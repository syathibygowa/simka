// SIMKA PRO | src/lib/nilai.js | v1.1 | 14.3.0: komponen Kehadiran (otomatis dari absensi pelajaran) | 17/10/2026
// Hitung nilai guru mapel di aplikasi (sama dengan fungsi SQL nilai_akumulasi): rata-rata setiap komponen aktif ×
// bobot, bobot dinormalkan atas komponen yang sudah berisi; serta deskripsi capaian otomatis dari predikat.
// v1.1: komponen bersumber 'kehadiran' memakai persentase kehadiran pelajaran santri (kehadiran: { [santriId]: { persen, p } }).
import { predikatDari, bulatkan } from './penilaian'

/** skor: Map kunci `${kolom}|${santri}` → nilai. Mengembalikan { nilai, lengkap } untuk satu santri dan aspek. */
export function hitungAkumulasi({ kategori, kolom, skor, santriId, aspek = 'pengetahuan', desimal = 0, kehadiran = {} }) {
  const kat = kategori.filter((k) => k.aktif && k.aspek === aspek && Number(k.bobot) > 0)
  let jumlah = 0; let bobot = 0; let terisi = 0
  for (const k of kat) {
    const h = kehadiran[santriId]
    const v = k.sumber === 'kehadiran' ? (h && h.p > 0 && h.persen != null ? [Number(h.persen)] : [])
      : kolom.filter((c) => c.category_id === k.id).map((c) => skor.get(`${c.id}|${santriId}`)).filter((x) => x != null && x !== '')
    if (!v.length) continue
    const rata = v.reduce((a, b) => a + Number(b), 0) / v.length
    jumlah += rata * Number(k.bobot); bobot += Number(k.bobot); terisi++
  }
  if (!bobot) return { nilai: null, lengkap: false }
  return { nilai: bulatkan(jumlah / bobot, desimal), lengkap: terisi === kat.length }
}

/** Deskripsi capaian otomatis: kalimat predikat (+ daftar TP untuk rapor SMA). aspek keterampilan memakai deskripsi_2. */
export function deskripsiOtomatis(nilai, predikat, { tp = [], pakaiTp = false, keterampilan = false } = {}) {
  const p = predikatDari(nilai, predikat)
  if (!p) return ''
  const kalimat = (keterampilan ? p.deskripsi_2 : p.deskripsi) || ''
  if (!pakaiTp || !tp.length) return kalimat
  return `${kalimat} ${tp.map((t) => t.teks || t).join(', ')}`.trim()
}

export const LABEL_SEMESTER = { 1: 'Semester 1 (Ganjil)', 2: 'Semester 2 (Genap)' }
