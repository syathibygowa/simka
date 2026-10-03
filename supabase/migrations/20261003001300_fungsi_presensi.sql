-- SIMKA PRO | supabase/migrations/20261003001300_fungsi_presensi.sql | v1.0 | Fase 2 – Tahap 1 Fungsi presensi | 03/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 2 · Migrasi 13: Fungsi inti presensi
--   A. Pengaturan dan bantu (jarak, libur, titik terdekat)
--   B. Jadwal pegawai (gabungan pola semua tugas) + sinkron dari jabatan
--   C. Rencana presensi (sesi yang sedang terbuka untuk datang/pulang)
--   D. Periksa lokasi (RPC pegawai) dan catat presensi (khusus Edge Function)
--   E. Deteksi kecurigaan, riwayat status, ringkasan harian, penutupan sesi
-- Semua waktu dari server (now()), zona Asia/Makassar (WITA).
-- =====================================================================

-- ---------------------------------------------------------------------
-- A. PENGATURAN DAN FUNGSI BANTU
-- ---------------------------------------------------------------------
create or replace function public.pengaturan_presensi()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
      'mulai_tanggal', null,                 -- penutupan otomatis berjalan mulai tanggal ini
      'jeda_minimal_pulang_menit', 15,       -- presensi pulang minimal X menit setelah datang
      'batas_akurasi_m', 100,                -- akurasi GPS lebih buruk dari ini ditandai
      'berlaku_cek_detik', 180,              -- cek lokasi berlaku 3 menit
      'retensi_selfie_hari', 183,            -- selfie dihapus setelah ±6 bulan
      'folder_selfie', 'SIMKA PRO/Presensi',
      'pengingat_menit', 10)
    || coalesce((select nilai from institution_settings where kunci = 'presensi'), '{}'::jsonb)
$$;

-- Jarak dua koordinat dalam meter (haversine)
create or replace function public.jarak_meter(lat1 double precision, lng1 double precision,
                                              lat2 double precision, lng2 double precision)
returns double precision language sql immutable as $$
  select 2 * 6371000 * asin(sqrt(
           power(sin(radians(lat2 - lat1) / 2), 2) +
           cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2)))
$$;

-- Apakah tanggal ini libur bagi kalender tugas tertentu (Ahad, libur bulanan, dsb.)
create or replace function public.libur_tugas(p_tanggal date, p_kalender text)
returns boolean language sql stable security definer set search_path = public as $$
  select (p_kalender is not null and exists (
            select 1 from holiday_calendars hc
             where hc.jenis_tugas = p_kalender
               and extract(dow from p_tanggal)::smallint = any(hc.hari_libur)))
      or exists (
            select 1 from holidays h
             where p_tanggal between h.tanggal_mulai and h.tanggal_akhir
               and ('semua' = any(h.berlaku_untuk) or (p_kalender is not null and p_kalender = any(h.berlaku_untuk))))
$$;

-- Titik terdekat: utamakan titik yang radiusnya memuat posisi, lalu yang terdekat
create or replace function public.titik_terdekat(p_lat double precision, p_lng double precision)
returns table (titik_id uuid, nama text, radius_m int, jarak_m int, di_area boolean)
language sql stable security definer set search_path = public as $$
  select g.id, g.nama, g.radius_m, round(x.j)::int, x.j <= g.radius_m
    from gps_points g
    cross join lateral (select public.jarak_meter(p_lat, p_lng, g.lat, g.lng) as j) x
   where g.aktif
   order by (x.j <= g.radius_m) desc, x.j
   limit 1
$$;

-- ---------------------------------------------------------------------
-- B. JADWAL PEGAWAI
-- ---------------------------------------------------------------------
-- Jadwal satu pegawai pada satu tanggal = gabungan sesi semua pola aktifnya.
--   * pola shift: hanya sesi yang dijadwalkan di shift_rosters pada tanggal itu;
--   * pola lain : sesuai hari dalam pekan dan tidak libur menurut kalender tugasnya.
create or replace function public.jadwal_pegawai(p_emp uuid, p_tanggal date)
returns table (
  employee_id uuid, tanggal date, session_id uuid, pattern_id uuid, jenis_pola text, nama_pola text,
  kode_sesi text, nama_sesi text, mulai timestamptz, selesai timestamptz,
  buka timestamptz, batas_tepat timestamptz, tutup timestamptz,
  wajib_pulang boolean, pulang_buka timestamptz, batas_cepat timestamptz, batas_pulang timestamptz,
  ditutup_pada timestamptz, opsional boolean, label_datang text, label_pulang text, warna text, urutan int)
