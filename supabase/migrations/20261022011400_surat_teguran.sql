-- SIMKA PRO | supabase/migrations/20261022011400_surat_teguran.sql | v1.0 | 14.1.0: Surat Teguran SP1–SP3 (usul Kepala Bidang, proses Tata Usaha, tanda tangan Direktur) | 17/10/2026
-- =====================================================================
-- SIMKA PRO · Migrasi 114: Surat Teguran SP1, SP2, SP3
--   Alur: Kepala Bidang (atau pemegang fitur Surat teguran) MENGUSULKAN → surat keluar dibuat otomatis dari template SP dan
--   langsung masuk ke Tata Usaha (status "Diperiksa TU") → TU memeriksa dan mengajukan tanda tangan → Direktur (paling tinggi
--   Ketua Yayasan) menandatangani → surat terbit bernomor (kode perihal IZ) → SP AKTIF selama masa berlakunya (bawaan 6 bulan)
--   → pegawai penerima mendapat notifikasi dan menyatakan "telah menerima" di akunnya → SP BERAKHIR otomatis.
--   * employee_warnings      : catatan SP (tingkat, pelanggaran, uraian, ringkasan kehadiran, masa berlaku, tanda terima, pencabutan)
--   * Ketentuan              : institution_settings 'surat_teguran' (masa berlaku per tingkat, penanda tangan per tingkat,
--                              kategori pelanggaran, harapan perbaikan, tembusan)
--   * Hak Akses              : fitur baru "Surat teguran" (1 lihat semua, 2 usul bagi anggota unitnya, 3 usul semua + cabut +
--                              ketentuan). Bawaan: Kepala Bidang 2; Direktur, Wakil Direktur, Yayasan 3; Tata Usaha 1.
--                              Penerima, pengusul, dan atasan langsung otomatis melihat SP terkait. Izin admin baru "kelola_teguran".
--   * Kerahasiaan            : SP tidak tampil di Layar Pantauan, grafik, maupun Portal Wali. Tidak ada potongan gaji otomatis;
--                              pembaca gaji melihat penanda "SP aktif" pada baris gaji.
--   * Template               : teguran_1, teguran_2, teguran_3 (dapat disunting TU), dengan kolom tanda tangan penerima di kanan.
-- Jalankan SETELAH migrasi 11300. Aman dijalankan ulang.
-- =====================================================================

drop table if exists pg_temp._sekali_sp;
create temp table _sekali_sp as
  select not exists (select 1 from public.features where kode = 'surat_teguran') as pertama;

-- ---------------------------------------------------------------------
-- 1. TABEL
-- ---------------------------------------------------------------------
create table if not exists public.employee_warnings (
  id               uuid primary key default gen_random_uuid(),
  employee_id      uuid not null references public.employees(id) on delete cascade,
  tingkat          smallint not null check (tingkat between 1 and 3),
  kategori         text[] not null default '{}',
  uraian           text not null,
  periode_mulai    date,
  periode_selesai  date,
  ringkasan_presensi jsonb,
  diusulkan_oleh   uuid references public.employees(id) on delete set null,
  diusulkan_pada   timestamptz not null default now(),
  letter_id        uuid references public.outgoing_letters(id) on delete set null,
  status           text not null default 'diusulkan' check (status in ('diusulkan','terbit','batal','dicabut')),
  nomor            text,
  tanggal_surat    date,
  berlaku_mulai    date,
  berlaku_sampai   date,
  diterima_pada    timestamptz,
  dicabut_oleh     uuid references public.employees(id) on delete set null,
  dicabut_pada     timestamptz,
  alasan           text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index if not exists ew_pegawai_idx on public.employee_warnings (employee_id, status);
create index if not exists ew_surat_idx on public.employee_warnings (letter_id);
create index if not exists ew_tanggal_idx on public.employee_warnings (diusulkan_pada desc);

drop trigger if exists aa_updated on public.employee_warnings;
create trigger aa_updated before update on public.employee_warnings for each row execute function public.tg_updated_at();
drop trigger if exists zz_audit on public.employee_warnings;
create trigger zz_audit after insert or update or delete on public.employee_warnings for each row execute function public.tg_audit();

-- ---------------------------------------------------------------------
-- 2. HAK AKSES: fitur "Surat teguran" dan izin admin
-- ---------------------------------------------------------------------
insert into public.features (kode, nama, kelompok, urutan, menu, arti, keterangan, kunci, sensitif) values
  ('surat_teguran', 'Surat teguran', 'Administrasi', 3, 'Persuratan → Surat Teguran (SP1–SP3)',
   '{"1": "Melihat semua surat teguran dan rekapnya", "2": "Mengusulkan surat teguran bagi pegawai di bidang/unit yang dipimpinnya", "3": "Mengusulkan bagi semua pegawai, mencabut surat teguran, dan mengatur ketentuannya"}'::jsonb,
   'Surat diproses Tata Usaha dan ditandatangani Direktur (paling tinggi Ketua Yayasan). Penerima, pengusul, dan atasan langsung otomatis melihat surat terkait.',
   null, false)
on conflict (kode) do update set nama = excluded.nama, kelompok = excluded.kelompok, urutan = excluded.urutan, menu = excluded.menu,
  arti = excluded.arti, keterangan = excluded.keterangan, dipakai = true;
update public.features set urutan = v.u from (values ('beban_kerja', 4), ('gaji', 5), ('tunjangan', 6), ('keuangan', 7)) v(k, u) where kode = v.k;

insert into public.admin_capabilities (kode, nama, urutan)
values ('kelola_teguran', 'Mengelola surat teguran pegawai (usul, cabut, ketentuan)', 19)
on conflict (kode) do update set nama = excluded.nama;
insert into public.capability_features (kode, feature_kode, tingkat_min) values ('kelola_teguran', 'surat_teguran', 3)
on conflict (kode, feature_kode) do update set tingkat_min = excluded.tingkat_min;

-- Hak bawaan (sekali)
insert into public.feature_grants (feature_kode, sasaran, sasaran_id, tingkat, mode, catatan)
select 'surat_teguran', 'struktural', sp.id, v.t, 'tambah', 'Bawaan 14.1.0'
from public.structural_positions sp join (values ('KEPALA_BIDANG', 2), ('DIREKTUR', 3), ('WAKIL_DIREKTUR', 3), ('YAYASAN', 3), ('TATA_USAHA', 1)) v(kode, t) on v.kode = sp.kode
where (select pertama from _sekali_sp)
on conflict (feature_kode, sasaran, sasaran_id) do nothing;

/** Hak Surat Teguran pengguna (untuk tampilan; setiap aksi diperiksa lagi di fungsinya). */
create or replace function public.hak_teguran()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'lihat', public.boleh_fitur('surat_teguran') or public.admin_boleh('kelola_teguran'),
    'usul', public.boleh_fitur('surat_teguran', 2) or public.admin_boleh('kelola_teguran'),
    'kelola', public.boleh_fitur('surat_teguran', 3) or public.admin_boleh('kelola_teguran'),
    'tu', public.boleh_kelola_persuratan(),
    'atasan', exists (select 1 from public.unit_pimpinan_saya()),
    'punya', exists (select 1 from employee_warnings w where w.diusulkan_oleh = public.saya() or (w.employee_id = public.saya() and w.status in ('terbit','dicabut'))))
