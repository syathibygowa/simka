-- SIMKA PRO | supabase/migrations/20261004003100_kelompok_santri.sql | v1.0 | Fase 4 – Tahap 2 Kelompok santri | 04/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 4 · Migrasi 31: Pengaturan kelompok santri dan akses berbasis kelompok (Blueprint Bagian 15)
--   * student_groups : kelas (rombel), kamar/asrama, halaqah, ekskul, lainnya — per tahun ajaran; grup WA; naqib
--   * group_keepers  : pengasuh utama, pendamping, dan pengganti sementara (bertanggal; akses gugur otomatis)
--   * group_members  : anggota beserta riwayat pindah (mulai–selesai); satu kelas, satu kamar, satu halaqah
--                      per santri per tahun ajaran; ekskul boleh lebih dari satu
--   * kelompok_saya(): kelompok yang sedang diasuh pengguna → santri_terlihat() kini juga memuat santri asuhan
--   * simpan_kelompok, hapus_kelompok, atur_pengasuh, tambah_anggota, keluarkan_anggota, impor_pembagian
-- Penulisan hanya lewat fungsi (admin ber-izin kelompok_santri atau hak fitur kelompok_santri tingkat 2+).
-- Jalankan SETELAH migrasi 3000. Aman dijalankan ulang.
-- =====================================================================

update public.admin_capabilities set nama = 'Mengatur kelompok santri: kelas, kamar, halaqah, ekskul, pengasuh, dan anggota (Fase 4)'
where kode = 'kelompok_santri';

-- ---------------------------------------------------------------------
-- 1. TABEL
-- ---------------------------------------------------------------------
create table if not exists public.student_groups (
  id                uuid primary key default gen_random_uuid(),
  academic_year_id  uuid not null references public.academic_years(id) on delete restrict,
  jenis             text not null constraint student_groups_jenis_check check (jenis in ('kelas','kamar','halaqah','ekskul','lainnya')),
  nama              text not null constraint student_groups_nama_check check (length(trim(nama)) >= 1),
  jenjang           text constraint student_groups_jenjang_check check (jenjang in ('wustha','sma')),
  tingkat           smallint,
  jenis_kelamin     text constraint student_groups_jk_check check (jenis_kelamin in ('L','P')),   -- kosong = campuran
  keterangan        text,
  wa_wali           text,      -- tautan grup WA wali santri
  wa_internal       text,      -- tautan grup WA internal pengasuh
  naqib_id          uuid references public.students(id) on delete set null,   -- ketua halaqah
  aktif             boolean not null default true,
  urutan            int not null default 0,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  constraint student_groups_unik unique (academic_year_id, jenis, nama),
  constraint student_groups_kelas_check check (jenis <> 'kelas' or (jenjang is not null and tingkat is not null and
    ((jenjang = 'wustha' and tingkat between 7 and 9) or (jenjang = 'sma' and tingkat between 10 and 12)))),
  constraint student_groups_jk_wajib check (jenis not in ('kamar','halaqah') or jenis_kelamin is not null)
);
create index if not exists student_groups_ta_idx on public.student_groups (academic_year_id, jenis, aktif);

create table if not exists public.group_keepers (
  id           uuid primary key default gen_random_uuid(),
  group_id     uuid not null references public.student_groups(id) on delete cascade,
  employee_id  uuid not null references public.employees(id) on delete cascade,
  peran        text not null default 'utama' constraint group_keepers_peran_check check (peran in ('utama','pendamping','pengganti')),
  mulai        date,
  sampai       date,
  catatan      text,
  created_at   timestamptz not null default now(),
  constraint group_keepers_unik unique (group_id, employee_id),
  constraint group_keepers_pengganti check (peran <> 'pengganti' or sampai is not null),
  constraint group_keepers_rentang check (mulai is null or sampai is null or sampai >= mulai)
);
create index if not exists group_keepers_pegawai_idx on public.group_keepers (employee_id);

create table if not exists public.group_members (
  id                uuid primary key default gen_random_uuid(),
  group_id          uuid not null references public.student_groups(id) on delete cascade,
  student_id        uuid not null references public.students(id) on delete cascade,
  jenis             text not null,              -- disalin dari kelompok (penjaga satu kelas/kamar/halaqah)
  academic_year_id  uuid not null,              -- disalin dari kelompok
  mulai             date not null default public.hari_ini(),
  selesai           date,
  alasan_keluar     text,
  created_at        timestamptz not null default now()
);
create unique index if not exists group_members_satu_aktif on public.group_members (group_id, student_id) where selesai is null;
create unique index if not exists group_members_satu_jenis on public.group_members (student_id, academic_year_id, jenis)
  where selesai is null and jenis in ('kelas','kamar','halaqah');
