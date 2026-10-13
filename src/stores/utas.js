// SIMKA PRO | src/stores/utas.js | v1.1 | Fase 12 – Tahap 4 UTAS per kelas atau per halaqah | 13/10/2026
// v1.1: aturMode (pembagian per kelas/halaqah per semester; muhaffizh tidak menguji halaqahnya sendiri).
// Ujian Tahfizh Akhir Semester (UTAS): penguji per kelas/halaqah, pembagian peserta, juz diujikan (otomatis menurut SOP), nilai
// Tajwid/Itqan, nilai akhir, predikat, dan status draf/final. Penulisan hanya lewat fungsi SQL.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { dataKelompokDemo } from '@/lib/demoKelompok'
import { dataTahfizhDemo, isiSantriDemo } from '@/lib/demoTahfizh'
import { dataPenilaianDemo } from '@/lib/demoPenilaian'
import { PEGAWAI_DEMO } from '@/lib/demo'
import { predikatDari } from '@/lib/penilaian'
import { hariIniISO } from '@/lib/tanggal'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'
import { useSantri } from './santri'

const rpc = async (nama, arg) => { const { data, error } = await supabase.rpc(nama, arg); if (error) throw new Error(pesanGalat(error)); return data }

// ---------- Data contoh ----------
const demo = { penguji: {}, hasil: {}, mode: {}, n: 0 }
const namaPeg = (id) => { const p = PEGAWAI_DEMO.find((x) => x.id === id); return p?.nama_lengkap || id }
function juzUsulDemo(s) {
  const d = dataTahfizhDemo(); const j = (d.juz[s.id] || []).map((x) => x.juz)
  return j.slice(-(s.jenjang === 'sma' ? 5 : 3)).sort((a, b) => a - b)
}
function dataDemo(smt) {
  const san = useSantri(); const kel = dataKelompokDemo(san.daftar); isiSantriDemo(san.daftar.filter((s) => ['aktif', 'nonaktif'].includes(s.status)))
  const pn = dataPenilaianDemo(); const ket = pn.ketentuan.tahfizh; const sesi = useSesi()
  const saya = sesi.peran === 'pegawai' ? 'p1' : null; const semua = sesi.isAdmin
  const mode = demo.mode[smt] || 'kelas'
  const kelas = kel.kelompok.filter((g) => g.jenis === mode).map((g) => ({ group_id: g.id, nama: g.nama, jenis: g.jenis, jenjang: g.jenjang, tingkat: g.tingkat, jenis_kelamin: g.jenis_kelamin,
    santri: kel.anggota.filter((a) => a.group_id === g.id).length, muhaffizh: g.jenis === 'halaqah' ? (g.pengasuh || []).map((p) => p.nama).join(', ') : null, penguji: (demo.penguji[`${smt}|${g.id}`] || []).map((e) => ({ employee_id: e, nama: namaPeg(e), niy: null, no_hp: '081234500000' })) }))
  const peserta = Object.values(demo.hasil).filter((r) => r.semester === smt).map((r) => {
    const s = san.daftar.find((x) => x.id === r.student_id); const g = kel.kelompok.find((x) => x.id === r.group_id)
    const dari = (j) => { const a = kel.anggota.find((x) => x.student_id === s.id && kel.kelompok.find((k) => k.id === x.group_id)?.jenis === j); return a ? kel.kelompok.find((k) => k.id === a.group_id)?.nama : null }
    return { ...r, nis: s.nis, nama: s.nama_lengkap, jenis_kelamin: s.jenis_kelamin, jenjang: s.jenjang, kelompok: g?.nama, jenis_kelompok: g?.jenis, kelas: dari('kelas'), halaqah: dari('halaqah'),
      penguji: r.penguji_id ? namaPeg(r.penguji_id) : null, juz_usul: juzUsulDemo(s), total_juz: (dataTahfizhDemo().juz[s.id] || []).length, saya: r.penguji_id === saya }
  }).filter((r) => semua || r.saya).sort((a, b) => (a.kelompok || '').localeCompare(b.kelompok || '') || a.nama.localeCompare(b.nama))
  const belum = {}
  if (semua) for (const g of kel.kelompok.filter((x) => x.jenis === mode)) { const n = kel.anggota.filter((a) => a.group_id === g.id && !demo.hasil[`${smt}|${a.student_id}`]).length; if (n) belum[g.id] = n }
  return { ta: 'ta1', semester: smt, mode, hak: { panitia: semua, penguji: Object.values(demo.hasil).some((r) => r.penguji_id === 'p1') || Object.values(demo.penguji).some((x) => x.includes('p1')), lihat: true },
    periode: pn.periode.find((p) => p.jenis === 'tahfizh' && p.semester === smt), ketentuan: { juz_sma: ket.utas_juz_sma, juz_wustha: ket.utas_juz_wustha, kkm: ket.ambang_bawaan, bahasa: ket.bahasa_predikat, bobot_tajwid: 50, bobot_itqan: 50 },
    predikat: pn.predikat.filter((p) => p.kelompok === 'utas'), kelas: semua ? kelas : kelas.filter((k) => (demo.penguji[`${smt}|${k.group_id}`] || []).includes('p1')), peserta, belum_dibagi: belum }
}
function hitungDemo(r) {
  const pn = dataPenilaianDemo()
  if (r.tajwid == null || r.itqan == null) { r.nilai_akhir = null; r.huruf = null; r.tuntas = null; return }
  r.nilai_akhir = Math.round(((Number(r.tajwid) + Number(r.itqan)) / 2) * 100) / 100
  r.huruf = predikatDari(r.nilai_akhir, pn.predikat.filter((p) => p.kelompok === 'utas'))?.huruf || null
  r.tuntas = r.nilai_akhir >= Number(pn.ketentuan.tahfizh.ambang_bawaan)
}

