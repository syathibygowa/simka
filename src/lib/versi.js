// SIMKA PRO | src/lib/versi.js | v14.16.0 | 14.16.0: status sakit/izin otomatis selaras dengan Klinik dan Perizinan | 19/10/2026
// Nomor versi aplikasi yang tampil di halaman Profil. Naikkan setiap kali kode diunggah ke GitHub.
// Keterangan versi tampil kepada pengguna, jadi ditulis tanpa kata "Fase".
export const VERSI_APLIKASI = '14.16.0'
export const KETERANGAN_VERSI = 'Klinik dan absensi selaras: santri yang dinyatakan sakit otomatis tercatat Sakit di semua absensi (termasuk yang sudah tersimpan dan jurnal mengajar), setelah sembuh atau kembali dari izin pulang langsung dapat diabsen lagi; santri yang sudah dirujuk dan menunggu klinik ditandai di formulir absensi'

// Waktu kode dibangun oleh GitHub Actions; dipakai untuk memastikan versi yang tayang adalah yang terbaru.
/* global __WAKTU_BUILD__ */
export const WAKTU_BUILD = typeof __WAKTU_BUILD__ !== 'undefined' ? __WAKTU_BUILD__ : ''
