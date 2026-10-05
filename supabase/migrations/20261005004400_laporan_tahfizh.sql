-- SIMKA PRO | supabase/migrations/20261005004400_laporan_tahfizh.sql | v1.0 | Fase 5 – Tahap 5 Laporan dan grafik tahfizh | 05/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 5 · Migrasi 44: Sumber data 15 laporan tahfizh (Blueprint Bagian 20 – Laporan tahfizh)
--   * data_laporan_tahfizh(bulan) : satu baris per santri terlihat — status capaian bulanan (sama dengan tab Capaian),
--     posisi sabaq akhir pekan 1–5 (pekan = tanggal 1–7, 8–14, 15–21, 22–28, 29–akhir), juz resmi, kelas, halaqah,
--     muhaffizh, naqib, kamar, program, tingkat.
--   * kepatuhan_setoran(bulan)    : per halaqah, sesi setoran seharusnya vs terisi untuk pekan 1–5.
--   * kehadiran_halaqah(bulan)    : per halaqah, persentase kehadiran santri dari absensi halaqah.
-- Hanya membaca; cakupan mengikuti santri_terlihat() dan halaqah asuhan (atau semua bagi pimpinan/admin tahfizh).
-- Jalankan SETELAH migrasi 4300. Aman dijalankan ulang.
-- =====================================================================

create or replace function public.data_laporan_tahfizh(p_bulan date)
returns table (student_id uuid, nis text, nama text, jenis_kelamin text, jenjang text, tingkat smallint, kelas text, halaqah_id uuid, halaqah text,
               muhaffizh text, naqib boolean, kamar text, program text, posisi_awal_hal int, posisi_akhir_hal int, tambah_hal int, target_hal int,
               pekan_efektif int, sesi_terdata int, status text, disahkan boolean, pekan int[], juz_resmi smallint[], total_resmi int)
language plpgsql stable security definer set search_path = public as $$
declare v_b date := date_trunc('month', p_bulan)::date; v_akhir date := (date_trunc('month', p_bulan) + interval '1 month - 1 day')::date;
  v_ta uuid;
begin
  select id into v_ta from academic_years where v_b between date_trunc('month', mulai) and selesai order by mulai desc limit 1;
  return query
  select c.student_id, c.nis, c.nama, c.jenis_kelamin, s.jenjang, c.tingkat, c.kelas, c.halaqah_id, c.halaqah,
         (select e.nama_lengkap from group_keepers k join employees e on e.id = k.employee_id
           where k.group_id = c.halaqah_id and k.employee_id in (select public._pengasuh_berlaku(c.halaqah_id, least(v_akhir, public.hari_ini())))
           order by array_position(array['utama','pendamping','pengganti'], k.peran) limit 1),
         exists (select 1 from student_groups g where g.id = c.halaqah_id and g.naqib_id = c.student_id),
         (select g.nama from group_members m join student_groups g on g.id = m.group_id
           where m.student_id = c.student_id and g.jenis = 'kamar' and g.academic_year_id = v_ta and m.mulai <= v_akhir
             and (m.selesai is null or m.selesai >= v_b) order by m.mulai desc limit 1),
         c.program, c.posisi_awal_hal, c.posisi_akhir_hal, c.tambah_hal, c.target_hal, c.pekan_efektif, c.sesi_terdata, c.status, c.disahkan,
         array(select case when v_b + (k - 1) * 7 > least(v_akhir, public.hari_ini()) then null else
                 coalesce((select l.sabaq_hal from memorization_logs l join memorization_sessions ms on ms.id = l.session_id
                            where l.student_id = c.student_id and l.sabaq_hal is not null
                              and l.tanggal <= least(case when k = 5 then v_akhir else v_b + k * 7 - 1 end, v_akhir)
                            order by l.tanggal desc, ms.jam_mulai desc nulls last limit 1),
                          (select t.awal_sabaq_hal from student_tahfizh t where t.student_id = c.student_id), 0)::int end
               from generate_series(1, 5) k order by k),
         coalesce((select array_agg(j.juz order by j.juz) from juz_achievements j where j.student_id = c.student_id), '{}'),
         c.total_resmi
    from public.capaian_bulanan(v_b, null) c join students s on s.id = c.student_id;
