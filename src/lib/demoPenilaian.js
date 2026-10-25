// SIMKA PRO | src/lib/demoPenilaian.js | v1.2 | 14.26.0: demo Wustha memakai TP (ceklist capaian) | 25/10/2026
// v1.1: identitas sekolah per jenis rapor (sampul dan halaman identitas sekolah).
// Pengaturan penilaian contoh untuk MODE DEMO (mengikuti isi awal migrasi 8200). Semua data fiktif.
import { dataJadwalDemo } from './demoJadwal'

const TA = { id: 'ta1', nama: '2026/2027', mulai: '2026-07-13', selesai: '2027-06-30', aktif: true, terkunci: false, semester: 1 }
const DIMENSI = ['Keimanan dan Ketakwaan', 'Kewargaan', 'Penalaran Kritis', 'Kreativitas', 'Kolaborasi', 'Kemandirian', 'Kesehatan', 'Komunikasi']
const SMA = [['KELOMPOK UMUM', 'Pendidikan Agama dan Budi Pekerti', 'PAI', 80, 'PAI'], ['KELOMPOK UMUM', 'Pendidikan Pancasila dan Kewarganegaraan', 'PKn', 75, 'PKN'],
  ['KELOMPOK UMUM', 'Bahasa Indonesia', 'IND', 75, 'BIND'], ['KELOMPOK UMUM', 'Bahasa Inggris', 'ING', 75, 'BING'], ['KELOMPOK UMUM', 'Matematika', 'MTK', 75, 'MTK'],
  ['KELOMPOK UMUM', 'Seni Prakarya dan Kewirausahaan', 'SENI', 75, null], ['KELOMPOK UMUM', 'Pendidikan Jasmani, Olah Raga, dan Kesehatan', 'PJOK', 75, null],
  ['KELOMPOK UMUM', 'Informatika, Koding dan AI', 'TIK', 75, 'INF'], ['KELOMPOK UMUM', 'Ilmu Pengetahuan Sosial', 'IPS', 75, 'IPS'], ['KELOMPOK UMUM', 'Ilmu Pengetahuan Alam', 'IPA', 75, 'IPA'],
  ['KELOMPOK UMUM', 'Adab', 'ADB', 80, null], ['KELOMPOK PEMINATAN', 'Aqidah', 'AQD', 80, null], ['KELOMPOK MUATAN LOKAL', 'Bahasa Arab', 'ARB', 80, 'BARAB'],
  ['KELOMPOK MUATAN LOKAL', "Ilmu Al-Qur'an", 'IQ', 80, null], ['KELOMPOK MUATAN LOKAL', 'Tahfidz', 'THZ', 80, '@tahfizh']]
const W9 = [['Bahasa Indonesia', 'BIND', 'BIND'], ['Bahasa Inggris', 'BING', 'BING'], ['Matematika', 'MTK', 'MTK'], ['Ilmu Pengetahuan Alam', 'IPA', 'IPA'], ['Ilmu Pengetahuan Sosial', 'IPS', 'IPS'],
  ['Pendidikan Kewarganegaraan', 'PKN', 'PKN'], ["Al-Qur'an", 'QUR', null], ['Hadits', 'HDS', 'HADITS'], ['Akidah', 'AKD', null], ['Akhlak', 'AKH', null], ['Fikih', 'FIK', 'FIQIH'],
  ['Bahasa Arab', 'ARB', 'BARAB'], ['Tajwid', 'TJW', 'TAHSIN'], ['Sejarah Peradaban Islam', 'SPI', null], ['Tafsir', 'TFS', null]]
const W78 = [['Tajwid', 'TJW', 'TAHSIN'], ['Hadits', 'HDS', 'HADITS'], ['Tafsir', 'TFS', null], ['Akidah', 'AKD', null], ['Akhlak', 'AKH', null], ['Fikih', 'FIK', 'FIQIH'],
  ['Bahasa Arab', 'ARB', 'BARAB'], ["Qira'ah wal Kitabah", 'QWK', null], ["Al-Qur'an", 'QUR', null], ['Sejarah Peradaban Islam', 'SPI', null], ['Khat', 'KHT', null], ['TIK', 'TIK', 'INF']]

let data = null
let nomor = 0
const id = (a) => `${a}-${++nomor}`

