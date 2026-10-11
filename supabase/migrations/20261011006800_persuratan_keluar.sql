-- SIMKA PRO | supabase/migrations/20261011006800_persuratan_keluar.sql | v1.1 | Fase 10 – Tahap 2 Template surat dan surat keluar; semua surat melalui Tata Usaha | 11/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 10 · Migrasi 68: Persuratan – template surat dan surat keluar (Blueprint Bagian 35)
--   * letter_templates  : template surat sistem (bukan Word): kode perihal, format nomor (surat/SK), D/K, kop, bentuk kepala
--                         (judul di tengah atau nomor/hal di kiri), judul, isi berisian {kunci}, daftar isian (teks, tanggal, jam,
--                         pegawai, santri, daftar, daftar pegawai), salam/basmalah/hamdalah/doa (huruf Latin, dicetak miring), tembusan,
--                         narahubung, "Ditetapkan di" (SK), penanda tangan bawaan. 13 template isi awal (11 dari pedoman
--                         persuratan Wahdah Islamiyah + Keterangan Aktif Santri + Keterangan Berkelakuan Baik); dapat disunting,
--                         disalin, dan ditambah oleh Tata Usaha.
--   * outgoing_letters  : surat keluar. SEMUA SURAT MELALUI TATA USAHA: TU menyusun surat (boleh atas permintaan pegawai/pimpinan, kolom
--                         pemohon) atau pimpinan menyusun draf lalu mengirimnya ke TU; hanya TU yang mengajukan tanda tangan dan
--                         menerbitkan nomor. Alur: draf (penyusun) → [Kepala Bidang: kirim ke TU → diperiksa] → TU mengajukan tanda tangan
--                         (elektronik atau basah) → penanda tangan menandatangani di Dokumen → Tanda tangan → SAH: nomor surat
--                         diambil otomatis saat itu (fungsi ambil_nomor; SK berurutan sendiri) → terbit, tercatat di buku agenda
--                         surat keluar dan registri dokumen (kode validasi + QR, halaman Cek Keabsahan).
--   * Salinan beku isi surat disimpan di registri dokumen saat diajukan; tanggal Hijriah dibekukan dari server.
-- Jalankan SETELAH migrasi 6700. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TABEL
-- ---------------------------------------------------------------------
create table if not exists public.letter_templates (
  id             uuid primary key default gen_random_uuid(),
  kode           text not null unique check (kode ~ '^[a-z0-9_]{3,40}$'),
  nama           text not null,
  kategori       text not null default 'umum' check (kategori in ('umum','pegawai','santri')),
  perihal_kode   text not null default 'NZ' references public.letter_subject_codes(kode) on update cascade,
  format_nomor   text not null default 'surat' references public.doc_number_formats(kode) on update cascade,
  dk             text not null default 'D' check (dk in ('D','K')),
  kop_kode       text not null default 'pondok',
  bentuk         text not null default 'kiri' check (bentuk in ('kiri','tengah')),
  judul          text,
  subjudul       text,
  hal_bawaan     text,
  kepada_bawaan  text,
  opsi           jsonb not null default '{}'::jsonb,
  isi            text not null default '',
  isian          jsonb not null default '[]'::jsonb,
  penanda        jsonb not null default '[{"jabatan":"Direktur"}]'::jsonb,
  aktif          boolean not null default true,
  bawaan         boolean not null default false,
  urutan         int not null default 0,
  dibuat_oleh    uuid references public.employees(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create table if not exists public.outgoing_letters (
  id              uuid primary key default gen_random_uuid(),
  template_id     uuid references public.letter_templates(id) on delete set null,
  jenis_nama      text not null,
  kategori        text not null default 'umum',
  kop_kode        text not null default 'pondok',
  dk              text not null default 'D' check (dk in ('D','K')),
  perihal_kode    text not null default 'NZ',
  format_nomor    text not null default 'surat',
  tanggal_surat   date not null default public.hari_ini(),
  tanggal_hijriah text,
  perihal         text not null,
  kepada          text,
  lampiran        text,
  tembusan        text[] not null default '{}',
  narahubung      text,
  nilai           jsonb not null default '{}'::jsonb,
  tampilan        jsonb not null default '{}'::jsonb,
  penanda         jsonb not null default '[]'::jsonb,
  mode_ttd        text not null default 'elektronik' check (mode_ttd in ('elektronik','basah')),
  nomor           text,
  status          text not null default 'draf' check (status in ('draf','diperiksa','menunggu_ttd','terbit','ditolak','dibatalkan','dicabut')),
  document_id     uuid references public.document_registry(id) on delete set null,
  catatan         text,
  berkas_arsip_id uuid references public.storage_objects(id) on delete set null,
  disusun_oleh    uuid references public.employees(id) on delete set null,
  pemohon_id      uuid references public.employees(id) on delete set null,
  diajukan_oleh   uuid references public.employees(id) on delete set null,
  diajukan_pada   timestamptz,
  terbit_pada     timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index if not exists ol_tanggal_idx on public.outgoing_letters (tanggal_surat desc);
create index if not exists ol_status_idx on public.outgoing_letters (status, disusun_oleh);
create index if not exists ol_doc_idx on public.outgoing_letters (document_id);
alter table public.outgoing_letters add column if not exists pemohon_id uuid references public.employees(id) on delete set null;

drop trigger if exists aa_updated on public.letter_templates;
create trigger aa_updated before update on public.letter_templates for each row execute function public.tg_updated_at();
drop trigger if exists aa_updated on public.outgoing_letters;
create trigger aa_updated before update on public.outgoing_letters for each row execute function public.tg_updated_at();
drop trigger if exists zz_audit on public.letter_templates;
create trigger zz_audit after insert or update or delete on public.letter_templates for each row execute function public.tg_audit();
drop trigger if exists zz_audit on public.outgoing_letters;
create trigger zz_audit after insert or update or delete on public.outgoing_letters for each row execute function public.tg_audit();

-- ---------------------------------------------------------------------
-- 2. HAK
-- ---------------------------------------------------------------------
/** Penyusun surat keluar: pengelola persuratan (TU) dan pimpinan (Yayasan, Direktur, Wadir, Kepala Bidang, termasuk Plt). */
create or replace function public.boleh_susun_surat()
returns boolean language sql stable security definer set search_path = public as $$
  select public.boleh_kelola_persuratan() or public.saya() in (select employee_id from public._pimpinan_surat())
$$;

create or replace function public.boleh_baca_surat_keluar(p_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.boleh_kelola_persuratan()
      or exists (select 1 from outgoing_letters o where o.id = p_id and (o.disusun_oleh = public.saya() or o.pemohon_id = public.saya()
                 or exists (select 1 from jsonb_array_elements(o.penanda) x where (x->>'employee_id')::uuid = public.saya())
                 or (o.status in ('terbit','dicabut') and public.saya() in (select public._puncak_surat()))))
$$;

alter table public.letter_templates enable row level security;
alter table public.outgoing_letters enable row level security;
drop policy if exists baca on public.letter_templates;
create policy baca on public.letter_templates for select to authenticated using (aktif or public.boleh_kelola_persuratan());
drop policy if exists baca on public.outgoing_letters;
create policy baca on public.outgoing_letters for select to authenticated using (public.boleh_baca_surat_keluar(id));
grant select on public.letter_templates, public.outgoing_letters to authenticated;

create or replace function public.hak_persuratan()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'kelola', public.boleh_kelola_persuratan(),
    'superadmin', public.is_superadmin(),
    'pimpinan', public.saya() in (select employee_id from public._pimpinan_surat()),
    'puncak', public.saya() in (select public._puncak_surat()),
    'susun', public.boleh_susun_surat(),
    'tampil', public.boleh_susun_surat()
              or exists (select 1 from letter_dispositions where kepada_id = public.saya())
              or exists (select 1 from incoming_letters where tujuan_id = public.saya())
              or exists (select 1 from outgoing_letters o, jsonb_array_elements(o.penanda) x where (x->>'employee_id')::uuid = public.saya()),
    'pengaturan', public.pengaturan_persuratan())
$$;

-- ---------------------------------------------------------------------
-- 3. KONTEKS PENYUSUNAN: identitas lembaga, tahun ajaran, penanda tangan, cari santri
-- ---------------------------------------------------------------------
create or replace function public.konteks_surat()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'lembaga', coalesce(i.nilai->>'nama_lengkap', ''), 'alamat', coalesce(i.nilai->>'alamat', ''), 'npsn', coalesce(i.nilai->>'npsn', ''),
    'nspp', coalesce(i.nilai->>'nspp', ''), 'kota', coalesce(nullif(i.nilai->>'kota_surat', ''), 'Gowa'), 'telepon', coalesce(i.nilai->>'telepon', ''),
    'email', coalesce(i.nilai->>'email', ''),
    'tahun_ajaran', (select nama from academic_years where aktif limit 1),
    'hari_ini', public.hari_ini(), 'hijriah_hari_ini', (select teks from public.hijriah(public.hari_ini())))
    from (select (select nilai from institution_settings where kunci = 'identitas') nilai) i
   where public.saya() is not null
$$;

/** Penanda tangan dari Setelan → Penanda tangan (pemegang jabatan terkini), untuk dipilih pada surat keluar. */
create or replace function public.penanda_tangan_surat()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare r signatories; hasil jsonb := '[]'::jsonb;
begin
  if not public.boleh_susun_surat() then return hasil; end if;
  for r in select * from signatories where aktif order by urutan, jabatan_tertulis loop
    r := public._isi_penanda_tangan(r);
    hasil := hasil || jsonb_build_object('id', r.id, 'jabatan', r.jabatan_tertulis, 'nama', r.nama, 'niy', r.niy, 'employee_id', r.employee_id);
  end loop;
  return hasil;
end $$;

/** Cari santri aktif untuk isian surat (SK aktif, SKBB, SKL, dst.). Hanya penyusun surat. */
create or replace function public.santri_untuk_surat(p_cari text)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(x order by x->>'nama'), '[]'::jsonb) from (
    select jsonb_build_object('id', s.id, 'nama', s.nama_lengkap, 'nis', s.nis, 'nisn', s.nisn, 'jk', s.jenis_kelamin,
      'tempat_lahir', s.tempat_lahir, 'tanggal_lahir', s.tanggal_lahir, 'jenjang', s.jenjang, 'tingkat', s.tingkat, 'alamat', s.alamat,
      'status', s.status, 'tanggal_masuk', s.tanggal_masuk, 'kelas', public._kelompok_santri(s.id, 'kelas'),
      'wali', coalesce((select c.nama from student_contacts c where c.student_id = s.id and c.nama is not null
                         order by case c.hubungan when 'ayah' then 1 when 'wali' then 2 else 3 end limit 1), '')) x
      from students s
     where public.boleh_susun_surat() and length(trim(coalesce(p_cari, ''))) >= 2
       and (s.nama_lengkap ilike '%' || trim(p_cari) || '%' or s.nis like trim(p_cari) || '%' or s.nisn like trim(p_cari) || '%')
     limit 30) q
$$;

-- ---------------------------------------------------------------------
-- 4. TEMPLATE SURAT
-- ---------------------------------------------------------------------
create or replace function public.simpan_template_surat(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid := nullif(p->>'id', '')::uuid; v_kode text := lower(trim(coalesce(p->>'kode', ''))); e jsonb; v_kunci text[] := '{}';
begin
  if not public.boleh_kelola_persuratan() then raise exception 'Hanya Tata Usaha atau pengelola persuratan yang dapat mengubah template surat.' using errcode = '42501'; end if;
  if v_kode !~ '^[a-z0-9_]{3,40}$' then raise exception 'Kode template hanya huruf kecil, angka, dan garis bawah (3–40 karakter).'; end if;
  if length(trim(coalesce(p->>'nama', ''))) < 3 then raise exception 'Isi nama template.'; end if;
  if not exists (select 1 from letter_subject_codes where kode = p->>'perihal_kode') then raise exception 'Kode perihal belum terdaftar.'; end if;
  if not exists (select 1 from doc_number_formats where kode = p->>'format_nomor' and aktif) then raise exception 'Format nomor tidak dikenal.'; end if;
  if not exists (select 1 from letterheads where kode = p->>'kop_kode') then raise exception 'Kop surat tidak dikenal.'; end if;
  if length(trim(coalesce(p->>'isi', ''))) < 10 then raise exception 'Isi template masih kosong.'; end if;
  if jsonb_typeof(coalesce(p->'isian', '[]')) <> 'array' or jsonb_typeof(coalesce(p->'penanda', '[]')) <> 'array' then raise exception 'Susunan isian/penanda tangan tidak sah.'; end if;
  if jsonb_array_length(coalesce(p->'penanda', '[]')) not between 1 and 2 then raise exception 'Penanda tangan surat satu atau dua orang.'; end if;
  for e in select * from jsonb_array_elements(coalesce(p->'isian', '[]')) loop
    if coalesce(e->>'kunci', '') !~ '^[a-z][a-z0-9_]{0,30}$' then raise exception 'Kunci isian "%" tidak sah (huruf kecil, angka, garis bawah).', e->>'kunci'; end if;
    if e->>'kunci' = any(v_kunci) then raise exception 'Kunci isian "%" dipakai dua kali.', e->>'kunci'; end if;
    if coalesce(e->>'jenis', 'teks') not in ('teks','panjang','tanggal','hari_tanggal','jam','angka','pegawai','santri','daftar','daftar_pegawai') then
      raise exception 'Jenis isian "%" tidak dikenal.', e->>'jenis'; end if;
    v_kunci := v_kunci || (e->>'kunci');
  end loop;
  if v_id is null then
    insert into letter_templates (kode, nama, kategori, perihal_kode, format_nomor, dk, kop_kode, bentuk, judul, subjudul, hal_bawaan, kepada_bawaan, opsi, isi, isian,
                                  penanda, aktif, urutan, dibuat_oleh)
    values (v_kode, trim(p->>'nama'), coalesce(nullif(p->>'kategori', ''), 'umum'), p->>'perihal_kode', p->>'format_nomor', coalesce(nullif(p->>'dk', ''), 'D'),
            p->>'kop_kode', coalesce(nullif(p->>'bentuk', ''), 'kiri'), nullif(trim(p->>'judul'), ''), nullif(trim(p->>'subjudul'), ''),
            nullif(trim(p->>'hal_bawaan'), ''), nullif(trim(p->>'kepada_bawaan'), ''), coalesce(p->'opsi', '{}'), p->>'isi', coalesce(p->'isian', '[]'),
            coalesce(p->'penanda', '[{"jabatan":"Direktur"}]'), coalesce((p->>'aktif')::boolean, true),
            coalesce((p->>'urutan')::int, (select coalesce(max(urutan), 0) + 1 from letter_templates)), public.saya())
    returning id into v_id;
  else
    update letter_templates set kode = v_kode, nama = trim(p->>'nama'), kategori = coalesce(nullif(p->>'kategori', ''), 'umum'), perihal_kode = p->>'perihal_kode',
           format_nomor = p->>'format_nomor', dk = coalesce(nullif(p->>'dk', ''), 'D'), kop_kode = p->>'kop_kode', bentuk = coalesce(nullif(p->>'bentuk', ''), 'kiri'),
           judul = nullif(trim(p->>'judul'), ''), subjudul = nullif(trim(p->>'subjudul'), ''), hal_bawaan = nullif(trim(p->>'hal_bawaan'), ''),
           kepada_bawaan = nullif(trim(p->>'kepada_bawaan'), ''), opsi = coalesce(p->'opsi', '{}'), isi = p->>'isi', isian = coalesce(p->'isian', '[]'),
           penanda = coalesce(p->'penanda', penanda), aktif = coalesce((p->>'aktif')::boolean, aktif)
     where id = v_id;
    if not found then raise exception 'Template tidak ditemukan.'; end if;
  end if;
  return v_id;
exception when unique_violation then raise exception 'Kode template "%" sudah dipakai.', v_kode;
end $$;

create or replace function public.hapus_template_surat(p_id uuid)
returns text language plpgsql volatile security definer set search_path = public as $$
begin
  if not public.boleh_kelola_persuratan() then raise exception 'Anda tidak berwenang menghapus template.' using errcode = '42501'; end if;
  if exists (select 1 from outgoing_letters where template_id = p_id) or exists (select 1 from letter_templates where id = p_id and bawaan) then
    update letter_templates set aktif = false where id = p_id; return 'nonaktif';
  end if;
  delete from letter_templates where id = p_id; return 'hapus';
end $$;

-- ---------------------------------------------------------------------
-- 5. SURAT KELUAR: simpan draf, kirim ke TU, ajukan tanda tangan, batalkan, arsip
-- ---------------------------------------------------------------------
create or replace function public._penanda_sah(p jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare e jsonb; hasil jsonb := '[]'::jsonb; st signatories; v_emp uuid; v_nama text; v_niy text; i int := 0;
begin
  if jsonb_typeof(coalesce(p, '[]')) <> 'array' or jsonb_array_length(coalesce(p, '[]')) not between 1 and 2 then
    raise exception 'Pilih satu atau dua penanda tangan surat.'; end if;
  for e in select * from jsonb_array_elements(p) loop
    i := i + 1; v_emp := null; v_nama := null; v_niy := null;
    if nullif(e->>'signatory_id', '') is not null then
      select * into st from signatories where id = (e->>'signatory_id')::uuid and aktif;
      if st.id is null then raise exception 'Penanda tangan ke-% tidak aktif lagi. Pilih ulang.', i; end if;
      st := public._isi_penanda_tangan(st); v_emp := st.employee_id; v_nama := st.nama; v_niy := st.niy;
    elsif nullif(e->>'employee_id', '') is not null then
      select id, nama_lengkap, niy into v_emp, v_nama, v_niy from employees where id = (e->>'employee_id')::uuid and status_akun = 'aktif';
      if v_emp is null then raise exception 'Penanda tangan ke-% harus pegawai berakun aktif.', i; end if;
    else raise exception 'Penanda tangan ke-% belum dipilih.', i;
    end if;
    if length(trim(coalesce(e->>'jabatan', ''))) < 3 then raise exception 'Isi jabatan penanda tangan ke-%.', i; end if;
    hasil := hasil || jsonb_build_object('posisi', case when jsonb_array_length(p) = 1 then 'kanan' when i = 1 then 'kiri' else 'kanan' end,
      'signatory_id', nullif(e->>'signatory_id', ''), 'employee_id', v_emp, 'nama', v_nama, 'niy', v_niy, 'jabatan', trim(e->>'jabatan'),
      'pengantar', nullif(trim(e->>'pengantar'), ''), 'an', nullif(trim(e->>'an'), ''));
  end loop;
  return hasil;
end $$;

/** p: {id?, template_id, kop_kode, dk, tanggal_surat, perihal, kepada, lampiran, tembusan[], narahubung, nilai{}, tampilan{}, penanda[]} */
create or replace function public.simpan_surat_keluar(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid := nullif(p->>'id', '')::uuid; o outgoing_letters%rowtype; t letter_templates%rowtype; v_kelola boolean := public.boleh_kelola_persuratan();
        v_pen jsonb; v_tem text[]; v_pemohon uuid;
begin
  if not public.boleh_susun_surat() then raise exception 'Hanya Tata Usaha dan pimpinan yang dapat menyusun surat keluar.' using errcode = '42501'; end if;
  select * into t from letter_templates where id = nullif(p->>'template_id', '')::uuid;
  if t.id is null then raise exception 'Pilih template surat.'; end if;
  if length(trim(coalesce(p->>'perihal', ''))) < 3 then raise exception 'Isi perihal surat.'; end if;
  if not exists (select 1 from letterheads where kode = coalesce(nullif(p->>'kop_kode', ''), t.kop_kode)) then raise exception 'Kop surat tidak dikenal.'; end if;
  if pg_column_size(p) > 1024 * 1024 then raise exception 'Isi surat terlalu panjang.'; end if;
  v_pen := public._penanda_sah(p->'penanda');
  -- Pemohon: TU mengisi pegawai yang meminta surat; draf pimpinan otomatis atas namanya sendiri
  v_pemohon := case when v_kelola then nullif(p->>'pemohon_id', '')::uuid else public.saya() end;
  if v_pemohon is not null and not exists (select 1 from employees where id = v_pemohon) then raise exception 'Pemohon surat tidak dikenal.'; end if;
  select coalesce(array_agg(trim(x)) filter (where trim(x) <> ''), '{}') into v_tem from jsonb_array_elements_text(coalesce(p->'tembusan', '[]')) x;
  if v_id is not null then
    select * into o from outgoing_letters where id = v_id for update;
    if o.id is null then raise exception 'Surat tidak ditemukan.'; end if;
    if not (o.disusun_oleh = public.saya() or v_kelola) then raise exception 'Hanya penyusun atau Tata Usaha yang dapat mengubah surat ini.' using errcode = '42501'; end if;
    if o.status not in ('draf','ditolak','diperiksa') or (o.status = 'diperiksa' and not v_kelola) then
      raise exception 'Surat yang sedang diajukan atau sudah terbit tidak dapat diubah.'; end if;
    update outgoing_letters set template_id = t.id, jenis_nama = t.nama, kategori = t.kategori, kop_kode = coalesce(nullif(p->>'kop_kode', ''), t.kop_kode),
           dk = coalesce(nullif(p->>'dk', ''), t.dk), perihal_kode = t.perihal_kode, format_nomor = t.format_nomor,
           tanggal_surat = coalesce(nullif(p->>'tanggal_surat', '')::date, public.hari_ini()), perihal = trim(p->>'perihal'),
           kepada = nullif(trim(p->>'kepada'), ''), lampiran = nullif(trim(p->>'lampiran'), ''), tembusan = v_tem, narahubung = nullif(trim(p->>'narahubung'), ''),
           nilai = coalesce(p->'nilai', '{}'), tampilan = coalesce(p->'tampilan', '{}'), penanda = v_pen,
           pemohon_id = case when v_kelola then v_pemohon else coalesce(pemohon_id, v_pemohon) end,
           status = case when o.status = 'ditolak' then 'draf' else o.status end
     where id = v_id;
  else
    insert into outgoing_letters (template_id, jenis_nama, kategori, kop_kode, dk, perihal_kode, format_nomor, tanggal_surat, perihal, kepada, lampiran, tembusan,
                                  narahubung, nilai, tampilan, penanda, disusun_oleh, pemohon_id)
    values (t.id, t.nama, t.kategori, coalesce(nullif(p->>'kop_kode', ''), t.kop_kode), coalesce(nullif(p->>'dk', ''), t.dk), t.perihal_kode, t.format_nomor,
            coalesce(nullif(p->>'tanggal_surat', '')::date, public.hari_ini()), trim(p->>'perihal'), nullif(trim(p->>'kepada'), ''), nullif(trim(p->>'lampiran'), ''),
            v_tem, nullif(trim(p->>'narahubung'), ''), coalesce(p->'nilai', '{}'), coalesce(p->'tampilan', '{}'), v_pen, public.saya(), v_pemohon)
    returning id into v_id;
  end if;
  return v_id;
end $$;

/** Penerima pemberitahuan pemeriksaan surat: pemegang jabatan Tata Usaha dan admin ber-izin kelola_persuratan. */
create or replace function public._pengelola_surat()
returns setof uuid language sql stable security definer set search_path = public as $$
  select e.id from employees e join employee_structurals es on es.employee_id = e.id join structural_positions sp on sp.id = es.structural_position_id
   where sp.kode = 'TATA_USAHA' and e.status_akun = 'aktif' and e.status_keaktifan = 'aktif'
  union select e.id from employees e join admin_permissions ap on ap.employee_id = e.id and ap.kode = 'kelola_persuratan' where e.status_akun = 'aktif' and e.peran = 'admin'
$$;

create or replace function public.kirim_surat_ke_tu(p_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare o outgoing_letters%rowtype; v_nama text;
begin
  select * into o from outgoing_letters where id = p_id for update;
  if o.id is null then raise exception 'Surat tidak ditemukan.'; end if;
  if o.disusun_oleh <> public.saya() then raise exception 'Hanya penyusun yang dapat mengirim surat ini ke Tata Usaha.' using errcode = '42501'; end if;
  if o.status not in ('draf','ditolak') then raise exception 'Surat ini sudah dikirim atau diajukan.'; end if;
  update outgoing_letters set status = 'diperiksa', catatan = null where id = p_id;
  select nama_lengkap into v_nama from employees where id = public.saya();
  insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
  select x, 'Draf surat keluar perlu diperiksa', coalesce(v_nama, 'Pimpinan') || ': ' || o.jenis_nama || ' – ' || o.perihal, '/persuratan/keluar?surat=' || p_id, 'NotePencil', 'jingga'
    from public._pengelola_surat() x where x <> public.saya();
end $$;

/** Nomor surat keluar diambil saat surat sah (atau saat diajukan dengan tanda tangan basah). */
create or replace function public._nomor_surat_keluar(p_id uuid)
returns text language plpgsql volatile security definer set search_path = public as $$
declare o outgoing_letters%rowtype; v jsonb; v_lama text := current_setting('simka.nomor_sistem', true);
begin
  select * into o from outgoing_letters where id = p_id for update;
  if o.nomor is not null then return o.nomor; end if;
  perform set_config('simka.nomor_sistem', '1', true);
  v := public.ambil_nomor(o.format_nomor, o.tanggal_surat, o.dk, o.perihal_kode, o.kop_kode);
  perform set_config('simka.nomor_sistem', coalesce(v_lama, ''), true);
  update outgoing_letters set nomor = v->>'nomor', status = 'terbit', terbit_pada = now() where id = p_id;
  return v->>'nomor';
end $$;

/** TU mengajukan tanda tangan. p_isi = salinan beku tampilan surat dari aplikasi; p_mode elektronik|basah. */
create or replace function public.ajukan_surat_keluar(p_id uuid, p_mode text, p_isi jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare o outgoing_letters%rowtype; v_doc uuid; v_kode text; v_status text; e jsonb; v_sisa int := 0; v_hijri text; v_nomor text; v_saya_nama text; i int := 0;
begin
  if not public.boleh_kelola_persuratan() then raise exception 'Hanya Tata Usaha atau pengelola persuratan yang dapat mengajukan tanda tangan surat.' using errcode = '42501'; end if;
  if p_mode not in ('elektronik','basah') then raise exception 'Mode tanda tangan tidak dikenal.'; end if;
  select * into o from outgoing_letters where id = p_id for update;
  if o.id is null then raise exception 'Surat tidak ditemukan.'; end if;
  if o.status not in ('draf','diperiksa','ditolak') then raise exception 'Surat ini sudah diajukan atau terbit.'; end if;
  if p_isi is null or jsonb_typeof(p_isi) <> 'object' then raise exception 'Isi surat kosong.'; end if;
  if jsonb_array_length(o.penanda) = 0 then raise exception 'Pilih penanda tangan surat.'; end if;
  if p_mode = 'elektronik' then
    for e in select * from jsonb_array_elements(o.penanda) loop
      if nullif(e->>'employee_id', '') is null then
        raise exception 'Penanda tangan % belum terhubung dengan akun pegawai. Hubungkan di Setelan → Penanda tangan, atau pilih tanda tangan basah.', e->>'jabatan'; end if;
    end loop;
  end if;
  select teks into v_hijri from public.hijriah(o.tanggal_surat);
  select nama_lengkap into v_saya_nama from employees where id = public.saya();
  -- registri lama surat ini (ditolak/dicabut) dilepas agar surat dapat diajukan ulang
  update document_registry set ref_id = null where ref_tabel = 'outgoing_letters' and ref_id = p_id and status <> 'sah';
  v_kode := public._kode_dokumen();
  insert into document_registry (kode, jenis, jenis_nama, perihal, subjek, periode, kop_kode, status, sidik, ref_tabel, ref_id, diterbitkan_pada, diterbitkan_oleh,
                                 isi, kunci, tautan, mode_ttd, diajukan_pada)
  values (v_kode, 'surat_keluar', o.jenis_nama, left(o.perihal, 300), left(o.kepada, 300), to_char(o.tanggal_surat, 'DD/MM/YYYY'), o.kop_kode, 'draf',
          public._sidik(p_isi), 'outgoing_letters', p_id, now(), public.saya(), p_isi || jsonb_build_object('tanggal_hijriah', v_hijri), 'surat_keluar:' || p_id, '/persuratan/keluar', p_mode, now())
  returning id into v_doc;
  for e in select * from jsonb_array_elements(o.penanda) loop
    i := i + 1;
    insert into document_signatures (document_id, urutan, posisi, employee_id, nama, jabatan, niy, status, waktu, catatan)
    values (v_doc, i, coalesce(e->>'posisi', 'kanan'), nullif(e->>'employee_id', '')::uuid, coalesce(e->>'nama', '–'), e->>'jabatan', e->>'niy',
            case when p_mode = 'basah' or (e->>'employee_id')::uuid = public.saya() then 'ditandatangani' else 'menunggu' end,
            case when p_mode = 'elektronik' and (e->>'employee_id')::uuid = public.saya() then now() end,
            case when p_mode = 'basah' then 'basah' end);
  end loop;
  select count(*) into v_sisa from document_signatures where document_id = v_doc and status = 'menunggu';
  update outgoing_letters set status = 'menunggu_ttd', mode_ttd = p_mode, document_id = v_doc, tanggal_hijriah = v_hijri, diajukan_oleh = public.saya(),
         diajukan_pada = now(), catatan = null where id = p_id;
  if v_sisa = 0 then
    update document_registry set status = 'sah', diterbitkan_pada = now() where id = v_doc;   -- pemicu mengambil nomor
    select nomor into v_nomor from outgoing_letters where id = p_id;
    v_status := 'terbit';
  else
    insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
    select s.employee_id, 'Permintaan tanda tangan surat', coalesce(v_saya_nama, 'Tata Usaha') || ' meminta tanda tangan elektronik untuk ' || o.jenis_nama || ': ' || left(o.perihal, 120) || '.',
           '/persuratan/keluar?resmi=' || v_doc, 'Signature', 'ungu'
      from document_signatures s where s.document_id = v_doc and s.status = 'menunggu';
    v_status := 'menunggu_ttd';
  end if;
  insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
  select distinct x, case when v_status = 'terbit' then 'Surat keluar terbit' else 'Surat keluar diajukan untuk tanda tangan' end,
         o.jenis_nama || ' – ' || o.perihal || coalesce(' (' || v_nomor || ')', ''), '/persuratan/keluar?surat=' || p_id, 'EnvelopeSimple', 'biru'
    from unnest(array[o.disusun_oleh, o.pemohon_id]) x where x is not null and x <> public.saya() and (v_status = 'terbit' or x = o.disusun_oleh);
  return jsonb_build_object('status', v_status, 'kode', v_kode, 'nomor', v_nomor, 'document_id', v_doc);
end $$;

/** Pemicu registri: surat keluar sah → nomor diambil; ditolak → kembali ke penyusun; dicabut → dibatalkan/dicabut. */
create or replace function public.tg_registri_surat_keluar()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_nomor text; o outgoing_letters%rowtype;
begin
  if new.jenis <> 'surat_keluar' or new.ref_id is null or new.status is not distinct from old.status then return new; end if;
  select * into o from outgoing_letters where id = new.ref_id;
  if o.id is null then return new; end if;
  if new.status = 'sah' then
    v_nomor := public._nomor_surat_keluar(o.id);
    new.nomor := v_nomor;
    new.isi := coalesce(new.isi, '{}'::jsonb) || jsonb_build_object('nomor', v_nomor);
    insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
    select distinct x, 'Surat keluar telah sah', o.jenis_nama || ' – ' || o.perihal || ' (' || v_nomor || ')', '/persuratan/keluar?surat=' || o.id, 'SealCheck', 'hijau'
      from unnest(array[o.disusun_oleh, o.pemohon_id]) x where x is not null and x <> new.diterbitkan_oleh;
  elsif new.status = 'ditolak' then
    update outgoing_letters set status = 'ditolak', catatan = new.catatan where id = o.id;
    if o.disusun_oleh is not null and o.disusun_oleh <> new.diterbitkan_oleh then
      perform public.kirim_notifikasi(o.disusun_oleh, 'Surat keluar ditolak penanda tangan', o.perihal || ': ' || left(coalesce(new.catatan, ''), 140),
        '/persuratan/keluar?surat=' || o.id, 'XCircle', 'merah');
    end if;
  elsif new.status = 'dicabut' then
    update outgoing_letters set status = case when old.status = 'sah' then 'dicabut' else case when status = 'dibatalkan' then status else 'dibatalkan' end end,
           catatan = coalesce(new.alasan_cabut, catatan) where id = o.id;
  end if;
  return new;
end $$;
drop trigger if exists ab_surat_keluar on public.document_registry;
create trigger ab_surat_keluar before update of status on public.document_registry for each row execute function public.tg_registri_surat_keluar();

create or replace function public.batalkan_surat_keluar(p_id uuid, p_alasan text)
returns void language plpgsql volatile security definer set search_path = public as $$
declare o outgoing_letters%rowtype;
begin
  select * into o from outgoing_letters where id = p_id for update;
  if o.id is null then raise exception 'Surat tidak ditemukan.'; end if;
  if not (o.disusun_oleh = public.saya() or public.boleh_kelola_persuratan()) then raise exception 'Hanya penyusun atau Tata Usaha yang dapat membatalkan surat ini.' using errcode = '42501'; end if;
  if o.status not in ('draf','diperiksa','ditolak','menunggu_ttd') then raise exception 'Surat yang sudah terbit hanya dapat dicabut superadmin melalui Dokumen → Dokumen resmi.'; end if;
  if length(trim(coalesce(p_alasan, ''))) < 5 then raise exception 'Tuliskan alasan pembatalan (minimal 5 huruf).'; end if;
  update outgoing_letters set status = 'dibatalkan', catatan = trim(p_alasan) where id = p_id;
  if o.document_id is not null then
    update document_registry set status = 'dicabut', dicabut_pada = now(), dicabut_oleh = public.saya(), alasan_cabut = trim(p_alasan)
     where id = o.document_id and status = 'draf';
    update notifications set dibaca_pada = coalesce(dibaca_pada, now()) where tautan = '/persuratan/keluar?resmi=' || o.document_id;
  end if;
end $$;

create or replace function public.simpan_arsip_surat_keluar(p_id uuid, p_berkas uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  if not public.boleh_kelola_persuratan() then raise exception 'Hanya Tata Usaha yang dapat mengunggah arsip surat.' using errcode = '42501'; end if;
  update outgoing_letters set berkas_arsip_id = p_berkas where id = p_id and status = 'terbit';
  if not found then raise exception 'Arsip hanya untuk surat yang sudah terbit.'; end if;
end $$;

-- ---------------------------------------------------------------------
-- 6. BACA: DAFTAR, RINCIAN, BUKU AGENDA, RINGKASAN
-- ---------------------------------------------------------------------
create or replace function public._surat_keluar_json(p_id uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', o.id, 'template_id', o.template_id, 'jenis_nama', o.jenis_nama, 'kategori', o.kategori, 'kop_kode', o.kop_kode, 'dk', o.dk,
    'perihal_kode', o.perihal_kode, 'format_nomor', o.format_nomor, 'tanggal_surat', o.tanggal_surat, 'tanggal_hijriah', o.tanggal_hijriah,
    'perihal', o.perihal, 'kepada', o.kepada, 'lampiran', o.lampiran, 'tembusan', to_jsonb(o.tembusan), 'narahubung', o.narahubung,
    'penanda', o.penanda, 'mode_ttd', o.mode_ttd, 'nomor', o.nomor, 'status', o.status, 'document_id', o.document_id, 'catatan', o.catatan,
    'berkas_arsip_id', o.berkas_arsip_id, 'disusun_oleh', de.nama_lengkap, 'disusun_oleh_id', o.disusun_oleh, 'saya_penyusun', o.disusun_oleh = public.saya(),
    'pemohon_id', o.pemohon_id, 'pemohon', (select nama_lengkap from employees where id = o.pemohon_id),
    'diajukan_pada', o.diajukan_pada, 'terbit_pada', o.terbit_pada, 'created_at', o.created_at, 'updated_at', o.updated_at,
    'kode_validasi', d.kode, 'status_dokumen', d.status,
    'menunggu_saya', exists (select 1 from document_signatures s where s.document_id = o.document_id and s.employee_id = public.saya() and s.status = 'menunggu')
                     and d.status = 'draf')
    from outgoing_letters o left join employees de on de.id = o.disusun_oleh left join document_registry d on d.id = o.document_id
   where o.id = p_id
$$;

create or replace function public.daftar_surat_keluar(p_mulai date default null, p_selesai date default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_mulai date := coalesce(p_mulai, public.hari_ini() - 90); v_selesai date := coalesce(p_selesai, public.hari_ini() + 365);
begin
  if public.saya() is null then return '[]'::jsonb; end if;
  return coalesce((select jsonb_agg(public._surat_keluar_json(o.id) order by
      case o.status when 'diperiksa' then 0 when 'menunggu_ttd' then 1 when 'ditolak' then 2 when 'draf' then 3 else 4 end, o.tanggal_surat desc, o.updated_at desc)
    from outgoing_letters o
   where public.boleh_baca_surat_keluar(o.id)
     and (o.tanggal_surat between v_mulai and v_selesai or o.status in ('draf','diperiksa','menunggu_ttd','ditolak'))
     and (o.status <> 'draf' or o.disusun_oleh = public.saya() or public.boleh_kelola_persuratan())), '[]'::jsonb);
end $$;

/** Rincian berdasarkan id surat atau id dokumen registri (tautan "Periksa" dari kotak Tanda tangan). */
create or replace function public.rincian_surat_keluar(p_id uuid default null, p_doc uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_id uuid := p_id; o outgoing_letters%rowtype; d document_registry%rowtype; v_kelola boolean := public.boleh_kelola_persuratan();
begin
  if v_id is null and p_doc is not null then
    select ref_id into v_id from document_registry where id = p_doc and jenis = 'surat_keluar';
    if v_id is null then select id into v_id from outgoing_letters where document_id = p_doc; end if;
  end if;
  select * into o from outgoing_letters where id = v_id;
  if o.id is null or not (public.boleh_baca_surat_keluar(o.id) or exists (select 1 from document_signatures s where s.document_id = coalesce(p_doc, o.document_id) and s.employee_id = public.saya())) then
    raise exception 'Surat tidak ditemukan atau Anda tidak berwenang membukanya.' using errcode = '42501'; end if;
  select * into d from document_registry where id = coalesce(p_doc, o.document_id);
  return public._surat_keluar_json(o.id) || jsonb_build_object(
    'nilai', o.nilai, 'tampilan', o.tampilan,
    'dokumen', case when d.id is null then null else jsonb_build_object('id', d.id, 'kode', d.kode, 'status', d.status, 'mode_ttd', d.mode_ttd, 'isi', d.isi,
       'nomor', d.nomor, 'catatan', d.catatan, 'diterbitkan_pada', d.diterbitkan_pada,
       'penanda', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'posisi', s.posisi, 'urutan', s.urutan, 'employee_id', s.employee_id, 'nama', s.nama,
          'jabatan', s.jabatan, 'niy', s.niy, 'status', s.status, 'waktu', s.waktu, 'catatan', s.catatan) order by s.urutan)
          from document_signatures s where s.document_id = d.id), '[]'::jsonb)) end,
    'boleh', jsonb_build_object(
      'ubah', o.status in ('draf','ditolak') and (o.disusun_oleh = public.saya() or v_kelola) or (o.status = 'diperiksa' and v_kelola),
      'kirim_tu', o.status in ('draf','ditolak') and o.disusun_oleh = public.saya() and not v_kelola,
      'ajukan', v_kelola and o.status in ('draf','diperiksa','ditolak'),
      'batal', o.status in ('draf','diperiksa','ditolak','menunggu_ttd') and (o.disusun_oleh = public.saya() or v_kelola),
      'arsip', v_kelola and o.status = 'terbit',
      'tanda_tangan', d.status = 'draf' and exists (select 1 from document_signatures s where s.document_id = d.id and s.employee_id = public.saya() and s.status = 'menunggu')));
end $$;

create or replace function public.buku_agenda_keluar(p_mulai date, p_selesai date)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not (public.boleh_kelola_persuratan() or public.saya() in (select public._puncak_surat())) then
    raise exception 'Buku agenda hanya dapat dibuka Tata Usaha dan pimpinan.' using errcode = '42501'; end if;
  if p_selesai < p_mulai then raise exception 'Rentang tanggal tidak sah.'; end if;
  if p_selesai - p_mulai > 400 then raise exception 'Rentang buku agenda paling lama satu tahun.'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('nomor', o.nomor, 'tanggal_surat', o.tanggal_surat, 'jenis_nama', o.jenis_nama, 'perihal', o.perihal,
      'kepada', o.kepada, 'penanda', (select string_agg(x->>'nama', '; ') from jsonb_array_elements(o.penanda) x), 'mode_ttd', o.mode_ttd,
      'status', o.status, 'kode_validasi', d.kode, 'disusun_oleh', de.nama_lengkap,
      'pemohon', (select nama_lengkap from employees where id = o.pemohon_id)) order by o.tanggal_surat, o.terbit_pada)
    from outgoing_letters o left join document_registry d on d.id = o.document_id left join employees de on de.id = o.disusun_oleh
   where o.status in ('terbit','dicabut') and o.tanggal_surat between p_mulai and p_selesai), '[]'::jsonb);
end $$;

create or replace function public.ringkasan_persuratan()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_awal date := date_trunc('month', public.hari_ini())::date; v_kelola boolean := public.boleh_kelola_persuratan();
begin
  if public.saya() is null then return '{}'::jsonb; end if;
  return jsonb_build_object(
    'perlu_tindakan_saya', (select count(*) from incoming_letters s where s.tujuan_id = public.saya() and s.status = 'diteruskan')
                           + (select count(*) from letter_dispositions d join incoming_letters s on s.id = d.letter_id where d.kepada_id = public.saya() and d.status <> 'selesai' and s.status <> 'batal'),
    'lewat_batas_saya', (select count(*) from letter_dispositions d where d.kepada_id = public.saya() and d.status <> 'selesai' and d.batas < public.hari_ini()),
    'masuk_bulan_ini', (select count(*) from incoming_letters s where s.tanggal_terima >= v_awal and s.status <> 'batal' and public.boleh_baca_surat(s.id)),
    'menunggu_disposisi', (select count(*) from incoming_letters s where s.status = 'diteruskan' and public.boleh_baca_surat(s.id)),
    'berjalan', (select count(*) from incoming_letters s where s.status = 'didisposisi' and public.boleh_baca_surat(s.id)),
    'lewat_batas', (select count(distinct d.letter_id) from letter_dispositions d where d.status <> 'selesai' and d.batas < public.hari_ini() and public.boleh_baca_surat(d.letter_id)),
    'selesai_bulan_ini', (select count(*) from incoming_letters s where s.status = 'selesai' and s.selesai_pada >= v_awal and public.boleh_baca_surat(s.id)),
    'keluar_diperiksa', case when v_kelola then (select count(*) from outgoing_letters where status = 'diperiksa') else 0 end,
    'keluar_menunggu_ttd', (select count(*) from outgoing_letters o where o.status = 'menunggu_ttd' and public.boleh_baca_surat_keluar(o.id)),
    'keluar_terbit_bulan_ini', (select count(*) from outgoing_letters o where o.status = 'terbit' and o.terbit_pada >= v_awal and public.boleh_baca_surat_keluar(o.id)),
    'ttd_saya', (select count(*) from document_signatures s join document_registry d on d.id = s.document_id
                  where s.employee_id = public.saya() and s.status = 'menunggu' and d.status = 'draf' and d.jenis = 'surat_keluar'),
    'kelola', v_kelola);
end $$;

-- ---------------------------------------------------------------------
-- 7. HAK LIHAT ARSIP PINDAIAN SURAT KELUAR (Edge Function "berkas")
-- ---------------------------------------------------------------------
do $$
declare d text := pg_get_functiondef('public.boleh_lihat_berkas(uuid,uuid)'::regprocedure);
  cabang text := $c$
  -- Arsip pindaian surat keluar bertanda tangan basah (Fase 10)
  if exists (select 1 from outgoing_letters ol where ol.berkas_arsip_id = p_obj) then
    v_sub := current_setting('request.jwt.claim.sub', true);
    perform set_config('request.jwt.claim.sub', coalesce((select user_id::text from employees where id = p_emp), ''), true);
    izin := exists (select 1 from outgoing_letters ol where ol.berkas_arsip_id = p_obj and public.boleh_baca_surat_keluar(ol.id));
    perform set_config('request.jwt.claim.sub', coalesce(v_sub, ''), true);
    if izin then return true; end if;
  end if;
  return false;
end $c$;
begin
  if position('outgoing_letters' in d) > 0 then return; end if;
  if d !~ E'\\n\\s*return false;\\s*\\nend' then raise exception 'boleh_lihat_berkas tidak dikenali; hubungi pengembang.'; end if;
  execute regexp_replace(d, E'\\n\\s*return false;\\s*\\nend', cabang);
end $$;

-- ---------------------------------------------------------------------
-- 8. TEMPLATE ISI AWAL (pedoman persuratan Wahdah Islamiyah; hanya isi awal, dapat disunting)
-- ---------------------------------------------------------------------
insert into public.letter_templates (kode, nama, kategori, perihal_kode, format_nomor, dk, kop_kode, bentuk, judul, subjudul, hal_bawaan, kepada_bawaan, opsi, isi, isian, penanda, bawaan, urutan) values
('undangan', 'Surat Undangan', 'umum', 'DW', 'surat', 'K', 'pondok', 'kiri', null, null, 'Undangan', null,
 '{"salam": true, "hamdalah": true, "salam_penutup": true, "tembusan": true, "narahubung": true}',
$t$Dengan memohon rahmat Allah _Subhanahu wa Ta'ala_, kami mengundang Bapak/Ibu/Saudara untuk menghadiri {acara} yang _insya Allah_ akan dilaksanakan pada:

Hari/tanggal : {hari_tanggal}
Waktu : {waktu} WITA s.d. selesai
Tempat : {tempat}
Agenda : {agenda}

Mengingat pentingnya acara tersebut, kami sangat mengharapkan kehadiran Bapak/Ibu/Saudara tepat waktu.

Demikian undangan ini kami sampaikan. Atas perhatian dan kehadirannya, kami ucapkan _jazakumullahu khairan_.$t$,
 '[{"kunci":"acara","label":"Nama acara","jenis":"teks","wajib":true},{"kunci":"hari_tanggal","label":"Hari dan tanggal acara","jenis":"hari_tanggal","wajib":true},{"kunci":"waktu","label":"Waktu mulai","jenis":"jam","wajib":true},{"kunci":"tempat","label":"Tempat","jenis":"teks","wajib":true},{"kunci":"agenda","label":"Agenda","jenis":"daftar","gaya":"angka"}]',
 '[{"jabatan":"Direktur"}]', true, 1),

('mandat', 'Surat Mandat', 'pegawai', 'AM', 'surat', 'D', 'pondok', 'tengah', 'SURAT MANDAT', null, 'Mandat', null,
 '{"salam": false}',
$t$Yang bertanda tangan di bawah ini, {penanda.jabatan} {lembaga}, dengan ini memberikan mandat kepada:

{penerima}

untuk {maksud}.

Mandat ini berlaku sejak tanggal ditetapkan sampai dengan selesainya tugas tersebut. Kepada yang bersangkutan agar melaksanakan mandat ini dengan penuh amanah dan tanggung jawab serta melaporkan hasilnya.

Demikian surat mandat ini dibuat untuk dipergunakan sebagaimana mestinya.$t$,
 '[{"kunci":"penerima","label":"Penerima mandat","jenis":"daftar_pegawai","wajib":true},{"kunci":"maksud","label":"Maksud mandat","jenis":"panjang","wajib":true}]',
 '[{"jabatan":"Direktur"}]', true, 2),

('instruksi', 'Surat Instruksi', 'pegawai', 'AM', 'surat', 'D', 'pondok', 'kiri', null, null, 'Instruksi', 'Seluruh Asatidzah dan Pegawai',
 '{"salam": true, "salam_penutup": true, "tembusan": true}',
$t$Sehubungan dengan {latar}, dengan ini kami menginstruksikan kepada Antum sekalian untuk:

{butir}

Demikian instruksi ini untuk dilaksanakan dengan penuh tanggung jawab. _Jazakumullahu khairan_.$t$,
 '[{"kunci":"latar","label":"Latar belakang (sehubungan dengan ...)","jenis":"panjang","wajib":true},{"kunci":"butir","label":"Butir instruksi","jenis":"daftar","gaya":"angka","wajib":true}]',
 '[{"jabatan":"Direktur"}]', true, 3),

('himbauan', 'Surat Himbauan', 'umum', 'IL', 'surat', 'D', 'pondok', 'kiri', null, null, 'Himbauan', 'Seluruh Keluarga Besar Pondok',
 '{"salam": true, "salam_penutup": true}',
$t$Sehubungan dengan {latar}, kami menghimbau kepada {sasaran} untuk:

{butir}

Demikian himbauan ini kami sampaikan. Semoga Allah _Subhanahu wa Ta'ala_ senantiasa memudahkan urusan kita semua.$t$,
 '[{"kunci":"latar","label":"Latar belakang","jenis":"panjang","wajib":true},{"kunci":"sasaran","label":"Sasaran himbauan","jenis":"teks","wajib":true,"bawaan":"seluruh asatidzah, pegawai, dan santri"},{"kunci":"butir","label":"Butir himbauan","jenis":"daftar","gaya":"angka","wajib":true}]',
 '[{"jabatan":"Direktur"}]', true, 4),

('peringatan', 'Surat Peringatan', 'pegawai', 'IZ', 'surat', 'D', 'pondok', 'kiri', null, null, 'Peringatan', null,
 '{"salam": true, "salam_penutup": true, "tembusan": true}',
$t$Berdasarkan {dasar}, dengan ini kami memberikan *Peringatan {tingkat}* kepada:

Nama : {pegawai.nama}
NIY : {pegawai.niy}
Jabatan : {pegawai.jabatan}
Unit kerja : {pegawai.unit}

Kami berharap yang bersangkutan {harapan}. Apabila peringatan ini tidak diindahkan, akan diambil tindakan sesuai ketentuan yang berlaku di lingkungan {lembaga}.

Demikian surat peringatan ini disampaikan untuk diperhatikan dan dilaksanakan.$t$,
 '[{"kunci":"pegawai","label":"Pegawai yang diberi peringatan","jenis":"pegawai","wajib":true},{"kunci":"tingkat","label":"Tingkat peringatan","jenis":"teks","wajib":true,"bawaan":"Pertama"},{"kunci":"dasar","label":"Dasar peringatan","jenis":"panjang","wajib":true},{"kunci":"harapan","label":"Harapan perbaikan","jenis":"panjang","wajib":true,"bawaan":"segera memperbaiki kedisiplinan dan kinerjanya"}]',
 '[{"jabatan":"Direktur"}]', true, 5),

('kuasa', 'Surat Penunjukan/Kuasa', 'pegawai', 'AM', 'surat', 'D', 'pondok', 'tengah', 'SURAT KUASA', null, 'Kuasa', null,
 '{"salam": false}',
$t$Yang bertanda tangan di bawah ini:

Nama : {pemberi.nama}
NIY : {pemberi.niy}
Jabatan : {pemberi.jabatan}

selanjutnya disebut *Pemberi Kuasa*, dengan ini memberikan kuasa kepada:

Nama : {penerima.nama}
NIY : {penerima.niy}
Jabatan : {penerima.jabatan}

selanjutnya disebut *Penerima Kuasa*, untuk {maksud}.

Demikian surat kuasa ini dibuat untuk dipergunakan sebagaimana mestinya.$t$,
 '[{"kunci":"pemberi","label":"Pemberi kuasa","jenis":"pegawai","wajib":true},{"kunci":"penerima","label":"Penerima kuasa","jenis":"pegawai","wajib":true},{"kunci":"maksud","label":"Maksud pemberian kuasa","jenis":"panjang","wajib":true}]',
 '[{"jabatan":"Pemberi Kuasa"},{"jabatan":"Penerima Kuasa"}]', true, 6),

('permohonan', 'Surat Permohonan', 'umum', 'TH', 'surat', 'K', 'pondok', 'kiri', null, null, 'Permohonan', null,
 '{"salam": true, "hamdalah": true, "salam_penutup": true, "tembusan": true, "narahubung": true}',
$t${pembuka}

Sehubungan dengan hal tersebut, kami memohon kesediaan Bapak/Ibu untuk {maksud} yang _insya Allah_ akan dilaksanakan pada:

Hari/tanggal : {hari_tanggal}
Pukul : {waktu} WITA s.d. selesai
Tempat : {tempat}

Demikian permohonan ini kami sampaikan. Atas perhatian dan kerja samanya, kami ucapkan _jazakumullahu khairan_.$t$,
 '[{"kunci":"pembuka","label":"Paragraf pembuka (latar kegiatan)","jenis":"panjang","wajib":true},{"kunci":"maksud","label":"Maksud permohonan","jenis":"panjang","wajib":true},{"kunci":"hari_tanggal","label":"Hari dan tanggal","jenis":"hari_tanggal","wajib":true},{"kunci":"waktu","label":"Pukul","jenis":"jam","wajib":true},{"kunci":"tempat","label":"Tempat","jenis":"teks","wajib":true}]',
 '[{"jabatan":"Direktur","pengantar":"Mengetahui,"},{"jabatan":"Ketua Panitia"}]', true, 7),

('pengumuman', 'Pengumuman', 'umum', 'IL', 'surat', 'D', 'pondok', 'tengah', 'PENGUMUMAN', 'TENTANG {tentang}', 'Pengumuman', null,
 '{"salam": true, "salam_penutup": true}',
$t$Diberitahukan kepada {sasaran} bahwa:

{butir}

Demikian pengumuman ini disampaikan untuk diketahui dan dilaksanakan sebagaimana mestinya.$t$,
 '[{"kunci":"tentang","label":"Tentang","jenis":"teks","wajib":true},{"kunci":"sasaran","label":"Ditujukan kepada","jenis":"teks","wajib":true,"bawaan":"seluruh asatidzah, pegawai, dan santri"},{"kunci":"butir","label":"Butir pengumuman","jenis":"daftar","gaya":"angka","wajib":true}]',
 '[{"jabatan":"Direktur"}]', true, 8),

('keterangan', 'Surat Keterangan/Rekomendasi', 'umum', 'IL', 'surat', 'K', 'pondok', 'tengah', 'SURAT KETERANGAN', null, 'Keterangan', null,
 '{"salam": false}',
$t$Yang bertanda tangan di bawah ini, {penanda.jabatan} {lembaga}, menerangkan bahwa:

Nama : {nama}
Nomor pokok : {nomor_pokok}
Pendidikan : {pendidikan}
Pekerjaan : {pekerjaan}
Alamat : {alamat}

{keterangan}

Demikian surat keterangan ini dibuat dengan sebenarnya untuk dipergunakan sebagaimana mestinya.$t$,
 '[{"kunci":"nama","label":"Nama yang diterangkan","jenis":"teks","wajib":true},{"kunci":"nomor_pokok","label":"Nomor pokok (NIY/NIK)","jenis":"teks"},{"kunci":"pendidikan","label":"Pendidikan terakhir","jenis":"teks"},{"kunci":"pekerjaan","label":"Pekerjaan","jenis":"teks"},{"kunci":"alamat","label":"Alamat","jenis":"teks"},{"kunci":"keterangan","label":"Isi keterangan/rekomendasi","jenis":"panjang","wajib":true}]',
 '[{"jabatan":"Direktur"}]', true, 9),

('perjalanan_dinas', 'Surat Perjalanan Dinas', 'pegawai', 'AM', 'surat', 'D', 'pondok', 'tengah', 'SURAT PERINTAH PERJALANAN DINAS', null, 'Perjalanan Dinas', null,
 '{"salam": false}',
$t$| No. | Uraian | Keterangan |
|---|---|---|
| 1. | Pejabat pemberi tugas | {penanda.jabatan} |
| 2. | Nama pegawai yang diperintah | {pegawai.nama} |
| 3. | Jabatan | {pegawai.jabatan} |
| 4. | Maksud perjalanan dinas | {maksud} |
| 5. | Alat angkutan yang dipergunakan | {angkutan} |
| 6. | Tempat berangkat | {berangkat_dari} |
| 7. | Tempat tujuan | {tujuan} |
| 8. | Lama perjalanan dinas | {lama} |
| 9. | Tanggal berangkat | {tanggal_berangkat} |
| 10. | Tanggal harus kembali | {tanggal_kembali} |
| 11. | Pengikut | {pengikut} |
| 12. | Pembebanan anggaran | {anggaran} |
| 13. | Keterangan lain-lain | {keterangan} |

Demikian surat perintah perjalanan dinas ini dibuat untuk dilaksanakan dengan penuh tanggung jawab.$t$,
 '[{"kunci":"pegawai","label":"Pegawai yang diperintah","jenis":"pegawai","wajib":true},{"kunci":"maksud","label":"Maksud perjalanan","jenis":"panjang","wajib":true},{"kunci":"angkutan","label":"Alat angkutan","jenis":"teks","bawaan":"Kendaraan darat"},{"kunci":"berangkat_dari","label":"Tempat berangkat","jenis":"teks","bawaan":"Gowa"},{"kunci":"tujuan","label":"Tempat tujuan","jenis":"teks","wajib":true},{"kunci":"lama","label":"Lama perjalanan","jenis":"teks","wajib":true,"bawaan":"1 (satu) hari"},{"kunci":"tanggal_berangkat","label":"Tanggal berangkat","jenis":"tanggal","wajib":true},{"kunci":"tanggal_kembali","label":"Tanggal kembali","jenis":"tanggal","wajib":true},{"kunci":"pengikut","label":"Pengikut","jenis":"teks","bawaan":"–"},{"kunci":"anggaran","label":"Pembebanan anggaran","jenis":"teks","bawaan":"Anggaran Pondok"},{"kunci":"keterangan","label":"Keterangan lain","jenis":"teks","bawaan":"–"}]',
 '[{"jabatan":"Direktur"}]', true, 10),

('surat_keputusan', 'Surat Keputusan', 'umum', 'QR', 'sk', 'D', 'pondok', 'tengah', 'KEPUTUSAN DIREKTUR', 'TENTANG
{tentang}', 'Keputusan', null,
 '{"salam": false, "basmalah": true, "ditetapkan": true, "tembusan": true}',
$t${penanda.jabatan} {lembaga}, setelah:

Menimbang : {menimbang}
Mengingat : {mengingat}

== *MEMUTUSKAN*

Menetapkan : {menetapkan}
Kesatu : {kesatu}
Kedua : {kedua}
Ketiga : Keputusan ini berlaku sejak tanggal ditetapkan dengan ketentuan apabila di kemudian hari terdapat kekeliruan akan diadakan perbaikan sebagaimana mestinya.$t$,
 '[{"kunci":"tentang","label":"Tentang","jenis":"teks","wajib":true},{"kunci":"menimbang","label":"Menimbang","jenis":"daftar","gaya":"huruf","wajib":true},{"kunci":"mengingat","label":"Mengingat","jenis":"daftar","gaya":"angka","wajib":true},{"kunci":"menetapkan","label":"Menetapkan","jenis":"panjang","wajib":true},{"kunci":"kesatu","label":"Diktum kesatu","jenis":"panjang","wajib":true},{"kunci":"kedua","label":"Diktum kedua","jenis":"panjang","wajib":true}]',
 '[{"jabatan":"Direktur"}]', true, 11),

('keterangan_aktif_santri', 'Surat Keterangan Aktif Santri', 'santri', 'IL', 'surat', 'K', 'pondok', 'tengah', 'SURAT KETERANGAN AKTIF', null, 'Keterangan Aktif Santri', null,
 '{"salam": false}',
$t$Yang bertanda tangan di bawah ini, {penanda.jabatan} {lembaga}, menerangkan bahwa:

Nama : {santri.nama}
NIS/NISN : {santri.nis} / {santri.nisn}
Tempat, tanggal lahir : {santri.ttl}
Jenis kelamin : {santri.jk}
Kelas : {santri.kelas} ({santri.jenjang})
Nama orang tua/wali : {santri.wali}
Alamat : {santri.alamat}

adalah benar santri {lembaga} yang masih aktif mengikuti kegiatan pendidikan pada Tahun Ajaran {tahun_ajaran}.

Surat keterangan ini diberikan untuk keperluan {keperluan}.

Demikian surat keterangan ini dibuat dengan sebenarnya untuk dipergunakan sebagaimana mestinya.$t$,
 '[{"kunci":"santri","label":"Santri","jenis":"santri","wajib":true},{"kunci":"keperluan","label":"Keperluan","jenis":"teks","wajib":true}]',
 '[{"jabatan":"Direktur"}]', true, 12),

('kelakuan_baik', 'Surat Keterangan Berkelakuan Baik', 'santri', 'IL', 'surat', 'K', 'pondok', 'tengah', 'SURAT KETERANGAN BERKELAKUAN BAIK', null, 'Keterangan Berkelakuan Baik', null,
 '{"salam": false}',
$t$Yang bertanda tangan di bawah ini, {penanda.jabatan} {lembaga}, menerangkan bahwa:

Nama : {santri.nama}
NIS/NISN : {santri.nis} / {santri.nisn}
Tempat, tanggal lahir : {santri.ttl}
Kelas : {santri.kelas} ({santri.jenjang})
Nama orang tua/wali : {santri.wali}

selama menjadi santri di {lembaga} berkelakuan baik, tidak pernah terlibat pelanggaran berat, dan tidak sedang menjalani sanksi.

Surat keterangan ini diberikan untuk keperluan {keperluan}.

Demikian surat keterangan ini dibuat dengan sebenarnya untuk dipergunakan sebagaimana mestinya.$t$,
 '[{"kunci":"santri","label":"Santri","jenis":"santri","wajib":true},{"kunci":"keperluan","label":"Keperluan","jenis":"teks","wajib":true}]',
 '[{"jabatan":"Direktur"}]', true, 13)
on conflict (kode) do nothing;

-- ---------------------------------------------------------------------
-- 9. REALTIME DAN HAK EKSEKUSI
-- ---------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'outgoing_letters') then
    alter publication supabase_realtime add table public.outgoing_letters;
  end if;
end $$;

do $$
declare f text;
begin
  foreach f in array array['boleh_susun_surat()','boleh_baca_surat_keluar(uuid)','hak_persuratan()','konteks_surat()','penanda_tangan_surat()',
    'santri_untuk_surat(text)','simpan_template_surat(jsonb)','hapus_template_surat(uuid)','simpan_surat_keluar(jsonb)','kirim_surat_ke_tu(uuid)',
    'ajukan_surat_keluar(uuid,text,jsonb)','batalkan_surat_keluar(uuid,text)','simpan_arsip_surat_keluar(uuid,uuid)','daftar_surat_keluar(date,date)',
    'rincian_surat_keluar(uuid,uuid)','buku_agenda_keluar(date,date)','ringkasan_persuratan()'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['_penanda_sah(jsonb)','_pengelola_surat()','_nomor_surat_keluar(uuid)','_surat_keluar_json(uuid)','tg_registri_surat_keluar()'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN (hasil yang benar: baris 1–8 "Sesuai")
-- ---------------------------------------------------------------------
select '1. Tabel template dan surat keluar' as pemeriksaan,
       case when to_regclass('public.letter_templates') is not null and to_regclass('public.outgoing_letters') is not null then 'Sesuai' else 'Periksa' end as hasil
union all select '2. Template isi awal (13)', case when (select count(*) from letter_templates where bawaan) >= 13 then 'Sesuai' else 'Periksa' end
union all select '3. Fungsi surat keluar (8)', case when (select count(*) from pg_proc where proname in ('simpan_surat_keluar','kirim_surat_ke_tu','ajukan_surat_keluar',
  'batalkan_surat_keluar','daftar_surat_keluar','rincian_surat_keluar','buku_agenda_keluar','simpan_template_surat')) = 8 then 'Sesuai' else 'Periksa' end
union all select '4. Nomor surat diambil saat sah (pemicu registri)', case when exists (select 1 from pg_trigger where tgname = 'ab_surat_keluar') then 'Sesuai' else 'Periksa' end
union all select '5. Tabel tertutup untuk tulis langsung (RLS)', case when (select count(*) from pg_policies where tablename in ('letter_templates','outgoing_letters') and cmd <> 'SELECT') = 0
  and (select bool_and(relrowsecurity) from pg_class where relname in ('letter_templates','outgoing_letters')) then 'Sesuai' else 'Periksa' end
union all select '6. Hak lihat arsip surat keluar', case when pg_get_functiondef('public.boleh_lihat_berkas(uuid,uuid)'::regprocedure) like '%outgoing_letters%' then 'Sesuai' else 'Periksa' end
union all select '7. Format nomor surat dan SK aktif', case when (select count(*) from doc_number_formats where kode in ('surat','sk') and aktif) = 2 then 'Sesuai' else 'Periksa' end
union all select '8. Hanya Tata Usaha yang mengajukan tanda tangan surat', case when pg_get_functiondef('public.ajukan_surat_keluar(uuid,text,jsonb)'::regprocedure) like '%boleh_kelola_persuratan%' then 'Sesuai' else 'Periksa' end
union all select '9. Penanda tangan terhubung akun (syarat TTD elektronik)', (select count(*) filter (where employee_id is not null)::text || ' dari ' || count(*)::text || ' penanda tangan aktif' from signatories where aktif);
