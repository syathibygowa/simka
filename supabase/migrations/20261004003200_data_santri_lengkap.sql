-- SIMKA PRO | supabase/migrations/20261004003200_data_santri_lengkap.sql | v1.0 | Fase 4 – Perbaikan P1 (data santri lengkap) | 04/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 4 · Migrasi 32: Kelengkapan data santri (masukan pemilik proyek)
--   * Kolom baru: nomor KK, RT, RW, kelurahan/desa, kecamatan, kabupaten/kota, provinsi (kolom "alamat" = jalan/dusun)
--   * Data wajib santri baru: NIS, NISN, nama, tempat lahir, tanggal lahir (data lama tidak dipaksa, tetapi
--     yang sudah terisi tidak boleh dikosongkan); v_santri memuat "data_kurang" untuk penanda dan saringan
--   * simpan_santri diperbarui untuk kolom baru (impor Excel ikut membaca kolom baru)
-- Jalankan SETELAH migrasi 3100. Aman dijalankan ulang.
-- =====================================================================

alter table public.students add column if not exists no_kk     text;
alter table public.students add column if not exists rt        text;
alter table public.students add column if not exists rw        text;
alter table public.students add column if not exists kelurahan text;
alter table public.students add column if not exists kecamatan text;
alter table public.students add column if not exists kota_kab  text;
alter table public.students add column if not exists provinsi  text;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'students_no_kk_format') then
    alter table public.students add constraint students_no_kk_format check (no_kk ~ '^[0-9]{16}$');
  end if;
  if not exists (select 1 from pg_constraint where conname = 'students_rt_rw_format') then
    alter table public.students add constraint students_rt_rw_format check (coalesce(rt, '000') ~ '^[0-9]{3}$' and coalesce(rw, '000') ~ '^[0-9]{3}$');
  end if;
end $$;

-- RT/RW disimpan 3 digit: "2" → "002"; isian bukan angka ditolak oleh batasan
create or replace function public._rt_rw(p text)
returns text language sql immutable as $$
  select case when nullif(trim(coalesce(p, '')), '') is null then null
              when trim(p) ~ '^[0-9]{1,3}$' then lpad(trim(p), 3, '0') else trim(p) end
$$;

