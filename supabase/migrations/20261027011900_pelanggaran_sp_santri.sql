-- SIMKA PRO | supabase/migrations/20261027011900_pelanggaran_sp_santri.sql | v1.0 | 14.6.0: catatan pelanggaran santri (tanpa poin) dan Surat Peringatan santri SP1–SP3 dengan sanksi | 18/10/2026
-- =====================================================================
-- SIMKA PRO · Migrasi 119: Kedisiplinan Santri
--   A. CATATAN PELANGGARAN (tanpa poin): tanggal, jam, kategori (ringan/sedang/berat dari ketentuan), tempat, uraian,
--      tindakan/pembinaan langsung, saksi, bukti (Google Drive). Dicatat pengasuh santri (wali kelas, musyrif, muhaffizh,
--      pembina ekskul), petugas Security, pemegang fitur "Kedisiplinan santri" tingkat Input/ubah, dan Bidang Kesantrian.
--      Pengasuh santri diberi tahu; pelanggaran berat dan pelanggaran yang mencapai AMBANG (jumlah pelanggaran yang belum
--      ditindaklanjuti SP) diberitahukan ke Bidang Kesantrian untuk dipertimbangkan surat peringatan.
--   B. SURAT PERINGATAN SANTRI SP-1, SP-2, SP-3: Bidang Kesantrian MENGUSULKAN (memilih pelanggaran dan sanksi per tingkat)
--      → surat keluar dibuat otomatis dari template dan langsung masuk ke Tata Usaha (Diperiksa TU) → TU mengajukan tanda tangan
--      → Direktur menandatangani → surat terbit bernomor (kode IZ) → SP aktif selama masa berlakunya; pengasuh, pengusul, dan
--      Kesantrian diberi tahu. SP-3 = santri DIKEMBALIKAN KEPADA ORANG TUA: bila ketentuan "SP-3 mengubah status" menyala,
--      status santri otomatis menjadi Berhenti (alasan: dikeluarkan berdasarkan SP-3 nomor …) dan pengelola Keuangan diberi
--      tahu untuk memeriksa tunggakan.
--   C. Hak Akses: fitur baru "Kedisiplinan santri" (1 lihat semua catatan dan SP, 2 mencatat pelanggaran semua santri,
--      3 mengusulkan/mencabut SP dan mengatur ketentuan). Pimpinan Bidang Kesantrian (termasuk Plt) otomatis tingkat Kelola.
--      Izin admin baru "kelola_disiplin". Bawaan: Direktur, Wakil Direktur, Yayasan 1; Tata Usaha 1.
--      Kerahasiaan: catatan tidak tampil di Layar Pantauan dan Portal Wali.
-- Jalankan SETELAH migrasi 11800. Aman dijalankan ulang.
-- =====================================================================

drop table if exists pg_temp._sekali_ds;
create temp table _sekali_ds as
  select not exists (select 1 from public.features where kode = 'disiplin_santri') as pertama;

