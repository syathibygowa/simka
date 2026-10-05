-- SIMKA PRO | supabase/migrations/20261006004800_izin_santri.sql | v1.0 | Fase 6 – Tahap 2 Status otomatis dan perizinan santri | 06/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 6 · Migrasi 48: Perizinan santri berjenjang (Blueprint Bagian 22, DIMAJUKAN dari Fase 7)
--                                   + status otomatis di absensi + rujukan klinik dari absensi (Bagian 17, 21)
--   * student_permits / student_permit_approvals: izin keluar/pulang santri.
--       Pengusul (musyrif → Kesantrian, muhaffizh → Tahfizh, wali kelas → Wustha/SMA sesuai jenjang santri,
--       petugas klinik/admin → Kesantrian). Izin s.d. batas hari (bawaan 2) cukup disetujui kepala bidang/unit;
--       lebih dari itu naik ke Direktur/Wadir. Plt menggantikan. Superadmin dapat memutus di semua tingkat.
--       Pencatatan keluar/kembali sementara oleh pengasuh/admin (Fase 7: oleh Security di gerbang).
--   * Klinik "Dipulangkan" otomatis menjadi usulan izin (sumber klinik) ke Kepala Bidang Kesantrian.
--   * status_otomatis_sesi(): santri yang sedang sakit (Klinik: istirahat/rawat/rujuk/dipulangkan) otomatis S,
--     santri yang sedang izin (disetujui/keluar, belum kembali) otomatis I pada setiap sesi absensi.
--   * simpan_absensi_santri() diperbarui: status otomatis menimpa isian; santri yang ditandai Sakit tanpa kasus
--     klinik terbuka WAJIB diberi keluhan singkat dan otomatis dirujuk ke klinik (sumber absensi).
--   * clinic_cases.sakit_sejak: waktu pasti mulai sakit (dasar status S otomatis).
--   * Izin admin baru: kelola_izin_santri. Template WA baru: izin_santri.
-- Jalankan SETELAH migrasi 4700. Aman dijalankan ulang.
-- =====================================================================

insert into public.admin_capabilities (kode, nama, urutan) values
  ('kelola_izin_santri', 'Mengelola perizinan santri: lihat semua, catat keluar/kembali, ketentuan (Fase 6)', 31)
on conflict (kode) do nothing;

insert into public.institution_settings (kunci, nilai) values ('perizinan', '{"batas_hari_bidang": 2, "lama_bawaan_hari": 2}')
on conflict (kunci) do nothing;

-- ---------------------------------------------------------------------
-- 1. KLINIK: waktu mulai sakit
-- ---------------------------------------------------------------------
alter table public.clinic_cases add column if not exists sakit_sejak timestamptz;
update public.clinic_cases c set sakit_sejak = (select min(v.waktu) from clinic_visits v where v.case_id = c.id and v.tindak_lanjut <> 'kembali')
 where c.sakit_sejak is null and exists (select 1 from clinic_visits v where v.case_id = c.id and v.tindak_lanjut <> 'kembali');

create or replace function public.tg_klinik_sakit()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'ditangani' and new.tindak_lanjut in ('istirahat','rawat','rujuk','pulang') and new.sakit_sejak is null then
    new.sakit_sejak := now();
  end if;
  return new;
end $$;
drop trigger if exists ab_sakit on public.clinic_cases;
create trigger ab_sakit before insert or update on public.clinic_cases for each row execute function public.tg_klinik_sakit();

-- ---------------------------------------------------------------------
-- 2. TABEL PERIZINAN
-- ---------------------------------------------------------------------
create table if not exists public.student_permits (
  id              uuid primary key default gen_random_uuid(),
  student_id      uuid not null references public.students(id) on delete cascade,
  jenis           text not null default 'pulang' check (jenis in ('pulang','keluar')),   -- pulang (menginap) / keluar (beberapa jam)
  alasan          text not null,
  penjemput       text,
  hubungan_penjemput text,
  hp_penjemput    text,
  keluar_pada     timestamptz not null,
  kembali_batas   timestamptz not null,
  lama_hari       int not null default 1,
  sumber          text not null default 'pengasuh' check (sumber in ('pengasuh','klinik','admin')),
  case_id         uuid references public.clinic_cases(id) on delete set null,
  pengusul_id     uuid references public.employees(id) on delete set null,
  peran_pengusul  text not null check (peran_pengusul in ('musyrif','wali_kelas','muhaffizh','petugas_klinik','admin')),
  unit_kode       text not null check (unit_kode in ('KESANTRIAN','TAHFIZH','WUSTHA','SMA')),
  perlu_pimpinan  boolean not null default false,
  status          text not null default 'diajukan'
                  check (status in ('diajukan','disetujui_bidang','disetujui','ditolak','dibatalkan','keluar','kembali')),
  keluar_aktual   timestamptz,
  kembali_pada    timestamptz,
  dicatat_keluar_oleh uuid references public.employees(id) on delete set null,
  dicatat_kembali_oleh uuid references public.employees(id) on delete set null,
  catatan         text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint student_permits_waktu check (kembali_batas > keluar_pada)
);
create index if not exists sp_santri_idx on public.student_permits (student_id, keluar_pada desc);
create index if not exists sp_status_idx on public.student_permits (status, unit_kode);

create table if not exists public.student_permit_approvals (
  id         uuid primary key default gen_random_uuid(),
  permit_id  uuid not null references public.student_permits(id) on delete cascade,
  tingkat    smallint not null check (tingkat in (1, 2)),
  keputusan  text not null check (keputusan in ('setuju','tolak')),
  oleh       uuid references public.employees(id) on delete set null,
  sebagai    text,
  catatan    text,
  pada       timestamptz not null default now()
);
create index if not exists spa_permit_idx on public.student_permit_approvals (permit_id, pada);

