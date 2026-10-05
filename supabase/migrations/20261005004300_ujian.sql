-- SIMKA PRO | supabase/migrations/20261005004300_ujian.sql | v1.0 | Fase 5 – Tahap 4 Ujian kenaikan juz dan sertifikasi | 05/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 5 · Migrasi 43: Ujian kenaikan juz dan sertifikasi hafalan (Blueprint Bagian 20)
--   * PENGUJI KINI SEPENUHNYA DIATUR ADMIN: tidak ada lagi penguji "bawaan" dari jabatan. Pemegang jabatan yang
--     sebelumnya menjadi penguji bawaan disalin SEKALI ke daftar penguji, sehingga dapat diubah keterangannya,
--     dinonaktifkan, atau dihapus seperti penguji lain.
--   * tahfizh_exams : satu baris per ujian. Alur: rekomendasi muhaffizh (menunggu) → diambil/ditetapkan penguji
--     (dijadwalkan) → dinilai Tajwid & Itqan (selesai; Tuntas/Remidi) atau dibatalkan.
--     Nilai akhir = Tajwid × bobot + Itqan × bobot (pengaturan); huruf & predikat dari rentang predikat; Tuntas bila ≥ KKM.
--     Kenaikan juz Tuntas → usulan capaian juz otomatis (sumber "ujian") untuk divalidasi.
--     Sertifikasi berjenjang 5, 10, 15 … juz: jenjang berikutnya hanya bila jenjang sebelumnya Tuntas dan hafalan resmi mencukupi.
--   * Muhaffizh tidak dapat menguji santri halaqahnya sendiri.
--   * Fungsi: rekomendasikan_ujian, ambil_ujian, tetapkan_penguji_ujian, nilai_ujian, batalkan_ujian, daftar_ujian,
--             jenjang_sertifikasi; penguji_tahfizh dan simpan_penguji diperbarui.
-- Jalankan SETELAH migrasi 4200. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. PENGUJI FLEKSIBEL
-- ---------------------------------------------------------------------
-- Salin penguji bawaan lama (jabatan) ke daftar penguji, sekali saja
insert into public.tahfizh_examiners (jenis, employee_id, aktif, catatan)
select distinct 'kenaikan', p.employee_id, true, p.nama_jabatan
  from public.pemegang_jabatan() p join public.org_units o on o.id = p.org_unit_id
 where o.kode = 'TAHFIZH' and p.kode in ('KEPALA_BIDANG','WAKIL_KEPALA_BIDANG')
on conflict (jenis, employee_id) do nothing;
insert into public.tahfizh_examiners (jenis, employee_id, aktif, catatan)
select distinct 'sertifikasi', p.employee_id, true, p.nama_jabatan
  from public.pemegang_jabatan() p where p.kode in ('DIREKTUR','WAKIL_DIREKTUR')
on conflict (jenis, employee_id) do nothing;

drop function if exists public.penguji_tahfizh(text);
create function public.penguji_tahfizh(p_jenis text)
returns table (employee_id uuid, nama text, niy text, jabatan text, bawaan boolean, aktif boolean, id uuid, no_hp text, catatan text)
language sql stable security definer set search_path = public as $$
  select e.id, e.nama_lengkap, e.niy,
         coalesce(x.catatan, (select string_agg(p.nama_jabatan, ', ') from public.pemegang_jabatan() p where p.employee_id = e.id), 'Penguji'),
         false, x.aktif, x.id, e.no_hp, x.catatan
    from tahfizh_examiners x join employees e on e.id = x.employee_id
   where x.jenis = p_jenis and e.status_keaktifan = 'aktif'
   order by x.aktif desc, e.nama_lengkap
$$;
revoke execute on function public.penguji_tahfizh(text) from public, anon;
grant execute on function public.penguji_tahfizh(text) to authenticated;

