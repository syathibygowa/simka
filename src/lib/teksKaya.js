// SIMKA PRO | src/lib/teksKaya.js | v2.0 | Perbaikan 13.8.0: garis bawah, daftar bernomor, daftar simbol, penomoran otomatis | 16/10/2026
// Format sederhana mengikuti kebiasaan WhatsApp sehingga tetap rapi saat dibagikan lewat WA:
//   *teks tebal*   _teks miring_   __teks bergaris bawah__   (boleh digabung: *_tebal miring_*)
//   Baris berawalan "1. " / "a. " = daftar bernomor; "- " atau "• " = daftar simbol (WhatsApp juga mengenali keduanya).
//   Baris baru dipertahankan.
// Teks selalu di-escape lebih dulu sebelum diubah menjadi HTML, sehingga aman ditampilkan dengan v-html.
// Penanda gaya hanya dikenali bila menempel pada kata (tidak diawali/diakhiri spasi) dan tidak melewati baris baru,
// sehingga tanda bintang atau garis bawah biasa (mis. pada alamat surel atau tautan) tidak ikut berubah.

const escape = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;')
const pola = (t) => {
  const e = t.replace(/[*_]/g, '\\$&'); const c = t[0] === '*' ? '*' : '_'
  return new RegExp(`(^|[\\s(\\[{"'>])${e}([^\\s${c}](?:[^${c}\\n]*?[^\\s${c}])?)${e}(?=$|[\\s.,;:!?)\\]}"'<])`, 'gm')
}
const GARIS = pola('__'); const TEBAL = pola('*'); const MIRING = pola('_')
/** Penanda butir daftar di awal baris: 1. 1) a. a) (bernomor) atau - • * (simbol), diikuti spasi. */
export const RE_BUTIR = /^([ \t]*)(\d{1,3}[.)]|[a-z][.)]|[-•*])[ \t]+(.*)$/

const gayaSebaris = (h) => h.replace(GARIS, '$1<u>$2</u>').replace(TEBAL, '$1<strong>$2</strong>').replace(MIRING, '$1<em>$2</em>')

/**
 * Teks berpenanda → HTML aman (tebal <strong>, miring <em>, garis bawah <u>, butir daftar dengan indentasi gantung).
 * Wadah tampilan memakai CSS white-space: pre-line (baris baru dipertahankan). Butir daftar berupa blok sehingga
 * baris barunya sendiri tidak ikut dicetak (agar tidak muncul baris kosong ganda).
 */
export function teksKaya(s, { daftar = true } = {}) {
  const html = gayaSebaris(escape(s))
  if (!daftar) return html
  const baris = html.split('\n'); let out = ''
  baris.forEach((b, i) => {
    const m = RE_BUTIR.exec(b)
    if (m) {
      const tingkat = Math.min(4, Math.floor(m[1].replace(/\t/g, '  ').length / 2))
      const tanda = /^[-•*]$/.test(m[2]) ? '•' : m[2]
      out += `<span class="tk-butir" style="--tk-i:${tingkat}"><span class="tk-tanda">${tanda}</span><span class="tk-isi">${m[3]}</span></span>`
    } else {
      out += b
      if (i < baris.length - 1 && !RE_BUTIR.test(baris[i + 1])) out += '\n'
      else if (i < baris.length - 1 && b.trim() === '') out += '\n'
    }
  })
  return out
}

/** Teks berpenanda → teks polos tanpa penanda gaya (untuk cuplikan, pencarian, dan notifikasi). */
export function teksPolos(s) {
  return String(s ?? '').replace(GARIS, '$1$2').replace(TEBAL, '$1$2').replace(MIRING, '$1$2')
}
/** Teks untuk WhatsApp: WhatsApp tidak mengenal garis bawah, jadi penandanya dilepas; tebal/miring/daftar tetap. */
export function teksWA(s) {
  return String(s ?? '').replace(GARIS, '$1$2')
}

/** Penomoran ulang otomatis: setiap rangkaian butir bernomor angka pada tingkat yang sama diurutkan 1, 2, 3, … */
export function nomoriUlang(nilai) {
  const baris = nilai.split('\n'); const hitung = {}
  for (let i = 0; i < baris.length; i++) {
    const m = /^([ \t]*)(\d{1,3})([.)])([ \t]+.*)?$/.exec(baris[i])
    if (!m) { if (!RE_BUTIR.test(baris[i])) for (const k of Object.keys(hitung)) delete hitung[k]; continue }
    const ind = m[1]
    for (const k of Object.keys(hitung)) if (k.length > ind.length) delete hitung[k]   // keluar dari sub-daftar
    hitung[ind] = (hitung[ind] || 0) + 1
    baris[i] = `${ind}${hitung[ind]}${m[3]}${m[4] || ' '}`
  }
  return baris.join('\n')
}

/**
 * Bungkus/lepas penanda pada pilihan teks di <textarea>.
 * jenis: 'tebal' | 'miring' | 'garis' | 'normal' (melepas semua penanda di pilihan) | 'nomor' | 'simbol'.
 * Mengembalikan { nilai, awal, akhir }.
 */