$$;

/** Boleh mengusulkan SP bagi pegawai tertentu: tingkat Kelola untuk semua; Input/ubah untuk anggota unit yang dipimpinnya. */
create or replace function public.boleh_usul_teguran(p_emp uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select p_emp is distinct from public.saya() and (
         public.boleh_fitur('surat_teguran', 3) or public.admin_boleh('kelola_teguran')
      or (public.boleh_fitur('surat_teguran', 2) and public.pimpinan_dari(p_emp)))
$$;

/** Boleh melihat SP seorang pegawai: dirinya, pemegang fitur (Lihat), atasan langsung, Tata Usaha. */
create or replace function public.boleh_lihat_teguran(p_emp uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select p_emp = public.saya() or public.boleh_fitur('surat_teguran') or public.admin_boleh('kelola_teguran')
      or public.pimpinan_dari(p_emp) or public.boleh_kelola_persuratan()
$$;

alter table public.employee_warnings enable row level security;
drop policy if exists baca on public.employee_warnings;
create policy baca on public.employee_warnings for select to authenticated
  using ((employee_id = public.saya() and status in ('terbit','dicabut')) or diusulkan_oleh = public.saya()
         or (employee_id <> public.saya() and public.boleh_lihat_teguran(employee_id)));
-- Tidak ada kebijakan tulis: semua perubahan lewat fungsi.
revoke all on public.employee_warnings from anon;
grant select on public.employee_warnings to authenticated;

-- ---------------------------------------------------------------------
-- 3. KETENTUAN
-- ---------------------------------------------------------------------
create or replace function public._tgl_panjang(p date)
returns text language sql immutable set search_path = public as $$
  select case when p is null then '' else extract(day from p)::int || ' ' || public.nama_bulan(extract(month from p)::int) || ' ' || extract(year from p)::int end
$$;

create or replace function public._teguran_set()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'masa_bulan', jsonb_build_object('1', 6, '2', 6, '3', 6),
    'penanda', jsonb_build_object('1', null, '2', null, '3', null),
    'kategori', jsonb_build_array('Tidak hadir tanpa keterangan', 'Terlambat berulang kali', 'Tidak mengisi jurnal harian atau jurnal mengajar',
                                  'Tidak melaksanakan tugas yang diberikan', 'Melanggar tata tertib dan adab pondok', 'Lainnya'),
    'harapan', 'segera memperbaiki kedisiplinan dan kinerjanya serta menaati tata tertib yang berlaku',
    'tembusan', jsonb_build_array('Ketua Yayasan', 'Kepala {bidang}', 'Arsip'))
  || coalesce((select nilai from institution_settings where kunci = 'surat_teguran'), '{}'::jsonb)
$$;

create or replace function public.pengaturan_teguran()
returns jsonb language sql stable security definer set search_path = public as $$
  select public._teguran_set() || jsonb_build_object('boleh_ubah', public.boleh_fitur('surat_teguran', 3) or public.admin_boleh('kelola_teguran'))
$$;

create or replace function public.simpan_pengaturan_teguran(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v jsonb := '{}'::jsonb; k text; n int;
begin
  if not (public.boleh_fitur('surat_teguran', 3) or public.admin_boleh('kelola_teguran')) then
    raise exception 'Hanya pemegang Surat teguran tingkat Kelola yang dapat mengubah ketentuan.' using errcode = '42501'; end if;
  foreach k in array array['1','2','3'] loop
    n := coalesce((p->'masa_bulan'->>k)::int, 6);
    if n not between 1 and 24 then raise exception 'Masa berlaku SP-% harus 1 sampai 24 bulan.', k; end if;
    v := jsonb_set(v, '{masa_bulan}', coalesce(v->'masa_bulan', '{}'::jsonb) || jsonb_build_object(k, n));
    if nullif(p->'penanda'->>k, '') is not null and not exists (select 1 from signatories where id = (p->'penanda'->>k)::uuid and aktif) then
      raise exception 'Penanda tangan SP-% tidak dikenal.', k; end if;
    v := jsonb_set(v, '{penanda}', coalesce(v->'penanda', '{}'::jsonb) || jsonb_build_object(k, nullif(p->'penanda'->>k, '')));
  end loop;
  if jsonb_typeof(p->'kategori') <> 'array' or jsonb_array_length(p->'kategori') = 0 then raise exception 'Isi sedikitnya satu kategori pelanggaran.'; end if;
  v := v || jsonb_build_object(
    'kategori', (select coalesce(jsonb_agg(trim(x)), '[]') from jsonb_array_elements_text(p->'kategori') x where trim(x) <> ''),
    'harapan', coalesce(nullif(trim(p->>'harapan'), ''), (public._teguran_set()->>'harapan')),
    'tembusan', (select coalesce(jsonb_agg(trim(x)), '[]') from jsonb_array_elements_text(coalesce(p->'tembusan', '[]')) x where trim(x) <> ''));
  insert into institution_settings (kunci, nilai, publik, updated_by) values ('surat_teguran', v, false, public.saya())
  on conflict (kunci) do update set nilai = excluded.nilai, updated_at = now(), updated_by = excluded.updated_by;
  return public.pengaturan_teguran();
end $$;

-- ---------------------------------------------------------------------
-- 4. TEMPLATE SURAT (isi awal; dapat disunting Tata Usaha di Persuratan → Template)
-- ---------------------------------------------------------------------
insert into public.letter_templates (kode, nama, kategori, perihal_kode, format_nomor, dk, kop_kode, bentuk, judul, subjudul, hal_bawaan, kepada_bawaan,
                                     opsi, isi, isian, penanda, aktif, bawaan, urutan)
select v.kode, v.nama, 'pegawai', 'IZ', 'surat', 'D', 'pondok', 'tengah', v.judul, null, v.hal, null,
       '{"salam": true, "salam_penutup": true, "tembusan": true, "penerima": true}'::jsonb, v.isi,
       ('[{"kunci":"pegawai","label":"Pegawai yang ditegur","jenis":"pegawai","wajib":true},'
        '{"kunci":"pelanggaran","label":"Pelanggaran","jenis":"daftar","gaya":"angka","wajib":true},'
        '{"kunci":"uraian","label":"Uraian pelanggaran","jenis":"panjang","wajib":true},'
        || case when v.tingkat > 1 then '{"kunci":"sp_sebelumnya","label":"Surat teguran sebelumnya","jenis":"teks","wajib":true},' else '' end ||
        '{"kunci":"harapan","label":"Harapan perbaikan","jenis":"panjang","wajib":true,"bawaan":"segera memperbaiki kedisiplinan dan kinerjanya"},'
        '{"kunci":"masa_berlaku","label":"Masa berlaku","jenis":"teks","wajib":true,"bawaan":"6 (enam) bulan"}]')::jsonb,
       '[{"jabatan":"Direktur"}]'::jsonb, true, true, 20 + v.tingkat
from (values
 (1, 'teguran_1', 'Surat Teguran Pertama (SP-1)', 'SURAT TEGURAN PERTAMA (SP-1)', 'Surat Teguran Pertama (SP-1)',
$t$Dengan ini kami memberikan *Surat Teguran Pertama (SP-1)* kepada:

Nama : {pegawai.nama}
NIY : {pegawai.niy}
Jabatan : {pegawai.jabatan}
Unit kerja : {pegawai.unit}

Teguran ini diberikan karena yang bersangkutan:
{pelanggaran}

{uraian}

Sehubungan dengan hal tersebut, yang bersangkutan diminta untuk {harapan}. Surat teguran ini berlaku selama {masa_berlaku} sejak tanggal surat ini. Apabila dalam masa tersebut pelanggaran serupa terulang, akan diberikan Surat Teguran Kedua (SP-2) sesuai ketentuan yang berlaku di lingkungan {lembaga}.

Demikian surat teguran ini disampaikan untuk diperhatikan dan dilaksanakan dengan penuh tanggung jawab.$t$),
 (2, 'teguran_2', 'Surat Teguran Kedua (SP-2)', 'SURAT TEGURAN KEDUA (SP-2)', 'Surat Teguran Kedua (SP-2)',
$t$Dengan ini kami memberikan *Surat Teguran Kedua (SP-2)* kepada:

Nama : {pegawai.nama}
NIY : {pegawai.niy}
Jabatan : {pegawai.jabatan}
Unit kerja : {pegawai.unit}

Sebelumnya yang bersangkutan telah menerima {sp_sebelumnya}. Namun yang bersangkutan masih:
{pelanggaran}

{uraian}

Sehubungan dengan hal tersebut, yang bersangkutan diminta dengan sungguh-sungguh untuk {harapan}. Surat teguran ini berlaku selama {masa_berlaku} sejak tanggal surat ini. Apabila dalam masa tersebut pelanggaran serupa terulang, akan diberikan Surat Teguran Ketiga (SP-3) sesuai ketentuan yang berlaku di lingkungan {lembaga}.

Demikian surat teguran ini disampaikan untuk diperhatikan dan dilaksanakan dengan penuh tanggung jawab.$t$),
 (3, 'teguran_3', 'Surat Teguran Ketiga (SP-3)', 'SURAT TEGURAN KETIGA (SP-3)', 'Surat Teguran Ketiga (SP-3)',
$t$Dengan ini kami memberikan *Surat Teguran Ketiga (SP-3)* sebagai teguran terakhir kepada:

Nama : {pegawai.nama}
NIY : {pegawai.niy}
Jabatan : {pegawai.jabatan}
Unit kerja : {pegawai.unit}

Sebelumnya yang bersangkutan telah menerima {sp_sebelumnya}. Namun yang bersangkutan masih:
{pelanggaran}

{uraian}

Sehubungan dengan hal tersebut, yang bersangkutan diminta dengan sungguh-sungguh untuk {harapan}. Surat teguran ini berlaku selama {masa_berlaku} sejak tanggal surat ini. Apabila dalam masa tersebut pelanggaran serupa terulang, pimpinan akan mengambil tindakan tegas sesuai ketentuan kepegawaian yang berlaku di lingkungan {lembaga}.

Demikian surat teguran ini disampaikan untuk diperhatikan dan dilaksanakan dengan penuh tanggung jawab.$t$)
) v(tingkat, kode, nama, judul, hal, isi)
on conflict (kode) do nothing;

-- ---------------------------------------------------------------------
-- 5. BANTUAN: saran tingkat, ringkasan kehadiran, penanda tangan
-- ---------------------------------------------------------------------
/** SP yang masih berlaku untuk seorang pegawai (terbit dan belum lewat masa berlaku). */
create or replace function public._sp_aktif(p_emp uuid)
returns setof public.employee_warnings language sql stable security definer set search_path = public as $$
  select * from employee_warnings where employee_id = p_emp and status = 'terbit' and berlaku_sampai >= public.hari_ini()
  order by tingkat desc, tanggal_surat desc
$$;

/** Saran tingkat SP berikutnya: satu di atas SP aktif tertinggi (paling tinggi SP-3). */
create or replace function public.saran_teguran(p_emp uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_maks int; v_ref employee_warnings;
begin
  if not public.boleh_lihat_teguran(p_emp) then raise exception 'Tidak berwenang.' using errcode = '42501'; end if;
  select max(tingkat) into v_maks from public._sp_aktif(p_emp);
  select * into v_ref from public._sp_aktif(p_emp) limit 1;
  return jsonb_build_object(
    'saran', least(coalesce(v_maks, 0) + 1, 3),
    'sp3_aktif', coalesce(v_maks, 0) = 3,
    'diusulkan', exists (select 1 from employee_warnings where employee_id = p_emp and status = 'diusulkan'),
    'aktif', coalesce((select jsonb_agg(jsonb_build_object('id', w.id, 'tingkat', w.tingkat, 'nomor', w.nomor, 'tanggal_surat', w.tanggal_surat,
                        'berlaku_sampai', w.berlaku_sampai) order by w.tingkat desc) from public._sp_aktif(p_emp) w), '[]'::jsonb),
    'riwayat', (select count(*) from employee_warnings where employee_id = p_emp and status in ('terbit','dicabut')));
end $$;

/** Teks SP sebelumnya untuk isi surat SP-2/SP-3. */
create or replace function public._teks_sp_sebelumnya(p_emp uuid, p_tingkat int)
returns text language sql stable security definer set search_path = public as $$
  select coalesce(
    (select 'Surat Teguran ' || case w.tingkat when 1 then 'Pertama (SP-1)' when 2 then 'Kedua (SP-2)' else 'Ketiga (SP-3)' end
            || coalesce(' Nomor ' || w.nomor, '') || ' tanggal ' || public._tgl_panjang(w.tanggal_surat)
       from public._sp_aktif(p_emp) w where w.tingkat < p_tingkat order by w.tingkat desc limit 1),
    'teguran dan pembinaan dari atasannya')
$$;

/** Ringkasan kehadiran pegawai dalam rentang (untuk dasar pelanggaran kehadiran). */
create or replace function public.ringkasan_presensi_teguran(p_emp uuid, p_mulai date, p_selesai date)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not (public.boleh_usul_teguran(p_emp) or public.boleh_lihat_teguran(p_emp)) then raise exception 'Tidak berwenang.' using errcode = '42501'; end if;
  if p_mulai is null or p_selesai is null or p_selesai < p_mulai then raise exception 'Rentang tanggal tidak sah.'; end if;
  if p_selesai - p_mulai > 185 then raise exception 'Rentang paling lama 186 hari (satu semester).'; end if;
  return (select jsonb_build_object('mulai', p_mulai, 'selesai', p_selesai,
      'sesi', count(*), 'hadir', count(*) filter (where status in ('hadir','terlambat','dinas_luar')),
      'terlambat', count(*) filter (where status = 'terlambat'), 'menit_terlambat', coalesce(sum(terlambat_menit) filter (where status = 'terlambat'), 0),
      'tanpa_keterangan', count(*) filter (where status = 'tanpa_keterangan'),
      'izin_sakit_cuti', count(*) filter (where status in ('izin','sakit','cuti')),
      'pulang_cepat', count(*) filter (where status_pulang = 'cepat'),
      'tidak_presensi_pulang', count(*) filter (where status_pulang = 'tidak_presensi'))
    from attendances where employee_id = p_emp and tanggal between p_mulai and p_selesai and not opsional);
end $$;

create or replace function public._teks_presensi_teguran(r jsonb)
returns text language sql immutable set search_path = public as $$
  select case when r is null then '' else
    'Rekap kehadiran ' || public._tgl_panjang((r->>'mulai')::date) || ' sampai dengan ' || public._tgl_panjang((r->>'selesai')::date) || ': '
    || (r->>'sesi') || ' sesi wajib, hadir ' || (r->>'hadir') || ' sesi'
    || case when (r->>'terlambat')::int > 0 then ', terlambat ' || (r->>'terlambat') || ' kali (' || (r->>'menit_terlambat') || ' menit)' else '' end
    || case when (r->>'tanpa_keterangan')::int > 0 then ', tanpa keterangan ' || (r->>'tanpa_keterangan') || ' sesi' else '' end
    || case when (r->>'izin_sakit_cuti')::int > 0 then ', izin/sakit/cuti ' || (r->>'izin_sakit_cuti') || ' sesi' else '' end
    || case when (r->>'pulang_cepat')::int > 0 then ', pulang sebelum waktunya ' || (r->>'pulang_cepat') || ' kali' else '' end
    || case when (r->>'tidak_presensi_pulang')::int > 0 then ', tidak presensi pulang ' || (r->>'tidak_presensi_pulang') || ' kali' else '' end
    || '.' end
$$;

/** Penanda tangan SP per tingkat: dari ketentuan, atau Direktur (Penanda tangan bertaut jabatan DIREKTUR). */
create or replace function public._penanda_teguran(p_tingkat int)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_id uuid := nullif(public._teguran_set()->'penanda'->>p_tingkat::text, '')::uuid; st signatories;
begin
  if v_id is not null then select * into st from signatories where id = v_id and aktif; end if;
  if st.id is null then
    select * into st from signatories where aktif and (sumber_jabatan = 'DIREKTUR' or jabatan_tertulis ilike 'direktur%')
     order by (sumber_jabatan = 'DIREKTUR') desc nulls last, urutan limit 1;
  end if;
  if st.id is null then raise exception 'Penanda tangan Direktur belum diatur. Atur di Setelan → Penanda tangan, atau di ketentuan Surat Teguran.'; end if;
  return public._penanda_sah(jsonb_build_array(jsonb_build_object('signatory_id', st.id, 'jabatan', st.jabatan_tertulis)));
end $$;

-- ---------------------------------------------------------------------
-- 6. ALUR: usul, batal, terima, cabut
-- ---------------------------------------------------------------------
/** p: {employee_id, tingkat, kategori[], uraian, periode_mulai?, periode_selesai?, sertakan_presensi?, harapan?} → id SP */
create or replace function public.usul_teguran(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_emp uuid := nullif(p->>'employee_id', '')::uuid; v_t int := coalesce((p->>'tingkat')::int, 0); e record; t letter_templates;
        v_set jsonb := public._teguran_set(); v_kat text[]; v_uraian text; v_pres jsonb; v_mulai date := nullif(p->>'periode_mulai', '')::date;
        v_selesai date := nullif(p->>'periode_selesai', '')::date; v_masa int; v_pen jsonb; v_surat uuid; v_id uuid; v_bidang text; v_tem text[];
        v_nama_sp text; v_saya text;
begin
  if v_emp is null then raise exception 'Pilih pegawai.'; end if;
  if not public.boleh_usul_teguran(v_emp) then raise exception 'Anda tidak berwenang mengusulkan surat teguran untuk pegawai ini.' using errcode = '42501'; end if;
  if v_t not between 1 and 3 then raise exception 'Pilih tingkat SP-1, SP-2, atau SP-3.'; end if;
  if exists (select 1 from employee_warnings where employee_id = v_emp and status = 'diusulkan') then
    raise exception 'Pegawai ini masih memiliki usulan surat teguran yang sedang diproses.'; end if;
  select coalesce(array_agg(trim(x)) filter (where trim(x) <> ''), '{}') into v_kat from jsonb_array_elements_text(coalesce(p->'kategori', '[]')) x;
  if cardinality(v_kat) = 0 then raise exception 'Pilih sedikitnya satu pelanggaran.'; end if;
  v_uraian := trim(coalesce(p->>'uraian', ''));
  if length(v_uraian) < 10 then raise exception 'Uraikan pelanggaran (minimal 10 huruf).'; end if;
  if (v_mulai is null) <> (v_selesai is null) or v_selesai < v_mulai then raise exception 'Periode pelanggaran tidak sah.'; end if;
  if coalesce((p->>'sertakan_presensi')::boolean, false) then
    if v_mulai is null then raise exception 'Isi periode untuk menyertakan ringkasan kehadiran.'; end if;
    v_pres := public.ringkasan_presensi_teguran(v_emp, v_mulai, v_selesai);
  end if;

  select e2.id, e2.nama_lengkap, e2.niy, e2.org_unit_id,
         coalesce((select sp.nama from employee_structurals es join structural_positions sp on sp.id = es.structural_position_id where es.employee_id = e2.id limit 1),
                  (select string_agg(fp.nama, ', ' order by fp.urutan) from employee_functions ef join functional_positions fp on fp.id = ef.functional_position_id where ef.employee_id = e2.id),
                  'Pegawai') jabatan,
         (select nama from org_units where id = e2.org_unit_id) unit
    into e from employees e2 where e2.id = v_emp and e2.status_keaktifan = 'aktif';
  if e.id is null then raise exception 'Pegawai tidak ditemukan atau tidak aktif.'; end if;
  select * into t from letter_templates where kode = 'teguran_' || v_t and aktif;
  if t.id is null then raise exception 'Template Surat Teguran SP-% tidak aktif. Aktifkan di Persuratan → Template.', v_t; end if;
  v_masa := coalesce((v_set->'masa_bulan'->>v_t::text)::int, 6);
  v_pen := public._penanda_teguran(v_t);
  v_bidang := coalesce((select nama from org_units where id = public._bidang_unit(e.org_unit_id)), e.unit, 'bidang terkait');
  select coalesce(array_agg(replace(x, '{bidang}', regexp_replace(v_bidang, '^Bidang\s+', ''))) , '{}') into v_tem from jsonb_array_elements_text(v_set->'tembusan') x;
  v_nama_sp := case v_t when 1 then 'Surat Teguran Pertama (SP-1)' when 2 then 'Surat Teguran Kedua (SP-2)' else 'Surat Teguran Ketiga (SP-3)' end;

  insert into outgoing_letters (template_id, jenis_nama, kategori, kop_kode, dk, perihal_kode, format_nomor, tanggal_surat, perihal, kepada, tembusan,
                                nilai, tampilan, penanda, status, disusun_oleh, pemohon_id, catatan)
  values (t.id, t.nama, t.kategori, t.kop_kode, t.dk, t.perihal_kode, t.format_nomor, public.hari_ini(), v_nama_sp || ' – ' || e.nama_lengkap, e.nama_lengkap, v_tem,
          jsonb_build_object(
            'pegawai', jsonb_build_object('id', e.id, 'nama', e.nama_lengkap, 'niy', e.niy, 'jabatan', e.jabatan, 'unit', e.unit),
            'pelanggaran', to_jsonb(v_kat),
            'uraian', v_uraian || case when v_pres is not null then E'\n' || public._teks_presensi_teguran(v_pres) else '' end,
            'sp_sebelumnya', public._teks_sp_sebelumnya(v_emp, v_t),
            'harapan', coalesce(nullif(trim(p->>'harapan'), ''), v_set->>'harapan'),
            'masa_berlaku', v_masa || ' (' || case v_masa when 1 then 'satu' when 2 then 'dua' when 3 then 'tiga' when 4 then 'empat' when 5 then 'lima'
                              when 6 then 'enam' when 7 then 'tujuh' when 8 then 'delapan' when 9 then 'sembilan' when 10 then 'sepuluh' when 11 then 'sebelas'
                              when 12 then 'dua belas' else v_masa::text end || ') bulan'),
          jsonb_build_object('bentuk', t.bentuk, 'judul', t.judul, 'subjudul', t.subjudul, 'isi', t.isi, 'opsi', t.opsi, 'isian', t.isian),
          v_pen, 'diperiksa', public.saya(), public.saya(), 'Usulan surat teguran')
  returning id into v_surat;

  insert into employee_warnings (employee_id, tingkat, kategori, uraian, periode_mulai, periode_selesai, ringkasan_presensi, diusulkan_oleh, letter_id)
  values (v_emp, v_t, v_kat, v_uraian, v_mulai, v_selesai, v_pres, public.saya(), v_surat)
  returning id into v_id;

  select nama_lengkap into v_saya from employees where id = public.saya();
  insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
  select x, 'Usulan surat teguran perlu diproses', coalesce(v_saya, 'Pimpinan') || ' mengusulkan ' || v_nama_sp || ' untuk ' || e.nama_lengkap || '.',
         '/persuratan/keluar?surat=' || v_surat, 'WarningOctagon', 'jingga'
    from (select public._pengelola_surat() x union select ap.employee_id from admin_permissions ap join employees ee on ee.id = ap.employee_id
           where ap.kode = 'kelola_teguran' and ee.peran = 'admin' and ee.status_akun = 'aktif') q
   where x <> public.saya();
  return v_id;
end $$;

/** Pengusul atau Tata Usaha membatalkan usulan yang belum terbit (surat ikut dibatalkan). */
create or replace function public.batal_teguran(p_id uuid, p_alasan text)
returns void language plpgsql volatile security definer set search_path = public as $$
declare w employee_warnings; o outgoing_letters;
begin
  select * into w from employee_warnings where id = p_id for update;
  if w.id is null then raise exception 'Surat teguran tidak ditemukan.'; end if;
  if w.status <> 'diusulkan' then raise exception 'Hanya usulan yang belum terbit yang dapat dibatalkan.'; end if;
  if not (w.diusulkan_oleh = public.saya() or public.boleh_kelola_persuratan() or public.boleh_fitur('surat_teguran', 3) or public.admin_boleh('kelola_teguran')) then
    raise exception 'Hanya pengusul atau Tata Usaha yang dapat membatalkan usulan ini.' using errcode = '42501'; end if;
  if length(trim(coalesce(p_alasan, ''))) < 5 then raise exception 'Tuliskan alasan pembatalan (minimal 5 huruf).'; end if;
  update employee_warnings set status = 'batal', alasan = trim(p_alasan) where id = p_id;
  select * into o from outgoing_letters where id = w.letter_id for update;
  if o.id is not null and o.status in ('draf','diperiksa','ditolak','menunggu_ttd') then
    update outgoing_letters set status = 'dibatalkan', catatan = 'Usulan surat teguran dibatalkan: ' || trim(p_alasan) where id = o.id;
    if o.document_id is not null then
      update document_registry set status = 'dicabut', dicabut_pada = now(), dicabut_oleh = public.saya(), alasan_cabut = trim(p_alasan)
       where id = o.document_id and status = 'draf';
      update notifications set dibaca_pada = coalesce(dibaca_pada, now()) where tautan = '/persuratan/keluar?resmi=' || o.document_id;
    end if;
  end if;
end $$;

/** Pegawai penerima menyatakan telah menerima SP. */
create or replace function public.terima_teguran(p_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare w employee_warnings; v_nama text;
begin
  select * into w from employee_warnings where id = p_id for update;
  if w.id is null or w.employee_id is distinct from public.saya() then raise exception 'Surat teguran tidak ditemukan.' using errcode = '42501'; end if;
  if w.status <> 'terbit' then raise exception 'Surat teguran ini belum terbit atau sudah dicabut.'; end if;
  if w.diterima_pada is not null then return; end if;
  update employee_warnings set diterima_pada = now() where id = p_id;
  select nama_lengkap into v_nama from employees where id = w.employee_id;
  if w.diusulkan_oleh is not null then
    perform public.kirim_notifikasi(w.diusulkan_oleh, 'Surat teguran telah diterima', coalesce(v_nama, 'Pegawai') || ' menyatakan telah menerima SP-' || w.tingkat || coalesce(' (' || w.nomor || ')', '') || '.',
      '/persuratan/teguran?sp=' || w.id, 'CheckCircle', 'hijau');
  end if;
end $$;

/** Pemegang Surat teguran tingkat Kelola mencabut SP yang sudah terbit (tidak lagi dihitung; surat tetap tercatat). */
create or replace function public.cabut_teguran(p_id uuid, p_alasan text)
returns void language plpgsql volatile security definer set search_path = public as $$
declare w employee_warnings;
begin
  if not (public.boleh_fitur('surat_teguran', 3) or public.admin_boleh('kelola_teguran')) then
    raise exception 'Hanya pemegang Surat teguran tingkat Kelola yang dapat mencabut surat teguran.' using errcode = '42501'; end if;
  select * into w from employee_warnings where id = p_id for update;
  if w.id is null then raise exception 'Surat teguran tidak ditemukan.'; end if;
  if w.status <> 'terbit' then raise exception 'Hanya surat teguran yang sudah terbit yang dapat dicabut.'; end if;
  if length(trim(coalesce(p_alasan, ''))) < 5 then raise exception 'Tuliskan alasan pencabutan (minimal 5 huruf).'; end if;
  update employee_warnings set status = 'dicabut', dicabut_oleh = public.saya(), dicabut_pada = now(), alasan = trim(p_alasan) where id = p_id;
  perform public.kirim_notifikasi(w.employee_id, 'Surat teguran dicabut', 'SP-' || w.tingkat || coalesce(' (' || w.nomor || ')', '') || ' dicabut: ' || left(trim(p_alasan), 140),
    '/profil/teguran', 'ArrowCounterClockwise', 'hijau');
end $$;

/** Pemicu surat keluar: SP mengikuti status suratnya (terbit → aktif; dibatalkan → batal; dicabut → dicabut; revisi terbit → pindah). */
create or replace function public.tg_teguran_surat()
returns trigger language plpgsql security definer set search_path = public as $$
declare w employee_warnings; v_masa int; v_set jsonb;
begin
  if new.status is not distinct from old.status then return new; end if;
  if new.status = 'terbit' then
    v_set := public._teguran_set();
    for w in select * from employee_warnings where letter_id in (new.id, new.revisi_dari) and status in ('diusulkan','terbit') loop
      v_masa := coalesce((v_set->'masa_bulan'->>w.tingkat::text)::int, 6);
      update employee_warnings set letter_id = new.id, status = 'terbit', nomor = new.nomor, tanggal_surat = new.tanggal_surat,
             berlaku_mulai = new.tanggal_surat, berlaku_sampai = (new.tanggal_surat + make_interval(months => v_masa))::date - 1
       where id = w.id;
      if w.status = 'diusulkan' then
        perform public.kirim_notifikasi(w.employee_id, 'Anda menerima surat teguran',
          'Surat Teguran ' || case w.tingkat when 1 then 'Pertama (SP-1)' when 2 then 'Kedua (SP-2)' else 'Ketiga (SP-3)' end || ' Nomor ' || coalesce(new.nomor, '–')
          || '. Buka untuk membaca dan menyatakan telah menerima.', '/profil/teguran', 'WarningOctagon', 'merah');
        if w.diusulkan_oleh is not null then
          perform public.kirim_notifikasi(w.diusulkan_oleh, 'Surat teguran terbit', 'SP-' || w.tingkat || ' (' || coalesce(new.nomor, '–') || ') telah terbit dan dikirim kepada pegawai.',
            '/persuratan/teguran?sp=' || w.id, 'SealCheck', 'hijau');
        end if;
      end if;
    end loop;
  elsif new.status = 'dibatalkan' then
    update employee_warnings set status = 'batal', alasan = coalesce(alasan, new.catatan) where letter_id = new.id and status = 'diusulkan';
  elsif new.status = 'dicabut' then
    update employee_warnings set status = 'dicabut', dicabut_pada = now(), alasan = coalesce(new.catatan, 'Surat dicabut')
     where letter_id = new.id and status = 'terbit';
  end if;
  return new;
end $$;
drop trigger if exists zb_teguran on public.outgoing_letters;
create trigger zb_teguran after update of status on public.outgoing_letters for each row execute function public.tg_teguran_surat();

-- ---------------------------------------------------------------------
-- 7. BACA
-- ---------------------------------------------------------------------
create or replace function public._teguran_json(w employee_warnings)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', w.id, 'employee_id', w.employee_id, 'nama', e.nama_lengkap, 'niy', e.niy, 'jenis_kelamin', e.jenis_kelamin,
    'unit', u.nama, 'bidang', (select nama from org_units where id = public._bidang_unit(e.org_unit_id)),
    'jabatan', coalesce((select sp.nama from employee_structurals es join structural_positions sp on sp.id = es.structural_position_id where es.employee_id = e.id limit 1),
                        (select string_agg(fp.nama, ', ' order by fp.urutan) from employee_functions ef join functional_positions fp on fp.id = ef.functional_position_id where ef.employee_id = e.id)),
    'tingkat', w.tingkat, 'kategori', to_jsonb(w.kategori), 'uraian', w.uraian, 'periode_mulai', w.periode_mulai, 'periode_selesai', w.periode_selesai,
    'ringkasan_presensi', w.ringkasan_presensi, 'diusulkan_oleh', w.diusulkan_oleh, 'pengusul', pe.nama_lengkap, 'diusulkan_pada', w.diusulkan_pada,
    'letter_id', w.letter_id, 'status_surat', o.status, 'status', w.status,
    'keadaan', case when w.status = 'terbit' and w.berlaku_sampai >= public.hari_ini() then 'aktif' when w.status = 'terbit' then 'berakhir' else w.status end,
    'nomor', w.nomor, 'tanggal_surat', w.tanggal_surat, 'berlaku_mulai', w.berlaku_mulai, 'berlaku_sampai', w.berlaku_sampai,
    'diterima_pada', w.diterima_pada, 'dicabut_pada', w.dicabut_pada, 'alasan', w.alasan,
    'saya_penerima', w.employee_id = public.saya(), 'saya_pengusul', w.diusulkan_oleh = public.saya())
  from employees e left join org_units u on u.id = e.org_unit_id left join employees pe on pe.id = w.diusulkan_oleh
  left join outgoing_letters o on o.id = w.letter_id
  where e.id = w.employee_id
$$;

/** Daftar SP yang boleh dilihat (rentang tanggal usul; p_emp untuk satu pegawai). */
create or replace function public.daftar_teguran(p_mulai date default null, p_selesai date default null, p_emp uuid default null)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(public._teguran_json(w) order by w.diusulkan_pada desc), '[]'::jsonb)
    from employee_warnings w
   where (p_emp is null or w.employee_id = p_emp)
     and (p_mulai is null or w.diusulkan_pada::date >= p_mulai) and (p_selesai is null or w.diusulkan_pada::date <= p_selesai)
     and (w.diusulkan_oleh = public.saya() or (w.employee_id = public.saya() and w.status in ('terbit','dicabut'))
          or (w.employee_id <> public.saya() and public.boleh_lihat_teguran(w.employee_id)))
$$;

/** SP milik pengguna (penerima) yang sudah terbit. */
create or replace function public.teguran_saya()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(public._teguran_json(w) order by w.tanggal_surat desc), '[]'::jsonb)
    from employee_warnings w where w.employee_id = public.saya() and w.status in ('terbit','dicabut')
$$;

/** Pegawai yang dapat diusulkan SP oleh pengguna, beserta SP aktif tertingginya. */
create or replace function public.pegawai_untuk_teguran()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', e.id, 'nama', e.nama_lengkap, 'niy', e.niy, 'jenis_kelamin', e.jenis_kelamin, 'unit', u.nama,
           'sp_aktif', (select max(tingkat) from public._sp_aktif(e.id)),
           'diusulkan', exists (select 1 from employee_warnings x where x.employee_id = e.id and x.status = 'diusulkan')) order by e.nama_lengkap), '[]'::jsonb)
    from employees e left join org_units u on u.id = e.org_unit_id
   where e.status_keaktifan = 'aktif' and e.peran <> 'superadmin' and e.id <> public.saya()
     and (public.boleh_fitur('surat_teguran', 3) or public.admin_boleh('kelola_teguran')
          or (public.boleh_fitur('surat_teguran', 2) and public.pimpinan_dari(e.id)))
