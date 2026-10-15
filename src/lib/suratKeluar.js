// SIMKA PRO | src/lib/suratKeluar.js | v1.3 | Tahap C: isian santri orang tua, hafalan, tanggal masuk; opsi kotak pas foto | 16/10/2026
// Mesin template surat keluar (template sistem, bukan Word). Isi template ditulis sebagai teks biasa:
//   {kunci}, {kunci.bagian}   isian (lihat ISIAN_GLOBAL dan isian template), mis. {santri.nama}, {pegawai.jabatan}, {lembaga}
//   *tebal*  _miring_          gaya teks (seperti WhatsApp)
//   baris kosong               paragraf baru
//   Label : nilai              baris berjajar (spasi sebelum titik dua), mis. "Hari/tanggal : {hari_tanggal}"
//   1. … / a. … / - …          daftar bernomor, berhuruf, atau berpoin
//   | sel | sel |              tabel; baris |---|---| di bawah baris pertama menjadikannya kepala tabel
//   == teks                    paragraf rata tengah, mis. "== *MEMUTUSKAN*"
// Isian jenis daftar/daftar pegawai yang berdiri sendiri pada satu baris (atau sebagai nilai baris berjajar) tampil
// sebagai daftar bernomor/tabel; di tengah kalimat tampil dipisah koma. Semua teks di-escape sebelum menjadi HTML.
import { teksKaya } from './teksKaya'
import { formatPanjang, formatHari } from './tanggal'

/** Salam, basmalah, hamdalah, dan doa ditulis dengan huruf Latin dan dicetak miring (istilah bahasa asing). */
export const LAFAZ = {
  basmalah: 'Bismillahirrahmanirrahim',
  salam: "Assalamu'alaikum warahmatullahi wabarakatuh",
  hamdalah: "Alhamdulillahi rabbil 'alamin, washshalatu wassalamu 'ala rasulillah",
  doa: 'Jazakumullahu khairan',
  salam_penutup: "Wassalamu'alaikum warahmatullahi wabarakatuh",
}
export const OPSI_SURAT = [
  { k: 'basmalah', n: 'Basmalah di atas surat' }, { k: 'salam', n: 'Salam pembuka' }, { k: 'hamdalah', n: 'Hamdalah sesudah salam' },
  { k: 'doa', n: 'Doa jazakumullahu khairan' }, { k: 'salam_penutup', n: 'Salam penutup' }, { k: 'tembusan', n: 'Tembusan' },
  { k: 'narahubung', n: 'Narahubung' }, { k: 'ditetapkan', n: '"Ditetapkan di … pada tanggal …" (SK)' }, { k: 'pas_foto', n: 'Kotak pas foto 3 × 4 di samping tanda tangan' },
]
export const JENIS_ISIAN = [
  { k: 'teks', n: 'Teks singkat' }, { k: 'panjang', n: 'Teks panjang' }, { k: 'tanggal', n: 'Tanggal' }, { k: 'hari_tanggal', n: 'Hari dan tanggal' },
  { k: 'jam', n: 'Jam' }, { k: 'angka', n: 'Angka' }, { k: 'pegawai', n: 'Pilih pegawai' }, { k: 'santri', n: 'Pilih santri' },
  { k: 'daftar', n: 'Daftar butir' }, { k: 'daftar_pegawai', n: 'Daftar pegawai (tabel)' },
]
export const KATEGORI_TEMPLATE = { umum: { n: 'Umum', w: 'tatausaha' }, pegawai: { n: 'Kepegawaian', w: 'pegawai' }, santri: { n: 'Kesantrian', w: 'santri' } }
export const FORMAT_NOMOR = [{ k: 'surat', n: 'Surat (urutan bersama D/K)' }, { k: 'sk', n: 'Surat Keputusan (urutan sendiri)' }]
export const STATUS_KELUAR = {
  draf: { n: 'Draf', w: 'hakakses' }, diperiksa: { n: 'Diperiksa TU', w: 'pengajuan' }, menunggu_ttd: { n: 'Menunggu tanda tangan', w: 'shift' },
  terbit: { n: 'Terbit', w: 'presensi' }, ditolak: { n: 'Ditolak', w: 'klinik' }, dibatalkan: { n: 'Dibatalkan', w: 'sistem' }, dicabut: { n: 'Dicabut', w: 'klinik' },
  direvisi: { n: 'Direvisi', w: 'pengajuan' },
}
/** Isian yang selalu tersedia di setiap template. */
export const ISIAN_GLOBAL = [
  { k: 'lembaga', n: 'Nama lengkap lembaga' }, { k: 'lembaga.alamat', n: 'Alamat lembaga' }, { k: 'lembaga.npsn', n: 'NPSN' }, { k: 'lembaga.nspp', n: 'NSPP' },
  { k: 'lembaga.kota', n: 'Kota surat' }, { k: 'tahun_ajaran', n: 'Tahun ajaran aktif' }, { k: 'tanggal_surat', n: 'Tanggal surat (Masehi)' },
  { k: 'tanggal_hijriah', n: 'Tanggal surat (Hijriah)' }, { k: 'nomor', n: 'Nomor surat' }, { k: 'perihal', n: 'Perihal' },
  { k: 'penanda.nama', n: 'Nama penanda tangan pertama' }, { k: 'penanda.jabatan', n: 'Jabatan penanda tangan pertama' }, { k: 'penanda.niy', n: 'NIY penanda tangan pertama' },
]
export const BAGIAN_PEGAWAI = ['nama', 'niy', 'jabatan', 'unit']
export const BAGIAN_SANTRI = ['nama', 'nis', 'nisn', 'ttl', 'jk', 'kelas', 'jenjang', 'wali', 'alamat', 'orang_tua', 'ayah', 'ibu', 'hafalan', 'tanggal_masuk']

