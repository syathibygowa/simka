-- SIMKA PRO | supabase/migrations/20261017010300_klinik_rujuk_bukan_medis.sql | v1.0 | Perbaikan 13.6.0 Rujuk santri hanya dari pegawai non-medis | 15/10/2026
-- =====================================================================
-- SIMKA PRO · Migrasi 103: Rujuk santri tidak tersedia bagi tenaga klinik
--   Rujukan = pegawai lain (wali kelas, musyrif, muhaffizh, dll.) melaporkan santri sakit untuk ditangani klinik.
--   Tenaga klinik (jabatan fungsional MEDIS atau terdaftar sebagai petugas klinik putra/putri) tidak merujuk ke dirinya sendiri;
--   santri yang datang langsung dicatat lewat Klinik → Periksa.
--   * _tenaga_klinik_saya() : pengguna adalah tenaga klinik
--   * hak_klinik().rujuk    : false bagi tenaga klinik (+ kunci baru tenaga_klinik)
--   * buat_rujukan          : menolak bila dipanggil tenaga klinik
-- Jalankan SETELAH migrasi 10200. Aman dijalankan ulang.
-- =====================================================================

create or replace function public._tenaga_klinik_saya()
returns boolean language sql stable security definer set search_path = public as $$
  select public.saya() is not null and (
    exists (select 1 from public.klinik_petugas_saya())
    or exists (select 1 from employee_functions ef join functional_positions fp on fp.id = ef.functional_position_id
                where ef.employee_id = public.saya() and fp.kode = 'MEDIS'))
$$;
revoke execute on function public._tenaga_klinik_saya() from public, anon;
grant execute on function public._tenaga_klinik_saya() to authenticated;

create or replace function public.hak_klinik()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'atur', public.boleh_kelola_klinik(),
    'pimpinan', public.pimpinan_kesantrian(),
    'petugas', coalesce((select jsonb_agg(k order by k) from public.klinik_petugas_saya() k), '[]'::jsonb),
    -- Rujukan dibuat pengasuh/pegawai lain untuk ditangani tenaga medis; tenaga medis tidak merujuk ke dirinya sendiri
    'rujuk', not public._tenaga_klinik_saya() and (exists (select 1 from public.santri_terlihat() limit 1) or public.boleh_kelola_klinik()),
    'tenaga_klinik', public._tenaga_klinik_saya(),
    'lihat', public.is_admin() or public.boleh_kelola_klinik() or public.pimpinan_kesantrian()
             or exists (select 1 from public.klinik_petugas_saya()) or exists (select 1 from public.santri_terlihat() limit 1))
$$;

create or replace function public.buat_rujukan(p_santri uuid, p_keluhan text, p_kapan text default 'hari_ini', p_catatan text default null)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v_klinik text; v_sumber text := 'pengasuh';
begin
  if public.saya() is null then raise exception 'Sesi tidak ditemukan. Silakan masuk kembali.' using errcode = '42501'; end if;
  select case when jenis_kelamin = 'P' then 'putri' else 'putra' end into v_klinik from students where id = p_santri;
  if v_klinik is null then raise exception 'Santri tidak ditemukan.'; end if;
  if public._tenaga_klinik_saya() then
    raise exception 'Petugas klinik tidak merujuk santri. Santri yang datang langsung dicatat lewat Klinik → Periksa.' using errcode = '42501';
  end if;
  if not (p_santri in (select public.santri_terlihat()) or public.boleh_detail_klinik(v_klinik)) then
    raise exception 'Anda hanya dapat merujuk santri asuhan Anda.' using errcode = '42501';
  end if;
  return public._rujukan_internal(p_santri, p_keluhan, p_kapan, v_sumber, public.saya(), null, null, p_catatan);
end $$;

-- PEMERIKSAAN — hasil yang benar: 2 baris "Sesuai"
select '1. Penanda tenaga klinik tersedia dan dipakai hak klinik' as pemeriksaan,
       case when position('_tenaga_klinik_saya' in (select prosrc from pg_proc where proname = 'hak_klinik')) > 0 then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Buat rujukan menolak tenaga klinik',
       case when position('_tenaga_klinik_saya' in (select prosrc from pg_proc where proname = 'buat_rujukan')) > 0 then 'Sesuai' else 'Periksa' end;
