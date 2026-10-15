-- SIMKA PRO | supabase/migrations/20261017009700_portal_wali_dasar.sql | v1.0 | Fase 9 – Tahap 13.0.0 Fondasi Portal Wali | 15/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 9 · Migrasi 97: Fondasi Portal Wali Santri (Blueprint Bagian 26)
--   * Pengaturan `portal_wali` (institution_settings): sakelar buka/tutup portal, cara masuk, lama sesi,
--     batas salah masuk, dan BUTIR INFORMASI yang dapat dinyalakan/dimatikan superadmin.
--     Butir sensitif (riwayat sakit, keuangan) bawaan NONAKTIF.
--   * guardian_sessions       : sesi wali per anak (kunci sesi acak; database hanya menyimpan sidik SHA-256)
--   * guardian_login_attempts : catatan percobaan masuk (dasar penguncian 5 kali salah → 15 menit)
--   * portal_masuk / portal_keluar / portal_data : SATU-SATUNYA pintu portal (dapat dipanggil tanpa login pegawai);
--     portal_data hanya mengembalikan data santri pemilik sesi dan hanya butir yang dinyalakan.
--   * Pengelolaan (superadmin, admin ber-izin kelola_santri): ringkasan, kesiapan data, sesi aktif, buka kunci, cabut sesi.
--   * Sesi wali otomatis gugur bila nomor HP kontak, NIS/NISN, tanggal lahir, atau status santri berubah.
-- Wali TIDAK dibuatkan akun Supabase Auth (tidak tercampur akun pegawai, hemat kuota paket gratis).
-- Jalankan SETELAH migrasi 9600. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. PENGATURAN BAWAAN
-- ---------------------------------------------------------------------
insert into public.institution_settings (kunci, nilai, publik) values ('portal_wali', jsonb_build_object(
  'aktif', false,
  'identitas', 'nis_nisn',
  'lama_sesi_hari', 30,
  'maks_salah', 5,
  'kunci_menit', 15,
  'pesan_tutup', 'Portal Wali belum dibuka. Silakan hubungi pengasuh atau Tata Usaha pondok.',
  'butir', jsonb_build_object(
    'profil', true, 'pengasuh', true, 'kehadiran', true, 'perizinan', true, 'kunjungan', true, 'titipan', true,
    'sakit', false, 'hafalan', true, 'ujian', true, 'nilai', true, 'prestasi', true, 'dokumen', true,
    'keuangan', false, 'pengumuman', true)
), false)
on conflict (kunci) do nothing;

/** Pengaturan portal digabung dengan nilai bawaan (butir baru otomatis memakai bawaannya). */
create or replace function public._portal_set()
returns jsonb language sql stable security definer set search_path = public as $$
  with b as (select jsonb_build_object(
      'aktif', false, 'identitas', 'nis_nisn', 'lama_sesi_hari', 30, 'maks_salah', 5, 'kunci_menit', 15,
      'pesan_tutup', 'Portal Wali belum dibuka. Silakan hubungi pengasuh atau Tata Usaha pondok.',
      'butir', jsonb_build_object(
        'profil', true, 'pengasuh', true, 'kehadiran', true, 'perizinan', true, 'kunjungan', true, 'titipan', true,
        'sakit', false, 'hafalan', true, 'ujian', true, 'nilai', true, 'prestasi', true, 'dokumen', true,
        'keuangan', false, 'pengumuman', true)) as v),
  s as (select coalesce((select nilai from institution_settings where kunci = 'portal_wali'), '{}'::jsonb) as v)
  select (b.v || (s.v - 'butir')) || jsonb_build_object('butir', (b.v->'butir') || coalesce(s.v->'butir', '{}'::jsonb))
    from b, s
$$;

/** Butir informasi aktif? */
create or replace function public._portal_butir(p_set jsonb, p_kode text)
returns boolean language sql immutable as $$
  select coalesce((p_set->'butir'->>p_kode)::boolean, false)
$$;

-- ---------------------------------------------------------------------
-- 2. TABEL
-- ---------------------------------------------------------------------
create table if not exists public.guardian_sessions (
  id              uuid primary key default gen_random_uuid(),
  student_id      uuid not null references public.students(id) on delete cascade,
  token_hash      text not null unique,
  hubungan        text,                  -- kontak yang cocok saat masuk: ayah, ibu, wali
  perangkat       text,
  dibuat          timestamptz not null default now(),
  terakhir        timestamptz not null default now(),
  kedaluwarsa     timestamptz not null,
  dicabut_pada    timestamptz,
  dicabut_alasan  text
);
create index if not exists guardian_sessions_santri_idx on public.guardian_sessions (student_id) where dicabut_pada is null;
create index if not exists guardian_sessions_terakhir_idx on public.guardian_sessions (terakhir desc);

