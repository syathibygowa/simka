// SIMKA PRO | src/lib/dokumenTahfizh.js | v1.1 | Perbaikan: bawaan sertifikat satu logo (pondok) | 16/10/2026
// Istilah jenis dan status dokumen tahfizh, serta pengaturan bawaan kepala Sertifikat Tahfizhul Quran.
export const JENIS_DOK_TAHFIZH = {
  suket_juz: { n: 'Suket kenaikan juz', panjang: 'Surat Keterangan Ujian Kenaikan Juz', w: 'agenda' },
  sertifikat_hafalan: { n: 'Sertifikat hafalan', panjang: 'Sertifikat Hafalan', w: 'tahfizh' },
  sertifikat_tahfizh: { n: 'Sertifikat Tahfizhul Quran', panjang: 'Sertifikat Tahfizhul Quran', w: 'prestasi' },
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
  // logo_kanan = logo utama (kosong = logo pondok di Setelan → Identitas); logo_kiri = logo tambahan (kosong = tidak ditampilkan)
  logo_kiri: '', logo_kanan: '',
}
/** Teks dengan _miring_ → HTML aman. */
export const miring = (t) => String(t || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/_([^_]+)_/g, '<i>$1</i>')
