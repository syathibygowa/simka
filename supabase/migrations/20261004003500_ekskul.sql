-- SIMKA PRO | supabase/migrations/20261004003500_ekskul.sql | v1.0 | Fase 4 – Tahap 4 Ekskul | 04/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 4 · Migrasi 35: Ekskul — jadwal pertemuan, presensi pembina, absensi HISBAT, jurnal materi (Bagian 18)
--   * extracurricular_schedules : jadwal pertemuan per ekskul (hari, jam, tempat). Setiap baris jadwal otomatis
--                                 menjadi sesi pola presensi "EKSKUL" dan masuk jadwal presensi pembina/pelatihnya
--   * extracurricular_journals  : jurnal materi per pertemuan (topik wajib, uraian, foto opsional ke Drive)
--   * Jabatan fungsional baru "Pelatih ekskul (luar)" (pola EKSKUL; berakun dan presensi GPS — keputusan pemilik proyek)
--   * sesi_kelompok(): sesi absensi satu kelompok (kelas/halaqah/asrama dari pengaturan; ekskul dari jadwal)
--   * sesi_absensi, detail_absensi, simpan_absensi_santri diperbarui: ekskul ikut, jurnal materi wajib
--   * jurnal_ekskul(): daftar pertemuan + jurnal untuk rekap. Ekskul tidak memengaruhi program pokok.
-- Jalankan SETELAH migrasi 3400. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. JABATAN PELATIH LUAR
-- ---------------------------------------------------------------------
insert into public.functional_positions (kode, nama, jenis_sesi, tanpa_rangkap, pengasuh, urutan, pola_id)
select 'PELATIH_EKSKUL', 'Pelatih ekskul (luar)', 'sesi', false, true, 15, (select id from public.task_patterns where kode = 'EKSKUL')
on conflict (kode) do nothing;
insert into public.feature_grants (feature_kode, sasaran, sasaran_id, tingkat, catatan)
select v.f, 'fungsional', fp.id, v.t, 'bawaan Fase 4'
from public.functional_positions fp, (values ('absensi_ekskul', 2), ('presensi', 2)) v(f, t)
where fp.kode = 'PELATIH_EKSKUL'
on conflict (feature_kode, sasaran, sasaran_id) do nothing;
insert into public.feature_grants (feature_kode, sasaran, sasaran_id, tingkat, catatan)
select 'absensi_ekskul', 'struktural', sp.id, 1, 'bawaan Fase 4'
from public.structural_positions sp
where sp.kode in ('YAYASAN','DIREKTUR','WAKIL_DIREKTUR','KEPALA_BIDANG','WAKIL_KEPALA_BIDANG','WAKIL_KEPALA_SEKOLAH')
on conflict (feature_kode, sasaran, sasaran_id) do nothing;

-- Hari ekskul ditentukan jadwal pertemuannya sendiri (boleh hari Ahad); hanya libur pondok yang berlaku semua.
update public.task_patterns set kalender = null, catatan = 'Sesi dibuat otomatis dari jadwal pertemuan ekskul (menu Ekskul)'
where kode = 'EKSKUL';

-- ---------------------------------------------------------------------
-- 2. TABEL
-- ---------------------------------------------------------------------
create table if not exists public.extracurricular_schedules (
  id          uuid primary key default gen_random_uuid(),
  group_id    uuid not null references public.student_groups(id) on delete cascade,
  hari        smallint not null check (hari between 0 and 6),        -- 0 = Ahad
  jam_mulai   time not null,
  jam_selesai time not null,
  tempat      text,
  session_id  uuid references public.pattern_sessions(id) on delete set null,   -- sesi presensi pembina
  aktif       boolean not null default true,
  created_at  timestamptz not null default now(),
  constraint extracurricular_schedules_jam check (jam_selesai > jam_mulai)
);
create index if not exists ekskul_jadwal_idx on public.extracurricular_schedules (group_id);

