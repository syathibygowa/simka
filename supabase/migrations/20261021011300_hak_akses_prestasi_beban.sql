-- SIMKA PRO | supabase/migrations/20261021011300_hak_akses_prestasi_beban.sql | v1.0 | Perbaikan 14.0.1: Prestasi Santri, Beban Kerja, dan kartu pelajar mengikuti Hak Akses | 17/10/2026
-- =====================================================================
-- SIMKA PRO · Migrasi 113: lanjutan Hak Akses untuk fungsi Fase 12 lanjutan (migrasi 8500–9600)
--   1. Prestasi Santri : Lihat = melihat prestasi seluruh santri; Input/ubah = mencatat, mengubah, menghapus prestasi.
--                        Pimpinan unit dan pengasuh kelompok tetap otomatis (tugas).
--   2. Beban Kerja     : Lihat = melihat beban kerjanya sendiri; Input/ubah = rekap beban kerja seluruh pegawai;
--                        Kelola = mengatur jam tupoksi (izin admin Atur beban kerja, sudah dipetakan di 14.0.0).
--                        Pimpinan tetap melihat anggota unitnya; sakelar "tampil di akun pegawai" tetap berlaku.
--   3. Kartu pelajar   : cetak kartu pelajar seluruh santri = admin ber-izin Cetak kartu atau Data santri tingkat Kelola
--                        (bukan pemegang Data pegawai, yang izinnya untuk kartu pegawai).
-- Penilaian tidak diubah: menunya sudah terbuka bagi pemegang "Penilaian dan rapor" tingkat Kelola.
-- Jalankan SETELAH migrasi 11200. Aman dijalankan ulang.
-- =====================================================================

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

-- ---------------------------------------------------------------------
-- 1. PRESTASI SANTRI
-- ---------------------------------------------------------------------
select pg_temp.tambal('daftar_prestasi',
  'where a.student_id in (select public.santri_terlihat())',
  'where (public.boleh_fitur(''prestasi'') or a.student_id in (select public.santri_terlihat()))', 'boleh_fitur(''prestasi'') or a.student_id');
