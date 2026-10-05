-- SIMKA PRO | supabase/migrations/20261006004600_klinik_dasar.sql | v1.0 | Fase 6 – Tahap 1 Dasar Klinik | 06/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 6 · Migrasi 46: Dasar Klinik (Blueprint Bagian 21)
--   * KLINIK PUTRA DAN PUTRI DIPISAH (keputusan 06/10/2026): santri L → Klinik Putra, P → Klinik Putri.
--     Petugas ditugaskan ke satu atau kedua klinik (clinic_staff); isi awal dari pemegang jabatan Petugas
--     kesehatan (MEDIS) menurut jenis kelaminnya, dapat diubah di Klinik → Ketentuan.
--   * clinic_cases     : satu KASUS per episode sakit santri (menunggu → ditangani → selesai/batal);
--                        paling banyak satu kasus terbuka per santri. Rujukan berikutnya menempel ke kasus terbuka.
--   * clinic_referrals : setiap rujukan masuk (pengasuh, absensi, lapor, petugas) dengan batas waktu periksa.
--   * clinic_visits    : setiap pemeriksaan (keluhan, pemeriksaan, diagnosis, tindakan, obat/terapi berupa CATATAN,
--                        tindak lanjut, jadwal kontrol). RAHASIA: hanya petugas klinik terkait, pengelola klinik,
--                        pimpinan Kesantrian (dan Direktur/Wadir), superadmin. Tidak masuk audit log.
--   * clinic_followups : jejak perjalanan kasus (rujukan, pemeriksaan, status, batal, selesai).
--   * Pengasuh/perujuk hanya melihat RINGKASAN (tanggal, keluhan umum, status) santri yang terlihat olehnya.
--   * Obat tidak dirinci (tanpa daftar dan stok): cukup catatan obat/terapi pada pemeriksaan.
--   * Pengaturan klinik: institution_settings kunci 'klinik' (jam layanan, batas waktu rujukan, hari kontrol).
--   * Izin admin baru: kelola_klinik. Hak fitur 'klinik' tingkat 3 setara pengelola.
--   * Fungsi: hak_klinik, pengaturan_klinik, simpan_pengaturan_klinik, simpan_petugas_klinik, hapus_petugas_klinik,
--             daftar_petugas_klinik, calon_petugas_klinik, buat_rujukan, simpan_pemeriksaan, batalkan_kasus_klinik, selesaikan_kasus_klinik, daftar_klinik,
--             detail_kasus_klinik, cari_santri_klinik.
-- Jalankan SETELAH migrasi 4500. Aman dijalankan ulang.
-- =====================================================================

insert into public.admin_capabilities (kode, nama, urutan) values
  ('kelola_klinik', 'Mengelola klinik: ketentuan, petugas, seluruh catatan pemeriksaan (Fase 6)', 30)
on conflict (kode) do nothing;

-- ---------------------------------------------------------------------
-- 1. TABEL
-- ---------------------------------------------------------------------
create table if not exists public.clinic_staff (
  id          uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees(id) on delete cascade,
  klinik      text not null check (klinik in ('putra','putri')),
  aktif       boolean not null default true,
  catatan     text,
  created_at  timestamptz not null default now(),
  unique (employee_id, klinik)
);

