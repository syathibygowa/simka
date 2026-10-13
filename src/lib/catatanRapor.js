// SIMKA PRO | src/lib/catatanRapor.js | v1.0 | Fase 12 – Tahap 4 Catatan rapor otomatis | 13/10/2026
// Penyusun catatan rapor dari bank kalimat (Penilaian → Kalimat rapor) dan data santri:
//   catatan wali kelas  : pembuka + 1–2 apresiasi kelebihan (dipilih dari keunggulan santri) + 1 dorongan + penutup
//   catatan muhaffizh   : susunan yang sama dengan pemicu hafalan, target bulanan, UTAS, dan kehadiran halaqah
//   kokurikuler (SMA)   : deskripsi dari dimensi tertinggi dan terendah
//   pengembangan diri   : deskripsi predikat dengan {kegiatan}
// Pilihan kalimat acak tetapi tetap (berbenih id santri + putaran), sehingga tiap santri mendapat susunan berbeda dan
// tombol "Susun ulang" menghasilkan variasi baru. Hasil selalu dapat disunting sebelum disimpan.

/** Skala nilai kokurikuler 1–4. */
export const SKALA_KOKURIKULER = {
  4: { n: 'Sangat baik', frasa: 'sudah sangat baik' },
  3: { n: 'Baik', frasa: 'sudah baik' },
  2: { n: 'Cukup', frasa: 'cukup baik' },
  1: { n: 'Perlu bimbingan', frasa: 'masih perlu bimbingan' },
}

// ---------- Acak berbenih ----------
function benih(teks) { let h = 2166136261; for (const c of String(teks)) { h ^= c.charCodeAt(0); h = Math.imul(h, 16777619) } return h >>> 0 }
function pengacak(teks) {
  let a = benih(teks)
  return () => { a = (a + 0x6d2b79f5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296 }
}
const ambil = (daftar, acak) => (daftar.length ? daftar[Math.floor(acak() * daftar.length)] : null)
function kocok(daftar, acak) { const a = [...daftar]; for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(acak() * (i + 1)); [a[i], a[j]] = [a[j], a[i]] } return a }

/** Nama panggilan: kolom panggilan, atau kata pertama nama lengkap (melewati "Muhammad"/"Muh." bila ada kata berikutnya). */
export function panggilan(s) {
  if (s?.panggilan) return s.panggilan
  const k = String(s?.nama || '').trim().split(/\s+/)
  return (/^(muhammad|mohammad|muh\.?|moh\.?|m\.)$/i.test(k[0]) && k[1] ? k[1] : k[0]) || 'Ananda'
}
const persen = (k) => (k?.sesi ? Math.round((k.hadir / k.sesi) * 100) : null)
const daftarKata = (a) => (a.length <= 1 ? a.join('') : `${a.slice(0, -1).join(', ')} dan ${a[a.length - 1]}`)

