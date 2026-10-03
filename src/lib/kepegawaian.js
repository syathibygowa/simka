// SIMKA PRO | src/lib/kepegawaian.js | v1.0 | Fase 1 – Data pegawai | 03/10/2026
// Label baku, normalisasi isian, dan kolom templat Excel data pegawai.

export const STATUS_PEGAWAI = { tetap: 'Tetap', kontrak: 'Kontrak', honorer: 'Honorer' }
export const KATEGORI_HONORER = { lama: 'Lama', baru: 'Baru' }
export const PENDIDIKAN = { SD: 'SD', SMP: 'SMP', SMA: 'SMA', S1: 'Sarjana (S1)', 'S1-LN': 'Sarjana luar negeri (S1-LN)', S2: 'Magister (S2)', S3: 'Doktor (S3)' }
export const STATUS_KELUARGA = { menikah: 'Menikah', belum_menikah: 'Belum menikah', cerai: 'Cerai' }
export const LEVEL_MUHAFFIZH = { pemula: 'Pemula', terampil: 'Terampil', mahir: 'Mahir' }
export const KEAKTIFAN = { aktif: 'Aktif', cuti_panjang: 'Cuti panjang', nonaktif: 'Nonaktif', keluar: 'Keluar' }
export const STATUS_AKUN = {
  aktif: { n: 'Akun aktif', w: 'presensi' }, menunggu: { n: 'Menunggu verifikasi', w: 'verifikasi' },
  tanpa_akun: { n: 'Belum punya akun', w: 'tahfizh' }, ditolak: { n: 'Ditolak', w: 'klinik' }, nonaktif: { n: 'Akun nonaktif', w: 'hakakses' },
}

const bersih = (v) => String(v ?? '').trim().toLowerCase().replace(/\s+/g, ' ')

/** Cocokkan teks bebas ke kunci daftar (menerima kunci atau labelnya). */
export function cocokkan(teks, daftar, alias = {}) {
  const t = bersih(teks); if (!t) return ''
  if (alias[t] !== undefined) return alias[t]
  for (const [k, n] of Object.entries(daftar)) if (bersih(k) === t || bersih(n) === t) return k
  return null // tidak dikenal
}
export const normalStatus = (v) => cocokkan(v, STATUS_PEGAWAI, { 'pegawai tetap': 'tetap', 'pegawai kontrak': 'kontrak', gtt: 'honorer', ptt: 'honorer' })
export const normalHonorer = (v) => cocokkan(v, KATEGORI_HONORER)
export const normalPendidikan = (v) => cocokkan(String(v ?? '').replace(/\s+/g, ''), { SD: '', SMP: '', SMA: '', S1: '', 'S1-LN': '', S2: '', S3: '' },
  { sma: 'SMA', ma: 'SMA', smk: 'SMA', slta: 'SMA', mts: 'SMP', sltp: 'SMP', mi: 'SD', s1ln: 'S1-LN', 'lc.': 'S1-LN', lc: 'S1-LN', sarjana: 'S1', magister: 'S2', doktor: 'S3' })
export const normalKeluarga = (v) => cocokkan(v, STATUS_KELUARGA, { kawin: 'menikah', 'sudah menikah': 'menikah', lajang: 'belum_menikah', 'belum kawin': 'belum_menikah', janda: 'cerai', duda: 'cerai' })
export const normalLevel = (v) => cocokkan(v, LEVEL_MUHAFFIZH)
export const normalKeaktifan = (v) => cocokkan(v, KEAKTIFAN)
export function normalJK(v) {
  const t = bersih(v); if (!t) return ''
  if (['l', 'lk', 'laki-laki', 'laki laki', 'pria', 'ikhwan'].includes(t)) return 'L'
  if (['p', 'pr', 'perempuan', 'wanita', 'akhwat'].includes(t)) return 'P'
  return null
}
export function normalHP(v) {
  let n = String(v ?? '').replace(/[^0-9+]/g, '')
  if (n.startsWith('+62')) n = '0' + n.slice(3); else if (n.startsWith('62')) n = '0' + n.slice(2); else if (n.startsWith('8')) n = '0' + n
  return n
}

