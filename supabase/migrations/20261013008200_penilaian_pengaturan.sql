-- SIMKA PRO | supabase/migrations/20261013008200_penilaian_pengaturan.sql | v1.0 | Fase 12 – Tahap 1 Pengaturan penilaian dan biodata rapor | 13/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 12 · Migrasi 82: fondasi penilaian dan rapor (Blueprint Bagian 19, keputusan pemilik proyek 13/10/2026)
--   * report_settings        : ketentuan per jenis rapor (SMA, Wustha, Tahfizh) per tahun ajaran: judul, kop, label ambang
--                              (KKTP/KKM), cara menentukan nilai rapor (tunggal/akumulasi/rekomendasi), keterampilan, sikap,
--                              kokurikuler, fase, penanda tangan, jumlah juz UTAS, bahasa predikat tahfizh (Arab/Indonesia)
--   * report_predicates      : tabel predikat per kelompok: sma, wustha, utas, pd (pengembangan diri), sikap
--   * grade_periods          : periode penilaian per jenis × semester (disiapkan/dibuka/ditutup), tanggal rapor, hari efektif,
--                              tema kokurikuler
--   * grade_categories       : kategori isian nilai guru (Harian, Ulangan, UTS, UAS, …) beserta bobot dan aspek
--   * report_subjects        : MAPEL RAPOR per jenis × tingkat: urutan, kelompok, nama di rapor, singkatan, KKM/KKTP, sumber nilai
--   * report_subject_sources : sumber nilai mapel rapor = satu atau beberapa MAPEL AJAR berbobot (mis. PKn ← nilai Tahfizh)
--   * report_phrases         : bank kalimat catatan wali kelas, catatan muhaffizh, dan catatan kehadiran (disusun otomatis kelak)
--   * students / student_contacts : kolom biodata rapor (agama, status dalam keluarga, telepon rumah, diterima di kelas,
--                              alamat orang tua; alamat kontak wali)
--   * Fungsi: hak_penilaian, siapkan_penilaian, pengaturan_penilaian, simpan_ketentuan_rapor, simpan_predikat_rapor,
--             simpan_komponen_nilai, simpan_periode_nilai, simpan_mapel_rapor, hapus_mapel_rapor, urutkan_mapel_rapor,
--             salin_mapel_rapor, simpan_kalimat_rapor, hapus_kalimat_rapor
-- Izin admin baru: atur_penilaian, kelola_nilai. Penulisan hanya lewat fungsi.
-- Jalankan SETELAH migrasi 8100. Aman dijalankan ulang.
-- =====================================================================

insert into public.admin_capabilities (kode, nama, urutan) values
  ('atur_penilaian', 'Mengatur penilaian dan rapor: periode, mapel rapor, komponen dan bobot, KKM, predikat, catatan (Fase 12)', 50),
  ('kelola_nilai', 'Mengelola nilai: mengisi atas nama guru, menyetujui perubahan nilai, mencetak semua rapor (Fase 12)', 51)
on conflict (kode) do nothing;

-- ---------------------------------------------------------------------
-- 1. BIODATA RAPOR SANTRI
-- ---------------------------------------------------------------------
alter table public.students add column if not exists agama            text default 'Islam';
alter table public.students add column if not exists status_keluarga  text;
alter table public.students add column if not exists telepon_rumah    text;
alter table public.students add column if not exists diterima_tingkat smallint;
alter table public.students add column if not exists alamat_ortu      text;
alter table public.student_contacts add column if not exists alamat   text;
do $$ begin
  alter table public.students add constraint students_diterima_tingkat_check check (diterima_tingkat is null or diterima_tingkat between 7 and 12);
exception when duplicate_object then null; end $$;
update public.students set agama = 'Islam' where agama is null;

-- simpan_santri (v Fase 12): sama dengan versi 3200 ditambah kolom biodata rapor dan alamat kontak
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
    if coalesce(trim(p->>'nisn'), '') = '' then raise exception 'NISN wajib diisi (10 angka).' using errcode = '23514'; end if;
    if coalesce(trim(p->>'tempat_lahir'), '') = '' or coalesce(p->>'tanggal_lahir', '') = '' then
      raise exception 'Tempat dan tanggal lahir wajib diisi.' using errcode = '23514';
    end if;
    insert into students (nis, nisn, nik, nama_lengkap, nama_panggilan, jenis_kelamin, tempat_lahir, tanggal_lahir, jenjang,
      tingkat, tanggal_masuk, jalur_masuk, asal_sekolah, hafalan_awal_juz, anak_ke, alamat, catatan,
      no_kk, rt, rw, kelurahan, kecamatan, kota_kab, provinsi,
      agama, status_keluarga, telepon_rumah, diterima_tingkat, alamat_ortu)
    values (trim(p->>'nis'), nullif(trim(p->>'nisn'), ''), nullif(trim(p->>'nik'), ''), trim(p->>'nama_lengkap'),
      nullif(trim(p->>'nama_panggilan'), ''), nullif(p->>'jenis_kelamin', ''), nullif(trim(p->>'tempat_lahir'), ''),
      nullif(p->>'tanggal_lahir', '')::date, p->>'jenjang', (p->>'tingkat')::smallint,
      coalesce(nullif(p->>'tanggal_masuk', '')::date, public.hari_ini()), coalesce(nullif(p->>'jalur_masuk', ''), 'baru'),
      nullif(trim(p->>'asal_sekolah'), ''), nullif(p->>'hafalan_awal_juz', '')::numeric, nullif(p->>'anak_ke', '')::smallint,
      nullif(trim(p->>'alamat'), ''), nullif(trim(p->>'catatan'), ''),
      nullif(trim(p->>'no_kk'), ''), public._rt_rw(p->>'rt'), public._rt_rw(p->>'rw'), nullif(trim(p->>'kelurahan'), ''),
      nullif(trim(p->>'kecamatan'), ''), nullif(trim(p->>'kota_kab'), ''), nullif(trim(p->>'provinsi'), ''),
      coalesce(nullif(trim(p->>'agama'), ''), 'Islam'), nullif(trim(p->>'status_keluarga'), ''), nullif(trim(p->>'telepon_rumah'), ''),
      coalesce(nullif(p->>'diterima_tingkat', '')::smallint, (p->>'tingkat')::smallint), nullif(trim(p->>'alamat_ortu'), ''))
    returning id into v_id;
  else
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
      provinsi         = case when p ? 'provinsi' then nullif(trim(p->>'provinsi'), '') else provinsi end,
      agama            = case when p ? 'agama' then coalesce(nullif(trim(p->>'agama'), ''), 'Islam') else agama end,
      status_keluarga  = case when p ? 'status_keluarga' then nullif(trim(p->>'status_keluarga'), '') else status_keluarga end,
      telepon_rumah    = case when p ? 'telepon_rumah' then nullif(trim(p->>'telepon_rumah'), '') else telepon_rumah end,
      diterima_tingkat = case when p ? 'diterima_tingkat' then nullif(p->>'diterima_tingkat', '')::smallint else diterima_tingkat end,
      alamat_ortu      = case when p ? 'alamat_ortu' then nullif(trim(p->>'alamat_ortu'), '') else alamat_ortu end
    where id = v_id;
    if not found then raise exception 'Data santri tidak ditemukan.'; end if;
  end if;

  if not public.admin_boleh('kelola_santri') and v_id not in (select public.santri_terlihat()) then
    raise exception 'Santri ini di luar cakupan jenjang yang Anda kelola.' using errcode = '42501';
  end if;

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
    insert into student_contacts (student_id, hubungan, nama, no_hp, pekerjaan, utama, alamat)
    values (v_id, v_h, nullif(trim(k->>'nama'), ''), hp, nullif(trim(k->>'pekerjaan'), ''), coalesce((k->>'utama')::boolean, false),
            nullif(trim(k->>'alamat'), ''))
    on conflict (student_id, hubungan) do update set
      nama      = case when k ? 'nama' then excluded.nama else student_contacts.nama end,
      no_hp     = case when k ? 'no_hp' then excluded.no_hp else student_contacts.no_hp end,
      pekerjaan = case when k ? 'pekerjaan' then excluded.pekerjaan else student_contacts.pekerjaan end,
      utama     = case when k ? 'utama' then excluded.utama else student_contacts.utama end,
      alamat    = case when k ? 'alamat' then excluded.alamat else student_contacts.alamat end;
  end loop;
  if not exists (select 1 from student_contacts where student_id = v_id and utama) then
    update student_contacts set utama = true where id = (
      select id from student_contacts where student_id = v_id
      order by (no_hp is null), array_position(array['ayah','ibu','wali'], hubungan) limit 1);
  end if;

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
revoke execute on function public.simpan_santri(jsonb) from public, anon, authenticated;

