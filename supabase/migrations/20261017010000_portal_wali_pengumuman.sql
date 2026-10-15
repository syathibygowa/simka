-- SIMKA PRO | supabase/migrations/20261017010000_portal_wali_pengumuman.sql | v1.0 | Fase 9 – Tahap 13.3.0 Pengumuman untuk wali dan notifikasi HP wali | 15/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 9 · Migrasi 100: Pengumuman untuk wali santri (Blueprint Bagian 26–27)
--   * guardian_announcements        : pengumuman khusus wali (terpisah dari pengumuman pegawai)
--   * guardian_announcement_targets : daftar penerima per santri (disimpan saat terbit) + tanda dibaca (oleh ayah/ibu/wali)
--   * Pengirim: admin, superadmin, pemegang hak fitur Pengumuman tingkat 2+, dan pimpinan (Kepala Bidang ke atas).
--   * Sasaran: semua santri aktif, jenjang, tingkat kelas, kelompok (kelas/kamar/halaqah/ekskul), putra/putri, santri tertentu.
--   * Notifikasi HP wali (web push): langganan per sesi wali (guardian_push_subscriptions); antrian guardian_push_queue
--     dikirim oleh Edge Function "dorong" YANG SUDAH ADA (fungsi SQL _dorong_ambil/_dorong_selesai diperluas;
--     Edge Function TIDAK perlu dipasang ulang).
--   * Portal: bagian 'pengumuman' (butir Pengumuman untuk wali), portal_baca_pengumuman, langganan/hapus notifikasi HP.
-- Jalankan SETELAH migrasi 9900. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TABEL
-- ---------------------------------------------------------------------
create table if not exists public.guardian_announcements (
  id                uuid primary key default gen_random_uuid(),
  judul             text not null check (length(trim(judul)) between 3 and 150),
  isi               text not null check (length(trim(isi)) >= 3),
  penting           boolean not null default false,
  sasaran           jsonb not null default '{"jenis":"semua"}'::jsonb,
  ringkasan_sasaran text,
  tampil_sampai     date,
  tautan            text,
  nama_tautan       text,
  dibuat_oleh       uuid references public.employees(id) on delete set null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index if not exists guardian_announcements_waktu_idx on public.guardian_announcements (created_at desc);

create table if not exists public.guardian_announcement_targets (
  announcement_id  uuid not null references public.guardian_announcements(id) on delete cascade,
  student_id       uuid not null references public.students(id) on delete cascade,
  dibaca_pada      timestamptz,
  dibaca_hubungan  text,
  primary key (announcement_id, student_id)
);
create index if not exists guardian_announcement_targets_santri_idx on public.guardian_announcement_targets (student_id);

create table if not exists public.guardian_push_subscriptions (
  id          uuid primary key default gen_random_uuid(),
  session_id  uuid not null references public.guardian_sessions(id) on delete cascade,
  student_id  uuid not null references public.students(id) on delete cascade,
  endpoint    text not null,
  p256dh      text not null,
  auth        text not null,
  perangkat   text,
  created_at  timestamptz not null default now(),
  terakhir_ok timestamptz,
  unique (session_id, endpoint)
);
create index if not exists guardian_push_subscriptions_santri_idx on public.guardian_push_subscriptions (student_id);

create table if not exists public.guardian_push_queue (
  id          bigint generated always as identity primary key,
  endpoint    text not null,
  p256dh      text not null,
  auth        text not null,
  judul       text not null,
  isi         text,
  tautan      text,
  ref_id      uuid not null,
  penting     boolean not null default false,
  percobaan   int not null default 0,
  created_at  timestamptz not null default now()
);

alter table public.guardian_announcements enable row level security;
alter table public.guardian_announcement_targets enable row level security;
alter table public.guardian_push_subscriptions enable row level security;
alter table public.guardian_push_queue enable row level security;
revoke all on public.guardian_announcements, public.guardian_announcement_targets,
              public.guardian_push_subscriptions, public.guardian_push_queue from anon, authenticated;

drop trigger if exists aa_updated on public.guardian_announcements;
create trigger aa_updated before update on public.guardian_announcements for each row execute function public.tg_updated_at();
drop trigger if exists zz_audit on public.guardian_announcements;
create trigger zz_audit after insert or update or delete on public.guardian_announcements for each row execute function public.tg_audit();

-- ---------------------------------------------------------------------
-- 2. HAK DAN SASARAN
-- ---------------------------------------------------------------------
create or replace function public.boleh_umumkan_wali()
returns boolean language sql stable security definer set search_path = public as $$
  select public.boleh_umumkan() or exists (select 1 from public.unit_pimpinan_saya())
$$;

create or replace function public._wajib_umumkan_wali()
returns void language plpgsql stable security definer set search_path = public as $$
begin
  if not public.boleh_umumkan_wali() then
    raise exception 'Pengumuman untuk wali dibuat oleh admin, superadmin, pemegang hak Pengumuman, atau pimpinan.' using errcode = '42501';
  end if;
end $$;

/**
 * Santri aktif yang menjadi sasaran. p = {jenis:'semua'|'pilihan', jenjang:[], tingkat:[], kelompok:[uuid], santri:[uuid], jk:'L'|'P'}
 * Pada jenis 'pilihan': jenjang, tingkat, kelompok, dan santri tertentu digabung (salah satu cocok); jk menyaring semuanya.
 */
create or replace function public._penerima_wali(p jsonb)
returns setof uuid language sql stable security definer set search_path = public as $$
  select s.id from students s
   where s.status = 'aktif'
     and (nullif(p->>'jk', '') is null or s.jenis_kelamin = p->>'jk')
     and (coalesce(p->>'jenis', 'pilihan') = 'semua'
          or s.jenjang in (select jsonb_array_elements_text(coalesce(p->'jenjang', '[]')))
          or s.tingkat::text in (select jsonb_array_elements_text(coalesce(p->'tingkat', '[]')))
          or s.id::text in (select jsonb_array_elements_text(coalesce(p->'santri', '[]')))
          or exists (select 1 from group_members m where m.student_id = s.id and m.selesai is null
                       and m.group_id::text in (select jsonb_array_elements_text(coalesce(p->'kelompok', '[]')))))
$$;

create or replace function public._ringkas_sasaran_wali(p jsonb)
returns text language plpgsql stable security definer set search_path = public as $$
declare bagian text[] := '{}'; v text;
begin
  if coalesce(p->>'jenis', 'pilihan') = 'semua' then
    bagian := bagian || 'Semua wali santri'::text;
  else
    select string_agg(case x when 'wustha' then 'Kesetaraan Wustha' when 'sma' then 'SMA' else x end, ', ') into v
      from jsonb_array_elements_text(coalesce(p->'jenjang', '[]')) x;
    if v is not null then bagian := bagian || v; end if;
    select string_agg('kelas ' || x, ', ' order by x::int) into v from jsonb_array_elements_text(coalesce(p->'tingkat', '[]')) x;
    if v is not null then bagian := bagian || v; end if;
    select string_agg(g.nama, ', ' order by g.jenis, g.nama) into v from student_groups g
     where g.id::text in (select jsonb_array_elements_text(coalesce(p->'kelompok', '[]')));
    if v is not null then bagian := bagian || v; end if;
    if jsonb_array_length(coalesce(p->'santri', '[]')) > 0 then
      bagian := bagian || (jsonb_array_length(p->'santri') || ' santri tertentu');
    end if;
  end if;
  if nullif(p->>'jk', '') is not null then bagian := bagian || (case p->>'jk' when 'L' then 'putra saja' else 'putri saja' end)::text; end if;
  return coalesce(nullif(array_to_string(bagian, '; '), ''), 'Semua wali santri');
end $$;

create or replace function public.hitung_sasaran_wali(p jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public._wajib_umumkan_wali();
  return jsonb_build_object(
    'santri', (select count(*) from public._penerima_wali(p)),
    'bersesi', (select count(distinct g.student_id) from guardian_sessions g
                 where g.dicabut_pada is null and g.kedaluwarsa > now() and g.student_id in (select public._penerima_wali(p))),
    'ringkasan', public._ringkas_sasaran_wali(p));
end $$;

/** Pilihan sasaran: kelompok aktif (kelas, kamar, halaqah, ekskul) beserta jumlah anggota, dan jumlah per jenjang/tingkat. */
create or replace function public.pilihan_sasaran_wali()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public._wajib_umumkan_wali();
  return jsonb_build_object(
    'kelompok', coalesce((select jsonb_agg(jsonb_build_object('id', g.id, 'jenis', g.jenis, 'nama', g.nama, 'jk', g.jenis_kelamin,
                           'jumlah', (select count(*) from group_members m join students s on s.id = m.student_id and s.status = 'aktif'
                                       where m.group_id = g.id and m.selesai is null))
                         order by array_position(array['kelas','kamar','halaqah','ekskul'], g.jenis), g.tingkat nulls last, g.nama)
                         from student_groups g join academic_years a on a.id = g.academic_year_id and a.aktif
                        where g.aktif and g.jenis in ('kelas','kamar','halaqah','ekskul')), '[]'::jsonb),
    'tingkat', coalesce((select jsonb_object_agg(t, n) from (select tingkat::text t, count(*) n from students where status = 'aktif' group by tingkat) x), '{}'::jsonb));
end $$;

/** Cari santri aktif untuk sasaran "santri tertentu". */
create or replace function public.cari_santri_wali(p_cari text)
returns table (id uuid, nis text, nama text, jk text, kelas text)
language plpgsql stable security definer set search_path = public as $$
declare q text := lower(trim(coalesce(p_cari, '')));
begin
  perform public._wajib_umumkan_wali();
  if length(q) < 2 then return; end if;
  return query select s.id, s.nis, s.nama_lengkap, s.jenis_kelamin, public._kelas_santri(s.id)
    from students s where s.status = 'aktif' and (lower(s.nama_lengkap) like '%' || q || '%' or s.nis like q || '%' or coalesce(s.nisn, '') like q || '%')
   order by s.nama_lengkap limit 20;
end $$;

-- ---------------------------------------------------------------------
-- 3. KELOLA PENGUMUMAN WALI
-- ---------------------------------------------------------------------
create or replace function public.simpan_pengumuman_wali(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid := nullif(p->>'id', '')::uuid; v_jumlah int; v_penting boolean := coalesce((p->>'penting')::boolean, false);
        v_sasaran jsonb := coalesce(p->'sasaran', '{"jenis":"semua"}'::jsonb); v_tautan text := nullif(trim(coalesce(p->>'tautan', '')), '');
begin
  perform public._wajib_umumkan_wali();
  if length(trim(coalesce(p->>'judul', ''))) < 3 then raise exception 'Judul pengumuman minimal 3 karakter.'; end if;
  if length(trim(coalesce(p->>'isi', ''))) < 3 then raise exception 'Isi pengumuman belum diisi.'; end if;
  if v_tautan is not null and v_tautan !~ '^https?://' then raise exception 'Tautan harus diawali https:// atau http://'; end if;

  if v_id is not null then
    update guardian_announcements set judul = trim(p->>'judul'), isi = trim(p->>'isi'), penting = v_penting,
           tampil_sampai = nullif(p->>'tampil_sampai', '')::date, tautan = v_tautan, nama_tautan = nullif(trim(coalesce(p->>'nama_tautan', '')), '')
     where id = v_id;
    if not found then raise exception 'Pengumuman tidak ditemukan.'; end if;
    return v_id;
  end if;

  insert into guardian_announcements (judul, isi, penting, sasaran, ringkasan_sasaran, tampil_sampai, tautan, nama_tautan, dibuat_oleh)
  values (trim(p->>'judul'), trim(p->>'isi'), v_penting, v_sasaran, public._ringkas_sasaran_wali(v_sasaran),
          nullif(p->>'tampil_sampai', '')::date, v_tautan, nullif(trim(coalesce(p->>'nama_tautan', '')), ''), public.saya())
  returning id into v_id;

  insert into guardian_announcement_targets (announcement_id, student_id)
  select v_id, x from public._penerima_wali(v_sasaran) x on conflict do nothing;
  get diagnostics v_jumlah = row_count;
  if v_jumlah = 0 then raise exception 'Sasaran yang dipilih tidak memiliki santri aktif. Ubah sasaran pengumuman.'; end if;

  -- Notifikasi HP ke perangkat wali yang berlangganan (sesi masih berlaku)
  insert into guardian_push_queue (endpoint, p256dh, auth, judul, isi, tautan, ref_id, penting)
  select distinct on (sp.endpoint) sp.endpoint, sp.p256dh, sp.auth,
         case when v_penting then 'Pengumuman penting: ' else 'Pengumuman pondok: ' end || trim(p->>'judul'),
         left(regexp_replace(regexp_replace(trim(p->>'isi'), '[*_]', '', 'g'), '\s+', ' ', 'g'), 140), '/wali/pengumuman', v_id, v_penting
    from guardian_push_subscriptions sp
    join guardian_sessions gs on gs.id = sp.session_id and gs.dicabut_pada is null and gs.kedaluwarsa > now()
   where sp.student_id in (select t.student_id from guardian_announcement_targets t where t.announcement_id = v_id);
  get diagnostics v_jumlah = row_count;
  if v_jumlah > 0 then perform public._panggil_dorong(); end if;
  return v_id;
end $$;

create or replace function public.daftar_pengumuman_wali()
returns table (id uuid, judul text, isi text, penting boolean, sasaran jsonb, ringkasan_sasaran text, tampil_sampai date, tautan text, nama_tautan text,
               created_at timestamptz, pembuat text, penerima int, sudah_dibaca int)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public._wajib_umumkan_wali();
  return query select a.id, a.judul, a.isi, a.penting, a.sasaran, a.ringkasan_sasaran, a.tampil_sampai, a.tautan, a.nama_tautan, a.created_at,
         e.nama_lengkap,
         (select count(*)::int from guardian_announcement_targets t where t.announcement_id = a.id),
         (select count(*)::int from guardian_announcement_targets t where t.announcement_id = a.id and t.dibaca_pada is not null)
    from guardian_announcements a left join employees e on e.id = a.dibuat_oleh
   order by a.created_at desc limit 300;
end $$;

create or replace function public.pembaca_pengumuman_wali(p_id uuid)
returns table (student_id uuid, nis text, nama text, jk text, kelas text, dibaca_pada timestamptz, dibaca_hubungan text, bersesi boolean, no_hp text, nama_wali text)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public._wajib_umumkan_wali();
  return query select s.id, s.nis, s.nama_lengkap, s.jenis_kelamin, public._kelas_santri(s.id), t.dibaca_pada, t.dibaca_hubungan,
         exists (select 1 from guardian_sessions g where g.student_id = s.id and g.dicabut_pada is null and g.kedaluwarsa > now()),
         (select c.no_hp from student_contacts c where c.student_id = s.id and c.no_hp is not null order by c.utama desc limit 1),
         (select c.nama from student_contacts c where c.student_id = s.id and c.no_hp is not null order by c.utama desc limit 1)
    from guardian_announcement_targets t join students s on s.id = t.student_id
   where t.announcement_id = p_id
   order by public._kelas_santri(s.id) nulls last, s.nama_lengkap;
end $$;

create or replace function public.hapus_pengumuman_wali(p_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  perform public._wajib_umumkan_wali();
  delete from guardian_push_queue where ref_id = p_id;
  delete from guardian_announcements where id = p_id;
end $$;

-- ---------------------------------------------------------------------
-- 4. PORTAL: DAFTAR, TANDA DIBACA, NOTIFIKASI HP
-- ---------------------------------------------------------------------
create or replace function public._portal_pengumuman(p_santri uuid, p_set jsonb, p jsonb)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('pengumuman', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'judul', a.judul, 'isi', a.isi, 'penting', a.penting,
            'tautan', a.tautan, 'nama_tautan', a.nama_tautan, 'created_at', a.created_at, 'dibaca_pada', t.dibaca_pada,
            'pengirim', (select coalesce(sp.nama, 'Pengelola') from employee_structurals es join structural_positions sp on sp.id = es.structural_position_id
                          where es.employee_id = a.dibuat_oleh limit 1))
          order by (a.penting and t.dibaca_pada is null) desc, a.created_at desc)
     from guardian_announcement_targets t join guardian_announcements a on a.id = t.announcement_id
    where t.student_id = p_santri and (a.tampil_sampai is null or a.tampil_sampai >= public.hari_ini())), '[]'::jsonb))
