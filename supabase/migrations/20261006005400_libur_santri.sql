-- SIMKA PRO | supabase/migrations/20261006005400_libur_santri.sql | v1.0 | Fase 7 – Tahap 3 Libur santri | 06/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 7 · Migrasi 54: Penentuan Libur Santri (Blueprint Bagian 23)
--   * holiday_periods: periode libur (bulanan/semester/khusus) dengan waktu pulang, batas kembali, rentang hitung,
--     sasaran (jenjang, jenis kelamin), dan SYARAT yang dapat diatur (holiday_criteria disatukan dalam kolom syarat):
--     kehadiran kelas/halaqah/asrama minimal (%), izin keluar maksimal, terlambat kembali maksimal, tambahan hafalan minimal,
--     rentang pertimbangan (margin), izin/sakit tidak mengurangi persentase.
--   * holiday_eligibility: hasil penilaian per santri (boleh / tidak / pertimbangan) lengkap dengan angka; keputusan dapat
--     diubah dengan alasan. Ekskul tidak dihitung (Bagian 18).
--   * Pengesahan sekali oleh Kepala Bidang Kesantrian, Direktur/Wadir, Plt, atau superadmin → setiap santri yang boleh libur
--     otomatis mendapat izin jenis "libur" (gerbang hijau, absensi otomatis Izin). Perubahan setelah disahkan ikut
--     memperbarui izinnya. Pembatalan periode membatalkan izin libur yang belum dipakai keluar.
--   * Daftar Perizinan "Aktif" tidak dipenuhi izin libur yang belum dipakai (hanya yang sudah keluar).
-- Jalankan SETELAH migrasi 5300. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. IZIN JENIS LIBUR, IZIN ADMIN, PENGATURAN BAWAAN
-- ---------------------------------------------------------------------
alter table public.student_permits drop constraint if exists student_permits_jenis_check;
alter table public.student_permits add constraint student_permits_jenis_check check (jenis in ('pulang','keluar','libur'));
alter table public.student_permits drop constraint if exists student_permits_sumber_check;
alter table public.student_permits add constraint student_permits_sumber_check check (sumber in ('pengasuh','klinik','admin','cepat','libur'));

insert into public.admin_capabilities (kode, nama, urutan) values
  ('kelola_libur', 'Mengelola libur santri: periode, syarat, penilaian, perubahan keputusan (Fase 7)', 35)
on conflict (kode) do nothing;

create or replace function public.syarat_libur_bawaan()
returns jsonb language sql stable security definer set search_path = public as $$
  select '{"kelas_min": 85, "halaqah_min": 85, "asrama_min": 85, "izin_maks": 2, "terlambat_maks": null,
           "hafalan_min_halaman": 0, "margin": 5, "abaikan_izin_sakit": true}'::jsonb
         || coalesce((select nilai from institution_settings where kunci = 'libur'), '{}'::jsonb)
$$;

