// SIMKA PRO | src/lib/versi.js | v10.2.0 | Fase 10 – Penutup: inventaris semua surat, revisi surat keluar, format tanggal surat | 11/10/2026
// Nomor versi aplikasi yang tampil di halaman Profil. Naikkan setiap kali kode diunggah ke GitHub.
// Keterangan versi tampil kepada pengguna, jadi ditulis tanpa kata "Fase".
export const VERSI_APLIKASI = '10.2.0'
export const KETERANGAN_VERSI = 'Persuratan lengkap: surat masuk, disposisi, surat keluar, revisi, dan inventaris semua surat'

// Waktu kode dibangun oleh GitHub Actions; dipakai untuk memastikan versi yang tayang adalah yang terbaru.
/* global __WAKTU_BUILD__ */
export const WAKTU_BUILD = typeof __WAKTU_BUILD__ !== 'undefined' ? __WAKTU_BUILD__ : ''
