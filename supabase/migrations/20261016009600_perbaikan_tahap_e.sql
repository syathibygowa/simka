-- SIMKA PRO | supabase/migrations/20261016009600_perbaikan_tahap_e.sql | v1.0 | Perbaikan: logo sertifikat, nama satuan per kop surat, tampil/sembunyi beban kerja per pegawai | 16/10/2026
-- A. Sertifikat Tahfizhul Quran: logo YPWI lama tidak dipakai lagi; bawaan hanya satu logo (logo pondok).
-- B. Kop surat: kolom nama_lembaga dan npsn per kop. Isian {lembaga} pada surat mengikuti kop yang dipilih
--    (Pondok, SMAS Tahfizhul Qur'an, Kesetaraan Wustha PPS Tahfizhul Qur'an, Yayasan). Diubah di Setelan → Kop surat.
-- C. Ekuivalensi jam beban kerja: setiap pegawai diatur terlihat/tersembunyi di akunnya (bawaan tersembunyi).
--    Admin, pengatur beban kerja, dan pimpinan (untuk anggota unitnya) tetap dapat melihat rekap.
-- Aman dijalankan ulang.

-- ---------------------------------------------------------------------
-- A. LOGO SERTIFIKAT
-- ---------------------------------------------------------------------
update public.institution_settings set nilai = nilai || '{"logo_kiri": ""}'::jsonb
 where kunci = 'sertifikat_tahfizh' and coalesce(nilai->>'logo_kiri', '') like '%logo-ypwi%';

-- ---------------------------------------------------------------------
-- B. NAMA SATUAN PER KOP
-- ---------------------------------------------------------------------
alter table public.letterheads add column if not exists nama_lembaga text;
alter table public.letterheads add column if not exists npsn text;
update public.letterheads set nama_lembaga = case kode
    when 'pondok' then (select nilai->>'nama_lengkap' from institution_settings where kunci = 'identitas')
    when 'sma' then 'SMAS Tahfizhul Qur''an Imam Asy-Syathiby Wahdah Islamiyah Gowa'
    when 'wustha' then 'Kesetaraan Wustha PPS Tahfizhul Qur''an Imam Asy-Syathiby Wahdah Islamiyah Gowa'
    when 'yayasan' then 'Yayasan Pesantren Imam Asysyatiby (YPIA) Wahdah Islamiyah'
  end
 where nama_lembaga is null and kode in ('pondok','sma','wustha','yayasan');
update public.letterheads set npsn = case kode when 'sma' then '69981356' when 'wustha' then '70023617' when 'pondok' then '70023617' end
 where npsn is null and kode in ('pondok','sma','wustha');

create or replace function public.konteks_surat()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'lembaga', coalesce(i.nilai->>'nama_lengkap', ''), 'alamat', coalesce(i.nilai->>'alamat', ''), 'npsn', coalesce(i.nilai->>'npsn', ''),
    'nspp', coalesce(i.nilai->>'nspp', ''), 'kota', coalesce(nullif(i.nilai->>'kota_surat', ''), 'Gowa'), 'telepon', coalesce(i.nilai->>'telepon', ''),
    'email', coalesce(i.nilai->>'email', ''),
    'tahun_ajaran', (select nama from academic_years where aktif limit 1),
    'hari_ini', public.hari_ini(), 'hijriah_hari_ini', (select teks from public.hijriah(public.hari_ini())),
    'kop', coalesce((select jsonb_object_agg(k.kode, jsonb_build_object('lembaga', k.nama_lembaga, 'npsn', k.npsn)) from letterheads k where k.nama_lembaga is not null), '{}'::jsonb))
    from (select (select nilai from institution_settings where kunci = 'identitas') nilai) i
   where public.saya() is not null
$$;

-- ---------------------------------------------------------------------
-- C. TAMPIL/SEMBUNYI BEBAN KERJA PER PEGAWAI
-- ---------------------------------------------------------------------
alter table public.employees add column if not exists beban_terlihat boolean not null default false;

create or replace function public.boleh_lihat_beban(p_emp uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select (p_emp = public.saya() and coalesce((select beban_terlihat from employees where id = p_emp), false))
      or public.boleh_atur_beban() or public.is_admin() or public.pimpinan_dari(p_emp)
$$;

/** Hak menu Beban Kerja untuk akun yang masuk. */
create or replace function public.hak_beban()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'saya', coalesce((select beban_terlihat from employees where id = public.saya()), false),
    'atur', public.boleh_atur_beban(),
    'rekap', public.is_admin() or public.boleh_atur_beban() or exists (select 1 from public.unit_pimpinan_saya()))
$$;

/** Daftar pengaturan tampil beban kerja (admin/pengatur beban kerja). */
create or replace function public.daftar_tampil_beban()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_object_agg(e.id, e.beban_terlihat), '{}'::jsonb) from employees e
   where public.is_admin() or public.boleh_atur_beban()
$$;

/** Atur tampil/sembunyi beban kerja di akun pegawai (satu, beberapa, atau semua bila p_ids null). */
create or replace function public.atur_tampil_beban(p_ids uuid[], p_tampil boolean)
returns int language plpgsql volatile security definer set search_path = public as $$
declare n int;
begin
  if not (public.boleh_atur_beban() or public.is_superadmin()) then
    raise exception 'Hanya superadmin atau admin ber-izin Atur beban kerja yang dapat mengubah pengaturan ini.' using errcode = '42501';
  end if;
  update employees set beban_terlihat = coalesce(p_tampil, false)
   where (p_ids is null or id = any (p_ids)) and beban_terlihat is distinct from coalesce(p_tampil, false);
  get diagnostics n = row_count;
  perform public.catat_audit('atur_tampil_beban', 'employees', coalesce(array_length(p_ids, 1), 0)::text,
    case when p_tampil then 'Beban kerja ditampilkan' else 'Beban kerja disembunyikan' end || ' untuk ' || n || ' pegawai', null);
  return n;
end $$;

do $$ declare f text; begin
  foreach f in array array['hak_beban()','daftar_tampil_beban()','atur_tampil_beban(uuid[],boolean)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- PEMERIKSAAN — hasil yang benar: 3 baris "Sesuai"
select '1. Logo sertifikat satu logo (pondok)' as pemeriksaan,
       case when coalesce((select nilai->>'logo_kiri' from institution_settings where kunci = 'sertifikat_tahfizh'), '') not like '%ypwi%' then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Nama satuan per kop surat', case when (select count(*) from letterheads where nama_lembaga is not null) >= 1 then 'Sesuai' else 'Periksa' end
union all
select '3. Tampil/sembunyi beban kerja per pegawai', case when exists (select 1 from information_schema.columns where table_name = 'employees' and column_name = 'beban_terlihat')
             and (select count(*) from pg_proc where proname in ('hak_beban','atur_tampil_beban','daftar_tampil_beban')) = 3 then 'Sesuai' else 'Periksa' end;
