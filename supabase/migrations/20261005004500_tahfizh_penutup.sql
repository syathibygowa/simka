-- SIMKA PRO | supabase/migrations/20261005004500_tahfizh_penutup.sql | v1.0 | Fase 5 – Tahap 6 Penutup fase tahfizh | 05/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 5 · Migrasi 45: Penutup fase Tahfizh
--   * ringkasan_tahfizh_beranda() : angka langsung untuk kartu beranda (sesuai cakupan pengguna): setoran hari ini,
--                                   ujian menunggu, usulan juz menunggu, rata-rata hafalan resmi, khatam, tercapai bulan ini.
--   * hafalan_santri(santri)      : isi tab Hafalan di profil santri terpadu (posisi, juz resmi + sumber, ujian,
--                                   usulan menunggu, jenjang sertifikasi, status bulan berjalan).
--   * Template WA baru: rekap_hafalan (ke wali santri), penguji_ujian (ke penguji). Dapat diubah di Pengaturan → Template WA.
-- Jalankan SETELAH migrasi 4400. Aman dijalankan ulang.
-- =====================================================================

create or replace function public.ringkasan_tahfizh_beranda()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_semua boolean := public.boleh_validasi_tahfizh() or public.boleh_atur_tahfizh() or public.boleh_pantau_absensi();
  v_tgl date := public.hari_ini(); v_saya uuid := public.saya(); hasil jsonb;
begin
  with sesi as (
    select g.id, ss.kode, (ms.id is not null) terisi, ss.buka <= now() dibuka
      from student_groups g join academic_years a on a.id = g.academic_year_id and a.aktif
      cross join lateral public.sesi_santri_tanggal('halaqah', v_tgl) ss
      left join memorization_sessions ms on ms.group_id = g.id and ms.tanggal = v_tgl and ms.sesi = ss.kode
     where g.aktif and g.jenis = 'halaqah' and (v_semua or v_saya in (select public._pengasuh_berlaku(g.id, v_tgl)))
  ), san as (
    select s.id, (select count(*) from juz_achievements j where j.student_id = s.id) resmi
      from students s where s.status = 'aktif' and s.id in (select public.santri_terlihat())
  ), bln as (select status from public.capaian_bulanan(v_tgl, null))
  select jsonb_build_object(
    'setoran_terisi', (select count(*) from sesi where terisi), 'setoran_dibuka', (select count(*) from sesi where dibuka), 'setoran_total', (select count(*) from sesi),
    'santri', (select count(*) from san), 'rata_juz', (select round(avg(resmi)::numeric, 1) from san), 'khatam', (select count(*) from san where resmi >= 30),
    'ujian_menunggu', (select count(*) from tahfizh_exams t where t.status in ('menunggu','dijadwalkan')
                        and (t.student_id in (select id from san) or public._penguji_aktif(t.jenis, v_saya))),
    'ujian_untuk_saya', (select count(*) from tahfizh_exams t where (t.status = 'menunggu' and public._penguji_aktif(t.jenis, v_saya)
                          and not public._muhaffizh_dari(t.student_id, v_saya)) or (t.status = 'dijadwalkan' and t.penguji_id = v_saya)),
    'usulan_menunggu', case when public.boleh_validasi_tahfizh() then (select count(*) from juz_proposals where status = 'menunggu') else
                         (select count(*) from juz_proposals p where p.status = 'menunggu' and p.student_id in (select id from san)) end,
    'tercapai', (select count(*) from bln where status in ('tercapai','khatam')),
    'tidak_tercapai', (select count(*) from bln where status = 'tidak_tercapai'),
    'terdata', (select count(*) from bln where status <> 'tidak_terdata'),
    'cakupan_semua', v_semua) into hasil;
  return hasil;
end $$;

