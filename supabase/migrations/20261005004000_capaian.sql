-- SIMKA PRO | supabase/migrations/20261005004000_capaian.sql | v1.0 | Fase 5 – Tahap 3 Validasi capaian juz dan status bulanan | 05/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 5 · Migrasi 40: Validasi capaian (Blueprint Bagian 20)
--   * juz_proposals        : usulan capaian juz (dari ceklist muhaffizh; Tahap 4 menambah usulan otomatis dari ujian Tuntas).
--                            Validator menyetujui (→ juz_achievements, resmi) atau mengembalikan dengan catatan.
--   * monthly_achievements : status capaian bulanan per santri yang SUDAH DISAHKAN validator (salinan beku), beserta
--                            penanda Murojaah dari muhaffizh (dengan alasan). Selama belum disahkan, status dihitung langsung:
--                              Khatam         = hafalan resmi 30 juz (atau sabaq 30 juz)
--                              Murojaah       = ditandai muhaffizh untuk bulan itu (tidak dihitung Tidak tercapai)
--                              Tidak terdata  = tidak ada sesi setoran yang mencakup santri pada bulan itu
--                              Tercapai       = penambahan sabaq sebulan ≥ target pekan × pekan efektif bulan itu
--                              Tidak tercapai = selain itu
--   * Validator: admin ber-izin validasi_tahfizh atau pimpinan Bidang Tahfizh (boleh_validasi_tahfizh).
--   * Fungsi: capaian_bulanan, tandai_murojaah, sahkan_capaian_bulan, batal_sahkan_capaian, usulkan_juz,
--             putuskan_usulan_juz, daftar_usulan_juz, ringkasan_capaian_bulanan.
-- Jalankan SETELAH migrasi 3900. Aman dijalankan ulang.
-- =====================================================================

-- Sumber juz resmi: tambah 'validasi' (usulan ceklist muhaffizh yang disetujui)
alter table public.juz_achievements drop constraint if exists juz_achievements_sumber;
alter table public.juz_achievements add constraint juz_achievements_sumber check (sumber in ('awal','ujian','sertifikasi','validasi'));

-- ---------------------------------------------------------------------
-- 1. TABEL
-- ---------------------------------------------------------------------
create table if not exists public.juz_proposals (
  id             uuid primary key default gen_random_uuid(),
  student_id     uuid not null references public.students(id) on delete cascade,
  juz            smallint not null constraint juz_proposals_juz check (juz between 1 and 30),
  sumber         text not null default 'ceklist' constraint juz_proposals_sumber check (sumber in ('ceklist','ujian','sertifikasi')),
  ref_id         uuid,                           -- id ujian (Tahap 4) bila sumber ujian/sertifikasi
  status         text not null default 'menunggu' constraint juz_proposals_status check (status in ('menunggu','disetujui','dikembalikan')),
  catatan        text,                           -- catatan pengusul
  catatan_validator text,
  diusulkan_oleh uuid references public.employees(id) on delete set null,
  diusulkan_pada timestamptz not null default now(),
  diputuskan_oleh uuid references public.employees(id) on delete set null,
  diputuskan_pada timestamptz
);
create unique index if not exists juz_proposals_menunggu_unik on public.juz_proposals (student_id, juz) where status = 'menunggu';
create index if not exists juz_proposals_status_idx on public.juz_proposals (status, diusulkan_pada desc);

create table if not exists public.monthly_achievements (
  student_id       uuid not null references public.students(id) on delete cascade,
  bulan            date not null constraint monthly_bulan_awal check (extract(day from bulan) = 1),
  academic_year_id uuid references public.academic_years(id) on delete cascade,
  murojaah         boolean not null default false,
  alasan_murojaah  text,
  ditandai_oleh    uuid references public.employees(id) on delete set null,
  -- Salinan saat disahkan (kosong = belum disahkan)
  status           text constraint monthly_status check (status in ('tercapai','tidak_tercapai','murojaah','khatam','tidak_terdata')),
  posisi_awal_hal  smallint, posisi_akhir_hal smallint, tambah_hal smallint, target_hal smallint, pekan_efektif smallint,
  total_resmi      smallint, halaqah text, program text, tingkat smallint,
  disahkan_oleh    uuid references public.employees(id) on delete set null,
  disahkan_pada    timestamptz,
  updated_at       timestamptz not null default now(),
  primary key (student_id, bulan)
);
create index if not exists monthly_bulan_idx on public.monthly_achievements (bulan);

