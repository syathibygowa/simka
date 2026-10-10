// SIMKA PRO | src/lib/menuCepat.js | v1.0 | Fase 8 – Tahap 0 Beranda pegawai fungsional | 10/10/2026
// Menu cepat beranda pegawai fungsional: tombol langsung ke menu kerja sesuai tupoksi masing-masing
// (musyrif → Musyrif, muhaffizh → Setoran Tahfizh, wali kelas → Absensi Kelas, medis → Klinik, security → Gerbang, dst.).
// Tupoksi didahulukan, lalu dilengkapi menu umum sampai 8 tombol (2 baris × 4 kolom).
import {
  PhBuildings, PhBookOpenText, PhCheckSquareOffset, PhMedal, PhChalkboardTeacher, PhCalendarDots, PhFirstAidKit, PhShieldCheck,
  PhGraduationCap, PhCalendarStar, PhSignOut, PhUsersThree, PhFileText, PhMegaphone, PhCalendarCheck, PhFolderOpen, PhClockCountdown, PhNotebook,
} from '@phosphor-icons/vue'

/** @param {object} t profil tugas (sesi.tugas), @param {object} c ciri tambahan: { shift } */
export function menuCepat(t = {}, c = {}) {
  const fungsi = new Set(t.fungsional || []); const kel = new Set(t.kelompok || [])
  const d = []
  const tambah = (x) => { if (!d.some((y) => y.ke === x.ke)) d.push(x) }
  // ---------- Sesuai tupoksi ----------
  if (fungsi.has('MEDIS') || (t.klinik || []).length) tambah({ kode: 'klinik', label: 'Klinik', ket: 'Antrean pasien', ikon: PhFirstAidKit, warna: 'klinik', ke: '/klinik/antrean' })
  if (fungsi.has('SECURITY') || t.gerbang) tambah({ kode: 'gerbang', label: 'Gerbang', ket: 'Catat keluar/masuk', ikon: PhShieldCheck, warna: 'security', ke: '/security/gerbang' })
  if (kel.has('kamar')) tambah({ kode: 'musyrif', label: 'Musyrif', ket: 'Kamar asuhan', ikon: PhBuildings, warna: 'musyrif', ke: '/musyrif' })
  if (kel.has('halaqah')) tambah({ kode: 'setoran', label: 'Setoran Tahfizh', ket: 'Halaqah asuhan', ikon: PhBookOpenText, warna: 'tahfizh', ke: '/tahfizh/setoran' })
  if (kel.has('kelas')) tambah({ kode: 'absensikelas', label: 'Absensi Kelas', ket: 'Kelas perwalian', ikon: PhCheckSquareOffset, warna: 'absensi', ke: '/absensi-santri/sesi' })
  if (kel.has('ekskul')) tambah({ kode: 'ekskul', label: 'Ekskul', ket: 'Ekskul binaan', ikon: PhMedal, warna: 'ekskul', ke: '/ekskul' })
  if (fungsi.has('GURU') || t.mengajar) {
    tambah({ kode: 'mengajar', label: 'Jurnal Mengajar', ket: 'Jam pelajaran Anda', ikon: PhChalkboardTeacher, warna: 'jadwal', ke: '/jurnal/mengajar' })
    tambah({ kode: 'jadwal', label: 'Jadwal Mengajar', ket: 'Jadwal Anda', ikon: PhCalendarDots, warna: 'kelompoksantri', ke: '/jadwal-pelajaran/guru' })
  }
  if (t.penguji) tambah({ kode: 'ujian', label: 'Ujian Tahfizh', ket: 'Daftar tunggu penguji', ikon: PhGraduationCap, warna: 'verifikasi', ke: '/tahfizh/ujian' })
  if (kel.has('kamar') || kel.has('kelas') || kel.has('halaqah')) {
    tambah({ kode: 'asuhan', label: 'Santri Asuhan', ket: 'Kelompok yang Anda ampu', ikon: PhUsersThree, warna: 'santri', ke: '/kelompok-santri' })
    tambah({ kode: 'izin', label: 'Izin Santri', ket: 'Usulan izin', ikon: PhSignOut, warna: 'pengajuan', ke: '/izin-santri/menunggu' })
  }
  if (c.shift) tambah({ kode: 'shift', label: 'Jadwal Shift', ket: 'Giliran tugas', ikon: PhCalendarStar, warna: 'shift', ke: '/jadwal-shift' })
  // ---------- Menu umum setiap pegawai ----------
  const umum = [
    { kode: 'pengajuan', label: 'Pengajuan', ket: 'Izin, sakit, cuti', ikon: PhFileText, warna: 'pengajuan', ke: '/pengajuan' },
    { kode: 'lapor', label: 'Lapor ke Bidang', ket: 'Sampaikan laporan', ikon: PhMegaphone, warna: 'laporan', ke: '/lapor' },
    { kode: 'jurnal', label: 'Jurnal Harian', ket: 'Ceklist tugas', ikon: PhNotebook, warna: 'tatausaha', ke: '/jurnal' },
    { kode: 'agenda', label: 'Agenda', ket: 'Kegiatan pondok', ikon: PhCalendarCheck, warna: 'agenda', ke: '/agenda' },
    { kode: 'berkas', label: 'Berkas Saya', ket: 'SK, formulir', ikon: PhFolderOpen, warna: 'berkas', ke: '/berkas' },
    { kode: 'beban', label: 'Beban Kerja', ket: 'Jam per pekan', ikon: PhClockCountdown, warna: 'gaji', ke: '/beban-kerja' },
  ]
  for (const u of umum) { if (d.length >= 8) break; tambah(u) }
  // Kelipatan 4 agar kisi rapi
  const n = d.length > 4 ? 8 : 4
  return d.slice(0, n)
}
