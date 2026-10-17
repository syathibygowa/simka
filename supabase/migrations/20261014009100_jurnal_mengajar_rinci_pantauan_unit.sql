-- SIMKA PRO | supabase/migrations/20261014009100_jurnal_mengajar_rinci_pantauan_unit.sql | v1.0 | Jurnal mengajar rinci, absensi santri per pelajaran, Layar Pantauan unit kerja | 14/10/2026
-- A. JURNAL MENGAJAR RINCI (ringan diisi)
--    * teaching_journals + bab, subbab, metode[], media[], absen (hanya santri yang TIDAK hadir: {student_id: kode}),
--      jumlah_anggota, jumlah_hadir. Kolom materi tetap diisi (bab – subbab) agar laporan lama tetap berjalan.
--    * Pengaturan 'jurnal_mengajar': batas_hari (bawaan 1 = H+1), absen_santri (bawaan aktif), daftar metode dan media.
--    * jadwal_mengajar_pekan(senin): jadwal mengajar Senin–Sabtu sepekan beserta jurnalnya (tanpa memilih tanggal).
--    * peserta_pelajaran(penugasan, tanggal): daftar santri kelas pada tanggal itu, ditandai otomatis bila sudah tercatat
--      tidak hadir di absensi kelas harian (wali kelas) — guru cukup menandai yang berbeda.
--    Beban data: SATU baris jurnal per jam pelajaran seperti sebelumnya; ketidakhadiran disimpan di kolom absen (jsonb)
--    pada baris yang sama, sehingga tidak ada tabel atau baris tambahan.
-- B. LAYAR PANTAUAN: data slide Pondok, Wali Kelas, Guru Mapel, Dokumen, Persuratan, Keuangan, Administrasi Pegawai.
--    Keuangan hanya dikirim kepada yang berhak melihat keuangan; perihal surat rahasia disamarkan.
-- Prasyarat: migrasi 8900 dan 9000 sudah terpasang. Aman dijalankan ulang.

-- =====================================================================
-- A. JURNAL MENGAJAR RINCI
-- =====================================================================
alter table public.teaching_journals add column if not exists bab text;
alter table public.teaching_journals add column if not exists subbab text;
alter table public.teaching_journals add column if not exists metode text[] not null default '{}';
alter table public.teaching_journals add column if not exists media text[] not null default '{}';
alter table public.teaching_journals add column if not exists absen jsonb not null default '{}'::jsonb;
alter table public.teaching_journals add column if not exists jumlah_anggota int;
alter table public.teaching_journals add column if not exists jumlah_hadir int;
create index if not exists teaching_journals_tanggal_idx on public.teaching_journals (tanggal);

insert into institution_settings (kunci, nilai, publik)
values ('jurnal_mengajar', '{"batas_hari": 1, "absen_santri": true,
  "metode": ["Ceramah", "Tanya jawab", "Diskusi", "Demonstrasi", "Praktik", "Penugasan", "Presentasi", "Talaqqi/hafalan", "Proyek", "Permainan"],
  "media": ["Papan tulis", "Buku paket", "Kitab", "Lembar kerja", "Proyektor/LCD", "Video", "Alat peraga", "Lingkungan sekitar"]}'::jsonb, false)
on conflict (kunci) do nothing;

create or replace function public.pengaturan_jurnal_mengajar()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('batas_hari', 1, 'absen_santri', true, 'metode', '[]'::jsonb, 'media', '[]'::jsonb)
         || coalesce((select nilai from institution_settings where kunci = 'jurnal_mengajar'), '{}'::jsonb)
$$;

