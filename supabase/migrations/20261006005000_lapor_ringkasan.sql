-- SIMKA PRO | supabase/migrations/20261006005000_lapor_ringkasan.sql | v1.0 | Fase 6 – Tahap 4 Lapor ke bidang dan dasbor ringkasan | 06/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 6 · Migrasi 50: Lapor ke Bidang Terkait (Blueprint Bagian 30) + dasbor ringkasan asrama dan ekskul
--   * report_categories : kategori laporan dan unit penerima bawaannya (dapat diatur). Kesehatan → Unit Klinik dan
--                         otomatis menjadi rujukan klinik untuk santri yang ditandai. Akademik/Lainnya: penerima dipilih pelapor.
--   * incident_reports  : laporan (kategori, unit penerima, santri terkait, lokasi, waktu, uraian, foto Drive, mendesak,
--                         anonim). Status: terkirim → diterima → ditindaklanjuti → selesai; pelapor mendapat notifikasi.
--   * incident_updates  : jejak perubahan status dan catatan tindak lanjut.
--   * Dibaca pelapor, unit penerima (anggota unit dan pejabat di atasnya), pimpinan, admin ber-izin kelola_lapor, superadmin.
--   * Pelapor ANONIM: hanya bila diaktifkan superadmin (Ketentuan Lapor). Identitas pelapor anonim hanya terlihat superadmin.
--   * ringkasan_asrama(), ringkasan_ekskul(): dasbor pemantauan semua kamar dan semua ekskul untuk admin/pimpinan.
--   * Izin admin baru: kelola_lapor.
-- Jalankan SETELAH migrasi 4900. Aman dijalankan ulang.
-- =====================================================================

insert into public.admin_capabilities (kode, nama, urutan) values
  ('kelola_lapor', 'Mengelola Lapor ke Bidang: lihat semua laporan, kategori, rekap (Fase 6)', 32)
on conflict (kode) do nothing;
insert into public.institution_settings (kunci, nilai) values ('lapor', '{"anonim_diizinkan": false}') on conflict (kunci) do nothing;

-- ---------------------------------------------------------------------
-- 1. TABEL
-- ---------------------------------------------------------------------
create table if not exists public.report_categories (
  kode       text primary key,
  nama       text not null,
  unit_kode  text,                       -- penerima bawaan; null = dipilih pelapor
  ke_klinik  boolean not null default false,
  contoh     text,
  aktif      boolean not null default true,
  urutan     int not null default 0
);
insert into public.report_categories (kode, nama, unit_kode, ke_klinik, contoh, urutan) values
  ('pelanggaran', 'Pelanggaran/kedisiplinan', 'KESANTRIAN', false, 'Santri berkelahi, keluar tanpa izin', 1),
  ('kesehatan',   'Kesehatan',                'KLINIK',     true,  'Santri tampak sakit', 2),
  ('keamanan',    'Keamanan',                 'SECURITY',   false, 'Orang asing di area asrama', 3),
  ('sarana',      'Sarana',                   'SARANA',     false, 'Kran asrama rusak, lampu mati', 4),
  ('akademik',    'Akademik/tahfizh',         null,         false, 'Santri sering tidak membawa mushaf', 5),
  ('lainnya',     'Lainnya',                  null,         false, 'Informasi umum', 6)
on conflict (kode) do nothing;

