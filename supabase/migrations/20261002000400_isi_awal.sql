-- =====================================================================
-- SIMKA PRO · Fase 1 · Migrasi 4: Isi awal sesuai blueprint
-- Semua isi awal dapat diubah superadmin melalui menu Pengaturan.
-- =====================================================================

-- ---------- Struktur organisasi (Bagian 5) ----------
insert into public.org_units (kode, nama, jenis, prioritas, urutan) values
  ('PIMPINAN', 'Pimpinan Pondok', 'pimpinan', true, 0);

insert into public.org_units (parent_id, kode, nama, jenis, prioritas, urutan)
select p.id, v.kode, v.nama, 'bidang', v.prioritas, v.urutan
from public.org_units p,
  (values ('TAHFIZH','Bidang Tahfizh',true,1), ('WUSTHA','Bidang Kesetaraan Wustha',true,2),
          ('SMA','Bidang SMA',true,3), ('KESANTRIAN','Bidang Kesantrian',true,4),
          ('SARANA','Bidang Sarana',false,5), ('MEDIA','Bidang Media',false,6),
          ('BAHASA','Bidang Bahasa',false,7), ('UMUM','Bidang Umum',false,8)) v(kode,nama,prioritas,urutan)
where p.kode = 'PIMPINAN';

insert into public.org_units (parent_id, kode, nama, jenis, urutan)
select p.id, v.kode, v.nama, 'unit', v.urutan
from (values ('KESANTRIAN','KLINIK','Unit Klinik',1), ('KESANTRIAN','SECURITY','Unit Security',2),
             ('UMUM','TU','Unit Tata Usaha',1), ('UMUM','DAPUR','Unit Dapur',2)) v(induk,kode,nama,urutan)
join public.org_units p on p.kode = v.induk;

-- ---------- Jabatan fungsional P1 (Bagian 3) ----------
insert into public.functional_positions (kode, nama, jenis_sesi, tanpa_rangkap, pengasuh, urutan) values
  ('GURU',        'Guru mata pelajaran', 'rentang', false, false, 1),
  ('WALI_KELAS',  'Wali kelas',          'rentang', false, true,  2),
  ('MUHAFFIZH',   'Muhaffizh/Muhaffizhah','sesi',   false, true,  3),
  ('MUSYRIF',     'Musyrif/Musyrifah',   'sesi',    false, true,  4),
  ('PEMBINA_EKSKUL','Pembina ekskul',    'sesi',    false, true,  5),
  ('OPERATOR',    'Operator',            'rentang', false, false, 6),
  ('STAF_BIDANG', 'Staf bidang',         'rentang', false, false, 7),
  ('STAF_PEMBANTU','Staf pembantu',      'rentang', false, false, 8),
  ('MEDIS',       'Petugas kesehatan (medis)', 'shift', true, false, 9),
  ('SECURITY',    'Petugas keamanan (security)','shift', true, false, 10),
  ('KEBERSIHAN',  'Petugas kebersihan',  'rentang', false, false, 11),
  ('LOGISTIK',    'Petugas logistik',    'rentang', false, false, 12),
  ('MEDIA',       'Petugas media',       'rentang', false, false, 13),
  ('SARPRAS',     'Petugas sarana prasarana','rentang', false, false, 14);

-- ---------- Jabatan struktural P2 ----------
insert into public.structural_positions (kode, nama, tingkat, boleh_menyetujui, urutan) values
  ('YAYASAN',        'Pengurus Yayasan',          10, true,  1),
  ('DIREKTUR',       'Direktur (Mudir)',          15, true,  2),
  ('WAKIL_DIREKTUR', 'Wakil Direktur',            20, true,  3),
  ('BENDAHARA',      'Bendahara',                 25, false, 4),
  ('KEPALA_BIDANG',  'Kepala Bidang',             30, true,  5),
  ('WAKIL_KEPALA_BIDANG','Wakil Kepala Bidang',   35, false, 6),
  ('WAKIL_KEPALA_SEKOLAH','Wakil Kepala Sekolah', 36, false, 7),
  ('KEPALA_UNIT',    'Kepala Unit',               40, false, 8),
  ('TATA_USAHA',     'Tata Usaha',                50, false, 9);