create or replace function public.simpan_pengaturan_jurnal_mengajar(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v jsonb := public.pengaturan_jurnal_mengajar(); v_batas int := coalesce((p->>'batas_hari')::int, (v->>'batas_hari')::int);
begin
  if not (public.is_superadmin() or public.admin_boleh('atur_jadwal')) then
    raise exception 'Hanya superadmin dan admin ber-izin Jadwal pelajaran yang dapat mengubah pengaturan jurnal mengajar.' using errcode = '42501';
  end if;
  if v_batas < 0 or v_batas > 14 then raise exception 'Batas pengisian jurnal 0–14 hari.'; end if;
  v := v || jsonb_build_object('batas_hari', v_batas, 'absen_santri', coalesce((p->>'absen_santri')::boolean, (v->>'absen_santri')::boolean))
         || case when jsonb_typeof(p->'metode') = 'array' then jsonb_build_object('metode', p->'metode') else '{}'::jsonb end
         || case when jsonb_typeof(p->'media') = 'array' then jsonb_build_object('media', p->'media') else '{}'::jsonb end;
  insert into institution_settings (kunci, nilai, publik, updated_by) values ('jurnal_mengajar', v, false, public.saya())
  on conflict (kunci) do update set nilai = excluded.nilai, updated_by = excluded.updated_by, updated_at = now();
  return v;
end $$;

/** Jurnal mengajar tanggal itu masih dapat diisi (hari ini sampai batas_hari ke belakang; bawaan H+1). */
create or replace function public._jurnal_mengajar_terbuka(p_tanggal date)
returns boolean language sql stable security definer set search_path = public as $$
  select p_tanggal <= public.hari_ini() and p_tanggal >= public.hari_ini() - coalesce((public.pengaturan_jurnal_mengajar()->>'batas_hari')::int, 1)
$$;

-- Jadwal mengajar satu tanggal (versi 9100): jurnal rinci, isian terakhir (untuk isian otomatis), status terbuka/terkunci
create or replace function public.jadwal_mengajar(p_tanggal date default null, p_emp uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_tgl date := coalesce(p_tanggal, public.hari_ini()); v_emp uuid := coalesce(p_emp, public.saya()); v_dow int := extract(dow from v_tgl);
  v_jumat boolean;
begin
  if v_emp is null then return '[]'; end if;
  if v_emp <> public.saya() and not (public.is_admin() or public.pimpinan_dari(v_emp)) then
    raise exception 'Anda tidak berwenang melihat jadwal mengajar pegawai ini.' using errcode = '42501';
  end if;
  if v_dow = 0 or public.libur_tugas(v_tgl, 'sekolah') then return '[]'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
      'tanggal', v_tgl, 'terbuka', public._jurnal_mengajar_terbuka(v_tgl),
      'assignment_id', t.id, 'period_id', p.id, 'jam_ke', p.nama, 'urutan', p.urutan, 'jam_mulai', p.jam_mulai, 'jam_selesai', p.jam_selesai,
      'group_id', g.id, 'kelas', g.nama, 'jenjang', g.jenjang, 'mapel', s.nama, 'kode_mapel', s.kode,
      'jurnal', (select jsonb_build_object('id', j.id, 'status', j.status, 'materi', j.materi, 'keterangan', j.keterangan, 'plan_id', j.plan_id,
                   'bab', j.bab, 'subbab', j.subbab, 'metode', j.metode, 'media', j.media, 'absen', j.absen, 'jumlah_anggota', j.jumlah_anggota, 'jumlah_hadir', j.jumlah_hadir)
                 from teaching_journals j where j.assignment_id = t.id and j.tanggal = v_tgl and j.period_id = p.id),
      'rencana', (select jsonb_build_object('id', tp.id, 'topik', tp.topik) from teaching_plans tp
                  where tp.assignment_id = t.id and not exists (select 1 from teaching_journals j2 where j2.plan_id = tp.id and not (j2.tanggal = v_tgl))
                  order by tp.urutan, tp.created_at limit 1),
      'materi_terakhir', (select j3.materi from teaching_journals j3 where j3.assignment_id = t.id and j3.tanggal < v_tgl and j3.status = 'terlaksana'
                          order by j3.tanggal desc limit 1),
      'terakhir', (select jsonb_build_object('tanggal', j4.tanggal, 'bab', j4.bab, 'subbab', j4.subbab, 'metode', j4.metode, 'media', j4.media)
                   from teaching_journals j4 where j4.assignment_id = t.id and j4.tanggal < v_tgl and j4.status = 'terlaksana'
                   order by j4.tanggal desc, j4.updated_at desc limit 1))
    order by p.jam_mulai)
    from class_schedules cs join teaching_assignments t on t.id = cs.assignment_id join academic_years a on a.id = t.academic_year_id and a.aktif
    join lesson_periods p on p.id = cs.period_id join student_groups g on g.id = t.group_id join subjects s on s.id = t.subject_id
    where cs.employee_id = v_emp and cs.hari = v_dow), '[]');
end $$;

