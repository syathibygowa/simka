// SIMKA PRO | src/stores/laporanSantri.js | v1.0 | Fase 8 – Tahap 3 Laporan kehadiran santri | 10/10/2026
// Memuat laporan kehadiran santri dari server (hak diperiksa server: pengasuh hanya santri asuhannya) atau contoh mode demo.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { useSantri } from './santri'
import { daftarTanggal } from '@/lib/laporanKehadiran'

const acak = (s) => { let x = 7; for (const c of s) x = (x * 31 + c.charCodeAt(0)) % 99991; const y = Math.sin(x) * 10000; return y - Math.floor(y) }
async function demo(mulai, selesai, cakupan, kelompok, kegiatan, rinci) {
  const st = useSantri(); if (!st.daftar.length) await st.muat()
  let daftar = st.daftar.filter((s) => s.status === 'aktif')
  daftar = cakupan === 'santri' ? daftar.filter((s) => s.id === kelompok) : daftar.slice(0, 24)
  const jenis = kegiatan === 'pokok' ? ['kelas', 'halaqah', 'asrama'] : [kegiatan]
  const SESI = { kelas: ['Absensi kelas'], halaqah: ['Halaqah subuh', 'Halaqah sore', 'Halaqah malam'], asrama: ['Asrama malam', 'Asrama pagi'], ekskul: ['Pertemuan ekskul'] }
  const hari = daftarTanggal(mulai, selesai).filter((d) => new Date(d + 'T00:00:00Z').getUTCDay() !== 0)
  const baris = []
  const santri = daftar.map((s) => {
    const h = { H: 0, T: 0, B: 0, I: 0, S: 0, A: 0 }; const pk = {}
    for (const d of hari) for (const j of jenis) for (const n of (j === 'ekskul' && new Date(d).getUTCDay() % 3 ? [] : SESI[j])) {
      const r = acak(s.id + d + n); const k = r < 0.84 ? 'H' : r < 0.9 ? 'T' : r < 0.93 ? 'I' : r < 0.96 ? 'S' : r < 0.98 ? 'B' : 'A'
      h[k]++; (pk[j] ||= { sesi: 0, hadir: 0 }).sesi++; if ('HTB'.includes(k)) pk[j].hadir++
      if (rinci) baris.push({ student_id: s.id, tanggal: d, jenis: j, nama_sesi: n, kelompok: j === 'kelas' ? s.kelas : j === 'asrama' ? s.kamar : s.halaqah, kode: k,
        keterangan: k === 'I' ? 'Izin pulang' : k === 'S' ? 'Klinik: istirahat di kamar' : null })
    }
    const sesi = Object.values(h).reduce((a, b) => a + b, 0); const total = h.H + h.T + h.B
    return { student_id: s.id, nama: s.nama_lengkap, nis: s.nis, jenis_kelamin: s.jenis_kelamin, jenjang: s.jenjang, kelas: s.kelas, kamar: s.kamar, halaqah: s.halaqah,
      sesi, hadir: h.H, terlambat: h.T, bolos: h.B, izin: h.I, sakit: h.S, absen: h.A, total_hadir: total, persen: sesi ? Math.round((1000 * total) / sesi) / 10 : null, per_kegiatan: pk }
  })
  const pengisian = [['7A', 'kelas', 'Ustzh. Nurul Aini, S.Pd.', 9, 9], ['Halaqah Ust. Hasan', 'halaqah', 'Ust. Hasan Basri, Lc.', 27, 25], ['Kamar Umar', 'kamar', 'Ust. Muhammad Ikhsan, S.Pd.I.', 18, 12],
    ['8B', 'kelas', 'Ust. Syamsul Arifin, S.Pd.', 9, 7]].map(([nama, jenis, pengampu, rencana, terisi], i) => ({ group_id: 'g' + i, nama, jenis, pengampu, rencana, terisi }))
  return { santri, rinci: baris, pengisian, mulai, selesai, kegiatan }
}

export const useLaporanSantri = defineStore('laporanSantri', {
  state: () => ({ data: null, memuat: false }),
  actions: {
    async muat({ mulai, selesai, cakupan, kelompok = null, jenjang = null, kegiatan = 'pokok', rinci = false }) {
      this.memuat = true
      try {
        if (MODE_DEMO) { this.data = await demo(mulai, selesai, cakupan, kelompok, kegiatan, rinci); return this.data }
        const { data, error } = await supabase.rpc('laporan_kehadiran_santri', { p_mulai: mulai, p_selesai: selesai, p_cakupan: cakupan, p_kelompok: kelompok,
          p_jenjang: jenjang, p_kegiatan: kegiatan, p_rinci: rinci })
        if (error) throw new Error(pesanGalat(error))
        this.data = data; return data
      } finally { this.memuat = false }
    },
  },
})
