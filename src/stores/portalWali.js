// SIMKA PRO | src/stores/portalWali.js | v1.0 | Fase 9 – Tahap 13.0.0 Fondasi Portal Wali | 15/10/2026
// Portal Wali: sesi per anak di perangkat (beberapa anak dapat ditambahkan), masuk/keluar, dan data portal.
// Semua data lewat fungsi SQL portal_masuk / portal_keluar / portal_data (tanpa akun pegawai).
// Kunci sesi tidak sah/dicabut → anak itu dihapus dari perangkat dan wali diminta masuk kembali.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { bacaAnak, simpanAnak, bacaAktif, simpanAktif, namaPerangkat, PENGATURAN_BAWAAN } from '@/lib/portalWali'
import { masukDemo, dataDemo } from '@/lib/demoPortalWali'
import { pesanGalat } from './lembaga'

export const usePortalWali = defineStore('portalWali', {
  state: () => ({
    anak: bacaAnak(),
    aktifNis: bacaAktif(),
    data: {},              // { [nis]: { beranda: {...}, ... } }
    memuat: false,
    galat: '',
    tutup: '',             // pesan bila portal ditutup superadmin
    pesanKeluar: '',       // pesan setelah sesi berakhir/dicabut
  }),
  getters: {
    aktif: (s) => s.anak.find((a) => a.nis === s.aktifNis) || s.anak[0] || null,
    beranda: (s) => s.data[(s.anak.find((a) => a.nis === s.aktifNis) || s.anak[0])?.nis]?.beranda || null,
    butir: (s) => s.data[(s.anak.find((a) => a.nis === s.aktifNis) || s.anak[0])?.nis]?.beranda?.butir || PENGATURAN_BAWAAN.butir,
  },
  actions: {
    simpan() { simpanAnak(this.anak); simpanAktif(this.aktif?.nis || '') },

    /** Masuk dengan NIS/NISN + tanggal lahir + 6 digit HP. Anak yang sama menggantikan sesi lamanya. */
    async masuk(identitas, tanggalLahir, hp) {
      let h
      if (MODE_DEMO) h = masukDemo(identitas, tanggalLahir, hp)
      else {
        const { data, error } = await supabase.rpc('portal_masuk', {
          p_identitas: identitas, p_tanggal_lahir: tanggalLahir || null, p_hp: hp, p_perangkat: namaPerangkat(),
        })
        if (error) throw new Error(pesanGalat(error))
        h = data
      }
      if (!h?.ok) { const e = new Error(h?.galat || 'Gagal masuk.'); e.kode = h?.kode; throw e }
      const baru = { token: h.token, ...h.santri, hubungan: h.hubungan, kedaluwarsa: h.kedaluwarsa }
      const lama = this.anak.find((a) => a.nis === baru.nis)
      if (lama && lama.token !== baru.token) this.keluarServer(lama.token)
      this.anak = [...this.anak.filter((a) => a.nis !== baru.nis), baru]
      this.aktifNis = baru.nis; this.tutup = ''; this.pesanKeluar = ''
      this.simpan()
      return baru
    },

    pilih(nis) { this.aktifNis = nis; this.simpan() },

    async keluarServer(token) {
      if (MODE_DEMO || !token) return
      try { await supabase.rpc('portal_keluar', { p_token: token }) } catch { /* sesi tetap dihapus dari perangkat */ }
    },

    /** Keluar untuk satu anak (bawaan: anak yang sedang dibuka). */
    async keluar(nis = this.aktif?.nis) {
      const a = this.anak.find((x) => x.nis === nis)
      if (!a) return
      await this.keluarServer(a.token)
      this.hapusLokal(nis)
    },
    async keluarSemua() {
      await Promise.all(this.anak.map((a) => this.keluarServer(a.token)))
      this.anak = []; this.data = {}; this.aktifNis = ''; this.simpan()
    },
    hapusLokal(nis) {
      this.anak = this.anak.filter((x) => x.nis !== nis)
      delete this.data[nis]
      if (this.aktifNis === nis) this.aktifNis = this.anak[0]?.nis || ''
      this.simpan()
    },

    /** Ambil satu bagian data portal untuk anak aktif. */
    async ambil(bagian, p = {}) {
      const a = this.aktif
      if (!a) return null
      let h
      if (MODE_DEMO) h = dataDemo(a.nis, bagian, p)
      else {
        const { data, error } = await supabase.rpc('portal_data', { p_token: a.token, p_bagian: bagian, p })
        if (error) throw new Error(pesanGalat(error))
        h = data
      }
      if (h?.sesi_berakhir) {
        this.pesanKeluar = `Sesi untuk ${a.nama} sudah berakhir atau dicabut pengelola. Silakan masuk kembali.`
        this.hapusLokal(a.nis)
        return null
      }
      if (h?.tutup) { this.tutup = h.pesan || PENGATURAN_BAWAAN.pesan_tutup; return null }
      this.tutup = ''
      if (h?.galat) throw new Error(h.galat)
      this.data[a.nis] = { ...(this.data[a.nis] || {}), [bagian]: h }
      // Perbarui ringkasan anak di perangkat (kelas dapat berubah saat naik kelas)
      if (bagian === 'beranda' && h?.santri) {
        Object.assign(a, { nama: h.santri.nama, panggilan: h.santri.panggilan, kelas: h.santri.kelas, jk: h.santri.jk })
        this.simpan()
      }
      return h
    },

    async muatBeranda() {
      this.memuat = true; this.galat = ''
      try { await this.ambil('beranda') }
      catch (e) { this.galat = e.message }
      finally { this.memuat = false }
    },
  },
})
