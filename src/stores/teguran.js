// SIMKA PRO | src/stores/teguran.js | v1.0 | 14.1.0: Surat Teguran SP1–SP3 (usul, batal, terima, cabut, ketentuan, rekap) | 17/10/2026
// Toko Surat Teguran. Semua hak diperiksa server (hak_teguran, boleh_usul_teguran, RLS employee_warnings);
// suratnya adalah surat keluar biasa di Persuratan (diperiksa TU, ditandatangani Direktur, nomor IZ).
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'
import { hariIniISO } from '@/lib/tanggal'
import { tambahHari } from '@/lib/persuratan'

const rpc = async (nama, arg) => { const { data, error } = await supabase.rpc(nama, arg); if (error) throw new Error(pesanGalat(error)); return data }
export const HAK_TEGURAN_KOSONG = { lihat: false, usul: false, kelola: false, tu: false, atasan: false, punya: false }
export const SET_BAWAAN = {
  masa_bulan: { 1: 6, 2: 6, 3: 6 }, penanda: { 1: null, 2: null, 3: null },
  kategori: ['Tidak hadir tanpa keterangan', 'Terlambat berulang kali', 'Tidak mengisi jurnal harian atau jurnal mengajar',
    'Tidak melaksanakan tugas yang diberikan', 'Melanggar tata tertib dan adab pondok', 'Lainnya'],
  harapan: 'segera memperbaiki kedisiplinan dan kinerjanya serta menaati tata tertib yang berlaku',
  tembusan: ['Ketua Yayasan', 'Kepala {bidang}', 'Arsip'],
}

