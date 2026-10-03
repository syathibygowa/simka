-- SIMKA PRO | supabase/migrations/20261003001400_isi_awal_presensi.sql | v1.0 | Fase 2 – Tahap 1 Isi awal presensi | 03/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 2 · Migrasi 14: Isi awal pola sesi, pengaturan, jadwal otomatis
-- Semua jam di bawah adalah ISI AWAL dan dapat diubah admin/superadmin di aplikasi.
-- Keputusan pemilik proyek (03/10/2026):
--   * rentang kerja 07.30–14.00, Jumat dan Sabtu sama; istirahat opsional
--   * jendela buka 30 menit, toleransi terlambat 10, cepat pulang 10, tutup datang 2 jam,
--     presensi pulang sampai 3 jam setelah jam selesai; wajib presensi pulang (pilihan a)
--   * asrama malam 21.00–24.00, asrama pagi 04.00–07.00
--   * penutupan sesi otomatis + penyapuan 00.30 WITA
-- =====================================================================

-- ---------- Pengaturan presensi (superadmin) ----------
insert into public.institution_settings (kunci, publik, nilai) values
('presensi', false, jsonb_build_object(
  'mulai_tanggal', null,
  'jeda_minimal_pulang_menit', 15,
  'batas_akurasi_m', 100,
  'berlaku_cek_detik', 180,
  'retensi_selfie_hari', 183,
  'folder_selfie', 'SIMKA PRO/Presensi',
  'pengingat_menit', 10))
on conflict (kunci) do nothing;

-- ---------- Pola tugas ----------
insert into public.task_patterns (kode, nama, jenis, kalender, pola_struktural, warna, urutan, catatan) values
  ('GURU',       'Guru',                     'rentang', 'sekolah',  false, 'presensi', 1, 'Datang dan pulang; istirahat opsional'),
  ('KANTOR',     'Staf dan kantor',          'rentang', 'kantor',   false, 'pegawai',  2, 'Operator, staf, kebersihan, logistik, media, sarpras'),
  ('STRUKTURAL', 'Jadwal umum struktural',   'rentang', 'kantor',   true,  'sistem',   3, 'Pimpinan tanpa tugas fungsional terjadwal'),
  ('MUHAFFIZH',  'Halaqah tahfizh',          'sesi',    'tahfizh',  false, 'tahfizh',  4, 'Tiga waktu halaqah'),
  ('MUSYRIF',    'Asrama',                   'sesi',    'asrama',   false, 'santri',   5, 'Malam dan pagi; tetap masuk hari Ahad'),
  ('EKSKUL',     'Pembina ekskul',           'sesi',    'sekolah',  false, 'laporan',  6, 'Sesi ditambahkan sesuai jadwal pertemuan ekskul'),
  ('MEDIS',      'Klinik (medis)',           'shift',   'medis',    false, 'klinik',   7, 'Dua shift; tidak rangkap tugas'),
  ('SECURITY',   'Security',                 'shift',   'security', false, 'security', 8, 'Tiga shift 8 jam bergilir; tidak rangkap tugas')
on conflict (kode) do nothing;

-- ---------- Sesi per pola ----------
-- Kolom: kode, nama, jam_mulai, jam_selesai, buka, tol_terlambat, tutup, wajib_pulang,
--        pulang_buka, tol_cepat_pulang, batas_pulang, opsional, label datang/pulang, urutan
insert into public.pattern_sessions (pattern_id, kode, nama, jam_mulai, jam_selesai, buka_menit,
  toleransi_terlambat_menit, tutup_menit, wajib_pulang, pulang_buka_menit, toleransi_cepat_pulang_menit,
  batas_pulang_menit, opsional, label_datang, label_pulang, urutan)