drop trigger if exists aa_updated on public.monthly_achievements;
create trigger aa_updated before update on public.monthly_achievements for each row execute function public.tg_updated_at();
drop trigger if exists zz_audit on public.juz_proposals;
create trigger zz_audit after insert or update or delete on public.juz_proposals for each row execute function public.tg_audit();

alter table public.juz_proposals enable row level security;
alter table public.monthly_achievements enable row level security;
drop policy if exists santri_baca on public.juz_proposals;
create policy santri_baca on public.juz_proposals for select to authenticated using (student_id in (select public.santri_terlihat()));
drop policy if exists santri_baca on public.monthly_achievements;
create policy santri_baca on public.monthly_achievements for select to authenticated using (student_id in (select public.santri_terlihat()));

-- ---------------------------------------------------------------------
-- 2. BANTUAN
-- ---------------------------------------------------------------------
-- Muhaffizh (pengasuh berlaku hari ini) dari halaqah aktif santri
create or replace function public._muhaffizh_santri(p_santri uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from group_members m join student_groups g on g.id = m.group_id and g.jenis = 'halaqah'
      join academic_years a on a.id = g.academic_year_id and a.aktif
     where m.student_id = p_santri and m.selesai is null
       and public.saya() in (select public._pengasuh_berlaku(g.id, public.hari_ini())))
$$;

-- Validator capaian: penerima notifikasi usulan (admin ber-izin, superadmin, pimpinan Bidang Tahfizh)
create or replace function public._validator_tahfizh()
returns setof uuid language sql stable security definer set search_path = public as $$
  select e.id from employees e where e.status_akun = 'aktif' and e.status_keaktifan = 'aktif'
     and (e.peran = 'superadmin' or (e.peran = 'admin' and exists (select 1 from admin_permissions p where p.employee_id = e.id and p.kode = 'validasi_tahfizh')))
  union
  select p.employee_id from public.pemegang_jabatan() p join org_units o on o.id = p.org_unit_id
   where o.kode = 'TAHFIZH' and p.kode in ('KEPALA_BIDANG','WAKIL_KEPALA_BIDANG')
$$;

-- ---------------------------------------------------------------------
-- 3. STATUS CAPAIAN BULANAN
-- ---------------------------------------------------------------------
-- Satu baris per santri terlihat (aktif/nonaktif) pada bulan itu. Bila sudah disahkan, nilai dari salinan beku.
create or replace function public.capaian_bulanan(p_bulan date, p_group uuid default null)
returns table (student_id uuid, nis text, nama text, jenis_kelamin text, tingkat smallint, kelas text, halaqah_id uuid, halaqah text,
               program text, posisi_awal_hal int, posisi_akhir_hal int, tambah_hal int, target_hal int, pekan_efektif int,
               sesi_terdata int, total_resmi int, status_otomatis text, status text, murojaah boolean, alasan_murojaah text,
               disahkan boolean, disahkan_pada timestamptz, disahkan_oleh text, muhaffizh_saya boolean)
language plpgsql stable security definer set search_path = public as $$
declare v_b date := date_trunc('month', p_bulan)::date; v_akhir date := (date_trunc('month', p_bulan) + interval '1 month - 1 day')::date;
  v_ta uuid; v_pekan int;
