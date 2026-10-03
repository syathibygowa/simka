// SIMKA PRO | src/lib/shift.js | v1.0 | Fase 2 – Tahap 5 Jadwal shift | 03/10/2026
// Bantuan jadwal shift: tanggal pekan, pembuat jadwal bergilir, dan pemeriksaan keterisian.

/** yyyy-mm-dd + n hari */
export function tambahHari(iso, n) {
  const d = new Date(iso + 'T00:00:00Z'); d.setUTCDate(d.getUTCDate() + n)
  return d.toISOString().slice(0, 10)
}
/** 0 = Ahad … 6 = Sabtu */
export const hariKe = (iso) => new Date(iso + 'T00:00:00Z').getUTCDay()
/** Senin pada pekan tanggal tersebut */
export const seninDari = (iso) => tambahHari(iso, -((hariKe(iso) + 6) % 7))
/** Tujuh tanggal Senin–Ahad mulai senin */
export const tanggalPekan = (senin) => Array.from({ length: 7 }, (_, i) => tambahHari(senin, i))

/**
 * Jadwal bergilir maju (pagi → siang → malam → libur) yang adil.
 * Pola dasar sepanjang N × blok hari: setiap sesi mendapat "blok" hari berurutan,
 * sisanya libur. Pegawai ke-i memakai pola yang digeser i × blok hari, sehingga
 * setiap hari setiap sesi diisi tepat satu orang dan hari libur bergantian.
 *   pegawai : [id] berurutan (urutan menentukan giliran)
 *   sesi    : [id] berurutan (contoh: pagi, siang, malam)
 *   mulai   : 'yyyy-mm-dd';  hari: jumlah hari;  blok: 1–3 hari berturut per sesi
 *   geser   : putaran awal (untuk melanjutkan giliran periode sebelumnya)
 * Mengembalikan [{ employee_id, tanggal, session_id }]
 */
export function buatBergilir({ pegawai, sesi, mulai, hari, blok = 2, geser = 0 }) {
  const N = pegawai.length; const k = sesi.length
  if (!k) throw new Error('Pola ini belum memiliki sesi shift yang aktif.')
  if (N < k) throw new Error(`Butuh minimal ${k} pegawai untuk ${k} shift per hari.`)
  const panjang = N * blok
  const pola = Array.from({ length: panjang }, (_, i) => { const b = Math.floor(i / blok); return b < k ? sesi[b] : null })
  const hasil = []
  for (let d = 0; d < hari; d++) {
    const tanggal = tambahHari(mulai, d)
    pegawai.forEach((emp, i) => {
      const s = pola[(((d + geser + i * blok) % panjang) + panjang) % panjang]
      if (s) hasil.push({ employee_id: emp, tanggal, session_id: s })
    })
  }
  return hasil
}

/** Ringkasan per pegawai: jumlah shift per sesi dan jumlah hari libur pada rentang */
export function ringkasPegawai(roster, pegawai, sesi, tanggal) {
  return pegawai.map((p) => {
    const milik = roster.filter((r) => r.employee_id === p.id && tanggal.includes(r.tanggal))
    const perSesi = Object.fromEntries(sesi.map((s) => [s.id, milik.filter((r) => r.session_id === s.id).length]))
    const hariKerja = new Set(milik.map((r) => r.tanggal)).size
    return { ...p, perSesi, total: milik.length, libur: tanggal.length - hariKerja }
  })
}

/** Sel kosong (sesi tanpa petugas) dan sel ganda pada rentang tanggal */
export function periksaKeterisian(roster, sesi, tanggal) {
  const kosong = []; const ganda = []
  for (const t of tanggal) for (const s of sesi) {
    const n = roster.filter((r) => r.tanggal === t && r.session_id === s.id).length
    if (!n) kosong.push({ tanggal: t, sesi: s }); else if (n > 1) ganda.push({ tanggal: t, sesi: s, n })
  }
  return { kosong, ganda }
}

export const STATUS_TUKAR = {
  menunggu_rekan: { n: 'Menunggu jawaban rekan', w: 'tahfizh' },
  menunggu_admin: { n: 'Menunggu persetujuan admin', w: 'pengajuan' },
  disetujui: { n: 'Disetujui', w: 'presensi' },
  ditolak: { n: 'Ditolak', w: 'klinik' },
  dibatalkan: { n: 'Dibatalkan', w: 'hakakses' },
}
