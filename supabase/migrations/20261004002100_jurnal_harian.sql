-- SIMKA PRO | supabase/migrations/20261004002100_jurnal_harian.sql | v1.0 | Fase 3 – Tahap 3 Jurnal harian | 04/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 3 · Migrasi 21: Jurnal harian pegawai
--   * journal_items    : butir ceklist per jabatan fungsional, jabatan struktural, bidang/unit, atau semua pegawai
--                        (isi awal contoh; dapat disunting admin ber-izin atur_jurnal dan superadmin)
--   * journal_checks   : butir ceklist yang dicentang pegawai per tanggal (langsung tercatat, tanpa verval)
--   * journal_entries  : kegiatan yang ditulis sendiri (jam, uraian, foto) → wajib diverval
--   * Batas pengisian H+1; setelah itu terkunci dan hari wajib tanpa isian tercatat "tidak diisi"
--   * rekap_jurnal(...) dan jurnal_pegawai(...) untuk laporan persentase pengisian
-- Jalankan SETELAH migrasi 2000. Aman dijalankan ulang.
-- =====================================================================

insert into public.admin_capabilities (kode, nama, urutan) values
  ('atur_jurnal', 'Mengatur template ceklist jurnal harian (Fase 3)', 10),
  ('verval_jurnal', 'Verval kegiatan jurnal dan melihat rekap jurnal (Fase 3)', 11)
on conflict (kode) do nothing;

-- ---------------------------------------------------------------------
-- 1. Butir ceklist
-- ---------------------------------------------------------------------
create table if not exists public.journal_items (
  id                     uuid primary key default gen_random_uuid(),
  functional_position_id uuid references public.functional_positions(id) on delete cascade,
  structural_position_id uuid references public.structural_positions(id) on delete cascade,
  org_unit_id            uuid references public.org_units(id) on delete cascade,
  uraian                 text not null check (length(trim(uraian)) >= 3),
  urutan                 int not null default 0,
  aktif                  boolean not null default true,
  created_at             timestamptz not null default now(),
  check (num_nonnulls(functional_position_id, structural_position_id, org_unit_id) <= 1)
);
create index if not exists journal_items_fung_idx on public.journal_items (functional_position_id);

create table if not exists public.journal_checks (
  employee_id uuid not null references public.employees(id) on delete cascade,
  tanggal     date not null,
  item_id     uuid not null references public.journal_items(id) on delete cascade,
  uraian      text not null,             -- salinan uraian saat dicentang (laporan tetap utuh bila template diubah)
  catatan     text,
  waktu       timestamptz not null default now(),
  primary key (employee_id, tanggal, item_id)
);
create index if not exists journal_checks_tgl_idx on public.journal_checks (tanggal);

