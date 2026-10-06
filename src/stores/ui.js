// SIMKA PRO | src/stores/ui.js | v1.3 | Fase 7 – Tahap 1 Sidebar berkelompok buka-tutup | 06/10/2026
// Pesan singkat (toast) dan status antarmuka bersama.
import { defineStore } from 'pinia'

let urut = 0
export const useUI = defineStore('ui', {
  state: () => ({ grupTutup: (() => { try { const v = localStorage.getItem('simka.sidebar.grup'); return v ? JSON.parse(v) : null } catch { return null } })(), sidebarCiut: (() => { try { return localStorage.getItem('simka.sidebar') === 'ciut' } catch { return false } })(), toasts: [], panelNotifikasi: false, dialog: { buka: false, judul: '', pesan: '', ya: 'Ya', bahaya: false, _res: null } }),
  actions: {
    toast(pesan, jenis = 'info', aksi = null) {
      const id = ++urut
      this.toasts.push({ id, pesan, jenis, aksi })
      setTimeout(() => this.tutupToast(id), aksi ? 6000 : 3500)
    },
    /** Sidebar desktop: ciut (hanya ikon, terbuka saat disentuh kursor) atau tetap terbuka. */
    aturSidebar(ciut) {
      this.sidebarCiut = ciut
      try { localStorage.setItem('simka.sidebar', ciut ? 'ciut' : 'buka') } catch { /* abaikan */ }
    },
    /** Kelompok menu sidebar yang ditutup (dapat dibuka-tutup; tersimpan di perangkat). */
    /** grupTutup null = belum pernah diatur: bawaan semua kelompok tertutup kecuali Utama. */
    alihGrup(g, semua = []) {
      if (this.grupTutup === null) this.grupTutup = semua.filter((x) => x !== 'Utama')
      this.grupTutup = this.grupTutup.includes(g) ? this.grupTutup.filter((x) => x !== g) : [...this.grupTutup, g]
      try { localStorage.setItem('simka.sidebar.grup', JSON.stringify(this.grupTutup)) } catch { /* abaikan */ }
    },
    aturSemuaGrup(daftar) {
      this.grupTutup = [...daftar]
      try { localStorage.setItem('simka.sidebar.grup', JSON.stringify(this.grupTutup)) } catch { /* abaikan */ }
    },
    tutupToast(id) { this.toasts = this.toasts.filter((t) => t.id !== id) },
    /** Konfirmasi aksi penting: await ui.konfirmasi({ judul, pesan, ya, bahaya }) → true/false */
    konfirmasi({ judul = 'Konfirmasi', pesan = '', ya = 'Ya, lanjutkan', bahaya = false } = {}) {
      return new Promise((res) => { this.dialog = { buka: true, judul, pesan, ya, bahaya, _res: res } })
    },
    jawab(v) { this.dialog._res?.(v); this.dialog = { ...this.dialog, buka: false, _res: null } },
  },
})
