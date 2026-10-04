// SIMKA PRO | src/stores/pengumuman.js | v1.2 | Fase 3 – Perbaikan P3 (berkas dan WA) | 04/10/2026
// Pengumuman: daftar untuk penerima, kelola (admin/superadmin/pemegang hak fitur), tanda dibaca, dan daftar pembaca.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { PENGUMUMAN_DEMO } from '@/lib/demo'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'

let kanal = null

export const usePengumuman = defineStore('pengumuman', {
  state: () => ({ daftar: [], memuat: false, galat: '' }),
  getters: {
    belumDibaca: (s) => s.daftar.filter((p) => p.saya_penerima && !p.dibaca_pada).length,
  },
  actions: {
    bolehKelola() { const s = useSesi(); return s.isAdmin || s.tingkat('pengumuman') >= 2 },

    async muat() {
      this.memuat = true; this.galat = ''
      try {
        if (MODE_DEMO) { if (!this.daftar.length) this.daftar = PENGUMUMAN_DEMO(useSesi().peran); return }
        const { data, error } = await supabase.rpc('daftar_pengumuman', { p_kelola: this.bolehKelola() })
        if (error) { this.galat = 'Pengumuman gagal dimuat. Periksa koneksi lalu muat ulang.'; return }
        this.daftar = data || []
        this.langganan()
      } finally { this.memuat = false }
    },

    /** Pengumuman baru/diubah oleh pembuat lain langsung tampil (Realtime). */
    langganan() {
      if (kanal || MODE_DEMO) return
      kanal = supabase.channel('pengumuman')
        .on('postgres_changes', { event: '*', schema: 'public', table: 'announcements' }, () => this.muat())
        .subscribe()
    },

    async simpan(isi) {
      if (MODE_DEMO) {
        const s = useSesi()
        if (isi.id) { const p = this.daftar.find((x) => x.id === isi.id); Object.assign(p, isi, { updated_at: new Date().toISOString() }); return isi.id }
        const id = 'pg' + Date.now()
        this.daftar.unshift({ ...isi, id, created_at: new Date().toISOString(), pembuat: s.pengguna?.nama_lengkap, ringkasan_sasaran: isi.ringkasan || 'Semua pegawai',
          penerima: 12, sudah_dibaca: 0, saya_penerima: true, dibaca_pada: new Date().toISOString() })
        return id
      }
      const { data, error } = await supabase.rpc('simpan_pengumuman', { p: isi })
      if (error) throw new Error(pesanGalat(error))
      await this.muat()
      return data
    },

    async hapus(id) {
      if (!MODE_DEMO) { const { error } = await supabase.rpc('hapus_pengumuman', { p_id: id }); if (error) throw new Error(pesanGalat(error)) }
      this.daftar = this.daftar.filter((p) => p.id !== id)
    },

    async tandaiDibaca(id) {
      const p = this.daftar.find((x) => x.id === id)
      if (!p || !p.saya_penerima || p.dibaca_pada) return
      p.dibaca_pada = new Date().toISOString()
      if (!MODE_DEMO) await supabase.rpc('baca_pengumuman', { p_id: id })
    },

    async pembaca(id) {
      if (MODE_DEMO) {
        return [['Ust. Hasan Basri, Lc.', 'Bidang Tahfizh', 30], ['Ustzh. Nurul Aini, S.Pd.', 'Bidang Kesetaraan Wustha', 95], ['Ust. Muhammad Ikhsan, S.Pd.I.', 'Bidang Kesantrian', null], ['Ust. Abdul Hakim', 'Unit Security', null]]
          .map(([nama, unit, m], i) => ({ employee_id: 'p' + i, nama, unit, no_hp: i === 3 ? null : '08123456781' + i, dibaca_pada: m == null ? null : new Date(Date.now() - m * 60000).toISOString() }))
      }
      const { data, error } = await supabase.rpc('pembaca_pengumuman', { p_id: id })
      if (error) throw new Error(pesanGalat(error))
      return data || []
    },

    async hitungSasaran(sasaran) {
      if (MODE_DEMO) return sasaran?.jenis === 'semua' ? 17 : 5
      const { data } = await supabase.rpc('hitung_sasaran', { p: sasaran })
      return data ?? 0
    },

    berhenti() { kanal?.unsubscribe(); kanal = null; this.$reset() },
  },
})
