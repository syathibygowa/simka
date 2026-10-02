-- =====================================================================
-- SIMKA PRO · Fase 1 (Fondasi) · Migrasi 1: Skema tabel inti
-- Pondok Pesantren Tahfizhul Qur'an Imam Asy-Syathiby Wahdah Islamiyah Gowa
-- Urutan: 0100 skema → 0200 fungsi → 0300 RLS → 0400 isi awal
--         → 0500 penyimpanan → 0600 jadwal (pg_cron)
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;
create extension if not exists citext with schema extensions;

-- ---------------------------------------------------------------------
-- 1. ORGANISASI
-- ---------------------------------------------------------------------
create table public.org_units (
  id          uuid primary key default gen_random_uuid(),
  parent_id   uuid references public.org_units(id) on delete restrict,
  kode        text not null unique,
  nama        text not null,
  jenis       text not null check (jenis in ('pimpinan','bidang','unit')),
  prioritas   boolean not null default false,
  aktif       boolean not null default true,
  urutan      int not null default 0,
  created_at  timestamptz not null default now(),
  constraint org_units_bukan_induk_sendiri check (parent_id is null or parent_id <> id)
);
comment on table public.org_units is 'Pohon bidang dan unit pondok (Bagian 5 blueprint).';

create table public.functional_positions (          -- Jabatan fungsional (P1), boleh rangkap
  id            uuid primary key default gen_random_uuid(),
  kode          text not null unique,
  nama          text not null,
  jenis_sesi    text not null default 'rentang'
                check (jenis_sesi in ('rentang','sesi','shift','khusus')),
  tanpa_rangkap boolean not null default false,       -- medis dan security tidak rangkap tugas
  pengasuh      boolean not null default false,       -- wali kelas, muhaffizh, musyrif, pembina ekskul
  aktif         boolean not null default true,
  urutan        int not null default 0
);

create table public.structural_positions (          -- Jabatan struktural (P2), hanya satu per orang
  id               uuid primary key default gen_random_uuid(),
  kode             text not null unique,
  nama             text not null,
  tingkat          int not null default 50,          -- makin kecil makin tinggi (yayasan = 10)
  boleh_menyetujui boolean not null default false,   -- wakil kepala: false (kecuali Plt)
  aktif            boolean not null default true,
  urutan           int not null default 0
);

