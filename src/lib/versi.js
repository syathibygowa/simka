// SIMKA PRO | src/lib/versi.js | v13.7.2 | Perbaikan 13.7.2: ikon aplikasi baru (logo pondok + SIMKA) | 16/10/2026
// Nomor versi aplikasi yang tampil di halaman Profil. Naikkan setiap kali kode diunggah ke GitHub.
// Keterangan versi tampil kepada pengguna, jadi ditulis tanpa kata "Fase".
export const VERSI_APLIKASI = '13.7.2'
export const KETERANGAN_VERSI = 'Ikon aplikasi baru: logo pondok dengan tulisan SIMKA'

// Waktu kode dibangun oleh GitHub Actions; dipakai untuk memastikan versi yang tayang adalah yang terbaru.
/* global __WAKTU_BUILD__ */
export const WAKTU_BUILD = typeof __WAKTU_BUILD__ !== 'undefined' ? __WAKTU_BUILD__ : ''
