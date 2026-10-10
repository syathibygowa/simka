// SIMKA PRO | src/lib/laporanKehadiran.js | v1.0 | Fase 8 – Tahap 2 Laporan kehadiran pegawai | 10/10/2026
// Olah data laporan kehadiran: pilihan periode cepat, kode status (kata lengkap untuk cetak, singkatan untuk matriks),
// matriks nama × tanggal, keterangan per pegawai, dan daftar perhatian (persentase di bawah ambang).
import { hariIniISO, HARI } from './tanggal'

export const STATUS_HADIR = {
  hadir: { n: 'Hadir', s: 'H', w: 'presensi', b: 0 }, dinas_luar: { n: 'Dinas luar', s: 'DL', w: 'jadwal', b: 1 },
  terlambat: { n: 'Terlambat', s: 'T', w: 'tahfizh', b: 2 }, cuti: { n: 'Cuti', s: 'C', w: 'agenda', b: 3 },
  izin: { n: 'Izin', s: 'I', w: 'pengajuan', b: 4 }, sakit: { n: 'Sakit', s: 'S', w: 'klinik', b: 5 },
  menunggu_verval: { n: 'Menunggu verval', s: 'V', w: 'shift', b: 6 }, tanpa_keterangan: { n: 'Tanpa keterangan', s: 'A', w: 'beranda', b: 7 },
}
export const JENIS_LAPORAN = {
  ringkas: { n: 'Rekap ringkas', ket: 'Jumlah setiap status per pegawai dan persentase' },
  matriks: { n: 'Rekap matriks', ket: 'Nama × tanggal, kertas mendatar' },
  individu: { n: 'Laporan individu', ket: 'Rincian per tanggal dan sesi' },
  perhatian: { n: 'Daftar perhatian', ket: 'Persentase di bawah ambang, untuk pembinaan' },
}

const iso = (d) => d.toISOString().slice(0, 10)
const tgl = (s) => new Date(s + 'T00:00:00Z')
export function tambahHari(s, n) { const d = tgl(s); d.setUTCDate(d.getUTCDate() + n); return iso(d) }
export function daftarTanggal(mulai, selesai) { const out = []; for (let d = mulai; d <= selesai; d = tambahHari(d, 1)) out.push(d); return out }
export const hariSingkat = (s) => HARI[tgl(s).getUTCDay()].slice(0, 3)

/** Pilihan periode cepat; hasil { mulai, selesai } (semester dibatasi sampai hari ini). */
export function periodeCepat(k) {
  const h = hariIniISO(); const d = tgl(h)
  if (k === 'hari') return { mulai: h, selesai: h }
  if (k === 'pekan') { const geser = (d.getUTCDay() + 6) % 7; return { mulai: tambahHari(h, -geser), selesai: h } }
  if (k === 'bulan') return { mulai: h.slice(0, 8) + '01', selesai: h }
  if (k === 'bulan_lalu') {
    const awal = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() - 1, 1)); const akhir = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), 0))
    return { mulai: iso(awal), selesai: iso(akhir) }
  }
  if (k === 'semester') { const m = d.getUTCMonth(); const awal = new Date(Date.UTC(d.getUTCFullYear(), m >= 6 ? 6 : 0, 1)); return { mulai: iso(awal), selesai: h } }
  return { mulai: h, selesai: h }
}
export const PERIODE_CEPAT = [{ k: 'hari', n: 'Hari ini' }, { k: 'pekan', n: 'Pekan ini' }, { k: 'bulan', n: 'Bulan ini' }, { k: 'bulan_lalu', n: 'Bulan lalu' }, { k: 'semester', n: 'Semester ini' }]

/** Keterangan per pegawai (kolom Keterangan rekap ringkas). */
export function keteranganPegawai(p) {
  const out = []
  const berizin = [['izin', 'izin'], ['sakit', 'sakit'], ['cuti', 'cuti']].filter(([k]) => p[k]).map(([k, n]) => `${n} ${p[k]}`)
  if (berizin.length) out.push(`${berizin.join(', ')} sesi (berizin)`)
  if (p.tidak_presensi) out.push(`${p.tidak_presensi} sesi tidak presensi`)
  else if (p.tanpa_keterangan) out.push(`${p.tanpa_keterangan} sesi tanpa keterangan`)
  if (p.menunggu) out.push(`${p.menunggu} sesi menunggu verval`)
  if (p.tidak_presensi_pulang) out.push(`${p.tidak_presensi_pulang} kali tidak presensi pulang`)
  return out.join('; ')
}

/** Matriks: { [employee_id]: { [tanggal]: kode } } dengan status terberat hari itu. */
export function susunMatriks(rinci) {
  const m = {}
  for (const r of rinci || []) {
    const st = STATUS_HADIR[r.status]; if (!st) continue
    const baris = (m[r.employee_id] ||= {}); const lama = baris[r.tanggal]
    if (!lama || STATUS_HADIR[lama].b < st.b) baris[r.tanggal] = r.status
  }
  return m
}
export const persenTeks = (v) => (v == null ? '–' : `${String(v).replace('.', ',')}%`)