function mapelRapor(jenis, tingkat, daftar) {
  const mp = dataJadwalDemo().mapel
  return daftar.map((x, i) => {
    const [kelompok, nama, singkatan, kkm, kode] = jenis === 'sma' ? x : [null, x[0], x[1], 70, x[2]]
    const sub = kode && kode !== '@tahfizh' ? mp.find((m) => m.kode === kode) : null
    return { id: id('rs'), academic_year_id: TA.id, jenis, tingkat, urutan: i + 1, kelompok, nama, singkatan, kkm, sumber: kode === '@tahfizh' ? 'tahfizh' : 'mapel', mode_nilai: null, aktif: true, catatan: null,
      sumber_mapel: sub ? [{ subject_id: sub.id, kode: sub.kode, nama: sub.nama, jenjang: sub.jenjang, aktif: true, bobot: 100 }] : [], pengampu: sub ? 1 : 0 }
  })
}

const IDN_DASAR = { alamat: 'Jalan Poros Malino KM.04, Lingkungan Bontobaddo', kode_pos: '92119', kelurahan: 'Bontoramba', kecamatan: 'Somba Opu', kota: 'Gowa', provinsi: 'Sulawesi Selatan', email: 'syathiby.gowa@gmail.com' }
const IDN = {
  sma: { ...IDN_DASAR, nama_sekolah: "SMAS Tahfizhul Qur'an Imam Asy Syatiby W.I", jenjang: 'Sekolah Menengah Atas (SMA)', npsn: '69981456', nss: '', alamat: 'Jalan Poros Malino-Sungguminasa Km.04, Dusun Bontobaddo',
    telepon: '085256006743', kementerian: 'Kementerian Pendidikan Dasar dan Menengah Republik Indonesia' },
  wustha: { ...IDN_DASAR, nama_sekolah: "Kesetaraan Wustha PPS Tahfizhul Qur'an Imam Asy-Syathiby Wahdah Islamiyah Gowa", jenjang: 'Pendidikan Kesetaraan Wustha (setara SMP)', npsn: '70023617',
    nss: '502373060054', telepon: '082194934531', kementerian: 'Kementerian Agama Kabupaten Gowa' },
  tahfizh: { ...IDN_DASAR, nama_sekolah: "Pondok Pesantren Tahfizhul Qur'an Imam Asy-Syathiby Wahdah Islamiyah Gowa", jenjang: "Program Tahfizhul Qur'an", npsn: '70023617', nss: '502373060054',
    telepon: '085243324006', kementerian: 'Kementerian Agama Kabupaten Gowa' },
}
export function dataPenilaianDemo() {
  if (data) return data
  const k = (jenis, x) => ({ academic_year_id: TA.id, jenis, kop_kode: null, label_ambang: 'KKM', ambang_bawaan: 75, mode_nilai: 'rekomendasi', desimal: 0, pakai_keterampilan: false, keterampilan_ikut: true,
    sikap_di_rapor: false, pakai_kokurikuler: false, pakai_tp: false, tampil_rata: false, tampil_peringkat: false, bahasa_predikat: 'arab', signatory_id: null, jabatan_ttd: null, tempat: 'Gowa',
    fase: {}, dimensi: [], utas_juz_sma: 5, utas_juz_wustha: 3, catatan: null, penanda: null, identitas: IDN[jenis], ...x })
  const ketentuan = {
    sma: k('sma', { judul: 'Laporan Hasil Belajar', kop_kode: 'sma', label_ambang: 'KKTP', pakai_kokurikuler: true, pakai_tp: true, signatory_id: 's3', jabatan_ttd: 'Kepala Sekolah',
      penanda: { jabatan: 'Kepala SMA', nama: 'H. Afrianto, Lc, M.H.', niy: '1994042801202001' }, fase: { 10: 'E', 11: 'F', 12: 'F' }, dimensi: DIMENSI }),
    wustha: k('wustha', { judul: 'Pencapaian Kompetensi Peserta Didik', kop_kode: 'wustha', ambang_bawaan: 70, pakai_keterampilan: true, pakai_tp: true, sikap_di_rapor: true, tampil_rata: true,
      signatory_id: 's2', jabatan_ttd: 'Kepala Kesetaraan', penanda: { jabatan: 'Kepala Kesetaraan Wustha (SMP)', nama: 'Chamdar Nur, S.Pd.I., SH., Lc., M.Pd.', niy: '1983042805201401' } }),
    tahfizh: k('tahfizh', { judul: "Laporan Hasil Capaian Hafalan Al-Qur'an", ambang_bawaan: 80, jabatan_ttd: 'Kepala Tahfizh' }),
  }
  const p = (kelompok, huruf, min, maks, sebutan, x = {}) => ({ id: id('pr'), academic_year_id: TA.id, kelompok, huruf, nilai_min: min, nilai_maks: maks, sebutan, sebutan_arab: null, deskripsi: null, deskripsi_2: null, tuntas: true, ...x })
  const predikat = [
    p('sma', 'A', 93, 100, 'Sangat Baik', { deskripsi: 'Memiliki pengetahuan yang sangat baik dalam memahami' }),
    p('sma', 'B', 86, 92.99, 'Baik', { deskripsi: 'Memiliki pemahaman yang baik pada materi' }),
    p('sma', 'C', 77, 85.99, 'Cukup', { deskripsi: 'Cukup mampu memahami persoalan pada materi' }),
    p('sma', 'D', 0, 76.99, 'Perlu Bimbingan', { deskripsi: 'Perlu bimbingan dan pendalaman materi mengenai', tuntas: false }),
    p('wustha', 'A', 85, 100, 'Sangat Baik', { deskripsi: 'Mampu menguasai seluruh kompetensi pengetahuan dengan sangat baik', deskripsi_2: 'Mampu menguasai seluruh kompetensi keterampilan dengan sangat baik' }),
    p('wustha', 'B', 75, 84.99, 'Baik', { deskripsi: 'Mampu menguasai seluruh kompetensi pengetahuan dengan baik', deskripsi_2: 'Mampu menguasai seluruh kompetensi keterampilan dengan baik' }),
    p('wustha', 'C', 70, 74.99, 'Cukup', { deskripsi: 'Cukup mampu menguasai kompetensi pengetahuan', deskripsi_2: 'Cukup mampu menguasai kompetensi keterampilan' }),
    p('wustha', 'D', 0, 69.99, 'Kurang', { deskripsi: 'Perlu bimbingan dalam menguasai kompetensi pengetahuan', deskripsi_2: 'Perlu bimbingan dalam menguasai kompetensi keterampilan', tuntas: false }),
    p('utas', 'A', 90, 100, 'Istimewa', { sebutan_arab: 'Mumtaz' }), p('utas', 'B', 80, 89.99, 'Sangat Baik', { sebutan_arab: 'Jayyid Jiddan' }),
    p('utas', 'C', 70, 79.99, 'Baik', { sebutan_arab: 'Jayyid', tuntas: false }), p('utas', 'D', 60, 69.99, 'Cukup', { sebutan_arab: 'Maqbul', tuntas: false }),
    p('utas', 'E', 0, 59.99, 'Kurang', { sebutan_arab: 'Rasib', tuntas: false }),
    p('pd', 'A', null, null, 'Sangat Baik', { deskripsi: 'Sangat baik dalam mengikuti kegiatan {kegiatan}' }), p('pd', 'B', null, null, 'Baik', { deskripsi: 'Baik dalam mengikuti kegiatan {kegiatan}' }),
    p('pd', 'C', null, null, 'Cukup', { deskripsi: 'Cukup baik dalam mengikuti kegiatan {kegiatan}' }), p('pd', 'D', null, null, 'Kurang', { deskripsi: 'Perlu bimbingan dalam mengikuti kegiatan {kegiatan}', tuntas: false }),
    p('sikap', 'A', null, null, 'Sangat Baik'), p('sikap', 'B', null, null, 'Baik'), p('sikap', 'C', null, null, 'Cukup'), p('sikap', 'K', null, null, 'Kurang', { tuntas: false }),
  ].map((x, i, a) => ({ ...x, urutan: a.filter((y, j) => j <= i && y.kelompok === x.kelompok).length }))
  const c = (jenis, kode, nama, aspek, bobot, berulang, urutan) => ({ id: id('gc'), academic_year_id: TA.id, jenis, kode, nama, aspek, bobot, berulang, aktif: true, urutan })
  const kategori = ['sma', 'wustha'].flatMap((j) => [c(j, 'HARIAN', 'Nilai harian', 'pengetahuan', 25, true, 1), c(j, 'ULANGAN', 'Ulangan', 'pengetahuan', 25, true, 2),
    c(j, 'UTS', 'Ujian tengah semester', 'pengetahuan', 20, false, 3), c(j, 'UAS', 'Ujian akhir semester', 'pengetahuan', 30, false, 4),
    ...(j === 'wustha' ? [c(j, 'PRAKTIK', 'Praktik', 'keterampilan', 50, true, 5), c(j, 'PROYEK', 'Proyek/portofolio', 'keterampilan', 50, true, 6)] : [])])
  const periode = ['sma', 'wustha', 'tahfizh'].flatMap((jenis) => [1, 2].map((semester) => ({ id: id('gp'), academic_year_id: TA.id, jenis, semester,
    status: semester === 1 && jenis !== 'tahfizh' ? 'dibuka' : 'disiapkan', batas_isi: null, tanggal_rapor: semester === 1 ? '2026-12-19' : null, hari_efektif: null,
    tema_kokurikuler: jenis === 'sma' && semester === 1 ? 'Generasi Sehat dan Bugar' : null, dibuka_pada: null, ditutup_pada: null, pengubah: null,
    hari_otomatis: semester === 1 ? 112 : 128 })))
  const mapel = [...[10, 11, 12].flatMap((t) => mapelRapor('sma', t, SMA)), ...[7, 8].flatMap((t) => mapelRapor('wustha', t, W78)), ...mapelRapor('wustha', 9, W9)]
  const kl = (kategori, jenis, bagian, kunci, min_nilai, teks, urutan = 1) => ({ id: id('kl'), kategori, jenis, bagian, kunci, min_nilai, teks, aktif: true, urutan })
  const kalimat = [
    kl('kehadiran', 'wustha', 'ambang', null, 90, 'Perhatian dan keseriusan dalam mengikuti pelajaran sangat memuaskan, mohon kehadirannya dipertahankan!'),
    kl('kehadiran', 'wustha', 'ambang', null, 75, 'Perhatian dan keseriusan dalam mengikuti pelajaran cukup memuaskan, mohon kehadirannya ditingkatkan lagi!', 2),
    kl('kehadiran', 'wustha', 'ambang', null, 0, 'Perhatian dan keseriusan dalam mengikuti pelajaran kurang memuaskan, mohon kehadirannya lebih ditingkatkan lagi!', 3),
    kl('kehadiran', 'sma', 'ambang', null, 95, 'Kehadiran ananda sangat baik, hal ini menunjukkan komitmen dan disiplin yang luar biasa terhadap proses pembelajaran.'),
    kl('kehadiran', 'sma', 'ambang', null, 85, 'Kehadiran ananda baik; pertahankan dan tingkatkan kedisiplinan dalam mengikuti pembelajaran.', 2),
    kl('kehadiran', 'sma', 'ambang', null, 0, 'Kehadiran ananda perlu ditingkatkan agar proses pembelajaran dapat diikuti dengan optimal.', 3),
    kl('kehadiran_halaqah', 'tahfizh', 'ambang', null, 90, 'Kehadiran ananda di halaqah sangat baik, pertahankan!'),
    kl('kehadiran_halaqah', 'tahfizh', 'ambang', null, 0, 'Kehadiran ananda di halaqah perlu ditingkatkan agar hafalan terjaga.', 2),
    kl('catatan_wali', null, 'pembuka', null, null, 'Alhamdulillah, Ananda {panggilan} telah menyelesaikan semester ini dengan baik.'),
    kl('catatan_wali', null, 'pembuka', null, null, '_Barakallahu fiik_, Ananda {panggilan}, atas usaha dan kesungguhan selama semester ini.', 2),
    kl('catatan_wali', null, 'kelebihan', 'mapel_terbaik', null, 'Capaian Ananda pada {mapel} sangat menonjol dan patut diapresiasi.'),
    kl('catatan_wali', null, 'kelebihan', 'kehadiran', null, 'Kehadiran Ananda sangat baik ({persen}%), cerminan kedisiplinan yang tinggi.'),
    kl('catatan_wali', null, 'kelebihan', 'hafalan', null, "Hafalan Al-Qur'an Ananda bertambah {tambah_juz} juz pada semester ini, sebuah capaian yang membanggakan."),
    kl('catatan_wali', null, 'dorongan', 'mapel_lemah', null, 'Tingkatkan lagi pemahaman pada {mapel_lemah} dengan lebih banyak berlatih dan bertanya.'),
    kl('catatan_wali', null, 'dorongan', 'umum', null, 'Terus jaga semangat belajar dan pertahankan konsistensi.'),
    kl('catatan_wali', null, 'penutup', null, null, 'Semoga Allah memudahkan langkah Ananda meraih cita-cita.'),
    kl('catatan_muhaffizh', 'tahfizh', 'pembuka', null, null, 'Alhamdulillah, Ananda {panggilan} telah mengikuti halaqah semester ini dengan baik.'),
    kl('catatan_muhaffizh', 'tahfizh', 'kelebihan', 'target_tercapai', null, 'Target hafalan semester ini tercapai dengan baik.'),
    kl('catatan_muhaffizh', 'tahfizh', 'dorongan', 'murajaah', null, 'Perbanyak murajaah agar hafalan semakin mutqin.'),
    kl('catatan_muhaffizh', 'tahfizh', 'penutup', null, null, "Semoga Allah menjadikan Ananda penghafal Al-Qur'an yang mengamalkannya."),
  ]
  data = { ta: TA, ketentuan, predikat, kategori, periode, mapel, kalimat }
  return data
}
export const idDemo = id
