-- SIMKA PRO | supabase/migrations/20261004002000_pengajuan_pegawai.sql | v1.0 | Fase 3 – Tahap 2 Pengajuan berjenjang | 04/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 3 · Migrasi 20: Pengajuan izin, sakit, dinas luar, dan cuti pegawai
--   * leave_types        : jenis pengajuan + aturan (lama maksimal, kuota tahunan/bulanan, lampiran, batas tanggal)
--   * leave_tiers        : jenjang persetujuan menurut lama hari (Kepala Bidang/Unit → Direktur/Wadir → Yayasan)
--   * acting_assignments : penunjukan Plt (berlaku sebagai pemegang jabatan selama masa tugasnya)
--   * leave_requests + leave_approvals : pengajuan dan jejak persetujuan setiap jenjang
--   * Disetujui penuh → nomor surat, kode validasi, dan status presensi terisi otomatis
--   * Penanda tangan (signatories) dapat ditautkan ke jabatan struktural: nama dan NIY mengikuti Data Pegawai
-- Jalankan SETELAH migrasi 1900. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Izin admin baru
-- ---------------------------------------------------------------------
insert into public.admin_capabilities (kode, nama, urutan) values
  ('atur_pengajuan', 'Mengatur jenis, kuota, jenjang pengajuan, dan Plt (Fase 3)', 8),
  ('lihat_pengajuan', 'Melihat dan mencetak semua pengajuan pegawai (Fase 3)', 9)
on conflict (kode) do nothing;

-- ---------------------------------------------------------------------
-- 2. Jenis pengajuan
-- ---------------------------------------------------------------------
create table if not exists public.leave_types (
  id                    uuid primary key default gen_random_uuid(),
  kode                  text not null unique check (kode ~ '^[A-Z0-9_]{2,30}$'),
  nama                  text not null,
  kelompok              text not null check (kelompok in ('izin','sakit','dinas_luar','cuti')),
  status_presensi       text not null check (status_presensi in ('izin','sakit','dinas_luar','cuti')),
  keterangan            text,                       -- penjelasan yang dibaca pegawai
  maks_hari             int check (maks_hari is null or maks_hari > 0),         -- lama maksimal satu pengajuan
  kuota_tahunan_hari    int check (kuota_tahunan_hari is null or kuota_tahunan_hari >= 0),
  batas_bulanan_hari    int check (batas_bulanan_hari is null or batas_bulanan_hari >= 0),
  batas_bulanan_kali    int check (batas_bulanan_kali is null or batas_bulanan_kali >= 0),
  aturan_kuota          text not null default 'tolak' check (aturan_kuota in ('tolak','peringatan')),
  lampiran_wajib_min_hari int check (lampiran_wajib_min_hari is null or lampiran_wajib_min_hari >= 1), -- null = lampiran opsional
  lampiran_keterangan   text,                       -- contoh: surat keterangan dokter
  mundur_maks_hari      int not null default 0 check (mundur_maks_hari >= 0),  -- boleh mulai berapa hari sebelum hari ini
  maju_min_hari         int not null default 0 check (maju_min_hari >= 0),     -- diajukan paling lambat H-n
  maju_maks_hari        int check (maju_maks_hari is null or maju_maks_hari >= 0), -- 0 = harus mulai hari ini (sakit)
  khusus_jk             text check (khusus_jk in ('L','P')),
  aktif                 boolean not null default true,
  urutan                int not null default 0,
  updated_at            timestamptz not null default now()
);

insert into public.leave_types (kode, nama, kelompok, status_presensi, keterangan, maks_hari, kuota_tahunan_hari, batas_bulanan_hari,
  lampiran_wajib_min_hari, lampiran_keterangan, mundur_maks_hari, maju_min_hari, maju_maks_hari, khusus_jk, urutan) values
  ('SAKIT', 'Sakit', 'sakit', 'sakit',
   'Diajukan pada hari pertama sakit, paling lama 3 hari. Sakit lebih dari 3 hari diajukan sebagai Izin dengan bukti (misalnya surat keterangan dokter).',
   3, null, null, null, 'Surat keterangan dokter atau foto resep (dianjurkan)', 0, 0, 0, null, 1),
  ('IZIN', 'Izin', 'izin', 'izin',
   'Untuk keperluan pribadi atau sakit lebih dari 3 hari. Izin 4 hari atau lebih wajib melampirkan bukti.',
   null, null, null, 4, 'Surat keterangan dokter, undangan, atau bukti lain yang relevan', 0, 0, null, null, 2),
  ('DINAS_LUAR', 'Dinas luar', 'dinas_luar', 'dinas_luar',
   'Tugas resmi di luar pondok atas penugasan pimpinan. Lampirkan surat tugas bila ada.',
   null, null, null, null, 'Surat tugas atau undangan kegiatan', 0, 0, null, null, 3),
  ('CUTI_TAHUNAN', 'Cuti tahunan', 'cuti', 'cuti',
   'Hak cuti tahunan pegawai. Diajukan paling lambat 3 hari sebelumnya.',
   12, 12, null, null, null, 0, 3, null, null, 4),
  ('CUTI_MELAHIRKAN', 'Cuti melahirkan', 'cuti', 'cuti',
   'Untuk pegawai perempuan menjelang dan sesudah melahirkan.',
   90, null, null, 1, 'Surat keterangan dokter atau bidan', 0, 0, null, 'P', 5),
  ('CUTI_MENIKAH', 'Cuti menikah', 'cuti', 'cuti',
   'Untuk pernikahan pegawai yang bersangkutan.',
   3, null, null, 1, 'Undangan atau surat keterangan pernikahan', 0, 0, null, null, 6),
  ('CUTI_PENTING', 'Cuti alasan penting', 'cuti', 'cuti',
   'Keluarga inti meninggal dunia, sakit keras, istri melahirkan, atau musibah lain.',
   3, null, null, null, 'Bukti pendukung bila ada', 1, 0, null, null, 7),
  ('CUTI_IBADAH', 'Cuti ibadah haji/umrah', 'cuti', 'cuti',
   'Untuk menunaikan ibadah haji atau umrah.',
   45, null, null, 1, 'Bukti pendaftaran atau jadwal keberangkatan', 0, 7, null, null, 8),
  ('CUTI_LUAR_TANGGUNGAN', 'Cuti di luar tanggungan', 'cuti', 'cuti',
   'Cuti panjang tanpa hak tunjangan selama masa cuti, atas persetujuan Yayasan.',
   null, null, null, 1, 'Surat permohonan bermaterai', 0, 14, null, null, 9)
on conflict (kode) do nothing;

