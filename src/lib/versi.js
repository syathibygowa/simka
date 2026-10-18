// SIMKA PRO | src/lib/versi.js | v14.12.0 | 14.12.0: hemat log server, kapasitas database, backup mingguan mudah dibaca | 18/10/2026
// Nomor versi aplikasi yang tampil di halaman Profil. Naikkan setiap kali kode diunggah ke GitHub.
// Keterangan versi tampil kepada pengguna, jadi ditulis tanpa kata "Fase".
export const VERSI_APLIKASI = '14.12.0'
export const KETERANGAN_VERSI = 'Hemat permintaan dan log server (pembaruan langsung diredam, jadwal otomatis digabung), Setelan → Kapasitas untuk memantau ukuran database dan masa simpan data, serta backup mingguan Google Sheets dengan 18 lembar ringkas yang mudah dibaca'

// Waktu kode dibangun oleh GitHub Actions; dipakai untuk memastikan versi yang tayang adalah yang terbaru.
/* global __WAKTU_BUILD__ */
export const WAKTU_BUILD = typeof __WAKTU_BUILD__ !== 'undefined' ? __WAKTU_BUILD__ : ''
