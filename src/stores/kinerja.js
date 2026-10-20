// SIMKA PRO | src/stores/kinerja.js | v1.0 | 14.18.0: indikator kinerja bidang (Layar Pantauan dan Rekap dan Laporan) | 21/10/2026
// Memuat angka mentah kinerja_bidang(mulai, selesai) dari server lalu diolah src/lib/kinerja.js (persentase, skor, predikat, catatan).
// Hak lihat diperiksa server: pengguna Layar Pantauan, pimpinan (Direktur, Wakil Direktur, Yayasan, Kepala Bidang), pengelola laporan.
// Hasil disimpan per periode agar Layar Pantauan dan tab laporan tidak memuat ulang data yang sama.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { usePegawai } from './pegawai'
import { olah } from '@/lib/kinerja'
import { daftarTanggal } from '@/lib/laporanKehadiran'

const acak = (s) => { let x = 11; for (const c of s) x = (x * 31 + c.charCodeAt(0)) % 99991; const y = Math.sin(x) * 10000; return y - Math.floor(y) }
const BIDANG = [['WUSTHA', 'Bidang Kesetaraan Wustha', 'Ust. Ahmad Syarif, S.Pd.'], ['SMA', 'Bidang SMA', 'Ust. Muhammad Ilham, M.Pd.'], ['TAHFIZH', 'Bidang Tahfizh', 'Ust. Abdul Hafizh, Lc.'],
  ['KESANTRIAN', 'Bidang Kesantrian', 'Ust. Rahmat Hidayat, S.Pd.I.'], ['BAHASA', 'Bidang Bahasa', 'Ust. Faisal Arif, Lc.'], ['UMUM', 'Bidang Umum', 'Ust. Fadhil Rahman, S.Kom.'],
  ['SARANA', 'Bidang Sarana', 'Ust. Syamsuddin'], ['MEDIA', 'Bidang Media', 'Ust. Ilham Syah, S.Kom.']]
const TUGAS = { WUSTHA: ['kelas', 'mengajar'], SMA: ['kelas', 'mengajar'], TAHFIZH: ['halaqah'], KESANTRIAN: ['kamar', 'ekskul'] }

