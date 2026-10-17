-- SIMKA PRO | supabase/migrations/20261020011200_hak_akses_semua_fitur.sql | v1.1 | Perbaikan 14.0.0: semua menu dapat diatur di Hak Akses (Tidak ada, Lihat, Input/ubah, Kelola) | 17/10/2026
-- =====================================================================
-- SIMKA PRO · Migrasi 112: Hak akses untuk SEMUA fitur
--   1. Setiap menu SIMKA kini memiliki baris di Hak Akses → Fitur. Yang tidak dapat diatur ditandai "kunci" beserta alasannya
--      (Beranda, Notifikasi, Profil, Setelan, Hak Akses; Gaji/Tunjangan/Keuangan diatur per orang di tab Fitur sensitif).
--   2. Lapis baru "Semua pegawai" (sasaran = 'semua') sebagai hak bawaan setiap pegawai. Jabatan dapat diberi tingkat sendiri,
--      termasuk "Tidak ada" (tingkat 0) untuk menimpa bawaan. Urutan: semua pegawai → jabatan → bidang → individu.
--      Jabatan Plt yang sedang berlaku ikut dihitung sebagai jabatan struktural.
--   3. Izin admin dipetakan ke fitur (tabel capability_features). admin_boleh(kode) kini juga benar bagi pegawai yang memegang
--      fitur pada tingkat yang ditentukan, sehingga menu khusus admin (Data Pegawai, Verifikasi Akun, Verval Presensi,
--      Penjadwalan, dll.) dapat diberikan kepada jabatan mana pun lewat matriks. Pemeriksaan tetap di server.
--   4. Akses yang sebelumnya otomatis karena jabatan dijadikan hak bawaan yang terlihat dan dapat diubah:
--      Layar Pantauan (semua jabatan struktural), Statistik Santri (disalin dari Data santri).
--   5. Fungsi yang sudah terpasang ditambal di tempat (bukan ditulis ulang) agar versi terbaru di database tetap terpakai.
-- Tidak ada pegawai yang kehilangan akses saat migrasi ini dijalankan.
-- Jalankan SETELAH migrasi 11100. Aman dijalankan ulang.
-- =====================================================================

-- Penanda jalankan pertama: hak bawaan dan pembersihan hanya dilakukan sekali, agar pengaturan Bapak tidak tertimpa saat diulang.
drop table if exists pg_temp._sekali;
create temp table _sekali as
  select not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                      where n.nspname = 'public' and p.proname = 'boleh_fitur') as pertama;

-- ---------------------------------------------------------------------
-- 1. SKEMA
-- ---------------------------------------------------------------------
alter table public.features add column if not exists kunci    text;
alter table public.features add column if not exists sensitif boolean not null default false;
alter table public.features drop constraint if exists features_kelompok_check;
alter table public.features add constraint features_kelompok_check
  check (kelompok in ('Utama','Presensi','Layanan Pegawai','Kepegawaian','Santri','Fungsional','Layanan','Administrasi','Sistem'));

alter table public.feature_grants drop constraint if exists feature_grants_sasaran_check;
alter table public.feature_grants add constraint feature_grants_sasaran_check
  check (sasaran in ('semua','fungsional','struktural','bidang','individu'));
alter table public.feature_grants drop constraint if exists feature_grants_tingkat_check;
alter table public.feature_grants add constraint feature_grants_tingkat_check
  check (tingkat between 0 and 3 and (tingkat > 0 or (mode = 'tambah' and sasaran in ('semua','fungsional','struktural'))));
create index if not exists feature_grants_sasaran_idx on public.feature_grants (sasaran, sasaran_id);

-- Izin admin → fitur: pemegang fitur pada tingkat_min ikut memiliki izin admin tersebut
create table if not exists public.capability_features (
  kode         text not null references public.admin_capabilities(kode) on delete cascade,
  feature_kode text not null references public.features(kode) on delete cascade,
  tingkat_min  smallint not null check (tingkat_min between 1 and 3),
  primary key (kode, feature_kode)
);
alter table public.capability_features enable row level security;
drop policy if exists baca on public.capability_features;
create policy baca on public.capability_features for select to authenticated using (true);
drop policy if exists kelola on public.capability_features;
create policy kelola on public.capability_features for all to authenticated using (public.is_superadmin()) with check (public.is_superadmin());