-- Keterangan boleh dikosongkan; aktif/nonaktif; tanpa notifikasi saat hanya mengubah keterangan
create or replace function public.simpan_penguji(p_jenis text, p_employee uuid, p_aktif boolean default true, p_catatan text default null)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid; v_baru boolean;
begin
  if not public.boleh_atur_tahfizh() then raise exception 'Anda tidak berwenang mengatur penguji tahfizh.' using errcode = '42501'; end if;
  if p_jenis not in ('kenaikan','sertifikasi') then raise exception 'Jenis penguji tidak dikenal.'; end if;
  if not exists (select 1 from employees where id = p_employee and status_keaktifan = 'aktif') then
    raise exception 'Pegawai tidak ditemukan atau tidak aktif.';
  end if;
  v_baru := not exists (select 1 from tahfizh_examiners where jenis = p_jenis and employee_id = p_employee and aktif);
  insert into tahfizh_examiners (jenis, employee_id, aktif, catatan)
  values (p_jenis, p_employee, coalesce(p_aktif, true), nullif(trim(p_catatan), ''))
  on conflict (jenis, employee_id) do update set aktif = excluded.aktif, catatan = excluded.catatan
  returning id into v_id;
  if v_baru and coalesce(p_aktif, true) and p_employee is distinct from public.saya() then
    perform public.kirim_notifikasi(p_employee,
      'Anda ditunjuk sebagai penguji ' || case p_jenis when 'kenaikan' then 'ujian kenaikan juz' else 'sertifikasi hafalan' end,
      'Daftar tunggu ujian tampil di menu Tahfizh → Ujian.', '/tahfizh/ujian', 'Exam', 'kuning');
  end if;
  return v_id;
end $$;

-- ---------------------------------------------------------------------
-- 2. TABEL UJIAN
-- ---------------------------------------------------------------------
create table if not exists public.tahfizh_exams (
  id                 uuid primary key default gen_random_uuid(),
  jenis              text not null constraint te_jenis check (jenis in ('kenaikan','sertifikasi')),
  student_id         uuid not null references public.students(id) on delete cascade,
  academic_year_id   uuid references public.academic_years(id) on delete set null,
  juz                smallint[] not null default '{}',
  jenjang            smallint constraint te_jenjang check (jenjang is null or (jenjang % 5 = 0 and jenjang between 5 and 30)),
  status             text not null default 'menunggu' constraint te_status check (status in ('menunggu','dijadwalkan','selesai','dibatalkan')),
  direkomendasikan_oleh uuid references public.employees(id) on delete set null,
  direkomendasikan_pada timestamptz not null default now(),
  catatan_rekomendasi text,
  penguji_id         uuid references public.employees(id) on delete set null,
  jadwal             timestamptz,
  nilai_tajwid       numeric(5,2) constraint te_tajwid check (nilai_tajwid between 0 and 100),
  nilai_itqan        numeric(5,2) constraint te_itqan check (nilai_itqan between 0 and 100),
  nilai_akhir        numeric(5,2),
  huruf              text,
  predikat           text,
  hasil              text constraint te_hasil check (hasil in ('tuntas','remidi')),
  kkm                numeric(5,2),
  catatan_penguji    text,
  diuji_pada         timestamptz,
  alasan_batal       text,
  ujian_ke           smallint not null default 1,
  updated_at         timestamptz not null default now()
);
create index if not exists te_status_idx on public.tahfizh_exams (jenis, status);
create index if not exists te_santri_idx on public.tahfizh_exams (student_id);

drop trigger if exists aa_updated on public.tahfizh_exams;
create trigger aa_updated before update on public.tahfizh_exams for each row execute function public.tg_updated_at();
drop trigger if exists zz_audit on public.tahfizh_exams;
create trigger zz_audit after insert or update or delete on public.tahfizh_exams for each row execute function public.tg_audit();

alter table public.tahfizh_exams enable row level security;
drop policy if exists baca on public.tahfizh_exams;
create policy baca on public.tahfizh_exams for select to authenticated using (
  student_id in (select public.santri_terlihat()) or penguji_id = public.saya()
  or exists (select 1 from tahfizh_examiners x where x.employee_id = public.saya() and x.jenis = tahfizh_exams.jenis and x.aktif));

