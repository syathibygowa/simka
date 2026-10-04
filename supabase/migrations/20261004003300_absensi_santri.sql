-- SIMKA PRO | supabase/migrations/20261004003300_absensi_santri.sql | v1.0 | Fase 4 – Tahap 3 Absensi HISBAT | 04/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 4 · Migrasi 33: Absensi santri HISBAT — kelas, halaqah, asrama (Blueprint Bagian 17)
--   * Sesi: kelas 1×/hari (jam dari Pengaturan, bawaan 07.00–12.00, kalender sekolah); halaqah dan asrama
--     MENGIKUTI sesi pola presensi pegawai "MUHAFFIZH" (subuh, sore, malam) dan "MUSYRIF" (malam, pagi)
--   * student_attendance_sessions   : satu baris per kelompok per tanggal per sesi yang terlaksana
--   * student_attendance_exceptions : HANYA pengecualian (I, S, B, A, T); santri yang tidak tercantum = Hadir
--   * student_attendance_logs       : jejak setiap pengisian/koreksi (siapa, atas nama siapa, sebelum → sesudah)
--   * sesi_absensi()      : daftar sesi hari itu untuk pengasuh (atau semua kelompok bagi admin/pimpinan)
--   * detail_absensi()    : isi satu sesi + anggota + kebutuhan presensi pengampu
--   * simpan_absensi_santri(): satu-satunya pintu tulis (pengasuh dalam jendela sesi, koreksi sampai akhir hari;
--                           admin ber-izin absensi_atas_nama sampai 7 hari ke belakang; superadmin kapan saja)
--   * rekap_absensi_santri(): rekap per santri per jenis (Terlambat dan Bolos dihitung hadir)
-- Jalankan SETELAH migrasi 3200. Aman dijalankan ulang.
-- =====================================================================

update public.admin_capabilities set nama = 'Input dan koreksi absensi santri atas nama pengampu (Fase 4)' where kode = 'absensi_atas_nama';

insert into public.institution_settings (kunci, nilai) values
  ('absensi_santri', '{"kelas": {"mulai": "07:00", "selesai": "12:00", "kalender": "sekolah", "nama": "Absensi kelas"},
                       "pola_halaqah": "MUHAFFIZH", "pola_asrama": "MUSYRIF", "batas_atas_nama_hari": 7}')
on conflict (kunci) do nothing;

-- Hak fitur bawaan pimpinan untuk memantau absensi (lihat)
insert into public.feature_grants (feature_kode, sasaran, sasaran_id, tingkat, catatan)
select f.kode, 'struktural', sp.id, 1, 'bawaan Fase 4'
from public.structural_positions sp, (values ('absensi_kelas'), ('absensi_halaqah'), ('absensi_asrama')) f(kode)
where sp.kode in ('YAYASAN','DIREKTUR','WAKIL_DIREKTUR','KEPALA_BIDANG','WAKIL_KEPALA_BIDANG','WAKIL_KEPALA_SEKOLAH')
on conflict (feature_kode, sasaran, sasaran_id) do nothing;

-- ---------------------------------------------------------------------
-- 1. TABEL
-- ---------------------------------------------------------------------
create table if not exists public.student_attendance_sessions (
  id               uuid primary key default gen_random_uuid(),
  group_id         uuid not null references public.student_groups(id) on delete cascade,
  jenis            text not null check (jenis in ('kelas','halaqah','asrama','ekskul')),
  tanggal          date not null,
  sesi             text not null,                    -- KELAS, atau kode sesi pola (SUBUH, SORE, MALAM, PAGI, …)
  nama_sesi        text not null,
  jam_mulai        time,
  jam_selesai      time,
  pengampu_id      uuid references public.employees(id) on delete set null,   -- pengasuh yang bertanggung jawab
  diinput_oleh     uuid references public.employees(id) on delete set null,   -- yang benar-benar mengisi
  atas_nama        boolean not null default false,
  diisi_terlambat  boolean not null default false,   -- diisi/dikoreksi setelah jendela sesi
  jumlah_anggota   int not null default 0,
  jumlah_hadir     int not null default 0,           -- termasuk Terlambat dan Bolos
  jumlah_izin      int not null default 0,
  jumlah_sakit     int not null default 0,
  jumlah_bolos     int not null default 0,
  jumlah_absen     int not null default 0,
  jumlah_terlambat int not null default 0,
  catatan          text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint student_attendance_sessions_unik unique (group_id, tanggal, sesi)
);
create index if not exists sas_tanggal_idx on public.student_attendance_sessions (tanggal, jenis);