export function terapkanGaya(nilai, awal, akhir, jenis) {
  if (jenis === 'nomor' || jenis === 'simbol') return terapkanDaftar(nilai, awal, akhir, jenis)
  let a = awal; let b = akhir
  // Pilihan kosong: ambil kata di sekitar kursor
  if (a === b) {
    while (a > 0 && !/\s/.test(nilai[a - 1])) a--
    while (b < nilai.length && !/\s/.test(nilai[b])) b++
  }
  // Abaikan spasi di tepi pilihan
  while (a < b && /\s/.test(nilai[a])) a++
  while (b > a && /\s/.test(nilai[b - 1])) b--
  const pilih = nilai.slice(a, b)
  if (jenis === 'normal') {
    const polos = pilih.replace(/[*_]/g, '')
    let kiri = a; let kanan = b
    while (kiri > 0 && /[*_]/.test(nilai[kiri - 1]) && /[*_]/.test(nilai[kanan] || '')) { kiri--; kanan++ }
    return { nilai: nilai.slice(0, kiri) + polos + nilai.slice(kanan), awal: kiri, akhir: kiri + polos.length }
  }
  const t = jenis === 'tebal' ? '*' : jenis === 'garis' ? '__' : '_'; const n = t.length
  if (!pilih) {
    const isi = nilai.slice(0, a) + t + t + nilai.slice(b)
    return { nilai: isi, awal: a + n, akhir: a + n }
  }
  // Sudah berpenanda → lepas (tombol berfungsi sebagai sakelar)
  const berpenanda = (x) => x.length > 2 * n && x.startsWith(t) && x.endsWith(t) && (n === 2 || !(x.startsWith('__') && x.endsWith('__')))
  if (berpenanda(pilih)) {
    const isi = pilih.slice(n, -n)
    return { nilai: nilai.slice(0, a) + isi + nilai.slice(b), awal: a, akhir: a + isi.length }
  }
  if (nilai.slice(a - n, a) === t && nilai.slice(b, b + n) === t && (n === 2 || (nilai[a - 2] !== '_' && nilai[b + 1] !== '_') || t === '*')) {
    return { nilai: nilai.slice(0, a - n) + pilih + nilai.slice(b + n), awal: a - n, akhir: b - n }
  }
  // Penanda per baris agar tidak melewati baris baru; penanda daftar di awal baris tetap di luar
  const isi = pilih.split('\n').map((l) => {
    if (!l.trim()) return l
    const m = RE_BUTIR.exec(l); const depan = m ? l.slice(0, l.length - m[3].length) : ''
    const inti = m ? m[3] : l
    return depan + inti.replace(/^(\s*)(.*?)(\s*)$/, `$1${t}$2${t}$3`)
  }).join('\n')
  return { nilai: nilai.slice(0, a) + isi + nilai.slice(b), awal: a, akhir: a + isi.length }
}

/** Jadikan/lepas daftar pada baris-baris yang dipilih (atau baris kursor). */
function terapkanDaftar(nilai, awal, akhir, jenis) {
  const mulai = nilai.lastIndexOf('\n', awal - 1) + 1
  let selesai = nilai.indexOf('\n', Math.max(awal, akhir - (akhir > awal && nilai[akhir - 1] === '\n' ? 1 : 0)))
  if (selesai < 0) selesai = nilai.length
  const baris = nilai.slice(mulai, selesai).split('\n')
  const sudah = (l) => { const m = RE_BUTIR.exec(l); return m && (jenis === 'nomor' ? /^\d/.test(m[2]) : /^[-•*]$/.test(m[2])) }
  const isiBaris = baris.filter((l) => l.trim())
  const lepas = isiBaris.length && isiBaris.every(sudah)
  let no = 0
  const hasil = baris.map((l) => {
    if (!l.trim() && baris.length > 1) return l
    const m = RE_BUTIR.exec(l); const ind = m ? m[1] : (/^[ \t]*/.exec(l)[0]); const inti = m ? m[3] : l.trim()
    if (lepas) return ind + inti
    no++
    return `${ind}${jenis === 'nomor' ? `${no}.` : '-'} ${inti}`
  }).join('\n')
  const isi = nomoriUlang(nilai.slice(0, mulai) + hasil + nilai.slice(selesai))
  const geser = isi.length - nilai.length
  return { nilai: isi, awal: baris.length === 1 && !lepas ? selesai + geser : mulai, akhir: selesai + geser }
}

/**
 * Tekan Enter di dalam butir daftar: lanjutkan dengan penanda berikutnya (nomor +1 atau simbol yang sama).
 * Enter pada butir kosong mengakhiri daftar. Mengembalikan { nilai, kursor } atau null bila bukan butir daftar.
 */
export function enterDaftar(nilai, kursor) {
  const mulai = nilai.lastIndexOf('\n', kursor - 1) + 1
  const baris = nilai.slice(mulai, kursor)
  const m = RE_BUTIR.exec(baris)
  if (!m) return null
  if (!m[3].trim()) {   // butir kosong → akhiri daftar
    const isi = nilai.slice(0, mulai) + m[1] + nilai.slice(kursor)
    return { nilai: isi, kursor: mulai + m[1].length }
  }
  let tanda = m[2]
  const angka = /^(\d+)([.)])$/.exec(tanda); const huruf = /^([a-z])([.)])$/.exec(tanda)
  if (angka) tanda = `${Number(angka[1]) + 1}${angka[2]}`
  else if (huruf) tanda = `${String.fromCharCode(Math.min(122, huruf[1].charCodeAt(0) + 1))}${huruf[2]}`
  const sisip = `\n${m[1]}${tanda} `
  let isi = nilai.slice(0, kursor) + sisip + nilai.slice(kursor)
  const pos = kursor + sisip.length
  if (!angka) return { nilai: isi, kursor: pos }
  // Butir sesudahnya ikut dinomori ulang; kursor tetap di akhir penanda baris baru
  const ke = isi.slice(0, pos).split('\n').length - 1
  isi = nomoriUlang(isi)
  const b = isi.split('\n')
  const mb = RE_BUTIR.exec(b[ke]) || /^(\s*\d+[.)] )()()(.*)$/.exec(b[ke])
  const panjangTanda = mb ? b[ke].length - (mb[3] || '').length : b[ke].length
  return { nilai: isi, kursor: b.slice(0, ke).reduce((t, x) => t + x.length + 1, 0) + panjangTanda }
}
