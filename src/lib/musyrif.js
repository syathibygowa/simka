// SIMKA PRO | src/lib/musyrif.js | v1.1 | Fase 6 – Tahap 3 Jurnal musyrif dan klinik lanjutan | 06/10/2026
// Pengolahan data absensi asrama (hasil absensi_asrama_rinci) menjadi rekap per santri, per pekan, per bulan,
// matriks harian individu, dan teks WA. Terlambat dan Bolos dihitung hadir (sama dengan rekap absensi santri).
import { BULAN, HARI, formatPanjang, formatPendek } from './tanggal'
import { persen, teksPersen, jam } from './absensi'
import { PhMosque, PhBroom, PhChalkboardTeacher, PhFirstAidKit, PhGavel, PhWarningCircle, PhDotsThreeCircle } from '@phosphor-icons/vue'

// ---------- Jurnal musyrif (v1.1) ----------
export const KATEGORI_JURNAL = {
  ibadah: { n: 'Ibadah', w: 'musyrif', ikon: PhMosque }, kebersihan: { n: 'Kebersihan', w: 'rekap', ikon: PhBroom },
  pembinaan: { n: 'Pembinaan', w: 'agenda', ikon: PhChalkboardTeacher }, kesehatan: { n: 'Kesehatan', w: 'klinik', ikon: PhFirstAidKit },
  kedisiplinan: { n: 'Kedisiplinan', w: 'laporan', ikon: PhGavel }, kejadian: { n: 'Kejadian', w: 'pengajuan', ikon: PhWarningCircle },
  lainnya: { n: 'Lainnya', w: 'hakakses', ikon: PhDotsThreeCircle },
}
export const WAKTU_JURNAL = { pagi: 'Pagi', siang: 'Siang', sore: 'Sore', malam: 'Malam', umum: 'Sepanjang hari' }
/** Waktu bawaan mengikuti jam sistem saat ini. */
export const waktuSekarang = () => { const j = new Date().getHours(); return j < 10 ? 'pagi' : j < 14 ? 'siang' : j < 18 ? 'sore' : 'malam' }

const iso = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
const tgl = (s) => new Date(`${s}T00:00:00`)
export const tambahHari = (s, n) => { const d = tgl(s); d.setDate(d.getDate() + n); return iso(d) }
/** Senin pada pekan tanggal s. */
export const awalPekan = (s) => tambahHari(s, -((tgl(s).getDay() + 6) % 7))
export const awalBulanDari = (s) => s.slice(0, 8) + '01'
export const akhirBulanDari = (s) => { const d = tgl(awalBulanDari(s)); d.setMonth(d.getMonth() + 1); d.setDate(0); return iso(d) }
export const namaHari = (s) => HARI[tgl(s).getDay()]
export const namaBulan = (s) => `${BULAN[Number(s.slice(5, 7)) - 1]} ${s.slice(0, 4)}`
export const teksRentang = (a, b) => (a === b ? formatPanjang(a) : `${formatPanjang(a)} s.d. ${formatPanjang(b)}`)

const kosong = () => ({ sesi: 0, H: 0, I: 0, S: 0, B: 0, A: 0, T: 0 })
const tambah = (r, kode) => { r.sesi++; r[kode]++ }
/** Hadir = sesi − Izin − Sakit − Absen (Terlambat dan Bolos dihitung hadir). */
export const hadirDari = (r) => r.sesi - r.I - r.S - r.A
export const persenDari = (r) => persen(hadirDari(r), r.sesi)

/**
 * Susun data rinci: { sesiPeta: id → sesi, perSantri: id → { total, tidak: [ {tanggal, nama_sesi, kode, ket} ] },
 *   perTanggal: tanggal → { sesi, H, … }, tidakDiisi: [rencana tanpa sesi] }
 */
