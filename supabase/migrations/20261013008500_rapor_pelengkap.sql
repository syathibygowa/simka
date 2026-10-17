-- SIMKA PRO | supabase/migrations/20261013008500_rapor_pelengkap.sql | v1.0 | Fase 12 – Tahap 4 Pengembangan diri, kokurikuler, catatan rapor; UTAS per halaqah | 13/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 12 · Migrasi 85
--   A. UTAS dapat dibagi PER KELAS atau PER HALAQAH (grade_periods.utas_mode). Per halaqah: muhaffizh menguji halaqah
--      lain (muhaffizh tidak dapat ditetapkan sebagai penguji halaqahnya sendiri).
--   B. Pengembangan diri (ekskul): pembina mengisi predikat per santri (+ deskripsi khusus), kehadiran ekskul sebagai acuan
--      * report_extracurricular
--   C. Kokurikuler (rapor SMA): wali kelas mengisi nilai 1–4 per dimensi profil lulusan
--      * report_cocurricular
--   D. Catatan rapor: catatan wali kelas dan catatan muhaffizh per santri (disusun otomatis di aplikasi dari bank kalimat dan
--      data santri, dapat disunting) * report_notes
--   * Bahan penyusun catatan: bahan_rapor_kelas (wali kelas), bahan_rapor_halaqah (muhaffizh)
--   * Hak isi: pengasuh kelompok (pembina/wali kelas/muhaffizh) saat periode rapor jenjang santri Dibuka (muhaffizh: periode
--     Tahfizh); pengelola nilai (admin kelola_nilai, superadmin) kapan saja.
-- Jalankan SETELAH migrasi 8400. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. BANTU: rentang semester dan kehadiran kelompok
-- ---------------------------------------------------------------------
create or replace function public.rentang_semester(p_ta uuid, p_semester smallint)
returns table (mulai date, selesai date)
language sql stable security definer set search_path = public as $$
  select case when p_semester = 1 then a.mulai else greatest(a.mulai, make_date(extract(year from a.selesai)::int, 1, 1)) end,
         case when p_semester = 1 then least(a.selesai, make_date(extract(year from a.mulai)::int, 12, 31)) else a.selesai end
    from academic_years a where a.id = p_ta
$$;

-- Kehadiran per santri pada sesi absensi sebuah kelompok dalam rentang (hanya sesi saat santri menjadi anggota).
-- Hadir = H, T, B (Terlambat dan Bolos dihitung hadir); I/S/A tidak hadir.
create or replace function public.kehadiran_kelompok(p_group uuid, p_mulai date, p_selesai date)
returns table (student_id uuid, sesi int, hadir int, izin int, sakit int, absen int)
language sql stable security definer set search_path = public as $$
  select a.sid, count(*)::int,
         count(*) filter (where coalesce(x.kode, 'H') not in ('I','S','A'))::int,
         count(*) filter (where x.kode = 'I')::int, count(*) filter (where x.kode = 'S')::int, count(*) filter (where x.kode = 'A')::int
    from student_attendance_sessions sa
    cross join lateral (select y as sid from public._anggota_pada(sa.group_id, sa.tanggal) y) a
    left join student_attendance_exceptions x on x.session_id = sa.id and x.student_id = a.sid
   where sa.group_id = p_group and sa.tanggal between p_mulai and p_selesai
   group by a.sid
$$;

-- ---------------------------------------------------------------------
-- A. UTAS PER KELAS ATAU PER HALAQAH
-- ---------------------------------------------------------------------
alter table public.grade_periods add column if not exists utas_mode text not null default 'kelas';
do $$ begin
  alter table public.grade_periods add constraint gp_utas_mode check (utas_mode in ('kelas','halaqah'));
exception when duplicate_object then null; end $$;

create or replace function public._mode_utas(p_ta uuid, p_semester smallint)
returns text language sql stable security definer set search_path = public as $$
  select coalesce((select utas_mode from grade_periods where academic_year_id = p_ta and jenis = 'tahfizh' and semester = p_semester), 'kelas')
$$;

create or replace function public.atur_mode_utas(p_semester smallint, p_mode text, p_ta uuid default null)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v_ta uuid := coalesce(p_ta, (select id from academic_years where aktif));
begin
  perform public._cek_panitia_utas(v_ta);
  if p_mode not in ('kelas','halaqah') then raise exception 'Pembagian UTAS harus per kelas atau per halaqah.'; end if;
  perform public.siapkan_penilaian(v_ta);
  update grade_periods set utas_mode = p_mode where academic_year_id = v_ta and jenis = 'tahfizh' and semester = p_semester;
end $$;