-- ---------- Daftar fitur (Bagian 4) ----------
insert into public.features (kode, nama, kelompok, fase, urutan) values
  ('data_pegawai','Data kepegawaian','Kepegawaian',1,1), ('presensi','Presensi','Kepegawaian',2,2),
  ('pengajuan','Pengajuan izin, sakit, cuti','Kepegawaian',3,3), ('jurnal_harian','Jurnal harian','Kepegawaian',3,4),
  ('berkas_pegawai','Berkas pegawai','Kepegawaian',3,5), ('kartu_pegawai','Kartu pegawai','Kepegawaian',3,6),
  ('data_santri','Data santri','Santri',4,1), ('absensi_kelas','Absensi kelas','Santri',4,2),
  ('absensi_halaqah','Absensi halaqah','Santri',4,3), ('absensi_asrama','Absensi asrama','Santri',4,4),
  ('absensi_ekskul','Absensi ekskul','Santri',4,5), ('kelompok_santri','Pengaturan kelompok','Santri',4,6),
  ('jadwal_mengajar','Jadwal dan jurnal mengajar','Santri',4,7), ('nilai','Nilai','Santri',12,8),
  ('tahfizh','Tahfizh','Santri',5,9),
  ('klinik','Klinik','Layanan',6,1), ('gerbang','Gerbang dan izin keluar','Layanan',7,2),
  ('titipan','Titipan','Layanan',7,3), ('buku_tamu','Buku tamu','Layanan',7,4), ('kunjungan','Kunjungan','Layanan',7,5),
  ('perizinan_santri','Perizinan santri','Layanan',7,6), ('lapor_bidang','Lapor ke bidang','Layanan',6,7),
  ('pantauan','Pantauan langsung','Layanan',7,8),
  ('tata_usaha','Tata usaha','Administrasi',10,1), ('slip_gaji','Slip gaji','Administrasi',11,2),
  ('keuangan_santri','Keuangan santri','Administrasi',13,3), ('laporan','Laporan dan ekspor','Administrasi',8,4),
  ('pengumuman','Pengumuman','Sistem',3,1), ('template_wa','Template WA','Sistem',3,2),
  ('pengaturan_lembaga','Pengaturan lembaga','Sistem',1,3), ('hak_akses','Hak akses','Sistem',1,4),
  ('audit_log','Audit log','Sistem',3,5);

insert into public.admin_capabilities (kode, nama, urutan) values
  ('verval_akun','Verifikasi akun pegawai baru',1),
  ('kelola_pegawai','Mengelola data kepegawaian dan impor Excel',2),
  ('kalender','Mengelola hari libur dan kalender',3),
  ('audit_log','Melihat audit log seluruh pegawai',4),
  ('verval_presensi','Verval presensi di luar area (Fase 2)',5),
  ('kelompok_santri','Pembagian kelas, halaqah, kamar (Fase 4)',6),
  ('absensi_atas_nama','Input absensi santri atas nama pengampu (Fase 4)',7);

-- ---------- Hak akses bawaan per jabatan (lapis 1) ----------
-- Semua jabatan fungsional: presensi, pengajuan, jurnal (input); berkas dan kartu (lihat)
insert into public.feature_grants (feature_kode, sasaran, sasaran_id, tingkat, catatan)
select f.kode, 'fungsional', fp.id, f.t, 'bawaan'
from public.functional_positions fp,
     (values ('presensi',2),('pengajuan',2),('jurnal_harian',2),('berkas_pegawai',1),('kartu_pegawai',1)) f(kode,t);

insert into public.feature_grants (feature_kode, sasaran, sasaran_id, tingkat, catatan)
select v.fitur, 'fungsional', fp.id, v.t, 'bawaan'
from (values ('WALI_KELAS','absensi_kelas',2), ('MUHAFFIZH','absensi_halaqah',2), ('MUHAFFIZH','tahfizh',2),
             ('MUSYRIF','absensi_asrama',2), ('PEMBINA_EKSKUL','absensi_ekskul',2),
             ('GURU','jadwal_mengajar',2), ('GURU','nilai',2), ('MUHAFFIZH','nilai',2),
             ('MEDIS','klinik',2), ('SECURITY','gerbang',2), ('SECURITY','titipan',2),
             ('SECURITY','buku_tamu',2), ('SECURITY','kunjungan',2)) v(jab,fitur,t)
join public.functional_positions fp on fp.kode = v.jab;

