-- SIMKA PRO | supabase/migrations/20261011006700_persuratan_masuk.sql | v1.0 | Fase 10 – Tahap 1 Surat masuk dan disposisi | 11/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 10 · Migrasi 67: Persuratan – surat masuk dan disposisi (Blueprint Bagian 35)
--   * incoming_letters    : surat masuk. Nomor agenda otomatis (format "agenda_masuk", reset per tahun Hijriah, dapat diubah
--                           di Setelan → Penomoran), tanggal terima, nomor/tanggal surat, pengirim, perihal, sifat (biasa, penting,
--                           segera, rahasia), cara diterima, pindaian (foto/PDF ke Drive, boleh beberapa berkas).
--                           Status: diteruskan (ke pimpinan) → didisposisi → selesai; atau diarsipkan (tanpa disposisi) / batal.
--   * letter_dispositions : disposisi berantai. Pimpinan penerima mendisposisikan ke pejabat/pegawai (instruksi, catatan, batas
--                           waktu); penerima boleh meneruskan lagi ke stafnya; penerima menandai selesai dengan laporan singkat.
--                           Surat otomatis Selesai bila semua disposisi selesai.
--   * Pengelola: superadmin, admin ber-izin kelola_persuratan, pemegang hak fitur tata_usaha ≥ 2 (jabatan Tata Usaha).
--   * Hak baca: pengelola, pimpinan penerima, semua pihak disposisi; Yayasan/Direktur/Wadir membaca semua surat kecuali
--     yang bersifat RAHASIA. Pindaian surat dibuka lewat Edge Function "berkas" dengan hak yang sama.
--   * Pengingat batas waktu disposisi: pg_cron "pengingat-disposisi" pukul 07.00 WITA.
-- Jalankan SETELAH migrasi 6600. Aman dijalankan ulang.
-- =====================================================================

insert into public.admin_capabilities (kode, nama, urutan) values
  ('kelola_persuratan', 'Mengelola persuratan: mencatat surat masuk, meneruskan ke pimpinan, buku agenda, ketentuan', 40)
on conflict (kode) do nothing;

insert into public.doc_number_formats (kode, nama, pola, grup_urut, reset) values
  ('agenda_masuk', 'Nomor agenda surat masuk', '{URUT3}/SM/{BLN_H_ROMAWI}/{THN_H}', 'agenda_masuk', 'tahun_hijriah')
on conflict (kode) do nothing;

insert into public.institution_settings (kunci, nilai) values ('persuratan', jsonb_build_object(
  'instruksi', jsonb_build_array('Tindak lanjuti', 'Pelajari dan laporkan', 'Hadiri/wakili', 'Koordinasikan', 'Siapkan jawaban',
                                 'Untuk diketahui', 'Edarkan', 'Arsipkan'),
  'batas_bawaan_hari', 3))
on conflict (kunci) do nothing;

