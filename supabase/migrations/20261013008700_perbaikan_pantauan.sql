-- SIMKA PRO | supabase/migrations/20261013008700_perbaikan_pantauan.sql | v1.0 | Perbaikan: Layar Pantauan "statement timeout" | 13/10/2026
-- =====================================================================
-- SIMKA PRO · Perbaikan kinerja Layar Pantauan (galat "canceling statement due to statement timeout")
-- Penyebab: capaian_bulanan (bagian Hafalan pada pantauan, juga dipakai menu Tahfizh → Capaian dan beranda) menghitung
-- sesi setoran setiap santri dengan memanggil _anggota_pada untuk SETIAP pasangan santri × sesi setoran bulan berjalan
-- (400 santri × ribuan sesi), dan tabel group_members tidak berindeks penuh pada group_id. Semakin jauh bulan berjalan,
-- semakin lambat hingga melewati batas waktu.
-- Perbaikan:
--   1. Indeks group_members (group_id, mulai) dan memorization_sessions (group_id, tanggal)
--   2. capaian_bulanan: sesi setoran dihitung sekali untuk semua santri (keanggotaan dibaca sekali per sesi); hasil sama.
-- Aman dijalankan ulang. Tidak mengubah data.
-- =====================================================================

create index if not exists group_members_kelompok_mulai_idx on public.group_members (group_id, mulai);
create index if not exists ms_kelompok_tanggal_idx on public.memorization_sessions (group_id, tanggal);
create index if not exists sae_sesi_santri_idx on public.student_attendance_exceptions (session_id, student_id);

create or replace function public.capaian_bulanan(p_bulan date, p_group uuid default null)
returns table (student_id uuid, nis text, nama text, jenis_kelamin text, tingkat smallint, kelas text, halaqah_id uuid, halaqah text,
               program text, posisi_awal_hal int, posisi_akhir_hal int, tambah_hal int, target_hal int, pekan_efektif int,
               sesi_terdata int, total_resmi int, status_otomatis text, status text, murojaah boolean, alasan_murojaah text,
               disahkan boolean, disahkan_pada timestamptz, disahkan_oleh text, muhaffizh_saya boolean)
language plpgsql stable security definer set search_path = public as $$
declare v_b date := date_trunc('month', p_bulan)::date; v_akhir date := (date_trunc('month', p_bulan) + interval '1 month - 1 day')::date;
  v_ta uuid; v_pekan int;