create table if not exists public.clinic_cases (
  id             uuid primary key default gen_random_uuid(),
  student_id     uuid not null references public.students(id) on delete cascade,
  klinik         text not null check (klinik in ('putra','putri')),
  status         text not null default 'menunggu' check (status in ('menunggu','ditangani','selesai','batal')),
  tindak_lanjut  text check (tindak_lanjut in ('kembali','istirahat','rawat','rujuk','pulang')),
  keluhan        text not null,                 -- keluhan umum (ringkasan yang boleh dilihat pengasuh dan wali)
  sumber         text not null check (sumber in ('pengasuh','absensi','lapor','datang_sendiri','petugas')),
  dibuka_pada    timestamptz not null default now(),
  dibuka_oleh    uuid references public.employees(id) on delete set null,
  sakit_mulai    date,                          -- status Sakit otomatis berlaku sejak (Tahap 2)
  kontrol_pada   timestamptz,
  selesai_pada   timestamptz,
  selesai_oleh   uuid references public.employees(id) on delete set null,
  hasil          text check (hasil in ('sembuh','kembali','batal')),
  catatan_selesai text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create unique index if not exists clinic_cases_satu_terbuka on public.clinic_cases (student_id) where status in ('menunggu','ditangani');
create index if not exists clinic_cases_status_idx on public.clinic_cases (klinik, status);
create index if not exists clinic_cases_tgl_idx on public.clinic_cases (dibuka_pada);

create table if not exists public.clinic_referrals (
  id             uuid primary key default gen_random_uuid(),
  case_id        uuid not null references public.clinic_cases(id) on delete cascade,
  student_id     uuid not null references public.students(id) on delete cascade,
  sumber         text not null check (sumber in ('pengasuh','absensi','lapor','datang_sendiri','petugas')),
  keluhan        text not null,
  waktu_periksa  text not null default 'hari_ini' check (waktu_periksa in ('hari_ini','besok')),
  batas_waktu    timestamptz,
  dirujuk_oleh   uuid references public.employees(id) on delete set null,
  dirujuk_pada   timestamptz not null default now(),
  ref_jenis      text,                          -- 'absensi' (sesi), 'lapor' (laporan) — Tahap 2 dan 4
  ref_id         uuid,
  catatan        text
);
create index if not exists clinic_referrals_case_idx on public.clinic_referrals (case_id);

create table if not exists public.clinic_visits (
  id             uuid primary key default gen_random_uuid(),
  case_id        uuid not null references public.clinic_cases(id) on delete cascade,
  student_id     uuid not null references public.students(id) on delete cascade,
  petugas_id     uuid references public.employees(id) on delete set null,
  waktu          timestamptz not null default now(),
  jenis          text not null default 'pemeriksaan' check (jenis in ('pemeriksaan','kontrol')),
  keluhan        text,
  pemeriksaan    text,                          -- tanda vital dan temuan (suhu, tensi, dll.)
  diagnosis      text,
  tindakan       text,
  obat           text,                          -- catatan obat/terapi (tanpa daftar dan stok)
  tindak_lanjut  text not null check (tindak_lanjut in ('kembali','istirahat','rawat','rujuk','pulang')),
  rujuk_ke       text,
  kontrol_pada   timestamptz,
  catatan        text,
  created_at     timestamptz not null default now()
);
create index if not exists clinic_visits_case_idx on public.clinic_visits (case_id, waktu);

create table if not exists public.clinic_followups (
  id      uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.clinic_cases(id) on delete cascade,
  jenis   text not null check (jenis in ('rujukan','pemeriksaan','status','batal','selesai','catatan')),
  isi     text,
  oleh    uuid references public.employees(id) on delete set null,
  pada    timestamptz not null default now()
);
create index if not exists clinic_followups_case_idx on public.clinic_followups (case_id, pada);

drop trigger if exists aa_updated on public.clinic_cases;
create trigger aa_updated before update on public.clinic_cases for each row execute function public.tg_updated_at();
-- Audit hanya untuk penugasan petugas dan kasus (bukan catatan pemeriksaan yang bersifat rahasia)
drop trigger if exists zz_audit on public.clinic_staff;
create trigger zz_audit after insert or update or delete on public.clinic_staff for each row execute function public.tg_audit();

-- Isi awal petugas: pemegang jabatan MEDIS aktif menurut jenis kelamin (sekali saja; tidak menimpa pengaturan)
insert into public.clinic_staff (employee_id, klinik, catatan)
select distinct e.id, case when e.jenis_kelamin = 'P' then 'putri' else 'putra' end, 'Isi awal dari jabatan Petugas kesehatan'
  from public.employees e
  join public.employee_functions ef on ef.employee_id = e.id
  join public.functional_positions fp on fp.id = ef.functional_position_id and fp.kode = 'MEDIS'
 where e.status_keaktifan = 'aktif'
   and not exists (select 1 from public.clinic_staff)
on conflict (employee_id, klinik) do nothing;

-- ---------------------------------------------------------------------
-- 2. HAK AKSES
-- ---------------------------------------------------------------------
create or replace function public.boleh_kelola_klinik()
returns boolean language sql stable security definer set search_path = public as $$
  select public.admin_boleh('kelola_klinik') or public.tingkat_fitur('klinik') >= 3
$$;

/** Pimpinan Bidang Kesantrian/Unit Klinik (beserta Direktur, Wadir, Yayasan, dan Plt). */
create or replace function public.pimpinan_kesantrian()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.unit_pimpinan_saya() u join org_units o on o.id = u where o.kode in ('KESANTRIAN','KLINIK'))
      or exists (select 1 from acting_assignments a join org_units o on o.id = a.org_unit_id
                  where a.employee_id = public.saya() and o.kode in ('KESANTRIAN','KLINIK')
                    and public.hari_ini() between a.mulai and a.sampai)
$$;

create or replace function public.klinik_petugas_saya()
returns setof text language sql stable security definer set search_path = public as $$
  select s.klinik from clinic_staff s join employees e on e.id = s.employee_id
   where s.aktif and e.id = public.saya() and e.status_keaktifan = 'aktif'
$$;

/** Boleh membaca catatan pemeriksaan (rahasia) untuk klinik tertentu. */
create or replace function public.boleh_detail_klinik(p_klinik text)
returns boolean language sql stable security definer set search_path = public as $$
  select public.boleh_kelola_klinik() or public.pimpinan_kesantrian()
      or p_klinik in (select public.klinik_petugas_saya())
$$;

/** Boleh memeriksa (menulis catatan pemeriksaan) di klinik tertentu: petugas klinik itu atau pengelola. */
create or replace function public.boleh_periksa_klinik(p_klinik text)
returns boolean language sql stable security definer set search_path = public as $$
  select public.boleh_kelola_klinik() or p_klinik in (select public.klinik_petugas_saya())
$$;

create or replace function public.hak_klinik()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'atur', public.boleh_kelola_klinik(),
    'pimpinan', public.pimpinan_kesantrian(),
    'petugas', coalesce((select jsonb_agg(k order by k) from public.klinik_petugas_saya() k), '[]'::jsonb),
    'rujuk', exists (select 1 from public.santri_terlihat() limit 1) or public.boleh_kelola_klinik()
             or exists (select 1 from public.klinik_petugas_saya()),
    'lihat', public.is_admin() or public.boleh_kelola_klinik() or public.pimpinan_kesantrian()
             or exists (select 1 from public.klinik_petugas_saya()) or exists (select 1 from public.santri_terlihat() limit 1))
$$;

alter table public.clinic_staff enable row level security;
alter table public.clinic_cases enable row level security;
alter table public.clinic_referrals enable row level security;
alter table public.clinic_visits enable row level security;
alter table public.clinic_followups enable row level security;

drop policy if exists baca on public.clinic_staff;
create policy baca on public.clinic_staff for select to authenticated using (true);
drop policy if exists baca on public.clinic_cases;
create policy baca on public.clinic_cases for select to authenticated
  using (public.boleh_detail_klinik(klinik) or student_id in (select public.santri_terlihat()));
drop policy if exists baca on public.clinic_referrals;
create policy baca on public.clinic_referrals for select to authenticated
  using (exists (select 1 from clinic_cases c where c.id = case_id
                  and (public.boleh_detail_klinik(c.klinik) or c.student_id in (select public.santri_terlihat()))));