drop trigger if exists aa_updated on public.student_permits;
create trigger aa_updated before update on public.student_permits for each row execute function public.tg_updated_at();
drop trigger if exists zz_audit on public.student_permits;
create trigger zz_audit after insert or update or delete on public.student_permits for each row execute function public.tg_audit();

-- ---------------------------------------------------------------------
-- 3. PEJABAT DAN HAK
-- ---------------------------------------------------------------------
/** Pegawai berakun aktif yang memegang jabatan struktural (tingkat ≤ p_maks) pada unit berkode p_kode, termasuk Plt. */
create or replace function public._pejabat_unit(p_kode text, p_maks int default 40)
returns setof uuid language sql stable security definer set search_path = public as $$
  select distinct e.id from employees e
    join employee_structurals es on es.employee_id = e.id
    join structural_positions sp on sp.id = es.structural_position_id and sp.tingkat <= p_maks
    join org_units o on o.id = es.org_unit_id and o.kode = p_kode
   where e.status_akun = 'aktif' and e.status_keaktifan = 'aktif'
  union
  select distinct a.employee_id from acting_assignments a
    join structural_positions sp on sp.id = a.structural_position_id and sp.tingkat <= p_maks
    join org_units o on o.id = a.org_unit_id and o.kode = p_kode
    join employees e on e.id = a.employee_id and e.status_akun = 'aktif'
   where public.hari_ini() between a.mulai and a.sampai
$$;

/** Direktur, Wakil Direktur (dan Plt-nya). */
create or replace function public._pimpinan_puncak()
returns setof uuid language sql stable security definer set search_path = public as $$
  select distinct e.id from employees e
    join employee_structurals es on es.employee_id = e.id
    join structural_positions sp on sp.id = es.structural_position_id and sp.kode in ('DIREKTUR','WAKIL_DIREKTUR')
   where e.status_akun = 'aktif' and e.status_keaktifan = 'aktif'
  union
  select distinct a.employee_id from acting_assignments a
    join structural_positions sp on sp.id = a.structural_position_id and sp.kode in ('DIREKTUR','WAKIL_DIREKTUR')
   where public.hari_ini() between a.mulai and a.sampai
$$;

create or replace function public.boleh_kelola_izin()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_superadmin() or public.admin_boleh('kelola_izin_santri') or public.tingkat_fitur('perizinan_santri') >= 3
$$;

/** Boleh memutus izin pada tingkat tertentu. Tingkat 1: kepala bidang/unit (tingkat ≤ 30) unit tujuan atau pimpinan puncak;
    tingkat 2: pimpinan puncak. Superadmin keduanya. */
create or replace function public.boleh_putus_izin(p_unit text, p_tingkat int)
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_superadmin()
      or public.saya() in (select public._pimpinan_puncak())
      or (p_tingkat = 1 and public.saya() in (select public._pejabat_unit(p_unit, 30)))
$$;

/** Boleh melihat izin seorang santri / unit. */
create or replace function public.boleh_lihat_izin(p_student uuid, p_unit text)
returns boolean language sql stable security definer set search_path = public as $$
  select public.boleh_kelola_izin() or public.is_admin() or public.boleh_putus_izin(p_unit, 1)
      or public.pimpinan_kesantrian() or p_student in (select public.santri_terlihat())
$$;

alter table public.student_permits enable row level security;
alter table public.student_permit_approvals enable row level security;
drop policy if exists baca on public.student_permits;
create policy baca on public.student_permits for select to authenticated using (public.boleh_lihat_izin(student_id, unit_kode));
drop policy if exists baca on public.student_permit_approvals;
create policy baca on public.student_permit_approvals for select to authenticated
  using (exists (select 1 from student_permits p where p.id = permit_id and public.boleh_lihat_izin(p.student_id, p.unit_kode)));

create or replace function public.pengaturan_izin()
returns jsonb language sql stable security definer set search_path = public as $$
  select '{"batas_hari_bidang": 2, "lama_bawaan_hari": 2}'::jsonb || coalesce((select nilai from institution_settings where kunci = 'perizinan'), '{}'::jsonb)
$$;

create or replace function public.simpan_pengaturan_izin(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare b int := (p->>'batas_hari_bidang')::int; l int := (p->>'lama_bawaan_hari')::int;
begin
  if not public.boleh_kelola_izin() then raise exception 'Anda tidak berwenang mengubah ketentuan perizinan.' using errcode = '42501'; end if;
  if b is null or b < 1 or b > 30 then raise exception 'Batas hari persetujuan kepala bidang harus 1–30.'; end if;
  if l is null or l < 1 or l > 30 then raise exception 'Lama izin bawaan harus 1–30 hari.'; end if;
  insert into institution_settings (kunci, nilai, updated_by) values ('perizinan', jsonb_build_object('batas_hari_bidang', b, 'lama_bawaan_hari', l), public.saya())
  on conflict (kunci) do update set nilai = excluded.nilai, updated_at = now(), updated_by = excluded.updated_by;
  return public.pengaturan_izin();
end $$;

/** Peran pengusul yang tersedia bagi pengguna untuk seorang santri: kelompok asuhan yang memuat santri itu. */
create or replace function public.peran_pengusul_izin(p_santri uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(distinct jsonb_build_object('peran', x.peran, 'unit', x.unit, 'kelompok', x.kelompok)), '[]'::jsonb) from (
    select case g.jenis when 'kamar' then 'musyrif' when 'halaqah' then 'muhaffizh' else 'wali_kelas' end as peran,
           case g.jenis when 'kamar' then 'KESANTRIAN' when 'halaqah' then 'TAHFIZH'
                else case when s.jenjang = 'sma' then 'SMA' else 'WUSTHA' end end as unit, g.nama as kelompok
      from group_members m join student_groups g on g.id = m.group_id and g.jenis in ('kamar','halaqah','kelas') and g.aktif
      join academic_years a on a.id = g.academic_year_id and a.aktif
      join students s on s.id = m.student_id
     where m.student_id = p_santri and m.selesai is null
       and public.saya() in (select public._pengasuh_berlaku(g.id, public.hari_ini()))
    union all
    select 'admin', 'KESANTRIAN', null where public.boleh_kelola_izin()
  ) x
$$;

create or replace function public.hak_izin()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'kelola', public.boleh_kelola_izin(),
    'puncak', public.is_superadmin() or public.saya() in (select public._pimpinan_puncak()),
    'unit_putus', coalesce((select jsonb_agg(k) from unnest(array['KESANTRIAN','TAHFIZH','WUSTHA','SMA']) k where public.boleh_putus_izin(k, 1)), '[]'::jsonb),
    'ajukan', public.boleh_kelola_izin() or exists (select 1 from public.kelompok_saya() g join student_groups sg on sg.id = g
                                                     where sg.jenis in ('kamar','halaqah','kelas')),
    'lihat', public.is_admin() or public.pimpinan_kesantrian() or exists (select 1 from public.santri_terlihat() limit 1)
             or exists (select 1 from unnest(array['KESANTRIAN','TAHFIZH','WUSTHA','SMA']) k where public.boleh_putus_izin(k, 1)))
