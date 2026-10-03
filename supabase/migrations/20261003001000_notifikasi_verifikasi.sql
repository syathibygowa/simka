-- SIMKA PRO | supabase/migrations/20261003001000_notifikasi_verifikasi.sql | v1.0 | Fase 1 – Akun dan hak akses | 03/10/2026
-- Notifikasi "Pendaftaran pegawai baru" kini membuka halaman Verifikasi Akun secara langsung.
-- Aman dijalankan ulang.
create or replace function public.tg_employees_notif()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status_akun = 'menunggu' and (TG_OP = 'INSERT' or old.status_akun is distinct from 'menunggu') then
    perform public.notifikasi_admin('verval_akun', 'Pendaftaran pegawai baru',
      new.nama_lengkap || ' menunggu verifikasi akun.', '/verifikasi/menunggu', 'UserPlus', 'biru');
  elsif TG_OP = 'UPDATE' and new.status_akun = 'aktif' and old.status_akun is distinct from 'aktif' then
    perform public.kirim_notifikasi(new.id, 'Akun Anda telah aktif',
      'Selamat bergabung di SIMKA PRO. Lengkapi profil Anda bila masih ada data yang kosong.',
      '/profil', 'CheckCircle', 'hijau');
  end if;
  return new;
end $$;

-- Notifikasi lama yang menunjuk halaman pegawai ikut diarahkan ke halaman verifikasi
update public.notifications set tautan = '/verifikasi/menunggu'
where judul = 'Pendaftaran pegawai baru' and tautan like '/pegawai/%';

-- Pemeriksaan: harus tampil 1 baris "Notifikasi verifikasi diperbarui"
select 'Notifikasi verifikasi diperbarui' as hasil
from pg_proc where proname = 'tg_employees_notif' and prosrc like '%/verifikasi/menunggu%';