const escape = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;')
const JENJANG = { wustha: 'Kesetaraan Wustha', sma: 'SMA' }
export const ttlSantri = (s) => [s?.tempat_lahir, s?.tanggal_lahir ? formatPanjang(s.tanggal_lahir) : ''].filter(Boolean).join(', ')

/** Nilai bawaan isian template untuk surat baru. */
export function nilaiAwal(isian = [], hariIni = '') {
  const v = {}
  for (const i of isian) {
    if (i.jenis === 'daftar') v[i.kunci] = i.bawaan ? String(i.bawaan).split('\n') : ['']
    else if (i.jenis === 'daftar_pegawai') v[i.kunci] = []
    else if (i.jenis === 'pegawai' || i.jenis === 'santri') v[i.kunci] = null
    else if (i.jenis === 'tanggal' || i.jenis === 'hari_tanggal') v[i.kunci] = i.bawaan || hariIni
    else if (i.jenis === 'jam') v[i.kunci] = i.bawaan || ''
    else v[i.kunci] = i.bawaan || ''
  }
  return v
}

/**
 * Susun peta isian. Hasil: { teks: {kunci: string}, blok: {kunci: {jenis, gaya, butir}} }.
 * k = { nilai, isian, lembaga (konteks_surat), penanda [{nama, jabatan, niy}], tanggal_surat, tanggal_hijriah, nomor, perihal }
 */
export function susunKonteks(k) {
  const t = {}; const blok = {}
  const L = k.lembaga || {}
  Object.assign(t, { lembaga: L.lembaga, 'lembaga.alamat': L.alamat, 'lembaga.npsn': L.npsn, 'lembaga.nspp': L.nspp, 'lembaga.kota': L.kota,
    tahun_ajaran: L.tahun_ajaran, tanggal_surat: k.tanggal_surat ? formatPanjang(k.tanggal_surat) : '', tanggal_hijriah: k.tanggal_hijriah, nomor: k.nomor, perihal: k.perihal })
  ;(k.penanda || []).forEach((p, i) => { const a = i ? `penanda${i + 1}` : 'penanda'; t[`${a}.nama`] = p?.nama; t[`${a}.jabatan`] = p?.jabatan; t[`${a}.niy`] = p?.niy })
  for (const i of k.isian || []) {
    const v = (k.nilai || {})[i.kunci]
    switch (i.jenis) {
      case 'tanggal': t[i.kunci] = v ? formatPanjang(v) : ''; break
      case 'hari_tanggal': t[i.kunci] = v ? formatHari(v) : ''; break
      case 'jam': t[i.kunci] = v ? String(v).slice(0, 5).replace(':', '.') : ''; break
      case 'pegawai':
        t[i.kunci] = v?.nama || ''
        for (const b of BAGIAN_PEGAWAI) t[`${i.kunci}.${b}`] = v?.[b] || ''
        break
      case 'santri':
        t[i.kunci] = v?.nama || ''
        Object.assign(t, { [`${i.kunci}.nama`]: v?.nama, [`${i.kunci}.nis`]: v?.nis, [`${i.kunci}.nisn`]: v?.nisn, [`${i.kunci}.ttl`]: v ? ttlSantri(v) : '',
          [`${i.kunci}.jk`]: v ? (v.jk === 'P' ? 'Perempuan' : 'Laki-laki') : '', [`${i.kunci}.kelas`]: v?.kelas, [`${i.kunci}.jenjang`]: JENJANG[v?.jenjang] || '',
          [`${i.kunci}.wali`]: v?.wali, [`${i.kunci}.alamat`]: v?.alamat, [`${i.kunci}.ayah`]: v?.ayah, [`${i.kunci}.ibu`]: v?.ibu,
          [`${i.kunci}.orang_tua`]: v ? ([v.ayah, v.ibu].filter(Boolean).join(' / ') || v.wali) : '',
          [`${i.kunci}.hafalan`]: v && v.hafalan != null ? `${String(v.hafalan).replace('.', ',')} juz` : '',
          [`${i.kunci}.tanggal_masuk`]: v?.tanggal_masuk ? formatPanjang(v.tanggal_masuk) : '' })
        break
      case 'daftar': {
        const butir = (Array.isArray(v) ? v : String(v || '').split('\n')).map((x) => String(x).trim()).filter(Boolean)
        t[i.kunci] = butir.join(', '); blok[i.kunci] = { jenis: 'daftar', gaya: i.gaya || 'angka', butir }; break
      }
      case 'daftar_pegawai': {
        const butir = (Array.isArray(v) ? v : []).filter(Boolean)
        t[i.kunci] = butir.map((p) => p.nama).join(', '); blok[i.kunci] = { jenis: 'daftar_pegawai', butir }; break
      }
      default: t[i.kunci] = v == null ? '' : String(v)
    }
  }
  return { teks: t, blok, label: Object.fromEntries((k.isian || []).map((i) => [i.kunci, i.label])) }
}

