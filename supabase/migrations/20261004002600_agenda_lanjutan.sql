-- SIMKA PRO | supabase/migrations/20261004002600_agenda_lanjutan.sql | v1.0 | Fase 3 – Perbaikan P2 (agenda lanjutan) | 04/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 3 · Migrasi 26: Agenda lanjutan (perbaikan dari uji pemilik proyek)
--   * Agenda berulang: harian, pekanan (pilih hari), bulanan, tahunan; setiap n; berakhir pada tanggal / setelah n kali / tanpa akhir;
--     satu tanggal kejadian dapat dilewati (pengecualian)
--   * Tautan (Zoom, Maps, dll.), lampiran berkas, dan 24 pilihan warna lembut
--   * Pengingat dalam menit sebelum mulai (10 menit, 1 jam, 1 hari, …); agenda sepanjang hari diacu pukul 06.00 WITA;
--     pg_cron tiap 5 menit, satu pengingat per kejadian tidak terkirim dua kali
--   * kalender_saya() kini mengembalikan setiap kejadian (agenda berulang tampil di tiap tanggalnya)
-- Jalankan SETELAH migrasi 2500. Aman dijalankan ulang.
-- =====================================================================

alter table public.agendas add column if not exists pengingat_menit int[] not null default '{1440,60}';
alter table public.agendas add column if not exists ulang jsonb;            -- {frek, interval, hari[], sampai, kali}
alter table public.agendas add column if not exists pengecualian date[] not null default '{}';
alter table public.agendas add column if not exists warna text not null default 'merak';
alter table public.agendas add column if not exists tautan text;
alter table public.agendas add column if not exists nama_tautan text;
alter table public.agendas add column if not exists lampiran_id uuid references public.storage_objects(id) on delete set null;

-- Data lama: pengingat hari → menit (H-n pukul 06.00 untuk agenda sepanjang hari; relatif jam mulai untuk agenda berjam)
update public.agendas set pengingat_menit = (select coalesce(array_agg(x * 1440 order by x desc), '{}') from unnest(pengingat) x)
 where cardinality(pengingat) > 0 and pengingat_menit = '{1440,60}';
update public.agendas set warna = case jenis when 'libur' then 'tomat' when 'rapat' then 'lavender' when 'lainnya' then 'pisang' else 'merak' end
 where warna = 'merak' and jenis <> 'kegiatan';

create table if not exists public.agenda_reminder_log (
  agenda_id   uuid not null references public.agendas(id) on delete cascade,
  tanggal     date not null,          -- tanggal kejadian
  menit       int not null,           -- menit sebelum mulai
  dikirim_pada timestamptz not null default now(),
  primary key (agenda_id, tanggal, menit)
);
alter table public.agenda_reminder_log enable row level security;

-- ---------------------------------------------------------------------
-- 1. Aturan berulang
-- ---------------------------------------------------------------------
/** Rapikan isian berulang dari aplikasi; null bila tidak berulang. */
create or replace function public._rapikan_ulang(p jsonb, p_mulai date)
returns jsonb language plpgsql immutable as $$
declare v_frek text := p->>'frek'; v_hari int[];
begin
  if p is null or jsonb_typeof(p) <> 'object' or coalesce(v_frek, '') not in ('harian','pekanan','bulanan','tahunan') then return null; end if;
  if v_frek = 'pekanan' then
    v_hari := coalesce((select array_agg(distinct x::int order by x::int) from jsonb_array_elements_text(p->'hari') x where x::int between 0 and 6), '{}');
    if cardinality(v_hari) = 0 then v_hari := array[extract(dow from p_mulai)::int]; end if;
  end if;
  if nullif(p->>'sampai', '') is not null and (p->>'sampai')::date < p_mulai then raise exception 'Tanggal akhir pengulangan tidak boleh sebelum tanggal mulai.'; end if;
  return jsonb_strip_nulls(jsonb_build_object('frek', v_frek, 'interval', greatest(1, least(coalesce((p->>'interval')::int, 1), 99)),
    'hari', to_jsonb(v_hari), 'sampai', nullif(p->>'sampai', ''),
    'kali', case when coalesce((p->>'kali')::int, 0) > 0 then least((p->>'kali')::int, 500) end));