begin
  select id into v_ta from academic_years where v_b between date_trunc('month', mulai) and selesai order by mulai desc limit 1;
  v_ta := coalesce(v_ta, (select id from academic_years where aktif));
  select coalesce(m.pekan_efektif, 4) into v_pekan from tahfizh_months m where m.academic_year_id = v_ta and m.bulan = v_b;
  v_pekan := coalesce(v_pekan, 4);
  return query
  with terlihat as materialized (select x as sid from public.santri_terlihat() x),
  kel as (
    select m.student_id, g.id, g.nama, g.jenis from group_members m join student_groups g on g.id = m.group_id
     where g.academic_year_id = v_ta and g.jenis in ('kelas','halaqah') and m.mulai <= v_akhir and (m.selesai is null or m.selesai >= v_b)
  ),
  -- sesi setoran bulan itu yang diikuti santri (anggota pada tanggal sesi) dan santri tidak berhalangan (I/S/B/A)
  ikut as materialized (
    select a.sid, count(*)::int n
      from memorization_sessions ms
      cross join lateral (select y as sid from public._anggota_pada(ms.group_id, ms.tanggal) y) a
     where ms.tanggal between v_b and v_akhir
       and (p_group is null or ms.group_id = p_group or a.sid in (select k.student_id from kel k where k.id = p_group))
       and not exists (select 1 from student_attendance_exceptions x where x.session_id = ms.attendance_session_id
                        and x.student_id = a.sid and x.kode in ('I','S','B','A'))
     group by a.sid
  ),
  dasar as (
    select s.id, s.nis, s.nama_lengkap, s.jenis_kelamin, s.tingkat,
           (select k.nama from kel k where k.student_id = s.id and k.jenis = 'kelas' limit 1) as kelas,
           (select k.id from kel k where k.student_id = s.id and k.jenis = 'halaqah' limit 1) as hq_id,
           (select k.nama from kel k where k.student_id = s.id and k.jenis = 'halaqah' limit 1) as hq,
           coalesce(t.program, 'reguler') as program,
           coalesce((select l.sabaq_hal from memorization_logs l join memorization_sessions ms on ms.id = l.session_id
                      where l.student_id = s.id and l.sabaq_hal is not null and l.tanggal < v_b
                      order by l.tanggal desc, ms.jam_mulai desc nulls last limit 1), t.awal_sabaq_hal, 0)::int as awal,
           coalesce((select l.sabaq_hal from memorization_logs l join memorization_sessions ms on ms.id = l.session_id
                      where l.student_id = s.id and l.sabaq_hal is not null and l.tanggal <= v_akhir
                      order by l.tanggal desc, ms.jam_mulai desc nulls last limit 1), t.awal_sabaq_hal, 0)::int as akhir,
           coalesce((select i.n from ikut i where i.sid = s.id), 0)::int as sesi,
           (select count(*) from juz_achievements j where j.student_id = s.id)::int as resmi,
           coalesce((select tg.pekan_hal from tahfizh_targets tg where tg.academic_year_id = v_ta and tg.program = coalesce(t.program, 'reguler')
                      and tg.tingkat = s.tingkat), 5)::int * v_pekan as target,
           ma.murojaah, ma.alasan_murojaah, ma.status as st_beku, ma.disahkan_pada, ma.disahkan_oleh,
           ma.posisi_awal_hal, ma.posisi_akhir_hal, ma.tambah_hal as tambah_beku, ma.target_hal as target_beku, ma.pekan_efektif as pekan_beku
      from students s left join student_tahfizh t on t.student_id = s.id
      left join monthly_achievements ma on ma.student_id = s.id and ma.bulan = v_b
     where s.status in ('aktif','nonaktif') and s.id in (select sid from terlihat)
       and (p_group is null or exists (select 1 from kel k where k.student_id = s.id and k.id = p_group))
  )
  select d.id, d.nis, d.nama_lengkap, d.jenis_kelamin, d.tingkat, d.kelas, d.hq_id, d.hq, d.program,
         coalesce(d.posisi_awal_hal::int, d.awal), coalesce(d.posisi_akhir_hal::int, d.akhir),
         coalesce(d.tambah_beku::int, d.akhir - d.awal), coalesce(d.target_beku::int, d.target), coalesce(d.pekan_beku::int, v_pekan),
         d.sesi, d.resmi,
         case when d.resmi >= 30 or d.akhir >= 600 then 'khatam'
              when coalesce(d.murojaah, false) then 'murojaah'
              when d.sesi = 0 then 'tidak_terdata'
              when d.akhir - d.awal >= d.target then 'tercapai' else 'tidak_tercapai' end,
         coalesce(d.st_beku,
           case when d.resmi >= 30 or d.akhir >= 600 then 'khatam'
                when coalesce(d.murojaah, false) then 'murojaah'
                when d.sesi = 0 then 'tidak_terdata'
                when d.akhir - d.awal >= d.target then 'tercapai' else 'tidak_tercapai' end),
         coalesce(d.murojaah, false), d.alasan_murojaah, d.disahkan_pada is not null, d.disahkan_pada,
         (select nama_lengkap from employees where id = d.disahkan_oleh),
         public._muhaffizh_santri(d.id)
    from dasar d
   order by d.hq nulls last, d.nama_lengkap;
end $$;

analyze public.group_members;
analyze public.memorization_sessions;
analyze public.memorization_logs;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 2 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select '1. Indeks keanggotaan kelompok dan sesi setoran' as pemeriksaan,
       case when (select count(*) from pg_indexes where indexname in ('group_members_kelompok_mulai_idx','ms_kelompok_tanggal_idx','sae_sesi_santri_idx')) = 3
            then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Fungsi capaian bulanan diperbarui', case when exists (select 1 from pg_proc where proname = 'capaian_bulanan' and prosrc like '%ikut as materialized%') then 'Sesuai' else 'Periksa' end;
