// SIMKA PRO | src/lib/urutan.js | v1.0 | 14.27.0: urutan halaman isian (Sebelumnya/Berikutnya) | 26/10/2026
// Halaman daftar (absensi hari ini, dasbor wali kelas/musyrif, setoran, ekskul, Tugas hari ini, daftar lembar nilai) menyimpan
// urutan item yang sedang tampil sebelum membuka satu isian. Halaman isian (Isi Absensi, Lembar Nilai) membacanya untuk tombol
// Sebelumnya dan Berikutnya. Disimpan di sessionStorage (per tab peramban); bila kosong tombol tidak tampil.
const KUNCI = 'simka.urutan.'
/** daftar: [{ ke: '/path' | { path, query }, label }] */
export function aturUrutan(jenis, daftar) {
  try { sessionStorage.setItem(KUNCI + jenis, JSON.stringify((daftar || []).filter((x) => x?.ke))) } catch { /* abaikan */ }
}
export function bacaUrutan(jenis) {
  try { return JSON.parse(sessionStorage.getItem(KUNCI + jenis) || '[]') } catch { return [] }
}
const jalur = (ke) => (typeof ke === 'string' ? ke : ke?.path || '')
/** Tetangga untuk path sekarang: { sebelum, sesudah, posisi (1-based), total } atau null bila path tidak ada di urutan. */
export function tetangga(jenis, pathKini) {
  const d = bacaUrutan(jenis); const i = d.findIndex((x) => jalur(x.ke) === pathKini)
  if (i < 0) return null
  return { sebelum: d[i - 1] || null, sesudah: d[i + 1] || null, posisi: i + 1, total: d.length }
}
/** Jalur isi absensi satu sesi. */
export const keAbsensi = (s, grup = null) => `/absensi-santri/isi/${grup || s.group_id}/${s.tanggal}/${s.sesi || s.kode}`
