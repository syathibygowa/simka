-- SIMKA PRO | supabase/migrations/20261013008300_nilai_guru_mapel.sql | v1.0 | Fase 12 – Tahap 2 Isian nilai guru mapel | 13/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 12 · Migrasi 83: isian nilai guru mapel (Blueprint Bagian 19)
--   * grade_columns    : isian nilai yang dibuat guru per penugasan mengajar × semester dalam satu komponen
--                        (Harian 1, Harian 2, Ulangan Bab 1, UTS, UAS, …)
--   * grade_scores     : nilai santri per isian (0–100)
--   * grade_objectives : tujuan pembelajaran (TP) per penugasan × semester (deskripsi capaian rapor SMA)
--   * grade_finals     : nilai rapor mapel ajar per santri: nilai (pengetahuan), keterampilan (kosong = sama dengan
--                        pengetahuan), sikap (akhir semester), deskripsi/deskripsi keterampilan (kosong = otomatis)
--   * nilai_akumulasi(penugasan, semester) : rata-rata per komponen × bobot (bobot dinormalkan atas komponen yang sudah
--                        berisi), per aspek pengetahuan/keterampilan, dibulatkan sesuai ketentuan
--   * Cara menentukan nilai rapor: tunggal (guru mengisi), akumulasi (otomatis), rekomendasi (saran; guru menetapkan)
--   * Hak isi: guru pengampu saat periode Dibuka; admin ber-izin kelola_nilai/superadmin kapan saja (atas nama guru).
--     Hak baca: guru pengampu, wali kelas kelas itu, pengelola nilai, pengatur/pimpinan jenjang.
--   * Fungsi: kelas_nilai, lembar_nilai, simpan_kolom_nilai, hapus_kolom_nilai, simpan_skor_nilai, simpan_nilai_akhir,
--             simpan_tp_nilai, nilai_mapel_ajar
-- Jalankan SETELAH migrasi 8200. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TABEL
-- ---------------------------------------------------------------------
create table if not exists public.grade_columns (
  id             uuid primary key default gen_random_uuid(),
  assignment_id  uuid not null references public.teaching_assignments(id) on delete cascade,
  semester       smallint not null constraint gcol_semester check (semester in (1,2)),
  category_id    uuid not null references public.grade_categories(id) on delete restrict,
  nama           text not null constraint gcol_nama check (length(trim(nama)) between 1 and 40),
  tanggal        date,
  urutan         smallint not null default 0,
  dibuat_oleh    uuid references public.employees(id) on delete set null,
  created_at     timestamptz not null default now()
);
create index if not exists grade_columns_tugas_idx on public.grade_columns (assignment_id, semester);

create table if not exists public.grade_scores (
  column_id   uuid not null references public.grade_columns(id) on delete cascade,
  student_id  uuid not null references public.students(id) on delete cascade,
  nilai       numeric(5,2) not null constraint gsc_nilai check (nilai between 0 and 100),
  diisi_oleh  uuid references public.employees(id) on delete set null,
  updated_at  timestamptz not null default now(),
  primary key (column_id, student_id)
);

create table if not exists public.grade_objectives (
  id             uuid primary key default gen_random_uuid(),
  assignment_id  uuid not null references public.teaching_assignments(id) on delete cascade,
  semester       smallint not null constraint gobj_semester check (semester in (1,2)),
  urutan         smallint not null default 0,
  teks           text not null constraint gobj_teks check (length(trim(teks)) between 2 and 200)
);
create index if not exists grade_objectives_tugas_idx on public.grade_objectives (assignment_id, semester, urutan);

create table if not exists public.grade_finals (
  assignment_id  uuid not null references public.teaching_assignments(id) on delete cascade,
  semester       smallint not null constraint gfin_semester check (semester in (1,2)),
  student_id     uuid not null references public.students(id) on delete cascade,
  nilai          numeric(5,2) constraint gfin_nilai check (nilai between 0 and 100),
  keterampilan   numeric(5,2) constraint gfin_ket check (keterampilan between 0 and 100),
  sikap          text constraint gfin_sikap check (sikap is null or length(sikap) between 1 and 3),
  deskripsi      text,
  deskripsi_2    text,
  diisi_oleh     uuid references public.employees(id) on delete set null,
  updated_at     timestamptz not null default now(),
  primary key (assignment_id, semester, student_id)
);