/** Ganti isian {…} dalam kalimat. */
export function isiKalimat(teks, nilai) {
  return String(teks || '').replace(/\{(\w+)\}/g, (m, k) => (nilai[k] != null && nilai[k] !== '' ? String(nilai[k]) : m))
}
/** Teks dengan _miring_ menjadi HTML (untuk tampilan/cetak). Teks lain di-escape. */
export function htmlMiring(teks) {
  const esc = String(teks || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  return esc.replace(/_([^_]+)_/g, '<i>$1</i>')
}

// ---------- Fakta santri ----------
/** Fakta penyusun catatan wali kelas dari bahan_rapor_kelas. */
export function faktaWali(s, opsi = {}) {
  const mapel = (s.mapel || []).filter((m) => m.nilai != null).map((m) => ({ ...m, nilai: Number(m.nilai), kkm: Number(m.kkm || 75) }))
  const urut = [...mapel].sort((a, b) => b.nilai - a.nilai)
  const rata = mapel.length ? Math.round((mapel.reduce((a, m) => a + m.nilai, 0) / mapel.length) * 10) / 10 : null
  const lemah = mapel.filter((m) => m.nilai < m.kkm).sort((a, b) => a.nilai - b.nilai)
  const terbaik = urut[0] || null
  const terendah = urut[urut.length - 1] || null
  const pd = (s.pd || []).filter((x) => x.nilai)
  const pdA = pd.filter((x) => String(x.nilai).toUpperCase() === 'A')
  const sikap = (s.sikap || []).filter(Boolean)
  const utasBaik = s.utas?.huruf && ['A', 'B'].includes(String(s.utas.huruf).toUpperCase())
  const hadir = persen(s.kehadiran)
  const kunci = {
    kelebihan: {
      mapel_terbaik: !!terbaik && terbaik.nilai >= Math.max(85, terbaik.kkm + 5),
      rata_tinggi: rata != null && rata >= 85 && mapel.length >= 3,
      kehadiran: hadir != null && hadir >= 95,
      hafalan: Number(s.tambah_juz || 0) >= 1,
      utas: !!utasBaik,
      pd: pdA.length > 0,
      sikap: sikap.length > 0 && sikap.every((x) => String(x).toUpperCase() === 'A'),
    },
    dorongan: {
      mapel_lemah: lemah.length > 0 || (!!terendah && mapel.length >= 3 && terendah.nilai < 80),
      kehadiran: hadir != null && hadir < 85,
      hafalan: Number(s.tambah_juz || 0) === 0 && Number(s.total_juz || 0) > 0,
      umum: true,
    },
  }
  const isian = {
    panggilan: panggilan(s), mapel: terbaik?.mapel, nilai: terbaik ? Math.round(terbaik.nilai) : null,
    mapel_lemah: (lemah.length ? lemah : terendah ? [terendah] : []).slice(0, 2).map((m) => m.mapel).join(' serta '),
    persen: hadir, tambah_juz: s.tambah_juz, juz: s.total_juz, predikat_utas: opsi.sebutUtas ? opsi.sebutUtas(s.utas) : s.utas?.huruf,
    kegiatan: (pdA[0] || pd[0])?.kegiatan,
  }
  return { kunci, isian, rata, hadir, terbaik, lemah }
}

/** Fakta penyusun catatan muhaffizh dari bahan_rapor_halaqah. */
export function faktaMuhaffizh(s, opsi = {}) {
  const hadir = persen(s.kehadiran)
  const rasio = s.bulan_total ? s.bulan_tercapai / s.bulan_total : null
  const utasBaik = s.utas?.huruf && ['A', 'B'].includes(String(s.utas.huruf).toUpperCase())
  const kunci = {
    kelebihan: {
      target_tercapai: rasio != null && rasio >= 0.75,
      tambah_banyak: Number(s.tambah_juz || 0) >= 1 || Number(s.tambah_hal || 0) >= 20,
      utas: !!utasBaik,
      kehadiran: hadir != null && hadir >= 90,
      kenaikan_juz: Number(s.kenaikan_lulus || 0) > 0,
    },
    dorongan: {
      target_kurang: rasio != null && rasio < 0.5,
      kehadiran: hadir != null && hadir < 80,
      murajaah: true,
    },
  }
  const isian = { panggilan: panggilan(s), persen: hadir, tambah_juz: s.tambah_juz, juz: s.total_juz, predikat_utas: opsi.sebutUtas ? opsi.sebutUtas(s.utas) : s.utas?.huruf }
  return { kunci, isian, rata: null, hadir, rasio }
}

/**
 * Susun catatan dari bank kalimat.
 * @param kalimat  daftar report_phrases (aktif) kategori catatan_wali/catatan_muhaffizh, sudah disaring jenisnya
 * @param fakta    hasil faktaWali/faktaMuhaffizh
 * @param kunciAcak id santri (+ putaran) sebagai benih
 */
export function susunCatatan(kalimat, fakta, kunciAcak) {
  const acak = pengacak(kunciAcak)
  const bagian = (b) => kalimat.filter((k) => k.bagian === b && k.aktif !== false)
  const cocok = (b, x) => !x.kunci || !!fakta.kunci[b]?.[x.kunci]
  const pakai = (k) => !k || !/\{(\w+)\}/.test(k.teks) || [...k.teks.matchAll(/\{(\w+)\}/g)].every((m) => fakta.isian[m[1]] != null && fakta.isian[m[1]] !== '')
  const hasil = []
  const p = ambil(bagian('pembuka').filter(pakai), acak); if (p) hasil.push(p)
  // Kelebihan: utamakan kalimat berpemicu yang terpenuhi, berbeda pemicunya; maksimal 2
  const lebih = kocok(bagian('kelebihan').filter((x) => x.kunci && cocok('kelebihan', x) && pakai(x)), acak)
  const dipakai = new Set()
  for (const k of lebih) { if (dipakai.size >= 2) break; if (!dipakai.has(k.kunci)) { dipakai.add(k.kunci); hasil.push(k) } }
  if (!dipakai.size) { const umum = ambil(bagian('kelebihan').filter((x) => !x.kunci && pakai(x)), acak); if (umum) hasil.push(umum) }
  // Dorongan: pemicu khusus lebih dulu, kalimat umum bila tidak ada
  const khusus = bagian('dorongan').filter((x) => x.kunci && !['umum', 'murajaah'].includes(x.kunci) && cocok('dorongan', x) && pakai(x))
  const d = ambil(khusus, acak) || ambil(bagian('dorongan').filter((x) => (!x.kunci || ['umum', 'murajaah'].includes(x.kunci)) && pakai(x)), acak)
  if (d) hasil.push(d)
  const t = ambil(bagian('penutup').filter(pakai), acak); if (t) hasil.push(t)
  return hasil.map((k) => isiKalimat(k.teks, fakta.isian)).join(' ').replace(/\s+/g, ' ').trim()
}

/** Kalimat bank untuk satu kategori dan jenis rapor (jenis kosong = berlaku semua). */
export const kalimatUntuk = (bank, kategori, jenis) => (bank || []).filter((k) => k.kategori === kategori && k.aktif !== false && (!k.jenis || k.jenis === jenis))
  .sort((a, b) => (a.urutan || 0) - (b.urutan || 0))

/** Deskripsi kokurikuler otomatis: dimensi tertinggi dan terendah (contoh rapor SMA). */
export function deskripsiKokurikuler(dimensi, tema) {
  const isi = Object.entries(dimensi || {}).map(([k, v]) => [k, Number(v)]).filter(([, v]) => v >= 1 && v <= 4)
  if (!isi.length) return ''
  const maks = Math.max(...isi.map(([, v]) => v)); const min = Math.min(...isi.map(([, v]) => v))
  const atas = isi.filter(([, v]) => v === maks).map(([k]) => k)
  const bawah = isi.filter(([, v]) => v === min).map(([k]) => k)
  const temaTeks = tema ? ` pada tema ${tema}` : ''
  let t = `Ananda ${SKALA_KOKURIKULER[maks].frasa} dalam penerapan dimensi ${daftarKata(atas)}${temaTeks}.`
  const saran = { 1: 'masih perlu bimbingan dalam', 2: 'perlu meningkatkan', 3: 'dapat lebih mengembangkan' }
  if (min < maks) t += ` Ananda ${saran[min]} penerapan dimensi ${daftarKata(bawah)}.`
  return t
}

/** Deskripsi pengembangan diri dari predikat (template {kegiatan}). */
export function deskripsiPd(predikat, huruf, kegiatan) {
  const p = (predikat || []).find((x) => String(x.huruf).toUpperCase() === String(huruf || '').toUpperCase())
  return p?.deskripsi ? isiKalimat(p.deskripsi, { kegiatan }) : ''
}
/** Usulan predikat pengembangan diri dari persentase kehadiran ekskul. */
export function usulPd(hadir, sesi, daftar = ['A', 'B', 'C', 'D']) {
  if (!sesi) return null
  const p = (hadir / sesi) * 100
  return p >= 90 ? daftar[0] : p >= 75 ? daftar[1] : p >= 60 ? daftar[2] : daftar[3] || daftar[daftar.length - 1]
}
