// SIMKA PRO | src/lib/santri.js | v1.2 | Fase 4 – Perbaikan P1 dan Tahap 3 | 04/10/2026
// Label baku, pembacaan NIS pondok, normalisasi isian, dan kolom templat Excel data santri.
import { normalJK, normalHP } from './kepegawaian'
import { supabase, MODE_DEMO } from './supabase'

export const JENJANG = { wustha: 'Kesetaraan Wustha', sma: 'SMA' }
export const JENJANG_PENDEK = { wustha: 'Wustha', sma: 'SMA' }
export const TINGKAT = { wustha: [7, 8, 9], sma: [10, 11, 12] }
export const jenjangDariTingkat = (t) => (Number(t) >= 10 ? 'sma' : 'wustha')
export const STATUS_SANTRI = {
  aktif: { n: 'Aktif', w: 'presensi' },
  nonaktif: { n: 'Nonaktif sementara', w: 'tahfizh' },
  mutasi_keluar: { n: 'Mutasi keluar', w: 'klinik' },
  lulus: { n: 'Lulus', w: 'pegawai' },
  berhenti: { n: 'Berhenti', w: 'hakakses' },
}
export const HUBUNGAN = { ayah: 'Ayah', ibu: 'Ibu', wali: 'Wali/darurat' }
export const JALUR = { baru: 'Santri baru', pindahan: 'Pindahan (mutasi masuk)' }

/** Kelas tampilan, mis. "Kelas 8 Wustha". */
export const labelKelas = (s) => (s?.tingkat ? `Kelas ${s.tingkat} ${JENJANG_PENDEK[s.jenjang] || ''}`.trim() : '–')

/**
 * NIS pondok 7 digit: YY (tahun masuk) + AA (angkatan) + NNN (nomor santri).
 * Contoh 2211010 → masuk 2022, angkatan 11, nomor 010.
 */
export function uraiNIS(nis) {
  const t = String(nis ?? '').trim()
  if (!/^\d{7}$/.test(t)) return null
  return { tahun: 2000 + Number(t.slice(0, 2)), angkatan: Number(t.slice(2, 4)), nomor: t.slice(4) }
}
/** NIS berikutnya untuk awalan 4 digit (tahun + angkatan) berdasarkan daftar santri yang terlihat. */
export function nisBerikutnya(awalan, daftar) {
  if (!/^\d{4}$/.test(awalan)) return ''
  const pakai = daftar.map((s) => s.nis).filter((n) => n?.startsWith(awalan)).map((n) => Number(n.slice(4)))
  const urut = (pakai.length ? Math.max(...pakai) : 0) + 1
  return urut > 999 ? '' : awalan + String(urut).padStart(3, '0')
}

/**
 * Penanda tangan kepala jenjang dari Pengaturan → Penanda tangan (jabatan tertulis memuat "Wustha" atau "SMA").
 * Bila belum ada, nama dikosongkan agar diisi tangan (tidak memakai nama Direktur).
 */
const KEPALA_DEMO = {
  wustha: { jabatan: 'Kepala Kesetaraan Wustha (SMP)', nama: 'Chamdar Nur, S.Pd.I., SH., Lc., M.Pd.', niy: '1983042805201401' },
  sma: { jabatan: 'Kepala SMA', nama: 'H. Afrianto, Lc, M.H.', niy: '1994042801202001' },
}
export async function penandaJenjang(jenjang) {
  const j = jenjang === 'sma' ? 'sma' : 'wustha'
  if (MODE_DEMO) return KEPALA_DEMO[j]
  const { data } = await supabase.from('signatories').select('jabatan_tertulis, nama, niy').eq('aktif', true)
    .ilike('jabatan_tertulis', j === 'sma' ? 'Kepala SMA%' : 'Kepala%Wustha%').order('urutan').limit(1).maybeSingle()
  return data ? { jabatan: data.jabatan_tertulis, nama: data.nama, niy: data.niy } : { jabatan: `Kepala ${JENJANG[j]}`, nama: '', niy: '' }
}

/** Inisial untuk avatar. */
export const inisial = (nama) => String(nama || '?').split(/\s+/).slice(0, 2).map((k) => k[0]).join('').toUpperCase()
/** Kontak utama (penerima WA bawaan). */
export const kontakUtama = (s) => (s?.kontak || []).find((k) => k.utama) || (s?.kontak || [])[0] || null
export const kontakDari = (s, hubungan) => (s?.kontak || []).find((k) => k.hubungan === hubungan) || null

