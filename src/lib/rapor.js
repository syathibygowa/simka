// SIMKA PRO | src/lib/rapor.js | v1.5 | 14.37.0: tanggal rapor bawaan memakai tanggal WITA hari ini | 30/10/2026
// Pengolah data cetak rapor (data_rapor / data_rapor_tahfizh): nilai per mapel rapor (pembulatan, predikat, deskripsi
// otomatis), jumlah/rata-rata/peringkat untuk leger, kehadiran (persentase dan kalimat), keputusan akhir tahun,
// identitas sekolah, serta label kelas Romawi.
import { predikatDari, bulatkan } from './penilaian'
import { deskripsiOtomatis, deskripsiCapaian } from './nilai'
import { formatPanjang, hariIniISO } from './tanggal'
import { deskripsiKokurikuler, deskripsiPd } from './catatanRapor'

export const ROMAWI = { 7: 'VII', 8: 'VIII', 9: 'IX', 10: 'X', 11: 'XI', 12: 'XII' }
/** Nama kelas di rapor: "X.A" untuk kelas "10A", tetap memakai nama asli bila tidak berpola angka+huruf. Keterangan kelas (mis. nama
 *  rombel) ditambahkan dalam kurung. */
export function namaKelasRapor(k) {
  if (!k) return ''
  const m = /^(\d{1,2})\s*([A-Za-z]*)$/.exec(String(k.nama || '').trim())
  const dasar = m && ROMAWI[m[1]] ? `${ROMAWI[m[1]]}${m[2] ? (k.jenjang === 'wustha' ? ' ' : '.') + m[2].toUpperCase() : ''}` : k.nama
  // 14.22.0: keterangan yang sama dengan nama kelas (mis. "Kelas 8A", "VIII A") tidak diulang
  const rata = (t) => String(t || '').toLowerCase().replace(/kelas/g, '').replace(/[^a-z0-9]/g, '')
  const ket = String(k.keterangan || '').trim()
  return ket && !rata(ket).includes(rata(dasar)) && !rata(ket).includes(rata(k.nama)) && rata(ket) !== rata(dasar) ? `${dasar} (${ket})` : dasar
}
export const SEMESTER_RAPOR = { 1: '1 (Ganjil)', 2: '2 (Genap)' }
export const SEMESTER_KATA = { 1: 'GANJIL', 2: 'GENAP' }

/** Isian identitas sekolah (Penilaian → Ketentuan) untuk sampul dan halaman identitas sekolah. */
export const IDENTITAS_SEKOLAH = [
  { k: 'nama_sekolah', n: 'Nama sekolah', lebar: true }, { k: 'jenjang', n: 'Jenjang (sampul)', lebar: true },
  { k: 'npsn', n: 'NPSN' }, { k: 'nss', n: 'NSS/NSPP' }, { k: 'alamat', n: 'Alamat sekolah', lebar: true },
  { k: 'kelurahan', n: 'Kelurahan/desa' }, { k: 'kecamatan', n: 'Kecamatan' }, { k: 'kota', n: 'Kabupaten/kota' }, { k: 'provinsi', n: 'Provinsi' },
  { k: 'kode_pos', n: 'Kode pos' }, { k: 'telepon', n: 'Telepon' }, { k: 'email', n: 'E-mail' }, { k: 'kementerian', n: 'Kementerian (sampul)', lebar: true },
]
// Logo sampul (identitas.logo_url) dipilih dari daftar logo terpusat (Setelan → Logo); kosong = logo pondok.

export const KEPUTUSAN = {
  naik: { n: 'Naik kelas', w: 'presensi' }, tinggal: { n: 'Tinggal kelas', w: 'klinik' },
  lulus: { n: 'Lulus', w: 'presensi' }, tidak_lulus: { n: 'Tidak lulus', w: 'klinik' },
}
export const kelasAkhir = (tingkat) => [9, 12].includes(Number(tingkat))
export const keputusanBawaan = (tingkat) => (kelasAkhir(tingkat) ? 'lulus' : 'naik')
/** Kalimat keputusan di rapor semester 2. */
export function teksKeputusan(k, tingkat) {
  if (!k?.keputusan) return ''
  if (k.keputusan === 'naik') return `Naik ke Kelas ${ROMAWI[k.ke_tingkat || Number(tingkat) + 1] || ''}`.trim()
  if (k.keputusan === 'tinggal') return `Tinggal di Kelas ${ROMAWI[k.ke_tingkat || tingkat] || ''}`.trim()
  return k.keputusan === 'lulus' ? 'LULUS' : 'TIDAK LULUS'
}

