-- SIMKA PRO | supabase/migrations/20261016009500_dokumen_tahfizh.sql | v1.0 | Tahap D: suket ujian kenaikan juz, sertifikat hafalan, Sertifikat Tahfizhul Quran | 16/10/2026
-- Dokumen tahfizh bernomor dengan kode validasi (registri dokumen) dan pilihan tanda tangan elektronik atau basah:
--   suket_juz           Surat Keterangan Ujian Kenaikan Juz — dari ujian kenaikan juz yang Tuntas
--   sertifikat_hafalan  Sertifikat Hafalan (sertifikasi berjenjang 5, 10, 15 … juz) — dari ujian sertifikasi yang Tuntas
--   sertifikat_tahfizh  Sertifikat Tahfizhul Quran (ijazah hafalan akhir jenjang, kelas 9/12)
-- Penerbit: penguji ujian tersebut (suket dan sertifikat hafalan), pimpinan/validator/pengatur tahfizh, Tata Usaha, superadmin.
-- Penanda tangan: suket dan sertifikat hafalan = Kepala Bidang Tahfizh + Penguji; Sertifikat Tahfizhul Quran = Direktur.
-- Tanda tangan elektronik masuk kotak Tanda tangan penanda tangan; penanda tangan yang sama dengan penerbit langsung tertanda.
-- Setiap terbit memberi notifikasi kepada Kepala Bidang Tahfizh, Tata Usaha, admin validasi tahfizh, dan superadmin.
-- Nomor: format suket_juz, sertifikat_hafalan, sertifikat_tahfizh (Setelan → Penomoran; urutan sendiri-sendiri).
-- Aman dijalankan ulang.

-- ---------------------------------------------------------------------
-- 1. FORMAT NOMOR DAN PENGATURAN SERTIFIKAT
-- ---------------------------------------------------------------------
insert into public.doc_number_formats (kode, nama, pola, grup_urut, reset) values
  ('suket_juz', 'Surat keterangan ujian kenaikan juz', 'SKJ.{URUT3}/{UNIT}/{BLN_H_ROMAWI}/{THN_H}', 'suket_juz', 'tahun_hijriah'),
  ('sertifikat_hafalan', 'Sertifikat hafalan (sertifikasi juz)', 'SH.{URUT3}/{UNIT}/{BLN_H_ROMAWI}/{THN_H}', 'sertifikat_hafalan', 'tahun_hijriah'),
  ('sertifikat_tahfizh', 'Sertifikat Tahfizhul Quran', '{DK}.{URUT3}/{UNIT}/{BLN_H_ROMAWI}/{THN_H}', 'sertifikat_tahfizh', 'tahun_hijriah')
on conflict (kode) do nothing;

insert into public.institution_settings (kunci, nilai) values ('sertifikat_tahfizh', jsonb_build_object(
  'baris1', 'YAYASAN PESANTREN WAHDAH ISLAMIYAH CABANG GOWA',
  'baris2', 'PONDOK PESANTREN TAHFIZHUL QURAN IMAM ASY-SYATHIBY',
  'baris3', 'WAHDAH ISLAMIYAH GOWA',
  'pembuka', 'Dengan memohon ridho Allah _Subhanahu Wata''ala_, Pondok Pesantren Tahfizhul Quran Imam Asy-Syathiby Wahdah Islamiyah Gowa menerangkan bahwa:',
  'program', 'Telah menyelesaikan Program Tahfizhul Quran di Pondok Pesantren Tahfizhul Quran Imam Asy-Syathiby Wahdah Islamiyah Gowa',
  'penutup', 'Demikian sertifikat ini diberikan sebagai tanda hafalan untuk terus menjaga, mengamalkan dan menyebarkan nilai-nilai Al-Quran.',
  'logo_kiri', '', 'logo_kanan', ''))
on conflict (kunci) do nothing;

