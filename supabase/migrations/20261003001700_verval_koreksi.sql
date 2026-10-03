-- SIMKA PRO | supabase/migrations/20261003001700_verval_koreksi.sql | v1.0 | Fase 2 – Tahap 6 Verval dan koreksi | 03/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 2 · Migrasi 17: Verval, koreksi bertingkat, izin per sesi, kecurigaan, notifikasi
-- Aturan (Bagian 9 blueprint):
--   * presensi di luar area → admin (izin verval_presensi) melakukan verval; hasilnya FINAL dan wajib beralasan;
--   * mengubah data final: admin mengajukan koreksi → superadmin menyetujui;
--   * superadmin dapat mengubah langsung, wajib beralasan; semua perubahan tercatat di riwayat status;
--   * pegawai dapat izin untuk sesi tertentu saja; izin gugur bila ia tetap presensi.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Perbarui rencana dan pencatatan presensi: izin sesi gugur bila pegawai tetap hadir
-- ---------------------------------------------------------------------
create or replace function public.rencana_presensi(p_emp uuid, p_waktu timestamptz)
returns table (aksi text, tanggal date, session_id uuid, pattern_id uuid, nama_pola text, nama_sesi text,
               label text, mulai timestamptz, selesai timestamptz, wajib_pulang boolean, opsional boolean,
               status text, menit int, perlu_konfirmasi boolean)
language sql stable security definer set search_path = public as $$
  with j as (
    select j.*, a.id as a_id, a.status as a_status, a.datang_pada, a.status_pulang, a.sumber as a_sumber
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
   where (j.a_id is null or (j.datang_pada is null and j.a_sumber = 'izin_sesi'))   -- izin sesi gugur bila pegawai tetap hadir
     and p_waktu between j.buka and j.tutup
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
              case when c.di_area then null else v_alasan end)
      on conflict (employee_id, session_id, tanggal) do update
         set status = excluded.status, usulan_status = excluded.usulan_status, datang_pada = excluded.datang_pada,
             datang_event_id = excluded.datang_event_id, terlambat_menit = excluded.terlambat_menit,
             status_pulang = excluded.status_pulang, sumber = excluded.sumber, diverval_oleh = null, diverval_pada = null,
             keterangan = concat_ws('; ', attendances.keterangan, 'Izin sesi gugur karena pegawai presensi', excluded.keterangan)
       where attendances.datang_pada is null and attendances.sumber = 'izin_sesi';
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


-- ---------------------------------------------------------------------
-- 2. Notifikasi otomatis
-- ---------------------------------------------------------------------
-- Presensi menunggu verval → admin ber-izin verval_presensi (satu notifikasi per ketukan, bukan per sesi)
create or replace function public.tg_notif_verval()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_nama text; v_baru_datang boolean; v_baru_pulang boolean;
begin
  v_baru_datang := coalesce(new.status = 'menunggu_verval' and (TG_OP = 'INSERT' or old.status is distinct from 'menunggu_verval'), false);
  v_baru_pulang := coalesce(new.status_pulang = 'menunggu_verval' and (TG_OP = 'INSERT' or old.status_pulang is distinct from 'menunggu_verval'), false);
  if not (v_baru_datang or v_baru_pulang) then return null; end if;
  if v_baru_datang and new.datang_event_id is not null and exists (
       select 1 from attendances where datang_event_id = new.datang_event_id and id <> new.id and status = 'menunggu_verval') then
    return null;
  end if;
  if v_baru_pulang and not v_baru_datang and new.pulang_event_id is not null and exists (
       select 1 from attendances where pulang_event_id = new.pulang_event_id and id <> new.id and status_pulang = 'menunggu_verval') then
    return null;
  end if;
  select nama_lengkap into v_nama from employees where id = new.employee_id;
  perform public.notifikasi_admin('verval_presensi',
    case when new.sumber = 'izin_sesi' then 'Pengajuan izin sesi' else 'Presensi di luar area' end,
    v_nama || ' – ' || new.nama_sesi || ' ' || to_char(new.tanggal, 'DD/MM/YYYY') ||
      case when new.sumber = 'izin_sesi' then ' (' || coalesce(new.usulan_status, 'izin') || ')' when v_baru_pulang and not v_baru_datang then ' (pulang)' else '' end ||
      '. Menunggu verval.', '/verval-presensi/antrian', 'MapPin', 'jingga');
  return null;
