// SIMKA PRO | src/lib/demoKelompok.js | v1.1 | Fase 4 – Tahap 6 Tahun ajaran, statistik, laporan | 05/10/2026
// Kelompok santri contoh untuk MODE DEMO (dibangun dari data santri contoh). Pengasuh memakai id pegawai contoh (p1 = Ust. Hasan Basri).
const TA = { id: 'ta1', nama: '2026/2027', mulai: '2026-07-13', selesai: '2027-06-30', aktif: true, terkunci: false }
const hariIni = () => new Date().toISOString().slice(0, 10)

let data = null
/** Satu salinan data demo bersama untuk store santri dan store kelompok. */
export function dataKelompokDemo(santri) {
  if (data) return data
  const g = (id, jenis, nama, extra = {}) => ({ id, academic_year_id: TA.id, jenis, nama, jenjang: null, tingkat: null, jenis_kelamin: null, keterangan: null,
    wa_wali: null, wa_internal: null, naqib_id: null, aktif: true, urutan: 0, tahun_ajaran: TA.nama, ta_aktif: true, ta_terkunci: false, ...extra })
  const kelompok = [
    g('g-7a', 'kelas', '7A', { jenjang: 'wustha', tingkat: 7, jenis_kelamin: 'L', wa_wali: 'https://chat.whatsapp.com/contoh7A' }),
    g('g-7b', 'kelas', '7B', { jenjang: 'wustha', tingkat: 7, jenis_kelamin: 'P' }),
    g('g-8a', 'kelas', '8A', { jenjang: 'wustha', tingkat: 8 }),
    g('g-9a', 'kelas', '9A', { jenjang: 'wustha', tingkat: 9 }),
    g('g-10a', 'kelas', '10A', { jenjang: 'sma', tingkat: 10 }),
    g('g-11a', 'kelas', '11A', { jenjang: 'sma', tingkat: 11 }),
    g('g-12a', 'kelas', '12A', { jenjang: 'sma', tingkat: 12 }),
    g('g-kab', 'kamar', 'Kamar Abu Bakar', { jenis_kelamin: 'L', keterangan: 'Asrama Putra 1' }),
    g('g-kum', 'kamar', 'Kamar Umar', { jenis_kelamin: 'L', keterangan: 'Asrama Putra 1' }),
    g('g-kai', 'kamar', 'Kamar Aisyah', { jenis_kelamin: 'P', keterangan: 'Asrama Putri' }),
    g('g-hhb', 'halaqah', 'Halaqah Ust. Hasan', { jenis_kelamin: 'L' }),
    g('g-hkh', 'halaqah', 'Halaqah Ustzh. Khadijah', { jenis_kelamin: 'P' }),
    g('g-epn', 'ekskul', 'Panahan', { keterangan: 'Selasa dan Kamis sore' }),
    g('g-epr', 'ekskul', 'Pramuka', { keterangan: 'Sabtu pagi' }),
  ]
  const pengasuh = {
    'g-7a': [['p1', 'utama']], 'g-7b': [['p2', 'utama']], 'g-8a': [['p12', 'utama']], 'g-10a': [['p6', 'utama']],
    'g-kab': [['p3', 'utama'], ['p12', 'pendamping']], 'g-kum': [['p12', 'utama']], 'g-hhb': [['p1', 'utama']], 'g-hkh': [['p7', 'utama']], 'g-epn': [['p6', 'utama']],
  }
  const NAMA_P = { p1: 'Ust. Hasan Basri, Lc.', p2: 'Ustzh. Nurul Aini, S.Pd.', p3: 'Ust. Muhammad Ikhsan, S.Pd.I.', p6: 'Ust. Yusuf Maulana, S.Pd.', p7: 'Ustzh. Khadijah Ramadhani, S.Ag.', p12: 'Ust. Syamsul Arifin, S.Pd.' }
  kelompok.forEach((k) => { k.pengasuh = (pengasuh[k.id] || []).map(([e, peran]) => ({ employee_id: e, nama: NAMA_P[e], niy: null, peran, mulai: null, sampai: null, berlaku: true, no_hp: '081234500000' })) })
  const anggota = []
  const masuk = (gid, sid) => anggota.push({ id: `m${anggota.length + 1}`, group_id: gid, student_id: sid, mulai: '2026-07-13', selesai: null, alasan_keluar: null })
  santri.filter((s) => ['aktif', 'nonaktif'].includes(s.status)).forEach((s, i) => {
    const kelas = kelompok.find((k) => k.jenis === 'kelas' && k.tingkat === s.tingkat && (!k.jenis_kelamin || k.jenis_kelamin === s.jenis_kelamin))
    if (kelas && i % 9 !== 4) masuk(kelas.id, s.id)
    const kamar = kelompok.filter((k) => k.jenis === 'kamar' && k.jenis_kelamin === s.jenis_kelamin)
    if (i % 7 !== 3) masuk(kamar[i % kamar.length].id, s.id)
    masuk(s.jenis_kelamin === 'L' ? 'g-hhb' : 'g-hkh', s.id)
    if (i % 3 === 0) masuk('g-epn', s.id)
    if (i % 4 === 1) masuk('g-epr', s.id)
  })
  kelompok.find((k) => k.id === 'g-hhb').naqib_id = anggota.find((a) => a.group_id === 'g-hhb')?.student_id || null
  data = { kelompok, anggota, ta: [TA] }
  return data
}
/** Kelompok aktif seorang santri (kolom "kelompok" pada v_santri). */
export function kelompokSantriDemo(id) {
  if (!data) return []
  const URUT = ['kelas', 'kamar', 'halaqah', 'ekskul', 'lainnya']
  return data.anggota.filter((a) => a.student_id === id && !a.selesai)
    .map((a) => data.kelompok.find((k) => k.id === a.group_id)).filter((k) => k && k.aktif)
    .map((k) => ({ id: k.id, jenis: k.jenis, nama: k.nama })).sort((a, b) => URUT.indexOf(a.jenis) - URUT.indexOf(b.jenis))
}
export const ID_PEGAWAI_DEMO = 'p1' // akun demo "Pegawai" = Ust. Hasan Basri
export { hariIni as hariIniDemo }
