-- SIMKA PRO | supabase/migrations/20261010006000_registri_dokumen.sql | v1.0 | Fase 8 – Tahap 1 Registri dokumen dan Cek Keabsahan | 10/10/2026
-- =====================================================================
-- Isi:
--   * document_registry   : satu daftar untuk SEMUA dokumen bertanda tangan elektronik (kode validasi 8 karakter,
--                           jenis, nomor, perihal, nama yang bersangkutan, status sah/direvisi/dicabut, sidik SHA-256).
--   * document_signatures : penanda tangan setiap dokumen (nama, jabatan, waktu). Tahap berikutnya memakai tabel
--                           ini untuk permintaan tanda tangan laporan resmi.
--   * Surat pengajuan pegawai (leave_requests) dan Surat Keterangan Sakit (clinic_letters) otomatis terdaftar
--     lewat pemicu; data lama didaftarkan sekali saat migrasi ini dijalankan. Pengajuan yang dibatalkan
--     superadmin otomatis berstatus "Dicabut".
--   * cek_dokumen(kode)   : dipanggil halaman publik Cek Keabsahan Dokumen (tanpa masuk); hanya data ringkas
--                           (tanpa isi dokumen, tanpa data kesehatan).
--   * cabut_dokumen()     : superadmin mencabut dokumen (alasan wajib).
-- Jalankan SETELAH migrasi 5900. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TABEL
-- ---------------------------------------------------------------------
create table if not exists public.document_registry (
  id               uuid primary key default gen_random_uuid(),
  kode             text not null unique check (kode ~ '^[A-Z2-9]{4}-[A-Z2-9]{4}$'),
  jenis            text not null,
  jenis_nama       text not null,
  nomor            text,
  perihal          text,
  subjek           text,
  periode          text,
  kop_kode         text,
  status           text not null default 'sah' check (status in ('draf','sah','direvisi','dicabut')),
  sidik            text,
  ref_tabel        text,
  ref_id           uuid,
  diterbitkan_pada timestamptz not null default now(),
  diterbitkan_oleh uuid references public.employees(id) on delete set null,
  dicabut_pada     timestamptz,
  dicabut_oleh     uuid references public.employees(id) on delete set null,
  alasan_cabut     text,
  pengganti_id     uuid references public.document_registry(id) on delete set null,
  jumlah_cek       int not null default 0,
  terakhir_dicek   timestamptz,
  created_at       timestamptz not null default now()
);
create unique index if not exists document_registry_ref_uidx on public.document_registry (ref_tabel, ref_id) where ref_id is not null;
create index if not exists document_registry_terbit_idx on public.document_registry (diterbitkan_pada desc);
create index if not exists document_registry_jenis_idx on public.document_registry (jenis, status);

create table if not exists public.document_signatures (
  id           uuid primary key default gen_random_uuid(),
  document_id  uuid not null references public.document_registry(id) on delete cascade,
  urutan       int not null default 1,
  posisi       text not null default 'kiri' check (posisi in ('kiri','kanan')),
  employee_id  uuid references public.employees(id) on delete set null,
  nama         text not null,
  jabatan      text,
  niy          text,
  status       text not null default 'ditandatangani' check (status in ('menunggu','ditandatangani','ditolak')),
  waktu        timestamptz,
  catatan      text,
  created_at   timestamptz not null default now()
);
create index if not exists document_signatures_doc_idx on public.document_signatures (document_id, urutan);
create index if not exists document_signatures_emp_idx on public.document_signatures (employee_id, status);

alter table public.document_registry enable row level security;
alter table public.document_signatures enable row level security;

-- Baca: admin/superadmin, penerbit, penanda tangan. Tulis hanya lewat fungsi.
drop policy if exists baca on public.document_registry;
create policy baca on public.document_registry for select to authenticated using (
  (select public.is_admin()) or diterbitkan_oleh = (select public.saya())
  or exists (select 1 from public.document_signatures s where s.document_id = document_registry.id and s.employee_id = (select public.saya())));
drop policy if exists baca on public.document_signatures;
create policy baca on public.document_signatures for select to authenticated using (
  document_id in (select d.id from public.document_registry d));
revoke insert, update, delete on public.document_registry, public.document_signatures from anon, authenticated;