-- data_utas (versi 8500): daftar kelompok mengikuti mode (kelas/halaqah), peserta memuat kelompok pembagian, kelas, halaqah
create or replace function public.data_utas(p_semester smallint default null, p_ta uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_ta uuid := coalesce(p_ta, (select id from academic_years where aktif)); v_smt smallint; v_semua boolean; v_mode text;
begin
  if public.saya() is null then raise exception 'Akun Anda belum aktif.'; end if;
  v_smt := coalesce(p_semester, (select semester from academic_years where id = v_ta), 1);
  v_semua := public.panitia_utas() or public.pimpinan_tahfizh() or public.is_admin();
  v_mode := public._mode_utas(v_ta, v_smt);
  return jsonb_build_object(
    'ta', v_ta, 'semester', v_smt, 'mode', v_mode, 'hak', public.hak_utas(),
    'periode', (select to_jsonb(p) from grade_periods p where p.academic_year_id = v_ta and p.jenis = 'tahfizh' and p.semester = v_smt),
    'ketentuan', (select jsonb_build_object('juz_sma', r.utas_juz_sma, 'juz_wustha', r.utas_juz_wustha, 'kkm', r.ambang_bawaan, 'bahasa', r.bahasa_predikat,
                    'bobot_tajwid', coalesce(t.bobot_tajwid, 50), 'bobot_itqan', coalesce(t.bobot_itqan, 50))
                  from report_settings r left join tahfizh_settings t on t.academic_year_id = r.academic_year_id
                 where r.academic_year_id = v_ta and r.jenis = 'tahfizh'),
    'predikat', coalesce((select jsonb_agg(jsonb_build_object('huruf', p.huruf, 'nilai_min', p.nilai_min, 'nilai_maks', p.nilai_maks, 'sebutan', p.sebutan,
                    'sebutan_arab', p.sebutan_arab, 'tuntas', p.tuntas) order by p.urutan) from report_predicates p where p.academic_year_id = v_ta and p.kelompok = 'utas'), '[]'::jsonb),
    'kelas', coalesce((select jsonb_agg(jsonb_build_object('group_id', g.id, 'nama', g.nama, 'jenis', g.jenis, 'jenjang', g.jenjang, 'tingkat', g.tingkat, 'jenis_kelamin', g.jenis_kelamin,
                    'santri', (select count(*) from group_members m join students s on s.id = m.student_id where m.group_id = g.id and m.selesai is null and s.status = 'aktif'),
                    'muhaffizh', case when g.jenis = 'halaqah' then (select string_agg(e.nama_lengkap, ', ') from group_keepers k join employees e on e.id = k.employee_id
                                   where k.group_id = g.id and (k.sampai is null or k.sampai >= public.hari_ini())) end,
                    'penguji', coalesce((select jsonb_agg(jsonb_build_object('employee_id', e.id, 'nama', e.nama_lengkap, 'niy', e.niy, 'no_hp', e.no_hp) order by e.nama_lengkap)
                                from utas_examiners x join employees e on e.id = x.employee_id
                               where x.academic_year_id = v_ta and x.semester = v_smt and x.group_id = g.id), '[]'::jsonb))
                  order by g.tingkat nulls last, g.nama)
                  from student_groups g where g.academic_year_id = v_ta and g.jenis = v_mode and g.aktif
                   and (v_semua or exists (select 1 from utas_examiners x where x.group_id = g.id and x.employee_id = public.saya() and x.academic_year_id = v_ta and x.semester = v_smt)
                        or g.id in (select public.kelompok_saya()))), '[]'::jsonb),
    'peserta', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'student_id', s.id, 'nis', s.nis, 'nama', s.nama_lengkap, 'jenis_kelamin', s.jenis_kelamin, 'jenjang', s.jenjang,
                    'group_id', r.group_id, 'kelompok', g.nama, 'jenis_kelompok', g.jenis,
                    'kelas', (select kg.nama from group_members km join student_groups kg on kg.id = km.group_id
                       where km.student_id = s.id and km.selesai is null and kg.jenis = 'kelas' and kg.academic_year_id = v_ta limit 1),
                    'halaqah', (select hg.nama from group_members hm join student_groups hg on hg.id = hm.group_id
                       where hm.student_id = s.id and hm.selesai is null and hg.jenis = 'halaqah' and hg.academic_year_id = v_ta limit 1),
                    'penguji_id', r.penguji_id, 'penguji', e.nama_lengkap, 'juz', r.juz, 'juz_usul', public.juz_utas(s.id, v_ta),
                    'total_juz', coalesce(r.total_juz, (select count(*) from juz_achievements j where j.student_id = s.id)),
                    'tajwid', r.tajwid, 'itqan', r.itqan, 'nilai_akhir', r.nilai_akhir, 'huruf', r.huruf, 'tuntas', r.tuntas,
                    'status', r.status, 'catatan', r.catatan, 'diuji_pada', r.diuji_pada, 'saya', r.penguji_id = public.saya())
                  order by g.tingkat nulls last, g.nama, s.nama_lengkap)
                  from utas_results r join students s on s.id = r.student_id left join student_groups g on g.id = r.group_id
                  left join employees e on e.id = r.penguji_id
                 where r.academic_year_id = v_ta and r.semester = v_smt
                   and (v_semua or r.penguji_id = public.saya() or r.student_id in (select public.santri_terlihat()))), '[]'::jsonb),
    'belum_dibagi', case when v_semua then coalesce((select jsonb_object_agg(g.id, n.n) from student_groups g
                    cross join lateral (select count(*) n from group_members m join students s on s.id = m.student_id
                                         where m.group_id = g.id and m.selesai is null and s.status = 'aktif'
                                           and not exists (select 1 from utas_results r where r.academic_year_id = v_ta and r.semester = v_smt and r.student_id = s.id)) n
                    where g.academic_year_id = v_ta and g.jenis = v_mode and g.aktif and n.n > 0), '{}'::jsonb) else '{}'::jsonb end);
