// SIMKA PRO | src/lib/demoPengajuan.js | v1.0 | Fase 3 – Tahap 2 Pengajuan berjenjang | 04/10/2026
// Data contoh pengajuan untuk MODE DEMO (tanpa server). Aturan inti meniru fungsi periksa_pengajuan di server.
import { hitungHari, PERAN_JENJANG } from './pengajuan'

const hari = (n) => new Date(Date.now() + 8 * 3600000 + n * 86400000).toISOString().slice(0, 10)
const lalu = (m) => new Date(Date.now() - m * 60000).toISOString()
const J = (kode, nama, kelompok, o = {}) => ({ id: 'j-' + kode, kode, nama, kelompok, status_presensi: kelompok, aktif: true, aturan_kuota: 'tolak',
  mundur_maks_hari: 0, maju_min_hari: 0, maju_maks_hari: null, maks_hari: null, kuota_tahunan_hari: null, batas_bulanan_hari: null, batas_bulanan_kali: null,
  lampiran_wajib_min_hari: null, lampiran_keterangan: null, khusus_jk: null, keterangan: '', ...o })
let JENIS = null
const jenisAwal = () => [
  J('SAKIT', 'Sakit', 'sakit', { urutan: 1, maks_hari: 3, maju_maks_hari: 0, lampiran_keterangan: 'Surat keterangan dokter atau foto resep (dianjurkan)', keterangan: 'Diajukan pada hari pertama sakit, paling lama 3 hari. Sakit lebih dari 3 hari diajukan sebagai Izin dengan bukti.' }),
  J('IZIN', 'Izin', 'izin', { urutan: 2, lampiran_wajib_min_hari: 4, lampiran_keterangan: 'Surat keterangan dokter, undangan, atau bukti lain yang relevan', keterangan: 'Untuk keperluan pribadi atau sakit lebih dari 3 hari.' }),
  J('DINAS_LUAR', 'Dinas luar', 'dinas_luar', { urutan: 3, lampiran_keterangan: 'Surat tugas atau undangan kegiatan', keterangan: 'Tugas resmi di luar pondok atas penugasan pimpinan.' }),
  J('CUTI_TAHUNAN', 'Cuti tahunan', 'cuti', { urutan: 4, maks_hari: 12, kuota_tahunan_hari: 12, maju_min_hari: 3, keterangan: 'Hak cuti tahunan pegawai.' }),
  J('CUTI_MELAHIRKAN', 'Cuti melahirkan', 'cuti', { urutan: 5, maks_hari: 90, lampiran_wajib_min_hari: 1, lampiran_keterangan: 'Surat keterangan dokter atau bidan', khusus_jk: 'P' }),
  J('CUTI_MENIKAH', 'Cuti menikah', 'cuti', { urutan: 6, maks_hari: 3, lampiran_wajib_min_hari: 1, lampiran_keterangan: 'Undangan atau surat keterangan pernikahan' }),
  J('CUTI_PENTING', 'Cuti alasan penting', 'cuti', { urutan: 7, maks_hari: 3, mundur_maks_hari: 1, keterangan: 'Keluarga inti meninggal dunia, sakit keras, atau musibah lain.' }),
  J('CUTI_IBADAH', 'Cuti ibadah haji/umrah', 'cuti', { urutan: 8, maks_hari: 45, maju_min_hari: 7, lampiran_wajib_min_hari: 1, lampiran_keterangan: 'Bukti pendaftaran atau jadwal keberangkatan' }),
  J('CUTI_LUAR_TANGGUNGAN', 'Cuti di luar tanggungan', 'cuti', { urutan: 9, maju_min_hari: 14, lampiran_wajib_min_hari: 1, lampiran_keterangan: 'Surat permohonan bermaterai' }),
]
const JENJANG = [{ id: 't1', mulai_hari: 1, sampai_hari: 1, langkah: ['kepala_bidang'] }, { id: 't2', mulai_hari: 2, sampai_hari: 3, langkah: ['kepala_bidang', 'direktur'] },
  { id: 't3', mulai_hari: 4, sampai_hari: null, langkah: ['kepala_bidang', 'direktur', 'yayasan'] }]
const PEJABAT = { kepala_bidang: ['Kepala Bidang Tahfizh: Ustzh. Khadijah Ramadhani, S.Ag.'], direktur: ['Direktur: Siswandi Safari, S.Pd.I., Lc., S.H., M.Ag.', 'Wakil Direktur: Ust. Muhammad Ikhsan, S.Pd.I.'], yayasan: ['Ketua Yayasan: H. Abdul Rahman, Lc.'] }

