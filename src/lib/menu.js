// SIMKA PRO | src/lib/menu.js | v3.7 | Fase 7 – Tahap 4 Pantauan langsung pimpinan | 06/10/2026
// Daftar menu SIMKA PRO, dikelompokkan: Utama, Presensi, Layanan Pegawai (milik setiap pegawai),
// Kepegawaian (pengelolaan data), Santri, Layanan, Administrasi, Sistem. Setiap menu memiliki ikon Phosphor (duotone) dan
// warna sendiri (kelas .w-* di token.css). "fase" menandai menu yang dibangun
// pada fase berikutnya; menu tersebut tampil dengan lencana fase.
import {
  PhHouse, PhFingerprint, PhUsersThree, PhStudent, PhBookOpenText, PhFileText, PhFirstAidKit,
  PhShieldCheck, PhChartBar, PhEnvelopeSimple, PhWallet, PhMegaphone, PhKey, PhGearSix, PhBell,
  PhUserCircle, PhSquaresFour, PhUserCheck, PhNotebook, PhIdentificationCard, PhTreeStructure, PhCoins, PhMapPinArea, PhCalendarStar, PhSealCheck, PhChartLineUp, PhClockCounterClockwise, PhFolderOpen, PhCalendarCheck, PhUsersFour, PhClockCountdown, PhChalkboardTeacher, PhCheckSquareOffset, PhMedal, PhCalendarDots, PhChartPieSlice, PhCalendarPlus, PhBuildings, PhSignOut, PhBroadcast,
} from '@phosphor-icons/vue'

