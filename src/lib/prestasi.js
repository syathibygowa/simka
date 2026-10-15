// SIMKA PRO | src/lib/prestasi.js | v1.0 | Tahap C: prestasi santri | 16/10/2026
// Istilah bidang dan tingkat prestasi santri, serta kalimat ringkas untuk surat/rapor.
export const BIDANG_PRESTASI = {
  tahfizh: { n: 'Tahfizh', w: 'tahfizh' }, akademik: { n: 'Akademik', w: 'laporan' }, keagamaan: { n: 'Keagamaan', w: 'santri' },
  non_akademik: { n: 'Non-akademik', w: 'ekskul' }, karakter: { n: 'Karakter/teladan', w: 'pengajuan' },
}
export const TINGKAT_PRESTASI = {
  pondok: 'Pondok', kecamatan: 'Kecamatan', kabupaten: 'Kabupaten/Kota', provinsi: 'Provinsi', nasional: 'Nasional', internasional: 'Internasional',
}
/** "Juara 1 MTQ Kabupaten Gowa tingkat Kabupaten/Kota (LPTQ Gowa, 2026)" */
export function kalimatPrestasi(p) {
  const tahun = String(p.tanggal || '').slice(0, 4)
  const tk = p.tingkat && p.tingkat !== 'pondok' ? ` tingkat ${TINGKAT_PRESTASI[p.tingkat] || p.tingkat}` : ''
  return `${p.capaian} ${p.nama_kegiatan}${tk} (${[p.penyelenggara, tahun].filter(Boolean).join(', ')})`
}
