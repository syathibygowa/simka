// SIMKA PRO | src/stores/bebanKerja.js | v1.0 | Fase 3 – Perbaikan P5 (ekuivalensi jam) | 04/10/2026
// Ekuivalensi jam beban kerja: komponen jam per tupoksi, jam per pegawai, rekap (total, wajib, selisih), dan kunci bulanan.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'

const rpc = async (nama, arg) => { const { data, error } = await supabase.rpc(nama, arg); if (error) throw new Error(pesanGalat(error)); return data }
export const KOLOM_BEBAN = ['Jabatan Struktural', 'Guru Mapel', 'Takhassus', 'Guru Tahfizh', 'Guru Walas', 'Musyrif', 'Fungsional Lainnya', 'Tugas Tambahan Lainnya']

// ---------- Data contoh (mode demo) ----------
const K = (kode, nama, kolom, kelompok, sumber, jam, urutan, tautan = null) => ({ id: 'c-' + kode, kode, nama, kolom, kelompok, sumber, jam_bawaan: jam, urutan, aktif: true, tautan })
const KOMPONEN_DEMO = [
  K('S_WAKIL_KEPALA_SEKOLAH', 'Wakil Kepala Sekolah', 'Jabatan Struktural', 'struktural', 'tetap', 12, 36, 'struktural'),
  K('S_BENDAHARA', 'Bendahara', 'Jabatan Struktural', 'struktural', 'tetap', 14, 25, 'struktural'), K('S_TATA_USAHA', 'Tata Usaha', 'Jabatan Struktural', 'struktural', 'tetap', 18, 50, 'struktural'),
  K('S_KEPALA_BIDANG', 'Kepala Bidang', 'Jabatan Struktural', 'struktural', 'tetap', 12, 30, 'struktural'),
  K('F_GURU', 'Guru mata pelajaran', 'Guru Mapel', 'fungsional', 'per_orang', 0, 101, 'fungsional'), K('F_WALI_KELAS', 'Wali kelas', 'Guru Walas', 'fungsional', 'tetap', 4, 102, 'fungsional'),
  K('F_MUHAFFIZH', 'Muhaffizh/Muhaffizhah', 'Guru Tahfizh', 'fungsional', 'tetap', 24, 103, 'fungsional'), K('F_MUSYRIF', 'Musyrif/Musyrifah', 'Musyrif', 'fungsional', 'tetap', 12, 104, 'fungsional'),
  K('F_OPERATOR', 'Operator', 'Fungsional Lainnya', 'fungsional', 'tetap', 12, 106, 'fungsional'), K('F_SECURITY', 'Petugas keamanan (security)', 'Fungsional Lainnya', 'fungsional', 'tetap', 48, 110, 'fungsional'),
  K('T_TAKHASSUS', 'Pengajar Takhassus', 'Takhassus', 'tambahan', 'per_orang', 0, 200), K('T_KEPALA_LAB', 'Kepala Laboratorium', 'Tugas Tambahan Lainnya', 'tambahan', 'tetap', 12, 210),
  K('T_STAF_KURIKULUM', 'Staf Kurikulum', 'Tugas Tambahan Lainnya', 'tambahan', 'tetap', 6, 220), K('T_STAF_MEDIA', 'Staf Media', 'Tugas Tambahan Lainnya', 'tambahan', 'tetap', 6, 223),
  K('T_LAINNYA', 'Tugas tambahan lainnya', 'Tugas Tambahan Lainnya', 'tambahan', 'per_orang', 0, 299),
]
const r = (kode, jam) => { const c = KOMPONEN_DEMO.find((x) => x.kode === kode); return { component_id: c.id, kode, nama: c.nama, kolom: c.kolom, kelompok: c.kelompok, sumber: c.sumber, jam, jam_bawaan: c.jam_bawaan, otomatis: !!c.tautan, ditimpa: false } }
const PEG = [
  ['d-pg', 'Ust. Hasan Basri, Lc.', 'tetap', 'Bidang Tahfizh', [r('F_GURU', 18), r('F_MUHAFFIZH', 24), r('F_WALI_KELAS', 4)]],
  ['p2', 'Ustzh. Nurul Aini, S.Pd.', 'tetap', 'Bidang Kesetaraan Wustha', [r('S_WAKIL_KEPALA_SEKOLAH', 12), r('F_GURU', 20), r('F_WALI_KELAS', 4), r('T_STAF_KURIKULUM', 6)]],
  ['p3', 'Ust. Muhammad Ikhsan, S.Pd.I.', 'tetap', 'Bidang Kesantrian', [r('S_KEPALA_BIDANG', 12), r('F_GURU', 6), r('F_MUSYRIF', 12), r('T_TAKHASSUS', 22)]],
  ['p4', 'Ust. Arief Muharief, S.E.', 'kontrak', 'Bidang Umum', [r('S_BENDAHARA', 14), r('S_TATA_USAHA', 18), r('F_WALI_KELAS', 4), r('T_STAF_MEDIA', 6)]],
  ['p5', 'Ust. Abdul Hakim', 'honorer', 'Unit Security', [r('F_SECURITY', 48)]],
  ['p6', 'Ust. Jumardi, S.Si., M.Si.', 'kontrak', 'Bidang SMA', [r('T_KEPALA_LAB', 12), r('F_GURU', 24), r('F_WALI_KELAS', 4), r('T_STAF_KURIKULUM', 6)]],
]
let RINCIAN_DEMO = null
const rincianDemo = () => (RINCIAN_DEMO ||= Object.fromEntries(PEG.map(([id, , , , d]) => [id, d])))
const WAJIB_DEMO = { tetap: 48, kontrak: 48, honorer: null }