language sql stable security definer set search_path = public as $$
  with dasar as (
    select s.*, p.jenis as jp, p.nama as np, p.warna as wp, p.urutan as up,
           ((p_tanggal + s.jam_mulai)::timestamp at time zone 'Asia/Makassar') as t_mulai,
           ((p_tanggal + s.jam_selesai
              + case when s.jam_selesai <= s.jam_mulai then interval '1 day' else interval '0' end
            )::timestamp at time zone 'Asia/Makassar') as t_selesai
      from employees e
      join employee_schedules es on es.employee_id = e.id and es.aktif
      join task_patterns p on p.id = es.pattern_id and p.aktif
      join pattern_sessions s on s.pattern_id = p.id and s.aktif
     where e.id = p_emp and e.status_keaktifan = 'aktif'
       and (es.sesi_dipegang is null or cardinality(es.sesi_dipegang) = 0 or s.id = any(es.sesi_dipegang))
       and case when p.jenis = 'shift'
                then exists (select 1 from shift_rosters r
                              where r.employee_id = e.id and r.tanggal = p_tanggal and r.session_id = s.id)
                else extract(dow from p_tanggal)::smallint = any(s.hari)
                     and not public.libur_tugas(p_tanggal, p.kalender)
           end
  )
  select p_emp, p_tanggal, d.id, d.pattern_id, d.jp, d.np, d.kode, d.nama, d.t_mulai, d.t_selesai,
         d.t_mulai - make_interval(mins => d.buka_menit),
         d.t_mulai + make_interval(mins => d.toleransi_terlambat_menit),
         d.t_mulai + make_interval(mins => d.tutup_menit),
         d.wajib_pulang,
         d.t_selesai - make_interval(mins => d.pulang_buka_menit),
         d.t_selesai - make_interval(mins => d.toleransi_cepat_pulang_menit),
         d.t_selesai + make_interval(mins => d.batas_pulang_menit),
         case when d.wajib_pulang then d.t_selesai + make_interval(mins => d.batas_pulang_menit)
              else d.t_mulai + make_interval(mins => d.tutup_menit) end,
         d.opsional, d.label_datang, d.label_pulang, d.wp, d.up * 100 + d.urutan
    from dasar d
   order by d.t_mulai
$$;

