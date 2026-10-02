-- =====================================================================
-- SIMKA PRO · Fase 1 · Migrasi 2: Fungsi bantu, pemicu, hak akses, penomoran
-- =====================================================================

-- ---------------------------------------------------------------------
-- A. IDENTITAS PENGGUNA SAAT INI
-- ---------------------------------------------------------------------
create or replace function public.saya()
returns uuid language sql stable security definer set search_path = public as $$
  select id from employees where user_id = auth.uid() and status_akun = 'aktif'
$$;

create or replace function public.is_superadmin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from employees
                 where user_id = auth.uid() and status_akun = 'aktif' and peran = 'superadmin')
$$;

create or replace function public.is_admin()   -- admin ATAU superadmin
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from employees
                 where user_id = auth.uid() and status_akun = 'aktif' and peran in ('admin','superadmin'))
$$;

-- Izin admin yang dicentang superadmin (superadmin selalu boleh)
create or replace function public.admin_boleh(p_kode text)
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_superadmin() or exists (
    select 1 from employees e join admin_permissions ap on ap.employee_id = e.id
    where e.user_id = auth.uid() and e.status_akun = 'aktif' and e.peran = 'admin' and ap.kode = p_kode)
$$;

-- Unit beserta seluruh turunannya
create or replace function public.unit_turunan(p_unit uuid)
returns setof uuid language sql stable security definer set search_path = public as $$
  with recursive t(id) as (
    select p_unit
    union all
    select u.id from org_units u join t on u.parent_id = t.id
  ) select id from t
$$;

-- Unit yang menjadi cakupan pimpinan (P2) saat ini.
-- Jabatan dengan tingkat <= 20 (yayasan, direktur, wakil direktur) mencakup seluruh pondok.
create or replace function public.unit_pimpinan_saya()
returns setof uuid language sql stable security definer set search_path = public as $$
  select u.id from org_units u
  where exists (
    select 1 from employees e
    join employee_structurals es on es.employee_id = e.id
    join structural_positions sp on sp.id = es.structural_position_id
    where e.user_id = auth.uid() and e.status_akun = 'aktif'
      and (sp.tingkat <= 20 or u.id in (select public.unit_turunan(es.org_unit_id)))
  )
$$;

create or replace function public.pimpinan_dari(p_employee uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from employees t
                 where t.id = p_employee
                   and t.org_unit_id in (select public.unit_pimpinan_saya()))
$$;

-- ---------------------------------------------------------------------
-- B. FORMAT TANGGAL INDONESIA DAN MASA KERJA
-- ---------------------------------------------------------------------
create or replace function public.nama_bulan(p_bulan int)
returns text language sql immutable as $$
  select (array['Januari','Februari','Maret','April','Mei','Juni','Juli',
                'Agustus','September','Oktober','November','Desember'])[p_bulan]
$$;

create or replace function public.tanggal_indo(p date)          -- 01 Januari 1980
returns text language sql immutable as $$
  select case when p is null then null else
    to_char(p,'DD') || ' ' || public.nama_bulan(extract(month from p)::int) || ' ' || to_char(p,'YYYY') end
$$;

create or replace function public.hari_ini()                     -- tanggal WITA
returns date language sql stable as $$
  select (now() at time zone 'Asia/Makassar')::date
$$;

create or replace function public.waktu_server()
returns jsonb language sql stable as $$
  select jsonb_build_object(
    'iso', now(),
    'tanggal', public.hari_ini(),
    'jam', to_char(now() at time zone 'Asia/Makassar','HH24:MI:SS'),
    'zona', 'WITA')
$$;

create or replace function public.masa_kerja(p_tmt date)
returns jsonb language sql stable as $$
  select case when p_tmt is null then null else
    jsonb_build_object(
      'tahun', extract(year from age(public.hari_ini(), p_tmt))::int,
      'bulan', extract(month from age(public.hari_ini(), p_tmt))::int,
      'teks',  extract(year from age(public.hari_ini(), p_tmt))::int || ' tahun ' ||
               extract(month from age(public.hari_ini(), p_tmt))::int || ' bulan') end
$$;

-- ---------------------------------------------------------------------
-- C. KALENDER HIJRIAH (tabular, dengan koreksi hari dari pengaturan)
-- ---------------------------------------------------------------------
create or replace function public._hijri_ke_jd(y int, m int, d int)
returns numeric language sql immutable as $$
  select d + ceil(29.5 * (m - 1)) + (y - 1) * 354 + floor((3 + 11 * y) / 30.0) + 1948439.5 - 1
