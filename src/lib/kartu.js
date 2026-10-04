// SIMKA PRO | src/lib/kartu.js | v1.0 | Fase 3 – Tahap 4 Berkas Saya dan kartu pegawai | 04/10/2026
// Kode QR verifikasi kartu pegawai (SVG, tanpa layanan luar) dan alamat halaman verifikasi.
import qrcode from 'qrcode-generator'

/** Alamat halaman verifikasi publik untuk kode kartu (mengikuti alamat aplikasi saat ini). */
export function alamatVerifikasi(kode) {
  const dasar = `${location.origin}${location.pathname}`.replace(/index\.html$/, '')
  return `${dasar}#/cek-kartu/${kode}`
}
/** SVG kode QR (koreksi galat M) untuk teks. */
export function svgQR(teks) {
  const q = qrcode(0, 'M'); q.addData(teks); q.make()
  return q.createSvgTag({ cellSize: 4, margin: 0, scalable: true })
}
/** Kode dibaca manusia: ABCD-EFGH-JK */
export const kodeRapi = (k) => (k ? k.replace(/(.{4})(.{4})(.*)/, '$1-$2-$3') : '')