export const useBebanKerja = defineStore('bebanKerja', {
  state: () => ({ komponen: [], wajib: { tetap: 48, kontrak: 48, honorer: null }, memuat: false }),
  getters: {
    bolehAtur: () => useSesi().bolehAdmin('atur_beban_kerja'),
    tambahan: (s) => s.komponen.filter((k) => k.aktif && !k.structural_position_id && !k.functional_position_id && !k.tautan),
  },
  actions: {
    async muatKomponen() {
      if (MODE_DEMO) { if (!this.komponen.length) this.komponen = KOMPONEN_DEMO.map((k) => ({ ...k })); this.wajib = { ...WAJIB_DEMO }; return }
      const [k, w] = await Promise.all([
        supabase.from('workload_components').select('*').order('urutan'),
        supabase.from('institution_settings').select('nilai').eq('kunci', 'beban_kerja').maybeSingle(),
      ])
      if (k.error) throw new Error(pesanGalat(k.error))
      this.komponen = k.data || []
      if (w.data?.nilai?.wajib) this.wajib = w.data.nilai.wajib
    },
    async rekap(unit = null) {
      if (MODE_DEMO) {
        const s = useSesi(); const d = rincianDemo()
        return PEG.filter(([id]) => s.peran !== 'pegawai' || id === s.pengguna?.id).map(([id, nama, status, unitN]) => {
          const total = d[id].reduce((a, b) => a + Number(b.jam), 0); const wajib = WAJIB_DEMO[status]
          return { employee_id: id, nama, niy: '20190701' + id.slice(-1), status, unit: unitN, jabatan: d[id].map((x) => x.nama).join(', '), jam_wajib: wajib, total, selisih: wajib == null ? null : total - wajib,
            rincian: d[id].filter((x) => x.jam > 0).map((x) => ({ nama: x.nama, kolom: x.kolom, kelompok: x.kelompok, jam: x.jam })) }
        })
      }
      return (await rpc('beban_kerja_rekap', { p_unit: unit })) || []
    },
    async rincian(emp) {
      if (MODE_DEMO) return (rincianDemo()[emp] || []).map((x) => ({ ...x }))
      return (await rpc('rincian_beban', { p_emp: emp })) || []
    },
    async simpanPegawai(emp, baris) {
      if (MODE_DEMO) { rincianDemo()[emp] = baris.map((b) => { const c = this.komponen.find((k) => k.id === b.component_id); return { ...b, nama: c.nama, kolom: c.kolom, kelompok: c.kelompok, sumber: c.sumber, otomatis: !!c.tautan } }); return }
      await rpc('simpan_beban_pegawai', { p_emp: emp, p_rincian: baris.map((b) => ({ component_id: b.component_id, jam: b.jam, catatan: b.catatan || null })) })
    },
    async simpanKomponen(k) {
      const isi = { kode: k.kode, nama: k.nama.trim(), kolom: k.kolom, kelompok: k.kelompok || 'tambahan', sumber: k.sumber, jam_bawaan: Number(k.jam_bawaan) || 0, keterangan: k.keterangan || null, aktif: k.aktif !== false, urutan: Number(k.urutan) || 0 }
      if (MODE_DEMO) { const i = this.komponen.findIndex((x) => x.id === k.id); if (i >= 0) Object.assign(this.komponen[i], isi); else this.komponen.push({ ...isi, id: 'c' + Date.now() }); return }
      const { error } = k.id ? await supabase.from('workload_components').update(isi).eq('id', k.id) : await supabase.from('workload_components').insert(isi)
      if (error) throw new Error(error.code === '23505' ? 'Kode komponen sudah dipakai.' : pesanGalat(error))
      await this.muatKomponen()
    },
    async aturWajib(w) {
      if (!MODE_DEMO) await rpc('atur_jam_wajib', { p: w })
      this.wajib = { tetap: w.tetap === '' ? null : Number(w.tetap), kontrak: w.kontrak === '' ? null : Number(w.kontrak), honorer: w.honorer === '' || w.honorer == null ? null : Number(w.honorer) }
    },
    async kunci(periode) { if (MODE_DEMO) return 6; return await rpc('kunci_beban_kerja', { p_periode: periode }) },
    async salinan(periode) {
      if (MODE_DEMO) return (await this.rekap()).map((x) => ({ ...x, dikunci_pada: new Date().toISOString() }))
      const { data, error } = await supabase.from('workload_snapshots').select('*, employees(nama_lengkap, niy, org_units(nama))').eq('periode', periode)
      if (error) throw new Error(pesanGalat(error))
      return (data || []).map((x) => ({ ...x, nama: x.employees?.nama_lengkap, niy: x.employees?.niy, unit: x.employees?.org_units?.nama }))
    },
  },
})