let DATA = null
function data() {
  if (DATA) return DATA
  JENIS = JENIS || jenisAwal()
  const j = (k) => JENIS.find((x) => x.kode === k)
  const buat = (id, emp, nama, unit, k, mulai, selesai, alasan, status, jenjang, extra = {}) => ({
    id, employee_id: emp, pemohon: nama, niy: '2019070101', unit, jabatan: 'Muhaffizh, Wali kelas', jenis: j(k).nama, kelompok: j(k).kelompok, leave_type_id: j(k).id,
    mulai, selesai, jumlah_hari: hitungHari(mulai, selesai), alasan, status, langkah_ke: jenjang.findIndex((x) => x.status === 'menunggu') + 1 || jenjang.length,
    melebihi_kuota: false, nomor_surat: status === 'disetujui' ? 'PGJ.007/PPTQ-IAS/X/2026' : null, kode_validasi: status === 'disetujui' ? '7KQ2-M9XA' : null,
    created_at: lalu(extra.menit || 300), diputus_pada: status === 'disetujui' ? lalu(60) : null, kop_kode: 'pondok', jenjang, ...extra,
  })
  const s = (peran, status, o = {}) => ({ peran, nama_peran: PERAN_JENJANG[peran], status, ...o })
  DATA = [
    buat('pj1', 'd-pg', 'Ust. Hasan Basri, Lc.', 'Bidang Tahfizh', 'IZIN', hari(3), hari(4), 'Menghadiri walimah saudara kandung di Bone.', 'menunggu',
      [s('kepala_bidang', 'disetujui', { nama: 'Ustzh. Khadijah Ramadhani, S.Ag.', jabatan_tertulis: 'Plt. Kepala Bidang Tahfizh', niy: '2017071507', waktu: lalu(40), catatan: 'Silakan, tugas halaqah digantikan Ust. Syamsul.' }),
       s('direktur', 'menunggu', { calon: PEJABAT.direktur })], { menit: 90 }),
    buat('pj2', 'd-pg', 'Ust. Hasan Basri, Lc.', 'Bidang Tahfizh', 'SAKIT', hari(-9), hari(-8), 'Demam dan radang tenggorokan.', 'disetujui',
      [s('kepala_bidang', 'disetujui', { nama: 'Ustzh. Khadijah Ramadhani, S.Ag.', jabatan_tertulis: 'Plt. Kepala Bidang Tahfizh', niy: '2017071507', waktu: lalu(13000) }),
       s('direktur', 'disetujui', { nama: 'Siswandi Safari, S.Pd.I., Lc., S.H., M.Ag.', jabatan_tertulis: 'Direktur', niy: '1983020910201401', waktu: lalu(12900) })], { menit: 13100 }),
    buat('pj3', 'p2', 'Ustzh. Nurul Aini, S.Pd.', 'Bidang Kesetaraan Wustha', 'CUTI_TAHUNAN', hari(8), hari(12), 'Mendampingi orang tua berobat ke Makassar.', 'menunggu',
      [s('kepala_bidang', 'menunggu', { calon: ['Kepala Bidang Kesetaraan Wustha: Chamdar Nur, S.Pd.I., SH., Lc., M.Pd.'] }), s('direktur', 'antre'), s('yayasan', 'antre')], { menit: 30, menunggu_saya: true }),
    buat('pj4', 'p12', 'Ust. Syamsul Arifin, S.Pd.', 'Bidang Kesetaraan Wustha', 'DINAS_LUAR', hari(1), hari(1), 'Pelatihan Kurikulum Merdeka di Kemenag Gowa.', 'menunggu',
      [s('kepala_bidang', 'menunggu', { calon: ['Kepala Bidang Kesetaraan Wustha: Chamdar Nur, S.Pd.I., SH., Lc., M.Pd.'] })], { menit: 15, menunggu_saya: true }),
  ]
  return DATA
}

export const ketentuan = () => { JENIS = JENIS || jenisAwal(); return { jenis: JENIS, jenjang: JENJANG, plt: [
  { id: 'plt1', employee_id: 'p7', structural_position_id: 'sp-kabid', org_unit_id: null, mulai: hari(-20), sampai: hari(40), catatan: 'Kepala bidang tugas belajar',
    employees: { nama_lengkap: 'Ustzh. Khadijah Ramadhani, S.Ag.' }, structural_positions: { nama: 'Kepala Bidang' }, org_units: { nama: 'Bidang Tahfizh' } }] } }
