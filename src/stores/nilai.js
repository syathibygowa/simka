// SIMKA PRO | src/stores/nilai.js | v1.1 | 14.26.0: ceklist capaian TP per santri (tp_tercapai) | 25/10/2026
// Isian nilai guru mapel: daftar kelas–mapel yang terlihat beserta kemajuan pengisian, lembar nilai satu penugasan ×
// semester (isian per komponen, nilai rapor, sikap, tujuan pembelajaran). Penulisan hanya lewat fungsi SQL.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { dataJadwalDemo } from '@/lib/demoJadwal'
import { dataKelompokDemo } from '@/lib/demoKelompok'
import { dataPenilaianDemo } from '@/lib/demoPenilaian'
import { hitungAkumulasi } from '@/lib/nilai'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'
import { useSantri } from './santri'

const rpc = async (nama, arg) => { const { data, error } = await supabase.rpc(nama, arg); if (error) throw new Error(pesanGalat(error)); return data }

// ---------- Data contoh (mode demo) ----------
const demo = { kolom: [], skor: new Map(), akhir: new Map(), tp: new Map(), n: 0 }
const kunci = (a, s) => `${a}|${s}`
function lembarDemo(id, smt) {
  const d = dataJadwalDemo(); const t = d.penugasan.find((x) => x.id === id); if (!t) throw new Error('Penugasan mengajar tidak ditemukan.')
  const san = useSantri(); const kel = dataKelompokDemo(san.daftar); const g = kel.kelompok.find((x) => x.id === t.group_id); const m = d.mapel.find((x) => x.id === t.subject_id)
  const pn = dataPenilaianDemo(); const jenis = g.jenjang; const ket = pn.ketentuan[jenis]
  const mr = pn.mapel.filter((r) => r.jenis === jenis && r.tingkat === g.tingkat && (r.sumber_mapel || []).some((x) => x.subject_id === m.id))
  const mode = mr.find((r) => r.mode_nilai)?.mode_nilai || ket.mode_nilai
  const per = pn.periode.find((p) => p.jenis === jenis && p.semester === smt)
  const sesi = useSesi(); const milik = sesi.peran === 'pegawai' ? t.employee_id === 'p1' : false
  const boleh = sesi.isAdmin || (milik && per?.status === 'dibuka')
  const santri = kel.anggota.filter((a) => a.group_id === g.id).map((a) => san.daftar.find((s) => s.id === a.student_id)).filter(Boolean)
    .map((s) => ({ id: s.id, nis: s.nis, nama: s.nama_lengkap, panggilan: s.nama_panggilan, jenis_kelamin: s.jenis_kelamin, aktif: true })).sort((a, b) => a.nama.localeCompare(b.nama))
  const kategori = pn.kategori.filter((c) => c.jenis === jenis)
  const kolom = demo.kolom.filter((c) => c.assignment_id === id && c.semester === smt)
  const skor = [...demo.skor.entries()].filter(([k]) => kolom.some((c) => k.startsWith(c.id + '|'))).map(([k, v]) => [...k.split('|'), v])
  const peta = new Map(skor.map(([c, s, v]) => [`${c}|${s}`, v]))
  const akhir = santri.map((s) => {
    const f = demo.akhir.get(`${kunci(id, smt)}|${s.id}`) || {}
    const saran = hitungAkumulasi({ kategori, kolom, skor: peta, santriId: s.id, desimal: ket.desimal }).nilai
    const saranK = hitungAkumulasi({ kategori, kolom, skor: peta, santriId: s.id, aspek: 'keterampilan', desimal: ket.desimal }).nilai
    return { student_id: s.id, nilai: mode === 'akumulasi' ? saran : f.nilai ?? null, keterampilan: f.keterampilan ?? null, sikap: f.sikap ?? null, deskripsi: f.deskripsi ?? null, deskripsi_2: f.deskripsi_2 ?? null, saran, saran_keterampilan: saranK }
  })
  return {
    tugas: { assignment_id: t.id, group_id: g.id, kelas: g.nama, jenjang: jenis, tingkat: g.tingkat, subject_id: m.id, mapel: m.nama, kode_mapel: m.kode, employee_id: t.employee_id, guru: t.nama_guru, milik_saya: milik },
    semester: smt, boleh_ubah: boleh, alasan: boleh ? null : per?.status === 'ditutup' ? 'Periode penilaian sudah ditutup; nilai terkunci.' : 'Periode penilaian belum dibuka.', pengelola: sesi.isAdmin,
    periode: per, mode, mapel_rapor: mr.map((r) => ({ id: r.id, nama: r.nama, kkm: r.kkm, bobot: 100 })), kkm: mr[0]?.kkm ?? ket.ambang_bawaan,
    ketentuan: { label_ambang: ket.label_ambang, desimal: ket.desimal, pakai_keterampilan: ket.pakai_keterampilan, keterampilan_ikut: ket.keterampilan_ikut, pakai_tp: ket.pakai_tp, sikap_di_rapor: ket.sikap_di_rapor },
    kategori, predikat: pn.predikat.filter((p) => p.kelompok === jenis), sikap_pilihan: pn.predikat.filter((p) => p.kelompok === 'sikap'),
    kolom, tp: (demo.tp.get(kunci(id, smt)) || []).map((teks, i) => ({ id: 'tp' + i, teks })), santri, skor, akhir,
    capaian_tp: Object.fromEntries(santri.map((s) => [s.id, demo.akhir.get(`${kunci(id, smt)}|${s.id}`)?.tp_tercapai]).filter(([, v]) => Array.isArray(v))),
  }
}

