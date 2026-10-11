-- SIMKA PRO | supabase/migrations/20261011007100_gaji_periode.sql | v1.0 | Fase 11 – Tahap 2 Periode gaji, perhitungan, penetapan yayasan | 11/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 11 · Migrasi 71: Periode gaji dan perhitungan (Blueprint Bagian 36)
-- Prinsip: SLIP SELALU MEMUAT NOMINAL YANG BENAR-BENAR DITERIMA. Skema tarif hanya titik awal hitungan.
--   * salary_decisions  : penetapan gaji oleh Ketua Yayasan (hak prerogatif) per pegawai dengan tanggal berlaku:
--                         - mode "total"  : jumlah pendapatan ditetapkan (mis. Rp3.500.000), berapa pun hasil skema;
--                         - mode "selisih": tambahan/pengurangan tetap dari skema (mis. +Rp250.000 atau −Rp100.000).
--                         Selisihnya tampil sebagai baris "Penyesuaian ketetapan yayasan" (label dapat diubah di Ketentuan).
--   * payroll_periods   : periode gaji bulanan (draf → diajukan → terbit; atau batal). Tahap ini: draf.
--   * payroll_lines     : satu baris per pegawai per periode, dengan salinan data penentu gaji (jabatan, status,
--                         pendidikan, masa kerja, rekening) dan jumlah: skema, penyesuaian, pendapatan, potongan, diterima.
--                         "Jumlah diterima" dapat diisi langsung (atau impor Excel) → penyesuaian dihitung otomatis.
--   * payroll_items     : rincian komponen. Sumber: skema (otomatis), penetapan (yayasan), manual (diubah/ditambah
--                         Bendahara dengan alasan), impor. Komponen skema yang diubah tetap dipertahankan saat hitung ulang.
--   * Honor per jam (honorer): guru = JP jurnal mengajar "terlaksana"; muhaffizh = jam sesi halaqah yang terisi.
--     Honorer guru/muhaffizh tidak menerima tunjangan fungsional Guru mapel/Muhaffizh (sudah dibayar per jam).
--   * Hak: dibaca pembaca gaji, diubah pengelola gaji, semuanya lewat fungsi. Tabel tertutup untuk tulis langsung.
-- Jalankan SETELAH migrasi 7000. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. KETENTUAN: label penyesuaian
-- ---------------------------------------------------------------------
create or replace function public._pengaturan_gaji()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('slip_pegawai', false, 'ttd_direktur', false, 'pembulatan', 100,
           'potong_izin', false, 'potong_sakit', false, 'potong_cuti', false, 'potong_terlambat', false,
           'tanggal_gajian', 1, 'honorer_tunjangan_jabatan', true, 'info_beban_kerja', true, 'catatan_slip', '',
           'label_penyesuaian', 'Penyesuaian ketetapan yayasan')
         || coalesce((select nilai from institution_settings where kunci = 'gaji'), '{}'::jsonb)
$$;

