-- SIMKA PRO | supabase/migrations/20261005003800_tahfizh_dasar.sql | v1.0 | Fase 5 – Tahap 1 Pengaturan tahfizh dan data hafalan awal | 05/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 5 · Migrasi 38: Fondasi tahfizh (Blueprint Bagian 20)
--   * tahfizh_settings  : KKM, bobot Tajwid/Itqan, batas isian janggal, ambang rekap — per tahun ajaran
--   * predicate_ranges  : rentang nilai → huruf, deskripsi rapor, deskripsi sertifikat, catatan akhir
--   * tahfizh_targets   : target per program (Reguler/Takhassus) × tingkat kelas 7–12, dalam HALAMAN
--   * tahfizh_months    : bulan dan pekan efektif (dihitung dari kalender, dapat diubah manual)
--   * tahfizh_examiners : penguji tambahan (kenaikan juz / sertifikasi) di luar penguji bawaan jabatan
--   * student_tahfizh   : program santri + posisi terakhir sabaq/sabqi/manzil (dalam halaman; 20 hal = 1 juz)
--   * juz_achievements  : capaian juz resmi (sumber: data awal, ujian, sertifikasi)
--   * Fungsi: hak_tahfizh, siapkan_tahfizh, hitung_pekan_efektif, simpan_pengaturan_tahfizh, penguji_tahfizh,
--             simpan_penguji, hapus_penguji, atur_program_tahfizh, simpan_hafalan_awal, impor_hafalan_awal, daftar_tahfizh
-- Penulisan hanya lewat fungsi. Izin admin baru: atur_tahfizh, validasi_tahfizh.
-- Jalankan SETELAH migrasi 3700. Aman dijalankan ulang.
-- =====================================================================

insert into public.admin_capabilities (kode, nama, urutan) values
  ('atur_tahfizh', 'Mengatur tahfizh: KKM, target, predikat, pekan efektif, dan penguji (Fase 5)', 19),
  ('validasi_tahfizh', 'Memvalidasi capaian hafalan dan mengisi data hafalan awal santri (Fase 5)', 20)
on conflict (kode) do nothing;

-- ---------------------------------------------------------------------
-- 1. TABEL
-- ---------------------------------------------------------------------
create table if not exists public.tahfizh_settings (
  academic_year_id    uuid primary key references public.academic_years(id) on delete cascade,
  kkm                 numeric(5,2) not null default 80 constraint tahfizh_kkm_check check (kkm between 0 and 100),
  bobot_tajwid        smallint not null default 50 constraint tahfizh_bobot_check check (bobot_tajwid between 0 and 100),
  bobot_itqan         smallint not null default 50,
  batas_lonjakan_hal  smallint not null default 10 constraint tahfizh_lonjakan_check check (batas_lonjakan_hal between 1 and 200),
  rekap_sangat_memuaskan smallint not null default 90,   -- % capaian target semester
  rekap_memuaskan     smallint not null default 75,
  catatan             text,
  updated_at          timestamptz not null default now(),
  updated_by          uuid references public.employees(id) on delete set null,
  constraint tahfizh_bobot_jumlah check (bobot_tajwid + bobot_itqan = 100),
  constraint tahfizh_rekap_urut check (rekap_memuaskan between 0 and 100 and rekap_sangat_memuaskan between rekap_memuaskan and 100)
);

create table if not exists public.predicate_ranges (
  id                    uuid primary key default gen_random_uuid(),
  academic_year_id      uuid not null references public.academic_years(id) on delete cascade,
  huruf                 text not null constraint predicate_huruf_check check (length(trim(huruf)) between 1 and 3),
  nilai_min             numeric(5,2) not null,
  nilai_maks            numeric(5,2) not null,
  deskripsi_rapor       text not null,
  deskripsi_sertifikat  text,
  catatan_akhir         text,
  urutan                smallint not null default 0,
  constraint predicate_unik unique (academic_year_id, huruf),
  constraint predicate_rentang check (nilai_min >= 0 and nilai_maks <= 100 and nilai_min <= nilai_maks)
);

create table if not exists public.tahfizh_targets (
  academic_year_id  uuid not null references public.academic_years(id) on delete cascade,
  program           text not null constraint tahfizh_target_program check (program in ('reguler','takhassus')),
  tingkat           smallint not null constraint tahfizh_target_tingkat check (tingkat between 7 and 12),
  pekan_hal         smallint not null default 5   constraint tahfizh_target_pekan check (pekan_hal between 0 and 100),
  bulan_hal         smallint not null default 20  constraint tahfizh_target_bulan check (bulan_hal between 0 and 400),
  semester_hal      smallint not null default 100 constraint tahfizh_target_semester check (semester_hal between 0 and 600),
  tahun_hal         smallint not null default 200 constraint tahfizh_target_tahun check (tahun_hal between 0 and 600),
  primary key (academic_year_id, program, tingkat)
);