create table if not exists public.student_attendance_exceptions (
  id          uuid primary key default gen_random_uuid(),
  session_id  uuid not null references public.student_attendance_sessions(id) on delete cascade,
  student_id  uuid not null references public.students(id) on delete cascade,
  kode        text not null check (kode in ('I','S','B','A','T')),
  keterangan  text,
  unique (session_id, student_id)
);
create index if not exists sae_santri_idx on public.student_attendance_exceptions (student_id);

create table if not exists public.student_attendance_logs (
  id          uuid primary key default gen_random_uuid(),
  session_id  uuid not null references public.student_attendance_sessions(id) on delete cascade,
  waktu       timestamptz not null default now(),
  oleh        uuid references public.employees(id) on delete set null,
  atas_nama   uuid references public.employees(id) on delete set null,
  aksi        text not null check (aksi in ('isi','koreksi')),
  perubahan   jsonb not null default '[]'
);
create index if not exists sal_sesi_idx on public.student_attendance_logs (session_id, waktu desc);

drop trigger if exists aa_updated on public.student_attendance_sessions;
create trigger aa_updated before update on public.student_attendance_sessions for each row execute function public.tg_updated_at();

-- ---------------------------------------------------------------------
-- 2. SESI PER JENIS DAN TANGGAL
-- ---------------------------------------------------------------------
-- Sesi absensi santri pada satu tanggal: kode, nama, jam, jendela buka, tutup (batas tepat), batas koreksi.
create or replace function public.sesi_santri_tanggal(p_jenis text, p_tanggal date)
returns table (kode text, nama text, jam_mulai time, jam_selesai time, mulai timestamptz, selesai timestamptz,
               buka timestamptz, tutup timestamptz, batas timestamptz, urutan int)
language plpgsql stable security definer set search_path = public as $$
declare st jsonb := coalesce((select nilai from institution_settings where kunci = 'absensi_santri'), '{}'::jsonb);
  v_pola text; v_akhir_hari timestamptz := ((p_tanggal + 1)::timestamp at time zone 'Asia/Makassar') - interval '1 second';
begin
  if p_jenis = 'kelas' then
    if public.libur_tugas(p_tanggal, coalesce(st->'kelas'->>'kalender', 'sekolah')) then return; end if;
    return query select 'KELAS'::text, coalesce(st->'kelas'->>'nama', 'Absensi kelas'),
      (st->'kelas'->>'mulai')::time, (st->'kelas'->>'selesai')::time,
      (p_tanggal + (st->'kelas'->>'mulai')::time)::timestamp at time zone 'Asia/Makassar',
      (p_tanggal + (st->'kelas'->>'selesai')::time)::timestamp at time zone 'Asia/Makassar',
      (p_tanggal + (st->'kelas'->>'mulai')::time)::timestamp at time zone 'Asia/Makassar',
      (p_tanggal + (st->'kelas'->>'selesai')::time)::timestamp at time zone 'Asia/Makassar',
      v_akhir_hari, 1;
    return;
  end if;
  v_pola := case p_jenis when 'halaqah' then coalesce(st->>'pola_halaqah', 'MUHAFFIZH') when 'asrama' then coalesce(st->>'pola_asrama', 'MUSYRIF') end;
  if v_pola is null then return; end if;
  return query
    with d as (
      select s.kode as k, s.nama as n, s.jam_mulai as jm, s.jam_selesai as js, s.buka_menit, s.tutup_menit, s.urutan as u,
             ((p_tanggal + s.jam_mulai)::timestamp at time zone 'Asia/Makassar') as t0,
             ((p_tanggal + s.jam_selesai + case when s.jam_selesai <= s.jam_mulai then interval '1 day' else interval '0' end)::timestamp
               at time zone 'Asia/Makassar') as t1
      from task_patterns p join pattern_sessions s on s.pattern_id = p.id and s.aktif and not s.opsional
      where p.kode = v_pola and p.aktif and extract(dow from p_tanggal)::smallint = any(s.hari)
        and not public.libur_tugas(p_tanggal, p.kalender))
    select d.k, d.n, d.jm, d.js, d.t0, d.t1, d.t0 - make_interval(mins => d.buka_menit),
           d.t1 + make_interval(mins => least(d.tutup_menit, 60)),
           greatest(d.t1 + make_interval(mins => least(d.tutup_menit, 60)), v_akhir_hari), d.u
    from d order by d.t0;
