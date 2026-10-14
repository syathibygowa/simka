// SIMKA PRO | src/lib/versi.js | v12.8.1 | Perbaikan: tampilan HP tidak meluber | 14/10/2026
// Nomor versi aplikasi yang tampil di halaman Profil. Naikkan setiap kali kode diunggah ke GitHub.
// Keterangan versi tampil kepada pengguna, jadi ditulis tanpa kata "Fase".
export const VERSI_APLIKASI = '12.8.1'
export const KETERANGAN_VERSI = 'Perbaikan tampilan HP: kartu dan daftar tidak lagi meluber melebihi lebar layar (Data Presensi, Tahfizh, Penjadwalan, dan halaman lain)'

// Waktu kode dibangun oleh GitHub Actions; dipakai untuk memastikan versi yang tayang adalah yang terbaru.
/* global __WAKTU_BUILD__ */
export const WAKTU_BUILD = typeof __WAKTU_BUILD__ !== 'undefined' ? __WAKTU_BUILD__ : ''
