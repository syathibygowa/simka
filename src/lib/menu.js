// SIMKA PRO | src/lib/menu.js | v4.2 | 14.6.0: menu Kedisiplinan Santri (pelanggaran dan surat peringatan santri) | 18/10/2026
// Daftar menu SIMKA PRO, dikelompokkan: Utama, Presensi, Layanan Pegawai (milik setiap pegawai),
// Kepegawaian (pengelolaan data), Santri, Fungsional, Layanan, Administrasi, Sistem. Setiap menu memiliki ikon Phosphor (duotone) dan
// warna sendiri (kelas .w-* di token.css). "fase" menandai menu yang dibangun
// pada fase berikutnya; menu tersebut tampil dengan lencana fase.
import {
  PhHouse, PhFingerprint, PhUsersThree, PhStudent, PhBookOpenText, PhFileText, PhFirstAidKit,
  PhShieldCheck, PhChartBar, PhEnvelopeSimple, PhWallet, PhMegaphone, PhKey, PhGearSix, PhBell,
  PhFiles, PhUserCircle, PhSquaresFour, PhUserCheck, PhNotebook, PhIdentificationCard, PhTreeStructure, PhCoins, PhCashRegister, PhMapPinArea, PhCalendarStar, PhSealCheck, PhChartLineUp, PhClockCounterClockwise, PhFolderOpen, PhCalendarCheck, PhUsersFour, PhClockCountdown, PhChalkboardTeacher, PhCheckSquareOffset, PhMedal, PhCalendarDots, PhChartPieSlice, PhCalendarPlus, PhBuildings, PhSignOut, PhListMagnifyingGlass, PhChalkboard, PhPresentationChart, PhExam, PhTrophy, PhGavel,
} from '@phosphor-icons/vue'

