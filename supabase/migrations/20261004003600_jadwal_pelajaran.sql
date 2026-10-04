-- SIMKA PRO | supabase/migrations/20261004003600_jadwal_pelajaran.sql | v1.0 | Fase 4 – Tahap 5 Jadwal pelajaran dan jurnal mengajar | 04/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 4 · Migrasi 36: Jadwal pelajaran dan jurnal mengajar (Blueprint Bagian 19)
--   * subjects              : mata pelajaran (umum dan pondok) per jenjang — isi awal dapat diubah
--   * lesson_periods        : jam pelajaran per jenjang dan jenis hari (reguler / Jumat), termasuk istirahat.
--                             Isi awal: jam ke-1 08.00, JP Wustha 40 menit, SMA 45 menit (keputusan pemilik proyek)
--   * teaching_assignments  : penugasan mengajar (guru, mapel, kelas/rombel, JP per pekan) per tahun ajaran
--   * class_schedules       : jadwal pelajaran per kelas (hari × jam ke-n); bentrok kelas dan bentrok guru ditolak
--   * teaching_plans        : rencana materi per penugasan → jurnal "satu ketukan" bila sesuai rencana
--   * teaching_journals     : jurnal mengajar per JP (terlaksana / tidak + materi); batas H+1 seperti Jurnal Harian
--   * Jam Guru Mapel di Ekuivalensi Beban Kerja terisi otomatis dari jadwal (1 JP = 1 jam)
-- Jalankan SETELAH migrasi 3500. Aman dijalankan ulang.
-- =====================================================================

insert into public.admin_capabilities (kode, nama, urutan) values
  ('atur_jadwal', 'Mengatur mata pelajaran, jam pelajaran, penugasan mengajar, dan jadwal pelajaran (Fase 4)', 18)
on conflict (kode) do nothing;
insert into public.institution_settings (kunci, nilai) values
  ('jadwal_pelajaran', '{"hari": [1, 2, 3, 4, 5, 6], "hari_jumat": 5, "jam_per_jp": 1}')
on conflict (kunci) do nothing;
insert into public.feature_grants (feature_kode, sasaran, sasaran_id, tingkat, catatan)
select 'jadwal_mengajar', 'struktural', sp.id, 1, 'bawaan Fase 4'
from public.structural_positions sp
where sp.kode in ('YAYASAN','DIREKTUR','WAKIL_DIREKTUR','KEPALA_BIDANG','WAKIL_KEPALA_BIDANG','WAKIL_KEPALA_SEKOLAH')
on conflict (feature_kode, sasaran, sasaran_id) do nothing;

-- ---------------------------------------------------------------------
-- 1. MATA PELAJARAN DAN JAM PELAJARAN
-- ---------------------------------------------------------------------
create table if not exists public.subjects (
  id        uuid primary key default gen_random_uuid(),
  kode      text not null unique constraint subjects_kode_check check (kode ~ '^[A-Z0-9_]{1,20}$'),
  nama      text not null,
  jenjang   text not null default 'semua' check (jenjang in ('wustha','sma','semua')),
  kelompok  text not null default 'umum' check (kelompok in ('umum','pondok','muatan_lokal')),
  aktif     boolean not null default true,
  urutan    int not null default 0,
  constraint subjects_nama_unik unique (nama, jenjang)
);
insert into public.subjects (kode, nama, jenjang, kelompok, urutan) values
  ('PAI', 'Pendidikan Agama Islam', 'semua', 'umum', 1), ('PKN', 'Pendidikan Pancasila', 'semua', 'umum', 2),
  ('BIND', 'Bahasa Indonesia', 'semua', 'umum', 3), ('MTK', 'Matematika', 'semua', 'umum', 4),
  ('IPA', 'Ilmu Pengetahuan Alam', 'wustha', 'umum', 5), ('IPS', 'Ilmu Pengetahuan Sosial', 'wustha', 'umum', 6),
  ('BING', 'Bahasa Inggris', 'semua', 'umum', 7), ('FIS', 'Fisika', 'sma', 'umum', 8), ('KIM', 'Kimia', 'sma', 'umum', 9),
  ('BIO', 'Biologi', 'sma', 'umum', 10), ('SEJ', 'Sejarah', 'sma', 'umum', 11), ('EKO', 'Ekonomi', 'sma', 'umum', 12),
  ('GEO', 'Geografi', 'sma', 'umum', 13), ('SOS', 'Sosiologi', 'sma', 'umum', 14), ('INF', 'Informatika', 'semua', 'umum', 15),
  ('PJOK', 'Pendidikan Jasmani', 'semua', 'umum', 16), ('SBDP', 'Seni Budaya', 'semua', 'umum', 17),
  ('BARAB', 'Bahasa Arab', 'semua', 'pondok', 20), ('FIQIH', 'Fiqih', 'semua', 'pondok', 21), ('AQIDAH', 'Aqidah', 'semua', 'pondok', 22),
  ('HADITS', 'Hadits', 'semua', 'pondok', 23), ('TAFSIR', 'Tafsir', 'semua', 'pondok', 24), ('SIRAH', 'Sirah Nabawiyah', 'semua', 'pondok', 25),
  ('TAHSIN', 'Tahsin dan Tajwid', 'semua', 'pondok', 26), ('NAHWU', 'Nahwu Sharaf', 'semua', 'pondok', 27)
