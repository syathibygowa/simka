-- SIMKA PRO | supabase/migrations/20261005004200_perbaikan_ganti_sandi.sql | v1.0 | Perbaikan: ganti sandi berulang terus-menerus | 05/10/2026
-- =====================================================================
-- MASALAH: setelah admin mengatur ulang sandi (sandi sementara) atau akun baru dibuat, pegawai diwajibkan mengganti sandi.
--   Sandi baru memang tersimpan, tetapi fungsi selesai_ganti_sandi() GAGAL menghapus penanda wajib_ganti_sandi karena
--   pemicu penjaga data pegawai (tg_employees_jaga) menolak pegawai/admin mengubah kolom sistem itu. Galatnya tidak
--   ditampilkan aplikasi, sehingga setiap kali masuk pegawai diminta mengganti sandi lagi tanpa henti.
-- PERBAIKAN: selesai_ganti_sandi() kini menghapus penanda sebagai proses sistem (seperti Edge Function), hanya untuk
--   baris pegawai yang sedang masuk dan hanya kolom wajib_ganti_sandi = false. Mengembalikan true bila berhasil.
-- Berdiri sendiri: dapat dijalankan langsung di sistem v4.5.0 maupun setelah migrasi Fase 5. Aman dijalankan ulang.
-- =====================================================================

drop function if exists public.selesai_ganti_sandi();
create function public.selesai_ganti_sandi()
returns boolean language plpgsql volatile security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_sub text := current_setting('request.jwt.claim.sub', true);
  v_claims text := current_setting('request.jwt.claims', true);
  v_n int;
begin
  if v_uid is null then raise exception 'Sesi masuk tidak berlaku. Silakan masuk ulang.' using errcode = '42501'; end if;
  -- Jalankan pembaruan sebagai proses sistem agar tidak ditolak penjaga kolom (identitas dipulihkan sesudahnya)
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', '', true);
  update employees set wajib_ganti_sandi = false where user_id = v_uid and wajib_ganti_sandi;
  get diagnostics v_n = row_count;
  perform set_config('request.jwt.claim.sub', coalesce(v_sub, ''), true);
  perform set_config('request.jwt.claims', coalesce(v_claims, ''), true);
  return true;
end $$;
revoke execute on function public.selesai_ganti_sandi() from public, anon;
grant execute on function public.selesai_ganti_sandi() to authenticated;

-- PEMERIKSAAN — hasil yang benar: 2 baris, semuanya "Sesuai"
select 'Fungsi selesai_ganti_sandi diperbarui' as pemeriksaan,
       case when (select prorettype::regtype::text from pg_proc where proname = 'selesai_ganti_sandi') = 'boolean' then 'Sesuai' else 'Periksa' end as hasil
union all
select 'Jumlah akun yang masih wajib ganti sandi: ' || (select count(*) from public.employees where wajib_ganti_sandi and status_akun = 'aktif')::text
       || ' (akan hilang setelah pemiliknya mengganti sandi sekali lagi)', 'Sesuai';
