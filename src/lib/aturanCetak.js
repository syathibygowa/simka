// SIMKA PRO | src/lib/aturanCetak.js | v1.5 | 14.34.0: dokumen kehadiran per jam pelajaran dan per pertemuan mapel | 30/10/2026
// Katalog dokumen cetak beserta penanda tangan kiri ("Mengetahui", pimpinan/atasan), kanan (pegawai terkait), dan kop.
// Nilai yang dipilih superadmin disimpan di tabel signer_rules (kiri, kanan, kop_kode); setiap DokumenCetak yang diberi
// prop `jenis` membaca aturan ini lalu TandaTangan memakainya.
//
// Nilai kiri/kanan:
//   - uuid pejabat (tabel signatories)                 → pejabat tetap
//   - peran pejabat: direktur, kepala_unit, pimpinan_kelompok, pimpinan_bagian, kabid_tahfizh, kabid_kesantrian
//     (pimpinan_bagian, 14.19.0: Ketua Yayasan / Direktur / Kepala Wustha / Kepala SMA sesuai konteks.bagian = kode kop)
//   - peran dokumen: pengasuh, pihak, pembuat, atasan_langsung (diambil dari halaman yang mencetak)
//   - tidak_ada                                         → kolom dikosongkan
// Nilai kop: null = sesuai unit dokumen (jenjang kelas/santri bila ada, selain itu kop bawaan halaman); kode kop = kop tetap.
//
// Sisi yang sudah ditandatangani elektronik (ada kode validasi) tidak pernah diganti.

export const PERAN = {
  direktur: { n: 'Direktur', pejabat: true },
  kepala_unit: { n: 'Kepala sekolah sesuai jenjang', pejabat: true },
  pimpinan_kelompok: { n: 'Pimpinan sesuai kelompok', pejabat: true },
  pimpinan_bagian: { n: 'Pimpinan sesuai bagian (Yayasan/Pondok/Wustha/SMA)', pejabat: true },
  kabid_tahfizh: { n: 'Kepala Bidang Tahfizh', pejabat: true },
  kabid_kesantrian: { n: 'Kepala Bidang Kesantrian', pejabat: true },
  pengasuh: { n: 'Penanggung jawab kelompok/mapel' },
  pihak: { n: 'Pihak bersangkutan' },
  atasan_langsung: { n: 'Atasan langsung (tulis tangan)' },
  pembuat: { n: 'Pembuat dokumen' },
  tidak_ada: { n: 'Tidak ada' },
}

export const KELOMPOK = ['Wali Kelas, Guru Mapel, dan Penilaian', 'Tahfizh', 'Musyrif, Kesantrian, dan Kedisiplinan', 'Data Santri dan Kelompok',
  'Security dan Perizinan', 'Kepegawaian dan Presensi', 'Gaji dan Keuangan', 'Persuratan, Laporan, dan Sistem']

