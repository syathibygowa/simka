-- SIMKA PRO | supabase/migrations/20261004003000_data_santri.sql | v1.0 | Fase 4 – Tahap 1 Data santri | 04/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 4 · Migrasi 30: Data santri, kontak wali, status, dan mutasi (Blueprint Bagian 14)
--   * students                : identitas santri; NIS 7 digit pondok (YY + angkatan 2 digit + nomor 3 digit),
--                               tahun masuk dan angkatan dibaca otomatis dari NIS
--   * student_contacts        : kontak ayah, ibu, wali/darurat (satu ditandai penerima WA utama)
--   * student_status_history  : setiap perubahan status beserta tanggal dan alasan
--   * student_mutations       : mutasi masuk (pindahan) dan mutasi keluar (nomor surat keterangan pindah)
--   * santri_terlihat()       : cakupan santri yang boleh dilihat (dipakai RLS; Tahap 2 menambah cakupan pengasuh)
--   * simpan_santri, impor_santri, ubah_status_santri, mutasi_keluar_santri : satu-satunya pintu tulis
-- Tabel santri TIDAK dapat ditulis langsung dari aplikasi; semua lewat fungsi di atas (security definer).
-- Jalankan SETELAH migrasi 2900. Aman dijalankan ulang.
-- =====================================================================

insert into public.admin_capabilities (kode, nama, urutan) values
  ('kelola_santri', 'Mengelola data santri, kontak wali, status, dan mutasi (Fase 4)', 17)
on conflict (kode) do nothing;

-- Hak fitur bawaan: pimpinan dapat melihat data santri (cakupan menurut bidang yang dipimpin)
insert into public.feature_grants (feature_kode, sasaran, sasaran_id, tingkat, catatan)
select 'data_santri', 'struktural', sp.id, 1, 'bawaan Fase 4'
from public.structural_positions sp
where sp.kode in ('YAYASAN','DIREKTUR','WAKIL_DIREKTUR','KEPALA_BIDANG','WAKIL_KEPALA_BIDANG','WAKIL_KEPALA_SEKOLAH')
on conflict (feature_kode, sasaran, sasaran_id) do nothing;

-- ---------------------------------------------------------------------
-- 1. TABEL
-- ---------------------------------------------------------------------
create table if not exists public.students (
  id               uuid primary key default gen_random_uuid(),
  nis              text not null constraint students_nis_unik unique
                   constraint students_nis_format check (nis ~ '^[0-9]{7}$'),
  nisn             text constraint students_nisn_unik unique
                   constraint students_nisn_format check (nisn ~ '^[0-9]{10}$'),
  nik              text constraint students_nik_format check (nik ~ '^[0-9]{16}$'),
  nama_lengkap     text not null constraint students_nama_check check (length(trim(nama_lengkap)) >= 3),
  nama_panggilan   text,
  jenis_kelamin    text not null constraint students_jk_check check (jenis_kelamin in ('L','P')),
  tempat_lahir     text,
  tanggal_lahir    date,
  jenjang          text not null constraint students_jenjang_check check (jenjang in ('wustha','sma')),
  tingkat          smallint not null,
  tahun_masuk      smallint generated always as (case when nis ~ '^[0-9]{7}$' then 2000 + substr(nis, 1, 2)::int end) stored,
  angkatan         smallint generated always as (case when nis ~ '^[0-9]{7}$' then substr(nis, 3, 2)::int end) stored,
  tanggal_masuk    date,
  jalur_masuk      text not null default 'baru' constraint students_jalur_check check (jalur_masuk in ('baru','pindahan')),
  asal_sekolah     text,
  hafalan_awal_juz numeric(4,1) constraint students_hafalan_check check (hafalan_awal_juz between 0 and 30),
  anak_ke          smallint constraint students_anak_ke_check check (anak_ke between 1 and 30),
  alamat           text,
  status           text not null default 'aktif'
                   constraint students_status_check check (status in ('aktif','nonaktif','mutasi_keluar','lulus','berhenti')),
  status_sejak     date not null default public.hari_ini(),
  foto_id          uuid references public.storage_objects(id) on delete set null,
  catatan          text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint students_tingkat_check check (
    (jenjang = 'wustha' and tingkat between 7 and 9) or (jenjang = 'sma' and tingkat between 10 and 12))
);
create index if not exists students_status_idx on public.students (status, jenjang, tingkat);