$$;

create or replace function public.hijriah(p date)
returns table (tahun int, bulan int, hari int, bulan_romawi text, nama_bulan text, teks text)
language plpgsql stable security definer set search_path = public as $$
declare
  v_koreksi int := 0; jd numeric; y int; m int; d int;
  romawi text[] := array['I','II','III','IV','V','VI','VII','VIII','IX','X','XI','XII'];
  nama   text[] := array['Muharram','Shafar','Rabiul Awal','Rabiul Akhir','Jumadil Awal','Jumadil Akhir',
                         'Rajab','Syakban','Ramadan','Syawal','Zulkaidah','Zulhijah'];
begin
  select coalesce((nilai->>'koreksi_hari')::int, 0) into v_koreksi
    from institution_settings where kunci = 'hijriah';
  jd := to_char(p + coalesce(v_koreksi, 0), 'J')::numeric - 0.5;
  y  := floor((30 * (jd - 1948439.5) + 10646) / 10631);
  m  := least(12, ceil((jd - (29 + public._hijri_ke_jd(y, 1, 1))) / 29.5) + 1);
  d  := (jd - public._hijri_ke_jd(y, m, 1) + 1)::int;
  return query select y, m, d, romawi[m], nama[m], d || ' ' || nama[m] || ' ' || y || ' H';
end $$;

-- ---------------------------------------------------------------------
-- D. MESIN PENOMORAN DOKUMEN (atomik, tidak ganda)
-- Token pola: {DK} {URUT} {URUT3} {PERIHAL} {UNIT} {BLN_H_ROMAWI} {THN_H}
--             {BLN_ROMAWI} {BLN} {THN}
-- ---------------------------------------------------------------------
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
  if auth.uid() is not null and not public.is_admin() then
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

-- Pratinjau tanpa menaikkan urutan (untuk menu Pengaturan)
create or replace function public.pratinjau_nomor(
  p_format text, p_tanggal date default null, p_dk text default 'D',
  p_perihal text default 'NZ', p_kop text default 'pondok')
returns text language plpgsql stable security definer set search_path = public as $$
declare f doc_number_formats; h record; v_tgl date := coalesce(p_tanggal, public.hari_ini());
  v_periode text; v_urut int; v_unit text; v text;
  romawi text[] := array['I','II','III','IV','V','VI','VII','VIII','IX','X','XI','XII'];
begin
  select * into f from doc_number_formats where kode = p_format;
  if not found then return null; end if;
  select * into h from public.hijriah(v_tgl);
  v_periode := case f.reset when 'tahun_hijriah' then h.tahun::text when 'tahun_masehi' then to_char(v_tgl,'YYYY')
                 when 'bulan_masehi' then to_char(v_tgl,'YYYY-MM') else '-' end;
  select coalesce(nilai,0) + 1 into v_urut from doc_counters where grup_urut = f.grup_urut and periode = v_periode;
  v_urut := coalesce(v_urut, 1);
  select kode_unit into v_unit from letterheads where kode = p_kop;
  v := replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(f.pola,
        '{DK}', p_dk), '{URUT3}', lpad(v_urut::text,3,'0')), '{URUT}', v_urut::text),
        '{PERIHAL}', coalesce(p_perihal,'')), '{UNIT}', coalesce(v_unit,'')),
        '{BLN_H_ROMAWI}', h.bulan_romawi), '{THN_H}', h.tahun::text),
        '{BLN_ROMAWI}', romawi[extract(month from v_tgl)::int]), '{BLN}', to_char(v_tgl,'MM')),
        '{THN}', to_char(v_tgl,'YYYY'));
  return v;
end $$;

-- ---------------------------------------------------------------------
-- E. HAK AKSES FITUR EFEKTIF (jabatan → bidang → individu)
-- ---------------------------------------------------------------------
create or replace function public.rincian_akses(p_employee uuid)
returns table (kode text, nama text, kelompok text, dari_jabatan smallint,
               dari_bidang smallint, dari_individu smallint, efektif smallint)
