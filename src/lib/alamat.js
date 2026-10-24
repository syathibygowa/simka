// SIMKA PRO | src/lib/alamat.js | v1.0 | 14.21.0: alamat resmi aplikasi untuk QR, catatan pengesahan, dan tautan WA | 24/10/2026
// Alamat dasar aplikasi yang dicetak di dokumen (catatan pengesahan, QR Cek Keabsahan, kartu) dan dikirim lewat WA.
// Urutan: Setelan → Integrasi → Alamat aplikasi (bila terbaca) › VITE_DOMAIN_APLIKASI › simka.digital bila aplikasi dibuka
// dari alamat GitHub Pages (*.github.io, mis. aplikasi lama yang terpasang di HP) › alamat yang sedang dibuka.
const RESMI = (import.meta.env.VITE_DOMAIN_APLIKASI || 'https://simka.digital/').replace(/\/?$/, '/')
let setelan = ''

/** Dipanggil saat pengaturan integrasi dimuat (hanya terbaca oleh superadmin). */
export function aturDomainAplikasi(url) {
  const u = String(url || '').trim()
  setelan = /^https?:\/\/[^\s]+$/i.test(u) ? u.replace(/#.*$/, '').replace(/index\.html$/, '').replace(/\/?$/, '/') : ''
}

/** Alamat dasar aplikasi, diakhiri garis miring, mis. https://simka.digital/ */
export function alamatAplikasi() {
  if (setelan) return setelan
  if (typeof location === 'undefined') return RESMI
  if (/\.github\.io$/i.test(location.hostname)) return RESMI
  if (location.protocol === 'file:') return RESMI
  return `${location.origin}${location.pathname}`.replace(/index\.html$/, '')
}
