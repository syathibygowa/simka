-- SIMKA PRO | supabase/migrations/20261004001900_pengumuman_dorong.sql | v1.0 | Fase 3 – Tahap 1 Pengumuman, audit log, notifikasi HP | 04/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 3 · Migrasi 19: Pengumuman, audit log, notifikasi dorong ke HP (web push)
--   * penerima_sasaran(sasaran)  : mesin sasaran bersama (dipakai juga oleh berkas dan agenda)
--   * announcements + announcement_targets : pengumuman dengan daftar penerima dan tanda dibaca
--   * audit_saya(...)             : audit log 30 hari sesuai peran, beserta nama pelaku
--   * push_subscriptions + push_queue : setiap notifikasi baru juga dikirim ke HP yang didaftarkan
--     (Edge Function "dorong"; kunci VAPID dibuat otomatis dan disimpan di skema privat)
-- Jalankan SETELAH migrasi 1800. Aman dijalankan ulang.
-- =====================================================================

create extension if not exists pg_net with schema extensions;
create schema if not exists privat;
revoke all on schema privat from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 1. Rahasia internal (tidak dapat dibaca aplikasi; hanya fungsi server)
-- ---------------------------------------------------------------------
create table if not exists privat.rahasia (
  kunci  text primary key,
  nilai  jsonb not null,
  diubah timestamptz not null default now()
);
insert into privat.rahasia (kunci, nilai) values
  ('dorong_token', to_jsonb(encode(extensions.gen_random_bytes(24), 'hex'))),
  ('url_supabase', to_jsonb('https://xtvoxjnivpugzztoevjh.supabase.co'::text))
on conflict (kunci) do nothing;

-- ---------------------------------------------------------------------
-- 2. Mesin sasaran bersama
--    Bentuk sasaran (jsonb):
--      {"jenis":"semua"}
--      {"jenis":"pilihan","unit":[uuid],"fungsional":[uuid],"struktural":[uuid],"jk":"L"|"P"|null,"pegawai":[uuid]}
--    Aturan: unit (beserta cabangnya), jabatan fungsional, dan struktural digabung;
--    bila ketiganya kosong berarti semua pegawai. Saringan jenis kelamin berlaku pada
--    kelompok itu. Pegawai tertentu selalu ikut. Hanya akun aktif dan pegawai aktif.
-- ---------------------------------------------------------------------
create or replace function public.penerima_sasaran(p jsonb)
returns setof uuid language plpgsql stable security definer set search_path = public as $$
declare
  v_unit uuid[] := coalesce((select array_agg(x::uuid) from jsonb_array_elements_text(p->'unit') x), '{}');
  v_fung uuid[] := coalesce((select array_agg(x::uuid) from jsonb_array_elements_text(p->'fungsional') x), '{}');
  v_str  uuid[] := coalesce((select array_agg(x::uuid) from jsonb_array_elements_text(p->'struktural') x), '{}');
  v_peg  uuid[] := coalesce((select array_agg(x::uuid) from jsonb_array_elements_text(p->'pegawai') x), '{}');
  v_jk   text   := nullif(p->>'jk', '');
  v_kelompok boolean := cardinality(v_unit) + cardinality(v_fung) + cardinality(v_str) > 0;
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
                         and (s.structural_position_id = any (v_str))))
       and (v_jk is null or a.jenis_kelamin = v_jk)
       and (coalesce(p->>'jenis', 'pilihan') = 'semua' or v_kelompok or v_jk is not null or cardinality(v_peg) = 0)
  )
  select id from kelompok
  union
  select a.id from aktif a where a.id = any (v_peg);
end $$;
-- Catatan: bila hanya "pegawai tertentu" yang dipilih, sasaran hanya orang-orang itu (bukan semua pegawai).

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
  if nullif(p->>'jk', '') is not null then
    bagian := bagian || case p->>'jk' when 'L' then 'khusus laki-laki' else 'khusus perempuan' end;
  end if;
  if jsonb_array_length(coalesce(p->'pegawai', '[]')) > 0 then
    bagian := bagian || (jsonb_array_length(p->'pegawai') || ' pegawai tertentu');
  end if;
  return coalesce(nullif(array_to_string(bagian, '; '), ''), 'Semua pegawai');
end $$;

