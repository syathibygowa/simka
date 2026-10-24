// SIMKA PRO | src/lib/tahsin.js | v1.1 | 14.21.0: ujian tahsin (hasil, KKM), status Menunggu ujian | 24/10/2026
// Tahsin: pembinaan bacaan Al-Qur'an bagi santri yang belum menghafal (umumnya santri baru atau pindahan).
// Tahapan dapat diubah pengelola di server (pengaturan "tahsin"); daftar di bawah dipakai mode demo dan sebagai cadangan.
export const TAHAPAN_BAWAAN = [
  { nama: 'Huruf hijaiyah dan makharijul huruf', uraian: 'Mengenal dan melafalkan huruf hijaiyah dari tempat keluarnya dengan benar' },
  { nama: 'Sifatul huruf', uraian: "Membedakan sifat huruf: hams, jahr, isti'la, istifal, qalqalah, dan lainnya" },
  { nama: 'Harakat, tanwin, sukun, dan tasydid', uraian: 'Membaca harakat pendek, tanwin, sukun, dan tasydid dengan tepat' },
  { nama: 'Hukum nun sukun dan tanwin', uraian: 'Izhar, idgham, iqlab, dan ikhfa' },
  { nama: "Hukum mim sukun, ghunnah, dan lam ta'rif", uraian: 'Ikhfa syafawi, idgham mimi, izhar syafawi, ghunnah musyaddadah, lam qamariyah dan syamsiyah' },
  { nama: 'Hukum mad', uraian: "Mad thabi'i dan mad far'i beserta panjang bacaannya" },
  { nama: "Waqaf dan ibtida'", uraian: 'Tanda waqaf, cara berhenti dan memulai bacaan' },
  { nama: 'Tilawah lancar', uraian: "Membaca Al-Qur'an dengan tartil dan lancar; siap mulai menghafal" },
]
export const CATATAN_LULUS_BAWAAN = 'Santri diajukan ujian tahsin bila seluruh tahapan tuntas dan bacaan dinilai lancar oleh pembina. Penguji menilai Makhraj dan Shifat; santri yang dinyatakan lulus mulai menghafal.'
/** 14.21.0: KKM ujian tahsin (rata-rata Makhraj dan Shifat) bila belum diatur. */
export const KKM_TAHSIN = 75
export const HASIL_TAHSIN = { lulus: { n: 'Lulus', w: 'presensi' }, belum_lulus: { n: 'Belum lulus', w: 'klinik' } }

export const NILAI_TAHSIN = {
  lancar: { n: 'Lancar', w: 'presensi' },
  cukup: { n: 'Cukup', w: 'tahfizh' },
  perlu_ulang: { n: 'Perlu diulang', w: 'klinik' },
}
export const SUMBER_TAHSIN = { santri_baru: 'Santri baru', pindahan: 'Santri pindahan', rekomendasi: 'Rekomendasi muhaffizh', lainnya: 'Lainnya' }
export const STATUS_TAHSIN = {
  berjalan: { n: 'Berjalan', w: 'tahsin' },
  menunggu: { n: 'Menunggu ujian', w: 'pengajuan' },
  lulus: { n: 'Lulus tahsin', w: 'presensi' },
  dihentikan: { n: 'Dihentikan', w: 'hakakses' },
}
/** Status tampilan: "berjalan" yang sudah diajukan lulus ditampilkan "Diajukan lulus". */
export const keadaanTahsin = (t) => (t.status === 'berjalan' && t.diajukan_lulus_pada ? 'menunggu' : t.status)
/** Persentase kemajuan: tahap tuntas (tahap berjalan − 1) dari jumlah tahapan; lulus = 100. */
export const persenTahsin = (t) => (t.status === 'lulus' ? 100 : Math.round((Math.max(0, (t.tahap || 1) - 1) / Math.max(1, t.jumlah_tahap || 8)) * 100))
