// SIMKA PRO | src/stores/akses.js | v1.0 | Fase 1 – Akun dan hak akses | 03/10/2026
// Hak akses fitur tiga lapis (Bagian 4): jabatan → bidang → individu.
// tingkat: 1 lihat, 2 input/ubah, 3 kelola. mode "cabut" pada tingkat t berarti akses dibatasi menjadi t − 1.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { FITUR_DEMO } from '@/lib/demo'
import { pesanGalat } from './lembaga'

export const TINGKAT = { 0: 'Tidak ada', 1: 'Lihat', 2: 'Input/ubah', 3: 'Kelola' }
const kunci = (g) => `${g.sasaran}:${g.sasaran_id}:${g.feature_kode}`

export const useAkses = defineStore('akses', {
  state: () => ({ fitur: [], grants: {}, dimuat: false }),
  getters: {
    kelompok: (s) => {
      const k = {}; for (const f of s.fitur) (k[f.kelompok] ||= []).push(f)
      return Object.entries(k)
    },
    /** Aturan untuk satu sasaran: { feature_kode: grant } */
    aturan: (s) => (sasaran, id) => {
      const o = {}; for (const g of Object.values(s.grants)) if (g.sasaran === sasaran && g.sasaran_id === id) o[g.feature_kode] = g
      return o
    },
    /** Jumlah aturan per sasaran (untuk penanda di daftar) */
    jumlahAturan: (s) => (sasaran, id) => Object.values(s.grants).filter((g) => g.sasaran === sasaran && g.sasaran_id === id).length,
  },
  actions: {
    async muat() {
      if (MODE_DEMO) { if (!this.dimuat) this.fitur = FITUR_DEMO; this.dimuat = true; return }
      const [f, g] = await Promise.all([
        supabase.from('features').select('*').order('kelompok').order('urutan'),
        supabase.from('feature_grants').select('*'),
      ])
      if (f.error || g.error) throw new Error(pesanGalat(f.error || g.error))
      this.fitur = f.data
      this.grants = Object.fromEntries(g.data.map((x) => [kunci(x), x]))
      this.dimuat = true
    },

    /** Atur satu aturan. tingkat 0 (atau null) menghapus aturan; mode 'tambah' atau 'cabut'. */
    async atur(sasaran, sasaran_id, feature_kode, tingkat, mode = 'tambah') {
      const k = kunci({ sasaran, sasaran_id, feature_kode })
      if (!tingkat) {
        if (!MODE_DEMO) {
          const { error } = await supabase.from('feature_grants').delete().match({ sasaran, sasaran_id, feature_kode })
          if (error) throw new Error(pesanGalat(error))
        }
        delete this.grants[k]; return
      }
      const baris = { sasaran, sasaran_id, feature_kode, tingkat, mode }
      if (MODE_DEMO) { this.grants[k] = baris; return }
      const { data, error } = await supabase.from('feature_grants').upsert(baris, { onConflict: 'feature_kode,sasaran,sasaran_id' }).select().single()
      if (error) throw new Error(pesanGalat(error))
      this.grants[k] = data
    },

    /** Akses efektif seorang pegawai (gabungan tiga lapis) dari server. */
    async rincian(employeeId) {
      if (MODE_DEMO) {
        return this.fitur.map((f) => {
          const i = this.grants[`individu:${employeeId}:${f.kode}`]
          const dj = ['presensi', 'pengajuan', 'jurnal_harian'].includes(f.kode) ? 2 : ['berkas_pegawai', 'kartu_pegawai'].includes(f.kode) ? 1 : 0
          const di = i ? (i.mode === 'cabut' ? -i.tingkat : i.tingkat) : null
          const ef = i ? (i.mode === 'cabut' ? Math.min(dj, i.tingkat - 1) : Math.max(dj, i.tingkat)) : dj
          return { kode: f.kode, nama: f.nama, kelompok: f.kelompok, dari_jabatan: dj, dari_bidang: null, dari_individu: di, efektif: ef }
        })
      }
      const { data, error } = await supabase.rpc('rincian_akses', { p_employee: employeeId })
      if (error) throw new Error(pesanGalat(error))
      return data
    },
  },
})
