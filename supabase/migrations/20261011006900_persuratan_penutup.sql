-- SIMKA PRO | supabase/migrations/20261011006900_persuratan_penutup.sql | v1.0 | Fase 10 – Tahap 3 Penutup: inventaris semua surat dan revisi surat keluar | 11/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 10 · Migrasi 69: Persuratan – penutup fase
--   * Revisi surat keluar: surat yang sudah terbit dapat direvisi oleh Tata Usaha. Revisi dibuat sebagai draf salinan
--     (nomor lama dipertahankan, atau nomor baru bila dipilih), diajukan dan ditandatangani ulang. Saat revisi sah,
--     surat lama berstatus "Direvisi" dan dokumen registrinya menunjuk dokumen pengganti (Cek Keabsahan menampilkannya).
--   * Buku agenda surat keluar menjadi INVENTARIS SEMUA SURAT: surat Tata Usaha + surat yang terbit di modul lain
--     (surat pengajuan pegawai, surat keterangan sakit klinik, surat keterangan pindah santri, laporan resmi bertanda tangan)
--     lengkap dengan sumber dan tautan ke tempat asalnya.
--   * Perbaikan: nomor yang sudah ada (revisi dengan nomor lama) tetap menerbitkan surat.
-- Jalankan SETELAH migrasi 6800. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. KOLOM DAN STATUS REVISI
-- ---------------------------------------------------------------------
alter table public.outgoing_letters add column if not exists revisi_dari uuid references public.outgoing_letters(id) on delete set null;
alter table public.outgoing_letters add column if not exists revisi_ke smallint not null default 0;
alter table public.outgoing_letters add column if not exists alasan_revisi text;
create index if not exists ol_revisi_idx on public.outgoing_letters (revisi_dari) where revisi_dari is not null;

do $$
declare c text;
begin
  for c in select conname from pg_constraint where conrelid = 'public.outgoing_letters'::regclass and contype = 'c'
            and pg_get_constraintdef(oid) like '%status%' and pg_get_constraintdef(oid) like '%menunggu_ttd%' loop
    execute format('alter table public.outgoing_letters drop constraint %I', c);
  end loop;
  alter table public.outgoing_letters add constraint outgoing_letters_status_check
    check (status in ('draf','diperiksa','menunggu_ttd','terbit','ditolak','dibatalkan','dicabut','direvisi'));
end $$;