/** Masa kerja dari TMT: { tahun, bulan, teks } */
export function masaKerja(tmt) {
  if (!tmt) return null
  const a = new Date(tmt + 'T00:00:00'), b = new Date()
  let bln = (b.getFullYear() - a.getFullYear()) * 12 + b.getMonth() - a.getMonth(); if (b.getDate() < a.getDate()) bln--
  if (bln < 0) return { tahun: 0, bulan: 0, teks: 'belum mulai' }
  return { tahun: Math.floor(bln / 12), bulan: bln % 12, teks: `${Math.floor(bln / 12)} tahun ${bln % 12} bulan` }
}

/** Kolom templat impor. "alias" = judul lain yang juga dikenali dari daftar Excel lama. */
export const KOLOM_IMPOR = [
  { k: 'nama_lengkap', j: 'Nama lengkap bergelar', wajib: true, alias: ['nama', 'nama lengkap', 'nama pegawai', 'nama guru'] },
  { k: 'niy', j: 'NIY', alias: ['nomor induk yayasan', 'no induk', 'nip/niy'] },
  { k: 'jenis_kelamin', j: 'Jenis kelamin (L/P)', alias: ['jenis kelamin', 'jk', 'l/p', 'gender'] },
  { k: 'tempat_lahir', j: 'Tempat lahir', alias: ['tempat'] },
  { k: 'tanggal_lahir', j: 'Tanggal lahir (dd/mm/yyyy)', tanggal: true, alias: ['tanggal lahir', 'tgl lahir', 'tgl. lahir'] },
  { k: 'tmt_tugas', j: 'TMT tugas (dd/mm/yyyy)', tanggal: true, alias: ['tmt', 'tmt tugas', 'mulai tugas', 'tanggal mulai tugas'] },
  { k: 'status_kepegawaian', j: 'Status kepegawaian (Tetap/Kontrak/Honorer)', alias: ['status kepegawaian', 'status pegawai', 'status'] },
  { k: 'kategori_honorer', j: 'Kategori honorer (Lama/Baru)', alias: ['kategori honorer', 'honorer'] },
  { k: 'pendidikan_terakhir', j: 'Pendidikan terakhir (SD/SMP/SMA/S1/S1-LN/S2/S3)', alias: ['pendidikan terakhir', 'pendidikan', 'ijazah terakhir'] },
  { k: 'status_keluarga', j: 'Status keluarga (Menikah/Belum menikah/Cerai)', alias: ['status keluarga', 'status pernikahan', 'status perkawinan'] },
  { k: 'no_hp', j: 'Nomor HP', alias: ['no hp', 'no. hp', 'hp', 'nomor wa', 'no wa', 'whatsapp', 'telepon'] },
  { k: 'email', j: 'Email', alias: ['e-mail', 'alamat email'] },
  { k: 'unit', j: 'Bidang/Unit', alias: ['bidang', 'unit', 'bagian', 'unit kerja'] },
  { k: 'fungsional', j: 'Jabatan fungsional (pisahkan dengan koma)', alias: ['jabatan fungsional', 'tugas', 'tugas fungsional', 'jabatan'] },
  { k: 'struktural', j: 'Jabatan struktural', alias: ['jabatan struktural', 'jabatan pimpinan'] },
  { k: 'level_muhaffizh', j: 'Level muhaffizh (Pemula/Terampil/Mahir)', alias: ['level muhaffizh', 'level'] },
  { k: 'status_keaktifan', j: 'Status keaktifan (Aktif/Cuti panjang/Nonaktif/Keluar)', alias: ['status keaktifan', 'keaktifan'] },
]

/** Kenali judul kolom Excel (templat SIMKA atau daftar lama pondok). */
export function kenaliJudul(judul) {
  const t = bersih(judul).replace(/\s*\(.*\)\s*$/, '').replace(/[*:]/g, '').trim()
  for (const c of KOLOM_IMPOR) if (bersih(c.j).replace(/\s*\(.*\)\s*$/, '') === t || c.alias.includes(t)) return c.k
  return null
}