drop policy if exists baca on public.clinic_visits;
create policy baca on public.clinic_visits for select to authenticated
  using (exists (select 1 from clinic_cases c where c.id = case_id and public.boleh_detail_klinik(c.klinik)));
drop policy if exists baca on public.clinic_followups;
create policy baca on public.clinic_followups for select to authenticated
  using (exists (select 1 from clinic_cases c where c.id = case_id and public.boleh_detail_klinik(c.klinik)));

-- ---------------------------------------------------------------------
-- 3. PENGATURAN KLINIK
-- ---------------------------------------------------------------------
create or replace function public.pengaturan_klinik()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
      'jam_layanan', jsonb_build_array(jsonb_build_object('mulai','07:30','selesai','11:00'),
                                       jsonb_build_object('mulai','16:00','selesai','19:00')),
      'batas_hari_ini_menit', 120,
      'batas_besok_jam', '11:00',
      'kontrol_bawaan_hari', 1,
      'kop', 'pondok')
    || coalesce((select nilai from institution_settings where kunci = 'klinik'), '{}'::jsonb)
$$;

create or replace function public.simpan_pengaturan_klinik(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v jsonb := '{}'::jsonb; j jsonb; m int;
begin
  if not public.boleh_kelola_klinik() then raise exception 'Anda tidak berwenang mengubah ketentuan klinik.' using errcode = '42501'; end if;
  if p ? 'jam_layanan' then
    if jsonb_typeof(p->'jam_layanan') <> 'array' or jsonb_array_length(p->'jam_layanan') = 0 then
      raise exception 'Isi paling sedikit satu jam layanan.';
    end if;
    for j in select * from jsonb_array_elements(p->'jam_layanan') loop
      if coalesce(j->>'mulai','') !~ '^\d{2}:\d{2}$' or coalesce(j->>'selesai','') !~ '^\d{2}:\d{2}$'
         or (j->>'selesai')::time <= (j->>'mulai')::time then
        raise exception 'Jam layanan % – % tidak sah (jam selesai harus setelah jam mulai).', j->>'mulai', j->>'selesai';
      end if;
    end loop;
    v := v || jsonb_build_object('jam_layanan', (select jsonb_agg(x order by x->>'mulai') from jsonb_array_elements(p->'jam_layanan') x));
  end if;
  if p ? 'batas_hari_ini_menit' then
    m := (p->>'batas_hari_ini_menit')::int;
    if m is null or m < 15 or m > 1440 then raise exception 'Batas waktu rujukan hari ini harus 15–1440 menit.'; end if;
    v := v || jsonb_build_object('batas_hari_ini_menit', m);
  end if;
  if p ? 'batas_besok_jam' then
    if coalesce(p->>'batas_besok_jam','') !~ '^\d{2}:\d{2}$' then raise exception 'Jam batas rujukan besok tidak sah.'; end if;
    v := v || jsonb_build_object('batas_besok_jam', p->>'batas_besok_jam');
  end if;
  if p ? 'kontrol_bawaan_hari' then
    m := (p->>'kontrol_bawaan_hari')::int;
    if m is null or m < 0 or m > 30 then raise exception 'Jadwal kontrol bawaan harus 0–30 hari.'; end if;
    v := v || jsonb_build_object('kontrol_bawaan_hari', m);
  end if;
  if p ? 'kop' then
    if p->>'kop' not in ('pondok','wustha','sma','yayasan') then raise exception 'Kop surat tidak dikenal.'; end if;
    v := v || jsonb_build_object('kop', p->>'kop');
  end if;
  insert into institution_settings (kunci, nilai, updated_by) values ('klinik', v, public.saya())
  on conflict (kunci) do update set nilai = institution_settings.nilai || excluded.nilai, updated_at = now(), updated_by = excluded.updated_by;
  return public.pengaturan_klinik();
end $$;

create or replace function public.simpan_petugas_klinik(p_employee uuid, p_klinik text, p_aktif boolean default true, p_catatan text default null)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid; v_nama text;
begin
  if not public.boleh_kelola_klinik() then raise exception 'Anda tidak berwenang mengatur petugas klinik.' using errcode = '42501'; end if;
  if p_klinik not in ('putra','putri') then raise exception 'Klinik harus Putra atau Putri.'; end if;
  select nama_lengkap into v_nama from employees where id = p_employee and status_keaktifan = 'aktif';
  if v_nama is null then raise exception 'Pegawai tidak ditemukan atau tidak aktif.'; end if;
  insert into clinic_staff (employee_id, klinik, aktif, catatan)
  values (p_employee, p_klinik, coalesce(p_aktif, true), nullif(trim(p_catatan), ''))
  on conflict (employee_id, klinik) do update set aktif = excluded.aktif, catatan = excluded.catatan
  returning id into v_id;
  if coalesce(p_aktif, true) then
    perform public.kirim_notifikasi(p_employee, 'Anda ditugaskan di Klinik ' || initcap(p_klinik),
      'Rujukan santri ' || case when p_klinik = 'putra' then 'putra' else 'putri' end || ' akan masuk ke antrean Anda.',
      '/klinik/antrean', 'FirstAidKit', 'merah');
  end if;
  return v_id;
end $$;

create or replace function public.hapus_petugas_klinik(p_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  if not public.boleh_kelola_klinik() then raise exception 'Anda tidak berwenang mengatur petugas klinik.' using errcode = '42501'; end if;
  delete from clinic_staff where id = p_id;
end $$;

/** Daftar petugas klinik (nama dan nomor HP untuk WA) — terbaca oleh semua pegawai yang masuk. */
create or replace function public.daftar_petugas_klinik()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'employee_id', e.id, 'nama', e.nama_lengkap, 'niy', e.niy,
           'jenis_kelamin', e.jenis_kelamin, 'no_hp', e.no_hp, 'klinik', s.klinik, 'aktif', s.aktif, 'catatan', s.catatan,
           'punya_akun', e.status_akun = 'aktif') order by s.klinik, s.aktif desc, e.nama_lengkap), '[]'::jsonb)
    from clinic_staff s join employees e on e.id = s.employee_id
   where public.saya() is not null and e.status_keaktifan = 'aktif'
