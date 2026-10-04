-- SIMKA PRO | supabase/migrations/20261004002400_beranda_fase3.sql | v1.0 | Fase 3 – Tahap 6 Dashboard per peran | 04/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 3 · Migrasi 24: Ringkasan beranda per peran
--   ringkasan_beranda() mengembalikan satu objek JSON berisi bagian yang berhak dilihat pengguna:
--     pribadi  : jurnal hari ini, pengajuan, kuota cuti, agenda terdekat, pengumuman dan berkas belum dibaca
--     pimpinan : antrean persetujuan, kehadiran dan pengisian jurnal anggota unit, anggota yang izin/cuti hari ini
--     kelola   : statistik modul Fase 3 untuk admin/superadmin (sesuai izin)
-- Satu panggilan untuk seluruh kartu beranda; disegarkan otomatis oleh aplikasi.
-- Jalankan SETELAH migrasi 2300. Aman dijalankan ulang.
-- =====================================================================

create or replace function public.ringkasan_beranda()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_saya uuid := public.saya(); v_hari date := public.hari_ini(); v jsonb := '{}'; v_pimpinan boolean; v_jurnal jsonb;
begin
  if v_saya is null then return '{}'; end if;

  -- ---------- Pribadi ----------
  select jsonb_build_object(
      'wajib', public.wajib_jurnal(v_saya, v_hari),
      'butir_total', (select count(*) from public.butir_jurnal(v_saya)),
      'butir_selesai', (select count(*) from journal_checks c where c.employee_id = v_saya and c.tanggal = v_hari),
      'kegiatan', (select count(*) from journal_entries e where e.employee_id = v_saya and e.tanggal = v_hari),
      'dikembalikan', (select count(*) from journal_entries e where e.employee_id = v_saya and e.status = 'dikembalikan'
                         and e.diverval_pada > now() - interval '7 days'),
      'kemarin_kosong', public.wajib_jurnal(v_saya, v_hari - 1)
                         and not exists (select 1 from journal_checks c where c.employee_id = v_saya and c.tanggal = v_hari - 1)
                         and not exists (select 1 from journal_entries e where e.employee_id = v_saya and e.tanggal = v_hari - 1))
    into v_jurnal;

  v := v || jsonb_build_object('pribadi', jsonb_build_object(
    'jurnal', v_jurnal,
    'pengajuan_menunggu', (select count(*) from leave_requests r where r.employee_id = v_saya and r.status = 'menunggu'),
    'pengajuan_terakhir', (select jsonb_build_object('id', r.id, 'jenis', t.nama, 'status', r.status, 'mulai', r.mulai, 'selesai', r.selesai,
                              'jenjang', (select public.nama_peran_jenjang(a.peran) from leave_approvals a where a.request_id = r.id and a.urutan = r.langkah_ke))
                             from leave_requests r join leave_types t on t.id = r.leave_type_id
                            where r.employee_id = v_saya and r.status in ('menunggu','disetujui') and r.selesai >= v_hari
                            order by r.mulai limit 1),
    'sedang_cuti', (select t.nama || ' s.d. ' || to_char(r.selesai, 'DD/MM/YYYY') from leave_requests r join leave_types t on t.id = r.leave_type_id
                     where r.employee_id = v_saya and r.status = 'disetujui' and v_hari between r.mulai and r.selesai limit 1),
    'cuti_sisa', (select jsonb_build_object('nama', t.nama, 'kuota', t.kuota_tahunan_hari,
                     'sisa', greatest(t.kuota_tahunan_hari - (select hari_tahun from public.pemakaian_pengajuan(v_saya, t.id, v_hari)), 0))
                    from leave_types t where t.kode = 'CUTI_TAHUNAN' and t.aktif and t.kuota_tahunan_hari is not null),
    'agenda', (select coalesce(jsonb_agg(x order by x->>'mulai', x->>'jam_mulai'), '[]') from (
                 select jsonb_build_object('id', a.id, 'judul', a.judul, 'jenis', a.jenis, 'mulai', a.mulai, 'selesai', a.selesai, 'jam_mulai', a.jam_mulai, 'lokasi', a.lokasi) x
                   from agendas a join agenda_targets t on t.agenda_id = a.id and t.employee_id = v_saya
                  where a.selesai >= v_hari order by a.mulai, a.jam_mulai limit 3) q),
    'libur_berikut', (select jsonb_build_object('nama', h.nama, 'mulai', h.tanggal_mulai, 'selesai', h.tanggal_akhir)
                        from holidays h where h.tanggal_akhir >= v_hari and h.jenis <> 'tanpa_sesi' order by h.tanggal_mulai limit 1),
    'pengumuman_belum', (select count(*) from announcement_targets t join announcements a on a.id = t.announcement_id
                          where t.employee_id = v_saya and t.dibaca_pada is null and (a.tampil_sampai is null or a.tampil_sampai >= v_hari)),
    'pengumuman_terbaru', (select jsonb_build_object('id', a.id, 'judul', a.judul, 'penting', a.penting, 'created_at', a.created_at, 'dibaca', t.dibaca_pada is not null)
                             from announcements a join announcement_targets t on t.announcement_id = a.id and t.employee_id = v_saya
                            where a.tampil_sampai is null or a.tampil_sampai >= v_hari
                            order by a.penting desc, a.created_at desc limit 1),
    'berkas_baru', (select count(*) from employee_document_targets t where t.employee_id = v_saya and t.dibuka_pertama is null)));

  -- ---------- Pimpinan (pejabat struktural atau Plt yang memimpin unit) ----------
  v_pimpinan := exists (select 1 from public.pemegang_jabatan(v_hari) h where h.employee_id = v_saya
                         and h.kode in ('DIREKTUR','WAKIL_DIREKTUR','YAYASAN','KEPALA_BIDANG','KEPALA_UNIT'));
  if v_pimpinan then
    v := v || jsonb_build_object('pimpinan', (
      with anggota as (
        select e.id, e.nama_lengkap, e.org_unit_id from employees e
         where e.status_keaktifan = 'aktif' and e.status_akun = 'aktif' and e.id <> v_saya and public.pimpinan_dari(e.id)
      ), wajib as (
        select a.id, public.wajib_jurnal(a.id, v_hari) w from anggota a
      )
      select jsonb_build_object(
        'persetujuan_menunggu', (select count(*) from leave_requests r join leave_approvals ap on ap.request_id = r.id and ap.urutan = r.langkah_ke
                                  where r.status = 'menunggu' and exists (select 1 from public.calon_penyetuju(r.employee_id, ap.peran) c where c.employee_id = v_saya)),
        'anggota', (select count(*) from anggota),
        'hadir', (select count(distinct x.employee_id) from attendances x join anggota a on a.id = x.employee_id
                   where x.tanggal = v_hari and x.status in ('hadir','terlambat','dinas_luar')),
        'terlambat', (select count(distinct x.employee_id) from attendances x join anggota a on a.id = x.employee_id where x.tanggal = v_hari and x.status = 'terlambat'),
        'jurnal_wajib', (select count(*) from wajib where w),
        'jurnal_terisi', (select count(*) from wajib j where j.w and (exists (select 1 from journal_checks c where c.employee_id = j.id and c.tanggal = v_hari)
                            or exists (select 1 from journal_entries e where e.employee_id = j.id and e.tanggal = v_hari and e.status <> 'dikembalikan'))),
        'tidak_hadir', (select coalesce(jsonb_agg(jsonb_build_object('nama', a.nama_lengkap, 'jenis', t.nama, 'selesai', r.selesai) order by a.nama_lengkap), '[]')
                          from leave_requests r join anggota a on a.id = r.employee_id join leave_types t on t.id = r.leave_type_id
                         where r.status = 'disetujui' and v_hari between r.mulai and r.selesai))
    ));
  end if;

  -- ---------- Pengelola (admin/superadmin) ----------
  if public.is_admin() then
    v := v || jsonb_build_object('kelola', jsonb_build_object(
      'verval_jurnal', case when public.admin_boleh('verval_jurnal') then (select count(*) from journal_entries where status = 'menunggu') end,
      'pengajuan_menunggu', case when public.admin_boleh('lihat_pengajuan') then (select count(*) from leave_requests where status = 'menunggu') end,
      'pengajuan_bulan_ini', case when public.admin_boleh('lihat_pengajuan') then (select count(*) from leave_requests where status = 'disetujui' and date_trunc('month', mulai) = date_trunc('month', v_hari::timestamp)) end,
      'sedang_izin', (select count(distinct employee_id) from leave_requests where status = 'disetujui' and v_hari between mulai and selesai),
      'agenda_bulan_ini', (select count(*) from agendas where mulai <= (date_trunc('month', v_hari::timestamp) + interval '1 month - 1 day')::date and selesai >= date_trunc('month', v_hari::timestamp)::date),
      'agenda_pekan_ini', (select count(*) from agendas where mulai between v_hari and v_hari + 6),
      'berkas_belum_dibuka', case when public.admin_boleh('kelola_berkas') then (select count(*) from employee_document_targets where dibuka_pertama is null) end,
      'kartu_terbit', (select count(*) from employee_cards),
      'tanpa_niy', (select count(*) from employees where status_keaktifan = 'aktif' and nullif(trim(coalesce(niy, '')), '') is null),
      'tanpa_foto', (select count(*) from employees where status_keaktifan = 'aktif' and status_akun = 'aktif' and foto_id is null),
      'perangkat_push', (select count(distinct employee_id) from push_subscriptions),
      'akun_aktif', (select count(*) from employees where status_akun = 'aktif'),
      'jurnal_hari_ini', (select count(distinct employee_id) from (select employee_id from journal_checks where tanggal = v_hari
                           union select employee_id from journal_entries where tanggal = v_hari) q),
      'pengumuman_aktif', (select count(*) from announcements where tampil_sampai is null or tampil_sampai >= v_hari)));
  end if;
  return v;
end $$;

revoke execute on function public.ringkasan_beranda() from public, anon;
grant execute on function public.ringkasan_beranda() to authenticated;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 2 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select 'Fungsi ringkasan beranda' as pemeriksaan,
       case when exists (select 1 from pg_proc where proname = 'ringkasan_beranda') then 'Sesuai' else 'Periksa' end as hasil
union all
select 'Migrasi 2300 sudah terpasang',
       case when exists (select 1 from pg_proc where proname = 'kalender_saya') then 'Sesuai' else 'Periksa: jalankan 2300 dulu' end;
