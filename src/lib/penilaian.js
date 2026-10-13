// SIMKA PRO | src/lib/penilaian.js | v1.0 | Fase 12 – Tahap 1 Pengaturan penilaian | 13/10/2026
// Label baku penilaian dan rapor: jenis rapor, cara menentukan nilai rapor, kelompok predikat, sumber nilai mapel rapor,
// bank kalimat catatan, serta fungsi bantu predikat dan pembulatan.

export const JENIS_RAPOR = {
  sma: { n: 'Rapor SMA', pendek: 'SMA', kurikulum: 'Kurikulum Merdeka', jenjang: 'sma', tingkat: [10, 11, 12], warna: 'rapor' },
  wustha: { n: 'Rapor Wustha', pendek: 'Wustha', kurikulum: 'K13 disesuaikan', jenjang: 'wustha', tingkat: [7, 8, 9], warna: 'kelompoksantri' },
  tahfizh: { n: 'Rapor Tahfizh', pendek: 'Tahfizh', kurikulum: 'Program tahfizh', jenjang: null, tingkat: [7, 8, 9, 10, 11, 12], warna: 'tahfizh' },
}

/** Cara menentukan nilai rapor dari isian guru. */
export const MODE_NILAI = {
  tunggal: { n: 'Nilai tunggal', ket: 'Guru langsung mengisi nilai rapor; isian harian, ulangan, UTS, dan UAS hanya sebagai catatan.' },
  akumulasi: { n: 'Akumulasi otomatis', ket: 'Nilai rapor dihitung otomatis dari isian berbobot (tidak dapat diubah guru).' },
  rekomendasi: { n: 'Rekomendasi', ket: 'Hasil akumulasi tampil sebagai saran; guru menetapkan nilai rapor (pakai saran atau ubah sendiri).' },
}

export const STATUS_PERIODE = {
  disiapkan: { n: 'Disiapkan', w: 'hakakses', ket: 'Guru belum dapat mengisi nilai.' },
  dibuka: { n: 'Dibuka', w: 'presensi', ket: 'Guru, muhaffizh, pembina, dan wali kelas dapat mengisi nilai.' },
  ditutup: { n: 'Ditutup', w: 'klinik', ket: 'Nilai terkunci; perubahan melalui permintaan ubah nilai yang disetujui admin.' },
}

/** Kelompok predikat: rentang angka (sma, wustha, utas) atau pilihan huruf (pd = pengembangan diri, sikap). */
export const KELOMPOK_PREDIKAT = {
  sma: { n: 'Mapel SMA', angka: true, jenis: 'sma', ket: 'Satu tabel untuk semua mapel rapor SMA. Kalimat capaian diikuti daftar tujuan pembelajaran (TP).' },
  wustha: { n: 'Mapel Wustha', angka: true, jenis: 'wustha', dua: true, ket: 'Satu tabel untuk semua mapel rapor Wustha; kalimat capaian pengetahuan dan keterampilan.' },
  utas: { n: 'UTAS tahfizh', angka: true, jenis: 'tahfizh', arab: true, ket: 'Predikat Ujian Tahfizh Akhir Semester (rapor tahfizh dan bagian tahfizh rapor sekolah).' },
  pd: { n: 'Pengembangan diri', angka: false, jenis: null, ket: 'Nilai huruf dari pembina. Deskripsi boleh memuat {kegiatan} (nama ekskul).' },
  sikap: { n: 'Sikap', angka: false, jenis: null, ket: 'Diisi guru di akhir semester. Dicetak di rapor Wustha; di SMA hanya tampil di leger.' },
}

export const SUMBER_NILAI = {
  mapel: { n: 'Mapel ajar', ket: 'Diambil dari nilai guru mapel yang mengajar (satu mapel atau gabungan berbobot).' },
  tahfizh: { n: 'Nilai tahfizh (UTAS)', ket: 'Diambil dari nilai akhir Ujian Tahfizh Akhir Semester.' },
  manual: { n: 'Diisi wali kelas', ket: 'Tidak ada mapel ajar yang menjadi sumber; wali kelas mengisi nilainya.' },
}

export const ASPEK = { pengetahuan: 'Pengetahuan', keterampilan: 'Keterampilan' }

