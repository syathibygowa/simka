// SIMKA PRO | src/lib/demoJadwal.js | v1.0 | Fase 4 – Tahap 5 Jadwal pelajaran dan jurnal mengajar | 04/10/2026
// Mapel, jam pelajaran, penugasan, dan jadwal contoh untuk MODE DEMO (mengikuti isi awal migrasi 3600).
const MAPEL = [['PAI', 'Pendidikan Agama Islam', 'semua', 'umum'], ['PKN', 'Pendidikan Pancasila', 'semua', 'umum'], ['BIND', 'Bahasa Indonesia', 'semua', 'umum'],
  ['MTK', 'Matematika', 'semua', 'umum'], ['IPA', 'Ilmu Pengetahuan Alam', 'wustha', 'umum'], ['IPS', 'Ilmu Pengetahuan Sosial', 'wustha', 'umum'],
  ['BING', 'Bahasa Inggris', 'semua', 'umum'], ['FIS', 'Fisika', 'sma', 'umum'], ['BIO', 'Biologi', 'sma', 'umum'], ['INF', 'Informatika', 'semua', 'umum'],
  ['BARAB', 'Bahasa Arab', 'semua', 'pondok'], ['FIQIH', 'Fiqih', 'semua', 'pondok'], ['HADITS', 'Hadits', 'semua', 'pondok'], ['TAHSIN', 'Tahsin dan Tajwid', 'semua', 'pondok']]
const JAM = {
  'wustha|reguler': [['jp', '08:00', '08:40'], ['jp', '08:40', '09:20'], ['jp', '09:20', '10:00'], ['istirahat', '10:00', '10:20'], ['jp', '10:20', '11:00'], ['jp', '11:00', '11:40'], ['jp', '11:40', '12:20'], ['istirahat', '12:20', '13:00'], ['jp', '13:00', '13:40']],
  'sma|reguler': [['jp', '08:00', '08:45'], ['jp', '08:45', '09:30'], ['jp', '09:30', '10:15'], ['istirahat', '10:15', '10:35'], ['jp', '10:35', '11:20'], ['jp', '11:20', '12:05'], ['istirahat', '12:05', '12:45'], ['jp', '12:45', '13:30'], ['jp', '13:30', '14:15']],
  'wustha|jumat': [['jp', '08:00', '08:40'], ['jp', '08:40', '09:20'], ['istirahat', '09:20', '09:35'], ['jp', '09:35', '10:15'], ['jp', '10:15', '10:55']],
  'sma|jumat': [['jp', '08:00', '08:45'], ['jp', '08:45', '09:30'], ['istirahat', '09:30', '09:45'], ['jp', '09:45', '10:30'], ['jp', '10:30', '11:15']],
}
let data = null
export function dataJadwalDemo() {
  if (data) return data
  const mapel = MAPEL.map(([kode, nama, jenjang, kelompok], i) => ({ id: 'm-' + kode, kode, nama, jenjang, kelompok, aktif: true, urutan: i }))
  const jam = []
  for (const [k, baris] of Object.entries(JAM)) {
    const [jenjang, jenis_hari] = k.split('|'); let n = 0
    baris.forEach(([jenis, mulai, selesai], i) => { if (jenis === 'jp') n++; jam.push({ id: `p-${k}-${i + 1}`, jenjang, jenis_hari, urutan: i + 1, jenis, nama: jenis === 'jp' ? `Jam ke-${n}` : i > 4 ? 'Istirahat dan shalat Zuhur' : 'Istirahat', jam_mulai: mulai, jam_selesai: selesai }) })
  }
  const NAMA_G = { p1: 'Ust. Hasan Basri, Lc.', p2: 'Ustzh. Nurul Aini, S.Pd.', p6: 'Ust. Yusuf Maulana, S.Pd.', p10: 'Ustzh. Aisyah Putri, S.Pd.', p12: 'Ust. Syamsul Arifin, S.Pd.' }
  const tugas = [['g-7a', 'BARAB', 'p1', 4], ['g-7a', 'MTK', 'p12', 4], ['g-7a', 'BIND', 'p2', 4], ['g-7a', 'BING', 'p10', 3], ['g-8a', 'MTK', 'p12', 4], ['g-8a', 'BARAB', 'p1', 4],
    ['g-7b', 'BIND', 'p2', 4], ['g-7b', 'MTK', 'p12', 4], ['g-10a', 'FIS', 'p6', 3], ['g-10a', 'MTK', 'p6', 4], ['g-10a', 'BING', 'p10', 3]]
  const penugasan = tugas.map(([g, m, e, jp], i) => ({ id: `t${i + 1}`, group_id: g, subject_id: 'm-' + m, employee_id: e, nama_guru: NAMA_G[e], jp_pekan: jp, catatan: null }))
  // Jadwal: isi beberapa jam setiap hari sekolah secara bergilir
  const jadwal = []
  const KELAS = { 'g-7a': 'wustha', 'g-7b': 'wustha', 'g-8a': 'wustha', 'g-10a': 'sma' }
  for (const [g, jj] of Object.entries(KELAS)) {
    const milik = penugasan.filter((t) => t.group_id === g)
    for (let h = 1; h <= 6; h++) {
      const slot = jam.filter((p) => p.jenjang === jj && p.jenis_hari === (h === 5 ? 'jumat' : 'reguler') && p.jenis === 'jp')
      slot.forEach((p, i) => {
        const t = milik[(Math.floor(i / 2) + h + (g === 'g-8a' ? 1 : 0)) % milik.length]
        const bentrok = jadwal.some((x) => x.employee_id === t.employee_id && x.hari === h && x.period_id.split('-').pop() === p.id.split('-').pop())
        if (!bentrok) jadwal.push({ id: `s-${g}-${h}-${p.id}`, assignment_id: t.id, group_id: g, employee_id: t.employee_id, hari: h, period_id: p.id })
      })
    }
  }
  data = { mapel, jam, penugasan, jadwal, rencana: [{ id: 'r1', assignment_id: 't1', urutan: 1, topik: 'Mufradat: alat-alat sekolah' }, { id: 'r2', assignment_id: 't1', urutan: 2, topik: 'Hiwar: perkenalan' }], jurnal: [] }
  return data
}