create table if not exists public.tahfizh_months (
  academic_year_id  uuid not null references public.academic_years(id) on delete cascade,
  bulan             date not null constraint tahfizh_bulan_awal check (extract(day from bulan) = 1),
  semester          smallint not null constraint tahfizh_bulan_semester check (semester in (1, 2)),
  pekan_efektif     smallint not null default 4 constraint tahfizh_bulan_pekan check (pekan_efektif between 0 and 5),
  manual            boolean not null default false,
  primary key (academic_year_id, bulan)
);

create table if not exists public.tahfizh_examiners (
  id           uuid primary key default gen_random_uuid(),
  jenis        text not null constraint tahfizh_penguji_jenis check (jenis in ('kenaikan','sertifikasi')),
  employee_id  uuid not null references public.employees(id) on delete cascade,
  aktif        boolean not null default true,
  catatan      text,
  created_at   timestamptz not null default now(),
  constraint tahfizh_penguji_unik unique (jenis, employee_id)
);

create table if not exists public.student_tahfizh (
  student_id     uuid primary key references public.students(id) on delete cascade,
  program        text not null default 'reguler' constraint student_tahfizh_program check (program in ('reguler','takhassus')),
  sabaq_hal      smallint not null default 0 constraint student_tahfizh_sabaq check (sabaq_hal between 0 and 600),
  sabqi_hal      smallint not null default 0 constraint student_tahfizh_sabqi check (sabqi_hal between 0 and 600),
  manzil_hal     smallint not null default 0 constraint student_tahfizh_manzil check (manzil_hal between 0 and 600),
  juz_sedang     smallint constraint student_tahfizh_juz check (juz_sedang between 1 and 30),
  posisi_pada    timestamptz,
  posisi_sumber  text constraint student_tahfizh_sumber check (posisi_sumber in ('awal','setoran')),
  updated_at     timestamptz not null default now()
);

create table if not exists public.juz_achievements (
  id                 uuid primary key default gen_random_uuid(),
  student_id         uuid not null references public.students(id) on delete cascade,
  juz                smallint not null constraint juz_achievements_juz check (juz between 1 and 30),
  sumber             text not null constraint juz_achievements_sumber check (sumber in ('awal','ujian','sertifikasi')),
  tanggal            date not null default public.hari_ini(),
  ditetapkan_oleh    uuid references public.employees(id) on delete set null,
  catatan            text,
  created_at         timestamptz not null default now(),
  constraint juz_achievements_unik unique (student_id, juz)
);
create index if not exists juz_achievements_santri_idx on public.juz_achievements (student_id);

drop trigger if exists aa_updated on public.tahfizh_settings;
create trigger aa_updated before update on public.tahfizh_settings for each row execute function public.tg_updated_at();
drop trigger if exists aa_updated on public.student_tahfizh;
create trigger aa_updated before update on public.student_tahfizh for each row execute function public.tg_updated_at();
do $$
declare t text;
begin
  foreach t in array array['tahfizh_settings','predicate_ranges','tahfizh_targets','tahfizh_examiners','student_tahfizh'] loop
    execute format('drop trigger if exists zz_audit on public.%I', t);
    execute format('create trigger zz_audit after insert or update or delete on public.%I for each row execute function public.tg_audit()', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 2. HAK
-- ---------------------------------------------------------------------
-- Pimpinan tahfizh: pemegang jabatan struktural yang membawahi Bidang Tahfizh (Kepala Bidang Tahfizh,
-- wakilnya, Direktur, Wakil Direktur) termasuk Plt yang sedang berlaku.
create or replace function public.pimpinan_tahfizh()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.unit_pimpinan_saya() u join org_units o on o.id = u where o.kode = 'TAHFIZH')
      or exists (select 1 from acting_assignments a join org_units o on o.id = a.org_unit_id
                  where a.employee_id = public.saya() and o.kode = 'TAHFIZH'
                    and public.hari_ini() between a.mulai and a.sampai)
$$;

create or replace function public.boleh_atur_tahfizh()
returns boolean language sql stable security definer set search_path = public as $$
  select public.admin_boleh('atur_tahfizh') or public.tingkat_fitur('tahfizh') >= 3
$$;

create or replace function public.boleh_validasi_tahfizh()
returns boolean language sql stable security definer set search_path = public as $$
  select public.admin_boleh('validasi_tahfizh') or public.pimpinan_tahfizh()
$$;