/** Jadwal mengajar sepekan (Senin–Sabtu) pekan yang memuat p_tanggal; hari libur tetap tampil dengan daftar kosong. */
create or replace function public.jadwal_mengajar_pekan(p_tanggal date default null, p_emp uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_senin date := coalesce(p_tanggal, public.hari_ini()) - (extract(isodow from coalesce(p_tanggal, public.hari_ini()))::int - 1); d date; v jsonb := '[]';
begin
  for i in 0..5 loop
    d := v_senin + i;
    v := v || jsonb_build_array(jsonb_build_object('tanggal', d, 'libur', public.libur_tugas(d, 'sekolah'), 'terbuka', public._jurnal_mengajar_terbuka(d),
                                                   'slot', public.jadwal_mengajar(d, p_emp)));
  end loop;
  return v;
end $$;

/** Peserta pelajaran: santri kelas pada tanggal itu; 'kode_kelas' = sudah tercatat tidak hadir di absensi kelas harian. */
create or replace function public.peserta_pelajaran(p_assignment uuid, p_tanggal date)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare t teaching_assignments;
begin
  select * into t from teaching_assignments where id = p_assignment;
  if not found then raise exception 'Penugasan mengajar tidak ditemukan.'; end if;
  if t.employee_id <> public.saya() and not (public.is_admin() or public.pimpinan_dari(t.employee_id) or t.group_id in (select public.kelompok_saya())) then
    raise exception 'Anda bukan guru pada penugasan ini.' using errcode = '42501';
  end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'nis', s.nis, 'nama', s.nama_lengkap, 'jk', s.jenis_kelamin,
      'kode_kelas', (select e.kode from student_attendance_sessions sa join student_attendance_exceptions e on e.session_id = sa.id and e.student_id = s.id
                      where sa.group_id = t.group_id and sa.tanggal = p_tanggal and sa.jenis = 'kelas' and e.kode in ('I','S','A')
                      order by sa.jam_mulai nulls last limit 1),
      'sakit', exists (select 1 from clinic_cases c where c.student_id = s.id and c.status <> 'batal' and c.tindak_lanjut in ('rawat','istirahat','rujuk')
                        and c.dibuka_pada::date <= p_tanggal and (c.selesai_pada is null or c.selesai_pada::date > p_tanggal)),
      'izin', exists (select 1 from student_permits pm where pm.student_id = s.id and pm.status in ('keluar') and pm.keluar_aktual::date <= p_tanggal
                       and (pm.kembali_pada is null or pm.kembali_pada::date > p_tanggal)))
      order by s.nama_lengkap)
    from public._anggota_pada(t.group_id, p_tanggal) x join students s on s.id = x and s.status = 'aktif'), '[]'::jsonb);
end $$;

-- Simpan jurnal mengajar (versi 9100): {tanggal, entri: [{assignment_id, period_id, status, bab, subbab, metode[], media[],
--   materi?, plan_id?, keterangan?, absen? {student_id: I|S|A|B|T}}]}
create or replace function public.simpan_jurnal_mengajar(p jsonb)
returns int language plpgsql volatile security definer set search_path = public as $$
declare v_tgl date := (p->>'tanggal')::date; r jsonb; n int := 0; v_saya uuid := public.saya(); t teaching_assignments;
  v_bab text; v_sub text; v_materi text; v_absen jsonb; v_anggota int; v_k text; v_v text; v_set jsonb := public.pengaturan_jurnal_mengajar();
