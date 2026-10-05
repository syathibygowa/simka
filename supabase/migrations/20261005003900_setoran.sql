-- SIMKA PRO | supabase/migrations/20261005003900_setoran.sql | v1.0 | Fase 5 – Tahap 2 Setoran per sesi halaqah | 05/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 5 · Migrasi 39: Setoran hafalan per sesi halaqah (Blueprint Bagian 20)
--   * memorization_sessions : satu baris per halaqah × tanggal × sesi (Subuh/Sore/Malam) — tanda setoran SUDAH DIISI
--                             (termasuk bila semua santri "Sama"); dasar laporan kepatuhan pengisian muhaffizh.
--   * memorization_logs     : HANYA santri yang bertambah/berubah atau diberi catatan. Santri yang tidak tercantum = Sama.
--                             Kolom *_hal kosong = Sama untuk jenis itu. *_lama = posisi sebelum sesi (dihitung server).
--   * Santri I/S/B/A pada absensi halaqah sesi itu = "Tidak setor" (otomatis, tidak dapat diisi setoran).
--   * Setoran diisi setelah absensi sesi itu tersimpan; jendela dan hak sama dengan absensi (pengasuh sampai
--     23.59 hari itu; admin ber-izin absensi_atas_nama sampai batas hari atas nama).
--   * Isian janggal ditandai: posisi sabaq turun, penambahan melebihi batas per sesi, sabqi/manzil melebihi sabaq.
--   * student_tahfizh mendapat kolom awal_* (data awal) — posisi terkini = setoran terakhir per jenis, atau data awal.
--   * Fungsi: status_setoran, detail_setoran, simpan_setoran, riwayat_setoran; simpan_hafalan_awal diperbarui.
-- Jalankan SETELAH migrasi 3800. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. POSISI DATA AWAL DIPISAH DARI POSISI TERKINI
-- ---------------------------------------------------------------------
alter table public.student_tahfizh add column if not exists awal_sabaq_hal smallint not null default 0;
alter table public.student_tahfizh add column if not exists awal_sabqi_hal smallint not null default 0;
alter table public.student_tahfizh add column if not exists awal_manzil_hal smallint not null default 0;
alter table public.student_tahfizh add column if not exists awal_juz_sedang smallint;
alter table public.student_tahfizh add column if not exists awal_pada timestamptz;
-- Salin posisi yang sudah diisi pada Tahap 1 sebagai data awal (sekali saja)
update public.student_tahfizh set awal_sabaq_hal = sabaq_hal, awal_sabqi_hal = sabqi_hal, awal_manzil_hal = manzil_hal,
       awal_juz_sedang = juz_sedang, awal_pada = posisi_pada
 where awal_pada is null and posisi_pada is not null and coalesce(posisi_sumber, 'awal') = 'awal';

-- ---------------------------------------------------------------------
-- 2. TABEL SETORAN
-- ---------------------------------------------------------------------
create table if not exists public.memorization_sessions (
  id                 uuid primary key default gen_random_uuid(),
  group_id           uuid not null references public.student_groups(id) on delete cascade,
  attendance_session_id uuid references public.student_attendance_sessions(id) on delete set null,
  tanggal            date not null,
  sesi               text not null,
  nama_sesi          text not null,
  jam_mulai          time,
  pengampu_id        uuid references public.employees(id) on delete set null,
  diinput_oleh       uuid references public.employees(id) on delete set null,
  atas_nama          boolean not null default false,
  diisi_terlambat    boolean not null default false,
  jumlah_anggota     int not null default 0,
  jumlah_setor       int not null default 0,   -- hadir (H/T) sehingga dapat setor
  jumlah_tidak_setor int not null default 0,   -- I/S/B/A
  jumlah_bertambah   int not null default 0,   -- sabaq bertambah
  jumlah_janggal     int not null default 0,
  total_tambah_hal   int not null default 0,   -- jumlah penambahan sabaq (halaman)
  catatan            text,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  constraint memorization_sessions_unik unique (group_id, tanggal, sesi)
);
create index if not exists ms_tanggal_idx on public.memorization_sessions (tanggal);

