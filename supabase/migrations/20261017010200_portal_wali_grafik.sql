-- SIMKA PRO | supabase/migrations/20261017010200_portal_wali_grafik.sql | v1.0 | Perbaikan 13.5.0 Grafik kehadiran dan hafalan di Beranda Portal Wali | 15/10/2026
-- =====================================================================
-- SIMKA PRO · Portal Wali · Migrasi 102: data grafik Beranda
--   * tren_hadir   : persentase kehadiran program pokok (kelas + halaqah + asrama) per bulan, 6 bulan terakhir
--                    (Terlambat dan Bolos dihitung hadir — sama dengan halaman Kehadiran). Hanya bila butir Kehadiran aktif.
--   * tren_hafalan : tambahan hafalan (halaman) dan jumlah hari setoran per bulan, 6 bulan terakhir, beserta target
--                    bulanan yang sudah disahkan dan juz yang tercapai pada bulan itu. Hanya bila butir Hafalan aktif.
--   Data langsung dari absensi dan setoran (tanpa tabel baru). Tidak mengubah data apa pun.
-- Jalankan SETELAH migrasi 10100. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TREN KEHADIRAN (6 bulan, termasuk bulan berjalan)
-- ---------------------------------------------------------------------
create or replace function public._portal_tren_hadir(p_santri uuid, p_hari date)
returns jsonb language sql stable security definer set search_path = public as $$
  with b as (select generate_series(date_trunc('month', p_hari) - interval '5 months', date_trunc('month', p_hari), interval '1 month')::date as bulan),
  x as (select date_trunc('month', s.tanggal)::date as bulan, count(*)::int as sesi,
               count(*) filter (where s.kode not in ('I','S','A'))::int as hadir,
               count(*) filter (where s.kode = 'I')::int as izin, count(*) filter (where s.kode = 'S')::int as sakit,
               count(*) filter (where s.kode = 'A')::int as absen
          from public._portal_sesi_santri(p_santri, (date_trunc('month', p_hari) - interval '5 months')::date, p_hari) s
         where s.jenis in ('kelas','halaqah','asrama')
         group by 1)
  select coalesce(jsonb_agg(jsonb_build_object('bulan', b.bulan, 'sesi', coalesce(x.sesi, 0), 'hadir', coalesce(x.hadir, 0),
                    'izin', coalesce(x.izin, 0), 'sakit', coalesce(x.sakit, 0), 'absen', coalesce(x.absen, 0),
                    'persen', case when x.sesi > 0 then round(x.hadir * 100.0 / x.sesi, 1) end) order by b.bulan), '[]'::jsonb)
    from b left join x on x.bulan = b.bulan
$$;

-- ---------------------------------------------------------------------
-- 2. TREN HAFALAN (6 bulan, termasuk bulan berjalan)
-- ---------------------------------------------------------------------
create or replace function public._portal_tren_hafalan(p_santri uuid, p_hari date)
returns jsonb language sql stable security definer set search_path = public as $$
  with b as (select generate_series(date_trunc('month', p_hari) - interval '5 months', date_trunc('month', p_hari), interval '1 month')::date as bulan),
  l as (select date_trunc('month', tanggal)::date as bulan, coalesce(sum(greatest(tambah_hal, 0)), 0)::int as tambah_hal,
               count(distinct tanggal)::int as hari_setor
          from memorization_logs
         where student_id = p_santri and tanggal between (date_trunc('month', p_hari) - interval '5 months')::date and p_hari
         group by 1),
  j as (select date_trunc('month', tanggal)::date as bulan, count(*)::int as juz
          from juz_achievements where student_id = p_santri and tanggal is not null group by 1)
  select coalesce(jsonb_agg(jsonb_build_object('bulan', b.bulan, 'tambah_hal', coalesce(l.tambah_hal, 0), 'hari_setor', coalesce(l.hari_setor, 0),
                    'juz_baru', coalesce(j.juz, 0),
                    -- Target bulanan hanya dari capaian yang sudah disahkan validator
                    'target_hal', (select m.target_hal from monthly_achievements m
                                    where m.student_id = p_santri and m.bulan = b.bulan and m.disahkan_pada is not null limit 1))
                  order by b.bulan), '[]'::jsonb)
    from b left join l on l.bulan = b.bulan left join j on j.bulan = b.bulan
$$;

