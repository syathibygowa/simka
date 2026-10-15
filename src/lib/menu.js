// SIMKA PRO | src/lib/menu.js | v3.25 | Fase 9 – Perbaikan: menu Portal Wali tersendiri; Roster menjadi Jadwal Pelajaran | 15/10/2026
// Daftar menu SIMKA PRO, dikelompokkan: Utama, Presensi, Layanan Pegawai (milik setiap pegawai),
// Kepegawaian (pengelolaan data), Santri, Fungsional, Layanan, Administrasi, Sistem. Setiap menu memiliki ikon Phosphor (duotone) dan
// warna sendiri (kelas .w-* di token.css). "fase" menandai menu yang dibangun
// pada fase berikutnya; menu tersebut tampil dengan lencana fase.
import {
  PhHouse, PhFingerprint, PhUsersThree, PhStudent, PhBookOpenText, PhFileText, PhFirstAidKit,
  PhShieldCheck, PhChartBar, PhEnvelopeSimple, PhWallet, PhMegaphone, PhKey, PhGearSix, PhBell,
  PhFiles, PhUserCircle, PhSquaresFour, PhUserCheck, PhNotebook, PhIdentificationCard, PhTreeStructure, PhCoins, PhCashRegister, PhMapPinArea, PhCalendarStar, PhSealCheck, PhChartLineUp, PhClockCounterClockwise, PhFolderOpen, PhCalendarCheck, PhUsersFour, PhClockCountdown, PhChalkboardTeacher, PhCheckSquareOffset, PhMedal, PhCalendarDots, PhChartPieSlice, PhCalendarPlus, PhBuildings, PhSignOut, PhListMagnifyingGlass, PhChalkboard, PhPresentationChart, PhExam, PhTrophy,
} from '@phosphor-icons/vue'

