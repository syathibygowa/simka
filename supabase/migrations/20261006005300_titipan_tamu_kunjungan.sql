-- SIMKA PRO | supabase/migrations/20261006005300_titipan_tamu_kunjungan.sql | v1.0 | Fase 7 – Tahap 2 Titipan, buku tamu, kunjungan | 06/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 7 · Migrasi 53: Titipan, Buku Tamu, Kunjungan Orang Tua (Blueprint Bagian 24)
--   * parcels (titipan): diterima Security dengan FOTO WAJIB; diambil dengan NAMA PENGAMBIL dan FOTO WAJIB
--     (mencegah paket hilang di pos); dapat dikembalikan ke pengirim atau dibatalkan (salah catat) dengan alasan.
--     Musyrif santri dinotifikasi saat titipan datang dan saat diambil; pengingat bila belum diambil N hari.
--   * guest_logs (buku tamu): nama, instansi, keperluan, orang yang ditemui (pegawai dinotifikasi), jam masuk/keluar, foto opsional.
--   * parent_visits (kunjungan): santri, pengunjung, hubungan, jam datang/pulang; musyrif dinotifikasi untuk memanggil santri;
--     kunjungan di luar jadwal (bila jadwal diaktifkan) hanya ditandai.
--   * Pengasuh (musyrif, wali kelas, muhaffizh) melihat titipan dan kunjungan santri asuhannya.
-- Jalankan SETELAH migrasi 5200. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TABEL
-- ---------------------------------------------------------------------
create table if not exists public.parcels (
  id              uuid primary key default gen_random_uuid(),
  student_id      uuid not null references public.students(id) on delete cascade,
  jenis           text not null default 'paket' check (jenis in ('paket','makanan','pakaian','uang','lainnya')),
  uraian          text not null,
  nominal         numeric(14,0),
  pengirim        text not null,
  hp_pengirim     text,
  ekspedisi       text,
  status          text not null default 'di_pos' check (status in ('di_pos','diambil','dikembalikan','batal')),
  diterima_pada   timestamptz not null default now(),
  diterima_oleh   uuid references public.employees(id) on delete set null,
  foto_terima_id  uuid references public.storage_objects(id) on delete set null,
  diambil_pada    timestamptz,
  pengambil_jenis text check (pengambil_jenis in ('santri','musyrif','wali','pengirim','lainnya')),
  pengambil_nama  text,
  diserahkan_oleh uuid references public.employees(id) on delete set null,
  foto_ambil_id   uuid references public.storage_objects(id) on delete set null,
  catatan         text,
  diingatkan      timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index if not exists pc_status_idx on public.parcels (status, diterima_pada desc);
create index if not exists pc_santri_idx on public.parcels (student_id, diterima_pada desc);

create table if not exists public.guest_logs (
  id              uuid primary key default gen_random_uuid(),
  nama            text not null,
  instansi        text,
  hp              text,
  keperluan       text not null,
  ditemui_id      uuid references public.employees(id) on delete set null,
  ditemui_teks    text,
  jumlah_orang    int not null default 1 check (jumlah_orang between 1 and 200),
  kendaraan       text,
  masuk_pada      timestamptz not null default now(),
  keluar_pada     timestamptz,
  foto_id         uuid references public.storage_objects(id) on delete set null,
  petugas_masuk   uuid references public.employees(id) on delete set null,
  petugas_keluar  uuid references public.employees(id) on delete set null,
  catatan         text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index if not exists gt_masuk_idx on public.guest_logs (masuk_pada desc);

create table if not exists public.parent_visits (
  id              uuid primary key default gen_random_uuid(),
  student_id      uuid not null references public.students(id) on delete cascade,
  pengunjung      text not null,
  hubungan        text,
  hp              text,
  jumlah_orang    int not null default 1 check (jumlah_orang between 1 and 50),
  datang_pada     timestamptz not null default now(),
  pulang_pada     timestamptz,
  luar_jadwal     boolean not null default false,
  foto_id         uuid references public.storage_objects(id) on delete set null,
  petugas_datang  uuid references public.employees(id) on delete set null,
  petugas_pulang  uuid references public.employees(id) on delete set null,
  catatan         text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index if not exists pv_datang_idx on public.parent_visits (datang_pada desc);
create index if not exists pv_santri_idx on public.parent_visits (student_id, datang_pada desc);

do $$
declare t text;
begin
  foreach t in array array['parcels','guest_logs','parent_visits'] loop
    execute format('drop trigger if exists aa_updated on public.%I', t);
    execute format('create trigger aa_updated before update on public.%I for each row execute function public.tg_updated_at()', t);
    execute format('drop trigger if exists zz_audit on public.%I', t);
    execute format('create trigger zz_audit after insert or update or delete on public.%I for each row execute function public.tg_audit()', t);
    execute format('alter table public.%I enable row level security', t);
    begin execute format('alter publication supabase_realtime add table public.%I', t); exception when others then null; end;
  end loop;
end $$;
drop policy if exists baca on public.parcels;
create policy baca on public.parcels for select to authenticated
  using (public.boleh_lihat_security() or student_id in (select public.santri_terlihat()));
drop policy if exists baca on public.parent_visits;
create policy baca on public.parent_visits for select to authenticated
  using (public.boleh_lihat_security() or student_id in (select public.santri_terlihat()));
drop policy if exists baca on public.guest_logs;
create policy baca on public.guest_logs for select to authenticated
  using (public.boleh_lihat_security() or ditemui_id = public.saya());

-- ---------------------------------------------------------------------
-- 2. PENGATURAN DAN HAK
-- ---------------------------------------------------------------------
create or replace function public.pengaturan_security()
returns jsonb language sql stable security definer set search_path = public as $$
  select '{"toleransi_terlambat_menit": 0, "keluar_lebih_awal_menit": 120, "pengingat_titipan_hari": 2,
           "jadwal_kunjungan_aktif": false, "hari_kunjungan": [0, 6], "jam_kunjungan_mulai": "08:00", "jam_kunjungan_selesai": "17:00"}'::jsonb
         || coalesce((select nilai from institution_settings where kunci = 'security'), '{}'::jsonb)
$$;

create or replace function public.simpan_pengaturan_security(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v jsonb := public.pengaturan_security(); t int; a int; h int;
begin
  if not public.boleh_kelola_security() then raise exception 'Anda tidak berwenang mengubah ketentuan Security.' using errcode = '42501'; end if;
  if p ? 'toleransi_terlambat_menit' then
    t := (p->>'toleransi_terlambat_menit')::int;
    if t is null or t < 0 or t > 720 then raise exception 'Toleransi terlambat kembali harus 0–720 menit.'; end if;
    v := v || jsonb_build_object('toleransi_terlambat_menit', t);
  end if;
  if p ? 'keluar_lebih_awal_menit' then
    a := (p->>'keluar_lebih_awal_menit')::int;
    if a is null or a < 0 or a > 1440 then raise exception 'Batas keluar lebih awal harus 0–1440 menit.'; end if;
    v := v || jsonb_build_object('keluar_lebih_awal_menit', a);
  end if;
  if p ? 'pengingat_titipan_hari' then
    h := (p->>'pengingat_titipan_hari')::int;
    if h is null or h < 1 or h > 30 then raise exception 'Pengingat titipan harus 1–30 hari.'; end if;
    v := v || jsonb_build_object('pengingat_titipan_hari', h);
  end if;
  if p ? 'jadwal_kunjungan_aktif' then v := v || jsonb_build_object('jadwal_kunjungan_aktif', coalesce((p->>'jadwal_kunjungan_aktif')::boolean, false)); end if;
  if p ? 'hari_kunjungan' then
    if jsonb_typeof(p->'hari_kunjungan') <> 'array' or exists (select 1 from jsonb_array_elements_text(p->'hari_kunjungan') x where x !~ '^[0-6]$') then
      raise exception 'Hari kunjungan tidak valid.'; end if;
    v := v || jsonb_build_object('hari_kunjungan', p->'hari_kunjungan');
  end if;
  if p ? 'jam_kunjungan_mulai' or p ? 'jam_kunjungan_selesai' then
    if coalesce(p->>'jam_kunjungan_mulai', v->>'jam_kunjungan_mulai') !~ '^\d{2}:\d{2}$' or coalesce(p->>'jam_kunjungan_selesai', v->>'jam_kunjungan_selesai') !~ '^\d{2}:\d{2}$'
       or coalesce(p->>'jam_kunjungan_selesai', v->>'jam_kunjungan_selesai') <= coalesce(p->>'jam_kunjungan_mulai', v->>'jam_kunjungan_mulai') then
      raise exception 'Jam kunjungan tidak valid (selesai harus setelah mulai).'; end if;
    v := v || jsonb_build_object('jam_kunjungan_mulai', coalesce(p->>'jam_kunjungan_mulai', v->>'jam_kunjungan_mulai'),
                                 'jam_kunjungan_selesai', coalesce(p->>'jam_kunjungan_selesai', v->>'jam_kunjungan_selesai'));
  end if;
  insert into institution_settings (kunci, nilai, updated_by) values ('security', v, public.saya())
  on conflict (kunci) do update set nilai = excluded.nilai, updated_at = now(), updated_by = excluded.updated_by;
  return public.pengaturan_security();
end $$;

/** Pengasuh: memegang kamar, kelas, atau halaqah aktif (melihat titipan dan kunjungan santri asuhannya). */
create or replace function public.hak_security()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('gerbang', public.boleh_gerbang(), 'kelola', public.boleh_kelola_security(),
    'lihat', public.boleh_lihat_security(), 'izin_cepat', public.boleh_izin_cepat(),
    'puncak', public.is_superadmin() or public.saya() in (select public._pimpinan_puncak()),
    'pengasuh', exists (select 1 from public.kelompok_saya() k join student_groups g on g.id = k where g.jenis in ('kamar','kelas','halaqah')))
$$;

/** Musyrif kamar santri yang berlaku hari ini. */
create or replace function public._musyrif_santri(p_santri uuid)
returns setof uuid language sql stable security definer set search_path = public as $$
  select distinct k.employee_id from group_members m
    join student_groups g on g.id = m.group_id and g.aktif and g.jenis = 'kamar'
    join academic_years a on a.id = g.academic_year_id and a.aktif
    join group_keepers k on k.group_id = g.id and (k.mulai is null or k.mulai <= public.hari_ini()) and (k.sampai is null or k.sampai >= public.hari_ini())
   where m.student_id = p_santri and m.selesai is null
$$;

-- ---------------------------------------------------------------------
-- 3. TITIPAN
-- ---------------------------------------------------------------------
create or replace function public._titipan_json(p_id uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', t.id, 'student_id', t.student_id, 'nama', s.nama_lengkap, 'nis', s.nis, 'jenis_kelamin', s.jenis_kelamin,
    'kelas', public._kelompok_santri(s.id, 'kelas'), 'kamar', public._kelompok_santri(s.id, 'kamar'),
    'jenis', t.jenis, 'uraian', t.uraian, 'nominal', t.nominal, 'pengirim', t.pengirim, 'hp_pengirim', t.hp_pengirim, 'ekspedisi', t.ekspedisi,
    'status', t.status, 'diterima_pada', t.diterima_pada, 'penerima', e1.nama_lengkap, 'foto_terima_id', t.foto_terima_id,
    'diambil_pada', t.diambil_pada, 'pengambil_jenis', t.pengambil_jenis, 'pengambil_nama', t.pengambil_nama, 'penyerah', e2.nama_lengkap,
    'foto_ambil_id', t.foto_ambil_id, 'catatan', t.catatan,
    'wali', (select jsonb_build_object('nama', c.nama, 'no_hp', c.no_hp, 'hubungan', c.hubungan) from student_contacts c
              where c.student_id = t.student_id and c.no_hp is not null order by c.utama desc, c.hubungan limit 1),
    'lama_jam', floor(extract(epoch from (coalesce(t.diambil_pada, now()) - t.diterima_pada)) / 3600)::int)
    from parcels t join students s on s.id = t.student_id
    left join employees e1 on e1.id = t.diterima_oleh left join employees e2 on e2.id = t.diserahkan_oleh
   where t.id = p_id
$$;

create or replace function public.terima_titipan(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v_s record; v_id uuid; v_jenis text := coalesce(nullif(p->>'jenis', ''), 'paket');
begin
  if not public.boleh_gerbang() then raise exception 'Hanya petugas Security yang dapat menerima titipan.' using errcode = '42501'; end if;
  select id, nama_lengkap, status into v_s from students where id = nullif(p->>'student_id', '')::uuid;
  if v_s.id is null then raise exception 'Pilih santri penerima titipan.'; end if;
  if v_s.status <> 'aktif' then raise exception '% tidak berstatus aktif.', v_s.nama_lengkap; end if;
  if v_jenis not in ('paket','makanan','pakaian','uang','lainnya') then raise exception 'Jenis titipan tidak dikenal.'; end if;
  if length(trim(coalesce(p->>'uraian', ''))) < 3 then raise exception 'Tuliskan uraian barang (minimal 3 huruf).'; end if;
  if length(trim(coalesce(p->>'pengirim', ''))) < 2 then raise exception 'Isi nama pengirim.'; end if;
  if v_jenis = 'uang' and coalesce((p->>'nominal')::numeric, 0) <= 0 then raise exception 'Isi nominal uang titipan.'; end if;
  if nullif(p->>'foto_terima_id', '') is null then raise exception 'Foto barang saat diterima wajib diambil.'; end if;
  insert into parcels (student_id, jenis, uraian, nominal, pengirim, hp_pengirim, ekspedisi, diterima_oleh, foto_terima_id, catatan)
  values (v_s.id, v_jenis, trim(p->>'uraian'), case when v_jenis = 'uang' then (p->>'nominal')::numeric end, trim(p->>'pengirim'),
          nullif(trim(p->>'hp_pengirim'), ''), nullif(trim(p->>'ekspedisi'), ''), public.saya(), (p->>'foto_terima_id')::uuid, nullif(trim(p->>'catatan'), ''))
  returning id into v_id;
  insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
  select x, 'Titipan untuk ' || v_s.nama_lengkap, initcap(v_jenis) || ': ' || trim(p->>'uraian') || ' · dari ' || trim(p->>'pengirim') || '. Silakan diambil di pos Security.',
         '/security/titipan', 'Package', 'teal'
    from public._musyrif_santri(v_s.id) x where x is distinct from public.saya();
  return public._titipan_json(v_id);
end $$;

/** p: { pengambil_jenis, pengambil_nama, foto_ambil_id, catatan } */
create or replace function public.ambil_titipan(p_id uuid, p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v parcels%rowtype; v_nama text; v_jenis text := p->>'pengambil_jenis';
begin
  if not public.boleh_gerbang() then raise exception 'Hanya petugas Security yang dapat menyerahkan titipan.' using errcode = '42501'; end if;
  select * into v from parcels where id = p_id for update;
  if v.id is null then raise exception 'Titipan tidak ditemukan.'; end if;
  if v.status <> 'di_pos' then raise exception 'Titipan ini sudah tidak berada di pos.'; end if;
  if v_jenis not in ('santri','musyrif','wali','lainnya') then raise exception 'Pilih siapa yang mengambil titipan.'; end if;
  if length(trim(coalesce(p->>'pengambil_nama', ''))) < 2 then raise exception 'Isi nama pengambil titipan.'; end if;
  if nullif(p->>'foto_ambil_id', '') is null then raise exception 'Foto pengambil bersama barang wajib diambil.'; end if;
  update parcels set status = 'diambil', diambil_pada = now(), pengambil_jenis = v_jenis, pengambil_nama = trim(p->>'pengambil_nama'),
         diserahkan_oleh = public.saya(), foto_ambil_id = (p->>'foto_ambil_id')::uuid,
         catatan = coalesce(nullif(trim(p->>'catatan'), ''), catatan) where id = p_id;
  select nama_lengkap into v_nama from students where id = v.student_id;
  insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
  select x, 'Titipan sudah diambil: ' || v_nama, v.uraian || ' · diambil ' || trim(p->>'pengambil_nama')
         || ' (' || v_jenis || ') ' || to_char(now() at time zone 'Asia/Makassar', 'DD/MM HH24.MI') || ' WITA', '/security/titipan', 'Package', 'hijau'
    from public._musyrif_santri(v.student_id) x where x is distinct from public.saya();
  return public._titipan_json(p_id);
end $$;

/** Kembalikan ke pengirim (status dikembalikan) atau batalkan karena salah catat (status batal; hanya pengelola). */
create or replace function public.tutup_titipan(p_id uuid, p_status text, p_alasan text, p_foto uuid default null)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v parcels%rowtype;
begin
  select * into v from parcels where id = p_id for update;
  if v.id is null then raise exception 'Titipan tidak ditemukan.'; end if;
  if v.status <> 'di_pos' then raise exception 'Titipan ini sudah tidak berada di pos.'; end if;
  if p_status = 'dikembalikan' then
    if not public.boleh_gerbang() then raise exception 'Hanya petugas Security.' using errcode = '42501'; end if;
  elsif p_status = 'batal' then
    if not public.boleh_kelola_security() then raise exception 'Pembatalan titipan hanya oleh superadmin atau pengelola Security.' using errcode = '42501'; end if;
  else raise exception 'Status harus dikembalikan atau batal.'; end if;
  if length(trim(coalesce(p_alasan, ''))) < 5 then raise exception 'Tuliskan alasan (minimal 5 huruf).'; end if;
  update parcels set status = p_status, diambil_pada = now(), diserahkan_oleh = public.saya(),
         pengambil_jenis = case when p_status = 'dikembalikan' then 'pengirim' end,
         pengambil_nama = case when p_status = 'dikembalikan' then pengirim end, foto_ambil_id = coalesce(p_foto, foto_ambil_id),
         catatan = trim(coalesce(catatan || E'\n', '') || case when p_status = 'batal' then 'Dibatalkan: ' else 'Dikembalikan: ' end || trim(p_alasan))
   where id = p_id;
  return public._titipan_json(p_id);
end $$;

/** cakupan: di_pos | semua (rentang tanggal diterima). Pengasuh hanya santri asuhannya. */
create or replace function public.daftar_titipan(p_cakupan text, p_mulai date default null, p_selesai date default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_semua boolean := public.boleh_lihat_security();
begin
  if public.saya() is null then return '[]'::jsonb; end if;
  return coalesce((select jsonb_agg(public._titipan_json(t.id) order by t.diterima_pada desc) from parcels t
    where (v_semua or t.student_id in (select public.santri_terlihat()))
      and case when p_cakupan = 'di_pos' then t.status = 'di_pos'
               else (t.diterima_pada at time zone 'Asia/Makassar')::date between coalesce(p_mulai, public.hari_ini() - 30) and coalesce(p_selesai, public.hari_ini()) end), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- 4. BUKU TAMU
-- ---------------------------------------------------------------------
create or replace function public._tamu_json(p_id uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', g.id, 'nama', g.nama, 'instansi', g.instansi, 'hp', g.hp, 'keperluan', g.keperluan,
    'ditemui_id', g.ditemui_id, 'ditemui', coalesce(e.nama_lengkap, g.ditemui_teks), 'jumlah_orang', g.jumlah_orang, 'kendaraan', g.kendaraan,
    'masuk_pada', g.masuk_pada, 'keluar_pada', g.keluar_pada, 'foto_id', g.foto_id, 'catatan', g.catatan,
    'petugas_masuk', e1.nama_lengkap, 'petugas_keluar', e2.nama_lengkap)
    from guest_logs g left join employees e on e.id = g.ditemui_id
    left join employees e1 on e1.id = g.petugas_masuk left join employees e2 on e2.id = g.petugas_keluar
   where g.id = p_id
$$;

create or replace function public.tamu_masuk(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid; v_ditemui uuid := nullif(p->>'ditemui_id', '')::uuid;
begin
  if not public.boleh_gerbang() then raise exception 'Hanya petugas Security yang dapat mencatat tamu.' using errcode = '42501'; end if;
  if length(trim(coalesce(p->>'nama', ''))) < 2 then raise exception 'Isi nama tamu.'; end if;
  if length(trim(coalesce(p->>'keperluan', ''))) < 3 then raise exception 'Isi keperluan tamu.'; end if;
  if v_ditemui is null and length(trim(coalesce(p->>'ditemui_teks', ''))) < 2 then raise exception 'Isi orang/bagian yang ditemui.'; end if;
  insert into guest_logs (nama, instansi, hp, keperluan, ditemui_id, ditemui_teks, jumlah_orang, kendaraan, foto_id, petugas_masuk, catatan)
  values (trim(p->>'nama'), nullif(trim(p->>'instansi'), ''), nullif(trim(p->>'hp'), ''), trim(p->>'keperluan'), v_ditemui,
          nullif(trim(p->>'ditemui_teks'), ''), greatest(1, coalesce((p->>'jumlah_orang')::int, 1)), nullif(trim(p->>'kendaraan'), ''),
          nullif(p->>'foto_id', '')::uuid, public.saya(), nullif(trim(p->>'catatan'), ''))
  returning id into v_id;
  if v_ditemui is not null and v_ditemui is distinct from public.saya() then
    insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
    values (v_ditemui, 'Tamu untuk Anda: ' || trim(p->>'nama'),
            coalesce(nullif(trim(p->>'instansi'), '') || ' · ', '') || trim(p->>'keperluan') || '. Tamu menunggu di pos Security.', '/security/tamu', 'Users', 'biru');
  end if;
  return public._tamu_json(v_id);
end $$;

create or replace function public.tamu_keluar(p_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
begin
  if not public.boleh_gerbang() then raise exception 'Hanya petugas Security yang dapat mencatat tamu.' using errcode = '42501'; end if;
  update guest_logs set keluar_pada = now(), petugas_keluar = public.saya() where id = p_id and keluar_pada is null;
  if not found then raise exception 'Tamu tidak ditemukan atau sudah tercatat keluar.'; end if;
  return public._tamu_json(p_id);
end $$;

/** cakupan: di_dalam | semua (rentang tanggal masuk). Pegawai yang ditemui melihat tamunya sendiri. */
create or replace function public.daftar_tamu(p_cakupan text, p_mulai date default null, p_selesai date default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_semua boolean := public.boleh_lihat_security();
begin
  if public.saya() is null then return '[]'::jsonb; end if;
  return coalesce((select jsonb_agg(public._tamu_json(g.id) order by g.masuk_pada desc) from guest_logs g
    where (v_semua or g.ditemui_id = public.saya())
      and case when p_cakupan = 'di_dalam' then g.keluar_pada is null
               else (g.masuk_pada at time zone 'Asia/Makassar')::date between coalesce(p_mulai, public.hari_ini() - 30) and coalesce(p_selesai, public.hari_ini()) end), '[]'::jsonb);
end $$;

/** Daftar pegawai aktif untuk kolom "orang yang ditemui" (nama dan jabatan saja). */
create or replace function public.pegawai_tujuan_tamu(p_q text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public.boleh_lihat_security() then raise exception 'Anda tidak berwenang.' using errcode = '42501'; end if;
  if length(trim(coalesce(p_q, ''))) < 2 then return '[]'::jsonb; end if;
  return coalesce((select jsonb_agg(x order by x->>'nama') from (
    select jsonb_build_object('id', e.id, 'nama', e.nama_lengkap,
      'jabatan', coalesce((select sp.nama || coalesce(' ' || o.nama, '') from employee_structurals es join structural_positions sp on sp.id = es.structural_position_id
                            left join org_units o on o.id = es.org_unit_id where es.employee_id = e.id),
                          (select string_agg(fp.nama, ', ' order by fp.urutan) from employee_functions f join functional_positions fp on fp.id = f.functional_position_id where f.employee_id = e.id))) x
      from employees e where e.status_keaktifan = 'aktif' and e.nama_lengkap ilike '%' || trim(p_q) || '%' limit 20) q), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- 5. KUNJUNGAN ORANG TUA
-- ---------------------------------------------------------------------
create or replace function public._kunjungan_json(p_id uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', v.id, 'student_id', v.student_id, 'nama', s.nama_lengkap, 'nis', s.nis, 'jenis_kelamin', s.jenis_kelamin,
    'kelas', public._kelompok_santri(s.id, 'kelas'), 'kamar', public._kelompok_santri(s.id, 'kamar'),
    'pengunjung', v.pengunjung, 'hubungan', v.hubungan, 'hp', v.hp, 'jumlah_orang', v.jumlah_orang,
    'datang_pada', v.datang_pada, 'pulang_pada', v.pulang_pada, 'luar_jadwal', v.luar_jadwal, 'foto_id', v.foto_id, 'catatan', v.catatan,
    'petugas_datang', e1.nama_lengkap, 'petugas_pulang', e2.nama_lengkap)
    from parent_visits v join students s on s.id = v.student_id
    left join employees e1 on e1.id = v.petugas_datang left join employees e2 on e2.id = v.petugas_pulang
   where v.id = p_id
$$;

create or replace function public._luar_jadwal_kunjungan(p_waktu timestamptz)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare a jsonb := public.pengaturan_security(); w timestamp := p_waktu at time zone 'Asia/Makassar';
begin
  if not coalesce((a->>'jadwal_kunjungan_aktif')::boolean, false) then return false; end if;
  return not ((a->'hari_kunjungan') @> to_jsonb(extract(dow from w)::int)
              and to_char(w, 'HH24:MI') between a->>'jam_kunjungan_mulai' and a->>'jam_kunjungan_selesai');
end $$;

create or replace function public.kunjungan_datang(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v_s record; v_id uuid; v_luar boolean := public._luar_jadwal_kunjungan(now());
begin
  if not public.boleh_gerbang() then raise exception 'Hanya petugas Security yang dapat mencatat kunjungan.' using errcode = '42501'; end if;
  select id, nama_lengkap, status into v_s from students where id = nullif(p->>'student_id', '')::uuid;
  if v_s.id is null then raise exception 'Pilih santri yang dikunjungi.'; end if;
  if v_s.status <> 'aktif' then raise exception '% tidak berstatus aktif.', v_s.nama_lengkap; end if;
  if length(trim(coalesce(p->>'pengunjung', ''))) < 2 then raise exception 'Isi nama pengunjung.'; end if;
  if exists (select 1 from parent_visits where student_id = v_s.id and pulang_pada is null) then
    raise exception '% masih tercatat sedang dikunjungi. Catat pulang kunjungan sebelumnya dahulu.', v_s.nama_lengkap;
  end if;
  insert into parent_visits (student_id, pengunjung, hubungan, hp, jumlah_orang, luar_jadwal, foto_id, petugas_datang, catatan)
  values (v_s.id, trim(p->>'pengunjung'), nullif(trim(p->>'hubungan'), ''), nullif(trim(p->>'hp'), ''),
          greatest(1, coalesce((p->>'jumlah_orang')::int, 1)), v_luar, nullif(p->>'foto_id', '')::uuid, public.saya(), nullif(trim(p->>'catatan'), ''))
  returning id into v_id;
  insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
  select x, 'Kunjungan untuk ' || v_s.nama_lengkap, trim(p->>'pengunjung') || coalesce(' (' || nullif(trim(p->>'hubungan'), '') || ')', '')
         || ' menunggu di ruang kunjungan. Mohon santri dipanggil.' || case when v_luar then ' Di luar jadwal kunjungan.' else '' end,
         '/security/kunjungan', 'Users', 'ungu'
    from public._musyrif_santri(v_s.id) x where x is distinct from public.saya();
  return public._kunjungan_json(v_id);
end $$;

create or replace function public.kunjungan_pulang(p_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
begin
  if not public.boleh_gerbang() then raise exception 'Hanya petugas Security yang dapat mencatat kunjungan.' using errcode = '42501'; end if;
  update parent_visits set pulang_pada = now(), petugas_pulang = public.saya() where id = p_id and pulang_pada is null;
  if not found then raise exception 'Kunjungan tidak ditemukan atau sudah tercatat pulang.'; end if;
  return public._kunjungan_json(p_id);
end $$;

create or replace function public.daftar_kunjungan(p_cakupan text, p_mulai date default null, p_selesai date default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_semua boolean := public.boleh_lihat_security();
begin
  if public.saya() is null then return '[]'::jsonb; end if;
  return coalesce((select jsonb_agg(public._kunjungan_json(v.id) order by v.datang_pada desc) from parent_visits v
    where (v_semua or v.student_id in (select public.santri_terlihat()))
      and case when p_cakupan = 'berlangsung' then v.pulang_pada is null
               else (v.datang_pada at time zone 'Asia/Makassar')::date between coalesce(p_mulai, public.hari_ini() - 30) and coalesce(p_selesai, public.hari_ini()) end), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- 6. PENGINGAT (terlambat kembali + titipan belum diambil) DAN BERANDA
-- ---------------------------------------------------------------------
create or replace function public.security_pengingat()
returns int language plpgsql volatile security definer set search_path = public as $$
declare r record; n int := 0; v_tol int := (public.pengaturan_security()->>'toleransi_terlambat_menit')::int;
        v_hari int := (public.pengaturan_security()->>'pengingat_titipan_hari')::int;
begin
  for r in select p.id, p.student_id, p.pengusul_id, p.kembali_batas, s.nama_lengkap,
                  coalesce(public._kelompok_santri(s.id, 'kamar'), '') kamar, coalesce(public._kelompok_santri(s.id, 'kelas'), '') kelas
             from student_permits p join students s on s.id = p.student_id
            where p.status = 'keluar' and p.terlambat_dikabari is null and now() > p.kembali_batas + make_interval(mins => v_tol)
  loop
    insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
    select distinct x, 'Terlambat kembali: ' || r.nama_lengkap,
           'Batas kembali ' || to_char(r.kembali_batas at time zone 'Asia/Makassar', 'DD/MM HH24.MI') || ' WITA'
           || case when r.kelas <> '' then ' · ' || r.kelas else '' end || case when r.kamar <> '' then ' · ' || r.kamar else '' end
           || '. Mohon hubungi wali santri.', '/izin-santri/aktif', 'Siren', 'merah'
      from (select r.pengusul_id x union select public._pengasuh_santri(r.student_id) union select public._pejabat_unit('KESANTRIAN', 30)) q
     where x is not null;
    update student_permits set terlambat_dikabari = now() where id = r.id; n := n + 1;
  end loop;
  for r in select t.id, t.student_id, t.uraian, t.diterima_pada, s.nama_lengkap from parcels t join students s on s.id = t.student_id
            where t.status = 'di_pos' and t.diingatkan is null and t.diterima_pada < now() - make_interval(days => v_hari)
  loop
    insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
    select distinct x, 'Titipan belum diambil: ' || r.nama_lengkap,
           r.uraian || ' · di pos sejak ' || to_char(r.diterima_pada at time zone 'Asia/Makassar', 'DD/MM HH24.MI') || ' WITA', '/security/titipan', 'Package', 'jingga'
      from (select public._musyrif_santri(r.student_id) x union select public._petugas_security()) q where x is not null;
    update parcels set diingatkan = now() where id = r.id; n := n + 1;
  end loop;
  return n;
end $$;
revoke execute on function public.security_pengingat() from public, anon, authenticated;

create or replace function public.ringkasan_security_beranda()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_hari date := public.hari_ini(); v_awal int := (public.pengaturan_security()->>'keluar_lebih_awal_menit')::int;
begin
  if public.saya() is null or not public.boleh_lihat_security() then return null; end if;
  return jsonb_build_object(
    'petugas', public.boleh_gerbang(),
    'siap', (select count(distinct p.student_id) from student_permits p where p.status = 'disetujui' and p.kembali_batas > now()
              and ((p.keluar_pada at time zone 'Asia/Makassar')::date <= v_hari or p.keluar_pada - make_interval(mins => v_awal) <= now())),
    'di_luar', (select count(*) from student_permits p where p.status = 'keluar'),
    'terlambat', (select count(*) from student_permits p where p.status = 'keluar' and now() > p.kembali_batas),
    'keluar_hari_ini', (select count(*) from gate_logs g where g.jenis = 'keluar' and (g.waktu at time zone 'Asia/Makassar')::date = v_hari),
    'kembali_hari_ini', (select count(*) from gate_logs g where g.jenis = 'kembali' and (g.waktu at time zone 'Asia/Makassar')::date = v_hari),
    'ditolak_hari_ini', (select count(*) from gate_logs g where g.jenis = 'ditolak' and (g.waktu at time zone 'Asia/Makassar')::date = v_hari),
    'titipan_di_pos', (select count(*) from parcels t where t.status = 'di_pos'),
    'titipan_lama', (select count(*) from parcels t where t.status = 'di_pos' and t.diterima_pada < now() - make_interval(days => (public.pengaturan_security()->>'pengingat_titipan_hari')::int)),
    'titipan_hari_ini', (select count(*) from parcels t where (t.diterima_pada at time zone 'Asia/Makassar')::date = v_hari),
    'diambil_hari_ini', (select count(*) from parcels t where t.status = 'diambil' and (t.diambil_pada at time zone 'Asia/Makassar')::date = v_hari),
    'tamu_di_dalam', (select count(*) from guest_logs g where g.keluar_pada is null),
    'tamu_hari_ini', (select count(*) from guest_logs g where (g.masuk_pada at time zone 'Asia/Makassar')::date = v_hari),
    'kunjungan_berlangsung', (select count(*) from parent_visits v where v.pulang_pada is null),
    'kunjungan_hari_ini', (select count(*) from parent_visits v where (v.datang_pada at time zone 'Asia/Makassar')::date = v_hari));
end $$;

-- ---------------------------------------------------------------------
-- 7. TEMPLATE WA
-- ---------------------------------------------------------------------
insert into public.wa_templates (kode, nama, isi, variabel, keterangan) values
  ('titipan_santri', 'Titipan santri ke wali',
   E'{salam}, Bapak/Ibu {nama_wali}.\n\nKami informasikan titipan untuk ananda *{nama_santri}* ({kelas}) {status_titipan}.\n• Barang: {barang}\n• Pengirim: {pengirim_titipan}\n• Diterima di pos: {waktu_terima}\n{pengambilan}\n\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
   '{nama_wali,nama_santri,kelas,status_titipan,barang,pengirim_titipan,waktu_terima,pengambilan,pengirim}', 'Security: kabari orang tua/wali bahwa titipan diterima atau sudah diambil santri.')
on conflict (kode) do nothing;


-- ---------------------------------------------------------------------
-- 8. HAK LIHAT FOTO (Edge Function "berkas")
-- ---------------------------------------------------------------------
create or replace function public.boleh_lihat_berkas(p_obj uuid, p_emp uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r leave_requests; v_peran text; j journal_entries;
  izin boolean := false; v_sub text;
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
  -- (perbaikan Fase 7: alias "j" bentrok dengan variabel j sehingga fungsi galat untuk semua foto yang sampai di sini)
  if exists (select 1 from extracurricular_journals ej join student_attendance_sessions sa on sa.id = ej.session_id
             where ej.foto_id = p_obj and (v_peran = 'admin'
               or p_emp in (select employee_id from group_keepers where group_id = sa.group_id)
               or public.tingkat_fitur_pegawai(p_emp, 'absensi_ekskul') >= 1)) then
    return true;
  end if;
  -- Foto Lapor ke Bidang dan Jurnal Musyrif (perbaikan Fase 6): diperiksa dengan hak pegawai yang meminta
  -- (pelapor, penerima laporan, pimpinan; pengasuh/pimpinan kamar), memakai fungsi hak yang sama dengan aplikasi.
  if exists (select 1 from incident_reports ir where ir.foto_id = p_obj) or exists (select 1 from dorm_journals dj where dj.foto_id = p_obj) then
    v_sub := current_setting('request.jwt.claim.sub', true);
    perform set_config('request.jwt.claim.sub', coalesce((select user_id::text from employees where id = p_emp), ''), true);
    izin := exists (select 1 from incident_reports ir where ir.foto_id = p_obj and (ir.pelapor_id = p_emp or public.boleh_tangani_lapor(ir.unit_kode)))
         or exists (select 1 from dorm_journals dj where dj.foto_id = p_obj and public.boleh_lihat_kamar(dj.group_id));
    perform set_config('request.jwt.claim.sub', coalesce(v_sub, ''), true);
    if izin then return true; end if;
  end if;
  -- Foto titipan, tamu, kunjungan (Fase 7 Tahap 2): admin, petugas Security, pemegang hak pantauan, pengasuh santri terkait
  if exists (select 1 from parcels pc where pc.foto_terima_id = p_obj or pc.foto_ambil_id = p_obj)
     or exists (select 1 from guest_logs gt where gt.foto_id = p_obj) or exists (select 1 from parent_visits pv where pv.foto_id = p_obj) then
    if v_peran = 'admin' or public.tingkat_fitur_pegawai(p_emp, 'gerbang') >= 1 or public.tingkat_fitur_pegawai(p_emp, 'pantauan') >= 1
       or exists (select 1 from parcels pc where (pc.foto_terima_id = p_obj or pc.foto_ambil_id = p_obj) and p_emp in (select public._pengasuh_santri(pc.student_id)))
       or exists (select 1 from parent_visits pv where pv.foto_id = p_obj and p_emp in (select public._pengasuh_santri(pv.student_id)))
       or exists (select 1 from guest_logs gt where gt.foto_id = p_obj and gt.ditemui_id = p_emp) then
      return true;
    end if;
  end if;
  -- Foto gerbang Security (Fase 7): petugas gerbang, pemegang hak pantauan, dan admin
  if exists (select 1 from gate_logs gl where gl.foto_id = p_obj) and (v_peran = 'admin'
       or public.tingkat_fitur_pegawai(p_emp, 'gerbang') >= 1 or public.tingkat_fitur_pegawai(p_emp, 'pantauan') >= 1) then
    return true;
  end if;
  return false;
end $function$;
revoke execute on function public.boleh_lihat_berkas(uuid,uuid) from public, anon, authenticated;
grant execute on function public.boleh_lihat_berkas(uuid,uuid) to service_role;

-- ---------------------------------------------------------------------
-- 9. HAK EKSEKUSI
-- ---------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array['pengaturan_security()','simpan_pengaturan_security(jsonb)','hak_security()','terima_titipan(jsonb)','ambil_titipan(uuid,jsonb)',
    'tutup_titipan(uuid,text,text,uuid)','daftar_titipan(text,date,date)','tamu_masuk(jsonb)','tamu_keluar(uuid)','daftar_tamu(text,date,date)',
    'pegawai_tujuan_tamu(text)','kunjungan_datang(jsonb)','kunjungan_pulang(uuid)','daftar_kunjungan(text,date,date)','ringkasan_security_beranda()'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['_musyrif_santri(uuid)','_titipan_json(uuid)','_tamu_json(uuid)','_kunjungan_json(uuid)','_luar_jadwal_kunjungan(timestamptz)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN (hasil yang benar: semua baris "Sesuai")
-- ---------------------------------------------------------------------
select '1. Tabel titipan, buku tamu, kunjungan' as pemeriksaan,
       case when to_regclass('public.parcels') is not null and to_regclass('public.guest_logs') is not null and to_regclass('public.parent_visits') is not null then 'Sesuai' else 'Periksa' end as hasil
union all select '2. Fungsi titipan (terima, ambil, tutup, daftar)', case when (select count(*) from pg_proc where proname in ('terima_titipan','ambil_titipan','tutup_titipan','daftar_titipan')) = 4 then 'Sesuai' else 'Periksa' end
union all select '3. Fungsi buku tamu dan kunjungan', case when (select count(*) from pg_proc where proname in ('tamu_masuk','tamu_keluar','daftar_tamu','kunjungan_datang','kunjungan_pulang','daftar_kunjungan')) = 6 then 'Sesuai' else 'Periksa' end
union all select '4. Ketentuan kunjungan dan pengingat titipan', case when public.pengaturan_security() ? 'jadwal_kunjungan_aktif' and public.pengaturan_security() ? 'pengingat_titipan_hari' then 'Sesuai' else 'Periksa' end
union all select '5. Template WA titipan_santri', case when exists (select 1 from wa_templates where kode = 'titipan_santri') then 'Sesuai' else 'Periksa' end
union all select '6. Hak lihat foto titipan/tamu/kunjungan', case when pg_get_functiondef('public.boleh_lihat_berkas'::regproc) like '%parent_visits%' then 'Sesuai' else 'Periksa' end
union all select '7. Pengingat Security masih terjadwal', case when exists (select 1 from cron.job where jobname = 'pengingat-security') then 'Sesuai' else 'Periksa' end;