-- ---------------------------------------------------------------------
-- 2. KATALOG FITUR (satu baris per menu; sama dengan src/lib/hakAkses.js v2.0)
-- ---------------------------------------------------------------------
insert into public.features (kode, nama, kelompok, urutan, menu, arti, keterangan, kunci, sensitif) values
  ('beranda', 'Beranda', 'Utama', 1, 'Beranda', '{}'::jsonb, null, 'Halaman awal setiap akun. Isinya menyesuaikan hak lain; grafik periodik pimpinan mengikuti fitur Layar Pantauan.', false),
  ('notifikasi', 'Notifikasi', 'Utama', 2, 'Notifikasi', '{}'::jsonb, null, 'Setiap akun menerima notifikasinya sendiri.', false),
  ('pengumuman', 'Pengumuman', 'Utama', 3, 'Pengumuman (pegawai dan wali santri)', '{"1":"Membaca pengumuman yang ditujukan kepadanya","2":"Membuat pengumuman untuk pegawai dan wali santri","3":"Sama dengan input/ubah"}'::jsonb, 'Pimpinan unit tetap dapat membuat pengumuman untuk wali santri unitnya.', null, false),
  ('agenda', 'Agenda', 'Utama', 4, 'Agenda', '{"1":"Melihat agenda yang ditujukan kepadanya","2":"Membuat dan mengelola agenda serta undangan","3":"Juga mengisi kalender libur pondok"}'::jsonb, null, null, false),
  ('profil', 'Profil', 'Utama', 5, 'Profil, Kartu Pegawai, Data kepegawaian saya', '{}'::jsonb, null, 'Setiap akun mengelola profil dan kartu pegawainya sendiri.', false),
  ('presensi', 'Presensi', 'Presensi', 1, 'Presensi', '{"1":"Membuka menu Presensi dan riwayat presensinya","2":"Melakukan presensi (GPS dan swafoto)","3":"Sama dengan input/ubah"}'::jsonb, 'Tingkat Tidak ada menyembunyikan menu Presensi. Jadwal wajib presensi tetap diatur di Penjadwalan.', null, false),
  ('verval_presensi', 'Verval dan data presensi', 'Presensi', 2, 'Verval Presensi, Data Presensi', '{"1":"Melihat data presensi seluruh pegawai (Data Presensi)","2":"Memverifikasi presensi, koreksi, dan kecurigaan","3":"Sama dengan input/ubah"}'::jsonb, null, null, false),
  ('atur_presensi', 'Penjadwalan', 'Presensi', 3, 'Penjadwalan, Jadwal Shift (semua petugas)', '{"1":"Melihat penjadwalan, jadwal kerja, dan jadwal shift semua pegawai","2":"Mengatur titik GPS, pola sesi, jadwal kerja, dan shift","3":"Juga mengisi kalender libur pondok"}'::jsonb, 'Petugas shift otomatis melihat jadwal shift-nya sendiri.', null, false),
  ('pengajuan', 'Pengajuan', 'Layanan Pegawai', 1, 'Pengajuan (izin, sakit, cuti, dinas luar)', '{"1":"Membuka menu dan melihat pengajuannya","2":"Mengajukan izin, sakit, cuti, dan dinas luar","3":"Juga melihat semua pengajuan dan mengatur ketentuannya"}'::jsonb, 'Persetujuan tetap mengikuti jenjang jabatan (Kepala Bidang → Direktur/Wadir → Yayasan).', null, false),
  ('jurnal_harian', 'Jurnal harian', 'Layanan Pegawai', 2, 'Jurnal Harian', '{"1":"Membuka menu dan melihat jurnalnya","2":"Mengisi jurnal harian","3":"Juga memverifikasi jurnal dan mengatur template ceklist"}'::jsonb, 'Pimpinan tetap melihat jurnal anggota unitnya.', null, false),
  ('berkas_pegawai', 'Berkas pegawai', 'Layanan Pegawai', 3, 'Berkas Saya', '{"1":"Membuka berkas yang dikirim kepadanya","2":"Mengirim dan mengelola berkas untuk pegawai","3":"Sama dengan input/ubah"}'::jsonb, null, null, false),
  ('data_pegawai', 'Data pegawai', 'Kepegawaian', 1, 'Data Pegawai (biodata, rekap, cetak kartu massal, kelompok pegawai)', '{"1":"Melihat data seluruh pegawai","2":"Menambah dan mengubah data serta jabatan pegawai, mencetak kartu","3":"Juga mengatur kelompok pegawai (PH, PI, dll.)"}'::jsonb, 'Berikan Input/ubah dengan hati-hati: pemegangnya dapat mengubah jabatan pegawai, termasuk jabatannya sendiri.', null, false),
  ('verifikasi_akun', 'Verifikasi akun', 'Kepegawaian', 2, 'Verifikasi Akun', '{"1":"Melihat akun yang menunggu verifikasi","2":"Memverifikasi atau menolak pendaftaran akun","3":"Sama dengan input/ubah"}'::jsonb, 'Reset sandi dan menonaktifkan akun mengikuti Data pegawai tingkat Input/ubah. Menjadikan admin tetap khusus superadmin.', null, false),
  ('data_santri', 'Data santri', 'Santri', 1, 'Data Santri, Kelengkapan Data', '{"1":"Melihat data seluruh santri","2":"Menambah dan mengubah data santri","3":"Juga mengimpor, memutasi keluar, dan mengubah status santri"}'::jsonb, 'Juga membuka menu Tahfizh, Klinik, Perizinan, dan Libur Santri untuk dilihat.', null, false),
  ('statistik_santri', 'Statistik santri', 'Santri', 2, 'Statistik Santri', '{"1":"Melihat statistik santri seluruh pondok","2":"Sama dengan lihat","3":"Sama dengan lihat"}'::jsonb, 'Hak bawaan disalin dari pemegang Data santri.', null, false),
  ('kelompok_santri', 'Kelompok santri', 'Santri', 3, 'Kelompok Santri, Naik Kelas', '{"1":"Melihat semua kelompok (kelas, kamar, halaqah, ekskul)","2":"Mengatur kelompok, pengasuh, anggota, dan kategori ekskul","3":"Juga menjalankan Naik Kelas dan pergantian tahun ajaran"}'::jsonb, null, null, false),
  ('prestasi', 'Prestasi santri', 'Santri', 4, 'Prestasi Santri', '{"1":"Melihat prestasi seluruh santri","2":"Mencatat dan mengubah prestasi santri","3":"Sama dengan input/ubah"}'::jsonb, 'Pengasuh kelompok otomatis melihat prestasi santri asuhannya. Bawaan disalin dari Data santri dan jabatan pimpinan.', null, false),
  ('nilai', 'Penilaian dan rapor', 'Santri', 5, 'Penilaian', '{"1":"Belum berpengaruh (nilai diisi di menu kerja penilai)","2":"Belum berpengaruh (nilai diisi di menu kerja penilai)","3":"Membuka menu Penilaian: mengatur penilaian, mengelola nilai, dan mencetak rapor"}'::jsonb, 'Pengisian nilai tetap di menu kerja penilai (Guru Mapel, Tahfizh, Ekskul, Wali Kelas).', null, false),
  ('jadwal_mengajar', 'Jadwal pelajaran dan guru mapel', 'Santri', 6, 'Jadwal Pelajaran, Guru Mapel', '{"1":"Melihat jadwal pelajaran","2":"Sama dengan lihat","3":"Mengatur jadwal dan penugasan, memantau jurnal mengajar semua guru"}'::jsonb, 'Guru yang memiliki penugasan mengajar otomatis mengisi jurnalnya. Pimpinan bidang memantau jenjangnya.', null, false),
  ('portal_wali', 'Kelola Portal Wali', 'Santri', 7, 'Portal Wali (kesiapan data, sesi wali, pengaturan)', '{"1":"Melihat kesiapan data dan sesi wali, membuka kunci, mencabut sesi","2":"Sama dengan lihat","3":"Juga mengatur butir informasi dan jenis dokumen portal"}'::jsonb, null, null, false),
  ('absensi_kelas', 'Absensi kelas dan wali kelas', 'Fungsional', 1, 'Absensi Santri, Wali Kelas', '{"1":"Memantau absensi kelas seluruh santri (perlu juga Data santri ≥ Lihat)","2":"Sama dengan lihat","3":"Juga mengisi absensi kelas, halaqah, dan asrama atas nama pengasuh"}'::jsonb, 'Wali kelas yang ditetapkan pada kelasnya otomatis dapat mengisi.', null, false),
  ('absensi_asrama', 'Absensi asrama (musyrif)', 'Fungsional', 2, 'Musyrif', '{"1":"Memantau absensi asrama dan jurnal musyrif semua kamar","2":"Sama dengan lihat","3":"Sama dengan lihat"}'::jsonb, 'Musyrif yang ditetapkan pada kamarnya otomatis dapat mengisi.', null, false),
  ('absensi_ekskul', 'Ekskul', 'Fungsional', 3, 'Ekskul (dasbor, pertemuan, jadwal, rekap, nilai)', '{"1":"Memantau semua ekskul, jurnal latihan, dan nilai ekskul","2":"Sama dengan lihat","3":"Sama dengan lihat"}'::jsonb, 'Pembina yang ditetapkan pada ekskulnya otomatis dapat mengisi.', null, false),
  ('tahfizh', 'Tahfizh', 'Fungsional', 4, 'Tahfizh', '{"1":"Melihat data tahfizh semua halaqah","2":"Sama dengan lihat","3":"Mengatur ketentuan tahfizh dan memvalidasi capaian hafalan"}'::jsonb, 'Muhaffizh yang ditetapkan pada halaqahnya otomatis dapat mengisi setoran.', null, false),
  ('klinik', 'Klinik', 'Fungsional', 5, 'Klinik', '{"1":"Membuka menu Klinik","2":"Sama dengan lihat","3":"Mengelola ketentuan dan seluruh catatan pemeriksaan"}'::jsonb, 'Petugas kesehatan diatur di Klinik → Petugas.', null, false),
  ('gerbang', 'Security', 'Fungsional', 6, 'Security (gerbang, titipan, buku tamu, kunjungan)', '{"1":"Melihat aktivitas security","2":"Petugas: mencatat keluar-masuk, titipan, tamu, dan kunjungan","3":"Mengelola ketentuan security"}'::jsonb, null, null, false),
  ('perizinan_santri', 'Perizinan dan libur santri', 'Layanan', 1, 'Perizinan, Libur Santri', '{"1":"Melihat perizinan dan libur santri","2":"Sama dengan lihat","3":"Mengelola semua izin santri, periode libur, dan ketentuannya"}'::jsonb, 'Pemutus izin mengikuti jabatan struktural (Kepala Bidang Kesantrian, Direktur/Wadir, Plt).', null, false),
  ('lapor_bidang', 'Laporan ke bidang', 'Layanan', 2, 'Laporan', '{"1":"Membuka menu Laporan dan membuat laporan","2":"Sama dengan lihat","3":"Mengelola semua laporan, kategori, dan rekap"}'::jsonb, 'Penerima laporan mengikuti kategori.', null, false),
  ('pantauan', 'Layar Pantauan', 'Layanan', 3, 'Layar Pantauan, grafik periodik di Beranda', '{"1":"Membuka Layar Pantauan dan grafik periodik seluruh pondok di Beranda","2":"Sama dengan lihat","3":"Sama dengan lihat"}'::jsonb, 'Admin dan superadmin selalu dapat membuka. Bawaan: semua jabatan struktural.', null, false),
  ('laporan', 'Dokumen dan laporan kehadiran', 'Administrasi', 1, 'Dokumen (rekap presensi, laporan kehadiran, dokumen resmi)', '{"1":"Membuka menu Dokumen untuk data dirinya dan dokumen yang perlu ditandatanganinya","2":"Melihat laporan kehadiran seluruh pegawai dan santri","3":"Sama dengan input/ubah"}'::jsonb, 'Pimpinan tetap melihat laporan anggota unitnya.', null, false),
  ('tata_usaha', 'Persuratan', 'Administrasi', 2, 'Persuratan', '{"1":"Membuka menu Persuratan","2":"Mengelola surat masuk, surat keluar, dan buku agenda","3":"Sama dengan input/ubah"}'::jsonb, 'Pimpinan penerima surat dan penerima disposisi otomatis dapat membuka.', null, false),
  ('beban_kerja', 'Beban kerja', 'Administrasi', 3, 'Beban Kerja', '{"1":"Melihat beban kerjanya sendiri","2":"Melihat rekap beban kerja seluruh pegawai","3":"Juga mengatur jam tupoksi dan tugas tambahan"}'::jsonb, 'Pimpinan tetap melihat beban kerja anggota unitnya.', null, false),
  ('gaji', 'Gaji', 'Administrasi', 4, 'Gaji', '{}'::jsonb, null, 'Fitur sensitif: diatur per orang di tab Fitur sensitif sesuai keputusan yayasan.', true),
  ('tunjangan', 'Tunjangan', 'Administrasi', 5, 'Tunjangan', '{}'::jsonb, null, 'Fitur sensitif: mengikuti hak Gaji di tab Fitur sensitif.', true),
  ('keuangan', 'Keuangan santri', 'Administrasi', 6, 'Keuangan', '{}'::jsonb, null, 'Fitur sensitif: diatur per orang di tab Fitur sensitif sesuai keputusan yayasan.', true),
  ('audit_log', 'Audit log', 'Sistem', 1, 'Audit Log', '{"1":"Melihat audit log seluruh aktivitas (30 hari terakhir)","2":"Sama dengan lihat","3":"Sama dengan lihat"}'::jsonb, 'Bawaan: khusus superadmin.', null, false),
  ('organisasi', 'Organisasi', 'Sistem', 2, 'Organisasi (bidang, unit, jabatan)', '{"1":"Melihat struktur organisasi dan daftar jabatan","2":"Mengubah bidang, unit, dan jabatan","3":"Sama dengan input/ubah"}'::jsonb, 'Bawaan: khusus superadmin.', null, false),
  ('setelan', 'Setelan', 'Sistem', 3, 'Setelan (lembaga, kop, logo, penanda tangan, nomor surat, template WA)', '{}'::jsonb, null, 'Khusus superadmin: kop, penanda tangan, dan nomor surat menentukan keabsahan dokumen bertanda tangan elektronik.', false),
  ('hak_akses', 'Hak Akses', 'Sistem', 4, 'Hak Akses', '{}'::jsonb, null, 'Khusus superadmin: pemegang menu ini dapat memberi dirinya sendiri semua akses.', false)
