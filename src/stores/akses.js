// SIMKA PRO | src/stores/akses.js | v1.1 | Perbaikan 13.9.0: katalog fitur berketerangan (menu, arti tingkat), fitur lama dipisah | 16/10/2026
// Hak akses fitur tiga lapis (Bagian 4): jabatan → bidang → individu.
// tingkat: 1 lihat, 2 input/ubah, 3 kelola. mode "cabut" pada tingkat t berarti akses dibatasi menjadi t − 1.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { FITUR_DEMO, ORGANISASI_DEMO } from '@/lib/demo'
import { KATALOG_FITUR } from '@/lib/hakAkses'
import { pesanGalat } from './lembaga'

export const TINGKAT = { 0: 'Tidak ada', 1: 'Lihat', 2: 'Input/ubah', 3: 'Kelola' }
const URUT_KELOMPOK = ['Santri', 'Layanan', 'Administrasi', 'Kepegawaian', 'Sistem']
const kunci = (g) => `${g.sasaran}:${g.sasaran_id}:${g.feature_kode}`

export const useAkses = defineStore('akses', {
  state: () => ({ fitur: [], fiturLama: [], grants: {}, dimuat: false }),
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
      if (MODE_DEMO) {
        if (!this.dimuat) {
          this.fitur = FITUR_DEMO
          // Contoh aturan bawaan per jabatan (mengikuti isi awal migrasi 0400 dan fitur yang berlaku)
          const org = ORGANISASI_DEMO()
          const id = (j, kode) => org[j].find((x) => x.kode === kode)?.id
          const bawaan = [['fungsional', 'WALI_KELAS', 'absensi_kelas', 2], ['fungsional', 'MUHAFFIZH', 'tahfizh', 2], ['fungsional', 'MUSYRIF', 'absensi_asrama', 2],
            ['fungsional', 'PEMBINA_EKSKUL', 'absensi_ekskul', 2], ['fungsional', 'GURU', 'jadwal_mengajar', 2], ['fungsional', 'GURU', 'nilai', 2], ['fungsional', 'MUHAFFIZH', 'nilai', 2],
            ['fungsional', 'MEDIS', 'klinik', 2], ['fungsional', 'SECURITY', 'gerbang', 2], ['struktural', 'DIREKTUR', 'pantauan', 1], ['struktural', 'WAKIL_DIREKTUR', 'pantauan', 1],
            ['struktural', 'KEPALA_BIDANG', 'pantauan', 1], ['struktural', 'KEPALA_BIDANG', 'data_santri', 1], ['struktural', 'WAKIL_KEPALA_BIDANG', 'pantauan', 1], ['struktural', 'TATA_USAHA', 'tata_usaha', 3]]
          for (const [sasaran, kode, f, t] of bawaan) { const sid = id(sasaran, kode); if (sid) this.grants[`${sasaran}:${sid}:${f}`] = { sasaran, sasaran_id: sid, feature_kode: f, tingkat: t, mode: 'tambah' } }
        }
        this.dimuat = true; return
      }
      const [f, g] = await Promise.all([
        supabase.from('features').select('*').order('kelompok').order('urutan'),
        supabase.from('feature_grants').select('*'),
      ])
      if (f.error || g.error) throw new Error(pesanGalat(f.error || g.error))
      // Lengkapi keterangan dari katalog bila kolom baru belum ada; fitur lama (dipakai = false) dipisah
      const kat = Object.fromEntries(KATALOG_FITUR.map((x) => [x.kode, x]))
      const semua = f.data.map((x) => ({ ...(kat[x.kode] || {}), ...x, menu: x.menu ?? kat[x.kode]?.menu, arti: x.arti && Object.keys(x.arti).length ? x.arti : kat[x.kode]?.arti || {},
        dipakai: x.dipakai ?? !!kat[x.kode] }))
      this.fitur = semua.filter((x) => x.dipakai).sort((a, b) => URUT_KELOMPOK.indexOf(a.kelompok) - URUT_KELOMPOK.indexOf(b.kelompok) || a.urutan - b.urutan)
      this.fiturLama = semua.filter((x) => !x.dipakai)
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