insert into public.feature_grants (feature_kode, sasaran, sasaran_id, tingkat, catatan)
select v.fitur, 'struktural', sp.id, v.t, 'bawaan'
from (values ('YAYASAN','pantauan',1), ('YAYASAN','laporan',1), ('YAYASAN','pengajuan',3),
             ('DIREKTUR','pantauan',1), ('DIREKTUR','laporan',1), ('DIREKTUR','pengajuan',3), ('DIREKTUR','data_pegawai',1),
             ('WAKIL_DIREKTUR','pantauan',1), ('WAKIL_DIREKTUR','laporan',1), ('WAKIL_DIREKTUR','pengajuan',3),
             ('KEPALA_BIDANG','pantauan',1), ('KEPALA_BIDANG','laporan',1), ('KEPALA_BIDANG','pengajuan',3),
             ('KEPALA_BIDANG','data_pegawai',1),
             ('WAKIL_KEPALA_BIDANG','pantauan',1), ('WAKIL_KEPALA_SEKOLAH','pantauan',1),
             ('BENDAHARA','slip_gaji',3), ('BENDAHARA','keuangan_santri',3), ('BENDAHARA','pantauan',1),
             ('TATA_USAHA','tata_usaha',3)) v(jab,fitur,t)
join public.structural_positions sp on sp.kode = v.jab;

-- ---------- Pengaturan lembaga (Bagian 34) ----------
insert into public.institution_settings (kunci, publik, nilai) values
('identitas', true, jsonb_build_object(
  'nama_lengkap', 'Pondok Pesantren Tahfizhul Qur''an Imam Asy-Syathiby Wahdah Islamiyah Gowa',
  'nama_singkat', 'IMAM ASY-SYATHIBY',
  'tagline', 'Generasi Qur''ani dan Berprestasi',
  'npsn', '70023617', 'nspp', '502373060054',
  'telepon', '085243324006', 'email', 'syathiby.gowa@gmail.com',
  'alamat', 'Jl. Poros Malino Sungguminasa, Lingkungan Bontobaddo No.KM.04, Bontoramba, Kec. Somba Opu, Kabupaten Gowa, Sulawesi Selatan 92119',
  'kota_surat', 'Gowa',
  'logo_url', 'https://i.ibb.co.com/W4kqQScd/PPS-IMAM-ASY-SYATHIBY.png',
  'logo_kemenag_url', 'https://cdn.kemenag.go.id/storage/archives/logo-kemenag-png-1png.png',
  'ikon_url', 'https://i.ibb.co.com/Kjq1b2Kw/Icon-SIMKA.png')),
('kalender', false, jsonb_build_object(
  'semester', 1, 'zona_waktu', 'Asia/Makassar',
  'catatan', 'Libur bulanan berlaku untuk semua; Ahad libur sekolah dan tahfizh, musyrif dan security tetap masuk.')),
('hijriah', true, jsonb_build_object('koreksi_hari', 0, 'metode', 'tabular (dapat dikoreksi ±hari)')),
('integrasi', false, jsonb_build_object(
  'supabase_url', '', 'gas_url', '', 'drive_folder_nama', 'SIMKA PRO', 'drive_folder_id', '',
  'email_pengirim', 'syathiby.gowa@gmail.com', 'nama_pengirim', 'SIMKA PRO Imam Asy-Syathiby',
  'domain_aplikasi', '', 'catatan', 'Kunci rahasia tidak disimpan di sini; pasang di Supabase Secrets dan Script Properties GAS.'));