create table if not exists public.memorization_logs (
  id               uuid primary key default gen_random_uuid(),
  session_id       uuid not null references public.memorization_sessions(id) on delete cascade,
  student_id       uuid not null references public.students(id) on delete cascade,
  tanggal          date not null,
  sabaq_lama       smallint not null default 0,
  sabaq_hal        smallint constraint ml_sabaq check (sabaq_hal between 0 and 600),   -- kosong = Sama
  sabqi_lama       smallint not null default 0,
  sabqi_hal        smallint constraint ml_sabqi check (sabqi_hal between 0 and 600),
  manzil_lama      smallint not null default 0,
  manzil_hal       smallint constraint ml_manzil check (manzil_hal between 0 and 600),
  tambah_hal       smallint not null default 0,  -- sabaq_hal − sabaq_lama (0 bila Sama)
  juz_sedang       smallint constraint ml_juz check (juz_sedang between 1 and 30),
  janggal          text[] not null default '{}',
  catatan          text,
  constraint memorization_logs_unik unique (session_id, student_id)
);
create index if not exists ml_santri_idx on public.memorization_logs (student_id, tanggal);
create index if not exists ml_tanggal_idx on public.memorization_logs (tanggal);

drop trigger if exists aa_updated on public.memorization_sessions;
create trigger aa_updated before update on public.memorization_sessions for each row execute function public.tg_updated_at();

alter table public.memorization_sessions enable row level security;
alter table public.memorization_logs enable row level security;
drop policy if exists sesi_baca on public.memorization_sessions;
create policy sesi_baca on public.memorization_sessions for select to authenticated using (group_id in (select id from public.student_groups));
drop policy if exists santri_baca on public.memorization_logs;
create policy santri_baca on public.memorization_logs for select to authenticated using (student_id in (select public.santri_terlihat()));

do $$ begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'memorization_sessions') then
    alter publication supabase_realtime add table public.memorization_sessions;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 3. HITUNG ULANG POSISI SANTRI
