// SIMKA PRO | src/lib/alumni.js | v1.0 | 14.25.0: label dan bantuan menu Alumni | 25/10/2026
// Pilihan rencana lanjut studi alumni (sama dengan batasan tabel alumni_profiles) dan bantuan teks.
export const LANJUT = {
  kuliah: { n: 'Kuliah', w: 'rapor' },
  pesantren: { n: 'Pesantren/ma\'had', w: 'tahfizh' },
  pengabdian: { n: 'Pengabdian', w: 'musyrif' },
  kerja: { n: 'Bekerja', w: 'gaji' },
  wirausaha: { n: 'Wirausaha', w: 'prestasi' },
  lainnya: { n: 'Lainnya', w: 'audit' },
}
export const JENIS_PT = { negeri: 'Negeri (PTN)', ptkin: 'Keagamaan Islam Negeri (PTKIN)', swasta: 'Swasta (PTS)', kedinasan: 'Kedinasan', luar_negeri: 'Luar negeri' }
export const STATUS_DAFTAR = {
  rencana: { n: 'Rencana', w: 'audit' },
  mendaftar: { n: 'Mendaftar', w: 'agenda' },
  diterima: { n: 'Diterima', w: 'presensi' },
  tidak_diterima: { n: 'Tidak diterima', w: 'klinik' },
  berjalan: { n: 'Sedang menjalani', w: 'rapor' },
}
export const JENIS_KELOMPOK_ALUMNI = { kelas: 'Kelas', halaqah: 'Halaqah', kamar: 'Kamar', ekskul: 'Ekskul' }
export const JENIS_SERTIFIKAT = { sertifikat_hafalan: 'Sertifikat hafalan', sertifikat_tahfizh: 'Sertifikat tahfizh', sertifikat_khataman: 'Sertifikat khataman' }

/** Ringkasan rencana studi satu baris: "Kuliah · UIN Alauddin Makassar · Hukum Keluarga Islam". */
export function ringkasStudi(a) {
  if (!a?.lanjut) return ''
  return [LANJUT[a.lanjut]?.n, a.kampus, a.prodi || a.fakultas].filter(Boolean).join(' · ')
}
/** Isian profil alumni dianggap lengkap bila rencana lanjut dan tujuan (kampus/lembaga) terisi. */
export const profilLengkap = (a) => !!(a?.lanjut && a?.kampus)
/** Kelompokkan riwayat [{ ta, jenis, nama, pengasuh }] per tahun ajaran → [{ ta, kelas, halaqah, kamar, ekskul }]. */
export function riwayatPerTA(riwayat = []) {
  const peta = new Map()
  for (const r of riwayat) {
    if (!peta.has(r.ta)) peta.set(r.ta, { ta: r.ta, ta_mulai: r.ta_mulai, kelas: [], halaqah: [], kamar: [], ekskul: [] })
    peta.get(r.ta)[r.jenis]?.push(r)
  }
  return [...peta.values()].sort((a, b) => String(a.ta_mulai).localeCompare(String(b.ta_mulai)))
}
/** Rentang tanggal tahun ajaran dari nama "2025/2026" (1 Juli – 30 Juni) untuk membuka Rekam Kesantrian. */
export function rentangTA(nama, mulai) {
  const th = Number(String(mulai || nama || '').slice(0, 4))
  return th ? { mulai: mulai || `${th}-07-01`, selesai: `${th + 1}-06-30` } : null
}