const ADMIN = ['admin', 'superadmin']
export const MENU = [
  // Utama
  { kode: 'beranda',    nama: 'Beranda',         ikon: PhHouse,          warna: 'beranda',    ke: '/',                  grup: 'Utama' },
  { kode: 'notifikasi', nama: 'Notifikasi',      ikon: PhBell,           warna: 'notifikasi', ke: '/notifikasi',        grup: 'Utama' },
  { kode: 'pengumuman', nama: 'Pengumuman',      ikon: PhMegaphone,      warna: 'pengumuman', ke: '/pengumuman',        grup: 'Utama' },
  { kode: 'agenda',     nama: 'Agenda',          ikon: PhCalendarCheck,  warna: 'agenda',     ke: '/agenda',            grup: 'Utama' },
  { kode: 'pantauan',   nama: 'Pantauan Langsung', ikon: PhBroadcast,    warna: 'shift',      ke: '/pantauan',          grup: 'Utama',
    syarat: (c) => c.struktural || Number(c.fitur?.pantauan ?? 0) >= 1 },
  // Presensi
  { kode: 'presensi',   nama: 'Presensi',        ikon: PhFingerprint,    warna: 'presensi',   ke: '/presensi',          grup: 'Presensi' },
  { kode: 'jadwalshift', nama: 'Jadwal Shift',   ikon: PhCalendarStar,   warna: 'shift',      ke: '/jadwal-shift',      grup: 'Presensi', syarat: 'shift' },
  { kode: 'vervalpresensi', nama: 'Verval Presensi', ikon: PhSealCheck,   warna: 'verval',     ke: '/verval-presensi',   grup: 'Presensi', peran: ADMIN, izin: 'verval_presensi' },
  { kode: 'rekappresensi', nama: 'Rekap Presensi', ikon: PhChartLineUp,  warna: 'rekap',      ke: '/rekap-presensi',    grup: 'Presensi', peran: ADMIN },
  { kode: 'aturpresensi', nama: 'Pengaturan Presensi', ikon: PhMapPinArea, warna: 'aturpresensi', ke: '/atur-presensi', grup: 'Presensi', peran: ADMIN, izin: 'atur_presensi' },
  // Layanan pegawai (milik setiap pegawai)
  { kode: 'pengajuan',  nama: 'Pengajuan',       ikon: PhFileText,       warna: 'pengajuan',  ke: '/pengajuan',         grup: 'Layanan Pegawai' },
  { kode: 'jurnal',     nama: 'Jurnal Harian',   ikon: PhNotebook,       warna: 'tatausaha',  ke: '/jurnal',            grup: 'Layanan Pegawai' },
  { kode: 'berkas',     nama: 'Berkas Saya',     ikon: PhFolderOpen,     warna: 'berkas',     ke: '/berkas',            grup: 'Layanan Pegawai' },
  { kode: 'bebankerja', nama: 'Beban Kerja',     ikon: PhClockCountdown, warna: 'gaji',       ke: '/beban-kerja',       grup: 'Layanan Pegawai' },
  { kode: 'kartu',      nama: 'Kartu Pegawai',   ikon: PhIdentificationCard, warna: 'profil', ke: '/kartu',             grup: 'Layanan Pegawai' },
  // Kepegawaian (pengelolaan data pegawai)
  { kode: 'pegawai',    nama: 'Data Pegawai',    ikon: PhUsersThree,     warna: 'pegawai',    ke: '/pegawai',           grup: 'Kepegawaian', peran: ADMIN },
  { kode: 'kelompok',   nama: 'Kelompok Pegawai', ikon: PhUsersFour,     warna: 'pegawai',    ke: '/kelompok-pegawai',  grup: 'Kepegawaian', peran: ADMIN, izin: 'kelola_kelompok' },
  { kode: 'verifikasi', nama: 'Verifikasi Akun', ikon: PhUserCheck,      warna: 'verifikasi', ke: '/verifikasi',        grup: 'Kepegawaian', peran: ADMIN, izin: 'verval_akun' },
  { kode: 'tunjangan',  nama: 'Jabatan dan Tunjangan', ikon: PhCoins,    warna: 'gaji',       ke: '/jabatan-tunjangan', grup: 'Kepegawaian', peran: ['superadmin'] },
  // Fase berikutnya
  { kode: 'santri',     nama: 'Data Santri',     ikon: PhStudent,        warna: 'santri',     ke: '/santri',            grup: 'Santri', fitur: 'data_santri' },
  { kode: 'kelompoksantri', nama: 'Kelompok Santri', ikon: PhChalkboardTeacher, warna: 'kelompoksantri', ke: '/kelompok-santri', grup: 'Santri',
    syarat: (c) => c.kelompok || Number(c.fitur?.data_santri ?? 0) >= 1 || Number(c.fitur?.kelompok_santri ?? 0) >= 1 },
  { kode: 'absensisantri', nama: 'Absensi Santri', ikon: PhCheckSquareOffset, warna: 'absensi', ke: '/absensi-santri', grup: 'Santri',
    syarat: (c) => c.kelompok || Number(c.fitur?.absensi_kelas ?? 0) >= 1 },
  { kode: 'statistiksantri', nama: 'Statistik Santri', ikon: PhChartPieSlice, warna: 'rekap', ke: '/statistik-santri', grup: 'Santri', fitur: 'data_santri' },
  { kode: 'tahunajaran', nama: 'Tahun Ajaran Baru', ikon: PhCalendarPlus, warna: 'agenda', ke: '/tahun-ajaran-baru', grup: 'Santri', peran: ADMIN, izin: 'kelompok_santri' },
  { kode: 'jadwalpelajaran', nama: 'Jadwal Pelajaran', ikon: PhCalendarDots, warna: 'jadwal', ke: '/jadwal-pelajaran', grup: 'Santri',
    syarat: (c) => c.kelompok || Number(c.fitur?.jadwal_mengajar ?? 0) >= 1 },
  { kode: 'musyrif', nama: 'Musyrif', ikon: PhBuildings, warna: 'musyrif', ke: '/musyrif', grup: 'Santri',
    syarat: (c) => (c.jenisKelompok || []).includes('kamar') || Number(c.fitur?.absensi_asrama ?? 0) >= 1 },
  { kode: 'ekskul', nama: 'Ekskul', ikon: PhMedal, warna: 'ekskul', ke: '/ekskul', grup: 'Santri',
    syarat: (c) => (c.jenisKelompok || []).includes('ekskul') || Number(c.fitur?.absensi_ekskul ?? 0) >= 1 },
  { kode: 'tahfizh',    nama: 'Tahfizh',         ikon: PhBookOpenText,   warna: 'tahfizh',    ke: '/tahfizh',           grup: 'Santri',
    syarat: (c) => (c.jenisKelompok || []).includes('halaqah') || Number(c.fitur?.tahfizh ?? 0) >= 1 || Number(c.fitur?.data_santri ?? 0) >= 1 },
  { kode: 'klinik',     nama: 'Klinik',          ikon: PhFirstAidKit,    warna: 'klinik',     ke: '/klinik',            grup: 'Layanan',
    syarat: (c) => c.kelompok || Number(c.fitur?.klinik ?? 0) >= 1 || Number(c.fitur?.data_santri ?? 0) >= 1 },
  { kode: 'izinsantri', nama: 'Perizinan Santri', ikon: PhSignOut, warna: 'pengajuan', ke: '/izin-santri', grup: 'Layanan',
    syarat: (c) => c.kelompok || Number(c.fitur?.perizinan_santri ?? 0) >= 1 || Number(c.fitur?.data_santri ?? 0) >= 1 || (c.izin || []).includes('kelola_izin_santri') },
  { kode: 'lapor', nama: 'Lapor ke Bidang', ikon: PhMegaphone, warna: 'laporan', ke: '/lapor', grup: 'Layanan' },
  { kode: 'security',   nama: 'Security',        ikon: PhShieldCheck,    warna: 'security',   ke: '/security',          grup: 'Layanan',
    syarat: (c) => Number(c.fitur?.gerbang ?? 0) >= 1 || Number(c.fitur?.pantauan ?? 0) >= 1 || (c.izin || []).includes('kelola_security')
      || (c.jenisKelompok || []).some((j) => ['kamar', 'kelas', 'halaqah'].includes(j)) },
  { kode: 'laporan',    nama: 'Laporan',         ikon: PhChartBar,       warna: 'laporan',    ke: '/segera/laporan',    grup: 'Administrasi', fase: 8 },
  { kode: 'tatausaha',  nama: 'Tata Usaha',      ikon: PhEnvelopeSimple, warna: 'tatausaha',  ke: '/segera/tatausaha',  grup: 'Administrasi', fase: 10 },
  { kode: 'gaji',       nama: 'Gaji',            ikon: PhWallet,         warna: 'gaji',       ke: '/segera/gaji',       grup: 'Administrasi', fase: 11 },
  // Sistem
  { kode: 'auditlog',   nama: 'Audit Log',       ikon: PhClockCounterClockwise, warna: 'audit', ke: '/audit-log',     grup: 'Sistem' },
  { kode: 'organisasi', nama: 'Struktur Organisasi', ikon: PhTreeStructure, warna: 'sistem',  ke: '/organisasi',        grup: 'Sistem', peran: ['superadmin'] },
  { kode: 'hakakses',   nama: 'Hak Akses',       ikon: PhKey,            warna: 'hakakses',   ke: '/hak-akses',         grup: 'Sistem', peran: ['superadmin'] },
  { kode: 'pengaturan', nama: 'Pengaturan',      ikon: PhGearSix,        warna: 'pengaturan', ke: '/pengaturan',        grup: 'Sistem', peran: ['superadmin'] },
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

export const GRUP = ['Utama', 'Presensi', 'Layanan Pegawai', 'Kepegawaian', 'Santri', 'Layanan', 'Administrasi', 'Sistem']
/** Menu sesuai peran. ciri.shift = pegawai memegang pola shift (menu Jadwal Shift tampil juga untuk admin). */
/** ciri.izin = izin admin yang dimiliki; menu ber-"izin" hanya tampil bagi superadmin atau admin yang memiliki izin itu. */
/** ciri.fitur = hak fitur pegawai; menu ber-"fitur" tampil bagi admin/superadmin atau pegawai dengan tingkat ≥ 1. */
export const menuUntuk = (peran, ciri = {}) => MENU.filter((m) => (!m.peran || m.peran.includes(peran))
  && (!m.syarat || ADMIN.includes(peran) || (typeof m.syarat === 'function' ? m.syarat(ciri) : ciri[m.syarat]))
  && (!m.fitur || ADMIN.includes(peran) || Number(ciri.fitur?.[m.fitur] ?? 0) >= 1)
  && (!m.izin || peran === 'superadmin' || (ciri.izin || []).includes(m.izin)))
export const cariMenu = (kode) => MENU.find((m) => m.kode === kode)