-- ---------------------------------------------------------------------
-- 2. PEGAWAI DAN AKUN
-- ---------------------------------------------------------------------
create table public.employees (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid unique references auth.users(id) on delete set null,
  username            extensions.citext unique
                      check (username is null or username ~ '^[a-zA-Z0-9._]{4,30}$'),
  email               extensions.citext unique,
  nama_lengkap        text not null check (length(trim(nama_lengkap)) >= 3),
  niy                 text unique,
  tempat_lahir        text,
  tanggal_lahir       date,
  jenis_kelamin       text check (jenis_kelamin in ('L','P')),
  tmt_tugas           date,
  status_kepegawaian  text check (status_kepegawaian in ('tetap','kontrak','honorer')),
  kategori_honorer    text check (kategori_honorer in ('lama','baru')),
  pendidikan_terakhir text check (pendidikan_terakhir in ('SD','SMP','SMA','S1','S1-LN','S2','S3')),
  status_keluarga     text check (status_keluarga in ('menikah','belum_menikah','cerai')),
  no_hp               text check (no_hp is null or no_hp ~ '^[0-9+]{9,16}$'),
  foto_id             uuid,                              -- → storage_objects (adapter)
  org_unit_id         uuid references public.org_units(id),
  level_muhaffizh     text check (level_muhaffizh in ('pemula','terampil','mahir')),
  status_keaktifan    text not null default 'aktif'
                      check (status_keaktifan in ('aktif','cuti_panjang','nonaktif','keluar')),
  status_akun         text not null default 'tanpa_akun'
                      check (status_akun in ('tanpa_akun','menunggu','aktif','ditolak','nonaktif')),
  peran               text not null default 'pegawai'
                      check (peran in ('superadmin','admin','pegawai')),
  wajib_ganti_sandi   boolean not null default false,
  catatan_verifikasi  text,
  diverifikasi_oleh   uuid references public.employees(id),
  diverifikasi_pada   timestamptz,
  tema                text not null default 'sistem' check (tema in ('terang','gelap','sistem')),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
-- Superadmin hanya satu akun
create unique index employees_superadmin_tunggal on public.employees ((peran)) where peran = 'superadmin';
create index employees_unit_idx on public.employees (org_unit_id);
create index employees_status_idx on public.employees (status_akun, status_keaktifan);

create table public.employee_functions (
  employee_id            uuid not null references public.employees(id) on delete cascade,
  functional_position_id uuid not null references public.functional_positions(id) on delete restrict,
  created_at             timestamptz not null default now(),
  primary key (employee_id, functional_position_id)
);

create table public.employee_structurals (             -- satu jabatan struktural per pegawai
  employee_id            uuid primary key references public.employees(id) on delete cascade,
  structural_position_id uuid not null references public.structural_positions(id) on delete restrict,
  org_unit_id            uuid references public.org_units(id),   -- cabang yang dipimpin
  tmt                    date,
  created_at             timestamptz not null default now()
);

create table public.employment_history (
  id              bigint generated always as identity primary key,
  employee_id     uuid not null references public.employees(id) on delete cascade,
  jenis           text not null,
  nilai_lama      text,
  nilai_baru      text,
  tanggal_berlaku date not null default ((now() at time zone 'Asia/Makassar')::date),
  alasan          text,
  dicatat_oleh    uuid references public.employees(id),
  created_at      timestamptz not null default now()
);
create index employment_history_emp_idx on public.employment_history (employee_id, tanggal_berlaku desc);

create table public.password_reset_tokens (
  id           uuid primary key default gen_random_uuid(),
  employee_id  uuid not null references public.employees(id) on delete cascade,
  token_hash   text not null unique,
  kedaluwarsa  timestamptz not null,
  dipakai_pada timestamptz,
  created_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 3. HAK AKSES FITUR (Bagian 4)
-- ---------------------------------------------------------------------
create table public.features (
  kode     text primary key,
  nama     text not null,
  kelompok text not null check (kelompok in ('Kepegawaian','Santri','Layanan','Administrasi','Sistem')),
  fase     int not null default 1,
  urutan   int not null default 0
);

-- tingkat: 1 = lihat, 2 = input/ubah, 3 = kelola
create table public.feature_grants (
  id           uuid primary key default gen_random_uuid(),
  feature_kode text not null references public.features(kode) on delete cascade,
  sasaran      text not null check (sasaran in ('fungsional','struktural','bidang','individu')),
  sasaran_id   uuid not null,
  tingkat      smallint not null check (tingkat between 1 and 3),
  mode         text not null default 'tambah' check (mode in ('tambah','cabut')),
  catatan      text,
  dibuat_oleh  uuid references public.employees(id),
  created_at   timestamptz not null default now(),
  unique (feature_kode, sasaran, sasaran_id)
);

create table public.admin_capabilities (               -- izin admin yang dapat dicentang superadmin
  kode   text primary key,
  nama   text not null,
  urutan int not null default 0
);

create table public.admin_permissions (
  employee_id uuid not null references public.employees(id) on delete cascade,
  kode        text not null references public.admin_capabilities(kode) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (employee_id, kode)
);

-- ---------------------------------------------------------------------
-- 4. PENGATURAN LEMBAGA, KOP, PENANDA TANGAN (Bagian 34)
-- ---------------------------------------------------------------------
create table public.institution_settings (
  kunci       text primary key,           -- identitas, kalender, integrasi, hijriah
  nilai       jsonb not null default '{}'::jsonb,
  publik      boolean not null default false,   -- boleh dibaca tanpa login (halaman masuk)
  updated_at  timestamptz not null default now(),
  updated_by  uuid references public.employees(id)
);

create table public.letterheads (
  id             uuid primary key default gen_random_uuid(),
  kode           text not null unique,             -- pondok, wustha, sma, yayasan
  nama           text not null,
  kode_unit      text not null,                    -- dipakai pada penomoran surat
  bentuk         text not null default 'gambar' check (bentuk in ('gambar','susun')),
  gambar_url     text,                             -- kop utuh (bentuk gambar)
  logo_kiri_url  text,
  logo_kanan_url text,
  baris          jsonb not null default '[]'::jsonb,  -- [{teks, tebal, ukuran}]
  pita_teks      text,
  pita_warna     text default '#F8E02F',
  aktif          boolean not null default true,
  urutan         int not null default 0,
  updated_at     timestamptz not null default now()
);

create table public.signatories (
  id               uuid primary key default gen_random_uuid(),
  jabatan_tertulis text not null,
  nama             text not null,
  niy              text,
  employee_id      uuid references public.employees(id) on delete set null,
  aktif            boolean not null default true,
  urutan           int not null default 0
);

create table public.signer_rules (
  jenis_dokumen   text primary key,
  nama_dokumen    text not null,
  kiri            text,      -- uuid penanda tangan atau peran dinamis: atasan_terakhir, pemohon, pencetak, ...
  kanan           text,
  mode            text not null default 'elektronik' check (mode in ('elektronik','basah')),
  kop_kode        text references public.letterheads(kode) on update cascade,
  urutan          int not null default 0
);

-- ---------------------------------------------------------------------
-- 5. KALENDER
-- ---------------------------------------------------------------------
create table public.academic_years (
  id        uuid primary key default gen_random_uuid(),
  nama      text not null unique check (nama ~ '^[0-9]{4}/[0-9]{4}$'),
  mulai     date not null,
  selesai   date not null,
  semester  smallint not null default 1 check (semester in (1,2)),
  aktif     boolean not null default false,
  terkunci  boolean not null default false,
  check (selesai > mulai)
);
create unique index academic_years_satu_aktif on public.academic_years ((aktif)) where aktif;

create table public.holiday_calendars (               -- libur pekanan per jenis tugas
  jenis_tugas text primary key,
  nama        text not null,
  hari_libur  smallint[] not null default '{}',      -- 0 = Ahad ... 6 = Sabtu
  catatan     text
);

create table public.holidays (
  id            uuid primary key default gen_random_uuid(),
  tanggal_mulai date not null,
  tanggal_akhir date not null,
  nama          text not null,
  jenis         text not null default 'libur_pondok'
                check (jenis in ('libur_bulanan','libur_pondok','libur_sekolah','libur_nasional','tanpa_sesi')),
  berlaku_untuk text[] not null default '{semua}',
  dibuat_oleh   uuid references public.employees(id),
  created_at    timestamptz not null default now(),
  check (tanggal_akhir >= tanggal_mulai)
);
create index holidays_tanggal_idx on public.holidays (tanggal_mulai, tanggal_akhir);

-- ---------------------------------------------------------------------
-- 6. PENOMORAN DOKUMEN (Bagian 32)
-- ---------------------------------------------------------------------
create table public.letter_subject_codes (
  kode       text primary key check (kode ~ '^[A-Z]{2,4}$'),
  arti       text not null,
  keterangan text,
  urutan     int not null default 0
);

create table public.doc_number_formats (
  kode       text primary key,             -- surat, sk, pengajuan, slip, kuitansi, tagihan
  nama       text not null,
  pola       text not null,                -- '{DK}.{URUT3}/{PERIHAL}/{UNIT}/{BLN_H_ROMAWI}/{THN_H}'
  grup_urut  text not null,                -- format dengan grup sama berbagi urutan
  reset      text not null default 'tahun_hijriah'
             check (reset in ('tahun_hijriah','tahun_masehi','bulan_masehi','tidak')),
  aktif      boolean not null default true,
  updated_at timestamptz not null default now()
);

create table public.doc_counters (
  grup_urut  text not null,
  periode    text not null,
  nilai      int not null default 0,
  updated_at timestamptz not null default now(),
  primary key (grup_urut, periode)
);

create table public.doc_numbers_issued (
  id          bigint generated always as identity primary key,
  format_kode text not null references public.doc_number_formats(kode),
  nomor       text not null,
  urut        int not null,
  periode     text not null,
  tanggal     date not null,
  perihal     text,
  dibuat_oleh uuid references public.employees(id),
  created_at  timestamptz not null default now(),
  unique (format_kode, nomor)
);

-- ---------------------------------------------------------------------
-- 7. PENYIMPANAN BERKAS (adapter, Bagian 39 dan 41)
-- ---------------------------------------------------------------------
create table public.storage_objects (
  id             uuid primary key default gen_random_uuid(),
  penyedia       text not null default 'supabase' check (penyedia in ('supabase','gdrive','s3','lokal')),
  bucket         text,
  kunci          text not null,                -- path berkas atau ID berkas Drive
  nama_berkas    text not null,
  mime           text,
  ukuran         int,
  kategori       text not null,
  folder_tujuan  text,                         -- contoh 'SIMKA PRO/Presensi/2026/10'
  status         text not null default 'tersimpan'
                 check (status in ('antri','tersimpan','gagal','dihapus')),
  percobaan      int not null default 0,
  galat          text,
  hapus_setelah  date,
  pemilik_id     uuid references public.employees(id) on delete set null,
  publik         boolean not null default false,
  created_at     timestamptz not null default now(),
  dipindah_pada  timestamptz
);
create index storage_objects_antri_idx on public.storage_objects (created_at) where status = 'antri';
create index storage_objects_retensi_idx on public.storage_objects (hapus_setelah) where status = 'tersimpan';
alter table public.employees
  add constraint employees_foto_fk foreign key (foto_id) references public.storage_objects(id) on delete set null;

create view public.file_queue with (security_invoker = true) as
  select * from public.storage_objects where status = 'antri' order by created_at;

-- ---------------------------------------------------------------------
-- 8. NOTIFIKASI, AUDIT, HEARTBEAT
-- ---------------------------------------------------------------------
create table public.notifications (
  id          uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees(id) on delete cascade,
  judul       text not null,
  isi         text,
  tautan      text,
  ikon        text default 'Bell',
  warna       text default 'merah',
  dibaca_pada timestamptz,
  created_at  timestamptz not null default now()
);
create index notifications_emp_idx on public.notifications (employee_id, created_at desc);
create index notifications_belum_idx on public.notifications (employee_id) where dibaca_pada is null;

create table public.audit_logs (
  id          bigint generated always as identity primary key,
  employee_id uuid references public.employees(id) on delete set null,
  aksi        text not null,
  tabel       text,
  data_id     text,
  ringkasan   text,
  data        jsonb,
  created_at  timestamptz not null default now()
);
create index audit_logs_waktu_idx on public.audit_logs (created_at desc);
create index audit_logs_emp_idx on public.audit_logs (employee_id, created_at desc);

create table public.heartbeat (
  id         bigint generated always as identity primary key,
  sumber     text not null,
  catatan    text,
  created_at timestamptz not null default now()
);
