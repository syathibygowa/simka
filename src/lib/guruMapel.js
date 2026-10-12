// SIMKA PRO | src/lib/guruMapel.js | v1.0 | Fase 4 – Menu Guru Mapel dan Wali Kelas | 12/10/2026
// Pengolahan slot mengajar (hasil slot_mengajar): status per jam pelajaran, rekap per guru, per mapel, dan teks WA pengingat.
import { formatHari } from './tanggal'

export const STATUS_JP = {
  terlaksana: { n: 'Terlaksana', w: 'presensi' },
  tidak_terlaksana: { n: 'Tidak terlaksana', w: 'klinik' },
  belum: { n: 'Belum diisi', w: 'tahfizh' },
  akan: { n: 'Belum dimulai', w: 'hakakses' },
}
/** Status tampilan: jam yang belum selesai dan belum diisi = "Belum dimulai". */
export const statusSlot = (s) => (s.status === 'belum' && !s.lewat ? 'akan' : s.status)
export const persenJP = (a, b) => (b ? Math.round((a / b) * 1000) / 10 : null)

/** Kelompokkan slot (hanya yang sudah lewat dihitung terjadwal) menurut kunci. */
function kelompokkan(slot, kunci, isi) {
  const m = new Map()
  for (const s of slot) {
    const k = kunci(s); const r = m.get(k) || { ...isi(s), terjadwal: 0, terlaksana: 0, tidak: 0, kosong: 0, hari_ini: 0, hari_ini_isi: 0, kelas: new Set(), mapel: new Set(), slot: [] }
    r.slot.push(s); r.kelas.add(s.kelas); r.mapel.add(s.mapel)
    if (s.lewat) { r.terjadwal++; if (s.status === 'terlaksana') r.terlaksana++; else if (s.status === 'tidak_terlaksana') r.tidak++; else r.kosong++ }
    m.set(k, r)
  }
  return [...m.values()].map((r) => ({ ...r, kelas: [...r.kelas].filter(Boolean).sort(), mapel: [...r.mapel].filter(Boolean).sort(), persen: persenJP(r.terlaksana, r.terjadwal) }))
}
/** Rekap per guru: { employee_id, guru, niy, no_hp, terjadwal, terlaksana, tidak, kosong, persen, kelas[], mapel[], slot[] } */
export const rekapGuru = (slot) => kelompokkan(slot, (s) => s.employee_id, (s) => ({ employee_id: s.employee_id, guru: s.guru, niy: s.niy, no_hp: s.no_hp }))
  .sort((a, b) => String(a.guru).localeCompare(String(b.guru), 'id'))
/** Rekap per penugasan (kelas + mapel): { assignment_id, kelas, mapel, guru, … } */
export const rekapPenugasan = (slot) => kelompokkan(slot, (s) => s.assignment_id, (s) => ({ assignment_id: s.assignment_id, kelas_nama: s.kelas, mapel_nama: s.mapel, guru: s.guru, employee_id: s.employee_id }))
  .sort((a, b) => String(a.kelas_nama).localeCompare(String(b.kelas_nama), 'id', { numeric: true }) || String(a.mapel_nama).localeCompare(String(b.mapel_nama), 'id'))

/** Warna persentase keterlaksanaan. */
export const warnaPersen = (p) => (p == null ? 'hakakses' : p >= 95 ? 'presensi' : p >= 85 ? 'agenda' : p >= 75 ? 'laporan' : 'beranda')

/** Pesan WA pengingat jurnal mengajar yang belum diisi. */
export function pesanPengingatJurnal(nama, slot) {
  const baris = slot.map((s) => `• ${formatHari(s.tanggal)}, ${s.jam_ke} (${s.jam_mulai}–${s.jam_selesai}): ${s.mapel} kelas ${s.kelas}`).join('\n')
  return `Assalamu'alaikum warahmatullahi wabarakatuh, ${nama}.\n\nMohon izin mengingatkan, jurnal mengajar berikut belum diisi di SIMKA PRO:\n${baris}\n\n`
    + 'Silakan isi melalui menu Jurnal Harian → Jurnal mengajar (batas pengisian H+1). Jazakumullahu khairan.'
}