// ---------- Normalisasi isian Excel ----------
const bersih = (v) => String(v ?? '').trim().toLowerCase().replace(/\s+/g, ' ')
export function normalJenjang(v) {
  const t = bersih(v); if (!t) return ''
  if (/(wustha|smp|mts|kesetaraan|paket b)/.test(t)) return 'wustha'
  if (/(sma|ma|aliyah|ulya|paket c)/.test(t)) return 'sma'
  return null
}
/** Kelas: "7", "VII", "Kelas 8B", "10 IPA" → angka 7–12. */
export function normalTingkat(v) {
  const t = bersih(v).replace(/^kelas\s*/, ''); if (!t) return ''
  const romawi = { vii: 7, viii: 8, ix: 9, x: 10, xi: 11, xii: 12 }
  const r = t.match(/^(xii|xi|x|ix|viii|vii)\b/); if (r) return romawi[r[1]]
  const a = t.match(/^(7|8|9|10|11|12)(?!\d)/); return a ? Number(a[1]) : null
}
export { normalJK, normalHP }
export function normalJalur(v) {
  const t = bersih(v); if (!t) return ''
  if (/pindah|mutasi/.test(t)) return 'pindahan'
  if (/baru|reguler|spmb|ppdb/.test(t)) return 'baru'
  return null
}

/** Kolom templat impor. "alias" = judul lain yang juga dikenali (mis. ekspor aplikasi SPMB pondok). */
export const KOLOM_IMPOR = [
  { k: 'nis', j: 'NIS (7 digit)', wajib: true, alias: ['nis', 'nomor induk', 'no induk', 'nomor induk santri', 'no. induk'] },
  { k: 'nisn', j: 'NISN', wajib: true, alias: ['nisn', 'nomor induk siswa nasional'] },
  { k: 'nama_lengkap', j: 'Nama lengkap', wajib: true, alias: ['nama', 'nama lengkap', 'nama santri', 'nama siswa', 'nama peserta didik'] },
  { k: 'jenis_kelamin', j: 'Jenis kelamin (L/P)', wajib: true, alias: ['jenis kelamin', 'jk', 'l/p', 'gender'] },
  { k: 'jenjang', j: 'Jenjang (Wustha/SMA)', alias: ['jenjang', 'jenjang sekolah', 'tingkat sekolah', 'sekolah'] },
  { k: 'tingkat', j: 'Kelas (7–12)', wajib: true, alias: ['kelas', 'tingkat', 'rombel', 'tingkat kelas'] },

  { k: 'nama_panggilan', j: 'Nama panggilan', alias: ['panggilan', 'nama panggilan'] },
  { k: 'tempat_lahir', j: 'Tempat lahir', wajib: true, alias: ['tempat lahir', 'tempat'] },
  { k: 'tanggal_lahir', j: 'Tanggal lahir (dd/mm/yyyy)', wajib: true, alias: ['tanggal lahir', 'tgl lahir', 'tgl. lahir'] },
  { k: 'nik', j: 'NIK', alias: ['nik', 'nomor induk kependudukan', 'no kk/nik'] },
  { k: 'anak_ke', j: 'Anak ke-', alias: ['anak ke', 'anak ke-'] },
  { k: 'no_kk', j: 'Nomor KK', alias: ['no kk', 'nomor kk', 'no. kk', 'nomor kartu keluarga', 'kk'] },
  { k: 'alamat', j: 'Alamat (jalan/dusun)', alias: ['alamat', 'alamat rumah', 'alamat lengkap', 'jalan', 'dusun', 'alamat jalan'] },
  { k: 'rt', j: 'RT', alias: ['rt'] },
  { k: 'rw', j: 'RW', alias: ['rw'] },
  { k: 'kelurahan', j: 'Kelurahan/desa', alias: ['kelurahan', 'desa', 'kelurahan/desa', 'desa/kelurahan'] },
  { k: 'kecamatan', j: 'Kecamatan', alias: ['kecamatan'] },
  { k: 'kota_kab', j: 'Kabupaten/kota', alias: ['kabupaten', 'kota', 'kabupaten/kota', 'kota/kabupaten', 'kab/kota'] },
  { k: 'provinsi', j: 'Provinsi', alias: ['provinsi', 'propinsi'] },
  { k: 'tanggal_masuk', j: 'Tanggal masuk (dd/mm/yyyy)', alias: ['tanggal masuk', 'tgl masuk', 'diterima tanggal'] },
  { k: 'jalur_masuk', j: 'Jalur masuk (Baru/Pindahan)', alias: ['jalur masuk', 'jalur', 'status masuk', 'jenis pendaftaran'] },
  { k: 'asal_sekolah', j: 'Asal sekolah', alias: ['asal sekolah', 'sekolah asal'] },
  { k: 'hafalan_awal_juz', j: 'Hafalan awal (juz)', alias: ['hafalan awal', 'hafalan', 'jumlah hafalan', 'hafalan (juz)'] },
  { k: 'nama_ayah', j: 'Nama ayah', alias: ['nama ayah', 'ayah', 'nama ayah kandung'] },
  { k: 'hp_ayah', j: 'HP ayah', alias: ['hp ayah', 'no hp ayah', 'nomor hp ayah', 'wa ayah'] },
  { k: 'pekerjaan_ayah', j: 'Pekerjaan ayah', alias: ['pekerjaan ayah'] },
  { k: 'nama_ibu', j: 'Nama ibu', alias: ['nama ibu', 'ibu', 'nama ibu kandung'] },
  { k: 'hp_ibu', j: 'HP ibu', alias: ['hp ibu', 'no hp ibu', 'nomor hp ibu', 'wa ibu'] },
  { k: 'pekerjaan_ibu', j: 'Pekerjaan ibu', alias: ['pekerjaan ibu'] },
  { k: 'nama_wali', j: 'Nama wali/darurat', alias: ['nama wali', 'wali', 'kontak darurat'] },
  { k: 'hp_wali', j: 'HP wali/darurat', alias: ['hp wali', 'no hp wali', 'nomor hp wali', 'hp darurat', 'no hp orang tua', 'hp orang tua', 'no. hp orang tua/wali'] },
  { k: 'pekerjaan_wali', j: 'Pekerjaan wali', alias: ['pekerjaan wali'] },
  { k: 'catatan', j: 'Catatan', alias: ['catatan', 'keterangan'] },
]
export function kenaliJudul(judul) {
  const t = bersih(judul).replace(/\s*\(.*\)\s*$/, '').replace(/[*:]/g, '').trim()
  for (const c of KOLOM_IMPOR) if (bersih(c.j).replace(/\s*\(.*\)\s*$/, '') === t || c.alias.includes(t)) return c.k
  return null
}

