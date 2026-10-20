// SIMKA PRO | src/lib/kinerja.js | v1.0 | 14.18.0: rumus indikator kinerja bidang (satu sumber untuk layar, cetak, dan Excel) | 21/10/2026
// Indikator Kinerja Bidang (IKB): enam indikator yang SAMA untuk setiap bidang agar penilaian adil.
// Angka mentah berasal dari fungsi server kinerja_bidang(mulai, selesai); persentase, skor, predikat, dan catatan dihitung di sini.
//   Skor = rata-rata indikator yang berlaku (bobot sama). Indikator tidak berlaku bila bidang tidak memiliki tugas itu
//   (mis. bidang tanpa kelompok santri) sehingga tidak menurunkan atau menaikkan skor.
import { hariIniISO } from './tanggal'

const n = (v) => Number(v) || 0

export const INDIKATOR = [
  { k: 'hadir', n: 'Kehadiran', pendek: 'Kehadiran', aspek: 'Kedisiplinan presensi', w: 'presensi', warna: '#1E7D4F', satuan: 'sesi',
    rumus: '(Hadir + Terlambat + Dinas luar + Menunggu verval) ÷ (Sesi wajib − Izin − Sakit − Cuti)',
    ket: 'Kehadiran pegawai pada sesi kerja wajib. Ketidakhadiran yang berizin resmi tidak mengurangi nilai.',
    hitung: (r) => [n(r.hadir) + n(r.terlambat) + n(r.dinas) + n(r.menunggu), n(r.wajib) - n(r.izin) - n(r.sakit) - n(r.cuti)] },
  { k: 'tepat', n: 'Ketepatan waktu', pendek: 'Tepat waktu', aspek: 'Kedisiplinan presensi', w: 'jadwal', warna: '#2F5FA8', satuan: 'sesi hadir',
    rumus: '(Hadir tepat waktu + Dinas luar) ÷ (Hadir + Terlambat + Dinas luar)',
    ket: 'Dari sesi yang dihadiri, berapa yang datang tepat waktu (tidak terlambat).',
    hitung: (r) => [n(r.hadir) + n(r.dinas), n(r.hadir) + n(r.terlambat) + n(r.dinas)] },
  { k: 'izin', n: 'Ketertiban perizinan', pendek: 'Tertib izin', aspek: 'Perizinan', w: 'pengajuan', warna: '#7B3FA0', satuan: 'sesi tidak hadir',
    rumus: '(Izin + Sakit + Cuti) ÷ (Izin + Sakit + Cuti + Tanpa keterangan)',
    ket: 'Setiap ketidakhadiran semestinya disertai pengajuan resmi. Tanpa ketidakhadiran sama sekali = 100%.',
    hitung: (r) => [n(r.izin) + n(r.sakit) + n(r.cuti), n(r.izin) + n(r.sakit) + n(r.cuti) + n(r.tk)], penuhBilaKosong: (r) => n(r.wajib) > 0 },
  { k: 'jurnal', n: 'Pengisian jurnal harian', pendek: 'Jurnal harian', aspek: 'Jurnal pegawai', w: 'tatausaha', warna: '#127A7A', satuan: 'hari wajib',
    rumus: 'Hari jurnal terisi ÷ Hari wajib jurnal',
    ket: 'Hari wajib = hari yang memiliki sesi kerja wajib dan pegawai tidak sedang izin, sakit, atau cuti. Terisi = ada ceklist tupoksi atau kegiatan (selain yang dikembalikan).',
    hitung: (r) => [n(r.jur_isi), n(r.jur_wajib)] },
  { k: 'santri', n: 'Pengabsenan santri', pendek: 'Absen santri', aspek: 'Mengabsen santri', w: 'santri', warna: '#C26A12', satuan: 'sesi absensi',
    rumus: 'Sesi absensi santri terisi ÷ Sesi absensi terjadwal yang sudah lewat',
    ket: 'Absensi kelas, halaqah, asrama, dan ekskul. Dihitung pada bidang pemilik kelompok: halaqah → Tahfizh; kamar dan ekskul → Kesantrian; kelas → Wustha atau SMA.',
    hitung: (r) => [n(r.ss_isi), n(r.ss)] },
  { k: 'tupoksi', n: 'Pelaksanaan tupoksi', pendek: 'Tupoksi', aspek: 'Menjalankan tupoksi', w: 'tahfizh', warna: '#A6791A', satuan: 'tugas',
    rumus: '(JP mengajar terlaksana + Butir tupoksi dicentang) ÷ (JP terjadwal + Butir tupoksi wajib)',
    ket: 'Butir tupoksi = ceklist jurnal harian sesuai jabatan/unit, dikalikan hari wajib. JP mengajar dihitung pada bidang jenjang kelas yang diajar.',
    hitung: (r) => [n(r.jp_isi) + n(r.butir_isi), n(r.jp) + n(r.butir)] },
]
export const INDIKATOR_PETA = Object.fromEntries(INDIKATOR.map((x) => [x.k, x]))