language plpgsql stable security definer set search_path = public as $$
declare v_peran text; v_unit uuid;
begin
  -- hanya superadmin, admin, atau pemilik akun yang boleh melihat
  if auth.uid() is not null and not public.is_admin() and p_employee is distinct from public.saya() then
    raise exception 'Tidak berwenang melihat hak akses pegawai lain.' using errcode = '42501';
  end if;
  select peran, org_unit_id into v_peran, v_unit from employees where id = p_employee;

  return query
  with jab as (
    select g.feature_kode, max(g.tingkat)::smallint t from feature_grants g
    where g.mode = 'tambah' and (
      (g.sasaran = 'fungsional' and g.sasaran_id in
         (select functional_position_id from employee_functions where employee_id = p_employee)) or
      (g.sasaran = 'struktural' and g.sasaran_id in
         (select structural_position_id from employee_structurals where employee_id = p_employee)))
    group by g.feature_kode
  ),
  leluhur as (   -- unit pegawai dan semua induknya
    with recursive a(id, parent_id) as (
      select id, parent_id from org_units where id = v_unit
      union all select u.id, u.parent_id from org_units u join a on u.id = a.parent_id
    ) select id from a
  ),
  bid as (
    select g.feature_kode,
           max(g.tingkat) filter (where g.mode = 'tambah')::smallint tambah,
           min(g.tingkat) filter (where g.mode = 'cabut')::smallint cabut
    from feature_grants g where g.sasaran = 'bidang' and g.sasaran_id in (select id from leluhur)
    group by g.feature_kode
  ),
  ind as (
    select g.feature_kode,
           max(g.tingkat) filter (where g.mode = 'tambah')::smallint tambah,
           min(g.tingkat) filter (where g.mode = 'cabut')::smallint cabut
    from feature_grants g where g.sasaran = 'individu' and g.sasaran_id = p_employee
    group by g.feature_kode
  ),
  hitung as (
    select f.kode, f.nama, f.kelompok, f.urutan,
           coalesce(jab.t, 0)::smallint l1,
           bid.tambah b_t, bid.cabut b_c, ind.tambah i_t, ind.cabut i_c
    from features f
    left join jab on jab.feature_kode = f.kode
    left join bid on bid.feature_kode = f.kode
    left join ind on ind.feature_kode = f.kode
  )
  select h.kode, h.nama, h.kelompok, h.l1,
         case when h.b_c is not null then (-h.b_c)::smallint else h.b_t end,
         case when h.i_c is not null then (-h.i_c)::smallint else h.i_t end,
         case when v_peran = 'superadmin' then 3::smallint else
           (select least(greatest(
              least(greatest(h.l1, coalesce(h.b_t,0)), coalesce(h.b_c - 1, 3)),
              coalesce(h.i_t,0)), coalesce(h.i_c - 1, 3)))::smallint end
  from hitung h order by h.kelompok, h.urutan;
end $$;
comment on function public.rincian_akses is
  'Nilai dari_bidang/dari_individu negatif berarti pencabutan pada tingkat tersebut. Efektif: 0 tanpa akses, 1 lihat, 2 input/ubah, 3 kelola.';

create or replace function public.fitur_saya()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_object_agg(kode, efektif) filter (where efektif > 0), '{}'::jsonb)
  from public.rincian_akses(public.saya())
$$;

create or replace function public.tingkat_fitur(p_kode text)
returns smallint language sql stable security definer set search_path = public as $$
  select coalesce((select efektif from public.rincian_akses(public.saya()) where kode = p_kode), 0)::smallint
$$;

-- ---------------------------------------------------------------------
-- F. NOTIFIKASI
-- ---------------------------------------------------------------------
create or replace function public.kirim_notifikasi(
  p_employee uuid, p_judul text, p_isi text default null, p_tautan text default null,
  p_ikon text default 'Bell', p_warna text default 'merah')
returns uuid language sql volatile security definer set search_path = public as $$
  insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
  values (p_employee, p_judul, p_isi, p_tautan, p_ikon, p_warna) returning id
$$;
revoke execute on function public.kirim_notifikasi(uuid,text,text,text,text,text) from public, anon, authenticated;
do $$ begin if exists (select 1 from pg_roles where rolname = 'service_role') then
  grant execute on function public.kirim_notifikasi(uuid,text,text,text,text,text) to service_role; end if; end $$;

create or replace function public.notifikasi_admin(
  p_izin text, p_judul text, p_isi text, p_tautan text, p_ikon text default 'Bell', p_warna text default 'biru')
returns int language plpgsql volatile security definer set search_path = public as $$
declare n int;
begin
  insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
  select e.id, p_judul, p_isi, p_tautan, p_ikon, p_warna from employees e
  where e.status_akun = 'aktif' and (e.peran = 'superadmin' or
        (e.peran = 'admin' and exists (select 1 from admin_permissions ap
                                       where ap.employee_id = e.id and ap.kode = p_izin)));
  get diagnostics n = row_count; return n;
