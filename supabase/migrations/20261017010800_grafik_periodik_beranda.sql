-- SIMKA PRO | supabase/migrations/20261017010800_grafik_periodik_beranda.sql | v1.0 | Perbaikan 13.7.0 Grafik periodik beranda pimpinan/admin/superadmin | 16/10/2026
-- =====================================================================
-- SIMKA PRO · Migrasi 108: Grafik periodik beranda
--   Slider kartu statistik di beranda pimpinan, admin, dan superadmin diganti grafik periodik (kartu statistik
--   pindah ke Layar Pantauan). grafik_periodik(periode) mengembalikan deret waktu:
--     pegawai : presensi pegawai (sesi tercatat, hadir termasuk terlambat/dinas luar, terlambat, izin/sakit/cuti, tanpa keterangan)
--     santri  : persentase kehadiran santri per program (kelas, halaqah, asrama, ekskul)
--     hafalan : santri setor dan tambahan halaman hafalan
--     layanan : kasus klinik baru dan izin keluar santri
--     jurnal  : keterlaksanaan pelajaran (jurnal mengajar terisi terlaksana)
--   periode: '7h' (7 hari), '14h' (14 hari, bawaan), '30h' (30 hari), '6b' (6 bulan, per bulan).
--   Hak: sama dengan Layar Pantauan (boleh_pantauan: admin, superadmin, pimpinan, pemegang hak pantauan).
-- Jalankan SETELAH migrasi 10700. Tidak mengubah data. Aman dijalankan ulang.
-- =====================================================================

create or replace function public.grafik_periodik(p_periode text default '14h')
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_hari date := public.hari_ini(); v_bulan boolean := p_periode = '6b'; v_mulai date; v_n int;
begin
  if not public.boleh_pantauan() then
    raise exception 'Grafik periodik hanya untuk pimpinan, admin, dan superadmin.' using errcode = '42501';
  end if;
  v_n := case p_periode when '7h' then 7 when '30h' then 30 when '6b' then 6 else 14 end;
  v_mulai := case when v_bulan then (date_trunc('month', v_hari) - make_interval(months => v_n - 1))::date else v_hari - (v_n - 1) end;

  return jsonb_build_object(
    'periode', case when v_bulan then '6b' else v_n || 'h' end, 'mulai', v_mulai, 'selesai', v_hari, 'bulanan', v_bulan,
    'titik', (select jsonb_agg(b order by b) from (
                select case when v_bulan then (date_trunc('month', v_mulai) + make_interval(months => i))::date else v_mulai + i end b
                  from generate_series(0, v_n - 1) i) t),
    'pegawai', coalesce((select jsonb_agg(jsonb_build_object('t', x.b, 'sesi', x.n, 'hadir', x.h, 'terlambat', x.tl, 'izin', x.isc, 'tanpa', x.tk,
                   'persen', case when x.n > 0 then round(100.0 * x.h / x.n, 1) end) order by x.b)
       from (select case when v_bulan then date_trunc('month', a.tanggal)::date else a.tanggal end b, count(*) n,
                    count(*) filter (where a.status in ('hadir','terlambat','dinas_luar')) h, count(*) filter (where a.status = 'terlambat') tl,
                    count(*) filter (where a.status in ('izin','sakit','cuti')) isc, count(*) filter (where a.status = 'tanpa_keterangan') tk
               from attendances a where a.tanggal between v_mulai and v_hari and not a.opsional group by 1) x), '[]'::jsonb),
    'santri', coalesce((select jsonb_agg(jsonb_build_object('t', x.b, 'jenis', x.jenis, 'anggota', x.ang, 'hadir', x.h,
                   'persen', case when x.ang > 0 then round(100.0 * x.h / x.ang, 1) end) order by x.b, x.jenis)
       from (select case when v_bulan then date_trunc('month', s.tanggal)::date else s.tanggal end b, s.jenis, sum(s.jumlah_anggota) ang, sum(s.jumlah_hadir) h
               from student_attendance_sessions s where s.tanggal between v_mulai and v_hari and s.jumlah_anggota > 0 group by 1, 2) x), '[]'::jsonb),
    'hafalan', coalesce((select jsonb_agg(jsonb_build_object('t', x.b, 'setor', x.setor, 'tambah_hal', x.hal) order by x.b)
       from (select case when v_bulan then date_trunc('month', l.tanggal)::date else l.tanggal end b, count(distinct l.student_id) setor,
                    coalesce(sum(greatest(l.tambah_hal, 0)), 0)::int hal
               from memorization_logs l where l.tanggal between v_mulai and v_hari group by 1) x), '[]'::jsonb),
    'klinik', coalesce((select jsonb_agg(jsonb_build_object('t', x.b, 'kasus', x.n) order by x.b)
       from (select case when v_bulan then date_trunc('month', (c.dibuka_pada at time zone 'Asia/Makassar')::date)::date else (c.dibuka_pada at time zone 'Asia/Makassar')::date end b, count(*) n
               from clinic_cases c where c.status <> 'batal' and (c.dibuka_pada at time zone 'Asia/Makassar')::date between v_mulai and v_hari group by 1) x), '[]'::jsonb),
    'izin', coalesce((select jsonb_agg(jsonb_build_object('t', x.b, 'keluar', x.n) order by x.b)
       from (select case when v_bulan then date_trunc('month', (p.keluar_pada at time zone 'Asia/Makassar')::date)::date else (p.keluar_pada at time zone 'Asia/Makassar')::date end b, count(*) n
               from student_permits p where p.status in ('disetujui','keluar','kembali') and (p.keluar_pada at time zone 'Asia/Makassar')::date between v_mulai and v_hari group by 1) x), '[]'::jsonb),
    'jurnal', coalesce((select jsonb_agg(jsonb_build_object('t', x.b, 'jp', x.n, 'terlaksana', x.ok,
                   'persen', case when x.n > 0 then round(100.0 * x.ok / x.n, 1) end) order by x.b)
       from (select case when v_bulan then date_trunc('month', j.tanggal)::date else j.tanggal end b, count(*) n, count(*) filter (where j.status = 'terlaksana') ok
               from teaching_journals j where j.tanggal between v_mulai and v_hari group by 1) x), '[]'::jsonb));
end $$;
revoke execute on function public.grafik_periodik(text) from public, anon;
grant execute on function public.grafik_periodik(text) to authenticated;

-- PEMERIKSAAN — hasil yang benar: 2 baris "Sesuai"
select '1. Fungsi grafik periodik tersedia' as pemeriksaan,
       case when exists (select 1 from pg_proc where proname = 'grafik_periodik') then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Tertutup bagi pengguna tanpa login',
       case when not has_function_privilege('anon', 'public.grafik_periodik(text)', 'execute') then 'Sesuai' else 'Periksa' end;
