// SIMKA PRO | src/stores/tahfizh.js | v1.0 | Fase 5 – Tahap 1 Pengaturan tahfizh dan data hafalan awal | 05/10/2026
// Tahfizh: hak pengguna, pengaturan per tahun ajaran (KKM, bobot, target, predikat, pekan efektif), penguji,
// daftar santri beserta program, posisi hafalan, dan capaian juz resmi. Penulisan hanya lewat fungsi SQL.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { dataTahfizhDemo, isiSantriDemo } from '@/lib/demoTahfizh'
import { PEGAWAI_DEMO } from '@/lib/demo'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'
import { useSantri } from './santri'
import { useKelompokSantri } from './kelompokSantri'

const rpc = async (nama, arg) => { const { data, error } = await supabase.rpc(nama, arg); if (error) throw new Error(pesanGalat(error)); return data }
const HAK_KOSONG = { atur: false, validasi: false, pimpinan: false, muhaffizh: false, penguji_kenaikan: false, penguji_sertifikasi: false, lihat: false }

export const useTahfizh = defineStore('tahfizh', {
  state: () => ({
    hak: { ...HAK_KOSONG }, hakDimuat: false,
    taId: '', pengaturan: null, predikat: [], target: [], bulan: [], penguji: { kenaikan: [], sertifikasi: [] },
    santri: [], memuat: false, galat: '',
  }),
  getters: {
    targetUntuk: (s) => (program, tingkat) => s.target.find((t) => t.program === program && t.tingkat === Number(tingkat)) || null,
    pekanSemester: (s) => (smt) => s.bulan.filter((b) => b.semester === smt).reduce((n, b) => n + Number(b.pekan_efektif || 0), 0),
  },
  actions: {
    async muatHak() {
      const sesi = useSesi()
      if (MODE_DEMO) {
        const p = sesi.peran
        this.hak = p === 'superadmin' ? { ...HAK_KOSONG, atur: true, validasi: true, lihat: true }
          : p === 'admin' ? { ...HAK_KOSONG, atur: sesi.izinAdmin.includes('atur_tahfizh'), validasi: sesi.izinAdmin.includes('validasi_tahfizh'), lihat: true }
            : { ...HAK_KOSONG, muhaffizh: true, lihat: true }
        this.hakDimuat = true; return this.hak
      }
      this.hak = { ...HAK_KOSONG, ...((await rpc('hak_tahfizh')) || {}) }
      this.hakDimuat = true
      return this.hak
    },

    // ---------- Pengaturan ----------
    async muatPengaturan(taId) {
      const kel = useKelompokSantri(); if (!kel.tahunAjaran.length) await kel.muat()
      this.taId = taId || kel.taSekarang?.id || ''
      if (MODE_DEMO) {
        const d = dataTahfizhDemo()
        Object.assign(this, { pengaturan: { ...d.pengaturan }, predikat: d.predikat.map((x) => ({ ...x })), target: d.target.map((x) => ({ ...x })), bulan: d.bulan.map((x) => ({ ...x })) })
        const nama = (id) => PEGAWAI_DEMO.find((p) => p.id === id)
        this.penguji = {
          kenaikan: [{ employee_id: 'p7', nama: nama('p7').nama_lengkap, niy: nama('p7').niy, jabatan: 'Wakil Kepala Bidang', bawaan: true, aktif: true, id: null },
            ...d.penguji.filter((x) => x.jenis === 'kenaikan').map((x) => ({ ...x, nama: nama(x.employee_id)?.nama_lengkap, niy: nama(x.employee_id)?.niy, jabatan: x.catatan || 'Penguji yang ditunjuk', bawaan: false }))],
          sertifikasi: [{ employee_id: 'pd', nama: 'Siswandi Safari, S.Pd.I., Lc., S.H., M.Ag.', niy: '1983020910201401', jabatan: 'Direktur (Mudir)', bawaan: true, aktif: true, id: null },
            ...d.penguji.filter((x) => x.jenis === 'sertifikasi').map((x) => ({ ...x, nama: nama(x.employee_id)?.nama_lengkap, niy: nama(x.employee_id)?.niy, jabatan: x.catatan || 'Penguji yang ditunjuk', bawaan: false }))],
        }
        return
      }
      if (!this.taId) return
      const [s, p, t, b, k1, k2] = await Promise.all([
        supabase.from('tahfizh_settings').select('*').eq('academic_year_id', this.taId).maybeSingle(),
        supabase.from('predicate_ranges').select('*').eq('academic_year_id', this.taId).order('urutan'),
        supabase.from('tahfizh_targets').select('*').eq('academic_year_id', this.taId).order('program').order('tingkat'),
        supabase.from('tahfizh_months').select('*').eq('academic_year_id', this.taId).order('bulan'),
        supabase.rpc('penguji_tahfizh', { p_jenis: 'kenaikan' }),
        supabase.rpc('penguji_tahfizh', { p_jenis: 'sertifikasi' }),
      ])
      for (const r of [s, p, t, b, k1, k2]) if (r.error) throw new Error(pesanGalat(r.error))
      this.pengaturan = s.data
      this.predikat = p.data.map((x) => ({ ...x, nilai_min: Number(x.nilai_min), nilai_maks: Number(x.nilai_maks) }))
      this.target = t.data; this.bulan = b.data
      this.penguji = { kenaikan: k1.data || [], sertifikasi: k2.data || [] }
    },
    async simpanPengaturan(isi) {
      if (MODE_DEMO) {
        const d = dataTahfizhDemo()
        if (isi.umum) Object.assign(d.pengaturan, isi.umum)
        if (isi.predikat) d.predikat = isi.predikat.map((x, i) => ({ ...x, id: 'pr' + i, urutan: i + 1 }))
        if (isi.target) isi.target.forEach((x) => Object.assign(d.target.find((t) => t.program === x.program && t.tingkat === x.tingkat), x))
        if (isi.bulan) isi.bulan.forEach((x) => { const b = d.bulan.find((y) => y.bulan === x.bulan); Object.assign(b, x); if (!x.manual) b.pekan_efektif = Math.min(5, Math.floor(b.hari_aktif / 6)) })
        return this.muatPengaturan(this.taId)
      }
      await rpc('simpan_pengaturan_tahfizh', { p_ta: this.taId, p: isi })
      await this.muatPengaturan(this.taId)
    },
    async simpanPenguji(jenis, employeeId, aktif = true, catatan = '') {
      if (MODE_DEMO) {
        const d = dataTahfizhDemo(); const ada = d.penguji.find((x) => x.jenis === jenis && x.employee_id === employeeId)
        if (ada) Object.assign(ada, { aktif, catatan }); else d.penguji.push({ id: 'x' + Date.now(), jenis, employee_id: employeeId, aktif, catatan })
        return this.muatPengaturan(this.taId)
      }
      await rpc('simpan_penguji', { p_jenis: jenis, p_employee: employeeId, p_aktif: aktif, p_catatan: catatan || null })
      await this.muatPengaturan(this.taId)
    },
    async hapusPenguji(id) {
      if (MODE_DEMO) { const d = dataTahfizhDemo(); d.penguji = d.penguji.filter((x) => x.id !== id); return this.muatPengaturan(this.taId) }
      await rpc('hapus_penguji', { p_id: id }); await this.muatPengaturan(this.taId)
    },

    // ---------- Santri ----------
    async muatSantri() {
      this.memuat = true; this.galat = ''
      try {
        if (MODE_DEMO) {
          const san = useSantri(); const kel = useKelompokSantri(); await san.muat(); await kel.muat()
          const aktif = san.daftar.filter((s) => ['aktif', 'nonaktif'].includes(s.status))
          const d = isiSantriDemo(aktif)
          const terlihat = useSesi().peran === 'pegawai' ? aktif.filter((s) => (s.kelompok || []).some((k) => k.id === 'g-hhb')) : aktif
          this.santri = terlihat.map((s) => {
            const t = d.santri[s.id] || {}; const j = d.juz[s.id] || []
            const hq = (s.kelompok || []).find((k) => k.jenis === 'halaqah'); const kl = (s.kelompok || []).find((k) => k.jenis === 'kelas')
            return { student_id: s.id, nis: s.nis, nama: s.nama_lengkap, jenis_kelamin: s.jenis_kelamin, jenjang: s.jenjang, tingkat: s.tingkat, status: s.status,
              kelas: kl?.nama || null, halaqah_id: hq?.id || null, halaqah: hq?.nama || null, program: t.program || 'reguler',
              sabaq_hal: t.sabaq_hal || 0, sabqi_hal: t.sabqi_hal || 0, manzil_hal: t.manzil_hal || 0, juz_sedang: t.juz_sedang || null,
              posisi_pada: t.posisi_pada || null, posisi_sumber: t.posisi_sumber || null,
              juz_resmi: j.map((x) => x.juz).sort((a, b) => a - b), juz_awal: j.filter((x) => x.sumber === 'awal').map((x) => x.juz).sort((a, b) => a - b), total_resmi: j.length }
          })
          return
        }
        this.santri = (await rpc('daftar_tahfizh', { p_group: null })) || []
      } catch (e) { this.galat = e.message || 'Data tahfizh gagal dimuat.' } finally { this.memuat = false }
    },
    cariSantri(id) { return this.santri.find((s) => s.student_id === id) },
    async aturProgram(ids, program) {
      if (MODE_DEMO) { const d = dataTahfizhDemo(); ids.forEach((id) => { d.santri[id] = { ...(d.santri[id] || {}), program } }); await this.muatSantri(); return ids.length }
      const n = await rpc('atur_program_tahfizh', { p_santri: ids, p_program: program }); await this.muatSantri(); return n
    },
    async simpanHafalanAwal(id, isi) {
      if (MODE_DEMO) {
        const d = dataTahfizhDemo(); const lama = d.juz[id] || []
        d.santri[id] = { ...(d.santri[id] || {}), ...isi, posisi_pada: new Date().toISOString(), posisi_sumber: 'awal' }; delete d.santri[id].juz
        if (isi.juz) { const tetap = lama.filter((x) => x.sumber !== 'awal'); d.juz[id] = [...tetap, ...isi.juz.filter((j) => !tetap.some((x) => x.juz === j)).map((j) => ({ juz: j, sumber: 'awal' }))] }
        await this.muatSantri(); return
      }
      await rpc('simpan_hafalan_awal', { p_santri: id, p: isi }); await this.muatSantri()
    },
    async imporHafalanAwal(baris) {
      if (MODE_DEMO) return baris.map((b, i) => ({ baris: i + 1, ok: false, pesan: 'Mode demo: impor tidak disimpan.' }))
      const h = await rpc('impor_hafalan_awal', { p_baris: baris }); await this.muatSantri(); return h
    },
  },
})