begin
  select id into v_ta from academic_years where v_b between date_trunc('month', mulai) and selesai order by mulai desc limit 1;
  v_ta := coalesce(v_ta, (select id from academic_years where aktif));
  select coalesce(m.pekan_efektif, 4) into v_pekan from tahfizh_months m where m.academic_year_id = v_ta and m.bulan = v_b;
  v_pekan := coalesce(v_pekan, 4);
  return query
  with kel as (
    select m.student_id, g.id, g.nama, g.jenis from group_members m join student_groups g on g.id = m.group_id
     where g.academic_year_id = v_ta and g.jenis in ('kelas','halaqah') and m.mulai <= v_akhir and (m.selesai is null or m.selesai >= v_b)
  ),
  dasar as (
    select s.id, s.nis, s.nama_lengkap, s.jenis_kelamin, s.tingkat,
           (select k.nama from kel k where k.student_id = s.id and k.jenis = 'kelas' limit 1) as kelas,
           (select k.id from kel k where k.student_id = s.id and k.jenis = 'halaqah' limit 1) as hq_id,
           (select k.nama from kel k where k.student_id = s.id and k.jenis = 'halaqah' limit 1) as hq,
           coalesce(t.program, 'reguler') as program,
           -- posisi sabaq awal bulan: setoran terakhir sebelum bulan ini, atau data awal
           coalesce((select l.sabaq_hal from memorization_logs l join memorization_sessions ms on ms.id = l.session_id
                      where l.student_id = s.id and l.sabaq_hal is not null and l.tanggal < v_b
                      order by l.tanggal desc, ms.jam_mulai desc nulls last limit 1), t.awal_sabaq_hal, 0)::int as awal,
           coalesce((select l.sabaq_hal from memorization_logs l join memorization_sessions ms on ms.id = l.session_id
                      where l.student_id = s.id and l.sabaq_hal is not null and l.tanggal <= v_akhir
                      order by l.tanggal desc, ms.jam_mulai desc nulls last limit 1), t.awal_sabaq_hal, 0)::int as akhir,
           -- sesi setoran halaqah santri pada bulan itu yang santri hadir (dapat setor)
           (select count(*) from memorization_sessions ms
             where ms.tanggal between v_b and v_akhir
               and s.id in (select public._anggota_pada(ms.group_id, ms.tanggal))
               and not exists (select 1 from student_attendance_exceptions x where x.session_id = ms.attendance_session_id
                                and x.student_id = s.id and x.kode in ('I','S','B','A')))::int as sesi,
           (select count(*) from juz_achievements j where j.student_id = s.id)::int as resmi,
           coalesce((select tg.pekan_hal from tahfizh_targets tg where tg.academic_year_id = v_ta and tg.program = coalesce(t.program, 'reguler')
                      and tg.tingkat = s.tingkat), 5)::int * v_pekan as target,
           ma.murojaah, ma.alasan_murojaah, ma.status as st_beku, ma.disahkan_pada, ma.disahkan_oleh,
           ma.posisi_awal_hal, ma.posisi_akhir_hal, ma.tambah_hal as tambah_beku, ma.target_hal as target_beku, ma.pekan_efektif as pekan_beku
      from students s left join student_tahfizh t on t.student_id = s.id
      left join monthly_achievements ma on ma.student_id = s.id and ma.bulan = v_b
     where s.status in ('aktif','nonaktif') and s.id in (select public.santri_terlihat())
       and (p_group is null or exists (select 1 from kel k where k.student_id = s.id and k.id = p_group))
  )
  select d.id, d.nis, d.nama_lengkap, d.jenis_kelamin, d.tingkat, d.kelas, d.hq_id, d.hq, d.program,
         coalesce(d.posisi_awal_hal::int, d.awal), coalesce(d.posisi_akhir_hal::int, d.akhir),
         coalesce(d.tambah_beku::int, d.akhir - d.awal), coalesce(d.target_beku::int, d.target), coalesce(d.pekan_beku::int, v_pekan),
         d.sesi, d.resmi,
         case when d.resmi >= 30 or d.akhir >= 600 then 'khatam'
              when coalesce(d.murojaah, false) then 'murojaah'
              when d.sesi = 0 then 'tidak_terdata'
              when d.akhir - d.awal >= d.target then 'tercapai' else 'tidak_tercapai' end,
         coalesce(d.st_beku,
           case when d.resmi >= 30 or d.akhir >= 600 then 'khatam'
                when coalesce(d.murojaah, false) then 'murojaah'
                when d.sesi = 0 then 'tidak_terdata'
                when d.akhir - d.awal >= d.target then 'tercapai' else 'tidak_tercapai' end),
         coalesce(d.murojaah, false), d.alasan_murojaah, d.disahkan_pada is not null, d.disahkan_pada,
         (select nama_lengkap from employees where id = d.disahkan_oleh),
         public._muhaffizh_santri(d.id)
    from dasar d
   order by d.hq nulls last, d.nama_lengkap;