// ---------- Kehadiran ----------
export const persenHadir = (k) => (k?.hari ? Math.round((k.hadir / k.hari) * 100) : null)
/** Kalimat kehadiran dari bank (ambang persentase menurun). */
export function kalimatHadir(persen, daftar) {
  if (persen == null) return ''
  const urut = [...(daftar || [])].sort((a, b) => Number(b.min ?? 0) - Number(a.min ?? 0))
  return (urut.find((x) => persen >= Number(x.min ?? 0)) || urut[urut.length - 1])?.teks || ''
}

// ---------- Nilai ----------
/** Kalimat capaian tanpa daftar TP: buang kata sambung yang menggantung di akhir ("… mengenai") lalu beri titik. */
function rapikan(t, adaTp) {
  if (!t) return ''
  const k = adaTp ? t : t.replace(/\s+(mengenai|pada materi|dalam memahami|materi|tentang)\s*$/i, '')
  return /[.,!?]$/.test(k.trim()) ? k.trim() : `${k.trim()}.`
}
/** Baris nilai satu santri untuk setiap mapel rapor. */
/** Nilai gabungan (rata-rata pengetahuan dan keterampilan), predikat, dan deskripsi gabungan (dengan tujuan pembelajaran bila dipakai).
    Deskripsi yang ditulis guru dipakai apa adanya (pengetahuan lalu keterampilan bila keduanya ditulis). */
function gabungan(n, k, x, pred, tp, pakaiTp, des, capai = null) {
  const ada = [n, k].filter((v) => v != null).map(Number)
  const g = ada.length ? bulatkan(ada.reduce((a, v) => a + v, 0) / ada.length, des) : null
  const p = predikatDari(g, pred)
  const tulis = [x.deskripsi, x.deskripsi_2].map((t) => String(t || '').trim()).filter(Boolean)
  let d = ''
  if (tulis.length) d = tulis.map((t) => (/[.!?]$/.test(t) ? t : t + '.')).join(' ')
  else if (g != null && capai != null && tp.length) d = deskripsiCapaian(g, pred, tp, capai, { gabung: k != null }) || ''   // 14.26.0: ceklist TP
  else if (g != null) {
    let kal = String(p?.deskripsi || '').trim()
    if (k != null && /pengetahuan/i.test(kal) && !/keterampilan/i.test(kal)) kal = kal.replace(/pengetahuan/i, 'pengetahuan dan keterampilan')
    d = rapikan(pakaiTp && tp.length ? `${kal} ${tp.map((t) => t.teks || t).join(', ')}` : kal, pakaiTp && tp.length > 0)
  }
  return { nilai_gabung: g, huruf_gabung: p?.huruf || '', deskripsi_gabung: d }
}
export function barisNilai(santri, D) {
  const ket = D.ketentuan || {}; const des = Number(ket.desimal || 0)
  const pred = (D.predikat || []).filter((p) => p.kelompok === D.kelas.jenjang)
  return (D.mapel || []).map((m) => {
    const x = santri.nilai?.[m.id] || {}
    const n = bulatkan(x.nilai, des); const k = bulatkan(x.keterampilan ?? (ket.keterampilan_ikut !== false ? x.nilai : null), des)
    const p = predikatDari(n, pred); const pk = predikatDari(k, pred)
    const tp = (x.tp || []).filter(Boolean)
    const capai = Array.isArray(x.tp_capai) ? x.tp_capai : null   // 14.26.0: TP yang dicentang guru (null = belum diceklist)
    const dCapai = n == null ? null : deskripsiCapaian(n, pred, tp, capai)
    return {
      ...m, nilai: n, keterampilan: k, huruf: p?.huruf || '', huruf_ket: pk?.huruf || '', tuntas: n == null ? null : n >= Number(m.kkm), sikap: x.sikap || '',
      deskripsi: x.deskripsi || dCapai || (n == null ? '' : rapikan(deskripsiOtomatis(n, pred, { tp, pakaiTp: !!ket.pakai_tp }), !!ket.pakai_tp && tp.length > 0)),
      deskripsi_2: x.deskripsi_2 || (k == null ? '' : deskripsiOtomatis(k, pred, { keterampilan: true })),
      // 14.23.0: rapor Wustha sederhana — satu predikat dan satu deskripsi dari rata-rata nilai pengetahuan dan keterampilan
      ...gabungan(n, k, x, pred, tp, !!ket.pakai_tp, des, capai),
    }
  })
}
/** Kelompokkan baris mapel menurut judul kelompok (KELOMPOK UMUM, …) dengan nomor urut berlanjut. */
export function kelompokkan(baris) {
  const g = []; let no = 0
  for (const b of baris) { let x = g[g.length - 1]; if (!x || x.kelompok !== (b.kelompok || '')) { x = { kelompok: b.kelompok || '', item: [] }; g.push(x) } x.item.push({ ...b, no: ++no }) }
  return g
}