const ADMIN = ['admin', 'superadmin']
export const MENU = [
  // Utama
  { kode: 'beranda',    nama: 'Beranda',         ikon: PhHouse,          warna: 'beranda',    ke: '/',                  grup: 'Utama' },
  { kode: 'notifikasi', nama: 'Notifikasi',      ikon: PhBell,           warna: 'notifikasi', ke: '/notifikasi',        grup: 'Utama' },
  { kode: 'pengumuman', nama: 'Pengumuman',      ikon: PhMegaphone,      warna: 'pengumuman', ke: '/pengumuman',        grup: 'Utama' },
  { kode: 'agenda',     nama: 'Agenda',          ikon: PhCalendarCheck,  warna: 'agenda',     ke: '/agenda',            grup: 'Utama' },
  // Presensi
  { kode: 'presensi',   nama: 'Presensi',        ikon: PhFingerprint,    warna: 'presensi',   ke: '/presensi',          grup: 'Presensi' },
  { kode: 'jadwalshift', nama: 'Jadwal Shift',   ikon: PhCalendarStar,   warna: 'shift',      ke: '/jadwal-shift',      grup: 'Presensi', syarat: 'shift' },
  { kode: 'vervalpresensi', nama: 'Verval Presensi', ikon: PhSealCheck,   warna: 'verval',     ke: '/verval-presensi',   grup: 'Presensi', peran: ADMIN, izin: 'verval_presensi' },
  { kode: 'datapresensi', nama: 'Data Presensi', ikon: PhListMagnifyingGlass, warna: 'datapresensi', ke: '/data-presensi', grup: 'Presensi', peran: ADMIN, izin: 'verval_presensi' },
  { kode: 'aturpresensi', nama: 'Penjadwalan', ikon: PhMapPinArea, warna: 'aturpresensi', ke: '/atur-presensi', grup: 'Presensi', peran: ADMIN, izin: 'atur_presensi' },
  // Layanan pegawai (milik setiap pegawai)
  { kode: 'pengajuan',  nama: 'Pengajuan',       ikon: PhFileText,       warna: 'pengajuan',  ke: '/pengajuan',         grup: 'Layanan Pegawai' },
  { kode: 'jurnal',     nama: 'Jurnal Harian',   ikon: PhNotebook,       warna: 'tatausaha',  ke: '/jurnal',            grup: 'Layanan Pegawai' },
  { kode: 'berkas',     nama: 'Berkas Saya',     ikon: PhFolderOpen,     warna: 'berkas',     ke: '/berkas',            grup: 'Layanan Pegawai' },
  // Kepegawaian (pengelolaan data pegawai)
  { kode: 'pegawai',    nama: 'Data Pegawai',    ikon: PhUsersThree,     warna: 'pegawai',    ke: '/pegawai',           grup: 'Kepegawaian', peran: ADMIN },
  { kode: 'verifikasi', nama: 'Verifikasi Akun', ikon: PhUserCheck,      warna: 'verifikasi', ke: '/verifikasi',        grup: 'Kepegawaian', peran: ADMIN, izin: 'verval_akun' },
  // Fase berikutnya
  { kode: 'santri',     nama: 'Data Santri',     ikon: PhStudent,        warna: 'santri',     ke: '/santri',            grup: 'Santri', fitur: 'data_santri' },
  { kode: 'kelompoksantri', nama: 'Kelompok Santri', ikon: PhChalkboardTeacher, warna: 'kelompoksantri', ke: '/kelompok-santri', grup: 'Santri',
    syarat: (c) => c.kelompok || Number(c.fitur?.data_santri ?? 0) >= 1 || Number(c.fitur?.kelompok_santri ?? 0) >= 1 },
  { kode: 'absensisantri', nama: 'Absensi Santri', ikon: PhCheckSquareOffset, warna: 'absensi', ke: '/absensi-santri', grup: 'Santri',
    syarat: (c) => c.kelompok || Number(c.fitur?.absensi_kelas ?? 0) >= 1 },
  { kode: 'statistiksantri', nama: 'Statistik Santri', ikon: PhChartPieSlice, warna: 'rekap', ke: '/statistik-santri', grup: 'Santri', fitur: 'data_santri' },
  { kode: 'tahunajaran', nama: 'Naik Kelas', ikon: PhCalendarPlus, warna: 'agenda', ke: '/tahun-ajaran-baru', grup: 'Santri', peran: ADMIN, izin: 'kelompok_santri' },
  // Portal Wali (Fase 9): pengaturan butir informasi, kesiapan data, sesi wali, percobaan gagal, pengumuman wali
  { kode: 'portalwali', nama: 'Portal Wali', ikon: PhUsersFour, warna: 'portalwali', ke: '/portal-wali', grup: 'Santri', peran: ADMIN, izin: 'kelola_santri' },
  { kode: 'jadwalpelajaran', nama: 'Jadwal Pelajaran', ikon: PhCalendarDots, warna: 'jadwal', ke: '/jadwal-pelajaran', grup: 'Santri',
    syarat: (c) => c.kelompok || Number(c.fitur?.jadwal_mengajar ?? 0) >= 1 },
  // Wali Kelas: wali kelas yang ditetapkan pada kelas, pimpinan/pemegang hak Absensi Kelas atau Jadwal mengajar, admin
  { kode: 'walikelas', nama: 'Wali Kelas', ikon: PhChalkboard, warna: 'walikelas', ke: '/wali-kelas', grup: 'Fungsional',
    syarat: (c) => (c.jenisKelompok || []).includes('kelas') || Number(c.fitur?.absensi_kelas ?? 0) >= 1 || !!c.luas?.jadwal_mengajar },
  // Guru Mapel: guru yang memiliki penugasan mengajar, pimpinan (pantauan), pemegang hak Jadwal mengajar, admin
  { kode: 'gurumapel', nama: 'Guru Mapel', ikon: PhPresentationChart, warna: 'gurumapel', ke: '/guru-mapel', grup: 'Fungsional',
    syarat: (c) => !!c.mengajar || !!c.pimpinan || Number(c.fitur?.jadwal_mengajar ?? 0) >= 3 || !!c.luas?.jadwal_mengajar },
  { kode: 'musyrif', nama: 'Musyrif', ikon: PhBuildings, warna: 'musyrif', ke: '/musyrif', grup: 'Fungsional',
    syarat: (c) => (c.jenisKelompok || []).includes('kamar') || Number(c.fitur?.absensi_asrama ?? 0) >= 1 },
  { kode: 'ekskul', nama: 'Ekskul', ikon: PhMedal, warna: 'ekskul', ke: '/ekskul', grup: 'Fungsional',
    syarat: (c) => (c.jenisKelompok || []).includes('ekskul') || Number(c.fitur?.absensi_ekskul ?? 0) >= 1 },
  { kode: 'tahfizh',    nama: 'Tahfizh',         ikon: PhBookOpenText,   warna: 'tahfizh',    ke: '/tahfizh',           grup: 'Fungsional',
    syarat: (c) => (c.jenisKelompok || []).includes('halaqah') || Number(c.fitur?.tahfizh ?? 0) >= 1 || Number(c.fitur?.data_santri ?? 0) >= 1 || !!c.pengujiUtas || !!c.penguji },
  // Penilaian (Fase 12): pengaturan, rekap, dan permintaan ubah nilai. Pengisian nilai tetap di menu kerja penilai
  // (Guru Mapel, Tahfizh, Ekskul, Wali Kelas). Tampil bagi pengatur penilaian (admin ber-izin atur_penilaian/kelola_nilai,
  // hak fitur Nilai tingkat 3) dan pimpinan bidang SMA/Wustha/Tahfizh.
  { kode: 'prestasi',   nama: 'Prestasi Santri', ikon: PhTrophy,         warna: 'prestasi',   ke: '/prestasi-santri',   grup: 'Santri',
    syarat: (c) => c.kelompok || !!c.pimpinan || Number(c.fitur?.data_santri ?? 0) >= 1 },
  { kode: 'penilaian',  nama: 'Penilaian',       ikon: PhExam,           warna: 'penilaian',  ke: '/penilaian',         grup: 'Santri', hak: (c) => !!c.penilaian },
  { kode: 'klinik',     nama: 'Klinik',          ikon: PhFirstAidKit,    warna: 'klinik',     ke: '/klinik',            grup: 'Fungsional',
    syarat: (c) => c.kelompok || Number(c.fitur?.klinik ?? 0) >= 1 || Number(c.fitur?.data_santri ?? 0) >= 1 },
  { kode: 'izinsantri', nama: 'Perizinan', ikon: PhSignOut, warna: 'pengajuan', ke: '/izin-santri', grup: 'Layanan',
    syarat: (c) => c.kelompok || Number(c.fitur?.perizinan_santri ?? 0) >= 1 || Number(c.fitur?.data_santri ?? 0) >= 1 || (c.izin || []).includes('kelola_izin_santri') },
  { kode: 'lapor', nama: 'Laporan', ikon: PhMegaphone, warna: 'laporan', ke: '/lapor', grup: 'Layanan' },
  { kode: 'security',   nama: 'Security',        ikon: PhShieldCheck,    warna: 'security',   ke: '/security',          grup: 'Fungsional',
    syarat: (c) => Number(c.fitur?.gerbang ?? 0) >= 1 || Number(c.fitur?.pantauan ?? 0) >= 1 || (c.izin || []).includes('kelola_security')
      || (c.jenisKelompok || []).some((j) => ['kamar', 'kelas', 'halaqah'].includes(j)) },
  // Dokumen: rekap presensi, laporan kehadiran, dan dokumen resmi dalam satu menu bertab (hemat menu)
  { kode: 'rekap',      nama: 'Dokumen',         ikon: PhFiles,    warna: 'rekap',      ke: '/rekap',             grup: 'Administrasi' },
  // Persuratan: Tata Usaha/pengelola, pimpinan penerima surat, dan pegawai yang pernah menerima disposisi
  { kode: 'persuratan', nama: 'Persuratan',      ikon: PhEnvelopeSimple, warna: 'tatausaha',  ke: '/persuratan',        grup: 'Administrasi',
    syarat: (c) => !!c.persuratan || (c.izin || []).includes('kelola_persuratan') || Number(c.fitur?.tata_usaha ?? 0) >= 1 },
  // Gaji: pengelola/pembaca gaji (superadmin dan yang ditunjuk superadmin) dan pegawai bila slip ditampilkan di akun pegawai
  { kode: 'gaji',       nama: 'Gaji',            ikon: PhWallet,         warna: 'gaji',       ke: '/gaji',              grup: 'Administrasi', hak: (c) => !!c.gaji },
  // Tunjangan: tarif, peta tunjangan, rekening, pengingat kenaikan (pengelola dan pembaca gaji)
  { kode: 'bebankerja', nama: 'Beban Kerja',     ikon: PhClockCountdown, warna: 'gaji',       ke: '/beban-kerja',       grup: 'Administrasi',
    hak: (c) => !!(c.beban?.saya || c.beban?.rekap || c.beban?.atur) },
  { kode: 'tunjangan',  nama: 'Tunjangan',       ikon: PhCoins,          warna: 'tahfizh',    ke: '/tunjangan',         grup: 'Administrasi', hak: (c) => !!c.gajiLihat },
  // Keuangan santri: hanya superadmin dan pegawai yang ditunjuk superadmin (mis. Bendahara Pondok)
  { kode: 'keuangan',   nama: 'Keuangan',        ikon: PhCashRegister,   warna: 'keuangan',   ke: '/keuangan',          grup: 'Administrasi', hak: (c) => !!c.keuangan },
  // Sistem
  { kode: 'auditlog',   nama: 'Audit Log',       ikon: PhClockCounterClockwise, warna: 'audit', ke: '/audit-log',     grup: 'Sistem' },
  { kode: 'organisasi', nama: 'Organisasi', ikon: PhTreeStructure, warna: 'sistem',  ke: '/organisasi',        grup: 'Sistem', peran: ['superadmin'] },
  { kode: 'hakakses',   nama: 'Hak Akses',       ikon: PhKey,            warna: 'hakakses',   ke: '/hak-akses',         grup: 'Sistem', peran: ['superadmin'] },
  { kode: 'pengaturan', nama: 'Setelan',         ikon: PhGearSix,        warna: 'pengaturan', ke: '/pengaturan',        grup: 'Sistem', peran: ['superadmin'] },
  { kode: 'profil',     nama: 'Profil',          ikon: PhUserCircle,     warna: 'profil',     ke: '/profil',            grup: 'Akun' },
]

