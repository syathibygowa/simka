-- SIMKA PRO | supabase/migrations/20261003001600_jadwal_shift.sql | v1.0 | Fase 2 – Tahap 5 Jadwal shift | 03/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 2 · Migrasi 16: Jadwal shift (medis, security) dan tukar shift
--   * data_shift            : jadwal satu pola shift pada rentang tanggal (admin & pemegang pola)
--   * simpan_jadwal_shift   : simpan jadwal satu rentang sekaligus (admin ber-izin atur_presensi)
--   * tukar shift           : pemohon → rekan menyetujui → admin memutuskan → jadwal ditukar
-- Jadwal yang sudah memiliki data presensi tidak pernah dihapus atau dipindahkan.
-- =====================================================================

create table public.shift_swaps (
  id                uuid primary key default gen_random_uuid(),
  pemohon_id        uuid not null references public.employees(id) on delete cascade,
  roster_pemohon_id uuid not null references public.shift_rosters(id) on delete cascade,
  penerima_id       uuid not null references public.employees(id) on delete cascade,
  roster_penerima_id uuid references public.shift_rosters(id) on delete cascade,  -- kosong = rekan menggantikan
  alasan            text not null check (length(trim(alasan)) >= 5),
  status            text not null default 'menunggu_rekan'
                    check (status in ('menunggu_rekan','menunggu_admin','disetujui','ditolak','dibatalkan')),
  rekan_pada        timestamptz,
  catatan_rekan     text,
  diputus_oleh      uuid references public.employees(id) on delete set null,
  diputus_pada      timestamptz,
  catatan_admin     text,
  created_at        timestamptz not null default now(),
  check (pemohon_id <> penerima_id)
);
create index shift_swaps_status_idx on public.shift_swaps (status, created_at desc);
alter table public.shift_swaps enable row level security;
create policy baca on public.shift_swaps for select to authenticated
  using (pemohon_id = public.saya() or penerima_id = public.saya() or public.admin_boleh('atur_presensi'));
create trigger zz_audit after insert or update or delete on public.shift_swaps
  for each row execute function public.tg_audit();

-- Waktu mulai satu baris jadwal shift (WITA)
create or replace function public.mulai_shift(p_roster uuid)
returns timestamptz language sql stable security definer set search_path = public as $$
  select ((r.tanggal + s.jam_mulai)::timestamp at time zone 'Asia/Makassar')
    from shift_rosters r join pattern_sessions s on s.id = r.session_id where r.id = p_roster
$$;