-- ---------------------------------------------------------------------
-- 2. HAK BACA: surat direvisi tetap dapat dibaca pimpinan puncak
-- ---------------------------------------------------------------------
create or replace function public.boleh_baca_surat_keluar(p_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.boleh_kelola_persuratan()
      or exists (select 1 from outgoing_letters o where o.id = p_id and (o.disusun_oleh = public.saya() or o.pemohon_id = public.saya()
                 or exists (select 1 from jsonb_array_elements(o.penanda) x where (x->>'employee_id')::uuid = public.saya())
                 or (o.status in ('terbit','dicabut','direvisi') and public.saya() in (select public._puncak_surat()))))
$$;

-- ---------------------------------------------------------------------
-- 3. NOMOR: nomor yang sudah ada (revisi bernomor lama) tetap menerbitkan surat
-- ---------------------------------------------------------------------
create or replace function public._nomor_surat_keluar(p_id uuid)
returns text language plpgsql volatile security definer set search_path = public as $$
declare o outgoing_letters%rowtype; v jsonb; v_lama text := current_setting('simka.nomor_sistem', true); v_nomor text;
begin
  select * into o from outgoing_letters where id = p_id for update;
  v_nomor := o.nomor;
  if v_nomor is null then
    perform set_config('simka.nomor_sistem', '1', true);
    v := public.ambil_nomor(o.format_nomor, o.tanggal_surat, o.dk, o.perihal_kode, o.kop_kode);
    perform set_config('simka.nomor_sistem', coalesce(v_lama, ''), true);
    v_nomor := v->>'nomor';
  end if;
  update outgoing_letters set nomor = v_nomor, status = 'terbit', terbit_pada = coalesce(terbit_pada, now()) where id = p_id;
  return v_nomor;
end $$;

-- ---------------------------------------------------------------------
-- 4. PEMICU REGISTRI: revisi sah → surat lama "Direvisi"
-- ---------------------------------------------------------------------
create or replace function public.tg_registri_surat_keluar()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_nomor text; o outgoing_letters%rowtype; v_doc_lama uuid;
begin
  if new.jenis <> 'surat_keluar' or new.ref_id is null or new.status is not distinct from old.status then return new; end if;
  select * into o from outgoing_letters where id = new.ref_id;
  if o.id is null then return new; end if;
  if new.status = 'sah' then
    v_nomor := public._nomor_surat_keluar(o.id);
    new.nomor := v_nomor;
    new.isi := coalesce(new.isi, '{}'::jsonb) || jsonb_build_object('nomor', v_nomor);
    insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
    select distinct x, case when o.revisi_dari is null then 'Surat keluar telah sah' else 'Revisi surat keluar telah sah' end,
           o.jenis_nama || ' – ' || o.perihal || ' (' || v_nomor || ')', '/persuratan/keluar?surat=' || o.id, 'SealCheck', 'hijau'
      from unnest(array[o.disusun_oleh, o.pemohon_id]) x where x is not null and x <> new.diterbitkan_oleh;
    -- Revisi: surat dan dokumen sebelumnya diganti
    if o.revisi_dari is not null then
      select document_id into v_doc_lama from outgoing_letters where id = o.revisi_dari;
      update outgoing_letters set status = 'direvisi', catatan = 'Diganti revisi ke-' || o.revisi_ke || coalesce(': ' || o.alasan_revisi, '')
       where id = o.revisi_dari and status = 'terbit';
      if v_doc_lama is not null then
        update document_registry set status = 'direvisi', pengganti_id = new.id where id = v_doc_lama and status = 'sah';
      end if;
    end if;
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

-- ---------------------------------------------------------------------
-- 5. REVISI SURAT KELUAR (Tata Usaha)
-- ---------------------------------------------------------------------
/** Membuat draf revisi dari surat terbit. p_nomor_baru = true → nomor baru diambil saat revisi sah; false → nomor lama dipakai.
    Bila draf revisi yang belum selesai sudah ada, id draf itu yang dikembalikan. */
create or replace function public.revisi_surat_keluar(p_id uuid, p_alasan text, p_nomor_baru boolean default false)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare o outgoing_letters%rowtype; v_id uuid;
begin
  if not public.boleh_kelola_persuratan() then raise exception 'Hanya Tata Usaha yang dapat merevisi surat keluar.' using errcode = '42501'; end if;
  select * into o from outgoing_letters where id = p_id for update;
  if o.id is null then raise exception 'Surat tidak ditemukan.'; end if;
  if o.status <> 'terbit' then raise exception 'Hanya surat yang sudah terbit yang dapat direvisi.'; end if;
  select id into v_id from outgoing_letters where revisi_dari = p_id and status in ('draf','diperiksa','menunggu_ttd','ditolak') order by created_at desc limit 1;
  if v_id is not null then return v_id; end if;
  if length(trim(coalesce(p_alasan, ''))) < 5 then raise exception 'Tuliskan alasan revisi (minimal 5 huruf).'; end if;
  insert into outgoing_letters (template_id, jenis_nama, kategori, kop_kode, dk, perihal_kode, format_nomor, tanggal_surat, perihal, kepada, lampiran,
                                tembusan, narahubung, nilai, tampilan, penanda, mode_ttd, nomor, status, catatan, disusun_oleh, pemohon_id,
                                revisi_dari, revisi_ke, alasan_revisi)
  values (o.template_id, o.jenis_nama, o.kategori, o.kop_kode, o.dk, o.perihal_kode, o.format_nomor,
          case when coalesce(p_nomor_baru, false) then public.hari_ini() else o.tanggal_surat end,
          o.perihal, o.kepada, o.lampiran, o.tembusan, o.narahubung, o.nilai, o.tampilan, o.penanda, o.mode_ttd,
          case when coalesce(p_nomor_baru, false) then null else o.nomor end, 'draf', 'Revisi: ' || trim(p_alasan),
          public.saya(), o.pemohon_id, o.id, o.revisi_ke + 1, trim(p_alasan))
  returning id into v_id;
  return v_id;
end $$;

-- ---------------------------------------------------------------------
-- 6. JSON, RINCIAN, DAFTAR (informasi revisi)
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
    'revisi_ke', o.revisi_ke, 'revisi_dari', o.revisi_dari, 'alasan_revisi', o.alasan_revisi,
    'revisi_dari_nomor', (select x.nomor from outgoing_letters x where x.id = o.revisi_dari),
    'pengganti', (select jsonb_build_object('id', x.id, 'status', x.status, 'nomor', x.nomor, 'revisi_ke', x.revisi_ke)
                    from outgoing_letters x where x.revisi_dari = o.id and x.status <> 'dibatalkan' order by x.created_at desc limit 1),
    'menunggu_saya', exists (select 1 from document_signatures s where s.document_id = o.document_id and s.employee_id = public.saya() and s.status = 'menunggu')
                     and d.status = 'draf')
    from outgoing_letters o left join employees de on de.id = o.disusun_oleh left join document_registry d on d.id = o.document_id
   where o.id = p_id