-- ---------------------------------------------------------------------
-- 3. BERANDA (sama dengan migrasi 9800 + tren_hadir dan tren_hafalan)
-- ---------------------------------------------------------------------
create or replace function public._portal_beranda(p_santri uuid, p_set jsonb, p_hubungan text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare s students; v_ta uuid; v_hari date := public.hari_ini(); hasil jsonb; v_wali text;
begin
  select x.* into s from students x where x.id = p_santri;
  select id into v_ta from academic_years where aktif limit 1;
  select c.nama into v_wali from student_contacts c where c.student_id = p_santri and c.hubungan = p_hubungan;
  hasil := jsonb_build_object(
    'butir', p_set->'butir',
    'lembaga', (select coalesce(nilai->>'nama_lengkap', nilai->>'nama') from institution_settings where kunci = 'identitas'),
    'tanggal', v_hari,
    'wali', jsonb_build_object('hubungan', p_hubungan, 'nama', v_wali),
    'santri', jsonb_build_object(
      'nis', s.nis, 'nama', s.nama_lengkap, 'panggilan', s.nama_panggilan, 'jk', s.jenis_kelamin,
      'jenjang', s.jenjang, 'tingkat', s.tingkat,
      'kelas', public._kelompok_santri(s.id, 'kelas'),
      'kamar', case when public._portal_butir(p_set, 'profil') then public._kelompok_santri(s.id, 'kamar') end,
      'halaqah', case when public._portal_butir(p_set, 'profil') then public._kelompok_santri(s.id, 'halaqah') end,
      'ekskul', case when public._portal_butir(p_set, 'profil') then public._kelompok_santri(s.id, 'ekskul') end,
      'program', case when public._portal_butir(p_set, 'hafalan') then (select program from student_tahfizh where student_id = s.id) end,
      'tempat_lahir', case when public._portal_butir(p_set, 'profil') then s.tempat_lahir end,
      'tanggal_lahir', case when public._portal_butir(p_set, 'profil') then s.tanggal_lahir end,
      'tahun_masuk', s.tahun_masuk));

  if public._portal_butir(p_set, 'pengasuh') then
    hasil := hasil || jsonb_build_object('pengasuh', coalesce((
      select jsonb_agg(jsonb_build_object('tugas', x.tugas, 'nama', x.nama, 'kelompok', x.kelompok) order by x.urut, x.kelompok)
      from (
        select distinct on (g.id)
               case g.jenis when 'kelas' then 'Wali kelas'
                            when 'kamar' then case when e.jenis_kelamin = 'P' then 'Musyrifah' else 'Musyrif' end
                            when 'halaqah' then case when e.jenis_kelamin = 'P' then 'Muhaffizhah' else 'Muhaffizh' end
                            else 'Pembina ekskul' end as tugas,
               e.nama_lengkap as nama, g.nama as kelompok,
               array_position(array['kelas','halaqah','kamar','ekskul'], g.jenis) as urut
          from group_members m
          join student_groups g on g.id = m.group_id and g.aktif and g.academic_year_id = v_ta and g.jenis in ('kelas','kamar','halaqah','ekskul')
          join group_keepers k on k.group_id = g.id and (k.mulai is null or k.mulai <= v_hari) and (k.sampai is null or k.sampai >= v_hari)
          join employees e on e.id = k.employee_id
         where m.student_id = p_santri and m.selesai is null
         order by g.id, array_position(array['utama','pendamping','pengganti'], k.peran)
      ) x), '[]'::jsonb));
  end if;

  if public._portal_butir(p_set, 'kehadiran') then
    hasil := hasil || jsonb_build_object(
      'hari_ini', coalesce((
        select jsonb_agg(jsonb_build_object('jenis', x.jenis, 'kelompok', x.kelompok, 'sesi', x.nama_sesi,
                                            'jam', to_char(x.jam, 'HH24.MI'), 'kode', x.kode) order by x.jam nulls last, x.nama_sesi)
          from public._portal_sesi_santri(p_santri, v_hari, v_hari) x), '[]'::jsonb),
      'bulan_ini', public._portal_rekap_hadir(p_santri, date_trunc('month', v_hari)::date, v_hari)->'pokok',
      'tren_hadir', public._portal_tren_hadir(p_santri, v_hari));
  end if;
  if public._portal_butir(p_set, 'hafalan') then
    hasil := hasil || jsonb_build_object('tren_hafalan', public._portal_tren_hafalan(p_santri, v_hari));
  end if;
  return hasil;
end $$;

-- ---------------------------------------------------------------------
-- 4. HAK EKSEKUSI (pembantu internal tertutup bagi aplikasi)
-- ---------------------------------------------------------------------
do $$ declare f text; begin
  foreach f in array array['_portal_tren_hadir(uuid,date)','_portal_tren_hafalan(uuid,date)','_portal_beranda(uuid,jsonb,text)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;

-- PEMERIKSAAN — hasil yang benar: 3 baris "Sesuai"
select '1. Fungsi data grafik kehadiran dan hafalan tersedia' as pemeriksaan,
       case when (select count(*) from pg_proc where pronamespace = 'public'::regnamespace
                   and proname in ('_portal_tren_hadir','_portal_tren_hafalan')) = 2 then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Grafik selalu berisi 6 bulan',
       case when jsonb_array_length(public._portal_tren_hadir(gen_random_uuid(), public.hari_ini())) = 6
             and jsonb_array_length(public._portal_tren_hafalan(gen_random_uuid(), public.hari_ini())) = 6 then 'Sesuai' else 'Periksa' end
union all
select '3. Fungsi grafik tertutup bagi pengguna tanpa login',
       case when not has_function_privilege('anon', 'public._portal_tren_hadir(uuid,date)', 'execute')
             and not has_function_privilege('anon', 'public._portal_tren_hafalan(uuid,date)', 'execute')
             and has_function_privilege('anon', 'public.portal_data(text,text,jsonb)', 'execute') then 'Sesuai' else 'Periksa' end;