// d(kode, nama, menu, asli kiri, asli kanan, bawaan kiri, bawaan kanan)
// asli = peran yang dihitung halaman. Peran dokumen (pengasuh, pihak, pembuat, atasan) diambil dari halaman; peran pejabat selalu
// dihitung dari daftar pejabat di Setelan agar seragam. '-' = halaman hanya menampilkan isian kosong.
const d = (kode, nama, menu, ak, an, bk = ak, bn = an) => ({ kode, nama, menu, asli: { kiri: ak, kanan: an }, bawaan: { kiri: bk, kanan: bn, kop: null } })
const DAFTAR = {
  'Wali Kelas, Guru Mapel, dan Penilaian': [
    d('wk_daftar_santri', 'Daftar santri kelas', 'Wali Kelas → Santri', 'direktur', 'pengasuh', 'kepala_unit'),
    d('wk_pelajaran', 'Rekap keterlaksanaan pelajaran kelas', 'Wali Kelas → Pelajaran', 'direktur', 'pengasuh', 'kepala_unit'),
    d('wk_pemantauan', 'Rekap pemantauan kelas', 'Wali Kelas → Semua kelas', 'direktur', 'pembuat', 'kepala_unit'),
    d('wk_nilai_mapel', 'Nilai santri per mata pelajaran', 'Wali Kelas → Rapor', 'direktur', 'pengasuh', 'kepala_unit'),
    d('rekap_absensi', 'Rekap kehadiran santri per kelompok', 'Wali Kelas, Musyrif, Absensi Santri → Rekap absensi', 'pimpinan_kelompok', 'pengasuh'),
    d('gm_kehadiran_mapel', 'Rekap kehadiran santri per mata pelajaran', 'Guru Mapel / Wali Kelas → Kehadiran', 'direktur', 'pengasuh', 'kepala_unit'),
    d('wk_kehadiran_jp', 'Kehadiran santri per jam pelajaran', 'Wali Kelas → Kehadiran kelas', 'direktur', 'pengasuh', 'kepala_unit'),
    d('gm_kehadiran_pertemuan', 'Kehadiran santri per pertemuan mapel', 'Guru Mapel / Wali Kelas → Kehadiran', 'direktur', 'pengasuh', 'kepala_unit'),
    d('gm_jurnal', 'Laporan jurnal mengajar', 'Guru Mapel / Wali Kelas → Jurnal mengajar', '-', 'pengasuh', 'kepala_unit'),
    d('gm_pantau', 'Rekap keterlaksanaan mengajar guru mapel', 'Guru Mapel → Pantau guru', 'direktur', 'pembuat', 'kepala_unit'),
    d('gm_rekap_guru', 'Laporan keterlaksanaan mengajar per guru', 'Guru Mapel → Rekap', 'direktur', 'pengasuh', 'kepala_unit'),
    d('jadwal_rekap_mengajar', 'Rekap/laporan keterlaksanaan mengajar', 'Jadwal Pelajaran → Rekap mengajar', 'direktur', 'pengasuh', 'kepala_unit'),
    d('jadwal_pelajaran', 'Jadwal pelajaran kelas dan jadwal mengajar guru', 'Jadwal Pelajaran', 'kepala_unit', 'pengasuh'),
    d('nilai_permintaan', 'Riwayat permintaan ubah nilai', 'Penilaian → Permintaan ubah nilai', '-', 'pembuat', 'kepala_unit'),
    d('nilai_rekap', 'Rekap kemajuan penilaian', 'Penilaian → Rekap', '-', 'pembuat', 'kepala_unit'),
  ],
  Tahfizh: [
    d('thz_santri', 'Data hafalan santri', 'Tahfizh → Data hafalan', 'kabid_tahfizh', 'pengasuh'),
    d('thz_capaian', 'Rekap status capaian hafalan bulanan', 'Tahfizh → Capaian', 'kabid_tahfizh', 'pengasuh'),
    d('thz_laporan', 'Laporan tahfizh', 'Tahfizh → Laporan', 'kabid_tahfizh', 'pengasuh'),
    d('thz_tahsin', 'Daftar santri tahsin', 'Tahfizh → Tahsin', 'kabid_tahfizh', 'pembuat'),
    d('thz_ujian_tahsin', 'Rekap hasil ujian tahsin', 'Tahfizh → Tahsin → Ujian tahsin', 'kabid_tahfizh', 'pembuat'),
    d('thz_utas', 'Hasil dan pembagian penguji UTAS', 'Tahfizh → UTAS', 'kabid_tahfizh', 'pembuat'),
    d('thz_ketentuan', 'Ketentuan penilaian dan target tahfizh', 'Tahfizh → Ketentuan', 'direktur', 'kabid_tahfizh'),
  ],
  'Musyrif, Kesantrian, dan Kedisiplinan': [
    d('msy_jurnal', 'Jurnal musyrif', 'Musyrif → Jurnal', 'kabid_kesantrian', 'pengasuh'),
    d('msy_rekap', 'Rekap musyrif per kamar', 'Musyrif → Rekap', 'kabid_kesantrian', 'pengasuh'),
    d('abs_perhatian', 'Santri perlu perhatian', 'Absensi Santri → Perlu perhatian', '-', 'pembuat', 'kabid_kesantrian'),
    d('ekskul_rekap', 'Rekap ekskul', 'Ekskul → Rekap', 'pimpinan_kelompok', 'pengasuh'),
    d('ekskul_nilai', 'Daftar nilai pengembangan diri', 'Ekskul → Nilai', '-', 'pengasuh', 'kabid_kesantrian'),
    d('disiplin_pelanggaran', 'Rekap dan riwayat pelanggaran santri', 'Kedisiplinan → Pelanggaran', 'kabid_kesantrian', 'pembuat'),
    d('disiplin_rekap', 'Rekap kedisiplinan santri', 'Kedisiplinan → Rekap', 'direktur', 'kabid_kesantrian'),
    d('disiplin_sp', 'Rekap surat peringatan santri', 'Kedisiplinan → Surat peringatan', 'direktur', 'kabid_kesantrian'),
    d('disiplin_santri', 'Riwayat kedisiplinan satu santri', 'Detail Santri → Kedisiplinan', 'kabid_kesantrian', 'pembuat'),
    d('prestasi', 'Rekap prestasi santri', 'Prestasi Santri', 'direktur', 'pembuat'),
    d('rekam_santri', 'Rekam kesantrian', 'Detail Santri → Rekam kesantrian', 'kabid_kesantrian', 'pengasuh'),
    d('klinik_surat_sakit', 'Surat keterangan sakit', 'Klinik', 'kabid_kesantrian', 'pihak'),
  ],
  'Data Santri dan Kelompok': [
    d('santri_daftar', 'Daftar santri', 'Data Santri', 'kepala_unit', 'pembuat'),
    d('santri_biodata', 'Biodata santri', 'Detail Santri', 'kepala_unit', 'pihak'),
    d('santri_pindah', 'Surat keterangan pindah', 'Detail Santri → Mutasi', 'direktur', 'kepala_unit'),
    d('santri_kelengkapan', 'Daftar kelengkapan data santri', 'Data Santri → Kelengkapan', 'direktur', 'pembuat'),
    d('santri_statistik', 'Rekapitulasi jumlah santri', 'Data Santri → Statistik', 'direktur', 'pembuat'),
    d('kelompok_daftar', 'Daftar santri satu kelompok', 'Kelompok Santri → Detail', 'pimpinan_kelompok', 'pengasuh'),
    d('kelompok_absensi', 'Lembar absensi kelompok (isian tangan)', 'Kelompok Santri → Cetak absensi', 'pimpinan_kelompok', 'pengasuh'),
    d('kelompok_rekap', 'Rekap kelas/halaqah/asrama/ekskul', 'Kelompok Santri', 'pimpinan_kelompok', 'pembuat'),
  ],
  'Security dan Perizinan': [
    d('izin_libur', 'Daftar libur santri', 'Perizinan → Libur', 'kabid_kesantrian', 'pembuat'),
    d('sec_gerbang', 'Riwayat gerbang santri', 'Security → Riwayat gerbang', 'kabid_kesantrian', 'pembuat'),
    d('sec_tamu', 'Buku tamu', 'Security → Tamu', 'kabid_kesantrian', 'pembuat'),
    d('sec_titipan', 'Daftar titipan santri', 'Security → Titipan', 'kabid_kesantrian', 'pembuat'),
    d('sec_kunjungan', 'Daftar kunjungan orang tua', 'Security → Kunjungan', 'kabid_kesantrian', 'pembuat'),
    d('pantauan', 'Daftar dari Layar Pantauan', 'Layar Pantauan', 'pimpinan_kelompok', 'pembuat'),
    d('izin_surat_santri', 'Surat izin keluar/pulang santri', 'Perizinan Santri → Surat', 'pihak', 'pengasuh'),
    d('izin_surat_kolektif', 'Surat izin kolektif santri', 'Perizinan Santri → Kolektif', 'pihak', 'pembuat'),
    d('izin_rekap_santri', 'Rekap perizinan santri (buku saku)', 'Data Santri → Detail → Rekap perizinan', 'kabid_kesantrian', 'pembuat'),
  ],
  'Kepegawaian dan Presensi': [
    d('pgw_daftar', 'Daftar pegawai', 'Data Pegawai', 'direktur', 'pembuat'),
    d('pgw_biodata', 'Biodata pegawai', 'Detail Pegawai', 'direktur', 'pihak'),
    d('pgw_drh', 'Daftar riwayat hidup pegawai', 'Detail Pegawai', 'direktur', 'pihak'),
    d('pgw_rekam', 'Rekam kepegawaian', 'Detail Pegawai → Rekam kepegawaian', 'direktur', 'pihak'),
    d('pgw_rekap', 'Rekap kepegawaian', 'Data Pegawai → Rekap', 'direktur', 'pembuat'),
    d('pgw_kelompok', 'Daftar anggota kelompok pegawai', 'Kelompok Pegawai', 'direktur', 'pembuat'),
    d('pgw_beban', 'Ekuivalensi jam beban kerja', 'Beban Kerja', 'direktur', 'pembuat'),
    d('pgw_peta', 'Peta jabatan dan perkiraan tunjangan', 'Tunjangan → Peta jabatan', 'direktur', 'pembuat'),
    d('organisasi', 'Struktur organisasi', 'Organisasi', 'direktur', 'pembuat'),
    d('presensi_harian', 'Daftar presensi harian pegawai', 'Data Presensi', 'direktur', 'pembuat'),
    d('presensi_bulanan', 'Rekap kehadiran bulanan pegawai', 'Data Presensi', 'direktur', 'pembuat'),
    d('rekap_presensi', 'Rekap presensi pegawai (harian dan periode)', 'Rekap dan Laporan → Rekap presensi', 'direktur', 'pembuat'),
    d('jadwal_kerja', 'Jadwal kerja pegawai', 'Atur Presensi → Jadwal kerja', 'direktur', 'pembuat'),
    d('pola_presensi', 'Pola sesi presensi pegawai', 'Atur Presensi → Pola dan sesi', 'direktur', 'pembuat'),
    d('jadwal_shift', 'Jadwal shift', 'Jadwal Shift', 'direktur', 'pembuat'),
    d('pengajuan_rekap', 'Rekap pengajuan izin, sakit, dinas luar, cuti', 'Pengajuan → Semua', 'direktur', 'pembuat'),
    d('jurnal_rekap', 'Rekap pengisian jurnal harian', 'Jurnal Harian → Rekap', 'direktur', 'pembuat'),
    d('jurnal_individu', 'Laporan dan ceklist jurnal harian per pegawai', 'Jurnal Harian → Rekap', 'atasan_langsung', 'pihak'),
    d('agenda', 'Agenda kegiatan', 'Agenda', 'direktur', 'pembuat'),
    d('pengumuman', 'Pengumuman', 'Pengumuman', 'direktur', 'pembuat'),
  ],
  'Gaji dan Keuangan': [
    d('gaji_daftar', 'Daftar gaji pegawai', 'Gaji → Periode', 'direktur', 'pembuat'),
    d('gaji_laporan', 'Laporan gaji', 'Gaji → Laporan', 'direktur', 'pembuat'),
    d('gaji_rekening', 'Daftar rekening penerimaan gaji', 'Gaji → Rekening', 'direktur', 'pembuat'),
    d('keu_santri', 'Laporan keuangan per santri', 'Keuangan → Santri', 'direktur', 'pembuat'),
    d('keu_tagihan', 'Daftar tagihan santri', 'Keuangan → Santri', 'direktur', 'pembuat'),
    d('keu_pembayaran', 'Rekap pemasukan keuangan santri', 'Keuangan → Pembayaran', 'direktur', 'pembuat'),
    d('keu_tunggakan', 'Laporan tunggakan', 'Keuangan → Tunggakan', 'direktur', 'pembuat'),
    d('keu_kas', 'Buku kas dan bank', 'Keuangan → Kas dan bank', 'direktur', 'pembuat'),
    d('keu_bukti', 'Bukti kas masuk/keluar', 'Keuangan → Kas dan bank', 'pihak', 'pembuat'),
    d('keu_laporan', 'Laporan keuangan', 'Keuangan → Laporan', 'direktur', 'pembuat'),
  ],
  'Persuratan, Laporan, dan Sistem': [
    d('surat_agenda_masuk', 'Buku agenda surat masuk', 'Persuratan → Buku agenda (per bagian)', 'direktur', 'pembuat', 'pimpinan_bagian'),
    d('surat_agenda_keluar', 'Buku agenda surat keluar', 'Persuratan → Buku agenda (per bagian)', 'direktur', 'pembuat', 'pimpinan_bagian'),
    d('surat_disposisi', 'Lembar disposisi', 'Persuratan → Surat masuk', 'pihak', 'pembuat'),
    d('teguran_rekap', 'Rekap surat teguran pegawai', 'Persuratan → Surat teguran', 'direktur', 'pembuat'),
    d('dokumen_resmi', 'Registri dokumen resmi', 'Rekap dan Laporan → Dokumen resmi', 'direktur', 'pembuat'),
    d('lapor_rekap', 'Rekap laporan ke bidang', 'Lapor ke Bidang', '-', 'pembuat', 'direktur'),
    d('audit_log', 'Audit log aktivitas pengguna', 'Audit Log', '-', 'pembuat', 'direktur'),
    d('hak_akses_admin', 'Rekap akses admin', 'Hak Akses → Rekap admin', 'direktur', 'pembuat'),
    d('hak_akses_fitur', 'Ceklist hak akses fitur', 'Hak Akses → Rekap jabatan', 'direktur', 'pembuat'),
    d('kinerja_bidang', 'Laporan indikator kinerja bidang', 'Rekap dan Laporan → Kinerja bidang', 'direktur', 'pembuat'),
  ],
}

