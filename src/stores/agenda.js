// SIMKA PRO | src/stores/agenda.js | v1.1 | Fase 3 – Perbaikan P2 (agenda lanjutan) | 04/10/2026
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
  { judul: 'Rapat pekanan Pengurus Harian', jenis: 'rapat', m: -1, s: -1, jam: '20:30:00', js: '21:30:00', lokasi: 'Ruang Direktur', warna: 'anggur', ulang: { frek: 'pekanan', interval: 1, hari: [6] },
    tautan: 'https://zoom.us/j/1234567890', nama_tautan: 'Zoom (bagi yang di luar pondok)' },
].map((a, i) => ({ id: 'ag' + i, sumber: 'agenda', judul: a.judul, keterangan: a.ket || null, jenis: a.jenis, mulai: hari(a.m), selesai: hari(a.s), jam_mulai: a.jam || null,
  jam_selesai: a.js || null, lokasi: a.lokasi || null, ringkasan_sasaran: i === 5 ? 'PH' : 'Semua pegawai', pengingat_menit: a.jam ? [1440, 60] : [1440], berlaku_untuk: a.jenis === 'libur' ? ['semua'] : null,
  jenis_libur: a.jenis === 'libur' ? 'libur_pondok' : null, pembuat: 'Ust. Fadhil Rahman, S.Kom.', penerima: 17,
  warna: a.warna || { libur: 'tomat', rapat: 'lavender', lainnya: 'pisang' }[a.jenis] || 'merak', ulang: a.ulang || null, tautan: a.tautan || null, nama_tautan: a.nama_tautan || null,
  ringkasan_ulang: a.ulang ? 'Setiap pekan (Sabtu)' : null, mulai_seri: hari(a.m), selesai_seri: hari(a.s) })))
/** Bentangkan agenda berulang (demo: pekanan dan harian sederhana). */
function bentang(daftar, dari, sampai) {
  const out = []
  for (const a of daftar) {
    if (!a.ulang) { if (a.selesai >= dari && a.mulai <= sampai) out.push(a); continue }
    const lompat = a.ulang.frek === 'harian' ? 1 : 7
    for (let d = a.mulai_seri, i = 0; d <= sampai && i < 400; i++, d = new Date(Date.parse(d + 'T00:00:00Z') + lompat * 86400000).toISOString().slice(0, 10))
      if (d >= dari && !(a.pengecualian || []).includes(d)) out.push({ ...a, mulai: d, selesai: d })
  }
  return out
}

export const useAgenda = defineStore('agenda', {
  state: () => ({ daftar: [], memuat: false, rentang: null }),
  actions: {
    bolehKelola() { return useSesi().bolehAdmin('kelola_agenda') },
    async muat(mulai, akhir) {
      this.memuat = true; this.rentang = [mulai, akhir]
      try { this.daftar = MODE_DEMO ? bentang(demo(), mulai, akhir) : (await rpc('kalender_saya', { p_mulai: mulai, p_akhir: akhir, p_kelola: this.bolehKelola() })) || [] }
      finally { this.memuat = false }
    },
    async muatUlang() { if (this.rentang) await this.muat(...this.rentang) },
    async simpan(isi) {
      if (MODE_DEMO) {
        const a = { ...isi, sumber: 'agenda', ringkasan_sasaran: isi.ringkasan || 'Semua pegawai', penerima: 12, pembuat: useSesi().pengguna?.nama_lengkap,
          mulai_seri: isi.mulai, selesai_seri: isi.selesai, ringkasan_ulang: isi.ulang ? 'Agenda berulang' : null }
        if (isi.id) Object.assign(demo().find((x) => x.id === isi.id), a); else demo().push({ ...a, id: 'ag' + Date.now() })
        await this.muatUlang(); return isi.id || demo().at(-1).id
      }
      const id = await rpc('simpan_agenda', { p: isi }); await this.muatUlang(); return id
    },
    async hapus(id) {
      if (MODE_DEMO) { DEMO = demo().filter((a) => a.id !== id) } else await rpc('hapus_agenda', { p_id: id })
      this.daftar = this.daftar.filter((a) => a.id !== id)
    },
    async lewati(id, tanggal) {
      if (MODE_DEMO) { const a = demo().find((x) => x.id === id); a.pengecualian = [...(a.pengecualian || []), tanggal] }
      else await rpc('lewati_kejadian_agenda', { p_id: id, p_tanggal: tanggal })
      await this.muatUlang()
    },
    async penerima(id) {
      if (MODE_DEMO) return [['Ust. Hasan Basri, Lc.', '081234567801', 'Bidang Tahfizh'], ['Ustzh. Nurul Aini, S.Pd.', '081234567802', 'Bidang Kesetaraan Wustha'], ['Ust. Abdul Hakim', null, 'Unit Security']]
        .map(([nama, no_hp, unit], i) => ({ employee_id: 'p' + i, nama, no_hp, unit }))
      return (await rpc('penerima_agenda', { p_id: id })) || []
    },
  },
})