create table if not exists public.guardian_login_attempts (
  id          bigserial primary key,
  kunci       text not null,             -- NIS/NISN yang diketik (angka saja)
  student_id  uuid references public.students(id) on delete set null,
  ip          text,
  berhasil    boolean not null,
  alasan      text,
  waktu       timestamptz not null default now()
);
create index if not exists guardian_login_attempts_kunci_idx on public.guardian_login_attempts (kunci, waktu desc);
create index if not exists guardian_login_attempts_ip_idx on public.guardian_login_attempts (ip, waktu desc);
create index if not exists guardian_login_attempts_waktu_idx on public.guardian_login_attempts (waktu);

-- Kedua tabel hanya dibaca/ditulis lewat fungsi (tanpa kebijakan = tertutup bagi anon dan authenticated)
alter table public.guardian_sessions enable row level security;
alter table public.guardian_login_attempts enable row level security;
revoke all on public.guardian_sessions, public.guardian_login_attempts from anon, authenticated;

-- ---------------------------------------------------------------------
-- 3. PEMBANTU
-- ---------------------------------------------------------------------
create or replace function public._portal_sidik(p_token text)
returns text language sql immutable as $$
  select encode(extensions.digest(convert_to(coalesce(p_token, ''), 'UTF8'), 'sha256'), 'hex')
$$;

create or replace function public._portal_ip()
returns text language plpgsql stable as $$
declare h text;
begin
  begin
    h := current_setting('request.headers', true)::json->>'x-forwarded-for';
  exception when others then h := null; end;
  return nullif(trim(split_part(coalesce(h, ''), ',', 1)), '');
end $$;

/** Hanya angka (nomor HP, NIS, NISN). */
create or replace function public._angka(p text)
returns text language sql immutable as $$ select regexp_replace(coalesce(p, ''), '\D', '', 'g') $$;

/** Cabut semua sesi aktif santri (opsional hanya kontak tertentu). */
create or replace function public._cabut_sesi_wali(p_santri uuid, p_alasan text, p_hubungan text default null)
returns int language plpgsql volatile security definer set search_path = public as $$
declare n int;
begin
  update guardian_sessions set dicabut_pada = now(), dicabut_alasan = left(p_alasan, 200)
   where student_id = p_santri and dicabut_pada is null and (p_hubungan is null or hubungan = p_hubungan);
  get diagnostics n = row_count;
  return n;
end $$;

/** Sesi wali yang sah (null bila tidak sah). Waktu "terakhir" diperbarui paling sering 5 menit sekali (hemat tulis). */
create or replace function public._portal_sesi(p_token text)
returns public.guardian_sessions language plpgsql volatile security definer set search_path = public as $$
declare gs guardian_sessions;
begin
  if coalesce(length(p_token), 0) < 32 then return null; end if;
  select x.* into gs from guardian_sessions x
   where x.token_hash = public._portal_sidik(p_token) and x.dicabut_pada is null and x.kedaluwarsa > now();
  if gs.id is null then return null; end if;
  if not exists (select 1 from students s where s.id = gs.student_id and s.status = 'aktif') then return null; end if;
  if gs.terakhir < now() - interval '5 minutes' then
    update guardian_sessions set terakhir = now() where id = gs.id;
  end if;
  return gs;
end $$;

-- Sesi gugur otomatis bila data penentu masuk berubah
create or replace function public.tg_cabut_sesi_wali_kontak()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if TG_OP = 'DELETE' then
    perform public._cabut_sesi_wali(old.student_id, 'Kontak ' || old.hubungan || ' dihapus', old.hubungan);
    return old;
  end if;
  if public._angka(old.no_hp) is distinct from public._angka(new.no_hp) then
    perform public._cabut_sesi_wali(new.student_id, 'Nomor HP ' || new.hubungan || ' diubah', new.hubungan);
  end if;
  return new;
end $$;
drop trigger if exists zz_cabut_sesi_wali on public.student_contacts;
create trigger zz_cabut_sesi_wali after update of no_hp or delete on public.student_contacts
  for each row execute function public.tg_cabut_sesi_wali_kontak();

