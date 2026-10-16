// SIMKA PRO | src/lib/hakAkses.js | v1.0 | Perbaikan 13.9.0: katalog Hak Akses Fitur (menu yang dikendalikan dan arti setiap tingkat) | 16/10/2026
// Sama dengan isi migrasi 20261019011100_katalog_hak_akses.sql. Dipakai sebagai cadangan bila kolom keterangan belum ada di database
// dan sebagai data mode demo. arti: makna tingkat 1 (lihat), 2 (input/ubah), 3 (kelola) sesuai pemeriksaan di server.
export const KATALOG_FITUR = [
  {"kode": "data_santri", "nama": "Data santri", "kelompok": "Santri", "urutan": 1, "menu": "Data Santri, Statistik Santri, Kelengkapan Data, Prestasi Santri", "arti": {"1": "Melihat data seluruh santri dan statistiknya", "2": "Menambah dan mengubah data santri", "3": "Sama dengan input/ubah"}, "keterangan": "Juga membuka menu Tahfizh, Klinik, Perizinan, dan Libur Santri untuk dilihat.", "dipakai": true},
  {"kode": "kelompok_santri", "nama": "Kelompok santri", "kelompok": "Santri", "urutan": 2, "menu": "Kelompok Santri, kategori Ekskul", "arti": {"1": "Melihat semua kelompok (kelas, kamar, halaqah, ekskul)", "2": "Mengatur kelompok, pengasuh, anggota, dan kategori ekskul", "3": "Sama dengan input/ubah"}, "keterangan": null, "dipakai": true},
  {"kode": "absensi_kelas", "nama": "Absensi kelas dan wali kelas", "kelompok": "Santri", "urutan": 3, "menu": "Absensi Santri, Wali Kelas", "arti": {"1": "Memantau absensi kelas seluruh santri (perlu juga Data santri ≥ Lihat)", "2": "Sama dengan lihat", "3": "Sama dengan lihat"}, "keterangan": "Wali kelas yang ditetapkan pada kelasnya otomatis dapat mengisi.", "dipakai": true},
  {"kode": "absensi_asrama", "nama": "Absensi asrama (musyrif)", "kelompok": "Santri", "urutan": 4, "menu": "Musyrif, Absensi Santri", "arti": {"1": "Memantau absensi asrama dan jurnal musyrif semua kamar", "2": "Sama dengan lihat", "3": "Sama dengan lihat"}, "keterangan": "Musyrif yang ditetapkan pada kamarnya otomatis dapat mengisi.", "dipakai": true},
  {"kode": "absensi_ekskul", "nama": "Ekskul", "kelompok": "Santri", "urutan": 5, "menu": "Ekskul (dasbor, pertemuan, jadwal, rekap, nilai)", "arti": {"1": "Memantau semua ekskul, jurnal latihan, dan nilai ekskul", "2": "Sama dengan lihat", "3": "Sama dengan lihat"}, "keterangan": "Pembina yang ditetapkan pada ekskulnya otomatis dapat mengisi.", "dipakai": true},
  {"kode": "tahfizh", "nama": "Tahfizh", "kelompok": "Santri", "urutan": 6, "menu": "Tahfizh", "arti": {"1": "Melihat data tahfizh semua halaqah", "2": "Sama dengan lihat", "3": "Mengatur ketentuan tahfizh dan memvalidasi capaian hafalan"}, "keterangan": "Muhaffizh yang ditetapkan pada halaqahnya otomatis dapat mengisi setoran.", "dipakai": true},
  {"kode": "jadwal_mengajar", "nama": "Jadwal pelajaran dan guru mapel", "kelompok": "Santri", "urutan": 7, "menu": "Jadwal Pelajaran, Guru Mapel, Wali Kelas (pantau)", "arti": {"1": "Melihat jadwal pelajaran", "2": "Sama dengan lihat", "3": "Mengatur jadwal dan penugasan, memantau jurnal mengajar semua guru"}, "keterangan": "Guru yang memiliki penugasan mengajar otomatis mengisi jurnalnya.", "dipakai": true},
  {"kode": "nilai", "nama": "Penilaian dan rapor", "kelompok": "Santri", "urutan": 8, "menu": "Penilaian", "arti": {"1": "Belum berpengaruh", "2": "Belum berpengaruh", "3": "Mengatur penilaian, mengelola nilai, dan mencetak rapor"}, "keterangan": null, "dipakai": true},
  {"kode": "klinik", "nama": "Klinik", "kelompok": "Layanan", "urutan": 1, "menu": "Klinik", "arti": {"1": "Membuka menu Klinik", "2": "Sama dengan lihat", "3": "Mengelola ketentuan dan seluruh catatan pemeriksaan"}, "keterangan": "Petugas kesehatan diatur di Klinik → Petugas.", "dipakai": true},
  {"kode": "perizinan_santri", "nama": "Perizinan dan libur santri", "kelompok": "Layanan", "urutan": 2, "menu": "Perizinan, Libur Santri", "arti": {"1": "Melihat perizinan dan libur santri", "2": "Sama dengan lihat", "3": "Mengelola semua izin santri dan ketentuannya"}, "keterangan": "Pemutus izin mengikuti jabatan struktural (Kepala Bidang Kesantrian, Direktur/Wadir, Plt).", "dipakai": true},
  {"kode": "gerbang", "nama": "Security", "kelompok": "Layanan", "urutan": 3, "menu": "Security (gerbang, titipan, buku tamu, kunjungan)", "arti": {"1": "Melihat aktivitas security", "2": "Petugas: mencatat keluar-masuk, titipan, tamu, dan kunjungan", "3": "Mengelola ketentuan security"}, "keterangan": null, "dipakai": true},
  {"kode": "pantauan", "nama": "Pantauan pimpinan", "kelompok": "Layanan", "urutan": 4, "menu": "Layar Pantauan, kartu pimpinan di Beranda", "arti": {"1": "Membuka layar pantauan dan dasbor pimpinan", "2": "Sama dengan lihat", "3": "Sama dengan lihat"}, "keterangan": "Pejabat struktural otomatis mendapat pantauan untuk unitnya.", "dipakai": true},
  {"kode": "lapor_bidang", "nama": "Laporan ke bidang", "kelompok": "Layanan", "urutan": 5, "menu": "Laporan", "arti": {"1": "Belum berpengaruh", "2": "Belum berpengaruh", "3": "Mengelola semua laporan, kategori, dan rekap"}, "keterangan": "Setiap pegawai dapat membuat laporan; penerima mengikuti kategori.", "dipakai": true},
  {"kode": "tata_usaha", "nama": "Persuratan", "kelompok": "Administrasi", "urutan": 1, "menu": "Persuratan", "arti": {"1": "Membuka menu Persuratan", "2": "Mengelola surat masuk, surat keluar, dan buku agenda", "3": "Sama dengan input/ubah"}, "keterangan": "Pimpinan penerima surat dan penerima disposisi otomatis dapat membuka.", "dipakai": true},
  {"kode": "pengumuman", "nama": "Pengumuman", "kelompok": "Sistem", "urutan": 1, "menu": "Pengumuman, Pengumuman wali", "arti": {"1": "Belum berpengaruh (semua pegawai membaca pengumuman)", "2": "Membuat pengumuman pegawai", "3": "Sama dengan input/ubah"}, "keterangan": "Pimpinan unit dapat membuat pengumuman untuk wali santri.", "dipakai": true}
]
export const FITUR_TIDAK_DIATUR = [
  {"kode": "data_pegawai", "keterangan": "Diatur lewat izin admin \"Mengelola data kepegawaian\"."},
  {"kode": "presensi", "keterangan": "Otomatis untuk setiap pegawai; pengaturan lewat izin admin Presensi."},
  {"kode": "pengajuan", "keterangan": "Otomatis untuk setiap pegawai; pengaturan lewat izin admin Pengajuan."},
  {"kode": "jurnal_harian", "keterangan": "Otomatis untuk setiap pegawai; verval lewat izin admin Jurnal."},
  {"kode": "berkas_pegawai", "keterangan": "Otomatis untuk setiap pegawai; pengiriman lewat izin admin Berkas."},
  {"kode": "kartu_pegawai", "keterangan": "Otomatis untuk setiap pegawai; cetak massal lewat izin admin."},
  {"kode": "absensi_halaqah", "keterangan": "Tergabung dalam fitur Tahfizh dan muhaffizh pada halaqahnya."},
  {"kode": "titipan", "keterangan": "Tergabung dalam fitur Security."},
  {"kode": "buku_tamu", "keterangan": "Tergabung dalam fitur Security."},
  {"kode": "kunjungan", "keterangan": "Tergabung dalam fitur Security."},
  {"kode": "laporan", "keterangan": "Menu Dokumen terbuka untuk semua pegawai sesuai cakupannya."},
  {"kode": "template_wa", "keterangan": "Khusus superadmin (Setelan → Template WA)."},
  {"kode": "pengaturan_lembaga", "keterangan": "Khusus superadmin (Setelan)."},
  {"kode": "hak_akses", "keterangan": "Khusus superadmin."}
]