-- ---------------------------------------------------------------------
-- 2. KODE VALIDASI (tanpa 0/O, 1/I/L) unik di semua sumber
-- ---------------------------------------------------------------------
create or replace function public._kode_dokumen()
returns text language plpgsql volatile set search_path = public as $$
declare a text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; s text; i int;
begin
  loop
    s := '';
    for i in 1..8 loop s := s || substr(a, 1 + floor(random() * length(a))::int, 1); end loop;
    s := substr(s, 1, 4) || '-' || substr(s, 5, 4);
    exit when not exists (select 1 from document_registry where kode = s)
          and not exists (select 1 from leave_requests where kode_validasi = s)
          and not exists (select 1 from clinic_letters where kode_validasi = s);
  end loop;
  return s;
end $$;

-- Pengajuan pegawai memakai pembuat kode yang sama (tidak bertabrakan dengan dokumen lain)
create or replace function public._kode_validasi()
returns text language sql volatile set search_path = public as $$ select public._kode_dokumen() $$;

/** Sidik SHA-256 (heksadesimal) dari isi dokumen dalam bentuk JSON kanonis. */
create or replace function public._sidik(p jsonb)
returns text language sql immutable set search_path = public, extensions as $$
  select encode(extensions.digest(convert_to(p::text, 'UTF8'), 'sha256'), 'hex')
$$;