begin
  if v_saya is null then raise exception 'Sesi masuk tidak berlaku.' using errcode = '42501'; end if;
  if v_tgl > public.hari_ini() then raise exception 'Jurnal mengajar tidak dapat diisi untuk tanggal yang akan datang.'; end if;
  if not public._jurnal_mengajar_terbuka(v_tgl) and not public.is_superadmin() then
    raise exception 'Jurnal tanggal ini sudah terkunci (batas pengisian H+%).', coalesce(v_set->>'batas_hari', '1');
  end if;
  for r in select * from jsonb_array_elements(coalesce(p->'entri', '[]')) loop
    select * into t from teaching_assignments where id = (r->>'assignment_id')::uuid;
    if not found then raise exception 'Penugasan mengajar tidak ditemukan.'; end if;
    if t.employee_id <> v_saya and not public.admin_boleh('atur_jadwal') then raise exception 'Anda bukan guru pada penugasan ini.' using errcode = '42501'; end if;
    if not exists (select 1 from class_schedules where assignment_id = t.id and period_id = (r->>'period_id')::uuid and hari = extract(dow from v_tgl)) then
      raise exception 'Jam tersebut tidak ada di jadwal pelajaran hari ini.';
    end if;
    v_bab := nullif(trim(r->>'bab'), ''); v_sub := nullif(trim(r->>'subbab'), '');
    v_materi := coalesce(nullif(trim(r->>'materi'), ''), nullif(concat_ws(' – ', v_bab, v_sub), ''));
    if coalesce(r->>'status', 'terlaksana') = 'terlaksana' and length(coalesce(v_materi, '')) < 3 then
      raise exception 'Isi bab/materi yang diajarkan (minimal 3 huruf).';
    end if;
    if r->>'status' = 'tidak_terlaksana' and length(trim(coalesce(r->>'keterangan', ''))) < 3 then
      raise exception 'Isi keterangan mengapa pelajaran tidak terlaksana.';
    end if;
    -- Ketidakhadiran santri: hanya anggota kelas pada tanggal itu dan kode sah; hadir tidak disimpan
    v_absen := '{}'::jsonb; v_anggota := null;
    if coalesce(r->>'status', 'terlaksana') = 'terlaksana' and coalesce((v_set->>'absen_santri')::boolean, true) and jsonb_typeof(r->'absen') = 'object' then
      select count(*) into v_anggota from public._anggota_pada(t.group_id, v_tgl) x join students s on s.id = x and s.status = 'aktif';
      for v_k, v_v in select key, value #>> '{}' from jsonb_each(r->'absen') loop
        if v_v in ('I','S','A','B','T') and exists (select 1 from public._anggota_pada(t.group_id, v_tgl) x where x = v_k::uuid) then
          v_absen := v_absen || jsonb_build_object(v_k, v_v);
        end if;
      end loop;
    end if;
    insert into teaching_journals (assignment_id, period_id, tanggal, employee_id, status, materi, plan_id, keterangan, bab, subbab, metode, media, absen, jumlah_anggota, jumlah_hadir)
    values (t.id, (r->>'period_id')::uuid, v_tgl, v_saya, coalesce(nullif(r->>'status', ''), 'terlaksana'), v_materi,
            nullif(r->>'plan_id', '')::uuid, nullif(trim(r->>'keterangan'), ''), v_bab, v_sub,
            coalesce(array(select jsonb_array_elements_text(case when jsonb_typeof(r->'metode') = 'array' then r->'metode' else '[]' end)), '{}'),
            coalesce(array(select jsonb_array_elements_text(case when jsonb_typeof(r->'media') = 'array' then r->'media' else '[]' end)), '{}'),
            v_absen, v_anggota,
            case when v_anggota is not null then v_anggota - (select count(*) from jsonb_each_text(v_absen) e where e.value in ('I','S','A','B')) end)
    on conflict (assignment_id, tanggal, period_id) do update set employee_id = excluded.employee_id, status = excluded.status,
      materi = excluded.materi, plan_id = excluded.plan_id, keterangan = excluded.keterangan, bab = excluded.bab, subbab = excluded.subbab,
      metode = excluded.metode, media = excluded.media, absen = excluded.absen, jumlah_anggota = excluded.jumlah_anggota,
      jumlah_hadir = excluded.jumlah_hadir, updated_at = now();
    n := n + 1;
  end loop;
  return n;
end $$;

