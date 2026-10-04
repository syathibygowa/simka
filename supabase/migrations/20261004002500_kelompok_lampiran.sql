-- SIMKA PRO | supabase/migrations/20261004002500_kelompok_lampiran.sql | v1.0 | Fase 3 – Perbaikan P1 (kartu, kelompok, pengumuman) | 04/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 3 · Migrasi 25 (perbaikan dari uji pemilik proyek):
--   * employee_groups + employee_group_members : kelompok pegawai bebas (Pengurus Harian, Pengurus Inti, panitia, dll.)
--     dikelola superadmin/admin ber-izin kelola_kelompok; menjadi pilihan sasaran (satu klik) di pengumuman, berkas, agenda
--   * penerima_sasaran / ringkas_sasaran mengenali kunci sasaran "kelompok_pegawai"
--   * Pengumuman dapat membawa lampiran berkas (Drive) dan tautan
-- Jalankan SETELAH migrasi 2400. Aman dijalankan ulang.
-- =====================================================================

insert into public.admin_capabilities (kode, nama, urutan) values
  ('kelola_kelompok', 'Mengatur kelompok pegawai (Pengurus Harian, Pengurus Inti, panitia, dll.) (Fase 3)', 15)
on conflict (kode) do nothing;

-- ---------------------------------------------------------------------
-- 1. Kelompok pegawai
-- ---------------------------------------------------------------------
create table if not exists public.employee_groups (
  id         uuid primary key default gen_random_uuid(),
  nama       text not null check (length(trim(nama)) between 2 and 100),
  singkatan  text check (singkatan is null or length(singkatan) <= 20),
  keterangan text,
  warna      text not null default 'pegawai',
  aktif      boolean not null default true,
  urutan     int not null default 0,
  dibuat_oleh uuid references public.employees(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists employee_groups_nama_uk on public.employee_groups (lower(nama));
create table if not exists public.employee_group_members (
  group_id    uuid not null references public.employee_groups(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  peran       text,               -- mis. Ketua, Sekretaris, Anggota (opsional)
  urutan      int not null default 0,
  created_at  timestamptz not null default now(),
  primary key (group_id, employee_id)
);
create index if not exists employee_group_members_emp_idx on public.employee_group_members (employee_id);

alter table public.employee_groups enable row level security;
alter table public.employee_group_members enable row level security;
drop trigger if exists aa_updated on public.employee_groups;
create trigger aa_updated before update on public.employee_groups for each row execute function public.tg_updated_at();
drop trigger if exists zz_audit on public.employee_groups;
create trigger zz_audit after insert or update or delete on public.employee_groups for each row execute function public.tg_audit();
drop trigger if exists zz_audit on public.employee_group_members;
create trigger zz_audit after insert or update or delete on public.employee_group_members for each row execute function public.tg_audit();

do $$
declare t text;
begin
  foreach t in array array['employee_groups','employee_group_members'] loop
    execute format('drop policy if exists baca on public.%I', t);
    execute format('create policy baca on public.%I for select to authenticated using (true)', t);
    execute format('drop policy if exists kelola on public.%I', t);
    execute format('create policy kelola on public.%I for all to authenticated using (public.admin_boleh(''kelola_kelompok'')) with check (public.admin_boleh(''kelola_kelompok''))', t);
  end loop;
end $$;
grant select, insert, update, delete on public.employee_groups, public.employee_group_members to authenticated;

-- ---------------------------------------------------------------------
-- 2. Mesin sasaran: kunci baru "kelompok_pegawai" (digabung seperti bidang/jabatan)
-- ---------------------------------------------------------------------
create or replace function public.penerima_sasaran(p jsonb)
returns setof uuid language plpgsql stable security definer set search_path = public as $$
declare
  v_unit uuid[] := coalesce((select array_agg(x::uuid) from jsonb_array_elements_text(p->'unit') x), '{}');
  v_fung uuid[] := coalesce((select array_agg(x::uuid) from jsonb_array_elements_text(p->'fungsional') x), '{}');
  v_str  uuid[] := coalesce((select array_agg(x::uuid) from jsonb_array_elements_text(p->'struktural') x), '{}');
  v_peg  uuid[] := coalesce((select array_agg(x::uuid) from jsonb_array_elements_text(p->'pegawai') x), '{}');
  v_grp  uuid[] := coalesce((select array_agg(x::uuid) from jsonb_array_elements_text(p->'kelompok_pegawai') x), '{}');
  v_jk   text   := nullif(p->>'jk', '');
  v_kelompok boolean := cardinality(v_unit) + cardinality(v_fung) + cardinality(v_str) + cardinality(v_grp) > 0;
begin
  return query
  with aktif as (
    select e.id, e.jenis_kelamin, e.org_unit_id from employees e
     where e.status_akun = 'aktif' and e.status_keaktifan = 'aktif'
  ), unit_cabang as (
    select distinct t from unnest(v_unit) u, lateral public.unit_turunan(u) t
  ), kelompok as (
    select a.id from aktif a
     where (coalesce(p->>'jenis', 'pilihan') = 'semua' or not v_kelompok
            or a.org_unit_id in (select t from unit_cabang)
            or exists (select 1 from employee_functions f where f.employee_id = a.id and f.functional_position_id = any (v_fung))
            or exists (select 1 from employee_structurals s where s.employee_id = a.id
                         and (s.structural_position_id = any (v_str)))
            or exists (select 1 from employee_group_members g join employee_groups k on k.id = g.group_id
                        where g.employee_id = a.id and k.aktif and g.group_id = any (v_grp)))
       and (v_jk is null or a.jenis_kelamin = v_jk)
       and (coalesce(p->>'jenis', 'pilihan') = 'semua' or v_kelompok or v_jk is not null or cardinality(v_peg) = 0)
  )
  select id from kelompok
  union
  select a.id from aktif a where a.id = any (v_peg);
end $$;

create or replace function public.ringkas_sasaran(p jsonb)
returns text language plpgsql stable security definer set search_path = public as $$
declare bagian text[] := '{}'; v text;
begin
  if coalesce(p->>'jenis', 'pilihan') = 'semua' then return 'Semua pegawai'; end if;
  select string_agg(nama, ', ' order by nama) into v from org_units where id::text in (select jsonb_array_elements_text(p->'unit'));
  if v is not null then bagian := bagian || v; end if;
  select string_agg(nama, ', ' order by urutan) into v from functional_positions where id::text in (select jsonb_array_elements_text(p->'fungsional'));
  if v is not null then bagian := bagian || v; end if;
  select string_agg(nama, ', ' order by urutan) into v from structural_positions where id::text in (select jsonb_array_elements_text(p->'struktural'));
  if v is not null then bagian := bagian || v; end if;
  select string_agg(coalesce(nullif(singkatan, ''), nama), ', ' order by urutan, nama) into v from employee_groups where id::text in (select jsonb_array_elements_text(p->'kelompok_pegawai'));
  if v is not null then bagian := bagian || v; end if;
  if nullif(p->>'jk', '') is not null then
    bagian := bagian || case p->>'jk' when 'L' then 'khusus laki-laki' else 'khusus perempuan' end;
  end if;
  if jsonb_array_length(coalesce(p->'pegawai', '[]')) > 0 then
    bagian := bagian || (jsonb_array_length(p->'pegawai') || ' pegawai tertentu');
  end if;
  return coalesce(nullif(array_to_string(bagian, '; '), ''), 'Semua pegawai');
end $$;

-- ---------------------------------------------------------------------
-- 3. Lampiran dan tautan pengumuman
-- ---------------------------------------------------------------------
alter table public.announcements add column if not exists lampiran_id uuid references public.storage_objects(id) on delete set null;
alter table public.announcements add column if not exists tautan text;
alter table public.announcements add column if not exists nama_tautan text;

create or replace function public.simpan_pengumuman(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid := nullif(p->>'id', '')::uuid; v_jumlah int; v_penting boolean := coalesce((p->>'penting')::boolean, false);
begin
  if not public.boleh_umumkan() then raise exception 'Anda tidak berwenang membuat pengumuman.' using errcode = '42501'; end if;
  if length(trim(coalesce(p->>'judul', ''))) < 3 then raise exception 'Judul pengumuman minimal 3 karakter.'; end if;
  if length(trim(coalesce(p->>'isi', ''))) < 3 then raise exception 'Isi pengumuman belum diisi.'; end if;

  if v_id is not null then
    update announcements set judul = trim(p->>'judul'), isi = trim(p->>'isi'), penting = v_penting,
           tampil_sampai = nullif(p->>'tampil_sampai', '')::date,
           lampiran_id = case when p ? 'lampiran_id' then nullif(p->>'lampiran_id', '')::uuid else lampiran_id end,
           tautan = nullif(trim(coalesce(p->>'tautan', '')), ''), nama_tautan = nullif(trim(coalesce(p->>'nama_tautan', '')), '')
     where id = v_id;
    if not found then raise exception 'Pengumuman tidak ditemukan.'; end if;
    return v_id;
  end if;

  if nullif(trim(coalesce(p->>'tautan', '')), '') is not null and p->>'tautan' !~ '^https?://' then
    raise exception 'Tautan harus diawali https:// atau http://';
  end if;
  insert into announcements (judul, isi, penting, sasaran, ringkasan_sasaran, tampil_sampai, dibuat_oleh, lampiran_id, tautan, nama_tautan)
  values (trim(p->>'judul'), trim(p->>'isi'), v_penting, coalesce(p->'sasaran', '{"jenis":"semua"}'),
          public.ringkas_sasaran(coalesce(p->'sasaran', '{"jenis":"semua"}')),
          nullif(p->>'tampil_sampai', '')::date, public.saya(), nullif(p->>'lampiran_id', '')::uuid,
          nullif(trim(coalesce(p->>'tautan', '')), ''), nullif(trim(coalesce(p->>'nama_tautan', '')), ''))
  returning id into v_id;

  insert into announcement_targets (announcement_id, employee_id)
  select v_id, x from public.penerima_sasaran(coalesce(p->'sasaran', '{"jenis":"semua"}')) x
  on conflict do nothing;
  get diagnostics v_jumlah = row_count;
  if v_jumlah = 0 then raise exception 'Sasaran yang dipilih tidak memiliki penerima (pegawai aktif berakun). Ubah sasaran pengumuman.'; end if;

  insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
  select t.employee_id, case when v_penting then 'Pengumuman penting: ' else 'Pengumuman: ' end || trim(p->>'judul'),
         left(regexp_replace(trim(p->>'isi'), '\s+', ' ', 'g'), 140), '/pengumuman/' || v_id, 'Megaphone',
         case when v_penting then 'merah' else 'ungu' end
    from announcement_targets t where t.announcement_id = v_id and t.employee_id is distinct from public.saya();
  return v_id;
end $$;

drop function if exists public.daftar_pengumuman(boolean);
create or replace function public.daftar_pengumuman(p_kelola boolean default false)
returns table (id uuid, judul text, isi text, penting boolean, ringkasan_sasaran text, tampil_sampai date,
               created_at timestamptz, updated_at timestamptz, pembuat text, dibaca_pada timestamptz,
               penerima int, sudah_dibaca int, saya_penerima boolean,
               lampiran_id uuid, nama_lampiran text, mime_lampiran text, ukuran_lampiran int, tautan text, nama_tautan text)
language sql stable security definer set search_path = public as $$
  select a.id, a.judul, a.isi, a.penting, a.ringkasan_sasaran, a.tampil_sampai, a.created_at, a.updated_at,
         e.nama_lengkap, t.dibaca_pada,
         case when p_kelola and public.boleh_umumkan() then (select count(*)::int from announcement_targets x where x.announcement_id = a.id) end,
         case when p_kelola and public.boleh_umumkan() then (select count(*)::int from announcement_targets x where x.announcement_id = a.id and x.dibaca_pada is not null) end,
         t.employee_id is not null,
         a.lampiran_id, o.nama_berkas, o.mime, o.ukuran, a.tautan, a.nama_tautan
    from announcements a
    left join employees e on e.id = a.dibuat_oleh
    left join storage_objects o on o.id = a.lampiran_id
    left join announcement_targets t on t.announcement_id = a.id and t.employee_id = public.saya()
   where (p_kelola and public.boleh_umumkan()) or t.employee_id is not null
   order by a.created_at desc
   limit 300
$$;

create or replace function public.boleh_lihat_berkas(p_obj uuid, p_emp uuid)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare r leave_requests; v_peran text; j journal_entries;
  izin boolean := false;
begin
  select peran into v_peran from employees where id = p_emp;
  if v_peran = 'superadmin' then return true; end if;
  for r in select * from leave_requests where lampiran_id = p_obj loop
    if r.employee_id = p_emp
       or (v_peran = 'admin' and exists (select 1 from admin_permissions where employee_id = p_emp and kode = 'lihat_pengajuan'))
       or exists (select 1 from leave_approvals a where a.request_id = r.id and a.oleh = p_emp)
       or exists (select 1 from leave_approvals a, public.calon_penyetuju(r.employee_id, a.peran) c
                   where a.request_id = r.id and a.status = 'menunggu' and c.employee_id = p_emp) then
      return true;
    end if;
  end loop;
  for j in select * from journal_entries where foto_id = p_obj loop
    if j.employee_id = p_emp
       or (v_peran = 'admin' and exists (select 1 from admin_permissions where employee_id = p_emp and kode = 'verval_jurnal'))
       or exists (select 1 from employees t, employee_structurals es join structural_positions sp on sp.id = es.structural_position_id
                   where t.id = j.employee_id and es.employee_id = p_emp
                     and (sp.tingkat <= 20 or t.org_unit_id in (select public.unit_turunan(es.org_unit_id)))) then
      return true;
    end if;
  end loop;
  if exists (select 1 from employee_documents d where d.berkas_id = p_obj and (
              exists (select 1 from employee_document_targets t where t.document_id = d.id and t.employee_id = p_emp)
              or (v_peran = 'admin' and exists (select 1 from admin_permissions where employee_id = p_emp and kode = 'kelola_berkas')))) then
    return true;
  end if;
  -- Lampiran pengumuman: penerima dan pembuat pengumuman
  if exists (select 1 from announcements a where a.lampiran_id = p_obj and (
              exists (select 1 from announcement_targets t where t.announcement_id = a.id and t.employee_id = p_emp)
              or a.dibuat_oleh = p_emp or v_peran = 'admin')) then
    return true;
  end if;
  -- Foto profil pegawai untuk pencetak kartu
  if v_peran = 'admin' and exists (select 1 from admin_permissions where employee_id = p_emp and kode = 'cetak_kartu')
     and exists (select 1 from employees where foto_id = p_obj) then
    return true;
  end if;
  return false;
end $$;

-- ---------------------------------------------------------------------
-- 4. Hak eksekusi
-- ---------------------------------------------------------------------
revoke execute on function public.penerima_sasaran(jsonb) from public, anon, authenticated;
revoke execute on function public.ringkas_sasaran(jsonb) from public, anon, authenticated;
revoke execute on function public.boleh_lihat_berkas(uuid,uuid) from public, anon, authenticated;
grant execute on function public.boleh_lihat_berkas(uuid,uuid) to service_role;
revoke execute on function public.daftar_pengumuman(boolean) from public, anon;
grant execute on function public.daftar_pengumuman(boolean) to authenticated;
revoke execute on function public.simpan_pengumuman(jsonb) from public, anon;
grant execute on function public.simpan_pengumuman(jsonb) to authenticated;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 4 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select 'Tabel kelompok pegawai (2) dengan RLS' as pemeriksaan,
       case when (select count(*) from pg_tables where schemaname = 'public' and rowsecurity
                   and tablename in ('employee_groups','employee_group_members')) = 2 then 'Sesuai' else 'Periksa' end as hasil
union all
select 'Sasaran mengenali kelompok pegawai',
       case when position('kelompok_pegawai' in pg_get_functiondef('public.penerima_sasaran(jsonb)'::regprocedure)) > 0 then 'Sesuai' else 'Periksa' end
union all
select 'Kolom lampiran dan tautan pengumuman',
       case when (select count(*) from information_schema.columns where table_name = 'announcements' and column_name in ('lampiran_id','tautan','nama_tautan')) = 3 then 'Sesuai' else 'Periksa' end
union all
select 'Migrasi 2400 sudah terpasang',
       case when exists (select 1 from pg_proc where proname = 'ringkasan_beranda') then 'Sesuai' else 'Periksa: jalankan 2400 dulu' end;