/** Katalog datar: [{ kode, nama, menu, kelompok, urutan, asli, bawaan }] */
export const KATALOG = Object.entries(DAFTAR).flatMap(([kelompok, x], i) => x.map((r, j) => ({ ...r, kelompok, urutan: (i + 1) * 100 + j + 1 })))
export const cariDokumen = (kode) => KATALOG.find((x) => x.kode === kode)

/** Peran yang masuk akal untuk satu dokumen (pejabat selalu; peran dokumen hanya bila halaman menyediakannya). */
export function peranUntuk(dok) {
  const asli = new Set([dok.asli.kiri, dok.asli.kanan])
  return Object.keys(PERAN).filter((k) => PERAN[k].pejabat || k === 'pembuat' || k === 'tidak_ada' || asli.has(k))
}

/** Dokumen yang penanda tangannya ditentukan alur lain (ditampilkan sebagai keterangan di Setelan). */
export const DIATUR_LAIN = [
  { nama: 'Surat keluar, surat teguran pegawai, dan surat dari template', tempat: 'Persuratan → Template surat (penanda tangan dipilih pada template/saat menyusun surat)' },
  { nama: 'Surat izin, sakit, dinas luar, dan cuti pegawai', tempat: 'Ditandatangani elektronik oleh atasan yang menyetujui pengajuan' },
  { nama: 'Laporan resmi kehadiran dan rekap layanan', tempat: 'Rekap dan Laporan → Laporan resmi (penanda tangan dipilih saat laporan dikirim untuk disahkan)' },
  { nama: 'Slip gaji, kuitansi, dan surat tagihan santri', tempat: 'Ditandatangani elektronik oleh bendahara (dan Direktur pada slip)' },
  { nama: 'Undangan khataman dan syahadah', tempat: 'Ditandatangani elektronik oleh Kepala Bidang Tahfizh saat dokumen diterbitkan' },
  { nama: 'Rapor dan sampul rapor', tempat: 'Penilaian → Ketentuan → Penanda tangan tengah (per jenjang)' },
  { nama: 'Kartu pegawai dan kartu pelajar', tempat: 'Kartu memakai tanda tangan Direktur' },
]

