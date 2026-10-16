// SIMKA PRO | src/stores/pengumumanWali.js | v1.1 | Perbaikan 13.9.0: admin perlu izin Kelola pengumuman | 16/10/2026
// Pengumuman untuk wali santri (pengelola): daftar beserta jumlah dibaca, simpan/ubah, hapus, pembaca per santri,
// pilihan sasaran (jenjang, tingkat, kelompok, santri tertentu, putra/putri) dan hitung penerima.
// Pengirim: admin, superadmin, pemegang hak Pengumuman tingkat 2+, dan pimpinan (Kepala Bidang ke atas) — diperiksa di server.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'

const rpc = async (nama, arg) => { const { data, error } = await supabase.rpc(nama, arg); if (error) throw new Error(pesanGalat(error)); return data }
const DEMO_KELOMPOK = [
  { id: 'g-7a', jenis: 'kelas', nama: '7A', jumlah: 5 }, { id: 'g-8a', jenis: 'kelas', nama: '8A', jumlah: 4 }, { id: 'g-10a', jenis: 'kelas', nama: '10A', jumlah: 4 },
  { id: 'g-kum', jenis: 'kamar', nama: 'Kamar Umar', jumlah: 6, jk: 'L' }, { id: 'g-kai', jenis: 'kamar', nama: 'Kamar Aisyah', jumlah: 6, jk: 'P' },
  { id: 'g-hhb', jenis: 'halaqah', nama: 'Halaqah Ust. Hasan', jumlah: 12, jk: 'L' }, { id: 'g-epn', jenis: 'ekskul', nama: 'Panahan', jumlah: 8 },
]

export const usePengumumanWali = defineStore('pengumumanWali', {
  state: () => ({ daftar: [], pilihan: null, memuat: false, galat: '', dimuat: false }),
  actions: {
    /** Boleh membuat pengumuman wali (perkiraan di aplikasi; server tetap memeriksa). */
    boleh() { const s = useSesi(); return s.bolehAdmin('kelola_pengumuman') || s.tingkat('pengumuman') >= 2 || s.pimpinanTinggi },

    async muat() {
      this.memuat = true; this.galat = ''
      try {
        if (MODE_DEMO) {
          if (!this.dimuat) this.daftar = [{ id: 'pw1', judul: 'Jadwal kunjungan wali bulan November', isi: 'Kunjungan wali santri dilaksanakan *Ahad, 9 November 2026* pukul 08.00–15.00 WITA. Mohon membawa kartu kunjungan.',
            penting: true, sasaran: { jenis: 'semua' }, ringkasan_sasaran: 'Semua wali santri', tampil_sampai: null, tautan: null, nama_tautan: null,
            created_at: new Date(Date.now() - 864e5).toISOString(), pembuat: 'Superadmin SIMKA', penerima: 22, sudah_dibaca: 9 }]
        } else this.daftar = (await rpc('daftar_pengumuman_wali')) || []
        this.dimuat = true
      } catch (e) { this.galat = e.message } finally { this.memuat = false }
    },
    async muatPilihan() {
      if (this.pilihan) return this.pilihan
      this.pilihan = MODE_DEMO ? { kelompok: DEMO_KELOMPOK, tingkat: { 7: 5, 8: 4, 9: 2, 10: 4, 11: 4, 12: 3 } } : await rpc('pilihan_sasaran_wali')
      return this.pilihan
    },
    async hitung(sasaran) {
      if (MODE_DEMO) return { santri: sasaran?.jenis === 'semua' ? 22 : 6, bersesi: 2, ringkasan: sasaran?.jenis === 'semua' ? 'Semua wali santri' : 'Pilihan' }
      return rpc('hitung_sasaran_wali', { p: sasaran })
    },
    async cariSantri(q) {
      if (MODE_DEMO) return [{ id: 's1', nis: '2615001', nama: 'Ahmad Fauzan', jk: 'L', kelas: '7A' }, { id: 's2', nis: '2615002', nama: 'Muhammad Rafi', jk: 'L', kelas: '7A' }]
        .filter((s) => s.nama.toLowerCase().includes(q.toLowerCase()) || s.nis.startsWith(q))
      return (await rpc('cari_santri_wali', { p_cari: q })) || []
    },
    async simpan(isi) {
      if (MODE_DEMO) {
        if (isi.id) { Object.assign(this.daftar.find((x) => x.id === isi.id) || {}, isi); return isi.id }
        const id = 'pw' + Date.now()
        this.daftar.unshift({ ...isi, id, created_at: new Date().toISOString(), pembuat: useSesi().pengguna?.nama_lengkap, ringkasan_sasaran: isi.ringkasan || 'Semua wali santri', penerima: 22, sudah_dibaca: 0 })
        return id
      }
      const id = await rpc('simpan_pengumuman_wali', { p: isi }); await this.muat(); return id
    },
    async hapus(id) {
      if (!MODE_DEMO) await rpc('hapus_pengumuman_wali', { p_id: id })
      this.daftar = this.daftar.filter((x) => x.id !== id)
    },
    async pembaca(id) {
      if (MODE_DEMO) return [['2615001', 'Ahmad Fauzan', '7A', 'ayah', 30], ['2615002', 'Muhammad Rafi', '7A', null, null], ['2514001', 'Abdullah Hanif', '8A', 'ibu', 200]]
        .map(([nis, nama, kelas, h, m], i) => ({ student_id: 's' + i, nis, nama, jk: 'L', kelas, dibaca_hubungan: h, dibaca_pada: m == null ? null : new Date(Date.now() - m * 60000).toISOString(), bersesi: i !== 1, no_hp: '0812345678' + i, nama_wali: 'Wali ' + nama.split(' ')[0] }))
      return (await rpc('pembaca_pengumuman_wali', { p_id: id })) || []
    },
  },
})
