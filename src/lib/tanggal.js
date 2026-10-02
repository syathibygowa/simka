// Format tanggal dan jam baku Indonesia (zona WITA, Asia/Makassar).
// dd/mm/yyyy  → formatPendek     dd mmmm yyyy → formatPanjang
export const ZONA = 'Asia/Makassar'
export const BULAN = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli',
  'Agustus', 'September', 'Oktober', 'November', 'Desember']
export const HARI = ['Ahad', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu']

let selisihServer = 0 // ms; diisi dari fungsi waktu_server() agar jam tidak bergantung jam HP
export const aturSelisihServer = (isoServer) => { selisihServer = new Date(isoServer).getTime() - Date.now() }
export const sekarang = () => new Date(Date.now() + selisihServer)

const bagian = (d) => {
  const f = new Intl.DateTimeFormat('en-GB', {
    timeZone: ZONA, year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23', weekday: 'short',
  }).formatToParts(d)
  const o = Object.fromEntries(f.map((p) => [p.type, p.value]))
  const hariKe = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].indexOf(o.weekday)
  return { y: +o.year, m: +o.month, d: +o.day, jam: o.hour, menit: o.minute, detik: o.second, hariKe }
}

const keDate = (v) => {
  if (!v) return null
  if (v instanceof Date) return v
  if (/^\d{4}-\d{2}-\d{2}$/.test(v)) { const [y, m, d] = v.split('-').map(Number); return new Date(Date.UTC(y, m - 1, d, 4)) } // 12.00 WITA
  return new Date(v)
}
const dua = (n) => String(n).padStart(2, '0')

/** yyyy-mm-dd hari ini (WITA) — nilai bawaan kolom tanggal */
export function hariIniISO() { const b = bagian(sekarang()); return `${b.y}-${dua(b.m)}-${dua(b.d)}` }
/** HH:MM saat ini — nilai bawaan kolom jam */
export function jamSekarang(detik = false) { const b = bagian(sekarang()); return detik ? `${b.jam}:${b.menit}:${b.detik}` : `${b.jam}:${b.menit}` }

/** 03/10/2026 */
export function formatPendek(v) { const d = keDate(v); if (!d || isNaN(d)) return '–'; const b = bagian(d); return `${dua(b.d)}/${dua(b.m)}/${b.y}` }
/** 03 Oktober 2026 */
export function formatPanjang(v) { const d = keDate(v); if (!d || isNaN(d)) return '–'; const b = bagian(d); return `${dua(b.d)} ${BULAN[b.m - 1]} ${b.y}` }
/** Sabtu, 03 Oktober 2026 */
export function formatHari(v) { const d = keDate(v); if (!d || isNaN(d)) return '–'; return `${HARI[bagian(d).hariKe]}, ${formatPanjang(d)}` }
/** 07.30 (titik sebagai pemisah jam baku) */
export function formatJam(v, detik = false) {
  const d = keDate(v); if (!d || isNaN(d)) return '–'; const b = bagian(d)
  return detik ? `${b.jam}.${b.menit}.${b.detik}` : `${b.jam}.${b.menit}`
}
/** 03/10/2026 07.30 */
export const formatWaktu = (v) => `${formatPendek(v)} ${formatJam(v)}`

/** "baru saja", "5 menit lalu", "kemarin 14.20", atau tanggal pendek */
export function formatRelatif(v) {
  const d = keDate(v); if (!d) return ''
  const s = Math.round((sekarang() - d) / 1000)
  if (s < 60) return 'baru saja'
  if (s < 3600) return `${Math.floor(s / 60)} menit lalu`
  if (s < 86400 && formatPendek(d) === formatPendek(sekarang())) return `${Math.floor(s / 3600)} jam lalu`
  const kemarin = new Date(sekarang().getTime() - 86400000)
  if (formatPendek(d) === formatPendek(kemarin)) return `kemarin ${formatJam(d)}`
  return formatPendek(d)
}

/** Ubah ketikan dd/mm/yyyy menjadi yyyy-mm-dd; null bila tidak sah */
export function uraiPendek(teks) {
  const m = /^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})$/.exec((teks || '').trim())
  if (!m) return null
  const [d, b, y] = [+m[1], +m[2], +m[3]]
  const t = new Date(Date.UTC(y, b - 1, d))
  if (t.getUTCFullYear() !== y || t.getUTCMonth() !== b - 1 || t.getUTCDate() !== d) return null
  return `${y}-${dua(b)}-${dua(d)}`
}

/** Tanggal Hijriah (kalender Ummul Qura bawaan peramban); koreksi hari dari Pengaturan */
export function formatHijriah(v = sekarang(), koreksiHari = 0) {
  try {
    const d = new Date(keDate(v).getTime() + koreksiHari * 86400000)
    const t = new Intl.DateTimeFormat('id-ID-u-ca-islamic-umalqura', { timeZone: ZONA, day: 'numeric', month: 'long', year: 'numeric' }).format(d)
    return t.replace(/\s?(SH|AH|H)$/, '') + ' H'
  } catch { return '' }
}

/** Salam sesuai waktu WITA */
export function salamWaktu() {
  const j = +bagian(sekarang()).jam
  if (j < 11) return 'Selamat pagi'
  if (j < 15) return 'Selamat siang'
  if (j < 18) return 'Selamat sore'
  return 'Selamat malam'
}

// Nama pendek untuk modul Excel
export const tglPendek = formatPendek
export const dariPendek = uraiPendek