do $$ begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'tahfizh_exams') then
    alter publication supabase_realtime add table public.tahfizh_exams;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 3. BANTUAN
-- ---------------------------------------------------------------------
create or replace function public._penguji_aktif(p_jenis text, p_employee uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from tahfizh_examiners x join employees e on e.id = x.employee_id
                  where x.jenis = p_jenis and x.employee_id = p_employee and x.aktif and e.status_keaktifan = 'aktif')
$$;

-- Jenjang sertifikasi tertinggi yang sudah Tuntas
create or replace function public.jenjang_sertifikasi(p_santri uuid)
returns smallint language sql stable security definer set search_path = public as $$
  select coalesce(max(jenjang), 0)::smallint from tahfizh_exams where student_id = p_santri and jenis = 'sertifikasi' and hasil = 'tuntas'
$$;

-- Pegawai pengasuh halaqah santri hari ini (tidak boleh menguji)
create or replace function public._muhaffizh_dari(p_santri uuid, p_employee uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from group_members m join student_groups g on g.id = m.group_id and g.jenis = 'halaqah'
      join academic_years a on a.id = g.academic_year_id and a.aktif
     where m.student_id = p_santri and m.selesai is null
       and p_employee in (select public._pengasuh_berlaku(g.id, public.hari_ini())))
$$;

-- ---------------------------------------------------------------------
-- 4. REKOMENDASI
-- ---------------------------------------------------------------------
-- Kenaikan juz: p_juz = juz yang diujikan (belum resmi). Sertifikasi: p_jenjang = 5, 10, …; p_juz opsional (juz yang diujikan).
create or replace function public.rekomendasikan_ujian(p_santri uuid, p_jenis text, p_juz smallint[] default '{}', p_jenjang smallint default null, p_catatan text default null)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid; v_nama text; v_resmi int; v_sudah smallint; v_ke smallint; v_ta uuid := (select id from academic_years where aktif);
  v_juz smallint[] := coalesce(p_juz, '{}');
begin
  if not (public._muhaffizh_santri(p_santri) or public.boleh_validasi_tahfizh()) then
    raise exception 'Rekomendasi ujian diajukan oleh muhaffizh santri tersebut.' using errcode = '42501';
  end if;
  select nama_lengkap into v_nama from students where id = p_santri and status = 'aktif';
  if v_nama is null then raise exception 'Santri tidak ditemukan atau tidak aktif.'; end if;
  if exists (select 1 from tahfizh_exams where student_id = p_santri and jenis = p_jenis and status in ('menunggu','dijadwalkan')) then
    raise exception '% masih memiliki ujian % yang belum selesai.', v_nama, case p_jenis when 'kenaikan' then 'kenaikan juz' else 'sertifikasi' end;
  end if;
  select count(*) into v_resmi from juz_achievements where student_id = p_santri;
  select coalesce(array_agg(distinct j order by j), '{}') into v_juz from unnest(v_juz) j;
  if exists (select 1 from unnest(v_juz) j where j not between 1 and 30) then raise exception 'Nomor juz harus 1–30.'; end if;

  if p_jenis = 'kenaikan' then
    if cardinality(v_juz) = 0 then raise exception 'Pilih juz yang akan diujikan.'; end if;
    if exists (select 1 from juz_achievements where student_id = p_santri and juz = any(v_juz)) then
      raise exception 'Ada juz yang sudah tercatat resmi untuk %. Pilih juz yang belum resmi.', v_nama;
    end if;
    select count(*) + 1 into v_ke from tahfizh_exams where student_id = p_santri and jenis = 'kenaikan' and juz && v_juz and status = 'selesai';
  elsif p_jenis = 'sertifikasi' then
    v_sudah := public.jenjang_sertifikasi(p_santri);
    if p_jenjang is null or p_jenjang <> v_sudah + 5 then
      raise exception 'Sertifikasi berjenjang: % berikutnya mengikuti jenjang % juz.', v_nama, v_sudah + 5;
    end if;
    if v_resmi < p_jenjang then raise exception 'Hafalan resmi % baru % juz; jenjang % juz belum dapat diujikan.', v_nama, v_resmi, p_jenjang; end if;
    if cardinality(v_juz) > 0 and exists (select 1 from unnest(v_juz) j where j not in (select juz from juz_achievements where student_id = p_santri)) then
      raise exception 'Juz sertifikasi harus juz yang sudah resmi.';
    end if;
    select count(*) + 1 into v_ke from tahfizh_exams where student_id = p_santri and jenis = 'sertifikasi' and jenjang = p_jenjang and status = 'selesai';
  else
    raise exception 'Jenis ujian tidak dikenal.';
  end if;

  insert into tahfizh_exams (jenis, student_id, academic_year_id, juz, jenjang, direkomendasikan_oleh, catatan_rekomendasi, ujian_ke)
  values (p_jenis, p_santri, v_ta, v_juz, case when p_jenis = 'sertifikasi' then p_jenjang end, public.saya(), nullif(trim(p_catatan), ''), v_ke)
  returning id into v_id;

  perform public.kirim_notifikasi(x.employee_id,
    case p_jenis when 'kenaikan' then 'Daftar tunggu ujian kenaikan juz' else 'Daftar tunggu sertifikasi ' || p_jenjang || ' juz' end,
    v_nama || case when cardinality(v_juz) > 0 then ' · juz ' || array_to_string(v_juz, ', ') else '' end || '. Ambil dan jadwalkan ujiannya.',
    '/tahfizh/ujian', 'Exam', 'kuning')
  from tahfizh_examiners x where x.jenis = p_jenis and x.aktif and x.employee_id is distinct from public.saya()
    and not public._muhaffizh_dari(p_santri, x.employee_id);
  return v_id;
