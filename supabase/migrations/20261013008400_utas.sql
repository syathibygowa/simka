-- SIMKA PRO | supabase/migrations/20261013008400_utas.sql | v1.0 | Fase 12 – Tahap 3 Ujian Tahfizh Akhir Semester (UTAS) | 13/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 12 · Migrasi 84: Ujian Tahfizh Akhir Semester (SOP UTAS pondok)
--   * utas_examiners : penguji UTAS per kelas per semester (diatur panitia = admin/superadmin/pengatur rapor tahfizh)
--   * utas_results   : peserta UTAS per semester: kelas, penguji, juz diujikan, Tajwid, Itqan, nilai akhir, predikat,
--                      tuntas (≥ KKM UTAS), status draf/final
--   * Juz diujikan otomatis: N juz resmi terakhir yang dicapai (N = 5 SMA, 3 Wustha, dapat diatur di Ketentuan rapor
--     Tahfizh); bila capaian semester kurang, otomatis ikut hafalan semester sebelumnya; bila total hafalan kurang dari N,
--     semua hafalan diujikan. Penguji/panitia dapat mengubah.
--   * Nilai akhir = Tajwid × bobot + Itqan × bobot (Ketentuan Tahfizh, bawaan 50/50 = (Tajwid + Itqan) ÷ 2)
--   * Penguji mengisi nilai lalu mengirim (final). Setelah final hanya panitia yang dapat mengubah/membuka kembali.
--   * Hasil UTAS menjadi dasar nilai rapor tahfizh dan bagian/mapel tahfizh rapor sekolah.
--   * Fungsi: hak_utas, juz_utas, data_utas, simpan_penguji_utas, bagi_peserta_utas, pindah_penguji_utas,
--             simpan_nilai_utas, buka_nilai_utas, hapus_peserta_utas
-- Jalankan SETELAH migrasi 8300. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TABEL
-- ---------------------------------------------------------------------
create table if not exists public.utas_examiners (
  academic_year_id  uuid not null references public.academic_years(id) on delete cascade,
  semester          smallint not null constraint ue_semester check (semester in (1,2)),
  group_id          uuid not null references public.student_groups(id) on delete cascade,
  employee_id       uuid not null references public.employees(id) on delete cascade,
  created_at        timestamptz not null default now(),
  primary key (academic_year_id, semester, group_id, employee_id)
);

create table if not exists public.utas_results (
  id                uuid primary key default gen_random_uuid(),
  academic_year_id  uuid not null references public.academic_years(id) on delete cascade,
  semester          smallint not null constraint ur_semester check (semester in (1,2)),
  student_id        uuid not null references public.students(id) on delete cascade,
  group_id          uuid references public.student_groups(id) on delete set null,
  penguji_id        uuid references public.employees(id) on delete set null,
  juz               smallint[] not null default '{}',
  total_juz         smallint,                       -- total hafalan resmi saat ujian
  tajwid            numeric(5,2) constraint ur_tajwid check (tajwid between 0 and 100),
  itqan             numeric(5,2) constraint ur_itqan check (itqan between 0 and 100),
  nilai_akhir       numeric(5,2),
  huruf             text,
  tuntas            boolean,
  status            text not null default 'draf' constraint ur_status check (status in ('draf','final')),
  catatan           text,
  diuji_pada        date,
  diisi_oleh        uuid references public.employees(id) on delete set null,
  updated_at        timestamptz not null default now(),
  constraint ur_unik unique (academic_year_id, semester, student_id)
);
create index if not exists utas_results_penguji_idx on public.utas_results (penguji_id, academic_year_id, semester);

drop trigger if exists aa_updated on public.utas_results;
create trigger aa_updated before update on public.utas_results for each row execute function public.tg_updated_at();
do $$
declare t text;
begin
  foreach t in array array['utas_examiners','utas_results'] loop
    execute format('drop trigger if exists zz_audit on public.%I', t);
    execute format('create trigger zz_audit after insert or update or delete on public.%I for each row execute function public.tg_audit()', t);
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;
drop policy if exists baca_semua on public.utas_examiners;
create policy baca_semua on public.utas_examiners for select to authenticated using (true);
drop policy if exists baca_hak on public.utas_results;
create policy baca_hak on public.utas_results for select to authenticated using (
  penguji_id = public.saya() or public.boleh_atur_penilaian('tahfizh') or public.is_admin() or student_id in (select public.santri_terlihat()));

