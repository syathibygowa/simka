-- SIMKA PRO | supabase/migrations/20261013008900_perbaikan_kelompok_pantauan.sql | v1.0 | Perbaikan: kelompok santri dan Layar Pantauan | 13/10/2026
-- =====================================================================
-- SIMKA PRO · Perbaikan pascauji (13/10/2026)
--   A. Kelompok santri: pemisahan putra/putri dapat diaktifkan atau dinonaktifkan per jenis kelompok (kelas, kamar,
--      halaqah, ekskul, lainnya) oleh superadmin dan admin ber-izin Kelompok santri.
--      Aktif  → kelompok wajib putra ATAU putri; hanya santri berjenis kelamin sama yang dapat dimasukkan.
--      Nonaktif → kelompok boleh campuran.  * institution_settings 'kelompok'; batasan student_groups_jk_wajib dihapus.
--   B. Layar Pantauan:
--      * pantauan_langsung(p_tanggal): dapat melihat hari sebelumnya (keadaan pada akhir hari itu, pukul 23.59 WITA).
--      * Pegawai: sementara bertugas (sedang di pondok pada sesi berjalan), cepat pulang, waktu absen pulang.
--      * Data baru: pelajaran (jurnal mengajar), perizinan santri dan pegawai, laporan kejadian, agenda, ujian tahfizh.
-- Aman dijalankan ulang. Jalankan setelah migrasi 8800.
-- =====================================================================

-- ---------------------------------------------------------------------
-- A. PEMISAHAN PUTRA/PUTRI KELOMPOK
-- ---------------------------------------------------------------------
insert into public.institution_settings (kunci, nilai, publik)
values ('kelompok', '{"pisah_jk": {"kelas": false, "kamar": true, "halaqah": true, "ekskul": false, "lainnya": false}}'::jsonb, false)
on conflict (kunci) do nothing;

alter table public.student_groups drop constraint if exists student_groups_jk_wajib;

create or replace function public.pisah_jk_kelompok(p_jenis text)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select (nilai->'pisah_jk'->>p_jenis)::boolean from institution_settings where kunci = 'kelompok'), p_jenis in ('kamar','halaqah'))
$$;

create or replace function public.pengaturan_kelompok()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('pisah_jk', jsonb_build_object(
    'kelas', public.pisah_jk_kelompok('kelas'), 'kamar', public.pisah_jk_kelompok('kamar'), 'halaqah', public.pisah_jk_kelompok('halaqah'),
    'ekskul', public.pisah_jk_kelompok('ekskul'), 'lainnya', public.pisah_jk_kelompok('lainnya')),
    'campuran', coalesce((select jsonb_object_agg(g.jenis, g.n) from (select g.jenis, count(*) n from student_groups g join academic_years a on a.id = g.academic_year_id and a.aktif
                  where g.aktif and g.jenis_kelamin is null group by g.jenis) g), '{}'::jsonb))
$$;

-- p: {"pisah_jk": {"kelas": true, ...}}
create or replace function public.simpan_pengaturan_kelompok(p jsonb)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v jsonb := '{}'::jsonb; k text;
begin
  if not (public.is_superadmin() or public.admin_boleh('kelompok_santri')) then
    raise exception 'Hanya superadmin dan admin ber-izin Kelompok santri yang dapat mengubah pengaturan ini.' using errcode = '42501';
  end if;
  foreach k in array array['kelas','kamar','halaqah','ekskul','lainnya'] loop
    v := v || jsonb_build_object(k, coalesce((p->'pisah_jk'->>k)::boolean, public.pisah_jk_kelompok(k)));
  end loop;
  insert into institution_settings (kunci, nilai, publik, updated_by) values ('kelompok', jsonb_build_object('pisah_jk', v), false, public.saya())
  on conflict (kunci) do update set nilai = institution_settings.nilai || jsonb_build_object('pisah_jk', v), updated_at = now(), updated_by = public.saya();