end $$;

-- Pengasuh kelompok yang berlaku pada tanggal tertentu
create or replace function public._pengasuh_berlaku(p_group uuid, p_tanggal date)
returns setof uuid language sql stable security definer set search_path = public as $$
  select employee_id from group_keepers
  where group_id = p_group and (mulai is null or mulai <= p_tanggal) and (sampai is null or sampai >= p_tanggal)
$$;

-- Anggota aktif kelompok pada tanggal tertentu
create or replace function public._anggota_pada(p_group uuid, p_tanggal date)
returns setof uuid language sql stable security definer set search_path = public as $$
  select m.student_id from group_members m join students s on s.id = m.student_id
  where m.group_id = p_group and m.mulai <= p_tanggal and (m.selesai is null or m.selesai > p_tanggal
        or (m.selesai = p_tanggal and m.alasan_keluar not like 'Pindah ke %'))
    and s.status in ('aktif','nonaktif')
$$;

create or replace function public.boleh_pantau_absensi()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_admin() or public.tingkat_fitur('absensi_kelas') >= 1 and public.tingkat_fitur('data_santri') >= 1
$$;

-- ---------------------------------------------------------------------
-- 3. RLS (hanya baca)
-- ---------------------------------------------------------------------
alter table public.student_attendance_sessions enable row level security;
alter table public.student_attendance_exceptions enable row level security;
alter table public.student_attendance_logs enable row level security;
drop policy if exists sesi_baca on public.student_attendance_sessions;
create policy sesi_baca on public.student_attendance_sessions for select to authenticated using (group_id in (select id from public.student_groups));
drop policy if exists pengecualian_baca on public.student_attendance_exceptions;
create policy pengecualian_baca on public.student_attendance_exceptions for select to authenticated
  using (student_id in (select public.santri_terlihat()));
drop policy if exists log_baca on public.student_attendance_logs;
create policy log_baca on public.student_attendance_logs for select to authenticated
  using ((select public.is_admin()) or session_id in (select id from public.student_attendance_sessions));

-- ---------------------------------------------------------------------
-- 4. DAFTAR SESI (pengasuh: kelompok asuhannya; p_semua: semua kelompok bagi admin/pimpinan)
-- ---------------------------------------------------------------------
create or replace function public.sesi_absensi(p_tanggal date default null, p_semua boolean default false)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_tgl date := coalesce(p_tanggal, public.hari_ini()); v_saya uuid := public.saya(); v_kini timestamptz := now(); hasil jsonb;
begin
  if v_saya is null then return '[]'::jsonb; end if;
  if p_semua and not public.boleh_pantau_absensi() then
    raise exception 'Anda tidak berwenang memantau absensi semua kelompok.' using errcode = '42501';
  end if;
  select coalesce(jsonb_agg(x order by x->>'mulai', x->>'urutan_jenis', x->>'nama_kelompok'), '[]'::jsonb) into hasil from (
    select jsonb_build_object(
      'group_id', g.id, 'jenis', case g.jenis when 'kamar' then 'asrama' else g.jenis end, 'jenis_kelompok', g.jenis,
      'nama_kelompok', g.nama, 'jenis_kelamin', g.jenis_kelamin, 'tanggal', v_tgl,
      'sesi', ss.kode, 'nama_sesi', ss.nama, 'jam_mulai', ss.jam_mulai, 'jam_selesai', ss.jam_selesai,
      'mulai', ss.mulai, 'selesai', ss.selesai, 'buka', ss.buka, 'tutup', ss.tutup, 'batas', ss.batas,
      'urutan_jenis', array_position(array['kelas','halaqah','kamar'], g.jenis),
      'status', case when sa.id is not null then 'terisi' when v_kini < ss.buka then 'belum_buka'
                     when v_kini <= ss.tutup then 'terbuka' when v_kini <= ss.batas then 'lewat' else 'tidak_terisi' end,
      'session_id', sa.id, 'jumlah_anggota', coalesce(sa.jumlah_anggota, (select count(*) from public._anggota_pada(g.id, v_tgl))),
      'jumlah_hadir', sa.jumlah_hadir, 'jumlah_izin', sa.jumlah_izin, 'jumlah_sakit', sa.jumlah_sakit,
      'jumlah_bolos', sa.jumlah_bolos, 'jumlah_absen', sa.jumlah_absen, 'jumlah_terlambat', sa.jumlah_terlambat,
      'atas_nama', sa.atas_nama, 'diisi_terlambat', sa.diisi_terlambat, 'diisi_pada', sa.updated_at,
      'asuhan_saya', v_saya in (select public._pengasuh_berlaku(g.id, v_tgl)),
      'pengampu', (select string_agg(e.nama_lengkap, ', ' order by k.peran, e.nama_lengkap) from group_keepers k join employees e on e.id = k.employee_id
                   where k.group_id = g.id and k.employee_id in (select public._pengasuh_berlaku(g.id, v_tgl)))) as x
    from student_groups g
    join academic_years a on a.id = g.academic_year_id and a.aktif
    cross join lateral public.sesi_santri_tanggal(case g.jenis when 'kamar' then 'asrama' else g.jenis end, v_tgl) ss
    left join student_attendance_sessions sa on sa.group_id = g.id and sa.tanggal = v_tgl and sa.sesi = ss.kode
    where g.aktif and g.jenis in ('kelas','halaqah','kamar')
      and ((p_semua) or v_saya in (select public._pengasuh_berlaku(g.id, v_tgl)))
  ) t;
  return hasil;