$$;

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
       'pengganti', (select x.kode from document_registry x where x.id = d.pengganti_id),
       'penanda', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'posisi', s.posisi, 'urutan', s.urutan, 'employee_id', s.employee_id, 'nama', s.nama,
          'jabatan', s.jabatan, 'niy', s.niy, 'status', s.status, 'waktu', s.waktu, 'catatan', s.catatan) order by s.urutan)
          from document_signatures s where s.document_id = d.id), '[]'::jsonb)) end,
    'boleh', jsonb_build_object(
      'ubah', o.status in ('draf','ditolak') and (o.disusun_oleh = public.saya() or v_kelola) or (o.status = 'diperiksa' and v_kelola),
      'kirim_tu', o.status in ('draf','ditolak') and o.disusun_oleh = public.saya() and not v_kelola,
      'ajukan', v_kelola and o.status in ('draf','diperiksa','ditolak'),
      'batal', o.status in ('draf','diperiksa','ditolak','menunggu_ttd') and (o.disusun_oleh = public.saya() or v_kelola),
      'arsip', v_kelola and o.status = 'terbit',
      'revisi', v_kelola and o.status = 'terbit',
      'tanda_tangan', d.status = 'draf' and exists (select 1 from document_signatures s where s.document_id = d.id and s.employee_id = public.saya() and s.status = 'menunggu')));
end $$;