create or replace function public.simpan_pengaturan_gaji(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v jsonb := public._pengaturan_gaji(); k text; v_bulat int; v_tgl int;
begin
  if not public.boleh_kelola_gaji() then raise exception 'Anda tidak berwenang mengatur ketentuan gaji.' using errcode = '42501'; end if;
  foreach k in array array['slip_pegawai','ttd_direktur','potong_izin','potong_sakit','potong_cuti','potong_terlambat',
                           'honorer_tunjangan_jabatan','info_beban_kerja'] loop
    if p ? k then v := v || jsonb_build_object(k, coalesce((p->>k)::boolean, false)); end if;
  end loop;
  if p ? 'pembulatan' then
    v_bulat := coalesce((p->>'pembulatan')::int, 100);
    if v_bulat not in (1, 100, 500, 1000) then raise exception 'Pembulatan hanya 1, 100, 500, atau 1.000 rupiah.'; end if;
    v := v || jsonb_build_object('pembulatan', v_bulat);
  end if;
  if p ? 'tanggal_gajian' then
    v_tgl := coalesce((p->>'tanggal_gajian')::int, 1);
    if v_tgl < 1 or v_tgl > 28 then raise exception 'Tanggal gajian antara 1 dan 28.'; end if;
    v := v || jsonb_build_object('tanggal_gajian', v_tgl);
  end if;
  if p ? 'catatan_slip' then v := v || jsonb_build_object('catatan_slip', left(trim(coalesce(p->>'catatan_slip', '')), 300)); end if;
  if p ? 'label_penyesuaian' then
    v := v || jsonb_build_object('label_penyesuaian', coalesce(nullif(left(trim(coalesce(p->>'label_penyesuaian', '')), 60), ''), 'Penyesuaian ketetapan yayasan'));
  end if;
  insert into institution_settings (kunci, nilai, updated_by) values ('gaji', v, public.saya())
  on conflict (kunci) do update set nilai = excluded.nilai, updated_at = now(), updated_by = excluded.updated_by;
  return public._pengaturan_gaji();
end $$;

-- ---------------------------------------------------------------------
-- 1. TABEL
-- ---------------------------------------------------------------------
create table if not exists public.salary_decisions (
  id             uuid primary key default gen_random_uuid(),
  employee_id    uuid not null references public.employees(id) on delete cascade,
  mode           text not null check (mode in ('total','selisih')),
  nilai          numeric(12,0) not null,
  keterangan     text not null check (length(trim(keterangan)) >= 3),
  dasar          text,                         -- nomor/tanggal ketetapan bila ada
  berlaku_mulai  date not null,
  berlaku_sampai date,
  dibuat_oleh    uuid references public.employees(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  check (mode = 'selisih' or nilai >= 0),
  check (berlaku_sampai is null or berlaku_sampai >= berlaku_mulai)
);
create index if not exists salary_decisions_emp_idx on public.salary_decisions (employee_id, berlaku_mulai desc);
comment on table public.salary_decisions is 'Penetapan gaji oleh Ketua Yayasan per pegawai (jumlah tetap atau selisih dari skema), bertanggal berlaku.';

create table if not exists public.payroll_periods (
  id            uuid primary key default gen_random_uuid(),
  tahun         int not null check (tahun between 2020 and 2100),
  bulan         int not null check (bulan between 1 and 12),
  tanggal_mulai date not null,
  tanggal_akhir date not null,
  tanggal_bayar date,
  status        text not null default 'draf' check (status in ('draf','diajukan','terbit','batal')),
  catatan       text,
  dihitung_pada timestamptz,
  dibuat_oleh   uuid references public.employees(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (tahun, bulan)
);
comment on table public.payroll_periods is 'Periode gaji bulanan.';

create table if not exists public.payroll_lines (
  id                uuid primary key default gen_random_uuid(),
  period_id         uuid not null references public.payroll_periods(id) on delete cascade,
  employee_id       uuid not null references public.employees(id) on delete restrict,
  data              jsonb not null default '{}'::jsonb,   -- salinan data penentu gaji + catatan kekurangan data
  target_diterima   numeric(12,0),                         -- jumlah diterima yang ditetapkan langsung (impor/isi)
  alasan_target     text,
  total_skema       numeric(12,0) not null default 0,
  total_penyesuaian numeric(12,0) not null default 0,
  total_pendapatan  numeric(12,0) not null default 0,
  total_potongan    numeric(12,0) not null default 0,
  diterima          numeric(12,0) not null default 0,
  catatan           text,
  updated_by        uuid references public.employees(id) on delete set null,
  updated_at        timestamptz not null default now(),
  unique (period_id, employee_id)
);
create index if not exists payroll_lines_emp_idx on public.payroll_lines (employee_id);

create table if not exists public.payroll_items (
  id             uuid primary key default gen_random_uuid(),
  line_id        uuid not null references public.payroll_lines(id) on delete cascade,
  jenis          text not null check (jenis in ('pendapatan','potongan')),
  kategori       text not null,   -- struktural, fungsional, pendidikan, masa_kerja, kepegawaian, kesehatan, level_muhaffizh,
                                  -- honor, penyesuaian, tambahan | potongan_kehadiran, pinjaman, simpanan, potongan_lain
  kode           text,
  label          text not null,
  jumlah         numeric(8,2),    -- jam/sesi (honor, potongan kehadiran)
  tarif          numeric(12,0),
  besaran_skema  numeric(12,0),   -- nilai menurut skema (null untuk tambahan manual)
  besaran        numeric(12,0) not null,
  sumber         text not null default 'skema' check (sumber in ('skema','penetapan','manual','impor')),
  alasan         text,
  rincian        jsonb not null default '{}'::jsonb,
  urutan         int not null default 0,
  diubah_oleh    uuid references public.employees(id) on delete set null,
  diubah_pada    timestamptz
);
create index if not exists payroll_items_line_idx on public.payroll_items (line_id, urutan);

-- RLS: hanya dibaca pembaca gaji (slip pegawai dibuka di tahap penerbitan); tulis hanya lewat fungsi
alter table public.salary_decisions enable row level security;
alter table public.payroll_periods enable row level security;
alter table public.payroll_lines enable row level security;
alter table public.payroll_items enable row level security;
drop policy if exists baca on public.salary_decisions;
create policy baca on public.salary_decisions for select to authenticated using (public.boleh_lihat_gaji());
drop policy if exists baca on public.payroll_periods;
create policy baca on public.payroll_periods for select to authenticated using (public.boleh_lihat_gaji());
drop policy if exists baca on public.payroll_lines;
create policy baca on public.payroll_lines for select to authenticated using (public.boleh_lihat_gaji());
drop policy if exists baca on public.payroll_items;
create policy baca on public.payroll_items for select to authenticated
  using (public.boleh_lihat_gaji());
grant select on public.salary_decisions, public.payroll_periods, public.payroll_lines, public.payroll_items to authenticated;

-- ---------------------------------------------------------------------
-- 2. PERHITUNGAN
-- ---------------------------------------------------------------------
create or replace function public._wajib_kelola_gaji()
returns void language plpgsql stable security definer set search_path = public as $$
begin
  if not public.boleh_kelola_gaji() then raise exception 'Anda tidak berwenang mengelola gaji.' using errcode = '42501'; end if;
end $$;

create or replace function public._wajib_periode_draf(p_period uuid)
returns payroll_periods language plpgsql stable security definer set search_path = public as $$
declare v payroll_periods;
begin
  select * into v from payroll_periods where id = p_period;
  if not found then raise exception 'Periode gaji tidak ditemukan.'; end if;
  if v.status <> 'draf' then raise exception 'Periode gaji % sudah % sehingga tidak dapat diubah.', to_char(make_date(v.tahun, v.bulan, 1), 'MM/YYYY'),
    case v.status when 'diajukan' then 'diajukan' when 'terbit' then 'terbit' else 'dibatalkan' end; end if;
  return v;
end $$;

/** Salinan data penentu gaji seorang pegawai pada tanggal akhir periode, beserta catatan kekurangan data. */
create or replace function public._data_gaji(p_emp uuid, p_tanggal date)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare e employees; v_th int; v_bln int; v_cat text[] := '{}'; v_rek jsonb;
begin
  select * into e from employees where id = p_emp;
  if e.tmt_tugas is not null and e.tmt_tugas <= p_tanggal then
    v_th := extract(year from age(p_tanggal, e.tmt_tugas))::int; v_bln := extract(month from age(p_tanggal, e.tmt_tugas))::int;
  end if;
  if e.status_kepegawaian is null then v_cat := array_append(v_cat, 'Status kepegawaian belum diisi.'); end if;
  if e.status_kepegawaian = 'honorer' and e.kategori_honorer is null then v_cat := array_append(v_cat, 'Kategori honorer (lama/baru) belum diisi.'); end if;
  if coalesce(e.status_kepegawaian, '') <> 'honorer' then
    if e.pendidikan_terakhir is null then v_cat := array_append(v_cat, 'Pendidikan terakhir belum diisi.'); end if;
    if e.tmt_tugas is null then v_cat := array_append(v_cat, 'TMT tugas belum diisi.'); end if;
  end if;
  select jsonb_build_object('cara_bayar', cara_bayar, 'bank', bank, 'nomor_rekening', nomor_rekening, 'atas_nama', atas_nama)
    into v_rek from employee_bank_accounts where employee_id = p_emp;
  if v_rek is null then v_cat := array_append(v_cat, 'Rekening/cara bayar belum diisi.'); end if;
  return jsonb_build_object(
    'niy', e.niy, 'nama', e.nama_lengkap, 'jk', e.jenis_kelamin,
    'unit', (select nama from org_units where id = e.org_unit_id), 'org_unit_id', e.org_unit_id,
    'status', e.status_kepegawaian, 'kategori_honorer', e.kategori_honorer, 'pendidikan', e.pendidikan_terakhir,
    'tmt', e.tmt_tugas, 'masa_kerja_tahun', coalesce(v_th, 0), 'masa_kerja_bulan', coalesce(v_bln, 0),
    'level_muhaffizh', e.level_muhaffizh,
    'jabatan_struktural', (select sp.nama from employee_structurals es join structural_positions sp on sp.id = es.structural_position_id where es.employee_id = p_emp),
    'jabatan_fungsional', coalesce((select jsonb_agg(fp.nama order by fp.urutan) from employee_functions ef join functional_positions fp on fp.id = ef.functional_position_id where ef.employee_id = p_emp), '[]'::jsonb),
    'rekening', v_rek, 'catatan', to_jsonb(v_cat));
end $$;

/** Komponen pendapatan menurut skema tarif pada tanggal tertentu (belum termasuk honor per jam dan penyesuaian). */
create or replace function public._komponen_skema(p_emp uuid, p_tanggal date)
returns table (kategori text, kode text, label text, besaran numeric, urutan int, catatan text)
language plpgsql stable security definer set search_path = public as $$
declare e employees; v_hon boolean; v_jab boolean; r record; v_th int; v_t salary_rates;
begin
  select * into e from employees where id = p_emp;
  v_hon := e.status_kepegawaian = 'honorer';
  v_jab := not v_hon or coalesce((public._pengaturan_gaji()->>'honorer_tunjangan_jabatan')::boolean, true);
  -- Struktural (satu jabatan)
  if v_jab then
    for r in select sp.kode, sp.nama from employee_structurals es join structural_positions sp on sp.id = es.structural_position_id where es.employee_id = p_emp loop
      select * into v_t from public.tarif_berlaku(p_tanggal) t where t.kategori = 'struktural' and t.kunci = r.kode;
      if found then return query select 'struktural'::text, r.kode, 'Tunjangan jabatan ' || r.nama, v_t.besaran, 10, null::text;
      else return query select 'struktural'::text, r.kode, null::text, 0::numeric, 10, 'Tarif jabatan struktural ' || r.nama || ' belum diatur.'; end if;
    end loop;
  end if;
  -- Fungsional (diakumulasi); honorer guru/muhaffizh dibayar per jam, bukan tunjangan fungsional itu
  if v_jab then
    for r in select fp.kode, fp.nama, fp.urutan from employee_functions ef join functional_positions fp on fp.id = ef.functional_position_id
              where ef.employee_id = p_emp and not (v_hon and fp.kode in ('GURU','MUHAFFIZH')) order by fp.urutan loop
      select * into v_t from public.tarif_berlaku(p_tanggal) t where t.kategori = 'fungsional' and t.kunci = r.kode;
      if found then return query select 'fungsional'::text, r.kode, 'Tunjangan ' || r.nama, v_t.besaran, 20 + r.urutan, null::text;
      else return query select 'fungsional'::text, r.kode, null::text, 0::numeric, 20 + r.urutan, 'Tarif ' || r.nama || ' belum diatur.'; end if;
    end loop;
  end if;
  if v_hon then return; end if;
  -- Pendidikan
  if e.pendidikan_terakhir is not null then
    select * into v_t from public.tarif_berlaku(p_tanggal) t where t.kategori = 'pendidikan' and t.kunci = e.pendidikan_terakhir;
    if found then return query select 'pendidikan'::text, e.pendidikan_terakhir, 'Tunjangan pendidikan ' || v_t.nama, v_t.besaran, 60, null::text;
    else return query select 'pendidikan'::text, e.pendidikan_terakhir, null::text, 0::numeric, 60, 'Tarif pendidikan ' || e.pendidikan_terakhir || ' belum diatur.'; end if;
  end if;
  -- Masa kerja (tahun penuh, maksimal 12)
  if e.tmt_tugas is not null and e.tmt_tugas <= p_tanggal then
    v_th := least(12, extract(year from age(p_tanggal, e.tmt_tugas))::int);
    if v_th >= 1 then
      select * into v_t from public.tarif_berlaku(p_tanggal) t where t.kategori = 'masa_kerja' and t.kunci = v_th::text;
      if found then return query select 'masa_kerja'::text, v_th::text, 'Tunjangan masa kerja ' || v_th || ' tahun', v_t.besaran, 70, null::text;
      else return query select 'masa_kerja'::text, v_th::text, null::text, 0::numeric, 70, 'Tarif masa kerja ' || v_th || ' tahun belum diatur.'; end if;
    end if;
  end if;
  -- Kepegawaian dan kesehatan
  if e.status_kepegawaian in ('tetap','kontrak') then
    select * into v_t from public.tarif_berlaku(p_tanggal) t where t.kategori = 'kepegawaian' and t.kunci = e.status_kepegawaian;
    if found then return query select 'kepegawaian'::text, e.status_kepegawaian, 'Tunjangan kepegawaian', v_t.besaran, 80, null::text; end if;
    select * into v_t from public.tarif_berlaku(p_tanggal) t where t.kategori = 'kesehatan' and t.kunci = e.status_kepegawaian;
    if found then return query select 'kesehatan'::text, e.status_kepegawaian, 'Tunjangan kesehatan', v_t.besaran, 81, null::text; end if;
  end if;
  -- Level muhaffizh
  if exists (select 1 from employee_functions ef join functional_positions fp on fp.id = ef.functional_position_id where ef.employee_id = p_emp and fp.kode = 'MUHAFFIZH') then
    if e.level_muhaffizh is null then return query select 'level_muhaffizh'::text, null::text, null::text, 0::numeric, 90, 'Level muhaffizh belum diisi.';
    else
      select * into v_t from public.tarif_berlaku(p_tanggal) t where t.kategori = 'level_muhaffizh' and t.kunci = e.level_muhaffizh;
      if found then return query select 'level_muhaffizh'::text, e.level_muhaffizh, 'Tunjangan level muhaffizh ' || lower(v_t.nama), v_t.besaran, 90, null::text; end if;
    end if;
  end if;
end $$;

/** Jam honor dalam rentang tanggal: guru = JP terlaksana (jurnal mengajar), muhaffizh = jam sesi halaqah yang terisi. */
create or replace function public._jam_honor(p_emp uuid, p_mulai date, p_akhir date)
returns table (kode text, jam numeric, rincian jsonb)
language sql stable security definer set search_path = public as $$
  select 'guru', count(*)::numeric, jsonb_build_object('sumber', 'Jurnal mengajar', 'jp_terlaksana', count(*))
    from teaching_journals where employee_id = p_emp and status = 'terlaksana' and tanggal between p_mulai and p_akhir
  union all
  select 'muhaffizh', coalesce(round(sum(extract(epoch from (coalesce(jam_selesai, jam_mulai + interval '1 hour') - jam_mulai)) / 3600.0)::numeric, 2), 0),
         jsonb_build_object('sumber', 'Absensi halaqah', 'sesi', count(*))
    from student_attendance_sessions where pengampu_id = p_emp and jenis = 'halaqah' and tanggal between p_mulai and p_akhir
$$;

create or replace function public._jumlahkan_baris(p_line uuid)
returns void language sql volatile security definer set search_path = public as $$
  update payroll_lines l set
    total_skema = coalesce((select sum(coalesce(besaran_skema, 0)) from payroll_items where line_id = l.id and jenis = 'pendapatan' and kategori not in ('penyesuaian','tambahan')), 0),
    total_penyesuaian = coalesce((select sum(besaran) from payroll_items where line_id = l.id and kategori = 'penyesuaian'), 0),
    total_pendapatan = coalesce((select sum(besaran) from payroll_items where line_id = l.id and jenis = 'pendapatan'), 0),
    total_potongan = coalesce((select sum(besaran) from payroll_items where line_id = l.id and jenis = 'potongan'), 0),
    diterima = coalesce((select sum(case when jenis = 'pendapatan' then besaran else -besaran end) from payroll_items where line_id = l.id), 0),
    updated_at = now()
  where l.id = p_line
$$;

/** Hitung ulang satu baris gaji. Komponen yang pernah diubah Bendahara (sumber manual) dipertahankan nominalnya;
 *  tambahan/potongan manual tidak disentuh; penyesuaian dihitung ulang dari target diterima atau penetapan yayasan. */
create or replace function public._hitung_baris(p_line uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare l payroll_lines; pr payroll_periods; e employees; k record; h record; v_ubah record; v_ubahan jsonb;
        v_tarif salary_rates; v_jam numeric; v_besar numeric; v_cat text[] := '{}'; v_data jsonb;
        d salary_decisions; v_dasar numeric; v_label text := public._pengaturan_gaji()->>'label_penyesuaian';
begin
  select * into l from payroll_lines where id = p_line;
  select * into pr from payroll_periods where id = l.period_id;
  select * into e from employees where id = l.employee_id;
  -- Simpan nilai komponen skema yang pernah diubah
  select coalesce(jsonb_agg(jsonb_build_object('kategori', i.kategori, 'kode', coalesce(i.kode, ''), 'besaran', i.besaran, 'jumlah', i.jumlah,
           'alasan', i.alasan, 'oleh', i.diubah_oleh, 'pada', i.diubah_pada)), '[]'::jsonb) into v_ubahan
    from payroll_items i where i.line_id = p_line and i.sumber = 'manual' and i.besaran_skema is not null;
  delete from payroll_items i where i.line_id = p_line and (i.sumber in ('skema','penetapan') or (i.sumber = 'manual' and i.besaran_skema is not null) or i.kategori = 'penyesuaian');

  -- Komponen skema
  for k in select * from public._komponen_skema(l.employee_id, pr.tanggal_akhir) loop
    if k.catatan is not null then v_cat := array_append(v_cat, k.catatan); continue; end if;
    select * into v_ubah from jsonb_to_recordset(v_ubahan) u(kategori text, kode text, besaran numeric, jumlah numeric, alasan text, oleh uuid, pada timestamptz)
      where u.kategori = k.kategori and u.kode = coalesce(k.kode, '');
    insert into payroll_items (line_id, jenis, kategori, kode, label, besaran_skema, besaran, sumber, alasan, urutan, diubah_oleh, diubah_pada)
    values (p_line, 'pendapatan', k.kategori, k.kode, k.label, k.besaran, coalesce(v_ubah.besaran, k.besaran),
            case when v_ubah.kategori is null then 'skema' else 'manual' end, v_ubah.alasan, k.urutan, v_ubah.oleh, v_ubah.pada);
  end loop;

  -- Honor per jam (honorer)
  if e.status_kepegawaian = 'honorer' then
    if e.kategori_honorer is null then v_cat := array_append(v_cat, 'Kategori honorer belum diisi; honor per jam tidak dihitung.');
    else
      for h in select * from public._jam_honor(l.employee_id, pr.tanggal_mulai, pr.tanggal_akhir) j
               where (j.kode = 'guru' and exists (select 1 from employee_functions ef join functional_positions fp on fp.id = ef.functional_position_id where ef.employee_id = e.id and fp.kode = 'GURU'))
                  or (j.kode = 'muhaffizh' and exists (select 1 from employee_functions ef join functional_positions fp on fp.id = ef.functional_position_id where ef.employee_id = e.id and fp.kode = 'MUHAFFIZH')) loop
        select * into v_tarif from public.tarif_berlaku(pr.tanggal_akhir) t where t.kategori = 'honorer_jam' and t.kunci = h.kode || '_' || e.kategori_honorer;
        if not found then v_cat := array_append(v_cat, ('Tarif honor ' || h.kode || ' ' || e.kategori_honorer || ' belum diatur.')); continue; end if;
        select * into v_ubah from jsonb_to_recordset(v_ubahan) u(kategori text, kode text, besaran numeric, jumlah numeric, alasan text, oleh uuid, pada timestamptz)
          where u.kategori = 'honor' and u.kode = h.kode;
        v_jam := coalesce(v_ubah.jumlah, h.jam);
        v_besar := round(v_jam * v_tarif.besaran);
        insert into payroll_items (line_id, jenis, kategori, kode, label, jumlah, tarif, besaran_skema, besaran, sumber, alasan, rincian, urutan, diubah_oleh, diubah_pada)
        values (p_line, 'pendapatan', 'honor', h.kode, case h.kode when 'guru' then 'Honor mengajar' else 'Honor halaqah' end, v_jam, v_tarif.besaran,
                round(h.jam * v_tarif.besaran), coalesce(v_ubah.besaran, v_besar), case when v_ubah.kategori is null then 'skema' else 'manual' end,
                v_ubah.alasan, h.rincian || jsonb_build_object('jam_otomatis', h.jam), 50, v_ubah.oleh, v_ubah.pada);
      end loop;
    end if;
  end if;

  -- Penyesuaian: target diterima (isi/impor) didahulukan, lalu penetapan yayasan yang berlaku
  select coalesce(sum(case when jenis = 'pendapatan' then besaran else -besaran end), 0) into v_dasar from payroll_items where line_id = p_line;
  if l.target_diterima is not null then
    if l.target_diterima - v_dasar <> 0 then
      insert into payroll_items (line_id, jenis, kategori, label, besaran, sumber, alasan, rincian, urutan)
      values (p_line, 'pendapatan', 'penyesuaian', v_label, l.target_diterima - v_dasar, 'manual', l.alasan_target,
              jsonb_build_object('dasar', 'Jumlah diterima ditetapkan', 'target_diterima', l.target_diterima), 95);
    end if;
  else
    select * into d from salary_decisions s where s.employee_id = l.employee_id and s.berlaku_mulai <= pr.tanggal_akhir
       and (s.berlaku_sampai is null or s.berlaku_sampai >= pr.tanggal_mulai) order by s.berlaku_mulai desc, s.created_at desc limit 1;
    if found then
      v_besar := case d.mode when 'selisih' then d.nilai
                 else d.nilai - coalesce((select sum(besaran) from payroll_items where line_id = p_line and jenis = 'pendapatan'), 0) end;
      if v_besar <> 0 then
        insert into payroll_items (line_id, jenis, kategori, label, besaran, sumber, alasan, rincian, urutan)
        values (p_line, 'pendapatan', 'penyesuaian', v_label, v_besar, 'penetapan', d.keterangan,
                jsonb_build_object('penetapan_id', d.id, 'mode', d.mode, 'nilai', d.nilai, 'dasar', d.dasar), 95);
      end if;
    end if;
  end if;

  v_data := public._data_gaji(l.employee_id, pr.tanggal_akhir);
  v_data := jsonb_set(v_data, '{catatan}', (v_data->'catatan') || to_jsonb(v_cat));
  update payroll_lines set data = v_data where id = p_line;
  perform public._jumlahkan_baris(p_line);
end $$;

-- ---------------------------------------------------------------------
-- 3. PERIODE
-- ---------------------------------------------------------------------
create or replace function public.buat_periode_gaji(p_tahun int, p_bulan int, p_tanggal_bayar date default null)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid; v_mulai date; v_akhir date; v_tgl int; e record; v_line uuid;
begin
  perform public._wajib_kelola_gaji();
  if p_bulan not between 1 and 12 then raise exception 'Bulan tidak sah.'; end if;
  if exists (select 1 from payroll_periods where tahun = p_tahun and bulan = p_bulan) then
    raise exception 'Periode gaji % sudah ada.', to_char(make_date(p_tahun, p_bulan, 1), 'MM/YYYY'); end if;
  v_mulai := make_date(p_tahun, p_bulan, 1); v_akhir := (v_mulai + interval '1 month - 1 day')::date;
  v_tgl := coalesce((public._pengaturan_gaji()->>'tanggal_gajian')::int, 1);
  insert into payroll_periods (tahun, bulan, tanggal_mulai, tanggal_akhir, tanggal_bayar, dibuat_oleh, dihitung_pada)
  values (p_tahun, p_bulan, v_mulai, v_akhir, coalesce(p_tanggal_bayar, (v_akhir + v_tgl)::date), public.saya(), now())
  returning id into v_id;
  for e in select id from employees where status_keaktifan = 'aktif' and peran <> 'superadmin' and (tmt_tugas is null or tmt_tugas <= v_akhir) loop
    insert into payroll_lines (period_id, employee_id, updated_by) values (v_id, e.id, public.saya()) returning id into v_line;
    perform public._hitung_baris(v_line);
  end loop;
  return v_id;
end $$;

/** Hitung ulang seluruh baris periode draf; pegawai aktif yang belum ada ditambahkan. */
create or replace function public.hitung_ulang_periode_gaji(p_period uuid)
returns int language plpgsql volatile security definer set search_path = public as $$
declare pr payroll_periods; r record; n int := 0; v_line uuid;
begin
  perform public._wajib_kelola_gaji(); pr := public._wajib_periode_draf(p_period);
  for r in select e.id from employees e where e.status_keaktifan = 'aktif' and e.peran <> 'superadmin' and (e.tmt_tugas is null or e.tmt_tugas <= pr.tanggal_akhir)
             and not exists (select 1 from payroll_lines l where l.period_id = p_period and l.employee_id = e.id) loop
    insert into payroll_lines (period_id, employee_id, updated_by) values (p_period, r.id, public.saya()) returning id into v_line;
  end loop;
  for r in select id from payroll_lines where period_id = p_period loop perform public._hitung_baris(r.id); n := n + 1; end loop;
  update payroll_periods set dihitung_pada = now(), updated_at = now() where id = p_period;
  return n;
end $$;

create or replace function public.ubah_periode_gaji(p_period uuid, p jsonb)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  perform public._wajib_kelola_gaji(); perform public._wajib_periode_draf(p_period);
  update payroll_periods set tanggal_bayar = coalesce(nullif(p->>'tanggal_bayar', '')::date, tanggal_bayar),
    catatan = case when p ? 'catatan' then nullif(trim(p->>'catatan'), '') else catatan end, updated_at = now() where id = p_period;
end $$;

create or replace function public.hapus_periode_gaji(p_period uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  perform public._wajib_kelola_gaji(); perform public._wajib_periode_draf(p_period);
  delete from payroll_periods where id = p_period;
end $$;

create or replace function public.tambah_baris_gaji(p_period uuid, p_emp uuid)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v uuid;
begin
  perform public._wajib_kelola_gaji(); perform public._wajib_periode_draf(p_period);
  if not exists (select 1 from employees where id = p_emp and peran <> 'superadmin') then raise exception 'Pegawai tidak ditemukan.'; end if;
  insert into payroll_lines (period_id, employee_id, updated_by) values (p_period, p_emp, public.saya())
  on conflict (period_id, employee_id) do nothing returning id into v;
  if v is null then raise exception 'Pegawai ini sudah ada di periode gaji.'; end if;
  perform public._hitung_baris(v);
  return v;
end $$;

create or replace function public.hapus_baris_gaji(p_line uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v_period uuid;
begin
  perform public._wajib_kelola_gaji();
  select period_id into v_period from payroll_lines where id = p_line;
  perform public._wajib_periode_draf(v_period);
  delete from payroll_lines where id = p_line;
end $$;

create or replace function public.hitung_ulang_baris_gaji(p_line uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  perform public._wajib_kelola_gaji();
  perform public._wajib_periode_draf((select period_id from payroll_lines where id = p_line));
  perform public._hitung_baris(p_line);
end $$;

-- ---------------------------------------------------------------------
-- 4. UBAH NOMINAL (Bendahara, wajib beralasan)
-- ---------------------------------------------------------------------
/** Ubah nominal komponen (atau jam honor). Nominal tetap dipertahankan saat hitung ulang. */
create or replace function public.ubah_item_gaji(p_item uuid, p_besaran numeric, p_jumlah numeric, p_alasan text)
returns void language plpgsql volatile security definer set search_path = public as $$
declare i payroll_items; v_line payroll_lines;
begin
  perform public._wajib_kelola_gaji();
  select * into i from payroll_items where id = p_item;
  if not found then raise exception 'Komponen gaji tidak ditemukan.'; end if;
  select * into v_line from payroll_lines where id = i.line_id;
  perform public._wajib_periode_draf(v_line.period_id);
  if i.kategori = 'penyesuaian' then raise exception 'Penyesuaian dihitung otomatis. Ubah lewat "Atur jumlah diterima" atau penetapan yayasan.'; end if;
  if length(trim(coalesce(p_alasan, ''))) < 3 then raise exception 'Alasan perubahan wajib diisi.'; end if;
  if p_besaran is not null and p_besaran < 0 then raise exception 'Nominal tidak boleh negatif.'; end if;
  if i.kategori = 'honor' and p_jumlah is not null then
    if p_jumlah < 0 then raise exception 'Jumlah jam tidak boleh negatif.'; end if;
    update payroll_items set jumlah = p_jumlah, besaran = coalesce(p_besaran, round(p_jumlah * tarif)) where id = p_item;
  else
    if p_besaran is null then raise exception 'Isi nominal.'; end if;
    update payroll_items set besaran = p_besaran where id = p_item;
  end if;
  update payroll_items set sumber = case when sumber in ('skema','manual') and besaran_skema is not null then 'manual' else sumber end,
    alasan = trim(p_alasan), diubah_oleh = public.saya(), diubah_pada = now() where id = p_item;
  perform public._hitung_baris(i.line_id);   -- penyesuaian dari target/penetapan ikut menyesuaikan
end $$;

/** Kembalikan komponen yang diubah ke nilai skema. */
create or replace function public.kembalikan_item_gaji(p_item uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare i payroll_items;
begin
  perform public._wajib_kelola_gaji();
  select * into i from payroll_items where id = p_item;
  if not found then raise exception 'Komponen gaji tidak ditemukan.'; end if;
  perform public._wajib_periode_draf((select period_id from payroll_lines where id = i.line_id));
  if i.besaran_skema is null then raise exception 'Komponen tambahan tidak memiliki nilai skema; hapus bila tidak dipakai.'; end if;
  update payroll_items set sumber = 'skema', besaran = besaran_skema, jumlah = coalesce((rincian->>'jam_otomatis')::numeric, jumlah),
    alasan = null, diubah_oleh = null, diubah_pada = null where id = p_item;
  perform public._hitung_baris(i.line_id);
end $$;

/** Tambah pendapatan lain (mis. THR, insentif kegiatan) atau potongan lain dengan alasan. */
create or replace function public.tambah_item_gaji(p_line uuid, p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v uuid; v_jenis text := coalesce(p->>'jenis', 'pendapatan'); v_besar numeric := round(coalesce((p->>'besaran')::numeric, 0));
begin
  perform public._wajib_kelola_gaji();
  perform public._wajib_periode_draf((select period_id from payroll_lines where id = p_line));
  if v_jenis not in ('pendapatan','potongan') then raise exception 'Jenis hanya pendapatan atau potongan.'; end if;
  if length(trim(coalesce(p->>'label', ''))) < 3 then raise exception 'Isi nama komponen.'; end if;
  if v_besar <= 0 then raise exception 'Nominal harus lebih dari nol.'; end if;
  insert into payroll_items (line_id, jenis, kategori, label, besaran, sumber, alasan, urutan, diubah_oleh, diubah_pada)
  values (p_line, v_jenis, case v_jenis when 'pendapatan' then 'tambahan' else 'potongan_lain' end, trim(p->>'label'), v_besar, 'manual',
          nullif(trim(p->>'alasan'), ''), case v_jenis when 'pendapatan' then 96 else 199 end, public.saya(), now())
  returning id into v;
  perform public._hitung_baris(p_line);
  return v;
end $$;

create or replace function public.hapus_item_gaji(p_item uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare i payroll_items;
begin
  perform public._wajib_kelola_gaji();
  select * into i from payroll_items where id = p_item;
  if not found then raise exception 'Komponen gaji tidak ditemukan.'; end if;
  perform public._wajib_periode_draf((select period_id from payroll_lines where id = i.line_id));
  if i.kategori not in ('tambahan','potongan_lain') then raise exception 'Komponen skema tidak dihapus; ubah nominalnya menjadi Rp0 bila tidak diberikan.'; end if;
  delete from payroll_items where id = p_item;
  perform public._hitung_baris(i.line_id);
end $$;

/** Tetapkan jumlah diterima (take home) seorang pegawai pada periode ini; null = hapus penetapan langsung. */
create or replace function public.atur_diterima_gaji(p_line uuid, p_diterima numeric, p_alasan text)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  perform public._wajib_kelola_gaji();
  perform public._wajib_periode_draf((select period_id from payroll_lines where id = p_line));
  if p_diterima is not null and p_diterima < 0 then raise exception 'Jumlah diterima tidak boleh negatif.'; end if;
  if p_diterima is not null and length(trim(coalesce(p_alasan, ''))) < 3 then raise exception 'Isi keterangan, mis. "Ketetapan Ketua Yayasan".'; end if;
  update payroll_lines set target_diterima = round(p_diterima), alasan_target = case when p_diterima is null then null else trim(p_alasan) end,
    updated_by = public.saya(), updated_at = now() where id = p_line;
  perform public._hitung_baris(p_line);
end $$;

/** Impor jumlah diterima dari Excel: [{niy, diterima, keterangan}]. Pegawai yang belum ada di periode ditambahkan. */
create or replace function public.impor_diterima_gaji(p_period uuid, p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare r jsonb; i int := 0; n int := 0; v_emp uuid; v_line uuid; v_gagal jsonb := '[]'::jsonb; v_nilai numeric;
begin
  perform public._wajib_kelola_gaji(); perform public._wajib_periode_draf(p_period);
  for r in select x from jsonb_array_elements(p) x loop
    i := i + 1;
    begin
      select id into v_emp from employees where niy = trim(r->>'niy') and peran <> 'superadmin';
      if v_emp is null then raise exception 'NIY % tidak ditemukan.', coalesce(r->>'niy', '(kosong)'); end if;
      v_nilai := round(nullif(regexp_replace(coalesce(r->>'diterima', ''), '[^0-9-]', '', 'g'), '')::numeric);
      if v_nilai is null or v_nilai < 0 then raise exception 'Jumlah diterima tidak sah.'; end if;
      select id into v_line from payroll_lines where period_id = p_period and employee_id = v_emp;
      if v_line is null then insert into payroll_lines (period_id, employee_id, updated_by) values (p_period, v_emp, public.saya()) returning id into v_line; end if;
      update payroll_lines set target_diterima = v_nilai,
        alasan_target = coalesce(nullif(trim(r->>'keterangan'), ''), 'Impor data gaji diterima'), updated_by = public.saya(), updated_at = now() where id = v_line;
      perform public._hitung_baris(v_line);
      n := n + 1;
    exception when others then v_gagal := v_gagal || jsonb_build_object('baris', i, 'pesan', sqlerrm);
    end;
  end loop;
  return jsonb_build_object('disimpan', n, 'gagal', v_gagal);
end $$;

-- ---------------------------------------------------------------------
-- 5. PENETAPAN YAYASAN
-- ---------------------------------------------------------------------
create or replace function public.simpan_penetapan_gaji(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v uuid := nullif(p->>'id', '')::uuid; v_mode text := p->>'mode'; v_nilai numeric := round((p->>'nilai')::numeric);
begin
  perform public._wajib_kelola_gaji();
  if v_mode not in ('total','selisih') then raise exception 'Pilih bentuk penetapan: jumlah tetap atau selisih dari skema.'; end if;
  if v_nilai is null then raise exception 'Isi nominal penetapan.'; end if;
  if v_mode = 'total' and v_nilai < 0 then raise exception 'Jumlah tetap tidak boleh negatif.'; end if;
  if v_mode = 'selisih' and v_nilai = 0 then raise exception 'Selisih tidak boleh nol.'; end if;
  if length(trim(coalesce(p->>'keterangan', ''))) < 3 then raise exception 'Isi keterangan penetapan, mis. "Ketetapan Ketua Yayasan".'; end if;
  if nullif(p->>'berlaku_mulai', '') is null then raise exception 'Isi tanggal mulai berlaku.'; end if;
  if v is null then
    insert into salary_decisions (employee_id, mode, nilai, keterangan, dasar, berlaku_mulai, berlaku_sampai, dibuat_oleh)
    values ((p->>'employee_id')::uuid, v_mode, v_nilai, trim(p->>'keterangan'), nullif(trim(p->>'dasar'), ''),
            (p->>'berlaku_mulai')::date, nullif(p->>'berlaku_sampai', '')::date, public.saya()) returning id into v;
  else
    update salary_decisions set mode = v_mode, nilai = v_nilai, keterangan = trim(p->>'keterangan'), dasar = nullif(trim(p->>'dasar'), ''),
      berlaku_mulai = (p->>'berlaku_mulai')::date, berlaku_sampai = nullif(p->>'berlaku_sampai', '')::date, updated_at = now() where id = v;
    if not found then raise exception 'Penetapan tidak ditemukan.'; end if;
  end if;
  return v;
end $$;

create or replace function public.hapus_penetapan_gaji(p_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  perform public._wajib_kelola_gaji();
  delete from salary_decisions where id = p_id;
end $$;

create or replace function public.daftar_penetapan_gaji()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public.boleh_lihat_gaji() then raise exception 'Anda tidak berwenang melihat data gaji.' using errcode = '42501'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'employee_id', d.employee_id, 'niy', e.niy, 'nama', e.nama_lengkap,
      'mode', d.mode, 'nilai', d.nilai, 'keterangan', d.keterangan, 'dasar', d.dasar, 'berlaku_mulai', d.berlaku_mulai, 'berlaku_sampai', d.berlaku_sampai,
      'aktif', d.berlaku_mulai <= public.hari_ini() and (d.berlaku_sampai is null or d.berlaku_sampai >= public.hari_ini()),
      'dibuat_oleh', (select nama_lengkap from employees where id = d.dibuat_oleh), 'created_at', d.created_at)
      order by e.nama_lengkap, d.berlaku_mulai desc)
    from salary_decisions d join employees e on e.id = d.employee_id), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- 6. BACA
-- ---------------------------------------------------------------------
create or replace function public.daftar_periode_gaji()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public.boleh_lihat_gaji() then raise exception 'Anda tidak berwenang melihat data gaji.' using errcode = '42501'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'tahun', p.tahun, 'bulan', p.bulan, 'status', p.status,
      'tanggal_mulai', p.tanggal_mulai, 'tanggal_akhir', p.tanggal_akhir, 'tanggal_bayar', p.tanggal_bayar, 'catatan', p.catatan,
      'dihitung_pada', p.dihitung_pada, 'pegawai', s.n, 'total_skema', s.skema, 'total_penyesuaian', s.sesuai,
      'total_pendapatan', s.pend, 'total_potongan', s.pot, 'total_diterima', s.terima, 'data_kurang', s.kurang)
      order by p.tahun desc, p.bulan desc)
    from payroll_periods p
    cross join lateral (select count(*) n, coalesce(sum(total_skema), 0) skema, coalesce(sum(total_penyesuaian), 0) sesuai,
        coalesce(sum(total_pendapatan), 0) pend, coalesce(sum(total_potongan), 0) pot, coalesce(sum(diterima), 0) terima,
        count(*) filter (where jsonb_array_length(coalesce(data->'catatan', '[]')) > 0) kurang
      from payroll_lines where period_id = p.id) s), '[]'::jsonb);
end $$;

create or replace function public.rincian_periode_gaji(p_period uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public.boleh_lihat_gaji() then raise exception 'Anda tidak berwenang melihat data gaji.' using errcode = '42501'; end if;
  return (select jsonb_build_object('periode', to_jsonb(p) - 'dibuat_oleh', 'baris', coalesce((
      select jsonb_agg(jsonb_build_object('id', l.id, 'employee_id', l.employee_id, 'data', l.data, 'target_diterima', l.target_diterima,
          'alasan_target', l.alasan_target, 'total_skema', l.total_skema, 'total_penyesuaian', l.total_penyesuaian,
          'total_pendapatan', l.total_pendapatan, 'total_potongan', l.total_potongan, 'diterima', l.diterima, 'catatan', l.catatan,
          'item', coalesce((select jsonb_agg(jsonb_build_object('id', i.id, 'jenis', i.jenis, 'kategori', i.kategori, 'kode', i.kode, 'label', i.label,
              'jumlah', i.jumlah, 'tarif', i.tarif, 'besaran_skema', i.besaran_skema, 'besaran', i.besaran, 'sumber', i.sumber, 'alasan', i.alasan,
              'rincian', i.rincian, 'diubah_oleh', (select nama_lengkap from employees where id = i.diubah_oleh), 'diubah_pada', i.diubah_pada)
              order by i.jenis desc, i.urutan, i.label) from payroll_items i where i.line_id = l.id), '[]'::jsonb))
        order by l.data->>'nama')
      from payroll_lines l where l.period_id = p.id), '[]'::jsonb))
    from payroll_periods p where p.id = p_period);
end $$;

-- ---------------------------------------------------------------------
-- 7. HAK EKSEKUSI
-- ---------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array['simpan_pengaturan_gaji(jsonb)','buat_periode_gaji(int,int,date)','hitung_ulang_periode_gaji(uuid)',
    'ubah_periode_gaji(uuid,jsonb)','hapus_periode_gaji(uuid)','tambah_baris_gaji(uuid,uuid)','hapus_baris_gaji(uuid)','hitung_ulang_baris_gaji(uuid)',
    'ubah_item_gaji(uuid,numeric,numeric,text)','kembalikan_item_gaji(uuid)','tambah_item_gaji(uuid,jsonb)','hapus_item_gaji(uuid)',
    'atur_diterima_gaji(uuid,numeric,text)','impor_diterima_gaji(uuid,jsonb)','simpan_penetapan_gaji(jsonb)','hapus_penetapan_gaji(uuid)',
    'daftar_penetapan_gaji()','daftar_periode_gaji()','rincian_periode_gaji(uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['_pengaturan_gaji()','_wajib_kelola_gaji()','_wajib_periode_draf(uuid)','_data_gaji(uuid,date)','_komponen_skema(uuid,date)',
    '_jam_honor(uuid,date,date)','_jumlahkan_baris(uuid)','_hitung_baris(uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN (hasil yang benar: baris 1–6 "Sesuai"; baris 7 keterangan data)
-- ---------------------------------------------------------------------
select '1. Tabel periode, baris, komponen, penetapan' as pemeriksaan,
       case when to_regclass('public.payroll_periods') is not null and to_regclass('public.payroll_lines') is not null
             and to_regclass('public.payroll_items') is not null and to_regclass('public.salary_decisions') is not null then 'Sesuai' else 'Periksa' end as hasil
union all select '2. Tabel gaji tertutup untuk tulis langsung', case when (select count(*) from pg_policies where tablename in
  ('payroll_periods','payroll_lines','payroll_items','salary_decisions') and cmd <> 'SELECT') = 0
  and (select bool_and(relrowsecurity) from pg_class where relname in ('payroll_periods','payroll_lines','payroll_items','salary_decisions')) then 'Sesuai' else 'Periksa' end
union all select '3. Fungsi periode dan perhitungan (8)', case when (select count(*) from pg_proc where proname in ('buat_periode_gaji','hitung_ulang_periode_gaji',
  '_hitung_baris','_komponen_skema','_jam_honor','rincian_periode_gaji','daftar_periode_gaji','hapus_periode_gaji')) = 8 then 'Sesuai' else 'Periksa' end
union all select '4. Fungsi ubah nominal dan jumlah diterima (6)', case when (select count(*) from pg_proc where proname in ('ubah_item_gaji','kembalikan_item_gaji',
  'tambah_item_gaji','hapus_item_gaji','atur_diterima_gaji','impor_diterima_gaji')) = 6 then 'Sesuai' else 'Periksa' end
union all select '5. Fungsi penetapan yayasan (3)', case when (select count(*) from pg_proc where proname in ('simpan_penetapan_gaji','hapus_penetapan_gaji','daftar_penetapan_gaji')) = 3 then 'Sesuai' else 'Periksa' end
union all select '6. Label penyesuaian di ketentuan', case when public._pengaturan_gaji() ? 'label_penyesuaian' then 'Sesuai' else 'Periksa' end
union all select '7. Pegawai aktif yang akan masuk periode gaji', (select count(*) || ' pegawai' from employees where status_keaktifan = 'aktif' and peran <> 'superadmin');
