// SIMKA PRO | src/stores/pengajuan.js | v1.1 | Fase 3 – Perbaikan P3 (berkas dan WA) | 04/10/2026
// Pengajuan izin, sakit, dinas luar, dan cuti: ajukan (dengan pemeriksaan aturan di server), persetujuan berjenjang,
// pembatalan, ketentuan (jenis, kuota, jenjang), dan Plt.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'
import * as demo from '@/lib/demoPengajuan'

let kanal = null
const rpc = async (nama, arg) => {
  const { data, error } = await supabase.rpc(nama, arg)
  if (error) throw new Error(pesanGalat(error))
  return data
}

export const usePengajuan = defineStore('pengajuan', {
  state: () => ({ saya: [], persetujuan: [], semua: [], jenis: [], jenjang: [], plt: [], kuota: [], memuat: false, dimuatKetentuan: false }),
  getters: {
    menungguSaya: (s) => s.persetujuan.filter((r) => r.menunggu_saya).length,
    jenisAktif: (s) => s.jenis.filter((j) => j.aktif).sort((a, b) => a.urutan - b.urutan),
  },
  actions: {
    async muatKetentuan(paksa = false) {
      if (this.dimuatKetentuan && !paksa) return
      if (MODE_DEMO) { Object.assign(this, demo.ketentuan()); this.dimuatKetentuan = true; return }
      const [j, t, p] = await Promise.all([
        supabase.from('leave_types').select('*').order('urutan'),
        supabase.from('leave_tiers').select('*').order('mulai_hari'),
        supabase.from('acting_assignments').select('*, employees!acting_assignments_employee_id_fkey(nama_lengkap), structural_positions(nama), org_units(nama)').order('mulai', { ascending: false }),
      ])
      this.jenis = j.data || []; this.jenjang = t.data || []; this.plt = p.data || []
      this.dimuatKetentuan = true
    },

    async muat(cakupan, { mulai = null, akhir = null } = {}) {
      this.memuat = true
      try {
        if (MODE_DEMO) { this[cakupan] = demo.daftar(cakupan, useSesi().pengguna); if (cakupan === 'saya') this.kuota = demo.kuota(); return }
        this[cakupan] = (await rpc('daftar_pengajuan', { p_cakupan: cakupan, p_mulai: mulai, p_akhir: akhir })) || []
        if (cakupan === 'saya') this.kuota = (await rpc('kuota_saya', {})) || []
        this.langganan()
      } finally { this.memuat = false }
    },

    langganan() {
      if (kanal || MODE_DEMO) return
      kanal = supabase.channel('pengajuan')
        .on('postgres_changes', { event: '*', schema: 'public', table: 'leave_requests' }, () => { this.muat('saya'); this.muat('persetujuan') })
        .subscribe()
    },

    async periksa(isi) {
      if (MODE_DEMO) return demo.periksa(isi, this.jenis)
      return await rpc('periksa_pengajuan', { p: isi })
    },
    async ajukan(isi) {
      if (MODE_DEMO) { const id = demo.ajukan(isi, this.jenis, useSesi().pengguna); this.saya = demo.daftar('saya', useSesi().pengguna); return id }
      const id = await rpc('ajukan_pengajuan', { p: isi })
      await this.muat('saya')
      return id
    },
    async detail(id) {
      if (MODE_DEMO) return demo.detail(id, useSesi())
      return await rpc('detail_pengajuan', { p_id: id })
    },
    /** Kontak WA: pemohon dan calon penyetuju jenjang yang sedang menunggu. */
    async kontak(id) {
      if (MODE_DEMO) return [{ peran: 'pemohon', employee_id: 'd-pg', nama: 'Ust. Hasan Basri, Lc.', no_hp: '081234567801' },
        { peran: 'penyetuju', employee_id: 'p3', nama: 'Siswandi Safari, S.Pd.I., Lc., S.H., M.Ag.', jabatan: 'Direktur', no_hp: '081234567803' }]
      return (await rpc('kontak_pengajuan', { p_id: id })) || []
    },
    async putuskan(id, setuju, catatan) {
      if (MODE_DEMO) return demo.putuskan(id, setuju, catatan, useSesi().pengguna)
      const hasil = await rpc('putuskan_pengajuan', { p_id: id, p_setuju: setuju, p_catatan: catatan || null })
      await this.muat('persetujuan')
      return hasil
    },
    async batalkan(id, alasan) {
      if (MODE_DEMO) return demo.batalkan(id)
      await rpc('batalkan_pengajuan', { p_id: id, p_alasan: alasan || null })
      await this.muat('saya')
    },

    // ----- Ketentuan (admin ber-izin atur_pengajuan dan superadmin) -----
    async simpanJenis(j) {
      const isi = { ...j }; delete isi._baru; delete isi.updated_at
      if (MODE_DEMO) { const i = this.jenis.findIndex((x) => x.id === j.id); if (i >= 0) this.jenis[i] = isi; else this.jenis.push({ ...isi, id: 'j' + Date.now() }); return }
      if (j._baru) delete isi.id
      const q = j._baru ? supabase.from('leave_types').insert(isi) : supabase.from('leave_types').update(isi).eq('id', j.id)
      const { error } = await q
      if (error) throw new Error(pesanGalat(error))
      await this.muatKetentuan(true)
    },
    async simpanJenjang(daftar) {
      if (MODE_DEMO) { this.jenjang = daftar.map((t, i) => ({ ...t, id: t.id || 't' + i })); return }
      const lama = this.jenjang.map((t) => t.id)
      const { error: e1 } = await supabase.from('leave_tiers').delete().in('id', lama.length ? lama : ['00000000-0000-0000-0000-000000000000'])
      if (e1) throw new Error(pesanGalat(e1))
      const { error } = await supabase.from('leave_tiers').insert(daftar.map((t) => ({ mulai_hari: t.mulai_hari, sampai_hari: t.sampai_hari || null, langkah: t.langkah })))
      if (error) throw new Error(pesanGalat(error))
      await this.muatKetentuan(true)
    },
    async simpanPlt(p) {
      if (MODE_DEMO) { this.plt.unshift({ ...p, id: 'plt' + Date.now() }); return }
      const { error } = await supabase.from('acting_assignments').insert({ employee_id: p.employee_id, structural_position_id: p.structural_position_id,
        org_unit_id: p.org_unit_id || null, mulai: p.mulai, sampai: p.sampai, catatan: p.catatan || null, dibuat_oleh: useSesi().pengguna?.id })
      if (error) throw new Error(pesanGalat(error))
      await this.muatKetentuan(true)
    },
    async hapusPlt(id) {
      if (!MODE_DEMO) { const { error } = await supabase.from('acting_assignments').delete().eq('id', id); if (error) throw new Error(pesanGalat(error)) }
      this.plt = this.plt.filter((x) => x.id !== id)
    },

    berhenti() { kanal?.unsubscribe(); kanal = null; this.$reset() },
  },
})