-- ---------------------------------------------------------------------
-- 3. RLS (baca saja; tulis lewat fungsi)
-- ---------------------------------------------------------------------
alter table public.tahfizh_settings enable row level security;
alter table public.predicate_ranges enable row level security;
alter table public.tahfizh_targets enable row level security;
alter table public.tahfizh_months enable row level security;
alter table public.tahfizh_examiners enable row level security;
alter table public.student_tahfizh enable row level security;
alter table public.juz_achievements enable row level security;

do $$
declare t text;
begin
  foreach t in array array['tahfizh_settings','predicate_ranges','tahfizh_targets','tahfizh_months','tahfizh_examiners'] loop
    execute format('drop policy if exists baca_semua on public.%I', t);
    execute format('create policy baca_semua on public.%I for select to authenticated using (true)', t);
  end loop;
end $$;
drop policy if exists santri_baca on public.student_tahfizh;
create policy santri_baca on public.student_tahfizh for select to authenticated using (
  student_id in (select public.santri_terlihat()));
drop policy if exists santri_baca on public.juz_achievements;
create policy santri_baca on public.juz_achievements for select to authenticated using (
  student_id in (select public.santri_terlihat()));

-- ---------------------------------------------------------------------
-- 4. PEKAN EFEKTIF DAN ISI AWAL PER TAHUN AJARAN
-- ---------------------------------------------------------------------
-- Pekan efektif per bulan = hari halaqah aktif (bukan libur kalender "tahfizh", di dalam rentang tahun ajaran) ÷ 6,
-- dibulatkan ke bawah, dibatasi 0–5 (bulan penuh dengan Ahad libur = 4 pekan; 6 bulan = 24 pekan seperti contoh pondok). Bulan Juli–Desember semester 1, Januari–Juni semester 2.
create or replace function public.hitung_pekan_efektif(p_ta uuid)
returns table (bulan date, semester smallint, hari_aktif int, pekan_efektif smallint)
language sql stable security definer set search_path = public as $$
  with ta as (select mulai, selesai from academic_years where id = p_ta),
  hari as (
    select d::date tgl from ta, generate_series(ta.mulai, ta.selesai, interval '1 day') d
  )
  select date_trunc('month', tgl)::date,
         (case when extract(month from tgl) >= 7 then 1 else 2 end)::smallint,
         count(*) filter (where not public.libur_tugas(tgl, 'tahfizh'))::int,
         least(5, greatest(0, floor(count(*) filter (where not public.libur_tugas(tgl, 'tahfizh')) / 6.0)))::smallint
  from hari group by 1, 2 order by 1
$$;

-- Siapkan pengaturan tahfizh sebuah tahun ajaran: salin dari tahun ajaran sebelumnya bila ada, bila tidak isi awal
-- blueprint. Hanya mengisi yang belum ada (tidak menimpa). Bulan efektif yang belum diubah manual dihitung ulang.
create or replace function public.siapkan_tahfizh(p_ta uuid default null)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v_ta uuid := coalesce(p_ta, (select id from academic_years where aktif)); v_lalu uuid;
begin
  if v_ta is null then return; end if;
  select a.id into v_lalu from academic_years a
   where a.id <> v_ta and a.mulai < (select mulai from academic_years where id = v_ta)
     and exists (select 1 from tahfizh_settings s where s.academic_year_id = a.id)
   order by a.mulai desc limit 1;

  if v_lalu is not null then
    insert into tahfizh_settings (academic_year_id, kkm, bobot_tajwid, bobot_itqan, batas_lonjakan_hal, rekap_sangat_memuaskan, rekap_memuaskan, catatan)
    select v_ta, kkm, bobot_tajwid, bobot_itqan, batas_lonjakan_hal, rekap_sangat_memuaskan, rekap_memuaskan, catatan
      from tahfizh_settings where academic_year_id = v_lalu
    on conflict do nothing;
    insert into predicate_ranges (academic_year_id, huruf, nilai_min, nilai_maks, deskripsi_rapor, deskripsi_sertifikat, catatan_akhir, urutan)
    select v_ta, huruf, nilai_min, nilai_maks, deskripsi_rapor, deskripsi_sertifikat, catatan_akhir, urutan
      from predicate_ranges where academic_year_id = v_lalu
       and not exists (select 1 from predicate_ranges x where x.academic_year_id = v_ta);
    insert into tahfizh_targets (academic_year_id, program, tingkat, pekan_hal, bulan_hal, semester_hal, tahun_hal)
    select v_ta, program, tingkat, pekan_hal, bulan_hal, semester_hal, tahun_hal
      from tahfizh_targets where academic_year_id = v_lalu
    on conflict do nothing;
  else
    insert into tahfizh_settings (academic_year_id) values (v_ta) on conflict do nothing;
    if not exists (select 1 from predicate_ranges where academic_year_id = v_ta) then
      insert into predicate_ranges (academic_year_id, huruf, nilai_min, nilai_maks, deskripsi_rapor, deskripsi_sertifikat, catatan_akhir, urutan) values
        (v_ta, 'A', 94, 100, 'Mumtaz (Istimewa)', 'Pujian',
         'Kemampuan ananda sangat baik, selamat atas pencapaiannya, semangat menghafal dan capaian hafalannya dipertahankan!', 1),
        (v_ta, 'B', 87, 93.99, 'Jayyid Jiddan (Sangat Baik)', 'Sangat Memuaskan',
         'Selamat atas pencapaiannya, semangat menghafal dan capaian hafalannya ditingkatkan lagi!', 2),
        (v_ta, 'C', 80, 86.99, 'Jayyid (Baik)', 'Memuaskan',
         'Semangat menghafal dan capaian hafalannya lebih ditingkatkan lagi!', 3),
        (v_ta, 'D', 0, 79.99, 'Maqbul (Cukup)', 'Cukup Memuaskan', 'Tingkatkan semangat menghafalnya!', 4);
    end if;
  end if;
  -- Target yang belum ada: isi awal blueprint (pekan 5 hal, bulan 20 hal, semester 5 juz, tahun 10 juz)
  insert into tahfizh_targets (academic_year_id, program, tingkat)
  select v_ta, p, t from unnest(array['reguler','takhassus']) p, generate_series(7, 12) t
  on conflict do nothing;
  -- Bulan efektif: tambah yang belum ada, hitung ulang yang tidak diubah manual
  insert into tahfizh_months (academic_year_id, bulan, semester, pekan_efektif)
  select v_ta, h.bulan, h.semester, h.pekan_efektif from public.hitung_pekan_efektif(v_ta) h
  on conflict (academic_year_id, bulan) do update set semester = excluded.semester, pekan_efektif = excluded.pekan_efektif
    where not tahfizh_months.manual;
  delete from tahfizh_months m where m.academic_year_id = v_ta
    and m.bulan not in (select h.bulan from public.hitung_pekan_efektif(v_ta) h);
