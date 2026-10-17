// SIMKA PRO | src/stores/akses.js | v2.0 | Perbaikan 14.0.0: lapis "Semua pegawai", tingkat Tidak ada per jabatan, fitur terkunci dan sensitif | 17/10/2026
// Hak akses fitur empat lapis: Semua pegawai (bawaan) → jabatan → bidang → individu.
// tingkat: 0 tidak ada, 1 lihat, 2 input/ubah, 3 kelola. mode "cabut" pada tingkat t berarti akses dibatasi menjadi t − 1.
// Jabatan tanpa aturan sendiri mengikuti bawaan Semua pegawai; aturan jabatan boleh bernilai 0 (Tidak ada) untuk menimpanya.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { FITUR_DEMO, ORGANISASI_DEMO } from '@/lib/demo'
import { KATALOG_FITUR, URUT_KELOMPOK, SEMUA_ID } from '@/lib/hakAkses'
import { pesanGalat } from './lembaga'

export const TINGKAT = { 0: 'Tidak ada', 1: 'Lihat', 2: 'Input/ubah', 3: 'Kelola' }
export { SEMUA_ID }
const kunci = (g) => `${g.sasaran}:${g.sasaran_id}:${g.feature_kode}`
const urut = (a, b) => URUT_KELOMPOK.indexOf(a.kelompok) - URUT_KELOMPOK.indexOf(b.kelompok) || a.urutan - b.urutan

export const useAkses = defineStore('akses', {
  state: () => ({ fitur: [], fiturLama: [], grants: {}, dimuat: false }),
  getters: {
    /** Semua fitur katalog (termasuk yang terkunci) dikelompokkan sesuai grup menu */
    kelompok: (s) => {
      const k = {}; for (const f of s.fitur) (k[f.kelompok] ||= []).push(f)
      return Object.entries(k)
    },
    /** Fitur yang dapat diatur di matriks (tidak terkunci) */
    fiturAtur: (s) => s.fitur.filter((f) => !f.kunci),
    /** Aturan untuk satu sasaran: { feature_kode: grant } */
    aturan: (s) => (sasaran, id) => {
      const o = {}; for (const g of Object.values(s.grants)) if (g.sasaran === sasaran && g.sasaran_id === id) o[g.feature_kode] = g
      return o
    },
    /** Tingkat bawaan Semua pegawai untuk satu fitur */
    bawaan: (s) => (kode) => Number(s.grants[`semua:${SEMUA_ID}:${kode}`]?.tingkat ?? 0),
    /** Jumlah aturan sendiri per sasaran (untuk penanda di daftar) */
    jumlahAturan: (s) => (sasaran, id) => Object.values(s.grants).filter((g) => g.sasaran === sasaran && g.sasaran_id === id).length,
  },
  actions: {
    async muat() {
      if (MODE_DEMO) {
        if (!this.dimuat) {
          this.fitur = [...FITUR_DEMO].sort(urut)
          // Contoh aturan bawaan (mengikuti migrasi 0400 dan 14.0.0)
          for (const f of KATALOG_FITUR) if (f.bawaan?.semua) this.grants[`semua:${SEMUA_ID}:${f.kode}`] = { sasaran: 'semua', sasaran_id: SEMUA_ID, feature_kode: f.kode, tingkat: f.bawaan.semua, mode: 'tambah' }
          const org = ORGANISASI_DEMO()
          const id = (j, kode) => org[j].find((x) => x.kode === kode)?.id
          const bawaan = [['fungsional', 'WALI_KELAS', 'absensi_kelas', 2], ['fungsional', 'MUHAFFIZH', 'tahfizh', 2], ['fungsional', 'MUSYRIF', 'absensi_asrama', 2],
            ['fungsional', 'PEMBINA_EKSKUL', 'absensi_ekskul', 2], ['fungsional', 'GURU', 'jadwal_mengajar', 2], ['fungsional', 'GURU', 'nilai', 2], ['fungsional', 'MUHAFFIZH', 'nilai', 2],
            ['fungsional', 'MEDIS', 'klinik', 2], ['fungsional', 'SECURITY', 'gerbang', 2], ['struktural', 'DIREKTUR', 'pantauan', 1], ['struktural', 'WAKIL_DIREKTUR', 'pantauan', 1],
            ['struktural', 'KEPALA_BIDANG', 'pantauan', 1], ['struktural', 'KEPALA_BIDANG', 'data_santri', 1], ['struktural', 'KEPALA_BIDANG', 'statistik_santri', 1],
            ['struktural', 'WAKIL_KEPALA_BIDANG', 'pantauan', 1], ['struktural', 'TATA_USAHA', 'pantauan', 1], ['struktural', 'TATA_USAHA', 'tata_usaha', 3]]
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
      const semua = f.data.map((x) => ({ ...(kat[x.kode] || {}), ...x, menu: x.menu ?? kat[x.kode]?.menu,
        arti: x.arti && Object.keys(x.arti).length ? x.arti : kat[x.kode]?.arti || {},
        kunci: x.kunci ?? kat[x.kode]?.kunci ?? null, sensitif: x.sensitif ?? !!kat[x.kode]?.sensitif, dipakai: x.dipakai ?? !!kat[x.kode] }))
      this.fitur = semua.filter((x) => x.dipakai).sort(urut)
      this.fiturLama = semua.filter((x) => !x.dipakai)
      this.grants = Object.fromEntries(g.data.map((x) => [kunci(x), x]))
      this.dimuat = true
    },

    /** Atur satu aturan. tingkat null (atau '' untuk bidang/individu) menghapus aturan sehingga mengikuti lapis di bawahnya.
        Untuk jabatan, tingkat 0 disimpan sebagai "Tidak ada" yang menimpa bawaan Semua pegawai.
        Untuk Semua pegawai, tingkat 0 berarti tanpa bawaan (aturan dihapus). */
    async atur(sasaran, sasaran_id, feature_kode, tingkat, mode = 'tambah') {
      const k = kunci({ sasaran, sasaran_id, feature_kode })
      const hapus = tingkat == null || tingkat === '' || (tingkat === 0 && !['fungsional', 'struktural'].includes(sasaran))
      if (hapus) {
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

    /** Akses efektif seorang pegawai (gabungan semua lapis) dari server. */
    async rincian(employeeId) {
      if (MODE_DEMO) {
        return this.fiturAtur.map((f) => {
          const i = this.grants[`individu:${employeeId}:${f.kode}`]
          const dj = this.bawaan(f.kode)
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