$$;

-- ---------------------------------------------------------------------
-- 4. AJUKAN, PUTUSKAN, CATAT
-- ---------------------------------------------------------------------
create or replace function public._label_unit_izin(p_unit text)
returns text language sql immutable as $$
  select case p_unit when 'KESANTRIAN' then 'Kepala Bidang Kesantrian' when 'TAHFIZH' then 'Kepala Bidang Tahfizh'
                     when 'WUSTHA' then 'Kepala Kesetaraan Wustha' else 'Kepala SMA' end
$$;

/** Pemberitahuan ke pemutus tingkat berikutnya. Tingkat 1 tanpa pejabat → pimpinan puncak. */
create or replace function public._kabari_pemutus_izin(p_id uuid, p_tingkat int)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v record; n int;
begin
  select p.*, s.nama_lengkap into v from student_permits p join students s on s.id = p.student_id where p.id = p_id;
  insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
  select x, 'Izin santri menunggu persetujuan', v.nama_lengkap || ' · ' || v.lama_hari || ' hari · ' || v.alasan, '/izin-santri/persetujuan', 'SignOut', 'jingga'
    from (select public._pejabat_unit(v.unit_kode, 30) x where p_tingkat = 1
          union select public._pimpinan_puncak() where p_tingkat = 2) q
   where x is distinct from v.pengusul_id;
  get diagnostics n = row_count;
  if n = 0 and p_tingkat = 1 then
    insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
    select x, 'Izin santri menunggu persetujuan', v.nama_lengkap || ' · ' || v.lama_hari || ' hari · ' || v.alasan, '/izin-santri/persetujuan', 'SignOut', 'jingga'
      from public._pimpinan_puncak() x where x is distinct from v.pengusul_id;
  end if;
end $$;

/** Kabari pihak terkait setelah izin disetujui/ditolak: pengusul, pengasuh santri, Kepala Bidang Kesantrian. */
create or replace function public._kabari_hasil_izin(p_id uuid, p_judul text, p_isi text, p_warna text)
returns void language sql volatile security definer set search_path = public as $$
  insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
  select distinct x, p_judul, p_isi, '/izin-santri/aktif', 'SignOut', p_warna from (
    select p.pengusul_id x from student_permits p where p.id = p_id
    union select k.employee_id from student_permits p join group_members m on m.student_id = p.student_id and m.selesai is null
           join student_groups g on g.id = m.group_id and g.aktif and g.jenis in ('kamar','kelas','halaqah')
           join group_keepers k on k.group_id = g.id and (k.sampai is null or k.sampai >= public.hari_ini())
          where p.id = p_id
    union select public._pejabat_unit('KESANTRIAN', 30)) q
  where x is not null and x is distinct from public.saya()
$$;