create index if not exists group_members_kelompok_idx on public.group_members (group_id) where selesai is null;
create index if not exists group_members_santri_idx on public.group_members (student_id);

create or replace function public.tg_group_members_salin()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  select g.jenis, g.academic_year_id into new.jenis, new.academic_year_id from student_groups g where g.id = new.group_id;
  return new;
end $$;
drop trigger if exists aa_salin on public.group_members;
create trigger aa_salin before insert or update of group_id on public.group_members
  for each row execute function public.tg_group_members_salin();

drop trigger if exists aa_updated on public.student_groups;
create trigger aa_updated before update on public.student_groups for each row execute function public.tg_updated_at();
drop trigger if exists zz_audit on public.student_groups;
create trigger zz_audit after insert or update or delete on public.student_groups for each row execute function public.tg_audit();
drop trigger if exists zz_audit on public.group_keepers;
create trigger zz_audit after insert or update or delete on public.group_keepers for each row execute function public.tg_audit();

-- ---------------------------------------------------------------------
-- 2. CAKUPAN
-- ---------------------------------------------------------------------
-- Kelompok tahun ajaran aktif yang sedang diasuh pengguna (pengganti hanya dalam rentang tanggalnya)
create or replace function public.kelompok_saya()
returns setof uuid language sql stable security definer set search_path = public as $$
  select k.group_id from group_keepers k
  join student_groups g on g.id = k.group_id and g.aktif
  join academic_years a on a.id = g.academic_year_id and a.aktif
  where k.employee_id = public.saya()
    and (k.mulai is null or k.mulai <= public.hari_ini())
    and (k.sampai is null or k.sampai >= public.hari_ini())
$$;

-- Santri yang boleh dilihat: (1) admin semua; (2) pemegang fitur data_santri menurut cakupan pimpinan;
-- (3) pengasuh: anggota aktif kelompok asuhannya.
create or replace function public.santri_terlihat()
returns setof uuid language plpgsql stable security definer set search_path = public as $$
declare v_wustha uuid; v_sma uuid; v_jenjang text[] := '{}'; v_lain boolean;
begin
  if public.saya() is null then return; end if;
  if public.is_admin() then return query select id from students; return; end if;
  if public.tingkat_fitur('data_santri') >= 1 then
    select id into v_wustha from org_units where kode = 'WUSTHA';
    select id into v_sma from org_units where kode = 'SMA';
    if exists (select 1 from public.unit_pimpinan_saya() u where u = v_wustha) then v_jenjang := array_append(v_jenjang, 'wustha'); end if;
    if exists (select 1 from public.unit_pimpinan_saya() u where u = v_sma) then v_jenjang := array_append(v_jenjang, 'sma'); end if;
    select exists (select 1 from public.unit_pimpinan_saya() u
                   where u not in (select public.unit_turunan(v_wustha)) and u not in (select public.unit_turunan(v_sma)))
      into v_lain;
    if v_lain or cardinality(v_jenjang) = 0 then
      return query select id from students; return;
    else
      return query select id from students where jenjang = any(v_jenjang);
    end if;
  end if;
  return query select m.student_id from group_members m
               where m.selesai is null and m.group_id in (select public.kelompok_saya());
end $$;

-- Wali kelas (pengasuh utama/pendamping kelas yang sedang berlaku) boleh memperbarui data santri kelasnya
create or replace function public.santri_wali_kelas_saya()
returns setof uuid language sql stable security definer set search_path = public as $$
  select m.student_id from group_members m join student_groups g on g.id = m.group_id
  where m.selesai is null and g.jenis = 'kelas' and g.id in (select public.kelompok_saya())
$$;

create or replace function public.boleh_ubah_santri(p_id uuid default null)
returns boolean language sql stable security definer set search_path = public as $$
  select public.admin_boleh('kelola_santri')
      or (public.tingkat_fitur('data_santri') >= 2 and (p_id is null or p_id in (select public.santri_terlihat())))
      or (p_id is not null and p_id in (select public.santri_wali_kelas_saya()))
$$;

create or replace function public.boleh_kelola_kelompok()
returns boolean language sql stable security definer set search_path = public as $$
  select public.admin_boleh('kelompok_santri') or public.tingkat_fitur('kelompok_santri') >= 2
$$;

-- ---------------------------------------------------------------------
-- 3. RLS (hanya baca; tulis lewat fungsi)
-- ---------------------------------------------------------------------
alter table public.student_groups enable row level security;
alter table public.group_keepers enable row level security;
alter table public.group_members enable row level security;

