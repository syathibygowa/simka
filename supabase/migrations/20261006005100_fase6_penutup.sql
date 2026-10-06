-- SIMKA PRO | supabase/migrations/20261006005100_fase6_penutup.sql | v1.0 | Fase 6 – Tahap 5 Penutup fase klinik dan lapor | 06/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 6 · Migrasi 51: Penutup Fase 6
--   * ringkasan_layanan_beranda(): kartu statistik langsung di Beranda untuk Klinik, Perizinan, dan Lapor ke Bidang,
--     sesuai hak pengguna (petugas/pimpinan/pemutus/penerima melihat cakupannya; pegawai melihat miliknya).
--   * riwayat_layanan_santri(santri): bagian Kesehatan, Perizinan, dan Laporan di profil santri terpadu.
--     Kesehatan hanya ringkasan (tanggal, keluhan umum, status) bagi pengasuh; nama pelapor anonim tidak ditampilkan.
-- Jalankan SETELAH migrasi 5000. Aman dijalankan ulang.
-- =====================================================================

create or replace function public.ringkasan_layanan_beranda()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_klinik boolean := public.boleh_kelola_klinik() or public.pimpinan_kesantrian() or exists (select 1 from public.klinik_petugas_saya());
begin
  if public.saya() is null then return null; end if;
  return jsonb_build_object(
    'klinik', case when v_klinik then (select jsonb_build_object(
        'menunggu', count(*) filter (where c.status = 'menunggu'),
        'lewat', count(*) filter (where c.status = 'menunggu' and (select min(r.batas_waktu) from clinic_referrals r where r.case_id = c.id) < now()),
        'dirawat', count(*) filter (where c.status = 'ditangani'),
        'kontrol_hari_ini', count(*) filter (where c.status = 'ditangani' and (c.kontrol_pada at time zone 'Asia/Makassar')::date = public.hari_ini()),
        'selesai_hari_ini', count(*) filter (where c.status = 'selesai' and (c.selesai_pada at time zone 'Asia/Makassar')::date = public.hari_ini()))
      from clinic_cases c where (c.status in ('menunggu','ditangani') or (c.selesai_pada at time zone 'Asia/Makassar')::date = public.hari_ini())
        and public.boleh_detail_klinik(c.klinik)) end,
    'rujukan_saya', (select count(*) from clinic_cases c where c.status in ('menunggu','ditangani')
        and exists (select 1 from clinic_referrals r where r.case_id = c.id and r.dirujuk_oleh = public.saya())),
    'izin', jsonb_build_object(
        'putuskan', (select count(*) from student_permits p where (p.status = 'diajukan' and public.boleh_putus_izin(p.unit_kode, 1))
                                                              or (p.status = 'disetujui_bidang' and public.boleh_putus_izin(p.unit_kode, 2))),
        'diajukan_saya', (select count(*) from student_permits p where p.pengusul_id = public.saya() and p.status in ('diajukan','disetujui_bidang')),
        'di_luar', (select count(*) from student_permits p where p.status = 'keluar' and public.boleh_lihat_izin(p.student_id, p.unit_kode)),
        'terlambat', (select count(*) from student_permits p where p.status = 'keluar' and now() > p.kembali_batas and public.boleh_lihat_izin(p.student_id, p.unit_kode)),
        'tampil', public.boleh_kelola_izin() or public.pimpinan_kesantrian() or exists (select 1 from unnest(array['KESANTRIAN','TAHFIZH','WUSTHA','SMA']) k where public.boleh_putus_izin(k, 1))),
    'lapor', jsonb_build_object(
        'baru', (select count(*) from incident_reports r where r.status = 'terkirim' and public.boleh_tangani_lapor(r.unit_kode)),
        'mendesak', (select count(*) from incident_reports r where r.mendesak and r.status <> 'selesai' and public.boleh_tangani_lapor(r.unit_kode)),
        'proses', (select count(*) from incident_reports r where r.status in ('diterima','ditindaklanjuti') and public.boleh_tangani_lapor(r.unit_kode)),
        'saya_terbuka', (select count(*) from incident_reports r where r.pelapor_id = public.saya() and r.status <> 'selesai'),
        'penerima', public.boleh_kelola_lapor() or exists (select 1 from org_units o where public.boleh_tangani_lapor(o.kode))));
end $$;

create or replace function public.riwayat_layanan_santri(p_santri uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_jk text; v_klinik text; v_detail boolean; v_lihat boolean; v_super boolean := public.is_superadmin();
begin
  select jenis_kelamin into v_jk from students where id = p_santri;
  if v_jk is null then return null; end if;
  v_klinik := case when v_jk = 'P' then 'putri' else 'putra' end;
  v_detail := public.boleh_detail_klinik(v_klinik);
  v_lihat := v_detail or p_santri in (select public.santri_terlihat()) or public.is_admin();
  if not v_lihat then raise exception 'Anda tidak berwenang melihat riwayat santri ini.' using errcode = '42501'; end if;
  return jsonb_build_object(
    'detail_klinik', v_detail,
    'klinik', coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'dibuka_pada', c.dibuka_pada, 'keluhan', c.keluhan, 'status', c.status,
          'tindak_lanjut', c.tindak_lanjut, 'hasil', c.hasil, 'selesai_pada', c.selesai_pada, 'kontrol_pada', c.kontrol_pada,
          'diagnosis', case when v_detail then (select v.diagnosis from clinic_visits v where v.case_id = c.id and v.diagnosis is not null order by v.waktu desc limit 1) end,
          'surat', (select count(*) from clinic_letters l where l.case_id = c.id)) order by c.dibuka_pada desc)
        from (select * from clinic_cases where student_id = p_santri order by dibuka_pada desc limit 20) c), '[]'::jsonb),
    'izin', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'jenis', p.jenis, 'alasan', p.alasan, 'status', p.status, 'keluar_pada', p.keluar_pada,
          'kembali_batas', p.kembali_batas, 'kembali_pada', p.kembali_pada, 'lama_hari', p.lama_hari,
          'terlambat', (p.status = 'keluar' and now() > p.kembali_batas) or (p.status = 'kembali' and p.kembali_pada > p.kembali_batas)) order by p.keluar_pada desc)
        from (select * from student_permits where student_id = p_santri order by keluar_pada desc limit 20) p), '[]'::jsonb),
    'laporan', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'kategori', k.nama, 'kode', r.kategori, 'uraian', r.uraian, 'status', r.status, 'created_at', r.created_at,
          'mendesak', r.mendesak, 'pelapor', case when r.anonim and not v_super then null else e.nama_lengkap end) order by r.created_at desc)
        from (select * from incident_reports where p_santri = any(santri_ids) order by created_at desc limit 20) r
        join report_categories k on k.kode = r.kategori left join employees e on e.id = r.pelapor_id), '[]'::jsonb));
end $$;

do $$
declare f text;
begin
  foreach f in array array['ringkasan_layanan_beranda()','riwayat_layanan_santri(uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

select '1. Kartu layanan di beranda' as pemeriksaan, case when exists (select 1 from pg_proc where proname = 'ringkasan_layanan_beranda') then 'Sesuai' else 'Periksa' end as hasil
union all select '2. Riwayat kesehatan, izin, laporan di profil santri', case when exists (select 1 from pg_proc where proname = 'riwayat_layanan_santri') then 'Sesuai' else 'Periksa' end;