-- ---------------------------------------------------------------------
-- 2. TABEL
-- ---------------------------------------------------------------------
create table if not exists public.holiday_periods (
  id              uuid primary key default gen_random_uuid(),
  nama            text not null,
  jenis           text not null default 'bulanan' check (jenis in ('bulanan','semester','khusus')),
  pulang_pada     timestamptz not null,
  kembali_batas   timestamptz not null,
  hitung_mulai    date not null,
  hitung_selesai  date not null,
  jenjang         text[] not null default '{}',
  jenis_kelamin   text check (jenis_kelamin in ('L','P')),
  syarat          jsonb not null default '{}'::jsonb,
  status          text not null default 'draf' check (status in ('draf','dinilai','disahkan','batal')),
  dinilai_pada    timestamptz,
  disahkan_oleh   uuid references public.employees(id) on delete set null,
  disahkan_pada   timestamptz,
  catatan         text,
  dibuat_oleh     uuid references public.employees(id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint hp_waktu check (kembali_batas > pulang_pada),
  constraint hp_hitung check (hitung_selesai >= hitung_mulai)
);
create table if not exists public.holiday_eligibility (
  id              uuid primary key default gen_random_uuid(),
  period_id       uuid not null references public.holiday_periods(id) on delete cascade,
  student_id      uuid not null references public.students(id) on delete cascade,
  otomatis        text not null check (otomatis in ('boleh','tidak','pertimbangan')),
  keputusan       text check (keputusan in ('boleh','tidak')),
  diubah          boolean not null default false,
  alasan_ubah     text,
  diubah_oleh     uuid references public.employees(id) on delete set null,
  diubah_pada     timestamptz,
  rincian         jsonb not null default '{}'::jsonb,
  permit_id       uuid references public.student_permits(id) on delete set null,
  created_at      timestamptz not null default now(),
  unique (period_id, student_id)
);
create index if not exists he_period_idx on public.holiday_eligibility (period_id);

do $$
declare t text;
begin
  foreach t in array array['holiday_periods','holiday_eligibility'] loop
    execute format('drop trigger if exists zz_audit on public.%I', t);
    execute format('create trigger zz_audit after insert or update or delete on public.%I for each row execute function public.tg_audit()', t);
    execute format('alter table public.%I enable row level security', t);
    begin execute format('alter publication supabase_realtime add table public.%I', t); exception when others then null; end;
  end loop;
end $$;
drop trigger if exists aa_updated on public.holiday_periods;
create trigger aa_updated before update on public.holiday_periods for each row execute function public.tg_updated_at();

-- ---------------------------------------------------------------------
-- 3. HAK
-- ---------------------------------------------------------------------
/** Mengelola libur: superadmin, admin ber-izin kelola_libur/kelola_izin_santri, pejabat pemutus izin Kesantrian (termasuk Plt). */
create or replace function public.boleh_kelola_libur()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_superadmin() or public.admin_boleh('kelola_libur') or public.admin_boleh('kelola_izin_santri')
      or public.boleh_putus_izin('KESANTRIAN', 1)
$$;
/** Mengesahkan daftar final: Kepala Bidang Kesantrian, Direktur/Wadir, Plt, superadmin. */
create or replace function public.boleh_sahkan_libur()
returns boolean language sql stable security definer set search_path = public as $$
  select public.boleh_putus_izin('KESANTRIAN', 1)
$$;
create or replace function public.boleh_lihat_libur()
returns boolean language sql stable security definer set search_path = public as $$
  select public.boleh_kelola_libur() or public.boleh_lihat_security()
$$;
create or replace function public.hak_libur()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('kelola', public.boleh_kelola_libur(), 'sahkan', public.boleh_sahkan_libur(), 'lihat', public.boleh_lihat_libur(),
    'pengasuh', exists (select 1 from public.kelompok_saya() k join student_groups g on g.id = k where g.jenis in ('kamar','kelas','halaqah')))
$$;

drop policy if exists baca on public.holiday_periods;
create policy baca on public.holiday_periods for select to authenticated using (public.boleh_lihat_libur() or status = 'disahkan');
drop policy if exists baca on public.holiday_eligibility;
create policy baca on public.holiday_eligibility for select to authenticated
  using (public.boleh_lihat_libur() or (student_id in (select public.santri_terlihat())
         and exists (select 1 from holiday_periods h where h.id = period_id and h.status = 'disahkan')));

/** Simpan syarat bawaan (Ketentuan libur). */
create or replace function public.simpan_syarat_libur(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
begin
  if not public.boleh_kelola_libur() then raise exception 'Anda tidak berwenang mengubah syarat libur.' using errcode = '42501'; end if;
  insert into institution_settings (kunci, nilai, updated_by) values ('libur', public._syarat_libur_bersih(p), public.saya())
  on conflict (kunci) do update set nilai = excluded.nilai, updated_at = now(), updated_by = excluded.updated_by;
  return public.syarat_libur_bawaan();
end $$;

/** Normalisasi syarat: angka persen 0–100 atau null (tidak dipakai), maksimal izin/terlambat ≥ 0 atau null. */
create or replace function public._syarat_libur_bersih(p jsonb)
returns jsonb language plpgsql immutable as $$
declare v jsonb := '{}'::jsonb; k text; n numeric;
begin
  foreach k in array array['kelas_min','halaqah_min','asrama_min','margin'] loop
    n := nullif(p->>k, '')::numeric;
    if n is not null and (n < 0 or n > 100) then raise exception 'Nilai % harus 0–100.', replace(k, '_', ' '); end if;
    v := v || jsonb_build_object(k, n);
  end loop;
  foreach k in array array['izin_maks','terlambat_maks','hafalan_min_halaman'] loop
    n := nullif(p->>k, '')::numeric;
    if n is not null and (n < 0 or n > 600) then raise exception 'Nilai % tidak valid.', replace(k, '_', ' '); end if;
    v := v || jsonb_build_object(k, n);
  end loop;
  return v || jsonb_build_object('margin', coalesce((v->>'margin')::numeric, 5), 'abaikan_izin_sakit', coalesce((p->>'abaikan_izin_sakit')::boolean, true));
end $$;

-- ---------------------------------------------------------------------
-- 4. PERIODE
-- ---------------------------------------------------------------------
create or replace function public.simpan_periode_libur(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid := nullif(p->>'id', '')::uuid; v_status text; v_pulang timestamptz := (p->>'pulang_pada')::timestamptz;
        v_kembali timestamptz := (p->>'kembali_batas')::timestamptz;
begin
  if not public.boleh_kelola_libur() then raise exception 'Anda tidak berwenang mengelola libur santri.' using errcode = '42501'; end if;
  if length(trim(coalesce(p->>'nama', ''))) < 3 then raise exception 'Isi nama periode libur.'; end if;
  if v_pulang is null or v_kembali is null or v_kembali <= v_pulang then raise exception 'Batas kembali harus setelah waktu pulang.'; end if;
  if (p->>'hitung_mulai')::date is null or (p->>'hitung_selesai')::date < (p->>'hitung_mulai')::date then raise exception 'Rentang hitung tidak valid.'; end if;
  if v_id is not null then
    select status into v_status from holiday_periods where id = v_id;
    if v_status is null then raise exception 'Periode tidak ditemukan.'; end if;
    if v_status in ('disahkan','batal') then raise exception 'Periode yang sudah disahkan atau dibatalkan tidak dapat diubah.'; end if;
    update holiday_periods set nama = trim(p->>'nama'), jenis = coalesce(nullif(p->>'jenis', ''), 'bulanan'), pulang_pada = v_pulang, kembali_batas = v_kembali,
           hitung_mulai = (p->>'hitung_mulai')::date, hitung_selesai = (p->>'hitung_selesai')::date,
           jenjang = coalesce(array(select jsonb_array_elements_text(coalesce(p->'jenjang', '[]'::jsonb))), '{}'),
           jenis_kelamin = nullif(p->>'jenis_kelamin', ''), syarat = public._syarat_libur_bersih(coalesce(p->'syarat', '{}'::jsonb)),
           catatan = nullif(trim(coalesce(p->>'catatan', '')), ''), status = 'draf'
     where id = v_id;
  else
    insert into holiday_periods (nama, jenis, pulang_pada, kembali_batas, hitung_mulai, hitung_selesai, jenjang, jenis_kelamin, syarat, catatan, dibuat_oleh)
    values (trim(p->>'nama'), coalesce(nullif(p->>'jenis', ''), 'bulanan'), v_pulang, v_kembali, (p->>'hitung_mulai')::date, (p->>'hitung_selesai')::date,
            coalesce(array(select jsonb_array_elements_text(coalesce(p->'jenjang', '[]'::jsonb))), '{}'), nullif(p->>'jenis_kelamin', ''),
            public._syarat_libur_bersih(coalesce(p->'syarat', public.syarat_libur_bawaan())), nullif(trim(coalesce(p->>'catatan', '')), ''), public.saya())
    returning id into v_id;
  end if;
  return v_id;
end $$;

/** Hitung kehadiran program pokok (kelas, halaqah, asrama) semua santri pada rentang, tanpa saringan hak pemanggil. */
create or replace function public._kehadiran_pokok(p_mulai date, p_selesai date)
returns table (student_id uuid, jenis text, sesi int, izin_sakit int, tidak_hadir int)
language sql stable security definer set search_path = public as $$
  with sesi as (
    select sa.id, sa.group_id, sa.jenis, sa.tanggal from student_attendance_sessions sa
     where sa.tanggal between p_mulai and p_selesai and sa.jenis in ('kelas','halaqah','asrama')
  ), ikut as (
    select s.id sid, s.jenis, a.x student_id from sesi s cross join lateral (select x from public._anggota_pada(s.group_id, s.tanggal) x) a
  )
  select i.student_id, i.jenis, count(*)::int,
         count(*) filter (where e.kode in ('I','S'))::int, count(*) filter (where e.kode in ('A','B'))::int
    from ikut i left join student_attendance_exceptions e on e.session_id = i.sid and e.student_id = i.student_id
   group by i.student_id, i.jenis
$$;

/** Nilai (ulang) semua santri sasaran. Keputusan yang sudah diubah manual dipertahankan. */
create or replace function public.nilai_libur(p_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare h holiday_periods%rowtype; sy jsonb; r record; v_r jsonb; v_hasil text; v_gagal text[]; v_timbang text[]; v_p numeric; v_min numeric;
        v_mg numeric; k text; v_n int := 0; v_keg jsonb; v_izin int; v_telat int; v_hfz int; v_abaikan boolean;
begin
  if not public.boleh_kelola_libur() then raise exception 'Anda tidak berwenang menilai libur santri.' using errcode = '42501'; end if;
  select * into h from holiday_periods where id = p_id for update;
  if h.id is null then raise exception 'Periode tidak ditemukan.'; end if;
  if h.status in ('disahkan','batal') then raise exception 'Periode yang sudah disahkan atau dibatalkan tidak dinilai ulang.'; end if;
  sy := h.syarat; v_mg := coalesce((sy->>'margin')::numeric, 5); v_abaikan := coalesce((sy->>'abaikan_izin_sakit')::boolean, true);
  create temp table if not exists _hadir_libur (student_id uuid, jenis text, sesi int, izin_sakit int, tidak_hadir int) on commit drop;
  truncate _hadir_libur;
  insert into _hadir_libur select * from public._kehadiran_pokok(h.hitung_mulai, h.hitung_selesai);
  -- Santri yang tidak lagi termasuk sasaran dihapus (bila belum diubah manual)
  delete from holiday_eligibility e where e.period_id = p_id and not exists (
    select 1 from students s where s.id = e.student_id and s.status = 'aktif'
       and (cardinality(h.jenjang) = 0 or s.jenjang = any (h.jenjang)) and (h.jenis_kelamin is null or s.jenis_kelamin = h.jenis_kelamin));
  for r in select s.id from students s where s.status = 'aktif'
             and (cardinality(h.jenjang) = 0 or s.jenjang = any (h.jenjang)) and (h.jenis_kelamin is null or s.jenis_kelamin = h.jenis_kelamin)
  loop
    v_keg := '{}'::jsonb; v_gagal := '{}'; v_timbang := '{}';
    foreach k in array array['kelas','halaqah','asrama'] loop
      select case when x.sesi - (case when v_abaikan then x.izin_sakit else 0 end) > 0
                  then round(100.0 * (x.sesi - x.izin_sakit - x.tidak_hadir) / (x.sesi - (case when v_abaikan then x.izin_sakit else 0 end)), 1) end,
             jsonb_build_object('sesi', x.sesi, 'izin_sakit', x.izin_sakit, 'tidak_hadir', x.tidak_hadir)
        into v_p, v_r from (select coalesce(sum(hl.sesi), 0)::int sesi, coalesce(sum(hl.izin_sakit), 0)::int izin_sakit, coalesce(sum(hl.tidak_hadir), 0)::int tidak_hadir
                              from _hadir_libur hl where hl.student_id = r.id and hl.jenis = k) x;
      v_keg := v_keg || jsonb_build_object(k, v_r || jsonb_build_object('persen', v_p));
      v_min := nullif(sy->>(k || '_min'), '')::numeric;
      if v_min is not null and v_p is not null and v_p < v_min then
        if v_p >= v_min - v_mg then v_timbang := v_timbang || (initcap(k) || ' ' || v_p || '% (min ' || v_min || '%)');
        else v_gagal := v_gagal || (initcap(k) || ' ' || v_p || '% (min ' || v_min || '%)'); end if;
      end if;
    end loop;
    select count(*) filter (where p.jenis in ('pulang','keluar')), count(*) filter (where p.kembali_pada > p.kembali_batas)
      into v_izin, v_telat from student_permits p
     where p.student_id = r.id and p.status in ('keluar','kembali') and p.jenis <> 'libur'
       and (coalesce(p.keluar_aktual, p.keluar_pada) at time zone 'Asia/Makassar')::date between h.hitung_mulai and h.hitung_selesai;
    if nullif(sy->>'izin_maks', '') is not null and v_izin > (sy->>'izin_maks')::int then
      if v_izin = (sy->>'izin_maks')::int + 1 then v_timbang := v_timbang || ('Izin keluar ' || v_izin || ' kali (maks ' || (sy->>'izin_maks') || ')');
      else v_gagal := v_gagal || ('Izin keluar ' || v_izin || ' kali (maks ' || (sy->>'izin_maks') || ')'); end if;
    end if;
    if nullif(sy->>'terlambat_maks', '') is not null and v_telat > (sy->>'terlambat_maks')::int then
      if v_telat = (sy->>'terlambat_maks')::int + 1 then v_timbang := v_timbang || ('Terlambat kembali ' || v_telat || ' kali (maks ' || (sy->>'terlambat_maks') || ')');
      else v_gagal := v_gagal || ('Terlambat kembali ' || v_telat || ' kali (maks ' || (sy->>'terlambat_maks') || ')'); end if;
    end if;
    select coalesce(sum(tambah_hal), 0)::int into v_hfz from memorization_logs where student_id = r.id and tanggal between h.hitung_mulai and h.hitung_selesai;
    if coalesce(nullif(sy->>'hafalan_min_halaman', '')::numeric, 0) > 0 and v_hfz < (sy->>'hafalan_min_halaman')::numeric then
      v_timbang := v_timbang || ('Tambahan hafalan ' || v_hfz || ' hal (min ' || (sy->>'hafalan_min_halaman') || ')');
    end if;
    v_hasil := case when cardinality(v_gagal) > 0 then 'tidak' when cardinality(v_timbang) > 0 then 'pertimbangan' else 'boleh' end;
    v_r := v_keg || jsonb_build_object('izin', v_izin, 'terlambat', v_telat, 'hafalan', v_hfz, 'gagal', to_jsonb(v_gagal), 'timbang', to_jsonb(v_timbang));
    insert into holiday_eligibility (period_id, student_id, otomatis, keputusan, rincian)
    values (p_id, r.id, v_hasil, case when v_hasil = 'pertimbangan' then null else v_hasil end, v_r)
    on conflict (period_id, student_id) do update set otomatis = excluded.otomatis, rincian = excluded.rincian,
       keputusan = case when holiday_eligibility.diubah then holiday_eligibility.keputusan else excluded.keputusan end;
    v_n := v_n + 1;
  end loop;
  update holiday_periods set status = 'dinilai', dinilai_pada = now() where id = p_id;
  return public.ringkasan_periode_libur(p_id);
end $$;

create or replace function public.ringkasan_periode_libur(p_id uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('jumlah', count(*), 'boleh', count(*) filter (where keputusan = 'boleh'), 'tidak', count(*) filter (where keputusan = 'tidak'),
    'belum', count(*) filter (where keputusan is null), 'pertimbangan', count(*) filter (where otomatis = 'pertimbangan'),
    'diubah', count(*) filter (where diubah), 'izin_dibuat', count(*) filter (where permit_id is not null))
    from holiday_eligibility where period_id = p_id
$$;

/** Buat atau batalkan izin libur satu santri sesuai keputusan (dipakai saat pengesahan dan perubahan setelah disahkan). */
create or replace function public._selaraskan_izin_libur(p_elig uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare e holiday_eligibility%rowtype; h holiday_periods%rowtype; v_pid uuid; v_lama int; v_sebagai text;
begin
  select * into e from holiday_eligibility where id = p_elig for update;
  select * into h from holiday_periods where id = e.period_id;
  if e.keputusan = 'boleh' and (e.permit_id is null or not exists (select 1 from student_permits where id = e.permit_id and status in ('disetujui','keluar','kembali'))) then
    -- Santri sedang di luar dengan izin lain: tidak dibuatkan izin libur (dicatat di rincian)
    if exists (select 1 from student_permits where student_id = e.student_id and status = 'keluar') then
      update holiday_eligibility set rincian = rincian || '{"catatan_izin": "Santri sedang di luar dengan izin lain saat disahkan."}' where id = e.id;
      return;
    end if;
    v_lama := greatest(1, ceil(extract(epoch from (h.kembali_batas - h.pulang_pada)) / 86400.0)::int);
    insert into student_permits (student_id, jenis, alasan, keluar_pada, kembali_batas, lama_hari, sumber, pengusul_id, peran_pengusul, unit_kode, perlu_pimpinan, status, catatan)
    values (e.student_id, 'libur', h.nama, h.pulang_pada, h.kembali_batas, v_lama, 'libur', coalesce(h.disahkan_oleh, public.saya()), 'pimpinan', 'KESANTRIAN', false, 'disetujui',
            'Izin libur otomatis dari periode ' || h.nama)
    returning id into v_pid;
    v_sebagai := case when h.disahkan_oleh in (select public._pimpinan_puncak()) then 'Direktur/Wakil Direktur'
                      when h.disahkan_oleh in (select public._pejabat_unit('KESANTRIAN', 30)) then 'Kepala Bidang Kesantrian' else 'Pengesah libur' end;
    insert into student_permit_approvals (permit_id, tingkat, keputusan, oleh, sebagai, catatan) values (v_pid, 1, 'setuju', h.disahkan_oleh, v_sebagai, 'Pengesahan libur');
    update holiday_eligibility set permit_id = v_pid where id = e.id;
  elsif e.keputusan is distinct from 'boleh' and e.permit_id is not null then
    update student_permits set status = 'dibatalkan', catatan = trim(coalesce(catatan || E'\n', '') || 'Keputusan libur diubah menjadi tidak libur.')
     where id = e.permit_id and status = 'disetujui';
  end if;
end $$;

/** Ubah keputusan satu santri (alasan wajib). Setelah disahkan, izin libur ikut dibuat/dibatalkan. */
create or replace function public.ubah_keputusan_libur(p_id uuid, p_keputusan text, p_alasan text)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare e holiday_eligibility%rowtype; v_status text;
begin
  if not public.boleh_kelola_libur() then raise exception 'Anda tidak berwenang mengubah keputusan libur.' using errcode = '42501'; end if;
  if p_keputusan not in ('boleh','tidak') then raise exception 'Keputusan harus boleh atau tidak.'; end if;
  select * into e from holiday_eligibility where id = p_id for update;
  if e.id is null then raise exception 'Data santri pada periode ini tidak ditemukan.'; end if;
  select status into v_status from holiday_periods where id = e.period_id;
  if v_status = 'batal' then raise exception 'Periode sudah dibatalkan.'; end if;
  if (p_keputusan <> e.otomatis or e.diubah or v_status = 'disahkan') and length(trim(coalesce(p_alasan, ''))) < 5 then
    raise exception 'Tuliskan alasan perubahan keputusan (minimal 5 huruf).';
  end if;
  if v_status = 'disahkan' and not public.boleh_sahkan_libur() then
    raise exception 'Setelah disahkan, perubahan hanya oleh Kepala Bidang Kesantrian, Direktur/Wadir, Plt, atau superadmin.' using errcode = '42501';
  end if;
  if e.keputusan = 'boleh' and p_keputusan = 'tidak' and exists (select 1 from student_permits where id = e.permit_id and status in ('keluar','kembali')) then
    raise exception 'Santri ini sudah keluar dengan izin libur; keputusan tidak dapat diubah.';
  end if;
  update holiday_eligibility set keputusan = p_keputusan, diubah = (p_keputusan <> otomatis) or (otomatis = 'pertimbangan'),
         alasan_ubah = nullif(trim(coalesce(p_alasan, '')), ''), diubah_oleh = public.saya(), diubah_pada = now() where id = p_id;
  if v_status = 'disahkan' then perform public._selaraskan_izin_libur(p_id); end if;
  return public.ringkasan_periode_libur(e.period_id);
end $$;

create or replace function public.sahkan_libur(p_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare h holiday_periods%rowtype; r record; v_belum int;
begin
  if not public.boleh_sahkan_libur() then
    raise exception 'Pengesahan libur oleh Kepala Bidang Kesantrian, Direktur/Wadir, Plt, atau superadmin.' using errcode = '42501';
  end if;
  select * into h from holiday_periods where id = p_id for update;
  if h.id is null then raise exception 'Periode tidak ditemukan.'; end if;
  if h.status <> 'dinilai' then raise exception 'Nilai periode terlebih dahulu sebelum disahkan.'; end if;
  select count(*) into v_belum from holiday_eligibility where period_id = p_id and keputusan is null;
  if v_belum > 0 then raise exception 'Masih ada % santri berstatus perlu pertimbangan yang belum diputuskan.', v_belum; end if;
  if h.kembali_batas <= now() then raise exception 'Batas kembali periode ini sudah lewat.'; end if;
  update holiday_periods set status = 'disahkan', disahkan_oleh = public.saya(), disahkan_pada = now() where id = p_id;
  for r in select id from holiday_eligibility where period_id = p_id and keputusan = 'boleh' loop
    perform public._selaraskan_izin_libur(r.id);
  end loop;
  -- Kabari Security dan setiap pengasuh (satu notifikasi per orang)
  insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
  select x, 'Daftar libur disahkan: ' || h.nama,
         (select count(*) from holiday_eligibility where period_id = p_id and keputusan = 'boleh') || ' santri libur, '
         || (select count(*) from holiday_eligibility where period_id = p_id and keputusan = 'tidak') || ' tinggal. Pulang '
         || to_char(h.pulang_pada at time zone 'Asia/Makassar', 'DD/MM HH24.MI') || ', kembali ' || to_char(h.kembali_batas at time zone 'Asia/Makassar', 'DD/MM HH24.MI') || ' WITA.',
         '/security/gerbang', 'CalendarCheck', 'hijau'
    from public._petugas_security() x where x is distinct from public.saya();
  insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
  select q.emp, 'Libur santri asuhan: ' || h.nama, q.boleh || ' santri asuhan Anda libur, ' || q.tidak || ' tinggal di pondok.', '/izin-santri/libur', 'CalendarCheck', 'hijau'
    from (select ps.emp, count(*) filter (where e.keputusan = 'boleh') boleh, count(*) filter (where e.keputusan = 'tidak') tidak
            from holiday_eligibility e cross join lateral (select x emp from public._pengasuh_santri(e.student_id) x) ps
           where e.period_id = p_id group by ps.emp) q
   where q.emp is distinct from public.saya();
  return public.ringkasan_periode_libur(p_id);
end $$;

create or replace function public.batalkan_libur(p_id uuid, p_alasan text)
returns void language plpgsql volatile security definer set search_path = public as $$
declare h holiday_periods%rowtype;
begin
  select * into h from holiday_periods where id = p_id for update;
  if h.id is null then raise exception 'Periode tidak ditemukan.'; end if;
  if h.status = 'disahkan' and not public.boleh_sahkan_libur() then raise exception 'Pembatalan periode yang sudah disahkan oleh pejabat pengesah.' using errcode = '42501'; end if;
  if h.status <> 'disahkan' and not public.boleh_kelola_libur() then raise exception 'Anda tidak berwenang.' using errcode = '42501'; end if;
  if length(trim(coalesce(p_alasan, ''))) < 5 then raise exception 'Tuliskan alasan pembatalan (minimal 5 huruf).'; end if;
  update student_permits set status = 'dibatalkan', catatan = trim(coalesce(catatan || E'\n', '') || 'Periode libur dibatalkan: ' || trim(p_alasan))
   where id in (select permit_id from holiday_eligibility where period_id = p_id and permit_id is not null) and status = 'disetujui';
  update holiday_periods set status = 'batal', catatan = trim(coalesce(catatan || E'\n', '') || 'Dibatalkan: ' || trim(p_alasan)) where id = p_id;
end $$;

-- ---------------------------------------------------------------------
-- 5. DAFTAR DAN DETAIL
-- ---------------------------------------------------------------------
create or replace function public._periode_libur_json(p_id uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select to_jsonb(h) || jsonb_build_object('ringkasan', public.ringkasan_periode_libur(h.id), 'pengesah', e.nama_lengkap, 'pembuat', b.nama_lengkap,
    'selesai', h.status = 'disahkan' and h.kembali_batas < now())
    from holiday_periods h left join employees e on e.id = h.disahkan_oleh left join employees b on b.id = h.dibuat_oleh where h.id = p_id
$$;

create or replace function public.daftar_periode_libur()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if public.saya() is null then return '[]'::jsonb; end if;
  return coalesce((select jsonb_agg(public._periode_libur_json(h.id) order by h.pulang_pada desc) from holiday_periods h
    where public.boleh_lihat_libur() or (h.status = 'disahkan' and exists (select 1 from holiday_eligibility e where e.period_id = h.id
                                                                               and e.student_id in (select public.santri_terlihat())))), '[]'::jsonb);
end $$;

create or replace function public.detail_libur(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_semua boolean := public.boleh_lihat_libur(); h holiday_periods%rowtype;
begin
  select * into h from holiday_periods where id = p_id;
  if h.id is null then raise exception 'Periode tidak ditemukan.'; end if;
  if not v_semua and h.status <> 'disahkan' then raise exception 'Anda tidak berwenang melihat periode ini.' using errcode = '42501'; end if;
  return public._periode_libur_json(p_id) || jsonb_build_object('santri', coalesce((select jsonb_agg(jsonb_build_object(
      'id', e.id, 'student_id', s.id, 'nama', s.nama_lengkap, 'nis', s.nis, 'jenis_kelamin', s.jenis_kelamin, 'jenjang', s.jenjang,
      'kelas', public._kelompok_santri(s.id, 'kelas'), 'kamar', public._kelompok_santri(s.id, 'kamar'), 'halaqah', public._kelompok_santri(s.id, 'halaqah'),
      'otomatis', e.otomatis, 'keputusan', e.keputusan, 'diubah', e.diubah, 'alasan_ubah', e.alasan_ubah, 'pengubah', u.nama_lengkap, 'rincian', e.rincian,
      'permit_id', e.permit_id, 'status_izin', p.status,
      'wali', (select jsonb_build_object('nama', c.nama, 'no_hp', c.no_hp, 'hubungan', c.hubungan) from student_contacts c
                where c.student_id = s.id and c.no_hp is not null order by c.utama desc, c.hubungan limit 1))
      order by s.jenjang, public._kelompok_santri(s.id, 'kelas'), s.nama_lengkap)
    from holiday_eligibility e join students s on s.id = e.student_id left join employees u on u.id = e.diubah_oleh
    left join student_permits p on p.id = e.permit_id
   where e.period_id = p_id and (v_semua or e.student_id in (select public.santri_terlihat()))), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------
-- 6. DAFTAR IZIN: izin libur yang belum dipakai tidak memenuhi tab "Aktif"/"Menunggu"
-- ---------------------------------------------------------------------
create or replace function public.daftar_izin(p_cakupan text, p_mulai date default null, p_selesai date default null, p_group uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_mulai date := coalesce(p_mulai, public.hari_ini() - 30); v_selesai date := coalesce(p_selesai, public.hari_ini() + 30);
begin
  if public.saya() is null then return '[]'::jsonb; end if;
  return coalesce((select jsonb_agg(x order by x->>'urut', x->>'keluar_pada' desc) from (
    select jsonb_build_object('id', p.id, 'student_id', p.student_id, 'nama', s.nama_lengkap, 'nis', s.nis, 'jenis_kelamin', s.jenis_kelamin,
      'kelas', public._kelompok_santri(s.id, 'kelas'), 'kamar', public._kelompok_santri(s.id, 'kamar'),
      'jenis', p.jenis, 'alasan', p.alasan, 'penjemput', p.penjemput, 'hubungan_penjemput', p.hubungan_penjemput, 'hp_penjemput', p.hp_penjemput,
      'keluar_pada', p.keluar_pada, 'kembali_batas', p.kembali_batas, 'lama_hari', p.lama_hari, 'sumber', p.sumber,
      'peran_pengusul', p.peran_pengusul, 'pengusul', e.nama_lengkap, 'unit_kode', p.unit_kode, 'pemutus', public._label_unit_izin(p.unit_kode),
      'perlu_pimpinan', p.perlu_pimpinan, 'status', p.status, 'keluar_aktual', p.keluar_aktual, 'kembali_pada', p.kembali_pada,
      'catatan', p.catatan, 'created_at', p.created_at,
      'terlambat', (p.status = 'keluar' and now() > p.kembali_batas) or (p.status = 'kembali' and p.kembali_pada > p.kembali_batas),
      'boleh_putus', (p.status = 'diajukan' and public.boleh_putus_izin(p.unit_kode, 1)) or (p.status = 'disetujui_bidang' and public.boleh_putus_izin(p.unit_kode, 2)),
      'boleh_ubah', p.status = 'diajukan' and (p.pengusul_id = public.saya() or public.boleh_putus_izin(p.unit_kode, 1) or public.boleh_kelola_izin()),
      'boleh_batal', p.status in ('diajukan','disetujui_bidang','disetujui') and (p.pengusul_id = public.saya() or public.boleh_kelola_izin() or public.boleh_putus_izin(p.unit_kode, 1)),
      'boleh_catat', p.status in ('disetujui','keluar') and public.boleh_gerbang(),
      'terlambat_menit', case when p.status = 'kembali' and p.kembali_pada > p.kembali_batas then floor(extract(epoch from (p.kembali_pada - p.kembali_batas)) / 60)::int end,
      'keputusan', coalesce((select jsonb_agg(jsonb_build_object('tingkat', a.tingkat, 'keputusan', a.keputusan, 'sebagai', a.sebagai, 'oleh', ae.nama_lengkap,
                    'catatan', a.catatan, 'pada', a.pada) order by a.pada) from student_permit_approvals a left join employees ae on ae.id = a.oleh
                    where a.permit_id = p.id), '[]'::jsonb),
      'urut', case when p.status in ('diajukan','disetujui_bidang') then '0' when p.status = 'keluar' and now() > p.kembali_batas then '1'
                   when p.status in ('disetujui','keluar') then '2' else '3' end) x
      from student_permits p join students s on s.id = p.student_id left join employees e on e.id = p.pengusul_id
     where public.boleh_lihat_izin(p.student_id, p.unit_kode)
       and (p_group is null or p.student_id in (select m.student_id from group_members m where m.group_id = p_group and m.selesai is null))
       and case p_cakupan
             when 'persetujuan' then (p.status = 'diajukan' and public.boleh_putus_izin(p.unit_kode, 1)) or (p.status = 'disetujui_bidang' and public.boleh_putus_izin(p.unit_kode, 2))
             when 'menunggu' then p.status in ('diajukan','disetujui_bidang')
             when 'aktif' then p.status = 'keluar' or (p.status = 'disetujui' and p.jenis <> 'libur')
             when 'semua' then ((p.keluar_pada at time zone 'Asia/Makassar')::date between v_mulai and v_selesai
                               or p.status in ('diajukan','disetujui_bidang','disetujui','keluar'))
                               and (p.jenis <> 'libur' or p.status in ('keluar','kembali'))
             else false end) q), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- 7. TEMPLATE WA
-- ---------------------------------------------------------------------
insert into public.wa_templates (kode, nama, isi, variabel, keterangan) values
  ('libur_santri', 'Libur santri ke wali',
   E'{salam}, Bapak/Ibu {nama_wali}.\n\nKami informasikan bahwa pada *{periode_libur}* ananda *{nama_santri}* ({kelas}) *{status_libur}*.\n• Pulang: {waktu_pulang}\n• Batas kembali: {batas_kembali}\n{keterangan}\n\nMohon ananda dijemput dan diantar kembali tepat waktu.\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
   '{nama_wali,nama_santri,kelas,periode_libur,status_libur,waktu_pulang,batas_kembali,keterangan,pengirim}', 'Libur Santri: kabari wali tentang keputusan libur ananda.')
on conflict (kode) do nothing;

-- ---------------------------------------------------------------------
-- 8. HAK EKSEKUSI
-- ---------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array['syarat_libur_bawaan()','boleh_kelola_libur()','boleh_sahkan_libur()','boleh_lihat_libur()','hak_libur()','simpan_syarat_libur(jsonb)',
    'simpan_periode_libur(jsonb)','nilai_libur(uuid)','ringkasan_periode_libur(uuid)','ubah_keputusan_libur(uuid,text,text)','sahkan_libur(uuid)',
    'batalkan_libur(uuid,text)','daftar_periode_libur()','detail_libur(uuid)','daftar_izin(text,date,date,uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['_syarat_libur_bersih(jsonb)','_kehadiran_pokok(date,date)','_selaraskan_izin_libur(uuid)','_periode_libur_json(uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN (hasil yang benar: semua baris "Sesuai")
-- ---------------------------------------------------------------------
select '1. Tabel periode dan hasil libur' as pemeriksaan,
       case when to_regclass('public.holiday_periods') is not null and to_regclass('public.holiday_eligibility') is not null then 'Sesuai' else 'Periksa' end as hasil
union all select '2. Izin jenis libur', case when exists (select 1 from pg_constraint where conname = 'student_permits_jenis_check' and pg_get_constraintdef(oid) like '%libur%') then 'Sesuai' else 'Periksa' end
union all select '3. Fungsi nilai, ubah, sahkan, batalkan', case when (select count(*) from pg_proc where proname in ('nilai_libur','ubah_keputusan_libur','sahkan_libur','batalkan_libur')) = 4 then 'Sesuai' else 'Periksa' end
union all select '4. Syarat bawaan libur', case when public.syarat_libur_bawaan() ? 'kelas_min' then 'Sesuai' else 'Periksa' end
union all select '5. Template WA libur_santri', case when exists (select 1 from wa_templates where kode = 'libur_santri') then 'Sesuai' else 'Periksa' end
union all select '6. Izin admin kelola_libur', case when exists (select 1 from admin_capabilities where kode = 'kelola_libur') then 'Sesuai' else 'Periksa' end;