create or replace function public.tg_cabut_sesi_wali_santri()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if old.nis is distinct from new.nis or old.nisn is distinct from new.nisn
     or old.tanggal_lahir is distinct from new.tanggal_lahir or (old.status = 'aktif' and new.status <> 'aktif') then
    perform public._cabut_sesi_wali(new.id, 'Data masuk santri atau status santri berubah');
  end if;
  return new;
end $$;
drop trigger if exists zz_cabut_sesi_wali on public.students;
create trigger zz_cabut_sesi_wali after update of nis, nisn, tanggal_lahir, status on public.students
  for each row execute function public.tg_cabut_sesi_wali_santri();

-- ---------------------------------------------------------------------
-- 4. MASUK DAN KELUAR (dapat dipanggil tanpa login pegawai)
-- ---------------------------------------------------------------------
-- Tidak memakai RAISE untuk galat masuk agar catatan percobaan gagal tetap tersimpan (dasar penguncian).
create or replace function public.portal_masuk(p_identitas text, p_tanggal_lahir date, p_hp text, p_perangkat text default null)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare
  v_set jsonb := public._portal_set();
  k text := public._angka(p_identitas);
  hp text := public._angka(p_hp);
  v_ip text := public._portal_ip();
  v_maks int; v_menit int; v_hari int;
  v_reset timestamptz; v_gagal int; v_akhir timestamptz; v_ip_gagal int;
  v_sid uuid; v_hub text; v_token text; v_sisa int;
  s students;
  GALAT_DATA constant text := 'Data tidak cocok. Periksa kembali NIS/NISN, tanggal lahir, dan 6 digit terakhir nomor HP.';