-- ---------------------------------------------------------------------
-- 3. Pengumuman
-- ---------------------------------------------------------------------
create table if not exists public.announcements (
  id           uuid primary key default gen_random_uuid(),
  judul        text not null check (length(trim(judul)) between 3 and 150),
  isi          text not null check (length(trim(isi)) >= 3),
  penting      boolean not null default false,
  sasaran      jsonb not null default '{"jenis":"semua"}',
  ringkasan_sasaran text,
  tampil_sampai date,
  dibuat_oleh  uuid references public.employees(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists announcements_waktu_idx on public.announcements (created_at desc);

create table if not exists public.announcement_targets (
  announcement_id uuid not null references public.announcements(id) on delete cascade,
  employee_id     uuid not null references public.employees(id) on delete cascade,
  dibaca_pada     timestamptz,
  primary key (announcement_id, employee_id)
);
create index if not exists announcement_targets_emp_idx on public.announcement_targets (employee_id);

alter table public.announcements enable row level security;
alter table public.announcement_targets enable row level security;

drop trigger if exists aa_updated on public.announcements;
create trigger aa_updated before update on public.announcements for each row execute function public.tg_updated_at();
drop trigger if exists zz_audit on public.announcements;
create trigger zz_audit after insert or update or delete on public.announcements for each row execute function public.tg_audit();

create or replace function public.boleh_umumkan()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_admin() or public.tingkat_fitur('pengumuman') >= 2
$$;

drop policy if exists baca on public.announcements;
create policy baca on public.announcements for select to authenticated
  using (public.boleh_umumkan()
         or exists (select 1 from announcement_targets t where t.announcement_id = announcements.id and t.employee_id = public.saya()));
drop policy if exists baca on public.announcement_targets;
create policy baca on public.announcement_targets for select to authenticated
  using (employee_id = public.saya() or public.boleh_umumkan());
-- Penulisan hanya lewat fungsi di bawah (tidak ada kebijakan tulis untuk klien).

/** Terbitkan atau ubah pengumuman. Pengumuman baru: penerima dihitung dari sasaran dan diberi notifikasi. */
create or replace function public.simpan_pengumuman(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid := nullif(p->>'id', '')::uuid; v_jumlah int; v_penting boolean := coalesce((p->>'penting')::boolean, false);
begin
  if not public.boleh_umumkan() then raise exception 'Anda tidak berwenang membuat pengumuman.' using errcode = '42501'; end if;
  if length(trim(coalesce(p->>'judul', ''))) < 3 then raise exception 'Judul pengumuman minimal 3 karakter.'; end if;
  if length(trim(coalesce(p->>'isi', ''))) < 3 then raise exception 'Isi pengumuman belum diisi.'; end if;

  if v_id is not null then
    update announcements set judul = trim(p->>'judul'), isi = trim(p->>'isi'), penting = v_penting,
           tampil_sampai = nullif(p->>'tampil_sampai', '')::date
     where id = v_id;
    if not found then raise exception 'Pengumuman tidak ditemukan.'; end if;
    return v_id;
  end if;

  insert into announcements (judul, isi, penting, sasaran, ringkasan_sasaran, tampil_sampai, dibuat_oleh)
  values (trim(p->>'judul'), trim(p->>'isi'), v_penting, coalesce(p->'sasaran', '{"jenis":"semua"}'),
          public.ringkas_sasaran(coalesce(p->'sasaran', '{"jenis":"semua"}')),
          nullif(p->>'tampil_sampai', '')::date, public.saya())
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

create or replace function public.hapus_pengumuman(p_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  if not public.boleh_umumkan() then raise exception 'Anda tidak berwenang menghapus pengumuman.' using errcode = '42501'; end if;
  delete from announcements where id = p_id;
  delete from notifications where tautan = '/pengumuman/' || p_id;
end $$;

create or replace function public.baca_pengumuman(p_id uuid)
returns void language sql volatile security definer set search_path = public as $$
  update announcement_targets set dibaca_pada = now()
   where announcement_id = p_id and employee_id = public.saya() and dibaca_pada is null;
  update notifications set dibaca_pada = now()
   where employee_id = public.saya() and tautan = '/pengumuman/' || p_id and dibaca_pada is null;
$$;

/** Daftar pengumuman untuk pengguna; mode "kelola" (pembuat pengumuman) menampilkan semua beserta jumlah dibaca. */
create or replace function public.daftar_pengumuman(p_kelola boolean default false)
returns table (id uuid, judul text, isi text, penting boolean, ringkasan_sasaran text, tampil_sampai date,
               created_at timestamptz, updated_at timestamptz, pembuat text, dibaca_pada timestamptz,
               penerima int, sudah_dibaca int, saya_penerima boolean)
language sql stable security definer set search_path = public as $$
  select a.id, a.judul, a.isi, a.penting, a.ringkasan_sasaran, a.tampil_sampai, a.created_at, a.updated_at,
         e.nama_lengkap, t.dibaca_pada,
         case when p_kelola and public.boleh_umumkan() then (select count(*)::int from announcement_targets x where x.announcement_id = a.id) end,
         case when p_kelola and public.boleh_umumkan() then (select count(*)::int from announcement_targets x where x.announcement_id = a.id and x.dibaca_pada is not null) end,
         t.employee_id is not null
    from announcements a
    left join employees e on e.id = a.dibuat_oleh
    left join announcement_targets t on t.announcement_id = a.id and t.employee_id = public.saya()
   where (p_kelola and public.boleh_umumkan()) or t.employee_id is not null
   order by a.created_at desc
   limit 300
$$;

/** Siapa saja penerima sebuah pengumuman dan apakah sudah membaca (pembuat pengumuman). */
create or replace function public.pembaca_pengumuman(p_id uuid)
returns table (employee_id uuid, nama text, unit text, dibaca_pada timestamptz)
language sql stable security definer set search_path = public as $$
  select t.employee_id, e.nama_lengkap, u.nama, t.dibaca_pada
    from announcement_targets t join employees e on e.id = t.employee_id
    left join org_units u on u.id = e.org_unit_id
   where t.announcement_id = p_id and public.boleh_umumkan()
   order by t.dibaca_pada nulls first, e.nama_lengkap
$$;

-- Pratinjau jumlah penerima sebelum diterbitkan
create or replace function public.hitung_sasaran(p jsonb)
returns int language sql stable security definer set search_path = public as $$
  select case when public.boleh_umumkan() then (select count(*)::int from public.penerima_sasaran(p)) else 0 end
$$;

-- ---------------------------------------------------------------------
-- 4. Audit log: 30 hari terakhir sesuai peran, beserta nama pelaku
--    Pegawai: aktivitasnya sendiri. Admin ber-izin audit_log dan superadmin: semua.
-- ---------------------------------------------------------------------
create or replace function public.audit_saya(p_mulai date default null, p_akhir date default null,
  p_pegawai uuid default null, p_tabel text default null, p_batas int default 300)
returns table (id bigint, created_at timestamptz, employee_id uuid, pelaku text, aksi text, tabel text,
               data_id text, ringkasan text, data jsonb)
language sql stable security definer set search_path = public as $$
  select l.id, l.created_at, l.employee_id, coalesce(e.nama_lengkap, 'Sistem'), l.aksi, l.tabel, l.data_id, l.ringkasan, l.data
    from audit_logs l left join employees e on e.id = l.employee_id
   where l.created_at > now() - interval '30 days'
     and (l.employee_id = public.saya() or public.admin_boleh('audit_log'))
     and (p_mulai is null or (l.created_at at time zone 'Asia/Makassar')::date >= p_mulai)
     and (p_akhir is null or (l.created_at at time zone 'Asia/Makassar')::date <= p_akhir)
     and (p_pegawai is null or l.employee_id = p_pegawai)
     and (p_tabel is null or l.tabel = p_tabel)
   order by l.created_at desc
   limit least(greatest(coalesce(p_batas, 300), 1), 2000)
$$;

-- ---------------------------------------------------------------------
-- 5. Notifikasi dorong (web push)
-- ---------------------------------------------------------------------
create table if not exists public.push_subscriptions (
  id          uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees(id) on delete cascade,
  endpoint    text not null unique,
  p256dh      text not null,
  auth        text not null,
  perangkat   text,
  created_at  timestamptz not null default now(),
  terakhir_ok timestamptz
);
create index if not exists push_subscriptions_emp_idx on public.push_subscriptions (employee_id);
alter table public.push_subscriptions enable row level security;
drop policy if exists baca_sendiri on public.push_subscriptions;
create policy baca_sendiri on public.push_subscriptions for select to authenticated using (employee_id = public.saya());

create table if not exists public.push_queue (
  id              bigint generated always as identity primary key,
  notification_id uuid not null references public.notifications(id) on delete cascade,
  percobaan       int not null default 0,
  created_at      timestamptz not null default now()
);
alter table public.push_queue enable row level security;   -- tanpa kebijakan: tertutup untuk klien

create or replace function public.daftar_dorong(p_endpoint text, p_p256dh text, p_auth text, p_perangkat text default null)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  if public.saya() is null then raise exception 'Sesi tidak ditemukan. Silakan masuk kembali.' using errcode = '42501'; end if;
  if p_endpoint !~ '^https://' then raise exception 'Alamat langganan tidak sah.'; end if;
  insert into push_subscriptions (employee_id, endpoint, p256dh, auth, perangkat)
  values (public.saya(), p_endpoint, p_p256dh, p_auth, left(p_perangkat, 120))
  on conflict (endpoint) do update set employee_id = excluded.employee_id, p256dh = excluded.p256dh,
         auth = excluded.auth, perangkat = excluded.perangkat, created_at = now();
end $$;

create or replace function public.hapus_dorong(p_endpoint text)
returns void language sql volatile security definer set search_path = public as $$
  delete from push_subscriptions where endpoint = p_endpoint and employee_id = public.saya();
$$;

create or replace function public.kunci_dorong()
returns text language sql stable security definer set search_path = public, privat as $$
  select nilai->>'publik' from privat.rahasia where kunci = 'vapid'
$$;

/** Memanggil Edge Function "dorong" (tidak menunggu hasil). Galat jaringan tidak menggagalkan transaksi. */
create or replace function public._panggil_dorong()
returns void language plpgsql volatile security definer set search_path = public, privat as $$
declare v_url text; v_token text;
begin
  select nilai #>> '{}' into v_url from privat.rahasia where kunci = 'url_supabase';
  select nilai #>> '{}' into v_token from privat.rahasia where kunci = 'dorong_token';
  if v_url is null or v_token is null then return; end if;
  perform net.http_post(url := v_url || '/functions/v1/dorong', body := '{"aksi":"kirim"}'::jsonb,
                        headers := jsonb_build_object('Content-Type', 'application/json', 'x-simka-token', v_token),
                        timeout_milliseconds := 10000);
exception when others then
  raise warning 'Panggilan dorong gagal: %', sqlerrm;
end $$;

create or replace function public.tg_notifikasi_dorong()
returns trigger language plpgsql security definer set search_path = public as $$
declare n int;
begin
  insert into push_queue (notification_id)
  select b.id from baru b where exists (select 1 from push_subscriptions s where s.employee_id = b.employee_id);
  get diagnostics n = row_count;
  if n > 0 then perform public._panggil_dorong(); end if;
  return null;
end $$;
drop trigger if exists zz_dorong on public.notifications;
create trigger zz_dorong after insert on public.notifications
  referencing new table as baru for each statement execute function public.tg_notifikasi_dorong();

-- Fungsi untuk Edge Function "dorong" (hanya service_role)
create or replace function public._dorong_rahasia()
returns jsonb language sql stable security definer set search_path = public, privat as $$
  select jsonb_object_agg(kunci, nilai) from privat.rahasia where kunci in ('dorong_token', 'vapid')
$$;
create or replace function public._dorong_simpan_kunci(p jsonb)
returns text language plpgsql volatile security definer set search_path = public, privat as $$
begin
  insert into privat.rahasia (kunci, nilai) values ('vapid', p) on conflict (kunci) do nothing;
  return (select nilai->>'publik' from privat.rahasia where kunci = 'vapid');
end $$;
create or replace function public._dorong_ambil(p_batas int default 300)
returns table (antrian_id bigint, endpoint text, p256dh text, auth text, judul text, isi text, tautan text, notif_id uuid, penting boolean)
language plpgsql volatile security definer set search_path = public as $$
begin
  return query
  with ambil as (
    update push_queue q set percobaan = q.percobaan + 1
     where q.id in (select x.id from push_queue x where x.percobaan < 3 order by x.id limit p_batas for update skip locked)
    returning q.id, q.notification_id
  )
  select a.id, s.endpoint, s.p256dh, s.auth, n.judul, n.isi, n.tautan, n.id, n.warna = 'merah'
    from ambil a join notifications n on n.id = a.notification_id
    join push_subscriptions s on s.employee_id = n.employee_id;
end $$;
create or replace function public._dorong_selesai(p_antrian bigint[], p_ok text[], p_hilang text[])
returns void language sql volatile security definer set search_path = public as $$
  delete from push_queue where id = any (p_antrian);
  update push_subscriptions set terakhir_ok = now() where endpoint = any (p_ok);
  delete from push_subscriptions where endpoint = any (p_hilang);
$$;

-- Penyapu: antrian yang tertinggal dikirim ulang tiap 2 menit; antrian > 1 hari dibuang
create or replace function public.sapu_antrian_dorong()
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  delete from push_queue where created_at < now() - interval '1 day' or percobaan >= 3;
  if exists (select 1 from push_queue where created_at < now() - interval '1 minute') then
    perform public._panggil_dorong();
  end if;
end $$;
select cron.schedule('sapu-antrian-dorong', '*/2 * * * *', $$ select public.sapu_antrian_dorong() $$);

-- ---------------------------------------------------------------------
-- 6. Hak eksekusi
-- ---------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array['penerima_sasaran(jsonb)','ringkas_sasaran(jsonb)','_panggil_dorong()','tg_notifikasi_dorong()',
    '_dorong_rahasia()','_dorong_simpan_kunci(jsonb)','_dorong_ambil(int)','_dorong_selesai(bigint[],text[],text[])','sapu_antrian_dorong()']
  loop execute format('revoke execute on function public.%s from public, anon, authenticated', f); end loop;
  foreach f in array array['_dorong_rahasia()','_dorong_simpan_kunci(jsonb)','_dorong_ambil(int)','_dorong_selesai(bigint[],text[],text[])']
  loop execute format('grant execute on function public.%s to service_role', f); end loop;
  foreach f in array array['simpan_pengumuman(jsonb)','hapus_pengumuman(uuid)','baca_pengumuman(uuid)','daftar_pengumuman(boolean)',
    'pembaca_pengumuman(uuid)','hitung_sasaran(jsonb)','boleh_umumkan()','audit_saya(date,date,uuid,text,int)',
    'daftar_dorong(text,text,text,text)','hapus_dorong(text)','kunci_dorong()']
  loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
grant select on public.announcements, public.announcement_targets, public.push_subscriptions to authenticated;

do $$ begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'announcements') then
    alter publication supabase_realtime add table public.announcements;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 6 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select 'Tabel pengumuman dan dorong (4)' as pemeriksaan,
       case when count(*) = 4 then 'Sesuai' else 'Periksa: ' || count(*) end as hasil
  from pg_tables where schemaname = 'public'
   and tablename in ('announcements','announcement_targets','push_subscriptions','push_queue')
union all
select 'RLS aktif di tabel baru',
       case when bool_and(rowsecurity) then 'Sesuai' else 'Periksa' end
  from pg_tables where schemaname = 'public'
   and tablename in ('announcements','announcement_targets','push_subscriptions','push_queue')
union all
select 'Fungsi pengumuman, audit, dorong (11)',
       case when count(*) = 11 then 'Sesuai' else 'Periksa: ' || count(*) end
  from pg_proc where pronamespace = 'public'::regnamespace
   and proname in ('penerima_sasaran','simpan_pengumuman','hapus_pengumuman','baca_pengumuman','daftar_pengumuman',
                   'pembaca_pengumuman','hitung_sasaran','audit_saya','daftar_dorong','hapus_dorong','kunci_dorong')
union all
select 'Ekstensi pg_net aktif',
       case when exists (select 1 from pg_extension where extname = 'pg_net') then 'Sesuai' else 'Periksa: aktifkan pg_net' end
union all
select 'Pemicu notifikasi ke HP',
       case when exists (select 1 from pg_trigger where tgname = 'zz_dorong') then 'Sesuai' else 'Periksa' end
union all
select 'Jadwal penyapu antrian pg_cron',
       case when exists (select 1 from cron.job where jobname = 'sapu-antrian-dorong') then 'Sesuai' else 'Periksa' end;
