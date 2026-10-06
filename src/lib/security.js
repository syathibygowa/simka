// SIMKA PRO | src/lib/security.js | v1.1 | Fase 7 – Tahap 2 Titipan, buku tamu, kunjungan | 06/10/2026
// Label baku Security (Blueprint Bagian 24): status gerbang santri, jenis catatan gerbang, titipan, tamu, kunjungan.
import { PhCheckCircle, PhXCircle, PhSignOut, PhSignIn, PhSiren, PhClock, PhHourglass, PhProhibit, PhPackage, PhHamburger, PhTShirt, PhMoney, PhDotsThreeCircle, PhArrowUUpLeft } from '@phosphor-icons/vue'

/** Status gerbang dari server: warna hijau (boleh keluar), biru (di luar), merah (tidak boleh keluar). */
export const STATUS_GERBANG = {
  boleh:          { n: 'Boleh keluar', ikon: PhCheckCircle, w: 'presensi', warna: 'hijau' },
  di_luar:        { n: 'Sedang di luar', ikon: PhSignOut, w: 'security', warna: 'biru' },
  terlambat:      { n: 'Terlambat kembali', ikon: PhSiren, w: 'klinik', warna: 'merah' },
  belum_waktunya: { n: 'Belum waktunya', ikon: PhClock, w: 'klinik', warna: 'merah' },
  kedaluwarsa:    { n: 'Izin kedaluwarsa', ikon: PhXCircle, w: 'klinik', warna: 'merah' },
  menunggu:       { n: 'Izin belum disetujui', ikon: PhHourglass, w: 'klinik', warna: 'merah' },
  tidak_ada:      { n: 'Tidak ada izin', ikon: PhProhibit, w: 'klinik', warna: 'merah' },
}
export const JENIS_LOG = {
  keluar:  { n: 'Keluar', ikon: PhSignOut, w: 'shift' },
  kembali: { n: 'Kembali', ikon: PhSignIn, w: 'presensi' },
  ditolak: { n: 'Ditolak', ikon: PhProhibit, w: 'klinik' },
}

/** Durasi menit → "1 jam 20 menit". */
export function durasi(menit) {
  const m = Math.max(0, Math.round(Number(menit) || 0))
  if (m < 60) return `${m} menit`
  if (m < 1440) return `${Math.floor(m / 60)} jam${m % 60 ? ' ' + (m % 60) + ' menit' : ''}`
  const j = Math.floor((m % 1440) / 60)
  return `${Math.floor(m / 1440)} hari${j ? ' ' + j + ' jam' : ''}`
}

/** Label santri di gerbang: "Nama – 8A" atau "Nama – Kamar Umar" sesuai pilihan akhiran. */
export const akhiranSantri = (s, akhiran) => (akhiran === 'kamar' ? s.kamar : s.kelas) || (akhiran === 'kamar' ? s.kelas : s.kamar) || ''

// ---------- Titipan ----------
export const JENIS_TITIPAN = {
  paket:   { n: 'Paket', ikon: PhPackage, w: 'security' },
  makanan: { n: 'Makanan', ikon: PhHamburger, w: 'pengajuan' },
  pakaian: { n: 'Pakaian', ikon: PhTShirt, w: 'tahfizh' },
  uang:    { n: 'Uang', ikon: PhMoney, w: 'gaji' },
  lainnya: { n: 'Lainnya', ikon: PhDotsThreeCircle, w: 'hakakses' },
}
export const STATUS_TITIPAN = {
  di_pos:       { n: 'Di pos', w: 'pengajuan', ikon: PhPackage },
  diambil:      { n: 'Sudah diambil', w: 'presensi', ikon: PhCheckCircle },
  dikembalikan: { n: 'Dikembalikan', w: 'rekap', ikon: PhArrowUUpLeft },
  batal:        { n: 'Dibatalkan', w: 'hakakses', ikon: PhProhibit },
}
export const PENGAMBIL = { santri: 'Santri sendiri', musyrif: 'Musyrif/pengasuh', wali: 'Orang tua/wali', pengirim: 'Pengirim', lainnya: 'Lainnya' }
export const rupiah = (n) => 'Rp' + Number(n || 0).toLocaleString('id-ID')
export const HARI_PENDEK = ['Ahad', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu']