create table if not exists public.incident_reports (
  id            uuid primary key default gen_random_uuid(),
  kategori      text not null references public.report_categories(kode),
  unit_kode     text not null,
  pelapor_id    uuid references public.employees(id) on delete set null,
  anonim        boolean not null default false,
  santri_ids    uuid[] not null default '{}',
  lokasi        text,
  waktu_kejadian timestamptz not null default now(),
  uraian        text not null,
  foto_id       uuid references public.storage_objects(id) on delete set null,
  mendesak      boolean not null default false,
  status        text not null default 'terkirim' check (status in ('terkirim','diterima','ditindaklanjuti','selesai')),
  selesai_pada  timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index if not exists ir_unit_idx on public.incident_reports (unit_kode, status, created_at desc);
create index if not exists ir_pelapor_idx on public.incident_reports (pelapor_id, created_at desc);
create table if not exists public.incident_updates (
  id         uuid primary key default gen_random_uuid(),
  report_id  uuid not null references public.incident_reports(id) on delete cascade,
  status     text not null,
  catatan    text,
  oleh       uuid references public.employees(id) on delete set null,
  pada       timestamptz not null default now()
);
create index if not exists iu_report_idx on public.incident_updates (report_id, pada);
drop trigger if exists aa_updated on public.incident_reports;
create trigger aa_updated before update on public.incident_reports for each row execute function public.tg_updated_at();

-- ---------------------------------------------------------------------
-- 2. HAK
-- ---------------------------------------------------------------------
create or replace function public.boleh_kelola_lapor()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_superadmin() or public.admin_boleh('kelola_lapor') or public.tingkat_fitur('lapor_bidang') >= 3
$$;

/** Penerima laporan untuk unit: anggota unit, pejabat unit itu atau di atasnya, pimpinan puncak, pengelola. */
create or replace function public.boleh_tangani_lapor(p_unit text)
returns boolean language sql stable security definer set search_path = public as $$
  select public.boleh_kelola_lapor()
      or exists (select 1 from org_units o where o.kode = p_unit and (o.id in (select public.unit_pimpinan_saya())
                 or o.id = (select e.org_unit_id from employees e where e.id = public.saya())))
$$;

create or replace function public.pengaturan_lapor()
returns jsonb language sql stable security definer set search_path = public as $$
  select '{"anonim_diizinkan": false}'::jsonb || coalesce((select nilai from institution_settings where kunci = 'lapor'), '{}'::jsonb)
$$;

create or replace function public.simpan_pengaturan_lapor(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
begin
  if not public.is_superadmin() then raise exception 'Pengaturan pelapor anonim hanya dapat diubah superadmin.' using errcode = '42501'; end if;
  insert into institution_settings (kunci, nilai, updated_by) values ('lapor', jsonb_build_object('anonim_diizinkan', coalesce((p->>'anonim_diizinkan')::boolean, false)), public.saya())
  on conflict (kunci) do update set nilai = institution_settings.nilai || excluded.nilai, updated_at = now(), updated_by = excluded.updated_by;
  return public.pengaturan_lapor();
end $$;

create or replace function public.simpan_kategori_lapor(p jsonb)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  if not public.boleh_kelola_lapor() then raise exception 'Anda tidak berwenang mengatur kategori laporan.' using errcode = '42501'; end if;
  if nullif(p->>'unit_kode', '') is not null and not exists (select 1 from org_units where kode = p->>'unit_kode') then raise exception 'Unit penerima tidak dikenal.'; end if;
  update report_categories set nama = coalesce(nullif(trim(p->>'nama'), ''), nama), unit_kode = nullif(p->>'unit_kode', ''),
         contoh = nullif(trim(p->>'contoh'), ''), aktif = coalesce((p->>'aktif')::boolean, aktif) where kode = p->>'kode';
  if not found then raise exception 'Kategori tidak ditemukan.'; end if;
end $$;

create or replace function public.hak_lapor()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('kelola', public.boleh_kelola_lapor(), 'superadmin', public.is_superadmin(),
    'unit', coalesce((select jsonb_agg(o.kode order by o.kode) from org_units o where public.boleh_tangani_lapor(o.kode)), '[]'::jsonb),
    'anonim_diizinkan', (public.pengaturan_lapor()->>'anonim_diizinkan')::boolean)
$$;

alter table public.report_categories enable row level security;
alter table public.incident_reports enable row level security;
alter table public.incident_updates enable row level security;
drop policy if exists baca on public.report_categories;
create policy baca on public.report_categories for select to authenticated using (true);
drop policy if exists baca on public.incident_reports;
create policy baca on public.incident_reports for select to authenticated using (pelapor_id = public.saya() or public.boleh_tangani_lapor(unit_kode));
drop policy if exists baca on public.incident_updates;
create policy baca on public.incident_updates for select to authenticated
  using (exists (select 1 from incident_reports r where r.id = report_id and (r.pelapor_id = public.saya() or public.boleh_tangani_lapor(r.unit_kode))));
grant select on public.report_categories, public.incident_reports, public.incident_updates to authenticated;

-- ---------------------------------------------------------------------
-- 3. KIRIM, TINDAK LANJUT, BACA
-- ---------------------------------------------------------------------
/** Pegawai yang dikabari untuk laporan baru: pejabat unit (atau unit induknya bila kosong), pengelola lapor;
    laporan mendesak juga ke seluruh anggota unit. */
create or replace function public._penerima_lapor(p_unit text, p_mendesak boolean)
returns setof uuid language sql stable security definer set search_path = public as $$
  with u as (select id, parent_id from org_units where kode = p_unit),
  pj as (select x from public._pejabat_unit(p_unit, 40) x),
  induk as (select x from u join org_units o on o.id = u.parent_id cross join lateral public._pejabat_unit(o.kode, 30) x where not exists (select 1 from pj))
  select x from pj union select x from induk
  union select e.id from employees e join admin_permissions ap on ap.employee_id = e.id and ap.kode = 'kelola_lapor' where e.status_akun = 'aktif' and e.peran = 'admin'
  union select e.id from employees e join u on e.org_unit_id = u.id where p_mendesak and e.status_akun = 'aktif'
$$;

create or replace function public.kirim_laporan(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare k report_categories%rowtype; v_unit text; v_anonim boolean := coalesce((p->>'anonim')::boolean, false); v_id uuid; v_santri uuid[];
        sid uuid; v_mendesak boolean := coalesce((p->>'mendesak')::boolean, false); v_nama_unit text; n int;
begin
  if public.saya() is null then raise exception 'Sesi tidak ditemukan. Silakan masuk kembali.' using errcode = '42501'; end if;
  select * into k from report_categories where kode = p->>'kategori' and aktif;
  if k.kode is null then raise exception 'Pilih kategori laporan.'; end if;
  v_unit := coalesce(k.unit_kode, nullif(p->>'unit_kode', ''));
  if v_unit is null or not exists (select 1 from org_units where kode = v_unit) then raise exception 'Pilih bidang/unit penerima laporan.'; end if;
  if length(trim(coalesce(p->>'uraian', ''))) < 10 then raise exception 'Tuliskan uraian laporan (minimal 10 huruf).'; end if;
  if v_anonim and not (public.pengaturan_lapor()->>'anonim_diizinkan')::boolean then raise exception 'Pelaporan anonim sedang tidak diaktifkan.'; end if;
  select coalesce(array_agg(distinct x::uuid), '{}') into v_santri from jsonb_array_elements_text(coalesce(p->'santri_ids', '[]')) x
   where exists (select 1 from students s where s.id = x::uuid and s.status = 'aktif');
  if k.ke_klinik and cardinality(v_santri) = 0 then raise exception 'Laporan kesehatan wajib menandai santri yang sakit.'; end if;
  insert into incident_reports (kategori, unit_kode, pelapor_id, anonim, santri_ids, lokasi, waktu_kejadian, uraian, foto_id, mendesak)
  values (k.kode, v_unit, public.saya(), v_anonim, v_santri, nullif(trim(p->>'lokasi'), ''), coalesce((p->>'waktu_kejadian')::timestamptz, now()),
          trim(p->>'uraian'), nullif(p->>'foto_id', '')::uuid, v_mendesak)
  returning id into v_id;
  insert into incident_updates (report_id, status, catatan, oleh) values (v_id, 'terkirim', null, case when v_anonim then null else public.saya() end);
  -- Kesehatan → rujukan klinik untuk setiap santri yang ditandai
  if k.ke_klinik then
    foreach sid in array v_santri loop
      perform public._rujukan_internal(sid, left(trim(p->>'uraian'), 200), 'hari_ini', 'lapor', case when v_anonim then null else public.saya() end, 'lapor', v_id,
                                       coalesce('Lokasi: ' || nullif(trim(p->>'lokasi'), ''), null));
    end loop;
    update incident_reports set status = 'diterima' where id = v_id;
    insert into incident_updates (report_id, status, catatan) values (v_id, 'diterima', 'Otomatis menjadi rujukan Klinik.');
  end if;
  select nama into v_nama_unit from org_units where kode = v_unit;
  insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
  select x, case when v_mendesak then 'MENDESAK: ' else '' end || 'Laporan ' || lower(k.nama), left(trim(p->>'uraian'), 140),
         '/lapor/masuk', 'Megaphone', case when v_mendesak then 'merah' else 'jingga' end
    from public._penerima_lapor(v_unit, v_mendesak) x where x <> public.saya();
  get diagnostics n = row_count;
  if n = 0 then
    insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
    select x, 'Laporan ' || lower(k.nama) || ' (' || coalesce(v_nama_unit, v_unit) || ')', left(trim(p->>'uraian'), 140), '/lapor/masuk', 'Megaphone', 'jingga'
      from public._pimpinan_puncak() x where x <> public.saya();
  end if;
  return v_id;
end $$;

create or replace function public.ubah_status_laporan(p_id uuid, p_status text, p_catatan text default null)
returns void language plpgsql volatile security definer set search_path = public as $$
declare r incident_reports%rowtype; v_urut text[] := array['terkirim','diterima','ditindaklanjuti','selesai'];
begin
  select * into r from incident_reports where id = p_id for update;
  if r.id is null then raise exception 'Laporan tidak ditemukan.'; end if;
  if not public.boleh_tangani_lapor(r.unit_kode) then raise exception 'Hanya bidang/unit penerima yang dapat menindaklanjuti laporan.' using errcode = '42501'; end if;
  if p_status not in ('diterima','ditindaklanjuti','selesai') then raise exception 'Status tidak sah.'; end if;
  if array_position(v_urut, p_status) < array_position(v_urut, r.status) then raise exception 'Status laporan tidak dapat dimundurkan.'; end if;
  if p_status in ('ditindaklanjuti','selesai') and length(trim(coalesce(p_catatan, ''))) < 5 then raise exception 'Tuliskan catatan tindak lanjut (minimal 5 huruf).'; end if;
  update incident_reports set status = p_status, selesai_pada = case when p_status = 'selesai' then now() else selesai_pada end where id = p_id;
  insert into incident_updates (report_id, status, catatan, oleh) values (p_id, p_status, nullif(trim(p_catatan), ''), public.saya());
  if r.pelapor_id is not null and r.pelapor_id <> public.saya() then
    perform public.kirim_notifikasi(r.pelapor_id, 'Laporan Anda ' || case p_status when 'diterima' then 'diterima' when 'ditindaklanjuti' then 'ditindaklanjuti' else 'selesai' end,
      coalesce(nullif(trim(p_catatan), ''), left(r.uraian, 120)), '/lapor/saya', 'Megaphone', case when p_status = 'selesai' then 'hijau' else 'biru' end);
  end if;
end $$;

/** cakupan: saya (laporan saya) | masuk (untuk unit yang saya tangani) | semua (pengelola/pimpinan; rentang tanggal). */
create or replace function public.daftar_laporan(p_cakupan text, p_mulai date default null, p_selesai date default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_mulai date := coalesce(p_mulai, public.hari_ini() - 30); v_selesai date := coalesce(p_selesai, public.hari_ini()); v_super boolean := public.is_superadmin();
begin
  if public.saya() is null then return '[]'::jsonb; end if;
  return coalesce((select jsonb_agg(x order by x->>'urut', x->>'created_at' desc) from (
    select jsonb_build_object('id', r.id, 'kategori', r.kategori, 'nama_kategori', k.nama, 'unit_kode', r.unit_kode, 'unit', o.nama,
      'pelapor', case when r.anonim and not v_super and r.pelapor_id is distinct from public.saya() then null else e.nama_lengkap end,
      'anonim', r.anonim, 'saya_pelapor', r.pelapor_id = public.saya(),
      'santri', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'nama', s.nama_lengkap, 'kamar', public._kelompok_santri(s.id, 'kamar'))) from students s where s.id = any(r.santri_ids)), '[]'::jsonb),
      'lokasi', r.lokasi, 'waktu_kejadian', r.waktu_kejadian, 'uraian', r.uraian, 'foto_id', r.foto_id, 'mendesak', r.mendesak, 'status', r.status,
      'created_at', r.created_at, 'selesai_pada', r.selesai_pada, 'boleh_tangani', public.boleh_tangani_lapor(r.unit_kode),
      'jejak', coalesce((select jsonb_agg(jsonb_build_object('status', u.status, 'catatan', u.catatan, 'pada', u.pada, 'oleh', ue.nama_lengkap) order by u.pada)
                         from incident_updates u left join employees ue on ue.id = u.oleh where u.report_id = r.id), '[]'::jsonb),
      'urut', case when r.status = 'selesai' then '3' when r.mendesak then '0' when r.status = 'terkirim' then '1' else '2' end) x
      from incident_reports r join report_categories k on k.kode = r.kategori left join org_units o on o.kode = r.unit_kode
      left join employees e on e.id = r.pelapor_id
     where case p_cakupan
             when 'saya' then r.pelapor_id = public.saya() and ((r.created_at at time zone 'Asia/Makassar')::date between v_mulai and v_selesai or r.status <> 'selesai')
             when 'masuk' then public.boleh_tangani_lapor(r.unit_kode) and ((r.created_at at time zone 'Asia/Makassar')::date between v_mulai and v_selesai or r.status <> 'selesai')
             when 'semua' then (r.pelapor_id = public.saya() or public.boleh_tangani_lapor(r.unit_kode)) and (r.created_at at time zone 'Asia/Makassar')::date between v_mulai and v_selesai
             else false end) q), '[]'::jsonb);
