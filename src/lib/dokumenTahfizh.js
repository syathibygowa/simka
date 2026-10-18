// SIMKA PRO | src/lib/dokumenTahfizh.js | v1.3 | 14.10.0: Sertifikat Penghargaan Khataman dan status khataman | 18/10/2026
// Istilah jenis dan status dokumen tahfizh, serta pengaturan bawaan kepala Sertifikat Tahfizhul Quran.
export const JENIS_DOK_TAHFIZH = {
  suket_juz: { n: 'Suket kenaikan juz', panjang: 'Surat Keterangan Ujian Kenaikan Juz', w: 'agenda' },
  sertifikat_hafalan: { n: 'Sertifikat hafalan', panjang: 'Sertifikat Hafalan', w: 'tahfizh' },
  sertifikat_tahfizh: { n: 'Sertifikat Tahfizhul Quran', panjang: 'Sertifikat Tahfizhul Quran', w: 'prestasi' },
  sertifikat_khataman: { n: 'Sertifikat khataman', panjang: 'Sertifikat Penghargaan Khataman', w: 'libursantri' },
}
/** Khataman Al-Qur'an 30 juz. */
export const STATUS_KHATAMAN = {
  diusulkan: { n: 'Menunggu persetujuan', w: 'pengajuan' }, dijadwalkan: { n: 'Dijadwalkan', w: 'agenda' }, selesai: { n: 'Terlaksana', w: 'presensi' },
  ditolak: { n: 'Ditolak', w: 'klinik' }, dibatalkan: { n: 'Dibatalkan', w: 'hakakses' },
}
export const PENGATURAN_KHATAMAN = {
  tempat_bawaan: 'Masjid Pondok Pesantren Imam Asy-Syathiby', judul: 'SERTIFIKAT PENGHARGAAN', subjudul: "KHATAMAN AL-QUR'AN 30 JUZ",
  pembuka: "Dengan memohon ridho Allah _Subhanahu Wata'ala_, Pondok Pesantren Tahfizhul Quran Imam Asy-Syathiby Wahdah Islamiyah Gowa memberikan penghargaan kepada:",
  isi: "atas kesungguhan dan ketekunannya dalam menghafal Al-Qur'an hingga menuntaskan hafalan 30 juz, yang dikhatamkan di hadapan para asatidzah dan santri",
  doa: "Semoga Allah menjaga hafalannya, menjadikannya ahlul Qur'an, dan memberkahi kedua orang tuanya dengan mahkota kemuliaan.",
}
/** Status gabungan: dokumen tahfizh (terbit/dicabut) + registri (draf/sah/ditolak). */
export function statusDok(d) {
  if (d.status === 'dicabut' || d.status_dokumen === 'dicabut') return { k: 'dicabut', n: 'Dicabut', w: 'sistem' }
  if (d.status_dokumen === 'ditolak') return { k: 'ditolak', n: 'Ditolak penanda tangan', w: 'klinik' }
  if (d.status_dokumen === 'draf') return { k: 'draf', n: 'Menunggu tanda tangan', w: 'pengajuan' }
  return { k: 'sah', n: d.mode_ttd === 'basah' ? 'Sah (tanda tangan basah)' : 'Sah', w: 'presensi' }
}
export const PENGATURAN_SERTIFIKAT = {
  baris1: 'YAYASAN PESANTREN WAHDAH ISLAMIYAH CABANG GOWA',
  baris2: 'PONDOK PESANTREN TAHFIZHUL QURAN IMAM ASY-SYATHIBY',
  baris3: 'WAHDAH ISLAMIYAH GOWA',
  pembuka: "Dengan memohon ridho Allah _Subhanahu Wata'ala_, Pondok Pesantren Tahfizhul Quran Imam Asy-Syathiby Wahdah Islamiyah Gowa menerangkan bahwa:",
  program: 'Telah menyelesaikan Program Tahfizhul Quran di Pondok Pesantren Tahfizhul Quran Imam Asy-Syathiby Wahdah Islamiyah Gowa',
  penutup: 'Demikian sertifikat ini diberikan sebagai tanda hafalan untuk terus menjaga, mengamalkan dan menyebarkan nilai-nilai Al-Quran.',
  // logo_kanan = logo utama (kosong = logo pondok di Setelan → Logo; nilai "logo:<kode>" dari daftar logo); logo_kiri = logo tambahan (kosong = tidak ditampilkan)
  logo_kiri: '', logo_kanan: '',
}
/** Teks dengan _miring_ → HTML aman. */
export const miring = (t) => String(t || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/_([^_]+)_/g, '<i>$1</i>')