-- ---------------------------------------------------------------------
-- Menyusun ulang posisi *_lama, penambahan, dan tanda janggal seluruh setoran seorang santri secara berurutan
-- (tanggal, jam sesi), lalu memperbarui posisi terkini di student_tahfizh. Dipakai setelah simpan/koreksi setoran
-- dan setelah data awal diubah, sehingga koreksi sesi lama tetap konsisten dengan sesi sesudahnya.
create or replace function public._hitung_ulang_setoran(p_santri uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare st student_tahfizh; r record; v_sabaq int; v_sabqi int; v_manzil int; v_juz smallint; v_batas int; v_j text[];
  v_ada boolean := false; v_pada timestamptz;
begin
  insert into student_tahfizh (student_id) values (p_santri) on conflict do nothing;
  select * into st from student_tahfizh where student_id = p_santri for update;
  v_sabaq := st.awal_sabaq_hal; v_sabqi := st.awal_sabqi_hal; v_manzil := st.awal_manzil_hal; v_juz := st.awal_juz_sedang; v_pada := st.awal_pada;
  v_batas := coalesce((select s.batas_lonjakan_hal from tahfizh_settings s join academic_years a on a.id = s.academic_year_id and a.aktif), 10);
  for r in
    select l.*, m.jam_mulai, m.created_at as dibuat
      from memorization_logs l join memorization_sessions m on m.id = l.session_id
     where l.student_id = p_santri order by l.tanggal, m.jam_mulai nulls last, m.created_at
  loop
    v_ada := true; v_j := '{}';
    if r.sabaq_hal is not null and r.sabaq_hal < v_sabaq then v_j := array_append(v_j, 'turun'); end if;
    if r.sabaq_hal is not null and r.sabaq_hal - v_sabaq > v_batas then v_j := array_append(v_j, 'lonjakan'); end if;
    if coalesce(r.sabqi_hal, v_sabqi) > coalesce(r.sabaq_hal, v_sabaq) or coalesce(r.manzil_hal, v_manzil) > coalesce(r.sabaq_hal, v_sabaq) then
      v_j := array_append(v_j, 'melebihi_sabaq');
    end if;
    update memorization_logs set sabaq_lama = v_sabaq, sabqi_lama = v_sabqi, manzil_lama = v_manzil,
           tambah_hal = case when r.sabaq_hal is null then 0 else r.sabaq_hal - v_sabaq end, janggal = v_j
     where id = r.id;
    v_sabaq := coalesce(r.sabaq_hal, v_sabaq); v_sabqi := coalesce(r.sabqi_hal, v_sabqi); v_manzil := coalesce(r.manzil_hal, v_manzil);
    v_juz := coalesce(r.juz_sedang, v_juz);
    v_pada := greatest(coalesce(v_pada, '-infinity'), ((r.tanggal + coalesce(r.jam_mulai, '00:00'))::timestamp at time zone 'Asia/Makassar'));
  end loop;
  update student_tahfizh set sabaq_hal = v_sabaq, sabqi_hal = v_sabqi, manzil_hal = v_manzil, juz_sedang = v_juz,
         posisi_pada = v_pada, posisi_sumber = case when v_ada then 'setoran' when v_pada is not null then 'awal' else null end
   where student_id = p_santri;
end $$;

-- Ringkasan sebuah sesi setoran (dipanggil setelah simpan dan setelah hitung ulang)
create or replace function public._ringkas_setoran(p_id uuid)
returns void language sql volatile security definer set search_path = public as $$
  update memorization_sessions m set
    jumlah_bertambah = (select count(*) from memorization_logs l where l.session_id = m.id and l.sabaq_hal is not null and l.tambah_hal > 0),
    jumlah_janggal = (select count(*) from memorization_logs l where l.session_id = m.id and cardinality(l.janggal) > 0),
    total_tambah_hal = coalesce((select sum(greatest(l.tambah_hal, 0)) from memorization_logs l where l.session_id = m.id), 0)
  where m.id = p_id
$$;

-- ---------------------------------------------------------------------
-- 4. DATA AWAL (memperbarui fungsi Tahap 1: kini mengisi kolom awal_* lalu menghitung ulang)
-- ---------------------------------------------------------------------
create or replace function public.simpan_hafalan_awal(p_santri uuid, p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v_juz smallint[]; v_tetap smallint[]; v_nama text; v_total int; v_posisi boolean := p ?| array['sabaq_hal','sabqi_hal','manzil_hal','juz_sedang'];
  v_ses uuid;
begin
  if not public.boleh_validasi_tahfizh() then
    raise exception 'Data hafalan awal hanya diisi admin ber-izin validasi tahfizh atau pimpinan Bidang Tahfizh.' using errcode = '42501';
  end if;
  select nama_lengkap into v_nama from students where id = p_santri;
  if v_nama is null then raise exception 'Santri tidak ditemukan.'; end if;

  insert into student_tahfizh (student_id) values (p_santri) on conflict do nothing;
  update student_tahfizh set
    program = coalesce(nullif(p->>'program', ''), program),
    awal_sabaq_hal = case when p ? 'sabaq_hal' then coalesce((p->>'sabaq_hal')::smallint, 0) else awal_sabaq_hal end,
    awal_sabqi_hal = case when p ? 'sabqi_hal' then coalesce((p->>'sabqi_hal')::smallint, 0) else awal_sabqi_hal end,
    awal_manzil_hal = case when p ? 'manzil_hal' then coalesce((p->>'manzil_hal')::smallint, 0) else awal_manzil_hal end,
    awal_juz_sedang = case when p ? 'juz_sedang' then nullif(p->>'juz_sedang', '')::smallint else awal_juz_sedang end,
    awal_pada = case when v_posisi then now() else awal_pada end
  where student_id = p_santri;
  if v_posisi then
    perform public._hitung_ulang_setoran(p_santri);
    for v_ses in select distinct session_id from memorization_logs where student_id = p_santri loop perform public._ringkas_setoran(v_ses); end loop;
  end if;

  if p ? 'juz' then
    select coalesce(array_agg(distinct x::smallint order by x::smallint), '{}') into v_juz
      from jsonb_array_elements_text(p->'juz') x where x ~ '^\d+$';
    if exists (select 1 from unnest(v_juz) j where j not between 1 and 30) then raise exception 'Nomor juz harus 1–30.'; end if;
    select coalesce(array_agg(juz), '{}') into v_tetap from juz_achievements where student_id = p_santri and sumber <> 'awal';
    delete from juz_achievements where student_id = p_santri and sumber = 'awal' and juz <> all(v_juz);
    insert into juz_achievements (student_id, juz, sumber, ditetapkan_oleh, catatan)
    select p_santri, j, 'awal', public.saya(), nullif(trim(p->>'catatan'), '')
      from unnest(v_juz) j where j <> all(v_tetap)
    on conflict (student_id, juz) do nothing;
    select count(*) into v_total from juz_achievements where student_id = p_santri;
    perform public.catat_audit('ubah', 'juz_achievements', p_santri::text,
      'Data hafalan awal ' || v_nama || ': ' || coalesce(array_to_string(v_juz, ', '), '–') || ' (total resmi ' || v_total || ' juz)',
      jsonb_build_object('juz_awal', v_juz));
  end if;
  return jsonb_build_object('ok', true, 'total_resmi', (select count(*) from juz_achievements where student_id = p_santri));
exception
  when check_violation then raise exception 'Posisi hafalan harus 0–30 juz (0–600 halaman) dan juz sedang dihafal 1–30.';
end $$;

-- ---------------------------------------------------------------------
-- 5. HAK DAN JENDELA (sama dengan absensi halaqah)
-- ---------------------------------------------------------------------
-- Mengembalikan pengampu yang dipakai; galat bila tidak berhak atau di luar jendela.
create or replace function public._cek_hak_setoran(p_group uuid, p_tanggal date, p_sesi text, p_atas_nama uuid, out v_pengampu uuid, out v_atas boolean, out v_telat boolean)
language plpgsql stable security definer set search_path = public as $$
declare ss record; v_saya uuid := public.saya(); v_kini timestamptz := now(); v_hari int;
  st jsonb := coalesce((select nilai from institution_settings where kunci = 'absensi_santri'), '{}'::jsonb);
begin
  v_atas := false;
  select * into ss from public.sesi_santri_tanggal('halaqah', p_tanggal) x where x.kode = p_sesi;
  if not found then raise exception 'Tidak ada sesi halaqah % pada tanggal ini.', p_sesi; end if;
  v_telat := v_kini > ss.tutup;
  if v_saya in (select public._pengasuh_berlaku(p_group, p_tanggal)) and not (p_atas_nama is not null and public.admin_boleh('absensi_atas_nama')) then
    if v_kini < ss.buka then raise exception 'Setoran % belum dibuka. Dibuka pukul %.', ss.nama, to_char(ss.buka at time zone 'Asia/Makassar', 'HH24.MI'); end if;
    if v_kini > ss.batas then raise exception 'Batas pengisian dan koreksi setoran ini sudah lewat. Hubungi admin untuk input atas nama.'; end if;
    v_pengampu := v_saya;
  elsif public.admin_boleh('absensi_atas_nama') then
    v_hari := coalesce((st->>'batas_atas_nama_hari')::int, 7);
    if v_kini < ss.buka then raise exception 'Sesi ini belum dibuka.'; end if;
    if not public.is_superadmin() and p_tanggal < public.hari_ini() - v_hari then
      raise exception 'Input atas nama paling lama % hari ke belakang. Hubungi superadmin.', v_hari;
    end if;
    v_atas := true;
    v_pengampu := coalesce(p_atas_nama, (select k.employee_id from group_keepers k where k.group_id = p_group
      and k.employee_id in (select public._pengasuh_berlaku(p_group, p_tanggal)) order by array_position(array['utama','pendamping','pengganti'], k.peran) limit 1));
  else
    raise exception 'Anda bukan muhaffizh halaqah ini.' using errcode = '42501';
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 6. DAFTAR SESI SETORAN SATU TANGGAL
-- ---------------------------------------------------------------------
-- p_semua: semua halaqah (admin, pimpinan Bidang Tahfizh, pemegang validasi tahfizh, atau pemantau absensi).
create or replace function public.status_setoran(p_tanggal date default null, p_semua boolean default false)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_tgl date := coalesce(p_tanggal, public.hari_ini()); v_saya uuid := public.saya(); v_kini timestamptz := now(); hasil jsonb;
begin
  if v_saya is null then return '[]'::jsonb; end if;
  if p_semua and not (public.boleh_validasi_tahfizh() or public.boleh_atur_tahfizh() or public.boleh_pantau_absensi()) then
    raise exception 'Anda tidak berwenang memantau setoran semua halaqah.' using errcode = '42501';
  end if;
  select coalesce(jsonb_agg(x order by x->>'mulai', x->>'nama_kelompok'), '[]'::jsonb) into hasil from (
    select jsonb_build_object(
      'group_id', g.id, 'nama_kelompok', g.nama, 'jenis_kelamin', g.jenis_kelamin, 'tanggal', v_tgl,
      'sesi', ss.kode, 'nama_sesi', ss.nama, 'jam_mulai', ss.jam_mulai, 'jam_selesai', ss.jam_selesai,
      'mulai', ss.mulai, 'buka', ss.buka, 'tutup', ss.tutup, 'batas', ss.batas,
      'absensi', case when sa.id is not null then 'terisi' when v_kini < ss.buka then 'belum_buka' when v_kini <= ss.batas then 'terbuka' else 'tidak_terisi' end,
      'status', case when ms.id is not null then 'terisi' when v_kini < ss.buka then 'belum_buka'
                     when v_kini <= ss.tutup then 'terbuka' when v_kini <= ss.batas then 'lewat' else 'tidak_terisi' end,
      'jumlah_anggota', coalesce(ms.jumlah_anggota, sa.jumlah_anggota, (select count(*) from public._anggota_pada(g.id, v_tgl))),
      'jumlah_hadir', sa.jumlah_hadir, 'jumlah_tidak_setor', ms.jumlah_tidak_setor, 'jumlah_bertambah', ms.jumlah_bertambah,
      'jumlah_janggal', ms.jumlah_janggal, 'total_tambah_hal', ms.total_tambah_hal, 'diisi_pada', ms.updated_at, 'diisi_terlambat', ms.diisi_terlambat,
      'atas_nama', ms.atas_nama,
      'asuhan_saya', v_saya in (select public._pengasuh_berlaku(g.id, v_tgl)),
      'pengampu', (select string_agg(e.nama_lengkap, ', ' order by k.peran, e.nama_lengkap) from group_keepers k join employees e on e.id = k.employee_id
                   where k.group_id = g.id and k.employee_id in (select public._pengasuh_berlaku(g.id, v_tgl)))) as x
    from student_groups g
    join academic_years a on a.id = g.academic_year_id and a.aktif
    cross join lateral public.sesi_santri_tanggal('halaqah', v_tgl) ss
    left join student_attendance_sessions sa on sa.group_id = g.id and sa.tanggal = v_tgl and sa.sesi = ss.kode
    left join memorization_sessions ms on ms.group_id = g.id and ms.tanggal = v_tgl and ms.sesi = ss.kode
    where g.aktif and g.jenis = 'halaqah'
      and (p_semua or v_saya in (select public._pengasuh_berlaku(g.id, v_tgl)))
  ) t;
  return hasil;
end $$;

-- ---------------------------------------------------------------------
-- 7. DETAIL SATU SESI SETORAN (formulir)
-- ---------------------------------------------------------------------
create or replace function public.detail_setoran(p_group uuid, p_tanggal date, p_sesi text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare g student_groups; ss record; sa student_attendance_sessions; ms memorization_sessions; v_saya uuid := public.saya();
  v_pengasuh boolean; v_jam time;
begin
  select * into g from student_groups where id = p_group;
  if not found or g.jenis <> 'halaqah' then raise exception 'Halaqah tidak ditemukan.'; end if;
  v_pengasuh := v_saya in (select public._pengasuh_berlaku(p_group, p_tanggal));
  if not (v_pengasuh or public.boleh_validasi_tahfizh() or public.boleh_atur_tahfizh() or public.boleh_pantau_absensi()) then
    raise exception 'Anda bukan muhaffizh halaqah ini.' using errcode = '42501';
  end if;
  select * into ss from public.sesi_santri_tanggal('halaqah', p_tanggal) x where x.kode = p_sesi;
  if not found then raise exception 'Tidak ada sesi halaqah % pada tanggal ini.', p_sesi; end if;
  v_jam := ss.jam_mulai;
  select * into sa from student_attendance_sessions where group_id = p_group and tanggal = p_tanggal and sesi = p_sesi;
  select * into ms from memorization_sessions where group_id = p_group and tanggal = p_tanggal and sesi = p_sesi;
  return jsonb_build_object(
    'session_id', ms.id, 'absensi_tersimpan', sa.id is not null, 'catatan', ms.catatan,
    'diisi_pada', ms.updated_at, 'diisi_terlambat', ms.diisi_terlambat, 'atas_nama', ms.atas_nama,
    'diinput_oleh', (select nama_lengkap from employees where id = ms.diinput_oleh),
    'pengampu', (select nama_lengkap from employees where id = ms.pengampu_id),
    'batas_lonjakan_hal', coalesce((select s.batas_lonjakan_hal from tahfizh_settings s join academic_years a on a.id = s.academic_year_id and a.aktif), 10),
    'boleh_isi', (v_pengasuh or public.admin_boleh('absensi_atas_nama')) and sa.id is not null,
    'santri', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id, 'nis', s.nis, 'nama', s.nama_lengkap, 'jenis_kelamin', s.jenis_kelamin,
        'program', coalesce(t.program, 'reguler'),
        'kehadiran', coalesce((select x.kode from student_attendance_exceptions x where x.session_id = sa.id and x.student_id = s.id), 'H'),
        -- posisi sebelum sesi ini: setoran terakhir sebelum sesi ini per jenis, atau data awal
        'sabaq_lama', coalesce(l.sabaq_lama, (
            select l2.sabaq_hal from memorization_logs l2 join memorization_sessions m2 on m2.id = l2.session_id
             where l2.student_id = s.id and l2.sabaq_hal is not null and (l2.tanggal, coalesce(m2.jam_mulai, '00:00')) < (p_tanggal, coalesce(v_jam, '00:00'))
             order by l2.tanggal desc, m2.jam_mulai desc nulls last limit 1), t.awal_sabaq_hal, 0),
        'sabqi_lama', coalesce(l.sabqi_lama, (
            select l2.sabqi_hal from memorization_logs l2 join memorization_sessions m2 on m2.id = l2.session_id
             where l2.student_id = s.id and l2.sabqi_hal is not null and (l2.tanggal, coalesce(m2.jam_mulai, '00:00')) < (p_tanggal, coalesce(v_jam, '00:00'))
             order by l2.tanggal desc, m2.jam_mulai desc nulls last limit 1), t.awal_sabqi_hal, 0),
        'manzil_lama', coalesce(l.manzil_lama, (
            select l2.manzil_hal from memorization_logs l2 join memorization_sessions m2 on m2.id = l2.session_id
             where l2.student_id = s.id and l2.manzil_hal is not null and (l2.tanggal, coalesce(m2.jam_mulai, '00:00')) < (p_tanggal, coalesce(v_jam, '00:00'))
             order by l2.tanggal desc, m2.jam_mulai desc nulls last limit 1), t.awal_manzil_hal, 0),
        'juz_sedang', coalesce(l.juz_sedang, t.juz_sedang),
        'sabaq_hal', l.sabaq_hal, 'sabqi_hal', l.sabqi_hal, 'manzil_hal', l.manzil_hal, 'tambah_hal', l.tambah_hal,
        'janggal', coalesce(to_jsonb(l.janggal), '[]'), 'catatan', l.catatan,
        'total_resmi', (select count(*) from juz_achievements j where j.student_id = s.id)) order by s.nama_lengkap)
      from students s left join student_tahfizh t on t.student_id = s.id
      left join memorization_logs l on l.session_id = ms.id and l.student_id = s.id
      where s.id in (select public._anggota_pada(p_group, p_tanggal))), '[]'));