on conflict (kode) do nothing;

create table if not exists public.lesson_periods (
  id          uuid primary key default gen_random_uuid(),
  jenjang     text not null check (jenjang in ('wustha','sma')),
  jenis_hari  text not null check (jenis_hari in ('reguler','jumat')),
  urutan      smallint not null check (urutan between 1 and 20),
  jenis       text not null default 'jp' check (jenis in ('jp','istirahat')),
  nama        text not null,
  jam_mulai   time not null,
  jam_selesai time not null,
  constraint lesson_periods_jam check (jam_selesai > jam_mulai),
  unique (jenjang, jenis_hari, urutan)
);
insert into public.lesson_periods (jenjang, jenis_hari, urutan, jenis, nama, jam_mulai, jam_selesai)
select v.* from (values
  ('wustha','reguler',1,'jp','Jam ke-1','08:00'::time,'08:40'::time), ('wustha','reguler',2,'jp','Jam ke-2','08:40','09:20'),
  ('wustha','reguler',3,'jp','Jam ke-3','09:20','10:00'), ('wustha','reguler',4,'istirahat','Istirahat','10:00','10:20'),
  ('wustha','reguler',5,'jp','Jam ke-4','10:20','11:00'), ('wustha','reguler',6,'jp','Jam ke-5','11:00','11:40'),
  ('wustha','reguler',7,'jp','Jam ke-6','11:40','12:20'), ('wustha','reguler',8,'istirahat','Istirahat dan shalat Zuhur','12:20','13:00'),
  ('wustha','reguler',9,'jp','Jam ke-7','13:00','13:40'),
  ('sma','reguler',1,'jp','Jam ke-1','08:00','08:45'), ('sma','reguler',2,'jp','Jam ke-2','08:45','09:30'),
  ('sma','reguler',3,'jp','Jam ke-3','09:30','10:15'), ('sma','reguler',4,'istirahat','Istirahat','10:15','10:35'),
  ('sma','reguler',5,'jp','Jam ke-4','10:35','11:20'), ('sma','reguler',6,'jp','Jam ke-5','11:20','12:05'),
  ('sma','reguler',7,'istirahat','Istirahat dan shalat Zuhur','12:05','12:45'), ('sma','reguler',8,'jp','Jam ke-6','12:45','13:30'),
  ('sma','reguler',9,'jp','Jam ke-7','13:30','14:15'),
  ('wustha','jumat',1,'jp','Jam ke-1','08:00','08:40'), ('wustha','jumat',2,'jp','Jam ke-2','08:40','09:20'),
  ('wustha','jumat',3,'istirahat','Istirahat','09:20','09:35'), ('wustha','jumat',4,'jp','Jam ke-3','09:35','10:15'),
  ('wustha','jumat',5,'jp','Jam ke-4','10:15','10:55'),
  ('sma','jumat',1,'jp','Jam ke-1','08:00','08:45'), ('sma','jumat',2,'jp','Jam ke-2','08:45','09:30'),
  ('sma','jumat',3,'istirahat','Istirahat','09:30','09:45'), ('sma','jumat',4,'jp','Jam ke-3','09:45','10:30'),
  ('sma','jumat',5,'jp','Jam ke-4','10:30','11:15')
) v(jenjang, jenis_hari, urutan, jenis, nama, jam_mulai, jam_selesai)
where not exists (select 1 from public.lesson_periods);

-- ---------------------------------------------------------------------
-- 2. PENUGASAN, JADWAL, RENCANA, JURNAL
-- ---------------------------------------------------------------------
create table if not exists public.teaching_assignments (
  id                uuid primary key default gen_random_uuid(),
  academic_year_id  uuid not null references public.academic_years(id) on delete restrict,
  group_id          uuid not null references public.student_groups(id) on delete cascade,
  subject_id        uuid not null references public.subjects(id) on delete restrict,
  employee_id       uuid not null references public.employees(id) on delete restrict,
  jp_pekan          smallint not null default 2 check (jp_pekan between 0 and 40),
  catatan           text,
  created_at        timestamptz not null default now(),
  constraint teaching_assignments_unik unique (group_id, subject_id)
);
create index if not exists ta_guru_idx on public.teaching_assignments (employee_id);

create table if not exists public.class_schedules (
  id             uuid primary key default gen_random_uuid(),
  assignment_id  uuid not null references public.teaching_assignments(id) on delete cascade,
  group_id       uuid not null,                       -- disalin dari penugasan (penjaga bentrok kelas)
  employee_id    uuid not null,                       -- disalin dari penugasan (penjaga bentrok guru)
  hari           smallint not null check (hari between 1 and 6),   -- 1 Senin … 6 Sabtu
  period_id      uuid not null references public.lesson_periods(id) on delete cascade,
  constraint class_schedules_kelas_unik unique (group_id, hari, period_id)
);
create index if not exists cs_guru_idx on public.class_schedules (employee_id, hari);

create table if not exists public.teaching_plans (
  id             uuid primary key default gen_random_uuid(),
  assignment_id  uuid not null references public.teaching_assignments(id) on delete cascade,
  urutan         int not null default 0,
  topik          text not null,
  created_at     timestamptz not null default now()
);
create index if not exists tp_penugasan_idx on public.teaching_plans (assignment_id, urutan);

