// SIMKA PRO | src/stores/penilaian.js | v1.0 | Fase 12 – Tahap 1 Pengaturan penilaian | 13/10/2026
// Penilaian dan rapor: pengaturan per tahun ajaran (ketentuan per jenis rapor, predikat, komponen dan bobot, periode,
// mapel rapor beserta sumber nilainya, bank kalimat catatan) dan hak pengguna. Penulisan hanya lewat fungsi SQL.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { dataPenilaianDemo, idDemo } from '@/lib/demoPenilaian'
import { dataJadwalDemo } from '@/lib/demoJadwal'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'

const rpc = async (nama, arg) => { const { data, error } = await supabase.rpc(nama, arg); if (error) throw new Error(pesanGalat(error)); return data }
const HAK_KOSONG = { atur: { sma: false, wustha: false, tahfizh: false }, atur_umum: false, kelola: false, pimpinan: [], menu: false }
const salin = (x) => JSON.parse(JSON.stringify(x))

export const usePenilaian = defineStore('penilaian', {
  state: () => ({ taId: '', ta: null, ketentuan: {}, predikat: [], kategori: [], periode: [], mapel: [], kalimat: [], hak: { ...HAK_KOSONG }, memuat: false, dimuat: false }),
  getters: {
    predikatKelompok: (s) => (k) => s.predikat.filter((p) => p.kelompok === k).sort((a, b) => a.urutan - b.urutan),
    kategoriJenis: (s) => (j) => s.kategori.filter((c) => c.jenis === j).sort((a, b) => a.urutan - b.urutan),
    mapelTingkat: (s) => (j, t) => s.mapel.filter((m) => m.jenis === j && m.tingkat === Number(t)).sort((a, b) => a.urutan - b.urutan),
    bolehAtur: (s) => (j) => !!(j ? s.hak.atur?.[j] : s.hak.atur_umum || s.hak.atur?.sma || s.hak.atur?.wustha || s.hak.atur?.tahfizh),
    terkunci: (s) => !!s.ta?.terkunci,
  },
  actions: {
    hakDemo() {
      const sesi = useSesi(); const p = sesi.peran
      const semua = p === 'superadmin' || (p === 'admin' && sesi.izinAdmin.includes('atur_penilaian'))
      return { atur: { sma: semua, wustha: semua, tahfizh: semua }, atur_umum: semua, kelola: semua, pimpinan: [], menu: p !== 'pegawai' }
    },
    async muat(taId) {
      this.memuat = true
      try {
        if (MODE_DEMO) {
          const d = dataPenilaianDemo()
          Object.assign(this, salin({ ta: d.ta, ketentuan: d.ketentuan, predikat: d.predikat, kategori: d.kategori, periode: d.periode, mapel: d.mapel, kalimat: d.kalimat }))
          this.taId = d.ta.id; this.hak = this.hakDemo(); return
        }
        const d = await rpc('pengaturan_penilaian', { p_ta: taId || this.taId || null })
        if (!d) { this.ta = null; return }
        this.taId = d.ta.id; this.ta = d.ta; this.ketentuan = d.ketentuan || {}; this.predikat = d.predikat || []; this.kategori = d.kategori || []
        this.periode = d.periode || []; this.mapel = d.mapel || []; this.kalimat = d.kalimat || []; this.hak = { ...HAK_KOSONG, ...(d.hak || {}) }
      } finally { this.memuat = false; this.dimuat = true }
    },

    async simpanKetentuan(jenis, isi) {
      if (MODE_DEMO) { Object.assign(dataPenilaianDemo().ketentuan[jenis], isi); return this.muat() }
      await rpc('simpan_ketentuan_rapor', { p_ta: this.taId, p_jenis: jenis, p: isi }); await this.muat(this.taId)
    },
    async simpanPredikat(kelompok, daftar) {
      if (MODE_DEMO) {
        const d = dataPenilaianDemo()
        d.predikat = [...d.predikat.filter((p) => p.kelompok !== kelompok), ...daftar.map((p, i) => ({ ...p, id: idDemo('pr'), kelompok, huruf: String(p.huruf).toUpperCase(), urutan: i + 1 }))]
        return this.muat()
      }
      await rpc('simpan_predikat_rapor', { p_ta: this.taId, p_kelompok: kelompok, p: daftar }); await this.muat(this.taId)
    },
    async simpanKomponen(jenis, daftar) {
      if (MODE_DEMO) {
        const d = dataPenilaianDemo()
        d.kategori = [...d.kategori.filter((c) => c.jenis !== jenis), ...daftar.map((c, i) => ({ ...c, id: c.id || idDemo('gc'), jenis, kode: c.kode || String(c.nama).toUpperCase().replace(/[^A-Z0-9]+/g, '_').slice(0, 20), urutan: i + 1, aktif: c.aktif !== false }))]
        return this.muat()
      }
      await rpc('simpan_komponen_nilai', { p_ta: this.taId, p_jenis: jenis, p: daftar }); await this.muat(this.taId)
    },
    async simpanPeriode(id, isi) {
      if (MODE_DEMO) { Object.assign(dataPenilaianDemo().periode.find((p) => p.id === id), isi, { pengubah: useSesi().pengguna?.nama_lengkap }); return this.muat() }
      await rpc('simpan_periode_nilai', { p_id: id, p: isi }); await this.muat(this.taId)
    },

    // ---------- Mapel rapor ----------
    async simpanMapel(isi) {
      if (MODE_DEMO) {
        const d = dataPenilaianDemo(); const mp = dataJadwalDemo().mapel
        const sumber_mapel = isi.sumber === 'mapel' ? (isi.sumber_mapel || []).map((x) => { const m = mp.find((y) => y.id === x.subject_id); return { subject_id: x.subject_id, kode: m?.kode, nama: m?.nama, jenjang: m?.jenjang, aktif: true, bobot: (isi.sumber_mapel.length === 1 ? 100 : Number(x.bobot)) } }) : []
        if (isi.id) Object.assign(d.mapel.find((m) => m.id === isi.id), isi, { sumber_mapel })
        else {
          const urut = d.mapel.filter((m) => m.jenis === isi.jenis && m.tingkat === isi.tingkat).length + 1
          d.mapel.push({ academic_year_id: d.ta.id, aktif: true, mode_nilai: null, catatan: null, pengampu: 0, ...isi, id: idDemo('rs'), urutan: urut, sumber_mapel })
        }
        return this.muat()
      }
      const id = await rpc('simpan_mapel_rapor', { p: { ...isi, academic_year_id: this.taId } }); await this.muat(this.taId); return id
    },
    async hapusMapel(id) {
      if (MODE_DEMO) { const d = dataPenilaianDemo(); d.mapel = d.mapel.filter((m) => m.id !== id); return this.muat() }
      await rpc('hapus_mapel_rapor', { p_id: id }); await this.muat(this.taId)
    },
    async urutkanMapel(ids) {
      if (MODE_DEMO) { const d = dataPenilaianDemo(); ids.forEach((id, i) => { d.mapel.find((m) => m.id === id).urutan = i + 1 }); return this.muat() }
      await rpc('urutkan_mapel_rapor', { p_ids: ids }); await this.muat(this.taId)
    },
    async salinMapel(jenis, dari, ke, timpa) {
      if (MODE_DEMO) {
        const d = dataPenilaianDemo(); let n = 0
        for (const t of ke) {
          if (timpa) d.mapel = d.mapel.filter((m) => !(m.jenis === jenis && m.tingkat === t))
          for (const m of d.mapel.filter((x) => x.jenis === jenis && x.tingkat === dari)) {
            if (d.mapel.some((x) => x.jenis === jenis && x.tingkat === t && x.nama === m.nama)) continue
            d.mapel.push({ ...salin(m), id: idDemo('rs'), tingkat: t }); n++
          }
        }
        await this.muat(); return n
      }
      const n = await rpc('salin_mapel_rapor', { p_ta: this.taId, p_jenis: jenis, p_dari: dari, p_ke: ke, p_timpa: !!timpa }); await this.muat(this.taId); return n
    },

    // ---------- Bank kalimat ----------
    async simpanKalimat(isi) {
      if (MODE_DEMO) {
        const d = dataPenilaianDemo()
        if (isi.id) Object.assign(d.kalimat.find((k) => k.id === isi.id), isi); else d.kalimat.push({ aktif: true, urutan: 99, ...isi, id: idDemo('kl') })
        return this.muat()
      }
      await rpc('simpan_kalimat_rapor', { p: isi }); await this.muat(this.taId)
    },
    async hapusKalimat(id) {
      if (MODE_DEMO) { const d = dataPenilaianDemo(); d.kalimat = d.kalimat.filter((k) => k.id !== id); return this.muat() }
      await rpc('hapus_kalimat_rapor', { p_id: id }); await this.muat(this.taId)
    },
  },
})