end $$;

-- simpan_penguji_utas (versi 8500): kelompok kelas atau halaqah sesuai mode; muhaffizh tidak menguji halaqahnya sendiri
create or replace function public.simpan_penguji_utas(p_semester smallint, p_group uuid, p_employees uuid[], p_ta uuid default null)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v_ta uuid := coalesce(p_ta, (select id from academic_years where aktif)); e uuid; g student_groups; v_nama text;
begin
  perform public._cek_panitia_utas(v_ta);
  select * into g from student_groups where id = p_group and academic_year_id = v_ta;
  if g.id is null or g.jenis not in ('kelas','halaqah') then raise exception 'Kelas/halaqah tidak ditemukan.'; end if;
  if exists (select 1 from unnest(p_employees) x where not exists (select 1 from employees where id = x and status_keaktifan = 'aktif')) then
    raise exception 'Penguji harus pegawai aktif.';
  end if;
  if g.jenis = 'halaqah' then
    select e2.nama_lengkap into v_nama from group_keepers k join employees e2 on e2.id = k.employee_id
     where k.group_id = g.id and k.employee_id = any(p_employees) and (k.sampai is null or k.sampai >= public.hari_ini()) limit 1;
    if v_nama is not null then raise exception '% adalah muhaffizh % sehingga tidak dapat menguji halaqahnya sendiri.', v_nama, g.nama; end if;
  end if;
  delete from utas_examiners where academic_year_id = v_ta and semester = p_semester and group_id = p_group and employee_id <> all(p_employees);
  update utas_results set penguji_id = null where academic_year_id = v_ta and semester = p_semester and group_id = p_group
     and penguji_id is not null and penguji_id <> all(p_employees) and status = 'draf';
  foreach e in array p_employees loop
    insert into utas_examiners (academic_year_id, semester, group_id, employee_id) values (v_ta, p_semester, p_group, e) on conflict do nothing;
    if found and e is distinct from public.saya() then
      perform public.kirim_notifikasi(e, 'Anda ditunjuk sebagai penguji UTAS semester ' || p_semester,
        case g.jenis when 'halaqah' then '' else 'Kelas ' end || g.nama || '. Daftar peserta tampil di Tahfizh → Ujian → UTAS.', '/tahfizh/ujian', 'Exam', 'kuning');
    end if;
  end loop;
end $$;

-- bagi_peserta_utas (versi 8500): kelompok kelas atau halaqah
create or replace function public.bagi_peserta_utas(p_semester smallint, p_group uuid, p_ulang boolean default false, p_ta uuid default null)
returns int language plpgsql volatile security definer set search_path = public as $$
declare v_ta uuid := coalesce(p_ta, (select id from academic_years where aktif)); v_penguji uuid[]; s record; v_n int := 0; v_pilih uuid;
begin
  perform public._cek_panitia_utas(v_ta);
  if not exists (select 1 from student_groups where id = p_group and academic_year_id = v_ta and jenis in ('kelas','halaqah')) then raise exception 'Kelas/halaqah tidak ditemukan.'; end if;
  select coalesce(array_agg(employee_id order by employee_id), '{}') into v_penguji from utas_examiners
   where academic_year_id = v_ta and semester = p_semester and group_id = p_group;
  if p_ulang then
    update utas_results set penguji_id = null where academic_year_id = v_ta and semester = p_semester and group_id = p_group
       and status = 'draf' and tajwid is null and itqan is null;
  end if;
  for s in select st.id from group_members m join students st on st.id = m.student_id
            where m.group_id = p_group and m.selesai is null and st.status = 'aktif' order by st.nama_lengkap loop
    insert into utas_results (academic_year_id, semester, student_id, group_id, juz, total_juz)
    values (v_ta, p_semester, s.id, p_group, public.juz_utas(s.id, v_ta), (select count(*) from juz_achievements where student_id = s.id))
    on conflict (academic_year_id, semester, student_id) do update set
      group_id = case when utas_results.tajwid is null and utas_results.itqan is null then excluded.group_id else utas_results.group_id end,
      penguji_id = case when utas_results.group_id is distinct from excluded.group_id and utas_results.tajwid is null and utas_results.itqan is null
                        then null else utas_results.penguji_id end,
      juz = case when utas_results.juz = '{}' then excluded.juz else utas_results.juz end;
    if cardinality(v_penguji) > 0 then
      select x into v_pilih from unnest(v_penguji) x
       order by (select count(*) from utas_results r where r.academic_year_id = v_ta and r.semester = p_semester and r.group_id = p_group and r.penguji_id = x), x
       limit 1;
      update utas_results set penguji_id = v_pilih
       where academic_year_id = v_ta and semester = p_semester and student_id = s.id and group_id = p_group and penguji_id is null;
      if found then v_n := v_n + 1; end if;
    end if;
  end loop;
  return v_n;
end $$;

