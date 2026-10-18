// SIMKA PRO | src/lib/tahsin.js | v1.0 | 14.11.0: konstanta tahsin (tahapan bawaan, nilai, asal santri) | 18/10/2026
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
export const CATATAN_LULUS_BAWAAN = 'Santri lulus tahsin bila seluruh tahapan tuntas dan bacaan dinilai lancar oleh pembina, lalu disahkan Kepala Bidang Tahfizh.'

export const NILAI_TAHSIN = {
  lancar: { n: 'Lancar', w: 'presensi' },
  cukup: { n: 'Cukup', w: 'tahfizh' },
  perlu_ulang: { n: 'Perlu diulang', w: 'klinik' },
}
export const SUMBER_TAHSIN = { santri_baru: 'Santri baru', pindahan: 'Santri pindahan', rekomendasi: 'Rekomendasi muhaffizh', lainnya: 'Lainnya' }
export const STATUS_TAHSIN = {
  berjalan: { n: 'Berjalan', w: 'tahsin' },
  menunggu: { n: 'Diajukan lulus', w: 'pengajuan' },
  lulus: { n: 'Lulus tahsin', w: 'presensi' },
  dihentikan: { n: 'Dihentikan', w: 'hakakses' },
}
/** Status tampilan: "berjalan" yang sudah diajukan lulus ditampilkan "Diajukan lulus". */
export const keadaanTahsin = (t) => (t.status === 'berjalan' && t.diajukan_lulus_pada ? 'menunggu' : t.status)
/** Persentase kemajuan: tahap tuntas (tahap berjalan − 1) dari jumlah tahapan; lulus = 100. */
export const persenTahsin = (t) => (t.status === 'lulus' ? 100 : Math.round((Math.max(0, (t.tahap || 1) - 1) / Math.max(1, t.jumlah_tahap || 8)) * 100))
