// SIMKA PRO | src/lib/jadwal.js | v1.1 | Perbaikan 13.6.0: jam pelajaran per hari (reguler/Jumat/Sabtu), warna dan sub-tab jenjang | 15/10/2026
// Hari sekolah, jenis jam per hari (reguler/Jumat/Sabtu, dapat diatur per jenjang), label mapel, warna jenjang,
// dan pengelompokan jam pelajaran berurutan.
export const HARI_SEKOLAH = [1, 2, 3, 4, 5, 6]          // Senin … Sabtu (Ahad libur sekolah)
export const HARI_JUMAT = 5
/** Jenis jam bawaan: Jumat memakai jam Jumat, hari lain jam reguler. Pembagian sebenarnya per jenjang: store jadwal → jenisHariUntuk(). */
export const jenisHari = (h) => (Number(h) === HARI_JUMAT ? 'jumat' : 'reguler')
/** Kumpulan jam pelajaran yang dapat dipakai sebuah hari */
export const JENIS_JAM = { reguler: 'Jam reguler', jumat: 'Jam Jumat', sabtu: 'Jam Sabtu' }
/** Pembagian bawaan hari → kumpulan jam (sama dengan sebelum pengaturan per hari ada) */
export const HARI_JAM_BAWAAN = { 1: 'reguler', 2: 'reguler', 3: 'reguler', 4: 'reguler', 5: 'jumat', 6: 'reguler' }
/** Sub-tab dan warna jenjang (dipakai di Jadwal Pelajaran dan Guru Mapel) */
export const JENJANG_TAB = { wustha: { n: 'Wustha (SMP)', w: 'tahfizh' }, sma: { n: 'SMA', w: 'pegawai' } }
export const warnaJenjang = (j) => JENJANG_TAB[j]?.w || 'jadwal'
export const KELOMPOK_MAPEL = { umum: 'Umum', pondok: 'Kepesantrenan', muatan_lokal: 'Muatan lokal' }
export const JENJANG_MAPEL = { semua: 'Wustha dan SMA', wustha: 'Kesetaraan Wustha', sma: 'SMA' }
export const jamPendek = (t) => String(t || '').slice(0, 5).replace(':', '.')

/** Kelompokkan jam pelajaran berurutan dengan penugasan yang sama (mis. Matematika jam ke-1–2) menjadi satu blok. */
export function blokMengajar(slot) {
  const j5 = (t) => String(t || '').slice(0, 5)
  const urut = [...slot].sort((a, b) => j5(a.jam_mulai).localeCompare(j5(b.jam_mulai)))
  const blok = []
  for (const s of urut) {
    const akhir = blok[blok.length - 1]
    // Bersambung bila penugasan sama dan jam mulai = jam selesai blok sebelumnya (tanpa istirahat di antaranya)
    if (akhir && akhir.assignment_id === s.assignment_id && j5(akhir.jam_selesai) === j5(s.jam_mulai)) { akhir.slot.push(s); akhir.jam_selesai = s.jam_selesai }
    else blok.push({ ...s, slot: [s], kunci: `${s.assignment_id}-${s.period_id}` })
  }
  return blok
}
