-- SIMKA PRO | supabase/migrations/20261017010900_kategori_ekskul_kelompok.sql | v1.0 | Perbaikan 13.7.1: kategori ekskul tersimpan dan tampil; dapat diatur dari Kelompok Santri | 16/10/2026
-- Penyebab: tampilan v_kelompok dibuat dengan "g.*" sebelum kolom kategori_ekskul ada. PostgreSQL membekukan daftar kolom
-- tampilan saat dibuat, sehingga nilai yang sudah tersimpan tidak pernah terbaca aplikasi (tampak "tidak tersimpan").
-- Perbaikan:
--   1. v_kelompok dibuat ulang (isi sama) agar memuat kolom kategori_ekskul dan kolom baru lain di student_groups.
--   2. simpan_kelompok_form menerima "kategori_ekskul" (indoor/outdoor/kosong) saat tambah/ubah kelompok berjenis ekskul.
-- Aman dijalankan ulang.

drop view if exists public.v_kelompok;
-- Kelompok beserta jumlah anggota dan pengasuh (nama pengasuh dapat dibaca semua yang berhak melihat kelompok)
create view public.v_kelompok as
select g.*, a.nama as tahun_ajaran, a.aktif as ta_aktif, a.terkunci as ta_terkunci,
  (select count(*) from group_members m where m.group_id = g.id and m.selesai is null)::int as jumlah,
  (select count(*) from group_members m join students s on s.id = m.student_id where m.group_id = g.id and m.selesai is null and s.jenis_kelamin = 'L')::int as jumlah_l,
  (select count(*) from group_members m join students s on s.id = m.student_id where m.group_id = g.id and m.selesai is null and s.jenis_kelamin = 'P')::int as jumlah_p,
  (select nama_lengkap from students where id = g.naqib_id) as nama_naqib,
  coalesce((select jsonb_agg(jsonb_build_object('employee_id', k.employee_id, 'nama', e.nama_lengkap, 'niy', e.niy,
                     'jenis_kelamin', e.jenis_kelamin, 'no_hp', case when (select public.is_admin()) then e.no_hp end,
                     'peran', k.peran, 'mulai', k.mulai, 'sampai', k.sampai, 'catatan', k.catatan,
                     'berlaku', (k.mulai is null or k.mulai <= public.hari_ini()) and (k.sampai is null or k.sampai >= public.hari_ini()))
                   order by array_position(array['utama','pendamping','pengganti'], k.peran), e.nama_lengkap)
            from group_keepers k join employees e on e.id = k.employee_id where k.group_id = g.id), '[]'::jsonb) as pengasuh,
  (g.id in (select public.kelompok_saya())) as asuhan_saya
from public.student_groups g
join public.academic_years a on a.id = g.academic_year_id
where (select public.is_admin()) or (select public.tingkat_fitur('data_santri')) >= 1
   or (select public.tingkat_fitur('kelompok_santri')) >= 1 or g.id in (select public.kelompok_saya());

grant select on public.v_kelompok to authenticated;
revoke select on public.v_kelompok from anon;

create or replace function public.simpan_kelompok_form(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_kode text; v_kendala text; v_pesan text; v_id uuid; v_kat text;
begin
  v_id := public.simpan_kelompok(p);   -- hak akses dan validasi dasar diperiksa di sini
  if p ? 'kategori_ekskul' then
    v_kat := nullif(trim(coalesce(p->>'kategori_ekskul', '')), '');
    if v_kat is not null and v_kat not in ('indoor','outdoor') then
      raise exception 'Kategori ekskul harus Indoor atau Outdoor.' using errcode = '22023';
    end if;
    update student_groups set kategori_ekskul = v_kat where id = v_id and jenis = 'ekskul';
  end if;
  return v_id;
exception when others then
  get stacked diagnostics v_kode = returned_sqlstate, v_kendala = constraint_name, v_pesan = message_text;
  raise exception '%', public._pesan_kelompok(v_kode, coalesce(v_kendala, ''), v_pesan) using errcode = v_kode;
end $$;
revoke execute on function public.simpan_kelompok_form(jsonb) from public, anon;
grant execute on function public.simpan_kelompok_form(jsonb) to authenticated;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 3 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select 'Tampilan v_kelompok memuat kategori_ekskul' as pemeriksaan,
       case when exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'v_kelompok'
                          and column_name = 'kategori_ekskul') then 'Sesuai' else 'Periksa' end as hasil
union all
select 'v_kelompok dapat dibaca pengguna masuk, tidak untuk anon',
       case when has_table_privilege('authenticated', 'public.v_kelompok', 'select')
             and not has_table_privilege('anon', 'public.v_kelompok', 'select') then 'Sesuai' else 'Periksa' end
union all
select 'simpan_kelompok_form menyimpan kategori ekskul',
       case when pg_get_functiondef('public.simpan_kelompok_form(jsonb)'::regprocedure) like '%kategori_ekskul%' then 'Sesuai' else 'Periksa' end;