end $$;

-- Tahun ajaran baru otomatis mendapat pengaturan tahfizh
create or replace function public.tg_academic_years_tahfizh()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.siapkan_tahfizh(new.id);
  return new;
end $$;
drop trigger if exists zz_tahfizh on public.academic_years;
create trigger zz_tahfizh after insert or update of mulai, selesai on public.academic_years
  for each row execute function public.tg_academic_years_tahfizh();

-- ---------------------------------------------------------------------
-- 5. HAK PENGGUNA DAN PENGUJI
-- ---------------------------------------------------------------------
-- Penguji bawaan: kenaikan juz = Kepala Bidang/Wakil Kepala Bidang Tahfizh (termasuk Plt);
-- sertifikasi = Direktur dan Wakil Direktur (termasuk Plt). Ditambah penguji yang ditunjuk admin.
create or replace function public.penguji_tahfizh(p_jenis text)
returns table (employee_id uuid, nama text, niy text, jabatan text, bawaan boolean, aktif boolean, id uuid)
language sql stable security definer set search_path = public as $$
  with bawaan as (
    select distinct on (p.employee_id) p.employee_id, p.nama_jabatan || case when p.plt then ' (Plt)' else '' end as jabatan
      from public.pemegang_jabatan() p left join org_units o on o.id = p.org_unit_id
     where (p_jenis = 'kenaikan' and p.kode in ('KEPALA_BIDANG','WAKIL_KEPALA_BIDANG') and o.kode = 'TAHFIZH')
        or (p_jenis = 'sertifikasi' and p.kode in ('DIREKTUR','WAKIL_DIREKTUR'))
     order by p.employee_id, p.plt
  )
  select e.id, e.nama_lengkap, e.niy, b.jabatan, true, true, null::uuid
    from bawaan b join employees e on e.id = b.employee_id
  union all
  select e.id, e.nama_lengkap, e.niy, coalesce(x.catatan, 'Penguji yang ditunjuk'), false, x.aktif, x.id
    from tahfizh_examiners x join employees e on e.id = x.employee_id
   where x.jenis = p_jenis and x.employee_id not in (select employee_id from bawaan)
     and e.status_keaktifan = 'aktif'
  order by 5 desc, 2
$$;

create or replace function public.hak_tahfizh()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'atur', public.boleh_atur_tahfizh(),
    'validasi', public.boleh_validasi_tahfizh(),
    'pimpinan', public.pimpinan_tahfizh(),
    'muhaffizh', exists (select 1 from public.kelompok_saya() k join student_groups g on g.id = k where g.jenis = 'halaqah'),
    'penguji_kenaikan', exists (select 1 from public.penguji_tahfizh('kenaikan') p where p.employee_id = public.saya() and p.aktif),
    'penguji_sertifikasi', exists (select 1 from public.penguji_tahfizh('sertifikasi') p where p.employee_id = public.saya() and p.aktif),
    'lihat', public.is_admin() or public.tingkat_fitur('tahfizh') >= 1 or public.tingkat_fitur('data_santri') >= 1 or public.pimpinan_tahfizh()
             or exists (select 1 from public.kelompok_saya() k join student_groups g on g.id = k where g.jenis = 'halaqah'))