export function olahRinci(d, saring = null) {
  const sesiPeta = Object.fromEntries((d?.sesi || []).map((s) => [s.id, s]))
  const perSantri = {}; const perTanggal = {}; const sel = {}
  for (const [sid, stid, kode, ket] of d?.isi || []) {
    const s = sesiPeta[sid]; if (!s || (saring && !saring(s))) continue
    const p = (perSantri[stid] ||= { total: kosong(), tidak: [] })
    tambah(p.total, kode)
    if (kode !== 'H') p.tidak.push({ tanggal: s.tanggal, sesi: s.sesi, nama_sesi: s.nama_sesi, kode, ket })
    tambah((perTanggal[s.tanggal] ||= kosong()), kode)
    sel[`${stid}|${s.tanggal}|${s.sesi}`] = { kode, ket }
  }
  const ada = new Set((d?.sesi || []).map((s) => `${s.tanggal}|${s.sesi}`))
  const tidakDiisi = (d?.rencana || []).filter((r) => !ada.has(`${r.tanggal}|${r.sesi}`) && (!saring || saring(r)))
  const jumlahSesi = (d?.sesi || []).filter((x) => !saring || saring(x)).length
  return { sesiPeta, perSantri, perTanggal, sel, tidakDiisi, jumlahSesi }
}

/** Ringkasan seluruh kamar: rata-rata, sesi terlaksana, hadir penuh. */
export function ringkasKamar(d, o) {
  const santri = (d?.santri || []).filter((s) => o.perSantri[s.id])
  const t = santri.reduce((a, s) => { const r = o.perSantri[s.id].total; return { h: a.h + hadirDari(r), n: a.n + r.sesi } }, { h: 0, n: 0 })
  return {
    persen: persen(t.h, t.n), sesi: o.jumlahSesi, santri: santri.length,
    penuh: santri.filter((s) => { const r = o.perSantri[s.id].total; return r.sesi && hadirDari(r) === r.sesi }).length,
  }
}

/** Potong rentang menjadi pekan (Senin–Ahad) atau bulan. [{ k, n, mulai, selesai }] */
export function bagiPeriode(mulai, selesai, jenis) {
  const hasil = []; let a = jenis === 'bulan' ? awalBulanDari(mulai) : awalPekan(mulai)
  while (a <= selesai) {
    const b = jenis === 'bulan' ? akhirBulanDari(a) : tambahHari(a, 6)
    const m = a < mulai ? mulai : a; const s = b > selesai ? selesai : b
    hasil.push({ k: a, mulai: m, selesai: s, n: jenis === 'bulan' ? namaBulan(a) : `${formatPendek(m).slice(0, 5)}–${formatPendek(s).slice(0, 5)}` })
    a = jenis === 'bulan' ? tambahHari(b, 1) : tambahHari(a, 7)
  }
  return hasil
}

/** Daftar tanggal pada rentang (untuk matriks individu). */
export function daftarTanggal(mulai, selesai) { const h = []; for (let a = mulai; a <= selesai; a = tambahHari(a, 1)) h.push(a); return h }

export const teksKode = { I: 'Izin', S: 'Sakit', B: 'Bolos', A: 'Absen', T: 'Terlambat' }
/** Ringkas untuk WA/salin: "Hadir 26/28 sesi (92,9%) · Izin 1 · Sakit 1". */
export function teksRekapSantri(r) {
  if (!r?.sesi) return 'Belum ada sesi asrama yang tercatat pada periode ini.'
  const lain = ['I', 'S', 'A', 'B', 'T'].filter((k) => r[k]).map((k) => `${teksKode[k]} ${r[k]}`)
  return `Hadir ${hadirDari(r)}/${r.sesi} sesi (${teksPersen(persenDari(r))})${lain.length ? ' · ' + lain.join(' · ') : ''}`
}
/** Rincian ketidakhadiran per santri untuk WA ke wali (keterangan sakit TIDAK disertakan; hanya status). */
export function teksTidakHadir(tidak, batas = 12) {
  if (!tidak.length) return 'Alhamdulillah, hadir penuh di semua sesi asrama.'
  const baris = tidak.slice(0, batas).map((x) => `• ${namaHari(x.tanggal)}, ${formatPendek(x.tanggal)} ${x.nama_sesi.toLowerCase()}: ${teksKode[x.kode]}`)
  if (tidak.length > batas) baris.push(`• … dan ${tidak.length - batas} sesi lainnya`)
  return 'Rincian:\n' + baris.join('\n')
}
export const jamSesi = (s) => jam(s?.jam_mulai)
