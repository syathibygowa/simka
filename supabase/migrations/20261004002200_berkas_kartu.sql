-- SIMKA PRO | supabase/migrations/20261004002200_berkas_kartu.sql | v1.0 | Fase 3 – Tahap 4 Berkas Saya dan kartu pegawai | 04/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 3 · Migrasi 22: Berkas Saya dan Kartu pegawai
--   * employee_documents + employee_document_targets : info, formulir, surat, SK dengan sasaran;
--     berkas di Google Drive dibuka lewat tautan sementara (Edge Function "berkas"), pembukaan tercatat
--   * employee_cards : kode verifikasi kartu pegawai (QR); cek_kartu(kode) dapat dipanggil tanpa masuk
--   * data_kartu(...) : data kartu (nama, NIY, jabatan, unit, foto, Direktur dari jabatan struktural)
-- Jalankan SETELAH migrasi 2100. Aman dijalankan ulang.
-- =====================================================================

insert into public.admin_capabilities (kode, nama, urutan) values
  ('kelola_berkas', 'Mengirim berkas pegawai (info, formulir, surat, SK) dan melihat pembukaannya (Fase 3)', 12),
  ('cetak_kartu', 'Mencetak kartu pegawai secara massal (Fase 3)', 13)
on conflict (kode) do nothing;

-- ---------------------------------------------------------------------
-- 1. Berkas pegawai
-- ---------------------------------------------------------------------
create table if not exists public.employee_documents (
  id                uuid primary key default gen_random_uuid(),
  judul             text not null check (length(trim(judul)) between 3 and 150),
  kategori          text not null default 'info' check (kategori in ('info','formulir','surat','sk','lainnya')),
  keterangan        text,
  berkas_id         uuid references public.storage_objects(id) on delete set null,
  tautan_luar       text check (tautan_luar is null or tautan_luar ~ '^https://'),
  sasaran           jsonb not null default '{"jenis":"semua"}',
  ringkasan_sasaran text,
  berlaku_sampai    date,
  dibuat_oleh       uuid references public.employees(id) on delete set null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  check (berkas_id is not null or tautan_luar is not null)
);
create table if not exists public.employee_document_targets (
  document_id   uuid not null references public.employee_documents(id) on delete cascade,
  employee_id   uuid not null references public.employees(id) on delete cascade,
  dibuka_pertama timestamptz,
  dibuka_terakhir timestamptz,
  jumlah_buka   int not null default 0,
  primary key (document_id, employee_id)
);
create index if not exists employee_document_targets_emp_idx on public.employee_document_targets (employee_id);

alter table public.employee_documents enable row level security;
alter table public.employee_document_targets enable row level security;
drop trigger if exists aa_updated on public.employee_documents;
create trigger aa_updated before update on public.employee_documents for each row execute function public.tg_updated_at();
drop trigger if exists zz_audit on public.employee_documents;
create trigger zz_audit after insert or update or delete on public.employee_documents for each row execute function public.tg_audit();

create or replace function public.boleh_kelola_berkas()
returns boolean language sql stable security definer set search_path = public as $$
  select public.admin_boleh('kelola_berkas')
$$;

drop policy if exists baca on public.employee_documents;
create policy baca on public.employee_documents for select to authenticated
  using (public.boleh_kelola_berkas() or exists (select 1 from employee_document_targets t
          where t.document_id = employee_documents.id and t.employee_id = public.saya()));
drop policy if exists baca on public.employee_document_targets;
create policy baca on public.employee_document_targets for select to authenticated
  using (employee_id = public.saya() or public.boleh_kelola_berkas());