create table if not exists public.teaching_journals (
  id             uuid primary key default gen_random_uuid(),
  assignment_id  uuid not null references public.teaching_assignments(id) on delete cascade,
  period_id      uuid not null references public.lesson_periods(id) on delete cascade,
  tanggal        date not null,
  employee_id    uuid references public.employees(id) on delete set null,   -- yang mengisi/mengajar
  status         text not null default 'terlaksana' check (status in ('terlaksana','tidak_terlaksana')),
  materi         text,
  plan_id        uuid references public.teaching_plans(id) on delete set null,
  keterangan     text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint teaching_journals_unik unique (assignment_id, tanggal, period_id)
);
create index if not exists tj_tanggal_idx on public.teaching_journals (tanggal);

drop trigger if exists aa_updated on public.teaching_journals;
create trigger aa_updated before update on public.teaching_journals for each row execute function public.tg_updated_at();
drop trigger if exists zz_audit on public.teaching_assignments;
create trigger zz_audit after insert or update or delete on public.teaching_assignments for each row execute function public.tg_audit();

-- Salin kelas dan guru dari penugasan, tolak jam yang tidak sesuai jenjang/jenis hari, dan tolak bentrok guru
create or replace function public.tg_jadwal_jaga()
returns trigger language plpgsql security definer set search_path = public as $$
declare a teaching_assignments; g student_groups; p lesson_periods; st jsonb; b record; v_jenis_hari text;
begin
  select * into a from teaching_assignments where id = new.assignment_id;
  select * into g from student_groups where id = a.group_id;
  select * into p from lesson_periods where id = new.period_id;
  new.group_id := a.group_id; new.employee_id := a.employee_id;
  st := coalesce((select nilai from institution_settings where kunci = 'jadwal_pelajaran'), '{}');
  v_jenis_hari := case when new.hari = coalesce((st->>'hari_jumat')::int, 5) then 'jumat' else 'reguler' end;
  if p.jenis <> 'jp' then raise exception 'Jam istirahat tidak dapat diisi pelajaran.'; end if;
  if p.jenjang <> g.jenjang or p.jenis_hari <> v_jenis_hari then
    raise exception 'Jam pelajaran tidak sesuai jenjang/hari kelas %.', g.nama;
  end if;
  select cs.id, gg.nama as kelas, pp.nama as jam, pp.jam_mulai, pp.jam_selesai into b
  from class_schedules cs join lesson_periods pp on pp.id = cs.period_id join student_groups gg on gg.id = cs.group_id
  where cs.employee_id = new.employee_id and cs.hari = new.hari and cs.id is distinct from new.id
    and pp.jam_mulai < p.jam_selesai and p.jam_mulai < pp.jam_selesai limit 1;
  if found then
    raise exception 'Bentrok: % sudah mengajar di kelas % pada % (% – %).', (select nama_lengkap from employees where id = new.employee_id),
      b.kelas, b.jam, to_char(b.jam_mulai, 'HH24.MI'), to_char(b.jam_selesai, 'HH24.MI');
  end if;
  return new;
end $$;
drop trigger if exists aa_jaga on public.class_schedules;
create trigger aa_jaga before insert or update on public.class_schedules for each row execute function public.tg_jadwal_jaga();

-- Ganti guru pada penugasan → jadwalnya ikut berpindah (bentrok diperiksa ulang)
create or replace function public.tg_penugasan_guru()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.employee_id is distinct from old.employee_id then
    update class_schedules set employee_id = new.employee_id where assignment_id = new.id;
  end if;
  return new;
end $$;
drop trigger if exists ab_guru on public.teaching_assignments;
create trigger ab_guru after update of employee_id on public.teaching_assignments for each row execute function public.tg_penugasan_guru();

-- ---------------------------------------------------------------------
-- 3. HAK DAN RLS
-- ---------------------------------------------------------------------
create or replace function public.boleh_atur_jadwal()
returns boolean language sql stable security definer set search_path = public as $$
  select public.admin_boleh('atur_jadwal') or public.tingkat_fitur('jadwal_mengajar') >= 3