-- ---------------------------------------------------------------------
-- 2. HAK
-- ---------------------------------------------------------------------
create or replace function public.panitia_utas()
returns boolean language sql stable security definer set search_path = public as $$
  select public.boleh_atur_penilaian('tahfizh') or public.boleh_kelola_nilai()
$$;

create or replace function public.hak_utas()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'panitia', public.panitia_utas(),
    'penguji', exists (select 1 from utas_examiners x join academic_years a on a.id = x.academic_year_id and a.aktif where x.employee_id = public.saya())
            or exists (select 1 from utas_results r join academic_years a on a.id = r.academic_year_id and a.aktif where r.penguji_id = public.saya()),
    'lihat', public.panitia_utas() or public.pimpinan_tahfizh() or public.is_admin()
            or exists (select 1 from public.kelompok_saya() k join student_groups g on g.id = k where g.jenis in ('halaqah','kelas')))
$$;

-- ---------------------------------------------------------------------
-- 3. JUZ DIUJIKAN (SOP)
-- ---------------------------------------------------------------------
-- N juz resmi yang paling akhir dicapai (tanggal capaian terbaru lebih dulu), diurutkan menaik.
create or replace function public.juz_utas(p_student uuid, p_ta uuid default null)
returns smallint[] language sql stable security definer set search_path = public as $$
  with s as (select jenjang from students where id = p_student),
  n as (select case when s.jenjang = 'sma' then coalesce(r.utas_juz_sma, 5) else coalesce(r.utas_juz_wustha, 3) end n
          from s left join report_settings r on r.jenis = 'tahfizh'
           and r.academic_year_id = coalesce(p_ta, (select id from academic_years where aktif)))
  select coalesce(array_agg(j.juz order by j.juz), '{}') from (
    select juz from juz_achievements where student_id = p_student
     order by tanggal desc, created_at desc, juz desc limit (select n from n)) j
$$;

create or replace function public._hitung_utas(p_ta uuid, p_tajwid numeric, p_itqan numeric)
returns table (nilai numeric, huruf text, tuntas boolean)
language sql stable security definer set search_path = public as $$
  with b as (select coalesce(t.bobot_tajwid, 50) bt, coalesce(t.bobot_itqan, 50) bi from (select 1) x
              left join tahfizh_settings t on t.academic_year_id = p_ta),
  v as (select round((p_tajwid * b.bt + p_itqan * b.bi) / 100.0, 2) n from b where p_tajwid is not null and p_itqan is not null)
  select v.n, (select p.huruf from report_predicates p where p.academic_year_id = p_ta and p.kelompok = 'utas'
                and v.n between p.nilai_min and p.nilai_maks order by p.urutan limit 1),
         v.n >= coalesce((select ambang_bawaan from report_settings where academic_year_id = p_ta and jenis = 'tahfizh'), 80)
    from v
$$;

