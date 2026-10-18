-- SIMKA PRO | supabase/migrations/20261025011700_jurnal_lengkap_laporan.sql | v1.0 | 14.4.0: jurnal mengajar/ekskul lengkap, laporan jurnal (per mapel, per kelas), rentang semester | 17/10/2026
-- =====================================================================
-- A. JURNAL MENGAJAR LENGKAP
--    * teaching_journals + tujuan (tujuan pembelajaran), kegiatan (langkah/ringkasan kegiatan), alat[] (alat/perlengkapan),
--      sumber[] (sumber belajar/referensi). Kolom lama (bab, subbab, metode, media, keterangan, absen) tetap.
--    * Pengaturan 'jurnal_mengajar' + daftar pilihan alat dan sumber, serta isian WAJIB yang dapat diatur:
--      wajib = { subbab, metode, media, alat, sumber, tujuan, kegiatan } (bawaan: sub-bab dan metode wajib;
--      bab/materi pokok selalu wajib; absensi santri mengikuti "absen_santri").
-- B. JURNAL EKSKUL: rincian + jam_mulai, jam_selesai (jam latihan sebenarnya), alat[], sumber[], catatan.
-- C. LAPORAN JURNAL (dasar cetak/unduh): laporan_jurnal_mengajar({assignment_id | group_id | employee_id, subject_id?, mulai, selesai})
--    → pertemuan (satu baris per tanggal × kelas × mapel; jam pelajaran berurutan digabung) beserta isian lengkap dan
--    santri yang tidak hadir. Hak: guru pengampu, wali kelas kelas itu, pemantau jadwal mengajar/pimpinan jenjang, admin.
-- D. Rentang semester komponen Kehadiran (14.3.0) diselaraskan dengan rentang rapor (semester 1 = awal TA s.d. 31 Desember,
--    semester 2 = 1 Januari s.d. akhir TA) bila tanggal di Periode penilaian kosong.
-- Jalankan SETELAH migrasi 11600. Aman dijalankan ulang.
-- =====================================================================

create or replace function pg_temp.tambal(p_fn text, p_cari text, p_ganti text, p_tanda text)
returns text language plpgsql as $$
declare r record; v text; n int := 0;
begin
  for r in select p.oid from pg_proc p join pg_namespace s on s.oid = p.pronamespace where s.nspname = 'public' and p.proname = p_fn loop
    v := pg_get_functiondef(r.oid);
    if position(p_tanda in v) > 0 then n := n + 1; continue; end if;
    if position(p_cari in v) = 0 then raise notice 'Penambalan %: teks acuan tidak ditemukan, dilewati.', p_fn; continue; end if;
    execute replace(v, p_cari, p_ganti); n := n + 1;
  end loop;
  return p_fn || ': ' || n;
end $$;

-- =====================================================================
-- A. JURNAL MENGAJAR LENGKAP
-- =====================================================================
alter table public.teaching_journals add column if not exists tujuan text;
alter table public.teaching_journals add column if not exists kegiatan text;
alter table public.teaching_journals add column if not exists alat text[] not null default '{}';
alter table public.teaching_journals add column if not exists sumber text[] not null default '{}';

create or replace function public.pengaturan_jurnal_mengajar()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('batas_hari', 1, 'absen_santri', true, 'metode', '[]'::jsonb, 'media', '[]'::jsonb,
           'alat', '["Papan tulis dan spidol", "Laptop", "Proyektor/LCD", "Pengeras suara", "Alat peraga", "Alat praktik/laboratorium", "Mushaf/kitab"]'::jsonb,
           'sumber', '["Buku paket", "Buku pendamping/LKS", "Kitab", "Modul guru", "Al-Qur''an dan tafsir", "Internet/artikel", "Video pembelajaran"]'::jsonb,
           'wajib', '{"subbab": true, "metode": true, "media": false, "alat": false, "sumber": false, "tujuan": false, "kegiatan": false}'::jsonb)
         || coalesce((select nilai from institution_settings where kunci = 'jurnal_mengajar'), '{}'::jsonb)
$$;