select p.id, v.kode, v.nama, v.mulai::time, v.selesai::time, v.buka, v.tol, v.tutup, v.wp,
       v.pbuka, v.tolc, v.bpulang, v.ops, v.ld, v.lp, v.urut
  from (values
    ('GURU',       'KERJA',     'Jam kerja',        '07:30', '14:00', 30, 10, 120, true,  120, 10, 180, false, 'Datang', 'Pulang',  1),
    ('GURU',       'ISTIRAHAT', 'Istirahat',        '12:00', '13:00', 15, 10,  60, true,   60,  0,  60, true,  'Keluar', 'Kembali', 2),
    ('KANTOR',     'KERJA',     'Jam kerja',        '07:30', '14:00', 30, 10, 120, true,  120, 10, 180, false, 'Datang', 'Pulang',  1),
    ('KANTOR',     'ISTIRAHAT', 'Istirahat',        '12:00', '13:00', 15, 10,  60, true,   60,  0,  60, true,  'Keluar', 'Kembali', 2),
    ('STRUKTURAL', 'KERJA',     'Jam kerja',        '07:30', '14:00', 30, 10, 120, true,  120, 10, 180, false, 'Datang', 'Pulang',  1),
    ('MUHAFFIZH',  'SUBUH',     'Halaqah subuh',    '05:00', '06:30', 30, 10,  45, false,   0,  0,   0, false, 'Hadir',  'Selesai', 1),
    ('MUHAFFIZH',  'SORE',      'Halaqah sore',     '15:30', '16:00', 30, 10,  45, false,   0,  0,   0, false, 'Hadir',  'Selesai', 2),
    ('MUHAFFIZH',  'MALAM',     'Halaqah malam',    '18:30', '19:30', 30, 10,  45, false,   0,  0,   0, false, 'Hadir',  'Selesai', 3),
    ('MUSYRIF',    'PAGI',      'Asrama pagi',      '04:00', '07:00', 30, 10,  45, false,   0,  0,   0, false, 'Hadir',  'Selesai', 1),
    ('MUSYRIF',    'MALAM',     'Asrama malam',     '21:00', '00:00', 30, 10,  45, false,   0,  0,   0, false, 'Hadir',  'Selesai', 2),
    ('MEDIS',      'SHIFT1',    'Shift 1',          '07:30', '11:00', 30, 10,  60, true,   30, 10, 120, false, 'Datang', 'Pulang',  1),
    ('MEDIS',      'SHIFT2',    'Shift 2',          '16:00', '19:00', 30, 10,  60, true,   30, 10, 120, false, 'Datang', 'Pulang',  2),
    ('SECURITY',   'PAGI',      'Shift pagi',       '06:00', '14:00', 30, 10, 120, true,   60, 10, 180, false, 'Datang', 'Pulang',  1),
    ('SECURITY',   'SIANG',     'Shift siang',      '14:00', '22:00', 30, 10, 120, true,   60, 10, 180, false, 'Datang', 'Pulang',  2),
    ('SECURITY',   'MALAM',     'Shift malam',      '22:00', '06:00', 30, 10, 120, true,   60, 10, 180, false, 'Datang', 'Pulang',  3)
  ) v(pola, kode, nama, mulai, selesai, buka, tol, tutup, wp, pbuka, tolc, bpulang, ops, ld, lp, urut)
  join public.task_patterns p on p.kode = v.pola
 where not exists (select 1 from public.pattern_sessions s where s.pattern_id = p.id and s.kode = v.kode);

-- ---------- Jabatan fungsional → pola bawaan ----------
update public.functional_positions fp set pola_id = p.id
  from (values ('GURU','GURU'), ('MUHAFFIZH','MUHAFFIZH'), ('MUSYRIF','MUSYRIF'), ('PEMBINA_EKSKUL','EKSKUL'),
               ('MEDIS','MEDIS'), ('SECURITY','SECURITY'), ('OPERATOR','KANTOR'), ('STAF_BIDANG','KANTOR'),
               ('STAF_PEMBANTU','KANTOR'), ('KEBERSIHAN','KANTOR'), ('LOGISTIK','KANTOR'), ('MEDIA','KANTOR'),
               ('SARPRAS','KANTOR')) v(jab, pola)
  join public.task_patterns p on p.kode = v.pola
 where fp.kode = v.jab and fp.pola_id is null;
-- Wali kelas tidak membawa pola sendiri (mengikuti pola gurunya).

-- ---------- Jadwal semua pegawai yang sudah ada ----------
select public.sinkron_jadwal_semua();

-- ---------- Jadwal otomatis (pg_cron, waktu UTC; WITA = UTC+8) ----------
-- Tiap 15 menit: tutup sesi yang jendelanya sudah lewat
select cron.schedule('tutup-sesi-presensi', '*/15 * * * *', $$ select public.tutup_sesi_presensi() $$);
-- 00.30 WITA (16.30 UTC): penyapuan akhir hari
select cron.schedule('penyapuan-presensi-harian', '30 16 * * *', $$ select public.tutup_sesi_presensi() $$);

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 6 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select 'Pola tugas (8)' as pemeriksaan,
       case when count(*) = 8 then 'Sesuai' else 'Periksa: ' || count(*) end as hasil
  from public.task_patterns where kode in ('GURU','KANTOR','STRUKTURAL','MUHAFFIZH','MUSYRIF','EKSKUL','MEDIS','SECURITY')
union all
select 'Sesi isi awal (15)',
       case when count(*) = 15 then 'Sesuai' else 'Periksa: ' || count(*) end
  from public.pattern_sessions
union all
select 'Jabatan fungsional berpola (13 dari 14)',
       case when count(*) filter (where pola_id is not null) = 13 then 'Sesuai'
            else 'Periksa: ' || count(*) filter (where pola_id is not null) end
  from public.functional_positions
union all
select 'Pengaturan presensi',
       case when exists (select 1 from public.institution_settings where kunci = 'presensi') then 'Sesuai' else 'Periksa' end
union all
select 'Jadwal otomatis pg_cron (2)',
       case when (select count(*) from cron.job where jobname in ('tutup-sesi-presensi','penyapuan-presensi-harian')) = 2
            then 'Sesuai' else 'Periksa' end
union all
select 'Pegawai berjabatan sudah punya jadwal',
       case when not exists (
              select 1 from public.employees e
               where e.status_akun <> 'ditolak'
                 and (exists (select 1 from public.employee_functions ef join public.functional_positions fp
                               on fp.id = ef.functional_position_id where ef.employee_id = e.id and fp.pola_id is not null)
                      or exists (select 1 from public.employee_structurals es where es.employee_id = e.id))
                 and not exists (select 1 from public.employee_schedules s where s.employee_id = e.id))
            then 'Sesuai' else 'Periksa' end;