export const PREDIKAT = [
  { min: 90, n: 'Sangat baik', w: 'presensi', warna: '#1E7D4F' },
  { min: 80, n: 'Baik', w: 'pegawai', warna: '#2F5FA8' },
  { min: 70, n: 'Cukup', w: 'laporan', warna: '#B5501A' },
  { min: 0, n: 'Perlu pembinaan', w: 'klinik', warna: '#C7332F' },
]
export const predikat = (skor) => (skor == null ? null : PREDIKAT.find((p) => skor >= p.min))

const satuDesimal = (v) => Math.round(v * 10) / 10
export const persenTeks = (p) => (p == null ? '–' : `${String(p).replace('.', ',')}%`)
export const skorTeks = (s) => (s == null ? '–' : String(s).replace('.', ','))

/** Hitung semua indikator, skor, dan predikat sebuah baris (bidang atau pegawai). */
export function nilai(r) {
  const ind = {}; const berlaku = []
  for (const x of INDIKATOR) {
    const [a, b] = x.hitung(r)
    let p = null
    if (b > 0) p = satuDesimal((100 * Math.min(a, b)) / b)
    else if (x.penuhBilaKosong?.(r)) p = 100
    ind[x.k] = { n: a, d: b, p }
    if (p != null) berlaku.push(p)
  }
  const skor = berlaku.length ? satuDesimal(berlaku.reduce((s, v) => s + v, 0) / berlaku.length) : null
  return { ind, skor, predikat: predikat(skor), berlaku: berlaku.length }
}

/** Catatan otomatis: kekuatan, indikator di bawah 80%, dan hal yang perlu ditindaklanjuti (dengan angka). */
export function catatan(r, h = nilai(r)) {
  const out = []
  if (h.skor == null) return ['Belum ada data tugas pada periode ini.']
  const urut = INDIKATOR.filter((x) => h.ind[x.k].p != null).sort((a, b) => h.ind[a.k].p - h.ind[b.k].p)
  const kuat = urut.filter((x) => h.ind[x.k].p >= 90).slice(-2).reverse()
  if (kuat.length) out.push(`Kekuatan: ${kuat.map((x) => `${x.n.toLowerCase()} ${persenTeks(h.ind[x.k].p)}`).join(', ')}.`)
  for (const x of urut.filter((y) => h.ind[y.k].p < 80)) {
    const v = h.ind[x.k]
    out.push(`Perlu perhatian: ${x.n.toLowerCase()} ${persenTeks(v.p)} (${v.n} dari ${v.d} ${x.satuan}).`)
  }
  if (n(r.tk)) out.push(`${n(r.tk)} sesi kerja tanpa keterangan (tidak presensi dan tanpa pengajuan).`)
  if (n(r.terlambat)) out.push(`${n(r.terlambat)} sesi terlambat.`)
  if (n(r.jur_wajib) - n(r.jur_isi) > 0) out.push(`${n(r.jur_wajib) - n(r.jur_isi)} hari wajib tanpa jurnal harian.`)
  if (n(r.ss) - n(r.ss_isi) > 0) out.push(`${n(r.ss) - n(r.ss_isi)} sesi absensi santri tidak diisi${n(r.ss_telat) ? `; ${n(r.ss_telat)} sesi diisi melewati batas waktu` : ''}.`)
  if (n(r.jp) - n(r.jp_isi) > 0) out.push(`${n(r.jp) - n(r.jp_isi)} JP mengajar tidak terlaksana atau jurnalnya kosong${n(r.jp_tidak) ? ` (${n(r.jp_tidak)} dicatat tidak terlaksana)` : ''}.`)
  if (n(r.menunggu)) out.push(`${n(r.menunggu)} sesi presensi masih menunggu verval (sementara dihitung hadir).`)
  if (out.length === (kuat.length ? 1 : 0)) out.push('Semua indikator di atas 80%; pertahankan.')
  return out
}