drop policy if exists kelompok_baca on public.student_groups;
create policy kelompok_baca on public.student_groups for select to authenticated using (
  (select public.is_admin()) or (select public.tingkat_fitur('data_santri')) >= 1
  or (select public.tingkat_fitur('kelompok_santri')) >= 1 or id in (select public.kelompok_saya()));
drop policy if exists pengasuh_baca on public.group_keepers;
create policy pengasuh_baca on public.group_keepers for select to authenticated using (
  group_id in (select id from public.student_groups));
drop policy if exists anggota_baca on public.group_members;
create policy anggota_baca on public.group_members for select to authenticated using (
  student_id in (select public.santri_terlihat()));

-- ---------------------------------------------------------------------
-- 4. NOTIFIKASI PENGASUH DAN PENUTUPAN KEANGGOTAAN SAAT SANTRI KELUAR
-- ---------------------------------------------------------------------
create or replace function public.tg_group_keepers_notif()
returns trigger language plpgsql security definer set search_path = public as $$
declare g student_groups; v_label text; v_kata text;
begin
  select * into g from student_groups where id = new.group_id;
  v_kata := case g.jenis when 'lainnya' then 'kelompok' else g.jenis end;
  v_label := case g.jenis when 'kelas' then 'wali' when 'kamar' then 'musyrif/musyrifah'
             when 'halaqah' then 'muhaffizh/muhaffizhah' else 'pembina' end
             || ' ' || case when lower(g.nama) like v_kata || '%' then '' else v_kata || ' ' end;
  if new.employee_id is distinct from public.saya() then
    insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
    values (new.employee_id,
            'Anda ditetapkan sebagai ' || v_label || g.nama,
            case new.peran when 'utama' then 'Peran: pengasuh utama.' when 'pendamping' then 'Peran: pendamping.'
              else 'Peran: pengganti sementara sampai ' || public.tanggal_indo(new.sampai) || '.' end
              || ' Daftar santri asuhan dapat dibuka di menu Kelompok Santri.',
            '/kelompok-santri/k/' || g.id, 'GraduationCap', 'biru');
  end if;
  return new;
end $$;
drop trigger if exists zz_notif on public.group_keepers;
create trigger zz_notif after insert on public.group_keepers for each row execute function public.tg_group_keepers_notif();

-- Santri mutasi keluar, lulus, atau berhenti → keanggotaan aktif ditutup pada tanggal statusnya
create or replace function public.tg_students_tutup_kelompok()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status in ('mutasi_keluar','lulus','berhenti') and old.status is distinct from new.status then
    update group_members set selesai = greatest(mulai, new.status_sejak),
      alasan_keluar = case new.status when 'mutasi_keluar' then 'Mutasi keluar' when 'lulus' then 'Lulus' else 'Berhenti' end
    where student_id = new.id and selesai is null;
  end if;
  return new;
end $$;
drop trigger if exists ac_tutup_kelompok on public.students;
create trigger ac_tutup_kelompok after update of status on public.students
  for each row execute function public.tg_students_tutup_kelompok();

-- ---------------------------------------------------------------------
-- 5. KELOMPOK
-- ---------------------------------------------------------------------
create or replace function public._ta_boleh_ubah(p_ta uuid)
returns void language plpgsql stable security definer set search_path = public as $$
begin
  if exists (select 1 from academic_years where id = p_ta and terkunci) then
    raise exception 'Tahun ajaran ini sudah dikunci sebagai arsip (baca saja).';
  end if;
end $$;

