// SIMKA PRO | src/lib/namaBerkas.js | v1.0 | Perbaikan: nama berkas cetak/PDF sesuai isi dokumen | 16/10/2026
// Peramban memakai judul halaman (document.title) sebagai nama berkas saat "Simpan sebagai PDF".
// Pola nama: "<Nama pegawai/santri atau bidang> - <Nama dokumen> - <Periode bulan>", mis.
//   "Ahmad Fauzan - Biodata Santri", "Bidang Tahfizh - Rekap Kehadiran Pegawai - Oktober 2026".
// Judul dipasang selama pratinjau/cetak lalu dikembalikan.
const BULAN = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember']

/** "Oktober 2026" dari tanggal (yyyy-mm-dd/Date) atau hari ini. */
export function periodeBulan(t = null) {
  const d = t ? new Date(typeof t === 'string' && t.length === 10 ? t + 'T00:00:00' : t) : new Date()
  return Number.isNaN(d.getTime()) ? '' : `${BULAN[d.getMonth()]} ${d.getFullYear()}`
}
/** Rentang tanggal → "Oktober 2026" atau "Juli–Oktober 2026" atau "Desember 2025–Januari 2026". */
export function periodeRentang(mulai, selesai) {
  if (!mulai) return periodeBulan(selesai)
  const a = periodeBulan(mulai); const b = periodeBulan(selesai || mulai)
  if (a === b) return a
  const [ba, ta] = a.split(' '); const [bb, tb] = b.split(' ')
  return ta === tb ? `${ba}–${bb} ${tb}` : `${a}–${b}`
}
const tglPanjang = (iso) => { const [t, b, h] = iso.split('-'); return `${Number(h)} ${BULAN[Number(b) - 1]} ${t}` }
/** Susun nama berkas dari bagian-bagian (yang kosong dilewati); karakter terlarang nama berkas dibuang. */
export function namaBerkas(...bagian) {
  const n = bagian.flat().map((x) => String(x ?? '').replace(/\s*\/\s*/g, '-').replace(/[\\:*?"<>|#%{}~&\n\r\t]+/g, ' ').replace(/\s+/g, ' ').trim()).filter(Boolean)
  const hasil = [...new Set(n)].join(' - ')
  return hasil.length > 150 ? hasil.slice(0, 150).trim() : hasil
}

let asli = null
/** Pasang judul halaman (nama berkas PDF) selama dokumen dipratinjau/dicetak. */
export function pasangJudul(nama) {
  if (!nama || typeof document === 'undefined') return
  if (asli === null) asli = document.title
  document.title = nama
}
export function lepasJudul() {
  if (asli !== null && typeof document !== 'undefined') { document.title = asli; asli = null }
}

const RE_TGL = new RegExp(`(?:(\\d{1,2})\\s+)?(${BULAN.join('|')})\\s+(\\d{4})`, 'g')
/**
 * Nama berkas bawaan dari judul dan subjudul dokumen: bagian subjudul yang bukan tanggal (bidang, kelas, kelompok, saringan)
 * diletakkan di depan, lalu judul, nomor, dan periode bulan yang diambil dari tanggal di subjudul (bila tidak ada: bulan cetak).
 * Contoh: judul "Rekap Kehadiran Pegawai", subjudul "01 Oktober 2026 s.d. 31 Oktober 2026 · Bidang Tahfizh"
 *         → "Bidang Tahfizh - Rekap Kehadiran Pegawai - Oktober 2026".
 */
export function namaDariJudul(judul, subjudul = '', nomor = '') {
  const tgl = []; const tglAngka = []; let berhari = false
  const subjek = String(subjudul || '').split(/\s+·\s+/).map((b) => {
    const sisa = b.replace(/\b(Senin|Selasa|Rabu|Kamis|Jumat|Sabtu|Ahad|Minggu),?\s*/g, '').replace(RE_TGL, (m, h, bln, th) => { if (h) berhari = true; tgl.push(`${th}-${String(BULAN.indexOf(bln) + 1).padStart(2, '0')}-${String(h || 1).padStart(2, '0')}`); return ' ' })
    return sisa.replace(/(\d{2})\/(\d{2})\/(\d{4})/g, (m, h, b, t) => { tglAngka.push(`${t}-${b}-${h}`); return ' ' })
      .replace(/s\.d\./gi, ' ').replace(/,?\s*pukul\s+[\d.:]+\s*(WITA)?/gi, ' ')
      .replace(/\b(keadaan per|keadaan|posisi per|periode|berlaku per|tarif berlaku per|bulan|dibayar|s\.d\.|sampai)\b/gi, ' ')
      .replace(/[,\s–-]+$/g, '').replace(/^[,\s–-]+/g, '').replace(/\s+/g, ' ').trim()
  }).filter((x) => x && x.length > 1 && !/^semua\b/i.test(x))
  const sumber = tgl.length ? tgl : tglAngka
  // Satu tanggal (laporan harian, keadaan per tanggal): tanggal lengkap; rentang: bulan; tanpa tanggal: bulan cetak
  const satuHari = tgl.length === 1 && berhari
  const periode = satuHari ? tglPanjang(tgl[0]) : sumber.length ? periodeRentang(sumber[0], sumber[sumber.length - 1]) : periodeBulan()
  return namaBerkas(subjek, judul, nomor, periode)
}

/** Subjek surat keluar untuk nama berkas: santri/pegawai pada isian surat, atau tujuan surat (baris pertama "Kepada"). */
export function subjekSurat(s = {}) {
  const v = Object.values(s.nilai || {})
  const orang = v.find((x) => x && !Array.isArray(x) && typeof x === 'object' && x.nama) || v.find((x) => Array.isArray(x) && x[0]?.nama)?.[0]
  return orang?.nama || String(s.kepada || '').split('\n')[0].trim()
}