create table if not exists public.extracurricular_journals (
  id          uuid primary key default gen_random_uuid(),
  session_id  uuid not null unique references public.student_attendance_sessions(id) on delete cascade,
  topik       text not null,
  uraian      text,
  foto_id     uuid references public.storage_objects(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table public.extracurricular_schedules enable row level security;
alter table public.extracurricular_journals enable row level security;
drop policy if exists jadwal_ekskul_baca on public.extracurricular_schedules;
create policy jadwal_ekskul_baca on public.extracurricular_schedules for select to authenticated using (group_id in (select id from public.student_groups));
drop policy if exists jurnal_ekskul_baca on public.extracurricular_journals;
create policy jurnal_ekskul_baca on public.extracurricular_journals for select to authenticated using (session_id in (select id from public.student_attendance_sessions));

-- Tingkat fitur untuk pegawai tertentu (dipakai pemeriksaan berkas)
create or replace function public.tingkat_fitur_pegawai(p_emp uuid, p_kode text)
returns smallint language sql stable security definer set search_path = public as $$
  select coalesce((select efektif from public.rincian_akses(p_emp) where kode = p_kode), 0)::smallint
$$;
revoke execute on function public.tingkat_fitur_pegawai(uuid,text) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 3. SESI PER KELOMPOK
-- ---------------------------------------------------------------------
create or replace function public.kode_sesi_ekskul(p_id uuid)
returns text language sql immutable as $$ select 'EKS_' || upper(left(replace(p_id::text, '-', ''), 8)) $$;

-- Sesi absensi satu kelompok pada satu tanggal. Ekskul: dari jadwal pertemuan (hanya libur pondok yang berlaku semua).
create or replace function public.sesi_kelompok(p_group uuid, p_tanggal date)
returns table (kode text, nama text, jam_mulai time, jam_selesai time, mulai timestamptz, selesai timestamptz,
               buka timestamptz, tutup timestamptz, batas timestamptz, urutan int, tempat text, session_id uuid)
language plpgsql stable security definer set search_path = public as $$
declare g student_groups; v_akhir timestamptz := ((p_tanggal + 1)::timestamp at time zone 'Asia/Makassar') - interval '1 second';
begin
  select * into g from student_groups where id = p_group;
  if not found then return; end if;
  if g.jenis = 'ekskul' then
    if public.libur_tugas(p_tanggal, null) then return; end if;
    return query
      select public.kode_sesi_ekskul(j.id), 'Pertemuan ekskul'::text, j.jam_mulai, j.jam_selesai,
             (p_tanggal + j.jam_mulai)::timestamp at time zone 'Asia/Makassar',
             (p_tanggal + j.jam_selesai)::timestamp at time zone 'Asia/Makassar',
             ((p_tanggal + j.jam_mulai)::timestamp at time zone 'Asia/Makassar') - interval '30 minutes',
             ((p_tanggal + j.jam_selesai)::timestamp at time zone 'Asia/Makassar') + interval '60 minutes',
             greatest(((p_tanggal + j.jam_selesai)::timestamp at time zone 'Asia/Makassar') + interval '60 minutes', v_akhir),
             1, j.tempat, j.session_id
      from extracurricular_schedules j
      where j.group_id = p_group and j.aktif and j.hari = extract(dow from p_tanggal)::smallint
      order by j.jam_mulai;
    return;
  end if;
  if g.jenis not in ('kelas','halaqah','kamar') then return; end if;
  return query select x.kode, x.nama, x.jam_mulai, x.jam_selesai, x.mulai, x.selesai, x.buka, x.tutup, x.batas, x.urutan,
                      null::text, null::uuid
    from public.sesi_santri_tanggal(case g.jenis when 'kamar' then 'asrama' else g.jenis end, p_tanggal) x;
end $$;
revoke execute on function public.sesi_kelompok(uuid,date) from public, anon;
grant execute on function public.sesi_kelompok(uuid,date) to authenticated;

-- ---------------------------------------------------------------------
-- 4. SINKRON JADWAL EKSKUL → PRESENSI PEMBINA
-- ---------------------------------------------------------------------
-- Setiap jadwal pertemuan = satu sesi pola EKSKUL (hari dan jam sama). Pembina/pelatih (pengasuh utama dan pendamping
-- ekskul aktif) mendapat jadwal presensi tepat pada sesi ekskul yang diampunya.
create or replace function public.sinkron_sesi_ekskul()
returns void language plpgsql volatile security definer set search_path = public as $$
declare v_pola uuid; j record; v_sid uuid; e record; v_sesi uuid[];
begin
  select id into v_pola from task_patterns where kode = 'EKSKUL';
  if v_pola is null then return; end if;
  for j in select s.*, g.nama as nama_g, (g.aktif and a.aktif) as hidup
           from extracurricular_schedules s join student_groups g on g.id = s.group_id join academic_years a on a.id = g.academic_year_id loop
    if j.session_id is null or not exists (select 1 from pattern_sessions where id = j.session_id) then
      insert into pattern_sessions (pattern_id, kode, nama, hari, jam_mulai, jam_selesai, buka_menit, toleransi_terlambat_menit, tutup_menit,
                                    wajib_pulang, opsional, label_datang, label_pulang, aktif, urutan)
      values (v_pola, public.kode_sesi_ekskul(j.id), left('Ekskul ' || j.nama_g, 60), array[j.hari], j.jam_mulai, j.jam_selesai, 30, 10, 60,
              false, false, 'Hadir', 'Selesai', j.aktif and j.hidup, 50)
      returning id into v_sid;
      update extracurricular_schedules set session_id = v_sid where id = j.id;
    else
      update pattern_sessions set nama = left('Ekskul ' || j.nama_g, 60), hari = array[j.hari], jam_mulai = j.jam_mulai,
        jam_selesai = j.jam_selesai, aktif = j.aktif and j.hidup
      where id = j.session_id;
    end if;
  end loop;
  -- Sesi ekskul yang jadwalnya sudah dihapus dinonaktifkan (riwayat presensi tetap)
  update pattern_sessions ps set aktif = false
  where ps.pattern_id = v_pola and ps.kode like 'EKS\_%' and ps.aktif
    and not exists (select 1 from extracurricular_schedules s where s.session_id = ps.id);
  -- Jadwal presensi pembina/pelatih
  for e in select distinct x.employee_id from (
             select k.employee_id from group_keepers k join student_groups g on g.id = k.group_id where g.jenis = 'ekskul'
             union select es.employee_id from employee_schedules es where es.pattern_id = v_pola) x loop
    select coalesce(array_agg(distinct s.session_id) filter (where s.session_id is not null), '{}') into v_sesi
    from group_keepers k join student_groups g on g.id = k.group_id and g.jenis = 'ekskul' and g.aktif
    join academic_years a on a.id = g.academic_year_id and a.aktif
    join extracurricular_schedules s on s.group_id = g.id and s.aktif
    where k.employee_id = e.employee_id and k.peran in ('utama','pendamping');
    if cardinality(v_sesi) > 0 then
      insert into employee_schedules (employee_id, pattern_id, sumber, sesi_dipegang, aktif, catatan)
      values (e.employee_id, v_pola, 'manual', v_sesi, true, 'Otomatis dari jadwal ekskul')
      on conflict (employee_id, pattern_id) do update set sesi_dipegang = excluded.sesi_dipegang, aktif = true;
    else
      update employee_schedules set aktif = false, sesi_dipegang = '{}' where employee_id = e.employee_id and pattern_id = v_pola;
    end if;
  end loop;
end $$;
revoke execute on function public.sinkron_sesi_ekskul() from public, anon, authenticated;

create or replace function public.tg_sinkron_ekskul()
returns trigger language plpgsql security definer set search_path = public as $$
begin perform public.sinkron_sesi_ekskul(); return null; end $$;
drop trigger if exists zz_sinkron_ekskul on public.extracurricular_schedules;
create trigger zz_sinkron_ekskul after insert or update or delete on public.extracurricular_schedules
  for each statement execute function public.tg_sinkron_ekskul();
drop trigger if exists zz_sinkron_ekskul on public.group_keepers;
create trigger zz_sinkron_ekskul after insert or update or delete on public.group_keepers
  for each statement execute function public.tg_sinkron_ekskul();
drop trigger if exists zz_sinkron_ekskul on public.student_groups;
create trigger zz_sinkron_ekskul after update of aktif, nama on public.student_groups
  for each statement execute function public.tg_sinkron_ekskul();

-- Simpan jadwal satu ekskul (menggantikan daftar): [{id?, hari, jam_mulai, jam_selesai, tempat}]
create or replace function public.simpan_jadwal_ekskul(p_group uuid, p_jadwal jsonb)
returns int language plpgsql volatile security definer set search_path = public as $$
declare g student_groups; r jsonb; n int := 0;
begin
  if not public.boleh_kelola_kelompok() then raise exception 'Anda tidak berwenang mengatur jadwal ekskul.' using errcode = '42501'; end if;
  select * into g from student_groups where id = p_group;
  if not found or g.jenis <> 'ekskul' then raise exception 'Kelompok bukan ekskul.'; end if;
  perform public._ta_boleh_ubah(g.academic_year_id);
  delete from extracurricular_schedules where group_id = p_group
    and id not in (select (x->>'id')::uuid from jsonb_array_elements(coalesce(p_jadwal, '[]')) x where nullif(x->>'id', '') is not null);
  for r in select * from jsonb_array_elements(coalesce(p_jadwal, '[]')) loop
    if (r->>'jam_selesai')::time <= (r->>'jam_mulai')::time then raise exception 'Jam selesai harus setelah jam mulai.'; end if;
    if nullif(r->>'id', '') is null then
      insert into extracurricular_schedules (group_id, hari, jam_mulai, jam_selesai, tempat)
      values (p_group, (r->>'hari')::smallint, (r->>'jam_mulai')::time, (r->>'jam_selesai')::time, nullif(trim(r->>'tempat'), ''));
    else
      update extracurricular_schedules set hari = (r->>'hari')::smallint, jam_mulai = (r->>'jam_mulai')::time,
        jam_selesai = (r->>'jam_selesai')::time, tempat = nullif(trim(r->>'tempat'), '')
      where id = (r->>'id')::uuid and group_id = p_group;
    end if;
    n := n + 1;
  end loop;
  return n;
end $$;
revoke execute on function public.simpan_jadwal_ekskul(uuid,jsonb) from public, anon;
grant execute on function public.simpan_jadwal_ekskul(uuid,jsonb) to authenticated;

-- ---------------------------------------------------------------------
-- 5. ABSENSI (DIPERBARUI: EKSKUL IKUT)
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
      'urutan_jenis', array_position(array['kelas','halaqah','kamar','ekskul'], g.jenis),
      'status', case when sa.id is not null then 'terisi' when v_kini < ss.buka then 'belum_buka'
                     when v_kini <= ss.tutup then 'terbuka' when v_kini <= ss.batas then 'lewat' else 'tidak_terisi' end,
      'session_id', sa.id, 'jumlah_anggota', coalesce(sa.jumlah_anggota, (select count(*) from public._anggota_pada(g.id, v_tgl))),
      'jumlah_hadir', sa.jumlah_hadir, 'jumlah_izin', sa.jumlah_izin, 'jumlah_sakit', sa.jumlah_sakit,
      'jumlah_bolos', sa.jumlah_bolos, 'jumlah_absen', sa.jumlah_absen, 'jumlah_terlambat', sa.jumlah_terlambat,
      'atas_nama', sa.atas_nama, 'tempat', ss.tempat, 'topik', (select topik from extracurricular_journals where session_id = sa.id), 'diisi_terlambat', sa.diisi_terlambat, 'diisi_pada', sa.updated_at,
      'asuhan_saya', v_saya in (select public._pengasuh_berlaku(g.id, v_tgl)),
      'pengampu', (select string_agg(e.nama_lengkap, ', ' order by k.peran, e.nama_lengkap) from group_keepers k join employees e on e.id = k.employee_id
                   where k.group_id = g.id and k.employee_id in (select public._pengasuh_berlaku(g.id, v_tgl)))) as x
    from student_groups g
    join academic_years a on a.id = g.academic_year_id and a.aktif
    cross join lateral public.sesi_kelompok(g.id, v_tgl) ss
    left join student_attendance_sessions sa on sa.group_id = g.id and sa.tanggal = v_tgl and sa.sesi = ss.kode
    where g.aktif and g.jenis in ('kelas','halaqah','kamar','ekskul')
      and ((p_semua) or v_saya in (select public._pengasuh_berlaku(g.id, v_tgl)))
  ) t;
  return hasil;
