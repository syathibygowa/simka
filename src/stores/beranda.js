// SIMKA PRO | src/stores/beranda.js | v1.0 | Fase 3 – Tahap 6 Dashboard per peran | 04/10/2026
// Ringkasan beranda per peran (pribadi, pimpinan, pengelola) dalam satu panggilan, disegarkan tiap 60 detik
// dan saat aplikasi kembali dibuka.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { useSesi } from './sesi'

let detak = null
const hari = (n) => new Date(Date.now() + 8 * 3600000 + n * 86400000).toISOString().slice(0, 10)
function demo(peran) {
  const v = { pribadi: {
    jurnal: { wajib: true, butir_total: 8, butir_selesai: 3, kegiatan: 1, dikembalikan: peran === 'pegawai' ? 1 : 0, kemarin_kosong: false },
    pengajuan_menunggu: 1, pengajuan_terakhir: { id: 'pj1', jenis: 'Izin', status: 'menunggu', mulai: hari(3), selesai: hari(4), jenjang: 'Direktur/Wakil Direktur' },
    sedang_cuti: null, cuti_sisa: { nama: 'Cuti tahunan', kuota: 12, sisa: 9 },
    agenda: [{ id: 'ag0', judul: 'Rapat koordinasi seluruh pegawai', jenis: 'rapat', mulai: hari(3), selesai: hari(3), jam_mulai: '20:00:00', lokasi: 'Aula Utama' },
      { id: 'ag1', judul: 'Ujian kenaikan juz santri', jenis: 'kegiatan', mulai: hari(9), selesai: hari(11), jam_mulai: '07:30:00', lokasi: 'Masjid Pondok' }],
    libur_berikut: { nama: 'Libur Maulid Nabi', mulai: hari(14), selesai: hari(14) },
    pengumuman_belum: 1, pengumuman_terbaru: { id: 'pg1', judul: 'Rapat koordinasi seluruh pegawai', penting: true, dibaca: false }, berkas_baru: 2 } }
  if (peran !== 'pegawai') {
    v.pimpinan = { persetujuan_menunggu: 2, anggota: 24, hadir: 19, terlambat: 2, jurnal_wajib: 22, jurnal_terisi: 17,
      tidak_hadir: [{ nama: 'Ustzh. Nurul Aini, S.Pd.', jenis: 'Sakit', selesai: hari(1) }, { nama: 'Ust. Syamsul Arifin, S.Pd.', jenis: 'Dinas luar', selesai: hari(0) }] }
    v.kelola = { verval_jurnal: 3, pengajuan_menunggu: 4, pengajuan_bulan_ini: 11, sedang_izin: 3, agenda_bulan_ini: 5, agenda_pekan_ini: 1, berkas_belum_dibuka: 9,
      kartu_terbit: 41, tanpa_niy: 3, tanpa_foto: 12, perangkat_push: 28, akun_aktif: 52, jurnal_hari_ini: 37, pengumuman_aktif: 3 }
  }
  return v
}

export const useBeranda = defineStore('beranda', {
  state: () => ({ data: null, diperbarui: null }),
  actions: {
    async muat() {
      if (MODE_DEMO) { this.data = demo(useSesi().peran); this.diperbarui = new Date(); return }
      const { data, error } = await supabase.rpc('ringkasan_beranda')
      if (!error) { this.data = data || {}; this.diperbarui = new Date() }
    },
    mulai() {
      this.muat()
      clearInterval(detak); detak = setInterval(() => document.visibilityState === 'visible' && this.muat(), 60000)
      document.addEventListener('visibilitychange', this._lihat ||= () => document.visibilityState === 'visible' && this.muat())
    },
    berhenti() { clearInterval(detak); detak = null; if (this._lihat) document.removeEventListener('visibilitychange', this._lihat) },
  },
})
