// SIMKA PRO | src/lib/gaji.js | v1.0 | Fase 11 – Tahap 2 Periode gaji: label komponen, status, terbilang | 11/10/2026
// Label, warna, dan pembantu bersama modul Gaji (periode, slip, laporan).
import { BULAN } from './tanggal'

export const namaPeriode = (p) => (p ? `${BULAN[p.bulan - 1]} ${p.tahun}` : '')

export const STATUS_PERIODE = {
  draf: { n: 'Draf', w: 'tahfizh', ket: 'Masih dapat diubah' },
  diajukan: { n: 'Diajukan', w: 'verifikasi', ket: 'Menunggu tanda tangan' },
  terbit: { n: 'Terbit', w: 'presensi', ket: 'Slip terkunci' },
  batal: { n: 'Batal', w: 'hakakses', ket: 'Tidak dipakai' },
}

/** Kategori komponen gaji: label pendek, warna (.w-*), dan pengelompokan kolom daftar gaji. */
export const KATEGORI_ITEM = {
  struktural: { n: 'Jabatan struktural', w: 'pengaturan', kol: 'struktural' },
  fungsional: { n: 'Jabatan fungsional', w: 'presensi', kol: 'fungsional' },
  pendidikan: { n: 'Pendidikan', w: 'pengajuan', kol: 'pendidikan' },
  masa_kerja: { n: 'Masa kerja', w: 'tahfizh', kol: 'masa_kerja' },
  kepegawaian: { n: 'Kepegawaian', w: 'pegawai', kol: 'kepegawaian' },
  kesehatan: { n: 'Kesehatan', w: 'klinik', kol: 'kepegawaian' },
  level_muhaffizh: { n: 'Level muhaffizh', w: 'santri', kol: 'lain' },
  honor: { n: 'Honor per jam', w: 'laporan', kol: 'honor' },
  tambahan: { n: 'Pendapatan lain', w: 'agenda', kol: 'lain' },
  penyesuaian: { n: 'Penyesuaian', w: 'verifikasi', kol: 'penyesuaian' },
  potongan_kehadiran: { n: 'Potongan kehadiran', w: 'klinik', kol: 'potongan' },
  pinjaman: { n: 'Cicilan pinjaman', w: 'shift', kol: 'potongan' },
  simpanan: { n: 'Simpanan program', w: 'berkas', kol: 'potongan' },
  potongan_lain: { n: 'Potongan lain', w: 'hakakses', kol: 'potongan' },
}
export const SUMBER_ITEM = {
  skema: { n: 'Skema', w: 'presensi' }, penetapan: { n: 'Ketetapan yayasan', w: 'verifikasi' },
  manual: { n: 'Diubah', w: 'pengajuan' }, impor: { n: 'Impor', w: 'shift' },
}
/** Kolom daftar gaji (cetak/Excel), berurutan. */
export const KOLOM_DAFTAR = [
  ['struktural', 'Tunj. struktural'], ['fungsional', 'Tunj. fungsional'], ['pendidikan', 'Tunj. pendidikan'], ['masa_kerja', 'Tunj. masa kerja'],
  ['kepegawaian', 'Tunj. kepeg. & kesehatan'], ['honor', 'Honor per jam'], ['lain', 'Lain-lain'], ['penyesuaian', 'Penyesuaian'],
]
export function perKolom(item = []) {
  const k = {}
  for (const i of item) { const kol = KATEGORI_ITEM[i.kategori]?.kol || (i.jenis === 'potongan' ? 'potongan' : 'lain'); k[kol] = (k[kol] || 0) + Number(i.besaran || 0) }
  return k
}

export const rupiah = (n) => (Number(n) < 0 ? '−' : '') + 'Rp' + Math.abs(Math.round(Number(n) || 0)).toLocaleString('id-ID')
export const angka = (n) => (Number(n) < 0 ? '−' : '') + Math.abs(Math.round(Number(n) || 0)).toLocaleString('id-ID')
/** Ubah teks rupiah ("Rp1.250.000", "1250000", "-50.000") menjadi angka; kosong = null. */
export function bacaRupiah(v) {
  const t = String(v ?? '').trim(); if (!t) return null
  const neg = /^[-−]/.test(t); const n = Number(t.replace(/[^0-9]/g, ''))
  return isNaN(n) ? null : neg ? -n : n
}

const SATUAN = ['', 'satu', 'dua', 'tiga', 'empat', 'lima', 'enam', 'tujuh', 'delapan', 'sembilan', 'sepuluh', 'sebelas']
function eja(n) {
  if (n < 12) return SATUAN[n]
  if (n < 20) return eja(n - 10) + ' belas'
  if (n < 100) return eja(Math.floor(n / 10)) + ' puluh' + (n % 10 ? ' ' + eja(n % 10) : '')
  if (n < 200) return 'seratus' + (n - 100 ? ' ' + eja(n - 100) : '')
  if (n < 1000) return eja(Math.floor(n / 100)) + ' ratus' + (n % 100 ? ' ' + eja(n % 100) : '')
  if (n < 2000) return 'seribu' + (n - 1000 ? ' ' + eja(n - 1000) : '')
  if (n < 1e6) return eja(Math.floor(n / 1000)) + ' ribu' + (n % 1000 ? ' ' + eja(n % 1000) : '')
  if (n < 1e9) return eja(Math.floor(n / 1e6)) + ' juta' + (n % 1e6 ? ' ' + eja(n % 1e6) : '')
  return eja(Math.floor(n / 1e9)) + ' miliar' + (n % 1e9 ? ' ' + eja(n % 1e9) : '')
}
/** Terbilang rupiah, contoh 3.250.000 → "Tiga juta dua ratus lima puluh ribu rupiah". */
export function terbilang(n) {
  n = Math.round(Number(n) || 0)
  if (n === 0) return 'Nol rupiah'
  const t = (n < 0 ? 'minus ' : '') + eja(Math.abs(n)) + ' rupiah'
  return t.charAt(0).toUpperCase() + t.slice(1)
}
