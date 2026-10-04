// SIMKA PRO | src/stores/jurnal.js | v1.0 | Fase 3 – Tahap 3 Jurnal harian | 04/10/2026
// Jurnal harian pegawai: ceklist dari template jabatan, kegiatan tulis sendiri (diverval), rekap, dan template.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'
import * as demo from '@/lib/demoJurnal'

const rpc = async (nama, arg) => {
  const { data, error } = await supabase.rpc(nama, arg)
  if (error) throw new Error(pesanGalat(error))
  return data
}

export const useJurnal = defineStore('jurnal', {
  state: () => ({ hari: null, antrian: [], butirTemplate: [], memuat: false }),
  actions: {
    async muatHari(tanggal) {
      this.memuat = true
      try { this.hari = MODE_DEMO ? demo.hari(tanggal) : await rpc('jurnal_saya', { p_tanggal: tanggal }) } finally { this.memuat = false }
    },
    async centang(item, selesai, catatan = null) {
      const b = this.hari.butir.find((x) => x.item_id === item)
      const lama = { ...b }
      Object.assign(b, { selesai, catatan: selesai ? catatan ?? b.catatan : null })
      if (MODE_DEMO) return
      try { await rpc('centang_jurnal', { p_tanggal: this.hari.tanggal, p_item: item, p_selesai: selesai, p_catatan: catatan ?? b.catatan }) }
      catch (e) { Object.assign(b, lama); throw e }
    },
    async simpanKegiatan(isi) {
      if (MODE_DEMO) { demo.simpanKegiatan(isi); return this.muatHari(isi.tanggal) }
      await rpc('simpan_kegiatan_jurnal', { p: isi })
      await this.muatHari(isi.tanggal)
    },
    async hapusKegiatan(id) {
      if (!MODE_DEMO) await rpc('hapus_kegiatan_jurnal', { p_id: id })
      this.hari.kegiatan = this.hari.kegiatan.filter((k) => k.id !== id)
    },

    async muatAntrian(status = 'menunggu') {
      this.memuat = true
      try { this.antrian = MODE_DEMO ? demo.antrian(status) : (await rpc('antrian_verval_jurnal', { p_status: status })) || [] } finally { this.memuat = false }
    },
    async verval(ids, setuju, catatan) {
      if (MODE_DEMO) { demo.verval(ids, setuju, catatan); return this.muatAntrian() }
      const n = await rpc('verval_jurnal', { p_ids: ids, p_setuju: setuju, p_catatan: catatan || null })
      await this.muatAntrian()
      return n
    },

    async rekap(mulai, akhir) {
      if (MODE_DEMO) return demo.rekap(useSesi())
      return (await rpc('rekap_jurnal', { p_mulai: mulai, p_akhir: akhir })) || []
    },
    async individu(emp, mulai, akhir) {
      if (MODE_DEMO) return demo.individu(mulai, akhir)
      return (await rpc('jurnal_pegawai', { p_emp: emp, p_mulai: mulai, p_akhir: akhir })) || []
    },

    async muatTemplate() {
      if (MODE_DEMO) { this.butirTemplate = demo.template(); return }
      const { data, error } = await supabase.from('journal_items').select('*').order('urutan')
      if (error) throw new Error(pesanGalat(error))
      this.butirTemplate = data || []
    },
    async simpanButir(b) {
      const isi = { functional_position_id: b.functional_position_id || null, structural_position_id: b.structural_position_id || null,
        org_unit_id: b.org_unit_id || null, uraian: b.uraian.trim(), urutan: Number(b.urutan) || 0, aktif: b.aktif !== false }
      if (MODE_DEMO) { if (b.id) Object.assign(this.butirTemplate.find((x) => x.id === b.id), isi); else this.butirTemplate.push({ ...isi, id: 'b' + Date.now() }); return }
      const q = b.id ? supabase.from('journal_items').update(isi).eq('id', b.id) : supabase.from('journal_items').insert(isi)
      const { error } = await q
      if (error) throw new Error(pesanGalat(error))
      await this.muatTemplate()
    },
    async hapusButir(id) {
      if (!MODE_DEMO) { const { error } = await supabase.from('journal_items').delete().eq('id', id); if (error) throw new Error(pesanGalat(error)) }
      this.butirTemplate = this.butirTemplate.filter((x) => x.id !== id)
    },
  },
})
