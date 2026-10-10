-- SIMKA PRO | supabase/migrations/20261010005800_akses_pengasuh.sql | v1.0 | Fase 8 – Tahap 0: akses pengasuh dan beranda pegawai | 10/10/2026
-- =====================================================================
-- Tujuan:
--   1. Pegawai fungsional (wali kelas, guru mapel, musyrif, muhaffizh, pembina ekskul, dll.) hanya membaca
--      kelompok dan santri yang DIAMPU. Hak fitur yang berasal dari jabatan fungsional (mis. Musyrif →
--      absensi_asrama tingkat 2) berarti "boleh mengisi untuk kelompoknya", BUKAN melihat semua kelompok.
--      Cakupan luas hanya untuk: admin/superadmin, hak fitur dari jabatan struktural, hak bidang/individu
--      yang diberikan superadmin, atau tingkat 3 (pengelola).
--      Celah yang ditutup (ditemukan lewat uji akses otomatis):
--        * Musyrif melihat semua kamar (kamar_musyrif, ringkasan_asrama, absensi_asrama_rinci,
--          daftar_jurnal_musyrif, tabel dorm_journals).
--        * Pembina ekskul melihat semua ekskul (ringkasan_ekskul, jurnal_ekskul).
--        * Guru mapel melihat rekap mengajar dan jurnal mengajar seluruh guru (jenjang_terlihat).
--        * Semua pegawai membaca penugasan, jadwal, dan rencana materi seluruh guru
--          (teaching_assignments, class_schedules, teaching_plans).
--        * status_otomatis_sesi dan rincian_beban dapat dipanggil untuk kelompok/pegawai mana pun.
--   2. Fungsi baru profil_tugas_saya(): tupoksi akun yang masuk (pimpinan tinggi atau bukan, jabatan
--      fungsional, kelompok asuhan, petugas klinik, petugas gerbang, penguji, cakupan luas per fitur)
--      untuk Beranda pegawai fungsional (sapaan, menu cepat sesuai tupoksi, "Untuk Anda").
-- Jalankan SETELAH migrasi 5700. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. CAKUPAN LUAS PER FITUR
-- ---------------------------------------------------------------------
create or replace function public.akses_luas(p_kode text)
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_admin() or (
    public.tingkat_fitur(p_kode) >= 1 and (
      public.tingkat_fitur(p_kode) >= 3
      or exists (
        select 1 from feature_grants g
         where g.feature_kode = p_kode and g.mode = 'tambah' and (
               (g.sasaran = 'struktural' and g.sasaran_id in (select es.structural_position_id from employee_structurals es
                                                               where es.employee_id = public.saya()))
            or (g.sasaran = 'individu' and g.sasaran_id = public.saya())
            or (g.sasaran = 'bidang' and g.sasaran_id in (
                  with recursive induk(id) as (
                    select org_unit_id from employees where id = public.saya()
                    union all select u.parent_id from org_units u join induk i on u.id = i.id where u.parent_id is not null)
                  select id from induk where id is not null))))))
$$;
revoke execute on function public.akses_luas(text) from public, anon;
grant execute on function public.akses_luas(text) to authenticated;

