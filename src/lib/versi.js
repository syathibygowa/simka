// SIMKA PRO | src/lib/versi.js | v13.6.0 | Perbaikan 13.6.0: sub-tab, jadwal kerja pegawai, audit log superadmin, pusat logo, jam pelajaran per hari | 16/10/2026
// Nomor versi aplikasi yang tampil di halaman Profil. Naikkan setiap kali kode diunggah ke GitHub.
// Keterangan versi tampil kepada pengguna, jadi ditulis tanpa kata "Fase".
export const VERSI_APLIKASI = '13.6.0'
export const KETERANGAN_VERSI = 'Sub-tab bergaris bawah, jadwal kerja semua pegawai, audit log khusus superadmin, pusat logo, dan jam pelajaran per hari'

// Waktu kode dibangun oleh GitHub Actions; dipakai untuk memastikan versi yang tayang adalah yang terbaru.
/* global __WAKTU_BUILD__ */
export const WAKTU_BUILD = typeof __WAKTU_BUILD__ !== 'undefined' ? __WAKTU_BUILD__ : ''