/** Ganti {kunci} pada satu baris. mode 'pratinjau' menandai isian kosong; 'final' mengosongkan dengan titik-titik. */
function sebaris(baris, ktx, mode) {
  return teksKaya(baris).replace(/\{([a-z][a-z0-9_]*(?:\.[a-z0-9_]+)?)\}/g, (m, kunci) => {
    const v = ktx.teks[kunci]
    if (v != null && String(v).trim() !== '') return teksKaya(String(v)).replace(/\n/g, '<br>')
    if (mode === 'final') return '…'
    const akar = kunci.split('.')[0]
    return `<span class="isian-kosong">[${escape(ktx.label[akar] ? ktx.label[akar] + (kunci.includes('.') ? ' – ' + kunci.split('.')[1] : '') : kunci)}]</span>`
  })
}
function htmlBlok(b, mode) {
  if (b.jenis === 'daftar') {
    if (!b.butir.length) return mode === 'final' ? '' : '<p><span class="isian-kosong">[daftar kosong]</span></p>'
    if (b.gaya === 'poin') return `<ul>${b.butir.map((x) => `<li>${teksKaya(x)}</li>`).join('')}</ul>`
    return `<ol type="${b.gaya === 'huruf' ? 'a' : '1'}">${b.butir.map((x) => `<li>${teksKaya(x)}</li>`).join('')}</ol>`
  }
  if (!b.butir.length) return mode === 'final' ? '' : '<p><span class="isian-kosong">[daftar pegawai kosong]</span></p>'
  return `<table class="tabel isi-tabel"><colgroup><col style="width:8%"><col style="width:40%"><col style="width:20%"><col style="width:32%"></colgroup>
    <thead><tr><th>No.</th><th>Nama</th><th>NIY</th><th>Jabatan</th></tr></thead><tbody>${b.butir.map((p, i) =>
    `<tr><td class="tengah">${i + 1}.</td><td>${escape(p.nama)}</td><td>${escape(p.niy || '–')}</td><td>${escape(p.jabatan || '')}</td></tr>`).join('')}</tbody></table>`
}
const blokSendiri = (s, ktx) => { const m = /^\{([a-z][a-z0-9_]*)\}$/.exec(s.trim()); return m && ktx.blok[m[1]] ? ktx.blok[m[1]] : null }
const RE_SEJAJAR = /^([^:|\n]{1,40}?)\s+:\s*(.*)$/

