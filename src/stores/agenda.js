// SIMKA PRO | src/stores/agenda.js | v1.0 | Fase 3 – Tahap 5 Agenda dan template WA | 04/10/2026
// Agenda dan kalender pondok: agenda dengan sasaran, pengingat H-n, hari libur pondok, dan penerima (untuk WA).
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'

const rpc = async (nama, arg) => { const { data, error } = await supabase.rpc(nama, arg); if (error) throw new Error(pesanGalat(error)); return data }
const hari = (n) => new Date(Date.now() + 8 * 3600000 + n * 86400000).toISOString().slice(0, 10)
let DEMO = null
const demo = () => (DEMO ||= [
  { judul: 'Rapat koordinasi seluruh pegawai', jenis: 'rapat', m: 3, s: 3, jam: '20:00:00', js: '21:30:00', lokasi: 'Aula Utama', ket: 'Membawa catatan program bidang.' },
  { judul: 'Ujian kenaikan juz santri', jenis: 'kegiatan', m: 9, s: 11, jam: '07:30:00', js: '11:30:00', lokasi: 'Masjid Pondok', ket: 'Muhaffizh menyiapkan daftar santri peserta.' },
  { judul: 'Libur Maulid Nabi', jenis: 'libur', m: 14, s: 14 },
  { judul: 'Pelatihan pertolongan pertama', jenis: 'kegiatan', m: -2, s: -2, jam: '09:00:00', js: '12:00:00', lokasi: 'Klinik' },
  { judul: 'Pengumpulan laporan bulanan bidang', jenis: 'lainnya', m: 20, s: 20 },
].map((a, i) => ({ id: 'ag' + i, sumber: 'agenda', judul: a.judul, keterangan: a.ket || null, jenis: a.jenis, mulai: hari(a.m), selesai: hari(a.s), jam_mulai: a.jam || null,
  jam_selesai: a.js || null, lokasi: a.lokasi || null, ringkasan_sasaran: 'Semua pegawai', pengingat: [7, 3, 1, 0], berlaku_untuk: a.jenis === 'libur' ? ['semua'] : null,
  jenis_libur: a.jenis === 'libur' ? 'libur_pondok' : null, pembuat: 'Ust. Fadhil Rahman, S.Kom.', penerima: 17 })))

export const useAgenda = defineStore('agenda', {
  state: () => ({ daftar: [], memuat: false, rentang: null }),
  actions: {
    bolehKelola() { return useSesi().bolehAdmin('kelola_agenda') },
    async muat(mulai, akhir) {
      this.memuat = true; this.rentang = [mulai, akhir]
      try { this.daftar = MODE_DEMO ? demo().filter((a) => a.selesai >= mulai && a.mulai <= akhir) : (await rpc('kalender_saya', { p_mulai: mulai, p_akhir: akhir, p_kelola: this.bolehKelola() })) || [] }
      finally { this.memuat = false }
    },
    async muatUlang() { if (this.rentang) await this.muat(...this.rentang) },
    async simpan(isi) {
      if (MODE_DEMO) {
        const a = { ...isi, sumber: 'agenda', ringkasan_sasaran: isi.ringkasan || 'Semua pegawai', penerima: 12, pembuat: useSesi().pengguna?.nama_lengkap }
        if (isi.id) Object.assign(demo().find((x) => x.id === isi.id), a); else demo().push({ ...a, id: 'ag' + Date.now() })
        await this.muatUlang(); return isi.id || demo().at(-1).id
      }
      const id = await rpc('simpan_agenda', { p: isi }); await this.muatUlang(); return id
    },
    async hapus(id) {
      if (MODE_DEMO) { DEMO = demo().filter((a) => a.id !== id) } else await rpc('hapus_agenda', { p_id: id })
      this.daftar = this.daftar.filter((a) => a.id !== id)
    },
    async penerima(id) {
      if (MODE_DEMO) return [['Ust. Hasan Basri, Lc.', '081234567801', 'Bidang Tahfizh'], ['Ustzh. Nurul Aini, S.Pd.', '081234567802', 'Bidang Kesetaraan Wustha'], ['Ust. Abdul Hakim', null, 'Unit Security']]
        .map(([nama, no_hp, unit], i) => ({ employee_id: 'p' + i, nama, no_hp, unit }))
      return (await rpc('penerima_agenda', { p_id: id })) || []
    },
  },
})
