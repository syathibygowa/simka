// SIMKA PRO | src/stores/sesi.js | v1.1 | Tahap 6 | 03/10/2026
// Sesi pengguna: masuk/keluar, data pegawai, peran sistem, dan hak akses fitur.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO, panggilFungsi } from '@/lib/supabase'
import { aturSelisihServer } from '@/lib/tanggal'
import { PENGGUNA_DEMO } from '@/lib/demo'

const simpan = (k, v) => { try { v == null ? localStorage.removeItem(k) : localStorage.setItem(k, v) } catch { /* penyimpanan peramban tidak tersedia */ } }
const baca = (k) => { try { return localStorage.getItem(k) } catch { return null } }

export const useSesi = defineStore('sesi', {
  state: () => ({ pengguna: null, fitur: {}, siap: false, wajibGantiSandi: false }),
  getters: {
    masuk: (s) => !!s.pengguna,
    peran: (s) => s.pengguna?.peran ?? 'pegawai',
    isSuperadmin: (s) => s.pengguna?.peran === 'superadmin',
    isAdmin: (s) => ['admin', 'superadmin'].includes(s.pengguna?.peran),
    namaPendek: (s) => (s.pengguna?.nama_lengkap ?? '').replace(/^(Ust\.|Ustzh\.)\s*/, '').split(',')[0],
    inisial: (s) => (s.pengguna?.nama_lengkap ?? '?').replace(/^(Ust\.|Ustzh\.)\s*/, '').split(/\s+/).slice(0, 2).map((k) => k[0]).join('').toUpperCase(),
  },
  actions: {
    async mulai() {
      if (MODE_DEMO) {
        const p = baca('simka.demo.peran')
        if (p && PENGGUNA_DEMO[p]) this.pengguna = { ...PENGGUNA_DEMO[p] }
        this.siap = true
        return
      }
      try {
        const { data } = await supabase.rpc('waktu_server')
        if (data?.iso) aturSelisihServer(data.iso)
      } catch { /* jam peranti dipakai sementara */ }
      const { data: { session } } = await supabase.auth.getSession()
      if (session) await this.muatPegawai()
      supabase.auth.onAuthStateChange((ev) => { if (ev === 'SIGNED_OUT') this.$reset() })
      this.siap = true
    },

    async muatPegawai() {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return
      const { data, error } = await supabase.from('v_pegawai').select('*').eq('user_id', user.id).maybeSingle()
      if (error || !data) { await supabase.auth.signOut(); throw new Error('Data pegawai untuk akun ini tidak ditemukan.') }
      const jabatan = [data.jabatan_struktural, ...(data.jabatan_fungsional || [])].filter(Boolean).join(', ')
        || (data.peran === 'superadmin' ? 'Pengelola sistem' : data.peran === 'admin' ? 'Admin' : 'Pegawai')
      this.pengguna = { ...data, jabatan }
      this.wajibGantiSandi = data.wajib_ganti_sandi
      const { data: fitur } = await supabase.rpc('fitur_saya')
      this.fitur = fitur || {}
    },

    /** Masuk dengan username + kata sandi (melalui Edge Function "masuk"). */
    async masukDengan(username, sandi) {
      if (MODE_DEMO) throw new Error('Mode demo: pilih peran di bawah untuk mencoba tampilan.')
      const r = await panggilFungsi('masuk', { username, sandi })
      if (r.status !== 'aktif') throw new Error(r.pesan || r.galat || 'Tidak dapat masuk.')
      await supabase.auth.setSession(r.session)
      await this.muatPegawai()
      return r
    },

    masukDemo(peran) { this.pengguna = { ...PENGGUNA_DEMO[peran] }; simpan('simka.demo.peran', peran) },

    async keluar() {
      if (!MODE_DEMO) await supabase.auth.signOut()
      simpan('simka.demo.peran', null)
      this.$reset(); this.siap = true
    },

    /** Tingkat akses fitur: 0 tidak ada, 1 lihat, 2 input/ubah, 3 kelola. Superadmin selalu 3. */
    tingkat(kode) {
      if (this.isSuperadmin) return 3
      return Number(this.fitur?.[kode] ?? 0)
    },
  },
})