-- ---------------------------------------------------------------------
-- 1. TABEL
-- ---------------------------------------------------------------------
create table if not exists public.student_warnings (
  id               uuid primary key default gen_random_uuid(),
  student_id       uuid not null references public.students(id) on delete cascade,
  tingkat          smallint not null check (tingkat between 1 and 3),
  kategori         text[] not null default '{}',
  sanksi           text[] not null default '{}',
  uraian           text,
  diusulkan_oleh   uuid references public.employees(id) on delete set null,
  diusulkan_pada   timestamptz not null default now(),
  letter_id        uuid references public.outgoing_letters(id) on delete set null,
  status           text not null default 'diusulkan' check (status in ('diusulkan','terbit','batal','dicabut')),
  nomor            text,
  tanggal_surat    date,
  berlaku_mulai    date,
  berlaku_sampai   date,
  status_diubah    boolean not null default false,
  diserahkan_pada  date,
  diserahkan_ket   text,
  dicabut_oleh     uuid references public.employees(id) on delete set null,
  dicabut_pada     timestamptz,
  alasan           text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index if not exists sw_santri_idx on public.student_warnings (student_id, status);
create index if not exists sw_surat_idx on public.student_warnings (letter_id);
create index if not exists sw_tanggal_idx on public.student_warnings (diusulkan_pada desc);

create table if not exists public.student_violations (
  id           uuid primary key default gen_random_uuid(),
  student_id   uuid not null references public.students(id) on delete cascade,
  tanggal      date not null default public.hari_ini(),
  jam          time,
  kategori     text not null constraint sv_kategori_check check (length(trim(kategori)) >= 3),
  tingkat      text not null default 'ringan' constraint sv_tingkat_check check (tingkat in ('ringan','sedang','berat')),
  tempat       text,
  uraian       text not null constraint sv_uraian_check check (length(trim(uraian)) >= 5),
  tindakan     text,
  saksi        text,
  bukti_id     uuid references public.storage_objects(id) on delete set null,
  warning_id   uuid references public.student_warnings(id) on delete set null,
  dicatat_oleh uuid references public.employees(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists sv_santri_idx on public.student_violations (student_id, tanggal desc);
create index if not exists sv_tanggal_idx on public.student_violations (tanggal desc);
create index if not exists sv_sp_idx on public.student_violations (warning_id);

do $$ declare t text; begin
  foreach t in array array['student_warnings','student_violations'] loop
    execute format('drop trigger if exists aa_updated on public.%I', t);
    execute format('create trigger aa_updated before update on public.%I for each row execute function public.tg_updated_at()', t);
    execute format('drop trigger if exists zz_audit on public.%I', t);
    execute format('create trigger zz_audit after insert or update or delete on public.%I for each row execute function public.tg_audit()', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 2. HAK AKSES
-- ---------------------------------------------------------------------
insert into public.features (kode, nama, kelompok, urutan, menu, arti, keterangan, kunci, sensitif) values
  ('disiplin_santri', 'Kedisiplinan santri', 'Santri', 8, 'Kedisiplinan Santri (pelanggaran, Surat Peringatan SP1–SP3, rekap)',
   '{"1": "Melihat seluruh catatan pelanggaran, surat peringatan, dan rekapnya", "2": "Mencatat pelanggaran semua santri", "3": "Mengusulkan dan mencabut surat peringatan santri serta mengatur ketentuannya"}'::jsonb,
   'Pengasuh santri (wali kelas, musyrif, muhaffizh, pembina ekskul) dan petugas Security otomatis dapat mencatat. Pimpinan Bidang Kesantrian otomatis tingkat Kelola. Surat diproses Tata Usaha dan ditandatangani Direktur.',
   null, false)
on conflict (kode) do update set nama = excluded.nama, kelompok = excluded.kelompok, urutan = excluded.urutan, menu = excluded.menu,
  arti = excluded.arti, keterangan = excluded.keterangan, dipakai = true;

insert into public.admin_capabilities (kode, nama, urutan)
values ('kelola_disiplin', 'Mengelola kedisiplinan santri (pelanggaran, surat peringatan, ketentuan)', 20)
on conflict (kode) do update set nama = excluded.nama;
insert into public.capability_features (kode, feature_kode, tingkat_min) values ('kelola_disiplin', 'disiplin_santri', 3)
on conflict (kode, feature_kode) do update set tingkat_min = excluded.tingkat_min;

insert into public.feature_grants (feature_kode, sasaran, sasaran_id, tingkat, mode, catatan)
select 'disiplin_santri', 'struktural', sp.id, v.t, 'tambah', 'Bawaan 14.6.0'
from public.structural_positions sp join (values ('DIREKTUR', 1), ('WAKIL_DIREKTUR', 1), ('YAYASAN', 1), ('TATA_USAHA', 1)) v(kode, t) on v.kode = sp.kode
where (select pertama from _sekali_ds)
on conflict (feature_kode, sasaran, sasaran_id) do nothing;

/** Pimpinan Bidang Kesantrian (termasuk Plt yang berlaku hari ini). */
create or replace function public._kesantrian_saya()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.unit_pimpinan_saya() u join org_units o on o.id = u where o.kode = 'KESANTRIAN')
      or exists (select 1 from acting_assignments a join org_units o on o.id = a.org_unit_id
                  where a.employee_id = public.saya() and o.kode = 'KESANTRIAN' and public.hari_ini() between a.mulai and a.sampai)
$$;

/** Tingkat Kelola kedisiplinan: usul/cabut SP, ketentuan, ubah/hapus semua catatan. */
create or replace function public._kelola_disiplin()
returns boolean language sql stable security definer set search_path = public as $$
  select public.boleh_fitur('disiplin_santri', 3) or public.admin_boleh('kelola_disiplin') or public._kesantrian_saya()
$$;

/** Melihat SELURUH catatan (bukan hanya santri asuhan). */
create or replace function public._lihat_semua_disiplin()
returns boolean language sql stable security definer set search_path = public as $$
  select public.boleh_fitur('disiplin_santri') or public.admin_boleh('kelola_disiplin') or public._kesantrian_saya()
$$;

/** Mencatat pelanggaran semua santri: tingkat Input/ubah, petugas Security, Kesantrian. */
create or replace function public._catat_semua_disiplin()
returns boolean language sql stable security definer set search_path = public as $$
  select public.boleh_fitur('disiplin_santri', 2) or public.admin_boleh('kelola_disiplin') or public._kesantrian_saya() or public.boleh_fitur('gerbang', 2)
$$;

/** Pengasuh santri yang berlaku (wali kelas, musyrif, muhaffizh, pembina ekskul). */
create or replace function public._pengasuh_disiplin(p_santri uuid)
returns setof uuid language sql stable security definer set search_path = public as $$
  select distinct k.employee_id from group_members m
    join student_groups g on g.id = m.group_id and g.aktif and g.jenis in ('kamar','kelas','halaqah','ekskul')
    join academic_years a on a.id = g.academic_year_id and a.aktif
    join group_keepers k on k.group_id = g.id and (k.mulai is null or k.mulai <= public.hari_ini()) and (k.sampai is null or k.sampai >= public.hari_ini())
   where m.student_id = p_santri and m.selesai is null
$$;

create or replace function public.boleh_catat_pelanggaran(p_santri uuid default null)
returns boolean language sql stable security definer set search_path = public as $$
  select public._catat_semua_disiplin()
      or (p_santri is null and exists (select 1 from group_keepers k join student_groups g on g.id = k.group_id and g.aktif
                                        where k.employee_id = public.saya() and g.jenis in ('kamar','kelas','halaqah','ekskul')
                                          and (k.sampai is null or k.sampai >= public.hari_ini())))
      or (p_santri is not null and public.saya() in (select public._pengasuh_disiplin(p_santri)))
$$;

/** Boleh melihat catatan kedisiplinan seorang santri: pemegang fitur, Kesantrian, pengasuhnya, pimpinan jenjangnya, Tata Usaha. */
create or replace function public.boleh_lihat_disiplin(p_santri uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public._lihat_semua_disiplin() or public._catat_semua_disiplin() or public.boleh_kelola_persuratan()
      or public.saya() in (select public._pengasuh_disiplin(p_santri))
      or (exists (select 1 from public.unit_pimpinan_saya()) and p_santri in (select public.santri_terlihat()))
$$;

create or replace function public.hak_disiplin()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'lihat_semua', public._lihat_semua_disiplin(),
    'catat', public.boleh_catat_pelanggaran(null),
    'catat_semua', public._catat_semua_disiplin(),
    'usul', public._kelola_disiplin(),
    'kelola', public._kelola_disiplin(),
    'tu', public.boleh_kelola_persuratan(),
    'kesantrian', public._kesantrian_saya(),
    'pimpinan', exists (select 1 from public.unit_pimpinan_saya()),
    'tampil', public._lihat_semua_disiplin() or public.boleh_catat_pelanggaran(null) or public.boleh_kelola_persuratan()
              or exists (select 1 from public.unit_pimpinan_saya()))
$$;

alter table public.student_violations enable row level security;
alter table public.student_warnings enable row level security;
drop policy if exists baca on public.student_violations;
create policy baca on public.student_violations for select to authenticated using (dicatat_oleh = public.saya() or public.boleh_lihat_disiplin(student_id));
drop policy if exists baca on public.student_warnings;
create policy baca on public.student_warnings for select to authenticated using (diusulkan_oleh = public.saya() or public.boleh_lihat_disiplin(student_id));
revoke all on public.student_violations, public.student_warnings from anon;
grant select on public.student_violations, public.student_warnings to authenticated;

-- ---------------------------------------------------------------------
-- 3. KETENTUAN
-- ---------------------------------------------------------------------
create or replace function public._disiplin_set()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'kategori', jsonb_build_array(
      jsonb_build_object('nama', 'Terlambat mengikuti kegiatan pondok', 'tingkat', 'ringan'),
      jsonb_build_object('nama', 'Berpakaian tidak sesuai ketentuan', 'tingkat', 'ringan'),
      jsonb_build_object('nama', 'Tidak menjaga kebersihan kamar atau lingkungan', 'tingkat', 'ringan'),
      jsonb_build_object('nama', 'Membuat gaduh pada jam belajar atau istirahat', 'tingkat', 'ringan'),
      jsonb_build_object('nama', 'Tidak mengikuti kegiatan tanpa izin', 'tingkat', 'sedang'),
      jsonb_build_object('nama', 'Keluar lingkungan pondok tanpa izin', 'tingkat', 'sedang'),
      jsonb_build_object('nama', 'Membawa atau menggunakan telepon genggam/barang elektronik tanpa izin', 'tingkat', 'sedang'),
      jsonb_build_object('nama', 'Berkata kasar atau tidak beradab', 'tingkat', 'sedang'),
      jsonb_build_object('nama', 'Merusak fasilitas pondok', 'tingkat', 'sedang'),
      jsonb_build_object('nama', 'Terlambat kembali dari izin atau libur', 'tingkat', 'sedang'),
      jsonb_build_object('nama', 'Berkelahi atau melakukan kekerasan', 'tingkat', 'berat'),
      jsonb_build_object('nama', 'Perundungan (bullying)', 'tingkat', 'berat'),
      jsonb_build_object('nama', 'Mencuri', 'tingkat', 'berat'),
      jsonb_build_object('nama', 'Merokok', 'tingkat', 'berat'),
      jsonb_build_object('nama', 'Berhubungan dengan lawan jenis yang bukan mahram', 'tingkat', 'berat'),
      jsonb_build_object('nama', 'Melawan atau tidak menghormati ustadz/ustadzah', 'tingkat', 'berat'),
      jsonb_build_object('nama', 'Meninggalkan pondok tanpa izin (kabur)', 'tingkat', 'berat'),
      jsonb_build_object('nama', 'Lainnya', 'tingkat', 'ringan')),
    'sanksi', jsonb_build_object(
      '1', jsonb_build_array('Pembinaan dan nasihat oleh wali kelas dan musyrif', 'Membuat surat pernyataan tidak mengulangi pelanggaran', 'Tugas kebersihan atau tambahan hafalan selama satu pekan'),
      '2', jsonb_build_array('Pemanggilan orang tua/wali santri ke pondok', 'Pencabutan hak izin keluar pondok selama satu bulan', 'Pembinaan khusus oleh Bidang Kesantrian'),
      '3', jsonb_build_array('Santri dikembalikan kepada orang tua/wali (dikeluarkan dari pondok)')),
    'masa_bulan', jsonb_build_object('1', 3, '2', 6, '3', 6),
    'penanda', jsonb_build_object('1', null, '2', null, '3', null),
    'harapan', 'memperbaiki akhlak dan kedisiplinannya serta menaati tata tertib pondok',
    'tembusan', jsonb_build_array('Ketua Yayasan', 'Kepala Bidang Kesantrian', 'Wali kelas santri', 'Arsip'),
    'ambang', jsonb_build_object('ringan', 5, 'sedang', 3, 'berat', 1),
    'jendela_hari', 180,
    'beri_tahu_pengasuh', true,
    'sp3_keluar', true)
  || coalesce((select nilai from institution_settings where kunci = 'disiplin_santri'), '{}'::jsonb)
$$;

create or replace function public.pengaturan_disiplin()
returns jsonb language sql stable security definer set search_path = public as $$
  select public._disiplin_set() || jsonb_build_object('boleh_ubah', public._kelola_disiplin())
$$;

create or replace function public.simpan_pengaturan_disiplin(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v jsonb := '{}'::jsonb; k text; n int; v_kat jsonb; v_sanksi jsonb := '{}'::jsonb; arr jsonb;
begin
  if not public._kelola_disiplin() then
    raise exception 'Hanya Bidang Kesantrian atau pemegang Kedisiplinan santri tingkat Kelola yang dapat mengubah ketentuan.' using errcode = '42501'; end if;
  -- kategori: [{nama, tingkat}]
  select coalesce(jsonb_agg(jsonb_build_object('nama', trim(x->>'nama'), 'tingkat', case when x->>'tingkat' in ('ringan','sedang','berat') then x->>'tingkat' else 'ringan' end)), '[]')
    into v_kat from jsonb_array_elements(case when jsonb_typeof(p->'kategori') = 'array' then p->'kategori' else '[]' end) x
   where length(trim(coalesce(x->>'nama', ''))) >= 3;
  if jsonb_array_length(v_kat) = 0 then raise exception 'Isi sedikitnya satu kategori pelanggaran (minimal 3 huruf).'; end if;
  if jsonb_array_length(v_kat) > 60 then raise exception 'Kategori pelanggaran paling banyak 60.'; end if;
  foreach k in array array['1','2','3'] loop
    n := coalesce((p->'masa_bulan'->>k)::int, 6);
    if n not between 1 and 24 then raise exception 'Masa berlaku SP-% harus 1 sampai 24 bulan.', k; end if;
    v := jsonb_set(v, '{masa_bulan}', coalesce(v->'masa_bulan', '{}'::jsonb) || jsonb_build_object(k, n));
    if nullif(p->'penanda'->>k, '') is not null and not exists (select 1 from signatories where id = (p->'penanda'->>k)::uuid and aktif) then
      raise exception 'Penanda tangan SP-% tidak dikenal.', k; end if;
    v := jsonb_set(v, '{penanda}', coalesce(v->'penanda', '{}'::jsonb) || jsonb_build_object(k, nullif(p->'penanda'->>k, '')));
    select coalesce(jsonb_agg(trim(x)), '[]') into arr from jsonb_array_elements_text(coalesce(p->'sanksi'->k, '[]')) x where trim(x) <> '';
    if jsonb_array_length(arr) = 0 then raise exception 'Isi sedikitnya satu sanksi untuk SP-%.', k; end if;
    v_sanksi := v_sanksi || jsonb_build_object(k, arr);
  end loop;
  foreach k in array array['ringan','sedang','berat'] loop
    n := coalesce((p->'ambang'->>k)::int, 0);
    if n not between 0 and 50 then raise exception 'Ambang pelanggaran % harus 0 sampai 50 (0 = tidak dipakai).', k; end if;
    v := jsonb_set(v, '{ambang}', coalesce(v->'ambang', '{}'::jsonb) || jsonb_build_object(k, n));
  end loop;
  n := coalesce((p->>'jendela_hari')::int, 180);
  if n not between 30 and 365 then raise exception 'Rentang penghitungan ambang harus 30 sampai 365 hari.'; end if;
  v := v || jsonb_build_object('kategori', v_kat, 'sanksi', v_sanksi, 'jendela_hari', n,
    'harapan', coalesce(nullif(trim(p->>'harapan'), ''), (public._disiplin_set()->>'harapan')),
    'tembusan', (select coalesce(jsonb_agg(trim(x)), '[]') from jsonb_array_elements_text(coalesce(p->'tembusan', '[]')) x where trim(x) <> ''),
    'beri_tahu_pengasuh', coalesce((p->>'beri_tahu_pengasuh')::boolean, true),
    'sp3_keluar', coalesce((p->>'sp3_keluar')::boolean, true));
  insert into institution_settings (kunci, nilai, publik, updated_by) values ('disiplin_santri', v, false, public.saya())
  on conflict (kunci) do update set nilai = excluded.nilai, updated_at = now(), updated_by = excluded.updated_by;
  return public.pengaturan_disiplin();
end $$;

-- ---------------------------------------------------------------------
-- 4. CATATAN PELANGGARAN
-- ---------------------------------------------------------------------
/** Penerima pemberitahuan Bidang Kesantrian: pimpinan unit KESANTRIAN (dan Plt), admin ber-izin kelola_disiplin. */
create or replace function public._penerima_kesantrian()
returns setof uuid language sql stable security definer set search_path = public as $$
  select distinct x from (
    select e.id x from employees e join org_units o on o.kode = 'KESANTRIAN'
     where e.status_akun = 'aktif' and e.status_keaktifan = 'aktif'
       and (exists (select 1 from employee_structurals es join structural_positions sp on sp.id = es.structural_position_id
                     where es.employee_id = e.id and e.org_unit_id = o.id and sp.kode in ('KEPALA_BIDANG','WAKIL_KEPALA_BIDANG'))
            or exists (select 1 from acting_assignments a where a.employee_id = e.id and a.org_unit_id = o.id and public.hari_ini() between a.mulai and a.sampai))
    union select ap.employee_id from admin_permissions ap join employees ee on ee.id = ap.employee_id
     where ap.kode = 'kelola_disiplin' and ee.peran = 'admin' and ee.status_akun = 'aktif') q
$$;

/** Jumlah pelanggaran yang belum ditindaklanjuti SP (dalam jendela hari ketentuan) per tingkat. */
create or replace function public._pelanggaran_terbuka(p_santri uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'ringan', count(*) filter (where tingkat = 'ringan'), 'sedang', count(*) filter (where tingkat = 'sedang'),
    'berat', count(*) filter (where tingkat = 'berat'), 'jumlah', count(*))
    from student_violations v
   where v.student_id = p_santri and v.warning_id is null
     and v.tanggal >= public.hari_ini() - coalesce((public._disiplin_set()->>'jendela_hari')::int, 180)
$$;

/** Ambang tercapai? (salah satu tingkat ≥ ambangnya; ambang 0 = tidak dipakai) */
create or replace function public._ambang_disiplin(p_santri uuid)
returns text language sql stable security definer set search_path = public as $$
  select case
    when (a->>'berat')::int > 0 and (t->>'berat')::int >= (a->>'berat')::int then 'berat'
    when (a->>'sedang')::int > 0 and (t->>'sedang')::int >= (a->>'sedang')::int then 'sedang'
    when (a->>'ringan')::int > 0 and (t->>'ringan')::int >= (a->>'ringan')::int then 'ringan' end
  from (select public._disiplin_set()->'ambang' a, public._pelanggaran_terbuka(p_santri) t) q
$$;

/** Simpan pelanggaran. p: { id?, student_id, tanggal, jam?, kategori, tingkat?, tempat?, uraian, tindakan?, saksi?, bukti_id? } */
create or replace function public.simpan_pelanggaran(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid := nullif(p->>'id', '')::uuid; v_santri uuid := nullif(p->>'student_id', '')::uuid; v_lama student_violations;
  v_saya uuid := public.saya(); v_set jsonb := public._disiplin_set(); v_kat text := trim(coalesce(p->>'kategori', '')); v_tingkat text;
  v_tgl date := coalesce(nullif(p->>'tanggal', '')::date, public.hari_ini()); v_nama text; v_kelas text; e uuid; v_ambang_lama text; v_ambang text;
  v_pencatat text;
begin
  if v_id is not null then
    select * into v_lama from student_violations where id = v_id;
    if v_lama.id is null then raise exception 'Catatan pelanggaran tidak ditemukan.'; end if;
    v_santri := v_lama.student_id;
    if not (v_lama.dicatat_oleh = v_saya or public._kelola_disiplin()) then
      raise exception 'Catatan hanya dapat diubah oleh pencatatnya atau Bidang Kesantrian.' using errcode = '42501'; end if;
    if v_lama.warning_id is not null and not public._kelola_disiplin() then
      raise exception 'Catatan ini sudah menjadi dasar surat peringatan dan hanya dapat diubah Bidang Kesantrian.'; end if;
  elsif v_santri is null then raise exception 'Pilih santri.';
  end if;
  if not public.boleh_catat_pelanggaran(v_santri) then raise exception 'Anda tidak berwenang mencatat pelanggaran santri ini.' using errcode = '42501'; end if;
  if not exists (select 1 from students where id = v_santri and status = 'aktif') and v_id is null then raise exception 'Santri tidak ditemukan atau tidak aktif.'; end if;
  if length(v_kat) < 3 then raise exception 'Pilih kategori pelanggaran.'; end if;
  if length(trim(coalesce(p->>'uraian', ''))) < 5 then raise exception 'Uraikan pelanggaran (minimal 5 huruf).'; end if;
  if v_tgl > public.hari_ini() then raise exception 'Tanggal pelanggaran belum terjadi.'; end if;
  if v_tgl < public.hari_ini() - 60 and not public._kelola_disiplin() then raise exception 'Pelanggaran lebih dari 60 hari lalu hanya dapat dicatat Bidang Kesantrian.'; end if;
  -- tingkat mengikuti kategori di ketentuan; kategori di luar daftar memakai tingkat yang dipilih (bawaan ringan)
  select x->>'tingkat' into v_tingkat from jsonb_array_elements(v_set->'kategori') x where lower(x->>'nama') = lower(v_kat) limit 1;
  v_tingkat := coalesce(case when p->>'tingkat' in ('ringan','sedang','berat') and (v_tingkat is null or lower(v_kat) = 'lainnya') then p->>'tingkat' end, v_tingkat, 'ringan');
  v_ambang_lama := public._ambang_disiplin(v_santri);

  if v_id is null then
    insert into student_violations (student_id, tanggal, jam, kategori, tingkat, tempat, uraian, tindakan, saksi, bukti_id, dicatat_oleh)
    values (v_santri, v_tgl, nullif(p->>'jam', '')::time, v_kat, v_tingkat, nullif(trim(coalesce(p->>'tempat', '')), ''), trim(p->>'uraian'),
            nullif(trim(coalesce(p->>'tindakan', '')), ''), nullif(trim(coalesce(p->>'saksi', '')), ''), nullif(p->>'bukti_id', '')::uuid, v_saya)
    returning id into v_id;
    select nama_lengkap, public._kelompok_santri(id, 'kelas') into v_nama, v_kelas from students where id = v_santri;
    select nama_lengkap into v_pencatat from employees where id = v_saya;
    if coalesce((v_set->>'beri_tahu_pengasuh')::boolean, true) then
      for e in select x from public._pengasuh_disiplin(v_santri) x where x is distinct from v_saya loop
        perform public.kirim_notifikasi(e, 'Pelanggaran santri: ' || v_nama,
          initcap(v_tingkat) || ' · ' || v_kat || coalesce(' · ' || to_char(v_tgl, 'DD/MM/YYYY'), '') || coalesce(' · dicatat ' || v_pencatat, ''),
          '/disiplin-santri/pelanggaran?santri=' || v_santri, 'Gavel', case v_tingkat when 'berat' then 'merah' when 'sedang' then 'jingga' else 'emas' end);
      end loop;
    end if;
    v_ambang := public._ambang_disiplin(v_santri);
    if v_tingkat = 'berat' or (v_ambang is not null and v_ambang_lama is null) then
      for e in select x from public._penerima_kesantrian() x where x is distinct from v_saya loop
        perform public.kirim_notifikasi(e,
          case when v_ambang is not null and v_ambang_lama is null then 'Pertimbangkan surat peringatan: ' || v_nama else 'Pelanggaran berat: ' || v_nama end,
          coalesce(v_kelas || ' · ', '') || v_kat || case when v_ambang is not null and v_ambang_lama is null
            then ' · jumlah pelanggaran ' || v_ambang || ' yang belum ditindaklanjuti telah mencapai ambang ketentuan.' else '' end,
          '/disiplin-santri/pelanggaran?santri=' || v_santri, 'WarningOctagon', 'merah');
      end loop;
    end if;
  else
    update student_violations set tanggal = v_tgl, jam = nullif(p->>'jam', '')::time, kategori = v_kat, tingkat = v_tingkat,
      tempat = nullif(trim(coalesce(p->>'tempat', '')), ''), uraian = trim(p->>'uraian'), tindakan = nullif(trim(coalesce(p->>'tindakan', '')), ''),
      saksi = nullif(trim(coalesce(p->>'saksi', '')), ''), bukti_id = case when p ? 'bukti_id' then nullif(p->>'bukti_id', '')::uuid else bukti_id end
     where id = v_id;
  end if;
  return v_id;
end $$;

create or replace function public.hapus_pelanggaran(p_id uuid, p_alasan text default null)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v student_violations;
begin
  select * into v from student_violations where id = p_id;
  if v.id is null then raise exception 'Catatan pelanggaran tidak ditemukan.'; end if;
  if not (v.dicatat_oleh = public.saya() or public._kelola_disiplin()) then
    raise exception 'Catatan hanya dapat dihapus oleh pencatatnya atau Bidang Kesantrian.' using errcode = '42501'; end if;
  if v.warning_id is not null and exists (select 1 from student_warnings w where w.id = v.warning_id and w.status in ('diusulkan','terbit')) then
    raise exception 'Catatan ini menjadi dasar surat peringatan yang masih berlaku dan tidak dapat dihapus.'; end if;
  delete from student_violations where id = p_id;
  perform public.catat_audit('hapus_pelanggaran', 'student_violations', p_id::text, v.kategori || ' · ' || to_char(v.tanggal, 'DD/MM/YYYY'), nullif(trim(coalesce(p_alasan, '')), ''));
end $$;

create or replace function public._pelanggaran_json(v student_violations)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', v.id, 'student_id', v.student_id, 'nama', s.nama_lengkap, 'nis', s.nis, 'jenis_kelamin', s.jenis_kelamin, 'jenjang', s.jenjang,
    'kelas', public._kelompok_santri(s.id, 'kelas'), 'kamar', public._kelompok_santri(s.id, 'kamar'),
    'tanggal', v.tanggal, 'jam', to_char(v.jam, 'HH24:MI'), 'kategori', v.kategori, 'tingkat', v.tingkat, 'tempat', v.tempat, 'uraian', v.uraian,
    'tindakan', v.tindakan, 'saksi', v.saksi, 'bukti_id', v.bukti_id, 'warning_id', v.warning_id,
    'sp_tingkat', (select w.tingkat from student_warnings w where w.id = v.warning_id and w.status in ('diusulkan','terbit')),
    'dicatat_oleh', v.dicatat_oleh, 'pencatat', e.nama_lengkap, 'dicatat_pada', v.created_at,
    'boleh_ubah', (v.dicatat_oleh = public.saya() and v.warning_id is null) or public._kelola_disiplin())
  from students s left join employees e on e.id = v.dicatat_oleh where s.id = v.student_id
$$;

/** Daftar pelanggaran yang boleh dilihat (rentang tanggal; p_santri untuk satu santri). Selain pemegang hak luas,
    pengguna melihat santri asuhannya, santri jenjang yang dipimpinnya, dan catatan yang dibuatnya. */
create or replace function public.daftar_pelanggaran(p_mulai date default null, p_selesai date default null, p_santri uuid default null)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(public._pelanggaran_json(v) order by v.tanggal desc, v.jam desc nulls last, v.created_at desc), '[]'::jsonb)
    from student_violations v
   where (p_santri is null or v.student_id = p_santri)
     and (p_mulai is null or v.tanggal >= p_mulai) and (p_selesai is null or v.tanggal <= p_selesai)
     and (v.dicatat_oleh = public.saya() or public.boleh_lihat_disiplin(v.student_id))
$$;

/** Santri yang dapat dicatat pelanggarannya (pencarian), beserta SP aktif dan jumlah pelanggaran terbuka. */
create or replace function public.cari_santri_disiplin(p_cari text default '')
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(x order by x->>'nama'), '[]'::jsonb) from (
    select jsonb_build_object('id', s.id, 'nama', s.nama_lengkap, 'nis', s.nis, 'jenis_kelamin', s.jenis_kelamin, 'jenjang', s.jenjang,
      'kelas', public._kelompok_santri(s.id, 'kelas'), 'kamar', public._kelompok_santri(s.id, 'kamar'),
      'sp_aktif', (select max(w.tingkat) from student_warnings w where w.student_id = s.id and w.status = 'terbit' and w.berlaku_sampai >= public.hari_ini()),
      'terbuka', public._pelanggaran_terbuka(s.id)) x
      from students s
     where s.status = 'aktif'
       and (length(trim(coalesce(p_cari, ''))) < 2 or s.nama_lengkap ilike '%' || trim(p_cari) || '%' or s.nis like trim(p_cari) || '%')
       and (public._catat_semua_disiplin() or public.saya() in (select public._pengasuh_disiplin(s.id)))
       and (length(trim(coalesce(p_cari, ''))) >= 2 or public.saya() in (select public._pengasuh_disiplin(s.id)))
     limit 40) q
$$;

-- ---------------------------------------------------------------------
-- 5. TEMPLATE SURAT PERINGATAN SANTRI (dapat disunting Tata Usaha di Persuratan → Template)
-- ---------------------------------------------------------------------
insert into public.letter_templates (kode, nama, kategori, perihal_kode, format_nomor, dk, kop_kode, bentuk, judul, subjudul, hal_bawaan, kepada_bawaan,
                                     opsi, isi, isian, penanda, aktif, bawaan, urutan)
select v.kode, v.nama, 'santri', 'IZ', 'surat', 'D', 'pondok', 'tengah', v.judul, null, v.nama, 'Orang tua/wali santri',
       '{"salam": true, "salam_penutup": true, "tembusan": true, "penerima": true}'::jsonb, v.isi,
       ('[{"kunci":"santri","label":"Santri","jenis":"santri","wajib":true},'
        '{"kunci":"pelanggaran","label":"Pelanggaran","jenis":"daftar","gaya":"angka","wajib":true},'
        '{"kunci":"uraian","label":"Uraian","jenis":"panjang","wajib":false},'
        || case when v.tingkat > 1 then '{"kunci":"sp_sebelumnya","label":"Surat peringatan sebelumnya","jenis":"teks","wajib":true},' else '' end ||
        '{"kunci":"sanksi","label":"Sanksi","jenis":"daftar","gaya":"huruf","wajib":true},'
        || case when v.tingkat < 3 then '{"kunci":"harapan","label":"Harapan perbaikan","jenis":"panjang","wajib":true,"bawaan":"memperbaiki akhlak dan kedisiplinannya"},'
                                        '{"kunci":"masa_berlaku","label":"Masa berlaku","jenis":"teks","wajib":true,"bawaan":"3 (tiga) bulan"}'
                else '{"kunci":"harapan","label":"Harapan","jenis":"panjang","wajib":false}' end || ']')::jsonb,
       '[{"jabatan":"Direktur"}]'::jsonb, true, true, 30 + v.tingkat
from (values
 (1, 'sp_santri_1', 'Surat Peringatan Pertama (SP-1) Santri', 'SURAT PERINGATAN PERTAMA (SP-1)',
$t$Berdasarkan catatan kedisiplinan Bidang Kesantrian, dengan ini kami memberikan *Surat Peringatan Pertama (SP-1)* kepada santri:

Nama : {santri.nama}
NIS : {santri.nis}
Kelas : {santri.kelas}
Orang tua/wali : {santri.orang_tua}

Peringatan ini diberikan karena santri tersebut telah melanggar tata tertib pondok, yaitu:
{pelanggaran}

{uraian}

Atas pelanggaran tersebut, santri yang bersangkutan dikenai sanksi:
{sanksi}

Kami mengharapkan santri yang bersangkutan {harapan}, serta memohon kerja sama Bapak/Ibu orang tua/wali untuk turut membina putra/putrinya. Surat peringatan ini berlaku selama {masa_berlaku} sejak tanggal surat ini. Apabila dalam masa tersebut pelanggaran terulang, akan diberikan Surat Peringatan Kedua (SP-2) sesuai tata tertib {lembaga}.

Demikian surat peringatan ini disampaikan untuk diperhatikan.$t$),
 (2, 'sp_santri_2', 'Surat Peringatan Kedua (SP-2) Santri', 'SURAT PERINGATAN KEDUA (SP-2)',
$t$Dengan ini kami memberikan *Surat Peringatan Kedua (SP-2)* kepada santri:

Nama : {santri.nama}
NIS : {santri.nis}
Kelas : {santri.kelas}
Orang tua/wali : {santri.orang_tua}

Sebelumnya santri tersebut telah menerima {sp_sebelumnya}. Namun santri yang bersangkutan masih melanggar tata tertib pondok, yaitu:
{pelanggaran}

{uraian}

Atas pelanggaran tersebut, santri yang bersangkutan dikenai sanksi:
{sanksi}

Kami mengharapkan dengan sungguh-sungguh agar santri yang bersangkutan {harapan}, serta memohon perhatian dan kerja sama Bapak/Ibu orang tua/wali. Surat peringatan ini berlaku selama {masa_berlaku} sejak tanggal surat ini. Apabila dalam masa tersebut pelanggaran terulang, akan diberikan Surat Peringatan Ketiga (SP-3) berupa pengembalian santri kepada orang tua/wali sesuai tata tertib {lembaga}.

Demikian surat peringatan ini disampaikan untuk diperhatikan.$t$),
 (3, 'sp_santri_3', 'Surat Peringatan Ketiga (SP-3) Santri', 'SURAT PERINGATAN KETIGA (SP-3)',
$t$Dengan ini kami memberikan *Surat Peringatan Ketiga (SP-3)* kepada santri:

Nama : {santri.nama}
NIS : {santri.nis}
Kelas : {santri.kelas}
Orang tua/wali : {santri.orang_tua}

Sebelumnya santri tersebut telah menerima {sp_sebelumnya}. Namun santri yang bersangkutan masih melanggar tata tertib pondok, yaitu:
{pelanggaran}

{uraian}

Berdasarkan pertimbangan pimpinan dan tata tertib {lembaga}, santri yang bersangkutan dikenai sanksi:
{sanksi}

Keputusan ini berlaku sejak tanggal surat ini. Bapak/Ibu orang tua/wali diharapkan menjemput putra/putrinya serta menyelesaikan administrasi santri di Tata Usaha, termasuk kewajiban keuangan. {harapan}

Demikian surat peringatan ini disampaikan untuk diketahui dan dilaksanakan.$t$)
) v(tingkat, kode, nama, judul, isi)
on conflict (kode) do nothing;

-- ---------------------------------------------------------------------
-- 6. SURAT PERINGATAN SANTRI: bantuan, usul, batal, cabut, serah, pemicu
-- ---------------------------------------------------------------------
create or replace function public._sp_santri_aktif(p_santri uuid)
returns setof public.student_warnings language sql stable security definer set search_path = public as $$
  select * from student_warnings where student_id = p_santri and status = 'terbit' and berlaku_sampai >= public.hari_ini()
  order by tingkat desc, tanggal_surat desc
$$;

create or replace function public._nama_sp_santri(p int)
returns text language sql immutable set search_path = public as $$
  select 'Surat Peringatan ' || case p when 1 then 'Pertama (SP-1)' when 2 then 'Kedua (SP-2)' else 'Ketiga (SP-3)' end
$$;

create or replace function public._teks_sp_santri_sebelumnya(p_santri uuid, p_tingkat int)
returns text language sql stable security definer set search_path = public as $$
  select coalesce(
    (select public._nama_sp_santri(w.tingkat) || coalesce(' Nomor ' || w.nomor, '') || ' tanggal ' || public._tgl_panjang(w.tanggal_surat)
       from public._sp_santri_aktif(p_santri) w where w.tingkat < p_tingkat order by w.tingkat desc limit 1),
    'teguran dan pembinaan dari pengasuh dan Bidang Kesantrian')
$$;

/** Saran tingkat SP berikutnya, SP aktif, dan pelanggaran yang belum ditindaklanjuti. */
create or replace function public.saran_sp_santri(p_santri uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_maks int;
begin
  if not public.boleh_lihat_disiplin(p_santri) then raise exception 'Tidak berwenang.' using errcode = '42501'; end if;
  select max(tingkat) into v_maks from public._sp_santri_aktif(p_santri);
  return jsonb_build_object(
    'saran', least(coalesce(v_maks, 0) + 1, 3),
    'sp3', exists (select 1 from student_warnings where student_id = p_santri and tingkat = 3 and status = 'terbit'),
    'diusulkan', exists (select 1 from student_warnings where student_id = p_santri and status = 'diusulkan'),
    'aktif', coalesce((select jsonb_agg(jsonb_build_object('id', w.id, 'tingkat', w.tingkat, 'nomor', w.nomor, 'tanggal_surat', w.tanggal_surat,
                        'berlaku_sampai', w.berlaku_sampai) order by w.tingkat desc) from public._sp_santri_aktif(p_santri) w), '[]'::jsonb),
    'terbuka', public._pelanggaran_terbuka(p_santri),
    'ambang', public._ambang_disiplin(p_santri),
    'pelanggaran', coalesce((select jsonb_agg(public._pelanggaran_json(v) order by v.tanggal desc) from student_violations v
                              where v.student_id = p_santri and v.warning_id is null and v.tanggal >= public.hari_ini() - 365), '[]'::jsonb));
end $$;

create or replace function public._penanda_sp_santri(p_tingkat int)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_id uuid := nullif(public._disiplin_set()->'penanda'->>p_tingkat::text, '')::uuid; st signatories;
begin
  if v_id is not null then select * into st from signatories where id = v_id and aktif; end if;
  if st.id is null then
    select * into st from signatories where aktif and (sumber_jabatan = 'DIREKTUR' or jabatan_tertulis ilike 'direktur%')
     order by (sumber_jabatan = 'DIREKTUR') desc nulls last, urutan limit 1;
  end if;
  if st.id is null then raise exception 'Penanda tangan Direktur belum diatur. Atur di Setelan → Penanda tangan, atau di ketentuan Kedisiplinan Santri.'; end if;
  return public._penanda_sah(jsonb_build_array(jsonb_build_object('signatory_id', st.id, 'jabatan', st.jabatan_tertulis)));
end $$;

create or replace function public._santri_surat_json(p_santri uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', s.id, 'nama', s.nama_lengkap, 'nis', s.nis, 'nisn', s.nisn, 'jk', s.jenis_kelamin,
      'tempat_lahir', s.tempat_lahir, 'tanggal_lahir', s.tanggal_lahir, 'jenjang', s.jenjang, 'tingkat', s.tingkat, 'alamat', s.alamat,
      'status', s.status, 'tanggal_masuk', s.tanggal_masuk, 'kelas', public._kelompok_santri(s.id, 'kelas'),
      'wali', coalesce((select c.nama from student_contacts c where c.student_id = s.id and c.nama is not null
                         order by c.utama desc nulls last, case c.hubungan when 'ayah' then 1 when 'wali' then 2 else 3 end limit 1), ''),
      'ayah', (select c.nama from student_contacts c where c.student_id = s.id and c.hubungan = 'ayah' limit 1),
      'ibu', (select c.nama from student_contacts c where c.student_id = s.id and c.hubungan = 'ibu' limit 1))
    from students s where s.id = p_santri
$$;

/** p: { student_id, tingkat, pelanggaran_ids[], uraian?, sanksi[], harapan? } → id SP */
create or replace function public.usul_sp_santri(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_santri uuid := nullif(p->>'student_id', '')::uuid; v_t int := coalesce((p->>'tingkat')::int, 0); s record; t letter_templates;
        v_set jsonb := public._disiplin_set(); v_ids uuid[]; v_kat text[]; v_butir jsonb; v_sanksi text[]; v_masa int; v_pen jsonb; v_surat uuid; v_id uuid;
        v_saya text; v_nama_sp text; v_uraian text;
begin
  if not public._kelola_disiplin() then raise exception 'Surat peringatan santri diusulkan oleh Bidang Kesantrian.' using errcode = '42501'; end if;
  if v_santri is null then raise exception 'Pilih santri.'; end if;
  if v_t not between 1 and 3 then raise exception 'Pilih tingkat SP-1, SP-2, atau SP-3.'; end if;
  select id, nama_lengkap, status into s from students where id = v_santri;
  if s.id is null or s.status <> 'aktif' then raise exception 'Santri tidak ditemukan atau tidak aktif.'; end if;
  if exists (select 1 from student_warnings where student_id = v_santri and status = 'diusulkan') then
    raise exception 'Santri ini masih memiliki usulan surat peringatan yang sedang diproses Tata Usaha.'; end if;
  select coalesce(array_agg(x::uuid), '{}') into v_ids from jsonb_array_elements_text(coalesce(p->'pelanggaran_ids', '[]')) x where x <> '';
  if cardinality(v_ids) = 0 then raise exception 'Pilih sedikitnya satu catatan pelanggaran sebagai dasar surat peringatan.'; end if;
  if exists (select 1 from unnest(v_ids) i where not exists (select 1 from student_violations v where v.id = i and v.student_id = v_santri and v.warning_id is null)) then
    raise exception 'Ada catatan pelanggaran yang bukan milik santri ini atau sudah menjadi dasar surat peringatan lain.'; end if;
  select array_agg(distinct v.kategori), jsonb_agg(public._tgl_panjang(v.tanggal) || ': ' || v.kategori || ' – ' || v.uraian order by v.tanggal)
    into v_kat, v_butir from student_violations v where v.id = any(v_ids);
  select coalesce(array_agg(trim(x)) filter (where trim(x) <> ''), '{}') into v_sanksi from jsonb_array_elements_text(coalesce(p->'sanksi', '[]')) x;
  if cardinality(v_sanksi) = 0 then raise exception 'Pilih atau tuliskan sedikitnya satu sanksi.'; end if;
  select * into t from letter_templates where kode = 'sp_santri_' || v_t and aktif;
  if t.id is null then raise exception 'Template Surat Peringatan SP-% santri tidak aktif. Aktifkan di Persuratan → Template.', v_t; end if;
  v_masa := coalesce((v_set->'masa_bulan'->>v_t::text)::int, 6);
  v_pen := public._penanda_sp_santri(v_t);
  v_nama_sp := public._nama_sp_santri(v_t);
  v_uraian := nullif(trim(coalesce(p->>'uraian', '')), '');

  insert into outgoing_letters (template_id, jenis_nama, kategori, kop_kode, dk, perihal_kode, format_nomor, tanggal_surat, perihal, kepada, tembusan,
                                nilai, tampilan, penanda, status, disusun_oleh, pemohon_id, catatan)
  values (t.id, t.nama, t.kategori, t.kop_kode, t.dk, t.perihal_kode, t.format_nomor, public.hari_ini(), v_nama_sp || ' – ' || s.nama_lengkap,
          'Orang tua/wali ' || s.nama_lengkap,
          (select coalesce(array_agg(x), '{}') from jsonb_array_elements_text(v_set->'tembusan') x),
          jsonb_build_object(
            'santri', public._santri_surat_json(v_santri),
            'pelanggaran', v_butir,
            'uraian', coalesce(v_uraian, ''),
            'sp_sebelumnya', public._teks_sp_santri_sebelumnya(v_santri, v_t),
            'sanksi', to_jsonb(v_sanksi),
            'harapan', case when v_t < 3 then coalesce(nullif(trim(p->>'harapan'), ''), v_set->>'harapan') else coalesce(nullif(trim(p->>'harapan'), ''), '') end,
            'masa_berlaku', v_masa || ' (' || case v_masa when 1 then 'satu' when 2 then 'dua' when 3 then 'tiga' when 4 then 'empat' when 5 then 'lima'
                              when 6 then 'enam' when 7 then 'tujuh' when 8 then 'delapan' when 9 then 'sembilan' when 10 then 'sepuluh' when 11 then 'sebelas'
                              when 12 then 'dua belas' else v_masa::text end || ') bulan'),
          jsonb_build_object('bentuk', t.bentuk, 'judul', t.judul, 'subjudul', t.subjudul, 'isi', t.isi, 'opsi', t.opsi, 'isian', t.isian),
          v_pen, 'diperiksa', public.saya(), public.saya(), 'Usulan surat peringatan santri')
  returning id into v_surat;

  insert into student_warnings (student_id, tingkat, kategori, sanksi, uraian, diusulkan_oleh, letter_id)
  values (v_santri, v_t, v_kat, v_sanksi, v_uraian, public.saya(), v_surat) returning id into v_id;
  update student_violations set warning_id = v_id where id = any(v_ids);

  select nama_lengkap into v_saya from employees where id = public.saya();
  insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
  select x, 'Usulan surat peringatan santri perlu diproses', coalesce(v_saya, 'Bidang Kesantrian') || ' mengusulkan ' || v_nama_sp || ' untuk ' || s.nama_lengkap || '.',
         '/persuratan/keluar?surat=' || v_surat, 'WarningOctagon', 'jingga'
    from public._pengelola_surat() x where x <> public.saya();
  return v_id;
end $$;

/** Pengusul, Bidang Kesantrian, atau Tata Usaha membatalkan usulan yang belum terbit (surat ikut dibatalkan, catatan dilepas). */
create or replace function public.batal_sp_santri(p_id uuid, p_alasan text)
returns void language plpgsql volatile security definer set search_path = public as $$
declare w student_warnings; o outgoing_letters;
begin
  select * into w from student_warnings where id = p_id for update;
  if w.id is null then raise exception 'Surat peringatan tidak ditemukan.'; end if;
  if w.status <> 'diusulkan' then raise exception 'Hanya usulan yang belum terbit yang dapat dibatalkan.'; end if;
  if not (w.diusulkan_oleh = public.saya() or public.boleh_kelola_persuratan() or public._kelola_disiplin()) then
    raise exception 'Hanya pengusul, Bidang Kesantrian, atau Tata Usaha yang dapat membatalkan usulan ini.' using errcode = '42501'; end if;
  if length(trim(coalesce(p_alasan, ''))) < 5 then raise exception 'Tuliskan alasan pembatalan (minimal 5 huruf).'; end if;
  update student_warnings set status = 'batal', alasan = trim(p_alasan) where id = p_id;
  update student_violations set warning_id = null where warning_id = p_id;
  select * into o from outgoing_letters where id = w.letter_id for update;
  if o.id is not null and o.status in ('draf','diperiksa','ditolak','menunggu_ttd') then
    update outgoing_letters set status = 'dibatalkan', catatan = 'Usulan surat peringatan santri dibatalkan: ' || trim(p_alasan) where id = o.id;
    if o.document_id is not null then
      update document_registry set status = 'dicabut', dicabut_pada = now(), dicabut_oleh = public.saya(), alasan_cabut = trim(p_alasan)
       where id = o.document_id and status = 'draf';
      update notifications set dibaca_pada = coalesce(dibaca_pada, now()) where tautan = '/persuratan/keluar?resmi=' || o.document_id;
    end if;
  end if;
end $$;

/** Kesantrian mencabut SP yang sudah terbit (tidak lagi dihitung; status santri yang sudah diubah TIDAK dipulihkan otomatis). */
create or replace function public.cabut_sp_santri(p_id uuid, p_alasan text)
returns void language plpgsql volatile security definer set search_path = public as $$
declare w student_warnings; e uuid; v_nama text;
begin
  if not public._kelola_disiplin() then raise exception 'Hanya Bidang Kesantrian yang dapat mencabut surat peringatan santri.' using errcode = '42501'; end if;
  select * into w from student_warnings where id = p_id for update;
  if w.id is null then raise exception 'Surat peringatan tidak ditemukan.'; end if;
  if w.status <> 'terbit' then raise exception 'Hanya surat peringatan yang sudah terbit yang dapat dicabut.'; end if;
  if length(trim(coalesce(p_alasan, ''))) < 5 then raise exception 'Tuliskan alasan pencabutan (minimal 5 huruf).'; end if;
  update student_warnings set status = 'dicabut', dicabut_oleh = public.saya(), dicabut_pada = now(), alasan = trim(p_alasan) where id = p_id;
  select nama_lengkap into v_nama from students where id = w.student_id;
  for e in select x from public._pengasuh_disiplin(w.student_id) x where x is distinct from public.saya() loop
    perform public.kirim_notifikasi(e, 'Surat peringatan santri dicabut', 'SP-' || w.tingkat || ' ' || coalesce(v_nama, '') || coalesce(' (' || w.nomor || ')', '') || ': ' || left(trim(p_alasan), 120),
      '/disiplin-santri/sp?sp=' || w.id, 'ArrowCounterClockwise', 'hijau');
  end loop;
end $$;

/** Mencatat penyerahan surat kepada orang tua/wali (tanggal dan keterangan, mis. "diserahkan langsung saat pemanggilan"). */
create or replace function public.serah_sp_santri(p_id uuid, p_tanggal date, p_ket text)
returns void language plpgsql volatile security definer set search_path = public as $$
declare w student_warnings;
begin
  select * into w from student_warnings where id = p_id for update;
  if w.id is null then raise exception 'Surat peringatan tidak ditemukan.'; end if;
  if not (public._kelola_disiplin() or public.boleh_kelola_persuratan() or w.diusulkan_oleh = public.saya()
          or public.saya() in (select public._pengasuh_disiplin(w.student_id))) then
    raise exception 'Tidak berwenang mencatat penyerahan surat.' using errcode = '42501'; end if;
  if w.status not in ('terbit','dicabut') then raise exception 'Surat peringatan belum terbit.'; end if;
  if p_tanggal is null or p_tanggal > public.hari_ini() or p_tanggal < w.tanggal_surat then raise exception 'Tanggal penyerahan tidak sah.'; end if;
  update student_warnings set diserahkan_pada = p_tanggal, diserahkan_ket = nullif(trim(coalesce(p_ket, '')), '') where id = p_id;
end $$;

/** Pemicu surat keluar: SP santri mengikuti status suratnya. SP-3 terbit → status santri Berhenti (bila ketentuan menyala). */
create or replace function public.tg_sp_santri_surat()
returns trigger language plpgsql security definer set search_path = public as $$
declare w student_warnings; v_set jsonb; v_masa int; v_nama text; e uuid; v_ubah boolean;
begin
  if new.status is not distinct from old.status then return new; end if;
  if new.status = 'terbit' then
    v_set := public._disiplin_set();
    for w in select * from student_warnings where letter_id in (new.id, new.revisi_dari) and status in ('diusulkan','terbit') loop
      v_masa := coalesce((v_set->'masa_bulan'->>w.tingkat::text)::int, 6);
      v_ubah := false;
      if w.status = 'diusulkan' and w.tingkat = 3 and coalesce((v_set->>'sp3_keluar')::boolean, true)
         and exists (select 1 from students where id = w.student_id and status = 'aktif') then
        perform set_config('simka.alasan', 'Dikeluarkan (dikembalikan kepada orang tua) berdasarkan ' || public._nama_sp_santri(3) || ' Nomor ' || coalesce(new.nomor, '–'), true);
        update students set status = 'berhenti', status_sejak = new.tanggal_surat where id = w.student_id;
        perform set_config('simka.alasan', '', true);
        v_ubah := true;
      end if;
      update student_warnings set letter_id = new.id, status = 'terbit', nomor = new.nomor, tanggal_surat = new.tanggal_surat,
             berlaku_mulai = new.tanggal_surat, berlaku_sampai = (new.tanggal_surat + make_interval(months => v_masa))::date - 1,
             status_diubah = status_diubah or v_ubah
       where id = w.id;
      if w.status = 'diusulkan' then
        select nama_lengkap into v_nama from students where id = w.student_id;
        for e in select distinct x from (select public._pengasuh_disiplin(w.student_id) x union select w.diusulkan_oleh union select public._penerima_kesantrian()) q
                  where x is not null loop
          perform public.kirim_notifikasi(e, public._nama_sp_santri(w.tingkat) || ' terbit: ' || coalesce(v_nama, ''),
            'Nomor ' || coalesce(new.nomor, '–') || case when v_ubah then '. Status santri diubah menjadi Berhenti (dikembalikan kepada orang tua).' else '. Sampaikan kepada orang tua/wali santri.' end,
            '/disiplin-santri/sp?sp=' || w.id, 'SealCheck', case w.tingkat when 3 then 'merah' else 'jingga' end);
        end loop;
        if w.tingkat = 3 then
          for e in select x from public._pejabat_keuangan() x union select sa.employee_id from sensitive_access sa where sa.fitur = 'keuangan' and sa.tingkat = 'kelola' loop
            perform public.kirim_notifikasi(e, 'Santri dikeluarkan: periksa tunggakan', coalesce(v_nama, 'Santri') || ' dikembalikan kepada orang tua berdasarkan SP-3 Nomor '
              || coalesce(new.nomor, '–') || '. Periksa tagihan dan tunggakan sebelum administrasi keluar.', '/keuangan', 'CashRegister', 'jingga');
          end loop;
        end if;
      end if;
    end loop;
  elsif new.status = 'dibatalkan' then
    update student_violations set warning_id = null where warning_id in (select id from student_warnings where letter_id = new.id and status = 'diusulkan');
    update student_warnings set status = 'batal', alasan = coalesce(alasan, new.catatan) where letter_id = new.id and status = 'diusulkan';
  elsif new.status = 'dicabut' then
    update student_warnings set status = 'dicabut', dicabut_pada = now(), alasan = coalesce(new.catatan, 'Surat dicabut') where letter_id = new.id and status = 'terbit';
  end if;
  return new;
end $$;
drop trigger if exists zc_sp_santri on public.outgoing_letters;
create trigger zc_sp_santri after update of status on public.outgoing_letters for each row execute function public.tg_sp_santri_surat();

-- ---------------------------------------------------------------------
-- 7. BACA
-- ---------------------------------------------------------------------
create or replace function public._sp_santri_json(w student_warnings)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', w.id, 'student_id', w.student_id, 'nama', s.nama_lengkap, 'nis', s.nis, 'jenis_kelamin', s.jenis_kelamin, 'jenjang', s.jenjang,
    'status_santri', s.status, 'kelas', public._kelompok_santri(s.id, 'kelas'), 'kamar', public._kelompok_santri(s.id, 'kamar'),
    'tingkat', w.tingkat, 'kategori', to_jsonb(w.kategori), 'sanksi', to_jsonb(w.sanksi), 'uraian', w.uraian,
    'pelanggaran', coalesce((select jsonb_agg(jsonb_build_object('id', v.id, 'tanggal', v.tanggal, 'kategori', v.kategori, 'tingkat', v.tingkat, 'uraian', v.uraian) order by v.tanggal)
                              from student_violations v where v.warning_id = w.id), '[]'::jsonb),
    'diusulkan_oleh', w.diusulkan_oleh, 'pengusul', pe.nama_lengkap, 'diusulkan_pada', w.diusulkan_pada,
    'letter_id', w.letter_id, 'status_surat', o.status, 'status', w.status,
    'keadaan', case when w.status = 'terbit' and (w.tingkat = 3 or w.berlaku_sampai >= public.hari_ini()) then 'aktif' when w.status = 'terbit' then 'berakhir' else w.status end,
    'nomor', w.nomor, 'tanggal_surat', w.tanggal_surat, 'berlaku_mulai', w.berlaku_mulai, 'berlaku_sampai', w.berlaku_sampai, 'status_diubah', w.status_diubah,
    'diserahkan_pada', w.diserahkan_pada, 'diserahkan_ket', w.diserahkan_ket, 'dicabut_pada', w.dicabut_pada, 'alasan', w.alasan,
    'wali', (select c.nama from student_contacts c where c.student_id = s.id and c.nama is not null order by c.utama desc nulls last, case c.hubungan when 'ayah' then 1 when 'wali' then 2 else 3 end limit 1),
    'hp_wali', (select c.no_hp from student_contacts c where c.student_id = s.id and nullif(c.no_hp, '') is not null order by c.utama desc nulls last, case c.hubungan when 'ayah' then 1 when 'wali' then 2 else 3 end limit 1),
    'saya_pengusul', w.diusulkan_oleh = public.saya())
  from students s left join employees pe on pe.id = w.diusulkan_oleh left join outgoing_letters o on o.id = w.letter_id
  where s.id = w.student_id
$$;

create or replace function public.daftar_sp_santri(p_mulai date default null, p_selesai date default null, p_santri uuid default null)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(public._sp_santri_json(w) order by w.diusulkan_pada desc), '[]'::jsonb)
    from student_warnings w
   where (p_santri is null or w.student_id = p_santri)
     and (p_mulai is null or w.diusulkan_pada::date >= p_mulai) and (p_selesai is null or w.diusulkan_pada::date <= p_selesai)
     and (w.diusulkan_oleh = public.saya() or public.boleh_lihat_disiplin(w.student_id))
$$;

/** Surat keluar SP santri dapat dibaca siapa pun yang boleh melihat kedisiplinan santri tersebut. */
create or replace function public._baca_surat_sp_santri(p_letter uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from student_warnings w where w.letter_id = p_letter and (w.diusulkan_oleh = public.saya() or public.boleh_lihat_disiplin(w.student_id)))
$$;

-- ---------------------------------------------------------------------
-- 8. PENAMBALAN DI TEMPAT
-- ---------------------------------------------------------------------
create or replace function pg_temp.tambal(p_fn text, p_cari text, p_ganti text, p_tanda text)
returns text language plpgsql as $$
declare r record; v text; n int := 0;
begin
  for r in select p.oid from pg_proc p join pg_namespace s on s.oid = p.pronamespace where s.nspname = 'public' and p.proname = p_fn loop
    v := pg_get_functiondef(r.oid);
    if position(p_tanda in v) > 0 then n := n + 1; continue; end if;
    if position(p_cari in v) = 0 then raise notice 'Penambalan %: teks acuan tidak ditemukan, dilewati.', p_fn; continue; end if;
    execute replace(v, p_cari, p_ganti); n := n + 1;
  end loop;
  return p_fn || ': ' || n;
end $$;
select pg_temp.tambal('boleh_baca_surat_keluar', 'or public._baca_surat_teguran(p_id)',
  'or public._baca_surat_teguran(p_id) or public._baca_surat_sp_santri(p_id)', '_baca_surat_sp_santri');
-- Bukti foto pelanggaran (Google Drive): pencatat dan siapa pun yang boleh melihat kedisiplinan santri tersebut
select pg_temp.tambal('boleh_lihat_berkas', $c$if v_peran = 'superadmin' then return true; end if;$c$,
  $c$if v_peran = 'superadmin' then return true; end if;
  -- Bukti pelanggaran santri (14.6.0): diperiksa dengan hak pegawai yang meminta
  if exists (select 1 from student_violations sv where sv.bukti_id = p_obj) then
    v_sub := current_setting('request.jwt.claim.sub', true);
    perform set_config('request.jwt.claim.sub', coalesce((select user_id::text from employees where id = p_emp), ''), true);
    izin := exists (select 1 from student_violations sv where sv.bukti_id = p_obj and (sv.dicatat_oleh = p_emp or public.boleh_lihat_disiplin(sv.student_id)));
    perform set_config('request.jwt.claim.sub', coalesce(v_sub, ''), true);
    if izin then return true; end if;
  end if;$c$, 'student_violations');

-- ---------------------------------------------------------------------
-- 9. HAK EKSEKUSI
-- ---------------------------------------------------------------------
do $$ declare f text; begin
  foreach f in array array['hak_disiplin()', 'boleh_catat_pelanggaran(uuid)', 'boleh_lihat_disiplin(uuid)', 'pengaturan_disiplin()', 'simpan_pengaturan_disiplin(jsonb)',
                           'simpan_pelanggaran(jsonb)', 'hapus_pelanggaran(uuid,text)', 'daftar_pelanggaran(date,date,uuid)', 'cari_santri_disiplin(text)',
                           'saran_sp_santri(uuid)', 'usul_sp_santri(jsonb)', 'batal_sp_santri(uuid,text)', 'cabut_sp_santri(uuid,text)', 'serah_sp_santri(uuid,date,text)',
                           'daftar_sp_santri(date,date,uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['_kesantrian_saya()', '_kelola_disiplin()', '_lihat_semua_disiplin()', '_catat_semua_disiplin()', '_pengasuh_disiplin(uuid)',
                           '_disiplin_set()', '_penerima_kesantrian()', '_pelanggaran_terbuka(uuid)', '_ambang_disiplin(uuid)', '_pelanggaran_json(student_violations)',
                           '_sp_santri_aktif(uuid)', '_teks_sp_santri_sebelumnya(uuid,integer)', '_penanda_sp_santri(integer)', '_santri_surat_json(uuid)',
                           '_sp_santri_json(student_warnings)', '_baca_surat_sp_santri(uuid)', 'tg_sp_santri_surat()'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 10. PEMERIKSAAN — hasil yang benar: 6 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select '1. Tabel pelanggaran dan surat peringatan santri dengan RLS' as pemeriksaan,
       case when (select count(*) from pg_class where relname in ('student_violations','student_warnings') and relrowsecurity) = 2 then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Fitur Kedisiplinan santri di Hak Akses',
       case when exists (select 1 from public.features where kode = 'disiplin_santri' and dipakai) then 'Sesuai' else 'Periksa' end
union all
select '3. Izin admin kelola_disiplin',
       case when exists (select 1 from public.admin_capabilities where kode = 'kelola_disiplin') then 'Sesuai' else 'Periksa' end
union all
select '4. Template SP-1, SP-2, SP-3 santri tersedia',
       case when (select count(*) from public.letter_templates where kode in ('sp_santri_1','sp_santri_2','sp_santri_3')) = 3 then 'Sesuai' else 'Periksa' end
union all
select '5. Surat keluar SP santri mengikuti status (pemicu terpasang)',
       case when exists (select 1 from pg_trigger where tgname = 'zc_sp_santri') then 'Sesuai' else 'Periksa' end
union all
select '6. Persuratan mengenal SP santri; bukti pelanggaran dapat dibuka',
       case when position('_baca_surat_sp_santri' in pg_get_functiondef('public.boleh_baca_surat_keluar(uuid)'::regprocedure)) > 0
             and position('student_violations' in pg_get_functiondef('public.boleh_lihat_berkas(uuid,uuid)'::regprocedure)) > 0 then 'Sesuai' else 'Periksa' end;
