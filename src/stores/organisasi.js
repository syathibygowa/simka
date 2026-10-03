// SIMKA PRO | src/stores/organisasi.js | v1.0 | Fase 1 – Struktur organisasi | 03/10/2026
// Pohon bidang/unit, jabatan fungsional (P1), dan jabatan struktural (P2).
// Dibaca semua pengguna masuk; diubah hanya oleh superadmin (RLS).
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { ORGANISASI_DEMO } from '@/lib/demo'
import { pesanGalat } from './lembaga'

const TABEL = { units: 'org_units', fungsional: 'functional_positions', struktural: 'structural_positions' }

export const useOrganisasi = defineStore('organisasi', {
  state: () => ({ units: [], fungsional: [], struktural: [], jumlahUnit: {}, jumlahFungsional: {}, jumlahStruktural: {}, dimuat: false }),
  getters: {
    anak: (s) => (id) => s.units.filter((u) => u.parent_id === id).sort((a, b) => a.urutan - b.urutan || a.nama.localeCompare(b.nama)),
    akar: (s) => s.units.filter((u) => !u.parent_id),
    cariUnit: (s) => (id) => s.units.find((u) => u.id === id),
    /** id unit beserta seluruh turunannya */
    turunan: (s) => (id) => {
      const hasil = new Set([id]); let ubah = true
      while (ubah) { ubah = false; for (const u of s.units) if (u.parent_id && hasil.has(u.parent_id) && !hasil.has(u.id)) { hasil.add(u.id); ubah = true } }
      return hasil
    },
    /** Daftar datar berurutan pohon (untuk pilihan induk dan tabel cetak) */
    datar(s) {
      const out = []
      const jalan = (id, lv) => this.anak(id).forEach((u) => { out.push({ ...u, tingkat: lv }); jalan(u.id, lv + 1) })
      s.units.filter((u) => !u.parent_id).forEach((r) => { out.push({ ...r, tingkat: 0 }); jalan(r.id, 1) })
      return out
    },
  },
  actions: {
    async muat() {
      if (MODE_DEMO) { if (!this.dimuat) this.$patch(ORGANISASI_DEMO()); this.dimuat = true; return }
      const [u, f, st, peg, ef, es] = await Promise.all([
        supabase.from('org_units').select('*').order('urutan'),
        supabase.from('functional_positions').select('*').order('urutan'),
        supabase.from('structural_positions').select('*').order('urutan'),
        supabase.from('employees').select('org_unit_id').eq('status_keaktifan', 'aktif'),
        supabase.from('employee_functions').select('functional_position_id'),
        supabase.from('employee_structurals').select('structural_position_id'),
      ])
      this.units = u.data || []; this.fungsional = f.data || []; this.struktural = st.data || []
      const hitung = (rows, k) => (rows || []).reduce((a, r) => { if (r[k]) a[r[k]] = (a[r[k]] || 0) + 1; return a }, {})
      this.jumlahUnit = hitung(peg.data, 'org_unit_id')
      this.jumlahFungsional = hitung(ef.data, 'functional_position_id')
      this.jumlahStruktural = hitung(es.data, 'structural_position_id')
      this.dimuat = true
    },

    /** Jumlah pegawai sebuah unit termasuk seluruh unit di bawahnya. */
    jumlahCabang(id) { let n = 0; for (const x of this.turunan(id)) n += this.jumlahUnit[x] || 0; return n },

    async simpan(jenis, baris, baru = false) {
      const isi = { ...baris }; delete isi._baru; delete isi.tingkat
      let hasil = isi
      if (!MODE_DEMO) {
        if (baru) delete isi.id
        const q = baru ? supabase.from(TABEL[jenis]).insert(isi) : supabase.from(TABEL[jenis]).update(isi).eq('id', baris.id)
        const { data, error } = await q.select().single()
        if (error) throw new Error(pesanGalat(error))
        hasil = data
      } else if (baru) hasil = { ...isi, id: 'd' + Date.now() }
      const daftar = this[jenis]; const i = daftar.findIndex((x) => x.id === hasil.id)
      if (i >= 0) daftar[i] = { ...daftar[i], ...hasil }; else daftar.push(hasil)
      return hasil
    },

    async hapusUnit(id) {
      if (this.units.some((u) => u.parent_id === id)) throw new Error('Unit ini masih memiliki unit di bawahnya. Pindahkan atau hapus unit di bawahnya lebih dulu.')
      if (this.jumlahUnit[id]) throw new Error('Unit ini masih memiliki pegawai. Pindahkan pegawainya lebih dulu, atau nonaktifkan unit.')
      if (!MODE_DEMO) {
        const { error } = await supabase.from('org_units').delete().eq('id', id)
        if (error) throw new Error(pesanGalat(error))
      }
      this.units = this.units.filter((u) => u.id !== id)
    },
  },
})
