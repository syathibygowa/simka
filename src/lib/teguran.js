// SIMKA PRO | src/lib/teguran.js | v1.0 | 14.1.0: Surat Teguran SP1–SP3 (nama tingkat, keadaan, teks ringkasan kehadiran) | 17/10/2026
// Konstanta dan pembantu Surat Teguran. Keadaan dihitung server: diusulkan (diproses TU), aktif (terbit dan masih berlaku),
// berakhir (masa berlaku lewat), batal (usulan dibatalkan), dicabut (dicabut pimpinan atau suratnya dicabut).
import { formatPanjang } from './tanggal'

export const TINGKAT_SP = {
  1: { singkat: 'SP-1', nama: 'Surat Teguran Pertama', w: 'tahfizh' },
  2: { singkat: 'SP-2', nama: 'Surat Teguran Kedua', w: 'pengajuan' },
  3: { singkat: 'SP-3', nama: 'Surat Teguran Ketiga', w: 'klinik' },
}
export const KEADAAN_SP = {
  diusulkan: { n: 'Diproses Tata Usaha', w: 'shift' },
  aktif: { n: 'Aktif', w: 'klinik' },
  berakhir: { n: 'Berakhir', w: 'presensi' },
  batal: { n: 'Dibatalkan', w: 'sistem' },
  dicabut: { n: 'Dicabut', w: 'hakakses' },
}
export const STATUS_SURAT_SP = { draf: 'Draf', diperiksa: 'Diperiksa Tata Usaha', menunggu_ttd: 'Menunggu tanda tangan', terbit: 'Terbit', ditolak: 'Ditolak penanda tangan', dibatalkan: 'Dibatalkan', dicabut: 'Dicabut', direvisi: 'Direvisi' }

/** Ringkasan kehadiran (dari ringkasan_presensi_teguran) dalam satu kalimat, sama dengan yang ditulis server ke surat. */
export function teksPresensi(r) {
  if (!r) return ''
  const b = [`${r.sesi} sesi wajib, hadir ${r.hadir} sesi`]
  if (r.terlambat > 0) b.push(`terlambat ${r.terlambat} kali (${r.menit_terlambat} menit)`)
  if (r.tanpa_keterangan > 0) b.push(`tanpa keterangan ${r.tanpa_keterangan} sesi`)
  if (r.izin_sakit_cuti > 0) b.push(`izin/sakit/cuti ${r.izin_sakit_cuti} sesi`)
  if (r.pulang_cepat > 0) b.push(`pulang sebelum waktunya ${r.pulang_cepat} kali`)
  if (r.tidak_presensi_pulang > 0) b.push(`tidak presensi pulang ${r.tidak_presensi_pulang} kali`)
  return `Rekap kehadiran ${formatPanjang(r.mulai)} sampai dengan ${formatPanjang(r.selesai)}: ${b.join(', ')}.`
}

/** Sisa hari masa berlaku SP aktif. */
export function sisaHari(sampai, hariIni) {
  if (!sampai || !hariIni) return null
  return Math.round((new Date(sampai + 'T00:00:00') - new Date(hariIni + 'T00:00:00')) / 86400000)
}