-- ---------------------------------------------------------------------
-- 1. TABEL
-- ---------------------------------------------------------------------
create table if not exists public.incoming_letters (
  id              uuid primary key default gen_random_uuid(),
  nomor_agenda    text not null unique,
  urut_agenda     int not null,
  periode         text not null,
  tanggal_terima  date not null default public.hari_ini(),
  nomor_surat     text,
  tanggal_surat   date,
  pengirim        text not null,
  alamat_pengirim text,
  perihal         text not null,
  ringkasan       text,
  lampiran        text,
  sifat           text not null default 'biasa' check (sifat in ('biasa','penting','segera','rahasia')),
  cara            text not null default 'langsung' check (cara in ('langsung','pos','email','wa','lainnya')),
  berkas_ids      uuid[] not null default '{}',
  tujuan_id       uuid references public.employees(id) on delete set null,
  status          text not null default 'diteruskan' check (status in ('diteruskan','didisposisi','selesai','diarsipkan','batal')),
  catatan         text,
  catatan_selesai text,
  dibaca_tujuan   timestamptz,
  dicatat_oleh    uuid references public.employees(id) on delete set null,
  diteruskan_pada timestamptz,
  selesai_pada    timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index if not exists il_terima_idx on public.incoming_letters (tanggal_terima desc);
create index if not exists il_tujuan_idx on public.incoming_letters (tujuan_id, status);
create index if not exists il_berkas_idx on public.incoming_letters using gin (berkas_ids);

create table if not exists public.letter_dispositions (
  id           uuid primary key default gen_random_uuid(),
  letter_id    uuid not null references public.incoming_letters(id) on delete cascade,
  induk_id     uuid references public.letter_dispositions(id) on delete cascade,
  dari_id      uuid not null references public.employees(id) on delete cascade,
  kepada_id    uuid not null references public.employees(id) on delete cascade,
  instruksi    text[] not null default '{}',
  catatan      text,
  batas        date,
  status       text not null default 'baru' check (status in ('baru','dibaca','selesai')),
  dibaca_pada  timestamptz,
  selesai_pada timestamptz,
  laporan      text,
  diingatkan   smallint not null default 0,
  created_at   timestamptz not null default now(),
  unique (letter_id, dari_id, kepada_id),
  constraint disposisi_bukan_diri check (dari_id <> kepada_id)
);
create index if not exists ld_kepada_idx on public.letter_dispositions (kepada_id, status);
create index if not exists ld_surat_idx on public.letter_dispositions (letter_id, created_at);

drop trigger if exists aa_updated on public.incoming_letters;
create trigger aa_updated before update on public.incoming_letters for each row execute function public.tg_updated_at();
drop trigger if exists zz_audit on public.incoming_letters;
create trigger zz_audit after insert or update or delete on public.incoming_letters for each row execute function public.tg_audit();
drop trigger if exists zz_audit on public.letter_dispositions;
create trigger zz_audit after insert or update or delete on public.letter_dispositions for each row execute function public.tg_audit();

-- ---------------------------------------------------------------------
-- 2. HAK
-- ---------------------------------------------------------------------
create or replace function public.boleh_kelola_persuratan()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_superadmin() or public.admin_boleh('kelola_persuratan') or public.tingkat_fitur('tata_usaha') >= 2
$$;

/** Pimpinan yang dapat menerima surat masuk dari TU: Yayasan, Direktur, Wadir, Kepala Bidang (termasuk Plt). */
create or replace function public._pimpinan_surat()
returns table (employee_id uuid, kode text, jabatan text, plt boolean)
language sql stable security definer set search_path = public as $$
  select distinct on (p.employee_id) p.employee_id, p.kode,
         p.nama_jabatan || case when p.kode = 'KEPALA_BIDANG' and o.nama is not null then ' ' || regexp_replace(o.nama, '^Bidang\s+', '') else '' end
           || case when p.plt then ' (Plt)' else '' end,
         p.plt
    from public.pemegang_jabatan() p left join org_units o on o.id = p.org_unit_id
   where p.kode in ('YAYASAN','DIREKTUR','WAKIL_DIREKTUR','KEPALA_BIDANG')
   order by p.employee_id, p.plt
$$;

/** Pimpinan puncak yang membaca semua surat (kecuali rahasia): Yayasan, Direktur, Wadir (termasuk Plt). */
create or replace function public._puncak_surat()
returns setof uuid language sql stable security definer set search_path = public as $$
  select employee_id from public._pimpinan_surat() where kode in ('YAYASAN','DIREKTUR','WAKIL_DIREKTUR')
$$;

/** Label jabatan singkat seorang pegawai: jabatan struktural (beserta bidangnya), bila tidak ada satu jabatan fungsional. */
create or replace function public._label_jabatan(p_emp uuid)
returns text language sql stable security definer set search_path = public as $$
  select coalesce(
    (select sp.nama || case when sp.kode in ('KEPALA_BIDANG','KEPALA_UNIT','WAKIL_KEPALA_BIDANG') and o.nama is not null
                            then ' ' || regexp_replace(o.nama, '^(Bidang|Unit)\s+', '') else '' end
       from employee_structurals es join structural_positions sp on sp.id = es.structural_position_id
       left join org_units o on o.id = es.org_unit_id where es.employee_id = p_emp),
    (select fp.nama from employee_functions ef join functional_positions fp on fp.id = ef.functional_position_id
      where ef.employee_id = p_emp order by fp.urutan limit 1),
    'Pegawai')
$$;

create or replace function public._pihak_surat(p_id uuid)
returns setof uuid language sql stable security definer set search_path = public as $$
  select tujuan_id from incoming_letters where id = p_id and tujuan_id is not null
  union select dari_id from letter_dispositions where letter_id = p_id
  union select kepada_id from letter_dispositions where letter_id = p_id
$$;

create or replace function public.boleh_baca_surat(p_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.boleh_kelola_persuratan()
      or public.saya() in (select public._pihak_surat(p_id))
      or (public.saya() in (select public._puncak_surat())
          and exists (select 1 from incoming_letters where id = p_id and sifat <> 'rahasia' and status <> 'batal'))
$$;

create or replace function public.pengaturan_persuratan()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('instruksi', jsonb_build_array('Tindak lanjuti','Untuk diketahui'), 'batas_bawaan_hari', 3)
         || coalesce((select nilai from institution_settings where kunci = 'persuratan'), '{}'::jsonb)
$$;

create or replace function public.simpan_pengaturan_persuratan(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v_ins jsonb;
begin
  if not public.boleh_kelola_persuratan() then raise exception 'Anda tidak berwenang mengatur ketentuan persuratan.' using errcode = '42501'; end if;
  select coalesce(jsonb_agg(distinct trim(x)), '[]'::jsonb) into v_ins from jsonb_array_elements_text(coalesce(p->'instruksi', '[]')) x where length(trim(x)) >= 3;
  if jsonb_array_length(v_ins) = 0 then raise exception 'Isi minimal satu pilihan instruksi disposisi.'; end if;
  insert into institution_settings (kunci, nilai, updated_by) values ('persuratan',
    jsonb_build_object('instruksi', (select jsonb_agg(x order by o) from jsonb_array_elements_text(coalesce(p->'instruksi', '[]')) with ordinality t(x, o)
                                      where length(trim(x)) >= 3),
                       'batas_bawaan_hari', greatest(0, least(60, coalesce((p->>'batas_bawaan_hari')::int, 3)))), public.saya())
  on conflict (kunci) do update set nilai = institution_settings.nilai || excluded.nilai, updated_at = now(), updated_by = excluded.updated_by;
  return public.pengaturan_persuratan();
end $$;

create or replace function public.hak_persuratan()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'kelola', public.boleh_kelola_persuratan(),
    'superadmin', public.is_superadmin(),
    'pimpinan', public.saya() in (select employee_id from public._pimpinan_surat()),
    'puncak', public.saya() in (select public._puncak_surat()),
    'tampil', public.boleh_kelola_persuratan() or public.saya() in (select employee_id from public._pimpinan_surat())
              or exists (select 1 from letter_dispositions where kepada_id = public.saya())
              or exists (select 1 from incoming_letters where tujuan_id = public.saya()),
    'pengaturan', public.pengaturan_persuratan())
$$;

alter table public.incoming_letters enable row level security;
alter table public.letter_dispositions enable row level security;
drop policy if exists baca on public.incoming_letters;
create policy baca on public.incoming_letters for select to authenticated using (public.boleh_baca_surat(id));
drop policy if exists baca on public.letter_dispositions;
create policy baca on public.letter_dispositions for select to authenticated using (public.boleh_baca_surat(letter_id));
grant select on public.incoming_letters, public.letter_dispositions to authenticated;

-- ---------------------------------------------------------------------
-- 3. PILIHAN PENERIMA
-- ---------------------------------------------------------------------
/** Pimpinan yang dapat dipilih TU sebagai penerima surat masuk. Direktur ditandai bawaan. */
create or replace function public.pimpinan_penerima_surat()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', e.id, 'nama', e.nama_lengkap, 'jabatan', p.jabatan, 'kode', p.kode,
           'bawaan', p.kode = 'DIREKTUR' and not p.plt)
           order by case p.kode when 'DIREKTUR' then 1 when 'WAKIL_DIREKTUR' then 2 when 'YAYASAN' then 3 else 4 end, p.jabatan, e.nama_lengkap), '[]'::jsonb)
    from public._pimpinan_surat() p join employees e on e.id = p.employee_id
   where public.saya() is not null
$$;

