// Statistik beranda yang diperbarui langsung: Supabase Realtime memicu muat ulang
// fungsi statistik_beranda() setiap kali data pegawai atau notifikasi berubah,
// ditambah penyegaran berkala sebagai cadangan.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { statistikDemo } from '@/lib/demo'

let kanal = null, berkala = null, tunda = null

export const useStatistik = defineStore('statistik', {
  state: () => ({ data: null, diperbarui: null, berubah: {} }),
  actions: {
    async muat() {
      let baru
      if (MODE_DEMO) {
        baru = this.data ? { ...this.data } : statistikDemo()
      } else {
        const { data, error } = await supabase.rpc('statistik_beranda')
        if (error) return
        baru = data
      }
      this.tandaiPerubahan(baru)
      this.data = baru
      this.diperbarui = new Date()
    },

    tandaiPerubahan(baru) {
      const b = {}
      if (this.data) for (const k in baru) if (typeof baru[k] === 'number' && baru[k] !== this.data[k]) b[k] = baru[k] > this.data[k] ? 'naik' : 'turun'
      this.berubah = b
      if (Object.keys(b).length) setTimeout(() => { this.berubah = {} }, 2500)
    },

    mulai() {
      this.muat()
      if (MODE_DEMO) {
        // Simulasi perubahan agar tampilan "langsung" dapat dilihat
        berkala = setInterval(() => {
          const d = { ...this.data }
          const k = ['akun_aktif', 'menunggu_verifikasi', 'audit_hari_ini', 'berkas_antri'][Math.floor(Math.random() * 4)]
          d[k] = Math.max(0, d[k] + (Math.random() > 0.4 ? 1 : -1))
          if (k === 'audit_hari_ini') d[k] = this.data[k] + 1
          this.tandaiPerubahan(d); this.data = d; this.diperbarui = new Date()
        }, 7000)
        return
      }
      const segarkan = () => { clearTimeout(tunda); tunda = setTimeout(() => this.muat(), 800) }
      kanal = supabase.channel('statistik-beranda')
        .on('postgres_changes', { event: '*', schema: 'public', table: 'employees' }, segarkan)
        .subscribe()
      berkala = setInterval(() => this.muat(), 60000)
    },

    berhenti() { kanal?.unsubscribe(); kanal = null; clearInterval(berkala); clearTimeout(tunda) },
  },
})