end $$;
revoke execute on function public.notifikasi_admin(text,text,text,text,text,text) from public, anon, authenticated;
do $$ begin if exists (select 1 from pg_roles where rolname = 'service_role') then
  grant execute on function public.notifikasi_admin(text,text,text,text,text,text) to service_role; end if; end $$;

create or replace function public.tandai_dibaca(p_id uuid default null)
returns int language plpgsql volatile security definer set search_path = public as $$
declare n int;
begin
  update notifications set dibaca_pada = now()
  where employee_id = public.saya() and dibaca_pada is null and (p_id is null or id = p_id);
  get diagnostics n = row_count; return n;
end $$;

-- ---------------------------------------------------------------------
-- G. AUDIT LOG
-- ---------------------------------------------------------------------
create or replace function public.catat_audit(p_aksi text, p_tabel text, p_id text, p_ringkasan text, p_data jsonb default null)
returns void language sql volatile security definer set search_path = public as $$
  insert into audit_logs (employee_id, aksi, tabel, data_id, ringkasan, data)
  values ((select id from employees where user_id = auth.uid()), p_aksi, p_tabel, p_id, p_ringkasan, p_data)
$$;

create or replace function public.tg_audit()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_data jsonb; v_id text;
begin
  v_data := case when TG_OP = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
  v_data := v_data - 'updated_at';
  v_id := coalesce(v_data->>'id', v_data->>'kode', v_data->>'kunci', v_data->>'employee_id', v_data->>'jenis_dokumen');
  if TG_OP = 'UPDATE' then
    select jsonb_object_agg(k, jsonb_build_object('lama', to_jsonb(old)->k, 'baru', to_jsonb(new)->k))
      into v_data
    from jsonb_object_keys(to_jsonb(new)) k
    where k <> 'updated_at' and to_jsonb(old)->k is distinct from to_jsonb(new)->k;
    if v_data is null then return new; end if;
  end if;
  insert into audit_logs (employee_id, aksi, tabel, data_id, ringkasan, data)
  values ((select id from employees where user_id = auth.uid()),
          case TG_OP when 'INSERT' then 'tambah' when 'UPDATE' then 'ubah' else 'hapus' end,
          TG_TABLE_NAME, v_id, TG_OP || ' ' || TG_TABLE_NAME, v_data);
  return coalesce(new, old);
end $$;