end $$;
create trigger zz_notif_verval after insert or update of status, status_pulang on public.attendances
  for each row execute function public.tg_notif_verval();

-- Penanda kecurigaan baru → admin (satu notifikasi per ketukan)
create or replace function public.tg_notif_curiga()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_nama text;
begin
  if new.event_id is not null and exists (select 1 from suspicion_flags where event_id = new.event_id and id <> new.id) then return null; end if;
  select nama_lengkap into v_nama from employees where id = new.employee_id;
  perform public.notifikasi_admin('verval_presensi', 'Presensi perlu ditinjau',
    'Ada penanda kecurigaan pada presensi ' || v_nama || '.', '/verval-presensi/kecurigaan', 'WarningCircle', 'merah');
  return null;
end $$;
create trigger zz_notif_curiga after insert on public.suspicion_flags
  for each row execute function public.tg_notif_curiga();

-- ---------------------------------------------------------------------
-- 3. Verval oleh admin (hasil final, wajib beralasan)
--    p_bagian: 'datang' (status sesi) atau 'pulang' (status pulang)
-- ---------------------------------------------------------------------
create or replace function public.verval_presensi(p_id uuid, p_bagian text, p_status text, p_alasan text)
returns void language plpgsql volatile security definer set search_path = public as $$
declare a attendances; v_saya uuid := public.saya(); v_teks text;
begin
  if not public.admin_boleh('verval_presensi') then
    raise exception 'Anda tidak memiliki izin verval presensi.' using hint = 'TANPA_IZIN';
  end if;
  if length(trim(coalesce(p_alasan, ''))) < 5 then
    raise exception 'Alasan verval wajib diisi (minimal 5 karakter).' using hint = 'ALASAN_WAJIB';
  end if;
  select * into a from attendances where id = p_id for update;
  if not found then raise exception 'Data presensi tidak ditemukan.' using hint = 'TIDAK_DITEMUKAN'; end if;
  if a.employee_id = v_saya and not public.is_superadmin() then
    raise exception 'Presensi Anda sendiri diverval oleh admin lain.' using hint = 'DIRI_SENDIRI';
  end if;

  perform set_config('simka.jenis_perubahan', 'verval', true);
  perform set_config('simka.alasan', trim(p_alasan), true);
  perform set_config('simka.oleh', coalesce(v_saya::text, ''), true);

  if p_bagian = 'datang' then
    if a.status <> 'menunggu_verval' then
      raise exception 'Presensi ini sudah diverval. Perubahan berikutnya melalui permintaan koreksi.' using hint = 'SUDAH_FINAL';
    end if;
    if p_status not in ('hadir','terlambat','dinas_luar','izin','sakit','tanpa_keterangan') then
      raise exception 'Status verval tidak sah.' using hint = 'STATUS_TIDAK_SAH';
    end if;
    update attendances set status = p_status, sumber = case when sumber = 'izin_sesi' then sumber else 'verval' end,
           terlambat_menit = case when p_status = 'terlambat' then greatest(terlambat_menit, 1) else 0 end,
           status_pulang = case when p_status in ('izin','sakit','tanpa_keterangan') then null else status_pulang end,
           diverval_oleh = v_saya, diverval_pada = now(),
           keterangan = concat_ws('; ', keterangan, 'Verval: ' || trim(p_alasan))
     where id = p_id;
  elsif p_bagian = 'pulang' then
    if a.status_pulang is distinct from 'menunggu_verval' then
      raise exception 'Presensi pulang ini tidak menunggu verval.' using hint = 'SUDAH_FINAL';
    end if;
    if p_status not in ('tepat','cepat','tidak_presensi') then
      raise exception 'Status pulang tidak sah.' using hint = 'STATUS_TIDAK_SAH';
    end if;
    update attendances set status_pulang = p_status, cepat_pulang_menit = case when p_status = 'cepat' then cepat_pulang_menit else 0 end,
           diverval_oleh = v_saya, diverval_pada = now(),
           keterangan = concat_ws('; ', keterangan, 'Verval pulang: ' || trim(p_alasan))
     where id = p_id;
  else
    raise exception 'Bagian verval tidak sah.' using hint = 'STATUS_TIDAK_SAH';
  end if;

  v_teks := case p_bagian when 'datang' then (select coalesce(case p_status when 'hadir' then 'Hadir' when 'terlambat' then 'Terlambat'
              when 'dinas_luar' then 'Dinas luar' when 'izin' then 'Izin' when 'sakit' then 'Sakit' else 'Tanpa keterangan' end, p_status))
            else case p_status when 'tepat' then 'Pulang tepat' when 'cepat' then 'Pulang cepat' else 'Tidak presensi pulang' end end;
  perform public.kirim_notifikasi(a.employee_id, 'Presensi sudah diverval',
    a.nama_sesi || ' ' || to_char(a.tanggal, 'DD/MM/YYYY') || ': ' || v_teks || '. Alasan: ' || trim(p_alasan),
    '/presensi', 'CheckCircle', case when p_status in ('tanpa_keterangan','tidak_presensi') then 'merah' else 'hijau' end);
