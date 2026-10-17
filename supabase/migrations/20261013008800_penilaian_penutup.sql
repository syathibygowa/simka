-- SIMKA PRO | supabase/migrations/20261013008800_penilaian_penutup.sql | v1.0 | Fase 12 – Tahap 6 Kunci periode, permintaan ubah nilai, rekap | 13/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 12 · Migrasi 88 (penutup Fase 12 – Penilaian)
--   A. Kunci periode: status efektif "ditutup" bila status Dibuka tetapi batas pengisian (batas_isi) sudah lewat.
--      Berlaku untuk isian guru mapel, isian pengasuh (pengembangan diri, catatan, kokurikuler, nilai wali kelas,
--      kenaikan), dan nilai UTAS oleh penguji. Pengelola nilai tetap dapat mengubah kapan saja (TA belum dikunci).
--   B. Permintaan ubah nilai: guru pengampu (nilai mapel) atau penguji (UTAS final) mengajukan perubahan beserta alasan;
--      pengelola nilai (admin ber-izin Mengelola nilai / superadmin; UTAS juga panitia) menyetujui atau menolak.
--      Disetujui → nilai langsung diterapkan; semua permintaan menjadi riwayat perubahan nilai. Notifikasi dua arah.
--      * grade_change_requests; grade_finals.koreksi (nilai rapor hasil koreksi yang disetujui, juga untuk mode akumulasi)
--   C. Rekap penilaian untuk pimpinan (kemajuan pengisian per kelas, guru, UTAS, ekskul) dan ringkasan beranda.
-- Jalankan SETELAH migrasi 8600 (dan perbaikan 8700). Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- A. STATUS PERIODE EFEKTIF
-- ---------------------------------------------------------------------
create or replace function public.status_periode_efektif(p_ta uuid, p_jenis text, p_semester smallint)
returns text language sql stable security definer set search_path = public as $$
  select case when p.status = 'dibuka' and p.batas_isi is not null and p.batas_isi < public.hari_ini() then 'ditutup'
              else coalesce(p.status, 'disiapkan') end
    from (select 1) x left join grade_periods p on p.academic_year_id = p_ta and p.jenis = p_jenis and p.semester = p_semester
$$;

create or replace function public._cek_isi_nilai(p_assignment uuid, p_semester smallint)
returns text language plpgsql stable security definer set search_path = public as $$
declare i record; v_status text; v_batas date;
begin
  select * into i from public._tugas_info(p_assignment);
  if i.assignment_id is null then raise exception 'Penugasan mengajar tidak ditemukan.'; end if;
  if p_semester not in (1,2) then raise exception 'Semester harus 1 atau 2.'; end if;
  if i.terkunci then raise exception 'Tahun ajaran ini sudah dikunci sebagai arsip (baca saja).'; end if;
  if public.boleh_kelola_nilai() then return i.jenis; end if;
  if i.employee_id is distinct from public.saya() then
    raise exception 'Hanya guru pengampu mapel ini yang dapat mengisi nilainya.' using errcode = '42501';
  end if;
  v_status := public.status_periode_efektif(i.academic_year_id, i.jenis, p_semester);
  select batas_isi into v_batas from grade_periods where academic_year_id = i.academic_year_id and jenis = i.jenis and semester = p_semester;
  if v_status = 'disiapkan' then
    raise exception 'Periode penilaian semester % belum dibuka. Hubungi pengelola penilaian.', p_semester;
  elsif v_status = 'ditutup' then
    raise exception 'Periode penilaian semester % sudah ditutup%; nilai terkunci. Perubahan melalui permintaan ubah nilai kepada admin.', p_semester,
      case when v_batas is not null and v_batas < public.hari_ini() then ' (batas pengisian ' || to_char(v_batas, 'DD/MM/YYYY') || ')' else '' end;
  end if;
  return i.jenis;
end $$;

create or replace function public._cek_isi_rapor(p_group uuid, p_semester smallint, p_jenis text)
returns void language plpgsql stable security definer set search_path = public as $$
declare g student_groups; v_status text; v_nama text;
begin
  select * into g from student_groups where id = p_group;
  if g.id is null then raise exception 'Kelompok santri tidak ditemukan.'; end if;
  if p_semester not in (1,2) then raise exception 'Semester harus 1 atau 2.'; end if;
  perform public._ta_boleh_ubah(g.academic_year_id);
  if public.boleh_kelola_nilai() then return; end if;
  if p_group not in (select public.kelompok_saya()) then
    raise exception 'Hanya pengasuh kelompok ini (atau pengelola nilai) yang dapat mengisinya.' using errcode = '42501';
  end if;
  v_status := public.status_periode_efektif(g.academic_year_id, p_jenis, p_semester);
  v_nama := case p_jenis when 'sma' then 'SMA' when 'wustha' then 'Wustha' else 'Tahfizh' end;
  if v_status = 'disiapkan' then
    raise exception 'Periode penilaian % semester % belum dibuka.', v_nama, p_semester;
  elsif v_status = 'ditutup' then
    raise exception 'Periode penilaian % semester % sudah ditutup; perubahan melalui pengelola nilai.', v_nama, p_semester;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- B. KOREKSI NILAI DAN PERMINTAAN UBAH NILAI