create or replace function public.hafalan_santri(p_santri uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare t student_tahfizh; v_hq uuid; hasil jsonb;
begin
  if p_santri not in (select public.santri_terlihat()) then raise exception 'Santri di luar cakupan Anda.' using errcode = '42501'; end if;
  select * into t from student_tahfizh where student_id = p_santri;
  select g.id into v_hq from group_members m join student_groups g on g.id = m.group_id and g.jenis = 'halaqah'
    join academic_years a on a.id = g.academic_year_id and a.aktif where m.student_id = p_santri and m.selesai is null limit 1;
  select jsonb_build_object(
    'program', coalesce(t.program, 'reguler'), 'sabaq_hal', coalesce(t.sabaq_hal, 0), 'sabqi_hal', coalesce(t.sabqi_hal, 0), 'manzil_hal', coalesce(t.manzil_hal, 0),
    'juz_sedang', t.juz_sedang, 'posisi_pada', t.posisi_pada, 'posisi_sumber', t.posisi_sumber,
    'halaqah', (select nama from student_groups where id = v_hq),
    'muhaffizh', (select e.nama_lengkap from group_keepers k join employees e on e.id = k.employee_id where k.group_id = v_hq
                   order by array_position(array['utama','pendamping','pengganti'], k.peran) limit 1),
    'juz', coalesce((select jsonb_agg(jsonb_build_object('juz', j.juz, 'sumber', j.sumber, 'tanggal', j.tanggal) order by j.juz) from juz_achievements j where j.student_id = p_santri), '[]'),
    'usulan', coalesce((select jsonb_agg(p.juz order by p.juz) from juz_proposals p where p.student_id = p_santri and p.status = 'menunggu'), '[]'),
    'jenjang_sertifikasi', public.jenjang_sertifikasi(p_santri),
    'ujian', coalesce((select jsonb_agg(jsonb_build_object('jenis', x.jenis, 'juz', x.juz, 'jenjang', x.jenjang, 'status', x.status, 'hasil', x.hasil,
                 'nilai_akhir', x.nilai_akhir, 'huruf', x.huruf, 'predikat', x.predikat, 'diuji_pada', x.diuji_pada, 'ujian_ke', x.ujian_ke,
                 'penguji', (select nama_lengkap from employees where id = x.penguji_id)) order by coalesce(x.diuji_pada, x.direkomendasikan_pada) desc)
               from tahfizh_exams x where x.student_id = p_santri and x.status <> 'dibatalkan'), '[]'),
    'bulan_ini', (select to_jsonb(c) - 'student_id' from public.capaian_bulanan(public.hari_ini(), v_hq) c where c.student_id = p_santri))
  into hasil;
  return hasil;
end $$;

do $$
declare f text;
begin
  foreach f in array array['ringkasan_tahfizh_beranda()','hafalan_santri(uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

insert into public.wa_templates (kode, nama, isi, variabel, keterangan) values
  ('rekap_hafalan', 'Rekap hafalan ke orang tua/wali',
   E'{salam}, Bapak/Ibu {nama_wali}.\n\nPerkembangan hafalan ananda *{nama_santri}* ({kelas}, {halaqah}):\n• Posisi hafalan: {posisi}\n• Hafalan resmi: {total_juz} juz\n• Capaian {periode}: {capaian}\n{keterangan}\n\nMohon doa dan dukungan Bapak/Ibu agar ananda istiqamah menjaga hafalannya.\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
   '{nama_wali,nama_santri,kelas,halaqah,posisi,total_juz,periode,capaian,keterangan}', 'Tombol WA di Profil santri → Hafalan (muhaffizh/pengasuh ke orang tua/wali).'),
  ('penguji_ujian', 'Daftar tunggu ujian ke penguji',
   E'{salam}, {nama}.\n\nDaftar tunggu {jenis_ujian} ({jumlah} santri):\n{daftar}\n\nMohon berkenan mengambil dan menjadwalkan ujiannya di SIMKA PRO: {tautan}\n\n{penutup}\n{pengirim}',
   '{nama,jenis_ujian,jumlah,daftar,tautan}', 'Tombol "Kabari penguji" di Tahfizh → Ujian.')
on conflict (kode) do nothing;

-- PEMERIKSAAN — hasil yang benar: 3 baris, semuanya "Sesuai"
select 'Fungsi beranda dan profil hafalan (2) tersedia' as pemeriksaan,
       case when (select count(distinct proname) from pg_proc where proname in ('ringkasan_tahfizh_beranda','hafalan_santri')) = 2 then 'Sesuai' else 'Periksa' end as hasil
union all
select 'Template WA rekap_hafalan dan penguji_ujian', case when (select count(*) from public.wa_templates where kode in ('rekap_hafalan','penguji_ujian')) = 2 then 'Sesuai' else 'Periksa' end
union all
select 'Migrasi 4400 sudah terpasang', case when exists (select 1 from pg_proc where proname = 'data_laporan_tahfizh') then 'Sesuai' else 'Periksa: jalankan 4400 dulu' end;
