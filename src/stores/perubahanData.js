// SIMKA PRO | src/stores/perubahanData.js | v1.0 | Fase 5 – Perbaikan: pegawai memperbarui data kepegawaiannya | 05/10/2026
// Pengajuan perubahan data kepegawaian oleh pegawai sendiri; diverifikasi-validasi superadmin saja.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'

const rpc = async (nama, arg) => { const { data, error } = await supabase.rpc(nama, arg); if (error) throw new Error(pesanGalat(error)); return data }
let demo = []

export const usePerubahanData = defineStore('perubahanData', {
  state: () => ({ daftar: [], dataSaya: null, memuat: false }),
  getters: { menunggu: (s) => s.daftar.filter((r) => r.status === 'menunggu').length },
  actions: {
    async muatDataSaya() {
      const sesi = useSesi()
      if (MODE_DEMO) { this.dataSaya = { ...sesi.pengguna, tempat_lahir: 'Gowa', tanggal_lahir: '1990-05-12', pendidikan_terakhir: 'S1', status_keluarga: 'menikah', tmt_tugas: '2018-07-16', status_kepegawaian: 'tetap', kategori_honorer: null, no_hp: '081234567890', level_muhaffizh: 'terampil' }; return this.dataSaya }
      const { data, error } = await supabase.from('employees').select('id, nama_lengkap, niy, tempat_lahir, tanggal_lahir, jenis_kelamin, tmt_tugas, status_kepegawaian, kategori_honorer, pendidikan_terakhir, status_keluarga, no_hp, level_muhaffizh').eq('id', sesi.pengguna.id).single()
      if (error) throw new Error(pesanGalat(error))
      this.dataSaya = data; return data
    },
    async muat(status = null) {
      this.memuat = true
      try { this.daftar = MODE_DEMO ? demo.filter((r) => !status || r.status === status) : (await rpc('daftar_perubahan_pegawai', { p_status: status })) || [] }
      finally { this.memuat = false }
    },
    async ajukan(data, alasan, tanggalBerlaku) {
      if (MODE_DEMO) {
        const sesi = useSesi(); const lama = Object.fromEntries(Object.keys(data).map((k) => [k, this.dataSaya?.[k] ?? null]))
        demo = demo.filter((r) => !(r.employee_id === sesi.pengguna.id && r.status === 'menunggu'))
        demo.unshift({ id: 'r' + Date.now(), employee_id: sesi.pengguna.id, nama: sesi.pengguna.nama_lengkap, niy: sesi.pengguna.niy, data, lama, alasan, tanggal_berlaku: tanggalBerlaku, status: 'menunggu', diajukan_pada: new Date().toISOString() })
        return
      }
      await rpc('ajukan_perubahan_pegawai', { p: data, p_alasan: alasan, p_bukti: null, p_tanggal_berlaku: tanggalBerlaku || null })
    },
    async batalkan(id) { if (MODE_DEMO) { const r = demo.find((x) => x.id === id); if (r) r.status = 'dibatalkan'; return } await rpc('batalkan_perubahan_pegawai', { p_id: id }) },
    async putuskan(id, setuju, catatan, koreksi = null) {
      if (MODE_DEMO) { const r = demo.find((x) => x.id === id); Object.assign(r, { status: setuju ? 'disetujui' : 'ditolak', catatan_verifikator: catatan, diputuskan_pada: new Date().toISOString(), data: { ...r.data, ...(koreksi || {}) } }); return }
      await rpc('putuskan_perubahan_pegawai', { p_id: id, p_setuju: setuju, p_catatan: catatan || null, p_koreksi: koreksi })
    },
  },
})
