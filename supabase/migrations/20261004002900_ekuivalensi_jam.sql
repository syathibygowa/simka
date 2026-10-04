-- SIMKA PRO | supabase/migrations/20261004002900_ekuivalensi_jam.sql | v1.0 | Fase 3 – Perbaikan P5 (ekuivalensi jam) | 04/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 3 · Migrasi 29: Ekuivalensi jam beban kerja per tupoksi
--   * workload_components : komponen jam per pekan — tertaut jabatan struktural/fungsional (otomatis) atau tugas tambahan
--     (diberikan per orang); sumber "tetap" (jam bawaan) atau "per_orang" (mis. Guru Mapel, Takhassus: diisi per pegawai,
--     kelak dari jadwal pelajaran Fase 4). Semua jam dan komponen dapat diubah/ditambah admin ber-izin atur_beban_kerja.
--   * employee_workloads  : jam per pegawai (penimpa jam bawaan, jam per orang, tugas tambahan)
--   * Jam wajib per status di Pengaturan (bawaan: tetap 48, kontrak 48, honorer tidak terikat)
--   * beban_kerja_rekap() : total, jam wajib, kelebihan/kekurangan per pegawai
--   * workload_snapshots  : kunci rekap bulanan (dasar perhitungan gaji Fase 11)
-- Jalankan SETELAH migrasi 2800. Aman dijalankan ulang.
-- =====================================================================

insert into public.admin_capabilities (kode, nama, urutan) values
  ('atur_beban_kerja', 'Mengatur ekuivalensi jam beban kerja dan mengunci rekap bulanan (Fase 3)', 16)
on conflict (kode) do nothing;

insert into public.institution_settings (kunci, nilai) values
  ('beban_kerja', '{"wajib": {"tetap": 48, "kontrak": 48, "honorer": null}, "satuan": "jam per pekan"}')
on conflict (kunci) do nothing;

-- ---------------------------------------------------------------------
-- 1. Komponen dan jam per pegawai
-- ---------------------------------------------------------------------
create table if not exists public.workload_components (
  id                     uuid primary key default gen_random_uuid(),
  kode                   text not null unique check (kode ~ '^[A-Z0-9_]{2,40}$'),
  nama                   text not null,
  kolom                  text not null default 'Tugas Tambahan Lainnya',   -- judul kolom rekap
  kelompok               text not null default 'tambahan' check (kelompok in ('struktural','fungsional','tambahan')),
  sumber                 text not null default 'tetap' check (sumber in ('tetap','per_orang')),
  jam_bawaan             numeric(5,1) not null default 0 check (jam_bawaan between 0 and 99),
  structural_position_id uuid unique references public.structural_positions(id) on delete set null,
  functional_position_id uuid unique references public.functional_positions(id) on delete set null,
  keterangan             text,
  aktif                  boolean not null default true,
  urutan                 int not null default 0,
  updated_at             timestamptz not null default now()
);
create table if not exists public.employee_workloads (
  id           uuid primary key default gen_random_uuid(),
  employee_id  uuid not null references public.employees(id) on delete cascade,
  component_id uuid not null references public.workload_components(id) on delete cascade,
  jam          numeric(5,1) not null check (jam between 0 and 99),
  catatan      text,
  diubah_oleh  uuid references public.employees(id) on delete set null,
  updated_at   timestamptz not null default now(),
  unique (employee_id, component_id)
);
create table if not exists public.workload_snapshots (
  periode      date not null,                -- tanggal 1 bulan
  employee_id  uuid not null references public.employees(id) on delete cascade,
  status       text,
  jam_wajib    numeric(5,1),
  total        numeric(5,1) not null,
  selisih      numeric(5,1),
  rincian      jsonb not null default '[]',
  dikunci_oleh uuid references public.employees(id) on delete set null,
  dikunci_pada timestamptz not null default now(),
  primary key (periode, employee_id)
);

alter table public.workload_components enable row level security;
alter table public.employee_workloads enable row level security;
alter table public.workload_snapshots enable row level security;
drop trigger if exists aa_updated on public.workload_components;
create trigger aa_updated before update on public.workload_components for each row execute function public.tg_updated_at();
drop trigger if exists aa_updated on public.employee_workloads;
create trigger aa_updated before update on public.employee_workloads for each row execute function public.tg_updated_at();
drop trigger if exists zz_audit on public.workload_components;
create trigger zz_audit after insert or update or delete on public.workload_components for each row execute function public.tg_audit();
drop trigger if exists zz_audit on public.employee_workloads;
create trigger zz_audit after insert or update or delete on public.employee_workloads for each row execute function public.tg_audit();