/** Pegawai aktif yang dapat menerima disposisi (semua pegawai berakun aktif). */
create or replace function public.pegawai_disposisi()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', e.id, 'nama', e.nama_lengkap, 'niy', e.niy, 'jabatan', public._label_jabatan(e.id),
           'unit', o.nama, 'pimpinan', e.id in (select employee_id from public._pimpinan_surat()))
           order by (e.id in (select employee_id from public._pimpinan_surat())) desc, e.nama_lengkap), '[]'::jsonb)
    from employees e left join org_units o on o.id = e.org_unit_id
   where public.saya() is not null and e.status_akun = 'aktif' and e.status_keaktifan = 'aktif' and e.peran <> 'superadmin'
$$;

-- ---------------------------------------------------------------------
-- 4. PENCATATAN SURAT MASUK
-- ---------------------------------------------------------------------
create or replace function public._berkas_sah(p jsonb)
returns uuid[] language sql stable security definer set search_path = public as $$
  select coalesce(array_agg(distinct x::uuid), '{}') from jsonb_array_elements_text(coalesce(p, '[]')) x
   where exists (select 1 from storage_objects s where s.id = x::uuid and s.status <> 'dihapus')
$$;

create or replace function public._kabari_tujuan_surat(p_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare s incoming_letters%rowtype;
begin
  select * into s from incoming_letters where id = p_id;
  if s.tujuan_id is null or s.tujuan_id = public.saya() then return; end if;
  perform public.kirim_notifikasi(s.tujuan_id,
    case s.sifat when 'rahasia' then 'Surat masuk RAHASIA perlu disposisi' when 'segera' then 'SEGERA: surat masuk perlu disposisi' else 'Surat masuk perlu disposisi' end,
    case when s.sifat = 'rahasia' then 'Agenda ' || s.nomor_agenda || '. Buka SIMKA PRO untuk membaca.'
         else s.perihal || ' – dari ' || s.pengirim end,
    '/persuratan/untuk-saya?surat=' || s.id, 'EnvelopeSimple', case when s.sifat in ('segera','rahasia') then 'merah' else 'biru' end);
end $$;

create or replace function public.catat_surat_masuk(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v_no jsonb; v_id uuid; v_tujuan uuid := nullif(p->>'tujuan_id', '')::uuid; v_arsip boolean := coalesce((p->>'arsip')::boolean, false);
        v_tgl date := coalesce(nullif(p->>'tanggal_terima', '')::date, public.hari_ini());
begin
  if not public.boleh_kelola_persuratan() then raise exception 'Hanya Tata Usaha atau pengelola persuratan yang dapat mencatat surat masuk.' using errcode = '42501'; end if;
  if length(trim(coalesce(p->>'pengirim', ''))) < 3 then raise exception 'Isi asal/pengirim surat.'; end if;
  if length(trim(coalesce(p->>'perihal', ''))) < 3 then raise exception 'Isi perihal surat.'; end if;
  if v_tgl > public.hari_ini() then raise exception 'Tanggal terima tidak boleh melewati hari ini.'; end if;
  if nullif(p->>'tanggal_surat', '')::date > v_tgl then raise exception 'Tanggal surat tidak boleh sesudah tanggal terima.'; end if;
  if not v_arsip and v_tujuan is null then raise exception 'Pilih pimpinan penerima surat, atau pilih "Langsung diarsipkan".'; end if;
  if v_tujuan is not null and v_tujuan not in (select employee_id from public._pimpinan_surat()) then raise exception 'Penerima surat harus pimpinan (Yayasan, Direktur, Wakil Direktur, atau Kepala Bidang).'; end if;
  perform set_config('simka.nomor_sistem', '1', true);
  v_no := public.ambil_nomor('agenda_masuk', v_tgl, 'D', null, 'pondok');
  perform set_config('simka.nomor_sistem', '', true);
  insert into incoming_letters (nomor_agenda, urut_agenda, periode, tanggal_terima, nomor_surat, tanggal_surat, pengirim, alamat_pengirim, perihal,
                                ringkasan, lampiran, sifat, cara, berkas_ids, tujuan_id, status, catatan, dicatat_oleh, diteruskan_pada)
  values (v_no->>'nomor', (v_no->>'urut')::int, v_no->>'periode', v_tgl, nullif(trim(p->>'nomor_surat'), ''), nullif(p->>'tanggal_surat', '')::date,
          trim(p->>'pengirim'), nullif(trim(p->>'alamat_pengirim'), ''), trim(p->>'perihal'), nullif(trim(p->>'ringkasan'), ''), nullif(trim(p->>'lampiran'), ''),
          coalesce(nullif(p->>'sifat', ''), 'biasa'), coalesce(nullif(p->>'cara', ''), 'langsung'), public._berkas_sah(p->'berkas_ids'),
          case when v_arsip then null else v_tujuan end, case when v_arsip then 'diarsipkan' else 'diteruskan' end,
          nullif(trim(p->>'catatan'), ''), public.saya(), case when v_arsip then null else now() end)
  returning id into v_id;
  if not v_arsip then perform public._kabari_tujuan_surat(v_id); end if;
  return jsonb_build_object('id', v_id, 'nomor_agenda', v_no->>'nomor');
end $$;

/** Ubah data surat selama belum didisposisi (perbaikan salah catat, ganti penerima, teruskan surat yang diarsipkan). */
create or replace function public.ubah_surat_masuk(p jsonb)
returns void language plpgsql volatile security definer set search_path = public as $$
declare s incoming_letters%rowtype; v_tujuan uuid := nullif(p->>'tujuan_id', '')::uuid; v_arsip boolean := coalesce((p->>'arsip')::boolean, false);
        v_tgl date;
begin
  if not public.boleh_kelola_persuratan() then raise exception 'Hanya Tata Usaha atau pengelola persuratan yang dapat mengubah surat masuk.' using errcode = '42501'; end if;
  select * into s from incoming_letters where id = (p->>'id')::uuid for update;
  if s.id is null then raise exception 'Surat tidak ditemukan.'; end if;
  if s.status not in ('diteruskan','diarsipkan') or exists (select 1 from letter_dispositions where letter_id = s.id) then
    raise exception 'Surat yang sudah didisposisi atau selesai tidak dapat diubah.'; end if;
  v_tgl := coalesce(nullif(p->>'tanggal_terima', '')::date, s.tanggal_terima);
  if length(trim(coalesce(p->>'pengirim', ''))) < 3 then raise exception 'Isi asal/pengirim surat.'; end if;
  if length(trim(coalesce(p->>'perihal', ''))) < 3 then raise exception 'Isi perihal surat.'; end if;
  if v_tgl > public.hari_ini() then raise exception 'Tanggal terima tidak boleh melewati hari ini.'; end if;
  if nullif(p->>'tanggal_surat', '')::date > v_tgl then raise exception 'Tanggal surat tidak boleh sesudah tanggal terima.'; end if;
  if not v_arsip and v_tujuan is null then raise exception 'Pilih pimpinan penerima surat, atau pilih "Langsung diarsipkan".'; end if;
  if v_tujuan is not null and v_tujuan not in (select employee_id from public._pimpinan_surat()) then raise exception 'Penerima surat harus pimpinan (Yayasan, Direktur, Wakil Direktur, atau Kepala Bidang).'; end if;
  update incoming_letters set tanggal_terima = v_tgl, nomor_surat = nullif(trim(p->>'nomor_surat'), ''), tanggal_surat = nullif(p->>'tanggal_surat', '')::date,
         pengirim = trim(p->>'pengirim'), alamat_pengirim = nullif(trim(p->>'alamat_pengirim'), ''), perihal = trim(p->>'perihal'),
         ringkasan = nullif(trim(p->>'ringkasan'), ''), lampiran = nullif(trim(p->>'lampiran'), ''), sifat = coalesce(nullif(p->>'sifat', ''), sifat),
         cara = coalesce(nullif(p->>'cara', ''), cara), berkas_ids = case when p ? 'berkas_ids' then public._berkas_sah(p->'berkas_ids') else berkas_ids end,
         catatan = nullif(trim(p->>'catatan'), ''),
         tujuan_id = case when v_arsip then null else v_tujuan end, status = case when v_arsip then 'diarsipkan' else 'diteruskan' end,
         diteruskan_pada = case when v_arsip then null when v_tujuan is distinct from s.tujuan_id then now() else diteruskan_pada end,
         dibaca_tujuan = case when v_tujuan is distinct from s.tujuan_id then null else dibaca_tujuan end
   where id = s.id;
  if not v_arsip and v_tujuan is distinct from s.tujuan_id then perform public._kabari_tujuan_surat(s.id); end if;
end $$;

/** Batalkan pencatatan (salah catat/dobel). Nomor agenda tidak dipakai ulang. */
create or replace function public.batalkan_surat_masuk(p_id uuid, p_alasan text)
returns void language plpgsql volatile security definer set search_path = public as $$
declare s incoming_letters%rowtype;
begin
  if not public.boleh_kelola_persuratan() then raise exception 'Anda tidak berwenang membatalkan pencatatan surat.' using errcode = '42501'; end if;
  if length(trim(coalesce(p_alasan, ''))) < 5 then raise exception 'Tuliskan alasan pembatalan (minimal 5 huruf).'; end if;
  select * into s from incoming_letters where id = p_id for update;
  if s.id is null then raise exception 'Surat tidak ditemukan.'; end if;
  if exists (select 1 from letter_dispositions where letter_id = p_id) then raise exception 'Surat yang sudah didisposisi tidak dapat dibatalkan.'; end if;
  update incoming_letters set status = 'batal', catatan_selesai = trim(p_alasan), selesai_pada = now() where id = p_id;
  if s.tujuan_id is not null and s.tujuan_id <> public.saya() and s.status = 'diteruskan' then
    perform public.kirim_notifikasi(s.tujuan_id, 'Surat masuk dibatalkan TU', 'Agenda ' || s.nomor_agenda || ': ' || trim(p_alasan), '/persuratan/untuk-saya', 'XCircle', 'abu');
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 5. DISPOSISI
-- ---------------------------------------------------------------------
/** Pimpinan penerima menutup surat tanpa disposisi (cukup diketahui). */
create or replace function public.selesaikan_surat_masuk(p_id uuid, p_catatan text default null)
returns void language plpgsql volatile security definer set search_path = public as $$
declare s incoming_letters%rowtype;
begin
  select * into s from incoming_letters where id = p_id for update;
  if s.id is null then raise exception 'Surat tidak ditemukan.'; end if;
  if s.tujuan_id is distinct from public.saya() and not public.is_superadmin() then raise exception 'Hanya pimpinan penerima surat yang dapat menutup surat ini.' using errcode = '42501'; end if;
  if s.status <> 'diteruskan' then raise exception 'Surat ini sudah didisposisi atau tidak lagi menunggu keputusan.'; end if;
  update incoming_letters set status = 'selesai', selesai_pada = now(), dibaca_tujuan = coalesce(dibaca_tujuan, now()),
         catatan_selesai = coalesce(nullif(trim(p_catatan), ''), 'Cukup diketahui') where id = p_id;
  if s.dicatat_oleh is not null and s.dicatat_oleh <> public.saya() then
    perform public.kirim_notifikasi(s.dicatat_oleh, 'Surat masuk selesai (cukup diketahui)', 'Agenda ' || s.nomor_agenda || ' – ' || s.perihal,
      '/persuratan/masuk?surat=' || s.id, 'CheckCircle', 'hijau');
  end if;
end $$;

/** p: {surat_id, induk_id (disposisi saya bila meneruskan), kepada: [uuid], instruksi: [teks], catatan, batas} */
create or replace function public.beri_disposisi(p jsonb)
returns int language plpgsql volatile security definer set search_path = public as $$
declare s incoming_letters%rowtype; v_induk letter_dispositions%rowtype; v_induk_id uuid := nullif(p->>'induk_id', '')::uuid;
        v_kepada uuid[]; v_ins text[]; v_batas date := nullif(p->>'batas', '')::date; k uuid; n int := 0; v_dari text;
begin
  select * into s from incoming_letters where id = (p->>'surat_id')::uuid for update;
  if s.id is null then raise exception 'Surat tidak ditemukan.'; end if;
  if s.status in ('selesai','diarsipkan','batal') then raise exception 'Surat ini sudah selesai atau diarsipkan.'; end if;
  if v_induk_id is null then
    if s.tujuan_id is distinct from public.saya() and not public.is_superadmin() then raise exception 'Hanya pimpinan penerima surat yang dapat memberi disposisi.' using errcode = '42501'; end if;
  else
    select * into v_induk from letter_dispositions where id = v_induk_id and letter_id = s.id;
    if v_induk.id is null or v_induk.kepada_id <> public.saya() then raise exception 'Anda hanya dapat meneruskan disposisi yang ditujukan kepada Anda.' using errcode = '42501'; end if;
    if v_induk.status = 'selesai' then raise exception 'Disposisi Anda sudah selesai; tidak dapat diteruskan lagi.'; end if;
  end if;
  select coalesce(array_agg(distinct x::uuid), '{}') into v_kepada from jsonb_array_elements_text(coalesce(p->'kepada', '[]')) x;
  if cardinality(v_kepada) = 0 then raise exception 'Pilih minimal satu penerima disposisi.'; end if;
  if public.saya() = any(v_kepada) then raise exception 'Disposisi tidak dapat ditujukan kepada diri sendiri.'; end if;
  if exists (select 1 from unnest(v_kepada) x where not exists (select 1 from employees e where e.id = x and e.status_akun = 'aktif')) then
    raise exception 'Penerima disposisi harus pegawai dengan akun aktif.'; end if;
  select coalesce(array_agg(trim(x) order by o), '{}') into v_ins from jsonb_array_elements_text(coalesce(p->'instruksi', '[]')) with ordinality t(x, o) where trim(x) <> '';
  if cardinality(v_ins) = 0 and length(trim(coalesce(p->>'catatan', ''))) < 3 then raise exception 'Pilih instruksi atau tuliskan catatan disposisi.'; end if;
  if v_batas is not null and v_batas < public.hari_ini() then raise exception 'Batas waktu tidak boleh sebelum hari ini.'; end if;
  select nama_lengkap into v_dari from employees where id = public.saya();
  foreach k in array v_kepada loop
    if exists (select 1 from letter_dispositions where letter_id = s.id and dari_id = public.saya() and kepada_id = k) then continue; end if;
    insert into letter_dispositions (letter_id, induk_id, dari_id, kepada_id, instruksi, catatan, batas)
    values (s.id, v_induk_id, public.saya(), k, v_ins, nullif(trim(p->>'catatan'), ''), v_batas);
    perform public.kirim_notifikasi(k, case when s.sifat = 'segera' then 'SEGERA: disposisi surat' else 'Disposisi surat dari ' || coalesce(v_dari, 'pimpinan') end,
      case when s.sifat = 'rahasia' then 'Surat bersifat rahasia. Buka SIMKA PRO untuk membaca.'
           else coalesce(array_to_string(v_ins, ', ') || ' – ', '') || s.perihal end
        || case when v_batas is not null then ' (batas ' || to_char(v_batas, 'DD/MM/YYYY') || ')' else '' end,
      '/persuratan/untuk-saya?surat=' || s.id, 'Stamp', case when s.sifat in ('segera','rahasia') then 'merah' else 'jingga' end);
    n := n + 1;
  end loop;
  if n = 0 then raise exception 'Penerima tersebut sudah menerima disposisi Anda untuk surat ini.'; end if;
  update incoming_letters set status = 'didisposisi', dibaca_tujuan = case when v_induk_id is null then coalesce(dibaca_tujuan, now()) else dibaca_tujuan end where id = s.id;
  if v_induk_id is not null and v_induk.status = 'baru' then update letter_dispositions set status = 'dibaca', dibaca_pada = now() where id = v_induk_id; end if;
  return n;
end $$;

/** Tarik disposisi yang salah kirim (belum selesai dan belum diteruskan). */
create or replace function public.tarik_disposisi(p_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare d letter_dispositions%rowtype; s incoming_letters%rowtype;
begin
  select * into d from letter_dispositions where id = p_id for update;
  if d.id is null then raise exception 'Disposisi tidak ditemukan.'; end if;
  if d.dari_id <> public.saya() and not public.is_superadmin() then raise exception 'Hanya pemberi disposisi yang dapat menariknya.' using errcode = '42501'; end if;
  if d.status = 'selesai' then raise exception 'Disposisi yang sudah selesai tidak dapat ditarik.'; end if;
  if exists (select 1 from letter_dispositions where induk_id = p_id) then raise exception 'Disposisi ini sudah diteruskan penerimanya; tidak dapat ditarik.'; end if;
  select * into s from incoming_letters where id = d.letter_id;
  delete from letter_dispositions where id = p_id;
  perform public.kirim_notifikasi(d.kepada_id, 'Disposisi ditarik kembali', 'Agenda ' || s.nomor_agenda || case when s.sifat = 'rahasia' then '' else ' – ' || s.perihal end,
    '/persuratan/untuk-saya', 'XCircle', 'abu');
  if not exists (select 1 from letter_dispositions where letter_id = s.id) then update incoming_letters set status = 'diteruskan' where id = s.id; end if;
end $$;

create or replace function public._cek_surat_selesai(p_surat uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare s incoming_letters%rowtype;
begin
  select * into s from incoming_letters where id = p_surat for update;
  if s.status = 'didisposisi' and exists (select 1 from letter_dispositions where letter_id = p_surat)
     and not exists (select 1 from letter_dispositions where letter_id = p_surat and status <> 'selesai') then
    update incoming_letters set status = 'selesai', selesai_pada = now() where id = p_surat;
    if s.dicatat_oleh is not null and s.dicatat_oleh <> public.saya() then
      perform public.kirim_notifikasi(s.dicatat_oleh, 'Surat masuk selesai ditindaklanjuti', 'Agenda ' || s.nomor_agenda || case when s.sifat = 'rahasia' then '' else ' – ' || s.perihal end,
        '/persuratan/masuk?surat=' || s.id, 'CheckCircle', 'hijau');
    end if;
    if s.tujuan_id is not null and s.tujuan_id <> public.saya() then
      perform public.kirim_notifikasi(s.tujuan_id, 'Semua disposisi surat selesai', 'Agenda ' || s.nomor_agenda || case when s.sifat = 'rahasia' then '' else ' – ' || s.perihal end,
        '/persuratan/untuk-saya?surat=' || s.id, 'CheckCircle', 'hijau');
    end if;
  end if;
end $$;

create or replace function public.selesaikan_disposisi(p_id uuid, p_laporan text)
returns void language plpgsql volatile security definer set search_path = public as $$
declare d letter_dispositions%rowtype; s incoming_letters%rowtype; v_nama text;
begin
  select * into d from letter_dispositions where id = p_id for update;
  if d.id is null then raise exception 'Disposisi tidak ditemukan.'; end if;
  if d.kepada_id <> public.saya() then raise exception 'Hanya penerima disposisi yang dapat menandai selesai.' using errcode = '42501'; end if;
  if d.status = 'selesai' then raise exception 'Disposisi ini sudah selesai.'; end if;
  if length(trim(coalesce(p_laporan, ''))) < 5 then raise exception 'Tuliskan laporan tindak lanjut (minimal 5 huruf).'; end if;
  if exists (select 1 from letter_dispositions where induk_id = p_id and status <> 'selesai') then
    raise exception 'Masih ada disposisi lanjutan dari Anda yang belum selesai.'; end if;
  update letter_dispositions set status = 'selesai', selesai_pada = now(), dibaca_pada = coalesce(dibaca_pada, now()), laporan = trim(p_laporan) where id = p_id;
  select * into s from incoming_letters where id = d.letter_id;
  select nama_lengkap into v_nama from employees where id = public.saya();
  perform public.kirim_notifikasi(d.dari_id, 'Disposisi selesai: ' || coalesce(v_nama, ''), left(trim(p_laporan), 160),
    '/persuratan/untuk-saya?surat=' || s.id, 'CheckCircle', 'hijau');
  perform public._cek_surat_selesai(d.letter_id);
end $$;

/** Tandai dibaca saat penerima membuka rincian surat. */
create or replace function public._tandai_baca_surat(p_id uuid)
returns void language sql volatile security definer set search_path = public as $$
  update letter_dispositions set status = 'dibaca', dibaca_pada = now() where letter_id = p_id and kepada_id = public.saya() and status = 'baru';
  update incoming_letters set dibaca_tujuan = now() where id = p_id and tujuan_id = public.saya() and dibaca_tujuan is null;
$$;

-- ---------------------------------------------------------------------
-- 6. BACA: DAFTAR, RINCIAN, RINGKASAN, BUKU AGENDA
-- ---------------------------------------------------------------------
create or replace function public._surat_json(p_id uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', s.id, 'nomor_agenda', s.nomor_agenda, 'urut_agenda', s.urut_agenda, 'tanggal_terima', s.tanggal_terima,
    'nomor_surat', s.nomor_surat, 'tanggal_surat', s.tanggal_surat, 'pengirim', s.pengirim, 'alamat_pengirim', s.alamat_pengirim, 'perihal', s.perihal,
    'ringkasan', s.ringkasan, 'lampiran', s.lampiran, 'sifat', s.sifat, 'cara', s.cara, 'jumlah_berkas', cardinality(s.berkas_ids),
    'tujuan_id', s.tujuan_id, 'tujuan', te.nama_lengkap, 'tujuan_jabatan', case when s.tujuan_id is not null then public._label_jabatan(s.tujuan_id) end,
    'status', s.status, 'catatan', s.catatan, 'catatan_selesai', s.catatan_selesai, 'dibaca_tujuan', s.dibaca_tujuan,
    'dicatat_oleh', ce.nama_lengkap, 'created_at', s.created_at, 'selesai_pada', s.selesai_pada,
    'disposisi_ringkas', coalesce((select jsonb_agg(jsonb_build_object('kepada', ke.nama_lengkap, 'status', d.status) order by d.created_at)
                                     from letter_dispositions d join employees ke on ke.id = d.kepada_id where d.letter_id = s.id and d.induk_id is null), '[]'::jsonb),
    'jumlah_disposisi', (select count(*) from letter_dispositions d where d.letter_id = s.id),
    'disposisi_terbuka', (select count(*) from letter_dispositions d where d.letter_id = s.id and d.status <> 'selesai'),
    'lewat_batas', exists (select 1 from letter_dispositions d where d.letter_id = s.id and d.status <> 'selesai' and d.batas < public.hari_ini()),
    'peran_saya', case when s.tujuan_id = public.saya() then 'tujuan'
                       when exists (select 1 from letter_dispositions d where d.letter_id = s.id and d.kepada_id = public.saya()) then 'penerima'
                       when exists (select 1 from letter_dispositions d where d.letter_id = s.id and d.dari_id = public.saya()) then 'pemberi' end,
    'perlu_tindakan', (s.tujuan_id = public.saya() and s.status = 'diteruskan')
                      or exists (select 1 from letter_dispositions d where d.letter_id = s.id and d.kepada_id = public.saya() and d.status <> 'selesai'),
    'batas_saya', (select min(d.batas) from letter_dispositions d where d.letter_id = s.id and d.kepada_id = public.saya() and d.status <> 'selesai'),
    'baru_saya', (s.tujuan_id = public.saya() and s.status = 'diteruskan' and s.dibaca_tujuan is null)
                 or exists (select 1 from letter_dispositions d where d.letter_id = s.id and d.kepada_id = public.saya() and d.status = 'baru'))
    from incoming_letters s left join employees te on te.id = s.tujuan_id left join employees ce on ce.id = s.dicatat_oleh
   where s.id = p_id
$$;

/** cakupan: masuk (semua surat yang boleh dibaca; rentang tanggal terima) | untuk_saya (perlu tindakan saya + yang melibatkan saya). */
create or replace function public.daftar_surat_masuk(p_cakupan text, p_mulai date default null, p_selesai date default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_mulai date := coalesce(p_mulai, public.hari_ini() - 90); v_selesai date := coalesce(p_selesai, public.hari_ini());
begin
  if public.saya() is null then return '[]'::jsonb; end if;
  if p_cakupan = 'untuk_saya' then
    return coalesce((select jsonb_agg(public._surat_json(s.id) order by
        ((s.tujuan_id = public.saya() and s.status = 'diteruskan')
          or exists (select 1 from letter_dispositions d where d.letter_id = s.id and d.kepada_id = public.saya() and d.status <> 'selesai')) desc,
        s.tanggal_terima desc, s.urut_agenda desc)
      from incoming_letters s
     where s.status <> 'batal' and public.saya() in (select public._pihak_surat(s.id))
       and ((s.tujuan_id = public.saya() and s.status = 'diteruskan')
            or exists (select 1 from letter_dispositions d where d.letter_id = s.id and d.kepada_id = public.saya() and d.status <> 'selesai')
            or s.tanggal_terima between v_mulai and v_selesai)), '[]'::jsonb);
  end if;
  return coalesce((select jsonb_agg(public._surat_json(s.id) order by s.tanggal_terima desc, s.periode desc, s.urut_agenda desc)
    from incoming_letters s where s.tanggal_terima between v_mulai and v_selesai and public.boleh_baca_surat(s.id)), '[]'::jsonb);
end $$;

create or replace function public.rincian_surat_masuk(p_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare s incoming_letters%rowtype; v_kelola boolean := public.boleh_kelola_persuratan(); v_rahasia_tertutup boolean;
begin
  select * into s from incoming_letters where id = p_id;
  if s.id is null or not public.boleh_baca_surat(p_id) then raise exception 'Surat tidak ditemukan atau Anda tidak berwenang membacanya.' using errcode = '42501'; end if;
  perform public._tandai_baca_surat(p_id);
  return public._surat_json(p_id) || jsonb_build_object(
    'berkas_ids', to_jsonb(s.berkas_ids),
    'disposisi', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'induk_id', d.induk_id, 'dari_id', d.dari_id, 'dari', de.nama_lengkap,
        'dari_jabatan', public._label_jabatan(d.dari_id), 'kepada_id', d.kepada_id, 'kepada', ke.nama_lengkap, 'kepada_jabatan', public._label_jabatan(d.kepada_id),
        'instruksi', to_jsonb(d.instruksi), 'catatan', d.catatan, 'batas', d.batas, 'status', d.status, 'dibaca_pada', d.dibaca_pada,
        'selesai_pada', d.selesai_pada, 'laporan', d.laporan, 'created_at', d.created_at,
        'lewat', d.status <> 'selesai' and d.batas < public.hari_ini(),
        'saya_penerima', d.kepada_id = public.saya(), 'saya_pemberi', d.dari_id = public.saya(),
        'boleh_tarik', (d.dari_id = public.saya() or public.is_superadmin()) and d.status <> 'selesai'
                       and not exists (select 1 from letter_dispositions c where c.induk_id = d.id)) order by d.created_at)
      from letter_dispositions d join employees de on de.id = d.dari_id join employees ke on ke.id = d.kepada_id where d.letter_id = p_id), '[]'::jsonb),
    'boleh', jsonb_build_object(
      'ubah', v_kelola and s.status in ('diteruskan','diarsipkan') and not exists (select 1 from letter_dispositions where letter_id = p_id),
      'batal', v_kelola and s.status in ('diteruskan','diarsipkan') and not exists (select 1 from letter_dispositions where letter_id = p_id),
      'disposisi', s.status in ('diteruskan','didisposisi') and (s.tujuan_id = public.saya() or public.is_superadmin()),
      'tutup', s.status = 'diteruskan' and (s.tujuan_id = public.saya() or public.is_superadmin()),
      'cetak', v_kelola or s.tujuan_id = public.saya() or public.saya() in (select public._puncak_surat())));
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
    'kelola', v_kelola);
end $$;

/** Buku agenda surat masuk per rentang tanggal terima: pengelola dan pimpinan puncak. */
create or replace function public.buku_agenda_masuk(p_mulai date, p_selesai date)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not (public.boleh_kelola_persuratan() or public.saya() in (select public._puncak_surat())) then
    raise exception 'Buku agenda hanya dapat dibuka Tata Usaha dan pimpinan.' using errcode = '42501'; end if;
  if p_selesai < p_mulai then raise exception 'Rentang tanggal tidak sah.'; end if;
  if p_selesai - p_mulai > 400 then raise exception 'Rentang buku agenda paling lama satu tahun.'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('nomor_agenda', s.nomor_agenda, 'tanggal_terima', s.tanggal_terima, 'nomor_surat', s.nomor_surat,
      'tanggal_surat', s.tanggal_surat, 'pengirim', s.pengirim, 'perihal', case when s.sifat = 'rahasia' and not public.boleh_baca_surat(s.id) then '(Rahasia)' else s.perihal end,
      'sifat', s.sifat, 'status', s.status, 'tujuan', te.nama_lengkap,
      'disposisi', (select string_agg(ke.nama_lengkap, '; ' order by d.created_at) from letter_dispositions d join employees ke on ke.id = d.kepada_id
                     where d.letter_id = s.id and d.induk_id is null)) order by s.tanggal_terima, s.periode, s.urut_agenda)
    from incoming_letters s left join employees te on te.id = s.tujuan_id
   where s.tanggal_terima between p_mulai and p_selesai), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- 7. PENGINGAT BATAS WAKTU DISPOSISI (pukul 07.00 WITA)