// Aturan tampil setiap menu (v4.0, 14.0.0) — semuanya dapat diatur superadmin di Hak Akses:
//   fitur/min : kode fitur di Hak Akses dan tingkat minimal untuk membuka menu (bawaan 1 = Lihat)
//   izin      : izin admin yang juga membuka menu (izin efektif: dicentang superadmin atau didapat dari hak fitur)
//   admin     : admin selalu melihat menu ini (seperti sebelumnya)
//   otomatis  : akses karena TUGAS yang ditetapkan (wali kelas, musyrif, muhaffizh, pembina, guru, petugas, penerima surat)
//   kunci     : 'semua' = selalu tampil; 'superadmin' = khusus superadmin
//   sensitif  : gaji/tunjangan/keuangan, mengikuti tab Fitur sensitif (fungsi hak)
const kel = (c, ...j) => (c.jenisKelompok || []).some((x) => j.includes(x))
const t = (c, f) => Number(c.fitur?.[f] ?? 0)
export const MENU = [
  // Utama
  { kode: 'beranda',    nama: 'Beranda',         ikon: PhHouse,          warna: 'beranda',    ke: '/',                  grup: 'Utama', kunci: 'semua' },
  { kode: 'notifikasi', nama: 'Notifikasi',      ikon: PhBell,           warna: 'notifikasi', ke: '/notifikasi',        grup: 'Utama', kunci: 'semua' },
  { kode: 'pengumuman', nama: 'Pengumuman',      ikon: PhMegaphone,      warna: 'pengumuman', ke: '/pengumuman',        grup: 'Utama', fitur: 'pengumuman' },
  { kode: 'agenda',     nama: 'Agenda',          ikon: PhCalendarCheck,  warna: 'agenda',     ke: '/agenda',            grup: 'Utama', fitur: 'agenda' },
  // Presensi
  { kode: 'presensi',   nama: 'Presensi',        ikon: PhFingerprint,    warna: 'presensi',   ke: '/presensi',          grup: 'Presensi', fitur: 'presensi' },
  { kode: 'jadwalshift', nama: 'Jadwal Shift',   ikon: PhCalendarStar,   warna: 'shift',      ke: '/jadwal-shift',      grup: 'Presensi', fitur: 'atur_presensi', admin: true, otomatis: (c) => !!c.shift },
  { kode: 'vervalpresensi', nama: 'Verval Presensi', ikon: PhSealCheck,   warna: 'verval',     ke: '/verval-presensi',   grup: 'Presensi', fitur: 'verval_presensi', min: 2, izin: 'verval_presensi' },
  { kode: 'datapresensi', nama: 'Data Presensi', ikon: PhListMagnifyingGlass, warna: 'datapresensi', ke: '/data-presensi', grup: 'Presensi', fitur: 'verval_presensi', izin: 'verval_presensi' },
  { kode: 'aturpresensi', nama: 'Penjadwalan', ikon: PhMapPinArea, warna: 'aturpresensi', ke: '/atur-presensi', grup: 'Presensi', fitur: 'atur_presensi', izin: 'atur_presensi' },
  // Layanan pegawai (milik setiap pegawai)
  { kode: 'pengajuan',  nama: 'Pengajuan',       ikon: PhFileText,       warna: 'pengajuan',  ke: '/pengajuan',         grup: 'Layanan Pegawai', fitur: 'pengajuan' },
  { kode: 'jurnal',     nama: 'Jurnal Harian',   ikon: PhNotebook,       warna: 'tatausaha',  ke: '/jurnal',            grup: 'Layanan Pegawai', fitur: 'jurnal_harian' },
  { kode: 'berkas',     nama: 'Berkas Saya',     ikon: PhFolderOpen,     warna: 'berkas',     ke: '/berkas',            grup: 'Layanan Pegawai', fitur: 'berkas_pegawai' },
  // Kepegawaian (pengelolaan data pegawai)
  { kode: 'pegawai',    nama: 'Data Pegawai',    ikon: PhUsersThree,     warna: 'pegawai',    ke: '/pegawai',           grup: 'Kepegawaian', fitur: 'data_pegawai', admin: true },
  { kode: 'verifikasi', nama: 'Verifikasi Akun', ikon: PhUserCheck,      warna: 'verifikasi', ke: '/verifikasi',        grup: 'Kepegawaian', fitur: 'verifikasi_akun', izin: 'verval_akun' },
  // Santri
  { kode: 'santri',     nama: 'Data Santri',     ikon: PhStudent,        warna: 'santri',     ke: '/santri',            grup: 'Santri', fitur: 'data_santri', admin: true },
  { kode: 'kelompoksantri', nama: 'Kelompok Santri', ikon: PhChalkboardTeacher, warna: 'kelompoksantri', ke: '/kelompok-santri', grup: 'Santri', fitur: 'kelompok_santri', admin: true,
    otomatis: (c) => c.kelompok || t(c, 'data_santri') >= 1 },
  { kode: 'absensisantri', nama: 'Absensi Santri', ikon: PhCheckSquareOffset, warna: 'absensi', ke: '/absensi-santri', grup: 'Santri', fitur: 'absensi_kelas', admin: true,
    otomatis: (c) => c.kelompok },
  { kode: 'statistiksantri', nama: 'Statistik Santri', ikon: PhChartPieSlice, warna: 'rekap', ke: '/statistik-santri', grup: 'Santri', fitur: 'statistik_santri', admin: true },
  { kode: 'tahunajaran', nama: 'Naik Kelas', ikon: PhCalendarPlus, warna: 'agenda', ke: '/tahun-ajaran-baru', grup: 'Santri', fitur: 'kelompok_santri', min: 3,
    otomatis: (c) => c.peran === 'admin' && (c.izin || []).includes('kelompok_santri') },
  // Portal Wali: pengaturan butir informasi, kesiapan data, sesi wali, percobaan gagal, pengumuman wali
  { kode: 'portalwali', nama: 'Portal Wali', ikon: PhUsersFour, warna: 'portalwali', ke: '/portal-wali', grup: 'Santri', fitur: 'portal_wali',
    otomatis: (c) => c.peran === 'admin' && (c.izin || []).includes('kelola_santri') },
  { kode: 'jadwalpelajaran', nama: 'Jadwal Pelajaran', ikon: PhCalendarDots, warna: 'jadwal', ke: '/jadwal-pelajaran', grup: 'Santri', fitur: 'jadwal_mengajar', admin: true,
    otomatis: (c) => c.kelompok },
  // Wali Kelas: wali kelas yang ditetapkan pada kelas, pemegang hak Absensi Kelas atau cakupan luas Jadwal mengajar, admin
  { kode: 'walikelas', nama: 'Wali Kelas', ikon: PhChalkboard, warna: 'walikelas', ke: '/wali-kelas', grup: 'Fungsional', fitur: 'absensi_kelas', admin: true,
    otomatis: (c) => kel(c, 'kelas') || !!c.luas?.jadwal_mengajar },
  // Guru Mapel: guru yang memiliki penugasan mengajar, pimpinan bidang (pantau jenjangnya), pemegang Jadwal mengajar tingkat Kelola, admin
  { kode: 'gurumapel', nama: 'Guru Mapel', ikon: PhPresentationChart, warna: 'gurumapel', ke: '/guru-mapel', grup: 'Fungsional', fitur: 'jadwal_mengajar', min: 3, admin: true,
    otomatis: (c) => !!c.mengajar || !!c.pimpinan || !!c.luas?.jadwal_mengajar },
  { kode: 'musyrif', nama: 'Musyrif', ikon: PhBuildings, warna: 'musyrif', ke: '/musyrif', grup: 'Fungsional', fitur: 'absensi_asrama', admin: true,
    otomatis: (c) => kel(c, 'kamar') },
  { kode: 'ekskul', nama: 'Ekskul', ikon: PhMedal, warna: 'ekskul', ke: '/ekskul', grup: 'Fungsional', fitur: 'absensi_ekskul', admin: true,
    otomatis: (c) => kel(c, 'ekskul') },
  { kode: 'tahfizh',    nama: 'Tahfizh',         ikon: PhBookOpenText,   warna: 'tahfizh',    ke: '/tahfizh',           grup: 'Fungsional', fitur: 'tahfizh', admin: true,
    otomatis: (c) => kel(c, 'halaqah') || t(c, 'data_santri') >= 1 || !!c.pengujiUtas || !!c.penguji },
  { kode: 'prestasi',   nama: 'Prestasi Santri', ikon: PhTrophy,         warna: 'prestasi',   ke: '/prestasi-santri',   grup: 'Santri', fitur: 'prestasi', admin: true,
    otomatis: (c) => c.kelompok },
  // Kedisiplinan santri (14.6.0): pengasuh santri, petugas Security, Bidang Kesantrian/pimpinan, Tata Usaha, pemegang fitur
  { kode: 'disiplin',   nama: 'Kedisiplinan Santri', ikon: PhGavel,     warna: 'disiplin',   ke: '/disiplin-santri',   grup: 'Santri', fitur: 'disiplin_santri', admin: true, izin: 'kelola_disiplin',
    otomatis: (c) => c.kelompok || !!c.pimpinan || t(c, 'tata_usaha') >= 2 || t(c, 'gerbang') >= 2 },
  // Penilaian: pengaturan, rekap, dan permintaan ubah nilai. Pengisian nilai tetap di menu kerja penilai.
  { kode: 'penilaian',  nama: 'Penilaian',       ikon: PhExam,           warna: 'penilaian',  ke: '/penilaian',         grup: 'Santri', fitur: 'nilai', min: 3, otomatis: (c) => !!c.penilaian },
  { kode: 'klinik',     nama: 'Klinik',          ikon: PhFirstAidKit,    warna: 'klinik',     ke: '/klinik',            grup: 'Fungsional', fitur: 'klinik', admin: true,
    otomatis: (c) => c.kelompok || t(c, 'data_santri') >= 1 },
  { kode: 'izinsantri', nama: 'Perizinan', ikon: PhSignOut, warna: 'pengajuan', ke: '/izin-santri', grup: 'Layanan', fitur: 'perizinan_santri', admin: true, izin: 'kelola_izin_santri',
    otomatis: (c) => c.kelompok || t(c, 'data_santri') >= 1 },
  { kode: 'libursantri', nama: 'Libur Santri', ikon: PhCalendarCheck, warna: 'libursantri', ke: '/libur-santri', grup: 'Layanan', fitur: 'perizinan_santri', admin: true, izin: 'kelola_izin_santri',
    otomatis: (c) => c.kelompok || t(c, 'data_santri') >= 1 },
  { kode: 'lapor', nama: 'Laporan', ikon: PhMegaphone, warna: 'laporan', ke: '/lapor', grup: 'Layanan', fitur: 'lapor_bidang', izin: 'kelola_lapor' },
  { kode: 'security',   nama: 'Security',        ikon: PhShieldCheck,    warna: 'security',   ke: '/security',          grup: 'Fungsional', fitur: 'gerbang', admin: true, izin: 'kelola_security',
    otomatis: (c) => t(c, 'pantauan') >= 1 || kel(c, 'kamar', 'kelas', 'halaqah') },
  // Dokumen: rekap presensi, laporan kehadiran, dan dokumen resmi dalam satu menu bertab (hemat menu)
  { kode: 'rekap',      nama: 'Dokumen',         ikon: PhFiles,    warna: 'rekap',      ke: '/rekap',             grup: 'Administrasi', fitur: 'laporan' },
  // Persuratan: Tata Usaha/pengelola, pimpinan penerima surat, dan pegawai yang pernah menerima disposisi
  { kode: 'persuratan', nama: 'Persuratan',      ikon: PhEnvelopeSimple, warna: 'tatausaha',  ke: '/persuratan',        grup: 'Administrasi', fitur: 'tata_usaha', admin: true, izin: 'kelola_persuratan',
    otomatis: (c) => !!c.persuratan || t(c, 'surat_teguran') >= 1 || (c.izin || []).includes('kelola_teguran') },
  // Gaji: pengelola/pembaca gaji (superadmin dan yang ditunjuk superadmin) dan pegawai bila slip ditampilkan di akun pegawai
  { kode: 'gaji',       nama: 'Gaji',            ikon: PhWallet,         warna: 'gaji',       ke: '/gaji',              grup: 'Administrasi', sensitif: true, otomatis: (c) => !!c.gaji },
  { kode: 'bebankerja', nama: 'Beban Kerja',     ikon: PhClockCountdown, warna: 'gaji',       ke: '/beban-kerja',       grup: 'Administrasi', fitur: 'beban_kerja', izin: 'atur_beban_kerja',
    otomatis: (c) => !!(c.beban?.saya || c.beban?.rekap || c.beban?.atur) },
  // Tunjangan: tarif, peta tunjangan, rekening, pengingat kenaikan (pengelola dan pembaca gaji)
  { kode: 'tunjangan',  nama: 'Tunjangan',       ikon: PhCoins,          warna: 'tahfizh',    ke: '/tunjangan',         grup: 'Administrasi', sensitif: true, otomatis: (c) => !!c.gajiLihat },
  // Keuangan santri: hanya superadmin dan pegawai yang ditunjuk superadmin (mis. Bendahara Pondok)
  { kode: 'keuangan',   nama: 'Keuangan',        ikon: PhCashRegister,   warna: 'keuangan',   ke: '/keuangan',          grup: 'Administrasi', sensitif: true, otomatis: (c) => !!c.keuangan },
  // Sistem
  { kode: 'auditlog',   nama: 'Audit Log',       ikon: PhClockCounterClockwise, warna: 'audit', ke: '/audit-log',     grup: 'Sistem', fitur: 'audit_log' },
  { kode: 'organisasi', nama: 'Organisasi', ikon: PhTreeStructure, warna: 'sistem',  ke: '/organisasi',        grup: 'Sistem', fitur: 'organisasi' },
  { kode: 'hakakses',   nama: 'Hak Akses',       ikon: PhKey,            warna: 'hakakses',   ke: '/hak-akses',         grup: 'Sistem', kunci: 'superadmin' },
  { kode: 'pengaturan', nama: 'Setelan',         ikon: PhGearSix,        warna: 'pengaturan', ke: '/pengaturan',        grup: 'Sistem', kunci: 'superadmin' },
  { kode: 'profil',     nama: 'Profil',          ikon: PhUserCircle,     warna: 'profil',     ke: '/profil',            grup: 'Akun', kunci: 'semua' },
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
/** Apakah menu m terbuka bagi peran dan ciri pengguna (ciri dari stores/sesi.js → ciriMenu). */
export function menuTerlihat(m, peran, c = {}) {
  if (!m) return false
  if (m.kunci === 'semua' || peran === 'superadmin') return true
  if (m.kunci === 'superadmin') return false
  if (m.sensitif) return !!m.otomatis?.(c)
  if (m.admin && peran === 'admin') return true
  if (m.izin && (c.izin || []).includes(m.izin)) return true
  if (m.fitur && t(c, m.fitur) >= (m.min || 1)) return true
  return !!m.otomatis?.({ ...c, peran })
}
/** Menu yang terbuka bagi pengguna. Keamanan tetap diperiksa server; ini hanya menyaring tampilan. */
export const menuUntuk = (peran, ciri = {}) => MENU.filter((m) => menuTerlihat(m, peran, ciri))
export const cariMenu = (kode) => MENU.find((m) => m.kode === kode)
