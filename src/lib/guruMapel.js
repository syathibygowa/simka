// SIMKA PRO | src/lib/guruMapel.js | v1.1 | 14.32.0: posting jadwal mengajar hari ini ke WA dan pengingat rekap jurnal per guru | 29/10/2026
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

// ---------- 14.32.0: WhatsApp pantauan guru ----------
const IKON_JP = { terlaksana: '✅', tidak_terlaksana: '❌', belum: '⏳', akan: '🕒' }
const jam5 = (j) => String(j || '').slice(0, 5).replace(':', '.')
const JUDUL_SARING = { '': '', belum: 'Belum diisi', tidak_terlaksana: 'Tidak terlaksana', terlaksana: 'Terlaksana' }
/**
 * Teks jadwal mengajar satu hari untuk grup WhatsApp. Tanda mengikuti jurnal: ✅ terlaksana, ❌ tidak terlaksana, ⏳ jam lewat tetapi
 * jurnal belum diisi, 🕒 belum dimulai. format: 'jam' (urut jam pelajaran) | 'guru' (per guru). saring: '' | belum | tidak_terlaksana | terlaksana.
 */
export function teksJadwalHariIniWA(slot, { tanggal, jenjang = '', saring = '', format = 'jam', tautan = '' } = {}) {
  const st = (s) => statusSlot(s)
  const pilih = slot.filter((s) => !saring || (saring === 'belum' ? s.lewat && s.status === 'belum' : s.status === saring))
  const n = (f) => slot.filter(f).length; const lewat = slot.filter((s) => s.lewat)
  const kepala = [`*JADWAL MENGAJAR HARI INI${jenjang ? ' · ' + (jenjang === 'sma' ? 'SMA' : 'WUSTHA') : ''}*`, `🗓️ ${formatHari(tanggal)}`,
    saring ? `Saringan: *${JUDUL_SARING[saring]}*` : '',
    `Terlaksana ${n((s) => s.status === 'terlaksana')}/${lewat.length} jam yang sudah lewat · ⏳ belum diisi ${n((s) => s.lewat && s.status === 'belum')} · ❌ tidak terlaksana ${n((s) => s.status === 'tidak_terlaksana')} · 🕒 belum dimulai ${n((s) => !s.lewat && s.status === 'belum')}`, '']
  const badan = []
  const baris = (s, denganGuru = true) => `${IKON_JP[st(s)]} ${s.kelas} · ${s.mapel}${denganGuru ? ' – ' + s.guru : ''}${s.status === 'tidak_terlaksana' && s.keterangan ? ` (${s.keterangan})` : ''}`
  if (format === 'guru') {
    const per = new Map(); for (const s of pilih) { if (!per.has(s.guru)) per.set(s.guru, []); per.get(s.guru).push(s) }
    for (const [g, xs] of [...per.entries()].sort((a, b) => String(a[0]).localeCompare(String(b[0]), 'id'))) {
      badan.push(`*${g}*`); xs.sort((a, b) => String(a.jam_mulai).localeCompare(String(b.jam_mulai)))
      for (const s of xs) badan.push(`${IKON_JP[st(s)]} ${jam5(s.jam_mulai)} · ${s.kelas} · ${s.mapel}${s.status === 'tidak_terlaksana' && s.keterangan ? ` (${s.keterangan})` : ''}`)
      badan.push('')
    }
  } else {
    const per = new Map(); for (const s of pilih) { const k = `${s.jam_ke ?? ''}|${s.jam_mulai}|${s.jam_selesai}`; if (!per.has(k)) per.set(k, []); per.get(k).push(s) }
    for (const [k, xs] of [...per.entries()].sort((a, b) => a[0].split('|')[1].localeCompare(b[0].split('|')[1]))) {
      const [ke, m, e] = k.split('|')
      badan.push(`*${ke ? (/^jam/i.test(ke) ? ke : 'Jam ke-' + ke) + ' ' : ''}(${jam5(m)}–${jam5(e)})*`)
      xs.sort((a, b) => String(a.kelas).localeCompare(String(b.kelas), 'id', { numeric: true })).forEach((s) => badan.push(baris(s)))
      badan.push('')
    }
  }
  if (!pilih.length) badan.push(saring ? 'Tidak ada jam pelajaran dengan status ini.' : 'Tidak ada jam pelajaran terjadwal hari ini.', '')
  const kaki = ['Keterangan: ✅ terlaksana · ❌ tidak terlaksana · ⏳ jam lewat, jurnal belum diisi · 🕒 belum dimulai',
    'Mohon Bapak/Ibu guru yang bertanda ⏳ segera mengisi jurnal mengajar di SIMKA PRO.', tautan ? tautan : '']
  return [...kepala, ...badan, ...kaki].filter((x, i, a) => !(x === '' && a[i - 1] === '')).join('\n').trim()
}

/** Pengingat pribadi rekap periode: ringkasan jurnal terisi dan daftar jam yang belum diisi/belum lengkap. */
export function pesanRekapJurnalGuru(g, { rentang = '', tautan = '' } = {}) {
  const belum = g.slot.filter((s) => s.lewat && s.status === 'belum').sort((a, b) => (a.tanggal + a.jam_mulai).localeCompare(b.tanggal + b.jam_mulai))
  const daftar = belum.slice(0, 25).map((s) => `• ${formatHari(s.tanggal)}, ${jam5(s.jam_mulai)}: ${s.mapel} kelas ${s.kelas}`)
  return [`Assalamu'alaikum warahmatullahi wabarakatuh, ${g.guru}.`, '', `Rekap jurnal mengajar ${rentang}:`,
    `✅ Terisi (terlaksana): ${g.terlaksana} JP`, g.tidak ? `❌ Tidak terlaksana (berketerangan): ${g.tidak} JP` : '', `⏳ Belum diisi: ${g.kosong} JP`,
    `Keterlaksanaan: ${g.persen ?? 0}% dari ${g.terjadwal} JP terjadwal.`, '',
    ...(belum.length ? ['Jurnal yang belum diisi:', ...daftar, belum.length > 25 ? `… dan ${belum.length - 25} JP lainnya.` : '', '',
      'Mohon dilengkapi melalui SIMKA PRO (Jurnal Harian → Jurnal mengajar).'] : ['Alhamdulillah, seluruh jurnal sudah terisi. Jazakumullahu khairan.']),
    tautan, '', 'Jazakumullahu khairan.'].filter((x, i, a) => !(x === '' && a[i - 1] === '')).join('\n').trim()
}