-- ---------------------------------------------------------------------
create or replace function public.pengingat_disposisi()
returns int language plpgsql volatile security definer set search_path = public as $$
declare r record; n int := 0;
begin
  -- hari batas: penerima diingatkan sekali
  for r in select d.*, s.nomor_agenda, s.perihal, s.sifat from letter_dispositions d join incoming_letters s on s.id = d.letter_id
            where d.status <> 'selesai' and s.status = 'didisposisi' and d.batas = public.hari_ini() and d.diingatkan < 1 loop
    perform public.kirim_notifikasi(r.kepada_id, 'Batas disposisi hari ini', 'Agenda ' || r.nomor_agenda || case when r.sifat = 'rahasia' then '' else ' – ' || r.perihal end,
      '/persuratan/untuk-saya?surat=' || r.letter_id, 'Clock', 'jingga');
    update letter_dispositions set diingatkan = 1 where id = r.id; n := n + 1;
  end loop;
  -- lewat batas: penerima dan pemberi disposisi dikabari sekali
  for r in select d.*, s.nomor_agenda, s.perihal, s.sifat, ke.nama_lengkap kepada_nama from letter_dispositions d join incoming_letters s on s.id = d.letter_id
             join employees ke on ke.id = d.kepada_id
            where d.status <> 'selesai' and s.status = 'didisposisi' and d.batas < public.hari_ini() and d.diingatkan < 2 loop
    perform public.kirim_notifikasi(r.kepada_id, 'Disposisi lewat batas waktu', 'Agenda ' || r.nomor_agenda || case when r.sifat = 'rahasia' then '' else ' – ' || r.perihal end,
      '/persuratan/untuk-saya?surat=' || r.letter_id, 'WarningCircle', 'merah');
    perform public.kirim_notifikasi(r.dari_id, 'Disposisi belum selesai: ' || r.kepada_nama, 'Agenda ' || r.nomor_agenda || ' lewat batas ' || to_char(r.batas, 'DD/MM/YYYY'),
      '/persuratan/untuk-saya?surat=' || r.letter_id, 'WarningCircle', 'merah');
    update letter_dispositions set diingatkan = 2 where id = r.id; n := n + 1;
  end loop;
  return n;