end $$;

-- ---------------------------------------------------------------------
-- 4. Koreksi bertingkat: admin mengajukan → superadmin memutuskan
-- ---------------------------------------------------------------------
create or replace function public.ajukan_koreksi(p_id uuid, p_status text, p_pulang text, p_alasan text)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare a attendances; v_id uuid; v_nama text;
begin
  if not public.admin_boleh('verval_presensi') then
    raise exception 'Anda tidak memiliki izin mengajukan koreksi presensi.' using hint = 'TANPA_IZIN';
  end if;
  if length(trim(coalesce(p_alasan, ''))) < 5 then
    raise exception 'Alasan koreksi wajib diisi (minimal 5 karakter).' using hint = 'ALASAN_WAJIB';
  end if;
  select * into a from attendances where id = p_id;
  if not found then raise exception 'Data presensi tidak ditemukan.' using hint = 'TIDAK_DITEMUKAN'; end if;
  if a.status = 'menunggu_verval' then
    raise exception 'Presensi ini belum diverval. Lakukan verval, bukan koreksi.' using hint = 'BELUM_FINAL';
  end if;
  if p_status is null or p_status not in ('hadir','terlambat','dinas_luar','izin','sakit','cuti','tanpa_keterangan')
     or (p_pulang is not null and p_pulang not in ('tepat','cepat','tidak_presensi')) then
    raise exception 'Status koreksi tidak sah.' using hint = 'STATUS_TIDAK_SAH';
  end if;
  if p_status = a.status and p_pulang is not distinct from a.status_pulang then
    raise exception 'Status baru sama dengan status sekarang.' using hint = 'TIDAK_BERUBAH';
  end if;
  if exists (select 1 from correction_requests where attendance_id = p_id and status = 'menunggu') then
    raise exception 'Presensi ini sudah memiliki permintaan koreksi yang menunggu.' using hint = 'SEDANG_DIPROSES';
  end if;
  insert into correction_requests (attendance_id, diajukan_oleh, status_baru, pulang_baru, alasan)
  values (p_id, public.saya(), p_status, p_pulang, trim(p_alasan)) returning id into v_id;
  select nama_lengkap into v_nama from employees where id = a.employee_id;
  insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
  select e.id, 'Permintaan koreksi presensi', v_nama || ' – ' || a.nama_sesi || ' ' || to_char(a.tanggal, 'DD/MM/YYYY') || '. Menunggu persetujuan.',
         '/verval-presensi/koreksi', 'ListChecks', 'ungu'
    from employees e where e.peran = 'superadmin' and e.status_akun = 'aktif';
  return v_id;
end $$;

