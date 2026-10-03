// SIMKA PRO | src/stores/pegawai.js | v1.2 | Fase 2 – Tahap 5 Jadwal shift | 03/10/2026
// Data kepegawaian: daftar, simpan (beserta jabatan, satu transaksi di server), impor Excel,
// riwayat kepegawaian, dan hapus (superadmin, hanya data tanpa akun/ditolak).
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { PEGAWAI_DEMO } from '@/lib/demo'
import { pesanGalat } from './lembaga'
import { useOrganisasi } from './organisasi'

const KODE_DEMO = { // label jabatan pada data contoh → kode jabatan fungsional
  'Muhaffizh': 'MUHAFFIZH', 'Wali kelas': 'WALI_KELAS', 'Guru mapel': 'GURU', 'Musyrif': 'MUSYRIF', 'Petugas kesehatan': 'MEDIS',
  'Petugas keamanan': 'SECURITY', 'Pembina ekskul': 'PEMBINA_EKSKUL', 'Staf bidang': 'STAF_BIDANG', 'Petugas sarpras': 'SARPRAS', 'Petugas media': 'MEDIA',
}
/** Mode demo: lengkapi data contoh dengan id unit dan jabatan agar formulir dapat dicoba. */
function lengkapiDemo(p, org) {
  const unit = org.units.find((u) => u.nama === p.nama_unit)
  const fid = (p.jabatan_fungsional || []).map((n) => org.fungsional.find((f) => f.kode === KODE_DEMO[n])?.id).filter(Boolean)
  const sid = org.struktural.find((s) => s.nama === p.jabatan_struktural)?.id || null
  return { ...p, org_unit_id: unit?.id || null, fungsional_ids: fid, structural_position_id: sid, unit_struktural_id: sid ? unit?.id : null }
}
/** Mode demo: susun ulang kolom tampilan dari id. */
function tampilDemo(p, org) {
  return {
    ...p,
    nama_unit: org.units.find((u) => u.id === p.org_unit_id)?.nama || null,
    jabatan_fungsional: (p.fungsional_ids || []).map((id) => org.fungsional.find((f) => f.id === id)?.nama).filter(Boolean),
    jabatan_struktural: org.struktural.find((s) => s.id === p.structural_position_id)?.nama || null,
  }
}

export const usePegawai = defineStore('pegawai', {
  state: () => ({ daftar: [], memuat: false, galat: '', riwayat: {} }),
  actions: {
    async muat() {
      this.memuat = true; this.galat = ''
      try {
        if (MODE_DEMO) {
          const org = useOrganisasi(); await org.muat()
          if (!this.daftar.length) this.daftar = PEGAWAI_DEMO.map((p) => lengkapiDemo(p, org))
          return
        }
        const { data, error } = await supabase.from('v_pegawai').select('*').order('nama_lengkap')
        if (error) { this.galat = 'Data pegawai gagal dimuat. Periksa koneksi lalu muat ulang.'; return }
        this.daftar = data
      } finally { this.memuat = false }
    },
    cari(id) { return this.daftar.find((p) => p.id === id) },

    /** Simpan satu pegawai (baru atau ubah) beserta jabatan fungsional dan struktural. */
    async simpan(isi) {
      if (MODE_DEMO) {
        const org = useOrganisasi()
        const data = { ...isi, structural_position_id: isi.struktural_id || null }
        if (!isi.id) { data.id = 'p' + Date.now(); data.status_akun = 'tanpa_akun'; this.daftar.push(tampilDemo(data, org)) }
        else { const i = this.daftar.findIndex((p) => p.id === isi.id); this.daftar[i] = tampilDemo({ ...this.daftar[i], ...data }, org) }
        return data.id
      }
      const { data: id, error } = await supabase.rpc('simpan_pegawai', { p: isi })
      if (error) throw new Error(pesanGalat(error))
      const { data: baru } = await supabase.from('v_pegawai').select('*').eq('id', id).maybeSingle()
      if (baru) { const i = this.daftar.findIndex((p) => p.id === id); if (i >= 0) this.daftar[i] = baru; else this.daftar.push(baru) }
      delete this.riwayat[id]
      return id
    },

    /** Impor banyak baris sekaligus; hasil per baris { baris, ok, aksi, pesan }. */
    async impor(baris) {
      if (MODE_DEMO) {
        const hasil = []
        for (const [i, b] of baris.entries()) {
          const ada = b.niy && this.daftar.find((p) => p.niy === b.niy)
          await this.simpan({ ...(ada ? this.cari(ada.id) : {}), ...b, id: ada?.id })
          hasil.push({ baris: i + 1, ok: true, aksi: ada ? 'diperbarui' : 'ditambah' })
        }
        return hasil
      }
      const hasil = []
      for (let i = 0; i < baris.length; i += 100) { // dikirim per 100 baris
        const { data, error } = await supabase.rpc('impor_pegawai', { p_baris: baris.slice(i, i + 100) })
        if (error) throw new Error(pesanGalat(error))
        hasil.push(...data.map((h) => ({ ...h, baris: h.baris + i })))
      }
      await this.muat()
      return hasil
    },

    async muatRiwayat(id) {
      if (MODE_DEMO) { this.riwayat[id] = []; return }
      const { data } = await supabase.from('employment_history').select('*').eq('employee_id', id).order('tanggal_berlaku', { ascending: false }).order('id', { ascending: false })
      this.riwayat[id] = data || []
    },

    async hapus(id) {
      if (!MODE_DEMO) {
        const { data, error } = await supabase.from('employees').delete().eq('id', id).select('id')
        if (error) throw new Error(pesanGalat(error))
        if (!data?.length) throw new Error('Data ini tidak dapat dihapus. Hanya superadmin yang dapat menghapus data pegawai yang belum memiliki akun atau yang pendaftarannya ditolak.')
      }
      this.daftar = this.daftar.filter((p) => p.id !== id)
    },
  },
})