/** Periode bawaan Layar Pantauan: awal bulan berjalan s.d. kemarin; pada tanggal 1 = seluruh bulan lalu. */
export function periodeBerjalan(hari = hariIniISO()) {
  const [y, m, d] = hari.split('-').map(Number)
  const iso = (t) => t.toISOString().slice(0, 10)
  if (d === 1) return { mulai: iso(new Date(Date.UTC(y, m - 2, 1))), selesai: iso(new Date(Date.UTC(y, m - 1, 0))) }
  return { mulai: `${hari.slice(0, 8)}01`, selesai: iso(new Date(Date.UTC(y, m - 1, d - 1))) }
}

/** Periode cepat untuk tab laporan (paling panjang 92 hari). */
export const PERIODE_KINERJA = [{ k: 'berjalan', n: 'Bulan berjalan' }, { k: 'bulan_lalu', n: 'Bulan lalu' }, { k: 'triwulan', n: '3 bulan terakhir' }]
export function periodeKinerja(k, hari = hariIniISO()) {
  const [y, m, d] = hari.split('-').map(Number); const iso = (t) => t.toISOString().slice(0, 10)
  const kemarin = iso(new Date(Date.UTC(y, m - 1, d - 1)))
  if (k === 'bulan_lalu') return { mulai: iso(new Date(Date.UTC(y, m - 2, 1))), selesai: iso(new Date(Date.UTC(y, m - 1, 0))) }
  if (k === 'triwulan') return { mulai: iso(new Date(Date.UTC(y, m - 1, d - 91))), selesai: kemarin }
  return periodeBerjalan(hari)
}

/** Lengkapi muatan server dengan nilai, catatan, dan urutan; pegawai dan kelompok dikelompokkan per bidang. */
export function olah(data) {
  if (!data) return null
  const bidang = (data.bidang || []).map((b) => { const h = nilai(b); return { ...b, ...h, catatan: catatan(b, h) } })
  const pegawai = (data.pegawai || []).map((p) => { const h = nilai(p); return { ...p, ...h, catatan: catatan(p, h) } })
  const kelompok = (data.kelompok || []).map((g) => ({ ...g, p: n(g.ss) ? satuDesimal((100 * n(g.ss_isi)) / n(g.ss)) : null }))
  // Ringkasan pondok: jumlah seluruh angka mentah bidang (setiap bidang sudah memuat tugas miliknya, tanpa tumpang tindih)
  const kunci = ['pegawai', 'wajib', 'hadir', 'terlambat', 'dinas', 'menunggu', 'izin', 'sakit', 'cuti', 'tk', 'jur_wajib', 'jur_isi', 'butir', 'butir_isi', 'ss', 'ss_isi', 'ss_telat', 'jp', 'jp_isi', 'jp_tidak']
  const jumlah = Object.fromEntries(kunci.map((k) => [k, bidang.reduce((s, b) => s + n(b[k]), 0)]))
  const hp = nilai(jumlah)
  return { ...data, bidang, pegawai, kelompok, pondok: { ...jumlah, ...hp, nama: 'Seluruh pondok', catatan: catatan(jumlah, hp) } }
}