// ---------- 14.21.0: penanda tangan dokumen tahfizh (Setelan → Penanda tangan → Dokumen tahfizh) ----------
// Disimpan di institution_settings kunci "ttd_tahfizh": { kode_dokumen: [peran kiri, peran kanan] } (satu peran = penanda tangan tunggal).
// Orang yang sama hanya menandatangani sekali dengan jabatan tertinggi: Direktur › Kepala Bidang Tahfizh › Penguji › Muhaffizh.
export const PERAN_TTD_TAHFIZH = {
  direktur: { n: 'Direktur', peringkat: 4 },
  kepala_tahfizh: { n: 'Kepala Bidang Tahfizh', peringkat: 3 },
  penguji: { n: 'Penguji', peringkat: 2 },
  muhaffizh: { n: 'Muhaffizh santri', peringkat: 1 },
}
export const DOK_TTD_TAHFIZH = [
  { kode: 'suket_juz', nama: 'Surat Keterangan Ujian Kenaikan Juz', peran: ['muhaffizh', 'penguji', 'kepala_tahfizh', 'direktur'], bawaan: ['kepala_tahfizh', 'penguji'] },
  { kode: 'sertifikat_hafalan', nama: 'Sertifikat Hafalan (sertifikasi 5, 10, 15 … juz)', peran: ['muhaffizh', 'penguji', 'kepala_tahfizh', 'direktur'], bawaan: ['kepala_tahfizh', 'penguji'] },
  { kode: 'sertifikat_khataman', nama: 'Sertifikat Penghargaan Khataman 30 juz', peran: ['muhaffizh', 'kepala_tahfizh', 'direktur'], bawaan: ['direktur', 'kepala_tahfizh'] },
  { kode: 'sertifikat_tahfizh', nama: 'Sertifikat Tahfizhul Quran (akhir jenjang)', peran: ['muhaffizh', 'kepala_tahfizh', 'direktur'], bawaan: ['direktur'] },
  { kode: 'suket_tahsin', nama: 'Surat Keterangan Hasil Ujian Tahsin', peran: ['muhaffizh', 'penguji', 'kepala_tahfizh', 'direktur'], bawaan: ['kepala_tahfizh', 'penguji'] },
]
/** Peringkat jabatan tertulis (untuk menyaring penanda tangan ganda pada dokumen lama). */
export function peringkatJabatan(j) {
  const t = String(j || '').toLowerCase()
  if (/direktur|mudir/.test(t)) return 4
  if (/kepala|ka\.? ?bid/.test(t)) return 3
  if (/penguji/.test(t)) return 2
  if (/muhaffi/.test(t)) return 1
  return 0
}
/** Penanda tangan unik: orang yang sama (nama/NIY) hanya sekali, dengan jabatan tertinggi pada posisinya. */
export function ttdUnik(daftar = []) {
  const hasil = []
  for (const t of daftar.filter(Boolean)) {
    const kunci = (x) => (x.employee_id || `${x.nama || ''}|${x.niy || ''}`).toLowerCase()
    const i = hasil.findIndex((x) => x.nama && kunci(x) === kunci(t))
    if (i < 0) { hasil.push({ ...t }); continue }
    const lama = hasil[i]; const tanda = lama.status === 'ditandatangani' || t.status === 'ditandatangani'
    const pilih = peringkatJabatan(t.jabatan) > peringkatJabatan(lama.jabatan) ? t : lama
    hasil[i] = { ...pilih, status: tanda ? 'ditandatangani' : pilih.status, waktu: pilih.waktu || lama.waktu || t.waktu }
  }
  if (hasil.length === 1) hasil[0] = { ...hasil[0], pengantar: '' }
  return hasil
}

