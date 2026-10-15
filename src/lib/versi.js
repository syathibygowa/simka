// SIMKA PRO | src/lib/versi.js | v12.13.1 | Perbaikan: nama berkas cetak/PDF sesuai dokumen | 16/10/2026
// Nomor versi aplikasi yang tampil di halaman Profil. Naikkan setiap kali kode diunggah ke GitHub.
// Keterangan versi tampil kepada pengguna, jadi ditulis tanpa kata "Fase".
export const VERSI_APLIKASI = '12.13.1'
export const KETERANGAN_VERSI = 'Nama berkas cetak/PDF mengikuti isi dokumen: nama pegawai/santri atau bidang, nama dokumen, dan periode bulan'

// Waktu kode dibangun oleh GitHub Actions; dipakai untuk memastikan versi yang tayang adalah yang terbaru.
/* global __WAKTU_BUILD__ */
export const WAKTU_BUILD = typeof __WAKTU_BUILD__ !== 'undefined' ? __WAKTU_BUILD__ : ''