end $$;

/** Kalimat pengulangan, mis. "Setiap pekan (Senin, Kamis) sampai 30/06/2027". */
create or replace function public.ringkas_ulang(p jsonb)
returns text language sql immutable as $$
  select case when p is null then null else
    'Setiap ' || case when coalesce((p->>'interval')::int, 1) > 1 then (p->>'interval') || ' ' else '' end
    || case p->>'frek' when 'harian' then 'hari' when 'pekanan' then 'pekan' when 'bulanan' then 'bulan' else 'tahun' end
    || case when p->>'frek' = 'pekanan' then ' (' || (select string_agg((array['Ahad','Senin','Selasa','Rabu','Kamis','Jumat','Sabtu'])[x::int + 1], ', ' order by x::int)
                                                   from jsonb_array_elements_text(p->'hari') x) || ')' else '' end
    || case when p ? 'sampai' then ' sampai ' || to_char((p->>'sampai')::date, 'DD/MM/YYYY')
            when p ? 'kali' then ', ' || (p->>'kali') || ' kali' else '' end end
$$;

/** Tanggal mulai setiap kejadian agenda yang beririsan dengan rentang [p_dari, p_sampai]. */
create or replace function public.kejadian_agenda(a agendas, p_dari date, p_sampai date)
returns setof date language plpgsql stable as $$
declare
  u jsonb := a.ulang; v_lama int := a.selesai - a.mulai; v_akhir date; v_int int; v_frek text; d date; n int := 0; i int := 0; w date; h int;
begin
  if u is null then
    if a.selesai >= p_dari and a.mulai <= p_sampai then return next a.mulai; end if;
    return;
  end if;
  v_int := coalesce((u->>'interval')::int, 1); v_frek := u->>'frek';
  v_akhir := least(p_sampai, coalesce((u->>'sampai')::date, p_sampai));
  if v_frek = 'pekanan' then
    w := a.mulai - extract(dow from a.mulai)::int;          -- Ahad pada pekan tanggal mulai
    while w <= v_akhir and i < 3000 loop
      for h in select x::int from jsonb_array_elements_text(u->'hari') x order by x::int loop
        d := w + h;
        if d >= a.mulai and d <= v_akhir then
          n := n + 1;
          exit when (u ? 'kali') and n > (u->>'kali')::int;
          if d + v_lama >= p_dari and not (d = any (a.pengecualian)) then return next d; end if;
        end if;
      end loop;
      exit when (u ? 'kali') and n >= (u->>'kali')::int;
      w := w + 7 * v_int; i := i + 1;
    end loop;
    return;
  end if;
  loop
    d := case v_frek when 'harian' then a.mulai + i * v_int
                     when 'bulanan' then (a.mulai + make_interval(months => i * v_int))::date
                     else (a.mulai + make_interval(years => i * v_int))::date end;
    exit when d > v_akhir or i > 3000;
    n := n + 1;
    exit when (u ? 'kali') and n > (u->>'kali')::int;
    if d + v_lama >= p_dari and not (d = any (a.pengecualian)) then return next d; end if;
    i := i + 1;
  end loop;
end $$;

/** Lewati satu tanggal kejadian agenda berulang (tidak tampil dan tidak diingatkan). */
create or replace function public.lewati_kejadian_agenda(p_id uuid, p_tanggal date)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  if not public.boleh_kelola_agenda() then raise exception 'Anda tidak berwenang mengubah agenda.' using errcode = '42501'; end if;
  update agendas set pengecualian = array(select distinct x from unnest(pengecualian || p_tanggal) x order by x) where id = p_id and ulang is not null;
  if not found then raise exception 'Agenda berulang tidak ditemukan.'; end if;
  insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
  select t.employee_id, 'Agenda ditiadakan: ' || a.judul, 'Kegiatan tanggal ' || to_char(p_tanggal, 'DD/MM/YYYY') || ' tidak dilaksanakan.', '/agenda/' || a.id, 'CalendarStar', 'jingga'
    from agenda_targets t join agendas a on a.id = t.agenda_id where t.agenda_id = p_id;
