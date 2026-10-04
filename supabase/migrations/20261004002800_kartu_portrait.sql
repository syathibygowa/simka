-- SIMKA PRO | supabase/migrations/20261004002800_kartu_portrait.sql | v1.0 | Fase 3 – Perbaikan P4 (kartu pegawai portrait) | 04/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 3 · Migrasi 28: Data kartu pegawai tegak (portrait)
--   * data_kartu() menambah "jabatan_kartu": jabatan struktural bila ada; bila tidak, satu jabatan fungsional
--     menurut urutan jabatan (Guru, Muhaffizh, Musyrif, Medis, Security, …). Kolom "jabatan" (lengkap) tetap ada.
--   * Foto kartu = foto profil akun (employees.foto_id), diganti dari menu Profil atau Kartu Pegawai.
-- Jalankan SETELAH migrasi 2700. Aman dijalankan ulang.
-- =====================================================================

drop function if exists public.data_kartu(uuid[]);
create or replace function public.data_kartu(p_emps uuid[] default null)
returns table (employee_id uuid, nama text, niy text, jenis_kelamin text, jabatan text, jabatan_kartu text, unit text, foto_id uuid,
               kode text, aktif boolean, tmt_tugas date)
language plpgsql volatile security definer set search_path = public as $$
declare v_ids uuid[];
begin
  if p_emps is null then v_ids := array[public.saya()];
  elsif public.admin_boleh('cetak_kartu') then v_ids := p_emps;
  else raise exception 'Anda tidak berwenang mencetak kartu pegawai lain.' using errcode = '42501';
  end if;
  insert into employee_cards (employee_id, kode)
  select x, public._kode_kartu() from unnest(v_ids) x
   where x is not null and not exists (select 1 from employee_cards c where c.employee_id = x)
  on conflict do nothing;
  return query
  select e.id, e.nama_lengkap, e.niy, e.jenis_kelamin,
         nullif(concat_ws(', ', (select string_agg(sp.nama, ', ') from employee_structurals es join structural_positions sp on sp.id = es.structural_position_id where es.employee_id = e.id),
                (select string_agg(fp.nama, ', ' order by fp.urutan) from employee_functions ef join functional_positions fp on fp.id = ef.functional_position_id where ef.employee_id = e.id)), ''),
         coalesce((select sp.nama from employee_structurals es join structural_positions sp on sp.id = es.structural_position_id
                    where es.employee_id = e.id order by sp.tingkat limit 1),
                  (select fp.nama from employee_functions ef join functional_positions fp on fp.id = ef.functional_position_id
                    where ef.employee_id = e.id order by fp.urutan limit 1), 'Pegawai'),
         u.nama, e.foto_id, c.kode, e.status_keaktifan = 'aktif', e.tmt_tugas
    from employees e join employee_cards c on c.employee_id = e.id left join org_units u on u.id = e.org_unit_id
   where e.id = any (v_ids)
   order by u.nama nulls last, e.nama_lengkap;
end $$;
revoke execute on function public.data_kartu(uuid[]) from public, anon;
grant execute on function public.data_kartu(uuid[]) to authenticated;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 2 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select 'Data kartu memuat jabatan kartu' as pemeriksaan,
       case when position('jabatan_kartu' in pg_get_function_result('public.data_kartu(uuid[])'::regprocedure)) > 0 then 'Sesuai' else 'Periksa' end as hasil
union all
select 'Migrasi 2700 sudah terpasang',
       case when exists (select 1 from pg_tables where tablename = 'document_categories') then 'Sesuai' else 'Periksa: jalankan 2700 dulu' end;
