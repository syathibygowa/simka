// SIMKA PRO | src/lib/kartu.js | v1.1 | 14.21.0: alamat verifikasi kartu memakai alamat resmi aplikasi | 24/10/2026
// Kode QR verifikasi kartu pegawai (SVG, tanpa layanan luar) dan alamat halaman verifikasi.
import qrcode from 'qrcode-generator'
import { alamatAplikasi } from './alamat'

/** Alamat halaman verifikasi publik untuk kode kartu (mengikuti alamat aplikasi saat ini). */
export function alamatVerifikasi(kode) {
  return `${alamatAplikasi()}#/cek-kartu/${kode}`
}
/** SVG kode QR (koreksi galat M) untuk teks. */
export function svgQR(teks) {
  const q = qrcode(0, 'M'); q.addData(teks); q.make()
  return q.createSvgTag({ cellSize: 4, margin: 0, scalable: true })
}
/** Kode dibaca manusia: ABCD-EFGH-JK */
export const kodeRapi = (k) => (k ? k.replace(/(.{4})(.{4})(.*)/, '$1-$2-$3') : '')