-- ---------------------------------------------------------------------
alter table public.grade_finals add column if not exists koreksi numeric(5,2);
do $$ begin
  alter table public.grade_finals add constraint gfin_koreksi check (koreksi is null or koreksi between 0 and 100);
exception when duplicate_object then null; end $$;

create table if not exists public.grade_change_requests (
  id                uuid primary key default gen_random_uuid(),
  academic_year_id  uuid not null references public.academic_years(id) on delete cascade,
  semester          smallint not null constraint gcr_semester check (semester in (1,2)),
  jenis             text not null constraint gcr_jenis check (jenis in ('mapel','utas')),
  assignment_id     uuid references public.teaching_assignments(id) on delete cascade,
  utas_result_id    uuid references public.utas_results(id) on delete cascade,
  student_id        uuid not null references public.students(id) on delete cascade,
  perubahan         jsonb not null,            -- {"nilai": {"lama": 70, "baru": 78}, "sikap": {...}} / {"tajwid": {...}, "itqan": {...}}
  alasan            text not null constraint gcr_alasan check (length(trim(alasan)) >= 5),
  status            text not null default 'menunggu' constraint gcr_status check (status in ('menunggu','disetujui','ditolak','dibatalkan')),
  diajukan_oleh     uuid references public.employees(id) on delete set null,
  diajukan_pada     timestamptz not null default now(),
  diputus_oleh      uuid references public.employees(id) on delete set null,
  diputus_pada      timestamptz,
  catatan_putusan   text,
  constraint gcr_sasaran check ((jenis = 'mapel' and assignment_id is not null) or (jenis = 'utas' and utas_result_id is not null))
);
create index if not exists gcr_status_idx on public.grade_change_requests (status, diajukan_pada desc);
create index if not exists gcr_tugas_idx on public.grade_change_requests (assignment_id, semester, student_id);
create unique index if not exists gcr_satu_menunggu on public.grade_change_requests (coalesce(assignment_id, utas_result_id), semester, student_id) where status = 'menunggu';
drop trigger if exists zz_audit on public.grade_change_requests;
create trigger zz_audit after insert or update or delete on public.grade_change_requests for each row execute function public.tg_audit();
alter table public.grade_change_requests enable row level security;
drop policy if exists baca_hak on public.grade_change_requests;
create policy baca_hak on public.grade_change_requests for select to authenticated
  using (diajukan_oleh = public.saya() or public.boleh_kelola_nilai() or public.panitia_utas());

-- nilai_mapel_ajar (versi 8800): koreksi yang disetujui menggantikan nilai rapor (semua cara penilaian)
create or replace function public.nilai_mapel_ajar(p_assignment uuid, p_semester smallint)
returns table (student_id uuid, nilai numeric, keterampilan numeric, sikap text, deskripsi text, deskripsi_2 text, saran numeric, saran_keterampilan numeric)
language sql stable security definer set search_path = public as $$
  with m as (select public._mode_tugas(p_assignment) mode),
  ak as (select * from public.nilai_akumulasi(p_assignment, p_semester)),
  sis as (select f.student_id from grade_finals f where f.assignment_id = p_assignment and f.semester = p_semester
          union select a.student_id from ak a)
  select s.student_id,
         case when f.koreksi is not null then f.koreksi
              when m.mode = 'akumulasi' then (select a.nilai from ak a where a.student_id = s.student_id and a.aspek = 'pengetahuan') else f.nilai end,
         f.keterampilan, f.sikap, f.deskripsi, f.deskripsi_2,
         (select a.nilai from ak a where a.student_id = s.student_id and a.aspek = 'pengetahuan'),
         (select a.nilai from ak a where a.student_id = s.student_id and a.aspek = 'keterampilan')
    from sis s cross join m
    left join grade_finals f on f.assignment_id = p_assignment and f.semester = p_semester and f.student_id = s.student_id
$$;