end $$;

-- ---------------------------------------------------------------------
-- 5. DETAIL SATU SESI (untuk formulir pengisian)
-- ---------------------------------------------------------------------
create or replace function public.detail_absensi(p_group uuid, p_tanggal date, p_sesi text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare g student_groups; v_jenis text; ss record; sa student_attendance_sessions; v_saya uuid := public.saya();
  v_pengasuh boolean; v_perlu boolean := false; v_pola text; st jsonb;
begin
  select * into g from student_groups where id = p_group;
  if not found then raise exception 'Kelompok tidak ditemukan.'; end if;
  v_pengasuh := v_saya in (select public._pengasuh_berlaku(p_group, p_tanggal));
  if not (v_pengasuh or public.boleh_pantau_absensi()) then
    raise exception 'Anda bukan pengasuh kelompok ini.' using errcode = '42501';
  end if;
  v_jenis := case g.jenis when 'kamar' then 'asrama' else g.jenis end;
  select * into ss from public.sesi_santri_tanggal(v_jenis, p_tanggal) x where x.kode = p_sesi;
  if not found then raise exception 'Tidak ada sesi % pada tanggal ini (hari libur atau sesi tidak berlaku).', p_sesi; end if;
  select * into sa from student_attendance_sessions where group_id = p_group and tanggal = p_tanggal and sesi = p_sesi;
  -- Presensi pengampu (halaqah dan asrama): diminta bila sesi ini ada di jadwal presensinya dan belum presensi
  if v_pengasuh and v_jenis in ('halaqah','asrama') then
    st := coalesce((select nilai from institution_settings where kunci = 'absensi_santri'), '{}'::jsonb);
    v_pola := case v_jenis when 'halaqah' then coalesce(st->>'pola_halaqah', 'MUHAFFIZH') else coalesce(st->>'pola_asrama', 'MUSYRIF') end;
    select exists (select 1 from public.jadwal_pegawai(v_saya, p_tanggal) j join task_patterns tp on tp.id = j.pattern_id
                   where tp.kode = v_pola and j.kode_sesi = p_sesi
                     and not exists (select 1 from attendances at where at.employee_id = v_saya and at.tanggal = p_tanggal
                                      and at.session_id = j.session_id
                                      and at.status in ('hadir','terlambat','dinas_luar','menunggu_verval')))
      into v_perlu;
  end if;
  return jsonb_build_object(
    'kelompok', jsonb_build_object('id', g.id, 'nama', g.nama, 'jenis', g.jenis, 'jenis_kelamin', g.jenis_kelamin, 'tingkat', g.tingkat, 'jenjang', g.jenjang,
                                   'wa_wali', g.wa_wali, 'naqib_id', g.naqib_id),
    'jenis', v_jenis, 'tanggal', p_tanggal, 'sesi', ss.kode, 'nama_sesi', ss.nama, 'jam_mulai', ss.jam_mulai, 'jam_selesai', ss.jam_selesai,
    'buka', ss.buka, 'tutup', ss.tutup, 'batas', ss.batas, 'sekarang', now(),
    'pengasuh_saya', v_pengasuh, 'perlu_presensi', v_perlu,
    'boleh_atas_nama', public.admin_boleh('absensi_atas_nama'),
    'pengasuh', coalesce((select jsonb_agg(jsonb_build_object('employee_id', e.id, 'nama', e.nama_lengkap, 'peran', k.peran) order by k.peran)
                 from group_keepers k join employees e on e.id = k.employee_id
                 where k.group_id = p_group and k.employee_id in (select public._pengasuh_berlaku(p_group, p_tanggal))), '[]'),
    'anggota', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'nis', s.nis, 'nama', s.nama_lengkap, 'jenis_kelamin', s.jenis_kelamin,
                                    'status', s.status) order by s.nama_lengkap)
                from students s where s.id in (select public._anggota_pada(p_group, p_tanggal))), '[]'),
    'sesi_tercatat', case when sa.id is null then null else jsonb_build_object('id', sa.id, 'atas_nama', sa.atas_nama, 'diisi_terlambat', sa.diisi_terlambat,
       'catatan', sa.catatan, 'diisi_pada', sa.updated_at,
       'pengampu', (select nama_lengkap from employees where id = sa.pengampu_id), 'diinput_oleh', (select nama_lengkap from employees where id = sa.diinput_oleh)) end,
    'pengecualian', coalesce((select jsonb_agg(jsonb_build_object('student_id', x.student_id, 'kode', x.kode, 'keterangan', x.keterangan))
                     from student_attendance_exceptions x where x.session_id = sa.id), '[]'),
    'log', coalesce((select jsonb_agg(jsonb_build_object('waktu', l.waktu, 'aksi', l.aksi, 'oleh', (select nama_lengkap from employees where id = l.oleh),
                     'atas_nama', (select nama_lengkap from employees where id = l.atas_nama), 'perubahan', l.perubahan) order by l.waktu desc)
             from student_attendance_logs l where l.session_id = sa.id), '[]'));