-- ---------------------------------------------------------------------
-- B–D. TABEL
-- ---------------------------------------------------------------------
create table if not exists public.report_extracurricular (
  academic_year_id  uuid not null references public.academic_years(id) on delete cascade,
  semester          smallint not null constraint rx_semester check (semester in (1,2)),
  group_id          uuid not null references public.student_groups(id) on delete cascade,
  student_id        uuid not null references public.students(id) on delete cascade,
  nilai             text constraint rx_nilai check (nilai is null or length(nilai) between 1 and 3),
  deskripsi         text,
  diisi_oleh        uuid references public.employees(id) on delete set null,
  updated_at        timestamptz not null default now(),
  primary key (academic_year_id, semester, group_id, student_id)
);
create table if not exists public.report_cocurricular (
  academic_year_id  uuid not null references public.academic_years(id) on delete cascade,
  semester          smallint not null constraint rc_semester check (semester in (1,2)),
  student_id        uuid not null references public.students(id) on delete cascade,
  dimensi           jsonb not null default '{}'::jsonb,   -- {"Kemandirian": 4, "Kreativitas": 2, …} (1–4)
  deskripsi         text,                                 -- kosong = disusun otomatis (tertinggi dan terendah)
  diisi_oleh        uuid references public.employees(id) on delete set null,
  updated_at        timestamptz not null default now(),
  primary key (academic_year_id, semester, student_id)
);
create table if not exists public.report_notes (
  academic_year_id  uuid not null references public.academic_years(id) on delete cascade,
  semester          smallint not null constraint rn_semester check (semester in (1,2)),
  student_id        uuid not null references public.students(id) on delete cascade,
  jenis             text not null constraint rn_jenis check (jenis in ('wali','muhaffizh')),
  teks              text not null constraint rn_teks check (length(trim(teks)) between 3 and 1000),
  diisi_oleh        uuid references public.employees(id) on delete set null,
  updated_at        timestamptz not null default now(),
  primary key (academic_year_id, semester, student_id, jenis)
);
do $$
declare t text;
begin
  foreach t in array array['report_extracurricular','report_cocurricular','report_notes'] loop
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
-- HAK ISI RAPOR OLEH PENGASUH
-- ---------------------------------------------------------------------
-- Pengasuh kelompok (wali kelas/pembina/muhaffizh) saat periode jenis rapor itu Dibuka; pengelola nilai kapan saja.
-- p_jenis: 'tahfizh' untuk muhaffizh, selain itu jenjang santri (sma/wustha).
create or replace function public._cek_isi_rapor(p_group uuid, p_semester smallint, p_jenis text)
returns void language plpgsql stable security definer set search_path = public as $$
declare g student_groups; v_status text;
begin
  select * into g from student_groups where id = p_group;
  if g.id is null then raise exception 'Kelompok santri tidak ditemukan.'; end if;
  if p_semester not in (1,2) then raise exception 'Semester harus 1 atau 2.'; end if;
  perform public._ta_boleh_ubah(g.academic_year_id);
  if public.boleh_kelola_nilai() then return; end if;
  if p_group not in (select public.kelompok_saya()) then
    raise exception 'Hanya pengasuh kelompok ini (atau pengelola nilai) yang dapat mengisinya.' using errcode = '42501';
  end if;
  select status into v_status from grade_periods where academic_year_id = g.academic_year_id and jenis = p_jenis and semester = p_semester;
  if coalesce(v_status, 'disiapkan') = 'disiapkan' then
    raise exception 'Periode penilaian % semester % belum dibuka.', case p_jenis when 'sma' then 'SMA' when 'wustha' then 'Wustha' else 'Tahfizh' end, p_semester;
  elsif v_status = 'ditutup' then
    raise exception 'Periode penilaian % semester % sudah ditutup; perubahan melalui pengelola nilai.', case p_jenis when 'sma' then 'SMA' when 'wustha' then 'Wustha' else 'Tahfizh' end, p_semester;
  end if;
end $$;

create or replace function public._boleh_isi_rapor(p_group uuid, p_semester smallint, p_jenis text)
returns boolean language plpgsql stable security definer set search_path = public as $$
begin
  perform public._cek_isi_rapor(p_group, p_semester, p_jenis); return true;
exception when others then return false;
end $$;