-- v_santri dibuat ulang agar memuat kolom baru (s.*) dan alamat kontak
drop view if exists public.v_santri;
create view public.v_santri as
select s.*,
  case s.jenjang when 'wustha' then 'Kesetaraan Wustha' else 'SMA' end as nama_jenjang,
  case when s.tempat_lahir is not null and s.tanggal_lahir is not null
       then s.tempat_lahir || ', ' || public.tanggal_indo(s.tanggal_lahir) end as ttl,
  case when s.tanggal_lahir is not null then extract(year from age(public.hari_ini(), s.tanggal_lahir))::int end as usia,
  coalesce((select jsonb_agg(jsonb_build_object('hubungan', c.hubungan, 'nama', c.nama, 'no_hp', c.no_hp,
                                                'pekerjaan', c.pekerjaan, 'utama', c.utama, 'alamat', c.alamat)
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

-- ---------------------------------------------------------------------
-- 2. TABEL PENILAIAN
-- ---------------------------------------------------------------------
create table if not exists public.report_settings (
  academic_year_id  uuid not null references public.academic_years(id) on delete cascade,
  jenis             text not null constraint rs_jenis check (jenis in ('sma','wustha','tahfizh')),
  judul             text not null,
  kop_kode          text references public.letterheads(kode) on update cascade on delete set null,
  label_ambang      text not null default 'KKM' constraint rs_label check (label_ambang in ('KKM','KKTP')),
  ambang_bawaan     numeric(5,2) not null default 75 constraint rs_ambang check (ambang_bawaan between 0 and 100),
  mode_nilai        text not null default 'rekomendasi' constraint rs_mode check (mode_nilai in ('tunggal','akumulasi','rekomendasi')),
  desimal           smallint not null default 0 constraint rs_desimal check (desimal between 0 and 2),
  pakai_keterampilan boolean not null default false,
  keterampilan_ikut boolean not null default true,      -- bawaan nilai keterampilan = nilai pengetahuan (guru boleh mengisi terpisah)
  sikap_di_rapor    boolean not null default false,     -- false: sikap hanya tampil di leger
  pakai_kokurikuler boolean not null default false,
  pakai_tp          boolean not null default false,     -- deskripsi capaian memuat daftar tujuan pembelajaran
  tampil_rata       boolean not null default false,     -- rata-rata nilai dicetak di rapor
  tampil_peringkat  boolean not null default false,     -- peringkat dicetak di rapor (bawaan hanya di leger)
  bahasa_predikat   text not null default 'arab' constraint rs_bahasa check (bahasa_predikat in ('arab','indonesia')),
  signatory_id      uuid references public.signatories(id) on delete set null,
  jabatan_ttd       text,
  tempat            text not null default 'Gowa',
  fase              jsonb not null default '{}'::jsonb,  -- {"10":"E","11":"F","12":"F"}
  dimensi           jsonb not null default '[]'::jsonb,  -- dimensi profil lulusan (kokurikuler)
  utas_juz_sma      smallint not null default 5 constraint rs_juz_sma check (utas_juz_sma between 1 and 30),
  utas_juz_wustha   smallint not null default 3 constraint rs_juz_wustha check (utas_juz_wustha between 1 and 30),
  catatan           text,
  updated_at        timestamptz not null default now(),
  updated_by        uuid references public.employees(id) on delete set null,
  primary key (academic_year_id, jenis)
);

create table if not exists public.report_predicates (
  id                uuid primary key default gen_random_uuid(),
  academic_year_id  uuid not null references public.academic_years(id) on delete cascade,
  kelompok          text not null constraint rp_kelompok check (kelompok in ('sma','wustha','utas','pd','sikap')),
  huruf             text not null constraint rp_huruf check (length(trim(huruf)) between 1 and 3),
  nilai_min         numeric(5,2),
  nilai_maks        numeric(5,2),
  sebutan           text not null,           -- Sangat Baik, Baik, … (bahasa Indonesia)
  sebutan_arab      text,                    -- Mumtaz, Jayyid Jiddan, … (UTAS)
  deskripsi         text,                    -- kalimat capaian (pengetahuan) / templat deskripsi pengembangan diri
  deskripsi_2       text,                    -- kalimat capaian keterampilan (Wustha)
  tuntas            boolean not null default true,
  urutan            smallint not null default 0,
  constraint rp_unik unique (academic_year_id, kelompok, huruf),
  constraint rp_rentang check ((nilai_min is null and nilai_maks is null)
    or (nilai_min is not null and nilai_maks is not null and nilai_min >= 0 and nilai_maks <= 100 and nilai_min <= nilai_maks))
);

create table if not exists public.grade_periods (
  id                uuid primary key default gen_random_uuid(),
  academic_year_id  uuid not null references public.academic_years(id) on delete cascade,
  jenis             text not null constraint gp_jenis check (jenis in ('sma','wustha','tahfizh')),
  semester          smallint not null constraint gp_semester check (semester in (1,2)),
  status            text not null default 'disiapkan' constraint gp_status check (status in ('disiapkan','dibuka','ditutup')),
  batas_isi         date,
  tanggal_rapor     date,
  hari_efektif      smallint constraint gp_hari check (hari_efektif is null or hari_efektif between 1 and 200),
  tema_kokurikuler  text,
  dibuka_pada       timestamptz,
  ditutup_pada      timestamptz,
  diubah_oleh       uuid references public.employees(id) on delete set null,
  updated_at        timestamptz not null default now(),
  constraint gp_unik unique (academic_year_id, jenis, semester)
);

create table if not exists public.grade_categories (
  id                uuid primary key default gen_random_uuid(),
  academic_year_id  uuid not null references public.academic_years(id) on delete cascade,
  jenis             text not null constraint gc_jenis check (jenis in ('sma','wustha')),
  kode              text not null constraint gc_kode check (kode ~ '^[A-Z0-9_]{1,20}$'),
  nama              text not null,
  aspek             text not null default 'pengetahuan' constraint gc_aspek check (aspek in ('pengetahuan','keterampilan')),
  bobot             numeric(5,2) not null default 0 constraint gc_bobot check (bobot between 0 and 100),
  berulang          boolean not null default true,     -- guru boleh menambah beberapa isian (Harian 1, Harian 2, …) yang dirata-rata
  aktif             boolean not null default true,
  urutan            smallint not null default 0,
  constraint gc_unik unique (academic_year_id, jenis, kode)
);

create table if not exists public.report_subjects (
  id                uuid primary key default gen_random_uuid(),
  academic_year_id  uuid not null references public.academic_years(id) on delete cascade,
  jenis             text not null constraint rsu_jenis check (jenis in ('sma','wustha')),
  tingkat           smallint not null constraint rsu_tingkat check (tingkat between 7 and 12),
  urutan            smallint not null default 0,
  kelompok          text,                              -- judul kelompok di rapor (mis. KELOMPOK UMUM); kosong = tanpa judul
  nama              text not null constraint rsu_nama check (length(trim(nama)) >= 2),
  singkatan         text,
  kkm               numeric(5,2) not null default 75 constraint rsu_kkm check (kkm between 0 and 100),
  sumber            text not null default 'mapel' constraint rsu_sumber check (sumber in ('mapel','tahfizh','manual')),
  mode_nilai        text constraint rsu_mode check (mode_nilai is null or mode_nilai in ('tunggal','akumulasi','rekomendasi')),
  aktif             boolean not null default true,
  catatan           text,
  updated_at        timestamptz not null default now(),
  constraint rsu_jenjang check ((jenis = 'wustha' and tingkat between 7 and 9) or (jenis = 'sma' and tingkat between 10 and 12)),
  constraint rsu_nama_unik unique (academic_year_id, jenis, tingkat, nama)
);
create index if not exists report_subjects_ta_idx on public.report_subjects (academic_year_id, jenis, tingkat, urutan);

create table if not exists public.report_subject_sources (
  report_subject_id uuid not null references public.report_subjects(id) on delete cascade,
  subject_id        uuid not null references public.subjects(id) on delete restrict,
  bobot             numeric(5,2) not null default 100 constraint rss_bobot check (bobot > 0 and bobot <= 100),
  primary key (report_subject_id, subject_id)
);

create table if not exists public.report_phrases (
  id          uuid primary key default gen_random_uuid(),
  kategori    text not null constraint rph_kategori check (kategori in ('catatan_wali','catatan_muhaffizh','kehadiran','kehadiran_halaqah')),
  jenis       text constraint rph_jenis check (jenis is null or jenis in ('sma','wustha','tahfizh')),  -- kosong = semua rapor
  bagian      text not null constraint rph_bagian check (bagian in ('pembuka','kelebihan','dorongan','penutup','ambang')),
  kunci       text,                     -- pemicu kelebihan/dorongan (mis. mapel_terbaik, kehadiran, hafalan)
  min_nilai   numeric(5,2),             -- bagian "ambang": berlaku bila persentase ≥ min_nilai
  teks        text not null constraint rph_teks check (length(trim(teks)) >= 5),
  aktif       boolean not null default true,
  urutan      smallint not null default 0,
  created_at  timestamptz not null default now()
);
create index if not exists report_phrases_kat_idx on public.report_phrases (kategori, bagian, kunci);

drop trigger if exists aa_updated on public.report_settings;
create trigger aa_updated before update on public.report_settings for each row execute function public.tg_updated_at();
drop trigger if exists aa_updated on public.grade_periods;
create trigger aa_updated before update on public.grade_periods for each row execute function public.tg_updated_at();
drop trigger if exists aa_updated on public.report_subjects;
create trigger aa_updated before update on public.report_subjects for each row execute function public.tg_updated_at();
do $$
declare t text;
begin
  foreach t in array array['report_settings','report_predicates','grade_periods','grade_categories','report_subjects','report_subject_sources','report_phrases'] loop
    execute format('drop trigger if exists zz_audit on public.%I', t);
    execute format('create trigger zz_audit after insert or update or delete on public.%I for each row execute function public.tg_audit()', t);
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists baca_semua on public.%I', t);
    execute format('create policy baca_semua on public.%I for select to authenticated using (true)', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 3. HAK
-- ---------------------------------------------------------------------
-- Pimpinan sebuah unit (kode org_units): Kepala Bidang unit itu/induknya, Direktur, Wadir, Yayasan, termasuk Plt yang berlaku.
create or replace function public.pimpinan_unit(p_kode text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.unit_pimpinan_saya() u join org_units o on o.id = u where o.kode = p_kode)
      or exists (select 1 from acting_assignments a join org_units o on o.id = a.org_unit_id
                  where a.employee_id = public.saya() and o.kode = p_kode
                    and public.hari_ini() between a.mulai and a.sampai)
$$;

create or replace function public._unit_jenis_rapor(p_jenis text)
returns text language sql immutable as $$
  select case p_jenis when 'sma' then 'SMA' when 'wustha' then 'WUSTHA' when 'tahfizh' then 'TAHFIZH' end
$$;

-- Pengatur penilaian: admin ber-izin atur_penilaian, hak fitur Nilai tingkat 3, superadmin; untuk satu jenis rapor juga
-- pimpinan bidangnya (Kepala SMA, Kepala Kesetaraan Wustha, Kepala Bidang Tahfizh, Direktur/Wadir, termasuk Plt).
-- Untuk rapor tahfizh juga pengatur tahfizh (atur_tahfizh).
create or replace function public.boleh_atur_penilaian(p_jenis text default null)
returns boolean language sql stable security definer set search_path = public as $$
  select public.admin_boleh('atur_penilaian') or public.tingkat_fitur('nilai') >= 3
      or (p_jenis is not null and public.pimpinan_unit(public._unit_jenis_rapor(p_jenis)))
      or (p_jenis = 'tahfizh' and public.boleh_atur_tahfizh())
$$;

create or replace function public.boleh_kelola_nilai()
returns boolean language sql stable security definer set search_path = public as $$
  select public.admin_boleh('kelola_nilai') or public.tingkat_fitur('nilai') >= 3
$$;

-- Hak menu Penilaian: menu = pengatur (salah satu jenis), pengelola nilai, atau pimpinan bidang terkait
create or replace function public.hak_penilaian()
returns jsonb language sql stable security definer set search_path = public as $$
  with h as (
    select public.boleh_atur_penilaian('sma') sma, public.boleh_atur_penilaian('wustha') wustha, public.boleh_atur_penilaian('tahfizh') tahfizh,
           public.boleh_atur_penilaian(null) umum, public.boleh_kelola_nilai() kelola,
           public.pimpinan_unit('SMA') p_sma, public.pimpinan_unit('WUSTHA') p_wustha, public.pimpinan_unit('TAHFIZH') p_tahfizh
  )
  select jsonb_build_object(
    'atur', jsonb_build_object('sma', h.sma, 'wustha', h.wustha, 'tahfizh', h.tahfizh),
    'atur_umum', h.umum, 'kelola', h.kelola,
    'pimpinan', to_jsonb(array_remove(array[case when h.p_sma then 'sma' end, case when h.p_wustha then 'wustha' end,
                                             case when h.p_tahfizh then 'tahfizh' end], null)),
    'menu', h.sma or h.wustha or h.tahfizh or h.kelola or h.p_sma or h.p_wustha or h.p_tahfizh)
  from h
$$;

-- ---------------------------------------------------------------------
-- 4. ISI AWAL PER TAHUN AJARAN
-- ---------------------------------------------------------------------
-- Hari efektif otomatis per semester (semester 1 = mulai TA s.d. 31 Desember; semester 2 = 1 Januari s.d. akhir TA):
-- hari yang bukan Ahad dan bukan libur kalender (sekolah untuk SMA/Wustha, tahfizh untuk rapor tahfizh).
create or replace function public.hari_efektif_otomatis(p_ta uuid, p_jenis text, p_semester smallint)
returns int language sql stable security definer set search_path = public as $$
  with ta as (select mulai, selesai from academic_years where id = p_ta),
  r as (select case when p_semester = 1 then ta.mulai else greatest(ta.mulai, make_date(extract(year from ta.selesai)::int, 1, 1)) end a,
               case when p_semester = 1 then least(ta.selesai, make_date(extract(year from ta.mulai)::int, 12, 31)) else ta.selesai end b
          from ta)
  select count(*)::int from r, generate_series(r.a, r.b, interval '1 day') d
   where extract(dow from d) <> 0 and not public.libur_tugas(d::date, case when p_jenis = 'tahfizh' then 'tahfizh' else 'sekolah' end)
$$;

create or replace function public._isi_mapel_rapor(p_ta uuid, p_jenis text, p_tingkat smallint, p_daftar jsonb)
returns void language plpgsql volatile security definer set search_path = public as $$
declare r jsonb; i int := 0; v_id uuid; v_sub uuid;
begin
  for r in select * from jsonb_array_elements(p_daftar) loop
    i := i + 1;
    insert into report_subjects (academic_year_id, jenis, tingkat, urutan, kelompok, nama, singkatan, kkm, sumber)
    values (p_ta, p_jenis, p_tingkat, i, nullif(r->>'kelompok', ''), r->>'nama', nullif(r->>'singkat', ''), (r->>'kkm')::numeric,
            coalesce(nullif(r->>'sumber', ''), 'mapel'))
    on conflict (academic_year_id, jenis, tingkat, nama) do nothing
    returning id into v_id;
    if v_id is not null and coalesce(r->>'mapel', '') <> '' then
      select id into v_sub from subjects where kode = r->>'mapel';
      if v_sub is not null then
        insert into report_subject_sources (report_subject_id, subject_id, bobot) values (v_id, v_sub, 100) on conflict do nothing;
      end if;
    end if;
  end loop;
end $$;

create or replace function public.siapkan_penilaian(p_ta uuid default null)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v_ta uuid := coalesce(p_ta, (select id from academic_years where aktif)); v_lalu uuid; j text; s smallint; t smallint;
        v_sma jsonb; v_w9 jsonb; v_w78 jsonb; m record; v_baru uuid;
begin
  if v_ta is null then return; end if;
  select a.id into v_lalu from academic_years a
   where a.id <> v_ta and a.mulai < (select mulai from academic_years where id = v_ta)
     and exists (select 1 from report_settings x where x.academic_year_id = a.id)
   order by a.mulai desc limit 1;

  -- 4a. Ketentuan per jenis rapor
  if v_lalu is not null then
    insert into report_settings (academic_year_id, jenis, judul, kop_kode, label_ambang, ambang_bawaan, mode_nilai, desimal, pakai_keterampilan,
      keterampilan_ikut, sikap_di_rapor, pakai_kokurikuler, pakai_tp, tampil_rata, tampil_peringkat, bahasa_predikat, signatory_id, jabatan_ttd,
      tempat, fase, dimensi, utas_juz_sma, utas_juz_wustha, catatan)
    select v_ta, jenis, judul, kop_kode, label_ambang, ambang_bawaan, mode_nilai, desimal, pakai_keterampilan,
      keterampilan_ikut, sikap_di_rapor, pakai_kokurikuler, pakai_tp, tampil_rata, tampil_peringkat, bahasa_predikat, signatory_id, jabatan_ttd,
      tempat, fase, dimensi, utas_juz_sma, utas_juz_wustha, catatan
      from report_settings where academic_year_id = v_lalu
    on conflict do nothing;
    insert into report_predicates (academic_year_id, kelompok, huruf, nilai_min, nilai_maks, sebutan, sebutan_arab, deskripsi, deskripsi_2, tuntas, urutan)
    select v_ta, kelompok, huruf, nilai_min, nilai_maks, sebutan, sebutan_arab, deskripsi, deskripsi_2, tuntas, urutan
      from report_predicates p where p.academic_year_id = v_lalu
       and not exists (select 1 from report_predicates x where x.academic_year_id = v_ta and x.kelompok = p.kelompok);
    insert into grade_categories (academic_year_id, jenis, kode, nama, aspek, bobot, berulang, aktif, urutan)
    select v_ta, jenis, kode, nama, aspek, bobot, berulang, aktif, urutan from grade_categories c where c.academic_year_id = v_lalu
       and not exists (select 1 from grade_categories x where x.academic_year_id = v_ta and x.jenis = c.jenis)
    on conflict do nothing;
    if not exists (select 1 from report_subjects where academic_year_id = v_ta) then
      for m in select * from report_subjects where academic_year_id = v_lalu loop
        insert into report_subjects (academic_year_id, jenis, tingkat, urutan, kelompok, nama, singkatan, kkm, sumber, mode_nilai, aktif, catatan)
        values (v_ta, m.jenis, m.tingkat, m.urutan, m.kelompok, m.nama, m.singkatan, m.kkm, m.sumber, m.mode_nilai, m.aktif, m.catatan)
        returning id into v_baru;
        insert into report_subject_sources (report_subject_id, subject_id, bobot)
        select v_baru, subject_id, bobot from report_subject_sources where report_subject_id = m.id;
      end loop;
    end if;
  end if;

  insert into report_settings (academic_year_id, jenis, judul, kop_kode, label_ambang, ambang_bawaan, pakai_keterampilan, sikap_di_rapor,
    pakai_kokurikuler, pakai_tp, tampil_rata, signatory_id, jabatan_ttd, fase, dimensi)
  values
    (v_ta, 'sma', 'Laporan Hasil Belajar', 'sma', 'KKTP', 75, false, false, true, true, false,
     (select id from signatories where aktif and jabatan_tertulis ilike '%SMA%' order by urutan limit 1), 'Kepala Sekolah',
     '{"10":"E","11":"F","12":"F"}'::jsonb,
     '["Keimanan dan Ketakwaan","Kewargaan","Penalaran Kritis","Kreativitas","Kolaborasi","Kemandirian","Kesehatan","Komunikasi"]'::jsonb),
    (v_ta, 'wustha', 'Pencapaian Kompetensi Peserta Didik', 'wustha', 'KKM', 70, true, true, false, false, true,
     (select id from signatories where aktif and jabatan_tertulis ilike '%Wustha%' order by urutan limit 1), 'Kepala Kesetaraan',
     '{}'::jsonb, '[]'::jsonb),
    (v_ta, 'tahfizh', 'Laporan Hasil Capaian Hafalan Al-Qur''an', null, 'KKM', 80, false, false, false, false, false,
     (select id from signatories where aktif and jabatan_tertulis ilike '%Tahfizh%' order by urutan limit 1), 'Kepala Tahfizh',
     '{}'::jsonb, '[]'::jsonb)
  on conflict do nothing;

  -- 4b. Predikat (isi awal sesuai contoh rapor pondok; dapat diubah)
  if not exists (select 1 from report_predicates where academic_year_id = v_ta and kelompok = 'sma') then
    insert into report_predicates (academic_year_id, kelompok, huruf, nilai_min, nilai_maks, sebutan, deskripsi, tuntas, urutan) values
      (v_ta, 'sma', 'A', 93, 100, 'Sangat Baik', 'Memiliki pengetahuan yang sangat baik dalam memahami', true, 1),
      (v_ta, 'sma', 'B', 86, 92.99, 'Baik', 'Memiliki pemahaman yang baik pada materi', true, 2),
      (v_ta, 'sma', 'C', 77, 85.99, 'Cukup', 'Cukup mampu memahami persoalan pada materi', true, 3),
      (v_ta, 'sma', 'D', 0, 76.99, 'Perlu Bimbingan', 'Perlu bimbingan dan pendalaman materi mengenai', false, 4);
  end if;
  if not exists (select 1 from report_predicates where academic_year_id = v_ta and kelompok = 'wustha') then
    insert into report_predicates (academic_year_id, kelompok, huruf, nilai_min, nilai_maks, sebutan, deskripsi, deskripsi_2, tuntas, urutan) values
      (v_ta, 'wustha', 'A', 85, 100, 'Sangat Baik', 'Mampu menguasai seluruh kompetensi pengetahuan dengan sangat baik',
       'Mampu menguasai seluruh kompetensi keterampilan dengan sangat baik', true, 1),
      (v_ta, 'wustha', 'B', 75, 84.99, 'Baik', 'Mampu menguasai seluruh kompetensi pengetahuan dengan baik',
       'Mampu menguasai seluruh kompetensi keterampilan dengan baik', true, 2),
      (v_ta, 'wustha', 'C', 70, 74.99, 'Cukup', 'Cukup mampu menguasai kompetensi pengetahuan',
       'Cukup mampu menguasai kompetensi keterampilan', true, 3),
      (v_ta, 'wustha', 'D', 0, 69.99, 'Kurang', 'Perlu bimbingan dalam menguasai kompetensi pengetahuan',
       'Perlu bimbingan dalam menguasai kompetensi keterampilan', false, 4);
  end if;
  if not exists (select 1 from report_predicates where academic_year_id = v_ta and kelompok = 'utas') then
    insert into report_predicates (academic_year_id, kelompok, huruf, nilai_min, nilai_maks, sebutan, sebutan_arab, tuntas, urutan) values
      (v_ta, 'utas', 'A', 90, 100, 'Istimewa', 'Mumtaz', true, 1),
      (v_ta, 'utas', 'B', 80, 89.99, 'Sangat Baik', 'Jayyid Jiddan', true, 2),
      (v_ta, 'utas', 'C', 70, 79.99, 'Baik', 'Jayyid', false, 3),
      (v_ta, 'utas', 'D', 60, 69.99, 'Cukup', 'Maqbul', false, 4),
      (v_ta, 'utas', 'E', 0, 59.99, 'Kurang', 'Rasib', false, 5);
  end if;
  if not exists (select 1 from report_predicates where academic_year_id = v_ta and kelompok = 'pd') then
    insert into report_predicates (academic_year_id, kelompok, huruf, sebutan, deskripsi, tuntas, urutan) values
      (v_ta, 'pd', 'A', 'Sangat Baik', 'Sangat baik dalam mengikuti kegiatan {kegiatan}', true, 1),
      (v_ta, 'pd', 'B', 'Baik', 'Baik dalam mengikuti kegiatan {kegiatan}', true, 2),
      (v_ta, 'pd', 'C', 'Cukup', 'Cukup baik dalam mengikuti kegiatan {kegiatan}', true, 3),
      (v_ta, 'pd', 'D', 'Kurang', 'Perlu bimbingan dalam mengikuti kegiatan {kegiatan}', false, 4);
  end if;
  if not exists (select 1 from report_predicates where academic_year_id = v_ta and kelompok = 'sikap') then
    insert into report_predicates (academic_year_id, kelompok, huruf, sebutan, tuntas, urutan) values
      (v_ta, 'sikap', 'A', 'Sangat Baik', true, 1), (v_ta, 'sikap', 'B', 'Baik', true, 2),
      (v_ta, 'sikap', 'C', 'Cukup', true, 3), (v_ta, 'sikap', 'K', 'Kurang', false, 4);
  end if;

  -- 4c. Kategori isian nilai guru dan bobotnya
  foreach j in array array['sma','wustha'] loop
    if not exists (select 1 from grade_categories where academic_year_id = v_ta and jenis = j) then
      insert into grade_categories (academic_year_id, jenis, kode, nama, aspek, bobot, berulang, urutan) values
        (v_ta, j, 'HARIAN', 'Nilai harian', 'pengetahuan', 25, true, 1),
        (v_ta, j, 'ULANGAN', 'Ulangan', 'pengetahuan', 25, true, 2),
        (v_ta, j, 'UTS', 'Ujian tengah semester', 'pengetahuan', 20, false, 3),
        (v_ta, j, 'UAS', 'Ujian akhir semester', 'pengetahuan', 30, false, 4);
      if j = 'wustha' then
        insert into grade_categories (academic_year_id, jenis, kode, nama, aspek, bobot, berulang, urutan) values
          (v_ta, j, 'PRAKTIK', 'Praktik', 'keterampilan', 50, true, 5),
          (v_ta, j, 'PROYEK', 'Proyek/portofolio', 'keterampilan', 50, true, 6);
      end if;
    end if;
  end loop;

  -- 4d. Periode penilaian (2 semester × 3 jenis rapor)
  foreach j in array array['sma','wustha','tahfizh'] loop
    foreach s in array array[1,2]::smallint[] loop
      insert into grade_periods (academic_year_id, jenis, semester) values (v_ta, j, s) on conflict do nothing;
    end loop;
  end loop;

  -- 4e. Mapel rapor isi awal (dari contoh rapor pondok; sumber dicocokkan dengan kode mapel ajar bila ada)
  if not exists (select 1 from report_subjects where academic_year_id = v_ta) then
    v_sma := '[
      {"kelompok":"KELOMPOK UMUM","nama":"Pendidikan Agama dan Budi Pekerti","singkat":"PAI","kkm":80,"mapel":"PAI"},
      {"kelompok":"KELOMPOK UMUM","nama":"Pendidikan Pancasila dan Kewarganegaraan","singkat":"PKn","kkm":75,"mapel":"PKN"},
      {"kelompok":"KELOMPOK UMUM","nama":"Bahasa Indonesia","singkat":"IND","kkm":75,"mapel":"BIND"},
      {"kelompok":"KELOMPOK UMUM","nama":"Bahasa Inggris","singkat":"ING","kkm":75,"mapel":"BING"},
      {"kelompok":"KELOMPOK UMUM","nama":"Matematika","singkat":"MTK","kkm":75,"mapel":"MTK"},
      {"kelompok":"KELOMPOK UMUM","nama":"Seni Prakarya dan Kewirausahaan","singkat":"SENI","kkm":75,"mapel":"SBDP"},
      {"kelompok":"KELOMPOK UMUM","nama":"Pendidikan Jasmani, Olah Raga, dan Kesehatan","singkat":"PJOK","kkm":75,"mapel":"PJOK"},
      {"kelompok":"KELOMPOK UMUM","nama":"Informatika, Koding dan AI","singkat":"TIK","kkm":75,"mapel":"INF"},
      {"kelompok":"KELOMPOK UMUM","nama":"Ilmu Pengetahuan Sosial","singkat":"IPS","kkm":75,"mapel":"IPS"},
      {"kelompok":"KELOMPOK UMUM","nama":"Ilmu Pengetahuan Alam","singkat":"IPA","kkm":75,"mapel":"IPA"},
      {"kelompok":"KELOMPOK UMUM","nama":"Adab","singkat":"ADB","kkm":80},
      {"kelompok":"KELOMPOK PEMINATAN","nama":"Aqidah","singkat":"AQD","kkm":80,"mapel":"AQIDAH"},
      {"kelompok":"KELOMPOK MUATAN LOKAL","nama":"Bahasa Arab","singkat":"ARB","kkm":80,"mapel":"BARAB"},
      {"kelompok":"KELOMPOK MUATAN LOKAL","nama":"Ilmu Al-Qur''an","singkat":"IQ","kkm":80},
      {"kelompok":"KELOMPOK MUATAN LOKAL","nama":"Tahfidz","singkat":"THZ","kkm":80,"sumber":"tahfizh"}]';
    v_w9 := '[
      {"nama":"Bahasa Indonesia","singkat":"BIND","kkm":70,"mapel":"BIND"},{"nama":"Bahasa Inggris","singkat":"BING","kkm":70,"mapel":"BING"},
      {"nama":"Matematika","singkat":"MTK","kkm":70,"mapel":"MTK"},{"nama":"Ilmu Pengetahuan Alam","singkat":"IPA","kkm":70,"mapel":"IPA"},
      {"nama":"Ilmu Pengetahuan Sosial","singkat":"IPS","kkm":70,"mapel":"IPS"},{"nama":"Pendidikan Kewarganegaraan","singkat":"PKN","kkm":70,"mapel":"PKN"},
      {"nama":"Al-Qur''an","singkat":"QUR","kkm":70},{"nama":"Hadits","singkat":"HDS","kkm":70,"mapel":"HADITS"},
      {"nama":"Akidah","singkat":"AKD","kkm":70,"mapel":"AQIDAH"},{"nama":"Akhlak","singkat":"AKH","kkm":70},
      {"nama":"Fikih","singkat":"FIK","kkm":70,"mapel":"FIQIH"},{"nama":"Bahasa Arab","singkat":"ARB","kkm":70,"mapel":"BARAB"},
      {"nama":"Tajwid","singkat":"TJW","kkm":70,"mapel":"TAHSIN"},{"nama":"Sejarah Peradaban Islam","singkat":"SPI","kkm":70},
      {"nama":"Tafsir","singkat":"TFS","kkm":70,"mapel":"TAFSIR"}]';
    v_w78 := '[
      {"nama":"Tajwid","singkat":"TJW","kkm":70,"mapel":"TAHSIN"},{"nama":"Hadits","singkat":"HDS","kkm":70,"mapel":"HADITS"},
      {"nama":"Tafsir","singkat":"TFS","kkm":70,"mapel":"TAFSIR"},{"nama":"Akidah","singkat":"AKD","kkm":70,"mapel":"AQIDAH"},
      {"nama":"Akhlak","singkat":"AKH","kkm":70},{"nama":"Fikih","singkat":"FIK","kkm":70,"mapel":"FIQIH"},
      {"nama":"Bahasa Arab","singkat":"ARB","kkm":70,"mapel":"BARAB"},{"nama":"Qira''ah wal Kitabah","singkat":"QWK","kkm":70},
      {"nama":"Al-Qur''an","singkat":"QUR","kkm":70},{"nama":"Sejarah Peradaban Islam","singkat":"SPI","kkm":70},
      {"nama":"Khat","singkat":"KHT","kkm":70},{"nama":"TIK","singkat":"TIK","kkm":70,"mapel":"INF"}]';
    foreach t in array array[10,11,12]::smallint[] loop perform public._isi_mapel_rapor(v_ta, 'sma', t, v_sma); end loop;
    perform public._isi_mapel_rapor(v_ta, 'wustha', 7::smallint, v_w78);
    perform public._isi_mapel_rapor(v_ta, 'wustha', 8::smallint, v_w78);
    perform public._isi_mapel_rapor(v_ta, 'wustha', 9::smallint, v_w9);
  end if;
end $$;

-- Bank kalimat (tidak per tahun ajaran): isi awal sekali
insert into public.report_phrases (kategori, jenis, bagian, kunci, min_nilai, teks, urutan)
select v.* from (values
  -- Catatan kehadiran rapor sekolah (dipilih menurut persentase kehadiran kelas)
  ('kehadiran', 'wustha', 'ambang', null, 90::numeric, 'Perhatian dan keseriusan dalam mengikuti pelajaran sangat memuaskan, mohon kehadirannya dipertahankan!', 1),
  ('kehadiran', 'wustha', 'ambang', null, 75, 'Perhatian dan keseriusan dalam mengikuti pelajaran cukup memuaskan, mohon kehadirannya ditingkatkan lagi!', 2),
  ('kehadiran', 'wustha', 'ambang', null, 0, 'Perhatian dan keseriusan dalam mengikuti pelajaran kurang memuaskan, mohon kehadirannya lebih ditingkatkan lagi!', 3),
  ('kehadiran', 'sma', 'ambang', null, 95, 'Kehadiran ananda sangat baik, hal ini menunjukkan komitmen dan disiplin yang luar biasa terhadap proses pembelajaran.', 1),
  ('kehadiran', 'sma', 'ambang', null, 85, 'Kehadiran ananda baik; pertahankan dan tingkatkan kedisiplinan dalam mengikuti pembelajaran.', 2),
  ('kehadiran', 'sma', 'ambang', null, 0, 'Kehadiran ananda perlu ditingkatkan agar proses pembelajaran dapat diikuti dengan optimal.', 3),
  ('kehadiran_halaqah', 'tahfizh', 'ambang', null, 90, 'Kehadiran ananda di halaqah sangat baik, pertahankan!', 1),
  ('kehadiran_halaqah', 'tahfizh', 'ambang', null, 75, 'Kehadiran ananda di halaqah baik, tingkatkan lagi.', 2),
  ('kehadiran_halaqah', 'tahfizh', 'ambang', null, 0, 'Kehadiran ananda di halaqah perlu ditingkatkan agar hafalan terjaga.', 3),
  -- Catatan wali kelas: pembuka
  ('catatan_wali', null, 'pembuka', null, null, 'Alhamdulillah, Ananda {panggilan} telah menyelesaikan semester ini dengan baik.', 1),
  ('catatan_wali', null, 'pembuka', null, null, 'Ananda {panggilan} menunjukkan semangat belajar yang patut disyukuri pada semester ini.', 2),
  ('catatan_wali', null, 'pembuka', null, null, 'Ananda {panggilan} telah berproses dengan sungguh-sungguh selama semester ini.', 3),
  ('catatan_wali', null, 'pembuka', null, null, '_Barakallahu fiik_, Ananda {panggilan}, atas usaha dan kesungguhan selama semester ini.', 4),
  -- Catatan wali kelas: kelebihan yang diapresiasi (kunci = pemicu dari data santri)
  ('catatan_wali', null, 'kelebihan', 'mapel_terbaik', null, 'Capaian Ananda pada {mapel} sangat menonjol dan patut diapresiasi.', 1),
  ('catatan_wali', null, 'kelebihan', 'mapel_terbaik', null, 'Ananda unggul dalam {mapel} dengan nilai {nilai}.', 2),
  ('catatan_wali', null, 'kelebihan', 'rata_tinggi', null, 'Rata-rata nilai Ananda sangat baik, tanda kesungguhan belajar di hampir semua pelajaran.', 1),
  ('catatan_wali', null, 'kelebihan', 'kenaikan', null, 'Nilai Ananda meningkat dibanding semester lalu, terutama pada {mapel}.', 1),
  ('catatan_wali', null, 'kelebihan', 'kehadiran', null, 'Kehadiran Ananda sangat baik ({persen}%), cerminan kedisiplinan yang tinggi.', 1),
  ('catatan_wali', null, 'kelebihan', 'kehadiran', null, 'Ananda hampir tidak pernah absen, sebuah teladan kedisiplinan bagi teman-temannya.', 2),
  ('catatan_wali', null, 'kelebihan', 'hafalan', null, 'Hafalan Al-Qur''an Ananda bertambah {tambah_juz} juz pada semester ini, sebuah capaian yang membanggakan.', 1),
  ('catatan_wali', null, 'kelebihan', 'utas', null, 'Ananda meraih predikat {predikat_utas} pada Ujian Tahfizh Akhir Semester.', 1),
  ('catatan_wali', null, 'kelebihan', 'pd', null, 'Ananda juga aktif dan berprestasi dalam kegiatan {kegiatan}.', 1),
  ('catatan_wali', null, 'kelebihan', 'sikap', null, 'Sikap dan akhlak Ananda dalam keseharian sangat baik dan menjadi contoh.', 1),
  -- Catatan wali kelas: dorongan
  ('catatan_wali', null, 'dorongan', 'mapel_lemah', null, 'Tingkatkan lagi pemahaman pada {mapel_lemah} dengan lebih banyak berlatih dan bertanya.', 1),
  ('catatan_wali', null, 'dorongan', 'mapel_lemah', null, 'Berikan perhatian lebih pada {mapel_lemah} agar capaiannya semakin baik.', 2),
  ('catatan_wali', null, 'dorongan', 'kehadiran', null, 'Perhatikan kehadiran agar tidak tertinggal pelajaran.', 1),
  ('catatan_wali', null, 'dorongan', 'hafalan', null, 'Jaga murajaah agar hafalan semakin kuat dan lancar.', 1),
  ('catatan_wali', null, 'dorongan', 'umum', null, 'Terus jaga semangat belajar dan pertahankan konsistensi.', 1),
  ('catatan_wali', null, 'dorongan', 'umum', null, 'Pertahankan prestasi ini dan teruslah menjadi pribadi yang lebih baik.', 2),
  -- Catatan wali kelas: penutup
  ('catatan_wali', null, 'penutup', null, null, 'Semoga Allah memudahkan langkah Ananda meraih cita-cita.', 1),
  ('catatan_wali', null, 'penutup', null, null, 'Teruslah bersemangat; semoga ilmu yang dipelajari menjadi berkah.', 2),
  ('catatan_wali', null, 'penutup', null, null, 'Semoga Allah menjadikan Ananda generasi Qur''ani yang berakhlak mulia.', 3),
  ('catatan_wali', null, 'penutup', null, null, '_Jazakallahu khairan_ atas kesungguhan Ananda.', 4),
  -- Catatan muhaffizh
  ('catatan_muhaffizh', 'tahfizh', 'pembuka', null, null, 'Alhamdulillah, Ananda {panggilan} telah mengikuti halaqah semester ini dengan baik.', 1),
  ('catatan_muhaffizh', 'tahfizh', 'pembuka', null, null, '_Barakallahu fiik_, Ananda {panggilan}.', 2),
  ('catatan_muhaffizh', 'tahfizh', 'kelebihan', 'target_tercapai', null, 'Target hafalan semester ini tercapai dengan baik.', 1),
  ('catatan_muhaffizh', 'tahfizh', 'kelebihan', 'tambah_banyak', null, 'Hafalan Ananda bertambah {tambah_juz} juz, melampaui harapan.', 1),
  ('catatan_muhaffizh', 'tahfizh', 'kelebihan', 'utas', null, 'Ananda meraih predikat {predikat_utas} pada Ujian Tahfizh Akhir Semester.', 1),
  ('catatan_muhaffizh', 'tahfizh', 'kelebihan', 'kehadiran', null, 'Kehadiran Ananda di halaqah sangat baik ({persen}%).', 1),
  ('catatan_muhaffizh', 'tahfizh', 'kelebihan', 'kenaikan_juz', null, 'Ananda lulus ujian kenaikan juz dengan baik.', 1),
  ('catatan_muhaffizh', 'tahfizh', 'dorongan', 'target_kurang', null, 'Tingkatkan lagi jumlah setoran agar target hafalan tercapai.', 1),
  ('catatan_muhaffizh', 'tahfizh', 'dorongan', 'kehadiran', null, 'Perhatikan kehadiran di halaqah agar setoran tidak tertinggal.', 1),
  ('catatan_muhaffizh', 'tahfizh', 'dorongan', 'murajaah', null, 'Perbanyak murajaah agar hafalan semakin mutqin.', 1),
  ('catatan_muhaffizh', 'tahfizh', 'penutup', null, null, 'Semoga Allah menjadikan Ananda penghafal Al-Qur''an yang mengamalkannya.', 1),
  ('catatan_muhaffizh', 'tahfizh', 'penutup', null, null, 'Teruslah bersemangat bersama Al-Qur''an.', 2)
) as v(kategori, jenis, bagian, kunci, min_nilai, teks, urutan)
where not exists (select 1 from public.report_phrases);

create or replace function public.tg_academic_years_penilaian()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.siapkan_penilaian(new.id);
  return new;
end $$;
drop trigger if exists zz_penilaian on public.academic_years;
create trigger zz_penilaian after insert on public.academic_years for each row execute function public.tg_academic_years_penilaian();

-- ---------------------------------------------------------------------
-- 5. BACA PENGATURAN (satu panggilan)
-- ---------------------------------------------------------------------
create or replace function public.pengaturan_penilaian(p_ta uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_ta uuid := coalesce(p_ta, (select id from academic_years where aktif));
begin
  if public.saya() is null then raise exception 'Akun Anda belum aktif.'; end if;
  if v_ta is null then return null; end if;
  return jsonb_build_object(
    'ta', (select jsonb_build_object('id', id, 'nama', nama, 'mulai', mulai, 'selesai', selesai, 'aktif', aktif, 'terkunci', terkunci, 'semester', semester)
             from academic_years where id = v_ta),
    'ketentuan', coalesce((select jsonb_object_agg(r.jenis, to_jsonb(r) || jsonb_build_object(
                    'penanda', (select jsonb_build_object('jabatan', s.jabatan_tertulis, 'nama', s.nama, 'niy', s.niy) from signatories s where s.id = r.signatory_id)))
                  from report_settings r where r.academic_year_id = v_ta), '{}'::jsonb),
    'predikat', coalesce((select jsonb_agg(to_jsonb(p) order by p.kelompok, p.urutan) from report_predicates p where p.academic_year_id = v_ta), '[]'::jsonb),
    'kategori', coalesce((select jsonb_agg(to_jsonb(c) order by c.jenis, c.aspek, c.urutan) from grade_categories c where c.academic_year_id = v_ta), '[]'::jsonb),
    'periode', coalesce((select jsonb_agg(to_jsonb(g) || jsonb_build_object('hari_otomatis', public.hari_efektif_otomatis(v_ta, g.jenis, g.semester),
                    'pengubah', (select nama_lengkap from employees where id = g.diubah_oleh))
                  order by array_position(array['sma','wustha','tahfizh'], g.jenis), g.semester)
                  from grade_periods g where g.academic_year_id = v_ta), '[]'::jsonb),
    'mapel', coalesce((select jsonb_agg(to_jsonb(m) || jsonb_build_object('sumber_mapel', coalesce((
                      select jsonb_agg(jsonb_build_object('subject_id', s.id, 'kode', s.kode, 'nama', s.nama, 'jenjang', s.jenjang, 'aktif', s.aktif, 'bobot', x.bobot)
                                       order by x.bobot desc, s.urutan)
                        from report_subject_sources x join subjects s on s.id = x.subject_id where x.report_subject_id = m.id), '[]'::jsonb),
                    'pengampu', (select count(*) from teaching_assignments t join student_groups g on g.id = t.group_id
                                  where t.academic_year_id = v_ta and g.tingkat = m.tingkat
                                    and t.subject_id in (select subject_id from report_subject_sources where report_subject_id = m.id)))
                  order by m.jenis, m.tingkat, m.urutan)
                  from report_subjects m where m.academic_year_id = v_ta), '[]'::jsonb),
    'kalimat', coalesce((select jsonb_agg(to_jsonb(k) order by k.kategori, k.jenis nulls first, k.bagian, k.kunci nulls first, k.min_nilai desc nulls last, k.urutan)
                  from report_phrases k), '[]'::jsonb),
    'hak', public.hak_penilaian());
end $$;

-- ---------------------------------------------------------------------
-- 6. SIMPAN
-- ---------------------------------------------------------------------
create or replace function public._cek_atur_penilaian(p_ta uuid, p_jenis text)
returns void language plpgsql stable security definer set search_path = public as $$
begin
  if not (case when p_jenis is null then public.boleh_atur_penilaian(null) or public.boleh_atur_penilaian('sma')
                 or public.boleh_atur_penilaian('wustha') or public.boleh_atur_penilaian('tahfizh')
               else public.boleh_atur_penilaian(p_jenis) end) then
    raise exception 'Anda tidak berwenang mengubah pengaturan penilaian%.', case p_jenis when 'sma' then ' SMA' when 'wustha' then ' Wustha'
      when 'tahfizh' then ' tahfizh' else '' end using errcode = '42501';
  end if;
  if not exists (select 1 from academic_years where id = p_ta) then raise exception 'Tahun ajaran tidak ditemukan.'; end if;
  perform public._ta_boleh_ubah(p_ta);
end $$;

-- p: isian report_settings yang dikirim (bagian yang tidak dikirim tidak berubah)
create or replace function public.simpan_ketentuan_rapor(p_ta uuid, p_jenis text, p jsonb)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  perform public._cek_atur_penilaian(p_ta, p_jenis);
  perform public.siapkan_penilaian(p_ta);
  if p ? 'judul' and coalesce(trim(p->>'judul'), '') = '' then raise exception 'Judul rapor wajib diisi.'; end if;
  update report_settings set
    judul              = case when p ? 'judul' then trim(p->>'judul') else judul end,
    kop_kode           = case when p ? 'kop_kode' then nullif(p->>'kop_kode', '') else kop_kode end,
    label_ambang       = coalesce(nullif(p->>'label_ambang', ''), label_ambang),
    ambang_bawaan      = coalesce((p->>'ambang_bawaan')::numeric, ambang_bawaan),
    mode_nilai         = coalesce(nullif(p->>'mode_nilai', ''), mode_nilai),
    desimal            = coalesce((p->>'desimal')::smallint, desimal),
    pakai_keterampilan = coalesce((p->>'pakai_keterampilan')::boolean, pakai_keterampilan),
    keterampilan_ikut  = coalesce((p->>'keterampilan_ikut')::boolean, keterampilan_ikut),
    sikap_di_rapor     = coalesce((p->>'sikap_di_rapor')::boolean, sikap_di_rapor),
    pakai_kokurikuler  = coalesce((p->>'pakai_kokurikuler')::boolean, pakai_kokurikuler),
    pakai_tp           = coalesce((p->>'pakai_tp')::boolean, pakai_tp),
    tampil_rata        = coalesce((p->>'tampil_rata')::boolean, tampil_rata),
    tampil_peringkat   = coalesce((p->>'tampil_peringkat')::boolean, tampil_peringkat),
    bahasa_predikat    = coalesce(nullif(p->>'bahasa_predikat', ''), bahasa_predikat),
    signatory_id       = case when p ? 'signatory_id' then nullif(p->>'signatory_id', '')::uuid else signatory_id end,
    jabatan_ttd        = case when p ? 'jabatan_ttd' then nullif(trim(p->>'jabatan_ttd'), '') else jabatan_ttd end,
    tempat             = coalesce(nullif(trim(p->>'tempat'), ''), tempat),
    fase               = coalesce(p->'fase', fase),
    dimensi            = coalesce(p->'dimensi', dimensi),
    utas_juz_sma       = coalesce((p->>'utas_juz_sma')::smallint, utas_juz_sma),
    utas_juz_wustha    = coalesce((p->>'utas_juz_wustha')::smallint, utas_juz_wustha),
    catatan            = case when p ? 'catatan' then nullif(trim(p->>'catatan'), '') else catatan end,
    updated_by         = public.saya()
  where academic_year_id = p_ta and jenis = p_jenis;
  if not found then raise exception 'Jenis rapor tidak dikenal.'; end if;
exception
  when check_violation then raise exception 'Isian ketentuan di luar batas (ambang 0–100, desimal 0–2, juz UTAS 1–30).';
  when invalid_text_representation then raise exception 'Isian ketentuan tidak sah. Periksa angka yang diisi.';
end $$;

-- p: [{huruf, nilai_min?, nilai_maks?, sebutan, sebutan_arab?, deskripsi?, deskripsi_2?, tuntas?}] — mengganti seluruh kelompok
create or replace function public.simpan_predikat_rapor(p_ta uuid, p_kelompok text, p jsonb)
returns void language plpgsql volatile security definer set search_path = public as $$
declare r jsonb; i int := 0; v_n int; v_angka boolean := p_kelompok in ('sma','wustha','utas'); v_jenis text;
begin
  v_jenis := case p_kelompok when 'utas' then 'tahfizh' when 'sma' then 'sma' when 'wustha' then 'wustha' else null end;
  perform public._cek_atur_penilaian(p_ta, v_jenis);
  if p_kelompok not in ('sma','wustha','utas','pd','sikap') then raise exception 'Kelompok predikat tidak dikenal.'; end if;
  if jsonb_typeof(p) <> 'array' or jsonb_array_length(p) < 2 then raise exception 'Predikat minimal dua baris.'; end if;
  if exists (select 1 from jsonb_array_elements(p) x where coalesce(trim(x->>'huruf'), '') = '' or coalesce(trim(x->>'sebutan'), '') = '') then
    raise exception 'Setiap predikat wajib berhuruf dan bersebutan.';
  end if;
  select count(*) - count(distinct upper(trim(x->>'huruf'))) into v_n from jsonb_array_elements(p) x;
  if v_n > 0 then raise exception 'Huruf predikat tidak boleh kembar.'; end if;
  if v_angka then
    if exists (select 1 from jsonb_array_elements(p) x where nullif(x->>'nilai_min', '') is null or nullif(x->>'nilai_maks', '') is null
                  or (x->>'nilai_min')::numeric > (x->>'nilai_maks')::numeric or (x->>'nilai_min')::numeric < 0 or (x->>'nilai_maks')::numeric > 100) then
      raise exception 'Setiap rentang wajib diisi 0–100 dengan batas bawah tidak melebihi batas atas.';
    end if;
    select count(*) into v_n from jsonb_array_elements(p) a, jsonb_array_elements(p) b
     where a <> b and (a->>'nilai_min')::numeric <= (b->>'nilai_maks')::numeric and (b->>'nilai_min')::numeric <= (a->>'nilai_maks')::numeric;
    if v_n > 0 then raise exception 'Rentang nilai predikat ada yang bertumpuk. Periksa batas bawah dan atasnya.'; end if;
  end if;
  delete from report_predicates where academic_year_id = p_ta and kelompok = p_kelompok;
  for r in select * from jsonb_array_elements(p)
           order by case when v_angka then (value->>'nilai_min')::numeric end desc nulls last, (value->>'urutan')::int nulls last loop
    i := i + 1;
    insert into report_predicates (academic_year_id, kelompok, huruf, nilai_min, nilai_maks, sebutan, sebutan_arab, deskripsi, deskripsi_2, tuntas, urutan)
    values (p_ta, p_kelompok, upper(trim(r->>'huruf')),
            case when v_angka then (r->>'nilai_min')::numeric end, case when v_angka then (r->>'nilai_maks')::numeric end,
            trim(r->>'sebutan'), nullif(trim(r->>'sebutan_arab'), ''), nullif(trim(r->>'deskripsi'), ''), nullif(trim(r->>'deskripsi_2'), ''),
            coalesce((r->>'tuntas')::boolean, true), i);
  end loop;
end $$;

-- p: [{id?, kode?, nama, aspek, bobot, berulang, aktif}] — daftar lengkap kategori satu jenis rapor
create or replace function public.simpan_komponen_nilai(p_ta uuid, p_jenis text, p jsonb)
returns void language plpgsql volatile security definer set search_path = public as $$
declare r jsonb; i int := 0; v_kode text; v_ids uuid[] := '{}'; v_id uuid; v_sum numeric; v_kt boolean;
begin
  perform public._cek_atur_penilaian(p_ta, p_jenis);
  if p_jenis not in ('sma','wustha') then raise exception 'Komponen nilai hanya untuk rapor SMA dan Wustha.'; end if;
  if jsonb_typeof(p) <> 'array' or jsonb_array_length(p) = 0 then raise exception 'Minimal satu komponen nilai.'; end if;
  select pakai_keterampilan into v_kt from report_settings where academic_year_id = p_ta and jenis = p_jenis;
  -- Bobot komponen aktif per aspek harus berjumlah 100
  for r in select jsonb_build_object('aspek', a) from unnest(array['pengetahuan','keterampilan']) a loop
    select coalesce(sum((x->>'bobot')::numeric), 0) into v_sum from jsonb_array_elements(p) x
     where coalesce(x->>'aspek', 'pengetahuan') = r->>'aspek' and coalesce((x->>'aktif')::boolean, true);
    if (r->>'aspek' = 'pengetahuan' or coalesce(v_kt, false)) and v_sum <> 100
       and exists (select 1 from jsonb_array_elements(p) x where coalesce(x->>'aspek', 'pengetahuan') = r->>'aspek' and coalesce((x->>'aktif')::boolean, true)) then
      raise exception 'Bobot komponen % harus berjumlah 100%% (sekarang %).', r->>'aspek', v_sum;
    end if;
  end loop;
  if not exists (select 1 from jsonb_array_elements(p) x where coalesce(x->>'aspek', 'pengetahuan') = 'pengetahuan' and coalesce((x->>'aktif')::boolean, true)) then
    raise exception 'Minimal satu komponen pengetahuan yang aktif.';
  end if;
  for r in select * from jsonb_array_elements(p) loop
    i := i + 1;
    if coalesce(trim(r->>'nama'), '') = '' then raise exception 'Nama komponen wajib diisi.'; end if;
    v_kode := upper(regexp_replace(coalesce(nullif(trim(r->>'kode'), ''), trim(r->>'nama')), '[^A-Za-z0-9]+', '_', 'g'));
    v_kode := left(trim(both '_' from v_kode), 20);
    v_id := nullif(r->>'id', '')::uuid;
    if v_id is not null and exists (select 1 from grade_categories where id = v_id and academic_year_id = p_ta and jenis = p_jenis) then
      update grade_categories set nama = trim(r->>'nama'), aspek = coalesce(nullif(r->>'aspek', ''), 'pengetahuan'),
             bobot = coalesce((r->>'bobot')::numeric, 0), berulang = coalesce((r->>'berulang')::boolean, true),
             aktif = coalesce((r->>'aktif')::boolean, true), urutan = i
       where id = v_id;
    else
      insert into grade_categories (academic_year_id, jenis, kode, nama, aspek, bobot, berulang, aktif, urutan)
      values (p_ta, p_jenis, v_kode, trim(r->>'nama'), coalesce(nullif(r->>'aspek', ''), 'pengetahuan'), coalesce((r->>'bobot')::numeric, 0),
              coalesce((r->>'berulang')::boolean, true), coalesce((r->>'aktif')::boolean, true), i)
      on conflict (academic_year_id, jenis, kode) do update set nama = excluded.nama, aspek = excluded.aspek, bobot = excluded.bobot,
             berulang = excluded.berulang, aktif = excluded.aktif, urutan = excluded.urutan
      returning id into v_id;
    end if;
    v_ids := v_ids || v_id;
  end loop;
  -- Komponen yang tidak dikirim dihapus (Tahap 2: komponen yang sudah berisi nilai dinonaktifkan, bukan dihapus)
  delete from grade_categories where academic_year_id = p_ta and jenis = p_jenis and id <> all(v_ids);
exception
  when check_violation then raise exception 'Bobot komponen harus 0–100.';
  when unique_violation then raise exception 'Nama/kode komponen kembar. Gunakan nama yang berbeda.';
end $$;

-- p: {status?, batas_isi?, tanggal_rapor?, hari_efektif?, tema_kokurikuler?}
create or replace function public.simpan_periode_nilai(p_id uuid, p jsonb)
returns void language plpgsql volatile security definer set search_path = public as $$
declare g grade_periods; v_status text := nullif(p->>'status', '');
begin
  select * into g from grade_periods where id = p_id;
  if g.id is null then raise exception 'Periode penilaian tidak ditemukan.'; end if;
  perform public._cek_atur_penilaian(g.academic_year_id, g.jenis);
  if v_status is not null and v_status not in ('disiapkan','dibuka','ditutup') then raise exception 'Status periode tidak dikenal.'; end if;
  update grade_periods set
    status           = coalesce(v_status, status),
    batas_isi        = case when p ? 'batas_isi' then nullif(p->>'batas_isi', '')::date else batas_isi end,
    tanggal_rapor    = case when p ? 'tanggal_rapor' then nullif(p->>'tanggal_rapor', '')::date else tanggal_rapor end,
    hari_efektif     = case when p ? 'hari_efektif' then nullif(p->>'hari_efektif', '')::smallint else hari_efektif end,
    tema_kokurikuler = case when p ? 'tema_kokurikuler' then nullif(trim(p->>'tema_kokurikuler'), '') else tema_kokurikuler end,
    dibuka_pada      = case when v_status = 'dibuka' and g.status <> 'dibuka' then now() else dibuka_pada end,
    ditutup_pada     = case when v_status = 'ditutup' and g.status <> 'ditutup' then now() when v_status is not null and v_status <> 'ditutup' then null else ditutup_pada end,
    diubah_oleh      = public.saya()
  where id = p_id;
  if v_status is not null and v_status <> g.status then
    perform public.catat_audit('ubah', 'grade_periods', p_id::text,
      'Periode penilaian ' || upper(g.jenis) || ' semester ' || g.semester || ': ' || g.status || ' → ' || v_status, jsonb_build_object('status', v_status));
  end if;
exception
  when check_violation then raise exception 'Hari efektif harus 1–200.';
end $$;

-- p: {id?, academic_year_id, jenis, tingkat, kelompok?, nama, singkatan?, kkm, sumber, mode_nilai?, aktif?, catatan?,
--     sumber_mapel?: [{subject_id, bobot}]}
create or replace function public.simpan_mapel_rapor(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid := nullif(p->>'id', '')::uuid; m report_subjects; v_ta uuid; v_jenis text; v_tingkat smallint; v_sumber text;
        v_src jsonb := coalesce(p->'sumber_mapel', '[]'::jsonb); v_sum numeric; v_n int;
begin
  if v_id is not null then
    select * into m from report_subjects where id = v_id;
    if m.id is null then raise exception 'Mapel rapor tidak ditemukan.'; end if;
  end if;
  v_ta := coalesce(m.academic_year_id, nullif(p->>'academic_year_id', '')::uuid, (select id from academic_years where aktif));
  v_jenis := coalesce(m.jenis, p->>'jenis'); v_tingkat := coalesce(m.tingkat, (p->>'tingkat')::smallint);
  perform public._cek_atur_penilaian(v_ta, v_jenis);
  v_sumber := coalesce(nullif(p->>'sumber', ''), m.sumber, 'mapel');
  if coalesce(trim(p->>'nama'), m.nama, '') = '' then raise exception 'Nama mapel di rapor wajib diisi.'; end if;
  -- Sumber nilai
  if v_sumber = 'mapel' then
    select count(*), coalesce(sum((x->>'bobot')::numeric), 0) into v_n, v_sum from jsonb_array_elements(v_src) x;
    if v_n > 1 and v_sum <> 100 then raise exception 'Bobot gabungan mapel sumber harus berjumlah 100%% (sekarang %).', v_sum; end if;
    if exists (select 1 from jsonb_array_elements(v_src) x where not exists (select 1 from subjects s where s.id = (x->>'subject_id')::uuid)) then
      raise exception 'Mapel sumber tidak ditemukan.';
    end if;
    select count(*) - count(distinct x->>'subject_id') into v_n from jsonb_array_elements(v_src) x;
    if v_n > 0 then raise exception 'Mapel sumber tidak boleh dipilih dua kali.'; end if;
  end if;

  if v_id is null then
    insert into report_subjects (academic_year_id, jenis, tingkat, urutan, kelompok, nama, singkatan, kkm, sumber, mode_nilai, aktif, catatan)
    values (v_ta, v_jenis, v_tingkat,
            coalesce((select max(urutan) + 1 from report_subjects where academic_year_id = v_ta and jenis = v_jenis and tingkat = v_tingkat), 1),
            nullif(trim(p->>'kelompok'), ''), trim(p->>'nama'), nullif(trim(p->>'singkatan'), ''),
            coalesce((p->>'kkm')::numeric, (select ambang_bawaan from report_settings where academic_year_id = v_ta and jenis = v_jenis), 75),
            v_sumber, nullif(p->>'mode_nilai', ''), coalesce((p->>'aktif')::boolean, true), nullif(trim(p->>'catatan'), ''))
    returning id into v_id;
  else
    update report_subjects set
      kelompok   = case when p ? 'kelompok' then nullif(trim(p->>'kelompok'), '') else kelompok end,
      nama       = coalesce(nullif(trim(p->>'nama'), ''), nama),
      singkatan  = case when p ? 'singkatan' then nullif(trim(p->>'singkatan'), '') else singkatan end,
      kkm        = coalesce((p->>'kkm')::numeric, kkm),
      sumber     = v_sumber,
      mode_nilai = case when p ? 'mode_nilai' then nullif(p->>'mode_nilai', '') else mode_nilai end,
      aktif      = coalesce((p->>'aktif')::boolean, aktif),
      catatan    = case when p ? 'catatan' then nullif(trim(p->>'catatan'), '') else catatan end
    where id = v_id;
  end if;
  if v_sumber <> 'mapel' then
    delete from report_subject_sources where report_subject_id = v_id;
  elsif p ? 'sumber_mapel' then
    delete from report_subject_sources where report_subject_id = v_id;
    insert into report_subject_sources (report_subject_id, subject_id, bobot)
    select v_id, (x->>'subject_id')::uuid, case when jsonb_array_length(v_src) = 1 then 100 else (x->>'bobot')::numeric end
      from jsonb_array_elements(v_src) x;
  end if;
  return v_id;
exception
  when unique_violation then raise exception 'Nama mapel rapor itu sudah ada di tingkat ini.';
  when check_violation then raise exception 'Isian mapel rapor di luar batas (KKM 0–100, bobot sumber 1–100).';
end $$;

create or replace function public.hapus_mapel_rapor(p_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare m report_subjects;
begin
  select * into m from report_subjects where id = p_id;
  if m.id is null then return; end if;
  perform public._cek_atur_penilaian(m.academic_year_id, m.jenis);
  delete from report_subjects where id = p_id;
end $$;

-- Urutan baru mapel rapor dalam satu jenis × tingkat (daftar id sesuai urutan tampil)
create or replace function public.urutkan_mapel_rapor(p_ids uuid[])
returns void language plpgsql volatile security definer set search_path = public as $$
declare m report_subjects; i int;
begin
  select * into m from report_subjects where id = p_ids[1];
  if m.id is null then return; end if;
  perform public._cek_atur_penilaian(m.academic_year_id, m.jenis);
  if exists (select 1 from report_subjects x where x.id = any(p_ids)
              and (x.academic_year_id, x.jenis, x.tingkat) is distinct from (m.academic_year_id, m.jenis, m.tingkat)) then
    raise exception 'Urutan hanya untuk mapel rapor dalam satu tingkat yang sama.';
  end if;
  for i in 1 .. cardinality(p_ids) loop
    update report_subjects set urutan = i where id = p_ids[i];
  end loop;
end $$;

-- Salin susunan mapel rapor dari satu tingkat ke tingkat lain (jenis sama). p_timpa = hapus susunan tujuan lebih dulu.
create or replace function public.salin_mapel_rapor(p_ta uuid, p_jenis text, p_dari smallint, p_ke smallint[], p_timpa boolean default false)
returns int language plpgsql volatile security definer set search_path = public as $$
declare t smallint; m record; v_baru uuid; v_n int := 0;
begin
  perform public._cek_atur_penilaian(p_ta, p_jenis);
  foreach t in array p_ke loop
    if t = p_dari then continue; end if;
    if (p_jenis = 'wustha' and t not between 7 and 9) or (p_jenis = 'sma' and t not between 10 and 12) then
      raise exception 'Tingkat % bukan tingkat rapor %.', t, upper(p_jenis);
    end if;
    if p_timpa then delete from report_subjects where academic_year_id = p_ta and jenis = p_jenis and tingkat = t; end if;
    for m in select * from report_subjects where academic_year_id = p_ta and jenis = p_jenis and tingkat = p_dari order by urutan loop
      insert into report_subjects (academic_year_id, jenis, tingkat, urutan, kelompok, nama, singkatan, kkm, sumber, mode_nilai, aktif, catatan)
      values (p_ta, p_jenis, t, m.urutan, m.kelompok, m.nama, m.singkatan, m.kkm, m.sumber, m.mode_nilai, m.aktif, m.catatan)
      on conflict (academic_year_id, jenis, tingkat, nama) do nothing
      returning id into v_baru;
      if v_baru is not null then
        insert into report_subject_sources (report_subject_id, subject_id, bobot)
        select v_baru, subject_id, bobot from report_subject_sources where report_subject_id = m.id;
        v_n := v_n + 1;
      end if;
    end loop;
  end loop;
  return v_n;
end $$;

-- Pengubah bank kalimat: pengatur umum; pimpinan tahfizh untuk catatan muhaffizh/kehadiran halaqah; pimpinan SMA/Wustha
-- untuk catatan wali kelas dan catatan kehadiran (jenisnya sendiri, atau yang berlaku untuk semua rapor).
create or replace function public._boleh_kalimat(p_kat text, p_jenis text)
returns boolean language sql stable security definer set search_path = public as $$
  select public.boleh_atur_penilaian(null)
      or case when p_kat in ('catatan_muhaffizh','kehadiran_halaqah') then public.boleh_atur_penilaian('tahfizh')
              when p_jenis is not null then public.boleh_atur_penilaian(p_jenis)
              else public.boleh_atur_penilaian('sma') or public.boleh_atur_penilaian('wustha') end
$$;

-- p: {id?, kategori, jenis?, bagian, kunci?, min_nilai?, teks, aktif?, urutan?}
create or replace function public.simpan_kalimat_rapor(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid := nullif(p->>'id', '')::uuid; v_kat text;
begin
  v_kat := coalesce(nullif(p->>'kategori', ''), (select kategori from report_phrases where id = v_id));
  if not public._boleh_kalimat(v_kat, coalesce(nullif(p->>'jenis', ''), (select jenis from report_phrases where id = v_id))) then
    raise exception 'Anda tidak berwenang mengubah bank kalimat rapor.' using errcode = '42501';
  end if;
  if coalesce(trim(p->>'teks'), '') = '' then raise exception 'Teks kalimat wajib diisi.'; end if;
  if v_id is null then
    insert into report_phrases (kategori, jenis, bagian, kunci, min_nilai, teks, aktif, urutan)
    values (v_kat, nullif(p->>'jenis', ''), p->>'bagian', nullif(trim(p->>'kunci'), ''), nullif(p->>'min_nilai', '')::numeric,
            trim(p->>'teks'), coalesce((p->>'aktif')::boolean, true), coalesce((p->>'urutan')::smallint, 99))
    returning id into v_id;
  else
    update report_phrases set jenis = case when p ? 'jenis' then nullif(p->>'jenis', '') else jenis end,
      bagian = coalesce(nullif(p->>'bagian', ''), bagian), kunci = case when p ? 'kunci' then nullif(trim(p->>'kunci'), '') else kunci end,
      min_nilai = case when p ? 'min_nilai' then nullif(p->>'min_nilai', '')::numeric else min_nilai end,
      teks = trim(p->>'teks'), aktif = coalesce((p->>'aktif')::boolean, aktif), urutan = coalesce((p->>'urutan')::smallint, urutan)
    where id = v_id;
    if not found then raise exception 'Kalimat tidak ditemukan.'; end if;
  end if;
  return v_id;
exception
  when check_violation then raise exception 'Isian kalimat tidak sah (kategori, bagian, atau teks terlalu pendek).';
end $$;

create or replace function public.hapus_kalimat_rapor(p_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v_kat text; v_jenis text;
begin
  select kategori, jenis into v_kat, v_jenis from report_phrases where id = p_id;
  if v_kat is null then return; end if;
  if not public._boleh_kalimat(v_kat, v_jenis) then
    raise exception 'Anda tidak berwenang mengubah bank kalimat rapor.' using errcode = '42501';
  end if;
  delete from report_phrases where id = p_id;
end $$;

-- ---------------------------------------------------------------------
-- 7. HAK EKSEKUSI DAN ISI AWAL TAHUN AJARAN YANG ADA
-- ---------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array['pimpinan_unit(text)','boleh_atur_penilaian(text)','boleh_kelola_nilai()','hak_penilaian()',
      'hari_efektif_otomatis(uuid,text,smallint)','pengaturan_penilaian(uuid)','simpan_ketentuan_rapor(uuid,text,jsonb)',
      'simpan_predikat_rapor(uuid,text,jsonb)','simpan_komponen_nilai(uuid,text,jsonb)','simpan_periode_nilai(uuid,jsonb)',
      'simpan_mapel_rapor(jsonb)','hapus_mapel_rapor(uuid)','urutkan_mapel_rapor(uuid[])','salin_mapel_rapor(uuid,text,smallint,smallint[],boolean)',
      'simpan_kalimat_rapor(jsonb)','hapus_kalimat_rapor(uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['siapkan_penilaian(uuid)','_isi_mapel_rapor(uuid,text,smallint,jsonb)','_cek_atur_penilaian(uuid,text)','_boleh_kalimat(text,text)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;

do $$
declare a record;
begin
  for a in select id from academic_years order by mulai loop perform public.siapkan_penilaian(a.id); end loop;
end $$;

-- ---------------------------------------------------------------------
-- 8. PEMERIKSAAN — hasil yang benar: 9 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select '1. Tabel penilaian (7) dengan RLS' as pemeriksaan,
       case when (select count(*) from pg_tables where schemaname = 'public' and rowsecurity and tablename in
         ('report_settings','report_predicates','grade_periods','grade_categories','report_subjects','report_subject_sources','report_phrases')) = 7
            then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Izin admin atur_penilaian dan kelola_nilai',
       case when (select count(*) from public.admin_capabilities where kode in ('atur_penilaian','kelola_nilai')) = 2 then 'Sesuai' else 'Periksa' end
union all
select '3. Ketentuan rapor SMA, Wustha, Tahfizh (TA aktif)',
       case when (select count(*) from public.report_settings r join public.academic_years a on a.id = r.academic_year_id and a.aktif) = 3
            then 'Sesuai' else 'Periksa' end
union all
select '4. Predikat 5 kelompok (TA aktif)',
       case when (select count(distinct kelompok) from public.report_predicates p join public.academic_years a on a.id = p.academic_year_id and a.aktif) = 5
            then 'Sesuai' else 'Periksa' end
union all
select '5. Periode penilaian 3 jenis × 2 semester',
       case when (select count(*) from public.grade_periods g join public.academic_years a on a.id = g.academic_year_id and a.aktif) = 6
            then 'Sesuai' else 'Periksa' end
union all
select '6. Mapel rapor isi awal (kelas 7–12)',
       case when (select count(distinct (jenis, tingkat)) from public.report_subjects m join public.academic_years a on a.id = m.academic_year_id and a.aktif) = 6
            then 'Sesuai' else 'Periksa (sudah diubah?)' end
union all
select '7. Bank kalimat catatan rapor terisi',
       case when (select count(*) from public.report_phrases) >= 40 then 'Sesuai' else 'Periksa' end
union all
select '8. Kolom biodata rapor santri',
       case when (select count(*) from information_schema.columns where table_schema = 'public' and table_name = 'v_santri'
                   and column_name in ('agama','status_keluarga','telepon_rumah','diterima_tingkat','alamat_ortu')) = 5
            then 'Sesuai' else 'Periksa' end
union all
select '9. Tertutup bagi pengunjung tanpa masuk',
       case when not has_function_privilege('anon', 'public.pengaturan_penilaian(uuid)', 'execute')
             and not has_function_privilege('anon', 'public.simpan_mapel_rapor(jsonb)', 'execute') then 'Sesuai' else 'Periksa' end;