-- ---------------------------------------------------------------------
-- 4. DATA UTAS (satu panggilan)
-- ---------------------------------------------------------------------
-- Panitia/pimpinan/admin: semua kelas. Penguji: peserta yang diujinya. Muhaffizh/wali kelas: santri asuhannya (baca saja).
create or replace function public.data_utas(p_semester smallint default null, p_ta uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_ta uuid := coalesce(p_ta, (select id from academic_years where aktif)); v_smt smallint; v_semua boolean;
begin
  if public.saya() is null then raise exception 'Akun Anda belum aktif.'; end if;
  v_smt := coalesce(p_semester, (select semester from academic_years where id = v_ta), 1);
  v_semua := public.panitia_utas() or public.pimpinan_tahfizh() or public.is_admin();
  return jsonb_build_object(
    'ta', v_ta, 'semester', v_smt, 'hak', public.hak_utas(),
    'periode', (select to_jsonb(p) from grade_periods p where p.academic_year_id = v_ta and p.jenis = 'tahfizh' and p.semester = v_smt),
    'ketentuan', (select jsonb_build_object('juz_sma', r.utas_juz_sma, 'juz_wustha', r.utas_juz_wustha, 'kkm', r.ambang_bawaan, 'bahasa', r.bahasa_predikat,
                    'bobot_tajwid', coalesce(t.bobot_tajwid, 50), 'bobot_itqan', coalesce(t.bobot_itqan, 50))
                  from report_settings r left join tahfizh_settings t on t.academic_year_id = r.academic_year_id
                 where r.academic_year_id = v_ta and r.jenis = 'tahfizh'),
    'predikat', coalesce((select jsonb_agg(jsonb_build_object('huruf', p.huruf, 'nilai_min', p.nilai_min, 'nilai_maks', p.nilai_maks, 'sebutan', p.sebutan,
                    'sebutan_arab', p.sebutan_arab, 'tuntas', p.tuntas) order by p.urutan) from report_predicates p where p.academic_year_id = v_ta and p.kelompok = 'utas'), '[]'::jsonb),
    'kelas', coalesce((select jsonb_agg(jsonb_build_object('group_id', g.id, 'nama', g.nama, 'jenjang', g.jenjang, 'tingkat', g.tingkat, 'jenis_kelamin', g.jenis_kelamin,
                    'santri', (select count(*) from group_members m join students s on s.id = m.student_id where m.group_id = g.id and m.selesai is null and s.status = 'aktif'),
                    'penguji', coalesce((select jsonb_agg(jsonb_build_object('employee_id', e.id, 'nama', e.nama_lengkap, 'niy', e.niy, 'no_hp', e.no_hp) order by e.nama_lengkap)
                                from utas_examiners x join employees e on e.id = x.employee_id
                               where x.academic_year_id = v_ta and x.semester = v_smt and x.group_id = g.id), '[]'::jsonb))
                  order by g.tingkat, g.nama)
                  from student_groups g where g.academic_year_id = v_ta and g.jenis = 'kelas' and g.aktif
                   and (v_semua or exists (select 1 from utas_examiners x where x.group_id = g.id and x.employee_id = public.saya() and x.academic_year_id = v_ta and x.semester = v_smt)
                        or g.id in (select public.kelompok_saya()))), '[]'::jsonb),
    'peserta', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'student_id', s.id, 'nis', s.nis, 'nama', s.nama_lengkap, 'jenis_kelamin', s.jenis_kelamin, 'jenjang', s.jenjang,
                    'group_id', r.group_id, 'kelas', g.nama, 'halaqah', (select hg.nama from group_members hm join student_groups hg on hg.id = hm.group_id
                       where hm.student_id = s.id and hm.selesai is null and hg.jenis = 'halaqah' and hg.academic_year_id = v_ta limit 1),
                    'penguji_id', r.penguji_id, 'penguji', e.nama_lengkap, 'juz', r.juz, 'juz_usul', public.juz_utas(s.id, v_ta),
                    'total_juz', coalesce(r.total_juz, (select count(*) from juz_achievements j where j.student_id = s.id)),
                    'tajwid', r.tajwid, 'itqan', r.itqan, 'nilai_akhir', r.nilai_akhir, 'huruf', r.huruf, 'tuntas', r.tuntas,
                    'status', r.status, 'catatan', r.catatan, 'diuji_pada', r.diuji_pada, 'saya', r.penguji_id = public.saya())
                  order by g.tingkat, g.nama, s.nama_lengkap)
                  from utas_results r join students s on s.id = r.student_id left join student_groups g on g.id = r.group_id
                  left join employees e on e.id = r.penguji_id
                 where r.academic_year_id = v_ta and r.semester = v_smt
                   and (v_semua or r.penguji_id = public.saya() or r.student_id in (select public.santri_terlihat()))), '[]'::jsonb),
    -- Kelas yang belum dibagi: jumlah santri aktif belum menjadi peserta (untuk panitia)
    'belum_dibagi', case when v_semua then coalesce((select jsonb_object_agg(g.id, n.n) from student_groups g
                    cross join lateral (select count(*) n from group_members m join students s on s.id = m.student_id
                                         where m.group_id = g.id and m.selesai is null and s.status = 'aktif'
                                           and not exists (select 1 from utas_results r where r.academic_year_id = v_ta and r.semester = v_smt and r.student_id = s.id)) n
                    where g.academic_year_id = v_ta and g.jenis = 'kelas' and g.aktif and n.n > 0), '{}'::jsonb) else '{}'::jsonb end);
