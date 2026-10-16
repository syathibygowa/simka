-- SIMKA PRO | supabase/migrations/20261019011100_katalog_hak_akses.sql | v1.0 | Perbaikan 13.9.0: katalog Hak Akses Fitur diperbarui sesuai menu terkini; izin admin Kelola pengumuman | 16/10/2026
-- 1. Tabel features mendapat keterangan agar mudah diatur di menu Hak Akses:
--      menu   : menu/tab yang dikendalikan fitur ini
--      arti   : arti setiap tingkat {"1": lihat, "2": input/ubah, "3": kelola} sesuai pemeriksaan di server
--      dipakai: false = fitur lama yang tidak lagi diatur di sini (otomatis untuk semua pegawai, khusus superadmin,
--               atau sudah tergabung dalam fitur lain). Aturan lamanya tetap tersimpan tetapi tidak ditampilkan.
-- 2. Nama dan pengelompokan 15 fitur yang berlaku diselaraskan dengan nama menu sekarang.
-- 3. Izin admin baru "kelola_pengumuman". Sebelumnya semua admin otomatis dapat membuat pengumuman; kini dapat
--    dicentang per admin. Semua admin yang sudah ada langsung diberi izin ini agar tidak ada yang berubah.
-- Aman dijalankan ulang.

alter table public.features add column if not exists menu       text;
alter table public.features add column if not exists arti       jsonb not null default '{}'::jsonb;
alter table public.features add column if not exists keterangan text;
alter table public.features add column if not exists dipakai    boolean not null default true;

insert into public.features (kode, nama, kelompok, urutan, menu, arti, keterangan, dipakai) values
  ('data_santri', 'Data santri', 'Santri', 1, 'Data Santri, Statistik Santri, Kelengkapan Data, Prestasi Santri', '{"1": "Melihat data seluruh santri dan statistiknya", "2": "Menambah dan mengubah data santri", "3": "Sama dengan input/ubah"}'::jsonb, 'Juga membuka menu Tahfizh, Klinik, Perizinan, dan Libur Santri untuk dilihat.', true),
  ('kelompok_santri', 'Kelompok santri', 'Santri', 2, 'Kelompok Santri, kategori Ekskul', '{"1": "Melihat semua kelompok (kelas, kamar, halaqah, ekskul)", "2": "Mengatur kelompok, pengasuh, anggota, dan kategori ekskul", "3": "Sama dengan input/ubah"}'::jsonb, null, true),
  ('absensi_kelas', 'Absensi kelas dan wali kelas', 'Santri', 3, 'Absensi Santri, Wali Kelas', '{"1": "Memantau absensi kelas seluruh santri (perlu juga Data santri ≥ Lihat)", "2": "Sama dengan lihat", "3": "Sama dengan lihat"}'::jsonb, 'Wali kelas yang ditetapkan pada kelasnya otomatis dapat mengisi.', true),
  ('absensi_asrama', 'Absensi asrama (musyrif)', 'Santri', 4, 'Musyrif, Absensi Santri', '{"1": "Memantau absensi asrama dan jurnal musyrif semua kamar", "2": "Sama dengan lihat", "3": "Sama dengan lihat"}'::jsonb, 'Musyrif yang ditetapkan pada kamarnya otomatis dapat mengisi.', true),
  ('absensi_ekskul', 'Ekskul', 'Santri', 5, 'Ekskul (dasbor, pertemuan, jadwal, rekap, nilai)', '{"1": "Memantau semua ekskul, jurnal latihan, dan nilai ekskul", "2": "Sama dengan lihat", "3": "Sama dengan lihat"}'::jsonb, 'Pembina yang ditetapkan pada ekskulnya otomatis dapat mengisi.', true),
  ('tahfizh', 'Tahfizh', 'Santri', 6, 'Tahfizh', '{"1": "Melihat data tahfizh semua halaqah", "2": "Sama dengan lihat", "3": "Mengatur ketentuan tahfizh dan memvalidasi capaian hafalan"}'::jsonb, 'Muhaffizh yang ditetapkan pada halaqahnya otomatis dapat mengisi setoran.', true),
  ('jadwal_mengajar', 'Jadwal pelajaran dan guru mapel', 'Santri', 7, 'Jadwal Pelajaran, Guru Mapel, Wali Kelas (pantau)', '{"1": "Melihat jadwal pelajaran", "2": "Sama dengan lihat", "3": "Mengatur jadwal dan penugasan, memantau jurnal mengajar semua guru"}'::jsonb, 'Guru yang memiliki penugasan mengajar otomatis mengisi jurnalnya.', true),
  ('nilai', 'Penilaian dan rapor', 'Santri', 8, 'Penilaian', '{"1": "Belum berpengaruh", "2": "Belum berpengaruh", "3": "Mengatur penilaian, mengelola nilai, dan mencetak rapor"}'::jsonb, null, true),
  ('klinik', 'Klinik', 'Layanan', 1, 'Klinik', '{"1": "Membuka menu Klinik", "2": "Sama dengan lihat", "3": "Mengelola ketentuan dan seluruh catatan pemeriksaan"}'::jsonb, 'Petugas kesehatan diatur di Klinik → Petugas.', true),
  ('perizinan_santri', 'Perizinan dan libur santri', 'Layanan', 2, 'Perizinan, Libur Santri', '{"1": "Melihat perizinan dan libur santri", "2": "Sama dengan lihat", "3": "Mengelola semua izin santri dan ketentuannya"}'::jsonb, 'Pemutus izin mengikuti jabatan struktural (Kepala Bidang Kesantrian, Direktur/Wadir, Plt).', true),
  ('gerbang', 'Security', 'Layanan', 3, 'Security (gerbang, titipan, buku tamu, kunjungan)', '{"1": "Melihat aktivitas security", "2": "Petugas: mencatat keluar-masuk, titipan, tamu, dan kunjungan", "3": "Mengelola ketentuan security"}'::jsonb, null, true),
  ('pantauan', 'Pantauan pimpinan', 'Layanan', 4, 'Layar Pantauan, kartu pimpinan di Beranda', '{"1": "Membuka layar pantauan dan dasbor pimpinan", "2": "Sama dengan lihat", "3": "Sama dengan lihat"}'::jsonb, 'Pejabat struktural otomatis mendapat pantauan untuk unitnya.', true),
  ('lapor_bidang', 'Laporan ke bidang', 'Layanan', 5, 'Laporan', '{"1": "Belum berpengaruh", "2": "Belum berpengaruh", "3": "Mengelola semua laporan, kategori, dan rekap"}'::jsonb, 'Setiap pegawai dapat membuat laporan; penerima mengikuti kategori.', true),
  ('tata_usaha', 'Persuratan', 'Administrasi', 1, 'Persuratan', '{"1": "Membuka menu Persuratan", "2": "Mengelola surat masuk, surat keluar, dan buku agenda", "3": "Sama dengan input/ubah"}'::jsonb, 'Pimpinan penerima surat dan penerima disposisi otomatis dapat membuka.', true),
  ('pengumuman', 'Pengumuman', 'Sistem', 1, 'Pengumuman, Pengumuman wali', '{"1": "Belum berpengaruh (semua pegawai membaca pengumuman)", "2": "Membuat pengumuman pegawai", "3": "Sama dengan input/ubah"}'::jsonb, 'Pimpinan unit dapat membuat pengumuman untuk wali santri.', true)