create or replace function public.putuskan_koreksi(p_id uuid, p_setuju boolean, p_catatan text default null)
returns void language plpgsql volatile security definer set search_path = public as $$
declare k correction_requests; a attendances;
begin
  if not public.is_superadmin() then
    raise exception 'Hanya superadmin yang dapat memutuskan koreksi.' using hint = 'TANPA_IZIN';
  end if;
  select * into k from correction_requests where id = p_id for update;
  if not found or k.status <> 'menunggu' then
    raise exception 'Permintaan koreksi tidak ditemukan atau sudah diputuskan.' using hint = 'SUDAH_DIJAWAB';
  end if;
  if not p_setuju and length(trim(coalesce(p_catatan, ''))) < 5 then
    raise exception 'Alasan penolakan wajib diisi (minimal 5 karakter).' using hint = 'ALASAN_WAJIB';
  end if;
  select * into a from attendances where id = k.attendance_id for update;
  if p_setuju then
    perform set_config('simka.jenis_perubahan', 'koreksi', true);
    perform set_config('simka.alasan', k.alasan || coalesce(' | Disetujui: ' || nullif(trim(p_catatan), ''), ''), true);
    perform set_config('simka.oleh', coalesce(public.saya()::text, ''), true);
    update attendances set status = k.status_baru,
           status_pulang = case when k.status_baru in ('izin','sakit','cuti','tanpa_keterangan') then null
                                else coalesce(k.pulang_baru, status_pulang) end,
           terlambat_menit = case when k.status_baru = 'terlambat' then greatest(terlambat_menit, 1) else 0 end,
           cepat_pulang_menit = case when coalesce(k.pulang_baru, status_pulang) = 'cepat' then cepat_pulang_menit else 0 end,
           sumber = 'koreksi', keterangan = concat_ws('; ', keterangan, 'Koreksi: ' || k.alasan)
     where id = k.attendance_id;
  end if;
  update correction_requests set status = case when p_setuju then 'disetujui' else 'ditolak' end,
         diputus_oleh = public.saya(), diputus_pada = now(), catatan = nullif(trim(coalesce(p_catatan, '')), '')
   where id = p_id;
  perform public.kirim_notifikasi(k.diajukan_oleh, case when p_setuju then 'Koreksi presensi disetujui' else 'Koreksi presensi ditolak' end,
    a.nama_sesi || ' ' || to_char(a.tanggal, 'DD/MM/YYYY') || coalesce('. ' || nullif(trim(p_catatan), ''), '.'),
    '/verval-presensi/koreksi', 'ListChecks', case when p_setuju then 'hijau' else 'merah' end);
  if p_setuju then
    perform public.kirim_notifikasi(a.employee_id, 'Presensi Anda dikoreksi',
      a.nama_sesi || ' ' || to_char(a.tanggal, 'DD/MM/YYYY') || ' dikoreksi. Alasan: ' || k.alasan, '/presensi', 'ListChecks', 'biru');
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 5. Superadmin: ubah langsung atau catat manual (wajib beralasan)
-- ---------------------------------------------------------------------
create or replace function public.ubah_presensi(p_id uuid, p_status text, p_pulang text, p_alasan text)
returns void language plpgsql volatile security definer set search_path = public as $$
declare a attendances;
begin
  if not public.is_superadmin() then raise exception 'Hanya superadmin yang dapat mengubah langsung.' using hint = 'TANPA_IZIN'; end if;
  if length(trim(coalesce(p_alasan, ''))) < 5 then raise exception 'Alasan wajib diisi (minimal 5 karakter).' using hint = 'ALASAN_WAJIB'; end if;
  if p_status not in ('hadir','terlambat','dinas_luar','izin','sakit','cuti','tanpa_keterangan')
     or (p_pulang is not null and p_pulang not in ('tepat','cepat','tidak_presensi')) then
    raise exception 'Status tidak sah.' using hint = 'STATUS_TIDAK_SAH';
  end if;
  select * into a from attendances where id = p_id for update;
  if not found then raise exception 'Data presensi tidak ditemukan.' using hint = 'TIDAK_DITEMUKAN'; end if;
  perform set_config('simka.jenis_perubahan', 'superadmin', true);
  perform set_config('simka.alasan', trim(p_alasan), true);
  perform set_config('simka.oleh', coalesce(public.saya()::text, ''), true);
  update attendances set status = p_status,
         status_pulang = case when p_status in ('izin','sakit','cuti','tanpa_keterangan') then null when a.wajib_pulang then coalesce(p_pulang, status_pulang) else null end,
         terlambat_menit = case when p_status = 'terlambat' then greatest(terlambat_menit, 1) else 0 end,
         sumber = 'koreksi', diverval_oleh = coalesce(diverval_oleh, public.saya()), diverval_pada = coalesce(diverval_pada, now()),
         keterangan = concat_ws('; ', keterangan, 'Diubah superadmin: ' || trim(p_alasan))
   where id = p_id;
  -- Permintaan koreksi yang masih menunggu untuk data ini tidak lagi relevan
  update correction_requests set status = 'ditolak', diputus_oleh = public.saya(), diputus_pada = now(),
         catatan = 'Diubah langsung oleh superadmin'
   where attendance_id = p_id and status = 'menunggu';
  perform public.kirim_notifikasi(a.employee_id, 'Presensi Anda diubah',
    a.nama_sesi || ' ' || to_char(a.tanggal, 'DD/MM/YYYY') || '. Alasan: ' || trim(p_alasan), '/presensi', 'ListChecks', 'biru');
