// SIMKA PRO | src/lib/logo.js | v1.0 | Perbaikan 13.6.0: daftar logo terpusat (Setelan → Logo) | 15/10/2026
// Semua logo lembaga dikelola di satu tempat: Setelan → Logo (disimpan di pengaturan identitas, kunci logo_daftar).
// Bagian lain (kop surat, dokumen tahfizh, sampul rapor) menyimpan RUJUKAN "logo:<kode>" sehingga mengganti gambar
// di Setelan → Logo langsung berlaku di semua dokumen. Tautan gambar biasa (https://…) tetap didukung.
import { alamatAset } from './penyimpanan'

/** Logo bawaan (selalu ada di daftar; gambar boleh kosong). sumber = kolom identitas lama yang ikut disinkronkan. */
export const LOGO_BAWAAN = [
  { k: 'pondok', n: 'Logo pondok', sumber: 'logo_url' },
  { k: 'yayasan', n: 'Logo yayasan' },
  { k: 'wustha', n: 'Logo Wustha' },
  { k: 'sma', n: 'Logo SMA' },
  { k: 'kemenag', n: 'Logo Kementerian Agama', sumber: 'logo_kemenag_url' },
  { k: 'diknas', n: 'Logo Kemendikdasmen (Diknas)' },
]
export const AWALAN = 'logo:'
export const rujukan = (k) => (k ? AWALAN + k : '')
export const kodeRujukan = (v) => (typeof v === 'string' && v.startsWith(AWALAN) ? v.slice(AWALAN.length) : '')

/** Daftar logo lengkap: bawaan (diisi dari logo_daftar atau kolom lama) + logo tambahan. [{ k, n, url, bawaan }] */
export function daftarLogo(identitas = {}) {
  const simpan = Array.isArray(identitas.logo_daftar) ? identitas.logo_daftar : []
  const cari = (k) => simpan.find((x) => x.k === k)
  const bawaan = LOGO_BAWAAN.map((b) => ({ k: b.k, n: cari(b.k)?.n || b.n, url: cari(b.k)?.url || (b.sumber ? identitas[b.sumber] : '') || '', bawaan: true }))
  const tambahan = simpan.filter((x) => !LOGO_BAWAAN.some((b) => b.k === x.k)).map((x) => ({ k: x.k, n: x.n, url: x.url || '', bawaan: false }))
  return [...bawaan, ...tambahan]
}

/** Alamat gambar dari nilai tersimpan: "logo:<kode>" → gambar di daftar logo; tautan biasa → tautan itu. */
export function urlLogo(nilai, identitas = {}) {
  if (!nilai) return ''
  const k = kodeRujukan(nilai)
  if (k) return alamatAset(daftarLogo(identitas).find((x) => x.k === k)?.url || '')
  return alamatAset(nilai)
}
/** Nama logo dari nilai tersimpan (untuk keterangan di layar). */
export function namaLogo(nilai, identitas = {}) {
  const k = kodeRujukan(nilai)
  if (k) return daftarLogo(identitas).find((x) => x.k === k)?.n || 'Logo tidak ditemukan'
  return nilai ? 'Tautan gambar' : 'Tanpa logo'
}