end $$;

-- ---------------------------------------------------------------------
-- 6. SIMPAN ABSENSI (satu-satunya pintu tulis)
-- ---------------------------------------------------------------------
-- p: {group_id, tanggal, sesi, pengecualian: [{student_id, kode, keterangan}], catatan?, atas_nama_id?}
create or replace function public.simpan_absensi_santri(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_group uuid := (p->>'group_id')::uuid; v_tgl date := (p->>'tanggal')::date; v_sesi text := p->>'sesi';
  g student_groups; v_jenis text; ss record; v_saya uuid := public.saya(); v_pengasuh boolean; v_atas boolean := false;
  v_pengampu uuid; v_id uuid; v_lama jsonb; v_baru jsonb; v_ubah jsonb; v_batas_hari int; v_kini timestamptz := now();
  r jsonb; st jsonb := coalesce((select nilai from institution_settings where kunci = 'absensi_santri'), '{}'::jsonb);
begin
  if v_saya is null then raise exception 'Sesi masuk tidak berlaku. Silakan masuk ulang.' using errcode = '42501'; end if;
  select * into g from student_groups where id = v_group;
  if not found or not g.aktif then raise exception 'Kelompok tidak ditemukan atau nonaktif.'; end if;
  if g.jenis not in ('kelas','halaqah','kamar') then raise exception 'Absensi ekskul diisi di menu Ekskul.'; end if;
  if not exists (select 1 from academic_years where id = g.academic_year_id and aktif and not terkunci) then
    raise exception 'Kelompok ini bukan milik tahun ajaran aktif.';
  end if;
  v_jenis := case g.jenis when 'kamar' then 'asrama' else g.jenis end;
  select * into ss from public.sesi_santri_tanggal(v_jenis, v_tgl) x where x.kode = v_sesi;
  if not found then raise exception 'Tidak ada sesi % pada tanggal ini (hari libur atau sesi tidak berlaku).', v_sesi; end if;
  v_pengasuh := v_saya in (select public._pengasuh_berlaku(v_group, v_tgl));

  if v_pengasuh and not (nullif(p->>'atas_nama_id', '') is not null and public.admin_boleh('absensi_atas_nama')) then
    if v_kini < ss.buka then raise exception 'Absensi % belum dibuka. Dibuka pukul %.', ss.nama, to_char(ss.buka at time zone 'Asia/Makassar', 'HH24.MI'); end if;
    if v_kini > ss.batas then raise exception 'Batas pengisian dan koreksi absensi ini sudah lewat. Hubungi admin untuk input atas nama.'; end if;
    v_pengampu := v_saya;
  elsif public.admin_boleh('absensi_atas_nama') then
    v_batas_hari := coalesce((st->>'batas_atas_nama_hari')::int, 7);
    if v_kini < ss.buka then raise exception 'Sesi ini belum dibuka.'; end if;
    if not public.is_superadmin() and v_tgl < public.hari_ini() - v_batas_hari then
      raise exception 'Input atas nama paling lama % hari ke belakang. Hubungi superadmin.', v_batas_hari;
    end if;
    v_atas := true;
    v_pengampu := coalesce(nullif(p->>'atas_nama_id', '')::uuid,
      (select k.employee_id from group_keepers k where k.group_id = v_group and k.employee_id in (select public._pengasuh_berlaku(v_group, v_tgl))
        order by array_position(array['utama','pendamping','pengganti'], k.peran) limit 1));
    if v_pengampu is not null and v_pengampu not in (select public._pengasuh_berlaku(v_group, v_tgl)) then
      raise exception 'Pegawai yang dipilih bukan pengasuh kelompok ini pada tanggal tersebut.';
    end if;
  else
    raise exception 'Anda bukan pengasuh kelompok ini.' using errcode = '42501';
  end if;

  -- Validasi pengecualian
  for r in select * from jsonb_array_elements(coalesce(p->'pengecualian', '[]')) loop
    if r->>'kode' not in ('I','S','B','A','T') then raise exception 'Kode absensi harus H, I, S, B, A, atau T.'; end if;
    if r->>'student_id' is null or (r->>'student_id')::uuid not in (select public._anggota_pada(v_group, v_tgl)) then
      raise exception 'Ada santri yang bukan anggota % pada tanggal ini.', g.nama;
    end if;
  end loop;

  select id into v_id from student_attendance_sessions where group_id = v_group and tanggal = v_tgl and sesi = v_sesi for update;
  select coalesce(jsonb_object_agg(student_id::text, jsonb_build_object('kode', kode, 'keterangan', keterangan)), '{}') into v_lama
  from student_attendance_exceptions where session_id = v_id;
  select coalesce(jsonb_object_agg(x->>'student_id', jsonb_build_object('kode', x->>'kode', 'keterangan', nullif(trim(coalesce(x->>'keterangan', '')), ''))), '{}') into v_baru
  from jsonb_array_elements(coalesce(p->'pengecualian', '[]')) x;

  if v_id is null then
    insert into student_attendance_sessions (group_id, jenis, tanggal, sesi, nama_sesi, jam_mulai, jam_selesai, pengampu_id, diinput_oleh, atas_nama, diisi_terlambat, catatan)
    values (v_group, v_jenis, v_tgl, v_sesi, ss.nama, ss.jam_mulai, ss.jam_selesai, v_pengampu, v_saya, v_atas, v_kini > ss.tutup, nullif(trim(p->>'catatan'), ''))
    returning id into v_id;
  else
    update student_attendance_sessions set diinput_oleh = v_saya, atas_nama = atas_nama or v_atas,
      pengampu_id = coalesce(pengampu_id, v_pengampu), diisi_terlambat = diisi_terlambat or v_kini > ss.tutup,
      catatan = nullif(trim(p->>'catatan'), '')
    where id = v_id;
  end if;

  delete from student_attendance_exceptions where session_id = v_id;
  insert into student_attendance_exceptions (session_id, student_id, kode, keterangan)
  select v_id, (x->>'student_id')::uuid, x->>'kode', nullif(trim(coalesce(x->>'keterangan', '')), '')
  from jsonb_array_elements(coalesce(p->'pengecualian', '[]')) x;

  update student_attendance_sessions sa set
    jumlah_anggota = (select count(*) from public._anggota_pada(v_group, v_tgl)),
    jumlah_izin = (select count(*) from student_attendance_exceptions where session_id = v_id and kode = 'I'),
    jumlah_sakit = (select count(*) from student_attendance_exceptions where session_id = v_id and kode = 'S'),
    jumlah_bolos = (select count(*) from student_attendance_exceptions where session_id = v_id and kode = 'B'),
    jumlah_absen = (select count(*) from student_attendance_exceptions where session_id = v_id and kode = 'A'),
    jumlah_terlambat = (select count(*) from student_attendance_exceptions where session_id = v_id and kode = 'T')
  where id = v_id;
  update student_attendance_sessions set jumlah_hadir = jumlah_anggota - jumlah_izin - jumlah_sakit - jumlah_absen where id = v_id;

  -- Log perubahan (santri yang kodenya berubah)
  select coalesce(jsonb_agg(jsonb_build_object('student_id', k, 'nama', (select nama_lengkap from students where id = k::uuid),
           'lama', coalesce(v_lama->k->>'kode', 'H'), 'baru', coalesce(v_baru->k->>'kode', 'H'))), '[]') into v_ubah
  from (select jsonb_object_keys(v_lama) k union select jsonb_object_keys(v_baru)) z
  where coalesce(v_lama->k->>'kode', 'H') is distinct from coalesce(v_baru->k->>'kode', 'H')
     or (v_lama->k->>'keterangan') is distinct from (v_baru->k->>'keterangan');
  insert into student_attendance_logs (session_id, oleh, atas_nama, aksi, perubahan)
  values (v_id, v_saya, case when v_atas then v_pengampu end,
          case when exists (select 1 from student_attendance_logs where session_id = v_id) then 'koreksi' else 'isi' end, v_ubah);
  return v_id;
end $$;

-- ---------------------------------------------------------------------
-- 7. REKAP PER SANTRI
-- ---------------------------------------------------------------------
-- Hadir = sesi − Izin − Sakit − Absen (Terlambat dan Bolos dihitung hadir). Hanya sesi yang terlaksana (tercatat).
create or replace function public.rekap_absensi_santri(p_mulai date, p_selesai date, p_group uuid default null,
  p_jenis text default null, p_santri uuid default null)
returns table (student_id uuid, jenis text, sesi int, hadir int, izin int, sakit int, bolos int, absen int, terlambat int)
language sql stable security definer set search_path = public as $$
  with sesi as (
    select sa.id, sa.group_id, sa.jenis, sa.tanggal from student_attendance_sessions sa
    where sa.tanggal between p_mulai and p_selesai and (p_group is null or sa.group_id = p_group) and (p_jenis is null or sa.jenis = p_jenis)
  ), ikut as (
    select s.id as sid, s.jenis, a.sa_student as student_id from sesi s
    cross join lateral (select x as sa_student from public._anggota_pada(s.group_id, s.tanggal) x) a
  )
  select i.student_id, i.jenis, count(*)::int,
         (count(*) - count(*) filter (where e.kode in ('I','S','A')))::int,
         count(*) filter (where e.kode = 'I')::int, count(*) filter (where e.kode = 'S')::int,
         count(*) filter (where e.kode = 'B')::int, count(*) filter (where e.kode = 'A')::int,
         count(*) filter (where e.kode = 'T')::int
  from ikut i left join student_attendance_exceptions e on e.session_id = i.sid and e.student_id = i.student_id
  where i.student_id in (select public.santri_terlihat()) and (p_santri is null or i.student_id = p_santri)
  group by i.student_id, i.jenis
$$;

-- Riwayat pengecualian satu santri (untuk biodata/profil): tanggal, kegiatan, kode
create or replace function public.riwayat_absensi_santri(p_santri uuid, p_mulai date, p_selesai date)
returns table (tanggal date, jenis text, kelompok text, nama_sesi text, kode text, keterangan text)
language sql stable security definer set search_path = public as $$
  select sa.tanggal, sa.jenis, g.nama, sa.nama_sesi, e.kode, e.keterangan
  from student_attendance_exceptions e join student_attendance_sessions sa on sa.id = e.session_id join student_groups g on g.id = sa.group_id
  where e.student_id = p_santri and p_santri in (select public.santri_terlihat()) and sa.tanggal between p_mulai and p_selesai
  order by sa.tanggal desc, sa.jam_mulai desc
$$;

-- ---------------------------------------------------------------------
-- 8. TEMPLATE WA KE WALI
-- ---------------------------------------------------------------------
insert into public.wa_templates (kode, nama, isi, variabel, keterangan) values
  ('absen_santri', 'Ketidakhadiran santri',
   E'{salam}, Bapak/Ibu {nama_wali}.\n\nKami informasikan bahwa ananda *{nama_santri}* ({kelas}) tercatat *{status}* pada {kegiatan}, {tanggal}.\n{keterangan}\n\nMohon perhatian dan kerja samanya.\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
   '{nama_wali,nama_santri,kelas,status,kegiatan,tanggal,keterangan,pengirim}', 'Absensi Santri: kabari wali santri yang tidak hadir (Izin, Sakit, Bolos, Absen, Terlambat).'),
  ('rekap_santri', 'Rekap kehadiran santri',
   E'{salam}, Bapak/Ibu {nama_wali}.\n\nRekap kehadiran ananda *{nama_santri}* ({kelas}) periode {periode}:\n{rekap}\n\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
   '{nama_wali,nama_santri,kelas,periode,rekap,pengirim}', 'Absensi Santri → Rekap: rekap pekanan/bulanan ke wali.')
on conflict (kode) do nothing;

do $$
declare f text;
begin
  foreach f in array array['sesi_santri_tanggal(text,date)','boleh_pantau_absensi()','sesi_absensi(date,boolean)','detail_absensi(uuid,date,text)',
    'simpan_absensi_santri(jsonb)','rekap_absensi_santri(date,date,uuid,text,uuid)','riwayat_absensi_santri(uuid,date,date)']
  loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  execute 'revoke execute on function public._pengasuh_berlaku(uuid,date) from public, anon, authenticated';
  execute 'revoke execute on function public._anggota_pada(uuid,date) from public, anon, authenticated';
end $$;

do $$ begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'student_attendance_sessions') then
    alter publication supabase_realtime add table public.student_attendance_sessions;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 6 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select 'Tabel absensi santri (3) dengan RLS' as pemeriksaan,
       case when (select count(*) from pg_tables where schemaname = 'public' and rowsecurity
                   and tablename in ('student_attendance_sessions','student_attendance_exceptions','student_attendance_logs')) = 3 then 'Sesuai' else 'Periksa' end as hasil