on conflict (kode) do update set nama = excluded.nama, kelompok = excluded.kelompok, urutan = excluded.urutan, menu = excluded.menu,
  arti = excluded.arti, keterangan = excluded.keterangan, kunci = excluded.kunci, sensitif = excluded.sensitif, dipakai = true;

update public.features set dipakai = false, kunci = null, keterangan = v.ket
from (values
  ('absensi_halaqah', 'Tergabung dalam fitur Tahfizh dan muhaffizh pada halaqahnya.'),
  ('titipan', 'Tergabung dalam fitur Security.'),
  ('buku_tamu', 'Tergabung dalam fitur Security.'),
  ('kunjungan', 'Tergabung dalam fitur Security.'),
  ('kartu_pegawai', 'Kartu sendiri di Profil; cetak massal tergabung dalam Data pegawai.'),
  ('template_wa', 'Tergabung dalam Setelan (khusus superadmin).'),
  ('pengaturan_lembaga', 'Tergabung dalam Setelan (khusus superadmin).')
) v(kode, ket) where public.features.kode = v.kode;

-- Peta izin admin → fitur (hanya izin yang ada di database)
insert into public.capability_features (kode, feature_kode, tingkat_min)
select v.kode, v.fitur, v.minimal from (values
  ('kelola_pengumuman', 'pengumuman', 2),
  ('kelola_agenda', 'agenda', 2),
  ('kalender', 'agenda', 3),
  ('verval_presensi', 'verval_presensi', 2),
  ('atur_presensi', 'atur_presensi', 2),
  ('kalender', 'atur_presensi', 3),
  ('lihat_pengajuan', 'pengajuan', 3),
  ('atur_pengajuan', 'pengajuan', 3),
  ('verval_jurnal', 'jurnal_harian', 3),
  ('atur_jurnal', 'jurnal_harian', 3),
  ('kelola_berkas', 'berkas_pegawai', 2),
  ('kelola_pegawai', 'data_pegawai', 2),
  ('cetak_kartu', 'data_pegawai', 2),
  ('kelola_kelompok', 'data_pegawai', 3),
  ('verval_akun', 'verifikasi_akun', 2),
  ('kelola_santri', 'data_santri', 3),
  ('kelompok_santri', 'kelompok_santri', 2),
  ('atur_penilaian', 'nilai', 3),
  ('kelola_nilai', 'nilai', 3),
  ('atur_jadwal', 'jadwal_mengajar', 3),
  ('absensi_atas_nama', 'absensi_kelas', 3),
  ('atur_tahfizh', 'tahfizh', 3),
  ('validasi_tahfizh', 'tahfizh', 3),
  ('kelola_klinik', 'klinik', 3),
  ('kelola_security', 'gerbang', 3),
  ('kelola_izin_santri', 'perizinan_santri', 3),
  ('kelola_libur', 'perizinan_santri', 3),
  ('kelola_lapor', 'lapor_bidang', 3),
  ('kelola_persuratan', 'tata_usaha', 2),
  ('atur_beban_kerja', 'beban_kerja', 3)
) v(kode, fitur, minimal)
where exists (select 1 from public.admin_capabilities c where c.kode = v.kode)
on conflict (kode, feature_kode) do update set tingkat_min = excluded.tingkat_min;