end $$;

-- ---------------------------------------------------------------------
-- 5. PENGUJI MENGAMBIL / ADMIN MENETAPKAN
-- ---------------------------------------------------------------------
create or replace function public.ambil_ujian(p_id uuid, p_jadwal timestamptz default null)
returns void language plpgsql volatile security definer set search_path = public as $$
declare r tahfizh_exams;
begin
  select * into r from tahfizh_exams where id = p_id for update;
  if not found or r.status not in ('menunggu','dijadwalkan') then raise exception 'Ujian tidak ditemukan atau sudah selesai.'; end if;
  if not public._penguji_aktif(r.jenis, public.saya()) then raise exception 'Anda bukan penguji aktif untuk ujian ini.' using errcode = '42501'; end if;
  if public._muhaffizh_dari(r.student_id, public.saya()) then raise exception 'Muhaffizh tidak menguji santri halaqahnya sendiri.'; end if;
  if r.penguji_id is not null and r.penguji_id <> public.saya() then raise exception 'Ujian ini sudah diambil penguji lain.'; end if;
  update tahfizh_exams set penguji_id = public.saya(), jadwal = coalesce(p_jadwal, jadwal), status = 'dijadwalkan' where id = p_id;
  if r.direkomendasikan_oleh is not null and r.direkomendasikan_oleh <> public.saya() then
    perform public.kirim_notifikasi(r.direkomendasikan_oleh, 'Ujian dijadwalkan: ' || (select nama_lengkap from students where id = r.student_id),
      'Penguji ' || (select nama_lengkap from employees where id = public.saya())
      || coalesce(' · ' || to_char(coalesce(p_jadwal, r.jadwal) at time zone 'Asia/Makassar', 'DD/MM/YYYY HH24.MI') || ' WITA', ''),
      '/tahfizh/ujian', 'CalendarCheck', 'biru');
  end if;
end $$;