/** Isi template → HTML. */
export function renderIsi(teks, ktx, mode = 'pratinjau') {
  const baris = String(teks || '').replace(/\r/g, '').split('\n')
  const out = []; let i = 0
  while (i < baris.length) {
    const b = baris[i]
    if (!b.trim()) { i++; continue }
    if (/^==\s+/.test(b)) { out.push(`<p class="tengah-p">${sebaris(b.replace(/^==\s+/, ''), ktx, mode)}</p>`); i++; continue }
    if (/^\s*\|/.test(b)) {
      const rows = []; while (i < baris.length && /^\s*\|/.test(baris[i])) rows.push(baris[i++])
      const sel = (r) => r.trim().replace(/^\|/, '').replace(/\|$/, '').split('|').map((c) => c.trim())
      let kepala = null; let isi = rows.map(sel)
      if (isi.length > 1 && isi[1].every((c) => /^:?-{3,}:?$/.test(c))) { kepala = isi[0]; isi = isi.slice(2) }
      out.push(`<table class="tabel isi-tabel">${kepala ? `<thead><tr>${kepala.map((c) => `<th>${sebaris(c, ktx, mode)}</th>`).join('')}</tr></thead>` : ''}<tbody>${isi.map((r) =>
        `<tr>${r.map((c) => `<td${/^\d+\.?$/.test(c) ? ' class="tengah"' : ''}>${sebaris(c, ktx, mode)}</td>`).join('')}</tr>`).join('')}</tbody></table>`)
      continue
    }
    if (RE_SEJAJAR.test(b) && !/^\s*(\d+|[a-z])\.\s/.test(b)) {
      const rows = []; while (i < baris.length && RE_SEJAJAR.test(baris[i]) && baris[i].trim()) rows.push(RE_SEJAJAR.exec(baris[i++]))
      out.push(`<table class="sejajar">${rows.map((m) => { const bl = blokSendiri(m[2], ktx)
        return `<tr><td class="lbl">${sebaris(m[1].trim(), ktx, mode)}</td><td class="tt">:</td><td>${bl ? htmlBlok(bl, mode) : sebaris(m[2], ktx, mode)}</td></tr>` }).join('')}</table>`)
      continue
    }
    const daftar = /^\s*(\d+\.|[a-z]\.|-)\s+/.exec(b)
    if (daftar) {
      const jenis = daftar[1] === '-' ? 'ul' : /^\d/.test(daftar[1]) ? 'ol1' : 'ola'; const pola = jenis === 'ul' ? /^\s*-\s+/ : jenis === 'ol1' ? /^\s*\d+\.\s+/ : /^\s*[a-z]\.\s+/
      const items = []; while (i < baris.length && pola.test(baris[i])) items.push(baris[i++].replace(pola, ''))
      const li = items.map((x) => `<li>${sebaris(x, ktx, mode)}</li>`).join('')
      out.push(jenis === 'ul' ? `<ul>${li}</ul>` : `<ol type="${jenis === 'ola' ? 'a' : '1'}">${li}</ol>`)
      continue
    }
    const bl = blokSendiri(b, ktx)
    if (bl) { out.push(htmlBlok(bl, mode)); i++; continue }
    const para = []
    while (i < baris.length && baris[i].trim() && !/^==\s+|^\s*\|/.test(baris[i]) && !RE_SEJAJAR.test(baris[i]) && !/^\s*(\d+\.|[a-z]\.|-)\s+/.test(baris[i]) && !blokSendiri(baris[i], ktx)) para.push(baris[i++])
    out.push(`<p>${para.map((x) => sebaris(x, ktx, mode)).join('<br>')}</p>`)
  }
  return out.join('\n')
}

/** Teks satu baris (judul, subjudul) → HTML dengan isian; baris baru dipertahankan. */
export const renderBaris = (teks, ktx, mode = 'pratinjau') => String(teks || '').split('\n').map((x) => sebaris(x, ktx, mode)).join('<br>')

/** Isian yang belum diisi (wajib) untuk diperingatkan sebelum disimpan/diajukan. */
export function isianKosong(isian = [], nilai = {}) {
  return isian.filter((i) => i.wajib).filter((i) => {
    const v = nilai[i.kunci]
    if (i.jenis === 'daftar') return !(Array.isArray(v) ? v : []).some((x) => String(x).trim())
    if (i.jenis === 'daftar_pegawai') return !(Array.isArray(v) && v.length)
    if (i.jenis === 'pegawai' || i.jenis === 'santri') return !v?.id && !v?.nama
    return v == null || String(v).trim() === ''
  }).map((i) => i.label)
}

/** Potret template yang dibekukan pada surat (perubahan template kemudian tidak mengubah surat lama). */
export const potretTemplate = (t) => ({ bentuk: t.bentuk, judul: t.judul, subjudul: t.subjudul, isi: t.isi, opsi: { ...(t.opsi || {}) }, isian: JSON.parse(JSON.stringify(t.isian || [])) })