-- ---------------------------------------------------------------------
-- 3. PEMBERSIHAN (sekali): aturan lama untuk fitur yang sejak 13.9.0 tidak berpengaruh
--    (presensi, pengajuan, jurnal, berkas, kartu, data pegawai, dokumen). Isinya dibuat ketika fitur-fitur ini belum
--    diperiksa server, sehingga bila dibiarkan akan tiba-tiba memberi akses baru. Diganti hak bawaan di bawah.
-- ---------------------------------------------------------------------
delete from public.feature_grants g
 where (select pertama from _sekali)
   and g.feature_kode in ('presensi','pengajuan','jurnal_harian','berkas_pegawai','kartu_pegawai','data_pegawai','laporan');

-- ---------------------------------------------------------------------
-- 4. HAK BAWAAN (sekali) — meniru perilaku sebelum migrasi ini
-- ---------------------------------------------------------------------
-- 4a. Semua pegawai
insert into public.feature_grants (feature_kode, sasaran, sasaran_id, tingkat, mode, catatan)
select v.kode, 'semua', '00000000-0000-0000-0000-000000000000'::uuid, v.t, 'tambah', 'Bawaan 14.0.0'
from (values
  ('pengumuman', 1),
  ('agenda', 1),
  ('presensi', 2),
  ('pengajuan', 2),
  ('jurnal_harian', 2),
  ('berkas_pegawai', 1),
  ('lapor_bidang', 1),
  ('laporan', 1)
) v(kode, t)
where (select pertama from _sekali)
on conflict (feature_kode, sasaran, sasaran_id) do nothing;

-- 4b. Layar Pantauan: sebelumnya otomatis untuk SEMUA jabatan struktural (termasuk Plt)
insert into public.feature_grants (feature_kode, sasaran, sasaran_id, tingkat, mode, catatan)
select 'pantauan', 'struktural', sp.id, 1, 'tambah', 'Bawaan 14.0.0: sebelumnya otomatis untuk jabatan struktural'
from public.structural_positions sp
where (select pertama from _sekali)
on conflict (feature_kode, sasaran, sasaran_id) do nothing;

-- 4c. Statistik Santri: sebelumnya mengikuti Data santri → salin semua aturan Data santri
insert into public.feature_grants (feature_kode, sasaran, sasaran_id, tingkat, mode, catatan)
select 'statistik_santri', g.sasaran, g.sasaran_id, g.tingkat, g.mode, 'Bawaan 14.0.0: disalin dari Data santri'
from public.feature_grants g
where (select pertama from _sekali) and g.feature_kode = 'data_santri'
on conflict (feature_kode, sasaran, sasaran_id) do nothing;

-- 4d. Prestasi Santri: sebelumnya menu terbuka bagi pemegang Data santri dan pimpinan → salin Data santri + jabatan pimpinan
insert into public.feature_grants (feature_kode, sasaran, sasaran_id, tingkat, mode, catatan)
select 'prestasi', g.sasaran, g.sasaran_id, least(g.tingkat, 1), g.mode, 'Bawaan 14.0.0: disalin dari Data santri'
from public.feature_grants g
where (select pertama from _sekali) and g.feature_kode = 'data_santri' and g.tingkat >= 1
on conflict (feature_kode, sasaran, sasaran_id) do nothing;
insert into public.feature_grants (feature_kode, sasaran, sasaran_id, tingkat, mode, catatan)
select 'prestasi', 'struktural', sp.id, 1, 'tambah', 'Bawaan 14.0.0: sebelumnya otomatis untuk pimpinan'
from public.structural_positions sp
where (select pertama from _sekali) and sp.kode in ('YAYASAN','DIREKTUR','WAKIL_DIREKTUR','KEPALA_BIDANG','KEPALA_UNIT')
on conflict (feature_kode, sasaran, sasaran_id) do nothing;