create or replace function public.ajukan_izin(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_s record; v_peran text := coalesce(p->>'peran', ''); v_unit text; v_keluar timestamptz; v_kembali timestamptz;
        v_lama int; v_batas int := (public.pengaturan_izin()->>'batas_hari_bidang')::int; v_id uuid; v_opsi jsonb;
begin
  if public.saya() is null then raise exception 'Sesi tidak ditemukan. Silakan masuk kembali.' using errcode = '42501'; end if;
  select id, nama_lengkap, status, jenjang into v_s from students where id = nullif(p->>'student_id', '')::uuid;
  if v_s.id is null then raise exception 'Pilih santri.'; end if;
  if v_s.status <> 'aktif' then raise exception '% tidak berstatus aktif.', v_s.nama_lengkap; end if;
  v_opsi := public.peran_pengusul_izin(v_s.id);
  select o->>'unit' into v_unit from jsonb_array_elements(v_opsi) o where o->>'peran' = v_peran limit 1;
  if v_unit is null then raise exception 'Anda bukan pengasuh (musyrif, wali kelas, atau muhaffizh) santri ini.' using errcode = '42501'; end if;
  if length(trim(coalesce(p->>'alasan', ''))) < 5 then raise exception 'Tuliskan alasan izin (minimal 5 huruf).'; end if;
  v_keluar := (p->>'keluar_pada')::timestamptz; v_kembali := (p->>'kembali_batas')::timestamptz;
  if v_keluar is null or v_kembali is null then raise exception 'Isi waktu keluar dan batas kembali.'; end if;
  if v_kembali <= v_keluar then raise exception 'Batas kembali harus setelah waktu keluar.'; end if;
  if v_keluar < now() - interval '1 day' then raise exception 'Waktu keluar paling lambat kemarin.'; end if;
  if exists (select 1 from student_permits where student_id = v_s.id and status in ('diajukan','disetujui_bidang','disetujui','keluar')
              and keluar_pada < v_kembali and kembali_batas > v_keluar) then
    raise exception '% sudah memiliki izin pada rentang waktu tersebut.', v_s.nama_lengkap;
  end if;
  v_lama := greatest(1, ceil(extract(epoch from (v_kembali - v_keluar)) / 86400.0)::int);
  insert into student_permits (student_id, jenis, alasan, penjemput, hubungan_penjemput, hp_penjemput, keluar_pada, kembali_batas,
                               lama_hari, sumber, pengusul_id, peran_pengusul, unit_kode, perlu_pimpinan, catatan)
  values (v_s.id, case when p->>'jenis' = 'keluar' then 'keluar' else 'pulang' end, trim(p->>'alasan'),
          nullif(trim(p->>'penjemput'), ''), nullif(trim(p->>'hubungan_penjemput'), ''), nullif(trim(p->>'hp_penjemput'), ''),
          v_keluar, v_kembali, v_lama, case when v_peran = 'admin' then 'admin' else 'pengasuh' end, public.saya(), v_peran, v_unit,
          v_lama > v_batas, nullif(trim(p->>'catatan'), ''))
  returning id into v_id;
  perform public._kabari_pemutus_izin(v_id, 1);
  return v_id;
end $$;

/** Ubah/lengkapi izin yang belum diputus (pengusul, pemutus tingkat 1, atau pengelola). */
create or replace function public.lengkapi_izin(p_id uuid, p jsonb)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v student_permits%rowtype; v_keluar timestamptz; v_kembali timestamptz; v_lama int;
begin
  select * into v from student_permits where id = p_id for update;
  if v.id is null then raise exception 'Izin tidak ditemukan.'; end if;
  if v.status <> 'diajukan' then raise exception 'Izin yang sudah diputus tidak dapat diubah.'; end if;
  if not (v.pengusul_id = public.saya() or public.boleh_putus_izin(v.unit_kode, 1) or public.boleh_kelola_izin()) then
    raise exception 'Anda tidak berwenang mengubah izin ini.' using errcode = '42501';
  end if;
  v_keluar := coalesce((p->>'keluar_pada')::timestamptz, v.keluar_pada); v_kembali := coalesce((p->>'kembali_batas')::timestamptz, v.kembali_batas);
  if v_kembali <= v_keluar then raise exception 'Batas kembali harus setelah waktu keluar.'; end if;
  v_lama := greatest(1, ceil(extract(epoch from (v_kembali - v_keluar)) / 86400.0)::int);
  update student_permits set alasan = coalesce(nullif(trim(p->>'alasan'), ''), alasan),
         jenis = case when p ? 'jenis' then case when p->>'jenis' = 'keluar' then 'keluar' else 'pulang' end else jenis end,
         penjemput = case when p ? 'penjemput' then nullif(trim(p->>'penjemput'), '') else penjemput end,
         hubungan_penjemput = case when p ? 'hubungan_penjemput' then nullif(trim(p->>'hubungan_penjemput'), '') else hubungan_penjemput end,
         hp_penjemput = case when p ? 'hp_penjemput' then nullif(trim(p->>'hp_penjemput'), '') else hp_penjemput end,
         catatan = case when p ? 'catatan' then nullif(trim(p->>'catatan'), '') else catatan end,
         keluar_pada = v_keluar, kembali_batas = v_kembali, lama_hari = v_lama,
         perlu_pimpinan = v_lama > (public.pengaturan_izin()->>'batas_hari_bidang')::int
   where id = p_id;
end $$;

create or replace function public.putuskan_izin(p_id uuid, p_keputusan text, p_catatan text default null)
returns text language plpgsql volatile security definer set search_path = public as $$
declare v student_permits%rowtype; v_tingkat int; v_sebagai text; v_nama text; v_puncak boolean;
begin
  select * into v from student_permits where id = p_id for update;
  if v.id is null then raise exception 'Izin tidak ditemukan.'; end if;
  if p_keputusan not in ('setuju','tolak') then raise exception 'Keputusan harus setuju atau tolak.'; end if;
  if v.status = 'diajukan' then v_tingkat := 1; elsif v.status = 'disetujui_bidang' then v_tingkat := 2;
  else raise exception 'Izin ini sudah diputus.'; end if;
  if not public.boleh_putus_izin(v.unit_kode, v_tingkat) then
    raise exception 'Izin ini menunggu keputusan %.', case when v_tingkat = 1 then public._label_unit_izin(v.unit_kode) else 'Direktur/Wakil Direktur' end
      using errcode = '42501';
  end if;
  if p_keputusan = 'tolak' and length(trim(coalesce(p_catatan, ''))) < 5 then raise exception 'Tuliskan alasan penolakan (minimal 5 huruf).'; end if;
  if v.penjemput is null and v.jenis = 'pulang' and p_keputusan = 'setuju' then raise exception 'Lengkapi nama penjemput sebelum menyetujui izin pulang.'; end if;
  v_puncak := public.saya() in (select public._pimpinan_puncak()) or public.is_superadmin();
  v_sebagai := case when public.saya() in (select public._pimpinan_puncak()) then 'Direktur/Wakil Direktur'
                    when v_tingkat = 1 and public.saya() in (select public._pejabat_unit(v.unit_kode, 30)) then public._label_unit_izin(v.unit_kode)
                    else 'Superadmin' end;
  insert into student_permit_approvals (permit_id, tingkat, keputusan, oleh, sebagai, catatan)
  values (p_id, v_tingkat, p_keputusan, public.saya(), v_sebagai, nullif(trim(p_catatan), ''));
  select nama_lengkap into v_nama from students where id = v.student_id;
  if p_keputusan = 'tolak' then
    update student_permits set status = 'ditolak' where id = p_id;
    perform public._kabari_hasil_izin(p_id, 'Izin santri ditolak: ' || v_nama, trim(p_catatan), 'merah');
    return 'ditolak';
  end if;
  if v_tingkat = 1 and v.perlu_pimpinan and not v_puncak then
    update student_permits set status = 'disetujui_bidang' where id = p_id;
    perform public._kabari_pemutus_izin(p_id, 2);
    return 'disetujui_bidang';
  end if;
  update student_permits set status = 'disetujui' where id = p_id;
  perform public._kabari_hasil_izin(p_id, 'Izin santri disetujui: ' || v_nama,
    to_char(v.keluar_pada at time zone 'Asia/Makassar', 'DD/MM HH24.MI') || ' s.d. ' || to_char(v.kembali_batas at time zone 'Asia/Makassar', 'DD/MM HH24.MI')
    || ' · ' || v.alasan, 'hijau');
  return 'disetujui';
end $$;

create or replace function public.batalkan_izin(p_id uuid, p_alasan text)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v student_permits%rowtype;
begin
  select * into v from student_permits where id = p_id for update;
  if v.id is null then raise exception 'Izin tidak ditemukan.'; end if;
  if v.status not in ('diajukan','disetujui_bidang','disetujui') then raise exception 'Izin ini tidak dapat dibatalkan (sudah keluar, kembali, atau diputus).'; end if;
  if not (v.pengusul_id = public.saya() or public.boleh_kelola_izin() or public.boleh_putus_izin(v.unit_kode, 1)) then
    raise exception 'Anda tidak berwenang membatalkan izin ini.' using errcode = '42501';
  end if;
  if length(trim(coalesce(p_alasan, ''))) < 5 then raise exception 'Tuliskan alasan pembatalan (minimal 5 huruf).'; end if;
  update student_permits set status = 'dibatalkan', catatan = trim(coalesce(catatan || E'\n', '') || 'Dibatalkan: ' || trim(p_alasan)) where id = p_id;
end $$;

/** Catat santri keluar / kembali. Sementara oleh pengasuh santri dan pengelola izin; Fase 7 oleh Security di gerbang. */
create or replace function public.catat_gerbang_izin(p_id uuid, p_aksi text, p_waktu timestamptz default null)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v student_permits%rowtype; t timestamptz := coalesce(p_waktu, now());
begin
  select * into v from student_permits where id = p_id for update;
  if v.id is null then raise exception 'Izin tidak ditemukan.'; end if;
  if not (public.boleh_kelola_izin() or v.student_id in (select public.santri_terlihat()) and exists (
            select 1 from jsonb_array_elements(public.peran_pengusul_izin(v.student_id)))) then
    raise exception 'Hanya pengasuh santri atau pengelola izin yang dapat mencatat.' using errcode = '42501';
  end if;
  if t > now() + interval '5 minutes' then raise exception 'Waktu tidak boleh di masa depan.'; end if;
  if p_aksi = 'keluar' then
    if v.status <> 'disetujui' then raise exception 'Santri hanya dapat keluar dengan izin yang sudah disetujui.'; end if;
    update student_permits set status = 'keluar', keluar_aktual = t, dicatat_keluar_oleh = public.saya() where id = p_id;
  elsif p_aksi = 'kembali' then
    if v.status not in ('keluar','disetujui') then raise exception 'Izin ini belum berstatus keluar.'; end if;
    update student_permits set status = 'kembali', keluar_aktual = coalesce(keluar_aktual, keluar_pada), kembali_pada = t,
           dicatat_kembali_oleh = public.saya() where id = p_id;
  else raise exception 'Aksi harus keluar atau kembali.'; end if;
end $$;

-- ---------------------------------------------------------------------
-- 5. BACA
-- ---------------------------------------------------------------------
/** cakupan: persetujuan (menunggu keputusan saya) | aktif (disetujui/keluar, belum kembali) | menunggu | semua (rentang tanggal keluar).
    p_group: saring satu kelompok (mis. kamar di menu Musyrif). */
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
      'boleh_catat', p.status in ('disetujui','keluar') and (public.boleh_kelola_izin() or jsonb_array_length(public.peran_pengusul_izin(p.student_id)) > 0),
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
             when 'aktif' then p.status in ('disetujui','keluar')
             when 'semua' then (p.keluar_pada at time zone 'Asia/Makassar')::date between v_mulai and v_selesai
                               or p.status in ('diajukan','disetujui_bidang','disetujui','keluar')
             else false end) q), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- 6. KLINIK "DIPULANGKAN" → USULAN IZIN