on conflict (kode) do update set nama = excluded.nama, kelompok = excluded.kelompok, urutan = excluded.urutan,
  menu = excluded.menu, arti = excluded.arti, keterangan = excluded.keterangan, dipakai = true;

update public.features f set dipakai = false, keterangan = v.ket
from (values
  ('data_pegawai', 'Diatur lewat izin admin "Mengelola data kepegawaian".'),
  ('presensi', 'Otomatis untuk setiap pegawai; pengaturan lewat izin admin Presensi.'),
  ('pengajuan', 'Otomatis untuk setiap pegawai; pengaturan lewat izin admin Pengajuan.'),
  ('jurnal_harian', 'Otomatis untuk setiap pegawai; verval lewat izin admin Jurnal.'),
  ('berkas_pegawai', 'Otomatis untuk setiap pegawai; pengiriman lewat izin admin Berkas.'),
  ('kartu_pegawai', 'Otomatis untuk setiap pegawai; cetak massal lewat izin admin.'),
  ('absensi_halaqah', 'Tergabung dalam fitur Tahfizh dan muhaffizh pada halaqahnya.'),
  ('titipan', 'Tergabung dalam fitur Security.'),
  ('buku_tamu', 'Tergabung dalam fitur Security.'),
  ('kunjungan', 'Tergabung dalam fitur Security.'),
  ('laporan', 'Menu Dokumen terbuka untuk semua pegawai sesuai cakupannya.'),
  ('template_wa', 'Khusus superadmin (Setelan → Template WA).'),
  ('pengaturan_lembaga', 'Khusus superadmin (Setelan).'),
  ('hak_akses', 'Khusus superadmin.')
) v(kode, ket) where f.kode = v.kode;

-- ---------------------------------------------------------------------
-- Izin admin: Kelola pengumuman
-- ---------------------------------------------------------------------
insert into public.admin_capabilities (kode, nama, urutan)
values ('kelola_pengumuman', 'Membuat dan mengelola pengumuman pegawai dan Portal Wali', 4)
on conflict (kode) do update set nama = excluded.nama;

-- Admin yang sudah ada tetap dapat membuat pengumuman (hanya saat izin ini pertama kali dibuat)
insert into public.admin_permissions (employee_id, kode)
select e.id, 'kelola_pengumuman' from public.employees e
where e.peran = 'admin'
  and not exists (select 1 from public.admin_permissions p where p.kode = 'kelola_pengumuman')
on conflict do nothing;

create or replace function public.boleh_umumkan()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_superadmin() or public.admin_boleh('kelola_pengumuman') or public.tingkat_fitur('pengumuman') >= 2
$$;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 4 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select 'Kolom keterangan fitur tersedia' as pemeriksaan,
       case when (select count(*) from information_schema.columns where table_schema = 'public' and table_name = 'features'
                   and column_name in ('menu','arti','keterangan','dipakai')) = 4 then 'Sesuai' else 'Periksa' end as hasil
union all
select 'Fitur yang berlaku (15) memiliki arti tingkat',
       case when (select count(*) from public.features where dipakai and arti ? '1') = 15 then 'Sesuai' else 'Periksa' end
union all
select 'Fitur lama ditandai tidak diatur (14)',
       case when (select count(*) from public.features where not dipakai) = 14 then 'Sesuai' else 'Periksa' end
union all
select 'Izin admin Kelola pengumuman tersedia',
       case when exists (select 1 from public.admin_capabilities where kode = 'kelola_pengumuman') then 'Sesuai' else 'Periksa' end;
