-- SIMKA PRO | supabase/migrations/20261004002300_agenda_template_wa.sql | v1.0 | Fase 3 – Tahap 5 Agenda dan template WA | 04/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 3 · Migrasi 23: Agenda, pengingat, dan template WA
--   * agendas + agenda_targets : agenda dengan sasaran; agenda berjenis libur otomatis masuk kalender libur pondok
--   * kirim_pengingat_agenda() : pengingat H-7/H-3/H-1/hari H (dapat diubah per agenda) lewat notifikasi dan HP
--   * kalender_saya(...)       : agenda yang ditujukan kepada pegawai + hari libur pondok untuk kalender bulanan
--   * wa_templates             : template pesan WhatsApp dengan isian {nama} dan sebagainya (dikelola superadmin)
-- Jalankan SETELAH migrasi 2200. Aman dijalankan ulang.
-- =====================================================================

insert into public.admin_capabilities (kode, nama, urutan) values
  ('kelola_agenda', 'Membuat dan mengelola agenda beserta pengingatnya (Fase 3)', 14)
on conflict (kode) do nothing;

-- ---------------------------------------------------------------------
-- 1. Agenda
-- ---------------------------------------------------------------------
create table if not exists public.agendas (
  id                uuid primary key default gen_random_uuid(),
  judul             text not null check (length(trim(judul)) between 3 and 150),
  keterangan        text,
  jenis             text not null default 'kegiatan' check (jenis in ('kegiatan','rapat','libur','lainnya')),
  mulai             date not null,
  selesai           date not null,
  jam_mulai         time,
  jam_selesai       time,
  lokasi            text,
  sasaran           jsonb not null default '{"jenis":"semua"}',
  ringkasan_sasaran text,
  pengingat         int[] not null default '{7,3,1,0}',
  holiday_id        uuid references public.holidays(id) on delete set null,
  dibuat_oleh       uuid references public.employees(id) on delete set null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  check (selesai >= mulai),
  check (jam_selesai is null or jam_mulai is null or jam_selesai > jam_mulai or selesai > mulai)
);
create index if not exists agendas_tanggal_idx on public.agendas (mulai, selesai);
create table if not exists public.agenda_targets (
  agenda_id   uuid not null references public.agendas(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  primary key (agenda_id, employee_id)
);
create index if not exists agenda_targets_emp_idx on public.agenda_targets (employee_id);
create table if not exists public.agenda_reminders_sent (
  agenda_id   uuid not null references public.agendas(id) on delete cascade,
  h           int not null,
  dikirim_pada timestamptz not null default now(),
  primary key (agenda_id, h)
);

alter table public.agendas enable row level security;
alter table public.agenda_targets enable row level security;
alter table public.agenda_reminders_sent enable row level security;
drop trigger if exists aa_updated on public.agendas;
create trigger aa_updated before update on public.agendas for each row execute function public.tg_updated_at();
drop trigger if exists zz_audit on public.agendas;
create trigger zz_audit after insert or update or delete on public.agendas for each row execute function public.tg_audit();

create or replace function public.boleh_kelola_agenda()
returns boolean language sql stable security definer set search_path = public as $$
  select public.admin_boleh('kelola_agenda')
$$;
drop policy if exists baca on public.agendas;
create policy baca on public.agendas for select to authenticated
  using (public.boleh_kelola_agenda() or exists (select 1 from agenda_targets t where t.agenda_id = agendas.id and t.employee_id = public.saya()));
drop policy if exists baca on public.agenda_targets;
create policy baca on public.agenda_targets for select to authenticated
  using (employee_id = public.saya() or public.boleh_kelola_agenda());

/** Simpan agenda. Agenda baru: penerima dihitung dari sasaran dan diberi notifikasi. Jenis libur juga menulis kalender libur pondok. */
create or replace function public.simpan_agenda(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid := nullif(p->>'id', '')::uuid; a agendas; v_n int; v_sasaran jsonb := coalesce(p->'sasaran', '{"jenis":"semua"}');
        v_jenis text := coalesce(nullif(p->>'jenis', ''), 'kegiatan'); v_hol uuid;
        v_pengingat int[] := coalesce((select array_agg(distinct x::int order by x::int desc) from jsonb_array_elements_text(p->'pengingat') x where x::int between 0 and 30), '{}');
begin
  if not public.boleh_kelola_agenda() then raise exception 'Anda tidak berwenang mengelola agenda.' using errcode = '42501'; end if;
  if length(trim(coalesce(p->>'judul', ''))) < 3 then raise exception 'Judul agenda minimal 3 karakter.'; end if;
  if (p->>'selesai')::date < (p->>'mulai')::date then raise exception 'Tanggal selesai tidak boleh sebelum tanggal mulai.'; end if;
  if v_jenis = 'libur' and not public.admin_boleh('kalender') then
    raise exception 'Agenda libur mengubah kalender pondok; hanya admin ber-izin kalender dan superadmin yang dapat membuatnya.' using errcode = '42501';
  end if;

  if v_id is not null then
    select * into a from agendas where id = v_id;
    if not found then raise exception 'Agenda tidak ditemukan.'; end if;
    update agendas set judul = trim(p->>'judul'), keterangan = nullif(trim(coalesce(p->>'keterangan', '')), ''), jenis = v_jenis,
           mulai = (p->>'mulai')::date, selesai = (p->>'selesai')::date, jam_mulai = nullif(p->>'jam_mulai', '')::time,
           jam_selesai = nullif(p->>'jam_selesai', '')::time, lokasi = nullif(trim(coalesce(p->>'lokasi', '')), ''), pengingat = v_pengingat
     where id = v_id;
    -- tanggal berubah: pengingat yang sudah terkirim diulang sesuai tanggal baru
    if a.mulai <> (p->>'mulai')::date then
      delete from agenda_reminders_sent where agenda_id = v_id;
      insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
      select t.employee_id, 'Agenda diubah: ' || trim(p->>'judul'), 'Jadwal baru ' || to_char((p->>'mulai')::date, 'DD/MM/YYYY') || '.',
             '/agenda/' || v_id, 'CalendarStar', 'jingga' from agenda_targets t where t.agenda_id = v_id;
    end if;
  else
    insert into agendas (judul, keterangan, jenis, mulai, selesai, jam_mulai, jam_selesai, lokasi, sasaran, ringkasan_sasaran, pengingat, dibuat_oleh)
    values (trim(p->>'judul'), nullif(trim(coalesce(p->>'keterangan', '')), ''), v_jenis, (p->>'mulai')::date, (p->>'selesai')::date,
            nullif(p->>'jam_mulai', '')::time, nullif(p->>'jam_selesai', '')::time, nullif(trim(coalesce(p->>'lokasi', '')), ''),
            v_sasaran, public.ringkas_sasaran(v_sasaran), v_pengingat, public.saya())
    returning id into v_id;
    insert into agenda_targets (agenda_id, employee_id) select v_id, x from public.penerima_sasaran(v_sasaran) x on conflict do nothing;
    get diagnostics v_n = row_count;
    if v_n = 0 then raise exception 'Sasaran yang dipilih tidak memiliki penerima (pegawai aktif berakun).'; end if;
    insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
    select t.employee_id, case when v_jenis = 'libur' then 'Hari libur: ' else 'Agenda baru: ' end || trim(p->>'judul'),
           to_char((p->>'mulai')::date, 'DD/MM/YYYY') || case when (p->>'selesai')::date > (p->>'mulai')::date then ' s.d. ' || to_char((p->>'selesai')::date, 'DD/MM/YYYY') else '' end
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

create or replace function public.hapus_agenda(p_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v_hol uuid;
begin
  if not public.boleh_kelola_agenda() then raise exception 'Anda tidak berwenang menghapus agenda.' using errcode = '42501'; end if;
  delete from agendas where id = p_id returning holiday_id into v_hol;
  if v_hol is not null then delete from holidays where id = v_hol; end if;
  delete from notifications where tautan = '/agenda/' || p_id;
end $$;

/** Kalender: agenda yang ditujukan kepada saya (atau semua untuk pengelola) dan hari libur pondok pada rentang tanggal. */
create or replace function public.kalender_saya(p_mulai date, p_akhir date, p_kelola boolean default false)
returns table (id uuid, sumber text, judul text, keterangan text, jenis text, mulai date, selesai date, jam_mulai time, jam_selesai time,
               lokasi text, ringkasan_sasaran text, pengingat int[], berlaku_untuk text[], jenis_libur text, pembuat text, penerima int, holiday_id uuid)
language sql stable security definer set search_path = public as $$
  select a.id, 'agenda', a.judul, a.keterangan, a.jenis, a.mulai, a.selesai, a.jam_mulai, a.jam_selesai, a.lokasi, a.ringkasan_sasaran, a.pengingat,
         h.berlaku_untuk, h.jenis, e.nama_lengkap,
         case when p_kelola and public.boleh_kelola_agenda() then (select count(*)::int from agenda_targets x where x.agenda_id = a.id) end, a.holiday_id
    from agendas a left join holidays h on h.id = a.holiday_id left join employees e on e.id = a.dibuat_oleh
   where a.selesai >= p_mulai and a.mulai <= p_akhir
     and ((p_kelola and public.boleh_kelola_agenda()) or exists (select 1 from agenda_targets t where t.agenda_id = a.id and t.employee_id = public.saya()))
  union all
  select h.id, 'libur', h.nama, null, 'libur', h.tanggal_mulai, h.tanggal_akhir, null, null, null, null, null, h.berlaku_untuk, h.jenis, null, null, h.id
    from holidays h
   where h.tanggal_akhir >= p_mulai and h.tanggal_mulai <= p_akhir and h.jenis <> 'tanpa_sesi'
     and not exists (select 1 from agendas a where a.holiday_id = h.id)
  order by 6, 8 nulls first
$$;

/** Penerima agenda beserta nomor HP (pengelola agenda; untuk tombol WA). */
create or replace function public.penerima_agenda(p_id uuid)
returns table (employee_id uuid, nama text, no_hp text, unit text)
language sql stable security definer set search_path = public as $$
  select e.id, e.nama_lengkap, e.no_hp, u.nama
    from agenda_targets t join employees e on e.id = t.employee_id left join org_units u on u.id = e.org_unit_id
   where t.agenda_id = p_id and public.boleh_kelola_agenda()
   order by u.nama nulls last, e.nama_lengkap
$$;

/** Pengingat terjadwal (pg_cron tiap pagi 06.00 WITA): kirim notifikasi H-n sesuai daftar pengingat setiap agenda. */
create or replace function public.kirim_pengingat_agenda()
returns int language plpgsql volatile security definer set search_path = public as $$
declare a agendas; v_h int; n int := 0; v_hari int; m int;
begin
  for a in select * from agendas where mulai >= public.hari_ini() and mulai <= public.hari_ini() + 30 and cardinality(pengingat) > 0 loop
    v_hari := a.mulai - public.hari_ini();
    foreach v_h in array a.pengingat loop
      if v_h = v_hari and not exists (select 1 from agenda_reminders_sent s where s.agenda_id = a.id and s.h = v_h) then
        insert into agenda_reminders_sent (agenda_id, h) values (a.id, v_h);
        insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
        select t.employee_id,
               case when v_h = 0 then 'Hari ini: ' when v_h = 1 then 'Besok: ' else 'H-' || v_h || ': ' end || a.judul,
               to_char(a.mulai, 'DD/MM/YYYY') || coalesce(' pukul ' || to_char(a.jam_mulai, 'HH24.MI'), '') || coalesce(' · ' || a.lokasi, ''),
               '/agenda/' || a.id, 'CalendarStar', case when a.jenis = 'libur' then 'merah' else 'jingga' end
          from agenda_targets t join employees e on e.id = t.employee_id
         where t.agenda_id = a.id and e.status_akun = 'aktif';
        get diagnostics m = row_count; n := n + m;
      end if;
    end loop;
  end loop;
  return n;
end $$;
select cron.schedule('pengingat-agenda', '0 22 * * *', $$ select public.kirim_pengingat_agenda() $$);   -- 22.00 UTC = 06.00 WITA

-- ---------------------------------------------------------------------
-- 2. Template WA
-- ---------------------------------------------------------------------
create table if not exists public.wa_templates (
  kode       text primary key check (kode ~ '^[a-z0-9_]{2,40}$'),
  nama       text not null,
  isi        text not null,
  variabel   text[] not null default '{}',     -- isian yang tersedia, mis. {nama}
  keterangan text,
  aktif      boolean not null default true,
  updated_at timestamptz not null default now()
);
alter table public.wa_templates enable row level security;
drop policy if exists baca on public.wa_templates;
create policy baca on public.wa_templates for select to authenticated using (true);
drop policy if exists kelola on public.wa_templates;
create policy kelola on public.wa_templates for all to authenticated using (public.is_superadmin()) with check (public.is_superadmin());
drop trigger if exists aa_updated on public.wa_templates;
create trigger aa_updated before update on public.wa_templates for each row execute function public.tg_updated_at();
drop trigger if exists zz_audit on public.wa_templates;
create trigger zz_audit after insert or update or delete on public.wa_templates for each row execute function public.tg_audit();

insert into public.wa_templates (kode, nama, isi, variabel, keterangan) values
  ('aktivasi', 'Akun diaktifkan',
   E'Assalamu''alaikum warahmatullahi wabarakatuh, {nama}.\n\nAkun SIMKA PRO Anda telah aktif. Silakan masuk di {alamat_aplikasi} dengan username *{username}* dan kata sandi yang Anda buat saat mendaftar.\n\nJazakumullahu khairan.\nAdmin SIMKA PRO Imam Asy-Syathiby',
   '{nama,username,alamat_aplikasi}', 'Dikirim admin dari Verifikasi Akun saat akun disetujui.'),
  ('ditolak', 'Pendaftaran ditolak',
   E'Assalamu''alaikum warahmatullahi wabarakatuh, {nama}.\n\nPendaftaran akun SIMKA PRO Anda belum dapat disetujui dengan catatan: {catatan}\n\nSilakan hubungi admin pondok untuk keterangan lebih lanjut.\nAdmin SIMKA PRO Imam Asy-Syathiby',
   '{nama,catatan}', 'Dikirim admin dari Verifikasi Akun saat pendaftaran ditolak.'),
  ('sandi_sementara', 'Kata sandi sementara',
   E'Assalamu''alaikum warahmatullahi wabarakatuh, {nama}.\n\nKata sandi sementara akun SIMKA PRO Anda:\nUsername: *{username}*\nKata sandi: *{sandi}*\n\nSilakan masuk di {alamat_aplikasi} lalu ganti kata sandi saat diminta. Jangan bagikan pesan ini kepada siapa pun.\nAdmin SIMKA PRO Imam Asy-Syathiby',
   '{nama,username,sandi,alamat_aplikasi}', 'Dikirim admin setelah mengatur ulang kata sandi.'),
  ('undangan_agenda', 'Undangan/pengingat agenda',
   E'Assalamu''alaikum warahmatullahi wabarakatuh, {nama}.\n\nMengingatkan agenda *{judul}*\nHari/tanggal: {tanggal}\nWaktu: {waktu}\nTempat: {lokasi}\n\n{keterangan}\n\nJazakumullahu khairan.\n{pengirim}',
   '{nama,judul,tanggal,waktu,lokasi,keterangan,pengirim}', 'Tombol WA di rincian agenda.'),
  ('pengajuan_disetujui', 'Pengajuan disetujui',
   E'Assalamu''alaikum warahmatullahi wabarakatuh, {nama}.\n\nPengajuan {jenis} Anda tanggal {tanggal} telah disetujui (nomor {nomor}). Surat dapat diunduh di menu Pengajuan SIMKA PRO: {alamat_aplikasi}\n\nJazakumullahu khairan.',
   '{nama,jenis,tanggal,nomor,alamat_aplikasi}', 'Tombol WA di rincian pengajuan (pengelola).'),
  ('umum', 'Pesan umum kepada pegawai',
   E'Assalamu''alaikum warahmatullahi wabarakatuh, {nama}.\n\n{pesan}\n\nJazakumullahu khairan.\n{pengirim}',
   '{nama,pesan,pengirim}', 'Pesan bebas dari admin.')
on conflict (kode) do nothing;

-- ---------------------------------------------------------------------
-- 3. Hak eksekusi
-- ---------------------------------------------------------------------
do $$
declare f text;
begin
  execute 'revoke execute on function public.kirim_pengingat_agenda() from public, anon, authenticated';
  foreach f in array array['boleh_kelola_agenda()','simpan_agenda(jsonb)','hapus_agenda(uuid)','kalender_saya(date,date,boolean)','penerima_agenda(uuid)']
  loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
grant select on public.agendas, public.agenda_targets to authenticated;
grant select, insert, update, delete on public.wa_templates to authenticated;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 5 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select 'Tabel agenda dan template WA (4)' as pemeriksaan,
       case when count(*) = 4 then 'Sesuai' else 'Periksa: ' || count(*) end as hasil
  from pg_tables where schemaname = 'public' and tablename in ('agendas','agenda_targets','agenda_reminders_sent','wa_templates')
union all
select 'RLS aktif di tabel baru',
       case when bool_and(rowsecurity) then 'Sesuai' else 'Periksa' end
  from pg_tables where schemaname = 'public' and tablename in ('agendas','agenda_targets','agenda_reminders_sent','wa_templates')
union all
select 'Template WA isi awal (minimal 6)',
       case when count(*) >= 6 then 'Sesuai' else 'Periksa: ' || count(*) end from public.wa_templates
union all
select 'Jadwal pengingat agenda pg_cron',
       case when exists (select 1 from cron.job where jobname = 'pengingat-agenda') then 'Sesuai' else 'Periksa' end
union all
select 'Migrasi 2200 sudah terpasang',
       case when exists (select 1 from pg_proc where proname = 'cek_kartu') then 'Sesuai' else 'Periksa: jalankan 2200 dulu' end;