-- ---------------------------------------------------------------------
-- 2. TABEL DOKUMEN TAHFIZH
-- ---------------------------------------------------------------------
create table if not exists public.tahfizh_documents (
  id               uuid primary key default gen_random_uuid(),
  jenis            text not null constraint tahfizh_documents_jenis_check check (jenis in ('suket_juz','sertifikat_hafalan','sertifikat_tahfizh')),
  student_id       uuid not null references public.students(id) on delete cascade,
  exam_id          uuid references public.tahfizh_exams(id) on delete set null,
  nomor            text not null,
  tanggal          date not null,
  tanggal_hijriah  text,
  data             jsonb not null,
  mode_ttd         text not null default 'elektronik' constraint tahfizh_documents_mode_check check (mode_ttd in ('elektronik','basah')),
  document_id      uuid references public.document_registry(id) on delete set null,
  status           text not null default 'terbit' constraint tahfizh_documents_status_check check (status in ('terbit','dicabut')),
  alasan_cabut     text,
  dicabut_pada     timestamptz,
  diterbitkan_oleh uuid references public.employees(id) on delete set null,
  created_at       timestamptz not null default now()
);
create unique index if not exists tahfizh_documents_ujian_uidx on public.tahfizh_documents (exam_id, jenis) where exam_id is not null and status = 'terbit';
create unique index if not exists tahfizh_documents_sertifikat_uidx on public.tahfizh_documents (student_id) where jenis = 'sertifikat_tahfizh' and status = 'terbit';
create index if not exists tahfizh_documents_tanggal_idx on public.tahfizh_documents (tanggal desc);
alter table public.tahfizh_documents enable row level security;   -- dibaca lewat fungsi

/** Boleh menerbitkan/mengelola semua dokumen tahfizh (selain penguji ujiannya sendiri). */
create or replace function public.boleh_kelola_dokumen_tahfizh()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_superadmin() or public.boleh_validasi_tahfizh() or public.boleh_atur_tahfizh() or public.boleh_kelola_persuratan()
$$;

/** Penerima kabar dokumen tahfizh: Kepala Bidang Tahfizh, Tata Usaha, admin validasi tahfizh, superadmin. */
create or replace function public._penerima_dokumen_tahfizh()
returns setof uuid language sql stable security definer set search_path = public as $$
  select v from public._validator_tahfizh() v
  union
  select e.id from employees e where e.status_akun = 'aktif' and e.status_keaktifan = 'aktif'
     and ((e.peran = 'admin' and exists (select 1 from admin_permissions p where p.employee_id = e.id and p.kode = 'kelola_persuratan'))
          or e.org_unit_id in (select u.id from org_units u where u.kode = 'TU'))
$$;

/** Pemegang jabatan (Kepala Bidang Tahfizh atau Direktur) beserta nama dan NIY. */
create or replace function public._pejabat_tahfizh(p_kode text)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(
    (select jsonb_build_object('employee_id', e.id, 'nama', e.nama_lengkap, 'niy', e.niy,
              'jabatan', case when p.plt then 'Plt. ' else '' end || case p_kode when 'DIREKTUR' then 'Direktur' else 'Kepala Bidang Tahfizh' end)
       from public.pemegang_jabatan() p join employees e on e.id = p.employee_id left join org_units o on o.id = p.org_unit_id
      where p.kode = p_kode and (p_kode = 'DIREKTUR' or o.kode = 'TAHFIZH')
      order by p.plt, e.nama_lengkap limit 1),
    (select jsonb_build_object('employee_id', s.employee_id, 'nama', s.nama, 'niy', s.niy, 'jabatan', s.jabatan_tertulis)
       from signatories s where s.aktif and s.jabatan_tertulis ilike case p_kode when 'DIREKTUR' then 'Direktur%' else '%Tahfizh%' end
      order by s.urutan limit 1))
$$;

