// SIMKA PRO | src/lib/demoJurnal.js | v1.0 | Fase 3 – Tahap 3 Jurnal harian | 04/10/2026
// Data contoh jurnal harian untuk MODE DEMO.
const hariIni = () => new Date(Date.now() + 8 * 3600000).toISOString().slice(0, 10)
const geser = (iso, n) => new Date(Date.parse(iso + 'T00:00:00Z') + n * 86400000).toISOString().slice(0, 10)
const BUTIR = [
  ['f-MUHAFFIZH', 'Muhaffizh/Muhaffizhah', ['Membimbing halaqah subuh', 'Membimbing halaqah sore', 'Membimbing halaqah malam', 'Mencatat setoran sabaq, sabqi, dan manzil', 'Memotivasi santri yang hafalannya tertinggal']],
  ['f-WALI_KELAS', 'Wali kelas', ['Mengabsen santri di kelas', 'Memantau kerapian dan kedisiplinan santri kelas', 'Menindaklanjuti santri yang tidak hadir']],
]
let SIMPAN = {}
function butirHari(tgl) {
  const s = SIMPAN[tgl] || (SIMPAN[tgl] = { cek: tgl < hariIni() ? { 'f-MUHAFFIZH-0': 'Lancar', 'f-MUHAFFIZH-1': null, 'f-MUHAFFIZH-3': null } : { 'f-MUHAFFIZH-0': null }, kegiatan: tgl === hariIni()
    ? [{ id: 'k1', jam_mulai: '09:00:00', jam_selesai: '10:30:00', uraian: 'Menyusun rencana ujian kenaikan juz bersama koordinator tahfizh.', status: 'menunggu' }]
    : tgl === geser(hariIni(), -1) ? [{ id: 'k2', jam_mulai: '20:00:00', jam_selesai: '21:00:00', uraian: 'Rapat wali kelas Kesetaraan Wustha.', status: 'dikembalikan', catatan_verval: 'Lengkapi hasil rapat.' }] : [] })
  return s
}
export function hari(tgl) {
  const s = butirHari(tgl)
  return { tanggal: tgl, terbuka: tgl <= hariIni() && tgl >= geser(hariIni(), -1), wajib: true, butir_lama: [],
    butir: BUTIR.flatMap(([k, kel, d]) => d.map((u, i) => { const id = `${k}-${i}`; return { item_id: id, kelompok: kel, uraian: u, selesai: id in s.cek, catatan: s.cek[id] || null } })),
    kegiatan: s.kegiatan }
}
export function simpanKegiatan(isi) {
  const s = butirHari(isi.tanggal)
  if (isi.id) Object.assign(s.kegiatan.find((k) => k.id === isi.id), isi, { status: 'menunggu' })
  else s.kegiatan.push({ ...isi, id: 'k' + Date.now(), status: 'menunggu' })
}
let ANTRIAN = null
export function antrian(status) {
  ANTRIAN = ANTRIAN || [
    ['Ust. Hasan Basri, Lc.', 'Bidang Tahfizh', 0, '09:00', '10:30', 'Menyusun rencana ujian kenaikan juz bersama koordinator tahfizh.'],
    ['Ustzh. Nurul Aini, S.Pd.', 'Bidang Kesetaraan Wustha', 0, '13:30', '15:00', 'Mendampingi lomba cerdas cermat santri di Sungguminasa.'],
    ['Ust. Muhammad Ikhsan, S.Pd.I.', 'Bidang Kesantrian', -1, '21:00', '23:00', 'Menangani santri sakit malam hari dan mengantar ke klinik.'],
  ].map(([nama, unit, h, m, s, u], i) => ({ id: 'a' + i, employee_id: 'p' + i, nama, unit, tanggal: geser(hariIni(), h), jam_mulai: m + ':00', jam_selesai: s + ':00', uraian: u, status: 'menunggu', created_at: new Date().toISOString() }))
  return ANTRIAN.filter((a) => a.status === status)
}
export function verval(ids, setuju, catatan) { ANTRIAN.forEach((a) => { if (ids.includes(a.id)) Object.assign(a, { status: setuju ? 'disetujui' : 'dikembalikan', catatan_verval: catatan, diverval_pada: new Date().toISOString() }) }) }
export function rekap(sesi) {
  const r = [['Ust. Hasan Basri, Lc.', 'Bidang Tahfizh', 22, 21], ['Ustzh. Nurul Aini, S.Pd.', 'Bidang Kesetaraan Wustha', 22, 18], ['Ust. Muhammad Ikhsan, S.Pd.I.', 'Bidang Kesantrian', 26, 26],
    ['Ust. Abdul Hakim', 'Unit Security', 20, 12], ['Ustzh. Fatimah Az-Zahra, A.Md.Kep.', 'Unit Klinik', 22, 20]]
    .map(([nama, unit, w, t], i) => ({ employee_id: i === 0 ? 'd-pg' : 'p' + i, nama, niy: '20190701' + i, unit, hari_wajib: w, hari_terisi: t, hari_kosong: w - t, persen: Math.round((1000 * t) / w) / 10,
      butir: t * 4, kegiatan_disetujui: i + 2, kegiatan_menunggu: i % 2, kegiatan_dikembalikan: i === 3 ? 1 : 0 }))
  return sesi.peran === 'pegawai' ? r.filter((x) => x.employee_id === 'd-pg') : r
}
export function individu(mulai, akhir) {
  const out = []
  for (let d = mulai; d <= akhir && d <= hariIni(); d = geser(d, 1)) {
    const kosong = d.endsWith('3') || d.endsWith('8')
    out.push({ tanggal: d, wajib: new Date(d + 'T00:00:00Z').getUTCDay() !== 0, terkunci: d < geser(hariIni(), -1),
      butir: kosong ? [] : [{ uraian: 'Membimbing halaqah subuh' }, { uraian: 'Membimbing halaqah malam' }, { uraian: 'Mencatat setoran sabaq, sabqi, dan manzil' }],
      kegiatan: d.endsWith('5') ? [{ jam_mulai: '09:00:00', jam_selesai: '10:00:00', uraian: 'Rapat koordinasi tahfizh', status: 'disetujui' }] : [] })
  }
  return out
}
export function template() {
  return BUTIR.flatMap(([k, , d]) => d.map((u, i) => ({ id: `${k}-${i}`, functional_position_id: { 'f-MUHAFFIZH': 'f2', 'f-WALI_KELAS': 'f1' }[k], structural_position_id: null, org_unit_id: null, uraian: u, urutan: i + 1, aktif: true })))
}