-- ---------------------------------------------------------------------
-- 2. ASRAMA: musyrif hanya kamarnya
-- ---------------------------------------------------------------------
create or replace function public.boleh_lihat_kamar(p_group uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.boleh_pantau_absensi() or public.akses_luas('absensi_asrama')
      or p_group in (select public.kelompok_saya())
$$;

-- ---------------------------------------------------------------------
-- 3. EKSKUL: pembina hanya ekskul binaannya
-- ---------------------------------------------------------------------
create or replace function public.ringkasan_ekskul(p_mulai date, p_selesai date)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_akhir date := least(p_selesai, public.hari_ini()); v_semua boolean := public.boleh_pantau_absensi() or public.akses_luas('absensi_ekskul');
begin
  if p_selesai < p_mulai or p_selesai - p_mulai > 400 then raise exception 'Rentang tanggal tidak sah (paling panjang 400 hari).'; end if;
  return coalesce((select jsonb_agg(x order by x->>'nama') from (
    select jsonb_build_object('id', g.id, 'nama', g.nama, 'keterangan', g.keterangan,
      'pembina', (select string_agg(e.nama_lengkap, ', ' order by k.peran) from group_keepers k join employees e on e.id = k.employee_id
                   where k.group_id = g.id and (k.sampai is null or k.sampai >= public.hari_ini())),
      'anggota_aktif', (select count(*) from group_members m join students s on s.id = m.student_id where m.group_id = g.id and m.selesai is null and s.status = 'aktif'),
      'pertemuan_rencana', (select count(*) from generate_series(p_mulai, v_akhir, interval '1 day') d cross join lateral public.sesi_kelompok(g.id, d::date) sk where sk.selesai <= now()),
      'pertemuan_terlaksana', a.terisi, 'anggota', a.anggota, 'hadir', a.hadir, 'izin', a.izin, 'sakit', a.sakit, 'absen', a.absen,
      'persen', case when a.anggota > 0 then round(a.hadir * 100.0 / a.anggota, 1) end,
      'jurnal_terisi', (select count(*) from extracurricular_journals j join student_attendance_sessions sa on sa.id = j.session_id
                         where sa.group_id = g.id and sa.tanggal between p_mulai and p_selesai),
      'terakhir', (select jsonb_build_object('tanggal', sa.tanggal, 'topik', j.topik) from student_attendance_sessions sa left join extracurricular_journals j on j.session_id = sa.id
                    where sa.group_id = g.id order by sa.tanggal desc limit 1)) x
      from student_groups g join academic_years ay on ay.id = g.academic_year_id and ay.aktif
      cross join lateral (select count(*) terisi, coalesce(sum(jumlah_anggota), 0) anggota, coalesce(sum(jumlah_hadir), 0) hadir, coalesce(sum(jumlah_izin), 0) izin,
                                 coalesce(sum(jumlah_sakit), 0) sakit, coalesce(sum(jumlah_absen), 0) absen
                            from student_attendance_sessions sa where sa.group_id = g.id and sa.jenis = 'ekskul' and sa.tanggal between p_mulai and p_selesai) a
     where g.jenis = 'ekskul' and g.aktif and (v_semua or g.id in (select public.kelompok_saya()))) q), '[]'::jsonb);
end $$;

create or replace function public.jurnal_ekskul(p_group uuid, p_mulai date, p_selesai date)
returns table (session_id uuid, tanggal date, jam_mulai time, jam_selesai time, topik text, uraian text, foto_id uuid,
               pengampu text, jumlah_anggota int, jumlah_hadir int, jumlah_izin int, jumlah_sakit int, jumlah_absen int)
language sql stable security definer set search_path = public as $$
  select sa.id, sa.tanggal, sa.jam_mulai, sa.jam_selesai, j.topik, j.uraian, j.foto_id,
         (select nama_lengkap from employees where id = sa.pengampu_id), sa.jumlah_anggota, sa.jumlah_hadir, sa.jumlah_izin, sa.jumlah_sakit, sa.jumlah_absen
  from student_attendance_sessions sa left join extracurricular_journals j on j.session_id = sa.id
  where sa.group_id = p_group and sa.jenis = 'ekskul' and sa.tanggal between p_mulai and p_selesai
    and (public.is_admin() or public.saya() in (select employee_id from group_keepers where group_id = p_group)
         or public.akses_luas('absensi_ekskul') or public.boleh_pantau_absensi())
  order by sa.tanggal, sa.jam_mulai
$$;

-- ---------------------------------------------------------------------
-- 4. JADWAL DAN JURNAL MENGAJAR: guru hanya miliknya; wali kelas juga kelasnya
-- ---------------------------------------------------------------------
create or replace function public.jenjang_terlihat()
returns text[] language plpgsql stable security definer set search_path = public as $$
declare v_wustha uuid; v_sma uuid; v_j text[] := '{}'; v_lain boolean;
begin
  if public.is_admin() then return array['wustha','sma']; end if;
  if not public.akses_luas('jadwal_mengajar') then return '{}'; end if;
  select id into v_wustha from org_units where kode = 'WUSTHA';
  select id into v_sma from org_units where kode = 'SMA';
  if exists (select 1 from public.unit_pimpinan_saya() u where u = v_wustha) then v_j := array_append(v_j, 'wustha'); end if;
  if exists (select 1 from public.unit_pimpinan_saya() u where u = v_sma) then v_j := array_append(v_j, 'sma'); end if;
  select exists (select 1 from public.unit_pimpinan_saya() u
                 where u not in (select public.unit_turunan(v_wustha)) and u not in (select public.unit_turunan(v_sma))) into v_lain;
  if v_lain or cardinality(v_j) = 0 then return array['wustha','sma']; end if;
  return v_j;
end $$;

drop policy if exists baca on public.teaching_assignments;
create policy baca on public.teaching_assignments for select to authenticated using (
  employee_id = (select public.saya()) or (select public.is_admin()) or (select public.akses_luas('jadwal_mengajar'))
  or public.pimpinan_dari(employee_id) or group_id in (select public.kelompok_saya()));

drop policy if exists baca on public.class_schedules;
create policy baca on public.class_schedules for select to authenticated using (
  employee_id = (select public.saya()) or (select public.is_admin()) or (select public.akses_luas('jadwal_mengajar'))
  or public.pimpinan_dari(employee_id) or group_id in (select public.kelompok_saya()));

drop policy if exists baca on public.teaching_plans;
create policy baca on public.teaching_plans for select to authenticated using (
  assignment_id in (select t.id from public.teaching_assignments t));

-- ---------------------------------------------------------------------
-- 5. STATUS OTOMATIS ABSENSI dan RINCIAN BEBAN: hanya yang berhak
-- ---------------------------------------------------------------------
create or replace function public.status_otomatis_sesi(p_group uuid, p_tanggal date, p_sesi text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare ss record;
begin
  -- Pemanggil: pengasuh kelompok (termasuk pengganti pada tanggal itu), admin, atau pemantau absensi.
  if auth.uid() is not null and not (public.is_admin() or public.boleh_pantau_absensi()
       or public.saya() in (select public._pengasuh_berlaku(p_group, p_tanggal))
       or p_group in (select public.kelompok_saya()) or public.boleh_lihat_kamar(p_group)) then
    return '[]'::jsonb;
  end if;
  select * into ss from public.sesi_kelompok(p_group, p_tanggal) x where x.kode = p_sesi;
  if not found then return '[]'::jsonb; end if;
  return coalesce((select jsonb_agg(z) from (
    select distinct on (sid) jsonb_build_object('student_id', sid, 'kode', kode, 'sumber', sumber, 'keterangan', ket, 'ref_id', ref) z
      from (
        select c.student_id sid, 'S' kode, 'klinik' sumber, 1 urut, c.id ref,
               'Klinik: ' || case c.tindak_lanjut when 'istirahat' then 'istirahat di kamar' when 'rawat' then 'dirawat di klinik'
                                  when 'rujuk' then 'dirujuk ke RS/puskesmas' when 'pulang' then 'dipulangkan' else 'sakit' end ket
          from clinic_cases c
         where c.student_id in (select public._anggota_pada(p_group, p_tanggal))
           and c.sakit_sejak is not null and c.sakit_sejak <= ss.selesai and c.status in ('ditangani','selesai')
           and (c.selesai_pada is null or c.selesai_pada > ss.mulai)
        union all
        select p.student_id, 'I', 'izin', 2, p.id,
               'Izin ' || case p.jenis when 'keluar' then 'keluar' else 'pulang' end || ' s.d. '
                 || to_char(p.kembali_batas at time zone 'Asia/Makassar', 'DD/MM HH24.MI') || ': ' || p.alasan
          from student_permits p
         where p.student_id in (select public._anggota_pada(p_group, p_tanggal))
           and p.status in ('disetujui','keluar','kembali')
           and coalesce(p.keluar_aktual, p.keluar_pada) <= ss.selesai
           and coalesce(p.kembali_pada, case when p.status = 'keluar' then 'infinity'::timestamptz else p.kembali_batas end) > ss.mulai
      ) a order by sid, urut) q), '[]'::jsonb);
end $$;

create or replace function public.rincian_beban(p_emp uuid)
returns table (component_id uuid, kode text, nama text, kolom text, kelompok text, sumber text, jam numeric, jam_bawaan numeric,
               otomatis boolean, ditimpa boolean, catatan text, urutan integer)
language sql stable security definer set search_path = public as $$
  with boleh as (select auth.uid() is null or public.boleh_lihat_beban(p_emp) as ya),
  tertaut as (
    select c.* from workload_components c
     where c.aktif and (c.structural_position_id in (select structural_position_id from employee_structurals where employee_id = p_emp)
        or c.functional_position_id in (select functional_position_id from employee_functions where employee_id = p_emp))
  )
  select c.id, c.kode, c.nama, c.kolom, c.kelompok, c.sumber, coalesce(w.jam, case when c.sumber = 'tetap' then c.jam_bawaan else 0 end), c.jam_bawaan,
         true, w.id is not null, w.catatan, c.urutan
    from tertaut c left join employee_workloads w on w.component_id = c.id and w.employee_id = p_emp
   where (select ya from boleh)
  union all
  select c.id, c.kode, c.nama, c.kolom, c.kelompok, c.sumber, w.jam, c.jam_bawaan, false, false, w.catatan, c.urutan
    from employee_workloads w join workload_components c on c.id = w.component_id
   where w.employee_id = p_emp and c.id not in (select id from tertaut) and (select ya from boleh)
  order by 12
$$;

-- ---------------------------------------------------------------------
-- 6. PROFIL TUGAS (untuk Beranda dan menu cepat)
-- ---------------------------------------------------------------------
create or replace function public.profil_tugas_saya()
returns jsonb language sql stable security definer set search_path = public as $$
  select case when public.saya() is null then '{}'::jsonb else jsonb_build_object(
    -- Pimpinan tinggi: Direktur, Wakil Direktur, Yayasan, Kepala Bidang, Kepala Unit (termasuk Plt yang sedang berlaku)
    'pimpinan', exists (select 1 from public.pemegang_jabatan(public.hari_ini()) h where h.employee_id = public.saya()
                         and h.kode in ('DIREKTUR','WAKIL_DIREKTUR','YAYASAN','KEPALA_BIDANG','KEPALA_UNIT')),
    'struktural', (select coalesce(jsonb_agg(distinct h.kode), '[]') from public.pemegang_jabatan(public.hari_ini()) h where h.employee_id = public.saya()),
    'fungsional', (select coalesce(jsonb_agg(fp.kode order by fp.urutan), '[]') from employee_functions ef
                     join functional_positions fp on fp.id = ef.functional_position_id where ef.employee_id = public.saya()),
    'kelompok', (select coalesce(jsonb_agg(distinct g.jenis), '[]') from public.kelompok_saya() k join student_groups g on g.id = k),
    'mengajar', exists (select 1 from teaching_assignments t join academic_years a on a.id = t.academic_year_id and a.aktif
                         where t.employee_id = public.saya()),
    'klinik', (select coalesce(jsonb_agg(distinct k), '[]') from public.klinik_petugas_saya() k),
    'gerbang', public.boleh_gerbang(),
    'penguji', exists (select 1 from tahfizh_examiners x where x.employee_id = public.saya() and x.aktif),
    'pantauan', public.is_admin() or public.tingkat_fitur('pantauan') >= 1,
    'luas', jsonb_build_object(
      'data_santri', public.akses_luas('data_santri'), 'absensi_kelas', public.akses_luas('absensi_kelas'),
      'absensi_halaqah', public.akses_luas('absensi_halaqah'), 'absensi_asrama', public.akses_luas('absensi_asrama'),
      'absensi_ekskul', public.akses_luas('absensi_ekskul'), 'jadwal_mengajar', public.akses_luas('jadwal_mengajar'),
      'tahfizh', public.akses_luas('tahfizh'), 'klinik', public.akses_luas('klinik'))) end
$$;
revoke execute on function public.profil_tugas_saya() from public, anon;
grant execute on function public.profil_tugas_saya() to authenticated;

do $$ declare f text; begin
  foreach f in array array['boleh_lihat_kamar(uuid)','ringkasan_ekskul(date,date)','jurnal_ekskul(uuid,date,date)','jenjang_terlihat()',
                           'status_otomatis_sesi(uuid,date,text)','rincian_beban(uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 7. PEMERIKSAAN (hasil yang benar: semua baris "Sesuai")
-- ---------------------------------------------------------------------
select '1. Fungsi akses_luas' as pemeriksaan,
       case when exists (select 1 from pg_proc where proname = 'akses_luas') then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Kamar memakai cakupan luas',
       case when position('akses_luas' in pg_get_functiondef('public.boleh_lihat_kamar(uuid)'::regprocedure)) > 0 then 'Sesuai' else 'Periksa' end
union all
select '3. Ekskul memakai cakupan luas',
       case when position('akses_luas' in pg_get_functiondef('public.ringkasan_ekskul(date,date)'::regprocedure)) > 0
             and position('akses_luas' in pg_get_functiondef('public.jurnal_ekskul(uuid,date,date)'::regprocedure)) > 0 then 'Sesuai' else 'Periksa' end
union all
select '4. Jurnal mengajar memakai cakupan luas',
       case when position('akses_luas' in pg_get_functiondef('public.jenjang_terlihat()'::regprocedure)) > 0 then 'Sesuai' else 'Periksa' end
union all
select '5. Penugasan, jadwal, rencana materi dibatasi',
       case when (select count(*) from pg_policies where tablename in ('teaching_assignments','class_schedules','teaching_plans')
                   and policyname = 'baca' and qual <> 'true') = 3 then 'Sesuai' else 'Periksa' end
union all
select '6. Fungsi profil_tugas_saya',
       case when exists (select 1 from pg_proc where proname = 'profil_tugas_saya') then 'Sesuai' else 'Periksa' end;
