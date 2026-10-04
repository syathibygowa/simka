// SIMKA PRO | src/stores/berkasPegawai.js | v1.0 | Fase 3 – Tahap 4 Berkas Saya dan kartu pegawai | 04/10/2026
// Berkas Saya: info, formulir, surat, dan SK yang dikirim kepada pegawai tertentu; catatan pembukaan.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'

const rpc = async (nama, arg) => { const { data, error } = await supabase.rpc(nama, arg); if (error) throw new Error(pesanGalat(error)); return data }
const lalu = (m) => new Date(Date.now() - m * 60000).toISOString()
const DEMO = (kelola) => [
  ['SK Penugasan Musyrif Asrama Putra TA 2026/2027', 'sk', 'Surat keputusan penugasan musyrif untuk tahun ajaran berjalan.', 'SK-Musyrif-2026.pdf', 'application/pdf', 180, null, 6, 4],
  ['Formulir Pembaruan Data Keluarga', 'formulir', 'Isi formulir daring paling lambat akhir bulan.', null, null, 2000, 'https://forms.gle/contoh', 17, 11],
  ['Surat Edaran Libur Pertengahan Semester', 'surat', null, 'SE-Libur.pdf', 'application/pdf', 6000, null, 17, 17],
  ['Panduan Penggunaan SIMKA PRO untuk Pegawai', 'info', 'Panduan singkat presensi, pengajuan, dan jurnal.', 'Panduan-SIMKA.pdf', 'application/pdf', 9000, null, 17, 15],
].map(([judul, kategori, keterangan, nama_berkas, mime, m, tautan_luar, pen, buka], i) => ({ id: 'bk' + i, judul, kategori, keterangan, nama_berkas, mime, ukuran: nama_berkas ? 245000 : null, berkas_id: nama_berkas ? 'o' + i : null,
  tautan_luar, ringkasan_sasaran: i === 0 ? 'Musyrif/Musyrifah' : 'Semua pegawai', berlaku_sampai: null, created_at: lalu(m), pembuat: 'Ust. Fadhil Rahman, S.Kom.',
  dibuka_pertama: i > 1 ? lalu(m - 30) : null, jumlah_buka: i > 1 ? 1 : 0, saya_penerima: true, penerima: kelola ? pen : null, sudah_buka: kelola ? buka : null }))

export const useBerkasPegawai = defineStore('berkasPegawai', {
  state: () => ({ daftar: [], memuat: false }),
  actions: {
    bolehKelola() { return useSesi().bolehAdmin('kelola_berkas') },
    async muat() {
      this.memuat = true
      try { this.daftar = MODE_DEMO ? (this.daftar.length ? this.daftar : DEMO(this.bolehKelola())) : (await rpc('daftar_berkas_pegawai', { p_kelola: this.bolehKelola() })) || [] }
      finally { this.memuat = false }
    },
    async simpan(isi) {
      if (MODE_DEMO) { this.daftar.unshift({ ...isi, id: 'bk' + Date.now(), created_at: new Date().toISOString(), saya_penerima: true, penerima: 5, sudah_buka: 0, ringkasan_sasaran: isi.ringkasan }); return }
      const id = await rpc('simpan_berkas_pegawai', { p: isi }); await this.muat(); return id
    },
    async hapus(id) { if (!MODE_DEMO) await rpc('hapus_berkas_pegawai', { p_id: id }); this.daftar = this.daftar.filter((d) => d.id !== id) },
    async catatBuka(id) {
      const d = this.daftar.find((x) => x.id === id)
      if (d && d.saya_penerima) { d.jumlah_buka = (d.jumlah_buka || 0) + 1; d.dibuka_pertama ||= new Date().toISOString() }
      if (!MODE_DEMO) await rpc('catat_buka_berkas', { p_id: id })
    },
    async pembuka(id) {
      if (MODE_DEMO) return [['Ust. Hasan Basri, Lc.', 'Bidang Tahfizh', 40], ['Ust. Muhammad Ikhsan, S.Pd.I.', 'Bidang Kesantrian', null], ['Ust. Abdul Hakim', 'Unit Security', 300]]
        .map(([nama, unit, m], i) => ({ employee_id: 'p' + i, nama, unit, dibuka_pertama: m ? lalu(m) : null, dibuka_terakhir: m ? lalu(m - 5) : null, jumlah_buka: m ? 2 : 0 }))
      return (await rpc('pembuka_berkas', { p_id: id })) || []
    },
  },
})
