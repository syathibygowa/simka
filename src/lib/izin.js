// SIMKA PRO | src/lib/izin.js | v1.1 | Fase 7 – Tahap 3 Libur santri | 06/10/2026
// Label baku perizinan santri (Blueprint Bagian 22–23): status, peran pengusul, unit pemutus, teks WA, hasil libur.
import { PhHourglass, PhCheckCircle, PhXCircle, PhSignOut, PhSignIn, PhProhibit, PhSealCheck } from '@phosphor-icons/vue'
import { formatWaktu } from './tanggal'

export const STATUS_IZIN = {
  diajukan:          { n: 'Menunggu kepala bidang', p: 'Diajukan', w: 'pengajuan', ikon: PhHourglass },
  disetujui_bidang:  { n: 'Menunggu Direktur/Wadir', p: 'Menunggu pimpinan', w: 'agenda', ikon: PhSealCheck },
  disetujui:         { n: 'Disetujui, belum keluar', p: 'Disetujui', w: 'presensi', ikon: PhCheckCircle },
  keluar:            { n: 'Sedang di luar pondok', p: 'Keluar', w: 'shift', ikon: PhSignOut },
  kembali:           { n: 'Sudah kembali', p: 'Kembali', w: 'rekap', ikon: PhSignIn },
  ditolak:           { n: 'Ditolak', p: 'Ditolak', w: 'klinik', ikon: PhXCircle },
  dibatalkan:        { n: 'Dibatalkan', p: 'Dibatalkan', w: 'hakakses', ikon: PhProhibit },
}
export const PERAN_PENGUSUL = { musyrif: 'Musyrif', wali_kelas: 'Wali kelas', muhaffizh: 'Muhaffizh', petugas_klinik: 'Petugas klinik', admin: 'Admin' }
export const UNIT_IZIN = { KESANTRIAN: 'Kepala Bidang Kesantrian', TAHFIZH: 'Kepala Bidang Tahfizh', WUSTHA: 'Kepala Kesetaraan Wustha', SMA: 'Kepala SMA' }
export const JENIS_IZIN = { pulang: 'Pulang (menginap)', keluar: 'Keluar beberapa jam', libur: 'Libur pondok' }

// ---------- Libur santri (Bagian 23) ----------
export const HASIL_LIBUR = {
  boleh:        { n: 'Boleh libur', w: 'presensi', ikon: PhCheckCircle },
  tidak:        { n: 'Tidak libur', w: 'klinik', ikon: PhXCircle },
  pertimbangan: { n: 'Perlu pertimbangan', w: 'pengajuan', ikon: PhHourglass },
}
export const STATUS_PERIODE = {
  draf:     { n: 'Draf', w: 'hakakses' },
  dinilai:  { n: 'Sudah dinilai', w: 'pengajuan' },
  disahkan: { n: 'Disahkan', w: 'presensi' },
  batal:    { n: 'Dibatalkan', w: 'klinik' },
}
export const JENIS_PERIODE = { bulanan: 'Libur bulanan', semester: 'Libur semester', khusus: 'Libur khusus' }
export const SYARAT_LIBUR = [
  { k: 'kelas_min', n: 'Kehadiran kelas minimal', s: '%' }, { k: 'halaqah_min', n: 'Kehadiran halaqah minimal', s: '%' },
  { k: 'asrama_min', n: 'Kehadiran asrama minimal', s: '%' }, { k: 'izin_maks', n: 'Izin keluar maksimal', s: 'kali' },
  { k: 'terlambat_maks', n: 'Terlambat kembali maksimal', s: 'kali' }, { k: 'hafalan_min_halaman', n: 'Tambahan hafalan minimal', s: 'halaman' },
  { k: 'margin', n: 'Rentang "perlu pertimbangan" di bawah ambang', s: '%' },
]

/** Label status untuk kartu, termasuk "Terlambat kembali". */
export function labelIzin(x) {
  if (x.terlambat && x.status === 'keluar') return { n: 'Terlambat kembali', w: 'klinik' }
  return { n: STATUS_IZIN[x.status]?.n || x.status, w: STATUS_IZIN[x.status]?.w || 'hakakses' }
}
export const rentangIzin = (x) => `${formatWaktu(x.keluar_pada)} s.d. ${formatWaktu(x.kembali_batas)}`
