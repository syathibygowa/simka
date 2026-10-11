-- SIMKA PRO | supabase/migrations/20261011007500_akses_sensitif.sql | v1.0 | Fase 11 – Tahap 6 Akses fitur sensitif (gaji dan keuangan) ditunjuk superadmin | 11/10/2026
-- =====================================================================
-- SIMKA PRO · Migrasi 75: Akses fitur sensitif
--   Pondok memiliki empat bendahara (Wustha, SMA, Pondok, Yayasan). Gaji ditangani Bendahara Yayasan,
--   keuangan santri oleh Bendahara Pondok. Karena itu jabatan "Bendahara" TIDAK LAGI otomatis membuka
--   gaji/keuangan. Hanya superadmin dan pegawai yang DITUNJUK superadmin yang dapat mengaksesnya.
--   * sensitive_access          : penunjukan per fitur (gaji | keuangan), tingkat kelola/lihat,
--                                 penanda tangan dokumen (slip/kuitansi/surat tagihan) dan jabatan tertulisnya
--   * boleh_kelola_gaji/lihat   : superadmin atau yang ditunjuk (izin admin kelola_gaji/lihat_gaji dipindah ke sini)
--   * boleh_kelola_keuangan/lihat : disiapkan untuk menu Keuangan (Fase 13)
--   * _pejabat_gaji('bendahara'): yang ditunjuk sebagai penanda tangan gaji (bukan lagi semua jabatan Bendahara)
--   * Fitur "slip_gaji" dan "keuangan_santri" dihapus dari Hak Akses Fitur (tidak dipakai lagi)
-- Jalankan SETELAH migrasi 7400. Aman dijalankan ulang.
-- PENTING: setelah dijalankan, superadmin menunjuk Bendahara Yayasan di Hak Akses → Fitur sensitif.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TABEL PENUNJUKAN
-- ---------------------------------------------------------------------
create table if not exists public.sensitive_access (
  id              uuid primary key default gen_random_uuid(),
  fitur           text not null constraint sensitive_access_fitur_check check (fitur in ('gaji','keuangan')),
  employee_id     uuid not null references public.employees(id) on delete cascade,
  tingkat         text not null default 'kelola' constraint sensitive_access_tingkat_check check (tingkat in ('kelola','lihat')),
  penanda_tangan  boolean not null default false,
  jabatan_ttd     text,
  catatan         text,
  ditunjuk_oleh   uuid references public.employees(id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint sensitive_access_unik unique (fitur, employee_id),
  constraint sensitive_access_ttd_kelola check (not penanda_tangan or tingkat = 'kelola')
);
alter table public.sensitive_access enable row level security;
drop policy if exists baca on public.sensitive_access;
create policy baca on public.sensitive_access for select to authenticated using (public.is_superadmin() or employee_id = public.saya());
drop trigger if exists zz_audit on public.sensitive_access;
create trigger zz_audit after insert or update or delete on public.sensitive_access for each row execute function public.tg_audit();

-- Tingkat akses seorang pegawai (null = tidak ditunjuk). Akun dan kepegawaian harus aktif.
create or replace function public._akses_sensitif(p_fitur text, p_emp uuid)
returns text language sql stable security definer set search_path = public as $$
  select sa.tingkat from sensitive_access sa join employees e on e.id = sa.employee_id
   where sa.fitur = p_fitur and sa.employee_id = p_emp and e.status_akun = 'aktif' and e.status_keaktifan = 'aktif'
$$;
revoke execute on function public._akses_sensitif(text,uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 2. HAK GAJI DAN KEUANGAN
-- ---------------------------------------------------------------------
create or replace function public.boleh_kelola_gaji()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_superadmin() or coalesce(public._akses_sensitif('gaji', public.saya()) = 'kelola', false)
$$;
create or replace function public.boleh_lihat_gaji()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_superadmin() or public._akses_sensitif('gaji', public.saya()) is not null
$$;
create or replace function public.boleh_kelola_keuangan()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_superadmin() or coalesce(public._akses_sensitif('keuangan', public.saya()) = 'kelola', false)
$$;
create or replace function public.boleh_lihat_keuangan()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_superadmin() or public._akses_sensitif('keuangan', public.saya()) is not null
$$;

-- Penanda tangan gaji (Bendahara Yayasan) = yang ditunjuk dan ditandai penanda tangan.
create or replace function public._pejabat_gaji(p_peran text)
returns setof uuid language sql stable security definer set search_path = public as $$
  select sa.employee_id from sensitive_access sa join employees e on e.id = sa.employee_id
   where p_peran = 'bendahara' and sa.fitur = 'gaji' and sa.penanda_tangan and sa.tingkat = 'kelola'
     and e.status_keaktifan = 'aktif' and e.status_akun = 'aktif'
  union
  select es.employee_id from employee_structurals es join structural_positions sp on sp.id = es.structural_position_id
    join employees e on e.id = es.employee_id
   where p_peran = 'direktur' and sp.kode = 'DIREKTUR' and e.status_keaktifan = 'aktif' and e.status_akun = 'aktif'
  union
  select a.employee_id from acting_assignments a join structural_positions sp on sp.id = a.structural_position_id
   where p_peran = 'direktur' and sp.kode = 'DIREKTUR'
     and (a.mulai is null or a.mulai <= public.hari_ini()) and (a.sampai is null or a.sampai >= public.hari_ini())
$$;

/** Jabatan tertulis penanda tangan sebuah fitur (mis. "Bendahara Yayasan"). */
create or replace function public._jabatan_ttd(p_fitur text, p_emp uuid)
returns text language sql stable security definer set search_path = public as $$
  select coalesce(nullif(trim((select jabatan_ttd from sensitive_access where fitur = p_fitur and employee_id = p_emp)), ''),
                  case p_fitur when 'gaji' then 'Bendahara Yayasan' else 'Bendahara Pondok' end)
$$;

create or replace function public._isi_ttd(p_period uuid, p_peran text, p_emp uuid)
returns void language sql volatile security definer set search_path = public as $$
  update payroll_signatures set status = 'ditandatangani', waktu = now(), employee_id = p_emp,
    nama = (select nama_lengkap from employees where id = p_emp), niy = (select niy from employees where id = p_emp),
    jabatan = case p_peran when 'bendahara' then public._jabatan_ttd('gaji', p_emp) else
      coalesce((select sp.nama from employee_structurals es join structural_positions sp on sp.id = es.structural_position_id
                 where es.employee_id = p_emp and sp.kode = 'DIREKTUR'), 'Plt. Direktur') end
  where period_id = p_period and peran = p_peran
$$;

create or replace function public.hak_gaji()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_slip boolean; v_ttd int; v_minta int; v_bend boolean;
begin
  v_slip := public.saya() is not null and (coalesce((public._pengaturan_gaji()->>'slip_pegawai')::boolean, false)
            or exists (select 1 from payroll_lines where employee_id = public.saya() and dibuka_pegawai and document_id is not null));
  select count(*) into v_ttd from payroll_signatures s join payroll_periods p on p.id = s.period_id
   where p.status = 'diajukan' and s.status = 'menunggu' and public.saya() in (select public._pejabat_gaji(s.peran));
  v_minta := case when public.boleh_kelola_gaji() then (select count(*) from payroll_slip_requests where status = 'menunggu') else 0 end;
  v_bend := public.saya() in (select public._pejabat_gaji('bendahara'));
  return jsonb_build_object('kelola', public.boleh_kelola_gaji(), 'lihat', public.boleh_lihat_gaji(), 'superadmin', public.is_superadmin(),
    'bendahara', v_bend, 'jabatan_ttd', case when v_bend then public._jabatan_ttd('gaji', public.saya()) end,
    'slip_saya', v_slip, 'ttd_menunggu', v_ttd, 'permintaan_menunggu', v_minta,
    'tampil', public.boleh_lihat_gaji() or v_slip or v_ttd > 0, 'pengaturan', public.pengaturan_gaji());
end $$;

-- ---------------------------------------------------------------------
-- 3. PINDAHKAN IZIN ADMIN LAMA, HAPUS JALUR LAMA
-- ---------------------------------------------------------------------
insert into public.sensitive_access (fitur, employee_id, tingkat, catatan)
select 'gaji', ap.employee_id, case when bool_or(ap.kode = 'kelola_gaji') then 'kelola' else 'lihat' end, 'Dipindah dari izin admin'
  from public.admin_permissions ap where ap.kode in ('kelola_gaji','lihat_gaji') group by ap.employee_id
on conflict (fitur, employee_id) do nothing;
delete from public.admin_permissions where kode in ('kelola_gaji','lihat_gaji');
delete from public.admin_capabilities where kode in ('kelola_gaji','lihat_gaji');
-- Hak fitur lama (jabatan Bendahara → slip_gaji/keuangan_santri tingkat 3) tidak berlaku lagi
delete from public.features where kode in ('slip_gaji','keuangan_santri');

-- Penerima notifikasi pengelola gaji: yang ditunjuk (bukan lagi izin admin kelola_gaji); pesan galat ajukan
do $$
declare f record; d text;
begin
  for f in select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.prosrc like '%ap.kode = ''kelola_gaji''%' loop
    d := pg_get_functiondef(f.oid);
    d := replace(d, 'select ap.employee_id from admin_permissions ap where ap.kode = ''kelola_gaji''',
                    'select sa.employee_id from sensitive_access sa where sa.fitur = ''gaji'' and sa.tingkat = ''kelola''');
    execute d;
  end loop;
  d := pg_get_functiondef('public.ajukan_periode_gaji(uuid)'::regprocedure);
  if position('memegang jabatan struktural Bendahara' in d) > 0 then
    execute replace(d, 'Belum ada pegawai berakun aktif yang memegang jabatan struktural Bendahara. Tetapkan dulu di Data Pegawai.',
                       'Superadmin belum menunjuk penanda tangan gaji (Bendahara Yayasan) di Hak Akses → Fitur sensitif.');
  end if;
  d := pg_get_functiondef('public.terbitkan_revisi_slip(uuid)'::regprocedure);
  execute replace(d, '''Revisi slip diterbitkan oleh Bendahara.''', '''Revisi slip diterbitkan oleh penanda tangan gaji yang ditunjuk superadmin.''');
end $$;

-- ---------------------------------------------------------------------
-- 4. KELOLA PENUNJUKAN (superadmin)
-- ---------------------------------------------------------------------
create or replace function public.daftar_akses_sensitif()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_superadmin() then raise exception 'Hanya superadmin yang mengatur akses fitur sensitif.' using errcode = '42501'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', sa.id, 'fitur', sa.fitur, 'employee_id', sa.employee_id, 'tingkat', sa.tingkat,
      'penanda_tangan', sa.penanda_tangan, 'jabatan_ttd', sa.jabatan_ttd, 'catatan', sa.catatan, 'created_at', sa.created_at,
      'niy', e.niy, 'nama', e.nama_lengkap, 'peran', e.peran, 'aktif', e.status_akun = 'aktif' and e.status_keaktifan = 'aktif',
      'jabatan', (select sp.nama from employee_structurals es join structural_positions sp on sp.id = es.structural_position_id where es.employee_id = e.id),
      'unit', (select nama from org_units where id = coalesce((select es.org_unit_id from employee_structurals es where es.employee_id = e.id), e.org_unit_id)),
      'ditunjuk_oleh', (select nama_lengkap from employees where id = sa.ditunjuk_oleh))
    order by sa.fitur, sa.penanda_tangan desc, e.nama_lengkap)
    from sensitive_access sa join employees e on e.id = sa.employee_id), '[]'::jsonb);
