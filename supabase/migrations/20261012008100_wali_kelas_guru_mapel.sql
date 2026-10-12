-- SIMKA PRO | supabase/migrations/20261012008100_wali_kelas_guru_mapel.sql | v1.0 | Fase 4 – Menu Wali Kelas dan Guru Mapel | 12/10/2026
-- =====================================================================
-- SIMKA PRO · Migrasi 81: menu tersendiri untuk tupoksi Wali Kelas dan Guru Mapel
--   (melengkapi menu Musyrif, Tahfizh/muhaffizh, Klinik, dan Security)
-- WALI KELAS
--   boleh_lihat_kelas(kelas)          : wali kelas kelas itu, pemantau absensi (admin/superadmin, pemegang hak Absensi Kelas
--                                       dan Data Santri), cakupan luas Absensi Kelas, dan pimpinan menurut jenjangnya
--   kelas_walas()                     : kelas yang terlihat beserta wali kelas, jumlah santri putra/putri, tautan grup WA
--   absensi_kelas_rinci(kelas, a, b)  : rincian absensi kelas (bentuk sama dengan absensi asrama) untuk dasbor dan rekap
--   ringkasan_kelas(a, b)             : pemantauan semua kelas: kehadiran, absensi hari ini, sakit/izin, keterlaksanaan mengajar
-- GURU MAPEL
--   slot_mengajar(a, b, kelas, guru)  : setiap jam pelajaran terjadwal beserta status jurnal mengajarnya
--                                       (terlaksana / tidak terlaksana / belum diisi), untuk pemantauan harian guru mapel
--                                       dan pelajaran hari ini di kelas wali kelas
-- Semua fungsi hanya membaca; pengisian tetap lewat Absensi Santri dan Jurnal Harian → Jurnal mengajar.
-- Jalankan SETELAH migrasi 8000. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. HAK LIHAT KELAS
-- ---------------------------------------------------------------------
create or replace function public.boleh_lihat_kelas(p_group uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.boleh_pantau_absensi() or public.akses_luas('absensi_kelas')
      or p_group in (select public.kelompok_saya())
      or (select g.jenjang from student_groups g where g.id = p_group) = any(public.jenjang_terlihat())
$$;

-- ---------------------------------------------------------------------
-- 2. DAFTAR KELAS UNTUK MENU WALI KELAS
-- ---------------------------------------------------------------------
create or replace function public.kelas_walas()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(x order by (x->>'asuhan_saya')::boolean desc, (x->>'tingkat')::int, x->>'nama'), '[]'::jsonb) from (
    select jsonb_build_object('id', g.id, 'nama', g.nama, 'jenjang', g.jenjang, 'tingkat', g.tingkat, 'jenis_kelamin', g.jenis_kelamin,
             'keterangan', g.keterangan, 'wa_wali', g.wa_wali, 'wa_internal', g.wa_internal,
             'asuhan_saya', g.id in (select public.kelompok_saya()),
             'jumlah', a.jumlah, 'putra', a.putra, 'putri', a.putri,
             'wali', coalesce((select jsonb_agg(jsonb_build_object('employee_id', e.id, 'nama', e.nama_lengkap, 'niy', e.niy,
                           'peran', k.peran, 'no_hp', e.no_hp) order by case k.peran when 'utama' then 0 when 'pendamping' then 1 else 2 end, e.nama_lengkap)
                         from group_keepers k join employees e on e.id = k.employee_id
                         where k.group_id = g.id and (k.mulai is null or k.mulai <= public.hari_ini())
                           and (k.sampai is null or k.sampai >= public.hari_ini())), '[]'::jsonb),
             'mapel', (select count(*) from teaching_assignments t where t.group_id = g.id)) x
      from student_groups g join academic_years ay on ay.id = g.academic_year_id and ay.aktif
      cross join lateral (select count(*) jumlah, count(*) filter (where s.jenis_kelamin = 'L') putra, count(*) filter (where s.jenis_kelamin = 'P') putri
                            from group_members m join students s on s.id = m.student_id
                           where m.group_id = g.id and m.selesai is null and s.status = 'aktif') a
     where g.jenis = 'kelas' and g.aktif and public.boleh_lihat_kelas(g.id)) q
$$;