end $$;

do $$ begin
  if exists (select 1 from cron.job where jobname = 'pengingat-disposisi') then perform cron.unschedule('pengingat-disposisi'); end if;
  perform cron.schedule('pengingat-disposisi', '0 23 * * *', 'select public.pengingat_disposisi()');
end $$;

-- ---------------------------------------------------------------------
-- 8. HAK LIHAT PINDAIAN SURAT (Edge Function "berkas")
-- ---------------------------------------------------------------------
do $$
declare d text := pg_get_functiondef('public.boleh_lihat_berkas(uuid,uuid)'::regprocedure);
  cabang text := $c$
  -- Pindaian surat masuk (Fase 10): hak sama dengan membaca surat, diperiksa sebagai pegawai yang meminta
  if exists (select 1 from incoming_letters il where p_obj = any(il.berkas_ids)) then
    v_sub := current_setting('request.jwt.claim.sub', true);
    perform set_config('request.jwt.claim.sub', coalesce((select user_id::text from employees where id = p_emp), ''), true);
    izin := exists (select 1 from incoming_letters il where p_obj = any(il.berkas_ids) and public.boleh_baca_surat(il.id));
    perform set_config('request.jwt.claim.sub', coalesce(v_sub, ''), true);
    if izin then return true; end if;
  end if;
  return false;
