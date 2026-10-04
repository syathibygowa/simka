// SIMKA PRO | src/stores/templatWA.js | v1.1 | Fase 4 – Tahap 1 Data santri | 04/10/2026
// Template pesan WhatsApp (dikelola superadmin).
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { BAWAAN_WA, setelTemplatWA } from '@/lib/wa'

const NAMA = { aktivasi: 'Akun diaktifkan', ditolak: 'Pendaftaran ditolak', sandi_sementara: 'Kata sandi sementara', undangan_agenda: 'Undangan/pengingat agenda', umum: 'Pesan umum kepada pegawai', wali_santri: 'Pesan ke orang tua/wali santri' }
export const useTemplatWA = defineStore('templatWA', {
  state: () => ({ daftar: [], memuat: false }),
  actions: {
    async muat() {
      this.memuat = true
      try {
        if (MODE_DEMO) { if (!this.daftar.length) this.daftar = Object.entries(BAWAAN_WA).map(([kode, isi]) => ({ kode, nama: NAMA[kode], isi, aktif: true, variabel: [...new Set(isi.match(/\{(\w+)\}/g).map((x) => x.slice(1, -1)))] })); return }
        const { data, error } = await supabase.from('wa_templates').select('*').order('kode')
        if (error) throw new Error(pesanGalat(error))
        this.daftar = data || []
      } finally { this.memuat = false }
    },
    async simpan(t) {
      const isi = { kode: t.kode, nama: t.nama.trim(), isi: t.isi, variabel: t.variabel || [], keterangan: t.keterangan || null, aktif: t.aktif !== false }
      if (!MODE_DEMO) {
        const { error } = t._baru ? await supabase.from('wa_templates').insert(isi) : await supabase.from('wa_templates').update(isi).eq('kode', t.kode)
        if (error) throw new Error(pesanGalat(error))
      }
      const i = this.daftar.findIndex((x) => x.kode === t.kode); if (i >= 0) this.daftar[i] = isi; else this.daftar.push(isi)
      setelTemplatWA(t.kode, isi.isi)
    },
    async hapus(kode) {
      if (!MODE_DEMO) { const { error } = await supabase.from('wa_templates').delete().eq('kode', kode); if (error) throw new Error(pesanGalat(error)) }
      this.daftar = this.daftar.filter((x) => x.kode !== kode)
    },
  },
})