-- simpan_nilai_utas (versi 8800): penguji terkunci bila periode tahfizh ditutup atau batas pengisian lewat
create or replace function public.simpan_nilai_utas(p jsonb, p_kirim boolean default false)
returns int language plpgsql volatile security definer set search_path = public as $$
declare x jsonb; r utas_results; v_n int := 0; v_panitia boolean := public.panitia_utas(); h record; v_juz smallint[]; v_status text;
begin
  for x in select * from jsonb_array_elements(p) loop
    select * into r from utas_results where id = (x->>'id')::uuid;
    if r.id is null then raise exception 'Peserta UTAS tidak ditemukan.'; end if;
    perform public._ta_boleh_ubah(r.academic_year_id);
    if not v_panitia then
      if r.penguji_id is distinct from public.saya() then raise exception 'Anda bukan penguji santri ini.' using errcode = '42501'; end if;
      if r.status = 'final' then raise exception 'Nilai sudah dikirim (final). Ajukan permintaan ubah nilai kepada panitia UTAS.'; end if;
      v_status := public.status_periode_efektif(r.academic_year_id, 'tahfizh', r.semester);
      if v_status = 'ditutup' then raise exception 'Periode penilaian tahfizh semester % sudah ditutup; perubahan melalui permintaan ubah nilai.', r.semester; end if;
    end if;
    if x ? 'juz' then
      select coalesce(array_agg(distinct j::smallint order by j::smallint), '{}') into v_juz from jsonb_array_elements_text(x->'juz') j where j ~ '^\d+$';
      if exists (select 1 from unnest(v_juz) j where j not between 1 and 30) then raise exception 'Nomor juz harus 1–30.'; end if;
    end if;
    update utas_results set
      juz        = case when x ? 'juz' then v_juz else juz end,
      tajwid     = case when x ? 'tajwid' then nullif(x->>'tajwid', '')::numeric else tajwid end,
      itqan      = case when x ? 'itqan' then nullif(x->>'itqan', '')::numeric else itqan end,
      catatan    = case when x ? 'catatan' then nullif(trim(x->>'catatan'), '') else catatan end,
      diuji_pada = case when x ? 'diuji_pada' then nullif(x->>'diuji_pada', '')::date else coalesce(diuji_pada, public.hari_ini()) end,
      diisi_oleh = public.saya()
    where id = r.id returning * into r;
    select * into h from public._hitung_utas(r.academic_year_id, r.tajwid, r.itqan);
    if p_kirim and (r.tajwid is null or r.itqan is null) then raise exception 'Nilai Tajwid dan Itqan % wajib diisi sebelum dikirim.', (select nama_lengkap from students where id = r.student_id); end if;
    update utas_results set nilai_akhir = h.nilai, huruf = h.huruf, tuntas = h.tuntas,
      status = case when p_kirim then 'final' else status end
     where id = r.id;
    v_n := v_n + 1;
  end loop;
  return v_n;
exception
  when check_violation then raise exception 'Nilai Tajwid dan Itqan harus 0–100.';
  when invalid_text_representation then raise exception 'Nilai harus berupa angka 0–100.';
end $$;

