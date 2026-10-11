-- SIMKA PRO | supabase/migrations/20261012007900_data_presensi.sql | v1.0 | Fase 3 – Menu Data Presensi (harian per bidang dan bulanan) | 12/10/2026
-- =====================================================================
-- Menu Data Presensi (dipisah dari tab Verval Presensi):
--   presensi_hari_pegawai(tanggal, bidang) → setiap pegawai aktif (bidang beserta cabangnya, atau semua)
--     beserta sesi presensinya pada tanggal itu (sama dengan presensi_harian: jadwal + data tercatat + keadaan).
--   Hak: superadmin dan admin ber-izin verval_presensi.
--   Rekap bulanan memakai laporan_kehadiran_pegawai (cakupan bidang/semua, rinci) yang sudah ada.
-- Jalankan SETELAH migrasi 7800. Aman dijalankan ulang.
-- =====================================================================
create or replace function public.presensi_hari_pegawai(p_tanggal date default null, p_unit uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_hari date := coalesce(p_tanggal, public.hari_ini()); v_hasil jsonb;
begin
  if public.saya() is null then raise exception 'Akun Anda belum aktif.' using hint = 'AKUN_TIDAK_AKTIF'; end if;
  if not public.admin_boleh('verval_presensi') then
    raise exception 'Menu ini memerlukan izin verval presensi.' using errcode = '42501', hint = 'TANPA_IZIN';
  end if;
  if v_hari > public.hari_ini() + 31 then raise exception 'Tanggal terlalu jauh ke depan.'; end if;

  select coalesce(jsonb_agg(x order by x->>'nama'), '[]'::jsonb) into v_hasil from (
    select jsonb_build_object(
      'employee_id', e.id, 'nama', e.nama_lengkap, 'niy', e.niy, 'jenis_kelamin', e.jenis_kelamin,
      'org_unit_id', e.org_unit_id, 'unit', u.nama,
      'jabatan', (select string_agg(fp.nama, ', ' order by fp.urutan) from employee_functions ef
                    join functional_positions fp on fp.id = ef.functional_position_id where ef.employee_id = e.id),
      'sesi', coalesce(public.presensi_harian(e.id, v_hari)->'sesi', '[]'::jsonb)) x
      from employees e left join org_units u on u.id = e.org_unit_id
     where e.status_akun = 'aktif' and e.status_keaktifan = 'aktif' and e.peran <> 'superadmin'
       and (p_unit is null or e.org_unit_id in (select public.unit_turunan(p_unit)))) q;

  return jsonb_build_object('tanggal', v_hari, 'jam', to_char(now() at time zone 'Asia/Makassar', 'HH24:MI'), 'pegawai', v_hasil);
end $$;
revoke execute on function public.presensi_hari_pegawai(date, uuid) from public, anon;
grant execute on function public.presensi_hari_pegawai(date, uuid) to authenticated;

-- ---------------------------------------------------------------------
-- Pemeriksaan (hasil yang benar):
--   1) fungsi ada                                → 1
--   2) tidak dapat dipanggil anon                → false
-- ---------------------------------------------------------------------
select count(*) as fungsi_ada from pg_proc where proname = 'presensi_hari_pegawai';
select has_function_privilege('anon', 'public.presensi_hari_pegawai(date, uuid)', 'execute') as anon_boleh;