create or replace function public.boleh_atur_beban()
returns boolean language sql stable security definer set search_path = public as $$
  select public.admin_boleh('atur_beban_kerja')
$$;
create or replace function public.boleh_lihat_beban(p_emp uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select p_emp = public.saya() or public.boleh_atur_beban() or public.is_admin() or public.pimpinan_dari(p_emp)
$$;

drop policy if exists baca on public.workload_components;
create policy baca on public.workload_components for select to authenticated using (true);
drop policy if exists kelola on public.workload_components;
create policy kelola on public.workload_components for all to authenticated using (public.boleh_atur_beban()) with check (public.boleh_atur_beban());
drop policy if exists baca on public.employee_workloads;
create policy baca on public.employee_workloads for select to authenticated using (public.boleh_lihat_beban(employee_id));
drop policy if exists baca on public.workload_snapshots;
create policy baca on public.workload_snapshots for select to authenticated using (public.boleh_lihat_beban(employee_id));
grant select, insert, update, delete on public.workload_components to authenticated;
grant select on public.employee_workloads, public.workload_snapshots to authenticated;

-- ---------------------------------------------------------------------
-- 2. Isi awal komponen (semua angka dapat diubah di aplikasi)
-- ---------------------------------------------------------------------
insert into public.workload_components (kode, nama, kolom, kelompok, sumber, jam_bawaan, structural_position_id, urutan)
select 'S_' || sp.kode, sp.nama, 'Jabatan Struktural', 'struktural', 'tetap',
       case sp.kode when 'YAYASAN' then 0 when 'DIREKTUR' then 24 when 'WAKIL_DIREKTUR' then 18 when 'BENDAHARA' then 14
                    when 'TATA_USAHA' then 18 else 12 end, sp.id, sp.tingkat
  from public.structural_positions sp
on conflict (kode) do nothing;

insert into public.workload_components (kode, nama, kolom, kelompok, sumber, jam_bawaan, functional_position_id, urutan, keterangan)
select 'F_' || fp.kode, fp.nama,
       case fp.kode when 'GURU' then 'Guru Mapel' when 'MUHAFFIZH' then 'Guru Tahfizh' when 'WALI_KELAS' then 'Guru Walas'
                    when 'MUSYRIF' then 'Musyrif' else 'Fungsional Lainnya' end,
       'fungsional', case when fp.kode in ('GURU','PEMBINA_EKSKUL') then 'per_orang' else 'tetap' end,
       case fp.kode when 'GURU' then 0 when 'MUHAFFIZH' then 24 when 'WALI_KELAS' then 4 when 'MUSYRIF' then 12 when 'PEMBINA_EKSKUL' then 2
                    when 'OPERATOR' then 12 when 'STAF_BIDANG' then 6 when 'STAF_PEMBANTU' then 6 when 'MEDIA' then 12 when 'SARPRAS' then 12
                    else 48 end, fp.id, 100 + fp.urutan,
       case fp.kode when 'GURU' then 'Jam mengajar per pekan diisi per guru (kelak otomatis dari jadwal pelajaran Fase 4).'
                    when 'PEMBINA_EKSKUL' then 'Diisi per pembina sesuai jadwal ekskul.'
                    when 'MEDIS' then 'Tugas penuh waktu (shift).' when 'SECURITY' then 'Tugas penuh waktu (shift).' end
  from public.functional_positions fp
on conflict (kode) do nothing;

insert into public.workload_components (kode, nama, kolom, kelompok, sumber, jam_bawaan, urutan, keterangan) values
  ('T_TAKHASSUS', 'Pengajar Takhassus', 'Takhassus', 'tambahan', 'per_orang', 0, 200, 'Jam mengajar takhassus per pekan, diisi per orang.'),
  ('T_KEPALA_LAB', 'Kepala Laboratorium', 'Tugas Tambahan Lainnya', 'tambahan', 'tetap', 12, 210, null),
  ('T_KEPALA_PERPUS', 'Kepala Perpustakaan', 'Tugas Tambahan Lainnya', 'tambahan', 'tetap', 12, 211, null),
  ('T_KEPALA_TAKHASSUS', 'Kepala Takhassus', 'Tugas Tambahan Lainnya', 'tambahan', 'tetap', 12, 212, null),
  ('T_KEPALA_MEDIS', 'Kepala Medis', 'Tugas Tambahan Lainnya', 'tambahan', 'tetap', 12, 213, null),
  ('T_BENDAHARA_BOS', 'Bendahara BOS', 'Tugas Tambahan Lainnya', 'tambahan', 'tetap', 14, 214, null),
  ('T_STAF_KURIKULUM', 'Staf Kurikulum', 'Tugas Tambahan Lainnya', 'tambahan', 'tetap', 6, 220, null),
  ('T_STAF_KESISWAAN', 'Staf Kesiswaan', 'Tugas Tambahan Lainnya', 'tambahan', 'tetap', 6, 221, null),
  ('T_STAF_SARPRAS', 'Staf Sarana Prasarana', 'Tugas Tambahan Lainnya', 'tambahan', 'tetap', 6, 222, null),
  ('T_STAF_MEDIA', 'Staf Media', 'Tugas Tambahan Lainnya', 'tambahan', 'tetap', 6, 223, null),
  ('T_STAF_TAHFIZH', 'Staf Tahfizh', 'Tugas Tambahan Lainnya', 'tambahan', 'tetap', 6, 224, null),
  ('T_LAINNYA', 'Tugas tambahan lainnya', 'Tugas Tambahan Lainnya', 'tambahan', 'per_orang', 0, 299, 'Untuk penugasan khusus yang belum diatur; jam diisi per orang.')
on conflict (kode) do nothing;

-- ---------------------------------------------------------------------
-- 3. Perhitungan
-- ---------------------------------------------------------------------
create or replace function public.jam_wajib(p_status text)
returns numeric language sql stable security definer set search_path = public as $$
  select nullif(nilai #>> array['wajib', coalesce(p_status, 'tetap')], '')::numeric from institution_settings where kunci = 'beban_kerja'
$$;

/** Rincian jam per komponen seorang pegawai: komponen dari jabatannya (otomatis, dapat ditimpa) + tugas tambahan yang diberikan. */
create or replace function public.rincian_beban(p_emp uuid)
returns table (component_id uuid, kode text, nama text, kolom text, kelompok text, sumber text, jam numeric, jam_bawaan numeric,
               otomatis boolean, ditimpa boolean, catatan text, urutan int)
language sql stable security definer set search_path = public as $$
  with tertaut as (
    select c.* from workload_components c
     where c.aktif and (c.structural_position_id in (select structural_position_id from employee_structurals where employee_id = p_emp)
        or c.functional_position_id in (select functional_position_id from employee_functions where employee_id = p_emp))
  )
  select c.id, c.kode, c.nama, c.kolom, c.kelompok, c.sumber, coalesce(w.jam, case when c.sumber = 'tetap' then c.jam_bawaan else 0 end), c.jam_bawaan,
         true, w.id is not null, w.catatan, c.urutan
    from tertaut c left join employee_workloads w on w.component_id = c.id and w.employee_id = p_emp
  union all
  select c.id, c.kode, c.nama, c.kolom, c.kelompok, c.sumber, w.jam, c.jam_bawaan, false, false, w.catatan, c.urutan
    from employee_workloads w join workload_components c on c.id = w.component_id
   where w.employee_id = p_emp and c.id not in (select id from tertaut)
  order by 12
$$;

create or replace function public.beban_kerja_rekap(p_unit uuid default null)
returns table (employee_id uuid, nama text, niy text, status text, unit text, org_unit_id uuid, jabatan text,
               jam_wajib numeric, total numeric, selisih numeric, rincian jsonb)
language sql stable security definer set search_path = public as $$
  select e.id, e.nama_lengkap, e.niy, e.status_kepegawaian, u.nama, e.org_unit_id,
         nullif(concat_ws(', ', (select string_agg(sp.nama, ', ') from employee_structurals es join structural_positions sp on sp.id = es.structural_position_id where es.employee_id = e.id),
                (select string_agg(fp.nama, ', ' order by fp.urutan) from employee_functions ef join functional_positions fp on fp.id = ef.functional_position_id where ef.employee_id = e.id),
                (select string_agg(c.nama, ', ' order by c.urutan) from employee_workloads w join workload_components c on c.id = w.component_id
                  where w.employee_id = e.id and c.structural_position_id is null and c.functional_position_id is null)), ''),
         public.jam_wajib(e.status_kepegawaian), r.total,
         r.total - public.jam_wajib(e.status_kepegawaian),
         r.rincian
    from employees e left join org_units u on u.id = e.org_unit_id
    cross join lateral (select coalesce(sum(b.jam), 0) total,
                               coalesce(jsonb_agg(jsonb_build_object('kode', b.kode, 'nama', b.nama, 'kolom', b.kolom, 'kelompok', b.kelompok, 'jam', b.jam) order by b.urutan)
                                        filter (where b.jam > 0), '[]') rincian
                          from public.rincian_beban(e.id) b) r
   where e.status_keaktifan = 'aktif' and public.boleh_lihat_beban(e.id)
     and (p_unit is null or e.org_unit_id in (select public.unit_turunan(p_unit)))
   order by u.nama nulls last, e.nama_lengkap
$$;

/** Simpan jam seorang pegawai: [{component_id, jam, catatan}] — penimpa jam bawaan, jam per orang, dan tugas tambahan. */
create or replace function public.simpan_beban_pegawai(p_emp uuid, p_rincian jsonb)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  if not public.boleh_atur_beban() then raise exception 'Anda tidak berwenang mengatur beban kerja.' using errcode = '42501'; end if;
  delete from employee_workloads where employee_id = p_emp
     and component_id not in (select (x->>'component_id')::uuid from jsonb_array_elements(coalesce(p_rincian, '[]')) x);
  insert into employee_workloads (employee_id, component_id, jam, catatan, diubah_oleh)
  select p_emp, (x->>'component_id')::uuid, (x->>'jam')::numeric, nullif(trim(coalesce(x->>'catatan', '')), ''), public.saya()
    from jsonb_array_elements(coalesce(p_rincian, '[]')) x
  on conflict (employee_id, component_id) do update set jam = excluded.jam, catatan = excluded.catatan, diubah_oleh = excluded.diubah_oleh;
end $$;

/** Kunci rekap bulan berjalan/tertentu (dasar gaji Fase 11). Mengunci ulang menimpa salinan bulan itu. */
create or replace function public.kunci_beban_kerja(p_periode date)
returns int language plpgsql volatile security definer set search_path = public as $$
declare v_p date := date_trunc('month', p_periode)::date; n int;
begin
  if not public.boleh_atur_beban() then raise exception 'Anda tidak berwenang mengunci rekap beban kerja.' using errcode = '42501'; end if;
  delete from workload_snapshots where periode = v_p;
  insert into workload_snapshots (periode, employee_id, status, jam_wajib, total, selisih, rincian, dikunci_oleh)
  select v_p, r.employee_id, r.status, r.jam_wajib, r.total, r.selisih, r.rincian, public.saya() from public.beban_kerja_rekap(null) r;
  get diagnostics n = row_count;
  perform public.catat_audit('kunci_beban_kerja', 'workload_snapshots', to_char(v_p, 'YYYY-MM'), 'Rekap beban kerja dikunci untuk ' || to_char(v_p, 'MM/YYYY'), jsonb_build_object('jumlah', n));
  return n;
end $$;

create or replace function public.atur_jam_wajib(p jsonb)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  if not public.boleh_atur_beban() then raise exception 'Anda tidak berwenang mengubah jam wajib.' using errcode = '42501'; end if;
  update institution_settings set nilai = jsonb_set(nilai, '{wajib}', jsonb_build_object(
      'tetap', nullif(p->>'tetap', '')::numeric, 'kontrak', nullif(p->>'kontrak', '')::numeric, 'honorer', nullif(p->>'honorer', '')::numeric))
   where kunci = 'beban_kerja';
end $$;

do $$
declare f text;
begin
  foreach f in array array['boleh_atur_beban()','boleh_lihat_beban(uuid)','jam_wajib(text)','rincian_beban(uuid)','beban_kerja_rekap(uuid)',
    'simpan_beban_pegawai(uuid,jsonb)','kunci_beban_kerja(date)','atur_jam_wajib(jsonb)']
  loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 5 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select 'Tabel ekuivalensi jam (3) dengan RLS' as pemeriksaan,
       case when (select count(*) from pg_tables where schemaname = 'public' and rowsecurity
                   and tablename in ('workload_components','employee_workloads','workload_snapshots')) = 3 then 'Sesuai' else 'Periksa' end as hasil
union all
select 'Komponen jam isi awal (minimal 30)',
       case when (select count(*) from public.workload_components) >= 30 then 'Sesuai' else 'Periksa' end
union all
select 'Jam wajib tetap dan kontrak 48 jam',
       case when public.jam_wajib('tetap') = 48 and public.jam_wajib('kontrak') = 48 and public.jam_wajib('honorer') is null then 'Sesuai' else 'Periksa (sudah diubah?)' end
union all
select 'Fungsi rekap beban kerja',
       case when exists (select 1 from pg_proc where proname = 'beban_kerja_rekap') then 'Sesuai' else 'Periksa' end
union all
select 'Migrasi 2800 sudah terpasang',
       case when position('jabatan_kartu' in pg_get_function_result('public.data_kartu(uuid[])'::regprocedure)) > 0 then 'Sesuai' else 'Periksa: jalankan 2800 dulu' end;
