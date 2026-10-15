// SIMKA PRO | src/stores/prestasi.js | v1.0 | Tahap C: prestasi dan capaian santri | 16/10/2026
// Prestasi/capaian santri: dicatat wali kelas, musyrif, muhaffizh, pembina ekskul santri tersebut, pimpinan, admin ber-izin
// Kelola santri, dan superadmin (diperiksa server). Pengasuh santri mendapat notifikasi. Prestasi "masuk rapor" tampil di rapor.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'
import { useSantri } from './santri'
import { hariIniISO } from '@/lib/tanggal'

const rpc = async (nama, arg) => { const { data, error } = await supabase.rpc(nama, arg); if (error) throw new Error(pesanGalat(error)); return data }
const tglMundur = (n) => { const d = new Date(); d.setDate(d.getDate() - n); return d.toISOString().slice(0, 10) }

// ---------- Mode demo ----------
let DEMO = null
function demo() {
  if (DEMO) return DEMO
  const san = useSantri().daftar
  const contoh = [
    ['tahfizh', 'kabupaten', 'MTQ Cabang Tahfizh 5 Juz', 'Juara 1', 'LPTQ Kabupaten Gowa', 12],
    ['akademik', 'provinsi', 'Olimpiade Sains Nasional Matematika', 'Medali perak', 'Dinas Pendidikan Sulawesi Selatan', 30],
    ['keagamaan', 'pondok', "Lomba Pidato Bahasa Arab Pekan Muharram", 'Juara 2', 'OSIS Pondok', 40],
    ['non_akademik', 'kecamatan', 'Lomba Panahan Pelajar', 'Juara 3', 'KONI Kecamatan Parangloe', 55],
    ['tahfizh', 'pondok', 'Ujian Tasmi 10 Juz Sekali Duduk', 'Lulus mumtaz', 'Bidang Tahfizh', 20],
    ['karakter', 'pondok', 'Santri Teladan Bulan Rabiul Awal', 'Santri teladan', 'Bidang Kesantrian', 8],
  ]
  DEMO = contoh.map((c, i) => { const s = san[(i * 5) % Math.max(1, san.length)] || {}
    return { id: 'pr' + i, student_id: s.id, nama: s.nama_lengkap, nis: s.nis, jenis_kelamin: s.jenis_kelamin, jenjang: s.jenjang,
      kelas: (s.kelompok || []).find((k) => k.jenis === 'kelas')?.nama || '', tanggal: tglMundur(c[5]), bidang: c[0], tingkat: c[1], nama_kegiatan: c[2],
      capaian: c[3], penyelenggara: c[4], keterangan: null, bukti_id: null, masuk_rapor: true, dicatat_oleh: 'p1', pencatat: 'Ust. Hasan Basri, Lc.', boleh_ubah: true } })
  return DEMO
}

export const usePrestasi = defineStore('prestasi', {
  state: () => ({ boleh: false, hakDimuat: false }),
  actions: {
    async muatHak() {
      if (this.hakDimuat) return this.boleh
      if (MODE_DEMO) { const s = useSesi(); this.boleh = s.isAdmin || s.kelompokSaya.length > 0 }
      else this.boleh = !!(await rpc('boleh_catat_prestasi', { p_santri: null }))
      this.hakDimuat = true; return this.boleh
    },
    /** Daftar prestasi santri yang terlihat; saring rentang tanggal dan/atau satu santri. */
    async daftar({ mulai = null, selesai = null, santri = null } = {}) {
      if (MODE_DEMO) { await useSantri().muat(); return demo().filter((x) => (!santri || x.student_id === santri) && (!mulai || x.tanggal >= mulai) && (!selesai || x.tanggal <= selesai)).map((x) => ({ ...x })) }
      return (await rpc('daftar_prestasi', { p_mulai: mulai, p_selesai: selesai, p_santri: santri })) || []
    },
    async simpan(isi) {
      if (MODE_DEMO) {
        const d = demo()
        if (isi.id) { const x = d.find((y) => y.id === isi.id); Object.assign(x, isi); return isi.id }
        const s = useSantri().cari(isi.student_id) || {}
        const baru = { id: 'pr' + Date.now(), nama: s.nama_lengkap, nis: s.nis, jenis_kelamin: s.jenis_kelamin, jenjang: s.jenjang,
          kelas: (s.kelompok || []).find((k) => k.jenis === 'kelas')?.nama || '', tanggal: hariIniISO(), masuk_rapor: true, pencatat: useSesi().pengguna?.nama_lengkap, boleh_ubah: true, ...isi }
        d.unshift(baru); return baru.id
      }
      return await rpc('simpan_prestasi', { p: isi })
    },
    async hapus(id) {
      if (MODE_DEMO) { DEMO = demo().filter((x) => x.id !== id); return }
      await rpc('hapus_prestasi', { p_id: id })
    },
  },
})