// ---------- Penyelesaian aturan ----------
const bersih = (s) => (s ? { jabatan: s.jabatan_tertulis ?? s.jabatan ?? '', nama: s.nama || '', niy: s.niy || '' } : null)

/** Pejabat dari daftar signatories. */
export function pejabat(peran, signatories, jenjang = null, kelompok = null, bagian = null) {
  const aktif = (signatories || []).filter((s) => s.aktif !== false)
  const cari = (re) => aktif.find((s) => re.test(s.jabatan_tertulis || ''))
  const direktur = () => bersih(aktif.find((s) => s.sumber_jabatan === 'DIREKTUR') || cari(/^direktur$/i) || cari(/^direktur/i)) || { jabatan: 'Direktur', nama: '', niy: '' }
  const kepala = (j) => (j === 'sma' ? bersih(cari(/^kepala\s+sma/i)) || { jabatan: 'Kepala SMA', nama: '', niy: '' }
    : j === 'wustha' ? bersih(cari(/^kepala.*wustha/i)) || { jabatan: 'Kepala Kesetaraan Wustha', nama: '', niy: '' } : direktur())
  const tahfizh = () => bersih(cari(/tahfi[zd]h/i)) || { jabatan: 'Kepala Bidang Tahfizh', nama: '', niy: '' }
  const kesantrian = () => bersih(cari(/kesantrian/i)) || { jabatan: 'Kepala Bidang Kesantrian', nama: '', niy: '' }
  if (peran === 'direktur') return direktur()
  if (peran === 'kepala_unit') return kepala(jenjang)
  if (peran === 'pimpinan_bagian') {
    if (bagian === 'yayasan') return bersih(aktif.find((s) => s.sumber_jabatan === 'YAYASAN') || cari(/yayasan/i)) || { jabatan: 'Ketua Yayasan', nama: '', niy: '' }
    return bagian === 'sma' || bagian === 'wustha' ? kepala(bagian) : direktur()
  }
  if (peran === 'kabid_tahfizh') return tahfizh()
  if (peran === 'kabid_kesantrian') return kesantrian()
  if (peran === 'pimpinan_kelompok') {
    const j = kelompok?.jenis
    if (j === 'kelas' || (!j && jenjang)) return kepala(kelompok?.jenjang || jenjang)
    if (j === 'halaqah') return tahfizh()
    if (j === 'kamar' || j === 'asrama' || j === 'ekskul') return kesantrian()
    return direktur()
  }
  if (peran && !PERAN[peran] && peran !== '-') return bersih(aktif.find((s) => s.id === peran) || (signatories || []).find((s) => s.id === peran))
  return null
}