-- ---------------------------------------------------------------------
create or replace function public.tg_klinik_usulan_izin()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_lama int := (public.pengaturan_izin()->>'lama_bawaan_hari')::int; v_nama text;
begin
  if new.tindak_lanjut = 'pulang' and new.status = 'ditangani' and coalesce(old.tindak_lanjut, '') <> 'pulang'
     and not exists (select 1 from student_permits where case_id = new.id and status not in ('ditolak','dibatalkan')) then
    insert into student_permits (student_id, jenis, alasan, keluar_pada, kembali_batas, lama_hari, sumber, case_id, pengusul_id,
                                 peran_pengusul, unit_kode, perlu_pimpinan, catatan)
    values (new.student_id, 'pulang', 'Dipulangkan klinik untuk pemulihan: ' || new.keluhan, now(), now() + make_interval(days => v_lama),
            v_lama, 'klinik', new.id, public.saya(), 'petugas_klinik', 'KESANTRIAN',
            v_lama > (public.pengaturan_izin()->>'batas_hari_bidang')::int, 'Usulan otomatis dari Klinik. Lengkapi penjemput dan batas kembali.')
    returning id into v_id;
    perform public._kabari_pemutus_izin(v_id, 1);
  end if;
  return new;
end $$;
drop trigger if exists zz_usulan_izin on public.clinic_cases;
create trigger zz_usulan_izin after update on public.clinic_cases for each row execute function public.tg_klinik_usulan_izin();

