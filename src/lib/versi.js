// SIMKA PRO | src/lib/versi.js | v14.19.0 | 14.19.0: nomor surat per bagian, nomor awal, persuratan per bagian, sesi tidak minta masuk ulang | 21/10/2026
// Nomor versi aplikasi yang tampil di halaman Profil. Naikkan setiap kali kode diunggah ke GitHub.
// Keterangan versi tampil kepada pengguna, jadi ditulis tanpa kata "Fase".
export const VERSI_APLIKASI = '14.19.0'
export const KETERANGAN_VERSI = 'Nomor surat terpisah untuk Yayasan, Pondok, Wustha, dan SMA (surat biasa berlanjut lintas kode perihal, Surat Keputusan QR berurutan sendiri) dengan nomor awal yang dapat diatur dan nomor ribuan yang utuh; surat masuk, surat keluar, dan buku agenda per bagian dengan kop dan pimpinan bagian itu; aplikasi tidak lagi meminta masuk ulang setiap dibuka'

// Waktu kode dibangun oleh GitHub Actions; dipakai untuk memastikan versi yang tayang adalah yang terbaru.
/* global __WAKTU_BUILD__ */
export const WAKTU_BUILD = typeof __WAKTU_BUILD__ !== 'undefined' ? __WAKTU_BUILD__ : ''