$$;

/** Calon petugas (pegawai aktif) untuk pengelola klinik. */
create or replace function public.calon_petugas_klinik()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public.boleh_kelola_klinik() then raise exception 'Anda tidak berwenang mengatur petugas klinik.' using errcode = '42501'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'nama', e.nama_lengkap, 'niy', e.niy, 'jenis_kelamin', e.jenis_kelamin,
           'medis', exists (select 1 from employee_functions ef join functional_positions fp on fp.id = ef.functional_position_id
                             where ef.employee_id = e.id and fp.kode = 'MEDIS')) order by e.nama_lengkap)
    from employees e where e.status_keaktifan = 'aktif'), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- 4. RUJUKAN
-- ---------------------------------------------------------------------
/** Nama kelompok aktif santri (kelas/kamar/halaqah) pada tahun ajaran aktif. */
create or replace function public._kelompok_santri(p_santri uuid, p_jenis text)
returns text language sql stable security definer set search_path = public as $$
  select string_agg(g.nama, ', ' order by g.nama)
    from group_members m join student_groups g on g.id = m.group_id
    join academic_years a on a.id = g.academic_year_id and a.aktif
   where m.student_id = p_santri and m.jenis = p_jenis and m.selesai is null
$$;

/** Batas waktu pemeriksaan: "hari ini" = batas_hari_ini_menit dihitung dari waktu rujukan (atau dari jam layanan berikutnya
    bila dirujuk di luar jam layanan); "besok" = jam batas_besok_jam esok hari. Waktu WITA. */
create or replace function public._batas_rujukan(p_pada timestamptz, p_kapan text)
returns timestamptz language plpgsql stable security definer set search_path = public as $$
declare s jsonb := public.pengaturan_klinik(); t timestamp := (p_pada at time zone 'Asia/Makassar');
        d date := t::date; mulai timestamp; j jsonb; menit int := (s->>'batas_hari_ini_menit')::int;
begin
  if p_kapan = 'besok' then
    return ((d + 1) + (s->>'batas_besok_jam')::time) at time zone 'Asia/Makassar';
  end if;
  for j in select * from jsonb_array_elements(s->'jam_layanan') order by 1 loop
    if t < d + (j->>'selesai')::time then
      mulai := greatest(t, d + (j->>'mulai')::time);
      return (mulai + make_interval(mins => menit)) at time zone 'Asia/Makassar';
    end if;
  end loop;
  -- Di luar semua jam layanan hari ini: dihitung dari jam layanan pertama esok hari
  mulai := (d + 1) + ((s->'jam_layanan'->0)->>'mulai')::time;
  return (mulai + make_interval(mins => menit)) at time zone 'Asia/Makassar';
end $$;

/** Pembuat rujukan internal (dipakai juga oleh absensi dan lapor). Tidak memeriksa hak; panggil dari fungsi yang memeriksa. */
create or replace function public._rujukan_internal(p_santri uuid, p_keluhan text, p_kapan text, p_sumber text,
  p_oleh uuid, p_ref_jenis text default null, p_ref_id uuid default null, p_catatan text default null)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v_s record; v_kasus uuid; v_baru boolean := false; v_batas timestamptz; v_klinik text; n int; v_perujuk text;
begin
  select id, nama_lengkap, jenis_kelamin, status into v_s from students where id = p_santri;
  if v_s.id is null then raise exception 'Santri tidak ditemukan.'; end if;
  if v_s.status <> 'aktif' then raise exception '% tidak berstatus aktif.', v_s.nama_lengkap; end if;
  if length(trim(coalesce(p_keluhan, ''))) < 3 then raise exception 'Tuliskan keluhan singkat (minimal 3 huruf).'; end if;
  if coalesce(p_kapan, 'hari_ini') not in ('hari_ini','besok') then raise exception 'Waktu periksa harus hari ini atau besok.'; end if;
  v_klinik := case when v_s.jenis_kelamin = 'P' then 'putri' else 'putra' end;
  v_batas := public._batas_rujukan(now(), coalesce(p_kapan, 'hari_ini'));

  select id into v_kasus from clinic_cases where student_id = p_santri and status in ('menunggu','ditangani') for update;
  if v_kasus is null then
    insert into clinic_cases (student_id, klinik, keluhan, sumber, dibuka_oleh)
    values (p_santri, v_klinik, trim(p_keluhan), p_sumber, p_oleh) returning id into v_kasus;
    v_baru := true;
  end if;
  insert into clinic_referrals (case_id, student_id, sumber, keluhan, waktu_periksa, batas_waktu, dirujuk_oleh, ref_jenis, ref_id, catatan)
  values (v_kasus, p_santri, p_sumber, trim(p_keluhan), coalesce(p_kapan, 'hari_ini'), v_batas, p_oleh, p_ref_jenis, p_ref_id, nullif(trim(p_catatan), ''));
  select nama_lengkap into v_perujuk from employees where id = p_oleh;
  insert into clinic_followups (case_id, jenis, isi, oleh)
  values (v_kasus, 'rujukan', format('Dirujuk%s: %s (periksa %s)', coalesce(' oleh ' || v_perujuk, ''), trim(p_keluhan),
          case when p_kapan = 'besok' then 'besok' else 'hari ini' end), p_oleh);

  -- Notifikasi ke petugas klinik terkait; bila belum ada petugas, ke pengelola klinik
  if p_sumber <> 'datang_sendiri' then
    insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
    select s.employee_id, 'Rujukan klinik: ' || v_s.nama_lengkap,
           trim(p_keluhan) || ' · periksa ' || case when p_kapan = 'besok' then 'besok' else 'hari ini' end
             || coalesce(' · dari ' || v_perujuk, ''),
           '/klinik/antrean', 'FirstAidKit', 'merah'
      from clinic_staff s join employees e on e.id = s.employee_id
     where s.klinik = v_klinik and s.aktif and e.status_akun = 'aktif' and e.id is distinct from p_oleh;
    get diagnostics n = row_count;
    if n = 0 and not exists (select 1 from clinic_staff s where s.klinik = v_klinik and s.aktif and s.employee_id = p_oleh) then
      perform public.notifikasi_admin('kelola_klinik', 'Rujukan klinik: ' || v_s.nama_lengkap,
        'Belum ada petugas aktif di Klinik ' || initcap(v_klinik) || '. ' || trim(p_keluhan), '/klinik/antrean', 'FirstAidKit', 'merah');
    end if;
  end if;
  return jsonb_build_object('case_id', v_kasus, 'baru', v_baru, 'klinik', v_klinik, 'batas_waktu', v_batas);
