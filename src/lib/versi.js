// SIMKA PRO | src/lib/versi.js | v14.37.0 | 14.37.0: hasil audit sistem — masuk tidak memproses terus, keluar membersihkan data akun, username bergaris bawah, pembersihan kode | 30/10/2026
// Nomor versi aplikasi yang tampil di halaman Profil. Naikkan setiap kali kode diunggah ke GitHub.
// Keterangan versi tampil kepada pengguna, jadi ditulis tanpa kata "Fase".
export const VERSI_APLIKASI = '14.37.0'
export const KETERANGAN_VERSI = 'Pemeriksaan menyeluruh sistem: masuk tidak lagi memproses terus saat server ramai, keluar akun membersihkan seluruh data di perangkat, username bergaris bawah dapat masuk, fungsi internal tertutup bagi pengguna belum masuk, dan halaman yang tidak terpakai dibersihkan'

// Waktu kode dibangun oleh GitHub Actions; dipakai untuk memastikan versi yang tayang adalah yang terbaru.
/* global __WAKTU_BUILD__ */
export const WAKTU_BUILD = typeof __WAKTU_BUILD__ !== 'undefined' ? __WAKTU_BUILD__ : ''