// ---------- Kelompok santri (Tahap 2) ----------
export const JENIS_KELOMPOK = {
  kelas:   { n: 'Kelas', jamak: 'Kelas', pengasuh: 'Wali kelas', warna: 'laporan', contoh: 'Contoh: 7A, 10 IPA' },
  kamar:   { n: 'Kamar', jamak: 'Kamar/asrama', pengasuh: 'Musyrif/musyrifah', warna: 'santri', contoh: 'Contoh: Kamar Abu Bakar' },
  halaqah: { n: 'Halaqah', jamak: 'Halaqah tahfizh', pengasuh: 'Muhaffizh/muhaffizhah', warna: 'tahfizh', contoh: 'Contoh: Halaqah Ust. Ahmad' },
  ekskul:  { n: 'Ekskul', jamak: 'Ekskul', pengasuh: 'Pembina/pelatih', warna: 'pengumuman', contoh: 'Contoh: Panahan, Pramuka' },
  lainnya: { n: 'Lainnya', jamak: 'Kelompok lainnya', pengasuh: 'Pembina', warna: 'hakakses', contoh: 'Contoh: Tim Olimpiade' },
}
/** Jabatan fungsional yang lazim mengasuh setiap jenis kelompok (untuk menyarankan pengasuh). */
export const JABATAN_PENGASUH = { kelas: 'WALI_KELAS', kamar: 'MUSYRIF', halaqah: 'MUHAFFIZH', ekskul: 'PEMBINA_EKSKUL', lainnya: null }
export const PERAN_PENGASUH = { utama: 'Pengasuh utama', pendamping: 'Pendamping', pengganti: 'Pengganti sementara' }
/** Kelompok aktif seorang santri menurut jenis, mis. kelompokDari(s, 'kelas') → { id, nama } */
export const kelompokDari = (s, jenis) => (s?.kelompok || []).find((k) => k.jenis === jenis) || null
export const namaKelompok = (s, jenis) => (s?.kelompok || []).filter((k) => k.jenis === jenis).map((k) => k.nama).join(', ')
/** Rombel bila sudah dibagi, selain itu "Kelas 8 Wustha". */
export const labelRombel = (s) => { const k = kelompokDari(s, 'kelas'); return k ? `Kelas ${k.nama.replace(/^kelas\s*/i, '')}` : labelKelas(s) }
export const subjudulKelompok = (g) => [
  g.jenis === 'kelas' && g.tingkat ? `Kelas ${g.tingkat} ${JENJANG_PENDEK[g.jenjang] || ''}`.trim() : null,
  g.jenis_kelamin === 'L' ? 'Putra' : g.jenis_kelamin === 'P' ? 'Putri' : 'Putra dan putri',
].filter(Boolean).join(' · ')