-- ---------- Kop surat: bentuk gambar resmi (berkas di /kop/*.jpg aplikasi) ----------
insert into public.letterheads (kode, nama, kode_unit, bentuk, gambar_url, logo_kiri_url, logo_kanan_url, baris, pita_teks, urutan) values
('pondok', 'Kop Pondok', 'PPTQ-IAS', 'gambar', 'kop/kop-pondok.jpg',
  'https://cdn.kemenag.go.id/storage/archives/logo-kemenag-png-1png.png',
  'https://i.ibb.co.com/W4kqQScd/PPS-IMAM-ASY-SYATHIBY.png',
  '[{"teks":"KEMENTERIAN AGAMA KABUPATEN GOWA","tebal":false,"ukuran":13},
    {"teks":"PONDOK PESANTREN TAHFIZHUL QUR''AN","tebal":true,"ukuran":15},
    {"teks":"IMAM ASY-SYATHIBY WAHDAH ISLAMIYAH GOWA","tebal":true,"ukuran":15},
    {"teks":"NPSN. 70023617  NSPP. 502373060054  e-Mail: syathiby.gowa@gmail.com","tebal":false,"ukuran":10}]',
  'Jalan Poros Malino KM.04, Ling. Bontobaddo, Kel. Bontoramba, Kab. Gowa Kode Pos 92119 | Telp. 085243324006', 1),
('wustha', 'Kop Kesetaraan Wustha', 'KW-IAS', 'gambar', 'kop/kop-wustha.jpg',
  'https://cdn.kemenag.go.id/storage/archives/logo-kemenag-png-1png.png', null,
  '[{"teks":"KEMENTERIAN AGAMA KABUPATEN GOWA","tebal":false,"ukuran":13},
    {"teks":"KESETARAAN WUSTHA PPS TAHFIZHUL QUR''AN","tebal":true,"ukuran":15},
    {"teks":"IMAM ASY-SYATHIBY WAHDAH ISLAMIYAH GOWA","tebal":true,"ukuran":15},
    {"teks":"NPSN. 70023617  NSPP. 502373060054  e-Mail: syathiby.gowa@gmail.com","tebal":false,"ukuran":10}]',
  'Jalan Poros Malino KM.04, Ling. Bontobaddo, Kel. Bontoramba, Kab. Gowa Kode Pos 92119 | Telp. 082194934531', 2),
('sma', 'Kop SMA', 'SMAS-IAS', 'gambar', 'kop/kop-sma.jpg', null, null,
  '[{"teks":"PEMERINTAH PROVINSI SULAWESI SELATAN","tebal":false,"ukuran":12},
    {"teks":"DINAS PENDIDIKAN PROVINSI SULAWESI SELATAN","tebal":false,"ukuran":12},
    {"teks":"YAYASAN PESANTREN IMAM ASYSYATIBY WAHDAH ISLAMIYAH","tebal":true,"ukuran":13},
    {"teks":"SMAS TAHFIZHUL QUR''AN IMAM ASY-SYATIBY W.I","tebal":true,"ukuran":15},
    {"teks":"NPSN. 69981356  Akreditasi Baik (B)  e-Mail: syathiby.gowa@gmail.com","tebal":false,"ukuran":10}]',
  'Jalan Poros Malino KM.04, Ling. Bontobaddo, Kel. Bontoramba, Kab. Gowa Kode Pos 92119 | Telp. 085256006743', 3),
('yayasan', 'Kop Yayasan', 'YPIA', 'gambar', 'kop/kop-yayasan.jpg', null, null,
  '[{"teks":"YAYASAN PESANTREN IMAM ASYSYATIBY (YPIA)","tebal":true,"ukuran":15},
    {"teks":"WAHDAH ISLAMIYAH","tebal":true,"ukuran":14},
    {"teks":"Daftar Yayasan Nomor AHU-0003525.AH.01.04.Tahun 2023","tebal":false,"ukuran":10},
    {"teks":"Jalan Poros Malino Sungguminasa KM.04, Ling. Bontobaddo, Kelurahan Bontoramba, Kecamatan Somba Opu, Kabupaten Gowa Sulawesi Selatan Kode Pos. 92119","tebal":false,"ukuran":9}]',
  'Nomor Induk Berusaha. 0205230018097, e-Mail: syathiby.gowa@gmail.com, Telp. 081343663344/085395959512', 4);

-- ---------- Penanda tangan (isi awal dari aplikasi SPMB) ----------
insert into public.signatories (jabatan_tertulis, nama, niy, urutan) values
  ('Direktur', 'Siswandi Safari, S.Pd.I., Lc., S.H., M.Ag.', '1983020910201401', 1),
  ('Kepala Kesetaraan Wustha (SMP)', 'Chamdar Nur, S.Pd.I., SH., Lc., M.Pd.', '1983042805201401', 2),
  ('Kepala SMA', 'H. Afrianto, Lc, M.H.', '1994042801202001', 3);

insert into public.signer_rules (jenis_dokumen, nama_dokumen, kiri, kanan, kop_kode, urutan) values
  ('pengajuan_pegawai', 'Surat izin/sakit/cuti pegawai', 'atasan_terakhir', 'pemohon', 'pondok', 1),
  ('izin_santri', 'Catatan izin santri (internal)', 'kepala_bidang', 'pengusul', 'pondok', 2),
  ('rekap_pegawai', 'Rekap kehadiran pegawai',
     (select id::text from public.signatories where jabatan_tertulis = 'Direktur'), 'pencetak', 'pondok', 3),
  ('rekap_santri', 'Rekap kehadiran santri', 'kepala_jenjang', 'pengasuh', 'pondok', 4),
  ('slip_gaji', 'Slip gaji', 'bendahara', 'pegawai', 'pondok', 5),
  ('surat_keluar', 'Surat keluar tata usaha', 'sesuai_template', null, 'pondok', 6),
  ('kartu_pegawai', 'Kartu pegawai', (select id::text from public.signatories where jabatan_tertulis = 'Direktur'), null, 'pondok', 7),
  ('kuitansi', 'Kuitansi pembayaran', 'bendahara', null, 'pondok', 8),
  ('tagihan_santri', 'Surat tagihan santri', 'bendahara', null, 'pondok', 9),
  ('daftar_pegawai', 'Daftar dan rekap kepegawaian',
     (select id::text from public.signatories where jabatan_tertulis = 'Direktur'), 'pencetak', 'pondok', 10);

-- ---------- Kalender ----------
insert into public.holiday_calendars (jenis_tugas, nama, hari_libur, catatan) values
  ('sekolah', 'Sekolah (Wustha dan SMA)', '{0}', 'Ahad libur'),
  ('tahfizh', 'Halaqah tahfizh', '{0}', 'Ahad libur'),
  ('asrama',  'Asrama (musyrif)', '{}', 'Tetap masuk hari Ahad'),
  ('security','Security', '{}', 'Bergiliran; libur diatur pada jadwal shift'),
  ('medis',   'Klinik (medis)', '{}', 'Diatur pada jadwal shift'),
  ('kantor',  'Kantor dan staf', '{0}', 'Ahad libur');

insert into public.academic_years (nama, mulai, selesai, semester, aktif) values
  ('2026/2027', '2026-07-13', '2027-06-30', 1, true);

-- ---------- Kode perihal surat (pedoman persuratan Wahdah Islamiyah) ----------
insert into public.letter_subject_codes (kode, arti, keterangan, urutan) values
  ('QR','Qarar','Surat Keputusan (SK)',1), ('FW','Fatwa','Surat fatwa',2),
  ('AM','Amanah','Tugas, mandat, instruksi, pelimpahan, kuasa, perjalanan dinas',3),
  ('TH','Thalab','Permohonan atau permintaan (bantuan, sarana, kerja sama)',4),
  ('TQ','Taqrir','Laporan (keuangan, perjalanan, acara, daurah)',5),
  ('DW','Da''wah','Undangan dan panggilan',6),
  ('IL','I''lan','Seruan, himbauan, edaran, pemberitahuan, pengumuman, keterangan, rekomendasi',7),
  ('IZ','Indzar','Peringatan, teguran, sanksi',8), ('NZ','Nahwa Dzalik','Lain-lain',9);

-- ---------- Format nomor dokumen ----------
insert into public.doc_number_formats (kode, nama, pola, grup_urut, reset) values
  ('surat',     'Surat tata usaha (D/K)',  '{DK}.{URUT3}/{PERIHAL}/{UNIT}/{BLN_H_ROMAWI}/{THN_H}', 'surat', 'tahun_hijriah'),
  ('sk',        'Surat Keputusan (SK)',    '{DK}.{URUT3}/{PERIHAL}/{UNIT}/{BLN_H_ROMAWI}/{THN_H}', 'sk',    'tahun_hijriah'),
  ('pengajuan', 'Dokumen pengajuan pegawai','PGJ.{URUT3}/{UNIT}/{BLN_ROMAWI}/{THN}', 'pengajuan', 'tahun_masehi'),
  ('slip',      'Slip gaji',               'SLIP.{URUT3}/{UNIT}/{BLN}/{THN}', 'slip', 'bulan_masehi'),
  ('kuitansi',  'Kuitansi pembayaran',     'KWT.{URUT3}/{UNIT}/{BLN_ROMAWI}/{THN}', 'kuitansi', 'tahun_masehi'),
  ('tagihan',   'Surat tagihan santri',    'TGH.{URUT3}/{UNIT}/{BLN_ROMAWI}/{THN}', 'tagihan', 'tahun_masehi');

-- Jejak audit dari proses isi awal tidak diperlukan
delete from public.audit_logs;
