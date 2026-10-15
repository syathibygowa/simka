-- SIMKA PRO | supabase/migrations/20261017010400_audit_khusus_superadmin.sql | v1.0 | Perbaikan 13.6.0 Audit log khusus superadmin + ringkasan kategori | 15/10/2026
-- =====================================================================
-- SIMKA PRO · Migrasi 104: Audit log hanya untuk superadmin
--   * Log audit hanya dapat dibaca superadmin (sebelumnya: pegawai melihat log sendiri, admin ber-izin "audit_log" melihat semua).
--   * Izin admin "audit_log" dan fitur "audit_log" di Hak Akses dihapus (tidak lagi dapat diberikan).
--   * audit_daftar(...)   : daftar log dengan saringan banyak jenis data sekaligus (dipakai kartu kategori).
--   * ringkasan_audit(...): jumlah aktivitas per jenis data dan aksi pada rentang tanggal (untuk kartu statistik).
--   * audit_saya(...)     : tetap ada demi kompatibilitas, kini juga khusus superadmin.
-- Jalankan SETELAH migrasi 10300. Aman dijalankan ulang.
-- =====================================================================

-- 1. Kebijakan baca: khusus superadmin, 30 hari terakhir
drop policy if exists baca on public.audit_logs;
create policy baca on public.audit_logs for select to authenticated
  using (created_at > now() - interval '30 days' and public.is_superadmin());

-- 2. Hapus izin admin dan fitur audit_log (penugasan yang ada ikut terhapus)
delete from public.admin_permissions where kode = 'audit_log';
delete from public.admin_capabilities where kode = 'audit_log';
delete from public.feature_grants where feature_kode = 'audit_log';
delete from public.features where kode = 'audit_log';

-- 3. Daftar log (khusus superadmin)
create or replace function public.audit_daftar(p_mulai date default null, p_akhir date default null,
  p_pegawai uuid default null, p_tabel text[] default null, p_batas int default 1000)
returns table (id bigint, created_at timestamptz, employee_id uuid, pelaku text, aksi text, tabel text,
               data_id text, ringkasan text, data jsonb)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_superadmin() then
    raise exception 'Audit log hanya dapat dibuka oleh superadmin.' using errcode = '42501';
  end if;
  return query
  select l.id, l.created_at, l.employee_id, coalesce(e.nama_lengkap, 'Sistem'), l.aksi, l.tabel, l.data_id, l.ringkasan, l.data
    from audit_logs l left join employees e on e.id = l.employee_id
   where l.created_at > now() - interval '30 days'
     and (p_mulai is null or (l.created_at at time zone 'Asia/Makassar')::date >= p_mulai)
     and (p_akhir is null or (l.created_at at time zone 'Asia/Makassar')::date <= p_akhir)
     and (p_pegawai is null or l.employee_id = p_pegawai)
     and (p_tabel is null or cardinality(p_tabel) = 0 or coalesce(l.tabel, '') = any (p_tabel))
   order by l.created_at desc
   limit least(greatest(coalesce(p_batas, 1000), 1), 3000);
end $$;

-- 4. Ringkasan per jenis data dan aksi (khusus superadmin)
create or replace function public.ringkasan_audit(p_mulai date default null, p_akhir date default null, p_pegawai uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_superadmin() then
    raise exception 'Audit log hanya dapat dibuka oleh superadmin.' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('tabel', x.tabel, 'aksi', x.aksi, 'jumlah', x.n) order by x.n desc)
      from (select coalesce(l.tabel, '') tabel, l.aksi, count(*)::int n
              from audit_logs l
             where l.created_at > now() - interval '30 days'
               and (p_mulai is null or (l.created_at at time zone 'Asia/Makassar')::date >= p_mulai)
               and (p_akhir is null or (l.created_at at time zone 'Asia/Makassar')::date <= p_akhir)
               and (p_pegawai is null or l.employee_id = p_pegawai)
             group by 1, 2) x), '[]'::jsonb);
end $$;

-- 5. audit_saya: kompatibilitas, khusus superadmin
create or replace function public.audit_saya(p_mulai date default null, p_akhir date default null,
  p_pegawai uuid default null, p_tabel text default null, p_batas int default 300)
returns table (id bigint, created_at timestamptz, employee_id uuid, pelaku text, aksi text, tabel text,
               data_id text, ringkasan text, data jsonb)
language sql stable security definer set search_path = public as $$
  select * from public.audit_daftar(p_mulai, p_akhir, p_pegawai, case when p_tabel is null then null else array[p_tabel] end, p_batas)
$$;

do $$ declare f text; begin
  foreach f in array array['audit_daftar(date,date,uuid,text[],int)','ringkasan_audit(date,date,uuid)','audit_saya(date,date,uuid,text,int)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- PEMERIKSAAN — hasil yang benar: 3 baris "Sesuai"
select '1. Kebijakan baca audit log khusus superadmin' as pemeriksaan,
       case when (select qual from pg_policies where tablename = 'audit_logs' and policyname = 'baca') like '%is_superadmin%'
             and (select qual from pg_policies where tablename = 'audit_logs' and policyname = 'baca') not like '%saya()%'
            then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Izin admin dan fitur audit_log sudah dihapus',
       case when not exists (select 1 from admin_capabilities where kode = 'audit_log') and not exists (select 1 from features where kode = 'audit_log')
            then 'Sesuai' else 'Periksa' end
union all
select '3. Fungsi daftar dan ringkasan audit tersedia',
       case when (select count(*) from pg_proc where pronamespace = 'public'::regnamespace and proname in ('audit_daftar','ringkasan_audit')) = 2
            then 'Sesuai' else 'Periksa' end;