create or replace function public.simpan_pengaturan_jurnal_mengajar(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v jsonb := public.pengaturan_jurnal_mengajar(); v_batas int := coalesce((p->>'batas_hari')::int, (v->>'batas_hari')::int); k text; w jsonb := '{}'::jsonb;
begin
  if not (public.is_superadmin() or public.admin_boleh('atur_jadwal')) then
    raise exception 'Hanya superadmin dan admin ber-izin Jadwal pelajaran yang dapat mengubah pengaturan jurnal mengajar.' using errcode = '42501';
  end if;
  if v_batas < 0 or v_batas > 14 then raise exception 'Batas pengisian jurnal 0–14 hari.'; end if;
  v := v || jsonb_build_object('batas_hari', v_batas, 'absen_santri', coalesce((p->>'absen_santri')::boolean, (v->>'absen_santri')::boolean));
  foreach k in array array['metode','media','alat','sumber'] loop
    if jsonb_typeof(p->k) = 'array' then v := v || jsonb_build_object(k, p->k); end if;
  end loop;
  if jsonb_typeof(p->'wajib') = 'object' then
    foreach k in array array['subbab','metode','media','alat','sumber','tujuan','kegiatan'] loop
      w := w || jsonb_build_object(k, coalesce((p->'wajib'->>k)::boolean, false));
    end loop;
    v := v || jsonb_build_object('wajib', w);
  end if;
  insert into institution_settings (kunci, nilai, publik, updated_by) values ('jurnal_mengajar', v, false, public.saya())
  on conflict (kunci) do update set nilai = excluded.nilai, updated_by = excluded.updated_by, updated_at = now();
  return v;
end $$;

-- Simpan jurnal mengajar (versi 11700): {tanggal, entri: [{assignment_id, period_id, status, bab, subbab, tujuan, kegiatan,
--   metode[], media[], alat[], sumber[], materi?, plan_id?, keterangan?, absen? {student_id: I|S|A|B|T}}]}
create or replace function public.simpan_jurnal_mengajar(p jsonb)
returns int language plpgsql volatile security definer set search_path = public as $$
declare v_tgl date := (p->>'tanggal')::date; r jsonb; n int := 0; v_saya uuid := public.saya(); t teaching_assignments;
  v_bab text; v_sub text; v_materi text; v_absen jsonb; v_anggota int; v_k text; v_v text; v_set jsonb := public.pengaturan_jurnal_mengajar();
  v_w jsonb := coalesce(public.pengaturan_jurnal_mengajar()->'wajib', '{}'::jsonb);
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
    if coalesce(r->>'status', 'terlaksana') = 'terlaksana' then
      if length(coalesce(v_materi, '')) < 3 then raise exception 'Isi bab/materi yang diajarkan (minimal 3 huruf).'; end if;
      if (v_w->>'subbab')::boolean and length(coalesce(v_sub, '')) < 3 then raise exception 'Isi sub-bab/pembahasan yang diajarkan.'; end if;
      if (v_w->>'tujuan')::boolean and length(trim(coalesce(r->>'tujuan', ''))) < 5 then raise exception 'Isi tujuan pembelajaran pertemuan ini.'; end if;
      if (v_w->>'kegiatan')::boolean and length(trim(coalesce(r->>'kegiatan', ''))) < 10 then raise exception 'Uraikan kegiatan pembelajaran (minimal 10 huruf).'; end if;
      if (v_w->>'metode')::boolean and jsonb_array_length(case when jsonb_typeof(r->'metode') = 'array' then r->'metode' else '[]' end) = 0 then raise exception 'Pilih minimal satu metode/strategi pembelajaran.'; end if;
      if (v_w->>'media')::boolean and jsonb_array_length(case when jsonb_typeof(r->'media') = 'array' then r->'media' else '[]' end) = 0 then raise exception 'Pilih minimal satu media pembelajaran.'; end if;
      if (v_w->>'alat')::boolean and jsonb_array_length(case when jsonb_typeof(r->'alat') = 'array' then r->'alat' else '[]' end) = 0 then raise exception 'Pilih minimal satu alat/perlengkapan.'; end if;
      if (v_w->>'sumber')::boolean and jsonb_array_length(case when jsonb_typeof(r->'sumber') = 'array' then r->'sumber' else '[]' end) = 0 then raise exception 'Pilih minimal satu sumber belajar/referensi.'; end if;
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
    insert into teaching_journals (assignment_id, period_id, tanggal, employee_id, status, materi, plan_id, keterangan, bab, subbab, metode, media,
                                   alat, sumber, tujuan, kegiatan, absen, jumlah_anggota, jumlah_hadir)
    values (t.id, (r->>'period_id')::uuid, v_tgl, v_saya, coalesce(nullif(r->>'status', ''), 'terlaksana'), v_materi,
            nullif(r->>'plan_id', '')::uuid, nullif(trim(r->>'keterangan'), ''), v_bab, v_sub,
            coalesce(array(select jsonb_array_elements_text(case when jsonb_typeof(r->'metode') = 'array' then r->'metode' else '[]' end)), '{}'),
            coalesce(array(select jsonb_array_elements_text(case when jsonb_typeof(r->'media') = 'array' then r->'media' else '[]' end)), '{}'),
            coalesce(array(select jsonb_array_elements_text(case when jsonb_typeof(r->'alat') = 'array' then r->'alat' else '[]' end)), '{}'),
            coalesce(array(select jsonb_array_elements_text(case when jsonb_typeof(r->'sumber') = 'array' then r->'sumber' else '[]' end)), '{}'),
            nullif(trim(coalesce(r->>'tujuan', '')), ''), nullif(trim(coalesce(r->>'kegiatan', '')), ''),
            v_absen, v_anggota,
            case when v_anggota is not null then v_anggota - (select count(*) from jsonb_each_text(v_absen) e where e.value in ('I','S','A','B')) end)
    on conflict (assignment_id, tanggal, period_id) do update set employee_id = excluded.employee_id, status = excluded.status,
      materi = excluded.materi, plan_id = excluded.plan_id, keterangan = excluded.keterangan, bab = excluded.bab, subbab = excluded.subbab,
      metode = excluded.metode, media = excluded.media, alat = excluded.alat, sumber = excluded.sumber, tujuan = excluded.tujuan, kegiatan = excluded.kegiatan,
      absen = excluded.absen, jumlah_anggota = excluded.jumlah_anggota, jumlah_hadir = excluded.jumlah_hadir, updated_at = now();
    n := n + 1;
  end loop;
  return n;
end $$;

-- Jadwal mengajar: sertakan isian baru di jurnal tersimpan dan isian awal dari pertemuan sebelumnya
select pg_temp.tambal('jadwal_mengajar', '''bab'', j.bab, ''subbab'', j.subbab, ''metode'', j.metode, ''media'', j.media, ''absen'', j.absen,',
  '''bab'', j.bab, ''subbab'', j.subbab, ''metode'', j.metode, ''media'', j.media, ''alat'', j.alat, ''sumber'', j.sumber, ''tujuan'', j.tujuan, ''kegiatan'', j.kegiatan, ''absen'', j.absen,', 'j.alat');
select pg_temp.tambal('jadwal_mengajar', '''subbab'', j4.subbab, ''metode'', j4.metode, ''media'', j4.media)',
  '''subbab'', j4.subbab, ''metode'', j4.metode, ''media'', j4.media, ''alat'', j4.alat, ''sumber'', j4.sumber)', 'j4.alat');

-- =====================================================================
-- B. JURNAL EKSKUL: jam latihan, alat, sumber, catatan
-- =====================================================================
select pg_temp.tambal('simpan_rincian_jurnal_ekskul',
  '''tindak_lanjut'', nullif(trim(coalesce(p->>''tindak_lanjut'', '''')), ''''));',
  '''tindak_lanjut'', nullif(trim(coalesce(p->>''tindak_lanjut'', '''')), ''''),
                              ''jam_mulai'', nullif(p->>''jam_mulai'', ''''), ''jam_selesai'', nullif(p->>''jam_selesai'', ''''),
                              ''alat'', coalesce(p->''alat'', ''[]''::jsonb), ''sumber'', coalesce(p->''sumber'', ''[]''::jsonb),
                              ''catatan'', nullif(trim(coalesce(p->>''catatan'', '''')), ''''));
  if nullif(p->>''jam_mulai'', '''') is not null or nullif(p->>''jam_selesai'', '''') is not null then
    if coalesce(p->>''jam_mulai'', '''') !~ ''^\d{2}:\d{2}$'' or coalesce(p->>''jam_selesai'', '''') !~ ''^\d{2}:\d{2}$'' then
      raise exception ''Isi jam mulai dan jam selesai latihan (format JJ:MM).'';
    end if;
    if (p->>''jam_selesai'')::time <= (p->>''jam_mulai'')::time then raise exception ''Jam selesai latihan harus setelah jam mulai.''; end if;
    update student_attendance_sessions set jam_mulai = (p->>''jam_mulai'')::time, jam_selesai = (p->>''jam_selesai'')::time where id = p_sesi;
  end if;', 'jam_mulai');

/** Jurnal ekskul per pertemuan + rincian lengkap (materi, kegiatan, metode, media, alat, sumber, capaian, jam latihan). */
drop function if exists public.jurnal_ekskul(uuid, date, date);
create function public.jurnal_ekskul(p_group uuid, p_mulai date, p_selesai date)
returns table (session_id uuid, tanggal date, jam_mulai time, jam_selesai time, topik text, uraian text, foto_id uuid,
               pengampu text, jumlah_anggota int, jumlah_hadir int, jumlah_izin int, jumlah_sakit int, jumlah_absen int, rincian jsonb)
language sql stable security definer set search_path = public as $$
  select sa.id, sa.tanggal, sa.jam_mulai, sa.jam_selesai, j.topik, j.uraian, j.foto_id,
         (select nama_lengkap from employees where id = sa.pengampu_id), sa.jumlah_anggota, sa.jumlah_hadir, sa.jumlah_izin, sa.jumlah_sakit, sa.jumlah_absen, j.rincian
  from student_attendance_sessions sa left join extracurricular_journals j on j.session_id = sa.id
  where sa.group_id = p_group and sa.jenis = 'ekskul' and sa.tanggal between p_mulai and p_selesai
    and (public.is_admin() or public.saya() in (select employee_id from group_keepers where group_id = p_group)
         or public.akses_luas('absensi_ekskul') or public.boleh_pantau_absensi())
  order by sa.tanggal, sa.jam_mulai
$$;
revoke execute on function public.jurnal_ekskul(uuid,date,date) from public, anon;
grant execute on function public.jurnal_ekskul(uuid,date,date) to authenticated;

-- =====================================================================
-- C. LAPORAN JURNAL MENGAJAR
-- =====================================================================
create or replace function public._boleh_lihat_jurnal_mengajar(p_assignment uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from teaching_assignments t join student_groups g on g.id = t.group_id
                  where t.id = p_assignment
                    and (t.employee_id = public.saya() or public.is_admin() or public.pimpinan_dari(t.employee_id)
                         or public.tingkat_fitur('jadwal_mengajar') >= 3 or g.jenjang = any(public.jenjang_terlihat())
                         or g.id in (select public.kelompok_saya()) or public.boleh_lihat_kelas(g.id)))
$$;

/** Laporan jurnal mengajar. p: { assignment_id | group_id | employee_id, subject_id?, mulai, selesai }.
    Satu baris per (penugasan × tanggal): jam pelajaran berurutan di hari itu digabung. */
create or replace function public.laporan_jurnal_mengajar(p jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_mulai date := coalesce(nullif(p->>'mulai', '')::date, date_trunc('month', public.hari_ini())::date);
  v_selesai date := coalesce(nullif(p->>'selesai', '')::date, public.hari_ini()); v_ids uuid[];
begin
  if public.saya() is null then raise exception 'Akun Anda belum aktif.' using errcode = '42501'; end if;
  if v_selesai < v_mulai then raise exception 'Tanggal akhir harus setelah tanggal awal.'; end if;
  if v_selesai - v_mulai > 400 then raise exception 'Rentang laporan paling panjang satu tahun ajaran.'; end if;
  select array_agg(t.id) into v_ids from teaching_assignments t join academic_years a on a.id = t.academic_year_id
   where (nullif(p->>'assignment_id', '') is null or t.id = (p->>'assignment_id')::uuid)
     and (nullif(p->>'group_id', '') is null or t.group_id = (p->>'group_id')::uuid)
     and (nullif(p->>'employee_id', '') is null or t.employee_id = (p->>'employee_id')::uuid)
     and (nullif(p->>'subject_id', '') is null or t.subject_id = (p->>'subject_id')::uuid)
     and (nullif(p->>'assignment_id', '') is not null or a.mulai <= v_selesai and coalesce(a.selesai, v_selesai) >= v_mulai)
     and public._boleh_lihat_jurnal_mengajar(t.id);
  if v_ids is null then
    if nullif(p->>'assignment_id', '') is not null then raise exception 'Anda tidak berwenang melihat jurnal mengajar ini.' using errcode = '42501'; end if;
    return jsonb_build_object('mulai', v_mulai, 'selesai', v_selesai, 'penugasan', '[]'::jsonb, 'pertemuan', '[]'::jsonb);
  end if;
  return jsonb_build_object('mulai', v_mulai, 'selesai', v_selesai,
    'penugasan', (select jsonb_agg(jsonb_build_object('assignment_id', t.id, 'group_id', g.id, 'kelas', g.nama, 'jenjang', g.jenjang, 'tingkat', g.tingkat,
                    'subject_id', s.id, 'mapel', s.nama, 'kode_mapel', s.kode, 'employee_id', e.id, 'guru', e.nama_lengkap, 'niy', e.niy,
                    'wali', (select jsonb_build_object('nama', we.nama_lengkap, 'niy', we.niy) from group_keepers k join employees we on we.id = k.employee_id
                              where k.group_id = g.id and (k.sampai is null or k.sampai >= public.hari_ini()) order by (k.peran = 'utama') desc limit 1))
                  order by g.tingkat, g.nama, s.nama)
                  from teaching_assignments t join student_groups g on g.id = t.group_id join subjects s on s.id = t.subject_id left join employees e on e.id = t.employee_id
                 where t.id = any(v_ids)),
    'pertemuan', coalesce((select jsonb_agg(x order by x->>'tanggal', x->>'jam_mulai', x->>'kelas') from (
        select jsonb_build_object('assignment_id', j.assignment_id, 'tanggal', j.tanggal, 'kelas', g.nama, 'mapel', s.nama, 'kode_mapel', s.kode,
                 'guru', coalesce(ep.nama_lengkap, e.nama_lengkap), 'pengisi_lain', j.employee_id is distinct from t.employee_id,
                 'jp', count(*), 'jam_ke', min(lp.nama) || case when count(*) > 1 then ' – ' || max(lp.nama) else '' end,
                 'jam_mulai', to_char(min(lp.jam_mulai), 'HH24:MI'), 'jam_selesai', to_char(max(lp.jam_selesai), 'HH24:MI'),
                 'status', min(j.status), 'bab', max(j.bab), 'subbab', max(j.subbab), 'materi', max(j.materi), 'tujuan', max(j.tujuan), 'kegiatan', max(j.kegiatan),
                 'metode', (select coalesce(jsonb_agg(distinct m), '[]') from teaching_journals jj cross join unnest(jj.metode) m where jj.assignment_id = j.assignment_id and jj.tanggal = j.tanggal),
                 'media', (select coalesce(jsonb_agg(distinct m), '[]') from teaching_journals jj cross join unnest(jj.media) m where jj.assignment_id = j.assignment_id and jj.tanggal = j.tanggal),
                 'alat', (select coalesce(jsonb_agg(distinct m), '[]') from teaching_journals jj cross join unnest(jj.alat) m where jj.assignment_id = j.assignment_id and jj.tanggal = j.tanggal),
                 'sumber', (select coalesce(jsonb_agg(distinct m), '[]') from teaching_journals jj cross join unnest(jj.sumber) m where jj.assignment_id = j.assignment_id and jj.tanggal = j.tanggal),
                 'keterangan', max(j.keterangan), 'jumlah_anggota', max(j.jumlah_anggota), 'jumlah_hadir', min(j.jumlah_hadir),
                 'tidak_hadir', (select coalesce(jsonb_agg(jsonb_build_object('nama', st.nama_lengkap, 'kode', a.kode) order by st.nama_lengkap), '[]')
                                   from (select distinct on (e2.key) e2.key, e2.value #>> '{}' kode from teaching_journals jj cross join lateral jsonb_each(jj.absen) e2
                                          where jj.assignment_id = j.assignment_id and jj.tanggal = j.tanggal
                                          order by e2.key, array_position(array['A','B','S','I','T'], e2.value #>> '{}')) a
                                   join students st on st.id = a.key::uuid)) x
          from teaching_journals j join teaching_assignments t on t.id = j.assignment_id join student_groups g on g.id = t.group_id
          join subjects s on s.id = t.subject_id join lesson_periods lp on lp.id = j.period_id
          left join employees e on e.id = t.employee_id left join employees ep on ep.id = j.employee_id
         where j.assignment_id = any(v_ids) and j.tanggal between v_mulai and v_selesai
         group by j.assignment_id, j.tanggal, g.nama, s.nama, s.kode, ep.nama_lengkap, e.nama_lengkap, j.employee_id, t.employee_id) q), '[]'::jsonb));
end $$;

-- =====================================================================
-- D. RENTANG SEMESTER KOMPONEN KEHADIRAN = RENTANG RAPOR (bila Periode penilaian tidak diisi)
-- =====================================================================
create or replace function public._rentang_semester(p_ta uuid, p_jenis text, p_semester smallint)
returns table (mulai date, selesai date) language sql stable security definer set search_path = public as $$
  select coalesce(gp.tanggal_mulai, rs.mulai), coalesce(gp.tanggal_selesai, rs.selesai)
    from public.rentang_semester(p_ta, p_semester) rs
    left join grade_periods gp on gp.academic_year_id = p_ta and gp.jenis = p_jenis and gp.semester = p_semester
$$;

-- =====================================================================
-- HAK EKSEKUSI
-- =====================================================================
do $$
begin
  revoke execute on function public._boleh_lihat_jurnal_mengajar(uuid) from public, anon, authenticated;
  revoke execute on function public._rentang_semester(uuid,text,smallint) from public, anon, authenticated;
  revoke execute on function public.laporan_jurnal_mengajar(jsonb) from public, anon;
  grant execute on function public.laporan_jurnal_mengajar(jsonb) to authenticated;
end $$;

-- =====================================================================
-- PEMERIKSAAN — hasil yang benar: 5 baris, semuanya "Sesuai"
-- =====================================================================
select '1. Kolom jurnal mengajar lengkap (tujuan, kegiatan, alat, sumber)' as pemeriksaan,
       case when (select count(*) from information_schema.columns where table_name = 'teaching_journals' and column_name in ('tujuan','kegiatan','alat','sumber')) = 4
            then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Isian wajib jurnal dapat diatur',
       case when public.pengaturan_jurnal_mengajar() ? 'wajib' and position('v_w->>' in pg_get_functiondef('public.simpan_jurnal_mengajar(jsonb)'::regprocedure)) > 0
            then 'Sesuai' else 'Periksa' end
union all
select '3. Jadwal mengajar memuat isian baru',
       case when position('j.alat' in pg_get_functiondef('public.jadwal_mengajar(date,uuid)'::regprocedure)) > 0 then 'Sesuai' else 'Periksa' end
union all
select '4. Jurnal ekskul: jam latihan, alat, sumber',
       case when position('jam_mulai' in pg_get_functiondef('public.simpan_rincian_jurnal_ekskul(uuid,jsonb)'::regprocedure)) > 0 then 'Sesuai' else 'Periksa' end
union all
select '5. Laporan jurnal mengajar tersedia',
       case when to_regprocedure('public.laporan_jurnal_mengajar(jsonb)') is not null then 'Sesuai' else 'Periksa' end;