-- ---------------------------------------------------------------------
-- 3. RINCIAN ABSENSI SATU KELAS (bentuk sama dengan absensi_asrama_rinci)
-- ---------------------------------------------------------------------
create or replace function public.absensi_kelas_rinci(p_group uuid, p_mulai date, p_selesai date)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare g student_groups%rowtype; v_akhir date := least(p_selesai, public.hari_ini());
begin
  select * into g from student_groups where id = p_group;
  if g.id is null or g.jenis <> 'kelas' then raise exception 'Kelas tidak ditemukan.'; end if;
  if p_mulai is null or p_selesai is null or p_selesai < p_mulai then raise exception 'Rentang tanggal tidak sah.'; end if;
  if p_selesai - p_mulai > 400 then raise exception 'Rentang paling panjang 400 hari.'; end if;
  if not public.boleh_lihat_kelas(p_group) then raise exception 'Anda tidak berwenang melihat absensi kelas ini.' using errcode = '42501'; end if;

  return jsonb_build_object(
    'kelas', jsonb_build_object('id', g.id, 'nama', g.nama, 'jenjang', g.jenjang, 'tingkat', g.tingkat, 'jenis_kelamin', g.jenis_kelamin),
    'mulai', p_mulai, 'selesai', p_selesai,
    'sesi', coalesce((select jsonb_agg(jsonb_build_object('id', sa.id, 'tanggal', sa.tanggal, 'sesi', sa.sesi, 'nama_sesi', sa.nama_sesi,
              'jam_mulai', sa.jam_mulai, 'pengisi', e.nama_lengkap, 'terlambat', sa.diisi_terlambat, 'atas_nama', sa.atas_nama)
              order by sa.tanggal, sa.jam_mulai)
            from student_attendance_sessions sa left join employees e on e.id = coalesce(sa.diinput_oleh, sa.pengampu_id)
           where sa.group_id = p_group and sa.jenis = 'kelas' and sa.tanggal between p_mulai and p_selesai), '[]'::jsonb),
    'isi', coalesce((select jsonb_agg(jsonb_build_array(sa.id, a.sid, coalesce(x.kode, 'H'), x.keterangan))
            from student_attendance_sessions sa
            cross join lateral (select y as sid from public._anggota_pada(sa.group_id, sa.tanggal) y) a
            left join student_attendance_exceptions x on x.session_id = sa.id and x.student_id = a.sid
           where sa.group_id = p_group and sa.jenis = 'kelas' and sa.tanggal between p_mulai and p_selesai), '[]'::jsonb),
    'rencana', coalesce((select jsonb_agg(jsonb_build_object('tanggal', d::date, 'sesi', ss.kode, 'nama_sesi', ss.nama) order by d, ss.urutan)
            from generate_series(p_mulai, v_akhir, interval '1 day') d
            cross join lateral public.sesi_santri_tanggal('kelas', d::date) ss
           where ss.selesai <= now() and v_akhir >= p_mulai), '[]'::jsonb),
    'santri', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'nis', s.nis, 'nama', s.nama_lengkap, 'jenis_kelamin', s.jenis_kelamin,
              'status', s.status, 'aktif_di_kamar', t.aktif) order by s.nama_lengkap)
            from (select m.student_id, bool_or(m.selesai is null) as aktif from group_members m
                   where m.group_id = p_group and m.mulai <= p_selesai and (m.selesai is null or m.selesai >= p_mulai)
                   group by m.student_id) t
            join students s on s.id = t.student_id), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------
-- 4. SLOT MENGAJAR (jadwal × tanggal × jurnal)
-- ---------------------------------------------------------------------
/** Setiap jam pelajaran terjadwal pada rentang (paling lama 62 hari; hari Ahad dan libur sekolah dilewati).
    status: terlaksana | tidak_terlaksana | belum; lewat = jam pelajaran sudah selesai. Hanya slot yang boleh dilihat. */