export const useUtas = defineStore('utas', {
  state: () => ({ data: null, semester: null, memuat: false }),
  getters: { hak: (s) => s.data?.hak || { panitia: false, penguji: false, lihat: false } },
  actions: {
    async muat(smt) {
      this.memuat = true
      try {
        if (MODE_DEMO) { const san = useSantri(); await san.muat(); this.semester = smt || this.semester || 1; this.data = dataDemo(this.semester); return }
        this.data = await rpc('data_utas', { p_semester: smt || this.semester || null, p_ta: null }); this.semester = this.data.semester
      } finally { this.memuat = false }
    },
    async aturMode(mode) {
      if (MODE_DEMO) { if (!useSesi().isAdmin) throw new Error('Hanya panitia UTAS (admin/superadmin) yang dapat melakukan ini.'); demo.mode[this.semester] = mode; return this.muat(this.semester) }
      await rpc('atur_mode_utas', { p_semester: this.semester, p_mode: mode, p_ta: null }); return this.muat(this.semester)
    },
    async simpanPenguji(groupId, ids) {
      if (MODE_DEMO) {
        const g = dataKelompokDemo(useSantri().daftar).kelompok.find((x) => x.id === groupId)
        const m = (g?.pengasuh || []).find((p) => ids.includes(p.employee_id)); if (g?.jenis === 'halaqah' && m) throw new Error(`${m.nama} adalah muhaffizh ${g.nama} sehingga tidak dapat menguji halaqahnya sendiri.`)
        demo.penguji[`${this.semester}|${groupId}`] = [...ids]; for (const r of Object.values(demo.hasil)) if (r.group_id === groupId && r.semester === this.semester && r.penguji_id && !ids.includes(r.penguji_id) && r.status === 'draf') r.penguji_id = null; return this.muat(this.semester) }
      await rpc('simpan_penguji_utas', { p_semester: this.semester, p_group: groupId, p_employees: ids, p_ta: null }); return this.muat(this.semester)
    },
    async bagi(groupId, ulang = false) {
      if (MODE_DEMO) {
        const san = useSantri(); const kel = dataKelompokDemo(san.daftar); const pj = demo.penguji[`${this.semester}|${groupId}`] || []; let n = 0
        if (ulang) for (const r of Object.values(demo.hasil)) if (r.group_id === groupId && r.status === 'draf' && r.tajwid == null && r.itqan == null) r.penguji_id = null
        for (const a of kel.anggota.filter((x) => x.group_id === groupId)) {
          const k = `${this.semester}|${a.student_id}`; const s = san.daftar.find((x) => x.id === a.student_id)
          demo.hasil[k] ||= { id: 'u' + ++demo.n, semester: this.semester, student_id: a.student_id, group_id: groupId, penguji_id: null, juz: juzUsulDemo(s), tajwid: null, itqan: null, nilai_akhir: null, huruf: null, tuntas: null, status: 'draf', catatan: null, diuji_pada: null }
          if (demo.hasil[k].group_id !== groupId && demo.hasil[k].tajwid == null && demo.hasil[k].itqan == null) { demo.hasil[k].group_id = groupId; demo.hasil[k].penguji_id = null }
          if (pj.length && !demo.hasil[k].penguji_id) { const hitung = (e) => Object.values(demo.hasil).filter((r) => r.group_id === groupId && r.semester === this.semester && r.penguji_id === e).length; demo.hasil[k].penguji_id = [...pj].sort((x, y) => hitung(x) - hitung(y))[0]; n++ }
        }
        await this.muat(this.semester); return n
      }
      const n = await rpc('bagi_peserta_utas', { p_semester: this.semester, p_group: groupId, p_ulang: ulang, p_ta: null }); await this.muat(this.semester); return n
    },
    async pindah(ids, pengujiId) {
      if (MODE_DEMO) { for (const r of Object.values(demo.hasil)) if (ids.includes(r.id)) r.penguji_id = pengujiId; return this.muat(this.semester) }
      await rpc('pindah_penguji_utas', { p_ids: ids, p_penguji: pengujiId }); return this.muat(this.semester)
    },
    async hapus(ids) {
      if (MODE_DEMO) { for (const [k, r] of Object.entries(demo.hasil)) if (ids.includes(r.id) && r.tajwid == null && r.itqan == null) delete demo.hasil[k]; return this.muat(this.semester) }
      await rpc('hapus_peserta_utas', { p_ids: ids }); return this.muat(this.semester)
    },
    /** isi: [{ id, juz?, tajwid?, itqan?, catatan? }] */
    async simpanNilai(isi, kirim = false) {
      if (MODE_DEMO) {
        for (const x of isi) {
          const r = Object.values(demo.hasil).find((y) => y.id === x.id)
          if (r.status === 'final' && !useSesi().isAdmin) throw new Error('Nilai sudah dikirim (final). Perubahan melalui panitia UTAS.')
          for (const f of ['juz', 'tajwid', 'itqan', 'catatan']) if (f in x) r[f] = x[f] === '' ? null : x[f]
          r.diuji_pada ||= hariIniISO(); hitungDemo(r)
          if (kirim) { if (r.tajwid == null || r.itqan == null) throw new Error('Nilai Tajwid dan Itqan wajib diisi sebelum dikirim.'); r.status = 'final' }
        }
        return this.muat(this.semester)
      }
      await rpc('simpan_nilai_utas', { p: isi, p_kirim: kirim }); return this.muat(this.semester)
    },
    async buka(ids) {
      if (MODE_DEMO) { for (const r of Object.values(demo.hasil)) if (ids.includes(r.id)) r.status = 'draf'; return this.muat(this.semester) }
      await rpc('buka_nilai_utas', { p_ids: ids }); return this.muat(this.semester)
    },
  },
})
