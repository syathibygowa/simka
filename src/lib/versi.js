// SIMKA PRO | src/lib/versi.js | v8.1.0 | Fase 8 – Tahap 1 Registri dokumen dan Cek Keabsahan; kontrol pimpinan | 10/10/2026
// Nomor versi aplikasi yang tampil di halaman Profil. Naikkan setiap kali kode diunggah ke GitHub.
// Keterangan versi tampil kepada pengguna, jadi ditulis tanpa kata "Fase".
export const VERSI_APLIKASI = '8.1.0'
export const KETERANGAN_VERSI = 'Cek Keabsahan Dokumen dan registri dokumen resmi'

// Waktu kode dibangun oleh GitHub Actions; dipakai untuk memastikan versi yang tayang adalah yang terbaru.
/* global __WAKTU_BUILD__ */
export const WAKTU_BUILD = typeof __WAKTU_BUILD__ !== 'undefined' ? __WAKTU_BUILD__ : ''