-- ---------------------------------------------------------------------
-- 3. Jenjang persetujuan menurut lama hari
-- ---------------------------------------------------------------------
create table if not exists public.leave_tiers (
  id          uuid primary key default gen_random_uuid(),
  mulai_hari  int not null check (mulai_hari >= 1),
  sampai_hari int check (sampai_hari is null or sampai_hari >= mulai_hari),  -- null = seterusnya
  langkah     text[] not null check (cardinality(langkah) >= 1
                and langkah <@ array['kepala_bidang','direktur','yayasan']::text[]),
  updated_at  timestamptz not null default now()
);
insert into public.leave_tiers (mulai_hari, sampai_hari, langkah)
select * from (values (1, 1, array['kepala_bidang']), (2, 3, array['kepala_bidang','direktur']),
                      (4, null::int, array['kepala_bidang','direktur','yayasan'])) v
 where not exists (select 1 from public.leave_tiers);

-- ---------------------------------------------------------------------
-- 4. Plt (pelaksana tugas)
-- ---------------------------------------------------------------------
create table if not exists public.acting_assignments (
  id                     uuid primary key default gen_random_uuid(),
  employee_id            uuid not null references public.employees(id) on delete cascade,
  structural_position_id uuid not null references public.structural_positions(id) on delete cascade,
  org_unit_id            uuid references public.org_units(id) on delete cascade,
  mulai                  date not null,
  sampai                 date not null check (sampai >= mulai),
  catatan                text,
  dibuat_oleh            uuid references public.employees(id) on delete set null,
  created_at             timestamptz not null default now()
);

/** Pemegang jabatan struktural pada suatu tanggal: definitif dan Plt yang berlaku. */
create or replace function public.pemegang_jabatan(p_tanggal date default null)
returns table (employee_id uuid, kode text, nama_jabatan text, org_unit_id uuid, plt boolean)
language sql stable security definer set search_path = public as $$
  select es.employee_id, sp.kode, sp.nama, es.org_unit_id, false
    from employee_structurals es join structural_positions sp on sp.id = es.structural_position_id
    join employees e on e.id = es.employee_id
   where e.status_keaktifan = 'aktif' and e.status_akun = 'aktif'
  union all
  select a.employee_id, sp.kode, sp.nama, a.org_unit_id, true
    from acting_assignments a join structural_positions sp on sp.id = a.structural_position_id
    join employees e on e.id = a.employee_id
   where e.status_keaktifan = 'aktif' and e.status_akun = 'aktif'
     and coalesce(p_tanggal, public.hari_ini()) between a.mulai and a.sampai
$$;