$$;

create or replace function public.simpan_penguji(p_jenis text, p_employee uuid, p_aktif boolean default true, p_catatan text default null)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid;
begin
  if not public.boleh_atur_tahfizh() then raise exception 'Anda tidak berwenang mengatur penguji tahfizh.' using errcode = '42501'; end if;
  if p_jenis not in ('kenaikan','sertifikasi') then raise exception 'Jenis penguji tidak dikenal.'; end if;
  if not exists (select 1 from employees where id = p_employee and status_keaktifan = 'aktif') then
    raise exception 'Pegawai tidak ditemukan atau tidak aktif.';
  end if;
  insert into tahfizh_examiners (jenis, employee_id, aktif, catatan)
  values (p_jenis, p_employee, coalesce(p_aktif, true), nullif(trim(p_catatan), ''))
  on conflict (jenis, employee_id) do update set aktif = excluded.aktif, catatan = excluded.catatan
  returning id into v_id;
  if p_employee is distinct from public.saya() and coalesce(p_aktif, true) then
    perform public.kirim_notifikasi(p_employee,
      'Anda ditunjuk sebagai penguji ' || case p_jenis when 'kenaikan' then 'ujian kenaikan juz' else 'sertifikasi hafalan' end,
      'Daftar tunggu ujian akan tampil di menu Tahfizh.', '/tahfizh', 'BookOpenText', 'kuning');
  end if;
  return v_id;
end $$;