/** Leger: baris per santri (nilai per mapel, jumlah, rata-rata, peringkat, sikap terbanyak, kehadiran). */
export function hitungLeger(D) {
  const des = Number(D.ketentuan?.desimal || 0)
  const baris = (D.santri || []).map((s) => {
    const n = barisNilai(s, D); const ada = n.filter((x) => x.nilai != null)
    const jumlah = ada.reduce((a, x) => a + Number(x.nilai), 0)
    const sikap = n.map((x) => x.sikap).filter(Boolean); const hit = {}; sikap.forEach((h) => { hit[h] = (hit[h] || 0) + 1 })
    return { s, n, jumlah: bulatkan(jumlah, des), rata: ada.length ? bulatkan(jumlah / ada.length, 2) : null, terisi: ada.length,
      bawah: n.filter((x) => x.tuntas === false), sikap: Object.entries(hit).sort((a, b) => b[1] - a[1])[0]?.[0] || '', hadir: persenHadir(s.kehadiran) }
  })
  const urut = [...baris].filter((b) => b.rata != null).sort((a, b) => b.jumlah - a.jumlah)
  for (const b of baris) b.peringkat = b.rata == null ? null : urut.findIndex((x) => x.jumlah === b.jumlah) + 1
  return baris
}
/** Ringkasan per mapel untuk laporan ketercapaian: rata-rata kelas, tertinggi, terendah, jumlah di bawah KKM. */
export function ringkasMapel(D, leger) {
  return (D.mapel || []).map((m, i) => {
    const v = leger.map((b) => b.n[i]?.nilai).filter((x) => x != null).map(Number)
    return { ...m, rata: v.length ? bulatkan(v.reduce((a, x) => a + x, 0) / v.length, 2) : null, maks: v.length ? Math.max(...v) : null, min: v.length ? Math.min(...v) : null,
      bawah: v.filter((x) => x < Number(m.kkm)).length, terisi: v.length }
  })
}

// ---------- Bagian lain ----------
export const deskripsiKok = (s, D) => s.kokurikuler?.deskripsi || deskripsiKokurikuler(s.kokurikuler?.dimensi, D.periode?.tema_kokurikuler)
export const barisPd = (s, D) => (s.pd || []).map((x) => {
  const p = (D.predikat || []).find((y) => y.kelompok === 'pd' && y.huruf === x.nilai)
  return { ...x, sebutan: p?.sebutan || '', deskripsi: x.deskripsi || deskripsiPd((D.predikat || []).filter((y) => y.kelompok === 'pd'), x.nilai, x.kegiatan) }
})
export const ttl = (s) => [s.tempat_lahir, s.tanggal_lahir ? formatPanjang(s.tanggal_lahir) : ''].filter(Boolean).join(', ')
export const nisNisn = (s) => [s.nis, s.nisn].filter(Boolean).join('/')
export const JK_PANJANG = { L: 'Laki-laki', P: 'Perempuan' }
/** Tanggal rapor: dari periode penilaian, bawaan hari ini. */
export const tanggalRapor = (D) => D?.periode?.tanggal_rapor || hariIniISO()
/** Kode kop: ketentuan, bawaan jenjang (SMA → Kop SMA; Wustha → Kop Kesetaraan Wustha; tahfizh → jenjang santri/pondok). */
export const kopRapor = (ket, jenjang) => ket?.kop_kode || (jenjang === 'sma' ? 'sma' : jenjang === 'wustha' ? 'wustha' : 'pondok')
/** Nama wali kelas utama. */
export const waliUtama = (D) => (D?.wali || []).find((w) => w.peran === 'utama') || (D?.wali || [])[0] || null