create or replace function public.slot_mengajar(p_mulai date, p_selesai date, p_group uuid default null, p_emp uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_akhir date := least(p_selesai, public.hari_ini() + 7); v_pantau boolean := public.is_admin() or public.tingkat_fitur('jadwal_mengajar') >= 1;
begin
  if public.saya() is null then raise exception 'Akun Anda belum aktif.'; end if;
  if p_mulai is null or p_selesai is null or p_selesai < p_mulai then raise exception 'Rentang tanggal tidak sah.'; end if;
  if p_selesai - p_mulai > 61 then raise exception 'Rentang paling lama 62 hari.'; end if;
  return coalesce((select jsonb_agg(x order by x->>'tanggal', x->>'jam_mulai', x->>'kelas') from (
    select jsonb_build_object('tanggal', h.tgl, 'jam_ke', p.nama, 'urutan', p.urutan, 'jam_mulai', to_char(p.jam_mulai, 'HH24:MI'), 'jam_selesai', to_char(p.jam_selesai, 'HH24:MI'),
             'group_id', g.id, 'kelas', g.nama, 'jenjang', g.jenjang, 'assignment_id', t.id, 'period_id', p.id,
             'mapel', s.nama, 'kode_mapel', s.kode, 'employee_id', e.id, 'guru', e.nama_lengkap, 'niy', e.niy,
             'wali_kelas', (select string_agg(we.nama_lengkap, ', ' order by case k.peran when 'utama' then 0 else 1 end) from group_keepers k join employees we on we.id = k.employee_id
                             where k.group_id = g.id and (k.mulai is null or k.mulai <= h.tgl) and (k.sampai is null or k.sampai >= h.tgl)),
             'no_hp', case when v_pantau or public.pimpinan_dari(e.id) or g.id in (select public.kelompok_saya()) then e.no_hp end,
             'status', coalesce(j.status, 'belum'), 'materi', j.materi, 'keterangan', j.keterangan,
             'pengisi', case when j.employee_id is distinct from t.employee_id then (select nama_lengkap from employees where id = j.employee_id) end,
             'lewat', ((h.tgl + p.jam_selesai)::timestamp at time zone 'Asia/Makassar') <= now()) x
      from (select d::date tgl, extract(dow from d)::int dow from generate_series(p_mulai, v_akhir, interval '1 day') d
             where extract(dow from d) <> 0 and not public.libur_tugas(d::date, 'sekolah')) h
      join class_schedules cs on cs.hari = h.dow
      join teaching_assignments t on t.id = cs.assignment_id
      join academic_years a on a.id = t.academic_year_id and a.aktif
      join lesson_periods p on p.id = cs.period_id
      join student_groups g on g.id = t.group_id
      join subjects s on s.id = t.subject_id
      join employees e on e.id = t.employee_id
      left join teaching_journals j on j.assignment_id = t.id and j.tanggal = h.tgl and j.period_id = p.id
     where (p_group is null or t.group_id = p_group) and (p_emp is null or t.employee_id = p_emp)
       and (t.employee_id = public.saya() or public.is_admin() or public.pimpinan_dari(t.employee_id)
            or public.tingkat_fitur('jadwal_mengajar') >= 3 or g.jenjang = any(public.jenjang_terlihat())
            or g.id in (select public.kelompok_saya()))) q), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- 5. RINGKASAN SEMUA KELAS (pemantauan pimpinan/admin)
-- ---------------------------------------------------------------------
create or replace function public.ringkasan_kelas(p_mulai date, p_selesai date)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_akhir date := least(p_selesai, public.hari_ini()); v_rencana int; v_hari date := public.hari_ini();
begin
  if p_selesai < p_mulai or p_selesai - p_mulai > 400 then raise exception 'Rentang tanggal tidak sah (paling panjang 400 hari).'; end if;
  select count(*) into v_rencana from generate_series(p_mulai, v_akhir, interval '1 day') d
   cross join lateral public.sesi_santri_tanggal('kelas', d::date) ss where ss.selesai <= now();
  return coalesce((select jsonb_agg(x order by (x->>'tingkat')::int, x->>'nama') from (
    select jsonb_build_object('id', g.id, 'nama', g.nama, 'jenjang', g.jenjang, 'tingkat', g.tingkat, 'jenis_kelamin', g.jenis_kelamin,
      'wali', (select string_agg(e.nama_lengkap, ', ' order by case k.peran when 'utama' then 0 else 1 end) from group_keepers k join employees e on e.id = k.employee_id
                where k.group_id = g.id and (k.mulai is null or k.mulai <= v_hari) and (k.sampai is null or k.sampai >= v_hari)),
      'santri', (select count(*) from group_members m join students s on s.id = m.student_id where m.group_id = g.id and m.selesai is null and s.status = 'aktif'),
      'sesi_rencana', v_rencana, 'sesi_terisi', a.terisi, 'anggota', a.anggota, 'hadir', a.hadir, 'izin', a.izin, 'sakit', a.sakit, 'absen', a.absen,
      'bolos', a.bolos, 'terlambat', a.terlambat,
      'persen', case when a.anggota > 0 then round(a.hadir * 100.0 / a.anggota, 1) end,
      'hari_ini_wajib', exists (select 1 from public.sesi_santri_tanggal('kelas', v_hari)),
      'hari_ini_terisi', exists (select 1 from student_attendance_sessions where group_id = g.id and jenis = 'kelas' and tanggal = v_hari),
      'sakit_aktif', (select count(*) from clinic_cases c where c.status = 'ditangani' and c.student_id in (select m.student_id from group_members m where m.group_id = g.id and m.selesai is null)),
      'izin_aktif', (select count(*) from student_permits p where p.status in ('disetujui','keluar') and p.student_id in (select m.student_id from group_members m where m.group_id = g.id and m.selesai is null)),
      'jp_terjadwal', jp.terjadwal, 'jp_terlaksana', jp.terlaksana, 'jp_tidak', jp.tidak, 'jp_kosong', jp.terjadwal - jp.terlaksana - jp.tidak,
      'jp_hari_ini', jp.hari_ini, 'jp_hari_ini_isi', jp.hari_ini_isi) x
      from student_groups g join academic_years ay on ay.id = g.academic_year_id and ay.aktif
      cross join lateral (select count(*) terisi, coalesce(sum(jumlah_anggota), 0) anggota, coalesce(sum(jumlah_hadir), 0) hadir, coalesce(sum(jumlah_izin), 0) izin,
                                 coalesce(sum(jumlah_sakit), 0) sakit, coalesce(sum(jumlah_absen), 0) absen, coalesce(sum(jumlah_bolos), 0) bolos,
                                 coalesce(sum(jumlah_terlambat), 0) terlambat
                            from student_attendance_sessions sa where sa.group_id = g.id and sa.jenis = 'kelas' and sa.tanggal between p_mulai and p_selesai) a
      cross join lateral (
        select count(*) filter (where sl.tgl <= v_akhir and sl.lewat) terjadwal,
               count(j.*) filter (where j.status = 'terlaksana' and sl.tgl <= v_akhir and sl.lewat) terlaksana,
               count(j.*) filter (where j.status = 'tidak_terlaksana' and sl.tgl <= v_akhir and sl.lewat) tidak,
               count(*) filter (where sl.tgl = v_hari) hari_ini, count(j.*) filter (where sl.tgl = v_hari) hari_ini_isi
          from (select d::date tgl, cs.assignment_id, cs.period_id,
                       ((d::date + p.jam_selesai)::timestamp at time zone 'Asia/Makassar') <= now() lewat
                  from generate_series(p_mulai, greatest(v_akhir, v_hari), interval '1 day') d
                  join class_schedules cs on cs.hari = extract(dow from d)::int and cs.group_id = g.id
                  join teaching_assignments t on t.id = cs.assignment_id and t.academic_year_id = ay.id
                  join lesson_periods p on p.id = cs.period_id
                 where extract(dow from d) <> 0 and not public.libur_tugas(d::date, 'sekolah')
                   and (d::date <= v_akhir or d::date = v_hari)) sl
          left join teaching_journals j on j.assignment_id = sl.assignment_id and j.tanggal = sl.tgl and j.period_id = sl.period_id) jp
     where g.jenis = 'kelas' and g.aktif and public.boleh_lihat_kelas(g.id)) q), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- 6. HAK FUNGSI
-- ---------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array['boleh_lihat_kelas(uuid)','kelas_walas()','absensi_kelas_rinci(uuid,date,date)','slot_mengajar(date,date,uuid,uuid)',
      'ringkasan_kelas(date,date)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 7. PEMERIKSAAN (hasil yang benar: semua "Sesuai")
-- ---------------------------------------------------------------------
select '1. Fungsi menu Wali Kelas' as pemeriksaan,
       case when (select count(*) from pg_proc where proname in ('boleh_lihat_kelas','kelas_walas','absensi_kelas_rinci','ringkasan_kelas')) = 4
            then 'Sesuai' else 'Periksa' end as hasil
union all select '2. Fungsi menu Guru Mapel (slot mengajar)',
       case when exists (select 1 from pg_proc where proname = 'slot_mengajar') then 'Sesuai' else 'Periksa' end
union all select '3. Tertutup bagi pengunjung tanpa masuk',
       case when not has_function_privilege('anon', 'public.kelas_walas()', 'execute')
             and not has_function_privilege('anon', 'public.slot_mengajar(date,date,uuid,uuid)', 'execute') then 'Sesuai' else 'Periksa' end;