create or replace function public._boleh_lihat_kelompok_rapor(p_group uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_admin() or public.boleh_kelola_nilai() or p_group in (select public.kelompok_saya())
      or exists (select 1 from student_groups g where g.id = p_group and (
           (g.jenis = 'kelas' and (public.boleh_atur_penilaian(g.jenjang) or public.pimpinan_unit(upper(g.jenjang))))
        or (g.jenis = 'halaqah' and (public.boleh_atur_penilaian('tahfizh') or public.pimpinan_tahfizh()))
        or (g.jenis = 'ekskul' and (public.boleh_atur_penilaian(null) or public.tingkat_fitur('absensi_ekskul') >= 1))))
$$;

-- ---------------------------------------------------------------------
-- B. PENGEMBANGAN DIRI (EKSKUL)
-- ---------------------------------------------------------------------
create or replace function public.ekskul_nilai_saya(p_semester smallint default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_ta uuid := (select id from academic_years where aktif); v_smt smallint;
begin
  v_smt := coalesce(p_semester, (select semester from academic_years where id = v_ta), 1);
  return jsonb_build_object('semester', v_smt, 'daftar', coalesce((select jsonb_agg(jsonb_build_object('group_id', g.id, 'nama', g.nama, 'keterangan', g.keterangan,
      'asuhan_saya', g.id in (select public.kelompok_saya()),
      'pembina', (select string_agg(e.nama_lengkap, ', ') from group_keepers k join employees e on e.id = k.employee_id where k.group_id = g.id and (k.sampai is null or k.sampai >= public.hari_ini())),
      'santri', (select count(*) from group_members m join students s on s.id = m.student_id where m.group_id = g.id and m.selesai is null and s.status = 'aktif'),
      'terisi', (select count(*) from report_extracurricular r where r.group_id = g.id and r.academic_year_id = v_ta and r.semester = v_smt and r.nilai is not null))
      order by (g.id in (select public.kelompok_saya())) desc, g.nama)
    from student_groups g where g.academic_year_id = v_ta and g.jenis = 'ekskul' and g.aktif and public._boleh_lihat_kelompok_rapor(g.id)), '[]'::jsonb));
end $$;

create or replace function public.nilai_ekskul(p_group uuid, p_semester smallint)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare g student_groups; r record;
begin
  select * into g from student_groups where id = p_group;
  if g.id is null or g.jenis <> 'ekskul' then raise exception 'Ekskul tidak ditemukan.'; end if;
  if not public._boleh_lihat_kelompok_rapor(p_group) then raise exception 'Anda tidak berwenang melihat nilai ekskul ini.' using errcode = '42501'; end if;
  select * into r from public.rentang_semester(g.academic_year_id, p_semester);
  return jsonb_build_object(
    'ekskul', jsonb_build_object('group_id', g.id, 'nama', g.nama, 'keterangan', g.keterangan), 'semester', p_semester,
    'boleh', jsonb_build_object('sma', public._boleh_isi_rapor(p_group, p_semester, 'sma'), 'wustha', public._boleh_isi_rapor(p_group, p_semester, 'wustha')),
    'predikat', coalesce((select jsonb_agg(jsonb_build_object('huruf', p.huruf, 'sebutan', p.sebutan, 'deskripsi', p.deskripsi) order by p.urutan)
                  from report_predicates p where p.academic_year_id = g.academic_year_id and p.kelompok = 'pd'), '[]'::jsonb),
    'santri', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'nis', s.nis, 'nama', s.nama_lengkap, 'jenis_kelamin', s.jenis_kelamin, 'jenjang', s.jenjang,
                  'kelas', (select kg.nama from group_members km join student_groups kg on kg.id = km.group_id where km.student_id = s.id and km.selesai is null and kg.jenis = 'kelas' and kg.academic_year_id = g.academic_year_id limit 1),
                  'sesi', k.sesi, 'hadir', k.hadir, 'nilai', x.nilai, 'deskripsi', x.deskripsi) order by s.nama_lengkap)
                from (select m.student_id from group_members m where m.group_id = p_group group by m.student_id having bool_or(m.selesai is null)
                      union select student_id from report_extracurricular where group_id = p_group and academic_year_id = g.academic_year_id and semester = p_semester) mm
                join students s on s.id = mm.student_id and s.status in ('aktif','nonaktif')
                left join public.kehadiran_kelompok(p_group, r.mulai, r.selesai) k on k.student_id = s.id
                left join report_extracurricular x on x.group_id = p_group and x.student_id = s.id and x.academic_year_id = g.academic_year_id and x.semester = p_semester), '[]'::jsonb));
end $$;

-- p: [{student_id, nilai, deskripsi?}]
create or replace function public.simpan_nilai_ekskul(p_group uuid, p_semester smallint, p jsonb)
returns int language plpgsql volatile security definer set search_path = public as $$
declare g student_groups; x jsonb; v_n int := 0; v_jenjang text; v_huruf text[];
begin
  select * into g from student_groups where id = p_group;
  if g.id is null or g.jenis <> 'ekskul' then raise exception 'Ekskul tidak ditemukan.'; end if;
  select coalesce(array_agg(huruf), '{}') into v_huruf from report_predicates where academic_year_id = g.academic_year_id and kelompok = 'pd';
  for x in select * from jsonb_array_elements(p) loop
    select jenjang into v_jenjang from students where id = (x->>'student_id')::uuid;
    perform public._cek_isi_rapor(p_group, p_semester, v_jenjang);
    if not exists (select 1 from group_members where group_id = p_group and student_id = (x->>'student_id')::uuid) then raise exception 'Santri bukan anggota ekskul ini.'; end if;
    if nullif(x->>'nilai', '') is not null and upper(x->>'nilai') <> all(v_huruf) then raise exception 'Nilai harus salah satu: %.', array_to_string(v_huruf, ', '); end if;
    if nullif(x->>'nilai', '') is null and nullif(trim(x->>'deskripsi'), '') is null then
      delete from report_extracurricular where academic_year_id = g.academic_year_id and semester = p_semester and group_id = p_group and student_id = (x->>'student_id')::uuid;
    else
      insert into report_extracurricular (academic_year_id, semester, group_id, student_id, nilai, deskripsi, diisi_oleh)
      values (g.academic_year_id, p_semester, p_group, (x->>'student_id')::uuid, upper(nullif(x->>'nilai', '')), nullif(trim(x->>'deskripsi'), ''), public.saya())
      on conflict (academic_year_id, semester, group_id, student_id) do update set nilai = excluded.nilai,
        deskripsi = case when x ? 'deskripsi' then excluded.deskripsi else report_extracurricular.deskripsi end, diisi_oleh = excluded.diisi_oleh;
    end if;
    v_n := v_n + 1;
  end loop;
  return v_n;