end $$;

/** Rujukan oleh pengasuh/pegawai yang dapat melihat santri, atau oleh petugas/pengelola klinik. */
create or replace function public.buat_rujukan(p_santri uuid, p_keluhan text, p_kapan text default 'hari_ini', p_catatan text default null)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v_klinik text; v_sumber text := 'pengasuh';
begin
  if public.saya() is null then raise exception 'Sesi tidak ditemukan. Silakan masuk kembali.' using errcode = '42501'; end if;
  select case when jenis_kelamin = 'P' then 'putri' else 'putra' end into v_klinik from students where id = p_santri;
  if v_klinik is null then raise exception 'Santri tidak ditemukan.'; end if;
  if public.boleh_periksa_klinik(v_klinik) then v_sumber := 'petugas';
  elsif not (p_santri in (select public.santri_terlihat()) or public.boleh_detail_klinik(v_klinik)) then
    raise exception 'Anda hanya dapat merujuk santri asuhan Anda.' using errcode = '42501';
  end if;
  return public._rujukan_internal(p_santri, p_keluhan, p_kapan, v_sumber, public.saya(), null, null, p_catatan);
end $$;

-- ---------------------------------------------------------------------
-- 5. PEMERIKSAAN DAN PENYELESAIAN
-- ---------------------------------------------------------------------
/** Simpan pemeriksaan. p: { case_id | student_id (pasien datang sendiri), keluhan, pemeriksaan, diagnosis, tindakan, obat,
    tindak_lanjut, rujuk_ke, kontrol_pada, catatan }. Tindak lanjut "kembali" menutup kasus (kembali beraktivitas). */
