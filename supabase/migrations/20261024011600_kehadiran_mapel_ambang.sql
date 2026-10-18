-- SIMKA PRO | supabase/migrations/20261024011600_kehadiran_mapel_ambang.sql | v1.0 | 14.3.0: ambang warna kehadiran, rekap kehadiran per mapel, komponen nilai Kehadiran | 17/10/2026
-- =====================================================================
-- A. AMBANG KEHADIRAN (warna otomatis)
--    institution_settings 'ambang_kehadiran': { aktif, batas_pegawai (80), batas_santri (80), cetak (true), unduh (true) }.
--    Baris dengan persentase kehadiran DI BAWAH batas diwarnai merah di layar; bila 'cetak'/'unduh' aktif, warnanya ikut
--    pada cetakan F4 dan berkas Excel. ambang_kehadiran() dibaca semua akun; simpan_ambang_kehadiran(p) oleh superadmin
--    atau pemegang hak Dokumen dan laporan tingkat Kelola.
-- B. REKAP KEHADIRAN SANTRI PER MATA PELAJARAN (dari absensi guru mapel di jurnal mengajar)
--    * Pertemuan = tanggal yang jurnalnya terlaksana dan absensinya diisi (beberapa jam pelajaran di hari yang sama = 1).
--    * Hadir = pertemuan − (Sakit + Izin + Alfa + Bolos). Terlambat tetap hadir. (Keputusan: semua ketidakhadiran mengurangi.)
--    * Persen = Hadir ÷ Pertemuan × 100.
--    * rekap_kehadiran_mapel({group_id | assignment_id, mulai, selesai}): matriks santri × mapel.
--      Hak: wali kelas/pemantau kelas melihat semua mapel kelas itu; guru melihat mapel yang diampunya.
-- C. KOMPONEN NILAI "KEHADIRAN" (rapor)
--    * grade_categories.sumber: 'isian' (diisi guru) | 'kehadiran' (otomatis dari B pada rentang semester).
--    * Bobotnya ikut dihitung dalam nilai akhir seperti komponen lain (UH, UTS, UAS, …); guru tidak mengisinya.
--    * Rentang semester: grade_periods.tanggal_mulai/tanggal_selesai bila diisi; bila kosong, semester 1 = 6 bulan
--      pertama tahun ajaran, semester 2 = sisanya.
-- Jalankan SETELAH migrasi 11500. Aman dijalankan ulang.
-- =====================================================================

create or replace function pg_temp.tambal(p_fn text, p_cari text, p_ganti text, p_tanda text)
returns text language plpgsql as $$
declare r record; v text; n int := 0;
begin
  for r in select p.oid from pg_proc p join pg_namespace s on s.oid = p.pronamespace where s.nspname = 'public' and p.proname = p_fn loop
    v := pg_get_functiondef(r.oid);
    if position(p_tanda in v) > 0 then n := n + 1; continue; end if;      -- sudah ditambal
    if position(p_cari in v) = 0 then raise notice 'Penambalan %: teks acuan tidak ditemukan, dilewati.', p_fn; continue; end if;
    execute replace(v, p_cari, p_ganti); n := n + 1;
  end loop;
  return p_fn || ': ' || n;
end $$;

-- =====================================================================
-- A. AMBANG KEHADIRAN
-- =====================================================================
create or replace function public.ambang_kehadiran()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('aktif', true, 'batas_pegawai', 80, 'batas_santri', 80, 'cetak', true, 'unduh', true)
      || coalesce((select nilai from institution_settings where kunci = 'ambang_kehadiran'), '{}'::jsonb)
$$;

