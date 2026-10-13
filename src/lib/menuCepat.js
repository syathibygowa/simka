// SIMKA PRO | src/lib/menuCepat.js | v1.6 | Perbaikan: Wali Kelas dan Guru Mapel di menu cepat; tombol tupoksi tidak terpotong | 14/10/2026
// Menu cepat beranda pegawai fungsional: tombol langsung ke menu kerja sesuai tupoksi masing-masing
// (musyrif → Musyrif, muhaffizh → Setoran Tahfizh, wali kelas → Absensi Kelas, medis → Klinik, security → Gerbang, dst.).
// Tupoksi didahulukan, lalu dilengkapi menu umum sampai 8 tombol (2 baris × 4 kolom).
import {
  PhBuildings, PhBookOpenText, PhCheckSquareOffset, PhMedal, PhChalkboardTeacher, PhCalendarDots, PhFirstAidKit, PhShieldCheck,
  PhGraduationCap, PhCalendarStar, PhSignOut, PhUsersThree, PhFileText, PhMegaphone, PhCalendarCheck, PhFolderOpen, PhClockCountdown, PhNotebook, PhEnvelopeSimple, PhWallet, PhCashRegister, PhChalkboard, PhPresentationChart,
} from '@phosphor-icons/vue'

/** @param {object} t profil tugas (sesi.tugas), @param {object} c ciri tambahan: { shift, persuratan, gaji } */
export function menuCepat(t = {}, c = {}) {
  const fungsi = new Set(t.fungsional || []); const kel = new Set(t.kelompok || [])
  const d = []
  const tambah = (x) => { if (!d.some((y) => y.ke === x.ke)) d.push(x) }
  // ---------- Sesuai tupoksi ----------
  if (fungsi.has('MEDIS') || (t.klinik || []).length) tambah({ kode: 'klinik', label: 'Klinik', ket: 'Antrean pasien', ikon: PhFirstAidKit, warna: 'klinik', ke: '/klinik/antrean' })
  if (fungsi.has('SECURITY') || t.gerbang) tambah({ kode: 'gerbang', label: 'Gerbang', ket: 'Catat keluar/masuk', ikon: PhShieldCheck, warna: 'security', ke: '/security/gerbang' })
  if (kel.has('kamar')) tambah({ kode: 'musyrif', label: 'Musyrif', ket: 'Kamar asuhan', ikon: PhBuildings, warna: 'musyrif', ke: '/musyrif' })
  if (kel.has('halaqah')) tambah({ kode: 'setoran', label: 'Setoran Tahfizh', ket: 'Halaqah asuhan', ikon: PhBookOpenText, warna: 'tahfizh', ke: '/tahfizh/setoran' })
  if (kel.has('kelas')) {
    tambah({ kode: 'absensikelas', label: 'Absensi Kelas', ket: 'Kelas perwalian', ikon: PhCheckSquareOffset, warna: 'absensi', ke: '/absensi-santri/sesi' })
    tambah({ kode: 'walikelas', label: 'Wali Kelas', ket: 'Santri, rapor, catatan', ikon: PhChalkboard, warna: 'walikelas', ke: '/wali-kelas' })
  }
  if (kel.has('ekskul')) tambah({ kode: 'ekskul', label: 'Ekskul', ket: 'Ekskul binaan', ikon: PhMedal, warna: 'ekskul', ke: '/ekskul' })
  if (fungsi.has('GURU') || t.mengajar) {
    tambah({ kode: 'mengajar', label: 'Jurnal Mengajar', ket: 'Jam pelajaran Anda', ikon: PhChalkboardTeacher, warna: 'jadwal', ke: '/jurnal/mengajar' })
    tambah({ kode: 'gurumapel', label: 'Guru Mapel', ket: 'Kelas, nilai, rekap', ikon: PhPresentationChart, warna: 'gurumapel', ke: '/guru-mapel' })
    tambah({ kode: 'jadwal', label: 'Jadwal Mengajar', ket: 'Jadwal Anda', ikon: PhCalendarDots, warna: 'kelompoksantri', ke: '/jadwal-pelajaran/guru' })
  }
  if (t.penguji) tambah({ kode: 'ujian', label: 'Ujian Tahfizh', ket: 'Daftar tunggu penguji', ikon: PhGraduationCap, warna: 'verifikasi', ke: '/tahfizh/ujian' })
  if (kel.has('kamar') || kel.has('kelas') || kel.has('halaqah')) {
    tambah({ kode: 'asuhan', label: 'Santri Asuhan', ket: 'Kelompok yang Anda ampu', ikon: PhUsersThree, warna: 'santri', ke: '/kelompok-santri' })
    tambah({ kode: 'izin', label: 'Izin Santri', ket: 'Usulan izin', ikon: PhSignOut, warna: 'pengajuan', ke: '/izin-santri/menunggu' })
  }
  if ((t.struktural || []).includes('TATA_USAHA') || c.persuratan) tambah({ kode: 'persuratan', label: 'Persuratan', ket: 'Surat dan disposisi', ikon: PhEnvelopeSimple, warna: 'tatausaha', ke: '/persuratan' })
  if (c.keuangan) tambah({ kode: 'keuangan', label: 'Keuangan', ket: 'Tagihan dan pembayaran santri', ikon: PhCashRegister, warna: 'keuangan', ke: '/keuangan' })
  if (c.gaji) tambah({ kode: 'gaji', label: 'Gaji', ket: c.gajiLihat ? 'Periode, slip, laporan' : 'Slip gaji Anda', ikon: PhWallet, warna: 'gaji', ke: '/gaji' })
  if (c.shift) tambah({ kode: 'shift', label: 'Jadwal Shift', ket: 'Giliran tugas', ikon: PhCalendarStar, warna: 'shift', ke: '/jadwal-shift' })
  // ---------- Menu umum setiap pegawai ----------
  const umum = [
    { kode: 'pengajuan', label: 'Pengajuan', ket: 'Izin, sakit, cuti', ikon: PhFileText, warna: 'pengajuan', ke: '/pengajuan' },
    { kode: 'lapor', label: 'Laporan', ket: 'Sampaikan laporan', ikon: PhMegaphone, warna: 'laporan', ke: '/lapor' },
    { kode: 'jurnal', label: 'Jurnal Harian', ket: 'Ceklist tugas', ikon: PhNotebook, warna: 'tatausaha', ke: '/jurnal' },
    { kode: 'agenda', label: 'Agenda', ket: 'Kegiatan pondok', ikon: PhCalendarCheck, warna: 'agenda', ke: '/agenda' },
    { kode: 'berkas', label: 'Berkas Saya', ket: 'SK, formulir', ikon: PhFolderOpen, warna: 'berkas', ke: '/berkas' },
    { kode: 'beban', label: 'Beban Kerja', ket: 'Jam per pekan', ikon: PhClockCountdown, warna: 'gaji', ke: '/beban-kerja' },
  ]
  // Tombol tupoksi tidak pernah dipotong; menu umum melengkapi sampai kelipatan 4 (sedikitnya 8 tombol)
  const target = Math.max(8, Math.ceil(d.length / 4) * 4)
  for (const u of umum) { if (d.length >= target) break; tambah(u) }
  return d.slice(0, Math.max(target, Math.floor(d.length / 4) * 4))
}
