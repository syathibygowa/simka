// SIMKA PRO | src/stores/audit.js | v2.0 | Perbaikan 13.6.0: audit log khusus superadmin, ringkasan per kategori | 15/10/2026
// Audit log 30 hari, hanya untuk superadmin. Ringkasan jumlah aktivitas per jenis data dan aksi untuk kartu statistik.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { AUDIT_DEMO } from '@/lib/demo'
import { pesanGalat } from './lembaga'

const tglWITA = (iso) => new Date(new Date(iso).getTime() + 8 * 3600000).toISOString().slice(0, 10)

export const useAudit = defineStore('audit', {
  state: () => ({ daftar: [], ringkasan: [], memuat: false }),
  actions: {
    /** tabel: daftar jenis data (kosong = semua). */
    async muat({ mulai, akhir, pegawai, tabel = [], batas = 1000 } = {}) {
      this.memuat = true
      try {
        if (MODE_DEMO) {
          const semua = AUDIT_DEMO().filter((r) => (!pegawai || r.employee_id === pegawai)
            && (!mulai || tglWITA(r.created_at) >= mulai) && (!akhir || tglWITA(r.created_at) <= akhir))
          const peta = {}
          for (const r of semua) { const k = `${r.tabel}|${r.aksi}`; peta[k] = (peta[k] || 0) + 1 }
          this.ringkasan = Object.entries(peta).map(([k, n]) => ({ tabel: k.split('|')[0], aksi: k.split('|')[1], jumlah: n }))
          this.daftar = semua.filter((r) => !tabel.length || tabel.includes(r.tabel))
          return
        }
        const [d, r] = await Promise.all([
          supabase.rpc('audit_daftar', { p_mulai: mulai || null, p_akhir: akhir || null, p_pegawai: pegawai || null, p_tabel: tabel.length ? tabel : null, p_batas: batas }),
          supabase.rpc('ringkasan_audit', { p_mulai: mulai || null, p_akhir: akhir || null, p_pegawai: pegawai || null }),
        ])
        if (d.error) throw new Error(pesanGalat(d.error))
        if (r.error) throw new Error(pesanGalat(r.error))
        this.daftar = d.data || []; this.ringkasan = r.data || []
      } finally { this.memuat = false }
    },
  },
})
