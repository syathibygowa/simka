// SIMKA PRO | src/stores/laporanKehadiran.js | v1.0 | Fase 8 – Tahap 2 Laporan kehadiran pegawai | 10/10/2026
// Memuat laporan kehadiran pegawai dari server (hak cakupan diperiksa server) atau data contoh pada mode demo.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { usePegawai } from './pegawai'
import { useSesi } from './sesi'
import { daftarTanggal } from '@/lib/laporanKehadiran'

const acak = (s) => { let x = 7; for (const c of s) x = (x * 31 + c.charCodeAt(0)) % 99991; const y = Math.sin(x) * 10000; return y - Math.floor(y) }
async function demo(mulai, selesai, cakupan, nilai, rinci) {
  const peg = usePegawai(); if (!peg.daftar.length) await peg.muat()
  let daftar = peg.daftar.filter((p) => p.status_akun === 'aktif')
  if (cakupan === 'saya') daftar = daftar.slice(0, 1)
  if (cakupan === 'individu') daftar = daftar.filter((p) => p.id === nilai)
  if (cakupan === 'bidang') daftar = daftar.filter((p) => p.org_unit_id === nilai)
  const hari = daftarTanggal(mulai, selesai).filter((d) => new Date(d + 'T00:00:00Z').getUTCDay() !== 0)
  const baris = []
  const pegawai = daftar.map((p) => {
    const hit = { hadir: 0, terlambat: 0, dinas_luar: 0, izin: 0, sakit: 0, cuti: 0, tanpa_keterangan: 0, menunggu_verval: 0 }; let menit = 0; let cepat = 0
    for (const d of hari) {
      const r = acak(p.id + d); const st = r < 0.74 ? 'hadir' : r < 0.86 ? 'terlambat' : r < 0.89 ? 'dinas_luar' : r < 0.93 ? 'izin' : r < 0.955 ? 'sakit' : r < 0.97 ? 'cuti' : 'tanpa_keterangan'
      hit[st]++; const tm = st === 'terlambat' ? 3 + Math.round(r * 40) % 25 : 0; menit += tm; if (r > 0.5 && r < 0.53) cepat++
      if (rinci) baris.push({ employee_id: p.id, tanggal: d, nama_pola: (p.jabatan_fungsional || ['Staf'])[0], nama_sesi: 'Jam kerja', mulai: `${d}T07:30:00+08:00`, selesai: `${d}T14:00:00+08:00`,
        status: st, terlambat_menit: tm, datang_pada: ['hadir', 'terlambat', 'dinas_luar'].includes(st) ? `${d}T07:${String(10 + tm + 20).padStart(2, '0')}:00+08:00` : null,
        pulang_pada: ['hadir', 'terlambat'].includes(st) ? `${d}T14:0${Math.round(r * 9)}:00+08:00` : null, status_pulang: ['hadir', 'terlambat'].includes(st) ? 'tepat' : null,
        titik: ['hadir', 'terlambat'].includes(st) ? 'Gedung Utama' : null, keterangan: st === 'izin' ? 'Keperluan keluarga' : st === 'sakit' ? 'Demam' : st === 'dinas_luar' ? 'Rapat di kantor Kemenag' : null,
        tidak_presensi: st === 'tanpa_keterangan' })
    }
    const wajib = hari.length; const total = hit.hadir + hit.terlambat + hit.dinas_luar
    return { employee_id: p.id, nama: p.nama_lengkap, niy: p.niy, status_kepegawaian: p.status_kepegawaian, unit: p.nama_unit, jabatan: (p.jabatan_fungsional || []).join(', '),
      sesi_wajib: wajib, ...hit, menunggu: hit.menunggu_verval, menit_terlambat: menit, tidak_presensi: hit.tanpa_keterangan, cepat_pulang: cepat, tidak_presensi_pulang: 0,
      total_hadir: total, persen: wajib ? Math.round((1000 * total) / wajib) / 10 : null }
  })
  return { pegawai, rinci: baris, mulai, selesai }
}

export const useLaporanKehadiran = defineStore('laporanKehadiran', {
  state: () => ({ data: null, memuat: false }),
  actions: {
    async muat({ mulai, selesai, cakupan, nilai = null, rinci = false }) {
      this.memuat = true
      try {
        if (MODE_DEMO) { this.data = await demo(mulai, selesai, cakupan, nilai, rinci); return this.data }
        const { data, error } = await supabase.rpc('laporan_kehadiran_pegawai', { p_mulai: mulai, p_selesai: selesai, p_cakupan: cakupan, p_nilai: nilai, p_rinci: rinci })
        if (error) throw new Error(pesanGalat(error))
        this.data = data; return data
      } finally { this.memuat = false }
    },
  },
})
export const bolehPantau = () => { const s = useSesi(); return s.isAdmin || s.pimpinanTinggi }
