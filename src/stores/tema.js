// Tema Terang / Gelap / Ikuti sistem. Pilihan disimpan di peramban dan, bila
// tersambung server, di kolom employees.tema agar ikut ke perangkat lain.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'

const mq = typeof window !== 'undefined' ? window.matchMedia('(prefers-color-scheme: dark)') : null
const baca = () => { try { return localStorage.getItem('simka.tema') || 'sistem' } catch { return 'sistem' } }

export const useTema = defineStore('tema', {
  state: () => ({ pilihan: baca(), sistemGelap: mq?.matches ?? false }),
  getters: { gelap: (s) => s.pilihan === 'gelap' || (s.pilihan === 'sistem' && s.sistemGelap) },
  actions: {
    pasang() {
      mq?.addEventListener('change', (e) => { this.sistemGelap = e.matches; this.terapkan() })
      this.terapkan()
    },
    terapkan() {
      document.documentElement.classList.toggle('dark', this.gelap)
      document.querySelector('meta[name="theme-color"]')?.setAttribute('content', this.gelap ? '#211719' : '#C7332F')
    },
    async atur(p, employeeId) {
      this.pilihan = p
      try { localStorage.setItem('simka.tema', p) } catch { /* abaikan */ }
      this.terapkan()
      if (!MODE_DEMO && employeeId) await supabase.from('employees').update({ tema: p }).eq('id', employeeId)
    },
  },
})
