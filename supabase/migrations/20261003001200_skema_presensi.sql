-- SIMKA PRO | supabase/migrations/20261003001200_skema_presensi.sql | v1.0 | Fase 2 – Tahap 1 Skema presensi | 03/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 2 (Presensi pegawai) · Migrasi 12: Tabel presensi + RLS
-- Urutan Fase 2: 1200 skema → 1300 fungsi → 1400 isi awal
-- Prinsip (Bagian 9 dan 42 blueprint):
--   * tabel presensi TIDAK dapat ditulis langsung dari aplikasi;
--     semua penulisan lewat fungsi security definer / Edge Function;
--   * data lama tidak pernah dihapus, perubahan dicatat di riwayat status.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TITIK GPS (Bagian 9: banyak titik, nama + koordinat + radius)
-- ---------------------------------------------------------------------
create table public.gps_points (
  id          uuid primary key default gen_random_uuid(),
  nama        text not null check (length(trim(nama)) between 2 and 60),
  lat         double precision not null check (lat between -90 and 90),
  lng         double precision not null check (lng between -180 and 180),
  radius_m    int not null default 100 check (radius_m between 10 and 2000),
  aktif       boolean not null default true,
  urutan      int not null default 0,
  catatan     text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
comment on table public.gps_points is 'Titik area pondok. Presensi sah di dalam radius titik mana pun.';

-- ---------------------------------------------------------------------
-- 2. POLA TUGAS DAN SESI
-- ---------------------------------------------------------------------
create table public.task_patterns (
  id              uuid primary key default gen_random_uuid(),
  kode            text not null unique check (kode ~ '^[A-Z0-9_]{2,40}$'),
  nama            text not null,
  jenis           text not null check (jenis in ('rentang','sesi','shift','khusus')),
  kalender        text references public.holiday_calendars(jenis_tugas) on update cascade on delete set null,
  pola_struktural boolean not null default false,   -- dipakai pegawai struktural tanpa pola fungsional
  employee_id     uuid references public.employees(id) on delete cascade,  -- terisi = pola pribadi satu pegawai
  warna           text not null default 'presensi',
  aktif           boolean not null default true,
  urutan          int not null default 0,
  catatan         text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create unique index task_patterns_satu_struktural on public.task_patterns ((pola_struktural)) where pola_struktural;
comment on column public.task_patterns.jenis is
  'rentang = datang dan pulang; sesi = sekali presensi per sesi; shift = hanya hari yang dijadwalkan di shift_rosters; khusus = jadwal pribadi.';

-- Jabatan fungsional menunjuk pola bawaannya (banyak jabatan boleh memakai satu pola)
alter table public.functional_positions
  add column if not exists pola_id uuid references public.task_patterns(id) on delete set null;

create table public.pattern_sessions (
  id                           uuid primary key default gen_random_uuid(),
  pattern_id                   uuid not null references public.task_patterns(id) on delete cascade,
  kode                         text not null check (kode ~ '^[A-Z0-9_]{1,30}$'),
  nama                         text not null,
  hari                         smallint[] not null default '{0,1,2,3,4,5,6}'
                               check (cardinality(hari) > 0 and hari <@ '{0,1,2,3,4,5,6}'::smallint[]),  -- 0 = Ahad
  jam_mulai                    time not null,
  jam_selesai                  time not null,     -- lebih kecil dari jam mulai = lewat tengah malam
  buka_menit                   int not null default 30  check (buka_menit between 0 and 240),
  toleransi_terlambat_menit    int not null default 10  check (toleransi_terlambat_menit between 0 and 240),
  tutup_menit                  int not null default 120 check (tutup_menit between 1 and 720),
  wajib_pulang                 boolean not null default false,
  pulang_buka_menit            int not null default 120 check (pulang_buka_menit between 0 and 720),
  toleransi_cepat_pulang_menit int not null default 10  check (toleransi_cepat_pulang_menit between 0 and 240),
  batas_pulang_menit           int not null default 180 check (batas_pulang_menit between 0 and 720),
  opsional                     boolean not null default false,   -- tidak dihitung sesi wajib (misalnya istirahat)
  label_datang                 text not null default 'Datang',
  label_pulang                 text not null default 'Pulang',
  aktif                        boolean not null default true,
  urutan                       int not null default 0,
  created_at                   timestamptz not null default now(),
  updated_at                   timestamptz not null default now(),
  check (jam_selesai <> jam_mulai),
  check (tutup_menit >= toleransi_terlambat_menit)
);
create index pattern_sessions_pola_idx on public.pattern_sessions (pattern_id);
comment on column public.pattern_sessions.buka_menit is 'Presensi dapat dilakukan sejak X menit sebelum jam mulai.';
comment on column public.pattern_sessions.tutup_menit is 'Batas presensi datang, X menit setelah jam mulai. Lewat batas = sesi ditutup.';
comment on column public.pattern_sessions.pulang_buka_menit is 'Presensi pulang dapat dilakukan sejak X menit sebelum jam selesai.';
comment on column public.pattern_sessions.batas_pulang_menit is 'Presensi pulang masih diterima sampai X menit setelah jam selesai.';

-- ---------------------------------------------------------------------
-- 3. JADWAL PEGAWAI DAN SHIFT
-- ---------------------------------------------------------------------
create table public.employee_schedules (
  id            uuid primary key default gen_random_uuid(),
  employee_id   uuid not null references public.employees(id) on delete cascade,
  pattern_id    uuid not null references public.task_patterns(id) on delete cascade,
  sumber        text not null default 'manual' check (sumber in ('jabatan','struktural','manual')),
  sesi_dipegang uuid[],                 -- kosong = semua sesi pola; terisi = hanya sesi tertentu
  aktif         boolean not null default true,
  catatan       text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (employee_id, pattern_id)
);
create index employee_schedules_emp_idx on public.employee_schedules (employee_id) where aktif;

create table public.shift_rosters (
  id          uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees(id) on delete cascade,
  tanggal     date not null,
  session_id  uuid not null references public.pattern_sessions(id) on delete cascade,
  catatan     text,
  dibuat_oleh uuid references public.employees(id) on delete set null,
  created_at  timestamptz not null default now(),
  unique (employee_id, tanggal, session_id)
);
create index shift_rosters_tanggal_idx on public.shift_rosters (tanggal);

-- ---------------------------------------------------------------------
-- 4. PRESENSI
-- ---------------------------------------------------------------------
-- Cek lokasi sebelum selfie (waktu, titik, dan jarak dihitung server;
-- dipakai untuk watermark). Berlaku singkat dan hanya sekali pakai.
create table public.attendance_checks (
  id           uuid primary key default gen_random_uuid(),
  employee_id  uuid not null references public.employees(id) on delete cascade,
  waktu        timestamptz not null default now(),
  lat          double precision not null,
  lng          double precision not null,
  akurasi_m    real,
  titik_id     uuid references public.gps_points(id) on delete set null,
  titik_nama   text,
  jarak_m      int,
  di_area      boolean not null,
  dipakai_pada timestamptz
);
create index attendance_checks_waktu_idx on public.attendance_checks (waktu);

-- Setiap ketukan presensi (satu ketukan dapat memenuhi beberapa sesi)
create table public.attendance_events (
  id             uuid primary key default gen_random_uuid(),
  employee_id    uuid not null references public.employees(id) on delete restrict,
  waktu          timestamptz not null default now(),
  tanggal        date not null,
  cek_id         uuid references public.attendance_checks(id) on delete set null,
  lat            double precision not null,
  lng            double precision not null,
  akurasi_m      real,
  titik_id       uuid references public.gps_points(id) on delete set null,
  titik_nama     text,
  jarak_m        int,
  di_area        boolean not null,
  pilihan        text check (pilihan in ('hadir','izin','sakit')),   -- hanya di luar area
  alasan         text,
  selfie_id      uuid references public.storage_objects(id) on delete set null,
  selfie_hash    text,
  perangkat_id   text,
  perangkat_info text,
  alamat_ip      text,
  permintaan_id  text not null,           -- pencegah data dobel saat tombol ditekan ulang
  hasil          jsonb not null default '[]'::jsonb,
  created_at     timestamptz not null default now(),
  unique (employee_id, permintaan_id)
);
create index attendance_events_emp_idx on public.attendance_events (employee_id, waktu desc);
create index attendance_events_hash_idx on public.attendance_events (selfie_hash) where selfie_hash is not null;
create index attendance_events_perangkat_idx on public.attendance_events (perangkat_id) where perangkat_id is not null;

-- Satu baris per pegawai per sesi per tanggal
create table public.attendances (
  id                  uuid primary key default gen_random_uuid(),
  employee_id         uuid not null references public.employees(id) on delete restrict,
  tanggal             date not null,                  -- tanggal sesi dimulai (WITA)
  session_id          uuid not null references public.pattern_sessions(id) on delete restrict,
  pattern_id          uuid not null references public.task_patterns(id) on delete restrict,
  nama_pola           text not null,                  -- salinan saat dicatat
  nama_sesi           text not null,
  jadwal_mulai        timestamptz not null,
  jadwal_selesai      timestamptz not null,
  wajib_pulang        boolean not null default false,
  opsional            boolean not null default false,
  status              text not null check (status in ('hadir','terlambat','dinas_luar','menunggu_verval',
                                                      'izin','sakit','cuti','tanpa_keterangan')),
  usulan_status       text check (usulan_status in ('hadir','izin','sakit')),
  datang_pada         timestamptz,
  datang_event_id     uuid references public.attendance_events(id) on delete set null,
  terlambat_menit     int not null default 0,
  status_pulang       text check (status_pulang in ('belum','tepat','cepat','tidak_presensi','menunggu_verval')),
  pulang_pada         timestamptz,
  pulang_event_id     uuid references public.attendance_events(id) on delete set null,
  cepat_pulang_menit  int not null default 0,
  sumber              text not null check (sumber in ('gps','luar_area','verval','pengajuan','penutupan','koreksi','izin_sesi')),
  keterangan          text,
  diverval_oleh       uuid references public.employees(id) on delete set null,
  diverval_pada       timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  unique (employee_id, session_id, tanggal)
);
create index attendances_tanggal_idx on public.attendances (tanggal);
create index attendances_emp_tanggal_idx on public.attendances (employee_id, tanggal);
create index attendances_verval_idx on public.attendances (created_at)
  where status = 'menunggu_verval' or status_pulang = 'menunggu_verval';

-- Riwayat status: siapa, kapan, dari apa ke apa, dan alasannya (diisi pemicu)
create table public.attendance_status_history (
  id             bigint generated always as identity primary key,
  attendance_id  uuid not null references public.attendances(id) on delete cascade,
  jenis          text not null default 'sistem',   -- presensi, penutupan, verval, koreksi, superadmin, pengajuan
  dari_status    text,
  ke_status      text,
  dari_pulang    text,
  ke_pulang      text,
  alasan         text,
  oleh           uuid references public.employees(id) on delete set null,
  created_at     timestamptz not null default now()
);
create index attendance_status_history_att_idx on public.attendance_status_history (attendance_id, created_at);

-- Koreksi data final oleh admin → disetujui superadmin
create table public.correction_requests (
  id            uuid primary key default gen_random_uuid(),
  attendance_id uuid not null references public.attendances(id) on delete cascade,
  diajukan_oleh uuid not null references public.employees(id) on delete cascade,
  status_baru   text not null check (status_baru in ('hadir','terlambat','dinas_luar','izin','sakit','cuti','tanpa_keterangan')),
  pulang_baru   text check (pulang_baru in ('tepat','cepat','tidak_presensi')),
  alasan        text not null check (length(trim(alasan)) >= 5),
  status        text not null default 'menunggu' check (status in ('menunggu','disetujui','ditolak')),
  diputus_oleh  uuid references public.employees(id) on delete set null,
  diputus_pada  timestamptz,
  catatan       text,
  created_at    timestamptz not null default now()
);
create index correction_requests_menunggu_idx on public.correction_requests (created_at) where status = 'menunggu';

-- Penanda kecurigaan (Bagian 9: panel deteksi)
create table public.suspicion_flags (
  id           uuid primary key default gen_random_uuid(),
  employee_id  uuid not null references public.employees(id) on delete cascade,
  event_id     uuid references public.attendance_events(id) on delete cascade,
  jenis        text not null check (jenis in ('koordinat_identik','akurasi_tidak_wajar','perangkat_bersama','selfie_identik')),
  rincian      jsonb not null default '{}'::jsonb,
  status       text not null default 'baru' check (status in ('baru','wajar','pelanggaran')),
  ditinjau_oleh uuid references public.employees(id) on delete set null,
  ditinjau_pada timestamptz,
  catatan      text,
  created_at   timestamptz not null default now()
);
create index suspicion_flags_baru_idx on public.suspicion_flags (created_at desc) where status = 'baru';

-- ---------------------------------------------------------------------
-- 5. updated_at dan audit pengaturan
-- ---------------------------------------------------------------------
create trigger aa_updated before update on public.gps_points         for each row execute function public.tg_updated_at();
create trigger aa_updated before update on public.task_patterns      for each row execute function public.tg_updated_at();
create trigger aa_updated before update on public.pattern_sessions   for each row execute function public.tg_updated_at();
create trigger aa_updated before update on public.employee_schedules for each row execute function public.tg_updated_at();
create trigger aa_updated before update on public.attendances        for each row execute function public.tg_updated_at();

do $$
declare t text;
begin
  foreach t in array array['gps_points','task_patterns','pattern_sessions','employee_schedules','shift_rosters']
  loop
    execute format('create trigger zz_audit after insert or update or delete on public.%I
                    for each row execute function public.tg_audit()', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 6. ROW LEVEL SECURITY
-- ---------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['gps_points','task_patterns','pattern_sessions','employee_schedules','shift_rosters',
    'attendance_checks','attendance_events','attendances','attendance_status_history',
    'correction_requests','suspicion_flags']
  loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- Izin admin baru: mengatur pola sesi, jadwal, dan shift
insert into public.admin_capabilities (kode, nama, urutan) values
  ('atur_presensi', 'Mengatur pola sesi, jadwal pegawai, dan shift presensi', 8)
on conflict (kode) do update set nama = excluded.nama;
update public.admin_capabilities set nama = 'Verval presensi di luar area dan permintaan koreksi'
 where kode = 'verval_presensi';

-- Titik GPS: dibaca semua pengguna masuk, dikelola superadmin
create policy baca on public.gps_points for select to authenticated using (true);
create policy kelola_superadmin on public.gps_points for all to authenticated
  using (public.is_superadmin()) with check (public.is_superadmin());

-- Pola dan sesi: dibaca semua, dikelola admin ber-izin atur_presensi
create policy baca on public.task_patterns for select to authenticated
  using (employee_id is null or employee_id = public.saya() or public.is_admin());
create policy kelola on public.task_patterns for all to authenticated
  using (public.admin_boleh('atur_presensi')) with check (public.admin_boleh('atur_presensi'));

create policy baca on public.pattern_sessions for select to authenticated using (true);
create policy kelola on public.pattern_sessions for all to authenticated
  using (public.admin_boleh('atur_presensi')) with check (public.admin_boleh('atur_presensi'));

-- Jadwal pegawai
create policy baca on public.employee_schedules for select to authenticated
  using (employee_id = public.saya() or public.is_admin() or public.pimpinan_dari(employee_id));
create policy kelola on public.employee_schedules for all to authenticated
  using (public.admin_boleh('atur_presensi')) with check (public.admin_boleh('atur_presensi'));

-- Shift: semua pengguna masuk dapat melihat siapa bertugas (rekan shift)
create policy baca on public.shift_rosters for select to authenticated using (true);
create policy kelola on public.shift_rosters for all to authenticated
  using (public.admin_boleh('atur_presensi')) with check (public.admin_boleh('atur_presensi'));

-- Data presensi: HANYA BACA dari aplikasi
create policy baca on public.attendance_events for select to authenticated
  using (employee_id = public.saya() or public.is_admin() or public.pimpinan_dari(employee_id));
create policy baca on public.attendances for select to authenticated
  using (employee_id = public.saya() or public.is_admin() or public.pimpinan_dari(employee_id));
create policy baca on public.attendance_status_history for select to authenticated
  using (exists (select 1 from public.attendances a where a.id = attendance_id
                  and (a.employee_id = public.saya() or public.is_admin() or public.pimpinan_dari(a.employee_id))));
create policy baca on public.correction_requests for select to authenticated
  using (public.admin_boleh('verval_presensi'));
create policy baca on public.suspicion_flags for select to authenticated
  using (public.admin_boleh('verval_presensi'));
-- attendance_checks: tanpa kebijakan = tertutup sepenuhnya untuk klien.

-- Realtime untuk kartu statistik langsung
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.attendances;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 4 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select 'Tabel presensi (11)' as pemeriksaan,
       case when count(*) = 11 then 'Sesuai' else 'Periksa: ' || count(*) end as hasil
  from information_schema.tables
 where table_schema = 'public' and table_name in ('gps_points','task_patterns','pattern_sessions',
   'employee_schedules','shift_rosters','attendance_checks','attendance_events','attendances',
   'attendance_status_history','correction_requests','suspicion_flags')
union all
select 'RLS aktif di semua tabel presensi',
       case when count(*) = 11 then 'Sesuai' else 'Periksa: ' || count(*) end
  from pg_tables where schemaname = 'public' and rowsecurity and tablename in ('gps_points','task_patterns',
   'pattern_sessions','employee_schedules','shift_rosters','attendance_checks','attendance_events','attendances',
   'attendance_status_history','correction_requests','suspicion_flags')
union all
select 'Kolom pola_id di jabatan fungsional',
       case when exists (select 1 from information_schema.columns where table_schema = 'public'
                         and table_name = 'functional_positions' and column_name = 'pola_id') then 'Sesuai' else 'Periksa' end
union all
select 'Izin admin atur_presensi',
       case when exists (select 1 from public.admin_capabilities where kode = 'atur_presensi') then 'Sesuai' else 'Periksa' end;