end $$;

-- ---------------------------------------------------------------------
-- 5. PANITIA: PENGUJI, PEMBAGIAN, PINDAH
-- ---------------------------------------------------------------------
create or replace function public._cek_panitia_utas(p_ta uuid)
returns void language plpgsql stable security definer set search_path = public as $$
begin
  if not public.panitia_utas() then raise exception 'Hanya panitia UTAS (admin/superadmin) yang dapat melakukan ini.' using errcode = '42501'; end if;
  perform public._ta_boleh_ubah(p_ta);
end $$;

-- Penguji satu kelas (daftar lengkap; yang tidak dikirim dilepas). Peserta yang penguji lamanya dilepas menjadi tanpa penguji.
create or replace function public.simpan_penguji_utas(p_semester smallint, p_group uuid, p_employees uuid[], p_ta uuid default null)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v_ta uuid := coalesce(p_ta, (select id from academic_years where aktif)); e uuid;
begin
  perform public._cek_panitia_utas(v_ta);
  if not exists (select 1 from student_groups where id = p_group and jenis = 'kelas' and academic_year_id = v_ta) then raise exception 'Kelas tidak ditemukan.'; end if;
  if exists (select 1 from unnest(p_employees) x where not exists (select 1 from employees where id = x and status_keaktifan = 'aktif')) then
    raise exception 'Penguji harus pegawai aktif.';
  end if;
  delete from utas_examiners where academic_year_id = v_ta and semester = p_semester and group_id = p_group and employee_id <> all(p_employees);
  update utas_results set penguji_id = null where academic_year_id = v_ta and semester = p_semester and group_id = p_group
     and penguji_id is not null and penguji_id <> all(p_employees) and status = 'draf';
  foreach e in array p_employees loop
    insert into utas_examiners (academic_year_id, semester, group_id, employee_id) values (v_ta, p_semester, p_group, e) on conflict do nothing;
    if found and e is distinct from public.saya() then
      perform public.kirim_notifikasi(e, 'Anda ditunjuk sebagai penguji UTAS semester ' || p_semester,
        'Kelas ' || (select nama from student_groups where id = p_group) || '. Daftar peserta tampil di Tahfizh → Ujian → UTAS.', '/tahfizh/ujian', 'Exam', 'kuning');
    end if;
  end loop;
end $$;

-- Bagi santri aktif kelas menjadi peserta UTAS, bergilir di antara penguji kelas itu (yang paling sedikit pesertanya lebih dulu).
-- p_ulang = bagi ulang penguji untuk peserta berstatus draf yang belum bernilai. Juz diujikan diisi otomatis bila kosong.
create or replace function public.bagi_peserta_utas(p_semester smallint, p_group uuid, p_ulang boolean default false, p_ta uuid default null)
returns int language plpgsql volatile security definer set search_path = public as $$
declare v_ta uuid := coalesce(p_ta, (select id from academic_years where aktif)); v_penguji uuid[]; s record; v_n int := 0; v_pilih uuid;
begin
  perform public._cek_panitia_utas(v_ta);
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
    on conflict (academic_year_id, semester, student_id) do update set group_id = excluded.group_id,
      juz = case when utas_results.juz = '{}' then excluded.juz else utas_results.juz end;
    if cardinality(v_penguji) > 0 then
      select x into v_pilih from unnest(v_penguji) x
       order by (select count(*) from utas_results r where r.academic_year_id = v_ta and r.semester = p_semester and r.group_id = p_group and r.penguji_id = x), x
       limit 1;
      update utas_results set penguji_id = v_pilih
       where academic_year_id = v_ta and semester = p_semester and student_id = s.id and penguji_id is null;
      if found then v_n := v_n + 1; end if;
    end if;
  end loop;
  return v_n;
end $$;