end $$;

-- simpan_kelompok (versi 8900): jenis kelamin wajib bila pemisahan putra/putri aktif untuk jenis kelompok itu
create or replace function public.simpan_kelompok(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid := nullif(p->>'id', '')::uuid; v_ta uuid; v_jenis text; v_tingkat smallint; v_jenjang text; v_wa text;
begin
  if not public.boleh_kelola_kelompok() then
    raise exception 'Anda tidak berwenang mengatur kelompok santri.' using errcode = '42501';
  end if;
  v_ta := coalesce(nullif(p->>'academic_year_id', '')::uuid, (select academic_year_id from student_groups where id = v_id),
                   (select id from academic_years where aktif));
  if v_ta is null then raise exception 'Belum ada tahun ajaran aktif. Atur di Pengaturan → Tahun ajaran.'; end if;
  perform public._ta_boleh_ubah(v_ta);
  v_jenis := coalesce(nullif(p->>'jenis', ''), (select jenis from student_groups where id = v_id));
  if public.pisah_jk_kelompok(v_jenis) and nullif(p->>'jenis_kelamin', '') is null then
    raise exception 'Kelompok ini wajib ditentukan putra atau putri (pemisahan putra/putri aktif untuk jenis ini).';
  end if;
  v_tingkat := nullif(p->>'tingkat', '')::smallint;
  v_jenjang := coalesce(nullif(p->>'jenjang', ''), case when v_tingkat >= 10 then 'sma' when v_tingkat >= 7 then 'wustha' end);
  if v_jenis <> 'kelas' then v_tingkat := null; v_jenjang := nullif(p->>'jenjang', ''); end if;
  foreach v_wa in array array[p->>'wa_wali', p->>'wa_internal'] loop
    if coalesce(v_wa, '') <> '' and v_wa !~* '^https?://' then
      raise exception 'Tautan grup WA harus diawali https:// (contoh https://chat.whatsapp.com/…).';
    end if;
  end loop;
  if v_id is null then
    insert into student_groups (academic_year_id, jenis, nama, jenjang, tingkat, jenis_kelamin, keterangan, wa_wali, wa_internal, naqib_id, aktif, urutan)
    values (v_ta, v_jenis, trim(p->>'nama'), v_jenjang, v_tingkat, nullif(p->>'jenis_kelamin', ''), nullif(trim(p->>'keterangan'), ''),
            nullif(trim(p->>'wa_wali'), ''), nullif(trim(p->>'wa_internal'), ''), nullif(p->>'naqib_id', '')::uuid,
            coalesce((p->>'aktif')::boolean, true), coalesce((p->>'urutan')::int, 0))
    returning id into v_id;
  else
    update student_groups set
      nama = trim(p->>'nama'), jenjang = v_jenjang, tingkat = v_tingkat,
      jenis_kelamin = nullif(p->>'jenis_kelamin', ''), keterangan = nullif(trim(p->>'keterangan'), ''),
      wa_wali = nullif(trim(p->>'wa_wali'), ''), wa_internal = nullif(trim(p->>'wa_internal'), ''),
      naqib_id = nullif(p->>'naqib_id', '')::uuid, aktif = coalesce((p->>'aktif')::boolean, aktif),
      urutan = coalesce((p->>'urutan')::int, urutan)
    where id = v_id;
    if not found then raise exception 'Kelompok tidak ditemukan.'; end if;
    if exists (select 1 from group_members m join students s on s.id = m.student_id join student_groups g on g.id = m.group_id
               where m.group_id = v_id and m.selesai is null and g.jenis_kelamin is not null and s.jenis_kelamin <> g.jenis_kelamin) then
      raise exception 'Masih ada anggota yang jenis kelaminnya berbeda dengan pilihan kelompok ini.';
    end if;
  end if;
  if (select naqib_id from student_groups where id = v_id) is not null and not exists (
      select 1 from group_members where group_id = v_id and selesai is null and student_id = (select naqib_id from student_groups where id = v_id)) then
    raise exception 'Naqib harus anggota aktif halaqah ini.';
  end if;
  return v_id;
end $$;

-- ---------------------------------------------------------------------
-- B. LAYAR PANTAUAN PER TANGGAL
-- ---------------------------------------------------------------------
drop function if exists public.pantauan_langsung();
create or replace function public.pantauan_langsung(p_tanggal date default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_hari date := coalesce(p_tanggal, public.hari_ini()); v_lalu boolean; v_kini timestamptz;
  v_awal timestamptz; v_santri jsonb; v_pegawai jsonb; v_sesi jsonb; v_sec jsonb; v_klinik jsonb; v_hafalan jsonb;
  v_pelajaran jsonb; v_izin jsonb; v_lapor jsonb; v_agenda jsonb; v_ujian jsonb;
begin
  if not public.boleh_pantauan() then raise exception 'Pantauan langsung untuk pimpinan, yayasan, admin, dan superadmin.' using errcode = '42501'; end if;
  if v_hari > public.hari_ini() then raise exception 'Tanggal pantauan belum terjadi.'; end if;
  v_lalu := v_hari < public.hari_ini();
  v_awal := v_hari::timestamp at time zone 'Asia/Makassar';
  v_kini := case when v_lalu then ((v_hari + 1)::timestamp at time zone 'Asia/Makassar') - interval '1 second' else now() end;

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
                  from clinic_cases c where c.student_id = s.id and c.status <> 'batal' and c.dibuka_pada <= v_kini and (c.selesai_pada is null or c.selesai_pada > v_kini)
                   and (c.status = 'menunggu' or c.tindak_lanjut in ('istirahat','rawat','rujuk')) order by c.dibuka_pada desc limit 1),
      'luar', (select jsonb_build_object('jenis', pm.jenis, 'alasan', pm.alasan, 'keluar', pm.keluar_aktual, 'batas', pm.kembali_batas, 'terlambat', v_kini > pm.kembali_batas)
                 from student_permits pm where pm.student_id = s.id and pm.status in ('keluar','kembali') and pm.keluar_aktual <= v_kini
                  and (pm.kembali_pada is null or pm.kembali_pada > v_kini) order by pm.keluar_aktual desc nulls last limit 1))
      order by s.nama_lengkap), '[]'::jsonb)
    into v_santri
    from students s left join per p on p.student_id = s.id where s.status = 'aktif';

  -- ---------- Pegawai ----------
  with j as materialized (
    select e.id emp, x.session_id, x.nama_sesi, x.mulai, x.selesai, x.batas_pulang, x.buka, x.tutup from employees e cross join lateral public.jadwal_pegawai(e.id, v_hari) x
     where e.status_akun = 'aktif' and e.status_keaktifan = 'aktif' and not x.opsional
  ), a as materialized (
    select employee_id emp, session_id, status, terlambat_menit, datang_pada, pulang_pada, status_pulang, cepat_pulang_menit, nama_sesi
      from attendances where tanggal = v_hari and not opsional
  ), cuti as (
    select distinct on (lr.employee_id) lr.employee_id emp, lt.status_presensi st, lt.nama
      from leave_requests lr join leave_types lt on lt.id = lr.leave_type_id
     where lr.status = 'disetujui' and v_hari between lr.mulai and lr.selesai order by lr.employee_id, lr.mulai
  ), g as (
    select e.id, e.nama_lengkap, e.jenis_kelamin, e.org_unit_id,
           (select array_agg(a.status) from a where a.emp = e.id and (a.datang_pada is null or a.datang_pada <= v_kini)) st,
           (select max(a.terlambat_menit) from a where a.emp = e.id) telat,
           (select min(a.datang_pada) from a where a.emp = e.id and a.datang_pada <= v_kini) datang,
           (select max(a.pulang_pada) from a where a.emp = e.id and a.pulang_pada <= v_kini) pulang,
           (select max(a.cepat_pulang_menit) from a where a.emp = e.id and a.status_pulang = 'cepat' and a.pulang_pada <= v_kini) cepat,
           (select j.nama_sesi from j join a on a.emp = j.emp and a.session_id = j.session_id
             where j.emp = e.id and v_kini >= j.mulai and v_kini < coalesce(j.batas_pulang, j.selesai)
               and a.datang_pada is not null and a.datang_pada <= v_kini and (a.pulang_pada is null or a.pulang_pada > v_kini)
               and a.status in ('hadir','terlambat') order by j.mulai limit 1) sesi_kini,
           (select count(*) from j where j.emp = e.id) wajib,
           (select count(*) from j where j.emp = e.id and v_kini >= j.buka) terbuka,
           (select count(*) from j where j.emp = e.id and v_kini < coalesce(j.batas_pulang, j.selesai)) belum_selesai,
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
      'bertugas', g.sesi_kini is not null, 'sesi_kini', g.sesi_kini, 'pulang_pada', g.pulang, 'cepat_menit', g.cepat,
      'sudah_pulang', g.sesi_kini is null and (g.wajib = 0 or (g.pulang is not null and g.belum_selesai = 0) or (g.pulang is not null and not exists (
                       select 1 from j where j.emp = g.id and v_kini >= j.mulai and v_kini < coalesce(j.batas_pulang, j.selesai)))),
      'ket', case when g.cuti_nama is not null then g.cuti_nama
                  when g.telat > 0 then 'Terlambat ' || g.telat || ' menit'
                  when g.datang is not null then 'Datang ' || to_char(g.datang at time zone 'Asia/Makassar', 'HH24.MI') end)
      order by g.nama_lengkap), '[]'::jsonb)
    into v_pegawai from g;

  -- ---------- Sesi kegiatan santri ----------
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

  -- ---------- Klinik: kasus terbuka pada saat itu dan kasus hari itu (tanpa diagnosis) ----------
  select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'student_id', c.student_id, 'nama', s.nama_lengkap, 'jk', s.jenis_kelamin, 'jenjang', s.jenjang,
      'kelas', public._kelompok_santri(s.id, 'kelas'), 'kamar', public._kelompok_santri(s.id, 'kamar'), 'klinik', c.klinik,
      'status', case when c.selesai_pada is not null and c.selesai_pada <= v_kini then 'selesai' when c.status = 'selesai' then 'ditangani' else c.status end,
      'tindak_lanjut', c.tindak_lanjut, 'keluhan', c.keluhan, 'dibuka_pada', c.dibuka_pada, 'kontrol_pada', c.kontrol_pada, 'hasil', c.hasil,
      'selesai_pada', case when c.selesai_pada <= v_kini then c.selesai_pada end,
      'periksa_hari_ini', (select count(*) from clinic_visits v where v.case_id = c.id and (v.waktu at time zone 'Asia/Makassar')::date = v_hari))
      order by c.dibuka_pada desc), '[]'::jsonb)
    into v_klinik
    from clinic_cases c join students s on s.id = c.student_id
   where c.status <> 'batal' and c.dibuka_pada <= v_kini and (c.selesai_pada is null or c.selesai_pada >= v_awal);

  -- ---------- Hafalan ----------
  select coalesce(jsonb_agg(jsonb_build_object('id', cb.student_id, 'resmi', cb.total_resmi, 'tambah', cb.tambah_hal, 'target', cb.target_hal, 'status', cb.status,
      'posisi', cb.posisi_akhir_hal, 'halaqah', cb.halaqah, 'program', cb.program,
      'hari_ini', (select coalesce(sum(l.tambah_hal), 0) from memorization_logs l where l.student_id = cb.student_id and l.tanggal = v_hari),
      'setor_hari_ini', exists (select 1 from memorization_logs l where l.student_id = cb.student_id and l.tanggal = v_hari))), '[]'::jsonb)
    into v_hafalan
    from public.capaian_bulanan(v_hari, null) cb;

  -- ---------- Security pada hari itu ----------
  v_sec := jsonb_build_object(
    'gerbang', coalesce((select jsonb_agg(jsonb_build_object('id', gl.id, 'jenis', gl.jenis, 'waktu', gl.waktu, 'nama', s.nama_lengkap, 'jk', s.jenis_kelamin, 'jenjang', s.jenjang,
        'kelas', public._kelompok_santri(s.id, 'kelas'), 'kamar', public._kelompok_santri(s.id, 'kamar'), 'penjemput', gl.penjemput, 'catatan', gl.catatan,
        'terlambat_menit', gl.terlambat_menit, 'petugas', e.nama_lengkap, 'foto_id', gl.foto_id) order by gl.waktu desc)
      from gate_logs gl join students s on s.id = gl.student_id left join employees e on e.id = gl.petugas_id
     where (gl.waktu at time zone 'Asia/Makassar')::date = v_hari), '[]'::jsonb),
    'titipan', coalesce((select jsonb_agg(public._titipan_json(t.id) || case when t.diterima_pada <= v_kini and (t.diambil_pada is null or t.diambil_pada > v_kini) and t.status <> 'batal'
                 then '{"status": "di_pos"}'::jsonb else '{}'::jsonb end order by t.diterima_pada desc) from parcels t
     where t.status <> 'batal' and t.diterima_pada <= v_kini and ((t.diambil_pada is null or t.diambil_pada > v_kini)
        or (t.diterima_pada at time zone 'Asia/Makassar')::date = v_hari or (t.diambil_pada at time zone 'Asia/Makassar')::date = v_hari)), '[]'::jsonb),
    'tamu', coalesce((select jsonb_agg(public._tamu_json(gt.id) || case when gt.keluar_pada > v_kini then '{"keluar_pada": null}'::jsonb else '{}'::jsonb end order by gt.masuk_pada desc)
      from guest_logs gt where gt.masuk_pada <= v_kini and ((gt.keluar_pada is null or gt.keluar_pada > v_kini) or (gt.masuk_pada at time zone 'Asia/Makassar')::date = v_hari)), '[]'::jsonb),
    'kunjungan', coalesce((select jsonb_agg(public._kunjungan_json(pv.id) || case when pv.pulang_pada > v_kini then '{"pulang_pada": null}'::jsonb else '{}'::jsonb end order by pv.datang_pada desc)
      from parent_visits pv where pv.datang_pada <= v_kini and ((pv.pulang_pada is null or pv.pulang_pada > v_kini) or (pv.datang_pada at time zone 'Asia/Makassar')::date = v_hari)), '[]'::jsonb));

  -- ---------- Pelajaran (jadwal mengajar dan jurnal) hari itu ----------
  select coalesce(jsonb_agg(jsonb_build_object('kelas', g.nama, 'jenjang', g.jenjang, 'jk', g.jenis_kelamin, 'mapel', sb.nama, 'guru', e.nama_lengkap,
      'jp', lp.nama, 'urutan', lp.urutan, 'jam_mulai', lp.jam_mulai, 'jam_selesai', lp.jam_selesai,
      'status', case when tj.status is not null then tj.status
                     when v_kini < (v_hari + lp.jam_mulai)::timestamp at time zone 'Asia/Makassar' then 'akan_datang'
                     when v_kini < (v_hari + lp.jam_selesai)::timestamp at time zone 'Asia/Makassar' then 'berlangsung' else 'belum_diisi' end,
      'materi', tj.materi) order by lp.jam_mulai, g.nama), '[]'::jsonb)
    into v_pelajaran
    from class_schedules cs join teaching_assignments t on t.id = cs.assignment_id join academic_years ay on ay.id = t.academic_year_id and ay.aktif
    join student_groups g on g.id = cs.group_id join subjects sb on sb.id = t.subject_id join employees e on e.id = cs.employee_id
    join lesson_periods lp on lp.id = cs.period_id
    left join teaching_journals tj on tj.assignment_id = cs.assignment_id and tj.period_id = cs.period_id and tj.tanggal = v_hari
   where cs.hari = extract(isodow from v_hari)::int and g.aktif and not public.libur_tugas(v_hari, 'sekolah');

  -- ---------- Perizinan santri dan pegawai ----------
  v_izin := jsonb_build_object(
    'santri', coalesce((select jsonb_agg(jsonb_build_object('id', pm.id, 'nama', s.nama_lengkap, 'nis', s.nis, 'jk', s.jenis_kelamin, 'jenjang', s.jenjang,
        'kelas', public._kelompok_santri(s.id, 'kelas'), 'kamar', public._kelompok_santri(s.id, 'kamar'), 'jenis', pm.jenis, 'alasan', pm.alasan, 'status', pm.status,
        'diajukan', pm.created_at, 'keluar', pm.keluar_aktual, 'batas', pm.kembali_batas, 'kembali', pm.kembali_pada,
        'menunggu', pm.status in ('diajukan','disetujui_bidang') and pm.created_at <= v_kini,
        'keluar_hari_ini', (pm.keluar_aktual at time zone 'Asia/Makassar')::date = v_hari,
        'kembali_hari_ini', (pm.kembali_pada at time zone 'Asia/Makassar')::date = v_hari,
        'terlambat', pm.keluar_aktual is not null and coalesce(pm.kembali_pada, v_kini) > pm.kembali_batas and (pm.kembali_pada is null or (pm.kembali_pada at time zone 'Asia/Makassar')::date = v_hari))
        order by pm.created_at desc)
      from student_permits pm join students s on s.id = pm.student_id
     where (pm.status in ('diajukan','disetujui_bidang') and not v_lalu)
        or (pm.keluar_aktual at time zone 'Asia/Makassar')::date = v_hari or (pm.kembali_pada at time zone 'Asia/Makassar')::date = v_hari
        or (pm.created_at at time zone 'Asia/Makassar')::date = v_hari), '[]'::jsonb),
    'pegawai', coalesce((select jsonb_agg(jsonb_build_object('id', lr.id, 'nama', e.nama_lengkap, 'jk', e.jenis_kelamin, 'jenis', lt.nama, 'status', lr.status,
        'mulai', lr.mulai, 'selesai', lr.selesai, 'hari', lr.jumlah_hari, 'alasan', lr.alasan, 'berlaku', lr.status = 'disetujui' and v_hari between lr.mulai and lr.selesai,
        'diajukan', lr.created_at) order by lr.created_at desc)
      from leave_requests lr join employees e on e.id = lr.employee_id join leave_types lt on lt.id = lr.leave_type_id
     where (lr.status = 'disetujui' and v_hari between lr.mulai and lr.selesai) or (lr.status = 'menunggu' and not v_lalu)
        or (lr.created_at at time zone 'Asia/Makassar')::date = v_hari), '[]'::jsonb));

  -- ---------- Laporan kejadian (menu Lapor) ----------
  select coalesce(jsonb_agg(jsonb_build_object('id', r.id, 'kategori', r.kategori, 'unit_kode', r.unit_kode, 'lokasi', r.lokasi, 'waktu', coalesce(r.waktu_kejadian, r.created_at),
      'uraian', left(r.uraian, 160), 'mendesak', r.mendesak, 'status', case when r.selesai_pada is not null and r.selesai_pada > v_kini then 'ditindaklanjuti' else r.status end,
      'hari_ini', (r.created_at at time zone 'Asia/Makassar')::date = v_hari) order by r.created_at desc), '[]'::jsonb)
    into v_lapor
    from incident_reports r
   where r.created_at <= v_kini and ((r.created_at at time zone 'Asia/Makassar')::date = v_hari or r.selesai_pada is null or r.selesai_pada > v_kini);

  -- ---------- Agenda hari itu ----------
  select coalesce(jsonb_agg(jsonb_build_object('id', a.id, 'judul', a.judul, 'jenis', a.jenis, 'jam_mulai', a.jam_mulai, 'jam_selesai', a.jam_selesai, 'lokasi', a.lokasi,
      'sasaran', a.ringkasan_sasaran) order by a.jam_mulai nulls first, a.judul), '[]'::jsonb)
    into v_agenda
    from agendas a where v_hari between a.mulai and coalesce(a.selesai, a.mulai);

  -- ---------- Ujian tahfizh hari itu ----------
  select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'jenis', x.jenis, 'juz', x.juz, 'jenjang_sertifikasi', x.jenjang, 'nama', s.nama_lengkap, 'nis', s.nis, 'jk', s.jenis_kelamin,
      'jenjang', s.jenjang, 'kelas', public._kelompok_santri(s.id, 'kelas'), 'halaqah', public._kelompok_santri(s.id, 'halaqah'),
      'status', case when x.diuji_pada is not null and x.diuji_pada > v_kini then 'dijadwalkan' else x.status end,
      'hasil', case when x.diuji_pada <= v_kini then x.hasil end, 'nilai', case when x.diuji_pada <= v_kini then x.nilai_akhir end,
      'jadwal', x.jadwal, 'penguji', pe.nama_lengkap) order by x.jadwal nulls last), '[]'::jsonb)
    into v_ujian
    from tahfizh_exams x join students s on s.id = x.student_id left join employees pe on pe.id = x.penguji_id
   where x.status <> 'dibatalkan' and ((x.jadwal at time zone 'Asia/Makassar')::date = v_hari or (x.diuji_pada at time zone 'Asia/Makassar')::date = v_hari);

  return jsonb_build_object('tanggal', v_hari, 'waktu', v_kini, 'lalu', v_lalu, 'santri', v_santri, 'pegawai', v_pegawai, 'sesi', v_sesi, 'security', v_sec, 'klinik', v_klinik,
    'hafalan', v_hafalan, 'pelajaran', v_pelajaran, 'izin', v_izin, 'lapor', v_lapor, 'agenda', v_agenda, 'ujian', v_ujian,
    'kelompok', (select jsonb_object_agg(j, n) from (select g.jenis j, count(*) n from student_groups g join academic_years ay on ay.id = g.academic_year_id and ay.aktif where g.aktif group by g.jenis) q),
    'bidang', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'nama', nama) order by urutan) from org_units where jenis = 'bidang' and aktif), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------
-- HAK EKSEKUSI
-- ---------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array['pantauan_langsung(date)','pengaturan_kelompok()','simpan_pengaturan_kelompok(jsonb)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  execute 'revoke execute on function public.pisah_jk_kelompok(text) from public, anon';
  execute 'grant execute on function public.pisah_jk_kelompok(text) to authenticated';
end $$;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 3 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select '1. Pengaturan pemisahan putra/putri kelompok' as pemeriksaan,
       case when exists (select 1 from institution_settings where kunci = 'kelompok')
             and not exists (select 1 from pg_constraint where conname = 'student_groups_jk_wajib') then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Layar Pantauan per tanggal', case when exists (select 1 from pg_proc where proname = 'pantauan_langsung' and pronargs = 1)
                                          and not exists (select 1 from pg_proc where proname = 'pantauan_langsung' and pronargs = 0) then 'Sesuai' else 'Periksa' end
union all
select '3. Migrasi 8700 sudah terpasang', case when exists (select 1 from pg_indexes where indexname = 'group_members_kelompok_mulai_idx') then 'Sesuai' else 'Periksa: jalankan 8700 dulu' end;