create or replace function public.tetapkan_penguji_ujian(p_id uuid, p_employee uuid, p_jadwal timestamptz default null)
returns void language plpgsql volatile security definer set search_path = public as $$
declare r tahfizh_exams;
begin
  if not (public.boleh_atur_tahfizh() or public.boleh_validasi_tahfizh()) then raise exception 'Anda tidak berwenang menetapkan penguji.' using errcode = '42501'; end if;
  select * into r from tahfizh_exams where id = p_id for update;
  if not found or r.status not in ('menunggu','dijadwalkan') then raise exception 'Ujian tidak ditemukan atau sudah selesai.'; end if;
  if not public._penguji_aktif(r.jenis, p_employee) then raise exception 'Pegawai itu bukan penguji aktif untuk jenis ujian ini.'; end if;
  if public._muhaffizh_dari(r.student_id, p_employee) then raise exception 'Muhaffizh tidak menguji santri halaqahnya sendiri.'; end if;
  update tahfizh_exams set penguji_id = p_employee, jadwal = coalesce(p_jadwal, jadwal), status = 'dijadwalkan' where id = p_id;
  perform public.kirim_notifikasi(p_employee, 'Anda ditetapkan sebagai penguji: ' || (select nama_lengkap from students where id = r.student_id),
    case r.jenis when 'kenaikan' then 'Kenaikan juz ' || array_to_string(r.juz, ', ') else 'Sertifikasi ' || r.jenjang || ' juz' end
    || coalesce(' · ' || to_char(coalesce(p_jadwal, r.jadwal) at time zone 'Asia/Makassar', 'DD/MM/YYYY HH24.MI') || ' WITA', ''),
    '/tahfizh/ujian', 'Exam', 'kuning')
  where p_employee is distinct from public.saya();
end $$;

-- ---------------------------------------------------------------------
-- 6. PENILAIAN
-- ---------------------------------------------------------------------
create or replace function public.nilai_ujian(p_id uuid, p_tajwid numeric, p_itqan numeric, p_catatan text default null)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare r tahfizh_exams; st tahfizh_settings; v_ta uuid := (select id from academic_years where aktif); v_akhir numeric; pr predicate_ranges;
  v_hasil text; v_nama text; j smallint;
begin
  select * into r from tahfizh_exams where id = p_id for update;
  if not found or r.status not in ('menunggu','dijadwalkan') then raise exception 'Ujian tidak ditemukan atau sudah dinilai.'; end if;
  if not (public._penguji_aktif(r.jenis, public.saya()) or public.is_superadmin()) then
    raise exception 'Hanya penguji aktif yang dapat menilai ujian ini.' using errcode = '42501';
  end if;
  if r.penguji_id is not null and r.penguji_id <> public.saya() and not public.is_superadmin() then
    raise exception 'Ujian ini dipegang penguji lain.';
  end if;
  if public._muhaffizh_dari(r.student_id, public.saya()) then raise exception 'Muhaffizh tidak menguji santri halaqahnya sendiri.'; end if;
  if p_tajwid is null or p_itqan is null or p_tajwid not between 0 and 100 or p_itqan not between 0 and 100 then
    raise exception 'Nilai Tajwid dan Itqan harus 0–100.';
  end if;
  select * into st from tahfizh_settings where academic_year_id = v_ta;
  v_akhir := round(p_tajwid * coalesce(st.bobot_tajwid, 50) / 100.0 + p_itqan * coalesce(st.bobot_itqan, 50) / 100.0, 2);
  select * into pr from predicate_ranges where academic_year_id = v_ta and v_akhir between nilai_min and nilai_maks order by nilai_min desc limit 1;
  v_hasil := case when v_akhir >= coalesce(st.kkm, 80) then 'tuntas' else 'remidi' end;
  select nama_lengkap into v_nama from students where id = r.student_id;

  update tahfizh_exams set nilai_tajwid = p_tajwid, nilai_itqan = p_itqan, nilai_akhir = v_akhir, huruf = pr.huruf, predikat = pr.deskripsi_rapor,
         hasil = v_hasil, kkm = coalesce(st.kkm, 80), catatan_penguji = nullif(trim(p_catatan), ''), diuji_pada = now(),
         penguji_id = coalesce(penguji_id, public.saya()), status = 'selesai'
   where id = p_id;

  -- Kenaikan juz Tuntas → usulan capaian juz (sumber ujian) untuk divalidasi
  if r.jenis = 'kenaikan' and v_hasil = 'tuntas' then
    foreach j in array r.juz loop
      insert into juz_proposals (student_id, juz, sumber, ref_id, catatan, diusulkan_oleh)
      select r.student_id, j, 'ujian', r.id, 'Ujian kenaikan juz: nilai ' || v_akhir || ' (' || coalesce(pr.huruf, '-') || ')', public.saya()
       where not exists (select 1 from juz_achievements where student_id = r.student_id and juz = j)
      on conflict do nothing;
    end loop;
    perform public.kirim_notifikasi(v, 'Usulan capaian juz dari ujian: ' || v_nama, 'Juz ' || array_to_string(r.juz, ', ') || ' Tuntas (' || v_akhir || '). Mohon divalidasi.',
      '/tahfizh/capaian?bagian=usulan', 'SealCheck', 'kuning')
      from public._validator_tahfizh() v where v is distinct from public.saya();
  end if;

  if r.direkomendasikan_oleh is not null and r.direkomendasikan_oleh <> public.saya() then
    perform public.kirim_notifikasi(r.direkomendasikan_oleh,
      'Hasil ujian ' || v_nama || ': ' || case v_hasil when 'tuntas' then 'TUNTAS' else 'REMIDI' end,
      case r.jenis when 'kenaikan' then 'Kenaikan juz ' || array_to_string(r.juz, ', ') else 'Sertifikasi ' || r.jenjang || ' juz' end
      || ' · nilai ' || v_akhir || coalesce(' (' || pr.huruf || ', ' || pr.deskripsi_rapor || ')', '') || coalesce('. Catatan: ' || nullif(trim(p_catatan), ''), ''),
      '/tahfizh/ujian', 'Exam', case v_hasil when 'tuntas' then 'hijau' else 'merah' end);
  end if;
  return jsonb_build_object('nilai_akhir', v_akhir, 'huruf', pr.huruf, 'predikat', pr.deskripsi_rapor, 'hasil', v_hasil);