end $$;

-- Ringkasan per halaqah satu bulan (untuk kartu dan daftar validasi)
create or replace function public.ringkasan_capaian_bulanan(p_bulan date)
returns table (halaqah_id uuid, halaqah text, jumlah int, tercapai int, tidak_tercapai int, murojaah int, khatam int, tidak_terdata int,
               disahkan int, total_tambah_hal int)
language sql stable security definer set search_path = public as $$
  select c.halaqah_id, coalesce(c.halaqah, 'Belum masuk halaqah'), count(*)::int,
         count(*) filter (where c.status = 'tercapai')::int, count(*) filter (where c.status = 'tidak_tercapai')::int,
         count(*) filter (where c.status = 'murojaah')::int, count(*) filter (where c.status = 'khatam')::int,
         count(*) filter (where c.status = 'tidak_terdata')::int, count(*) filter (where c.disahkan)::int,
         coalesce(sum(greatest(c.tambah_hal, 0)), 0)::int
    from public.capaian_bulanan(p_bulan, null) c
   group by c.halaqah_id, c.halaqah order by 2
$$;

-- Muhaffizh menandai/mencabut Murojaah (wajib alasan saat menandai). Validator juga boleh.
create or replace function public.tandai_murojaah(p_santri uuid[], p_bulan date, p_aktif boolean, p_alasan text default null)
returns int language plpgsql volatile security definer set search_path = public as $$
declare v_b date := date_trunc('month', p_bulan)::date; s uuid; n int := 0; v_ta uuid;
begin
  if p_aktif and length(trim(coalesce(p_alasan, ''))) < 5 then raise exception 'Tuliskan alasan Murojaah (minimal 5 huruf).'; end if;
  if v_b > date_trunc('month', public.hari_ini()) then raise exception 'Murojaah tidak dapat ditandai untuk bulan yang belum berjalan.'; end if;
  select id into v_ta from academic_years where v_b between date_trunc('month', mulai) and selesai order by mulai desc limit 1;
  foreach s in array p_santri loop
    if not (public._muhaffizh_santri(s) or public.boleh_validasi_tahfizh()) then
      raise exception 'Anda bukan muhaffizh % dan tidak berwenang memvalidasi.', (select nama_lengkap from students where id = s) using errcode = '42501';
    end if;
    if exists (select 1 from monthly_achievements where student_id = s and bulan = v_b and disahkan_pada is not null) then
      raise exception 'Capaian % bulan ini sudah disahkan. Minta validator membatalkan pengesahan lebih dulu.', (select nama_lengkap from students where id = s);
    end if;
    insert into monthly_achievements (student_id, bulan, academic_year_id, murojaah, alasan_murojaah, ditandai_oleh)
    values (s, v_b, v_ta, p_aktif, case when p_aktif then trim(p_alasan) end, public.saya())
    on conflict (student_id, bulan) do update set murojaah = excluded.murojaah, alasan_murojaah = excluded.alasan_murojaah, ditandai_oleh = excluded.ditandai_oleh;
    n := n + 1;
  end loop;
  return n;
end $$;

