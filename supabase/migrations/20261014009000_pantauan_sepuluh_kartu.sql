-- SIMKA PRO | supabase/migrations/20261014009000_pantauan_sepuluh_kartu.sql | v1.0 | Perbaikan: data tambahan Layar Pantauan (10 kartu per slide) | 14/10/2026
-- Layar Pantauan v12.7:
--   * pegawai_sesi : kehadiran setiap pegawai per sesi kerja pada tanggal itu (mis. musyrif hadir pagi dan hadir malam).
--   * grup         : rekap kelompok aktif (kelas, kamar, halaqah, ekskul) — nama, putra/putri, jenjang, pengasuh berlaku,
--                    jumlah santri L/P pada tanggal itu; dipakai kartu "Jumlah kelas/kamar/halaqah" dan cetak rekapnya.
-- Fungsi pantauan_langsung(date) versi 8900 diganti nama menjadi _pantauan_dasar(date) (tidak dapat dipanggil langsung),
-- lalu pantauan_langsung(date) baru menambahkan kedua data di atas. Aman dijalankan ulang.
-- Prasyarat: migrasi 8900 sudah terpasang.

do $$
begin
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = '_pantauan_dasar') then
    alter function public.pantauan_langsung(date) rename to _pantauan_dasar;
  end if;
end $$;
revoke execute on function public._pantauan_dasar(date) from public, anon, authenticated;

create or replace function public.pantauan_langsung(p_tanggal date default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_dasar jsonb; v_hari date; v_kini timestamptz; v_sesi_peg jsonb; v_grup jsonb;
begin
  v_dasar := public._pantauan_dasar(p_tanggal);           -- memeriksa hak akses dan tanggal
  v_hari := (v_dasar->>'tanggal')::date; v_kini := (v_dasar->>'waktu')::timestamptz;

  -- ---------- Kehadiran pegawai per sesi kerja ----------
  with j as materialized (
    select e.id emp, x.session_id, x.nama_sesi, x.mulai, x.buka from employees e cross join lateral public.jadwal_pegawai(e.id, v_hari) x
     where e.status_akun = 'aktif' and e.status_keaktifan = 'aktif' and not x.opsional
  ), a as materialized (
    select employee_id emp, session_id, status, datang_pada, pulang_pada from attendances where tanggal = v_hari and not opsional
  )
  select coalesce(jsonb_object_agg(emp, daftar), '{}'::jsonb) into v_sesi_peg from (
    select j.emp::text emp, jsonb_agg(jsonb_build_object('n', j.nama_sesi, 'mulai', to_char(j.mulai at time zone 'Asia/Makassar', 'HH24:MI'),
             'st', case when a.status is not null and (a.datang_pada is null or a.datang_pada <= v_kini) then a.status
                        when v_kini < j.buka then 'akan_datang' else 'belum' end,
             'datang', case when a.datang_pada <= v_kini then a.datang_pada end, 'pulang', case when a.pulang_pada <= v_kini then a.pulang_pada end) order by j.mulai) daftar
      from j left join a on a.emp = j.emp and a.session_id = j.session_id
     group by j.emp) q;

  -- ---------- Rekap kelompok aktif pada tanggal itu ----------
  select coalesce(jsonb_agg(jsonb_build_object('id', g.id, 'jenis', g.jenis, 'nama', g.nama, 'jk', g.jenis_kelamin, 'jenjang', g.jenjang, 'tingkat', g.tingkat,
      'pengasuh', (select string_agg(e.nama_lengkap, ', ' order by e.nama_lengkap) from employees e where e.id in (select public._pengasuh_berlaku(g.id, v_hari))),
      'l', m.l, 'p', m.p) order by g.jenis, g.urutan nulls last, g.nama), '[]'::jsonb)
    into v_grup
    from student_groups g join academic_years ay on ay.id = g.academic_year_id and ay.aktif
    cross join lateral (select count(*) filter (where s.jenis_kelamin = 'L') l, count(*) filter (where s.jenis_kelamin = 'P') p
                          from public._anggota_pada(g.id, v_hari) x join students s on s.id = x and s.status = 'aktif') m
   where g.aktif and g.jenis in ('kelas','kamar','halaqah','ekskul');

  return v_dasar || jsonb_build_object('pegawai_sesi', v_sesi_peg, 'grup', v_grup);
end $$;

do $$ begin
  execute 'revoke execute on function public.pantauan_langsung(date) from public, anon';
  execute 'grant execute on function public.pantauan_langsung(date) to authenticated';
end $$;

-- PEMERIKSAAN — hasil yang benar: 2 baris, semuanya "Sesuai"
select '1. Fungsi dasar pantauan tersembunyi' as pemeriksaan,
       case when exists (select 1 from pg_proc where proname = '_pantauan_dasar')
             and not has_function_privilege('authenticated', 'public._pantauan_dasar(date)', 'execute') then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Layar Pantauan memuat data sesi pegawai dan rekap kelompok',
       case when exists (select 1 from pg_proc where proname = 'pantauan_langsung' and prosrc like '%pegawai_sesi%') then 'Sesuai' else 'Periksa: jalankan 8900 dulu' end;