// ---------------------------------------------------------------------------------------------- mode demo
let DEMO = null
const hari = (n) => tambahHari(hariIniISO(), n)
function demo() {
  if (DEMO) return DEMO
  const p = (id, nama, niy, jk, unit, bidang, jabatan) => ({ id, nama, niy, jenis_kelamin: jk, unit, bidang, jabatan })
  const PEG = [
    p('d-pg', 'Ust. Hasan Basri, Lc.', '2019070101', 'L', 'Bidang Tahfizh', 'Bidang Tahfizh', 'Muhaffizh, Wali kelas'),
    p('e-syam', 'Ust. Syamsul Arifin, S.Pd.', '2021071503', 'L', 'Bidang Kesetaraan Wustha', 'Bidang Kesetaraan Wustha', 'Guru mapel'),
    p('e-ikh', 'Ust. Ilham Saputra, S.Sos.', '2022010204', 'L', 'Bidang Media', 'Bidang Media', 'Petugas media'),
    p('e-nur', 'Ustzh. Nurul Aini, S.Pd.', '2020071502', 'P', 'Bidang Kesetaraan Wustha', 'Bidang Kesetaraan Wustha', 'Guru mapel, Wali kelas'),
    p('e-rif', 'Ust. Rifqi Maulana', '2023080105', 'L', 'Unit Security', 'Bidang Kesantrian', 'Petugas keamanan (security)'),
  ]
  const w = (o) => ({ periode_mulai: null, periode_selesai: null, ringkasan_presensi: null, diterima_pada: null, dicabut_pada: null, alasan: null,
    diusulkan_oleh: 'e-thf', pengusul: 'Ust. Hamzah Ridwan, Lc.', saya_pengusul: false, ...o })
  const isi = (id) => PEG.find((x) => x.id === id)
  const daftar = [
    w({ id: 'sp-1', employee_id: 'd-pg', ...pick(isi('d-pg')), tingkat: 1, kategori: ['Terlambat berulang kali', 'Tidak mengisi jurnal harian atau jurnal mengajar'],
      uraian: 'Terlambat hadir di halaqah subuh lebih dari lima kali dalam sebulan dan tidak mengisi jurnal harian selama dua pekan.',
      letter_id: 'sk-sp1', status_surat: 'terbit', status: 'terbit', keadaan: 'aktif', nomor: 'D.004/IZ/PPTQ-IAS/IV/1448', tanggal_surat: hari(-20),
      berlaku_mulai: hari(-20), berlaku_sampai: tambahHari(hari(-20), 181), diusulkan_pada: new Date(Date.now() - 22 * 864e5).toISOString() }),
    w({ id: 'sp-2', employee_id: 'e-syam', ...pick(isi('e-syam')), tingkat: 2, kategori: ['Tidak hadir tanpa keterangan'],
      uraian: 'Tidak hadir mengajar tanpa pemberitahuan sebanyak empat kali setelah menerima SP-1.',
      ringkasan_presensi: { mulai: hari(-30), selesai: hari(-1), sesi: 22, hadir: 16, terlambat: 2, menit_terlambat: 25, tanpa_keterangan: 4, izin_sakit_cuti: 2, pulang_cepat: 0, tidak_presensi_pulang: 1 },
      periode_mulai: hari(-30), periode_selesai: hari(-1), diusulkan_oleh: 'e-kst', pengusul: 'Ust. Muhammad Ikhsan, S.Pd.I.',
      letter_id: null, status_surat: 'diperiksa', status: 'diusulkan', keadaan: 'diusulkan', nomor: null, tanggal_surat: null, berlaku_mulai: null, berlaku_sampai: null,
      diusulkan_pada: new Date(Date.now() - 2 * 36e5).toISOString() }),
    w({ id: 'sp-3', employee_id: 'e-ikh', ...pick(isi('e-ikh')), tingkat: 1, kategori: ['Tidak melaksanakan tugas yang diberikan'],
      uraian: 'Tidak menyelesaikan dokumentasi kegiatan pondok yang ditugaskan.', letter_id: null, status_surat: 'terbit', status: 'terbit', keadaan: 'berakhir',
      nomor: 'D.019/IZ/PPTQ-IAS/IX/1447', tanggal_surat: hari(-230), berlaku_mulai: hari(-230), berlaku_sampai: hari(-50), diterima_pada: new Date(Date.now() - 228 * 864e5).toISOString(),
      diusulkan_pada: new Date(Date.now() - 232 * 864e5).toISOString() }),
    w({ id: 'sp-4', employee_id: 'e-rif', ...pick(isi('e-rif')), tingkat: 1, kategori: ['Melanggar tata tertib dan adab pondok'],
      uraian: 'Meninggalkan pos jaga tanpa pengganti pada shift malam.', letter_id: null, status_surat: 'terbit', status: 'dicabut', keadaan: 'dicabut',
      nomor: 'D.011/IZ/PPTQ-IAS/II/1448', tanggal_surat: hari(-90), berlaku_mulai: hari(-90), berlaku_sampai: hari(90), diterima_pada: new Date(Date.now() - 88 * 864e5).toISOString(),
      dicabut_pada: new Date(Date.now() - 10 * 864e5).toISOString(), alasan: 'Kinerja membaik dan telah mengikuti pembinaan.', diusulkan_pada: new Date(Date.now() - 92 * 864e5).toISOString() }),
  ]
  DEMO = { PEG, daftar, set: JSON.parse(JSON.stringify(SET_BAWAAN)) }
  return DEMO
}
function pick(p) { return { nama: p.nama, niy: p.niy, jenis_kelamin: p.jenis_kelamin, unit: p.unit, bidang: p.bidang, jabatan: p.jabatan } }
const sayaDemo = () => ({ superadmin: 'e-dir', admin: 'e-tu', pegawai: 'd-pg' }[useSesi().peran] || 'd-pg')