-- p: {id?, academic_year_id?, jenis, nama, jenjang?, tingkat?, jenis_kelamin?, keterangan?, wa_wali?, wa_internal?, naqib_id?, aktif?, urutan?}
create or replace function public.simpan_kelompok(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid := nullif(p->>'id', '')::uuid; v_ta uuid; v_jenis text; v_tingkat smallint; v_jenjang text; v_wa text;
begin
  if not public.boleh_kelola_kelompok() then
    raise exception 'Anda tidak berwenang mengatur kelompok santri.' using errcode = '42501';
  end if;
  v_ta := coalesce(nullif(p->>'academic_year_id', '')::uuid, (select academic_year_id from student_groups where id = v_id),
                   (select id from academic_years where aktif));
  if v_ta is null then raise exception 'Belum ada tahun ajaran aktif. Atur di Pengaturan → Tahun ajaran.'; end if;
  perform public._ta_boleh_ubah(v_ta);
  v_jenis := coalesce(nullif(p->>'jenis', ''), (select jenis from student_groups where id = v_id));
  v_tingkat := nullif(p->>'tingkat', '')::smallint;
  v_jenjang := coalesce(nullif(p->>'jenjang', ''), case when v_tingkat >= 10 then 'sma' when v_tingkat >= 7 then 'wustha' end);
  if v_jenis <> 'kelas' then v_tingkat := null; v_jenjang := nullif(p->>'jenjang', ''); end if;
  foreach v_wa in array array[p->>'wa_wali', p->>'wa_internal'] loop
    if coalesce(v_wa, '') <> '' and v_wa !~* '^https?://' then
      raise exception 'Tautan grup WA harus diawali https:// (contoh https://chat.whatsapp.com/…).';
    end if;
  end loop;
  if v_id is null then
    insert into student_groups (academic_year_id, jenis, nama, jenjang, tingkat, jenis_kelamin, keterangan, wa_wali, wa_internal, naqib_id, aktif, urutan)
    values (v_ta, v_jenis, trim(p->>'nama'), v_jenjang, v_tingkat, nullif(p->>'jenis_kelamin', ''), nullif(trim(p->>'keterangan'), ''),
            nullif(trim(p->>'wa_wali'), ''), nullif(trim(p->>'wa_internal'), ''), nullif(p->>'naqib_id', '')::uuid,
            coalesce((p->>'aktif')::boolean, true), coalesce((p->>'urutan')::int, 0))
    returning id into v_id;
  else
    update student_groups set
      nama = trim(p->>'nama'), jenjang = v_jenjang, tingkat = v_tingkat,
      jenis_kelamin = nullif(p->>'jenis_kelamin', ''), keterangan = nullif(trim(p->>'keterangan'), ''),
      wa_wali = nullif(trim(p->>'wa_wali'), ''), wa_internal = nullif(trim(p->>'wa_internal'), ''),
      naqib_id = nullif(p->>'naqib_id', '')::uuid, aktif = coalesce((p->>'aktif')::boolean, aktif),
      urutan = coalesce((p->>'urutan')::int, urutan)
    where id = v_id;
    if not found then raise exception 'Kelompok tidak ditemukan.'; end if;
    -- Jenis kelamin kelompok tidak boleh bertentangan dengan anggota aktif
    if exists (select 1 from group_members m join students s on s.id = m.student_id join student_groups g on g.id = m.group_id
               where m.group_id = v_id and m.selesai is null and g.jenis_kelamin is not null and s.jenis_kelamin <> g.jenis_kelamin) then
      raise exception 'Masih ada anggota yang jenis kelaminnya berbeda dengan pilihan kelompok ini.';
    end if;
  end if;
  if (select naqib_id from student_groups where id = v_id) is not null and not exists (
      select 1 from group_members where group_id = v_id and selesai is null and student_id = (select naqib_id from student_groups where id = v_id)) then
    raise exception 'Naqib harus anggota aktif halaqah ini.';
  end if;
  return v_id;
end $$;

create or replace function public._pesan_kelompok(p_kode text, p_kendala text, p_pesan text)
returns text language sql immutable as $$
  select case
    when p_kendala = 'student_groups_unik' then 'Nama kelompok sudah dipakai untuk jenis yang sama di tahun ajaran ini.'
    when p_kendala = 'student_groups_kelas_check' then 'Kelas wajib memiliki tingkat yang sesuai jenjang (Wustha 7–9, SMA 10–12).'
    when p_kendala = 'student_groups_jk_wajib' then 'Kamar dan halaqah wajib ditentukan putra atau putri.'
    when p_kendala = 'student_groups_nama_check' then 'Nama kelompok wajib diisi.'
    when p_kendala = 'group_keepers_pengganti' then 'Pengganti sementara wajib memiliki tanggal berakhir.'
    when p_kendala = 'group_keepers_rentang' then 'Tanggal berakhir tidak boleh sebelum tanggal mulai.'
    when p_kendala = 'group_keepers_unik' then 'Pegawai yang sama tercantum dua kali sebagai pengasuh.'
    when p_kendala = 'group_members_satu_jenis' then 'Santri sudah terdaftar di kelompok lain yang sejenis.'
    else p_pesan end
$$;

create or replace function public.simpan_kelompok_form(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_kode text; v_kendala text; v_pesan text;
begin
  return public.simpan_kelompok(p);
exception when others then
  get stacked diagnostics v_kode = returned_sqlstate, v_kendala = constraint_name, v_pesan = message_text;
  raise exception '%', public._pesan_kelompok(v_kode, coalesce(v_kendala, ''), v_pesan) using errcode = v_kode;
end $$;

-- Hapus hanya kelompok yang belum pernah memiliki anggota; selebihnya dinonaktifkan agar riwayat tetap ada
create or replace function public.hapus_kelompok(p_id uuid)
returns text language plpgsql volatile security definer set search_path = public as $$
declare g student_groups;
begin
  if not public.boleh_kelola_kelompok() then raise exception 'Anda tidak berwenang mengatur kelompok santri.' using errcode = '42501'; end if;
  select * into g from student_groups where id = p_id;
  if not found then raise exception 'Kelompok tidak ditemukan.'; end if;
  perform public._ta_boleh_ubah(g.academic_year_id);
  if exists (select 1 from group_members where group_id = p_id) then
    update student_groups set aktif = false where id = p_id;
    update group_members set selesai = greatest(mulai, public.hari_ini()), alasan_keluar = 'Kelompok dinonaktifkan'
    where group_id = p_id and selesai is null;
    return 'dinonaktifkan';
  end if;
  delete from student_groups where id = p_id;
  return 'dihapus';
end $$;

-- p_daftar: [{employee_id, peran, mulai?, sampai?, catatan?}] — menggantikan daftar pengasuh kelompok
create or replace function public.atur_pengasuh(p_group uuid, p_daftar jsonb)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v_kode text; v_kendala text; v_pesan text; r jsonb;
begin
  if not public.boleh_kelola_kelompok() then raise exception 'Anda tidak berwenang mengatur pengasuh kelompok.' using errcode = '42501'; end if;
  perform public._ta_boleh_ubah((select academic_year_id from student_groups where id = p_group));
  delete from group_keepers where group_id = p_group
    and employee_id not in (select (x->>'employee_id')::uuid from jsonb_array_elements(coalesce(p_daftar, '[]')) x);
  for r in select * from jsonb_array_elements(coalesce(p_daftar, '[]')) loop
    if not exists (select 1 from employees where id = (r->>'employee_id')::uuid and status_keaktifan = 'aktif') then
      raise exception 'Pengasuh harus pegawai aktif.';
    end if;
    insert into group_keepers (group_id, employee_id, peran, mulai, sampai, catatan)
    values (p_group, (r->>'employee_id')::uuid, coalesce(nullif(r->>'peran', ''), 'utama'),
            nullif(r->>'mulai', '')::date, nullif(r->>'sampai', '')::date, nullif(trim(r->>'catatan'), ''))
    on conflict (group_id, employee_id) do update set peran = excluded.peran, mulai = excluded.mulai,
      sampai = excluded.sampai, catatan = excluded.catatan;
  end loop;
exception when others then
  get stacked diagnostics v_kode = returned_sqlstate, v_kendala = constraint_name, v_pesan = message_text;
  raise exception '%', public._pesan_kelompok(v_kode, coalesce(v_kendala, ''), v_pesan) using errcode = v_kode;
end $$;

-- ---------------------------------------------------------------------
-- 6. ANGGOTA
-- ---------------------------------------------------------------------
-- Satu santri ke satu kelompok (dipakai tambah_anggota dan impor). Kelas/kamar/halaqah lama di tahun ajaran
-- yang sama otomatis ditutup ("pindah"). Mengembalikan: 'ditambah', 'dipindah', atau 'sudah'.
create or replace function public._masukkan_anggota(p_group uuid, p_santri uuid, p_tanggal date, p_alasan text)
returns text language plpgsql volatile security definer set search_path = public as $$
declare g student_groups; s students; v_lama uuid; v_nama_lama text;
begin
  select * into g from student_groups where id = p_group;
  select * into s from students where id = p_santri;
  if not found then raise exception 'Santri tidak ditemukan.'; end if;
  if s.status not in ('aktif','nonaktif') then raise exception '% berstatus tidak aktif.', s.nama_lengkap; end if;
  if not g.aktif then raise exception 'Kelompok % nonaktif.', g.nama; end if;
  if g.jenis_kelamin is not null and g.jenis_kelamin <> s.jenis_kelamin then
    raise exception '% tidak sesuai: kelompok % khusus %.', s.nama_lengkap, g.nama, case g.jenis_kelamin when 'L' then 'putra' else 'putri' end;
  end if;
  if g.jenis = 'kelas' and (g.tingkat <> s.tingkat or g.jenjang <> s.jenjang) then
    raise exception '% tercatat kelas % sedangkan % untuk kelas %. Ubah kelas di Data Santri bila perlu.', s.nama_lengkap, s.tingkat, g.nama, g.tingkat;
  end if;
  if exists (select 1 from group_members where group_id = p_group and student_id = p_santri and selesai is null) then return 'sudah'; end if;
  if g.jenis in ('kelas','kamar','halaqah') then
    select m.id, gg.nama into v_lama, v_nama_lama from group_members m join student_groups gg on gg.id = m.group_id
    where m.student_id = p_santri and m.academic_year_id = g.academic_year_id and m.jenis = g.jenis and m.selesai is null;
    if v_lama is not null then
      update group_members set selesai = greatest(mulai, p_tanggal),
        alasan_keluar = 'Pindah ke ' || g.nama || coalesce(': ' || nullif(trim(p_alasan), ''), '')
      where id = v_lama;
      update student_groups set naqib_id = null where naqib_id = p_santri and id <> p_group and jenis = 'halaqah';
    end if;
  end if;
  insert into group_members (group_id, student_id, mulai) values (p_group, p_santri, p_tanggal);
  return case when v_lama is null then 'ditambah' else 'dipindah' end;
end $$;

create or replace function public.tambah_anggota(p_group uuid, p_santri uuid[], p_tanggal date default null, p_alasan text default null)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v uuid; h text; v_tgl date := coalesce(p_tanggal, public.hari_ini()); n_tambah int := 0; n_pindah int := 0; n_sudah int := 0;
  lewat jsonb := '[]'; v_pesan text;
begin
  if not public.boleh_kelola_kelompok() then raise exception 'Anda tidak berwenang mengatur anggota kelompok.' using errcode = '42501'; end if;
  perform public._ta_boleh_ubah((select academic_year_id from student_groups where id = p_group));
  foreach v in array p_santri loop
    begin
      h := public._masukkan_anggota(p_group, v, v_tgl, p_alasan);
      if h = 'ditambah' then n_tambah := n_tambah + 1; elsif h = 'dipindah' then n_pindah := n_pindah + 1; else n_sudah := n_sudah + 1; end if;
    exception when others then
      get stacked diagnostics v_pesan = message_text;
      lewat := lewat || jsonb_build_object('id', v, 'pesan', v_pesan);
    end;
  end loop;
  return jsonb_build_object('ditambah', n_tambah, 'dipindah', n_pindah, 'sudah', n_sudah, 'dilewati', lewat);
end $$;

create or replace function public.keluarkan_anggota(p_group uuid, p_santri uuid[], p_tanggal date default null, p_alasan text default null)
returns int language plpgsql volatile security definer set search_path = public as $$
declare n int;
begin
  if not public.boleh_kelola_kelompok() then raise exception 'Anda tidak berwenang mengatur anggota kelompok.' using errcode = '42501'; end if;
  perform public._ta_boleh_ubah((select academic_year_id from student_groups where id = p_group));
  update group_members set selesai = greatest(mulai, coalesce(p_tanggal, public.hari_ini())),
    alasan_keluar = coalesce(nullif(trim(p_alasan), ''), 'Dikeluarkan dari kelompok')
  where group_id = p_group and student_id = any(p_santri) and selesai is null;
  get diagnostics n = row_count;
  update student_groups set naqib_id = null where id = p_group and naqib_id = any(p_santri);
  return n;
end $$;

-- Impor pembagian dari Excel: [{nis, kelas?, kamar?, halaqah?, ekskul?: "Panahan, Pramuka"}]
-- Kelompok yang belum ada dibuat otomatis di tahun ajaran aktif (kelas: tingkat dibaca dari nama, mis. "7A").
create or replace function public.impor_pembagian(p_baris jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare r jsonb; i int := 0; s students; v_ta uuid; hasil jsonb := '[]'; v_jenis text; v_nama text; v_gid uuid;
  v_tingkat smallint; v_catatan text[]; v_pesan text; h text;
begin
  if not public.boleh_kelola_kelompok() then raise exception 'Anda tidak berwenang mengimpor pembagian kelompok.' using errcode = '42501'; end if;
  select id into v_ta from academic_years where aktif;
  if v_ta is null then raise exception 'Belum ada tahun ajaran aktif.'; end if;
  perform public._ta_boleh_ubah(v_ta);
  if jsonb_array_length(p_baris) > 700 then raise exception 'Maksimal 700 baris sekali impor.'; end if;
  for r in select * from jsonb_array_elements(p_baris) loop
    i := i + 1; v_catatan := '{}';
    select * into s from students where nis = trim(r->>'nis');
    if not found then
      hasil := hasil || jsonb_build_object('baris', i, 'ok', false, 'pesan', 'NIS ' || coalesce(r->>'nis', '') || ' belum terdaftar di Data Santri.');
      continue;
    end if;
    foreach v_jenis in array array['kelas','kamar','halaqah','ekskul'] loop
      for v_nama in select trim(x) from regexp_split_to_table(coalesce(r->>v_jenis, ''), case when v_jenis = 'ekskul' then '\s*[,;]\s*' else '\s*;\s*' end) x
                    where trim(x) <> '' loop
        begin
          select id into v_gid from student_groups where academic_year_id = v_ta and jenis = v_jenis and lower(nama) = lower(v_nama);
          if v_gid is null then
            if v_jenis = 'kelas' then
              v_tingkat := coalesce(substring(v_nama from '^(?:[Kk]elas\s*)?(1[0-2]|[7-9])')::smallint, s.tingkat);
            end if;
            insert into student_groups (academic_year_id, jenis, nama, jenjang, tingkat, jenis_kelamin)
            values (v_ta, v_jenis, v_nama,
                    case when v_jenis = 'kelas' then case when v_tingkat >= 10 then 'sma' else 'wustha' end end,
                    case when v_jenis = 'kelas' then v_tingkat end,
                    case when v_jenis in ('kamar','halaqah') then s.jenis_kelamin end)
            returning id into v_gid;
            h := public._masukkan_anggota(v_gid, s.id, public.hari_ini(), 'Impor pembagian');
            v_catatan := v_catatan || (initcap(v_jenis) || ' ' || v_nama || ' dibuat');
          else
            h := public._masukkan_anggota(v_gid, s.id, public.hari_ini(), 'Impor pembagian');
          end if;
          if h = 'dipindah' then v_catatan := v_catatan || ('pindah ' || v_jenis || ' ke ' || v_nama); end if;
        exception when others then
          get stacked diagnostics v_pesan = message_text;
          v_catatan := v_catatan || ('GAGAL ' || v_jenis || ' ' || v_nama || ': ' || v_pesan);
        end;
        v_gid := null;
      end loop;
    end loop;
    hasil := hasil || jsonb_build_object('baris', i, 'ok', not exists (select 1 from unnest(v_catatan) c where c like 'GAGAL%'),
                                         'nama', s.nama_lengkap, 'pesan', array_to_string(v_catatan, '; '));
  end loop;
  perform public.catat_audit('impor_pembagian', 'group_members', null, 'Impor pembagian kelompok: ' || jsonb_array_length(p_baris) || ' baris', null);
  return hasil;
end $$;

-- ---------------------------------------------------------------------
-- 7. TAMPILAN
-- ---------------------------------------------------------------------
-- Kelompok beserta jumlah anggota dan pengasuh (nama pengasuh dapat dibaca semua yang berhak melihat kelompok)
create or replace view public.v_kelompok as
select g.*, a.nama as tahun_ajaran, a.aktif as ta_aktif, a.terkunci as ta_terkunci,
  (select count(*) from group_members m where m.group_id = g.id and m.selesai is null)::int as jumlah,
  (select count(*) from group_members m join students s on s.id = m.student_id where m.group_id = g.id and m.selesai is null and s.jenis_kelamin = 'L')::int as jumlah_l,
  (select count(*) from group_members m join students s on s.id = m.student_id where m.group_id = g.id and m.selesai is null and s.jenis_kelamin = 'P')::int as jumlah_p,
  (select nama_lengkap from students where id = g.naqib_id) as nama_naqib,
  coalesce((select jsonb_agg(jsonb_build_object('employee_id', k.employee_id, 'nama', e.nama_lengkap, 'niy', e.niy,
                     'jenis_kelamin', e.jenis_kelamin, 'no_hp', case when (select public.is_admin()) then e.no_hp end,
                     'peran', k.peran, 'mulai', k.mulai, 'sampai', k.sampai, 'catatan', k.catatan,
                     'berlaku', (k.mulai is null or k.mulai <= public.hari_ini()) and (k.sampai is null or k.sampai >= public.hari_ini()))
                   order by array_position(array['utama','pendamping','pengganti'], k.peran), e.nama_lengkap)
            from group_keepers k join employees e on e.id = k.employee_id where k.group_id = g.id), '[]'::jsonb) as pengasuh,
  (g.id in (select public.kelompok_saya())) as asuhan_saya
from public.student_groups g
join public.academic_years a on a.id = g.academic_year_id
where (select public.is_admin()) or (select public.tingkat_fitur('data_santri')) >= 1
   or (select public.tingkat_fitur('kelompok_santri')) >= 1 or g.id in (select public.kelompok_saya());

-- Data santri kini memuat kelompok aktif tahun ajaran berjalan (kelas, kamar, halaqah, ekskul)
drop view if exists public.v_santri;
create view public.v_santri as
select s.*,
  case s.jenjang when 'wustha' then 'Kesetaraan Wustha' else 'SMA' end as nama_jenjang,
  case when s.tempat_lahir is not null and s.tanggal_lahir is not null
       then s.tempat_lahir || ', ' || public.tanggal_indo(s.tanggal_lahir) end as ttl,
  case when s.tanggal_lahir is not null then extract(year from age(public.hari_ini(), s.tanggal_lahir))::int end as usia,
  coalesce((select jsonb_agg(jsonb_build_object('hubungan', c.hubungan, 'nama', c.nama, 'no_hp', c.no_hp,
                                                'pekerjaan', c.pekerjaan, 'utama', c.utama)
                             order by array_position(array['ayah','ibu','wali'], c.hubungan))
            from public.student_contacts c where c.student_id = s.id), '[]'::jsonb) as kontak,
  coalesce((select jsonb_agg(jsonb_build_object('id', g.id, 'jenis', g.jenis, 'nama', g.nama)
                             order by array_position(array['kelas','kamar','halaqah','ekskul','lainnya'], g.jenis), g.nama)
            from public.group_members m join public.student_groups g on g.id = m.group_id
            join public.academic_years a on a.id = g.academic_year_id and a.aktif
            where m.student_id = s.id and m.selesai is null), '[]'::jsonb) as kelompok
from public.students s
where s.id in (select public.santri_terlihat());
comment on view public.v_santri is 'Dibaca dengan hak pemilik; baris dibatasi santri_terlihat() (cakupan pimpinan dan pengasuh).';
grant select on public.v_santri, public.v_kelompok to authenticated;
revoke select on public.v_santri, public.v_kelompok from anon;

-- Riwayat kelompok satu santri (semua tahun ajaran)
create or replace function public.riwayat_kelompok_santri(p_id uuid)
returns table (jenis text, nama text, tahun_ajaran text, mulai date, selesai date, alasan_keluar text)
language sql stable security definer set search_path = public as $$
  select g.jenis, g.nama, a.nama, m.mulai, m.selesai, m.alasan_keluar
  from group_members m join student_groups g on g.id = m.group_id join academic_years a on a.id = g.academic_year_id
  where m.student_id = p_id and p_id in (select public.santri_terlihat())
  order by a.mulai desc, m.mulai desc, g.jenis
$$;

do $$
declare f text;
begin
  foreach f in array array['kelompok_saya()','santri_wali_kelas_saya()','boleh_kelola_kelompok()','simpan_kelompok_form(jsonb)',
    'hapus_kelompok(uuid)','atur_pengasuh(uuid,jsonb)','tambah_anggota(uuid,uuid[],date,text)','keluarkan_anggota(uuid,uuid[],date,text)',
    'impor_pembagian(jsonb)','riwayat_kelompok_santri(uuid)']
  loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  execute 'revoke execute on function public.simpan_kelompok(jsonb) from public, anon, authenticated';
  execute 'revoke execute on function public._masukkan_anggota(uuid,uuid,date,text) from public, anon, authenticated';
end $$;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 6 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select 'Tabel kelompok (3) dengan RLS' as pemeriksaan,
       case when (select count(*) from pg_tables where schemaname = 'public' and rowsecurity
                   and tablename in ('student_groups','group_keepers','group_members')) = 3 then 'Sesuai' else 'Periksa' end as hasil
union all
select 'Tabel kelompok tidak dapat ditulis langsung',
       case when not exists (select 1 from pg_policies where schemaname = 'public'
                              and tablename in ('student_groups','group_keepers','group_members') and cmd <> 'SELECT') then 'Sesuai' else 'Periksa' end
union all
select 'Satu kelas, satu kamar, satu halaqah per santri',
       case when exists (select 1 from pg_indexes where indexname = 'group_members_satu_jenis') then 'Sesuai' else 'Periksa' end
union all
select 'Fungsi kelompok (6)',
       case when (select count(distinct proname) from pg_proc where proname in
                   ('simpan_kelompok_form','hapus_kelompok','atur_pengasuh','tambah_anggota','keluarkan_anggota','impor_pembagian')) = 6
            then 'Sesuai' else 'Periksa' end
union all
select 'Data santri memuat kelompok', case when exists (select 1 from information_schema.columns
       where table_name = 'v_santri' and column_name = 'kelompok') then 'Sesuai' else 'Periksa' end
union all
select 'Migrasi 3000 sudah terpasang',
       case when exists (select 1 from pg_proc where proname = 'simpan_santri_form') then 'Sesuai' else 'Periksa: jalankan 3000 dulu' end;