-- Ajukan permintaan ubah nilai.
-- p mapel: {jenis:'mapel', assignment_id, semester, student_id, nilai?, keterampilan?, sikap?, deskripsi?, alasan}
-- p utas : {jenis:'utas', utas_result_id, tajwid?, itqan?, alasan}
create or replace function public.ajukan_ubah_nilai(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_jenis text := coalesce(nullif(p->>'jenis', ''), 'mapel'); v_smt smallint; v_aid uuid; v_sid uuid; v_ta uuid; v_ubah jsonb := '{}'::jsonb;
  v_alasan text := trim(coalesce(p->>'alasan', '')); i record; n record; r utas_results; v_bisa boolean; k text; v_baru text; v_lama jsonb; v_id uuid;
  v_huruf text[]; v_ket text;
begin
  if public.saya() is null then raise exception 'Akun Anda belum aktif.'; end if;
  if length(v_alasan) < 5 then raise exception 'Alasan perubahan wajib diisi (minimal 5 huruf).'; end if;
  if v_jenis = 'mapel' then
    v_aid := (p->>'assignment_id')::uuid; v_smt := (p->>'semester')::smallint; v_sid := (p->>'student_id')::uuid;
    select * into i from public._tugas_info(v_aid);
    if i.assignment_id is null then raise exception 'Penugasan mengajar tidak ditemukan.'; end if;
    if i.terkunci then raise exception 'Tahun ajaran ini sudah dikunci sebagai arsip (baca saja).'; end if;
    if i.employee_id is distinct from public.saya() then raise exception 'Hanya guru pengampu mapel ini yang dapat mengajukan perubahan nilainya.' using errcode = '42501'; end if;
    begin perform public._cek_isi_nilai(v_aid, v_smt); v_bisa := true; exception when others then v_bisa := false; end;
    if v_bisa then raise exception 'Periode penilaian masih dibuka; ubah nilai langsung di lembar nilai.'; end if;
    if public.status_periode_efektif(i.academic_year_id, i.jenis, v_smt) = 'disiapkan' then raise exception 'Periode penilaian semester % belum dibuka.', v_smt; end if;
    if not exists (select 1 from group_members where group_id = i.group_id and student_id = v_sid) then raise exception 'Santri bukan anggota kelas ini.'; end if;
    select * into n from public.nilai_mapel_ajar(v_aid, v_smt) x where x.student_id = v_sid;
    select coalesce(array_agg(huruf), '{}') into v_huruf from report_predicates where academic_year_id = i.academic_year_id and kelompok = 'sikap';
    foreach k in array array['nilai','keterampilan','sikap','deskripsi'] loop
      continue when not (p ? k);
      v_baru := nullif(trim(p->>k), '');
      v_lama := case k when 'nilai' then to_jsonb(n.nilai) when 'keterampilan' then to_jsonb(n.keterampilan) when 'sikap' then to_jsonb(n.sikap) else to_jsonb(n.deskripsi) end;
      if k in ('nilai','keterampilan') then
        if v_baru is not null and (v_baru !~ '^\d+(\.\d+)?$' or v_baru::numeric > 100) then raise exception 'Nilai harus 0–100.'; end if;
        continue when (v_baru::numeric) is not distinct from (v_lama #>> '{}')::numeric;
        v_ubah := v_ubah || jsonb_build_object(k, jsonb_build_object('lama', v_lama, 'baru', to_jsonb(v_baru::numeric)));
      else
        if k = 'sikap' and v_baru is not null then v_baru := upper(v_baru); if v_baru <> all(v_huruf) then raise exception 'Sikap harus salah satu: %.', array_to_string(v_huruf, ', '); end if; end if;
        continue when v_baru is not distinct from (v_lama #>> '{}');
        v_ubah := v_ubah || jsonb_build_object(k, jsonb_build_object('lama', v_lama, 'baru', to_jsonb(v_baru)));
      end if;
    end loop;
    v_ta := i.academic_year_id;
    v_ket := (select s.nama || ' kelas ' || g.nama from subjects s, student_groups g where s.id = i.subject_id and g.id = i.group_id);
  elsif v_jenis = 'utas' then
    select * into r from utas_results where id = (p->>'utas_result_id')::uuid;
    if r.id is null then raise exception 'Peserta UTAS tidak ditemukan.'; end if;
    perform public._ta_boleh_ubah(r.academic_year_id);
    if r.penguji_id is distinct from public.saya() then raise exception 'Hanya penguji santri ini yang dapat mengajukan perubahan nilai UTAS.' using errcode = '42501'; end if;
    if r.status <> 'final' and public.status_periode_efektif(r.academic_year_id, 'tahfizh', r.semester) <> 'ditutup' then
      raise exception 'Nilai belum final; ubah langsung di daftar UTAS.';
    end if;
    v_sid := r.student_id; v_smt := r.semester; v_ta := r.academic_year_id;
    foreach k in array array['tajwid','itqan'] loop
      continue when not (p ? k);
      v_baru := nullif(trim(p->>k), '');
      if v_baru is null or v_baru !~ '^\d+(\.\d+)?$' or v_baru::numeric > 100 then raise exception 'Nilai % harus 0–100.', initcap(k); end if;
      v_lama := case k when 'tajwid' then to_jsonb(r.tajwid) else to_jsonb(r.itqan) end;
      continue when v_baru::numeric is not distinct from (v_lama #>> '{}')::numeric;
      v_ubah := v_ubah || jsonb_build_object(k, jsonb_build_object('lama', v_lama, 'baru', to_jsonb(v_baru::numeric)));
    end loop;
    v_ket := 'UTAS semester ' || r.semester;
  else
    raise exception 'Jenis permintaan tidak dikenal.';
  end if;
  if v_ubah = '{}'::jsonb then raise exception 'Tidak ada nilai yang berubah.'; end if;
  begin
    insert into grade_change_requests (academic_year_id, semester, jenis, assignment_id, utas_result_id, student_id, perubahan, alasan, diajukan_oleh)
    values (v_ta, v_smt, v_jenis, case when v_jenis = 'mapel' then v_aid end, case when v_jenis = 'utas' then r.id end, v_sid, v_ubah, v_alasan, public.saya())
    returning id into v_id;
  exception when unique_violation then
    raise exception 'Masih ada permintaan ubah nilai santri ini yang menunggu keputusan; batalkan dulu bila ingin mengganti.';
  end;
  perform public.notifikasi_admin('kelola_nilai', 'Permintaan ubah nilai',
    (select nama_lengkap from employees where id = public.saya()) || ' mengajukan perubahan nilai ' || v_ket || ' untuk ' || (select nama_lengkap from students where id = v_sid) || '.',
    '/penilaian/permintaan', 'PencilLine', 'kuning');
  return v_id;
end $$;

create or replace function public.batal_ubah_nilai(p_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  update grade_change_requests set status = 'dibatalkan', diputus_pada = now(), diputus_oleh = public.saya()
   where id = p_id and status = 'menunggu' and diajukan_oleh = public.saya();
  if not found then raise exception 'Permintaan tidak ditemukan, bukan milik Anda, atau sudah diputus.'; end if;
end $$;

create or replace function public.putuskan_ubah_nilai(p_id uuid, p_setuju boolean, p_catatan text default null)
returns void language plpgsql volatile security definer set search_path = public as $$
declare q grade_change_requests; v_mode text; r utas_results; h record; v_ket text;
begin
  select * into q from grade_change_requests where id = p_id for update;
  if q.id is null then raise exception 'Permintaan tidak ditemukan.'; end if;
  if q.status <> 'menunggu' then raise exception 'Permintaan ini sudah diputus.'; end if;
  if not (public.boleh_kelola_nilai() or (q.jenis = 'utas' and public.panitia_utas())) then
    raise exception 'Hanya pengelola nilai yang dapat memutus permintaan ubah nilai.' using errcode = '42501';
  end if;
  perform public._ta_boleh_ubah(q.academic_year_id);
  if not p_setuju and length(trim(coalesce(p_catatan, ''))) < 3 then raise exception 'Tuliskan alasan penolakan.'; end if;
  if p_setuju then
    if q.jenis = 'mapel' then
      v_mode := public._mode_tugas(q.assignment_id);
      insert into grade_finals (assignment_id, semester, student_id, diisi_oleh) values (q.assignment_id, q.semester, q.student_id, public.saya())
      on conflict (assignment_id, semester, student_id) do nothing;
      update grade_finals set
        nilai        = case when q.perubahan ? 'nilai' and v_mode <> 'akumulasi' then (q.perubahan->'nilai'->>'baru')::numeric else nilai end,
        koreksi      = case when q.perubahan ? 'nilai' and v_mode = 'akumulasi' then (q.perubahan->'nilai'->>'baru')::numeric else koreksi end,
        keterampilan = case when q.perubahan ? 'keterampilan' then (q.perubahan->'keterampilan'->>'baru')::numeric else keterampilan end,
        sikap        = case when q.perubahan ? 'sikap' then q.perubahan->'sikap'->>'baru' else sikap end,
        deskripsi    = case when q.perubahan ? 'deskripsi' then q.perubahan->'deskripsi'->>'baru' else deskripsi end,
        diisi_oleh   = public.saya()
       where assignment_id = q.assignment_id and semester = q.semester and student_id = q.student_id;
    else
      update utas_results set
        tajwid = case when q.perubahan ? 'tajwid' then (q.perubahan->'tajwid'->>'baru')::numeric else tajwid end,
        itqan  = case when q.perubahan ? 'itqan' then (q.perubahan->'itqan'->>'baru')::numeric else itqan end,
        diisi_oleh = public.saya()
       where id = q.utas_result_id returning * into r;
      select * into h from public._hitung_utas(r.academic_year_id, r.tajwid, r.itqan);
      update utas_results set nilai_akhir = h.nilai, huruf = h.huruf, tuntas = h.tuntas where id = r.id;
    end if;
  end if;
  update grade_change_requests set status = case when p_setuju then 'disetujui' else 'ditolak' end, diputus_oleh = public.saya(), diputus_pada = now(),
         catatan_putusan = nullif(trim(coalesce(p_catatan, '')), '')
   where id = q.id;
  v_ket := (select nama_lengkap from students where id = q.student_id);
  if q.diajukan_oleh is not null and q.diajukan_oleh is distinct from public.saya() then
    perform public.kirim_notifikasi(q.diajukan_oleh,
      'Permintaan ubah nilai ' || case when p_setuju then 'disetujui' else 'ditolak' end,
      'Nilai ' || v_ket || case when p_setuju then ' sudah diperbarui.' else '. Alasan: ' || trim(p_catatan) end,
      case when q.jenis = 'mapel' then '/guru-mapel/nilai/' || q.assignment_id else '/tahfizh/ujian' end, 'PencilLine', case when p_setuju then 'hijau' else 'merah' end);
  end if;
end $$;

-- Daftar permintaan ubah nilai (riwayat). Pengelola nilai: semua; panitia UTAS: permintaan UTAS; selain itu: milik sendiri.
create or replace function public.daftar_ubah_nilai(p_status text default null, p_assignment uuid default null, p_ta uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_ta uuid := coalesce(p_ta, (select id from academic_years where aktif)); v_kelola boolean := public.boleh_kelola_nilai(); v_panitia boolean := public.panitia_utas();
begin
  if public.saya() is null then raise exception 'Akun Anda belum aktif.'; end if;
  return jsonb_build_object('kelola', v_kelola, 'panitia', v_panitia,
    'menunggu', (select count(*) from grade_change_requests q where q.academic_year_id = v_ta and q.status = 'menunggu'
                  and (v_kelola or (q.jenis = 'utas' and v_panitia) or q.diajukan_oleh = public.saya())),
    'daftar', coalesce((select jsonb_agg(jsonb_build_object('id', q.id, 'jenis', q.jenis, 'semester', q.semester, 'status', q.status, 'perubahan', q.perubahan,
        'alasan', q.alasan, 'diajukan_pada', q.diajukan_pada, 'pengaju', pe.nama_lengkap, 'diputus_pada', q.diputus_pada, 'pemutus', pu.nama_lengkap,
        'catatan_putusan', q.catatan_putusan, 'student_id', s.id, 'nis', s.nis, 'nama', s.nama_lengkap, 'jenis_kelamin', s.jenis_kelamin,
        'assignment_id', q.assignment_id, 'utas_result_id', q.utas_result_id,
        'kelas', coalesce(g.nama, (select kg.nama from group_members km join student_groups kg on kg.id = km.group_id
                                    where km.student_id = s.id and kg.jenis = 'kelas' and kg.academic_year_id = q.academic_year_id order by km.selesai nulls first limit 1)),
        'mapel', case when q.jenis = 'utas' then 'UTAS (tahfizh)' else sb.nama end,
        'mode', case when q.jenis = 'mapel' then public._mode_tugas(q.assignment_id) end,
        'boleh_putus', q.status = 'menunggu' and (v_kelola or (q.jenis = 'utas' and v_panitia)),
        'boleh_batal', q.status = 'menunggu' and q.diajukan_oleh = public.saya())
        order by (q.status = 'menunggu') desc, q.diajukan_pada desc)
      from grade_change_requests q join students s on s.id = q.student_id
      left join employees pe on pe.id = q.diajukan_oleh left join employees pu on pu.id = q.diputus_oleh
      left join teaching_assignments t on t.id = q.assignment_id left join student_groups g on g.id = t.group_id left join subjects sb on sb.id = t.subject_id
     where q.academic_year_id = v_ta and (p_status is null or q.status = p_status) and (p_assignment is null or q.assignment_id = p_assignment)
       and (v_kelola or (q.jenis = 'utas' and v_panitia) or q.diajukan_oleh = public.saya()
            or (q.assignment_id is not null and exists (select 1 from teaching_assignments t2 where t2.id = q.assignment_id and t2.employee_id = public.saya())))), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------
-- C. REKAP PENILAIAN (PIMPINAN) DAN RINGKASAN BERANDA
-- ---------------------------------------------------------------------
create or replace function public.rekap_penilaian(p_semester smallint default null, p_ta uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_ta uuid := coalesce(p_ta, (select id from academic_years where aktif)); v_smt smallint; v_semua boolean; v_jenis text[];
begin
  if public.saya() is null then raise exception 'Akun Anda belum aktif.'; end if;
  v_semua := public.is_admin() or public.boleh_kelola_nilai() or public.boleh_atur_penilaian(null);
  v_jenis := array_remove(array[case when v_semua or public.boleh_atur_penilaian('sma') or public.pimpinan_unit('SMA') then 'sma' end,
                                case when v_semua or public.boleh_atur_penilaian('wustha') or public.pimpinan_unit('WUSTHA') then 'wustha' end,
                                case when v_semua or public.boleh_atur_penilaian('tahfizh') or public.pimpinan_unit('TAHFIZH') then 'tahfizh' end], null);
  if cardinality(v_jenis) = 0 then raise exception 'Rekap penilaian untuk pimpinan, pengatur penilaian, dan pengelola nilai.' using errcode = '42501'; end if;
  v_smt := coalesce(p_semester, (select semester from academic_years where id = v_ta), 1);
  return (
    with kel as materialized (
      select g.id, g.nama, g.jenjang, g.tingkat from student_groups g
       where g.academic_year_id = v_ta and g.jenis = 'kelas' and g.aktif and g.jenjang = any(v_jenis)),
    ang as materialized (
      select m.group_id, m.student_id from group_members m join students s on s.id = m.student_id
       where m.group_id in (select id from kel) and m.selesai is null and s.status = 'aktif'),
    tug as materialized (
      select t.id, t.group_id, t.employee_id, sb.nama mapel,
             (select count(*) from ang a where a.group_id = t.group_id) target,
             (select count(*) from public.nilai_mapel_ajar(t.id, v_smt) n where n.nilai is not null and n.student_id in (select a.student_id from ang a where a.group_id = t.group_id)) terisi,
             (select count(*) from grade_finals f where f.assignment_id = t.id and f.semester = v_smt and f.sikap is not null
                and f.student_id in (select a.student_id from ang a where a.group_id = t.group_id)) sikap
        from teaching_assignments t join subjects sb on sb.id = t.subject_id where t.group_id in (select id from kel))
    select jsonb_build_object('ta', v_ta, 'semester', v_smt, 'jenis', to_jsonb(v_jenis),
      'periode', coalesce((select jsonb_agg(jsonb_build_object('jenis', p.jenis, 'status', p.status, 'status_efektif', public.status_periode_efektif(v_ta, p.jenis, v_smt),
                    'batas_isi', p.batas_isi, 'tanggal_rapor', p.tanggal_rapor) order by p.jenis)
                  from grade_periods p where p.academic_year_id = v_ta and p.semester = v_smt and p.jenis = any(v_jenis)), '[]'::jsonb),
      'permintaan_menunggu', (select count(*) from grade_change_requests q where q.academic_year_id = v_ta and q.status = 'menunggu'),
      'kelas', coalesce((select jsonb_agg(jsonb_build_object('group_id', k.id, 'nama', k.nama, 'jenjang', k.jenjang, 'tingkat', k.tingkat,
            'wali', (select string_agg(e.nama_lengkap, ', ') from group_keepers gk join employees e on e.id = gk.employee_id where gk.group_id = k.id and (gk.sampai is null or gk.sampai >= public.hari_ini())),
            'santri', (select count(*) from ang a where a.group_id = k.id),
            'tugas', (select count(*) from tug t where t.group_id = k.id),
            'tugas_lengkap', (select count(*) from tug t where t.group_id = k.id and t.target > 0 and t.terisi >= t.target),
            'nilai_terisi', (select coalesce(sum(t.terisi), 0) from tug t where t.group_id = k.id),
            'nilai_target', (select coalesce(sum(t.target), 0) from tug t where t.group_id = k.id),
            'sikap', (select coalesce(sum(t.sikap), 0) from tug t where t.group_id = k.id),
            'catatan', (select count(*) from report_notes n where n.academic_year_id = v_ta and n.semester = v_smt and n.jenis = 'wali' and n.student_id in (select a.student_id from ang a where a.group_id = k.id)),
            'kokurikuler', (select count(*) from report_cocurricular c where c.academic_year_id = v_ta and c.semester = v_smt and c.dimensi <> '{}'::jsonb and c.student_id in (select a.student_id from ang a where a.group_id = k.id)),
            'pd', (select count(distinct x.student_id) from report_extracurricular x where x.academic_year_id = v_ta and x.semester = v_smt and x.nilai is not null and x.student_id in (select a.student_id from ang a where a.group_id = k.id)),
            'keputusan', case when v_smt = 2 then (select count(*) from report_decisions d where d.academic_year_id = v_ta and d.student_id in (select a.student_id from ang a where a.group_id = k.id)) end,
            'utas_final', (select count(*) from utas_results u where u.academic_year_id = v_ta and u.semester = v_smt and u.status = 'final' and u.student_id in (select a.student_id from ang a where a.group_id = k.id)))
          order by k.tingkat, k.nama) from kel k), '[]'::jsonb),
      'guru', coalesce((select jsonb_agg(x order by (x->>'kurang')::int desc, x->>'nama') from (
          select jsonb_build_object('employee_id', e.id, 'nama', e.nama_lengkap, 'tugas', count(*), 'terisi', sum(t.terisi), 'target', sum(t.target), 'kurang', sum(greatest(t.target - t.terisi, 0)),
                 'belum', jsonb_agg(jsonb_build_object('assignment_id', t.id, 'mapel', t.mapel, 'kelas', (select nama from kel where id = t.group_id), 'terisi', t.terisi, 'target', t.target)
                                    order by t.mapel) filter (where t.terisi < t.target)) x
            from tug t join employees e on e.id = t.employee_id group by e.id, e.nama_lengkap) q), '[]'::jsonb),
      'utas', case when 'tahfizh' = any(v_jenis) then (select jsonb_build_object('peserta', count(*), 'dinilai', count(*) filter (where u.nilai_akhir is not null),
                    'final', count(*) filter (where u.status = 'final'), 'remedial', count(*) filter (where u.tuntas = false))
                  from utas_results u where u.academic_year_id = v_ta and u.semester = v_smt) end,
      'ekskul', coalesce((select jsonb_agg(jsonb_build_object('group_id', g.id, 'nama', g.nama,
            'pembina', (select string_agg(e.nama_lengkap, ', ') from group_keepers gk join employees e on e.id = gk.employee_id where gk.group_id = g.id and (gk.sampai is null or gk.sampai >= public.hari_ini())),
            'santri', (select count(*) from group_members m join students s on s.id = m.student_id where m.group_id = g.id and m.selesai is null and s.status = 'aktif'),
            'terisi', (select count(*) from report_extracurricular x where x.group_id = g.id and x.academic_year_id = v_ta and x.semester = v_smt and x.nilai is not null)) order by g.nama)
          from student_groups g where g.academic_year_id = v_ta and g.jenis = 'ekskul' and g.aktif), '[]'::jsonb))
  );
end $$;

-- Ringkasan penilaian untuk kartu beranda (apa yang perlu dikerjakan pengguna ini pada semester berjalan)
create or replace function public.ringkas_penilaian_saya()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_ta uuid := (select id from academic_years where aktif); v_smt smallint; v_saya uuid := public.saya();
begin
  if v_saya is null or v_ta is null then return null; end if;
  v_smt := coalesce((select semester from academic_years where id = v_ta), 1);
  return (
    with tug as materialized (
      select t.id, g.jenjang, (select count(*) from group_members m join students s on s.id = m.student_id where m.group_id = t.group_id and m.selesai is null and s.status = 'aktif') target,
             (select count(*) from public.nilai_mapel_ajar(t.id, v_smt) n where n.nilai is not null) terisi
        from teaching_assignments t join student_groups g on g.id = t.group_id where t.academic_year_id = v_ta and t.employee_id = v_saya),
    wali as materialized (select g.id, g.nama, g.jenjang from student_groups g where g.id in (select public.kelompok_saya()) and g.jenis = 'kelas')
    select jsonb_build_object('semester', v_smt,
      'periode', coalesce((select jsonb_agg(jsonb_build_object('jenis', p.jenis, 'status', public.status_periode_efektif(v_ta, p.jenis, v_smt), 'batas_isi', p.batas_isi))
                  from grade_periods p where p.academic_year_id = v_ta and p.semester = v_smt), '[]'::jsonb),
      'tugas', (select count(*) from tug), 'tugas_lengkap', (select count(*) from tug where target > 0 and terisi >= target),
      'nilai_kurang', (select coalesce(sum(greatest(target - terisi, 0)), 0) from tug),
      'wali', coalesce((select jsonb_agg(jsonb_build_object('group_id', w.id, 'nama', w.nama,
                  'santri', (select count(*) from group_members m join students s on s.id = m.student_id where m.group_id = w.id and m.selesai is null and s.status = 'aktif'),
                  'catatan', (select count(*) from report_notes n join group_members m on m.student_id = n.student_id and m.group_id = w.id and m.selesai is null
                               where n.academic_year_id = v_ta and n.semester = v_smt and n.jenis = 'wali'))) from wali w), '[]'::jsonb),
      'utas_draf', (select count(*) from utas_results u where u.academic_year_id = v_ta and u.semester = v_smt and u.penguji_id = v_saya and u.status = 'draf'),
      'pd_kurang', (select count(*) from group_members m join student_groups g on g.id = m.group_id join students s on s.id = m.student_id
                     where g.id in (select public.kelompok_saya()) and g.jenis = 'ekskul' and m.selesai is null and s.status = 'aktif'
                       and not exists (select 1 from report_extracurricular x where x.group_id = g.id and x.student_id = m.student_id and x.academic_year_id = v_ta and x.semester = v_smt and x.nilai is not null)),
      'permintaan_saya', (select count(*) from grade_change_requests q where q.diajukan_oleh = v_saya and q.status = 'menunggu'),
      'permintaan_menunggu', case when public.boleh_kelola_nilai() or public.panitia_utas() then
                  (select count(*) from grade_change_requests q where q.academic_year_id = v_ta and q.status = 'menunggu'
                    and (public.boleh_kelola_nilai() or q.jenis = 'utas')) end,
      'rekap', (public.hak_penilaian()->>'menu')::boolean)
  );
end $$;

-- ---------------------------------------------------------------------
-- HAK EKSEKUSI
-- ---------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array['status_periode_efektif(uuid,text,smallint)','ajukan_ubah_nilai(jsonb)','batal_ubah_nilai(uuid)','putuskan_ubah_nilai(uuid,boolean,text)',
      'daftar_ubah_nilai(text,uuid,uuid)','rekap_penilaian(smallint,uuid)','ringkas_penilaian_saya()'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 5 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select '1. Kunci periode menurut batas pengisian' as pemeriksaan,
       case when exists (select 1 from pg_proc where proname = 'status_periode_efektif') then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Tabel permintaan ubah nilai dengan RLS',
       case when exists (select 1 from pg_tables where schemaname = 'public' and tablename = 'grade_change_requests' and rowsecurity) then 'Sesuai' else 'Periksa' end
union all
select '3. Kolom koreksi nilai rapor', case when exists (select 1 from information_schema.columns where table_name = 'grade_finals' and column_name = 'koreksi') then 'Sesuai' else 'Periksa' end
union all
select '4. Fungsi permintaan, rekap, dan ringkasan (6)',
       case when (select count(*) from pg_proc where proname in ('ajukan_ubah_nilai','batal_ubah_nilai','putuskan_ubah_nilai','daftar_ubah_nilai','rekap_penilaian','ringkas_penilaian_saya')) = 6
            then 'Sesuai' else 'Periksa' end
union all
select '5. Migrasi 8600 sudah terpasang', case when exists (select 1 from pg_proc where proname = 'data_rapor') then 'Sesuai' else 'Periksa: jalankan 8600 dulu' end;