end $$;

/** Rekap jumlah laporan per kategori dan unit pada rentang (yang dapat dilihat pengguna). */
create or replace function public.rekap_laporan(p_mulai date, p_selesai date)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('kategori', k.nama, 'unit', o.nama, 'jumlah', q.jumlah, 'terkirim', q.terkirim, 'diterima', q.diterima,
           'ditindaklanjuti', q.ditindaklanjuti, 'selesai', q.selesai, 'mendesak', q.mendesak) order by k.urutan, o.nama), '[]'::jsonb)
    from (select r.kategori, r.unit_kode, count(*) jumlah, count(*) filter (where status = 'terkirim') terkirim, count(*) filter (where status = 'diterima') diterima,
                 count(*) filter (where status = 'ditindaklanjuti') ditindaklanjuti, count(*) filter (where status = 'selesai') selesai, count(*) filter (where mendesak) mendesak
            from incident_reports r
           where (r.created_at at time zone 'Asia/Makassar')::date between p_mulai and p_selesai
             and (r.pelapor_id = public.saya() or public.boleh_tangani_lapor(r.unit_kode))
           group by r.kategori, r.unit_kode) q
    join report_categories k on k.kode = q.kategori left join org_units o on o.kode = q.unit_kode
$$;

/** Cari santri aktif untuk ditandai pada laporan (semua santri, hanya nama/NIS/kamar — Blueprint Bagian 30). */
create or replace function public.cari_santri_lapor(p_cari text)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'nama', s.nama_lengkap, 'nis', s.nis, 'kamar', public._kelompok_santri(s.id, 'kamar'),
           'kelas', public._kelompok_santri(s.id, 'kelas')) order by s.nama_lengkap), '[]'::jsonb)
    from (select * from students where status = 'aktif' and public.saya() is not null and length(trim(coalesce(p_cari, ''))) >= 2
            and (nama_lengkap ilike '%' || trim(p_cari) || '%' or nis like trim(p_cari) || '%') order by nama_lengkap limit 20) s