begin
  if not coalesce((v_set->>'aktif')::boolean, false) then
    return jsonb_build_object('ok', false, 'kode', 'TUTUP', 'galat', v_set->>'pesan_tutup');
  end if;
  v_maks := greatest(3, least(10, coalesce((v_set->>'maks_salah')::int, 5)));
  v_menit := greatest(5, least(120, coalesce((v_set->>'kunci_menit')::int, 15)));
  v_hari := greatest(1, least(180, coalesce((v_set->>'lama_sesi_hari')::int, 30)));

  if length(k) not in (7, 10) or (v_set->>'identitas' = 'nisn' and length(k) <> 10) then
    return jsonb_build_object('ok', false, 'kode', 'FORMAT', 'galat',
      case when v_set->>'identitas' = 'nisn' then 'NISN terdiri atas 10 angka.' else 'Isi NIS (7 angka) atau NISN (10 angka).' end);
  end if;
  if length(hp) <> 6 then return jsonb_build_object('ok', false, 'kode', 'FORMAT', 'galat', 'Isi 6 digit terakhir nomor HP.'); end if;
  if p_tanggal_lahir is null then return jsonb_build_object('ok', false, 'kode', 'FORMAT', 'galat', 'Isi tanggal lahir santri.'); end if;

  -- Santri dicari lebih dulu; kunci penghitung salah memakai NIS santri itu (NIS dan NISN dihitung bersama)
  select x.* into s from students x
   where x.status = 'aktif' and (x.nisn = k or (v_set->>'identitas' <> 'nisn' and x.nis = k)) limit 1;
  if s.id is not null then k := s.nis; end if;

  -- Penguncian: berturut-turut salah sejak masuk berhasil/buka kunci terakhir
  select max(a.waktu) into v_reset from guardian_login_attempts a where a.kunci = k and a.berhasil;
  select count(*), max(a.waktu) into v_gagal, v_akhir from guardian_login_attempts a
   where a.kunci = k and not a.berhasil and a.waktu > coalesce(v_reset, '-infinity'::timestamptz);
  if v_gagal >= v_maks and v_akhir > now() - make_interval(mins => v_menit) then
    return jsonb_build_object('ok', false, 'kode', 'KUNCI', 'sampai', v_akhir + make_interval(mins => v_menit),
      'galat', format('Terlalu banyak percobaan salah. Coba lagi setelah %s menit, atau minta pengasuh membuka kunci.',
                      ceil(extract(epoch from (v_akhir + make_interval(mins => v_menit) - now())) / 60)::int));
  end if;
  if v_ip is not null then
    select count(*) into v_ip_gagal from guardian_login_attempts a
     where a.ip = v_ip and not a.berhasil and a.waktu > now() - interval '15 minutes';
    if v_ip_gagal >= 30 then
      return jsonb_build_object('ok', false, 'kode', 'KUNCI', 'galat', 'Terlalu banyak percobaan dari jaringan ini. Coba lagi 15 menit lagi.');
    end if;
  end if;

  if s.id is not null and s.tanggal_lahir = p_tanggal_lahir then
    select c.hubungan into v_hub from student_contacts c
     where c.student_id = s.id and right(public._angka(c.no_hp), 6) = hp and length(public._angka(c.no_hp)) >= 9
     order by c.utama desc, array_position(array['ayah','ibu','wali'], c.hubungan) limit 1;
    if v_hub is not null then v_sid := s.id; end if;
  end if;

  if v_sid is null then
    insert into guardian_login_attempts (kunci, student_id, ip, berhasil, alasan)
    values (k, s.id, v_ip, false, case when s.id is null then 'identitas' when s.tanggal_lahir is distinct from p_tanggal_lahir then 'tanggal_lahir' else 'hp' end);
    v_sisa := v_maks - (v_gagal + 1);
    return jsonb_build_object('ok', false, 'kode', 'SALAH', 'sisa', greatest(v_sisa, 0),
      'galat', GALAT_DATA || case when v_sisa > 0 then format(' Sisa %s kali percobaan.', v_sisa)
                                  else format(' Portal dikunci %s menit.', v_menit) end);
  end if;

  -- Berhasil
  v_token := encode(extensions.gen_random_bytes(32), 'hex');
  insert into guardian_sessions (student_id, token_hash, hubungan, perangkat, kedaluwarsa)
  values (v_sid, public._portal_sidik(v_token), v_hub, left(nullif(trim(coalesce(p_perangkat, '')), ''), 120), now() + make_interval(days => v_hari));
  insert into guardian_login_attempts (kunci, student_id, ip, berhasil, alasan) values (k, v_sid, v_ip, true, 'masuk');
  -- Paling banyak 10 sesi aktif per santri (yang terlama dicabut)
  update guardian_sessions set dicabut_pada = now(), dicabut_alasan = 'Melebihi 10 perangkat'
   where id in (select g.id from guardian_sessions g where g.student_id = v_sid and g.dicabut_pada is null
                 order by g.terakhir desc offset 10);
  -- Bersih-bersih ringan: catatan percobaan > 90 hari dan sesi kedaluwarsa/dicabut > 90 hari
  delete from guardian_login_attempts where waktu < now() - interval '90 days';
  delete from guardian_sessions where coalesce(dicabut_pada, kedaluwarsa) < now() - interval '90 days';

  return jsonb_build_object('ok', true, 'token', v_token, 'kedaluwarsa', now() + make_interval(days => v_hari),
    'santri', jsonb_build_object('nis', s.nis, 'nama', s.nama_lengkap, 'panggilan', s.nama_panggilan, 'jk', s.jenis_kelamin,
                                 'kelas', public._kelas_santri(s.id)),
    'hubungan', v_hub);
end $$;

create or replace function public.portal_keluar(p_token text)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
begin
  update guardian_sessions set dicabut_pada = now(), dicabut_alasan = 'Keluar dari perangkat'
   where token_hash = public._portal_sidik(p_token) and dicabut_pada is null;
  return jsonb_build_object('ok', true);
end $$;