async function demo(mulai, selesai) {
  const peg = usePegawai(); if (!peg.daftar.length) await peg.muat()
  const hari = daftarTanggal(mulai, selesai).filter((d) => new Date(d + 'T00:00:00Z').getUTCDay() !== 5)
  const ph = hari.length
  const pegawai = peg.daftar.filter((p) => p.status_akun === 'aktif').map((p, i) => {
    const b = BIDANG[i % BIDANG.length]; const r = acak(p.id); const r2 = acak(p.id + 'x'); const mutu = 0.62 + (BIDANG.indexOf(b) % 4) * 0.08 + r * 0.12
    const wajib = ph * (r2 > 0.6 ? 2 : 1); const izin = Math.round(r2 * 2); const sakit = r > 0.8 ? 1 : 0; const cuti = r > 0.93 ? 2 : 0; const tk = Math.max(0, Math.round((1 - mutu) * 6 - 1))
    const hadirAll = wajib - izin - sakit - cuti - tk; const terlambat = Math.round(hadirAll * (1 - mutu) * 0.6); const dinas = r > 0.7 ? 1 : 0
    const jurW = ph - izin - sakit - cuti; const tugas = TUGAS[b[0]] || []
    const ss = tugas.some((t) => t !== 'mengajar') && i % 3 !== 2 ? ph * 2 : 0; const jp = tugas.includes('mengajar') ? Math.round(ph * 0.8) : 0
    return { id: p.id, nama: p.nama_lengkap, niy: p.niy, bidang: b[0], unit: b[1], jabatan: (p.jabatan_fungsional || []).join(', ') || p.jabatan_struktural || 'Staf',
      wajib, hadir: hadirAll - terlambat - dinas, terlambat, dinas, menunggu: 0, izin, sakit, cuti, tk,
      jur_wajib: jurW, jur_isi: Math.round(jurW * Math.min(1, mutu + 0.05)), butir: jurW * 3, butir_isi: Math.round(jurW * 3 * Math.min(1, mutu)),
      ss, ss_isi: Math.round(ss * Math.min(1, mutu + 0.1)), ss_telat: Math.round(ss * 0.05), jp, jp_isi: Math.round(jp * Math.min(1, mutu + 0.08)), jp_tidak: jp ? 1 : 0 }
  })
  const kelompok = []
  BIDANG.forEach(([kode], bi) => (TUGAS[kode] || []).filter((t) => t !== 'mengajar').forEach((j, ji) => {
    for (let g = 1; g <= 3; g++) { const ss = ph * (j === 'ekskul' ? 0.3 : j === 'kamar' ? 2 : 1); const q = 0.7 + acak(kode + j + g) * 0.3
      kelompok.push({ id: `${kode}${j}${g}`, jenis: j, nama: `${{ kelas: kode === 'SMA' ? 'Kelas X' : 'Kelas VII', halaqah: 'Halaqah', kamar: 'Kamar', ekskul: 'Ekskul' }[j]} ${String.fromCharCode(64 + g)}`, bidang: kode,
        ss: Math.round(ss), ss_isi: Math.round(ss * q), ss_telat: Math.round(ss * 0.04), pengasuh: pegawai[(bi * 3 + ji + g) % pegawai.length]?.nama }) }
  }))
  const tambah = (a, k) => a.reduce((s, x) => s + (Number(x[k]) || 0), 0)
  const bidang = BIDANG.map(([kode, nama, kepala], i) => {
    const p = pegawai.filter((x) => x.bidang === kode); const g = kelompok.filter((x) => x.bidang === kode)
    const o = { id: 'b' + i, kode, nama, kepala, pegawai: p.length }
    for (const k of ['wajib', 'hadir', 'terlambat', 'dinas', 'menunggu', 'izin', 'sakit', 'cuti', 'tk', 'jur_wajib', 'jur_isi', 'butir', 'butir_isi', 'jp', 'jp_isi', 'jp_tidak']) o[k] = tambah(p, k)
    o.ss = tambah(g, 'ss'); o.ss_isi = tambah(g, 'ss_isi'); o.ss_telat = tambah(g, 'ss_telat')
    return o
  })
  pegawai.forEach((p) => { p.bidang = bidang.find((b) => b.kode === p.bidang)?.id })
  kelompok.forEach((g) => { g.bidang = bidang.find((b) => b.kode === g.bidang)?.id })
  return { mulai, selesai, hari: daftarTanggal(mulai, selesai).length, dibuat: new Date().toISOString(), bidang, pegawai, kelompok }
}

export const useKinerja = defineStore('kinerja', {
  state: () => ({ data: null, memuat: false, galat: null, simpanan: {} }),
  actions: {
    /** Muat indikator untuk rentang tanggal (paling panjang 92 hari). segar = abaikan simpanan. */
    async muat(mulai, selesai, segar = false) {
      const kunci = `${mulai}|${selesai}`
      if (!segar && this.simpanan[kunci] && Date.now() - this.simpanan[kunci].t < 5 * 60000) { this.data = this.simpanan[kunci].d; return this.data }
      this.memuat = true; this.galat = null
      try {
        let mentah
        if (MODE_DEMO) mentah = await demo(mulai, selesai)
        else {
          const { data, error } = await supabase.rpc('kinerja_bidang', { p_mulai: mulai, p_selesai: selesai })
          if (error) throw new Error(pesanGalat(error))
          mentah = data
        }
        this.data = olah(mentah); this.simpanan[kunci] = { t: Date.now(), d: this.data }
        return this.data
      } catch (e) { this.galat = e.message; throw e } finally { this.memuat = false }
    },
  },
})