-- ---------------------------------------------------------------------
-- 5. FUNGSI INTI HAK AKSES
-- ---------------------------------------------------------------------
/** Jabatan seorang pegawai: fungsional, struktural tetap, dan struktural Plt yang sedang berlaku. */
create or replace function public._jabatan_pegawai(p_emp uuid)
returns table (sasaran text, sasaran_id uuid)
language sql stable security definer set search_path = public as $$
  select 'fungsional'::text, ef.functional_position_id from employee_functions ef where ef.employee_id = p_emp
  union
  select 'struktural'::text, es.structural_position_id from employee_structurals es where es.employee_id = p_emp
  union
  select 'struktural'::text, aa.structural_position_id from acting_assignments aa
   where aa.employee_id = p_emp and public.hari_ini() between aa.mulai and aa.sampai
$$;

/** Tingkat satu fitur untuk satu pegawai (versi ringan dari rincian_akses).
    jabatan = maksimum dari setiap jabatannya, masing-masing memakai aturan jabatan itu (boleh 0) atau bawaan Semua pegawai;
    lalu bidang (tambah/cabut) dan individu (tambah/cabut). Superadmin selalu 3. */
create or replace function public._tingkat(p_emp uuid, p_kode text)
returns smallint language plpgsql stable security definer set search_path = public as $$
declare v_peran text; v_unit uuid; v_dasar smallint; v_jab smallint; v_bt smallint; v_bc smallint; v_it smallint; v_ic smallint;
begin
  if p_emp is null then return 0; end if;
  select peran, org_unit_id into v_peran, v_unit from employees where id = p_emp;
  if not found then return 0; end if;
  if v_peran = 'superadmin' then return 3; end if;
  select g.tingkat into v_dasar from feature_grants g where g.feature_kode = p_kode and g.sasaran = 'semua' and g.mode = 'tambah';
  select max(coalesce(g.tingkat, v_dasar, 0)) into v_jab
    from public._jabatan_pegawai(p_emp) j
    left join feature_grants g on g.feature_kode = p_kode and g.sasaran = j.sasaran and g.sasaran_id = j.sasaran_id and g.mode = 'tambah';
  v_jab := coalesce(v_jab, v_dasar, 0);
  with recursive a(id, parent_id) as (
    select id, parent_id from org_units where id = v_unit
    union all select u.id, u.parent_id from org_units u join a on u.id = a.parent_id
  )
  select max(g.tingkat) filter (where g.mode = 'tambah'), min(g.tingkat) filter (where g.mode = 'cabut') into v_bt, v_bc
    from feature_grants g where g.feature_kode = p_kode and g.sasaran = 'bidang' and g.sasaran_id in (select id from a);
  select max(g.tingkat) filter (where g.mode = 'tambah'), min(g.tingkat) filter (where g.mode = 'cabut') into v_it, v_ic
    from feature_grants g where g.feature_kode = p_kode and g.sasaran = 'individu' and g.sasaran_id = p_emp;
  return least(greatest(least(greatest(v_jab, coalesce(v_bt, 0)), coalesce(v_bc - 1, 3)), coalesce(v_it, 0)), coalesce(v_ic - 1, 3))::smallint;
end $$;

/** Rincian akses seluruh fitur seorang pegawai (dipakai menu Hak Akses dan fitur_saya). Tanda tangan fungsi tidak berubah. */
create or replace function public.rincian_akses(p_employee uuid)
returns table (kode text, nama text, kelompok text, dari_jabatan smallint, dari_bidang smallint, dari_individu smallint, efektif smallint)
language plpgsql stable security definer set search_path = public as $$
declare v_peran text; v_unit uuid;
begin
  if auth.uid() is not null and not public.is_admin() and p_employee is distinct from public.saya() then
    raise exception 'Tidak berwenang melihat hak akses pegawai lain.' using errcode = '42501';
  end if;
  select e.peran, e.org_unit_id into v_peran, v_unit from employees e where e.id = p_employee;

  return query
  with jab_saya as (select * from public._jabatan_pegawai(p_employee)),
  dasar as (select g.feature_kode, g.tingkat from feature_grants g where g.sasaran = 'semua' and g.mode = 'tambah'),
  per_jab as (
    select f.kode fk, coalesce(g.tingkat, d.tingkat, 0) t
      from features f cross join jab_saya j
      left join feature_grants g on g.feature_kode = f.kode and g.sasaran = j.sasaran and g.sasaran_id = j.sasaran_id and g.mode = 'tambah'
      left join dasar d on d.feature_kode = f.kode
  ),
  jab as (
    select f.kode fk, coalesce((select max(p.t) from per_jab p where p.fk = f.kode), d.tingkat, 0)::smallint t
      from features f left join dasar d on d.feature_kode = f.kode
  ),
  leluhur as (
    with recursive a(id, parent_id) as (
      select o.id, o.parent_id from org_units o where o.id = v_unit
      union all select u.id, u.parent_id from org_units u join a on u.id = a.parent_id
    ) select a.id from a
  ),
  bid as (
    select g.feature_kode fk, max(g.tingkat) filter (where g.mode = 'tambah')::smallint tambah, min(g.tingkat) filter (where g.mode = 'cabut')::smallint cabut
      from feature_grants g where g.sasaran = 'bidang' and g.sasaran_id in (select l.id from leluhur l) group by g.feature_kode
  ),
  ind as (
    select g.feature_kode fk, max(g.tingkat) filter (where g.mode = 'tambah')::smallint tambah, min(g.tingkat) filter (where g.mode = 'cabut')::smallint cabut
      from feature_grants g where g.sasaran = 'individu' and g.sasaran_id = p_employee group by g.feature_kode
  )
  select f.kode, f.nama, f.kelompok, jab.t,
         case when bid.cabut is not null then (-bid.cabut)::smallint else bid.tambah end,
         case when ind.cabut is not null then (-ind.cabut)::smallint else ind.tambah end,
         case when v_peran = 'superadmin' then 3::smallint else
           least(greatest(least(greatest(jab.t, coalesce(bid.tambah, 0)), coalesce(bid.cabut - 1, 3)), coalesce(ind.tambah, 0)), coalesce(ind.cabut - 1, 3))::smallint end
    from features f join jab on jab.fk = f.kode
    left join bid on bid.fk = f.kode left join ind on ind.fk = f.kode
   order by f.kelompok, f.urutan;
end $$;
comment on function public.rincian_akses is
  'dari_jabatan sudah termasuk bawaan Semua pegawai. dari_bidang/dari_individu negatif = pencabutan pada tingkat tersebut. Efektif: 0 tanpa akses, 1 lihat, 2 input/ubah, 3 kelola.';