$$;

/** Penanda SP aktif per pegawai (employee_id → tingkat) bagi pembaca gaji dan pemegang Surat teguran. */
create or replace function public.sp_aktif_pegawai()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_object_agg(employee_id, tingkat), '{}'::jsonb) from (
    select w.employee_id, max(w.tingkat) tingkat from employee_warnings w
     where w.status = 'terbit' and w.berlaku_sampai >= public.hari_ini()
       and (public.boleh_lihat_gaji() or public.boleh_lihat_teguran(w.employee_id))
     group by w.employee_id) q
$$;

/** Surat keluar SP dapat dibaca penerimanya (setelah terbit) dan siapa pun yang boleh melihat SP tersebut. */
create or replace function public._baca_surat_teguran(p_letter uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from employee_warnings w where w.letter_id = p_letter
                   and ((w.employee_id = public.saya() and w.status in ('terbit','dicabut'))
                        or w.diusulkan_oleh = public.saya()
                        or (w.employee_id <> public.saya() and public.boleh_lihat_teguran(w.employee_id))))
$$;

-- ---------------------------------------------------------------------
-- 8. PENAMBALAN DI TEMPAT: Persuratan mengenal Surat Teguran
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
select pg_temp.tambal('boleh_baca_surat_keluar', 'select public.boleh_kelola_persuratan()',
  'select public.boleh_kelola_persuratan() or public._baca_surat_teguran(p_id)', '_baca_surat_teguran');