end $$;

-- ---------------------------------------------------------------------
-- C–D. BAHAN RAPOR KELAS (wali kelas: catatan wali kelas, kokurikuler)
-- ---------------------------------------------------------------------
create or replace function public.bahan_rapor_kelas(p_group uuid, p_semester smallint)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare g student_groups; r record;
begin
  select * into g from student_groups where id = p_group;
  if g.id is null or g.jenis <> 'kelas' then raise exception 'Kelas tidak ditemukan.'; end if;
  if not public._boleh_lihat_kelompok_rapor(p_group) then raise exception 'Anda tidak berwenang melihat rapor kelas ini.' using errcode = '42501'; end if;
  select * into r from public.rentang_semester(g.academic_year_id, p_semester);
  return jsonb_build_object(
    'kelas', jsonb_build_object('group_id', g.id, 'nama', g.nama, 'jenjang', g.jenjang, 'tingkat', g.tingkat), 'semester', p_semester,
    'boleh', public._boleh_isi_rapor(p_group, p_semester, g.jenjang),
    'kokurikuler', (select jsonb_build_object('aktif', s.pakai_kokurikuler, 'dimensi', s.dimensi,
                      'tema', (select tema_kokurikuler from grade_periods p where p.academic_year_id = g.academic_year_id and p.jenis = g.jenjang and p.semester = p_semester))
                    from report_settings s where s.academic_year_id = g.academic_year_id and s.jenis = g.jenjang),
    'santri', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'nis', s.nis, 'nama', s.nama_lengkap, 'panggilan', s.nama_panggilan, 'jenis_kelamin', s.jenis_kelamin,
        'kehadiran', (select jsonb_build_object('sesi', k.sesi, 'hadir', k.hadir, 'sakit', k.sakit, 'izin', k.izin, 'absen', k.absen) from public.kehadiran_kelompok(p_group, r.mulai, r.selesai) k where k.student_id = s.id),
        'mapel', coalesce((select jsonb_agg(jsonb_build_object('mapel', sb.nama, 'nilai', n.nilai, 'kkm', coalesce((select m.kkm from public._mapel_rapor_tugas(t.id) m limit 1), 75)))
                   from teaching_assignments t join subjects sb on sb.id = t.subject_id
                   cross join lateral public.nilai_mapel_ajar(t.id, p_semester) n
                  where t.group_id = p_group and n.student_id = s.id and n.nilai is not null), '[]'::jsonb),
        'sikap', coalesce((select jsonb_agg(f.sikap) from grade_finals f join teaching_assignments t on t.id = f.assignment_id
                  where t.group_id = p_group and f.semester = p_semester and f.student_id = s.id and f.sikap is not null), '[]'::jsonb),
        'tambah_juz', (select count(*) from juz_achievements j where j.student_id = s.id and j.sumber <> 'awal' and j.tanggal between r.mulai and r.selesai),
        'total_juz', (select count(*) from juz_achievements j where j.student_id = s.id),
        'utas', (select jsonb_build_object('nilai', u.nilai_akhir, 'huruf', u.huruf, 'tuntas', u.tuntas) from utas_results u
                  where u.student_id = s.id and u.academic_year_id = g.academic_year_id and u.semester = p_semester and u.nilai_akhir is not null),
        'pd', coalesce((select jsonb_agg(jsonb_build_object('kegiatan', eg.nama, 'nilai', x.nilai)) from report_extracurricular x join student_groups eg on eg.id = x.group_id
                  where x.student_id = s.id and x.academic_year_id = g.academic_year_id and x.semester = p_semester and x.nilai is not null), '[]'::jsonb),
        'kokurikuler', (select jsonb_build_object('dimensi', c.dimensi, 'deskripsi', c.deskripsi) from report_cocurricular c
                  where c.student_id = s.id and c.academic_year_id = g.academic_year_id and c.semester = p_semester),
        'catatan', (select n.teks from report_notes n where n.student_id = s.id and n.academic_year_id = g.academic_year_id and n.semester = p_semester and n.jenis = 'wali'))
        order by s.nama_lengkap)
      from (select m.student_id from group_members m where m.group_id = p_group group by m.student_id having bool_or(m.selesai is null)) mm
      join students s on s.id = mm.student_id and s.status in ('aktif','nonaktif')), '[]'::jsonb));
end $$;