-- ---------------------------------------------------------------------
-- 3. TERBITKAN
-- p: { jenis, exam_id? (suket_juz/sertifikat_hafalan), student_id? (sertifikat_tahfizh), tanggal?, mode: elektronik|basah,
--      predikat? , tanggal_hafal? (sertifikat_tahfizh) }
-- ---------------------------------------------------------------------
create or replace function public.terbitkan_dokumen_tahfizh(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v_saya uuid := public.saya(); v_jenis text := p->>'jenis'; v_mode text := coalesce(nullif(p->>'mode', ''), 'elektronik');
  v_tgl date := coalesce(nullif(p->>'tanggal', '')::date, public.hari_ini()); r tahfizh_exams; s students; v_santri uuid;
  v_data jsonb; v_nomor jsonb; v_h record; v_hafal record; v_ttd jsonb := '[]'::jsonb; t jsonb; v_id uuid; v_doc uuid; v_kode text;
  v_nama_dok text; v_perihal text; v_format text; v_dk text := null; v_sisa int; v_i int := 0; v_total int; v_tgl_hafal date; v_predikat text;
  v_pesan text; v_penguji employees; v_kepala jsonb; v_kelas text; v_halaqah text;
begin
  if v_saya is null then raise exception 'Akun Anda belum aktif.' using errcode = '42501'; end if;
  if v_jenis not in ('suket_juz','sertifikat_hafalan','sertifikat_tahfizh') then raise exception 'Jenis dokumen tahfizh tidak dikenal.'; end if;
  if v_mode not in ('elektronik','basah') then raise exception 'Mode tanda tangan tidak dikenal.'; end if;
  if v_tgl > public.hari_ini() then raise exception 'Tanggal dokumen belum terjadi.'; end if;

  if v_jenis in ('suket_juz','sertifikat_hafalan') then
    select * into r from tahfizh_exams where id = nullif(p->>'exam_id', '')::uuid;
    if r.id is null then raise exception 'Data ujian tidak ditemukan.'; end if;
    if r.jenis <> (case v_jenis when 'suket_juz' then 'kenaikan' else 'sertifikasi' end) then raise exception 'Jenis ujian tidak sesuai dengan dokumen.'; end if;
    if r.status <> 'selesai' or r.hasil <> 'tuntas' then raise exception 'Dokumen hanya diterbitkan untuk ujian yang sudah dinilai Tuntas.'; end if;
    if not (r.penguji_id = v_saya or public.boleh_kelola_dokumen_tahfizh()) then
      raise exception 'Dokumen ini diterbitkan oleh penguji ujian tersebut, pimpinan tahfizh, atau Tata Usaha.' using errcode = '42501';
    end if;
    if exists (select 1 from tahfizh_documents d where d.exam_id = r.id and d.jenis = v_jenis and d.status = 'terbit') then
      raise exception 'Dokumen untuk ujian ini sudah terbit (nomor %). Cetak ulang dari daftar dokumen.',
        (select d.nomor from tahfizh_documents d where d.exam_id = r.id and d.jenis = v_jenis and d.status = 'terbit');
    end if;
    v_santri := r.student_id;
  else
    if not public.boleh_kelola_dokumen_tahfizh() then
      raise exception 'Sertifikat Tahfizhul Quran diterbitkan oleh pimpinan tahfizh, Tata Usaha, atau superadmin.' using errcode = '42501';
    end if;
    v_santri := nullif(p->>'student_id', '')::uuid;
    if exists (select 1 from tahfizh_documents d where d.student_id = v_santri and d.jenis = 'sertifikat_tahfizh' and d.status = 'terbit') then
      raise exception 'Sertifikat Tahfizhul Quran santri ini sudah terbit. Cabut lebih dulu bila perlu diterbitkan ulang.';
    end if;
  end if;
  select * into s from students where id = v_santri;
  if s.id is null then raise exception 'Santri tidak ditemukan.'; end if;
  v_kelas := public._kelompok_santri(s.id, 'kelas'); v_halaqah := public._kelompok_santri(s.id, 'halaqah');

  -- Penanda tangan
  if v_jenis = 'sertifikat_tahfizh' then
    t := public._pejabat_tahfizh('DIREKTUR');
    if t is null then raise exception 'Direktur belum tercatat (Data Pegawai → jabatan struktural, atau Setelan → Penanda tangan).'; end if;
    v_ttd := jsonb_build_array(t);
  else
    v_kepala := public._pejabat_tahfizh('KEPALA_BIDANG');
    if v_kepala is null then raise exception 'Kepala Bidang Tahfizh belum tercatat (Data Pegawai → jabatan struktural, atau Setelan → Penanda tangan).'; end if;
    select * into v_penguji from employees where id = r.penguji_id;
    if v_penguji.id is null then raise exception 'Penguji ujian ini tidak tercatat.'; end if;
    v_ttd := jsonb_build_array(v_kepala || jsonb_build_object('pengantar', 'Mengetahui,'),
                               jsonb_build_object('employee_id', v_penguji.id, 'nama', v_penguji.nama_lengkap, 'niy', v_penguji.niy, 'jabatan', 'Penguji'));
  end if;
  if v_mode = 'elektronik' and exists (select 1 from jsonb_array_elements(v_ttd) x where nullif(x->>'employee_id', '') is null) then
    raise exception 'Penanda tangan belum terhubung dengan akun pegawai. Pilih tanda tangan basah atau hubungkan di Setelan → Penanda tangan.';
  end if;

  -- Isi (salinan beku)
  v_data := jsonb_build_object('nama', s.nama_lengkap, 'nis', s.nis, 'nisn', s.nisn, 'jenis_kelamin', s.jenis_kelamin,
    'tempat_lahir', s.tempat_lahir, 'tanggal_lahir', s.tanggal_lahir, 'jenjang', s.jenjang, 'tingkat', s.tingkat, 'kelas', v_kelas, 'halaqah', v_halaqah,
    'total_juz', (select count(*) from juz_achievements j where j.student_id = s.id), 'penanda', v_ttd);
  if v_jenis <> 'sertifikat_tahfizh' then
    v_data := v_data || jsonb_build_object('juz', to_jsonb(r.juz), 'jenjang_juz', r.jenjang, 'ujian_ke', r.ujian_ke,
      'tanggal_ujian', (coalesce(r.diuji_pada, r.updated_at) at time zone 'Asia/Makassar')::date,
      'nilai_tajwid', r.nilai_tajwid, 'nilai_itqan', r.nilai_itqan, 'nilai_akhir', r.nilai_akhir, 'huruf', r.huruf, 'predikat', r.predikat,
      'predikat_sertifikat', (select pr.deskripsi_sertifikat from predicate_ranges pr where pr.academic_year_id = r.academic_year_id and pr.huruf = r.huruf limit 1),
      'kkm', r.kkm, 'catatan_penguji', r.catatan_penguji, 'penguji', v_penguji.nama_lengkap);
  else
    v_total := (v_data->>'total_juz')::int;
    if v_total < 1 then raise exception 'Santri ini belum memiliki capaian juz resmi.'; end if;
    v_tgl_hafal := coalesce(nullif(p->>'tanggal_hafal', '')::date, (select max(tanggal) from juz_achievements where student_id = s.id), v_tgl);
    v_predikat := nullif(trim(coalesce(p->>'predikat', '')), '');
    if v_predikat is null then raise exception 'Isi predikat sertifikat, misalnya Istimewa (Mumtaz).'; end if;
    select * into v_hafal from public.hijriah(v_tgl_hafal);
    v_data := v_data || jsonb_build_object('tanggal_hafal', v_tgl_hafal, 'tanggal_hafal_hijriah', regexp_replace(v_hafal.teks, '\s*H\.?$', ''),
      'predikat', upper(v_predikat), 'pengaturan', (select nilai from institution_settings where kunci = 'sertifikat_tahfizh'));
    v_dk := 'K';
  end if;

  -- Nomor
  v_format := v_jenis;
  perform set_config('simka.nomor_sistem', '1', true);
  v_nomor := public.ambil_nomor(v_format, v_tgl, coalesce(v_dk, 'D'), null, 'pondok');
  perform set_config('simka.nomor_sistem', '', true);
  select * into v_h from public.hijriah(v_tgl);

  v_nama_dok := case v_jenis when 'suket_juz' then 'Surat Keterangan Ujian Kenaikan Juz' when 'sertifikat_hafalan' then 'Sertifikat Hafalan' else 'Sertifikat Tahfizhul Quran' end;
  v_perihal := case v_jenis when 'suket_juz' then 'Ujian kenaikan juz ' || array_to_string(r.juz, ', ')
                            when 'sertifikat_hafalan' then 'Sertifikasi hafalan ' || r.jenjang || ' juz'
                            else 'Hafalan ' || v_total || ' juz' end;

  insert into tahfizh_documents (jenis, student_id, exam_id, nomor, tanggal, tanggal_hijriah, data, mode_ttd, diterbitkan_oleh)
  values (v_jenis, s.id, r.id, v_nomor->>'nomor', v_tgl, regexp_replace(v_h.teks, '\s*H\.?$', ''), v_data, v_mode, v_saya)
  returning id into v_id;

  -- Registri dokumen + tanda tangan
  v_kode := public._kode_dokumen();
  insert into document_registry (kode, jenis, jenis_nama, nomor, perihal, subjek, kop_kode, status, sidik, ref_tabel, ref_id, diterbitkan_pada, diterbitkan_oleh,
                                 isi, tautan, mode_ttd, diajukan_pada)
  values (v_kode, v_jenis, v_nama_dok, v_nomor->>'nomor', v_perihal, s.nama_lengkap || ' (' || s.nis || ')', 'pondok', 'draf', public._sidik(v_data),
          'tahfizh_documents', v_id, now(), v_saya, v_data, '/tahfizh/dokumen', v_mode, now())
  returning id into v_doc;
  for t in select * from jsonb_array_elements(v_ttd) loop
    v_i := v_i + 1;
    insert into document_signatures (document_id, urutan, posisi, employee_id, nama, jabatan, niy, status, waktu, catatan)
    values (v_doc, v_i, 'kiri', nullif(t->>'employee_id', '')::uuid, t->>'nama', t->>'jabatan', t->>'niy',
            case when v_mode = 'basah' or nullif(t->>'employee_id', '')::uuid = v_saya then 'ditandatangani' else 'menunggu' end,
            case when v_mode = 'elektronik' and nullif(t->>'employee_id', '')::uuid = v_saya then now() end,
            case when v_mode = 'basah' then 'basah' end);
  end loop;
  select count(*) into v_sisa from document_signatures where document_id = v_doc and status <> 'ditandatangani';
  if v_sisa = 0 then update document_registry set status = 'sah' where id = v_doc; end if;
  update tahfizh_documents set document_id = v_doc where id = v_id;

  -- Kabar
  v_pesan := s.nama_lengkap || ' · ' || v_perihal || ' · nomor ' || (v_nomor->>'nomor');
  insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
  select x.employee_id, 'Permintaan tanda tangan: ' || v_nama_dok, v_pesan, '/rekap/tandatangan', 'Signature', 'ungu'
    from document_signatures x where x.document_id = v_doc and x.status = 'menunggu' and x.employee_id is not null;
  insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
  select e, v_nama_dok || ' terbit', v_pesan || '. Siap dicetak.', '/tahfizh/dokumen?dok=' || v_id, 'Certificate', 'emas'
    from public._penerima_dokumen_tahfizh() e
   where e is distinct from v_saya and e not in (select x.employee_id from document_signatures x where x.document_id = v_doc and x.status = 'menunggu' and x.employee_id is not null);
  if v_jenis <> 'sertifikat_tahfizh' and r.direkomendasikan_oleh is not null and r.direkomendasikan_oleh <> v_saya then
    perform public.kirim_notifikasi(r.direkomendasikan_oleh, v_nama_dok || ' terbit: ' || s.nama_lengkap, v_perihal || ' · nomor ' || (v_nomor->>'nomor'),
      '/tahfizh/dokumen?dok=' || v_id, 'Certificate', 'emas');
  end if;
  return jsonb_build_object('id', v_id, 'nomor', v_nomor->>'nomor', 'kode', v_kode, 'status', case when v_sisa = 0 then 'sah' else 'draf' end);
end $$;

-- ---------------------------------------------------------------------
-- 4. DAFTAR, CABUT, CALON SERTIFIKAT
-- ---------------------------------------------------------------------
create or replace function public.daftar_dokumen_tahfizh(p_mulai date default null, p_selesai date default null, p_id uuid default null)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', d.id, 'jenis', d.jenis, 'student_id', d.student_id, 'exam_id', d.exam_id, 'nomor', d.nomor, 'tanggal', d.tanggal,
      'tanggal_hijriah', d.tanggal_hijriah, 'data', d.data, 'mode_ttd', d.mode_ttd, 'status', d.status, 'alasan_cabut', d.alasan_cabut,
      'document_id', d.document_id, 'kode', g.kode, 'status_dokumen', g.status, 'diterbitkan_oleh', e.nama_lengkap, 'created_at', d.created_at,
      'ttd', coalesce((select jsonb_agg(jsonb_build_object('urutan', x.urutan, 'nama', x.nama, 'jabatan', x.jabatan, 'niy', x.niy, 'status', x.status,
                        'waktu', x.waktu, 'basah', x.catatan = 'basah') order by x.urutan) from document_signatures x where x.document_id = d.document_id), '[]'::jsonb),
      'boleh_cabut', d.status = 'terbit' and (public.boleh_kelola_dokumen_tahfizh() or (d.diterbitkan_oleh = public.saya() and g.status = 'draf')))
      order by d.tanggal desc, d.created_at desc), '[]'::jsonb)
    from tahfizh_documents d left join document_registry g on g.id = d.document_id left join employees e on e.id = d.diterbitkan_oleh
   where (p_id is null or d.id = p_id)
     and (p_id is not null or ((p_mulai is null or d.tanggal >= p_mulai) and (p_selesai is null or d.tanggal <= p_selesai)))
     and (public.boleh_kelola_dokumen_tahfizh() or d.diterbitkan_oleh = public.saya()
          or d.student_id in (select public.santri_terlihat())
          or exists (select 1 from document_signatures x where x.document_id = d.document_id and x.employee_id = public.saya())
          or exists (select 1 from tahfizh_exams t where t.id = d.exam_id and t.penguji_id = public.saya()))
