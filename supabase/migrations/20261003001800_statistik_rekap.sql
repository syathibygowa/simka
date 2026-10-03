-- SIMKA PRO | supabase/migrations/20261003001800_statistik_rekap.sql | v1.0 | Fase 2 – Tahap 7 Statistik, rekap, pengingat | 03/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 2 · Migrasi 18: Statistik presensi langsung, rekap harian/periode, pengingat sesi
--   * statistik_presensi(tanggal) : kartu statistik beranda admin/superadmin (diperbarui lewat Realtime)
--   * rekap_harian(tanggal)       : semua sesi semua pegawai pada satu tanggal (termasuk yang belum presensi)
--   * rekap_presensi(mulai, akhir): ringkasan per pegawai pada satu periode (dasar cetak F4 bulanan)
--   * kirim_pengingat_presensi()  : notifikasi aplikasi X menit sebelum jendela presensi dibuka (pg_cron tiap 5 menit)
-- Laporan lengkap semua cakupan, PDF bertanda tangan elektronik, dan QR tetap di Fase 8.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Statistik presensi satu hari (admin dan superadmin)
-- ---------------------------------------------------------------------
create or replace function public.statistik_presensi(p_tanggal date default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_tgl date := coalesce(p_tanggal, (now() at time zone 'Asia/Makassar')::date); v jsonb;
begin
  if not public.is_admin() then raise exception 'Hanya admin yang dapat melihat statistik presensi.' using hint = 'TANPA_IZIN'; end if;
  with j as (
    select e.id as emp, x.session_id, x.nama_pola, x.buka, x.tutup
      from employees e cross join lateral public.jadwal_pegawai(e.id, v_tgl) x
     where e.status_akun = 'aktif' and e.status_keaktifan = 'aktif' and not x.opsional
  ), a as (
    select employee_id as emp, session_id, nama_pola, status from attendances where tanggal = v_tgl and not opsional
  ), g as (
    select coalesce(j.emp, a.emp) as emp, coalesce(j.nama_pola, a.nama_pola) as pola, a.status, j.buka, j.tutup
      from j full join a on a.emp = j.emp and a.session_id = j.session_id
  )
  select jsonb_build_object(
    'tanggal', v_tgl, 'waktu', now(),
    'pegawai_terjadwal', count(distinct emp),
    'pegawai_hadir', count(distinct emp) filter (where status in ('hadir','terlambat','dinas_luar')),
    'sesi_wajib', count(*),
    'sesi_tercatat', count(*) filter (where status is not null),
    'hadir', count(*) filter (where status = 'hadir'),
    'terlambat', count(*) filter (where status = 'terlambat'),
    'dinas_luar', count(*) filter (where status = 'dinas_luar'),
    'izin_sakit_cuti', count(*) filter (where status in ('izin','sakit','cuti')),
    'menunggu_verval', count(*) filter (where status = 'menunggu_verval'),
    'tanpa_keterangan', count(*) filter (where status = 'tanpa_keterangan'),
    'terbuka_belum', count(*) filter (where status is null and now() between buka and tutup),
    'terlewat_belum', count(*) filter (where status is null and now() > tutup),
    'akan_datang', count(*) filter (where status is null and now() < buka),
    'persen_kehadiran', case when count(*) filter (where status is not null or now() > tutup) = 0 then null
      else round(100.0 * count(*) filter (where status in ('hadir','terlambat','dinas_luar'))
                 / count(*) filter (where status is not null or now() > tutup), 1) end,
    'per_pola', coalesce((select jsonb_agg(jsonb_build_object('pola', pola, 'wajib', n, 'hadir', h) order by n desc)
                  from (select pola, count(*) n, count(*) filter (where status in ('hadir','terlambat','dinas_luar')) h from g group by pola) z), '[]'::jsonb),
    'verval_menunggu', (select count(*) from attendances where status = 'menunggu_verval' or status_pulang = 'menunggu_verval'),
    'curiga_baru', (select count(*) from suspicion_flags where status = 'baru')
  ) into v from g;
  return v;
end $$;

-- ---------------------------------------------------------------------
-- 2. Rekap harian: semua sesi semua pegawai pada satu tanggal
-- ---------------------------------------------------------------------
create or replace function public.rekap_harian(p_tanggal date)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v jsonb;
begin
  if not public.is_admin() then raise exception 'Hanya admin yang dapat melihat rekap harian.' using hint = 'TANPA_IZIN'; end if;
  with j as (
    select e.id as emp, x.* from employees e cross join lateral public.jadwal_pegawai(e.id, p_tanggal) x
     where e.status_akun = 'aktif' and e.status_keaktifan = 'aktif'
  ), a as (select * from attendances where tanggal = p_tanggal)
  select coalesce(jsonb_agg(jsonb_build_object(
      'employee_id', coalesce(j.emp, a.employee_id), 'nama', e.nama_lengkap, 'niy', e.niy, 'unit', u.nama, 'org_unit_id', e.org_unit_id,
      'nama_pola', coalesce(j.nama_pola, a.nama_pola), 'nama_sesi', coalesce(j.nama_sesi, a.nama_sesi),
      'mulai', coalesce(j.mulai, a.jadwal_mulai), 'selesai', coalesce(j.selesai, a.jadwal_selesai),
      'opsional', coalesce(j.opsional, a.opsional), 'wajib_pulang', coalesce(j.wajib_pulang, a.wajib_pulang),
      'attendance_id', a.id, 'status', a.status, 'terlambat_menit', a.terlambat_menit, 'datang_pada', a.datang_pada,
      'pulang_pada', a.pulang_pada, 'status_pulang', a.status_pulang, 'cepat_pulang_menit', a.cepat_pulang_menit, 'keterangan', a.keterangan,
      'keadaan', case when a.id is not null then 'tercatat' when now() < j.buka then 'akan_datang'
                      when now() <= j.tutup then 'terbuka' else 'terlewat' end)
      order by e.nama_lengkap, coalesce(j.mulai, a.jadwal_mulai)), '[]'::jsonb)
    into v
    from j full join a on a.employee_id = j.emp and a.session_id = j.session_id
    join employees e on e.id = coalesce(j.emp, a.employee_id)
    left join org_units u on u.id = e.org_unit_id;
  return v;
end $$;

-- ---------------------------------------------------------------------
-- 3. Rekap periode per pegawai (admin: semua; pimpinan: bawahannya; pegawai: dirinya)
--    Dihitung dari data presensi yang tercatat. Sesi tanpa presensi masuk hitungan
--    sebagai "Tanpa keterangan" setelah penutupan otomatis diaktifkan.
-- ---------------------------------------------------------------------
create or replace function public.rekap_presensi(p_mulai date, p_akhir date)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v jsonb; v_saya uuid := public.saya(); v_admin boolean := public.is_admin();
begin
  if v_saya is null then raise exception 'Akun Anda belum aktif.' using hint = 'AKUN_TIDAK_AKTIF'; end if;
  if p_akhir < p_mulai or p_akhir - p_mulai > 92 then raise exception 'Rentang rekap paling lama 3 bulan.' using hint = 'RENTANG_TIDAK_SAH'; end if;
  select coalesce(jsonb_agg(x order by x->>'nama'), '[]'::jsonb) into v from (
    select jsonb_build_object(
      'employee_id', e.id, 'nama', e.nama_lengkap, 'niy', e.niy, 'unit', u.nama, 'org_unit_id', e.org_unit_id,
      'jabatan', (select string_agg(fp.nama, ', ' order by fp.urutan) from employee_functions ef join functional_positions fp on fp.id = ef.functional_position_id where ef.employee_id = e.id),
      'sesi', count(a.id),
      'hadir', count(a.id) filter (where a.status = 'hadir'),
      'terlambat', count(a.id) filter (where a.status = 'terlambat'),
      'dinas_luar', count(a.id) filter (where a.status = 'dinas_luar'),
      'izin', count(a.id) filter (where a.status = 'izin'),
      'sakit', count(a.id) filter (where a.status = 'sakit'),
      'cuti', count(a.id) filter (where a.status = 'cuti'),
      'tanpa_keterangan', count(a.id) filter (where a.status = 'tanpa_keterangan'),
      'menunggu', count(a.id) filter (where a.status = 'menunggu_verval'),
      'menit_terlambat', coalesce(sum(a.terlambat_menit) filter (where a.status = 'terlambat'), 0),
      'pulang_cepat', count(a.id) filter (where a.status_pulang = 'cepat'),
      'tidak_presensi_pulang', count(a.id) filter (where a.status_pulang = 'tidak_presensi'),
      'persen', case when count(a.id) = 0 then null
                     else round(100.0 * count(a.id) filter (where a.status in ('hadir','terlambat','dinas_luar')) / count(a.id), 1) end) x
      from employees e
      left join org_units u on u.id = e.org_unit_id
      left join attendances a on a.employee_id = e.id and a.tanggal between p_mulai and p_akhir and not a.opsional
     where e.status_akun = 'aktif' and e.status_keaktifan = 'aktif'
       and (v_admin or e.id = v_saya or public.pimpinan_dari(e.id))
     group by e.id, u.nama
  ) q;
  return v;
end $$;

-- ---------------------------------------------------------------------
-- 4. Pengingat sesi (notifikasi aplikasi; notifikasi dorong ke HP menyusul di Fase 3)
-- ---------------------------------------------------------------------
create table if not exists public.attendance_reminders (
  employee_id uuid not null references public.employees(id) on delete cascade,
  tanggal     date not null,
  session_id  uuid not null references public.pattern_sessions(id) on delete cascade,
  dikirim_pada timestamptz not null default now(),
  primary key (employee_id, tanggal, session_id)
);
alter table public.attendance_reminders enable row level security;   -- tanpa kebijakan: hanya fungsi server

create or replace function public.kirim_pengingat_presensi()
returns int language plpgsql volatile security definer set search_path = public as $$
declare v_menit int := coalesce((public.pengaturan_presensi()->>'pengingat_menit')::int, 0); n int := 0;
        v_hari date := (now() at time zone 'Asia/Makassar')::date;
begin
  delete from attendance_reminders where tanggal < v_hari - 3;
  if v_menit <= 0 then return 0; end if;
  with calon as (
    select e.id as emp, j.tanggal, j.session_id, j.nama_sesi, j.buka, j.label_datang
      from employees e
      cross join generate_series(v_hari::timestamp, (v_hari + 1)::timestamp, interval '1 day') d
      cross join lateral public.jadwal_pegawai(e.id, d::date) j
     where e.status_akun = 'aktif' and e.status_keaktifan = 'aktif' and e.user_id is not null
       and not j.opsional
       and now() >= j.buka - make_interval(mins => v_menit) and now() < j.buka
       and not exists (select 1 from attendances a where a.employee_id = e.id and a.session_id = j.session_id and a.tanggal = j.tanggal)
       and not exists (select 1 from attendance_reminders r where r.employee_id = e.id and r.session_id = j.session_id and r.tanggal = j.tanggal)
  ), catat as (
    insert into attendance_reminders (employee_id, tanggal, session_id)
    select emp, tanggal, session_id from calon on conflict do nothing returning employee_id, tanggal, session_id
  )
  insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
  select c.emp, 'Presensi segera dibuka',
         c.nama_sesi || ': presensi ' || lower(coalesce(c.label_datang, 'datang')) || ' dibuka pukul '
           || to_char(c.buka at time zone 'Asia/Makassar', 'HH24.MI') || ' WITA.',
         '/presensi', 'Clock', 'hijau'
    from calon c join catat k on k.employee_id = c.emp and k.session_id = c.session_id and k.tanggal = c.tanggal;
  get diagnostics n = row_count;
  return n;
end $$;

select cron.schedule('pengingat-presensi', '*/5 * * * *', $$ select public.kirim_pengingat_presensi() $$);

-- ---------------------------------------------------------------------
-- Hak eksekusi
-- ---------------------------------------------------------------------
revoke execute on function public.statistik_presensi(date) from public, anon;
revoke execute on function public.rekap_harian(date) from public, anon;
revoke execute on function public.rekap_presensi(date, date) from public, anon;
revoke execute on function public.kirim_pengingat_presensi() from public, anon, authenticated;
grant execute on function public.statistik_presensi(date) to authenticated;
grant execute on function public.rekap_harian(date) to authenticated;
grant execute on function public.rekap_presensi(date, date) to authenticated;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 3 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select 'Fungsi statistik, rekap, pengingat (4)' as pemeriksaan,
       case when count(*) = 4 then 'Sesuai' else 'Periksa: ' || count(*) end as hasil
  from pg_proc where pronamespace = 'public'::regnamespace
   and proname in ('statistik_presensi','rekap_harian','rekap_presensi','kirim_pengingat_presensi')
union all
select 'Jadwal pengingat pg_cron',
       case when exists (select 1 from cron.job where jobname = 'pengingat-presensi') then 'Sesuai' else 'Periksa' end
union all
select 'Migrasi 1700 sudah terpasang',
       case when exists (select 1 from pg_proc where proname = 'verval_presensi') then 'Sesuai' else 'Periksa: jalankan 1700 dulu' end;