/**
 * Susun aturan satu dokumen.
 * konteks: { jenjang, kelompok: { jenis, jenjang }, bagian (kode kop penerbit), pengasuh, pihak, pembuat } — semuanya opsional.
 * pengguna: pengguna masuk (untuk peran pembuat bila halaman tidak menyediakannya).
 */
export function susunAturan(kode, { rules = [], signatories = [], letterheads = [], konteks = {}, pengguna = null } = {}) {
  const dok = cariDokumen(kode)
  if (!dok) return null
  const r = rules.find((x) => x.jenis_dokumen === kode)
  const atur = { kiri: r ? r.kiri ?? dok.bawaan.kiri : dok.bawaan.kiri, kanan: r ? r.kanan ?? dok.bawaan.kanan : dok.bawaan.kanan, kop: r ? r.kop_kode ?? null : dok.bawaan.kop }
  const k = konteks || {}
  const jenjang = k.jenjang || (k.kelompok?.jenis === 'kelas' ? k.kelompok?.jenjang : null) || null
  /** Sisi tanda tangan akhir. kiri/kanan = objek dari halaman. */
  function sisi(posisi, kiri, kanan) {
    const asal = posisi === 'kiri' ? kiri : kanan
    const lain = posisi === 'kiri' ? kanan : kiri
    const v = atur[posisi]
    if (!v || asal?.kode || asal?.elektronik) return asal                      // sudah ditandatangani elektronik: tetap
    if (v === dok.asli[posisi] && !PERAN[v]?.pejabat) return asal              // peran dokumen: dari halaman
    const tempel = (o) => (o ? { ...o, pengantar: asal?.pengantar } : asal)
    if (v === 'tidak_ada') return { pengantar: asal?.pengantar, jabatan: '', nama: '', niy: '', kosong: true }
    const pj = pejabat(v, signatories, jenjang, k.kelompok, k.bagian || null)
    if (pj) return tempel(pj)
    if (v === dok.asli[posisi === 'kiri' ? 'kanan' : 'kiri']) return tempel(lain)  // tukar sisi
    if (k[v]) return tempel(k[v])
    if (v === 'pembuat') return tempel({ jabatan: 'Pembuat', nama: pengguna?.nama_lengkap || '', niy: pengguna?.niy || '' })
    if (v === 'atasan_langsung') return tempel({ jabatan: 'Atasan Langsung', nama: '.....................................', niy: '' })
    return asal
  }
  function kop(kopHalaman) {
    if (atur.kop) return atur.kop
    if (k.bagian && letterheads.some((x) => x.kode === k.bagian)) return k.bagian
    if (jenjang && letterheads.some((x) => x.kode === jenjang)) return jenjang
    return kopHalaman
  }
  return { dok, atur, sisi, kop }
}