create table if not exists public.student_contacts (
  id          uuid primary key default gen_random_uuid(),
  student_id  uuid not null references public.students(id) on delete cascade,
  hubungan    text not null constraint student_contacts_hubungan_check check (hubungan in ('ayah','ibu','wali')),
  nama        text,
  no_hp       text constraint student_contacts_hp_check check (no_hp ~ '^[0-9+]{9,16}$'),
  pekerjaan   text,
  utama       boolean not null default false,
  created_at  timestamptz not null default now(),
  unique (student_id, hubungan)
);
create unique index if not exists student_contacts_satu_utama on public.student_contacts (student_id) where utama;

create table if not exists public.student_status_history (
  id           uuid primary key default gen_random_uuid(),
  student_id   uuid not null references public.students(id) on delete cascade,
  status_lama  text,
  status_baru  text not null,
  tanggal      date not null default public.hari_ini(),
  alasan       text,
  oleh         uuid references public.employees(id) on delete set null,
  created_at   timestamptz not null default now()
);
create index if not exists student_status_history_idx on public.student_status_history (student_id, created_at desc);

create table if not exists public.student_mutations (
  id                uuid primary key default gen_random_uuid(),
  student_id        uuid not null references public.students(id) on delete cascade,
  jenis             text not null check (jenis in ('masuk','keluar')),
  tanggal           date not null default public.hari_ini(),
  sekolah           text,                 -- asal sekolah (masuk) atau tujuan (keluar)
  alasan            text,
  jenjang           text,
  tingkat           smallint,
  hafalan_juz       numeric(4,1),
  nomor_surat       text,
  kop               text,
  academic_year_id  uuid references public.academic_years(id) on delete set null,
  oleh              uuid references public.employees(id) on delete set null,
  created_at        timestamptz not null default now()
);
create unique index if not exists student_mutations_satu_masuk on public.student_mutations (student_id) where jenis = 'masuk';
create index if not exists student_mutations_idx on public.student_mutations (jenis, tanggal);

drop trigger if exists aa_updated on public.students;
create trigger aa_updated before update on public.students for each row execute function public.tg_updated_at();
drop trigger if exists zz_audit on public.students;
create trigger zz_audit after insert or update or delete on public.students for each row execute function public.tg_audit();
drop trigger if exists zz_audit on public.student_contacts;
create trigger zz_audit after insert or update or delete on public.student_contacts for each row execute function public.tg_audit();

-- ---------------------------------------------------------------------
-- 2. CAKUPAN DAN HAK
-- ---------------------------------------------------------------------
-- Santri yang boleh dilihat pengguna saat ini:
--   admin/superadmin → semua; pemegang fitur data_santri → semua, kecuali pimpinan yang cakupannya hanya
--   Bidang Kesetaraan Wustha dan/atau Bidang SMA → santri jenjang itu saja.
--   (Tahap 2 menambahkan: pengasuh → santri kelompok asuhnya.)
create or replace function public.santri_terlihat()
returns setof uuid language plpgsql stable security definer set search_path = public as $$
declare v_wustha uuid; v_sma uuid; v_jenjang text[] := '{}'; v_lain boolean;
begin
  if public.saya() is null then return; end if;
  if public.is_admin() then return query select id from students; return; end if;
  if public.tingkat_fitur('data_santri') >= 1 then
    select id into v_wustha from org_units where kode = 'WUSTHA';
    select id into v_sma from org_units where kode = 'SMA';
    if exists (select 1 from public.unit_pimpinan_saya() u where u = v_wustha) then v_jenjang := array_append(v_jenjang, 'wustha'); end if;
    if exists (select 1 from public.unit_pimpinan_saya() u where u = v_sma) then v_jenjang := array_append(v_jenjang, 'sma'); end if;
    select exists (select 1 from public.unit_pimpinan_saya() u
                   where u not in (select public.unit_turunan(v_wustha)) and u not in (select public.unit_turunan(v_sma)))
      into v_lain;
    if v_lain or cardinality(v_jenjang) = 0 then
      return query select id from students;
    else
      return query select id from students where jenjang = any(v_jenjang);
    end if;
  end if;