export const useNilai = defineStore('nilai', {
  state: () => ({ semester: null, daftar: [], memuat: false, dimuat: false, lembar: null }),
  actions: {
    async muatDaftar(semester) {
      this.memuat = true
      try {
        if (MODE_DEMO) {
          const san = useSantri(); await san.muat(); const sesi = useSesi(); this.semester = semester || this.semester || 1
          const d = dataJadwalDemo(); const kel = dataKelompokDemo(san.daftar)
          this.daftar = d.penugasan.filter((t) => sesi.isAdmin || t.employee_id === 'p1').map((t) => {
            const l = lembarDemo(t.id, this.semester)
            return { assignment_id: t.id, group_id: t.group_id, kelas: l.tugas.kelas, jenjang: l.tugas.jenjang, tingkat: l.tugas.tingkat, mapel: l.tugas.mapel, kode_mapel: l.tugas.kode_mapel,
              employee_id: t.employee_id, guru: t.nama_guru, milik_saya: l.tugas.milik_saya, mode: l.mode, mapel_rapor: l.mapel_rapor.map((r) => r.nama), status: l.periode?.status || 'disiapkan',
              santri: l.santri.length, kolom: l.kolom.length, terisi: l.akhir.filter((a) => a.nilai != null).length, sikap: l.akhir.filter((a) => a.sikap).length }
          }).sort((a, b) => Number(b.milik_saya) - Number(a.milik_saya) || a.tingkat - b.tingkat || a.kelas.localeCompare(b.kelas))
          void kel; return
        }
        const r = await rpc('kelas_nilai', { p_semester: semester || this.semester || null, p_ta: null })
        this.semester = r.semester; this.daftar = r.daftar || []
      } finally { this.memuat = false; this.dimuat = true }
    },
    async muatLembar(id, semester) {
      if (MODE_DEMO) { const san = useSantri(); await san.muat(); this.lembar = lembarDemo(id, Number(semester)); return this.lembar }
      this.lembar = await rpc('lembar_nilai', { p_assignment: id, p_semester: Number(semester) }); return this.lembar
    },
    async simpanKolom(isi) {
      const { tugas, semester } = this.lembar
      if (MODE_DEMO) {
        const k = this.lembar.kategori.find((c) => c.id === isi.category_id)
        if (!isi.id && k && !k.berulang && demo.kolom.some((c) => c.assignment_id === tugas.assignment_id && c.semester === semester && c.category_id === k.id)) throw new Error(`Komponen ${k.nama} hanya diisi sekali dan isiannya sudah ada.`)
        if (isi.id) Object.assign(demo.kolom.find((c) => c.id === isi.id), isi)
        else demo.kolom.push({ ...isi, id: 'kol' + ++demo.n, assignment_id: tugas.assignment_id, semester, urutan: demo.n })
        return this.muatLembar(tugas.assignment_id, semester)
      }
      await rpc('simpan_kolom_nilai', { p_assignment: tugas.assignment_id, p_semester: semester, p: isi }); return this.muatLembar(tugas.assignment_id, semester)
    },
    async hapusKolom(id) {
      const { tugas, semester } = this.lembar
      if (MODE_DEMO) { demo.kolom = demo.kolom.filter((c) => c.id !== id); for (const k of [...demo.skor.keys()]) if (k.startsWith(id + '|')) demo.skor.delete(k); return this.muatLembar(tugas.assignment_id, semester) }
      await rpc('hapus_kolom_nilai', { p_id: id }); return this.muatLembar(tugas.assignment_id, semester)
    },
    /** perubahan: { [kolomId]: [{ student_id, nilai }] } */
    async simpanSkor(perubahan) {
      const { tugas, semester } = this.lembar
      for (const [kolom, isi] of Object.entries(perubahan)) {
        if (!isi.length) continue
        if (MODE_DEMO) { for (const x of isi) { if (x.nilai === '' || x.nilai == null) demo.skor.delete(`${kolom}|${x.student_id}`); else demo.skor.set(`${kolom}|${x.student_id}`, Number(x.nilai)) } continue }
        await rpc('simpan_skor_nilai', { p_column: kolom, p: isi })
      }
      return this.muatLembar(tugas.assignment_id, semester)
    },
    async simpanAkhir(isi) {
      const { tugas, semester } = this.lembar
      if (MODE_DEMO) {
        for (const x of isi) { const k = `${kunci(tugas.assignment_id, semester)}|${x.student_id}`; const lama = demo.akhir.get(k) || {}; const baru = { ...lama }
          for (const f of ['nilai', 'keterampilan', 'sikap', 'deskripsi', 'deskripsi_2', 'tp_tercapai']) if (f in x) baru[f] = x[f] === '' ? null : x[f]
          demo.akhir.set(k, baru) }
        return this.muatLembar(tugas.assignment_id, semester)
      }
      await rpc('simpan_nilai_akhir', { p_assignment: tugas.assignment_id, p_semester: semester, p: isi }); return this.muatLembar(tugas.assignment_id, semester)
    },
    async simpanTP(daftar) {
      const { tugas, semester } = this.lembar
      if (MODE_DEMO) { demo.tp.set(kunci(tugas.assignment_id, semester), daftar.filter((x) => x.trim())); return this.muatLembar(tugas.assignment_id, semester) }
      await rpc('simpan_tp_nilai', { p_assignment: tugas.assignment_id, p_semester: semester, p: daftar }); return this.muatLembar(tugas.assignment_id, semester)
    },
  },
})