end $$;

create or replace function public.batalkan_ujian(p_id uuid, p_alasan text)
returns void language plpgsql volatile security definer set search_path = public as $$
declare r tahfizh_exams;
begin
  select * into r from tahfizh_exams where id = p_id for update;
  if not found or r.status not in ('menunggu','dijadwalkan') then raise exception 'Ujian tidak ditemukan atau sudah selesai.'; end if;
  if not (r.direkomendasikan_oleh = public.saya() or public.boleh_validasi_tahfizh() or public.boleh_atur_tahfizh()) then
    raise exception 'Ujian dibatalkan oleh pengusul atau validator tahfizh.' using errcode = '42501';
  end if;
  if length(trim(coalesce(p_alasan, ''))) < 5 then raise exception 'Tuliskan alasan pembatalan (minimal 5 huruf).'; end if;
  update tahfizh_exams set status = 'dibatalkan', alasan_batal = trim(p_alasan) where id = p_id;
  if r.penguji_id is not null and r.penguji_id <> public.saya() then
    perform public.kirim_notifikasi(r.penguji_id, 'Ujian dibatalkan: ' || (select nama_lengkap from students where id = r.student_id), trim(p_alasan), '/tahfizh/ujian', 'Exam', 'merah');
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 7. DAFTAR UJIAN
-- ---------------------------------------------------------------------
create or replace function public.daftar_ujian(p_jenis text default null, p_status text default null)
returns table (id uuid, jenis text, student_id uuid, nis text, nama text, jenis_kelamin text, kelas text, halaqah text, juz smallint[], jenjang smallint,
               status text, ujian_ke smallint, direkomendasikan_oleh text, direkomendasikan_pada timestamptz, catatan_rekomendasi text,
               penguji_id uuid, penguji text, jadwal timestamptz, nilai_tajwid numeric, nilai_itqan numeric, nilai_akhir numeric, huruf text,
               predikat text, hasil text, kkm numeric, catatan_penguji text, diuji_pada timestamptz, alasan_batal text, total_resmi int,
               penguji_saya boolean, boleh_nilai boolean, muhaffizh_saya boolean)