end $$;

create or replace function public.boleh_ubah_santri(p_id uuid default null)
returns boolean language sql stable security definer set search_path = public as $$
  select public.admin_boleh('kelola_santri')
      or (public.tingkat_fitur('data_santri') >= 2 and (p_id is null or p_id in (select public.santri_terlihat())))
$$;

-- ---------------------------------------------------------------------
-- 3. RLS: hanya baca; tulis lewat fungsi
-- ---------------------------------------------------------------------
alter table public.students enable row level security;
alter table public.student_contacts enable row level security;
alter table public.student_status_history enable row level security;
alter table public.student_mutations enable row level security;

drop policy if exists santri_baca on public.students;
create policy santri_baca on public.students for select to authenticated
  using (id in (select public.santri_terlihat()));
drop policy if exists santri_hapus on public.students;
create policy santri_hapus on public.students for delete to authenticated using (public.is_superadmin());

drop policy if exists kontak_baca on public.student_contacts;
create policy kontak_baca on public.student_contacts for select to authenticated
  using (student_id in (select public.santri_terlihat()));
drop policy if exists status_santri_baca on public.student_status_history;
create policy status_santri_baca on public.student_status_history for select to authenticated
  using (student_id in (select public.santri_terlihat()));
drop policy if exists mutasi_baca on public.student_mutations;
create policy mutasi_baca on public.student_mutations for select to authenticated
  using (student_id in (select public.santri_terlihat()));

-- ---------------------------------------------------------------------
-- 4. RIWAYAT STATUS OTOMATIS
-- ---------------------------------------------------------------------
-- Alasan dikirim fungsi pemanggil lewat set_config('simka.alasan', …, true).
create or replace function public.tg_students_status()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if TG_OP = 'INSERT' then
    insert into student_status_history (student_id, status_lama, status_baru, tanggal, alasan, oleh)
    values (new.id, null, new.status, coalesce(new.tanggal_masuk, public.hari_ini()),
            case when new.jalur_masuk = 'pindahan' then 'Santri pindahan' || coalesce(' dari ' || new.asal_sekolah, '')
                 else 'Santri baru' end, public.saya());
  elsif new.status is distinct from old.status then
    insert into student_status_history (student_id, status_lama, status_baru, tanggal, alasan, oleh)
    values (new.id, old.status, new.status, new.status_sejak,
            nullif(current_setting('simka.alasan', true), ''), public.saya());
  end if;
  return new;
end $$;
drop trigger if exists ab_status on public.students;
create trigger ab_status after insert or update of status on public.students
  for each row execute function public.tg_students_status();

-- ---------------------------------------------------------------------
-- 5. SIMPAN SANTRI (baru atau ubah) BESERTA KONTAK — satu transaksi
-- ---------------------------------------------------------------------
-- p: {id?, nis, nisn, nik, nama_lengkap, nama_panggilan, jenis_kelamin, tempat_lahir, tanggal_lahir, jenjang, tingkat,
--     tanggal_masuk, jalur_masuk, asal_sekolah, hafalan_awal_juz, anak_ke, alamat, catatan,
--     kontak: [{hubungan, nama?, no_hp?, pekerjaan?, utama?, hapus?}]}
-- Hanya kolom yang dikirim yang diubah (sel Excel kosong tidak menghapus data lama).
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
    insert into students (nis, nisn, nik, nama_lengkap, nama_panggilan, jenis_kelamin, tempat_lahir, tanggal_lahir, jenjang,
      tingkat, tanggal_masuk, jalur_masuk, asal_sekolah, hafalan_awal_juz, anak_ke, alamat, catatan)
    values (trim(p->>'nis'), nullif(trim(p->>'nisn'), ''), nullif(trim(p->>'nik'), ''), trim(p->>'nama_lengkap'),
      nullif(trim(p->>'nama_panggilan'), ''), nullif(p->>'jenis_kelamin', ''), nullif(trim(p->>'tempat_lahir'), ''),
      nullif(p->>'tanggal_lahir', '')::date, p->>'jenjang', (p->>'tingkat')::smallint,
      coalesce(nullif(p->>'tanggal_masuk', '')::date, public.hari_ini()), coalesce(nullif(p->>'jalur_masuk', ''), 'baru'),
      nullif(trim(p->>'asal_sekolah'), ''), nullif(p->>'hafalan_awal_juz', '')::numeric, nullif(p->>'anak_ke', '')::smallint,
      nullif(trim(p->>'alamat'), ''), nullif(trim(p->>'catatan'), ''))
    returning id into v_id;
  else
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
      catatan          = case when p ? 'catatan' then nullif(trim(p->>'catatan'), '') else catatan end
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