select pg_temp.tambal('hak_persuratan', '''pengaturan'', public.pengaturan_persuratan())',
  '''pengaturan'', public.pengaturan_persuratan(), ''teguran'', public.hak_teguran())', 'hak_teguran()');
select pg_temp.tambal('hak_persuratan', '''tampil'', public.boleh_susun_surat()',
  '''tampil'', public.boleh_susun_surat() or public.boleh_fitur(''surat_teguran'') or public.admin_boleh(''kelola_teguran'') or exists (select 1 from employee_warnings where diusulkan_oleh = public.saya())',
  'boleh_fitur(''surat_teguran'')');

-- ---------------------------------------------------------------------
-- 9. HAK EKSEKUSI
-- ---------------------------------------------------------------------
do $$ declare f text; begin
  foreach f in array array['hak_teguran()', 'boleh_usul_teguran(uuid)', 'boleh_lihat_teguran(uuid)', 'pengaturan_teguran()', 'simpan_pengaturan_teguran(jsonb)',
                           'saran_teguran(uuid)', 'ringkasan_presensi_teguran(uuid,date,date)', 'usul_teguran(jsonb)', 'batal_teguran(uuid,text)',
                           'terima_teguran(uuid)', 'cabut_teguran(uuid,text)', 'daftar_teguran(date,date,uuid)', 'teguran_saya()', 'pegawai_untuk_teguran()',
                           'sp_aktif_pegawai()'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['_teguran_set()', '_sp_aktif(uuid)', '_teks_sp_sebelumnya(uuid,integer)', '_penanda_teguran(integer)', '_teguran_json(employee_warnings)',
                           '_baca_surat_teguran(uuid)', 'tg_teguran_surat()'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 10. PEMERIKSAAN — hasil yang benar: 6 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select '1. Tabel surat teguran tersedia dengan RLS' as pemeriksaan,
       case when exists (select 1 from pg_class where relname = 'employee_warnings' and relrowsecurity) then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Fitur Surat teguran di Hak Akses (40 fitur)',
       case when exists (select 1 from public.features where kode = 'surat_teguran' and dipakai) and (select count(*) from public.features where dipakai) >= 40
            then 'Sesuai' else 'Periksa' end
union all
select '3. Hak bawaan Kepala Bidang mengusulkan',
       case when exists (select 1 from public.feature_grants g join public.structural_positions sp on sp.id = g.sasaran_id
                          where g.feature_kode = 'surat_teguran' and sp.kode = 'KEPALA_BIDANG' and g.tingkat >= 2) then 'Sesuai' else 'Periksa' end
union all
select '4. Template SP-1, SP-2, SP-3 tersedia',
       case when (select count(*) from public.letter_templates where kode in ('teguran_1','teguran_2','teguran_3')) = 3 then 'Sesuai' else 'Periksa' end
union all
select '5. Surat keluar SP mengikuti status (pemicu terpasang)',
       case when exists (select 1 from pg_trigger where tgname = 'zb_teguran') then 'Sesuai' else 'Periksa' end
union all
select '6. Persuratan mengenal Surat Teguran',
       case when position('hak_teguran' in pg_get_functiondef('public.hak_persuratan()'::regprocedure)) > 0
             and position('_baca_surat_teguran' in pg_get_functiondef('public.boleh_baca_surat_keluar(uuid)'::regprocedure)) > 0 then 'Sesuai' else 'Periksa' end;
