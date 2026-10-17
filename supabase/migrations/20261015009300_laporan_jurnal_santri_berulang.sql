-- SIMKA PRO | supabase/migrations/20261015009300_laporan_jurnal_santri_berulang.sql | v1.0 | Tahap B: tabel ceklist jurnal bulanan, santri berulang sakit/izin/absen/terlambat | 15/10/2026
-- A. matriks_jurnal(pegawai, mulai, akhir): butir ceklist template yang berlaku bagi pegawai (ditambah butir yang pernah
--    dicentang pada rentang itu) × tanggal, beserta tanggal yang dicentang dan hari wajib. Rentang paling panjang 31 hari.
-- B. riwayat_berulang_santri(mulai, selesai): per santri yang terlihat oleh pengguna — jumlah ketidakhadiran per kegiatan
--    (kelas, halaqah, asrama, ekskul, pelajaran) dan kode (S sakit, I izin, A alfa, B bolos, T terlambat), kasus klinik
--    (tanpa diagnosis), izin keluar/pulang, dan terlambat kembali. Hanya membaca pengecualian (hemat), bukan seluruh absensi.
-- Aman dijalankan ulang.

create or replace function public.matriks_jurnal(p_emp uuid, p_mulai date, p_akhir date)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public.boleh_lihat_jurnal(p_emp) then raise exception 'Anda tidak berhak melihat jurnal pegawai ini.' using errcode = '42501'; end if;
  if p_akhir < p_mulai or p_akhir - p_mulai > 30 then raise exception 'Rentang tabel ceklist paling panjang 31 hari.'; end if;
  return jsonb_build_object(
    'butir', coalesce((select jsonb_agg(jsonb_build_object('item_id', x.item_id, 'kelompok', x.kelompok, 'uraian', x.uraian) order by x.urut, x.uraian) from (
        select b.item_id, b.kelompok, b.uraian, b.urutan urut from public.butir_jurnal(p_emp) b
        union
        select distinct c.item_id, 'Lainnya', c.uraian, 999999 from journal_checks c
         where c.employee_id = p_emp and c.tanggal between p_mulai and p_akhir
           and c.item_id not in (select item_id from public.butir_jurnal(p_emp))) x), '[]'::jsonb),
    'hari', coalesce((select jsonb_agg(jsonb_build_object('tanggal', d::date, 'wajib', public.wajib_jurnal(p_emp, d::date)) order by d)
        from generate_series(p_mulai, p_akhir, interval '1 day') d), '[]'::jsonb),
    'cek', coalesce((select jsonb_agg(jsonb_build_object('item_id', c.item_id, 'tanggal', c.tanggal)) from journal_checks c
        where c.employee_id = p_emp and c.tanggal between p_mulai and p_akhir), '[]'::jsonb),
    'kegiatan', coalesce((select jsonb_agg(jsonb_build_object('tanggal', e.tanggal, 'n', e.n)) from (
        select tanggal, count(*) n from journal_entries where employee_id = p_emp and tanggal between p_mulai and p_akhir and status <> 'dikembalikan' group by tanggal) e), '[]'::jsonb));
end $$;

create or replace function public.riwayat_berulang_santri(p_mulai date, p_selesai date)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v jsonb;
begin
  if public.saya() is null then raise exception 'Akun Anda belum aktif.' using errcode = '42501'; end if;
  if p_selesai < p_mulai or p_selesai - p_mulai > 366 then raise exception 'Rentang paling panjang satu tahun.'; end if;
  with lihat as materialized (select x id from public.santri_terlihat() x),
  absen as (
    select e.student_id id, sa.jenis, e.kode, count(*) n from student_attendance_exceptions e
      join student_attendance_sessions sa on sa.id = e.session_id
     where sa.tanggal between p_mulai and p_selesai and e.student_id in (select id from lihat)
     group by 1, 2, 3
    union all
    select (a.key)::uuid, 'pelajaran', a.value #>> '{}', count(*) from teaching_journals tj cross join lateral jsonb_each(tj.absen) a
     where tj.tanggal between p_mulai and p_selesai and (a.key)::uuid in (select id from lihat)
     group by 1, 2, 3
  ), absen_j as (
    select id, jsonb_object_agg(jenis, kode_n) a from (
      select id, jenis, jsonb_object_agg(kode, n) kode_n from absen group by id, jenis) q group by id
  ), klinik as (
    select c.student_id id, count(*) n, max(c.dibuka_pada) terakhir,
           string_agg(distinct left(c.keluhan, 40), '; ') keluhan from clinic_cases c
     where c.status <> 'batal' and (c.dibuka_pada at time zone 'Asia/Makassar')::date between p_mulai and p_selesai and c.student_id in (select id from lihat)
     group by 1
  ), izin as (
    select p.student_id id, count(*) n, count(*) filter (where coalesce(p.kembali_pada, now()) > p.kembali_batas) telat from student_permits p
     where p.keluar_aktual is not null and (p.keluar_aktual at time zone 'Asia/Makassar')::date between p_mulai and p_selesai and p.student_id in (select id from lihat)
     group by 1
  ), semua as (select id from absen_j union select id from klinik union select id from izin)
  select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'absen', coalesce(a.a, '{}'::jsonb), 'klinik', coalesce(k.n, 0), 'klinik_terakhir', k.terakhir,
           'keluhan', k.keluhan, 'izin', coalesce(i.n, 0), 'telat_kembali', coalesce(i.telat, 0))), '[]'::jsonb)
    into v
    from semua s left join absen_j a on a.id = s.id left join klinik k on k.id = s.id left join izin i on i.id = s.id;
  return v;
end $$;

do $$ declare f text; begin
  foreach f in array array['matriks_jurnal(uuid,date,date)','riwayat_berulang_santri(date,date)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- PEMERIKSAAN — hasil yang benar: 1 baris "Sesuai"
select '1. Fungsi tabel ceklist jurnal dan santri berulang' as pemeriksaan,
       case when (select count(*) from pg_proc where proname in ('matriks_jurnal','riwayat_berulang_santri')) = 2 then 'Sesuai' else 'Periksa' end as hasil;