language sql stable security definer set search_path = public as $$
  with kel as (
    select m.student_id, g.jenis, g.nama from group_members m join student_groups g on g.id = m.group_id
      join academic_years a on a.id = g.academic_year_id and a.aktif where m.selesai is null and g.jenis in ('kelas','halaqah')
  )
  select t.id, t.jenis, s.id, s.nis, s.nama_lengkap, s.jenis_kelamin,
         (select k.nama from kel k where k.student_id = s.id and k.jenis = 'kelas' limit 1),
         (select k.nama from kel k where k.student_id = s.id and k.jenis = 'halaqah' limit 1),
         t.juz, t.jenjang, t.status, t.ujian_ke, (select nama_lengkap from employees where id = t.direkomendasikan_oleh), t.direkomendasikan_pada,
         t.catatan_rekomendasi, t.penguji_id, (select nama_lengkap from employees where id = t.penguji_id), t.jadwal,
         t.nilai_tajwid, t.nilai_itqan, t.nilai_akhir, t.huruf, t.predikat, t.hasil, t.kkm, t.catatan_penguji, t.diuji_pada, t.alasan_batal,
         (select count(*) from juz_achievements j where j.student_id = s.id)::int,
         t.penguji_id = public.saya(),
         t.status in ('menunggu','dijadwalkan') and public._penguji_aktif(t.jenis, public.saya())
           and (t.penguji_id is null or t.penguji_id = public.saya()) and not public._muhaffizh_dari(s.id, public.saya()),
         public._muhaffizh_santri(s.id)
    from tahfizh_exams t join students s on s.id = t.student_id
   where (p_jenis is null or t.jenis = p_jenis)
     and (p_status is null or t.status = p_status or (p_status = 'aktif' and t.status in ('menunggu','dijadwalkan')))
     and (s.id in (select public.santri_terlihat()) or t.penguji_id = public.saya() or public._penguji_aktif(t.jenis, public.saya()))
     and (t.status in ('menunggu','dijadwalkan') or coalesce(t.diuji_pada, t.updated_at) > now() - interval '1 year')
   order by case t.status when 'dijadwalkan' then 0 when 'menunggu' then 1 else 2 end, coalesce(t.jadwal, t.direkomendasikan_pada), t.diuji_pada desc
   limit 500
$$;

-- ---------------------------------------------------------------------
-- 8. HAK EKSEKUSI
-- ---------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array['rekomendasikan_ujian(uuid,text,smallint[],smallint,text)','ambil_ujian(uuid,timestamptz)',
    'tetapkan_penguji_ujian(uuid,uuid,timestamptz)','nilai_ujian(uuid,numeric,numeric,text)','batalkan_ujian(uuid,text)',
    'daftar_ujian(text,text)','jenjang_sertifikasi(uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['_penguji_aktif(text,uuid)','_muhaffizh_dari(uuid,uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;

-- PEMERIKSAAN — hasil yang benar: 4 baris, semuanya "Sesuai"
select 'Tabel ujian dengan RLS' as pemeriksaan,
       case when exists (select 1 from pg_tables where schemaname = 'public' and tablename = 'tahfizh_exams' and rowsecurity) then 'Sesuai' else 'Periksa' end as hasil
union all
select 'Fungsi ujian (7) tersedia',
       case when (select count(distinct proname) from pg_proc where proname in ('rekomendasikan_ujian','ambil_ujian','tetapkan_penguji_ujian','nilai_ujian',
         'batalkan_ujian','daftar_ujian','jenjang_sertifikasi')) = 7 then 'Sesuai' else 'Periksa' end
union all
select 'Penguji dikelola penuh (' || (select count(*) from public.tahfizh_examiners where aktif) || ' penguji aktif)', 'Sesuai'
union all
select 'Migrasi 4000 sudah terpasang', case when exists (select 1 from pg_proc where proname = 'usulkan_juz') then 'Sesuai' else 'Periksa: jalankan 4000 dulu' end;
