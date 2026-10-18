-- SIMKA PRO | supabase/migrations/20261104012700_khataman.sql | v1.0 | 14.10.0: Khataman Al-Qur'an 30 juz (usul, persetujuan, jadwal, undangan, sertifikat penghargaan) | 18/10/2026
-- =====================================================================
-- SIMKA PRO · Migrasi 127: Khataman Al-Qur'an 30 juz
--   Alur: Muhaffizh mengusulkan santri yang sudah khatam 30 juz beserta usulan jadwal (tanggal, jam) dan tempat
--         → Kepala Bidang Tahfizh menyetujui (boleh mengubah jadwal) atau menolak
--         → terbit Surat Undangan Khataman (untuk diteruskan muhaffizh kepada orang tua) bernomor dan ber-QR
--           dan Sertifikat Penghargaan Khataman (portrait) bertanda tangan elektronik Direktur dan Kepala Bidang Tahfizh,
--           sehingga sertifikat siap diserahkan saat khataman
--         → ubah jadwal (riwayat tersimpan; undangan dan sertifikat ikut diperbarui) → tandai terlaksana
--           (otomatis tercatat sebagai prestasi santri bidang tahfizh).
--   Syarat santri: aktif dan hafalan resmi 30 juz atau posisi setoran sabaq sudah mencapai 30 juz (600 halaman).
--   Template WA: khataman_pengumuman (grup), khataman_undangan_wali (muhaffizh → orang tua), khataman_muhaffizh (kepala → muhaffizh).
--   Nomor: undangan memakai format "surat" kode perihal DW (Da'wah: undangan); sertifikat memakai format baru "sertifikat_khataman".
-- Jalankan SETELAH migrasi 12600. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TABEL, FORMAT NOMOR, PENGATURAN
-- ---------------------------------------------------------------------
create table if not exists public.tahfizh_khataman (
  id               uuid primary key default gen_random_uuid(),
  student_id       uuid not null references public.students(id) on delete cascade,
  academic_year_id uuid references public.academic_years(id) on delete set null,
  status           text not null default 'diusulkan' constraint tahfizh_khataman_status_check
                   check (status in ('diusulkan','dijadwalkan','selesai','ditolak','dibatalkan')),
  jadwal           timestamptz not null,
  tempat           text,
  catatan_usul     text,
  diusulkan_oleh   uuid references public.employees(id) on delete set null,
  diusulkan_pada   timestamptz not null default now(),
  diputus_oleh     uuid references public.employees(id) on delete set null,
  diputus_pada     timestamptz,
  alasan_tolak     text,
  riwayat_jadwal   jsonb not null default '[]'::jsonb,
  undangan_nomor   text,
  undangan_doc     uuid references public.document_registry(id) on delete set null,
  sertifikat_id    uuid,
  selesai_pada     timestamptz,
  catatan_selesai  text,
  alasan_batal     text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create unique index if not exists tahfizh_khataman_aktif_uidx on public.tahfizh_khataman (student_id) where status in ('diusulkan','dijadwalkan','selesai');
create index if not exists tahfizh_khataman_jadwal_idx on public.tahfizh_khataman (jadwal desc);
alter table public.tahfizh_khataman enable row level security;   -- dibaca dan diubah lewat fungsi

alter table public.tahfizh_documents drop constraint if exists tahfizh_documents_jenis_check;
alter table public.tahfizh_documents add constraint tahfizh_documents_jenis_check
  check (jenis in ('suket_juz','sertifikat_hafalan','sertifikat_tahfizh','sertifikat_khataman'));
create unique index if not exists tahfizh_documents_khataman_uidx on public.tahfizh_documents (student_id) where jenis = 'sertifikat_khataman' and status = 'terbit';

insert into public.doc_number_formats (kode, nama, pola, grup_urut, reset) values
  ('sertifikat_khataman', 'Sertifikat penghargaan khataman 30 juz', 'SKH.{URUT3}/{UNIT}/{BLN_H_ROMAWI}/{THN_H}', 'sertifikat_khataman', 'tahun_hijriah')
on conflict (kode) do nothing;

insert into public.institution_settings (kunci, nilai) values ('khataman', jsonb_build_object(
  'tempat_bawaan', 'Masjid Pondok Pesantren Imam Asy-Syathiby',
  'judul', 'SERTIFIKAT PENGHARGAAN',
  'subjudul', 'KHATAMAN AL-QUR''AN 30 JUZ',
  'pembuka', 'Dengan memohon ridho Allah _Subhanahu Wata''ala_, Pondok Pesantren Tahfizhul Quran Imam Asy-Syathiby Wahdah Islamiyah Gowa memberikan penghargaan kepada:',
  'isi', 'atas kesungguhan dan ketekunannya dalam menghafal Al-Qur''an hingga menuntaskan hafalan 30 juz, yang dikhatamkan di hadapan para asatidzah dan santri',
  'doa', 'Semoga Allah menjaga hafalannya, menjadikannya ahlul Qur''an, dan memberkahi kedua orang tuanya dengan mahkota kemuliaan.'))
on conflict (kunci) do nothing;

-- ---------------------------------------------------------------------
-- 2. HAK
-- ---------------------------------------------------------------------
/** Memutus (menyetujui/menolak) dan menjadwal ulang khataman: Kepala Bidang Tahfizh (termasuk Plt), admin validasi tahfizh, superadmin. */
create or replace function public.boleh_putus_khataman()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_superadmin() or public.pimpinan_tahfizh() or public.admin_boleh('validasi_tahfizh')
$$;

/** Hafalan santri sudah 30 juz: juz resmi 30 atau posisi sabaq ≥ 600 halaman. */
create or replace function public._khatam_30(p_santri uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select (select count(*) from juz_achievements where student_id = p_santri) >= 30
      or coalesce((select sabaq_hal from student_tahfizh where student_id = p_santri), 0) >= 600
$$;

-- ---------------------------------------------------------------------
-- 3. DOKUMEN: UNDANGAN DAN SERTIFIKAT (dipanggil dari fungsi lain)
-- ---------------------------------------------------------------------
/** Susun ulang isi undangan di registri dokumen (nomor tetap). Penanda tangan: Kepala Bidang Tahfizh. */
create or replace function public._dok_undangan_khataman(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare k tahfizh_khataman; s students; v_isi jsonb; v_kepala jsonb; v_doc uuid; v_saya uuid := public.saya(); v_nomor jsonb; v_kode text;
begin
  select * into k from tahfizh_khataman where id = p_id;
  select * into s from students where id = k.student_id;
  v_kepala := public._pejabat_tahfizh('KEPALA_BIDANG');
  if k.undangan_nomor is null then
    perform set_config('simka.nomor_sistem', '1', true);
    v_nomor := public.ambil_nomor('surat', public.hari_ini(), 'D', 'DW', 'pondok');
    perform set_config('simka.nomor_sistem', '', true);
    update tahfizh_khataman set undangan_nomor = v_nomor->>'nomor' where id = p_id returning * into k;
  end if;
  v_isi := jsonb_build_object('nomor', k.undangan_nomor, 'nama', s.nama_lengkap, 'nis', s.nis, 'kelas', public._kelompok_santri(s.id, 'kelas'),
    'halaqah', public._kelompok_santri(s.id, 'halaqah'), 'jadwal', k.jadwal, 'tempat', k.tempat, 'penanda', v_kepala);
  if k.undangan_doc is null then
    v_kode := public._kode_dokumen();
    insert into document_registry (kode, jenis, jenis_nama, nomor, perihal, subjek, kop_kode, status, sidik, ref_tabel, ref_id, diterbitkan_pada,
                                   diterbitkan_oleh, isi, tautan, mode_ttd, diajukan_pada)
    values (v_kode, 'undangan_khataman', 'Surat Undangan Khataman Al-Qur''an', k.undangan_nomor,
            'Undangan khataman Al-Qur''an 30 juz, ' || to_char(k.jadwal at time zone 'Asia/Makassar', 'DD/MM/YYYY HH24.MI') || ' WITA',
            s.nama_lengkap || ' (NIS ' || s.nis || ')', 'pondok', 'draf', public._sidik(v_isi), 'tahfizh_khataman', p_id, now(), v_saya, v_isi,
            '/tahfizh/khataman', 'elektronik', now())
    returning id into v_doc;
    update tahfizh_khataman set undangan_doc = v_doc where id = p_id;
  else
    v_doc := k.undangan_doc;
    update document_registry set isi = v_isi, sidik = public._sidik(v_isi), status = 'draf',
           perihal = 'Undangan khataman Al-Qur''an 30 juz, ' || to_char(k.jadwal at time zone 'Asia/Makassar', 'DD/MM/YYYY HH24.MI') || ' WITA'
     where id = v_doc;
  end if;
  delete from document_signatures where document_id = v_doc;
  insert into document_signatures (document_id, urutan, posisi, employee_id, nama, jabatan, niy, status, waktu)
  values (v_doc, 1, 'kanan', nullif(v_kepala->>'employee_id', '')::uuid, coalesce(v_kepala->>'nama', 'Kepala Bidang Tahfizh'),
          coalesce(v_kepala->>'jabatan', 'Kepala Bidang Tahfizh'), v_kepala->>'niy',
          case when nullif(v_kepala->>'employee_id', '')::uuid = v_saya then 'ditandatangani' else 'menunggu' end,
          case when nullif(v_kepala->>'employee_id', '')::uuid = v_saya then now() end);
  if not exists (select 1 from document_signatures where document_id = v_doc and status <> 'ditandatangani') then
    update document_registry set status = 'sah' where id = v_doc;
  else
    insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
    select x.employee_id, 'Permintaan tanda tangan: Undangan Khataman', s.nama_lengkap || ' · nomor ' || k.undangan_nomor, '/rekap/tandatangan', 'Signature', 'ungu'
      from document_signatures x where x.document_id = v_doc and x.status = 'menunggu' and x.employee_id is not null;
  end if;
end $$;

/** Terbitkan atau perbarui Sertifikat Penghargaan Khataman (tanggal = tanggal khataman). Penanda tangan: Direktur (kiri) dan Kepala Bidang Tahfizh. */
create or replace function public._dok_sertifikat_khataman(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare k tahfizh_khataman; s students; v_tgl date; v_h record; v_data jsonb; v_ttd jsonb; t jsonb; v_i int := 0; v_saya uuid := public.saya();
  v_doc uuid; v_dokid uuid; v_nomor jsonb; v_kode text; v_ada tahfizh_documents;
begin
  select * into k from tahfizh_khataman where id = p_id;
  select * into s from students where id = k.student_id;
  v_tgl := (k.jadwal at time zone 'Asia/Makassar')::date;
  select * into v_h from public.hijriah(v_tgl);
  v_ttd := jsonb_build_array(coalesce(public._pejabat_tahfizh('DIREKTUR'), jsonb_build_object('nama', '', 'jabatan', 'Direktur')) || jsonb_build_object('pengantar', 'Mengetahui,'),
                             coalesce(public._pejabat_tahfizh('KEPALA_BIDANG'), jsonb_build_object('nama', '', 'jabatan', 'Kepala Bidang Tahfizh')));
  v_data := jsonb_build_object('nama', s.nama_lengkap, 'nis', s.nis, 'nisn', s.nisn, 'jenis_kelamin', s.jenis_kelamin, 'tempat_lahir', s.tempat_lahir,
    'tanggal_lahir', s.tanggal_lahir, 'jenjang', s.jenjang, 'tingkat', s.tingkat, 'kelas', public._kelompok_santri(s.id, 'kelas'),
    'halaqah', public._kelompok_santri(s.id, 'halaqah'), 'total_juz', greatest(30, (select count(*) from juz_achievements j where j.student_id = s.id)),
    'tanggal_khataman', v_tgl, 'tempat', k.tempat, 'penanda', v_ttd, 'pengaturan', (select nilai from institution_settings where kunci = 'khataman'));
  if k.sertifikat_id is not null then select * into v_ada from tahfizh_documents where id = k.sertifikat_id and status = 'terbit'; end if;
  if v_ada.id is null then
    perform set_config('simka.nomor_sistem', '1', true);
    v_nomor := public.ambil_nomor('sertifikat_khataman', least(v_tgl, public.hari_ini()), 'D', null, 'pondok');
    perform set_config('simka.nomor_sistem', '', true);
    insert into tahfizh_documents (jenis, student_id, nomor, tanggal, tanggal_hijriah, data, mode_ttd, diterbitkan_oleh)
    values ('sertifikat_khataman', s.id, v_nomor->>'nomor', v_tgl, regexp_replace(v_h.teks, '\s*H\.?$', ''), v_data, 'elektronik', v_saya)
    returning id into v_dokid;
    v_kode := public._kode_dokumen();
    insert into document_registry (kode, jenis, jenis_nama, nomor, perihal, subjek, kop_kode, status, sidik, ref_tabel, ref_id, diterbitkan_pada, diterbitkan_oleh,
                                   isi, tautan, mode_ttd, diajukan_pada)
    values (v_kode, 'sertifikat_khataman', 'Sertifikat Penghargaan Khataman', v_nomor->>'nomor', 'Khataman Al-Qur''an 30 juz',
            s.nama_lengkap || ' (' || s.nis || ')', 'pondok', 'draf', public._sidik(v_data), 'tahfizh_documents', v_dokid, now(), v_saya, v_data,
            '/tahfizh/dokumen', 'elektronik', now())
    returning id into v_doc;
    update tahfizh_documents set document_id = v_doc where id = v_dokid;
    update tahfizh_khataman set sertifikat_id = v_dokid where id = p_id;
  else
    v_dokid := v_ada.id; v_doc := v_ada.document_id;
    update tahfizh_documents set tanggal = v_tgl, tanggal_hijriah = regexp_replace(v_h.teks, '\s*H\.?$', ''), data = v_data where id = v_dokid;
    update document_registry set isi = v_data, sidik = public._sidik(v_data), status = 'draf' where id = v_doc;
    delete from document_signatures where document_id = v_doc;
  end if;
  for t in select * from jsonb_array_elements(v_ttd) loop
    v_i := v_i + 1;
    insert into document_signatures (document_id, urutan, posisi, employee_id, nama, jabatan, niy, status, waktu)
    values (v_doc, v_i, 'kiri', nullif(t->>'employee_id', '')::uuid, t->>'nama', t->>'jabatan', t->>'niy',
            case when nullif(t->>'employee_id', '')::uuid = v_saya then 'ditandatangani' else 'menunggu' end,
            case when nullif(t->>'employee_id', '')::uuid = v_saya then now() end);
  end loop;
  if not exists (select 1 from document_signatures where document_id = v_doc and status <> 'ditandatangani') then
    update document_registry set status = 'sah' where id = v_doc;
  else
    insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
    select x.employee_id, 'Permintaan tanda tangan: Sertifikat Khataman', s.nama_lengkap || ' · khataman ' || to_char(v_tgl, 'DD/MM/YYYY'), '/rekap/tandatangan', 'Signature', 'ungu'
      from document_signatures x where x.document_id = v_doc and x.status = 'menunggu' and x.employee_id is not null;
  end if;
end $$;
revoke execute on function public._dok_undangan_khataman(uuid) from public, anon, authenticated;
revoke execute on function public._dok_sertifikat_khataman(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 4. ALUR
-- ---------------------------------------------------------------------
/** Calon khataman: santri aktif yang hafalannya sudah 30 juz dan belum punya khataman berjalan/selesai. */
create or replace function public.calon_khataman()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('student_id', s.id, 'nis', s.nis, 'nama', s.nama_lengkap, 'jenis_kelamin', s.jenis_kelamin,
      'kelas', public._kelompok_santri(s.id, 'kelas'), 'halaqah', public._kelompok_santri(s.id, 'halaqah'),
      'total_resmi', (select count(*) from juz_achievements j where j.student_id = s.id), 'sabaq_hal', t.sabaq_hal) order by s.nama_lengkap), '[]'::jsonb)
    from students s left join student_tahfizh t on t.student_id = s.id
   where s.status = 'aktif' and public._khatam_30(s.id)
     and not exists (select 1 from tahfizh_khataman k where k.student_id = s.id and k.status in ('diusulkan','dijadwalkan','selesai'))
     and (public._muhaffizh_santri(s.id) or public.boleh_putus_khataman() or public.boleh_atur_tahfizh())
$$;

create or replace function public.usulkan_khataman(p jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_saya uuid := public.saya(); v_santri uuid := nullif(p->>'student_id', '')::uuid; v_jadwal timestamptz := nullif(p->>'jadwal', '')::timestamptz;
  s students; v_id uuid;
begin
  if v_saya is null then raise exception 'Akun Anda belum aktif.' using errcode = '42501'; end if;
  select * into s from students where id = v_santri;
  if s.id is null or s.status <> 'aktif' then raise exception 'Santri tidak ditemukan atau tidak aktif.'; end if;
  if not (public._muhaffizh_santri(s.id) or public.boleh_putus_khataman() or public.boleh_atur_tahfizh()) then
    raise exception 'Khataman diusulkan oleh muhaffizh santri tersebut.' using errcode = '42501'; end if;
  if not public._khatam_30(s.id) then raise exception '% belum tercatat khatam 30 juz (hafalan resmi atau posisi sabaq).', s.nama_lengkap; end if;
  if exists (select 1 from tahfizh_khataman where student_id = s.id and status in ('diusulkan','dijadwalkan','selesai')) then
    raise exception 'Khataman % sudah diusulkan atau terlaksana.', s.nama_lengkap; end if;
  if v_jadwal is null then raise exception 'Isi usulan tanggal dan jam khataman.'; end if;
  if v_jadwal < now() - interval '1 day' then raise exception 'Jadwal khataman tidak boleh lewat.'; end if;
  insert into tahfizh_khataman (student_id, academic_year_id, jadwal, tempat, catatan_usul, diusulkan_oleh)
  values (s.id, (select id from academic_years where aktif), v_jadwal,
          coalesce(nullif(trim(p->>'tempat'), ''), (select nilai->>'tempat_bawaan' from institution_settings where kunci = 'khataman')),
          nullif(trim(p->>'catatan'), ''), v_saya)
  returning id into v_id;
  perform public.kirim_notifikasi(e, 'Usulan khataman: ' || s.nama_lengkap,
    'Khatam 30 juz · usulan ' || to_char(v_jadwal at time zone 'Asia/Makassar', 'DD/MM/YYYY HH24.MI') || ' WITA. Mohon diputuskan.', '/tahfizh/khataman', 'Certificate', 'emas')
    from public._validator_tahfizh() e where e is distinct from v_saya;
  return v_id;
end $$;

/** Setujui (boleh mengubah jadwal/tempat) atau tolak. Setuju → undangan dan sertifikat terbit. */
create or replace function public.putuskan_khataman(p_id uuid, p_setuju boolean, p jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_saya uuid := public.saya(); k tahfizh_khataman; v_nama text;
begin
  if not public.boleh_putus_khataman() then raise exception 'Khataman disetujui oleh Kepala Bidang Tahfizh.' using errcode = '42501'; end if;
  select * into k from tahfizh_khataman where id = p_id for update;
  if k.id is null or k.status <> 'diusulkan' then raise exception 'Usulan khataman tidak ditemukan atau sudah diputuskan.'; end if;
  select nama_lengkap into v_nama from students where id = k.student_id;
  if not p_setuju then
    if length(trim(coalesce(p->>'alasan', ''))) < 5 then raise exception 'Tuliskan alasan penolakan (minimal 5 huruf).'; end if;
    update tahfizh_khataman set status = 'ditolak', alasan_tolak = trim(p->>'alasan'), diputus_oleh = v_saya, diputus_pada = now(), updated_at = now() where id = p_id;
    if k.diusulkan_oleh is not null then
      perform public.kirim_notifikasi(k.diusulkan_oleh, 'Usulan khataman ditolak: ' || v_nama, trim(p->>'alasan'), '/tahfizh/khataman', 'XCircle', 'merah');
    end if;
    return jsonb_build_object('status', 'ditolak');
  end if;
  update tahfizh_khataman set status = 'dijadwalkan', diputus_oleh = v_saya, diputus_pada = now(), updated_at = now(),
         jadwal = coalesce(nullif(p->>'jadwal', '')::timestamptz, jadwal), tempat = coalesce(nullif(trim(p->>'tempat'), ''), tempat)
   where id = p_id returning * into k;
  perform public._dok_undangan_khataman(p_id);
  perform public._dok_sertifikat_khataman(p_id);
  if k.diusulkan_oleh is not null and k.diusulkan_oleh <> v_saya then
    perform public.kirim_notifikasi(k.diusulkan_oleh, 'Khataman disetujui: ' || v_nama,
      to_char(k.jadwal at time zone 'Asia/Makassar', 'DD/MM/YYYY HH24.MI') || ' WITA · ' || coalesce(k.tempat, '-') || '. Teruskan undangan kepada orang tua.',
      '/tahfizh/khataman', 'CalendarCheck', 'hijau');
  end if;
  return jsonb_build_object('status', 'dijadwalkan');
end $$;

/** Ubah jadwal/tempat: pengusul (selama masih usulan) atau pemutus. Riwayat tersimpan; undangan dan sertifikat diperbarui. */
create or replace function public.ubah_jadwal_khataman(p_id uuid, p_jadwal timestamptz, p_tempat text default null, p_alasan text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_saya uuid := public.saya(); k tahfizh_khataman; v_nama text;
begin
  select * into k from tahfizh_khataman where id = p_id for update;
  if k.id is null or k.status not in ('diusulkan','dijadwalkan') then raise exception 'Khataman tidak ditemukan atau sudah selesai/dibatalkan.'; end if;
  if not (public.boleh_putus_khataman() or (k.status = 'diusulkan' and k.diusulkan_oleh = v_saya)) then
    raise exception 'Jadwal khataman yang sudah disetujui diubah oleh Kepala Bidang Tahfizh.' using errcode = '42501'; end if;
  if p_jadwal is null then raise exception 'Isi tanggal dan jam yang baru.'; end if;
  if k.status = 'dijadwalkan' and length(trim(coalesce(p_alasan, ''))) < 5 then raise exception 'Tuliskan alasan perubahan jadwal (minimal 5 huruf).'; end if;
  update tahfizh_khataman set jadwal = p_jadwal, tempat = coalesce(nullif(trim(p_tempat), ''), tempat), updated_at = now(),
         riwayat_jadwal = riwayat_jadwal || jsonb_build_array(jsonb_build_object('jadwal_lama', k.jadwal, 'tempat_lama', k.tempat, 'jadwal_baru', p_jadwal,
           'tempat_baru', coalesce(nullif(trim(p_tempat), ''), k.tempat), 'alasan', nullif(trim(p_alasan), ''), 'oleh', (select nama_lengkap from employees where id = v_saya), 'waktu', now()))
   where id = p_id;
  if k.status = 'dijadwalkan' then
    perform public._dok_undangan_khataman(p_id);
    perform public._dok_sertifikat_khataman(p_id);
    select nama_lengkap into v_nama from students where id = k.student_id;
    if k.diusulkan_oleh is not null and k.diusulkan_oleh <> v_saya then
      perform public.kirim_notifikasi(k.diusulkan_oleh, 'Jadwal khataman diubah: ' || v_nama,
        to_char(p_jadwal at time zone 'Asia/Makassar', 'DD/MM/YYYY HH24.MI') || ' WITA. ' || coalesce(trim(p_alasan), '') || ' Kabari kembali orang tua.',
        '/tahfizh/khataman', 'CalendarCheck', 'kuning');
    end if;
  end if;
end $$;

/** Tandai terlaksana (sertifikat diserahkan): pengusul atau pemutus. Tercatat sebagai prestasi santri. */
create or replace function public.selesaikan_khataman(p_id uuid, p_catatan text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_saya uuid := public.saya(); k tahfizh_khataman; v_tgl date;
begin
  select * into k from tahfizh_khataman where id = p_id for update;
  if k.id is null or k.status <> 'dijadwalkan' then raise exception 'Khataman belum disetujui atau sudah selesai.'; end if;
  if not (public.boleh_putus_khataman() or k.diusulkan_oleh = v_saya or public._muhaffizh_santri(k.student_id)) then
    raise exception 'Anda tidak berwenang menandai khataman ini.' using errcode = '42501'; end if;
  v_tgl := (k.jadwal at time zone 'Asia/Makassar')::date;
  if v_tgl > public.hari_ini() then raise exception 'Khataman dijadwalkan %; tandai terlaksana pada atau setelah hari pelaksanaan.', to_char(v_tgl, 'DD/MM/YYYY'); end if;
  update tahfizh_khataman set status = 'selesai', selesai_pada = now(), catatan_selesai = nullif(trim(p_catatan), ''), updated_at = now() where id = p_id;
  insert into student_achievements (student_id, tanggal, bidang, tingkat, nama_kegiatan, capaian, penyelenggara, keterangan, masuk_rapor, dicatat_oleh)
  select k.student_id, v_tgl, 'tahfizh', 'pondok', 'Khataman Al-Qur''an 30 Juz', 'Khatam 30 juz', 'Bidang Tahfizh',
         'Sertifikat ' || coalesce((select nomor from tahfizh_documents where id = k.sertifikat_id), '-'), true, v_saya
   where not exists (select 1 from student_achievements a where a.student_id = k.student_id and a.nama_kegiatan = 'Khataman Al-Qur''an 30 Juz');
end $$;

/** Batalkan: pengusul (selama usulan) atau pemutus. Undangan dan sertifikat dicabut. */
create or replace function public.batalkan_khataman(p_id uuid, p_alasan text)
returns void language plpgsql security definer set search_path = public as $$
declare v_saya uuid := public.saya(); k tahfizh_khataman;
begin
  select * into k from tahfizh_khataman where id = p_id for update;
  if k.id is null or k.status not in ('diusulkan','dijadwalkan') then raise exception 'Khataman tidak dapat dibatalkan.'; end if;
  if not (public.boleh_putus_khataman() or (k.status = 'diusulkan' and k.diusulkan_oleh = v_saya)) then
    raise exception 'Anda tidak berwenang membatalkan khataman ini.' using errcode = '42501'; end if;
  if length(trim(coalesce(p_alasan, ''))) < 5 then raise exception 'Tuliskan alasan pembatalan (minimal 5 huruf).'; end if;
  update tahfizh_khataman set status = 'dibatalkan', alasan_batal = trim(p_alasan), updated_at = now() where id = p_id;
  update document_registry set status = 'dicabut', dicabut_pada = now(), dicabut_oleh = v_saya, alasan_cabut = trim(p_alasan) where id = k.undangan_doc;
  update tahfizh_documents set status = 'dicabut', alasan_cabut = trim(p_alasan), dicabut_pada = now() where id = k.sertifikat_id;
  update document_registry set status = 'dicabut', dicabut_pada = now(), dicabut_oleh = v_saya, alasan_cabut = trim(p_alasan)
   where id = (select document_id from tahfizh_documents where id = k.sertifikat_id);
end $$;

/** Daftar khataman beserta data WhatsApp (muhaffizh, orang tua) dan dokumen. */
create or replace function public.daftar_khataman(p_status text default null)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(x order by (x->>'urut')::int, x->>'jadwal'), '[]'::jsonb) from (
    select jsonb_build_object('id', k.id, 'student_id', s.id, 'nis', s.nis, 'nama', s.nama_lengkap, 'jenis_kelamin', s.jenis_kelamin,
      'kelas', public._kelompok_santri(s.id, 'kelas'), 'halaqah', public._kelompok_santri(s.id, 'halaqah'),
      'total_resmi', (select count(*) from juz_achievements j where j.student_id = s.id),
      'status', k.status, 'jadwal', k.jadwal, 'tempat', k.tempat, 'catatan_usul', k.catatan_usul,
      'urut', case k.status when 'diusulkan' then 0 when 'dijadwalkan' then 1 when 'selesai' then 2 else 3 end,
      'pengusul', (select nama_lengkap from employees where id = k.diusulkan_oleh), 'hp_pengusul', (select no_hp from employees where id = k.diusulkan_oleh),
      'diusulkan_pada', k.diusulkan_pada, 'pemutus', (select nama_lengkap from employees where id = k.diputus_oleh), 'diputus_pada', k.diputus_pada,
      'alasan_tolak', k.alasan_tolak, 'alasan_batal', k.alasan_batal, 'selesai_pada', k.selesai_pada, 'catatan_selesai', k.catatan_selesai,
      'riwayat_jadwal', k.riwayat_jadwal,
      'muhaffizh', mh.nama_lengkap, 'hp_muhaffizh', mh.no_hp,
      'wali', (select jsonb_build_object('nama', c.nama, 'hubungan', c.hubungan, 'no_hp', c.no_hp) from student_contacts c
                where c.student_id = s.id order by c.utama desc, array_position(array['ayah','ibu','wali'], c.hubungan) limit 1),
      'undangan', case when k.undangan_doc is not null then (select jsonb_build_object('nomor', g.nomor, 'kode', g.kode, 'status', g.status, 'isi', g.isi,
                    'ttd', (select jsonb_agg(jsonb_build_object('nama', x.nama, 'jabatan', x.jabatan, 'niy', x.niy, 'status', x.status, 'waktu', x.waktu) order by x.urutan)
                              from document_signatures x where x.document_id = g.id)) from document_registry g where g.id = k.undangan_doc) end,
      'sertifikat', case when k.sertifikat_id is not null then (select jsonb_build_object('id', d.id, 'nomor', d.nomor, 'status', d.status, 'kode', g.kode, 'status_dokumen', g.status)
                    from tahfizh_documents d left join document_registry g on g.id = d.document_id where d.id = k.sertifikat_id) end,
      'boleh_putus', public.boleh_putus_khataman() and k.status = 'diusulkan',
      'boleh_ubah', k.status in ('diusulkan','dijadwalkan') and (public.boleh_putus_khataman() or (k.status = 'diusulkan' and k.diusulkan_oleh = public.saya())),
      'boleh_selesai', k.status = 'dijadwalkan' and (public.boleh_putus_khataman() or k.diusulkan_oleh = public.saya() or public._muhaffizh_santri(s.id)),
      'boleh_batal', k.status in ('diusulkan','dijadwalkan') and (public.boleh_putus_khataman() or (k.status = 'diusulkan' and k.diusulkan_oleh = public.saya()))) x
      from tahfizh_khataman k join students s on s.id = k.student_id
      left join lateral (select e.nama_lengkap, e.no_hp from group_members m join student_groups g on g.id = m.group_id and g.jenis = 'halaqah'
                           join academic_years a on a.id = g.academic_year_id and a.aktif join group_keepers gk on gk.group_id = g.id
                           join employees e on e.id = gk.employee_id
                          where m.student_id = s.id and m.selesai is null and (gk.sampai is null or gk.sampai >= public.hari_ini())
                          order by array_position(array['utama','pendamping','pengganti'], gk.peran) limit 1) mh on true
     where (p_status is null or k.status = p_status or (p_status = 'berjalan' and k.status in ('diusulkan','dijadwalkan')))
       and (public.boleh_putus_khataman() or public.boleh_atur_tahfizh() or k.diusulkan_oleh = public.saya()
            or s.id in (select public.santri_terlihat()) or public.boleh_kelola_dokumen_tahfizh())
       and (k.status in ('diusulkan','dijadwalkan') or k.jadwal > now() - interval '2 years')) q
$$;

do $$ declare f text; begin
  foreach f in array array['calon_khataman()','usulkan_khataman(jsonb)','putuskan_khataman(uuid,boolean,jsonb)','ubah_jadwal_khataman(uuid,timestamptz,text,text)',
                           'selesaikan_khataman(uuid,text)','batalkan_khataman(uuid,text)','daftar_khataman(text)','boleh_putus_khataman()'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 5. TEMPLATE WHATSAPP
-- ---------------------------------------------------------------------
insert into public.wa_templates (kode, nama, isi, variabel, keterangan) values
  ('khataman_pengumuman', 'Pengumuman khataman ke grup WA',
   E'{salam}.\n\n*Undangan Khataman Al-Qur''an 30 Juz*\n\nAlhamdulillah, ananda *{nama_santri}* ({kelas}, {halaqah}) telah menuntaskan hafalan Al-Qur''an 30 juz. Insya Allah khataman akan dilaksanakan pada:\n• Hari/tanggal: {tanggal}\n• Waktu: {waktu}\n• Tempat: {tempat}\n\nKami mengundang para asatidzah dan santri untuk hadir menyaksikan dan mendoakan. Semoga Allah memberkahi.\n\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
   '{nama_santri,kelas,halaqah,tanggal,waktu,tempat}', 'Tombol "Pengumuman grup" di Tahfizh → Khataman.'),
  ('khataman_undangan_wali', 'Undangan khataman ke orang tua/wali',
   E'{salam}, Bapak/Ibu {nama_wali}.\n\nAlhamdulillah, dengan izin Allah ananda *{nama_santri}* ({kelas}) telah menuntaskan hafalan Al-Qur''an 30 juz. Kami mengundang Bapak/Ibu untuk hadir pada *Khataman Al-Qur''an* ananda:\n• Hari/tanggal: {tanggal}\n• Waktu: {waktu}\n• Tempat: {tempat}\n\nPada acara tersebut ananda menerima Sertifikat Penghargaan Khataman. Surat undangan resmi nomor {nomor} dapat diperiksa di: {tautan_cek}\n\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
   '{nama_wali,nama_santri,kelas,tanggal,waktu,tempat,nomor,tautan_cek}', 'Tombol "WA orang tua" di Tahfizh → Khataman (dikirim muhaffizh).'),
  ('khataman_muhaffizh', 'Persetujuan khataman ke muhaffizh',
   E'{salam}, {nama}.\n\nUsulan khataman ananda *{nama_santri}* ({halaqah}) telah *disetujui* dengan jadwal:\n• Hari/tanggal: {tanggal}\n• Waktu: {waktu}\n• Tempat: {tempat}\n\nMohon undangan diteruskan kepada orang tua santri dan santri dipersiapkan. Undangan dan sertifikat dapat dicetak di SIMKA PRO (Tahfizh → Khataman): {tautan}\n\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
   '{nama,nama_santri,halaqah,tanggal,waktu,tempat,tautan}', 'Tombol "WA muhaffizh" di Tahfizh → Khataman.')
on conflict (kode) do nothing;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 4 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select '1. Tabel khataman tersedia' as pemeriksaan, case when to_regclass('public.tahfizh_khataman') is not null then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Fungsi alur khataman (7)', case when (select count(distinct proname) from pg_proc where pronamespace = 'public'::regnamespace and proname in
  ('calon_khataman','usulkan_khataman','putuskan_khataman','ubah_jadwal_khataman','selesaikan_khataman','batalkan_khataman','daftar_khataman')) = 7 then 'Sesuai' else 'Periksa' end
union all
select '3. Sertifikat khataman sebagai dokumen tahfizh', case when position('sertifikat_khataman' in (select pg_get_constraintdef(oid) from pg_constraint where conname = 'tahfizh_documents_jenis_check')) > 0
  and exists (select 1 from public.doc_number_formats where kode = 'sertifikat_khataman') then 'Sesuai' else 'Periksa' end
union all
select '4. Template WA khataman (3)', case when (select count(*) from public.wa_templates where kode like 'khataman_%') = 3 then 'Sesuai' else 'Periksa' end;