end $$;


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
  select * into ss from public.sesi_kelompok(p_group, p_tanggal) x where x.kode = p_sesi;
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
  elsif v_pengasuh and v_jenis = 'ekskul' then
    -- Pembina ekskul: sesi presensi = sesi pola EKSKUL yang dibuat dari jadwal pertemuan ini
    select exists (select 1 from public.jadwal_pegawai(v_saya, p_tanggal) j
                   where j.session_id = ss.session_id
                     and not exists (select 1 from attendances at where at.employee_id = v_saya and at.tanggal = p_tanggal
                                      and at.session_id = j.session_id
                                      and at.status in ('hadir','terlambat','dinas_luar','menunggu_verval')))
      into v_perlu;
  end if;
  return jsonb_build_object(
    'kelompok', jsonb_build_object('id', g.id, 'nama', g.nama, 'jenis', g.jenis, 'jenis_kelamin', g.jenis_kelamin, 'tingkat', g.tingkat, 'jenjang', g.jenjang,
                                   'wa_wali', g.wa_wali, 'naqib_id', g.naqib_id),
    'jenis', v_jenis, 'tanggal', p_tanggal, 'sesi', ss.kode, 'nama_sesi', ss.nama, 'jam_mulai', ss.jam_mulai, 'jam_selesai', ss.jam_selesai,
    'buka', ss.buka, 'tutup', ss.tutup, 'batas', ss.batas, 'sekarang', now(), 'tempat', ss.tempat,
    'jurnal', (select jsonb_build_object('topik', j.topik, 'uraian', j.uraian, 'foto_id', j.foto_id) from extracurricular_journals j where j.session_id = sa.id),
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
  if g.jenis not in ('kelas','halaqah','kamar','ekskul') then raise exception 'Kelompok lainnya tidak memiliki absensi.'; end if;
  if not exists (select 1 from academic_years where id = g.academic_year_id and aktif and not terkunci) then
    raise exception 'Kelompok ini bukan milik tahun ajaran aktif.';
  end if;
  v_jenis := case g.jenis when 'kamar' then 'asrama' else g.jenis end;
  select * into ss from public.sesi_kelompok(v_group, v_tgl) x where x.kode = v_sesi;
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

  -- Ekskul: jurnal materi wajib (topik)
  if v_jenis = 'ekskul' and length(trim(coalesce(p->'jurnal'->>'topik', ''))) < 3 then
    raise exception 'Isi topik/materi pertemuan ekskul (minimal 3 huruf).';
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
  if v_jenis = 'ekskul' then
    insert into extracurricular_journals (session_id, topik, uraian, foto_id)
    values (v_id, trim(p->'jurnal'->>'topik'), nullif(trim(coalesce(p->'jurnal'->>'uraian', '')), ''), nullif(p->'jurnal'->>'foto_id', '')::uuid)
    on conflict (session_id) do update set topik = excluded.topik, uraian = excluded.uraian,
      foto_id = coalesce(excluded.foto_id, extracurricular_journals.foto_id), updated_at = now();
  end if;
  return v_id;
end $$;


-- ---------------------------------------------------------------------
-- 6. JURNAL EKSKUL UNTUK REKAP
-- ---------------------------------------------------------------------
create or replace function public.jurnal_ekskul(p_group uuid, p_mulai date, p_selesai date)
returns table (session_id uuid, tanggal date, jam_mulai time, jam_selesai time, topik text, uraian text, foto_id uuid,
               pengampu text, jumlah_anggota int, jumlah_hadir int, jumlah_izin int, jumlah_sakit int, jumlah_absen int)
language sql stable security definer set search_path = public as $$
  select sa.id, sa.tanggal, sa.jam_mulai, sa.jam_selesai, j.topik, j.uraian, j.foto_id,
         (select nama_lengkap from employees where id = sa.pengampu_id), sa.jumlah_anggota, sa.jumlah_hadir, sa.jumlah_izin, sa.jumlah_sakit, sa.jumlah_absen
  from student_attendance_sessions sa left join extracurricular_journals j on j.session_id = sa.id
  where sa.group_id = p_group and sa.jenis = 'ekskul' and sa.tanggal between p_mulai and p_selesai
    and (public.is_admin() or public.saya() in (select employee_id from group_keepers where group_id = p_group)
         or public.tingkat_fitur('absensi_ekskul') >= 1)
  order by sa.tanggal, sa.jam_mulai
$$;
revoke execute on function public.jurnal_ekskul(uuid,date,date) from public, anon;
grant execute on function public.jurnal_ekskul(uuid,date,date) to authenticated;

-- Foto jurnal ekskul dapat dibuka pengasuh, admin, dan pimpinan
create or replace function public.boleh_lihat_berkas(p_obj uuid, p_emp uuid)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare r leave_requests; v_peran text; j journal_entries;
  izin boolean := false;
begin
  select peran into v_peran from employees where id = p_emp;
  if v_peran = 'superadmin' then return true; end if;
  for r in select * from leave_requests where lampiran_id = p_obj loop
    if r.employee_id = p_emp
       or (v_peran = 'admin' and exists (select 1 from admin_permissions where employee_id = p_emp and kode = 'lihat_pengajuan'))
       or exists (select 1 from leave_approvals a where a.request_id = r.id and a.oleh = p_emp)
       or exists (select 1 from leave_approvals a, public.calon_penyetuju(r.employee_id, a.peran) c
                   where a.request_id = r.id and a.status = 'menunggu' and c.employee_id = p_emp) then
      return true;
    end if;
  end loop;
  for j in select * from journal_entries where foto_id = p_obj loop
    if j.employee_id = p_emp
       or (v_peran = 'admin' and exists (select 1 from admin_permissions where employee_id = p_emp and kode = 'verval_jurnal'))
       or exists (select 1 from employees t, employee_structurals es join structural_positions sp on sp.id = es.structural_position_id
                   where t.id = j.employee_id and es.employee_id = p_emp
                     and (sp.tingkat <= 20 or t.org_unit_id in (select public.unit_turunan(es.org_unit_id)))) then
      return true;
    end if;
  end loop;
  if exists (select 1 from employee_documents d where d.berkas_id = p_obj and (
              exists (select 1 from employee_document_targets t where t.document_id = d.id and t.employee_id = p_emp)
              or (v_peran = 'admin' and exists (select 1 from admin_permissions where employee_id = p_emp and kode = 'kelola_berkas')))) then
    return true;
  end if;
  -- Lampiran agenda: penerima, pembuat, dan admin
  if exists (select 1 from agendas g where g.lampiran_id = p_obj and (
              exists (select 1 from agenda_targets t where t.agenda_id = g.id and t.employee_id = p_emp)
              or g.dibuat_oleh = p_emp or v_peran = 'admin')) then
    return true;
  end if;
  -- Lampiran pengumuman: penerima dan pembuat pengumuman
  if exists (select 1 from announcements a where a.lampiran_id = p_obj and (
              exists (select 1 from announcement_targets t where t.announcement_id = a.id and t.employee_id = p_emp)
              or a.dibuat_oleh = p_emp or v_peran = 'admin')) then
    return true;
  end if;
  -- Foto profil pegawai untuk pencetak kartu
  if v_peran = 'admin' and exists (select 1 from admin_permissions where employee_id = p_emp and kode = 'cetak_kartu')
     and exists (select 1 from employees where foto_id = p_obj) then
    return true;
  end if;
  -- Foto jurnal ekskul: pengasuh kelompok, admin, dan pimpinan yang dapat melihat santri
  if exists (select 1 from extracurricular_journals j join student_attendance_sessions sa on sa.id = j.session_id
             where j.foto_id = p_obj and (v_peran = 'admin'
               or p_emp in (select employee_id from group_keepers where group_id = sa.group_id)
               or public.tingkat_fitur_pegawai(p_emp, 'absensi_ekskul') >= 1)) then
    return true;
  end if;
  return false;
end $$;


do $$
declare f text;
begin
  foreach f in array array['sesi_absensi(date,boolean)','detail_absensi(uuid,date,text)','simpan_absensi_santri(jsonb)']
  loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- Sinkron awal (bila jadwal sudah ada)
select public.sinkron_sesi_ekskul();

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 5 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select 'Tabel jadwal dan jurnal ekskul dengan RLS' as pemeriksaan,
       case when (select count(*) from pg_tables where schemaname = 'public' and rowsecurity
                   and tablename in ('extracurricular_schedules','extracurricular_journals')) = 2 then 'Sesuai' else 'Periksa' end as hasil
union all
select 'Jabatan Pelatih ekskul (luar) memakai pola EKSKUL',
       case when exists (select 1 from public.functional_positions fp join public.task_patterns tp on tp.id = fp.pola_id
                         where fp.kode = 'PELATIH_EKSKUL' and tp.kode = 'EKSKUL') then 'Sesuai' else 'Periksa' end
union all
select 'Jadwal ekskul tersambung ke presensi pembina',
       case when exists (select 1 from pg_trigger where tgname = 'zz_sinkron_ekskul') then 'Sesuai' else 'Periksa' end
union all
select 'Absensi memakai sesi per kelompok (ekskul ikut)',
       case when position('sesi_kelompok' in pg_get_functiondef('public.simpan_absensi_santri(jsonb)'::regprocedure)) > 0 then 'Sesuai' else 'Periksa' end
union all
select 'Migrasi 3400 sudah terpasang',
       case when exists (select 1 from pg_proc where proname = 'jabatan_pengasuh') then 'Sesuai' else 'Periksa: jalankan 3400 dulu' end;