-- Pesan galat yang mudah dipahami (formulir dan impor)
create or replace function public._pesan_santri(p_kode text, p_kendala text, p_pesan text)
returns text language sql immutable as $$
  select case
    when p_kendala = 'students_nis_unik' then 'NIS sudah dipakai santri lain.'
    when p_kendala = 'students_nisn_unik' then 'NISN sudah dipakai santri lain.'
    when p_kendala = 'students_nis_format' then 'NIS harus 7 angka (contoh 2211010: masuk 2022, angkatan 11, nomor 010).'
    when p_kendala = 'students_nisn_format' then 'NISN harus 10 angka.'
    when p_kendala = 'students_nik_format' then 'NIK harus 16 angka.'
    when p_kendala = 'students_nama_check' then 'Nama santri minimal 3 huruf.'
    when p_kendala = 'students_jk_check' then 'Jenis kelamin harus L atau P.'
    when p_kendala = 'students_jenjang_check' then 'Jenjang harus Wustha atau SMA.'
    when p_kendala = 'students_tingkat_check' then 'Kelas tidak sesuai jenjang (Wustha kelas 7–9, SMA kelas 10–12).'
    when p_kendala = 'students_hafalan_check' then 'Hafalan awal harus 0–30 juz.'
    when p_kendala = 'students_anak_ke_check' then 'Anak ke- harus 1–30.'
    when p_kendala = 'student_contacts_hp_check' then 'Nomor HP orang tua/wali harus 9–16 angka.'
    when p_kode = '23502' then 'Data wajib belum lengkap (NIS, nama, jenis kelamin, jenjang, kelas).'
    when p_kode in ('22007','22008') then 'Format tanggal tidak sah.'
    when p_kode = '22P02' then 'Isian angka tidak sah.'
    else p_pesan end
$$;