drop trigger if exists aa_updated on public.grade_finals;
create trigger aa_updated before update on public.grade_finals for each row execute function public.tg_updated_at();
drop trigger if exists aa_updated on public.grade_scores;
create trigger aa_updated before update on public.grade_scores for each row execute function public.tg_updated_at();
-- Audit: nilai rapor dan isian (bukan setiap skor, agar log tidak membengkak)
do $$
declare t text;
begin
  foreach t in array array['grade_finals','grade_columns','grade_objectives'] loop
    execute format('drop trigger if exists zz_audit on public.%I', t);
    execute format('create trigger zz_audit after insert or update or delete on public.%I for each row execute function public.tg_audit()', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 2. HAK
-- ---------------------------------------------------------------------
-- Jenis rapor sebuah penugasan = jenjang kelasnya (wustha/sma)
create or replace function public._tugas_info(p_assignment uuid)
returns table (assignment_id uuid, academic_year_id uuid, group_id uuid, subject_id uuid, employee_id uuid, jenis text, tingkat smallint, terkunci boolean)
language sql stable security definer set search_path = public as $$
  select t.id, t.academic_year_id, t.group_id, t.subject_id, t.employee_id, g.jenjang, g.tingkat, a.terkunci
    from teaching_assignments t join student_groups g on g.id = t.group_id join academic_years a on a.id = t.academic_year_id
   where t.id = p_assignment
$$;

create or replace function public.boleh_lihat_nilai(p_assignment uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public._tugas_info(p_assignment) i
                  where i.employee_id = public.saya() or public.is_admin() or public.boleh_kelola_nilai()
                     or public.boleh_atur_penilaian(i.jenis) or public.pimpinan_unit(upper(i.jenis))
                     or i.group_id in (select public.kelompok_saya()))
$$;

-- Pemeriksa hak isi: guru pengampu saat periode Dibuka; pengelola nilai (admin kelola_nilai, hak fitur Nilai 3, superadmin)
-- kapan saja selama tahun ajaran belum dikunci. Mengembalikan jenis rapor.
create or replace function public._cek_isi_nilai(p_assignment uuid, p_semester smallint)
returns text language plpgsql stable security definer set search_path = public as $$
declare i record; v_status text;
begin
  select * into i from public._tugas_info(p_assignment);
  if i.assignment_id is null then raise exception 'Penugasan mengajar tidak ditemukan.'; end if;
  if p_semester not in (1,2) then raise exception 'Semester harus 1 atau 2.'; end if;
  if i.terkunci then raise exception 'Tahun ajaran ini sudah dikunci sebagai arsip (baca saja).'; end if;
  if public.boleh_kelola_nilai() then return i.jenis; end if;
  if i.employee_id is distinct from public.saya() then
    raise exception 'Hanya guru pengampu mapel ini yang dapat mengisi nilainya.' using errcode = '42501';
  end if;
  select status into v_status from grade_periods where academic_year_id = i.academic_year_id and jenis = i.jenis and semester = p_semester;
  if coalesce(v_status, 'disiapkan') = 'disiapkan' then
    raise exception 'Periode penilaian semester % belum dibuka. Hubungi pengelola penilaian.', p_semester;
  elsif v_status = 'ditutup' then
    raise exception 'Periode penilaian semester % sudah ditutup; nilai terkunci. Perubahan melalui permintaan ubah nilai kepada admin.', p_semester;
  end if;
  return i.jenis;
end $$;

-- ---------------------------------------------------------------------
-- 3. MAPEL RAPOR TERKAIT, CARA MENENTUKAN NILAI, DAN KKM
-- ---------------------------------------------------------------------
-- Mapel rapor (tingkat yang sama) yang mengambil nilai dari mapel ajar penugasan ini
create or replace function public._mapel_rapor_tugas(p_assignment uuid)
returns table (id uuid, nama text, kkm numeric, mode_nilai text, bobot numeric)
language sql stable security definer set search_path = public as $$
  select r.id, r.nama, r.kkm, r.mode_nilai, x.bobot
    from public._tugas_info(p_assignment) i
    join report_subjects r on r.academic_year_id = i.academic_year_id and r.jenis = i.jenis and r.tingkat = i.tingkat and r.aktif
    join report_subject_sources x on x.report_subject_id = r.id and x.subject_id = i.subject_id
   order by r.urutan
$$;

create or replace function public._mode_tugas(p_assignment uuid)
returns text language sql stable security definer set search_path = public as $$
  select coalesce((select m.mode_nilai from public._mapel_rapor_tugas(p_assignment) m where m.mode_nilai is not null limit 1),
                  (select s.mode_nilai from public._tugas_info(p_assignment) i join report_settings s on s.academic_year_id = i.academic_year_id and s.jenis = i.jenis),
                  'rekomendasi')
$$;

-- ---------------------------------------------------------------------
-- 4. HITUNG AKUMULASI
-- ---------------------------------------------------------------------
-- Per santri × aspek: rata-rata setiap komponen aktif, dikali bobot; bobot dinormalkan atas komponen yang sudah berisi
-- (agar saran tengah semester tetap bermakna). lengkap = semua komponen aktif aspek itu sudah berisi.
create or replace function public.nilai_akumulasi(p_assignment uuid, p_semester smallint)
returns table (student_id uuid, aspek text, nilai numeric, lengkap boolean)
language sql stable security definer set search_path = public as $$
  with i as (select * from public._tugas_info(p_assignment)),
  st as (select s.desimal from report_settings s, i where s.academic_year_id = i.academic_year_id and s.jenis = i.jenis),
  kat as (select c.id, c.aspek, c.bobot from grade_categories c, i
           where c.academic_year_id = i.academic_year_id and c.jenis = i.jenis and c.aktif and c.bobot > 0),
  rata as (select sc.student_id, k.aspek, k.id kat_id, k.bobot, avg(sc.nilai) r
             from kat k join grade_columns gc on gc.category_id = k.id and gc.assignment_id = p_assignment and gc.semester = p_semester
             join grade_scores sc on sc.column_id = gc.id
            group by sc.student_id, k.aspek, k.id, k.bobot)
  select r.student_id, r.aspek,
         round(sum(r.r * r.bobot) / nullif(sum(r.bobot), 0), coalesce((select desimal from st), 0)),
         count(*) = (select count(*) from kat k where k.aspek = r.aspek)
    from rata r group by r.student_id, r.aspek
$$;

-- Nilai mapel ajar untuk rapor (dipakai rapor/leger kelak): akumulasi → hasil hitung; tunggal/rekomendasi → nilai yang
-- ditetapkan guru. Keterampilan kosong = sama dengan pengetahuan.
create or replace function public.nilai_mapel_ajar(p_assignment uuid, p_semester smallint)
returns table (student_id uuid, nilai numeric, keterampilan numeric, sikap text, deskripsi text, deskripsi_2 text, saran numeric, saran_keterampilan numeric)
language sql stable security definer set search_path = public as $$
  with m as (select public._mode_tugas(p_assignment) mode),
  ak as (select * from public.nilai_akumulasi(p_assignment, p_semester)),
  sis as (select f.student_id from grade_finals f where f.assignment_id = p_assignment and f.semester = p_semester
          union select a.student_id from ak a)
  select s.student_id,
         case when m.mode = 'akumulasi' then (select a.nilai from ak a where a.student_id = s.student_id and a.aspek = 'pengetahuan') else f.nilai end,
         f.keterampilan, f.sikap, f.deskripsi, f.deskripsi_2,
         (select a.nilai from ak a where a.student_id = s.student_id and a.aspek = 'pengetahuan'),
         (select a.nilai from ak a where a.student_id = s.student_id and a.aspek = 'keterampilan')
    from sis s cross join m
    left join grade_finals f on f.assignment_id = p_assignment and f.semester = p_semester and f.student_id = s.student_id
$$;

-- ---------------------------------------------------------------------
-- 5. DAFTAR KELAS–MAPEL DAN LEMBAR NILAI
-- ---------------------------------------------------------------------
-- Penugasan yang terlihat (guru: miliknya; pengelola/pimpinan/wali kelas: sesuai hak) beserta kemajuan pengisian semester itu
create or replace function public.kelas_nilai(p_semester smallint default null, p_ta uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_ta uuid := coalesce(p_ta, (select id from academic_years where aktif)); v_smt smallint;
begin
  if public.saya() is null then raise exception 'Akun Anda belum aktif.'; end if;
  v_smt := coalesce(p_semester, (select semester from academic_years where id = v_ta), 1);
  return jsonb_build_object('semester', v_smt, 'ta', v_ta, 'daftar', coalesce((select jsonb_agg(x order by (x->>'milik_saya')::boolean desc, (x->>'tingkat')::int, x->>'kelas', x->>'mapel') from (
    select jsonb_build_object('assignment_id', t.id, 'group_id', g.id, 'kelas', g.nama, 'jenjang', g.jenjang, 'tingkat', g.tingkat,
      'subject_id', s.id, 'mapel', s.nama, 'kode_mapel', s.kode, 'employee_id', e.id, 'guru', e.nama_lengkap, 'niy', e.niy,
      'milik_saya', t.employee_id = public.saya(),
      'mode', public._mode_tugas(t.id),
      'mapel_rapor', coalesce((select jsonb_agg(m.nama) from public._mapel_rapor_tugas(t.id) m), '[]'::jsonb),
      'status', coalesce((select p.status from grade_periods p where p.academic_year_id = t.academic_year_id and p.jenis = g.jenjang and p.semester = v_smt), 'disiapkan'),
      'santri', (select count(*) from group_members gm join students st on st.id = gm.student_id where gm.group_id = g.id and gm.selesai is null and st.status = 'aktif'),
      'kolom', (select count(*) from grade_columns c where c.assignment_id = t.id and c.semester = v_smt),
      'terisi', (select count(*) from public.nilai_mapel_ajar(t.id, v_smt) n where n.nilai is not null
                  and n.student_id in (select gm.student_id from group_members gm where gm.group_id = g.id and gm.selesai is null)),
      'sikap', (select count(*) from grade_finals f where f.assignment_id = t.id and f.semester = v_smt and f.sikap is not null)) x
      from teaching_assignments t join student_groups g on g.id = t.group_id join subjects s on s.id = t.subject_id
      join employees e on e.id = t.employee_id
     where t.academic_year_id = v_ta and public.boleh_lihat_nilai(t.id)) q), '[]'::jsonb));
end $$;

create or replace function public.lembar_nilai(p_assignment uuid, p_semester smallint)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare i record; v_ubah boolean; v_alasan text;
begin
  select * into i from public._tugas_info(p_assignment);
  if i.assignment_id is null then raise exception 'Penugasan mengajar tidak ditemukan.'; end if;
  if not public.boleh_lihat_nilai(p_assignment) then raise exception 'Anda tidak berwenang melihat nilai mapel ini.' using errcode = '42501'; end if;
  begin perform public._cek_isi_nilai(p_assignment, p_semester); v_ubah := true;
  exception when others then v_ubah := false; v_alasan := sqlerrm; end;
  return jsonb_build_object(
    'tugas', (select jsonb_build_object('assignment_id', t.id, 'academic_year_id', t.academic_year_id, 'group_id', g.id, 'kelas', g.nama, 'jenjang', g.jenjang,
                'tingkat', g.tingkat, 'subject_id', s.id, 'mapel', s.nama, 'kode_mapel', s.kode, 'employee_id', e.id, 'guru', e.nama_lengkap, 'niy', e.niy,
                'milik_saya', t.employee_id = public.saya())
              from teaching_assignments t join student_groups g on g.id = t.group_id join subjects s on s.id = t.subject_id join employees e on e.id = t.employee_id
             where t.id = p_assignment),
    'semester', p_semester, 'boleh_ubah', v_ubah, 'alasan', v_alasan, 'pengelola', public.boleh_kelola_nilai(),
    'periode', (select to_jsonb(p) from grade_periods p where p.academic_year_id = i.academic_year_id and p.jenis = i.jenis and p.semester = p_semester),
    'mode', public._mode_tugas(p_assignment),
    'mapel_rapor', coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'nama', m.nama, 'kkm', m.kkm, 'bobot', m.bobot)) from public._mapel_rapor_tugas(p_assignment) m), '[]'::jsonb),
    'kkm', coalesce((select m.kkm from public._mapel_rapor_tugas(p_assignment) m limit 1),
                    (select ambang_bawaan from report_settings where academic_year_id = i.academic_year_id and jenis = i.jenis)),
    'ketentuan', (select jsonb_build_object('label_ambang', label_ambang, 'desimal', desimal, 'pakai_keterampilan', pakai_keterampilan,
                    'keterampilan_ikut', keterampilan_ikut, 'pakai_tp', pakai_tp, 'sikap_di_rapor', sikap_di_rapor)
                  from report_settings where academic_year_id = i.academic_year_id and jenis = i.jenis),
    'kategori', coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'kode', c.kode, 'nama', c.nama, 'aspek', c.aspek, 'bobot', c.bobot, 'berulang', c.berulang, 'aktif', c.aktif)
                    order by c.aspek, c.urutan) from grade_categories c where c.academic_year_id = i.academic_year_id and c.jenis = i.jenis
                    and (c.aktif or exists (select 1 from grade_columns x where x.category_id = c.id and x.assignment_id = p_assignment))), '[]'::jsonb),
    'predikat', coalesce((select jsonb_agg(jsonb_build_object('huruf', p.huruf, 'nilai_min', p.nilai_min, 'nilai_maks', p.nilai_maks, 'sebutan', p.sebutan,
                    'deskripsi', p.deskripsi, 'deskripsi_2', p.deskripsi_2, 'tuntas', p.tuntas) order by p.urutan)
                  from report_predicates p where p.academic_year_id = i.academic_year_id and p.kelompok = i.jenis), '[]'::jsonb),
    'sikap_pilihan', coalesce((select jsonb_agg(jsonb_build_object('huruf', p.huruf, 'sebutan', p.sebutan) order by p.urutan)
                  from report_predicates p where p.academic_year_id = i.academic_year_id and p.kelompok = 'sikap'), '[]'::jsonb),
    'kolom', coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'category_id', c.category_id, 'nama', c.nama, 'tanggal', c.tanggal, 'urutan', c.urutan)
                    order by c.urutan, c.created_at) from grade_columns c where c.assignment_id = p_assignment and c.semester = p_semester), '[]'::jsonb),
    'tp', coalesce((select jsonb_agg(jsonb_build_object('id', o.id, 'teks', o.teks) order by o.urutan) from grade_objectives o
                    where o.assignment_id = p_assignment and o.semester = p_semester), '[]'::jsonb),
    'santri', coalesce((select jsonb_agg(jsonb_build_object('id', st.id, 'nis', st.nis, 'nama', st.nama_lengkap, 'panggilan', st.nama_panggilan,
                    'jenis_kelamin', st.jenis_kelamin, 'aktif', x.aktif) order by st.nama_lengkap)
                  from (select gm.student_id, bool_or(gm.selesai is null) aktif from group_members gm where gm.group_id = i.group_id group by gm.student_id) x
                  join students st on st.id = x.student_id
                 where (x.aktif and st.status in ('aktif','nonaktif'))
                    or exists (select 1 from grade_finals f where f.assignment_id = p_assignment and f.semester = p_semester and f.student_id = st.id)
                    or exists (select 1 from grade_scores sc join grade_columns c on c.id = sc.column_id
                                where c.assignment_id = p_assignment and c.semester = p_semester and sc.student_id = st.id)), '[]'::jsonb),
    'skor', coalesce((select jsonb_agg(jsonb_build_array(sc.column_id, sc.student_id, sc.nilai))
                  from grade_scores sc join grade_columns c on c.id = sc.column_id where c.assignment_id = p_assignment and c.semester = p_semester), '[]'::jsonb),
    'akhir', coalesce((select jsonb_agg(jsonb_build_object('student_id', n.student_id, 'nilai', n.nilai, 'keterampilan', n.keterampilan, 'sikap', n.sikap,
                    'deskripsi', n.deskripsi, 'deskripsi_2', n.deskripsi_2, 'saran', n.saran, 'saran_keterampilan', n.saran_keterampilan))
                  from public.nilai_mapel_ajar(p_assignment, p_semester) n), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------
-- 6. SIMPAN
-- ---------------------------------------------------------------------
-- p: {id?, category_id, nama, tanggal?}
create or replace function public.simpan_kolom_nilai(p_assignment uuid, p_semester smallint, p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_jenis text; v_id uuid := nullif(p->>'id', '')::uuid; c grade_categories; i record;
begin
  v_jenis := public._cek_isi_nilai(p_assignment, p_semester);
  select * into i from public._tugas_info(p_assignment);
  select * into c from grade_categories where id = coalesce(nullif(p->>'category_id', '')::uuid, (select category_id from grade_columns where id = v_id));
  if c.id is null or c.academic_year_id <> i.academic_year_id or c.jenis <> v_jenis then raise exception 'Komponen nilai tidak sah untuk mapel ini.'; end if;
  if coalesce(trim(p->>'nama'), '') = '' then raise exception 'Nama isian wajib diisi.'; end if;
  if v_id is null then
    if not c.aktif then raise exception 'Komponen % sudah dinonaktifkan pengelola penilaian.', c.nama; end if;
    if not c.berulang and exists (select 1 from grade_columns where assignment_id = p_assignment and semester = p_semester and category_id = c.id) then
      raise exception 'Komponen % hanya diisi sekali dan isiannya sudah ada.', c.nama;
    end if;
    insert into grade_columns (assignment_id, semester, category_id, nama, tanggal, urutan, dibuat_oleh)
    values (p_assignment, p_semester, c.id, trim(p->>'nama'), nullif(p->>'tanggal', '')::date,
            coalesce((select max(urutan) + 1 from grade_columns where assignment_id = p_assignment and semester = p_semester), 1), public.saya())
    returning id into v_id;
  else
    update grade_columns set nama = trim(p->>'nama'), tanggal = case when p ? 'tanggal' then nullif(p->>'tanggal', '')::date else tanggal end
     where id = v_id and assignment_id = p_assignment and semester = p_semester;
    if not found then raise exception 'Isian nilai tidak ditemukan.'; end if;
  end if;
  return v_id;
exception
  when check_violation then raise exception 'Nama isian 1–40 huruf.';
end $$;

create or replace function public.hapus_kolom_nilai(p_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare c grade_columns;
begin
  select * into c from grade_columns where id = p_id;
  if c.id is null then return; end if;
  perform public._cek_isi_nilai(c.assignment_id, c.semester);
  delete from grade_columns where id = p_id;
end $$;

-- p: [{student_id, nilai}] (nilai kosong/null = hapus)
create or replace function public.simpan_skor_nilai(p_column uuid, p jsonb)
returns int language plpgsql volatile security definer set search_path = public as $$
declare c grade_columns; r jsonb; v_n int := 0; v_grup uuid;
begin
  select * into c from grade_columns where id = p_column;
  if c.id is null then raise exception 'Isian nilai tidak ditemukan.'; end if;
  perform public._cek_isi_nilai(c.assignment_id, c.semester);
  select group_id into v_grup from teaching_assignments where id = c.assignment_id;
  for r in select * from jsonb_array_elements(p) loop
    if not exists (select 1 from group_members where group_id = v_grup and student_id = (r->>'student_id')::uuid) then
      raise exception 'Santri tidak terdaftar di kelas ini.';
    end if;
    if nullif(r->>'nilai', '') is null then
      delete from grade_scores where column_id = p_column and student_id = (r->>'student_id')::uuid;
    else
      insert into grade_scores (column_id, student_id, nilai, diisi_oleh) values (p_column, (r->>'student_id')::uuid, (r->>'nilai')::numeric, public.saya())
      on conflict (column_id, student_id) do update set nilai = excluded.nilai, diisi_oleh = excluded.diisi_oleh;
    end if;
    v_n := v_n + 1;
  end loop;
  return v_n;
exception
  when check_violation then raise exception 'Nilai harus 0–100.';
  when invalid_text_representation then raise exception 'Nilai harus berupa angka 0–100.';
end $$;

-- p: [{student_id, nilai?, keterampilan?, sikap?, deskripsi?, deskripsi_2?}] — hanya kunci yang dikirim yang diubah
create or replace function public.simpan_nilai_akhir(p_assignment uuid, p_semester smallint, p jsonb)
returns int language plpgsql volatile security definer set search_path = public as $$
declare r jsonb; v_n int := 0; i record; v_mode text; v_sikap text[];
begin
  perform public._cek_isi_nilai(p_assignment, p_semester);
  select * into i from public._tugas_info(p_assignment);
  v_mode := public._mode_tugas(p_assignment);
  select coalesce(array_agg(huruf), '{}') into v_sikap from report_predicates where academic_year_id = i.academic_year_id and kelompok = 'sikap';
  for r in select * from jsonb_array_elements(p) loop
    if not exists (select 1 from group_members where group_id = i.group_id and student_id = (r->>'student_id')::uuid) then
      raise exception 'Santri tidak terdaftar di kelas ini.';
    end if;
    if nullif(r->>'sikap', '') is not null and upper(r->>'sikap') <> all(v_sikap) then
      raise exception 'Nilai sikap harus salah satu: %.', array_to_string(v_sikap, ', ');
    end if;
    insert into grade_finals (assignment_id, semester, student_id, diisi_oleh) values (p_assignment, p_semester, (r->>'student_id')::uuid, public.saya())
    on conflict do nothing;
    update grade_finals set
      nilai        = case when r ? 'nilai' and v_mode <> 'akumulasi' then nullif(r->>'nilai', '')::numeric else nilai end,
      keterampilan = case when r ? 'keterampilan' then nullif(r->>'keterampilan', '')::numeric else keterampilan end,
      sikap        = case when r ? 'sikap' then upper(nullif(trim(r->>'sikap'), '')) else sikap end,
      deskripsi    = case when r ? 'deskripsi' then nullif(trim(r->>'deskripsi'), '') else deskripsi end,
      deskripsi_2  = case when r ? 'deskripsi_2' then nullif(trim(r->>'deskripsi_2'), '') else deskripsi_2 end,
      diisi_oleh   = public.saya()
    where assignment_id = p_assignment and semester = p_semester and student_id = (r->>'student_id')::uuid;
    v_n := v_n + 1;
  end loop;
  -- Baris yang seluruhnya kosong dibuang
  delete from grade_finals where assignment_id = p_assignment and semester = p_semester
     and nilai is null and keterampilan is null and sikap is null and deskripsi is null and deskripsi_2 is null;
  return v_n;
exception
  when check_violation then raise exception 'Nilai harus 0–100.';
  when invalid_text_representation then raise exception 'Nilai harus berupa angka 0–100.';
end $$;

-- p: ["TP 1", "TP 2", …] — mengganti seluruh daftar tujuan pembelajaran
create or replace function public.simpan_tp_nilai(p_assignment uuid, p_semester smallint, p jsonb)
returns int language plpgsql volatile security definer set search_path = public as $$
declare v_n int := 0; t text;
begin
  perform public._cek_isi_nilai(p_assignment, p_semester);
  if jsonb_array_length(p) > 20 then raise exception 'Paling banyak 20 tujuan pembelajaran.'; end if;
  delete from grade_objectives where assignment_id = p_assignment and semester = p_semester;
  for t in select trim(value) from jsonb_array_elements_text(p) loop
    if t = '' then continue; end if;
    v_n := v_n + 1;
    insert into grade_objectives (assignment_id, semester, urutan, teks) values (p_assignment, p_semester, v_n, t);
  end loop;
  return v_n;
exception
  when check_violation then raise exception 'Setiap tujuan pembelajaran 2–200 huruf.';
end $$;

-- ---------------------------------------------------------------------
-- 7. RLS (baca sesuai hak; tulis hanya lewat fungsi)
-- ---------------------------------------------------------------------
alter table public.grade_columns enable row level security;
alter table public.grade_scores enable row level security;
alter table public.grade_objectives enable row level security;
alter table public.grade_finals enable row level security;
drop policy if exists baca_hak on public.grade_columns;
create policy baca_hak on public.grade_columns for select to authenticated using (public.boleh_lihat_nilai(assignment_id));
drop policy if exists baca_hak on public.grade_objectives;
create policy baca_hak on public.grade_objectives for select to authenticated using (public.boleh_lihat_nilai(assignment_id));
drop policy if exists baca_hak on public.grade_finals;
create policy baca_hak on public.grade_finals for select to authenticated using (public.boleh_lihat_nilai(assignment_id));
drop policy if exists baca_hak on public.grade_scores;
create policy baca_hak on public.grade_scores for select to authenticated using (
  public.boleh_lihat_nilai((select c.assignment_id from public.grade_columns c where c.id = column_id)));

-- ---------------------------------------------------------------------
-- 8. KOMPONEN NILAI: komponen yang sudah dipakai isian dinonaktifkan, tidak dihapus
-- ---------------------------------------------------------------------
create or replace function public.simpan_komponen_nilai(p_ta uuid, p_jenis text, p jsonb)
returns void language plpgsql volatile security definer set search_path = public as $$
declare r jsonb; i int := 0; v_kode text; v_ids uuid[] := '{}'; v_id uuid; v_sum numeric; v_kt boolean;
begin
  perform public._cek_atur_penilaian(p_ta, p_jenis);
  if p_jenis not in ('sma','wustha') then raise exception 'Komponen nilai hanya untuk rapor SMA dan Wustha.'; end if;
  if jsonb_typeof(p) <> 'array' or jsonb_array_length(p) = 0 then raise exception 'Minimal satu komponen nilai.'; end if;
  select pakai_keterampilan into v_kt from report_settings where academic_year_id = p_ta and jenis = p_jenis;
  -- Bobot komponen aktif per aspek harus berjumlah 100
  for r in select jsonb_build_object('aspek', a) from unnest(array['pengetahuan','keterampilan']) a loop
    select coalesce(sum((x->>'bobot')::numeric), 0) into v_sum from jsonb_array_elements(p) x
     where coalesce(x->>'aspek', 'pengetahuan') = r->>'aspek' and coalesce((x->>'aktif')::boolean, true);
    if (r->>'aspek' = 'pengetahuan' or coalesce(v_kt, false)) and v_sum <> 100
       and exists (select 1 from jsonb_array_elements(p) x where coalesce(x->>'aspek', 'pengetahuan') = r->>'aspek' and coalesce((x->>'aktif')::boolean, true)) then
      raise exception 'Bobot komponen % harus berjumlah 100%% (sekarang %).', r->>'aspek', v_sum;
    end if;
  end loop;
  if not exists (select 1 from jsonb_array_elements(p) x where coalesce(x->>'aspek', 'pengetahuan') = 'pengetahuan' and coalesce((x->>'aktif')::boolean, true)) then
    raise exception 'Minimal satu komponen pengetahuan yang aktif.';
  end if;
  for r in select * from jsonb_array_elements(p) loop
    i := i + 1;
    if coalesce(trim(r->>'nama'), '') = '' then raise exception 'Nama komponen wajib diisi.'; end if;
    v_kode := upper(regexp_replace(coalesce(nullif(trim(r->>'kode'), ''), trim(r->>'nama')), '[^A-Za-z0-9]+', '_', 'g'));
    v_kode := left(trim(both '_' from v_kode), 20);
    v_id := nullif(r->>'id', '')::uuid;
    if v_id is not null and exists (select 1 from grade_categories where id = v_id and academic_year_id = p_ta and jenis = p_jenis) then
      update grade_categories set nama = trim(r->>'nama'), aspek = coalesce(nullif(r->>'aspek', ''), 'pengetahuan'),
             bobot = coalesce((r->>'bobot')::numeric, 0), berulang = coalesce((r->>'berulang')::boolean, true),
             aktif = coalesce((r->>'aktif')::boolean, true), urutan = i
       where id = v_id;
    else
      insert into grade_categories (academic_year_id, jenis, kode, nama, aspek, bobot, berulang, aktif, urutan)
      values (p_ta, p_jenis, v_kode, trim(r->>'nama'), coalesce(nullif(r->>'aspek', ''), 'pengetahuan'), coalesce((r->>'bobot')::numeric, 0),
              coalesce((r->>'berulang')::boolean, true), coalesce((r->>'aktif')::boolean, true), i)
      on conflict (academic_year_id, jenis, kode) do update set nama = excluded.nama, aspek = excluded.aspek, bobot = excluded.bobot,
             berulang = excluded.berulang, aktif = excluded.aktif, urutan = excluded.urutan
      returning id into v_id;
    end if;
    v_ids := v_ids || v_id;
  end loop;
  -- Komponen yang tidak dikirim: dinonaktifkan bila sudah dipakai isian nilai guru, selain itu dihapus
  update grade_categories c set aktif = false where c.academic_year_id = p_ta and c.jenis = p_jenis and c.id <> all(v_ids)
     and exists (select 1 from grade_columns x where x.category_id = c.id);
  delete from grade_categories c where c.academic_year_id = p_ta and c.jenis = p_jenis and c.id <> all(v_ids)
     and not exists (select 1 from grade_columns x where x.category_id = c.id);
exception
  when check_violation then raise exception 'Bobot komponen harus 0–100.';
  when unique_violation then raise exception 'Nama/kode komponen kembar. Gunakan nama yang berbeda.';
end $$;

-- ---------------------------------------------------------------------
-- 9. HAK EKSEKUSI
-- ---------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array['boleh_lihat_nilai(uuid)','nilai_akumulasi(uuid,smallint)','nilai_mapel_ajar(uuid,smallint)','kelas_nilai(smallint,uuid)',
      'lembar_nilai(uuid,smallint)','simpan_kolom_nilai(uuid,smallint,jsonb)','hapus_kolom_nilai(uuid)','simpan_skor_nilai(uuid,jsonb)',
      'simpan_nilai_akhir(uuid,smallint,jsonb)','simpan_tp_nilai(uuid,smallint,jsonb)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['_tugas_info(uuid)','_cek_isi_nilai(uuid,smallint)','_mapel_rapor_tugas(uuid)','_mode_tugas(uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 10. PEMERIKSAAN — hasil yang benar: 5 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select '1. Tabel isian nilai (4) dengan RLS' as pemeriksaan,
       case when (select count(*) from pg_tables where schemaname = 'public' and rowsecurity and tablename in
         ('grade_columns','grade_scores','grade_objectives','grade_finals')) = 4 then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Fungsi isian nilai guru',
       case when (select count(*) from pg_proc where proname in ('kelas_nilai','lembar_nilai','simpan_kolom_nilai','simpan_skor_nilai','simpan_nilai_akhir','simpan_tp_nilai')) = 6
            then 'Sesuai' else 'Periksa' end
union all
select '3. Tabel tertutup untuk tulis langsung',
       case when not exists (select 1 from pg_policies where tablename in ('grade_columns','grade_scores','grade_objectives','grade_finals') and cmd <> 'SELECT')
            then 'Sesuai' else 'Periksa' end
union all
select '4. Tertutup bagi pengunjung tanpa masuk',
       case when not has_function_privilege('anon', 'public.lembar_nilai(uuid,smallint)', 'execute') then 'Sesuai' else 'Periksa' end
union all
select '5. Migrasi 8200 sudah terpasang',
       case when exists (select 1 from pg_proc where proname = 'pengaturan_penilaian') then 'Sesuai' else 'Periksa: jalankan 8200 dulu' end;
