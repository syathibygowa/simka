// SIMKA PRO | src/lib/kelengkapanSantri.js | v1.0 | Perbaikan 13.8.0: daftar kolom pemeriksaan kelengkapan seluruh data santri | 16/10/2026
// Kelengkapan data santri di seluruh basis data (bukan hanya data pokok): identitas, alamat, orang tua/wali,
// data masuk dan sekolah asal, serta kelompok pondok tahun ajaran berjalan (kelas, kamar, halaqah).
// "bawaan: false" = tidak dihitung kecuali diaktifkan pengguna di "Atur kolom" (data yang memang tidak selalu ada).
const kontak = (s, h) => (s.kontak || []).find((x) => x.hubungan === h) || {}
const ada = (v) => v != null && String(v).trim() !== ''
const kelompok = (s, j) => (s.kelompok || []).some((k) => k.jenis === j)

export const KATEGORI_KELENGKAPAN = [
  { k: 'identitas', n: 'Identitas', w: 'santri', kolom: [
    { k: 'nisn', n: 'NISN', cek: (s) => ada(s.nisn) },
    { k: 'nik', n: 'NIK', cek: (s) => ada(s.nik) },
    { k: 'no_kk', n: 'Nomor KK', cek: (s) => ada(s.no_kk) },
    { k: 'nama_panggilan', n: 'Nama panggilan', cek: (s) => ada(s.nama_panggilan) },
    { k: 'tempat_lahir', n: 'Tempat lahir', cek: (s) => ada(s.tempat_lahir) },
    { k: 'tanggal_lahir', n: 'Tanggal lahir', cek: (s) => ada(s.tanggal_lahir) },
    { k: 'anak_ke', n: 'Anak ke-', cek: (s) => ada(s.anak_ke) },
    { k: 'agama', n: 'Agama', cek: (s) => ada(s.agama) },
    { k: 'status_keluarga', n: 'Status dalam keluarga', cek: (s) => ada(s.status_keluarga) },
    { k: 'foto', n: 'Foto', cek: (s) => ada(s.foto_id) },
  ] },
  { k: 'alamat', n: 'Alamat', w: 'agenda', kolom: [
    { k: 'alamat', n: 'Alamat (jalan/dusun)', cek: (s) => ada(s.alamat) },
    { k: 'rt', n: 'RT', cek: (s) => ada(s.rt) },
    { k: 'rw', n: 'RW', cek: (s) => ada(s.rw) },
    { k: 'kelurahan', n: 'Kelurahan/desa', cek: (s) => ada(s.kelurahan) },
    { k: 'kecamatan', n: 'Kecamatan', cek: (s) => ada(s.kecamatan) },
    { k: 'kota_kab', n: 'Kabupaten/kota', cek: (s) => ada(s.kota_kab) },
    { k: 'provinsi', n: 'Provinsi', cek: (s) => ada(s.provinsi) },
    { k: 'telepon_rumah', n: 'Telepon rumah', bawaan: false, cek: (s) => ada(s.telepon_rumah) },
  ] },
  { k: 'ortu', n: 'Orang tua/wali', w: 'pengajuan', kolom: [
    { k: 'nama_ayah', n: 'Nama ayah', cek: (s) => ada(kontak(s, 'ayah').nama) },
    { k: 'pekerjaan_ayah', n: 'Pekerjaan ayah', cek: (s) => ada(kontak(s, 'ayah').pekerjaan) },
    { k: 'hp_ayah', n: 'HP ayah', bawaan: false, cek: (s) => ada(kontak(s, 'ayah').no_hp) },
    { k: 'nama_ibu', n: 'Nama ibu', cek: (s) => ada(kontak(s, 'ibu').nama) },
    { k: 'pekerjaan_ibu', n: 'Pekerjaan ibu', cek: (s) => ada(kontak(s, 'ibu').pekerjaan) },
    { k: 'hp_ibu', n: 'HP ibu', bawaan: false, cek: (s) => ada(kontak(s, 'ibu').no_hp) },
    { k: 'hp_ortu', n: 'Nomor HP orang tua/wali (minimal satu)', cek: (s) => (s.kontak || []).some((x) => ada(x.no_hp)) },
    { k: 'kontak_utama', n: 'Kontak utama (penerima kabar)', cek: (s) => (s.kontak || []).some((x) => x.utama) },
    { k: 'alamat_ortu', n: 'Alamat orang tua', cek: (s) => ada(s.alamat_ortu) },
    { k: 'nama_wali', n: 'Nama wali/darurat', bawaan: false, cek: (s) => ada(kontak(s, 'wali').nama) },
    { k: 'hp_wali', n: 'HP wali/darurat', bawaan: false, cek: (s) => ada(kontak(s, 'wali').no_hp) },
  ] },
  { k: 'masuk', n: 'Masuk dan sekolah asal', w: 'laporan', kolom: [
    { k: 'tanggal_masuk', n: 'Tanggal masuk', cek: (s) => ada(s.tanggal_masuk) },
    { k: 'asal_sekolah', n: 'Asal sekolah', cek: (s) => ada(s.asal_sekolah) },
    { k: 'diterima_tingkat', n: 'Diterima di kelas', cek: (s) => ada(s.diterima_tingkat) },
    { k: 'hafalan_awal', n: 'Hafalan awal (juz)', cek: (s) => ada(s.hafalan_awal_juz) },
  ] },
  { k: 'pondok', n: 'Kelompok pondok', w: 'kelompoksantri', kolom: [
    { k: 'kelas', n: 'Rombel kelas', cek: (s) => kelompok(s, 'kelas') },
    { k: 'kamar', n: 'Kamar asrama', cek: (s) => kelompok(s, 'kamar') },
    { k: 'halaqah', n: 'Halaqah tahfizh', cek: (s) => kelompok(s, 'halaqah') },
    { k: 'ekskul', n: 'Ekskul', bawaan: false, cek: (s) => kelompok(s, 'ekskul') },
  ] },
]
export const SEMUA_KOLOM = KATEGORI_KELENGKAPAN.flatMap((g) => g.kolom.map((c) => ({ ...c, kategori: g.k })))
export const KOLOM_BAWAAN = SEMUA_KOLOM.filter((c) => c.bawaan !== false).map((c) => c.k)

/** Periksa satu santri terhadap daftar kolom aktif → { kurang: [kolom], persen } */
export function periksaSantri(s, aktif) {
  const kol = SEMUA_KOLOM.filter((c) => aktif.includes(c.k))
  const kurang = kol.filter((c) => !c.cek(s))
  return { kurang, persen: kol.length ? Math.round(((kol.length - kurang.length) / kol.length) * 100) : 100 }
}
