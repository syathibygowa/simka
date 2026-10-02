// Pesan singkat (toast) dan status antarmuka bersama.
import { defineStore } from 'pinia'

let urut = 0
export const useUI = defineStore('ui', {
  state: () => ({ toasts: [], panelNotifikasi: false }),
  actions: {
    toast(pesan, jenis = 'info', aksi = null) {
      const id = ++urut
      this.toasts.push({ id, pesan, jenis, aksi })
      setTimeout(() => this.tutupToast(id), aksi ? 6000 : 3500)
    },
    tutupToast(id) { this.toasts = this.toasts.filter((t) => t.id !== id) },
  },
})