-- ---------------------------------------------------------------------
-- 7. STATUS OTOMATIS PADA SESI ABSENSI
-- ---------------------------------------------------------------------
/** [{ student_id, kode (S|I), sumber (klinik|izin), keterangan, ref_id }] untuk anggota kelompok pada satu sesi.
    Sakit (Klinik) didahulukan atas Izin. */
create or replace function public.status_otomatis_sesi(p_group uuid, p_tanggal date, p_sesi text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare ss record;
begin
  select * into ss from public.sesi_kelompok(p_group, p_tanggal) x where x.kode = p_sesi;
  if not found then return '[]'::jsonb; end if;
  return coalesce((select jsonb_agg(z) from (
    select distinct on (sid) jsonb_build_object('student_id', sid, 'kode', kode, 'sumber', sumber, 'keterangan', ket, 'ref_id', ref) z
      from (
        select c.student_id sid, 'S' kode, 'klinik' sumber, 1 urut, c.id ref,
               'Klinik: ' || case c.tindak_lanjut when 'istirahat' then 'istirahat di kamar' when 'rawat' then 'dirawat di klinik'
                                  when 'rujuk' then 'dirujuk ke RS/puskesmas' when 'pulang' then 'dipulangkan' else 'sakit' end ket
          from clinic_cases c
         where c.student_id in (select public._anggota_pada(p_group, p_tanggal))
           and c.sakit_sejak is not null and c.sakit_sejak <= ss.selesai and c.status in ('ditangani','selesai')
           and (c.selesai_pada is null or c.selesai_pada > ss.mulai)
        union all
        select p.student_id, 'I', 'izin', 2, p.id,
               'Izin ' || case p.jenis when 'keluar' then 'keluar' else 'pulang' end || ' s.d. '
                 || to_char(p.kembali_batas at time zone 'Asia/Makassar', 'DD/MM HH24.MI') || ': ' || p.alasan
          from student_permits p
         where p.student_id in (select public._anggota_pada(p_group, p_tanggal))
           and p.status in ('disetujui','keluar','kembali')
           and coalesce(p.keluar_aktual, p.keluar_pada) <= ss.selesai
           and coalesce(p.kembali_pada, case when p.status = 'keluar' then 'infinity'::timestamptz else p.kembali_batas end) > ss.mulai
      ) a order by sid, urut) q), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- 8. SIMPAN ABSENSI: status otomatis + rujukan klinik dari Sakit
-- ---------------------------------------------------------------------
create or replace function public.simpan_absensi_santri(p jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $$
declare v_group uuid := (p->>'group_id')::uuid; v_tgl date := (p->>'tanggal')::date; v_sesi text := p->>'sesi';
  g student_groups; v_jenis text; ss record; v_saya uuid := public.saya(); v_pengasuh boolean; v_atas boolean := false;
  v_pengampu uuid; v_id uuid; v_lama jsonb; v_baru jsonb; v_ubah jsonb; v_batas_hari int; v_kini timestamptz := now();
  r jsonb; st jsonb := coalesce((select nilai from institution_settings where kunci = 'absensi_santri'), '{}'::jsonb);
  v_oto jsonb; v_rujuk jsonb := '[]'::jsonb; v_nama text;
begin
  if v_saya is null then raise exception 'Sesi masuk tidak berlaku. Silakan masuk ulang.' using errcode = '42501'; end if;
  select * into g from student_groups where id = v_group;
  if not found or not g.aktif then raise exception 'Kelompok tidak ditemukan atau nonaktif.'; end if;
  if g.jenis not in ('kelas','halaqah','kamar','ekskul') then raise exception 'Kelompok lainnya tidak memiliki absensi.'; end if;
  if not exists (select 1 from academic_years where id = g.academic_year_id and aktif and not terkunci) then
    raise exception 'Kelompok ini bukan milik tahun ajaran aktif.';
  end if;
  v_jenis := case g.jenis when 'kamar' then 'asrama' else g.jenis end;
  select * into ss from public.sesi_kelompok(v_group, v_tgl) x where x.kode = v_sesi;
  if not found then raise exception 'Tidak ada sesi % pada tanggal ini (hari libur atau sesi tidak berlaku).', v_sesi; end if;
  v_pengasuh := v_saya in (select public._pengasuh_berlaku(v_group, v_tgl));

  if v_pengasuh and not (nullif(p->>'atas_nama_id', '') is not null and public.admin_boleh('absensi_atas_nama')) then
    if v_kini < ss.buka then raise exception 'Absensi % belum dibuka. Dibuka pukul %.', ss.nama, to_char(ss.buka at time zone 'Asia/Makassar', 'HH24.MI'); end if;
    if v_kini > ss.batas then raise exception 'Batas pengisian dan koreksi absensi ini sudah lewat. Hubungi admin untuk input atas nama.'; end if;
    v_pengampu := v_saya;
  elsif public.admin_boleh('absensi_atas_nama') then
    v_batas_hari := coalesce((st->>'batas_atas_nama_hari')::int, 7);
    if v_kini < ss.buka then raise exception 'Sesi ini belum dibuka.'; end if;
    if not public.is_superadmin() and v_tgl < public.hari_ini() - v_batas_hari then
      raise exception 'Input atas nama paling lama % hari ke belakang. Hubungi superadmin.', v_batas_hari;
    end if;
    v_atas := true;
    v_pengampu := coalesce(nullif(p->>'atas_nama_id', '')::uuid,
      (select k.employee_id from group_keepers k where k.group_id = v_group and k.employee_id in (select public._pengasuh_berlaku(v_group, v_tgl))
        order by array_position(array['utama','pendamping','pengganti'], k.peran) limit 1));
    if v_pengampu is not null and v_pengampu not in (select public._pengasuh_berlaku(v_group, v_tgl)) then
      raise exception 'Pegawai yang dipilih bukan pengasuh kelompok ini pada tanggal tersebut.';
    end if;
  else
    raise exception 'Anda bukan pengasuh kelompok ini.' using errcode = '42501';
  end if;

  -- Ekskul: jurnal materi wajib (topik)
  if v_jenis = 'ekskul' and length(trim(coalesce(p->'jurnal'->>'topik', ''))) < 3 then
    raise exception 'Isi topik/materi pertemuan ekskul (minimal 3 huruf).';
  end if;

  -- Validasi pengecualian
  for r in select * from jsonb_array_elements(coalesce(p->'pengecualian', '[]')) loop
    if r->>'kode' not in ('I','S','B','A','T') then raise exception 'Kode absensi harus H, I, S, B, A, atau T.'; end if;
    if r->>'student_id' is null or (r->>'student_id')::uuid not in (select public._anggota_pada(v_group, v_tgl)) then
      raise exception 'Ada santri yang bukan anggota % pada tanggal ini.', g.nama;
    end if;
  end loop;

  -- v6.2: status otomatis (Sakit dari Klinik, Izin dari perizinan santri) menimpa isian pengasuh
  v_oto := public.status_otomatis_sesi(v_group, v_tgl, v_sesi);
  p := jsonb_set(p, '{pengecualian}', coalesce((
      select jsonb_agg(x) from jsonb_array_elements(coalesce(p->'pengecualian', '[]')) x
       where not exists (select 1 from jsonb_array_elements(v_oto) o where o->>'student_id' = x->>'student_id')), '[]'::jsonb)
    || coalesce((select jsonb_agg(jsonb_build_object('student_id', o->>'student_id', 'kode', o->>'kode', 'keterangan', o->>'keterangan'))
                  from jsonb_array_elements(v_oto) o), '[]'::jsonb));
  -- v6.2: Sakit yang diisi pengasuh untuk santri tanpa kasus klinik terbuka → wajib keluhan, lalu dirujuk otomatis
  for r in select * from jsonb_array_elements(coalesce(p->'pengecualian', '[]')) loop
    if r->>'kode' = 'S'
       and not exists (select 1 from jsonb_array_elements(v_oto) o where o->>'student_id' = r->>'student_id')
       and not exists (select 1 from clinic_cases c where c.student_id = (r->>'student_id')::uuid and c.status in ('menunggu','ditangani')) then
      if length(trim(coalesce(r->>'keterangan', ''))) < 3 then
        select nama_lengkap into v_nama from students where id = (r->>'student_id')::uuid;
        raise exception 'Tuliskan keluhan singkat untuk % yang ditandai Sakit (untuk rujukan klinik).', v_nama;
      end if;
      v_rujuk := v_rujuk || jsonb_build_array(r);
    end if;
  end loop;

  select id into v_id from student_attendance_sessions where group_id = v_group and tanggal = v_tgl and sesi = v_sesi for update;
  select coalesce(jsonb_object_agg(student_id::text, jsonb_build_object('kode', kode, 'keterangan', keterangan)), '{}') into v_lama
  from student_attendance_exceptions where session_id = v_id;
  select coalesce(jsonb_object_agg(x->>'student_id', jsonb_build_object('kode', x->>'kode', 'keterangan', nullif(trim(coalesce(x->>'keterangan', '')), ''))), '{}') into v_baru
  from jsonb_array_elements(coalesce(p->'pengecualian', '[]')) x;

  if v_id is null then
    insert into student_attendance_sessions (group_id, jenis, tanggal, sesi, nama_sesi, jam_mulai, jam_selesai, pengampu_id, diinput_oleh, atas_nama, diisi_terlambat, catatan)
    values (v_group, v_jenis, v_tgl, v_sesi, ss.nama, ss.jam_mulai, ss.jam_selesai, v_pengampu, v_saya, v_atas, v_kini > ss.tutup, nullif(trim(p->>'catatan'), ''))
    returning id into v_id;
  else
    update student_attendance_sessions set diinput_oleh = v_saya, atas_nama = atas_nama or v_atas,
      pengampu_id = coalesce(pengampu_id, v_pengampu), diisi_terlambat = diisi_terlambat or v_kini > ss.tutup,
      catatan = nullif(trim(p->>'catatan'), '')
    where id = v_id;
  end if;

  delete from student_attendance_exceptions where session_id = v_id;
  insert into student_attendance_exceptions (session_id, student_id, kode, keterangan)
  select v_id, (x->>'student_id')::uuid, x->>'kode', nullif(trim(coalesce(x->>'keterangan', '')), '')
  from jsonb_array_elements(coalesce(p->'pengecualian', '[]')) x;

  update student_attendance_sessions sa set
    jumlah_anggota = (select count(*) from public._anggota_pada(v_group, v_tgl)),
    jumlah_izin = (select count(*) from student_attendance_exceptions where session_id = v_id and kode = 'I'),
    jumlah_sakit = (select count(*) from student_attendance_exceptions where session_id = v_id and kode = 'S'),
    jumlah_bolos = (select count(*) from student_attendance_exceptions where session_id = v_id and kode = 'B'),
    jumlah_absen = (select count(*) from student_attendance_exceptions where session_id = v_id and kode = 'A'),
    jumlah_terlambat = (select count(*) from student_attendance_exceptions where session_id = v_id and kode = 'T')
  where id = v_id;
  update student_attendance_sessions set jumlah_hadir = jumlah_anggota - jumlah_izin - jumlah_sakit - jumlah_absen where id = v_id;

  -- Log perubahan (santri yang kodenya berubah)
  select coalesce(jsonb_agg(jsonb_build_object('student_id', k, 'nama', (select nama_lengkap from students where id = k::uuid),
           'lama', coalesce(v_lama->k->>'kode', 'H'), 'baru', coalesce(v_baru->k->>'kode', 'H'))), '[]') into v_ubah
  from (select jsonb_object_keys(v_lama) k union select jsonb_object_keys(v_baru)) z
  where coalesce(v_lama->k->>'kode', 'H') is distinct from coalesce(v_baru->k->>'kode', 'H')
     or (v_lama->k->>'keterangan') is distinct from (v_baru->k->>'keterangan');
  insert into student_attendance_logs (session_id, oleh, atas_nama, aksi, perubahan)
  values (v_id, v_saya, case when v_atas then v_pengampu end,
          case when exists (select 1 from student_attendance_logs where session_id = v_id) then 'koreksi' else 'isi' end, v_ubah);
  -- v6.2: rujukan klinik otomatis untuk santri yang ditandai Sakit (hanya tanggal hari ini/kemarin)
  if v_tgl >= public.hari_ini() - 1 then
    for r in select * from jsonb_array_elements(v_rujuk) loop
      perform public._rujukan_internal((r->>'student_id')::uuid, trim(r->>'keterangan'),
        case when r->>'periksa' = 'besok' then 'besok' else 'hari_ini' end, 'absensi', v_saya, 'absensi', v_id,
        format('Dari absensi %s %s', lower(ss.nama), g.nama));
    end loop;
  end if;
  if v_jenis = 'ekskul' then
    insert into extracurricular_journals (session_id, topik, uraian, foto_id)
    values (v_id, trim(p->'jurnal'->>'topik'), nullif(trim(coalesce(p->'jurnal'->>'uraian', '')), ''), nullif(p->'jurnal'->>'foto_id', '')::uuid)
    on conflict (session_id) do update set topik = excluded.topik, uraian = excluded.uraian,
      foto_id = coalesce(excluded.foto_id, extracurricular_journals.foto_id), updated_at = now();
  end if;
  return v_id;
end $$;

-- ---------------------------------------------------------------------
-- 9. TEMPLATE WA, HAK EKSEKUSI
-- ---------------------------------------------------------------------
insert into public.wa_templates (kode, nama, isi, variabel, keterangan) values
  ('izin_santri', 'Izin keluar/pulang santri ke wali',
   E'{salam}, Bapak/Ibu {nama_wali}.\n\nKami informasikan izin {jenis_izin} ananda *{nama_santri}* ({kelas}) *{status}*.\n• Alasan: {alasan}\n• Keluar: {waktu_keluar}\n• Batas kembali: {batas_kembali}\n• Penjemput: {penjemput}\n\nMohon ananda diantar kembali ke pondok sebelum batas waktu.\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
   '{nama_wali,nama_santri,kelas,jenis_izin,status,alasan,waktu_keluar,batas_kembali,penjemput,pengirim}', 'Perizinan Santri: kabari orang tua/wali tentang izin keluar/pulang.')
on conflict (kode) do nothing;

do $$
declare f text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'student_permits') then
    alter publication supabase_realtime add table public.student_permits;
  end if;
  foreach f in array array['boleh_kelola_izin()','boleh_putus_izin(text,integer)','boleh_lihat_izin(uuid,text)','pengaturan_izin()',
    'simpan_pengaturan_izin(jsonb)','peran_pengusul_izin(uuid)','hak_izin()','ajukan_izin(jsonb)','lengkapi_izin(uuid,jsonb)',
    'putuskan_izin(uuid,text,text)','batalkan_izin(uuid,text)','catat_gerbang_izin(uuid,text,timestamptz)',
    'daftar_izin(text,date,date,uuid)','status_otomatis_sesi(uuid,date,text)']
  loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['_pejabat_unit(text,integer)','_pimpinan_puncak()','_kabari_pemutus_izin(uuid,integer)','_kabari_hasil_izin(uuid,text,text,text)']
  loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;
grant select on public.student_permits, public.student_permit_approvals to authenticated;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 5 baris, semuanya "Sesuai" (baris 5 boleh "Belum ada …" bila struktur belum diisi)
-- ---------------------------------------------------------------------
select '1. Tabel perizinan santri dengan RLS' as pemeriksaan,
       case when (select count(*) from pg_tables where schemaname = 'public' and rowsecurity and tablename in ('student_permits','student_permit_approvals')) = 2
            then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Status otomatis di absensi', case when exists (select 1 from pg_proc where proname = 'status_otomatis_sesi')
         and position('status_otomatis_sesi' in pg_get_functiondef('public.simpan_absensi_santri'::regproc)) > 0 then 'Sesuai' else 'Periksa' end
union all
select '3. Klinik: waktu mulai sakit dan usulan izin', case when exists (select 1 from information_schema.columns where table_name = 'clinic_cases' and column_name = 'sakit_sejak')
         and exists (select 1 from pg_trigger where tgname = 'zz_usulan_izin') then 'Sesuai' else 'Periksa' end
union all
select '4. Izin admin kelola_izin_santri dan template izin_santri', case when exists (select 1 from public.admin_capabilities where kode = 'kelola_izin_santri')
         and exists (select 1 from public.wa_templates where kode = 'izin_santri') then 'Sesuai' else 'Periksa' end
union all
select '5. Pemutus izin (Kesantrian, Tahfizh, Wustha, SMA, Direktur/Wadir)',
       (select string_agg(k || ' ' || (select count(*) from public._pejabat_unit(k, 30)), ', ') from unnest(array['KESANTRIAN','TAHFIZH','WUSTHA','SMA']) k)
       || ', puncak ' || (select count(*) from public._pimpinan_puncak());
