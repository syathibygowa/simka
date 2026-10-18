// SIMKA PRO | src/lib/hakAkses.js | v2.3 | 14.6.0: fitur Kedisiplinan santri dan izin admin kelola_disiplin | 18/10/2026
// Katalog Hak Akses Fitur: SATU fitur untuk setiap menu (atau sekelompok menu yang tidak terpisahkan), dikelompokkan sesuai
// grup menu di sidebar. Isi ini sama dengan migrasi 20261020011200_hak_akses_semua_fitur.sql (+ 20261021011300, 20261022011400) dan dipakai sebagai cadangan bila
// kolom keterangan belum ada di database serta sebagai data mode demo.
//   arti    : makna tingkat 1 (lihat), 2 (input/ubah), 3 (kelola) sesuai pemeriksaan di server
//   kunci   : bila diisi, fitur tidak dapat diatur di matriks (alasannya ditampilkan)
//   sensitif: diatur per orang di tab Fitur sensitif (gaji, tunjangan, keuangan santri)
//   bawaan  : hak bawaan saat migrasi dijalankan (semua = lapis "Semua pegawai")
//   izin    : izin admin yang ikut dimiliki pemegang tingkat tertentu, mis. { kode: 'verval_presensi', min: 2 }
export const SEMUA_ID = '00000000-0000-0000-0000-000000000000'
export const URUT_KELOMPOK = ['Utama', 'Presensi', 'Layanan Pegawai', 'Kepegawaian', 'Santri', 'Fungsional', 'Layanan', 'Administrasi', 'Sistem']

