// SIMKA PRO | src/lib/izin.js | v1.3 | 14.22.0: pesan WA pimpinan sesuai tahap persetujuan | 25/10/2026
// Label baku perizinan santri (Blueprint Bagian 22–23): status, peran pengusul, unit pemutus, teks WA, hasil libur.
import { PhHourglass, PhCheckCircle, PhXCircle, PhSignOut, PhSignIn, PhProhibit, PhSealCheck } from '@phosphor-icons/vue'
import { formatWaktu } from './tanggal'
import { halamanAplikasi } from './wa'

export const STATUS_IZIN = {
  diajukan:          { n: 'Menunggu kepala bidang', p: 'Diajukan', w: 'pengajuan', ikon: PhHourglass },
  disetujui_bidang:  { n: 'Menunggu Direktur/Wadir', p: 'Menunggu pimpinan', w: 'agenda', ikon: PhSealCheck },
  disetujui:         { n: 'Disetujui, belum keluar', p: 'Disetujui', w: 'presensi', ikon: PhCheckCircle },
  keluar:            { n: 'Sedang di luar pondok', p: 'Keluar', w: 'shift', ikon: PhSignOut },
  kembali:           { n: 'Sudah kembali', p: 'Kembali', w: 'rekap', ikon: PhSignIn },
  ditolak:           { n: 'Ditolak', p: 'Ditolak', w: 'klinik', ikon: PhXCircle },
  dibatalkan:        { n: 'Dibatalkan', p: 'Dibatalkan', w: 'hakakses', ikon: PhProhibit },
}
export const PERAN_PENGUSUL = { musyrif: 'Musyrif', wali_kelas: 'Wali kelas', muhaffizh: 'Muhaffizh', petugas_klinik: 'Petugas klinik', admin: 'Admin', pimpinan: 'Pimpinan', pendamping: 'Pendamping' }
export const UNIT_IZIN = { KESANTRIAN: 'Kepala Bidang Kesantrian', TAHFIZH: 'Kepala Bidang Tahfizh', WUSTHA: 'Kepala Kesetaraan Wustha', SMA: 'Kepala SMA' }
export const JENIS_IZIN = { pulang: 'Pulang (menginap)', keluar: 'Keluar beberapa jam', libur: 'Libur pondok' }

// ---------- Libur santri (Bagian 23) ----------
export const HASIL_LIBUR = {
  boleh:        { n: 'Boleh libur', w: 'presensi', ikon: PhCheckCircle },
  tidak:        { n: 'Tidak libur', w: 'klinik', ikon: PhXCircle },
  pertimbangan: { n: 'Perlu pertimbangan', w: 'pengajuan', ikon: PhHourglass },
}
export const STATUS_PERIODE = {
  draf:     { n: 'Draf', w: 'hakakses' },
  dinilai:  { n: 'Sudah dinilai', w: 'pengajuan' },
  disahkan: { n: 'Disahkan', w: 'presensi' },
  batal:    { n: 'Dibatalkan', w: 'klinik' },
}
export const JENIS_PERIODE = { bulanan: 'Libur bulanan', semester: 'Libur semester', khusus: 'Libur khusus' }
export const SYARAT_LIBUR = [
  { k: 'kelas_min', n: 'Kehadiran kelas minimal', s: '%' }, { k: 'halaqah_min', n: 'Kehadiran halaqah minimal', s: '%' },
  { k: 'asrama_min', n: 'Kehadiran asrama minimal', s: '%' }, { k: 'izin_maks', n: 'Izin keluar maksimal', s: 'kali' },
  { k: 'terlambat_maks', n: 'Terlambat kembali maksimal', s: 'kali' }, { k: 'hafalan_min_halaman', n: 'Tambahan hafalan minimal', s: 'halaman' },
  { k: 'margin', n: 'Rentang "perlu pertimbangan" di bawah ambang', s: '%' },
]

/** Label status untuk kartu, termasuk "Terlambat kembali". */
export function labelIzin(x) {
  if (x.terlambat && x.status === 'keluar') return { n: 'Terlambat kembali', w: 'klinik' }
  return { n: STATUS_IZIN[x.status]?.n || x.status, w: STATUS_IZIN[x.status]?.w || 'hakakses' }
}
export const rentangIzin = (x) => `${formatWaktu(x.keluar_pada)} s.d. ${formatWaktu(x.kembali_batas)}`

