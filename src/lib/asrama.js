// SIMKA PRO | src/lib/asrama.js | v1.0 | 14.35.0: peran sesi asrama (wajib/opsional), pengontrolan kamar, laporan WA sesi | 30/10/2026
// Sesi asrama mengikuti pola presensi musyrif. Setiap sesi berperan:
//   wajib    → absensi santri wajib diisi
//   opsional → musyrif tetap mengontrol kamar; absensi santri boleh diisi, tidak wajib
// Setiap sesi (wajib maupun opsional) dicatat pengontrolannya dengan ceklist butir yang dapat diatur.
import { formatHari } from './tanggal'

export const MODE_SESI = {
  wajib: { n: 'Wajib absen', ket: 'Absensi santri wajib diisi', w: 'presensi' },
  opsional: { n: 'Absen opsional', ket: 'Kontrol saja; absensi santri boleh diisi', w: 'shift' },
}
export const KODE_TIDAK = { I: 'izin', S: 'sakit', B: 'bolos', A: 'absen', T: 'terlambat' }

/** Keadaan sesi pada saat ini: belum_buka | berlangsung | lewat. */
export function keadaanSesi(s, kini = new Date()) {
  if (kini < new Date(s.buka)) return 'belum_buka'
  if (kini <= new Date(s.tutup)) return 'berlangsung'
  return 'lewat'
}
export const KEADAAN = {
  belum_buka: { n: 'Belum dibuka', w: 'hakakses' },
  berlangsung: { n: 'Sedang berlangsung', w: 'shift' },
  lewat: { n: 'Sudah lewat', w: 'rekap' },
}

/** Ringkasan satu sesi untuk kartu: { absenWajibBelum, kontrolBelum }. */
export function statusSesiAsrama(s, kini = new Date()) {
  const k = keadaanSesi(s, kini)
  return { keadaan: k, absenBelum: s.mode === 'wajib' && !s.absensi && k !== 'belum_buka', kontrolBelum: !s.kontrol && k !== 'belum_buka' }
}

const salam = "Assalamu'alaikum warahmatullahi wabarakatuh."
const penutup = 'Jazakumullahu khairan.'
const jam = (t) => String(t || '').slice(0, 5).replace(':', '.')

/** Baris laporan satu sesi. format: 'lengkap' (internal: nama dan keterangan) | 'ringkas' (angka saja, tanpa alasan pribadi). */
export function barisSesi(s, jumlahSantri, format = 'lengkap') {
  const b = [`*${s.nama}* (${jam(s.jam_mulai)}–${jam(s.jam_selesai)} WITA)${s.mode === 'opsional' ? ' — sesi kontrol' : ''}`]
  const a = s.absensi
  if (a) {
    const lain = [['izin', a.izin], ['sakit', a.sakit], ['bolos', a.bolos], ['absen', a.absen], ['terlambat', a.terlambat]].filter((x) => x[1]).map((x) => `${x[0]} ${x[1]}`)
    b.push(`• Kehadiran: ${a.hadir}/${a.jumlah_anggota} santri hadir${lain.length ? ' (' + lain.join(', ') + ')' : ''}`)
    if (format === 'lengkap' && a.tidak?.length) a.tidak.forEach((x) => b.push(`   – ${x.nama}: ${KODE_TIDAK[x.kode] || x.kode}${x.kode !== 'S' && x.keterangan ? ' (' + x.keterangan + ')' : ''}`))
    else if (!lain.length) b.push('• Alhamdulillah, seluruh santri hadir.')
  } else if (s.mode === 'wajib') b.push(`• Absensi santri: belum diisi (${jumlahSantri} santri)`)
  else b.push('• Absensi santri: tidak diisi (sesi kontrol)')
  const k = s.kontrol
  if (k) {
    k.butir.forEach((x) => b.push(`${x.ok ? '✅' : '⬜'} ${x.teks}`))
    if (k.catatan) b.push(`• Catatan: ${k.catatan}`)
  } else b.push('• Pengontrolan: belum dicatat')
  return b.join('\n')
}

/** Laporan satu sesi atau beberapa sesi satu kamar pada satu tanggal ke grup WhatsApp. */
export function laporanAsramaWA({ kamar, tanggal, sesi, jumlahSantri, pengirim, format = 'lengkap' }) {
  const satu = sesi.length === 1
  const kepala = satu
    ? `Laporan ${sesi[0].nama.toLowerCase()} *${kamar}*\n${formatHari(tanggal)}`
    : `Laporan sesi asrama *${kamar}*\n${formatHari(tanggal)} (${sesi.length} sesi)`
  const isi = sesi.map((s) => barisSesi(s, jumlahSantri, format)).join('\n\n')
  const ket = format === 'ringkas' ? '\n\nKeterangan pribadi santri tidak dicantumkan.' : ''
  return `${salam}\n\n${kepala}\nJumlah santri: ${jumlahSantri}\n\n${isi}${ket}\n\n${penutup}\n${pengirim || ''}\nMusyrif ${kamar}`.trim()
}

export const FORMAT_LAPORAN = [
  { k: 'lengkap', n: 'Lengkap', ket: 'Nama santri tidak hadir' },
  { k: 'ringkas', n: 'Ringkas', ket: 'Angka saja (grup wali)' },
]
