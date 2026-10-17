-- SIMKA PRO | supabase/migrations/20261013008600_rapor_cetak.sql | v1.0 | Fase 12 – Tahap 5 Cetak rapor dan leger | 13/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 12 · Migrasi 86
--   A. Identitas sekolah per jenis rapor (sampul dan halaman identitas sekolah): report_settings.identitas
--   B. Nilai mapel rapor bersumber "Diisi wali kelas": report_manual_scores
--   C. Keputusan akhir tahun (semester 2): naik kelas / tinggal kelas / lulus / tidak lulus: report_decisions
--   D. Kehadiran rapor dalam HARI (sakit, izin, tanpa keterangan): satu hari dihitung hadir bila santri hadir pada salah
--      satu sesi hari itu (Hadir, Terlambat, Bolos = hadir); bila tidak, menurut keterangan terbanyak hari itu.
--   E. Bahan cetak: nilai_rapor_kelas, data_rapor (rapor SMA/Wustha, leger, sampul, identitas, ketercapaian, remidi,
--      tanda terima) dan data_rapor_tahfizh (rapor tahfizh per kelas atau per halaqah).
-- Jalankan SETELAH migrasi 8500. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- A. IDENTITAS SEKOLAH PER JENIS RAPOR
-- ---------------------------------------------------------------------
alter table public.report_settings add column if not exists identitas jsonb not null default '{}'::jsonb;

update public.report_settings set identitas = jsonb_build_object(
    'nama_sekolah', 'SMAS Tahfizhul Qur''an Imam Asy Syatiby W.I', 'jenjang', 'Sekolah Menengah Atas (SMA)',
    'npsn', '69981456', 'nss', '', 'alamat', 'Jalan Poros Malino-Sungguminasa Km.04, Dusun Bontobaddo', 'kode_pos', '92119',
    'kelurahan', 'Bontoramba', 'kecamatan', 'Somba Opu', 'kota', 'Gowa', 'provinsi', 'Sulawesi Selatan',
    'email', 'syathiby.gowa@gmail.com', 'telepon', '085256006743', 'kementerian', 'Kementerian Pendidikan Dasar dan Menengah Republik Indonesia')
 where jenis = 'sma' and identitas = '{}'::jsonb;
update public.report_settings set identitas = jsonb_build_object(
    'nama_sekolah', 'Kesetaraan Wustha PPS Tahfizhul Qur''an Imam Asy-Syathiby Wahdah Islamiyah Gowa', 'jenjang', 'Pendidikan Kesetaraan Wustha (setara SMP)',
    'npsn', '70023617', 'nss', '502373060054', 'alamat', 'Jalan Poros Malino KM.04, Lingkungan Bontobaddo', 'kode_pos', '92119',
    'kelurahan', 'Bontoramba', 'kecamatan', 'Somba Opu', 'kota', 'Gowa', 'provinsi', 'Sulawesi Selatan',
    'email', 'syathiby.gowa@gmail.com', 'telepon', '082194934531', 'kementerian', 'Kementerian Agama Kabupaten Gowa')
 where jenis = 'wustha' and identitas = '{}'::jsonb;
update public.report_settings set identitas = jsonb_build_object(
    'nama_sekolah', 'Pondok Pesantren Tahfizhul Qur''an Imam Asy-Syathiby Wahdah Islamiyah Gowa', 'jenjang', 'Program Tahfizhul Qur''an',
    'npsn', '70023617', 'nss', '502373060054', 'alamat', 'Jalan Poros Malino KM.04, Lingkungan Bontobaddo', 'kode_pos', '92119',
    'kelurahan', 'Bontoramba', 'kecamatan', 'Somba Opu', 'kota', 'Gowa', 'provinsi', 'Sulawesi Selatan',
    'email', 'syathiby.gowa@gmail.com', 'telepon', '085243324006', 'kementerian', 'Kementerian Agama Kabupaten Gowa')
 where jenis = 'tahfizh' and identitas = '{}'::jsonb;

-- Tahun ajaran baru menyalin identitas dari tahun sebelumnya (siapkan_penilaian menyalin baris report_settings; kolom
-- baru diisi dari tahun terakhir yang berisi bila masih kosong).
create or replace function public.tg_identitas_rapor()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.identitas = '{}'::jsonb then
    new.identitas := coalesce((select r.identitas from report_settings r join academic_years a on a.id = r.academic_year_id
                                where r.jenis = new.jenis and r.identitas <> '{}'::jsonb and r.academic_year_id <> new.academic_year_id
                                order by a.mulai desc limit 1), '{}'::jsonb);
  end if;
  return new;