union all
select 'Tabel absensi tidak dapat ditulis langsung',
       case when not exists (select 1 from pg_policies where schemaname = 'public' and cmd <> 'SELECT'
                              and tablename in ('student_attendance_sessions','student_attendance_exceptions','student_attendance_logs')) then 'Sesuai' else 'Periksa' end
union all
select 'Sesi halaqah mengikuti pola MUHAFFIZH (hari Senin: 3 sesi)',
       case when (select count(*) from public.sesi_santri_tanggal('halaqah', date '2026-10-05')) = 3 then 'Sesuai'
            else 'Periksa: ' || (select count(*) from public.sesi_santri_tanggal('halaqah', date '2026-10-05')) || ' sesi (pola diubah?)' end
union all
select 'Sesi asrama mengikuti pola MUSYRIF (hari Senin: 2 sesi)',
       case when (select count(*) from public.sesi_santri_tanggal('asrama', date '2026-10-05')) = 2 then 'Sesuai'
            else 'Periksa: ' || (select count(*) from public.sesi_santri_tanggal('asrama', date '2026-10-05')) || ' sesi (pola diubah?)' end
union all
select 'Template WA ke wali (2)',
       case when (select count(*) from public.wa_templates where kode in ('absen_santri','rekap_santri')) = 2 then 'Sesuai' else 'Periksa' end
union all
select 'Migrasi 3200 sudah terpasang',
       case when exists (select 1 from information_schema.columns where table_name = 'students' and column_name = 'no_kk') then 'Sesuai' else 'Periksa: jalankan 3200 dulu' end;