$$;

create or replace function public.portal_baca_pengumuman(p_token text, p_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare gs guardian_sessions;
begin
  gs := public._portal_sesi(p_token);
  if gs.id is null then return jsonb_build_object('sesi_berakhir', true); end if;
  update guardian_announcement_targets set dibaca_pada = now(), dibaca_hubungan = gs.hubungan
   where announcement_id = p_id and student_id = gs.student_id and dibaca_pada is null;
  return jsonb_build_object('ok', true);
end $$;

/** Kunci publik VAPID untuk langganan notifikasi HP wali (boleh diketahui siapa saja). */
create or replace function public.portal_kunci_dorong()
returns text language sql stable security definer set search_path = public, privat as $$
  select nilai->>'publik' from privat.rahasia where kunci = 'vapid'
$$;

create or replace function public.portal_daftar_dorong(p_token text, p_endpoint text, p_p256dh text, p_auth text, p_perangkat text default null)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare gs guardian_sessions;
begin
  gs := public._portal_sesi(p_token);
  if gs.id is null then return jsonb_build_object('sesi_berakhir', true); end if;
  if coalesce(p_endpoint, '') !~ '^https://' or length(coalesce(p_p256dh, '')) < 20 or length(coalesce(p_auth, '')) < 8 then
    return jsonb_build_object('galat', 'Alamat langganan notifikasi tidak sah.');
  end if;
  insert into guardian_push_subscriptions (session_id, student_id, endpoint, p256dh, auth, perangkat)
  values (gs.id, gs.student_id, p_endpoint, p_p256dh, p_auth, left(p_perangkat, 120))
  on conflict (session_id, endpoint) do update set p256dh = excluded.p256dh, auth = excluded.auth, perangkat = excluded.perangkat, created_at = now();
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.portal_hapus_dorong(p_token text, p_endpoint text)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare gs guardian_sessions;
begin
  gs := public._portal_sesi(p_token);
  if gs.id is null then return jsonb_build_object('sesi_berakhir', true); end if;
  delete from guardian_push_subscriptions where session_id = gs.id and (p_endpoint is null or endpoint = p_endpoint);
  return jsonb_build_object('ok', true);
end $$;

/** Status notifikasi HP untuk sesi ini. */
create or replace function public.portal_status_dorong(p_token text, p_endpoint text)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare gs guardian_sessions;
begin
  gs := public._portal_sesi(p_token);
  if gs.id is null then return jsonb_build_object('sesi_berakhir', true); end if;
  return jsonb_build_object('aktif', exists (select 1 from guardian_push_subscriptions where session_id = gs.id and endpoint = p_endpoint));
end $$;

-- ---------------------------------------------------------------------
-- 5. EDGE FUNCTION "dorong" (tanpa pasang ulang): antrian wali ikut diambil.
--    Baris wali memakai nomor antrian NEGATIF agar dapat dibedakan saat _dorong_selesai.
-- ---------------------------------------------------------------------
create or replace function public._dorong_ambil(p_batas integer default 300)
returns table (antrian_id bigint, endpoint text, p256dh text, auth text, judul text, isi text, tautan text, notif_id uuid, penting boolean)
language plpgsql security definer set search_path = public as $$
begin
  return query
  with ambil as (
    update push_queue q set percobaan = q.percobaan + 1
     where q.id in (select x.id from push_queue x where x.percobaan < 3 order by x.id limit p_batas for update skip locked)
    returning q.id, q.notification_id
  )
  select a.id, s.endpoint, s.p256dh, s.auth, n.judul, n.isi, n.tautan, n.id, n.warna = 'merah'
    from ambil a join notifications n on n.id = a.notification_id
    join push_subscriptions s on s.employee_id = n.employee_id;

  return query
  with ambil as (
    update guardian_push_queue q set percobaan = q.percobaan + 1
     where q.id in (select x.id from guardian_push_queue x where x.percobaan < 3 order by x.id limit p_batas for update skip locked)
    returning q.*
  )
  select -a.id, a.endpoint, a.p256dh, a.auth, a.judul, a.isi, a.tautan, a.ref_id, a.penting from ambil a;
end $$;

create or replace function public._dorong_selesai(p_antrian bigint[], p_ok text[], p_hilang text[])
returns void language sql security definer set search_path = public as $$
  delete from push_queue where id = any (p_antrian);
  delete from guardian_push_queue where -id = any (p_antrian);
  update push_subscriptions set terakhir_ok = now() where endpoint = any (p_ok);
  update guardian_push_subscriptions set terakhir_ok = now() where endpoint = any (p_ok);
  delete from push_subscriptions where endpoint = any (p_hilang);
  delete from guardian_push_subscriptions where endpoint = any (p_hilang);
  -- Antrian wali yang gagal 3 kali dibuang
  delete from guardian_push_queue where percobaan >= 3;
$$;

-- ---------------------------------------------------------------------
-- 6. PINTU PORTAL (13.3.0) dan beranda (jumlah pengumuman belum dibaca)
-- ---------------------------------------------------------------------
create or replace function public.portal_data(p_token text, p_bagian text, p jsonb default '{}'::jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v_set jsonb := public._portal_set(); gs guardian_sessions; v_butir text; hasil jsonb;
begin
  if not coalesce((v_set->>'aktif')::boolean, false) then
    return jsonb_build_object('tutup', true, 'pesan', v_set->>'pesan_tutup');
  end if;
  gs := public._portal_sesi(p_token);
  if gs.id is null then return jsonb_build_object('sesi_berakhir', true); end if;
  v_butir := case when p_bagian in ('kehadiran','perizinan','kunjungan','titipan','sakit','hafalan','ujian','nilai','prestasi','keuangan','pengumuman')
                  then p_bagian end;
  if v_butir is not null and not public._portal_butir(v_set, v_butir) then
    return jsonb_build_object('nonaktif', true, 'butir', v_set->'butir');
  end if;
  p := coalesce(p, '{}'::jsonb);
  case coalesce(p_bagian, '')
    when 'beranda' then
      hasil := public._portal_beranda(gs.student_id, v_set, gs.hubungan);
      if public._portal_butir(v_set, 'pengumuman') then
        hasil := hasil || jsonb_build_object('pengumuman_baru', (
          select count(*) from guardian_announcement_targets t join guardian_announcements a on a.id = t.announcement_id
           where t.student_id = gs.student_id and t.dibaca_pada is null and (a.tampil_sampai is null or a.tampil_sampai >= public.hari_ini())));
      end if;
      return hasil;
    when 'kehadiran'  then return public._portal_kehadiran(gs.student_id, v_set, p);
    when 'perizinan'  then return public._portal_perizinan(gs.student_id, v_set, p);
    when 'kunjungan'  then return public._portal_kunjungan(gs.student_id, v_set, p);
    when 'titipan'    then return public._portal_titipan(gs.student_id, v_set, p);
    when 'sakit'      then return public._portal_sakit(gs.student_id, v_set, p);
    when 'hafalan'    then return public._portal_hafalan(gs.student_id, v_set, p);
    when 'ujian'      then return public._portal_ujian(gs.student_id, v_set, p);
    when 'nilai'      then return public._portal_nilai(gs.student_id, v_set, p);
    when 'prestasi'   then return public._portal_prestasi(gs.student_id, v_set, p);
    when 'keuangan'   then return public._portal_keuangan(gs.student_id, v_set, p);
    when 'pengumuman' then return public._portal_pengumuman(gs.student_id, v_set, p);
    else return jsonb_build_object('galat', 'Bagian portal tidak dikenal.');
  end case;
end $$;

-- ---------------------------------------------------------------------
-- 7. HAK EKSEKUSI
-- ---------------------------------------------------------------------
do $$ declare f text; begin
  foreach f in array array['_wajib_umumkan_wali()','_penerima_wali(jsonb)','_ringkas_sasaran_wali(jsonb)','_portal_pengumuman(uuid,jsonb,jsonb)',
                           '_dorong_ambil(integer)','_dorong_selesai(bigint[],text[],text[])'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
  foreach f in array array['portal_data(text,text,jsonb)','portal_baca_pengumuman(text,uuid)','portal_kunci_dorong()',
                           'portal_daftar_dorong(text,text,text,text,text)','portal_hapus_dorong(text,text)','portal_status_dorong(text,text)'] loop
    execute format('revoke execute on function public.%s from public', f);
    execute format('grant execute on function public.%s to anon, authenticated', f);
  end loop;
  foreach f in array array['boleh_umumkan_wali()','hitung_sasaran_wali(jsonb)','pilihan_sasaran_wali()','cari_santri_wali(text)',
                           'simpan_pengumuman_wali(jsonb)','daftar_pengumuman_wali()','pembaca_pengumuman_wali(uuid)','hapus_pengumuman_wali(uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  -- Edge Function "dorong" memanggil dengan service_role
  execute 'grant execute on function public._dorong_ambil(integer) to service_role';
  execute 'grant execute on function public._dorong_selesai(bigint[],text[],text[]) to service_role';
end $$;

-- PEMERIKSAAN — hasil yang benar: 4 baris "Sesuai"
select '1. Tabel pengumuman wali dan notifikasi HP wali (RLS aktif)' as pemeriksaan,
       case when (select count(*) from pg_class where relname in ('guardian_announcements','guardian_announcement_targets',
             'guardian_push_subscriptions','guardian_push_queue') and relrowsecurity) = 4 then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Fungsi kelola pengumuman wali lengkap',
       case when (select count(*) from pg_proc where pronamespace = 'public'::regnamespace and proname in
             ('simpan_pengumuman_wali','daftar_pengumuman_wali','pembaca_pengumuman_wali','hapus_pengumuman_wali','hitung_sasaran_wali','pilihan_sasaran_wali','cari_santri_wali')) = 7
            then 'Sesuai' else 'Periksa' end
union all
select '3. Portal: baca pengumuman dan langganan notifikasi HP tanpa login pegawai',
       case when has_function_privilege('anon', 'public.portal_baca_pengumuman(text,uuid)', 'execute')
             and has_function_privilege('anon', 'public.portal_daftar_dorong(text,text,text,text,text)', 'execute')
             and not has_function_privilege('anon', 'public.simpan_pengumuman_wali(jsonb)', 'execute') then 'Sesuai' else 'Periksa' end
union all
select '4. Antrian notifikasi HP wali ikut dikirim fungsi dorong',
       case when position('guardian_push_queue' in (select prosrc from pg_proc where proname = '_dorong_ambil')) > 0 then 'Sesuai' else 'Periksa' end;