end $$;

create or replace function public.catat_presensi_manual(p_emp uuid, p_tanggal date, p_session uuid, p_status text, p_alasan text)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare j record; v_id uuid;
begin
  if not public.is_superadmin() then raise exception 'Hanya superadmin yang dapat mencatat presensi manual.' using hint = 'TANPA_IZIN'; end if;
  if length(trim(coalesce(p_alasan, ''))) < 5 then raise exception 'Alasan wajib diisi (minimal 5 karakter).' using hint = 'ALASAN_WAJIB'; end if;
  if p_status not in ('hadir','terlambat','dinas_luar','izin','sakit','cuti','tanpa_keterangan') then
    raise exception 'Status tidak sah.' using hint = 'STATUS_TIDAK_SAH';
  end if;
  select * into j from public.jadwal_pegawai(p_emp, p_tanggal) x where x.session_id = p_session;
  if not found then raise exception 'Sesi ini tidak ada pada jadwal pegawai di tanggal tersebut.' using hint = 'BUKAN_JADWAL'; end if;
  if exists (select 1 from attendances where employee_id = p_emp and session_id = p_session and tanggal = p_tanggal) then
    raise exception 'Sesi ini sudah memiliki data presensi. Gunakan ubah status.' using hint = 'SUDAH_ADA';
  end if;
  perform set_config('simka.jenis_perubahan', 'superadmin', true);
  perform set_config('simka.alasan', trim(p_alasan), true);
  perform set_config('simka.oleh', coalesce(public.saya()::text, ''), true);
  insert into attendances (employee_id, tanggal, session_id, pattern_id, nama_pola, nama_sesi, jadwal_mulai, jadwal_selesai,
                           wajib_pulang, opsional, status, terlambat_menit, status_pulang, sumber, keterangan, diverval_oleh, diverval_pada)
  values (p_emp, p_tanggal, p_session, j.pattern_id, j.nama_pola, j.nama_sesi, j.mulai, j.selesai, j.wajib_pulang, j.opsional,
          p_status, case when p_status = 'terlambat' then 1 else 0 end,
          case when j.wajib_pulang and p_status in ('hadir','terlambat','dinas_luar') then 'tepat' end,
          'koreksi', 'Dicatat manual: ' || trim(p_alasan), public.saya(), now())
  returning id into v_id;
  perform public.kirim_notifikasi(p_emp, 'Presensi dicatat manual',
    j.nama_sesi || ' ' || to_char(p_tanggal, 'DD/MM/YYYY') || '. Alasan: ' || trim(p_alasan), '/presensi', 'ListChecks', 'biru');
  return v_id;
end $$;