// ---------- 14.20.0: izin kolektif, surat, pesan WA ----------
export const STATUS_KOLEKTIF = {
  diajukan:         { n: 'Menunggu Kepala Bidang Kesantrian', w: 'pengajuan', ikon: PhHourglass },
  disetujui_bidang: { n: 'Menunggu Direktur/Wadir', w: 'agenda', ikon: PhSealCheck },
  disetujui:        { n: 'Disetujui', w: 'presensi', ikon: PhCheckCircle },
  selesai:          { n: 'Selesai, semua kembali', w: 'rekap', ikon: PhSignIn },
  ditolak:          { n: 'Ditolak', w: 'klinik', ikon: PhXCircle },
  dibatalkan:       { n: 'Dibatalkan', w: 'hakakses', ikon: PhProhibit },
}
/** Ada surat resmi (bernomor) untuk izin ini. */
export const adaSurat = (x) => !!x?.nomor_surat && ['disetujui', 'keluar', 'kembali', 'selesai'].includes(x.status)
const penjemputTeks = (x) => (x.penjemput ? `${x.penjemput}${x.hubungan_penjemput ? ' (' + x.hubungan_penjemput + ')' : ''}` : '–')

/** Isi pesan WA "minta persetujuan" izin perorangan kepada pemutus p ({ nama, jabatan, tingkat }). */
export function dataMintaIzin(x, p, kelas = '') {
  return { nama: p.nama, jabatan: p.jabatan, jenis_izin: x.jenis === 'keluar' ? 'keluar' : 'pulang', nama_santri: x.nama, kelas: kelas || x.kelas || x.kamar || '',
    alasan: x.alasan, waktu_keluar: formatWaktu(x.keluar_pada) + ' WITA', batas_kembali: formatWaktu(x.kembali_batas) + ' WITA', penjemput: penjemputTeks(x),
    keterangan: p.tingkat === 2 ? (x.status === 'disetujui_bidang' ? `Izin ${x.lama_hari} hari ini telah disetujui ${x.pemutus || 'kepala bidang'} dan memerlukan persetujuan pimpinan.`
      : `Izin ${x.lama_hari} hari ini sedang menunggu ${x.pemutus || 'kepala bidang'} dan selanjutnya memerlukan persetujuan pimpinan.`) : '',
    tautan: halamanAplikasi('/izin-santri/persetujuan') }
}
/** Isi pesan WA "minta persetujuan" izin kolektif. */
export function dataMintaKolektif(k, p) {
  const aktif = (k.anggota || []).filter((a) => !['dibatalkan', 'ditolak'].includes(a.status))
  return { nama: p.nama, jabatan: p.jabatan, kegiatan: k.kegiatan, jumlah: aktif.length, tempat: k.tempat || '–', waktu_keluar: formatWaktu(k.keluar_pada) + ' WITA',
    batas_kembali: formatWaktu(k.kembali_batas) + ' WITA', pendamping: k.pendamping || '–',
    daftar: aktif.map((a) => `${a.nama}${a.kelas ? ' (' + a.kelas + ')' : ''}`).join(', '),
    keterangan: p.tingkat === 2 ? (k.status === 'disetujui_bidang' ? 'Telah disetujui Kepala Bidang Kesantrian dan memerlukan persetujuan pimpinan.' : 'Sedang menunggu Kepala Bidang Kesantrian dan selanjutnya memerlukan persetujuan pimpinan.') : '',
    tautan: halamanAplikasi(`/izin-santri/kolektif?izin=${k.id}`) }
}
/** Isi pesan WA izin kolektif kepada orang tua/wali seorang anggota. */
export function dataWaliKolektif(k, a, kontak) {
  return { nama_wali: kontak?.nama || 'orang tua/wali', nama_santri: a.nama, kelas: a.kelas || a.kamar || '', kegiatan: k.kegiatan,
    status: { diajukan: 'sedang diajukan', disetujui_bidang: 'sedang diajukan', disetujui: 'telah mendapat', keluar: 'sedang menjalani', kembali: 'telah selesai menjalani', selesai: 'telah selesai menjalani' }[a.status] || 'mendapat',
    jumlah: Math.max(0, (k.anggota || []).filter((x) => !['dibatalkan', 'ditolak'].includes(x.status)).length - 1), tempat: k.tempat || '–',
    waktu_keluar: formatWaktu(k.keluar_pada) + ' WITA', batas_kembali: formatWaktu(k.kembali_batas) + ' WITA', pendamping: `${k.pendamping || '–'}${k.hp_pendamping ? ' (' + k.hp_pendamping + ')' : ''}` }
}

