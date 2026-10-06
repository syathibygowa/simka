-- SIMKA PRO | supabase/migrations/20261006005700_perbaikan_uji_coba.sql | v1.0 | Fase 7 – Perbaikan uji coba (layar pantauan, izin admin) | 06/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 7 · Migrasi 57: Perbaikan hasil uji coba pemilik proyek
--   * Nama izin admin tanpa keterangan "(Fase N)"; uraian kelola_izin_santri disesuaikan (catat gerbang kini oleh Security).
--   * pantauan_langsung() v2 untuk Layar Pantauan (slide presentasi/SmartTV): ditambah data klinik (kasus terbuka dan
--     selesai hari ini, tanpa diagnosis), hafalan santri (capaian bulan berjalan, juz resmi, setoran hari ini), kode bidang/unit
--     dan penanda musyrif/muhaffizh pegawai, ekskul santri, serta jumlah kelompok aktif per jenis.
-- Jalankan SETELAH migrasi 5600. Aman dijalankan ulang.
-- =====================================================================

update public.admin_capabilities set nama = regexp_replace(nama, '\s*\(Fase [0-9]+\)\s*$', '') where nama ~ '\(Fase [0-9]+\)';
update public.admin_capabilities set nama = 'Mengelola perizinan santri: lihat semua izin dan ketentuan' where kode = 'kelola_izin_santri';