end $c$;
begin
  if position('incoming_letters' in d) > 0 then return; end if;
  if d !~ E'\\n\\s*return false;\\s*\\nend' then raise exception 'boleh_lihat_berkas tidak dikenali; hubungi pengembang.'; end if;
  execute regexp_replace(d, E'\\n\\s*return false;\\s*\\nend', cabang);
end $$;

-- ---------------------------------------------------------------------
-- 9. REALTIME DAN HAK EKSEKUSI
-- ---------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'incoming_letters') then
      alter publication supabase_realtime add table public.incoming_letters; end if;
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'letter_dispositions') then
      alter publication supabase_realtime add table public.letter_dispositions; end if;
  end if;
end $$;

do $$
declare f text;
begin
  foreach f in array array['boleh_kelola_persuratan()','boleh_baca_surat(uuid)','pengaturan_persuratan()','simpan_pengaturan_persuratan(jsonb)',
    'hak_persuratan()','pimpinan_penerima_surat()','pegawai_disposisi()','catat_surat_masuk(jsonb)','ubah_surat_masuk(jsonb)',
    'batalkan_surat_masuk(uuid,text)','selesaikan_surat_masuk(uuid,text)','beri_disposisi(jsonb)','tarik_disposisi(uuid)',
    'selesaikan_disposisi(uuid,text)','daftar_surat_masuk(text,date,date)','rincian_surat_masuk(uuid)','ringkasan_persuratan()',
    'buku_agenda_masuk(date,date)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['_pimpinan_surat()','_puncak_surat()','_label_jabatan(uuid)','_pihak_surat(uuid)','_berkas_sah(jsonb)',
    '_kabari_tujuan_surat(uuid)','_cek_surat_selesai(uuid)','_tandai_baca_surat(uuid)','_surat_json(uuid)','pengingat_disposisi()'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN (hasil yang benar: semua baris "Sesuai")
-- ---------------------------------------------------------------------
select '1. Tabel surat masuk dan disposisi' as pemeriksaan,
       case when to_regclass('public.incoming_letters') is not null and to_regclass('public.letter_dispositions') is not null then 'Sesuai' else 'Periksa' end as hasil
union all select '2. Format nomor agenda surat masuk', case when exists (select 1 from doc_number_formats where kode = 'agenda_masuk' and aktif) then 'Sesuai' else 'Periksa' end
union all select '3. Izin admin kelola_persuratan', case when exists (select 1 from admin_capabilities where kode = 'kelola_persuratan') then 'Sesuai' else 'Periksa' end
union all select '4. Fungsi pencatatan dan disposisi (9)', case when (select count(*) from pg_proc where proname in ('catat_surat_masuk','ubah_surat_masuk','batalkan_surat_masuk',
  'selesaikan_surat_masuk','beri_disposisi','tarik_disposisi','selesaikan_disposisi','rincian_surat_masuk','daftar_surat_masuk')) = 9 then 'Sesuai' else 'Periksa' end
union all select '5. Tabel tertutup untuk tulis langsung (RLS)', case when (select count(*) from pg_policies where tablename in ('incoming_letters','letter_dispositions') and cmd <> 'SELECT') = 0
  and (select bool_and(relrowsecurity) from pg_class where relname in ('incoming_letters','letter_dispositions')) then 'Sesuai' else 'Periksa' end
union all select '6. Hak lihat pindaian surat', case when pg_get_functiondef('public.boleh_lihat_berkas(uuid,uuid)'::regprocedure) like '%incoming_letters%' then 'Sesuai' else 'Periksa' end
union all select '7. Pengingat disposisi terjadwal', case when exists (select 1 from cron.job where jobname = 'pengingat-disposisi') then 'Sesuai' else 'Periksa' end
union all select '8. Pimpinan penerima surat (data)', (select count(*) || ' pimpinan aktif' from public._pimpinan_surat())
union all select '9. Pengelola persuratan (jabatan Tata Usaha)', (select count(*) || ' pegawai' from employee_structurals es join structural_positions sp on sp.id = es.structural_position_id where sp.kode = 'TATA_USAHA');