-- Validator mengesahkan status bulanan (salinan beku) untuk satu halaqah atau semua santri terlihat.
create or replace function public.sahkan_capaian_bulan(p_bulan date, p_group uuid default null)
returns int language plpgsql volatile security definer set search_path = public as $$
declare v_b date := date_trunc('month', p_bulan)::date; v_ta uuid; n int;
begin
  if not public.boleh_validasi_tahfizh() then raise exception 'Hanya validator tahfizh yang dapat mengesahkan capaian bulanan.' using errcode = '42501'; end if;
  if v_b >= date_trunc('month', public.hari_ini()) and public.hari_ini() < (v_b + interval '1 month - 1 day')::date - 2 then
    raise exception 'Capaian bulan berjalan baru dapat disahkan mulai 3 hari sebelum akhir bulan.';
  end if;
  select id into v_ta from academic_years where v_b between date_trunc('month', mulai) and selesai order by mulai desc limit 1;
  if exists (select 1 from academic_years where id = v_ta and terkunci) then raise exception 'Tahun ajaran bulan ini sudah dikunci.'; end if;
  insert into monthly_achievements (student_id, bulan, academic_year_id, status, posisi_awal_hal, posisi_akhir_hal, tambah_hal, target_hal,
         pekan_efektif, total_resmi, halaqah, program, tingkat, disahkan_oleh, disahkan_pada, murojaah)
  select c.student_id, v_b, v_ta, c.status_otomatis, c.posisi_awal_hal, c.posisi_akhir_hal, c.tambah_hal, c.target_hal, c.pekan_efektif,
         c.total_resmi, c.halaqah, c.program, c.tingkat, public.saya(), now(), c.murojaah
    from public.capaian_bulanan(v_b, p_group) c where not c.disahkan
  on conflict (student_id, bulan) do update set status = excluded.status, posisi_awal_hal = excluded.posisi_awal_hal,
     posisi_akhir_hal = excluded.posisi_akhir_hal, tambah_hal = excluded.tambah_hal, target_hal = excluded.target_hal,
     pekan_efektif = excluded.pekan_efektif, total_resmi = excluded.total_resmi, halaqah = excluded.halaqah, program = excluded.program,
     tingkat = excluded.tingkat, disahkan_oleh = excluded.disahkan_oleh, disahkan_pada = excluded.disahkan_pada, academic_year_id = excluded.academic_year_id;
  get diagnostics n = row_count;
  perform public.catat_audit('ubah', 'monthly_achievements', to_char(v_b, 'YYYY-MM'),
    'Mengesahkan capaian bulanan ' || to_char(v_b, 'MM/YYYY') || coalesce(' halaqah ' || (select nama from student_groups where id = p_group), ' (semua)') || ': ' || n || ' santri',
    jsonb_build_object('bulan', v_b, 'group', p_group, 'jumlah', n));
  return n;
end $$;

create or replace function public.batal_sahkan_capaian(p_bulan date, p_group uuid default null)
returns int language plpgsql volatile security definer set search_path = public as $$
declare v_b date := date_trunc('month', p_bulan)::date; n int;
begin
  if not public.boleh_validasi_tahfizh() then raise exception 'Hanya validator tahfizh yang dapat membatalkan pengesahan.' using errcode = '42501'; end if;
  if exists (select 1 from monthly_achievements m join academic_years a on a.id = m.academic_year_id where m.bulan = v_b and a.terkunci) then
    raise exception 'Tahun ajaran bulan ini sudah dikunci.';
  end if;
  update monthly_achievements set status = null, posisi_awal_hal = null, posisi_akhir_hal = null, tambah_hal = null, target_hal = null,
         pekan_efektif = null, total_resmi = null, halaqah = null, program = null, tingkat = null, disahkan_oleh = null, disahkan_pada = null
   where bulan = v_b and disahkan_pada is not null
     and student_id in (select c.student_id from public.capaian_bulanan(v_b, p_group) c);
  get diagnostics n = row_count;
  perform public.catat_audit('ubah', 'monthly_achievements', to_char(v_b, 'YYYY-MM'), 'Membatalkan pengesahan capaian ' || to_char(v_b, 'MM/YYYY') || ': ' || n || ' santri', null);
  return n;