-- Sinkron jadwal dari jabatan fungsional (pola bawaan) dan struktural
create or replace function public.sinkron_jadwal(p_emp uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v_pola uuid[]; v_str uuid;
begin
  select coalesce(array_agg(distinct fp.pola_id) filter (where fp.pola_id is not null), '{}')
    into v_pola
    from employee_functions ef
    join functional_positions fp on fp.id = ef.functional_position_id
   where ef.employee_id = p_emp;

  delete from employee_schedules
   where employee_id = p_emp and sumber = 'jabatan' and not (pattern_id = any(v_pola));

  insert into employee_schedules (employee_id, pattern_id, sumber)
  select p_emp, x, 'jabatan' from unnest(v_pola) x
  on conflict (employee_id, pattern_id) do nothing;

  -- Struktural tanpa tugas fungsional terjadwal tetap wajib presensi (pola struktural)
  select id into v_str from task_patterns where pola_struktural limit 1;
  if cardinality(v_pola) = 0 and v_str is not null
     and exists (select 1 from employee_structurals where employee_id = p_emp) then
    insert into employee_schedules (employee_id, pattern_id, sumber)
    values (p_emp, v_str, 'struktural')
    on conflict (employee_id, pattern_id) do nothing;
  else
    delete from employee_schedules where employee_id = p_emp and sumber = 'struktural';
  end if;
end $$;

create or replace function public.sinkron_jadwal_semua()
returns int language plpgsql volatile security definer set search_path = public as $$
declare r record; n int := 0;
begin
  if auth.uid() is not null and not public.admin_boleh('atur_presensi') then
    raise exception 'Anda tidak memiliki izin mengatur presensi.' using hint = 'TANPA_IZIN';
  end if;
  for r in select id from employees where status_akun <> 'ditolak' loop
    perform public.sinkron_jadwal(r.id); n := n + 1;
  end loop;
  return n;
end $$;

create or replace function public.tg_sinkron_jadwal()
returns trigger language plpgsql security definer set search_path = public as $$
declare r record;
begin
  if TG_TABLE_NAME = 'functional_positions' then
    for r in select employee_id from employee_functions where functional_position_id = new.id loop
      perform public.sinkron_jadwal(r.employee_id);
    end loop;
  else
    perform public.sinkron_jadwal(coalesce(new.employee_id, old.employee_id));
  end if;
  return null;
end $$;

create trigger zz_sinkron_jadwal after insert or delete on public.employee_functions
  for each row execute function public.tg_sinkron_jadwal();
create trigger zz_sinkron_jadwal after insert or delete on public.employee_structurals
  for each row execute function public.tg_sinkron_jadwal();
create trigger zz_sinkron_jadwal after update of pola_id on public.functional_positions
  for each row execute function public.tg_sinkron_jadwal();

-- Penjaga: sesi dengan kode sama dalam satu pola tidak boleh berbagi hari
create or replace function public.tg_sesi_jaga()
returns trigger language plpgsql set search_path = public as $$
begin
  if new.aktif and exists (
       select 1 from pattern_sessions s
        where s.pattern_id = new.pattern_id and s.kode = new.kode and s.aktif
          and s.id <> new.id and s.hari && new.hari) then
    raise exception 'Sesi % sudah memiliki jam pada sebagian hari yang dipilih. Pilih hari yang berbeda.', new.nama
      using hint = 'SESI_BERTUMPUK';
  end if;
  return new;
end $$;
create trigger aa_sesi_jaga before insert or update on public.pattern_sessions
  for each row execute function public.tg_sesi_jaga();

-- Penjaga: jadwal shift hanya untuk sesi pola berjenis shift
create or replace function public.tg_shift_jaga()
returns trigger language plpgsql set search_path = public as $$
begin
  if not exists (select 1 from pattern_sessions s join task_patterns p on p.id = s.pattern_id
                  where s.id = new.session_id and p.jenis = 'shift') then
    raise exception 'Jadwal shift hanya dapat memakai sesi dari pola berjenis shift.' using hint = 'BUKAN_SHIFT';
  end if;
  return new;
end $$;
create trigger aa_shift_jaga before insert or update on public.shift_rosters
  for each row execute function public.tg_shift_jaga();

-- ---------------------------------------------------------------------
-- C. RENCANA PRESENSI PADA SATU WAKTU
-- ---------------------------------------------------------------------
-- Satu presensi memenuhi SEMUA sesi yang jendelanya sedang terbuka:
--   datang : belum ada data sesi itu dan waktu di antara buka..tutup
--   pulang : sudah datang, wajib pulang, belum pulang, waktu di antara pulang_buka..batas_pulang
-- Pulang sebelum batas toleransi cepat pulang perlu konfirmasi pegawai
-- (kecuali sesi opsional seperti istirahat: kembali lebih awal tidak dihitung cepat pulang).
create or replace function public.rencana_presensi(p_emp uuid, p_waktu timestamptz)
returns table (aksi text, tanggal date, session_id uuid, pattern_id uuid, nama_pola text, nama_sesi text,
               label text, mulai timestamptz, selesai timestamptz, wajib_pulang boolean, opsional boolean,
               status text, menit int, perlu_konfirmasi boolean)
language sql stable security definer set search_path = public as $$
  with j as (
    select j.*, a.id as a_id, a.status as a_status, a.datang_pada, a.status_pulang
      from generate_series(((p_waktu at time zone 'Asia/Makassar')::date - 1)::timestamp,
                           (p_waktu at time zone 'Asia/Makassar')::date::timestamp, interval '1 day') d
      cross join lateral public.jadwal_pegawai(p_emp, d::date) j
      left join attendances a on a.employee_id = p_emp and a.session_id = j.session_id and a.tanggal = j.tanggal
  ), jeda as (
    select make_interval(mins => (public.pengaturan_presensi()->>'jeda_minimal_pulang_menit')::int) as v
  )
  select 'datang', j.tanggal, j.session_id, j.pattern_id, j.nama_pola, j.nama_sesi, j.label_datang,
         j.mulai, j.selesai, j.wajib_pulang, j.opsional,
         case when p_waktu <= j.batas_tepat then 'hadir' else 'terlambat' end,
         case when p_waktu <= j.batas_tepat then 0
              else greatest(1, floor(extract(epoch from p_waktu - j.mulai) / 60))::int end,
         false
    from j
   where j.a_id is null and p_waktu between j.buka and j.tutup
  union all
  select 'pulang', j.tanggal, j.session_id, j.pattern_id, j.nama_pola, j.nama_sesi, j.label_pulang,
         j.mulai, j.selesai, j.wajib_pulang, j.opsional,
         case when j.opsional or p_waktu >= j.batas_cepat then 'tepat' else 'cepat' end,
         case when j.opsional or p_waktu >= j.batas_cepat then 0
              else greatest(1, floor(extract(epoch from j.selesai - p_waktu) / 60))::int end,
         not j.opsional and p_waktu < j.batas_cepat
    from j, jeda
   where j.a_id is not null and j.wajib_pulang and j.datang_pada is not null
     and coalesce(j.status_pulang, 'belum') = 'belum'
     and j.a_status in ('hadir','terlambat','dinas_luar','menunggu_verval')
     and p_waktu between j.pulang_buka and j.batas_pulang
     and p_waktu >= j.datang_pada + jeda.v
$$;

-- ---------------------------------------------------------------------
-- D1. PERIKSA LOKASI (dipanggil aplikasi sebelum mengambil selfie)
-- ---------------------------------------------------------------------
create or replace function public.periksa_presensi(p_lat double precision, p_lng double precision,
                                                   p_akurasi real default null)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare
  v_emp uuid := public.saya();
  v_now timestamptz := now();
  v_set jsonb := public.pengaturan_presensi();
  t record; v_cek uuid; v_rencana jsonb; v_berikut jsonb;
begin
  if v_emp is null then
    raise exception 'Akun Anda belum aktif.' using hint = 'AKUN_TIDAK_AKTIF';
  end if;
  if p_lat is null or p_lng is null or p_lat not between -90 and 90 or p_lng not between -180 and 180 then
    raise exception 'Lokasi tidak terbaca. Aktifkan GPS lalu coba lagi.' using hint = 'LOKASI_TIDAK_SAH';
  end if;

  select * into t from public.titik_terdekat(p_lat, p_lng);

  insert into attendance_checks (employee_id, waktu, lat, lng, akurasi_m, titik_id, titik_nama, jarak_m, di_area)
  values (v_emp, v_now, p_lat, p_lng, p_akurasi, t.titik_id, t.nama, t.jarak_m, coalesce(t.di_area, false))
  returning id into v_cek;

  select coalesce(jsonb_agg(to_jsonb(r) order by r.mulai, r.aksi), '[]'::jsonb)
    into v_rencana from public.rencana_presensi(v_emp, v_now) r;

  select to_jsonb(x) into v_berikut from (
    select j.tanggal, j.nama_pola, j.nama_sesi, j.mulai, j.buka
      from generate_series(((v_now at time zone 'Asia/Makassar')::date)::timestamp,
                           ((v_now at time zone 'Asia/Makassar')::date + 1)::timestamp, interval '1 day') d
      cross join lateral public.jadwal_pegawai(v_emp, d::date) j
     where j.buka > v_now
     order by j.buka limit 1) x;

  return jsonb_build_object(
    'cek_id', v_cek,
    'waktu', v_now,
    'tanggal', (v_now at time zone 'Asia/Makassar')::date,
    'jam', to_char(v_now at time zone 'Asia/Makassar', 'HH24:MI:SS'),
    'ada_titik', t.titik_id is not null,
    'titik', t.nama,
    'jarak_m', t.jarak_m,
    'radius_m', t.radius_m,
    'di_area', coalesce(t.di_area, false),
    'akurasi_m', p_akurasi,
    'rencana', v_rencana,
    'perlu_konfirmasi', exists (select 1 from jsonb_array_elements(v_rencana) e where (e->>'perlu_konfirmasi')::boolean),
    'sesi_berikut', v_berikut,
    'berlaku_detik', (v_set->>'berlaku_cek_detik')::int);
end $$;

-- ---------------------------------------------------------------------
-- D2. CATAT PRESENSI (inti; waktu dapat diberikan hanya untuk uji internal)
-- ---------------------------------------------------------------------
create or replace function public._catat_presensi(
  p_emp uuid, p_cek uuid, p_pilihan text, p_alasan text, p_selfie uuid, p_hash text,
  p_perangkat text, p_info text, p_ip text, p_permintaan text, p_konfirmasi_cepat boolean,
  p_waktu timestamptz)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare
  v_set jsonb := public.pengaturan_presensi();
  c attendance_checks;
  v_ada record; r record;
  v_ev uuid; v_hasil jsonb := '[]'::jsonb; v_ada_rencana boolean := false;
  v_alasan text := nullif(trim(coalesce(p_alasan, '')), '');
begin
  if p_permintaan is null or length(p_permintaan) < 8 then
    raise exception 'Permintaan tidak sah.' using hint = 'PERMINTAAN_TIDAK_SAH';
  end if;
  -- Satu pegawai diproses berurutan (tekan ganda tidak membuat data dobel)
  perform pg_advisory_xact_lock(hashtextextended('presensi:' || p_emp::text, 0));

  select id, hasil, waktu, di_area into v_ada
    from attendance_events where employee_id = p_emp and permintaan_id = p_permintaan;
  if found then
    return jsonb_build_object('ok', true, 'ulang', true, 'event_id', v_ada.id, 'waktu', v_ada.waktu,
                              'di_area', v_ada.di_area, 'hasil', v_ada.hasil);
  end if;

  if not exists (select 1 from employees where id = p_emp and status_akun = 'aktif' and status_keaktifan = 'aktif') then
    raise exception 'Akun Anda belum aktif atau sedang tidak aktif bertugas.' using hint = 'AKUN_TIDAK_AKTIF';
  end if;

  select * into c from attendance_checks where id = p_cek and employee_id = p_emp for update;
  if not found then
    raise exception 'Pemeriksaan lokasi tidak ditemukan. Silakan ulangi presensi.' using hint = 'CEK_TIDAK_DITEMUKAN';
  end if;
  if c.dipakai_pada is not null then
    raise exception 'Pemeriksaan lokasi ini sudah dipakai. Silakan ulangi presensi.' using hint = 'CEK_SUDAH_DIPAKAI';
  end if;
  if p_waktu - c.waktu > make_interval(secs => (v_set->>'berlaku_cek_detik')::int) then
    raise exception 'Waktu pemeriksaan lokasi sudah habis. Silakan ulangi presensi.' using hint = 'CEK_KEDALUWARSA';
  end if;

  if p_selfie is null or not exists (select 1 from storage_objects where id = p_selfie and pemilik_id = p_emp) then
    raise exception 'Selfie wajib diambil pada setiap presensi.' using hint = 'SELFIE_WAJIB';
  end if;

  if not c.di_area then
    if p_pilihan is null or p_pilihan not in ('hadir','izin','sakit') then
      raise exception 'Anda berada di luar area pondok. Pilih Hadir, Izin, atau Sakit.' using hint = 'PILIHAN_WAJIB';
    end if;
    if v_alasan is null or length(v_alasan) < 5 then
      raise exception 'Alasan wajib diisi (minimal 5 karakter) untuk presensi di luar area.' using hint = 'ALASAN_WAJIB';
    end if;
  end if;

  -- Rencana: apa saja yang akan dicatat
  for r in select * from public.rencana_presensi(p_emp, p_waktu) loop
    v_ada_rencana := true;
  end loop;
  if not v_ada_rencana then
    raise exception 'Tidak ada sesi yang sedang terbuka untuk presensi saat ini.' using hint = 'TIDAK_ADA_SESI';
  end if;
  if not exists (select 1 from public.rencana_presensi(p_emp, p_waktu) x
                  where not x.perlu_konfirmasi or coalesce(p_konfirmasi_cepat, false)) then
    raise exception 'Presensi pulang lebih awal perlu konfirmasi.' using hint = 'BUTUH_KONFIRMASI';
  end if;

  insert into attendance_events (employee_id, waktu, tanggal, cek_id, lat, lng, akurasi_m, titik_id, titik_nama,
                                 jarak_m, di_area, pilihan, alasan, selfie_id, selfie_hash, perangkat_id,
                                 perangkat_info, alamat_ip, permintaan_id)
  values (p_emp, p_waktu, (p_waktu at time zone 'Asia/Makassar')::date, c.id, c.lat, c.lng, c.akurasi_m,
          c.titik_id, c.titik_nama, c.jarak_m, c.di_area,
          case when c.di_area then null else p_pilihan end, case when c.di_area then null else v_alasan end,
          p_selfie, nullif(p_hash, ''), nullif(p_perangkat, ''), left(p_info, 300), left(p_ip, 60), p_permintaan)
  returning id into v_ev;

  perform set_config('simka.jenis_perubahan', 'presensi', true);
  perform set_config('simka.oleh', p_emp::text, true);
  perform set_config('simka.alasan', coalesce(case when c.di_area then null else v_alasan end, ''), true);

  for r in select * from public.rencana_presensi(p_emp, p_waktu) x
            where not x.perlu_konfirmasi or coalesce(p_konfirmasi_cepat, false)
            order by x.mulai, x.aksi
  loop
    if r.aksi = 'datang' then
      insert into attendances (employee_id, tanggal, session_id, pattern_id, nama_pola, nama_sesi,
                               jadwal_mulai, jadwal_selesai, wajib_pulang, opsional, status, usulan_status,
                               datang_pada, datang_event_id, terlambat_menit, status_pulang, sumber, keterangan)
      values (p_emp, r.tanggal, r.session_id, r.pattern_id, r.nama_pola, r.nama_sesi,
              r.mulai, r.selesai, r.wajib_pulang, r.opsional,
              case when c.di_area then r.status else 'menunggu_verval' end,
              case when c.di_area then null else p_pilihan end,
              p_waktu, v_ev,
              case when c.di_area or p_pilihan = 'hadir' then r.menit else 0 end,
              case when r.wajib_pulang then 'belum' end,
              case when c.di_area then 'gps' else 'luar_area' end,
              case when c.di_area then null else v_alasan end);
    else
      update attendances
         set pulang_pada = p_waktu, pulang_event_id = v_ev,
             status_pulang = case when c.di_area then r.status else 'menunggu_verval' end,
             cepat_pulang_menit = r.menit,
             keterangan = case when c.di_area then keterangan
                               else concat_ws('; ', keterangan, 'Pulang di luar area: ' || v_alasan) end
       where employee_id = p_emp and session_id = r.session_id and tanggal = r.tanggal;
    end if;

    v_hasil := v_hasil || jsonb_build_object(
      'aksi', r.aksi, 'tanggal', r.tanggal, 'session_id', r.session_id, 'nama_pola', r.nama_pola,
      'nama_sesi', r.nama_sesi, 'label', r.label,
      'status', case when c.di_area then r.status else 'menunggu_verval' end,
      'menit', r.menit);
  end loop;

  update attendance_events set hasil = v_hasil where id = v_ev;
  update attendance_checks set dipakai_pada = p_waktu where id = c.id;
  perform public.periksa_kecurigaan(v_ev);

  return jsonb_build_object(
    'ok', true, 'ulang', false, 'event_id', v_ev, 'waktu', p_waktu,
    'jam', to_char(p_waktu at time zone 'Asia/Makassar', 'HH24:MI:SS'),
    'di_area', c.di_area, 'titik', c.titik_nama, 'jarak_m', c.jarak_m,
    'menunggu_verval', not c.di_area, 'hasil', v_hasil);
end $$;

-- Pintu resmi untuk Edge Function "presensi" (waktu selalu dari server)
create or replace function public.catat_presensi(
  p_emp uuid, p_cek uuid, p_pilihan text, p_alasan text, p_selfie uuid, p_hash text,
  p_perangkat text, p_info text, p_ip text, p_permintaan text, p_konfirmasi_cepat boolean default false)
returns jsonb language sql volatile security definer set search_path = public as $$
  select public._catat_presensi(p_emp, p_cek, p_pilihan, p_alasan, p_selfie, p_hash,
                                p_perangkat, p_info, p_ip, p_permintaan, p_konfirmasi_cepat, now())
$$;

-- ---------------------------------------------------------------------
-- E1. DETEKSI KECURIGAAN (dijalankan otomatis setiap presensi)
-- ---------------------------------------------------------------------
create or replace function public.periksa_kecurigaan(p_event uuid)
returns int language plpgsql volatile security definer set search_path = public as $$
declare e attendance_events; v_batas real; n int := 0; v_lain jsonb;
begin
  select * into e from attendance_events where id = p_event;
  if not found then return 0; end if;
  v_batas := (public.pengaturan_presensi()->>'batas_akurasi_m')::real;

  -- 1. Akurasi GPS tidak wajar (tidak dilaporkan, terlalu sempurna, atau terlalu buruk)
  if e.akurasi_m is null or e.akurasi_m <= 1 or e.akurasi_m > v_batas then
    insert into suspicion_flags (employee_id, event_id, jenis, rincian)
    values (e.employee_id, e.id, 'akurasi_tidak_wajar', jsonb_build_object('akurasi_m', e.akurasi_m, 'batas_m', v_batas));
    n := n + 1;
  end if;

  -- 2. Koordinat sama persis dengan presensi sebelumnya (30 hari)
  if exists (select 1 from attendance_events x
              where x.employee_id = e.employee_id and x.id <> e.id and x.waktu > e.waktu - interval '30 days'
                and x.lat = e.lat and x.lng = e.lng) then
    insert into suspicion_flags (employee_id, event_id, jenis, rincian)
    values (e.employee_id, e.id, 'koordinat_identik', jsonb_build_object('lat', e.lat, 'lng', e.lng,
            'jumlah_sebelumnya', (select count(*) from attendance_events x where x.employee_id = e.employee_id
                                    and x.id <> e.id and x.waktu > e.waktu - interval '30 days'
                                    and x.lat = e.lat and x.lng = e.lng)));
    n := n + 1;
  end if;

  -- 3. Satu perangkat dipakai beberapa akun (30 hari)
  if e.perangkat_id is not null then
    select jsonb_agg(distinct emp.nama_lengkap) into v_lain
      from attendance_events x join employees emp on emp.id = x.employee_id
     where x.perangkat_id = e.perangkat_id and x.employee_id <> e.employee_id
       and x.waktu > e.waktu - interval '30 days';
    if v_lain is not null then
      insert into suspicion_flags (employee_id, event_id, jenis, rincian)
      values (e.employee_id, e.id, 'perangkat_bersama', jsonb_build_object('pegawai_lain', v_lain));
      n := n + 1;
    end if;
  end if;

  -- 4. Selfie identik dengan foto sebelumnya (berkas sama persis)
  if e.selfie_hash is not null and exists (select 1 from attendance_events x
                                            where x.selfie_hash = e.selfie_hash and x.id <> e.id) then
    insert into suspicion_flags (employee_id, event_id, jenis, rincian)
    values (e.employee_id, e.id, 'selfie_identik', jsonb_build_object('hash', left(e.selfie_hash, 16)));
    n := n + 1;
  end if;
  return n;
end $$;

-- ---------------------------------------------------------------------
-- E2. RIWAYAT STATUS (setiap perubahan dicatat; data lama tidak dihapus)
-- ---------------------------------------------------------------------
create or replace function public.tg_riwayat_presensi()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if TG_OP = 'INSERT' or new.status is distinct from old.status
     or new.status_pulang is distinct from old.status_pulang then
    insert into attendance_status_history (attendance_id, jenis, dari_status, ke_status, dari_pulang, ke_pulang, alasan, oleh)
    values (new.id,
            coalesce(nullif(current_setting('simka.jenis_perubahan', true), ''), 'sistem'),
            case when TG_OP = 'UPDATE' then old.status end, new.status,
            case when TG_OP = 'UPDATE' then old.status_pulang end, new.status_pulang,
            nullif(current_setting('simka.alasan', true), ''),
            coalesce(nullif(current_setting('simka.oleh', true), '')::uuid, public.saya()));
  end if;
  return new;
end $$;
create trigger zz_riwayat after insert or update on public.attendances
  for each row execute function public.tg_riwayat_presensi();

-- ---------------------------------------------------------------------
-- E3. PRESENSI HARIAN (untuk beranda dan halaman presensi)
-- ---------------------------------------------------------------------
-- Keadaan sesi: akan_datang, terbuka, menunggu_pulang, selesai, terlewat.
-- Sesi semalam (shift malam, asrama malam) dari kemarin ikut tampil selama belum ditutup.
create or replace function public.presensi_harian(p_emp uuid default null, p_tanggal date default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_saya uuid := public.saya();
  v_emp uuid := coalesce(p_emp, v_saya);
  v_now timestamptz := now();
  v_hari date := coalesce(p_tanggal, (now() at time zone 'Asia/Makassar')::date);
  v_sesi jsonb;
begin
  if v_emp is null then
    raise exception 'Akun Anda belum aktif.' using hint = 'AKUN_TIDAK_AKTIF';
  end if;
  if v_emp is distinct from v_saya and not (public.is_admin() or public.pimpinan_dari(v_emp)) then
    raise exception 'Anda tidak berhak melihat presensi pegawai ini.' using hint = 'TANPA_IZIN';
  end if;

  with j as (
    select j.* from public.jadwal_pegawai(v_emp, v_hari) j
    union all
    select k.* from public.jadwal_pegawai(v_emp, v_hari - 1) k
     where v_hari = (v_now at time zone 'Asia/Makassar')::date and k.selesai > (v_hari::timestamp at time zone 'Asia/Makassar')
       and k.ditutup_pada > v_now
  ), gabung as (
    select coalesce(j.tanggal, a.tanggal) as tanggal,
           coalesce(j.session_id, a.session_id) as session_id,
           coalesce(j.nama_pola, a.nama_pola) as nama_pola,
           coalesce(j.nama_sesi, a.nama_sesi) as nama_sesi,
           j.jenis_pola, j.warna, j.label_datang, j.label_pulang,
           coalesce(j.mulai, a.jadwal_mulai) as mulai, coalesce(j.selesai, a.jadwal_selesai) as selesai,
           j.buka, j.batas_tepat, j.tutup, j.pulang_buka, j.batas_pulang,
           coalesce(j.wajib_pulang, a.wajib_pulang) as wajib_pulang,
           coalesce(j.opsional, a.opsional) as opsional,
           a.id as attendance_id, a.status, a.usulan_status, a.datang_pada, a.terlambat_menit,
           a.status_pulang, a.pulang_pada, a.cepat_pulang_menit, a.sumber, a.keterangan,
           case
             when a.id is not null and a.wajib_pulang and a.status_pulang = 'belum'
                  and v_now <= coalesce(j.batas_pulang, a.jadwal_selesai) then 'menunggu_pulang'
             when a.id is not null then 'selesai'
             when j.buka is not null and v_now < j.buka then 'akan_datang'
             when j.buka is not null and v_now <= j.tutup then 'terbuka'
             else 'terlewat'
           end as keadaan
      from j
      full join (select * from attendances
                  where employee_id = v_emp
                    and (tanggal = v_hari or (tanggal = v_hari - 1 and session_id in (select session_id from j)))) a
        on a.session_id = j.session_id and a.tanggal = j.tanggal
  )
  select coalesce(jsonb_agg(to_jsonb(g) order by g.mulai), '[]'::jsonb) into v_sesi from gabung g;

  return jsonb_build_object(
    'employee_id', v_emp,
    'tanggal', v_hari,
    'waktu', v_now,
    'jam', to_char(v_now at time zone 'Asia/Makassar', 'HH24:MI:SS'),
    'sesi', v_sesi);
end $$;

-- ---------------------------------------------------------------------
-- E4. PENUTUPAN SESI (pg_cron tiap 15 menit + penyapuan 00.30 WITA)
-- ---------------------------------------------------------------------
-- * Sesi wajib yang jendela datangnya sudah lewat tanpa presensi → Tanpa keterangan.
-- * Sesi wajib pulang yang batas pulangnya lewat tanpa presensi pulang
--   → status tetap, ditandai "tidak presensi pulang" (keputusan pemilik proyek, pilihan a).
-- Hanya berjalan mulai 'mulai_tanggal' di Pengaturan presensi (aman sebelum uji coba selesai).
create or replace function public.tutup_sesi_presensi(p_sampai timestamptz default now())
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare
  v_mulai date := nullif(public.pengaturan_presensi()->>'mulai_tanggal', '')::date;
  v_hari date := (p_sampai at time zone 'Asia/Makassar')::date;
  n_tk int := 0; n_pl int := 0;
begin
  delete from attendance_checks where waktu < now() - interval '2 days';
  if v_mulai is null then
    return jsonb_build_object('dijalankan', false, 'pesan', 'Tanggal mulai presensi belum diatur.');
  end if;

  perform set_config('simka.jenis_perubahan', 'penutupan', true);
  perform set_config('simka.alasan', 'Ditutup otomatis oleh sistem', true);
  perform set_config('simka.oleh', '', true);

  insert into attendances (employee_id, tanggal, session_id, pattern_id, nama_pola, nama_sesi,
                           jadwal_mulai, jadwal_selesai, wajib_pulang, opsional, status, sumber)
  select e.id, j.tanggal, j.session_id, j.pattern_id, j.nama_pola, j.nama_sesi,
         j.mulai, j.selesai, j.wajib_pulang, j.opsional, 'tanpa_keterangan', 'penutupan'
    from employees e
    cross join generate_series(greatest(v_mulai, v_hari - 2)::timestamp, v_hari::timestamp, interval '1 day') d
    cross join lateral public.jadwal_pegawai(e.id, d::date) j
   where e.status_akun = 'aktif' and e.status_keaktifan = 'aktif'
     and not j.opsional and j.tutup < p_sampai
     and not exists (select 1 from attendances a
                      where a.employee_id = e.id and a.session_id = j.session_id and a.tanggal = j.tanggal)
  on conflict (employee_id, session_id, tanggal) do nothing;
  get diagnostics n_tk = row_count;

  update attendances a
     set status_pulang = 'tidak_presensi'
    from pattern_sessions s
   where s.id = a.session_id and a.wajib_pulang and a.status_pulang = 'belum'
     and a.tanggal >= v_mulai
     and a.jadwal_selesai + make_interval(mins => s.batas_pulang_menit) < p_sampai;
  get diagnostics n_pl = row_count;

  return jsonb_build_object('dijalankan', true, 'tanpa_keterangan', n_tk, 'tidak_presensi_pulang', n_pl,
                            'sampai', p_sampai);
end $$;

-- ---------------------------------------------------------------------
-- HAK EKSEKUSI
-- ---------------------------------------------------------------------
revoke execute on function public.pengaturan_presensi() from public, anon, authenticated;
revoke execute on function public.libur_tugas(date, text) from public, anon;
revoke execute on function public.titik_terdekat(double precision, double precision) from public, anon, authenticated;
revoke execute on function public.jadwal_pegawai(uuid, date) from public, anon, authenticated;
revoke execute on function public.sinkron_jadwal(uuid) from public, anon, authenticated;
revoke execute on function public.sinkron_jadwal_semua() from public, anon;
revoke execute on function public.rencana_presensi(uuid, timestamptz) from public, anon, authenticated;
revoke execute on function public.periksa_presensi(double precision, double precision, real) from public, anon;
revoke execute on function public._catat_presensi(uuid,uuid,text,text,uuid,text,text,text,text,text,boolean,timestamptz) from public, anon, authenticated;
revoke execute on function public.catat_presensi(uuid,uuid,text,text,uuid,text,text,text,text,text,boolean) from public, anon, authenticated;
revoke execute on function public.periksa_kecurigaan(uuid) from public, anon, authenticated;
revoke execute on function public.presensi_harian(uuid, date) from public, anon;
revoke execute on function public.tutup_sesi_presensi(timestamptz) from public, anon, authenticated;

grant execute on function public.libur_tugas(date, text) to authenticated;
grant execute on function public.sinkron_jadwal_semua() to authenticated;
grant execute on function public.periksa_presensi(double precision, double precision, real) to authenticated;
grant execute on function public.presensi_harian(uuid, date) to authenticated;
do $$ begin if exists (select 1 from pg_roles where rolname = 'service_role') then
  revoke execute on function public._catat_presensi(uuid,uuid,text,text,uuid,text,text,text,text,text,boolean,timestamptz) from service_role;
  grant execute on function public.catat_presensi(uuid,uuid,text,text,uuid,text,text,text,text,text,boolean) to service_role;
end if; end $$;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 3 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select 'Fungsi presensi (14)' as pemeriksaan,
       case when count(distinct proname) = 14 then 'Sesuai' else 'Periksa: ' || count(distinct proname) end as hasil
  from pg_proc where pronamespace = 'public'::regnamespace and proname in ('pengaturan_presensi','jarak_meter',
   'libur_tugas','titik_terdekat','jadwal_pegawai','sinkron_jadwal','sinkron_jadwal_semua','rencana_presensi',
   'periksa_presensi','_catat_presensi','catat_presensi','periksa_kecurigaan','presensi_harian','tutup_sesi_presensi')
union all
select 'Uji jarak (Makassar–Gowa ±10 km)',
       case when public.jarak_meter(-5.1477, 119.4327, -5.2081, 119.4950) between 9000 and 10500
            then 'Sesuai' else 'Periksa' end
union all
select 'Pemicu riwayat dan sinkron jadwal',
       case when (select count(*) from pg_trigger where tgname in ('zz_riwayat','zz_sinkron_jadwal','aa_sesi_jaga','aa_shift_jaga')) = 6
            then 'Sesuai' else 'Periksa' end;
