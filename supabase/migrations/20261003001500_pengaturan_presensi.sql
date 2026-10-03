-- SIMKA PRO | supabase/migrations/20261003001500_pengaturan_presensi.sql | v1.0 | Fase 2 – Tahap 3 Pengaturan presensi | 03/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 2 · Migrasi 15: Fungsi bantu menu Pengaturan Presensi
--   * pratinjau_jadwal  : jadwal gabungan seorang pegawai pada rentang tanggal (cek bertumpuk)
--   * atur_pola_jabatan : pola bawaan jabatan fungsional (admin ber-izin atur_presensi)
--   * izin_admin_saya   : daftar izin admin milik pengguna (untuk menampilkan tombol)
--   * admin dapat membaca pengaturan presensi (mengubah tetap superadmin)
-- =====================================================================

create or replace function public.pratinjau_jadwal(p_emp uuid, p_mulai date, p_akhir date default null)
returns table (tanggal date, session_id uuid, pattern_id uuid, jenis_pola text, nama_pola text, nama_sesi text,
               mulai timestamptz, selesai timestamptz, buka timestamptz, tutup timestamptz,
               wajib_pulang boolean, opsional boolean, warna text)
language plpgsql stable security definer set search_path = public as $$
begin
  if not (public.is_admin() or p_emp = public.saya() or public.pimpinan_dari(p_emp)) then
    raise exception 'Anda tidak berhak melihat jadwal pegawai ini.' using hint = 'TANPA_IZIN';
  end if;
  if coalesce(p_akhir, p_mulai) - p_mulai > 62 then
    raise exception 'Rentang pratinjau paling lama 2 bulan.' using hint = 'RENTANG_PANJANG';
  end if;
  return query
    select j.tanggal, j.session_id, j.pattern_id, j.jenis_pola, j.nama_pola, j.nama_sesi,
           j.mulai, j.selesai, j.buka, j.tutup, j.wajib_pulang, j.opsional, j.warna
      from generate_series(p_mulai::timestamp, coalesce(p_akhir, p_mulai)::timestamp, interval '1 day') d
      cross join lateral public.jadwal_pegawai(p_emp, d::date) j
     order by j.mulai;
end $$;

create or replace function public.atur_pola_jabatan(p_jabatan uuid, p_pola uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  if not public.admin_boleh('atur_presensi') then
    raise exception 'Anda tidak memiliki izin mengatur presensi.' using hint = 'TANPA_IZIN';
  end if;
  if p_pola is not null and not exists (select 1 from task_patterns where id = p_pola and employee_id is null) then
    raise exception 'Pola tidak ditemukan atau merupakan pola pribadi.' using hint = 'POLA_TIDAK_SAH';
  end if;
  update functional_positions set pola_id = p_pola where id = p_jabatan;   -- pemicu menyinkronkan jadwal
end $$;

create or replace function public.izin_admin_saya()
returns text[] language sql stable security definer set search_path = public as $$
  select case
    when public.is_superadmin() then (select coalesce(array_agg(kode), '{}') from admin_capabilities)
    else coalesce((select array_agg(ap.kode) from admin_permissions ap where ap.employee_id = public.saya()), '{}')
  end
$$;

-- Admin boleh membaca pengaturan presensi; mengubah tetap hanya superadmin (kebijakan kelola Fase 1)
drop policy if exists baca_presensi on public.institution_settings;
create policy baca_presensi on public.institution_settings for select to authenticated
  using (kunci = 'presensi' and public.is_admin());

revoke execute on function public.pratinjau_jadwal(uuid, date, date) from public, anon;
revoke execute on function public.atur_pola_jabatan(uuid, uuid) from public, anon;
revoke execute on function public.izin_admin_saya() from public, anon;
grant execute on function public.pratinjau_jadwal(uuid, date, date) to authenticated;
grant execute on function public.atur_pola_jabatan(uuid, uuid) to authenticated;
grant execute on function public.izin_admin_saya() to authenticated;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 2 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select 'Fungsi pengaturan presensi (3)' as pemeriksaan,
       case when count(*) = 3 then 'Sesuai' else 'Periksa: ' || count(*) end as hasil
  from pg_proc where pronamespace = 'public'::regnamespace
   and proname in ('pratinjau_jadwal','atur_pola_jabatan','izin_admin_saya')
union all
select 'Migrasi presensi sebelumnya (1200–1400) terpasang',
       case when exists (select 1 from public.task_patterns where kode = 'GURU') then 'Sesuai' else 'Periksa' end;