end $$;

-- ---------------------------------------------------------------------
-- 4. USULAN JUZ
-- ---------------------------------------------------------------------
create or replace function public.usulkan_juz(p_santri uuid, p_juz smallint[], p_catatan text default null)
returns int language plpgsql volatile security definer set search_path = public as $$
declare j smallint; n int := 0; v_nama text; v_halaqah text;
begin
  if not (public._muhaffizh_santri(p_santri) or public.boleh_validasi_tahfizh()) then
    raise exception 'Usulan capaian diajukan oleh muhaffizh santri tersebut.' using errcode = '42501';
  end if;
  if coalesce(array_length(p_juz, 1), 0) = 0 then raise exception 'Pilih sedikitnya satu juz.'; end if;
  select nama_lengkap into v_nama from students where id = p_santri;
  foreach j in array p_juz loop
    if j not between 1 and 30 then raise exception 'Nomor juz harus 1–30.'; end if;
    if exists (select 1 from juz_achievements where student_id = p_santri and juz = j) then
      raise exception 'Juz % sudah tercatat resmi untuk %.', j, v_nama;
    end if;
    insert into juz_proposals (student_id, juz, sumber, catatan, diusulkan_oleh)
    values (p_santri, j, 'ceklist', nullif(trim(p_catatan), ''), public.saya())
    on conflict do nothing;
    if found then n := n + 1; end if;
  end loop;
  if n > 0 then
    select g.nama into v_halaqah from group_members m join student_groups g on g.id = m.group_id and g.jenis = 'halaqah'
      join academic_years a on a.id = g.academic_year_id and a.aktif where m.student_id = p_santri and m.selesai is null limit 1;
    perform public.kirim_notifikasi(v, 'Usulan capaian juz: ' || v_nama,
      'Juz ' || array_to_string(p_juz, ', ') || coalesce(' · ' || v_halaqah, '') || '. Mohon divalidasi.', '/tahfizh/capaian?bagian=usulan', 'SealCheck', 'kuning')
      from public._validator_tahfizh() v where v is distinct from public.saya();
  end if;
  return n;
end $$;

-- Setujui (p_setuju) atau kembalikan usulan. Catatan wajib saat mengembalikan.
create or replace function public.putuskan_usulan_juz(p_ids uuid[], p_setuju boolean, p_catatan text default null)
returns int language plpgsql volatile security definer set search_path = public as $$
declare r juz_proposals; n int := 0;
begin
  if not public.boleh_validasi_tahfizh() then raise exception 'Hanya validator tahfizh yang dapat memutuskan usulan.' using errcode = '42501'; end if;
  if not p_setuju and length(trim(coalesce(p_catatan, ''))) < 5 then raise exception 'Tuliskan alasan pengembalian (minimal 5 huruf).'; end if;
  for r in select * from juz_proposals where id = any(p_ids) and status = 'menunggu' for update loop
    update juz_proposals set status = case when p_setuju then 'disetujui' else 'dikembalikan' end,
           catatan_validator = nullif(trim(p_catatan), ''), diputuskan_oleh = public.saya(), diputuskan_pada = now()
     where id = r.id;
    if p_setuju then
      insert into juz_achievements (student_id, juz, sumber, ditetapkan_oleh, catatan)
      values (r.student_id, r.juz, case r.sumber when 'ceklist' then 'validasi' else r.sumber end, public.saya(), coalesce(r.catatan, 'Disetujui dari usulan'))
      on conflict (student_id, juz) do nothing;
    end if;
    n := n + 1;
  end loop;
  -- Notifikasi ringkas ke pengusul
  perform public.kirim_notifikasi(x.oleh,
    case when p_setuju then 'Usulan capaian juz disetujui' else 'Usulan capaian juz dikembalikan' end,
    x.daftar || case when p_setuju then '' else '. Catatan: ' || trim(p_catatan) end, '/tahfizh/capaian?bagian=usulan', 'SealCheck',
    case when p_setuju then 'hijau' else 'merah' end)
  from (select p.diusulkan_oleh oleh, string_agg(s.nama_lengkap || ' juz ' || p.juz, ', ' order by s.nama_lengkap, p.juz) daftar
          from juz_proposals p join students s on s.id = p.student_id
         where p.id = any(p_ids) and p.diputuskan_oleh = public.saya() and p.diputuskan_pada > now() - interval '1 minute'
           and p.diusulkan_oleh is not null and p.diusulkan_oleh is distinct from public.saya()
         group by p.diusulkan_oleh) x;
  return n;
