// SIMKA PRO | src/stores/kartu.js | v1.1 | Fase 3 – Perbaikan P4 (kartu pegawai portrait) | 04/10/2026
// Kartu pegawai: data kartu (kode QR dibuat otomatis), ganti kode, pas foto, dan verifikasi publik.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'
import { unggahSupabase, kompresGambar } from '@/lib/penyimpanan'

const rpc = async (nama, arg) => { const { data, error } = await supabase.rpc(nama, arg); if (error) throw new Error(pesanGalat(error)); return data }
const DEMO = [
  ['Ust. Hasan Basri, Lc.', '2019070101', 'L', 'Muhaffizh/Muhaffizhah, Wali kelas', 'Bidang Tahfizh', 'H7KQ2M9XAP'],
  ['Ustzh. Nurul Aini, S.Pd.', '2020011502', 'P', 'Guru mata pelajaran, Wali kelas', 'Bidang Kesetaraan Wustha', 'N4TZ8QWE2R'],
  ['Ust. Muhammad Ikhsan, S.Pd.I.', '2018080303', 'L', 'Wakil Direktur, Musyrif/Musyrifah', 'Bidang Kesantrian', 'M2PL6VBX9C'],
  ['Ust. Abdul Hakim', '2021030104', 'L', 'Petugas keamanan (security)', 'Unit Security', 'A8JH3KD5SF'],
  ['Ustzh. Fatimah Az-Zahra, A.Md.Kep.', '2022070105', 'P', 'Petugas kesehatan (medis)', 'Unit Klinik', 'F6GT4YH2ND'],
]
const demo = (id, i) => { const d = DEMO[i % DEMO.length]; return { employee_id: id, nama: d[0], niy: d[1], jenis_kelamin: d[2], jabatan: d[3], jabatan_kartu: d[3].split(',')[0], unit: d[4], foto_id: null, kode: d[5], aktif: true } }

export const useKartu = defineStore('kartu', {
  actions: {
    async data(ids = null) {
      if (MODE_DEMO) return ids ? ids.map((id, i) => demo(id, i)) : [demo(useSesi().pengguna?.id, 0)]
      return (await rpc('data_kartu', { p_emps: ids })) || []
    },
    async gantiKode(emp) { if (MODE_DEMO) return 'Z9Y8X7W6V5'; return await rpc('ganti_kode_kartu', { p_emp: emp }) },
    async pasangFoto(emp, file) {
      if (MODE_DEMO) return null
      const blob = await kompresGambar(file, { maks: 600, kualitas: 0.8, rasio: [3, 4] })
      const { id } = await unggahSupabase(blob, { bucket: 'profil', path: `${emp}/foto-${Date.now()}.jpg`, kategori: 'foto_profil' })
      await rpc('pasang_foto', { p_emp: emp, p_obj: id })
      return id
    },
    async cek(kode) {
      if (MODE_DEMO) return kode?.replace(/-/g, '') === 'SALAH' ? { ditemukan: false } : { ditemukan: true, nama: 'Ust. Hasan Basri, Lc.', niy: '2019070101', jabatan: 'Muhaffizh/Muhaffizhah, Wali kelas', unit: 'Bidang Tahfizh', berlaku: true, lembaga: "Pondok Pesantren Tahfizhul Qur'an Imam Asy-Syathiby Wahdah Islamiyah Gowa" }
      return await rpc('cek_kartu', { p_kode: kode })
    },
  },
})
