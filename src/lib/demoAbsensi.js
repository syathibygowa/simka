// SIMKA PRO | src/lib/demoAbsensi.js | v1.1 | Fase 4 – Tahap 4 Ekskul | 04/10/2026
// Absensi santri contoh untuk MODE DEMO (tujuh hari terakhir terisi acak, hari ini sebagian).
import { dataKelompokDemo, ID_PEGAWAI_DEMO } from './demoKelompok'

export const SESI_DEMO = {
  kelas: [{ kode: 'KELAS', nama: 'Absensi kelas', jam_mulai: '07:00', jam_selesai: '12:00', buka: 0 }],
  halaqah: [{ kode: 'SUBUH', nama: 'Halaqah subuh', jam_mulai: '05:00', jam_selesai: '06:30', buka: 30 },
    { kode: 'SORE', nama: 'Halaqah sore', jam_mulai: '15:30', jam_selesai: '16:00', buka: 30 },
    { kode: 'MALAM', nama: 'Halaqah malam', jam_mulai: '18:30', jam_selesai: '19:30', buka: 30 }],
  asrama: [{ kode: 'PAGI', nama: 'Asrama pagi', jam_mulai: '04:00', jam_selesai: '07:00', buka: 30 },
    { kode: 'MALAM', nama: 'Asrama malam', jam_mulai: '21:00', jam_selesai: '00:00', buka: 30 }],
}
const jenisDari = (g) => (g.jenis === 'kamar' ? 'asrama' : g.jenis)
const dowWITA = (tgl) => new Date(`${tgl}T12:00:00+08:00`).getUTCDay()
const hariIniWITA = () => new Date(Date.now() + 8 * 3600000).toISOString().slice(0, 10)
// Jadwal pertemuan ekskul contoh: Panahan Selasa–Kamis dan hari ini (agar tampak di demo), Pramuka Sabtu
export const JADWAL_EKSKUL_DEMO = {
  'g-epn': [{ id: 'j1', hari: 2, jam_mulai: '15:30', jam_selesai: '17:00', tempat: 'Lapangan panahan' }, { id: 'j2', hari: 4, jam_mulai: '15:30', jam_selesai: '17:00', tempat: 'Lapangan panahan' }],
  'g-epr': [{ id: 'j3', hari: 6, jam_mulai: '07:30', jam_selesai: '09:30', tempat: 'Halaman masjid' }],
}
if (![2, 4].includes(dowWITA(hariIniWITA()))) JADWAL_EKSKUL_DEMO['g-epn'].push({ id: 'j0', hari: dowWITA(hariIniWITA()), jam_mulai: '16:00', jam_selesai: '23:30', tempat: 'Lapangan panahan' })
const kodeEks = (j) => 'EKS_' + j.id.toUpperCase()
/** Sesi satu kelompok pada satu tanggal (demo). */
export function sesiDemoUntuk(g, tgl) {
  if (g.jenis !== 'ekskul') return SESI_DEMO[jenisDari(g)] || []
  return (JADWAL_EKSKUL_DEMO[g.id] || []).filter((j) => j.hari === dowWITA(tgl))
    .map((j) => ({ kode: kodeEks(j), nama: 'Pertemuan ekskul', jam_mulai: j.jam_mulai, jam_selesai: j.jam_selesai, buka: 30, tempat: j.tempat }))
}
const TOPIK = ['Teknik berdiri dan memegang busur', 'Latihan jarak 10 meter', 'Tali-temali dan simpul dasar', 'Baris-berbaris', 'Evaluasi dan permainan kelompok']
const waktu = (tgl, j, tambahMenit = 0) => new Date(new Date(`${tgl}T${j}:00+08:00`).getTime() + tambahMenit * 60000) // jam WITA