-- ---------------------------------------------------------------------
-- 5. Pengajuan dan jejak persetujuan
-- ---------------------------------------------------------------------
create table if not exists public.leave_requests (
  id             uuid primary key default gen_random_uuid(),
  employee_id    uuid not null references public.employees(id) on delete cascade,
  leave_type_id  uuid not null references public.leave_types(id),
  mulai          date not null,
  selesai        date not null check (selesai >= mulai),
  jumlah_hari    int not null,
  alasan         text not null,
  alamat_selama  text,
  lampiran_id    uuid references public.storage_objects(id) on delete set null,
  kop_kode       text not null default 'pondok',
  status         text not null default 'menunggu' check (status in ('menunggu','disetujui','ditolak','dibatalkan')),
  langkah_ke     int not null default 1,
  melebihi_kuota boolean not null default false,
  catatan_kuota  text,
  nomor_surat    text,
  kode_validasi  text unique,
  diputus_pada   timestamptz,
  alasan_tolak   text,
  dibatalkan_oleh uuid references public.employees(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index if not exists leave_requests_emp_idx on public.leave_requests (employee_id, mulai desc);
create index if not exists leave_requests_status_idx on public.leave_requests (status, created_at desc);

create table if not exists public.leave_approvals (
  id            uuid primary key default gen_random_uuid(),
  request_id    uuid not null references public.leave_requests(id) on delete cascade,
  urutan        int not null,
  peran         text not null check (peran in ('kepala_bidang','direktur','yayasan')),
  status        text not null default 'antre' check (status in ('antre','menunggu','disetujui','ditolak','dilewati')),
  oleh          uuid references public.employees(id) on delete set null,
  nama          text,
  niy           text,
  jabatan_tertulis text,
  atas_nama     boolean not null default false,   -- diputus superadmin atas nama pejabat
  catatan       text,
  waktu         timestamptz,
  unique (request_id, urutan)
);

alter table public.attendances add column if not exists leave_request_id uuid references public.leave_requests(id) on delete set null;

alter table public.leave_types enable row level security;
alter table public.leave_tiers enable row level security;
alter table public.acting_assignments enable row level security;
alter table public.leave_requests enable row level security;
alter table public.leave_approvals enable row level security;

create or replace function public.boleh_atur_pengajuan()
returns boolean language sql stable security definer set search_path = public as $$
  select public.admin_boleh('atur_pengajuan')
$$;

do $$
declare t text;
begin
  foreach t in array array['leave_types','leave_tiers','acting_assignments'] loop
    execute format('drop policy if exists baca on public.%I', t);
    execute format('create policy baca on public.%I for select to authenticated using (true)', t);
    execute format('drop policy if exists kelola on public.%I', t);
    execute format('create policy kelola on public.%I for all to authenticated using (public.boleh_atur_pengajuan()) with check (public.boleh_atur_pengajuan())', t);
    execute format('drop trigger if exists zz_audit on public.%I', t);
    execute format('create trigger zz_audit after insert or update or delete on public.%I for each row execute function public.tg_audit()', t);
  end loop;
end $$;
drop trigger if exists aa_updated on public.leave_types;
create trigger aa_updated before update on public.leave_types for each row execute function public.tg_updated_at();
drop trigger if exists aa_updated on public.leave_requests;
create trigger aa_updated before update on public.leave_requests for each row execute function public.tg_updated_at();

-- Pengajuan dibaca lewat fungsi daftar_pengajuan/detail_pengajuan; baca langsung hanya pemilik dan admin.
drop policy if exists baca on public.leave_requests;
create policy baca on public.leave_requests for select to authenticated
  using (employee_id = public.saya() or public.admin_boleh('lihat_pengajuan'));
drop policy if exists baca on public.leave_approvals;
create policy baca on public.leave_approvals for select to authenticated
  using (oleh = public.saya() or public.admin_boleh('lihat_pengajuan')
         or exists (select 1 from leave_requests r where r.id = request_id and r.employee_id = public.saya()));

-- ---------------------------------------------------------------------
-- 6. Fungsi bantu
-- ---------------------------------------------------------------------
create or replace function public.nama_peran_jenjang(p text)
returns text language sql immutable as $$
  select case p when 'kepala_bidang' then 'Kepala Bidang/Unit' when 'direktur' then 'Direktur/Wakil Direktur'
                when 'yayasan' then 'Ketua Yayasan' else p end
$$;

/** Calon penyetuju satu jenjang untuk pemohon tertentu (tidak termasuk pemohon sendiri). */
create or replace function public.calon_penyetuju(p_emp uuid, p_peran text, p_tanggal date default null)
returns table (employee_id uuid, nama text, niy text, jabatan_tertulis text, plt boolean)
language plpgsql stable security definer set search_path = public as $$
declare v_unit uuid; v_atas uuid; v_temu uuid;
begin
  if p_peran = 'kepala_bidang' then
    select org_unit_id into v_unit from employees where id = p_emp;
    -- Telusuri dari unit pemohon ke atas; ambil pimpinan unit terdekat (Kepala Bidang atau Kepala Unit)
    v_atas := v_unit;
    while v_atas is not null and v_temu is null loop
      if exists (select 1 from public.pemegang_jabatan(p_tanggal) h
                  where h.kode in ('KEPALA_BIDANG','KEPALA_UNIT') and h.org_unit_id = v_atas and h.employee_id <> p_emp) then
        v_temu := v_atas;
      else
        select parent_id into v_atas from org_units where id = v_atas;
      end if;
    end loop;
    if v_temu is null then return; end if;
    return query
      select distinct on (h.employee_id) h.employee_id, e.nama_lengkap, e.niy,
             case when h.plt then 'Plt. ' else '' end || h.nama_jabatan || ' ' || regexp_replace(u.nama, '^(Bidang|Unit)\s+', '', 'i'), h.plt
        from public.pemegang_jabatan(p_tanggal) h join employees e on e.id = h.employee_id
        join org_units u on u.id = h.org_unit_id
       where h.kode in ('KEPALA_BIDANG','KEPALA_UNIT') and h.org_unit_id = v_temu and h.employee_id <> p_emp
       order by h.employee_id, h.plt;
  elsif p_peran = 'direktur' then
    return query
      select distinct on (h.employee_id) h.employee_id, e.nama_lengkap, e.niy,
             case when h.plt then 'Plt. ' else '' end || case h.kode when 'DIREKTUR' then 'Direktur' else 'Wakil Direktur' end, h.plt
        from public.pemegang_jabatan(p_tanggal) h join employees e on e.id = h.employee_id
       where h.kode in ('DIREKTUR','WAKIL_DIREKTUR') and h.employee_id <> p_emp
       order by h.employee_id, h.plt;
  elsif p_peran = 'yayasan' then
    return query
      select distinct on (h.employee_id) h.employee_id, e.nama_lengkap, e.niy,
             case when h.plt then 'Plt. ' else '' end || 'Ketua Yayasan', h.plt
        from public.pemegang_jabatan(p_tanggal) h join employees e on e.id = h.employee_id
       where h.kode = 'YAYASAN' and h.employee_id <> p_emp
       order by h.employee_id, h.plt;
  end if;
end $$;

/** Susunan jenjang untuk pemohon dan lama hari: jenjang tanpa pejabat dilewati; bila semua kosong, naik ke jenjang lebih tinggi. */
create or replace function public.susun_jenjang(p_emp uuid, p_hari int)
returns table (urutan int, peran text, ada_pejabat boolean)
language plpgsql stable security definer set search_path = public as $$
declare v_langkah text[]; v_semua text[] := array['kepala_bidang','direktur','yayasan']; v_ada boolean; i int := 0; v_aktif int := 0; p text; v_puncak int;
begin
  select t.langkah into v_langkah from leave_tiers t
   where p_hari >= t.mulai_hari and (t.sampai_hari is null or p_hari <= t.sampai_hari)
   order by t.mulai_hari desc limit 1;
  v_langkah := coalesce(v_langkah, v_semua);
  foreach p in array v_langkah loop
    i := i + 1;
    v_ada := exists (select 1 from public.calon_penyetuju(p_emp, p));
    if v_ada then v_aktif := v_aktif + 1; end if;
    urutan := i; peran := p; ada_pejabat := v_ada; return next;
  end loop;
  if v_aktif = 0 then
    -- naik ke jenjang di atas jenjang tertinggi pada aturan
    v_puncak := (select max(array_position(v_semua, x)) from unnest(v_langkah) x);
    for j in v_puncak + 1 .. 3 loop
      if exists (select 1 from public.calon_penyetuju(p_emp, v_semua[j])) then
        i := i + 1; urutan := i; peran := v_semua[j]; ada_pejabat := true; return next; exit;
      end if;
    end loop;
  end if;
end $$;

create or replace function public._kode_validasi()
returns text language plpgsql volatile set search_path = public as $$
declare a text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; s text; i int;
begin
  loop
    s := '';
    for i in 1..8 loop s := s || substr(a, 1 + floor(random() * length(a))::int, 1); end loop;
    s := substr(s, 1, 4) || '-' || substr(s, 5, 4);
    exit when not exists (select 1 from leave_requests where kode_validasi = s);
  end loop;
  return s;
end $$;

-- Nomor dokumen untuk proses sistem (penyetuju bukan admin): ambil_nomor menerima penanda internal
create or replace function public.ambil_nomor(
  p_format  text,
  p_tanggal date default null,
  p_dk      text default 'D',
  p_perihal text default 'NZ',
  p_kop     text default 'pondok'
) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  f doc_number_formats; h record; v_tgl date := coalesce(p_tanggal, public.hari_ini());
  v_periode text; v_urut int; v_unit text; v_nomor text;
  romawi text[] := array['I','II','III','IV','V','VI','VII','VIII','IX','X','XI','XII'];
begin
  if auth.uid() is not null and not public.is_admin() and coalesce(current_setting('simka.nomor_sistem', true), '') <> '1' then
    raise exception 'Hanya admin atau superadmin yang dapat mengambil nomor dokumen.' using errcode = '42501';
  end if;
  select * into f from doc_number_formats where kode = p_format and aktif;
  if not found then raise exception 'Format nomor "%" tidak ditemukan atau tidak aktif.', p_format; end if;
  if p_dk not in ('D','K') then raise exception 'Jenis surat harus D (Dakhily) atau K (Khariji).'; end if;
  if p_perihal is not null and not exists (select 1 from letter_subject_codes where kode = p_perihal) then
    raise exception 'Kode perihal "%" belum terdaftar.', p_perihal;
  end if;

  select * into h from public.hijriah(v_tgl);
  v_periode := case f.reset
    when 'tahun_hijriah' then h.tahun::text
    when 'tahun_masehi'  then to_char(v_tgl, 'YYYY')
    when 'bulan_masehi'  then to_char(v_tgl, 'YYYY-MM')
    else '-' end;

  insert into doc_counters (grup_urut, periode, nilai) values (f.grup_urut, v_periode, 1)
  on conflict (grup_urut, periode) do update set nilai = doc_counters.nilai + 1, updated_at = now()
  returning nilai into v_urut;

  select kode_unit into v_unit from letterheads where kode = p_kop;
  v_nomor := f.pola;
  v_nomor := replace(v_nomor, '{DK}', p_dk);
  v_nomor := replace(v_nomor, '{URUT3}', lpad(v_urut::text, 3, '0'));
  v_nomor := replace(v_nomor, '{URUT}', v_urut::text);
  v_nomor := replace(v_nomor, '{PERIHAL}', coalesce(p_perihal, ''));
  v_nomor := replace(v_nomor, '{UNIT}', coalesce(v_unit, ''));
  v_nomor := replace(v_nomor, '{BLN_H_ROMAWI}', h.bulan_romawi);
  v_nomor := replace(v_nomor, '{THN_H}', h.tahun::text);
  v_nomor := replace(v_nomor, '{BLN_ROMAWI}', romawi[extract(month from v_tgl)::int]);
  v_nomor := replace(v_nomor, '{BLN}', to_char(v_tgl, 'MM'));
  v_nomor := replace(v_nomor, '{THN}', to_char(v_tgl, 'YYYY'));

  insert into doc_numbers_issued (format_kode, nomor, urut, periode, tanggal, perihal, dibuat_oleh)
  values (p_format, v_nomor, v_urut, v_periode, v_tgl, p_perihal, public.saya());

  return jsonb_build_object('nomor', v_nomor, 'urut', v_urut, 'periode', v_periode,
                            'tanggal', v_tgl, 'hijriah', h.teks);
end $$;

/** Pemakaian kuota pegawai untuk satu jenis pada tahun dan bulan tanggal acuan (menunggu + disetujui). */
create or replace function public.pemakaian_pengajuan(p_emp uuid, p_jenis uuid, p_tanggal date, p_kecuali uuid default null)
returns table (hari_tahun int, hari_bulan int, kali_bulan int)
language sql stable security definer set search_path = public as $$
  select coalesce(sum(jumlah_hari) filter (where extract(year from mulai) = extract(year from p_tanggal)), 0)::int,
         coalesce(sum(jumlah_hari) filter (where date_trunc('month', mulai) = date_trunc('month', p_tanggal)), 0)::int,
         (count(*) filter (where date_trunc('month', mulai) = date_trunc('month', p_tanggal)))::int
    from leave_requests
   where employee_id = p_emp and leave_type_id = p_jenis and status in ('menunggu','disetujui')
     and (p_kecuali is null or id <> p_kecuali)
$$;

/** Ringkasan kuota untuk pegawai yang masuk (ditampilkan di menu Pengajuan). */
create or replace function public.kuota_saya(p_tanggal date default null)
returns table (leave_type_id uuid, kode text, nama text, kuota_tahunan_hari int, dipakai_tahun int,
               batas_bulanan_hari int, batas_bulanan_kali int, dipakai_bulan int, kali_bulan int)
language sql stable security definer set search_path = public as $$
  select t.id, t.kode, t.nama, t.kuota_tahunan_hari, u.hari_tahun, t.batas_bulanan_hari, t.batas_bulanan_kali, u.hari_bulan, u.kali_bulan
    from leave_types t, lateral public.pemakaian_pengajuan(public.saya(), t.id, coalesce(p_tanggal, public.hari_ini())) u
   where t.aktif order by t.urutan
$$;

/** Pratinjau sebelum mengirim: jenjang, pejabat, kuota, dan pelanggaran aturan. */
create or replace function public.periksa_pengajuan(p jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_emp uuid := coalesce(nullif(p->>'employee_id', '')::uuid, public.saya());
  t leave_types; e employees; v_mulai date := (p->>'mulai')::date; v_selesai date := (p->>'selesai')::date;
  v_hari int; v_hari_ini date := public.hari_ini(); u record; v_galat text[] := '{}'; v_peringatan text[] := '{}'; v_kuota boolean := false;
  v_jenjang jsonb;
begin
  if v_emp <> public.saya() and not public.is_admin() then raise exception 'Tidak berwenang.' using errcode = '42501'; end if;
  select * into e from employees where id = v_emp;
  select * into t from leave_types where id = (p->>'leave_type_id')::uuid and aktif;
  if t.id is null then return jsonb_build_object('galat', jsonb_build_array('Pilih jenis pengajuan.')); end if;
  if v_mulai is null or v_selesai is null then return jsonb_build_object('galat', jsonb_build_array('Isi tanggal mulai dan selesai.')); end if;
  if v_selesai < v_mulai then return jsonb_build_object('galat', jsonb_build_array('Tanggal selesai tidak boleh sebelum tanggal mulai.')); end if;
  v_hari := v_selesai - v_mulai + 1;

  if t.khusus_jk is not null and e.jenis_kelamin is distinct from t.khusus_jk then
    v_galat := v_galat || (t.nama || ' hanya untuk pegawai ' || case t.khusus_jk when 'P' then 'perempuan.' else 'laki-laki.' end);
  end if;
  if t.maks_hari is not null and v_hari > t.maks_hari then
    v_galat := v_galat || (t.nama || ' paling lama ' || t.maks_hari || ' hari.' ||
               case when t.kelompok = 'sakit' then ' Untuk sakit lebih lama, ajukan sebagai Izin dengan bukti.' else '' end);
  end if;
  if v_mulai < v_hari_ini - t.mundur_maks_hari then
    v_galat := v_galat || case when t.mundur_maks_hari = 0 then 'Tanggal mulai tidak boleh sebelum hari ini.'
                               else 'Tanggal mulai paling awal ' || t.mundur_maks_hari || ' hari sebelum hari ini.' end;
  end if;
  if t.maju_maks_hari is not null and v_mulai > v_hari_ini + t.maju_maks_hari then
    v_galat := v_galat || case when t.maju_maks_hari = 0 then t.nama || ' diajukan pada hari pertama (tanggal mulai = hari ini).'
                               else 'Tanggal mulai paling jauh ' || t.maju_maks_hari || ' hari ke depan.' end;
  end if;
  if t.maju_min_hari > 0 and v_mulai < v_hari_ini + t.maju_min_hari then
    v_galat := v_galat || (t.nama || ' diajukan paling lambat ' || t.maju_min_hari || ' hari sebelum tanggal mulai.');
  end if;
  if exists (select 1 from leave_requests r where r.employee_id = v_emp and r.status in ('menunggu','disetujui')
              and r.id is distinct from nullif(p->>'id', '')::uuid and daterange(r.mulai, r.selesai, '[]') && daterange(v_mulai, v_selesai, '[]')) then
    v_galat := v_galat || 'Tanggal ini bertumpuk dengan pengajuan lain yang masih berlaku.'::text;
  end if;

  select * into u from public.pemakaian_pengajuan(v_emp, t.id, v_mulai, nullif(p->>'id', '')::uuid);
  if t.kuota_tahunan_hari is not null and u.hari_tahun + v_hari > t.kuota_tahunan_hari then
    v_kuota := true;
    v_peringatan := v_peringatan || format('Kuota %s tahun ini %s hari; terpakai %s hari, sisa %s hari.', lower(t.nama),
                     t.kuota_tahunan_hari, u.hari_tahun, greatest(t.kuota_tahunan_hari - u.hari_tahun, 0));
  end if;
  if t.batas_bulanan_hari is not null and u.hari_bulan + v_hari > t.batas_bulanan_hari then
    v_kuota := true;
    v_peringatan := v_peringatan || format('Batas %s per bulan %s hari; bulan ini sudah %s hari.', lower(t.nama), t.batas_bulanan_hari, u.hari_bulan);
  end if;
  if t.batas_bulanan_kali is not null and u.kali_bulan + 1 > t.batas_bulanan_kali then
    v_kuota := true;
    v_peringatan := v_peringatan || format('Batas %s per bulan %s kali; bulan ini sudah %s kali.', lower(t.nama), t.batas_bulanan_kali, u.kali_bulan);
  end if;
  if v_kuota and t.aturan_kuota = 'tolak' then v_galat := v_galat || v_peringatan; v_peringatan := '{}'; end if;

  select coalesce(jsonb_agg(jsonb_build_object('urutan', s.urutan, 'peran', s.peran, 'nama_peran', public.nama_peran_jenjang(s.peran),
           'ada_pejabat', s.ada_pejabat,
           'pejabat', (select coalesce(jsonb_agg(c.jabatan_tertulis || ': ' || c.nama), '[]') from public.calon_penyetuju(v_emp, s.peran) c))
           order by s.urutan), '[]')
    into v_jenjang from public.susun_jenjang(v_emp, v_hari) s;

  return jsonb_build_object('jumlah_hari', v_hari, 'galat', to_jsonb(v_galat), 'peringatan', to_jsonb(v_peringatan),
    'melebihi_kuota', v_kuota, 'jenjang', v_jenjang,
    'lampiran_wajib', t.lampiran_wajib_min_hari is not null and v_hari >= t.lampiran_wajib_min_hari,
    'lampiran_keterangan', t.lampiran_keterangan);
end $$;

-- ---------------------------------------------------------------------
-- 7. Ajukan, putuskan, batalkan
-- ---------------------------------------------------------------------
create or replace function public._beri_tahu_jenjang(p_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare r leave_requests; a leave_approvals; v_nama text; v_jenis text;
begin
  select * into r from leave_requests where id = p_id;
  select * into a from leave_approvals where request_id = p_id and urutan = r.langkah_ke;
  select nama_lengkap into v_nama from employees where id = r.employee_id;
  select nama into v_jenis from leave_types where id = r.leave_type_id;
  insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
  select c.employee_id, 'Pengajuan menunggu persetujuan Anda',
         v_nama || ' mengajukan ' || lower(v_jenis) || ' ' || r.jumlah_hari || ' hari (' || to_char(r.mulai, 'DD/MM/YYYY')
           || case when r.selesai > r.mulai then '–' || to_char(r.selesai, 'DD/MM/YYYY') else '' end || ').',
         '/pengajuan/' || r.id, 'FileText', 'ungu'
    from public.calon_penyetuju(r.employee_id, a.peran) c;
end $$;

create or replace function public.ajukan_pengajuan(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_emp uuid := public.saya(); v_cek jsonb; v_id uuid; t leave_types; v_hari int; n int := 0; s record; v_pertama int;
begin
  if v_emp is null then raise exception 'Akun Anda belum aktif.' using errcode = '42501'; end if;
  if length(trim(coalesce(p->>'alasan', ''))) < 5 then raise exception 'Alasan wajib diisi (minimal 5 karakter).'; end if;
  v_cek := public.periksa_pengajuan(p - 'employee_id');
  if jsonb_array_length(v_cek->'galat') > 0 then raise exception '%', v_cek->'galat'->>0; end if;
  if (v_cek->>'lampiran_wajib')::boolean and nullif(p->>'lampiran_id', '') is null then
    raise exception 'Lampiran bukti wajib diunggah untuk pengajuan ini (%).', coalesce(v_cek->>'lampiran_keterangan', 'bukti pendukung');
  end if;
  if jsonb_array_length(v_cek->'jenjang') = 0 then
    raise exception 'Belum ada pejabat penyetuju yang terdaftar. Hubungi admin agar jabatan struktural diisi di Data Pegawai.';
  end if;
  select * into t from leave_types where id = (p->>'leave_type_id')::uuid;
  v_hari := (v_cek->>'jumlah_hari')::int;

  insert into leave_requests (employee_id, leave_type_id, mulai, selesai, jumlah_hari, alasan, alamat_selama, lampiran_id, kop_kode,
                              melebihi_kuota, catatan_kuota)
  values (v_emp, t.id, (p->>'mulai')::date, (p->>'selesai')::date, v_hari, trim(p->>'alasan'), nullif(trim(coalesce(p->>'alamat_selama', '')), ''),
          nullif(p->>'lampiran_id', '')::uuid, coalesce(nullif(p->>'kop_kode', ''), 'pondok'),
          (v_cek->>'melebihi_kuota')::boolean, nullif(array_to_string(array(select jsonb_array_elements_text(v_cek->'peringatan')), ' '), ''))
  returning id into v_id;

  for s in select * from jsonb_to_recordset(v_cek->'jenjang') as x(urutan int, peran text, ada_pejabat boolean) loop
    insert into leave_approvals (request_id, urutan, peran, status, catatan)
    values (v_id, s.urutan, s.peran, case when s.ada_pejabat then 'antre' else 'dilewati' end,
            case when s.ada_pejabat then null else 'Dilewati: belum ada pejabat ' || public.nama_peran_jenjang(s.peran) || ' untuk pemohon ini.' end);
  end loop;
  select min(urutan) into v_pertama from leave_approvals where request_id = v_id and status = 'antre';
  update leave_approvals set status = 'menunggu' where request_id = v_id and urutan = v_pertama;
  update leave_requests set langkah_ke = v_pertama where id = v_id;
  perform public._beri_tahu_jenjang(v_id);
  return v_id;
end $$;

/** Isi status presensi semua sesi wajib dalam rentang pengajuan yang disetujui. Presensi hadir yang sudah ada tidak diubah. */
create or replace function public._terapkan_pengajuan(p_id uuid)
returns int language plpgsql volatile security definer set search_path = public as $$
declare r leave_requests; t leave_types; d date; n int := 0; m int;
begin
  select * into r from leave_requests where id = p_id;
  select * into t from leave_types where id = r.leave_type_id;
  perform set_config('simka.jenis_perubahan', 'pengajuan', true);
  perform set_config('simka.alasan', t.nama || coalesce(' ' || r.nomor_surat, ''), true);
  for d in select generate_series(r.mulai, r.selesai, interval '1 day')::date loop
    insert into attendances (employee_id, tanggal, session_id, pattern_id, nama_pola, nama_sesi, jadwal_mulai, jadwal_selesai,
                             wajib_pulang, opsional, status, sumber, keterangan, leave_request_id)
    select r.employee_id, d, j.session_id, j.pattern_id, j.nama_pola, j.nama_sesi, j.mulai, j.selesai, false, j.opsional,
           t.status_presensi, 'pengajuan', t.nama || coalesce(' (' || r.nomor_surat || ')', ''), r.id
      from public.jadwal_pegawai(r.employee_id, d) j
     where not j.opsional
    on conflict (employee_id, session_id, tanggal) do update
       set status = excluded.status, sumber = 'pengajuan', keterangan = excluded.keterangan, leave_request_id = excluded.leave_request_id,
           usulan_status = null, status_pulang = null
     where attendances.datang_pada is null
       and (attendances.status in ('tanpa_keterangan','izin','sakit','cuti','menunggu_verval') or attendances.sumber in ('penutupan','izin_sesi'));
    get diagnostics m = row_count; n := n + m;
  end loop;
  return n;
end $$;

create or replace function public.putuskan_pengajuan(p_id uuid, p_setuju boolean, p_catatan text default null)
returns text language plpgsql volatile security definer set search_path = public as $$
declare r leave_requests; a leave_approvals; c record; v_saya uuid := public.saya(); v_atas_nama boolean := false;
        v_berikut int; v_nomor jsonb; v_jenis text; e employees;
begin
  select * into r from leave_requests where id = p_id for update;
  if not found then raise exception 'Pengajuan tidak ditemukan.'; end if;
  if r.status <> 'menunggu' then raise exception 'Pengajuan ini sudah %.', r.status; end if;
  select * into a from leave_approvals where request_id = p_id and urutan = r.langkah_ke;
  select * into c from public.calon_penyetuju(r.employee_id, a.peran) x where x.employee_id = v_saya limit 1;
  if c.employee_id is null then
    if public.is_superadmin() then
      v_atas_nama := true;
      if length(trim(coalesce(p_catatan, ''))) < 5 then raise exception 'Superadmin yang memutus atas nama pejabat wajib menuliskan catatan (minimal 5 karakter).'; end if;
      select * into c from public.calon_penyetuju(r.employee_id, a.peran) limit 1;
    else
      raise exception 'Anda bukan penyetuju pada jenjang ini (%).', public.nama_peran_jenjang(a.peran) using errcode = '42501';
    end if;
  end if;
  if not p_setuju and length(trim(coalesce(p_catatan, ''))) < 5 then raise exception 'Alasan penolakan wajib diisi (minimal 5 karakter).'; end if;
  select * into e from employees where id = v_saya;

  update leave_approvals set status = case when p_setuju then 'disetujui' else 'ditolak' end,
         oleh = v_saya, atas_nama = v_atas_nama, waktu = now(), catatan = nullif(trim(coalesce(p_catatan, '')), ''),
         nama = case when v_atas_nama then coalesce(c.nama, e.nama_lengkap) else e.nama_lengkap end,
         niy = case when v_atas_nama then c.niy else e.niy end,
         jabatan_tertulis = coalesce(c.jabatan_tertulis, public.nama_peran_jenjang(a.peran))
   where id = a.id;
  select nama into v_jenis from leave_types where id = r.leave_type_id;

  if not p_setuju then
    update leave_requests set status = 'ditolak', diputus_pada = now(), alasan_tolak = trim(p_catatan) where id = p_id;
    update leave_approvals set status = 'dilewati', catatan = 'Tidak diproses karena ditolak pada jenjang sebelumnya.'
     where request_id = p_id and status = 'antre';
    perform public.kirim_notifikasi(r.employee_id, 'Pengajuan ' || lower(v_jenis) || ' ditolak',
      'Ditolak oleh ' || coalesce(c.jabatan_tertulis, 'pejabat') || '. Alasan: ' || trim(p_catatan), '/pengajuan/' || p_id, 'XCircle', 'merah');
    return 'ditolak';
  end if;

  select min(urutan) into v_berikut from leave_approvals where request_id = p_id and status = 'antre';
  if v_berikut is not null then
    update leave_approvals set status = 'menunggu' where request_id = p_id and urutan = v_berikut;
    update leave_requests set langkah_ke = v_berikut where id = p_id;
    perform public._beri_tahu_jenjang(p_id);
    perform public.kirim_notifikasi(r.employee_id, 'Pengajuan Anda naik ke jenjang berikutnya',
      'Disetujui ' || coalesce(c.jabatan_tertulis, 'pejabat') || '; menunggu ' || public.nama_peran_jenjang((select peran from leave_approvals where request_id = p_id and urutan = v_berikut)) || '.',
      '/pengajuan/' || p_id, 'CheckCircle', 'biru');
    return 'naik';
  end if;

  perform set_config('simka.nomor_sistem', '1', true);
  v_nomor := public.ambil_nomor('pengajuan', public.hari_ini(), 'D', null, r.kop_kode);
  perform set_config('simka.nomor_sistem', '', true);
  update leave_requests set status = 'disetujui', diputus_pada = now(), nomor_surat = v_nomor->>'nomor', kode_validasi = public._kode_validasi()
   where id = p_id;
  perform public._terapkan_pengajuan(p_id);
  perform public.kirim_notifikasi(r.employee_id, 'Pengajuan ' || lower(v_jenis) || ' disetujui',
    'Surat ' || (v_nomor->>'nomor') || ' dapat diunduh. Presensi pada tanggal tersebut terisi otomatis.', '/pengajuan/' || p_id, 'SealCheck', 'hijau');
  return 'disetujui';
end $$;

create or replace function public.batalkan_pengajuan(p_id uuid, p_alasan text default null)
returns void language plpgsql volatile security definer set search_path = public as $$
declare r leave_requests;
begin
  select * into r from leave_requests where id = p_id for update;
  if not found then raise exception 'Pengajuan tidak ditemukan.'; end if;
  if r.status = 'menunggu' and r.employee_id = public.saya() then
    null;
  elsif r.status in ('menunggu','disetujui') and public.is_superadmin() then
    if length(trim(coalesce(p_alasan, ''))) < 5 then raise exception 'Alasan pembatalan wajib diisi (minimal 5 karakter).'; end if;
  else
    raise exception 'Pengajuan ini tidak dapat dibatalkan. Pemohon hanya dapat membatalkan selama belum diputus; pembatalan setelah disetujui oleh superadmin.' using errcode = '42501';
  end if;
  update leave_requests set status = 'dibatalkan', dibatalkan_oleh = public.saya(), alasan_tolak = nullif(trim(coalesce(p_alasan, '')), '') where id = p_id;
  update leave_approvals set status = 'dilewati', catatan = 'Pengajuan dibatalkan.' where request_id = p_id and status in ('antre','menunggu');
  if r.status = 'disetujui' then
    perform set_config('simka.jenis_perubahan', 'koreksi', true);
    perform set_config('simka.alasan', 'Pengajuan dibatalkan: ' || coalesce(p_alasan, ''), true);
    delete from attendances where leave_request_id = p_id and datang_pada is null and sumber = 'pengajuan';
    perform public.kirim_notifikasi(r.employee_id, 'Pengajuan Anda dibatalkan superadmin', p_alasan, '/pengajuan/' || p_id, 'XCircle', 'merah');
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 8. Daftar dan detail
-- ---------------------------------------------------------------------
create or replace function public.boleh_lihat_pengajuan(p_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from leave_requests r where r.id = p_id and (
           r.employee_id = public.saya() or public.admin_boleh('lihat_pengajuan')
           or exists (select 1 from leave_approvals a where a.request_id = r.id and a.oleh = public.saya())
           or exists (select 1 from leave_approvals a, public.calon_penyetuju(r.employee_id, a.peran) c
                       where a.request_id = r.id and a.status in ('menunggu','disetujui','ditolak') and c.employee_id = public.saya())))
$$;

/** cakupan: 'saya' | 'persetujuan' (menunggu keputusan saya + yang pernah saya putus) | 'semua' (admin ber-izin lihat_pengajuan) */
create or replace function public.daftar_pengajuan(p_cakupan text default 'saya', p_mulai date default null, p_akhir date default null)
returns table (id uuid, employee_id uuid, pemohon text, niy text, unit text, jabatan text, jenis text, kelompok text,
               mulai date, selesai date, jumlah_hari int, alasan text, status text, langkah_ke int, jenjang_kini text,
               melebihi_kuota boolean, nomor_surat text, created_at timestamptz, diputus_pada timestamptz, menunggu_saya boolean)
language plpgsql stable security definer set search_path = public as $$
declare v_saya uuid := public.saya();
begin
  if p_cakupan = 'semua' and not public.admin_boleh('lihat_pengajuan') then raise exception 'Tidak berwenang.' using errcode = '42501'; end if;
  return query
  select r.id, r.employee_id, e.nama_lengkap, e.niy, u.nama, v.jabatan, t.nama, t.kelompok, r.mulai, r.selesai, r.jumlah_hari, r.alasan,
         r.status, r.langkah_ke,
         (select public.nama_peran_jenjang(a.peran) from leave_approvals a where a.request_id = r.id and a.urutan = r.langkah_ke),
         r.melebihi_kuota, r.nomor_surat, r.created_at, r.diputus_pada,
         (r.status = 'menunggu' and exists (select 1 from leave_approvals a, public.calon_penyetuju(r.employee_id, a.peran) c
            where a.request_id = r.id and a.urutan = r.langkah_ke and c.employee_id = v_saya))
    from leave_requests r join employees e on e.id = r.employee_id join leave_types t on t.id = r.leave_type_id
    left join org_units u on u.id = e.org_unit_id
    left join lateral (select concat_ws(', ', (select sp.nama from employee_structurals es join structural_positions sp on sp.id = es.structural_position_id where es.employee_id = e.id),
                         (select string_agg(fp.nama, ', ' order by fp.urutan) from employee_functions ef join functional_positions fp on fp.id = ef.functional_position_id where ef.employee_id = e.id)) as jabatan) v on true
   where (p_mulai is null or r.selesai >= p_mulai) and (p_akhir is null or r.mulai <= p_akhir)
     and case p_cakupan
           when 'saya' then r.employee_id = v_saya
           when 'semua' then true
           else (exists (select 1 from leave_approvals a where a.request_id = r.id and a.oleh = v_saya)
                 or (r.status = 'menunggu' and exists (select 1 from leave_approvals a, public.calon_penyetuju(r.employee_id, a.peran) c
                       where a.request_id = r.id and a.urutan = r.langkah_ke and c.employee_id = v_saya)))
         end
   order by (r.status = 'menunggu') desc, r.created_at desc
   limit 500;
end $$;

create or replace function public.detail_pengajuan(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare r leave_requests; v jsonb; v_saya uuid := public.saya();
begin
  if not public.boleh_lihat_pengajuan(p_id) and not public.is_superadmin() then raise exception 'Anda tidak berhak melihat pengajuan ini.' using errcode = '42501'; end if;
  select * into r from leave_requests where id = p_id;
  select to_jsonb(r) || jsonb_build_object(
    'pemohon', jsonb_build_object('nama', e.nama_lengkap, 'niy', e.niy, 'unit', u.nama, 'jenis_kelamin', e.jenis_kelamin,
                 'jabatan', concat_ws(', ', (select sp.nama from employee_structurals es join structural_positions sp on sp.id = es.structural_position_id where es.employee_id = e.id),
                   (select string_agg(fp.nama, ', ' order by fp.urutan) from employee_functions ef join functional_positions fp on fp.id = ef.functional_position_id where ef.employee_id = e.id))),
    'jenis', jsonb_build_object('nama', t.nama, 'kelompok', t.kelompok, 'kode', t.kode),
    'jenjang', (select coalesce(jsonb_agg(jsonb_build_object('urutan', a.urutan, 'peran', a.peran, 'nama_peran', public.nama_peran_jenjang(a.peran),
                  'status', a.status, 'nama', a.nama, 'niy', a.niy, 'jabatan_tertulis', a.jabatan_tertulis, 'atas_nama', a.atas_nama,
                  'catatan', a.catatan, 'waktu', a.waktu,
                  'calon', case when a.status = 'menunggu' then (select coalesce(jsonb_agg(c.jabatan_tertulis || ': ' || c.nama), '[]') from public.calon_penyetuju(r.employee_id, a.peran) c) end)
                  order by a.urutan), '[]') from leave_approvals a where a.request_id = r.id),
    'boleh_putuskan', r.status = 'menunggu' and (public.is_superadmin() or exists (
                  select 1 from leave_approvals a, public.calon_penyetuju(r.employee_id, a.peran) c
                   where a.request_id = r.id and a.urutan = r.langkah_ke and c.employee_id = v_saya)),
    'atas_nama', r.status = 'menunggu' and public.is_superadmin() and not exists (
                  select 1 from leave_approvals a, public.calon_penyetuju(r.employee_id, a.peran) c
                   where a.request_id = r.id and a.urutan = r.langkah_ke and c.employee_id = v_saya),
    'boleh_batal', (r.status = 'menunggu' and r.employee_id = v_saya) or (r.status in ('menunggu','disetujui') and public.is_superadmin()),
    'sesi_terisi', (select count(*) from attendances x where x.leave_request_id = r.id))
    into v
    from employees e join leave_types t on t.id = r.leave_type_id left join org_units u on u.id = e.org_unit_id
   where e.id = r.employee_id;
  return v;
end $$;

/** Hak lihat berkas tambahan (dipakai Edge Function "berkas"): penyetuju dan pemegang izin lihat_pengajuan boleh melihat lampiran pengajuan. */
create or replace function public.boleh_lihat_berkas(p_obj uuid, p_emp uuid)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare r leave_requests; v_peran text;
begin
  select peran into v_peran from employees where id = p_emp;
  for r in select * from leave_requests where lampiran_id = p_obj loop
    if r.employee_id = p_emp or v_peran = 'superadmin'
       or (v_peran = 'admin' and exists (select 1 from admin_permissions where employee_id = p_emp and kode = 'lihat_pengajuan'))
       or exists (select 1 from leave_approvals a where a.request_id = r.id and a.oleh = p_emp)
       or exists (select 1 from leave_approvals a, public.calon_penyetuju(r.employee_id, a.peran) c
                   where a.request_id = r.id and a.status = 'menunggu' and c.employee_id = p_emp) then
      return true;
    end if;
  end loop;
  return false;
end $$;

-- ---------------------------------------------------------------------
-- 9. Penanda tangan mengikuti jabatan struktural di Data Pegawai
-- ---------------------------------------------------------------------
alter table public.signatories add column if not exists sumber_jabatan text;          -- kode jabatan struktural, mis. DIREKTUR
alter table public.signatories add column if not exists sumber_unit_id uuid references public.org_units(id) on delete set null;

create or replace function public._isi_penanda_tangan(s signatories)
returns signatories language plpgsql stable security definer set search_path = public as $$
declare h record;
begin
  if s.sumber_jabatan is null then return s; end if;
  select e.id, e.nama_lengkap, e.niy into h
    from employee_structurals es join structural_positions sp on sp.id = es.structural_position_id
    join employees e on e.id = es.employee_id
   where sp.kode = s.sumber_jabatan and e.status_keaktifan = 'aktif'
     and (s.sumber_unit_id is null or es.org_unit_id = s.sumber_unit_id)
   order by es.tmt desc nulls last, es.created_at desc limit 1;
  if h.id is not null then s.employee_id := h.id; s.nama := h.nama_lengkap; s.niy := h.niy; end if;
  return s;
end $$;

create or replace function public.tg_penanda_tangan_isi()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  new := public._isi_penanda_tangan(new);
  return new;
end $$;
drop trigger if exists aa_isi_jabatan on public.signatories;
create trigger aa_isi_jabatan before insert or update on public.signatories for each row execute function public.tg_penanda_tangan_isi();

create or replace function public.sinkron_penanda_tangan()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  -- Sentuh baris yang tertaut agar pemicu aa_isi_jabatan mengisi ulang nama dan NIY
  update signatories set sumber_jabatan = sumber_jabatan where sumber_jabatan is not null;
  return null;
end $$;
drop trigger if exists zz_sinkron_ttd on public.employee_structurals;
create trigger zz_sinkron_ttd after insert or update or delete on public.employee_structurals
  for each statement execute function public.sinkron_penanda_tangan();
drop trigger if exists zz_sinkron_ttd on public.employees;
create trigger zz_sinkron_ttd after update of nama_lengkap, niy, status_keaktifan on public.employees
  for each statement execute function public.sinkron_penanda_tangan();

-- Baris "Direktur" ditautkan ke jabatan struktural DIREKTUR (nama manual tetap dipakai bila belum ada pemegangnya)
update public.signatories set sumber_jabatan = 'DIREKTUR'
 where sumber_jabatan is null and lower(trim(jabatan_tertulis)) in ('direktur','direktur (mudir)','mudir');

-- ---------------------------------------------------------------------
-- 10. Hak eksekusi
-- ---------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array['_beri_tahu_jenjang(uuid)','_terapkan_pengajuan(uuid)','_kode_validasi()','_isi_penanda_tangan(signatories)',
    'tg_penanda_tangan_isi()','sinkron_penanda_tangan()','boleh_lihat_berkas(uuid,uuid)']
  loop execute format('revoke execute on function public.%s from public, anon, authenticated', f); end loop;
  execute 'grant execute on function public.boleh_lihat_berkas(uuid,uuid) to service_role';
  foreach f in array array['pemegang_jabatan(date)','calon_penyetuju(uuid,text,date)','susun_jenjang(uuid,int)','pemakaian_pengajuan(uuid,uuid,date,uuid)',
    'kuota_saya(date)','periksa_pengajuan(jsonb)','ajukan_pengajuan(jsonb)','putuskan_pengajuan(uuid,boolean,text)','batalkan_pengajuan(uuid,text)',
    'boleh_lihat_pengajuan(uuid)','daftar_pengajuan(text,date,date)','detail_pengajuan(uuid)','boleh_atur_pengajuan()','nama_peran_jenjang(text)']
  loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
grant select, insert, update, delete on public.leave_types, public.leave_tiers, public.acting_assignments to authenticated;
grant select on public.leave_requests, public.leave_approvals to authenticated;

do $$ begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'leave_requests') then
    alter publication supabase_realtime add table public.leave_requests;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 6 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select 'Tabel pengajuan (5)' as pemeriksaan,
       case when count(*) = 5 then 'Sesuai' else 'Periksa: ' || count(*) end as hasil
  from pg_tables where schemaname = 'public'
   and tablename in ('leave_types','leave_tiers','acting_assignments','leave_requests','leave_approvals')
union all
select 'RLS aktif di tabel pengajuan',
       case when bool_and(rowsecurity) then 'Sesuai' else 'Periksa' end
  from pg_tables where schemaname = 'public'
   and tablename in ('leave_types','leave_tiers','acting_assignments','leave_requests','leave_approvals')
union all
select 'Jenis pengajuan isi awal (minimal 9)',
       case when count(*) >= 9 then 'Sesuai' else 'Periksa: ' || count(*) end from public.leave_types
union all
select 'Jenjang persetujuan (minimal 1 aturan)',
       case when count(*) >= 1 then 'Sesuai' else 'Periksa' end from public.leave_tiers
union all
select 'Fungsi pengajuan inti (6)',
       case when count(*) = 6 then 'Sesuai' else 'Periksa: ' || count(*) end
  from pg_proc where pronamespace = 'public'::regnamespace
   and proname in ('periksa_pengajuan','ajukan_pengajuan','putuskan_pengajuan','batalkan_pengajuan','daftar_pengajuan','detail_pengajuan')
union all
select 'Migrasi 1900 sudah terpasang',
       case when exists (select 1 from pg_proc where proname = 'simpan_pengumuman') then 'Sesuai' else 'Periksa: jalankan 1900 dulu' end;