create or replace function public.pindah_penguji_utas(p_ids uuid[], p_penguji uuid)
returns int language plpgsql volatile security definer set search_path = public as $$
declare v_n int; v_ta uuid;
begin
  select academic_year_id into v_ta from utas_results where id = p_ids[1];
  if v_ta is null then return 0; end if;
  perform public._cek_panitia_utas(v_ta);
  if p_penguji is not null and not exists (select 1 from employees where id = p_penguji and status_keaktifan = 'aktif') then raise exception 'Penguji harus pegawai aktif.'; end if;
  update utas_results set penguji_id = p_penguji where id = any(p_ids);
  get diagnostics v_n = row_count;
  return v_n;
end $$;

create or replace function public.hapus_peserta_utas(p_ids uuid[])
returns int language plpgsql volatile security definer set search_path = public as $$
declare v_n int; v_ta uuid;
begin
  select academic_year_id into v_ta from utas_results where id = p_ids[1];
  if v_ta is null then return 0; end if;
  perform public._cek_panitia_utas(v_ta);
  delete from utas_results where id = any(p_ids) and tajwid is null and itqan is null;
  get diagnostics v_n = row_count;
  return v_n;
end $$;

-- ---------------------------------------------------------------------
-- 6. NILAI
-- ---------------------------------------------------------------------
-- p: [{id, juz?: [..], tajwid?, itqan?, catatan?, diuji_pada?}] · p_kirim = tandai final (penguji tidak dapat mengubah lagi)
-- Penguji: hanya pesertanya, status draf, periode rapor tahfizh semester itu belum ditutup. Panitia: kapan saja (TA belum dikunci).
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
      if r.status = 'final' then raise exception 'Nilai sudah dikirim (final). Perubahan melalui panitia UTAS.'; end if;
      select status into v_status from grade_periods where academic_year_id = r.academic_year_id and jenis = 'tahfizh' and semester = r.semester;
      if v_status = 'ditutup' then raise exception 'Periode penilaian tahfizh semester % sudah ditutup.', r.semester; end if;
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

-- Panitia membuka kembali nilai final agar penguji dapat memperbaiki
create or replace function public.buka_nilai_utas(p_ids uuid[])
returns int language plpgsql volatile security definer set search_path = public as $$
declare v_n int; v_ta uuid;
begin
  select academic_year_id into v_ta from utas_results where id = p_ids[1];
  if v_ta is null then return 0; end if;
  perform public._cek_panitia_utas(v_ta);
  update utas_results set status = 'draf' where id = any(p_ids) and status = 'final';
  get diagnostics v_n = row_count;
  return v_n;
end $$;

-- ---------------------------------------------------------------------
-- 7. HAK EKSEKUSI
-- ---------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array['panitia_utas()','hak_utas()','juz_utas(uuid,uuid)','data_utas(smallint,uuid)','simpan_penguji_utas(smallint,uuid,uuid[],uuid)',
      'bagi_peserta_utas(smallint,uuid,boolean,uuid)','pindah_penguji_utas(uuid[],uuid)','hapus_peserta_utas(uuid[])','simpan_nilai_utas(jsonb,boolean)',
      'buka_nilai_utas(uuid[])'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['_hitung_utas(uuid,numeric,numeric)','_cek_panitia_utas(uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 8. PEMERIKSAAN — hasil yang benar: 4 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select '1. Tabel UTAS (2) dengan RLS' as pemeriksaan,
       case when (select count(*) from pg_tables where schemaname = 'public' and rowsecurity and tablename in ('utas_examiners','utas_results')) = 2
            then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Fungsi UTAS',
       case when (select count(*) from pg_proc where proname in ('data_utas','simpan_penguji_utas','bagi_peserta_utas','simpan_nilai_utas','buka_nilai_utas','juz_utas')) = 6
            then 'Sesuai' else 'Periksa' end
union all
select '3. Predikat UTAS tersedia (TA aktif)',
       case when exists (select 1 from report_predicates p join academic_years a on a.id = p.academic_year_id and a.aktif where p.kelompok = 'utas')
            then 'Sesuai' else 'Periksa: jalankan 8200 dulu' end
union all
select '4. Tertutup bagi pengunjung tanpa masuk',
       case when not has_function_privilege('anon', 'public.data_utas(smallint,uuid)', 'execute') then 'Sesuai' else 'Periksa' end;