let data = null
export function dataAbsensiDemo() {
  if (data) return data
  const k = dataKelompokDemo([])
  const sesi = {} // kunci group|tanggal|sesi → { …, pengecualian: [] }
  const hari = new Date(Date.now() + 8 * 3600000) // tanggal WITA
  for (let i = 7; i >= 0; i--) {
    const d = new Date(hari); d.setUTCDate(d.getUTCDate() - i); const tgl = d.toISOString().slice(0, 10)
    for (const g of k.kelompok.filter((x) => ['kelas', 'halaqah', 'kamar', 'ekskul'].includes(x.jenis) && x.aktif)) {
      for (const s of sesiDemoUntuk(g, tgl)) {
        if (i === 0 && waktu(tgl, s.jam_selesai, s.jam_selesai <= s.jam_mulai ? 1440 : 0) > new Date()) continue // sesi hari ini yang belum selesai belum terisi
        if (i > 0 && (g.id.length + i + s.kode.length) % 9 === 0) continue        // sesekali tidak terisi
        const anggota = k.anggota.filter((a) => a.group_id === g.id && !a.selesai).map((a) => a.student_id)
        const pengecualian = anggota.filter((_, n) => (n + i + s.kode.length) % 11 === 0)
          .map((sid, n) => ({ student_id: sid, kode: ['S', 'I', 'T', 'A', 'B'][(n + i) % 5], keterangan: (n + i) % 5 === 0 ? 'Demam, istirahat di kamar' : null }))
        sesi[`${g.id}|${tgl}|${s.kode}`] = { id: `sa-${g.id}-${tgl}-${s.kode}`, group_id: g.id, jenis: jenisDari(g), tanggal: tgl, sesi: s.kode, nama_sesi: s.nama,
          jumlah_anggota: anggota.length, pengecualian, atas_nama: false, diisi_terlambat: false, diisi_pada: waktu(tgl, s.jam_mulai, 20).toISOString(),
          pengampu: g.pengasuh[0]?.nama || null, diinput_oleh: g.pengasuh[0]?.nama || 'Admin', log: [],
          jurnal: g.jenis === 'ekskul' ? { topik: TOPIK[(i + g.id.length) % TOPIK.length], uraian: 'Latihan rutin sesuai program pekan ini (contoh).', foto_id: null } : null, tempat: s.tempat }
      }
    }
  }
  data = { sesi, kelompok: k }
  return data
}
export const hitung = (s) => {
  const n = (kd) => s.pengecualian.filter((x) => x.kode === kd).length
  return { jumlah_izin: n('I'), jumlah_sakit: n('S'), jumlah_bolos: n('B'), jumlah_absen: n('A'), jumlah_terlambat: n('T'),
    jumlah_hadir: s.jumlah_anggota - n('I') - n('S') - n('A') }
}
/** Daftar sesi seperti fungsi sesi_absensi() di server. */
export function sesiAbsensiDemo(tanggal, semua, peranPegawai) {
  const d = dataAbsensiDemo(); const kini = new Date(); const akhir = waktu(tanggal, '23:59')
  const hasil = []
  for (const g of d.kelompok.kelompok.filter((x) => ['kelas', 'halaqah', 'kamar', 'ekskul'].includes(x.jenis) && x.aktif)) {
    const saya = g.pengasuh.some((p) => p.employee_id === ID_PEGAWAI_DEMO) && peranPegawai
    if (!semua && !saya) continue
    for (const s of sesiDemoUntuk(g, tanggal)) {
      const mulai = waktu(tanggal, s.jam_mulai); const selesai = waktu(tanggal, s.jam_selesai, s.jam_selesai <= s.jam_mulai ? 1440 : 0)
      const buka = new Date(mulai.getTime() - s.buka * 60000); const tutup = new Date(selesai.getTime() + (s.buka ? 45 : 0) * 60000)
      const batas = new Date(Math.max(tutup, akhir)); const sa = d.sesi[`${g.id}|${tanggal}|${s.kode}`]
      hasil.push({ group_id: g.id, jenis: jenisDari(g), jenis_kelompok: g.jenis, nama_kelompok: g.nama, jenis_kelamin: g.jenis_kelamin, tanggal,
        sesi: s.kode, nama_sesi: s.nama, jam_mulai: s.jam_mulai, jam_selesai: s.jam_selesai, mulai: mulai.toISOString(), buka: buka.toISOString(), tutup: tutup.toISOString(), batas: batas.toISOString(),
        status: sa ? 'terisi' : kini < buka ? 'belum_buka' : kini <= tutup ? 'terbuka' : kini <= batas ? 'lewat' : 'tidak_terisi',
        session_id: sa?.id || null, jumlah_anggota: sa?.jumlah_anggota ?? d.kelompok.anggota.filter((a) => a.group_id === g.id && !a.selesai).length,
        ...(sa ? hitung(sa) : {}), atas_nama: sa?.atas_nama, diisi_terlambat: sa?.diisi_terlambat, diisi_pada: sa?.diisi_pada,
        asuhan_saya: saya, pengampu: g.pengasuh.map((p) => p.nama).join(', '), tempat: s.tempat, topik: sa?.jurnal?.topik || null })
    }
  }
  return hasil.sort((a, b) => a.mulai.localeCompare(b.mulai) || a.nama_kelompok.localeCompare(b.nama_kelompok, 'id', { numeric: true }))
}
