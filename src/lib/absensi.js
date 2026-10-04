// SIMKA PRO | src/lib/absensi.js | v1.0 | Fase 4 – Tahap 3 Absensi HISBAT | 04/10/2026
// Kode HISBAT, label sesi, dan ringkasan kehadiran santri. Di aplikasi kode dipakai agar cepat diketuk;
// pada laporan cetak status ditulis dengan kata lengkap.
export const KODE = {
  H: { n: 'Hadir', w: 'presensi' },
  I: { n: 'Izin', w: 'pengajuan' },
  S: { n: 'Sakit', w: 'klinik' },
  B: { n: 'Bolos', w: 'tahfizh' },
  A: { n: 'Absen', w: 'beranda' },
  T: { n: 'Terlambat', w: 'laporan' },
}
export const URUT_KODE = ['H', 'I', 'S', 'B', 'A', 'T']
export const JENIS_ABSENSI = {
  kelas: { n: 'Kelas', pengampu: 'Wali kelas', warna: 'laporan', fitur: 'absensi_kelas' },
  halaqah: { n: 'Halaqah', pengampu: 'Muhaffizh', warna: 'tahfizh', fitur: 'absensi_halaqah' },
  asrama: { n: 'Asrama', pengampu: 'Musyrif', warna: 'santri', fitur: 'absensi_asrama' },
}
export const STATUS_SESI = {
  terisi: { n: 'Sudah diisi', w: 'presensi' },
  terbuka: { n: 'Sedang berlangsung', w: 'shift' },
  lewat: { n: 'Belum diisi', w: 'klinik' },
  belum_buka: { n: 'Belum dibuka', w: 'hakakses' },
  tidak_terisi: { n: 'Tidak diisi', w: 'klinik' },
}
export const jam = (t) => String(t || '').slice(0, 5).replace(':', '.')
export const persen = (hadir, sesi) => (sesi ? Math.round((hadir / sesi) * 1000) / 10 : null)
export const teksPersen = (p) => (p == null ? '–' : `${String(p).replace('.', ',')}%`)

/**
 * Gabungkan baris rekap_absensi_santri menjadi per santri: { kelas, halaqah, asrama, pokok } masing-masing
 * { sesi, hadir, izin, sakit, bolos, absen, terlambat }. Program pokok = kelas + halaqah + asrama.
 */
export function susunRekap(baris) {
  const kosong = () => ({ sesi: 0, hadir: 0, izin: 0, sakit: 0, bolos: 0, absen: 0, terlambat: 0 })
  const peta = {}
  for (const r of baris) {
    const p = (peta[r.student_id] ||= { kelas: kosong(), halaqah: kosong(), asrama: kosong(), pokok: kosong() })
    for (const k of ['sesi', 'hadir', 'izin', 'sakit', 'bolos', 'absen', 'terlambat']) {
      if (p[r.jenis]) p[r.jenis][k] += r[k]
      if (['kelas', 'halaqah', 'asrama'].includes(r.jenis)) p.pokok[k] += r[k]
    }
  }
  return peta
}
/** Ringkasan untuk WA ke wali, mis. "Kelas 6/6, halaqah 17/18 (1 Sakit), asrama 12/12". */
export function teksRingkas(r) {
  if (!r) return 'Belum ada sesi tercatat.'
  return ['kelas', 'halaqah', 'asrama'].filter((j) => r[j].sesi).map((j) => {
    const x = r[j]
    const ket = [x.izin && `${x.izin} Izin`, x.sakit && `${x.sakit} Sakit`, x.absen && `${x.absen} Absen`, x.bolos && `${x.bolos} Bolos`, x.terlambat && `${x.terlambat} Terlambat`].filter(Boolean)
    return `${JENIS_ABSENSI[j].n} ${x.hadir}/${x.sesi}${ket.length ? ` (${ket.join(', ')})` : ''}`
  }).join(', ') || 'Belum ada sesi tercatat.'
}