create or replace function public.tingkat_fitur(p_kode text)
returns smallint language sql stable security definer set search_path = public as $$
  select public._tingkat(public.saya(), p_kode)
$$;

create or replace function public.tingkat_fitur_pegawai(p_emp uuid, p_kode text)
returns smallint language sql stable security definer set search_path = public as $$
  select public._tingkat(p_emp, p_kode)
$$;

/** Pemegang fitur pada tingkat minimal (superadmin selalu). */
create or replace function public.boleh_fitur(p_kode text, p_min int default 1)
returns boolean language sql stable security definer set search_path = public as $$
  select public._tingkat(public.saya(), p_kode) >= p_min
$$;

/** Cakupan luas sebuah fitur (melihat semua kelompok, bukan hanya asuhan). Hak dari jabatan fungsional tidak termasuk;
    hak Semua pegawai, jabatan struktural (termasuk Plt), bidang, dan individu termasuk. */
create or replace function public.akses_luas(p_kode text)
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_admin() or (
    public.tingkat_fitur(p_kode) >= 1 and (
      public.tingkat_fitur(p_kode) >= 3
      or exists (
        select 1 from feature_grants g
         where g.feature_kode = p_kode and g.mode = 'tambah' and g.tingkat >= 1 and (
               g.sasaran = 'semua'
            or (g.sasaran = 'struktural' and g.sasaran_id in (select j.sasaran_id from public._jabatan_pegawai(public.saya()) j where j.sasaran = 'struktural'))
            or (g.sasaran = 'individu' and g.sasaran_id = public.saya())
            or (g.sasaran = 'bidang' and g.sasaran_id in (
                  with recursive induk(id) as (
                    select org_unit_id from employees where id = public.saya()
                    union all select u.parent_id from org_units u join induk i on u.id = i.id where u.parent_id is not null)
                  select id from induk where id is not null))))))
$$;

-- ---------------------------------------------------------------------
-- 6. IZIN ADMIN YANG DIPETAKAN KE FITUR
-- ---------------------------------------------------------------------
/** Izin admin murni (dicentang superadmin per admin) — perilaku admin_boleh sebelum 14.0.0. */
create or replace function public.izin_admin(p_kode text)
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_superadmin() or exists (
    select 1 from employees e join admin_permissions ap on ap.employee_id = e.id
    where e.user_id = auth.uid() and e.status_akun = 'aktif' and e.peran = 'admin' and ap.kode = p_kode)
$$;

/** Izin admin efektif: superadmin, admin yang dicentang, ATAU pemegang fitur yang dipetakan pada tingkat minimalnya. */
create or replace function public.admin_boleh(p_kode text)
returns boolean language sql stable security definer set search_path = public as $$
  select public.izin_admin(p_kode)
      or exists (select 1 from capability_features m
                  where m.kode = p_kode and public._tingkat(public.saya(), m.feature_kode) >= m.tingkat_min)
$$;

/** Sama dengan admin_boleh untuk pegawai tertentu (dipakai Edge Function dan pemeriksaan berkas). */
create or replace function public.admin_boleh_pegawai(p_emp uuid, p_kode text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from employees e where e.id = p_emp and e.status_akun = 'aktif' and (
           e.peran = 'superadmin'
           or (e.peran = 'admin' and exists (select 1 from admin_permissions ap where ap.employee_id = e.id and ap.kode = p_kode))
           or exists (select 1 from capability_features m where m.kode = p_kode and public._tingkat(e.id, m.feature_kode) >= m.tingkat_min)))
$$;

/** Daftar izin admin yang berlaku bagi pengguna (admin yang dicentang + yang didapat dari hak fitur). */
create or replace function public.izin_admin_saya()
returns text[] language sql stable security definer set search_path = public as $$
  select case
    when public.is_superadmin() then (select coalesce(array_agg(kode order by kode), '{}') from admin_capabilities)
    else coalesce((select array_agg(distinct x order by x) from (
           select ap.kode x from admin_permissions ap join employees e on e.id = ap.employee_id
            where ap.employee_id = public.saya() and e.peran = 'admin'
           union
           select m.kode from capability_features m where public._tingkat(public.saya(), m.feature_kode) >= m.tingkat_min) t), '{}')
  end
$$;

/** Notifikasi untuk pemegang izin: kini juga pegawai yang mendapat izin itu dari hak fitur. */
create or replace function public.notifikasi_admin(p_izin text, p_judul text, p_isi text, p_tautan text,
  p_ikon text default 'Bell', p_warna text default 'biru')
returns int language plpgsql volatile security definer set search_path = public as $$
declare n int;
begin
  insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
  select e.id, p_judul, p_isi, p_tautan, p_ikon, p_warna from employees e
  where e.status_akun = 'aktif' and public.admin_boleh_pegawai(e.id, p_izin);
  get diagnostics n = row_count; return n;
end $$;

-- ---------------------------------------------------------------------
-- 7. GERBANG FITUR YANG SEBELUMNYA OTOMATIS KARENA JABATAN ATAU PERAN
-- ---------------------------------------------------------------------
/** Melihat data seluruh pegawai beserta presensinya: admin, atau pemegang Data pegawai, Verval presensi, Penjadwalan,
    Verifikasi akun (Lihat), atau Dokumen (Input/ubah = laporan kehadiran seluruh pegawai). */
create or replace function public.lihat_semua_pegawai()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_admin() or public.boleh_fitur('data_pegawai') or public.boleh_fitur('verval_presensi')
      or public.boleh_fitur('atur_presensi') or public.boleh_fitur('verifikasi_akun') or public.boleh_fitur('laporan', 2)
$$;

/** Layar Pantauan dan grafik periodik: admin, superadmin, dan pemegang fitur Layar Pantauan (bawaan: jabatan struktural). */
create or replace function public.boleh_pantauan()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_admin() or public.boleh_fitur('pantauan')
$$;