select pg_temp.tambal('daftar_prestasi',
  '''boleh_ubah'', a.dicatat_oleh = public.saya() or',
  '''boleh_ubah'', a.dicatat_oleh = public.saya() or public.boleh_fitur(''prestasi'', 2) or', 'boleh_fitur(''prestasi'', 2)');
select pg_temp.tambal('boleh_catat_prestasi',
  'select public.admin_boleh(''kelola_santri'')',
  'select public.admin_boleh(''kelola_santri'') or public.boleh_fitur(''prestasi'', 2)', 'boleh_fitur(''prestasi'', 2)');
select pg_temp.tambal('simpan_prestasi',
  'v_lama.dicatat_oleh = v_saya or public.admin_boleh(''kelola_santri'')',
  'v_lama.dicatat_oleh = v_saya or public.admin_boleh(''kelola_santri'') or public.boleh_fitur(''prestasi'', 2)', 'boleh_fitur(''prestasi'', 2)');
select pg_temp.tambal('hapus_prestasi',
  'v.dicatat_oleh = public.saya() or public.admin_boleh(''kelola_santri'')',
  'v.dicatat_oleh = public.saya() or public.admin_boleh(''kelola_santri'') or public.boleh_fitur(''prestasi'', 2)', 'boleh_fitur(''prestasi'', 2)');

-- ---------------------------------------------------------------------
-- 2. BEBAN KERJA
-- ---------------------------------------------------------------------
select pg_temp.tambal('hak_beban',
  '''rekap'', public.is_admin() or',
  '''rekap'', public.is_admin() or public.boleh_fitur(''beban_kerja'', 2) or', 'boleh_fitur(''beban_kerja'', 2)');
select pg_temp.tambal('hak_beban',
  '''saya'', coalesce((select beban_terlihat from employees where id = public.saya()), false)',
  '''saya'', coalesce((select beban_terlihat from employees where id = public.saya()), false) or public.boleh_fitur(''beban_kerja'')', 'boleh_fitur(''beban_kerja'')');
select pg_temp.tambal('boleh_lihat_beban',
  'or public.boleh_atur_beban() or public.is_admin()',
  'or public.boleh_atur_beban() or public.is_admin() or public.boleh_fitur(''beban_kerja'', 2) or (p_emp = public.saya() and public.boleh_fitur(''beban_kerja''))', 'boleh_fitur(''beban_kerja''');

-- ---------------------------------------------------------------------
-- 3. KARTU PELAJAR SANTRI
-- ---------------------------------------------------------------------
select pg_temp.tambal('data_kartu_santri',
  'public.admin_boleh(''cetak_kartu'')',
  '(public.izin_admin(''cetak_kartu'') or public.boleh_fitur(''data_santri'', 3))', 'izin_admin(''cetak_kartu'')');
select pg_temp.tambal('ganti_kode_kartu_santri',
  'public.admin_boleh(''cetak_kartu'')',
  '(public.izin_admin(''cetak_kartu'') or public.boleh_fitur(''data_santri'', 3))', 'izin_admin(''cetak_kartu'')');

-- ---------------------------------------------------------------------
-- 4. ARTI TINGKAT DI KATALOG (sama dengan src/lib/hakAkses.js v2.1)
-- ---------------------------------------------------------------------
update public.features set arti = v.arti::jsonb, keterangan = v.ket
from (values
  ('prestasi', '{"1": "Melihat prestasi seluruh santri", "2": "Mencatat, mengubah, dan menghapus prestasi santri", "3": "Sama dengan input/ubah"}',
   'Pengasuh kelompok dan pimpinan unit otomatis untuk santrinya. Santri yang dapat dipilih saat mencatat mengikuti Data santri. Bawaan disalin dari Data santri dan jabatan pimpinan.'),
  ('beban_kerja', '{"1": "Melihat beban kerjanya sendiri", "2": "Melihat rekap beban kerja seluruh pegawai", "3": "Juga mengatur jam tupoksi, tugas tambahan, dan tampilan di akun pegawai"}',
   'Pimpinan tetap melihat beban kerja anggota unitnya. Pegawai yang dinyalakan "tampil di akun pegawai" tetap melihat beban kerjanya sendiri.'),
  ('data_santri', '{"1": "Melihat data seluruh santri", "2": "Menambah dan mengubah data santri", "3": "Juga mengimpor, memutasi keluar, mengubah status, dan mencetak kartu pelajar santri"}',
   'Juga membuka menu Tahfizh, Klinik, Perizinan, dan Libur Santri untuk dilihat.')
) v(kode, arti, ket) where public.features.kode = v.kode;

-- ---------------------------------------------------------------------
-- 5. PEMERIKSAAN — hasil yang benar: 4 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select '1. Prestasi mengikuti fitur Prestasi santri' as pemeriksaan,
       case when (select count(*) from pg_proc where proname in ('daftar_prestasi','boleh_catat_prestasi','simpan_prestasi','hapus_prestasi')
                   and prosrc ~ 'boleh_fitur\(''prestasi''') = 4 then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Beban kerja mengikuti fitur Beban kerja',
       case when (select count(*) from pg_proc where proname in ('hak_beban','boleh_lihat_beban') and prosrc ~ 'boleh_fitur\(''beban_kerja''') = 2
            then 'Sesuai' else 'Periksa' end
union all
select '3. Kartu pelajar tidak lagi terbuka bagi pemegang Data pegawai',
       case when (select count(*) from pg_proc where proname in ('data_kartu_santri','ganti_kode_kartu_santri') and prosrc ~ 'izin_admin\(''cetak_kartu''\)') = 2
            then 'Sesuai' else 'Periksa' end
union all
select '4. Arti tingkat Prestasi dan Beban kerja diperbarui',
       case when (select count(*) from public.features where (kode = 'prestasi' and arti ->> '2' like 'Mencatat, mengubah, dan menghapus%')
                                                          or (kode = 'beban_kerja' and arti ->> '2' like 'Melihat rekap%')) = 2
            then 'Sesuai' else 'Periksa' end;