-- Bahan catatan muhaffizh per halaqah
create or replace function public.bahan_rapor_halaqah(p_group uuid, p_semester smallint)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare g student_groups; r record;
begin
  select * into g from student_groups where id = p_group;
  if g.id is null or g.jenis <> 'halaqah' then raise exception 'Halaqah tidak ditemukan.'; end if;
  if not public._boleh_lihat_kelompok_rapor(p_group) then raise exception 'Anda tidak berwenang melihat rapor halaqah ini.' using errcode = '42501'; end if;
  select * into r from public.rentang_semester(g.academic_year_id, p_semester);
  return jsonb_build_object(
    'halaqah', jsonb_build_object('group_id', g.id, 'nama', g.nama, 'jenis_kelamin', g.jenis_kelamin,
                 'muhaffizh', (select string_agg(e.nama_lengkap, ', ') from group_keepers k join employees e on e.id = k.employee_id where k.group_id = g.id and (k.sampai is null or k.sampai >= public.hari_ini()))),
    'semester', p_semester, 'boleh', public._boleh_isi_rapor(p_group, p_semester, 'tahfizh'),
    'santri', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'nis', s.nis, 'nama', s.nama_lengkap, 'panggilan', s.nama_panggilan, 'jenis_kelamin', s.jenis_kelamin, 'jenjang', s.jenjang,
        'kehadiran', (select jsonb_build_object('sesi', k.sesi, 'hadir', k.hadir, 'sakit', k.sakit, 'izin', k.izin, 'absen', k.absen) from public.kehadiran_kelompok(p_group, r.mulai, r.selesai) k where k.student_id = s.id),
        'tambah_hal', (select coalesce(sum(ma.tambah_hal), 0) from monthly_achievements ma where ma.student_id = s.id and ma.bulan between date_trunc('month', r.mulai) and r.selesai),
        'bulan_tercapai', (select count(*) from monthly_achievements ma where ma.student_id = s.id and ma.bulan between date_trunc('month', r.mulai) and r.selesai and ma.status in ('tercapai','khatam')),
        'bulan_total', (select count(*) from monthly_achievements ma where ma.student_id = s.id and ma.bulan between date_trunc('month', r.mulai) and r.selesai and ma.status <> 'tidak_terdata'),
        'tambah_juz', (select count(*) from juz_achievements j where j.student_id = s.id and j.sumber <> 'awal' and j.tanggal between r.mulai and r.selesai),
        'total_juz', (select count(*) from juz_achievements j where j.student_id = s.id),
        'kenaikan_lulus', (select count(*) from tahfizh_exams te where te.student_id = s.id and te.jenis = 'kenaikan' and te.hasil = 'tuntas' and te.diuji_pada::date between r.mulai and r.selesai),
        'utas', (select jsonb_build_object('nilai', u.nilai_akhir, 'huruf', u.huruf, 'tuntas', u.tuntas) from utas_results u
                  where u.student_id = s.id and u.academic_year_id = g.academic_year_id and u.semester = p_semester and u.nilai_akhir is not null),
        'catatan', (select n.teks from report_notes n where n.student_id = s.id and n.academic_year_id = g.academic_year_id and n.semester = p_semester and n.jenis = 'muhaffizh'))
        order by s.nama_lengkap)
      from (select m.student_id from group_members m where m.group_id = p_group group by m.student_id having bool_or(m.selesai is null)) mm
      join students s on s.id = mm.student_id and s.status in ('aktif','nonaktif')), '[]'::jsonb));
end $$;

create or replace function public.halaqah_rapor_saya()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('group_id', g.id, 'nama', g.nama, 'jenis_kelamin', g.jenis_kelamin, 'asuhan_saya', g.id in (select public.kelompok_saya()),
           'muhaffizh', (select string_agg(e.nama_lengkap, ', ') from group_keepers k join employees e on e.id = k.employee_id where k.group_id = g.id and (k.sampai is null or k.sampai >= public.hari_ini())),
           'santri', (select count(*) from group_members m join students s on s.id = m.student_id where m.group_id = g.id and m.selesai is null and s.status = 'aktif'))
           order by (g.id in (select public.kelompok_saya())) desc, g.nama), '[]'::jsonb)
    from student_groups g join academic_years a on a.id = g.academic_year_id and a.aktif
   where g.jenis = 'halaqah' and g.aktif and public._boleh_lihat_kelompok_rapor(g.id)
$$;