export const kuota = () => [
  { kode: 'CUTI_TAHUNAN', nama: 'Cuti tahunan', kuota_tahunan_hari: 12, dipakai_tahun: 3, batas_bulanan_hari: null, batas_bulanan_kali: null, dipakai_bulan: 0, kali_bulan: 0 },
  { kode: 'IZIN', nama: 'Izin', kuota_tahunan_hari: null, dipakai_tahun: 2, batas_bulanan_hari: null, batas_bulanan_kali: null, dipakai_bulan: 2, kali_bulan: 1 },
]
export function daftar(cakupan, pengguna) {
  const d = data().map((r) => ({ ...r, jenjang_kini: r.status === 'menunggu' ? r.jenjang[r.langkah_ke - 1]?.nama_peran : null }))
  if (cakupan === 'saya') return d.filter((r) => r.employee_id === pengguna?.id)
  if (cakupan === 'persetujuan') return pengguna?.peran === 'pegawai' ? [] : d.filter((r) => r.employee_id !== pengguna?.id)
  return d
}
export function periksa(isi, jenis) {
  const j = jenis.find((x) => x.id === isi.leave_type_id); const galat = []
  const n = hitungHari(isi.mulai, isi.selesai); const hi = hari(0)
  if (!j) return { galat: ['Pilih jenis pengajuan.'], jenjang: [] }
  if (n < 1) galat.push('Tanggal selesai tidak boleh sebelum tanggal mulai.')
  if (j.maks_hari && n > j.maks_hari) galat.push(`${j.nama} paling lama ${j.maks_hari} hari.${j.kelompok === 'sakit' ? ' Untuk sakit lebih lama, ajukan sebagai Izin dengan bukti.' : ''}`)
  if (j.maju_maks_hari === 0 && isi.mulai !== hi) galat.push(`${j.nama} diajukan pada hari pertama (tanggal mulai = hari ini).`)
  if (j.maju_min_hari && isi.mulai < hari(j.maju_min_hari)) galat.push(`${j.nama} diajukan paling lambat ${j.maju_min_hari} hari sebelum tanggal mulai.`)
  if (isi.mulai < hari(-j.mundur_maks_hari)) galat.push('Tanggal mulai tidak boleh sebelum hari ini.')
  const t = JENJANG.find((x) => n >= x.mulai_hari && (!x.sampai_hari || n <= x.sampai_hari)) || JENJANG[2]
  return { jumlah_hari: n, galat, peringatan: [], melebihi_kuota: false, lampiran_wajib: j.lampiran_wajib_min_hari != null && n >= j.lampiran_wajib_min_hari,
    lampiran_keterangan: j.lampiran_keterangan, jenjang: t.langkah.map((p, i) => ({ urutan: i + 1, peran: p, nama_peran: PERAN_JENJANG[p], ada_pejabat: true, pejabat: PEJABAT[p] })) }
}
export function ajukan(isi, jenis, pengguna) {
  const j = jenis.find((x) => x.id === isi.leave_type_id); const c = periksa(isi, jenis)
  if (c.galat.length) throw new Error(c.galat[0])
  const id = 'pj' + Date.now()
  data().unshift({ id, employee_id: pengguna.id, pemohon: pengguna.nama_lengkap, niy: '2019070101', unit: pengguna.nama_unit, jabatan: pengguna.jabatan, jenis: j.nama, kelompok: j.kelompok,
    leave_type_id: j.id, mulai: isi.mulai, selesai: isi.selesai, jumlah_hari: c.jumlah_hari, alasan: isi.alasan, status: 'menunggu', langkah_ke: 1, created_at: new Date().toISOString(),
    kop_kode: isi.kop_kode || 'pondok', jenjang: c.jenjang.map((x, i) => ({ ...x, status: i === 0 ? 'menunggu' : 'antre', calon: i === 0 ? x.pejabat : null })) })
  return id
}
export function detail(id, sesi) {
  const r = data().find((x) => x.id === id); if (!r) throw new Error('Pengajuan tidak ditemukan.')
  const saya = r.employee_id === sesi.pengguna?.id
  return { ...r, pemohon: { nama: r.pemohon, niy: r.niy, unit: r.unit, jabatan: r.jabatan }, jenis: { nama: r.jenis, kelompok: r.kelompok },
    boleh_putuskan: r.status === 'menunggu' && !saya && sesi.peran !== 'pegawai', atas_nama: sesi.isSuperadmin && r.status === 'menunggu',
    boleh_batal: (r.status === 'menunggu' && saya) || (sesi.isSuperadmin && ['menunggu', 'disetujui'].includes(r.status)), sesi_terisi: r.status === 'disetujui' ? 2 : 0 }
}
export function putuskan(id, setuju, catatan, pengguna) {
  const r = data().find((x) => x.id === id); const a = r.jenjang[r.langkah_ke - 1]
  Object.assign(a, { status: setuju ? 'disetujui' : 'ditolak', nama: pengguna.nama_lengkap, jabatan_tertulis: 'Pejabat (demo)', waktu: new Date().toISOString(), catatan, calon: null })
  r.menunggu_saya = false
  if (!setuju) { r.status = 'ditolak'; r.alasan_tolak = catatan; return 'ditolak' }
  const b = r.jenjang.findIndex((x) => x.status === 'antre')
  if (b >= 0) { r.jenjang[b].status = 'menunggu'; r.jenjang[b].calon = PEJABAT[r.jenjang[b].peran]; r.langkah_ke = b + 1; return 'naik' }
  Object.assign(r, { status: 'disetujui', nomor_surat: 'PGJ.008/PPTQ-IAS/X/2026', kode_validasi: 'H4TN-2PQE', diputus_pada: new Date().toISOString() })
  return 'disetujui'
}
export function batalkan(id) { const r = data().find((x) => x.id === id); r.status = 'dibatalkan' }
