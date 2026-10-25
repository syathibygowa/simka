// SIMKA PRO | src/lib/nilai.js | v1.2 | 14.26.0: deskripsi capaian tertinggi/terendah dari ceklist TP | 25/10/2026
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

// ---------- 14.26.0: Capaian TP (ceklist guru mapel) ----------
const SAMBUNG = /\b(dalam|pada|mengenai|tentang|materi|memahami|menguasai|terhadap|yaitu)\s*:?$/i
/** "A", "A dan B", "A, B, dan C" */
export const daftarKata = (xs) => (xs.length <= 1 ? xs.join('') : xs.length === 2 ? `${xs[0]} dan ${xs[1]}` : `${xs.slice(0, -1).join(', ')}, dan ${xs[xs.length - 1]}`)
/** Kalimat predikat + daftar TP. Bila kalimat tidak diakhiri kata sambung (dalam/pada/mengenai …), disisipkan "terutama pada". */
export function kalimatTP(kalimat, tp) {
  const k = String(kalimat || '').trim().replace(/[.,;]+$/, '')
  if (!tp.length) return k ? `${k}.` : ''
  const isi = daftarKata(tp)
  const t = !k ? `Menguasai ${isi}` : SAMBUNG.test(k) ? `${k} ${isi}` : `${k}, terutama pada ${isi}`
  return t.charAt(0).toUpperCase() + t.slice(1) + '.'
}
/** Predikat terendah (nilai_min terkecil) dalam satu kelompok predikat. */
export const predikatTerendah = (predikat) => [...(predikat || [])].filter((p) => p.nilai_min != null).sort((a, b) => Number(a.nilai_min) - Number(b.nilai_min))[0] || null
/**
 * Deskripsi capaian dari ceklist TP (Kurikulum Merdeka): TP yang dicentang = capaian tertinggi (kalimat predikat nilai santri),
 * TP yang tidak dicentang = capaian terendah (kalimat predikat terendah, mis. D).
 *   capai null      → null (belum diceklist; pakai deskripsi otomatis lama)
 *   semua dicentang → hanya kalimat capaian tertinggi
 *   tidak ada       → hanya kalimat capaian terendah (semua TP perlu bimbingan)
 *   nilai berpredikat terendah → satu kalimat predikat terendah untuk semua TP
 * gabung: rapor Wustha (satu deskripsi untuk pengetahuan dan keterampilan).
 */
export function deskripsiCapaian(nilai, predikat, tp = [], capai = null, { gabung = false } = {}) {
  if (capai == null || nilai == null || nilai === '') return null
  const semua = tp.map((t) => t.teks || t).filter(Boolean)
  if (!semua.length) return null
  const set = new Set(capai); const tinggi = semua.filter((t) => set.has(t)); const rendah = semua.filter((t) => !set.has(t))
  const ganti = (t) => (gabung && /pengetahuan/i.test(t || '') && !/keterampilan/i.test(t || '') ? t.replace(/pengetahuan/i, 'pengetahuan dan keterampilan') : t)
  const p = predikatDari(nilai, predikat); const d = predikatTerendah(predikat)
  // Nilai sudah berpredikat terendah: satu kalimat saja untuk semua TP (tidak mengulang kalimat yang sama)
  if (p && d && p.huruf === d.huruf) return kalimatTP(ganti(p.deskripsi), semua)
  return [tinggi.length ? kalimatTP(ganti(p?.deskripsi), tinggi) : '', rendah.length ? kalimatTP(ganti(d?.deskripsi), rendah) : ''].filter(Boolean).join(' ')
}

export const LABEL_SEMESTER = { 1: 'Semester 1 (Ganjil)', 2: 'Semester 2 (Genap)' }