/** Jadwal shift: admin, pemegang Penjadwalan (Lihat), dan petugas pada pola shift tersebut. */
create or replace function public.boleh_lihat_shift(p_pola uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_admin() or public.boleh_fitur('atur_presensi')
      or exists (select 1 from employee_schedules where employee_id = public.saya() and pattern_id = p_pola and aktif)
$$;

/** Kelola Portal Wali: superadmin, admin ber-izin Mengelola santri, dan pemegang fitur Kelola Portal Wali. */
create or replace function public._boleh_portal()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_superadmin() or public.izin_admin('kelola_santri') or public.boleh_fitur('portal_wali')
$$;

/** Naik Kelas: superadmin, admin ber-izin santri dan kelompok, atau pemegang Kelompok santri tingkat Kelola. */
create or replace function public.boleh_ganti_ta()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_superadmin() or (public.admin_boleh('kelola_santri') and public.admin_boleh('kelompok_santri'))
      or public.boleh_fitur('kelompok_santri', 3)
$$;

-- ---------------------------------------------------------------------
-- 8. PENAMBALAN DI TEMPAT (fungsi terpasang diubah seperlunya, versi terbarunya tetap dipakai)
-- ---------------------------------------------------------------------
create or replace function pg_temp.tambal(p_fn text, p_cari text, p_ganti text, p_tanda text)
returns text language plpgsql as $$
declare r record; v text; n int := 0;
begin
  for r in select p.oid from pg_proc p join pg_namespace s on s.oid = p.pronamespace where s.nspname = 'public' and p.proname = p_fn loop
    v := pg_get_functiondef(r.oid);
    if position(p_tanda in v) > 0 then n := n + 1; continue; end if;      -- sudah ditambal
    if position(p_cari in v) = 0 then raise notice 'Penambalan %: teks acuan tidak ditemukan, dilewati.', p_fn; continue; end if;
    execute replace(v, p_cari, p_ganti); n := n + 1;
  end loop;
  return p_fn || ': ' || n;
end $$;

-- 8a. Presensi dan laporan kehadiran pegawai: admin → lihat_semua_pegawai()
select pg_temp.tambal('statistik_presensi', 'not public.is_admin()', 'not public.lihat_semua_pegawai()', 'lihat_semua_pegawai');
select pg_temp.tambal('rekap_harian', 'not public.is_admin()', 'not public.lihat_semua_pegawai()', 'lihat_semua_pegawai');
select pg_temp.tambal('presensi_harian', 'public.is_admin() or public.pimpinan_dari(v_emp)', 'public.lihat_semua_pegawai() or public.pimpinan_dari(v_emp)', 'lihat_semua_pegawai');
select pg_temp.tambal('riwayat_presensi', 'public.is_admin() or public.pimpinan_dari(a.employee_id)', 'public.lihat_semua_pegawai() or public.pimpinan_dari(a.employee_id)', 'lihat_semua_pegawai');
select pg_temp.tambal('rekap_presensi', 'v_admin boolean := public.is_admin()', 'v_admin boolean := public.lihat_semua_pegawai()', 'lihat_semua_pegawai');
select pg_temp.tambal('laporan_kehadiran_pegawai', 'v_admin boolean := public.is_admin()', 'v_admin boolean := public.lihat_semua_pegawai()', 'lihat_semua_pegawai');
-- 8b. Laporan kehadiran santri seluruh pondok: Dokumen tingkat Input/ubah
select pg_temp.tambal('laporan_kehadiran_santri', 'v_pemantau boolean := public.is_admin()', 'v_pemantau boolean := public.is_admin() or public.boleh_fitur(''laporan'', 2)', 'boleh_fitur(''laporan''');
-- 8c. Statistik Santri seluruh pondok
select pg_temp.tambal('statistik_santri', 'from public.santri_terlihat() x;',
  'from (select s.id from students s where public.boleh_fitur(''statistik_santri'') union select t from public.santri_terlihat() t) z(x);', 'boleh_fitur(''statistik_santri'') union');
select pg_temp.tambal('statistik_santri', 'public.is_admin() or sa.group_id', 'public.is_admin() or public.boleh_fitur(''statistik_santri'') or sa.group_id', 'boleh_fitur(''statistik_santri'') or sa.group_id');
-- 8d. Audit log
select pg_temp.tambal('audit_daftar', 'if not public.is_superadmin() then', 'if not (public.is_superadmin() or public.boleh_fitur(''audit_log'')) then', 'boleh_fitur(''audit_log'')');
select pg_temp.tambal('ringkasan_audit', 'if not public.is_superadmin() then', 'if not (public.is_superadmin() or public.boleh_fitur(''audit_log'')) then', 'boleh_fitur(''audit_log'')');
-- 8e. Pengaturan Portal Wali
select pg_temp.tambal('pengaturan_portal_wali', '''boleh_ubah'', public.is_superadmin()', '''boleh_ubah'', public.is_superadmin() or public.boleh_fitur(''portal_wali'', 3)', 'boleh_fitur(''portal_wali''');
select pg_temp.tambal('simpan_pengaturan_portal_wali', 'if not public.is_superadmin() then', 'if not (public.is_superadmin() or public.boleh_fitur(''portal_wali'', 3)) then', 'boleh_fitur(''portal_wali''');
-- 8f. Data pegawai: pemegang izin (dari hak fitur) mengubah data seperti admin, tetap tanpa mengubah peran/akun
select pg_temp.tambal('tg_employees_jaga', '  if public.is_admin() then', '  if public.is_admin() or public.admin_boleh(''kelola_pegawai'') or public.admin_boleh(''verval_akun'') then', 'admin_boleh(''kelola_pegawai'')');

-- 8g. Berkas: izin admin diperiksa lewat admin_boleh_pegawai; swafoto presensi untuk pemegang Verval presensi
do $$
declare v text; o oid;
begin
  select p.oid into o from pg_proc p join pg_namespace s on s.oid = p.pronamespace where s.nspname = 'public' and p.proname = 'boleh_lihat_berkas';
  if o is null then return; end if;
  v := pg_get_functiondef(o);
  if position('admin_boleh_pegawai' in v) = 0 then
    v := regexp_replace(v, 'v_peran = ''admin'' and exists \(select 1 from admin_permissions where employee_id = p_emp and kode = ''([a-z_]+)''\)',
                        'public.admin_boleh_pegawai(p_emp, ''\1'')', 'g');
    v := replace(v, 'if v_peran = ''superadmin'' then return true; end if;',
      'if v_peran = ''superadmin'' then return true; end if;
  -- Swafoto presensi (14.0.0): pemegang izin verval presensi, termasuk dari hak fitur
  if exists (select 1 from attendance_events ae where ae.selfie_id = p_obj) and public.admin_boleh_pegawai(p_emp, ''verval_presensi'') then
    return true;
  end if;');
    execute v;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 9. KEBIJAKAN BARIS (RLS)
-- ---------------------------------------------------------------------
do $$
declare r record; q text; w text; n int;
begin
  -- 9a. Data pegawai dan presensi: is_admin() → lihat_semua_pegawai() (dievaluasi sekali per kueri)
  for r in select * from pg_policies where schemaname = 'public' and cmd = 'SELECT'
             and tablename in ('employees','employee_functions','employee_structurals','employee_schedules','employment_history',
                               'attendances','attendance_events','attendance_status_history','task_patterns','institution_settings')
             and qual ~ 'is_admin\(\)' and qual !~ 'lihat_semua_pegawai' loop
    q := replace(r.qual, 'is_admin()', '( SELECT lihat_semua_pegawai() AS lihat_semua_pegawai)');
    execute format('alter policy %I on public.%I using (%s)', r.policyname, r.tablename, q);
  end loop;

  -- 9b. Organisasi: superadmin → juga pemegang Organisasi tingkat Input/ubah
  for r in select * from pg_policies where schemaname = 'public' and tablename in ('org_units','functional_positions','structural_positions')
             and cmd = 'ALL' and qual = 'is_superadmin()' loop
    q := '(is_superadmin() OR ( SELECT boleh_fitur(''organisasi''::text, 2) AS boleh_fitur))';
    execute format('alter policy %I on public.%I using (%s) with check (%s)', r.policyname, r.tablename, q, q);
  end loop;

  -- 9c. Audit log
  for r in select * from pg_policies where schemaname = 'public' and tablename = 'audit_logs' and cmd = 'SELECT'
             and qual ~ 'is_superadmin\(\)' and qual !~ 'audit_log' loop
    q := replace(r.qual, 'is_superadmin()', '(is_superadmin() OR ( SELECT boleh_fitur(''audit_log''::text, 1) AS boleh_fitur))');
    execute format('alter policy %I on public.%I using (%s)', r.policyname, r.tablename, q);
  end loop;

  -- 9d. admin_boleh di kebijakan dibungkus SELECT agar dihitung sekali per kueri (bukan per baris)
  for r in select * from pg_policies where schemaname = 'public'
             and (coalesce(qual, '') || coalesce(with_check, '')) ~ 'admin_boleh\('
             and (coalesce(qual, '') || coalesce(with_check, '')) !~ 'SELECT admin_boleh' loop
    q := regexp_replace(r.qual, 'admin_boleh\(''([a-z_]+)''::text\)', '( SELECT admin_boleh(''\1''::text) AS admin_boleh)', 'g');
    w := regexp_replace(r.with_check, 'admin_boleh\(''([a-z_]+)''::text\)', '( SELECT admin_boleh(''\1''::text) AS admin_boleh)', 'g');
    if q is not null and w is not null then
      execute format('alter policy %I on public.%I using (%s) with check (%s)', r.policyname, r.tablename, q, w);
    elsif q is not null then
      execute format('alter policy %I on public.%I using (%s)', r.policyname, r.tablename, q);
    else
      execute format('alter policy %I on public.%I with check (%s)', r.policyname, r.tablename, w);
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 10. HAK EKSEKUSI
-- ---------------------------------------------------------------------
revoke execute on function public._jabatan_pegawai(uuid) from public, anon, authenticated;
revoke execute on function public._tingkat(uuid, text) from public, anon, authenticated;
revoke execute on function public.admin_boleh_pegawai(uuid, text) from public, anon, authenticated;
revoke execute on function public.tingkat_fitur_pegawai(uuid, text) from public, anon, authenticated;
revoke execute on function public.notifikasi_admin(text, text, text, text, text, text) from public, anon, authenticated;
do $$ begin
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant execute on function public.admin_boleh_pegawai(uuid, text) to service_role;
    grant execute on function public._tingkat(uuid, text) to service_role;
    grant execute on function public.notifikasi_admin(text, text, text, text, text, text) to service_role;
  end if;
end $$;
do $$ declare f text; begin
  foreach f in array array['tingkat_fitur(text)', 'boleh_fitur(text,integer)', 'akses_luas(text)', 'izin_admin(text)', 'admin_boleh(text)',
                           'izin_admin_saya()', 'lihat_semua_pegawai()', 'boleh_pantauan()', 'boleh_lihat_shift(uuid)', 'boleh_ganti_ta()',
                           '_boleh_portal()', 'rincian_akses(uuid)', 'fitur_saya()'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 11. PEMERIKSAAN — hasil yang benar: semua baris "Sesuai"
-- ---------------------------------------------------------------------
select '1. Katalog: setiap menu punya fitur (39 atau lebih)' as pemeriksaan,
       case when (select count(*) from public.features where dipakai) >= 39 then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Lapis Semua pegawai tersedia (8 bawaan)',
       case when (select count(*) from public.feature_grants where sasaran = 'semua') >= 8 then 'Sesuai' else 'Periksa' end
union all
select '3. Izin admin dipetakan ke fitur',
       case when (select count(*) from public.capability_features) >= 25 then 'Sesuai' else 'Periksa' end
union all
select '4. Layar Pantauan tidak lagi otomatis untuk jabatan struktural',
       case when position('employee_structurals' in pg_get_functiondef('public.boleh_pantauan()'::regprocedure)) = 0
             and exists (select 1 from public.feature_grants where feature_kode = 'pantauan' and sasaran = 'struktural') then 'Sesuai' else 'Periksa' end
union all
select '5. Fungsi presensi dan laporan memakai lihat_semua_pegawai',
       case when (select count(*) from pg_proc where proname in ('statistik_presensi','rekap_harian','presensi_harian','riwayat_presensi','rekap_presensi','laporan_kehadiran_pegawai')
                   and prosrc ~ 'lihat_semua_pegawai') = 6 then 'Sesuai' else 'Periksa' end
union all
select '6. Kebijakan data pegawai memakai lihat_semua_pegawai',
       case when (select count(*) from pg_policies where schemaname = 'public' and qual ~ 'lihat_semua_pegawai') >= 9 then 'Sesuai' else 'Periksa' end
union all
select '7. admin_boleh di kebijakan dihitung sekali per kueri',
       case when not exists (select 1 from pg_policies where schemaname = 'public'
                              and (coalesce(qual, '') || coalesce(with_check, '')) ~ 'admin_boleh\('
                              and (coalesce(qual, '') || coalesce(with_check, '')) !~ 'SELECT admin_boleh') then 'Sesuai' else 'Periksa' end
union all
select '8. Berkas swafoto dan izin admin memakai admin_boleh_pegawai',
       case when (select prosrc from pg_proc where proname = 'boleh_lihat_berkas') ~ 'admin_boleh_pegawai' then 'Sesuai' else 'Periksa' end
union all
select '9. Superadmin tetap Kelola untuk semua fitur',
       case when coalesce((select min(public._tingkat(e.id, f.kode)) from public.employees e cross join public.features f where e.peran = 'superadmin'), 3) = 3
            then 'Sesuai' else 'Periksa' end;