-- =====================================================================
-- B. LAYAR PANTAUAN: UNIT KERJA
-- =====================================================================
create or replace function public.pantauan_langsung(p_tanggal date default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_dasar jsonb; v_hari date; v_kini timestamptz; v_sesi_peg jsonb; v_grup jsonb; v_awal_bulan date; v_ta uuid; v_smt int;
  v_kelas jsonb; v_mapel jsonb; v_dok jsonb; v_surat jsonb; v_keu jsonb; v_adm jsonb; v_umum jsonb; v_kelola_surat boolean;
begin
  v_dasar := public._pantauan_dasar(p_tanggal);           -- memeriksa hak akses dan tanggal
  v_hari := (v_dasar->>'tanggal')::date; v_kini := (v_dasar->>'waktu')::timestamptz;
  v_awal_bulan := date_trunc('month', v_hari)::date;
  select id into v_ta from academic_years where aktif limit 1;
  v_smt := case when extract(month from v_hari) >= 7 then 1 else 2 end;
  v_kelola_surat := public.boleh_kelola_persuratan() or public.is_superadmin();

  -- ---------- Kehadiran pegawai per sesi kerja (versi 9000) ----------
  with j as materialized (
    select e.id emp, x.session_id, x.nama_sesi, x.mulai, x.buka from employees e cross join lateral public.jadwal_pegawai(e.id, v_hari) x
     where e.status_akun = 'aktif' and e.status_keaktifan = 'aktif' and not x.opsional
  ), a as materialized (
    select employee_id emp, session_id, status, datang_pada, pulang_pada from attendances where tanggal = v_hari and not opsional
  )
  select coalesce(jsonb_object_agg(emp, daftar), '{}'::jsonb) into v_sesi_peg from (
    select j.emp::text emp, jsonb_agg(jsonb_build_object('n', j.nama_sesi, 'mulai', to_char(j.mulai at time zone 'Asia/Makassar', 'HH24:MI'),
             'st', case when a.status is not null and (a.datang_pada is null or a.datang_pada <= v_kini) then a.status
                        when v_kini < j.buka then 'akan_datang' else 'belum' end,
             'datang', case when a.datang_pada <= v_kini then a.datang_pada end, 'pulang', case when a.pulang_pada <= v_kini then a.pulang_pada end) order by j.mulai) daftar
      from j left join a on a.emp = j.emp and a.session_id = j.session_id
     group by j.emp) q;

  -- ---------- Rekap kelompok aktif (versi 9000 + id pengasuh) ----------
  select coalesce(jsonb_agg(jsonb_build_object('id', g.id, 'jenis', g.jenis, 'nama', g.nama, 'jk', g.jenis_kelamin, 'jenjang', g.jenjang, 'tingkat', g.tingkat,
      'pengasuh', (select string_agg(e.nama_lengkap, ', ' order by e.nama_lengkap) from employees e where e.id in (select public._pengasuh_berlaku(g.id, v_hari))),
      'pengasuh_ids', (select coalesce(jsonb_agg(x), '[]'::jsonb) from public._pengasuh_berlaku(g.id, v_hari) x),
      'l', m.l, 'p', m.p) order by g.jenis, g.urutan nulls last, g.nama), '[]'::jsonb)
    into v_grup
    from student_groups g join academic_years ay on ay.id = g.academic_year_id and ay.aktif
    cross join lateral (select count(*) filter (where s.jenis_kelamin = 'L') l, count(*) filter (where s.jenis_kelamin = 'P') p
                          from public._anggota_pada(g.id, v_hari) x join students s on s.id = x and s.status = 'aktif') m
   where g.aktif and g.jenis in ('kelas','kamar','halaqah','ekskul');

  -- ---------- Wali kelas: ketidakhadiran kelas hari itu, alfa/bolos bulan ini, catatan wali ----------
  v_kelas := jsonb_build_object(
    'absen', coalesce((select jsonb_agg(jsonb_build_object('id', e.student_id, 'kode', e.kode, 'sesi', sa.nama_sesi, 'ket', e.keterangan))
      from student_attendance_sessions sa join student_attendance_exceptions e on e.session_id = sa.id
     where sa.tanggal = v_hari and sa.jenis = 'kelas' and sa.created_at <= v_kini), '[]'::jsonb),
    'alfa_bulan', coalesce((select jsonb_agg(jsonb_build_object('id', q.student_id, 'n', q.n)) from (
      select e.student_id, count(*) n from student_attendance_sessions sa join student_attendance_exceptions e on e.session_id = sa.id
       where sa.tanggal between v_awal_bulan and v_hari and sa.jenis = 'kelas' and e.kode in ('A','B') group by e.student_id having count(*) >= 3) q), '[]'::jsonb),
    'catatan_wali', (select count(*) from report_notes rn where rn.academic_year_id = v_ta and rn.semester = v_smt and rn.jenis = 'wali'),
    'semester', v_smt);

  -- ---------- Guru mapel: guru mengajar hari itu, ketidakhadiran santri per pelajaran, jurnal bulan ini ----------
  v_mapel := jsonb_build_object(
    'guru', coalesce((select jsonb_agg(distinct cs.employee_id) from class_schedules cs join teaching_assignments t on t.id = cs.assignment_id
        join academic_years ay on ay.id = t.academic_year_id and ay.aktif
       where cs.hari = extract(isodow from v_hari)::int and extract(isodow from v_hari) <> 7 and not public.libur_tugas(v_hari, 'sekolah')), '[]'::jsonb),
    'absen', coalesce((select jsonb_agg(jsonb_build_object('id', e.key, 'kode', e.value #>> '{}', 'mapel', sb.nama, 'kelas', g.nama, 'jp', lp.nama, 'guru', em.nama_lengkap))
      from teaching_journals tj cross join lateral jsonb_each(tj.absen) e join teaching_assignments t on t.id = tj.assignment_id join subjects sb on sb.id = t.subject_id
      join student_groups g on g.id = t.group_id join lesson_periods lp on lp.id = tj.period_id left join employees em on em.id = t.employee_id
     where tj.tanggal = v_hari and tj.created_at <= v_kini), '[]'::jsonb),
    'diabsen', (select count(*) from teaching_journals tj where tj.tanggal = v_hari and tj.jumlah_anggota is not null and tj.created_at <= v_kini),
    'bulan', (select jsonb_build_object('total', count(*), 'terlaksana', count(*) filter (where status = 'terlaksana'), 'tidak', count(*) filter (where status = 'tidak_terlaksana'),
                     'rinci', count(*) filter (where bab is not null))
                from teaching_journals where tanggal between v_awal_bulan and v_hari));

  -- ---------- Dokumen resmi dan berkas pegawai ----------
  v_dok := jsonb_build_object(
    'sah', (select count(*) from document_registry where status = 'sah'),
    'terbit', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'jenis', d.jenis_nama, 'nomor', d.nomor, 'perihal', d.perihal, 'subjek', d.subjek, 'status', d.status,
        'waktu', d.diterbitkan_pada, 'hari_ini', (d.diterbitkan_pada at time zone 'Asia/Makassar')::date = v_hari) order by d.diterbitkan_pada desc)
      from document_registry d where d.diterbitkan_pada <= v_kini and d.diterbitkan_pada >= (v_awal_bulan::timestamp at time zone 'Asia/Makassar')), '[]'::jsonb),
    'draf', (select count(*) from document_registry where status = 'draf'),
    'dicabut_bulan', (select count(*) from document_registry where status in ('dicabut','direvisi') and coalesce(dicabut_pada, created_at) >= (v_awal_bulan::timestamp at time zone 'Asia/Makassar')),
    'menunggu_ttd', coalesce((select jsonb_agg(jsonb_build_object('jenis', d.jenis_nama, 'nomor', d.nomor, 'perihal', d.perihal, 'penanda', s.nama, 'jabatan', s.jabatan)) from document_signatures s
      join document_registry d on d.id = s.document_id where s.status = 'menunggu' and d.status in ('draf','sah')), '[]'::jsonb),
    'dicek_hari', (select count(*) from document_registry where (terakhir_dicek at time zone 'Asia/Makassar')::date = v_hari),
    'berkas', coalesce((select jsonb_agg(jsonb_build_object('judul', ed.judul, 'kategori', ed.kategori, 'sasaran', ed.ringkasan_sasaran, 'berlaku_sampai', ed.berlaku_sampai,
        'target', (select count(*) from employee_document_targets x where x.document_id = ed.id),
        'dibuka', (select count(*) from employee_document_targets x where x.document_id = ed.id and x.dibuka_pertama is not null)) order by ed.created_at desc)
      from employee_documents ed where ed.berlaku_sampai is null or ed.berlaku_sampai >= v_hari), '[]'::jsonb));

  -- ---------- Persuratan ----------
  v_surat := jsonb_build_object(
    'masuk', coalesce((select jsonb_agg(jsonb_build_object('agenda', l.nomor_agenda, 'tanggal', l.tanggal_terima, 'pengirim', l.pengirim,
        'perihal', case when l.sifat = 'rahasia' and not v_kelola_surat then 'Rahasia' else l.perihal end, 'sifat', l.sifat, 'status', l.status,
        'hari_ini', l.tanggal_terima = v_hari, 'bulan_ini', l.tanggal_terima >= v_awal_bulan) order by l.tanggal_terima desc, l.urut_agenda desc)
      from incoming_letters l where l.status <> 'batal' and l.created_at <= v_kini
       and (l.tanggal_terima >= v_awal_bulan or l.status in ('diteruskan','didisposisi'))), '[]'::jsonb),
    'disposisi', coalesce((select jsonb_agg(jsonb_build_object('perihal', case when l.sifat = 'rahasia' and not v_kelola_surat then 'Rahasia' else l.perihal end,
        'dari', ed.nama_lengkap, 'kepada', ek.nama_lengkap, 'status', d.status, 'batas', d.batas, 'lewat', d.batas < v_hari and d.status <> 'selesai'))
      from letter_dispositions d join incoming_letters l on l.id = d.letter_id join employees ed on ed.id = d.dari_id join employees ek on ek.id = d.kepada_id
     where d.status <> 'selesai' and l.status <> 'batal'), '[]'::jsonb),
    'keluar', coalesce((select jsonb_agg(jsonb_build_object('jenis', o.jenis_nama, 'nomor', o.nomor, 'perihal', o.perihal, 'kepada', o.kepada, 'status', o.status,
        'tanggal', o.tanggal_surat, 'terbit_hari', (o.terbit_pada at time zone 'Asia/Makassar')::date = v_hari,
        'terbit_bulan', o.terbit_pada >= (v_awal_bulan::timestamp at time zone 'Asia/Makassar')) order by coalesce(o.terbit_pada, o.created_at) desc)
      from outgoing_letters o where o.created_at <= v_kini and (o.status in ('draf','diperiksa','menunggu_ttd') or o.terbit_pada >= (v_awal_bulan::timestamp at time zone 'Asia/Makassar'))), '[]'::jsonb));

  -- ---------- Keuangan santri (hanya pemegang hak lihat keuangan) ----------
  if public.boleh_lihat_keuangan() then
    v_keu := jsonb_build_object('boleh', true,
      'bayar', coalesce((select jsonb_agg(jsonb_build_object('nomor', py.nomor, 'nama', s.nama_lengkap, 'nis', s.nis, 'kelas', public._kelompok_santri(s.id, 'kelas'),
          'jumlah', py.jumlah, 'cara', py.cara, 'status', py.status, 'tanggal', py.tanggal, 'waktu', py.created_at) order by py.created_at desc)
        from payments py join students s on s.id = py.student_id where py.tanggal between v_awal_bulan and v_hari and py.created_at <= v_kini), '[]'::jsonb),
      'tagih_bulan', (select jsonb_build_object('n', count(*), 'nominal', coalesce(sum(nominal), 0), 'dibayar', coalesce(sum(dibayar), 0), 'lunas', count(*) filter (where status = 'lunas'))
                        from bills where status <> 'batal' and tanggal_tagih between v_awal_bulan and (date_trunc('month', v_hari) + interval '1 month - 1 day')::date),
      'tunggak', coalesce((select jsonb_agg(jsonb_build_object('nama', s.nama_lengkap, 'nis', s.nis, 'jk', s.jenis_kelamin, 'kelas', public._kelompok_santri(s.id, 'kelas'),
          'n', q.n, 'sisa', q.sisa, 'tertua', q.tertua) order by q.sisa desc)
        from (select b.student_id, count(*) n, sum(b.nominal - b.dibayar) sisa, min(b.jatuh_tempo) tertua from bills b
               where b.status in ('belum','sebagian') and b.jatuh_tempo < v_hari group by b.student_id) q join students s on s.id = q.student_id where s.status = 'aktif'), '[]'::jsonb),
      'tempo7', (select jsonb_build_object('n', count(*), 'sisa', coalesce(sum(nominal - dibayar), 0)) from bills
                  where status in ('belum','sebagian') and jatuh_tempo between v_hari and v_hari + 7));
  else
    v_keu := jsonb_build_object('boleh', false);
  end if;

  -- ---------- Administrasi pegawai ----------
  v_adm := jsonb_build_object(
    'cuti', coalesce((select jsonb_agg(jsonb_build_object('nama', e.nama_lengkap, 'jenis', lt.nama, 'mulai', lr.mulai, 'selesai', lr.selesai, 'alasan', lr.alasan))
      from leave_requests lr join employees e on e.id = lr.employee_id join leave_types lt on lt.id = lr.leave_type_id where lr.status = 'menunggu'), '[]'::jsonb),
    'koreksi', coalesce((select jsonb_agg(jsonb_build_object('nama', e.nama_lengkap, 'status_baru', c.status_baru, 'alasan', c.alasan, 'waktu', c.created_at))
      from correction_requests c join employees e on e.id = c.diajukan_oleh where c.status = 'menunggu'), '[]'::jsonb),
    'data', coalesce((select jsonb_agg(jsonb_build_object('nama', e.nama_lengkap, 'alasan', r.alasan, 'waktu', r.diajukan_pada))
      from employee_data_requests r join employees e on e.id = r.employee_id where r.status = 'menunggu'), '[]'::jsonb),
    'jurnal_menunggu', (select count(*) from journal_entries where status = 'menunggu'),
    'jurnal_hari', coalesce((select jsonb_agg(distinct employee_id) from journal_entries where tanggal = v_hari and created_at <= v_kini), '[]'::jsonb),
    'curiga', coalesce((select jsonb_agg(jsonb_build_object('nama', e.nama_lengkap, 'jenis', f.jenis, 'waktu', f.created_at))
      from suspicion_flags f join employees e on e.id = f.employee_id where f.status = 'baru'), '[]'::jsonb),
    'slip', (select count(*) from payroll_slip_requests where status = 'menunggu'),
    'ultah', coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'nama', e.nama_lengkap, 'tanggal', e.tanggal_lahir,
        'hari_ini', to_char(e.tanggal_lahir, 'MMDD') = to_char(v_hari, 'MMDD')) order by to_char(e.tanggal_lahir, 'MMDD'))
      from employees e where e.status_keaktifan = 'aktif' and e.status_akun = 'aktif' and extract(month from e.tanggal_lahir) = extract(month from v_hari)), '[]'::jsonb),
    'belum_verifikasi', coalesce((select jsonb_agg(jsonb_build_object('nama', e.nama_lengkap, 'niy', e.niy)) from employees e
      where e.status_keaktifan = 'aktif' and e.diverifikasi_pada is null and e.peran <> 'superadmin'), '[]'::jsonb));

  -- ---------- Pondok secara umum ----------
  v_umum := jsonb_build_object(
    'pengumuman', coalesce((select jsonb_agg(jsonb_build_object('judul', a.judul, 'penting', a.penting, 'sasaran', a.ringkasan_sasaran, 'sampai', a.tampil_sampai) order by a.created_at desc)
      from announcements a where a.created_at <= v_kini and (a.tampil_sampai is null or a.tampil_sampai >= v_hari) and a.created_at >= v_kini - interval '30 days'), '[]'::jsonb),
    'libur', public.libur_tugas(v_hari, 'sekolah'));

  return v_dasar || jsonb_build_object('pegawai_sesi', v_sesi_peg, 'grup', v_grup, 'kelas_harian', v_kelas, 'mapel', v_mapel, 'dokumen', v_dok,
    'surat', v_surat, 'keuangan', v_keu, 'adminpeg', v_adm, 'umum', v_umum);