create or replace function public.simpan_berkas_pegawai(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid := nullif(p->>'id', '')::uuid; v_n int; v_sasaran jsonb := coalesce(p->'sasaran', '{"jenis":"semua"}');
        v_kat text := coalesce(nullif(p->>'kategori', ''), 'info');
begin
  if not public.boleh_kelola_berkas() then raise exception 'Anda tidak berwenang mengirim berkas pegawai.' using errcode = '42501'; end if;
  if length(trim(coalesce(p->>'judul', ''))) < 3 then raise exception 'Judul berkas minimal 3 karakter.'; end if;
  if nullif(p->>'berkas_id', '') is null and nullif(trim(coalesce(p->>'tautan_luar', '')), '') is null then
    raise exception 'Unggah berkas atau isi tautan (https://).';
  end if;
  if v_id is not null then
    update employee_documents set judul = trim(p->>'judul'), kategori = v_kat, keterangan = nullif(trim(coalesce(p->>'keterangan', '')), ''),
           berkas_id = coalesce(nullif(p->>'berkas_id', '')::uuid, berkas_id), tautan_luar = nullif(trim(coalesce(p->>'tautan_luar', '')), ''),
           berlaku_sampai = nullif(p->>'berlaku_sampai', '')::date
     where id = v_id;
    if not found then raise exception 'Berkas tidak ditemukan.'; end if;
    return v_id;
  end if;
  insert into employee_documents (judul, kategori, keterangan, berkas_id, tautan_luar, sasaran, ringkasan_sasaran, berlaku_sampai, dibuat_oleh)
  values (trim(p->>'judul'), v_kat, nullif(trim(coalesce(p->>'keterangan', '')), ''), nullif(p->>'berkas_id', '')::uuid,
          nullif(trim(coalesce(p->>'tautan_luar', '')), ''), v_sasaran, public.ringkas_sasaran(v_sasaran),
          nullif(p->>'berlaku_sampai', '')::date, public.saya())
  returning id into v_id;
  insert into employee_document_targets (document_id, employee_id)
  select v_id, x from public.penerima_sasaran(v_sasaran) x on conflict do nothing;
  get diagnostics v_n = row_count;
  if v_n = 0 then raise exception 'Sasaran yang dipilih tidak memiliki penerima (pegawai aktif berakun).'; end if;
  -- Berkas yang diunggah menjadi milik sistem (tidak ikut terhapus bersama akun pengunggah)
  update storage_objects set kategori = 'berkas_pegawai', hapus_setelah = null where id = nullif(p->>'berkas_id', '')::uuid;
  insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
  select t.employee_id,
         case v_kat when 'sk' then 'SK baru untuk Anda' when 'surat' then 'Surat baru untuk Anda' when 'formulir' then 'Formulir baru' else 'Berkas baru' end,
         trim(p->>'judul'), '/berkas/' || v_id, 'FolderOpen', 'biru'
    from employee_document_targets t where t.document_id = v_id and t.employee_id is distinct from public.saya();
  return v_id;
end $$;

create or replace function public.hapus_berkas_pegawai(p_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v_obj uuid;
begin
  if not public.boleh_kelola_berkas() then raise exception 'Anda tidak berwenang menghapus berkas pegawai.' using errcode = '42501'; end if;
  delete from employee_documents where id = p_id returning berkas_id into v_obj;
  delete from notifications where tautan = '/berkas/' || p_id;
  -- Berkas fisik di Drive dihapus oleh GAS pada sapuan berikutnya
  if v_obj is not null then update storage_objects set hapus_setelah = public.hari_ini() where id = v_obj; end if;
end $$;

create or replace function public.daftar_berkas_pegawai(p_kelola boolean default false)
returns table (id uuid, judul text, kategori text, keterangan text, berkas_id uuid, tautan_luar text, nama_berkas text, mime text, ukuran int,
               ringkasan_sasaran text, berlaku_sampai date, created_at timestamptz, pembuat text,
               dibuka_pertama timestamptz, jumlah_buka int, saya_penerima boolean, penerima int, sudah_buka int)
language sql stable security definer set search_path = public as $$
  select d.id, d.judul, d.kategori, d.keterangan, d.berkas_id, d.tautan_luar, o.nama_berkas, o.mime, o.ukuran,
         d.ringkasan_sasaran, d.berlaku_sampai, d.created_at, e.nama_lengkap, t.dibuka_pertama, coalesce(t.jumlah_buka, 0), t.employee_id is not null,
         case when p_kelola and public.boleh_kelola_berkas() then (select count(*)::int from employee_document_targets x where x.document_id = d.id) end,
         case when p_kelola and public.boleh_kelola_berkas() then (select count(*)::int from employee_document_targets x where x.document_id = d.id and x.dibuka_pertama is not null) end
    from employee_documents d
    left join storage_objects o on o.id = d.berkas_id
    left join employees e on e.id = d.dibuat_oleh
    left join employee_document_targets t on t.document_id = d.id and t.employee_id = public.saya()
   where (p_kelola and public.boleh_kelola_berkas()) or t.employee_id is not null
   order by d.created_at desc
   limit 500
$$;

create or replace function public.catat_buka_berkas(p_id uuid)
returns void language sql volatile security definer set search_path = public as $$
  update employee_document_targets set dibuka_pertama = coalesce(dibuka_pertama, now()), dibuka_terakhir = now(), jumlah_buka = jumlah_buka + 1
   where document_id = p_id and employee_id = public.saya();
  update notifications set dibaca_pada = now() where employee_id = public.saya() and tautan = '/berkas/' || p_id and dibaca_pada is null;
$$;

create or replace function public.pembuka_berkas(p_id uuid)
returns table (employee_id uuid, nama text, unit text, dibuka_pertama timestamptz, dibuka_terakhir timestamptz, jumlah_buka int)
language sql stable security definer set search_path = public as $$
  select t.employee_id, e.nama_lengkap, u.nama, t.dibuka_pertama, t.dibuka_terakhir, t.jumlah_buka
    from employee_document_targets t join employees e on e.id = t.employee_id left join org_units u on u.id = e.org_unit_id
   where t.document_id = p_id and public.boleh_kelola_berkas()
   order by t.dibuka_pertama nulls first, e.nama_lengkap
$$;

-- ---------------------------------------------------------------------
-- 2. Kartu pegawai
-- ---------------------------------------------------------------------
create table if not exists public.employee_cards (
  employee_id uuid primary key references public.employees(id) on delete cascade,
  kode        text not null unique,
  dibuat_pada timestamptz not null default now(),
  diganti_pada timestamptz
);
alter table public.employee_cards enable row level security;
drop policy if exists baca on public.employee_cards;
create policy baca on public.employee_cards for select to authenticated
  using (employee_id = public.saya() or public.admin_boleh('cetak_kartu'));

create or replace function public._kode_kartu()
returns text language plpgsql volatile set search_path = public as $$
declare a text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; s text;
begin
  loop
    s := '';
    for i in 1..10 loop s := s || substr(a, 1 + floor(random() * length(a))::int, 1); end loop;
    exit when not exists (select 1 from employee_cards where kode = s);
  end loop;
  return s;
end $$;

/** Data kartu. Tanpa argumen: kartu pegawai yang masuk. Dengan daftar id: admin ber-izin cetak_kartu. Kode dibuat bila belum ada. */
create or replace function public.data_kartu(p_emps uuid[] default null)
returns table (employee_id uuid, nama text, niy text, jenis_kelamin text, jabatan text, unit text, foto_id uuid,
               kode text, aktif boolean, tmt_tugas date)
language plpgsql volatile security definer set search_path = public as $$
declare v_ids uuid[];
begin
  if p_emps is null then v_ids := array[public.saya()];
  elsif public.admin_boleh('cetak_kartu') then v_ids := p_emps;
  else raise exception 'Anda tidak berwenang mencetak kartu pegawai lain.' using errcode = '42501';
  end if;
  insert into employee_cards (employee_id, kode)
  select x, public._kode_kartu() from unnest(v_ids) x
   where x is not null and not exists (select 1 from employee_cards c where c.employee_id = x)
  on conflict do nothing;
  return query
  select e.id, e.nama_lengkap, e.niy, e.jenis_kelamin,
         nullif(concat_ws(', ', (select string_agg(sp.nama, ', ') from employee_structurals es join structural_positions sp on sp.id = es.structural_position_id where es.employee_id = e.id),
                (select string_agg(fp.nama, ', ' order by fp.urutan) from employee_functions ef join functional_positions fp on fp.id = ef.functional_position_id where ef.employee_id = e.id)), ''),
         u.nama, e.foto_id, c.kode, e.status_keaktifan = 'aktif', e.tmt_tugas
    from employees e join employee_cards c on c.employee_id = e.id left join org_units u on u.id = e.org_unit_id
   where e.id = any (v_ids)
   order by u.nama nulls last, e.nama_lengkap;
end $$;

/** Ganti kode kartu (misalnya kartu hilang): kartu lama otomatis tidak berlaku. */
create or replace function public.ganti_kode_kartu(p_emp uuid)
returns text language plpgsql volatile security definer set search_path = public as $$
declare v text := public._kode_kartu();
begin
  if not (p_emp = public.saya() or public.admin_boleh('cetak_kartu')) then raise exception 'Tidak berwenang.' using errcode = '42501'; end if;
  insert into employee_cards (employee_id, kode) values (p_emp, v)
  on conflict (employee_id) do update set kode = excluded.kode, diganti_pada = now();
  perform public.catat_audit('ganti_kode_kartu', 'employee_cards', p_emp::text, 'Kode kartu pegawai diganti', null);
  return v;
end $$;

/** Pemeriksaan keabsahan kartu oleh siapa saja (pindai QR). Hanya data minimal yang ditampilkan. */
create or replace function public.cek_kartu(p_kode text)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce((
    select jsonb_build_object('ditemukan', true, 'nama', e.nama_lengkap, 'niy', e.niy, 'unit', u.nama,
             'jabatan', nullif(concat_ws(', ', (select string_agg(sp.nama, ', ') from employee_structurals es join structural_positions sp on sp.id = es.structural_position_id where es.employee_id = e.id),
                (select string_agg(fp.nama, ', ' order by fp.urutan) from employee_functions ef join functional_positions fp on fp.id = ef.functional_position_id where ef.employee_id = e.id)), ''),
             'berlaku', e.status_keaktifan = 'aktif',
             'lembaga', (select nilai->>'nama_lengkap' from institution_settings where kunci = 'identitas'))
      from employee_cards c join employees e on e.id = c.employee_id left join org_units u on u.id = e.org_unit_id
     where c.kode = upper(regexp_replace(coalesce(p_kode, ''), '[^A-Za-z0-9]', '', 'g'))),
    jsonb_build_object('ditemukan', false))
$$;

/** Pasang foto pegawai (pas foto kartu, bucket "profil"): pegawai sendiri, atau admin ber-izin cetak_kartu/kelola_pegawai. */
create or replace function public.pasang_foto(p_emp uuid, p_obj uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare o storage_objects; v_lama uuid;
begin
  if not (p_emp = public.saya() or public.admin_boleh('cetak_kartu') or public.admin_boleh('kelola_pegawai')) then
    raise exception 'Tidak berwenang mengganti foto pegawai ini.' using errcode = '42501';
  end if;
  select * into o from storage_objects where id = p_obj;
  if o.id is null or o.bucket <> 'profil' or o.kunci not like p_emp::text || '/%' then raise exception 'Berkas foto tidak sah.'; end if;
  select foto_id into v_lama from employees where id = p_emp;
  update employees set foto_id = p_obj where id = p_emp;
  if v_lama is not null and v_lama <> p_obj then update storage_objects set status = 'dihapus' where id = v_lama; end if;
end $$;

drop policy if exists "profil dikelola admin kartu" on storage.objects;
create policy "profil dikelola admin kartu" on storage.objects for all to authenticated
  using (bucket_id = 'profil' and (public.admin_boleh('cetak_kartu') or public.admin_boleh('kelola_pegawai')))
  with check (bucket_id = 'profil' and (public.admin_boleh('cetak_kartu') or public.admin_boleh('kelola_pegawai')));

-- ---------------------------------------------------------------------
-- 3. Hak lihat berkas (Edge Function "berkas"): pengajuan, jurnal, berkas pegawai, foto kartu
-- ---------------------------------------------------------------------
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
do $$
declare f text;
begin
  execute 'revoke execute on function public.boleh_lihat_berkas(uuid,uuid) from public, anon, authenticated';
  execute 'grant execute on function public.boleh_lihat_berkas(uuid,uuid) to service_role';
  execute 'revoke execute on function public._kode_kartu() from public, anon, authenticated';
  foreach f in array array['boleh_kelola_berkas()','simpan_berkas_pegawai(jsonb)','hapus_berkas_pegawai(uuid)','daftar_berkas_pegawai(boolean)',
    'catat_buka_berkas(uuid)','pembuka_berkas(uuid)','data_kartu(uuid[])','ganti_kode_kartu(uuid)','pasang_foto(uuid,uuid)']
  loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  -- Verifikasi kartu terbuka untuk umum (pemindai QR tidak perlu masuk)
  execute 'grant execute on function public.cek_kartu(text) to anon, authenticated';
end $$;
grant select on public.employee_documents, public.employee_document_targets, public.employee_cards to authenticated;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 5 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select 'Tabel berkas dan kartu (3)' as pemeriksaan,
       case when count(*) = 3 then 'Sesuai' else 'Periksa: ' || count(*) end as hasil
  from pg_tables where schemaname = 'public' and tablename in ('employee_documents','employee_document_targets','employee_cards')
union all
select 'RLS aktif di tabel baru',
       case when bool_and(rowsecurity) then 'Sesuai' else 'Periksa' end
  from pg_tables where schemaname = 'public' and tablename in ('employee_documents','employee_document_targets','employee_cards')
union all
select 'Fungsi berkas dan kartu (6)',
       case when count(*) = 6 then 'Sesuai' else 'Periksa: ' || count(*) end
  from pg_proc where pronamespace = 'public'::regnamespace
   and proname in ('simpan_berkas_pegawai','daftar_berkas_pegawai','catat_buka_berkas','data_kartu','ganti_kode_kartu','cek_kartu')
union all
select 'Verifikasi kartu dapat diakses tanpa masuk',
       case when has_function_privilege('anon', 'public.cek_kartu(text)', 'execute') then 'Sesuai' else 'Periksa' end
union all
select 'Migrasi 2100 sudah terpasang',
       case when exists (select 1 from pg_proc where proname = 'jurnal_saya') then 'Sesuai' else 'Periksa: jalankan 2100 dulu' end;