export const KATEGORI_KALIMAT = {
  catatan_wali: { n: 'Catatan wali kelas', w: 'walikelas', bagian: ['pembuka', 'kelebihan', 'dorongan', 'penutup'] },
  catatan_muhaffizh: { n: 'Catatan muhaffizh', w: 'tahfizh', bagian: ['pembuka', 'kelebihan', 'dorongan', 'penutup'] },
  kehadiran: { n: 'Catatan kehadiran (rapor sekolah)', w: 'presensi', bagian: ['ambang'] },
  kehadiran_halaqah: { n: 'Catatan kehadiran halaqah', w: 'absensi', bagian: ['ambang'] },
}
export const BAGIAN_KALIMAT = {
  pembuka: 'Pembuka', kelebihan: 'Apresiasi kelebihan', dorongan: 'Dorongan', penutup: 'Penutup dan doa', ambang: 'Menurut persentase kehadiran',
}
/** Pemicu kalimat: dipilih otomatis dari data santri saat catatan disusun (Tahap 4). */
export const KUNCI_KALIMAT = {
  catatan_wali: {
    kelebihan: { mapel_terbaik: 'Mapel nilai tertinggi', rata_tinggi: 'Rata-rata nilai tinggi', kenaikan: 'Nilai naik dari semester lalu', kehadiran: 'Kehadiran sangat baik',
      hafalan: 'Hafalan bertambah', utas: 'Predikat UTAS baik', pd: 'Pengembangan diri menonjol', sikap: 'Sikap sangat baik' },
    dorongan: { mapel_lemah: 'Mapel di bawah KKM/terendah', kehadiran: 'Kehadiran kurang', hafalan: 'Hafalan perlu dijaga', umum: 'Umum' },
  },
  catatan_muhaffizh: {
    kelebihan: { target_tercapai: 'Target hafalan tercapai', tambah_banyak: 'Penambahan hafalan banyak', utas: 'Predikat UTAS baik', kehadiran: 'Kehadiran halaqah baik', kenaikan_juz: 'Lulus ujian kenaikan juz' },
    dorongan: { target_kurang: 'Target belum tercapai', kehadiran: 'Kehadiran halaqah kurang', murajaah: 'Perlu murajaah' },
  },
}
/** Isian yang dapat dipakai dalam kalimat (diganti otomatis). */
export const ISIAN_KALIMAT = ['{panggilan}', '{mapel}', '{nilai}', '{mapel_lemah}', '{persen}', '{tambah_juz}', '{juz}', '{predikat_utas}', '{kegiatan}']

/** Predikat untuk sebuah nilai dari daftar rentang (kelompok angka). */
export function predikatDari(nilai, daftar) {
  if (nilai == null || nilai === '' || Number.isNaN(Number(nilai))) return null
  const n = Number(nilai)
  return (daftar || []).find((p) => p.nilai_min != null && n >= Number(p.nilai_min) && n <= Number(p.nilai_maks)) || null
}
/** Sebutan predikat sesuai pilihan bahasa (UTAS: Arab atau Indonesia). */
export const sebutanPredikat = (p, bahasa = 'indonesia') => (!p ? '' : bahasa === 'arab' && p.sebutan_arab ? p.sebutan_arab : p.sebutan)
export const bulatkan = (n, desimal = 0) => (n == null || Number.isNaN(Number(n)) ? null : Math.round(Number(n) * 10 ** desimal) / 10 ** desimal)

/** Celah antar-rentang (nilai yang tidak tercakup predikat mana pun), dibaca untuk peringatan di pengaturan. */
export function celahPredikat(daftar) {
  const r = (daftar || []).filter((p) => p.nilai_min !== '' && p.nilai_maks !== '' && p.nilai_min != null).map((p) => [Number(p.nilai_min), Number(p.nilai_maks)]).sort((a, b) => a[0] - b[0])
  const celah = []
  let atas = 0
  for (const [a, b] of r) { if (a - atas > 0.011 && !(atas === 0 && a === 0)) celah.push([atas, a]); atas = Math.max(atas, b) }
  if (r.length && 100 - atas > 0.011) celah.push([atas, 100])
  return celah
}
/** Ringkasan sumber nilai satu mapel rapor, mis. "← Matematika" atau "← Fisika 50% + Kimia 50%". */
export function labelSumber(m) {
  if (m.sumber === 'tahfizh') return '← Nilai UTAS tahfizh'
  if (m.sumber === 'manual') return 'Diisi wali kelas'
  const s = m.sumber_mapel || []
  if (!s.length) return 'Sumber nilai belum diatur'
  return '← ' + (s.length === 1 ? s[0].nama : s.map((x) => `${x.nama} ${Number(x.bobot)}%`).join(' + '))
}
export const sumberKurang = (m) => m.sumber === 'mapel' && !(m.sumber_mapel || []).length