// Navigasi bawah (mobile) — empat tab seperti aplikasi Android
/** Navigasi bawah HP: 5 menu, Presensi di tengah sebagai tombol utama yang menonjol. */
export const NAV_BAWAH = [
  { kode: 'beranda',  nama: 'Beranda',  ikon: PhHouse,       warna: 'beranda',   ke: '/' },
  { kode: 'jurnal',   nama: 'Jurnal',   ikon: PhNotebook,    warna: 'tatausaha', ke: '/jurnal' },
  { kode: 'presensi', nama: 'Presensi', ikon: PhFingerprint, warna: 'presensi',  ke: '/presensi', utama: true },
  { kode: 'tugas',    nama: 'Tugas',    ikon: PhSquaresFour, warna: 'tugas',     ke: '/tugas' },
  { kode: 'profil',   nama: 'Profil',   ikon: PhUserCircle,  warna: 'profil',    ke: '/profil' },
]

export const GRUP = ['Utama', 'Presensi', 'Layanan Pegawai', 'Kepegawaian', 'Santri', 'Fungsional', 'Layanan', 'Administrasi', 'Sistem']
/** Menu sesuai peran. ciri.shift = pegawai memegang pola shift (menu Jadwal Shift tampil juga untuk admin). */
/** ciri.izin = izin admin yang dimiliki; menu ber-"izin" hanya tampil bagi superadmin atau admin yang memiliki izin itu. */
/** ciri.fitur = hak fitur pegawai; menu ber-"fitur" tampil bagi admin/superadmin atau pegawai dengan tingkat ≥ 1. */
/** m.hak(ciri) = syarat yang berlaku juga bagi admin (hanya superadmin yang dikecualikan), mis. menu Gaji. */
export const menuUntuk = (peran, ciri = {}) => MENU.filter((m) => (!m.peran || m.peran.includes(peran))
  && (!m.syarat || ADMIN.includes(peran) || (typeof m.syarat === 'function' ? m.syarat(ciri) : ciri[m.syarat]))
  && (!m.fitur || ADMIN.includes(peran) || Number(ciri.fitur?.[m.fitur] ?? 0) >= 1)
  && (!m.izin || peran === 'superadmin' || (ciri.izin || []).includes(m.izin))
  && (!m.hak || peran === 'superadmin' || m.hak(ciri)))
export const cariMenu = (kode) => MENU.find((m) => m.kode === kode)