$$;

create or replace function public.cabut_dokumen_tahfizh(p_id uuid, p_alasan text)
returns void language plpgsql volatile security definer set search_path = public as $$
declare d tahfizh_documents; g document_registry;
begin
  select * into d from tahfizh_documents where id = p_id for update;
  if d.id is null or d.status <> 'terbit' then raise exception 'Dokumen tidak ditemukan atau sudah dicabut.'; end if;
  select * into g from document_registry where id = d.document_id;
  if not (public.boleh_kelola_dokumen_tahfizh() or (d.diterbitkan_oleh = public.saya() and g.status = 'draf')) then
    raise exception 'Dokumen dicabut oleh pimpinan tahfizh, Tata Usaha, atau superadmin.' using errcode = '42501';
  end if;
  if length(trim(coalesce(p_alasan, ''))) < 5 then raise exception 'Tuliskan alasan pencabutan (minimal 5 huruf).'; end if;
  update tahfizh_documents set status = 'dicabut', alasan_cabut = trim(p_alasan), dicabut_pada = now() where id = p_id;
  update document_registry set status = 'dicabut', dicabut_pada = now(), dicabut_oleh = public.saya(), alasan_cabut = trim(p_alasan) where id = d.document_id;
  perform public.catat_audit('cabut_dokumen_tahfizh', 'tahfizh_documents', p_id::text, d.nomor || ': ' || trim(p_alasan), null);