-- ---------------------------------------------------------------------
-- 6. Izin per sesi (pegawai)
-- ---------------------------------------------------------------------
create or replace function public.ajukan_izin_sesi(p_tanggal date, p_session uuid, p_jenis text, p_alasan text)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_emp uuid := public.saya(); j record; v_id uuid;
begin
  if v_emp is null then raise exception 'Akun Anda belum aktif.' using hint = 'AKUN_TIDAK_AKTIF'; end if;
  if p_jenis not in ('izin','sakit') then raise exception 'Pilih Izin atau Sakit.' using hint = 'STATUS_TIDAK_SAH'; end if;
  if length(trim(coalesce(p_alasan, ''))) < 5 then raise exception 'Alasan wajib diisi (minimal 5 karakter).' using hint = 'ALASAN_WAJIB'; end if;
  if p_tanggal < (now() at time zone 'Asia/Makassar')::date or p_tanggal > (now() at time zone 'Asia/Makassar')::date + 30 then
    raise exception 'Izin sesi hanya untuk hari ini sampai 30 hari ke depan.' using hint = 'TANGGAL_TIDAK_SAH';
  end if;
  select * into j from public.jadwal_pegawai(v_emp, p_tanggal) x where x.session_id = p_session;
  if not found then raise exception 'Sesi ini tidak ada pada jadwal Anda di tanggal tersebut.' using hint = 'BUKAN_JADWAL'; end if;
  if j.tutup <= now() then raise exception 'Sesi ini sudah ditutup.' using hint = 'SUDAH_DITUTUP'; end if;
  if exists (select 1 from attendances where employee_id = v_emp and session_id = p_session and tanggal = p_tanggal) then
    raise exception 'Sesi ini sudah memiliki presensi atau pengajuan.' using hint = 'SUDAH_ADA';
  end if;
  perform set_config('simka.jenis_perubahan', 'pengajuan', true);
  perform set_config('simka.alasan', trim(p_alasan), true);
  perform set_config('simka.oleh', v_emp::text, true);
  insert into attendances (employee_id, tanggal, session_id, pattern_id, nama_pola, nama_sesi, jadwal_mulai, jadwal_selesai,
                           wajib_pulang, opsional, status, usulan_status, sumber, keterangan)
  values (v_emp, p_tanggal, p_session, j.pattern_id, j.nama_pola, j.nama_sesi, j.mulai, j.selesai, j.wajib_pulang, j.opsional,
          'menunggu_verval', p_jenis, 'izin_sesi', 'Izin sesi: ' || trim(p_alasan))
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.batalkan_izin_sesi(p_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  delete from attendances
   where id = p_id and employee_id = public.saya() and sumber = 'izin_sesi' and status = 'menunggu_verval' and datang_pada is null;
  if not found then raise exception 'Pengajuan tidak dapat dibatalkan (sudah diverval atau bukan milik Anda).' using hint = 'TIDAK_DAPAT'; end if;
end $$;

-- ---------------------------------------------------------------------
-- 7. Tinjau penanda kecurigaan
-- ---------------------------------------------------------------------
create or replace function public.tinjau_kecurigaan(p_id uuid, p_status text, p_catatan text default null)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  if not public.admin_boleh('verval_presensi') then raise exception 'Anda tidak memiliki izin verval presensi.' using hint = 'TANPA_IZIN'; end if;
  if p_status not in ('wajar','pelanggaran') then raise exception 'Status tinjauan tidak sah.' using hint = 'STATUS_TIDAK_SAH'; end if;
  if p_status = 'pelanggaran' and length(trim(coalesce(p_catatan, ''))) < 5 then
    raise exception 'Catatan wajib diisi untuk pelanggaran (minimal 5 karakter).' using hint = 'ALASAN_WAJIB';
  end if;
  update suspicion_flags set status = p_status, ditinjau_oleh = public.saya(), ditinjau_pada = now(), catatan = nullif(trim(coalesce(p_catatan, '')), '')
   where id = p_id;
  if not found then raise exception 'Penanda tidak ditemukan.' using hint = 'TIDAK_DITEMUKAN'; end if;
end $$;

-- ---------------------------------------------------------------------
-- 8. Data panel admin: antrian verval, koreksi, kecurigaan
-- ---------------------------------------------------------------------
create or replace function public.panel_verval(p_hari int default 30)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v jsonb;
begin
  if not public.admin_boleh('verval_presensi') then raise exception 'Anda tidak memiliki izin verval presensi.' using hint = 'TANPA_IZIN'; end if;
  select jsonb_build_object(
    'antrian', coalesce((select jsonb_agg(x order by x->>'dibuat') from (
      select jsonb_build_object('id', a.id, 'employee_id', a.employee_id, 'nama', e.nama_lengkap, 'niy', e.niy, 'tanggal', a.tanggal,
        'nama_pola', a.nama_pola, 'nama_sesi', a.nama_sesi, 'jadwal_mulai', a.jadwal_mulai, 'jadwal_selesai', a.jadwal_selesai,
        'status', a.status, 'usulan_status', a.usulan_status, 'status_pulang', a.status_pulang, 'sumber', a.sumber,
        'terlambat_menit', a.terlambat_menit, 'cepat_pulang_menit', a.cepat_pulang_menit, 'keterangan', a.keterangan,
        'datang_pada', a.datang_pada, 'pulang_pada', a.pulang_pada, 'wajib_pulang', a.wajib_pulang, 'dibuat', a.created_at,
        'bagian', case when a.status = 'menunggu_verval' then 'datang' else 'pulang' end,
        'ev', (select jsonb_build_object('titik', ev.titik_nama, 'jarak_m', ev.jarak_m, 'akurasi_m', ev.akurasi_m, 'alasan', ev.alasan,
                 'pilihan', ev.pilihan, 'selfie_id', ev.selfie_id, 'waktu', ev.waktu, 'lat', ev.lat, 'lng', ev.lng)
                 from attendance_events ev where ev.id = case when a.status = 'menunggu_verval' then a.datang_event_id else a.pulang_event_id end),
        'curiga', (select coalesce(jsonb_agg(distinct f.jenis), '[]'::jsonb) from suspicion_flags f
                    where f.event_id in (a.datang_event_id, a.pulang_event_id))) x
        from attendances a join employees e on e.id = a.employee_id
       where (a.status = 'menunggu_verval' or a.status_pulang = 'menunggu_verval')
         and (a.employee_id <> public.saya() or public.is_superadmin())) q), '[]'::jsonb),
    'koreksi', coalesce((select jsonb_agg(jsonb_build_object('id', k.id, 'status', k.status, 'alasan', k.alasan, 'status_baru', k.status_baru,
        'pulang_baru', k.pulang_baru, 'catatan', k.catatan, 'dibuat', k.created_at, 'pengaju', ep.nama_lengkap,
        'attendance_id', a.id, 'nama', e.nama_lengkap, 'tanggal', a.tanggal, 'nama_sesi', a.nama_sesi, 'nama_pola', a.nama_pola,
        'status_lama', a.status, 'pulang_lama', a.status_pulang) order by (k.status = 'menunggu') desc, k.created_at desc)
        from correction_requests k join attendances a on a.id = k.attendance_id
        join employees e on e.id = a.employee_id join employees ep on ep.id = k.diajukan_oleh
       where k.status = 'menunggu' or k.created_at > now() - make_interval(days => p_hari)), '[]'::jsonb),
    'curiga', coalesce((select jsonb_agg(jsonb_build_object('id', f.id, 'jenis', f.jenis, 'rincian', f.rincian, 'status', f.status,
        'catatan', f.catatan, 'dibuat', f.created_at, 'nama', e.nama_lengkap, 'employee_id', f.employee_id,
        'ev', (select jsonb_build_object('waktu', ev.waktu, 'titik', ev.titik_nama, 'jarak_m', ev.jarak_m, 'akurasi_m', ev.akurasi_m,
                 'selfie_id', ev.selfie_id, 'di_area', ev.di_area, 'hasil', ev.hasil) from attendance_events ev where ev.id = f.event_id))
        order by (f.status = 'baru') desc, f.created_at desc)
        from suspicion_flags f join employees e on e.id = f.employee_id
       where f.status = 'baru' or f.created_at > now() - make_interval(days => p_hari)), '[]'::jsonb)
  ) into v;
  return v;
end $$;

-- Riwayat status satu data presensi (pegawai pemilik, admin, pimpinan)
create or replace function public.riwayat_presensi(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare a attendances;
begin
  select * into a from attendances where id = p_id;
  if not found or not (a.employee_id = public.saya() or public.is_admin() or public.pimpinan_dari(a.employee_id)) then
    raise exception 'Data tidak ditemukan.' using hint = 'TIDAK_DITEMUKAN';
  end if;
  return coalesce((select jsonb_agg(jsonb_build_object('waktu', h.created_at, 'jenis', h.jenis, 'dari', h.dari_status, 'ke', h.ke_status,
            'dari_pulang', h.dari_pulang, 'ke_pulang', h.ke_pulang, 'alasan', h.alasan, 'oleh', e.nama_lengkap) order by h.created_at)
          from attendance_status_history h left join employees e on e.id = h.oleh where h.attendance_id = p_id), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- Hak eksekusi
-- ---------------------------------------------------------------------
revoke execute on function public.verval_presensi(uuid, text, text, text) from public, anon;
revoke execute on function public.ajukan_koreksi(uuid, text, text, text) from public, anon;
revoke execute on function public.putuskan_koreksi(uuid, boolean, text) from public, anon;
revoke execute on function public.ubah_presensi(uuid, text, text, text) from public, anon;
revoke execute on function public.catat_presensi_manual(uuid, date, uuid, text, text) from public, anon;
revoke execute on function public.ajukan_izin_sesi(date, uuid, text, text) from public, anon;
revoke execute on function public.batalkan_izin_sesi(uuid) from public, anon;
revoke execute on function public.tinjau_kecurigaan(uuid, text, text) from public, anon;
revoke execute on function public.panel_verval(int) from public, anon;
revoke execute on function public.riwayat_presensi(uuid) from public, anon;
revoke execute on function public.rencana_presensi(uuid, timestamptz) from public, anon, authenticated;
revoke execute on function public._catat_presensi(uuid,uuid,text,text,uuid,text,text,text,text,text,boolean,timestamptz) from public, anon, authenticated;
grant execute on function public.verval_presensi(uuid, text, text, text) to authenticated;
grant execute on function public.ajukan_koreksi(uuid, text, text, text) to authenticated;
grant execute on function public.putuskan_koreksi(uuid, boolean, text) to authenticated;
grant execute on function public.ubah_presensi(uuid, text, text, text) to authenticated;
grant execute on function public.catat_presensi_manual(uuid, date, uuid, text, text) to authenticated;
grant execute on function public.ajukan_izin_sesi(date, uuid, text, text) to authenticated;
grant execute on function public.batalkan_izin_sesi(uuid) to authenticated;
grant execute on function public.tinjau_kecurigaan(uuid, text, text) to authenticated;
grant execute on function public.panel_verval(int) to authenticated;
grant execute on function public.riwayat_presensi(uuid) to authenticated;
do $$ begin if exists (select 1 from pg_roles where rolname = 'service_role') then
  revoke execute on function public._catat_presensi(uuid,uuid,text,text,uuid,text,text,text,text,text,boolean,timestamptz) from service_role;
end if; end $$;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 3 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select 'Fungsi verval dan koreksi (10)' as pemeriksaan,
       case when count(*) = 10 then 'Sesuai' else 'Periksa: ' || count(*) end as hasil
  from pg_proc where pronamespace = 'public'::regnamespace and proname in ('verval_presensi','ajukan_koreksi','putuskan_koreksi',
   'ubah_presensi','catat_presensi_manual','ajukan_izin_sesi','batalkan_izin_sesi','tinjau_kecurigaan','panel_verval','riwayat_presensi')
union all
select 'Pemicu notifikasi (2)',
       case when (select count(*) from pg_trigger where tgname in ('zz_notif_verval','zz_notif_curiga')) = 2 then 'Sesuai' else 'Periksa' end
union all
select 'Migrasi 1600 sudah terpasang',
       case when exists (select 1 from pg_proc where proname = 'simpan_jadwal_shift') then 'Sesuai' else 'Periksa: jalankan 1600 dulu' end;