end $$;

create or replace function public.simpan_akses_sensitif(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid; e employees; v_fitur text := p->>'fitur'; v_tingkat text := coalesce(p->>'tingkat', 'kelola');
  v_ttd boolean := coalesce((p->>'penanda_tangan')::boolean, false); v_baru boolean;
begin
  if not public.is_superadmin() then raise exception 'Hanya superadmin yang mengatur akses fitur sensitif.' using errcode = '42501'; end if;
  if v_fitur not in ('gaji','keuangan') then raise exception 'Fitur tidak dikenal.'; end if;
  if v_tingkat not in ('kelola','lihat') then raise exception 'Tingkat akses tidak dikenal.'; end if;
  select * into e from employees where id = (p->>'employee_id')::uuid;
  if e.id is null then raise exception 'Pegawai tidak ditemukan.'; end if;
  if e.status_akun <> 'aktif' then raise exception '% belum memiliki akun aktif.', e.nama_lengkap; end if;
  if v_ttd and v_tingkat <> 'kelola' then raise exception 'Penanda tangan harus bertingkat kelola.'; end if;
  v_baru := not exists (select 1 from sensitive_access where fitur = v_fitur and employee_id = e.id);
  insert into sensitive_access (fitur, employee_id, tingkat, penanda_tangan, jabatan_ttd, catatan, ditunjuk_oleh)
  values (v_fitur, e.id, v_tingkat, v_ttd, nullif(trim(p->>'jabatan_ttd'), ''), nullif(trim(p->>'catatan'), ''), public.saya())
  on conflict (fitur, employee_id) do update set tingkat = excluded.tingkat, penanda_tangan = excluded.penanda_tangan,
    jabatan_ttd = excluded.jabatan_ttd, catatan = excluded.catatan, updated_at = now()
  returning id into v_id;
  if v_baru then
    perform public.kirim_notifikasi(e.id, 'Anda ditunjuk mengelola ' || case v_fitur when 'gaji' then 'gaji dan tunjangan' else 'keuangan santri' end,
      'Superadmin memberi Anda akses ' || case v_tingkat when 'kelola' then 'kelola' else 'lihat' end
        || case when v_ttd then ' sebagai penanda tangan dokumen' else '' end || '.',
      case v_fitur when 'gaji' then '/gaji' else '/keuangan' end, 'Key', 'hijau');
  end if;
  return v_id;
end $$;

create or replace function public.hapus_akses_sensitif(p_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  if not public.is_superadmin() then raise exception 'Hanya superadmin yang mengatur akses fitur sensitif.' using errcode = '42501'; end if;
  delete from sensitive_access where id = p_id;
end $$;

-- ---------------------------------------------------------------------
-- 5. HAK EKSEKUSI
-- ---------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array['daftar_akses_sensitif()','simpan_akses_sensitif(jsonb)','hapus_akses_sensitif(uuid)',
                           'boleh_kelola_gaji()','boleh_lihat_gaji()','boleh_kelola_keuangan()','boleh_lihat_keuangan()','hak_gaji()'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['_pejabat_gaji(text)','_jabatan_ttd(text,uuid)','_isi_ttd(uuid,text,uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 6. PEMERIKSAAN (hasil yang benar: baris 1–4 "Sesuai"; baris 5–6 informasi)
-- ---------------------------------------------------------------------
select '1. Tabel penunjukan akses sensitif' as pemeriksaan,
       case when exists (select 1 from pg_tables where tablename = 'sensitive_access' and rowsecurity) then 'Sesuai' else 'Periksa' end as hasil
union all select '2. Jabatan Bendahara tidak lagi membuka gaji',
       case when pg_get_functiondef('public.boleh_kelola_gaji()'::regprocedure) not like '%tingkat_fitur%' then 'Sesuai' else 'Periksa' end
union all select '3. Izin admin kelola_gaji/lihat_gaji dipindah',
       case when not exists (select 1 from admin_capabilities where kode in ('kelola_gaji','lihat_gaji')) then 'Sesuai' else 'Periksa' end
union all select '4. Notifikasi pengelola gaji memakai penunjukan',
       case when not exists (select 1 from pg_proc where prosrc like '%ap.kode = ''kelola_gaji''%') then 'Sesuai' else 'Periksa' end
union all select '5. Ditunjuk untuk gaji', (select count(*) || ' pegawai, ' || count(*) filter (where penanda_tangan) || ' penanda tangan' from sensitive_access where fitur = 'gaji')
union all select '6. Ditunjuk untuk keuangan', (select count(*) || ' pegawai, ' || count(*) filter (where penanda_tangan) || ' penanda tangan' from sensitive_access where fitur = 'keuangan');