create or replace function public.simpan_pemeriksaan(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v_kasus clinic_cases%rowtype; v_s record; v_tl text := p->>'tindak_lanjut'; v_jenis text; v_id uuid;
        v_kontrol timestamptz; v_label text; v_perujuk uuid;
begin
  if public.saya() is null then raise exception 'Sesi tidak ditemukan. Silakan masuk kembali.' using errcode = '42501'; end if;
  if v_tl is null or v_tl not in ('kembali','istirahat','rawat','rujuk','pulang') then raise exception 'Pilih tindak lanjut.'; end if;

  if nullif(p->>'case_id', '') is not null then
    select * into v_kasus from clinic_cases where id = (p->>'case_id')::uuid for update;
    if v_kasus.id is null then raise exception 'Kasus tidak ditemukan.'; end if;
    if v_kasus.status not in ('menunggu','ditangani') then raise exception 'Kasus ini sudah selesai atau dibatalkan.'; end if;
  else
    -- Pasien datang sendiri: pakai kasus terbuka bila ada, selain itu buat kasus baru
    select id, nama_lengkap, jenis_kelamin, status into v_s from students where id = nullif(p->>'student_id', '')::uuid;
    if v_s.id is null then raise exception 'Pilih santri.'; end if;
    select * into v_kasus from clinic_cases where student_id = v_s.id and status in ('menunggu','ditangani') for update;
    if v_kasus.id is null then
      if not public.boleh_periksa_klinik(case when v_s.jenis_kelamin = 'P' then 'putri' else 'putra' end) then
        raise exception 'Santri % dilayani Klinik %; Anda bukan petugasnya.', v_s.nama_lengkap,
          case when v_s.jenis_kelamin = 'P' then 'Putri' else 'Putra' end using errcode = '42501';
      end if;
      perform public._rujukan_internal(v_s.id, coalesce(nullif(trim(p->>'keluhan'), ''), 'Datang ke klinik'), 'hari_ini',
                                       'datang_sendiri', public.saya());
      select * into v_kasus from clinic_cases where student_id = v_s.id and status = 'menunggu' for update;
    end if;
  end if;
  if not public.boleh_periksa_klinik(v_kasus.klinik) then
    raise exception 'Hanya petugas Klinik % atau pengelola klinik yang dapat mencatat pemeriksaan.', initcap(v_kasus.klinik) using errcode = '42501';
  end if;
  if v_tl = 'rujuk' and length(trim(coalesce(p->>'rujuk_ke', ''))) < 3 then raise exception 'Tuliskan tujuan rujukan (rumah sakit/puskesmas).'; end if;
  if nullif(p->>'kontrol_pada', '') is not null then
    v_kontrol := (p->>'kontrol_pada')::timestamptz;
    if v_kontrol < now() - interval '1 hour' then raise exception 'Jadwal kontrol tidak boleh di masa lalu.'; end if;
  end if;

  v_jenis := case when exists (select 1 from clinic_visits where case_id = v_kasus.id) then 'kontrol' else 'pemeriksaan' end;
  insert into clinic_visits (case_id, student_id, petugas_id, jenis, keluhan, pemeriksaan, diagnosis, tindakan, obat,
                             tindak_lanjut, rujuk_ke, kontrol_pada, catatan)
  values (v_kasus.id, v_kasus.student_id, public.saya(), v_jenis, nullif(trim(p->>'keluhan'), ''), nullif(trim(p->>'pemeriksaan'), ''),
          nullif(trim(p->>'diagnosis'), ''), nullif(trim(p->>'tindakan'), ''), nullif(trim(p->>'obat'), ''), v_tl,
          case when v_tl = 'rujuk' then nullif(trim(p->>'rujuk_ke'), '') end, case when v_tl <> 'kembali' then v_kontrol end,
          nullif(trim(p->>'catatan'), ''))
  returning id into v_id;

  v_label := case v_tl when 'kembali' then 'Kembali beraktivitas' when 'istirahat' then 'Istirahat di kamar'
               when 'rawat' then 'Rawat di klinik' when 'rujuk' then 'Dirujuk ke ' || trim(p->>'rujuk_ke') else 'Dipulangkan' end;
  if v_tl = 'kembali' then
    update clinic_cases set status = 'selesai', tindak_lanjut = v_tl, kontrol_pada = null, selesai_pada = now(),
           selesai_oleh = public.saya(), hasil = 'kembali' where id = v_kasus.id;
  else
    update clinic_cases set status = 'ditangani', tindak_lanjut = v_tl, kontrol_pada = v_kontrol,
           sakit_mulai = coalesce(sakit_mulai, public.hari_ini()) where id = v_kasus.id;
  end if;
  insert into clinic_followups (case_id, jenis, isi, oleh)
  values (v_kasus.id, 'pemeriksaan', initcap(v_jenis) || ': ' || v_label
          || coalesce(' · kontrol ' || to_char(v_kontrol at time zone 'Asia/Makassar', 'DD/MM/YYYY HH24.MI'), ''), public.saya());

  -- Ringkasan hasil ke perujuk (tanpa catatan medis)
  insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
  select distinct r.dirujuk_oleh, 'Hasil klinik: ' || st.nama_lengkap, v_label, '/klinik/rujukan', 'FirstAidKit', 'biru'
    from clinic_referrals r join students st on st.id = r.student_id
   where r.case_id = v_kasus.id and r.dirujuk_oleh is not null and r.dirujuk_oleh <> public.saya()
     and r.sumber in ('pengasuh','absensi','lapor');
  return jsonb_build_object('id', v_id, 'case_id', v_kasus.id, 'status', case when v_tl = 'kembali' then 'selesai' else 'ditangani' end);
end $$;

/** Batalkan kasus yang belum diperiksa (salah rujuk, santri tidak jadi sakit). Perujuk boleh membatalkan rujukannya sendiri. */
create or replace function public.batalkan_kasus_klinik(p_case uuid, p_alasan text)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v clinic_cases%rowtype;
begin
  select * into v from clinic_cases where id = p_case for update;
  if v.id is null then raise exception 'Kasus tidak ditemukan.'; end if;
  if v.status <> 'menunggu' then raise exception 'Hanya rujukan yang belum diperiksa yang dapat dibatalkan.'; end if;
  if not (public.boleh_periksa_klinik(v.klinik)
          or exists (select 1 from clinic_referrals r where r.case_id = p_case and r.dirujuk_oleh = public.saya())) then
    raise exception 'Anda tidak berwenang membatalkan rujukan ini.' using errcode = '42501';
  end if;
  if length(trim(coalesce(p_alasan, ''))) < 5 then raise exception 'Tuliskan alasan pembatalan (minimal 5 huruf).'; end if;
  update clinic_cases set status = 'batal', hasil = 'batal', selesai_pada = now(), selesai_oleh = public.saya(),
         catatan_selesai = trim(p_alasan) where id = p_case;
  insert into clinic_followups (case_id, jenis, isi, oleh) values (p_case, 'batal', 'Dibatalkan: ' || trim(p_alasan), public.saya());
end $$;

/** Nyatakan sembuh (menutup kasus yang sedang ditangani). */
create or replace function public.selesaikan_kasus_klinik(p_case uuid, p_catatan text default null)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v clinic_cases%rowtype; v_nama text;
begin
  select * into v from clinic_cases where id = p_case for update;
  if v.id is null then raise exception 'Kasus tidak ditemukan.'; end if;
  if v.status <> 'ditangani' then raise exception 'Kasus ini belum diperiksa atau sudah selesai.'; end if;
  if not public.boleh_periksa_klinik(v.klinik) then raise exception 'Hanya petugas klinik yang dapat menyatakan sembuh.' using errcode = '42501'; end if;
  update clinic_cases set status = 'selesai', hasil = 'sembuh', kontrol_pada = null, selesai_pada = now(),
         selesai_oleh = public.saya(), catatan_selesai = nullif(trim(p_catatan), '') where id = p_case;
  insert into clinic_followups (case_id, jenis, isi, oleh)
  values (p_case, 'selesai', 'Dinyatakan sembuh' || coalesce(': ' || nullif(trim(p_catatan), ''), ''), public.saya());
  select nama_lengkap into v_nama from students where id = v.student_id;
  insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
  select distinct r.dirujuk_oleh, 'Santri sembuh: ' || v_nama, 'Dinyatakan sembuh oleh klinik.',
         '/klinik/rujukan', 'FirstAidKit', 'hijau'
    from clinic_referrals r where r.case_id = p_case and r.dirujuk_oleh is not null and r.dirujuk_oleh <> public.saya()
     and r.sumber in ('pengasuh','absensi','lapor');
end $$;

-- ---------------------------------------------------------------------
-- 6. BACA
-- ---------------------------------------------------------------------
/** Daftar kasus. p_cakupan: 'antrean' (menunggu), 'dirawat' (ditangani), 'riwayat' (rentang tanggal, semua status),
    'rujukan_saya' (kasus yang saya rujuk / santri asuhan saya). Kolom rahasia hanya untuk yang berhak. */
create or replace function public.daftar_klinik(p_cakupan text, p_mulai date default null, p_selesai date default null, p_klinik text default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_mulai date := coalesce(p_mulai, public.hari_ini() - 30); v_selesai date := coalesce(p_selesai, public.hari_ini());
begin
  if public.saya() is null then return '[]'::jsonb; end if;
  return coalesce((
    select jsonb_agg(x order by x->>'urut', x->>'dibuka_pada' desc)
    from (
      select jsonb_build_object(
        'id', c.id, 'student_id', c.student_id, 'nama', s.nama_lengkap, 'nis', s.nis, 'jenis_kelamin', s.jenis_kelamin,
        'tingkat', s.tingkat, 'jenjang', s.jenjang,
        'kelas', public._kelompok_santri(s.id, 'kelas'), 'kamar', public._kelompok_santri(s.id, 'kamar'),
        'klinik', c.klinik, 'status', c.status, 'tindak_lanjut', c.tindak_lanjut, 'keluhan', c.keluhan, 'sumber', c.sumber,
        'dibuka_pada', c.dibuka_pada, 'kontrol_pada', c.kontrol_pada, 'selesai_pada', c.selesai_pada, 'hasil', c.hasil,
        'sakit_mulai', c.sakit_mulai,
        'batas_waktu', r.batas_waktu, 'waktu_periksa', r.waktu_periksa, 'perujuk', pr.nama_lengkap,
        'jumlah_rujukan', (select count(*) from clinic_referrals rr where rr.case_id = c.id),
        'lewat_batas', c.status = 'menunggu' and r.batas_waktu < now(),
        'detail', d.boleh,
        'boleh_periksa', public.boleh_periksa_klinik(c.klinik),
        'boleh_batal', c.status = 'menunggu' and (public.boleh_periksa_klinik(c.klinik)
                         or exists (select 1 from clinic_referrals rr where rr.case_id = c.id and rr.dirujuk_oleh = public.saya())),
        'pemeriksaan_terakhir', case when d.boleh then (
            select jsonb_build_object('waktu', v.waktu, 'diagnosis', v.diagnosis, 'tindakan', v.tindakan, 'obat', v.obat,
                                      'petugas', pe.nama_lengkap, 'rujuk_ke', v.rujuk_ke)
              from clinic_visits v left join employees pe on pe.id = v.petugas_id
             where v.case_id = c.id order by v.waktu desc limit 1) end,
        'urut', case when c.status = 'menunggu' and r.batas_waktu < now() then '0'
                     when c.status = 'menunggu' then '1' else '2' end) as x
      from clinic_cases c
      join students s on s.id = c.student_id
      left join lateral (select * from clinic_referrals rr where rr.case_id = c.id order by rr.dirujuk_pada limit 1) r on true
      left join employees pr on pr.id = r.dirujuk_oleh
      cross join lateral (select public.boleh_detail_klinik(c.klinik) as boleh) d
      where (p_klinik is null or c.klinik = p_klinik)
        and case p_cakupan
              when 'antrean' then c.status = 'menunggu' and d.boleh
              when 'dirawat' then c.status = 'ditangani' and d.boleh
              when 'riwayat' then d.boleh and (c.dibuka_pada at time zone 'Asia/Makassar')::date between v_mulai and v_selesai
              when 'rujukan_saya' then (c.status in ('menunggu','ditangani')
                                         or (c.dibuka_pada at time zone 'Asia/Makassar')::date between v_mulai and v_selesai)
                                       and (exists (select 1 from clinic_referrals rr where rr.case_id = c.id and rr.dirujuk_oleh = public.saya())
                                            or c.student_id in (select public.santri_terlihat()))
              else false end
    ) q), '[]'::jsonb);
end $$;

/** Rincian satu kasus: ringkasan untuk semua yang berhak melihat santri; pemeriksaan dan jejak hanya untuk yang berhak. */
create or replace function public.detail_kasus_klinik(p_case uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare c clinic_cases%rowtype; v_detail boolean;
begin
  select * into c from clinic_cases where id = p_case;
  if c.id is null then return null; end if;
  v_detail := public.boleh_detail_klinik(c.klinik);
  if not (v_detail or c.student_id in (select public.santri_terlihat())) then
    raise exception 'Anda tidak berwenang melihat kasus ini.' using errcode = '42501';
  end if;
  return (select jsonb_build_object(
    'kasus', to_jsonb(c) || jsonb_build_object('nama', s.nama_lengkap, 'nis', s.nis, 'jenis_kelamin', s.jenis_kelamin,
               'kelas', public._kelompok_santri(s.id, 'kelas'), 'kamar', public._kelompok_santri(s.id, 'kamar'),
               'halaqah', public._kelompok_santri(s.id, 'halaqah'), 'tanggal_lahir', s.tanggal_lahir),
    'detail', v_detail, 'boleh_periksa', public.boleh_periksa_klinik(c.klinik),
    'rujukan', coalesce((select jsonb_agg(jsonb_build_object('dirujuk_pada', r.dirujuk_pada, 'sumber', r.sumber, 'keluhan', r.keluhan,
                  'waktu_periksa', r.waktu_periksa, 'batas_waktu', r.batas_waktu, 'perujuk', e.nama_lengkap) order by r.dirujuk_pada)
                  from clinic_referrals r left join employees e on e.id = r.dirujuk_oleh where r.case_id = c.id), '[]'::jsonb),
    'pemeriksaan', case when v_detail then coalesce((select jsonb_agg(to_jsonb(v) || jsonb_build_object('petugas', e.nama_lengkap) order by v.waktu)
                  from clinic_visits v left join employees e on e.id = v.petugas_id where v.case_id = c.id), '[]'::jsonb) end,
    'jejak', case when v_detail then coalesce((select jsonb_agg(jsonb_build_object('jenis', f.jenis, 'isi', f.isi, 'pada', f.pada,
                  'oleh', e.nama_lengkap) order by f.pada) from clinic_followups f left join employees e on e.id = f.oleh
                  where f.case_id = c.id), '[]'::jsonb) end,
    'riwayat_santri', coalesce((select jsonb_agg(jsonb_build_object('id', h.id, 'dibuka_pada', h.dibuka_pada, 'keluhan', h.keluhan,
                  'status', h.status, 'hasil', h.hasil, 'tindak_lanjut', h.tindak_lanjut) order by h.dibuka_pada desc)
                  from clinic_cases h where h.student_id = c.student_id and h.id <> c.id), '[]'::jsonb))
    from students s where s.id = c.student_id);
end $$;

/** Pencarian santri untuk dirujuk atau dicatat datang sendiri. Petugas/pengelola mencari semua santri aktif di kliniknya;
    pegawai lain hanya santri yang terlihat olehnya. */
create or replace function public.cari_santri_klinik(p_cari text default '')
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(x order by x->>'nama'), '[]'::jsonb) from (
    select jsonb_build_object('id', s.id, 'nama', s.nama_lengkap, 'nis', s.nis, 'jenis_kelamin', s.jenis_kelamin,
             'kelas', public._kelompok_santri(s.id, 'kelas'), 'kamar', public._kelompok_santri(s.id, 'kamar'),
             'kasus_terbuka', (select c.status from clinic_cases c where c.student_id = s.id and c.status in ('menunggu','ditangani'))) x
      from students s
     where s.status = 'aktif'
       and (public.boleh_detail_klinik(case when s.jenis_kelamin = 'P' then 'putri' else 'putra' end)
            or s.id in (select public.santri_terlihat()))
       and (coalesce(trim(p_cari), '') = '' or s.nama_lengkap ilike '%' || trim(p_cari) || '%' or s.nis like trim(p_cari) || '%')
     order by s.nama_lengkap limit 40) q
$$;

-- ---------------------------------------------------------------------
-- 7. REALTIME, HAK EKSEKUSI
-- ---------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'clinic_cases') then
    alter publication supabase_realtime add table public.clinic_cases;
  end if;
end $$;

do $$
declare f text;
begin
  foreach f in array array['boleh_kelola_klinik()','pimpinan_kesantrian()','klinik_petugas_saya()','boleh_detail_klinik(text)',
    'boleh_periksa_klinik(text)','hak_klinik()','pengaturan_klinik()','simpan_pengaturan_klinik(jsonb)',
    'simpan_petugas_klinik(uuid,text,boolean,text)','hapus_petugas_klinik(uuid)','daftar_petugas_klinik()','calon_petugas_klinik()','buat_rujukan(uuid,text,text,text)',
    'simpan_pemeriksaan(jsonb)','batalkan_kasus_klinik(uuid,text)','selesaikan_kasus_klinik(uuid,text)',
    'daftar_klinik(text,date,date,text)','detail_kasus_klinik(uuid)','cari_santri_klinik(text)']
  loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['_rujukan_internal(uuid,text,text,text,uuid,text,uuid,text)','_batas_rujukan(timestamptz,text)','_kelompok_santri(uuid,text)']
  loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;
grant select on public.clinic_staff, public.clinic_cases, public.clinic_referrals, public.clinic_visits, public.clinic_followups to authenticated;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 6 baris; baris 1–5 "Sesuai", baris 6 jumlah petugas (boleh 0, diatur di aplikasi)
-- ---------------------------------------------------------------------
select '1. Tabel klinik (5) dengan RLS' as pemeriksaan,
       case when (select count(*) from pg_tables where schemaname = 'public' and rowsecurity and tablename in
         ('clinic_staff','clinic_cases','clinic_referrals','clinic_visits','clinic_followups')) = 5 then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Izin admin kelola_klinik', case when exists (select 1 from public.admin_capabilities where kode = 'kelola_klinik') then 'Sesuai' else 'Periksa' end
union all
select '3. Satu kasus terbuka per santri', case when exists (select 1 from pg_indexes where indexname = 'clinic_cases_satu_terbuka') then 'Sesuai' else 'Periksa' end
union all
select '4. Pengaturan klinik terbaca (2 jam layanan)', case when jsonb_array_length(public.pengaturan_klinik()->'jam_layanan') >= 1 then 'Sesuai' else 'Periksa' end
union all
select '5. Fungsi rujukan dan pemeriksaan', case when (select count(*) from pg_proc where pronamespace = 'public'::regnamespace
         and proname in ('buat_rujukan','simpan_pemeriksaan','daftar_klinik','detail_kasus_klinik')) = 4 then 'Sesuai' else 'Periksa' end
union all
select '6. Petugas klinik (putra/putri)', (select count(*) filter (where klinik = 'putra') || ' putra, ' || count(*) filter (where klinik = 'putri') || ' putri'
         from public.clinic_staff where aktif);
