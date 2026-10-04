// SIMKA PRO | src/lib/jadwal.js | v1.0 | Fase 4 – Tahap 5 Jadwal pelajaran dan jurnal mengajar | 04/10/2026
// Hari sekolah, jenis hari (reguler/Jumat), label mapel, dan pengelompokan jam pelajaran berurutan.
export const HARI_SEKOLAH = [1, 2, 3, 4, 5, 6]          // Senin … Sabtu (Ahad libur sekolah)
export const HARI_JUMAT = 5
export const jenisHari = (h) => (Number(h) === HARI_JUMAT ? 'jumat' : 'reguler')
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
