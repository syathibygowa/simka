// Data kepegawaian (baca). Penambahan/impor Excel menyusul pada tahap berikutnya Fase 1.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { PEGAWAI_DEMO } from '@/lib/demo'

export const usePegawai = defineStore('pegawai', {
  state: () => ({ daftar: [], memuat: false, galat: '' }),
  actions: {
    async muat() {
      this.memuat = true; this.galat = ''
      if (MODE_DEMO) { this.daftar = PEGAWAI_DEMO; this.memuat = false; return }
      const { data, error } = await supabase.from('v_pegawai')
        .select('id, nama_lengkap, niy, jenis_kelamin, nama_unit, jabatan_fungsional, jabatan_struktural, status_kepegawaian, status_akun, status_keaktifan, tmt_tugas, ttl, masa_kerja, no_hp, email, pendidikan_terakhir')
        .order('nama_lengkap')
      this.memuat = false
      if (error) { this.galat = 'Data pegawai gagal dimuat. Periksa koneksi lalu muat ulang.'; return }
      this.daftar = data
    },
    cari(id) { return this.daftar.find((p) => p.id === id) },
  },
})