end $$;

create or replace function public.kepatuhan_setoran(p_bulan date)
returns table (halaqah_id uuid, halaqah text, muhaffizh text, jumlah_santri int, seharusnya int[], terisi int[])
language plpgsql stable security definer set search_path = public as $$
declare v_b date := date_trunc('month', p_bulan)::date; v_akhir date := (date_trunc('month', p_bulan) + interval '1 month - 1 day')::date;
  v_semua boolean := public.boleh_validasi_tahfizh() or public.boleh_atur_tahfizh() or public.boleh_pantau_absensi();
  v_ta uuid;
begin
  select id into v_ta from academic_years where v_b between date_trunc('month', mulai) and selesai order by mulai desc limit 1;
  return query
  with hari as (
    select d::date tgl, least(5, (extract(day from d)::int - 1) / 7 + 1) as pk
      from generate_series(v_b, least(v_akhir, public.hari_ini()), interval '1 day') d
  ), sesi as (select h.tgl, h.pk, x.kode from hari h cross join lateral public.sesi_santri_tanggal('halaqah', h.tgl) x)
  select g.id, g.nama,
         (select e.nama_lengkap from group_keepers k join employees e on e.id = k.employee_id where k.group_id = g.id
           order by array_position(array['utama','pendamping','pengganti'], k.peran) limit 1),
         (select count(*) from public._anggota_pada(g.id, least(v_akhir, public.hari_ini())))::int,
         array(select count(s.kode)::int from generate_series(1, 5) k left join sesi s on s.pk = k group by k order by k),
         array(select count(ms.id)::int from generate_series(1, 5) k left join sesi s on s.pk = k
                 left join memorization_sessions ms on ms.group_id = g.id and ms.tanggal = s.tgl and ms.sesi = s.kode group by k order by k)
    from student_groups g
   where g.academic_year_id = v_ta and g.jenis = 'halaqah' and g.aktif
     and (v_semua or public.saya() in (select k.employee_id from group_keepers k where k.group_id = g.id))
   order by g.nama;
end $$;

create or replace function public.kehadiran_halaqah(p_bulan date)
returns table (halaqah_id uuid, sesi int, hadir bigint, anggota bigint, persen numeric)
language sql stable security definer set search_path = public as $$
  select sa.group_id, count(*)::int, sum(sa.jumlah_hadir), sum(sa.jumlah_anggota),
         round(100.0 * sum(sa.jumlah_hadir) / nullif(sum(sa.jumlah_anggota), 0), 1)
    from student_attendance_sessions sa join student_groups g on g.id = sa.group_id and g.jenis = 'halaqah'
   where sa.tanggal between date_trunc('month', p_bulan)::date and (date_trunc('month', p_bulan) + interval '1 month - 1 day')::date
     and (public.boleh_validasi_tahfizh() or public.boleh_atur_tahfizh() or public.boleh_pantau_absensi()
          or public.saya() in (select k.employee_id from group_keepers k where k.group_id = g.id))
   group by sa.group_id
$$;

do $$
declare f text;
begin
  foreach f in array array['data_laporan_tahfizh(date)','kepatuhan_setoran(date)','kehadiran_halaqah(date)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- PEMERIKSAAN — hasil yang benar: 2 baris, semuanya "Sesuai"
select 'Fungsi data laporan tahfizh (3) tersedia' as pemeriksaan,
       case when (select count(distinct proname) from pg_proc where proname in ('data_laporan_tahfizh','kepatuhan_setoran','kehadiran_halaqah')) = 3
            then 'Sesuai' else 'Periksa' end as hasil
union all
select 'Migrasi 4300 sudah terpasang', case when exists (select 1 from pg_proc where proname = 'daftar_ujian') then 'Sesuai' else 'Periksa: jalankan 4300 dulu' end;
