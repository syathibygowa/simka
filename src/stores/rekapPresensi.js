// SIMKA PRO | src/stores/rekapPresensi.js | v1.0 | Fase 2 – Tahap 7 Statistik, rekap, pengingat | 03/10/2026
// Statistik presensi langsung (Realtime tabel attendances + penyegaran berkala) dan rekap harian/periode.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { usePegawai } from './pegawai'
import { hariIniISO } from '@/lib/tanggal'

async function rpc(nama, isi) {
  const { data, error } = await supabase.rpc(nama, isi)
  if (error) throw new Error(error.hint && error.message ? error.message : pesanGalat(error))
  return data
}
let kanal = null; let berkala = null; let tunda = null

// ---------- Mode demo: angka contoh yang wajar ----------
const acak = (s) => { let x = 0; for (const c of s) x = (x * 31 + c.charCodeAt(0)) % 9973; return x / 9973 }
function statDemo() {
  return { tanggal: hariIniISO(), pegawai_terjadwal: 94, pegawai_hadir: 81, sesi_wajib: 236, sesi_tercatat: 171, hadir: 139, terlambat: 18, dinas_luar: 3,
    izin_sakit_cuti: 6, menunggu_verval: 3, tanpa_keterangan: 2, terbuka_belum: 12, terlewat_belum: 4, akan_datang: 49, persen_kehadiran: 91.2,
    per_pola: [{ pola: 'Guru', wajib: 58, hadir: 52 }, { pola: 'Halaqah tahfizh', wajib: 72, hadir: 49 }, { pola: 'Asrama', wajib: 32, hadir: 18 },
      { pola: 'Staf dan kantor', wajib: 22, hadir: 20 }, { pola: 'Security', wajib: 3, hadir: 2 }, { pola: 'Klinik (medis)', wajib: 2, hadir: 1 }],
    verval_menunggu: 3, curiga_baru: 2 }
}
function rekapDemo() {
  return usePegawai().daftar.filter((p) => p.status_akun === 'aktif').map((p) => {
    const r = acak(p.id + p.nama_lengkap); const sesi = 40 + Math.round(r * 50)
    const tk = Math.round(r * 3); const izin = Math.round(r * 2); const sakit = r > 0.6 ? 1 : 0; const terlambat = Math.round(r * 6)
    const hadir = sesi - tk - izin - sakit - terlambat
    return { employee_id: p.id, nama: p.nama_lengkap, niy: p.niy, unit: p.nama_unit, org_unit_id: p.org_unit_id, jabatan: (p.jabatan_fungsional || []).join(', '),
      sesi, hadir, terlambat, dinas_luar: 0, izin, sakit, cuti: 0, tanpa_keterangan: tk, menunggu: 0, menit_terlambat: terlambat * 7,
      pulang_cepat: Math.round(r * 2), tidak_presensi_pulang: Math.round(r), persen: Math.round(1000 * (hadir + terlambat) / sesi) / 10 }
  })
}
function harianDemo(tanggal) {
  const baris = []
  usePegawai().daftar.filter((p) => p.status_akun === 'aktif').forEach((p, i) => {
    const r = acak(p.id + tanggal)
    const status = r < 0.7 ? 'hadir' : r < 0.82 ? 'terlambat' : r < 0.88 ? 'izin' : r < 0.94 ? null : 'tanpa_keterangan'
    baris.push({ employee_id: p.id, nama: p.nama_lengkap, niy: p.niy, unit: p.nama_unit, org_unit_id: p.org_unit_id, nama_pola: (p.jabatan_fungsional || ['Staf'])[0],
      nama_sesi: 'Jam kerja', mulai: `${tanggal}T07:30:00+08:00`, selesai: `${tanggal}T14:00:00+08:00`, wajib_pulang: true, opsional: false,
      status, terlambat_menit: status === 'terlambat' ? 5 + (i % 20) : 0, datang_pada: status && ['hadir', 'terlambat'].includes(status) ? `${tanggal}T07:${String(15 + (i % 40)).padStart(2, '0')}:00+08:00` : null,
      pulang_pada: null, status_pulang: status && ['hadir', 'terlambat'].includes(status) ? 'belum' : null, keadaan: status ? 'tercatat' : 'terbuka' })
  })
  return baris
}

export const useRekapPresensi = defineStore('rekapPresensi', {
  state: () => ({ stat: null, diperbarui: null, berubah: {} }),
  actions: {
    async muatStatistik() {
      let baru
      if (MODE_DEMO) baru = this.stat ? { ...this.stat } : statDemo()
      else { try { baru = await rpc('statistik_presensi', {}) } catch { return } }
      const b = {}
      if (this.stat) for (const k in baru) if (typeof baru[k] === 'number' && baru[k] !== this.stat[k]) b[k] = baru[k] > this.stat[k] ? 'naik' : 'turun'
      this.berubah = b; if (Object.keys(b).length) setTimeout(() => { this.berubah = {} }, 2500)
      this.stat = baru; this.diperbarui = new Date()
    },
    /** Mulai pembaruan langsung: setiap perubahan tabel presensi memicu muat ulang (dengan jeda 1 detik). */
    mulai() {
      this.muatStatistik()
      if (MODE_DEMO) {
        berkala = setInterval(() => {
          const d = { ...this.stat }; d.hadir += 1; d.sesi_tercatat += 1; d.akan_datang = Math.max(0, d.akan_datang - 1)
          this.berubah = { hadir: 'naik', sesi_tercatat: 'naik' }; setTimeout(() => { this.berubah = {} }, 2500)
          this.stat = d; this.diperbarui = new Date()
        }, 8000)
        return
      }
      const segarkan = () => { clearTimeout(tunda); tunda = setTimeout(() => this.muatStatistik(), 1000) }
      kanal = supabase.channel('statistik-presensi')
        .on('postgres_changes', { event: '*', schema: 'public', table: 'attendances' }, segarkan)
        .subscribe()
      berkala = setInterval(() => this.muatStatistik(), 60000)
    },
    berhenti() { kanal?.unsubscribe(); kanal = null; clearInterval(berkala); clearTimeout(tunda) },

    async harian(tanggal) {
      if (MODE_DEMO) { const peg = usePegawai(); if (!peg.daftar.length) await peg.muat(); return harianDemo(tanggal) }
      return await rpc('rekap_harian', { p_tanggal: tanggal })
    },
    async periode(mulai, akhir) {
      if (MODE_DEMO) { const peg = usePegawai(); if (!peg.daftar.length) await peg.muat(); return rekapDemo() }
      return await rpc('rekap_presensi', { p_mulai: mulai, p_akhir: akhir })
    },
  },
})