create table if not exists public.journal_entries (
  id            uuid primary key default gen_random_uuid(),
  employee_id   uuid not null references public.employees(id) on delete cascade,
  tanggal       date not null,
  jam_mulai     time not null,
  jam_selesai   time not null check (jam_selesai > jam_mulai),
  uraian        text not null check (length(trim(uraian)) >= 5),
  foto_id       uuid references public.storage_objects(id) on delete set null,
  status        text not null default 'menunggu' check (status in ('menunggu','disetujui','dikembalikan')),
  catatan_verval text,
  diverval_oleh uuid references public.employees(id) on delete set null,
  diverval_pada timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index if not exists journal_entries_emp_idx on public.journal_entries (employee_id, tanggal);
create index if not exists journal_entries_status_idx on public.journal_entries (status) where status = 'menunggu';

alter table public.journal_items enable row level security;
alter table public.journal_checks enable row level security;
alter table public.journal_entries enable row level security;

drop trigger if exists aa_updated on public.journal_entries;
create trigger aa_updated before update on public.journal_entries for each row execute function public.tg_updated_at();
drop trigger if exists zz_audit on public.journal_items;
create trigger zz_audit after insert or update or delete on public.journal_items for each row execute function public.tg_audit();

create or replace function public.boleh_lihat_jurnal(p_emp uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select p_emp = public.saya() or public.admin_boleh('verval_jurnal') or public.pimpinan_dari(p_emp)
$$;

drop policy if exists baca on public.journal_items;
create policy baca on public.journal_items for select to authenticated using (true);
drop policy if exists kelola on public.journal_items;
create policy kelola on public.journal_items for all to authenticated
  using (public.admin_boleh('atur_jurnal')) with check (public.admin_boleh('atur_jurnal'));
drop policy if exists baca on public.journal_checks;
create policy baca on public.journal_checks for select to authenticated using (public.boleh_lihat_jurnal(employee_id));
drop policy if exists baca on public.journal_entries;
create policy baca on public.journal_entries for select to authenticated using (public.boleh_lihat_jurnal(employee_id));
-- Penulisan ceklist dan kegiatan hanya lewat fungsi (batas H+1 diperiksa server).

-- ---------------------------------------------------------------------
-- 2. Isi awal contoh ceklist (dapat disunting di menu Jurnal Harian → Template)
-- ---------------------------------------------------------------------
insert into public.journal_items (functional_position_id, uraian, urutan)
select fp.id, v.uraian, v.urutan
  from (values
    ('GURU', 'Mengajar sesuai jadwal dan mengisi jurnal mengajar', 1),
    ('GURU', 'Menyiapkan perangkat/bahan ajar untuk pertemuan berikutnya', 2),
    ('GURU', 'Memeriksa tugas atau hasil belajar santri', 3),
    ('GURU', 'Mencatat santri yang tidak hadir atau perlu pendampingan', 4),
    ('WALI_KELAS', 'Mengabsen santri di kelas', 1),
    ('WALI_KELAS', 'Memantau kerapian dan kedisiplinan santri kelas', 2),
    ('WALI_KELAS', 'Menindaklanjuti santri yang tidak hadir', 3),
    ('MUHAFFIZH', 'Membimbing halaqah subuh', 1),
    ('MUHAFFIZH', 'Membimbing halaqah sore', 2),
    ('MUHAFFIZH', 'Membimbing halaqah malam', 3),
    ('MUHAFFIZH', 'Mencatat setoran sabaq, sabqi, dan manzil', 4),
    ('MUHAFFIZH', 'Memotivasi santri yang hafalannya tertinggal', 5),
    ('MUSYRIF', 'Membangunkan santri untuk shalat Subuh', 1),
    ('MUSYRIF', 'Memimpin apel malam dan mengabsen santri asrama', 2),
    ('MUSYRIF', 'Memeriksa kebersihan dan kerapian kamar', 3),
    ('MUSYRIF', 'Mendampingi santri pada jam belajar malam', 4),
    ('MUSYRIF', 'Mencatat santri sakit atau izin dan melapor ke bidang terkait', 5),
    ('PEMBINA_EKSKUL', 'Melaksanakan kegiatan ekskul sesuai jadwal', 1),
    ('PEMBINA_EKSKUL', 'Mencatat kehadiran dan materi ekskul', 2),
    ('OPERATOR', 'Memperbarui data pada aplikasi/administrasi', 1),
    ('OPERATOR', 'Melayani permintaan data dari bidang', 2),
    ('STAF_BIDANG', 'Menyelesaikan administrasi bidang', 1),
    ('STAF_BIDANG', 'Mengarsipkan surat dan dokumen bidang', 2),
    ('STAF_BIDANG', 'Melaporkan pekerjaan kepada kepala bidang', 3),
    ('STAF_PEMBANTU', 'Melaksanakan tugas yang diberikan atasan', 1),
    ('MEDIS', 'Memeriksa santri yang dirujuk ke klinik', 1),
    ('MEDIS', 'Mencatat pemeriksaan dan pemberian obat', 2),
    ('MEDIS', 'Memeriksa stok obat dan alat kesehatan', 3),
    ('MEDIS', 'Memantau santri yang dirawat', 4),
    ('SECURITY', 'Berjaga di gerbang sesuai shift', 1),
    ('SECURITY', 'Berkeliling memeriksa area pondok', 2),
    ('SECURITY', 'Mencatat tamu, titipan, dan santri keluar/masuk', 3),
    ('SECURITY', 'Serah terima tugas dengan petugas shift berikutnya', 4),
    ('KEBERSIHAN', 'Membersihkan area sesuai pembagian', 1),
    ('KEBERSIHAN', 'Mengangkut sampah ke tempat pembuangan', 2),
    ('LOGISTIK', 'Memeriksa dan mencatat persediaan barang', 1),
    ('LOGISTIK', 'Melayani permintaan barang dari bidang', 2),
    ('MEDIA', 'Mendokumentasikan kegiatan pondok', 1),
    ('MEDIA', 'Mengunggah informasi ke media pondok', 2),
    ('SARPRAS', 'Memeriksa kondisi sarana dan prasarana', 1),
    ('SARPRAS', 'Menindaklanjuti laporan kerusakan', 2)
  ) v(kode, uraian, urutan)
  join public.functional_positions fp on fp.kode = v.kode
 where not exists (select 1 from public.journal_items);

insert into public.journal_items (structural_position_id, uraian, urutan)
select sp.id, v.uraian, v.urutan
  from (values ('KEPALA_BIDANG', 'Memantau kehadiran dan kinerja anggota bidang', 1),
               ('KEPALA_BIDANG', 'Menindaklanjuti pengajuan dan laporan anggota bidang', 2),
               ('KEPALA_UNIT', 'Memantau pelaksanaan tugas unit', 1)) v(kode, uraian, urutan)
  join public.structural_positions sp on sp.kode = v.kode
 where not exists (select 1 from public.journal_items where structural_position_id is not null);

-- ---------------------------------------------------------------------
-- 3. Fungsi bantu
-- ---------------------------------------------------------------------
/** Butir ceklist yang berlaku bagi seorang pegawai (gabungan semua jabatannya, unitnya beserta induknya, dan butir umum). */
create or replace function public.butir_jurnal(p_emp uuid)
returns table (item_id uuid, kelompok text, uraian text, urutan int)
language sql stable security definer set search_path = public as $$
  with recursive induk(id) as (
    select org_unit_id from employees where id = p_emp
    union all select u.parent_id from org_units u join induk i on u.id = i.id where u.parent_id is not null
  )
  select i.id,
         coalesce(fp.nama, sp.nama, u.nama, 'Umum'),
         i.uraian,
         case when fp.id is not null then 100 + fp.urutan * 100 when sp.id is not null then 50 + sp.urutan when u.id is not null then 2000 else 0 end * 100 + i.urutan
    from journal_items i
    left join functional_positions fp on fp.id = i.functional_position_id
    left join structural_positions sp on sp.id = i.structural_position_id
    left join org_units u on u.id = i.org_unit_id
   where i.aktif and (
         (i.functional_position_id is null and i.structural_position_id is null and i.org_unit_id is null)
      or i.functional_position_id in (select functional_position_id from employee_functions where employee_id = p_emp)
      or i.structural_position_id in (select structural_position_id from employee_structurals where employee_id = p_emp)
      or i.org_unit_id in (select id from induk where id is not null))
   order by 4
$$;

/** Hari wajib jurnal: ada sesi wajib pada jadwal dan tidak sedang izin/sakit/cuti dari pengajuan yang disetujui. */
create or replace function public.wajib_jurnal(p_emp uuid, p_tanggal date)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.jadwal_pegawai(p_emp, p_tanggal) j where not j.opsional)
     and not exists (select 1 from leave_requests r join leave_types t on t.id = r.leave_type_id
                      where r.employee_id = p_emp and r.status = 'disetujui' and t.kelompok <> 'dinas_luar'
                        and p_tanggal between r.mulai and r.selesai)
$$;

create or replace function public._jurnal_terbuka(p_tanggal date)
returns boolean language sql stable as $$
  select p_tanggal <= public.hari_ini() and p_tanggal >= public.hari_ini() - 1
$$;

-- ---------------------------------------------------------------------
-- 4. Pengisian oleh pegawai
-- ---------------------------------------------------------------------
create or replace function public.jurnal_saya(p_tanggal date default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_emp uuid := public.saya(); v_tgl date := coalesce(p_tanggal, public.hari_ini());
begin
  if v_emp is null then raise exception 'Akun Anda belum aktif.' using errcode = '42501'; end if;
  return jsonb_build_object(
    'tanggal', v_tgl, 'terbuka', public._jurnal_terbuka(v_tgl), 'wajib', public.wajib_jurnal(v_emp, v_tgl),
    'butir', (select coalesce(jsonb_agg(jsonb_build_object('item_id', b.item_id, 'kelompok', b.kelompok, 'uraian', b.uraian,
                'selesai', c.item_id is not null, 'catatan', c.catatan, 'waktu', c.waktu) order by b.urutan), '[]')
                from public.butir_jurnal(v_emp) b
                left join journal_checks c on c.employee_id = v_emp and c.tanggal = v_tgl and c.item_id = b.item_id),
    -- butir yang dicentang tetapi sudah tidak berlaku lagi (template diubah) tetap ditampilkan
    'butir_lama', (select coalesce(jsonb_agg(jsonb_build_object('item_id', c.item_id, 'uraian', c.uraian, 'catatan', c.catatan)), '[]')
                     from journal_checks c where c.employee_id = v_emp and c.tanggal = v_tgl
                      and c.item_id not in (select item_id from public.butir_jurnal(v_emp))),
    'kegiatan', (select coalesce(jsonb_agg(to_jsonb(e) order by e.jam_mulai), '[]') from journal_entries e where e.employee_id = v_emp and e.tanggal = v_tgl));
end $$;

create or replace function public.centang_jurnal(p_tanggal date, p_item uuid, p_selesai boolean, p_catatan text default null)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v_emp uuid := public.saya(); v_uraian text;
begin
  if v_emp is null then raise exception 'Akun Anda belum aktif.' using errcode = '42501'; end if;
  if not public._jurnal_terbuka(p_tanggal) then raise exception 'Jurnal tanggal ini sudah terkunci (batas pengisian H+1).'; end if;
  if not p_selesai then
    delete from journal_checks where employee_id = v_emp and tanggal = p_tanggal and item_id = p_item; return;
  end if;
  select uraian into v_uraian from public.butir_jurnal(v_emp) where item_id = p_item;
  if v_uraian is null then raise exception 'Butir ini tidak termasuk ceklist jabatan Anda.'; end if;
  insert into journal_checks (employee_id, tanggal, item_id, uraian, catatan)
  values (v_emp, p_tanggal, p_item, v_uraian, nullif(trim(coalesce(p_catatan, '')), ''))
  on conflict (employee_id, tanggal, item_id) do update set catatan = excluded.catatan, waktu = now();
end $$;

create or replace function public.simpan_kegiatan_jurnal(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_emp uuid := public.saya(); v_id uuid := nullif(p->>'id', '')::uuid; e journal_entries; v_tgl date := (p->>'tanggal')::date;
begin
  if v_emp is null then raise exception 'Akun Anda belum aktif.' using errcode = '42501'; end if;
  if length(trim(coalesce(p->>'uraian', ''))) < 5 then raise exception 'Uraian kegiatan minimal 5 karakter.'; end if;
  if (p->>'jam_selesai')::time <= (p->>'jam_mulai')::time then raise exception 'Jam selesai harus setelah jam mulai.'; end if;
  if v_id is null then
    if not public._jurnal_terbuka(v_tgl) then raise exception 'Jurnal tanggal ini sudah terkunci (batas pengisian H+1).'; end if;
    insert into journal_entries (employee_id, tanggal, jam_mulai, jam_selesai, uraian, foto_id)
    values (v_emp, v_tgl, (p->>'jam_mulai')::time, (p->>'jam_selesai')::time, trim(p->>'uraian'), nullif(p->>'foto_id', '')::uuid)
    returning id into v_id;
    return v_id;
  end if;
  select * into e from journal_entries where id = v_id and employee_id = v_emp;
  if not found then raise exception 'Kegiatan tidak ditemukan.'; end if;
  if e.status = 'disetujui' then raise exception 'Kegiatan yang sudah disetujui tidak dapat diubah.'; end if;
  -- Kegiatan yang dikembalikan boleh diperbaiki sampai 7 hari setelah dikembalikan
  if e.status = 'menunggu' and not public._jurnal_terbuka(e.tanggal) then raise exception 'Jurnal tanggal ini sudah terkunci (batas pengisian H+1).'; end if;
  if e.status = 'dikembalikan' and e.diverval_pada < now() - interval '7 days' then raise exception 'Batas perbaikan (7 hari setelah dikembalikan) sudah lewat.'; end if;
  update journal_entries set jam_mulai = (p->>'jam_mulai')::time, jam_selesai = (p->>'jam_selesai')::time, uraian = trim(p->>'uraian'),
         foto_id = coalesce(nullif(p->>'foto_id', '')::uuid, foto_id), status = 'menunggu'
   where id = v_id;
  return v_id;
end $$;

create or replace function public.hapus_kegiatan_jurnal(p_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  delete from journal_entries where id = p_id and employee_id = public.saya() and status <> 'disetujui'
     and (public._jurnal_terbuka(tanggal) or status = 'dikembalikan');
  if not found then raise exception 'Kegiatan tidak dapat dihapus (sudah disetujui atau jurnal terkunci).'; end if;
end $$;

-- ---------------------------------------------------------------------
-- 5. Verval kegiatan
-- ---------------------------------------------------------------------
create or replace function public.antrian_verval_jurnal(p_status text default 'menunggu')
returns table (id uuid, employee_id uuid, nama text, unit text, tanggal date, jam_mulai time, jam_selesai time, uraian text,
               foto_id uuid, status text, catatan_verval text, diverval_pada timestamptz, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select e.id, e.employee_id, p.nama_lengkap, u.nama, e.tanggal, e.jam_mulai, e.jam_selesai, e.uraian, e.foto_id, e.status,
         e.catatan_verval, e.diverval_pada, e.created_at
    from journal_entries e join employees p on p.id = e.employee_id left join org_units u on u.id = p.org_unit_id
   where public.admin_boleh('verval_jurnal') and e.status = p_status
     and (p_status = 'menunggu' or e.diverval_pada > now() - interval '30 days')
   order by e.tanggal, e.jam_mulai
   limit 500
$$;

create or replace function public.verval_jurnal(p_ids uuid[], p_setuju boolean, p_catatan text default null)
returns int language plpgsql volatile security definer set search_path = public as $$
declare n int; r record;
begin
  if not public.admin_boleh('verval_jurnal') then raise exception 'Anda tidak memiliki izin verval jurnal.' using errcode = '42501'; end if;
  if not p_setuju and length(trim(coalesce(p_catatan, ''))) < 5 then raise exception 'Catatan wajib diisi saat mengembalikan (minimal 5 karakter).'; end if;
  if exists (select 1 from journal_entries where id = any (p_ids) and employee_id = public.saya()) then
    raise exception 'Anda tidak dapat memverval jurnal Anda sendiri.';
  end if;
  update journal_entries set status = case when p_setuju then 'disetujui' else 'dikembalikan' end,
         catatan_verval = nullif(trim(coalesce(p_catatan, '')), ''), diverval_oleh = public.saya(), diverval_pada = now()
   where id = any (p_ids) and status = 'menunggu';
  get diagnostics n = row_count;
  for r in select employee_id, count(*) jml, min(tanggal) tgl from journal_entries where id = any (p_ids) and diverval_oleh = public.saya()
              and diverval_pada > now() - interval '5 seconds' group by employee_id loop
    perform public.kirim_notifikasi(r.employee_id,
      case when p_setuju then 'Kegiatan jurnal disetujui' else 'Kegiatan jurnal dikembalikan' end,
      r.jml || ' kegiatan' || case when p_setuju then ' disetujui.' else ' perlu diperbaiki: ' || trim(p_catatan) end,
      '/jurnal/harian?tanggal=' || r.tgl, case when p_setuju then 'CheckCircle' else 'Notebook' end, case when p_setuju then 'hijau' else 'jingga' end);
  end loop;
  return n;
end $$;

-- ---------------------------------------------------------------------
-- 6. Rekap dan laporan
-- ---------------------------------------------------------------------
/** Rekap per pegawai pada suatu periode. Pegawai biasa hanya mendapat barisnya sendiri; pimpinan melihat anggota unitnya. */
create or replace function public.rekap_jurnal(p_mulai date, p_akhir date)
returns table (employee_id uuid, nama text, niy text, unit text, org_unit_id uuid, hari_wajib int, hari_terisi int, hari_kosong int,
               persen numeric, butir int, kegiatan_disetujui int, kegiatan_menunggu int, kegiatan_dikembalikan int)
language plpgsql stable security definer set search_path = public as $$
declare v_akhir date := least(p_akhir, public.hari_ini());
begin
  if p_akhir - p_mulai > 92 then raise exception 'Rentang rekap paling panjang 3 bulan.'; end if;
  return query
  with peg as (
    select e.id, e.nama_lengkap, e.niy, e.org_unit_id from employees e
     where e.status_keaktifan = 'aktif' and e.status_akun = 'aktif' and public.boleh_lihat_jurnal(e.id)
  ), hari as (
    select p.id emp, d::date tgl from peg p, generate_series(p_mulai, v_akhir, interval '1 day') d
  ), isi as (
    select h.emp, h.tgl, public.wajib_jurnal(h.emp, h.tgl) wajib,
           exists (select 1 from journal_checks c where c.employee_id = h.emp and c.tanggal = h.tgl)
           or exists (select 1 from journal_entries x where x.employee_id = h.emp and x.tanggal = h.tgl and x.status <> 'dikembalikan') terisi
      from hari h
  )
  select p.id, p.nama_lengkap, p.niy, u.nama, p.org_unit_id,
         count(*) filter (where i.wajib)::int,
         count(*) filter (where i.wajib and i.terisi)::int,
         -- hari yang sudah terkunci (lewat H+1) dan tidak diisi
         count(*) filter (where i.wajib and not i.terisi and i.tgl < public.hari_ini() - 1)::int,
         case when count(*) filter (where i.wajib) > 0
              then round(100.0 * count(*) filter (where i.wajib and i.terisi) / count(*) filter (where i.wajib), 1) end,
         (select count(*)::int from journal_checks c where c.employee_id = p.id and c.tanggal between p_mulai and v_akhir),
         (select count(*)::int from journal_entries x where x.employee_id = p.id and x.tanggal between p_mulai and v_akhir and x.status = 'disetujui'),
         (select count(*)::int from journal_entries x where x.employee_id = p.id and x.tanggal between p_mulai and v_akhir and x.status = 'menunggu'),
         (select count(*)::int from journal_entries x where x.employee_id = p.id and x.tanggal between p_mulai and v_akhir and x.status = 'dikembalikan')
    from peg p left join isi i on i.emp = p.id left join org_units u on u.id = p.org_unit_id
   group by p.id, p.nama_lengkap, p.niy, u.nama, p.org_unit_id
   order by u.nama nulls last, p.nama_lengkap;
end $$;

/** Jurnal lengkap satu pegawai per hari (laporan individu). */
create or replace function public.jurnal_pegawai(p_emp uuid, p_mulai date, p_akhir date)
returns table (tanggal date, wajib boolean, terkunci boolean, butir jsonb, kegiatan jsonb)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.boleh_lihat_jurnal(p_emp) then raise exception 'Anda tidak berhak melihat jurnal pegawai ini.' using errcode = '42501'; end if;
  if p_akhir - p_mulai > 92 then raise exception 'Rentang laporan paling panjang 3 bulan.'; end if;
  return query
  select d::date, public.wajib_jurnal(p_emp, d::date), d::date < public.hari_ini() - 1,
         (select coalesce(jsonb_agg(jsonb_build_object('uraian', c.uraian, 'catatan', c.catatan) order by c.waktu), '[]')
            from journal_checks c where c.employee_id = p_emp and c.tanggal = d::date),
         (select coalesce(jsonb_agg(jsonb_build_object('jam_mulai', x.jam_mulai, 'jam_selesai', x.jam_selesai, 'uraian', x.uraian,
                   'status', x.status, 'foto_id', x.foto_id, 'catatan_verval', x.catatan_verval) order by x.jam_mulai), '[]')
            from journal_entries x where x.employee_id = p_emp and x.tanggal = d::date)
    from generate_series(p_mulai, least(p_akhir, public.hari_ini()), interval '1 day') d
   order by 1;
end $$;

/** Hak lihat foto kegiatan jurnal (dipakai Edge Function "berkas" melalui boleh_lihat_berkas). */
create or replace function public.boleh_lihat_berkas(p_obj uuid, p_emp uuid)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare r leave_requests; v_peran text; j journal_entries;
begin
  select peran into v_peran from employees where id = p_emp;
  for r in select * from leave_requests where lampiran_id = p_obj loop
    if r.employee_id = p_emp or v_peran = 'superadmin'
       or (v_peran = 'admin' and exists (select 1 from admin_permissions where employee_id = p_emp and kode = 'lihat_pengajuan'))
       or exists (select 1 from leave_approvals a where a.request_id = r.id and a.oleh = p_emp)
       or exists (select 1 from leave_approvals a, public.calon_penyetuju(r.employee_id, a.peran) c
                   where a.request_id = r.id and a.status = 'menunggu' and c.employee_id = p_emp) then
      return true;
    end if;
  end loop;
  -- Foto jurnal: pemilik, admin ber-izin verval_jurnal, dan pimpinan unit pegawai
  for j in select * from journal_entries where foto_id = p_obj loop
    if j.employee_id = p_emp or v_peran = 'superadmin'
       or (v_peran = 'admin' and exists (select 1 from admin_permissions where employee_id = p_emp and kode = 'verval_jurnal'))
       or exists (select 1 from employees t, employee_structurals es join structural_positions sp on sp.id = es.structural_position_id
                   where t.id = j.employee_id and es.employee_id = p_emp
                     and (sp.tingkat <= 20 or t.org_unit_id in (select public.unit_turunan(es.org_unit_id)))) then
      return true;
    end if;
  end loop;
  return false;
end $$;

-- ---------------------------------------------------------------------
-- 7. Hak eksekusi
-- ---------------------------------------------------------------------
do $$
declare f text;
begin
  execute 'revoke execute on function public.boleh_lihat_berkas(uuid,uuid) from public, anon, authenticated';
  execute 'grant execute on function public.boleh_lihat_berkas(uuid,uuid) to service_role';
  foreach f in array array['boleh_lihat_jurnal(uuid)','butir_jurnal(uuid)','wajib_jurnal(uuid,date)','_jurnal_terbuka(date)','jurnal_saya(date)',
    'centang_jurnal(date,uuid,boolean,text)','simpan_kegiatan_jurnal(jsonb)','hapus_kegiatan_jurnal(uuid)','antrian_verval_jurnal(text)',
    'verval_jurnal(uuid[],boolean,text)','rekap_jurnal(date,date)','jurnal_pegawai(uuid,date,date)']
  loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
grant select, insert, update, delete on public.journal_items to authenticated;
grant select on public.journal_checks, public.journal_entries to authenticated;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 5 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select 'Tabel jurnal (3)' as pemeriksaan,
       case when count(*) = 3 then 'Sesuai' else 'Periksa: ' || count(*) end as hasil
  from pg_tables where schemaname = 'public' and tablename in ('journal_items','journal_checks','journal_entries')
union all
select 'RLS aktif di tabel jurnal',
       case when bool_and(rowsecurity) then 'Sesuai' else 'Periksa' end
  from pg_tables where schemaname = 'public' and tablename in ('journal_items','journal_checks','journal_entries')
union all
select 'Contoh butir ceklist (minimal 30)',
       case when count(*) >= 30 then 'Sesuai' else 'Periksa: ' || count(*) end from public.journal_items
union all
select 'Fungsi jurnal inti (6)',
       case when count(*) = 6 then 'Sesuai' else 'Periksa: ' || count(*) end
  from pg_proc where pronamespace = 'public'::regnamespace
   and proname in ('jurnal_saya','centang_jurnal','simpan_kegiatan_jurnal','verval_jurnal','rekap_jurnal','jurnal_pegawai')
union all
select 'Migrasi 2000 sudah terpasang',
       case when exists (select 1 from pg_proc where proname = 'ajukan_pengajuan') then 'Sesuai' else 'Periksa: jalankan 2000 dulu' end;
