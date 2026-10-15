// SIMKA PRO | src/lib/versi.js | v13.0.0 | Fase 9 – Tahap 13.0.0 Fondasi Portal Wali | 15/10/2026
// Nomor versi aplikasi yang tampil di halaman Profil. Naikkan setiap kali kode diunggah ke GitHub.
// Keterangan versi tampil kepada pengguna, jadi ditulis tanpa kata "Fase".
export const VERSI_APLIKASI = '13.0.0'
export const KETERANGAN_VERSI = 'Portal Wali Santri: masuk wali (NIS/NISN, tanggal lahir, 6 digit HP), beranda anak, beberapa anak per perangkat, dan pengelolaan Portal Wali di Data Santri'

// Waktu kode dibangun oleh GitHub Actions; dipakai untuk memastikan versi yang tayang adalah yang terbaru.
/* global __WAKTU_BUILD__ */
export const WAKTU_BUILD = typeof __WAKTU_BUILD__ !== 'undefined' ? __WAKTU_BUILD__ : ''