-- Bungkus formulir: galat batasan diterjemahkan ke pesan Indonesia
create or replace function public.simpan_santri_form(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_kode text; v_kendala text; v_pesan text;
begin
  return public.simpan_santri(p);
exception when others then
  get stacked diagnostics v_kode = returned_sqlstate, v_kendala = constraint_name, v_pesan = message_text;
  raise exception '%', public._pesan_santri(v_kode, coalesce(v_kendala, ''), v_pesan) using errcode = v_kode;
end $$;

-- Impor Excel: p_baris = [{...isian simpan_santri...}]; baris dengan NIS yang sudah ada diperbarui
create or replace function public.impor_santri(p_baris jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare r jsonb; i int := 0; v_id uuid; v_ada uuid; hasil jsonb := '[]'::jsonb; v_kode text; v_kendala text; v_pesan text;
begin
  if not public.admin_boleh('kelola_santri') then
    raise exception 'Anda tidak berwenang mengimpor data santri.' using errcode = '42501';
  end if;
  if jsonb_array_length(p_baris) > 700 then raise exception 'Maksimal 700 baris sekali impor.'; end if;
  for r in select * from jsonb_array_elements(p_baris) loop
    i := i + 1;
    begin
      v_ada := (select id from students where nis = trim(r->>'nis'));
      if v_ada is not null then r := r || jsonb_build_object('id', v_ada); end if;
      v_id := public.simpan_santri(r);
      hasil := hasil || jsonb_build_object('baris', i, 'ok', true, 'id', v_id,
                                           'aksi', case when v_ada is null then 'ditambah' else 'diperbarui' end);
    exception when others then
      get stacked diagnostics v_kode = returned_sqlstate, v_kendala = constraint_name, v_pesan = message_text;
      hasil := hasil || jsonb_build_object('baris', i, 'ok', false,
                                           'pesan', public._pesan_santri(v_kode, coalesce(v_kendala, ''), v_pesan));
    end;
  end loop;
  perform public.catat_audit('impor_santri', 'students', null, 'Impor Excel santri: ' || jsonb_array_length(p_baris) || ' baris', null);
  return hasil;
end $$;

-- ---------------------------------------------------------------------
-- 6. STATUS DAN MUTASI KELUAR
-- ---------------------------------------------------------------------
-- Status: aktif, nonaktif (sementara), lulus, berhenti. Mutasi keluar memakai mutasi_keluar_santri().
create or replace function public.ubah_status_santri(p_id uuid, p_status text, p_tanggal date default null, p_alasan text default null)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v_lama text;
begin
  if not public.admin_boleh('kelola_santri') then
    raise exception 'Anda tidak berwenang mengubah status santri.' using errcode = '42501';
  end if;
  if p_status not in ('aktif','nonaktif','lulus','berhenti') then
    raise exception 'Status harus Aktif, Nonaktif sementara, Lulus, atau Berhenti. Untuk pindah sekolah gunakan Mutasi keluar.';
  end if;
  if length(trim(coalesce(p_alasan, ''))) < 5 then raise exception 'Alasan perubahan status wajib diisi (minimal 5 huruf).'; end if;
  select status into v_lama from students where id = p_id for update;
  if not found then raise exception 'Data santri tidak ditemukan.'; end if;
  if v_lama = p_status then raise exception 'Status santri sudah %.', p_status; end if;
  perform set_config('simka.alasan', trim(p_alasan), true);
  update students set status = p_status, status_sejak = coalesce(p_tanggal, public.hari_ini()) where id = p_id;
  perform set_config('simka.alasan', '', true);
end $$;

-- Mutasi keluar: tanggal, tujuan, alasan → status mutasi_keluar + nomor surat keterangan pindah (kop jenjang)
create or replace function public.mutasi_keluar_santri(p_id uuid, p_tanggal date, p_tujuan text, p_alasan text)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare s students; v_nomor jsonb; v_kop text; v_mid uuid; v_tgl date := coalesce(p_tanggal, public.hari_ini());
begin
  if not public.admin_boleh('kelola_santri') then
    raise exception 'Anda tidak berwenang mencatat mutasi santri.' using errcode = '42501';
  end if;
  if length(trim(coalesce(p_tujuan, ''))) < 3 then raise exception 'Sekolah/pondok tujuan wajib diisi.'; end if;
  if length(trim(coalesce(p_alasan, ''))) < 5 then raise exception 'Alasan pindah wajib diisi (minimal 5 huruf).'; end if;
  select * into s from students where id = p_id for update;
  if not found then raise exception 'Data santri tidak ditemukan.'; end if;
  if s.status <> 'aktif' and s.status <> 'nonaktif' then
    raise exception 'Mutasi keluar hanya untuk santri aktif atau nonaktif sementara.';
  end if;
  v_kop := case when s.jenjang = 'sma' then 'sma' else 'wustha' end;
  v_nomor := public.ambil_nomor('surat', v_tgl, 'K', 'IL', v_kop);
  insert into student_mutations (student_id, jenis, tanggal, sekolah, alasan, jenjang, tingkat, nomor_surat, kop, academic_year_id, oleh)
  values (p_id, 'keluar', v_tgl, trim(p_tujuan), trim(p_alasan), s.jenjang, s.tingkat, v_nomor->>'nomor', v_kop,
          (select id from academic_years where aktif), public.saya())
  returning id into v_mid;
  perform set_config('simka.alasan', 'Mutasi keluar ke ' || trim(p_tujuan) || ': ' || trim(p_alasan), true);
  update students set status = 'mutasi_keluar', status_sejak = v_tgl where id = p_id;
  perform set_config('simka.alasan', '', true);
  return jsonb_build_object('mutasi_id', v_mid, 'nomor', v_nomor->>'nomor');
end $$;

-- ---------------------------------------------------------------------
-- 7. TAMPILAN
-- ---------------------------------------------------------------------
create or replace view public.v_santri with (security_invoker = true) as
select s.*,
  case s.jenjang when 'wustha' then 'Kesetaraan Wustha' else 'SMA' end as nama_jenjang,
  case when s.tempat_lahir is not null and s.tanggal_lahir is not null
       then s.tempat_lahir || ', ' || public.tanggal_indo(s.tanggal_lahir) end as ttl,
  case when s.tanggal_lahir is not null then extract(year from age(public.hari_ini(), s.tanggal_lahir))::int end as usia,
  coalesce((select jsonb_agg(jsonb_build_object('hubungan', c.hubungan, 'nama', c.nama, 'no_hp', c.no_hp,
                                                'pekerjaan', c.pekerjaan, 'utama', c.utama)
                             order by array_position(array['ayah','ibu','wali'], c.hubungan))
            from public.student_contacts c where c.student_id = s.id), '[]'::jsonb) as kontak
from public.students s;

-- ---------------------------------------------------------------------
-- 8. PENANDA TANGAN DOKUMEN SANTRI DAN REALTIME
-- ---------------------------------------------------------------------
insert into public.signer_rules (jenis_dokumen, nama_dokumen, kiri, kanan, kop_kode, urutan) values
  ('daftar_santri', 'Daftar dan biodata santri', 'kepala_jenjang', 'pencetak', 'pondok', 11),
  ('surat_pindah_santri', 'Surat keterangan pindah santri', 'direktur', 'kepala_jenjang', 'wustha', 12)
on conflict (jenis_dokumen) do nothing;

-- Template WA ke orang tua/wali (dapat diubah superadmin di Pengaturan → Template WA)
insert into public.wa_templates (kode, nama, isi, variabel, keterangan) values
  ('wali_santri', 'Pesan ke orang tua/wali santri',
   E'{salam}, Bapak/Ibu {nama_wali}.\n\nKami dari {nama_singkat} menyampaikan informasi terkait ananda *{nama_santri}* (NIS {nis}, {kelas}).\n\n{pesan}\n\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
   '{nama_wali,nama_santri,nis,kelas,pesan,pengirim}', 'Tombol WA di Data Santri (kontak ayah, ibu, wali).')
on conflict (kode) do nothing;

do $$ begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'students') then
    alter publication supabase_realtime add table public.students;
  end if;
end $$;

do $$
declare f text;
begin
  foreach f in array array['santri_terlihat()','boleh_ubah_santri(uuid)','simpan_santri_form(jsonb)','impor_santri(jsonb)',
    'ubah_status_santri(uuid,text,date,text)','mutasi_keluar_santri(uuid,date,text,text)']
  loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  -- simpan_santri dipanggil lewat simpan_santri_form/impor_santri saja
  execute 'revoke execute on function public.simpan_santri(jsonb) from public, anon, authenticated';
end $$;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 6 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select 'Tabel santri (4) dengan RLS' as pemeriksaan,
       case when (select count(*) from pg_tables where schemaname = 'public' and rowsecurity
                   and tablename in ('students','student_contacts','student_status_history','student_mutations')) = 4
            then 'Sesuai' else 'Periksa' end as hasil
union all
select 'Tabel santri tidak dapat ditulis langsung (tanpa kebijakan insert/update)',
       case when not exists (select 1 from pg_policies where schemaname = 'public'
                              and tablename in ('students','student_contacts','student_status_history','student_mutations')
                              and cmd in ('INSERT','UPDATE','ALL')) then 'Sesuai' else 'Periksa' end
union all
select 'Fungsi simpan, impor, status, mutasi (5)',
       case when (select count(*) from pg_proc where proname in
                   ('simpan_santri','simpan_santri_form','impor_santri','ubah_status_santri','mutasi_keluar_santri')) = 5
            then 'Sesuai' else 'Periksa' end
union all
select 'Izin admin kelola_santri',
       case when exists (select 1 from public.admin_capabilities where kode = 'kelola_santri') then 'Sesuai' else 'Periksa' end
union all
select 'Tahun masuk dan angkatan dibaca dari NIS',
       case when (select attgenerated from pg_attribute where attrelid = 'public.students'::regclass and attname = 'angkatan') = 's'
            then 'Sesuai' else 'Periksa' end
union all
select 'Migrasi 2900 sudah terpasang',
       case when exists (select 1 from pg_proc where proname = 'beban_kerja_rekap') then 'Sesuai' else 'Periksa: jalankan 2900 dulu' end;