end $$;

create or replace function public.daftar_usulan_juz(p_status text default 'menunggu')
returns table (id uuid, student_id uuid, nis text, nama text, halaqah text, juz smallint, sumber text, status text, catatan text,
               catatan_validator text, diusulkan_oleh text, diusulkan_pada timestamptz, diputuskan_oleh text, diputuskan_pada timestamptz,
               total_resmi int)
language sql stable security definer set search_path = public as $$
  select p.id, s.id, s.nis, s.nama_lengkap,
         (select g.nama from group_members m join student_groups g on g.id = m.group_id and g.jenis = 'halaqah'
            join academic_years a on a.id = g.academic_year_id and a.aktif where m.student_id = s.id and m.selesai is null limit 1),
         p.juz, p.sumber, p.status, p.catatan, p.catatan_validator,
         (select nama_lengkap from employees where id = p.diusulkan_oleh), p.diusulkan_pada,
         (select nama_lengkap from employees where id = p.diputuskan_oleh), p.diputuskan_pada,
         (select count(*) from juz_achievements j where j.student_id = s.id)::int
    from juz_proposals p join students s on s.id = p.student_id
   where s.id in (select public.santri_terlihat())
     and (p_status is null or p.status = p_status)
     and (p.status = 'menunggu' or p.diputuskan_pada > now() - interval '90 days')
   order by p.diusulkan_pada desc
   limit 500
$$;

-- ---------------------------------------------------------------------
-- 5. HAK EKSEKUSI
-- ---------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array['capaian_bulanan(date,uuid)','ringkasan_capaian_bulanan(date)','tandai_murojaah(uuid[],date,boolean,text)',
    'sahkan_capaian_bulan(date,uuid)','batal_sahkan_capaian(date,uuid)','usulkan_juz(uuid,smallint[],text)',
    'putuskan_usulan_juz(uuid[],boolean,text)','daftar_usulan_juz(text)']
  loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['_muhaffizh_santri(uuid)','_validator_tahfizh()'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 5 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select 'Tabel usulan juz dan capaian bulanan dengan RLS' as pemeriksaan,
       case when (select count(*) from pg_tables where schemaname = 'public' and rowsecurity
                   and tablename in ('juz_proposals','monthly_achievements')) = 2 then 'Sesuai' else 'Periksa' end as hasil
union all
select 'Sumber juz "validasi" diterima',
       case when pg_get_constraintdef((select oid from pg_constraint where conname = 'juz_achievements_sumber')) like '%validasi%' then 'Sesuai' else 'Periksa' end
union all
select 'Fungsi capaian (8) tersedia',
       case when (select count(distinct proname) from pg_proc where proname in ('capaian_bulanan','ringkasan_capaian_bulanan','tandai_murojaah',
         'sahkan_capaian_bulan','batal_sahkan_capaian','usulkan_juz','putuskan_usulan_juz','daftar_usulan_juz')) = 8 then 'Sesuai' else 'Periksa' end
union all
select 'Validator tahfizh terdaftar (superadmin/izin/pimpinan)',
       case when exists (select 1 from public._validator_tahfizh()) then 'Sesuai' else 'Periksa: belum ada validator' end
union all
select 'Migrasi 3900 sudah terpasang', case when exists (select 1 from pg_proc where proname = 'simpan_setoran') then 'Sesuai' else 'Periksa: jalankan 3900 dulu' end;