create or replace function public.pantauan_langsung()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_hari date := public.hari_ini(); v_kini timestamptz := now(); v_santri jsonb; v_pegawai jsonb; v_sesi jsonb; v_sec jsonb; v_klinik jsonb; v_hafalan jsonb;
begin
  if not public.boleh_pantauan() then raise exception 'Pantauan langsung untuk pimpinan, yayasan, admin, dan superadmin.' using errcode = '42501'; end if;

  -- ---------- Santri ----------
  with sesi as (
    select sa.id, sa.jenis, sa.sesi, sa.nama_sesi, sa.group_id from student_attendance_sessions sa
     where sa.tanggal = v_hari and sa.jenis in ('kelas','halaqah','asrama')
  ), ikut as (
    select s.id sid, s.jenis, s.sesi, s.nama_sesi, a.x student_id, coalesce(e.kode, 'H') kode
      from sesi s cross join lateral (select x from public._anggota_pada(s.group_id, v_hari) x) a
      left join student_attendance_exceptions e on e.session_id = s.id and e.student_id = a.x
  ), per as (
    select student_id,
           count(*) filter (where jenis = 'kelas') kelas_sesi,
           count(*) filter (where jenis = 'kelas' and kode in ('I','S','A','B')) kelas_tidak,
           jsonb_object_agg(jenis || ':' || sesi, jsonb_build_object('n', nama_sesi, 'k', kode)) filter (where jenis in ('halaqah','asrama')) lain
      from ikut group by student_id
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', s.id, 'nama', s.nama_lengkap, 'nis', s.nis, 'jk', s.jenis_kelamin, 'jenjang', s.jenjang,
      'kelas', public._kelompok_santri(s.id, 'kelas'), 'kamar', public._kelompok_santri(s.id, 'kamar'), 'halaqah', public._kelompok_santri(s.id, 'halaqah'), 'ekskul', public._kelompok_santri(s.id, 'ekskul'),
      'kelas_sesi', coalesce(p.kelas_sesi, 0), 'kelas_tidak', coalesce(p.kelas_tidak, 0), 'sesi', coalesce(p.lain, '{}'::jsonb),
      'sakit', (select case c.tindak_lanjut when 'rawat' then 'Dirawat di klinik' when 'istirahat' then 'Istirahat (sakit)' when 'rujuk' then 'Dirujuk'
                                             else case when c.status = 'menunggu' then 'Menunggu pemeriksaan klinik' else 'Ditangani klinik' end end
                  from clinic_cases c where c.student_id = s.id and c.status in ('menunggu','ditangani')
                   and (c.status = 'menunggu' or c.tindak_lanjut in ('istirahat','rawat','rujuk')) order by c.dibuka_pada desc limit 1),
      'luar', (select jsonb_build_object('jenis', pm.jenis, 'alasan', pm.alasan, 'keluar', pm.keluar_aktual, 'batas', pm.kembali_batas, 'terlambat', v_kini > pm.kembali_batas)
                 from student_permits pm where pm.student_id = s.id and pm.status = 'keluar' order by pm.keluar_aktual desc nulls last limit 1))
      order by s.nama_lengkap), '[]'::jsonb)
    into v_santri
    from students s left join per p on p.student_id = s.id where s.status = 'aktif';

  -- ---------- Pegawai ----------
  with j as (
    select e.id emp, x.session_id, x.buka, x.tutup from employees e cross join lateral public.jadwal_pegawai(e.id, v_hari) x
     where e.status_akun = 'aktif' and e.status_keaktifan = 'aktif' and not x.opsional
  ), a as (
    select employee_id emp, status, terlambat_menit, datang_pada from attendances where tanggal = v_hari and not opsional
  ), cuti as (
    select distinct on (lr.employee_id) lr.employee_id emp, lt.status_presensi st, lt.nama
      from leave_requests lr join leave_types lt on lt.id = lr.leave_type_id
     where lr.status = 'disetujui' and v_hari between lr.mulai and lr.selesai order by lr.employee_id, lr.mulai
  ), g as (
    select e.id, e.nama_lengkap, e.jenis_kelamin, e.org_unit_id,
           (select array_agg(a.status) from a where a.emp = e.id) st,
           (select max(a.terlambat_menit) from a where a.emp = e.id) telat,
           (select min(a.datang_pada) from a where a.emp = e.id) datang,
           (select count(*) from j where j.emp = e.id) wajib,
           (select count(*) from j where j.emp = e.id and v_kini >= j.buka) terbuka,
           c.st cuti_st, c.nama cuti_nama
      from employees e left join cuti c on c.emp = e.id
     where e.status_keaktifan = 'aktif' and e.status_akun = 'aktif'
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', g.id, 'nama', g.nama_lengkap, 'jk', g.jenis_kelamin, 'bidang_id', public._bidang_unit(g.org_unit_id),
      'bidang', (select nama from org_units where id = public._bidang_unit(g.org_unit_id)), 'unit', (select nama from org_units where id = g.org_unit_id),
      'bidang_kode', (select kode from org_units where id = public._bidang_unit(g.org_unit_id)), 'unit_kode', (select kode from org_units where id = g.org_unit_id),
      'musyrif', exists (select 1 from employee_functions f join functional_positions fp on fp.id = f.functional_position_id where f.employee_id = g.id and fp.kode = 'MUSYRIF'),
      'muhaffizh', exists (select 1 from employee_functions f join functional_positions fp on fp.id = f.functional_position_id where f.employee_id = g.id and fp.kode = 'MUHAFFIZH'),
      'jabatan', coalesce((select sp.nama from employee_structurals es join structural_positions sp on sp.id = es.structural_position_id where es.employee_id = g.id limit 1),
                          (select string_agg(fp.nama, ', ' order by fp.urutan) from employee_functions f join functional_positions fp on fp.id = f.functional_position_id where f.employee_id = g.id)),
      'status', case when g.cuti_st in ('izin','sakit','cuti') or g.st && array['izin','sakit','cuti'] then coalesce(g.cuti_st, (select x from unnest(g.st) x where x in ('izin','sakit','cuti') limit 1))
                     when g.cuti_st = 'dinas_luar' or 'dinas_luar' = any (g.st) then 'dinas_luar'
                     when 'terlambat' = any (g.st) then 'terlambat'
                     when 'hadir' = any (g.st) then 'hadir'
                     when 'menunggu_verval' = any (g.st) then 'menunggu_verval'
                     when 'tanpa_keterangan' = any (g.st) then 'tanpa_keterangan'
                     when g.wajib = 0 then 'libur'
                     when g.terbuka > 0 then 'belum'
                     else 'akan_datang' end,
      'ket', case when g.cuti_nama is not null then g.cuti_nama
                  when g.telat > 0 then 'Terlambat ' || g.telat || ' menit'
                  when g.datang is not null then 'Datang ' || to_char(g.datang at time zone 'Asia/Makassar', 'HH24.MI') end)
      order by g.nama_lengkap), '[]'::jsonb)
    into v_pegawai from g;

  -- ---------- Sesi kegiatan santri hari ini ----------
  select coalesce(jsonb_agg(jsonb_build_object(
      'group_id', g.id, 'jenis', case g.jenis when 'kamar' then 'asrama' else g.jenis end, 'kelompok', g.nama, 'jk', g.jenis_kelamin, 'jenjang', g.jenjang,
      'sesi', ss.nama, 'mulai', ss.mulai, 'jam_mulai', ss.jam_mulai,
      'status', case when sa.id is not null then 'terisi' when v_kini < ss.buka then 'belum_buka' when v_kini <= ss.tutup then 'terbuka' else 'tidak_terisi' end,
      'hadir', sa.jumlah_hadir, 'anggota', coalesce(sa.jumlah_anggota, (select count(*) from public._anggota_pada(g.id, v_hari))),
      'pengampu', (select string_agg(e.nama_lengkap, ', ' order by e.nama_lengkap) from group_keepers k join employees e on e.id = k.employee_id
                    where k.group_id = g.id and k.employee_id in (select public._pengasuh_berlaku(g.id, v_hari))))
      order by ss.mulai, g.jenis, g.nama), '[]'::jsonb)
    into v_sesi
    from student_groups g join academic_years ay on ay.id = g.academic_year_id and ay.aktif
    cross join lateral public.sesi_kelompok(g.id, v_hari) ss
    left join student_attendance_sessions sa on sa.group_id = g.id and sa.tanggal = v_hari and sa.sesi = ss.kode
   where g.aktif and g.jenis in ('kelas','halaqah','kamar','ekskul');


  -- ---------- Klinik: kasus terbuka dan kasus yang selesai hari ini (tanpa diagnosis) ----------
  select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'student_id', c.student_id, 'nama', s.nama_lengkap, 'jk', s.jenis_kelamin, 'jenjang', s.jenjang,
      'kelas', public._kelompok_santri(s.id, 'kelas'), 'kamar', public._kelompok_santri(s.id, 'kamar'), 'klinik', c.klinik, 'status', c.status,
      'tindak_lanjut', c.tindak_lanjut, 'keluhan', c.keluhan, 'dibuka_pada', c.dibuka_pada, 'kontrol_pada', c.kontrol_pada, 'hasil', c.hasil, 'selesai_pada', c.selesai_pada,
      'periksa_hari_ini', (select count(*) from clinic_visits v where v.case_id = c.id and (v.waktu at time zone 'Asia/Makassar')::date = v_hari))
      order by c.dibuka_pada desc), '[]'::jsonb)
    into v_klinik
    from clinic_cases c join students s on s.id = c.student_id
   where c.status in ('menunggu','ditangani') or (c.selesai_pada at time zone 'Asia/Makassar')::date = v_hari or (c.dibuka_pada at time zone 'Asia/Makassar')::date = v_hari;

  -- ---------- Hafalan: capaian bulan berjalan per santri + setoran hari ini ----------
  select coalesce(jsonb_agg(jsonb_build_object('id', cb.student_id, 'resmi', cb.total_resmi, 'tambah', cb.tambah_hal, 'target', cb.target_hal, 'status', cb.status,
      'posisi', cb.posisi_akhir_hal, 'halaqah', cb.halaqah, 'program', cb.program,
      'hari_ini', (select coalesce(sum(l.tambah_hal), 0) from memorization_logs l where l.student_id = cb.student_id and l.tanggal = v_hari),
      'setor_hari_ini', exists (select 1 from memorization_logs l where l.student_id = cb.student_id and l.tanggal = v_hari))), '[]'::jsonb)
    into v_hafalan
    from public.capaian_bulanan(v_hari, null) cb;

  -- ---------- Security hari ini ----------
  v_sec := jsonb_build_object(
    'gerbang', coalesce((select jsonb_agg(jsonb_build_object('id', gl.id, 'jenis', gl.jenis, 'waktu', gl.waktu, 'nama', s.nama_lengkap, 'jk', s.jenis_kelamin, 'jenjang', s.jenjang,
        'kelas', public._kelompok_santri(s.id, 'kelas'), 'kamar', public._kelompok_santri(s.id, 'kamar'), 'penjemput', gl.penjemput, 'catatan', gl.catatan,
        'terlambat_menit', gl.terlambat_menit, 'petugas', e.nama_lengkap, 'foto_id', gl.foto_id) order by gl.waktu desc)
      from gate_logs gl join students s on s.id = gl.student_id left join employees e on e.id = gl.petugas_id
     where (gl.waktu at time zone 'Asia/Makassar')::date = v_hari), '[]'::jsonb),
    'titipan', coalesce((select jsonb_agg(public._titipan_json(t.id) order by t.diterima_pada desc) from parcels t
     where t.status = 'di_pos' or (t.diterima_pada at time zone 'Asia/Makassar')::date = v_hari or (t.diambil_pada at time zone 'Asia/Makassar')::date = v_hari), '[]'::jsonb),
    'tamu', coalesce((select jsonb_agg(public._tamu_json(gt.id) order by gt.masuk_pada desc) from guest_logs gt
     where gt.keluar_pada is null or (gt.masuk_pada at time zone 'Asia/Makassar')::date = v_hari), '[]'::jsonb),
    'kunjungan', coalesce((select jsonb_agg(public._kunjungan_json(pv.id) order by pv.datang_pada desc) from parent_visits pv
     where pv.pulang_pada is null or (pv.datang_pada at time zone 'Asia/Makassar')::date = v_hari), '[]'::jsonb));

  return jsonb_build_object('tanggal', v_hari, 'waktu', v_kini, 'santri', v_santri, 'pegawai', v_pegawai, 'sesi', v_sesi, 'security', v_sec, 'klinik', v_klinik, 'hafalan', v_hafalan,
    'kelompok', (select jsonb_object_agg(j, n) from (select g.jenis j, count(*) n from student_groups g join academic_years ay on ay.id = g.academic_year_id and ay.aktif where g.aktif group by g.jenis) q),
    'bidang', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'nama', nama) order by urutan) from org_units where jenis = 'bidang' and aktif), '[]'::jsonb));
end $$;
do $$ begin alter publication supabase_realtime add table public.memorization_logs; exception when others then null; end $$;

revoke execute on function public.pantauan_langsung() from public, anon;
grant execute on function public.pantauan_langsung() to authenticated;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN (hasil yang benar: kedua baris "Sesuai")
-- ---------------------------------------------------------------------
select '1. Nama izin admin tanpa teks fase' as pemeriksaan,
       case when not exists (select 1 from public.admin_capabilities where nama ~ 'Fase') then 'Sesuai' else 'Periksa' end as hasil
union all select '2. Layar pantauan memuat klinik dan hafalan',
       case when pg_get_functiondef('public.pantauan_langsung'::regproc) like '%capaian_bulanan%' then 'Sesuai' else 'Periksa' end;