/** Penanda tangan kiri untuk daftar kelompok: kelas → kepala jenjang, kamar → Kepala Bidang Kesantrian, halaqah → Kepala Bidang Tahfizh. */
const BIDANG_DEMO = {
  kamar: { jabatan: 'Kepala Bidang Kesantrian', nama: 'Ust. Muhammad Ikhsan, S.Pd.I.', niy: '2018010303' },
  halaqah: { jabatan: 'Kepala Bidang Tahfizh', nama: '', niy: '' },
}
export async function penandaKelompok(g) {
  if (g.jenis === 'kelas') return penandaJenjang(g.jenjang)
  const pola = g.jenis === 'kamar' ? '%Kesantrian%' : g.jenis === 'halaqah' ? '%Tahfizh%' : 'Direktur'
  const cadang = g.jenis === 'kamar' ? 'Kepala Bidang Kesantrian' : g.jenis === 'halaqah' ? 'Kepala Bidang Tahfizh' : 'Direktur'
  if (MODE_DEMO) return BIDANG_DEMO[g.jenis] || { jabatan: 'Direktur', nama: 'Siswandi Safari, S.Pd.I., Lc., S.H., M.Ag.', niy: '1983020910201401' }
  const { data } = await supabase.from('signatories').select('jabatan_tertulis, nama, niy').eq('aktif', true)
    .ilike('jabatan_tertulis', pola).order('urutan').limit(1).maybeSingle()
  return data ? { jabatan: data.jabatan_tertulis, nama: data.nama, niy: data.niy } : { jabatan: cadang, nama: '', niy: '' }
}
/** Judul kelompok untuk tampilan, mis. kelas "7A" → "Kelas 7A". */
export const judulKelompok = (g) => (g?.jenis === 'kelas' && !/^kelas/i.test(g.nama) ? `Kelas ${g.nama}` : g?.nama || '')

// ---------- Kelengkapan dan alamat (Perbaikan P1) ----------
/** Data wajib: NIS, NISN, nama, tempat lahir, tanggal lahir. */
export const kurangWajib = (s) => [!s.nisn && 'NISN', !s.tempat_lahir && 'Tempat lahir', !s.tanggal_lahir && 'Tanggal lahir'].filter(Boolean)
/** Alamat lengkap satu baris: jalan/dusun, RT/RW, kelurahan, kecamatan, kabupaten/kota, provinsi. */
export const alamatLengkap = (s) => [s?.alamat, (s?.rt || s?.rw) && `RT ${s.rt || '–'}/RW ${s.rw || '–'}`, s?.kelurahan && `Kel./Desa ${s.kelurahan}`,
  s?.kecamatan && `Kec. ${s.kecamatan}`, s?.kota_kab, s?.provinsi].filter(Boolean).join(', ')
/** Nilai sel ekspor untuk satu kolom impor (ekspor dapat diimpor kembali tanpa diubah). */
export function nilaiEkspor(s, k, formatTanggal) {
  const kontak = (h) => (s.kontak || []).find((x) => x.hubungan === h) || {}
  switch (k) {
    case 'jenjang': return s.jenjang === 'sma' ? 'SMA' : 'Wustha'
    case 'jenis_kelamin': return s.jenis_kelamin
    case 'tanggal_lahir': case 'tanggal_masuk': return s[k] ? formatTanggal(s[k]) : ''
    case 'jalur_masuk': return s.jalur_masuk === 'pindahan' ? 'Pindahan' : 'Baru'
    case 'hafalan_awal_juz': return s.hafalan_awal_juz == null ? '' : String(s.hafalan_awal_juz).replace('.', ',')
    case 'nama_ayah': return kontak('ayah').nama || ''
    case 'hp_ayah': return kontak('ayah').no_hp || ''
    case 'pekerjaan_ayah': return kontak('ayah').pekerjaan || ''
    case 'nama_ibu': return kontak('ibu').nama || ''
    case 'hp_ibu': return kontak('ibu').no_hp || ''
    case 'pekerjaan_ibu': return kontak('ibu').pekerjaan || ''
    case 'nama_wali': return kontak('wali').nama || ''
    case 'hp_wali': return kontak('wali').no_hp || ''
    case 'pekerjaan_wali': return kontak('wali').pekerjaan || ''
    default: return s[k] == null ? '' : String(s[k])
  }
}