create or replace function public.hapus_penguji(p_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  if not public.boleh_atur_tahfizh() then raise exception 'Anda tidak berwenang mengatur penguji tahfizh.' using errcode = '42501'; end if;
  delete from tahfizh_examiners where id = p_id;
end $$;

-- ---------------------------------------------------------------------
-- 6. SIMPAN PENGATURAN
-- ---------------------------------------------------------------------
-- p: { umum?: {kkm, bobot_tajwid, bobot_itqan, batas_lonjakan_hal, rekap_sangat_memuaskan, rekap_memuaskan, catatan},
--      predikat?: [{huruf, nilai_min, nilai_maks, deskripsi_rapor, deskripsi_sertifikat, catatan_akhir}],
--      target?: [{program, tingkat, pekan_hal, bulan_hal, semester_hal, tahun_hal}],
--      bulan?: [{bulan, pekan_efektif, manual}] }   (setiap bagian boleh tidak dikirim)
create or replace function public.simpan_pengaturan_tahfizh(p_ta uuid, p jsonb)
returns void language plpgsql volatile security definer set search_path = public as $$
declare r jsonb; v_a numeric; v_b numeric; i int := 0; v_n int;
begin
  if not public.boleh_atur_tahfizh() then raise exception 'Anda tidak berwenang mengubah pengaturan tahfizh.' using errcode = '42501'; end if;
  if not exists (select 1 from academic_years where id = p_ta) then raise exception 'Tahun ajaran tidak ditemukan.'; end if;
  perform public._ta_boleh_ubah(p_ta);
  perform public.siapkan_tahfizh(p_ta);

  if p ? 'umum' then
    r := p->'umum';
    update tahfizh_settings set
      kkm = coalesce((r->>'kkm')::numeric, kkm),
      bobot_tajwid = coalesce((r->>'bobot_tajwid')::smallint, bobot_tajwid),
      bobot_itqan = coalesce((r->>'bobot_itqan')::smallint, bobot_itqan),
      batas_lonjakan_hal = coalesce((r->>'batas_lonjakan_hal')::smallint, batas_lonjakan_hal),
      rekap_sangat_memuaskan = coalesce((r->>'rekap_sangat_memuaskan')::smallint, rekap_sangat_memuaskan),
      rekap_memuaskan = coalesce((r->>'rekap_memuaskan')::smallint, rekap_memuaskan),
      catatan = case when r ? 'catatan' then nullif(trim(r->>'catatan'), '') else catatan end,
      updated_by = public.saya()
    where academic_year_id = p_ta;
  end if;

  if p ? 'predikat' then
    if jsonb_array_length(p->'predikat') < 2 then raise exception 'Predikat minimal dua rentang.'; end if;
    -- Rentang tidak boleh bertumpuk
    select count(*) into v_n from jsonb_array_elements(p->'predikat') a, jsonb_array_elements(p->'predikat') b
     where a <> b and (a->>'nilai_min')::numeric <= (b->>'nilai_maks')::numeric and (b->>'nilai_min')::numeric <= (a->>'nilai_maks')::numeric;
    if v_n > 0 then raise exception 'Rentang nilai predikat ada yang bertumpuk. Periksa batas bawah dan atasnya.'; end if;
    delete from predicate_ranges where academic_year_id = p_ta;
    for r in select * from jsonb_array_elements(p->'predikat') order by (value->>'nilai_min')::numeric desc loop
      i := i + 1;
      if coalesce(trim(r->>'huruf'), '') = '' or coalesce(trim(r->>'deskripsi_rapor'), '') = '' then
        raise exception 'Setiap predikat wajib berhuruf dan berdeskripsi rapor.';
      end if;
      insert into predicate_ranges (academic_year_id, huruf, nilai_min, nilai_maks, deskripsi_rapor, deskripsi_sertifikat, catatan_akhir, urutan)
      values (p_ta, upper(trim(r->>'huruf')), (r->>'nilai_min')::numeric, (r->>'nilai_maks')::numeric, trim(r->>'deskripsi_rapor'),
              nullif(trim(r->>'deskripsi_sertifikat'), ''), nullif(trim(r->>'catatan_akhir'), ''), i);
    end loop;
  end if;

  if p ? 'target' then
    for r in select * from jsonb_array_elements(p->'target') loop
      update tahfizh_targets set pekan_hal = (r->>'pekan_hal')::smallint, bulan_hal = (r->>'bulan_hal')::smallint,
             semester_hal = (r->>'semester_hal')::smallint, tahun_hal = (r->>'tahun_hal')::smallint
       where academic_year_id = p_ta and program = r->>'program' and tingkat = (r->>'tingkat')::smallint;
    end loop;
  end if;

  if p ? 'bulan' then
    for r in select * from jsonb_array_elements(p->'bulan') loop
      update tahfizh_months set pekan_efektif = (r->>'pekan_efektif')::smallint, manual = coalesce((r->>'manual')::boolean, true)
       where academic_year_id = p_ta and bulan = (r->>'bulan')::date;
    end loop;
    perform public.siapkan_tahfizh(p_ta);   -- bulan yang dikembalikan ke otomatis dihitung ulang
  end if;
exception
  when check_violation then
    raise exception 'Nilai pengaturan di luar batas. Bobot Tajwid + Itqan harus 100; KKM 0–100; ambang rekap "Memuaskan" tidak boleh melebihi "Sangat memuaskan".';
end $$;

-- ---------------------------------------------------------------------
-- 7. PROGRAM SANTRI DAN DATA HAFALAN AWAL
-- ---------------------------------------------------------------------
create or replace function public.atur_program_tahfizh(p_santri uuid[], p_program text)
returns int language plpgsql volatile security definer set search_path = public as $$
declare v_n int;
begin
  if not (public.boleh_atur_tahfizh() or public.boleh_validasi_tahfizh()) then
    raise exception 'Anda tidak berwenang mengubah program tahfizh santri.' using errcode = '42501';
  end if;
  if p_program not in ('reguler','takhassus') then raise exception 'Program harus Reguler atau Takhassus.'; end if;
  insert into student_tahfizh (student_id, program)
  select s.id, p_program from students s where s.id = any(p_santri)
  on conflict (student_id) do update set program = excluded.program;
  get diagnostics v_n = row_count;
  return v_n;
end $$;

-- p: {program?, juz?: [1,2,30], sabaq_hal?, sabqi_hal?, manzil_hal?, juz_sedang?, catatan?}
-- Juz berlabel "data awal" diganti seluruhnya dengan daftar baru; juz hasil ujian/sertifikasi tidak disentuh.
create or replace function public.simpan_hafalan_awal(p_santri uuid, p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v_juz smallint[]; v_tetap smallint[]; v_nama text; v_total int;
begin
  if not public.boleh_validasi_tahfizh() then
    raise exception 'Data hafalan awal hanya diisi admin ber-izin validasi tahfizh atau pimpinan Bidang Tahfizh.' using errcode = '42501';
  end if;
  select nama_lengkap into v_nama from students where id = p_santri;
  if v_nama is null then raise exception 'Santri tidak ditemukan.'; end if;

  insert into student_tahfizh (student_id) values (p_santri) on conflict do nothing;
  update student_tahfizh set
    program = coalesce(nullif(p->>'program', ''), program),
    sabaq_hal = case when p ? 'sabaq_hal' then coalesce((p->>'sabaq_hal')::smallint, 0) else sabaq_hal end,
    sabqi_hal = case when p ? 'sabqi_hal' then coalesce((p->>'sabqi_hal')::smallint, 0) else sabqi_hal end,
    manzil_hal = case when p ? 'manzil_hal' then coalesce((p->>'manzil_hal')::smallint, 0) else manzil_hal end,
    juz_sedang = case when p ? 'juz_sedang' then nullif(p->>'juz_sedang', '')::smallint else juz_sedang end,
    posisi_pada = case when p ?| array['sabaq_hal','sabqi_hal','manzil_hal'] then now() else posisi_pada end,
    posisi_sumber = case when p ?| array['sabaq_hal','sabqi_hal','manzil_hal'] then 'awal' else posisi_sumber end
  where student_id = p_santri;

  if p ? 'juz' then
    select coalesce(array_agg(distinct x::smallint order by x::smallint), '{}') into v_juz
      from jsonb_array_elements_text(p->'juz') x where x ~ '^\d+$';
    if exists (select 1 from unnest(v_juz) j where j not between 1 and 30) then raise exception 'Nomor juz harus 1–30.'; end if;
    select coalesce(array_agg(juz), '{}') into v_tetap from juz_achievements where student_id = p_santri and sumber <> 'awal';
    delete from juz_achievements where student_id = p_santri and sumber = 'awal' and juz <> all(v_juz);
    insert into juz_achievements (student_id, juz, sumber, ditetapkan_oleh, catatan)
    select p_santri, j, 'awal', public.saya(), nullif(trim(p->>'catatan'), '')
      from unnest(v_juz) j where j <> all(v_tetap)
    on conflict (student_id, juz) do nothing;
    select count(*) into v_total from juz_achievements where student_id = p_santri;
    perform public.catat_audit('ubah', 'juz_achievements', p_santri::text,
      'Data hafalan awal ' || v_nama || ': ' || coalesce(array_to_string(v_juz, ', '), '–') || ' (total resmi ' || v_total || ' juz)',
      jsonb_build_object('juz_awal', v_juz));
  end if;
  return jsonb_build_object('ok', true, 'total_resmi', (select count(*) from juz_achievements where student_id = p_santri));
exception
  when check_violation then raise exception 'Posisi hafalan harus 0–30 juz (0–600 halaman) dan juz sedang dihafal 1–30.';
end $$;

-- p_baris: [{nis, program?, juz?: [..], sabaq_hal?, sabqi_hal?, manzil_hal?, juz_sedang?}]
create or replace function public.impor_hafalan_awal(p_baris jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare r jsonb; i int := 0; v_id uuid; v_nama text; hasil jsonb := '[]'; v_h jsonb;
begin
  if not public.boleh_validasi_tahfizh() then
    raise exception 'Impor hafalan awal hanya untuk admin ber-izin validasi tahfizh atau pimpinan Bidang Tahfizh.' using errcode = '42501';
  end if;
  if jsonb_array_length(p_baris) > 700 then raise exception 'Maksimal 700 baris sekali impor.'; end if;
  for r in select * from jsonb_array_elements(p_baris) loop
    i := i + 1;
    select id, nama_lengkap into v_id, v_nama from students where nis = trim(r->>'nis');
    if v_id is null then
      hasil := hasil || jsonb_build_object('baris', i, 'ok', false, 'pesan', 'NIS ' || coalesce(r->>'nis', '') || ' belum terdaftar di Data Santri.');
      continue;
    end if;
    begin
      v_h := public.simpan_hafalan_awal(v_id, r - 'nis');
      hasil := hasil || jsonb_build_object('baris', i, 'ok', true, 'nama', v_nama, 'pesan', 'Tersimpan; total resmi ' || (v_h->>'total_resmi') || ' juz.');
    exception when others then
      hasil := hasil || jsonb_build_object('baris', i, 'ok', false, 'nama', v_nama, 'pesan', sqlerrm);
    end;
  end loop;
  return hasil;
end $$;

-- ---------------------------------------------------------------------
-- 8. DAFTAR SANTRI TAHFIZH (sesuai cakupan santri_terlihat)
-- ---------------------------------------------------------------------
create or replace function public.daftar_tahfizh(p_group uuid default null)
returns table (student_id uuid, nis text, nama text, jenis_kelamin text, jenjang text, tingkat smallint, status text,
               kelas text, halaqah_id uuid, halaqah text, program text, sabaq_hal smallint, sabqi_hal smallint, manzil_hal smallint,
               juz_sedang smallint, posisi_pada timestamptz, posisi_sumber text, juz_resmi smallint[], juz_awal smallint[], total_resmi int)
language sql stable security definer set search_path = public as $$
  with ta as (select id from academic_years where aktif),
  kel as (
    select m.student_id, g.jenis, g.id, g.nama from group_members m join student_groups g on g.id = m.group_id
      join ta on ta.id = g.academic_year_id
     where m.selesai is null and g.jenis in ('kelas','halaqah')
  )
  select s.id, s.nis, s.nama_lengkap, s.jenis_kelamin, s.jenjang, s.tingkat, s.status,
         (select k.nama from kel k where k.student_id = s.id and k.jenis = 'kelas' limit 1),
         (select k.id from kel k where k.student_id = s.id and k.jenis = 'halaqah' limit 1),
         (select k.nama from kel k where k.student_id = s.id and k.jenis = 'halaqah' limit 1),
         coalesce(t.program, 'reguler'), coalesce(t.sabaq_hal, 0::smallint), coalesce(t.sabqi_hal, 0::smallint), coalesce(t.manzil_hal, 0::smallint),
         t.juz_sedang, t.posisi_pada, t.posisi_sumber,
         coalesce((select array_agg(j.juz order by j.juz) from juz_achievements j where j.student_id = s.id), '{}'),
         coalesce((select array_agg(j.juz order by j.juz) from juz_achievements j where j.student_id = s.id and j.sumber = 'awal'), '{}'),
         (select count(*) from juz_achievements j where j.student_id = s.id)::int
  from students s left join student_tahfizh t on t.student_id = s.id
  where s.status in ('aktif','nonaktif')
    and s.id in (select public.santri_terlihat())
    and (p_group is null or exists (select 1 from kel k where k.student_id = s.id and k.id = p_group))
  order by 10 nulls last, s.nama_lengkap
$$;

-- ---------------------------------------------------------------------
-- 9. HAK EKSEKUSI DAN ISI AWAL TAHUN AJARAN AKTIF
-- ---------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array['pimpinan_tahfizh()','boleh_atur_tahfizh()','boleh_validasi_tahfizh()','hitung_pekan_efektif(uuid)',
    'penguji_tahfizh(text)','hak_tahfizh()','simpan_penguji(text,uuid,boolean,text)','hapus_penguji(uuid)',
    'simpan_pengaturan_tahfizh(uuid,jsonb)','atur_program_tahfizh(uuid[],text)','simpan_hafalan_awal(uuid,jsonb)',
    'impor_hafalan_awal(jsonb)','daftar_tahfizh(uuid)']
  loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  execute 'revoke execute on function public.siapkan_tahfizh(uuid) from public, anon, authenticated';
end $$;

-- Semua tahun ajaran yang sudah ada mendapat pengaturan tahfizh (isi awal blueprint)
do $$
declare a record;
begin
  for a in select id from academic_years order by mulai loop perform public.siapkan_tahfizh(a.id); end loop;
end $$;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 8 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select 'Tabel tahfizh (7) dengan RLS' as pemeriksaan,
       case when (select count(*) from pg_tables where schemaname = 'public' and rowsecurity and tablename in
         ('tahfizh_settings','predicate_ranges','tahfizh_targets','tahfizh_months','tahfizh_examiners','student_tahfizh','juz_achievements')) = 7
            then 'Sesuai' else 'Periksa' end as hasil
union all
select 'Izin admin atur_tahfizh dan validasi_tahfizh',
       case when (select count(*) from public.admin_capabilities where kode in ('atur_tahfizh','validasi_tahfizh')) = 2 then 'Sesuai' else 'Periksa' end
union all
select 'Pengaturan tahfizh tahun ajaran aktif (KKM 80)',
       case when exists (select 1 from public.tahfizh_settings s join public.academic_years a on a.id = s.academic_year_id and a.aktif where s.kkm = 80)
            then 'Sesuai' else 'Periksa (sudah diubah?)' end
union all
select 'Predikat A–D tahun ajaran aktif',
       case when (select count(*) from public.predicate_ranges p join public.academic_years a on a.id = p.academic_year_id and a.aktif) = 4
            then 'Sesuai' else 'Periksa (sudah diubah?)' end
union all
select 'Target 2 program × 6 tingkat (12 baris)',
       case when (select count(*) from public.tahfizh_targets t join public.academic_years a on a.id = t.academic_year_id and a.aktif) = 12
            then 'Sesuai' else 'Periksa' end
union all
select 'Bulan efektif tahun ajaran aktif terisi',
       case when (select count(*) from public.tahfizh_months m join public.academic_years a on a.id = m.academic_year_id and a.aktif) >= 10
            then 'Sesuai' else 'Periksa' end
union all
select 'Tahun ajaran baru otomatis disiapkan', case when exists (select 1 from pg_trigger where tgname = 'zz_tahfizh') then 'Sesuai' else 'Periksa' end
union all
select 'Migrasi 3700 sudah terpasang', case when exists (select 1 from pg_proc where proname = 'aktifkan_tahun_ajaran') then 'Sesuai' else 'Periksa: jalankan 3700 dulu' end;
