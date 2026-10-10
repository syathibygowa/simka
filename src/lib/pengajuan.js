// SIMKA PRO | src/lib/pengajuan.js | v1.1 | Fase 8 – Tahap 0b Kepala Unit tidak lagi menyetujui pengajuan | 10/10/2026
// Label, warna, dan kalimat aturan pengajuan pegawai.
import { PhThermometer, PhHandPalm, PhBriefcase, PhUmbrella } from '@phosphor-icons/vue'

export const STATUS_PENGAJUAN = {
  menunggu: { n: 'Menunggu', w: 'tahfizh' }, disetujui: { n: 'Disetujui', w: 'presensi' },
  ditolak: { n: 'Ditolak', w: 'beranda' }, dibatalkan: { n: 'Dibatalkan', w: 'hakakses' },
}
export const STATUS_JENJANG = {
  antre: { n: 'Belum', w: 'hakakses' }, menunggu: { n: 'Menunggu', w: 'tahfizh' }, disetujui: { n: 'Disetujui', w: 'presensi' },
  ditolak: { n: 'Ditolak', w: 'beranda' }, dilewati: { n: 'Dilewati', w: 'hakakses' },
}
export const KELOMPOK = {
  sakit: { n: 'Sakit', ikon: PhThermometer, w: 'klinik' }, izin: { n: 'Izin', ikon: PhHandPalm, w: 'pengajuan' },
  dinas_luar: { n: 'Dinas luar', ikon: PhBriefcase, w: 'pegawai' }, cuti: { n: 'Cuti', ikon: PhUmbrella, w: 'santri' },
}
export const PERAN_JENJANG = { kepala_bidang: 'Kepala Bidang', direktur: 'Direktur/Wakil Direktur', yayasan: 'Ketua Yayasan' }

/** Kalimat aturan satu jenis pengajuan (dibaca semua pegawai di tab Ketentuan dan formulir). */
export function kalimatAturan(j) {
  const k = []
  if (j.maks_hari) k.push(`Paling lama ${j.maks_hari} hari per pengajuan.`)
  if (j.kuota_tahunan_hari != null) k.push(`Kuota ${j.kuota_tahunan_hari} hari per tahun.`)
  if (j.batas_bulanan_hari != null) k.push(`Paling banyak ${j.batas_bulanan_hari} hari per bulan.`)
  if (j.batas_bulanan_kali != null) k.push(`Paling banyak ${j.batas_bulanan_kali} kali per bulan.`)
  if ((j.kuota_tahunan_hari != null || j.batas_bulanan_hari != null || j.batas_bulanan_kali != null) && j.aturan_kuota === 'peringatan')
    k.push('Melebihi kuota tetap dapat diajukan dengan tanda peringatan bagi penyetuju.')
  if (j.maju_maks_hari === 0) k.push('Tanggal mulai harus hari ini (diajukan pada hari pertama).')
  else if (j.maju_maks_hari != null) k.push(`Tanggal mulai paling jauh ${j.maju_maks_hari} hari ke depan.`)
  if (j.maju_min_hari > 0) k.push(`Diajukan paling lambat H-${j.maju_min_hari}.`)
  if (j.mundur_maks_hari > 0) k.push(`Boleh diajukan susulan paling lama ${j.mundur_maks_hari} hari setelah tanggal mulai.`)
  if (j.lampiran_wajib_min_hari != null) k.push(j.lampiran_wajib_min_hari <= 1 ? `Wajib melampirkan bukti${j.lampiran_keterangan ? ` (${j.lampiran_keterangan.toLowerCase()})` : ''}.`
    : `Wajib melampirkan bukti bila ${j.lampiran_wajib_min_hari} hari atau lebih${j.lampiran_keterangan ? ` (${j.lampiran_keterangan.toLowerCase()})` : ''}.`)
  else if (j.lampiran_keterangan) k.push(`Lampiran dianjurkan: ${j.lampiran_keterangan.toLowerCase()}.`)
  if (j.khusus_jk) k.push(`Khusus pegawai ${j.khusus_jk === 'P' ? 'perempuan' : 'laki-laki'}.`)
  return k
}

/** Jumlah hari kalender dari dua tanggal yyyy-mm-dd (inklusif). */
export function hitungHari(mulai, selesai) {
  if (!mulai || !selesai) return 0
  return Math.round((Date.parse(selesai + 'T00:00:00Z') - Date.parse(mulai + 'T00:00:00Z')) / 86400000) + 1
}
export const rentangTanggal = (r, f) => (r.selesai && r.selesai !== r.mulai ? `${f(r.mulai)} s.d. ${f(r.selesai)}` : f(r.mulai))