end $$;

-- ---------------------------------------------------------------------
-- 2. Simpan agenda (dengan warna, tautan, lampiran, berulang, pengingat menit)
-- ---------------------------------------------------------------------
create or replace function public.simpan_agenda(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid := nullif(p->>'id', '')::uuid; a agendas; v_n int; v_sasaran jsonb := coalesce(p->'sasaran', '{"jenis":"semua"}');
        v_jenis text := coalesce(nullif(p->>'jenis', ''), 'kegiatan'); v_hol uuid;
        v_menit int[] := coalesce((select array_agg(distinct x::int order by x::int desc) from jsonb_array_elements_text(p->'pengingat_menit') x where x::int between 0 and 43200), '{}');
        v_ulang jsonb := public._rapikan_ulang(p->'ulang', (p->>'mulai')::date);
begin
  if not public.boleh_kelola_agenda() then raise exception 'Anda tidak berwenang mengelola agenda.' using errcode = '42501'; end if;
  if length(trim(coalesce(p->>'judul', ''))) < 3 then raise exception 'Judul agenda minimal 3 karakter.'; end if;
  if (p->>'selesai')::date < (p->>'mulai')::date then raise exception 'Tanggal selesai tidak boleh sebelum tanggal mulai.'; end if;
  if v_jenis = 'libur' and v_ulang is not null then raise exception 'Agenda libur tidak dapat dibuat berulang. Buat per tanggal libur.'; end if;
  if nullif(trim(coalesce(p->>'tautan', '')), '') is not null and p->>'tautan' !~ '^https?://' then raise exception 'Tautan harus diawali https://'; end if;
  if v_jenis = 'libur' and not public.admin_boleh('kalender') then
    raise exception 'Agenda libur mengubah kalender pondok; hanya admin ber-izin kalender dan superadmin yang dapat membuatnya.' using errcode = '42501';
  end if;

  if v_id is not null then
    select * into a from agendas where id = v_id;
    if not found then raise exception 'Agenda tidak ditemukan.'; end if;
    update agendas set judul = trim(p->>'judul'), keterangan = nullif(trim(coalesce(p->>'keterangan', '')), ''), jenis = v_jenis,
           mulai = (p->>'mulai')::date, selesai = (p->>'selesai')::date, jam_mulai = nullif(p->>'jam_mulai', '')::time,
           jam_selesai = nullif(p->>'jam_selesai', '')::time, lokasi = nullif(trim(coalesce(p->>'lokasi', '')), ''),
           pengingat_menit = v_menit, ulang = v_ulang, warna = coalesce(nullif(p->>'warna', ''), warna),
           tautan = nullif(trim(coalesce(p->>'tautan', '')), ''), nama_tautan = nullif(trim(coalesce(p->>'nama_tautan', '')), ''),
           lampiran_id = case when p ? 'lampiran_id' then nullif(p->>'lampiran_id', '')::uuid else lampiran_id end
     where id = v_id;
    -- tanggal, jam, atau pola berulang berubah: pengingat dijadwalkan ulang dan penerima diberi tahu
    if a.mulai <> (p->>'mulai')::date or a.jam_mulai is distinct from nullif(p->>'jam_mulai', '')::time or a.ulang is distinct from v_ulang then
      delete from agenda_reminder_log where agenda_id = v_id;
      insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
      select t.employee_id, 'Agenda diubah: ' || trim(p->>'judul'), 'Jadwal baru ' || to_char((p->>'mulai')::date, 'DD/MM/YYYY') || '.',
             '/agenda/' || v_id, 'CalendarStar', 'jingga' from agenda_targets t where t.agenda_id = v_id;
    end if;
  else
    insert into agendas (judul, keterangan, jenis, mulai, selesai, jam_mulai, jam_selesai, lokasi, sasaran, ringkasan_sasaran, pengingat, dibuat_oleh,
                         pengingat_menit, ulang, warna, tautan, nama_tautan, lampiran_id)
    values (trim(p->>'judul'), nullif(trim(coalesce(p->>'keterangan', '')), ''), v_jenis, (p->>'mulai')::date, (p->>'selesai')::date,
            nullif(p->>'jam_mulai', '')::time, nullif(p->>'jam_selesai', '')::time, nullif(trim(coalesce(p->>'lokasi', '')), ''),
            v_sasaran, public.ringkas_sasaran(v_sasaran), '{}', public.saya(),
            v_menit, v_ulang, coalesce(nullif(p->>'warna', ''), case v_jenis when 'libur' then 'tomat' when 'rapat' then 'lavender' else 'merak' end),
            nullif(trim(coalesce(p->>'tautan', '')), ''), nullif(trim(coalesce(p->>'nama_tautan', '')), ''), nullif(p->>'lampiran_id', '')::uuid)
    returning id into v_id;
    insert into agenda_targets (agenda_id, employee_id) select v_id, x from public.penerima_sasaran(v_sasaran) x on conflict do nothing;
    get diagnostics v_n = row_count;
    if v_n = 0 then raise exception 'Sasaran yang dipilih tidak memiliki penerima (pegawai aktif berakun).'; end if;
    insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
    select t.employee_id, case when v_jenis = 'libur' then 'Hari libur: ' else 'Agenda baru: ' end || trim(p->>'judul'),
           coalesce(public.ringkas_ulang(v_ulang) || ' mulai ', '') || to_char((p->>'mulai')::date, 'DD/MM/YYYY') || case when (p->>'selesai')::date > (p->>'mulai')::date then ' s.d. ' || to_char((p->>'selesai')::date, 'DD/MM/YYYY') else '' end
             || coalesce(' pukul ' || to_char(nullif(p->>'jam_mulai', '')::time, 'HH24.MI'), '') || coalesce(' · ' || nullif(trim(coalesce(p->>'lokasi', '')), ''), ''),
           '/agenda/' || v_id, 'CalendarStar', case when v_jenis = 'libur' then 'merah' else 'jingga' end
      from agenda_targets t where t.agenda_id = v_id and t.employee_id is distinct from public.saya();
  end if;

  -- Sinkron dengan kalender libur pondok
  select holiday_id into v_hol from agendas where id = v_id;
  if v_jenis = 'libur' then
    if v_hol is null then
      insert into holidays (tanggal_mulai, tanggal_akhir, nama, jenis, berlaku_untuk, dibuat_oleh)
      values ((p->>'mulai')::date, (p->>'selesai')::date, trim(p->>'judul'), coalesce(nullif(p->>'jenis_libur', ''), 'libur_pondok'),
              coalesce((select array_agg(x) from jsonb_array_elements_text(p->'berlaku_untuk') x), '{semua}'), public.saya())
      returning id into v_hol;
      update agendas set holiday_id = v_hol where id = v_id;
    else
      update holidays set tanggal_mulai = (p->>'mulai')::date, tanggal_akhir = (p->>'selesai')::date, nama = trim(p->>'judul'),
             jenis = coalesce(nullif(p->>'jenis_libur', ''), jenis),
             berlaku_untuk = coalesce((select array_agg(x) from jsonb_array_elements_text(p->'berlaku_untuk') x), berlaku_untuk)
       where id = v_hol;
    end if;
  elsif v_hol is not null then
    update agendas set holiday_id = null where id = v_id;
    delete from holidays where id = v_hol;
  end if;
  return v_id;
end $$;

-- ---------------------------------------------------------------------
-- 3. Kalender: setiap kejadian agenda + hari libur
-- ---------------------------------------------------------------------
drop function if exists public.kalender_saya(date, date, boolean);
create or replace function public.kalender_saya(p_mulai date, p_akhir date, p_kelola boolean default false)
returns table (id uuid, sumber text, judul text, keterangan text, jenis text, mulai date, selesai date, jam_mulai time, jam_selesai time,
               lokasi text, ringkasan_sasaran text, pengingat int[], berlaku_untuk text[], jenis_libur text, pembuat text, penerima int, holiday_id uuid,
               warna text, tautan text, nama_tautan text, lampiran_id uuid, nama_lampiran text, ulang jsonb, ringkasan_ulang text,
               mulai_seri date, selesai_seri date, pengingat_menit int[])
language sql stable security definer set search_path = public as $$
  select a.id, 'agenda', a.judul, a.keterangan, a.jenis, k.d, k.d + (a.selesai - a.mulai), a.jam_mulai, a.jam_selesai, a.lokasi, a.ringkasan_sasaran, a.pengingat,
         h.berlaku_untuk, h.jenis, e.nama_lengkap,
         case when p_kelola and public.boleh_kelola_agenda() then (select count(*)::int from agenda_targets x where x.agenda_id = a.id) end, a.holiday_id,
         a.warna, a.tautan, a.nama_tautan, a.lampiran_id, o.nama_berkas, a.ulang, public.ringkas_ulang(a.ulang), a.mulai, a.selesai, a.pengingat_menit
    from agendas a
    cross join lateral public.kejadian_agenda(a, p_mulai, p_akhir) k(d)
    left join holidays h on h.id = a.holiday_id left join employees e on e.id = a.dibuat_oleh left join storage_objects o on o.id = a.lampiran_id
   where ((p_kelola and public.boleh_kelola_agenda()) or exists (select 1 from agenda_targets t where t.agenda_id = a.id and t.employee_id = public.saya()))
     and p_akhir - p_mulai <= 400
  union all
  select h.id, 'libur', h.nama, null, 'libur', h.tanggal_mulai, h.tanggal_akhir, null, null, null, null, null, h.berlaku_untuk, h.jenis, null, null, h.id,
         'tomat', null, null, null, null, null, null, h.tanggal_mulai, h.tanggal_akhir, null
    from holidays h
   where h.tanggal_akhir >= p_mulai and h.tanggal_mulai <= p_akhir and h.jenis <> 'tanpa_sesi'
     and not exists (select 1 from agendas a where a.holiday_id = h.id)
  order by 6, 8 nulls first
$$;

-- ---------------------------------------------------------------------
-- 4. Pengingat (tiap 5 menit)
-- ---------------------------------------------------------------------
create or replace function public.label_pengingat(p_menit int, p_seharian boolean)
returns text language sql immutable as $$
  select case
    when p_menit = 0 then case when p_seharian then 'Hari ini: ' else 'Dimulai sekarang: ' end
    when p_menit < 60 then p_menit || ' menit lagi: '
    when p_menit < 1440 and p_menit % 60 = 0 then (p_menit / 60) || ' jam lagi: '
    when p_menit < 1440 then (p_menit / 60) || ' jam ' || (p_menit % 60) || ' menit lagi: '
    when p_menit = 1440 then 'Besok: '
    when p_menit % 1440 = 0 then 'H-' || (p_menit / 1440) || ': '
    else round(p_menit / 1440.0, 1) || ' hari lagi: ' end
$$;

create or replace function public.kirim_pengingat_agenda()
returns int language plpgsql volatile security definer set search_path = public as $$
declare a agendas; d date; m int; v_mulai timestamptz; n int := 0; c int; v_hari date := public.hari_ini();
begin
  for a in select * from agendas g where cardinality(g.pengingat_menit) > 0
              and (g.ulang is not null or g.mulai between v_hari - 1 and v_hari + 31) loop
    for d in select * from public.kejadian_agenda(a, v_hari - 1, v_hari + 31) loop
      v_mulai := (d + coalesce(a.jam_mulai, time '06:00')) at time zone 'Asia/Makassar';
      foreach m in array a.pengingat_menit loop
        -- kirim dalam jendela 2 jam setelah waktunya tiba (pengingat yang terlewat jauh tidak dikirim)
        if now() >= v_mulai - make_interval(mins => m) and now() < v_mulai - make_interval(mins => m) + interval '2 hours'
           and not exists (select 1 from agenda_reminder_log l where l.agenda_id = a.id and l.tanggal = d and l.menit = m) then
          insert into agenda_reminder_log (agenda_id, tanggal, menit) values (a.id, d, m) on conflict do nothing;
          insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
          select t.employee_id, public.label_pengingat(m, a.jam_mulai is null) || a.judul,
                 to_char(d, 'DD/MM/YYYY') || coalesce(' pukul ' || to_char(a.jam_mulai, 'HH24.MI'), '') || coalesce(' · ' || a.lokasi, '')
                   || case when a.tautan is not null then ' · ' || coalesce(a.nama_tautan, 'tautan tersedia') else '' end,
                 '/agenda/' || a.id || '?tanggal=' || d, 'CalendarStar', case when a.jenis = 'libur' then 'merah' else 'jingga' end
            from agenda_targets t join employees e on e.id = t.employee_id
           where t.agenda_id = a.id and e.status_akun = 'aktif';
          get diagnostics c = row_count; n := n + c;
        end if;
      end loop;
    end loop;
  end loop;
  delete from agenda_reminder_log where tanggal < v_hari - 60;
  return n;
end $$;
select cron.schedule('pengingat-agenda', '*/5 * * * *', $$ select public.kirim_pengingat_agenda() $$);

-- ---------------------------------------------------------------------
-- 5. Lampiran agenda dapat dibuka penerima; beranda memakai kejadian agenda
-- ---------------------------------------------------------------------
create or replace function public.boleh_lihat_berkas(p_obj uuid, p_emp uuid)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare r leave_requests; v_peran text; j journal_entries;
  izin boolean := false;
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
  return false;
end $$;

create or replace function public.ringkasan_beranda()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_saya uuid := public.saya(); v_hari date := public.hari_ini(); v jsonb := '{}'; v_pimpinan boolean; v_jurnal jsonb;
begin
  if v_saya is null then return '{}'; end if;

  -- ---------- Pribadi ----------
  select jsonb_build_object(
      'wajib', public.wajib_jurnal(v_saya, v_hari),
      'butir_total', (select count(*) from public.butir_jurnal(v_saya)),
      'butir_selesai', (select count(*) from journal_checks c where c.employee_id = v_saya and c.tanggal = v_hari),
      'kegiatan', (select count(*) from journal_entries e where e.employee_id = v_saya and e.tanggal = v_hari),
      'dikembalikan', (select count(*) from journal_entries e where e.employee_id = v_saya and e.status = 'dikembalikan'
                         and e.diverval_pada > now() - interval '7 days'),
      'kemarin_kosong', public.wajib_jurnal(v_saya, v_hari - 1)
                         and not exists (select 1 from journal_checks c where c.employee_id = v_saya and c.tanggal = v_hari - 1)
                         and not exists (select 1 from journal_entries e where e.employee_id = v_saya and e.tanggal = v_hari - 1))
    into v_jurnal;

  v := v || jsonb_build_object('pribadi', jsonb_build_object(
    'jurnal', v_jurnal,
    'pengajuan_menunggu', (select count(*) from leave_requests r where r.employee_id = v_saya and r.status = 'menunggu'),
    'pengajuan_terakhir', (select jsonb_build_object('id', r.id, 'jenis', t.nama, 'status', r.status, 'mulai', r.mulai, 'selesai', r.selesai,
                              'jenjang', (select public.nama_peran_jenjang(a.peran) from leave_approvals a where a.request_id = r.id and a.urutan = r.langkah_ke))
                             from leave_requests r join leave_types t on t.id = r.leave_type_id
                            where r.employee_id = v_saya and r.status in ('menunggu','disetujui') and r.selesai >= v_hari
                            order by r.mulai limit 1),
    'sedang_cuti', (select t.nama || ' s.d. ' || to_char(r.selesai, 'DD/MM/YYYY') from leave_requests r join leave_types t on t.id = r.leave_type_id
                     where r.employee_id = v_saya and r.status = 'disetujui' and v_hari between r.mulai and r.selesai limit 1),
    'cuti_sisa', (select jsonb_build_object('nama', t.nama, 'kuota', t.kuota_tahunan_hari,
                     'sisa', greatest(t.kuota_tahunan_hari - (select hari_tahun from public.pemakaian_pengajuan(v_saya, t.id, v_hari)), 0))
                    from leave_types t where t.kode = 'CUTI_TAHUNAN' and t.aktif and t.kuota_tahunan_hari is not null),
    'agenda', (select coalesce(jsonb_agg(x order by x->>'mulai', x->>'jam_mulai'), '[]') from (
                 select jsonb_build_object('id', k.id, 'judul', k.judul, 'jenis', k.jenis, 'mulai', k.mulai, 'selesai', k.selesai,
                          'jam_mulai', k.jam_mulai, 'lokasi', k.lokasi, 'warna', k.warna) x
                   from public.kalender_saya(v_hari, v_hari + 60, false) k
                  where k.sumber = 'agenda' and k.selesai >= v_hari order by k.mulai, k.jam_mulai nulls first limit 3) q),
    'libur_berikut', (select jsonb_build_object('nama', h.nama, 'mulai', h.tanggal_mulai, 'selesai', h.tanggal_akhir)
                        from holidays h where h.tanggal_akhir >= v_hari and h.jenis <> 'tanpa_sesi' order by h.tanggal_mulai limit 1),
    'pengumuman_belum', (select count(*) from announcement_targets t join announcements a on a.id = t.announcement_id
                          where t.employee_id = v_saya and t.dibaca_pada is null and (a.tampil_sampai is null or a.tampil_sampai >= v_hari)),
    'pengumuman_terbaru', (select jsonb_build_object('id', a.id, 'judul', a.judul, 'penting', a.penting, 'created_at', a.created_at, 'dibaca', t.dibaca_pada is not null)
                             from announcements a join announcement_targets t on t.announcement_id = a.id and t.employee_id = v_saya
                            where a.tampil_sampai is null or a.tampil_sampai >= v_hari
                            order by a.penting desc, a.created_at desc limit 1),
    'berkas_baru', (select count(*) from employee_document_targets t where t.employee_id = v_saya and t.dibuka_pertama is null)));

  -- ---------- Pimpinan (pejabat struktural atau Plt yang memimpin unit) ----------
  v_pimpinan := exists (select 1 from public.pemegang_jabatan(v_hari) h where h.employee_id = v_saya
                         and h.kode in ('DIREKTUR','WAKIL_DIREKTUR','YAYASAN','KEPALA_BIDANG','KEPALA_UNIT'));
  if v_pimpinan then
    v := v || jsonb_build_object('pimpinan', (
      with anggota as (
        select e.id, e.nama_lengkap, e.org_unit_id from employees e
         where e.status_keaktifan = 'aktif' and e.status_akun = 'aktif' and e.id <> v_saya and public.pimpinan_dari(e.id)
      ), wajib as (
        select a.id, public.wajib_jurnal(a.id, v_hari) w from anggota a
      )
      select jsonb_build_object(
        'persetujuan_menunggu', (select count(*) from leave_requests r join leave_approvals ap on ap.request_id = r.id and ap.urutan = r.langkah_ke
                                  where r.status = 'menunggu' and exists (select 1 from public.calon_penyetuju(r.employee_id, ap.peran) c where c.employee_id = v_saya)),
        'anggota', (select count(*) from anggota),
        'hadir', (select count(distinct x.employee_id) from attendances x join anggota a on a.id = x.employee_id
                   where x.tanggal = v_hari and x.status in ('hadir','terlambat','dinas_luar')),
        'terlambat', (select count(distinct x.employee_id) from attendances x join anggota a on a.id = x.employee_id where x.tanggal = v_hari and x.status = 'terlambat'),
        'jurnal_wajib', (select count(*) from wajib where w),
        'jurnal_terisi', (select count(*) from wajib j where j.w and (exists (select 1 from journal_checks c where c.employee_id = j.id and c.tanggal = v_hari)
                            or exists (select 1 from journal_entries e where e.employee_id = j.id and e.tanggal = v_hari and e.status <> 'dikembalikan'))),
        'tidak_hadir', (select coalesce(jsonb_agg(jsonb_build_object('nama', a.nama_lengkap, 'jenis', t.nama, 'selesai', r.selesai) order by a.nama_lengkap), '[]')
                          from leave_requests r join anggota a on a.id = r.employee_id join leave_types t on t.id = r.leave_type_id
                         where r.status = 'disetujui' and v_hari between r.mulai and r.selesai))
    ));
  end if;

  -- ---------- Pengelola (admin/superadmin) ----------
  if public.is_admin() then
    v := v || jsonb_build_object('kelola', jsonb_build_object(
      'verval_jurnal', case when public.admin_boleh('verval_jurnal') then (select count(*) from journal_entries where status = 'menunggu') end,
      'pengajuan_menunggu', case when public.admin_boleh('lihat_pengajuan') then (select count(*) from leave_requests where status = 'menunggu') end,
      'pengajuan_bulan_ini', case when public.admin_boleh('lihat_pengajuan') then (select count(*) from leave_requests where status = 'disetujui' and date_trunc('month', mulai) = date_trunc('month', v_hari::timestamp)) end,
      'sedang_izin', (select count(distinct employee_id) from leave_requests where status = 'disetujui' and v_hari between mulai and selesai),
      'agenda_bulan_ini', (select count(*) from public.kalender_saya(date_trunc('month', v_hari::timestamp)::date, (date_trunc('month', v_hari::timestamp) + interval '1 month - 1 day')::date, true) k where k.sumber = 'agenda'),
      'agenda_pekan_ini', (select count(*) from public.kalender_saya(v_hari, v_hari + 6, true) k where k.sumber = 'agenda'),
      'berkas_belum_dibuka', case when public.admin_boleh('kelola_berkas') then (select count(*) from employee_document_targets where dibuka_pertama is null) end,
      'kartu_terbit', (select count(*) from employee_cards),
      'tanpa_niy', (select count(*) from employees where status_keaktifan = 'aktif' and nullif(trim(coalesce(niy, '')), '') is null),
      'tanpa_foto', (select count(*) from employees where status_keaktifan = 'aktif' and status_akun = 'aktif' and foto_id is null),
      'perangkat_push', (select count(distinct employee_id) from push_subscriptions),
      'akun_aktif', (select count(*) from employees where status_akun = 'aktif'),
      'jurnal_hari_ini', (select count(distinct employee_id) from (select employee_id from journal_checks where tanggal = v_hari
                           union select employee_id from journal_entries where tanggal = v_hari) q),
      'pengumuman_aktif', (select count(*) from announcements where tampil_sampai is null or tampil_sampai >= v_hari)));
  end if;
  return v;
end $$;

do $$
declare f text;
begin
  revoke execute on function public.kirim_pengingat_agenda() from public, anon, authenticated;
  revoke execute on function public.boleh_lihat_berkas(uuid,uuid) from public, anon, authenticated;
  grant execute on function public.boleh_lihat_berkas(uuid,uuid) to service_role;
  foreach f in array array['simpan_agenda(jsonb)','kalender_saya(date,date,boolean)','lewati_kejadian_agenda(uuid,date)','ringkasan_beranda()']
  loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 5 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select 'Kolom agenda lanjutan (7)' as pemeriksaan,
       case when (select count(*) from information_schema.columns where table_name = 'agendas'
                   and column_name in ('pengingat_menit','ulang','pengecualian','warna','tautan','nama_tautan','lampiran_id')) = 7 then 'Sesuai' else 'Periksa' end as hasil
union all
select 'Fungsi kejadian agenda berulang',
       case when exists (select 1 from pg_proc where proname = 'kejadian_agenda') then 'Sesuai' else 'Periksa' end
union all
select 'Pengingat agenda tiap 5 menit',
       case when exists (select 1 from cron.job where jobname = 'pengingat-agenda' and schedule = '*/5 * * * *') then 'Sesuai' else 'Periksa' end
union all
select 'Log pengingat dengan RLS',
       case when exists (select 1 from pg_tables where tablename = 'agenda_reminder_log' and rowsecurity) then 'Sesuai' else 'Periksa' end
union all
select 'Migrasi 2500 sudah terpasang',
       case when exists (select 1 from pg_tables where tablename = 'employee_groups') then 'Sesuai' else 'Periksa: jalankan 2500 dulu' end;