-- ---------------------------------------------------------------------
-- 1. SIMPAN SANTRI (kolom baru dan data wajib)
-- ---------------------------------------------------------------------
create or replace function public.simpan_santri(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare
  v_id uuid := nullif(p->>'id', '')::uuid; v_baru boolean; k jsonb; v_h text; s students;
  hp text;
begin
  v_baru := v_id is null;
  if not public.boleh_ubah_santri(v_id) then
    raise exception 'Anda tidak berwenang mengubah data santri ini.' using errcode = '42501';
  end if;

  if v_baru then
    if coalesce(trim(p->>'nis'), '') = '' then raise exception 'NIS wajib diisi (7 digit).' using errcode = '23514'; end if;
    if coalesce(p->>'jenjang', '') = '' or coalesce(p->>'tingkat', '') = '' then
      raise exception 'Jenjang dan kelas (tingkat) wajib diisi.' using errcode = '23514';
    end if;
    -- Data wajib santri baru: NIS, NISN, nama, tempat dan tanggal lahir (Fase 4 – perbaikan P1)
    if coalesce(trim(p->>'nisn'), '') = '' then raise exception 'NISN wajib diisi (10 angka).' using errcode = '23514'; end if;
    if coalesce(trim(p->>'tempat_lahir'), '') = '' or coalesce(p->>'tanggal_lahir', '') = '' then
      raise exception 'Tempat dan tanggal lahir wajib diisi.' using errcode = '23514';
    end if;
    insert into students (nis, nisn, nik, nama_lengkap, nama_panggilan, jenis_kelamin, tempat_lahir, tanggal_lahir, jenjang,
      tingkat, tanggal_masuk, jalur_masuk, asal_sekolah, hafalan_awal_juz, anak_ke, alamat, catatan,
      no_kk, rt, rw, kelurahan, kecamatan, kota_kab, provinsi)
    values (trim(p->>'nis'), nullif(trim(p->>'nisn'), ''), nullif(trim(p->>'nik'), ''), trim(p->>'nama_lengkap'),
      nullif(trim(p->>'nama_panggilan'), ''), nullif(p->>'jenis_kelamin', ''), nullif(trim(p->>'tempat_lahir'), ''),
      nullif(p->>'tanggal_lahir', '')::date, p->>'jenjang', (p->>'tingkat')::smallint,
      coalesce(nullif(p->>'tanggal_masuk', '')::date, public.hari_ini()), coalesce(nullif(p->>'jalur_masuk', ''), 'baru'),
      nullif(trim(p->>'asal_sekolah'), ''), nullif(p->>'hafalan_awal_juz', '')::numeric, nullif(p->>'anak_ke', '')::smallint,
      nullif(trim(p->>'alamat'), ''), nullif(trim(p->>'catatan'), ''),
      nullif(trim(p->>'no_kk'), ''), public._rt_rw(p->>'rt'), public._rt_rw(p->>'rw'), nullif(trim(p->>'kelurahan'), ''),
      nullif(trim(p->>'kecamatan'), ''), nullif(trim(p->>'kota_kab'), ''), nullif(trim(p->>'provinsi'), ''))
    returning id into v_id;
  else
    -- Data wajib tidak boleh dikosongkan saat diubah
    if (p ? 'nisn' and coalesce(trim(p->>'nisn'), '') = '' and (select nisn from students where id = v_id) is not null)
       or (p ? 'tempat_lahir' and coalesce(trim(p->>'tempat_lahir'), '') = '' and (select tempat_lahir from students where id = v_id) is not null)
       or (p ? 'tanggal_lahir' and coalesce(p->>'tanggal_lahir', '') = '' and (select tanggal_lahir from students where id = v_id) is not null) then
      raise exception 'NISN, tempat lahir, dan tanggal lahir wajib diisi; data yang sudah ada tidak boleh dikosongkan.' using errcode = '23514';
    end if;
    update students set
      nis              = case when p ? 'nis' then trim(p->>'nis') else nis end,
      nisn             = case when p ? 'nisn' then nullif(trim(p->>'nisn'), '') else nisn end,
      nik              = case when p ? 'nik' then nullif(trim(p->>'nik'), '') else nik end,
      nama_lengkap     = case when p ? 'nama_lengkap' then trim(p->>'nama_lengkap') else nama_lengkap end,
      nama_panggilan   = case when p ? 'nama_panggilan' then nullif(trim(p->>'nama_panggilan'), '') else nama_panggilan end,
      jenis_kelamin    = case when p ? 'jenis_kelamin' then p->>'jenis_kelamin' else jenis_kelamin end,
      tempat_lahir     = case when p ? 'tempat_lahir' then nullif(trim(p->>'tempat_lahir'), '') else tempat_lahir end,
      tanggal_lahir    = case when p ? 'tanggal_lahir' then nullif(p->>'tanggal_lahir', '')::date else tanggal_lahir end,
      jenjang          = case when p ? 'jenjang' then p->>'jenjang' else jenjang end,
      tingkat          = case when p ? 'tingkat' then (p->>'tingkat')::smallint else tingkat end,
      tanggal_masuk    = case when p ? 'tanggal_masuk' then nullif(p->>'tanggal_masuk', '')::date else tanggal_masuk end,
      jalur_masuk      = case when p ? 'jalur_masuk' then coalesce(nullif(p->>'jalur_masuk', ''), 'baru') else jalur_masuk end,
      asal_sekolah     = case when p ? 'asal_sekolah' then nullif(trim(p->>'asal_sekolah'), '') else asal_sekolah end,
      hafalan_awal_juz = case when p ? 'hafalan_awal_juz' then nullif(p->>'hafalan_awal_juz', '')::numeric else hafalan_awal_juz end,
      anak_ke          = case when p ? 'anak_ke' then nullif(p->>'anak_ke', '')::smallint else anak_ke end,
      alamat           = case when p ? 'alamat' then nullif(trim(p->>'alamat'), '') else alamat end,
      catatan          = case when p ? 'catatan' then nullif(trim(p->>'catatan'), '') else catatan end,
      no_kk            = case when p ? 'no_kk' then nullif(trim(p->>'no_kk'), '') else no_kk end,
      rt               = case when p ? 'rt' then public._rt_rw(p->>'rt') else rt end,
      rw               = case when p ? 'rw' then public._rt_rw(p->>'rw') else rw end,
      kelurahan        = case when p ? 'kelurahan' then nullif(trim(p->>'kelurahan'), '') else kelurahan end,
      kecamatan        = case when p ? 'kecamatan' then nullif(trim(p->>'kecamatan'), '') else kecamatan end,
      kota_kab         = case when p ? 'kota_kab' then nullif(trim(p->>'kota_kab'), '') else kota_kab end,
      provinsi         = case when p ? 'provinsi' then nullif(trim(p->>'provinsi'), '') else provinsi end
    where id = v_id;
    if not found then raise exception 'Data santri tidak ditemukan.'; end if;
  end if;

  -- Pengubah non-admin (hak fitur data_santri tingkat 2+) hanya dalam cakupannya, termasuk jenjang hasil ubahan
  if not public.admin_boleh('kelola_santri') and v_id not in (select public.santri_terlihat()) then
    raise exception 'Santri ini di luar cakupan jenjang yang Anda kelola.' using errcode = '42501';
  end if;

  -- Kontak orang tua/wali
  for k in select * from jsonb_array_elements(coalesce(p->'kontak', '[]'::jsonb)) loop
    v_h := k->>'hubungan';
    if v_h not in ('ayah','ibu','wali') then raise exception 'Jenis kontak harus ayah, ibu, atau wali.'; end if;
    if coalesce((k->>'hapus')::boolean, false) then
      delete from student_contacts where student_id = v_id and hubungan = v_h;
      continue;
    end if;
    hp := nullif(regexp_replace(coalesce(k->>'no_hp', ''), '[^0-9+]', '', 'g'), '');
    if hp ~ '^\+?62' then hp := '0' || regexp_replace(hp, '^\+?62', ''); end if;
    if coalesce((k->>'utama')::boolean, false) then
      update student_contacts set utama = false where student_id = v_id and hubungan <> v_h and utama;
    end if;
    insert into student_contacts (student_id, hubungan, nama, no_hp, pekerjaan, utama)
    values (v_id, v_h, nullif(trim(k->>'nama'), ''), hp, nullif(trim(k->>'pekerjaan'), ''), coalesce((k->>'utama')::boolean, false))
    on conflict (student_id, hubungan) do update set
      nama      = case when k ? 'nama' then excluded.nama else student_contacts.nama end,
      no_hp     = case when k ? 'no_hp' then excluded.no_hp else student_contacts.no_hp end,
      pekerjaan = case when k ? 'pekerjaan' then excluded.pekerjaan else student_contacts.pekerjaan end,
      utama     = case when k ? 'utama' then excluded.utama else student_contacts.utama end;
  end loop;
  -- Pastikan ada satu penerima WA utama (bawaan: kontak berurutan ayah, ibu, wali yang ber-HP)
  if not exists (select 1 from student_contacts where student_id = v_id and utama) then
    update student_contacts set utama = true where id = (
      select id from student_contacts where student_id = v_id
      order by (no_hp is null), array_position(array['ayah','ibu','wali'], hubungan) limit 1);
  end if;

  -- Mutasi masuk untuk santri pindahan (satu catatan per santri, mengikuti data terbaru)
  select * into s from students where id = v_id;
  if s.jalur_masuk = 'pindahan' then
    insert into student_mutations (student_id, jenis, tanggal, sekolah, jenjang, tingkat, hafalan_juz, academic_year_id, oleh)
    values (v_id, 'masuk', coalesce(s.tanggal_masuk, public.hari_ini()), s.asal_sekolah, s.jenjang, s.tingkat, s.hafalan_awal_juz,
            (select id from academic_years where aktif), public.saya())
    on conflict (student_id) where jenis = 'masuk' do update set
      tanggal = excluded.tanggal, sekolah = excluded.sekolah, hafalan_juz = excluded.hafalan_juz,
      jenjang = case when v_baru then excluded.jenjang else student_mutations.jenjang end,
      tingkat = case when v_baru then excluded.tingkat else student_mutations.tingkat end;
  else
    delete from student_mutations where student_id = v_id and jenis = 'masuk';
  end if;
  return v_id;
end $$;


create or replace function public._pesan_santri(p_kode text, p_kendala text, p_pesan text)
returns text language sql immutable as $$
  select case
    when p_kendala = 'students_nis_unik' then 'NIS sudah dipakai santri lain.'
    when p_kendala = 'students_nisn_unik' then 'NISN sudah dipakai santri lain.'
    when p_kendala = 'students_nis_format' then 'NIS harus 7 angka (contoh 2211010: masuk 2022, angkatan 11, nomor 010).'
    when p_kendala = 'students_nisn_format' then 'NISN harus 10 angka.'
    when p_kendala = 'students_nik_format' then 'NIK harus 16 angka.'
    when p_kendala = 'students_no_kk_format' then 'Nomor KK harus 16 angka.'
    when p_kendala = 'students_rt_rw_format' then 'RT dan RW harus angka (paling banyak 3 digit).'
    when p_kendala = 'students_nama_check' then 'Nama santri minimal 3 huruf.'
    when p_kendala = 'students_jk_check' then 'Jenis kelamin harus L atau P.'
    when p_kendala = 'students_jenjang_check' then 'Jenjang harus Wustha atau SMA.'
    when p_kendala = 'students_tingkat_check' then 'Kelas tidak sesuai jenjang (Wustha kelas 7–9, SMA kelas 10–12).'
    when p_kendala = 'students_hafalan_check' then 'Hafalan awal harus 0–30 juz.'
    when p_kendala = 'students_anak_ke_check' then 'Anak ke- harus 1–30.'
    when p_kendala = 'student_contacts_hp_check' then 'Nomor HP orang tua/wali harus 9–16 angka.'
    when p_kode = '23502' then 'Data wajib belum lengkap (NIS, NISN, nama, tempat/tanggal lahir, jenis kelamin, kelas).'
    when p_kode in ('22007','22008') then 'Format tanggal tidak sah.'
    when p_kode = '22P02' then 'Isian angka tidak sah.'
    else p_pesan end
$$;

-- ---------------------------------------------------------------------
-- 2. TAMPILAN DATA SANTRI (kolom baru + penanda data wajib yang belum lengkap)
-- ---------------------------------------------------------------------
drop view if exists public.v_santri;
create view public.v_santri as
select s.*,
  case s.jenjang when 'wustha' then 'Kesetaraan Wustha' else 'SMA' end as nama_jenjang,
  case when s.tempat_lahir is not null and s.tanggal_lahir is not null
       then s.tempat_lahir || ', ' || public.tanggal_indo(s.tanggal_lahir) end as ttl,
  case when s.tanggal_lahir is not null then extract(year from age(public.hari_ini(), s.tanggal_lahir))::int end as usia,
  coalesce((select jsonb_agg(jsonb_build_object('hubungan', c.hubungan, 'nama', c.nama, 'no_hp', c.no_hp,
                                                'pekerjaan', c.pekerjaan, 'utama', c.utama)
                             order by array_position(array['ayah','ibu','wali'], c.hubungan))
            from public.student_contacts c where c.student_id = s.id), '[]'::jsonb) as kontak,
  coalesce((select jsonb_agg(jsonb_build_object('id', g.id, 'jenis', g.jenis, 'nama', g.nama)
                             order by array_position(array['kelas','kamar','halaqah','ekskul','lainnya'], g.jenis), g.nama)
            from public.group_members m join public.student_groups g on g.id = m.group_id
            join public.academic_years a on a.id = g.academic_year_id and a.aktif
            where m.student_id = s.id and m.selesai is null), '[]'::jsonb) as kelompok,
  array_remove(array[case when s.nisn is null then 'NISN' end, case when s.tempat_lahir is null then 'Tempat lahir' end,
                     case when s.tanggal_lahir is null then 'Tanggal lahir' end], null) as data_kurang
from public.students s
where s.id in (select public.santri_terlihat());
comment on view public.v_santri is 'Dibaca dengan hak pemilik; baris dibatasi santri_terlihat() (cakupan pimpinan dan pengasuh).';
grant select on public.v_santri to authenticated;
revoke select on public.v_santri from anon;
revoke execute on function public.simpan_santri(jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 4 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select 'Kolom alamat lengkap dan nomor KK (7)' as pemeriksaan,
       case when (select count(*) from information_schema.columns where table_schema = 'public' and table_name = 'students'
                   and column_name in ('no_kk','rt','rw','kelurahan','kecamatan','kota_kab','provinsi')) = 7 then 'Sesuai' else 'Periksa' end as hasil
union all
select 'Data santri memuat kolom baru dan penanda data kurang',
       case when (select count(*) from information_schema.columns where table_name = 'v_santri'
                   and column_name in ('kelurahan','data_kurang','kelompok')) = 3 then 'Sesuai' else 'Periksa' end
union all
select 'RT/RW dibakukan 3 digit', case when public._rt_rw('2') = '002' then 'Sesuai' else 'Periksa' end
union all
select 'Migrasi 3100 sudah terpasang',
       case when exists (select 1 from pg_proc where proname = 'impor_pembagian') then 'Sesuai' else 'Periksa: jalankan 3100 dulu' end;