-- ---------------------------------------------------------------------
-- 7. INVENTARIS SEMUA SURAT KELUAR (buku agenda surat keluar)
--    sumber: tu (Persuratan) | pengajuan (surat pengajuan pegawai) | klinik (surat keterangan sakit)
--            santri (surat keterangan pindah) | laporan (laporan resmi bertanda tangan)
-- ---------------------------------------------------------------------
create or replace function public.buku_agenda_keluar(p_mulai date, p_selesai date)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not (public.boleh_kelola_persuratan() or public.saya() in (select public._puncak_surat())) then
    raise exception 'Buku agenda hanya dapat dibuka Tata Usaha dan pimpinan.' using errcode = '42501'; end if;
  if p_selesai < p_mulai then raise exception 'Rentang tanggal tidak sah.'; end if;
  if p_selesai - p_mulai > 400 then raise exception 'Rentang buku agenda paling lama satu tahun.'; end if;
  return coalesce((select jsonb_agg(x order by x->>'tanggal_surat', x->>'urut') from (
    -- a. Surat Tata Usaha (Persuratan)
    select jsonb_build_object('sumber', 'tu', 'sumber_nama', 'Persuratan', 'id', o.id, 'document_id', o.document_id, 'nomor', o.nomor,
      'tanggal_surat', o.tanggal_surat, 'jenis_nama', o.jenis_nama, 'perihal', o.perihal, 'kepada', o.kepada,
      'penanda', (select string_agg(p->>'nama', '; ') from jsonb_array_elements(o.penanda) p), 'mode_ttd', o.mode_ttd,
      'status', o.status, 'kode_validasi', d.kode, 'disusun_oleh', de.nama_lengkap, 'pemohon', (select nama_lengkap from employees where id = o.pemohon_id),
      'revisi_ke', o.revisi_ke, 'tautan', '/persuratan/keluar?surat=' || o.id, 'urut', coalesce(o.terbit_pada, o.created_at)::text) as x
      from outgoing_letters o left join document_registry d on d.id = o.document_id left join employees de on de.id = o.disusun_oleh
     where o.status in ('terbit','dicabut','direvisi') and o.tanggal_surat between p_mulai and p_selesai
    union all
    -- b. Dokumen bertanda tangan dari modul lain (registri dokumen)
    select jsonb_build_object('sumber', case when d.jenis = 'pengajuan_pegawai' then 'pengajuan' when d.jenis = 'surat_sakit' then 'klinik' else 'laporan' end,
      'sumber_nama', case when d.jenis = 'pengajuan_pegawai' then 'Pengajuan pegawai' when d.jenis = 'surat_sakit' then 'Klinik' else 'Dokumen resmi' end,
      'id', d.id, 'document_id', d.id, 'nomor', d.nomor, 'tanggal_surat', (d.diterbitkan_pada at time zone 'Asia/Makassar')::date,
      'jenis_nama', d.jenis_nama, 'perihal', coalesce(d.perihal, d.jenis_nama) || coalesce(' (' || d.periode || ')', ''), 'kepada', d.subjek,
      'penanda', (select string_agg(s.nama, '; ' order by s.urutan) from document_signatures s where s.document_id = d.id and s.jabatan is distinct from 'Pemohon'),
      'mode_ttd', coalesce(d.mode_ttd, 'elektronik'),
      'status', case d.status when 'sah' then 'terbit' else d.status end, 'kode_validasi', d.kode,
      'disusun_oleh', (select nama_lengkap from employees where id = d.diterbitkan_oleh), 'pemohon', null, 'revisi_ke', 0,
      'tautan', case when d.jenis = 'pengajuan_pegawai' then '/pengajuan/' || d.ref_id
                     when d.jenis = 'surat_sakit' then '/klinik/riwayat'
                     when d.tautan is not null then d.tautan || '?resmi=' || d.id
                     else '/rekap/dokumen' end,
      'urut', d.diterbitkan_pada::text)
      from document_registry d
     where d.jenis <> 'surat_keluar' and d.status in ('sah','direvisi','dicabut')
       and (d.diterbitkan_pada at time zone 'Asia/Makassar')::date between p_mulai and p_selesai
    union all
    -- c. Surat keterangan pindah santri (mutasi keluar)
    select jsonb_build_object('sumber', 'santri', 'sumber_nama', 'Data santri', 'id', m.id, 'document_id', null, 'nomor', m.nomor_surat,
      'tanggal_surat', m.tanggal, 'jenis_nama', 'Surat Keterangan Pindah', 'perihal', 'Pindah ke ' || coalesce(m.sekolah, '–'),
      'kepada', s.nama_lengkap || coalesce(' (NIS ' || s.nis || ')', ''), 'penanda', null, 'mode_ttd', 'basah', 'status', 'terbit', 'kode_validasi', null,
      'disusun_oleh', (select nama_lengkap from employees where id = m.oleh), 'pemohon', null, 'revisi_ke', 0,
      'tautan', '/santri/' || m.student_id, 'urut', m.created_at::text)
      from student_mutations m join students s on s.id = m.student_id
     where m.jenis = 'keluar' and m.nomor_surat is not null and m.tanggal between p_mulai and p_selesai
  ) q), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- 8. HAK EKSEKUSI
-- ---------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array['boleh_baca_surat_keluar(uuid)','revisi_surat_keluar(uuid,text,boolean)','rincian_surat_keluar(uuid,uuid)','buku_agenda_keluar(date,date)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['_nomor_surat_keluar(uuid)','_surat_keluar_json(uuid)','tg_registri_surat_keluar()'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN (hasil yang benar: baris 1–4 "Sesuai")
-- ---------------------------------------------------------------------
select '1. Kolom revisi surat keluar' as pemeriksaan,
       case when (select count(*) from information_schema.columns where table_schema = 'public' and table_name = 'outgoing_letters'
                   and column_name in ('revisi_dari','revisi_ke','alasan_revisi')) = 3 then 'Sesuai' else 'Periksa' end as hasil
union all select '2. Status "direvisi" diterima', case when exists (select 1 from pg_constraint where conname = 'outgoing_letters_status_check'
  and pg_get_constraintdef(oid) like '%direvisi%') then 'Sesuai' else 'Periksa' end
union all select '3. Fungsi revisi surat keluar', case when to_regprocedure('public.revisi_surat_keluar(uuid,text,boolean)') is not null then 'Sesuai' else 'Periksa' end
union all select '4. Buku agenda memuat surat dari modul lain', case when pg_get_functiondef('public.buku_agenda_keluar(date,date)'::regprocedure) like '%student_mutations%'
  and pg_get_functiondef('public.buku_agenda_keluar(date,date)'::regprocedure) like '%document_registry%' then 'Sesuai' else 'Periksa' end;
