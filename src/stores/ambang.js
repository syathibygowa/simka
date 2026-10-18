// SIMKA PRO | src/stores/ambang.js | v1.0 | 14.3.0: ambang warna kehadiran (layar, cetak, unduhan Excel) | 17/10/2026
// Ambang kehadiran: baris dengan persentase kehadiran DI BAWAH batas diwarnai merah. Batas pegawai dan santri terpisah
// (bawaan 80%). Pilihan: aktif (layar), cetak (warna ikut tercetak), unduh (warna ikut di Excel). Dimuat sekali per sesi.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'

const BAWAAN = { aktif: true, batas_pegawai: 80, batas_santri: 80, cetak: true, unduh: true }
let demo = { ...BAWAAN }

export const useAmbang = defineStore('ambang', {
  state: () => ({ set: { ...BAWAAN }, dimuat: false }),
  getters: {
    /** Batas untuk 'pegawai' atau 'santri'. */
    batas: (s) => (jenis = 'santri') => Number(jenis === 'pegawai' ? s.set.batas_pegawai : s.set.batas_santri) || 80,
    /** true bila persentase p (0–100) di bawah batas dan pewarnaan aktif. */
    bawah: (s) => (p, jenis = 'santri') => s.set.aktif && p != null && p !== '' && Number(p) < (Number(jenis === 'pegawai' ? s.set.batas_pegawai : s.set.batas_santri) || 80),
    /** Kelas baris/kartu di layar. */
    kelas: (s) => (p, jenis = 'santri') => (s.set.aktif && p != null && p !== '' && Number(p) < (Number(jenis === 'pegawai' ? s.set.batas_pegawai : s.set.batas_santri) || 80)
      ? 'baris-ambang' : ''),
    /** Kelas baris tabel di dokumen cetak (hanya bila warna cetak aktif). */
    kelasCetak: (s) => (p, jenis = 'santri') => (s.set.aktif && s.set.cetak && p != null && p !== '' && Number(p) < (Number(jenis === 'pegawai' ? s.set.batas_pegawai : s.set.batas_santri) || 80)
      ? 'cetak-ambang' : ''),
  },
  actions: {
    async muat(paksa = false) {
      if (this.dimuat && !paksa) return this.set
      if (MODE_DEMO) { this.set = { ...demo }; this.dimuat = true; return this.set }
      const { data, error } = await supabase.rpc('ambang_kehadiran')
      if (!error && data) this.set = { ...BAWAAN, ...data }
      this.dimuat = true; return this.set
    },
    async simpan(p) {
      if (MODE_DEMO) { demo = { ...demo, ...p }; this.set = { ...demo }; return this.set }
      const { data, error } = await supabase.rpc('simpan_ambang_kehadiran', { p })
      if (error) throw new Error(error.message)
      this.set = { ...BAWAAN, ...data }; return this.set
    },
  },
})

/**
 * Unduh buku Excel; baris di bawah ambang diwarnai merah muda bila pengaturan "unduh" aktif.
 * baris: daftar { r (indeks baris 0-based di lembar), persen, jenis } untuk lembar pertama (atau { lembar, r, persen }).
 */
export async function unduhExcelAmbang(wb, namaBerkas, baris = []) {
  const amb = useAmbang(); await amb.muat()
  const tandai = amb.set.aktif && amb.set.unduh ? baris.filter((b) => amb.bawah(b.persen, b.jenis || 'santri')) : []
  const XS = await import('xlsx-js-style')
  const X = XS.default || XS
  for (const b of tandai) {
    const ws = wb.Sheets[b.lembar || wb.SheetNames[0]]; if (!ws || !ws['!ref']) continue
    const r = X.utils.decode_range(ws['!ref'])
    for (let c = r.s.c; c <= r.e.c; c++) {
      const a = X.utils.encode_cell({ r: b.r, c }); if (!ws[a]) ws[a] = { t: 's', v: '' }
      ws[a].s = { fill: { patternType: 'solid', fgColor: { rgb: 'FDE2E1' } }, font: { color: { rgb: '9B1C1C' } } }
    }
  }
  X.writeFile(wb, namaBerkas)
}