$$;
create or replace function public.boleh_lihat_jurnal_mengajar(p_emp uuid, p_group uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select p_emp = public.saya() or public.is_admin() or public.pimpinan_dari(p_emp) or public.tingkat_fitur('jadwal_mengajar') >= 3
      or p_group in (select public.kelompok_saya())
$$;

-- Jenjang kelas yang jurnal mengajarnya boleh dilihat pemegang fitur jadwal_mengajar (pimpinan menurut bidang)
create or replace function public.jenjang_terlihat()
returns text[] language plpgsql stable security definer set search_path = public as $$
declare v_wustha uuid; v_sma uuid; v_j text[] := '{}'; v_lain boolean;
begin
  if public.is_admin() then return array['wustha','sma']; end if;
  if public.tingkat_fitur('jadwal_mengajar') < 1 then return '{}'; end if;
  select id into v_wustha from org_units where kode = 'WUSTHA';
  select id into v_sma from org_units where kode = 'SMA';
  if exists (select 1 from public.unit_pimpinan_saya() u where u = v_wustha) then v_j := array_append(v_j, 'wustha'); end if;
  if exists (select 1 from public.unit_pimpinan_saya() u where u = v_sma) then v_j := array_append(v_j, 'sma'); end if;
  select exists (select 1 from public.unit_pimpinan_saya() u
                 where u not in (select public.unit_turunan(v_wustha)) and u not in (select public.unit_turunan(v_sma))) into v_lain;
  if v_lain or cardinality(v_j) = 0 then return array['wustha','sma']; end if;
  return v_j;
end $$;

alter table public.subjects enable row level security;
alter table public.lesson_periods enable row level security;
alter table public.teaching_assignments enable row level security;
alter table public.class_schedules enable row level security;
alter table public.teaching_plans enable row level security;
alter table public.teaching_journals enable row level security;
drop policy if exists baca on public.subjects;
create policy baca on public.subjects for select to authenticated using (true);
drop policy if exists baca on public.lesson_periods;
create policy baca on public.lesson_periods for select to authenticated using (true);
drop policy if exists baca on public.teaching_assignments;
create policy baca on public.teaching_assignments for select to authenticated using (true);
drop policy if exists baca on public.class_schedules;
create policy baca on public.class_schedules for select to authenticated using (true);
drop policy if exists baca on public.teaching_plans;
create policy baca on public.teaching_plans for select to authenticated using (true);
drop policy if exists baca on public.teaching_journals;
create policy baca on public.teaching_journals for select to authenticated using (
  employee_id = (select public.saya()) or (select public.is_admin())
  or (select employee_id from public.teaching_assignments t where t.id = assignment_id) = (select public.saya())
  or (select g.jenjang from public.teaching_assignments t join public.student_groups g on g.id = t.group_id where t.id = assignment_id)
       in (select unnest(public.jenjang_terlihat()))
  or public.boleh_lihat_jurnal_mengajar(employee_id, (select group_id from public.teaching_assignments t where t.id = assignment_id)));

-- ---------------------------------------------------------------------
-- 4. PENGATURAN: MAPEL, JAM PELAJARAN, PENUGASAN, JADWAL
-- ---------------------------------------------------------------------
create or replace function public._pesan_jadwal(p_kode text, p_kendala text, p_pesan text)
returns text language sql immutable as $$
  select case
    when p_kendala = 'subjects_kode_check' then 'Kode mapel hanya huruf kapital, angka, atau garis bawah (maks. 20).'
    when p_kendala = 'subjects_nama_unik' or (p_kode = '23505' and p_kendala like 'subjects%') then 'Mapel dengan nama atau kode yang sama sudah ada.'
    when p_kendala = 'teaching_assignments_unik' then 'Mapel ini sudah ditugaskan di kelas tersebut. Ubah penugasan yang ada.'
    when p_kendala = 'class_schedules_kelas_unik' then 'Jam tersebut sudah terisi pelajaran lain di kelas ini.'
    when p_kendala = 'lesson_periods_jam' then 'Jam selesai harus setelah jam mulai.'
    when p_kode = '23503' then 'Data masih dipakai (jadwal atau jurnal), sehingga tidak dapat dihapus. Nonaktifkan saja.'
    else p_pesan end
$$;

create or replace function public.simpan_mapel(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid := nullif(p->>'id', '')::uuid; v_kode text; v_kendala text; v_pesan text;
begin
  if not public.boleh_atur_jadwal() then raise exception 'Anda tidak berwenang mengatur mata pelajaran.' using errcode = '42501'; end if;
  if v_id is null then
    insert into subjects (kode, nama, jenjang, kelompok, urutan) values (upper(trim(p->>'kode')), trim(p->>'nama'),
      coalesce(nullif(p->>'jenjang', ''), 'semua'), coalesce(nullif(p->>'kelompok', ''), 'umum'), coalesce((p->>'urutan')::int, 0)) returning id into v_id;
  else
    update subjects set kode = upper(trim(p->>'kode')), nama = trim(p->>'nama'), jenjang = coalesce(nullif(p->>'jenjang', ''), 'semua'),
      kelompok = coalesce(nullif(p->>'kelompok', ''), 'umum'), aktif = coalesce((p->>'aktif')::boolean, aktif), urutan = coalesce((p->>'urutan')::int, urutan)
    where id = v_id;
  end if;
  return v_id;
exception when others then
  get stacked diagnostics v_kode = returned_sqlstate, v_kendala = constraint_name, v_pesan = message_text;
  raise exception '%', public._pesan_jadwal(v_kode, coalesce(v_kendala, ''), v_pesan) using errcode = v_kode;
end $$;

-- Jam pelajaran satu jenjang + jenis hari: [{urutan, jenis, nama, jam_mulai, jam_selesai}] (urutan yang dihapus ikut menghapus jadwal di jam itu)
create or replace function public.simpan_jam_pelajaran(p_jenjang text, p_jenis_hari text, p_daftar jsonb)
returns int language plpgsql volatile security definer set search_path = public as $$
declare r jsonb; n int := 0; v_kode text; v_kendala text; v_pesan text;
begin
  if not public.boleh_atur_jadwal() then raise exception 'Anda tidak berwenang mengatur jam pelajaran.' using errcode = '42501'; end if;
  delete from lesson_periods where jenjang = p_jenjang and jenis_hari = p_jenis_hari
    and urutan not in (select (x->>'urutan')::smallint from jsonb_array_elements(p_daftar) x);
  for r in select * from jsonb_array_elements(p_daftar) loop
    insert into lesson_periods (jenjang, jenis_hari, urutan, jenis, nama, jam_mulai, jam_selesai)
    values (p_jenjang, p_jenis_hari, (r->>'urutan')::smallint, r->>'jenis', trim(r->>'nama'), (r->>'jam_mulai')::time, (r->>'jam_selesai')::time)
    on conflict (jenjang, jenis_hari, urutan) do update set jenis = excluded.jenis, nama = excluded.nama, jam_mulai = excluded.jam_mulai, jam_selesai = excluded.jam_selesai;
    n := n + 1;
  end loop;
  -- Jam yang berubah menjadi istirahat tidak boleh menyimpan pelajaran
  delete from class_schedules cs using lesson_periods p where p.id = cs.period_id and p.jenis = 'istirahat';
  return n;
exception when others then
  get stacked diagnostics v_kode = returned_sqlstate, v_kendala = constraint_name, v_pesan = message_text;
  raise exception '%', public._pesan_jadwal(v_kode, coalesce(v_kendala, ''), v_pesan) using errcode = v_kode;
end $$;

create or replace function public.simpan_penugasan(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid := nullif(p->>'id', '')::uuid; g student_groups; s subjects; v_kode text; v_kendala text; v_pesan text;
begin
  if not public.boleh_atur_jadwal() then raise exception 'Anda tidak berwenang mengatur penugasan mengajar.' using errcode = '42501'; end if;
  select * into g from student_groups where id = (p->>'group_id')::uuid;
  if not found or g.jenis <> 'kelas' then raise exception 'Pilih kelas (rombel) yang sah.'; end if;
  perform public._ta_boleh_ubah(g.academic_year_id);
  select * into s from subjects where id = (p->>'subject_id')::uuid;
  if not found then raise exception 'Mata pelajaran tidak ditemukan.'; end if;
  if s.jenjang <> 'semua' and s.jenjang <> g.jenjang then raise exception 'Mapel % bukan untuk jenjang kelas %.', s.nama, g.nama; end if;
  if not exists (select 1 from employees where id = (p->>'employee_id')::uuid and status_keaktifan = 'aktif') then raise exception 'Guru harus pegawai aktif.'; end if;
  if v_id is null then
    insert into teaching_assignments (academic_year_id, group_id, subject_id, employee_id, jp_pekan, catatan)
    values (g.academic_year_id, g.id, s.id, (p->>'employee_id')::uuid, coalesce((p->>'jp_pekan')::smallint, 2), nullif(trim(p->>'catatan'), ''))
    returning id into v_id;
  else
    update teaching_assignments set subject_id = s.id, employee_id = (p->>'employee_id')::uuid, jp_pekan = coalesce((p->>'jp_pekan')::smallint, jp_pekan),
      catatan = nullif(trim(p->>'catatan'), '') where id = v_id;
  end if;
  return v_id;
exception when others then
  get stacked diagnostics v_kode = returned_sqlstate, v_kendala = constraint_name, v_pesan = message_text;
  raise exception '%', public._pesan_jadwal(v_kode, coalesce(v_kendala, ''), v_pesan) using errcode = v_kode;
end $$;

create or replace function public.hapus_penugasan(p_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  if not public.boleh_atur_jadwal() then raise exception 'Anda tidak berwenang mengatur penugasan mengajar.' using errcode = '42501'; end if;
  if exists (select 1 from teaching_journals where assignment_id = p_id) then
    raise exception 'Penugasan ini sudah memiliki jurnal mengajar sehingga tidak dapat dihapus. Ganti guru atau kosongkan jadwalnya.';
  end if;
  delete from teaching_assignments where id = p_id;
end $$;

-- Isi/kosongkan satu sel jadwal kelas
create or replace function public.atur_sel_jadwal(p_group uuid, p_hari smallint, p_period uuid, p_assignment uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v_kode text; v_kendala text; v_pesan text;
begin
  if not public.boleh_atur_jadwal() then raise exception 'Anda tidak berwenang mengatur jadwal pelajaran.' using errcode = '42501'; end if;
  perform public._ta_boleh_ubah((select academic_year_id from student_groups where id = p_group));
  delete from class_schedules where group_id = p_group and hari = p_hari and period_id = p_period;
  if p_assignment is not null then
    if (select group_id from teaching_assignments where id = p_assignment) <> p_group then raise exception 'Penugasan bukan milik kelas ini.'; end if;
    insert into class_schedules (assignment_id, group_id, employee_id, hari, period_id)
    values (p_assignment, p_group, (select employee_id from teaching_assignments where id = p_assignment), p_hari, p_period);
  end if;
exception when others then
  get stacked diagnostics v_kode = returned_sqlstate, v_kendala = constraint_name, v_pesan = message_text;
  raise exception '%', public._pesan_jadwal(v_kode, coalesce(v_kendala, ''), v_pesan) using errcode = v_kode;
end $$;

-- Impor penugasan dari Excel: [{guru (NIY atau nama), mapel (kode atau nama), kelas (nama rombel), jp}]
create or replace function public.impor_penugasan(p_baris jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare r jsonb; i int := 0; hasil jsonb := '[]'; v_ta uuid; v_emp uuid; v_sub uuid; v_grp uuid; v_ada uuid; v_pesan text;
begin
  if not public.boleh_atur_jadwal() then raise exception 'Anda tidak berwenang mengimpor penugasan.' using errcode = '42501'; end if;
  select id into v_ta from academic_years where aktif;
  for r in select * from jsonb_array_elements(p_baris) loop
    i := i + 1;
    begin
      select id into v_emp from employees where status_keaktifan = 'aktif' and (niy = trim(r->>'guru') or lower(nama_lengkap) = lower(trim(r->>'guru'))) limit 1;
      if v_emp is null then raise exception 'Guru "%" tidak ditemukan (tulis NIY atau nama persis seperti di Data Pegawai).', r->>'guru'; end if;
      select id into v_grp from student_groups where academic_year_id = v_ta and jenis = 'kelas' and lower(nama) = lower(regexp_replace(trim(r->>'kelas'), '^[Kk]elas\s*', ''));
      if v_grp is null then raise exception 'Kelas "%" tidak ditemukan di Kelompok Santri tahun ajaran aktif.', r->>'kelas'; end if;
      select s.id into v_sub from subjects s join student_groups g on g.id = v_grp
      where s.aktif and (s.kode = upper(trim(r->>'mapel')) or lower(s.nama) = lower(trim(r->>'mapel'))) and s.jenjang in ('semua', g.jenjang) limit 1;
      if v_sub is null then raise exception 'Mapel "%" tidak ditemukan untuk jenjang kelas ini.', r->>'mapel'; end if;
      select id into v_ada from teaching_assignments where group_id = v_grp and subject_id = v_sub;
      perform public.simpan_penugasan(jsonb_build_object('id', v_ada, 'group_id', v_grp, 'subject_id', v_sub, 'employee_id', v_emp,
        'jp_pekan', coalesce(nullif(r->>'jp', '')::smallint, 2)));
      hasil := hasil || jsonb_build_object('baris', i, 'ok', true, 'aksi', case when v_ada is null then 'ditambah' else 'diperbarui' end);
    exception when others then
      get stacked diagnostics v_pesan = message_text;
      hasil := hasil || jsonb_build_object('baris', i, 'ok', false, 'pesan', v_pesan);
    end;
    v_emp := null; v_sub := null; v_grp := null; v_ada := null;
  end loop;
  return hasil;
end $$;

-- ---------------------------------------------------------------------
-- 5. JAM GURU MAPEL OTOMATIS DI BEBAN KERJA (1 JP = jam_per_jp jam)
-- ---------------------------------------------------------------------
create or replace function public.sinkron_jam_mengajar()
returns void language plpgsql volatile security definer set search_path = public as $$
declare v_comp uuid; v_faktor numeric := coalesce((select (nilai->>'jam_per_jp')::numeric from institution_settings where kunci = 'jadwal_pelajaran'), 1);
begin
  select c.id into v_comp from workload_components c join functional_positions fp on fp.id = c.functional_position_id where fp.kode = 'GURU';
  if v_comp is null then return; end if;
  insert into employee_workloads (employee_id, component_id, jam, catatan)
  select cs.employee_id, v_comp, least(99, count(*) * v_faktor), 'Otomatis dari jadwal pelajaran'
  from class_schedules cs join teaching_assignments t on t.id = cs.assignment_id join academic_years a on a.id = t.academic_year_id and a.aktif
  group by cs.employee_id
  on conflict (employee_id, component_id) do update set jam = excluded.jam, catatan = excluded.catatan, updated_at = now();
  -- Guru yang tidak lagi terjadwal: jam otomatisnya dikosongkan
  delete from employee_workloads w where w.component_id = v_comp and w.catatan = 'Otomatis dari jadwal pelajaran'
    and not exists (select 1 from class_schedules cs join teaching_assignments t on t.id = cs.assignment_id
                    join academic_years a on a.id = t.academic_year_id and a.aktif where cs.employee_id = w.employee_id);
end $$;
create or replace function public.tg_sinkron_jam_mengajar()
returns trigger language plpgsql security definer set search_path = public as $$ begin perform public.sinkron_jam_mengajar(); return null; end $$;
drop trigger if exists zz_sinkron_jam on public.class_schedules;
create trigger zz_sinkron_jam after insert or update or delete on public.class_schedules for each statement execute function public.tg_sinkron_jam_mengajar();
drop trigger if exists zz_sinkron_jam on public.teaching_assignments;
create trigger zz_sinkron_jam after update or delete on public.teaching_assignments for each statement execute function public.tg_sinkron_jam_mengajar();

-- ---------------------------------------------------------------------
-- 6. JURNAL MENGAJAR
-- ---------------------------------------------------------------------
-- Jadwal mengajar seorang guru pada tanggal tertentu beserta jurnal dan rencana materi berikutnya
create or replace function public.jadwal_mengajar(p_tanggal date default null, p_emp uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_tgl date := coalesce(p_tanggal, public.hari_ini()); v_emp uuid := coalesce(p_emp, public.saya()); v_dow int := extract(dow from v_tgl);
begin
  if v_emp is null then return '[]'; end if;
  if v_emp <> public.saya() and not (public.is_admin() or public.pimpinan_dari(v_emp)) then
    raise exception 'Anda tidak berwenang melihat jadwal mengajar pegawai ini.' using errcode = '42501';
  end if;
  if v_dow = 0 or public.libur_tugas(v_tgl, 'sekolah') then return '[]'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
      'assignment_id', t.id, 'period_id', p.id, 'jam_ke', p.nama, 'urutan', p.urutan, 'jam_mulai', p.jam_mulai, 'jam_selesai', p.jam_selesai,
      'group_id', g.id, 'kelas', g.nama, 'jenjang', g.jenjang, 'mapel', s.nama, 'kode_mapel', s.kode,
      'jurnal', (select jsonb_build_object('id', j.id, 'status', j.status, 'materi', j.materi, 'keterangan', j.keterangan, 'plan_id', j.plan_id)
                 from teaching_journals j where j.assignment_id = t.id and j.tanggal = v_tgl and j.period_id = p.id),
      'rencana', (select jsonb_build_object('id', tp.id, 'topik', tp.topik) from teaching_plans tp
                  where tp.assignment_id = t.id and not exists (select 1 from teaching_journals j2 where j2.plan_id = tp.id and not (j2.tanggal = v_tgl))
                  order by tp.urutan, tp.created_at limit 1),
      'materi_terakhir', (select j3.materi from teaching_journals j3 where j3.assignment_id = t.id and j3.tanggal < v_tgl and j3.status = 'terlaksana'
                          order by j3.tanggal desc limit 1))
    order by p.jam_mulai)
    from class_schedules cs join teaching_assignments t on t.id = cs.assignment_id join academic_years a on a.id = t.academic_year_id and a.aktif
    join lesson_periods p on p.id = cs.period_id join student_groups g on g.id = t.group_id join subjects s on s.id = t.subject_id
    where cs.employee_id = v_emp and cs.hari = v_dow), '[]');
end $$;

-- Simpan jurnal mengajar: {tanggal, entri: [{assignment_id, period_id, status, materi, plan_id?, keterangan?}]}
create or replace function public.simpan_jurnal_mengajar(p jsonb)
returns int language plpgsql volatile security definer set search_path = public as $$
declare v_tgl date := (p->>'tanggal')::date; r jsonb; n int := 0; v_saya uuid := public.saya(); t teaching_assignments;
begin
  if v_saya is null then raise exception 'Sesi masuk tidak berlaku.' using errcode = '42501'; end if;
  if v_tgl > public.hari_ini() then raise exception 'Jurnal mengajar tidak dapat diisi untuk tanggal yang akan datang.'; end if;
  if not public._jurnal_terbuka(v_tgl) and not public.is_superadmin() then
    raise exception 'Jurnal tanggal ini sudah terkunci (batas pengisian H+1, sama dengan Jurnal Harian).';
  end if;
  for r in select * from jsonb_array_elements(coalesce(p->'entri', '[]')) loop
    select * into t from teaching_assignments where id = (r->>'assignment_id')::uuid;
    if not found then raise exception 'Penugasan mengajar tidak ditemukan.'; end if;
    if t.employee_id <> v_saya and not public.admin_boleh('atur_jadwal') then raise exception 'Anda bukan guru pada penugasan ini.' using errcode = '42501'; end if;
    if not exists (select 1 from class_schedules where assignment_id = t.id and period_id = (r->>'period_id')::uuid and hari = extract(dow from v_tgl)) then
      raise exception 'Jam tersebut tidak ada di jadwal pelajaran hari ini.';
    end if;
    if coalesce(r->>'status', 'terlaksana') = 'terlaksana' and length(trim(coalesce(r->>'materi', ''))) < 3 then
      raise exception 'Isi materi pokok yang diajarkan (minimal 3 huruf).';
    end if;
    if r->>'status' = 'tidak_terlaksana' and length(trim(coalesce(r->>'keterangan', ''))) < 3 then
      raise exception 'Isi keterangan mengapa pelajaran tidak terlaksana.';
    end if;
    insert into teaching_journals (assignment_id, period_id, tanggal, employee_id, status, materi, plan_id, keterangan)
    values (t.id, (r->>'period_id')::uuid, v_tgl, v_saya, coalesce(nullif(r->>'status', ''), 'terlaksana'), nullif(trim(r->>'materi'), ''),
            nullif(r->>'plan_id', '')::uuid, nullif(trim(r->>'keterangan'), ''))
    on conflict (assignment_id, tanggal, period_id) do update set employee_id = excluded.employee_id, status = excluded.status,
      materi = excluded.materi, plan_id = excluded.plan_id, keterangan = excluded.keterangan;
    n := n + 1;
  end loop;
  return n;
end $$;

-- Rencana materi per penugasan (menggantikan daftar): ["topik 1", "topik 2", …]; topik yang sudah dipakai jurnal tetap tersimpan
create or replace function public.simpan_rencana_materi(p_assignment uuid, p_topik jsonb)
returns int language plpgsql volatile security definer set search_path = public as $$
declare x text; n int := 0;
begin
  if (select employee_id from teaching_assignments where id = p_assignment) <> public.saya() and not public.boleh_atur_jadwal() then
    raise exception 'Anda bukan guru pada penugasan ini.' using errcode = '42501';
  end if;
  delete from teaching_plans tp where tp.assignment_id = p_assignment and not exists (select 1 from teaching_journals j where j.plan_id = tp.id);
  for x in select jsonb_array_elements_text(p_topik) loop
    if length(trim(x)) >= 2 and not exists (select 1 from teaching_plans where assignment_id = p_assignment and topik = trim(x)) then
      n := n + 1;
      insert into teaching_plans (assignment_id, urutan, topik) values (p_assignment, n, trim(x));
    end if;
  end loop;
  return n;
end $$;

-- Rekap mengajar per guru per penugasan: JP terjadwal (hari sekolah dalam periode), terlaksana, tidak terlaksana, belum diisi
create or replace function public.rekap_mengajar(p_mulai date, p_selesai date, p_emp uuid default null)
returns table (employee_id uuid, guru text, niy text, assignment_id uuid, kelas text, mapel text, jp_pekan int,
               jp_terjadwal int, jp_terlaksana int, jp_tidak int, jp_kosong int)
language sql stable security definer set search_path = public as $$
  with hari as (
    select d::date tgl, extract(dow from d)::int dow from generate_series(p_mulai, least(p_selesai, public.hari_ini()), interval '1 day') d
    where extract(dow from d) <> 0 and not public.libur_tugas(d::date, 'sekolah')
  ), slot as (
    select cs.assignment_id, h.tgl, cs.period_id from class_schedules cs join hari h on h.dow = cs.hari
  )
  select t.employee_id, e.nama_lengkap, e.niy, t.id, g.nama, s.nama, t.jp_pekan,
         count(sl.*)::int,
         count(j.*) filter (where j.status = 'terlaksana')::int,
         count(j.*) filter (where j.status = 'tidak_terlaksana')::int,
         (count(sl.*) - count(j.*))::int
  from teaching_assignments t join academic_years a on a.id = t.academic_year_id and a.aktif
  join employees e on e.id = t.employee_id join student_groups g on g.id = t.group_id join subjects s on s.id = t.subject_id
  left join slot sl on sl.assignment_id = t.id
  left join teaching_journals j on j.assignment_id = t.id and j.tanggal = sl.tgl and j.period_id = sl.period_id
  where (p_emp is null or t.employee_id = p_emp)
    and (t.employee_id = public.saya() or public.is_admin() or public.pimpinan_dari(t.employee_id) or public.tingkat_fitur('jadwal_mengajar') >= 3
         or g.jenjang = any(public.jenjang_terlihat()))
  group by t.employee_id, e.nama_lengkap, e.niy, t.id, g.nama, s.nama, t.jp_pekan
  order by e.nama_lengkap, g.nama, s.nama
$$;

do $$
declare f text;
begin
  foreach f in array array['boleh_atur_jadwal()','simpan_mapel(jsonb)','simpan_jam_pelajaran(text,text,jsonb)','simpan_penugasan(jsonb)',
    'hapus_penugasan(uuid)','atur_sel_jadwal(uuid,smallint,uuid,uuid)','impor_penugasan(jsonb)','jadwal_mengajar(date,uuid)',
    'simpan_jurnal_mengajar(jsonb)','simpan_rencana_materi(uuid,jsonb)','rekap_mengajar(date,date,uuid)','jenjang_terlihat()']
  loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  execute 'revoke execute on function public.sinkron_jam_mengajar() from public, anon, authenticated';
  execute 'revoke execute on function public.boleh_lihat_jurnal_mengajar(uuid,uuid) from public, anon';
end $$;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 6 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select 'Tabel jadwal pelajaran (6) dengan RLS' as pemeriksaan,
       case when (select count(*) from pg_tables where schemaname = 'public' and rowsecurity and tablename in
                   ('subjects','lesson_periods','teaching_assignments','class_schedules','teaching_plans','teaching_journals')) = 6 then 'Sesuai' else 'Periksa' end as hasil
union all
select 'Mata pelajaran isi awal (minimal 20)', case when (select count(*) from public.subjects) >= 20 then 'Sesuai' else 'Periksa' end
union all
select 'Jam pelajaran: jam ke-1 pukul 08.00, JP Wustha 40 menit, SMA 45 menit',
       case when exists (select 1 from public.lesson_periods where jenjang = 'wustha' and jenis_hari = 'reguler' and urutan = 1 and jam_mulai = '08:00' and jam_selesai = '08:40')
             and exists (select 1 from public.lesson_periods where jenjang = 'sma' and jenis_hari = 'reguler' and urutan = 1 and jam_selesai = '08:45')
            then 'Sesuai' else 'Periksa (sudah diubah?)' end
union all
select 'Jadwal Jumat tersendiri', case when exists (select 1 from public.lesson_periods where jenis_hari = 'jumat') then 'Sesuai' else 'Periksa' end
union all
select 'Jam Guru Mapel otomatis dari jadwal', case when exists (select 1 from pg_trigger where tgname = 'zz_sinkron_jam') then 'Sesuai' else 'Periksa' end
union all
select 'Migrasi 3500 sudah terpasang', case when exists (select 1 from pg_proc where proname = 'sinkron_sesi_ekskul') then 'Sesuai' else 'Periksa: jalankan 3500 dulu' end;