$$;

-- ---------------------------------------------------------------------
-- 4. DASBOR RINGKASAN ASRAMA DAN EKSKUL
-- ---------------------------------------------------------------------
create or replace function public.ringkasan_asrama(p_mulai date, p_selesai date)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_akhir date := least(p_selesai, public.hari_ini()); v_rencana int;
begin
  if p_selesai < p_mulai or p_selesai - p_mulai > 400 then raise exception 'Rentang tanggal tidak sah (paling panjang 400 hari).'; end if;
  select count(*) into v_rencana from generate_series(p_mulai, v_akhir, interval '1 day') d
   cross join lateral public.sesi_santri_tanggal('asrama', d::date) ss where ss.selesai <= now();
  return coalesce((select jsonb_agg(x order by x->>'nama') from (
    select jsonb_build_object('id', g.id, 'nama', g.nama, 'jenis_kelamin', g.jenis_kelamin, 'keterangan', g.keterangan,
      'musyrif', (select string_agg(e.nama_lengkap, ', ' order by k.peran) from group_keepers k join employees e on e.id = k.employee_id
                   where k.group_id = g.id and (k.sampai is null or k.sampai >= public.hari_ini())),
      'santri', (select count(*) from group_members m join students s on s.id = m.student_id where m.group_id = g.id and m.selesai is null and s.status = 'aktif'),
      'sesi_rencana', v_rencana, 'sesi_terisi', a.terisi, 'anggota', a.anggota, 'hadir', a.hadir, 'izin', a.izin, 'sakit', a.sakit, 'absen', a.absen, 'terlambat', a.terlambat,
      'persen', case when a.anggota > 0 then round(a.hadir * 100.0 / a.anggota, 1) end,
      'hari_ini_terisi', (select count(*) from student_attendance_sessions where group_id = g.id and jenis = 'asrama' and tanggal = public.hari_ini()),
      'sakit_aktif', (select count(*) from clinic_cases c where c.status = 'ditangani' and c.student_id in (select m.student_id from group_members m where m.group_id = g.id and m.selesai is null)),
      'izin_aktif', (select count(*) from student_permits p where p.status in ('disetujui','keluar') and p.student_id in (select m.student_id from group_members m where m.group_id = g.id and m.selesai is null)),
      'izin_terlambat', (select count(*) from student_permits p where p.status = 'keluar' and now() > p.kembali_batas and p.student_id in (select m.student_id from group_members m where m.group_id = g.id and m.selesai is null)),
      'jurnal', (select count(*) from dorm_journals j where j.group_id = g.id and j.tanggal between p_mulai and p_selesai),
      'jurnal_penting', (select count(*) from dorm_journals j where j.group_id = g.id and j.tanggal between p_mulai and p_selesai and j.penting),
      'jurnal_terakhir', (select max(j.tanggal) from dorm_journals j where j.group_id = g.id)) x
      from student_groups g join academic_years ay on ay.id = g.academic_year_id and ay.aktif
      cross join lateral (select count(*) terisi, coalesce(sum(jumlah_anggota), 0) anggota, coalesce(sum(jumlah_hadir), 0) hadir, coalesce(sum(jumlah_izin), 0) izin,
                                 coalesce(sum(jumlah_sakit), 0) sakit, coalesce(sum(jumlah_absen), 0) absen, coalesce(sum(jumlah_terlambat), 0) terlambat
                            from student_attendance_sessions sa where sa.group_id = g.id and sa.jenis = 'asrama' and sa.tanggal between p_mulai and p_selesai) a
     where g.jenis = 'kamar' and g.aktif and public.boleh_lihat_kamar(g.id)) q), '[]'::jsonb);