-- ---------------------------------------------------------------------
-- 5. DATA PORTAL
-- ---------------------------------------------------------------------
/** Beranda: identitas anak, pengasuh, dan kegiatan hari ini (hanya butir yang dinyalakan). */
create or replace function public._portal_beranda(p_santri uuid, p_set jsonb, p_hubungan text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare s students; v_ta uuid; v_hari date := public.hari_ini(); hasil jsonb; v_wali text;
begin
  select x.* into s from students x where x.id = p_santri;
  select id into v_ta from academic_years where aktif limit 1;
  select c.nama into v_wali from student_contacts c where c.student_id = p_santri and c.hubungan = p_hubungan;
  hasil := jsonb_build_object(
    'butir', p_set->'butir',
    'lembaga', (select coalesce(nilai->>'nama_lengkap', nilai->>'nama') from institution_settings where kunci = 'identitas'),
    'tanggal', v_hari,
    'wali', jsonb_build_object('hubungan', p_hubungan, 'nama', v_wali),
    'santri', jsonb_build_object(
      'nis', s.nis, 'nama', s.nama_lengkap, 'panggilan', s.nama_panggilan, 'jk', s.jenis_kelamin,
      'jenjang', s.jenjang, 'tingkat', s.tingkat,
      'kelas', public._kelompok_santri(s.id, 'kelas'),
      'kamar', case when public._portal_butir(p_set, 'profil') then public._kelompok_santri(s.id, 'kamar') end,
      'halaqah', case when public._portal_butir(p_set, 'profil') then public._kelompok_santri(s.id, 'halaqah') end,
      'ekskul', case when public._portal_butir(p_set, 'profil') then public._kelompok_santri(s.id, 'ekskul') end,
      'program', case when public._portal_butir(p_set, 'hafalan') then (select program from student_tahfizh where student_id = s.id) end,
      'tempat_lahir', case when public._portal_butir(p_set, 'profil') then s.tempat_lahir end,
      'tanggal_lahir', case when public._portal_butir(p_set, 'profil') then s.tanggal_lahir end,
      'tahun_masuk', s.tahun_masuk));

  if public._portal_butir(p_set, 'pengasuh') then
    hasil := hasil || jsonb_build_object('pengasuh', coalesce((
      select jsonb_agg(jsonb_build_object('tugas', x.tugas, 'nama', x.nama, 'kelompok', x.kelompok) order by x.urut, x.kelompok)
      from (
        select distinct on (g.id)
               case g.jenis when 'kelas' then 'Wali kelas'
                            when 'kamar' then case when e.jenis_kelamin = 'P' then 'Musyrifah' else 'Musyrif' end
                            when 'halaqah' then case when e.jenis_kelamin = 'P' then 'Muhaffizhah' else 'Muhaffizh' end
                            else 'Pembina ekskul' end as tugas,
               e.nama_lengkap as nama, g.nama as kelompok,
               array_position(array['kelas','halaqah','kamar','ekskul'], g.jenis) as urut
          from group_members m
          join student_groups g on g.id = m.group_id and g.aktif and g.academic_year_id = v_ta and g.jenis in ('kelas','kamar','halaqah','ekskul')
          join group_keepers k on k.group_id = g.id and (k.mulai is null or k.mulai <= v_hari) and (k.sampai is null or k.sampai >= v_hari)
          join employees e on e.id = k.employee_id
         where m.student_id = p_santri and m.selesai is null
         order by g.id, array_position(array['utama','pendamping','pengganti'], k.peran)
      ) x), '[]'::jsonb));
  end if;

  if public._portal_butir(p_set, 'kehadiran') then
    hasil := hasil || jsonb_build_object('hari_ini', coalesce((
      select jsonb_agg(jsonb_build_object('jenis', sa.jenis, 'kelompok', g.nama, 'sesi', sa.nama_sesi,
                                          'jam', to_char(sa.jam_mulai, 'HH24.MI'), 'kode', coalesce(e.kode, 'H'))
                       order by sa.jam_mulai nulls last, sa.nama_sesi)
        from student_attendance_sessions sa
        join group_members m on m.group_id = sa.group_id and m.student_id = p_santri
             and m.mulai <= sa.tanggal and (m.selesai is null or m.selesai >= sa.tanggal)
        join student_groups g on g.id = sa.group_id
        left join student_attendance_exceptions e on e.session_id = sa.id and e.student_id = p_santri
       where sa.tanggal = v_hari), '[]'::jsonb));
  end if;
  return hasil;
end $$;

/**
 * Pintu tunggal data portal. p_bagian: 'beranda' (Tahap 13.0.0; bagian lain menyusul).
 * Hasil khusus: {sesi_berakhir:true} bila kunci sesi tidak sah/kedaluwarsa/dicabut; {tutup:true} bila portal ditutup;
 * {nonaktif:true} bila butir dimatikan superadmin.
 */
create or replace function public.portal_data(p_token text, p_bagian text, p jsonb default '{}'::jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v_set jsonb := public._portal_set(); gs guardian_sessions;
begin
  if not coalesce((v_set->>'aktif')::boolean, false) then
    return jsonb_build_object('tutup', true, 'pesan', v_set->>'pesan_tutup');
  end if;
  gs := public._portal_sesi(p_token);
  if gs.id is null then return jsonb_build_object('sesi_berakhir', true); end if;
  case coalesce(p_bagian, '')
    when 'beranda' then return public._portal_beranda(gs.student_id, v_set, gs.hubungan);
    else return jsonb_build_object('galat', 'Bagian portal tidak dikenal.');
  end case;
end $$;

-- ---------------------------------------------------------------------
-- 6. PENGELOLAAN (superadmin; admin ber-izin kelola_santri)
-- ---------------------------------------------------------------------
create or replace function public._boleh_portal()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_superadmin() or public.admin_boleh('kelola_santri')
$$;

create or replace function public._wajib_boleh_portal()
returns void language plpgsql stable security definer set search_path = public as $$
begin
  if not public._boleh_portal() then
    raise exception 'Hanya superadmin atau admin ber-izin Kelola santri yang dapat mengelola Portal Wali.' using errcode = '42501';
  end if;
end $$;

create or replace function public.pengaturan_portal_wali()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public._wajib_boleh_portal();
  return public._portal_set() || jsonb_build_object('boleh_ubah', public.is_superadmin());
end $$;

create or replace function public.simpan_pengaturan_portal_wali(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare lama jsonb := public._portal_set(); baru jsonb; b jsonb := '{}'::jsonb; kk text;
begin
  if not public.is_superadmin() then raise exception 'Hanya superadmin yang dapat mengubah pengaturan Portal Wali.' using errcode = '42501'; end if;
  for kk in select jsonb_object_keys(lama->'butir') loop
    b := b || jsonb_build_object(kk, coalesce((p->'butir'->>kk)::boolean, (lama->'butir'->>kk)::boolean, false));
  end loop;
  baru := jsonb_build_object(
    'aktif', coalesce((p->>'aktif')::boolean, (lama->>'aktif')::boolean, false),
    'identitas', case when coalesce(p->>'identitas', lama->>'identitas') = 'nisn' then 'nisn' else 'nis_nisn' end,
    'lama_sesi_hari', greatest(1, least(180, coalesce((p->>'lama_sesi_hari')::int, (lama->>'lama_sesi_hari')::int, 30))),
    'maks_salah', greatest(3, least(10, coalesce((p->>'maks_salah')::int, (lama->>'maks_salah')::int, 5))),
    'kunci_menit', greatest(5, least(120, coalesce((p->>'kunci_menit')::int, (lama->>'kunci_menit')::int, 15))),
    'pesan_tutup', left(coalesce(nullif(trim(p->>'pesan_tutup'), ''), lama->>'pesan_tutup'), 300),
    'butir', b);
  insert into institution_settings (kunci, nilai, updated_by) values ('portal_wali', baru, public.saya())
  on conflict (kunci) do update set nilai = excluded.nilai, updated_by = excluded.updated_by;
  return baru || jsonb_build_object('boleh_ubah', true);
end $$;

/** Ringkasan kesiapan dan pemakaian portal. */
create or replace function public.ringkasan_portal_wali()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare hasil jsonb; v_set jsonb := public._portal_set(); v_maks int; v_menit int;
begin
  perform public._wajib_boleh_portal();
  v_maks := coalesce((v_set->>'maks_salah')::int, 5); v_menit := coalesce((v_set->>'kunci_menit')::int, 15);
  with a as (
    select s.id, s.nisn, s.tanggal_lahir,
           exists (select 1 from student_contacts c where c.student_id = s.id and length(public._angka(c.no_hp)) >= 9) as ada_hp
      from students s where s.status = 'aktif')
  select jsonb_build_object(
    'aktif', coalesce((v_set->>'aktif')::boolean, false),
    'santri', count(*),
    'tanpa_nisn', count(*) filter (where nisn is null),
    'tanpa_tgl', count(*) filter (where tanggal_lahir is null),
    'tanpa_hp', count(*) filter (where not ada_hp),
    'siap', count(*) filter (where tanggal_lahir is not null and ada_hp and (v_set->>'identitas' <> 'nisn' or nisn is not null)))
    into hasil from a;
  hasil := hasil || jsonb_build_object(
    'sesi_aktif', (select count(*) from guardian_sessions where dicabut_pada is null and kedaluwarsa > now()),
    'santri_bersesi', (select count(distinct student_id) from guardian_sessions where dicabut_pada is null and kedaluwarsa > now()),
    'masuk_7_hari', (select count(*) from guardian_login_attempts where berhasil and alasan = 'masuk' and waktu > now() - interval '7 days'),
    'gagal_24_jam', (select count(*) from guardian_login_attempts where not berhasil and waktu > now() - interval '24 hours'),
    'dibuka_7_hari', (select count(distinct student_id) from guardian_sessions where terakhir > now() - interval '7 days'));
  return hasil;
end $$;

/** Santri aktif yang datanya belum lengkap untuk masuk portal. */
create or replace function public.kesiapan_portal_wali()
returns table (id uuid, nis text, nisn text, nama text, jk text, kelas text, kurang text[])
language plpgsql stable security definer set search_path = public as $$
declare v_set jsonb := public._portal_set();
begin
  perform public._wajib_boleh_portal();
  return query
  select s.id, s.nis, s.nisn, s.nama_lengkap, s.jenis_kelamin, public._kelas_santri(s.id),
         array_remove(array[
           case when s.nisn is null and v_set->>'identitas' = 'nisn' then 'NISN' end,
           case when s.tanggal_lahir is null then 'Tanggal lahir' end,
           case when not exists (select 1 from student_contacts c where c.student_id = s.id and length(public._angka(c.no_hp)) >= 9)
                then 'Nomor HP orang tua/wali' end], null)
    from students s
   where s.status = 'aktif'
     and (s.tanggal_lahir is null or (s.nisn is null and v_set->>'identitas' = 'nisn')
          or not exists (select 1 from student_contacts c where c.student_id = s.id and length(public._angka(c.no_hp)) >= 9))
   order by public._kelas_santri(s.id) nulls last, s.nama_lengkap;
end $$;

/** Sesi wali yang sedang aktif. */
create or replace function public.sesi_portal_wali()
returns table (id uuid, student_id uuid, nis text, nama text, kelas text, hubungan text, nama_wali text,
               perangkat text, dibuat timestamptz, terakhir timestamptz, kedaluwarsa timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public._wajib_boleh_portal();
  return query
  select g.id, s.id, s.nis, s.nama_lengkap, public._kelas_santri(s.id), g.hubungan,
         (select c.nama from student_contacts c where c.student_id = s.id and c.hubungan = g.hubungan),
         g.perangkat, g.dibuat, g.terakhir, g.kedaluwarsa
    from guardian_sessions g join students s on s.id = g.student_id
   where g.dicabut_pada is null and g.kedaluwarsa > now()
   order by g.terakhir desc limit 1000;
end $$;

/** Percobaan masuk gagal 7 hari terakhir per NIS/NISN, dengan status terkunci. */
create or replace function public.kunci_portal_wali()
returns table (kunci text, nis text, nama text, gagal bigint, terakhir timestamptz, terkunci_sampai timestamptz, alasan text)
language plpgsql stable security definer set search_path = public as $$
declare v_set jsonb := public._portal_set(); v_maks int; v_menit int;
begin
  perform public._wajib_boleh_portal();
  v_maks := coalesce((v_set->>'maks_salah')::int, 5); v_menit := coalesce((v_set->>'kunci_menit')::int, 15);
  return query
  with r as (select a.kunci as k, max(a.waktu) as t from guardian_login_attempts a where a.berhasil group by a.kunci),
  f as (
    select a.kunci as k, count(*) as n, max(a.waktu) as t,
           (array_agg(a.alasan order by a.waktu desc))[1] as al,
           (array_agg(a.student_id order by a.waktu desc) filter (where a.student_id is not null))[1] as sid
      from guardian_login_attempts a left join r on r.k = a.kunci
     where not a.berhasil and a.waktu > coalesce(r.t, '-infinity'::timestamptz) and a.waktu > now() - interval '7 days'
     group by a.kunci)
  select f.k, s.nis, s.nama_lengkap, f.n, f.t,
         case when f.n >= v_maks and f.t + make_interval(mins => v_menit) > now() then f.t + make_interval(mins => v_menit) end,
         case f.al when 'identitas' then 'NIS/NISN tidak ditemukan' when 'tanggal_lahir' then 'Tanggal lahir tidak cocok'
                   when 'hp' then 'Nomor HP tidak cocok' else f.al end
    from f left join students s on s.id = f.sid
   order by f.t desc limit 500;
end $$;

create or replace function public.buka_kunci_wali(p_kunci text)
returns void language plpgsql volatile security definer set search_path = public as $$
declare k text := public._angka(p_kunci);
begin
  perform public._wajib_boleh_portal();
  if length(k) = 0 then raise exception 'NIS/NISN kosong.'; end if;
  insert into guardian_login_attempts (kunci, ip, berhasil, alasan) values (k, null, true, 'dibuka pengelola');
  perform public.catat_audit('buka_kunci_wali', 'guardian_login_attempts', k, 'Membuka kunci Portal Wali untuk ' || k, null);
end $$;

/** Cabut sesi: satu sesi (p_sesi), semua sesi seorang santri (p_santri), atau semua sesi (keduanya kosong; superadmin). */
create or replace function public.cabut_sesi_wali(p_sesi uuid default null, p_santri uuid default null, p_alasan text default null)
returns int language plpgsql volatile security definer set search_path = public as $$
declare n int; v_alasan text := coalesce(nullif(trim(p_alasan), ''), 'Dicabut pengelola');
begin
  perform public._wajib_boleh_portal();
  if p_sesi is null and p_santri is null and not public.is_superadmin() then
    raise exception 'Mencabut semua sesi hanya dapat dilakukan superadmin.' using errcode = '42501';
  end if;
  update guardian_sessions set dicabut_pada = now(), dicabut_alasan = left(v_alasan, 200)
   where dicabut_pada is null and (p_sesi is null or id = p_sesi) and (p_santri is null or student_id = p_santri);
  get diagnostics n = row_count;
  perform public.catat_audit('cabut_sesi_wali', 'guardian_sessions', coalesce(p_sesi, p_santri)::text,
    'Mencabut ' || n || ' sesi Portal Wali: ' || v_alasan, null);
  return n;
end $$;

-- ---------------------------------------------------------------------
-- 7. HAK EKSEKUSI
-- ---------------------------------------------------------------------
do $$ declare f text; begin
  -- Pembantu internal: tertutup bagi aplikasi
  foreach f in array array['_portal_set()','_portal_butir(jsonb,text)','_portal_sidik(text)','_portal_ip()',
                           '_cabut_sesi_wali(uuid,text,text)','_portal_sesi(text)','_portal_beranda(uuid,jsonb,text)',
                           '_boleh_portal()','_wajib_boleh_portal()'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
  -- Pintu portal: dapat dipanggil tanpa login pegawai
  foreach f in array array['portal_masuk(text,date,text,text)','portal_keluar(text)','portal_data(text,text,jsonb)'] loop
    execute format('revoke execute on function public.%s from public', f);
    execute format('grant execute on function public.%s to anon, authenticated', f);
  end loop;
  -- Pengelolaan: pegawai yang masuk (hak diperiksa di dalam fungsi)
  foreach f in array array['pengaturan_portal_wali()','simpan_pengaturan_portal_wali(jsonb)','ringkasan_portal_wali()',
                           'kesiapan_portal_wali()','sesi_portal_wali()','kunci_portal_wali()','buka_kunci_wali(text)',
                           'cabut_sesi_wali(uuid,uuid,text)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
grant execute on function public._angka(text) to authenticated;

-- PEMERIKSAAN — hasil yang benar: 5 baris "Sesuai"
select '1. Pengaturan portal_wali (sakit dan keuangan bawaan nonaktif)' as pemeriksaan,
       case when (select nilai->'butir'->>'sakit' from institution_settings where kunci = 'portal_wali') = 'false'
             and (select nilai->'butir'->>'keuangan' from institution_settings where kunci = 'portal_wali') = 'false'
            then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Tabel sesi dan percobaan masuk wali (RLS aktif)',
       case when (select count(*) from pg_class where relname in ('guardian_sessions','guardian_login_attempts') and relrowsecurity) = 2
            then 'Sesuai' else 'Periksa' end
union all
select '3. Pintu portal dapat dipanggil tanpa login',
       case when has_function_privilege('anon', 'public.portal_masuk(text,date,text,text)', 'execute')
             and has_function_privilege('anon', 'public.portal_data(text,text,jsonb)', 'execute')
             and not has_function_privilege('anon', 'public.ringkasan_portal_wali()', 'execute')
            then 'Sesuai' else 'Periksa' end
union all
select '4. Fungsi pengelolaan portal lengkap',
       case when (select count(*) from pg_proc where pronamespace = 'public'::regnamespace and proname in
             ('pengaturan_portal_wali','simpan_pengaturan_portal_wali','ringkasan_portal_wali','kesiapan_portal_wali',
              'sesi_portal_wali','kunci_portal_wali','buka_kunci_wali','cabut_sesi_wali')) = 8 then 'Sesuai' else 'Periksa' end
union all
select '5. Pemicu sesi gugur saat data masuk berubah',
       case when (select count(*) from pg_trigger where tgname = 'zz_cabut_sesi_wali') = 2 then 'Sesuai' else 'Periksa' end;