export const KATALOG_FITUR = [
  // ---------- Utama ----------
  { kode: 'beranda', nama: 'Beranda', kelompok: 'Utama', urutan: 1, menu: 'Beranda',
    arti: {}, kunci: 'Halaman awal setiap akun. Isinya menyesuaikan hak lain; grafik periodik pimpinan mengikuti fitur Layar Pantauan.' },
  { kode: 'notifikasi', nama: 'Notifikasi', kelompok: 'Utama', urutan: 2, menu: 'Notifikasi',
    arti: {}, kunci: 'Setiap akun menerima notifikasinya sendiri.' },
  { kode: 'pengumuman', nama: 'Pengumuman', kelompok: 'Utama', urutan: 3, menu: 'Pengumuman (pegawai dan wali santri)',
    arti: { 1: 'Membaca pengumuman yang ditujukan kepadanya', 2: 'Membuat pengumuman untuk pegawai dan wali santri', 3: 'Sama dengan input/ubah' },
    keterangan: 'Pimpinan unit tetap dapat membuat pengumuman untuk wali santri unitnya.', bawaan: { semua: 1 }, izin: [{ kode: 'kelola_pengumuman', min: 2 }] },
  { kode: 'agenda', nama: 'Agenda', kelompok: 'Utama', urutan: 4, menu: 'Agenda',
    arti: { 1: 'Melihat agenda yang ditujukan kepadanya', 2: 'Membuat dan mengelola agenda serta undangan', 3: 'Juga mengisi kalender libur pondok' },
    bawaan: { semua: 1 }, izin: [{ kode: 'kelola_agenda', min: 2 }, { kode: 'kalender', min: 3 }] },
  { kode: 'profil', nama: 'Profil', kelompok: 'Utama', urutan: 5, menu: 'Profil, Kartu Pegawai, Data kepegawaian saya',
    arti: {}, kunci: 'Setiap akun mengelola profil dan kartu pegawainya sendiri.' },

  // ---------- Presensi ----------
  { kode: 'presensi', nama: 'Presensi', kelompok: 'Presensi', urutan: 1, menu: 'Presensi',
    arti: { 1: 'Membuka menu Presensi dan riwayat presensinya', 2: 'Melakukan presensi (GPS dan swafoto)', 3: 'Sama dengan input/ubah' },
    keterangan: 'Tingkat Tidak ada menyembunyikan menu Presensi. Jadwal wajib presensi tetap diatur di Penjadwalan.', bawaan: { semua: 2 } },
  { kode: 'verval_presensi', nama: 'Verval dan data presensi', kelompok: 'Presensi', urutan: 2, menu: 'Verval Presensi, Data Presensi',
    arti: { 1: 'Melihat data presensi seluruh pegawai (Data Presensi)', 2: 'Memverifikasi presensi, koreksi, dan kecurigaan', 3: 'Sama dengan input/ubah' },
    izin: [{ kode: 'verval_presensi', min: 2 }] },
  { kode: 'atur_presensi', nama: 'Penjadwalan', kelompok: 'Presensi', urutan: 3, menu: 'Penjadwalan, Jadwal Shift (semua petugas)',
    arti: { 1: 'Melihat penjadwalan, jadwal kerja, dan jadwal shift semua pegawai', 2: 'Mengatur titik GPS, pola sesi, jadwal kerja, dan shift', 3: 'Juga mengisi kalender libur pondok' },
    keterangan: 'Petugas shift otomatis melihat jadwal shift-nya sendiri.', izin: [{ kode: 'atur_presensi', min: 2 }, { kode: 'kalender', min: 3 }] },

  // ---------- Layanan Pegawai ----------
  { kode: 'pengajuan', nama: 'Pengajuan', kelompok: 'Layanan Pegawai', urutan: 1, menu: 'Pengajuan (izin, sakit, cuti, dinas luar)',
    arti: { 1: 'Membuka menu dan melihat pengajuannya', 2: 'Mengajukan izin, sakit, cuti, dan dinas luar', 3: 'Juga melihat semua pengajuan dan mengatur ketentuannya' },
    keterangan: 'Persetujuan tetap mengikuti jenjang jabatan (Kepala Bidang → Direktur/Wadir → Yayasan).', bawaan: { semua: 2 },
    izin: [{ kode: 'lihat_pengajuan', min: 3 }, { kode: 'atur_pengajuan', min: 3 }] },
  { kode: 'jurnal_harian', nama: 'Jurnal harian', kelompok: 'Layanan Pegawai', urutan: 2, menu: 'Jurnal Harian',
    arti: { 1: 'Membuka menu dan melihat jurnalnya', 2: 'Mengisi jurnal harian', 3: 'Juga memverifikasi jurnal dan mengatur template ceklist' },
    keterangan: 'Pimpinan tetap melihat jurnal anggota unitnya.', bawaan: { semua: 2 }, izin: [{ kode: 'verval_jurnal', min: 3 }, { kode: 'atur_jurnal', min: 3 }] },
  { kode: 'berkas_pegawai', nama: 'Berkas pegawai', kelompok: 'Layanan Pegawai', urutan: 3, menu: 'Berkas Saya',
    arti: { 1: 'Membuka berkas yang dikirim kepadanya', 2: 'Mengirim dan mengelola berkas untuk pegawai', 3: 'Sama dengan input/ubah' },
    bawaan: { semua: 1 }, izin: [{ kode: 'kelola_berkas', min: 2 }] },

  // ---------- Kepegawaian ----------
  { kode: 'data_pegawai', nama: 'Data pegawai', kelompok: 'Kepegawaian', urutan: 1, menu: 'Data Pegawai (biodata, rekap, cetak kartu massal, kelompok pegawai)',
    arti: { 1: 'Melihat data seluruh pegawai', 2: 'Menambah dan mengubah data serta jabatan pegawai, mencetak kartu', 3: 'Juga mengatur kelompok pegawai (PH, PI, dll.)' },
    keterangan: 'Berikan Input/ubah dengan hati-hati: pemegangnya dapat mengubah jabatan pegawai, termasuk jabatannya sendiri.',
    izin: [{ kode: 'kelola_pegawai', min: 2 }, { kode: 'cetak_kartu', min: 2 }, { kode: 'kelola_kelompok', min: 3 }] },
  { kode: 'verifikasi_akun', nama: 'Verifikasi akun', kelompok: 'Kepegawaian', urutan: 2, menu: 'Verifikasi Akun',
    arti: { 1: 'Melihat akun yang menunggu verifikasi', 2: 'Memverifikasi atau menolak pendaftaran akun', 3: 'Sama dengan input/ubah' },
    keterangan: 'Reset sandi dan menonaktifkan akun mengikuti Data pegawai tingkat Input/ubah. Menjadikan admin tetap khusus superadmin.',
    izin: [{ kode: 'verval_akun', min: 2 }] },

  // ---------- Santri ----------
  { kode: 'data_santri', nama: 'Data santri', kelompok: 'Santri', urutan: 1, menu: 'Data Santri, Kelengkapan Data',
    arti: { 1: 'Melihat data seluruh santri', 2: 'Menambah dan mengubah data santri', 3: 'Juga mengimpor, memutasi keluar, mengubah status, dan mencetak kartu pelajar santri' },
    keterangan: 'Juga membuka menu Tahfizh, Klinik, Perizinan, dan Libur Santri untuk dilihat.', izin: [{ kode: 'kelola_santri', min: 3 }] },
  { kode: 'statistik_santri', nama: 'Statistik santri', kelompok: 'Santri', urutan: 2, menu: 'Statistik Santri',
    arti: { 1: 'Melihat statistik santri seluruh pondok', 2: 'Sama dengan lihat', 3: 'Sama dengan lihat' },
    keterangan: 'Hak bawaan disalin dari pemegang Data santri.' },
  { kode: 'kelompok_santri', nama: 'Kelompok santri', kelompok: 'Santri', urutan: 3, menu: 'Kelompok Santri, Naik Kelas',
    arti: { 1: 'Melihat semua kelompok (kelas, kamar, halaqah, ekskul)', 2: 'Mengatur kelompok, pengasuh, anggota, dan kategori ekskul', 3: 'Juga menjalankan Naik Kelas dan pergantian tahun ajaran' },
    izin: [{ kode: 'kelompok_santri', min: 2 }] },
  { kode: 'prestasi', nama: 'Prestasi santri', kelompok: 'Santri', urutan: 4, menu: 'Prestasi Santri',
    arti: { 1: 'Melihat prestasi seluruh santri', 2: 'Mencatat, mengubah, dan menghapus prestasi santri', 3: 'Sama dengan input/ubah' },
    keterangan: 'Pengasuh kelompok dan pimpinan unit otomatis untuk santrinya. Santri yang dapat dipilih saat mencatat mengikuti Data santri. Bawaan disalin dari Data santri dan jabatan pimpinan.' },
  { kode: 'disiplin_santri', nama: 'Kedisiplinan santri', kelompok: 'Santri', urutan: 8, menu: 'Kedisiplinan Santri (pelanggaran, Surat Peringatan SP1–SP3, rekap)',
    arti: { 1: 'Melihat seluruh catatan pelanggaran, surat peringatan, dan rekapnya', 2: 'Mencatat pelanggaran semua santri', 3: 'Mengusulkan dan mencabut surat peringatan santri serta mengatur ketentuannya' },
    keterangan: 'Pengasuh santri dan petugas Security otomatis dapat mencatat. Pimpinan Bidang Kesantrian otomatis tingkat Kelola. Surat diproses Tata Usaha dan ditandatangani Direktur.',
    izin: [{ kode: 'kelola_disiplin', min: 3 }] },
  { kode: 'nilai', nama: 'Penilaian dan rapor', kelompok: 'Santri', urutan: 5, menu: 'Penilaian',
    arti: { 1: 'Belum berpengaruh (nilai diisi di menu kerja penilai)', 2: 'Belum berpengaruh (nilai diisi di menu kerja penilai)', 3: 'Membuka menu Penilaian: mengatur penilaian, mengelola nilai, dan mencetak rapor' },
    keterangan: 'Pengisian nilai tetap di menu kerja penilai (Guru Mapel, Tahfizh, Ekskul, Wali Kelas).', izin: [{ kode: 'atur_penilaian', min: 3 }, { kode: 'kelola_nilai', min: 3 }] },
  { kode: 'jadwal_mengajar', nama: 'Jadwal pelajaran dan guru mapel', kelompok: 'Santri', urutan: 6, menu: 'Jadwal Pelajaran, Guru Mapel',
    arti: { 1: 'Melihat jadwal pelajaran', 2: 'Sama dengan lihat', 3: 'Mengatur jadwal dan penugasan, memantau jurnal mengajar semua guru' },
    keterangan: 'Guru yang memiliki penugasan mengajar otomatis mengisi jurnalnya. Pimpinan bidang memantau jenjangnya.', izin: [{ kode: 'atur_jadwal', min: 3 }] },
  { kode: 'portal_wali', nama: 'Kelola Portal Wali', kelompok: 'Santri', urutan: 7, menu: 'Portal Wali (kesiapan data, sesi wali, pengaturan)',
    arti: { 1: 'Melihat kesiapan data dan sesi wali, membuka kunci, mencabut sesi', 2: 'Sama dengan lihat', 3: 'Juga mengatur butir informasi dan jenis dokumen portal' } },

  // ---------- Fungsional ----------
  { kode: 'absensi_kelas', nama: 'Absensi kelas dan wali kelas', kelompok: 'Fungsional', urutan: 1, menu: 'Absensi Santri, Wali Kelas',
    arti: { 1: 'Memantau absensi kelas seluruh santri (perlu juga Data santri ≥ Lihat)', 2: 'Sama dengan lihat', 3: 'Juga mengisi absensi kelas, halaqah, dan asrama atas nama pengasuh' },
    keterangan: 'Wali kelas yang ditetapkan pada kelasnya otomatis dapat mengisi.', izin: [{ kode: 'absensi_atas_nama', min: 3 }] },
  { kode: 'absensi_asrama', nama: 'Absensi asrama (musyrif)', kelompok: 'Fungsional', urutan: 2, menu: 'Musyrif',
    arti: { 1: 'Memantau absensi asrama dan jurnal musyrif semua kamar', 2: 'Sama dengan lihat', 3: 'Sama dengan lihat' },
    keterangan: 'Musyrif yang ditetapkan pada kamarnya otomatis dapat mengisi.' },
  { kode: 'absensi_ekskul', nama: 'Ekskul', kelompok: 'Fungsional', urutan: 3, menu: 'Ekskul (dasbor, pertemuan, jadwal, rekap, nilai)',
    arti: { 1: 'Memantau semua ekskul, jurnal latihan, dan nilai ekskul', 2: 'Sama dengan lihat', 3: 'Sama dengan lihat' },
    keterangan: 'Pembina yang ditetapkan pada ekskulnya otomatis dapat mengisi.' },
  { kode: 'tahfizh', nama: 'Tahfizh', kelompok: 'Fungsional', urutan: 4, menu: 'Tahfizh',
    arti: { 1: 'Melihat data tahfizh semua halaqah', 2: 'Sama dengan lihat', 3: 'Mengatur ketentuan tahfizh dan memvalidasi capaian hafalan' },
    keterangan: 'Muhaffizh yang ditetapkan pada halaqahnya otomatis dapat mengisi setoran.', izin: [{ kode: 'atur_tahfizh', min: 3 }, { kode: 'validasi_tahfizh', min: 3 }] },
  { kode: 'klinik', nama: 'Klinik', kelompok: 'Fungsional', urutan: 5, menu: 'Klinik',
    arti: { 1: 'Membuka menu Klinik', 2: 'Sama dengan lihat', 3: 'Mengelola ketentuan dan seluruh catatan pemeriksaan' },
    keterangan: 'Petugas kesehatan diatur di Klinik → Petugas.', izin: [{ kode: 'kelola_klinik', min: 3 }] },
  { kode: 'gerbang', nama: 'Security', kelompok: 'Fungsional', urutan: 6, menu: 'Security (gerbang, titipan, buku tamu, kunjungan)',
    arti: { 1: 'Melihat aktivitas security', 2: 'Petugas: mencatat keluar-masuk, titipan, tamu, dan kunjungan', 3: 'Mengelola ketentuan security' },
    izin: [{ kode: 'kelola_security', min: 3 }] },

  // ---------- Layanan ----------
  { kode: 'perizinan_santri', nama: 'Perizinan dan libur santri', kelompok: 'Layanan', urutan: 1, menu: 'Perizinan, Libur Santri',
    arti: { 1: 'Melihat perizinan dan libur santri', 2: 'Sama dengan lihat', 3: 'Mengelola semua izin santri, periode libur, dan ketentuannya' },
    keterangan: 'Pemutus izin mengikuti jabatan struktural (Kepala Bidang Kesantrian, Direktur/Wadir, Plt).',
    izin: [{ kode: 'kelola_izin_santri', min: 3 }, { kode: 'kelola_libur', min: 3 }] },
  { kode: 'lapor_bidang', nama: 'Laporan ke bidang', kelompok: 'Layanan', urutan: 2, menu: 'Laporan',
    arti: { 1: 'Membuka menu Laporan dan membuat laporan', 2: 'Sama dengan lihat', 3: 'Mengelola semua laporan, kategori, dan rekap' },
    keterangan: 'Penerima laporan mengikuti kategori.', bawaan: { semua: 1 }, izin: [{ kode: 'kelola_lapor', min: 3 }] },
  { kode: 'pantauan', nama: 'Layar Pantauan', kelompok: 'Layanan', urutan: 3, menu: 'Layar Pantauan, grafik periodik di Beranda',
    arti: { 1: 'Membuka Layar Pantauan dan grafik periodik seluruh pondok di Beranda', 2: 'Sama dengan lihat', 3: 'Sama dengan lihat' },
    keterangan: 'Admin dan superadmin selalu dapat membuka. Bawaan: semua jabatan struktural.' },

  // ---------- Administrasi ----------
  { kode: 'laporan', nama: 'Dokumen dan laporan kehadiran', kelompok: 'Administrasi', urutan: 1, menu: 'Dokumen (rekap presensi, laporan kehadiran, dokumen resmi)',
    arti: { 1: 'Membuka menu Dokumen untuk data dirinya dan dokumen yang perlu ditandatanganinya', 2: 'Melihat laporan kehadiran seluruh pegawai dan santri', 3: 'Sama dengan input/ubah' },
    keterangan: 'Pimpinan tetap melihat laporan anggota unitnya.', bawaan: { semua: 1 } },
  { kode: 'tata_usaha', nama: 'Persuratan', kelompok: 'Administrasi', urutan: 2, menu: 'Persuratan',
    arti: { 1: 'Membuka menu Persuratan', 2: 'Mengelola surat masuk, surat keluar, dan buku agenda', 3: 'Sama dengan input/ubah' },
    keterangan: 'Pimpinan penerima surat dan penerima disposisi otomatis dapat membuka.', izin: [{ kode: 'kelola_persuratan', min: 2 }] },
  { kode: 'surat_teguran', nama: 'Surat teguran', kelompok: 'Administrasi', urutan: 3, menu: 'Persuratan → Surat Teguran (SP1–SP3)',
    arti: { 1: 'Melihat semua surat teguran dan rekapnya', 2: 'Mengusulkan surat teguran bagi pegawai di bidang/unit yang dipimpinnya', 3: 'Mengusulkan bagi semua pegawai, mencabut surat teguran, dan mengatur ketentuannya' },
    keterangan: 'Surat diproses Tata Usaha dan ditandatangani Direktur (paling tinggi Ketua Yayasan). Penerima, pengusul, dan atasan langsung otomatis melihat surat terkait.',
    izin: [{ kode: 'kelola_teguran', min: 3 }] },
  { kode: 'beban_kerja', nama: 'Beban kerja', kelompok: 'Administrasi', urutan: 4, menu: 'Beban Kerja',
    arti: { 1: 'Melihat beban kerjanya sendiri', 2: 'Melihat rekap beban kerja seluruh pegawai', 3: 'Juga mengatur jam tupoksi, tugas tambahan, dan tampilan di akun pegawai' },
    keterangan: 'Pimpinan tetap melihat beban kerja anggota unitnya. Pegawai yang dinyalakan "tampil di akun pegawai" tetap melihat beban kerjanya sendiri.', izin: [{ kode: 'atur_beban_kerja', min: 3 }] },
  { kode: 'gaji', nama: 'Gaji', kelompok: 'Administrasi', urutan: 5, menu: 'Gaji', arti: {}, sensitif: true,
    kunci: 'Fitur sensitif: diatur per orang di tab Fitur sensitif sesuai keputusan yayasan.' },
  { kode: 'tunjangan', nama: 'Tunjangan', kelompok: 'Administrasi', urutan: 6, menu: 'Tunjangan', arti: {}, sensitif: true,
    kunci: 'Fitur sensitif: mengikuti hak Gaji di tab Fitur sensitif.' },
  { kode: 'keuangan', nama: 'Keuangan santri', kelompok: 'Administrasi', urutan: 7, menu: 'Keuangan', arti: {}, sensitif: true,
    kunci: 'Fitur sensitif: diatur per orang di tab Fitur sensitif sesuai keputusan yayasan.' },

  // ---------- Sistem ----------
  { kode: 'audit_log', nama: 'Audit log', kelompok: 'Sistem', urutan: 1, menu: 'Audit Log',
    arti: { 1: 'Melihat audit log seluruh aktivitas (30 hari terakhir)', 2: 'Sama dengan lihat', 3: 'Sama dengan lihat' },
    keterangan: 'Bawaan: khusus superadmin.' },
  { kode: 'organisasi', nama: 'Organisasi', kelompok: 'Sistem', urutan: 2, menu: 'Organisasi (bidang, unit, jabatan)',
    arti: { 1: 'Melihat struktur organisasi dan daftar jabatan', 2: 'Mengubah bidang, unit, dan jabatan', 3: 'Sama dengan input/ubah' },
    keterangan: 'Bawaan: khusus superadmin.' },
  { kode: 'setelan', nama: 'Setelan', kelompok: 'Sistem', urutan: 3, menu: 'Setelan (lembaga, kop, logo, penanda tangan, nomor surat, template WA)',
    arti: {}, kunci: 'Khusus superadmin: kop, penanda tangan, dan nomor surat menentukan keabsahan dokumen bertanda tangan elektronik.' },
  { kode: 'hak_akses', nama: 'Hak Akses', kelompok: 'Sistem', urutan: 4, menu: 'Hak Akses',
    arti: {}, kunci: 'Khusus superadmin: pemegang menu ini dapat memberi dirinya sendiri semua akses.' },
]

/** Fitur lama yang tidak lagi diatur (tergabung dalam fitur lain). */
export const FITUR_TIDAK_DIATUR = [
  { kode: 'absensi_halaqah', keterangan: 'Tergabung dalam fitur Tahfizh dan muhaffizh pada halaqahnya.' },
  { kode: 'titipan', keterangan: 'Tergabung dalam fitur Security.' },
  { kode: 'buku_tamu', keterangan: 'Tergabung dalam fitur Security.' },
  { kode: 'kunjungan', keterangan: 'Tergabung dalam fitur Security.' },
  { kode: 'kartu_pegawai', keterangan: 'Kartu sendiri di Profil; cetak massal tergabung dalam Data pegawai.' },
  { kode: 'template_wa', keterangan: 'Tergabung dalam Setelan (khusus superadmin).' },
  { kode: 'pengaturan_lembaga', keterangan: 'Tergabung dalam Setelan (khusus superadmin).' },
]

/** Izin admin → fitur dan tingkat minimal yang juga memberi izin itu (dipakai mode demo). */
export const PETA_IZIN = KATALOG_FITUR.flatMap((f) => (f.izin || []).map((i) => ({ kode: i.kode, fitur: f.kode, min: i.min })))