end $$;

/** Calon Sertifikat Tahfizhul Quran: santri aktif/lulus kelas 9 dan 12 beserta jumlah juz, tanggal juz terakhir, predikat sertifikasi terakhir. */
create or replace function public.calon_sertifikat_tahfizh()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('student_id', s.id, 'nama', s.nama_lengkap, 'nis', s.nis, 'jenis_kelamin', s.jenis_kelamin,
      'jenjang', s.jenjang, 'tingkat', s.tingkat, 'status', s.status, 'kelas', public._kelompok_santri(s.id, 'kelas'),
      'total_juz', (select count(*) from juz_achievements j where j.student_id = s.id),
      'tanggal_hafal', (select max(tanggal) from juz_achievements j where j.student_id = s.id),
      'predikat', (select t.predikat from tahfizh_exams t where t.student_id = s.id and t.jenis = 'sertifikasi' and t.hasil = 'tuntas' order by t.diuji_pada desc limit 1),
      'dokumen_id', (select d.id from tahfizh_documents d where d.student_id = s.id and d.jenis = 'sertifikat_tahfizh' and d.status = 'terbit'))
      order by s.jenjang, s.tingkat, s.nama_lengkap), '[]'::jsonb)
    from students s
   where public.boleh_kelola_dokumen_tahfizh() and s.tingkat in (9, 12) and s.status in ('aktif','lulus')