// ---------------------------------------------------------------------------------------------- toko
export const useTeguran = defineStore('teguran', {
  state: () => ({ set: null, pegawai: [] }),
  actions: {
    hakDemo() {
      const p = useSesi().peran
      return { lihat: p !== 'pegawai', usul: p !== 'pegawai', kelola: p === 'superadmin', tu: p === 'admin', atasan: p === 'superadmin', punya: true }
    },
    async daftar(mulai = null, selesai = null, pegawai = null) {
      if (MODE_DEMO) {
        const saya = sayaDemo(); const peran = useSesi().peran
        return demo().daftar.filter((x) => (!pegawai || x.employee_id === pegawai) && (peran !== 'pegawai' || (x.employee_id === saya && ['terbit', 'dicabut'].includes(x.status))))
          .map((x) => ({ ...x, saya_penerima: x.employee_id === saya, saya_pengusul: x.diusulkan_oleh === saya }))
      }
      return (await rpc('daftar_teguran', { p_mulai: mulai, p_selesai: selesai, p_emp: pegawai })) || []
    },
    async saya() {
      if (MODE_DEMO) { const s = sayaDemo(); return demo().daftar.filter((x) => x.employee_id === s && ['terbit', 'dicabut'].includes(x.status)).map((x) => ({ ...x, saya_penerima: true })) }
      return (await rpc('teguran_saya')) || []
    },
    async muatPegawai() {
      if (MODE_DEMO) {
        const D = demo()
        this.pegawai = D.PEG.filter((x) => x.id !== sayaDemo()).map((x) => ({ ...x, sp_aktif: D.daftar.filter((w) => w.employee_id === x.id && w.keadaan === 'aktif').reduce((a, w) => Math.max(a, w.tingkat), 0) || null,
          diusulkan: D.daftar.some((w) => w.employee_id === x.id && w.status === 'diusulkan') }))
      } else this.pegawai = (await rpc('pegawai_untuk_teguran')) || []
      return this.pegawai
    },
    async saran(emp) {
      if (MODE_DEMO) {
        const a = demo().daftar.filter((w) => w.employee_id === emp && w.keadaan === 'aktif')
        const maks = a.reduce((m, w) => Math.max(m, w.tingkat), 0)
        return { saran: Math.min(maks + 1, 3), sp3_aktif: maks === 3, diusulkan: demo().daftar.some((w) => w.employee_id === emp && w.status === 'diusulkan'),
          aktif: a.map((w) => ({ id: w.id, tingkat: w.tingkat, nomor: w.nomor, tanggal_surat: w.tanggal_surat, berlaku_sampai: w.berlaku_sampai })), riwayat: a.length }
      }
      return rpc('saran_teguran', { p_emp: emp })
    },
    async ringkasanPresensi(emp, mulai, selesai) {
      if (MODE_DEMO) return { mulai, selesai, sesi: 20, hadir: 15, terlambat: 4, menit_terlambat: 52, tanpa_keterangan: 3, izin_sakit_cuti: 2, pulang_cepat: 1, tidak_presensi_pulang: 0 }
      return rpc('ringkasan_presensi_teguran', { p_emp: emp, p_mulai: mulai, p_selesai: selesai })
    },
    async usul(p) {
      if (MODE_DEMO) {
        const D = demo(); const e = D.PEG.find((x) => x.id === p.employee_id)
        D.daftar.unshift({ id: 'sp-' + Date.now(), employee_id: e.id, ...pick(e), tingkat: p.tingkat, kategori: p.kategori, uraian: p.uraian, periode_mulai: p.periode_mulai || null,
          periode_selesai: p.periode_selesai || null, ringkasan_presensi: null, diusulkan_oleh: sayaDemo(), pengusul: useSesi().pengguna?.nama_lengkap, saya_pengusul: true,
          diusulkan_pada: new Date().toISOString(), letter_id: null, status_surat: 'diperiksa', status: 'diusulkan', keadaan: 'diusulkan', nomor: null, tanggal_surat: null,
          berlaku_mulai: null, berlaku_sampai: null, diterima_pada: null, dicabut_pada: null, alasan: null })
        return D.daftar[0].id
      }
      return rpc('usul_teguran', { p })
    },
    async batal(id, alasan) {
      if (MODE_DEMO) { Object.assign(demo().daftar.find((x) => x.id === id), { status: 'batal', keadaan: 'batal', status_surat: 'dibatalkan', alasan }); return }
      return rpc('batal_teguran', { p_id: id, p_alasan: alasan })
    },
    async terima(id) {
      if (MODE_DEMO) { Object.assign(demo().daftar.find((x) => x.id === id), { diterima_pada: new Date().toISOString() }); return }
      return rpc('terima_teguran', { p_id: id })
    },
    async cabut(id, alasan) {
      if (MODE_DEMO) { Object.assign(demo().daftar.find((x) => x.id === id), { status: 'dicabut', keadaan: 'dicabut', alasan, dicabut_pada: new Date().toISOString() }); return }
      return rpc('cabut_teguran', { p_id: id, p_alasan: alasan })
    },
    async muatSet() {
      this.set = MODE_DEMO ? { ...demo().set, boleh_ubah: useSesi().peran === 'superadmin' } : await rpc('pengaturan_teguran')
      return this.set
    },
    async simpanSet(p) {
      if (MODE_DEMO) { Object.assign(demo().set, p); this.set = { ...demo().set, boleh_ubah: true }; return this.set }
      this.set = await rpc('simpan_pengaturan_teguran', { p }); return this.set
    },
    /** Penanda SP aktif: { employee_id: tingkat } (baris gaji, data pegawai). */
    async spAktif() {
      if (MODE_DEMO) return Object.fromEntries(demo().daftar.filter((x) => x.keadaan === 'aktif').map((x) => [x.employee_id, x.tingkat]))
      try { return (await rpc('sp_aktif_pegawai')) || {} } catch { return {} }
    },
  },
})