do $$
declare t text;
begin
  foreach t in array array['employees','employee_functions','employee_structurals','feature_grants',
    'admin_permissions','institution_settings','letterheads','signatories','signer_rules','org_units',
    'functional_positions','structural_positions','doc_number_formats','letter_subject_codes',
    'holidays','holiday_calendars','academic_years']
  loop
    execute format('create trigger zz_audit after insert or update or delete on public.%I
                    for each row execute function public.tg_audit()', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- H. PENJAGA DATA PEGAWAI
-- ---------------------------------------------------------------------
-- Pegawai hanya dapat mengubah kolom pribadi ringan. Data yang memengaruhi gaji
-- (status, TMT, jabatan, pendidikan, level) wajib lewat admin/superadmin.
create or replace function public.tg_employees_jaga()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  boleh_pegawai text[] := array['tempat_lahir','tanggal_lahir','jenis_kelamin','status_keluarga',
                                'no_hp','foto_id','tema','updated_at'];
  kolom_sistem text[]  := array['user_id','username','email','wajib_ganti_sandi'];
  k text;
begin
  new.updated_at := now();
  if auth.uid() is null then return new; end if;           -- service role / pg_cron

  if public.is_superadmin() then
    if old.peran = 'superadmin' and new.peran <> 'superadmin' then
      raise exception 'Peran superadmin tidak dapat dicabut dari akun superadmin.';
    end if;
    foreach k in array kolom_sistem loop
      if to_jsonb(new)->k is distinct from to_jsonb(old)->k and k <> 'wajib_ganti_sandi' then
        raise exception 'Kolom % hanya dapat diubah melalui menu kelola akun.', k;
      end if;
    end loop;
    return new;
  end if;

  if public.is_admin() then
    if new.peran is distinct from old.peran then
      raise exception 'Hanya superadmin yang dapat mengubah peran akun.';
    end if;
    if old.peran = 'superadmin' then
      raise exception 'Data superadmin hanya dapat diubah oleh superadmin.';
    end if;
    foreach k in array kolom_sistem loop
      if to_jsonb(new)->k is distinct from to_jsonb(old)->k then
        raise exception 'Kolom % hanya dapat diubah melalui menu kelola akun.', k;
      end if;
    end loop;
    return new;
  end if;

  -- pegawai biasa: hanya data diri ringan
  for k in select jsonb_object_keys(to_jsonb(new)) loop
    if not (k = any(boleh_pegawai)) and to_jsonb(new)->k is distinct from to_jsonb(old)->k then
      raise exception 'Kolom % hanya dapat diubah oleh admin setelah verifikasi.', k using errcode = '42501';
    end if;
  end loop;
  return new;
end $$;
create trigger aa_jaga before update on public.employees
  for each row execute function public.tg_employees_jaga();

-- Riwayat kepegawaian otomatis (dasar gaji per periode)
create or replace function public.tg_employees_riwayat()
returns trigger language plpgsql security definer set search_path = public as $$
declare k text; v_saya uuid := (select id from employees where user_id = auth.uid());
begin
  foreach k in array array['status_kepegawaian','status_keaktifan','pendidikan_terakhir',
                           'level_muhaffizh','kategori_honorer','tmt_tugas','org_unit_id']
  loop
    if to_jsonb(new)->>k is distinct from to_jsonb(old)->>k then
      insert into employment_history (employee_id, jenis, nilai_lama, nilai_baru, dicatat_oleh)
      values (new.id, case k when 'pendidikan_terakhir' then 'pendidikan' when 'tmt_tugas' then 'tmt'
                             when 'org_unit_id' then 'unit' else k end,
              to_jsonb(old)->>k, to_jsonb(new)->>k, v_saya);
    end if;
  end loop;
  return new;
end $$;
create trigger bb_riwayat after update on public.employees
  for each row execute function public.tg_employees_riwayat();

create or replace function public.tg_jabatan_riwayat()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_saya uuid := (select id from employees where user_id = auth.uid());
begin
  if TG_TABLE_NAME = 'employee_structurals' then
    insert into employment_history (employee_id, jenis, nilai_lama, nilai_baru, dicatat_oleh)
    values (coalesce(new.employee_id, old.employee_id), 'jabatan_struktural',
            (select nama from structural_positions where id = old.structural_position_id),
            (select nama from structural_positions where id = new.structural_position_id), v_saya);
  else
    insert into employment_history (employee_id, jenis, nilai_lama, nilai_baru, dicatat_oleh)
    values (coalesce(new.employee_id, old.employee_id), 'jabatan_fungsional',
            case when TG_OP = 'DELETE' then (select nama from functional_positions where id = old.functional_position_id) end,
            case when TG_OP = 'INSERT' then (select nama from functional_positions where id = new.functional_position_id) end,
            v_saya);
  end if;
  return coalesce(new, old);
end $$;
create trigger bb_riwayat after insert or update or delete on public.employee_structurals
  for each row execute function public.tg_jabatan_riwayat();
create trigger bb_riwayat after insert or delete on public.employee_functions
  for each row execute function public.tg_jabatan_riwayat();

-- Medis dan security tidak boleh rangkap tugas
create or replace function public.tg_cek_rangkap()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if exists (
    select 1 from employee_functions ef join functional_positions fp on fp.id = ef.functional_position_id
    where ef.employee_id = new.employee_id and ef.functional_position_id <> new.functional_position_id
      and (fp.tanpa_rangkap or (select tanpa_rangkap from functional_positions where id = new.functional_position_id))
  ) then
    raise exception 'Tugas medis dan security tidak dapat dirangkap dengan tugas fungsional lain.';
  end if;
  return new;
end $$;
create trigger aa_cek_rangkap before insert on public.employee_functions
  for each row execute function public.tg_cek_rangkap();

-- Notifikasi otomatis untuk pendaftaran dan aktivasi akun
create or replace function public.tg_employees_notif()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status_akun = 'menunggu' and (TG_OP = 'INSERT' or old.status_akun is distinct from 'menunggu') then
    perform public.notifikasi_admin('verval_akun', 'Pendaftaran pegawai baru',
      new.nama_lengkap || ' menunggu verifikasi akun.', '/pegawai/' || new.id, 'UserPlus', 'biru');
  elsif TG_OP = 'UPDATE' and new.status_akun = 'aktif' and old.status_akun is distinct from 'aktif' then
    perform public.kirim_notifikasi(new.id, 'Akun Anda telah aktif',
      'Selamat bergabung di SIMKA PRO. Lengkapi profil Anda bila masih ada data yang kosong.',
      '/profil', 'CheckCircle', 'hijau');
  end if;
  return new;
end $$;
create trigger cc_notif after insert or update of status_akun on public.employees
  for each row execute function public.tg_employees_notif();

-- Superadmin selesai mengganti sandi sementara
create or replace function public.selesai_ganti_sandi()
returns void language sql volatile security definer set search_path = public as $$
  update employees set wajib_ganti_sandi = false where user_id = auth.uid()
$$;

-- updated_at umum
create or replace function public.tg_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at := now(); return new; end $$;
create trigger aa_updated before update on public.letterheads for each row execute function public.tg_updated_at();
create trigger aa_updated before update on public.institution_settings for each row execute function public.tg_updated_at();
create trigger aa_updated before update on public.doc_number_formats for each row execute function public.tg_updated_at();

-- ---------------------------------------------------------------------
-- I. TAMPILAN DATA PEGAWAI DAN STATISTIK BERANDA
-- ---------------------------------------------------------------------
create or replace view public.v_pegawai with (security_invoker = true) as
select e.*,
  case when e.tempat_lahir is not null and e.tanggal_lahir is not null
       then e.tempat_lahir || ', ' || public.tanggal_indo(e.tanggal_lahir) end as ttl,
  public.masa_kerja(e.tmt_tugas) as masa_kerja,
  u.nama as nama_unit,
  sp.nama as jabatan_struktural,
  es.structural_position_id,
  es.org_unit_id as unit_struktural_id,
  coalesce((select array_agg(fp.nama order by fp.urutan) from employee_functions ef
            join functional_positions fp on fp.id = ef.functional_position_id
            where ef.employee_id = e.id), '{}') as jabatan_fungsional,
  coalesce((select array_agg(ef.functional_position_id) from employee_functions ef
            where ef.employee_id = e.id), '{}') as fungsional_ids
from public.employees e
left join public.org_units u on u.id = e.org_unit_id
left join public.employee_structurals es on es.employee_id = e.id
left join public.structural_positions sp on sp.id = es.structural_position_id;

create or replace function public.statistik_beranda()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_saya uuid := public.saya(); r jsonb;
begin
  if v_saya is null then return '{}'::jsonb; end if;
  r := jsonb_build_object(
    'notifikasi_belum_dibaca', (select count(*) from notifications where employee_id = v_saya and dibaca_pada is null),
    'waktu', public.waktu_server());
  if public.is_admin() then
    r := r || jsonb_build_object(
      'pegawai_aktif',      (select count(*) from employees where status_keaktifan = 'aktif' and status_akun <> 'ditolak'),
      'akun_aktif',         (select count(*) from employees where status_akun = 'aktif'),
      'menunggu_verifikasi',(select count(*) from employees where status_akun = 'menunggu'),
      'tanpa_akun',         (select count(*) from employees where status_akun = 'tanpa_akun'),
      'laki_laki',          (select count(*) from employees where jenis_kelamin = 'L' and status_keaktifan = 'aktif'),
      'perempuan',          (select count(*) from employees where jenis_kelamin = 'P' and status_keaktifan = 'aktif'),
      'bidang_aktif',       (select count(*) from org_units where jenis = 'bidang' and aktif),
      'admin',              (select count(*) from employees where peran = 'admin' and status_akun = 'aktif'),
      'per_status',         (select coalesce(jsonb_object_agg(coalesce(status_kepegawaian,'belum_diisi'), n), '{}')
                               from (select status_kepegawaian, count(*) n from employees
                                     where status_keaktifan = 'aktif' group by 1) s),
      'per_bidang',         (select coalesce(jsonb_agg(jsonb_build_object('bidang', nama, 'jumlah', n) order by urutan), '[]')
                               from (select u.nama, u.urutan, count(e.id) n from org_units u
                                     left join employees e on e.org_unit_id in (select public.unit_turunan(u.id))
                                          and e.status_keaktifan = 'aktif'
                                     where u.jenis = 'bidang' and u.aktif group by u.id, u.nama, u.urutan) b),
      'audit_hari_ini',     (select count(*) from audit_logs where created_at >= public.hari_ini()));
  end if;
  if public.is_superadmin() then
    r := r || jsonb_build_object(
      'heartbeat_terakhir', (select max(created_at) from heartbeat),
      'berkas_antri',       (select count(*) from storage_objects where status = 'antri'),
      'berkas_gagal',       (select count(*) from storage_objects where status = 'gagal'));
  end if;
  return r;
end $$;