end $$;

-- ---------------------------------------------------------------------
-- 8. SIMPAN SETORAN (satu-satunya pintu tulis)
-- ---------------------------------------------------------------------
-- p: {group_id, tanggal, sesi, catatan?, atas_nama_id?,
--     baris: [{student_id, sabaq_hal?, sabqi_hal?, manzil_hal?, juz_sedang?, catatan?}]}   (*_hal kosong/null = Sama)
-- Santri yang tidak dikirim = Sama. Mengembalikan {id, janggal: [{nama, tanda}]}.
create or replace function public.simpan_setoran(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v_group uuid := (p->>'group_id')::uuid; v_tgl date := (p->>'tanggal')::date; v_sesi text := p->>'sesi';
  g student_groups; ss record; sa student_attendance_sessions; hak record; v_id uuid; r jsonb; v_santri uuid; v_kode text;
  v_lama uuid[]; v_terkena uuid[]; v_saya uuid := public.saya(); v_janggal jsonb;
begin
  if v_saya is null then raise exception 'Sesi masuk tidak berlaku. Silakan masuk ulang.' using errcode = '42501'; end if;
  select * into g from student_groups where id = v_group;
  if not found or not g.aktif or g.jenis <> 'halaqah' then raise exception 'Halaqah tidak ditemukan atau nonaktif.'; end if;
  if not exists (select 1 from academic_years where id = g.academic_year_id and aktif and not terkunci) then
    raise exception 'Halaqah ini bukan milik tahun ajaran aktif.';
  end if;
  select * into hak from public._cek_hak_setoran(v_group, v_tgl, v_sesi, nullif(p->>'atas_nama_id', '')::uuid);
  select * into ss from public.sesi_santri_tanggal('halaqah', v_tgl) x where x.kode = v_sesi;
  select * into sa from student_attendance_sessions where group_id = v_group and tanggal = v_tgl and sesi = v_sesi;
  if sa.id is null then raise exception 'Simpan absensi sesi ini lebih dulu, baru isi setoran.'; end if;

  -- Validasi baris
  for r in select * from jsonb_array_elements(coalesce(p->'baris', '[]')) loop
    v_santri := (r->>'student_id')::uuid;
    if v_santri is null or v_santri not in (select public._anggota_pada(v_group, v_tgl)) then
      raise exception 'Ada santri yang bukan anggota % pada tanggal ini.', g.nama;
    end if;
    select kode into v_kode from student_attendance_exceptions where session_id = sa.id and student_id = v_santri;
    if v_kode in ('I','S','B','A') and (r->>'sabaq_hal' is not null or r->>'sabqi_hal' is not null or r->>'manzil_hal' is not null) then
      raise exception '% tercatat % pada absensi sesi ini sehingga tidak setor. Koreksi absensinya bila santri hadir.',
        (select nama_lengkap from students where id = v_santri), case v_kode when 'I' then 'Izin' when 'S' then 'Sakit' when 'B' then 'Bolos' else 'Absen' end;
    end if;
  end loop;

  select id into v_id from memorization_sessions where group_id = v_group and tanggal = v_tgl and sesi = v_sesi for update;
  if v_id is null then
    insert into memorization_sessions (group_id, attendance_session_id, tanggal, sesi, nama_sesi, jam_mulai, pengampu_id, diinput_oleh, atas_nama, diisi_terlambat, catatan)
    values (v_group, sa.id, v_tgl, v_sesi, ss.nama, ss.jam_mulai, hak.v_pengampu, v_saya, hak.v_atas, hak.v_telat, nullif(trim(p->>'catatan'), ''))
    returning id into v_id;
    v_lama := '{}';
  else
    select coalesce(array_agg(student_id), '{}') into v_lama from memorization_logs where session_id = v_id;
    update memorization_sessions set attendance_session_id = sa.id, diinput_oleh = v_saya, atas_nama = atas_nama or hak.v_atas,
           pengampu_id = coalesce(pengampu_id, hak.v_pengampu), diisi_terlambat = diisi_terlambat or hak.v_telat,
           catatan = nullif(trim(p->>'catatan'), '')
     where id = v_id;
  end if;

  delete from memorization_logs where session_id = v_id;
  insert into memorization_logs (session_id, student_id, tanggal, sabaq_hal, sabqi_hal, manzil_hal, juz_sedang, catatan)
  select v_id, (x->>'student_id')::uuid, v_tgl, nullif(x->>'sabaq_hal', '')::smallint, nullif(x->>'sabqi_hal', '')::smallint,
         nullif(x->>'manzil_hal', '')::smallint, nullif(x->>'juz_sedang', '')::smallint, nullif(trim(coalesce(x->>'catatan', '')), '')
    from jsonb_array_elements(coalesce(p->'baris', '[]')) x
   where nullif(x->>'sabaq_hal', '') is not null or nullif(x->>'sabqi_hal', '') is not null or nullif(x->>'manzil_hal', '') is not null
      or nullif(x->>'juz_sedang', '') is not null or nullif(trim(coalesce(x->>'catatan', '')), '') is not null;

  -- Hitung ulang semua santri yang terkena (baru maupun yang dihapus dari sesi ini)
  select coalesce(array_agg(distinct u), '{}') into v_terkena
    from (select unnest(v_lama) u union select student_id from memorization_logs where session_id = v_id) z;
  perform public._hitung_ulang_setoran(u) from unnest(v_terkena) u;
  -- Sesi lain milik santri tersebut ikut diringkas ulang (koreksi sesi lama dapat mengubah sesi sesudahnya)
  perform public._ringkas_setoran(m) from (select distinct session_id m from memorization_logs where student_id = any(v_terkena) union select v_id) z;

  update memorization_sessions set
    jumlah_anggota = (select count(*) from public._anggota_pada(v_group, v_tgl)),
    jumlah_tidak_setor = (select count(*) from student_attendance_exceptions x where x.session_id = sa.id and x.kode in ('I','S','B','A')),
    jumlah_setor = (select count(*) from public._anggota_pada(v_group, v_tgl))
                 - (select count(*) from student_attendance_exceptions x where x.session_id = sa.id and x.kode in ('I','S','B','A'))
  where id = v_id;

  select coalesce(jsonb_agg(jsonb_build_object('nama', s.nama_lengkap, 'tanda', l.janggal)), '[]') into v_janggal
    from memorization_logs l join students s on s.id = l.student_id where l.session_id = v_id and cardinality(l.janggal) > 0;
  return jsonb_build_object('id', v_id, 'janggal', v_janggal);
exception
  when check_violation then raise exception 'Posisi hafalan harus 0–30 juz (0–600 halaman) dan juz sedang dihafal 1–30.';
end $$;

-- ---------------------------------------------------------------------
-- 9. RIWAYAT SETORAN SEORANG SANTRI
-- ---------------------------------------------------------------------
create or replace function public.riwayat_setoran(p_santri uuid, p_mulai date default null, p_selesai date default null)
returns table (tanggal date, sesi text, nama_sesi text, halaqah text, kehadiran text, sabaq_lama smallint, sabaq_hal smallint,
               sabqi_lama smallint, sabqi_hal smallint, manzil_lama smallint, manzil_hal smallint, tambah_hal smallint,
               juz_sedang smallint, janggal text[], catatan text, pengampu text)
language sql stable security definer set search_path = public as $$
  -- Sesi setoran halaqah santri pada rentang: baris setoran bila ada; bila tidak, Sama atau Tidak setor (dari absensi)
  select m.tanggal, m.sesi, m.nama_sesi, g.nama,
         coalesce(x.kode, 'H'),
         coalesce(l.sabaq_lama, null), l.sabaq_hal, l.sabqi_lama, l.sabqi_hal, l.manzil_lama, l.manzil_hal, coalesce(l.tambah_hal, 0::smallint),
         l.juz_sedang, coalesce(l.janggal, '{}'), l.catatan, e.nama_lengkap
    from memorization_sessions m
    join student_groups g on g.id = m.group_id
    left join memorization_logs l on l.session_id = m.id and l.student_id = p_santri
    left join student_attendance_exceptions x on x.session_id = m.attendance_session_id and x.student_id = p_santri
    left join employees e on e.id = m.pengampu_id
   where p_santri in (select public.santri_terlihat())
     and p_santri in (select public._anggota_pada(m.group_id, m.tanggal))
     and m.tanggal between coalesce(p_mulai, public.hari_ini() - 30) and coalesce(p_selesai, public.hari_ini())
   order by m.tanggal desc, m.jam_mulai desc nulls last
$$;

-- ---------------------------------------------------------------------
-- 10. HAK EKSEKUSI
-- ---------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array['status_setoran(date,boolean)','detail_setoran(uuid,date,text)','simpan_setoran(jsonb)','riwayat_setoran(uuid,date,date)']
  loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['_hitung_ulang_setoran(uuid)','_ringkas_setoran(uuid)','_cek_hak_setoran(uuid,date,text,uuid)']
  loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 6 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select 'Tabel setoran (2) dengan RLS' as pemeriksaan,
       case when (select count(*) from pg_tables where schemaname = 'public' and rowsecurity
                   and tablename in ('memorization_sessions','memorization_logs')) = 2 then 'Sesuai' else 'Periksa' end as hasil
union all
select 'Kolom data awal (awal_*) di student_tahfizh',
       case when (select count(*) from information_schema.columns where table_schema = 'public' and table_name = 'student_tahfizh'
                   and column_name like 'awal\_%') = 5 then 'Sesuai' else 'Periksa' end
union all
select 'Fungsi setoran (4) tersedia',
       case when (select count(*) from pg_proc where proname in ('status_setoran','detail_setoran','simpan_setoran','riwayat_setoran')) = 4
            then 'Sesuai' else 'Periksa' end
union all
select 'Sesi halaqah terbaca dari pola presensi',
       case when exists (select 1 from public.sesi_santri_tanggal('halaqah', (select min(d)::date from generate_series(public.hari_ini(), public.hari_ini() + 7, '1 day') d
                         where exists (select 1 from public.sesi_santri_tanggal('halaqah', d::date))))) then 'Sesuai' else 'Periksa: pola MUHAFFIZH belum bersesi' end
union all
select 'Pantauan langsung setoran (realtime)',
       case when not exists (select 1 from pg_publication where pubname = 'supabase_realtime')
              or exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'memorization_sessions')
            then 'Sesuai' else 'Periksa' end
union all
select 'Migrasi 3800 sudah terpasang', case when exists (select 1 from pg_proc where proname = 'daftar_tahfizh') then 'Sesuai' else 'Periksa: jalankan 3800 dulu' end;