$$;

/** Hak tahfizh ditambah "dokumen" (kelola dokumen tahfizh: pimpinan/validator/pengatur, Tata Usaha, superadmin). */
create or replace function public.hak_tahfizh()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'atur', public.boleh_atur_tahfizh(),
    'validasi', public.boleh_validasi_tahfizh(),
    'pimpinan', public.pimpinan_tahfizh(),
    'muhaffizh', exists (select 1 from public.kelompok_saya() k join student_groups g on g.id = k where g.jenis = 'halaqah'),
    'penguji_kenaikan', exists (select 1 from public.penguji_tahfizh('kenaikan') p where p.employee_id = public.saya() and p.aktif),
    'penguji_sertifikasi', exists (select 1 from public.penguji_tahfizh('sertifikasi') p where p.employee_id = public.saya() and p.aktif),
    'dokumen', public.boleh_kelola_dokumen_tahfizh(),
    'lihat', public.is_admin() or public.tingkat_fitur('tahfizh') >= 1 or public.tingkat_fitur('data_santri') >= 1 or public.pimpinan_tahfizh()
             or exists (select 1 from public.kelompok_saya() k join student_groups g on g.id = k where g.jenis = 'halaqah'))
$$;

/** Pengaturan kepala Sertifikat Tahfizhul Quran (baris yayasan/pondok, logo, kalimat). */
create or replace function public.simpan_pengaturan_sertifikat_tahfizh(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v jsonb;
begin
  if not (public.boleh_atur_tahfizh() or public.is_superadmin()) then raise exception 'Hanya pengatur tahfizh yang dapat mengubah pengaturan sertifikat.' using errcode = '42501'; end if;
  select coalesce(nilai, '{}'::jsonb) || (p - 'kunci') into v from institution_settings where kunci = 'sertifikat_tahfizh';
  insert into institution_settings (kunci, nilai) values ('sertifikat_tahfizh', coalesce(v, p))
  on conflict (kunci) do update set nilai = excluded.nilai;
  return coalesce(v, p);
end $$;
create or replace function public.pengaturan_sertifikat_tahfizh()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce((select nilai from institution_settings where kunci = 'sertifikat_tahfizh'), '{}'::jsonb)
$$;

-- ---------------------------------------------------------------------
-- 5. HAK EKSEKUSI
-- ---------------------------------------------------------------------
do $$ declare f text; begin
  foreach f in array array['_penerima_dokumen_tahfizh()','_pejabat_tahfizh(text)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
  foreach f in array array['boleh_kelola_dokumen_tahfizh()','terbitkan_dokumen_tahfizh(jsonb)','daftar_dokumen_tahfizh(date,date,uuid)',
    'cabut_dokumen_tahfizh(uuid,text)','calon_sertifikat_tahfizh()','hak_tahfizh()','simpan_pengaturan_sertifikat_tahfizh(jsonb)','pengaturan_sertifikat_tahfizh()'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- PEMERIKSAAN — hasil yang benar: 2 baris "Sesuai"
select '1. Tabel dan fungsi dokumen tahfizh' as pemeriksaan,
       case when to_regclass('public.tahfizh_documents') is not null
             and (select count(*) from pg_proc where proname in ('terbitkan_dokumen_tahfizh','daftar_dokumen_tahfizh','cabut_dokumen_tahfizh','calon_sertifikat_tahfizh')) = 4
            then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Format nomor suket, sertifikat hafalan, Sertifikat Tahfizhul Quran',
       case when (select count(*) from doc_number_formats where kode in ('suket_juz','sertifikat_hafalan','sertifikat_tahfizh')) = 3 then 'Sesuai' else 'Periksa' end;