end $$;

do $$ declare f text; begin
  execute 'revoke execute on function public.pantauan_langsung(date) from public, anon';
  execute 'grant execute on function public.pantauan_langsung(date) to authenticated';
  foreach f in array array['pengaturan_jurnal_mengajar()','simpan_pengaturan_jurnal_mengajar(jsonb)','jadwal_mengajar_pekan(date,uuid)','peserta_pelajaran(uuid,date)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  execute 'revoke execute on function public._jurnal_mengajar_terbuka(date) from public, anon';
  execute 'grant execute on function public._jurnal_mengajar_terbuka(date) to authenticated';
end $$;

-- PEMERIKSAAN — hasil yang benar: 3 baris, semuanya "Sesuai"
select '1. Kolom jurnal mengajar rinci' as pemeriksaan,
       case when (select count(*) from information_schema.columns where table_schema = 'public' and table_name = 'teaching_journals'
                   and column_name in ('bab','subbab','metode','media','absen','jumlah_anggota','jumlah_hadir')) = 7 then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Pengaturan jurnal mengajar', case when exists (select 1 from institution_settings where kunci = 'jurnal_mengajar') then 'Sesuai' else 'Periksa' end
union all
select '3. Layar Pantauan memuat data unit kerja', case when exists (select 1 from pg_proc where proname = 'pantauan_langsung' and prosrc like '%adminpeg%')
             and exists (select 1 from pg_proc where proname = '_pantauan_dasar') then 'Sesuai' else 'Periksa: jalankan 9000 dulu' end;