create or replace function public.simpan_ambang_kehadiran(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v jsonb := '{}'::jsonb; k text;
begin
  if not (public.is_superadmin() or public.boleh_fitur('laporan', 3)) then
    raise exception 'Anda tidak berwenang mengubah ambang kehadiran.' using errcode = '42501';
  end if;
  foreach k in array array['batas_pegawai','batas_santri'] loop
    if p ? k then
      if (p->>k) !~ '^[0-9]{1,3}$' or (p->>k)::int not between 1 and 100 then raise exception 'Batas kehadiran harus 1–100%%.'; end if;
      v := v || jsonb_build_object(k, (p->>k)::int);
    end if;
  end loop;
  foreach k in array array['aktif','cetak','unduh'] loop
    if p ? k then v := v || jsonb_build_object(k, coalesce((p->>k)::boolean, false)); end if;
  end loop;
  insert into institution_settings (kunci, nilai, publik, updated_by) values ('ambang_kehadiran', v, true, public.saya())
  on conflict (kunci) do update set nilai = institution_settings.nilai || excluded.nilai, updated_at = now(), updated_by = excluded.updated_by;
  perform public.catat_audit('ubah_ambang_kehadiran', 'institution_settings', 'ambang_kehadiran', v::text, null);
  return public.ambang_kehadiran();
end $$;

-- =====================================================================
-- B. REKAP KEHADIRAN PER MAPEL
-- =====================================================================
/** Kehadiran setiap santri pada satu penugasan mengajar (kelas × mapel) dalam rentang tanggal. */
create or replace function public._kehadiran_mapel(p_assignment uuid, p_mulai date, p_selesai date)
returns table (student_id uuid, pertemuan int, hadir int, terlambat int, sakit int, izin int, alfa int, bolos int, persen numeric)
language sql stable security definer set search_path = public as $$
  with t as (select id, group_id from teaching_assignments where id = p_assignment),
  -- satu pertemuan per tanggal; kode terberat bila beberapa jam pelajaran berbeda isian
  hari as (
    select tj.tanggal, jsonb_object_agg(coalesce(e.key, '-'), e.value #>> '{}') filter (where e.key is not null) absen
      from teaching_journals tj cross join t
      left join lateral jsonb_each(tj.absen) e on true
     where tj.assignment_id = t.id and tj.status = 'terlaksana' and tj.jumlah_anggota is not null
       and tj.tanggal between p_mulai and p_selesai
     group by tj.tanggal),
  per as (
    select a.sid, h.tanggal, coalesce(h.absen->>a.sid::text, 'H') kode
      from hari h cross join t cross join lateral (select x sid from public._anggota_pada(t.group_id, h.tanggal) x) a)
  select sid, count(*)::int,
         count(*) filter (where kode in ('H','T'))::int, count(*) filter (where kode = 'T')::int,
         count(*) filter (where kode = 'S')::int, count(*) filter (where kode = 'I')::int,
         count(*) filter (where kode = 'A')::int, count(*) filter (where kode = 'B')::int,
         round(100.0 * count(*) filter (where kode in ('H','T')) / nullif(count(*), 0), 1)
    from per group by sid
$$;

/** Matriks kehadiran per mapel. p: { group_id | assignment_id, mulai, selesai }. */
create or replace function public.rekap_kehadiran_mapel(p jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_group uuid := nullif(p->>'group_id', '')::uuid; v_tugas uuid := nullif(p->>'assignment_id', '')::uuid;
  v_mulai date := coalesce(nullif(p->>'mulai', '')::date, public.hari_ini() - 30); v_selesai date := coalesce(nullif(p->>'selesai', '')::date, public.hari_ini());
  v_semua boolean; v_ids uuid[];
begin
  if public.saya() is null then raise exception 'Akun Anda belum aktif.' using errcode = '42501'; end if;
  if v_selesai < v_mulai then raise exception 'Tanggal akhir harus setelah tanggal awal.'; end if;
  if v_selesai - v_mulai > 400 then raise exception 'Rentang rekap paling panjang satu tahun ajaran.'; end if;
  if v_group is null then select group_id into v_group from teaching_assignments where id = v_tugas; end if;
  if v_group is null then raise exception 'Pilih kelas atau mapel.'; end if;
  v_semua := public.boleh_lihat_kelas(v_group) or public.boleh_kelola_nilai() or public.is_admin();
  select array_agg(t.id) into v_ids from teaching_assignments t
   where t.group_id = v_group and (v_tugas is null or t.id = v_tugas) and (v_semua or t.employee_id = public.saya());
  if v_ids is null then raise exception 'Anda tidak berwenang melihat kehadiran pelajaran kelas ini.' using errcode = '42501'; end if;
  return jsonb_build_object(
    'mulai', v_mulai, 'selesai', v_selesai,
    'kelas', (select jsonb_build_object('id', g.id, 'nama', g.nama, 'jenjang', g.jenjang, 'tingkat', g.tingkat) from student_groups g where g.id = v_group),
    'mapel', coalesce((select jsonb_agg(jsonb_build_object('assignment_id', t.id, 'mapel', s.nama, 'kode', s.kode, 'guru', e.nama_lengkap,
                  'pertemuan', (select count(distinct tj.tanggal) from teaching_journals tj where tj.assignment_id = t.id and tj.status = 'terlaksana'
                                  and tj.jumlah_anggota is not null and tj.tanggal between v_mulai and v_selesai))
                order by s.urutan nulls last, s.nama)
              from teaching_assignments t join subjects s on s.id = t.subject_id left join employees e on e.id = t.employee_id
             where t.id = any(v_ids)), '[]'::jsonb),
    'santri', coalesce((select jsonb_agg(jsonb_build_object('student_id', st.id, 'nis', st.nis, 'nama', st.nama_lengkap, 'jk', st.jenis_kelamin,
                  'mapel', (select coalesce(jsonb_object_agg(k.assignment_id, jsonb_build_object('p', k.pertemuan, 'h', k.hadir, 't', k.terlambat, 's', k.sakit,
                                    'i', k.izin, 'a', k.alfa, 'b', k.bolos, 'persen', k.persen)), '{}'::jsonb)
                            from (select x.assignment_id, km.* from unnest(v_ids) x(assignment_id)
                                   cross join lateral public._kehadiran_mapel(x.assignment_id, v_mulai, v_selesai) km where km.student_id = st.id) k))
                order by st.nama_lengkap)
              from students st
             where st.id in (select m.student_id from group_members m where m.group_id = v_group
                              and m.mulai <= v_selesai and (m.selesai is null or m.selesai >= v_mulai))), '[]'::jsonb));
end $$;

-- =====================================================================
-- C. KOMPONEN NILAI KEHADIRAN
-- =====================================================================
alter table public.grade_categories add column if not exists sumber text not null default 'isian';
alter table public.grade_categories drop constraint if exists gc_sumber;
alter table public.grade_categories add constraint gc_sumber check (sumber in ('isian','kehadiran'));
alter table public.grade_periods add column if not exists tanggal_mulai date;
alter table public.grade_periods add column if not exists tanggal_selesai date;

/** Rentang tanggal satu semester (untuk komponen Kehadiran). */
create or replace function public._rentang_semester(p_ta uuid, p_jenis text, p_semester smallint)
returns table (mulai date, selesai date) language sql stable security definer set search_path = public as $$
  select coalesce(gp.tanggal_mulai, case when p_semester = 1 then a.mulai else (a.mulai + interval '6 months')::date end),
         coalesce(gp.tanggal_selesai, case when p_semester = 1 then (a.mulai + interval '6 months')::date - 1
                                            else coalesce(a.selesai, (a.mulai + interval '12 months')::date - 1) end)
    from academic_years a
    left join grade_periods gp on gp.academic_year_id = a.id and gp.jenis = p_jenis and gp.semester = p_semester
   where a.id = p_ta
$$;

/** Kehadiran per santri untuk lembar nilai satu penugasan × semester. */
create or replace function public._kehadiran_nilai(p_assignment uuid, p_semester smallint)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('mulai', r.mulai, 'selesai', r.selesai,
           'santri', coalesce((select jsonb_object_agg(k.student_id, jsonb_build_object('p', k.pertemuan, 'h', k.hadir, 's', k.sakit, 'i', k.izin,
                                 'a', k.alfa, 'b', k.bolos, 't', k.terlambat, 'persen', k.persen))
                               from public._kehadiran_mapel(p_assignment, r.mulai, least(r.selesai, public.hari_ini())) k), '{}'::jsonb))
    from public._tugas_info(p_assignment) i cross join lateral public._rentang_semester(i.academic_year_id, i.jenis, p_semester) r
$$;

/** Akumulasi nilai: komponen isian (rata-rata isian guru) + komponen Kehadiran (persentase kehadiran pelajaran). */
create or replace function public.nilai_akumulasi(p_assignment uuid, p_semester smallint)
returns table (student_id uuid, aspek text, nilai numeric, lengkap boolean)
language sql stable security definer set search_path = public as $$
  with i as (select * from public._tugas_info(p_assignment)),
  st as (select s.desimal from report_settings s, i where s.academic_year_id = i.academic_year_id and s.jenis = i.jenis),
  kat as (select c.id, c.aspek, c.bobot, c.sumber from grade_categories c, i
           where c.academic_year_id = i.academic_year_id and c.jenis = i.jenis and c.aktif and c.bobot > 0),
  rg as (select r.* from i cross join lateral public._rentang_semester(i.academic_year_id, i.jenis, p_semester) r),
  rata as (select sc.student_id, k.aspek, k.id kat_id, k.bobot, avg(sc.nilai) r
             from kat k join grade_columns gc on gc.category_id = k.id and gc.assignment_id = p_assignment and gc.semester = p_semester
             join grade_scores sc on sc.column_id = gc.id
            where k.sumber = 'isian'
            group by sc.student_id, k.aspek, k.id, k.bobot
           union all
           select km.student_id, k.aspek, k.id, k.bobot, km.persen
             from kat k cross join rg
             cross join lateral public._kehadiran_mapel(p_assignment, rg.mulai, least(rg.selesai, public.hari_ini())) km
            where k.sumber = 'kehadiran' and km.pertemuan > 0)
  select r.student_id, r.aspek,
         round(sum(r.r * r.bobot) / nullif(sum(r.bobot), 0), coalesce((select desimal from st), 0)),
         count(*) = (select count(*) from kat k where k.aspek = r.aspek)
    from rata r group by r.student_id, r.aspek
$$;

-- Lembar nilai: sertakan sumber komponen dan kehadiran pelajaran per santri
select pg_temp.tambal('lembar_nilai', '''bobot'', c.bobot, ''berulang'', c.berulang, ''aktif'', c.aktif)',
  '''bobot'', c.bobot, ''berulang'', c.berulang, ''aktif'', c.aktif, ''sumber'', c.sumber)', '''sumber'', c.sumber');
select pg_temp.tambal('lembar_nilai', '''semester'', p_semester, ''boleh_ubah'', v_ubah,',
  '''semester'', p_semester, ''kehadiran'', public._kehadiran_nilai(p_assignment, p_semester), ''boleh_ubah'', v_ubah,', '_kehadiran_nilai');

-- Guru tidak membuat isian pada komponen Kehadiran
select pg_temp.tambal('simpan_kolom_nilai', '  if coalesce(trim(p->>''nama''), '''') = '''' then raise exception ''Nama isian wajib diisi.''; end if;',
  '  if c.sumber = ''kehadiran'' then raise exception ''Komponen % dihitung otomatis dari absensi pelajaran; tidak perlu diisi.'', c.nama; end if;
  if coalesce(trim(p->>''nama''), '''') = '''' then raise exception ''Nama isian wajib diisi.''; end if;', 'sumber = ''kehadiran''');

-- Pengaturan komponen: simpan sumber (paling banyak satu komponen Kehadiran per aspek)
select pg_temp.tambal('simpan_komponen_nilai', '    v_ids := v_ids || v_id;',
  '    update grade_categories set sumber = case when r->>''sumber'' = ''kehadiran'' then ''kehadiran'' else ''isian'' end,
           berulang = case when r->>''sumber'' = ''kehadiran'' then false else berulang end where id = v_id;
    v_ids := v_ids || v_id;', 'r->>''sumber''');
select pg_temp.tambal('simpan_komponen_nilai', '  for r in select * from jsonb_array_elements(p) loop
    i := i + 1;',
  '  if exists (select 1 from jsonb_array_elements(p) x where x->>''sumber'' = ''kehadiran'' group by coalesce(x->>''aspek'', ''pengetahuan'') having count(*) > 1) then
    raise exception ''Komponen Kehadiran cukup satu untuk setiap aspek.'';
  end if;
  for r in select * from jsonb_array_elements(p) loop
    i := i + 1;', 'Komponen Kehadiran cukup satu');

-- Salin pengaturan tahun lalu: ikut menyalin sumber komponen
select pg_temp.tambal('siapkan_penilaian',
  'insert into grade_categories (academic_year_id, jenis, kode, nama, aspek, bobot, berulang, aktif, urutan)
    select v_ta, jenis, kode, nama, aspek, bobot, berulang, aktif, urutan from grade_categories',
  'insert into grade_categories (academic_year_id, jenis, kode, nama, aspek, bobot, berulang, aktif, urutan, sumber)
    select v_ta, jenis, kode, nama, aspek, bobot, berulang, aktif, urutan, sumber from grade_categories', 'urutan, sumber');

-- Periode nilai: rentang tanggal semester dapat diatur
select pg_temp.tambal('simpan_periode_nilai', E'exception\n  when check_violation then raise exception ''Hari efektif harus 1–200.'';',
  E'  if p ? ''tanggal_mulai'' or p ? ''tanggal_selesai'' then\n'
  || E'    update grade_periods set tanggal_mulai = case when p ? ''tanggal_mulai'' then nullif(p->>''tanggal_mulai'', '''')::date else tanggal_mulai end,\n'
  || E'           tanggal_selesai = case when p ? ''tanggal_selesai'' then nullif(p->>''tanggal_selesai'', '''')::date else tanggal_selesai end where id = p_id;\n'
  || E'    if exists (select 1 from grade_periods where id = p_id and tanggal_selesai < tanggal_mulai) then raise exception ''Tanggal akhir semester harus setelah tanggal awal.''; end if;\n'
  || E'  end if;\nexception\n  when check_violation then raise exception ''Hari efektif harus 1–200.'';', 'tanggal_mulai');

-- =====================================================================
-- HAK EKSEKUSI
-- =====================================================================
do $$
declare f text;
begin
  foreach f in array array['_kehadiran_mapel(uuid,date,date)', '_rentang_semester(uuid,text,smallint)', '_kehadiran_nilai(uuid,smallint)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
  foreach f in array array['ambang_kehadiran()', 'simpan_ambang_kehadiran(jsonb)', 'rekap_kehadiran_mapel(jsonb)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- =====================================================================
-- PEMERIKSAAN — hasil yang benar: 5 baris, semuanya "Sesuai"
-- =====================================================================
select '1. Ambang kehadiran (bawaan 80%)' as pemeriksaan,
       case when (public.ambang_kehadiran()->>'batas_santri')::int between 1 and 100 then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Rekap kehadiran per mapel tersedia',
       case when to_regprocedure('public.rekap_kehadiran_mapel(jsonb)') is not null then 'Sesuai' else 'Periksa' end
union all
select '3. Komponen nilai mengenal sumber Kehadiran',
       case when exists (select 1 from information_schema.columns where table_name = 'grade_categories' and column_name = 'sumber') then 'Sesuai' else 'Periksa' end
union all
select '4. Nilai akhir menghitung bobot Kehadiran',
       case when position('_kehadiran_mapel' in pg_get_functiondef('public.nilai_akumulasi(uuid,smallint)'::regprocedure)) > 0
             and position('_kehadiran_nilai' in pg_get_functiondef('public.lembar_nilai(uuid,smallint)'::regprocedure)) > 0 then 'Sesuai' else 'Periksa' end
union all
select '5. Pengaturan komponen dan periode menyimpan Kehadiran',
       case when position('sumber' in pg_get_functiondef('public.simpan_komponen_nilai(uuid,text,jsonb)'::regprocedure)) > 0
             and position('tanggal_mulai' in pg_get_functiondef('public.simpan_periode_nilai(uuid,jsonb)'::regprocedure)) > 0 then 'Sesuai' else 'Periksa' end;
