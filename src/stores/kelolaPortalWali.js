// SIMKA PRO | src/stores/kelolaPortalWali.js | v1.1 | Fase 9 – Tahap 13.4.0 Pilihan jenis dokumen santri | 15/10/2026
// Pengelolaan Portal Wali (superadmin; admin ber-izin kelola_santri): pengaturan dan butir informasi,
// ringkasan kesiapan, data santri yang belum lengkap, sesi aktif, percobaan gagal/terkunci, buka kunci, cabut sesi.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { PENGATURAN_BAWAAN } from '@/lib/portalWali'
import { SANTRI_DEMO } from '@/lib/demoSantri'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'

const rpc = async (nama, arg) => { const { data, error } = await supabase.rpc(nama, arg); if (error) throw new Error(pesanGalat(error)); return data }

let demoSet = JSON.parse(JSON.stringify(PENGATURAN_BAWAAN))
function demoKurang() {
  return SANTRI_DEMO().filter((s) => s.status === 'aktif').map((s) => ({
    id: s.id, nis: s.nis, nisn: s.nisn, nama: s.nama_lengkap, jk: s.jenis_kelamin, kelas: null,
    kurang: [!s.tanggal_lahir && 'Tanggal lahir', !s.kontak.some((k) => k.no_hp) && 'Nomor HP orang tua/wali'].filter(Boolean),
  })).filter((s) => s.kurang.length)
}

export const useKelolaPortalWali = defineStore('kelolaPortalWali', {
  state: () => ({ pilihanDokumen: null, pengaturan: null, ringkasan: null, kurang: [], sesi: [], gagal: [], memuat: false, galat: '' }),
  getters: {
    terkunci: (s) => s.gagal.filter((g) => g.terkunci_sampai && new Date(g.terkunci_sampai) > new Date()),
  },
  actions: {
    async muat() {
      this.memuat = true; this.galat = ''
      try {
        if (MODE_DEMO) {
          const kurang = demoKurang(); const n = SANTRI_DEMO().filter((s) => s.status === 'aktif').length
          this.pengaturan = { ...demoSet, boleh_ubah: useSesi().isSuperadmin }
          this.ringkasan = { aktif: demoSet.aktif, santri: n, tanpa_nisn: 4, tanpa_tgl: 0, tanpa_hp: kurang.length, siap: n - kurang.length,
            sesi_aktif: 3, santri_bersesi: 2, masuk_7_hari: 5, gagal_24_jam: 2, dibuka_7_hari: 2 }
          this.kurang = kurang
          this.sesi = [
            { id: 'w1', student_id: 's1', nis: '2615001', nama: 'Ahmad Fauzan', kelas: '7A', hubungan: 'ayah', nama_wali: 'Fauzi', perangkat: 'Android · Chrome', dibuat: new Date(Date.now() - 3 * 864e5).toISOString(), terakhir: new Date(Date.now() - 36e5).toISOString(), kedaluwarsa: new Date(Date.now() + 27 * 864e5).toISOString() },
            { id: 'w2', student_id: 's1', nis: '2615001', nama: 'Ahmad Fauzan', kelas: '7A', hubungan: 'ibu', nama_wali: 'Siti Aminah', perangkat: 'iPhone/iPad · Safari', dibuat: new Date(Date.now() - 864e5).toISOString(), terakhir: new Date(Date.now() - 6e5).toISOString(), kedaluwarsa: new Date(Date.now() + 29 * 864e5).toISOString() },
            { id: 'w3', student_id: 's2', nis: '2615002', nama: 'Muhammad Rafi', kelas: '7A', hubungan: 'ayah', nama_wali: 'Rahman', perangkat: 'Android · Samsung Internet', dibuat: new Date(Date.now() - 5 * 864e5).toISOString(), terakhir: new Date(Date.now() - 2 * 864e5).toISOString(), kedaluwarsa: new Date(Date.now() + 25 * 864e5).toISOString() },
          ]
          this.pilihanDokumen = { surat: [{ kode: 'keterangan_aktif_santri', nama: 'Surat Keterangan Aktif Santri', kategori: 'santri' }, { kode: 'kelakuan_baik', nama: 'Surat Keterangan Berkelakuan Baik', kategori: 'santri' }, { kode: 'keterangan_lulus', nama: 'Surat Keterangan Lulus (SKL)', kategori: 'santri' }, { kode: 'keterangan_prestasi', nama: 'Surat Keterangan Prestasi', kategori: 'santri' }, { kode: 'rekomendasi_sekolah', nama: 'Surat Rekomendasi Sekolah', kategori: 'santri' }, { kode: 'undangan', nama: 'Surat Undangan', kategori: 'umum' }],
            tahfizh: [{ kode: 'suket_juz', nama: 'Surat Keterangan Ujian Kenaikan Juz' }, { kode: 'sertifikat_hafalan', nama: 'Sertifikat Hafalan' }, { kode: 'sertifikat_tahfizh', nama: 'Sertifikat Tahfizhul Quran' }] }
          this.gagal = [{ kunci: '2615003', nis: '2615003', nama: 'Abdullah Hanif', gagal: 5, terakhir: new Date(Date.now() - 3e5).toISOString(), terkunci_sampai: new Date(Date.now() + 6e5).toISOString(), alasan: 'Nomor HP tidak cocok' }]
          return
        }
        const [p, r, k, s, g, pd] = await Promise.all([
          rpc('pengaturan_portal_wali'), rpc('ringkasan_portal_wali'), rpc('kesiapan_portal_wali'), rpc('sesi_portal_wali'), rpc('kunci_portal_wali'), rpc('pilihan_dokumen_portal_wali'),
        ])
        this.pengaturan = p; this.pilihanDokumen = pd; this.ringkasan = r; this.kurang = k || []; this.sesi = s || []; this.gagal = g || []
      } catch (e) { this.galat = e.message } finally { this.memuat = false }
    },
    async simpan(isi) {
      if (MODE_DEMO) { demoSet = { ...demoSet, ...isi, butir: { ...demoSet.butir, ...(isi.butir || {}) } }; this.pengaturan = { ...demoSet, dokumen: isi.dokumen || demoSet.dokumen, boleh_ubah: true }; if (this.ringkasan) this.ringkasan.aktif = demoSet.aktif; return }
      this.pengaturan = await rpc('simpan_pengaturan_portal_wali', { p: isi })
      if (this.ringkasan) this.ringkasan.aktif = this.pengaturan.aktif
    },
    async bukaKunci(kunci) {
      if (!MODE_DEMO) await rpc('buka_kunci_wali', { p_kunci: kunci })
      this.gagal = this.gagal.filter((g) => g.kunci !== kunci)
    },
    async cabut({ sesi = null, santri = null, alasan = '' } = {}) {
      const n = MODE_DEMO ? this.sesi.filter((x) => (!sesi || x.id === sesi) && (!santri || x.student_id === santri)).length
        : await rpc('cabut_sesi_wali', { p_sesi: sesi, p_santri: santri, p_alasan: alasan || null })
      this.sesi = this.sesi.filter((x) => !((!sesi || x.id === sesi) && (!santri || x.student_id === santri)))
      if (this.ringkasan) this.ringkasan.sesi_aktif = this.sesi.length
      return n
    },
  },
})