end $$;
drop trigger if exists ab_identitas on public.report_settings;
create trigger ab_identitas before insert on public.report_settings for each row execute function public.tg_identitas_rapor();

-- simpan_ketentuan_rapor menerima kunci "identitas" lewat fungsi khusus berikut (ketentuan lain tetap lewat fungsi lama)
create or replace function public.simpan_identitas_rapor(p_ta uuid, p_jenis text, p jsonb)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v_ta uuid := coalesce(p_ta, (select id from academic_years where aktif));
begin
  perform public._cek_atur_penilaian(v_ta, p_jenis);
  if jsonb_typeof(p) <> 'object' then raise exception 'Identitas sekolah tidak sah.'; end if;
  update report_settings set identitas = (select coalesce(jsonb_object_agg(k, to_jsonb(trim(v))), '{}'::jsonb) from jsonb_each_text(p) x(k, v)),
         updated_by = public.saya()
   where academic_year_id = v_ta and jenis = p_jenis;
  if not found then raise exception 'Ketentuan rapor % belum disiapkan.', p_jenis; end if;
end $$;

-- ---------------------------------------------------------------------
-- B–C. TABEL
-- ---------------------------------------------------------------------
create table if not exists public.report_manual_scores (
  academic_year_id  uuid not null references public.academic_years(id) on delete cascade,
  semester          smallint not null constraint rms_semester check (semester in (1,2)),
  report_subject_id uuid not null references public.report_subjects(id) on delete cascade,
  student_id        uuid not null references public.students(id) on delete cascade,
  nilai             numeric(5,2) constraint rms_nilai check (nilai between 0 and 100),
  keterampilan      numeric(5,2) constraint rms_ket check (keterampilan between 0 and 100),
  deskripsi         text,
  diisi_oleh        uuid references public.employees(id) on delete set null,
  updated_at        timestamptz not null default now(),
  primary key (academic_year_id, semester, report_subject_id, student_id)
);
create table if not exists public.report_decisions (
  academic_year_id  uuid not null references public.academic_years(id) on delete cascade,
  student_id        uuid not null references public.students(id) on delete cascade,
  keputusan         text not null constraint rd_keputusan check (keputusan in ('naik','tinggal','lulus','tidak_lulus')),
  ke_tingkat        smallint constraint rd_tingkat check (ke_tingkat is null or ke_tingkat between 7 and 12),
  catatan           text,
  diisi_oleh        uuid references public.employees(id) on delete set null,
  updated_at        timestamptz not null default now(),
  primary key (academic_year_id, student_id)
);
do $$
declare t text;
begin
  foreach t in array array['report_manual_scores','report_decisions'] loop
    execute format('drop trigger if exists aa_updated on public.%I', t);
    execute format('create trigger aa_updated before update on public.%I for each row execute function public.tg_updated_at()', t);
    execute format('drop trigger if exists zz_audit on public.%I', t);
    execute format('create trigger zz_audit after insert or update or delete on public.%I for each row execute function public.tg_audit()', t);
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists baca_hak on public.%I', t);
    execute format('create policy baca_hak on public.%I for select to authenticated using (student_id in (select public.santri_terlihat()) or public.is_admin())', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- D. KEHADIRAN DALAM HARI
-- ---------------------------------------------------------------------
create or replace function public.kehadiran_harian(p_group uuid, p_mulai date, p_selesai date)
returns table (student_id uuid, hari int, hadir int, sakit int, izin int, absen int)
language sql stable security definer set search_path = public as $$
  with s as (
    select a.sid, sa.tanggal, coalesce(x.kode, 'H') kode
      from student_attendance_sessions sa
      cross join lateral (select y as sid from public._anggota_pada(sa.group_id, sa.tanggal) y) a
      left join student_attendance_exceptions x on x.session_id = sa.id and x.student_id = a.sid
     where sa.group_id = p_group and sa.tanggal between p_mulai and p_selesai),
  d as (
    select sid, tanggal, bool_or(kode not in ('I','S','A')) h,
           count(*) filter (where kode = 'S') ns, count(*) filter (where kode = 'I') ni, count(*) filter (where kode = 'A') na
      from s group by sid, tanggal)
  select sid, count(*)::int, count(*) filter (where h)::int,
         count(*) filter (where not h and ns >= ni and ns >= na)::int,
         count(*) filter (where not h and ni > ns and ni >= na)::int,
         count(*) filter (where not h and na > ns and na > ni)::int
    from d group by sid
$$;

-- ---------------------------------------------------------------------
-- E. NILAI MAPEL RAPOR SATU KELAS
-- ---------------------------------------------------------------------
-- Mapel ajar: rata-rata berbobot dari nilai guru (bobot dinormalkan atas sumber yang terisi); keterampilan kosong =
-- pengetahuan bila "keterampilan mengikuti pengetahuan"; deskripsi/sikap dari sumber (bila satu sumber); TP dari semua sumber.
-- Tahfizh: nilai akhir UTAS. Diisi wali kelas: report_manual_scores.
create or replace function public.nilai_rapor_kelas(p_group uuid, p_semester smallint)
returns table (student_id uuid, report_subject_id uuid, nilai numeric, keterampilan numeric, sikap text, deskripsi text, deskripsi_2 text, tp text[])
language plpgsql stable security definer set search_path = public as $$
declare g student_groups; v_ikut boolean;
begin
  select * into g from student_groups where id = p_group;
  if g.id is null or g.jenis <> 'kelas' or g.jenjang not in ('sma','wustha') then return; end if;
  select coalesce(r.keterampilan_ikut, true) into v_ikut from report_settings r where r.academic_year_id = g.academic_year_id and r.jenis = g.jenjang;
  return query
  with rs as (select r.* from report_subjects r where r.academic_year_id = g.academic_year_id and r.jenis = g.jenjang and r.tingkat = g.tingkat and r.aktif),
  anggota as (select m.student_id sid from group_members m where m.group_id = p_group group by m.student_id),
  src as (select r.id rid, t.id aid, x.bobot from rs r join report_subject_sources x on x.report_subject_id = r.id
            join teaching_assignments t on t.group_id = p_group and t.subject_id = x.subject_id where r.sumber = 'mapel'),
  nil as (select s.rid, n.student_id sid, s.aid, s.bobot, n.nilai nv, coalesce(n.keterampilan, case when coalesce(v_ikut, true) then n.nilai end) kv,
                 n.sikap sk, n.deskripsi d1, n.deskripsi_2 d2
            from src s cross join lateral public.nilai_mapel_ajar(s.aid, p_semester) n where n.student_id in (select sid from anggota)),
  agr as (select n.sid, n.rid,
                 round(sum(n.nv * n.bobot) filter (where n.nv is not null) / nullif(sum(n.bobot) filter (where n.nv is not null), 0), 2) nv,
                 round(sum(n.kv * n.bobot) filter (where n.kv is not null) / nullif(sum(n.bobot) filter (where n.kv is not null), 0), 2) kv,
                 (array_agg(n.sk order by n.bobot desc) filter (where n.sk is not null))[1] sk,
                 case when count(distinct n.aid) = 1 then max(n.d1) end d1, case when count(distinct n.aid) = 1 then max(n.d2) end d2,
                 array_agg(distinct n.aid) aids
            from nil n group by n.sid, n.rid)
  select a.sid, a.rid, a.nv, a.kv, a.sk, a.d1, a.d2,
         (select array_agg(o.teks order by o.assignment_id, o.urutan) from grade_objectives o where o.assignment_id = any(a.aids) and o.semester = p_semester)
    from agr a
  union all
  select u.student_id, r.id, u.nilai_akhir, u.nilai_akhir, null::text, null::text, null::text, null::text[]
    from rs r join utas_results u on u.academic_year_id = g.academic_year_id and u.semester = p_semester and u.nilai_akhir is not null
   where r.sumber = 'tahfizh' and u.student_id in (select sid from anggota)
  union all
  select m.student_id, r.id, m.nilai, coalesce(m.keterampilan, case when coalesce(v_ikut, true) then m.nilai end), null::text, m.deskripsi, null::text, null::text[]
    from rs r join report_manual_scores m on m.report_subject_id = r.id and m.academic_year_id = g.academic_year_id and m.semester = p_semester
   where r.sumber = 'manual' and m.student_id in (select sid from anggota);
end $$;

-- Ringkas penanda tangan: { jabatan, nama, niy }
create or replace function public._penanda_rapor(p_ta uuid, p_jenis text)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('jabatan', coalesce(r.jabatan_ttd, s.jabatan_tertulis), 'jabatan_lengkap', s.jabatan_tertulis, 'nama', s.nama, 'niy', s.niy)
    from report_settings r left join signatories s on s.id = r.signatory_id
   where r.academic_year_id = p_ta and r.jenis = p_jenis
$$;

-- Biodata santri untuk rapor (identitas peserta didik, sampul)
create or replace function public._biodata_rapor(p_student uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', s.id, 'nis', s.nis, 'nisn', s.nisn, 'nama', s.nama_lengkap, 'panggilan', s.nama_panggilan, 'jenis_kelamin', s.jenis_kelamin,
    'tempat_lahir', s.tempat_lahir, 'tanggal_lahir', s.tanggal_lahir, 'agama', coalesce(s.agama, 'Islam'), 'status_keluarga', s.status_keluarga, 'anak_ke', s.anak_ke,
    'alamat', concat_ws(', ', nullif(s.alamat, ''), case when s.rt is not null or s.rw is not null then concat('RT ', coalesce(s.rt, '-'), '/RW ', coalesce(s.rw, '-')) end,
                        nullif(s.kelurahan, ''), nullif(s.kecamatan, ''), nullif(s.kota_kab, ''), nullif(s.provinsi, '')),
    'telepon_rumah', s.telepon_rumah, 'asal_sekolah', s.asal_sekolah, 'diterima_tingkat', coalesce(s.diterima_tingkat, s.tingkat), 'tanggal_masuk', s.tanggal_masuk,
    'jenjang', s.jenjang, 'tingkat', s.tingkat, 'status', s.status,
    'ayah', (select jsonb_build_object('nama', c.nama, 'pekerjaan', c.pekerjaan, 'no_hp', c.no_hp, 'alamat', c.alamat) from student_contacts c where c.student_id = s.id and c.hubungan = 'ayah' order by c.utama desc limit 1),
    'ibu', (select jsonb_build_object('nama', c.nama, 'pekerjaan', c.pekerjaan, 'no_hp', c.no_hp, 'alamat', c.alamat) from student_contacts c where c.student_id = s.id and c.hubungan = 'ibu' order by c.utama desc limit 1),
    'wali', (select jsonb_build_object('nama', c.nama, 'pekerjaan', c.pekerjaan, 'no_hp', c.no_hp, 'alamat', c.alamat, 'hubungan', c.hubungan) from student_contacts c
              where c.student_id = s.id and c.hubungan not in ('ayah','ibu') order by c.utama desc limit 1),
    'alamat_ortu', s.alamat_ortu)
  from students s where s.id = p_student
$$;

-- ---------------------------------------------------------------------
-- E. DATA RAPOR KELAS (SMA/WUSTHA)
-- ---------------------------------------------------------------------
create or replace function public.data_rapor(p_group uuid, p_semester smallint)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare g student_groups; r record; v_ta academic_years;
begin
  select * into g from student_groups where id = p_group;
  if g.id is null or g.jenis <> 'kelas' then raise exception 'Kelas tidak ditemukan.'; end if;
  if g.jenjang not in ('sma','wustha') then raise exception 'Kelas ini belum berjenjang SMA/Wustha.'; end if;
  if not public._boleh_lihat_kelompok_rapor(p_group) then raise exception 'Anda tidak berwenang mencetak rapor kelas ini.' using errcode = '42501'; end if;
  select * into v_ta from academic_years where id = g.academic_year_id;
  select * into r from public.rentang_semester(g.academic_year_id, p_semester);
  return jsonb_build_object(
    'kelas', jsonb_build_object('group_id', g.id, 'nama', g.nama, 'keterangan', g.keterangan, 'jenjang', g.jenjang, 'tingkat', g.tingkat, 'jenis_kelamin', g.jenis_kelamin),
    'ta', jsonb_build_object('id', v_ta.id, 'nama', v_ta.nama, 'mulai', v_ta.mulai, 'selesai', v_ta.selesai),
    'semester', p_semester, 'rentang', jsonb_build_object('mulai', r.mulai, 'selesai', r.selesai),
    'boleh', public._boleh_isi_rapor(p_group, p_semester, g.jenjang),
    'periode', (select to_jsonb(p) from grade_periods p where p.academic_year_id = g.academic_year_id and p.jenis = g.jenjang and p.semester = p_semester),
    'ketentuan', (select to_jsonb(s) - 'updated_by' from report_settings s where s.academic_year_id = g.academic_year_id and s.jenis = g.jenjang),
    'penanda', public._penanda_rapor(g.academic_year_id, g.jenjang),
    'wali', coalesce((select jsonb_agg(jsonb_build_object('nama', e.nama_lengkap, 'niy', e.niy, 'peran', k.peran) order by (k.peran = 'utama') desc, e.nama_lengkap)
                       from group_keepers k join employees e on e.id = k.employee_id
                      where k.group_id = g.id and (k.sampai is null or k.sampai >= least(r.selesai, public.hari_ini()))), '[]'::jsonb),
    'predikat', coalesce((select jsonb_agg(to_jsonb(p) order by p.kelompok, p.urutan) from report_predicates p
                           where p.academic_year_id = g.academic_year_id and p.kelompok in (g.jenjang, 'pd', 'sikap', 'utas')), '[]'::jsonb),
    'kalimat_hadir', coalesce((select jsonb_agg(jsonb_build_object('min', x.min_nilai, 'teks', x.teks) order by x.min_nilai desc nulls last)
                       from report_phrases x where x.kategori = 'kehadiran' and x.aktif and (x.jenis is null or x.jenis = g.jenjang)), '[]'::jsonb),
    'mapel', coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'urutan', m.urutan, 'kelompok', m.kelompok, 'nama', m.nama, 'singkatan', m.singkatan, 'kkm', m.kkm, 'sumber', m.sumber,
                  'sumber_mapel', (select string_agg(sb.nama, ' + ' order by x.bobot desc) from report_subject_sources x join subjects sb on sb.id = x.subject_id where x.report_subject_id = m.id),
                  'guru', (select string_agg(distinct e.nama_lengkap, ', ') from report_subject_sources x join teaching_assignments t on t.subject_id = x.subject_id and t.group_id = g.id
                            join employees e on e.id = t.employee_id where x.report_subject_id = m.id)) order by m.urutan, m.nama)
               from report_subjects m where m.academic_year_id = g.academic_year_id and m.jenis = g.jenjang and m.tingkat = g.tingkat and m.aktif), '[]'::jsonb),
    'santri', coalesce((select jsonb_agg(public._biodata_rapor(s.id) || jsonb_build_object(
        'kehadiran', (select jsonb_build_object('hari', k.hari, 'hadir', k.hadir, 'sakit', k.sakit, 'izin', k.izin, 'absen', k.absen) from public.kehadiran_harian(p_group, r.mulai, r.selesai) k where k.student_id = s.id),
        'nilai', coalesce((select jsonb_object_agg(n.report_subject_id, jsonb_build_object('nilai', n.nilai, 'keterampilan', n.keterampilan, 'sikap', n.sikap, 'deskripsi', n.deskripsi,
                    'deskripsi_2', n.deskripsi_2, 'tp', to_jsonb(n.tp))) from public.nilai_rapor_kelas(p_group, p_semester) n where n.student_id = s.id), '{}'::jsonb),
        'pd', coalesce((select jsonb_agg(jsonb_build_object('kegiatan', eg.nama, 'nilai', x.nilai, 'deskripsi', x.deskripsi) order by eg.nama) from report_extracurricular x join student_groups eg on eg.id = x.group_id
                  where x.student_id = s.id and x.academic_year_id = g.academic_year_id and x.semester = p_semester and x.nilai is not null), '[]'::jsonb),
        'kokurikuler', (select jsonb_build_object('dimensi', c.dimensi, 'deskripsi', c.deskripsi) from report_cocurricular c
                  where c.student_id = s.id and c.academic_year_id = g.academic_year_id and c.semester = p_semester),
        'catatan', (select n.teks from report_notes n where n.student_id = s.id and n.academic_year_id = g.academic_year_id and n.semester = p_semester and n.jenis = 'wali'),
        'keputusan', case when p_semester = 2 then (select jsonb_build_object('keputusan', d.keputusan, 'ke_tingkat', d.ke_tingkat, 'catatan', d.catatan)
                  from report_decisions d where d.student_id = s.id and d.academic_year_id = g.academic_year_id) end,
        'tahfizh', jsonb_build_object('total_juz', (select count(*) from juz_achievements j where j.student_id = s.id),
                  'utas', (select jsonb_build_object('juz', u.juz, 'nilai', u.nilai_akhir, 'huruf', u.huruf, 'tuntas', u.tuntas, 'diuji_pada', u.diuji_pada, 'total_juz', u.total_juz)
                            from utas_results u where u.student_id = s.id and u.academic_year_id = g.academic_year_id and u.semester = p_semester)))
        order by s.nama_lengkap)
      from (select m.student_id from group_members m where m.group_id = p_group group by m.student_id having bool_or(m.selesai is null)) mm
      join students s on s.id = mm.student_id and s.status in ('aktif','nonaktif','lulus')), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------
-- E. DATA RAPOR TAHFIZH (kelompok kelas atau halaqah)
-- ---------------------------------------------------------------------
create or replace function public.data_rapor_tahfizh(p_group uuid, p_semester smallint)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare g student_groups; r record; v_ta academic_years;
begin
  select * into g from student_groups where id = p_group;
  if g.id is null or g.jenis not in ('kelas','halaqah') then raise exception 'Kelas/halaqah tidak ditemukan.'; end if;
  if not public._boleh_lihat_kelompok_rapor(p_group) then raise exception 'Anda tidak berwenang mencetak rapor tahfizh kelompok ini.' using errcode = '42501'; end if;
  select * into v_ta from academic_years where id = g.academic_year_id;
  select * into r from public.rentang_semester(g.academic_year_id, p_semester);
  return jsonb_build_object(
    'kelompok', jsonb_build_object('group_id', g.id, 'nama', g.nama, 'jenis', g.jenis, 'jenjang', g.jenjang, 'tingkat', g.tingkat),
    'ta', jsonb_build_object('id', v_ta.id, 'nama', v_ta.nama), 'semester', p_semester, 'rentang', jsonb_build_object('mulai', r.mulai, 'selesai', r.selesai),
    'periode', (select to_jsonb(p) from grade_periods p where p.academic_year_id = g.academic_year_id and p.jenis = 'tahfizh' and p.semester = p_semester),
    'ketentuan', (select to_jsonb(s) - 'updated_by' from report_settings s where s.academic_year_id = g.academic_year_id and s.jenis = 'tahfizh'),
    'fase', (select jsonb_object_agg(s.jenis, s.fase) from report_settings s where s.academic_year_id = g.academic_year_id and s.jenis in ('sma','wustha')),
    'penanda', public._penanda_rapor(g.academic_year_id, 'tahfizh'),
    'predikat', coalesce((select jsonb_agg(to_jsonb(p) order by p.urutan) from report_predicates p where p.academic_year_id = g.academic_year_id and p.kelompok = 'utas'), '[]'::jsonb),
    'kalimat_hadir', coalesce((select jsonb_agg(jsonb_build_object('min', x.min_nilai, 'teks', x.teks) order by x.min_nilai desc nulls last)
                       from report_phrases x where x.kategori = 'kehadiran_halaqah' and x.aktif), '[]'::jsonb),
    'santri', coalesce((select jsonb_agg(public._biodata_rapor(s.id) || jsonb_build_object(
        'kelas', (select kg.nama from group_members km join student_groups kg on kg.id = km.group_id
                   where km.student_id = s.id and kg.jenis = 'kelas' and kg.academic_year_id = g.academic_year_id order by km.selesai nulls first limit 1),
        'halaqah', h.nama, 'muhaffizh', (select jsonb_build_object('nama', e.nama_lengkap, 'niy', e.niy) from group_keepers k join employees e on e.id = k.employee_id
                   where k.group_id = h.id and (k.sampai is null or k.sampai >= least(r.selesai, public.hari_ini())) order by (k.peran = 'utama') desc limit 1),
        'kehadiran', (select jsonb_build_object('hari', k.hari, 'hadir', k.hadir, 'sakit', k.sakit, 'izin', k.izin, 'absen', k.absen)
                   from public.kehadiran_harian(h.id, r.mulai, r.selesai) k where k.student_id = s.id),
        'bulanan', coalesce((select jsonb_agg(jsonb_build_object('bulan', ma.bulan, 'posisi_akhir_hal', ma.posisi_akhir_hal, 'tambah_hal', ma.tambah_hal, 'target_hal', ma.target_hal,
                   'status', ma.status, 'total_resmi', ma.total_resmi) order by ma.bulan)
                   from monthly_achievements ma where ma.student_id = s.id and ma.bulan between date_trunc('month', r.mulai)::date and r.selesai), '[]'::jsonb),
        'kenaikan', coalesce((select jsonb_agg(jsonb_build_object('juz', te.juz, 'tajwid', te.nilai_tajwid, 'itqan', te.nilai_itqan, 'nilai', te.nilai_akhir, 'huruf', te.huruf,
                   'predikat', te.predikat, 'hasil', te.hasil, 'diuji_pada', te.diuji_pada) order by te.diuji_pada)
                   from tahfizh_exams te where te.student_id = s.id and te.jenis = 'kenaikan' and te.status = 'selesai' and te.diuji_pada::date between r.mulai and r.selesai), '[]'::jsonb),
        'total_juz', (select count(*) from juz_achievements j where j.student_id = s.id),
        'utas', (select jsonb_build_object('juz', u.juz, 'total_juz', u.total_juz, 'tajwid', u.tajwid, 'itqan', u.itqan, 'nilai', u.nilai_akhir, 'huruf', u.huruf, 'tuntas', u.tuntas,
                   'status', u.status, 'diuji_pada', u.diuji_pada)
                   from utas_results u where u.student_id = s.id and u.academic_year_id = g.academic_year_id and u.semester = p_semester),
        'catatan', (select n.teks from report_notes n where n.student_id = s.id and n.academic_year_id = g.academic_year_id and n.semester = p_semester and n.jenis = 'muhaffizh'))
        order by s.nama_lengkap)
      from (select m.student_id from group_members m where m.group_id = p_group group by m.student_id having bool_or(m.selesai is null)) mm
      join students s on s.id = mm.student_id and s.status in ('aktif','nonaktif','lulus')
      left join lateral (select hg.id, hg.nama from group_members hm join student_groups hg on hg.id = hm.group_id
                          where hm.student_id = s.id and hg.jenis = 'halaqah' and hg.academic_year_id = g.academic_year_id
                          order by (hg.id = p_group) desc, hm.selesai nulls first limit 1) h on true), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------
-- ISIAN WALI KELAS: NILAI MAPEL "DIISI WALI KELAS" DAN KEPUTUSAN AKHIR TAHUN
-- ---------------------------------------------------------------------
-- p: [{student_id, report_subject_id, nilai, keterampilan?, deskripsi?}] (nilai kosong dan deskripsi kosong = hapus)
create or replace function public.simpan_nilai_manual(p_group uuid, p_semester smallint, p jsonb)
returns int language plpgsql volatile security definer set search_path = public as $$
declare g student_groups; x jsonb; v_n int := 0;
begin
  select * into g from student_groups where id = p_group;
  if g.id is null or g.jenis <> 'kelas' then raise exception 'Kelas tidak ditemukan.'; end if;
  perform public._cek_isi_rapor(p_group, p_semester, g.jenjang);
  for x in select * from jsonb_array_elements(p) loop
    if not exists (select 1 from group_members where group_id = p_group and student_id = (x->>'student_id')::uuid) then raise exception 'Santri bukan anggota kelas ini.'; end if;
    if not exists (select 1 from report_subjects where id = (x->>'report_subject_id')::uuid and sumber = 'manual' and academic_year_id = g.academic_year_id
                    and jenis = g.jenjang and tingkat = g.tingkat) then
      raise exception 'Mapel rapor ini tidak diisi wali kelas.';
    end if;
    if nullif(x->>'nilai', '') is null and nullif(x->>'keterampilan', '') is null and nullif(trim(x->>'deskripsi'), '') is null then
      delete from report_manual_scores where academic_year_id = g.academic_year_id and semester = p_semester
         and report_subject_id = (x->>'report_subject_id')::uuid and student_id = (x->>'student_id')::uuid;
    else
      insert into report_manual_scores (academic_year_id, semester, report_subject_id, student_id, nilai, keterampilan, deskripsi, diisi_oleh)
      values (g.academic_year_id, p_semester, (x->>'report_subject_id')::uuid, (x->>'student_id')::uuid, nullif(x->>'nilai', '')::numeric,
              nullif(x->>'keterampilan', '')::numeric, nullif(trim(x->>'deskripsi'), ''), public.saya())
      on conflict (academic_year_id, semester, report_subject_id, student_id) do update set nilai = excluded.nilai, keterampilan = excluded.keterampilan,
        deskripsi = excluded.deskripsi, diisi_oleh = excluded.diisi_oleh;
    end if;
    v_n := v_n + 1;
  end loop;
  return v_n;
exception
  when check_violation then raise exception 'Nilai harus 0–100.';
end $$;

-- p: [{student_id, keputusan: naik|tinggal|lulus|tidak_lulus|'' (hapus), catatan?}]
create or replace function public.simpan_keputusan_rapor(p_group uuid, p jsonb)
returns int language plpgsql volatile security definer set search_path = public as $$
declare g student_groups; x jsonb; v_n int := 0; v_k text; v_ke smallint;
begin
  select * into g from student_groups where id = p_group;
  if g.id is null or g.jenis <> 'kelas' then raise exception 'Kelas tidak ditemukan.'; end if;
  perform public._cek_isi_rapor(p_group, 2::smallint, g.jenjang);
  for x in select * from jsonb_array_elements(p) loop
    if not exists (select 1 from group_members where group_id = p_group and student_id = (x->>'student_id')::uuid) then raise exception 'Santri bukan anggota kelas ini.'; end if;
    v_k := nullif(x->>'keputusan', '');
    if v_k is null then
      delete from report_decisions where academic_year_id = g.academic_year_id and student_id = (x->>'student_id')::uuid;
    else
      if v_k in ('lulus','tidak_lulus') and g.tingkat not in (9, 12) then raise exception 'Keputusan lulus/tidak lulus hanya untuk kelas 9 dan 12.'; end if;
      if v_k in ('naik','tinggal') and g.tingkat in (9, 12) then raise exception 'Kelas akhir jenjang memakai keputusan lulus/tidak lulus.'; end if;
      v_ke := case v_k when 'naik' then g.tingkat + 1 when 'tinggal' then g.tingkat end;
      insert into report_decisions (academic_year_id, student_id, keputusan, ke_tingkat, catatan, diisi_oleh)
      values (g.academic_year_id, (x->>'student_id')::uuid, v_k, v_ke, nullif(trim(x->>'catatan'), ''), public.saya())
      on conflict (academic_year_id, student_id) do update set keputusan = excluded.keputusan, ke_tingkat = excluded.ke_tingkat,
        catatan = case when x ? 'catatan' then excluded.catatan else report_decisions.catatan end, diisi_oleh = excluded.diisi_oleh;
    end if;
    v_n := v_n + 1;
  end loop;
  return v_n;
end $$;

-- ---------------------------------------------------------------------
-- HAK EKSEKUSI
-- ---------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array['simpan_identitas_rapor(uuid,text,jsonb)',
      'data_rapor(uuid,smallint)','data_rapor_tahfizh(uuid,smallint)','simpan_nilai_manual(uuid,smallint,jsonb)','simpan_keputusan_rapor(uuid,jsonb)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  -- dipakai di dalam data_rapor; tidak dipanggil langsung dari aplikasi
  foreach f in array array['_penanda_rapor(uuid,text)','_biodata_rapor(uuid)','tg_identitas_rapor()','kehadiran_harian(uuid,date,date)','nilai_rapor_kelas(uuid,smallint)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;
-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 5 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select '1. Identitas sekolah pada ketentuan rapor' as pemeriksaan,
       case when not exists (select 1 from report_settings where identitas = '{}'::jsonb) then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Tabel nilai manual dan keputusan akhir tahun (2) dengan RLS',
       case when (select count(*) from pg_tables where schemaname = 'public' and rowsecurity and tablename in ('report_manual_scores','report_decisions')) = 2 then 'Sesuai' else 'Periksa' end
union all
select '3. Fungsi cetak rapor', case when (select count(*) from pg_proc where proname in ('data_rapor','data_rapor_tahfizh','nilai_rapor_kelas','kehadiran_harian')) = 4 then 'Sesuai' else 'Periksa' end
union all
select '4. Tertutup bagi pengunjung tanpa masuk', case when not has_function_privilege('anon', 'public.data_rapor(uuid,smallint)', 'execute') then 'Sesuai' else 'Periksa' end
union all
select '5. Migrasi 8500 sudah terpasang', case when exists (select 1 from pg_proc where proname = 'bahan_rapor_kelas') then 'Sesuai' else 'Periksa: jalankan 8500 dulu' end;