-- Apakah pegawai boleh melihat jadwal pola shift ini
create or replace function public.boleh_lihat_shift(p_pola uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_admin() or exists (select 1 from employee_schedules
                                       where employee_id = public.saya() and pattern_id = p_pola and aktif)
$$;

-- ---------------------------------------------------------------------
-- Data jadwal satu pola shift (pegawai pemegang, jadwal, permintaan tukar)
-- ---------------------------------------------------------------------
create or replace function public.data_shift(p_pola uuid, p_mulai date, p_akhir date)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v jsonb;
begin
  if not public.boleh_lihat_shift(p_pola) then
    raise exception 'Anda tidak berhak melihat jadwal shift ini.' using hint = 'TANPA_IZIN';
  end if;
  if p_akhir < p_mulai or p_akhir - p_mulai > 92 then
    raise exception 'Rentang tanggal paling lama 3 bulan.' using hint = 'RENTANG_TIDAK_SAH';
  end if;
  select jsonb_build_object(
    'pegawai', coalesce((
      select jsonb_agg(jsonb_build_object('id', e.id, 'nama', e.nama_lengkap, 'niy', e.niy) order by e.nama_lengkap)
        from employees e join employee_schedules es on es.employee_id = e.id and es.pattern_id = p_pola and es.aktif
       where e.status_keaktifan = 'aktif' and e.status_akun <> 'ditolak'), '[]'::jsonb),
    'roster', coalesce((
      select jsonb_agg(jsonb_build_object('id', r.id, 'employee_id', r.employee_id, 'tanggal', r.tanggal,
               'session_id', r.session_id, 'catatan', r.catatan,
               'ada_presensi', exists (select 1 from attendances a where a.employee_id = r.employee_id
                                         and a.session_id = r.session_id and a.tanggal = r.tanggal),
               'sudah_mulai', public.mulai_shift(r.id) <= now()) order by r.tanggal)
        from shift_rosters r join pattern_sessions s on s.id = r.session_id
       where s.pattern_id = p_pola and r.tanggal between p_mulai and p_akhir), '[]'::jsonb),
    'tukar', coalesce((
      select jsonb_agg(jsonb_build_object('id', t.id, 'status', t.status, 'alasan', t.alasan,
               'pemohon_id', t.pemohon_id, 'pemohon', ep.nama_lengkap, 'penerima_id', t.penerima_id, 'penerima', er.nama_lengkap,
               'tanggal_pemohon', rp.tanggal, 'sesi_pemohon', sp.nama,
               'tanggal_penerima', rr.tanggal, 'sesi_penerima', sr.nama,
               'catatan_rekan', t.catatan_rekan, 'catatan_admin', t.catatan_admin, 'created_at', t.created_at)
             order by t.created_at desc)
        from shift_swaps t
        join employees ep on ep.id = t.pemohon_id join employees er on er.id = t.penerima_id
        join shift_rosters rp on rp.id = t.roster_pemohon_id join pattern_sessions sp on sp.id = rp.session_id
        left join shift_rosters rr on rr.id = t.roster_penerima_id left join pattern_sessions sr on sr.id = rr.session_id
       where sp.pattern_id = p_pola
         and (t.status in ('menunggu_rekan','menunggu_admin') or t.created_at > now() - interval '30 days')
         and (public.admin_boleh('atur_presensi') or t.pemohon_id = public.saya() or t.penerima_id = public.saya())), '[]'::jsonb)
  ) into v;
  return v;
end $$;

-- ---------------------------------------------------------------------
-- Simpan jadwal satu rentang sekaligus (hasil pembuat jadwal bergilir atau suntingan manual)
-- p_baris: [{ "employee_id": "...", "tanggal": "yyyy-mm-dd", "session_id": "..." }, ...]
-- ---------------------------------------------------------------------
create or replace function public.simpan_jadwal_shift(p_pola uuid, p_mulai date, p_akhir date, p_baris jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare n_hapus int := 0; n_tambah int := 0; v_salah text; v_saya uuid := public.saya();
begin
  if not public.admin_boleh('atur_presensi') then
    raise exception 'Anda tidak memiliki izin mengatur jadwal shift.' using hint = 'TANPA_IZIN';
  end if;
  if not exists (select 1 from task_patterns where id = p_pola and jenis = 'shift') then
    raise exception 'Pola ini bukan pola shift.' using hint = 'BUKAN_SHIFT';
  end if;
  if p_akhir < p_mulai or p_akhir - p_mulai > 92 then
    raise exception 'Rentang tanggal paling lama 3 bulan.' using hint = 'RENTANG_TIDAK_SAH';
  end if;

  drop table if exists _baru;
  create temp table _baru on commit drop as
  select distinct (x->>'employee_id')::uuid as employee_id, (x->>'tanggal')::date as tanggal, (x->>'session_id')::uuid as session_id
    from jsonb_array_elements(coalesce(p_baris, '[]'::jsonb)) x;

  if exists (select 1 from _baru where tanggal not between p_mulai and p_akhir) then
    raise exception 'Ada jadwal di luar rentang tanggal yang disimpan.' using hint = 'RENTANG_TIDAK_SAH';
  end if;
  if exists (select 1 from _baru b left join pattern_sessions s on s.id = b.session_id
              where s.id is null or s.pattern_id <> p_pola) then
    raise exception 'Ada sesi yang bukan milik pola shift ini.' using hint = 'SESI_TIDAK_SAH';
  end if;
  select string_agg(distinct e.nama_lengkap, ', ') into v_salah
    from _baru b join employees e on e.id = b.employee_id
   where not exists (select 1 from employee_schedules es where es.employee_id = b.employee_id and es.pattern_id = p_pola and es.aktif);
  if v_salah is not null then
    raise exception 'Pegawai berikut tidak memegang pola shift ini: %.', v_salah using hint = 'BUKAN_PEMEGANG';
  end if;

  -- Hapus jadwal lama di rentang yang tidak ada lagi, kecuali yang sudah berisi presensi
  delete from shift_rosters r
   using pattern_sessions s
   where s.id = r.session_id and s.pattern_id = p_pola and r.tanggal between p_mulai and p_akhir
     and not exists (select 1 from _baru b where b.employee_id = r.employee_id and b.tanggal = r.tanggal and b.session_id = r.session_id)
     and not exists (select 1 from attendances a where a.employee_id = r.employee_id and a.session_id = r.session_id and a.tanggal = r.tanggal);
  get diagnostics n_hapus = row_count;

  insert into shift_rosters (employee_id, tanggal, session_id, dibuat_oleh)
  select b.employee_id, b.tanggal, b.session_id, v_saya from _baru b
  on conflict (employee_id, tanggal, session_id) do nothing;
  get diagnostics n_tambah = row_count;

  -- Beri tahu pegawai yang jadwalnya berubah
  if n_hapus + n_tambah > 0 then
    insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
    select distinct b.employee_id, 'Jadwal shift diperbarui',
           'Jadwal shift ' || to_char(p_mulai, 'DD/MM/YYYY') || ' s.d. ' || to_char(p_akhir, 'DD/MM/YYYY') || ' sudah disusun. Periksa jadwal Anda.',
           '/jadwal-shift', 'CalendarCheck', 'biru'
      from _baru b where b.employee_id is distinct from v_saya;
  end if;
  return jsonb_build_object('dihapus', n_hapus, 'ditambah', n_tambah);
end $$;

-- ---------------------------------------------------------------------
-- TUKAR SHIFT
-- ---------------------------------------------------------------------
create or replace function public.ajukan_tukar_shift(p_roster uuid, p_rekan uuid, p_roster_rekan uuid default null, p_alasan text default null)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_saya uuid := public.saya(); r shift_rosters; rr shift_rosters; v_pola uuid; v_id uuid; v_nama text;
begin
  select * into r from shift_rosters where id = p_roster;
  if not found or r.employee_id is distinct from v_saya then
    raise exception 'Jadwal shift tidak ditemukan atau bukan milik Anda.' using hint = 'BUKAN_MILIK';
  end if;
  select pattern_id into v_pola from pattern_sessions where id = r.session_id;
  if public.mulai_shift(r.id) <= now() then
    raise exception 'Shift yang sudah dimulai tidak dapat ditukar.' using hint = 'SUDAH_MULAI';
  end if;
  if length(trim(coalesce(p_alasan, ''))) < 5 then
    raise exception 'Alasan wajib diisi (minimal 5 karakter).' using hint = 'ALASAN_WAJIB';
  end if;
  if not exists (select 1 from employee_schedules where employee_id = p_rekan and pattern_id = v_pola and aktif) then
    raise exception 'Rekan yang dipilih tidak memegang pola shift yang sama.' using hint = 'BUKAN_PEMEGANG';
  end if;
  if p_roster_rekan is not null then
    select * into rr from shift_rosters where id = p_roster_rekan;
    if not found or rr.employee_id <> p_rekan
       or (select pattern_id from pattern_sessions where id = rr.session_id) <> v_pola then
      raise exception 'Shift rekan tidak sesuai.' using hint = 'SHIFT_REKAN_TIDAK_SAH';
    end if;
    if public.mulai_shift(rr.id) <= now() then
      raise exception 'Shift rekan sudah dimulai.' using hint = 'SUDAH_MULAI';
    end if;
  end if;
  if exists (select 1 from shift_swaps where status in ('menunggu_rekan','menunggu_admin')
              and (roster_pemohon_id in (p_roster, p_roster_rekan) or roster_penerima_id in (p_roster, p_roster_rekan))) then
    raise exception 'Shift ini sedang dalam permintaan tukar yang lain.' using hint = 'SEDANG_DIPROSES';
  end if;

  insert into shift_swaps (pemohon_id, roster_pemohon_id, penerima_id, roster_penerima_id, alasan)
  values (v_saya, p_roster, p_rekan, p_roster_rekan, trim(p_alasan)) returning id into v_id;
  select nama_lengkap into v_nama from employees where id = v_saya;
  perform public.kirim_notifikasi(p_rekan, 'Permintaan tukar shift',
    v_nama || ' meminta ' || case when p_roster_rekan is null then 'Anda menggantikan shift ' else 'bertukar shift ' end
      || to_char(r.tanggal, 'DD/MM/YYYY') || '. Mohon dijawab.', '/jadwal-shift', 'ArrowsLeftRight', 'ungu');
  return v_id;
end $$;

create or replace function public.jawab_tukar_shift(p_id uuid, p_setuju boolean, p_catatan text default null)
returns void language plpgsql volatile security definer set search_path = public as $$
declare t shift_swaps; v_nama text;
begin
  select * into t from shift_swaps where id = p_id for update;
  if not found or t.penerima_id is distinct from public.saya() then
    raise exception 'Permintaan tidak ditemukan.' using hint = 'TIDAK_DITEMUKAN';
  end if;
  if t.status <> 'menunggu_rekan' then
    raise exception 'Permintaan ini sudah dijawab.' using hint = 'SUDAH_DIJAWAB';
  end if;
  update shift_swaps set status = case when p_setuju then 'menunggu_admin' else 'ditolak' end,
         rekan_pada = now(), catatan_rekan = nullif(trim(coalesce(p_catatan, '')), '')
   where id = p_id;
  select nama_lengkap into v_nama from employees where id = t.penerima_id;
  perform public.kirim_notifikasi(t.pemohon_id,
    case when p_setuju then 'Rekan menyetujui tukar shift' else 'Rekan menolak tukar shift' end,
    v_nama || case when p_setuju then ' setuju. Menunggu persetujuan admin.' else ' menolak permintaan tukar shift Anda.' end,
    '/jadwal-shift', 'ArrowsLeftRight', case when p_setuju then 'hijau' else 'merah' end);
  if p_setuju then
    perform public.notifikasi_admin('atur_presensi', 'Tukar shift menunggu persetujuan',
      'Permintaan tukar shift sudah disetujui rekan dan menunggu keputusan admin.', '/jadwal-shift', 'ArrowsLeftRight', 'ungu');
  end if;
end $$;

create or replace function public.putuskan_tukar_shift(p_id uuid, p_setuju boolean, p_catatan text default null)
returns void language plpgsql volatile security definer set search_path = public as $$
declare t shift_swaps; a shift_rosters; b shift_rosters; v_pesan text;
begin
  if not public.admin_boleh('atur_presensi') then
    raise exception 'Anda tidak memiliki izin memutuskan tukar shift.' using hint = 'TANPA_IZIN';
  end if;
  select * into t from shift_swaps where id = p_id for update;
  if not found then raise exception 'Permintaan tidak ditemukan.' using hint = 'TIDAK_DITEMUKAN'; end if;
  if t.status <> 'menunggu_admin' then
    raise exception 'Permintaan ini tidak sedang menunggu keputusan admin.' using hint = 'SUDAH_DIJAWAB';
  end if;
  if not p_setuju and length(trim(coalesce(p_catatan, ''))) < 5 then
    raise exception 'Alasan penolakan wajib diisi (minimal 5 karakter).' using hint = 'ALASAN_WAJIB';
  end if;

  if p_setuju then
    select * into a from shift_rosters where id = t.roster_pemohon_id for update;
    if t.roster_penerima_id is not null then select * into b from shift_rosters where id = t.roster_penerima_id for update; end if;
    if a.id is null or a.employee_id <> t.pemohon_id or (t.roster_penerima_id is not null and (b.id is null or b.employee_id <> t.penerima_id)) then
      raise exception 'Jadwal shift sudah berubah sejak permintaan diajukan. Tolak permintaan ini.' using hint = 'JADWAL_BERUBAH';
    end if;
    if public.mulai_shift(a.id) <= now() or (b.id is not null and public.mulai_shift(b.id) <= now()) then
      raise exception 'Salah satu shift sudah dimulai sehingga tidak dapat ditukar.' using hint = 'SUDAH_MULAI';
    end if;
    if exists (select 1 from shift_rosters where employee_id = t.penerima_id and tanggal = a.tanggal and session_id = a.session_id)
       or (b.id is not null and exists (select 1 from shift_rosters where employee_id = t.pemohon_id and tanggal = b.tanggal and session_id = b.session_id)) then
      raise exception 'Pegawai sudah memiliki shift yang sama pada tanggal tersebut.' using hint = 'BENTROK';
    end if;
    update shift_rosters set employee_id = t.penerima_id, catatan = concat_ws('; ', catatan, 'Hasil tukar shift') where id = a.id;
    if b.id is not null then
      update shift_rosters set employee_id = t.pemohon_id, catatan = concat_ws('; ', catatan, 'Hasil tukar shift') where id = b.id;
    end if;
  end if;

  update shift_swaps set status = case when p_setuju then 'disetujui' else 'ditolak' end,
         diputus_oleh = public.saya(), diputus_pada = now(), catatan_admin = nullif(trim(coalesce(p_catatan, '')), '')
   where id = p_id;
  v_pesan := case when p_setuju then 'Tukar shift disetujui admin. Jadwal Anda sudah diperbarui.'
                  else 'Tukar shift ditolak admin: ' || trim(p_catatan) end;
  perform public.kirim_notifikasi(t.pemohon_id, 'Keputusan tukar shift', v_pesan, '/jadwal-shift', 'ArrowsLeftRight', case when p_setuju then 'hijau' else 'merah' end);
  perform public.kirim_notifikasi(t.penerima_id, 'Keputusan tukar shift', v_pesan, '/jadwal-shift', 'ArrowsLeftRight', case when p_setuju then 'hijau' else 'merah' end);
end $$;

create or replace function public.batalkan_tukar_shift(p_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  update shift_swaps set status = 'dibatalkan'
   where id = p_id and pemohon_id = public.saya() and status in ('menunggu_rekan','menunggu_admin');
  if not found then raise exception 'Permintaan tidak dapat dibatalkan.' using hint = 'TIDAK_DAPAT'; end if;
end $$;

-- ---------------------------------------------------------------------
-- Hak eksekusi
-- ---------------------------------------------------------------------
revoke execute on function public.mulai_shift(uuid) from public, anon, authenticated;
revoke execute on function public.boleh_lihat_shift(uuid) from public, anon;
revoke execute on function public.data_shift(uuid, date, date) from public, anon;
revoke execute on function public.simpan_jadwal_shift(uuid, date, date, jsonb) from public, anon;
revoke execute on function public.ajukan_tukar_shift(uuid, uuid, uuid, text) from public, anon;
revoke execute on function public.jawab_tukar_shift(uuid, boolean, text) from public, anon;
revoke execute on function public.putuskan_tukar_shift(uuid, boolean, text) from public, anon;
revoke execute on function public.batalkan_tukar_shift(uuid) from public, anon;
grant execute on function public.boleh_lihat_shift(uuid) to authenticated;
grant execute on function public.data_shift(uuid, date, date) to authenticated;
grant execute on function public.simpan_jadwal_shift(uuid, date, date, jsonb) to authenticated;
grant execute on function public.ajukan_tukar_shift(uuid, uuid, uuid, text) to authenticated;
grant execute on function public.jawab_tukar_shift(uuid, boolean, text) to authenticated;
grant execute on function public.putuskan_tukar_shift(uuid, boolean, text) to authenticated;
grant execute on function public.batalkan_tukar_shift(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 3 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select 'Tabel tukar shift' as pemeriksaan,
       case when exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'shift_swaps')
            then 'Sesuai' else 'Periksa' end as hasil
union all
select 'Fungsi jadwal shift (8)',
       case when count(*) = 8 then 'Sesuai' else 'Periksa: ' || count(*) end
  from pg_proc where pronamespace = 'public'::regnamespace and proname in ('mulai_shift','boleh_lihat_shift','data_shift',
   'simpan_jadwal_shift','ajukan_tukar_shift','jawab_tukar_shift','putuskan_tukar_shift','batalkan_tukar_shift')
union all
select 'Migrasi 1500 sudah terpasang',
       case when exists (select 1 from pg_proc where proname = 'pratinjau_jadwal') then 'Sesuai' else 'Periksa: jalankan 1500 dulu' end;
