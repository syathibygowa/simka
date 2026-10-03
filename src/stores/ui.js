// SIMKA PRO | src/stores/ui.js | v1.1 | Fase 1 – Pengaturan | 03/10/2026
// Pesan singkat (toast) dan status antarmuka bersama.
import { defineStore } from 'pinia'

let urut = 0
export const useUI = defineStore('ui', {
  state: () => ({ toasts: [], panelNotifikasi: false, dialog: { buka: false, judul: '', pesan: '', ya: 'Ya', bahaya: false, _res: null } }),
  actions: {
    toast(pesan, jenis = 'info', aksi = null) {
      const id = ++urut
      this.toasts.push({ id, pesan, jenis, aksi })
      setTimeout(() => this.tutupToast(id), aksi ? 6000 : 3500)
    },
    tutupToast(id) { this.toasts = this.toasts.filter((t) => t.id !== id) },
    /** Konfirmasi aksi penting: await ui.konfirmasi({ judul, pesan, ya, bahaya }) → true/false */
    konfirmasi({ judul = 'Konfirmasi', pesan = '', ya = 'Ya, lanjutkan', bahaya = false } = {}) {
      return new Promise((res) => { this.dialog = { buka: true, judul, pesan, ya, bahaya, _res: res } })
    },
    jawab(v) { this.dialog._res?.(v); this.dialog = { ...this.dialog, buka: false, _res: null } },
  },
})