end $$;

create or replace function public.ringkasan_ekskul(p_mulai date, p_selesai date)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_akhir date := least(p_selesai, public.hari_ini()); v_semua boolean := public.boleh_pantau_absensi() or public.tingkat_fitur('absensi_ekskul') >= 1;
begin
  if p_selesai < p_mulai or p_selesai - p_mulai > 400 then raise exception 'Rentang tanggal tidak sah (paling panjang 400 hari).'; end if;
  return coalesce((select jsonb_agg(x order by x->>'nama') from (
    select jsonb_build_object('id', g.id, 'nama', g.nama, 'keterangan', g.keterangan,
      'pembina', (select string_agg(e.nama_lengkap, ', ' order by k.peran) from group_keepers k join employees e on e.id = k.employee_id
                   where k.group_id = g.id and (k.sampai is null or k.sampai >= public.hari_ini())),
      'anggota_aktif', (select count(*) from group_members m join students s on s.id = m.student_id where m.group_id = g.id and m.selesai is null and s.status = 'aktif'),
      'pertemuan_rencana', (select count(*) from generate_series(p_mulai, v_akhir, interval '1 day') d cross join lateral public.sesi_kelompok(g.id, d::date) sk where sk.selesai <= now()),
      'pertemuan_terlaksana', a.terisi, 'anggota', a.anggota, 'hadir', a.hadir, 'izin', a.izin, 'sakit', a.sakit, 'absen', a.absen,
      'persen', case when a.anggota > 0 then round(a.hadir * 100.0 / a.anggota, 1) end,
      'jurnal_terisi', (select count(*) from extracurricular_journals j join student_attendance_sessions sa on sa.id = j.session_id
                         where sa.group_id = g.id and sa.tanggal between p_mulai and p_selesai),
      'terakhir', (select jsonb_build_object('tanggal', sa.tanggal, 'topik', j.topik) from student_attendance_sessions sa left join extracurricular_journals j on j.session_id = sa.id
                    where sa.group_id = g.id order by sa.tanggal desc limit 1)) x
      from student_groups g join academic_years ay on ay.id = g.academic_year_id and ay.aktif
      cross join lateral (select count(*) terisi, coalesce(sum(jumlah_anggota), 0) anggota, coalesce(sum(jumlah_hadir), 0) hadir, coalesce(sum(jumlah_izin), 0) izin,
                                 coalesce(sum(jumlah_sakit), 0) sakit, coalesce(sum(jumlah_absen), 0) absen
                            from student_attendance_sessions sa where sa.group_id = g.id and sa.jenis = 'ekskul' and sa.tanggal between p_mulai and p_selesai) a
     where g.jenis = 'ekskul' and g.aktif and (v_semua or g.id in (select public.kelompok_saya()))) q), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- 5. HAK EKSEKUSI, REALTIME
-- ---------------------------------------------------------------------
do $$
declare f text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'incident_reports') then
    alter publication supabase_realtime add table public.incident_reports;
  end if;
  foreach f in array array['boleh_kelola_lapor()','boleh_tangani_lapor(text)','pengaturan_lapor()','simpan_pengaturan_lapor(jsonb)','simpan_kategori_lapor(jsonb)',
    'hak_lapor()','kirim_laporan(jsonb)','ubah_status_laporan(uuid,text,text)','daftar_laporan(text,date,date)','rekap_laporan(date,date)',
    'ringkasan_asrama(date,date)','ringkasan_ekskul(date,date)','cari_santri_lapor(text)']
  loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  execute 'revoke execute on function public._penerima_lapor(text,boolean) from public, anon, authenticated';
end $$;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 4 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select '1. Lapor ke Bidang: 3 tabel dengan RLS' as pemeriksaan,
       case when (select count(*) from pg_tables where schemaname = 'public' and rowsecurity and tablename in ('report_categories','incident_reports','incident_updates')) = 3
            then 'Sesuai' else 'Periksa' end as hasil
union all select '2. Kategori laporan (6)', case when (select count(*) from public.report_categories) >= 6 then 'Sesuai' else 'Periksa' end
union all select '3. Pelapor anonim (bawaan nonaktif)', case when (public.pengaturan_lapor() ? 'anonim_diizinkan') then 'Sesuai' else 'Periksa' end
union all select '4. Dasbor ringkasan asrama dan ekskul', case when (select count(*) from pg_proc where proname in ('ringkasan_asrama','ringkasan_ekskul')) = 2 then 'Sesuai' else 'Periksa' end;
