// SIMKA PRO | src/stores/audit.js | v1.0 | Fase 3 – Tahap 1 Pengumuman, audit log, notifikasi HP | 04/10/2026
// Audit log 30 hari: pegawai melihat aktivitasnya sendiri; admin ber-izin audit_log dan superadmin melihat semua.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { AUDIT_DEMO } from '@/lib/demo'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'

export const useAudit = defineStore('audit', {
  state: () => ({ daftar: [], memuat: false }),
  actions: {
    async muat({ mulai, akhir, pegawai, tabel, batas = 300 } = {}) {
      this.memuat = true
      try {
        if (MODE_DEMO) {
          const s = useSesi(); const sendiri = !s.bolehAdmin('audit_log')
          this.daftar = AUDIT_DEMO().filter((r) => (!tabel || r.tabel === tabel) && (!pegawai || r.employee_id === pegawai) && (!sendiri || r.employee_id === s.pengguna?.id))
          return
        }
        const { data, error } = await supabase.rpc('audit_saya', { p_mulai: mulai || null, p_akhir: akhir || null, p_pegawai: pegawai || null, p_tabel: tabel || null, p_batas: batas })
        if (error) throw new Error(pesanGalat(error))
        this.daftar = data || []
      } finally { this.memuat = false }
    },
  },
})