-- p: [{student_id, dimensi: {nama: 1..4}, deskripsi?}]
create or replace function public.simpan_kokurikuler(p_group uuid, p_semester smallint, p jsonb)
returns int language plpgsql volatile security definer set search_path = public as $$
declare g student_groups; x jsonb; v_n int := 0;
begin
  select * into g from student_groups where id = p_group;
  if g.id is null or g.jenis <> 'kelas' then raise exception 'Kelas tidak ditemukan.'; end if;
  perform public._cek_isi_rapor(p_group, p_semester, g.jenjang);
  for x in select * from jsonb_array_elements(p) loop
    if not exists (select 1 from group_members where group_id = p_group and student_id = (x->>'student_id')::uuid) then raise exception 'Santri bukan anggota kelas ini.'; end if;
    if exists (select 1 from jsonb_each_text(coalesce(x->'dimensi', '{}'::jsonb)) d where d.value !~ '^[1-4]$') then raise exception 'Nilai dimensi harus 1–4.'; end if;
    insert into report_cocurricular (academic_year_id, semester, student_id, dimensi, deskripsi, diisi_oleh)
    values (g.academic_year_id, p_semester, (x->>'student_id')::uuid, coalesce(x->'dimensi', '{}'::jsonb), nullif(trim(x->>'deskripsi'), ''), public.saya())
    on conflict (academic_year_id, semester, student_id) do update set dimensi = excluded.dimensi,
      deskripsi = case when x ? 'deskripsi' then excluded.deskripsi else report_cocurricular.deskripsi end, diisi_oleh = excluded.diisi_oleh;
    v_n := v_n + 1;
  end loop;
  return v_n;
end $$;

-- p: [{student_id, teks}] (teks kosong = hapus). p_jenis: wali (kelompok kelas) | muhaffizh (kelompok halaqah)
create or replace function public.simpan_catatan_rapor(p_group uuid, p_semester smallint, p_jenis text, p jsonb)
returns int language plpgsql volatile security definer set search_path = public as $$
declare g student_groups; x jsonb; v_n int := 0;
begin
  select * into g from student_groups where id = p_group;
  if g.id is null or (p_jenis = 'wali' and g.jenis <> 'kelas') or (p_jenis = 'muhaffizh' and g.jenis <> 'halaqah') or p_jenis not in ('wali','muhaffizh') then
    raise exception 'Kelompok tidak sesuai jenis catatan.';
  end if;
  perform public._cek_isi_rapor(p_group, p_semester, case when p_jenis = 'muhaffizh' then 'tahfizh' else g.jenjang end);
  for x in select * from jsonb_array_elements(p) loop
    if not exists (select 1 from group_members where group_id = p_group and student_id = (x->>'student_id')::uuid) then raise exception 'Santri bukan anggota kelompok ini.'; end if;
    if nullif(trim(x->>'teks'), '') is null then
      delete from report_notes where academic_year_id = g.academic_year_id and semester = p_semester and student_id = (x->>'student_id')::uuid and jenis = p_jenis;
    else
      insert into report_notes (academic_year_id, semester, student_id, jenis, teks, diisi_oleh)
      values (g.academic_year_id, p_semester, (x->>'student_id')::uuid, p_jenis, trim(x->>'teks'), public.saya())
      on conflict (academic_year_id, semester, student_id, jenis) do update set teks = excluded.teks, diisi_oleh = excluded.diisi_oleh;
    end if;
    v_n := v_n + 1;
  end loop;
  return v_n;
exception
  when check_violation then raise exception 'Catatan 3–1000 huruf.';
end $$;

-- ---------------------------------------------------------------------
-- HAK EKSEKUSI
-- ---------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array['rentang_semester(uuid,smallint)','kehadiran_kelompok(uuid,date,date)','atur_mode_utas(smallint,text,uuid)','data_utas(smallint,uuid)',
      'simpan_penguji_utas(smallint,uuid,uuid[],uuid)','bagi_peserta_utas(smallint,uuid,boolean,uuid)','ekskul_nilai_saya(smallint)','nilai_ekskul(uuid,smallint)',
      'simpan_nilai_ekskul(uuid,smallint,jsonb)','bahan_rapor_kelas(uuid,smallint)','bahan_rapor_halaqah(uuid,smallint)','halaqah_rapor_saya()',
      'simpan_kokurikuler(uuid,smallint,jsonb)','simpan_catatan_rapor(uuid,smallint,text,jsonb)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['_mode_utas(uuid,smallint)','_cek_isi_rapor(uuid,smallint,text)','_boleh_isi_rapor(uuid,smallint,text)','_boleh_lihat_kelompok_rapor(uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 5 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select '1. UTAS per kelas/halaqah (kolom utas_mode)' as pemeriksaan,
       case when exists (select 1 from information_schema.columns where table_name = 'grade_periods' and column_name = 'utas_mode') then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Tabel pengembangan diri, kokurikuler, catatan (3) dengan RLS',
       case when (select count(*) from pg_tables where schemaname = 'public' and rowsecurity and tablename in ('report_extracurricular','report_cocurricular','report_notes')) = 3
            then 'Sesuai' else 'Periksa' end
union all
select '3. Fungsi isian pengasuh',
       case when (select count(*) from pg_proc where proname in ('nilai_ekskul','simpan_nilai_ekskul','bahan_rapor_kelas','bahan_rapor_halaqah','simpan_kokurikuler','simpan_catatan_rapor')) = 6
            then 'Sesuai' else 'Periksa' end
union all
select '4. Tertutup bagi pengunjung tanpa masuk',
       case when not has_function_privilege('anon', 'public.bahan_rapor_kelas(uuid,smallint)', 'execute') then 'Sesuai' else 'Periksa' end
union all
select '5. Migrasi 8400 sudah terpasang', case when exists (select 1 from pg_proc where proname = 'juz_utas') then 'Sesuai' else 'Periksa: jalankan 8400 dulu' end;