-- ---------------------------------------------------------------------
-- 3. PENDAFTARAN OTOMATIS: SURAT PENGAJUAN PEGAWAI
-- ---------------------------------------------------------------------
create or replace function public._daftar_pengajuan(p_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare r record; v_doc uuid; v_status text; v_isi jsonb;
begin
  select l.*, t.nama as jenis_nama_cuti, e.nama_lengkap, e.niy
    into r from leave_requests l join leave_types t on t.id = l.leave_type_id join employees e on e.id = l.employee_id where l.id = p_id;
  if not found or r.kode_validasi is null then return; end if;
  -- Kode sudah dipakai dokumen lain (sangat jarang): lewati agar persetujuan tidak gagal
  if exists (select 1 from document_registry d where d.kode = r.kode_validasi and (d.ref_tabel, d.ref_id) is distinct from ('leave_requests', p_id)) then return; end if;
  v_status := case r.status when 'disetujui' then 'sah' when 'dibatalkan' then 'dicabut' else 'draf' end;
  v_isi := jsonb_build_object('nomor', r.nomor_surat, 'jenis', r.jenis_nama_cuti, 'nama', r.nama_lengkap, 'niy', r.niy,
                              'mulai', r.mulai, 'selesai', r.selesai, 'hari', r.jumlah_hari, 'alasan', r.alasan, 'diputus', r.diputus_pada);
  insert into document_registry (kode, jenis, jenis_nama, nomor, perihal, subjek, kop_kode, status, sidik, ref_tabel, ref_id,
                                 diterbitkan_pada, diterbitkan_oleh, dicabut_pada, dicabut_oleh, alasan_cabut)
  values (r.kode_validasi, 'pengajuan_pegawai', 'Surat ' || r.jenis_nama_cuti, r.nomor_surat,
          r.jenis_nama_cuti || ' ' || r.jumlah_hari || ' hari, ' || to_char(r.mulai, 'DD/MM/YYYY')
            || case when r.selesai > r.mulai then ' s.d. ' || to_char(r.selesai, 'DD/MM/YYYY') else '' end,
          r.nama_lengkap, r.kop_kode, v_status, public._sidik(v_isi), 'leave_requests', p_id,
          coalesce(r.diputus_pada, r.updated_at), r.employee_id,
          case when v_status = 'dicabut' then coalesce(r.updated_at, now()) end, case when v_status = 'dicabut' then r.dibatalkan_oleh end,
          case when v_status = 'dicabut' then 'Pengajuan dibatalkan' end)
  on conflict (ref_tabel, ref_id) where ref_id is not null do update set
    kode = excluded.kode, jenis_nama = excluded.jenis_nama, nomor = excluded.nomor, perihal = excluded.perihal, subjek = excluded.subjek,
    status = case when document_registry.status = 'dicabut' then 'dicabut' else excluded.status end,
    sidik = excluded.sidik, dicabut_pada = coalesce(document_registry.dicabut_pada, excluded.dicabut_pada),
    dicabut_oleh = coalesce(document_registry.dicabut_oleh, excluded.dicabut_oleh),
    alasan_cabut = coalesce(document_registry.alasan_cabut, excluded.alasan_cabut)
  returning id into v_doc;
  -- Penanda tangan: semua penyetuju (berurutan); kanan = pemohon
  delete from document_signatures where document_id = v_doc;
  insert into document_signatures (document_id, urutan, posisi, employee_id, nama, jabatan, niy, status, waktu, catatan)
  select v_doc, a.urutan, 'kiri', a.oleh, coalesce(a.nama, e.nama_lengkap), coalesce(a.jabatan_tertulis, public.nama_peran_jenjang(a.peran)),
         coalesce(a.niy, e.niy), 'ditandatangani', a.waktu, case when a.atas_nama then 'Diputus superadmin atas nama jenjang ini' end
    from leave_approvals a left join employees e on e.id = a.oleh
   where a.request_id = p_id and a.status = 'disetujui';
  insert into document_signatures (document_id, urutan, posisi, employee_id, nama, jabatan, niy, status, waktu)
  values (v_doc, 99, 'kanan', r.employee_id, r.nama_lengkap, 'Pemohon', r.niy, 'ditandatangani', r.created_at);
end $$;

create or replace function public.tg_daftar_pengajuan()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.kode_validasi is not null then perform public._daftar_pengajuan(new.id); end if;
  return null;
end $$;
drop trigger if exists zz_registri on public.leave_requests;
create trigger zz_registri after insert or update of status, kode_validasi, nomor_surat on public.leave_requests
  for each row execute function public.tg_daftar_pengajuan();

-- ---------------------------------------------------------------------
-- 4. PENDAFTARAN OTOMATIS: SURAT KETERANGAN SAKIT
-- ---------------------------------------------------------------------
create or replace function public._daftar_surat_sakit(p_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare r record; v_doc uuid; v_isi jsonb;
begin
  select l.*, s.nama_lengkap, s.nis, e.nama_lengkap as petugas, e.niy as petugas_niy
    into r from clinic_letters l join clinic_cases c on c.id = l.case_id join students s on s.id = c.student_id
    left join employees e on e.id = l.dibuat_oleh where l.id = p_id;
  if not found then return; end if;
  if exists (select 1 from document_registry d where d.kode = r.kode_validasi and (d.ref_tabel, d.ref_id) is distinct from ('clinic_letters', p_id)) then return; end if;
  v_isi := jsonb_build_object('nomor', r.nomor, 'nama', r.nama_lengkap, 'nis', r.nis, 'tanggal', r.tanggal,
                              'mulai', r.istirahat_mulai, 'sampai', r.istirahat_sampai, 'keperluan', r.keperluan, 'diagnosis', r.diagnosis);
  insert into document_registry (kode, jenis, jenis_nama, nomor, perihal, subjek, kop_kode, status, sidik, ref_tabel, ref_id, diterbitkan_pada, diterbitkan_oleh)
  values (r.kode_validasi, 'surat_sakit', 'Surat Keterangan Sakit', r.nomor,
          'Istirahat sakit ' || to_char(r.istirahat_mulai, 'DD/MM/YYYY')
            || case when r.istirahat_sampai > r.istirahat_mulai then ' s.d. ' || to_char(r.istirahat_sampai, 'DD/MM/YYYY') else '' end,
          r.nama_lengkap || ' (NIS ' || r.nis || ')', 'pondok', 'sah', public._sidik(v_isi), 'clinic_letters', p_id, r.created_at, r.dibuat_oleh)
  on conflict (ref_tabel, ref_id) where ref_id is not null do update set nomor = excluded.nomor, perihal = excluded.perihal, sidik = excluded.sidik
  returning id into v_doc;
  delete from document_signatures where document_id = v_doc;
  insert into document_signatures (document_id, urutan, posisi, employee_id, nama, jabatan, niy, status, waktu)
  values (v_doc, 1, 'kanan', r.dibuat_oleh, coalesce(r.petugas, 'Petugas Klinik'), 'Petugas Klinik', r.petugas_niy, 'ditandatangani', r.created_at);
end $$;

create or replace function public.tg_daftar_surat_sakit()
returns trigger language plpgsql security definer set search_path = public as $$
begin perform public._daftar_surat_sakit(new.id); return null; end $$;
drop trigger if exists zz_registri on public.clinic_letters;
create trigger zz_registri after insert or update on public.clinic_letters
  for each row execute function public.tg_daftar_surat_sakit();

-- Data lama: daftarkan sekali
do $$ declare x uuid; begin
  for x in select id from leave_requests where kode_validasi is not null loop perform public._daftar_pengajuan(x); end loop;
  for x in select id from clinic_letters loop perform public._daftar_surat_sakit(x); end loop;
end $$;

-- ---------------------------------------------------------------------
-- 5. CEK KEABSAHAN (publik, tanpa masuk)
-- ---------------------------------------------------------------------
create or replace function public.cek_dokumen(p_kode text)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare k text := upper(regexp_replace(coalesce(p_kode, ''), '[^A-Za-z0-9]', '', 'g')); d document_registry; v_lembaga text;
begin
  -- Huruf yang mudah tertukar diseragamkan (O→0 tidak dipakai, jadi tidak ada padanan; I/L/1 juga tidak dipakai)
  if length(k) <> 8 then return jsonb_build_object('ditemukan', false, 'kode', p_kode); end if;
  k := substr(k, 1, 4) || '-' || substr(k, 5, 4);
  select * into d from document_registry where kode = k;
  select coalesce(nilai->>'nama_lengkap', nilai->>'nama') into v_lembaga from institution_settings where kunci = 'identitas';
  if not found or d.id is null then return jsonb_build_object('ditemukan', false, 'kode', k, 'lembaga', v_lembaga); end if;
  update document_registry set jumlah_cek = jumlah_cek + 1, terakhir_dicek = now() where id = d.id;
  return jsonb_build_object(
    'ditemukan', true, 'kode', d.kode, 'jenis', d.jenis, 'jenis_nama', d.jenis_nama, 'nomor', d.nomor, 'perihal', d.perihal,
    'subjek', d.subjek, 'periode', d.periode, 'status', d.status, 'diterbitkan_pada', d.diterbitkan_pada,
    'dicabut_pada', d.dicabut_pada, 'alasan_cabut', d.alasan_cabut,
    'pengganti', (select x.kode from document_registry x where x.id = d.pengganti_id),
    'sidik', substr(d.sidik, 1, 16), 'lembaga', v_lembaga,
    'penanda', coalesce((select jsonb_agg(jsonb_build_object('nama', s.nama, 'jabatan', s.jabatan, 'status', s.status, 'waktu', s.waktu)
                                          order by case s.posisi when 'kiri' then 0 else 1 end, s.urutan)
                           from document_signatures s where s.document_id = d.id and s.status = 'ditandatangani'), '[]'::jsonb));
end $$;
revoke execute on function public.cek_dokumen(text) from public;
grant execute on function public.cek_dokumen(text) to anon, authenticated;

-- ---------------------------------------------------------------------
-- 6. CABUT DOKUMEN (superadmin)
-- ---------------------------------------------------------------------
create or replace function public.cabut_dokumen(p_id uuid, p_alasan text)
returns void language plpgsql volatile security definer set search_path = public as $$
declare d document_registry;
begin
  if not public.is_superadmin() then raise exception 'Hanya superadmin yang dapat mencabut dokumen.' using errcode = '42501'; end if;
  if length(trim(coalesce(p_alasan, ''))) < 5 then raise exception 'Alasan pencabutan wajib diisi (paling sedikit 5 karakter).'; end if;
  select * into d from document_registry where id = p_id for update;
  if not found then raise exception 'Dokumen tidak ditemukan.'; end if;
  if d.status = 'dicabut' then raise exception 'Dokumen sudah dicabut.'; end if;
  if d.ref_tabel = 'leave_requests' then
    raise exception 'Surat pengajuan dicabut dengan membatalkan pengajuannya di menu Pengajuan.';
  end if;
  update document_registry set status = 'dicabut', dicabut_pada = now(), dicabut_oleh = public.saya(), alasan_cabut = trim(p_alasan) where id = p_id;
end $$;
revoke execute on function public.cabut_dokumen(uuid, text) from public, anon;
grant execute on function public.cabut_dokumen(uuid, text) to authenticated;

do $$ declare f text; begin
  foreach f in array array['_kode_dokumen()','_kode_validasi()','_daftar_pengajuan(uuid)','_daftar_surat_sakit(uuid)','_sidik(jsonb)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 7. PEMERIKSAAN (hasil yang benar: baris 1–4 "Sesuai"; baris 5 jumlah dokumen lama yang terdaftar)
-- ---------------------------------------------------------------------
select '1. Tabel registri dokumen' as pemeriksaan,
       case when to_regclass('public.document_registry') is not null and to_regclass('public.document_signatures') is not null then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Pemicu surat pengajuan dan surat sakit',
       case when (select count(*) from pg_trigger where tgname = 'zz_registri') = 2 then 'Sesuai' else 'Periksa' end
union all
select '3. Cek keabsahan dapat dibuka tanpa masuk',
       case when has_function_privilege('anon', 'public.cek_dokumen(text)', 'execute') then 'Sesuai' else 'Periksa' end
union all
select '4. Semua surat lama terdaftar',
       case when (select count(*) from leave_requests where kode_validasi is not null) + (select count(*) from clinic_letters)
                 <= (select count(*) from document_registry) then 'Sesuai' else 'Periksa' end
union all
select '5. Jumlah dokumen terdaftar', (select count(*)::text || ' dokumen' from document_registry);
