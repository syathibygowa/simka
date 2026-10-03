// SIMKA PRO | src/stores/notifikasi.js | v1.1 | Fase 1 – Akun dan hak akses | 03/10/2026
// Notifikasi per akun: dibaca/belum dibaca, langsung (Supabase Realtime),
// dan setiap notifikasi membuka halaman terkait (kolom "tautan").
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { notifikasiDemo } from '@/lib/demo'
import { useSesi } from './sesi'
import { useUI } from './ui'

let kanal = null
let pengatur = null

export const useNotifikasi = defineStore('notifikasi', {
  state: () => ({ daftar: [], memuat: false }),
  getters: {
    belumDibaca: (s) => s.daftar.filter((n) => !n.dibaca_pada).length,
    terbaru: (s) => s.daftar.slice(0, 6),
  },
  actions: {
    async muat() {
      const sesi = useSesi()
      if (!sesi.pengguna) return
      this.memuat = true
      if (MODE_DEMO) {
        this.daftar = notifikasiDemo(sesi.peran)
        this.memuat = false
        this.simulasiMasuk(sesi.peran)
        return
      }
      const { data } = await supabase.from('notifications').select('*')
        .eq('employee_id', sesi.pengguna.id).order('created_at', { ascending: false }).limit(100)
      this.daftar = data || []
      this.memuat = false
      this.langganan(sesi.pengguna.id)
    },

    langganan(employeeId) {
      kanal?.unsubscribe()
      kanal = supabase.channel(`notif-${employeeId}`)
        .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'notifications', filter: `employee_id=eq.${employeeId}` },
          ({ new: n }) => this.terima(n))
        .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'notifications', filter: `employee_id=eq.${employeeId}` },
          ({ new: n }) => { const i = this.daftar.findIndex((x) => x.id === n.id); if (i >= 0) this.daftar[i] = n })
        .subscribe()
    },

    terima(n) {
      if (this.daftar.some((x) => x.id === n.id)) return
      this.daftar.unshift(n)
      useUI().toast(n.judul, 'notifikasi', n.tautan ? { label: 'Buka', notif: n } : null)
    },

    /** Mode demo: satu notifikasi baru datang setelah 25 detik untuk menunjukkan pembaruan langsung. */
    simulasiMasuk(peran) {
      clearTimeout(pengatur)
      pengatur = setTimeout(() => {
        const n = peran === 'pegawai'
          ? { judul: 'Jadwal tugas Anda diperbarui', isi: 'Admin menambahkan tugas Wali kelas pada profil Anda.', tautan: '/profil', ikon: 'ListChecks', warna: 'ungu' }
          : { judul: 'Pendaftaran pegawai baru', isi: 'Ust. Ahmad Zaki mendaftar dan menunggu verifikasi akun.', tautan: '/verifikasi/menunggu', ikon: 'UserPlus', warna: 'biru' }
        this.terima({ id: `baru-${Date.now()}`, ...n, created_at: new Date().toISOString(), dibaca_pada: null })
      }, 25000)
    },

    async tandai(id) {
      const n = this.daftar.find((x) => x.id === id)
      if (!n || n.dibaca_pada) return
      n.dibaca_pada = new Date().toISOString()
      if (!MODE_DEMO) await supabase.rpc('tandai_dibaca', { p_id: id })
    },

    async tandaiBelum(id) {
      const n = this.daftar.find((x) => x.id === id)
      if (!n) return
      n.dibaca_pada = null
      if (!MODE_DEMO) await supabase.rpc('tandai_belum_dibaca', { p_id: id })
    },

    async tandaiSemua() {
      const t = new Date().toISOString()
      this.daftar.forEach((n) => { if (!n.dibaca_pada) n.dibaca_pada = t })
      if (!MODE_DEMO) await supabase.rpc('tandai_dibaca', { p_id: null })
    },

    async hapus(id) {
      this.daftar = this.daftar.filter((x) => x.id !== id)
      if (!MODE_DEMO) await supabase.from('notifications').delete().eq('id', id)
    },

    berhenti() { kanal?.unsubscribe(); kanal = null; clearTimeout(pengatur); this.$reset() },
  },
})
