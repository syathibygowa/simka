// SIMKA PRO | src/stores/jadwal.js | v1.0 | Fase 4 – Tahap 5 Jadwal pelajaran dan jurnal mengajar | 04/10/2026
// Mata pelajaran, jam pelajaran, penugasan mengajar, jadwal pelajaran per kelas/guru, jurnal mengajar, dan rekap.
// Penulisan lewat fungsi SQL (hak atur_jadwal; guru menulis jurnal dan rencana materinya sendiri).
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { dataJadwalDemo } from '@/lib/demoJadwal'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'
import { useKelompokSantri } from './kelompokSantri'

const rpc = async (nama, arg) => { const { data, error } = await supabase.rpc(nama, arg); if (error) throw new Error(pesanGalat(error)); return data }
const j5 = (t) => String(t || '').slice(0, 5)
const idSaya = () => (MODE_DEMO ? 'p1' : useSesi().pengguna?.id)

export const useJadwal = defineStore('jadwal', {
  state: () => ({ mapel: [], jam: [], penugasan: [], jadwal: [], memuat: false, dimuat: false }),
  getters: {
    jamUntuk: (s) => (jenjang, jenisHari) => s.jam.filter((p) => p.jenjang === jenjang && p.jenis_hari === jenisHari).sort((a, b) => a.urutan - b.urutan),
    cariMapel: (s) => (id) => s.mapel.find((m) => m.id === id),
    cariPenugasan: (s) => (id) => s.penugasan.find((t) => t.id === id),
  },
  actions: {
    async muat(paksa = false) {
      if (this.dimuat && !paksa) return
      this.memuat = true
      try {
        if (MODE_DEMO) { const d = dataJadwalDemo(); Object.assign(this, { mapel: d.mapel, jam: d.jam, penugasan: d.penugasan, jadwal: d.jadwal }); this.dimuat = true; return }
        const ta = useKelompokSantri().taAktif?.id
        const [m, j, t, s] = await Promise.all([
          supabase.from('subjects').select('*').order('urutan'),
          supabase.from('lesson_periods').select('*').order('urutan'),
          supabase.from('teaching_assignments').select('*, guru:employee_id(nama_lengkap, niy)').order('created_at'),
          supabase.from('class_schedules').select('*'),
        ])
        for (const r of [m, j, t, s]) if (r.error) throw new Error(pesanGalat(r.error))
        this.mapel = m.data
        this.jam = j.data.map((p) => ({ ...p, jam_mulai: j5(p.jam_mulai), jam_selesai: j5(p.jam_selesai) }))
        this.penugasan = t.data.filter((x) => !ta || x.academic_year_id === ta).map((x) => ({ ...x, nama_guru: x.guru?.nama_lengkap, niy_guru: x.guru?.niy }))
        const ids = new Set(this.penugasan.map((x) => x.id))
        this.jadwal = s.data.filter((x) => ids.has(x.assignment_id))
        this.dimuat = true
      } finally { this.memuat = false }
    },
    async simpanMapel(isi) {
      if (MODE_DEMO) { const d = dataJadwalDemo(); if (isi.id) Object.assign(d.mapel.find((m) => m.id === isi.id), isi); else d.mapel.push({ ...isi, id: 'm-' + isi.kode, aktif: true }); return this.muat(true) }
      await rpc('simpan_mapel', { p: isi }); await this.muat(true)
    },
    async simpanJam(jenjang, jenisHari, daftar) {
      if (MODE_DEMO) { const d = dataJadwalDemo(); d.jam = [...d.jam.filter((p) => !(p.jenjang === jenjang && p.jenis_hari === jenisHari)), ...daftar.map((p) => ({ ...p, id: p.id || `p-${jenjang}|${jenisHari}-${p.urutan}`, jenjang, jenis_hari: jenisHari }))]; return this.muat(true) }
      await rpc('simpan_jam_pelajaran', { p_jenjang: jenjang, p_jenis_hari: jenisHari, p_daftar: daftar }); await this.muat(true)
    },
    async simpanPenugasan(isi, namaGuru = '') {
      if (MODE_DEMO) {
        const d = dataJadwalDemo()
        if (d.penugasan.some((t) => t.id !== isi.id && t.group_id === isi.group_id && t.subject_id === isi.subject_id)) throw new Error('Mapel ini sudah ditugaskan di kelas tersebut. Ubah penugasan yang ada.')
        if (isi.id) Object.assign(d.penugasan.find((t) => t.id === isi.id), isi, { nama_guru: namaGuru }); else d.penugasan.push({ ...isi, id: 't' + Date.now(), nama_guru: namaGuru })
        d.jadwal.filter((s) => s.assignment_id === isi.id).forEach((s) => { s.employee_id = isi.employee_id })
        return this.muat(true)
      }
      await rpc('simpan_penugasan', { p: isi }); await this.muat(true)
    },
    async hapusPenugasan(id) {
      if (MODE_DEMO) { const d = dataJadwalDemo(); d.penugasan = d.penugasan.filter((t) => t.id !== id); d.jadwal = d.jadwal.filter((s) => s.assignment_id !== id); return this.muat(true) }
      await rpc('hapus_penugasan', { p_id: id }); await this.muat(true)
    },
    async aturSel(group, hari, period, assignment) {
      if (MODE_DEMO) {
        const d = dataJadwalDemo(); const t = d.penugasan.find((x) => x.id === assignment); const p = d.jam.find((x) => x.id === period)
        if (t) {
          const lain = d.jadwal.find((s) => s.employee_id === t.employee_id && s.hari === hari && s.group_id !== group && (() => { const q = d.jam.find((x) => x.id === s.period_id); return q.jam_mulai < p.jam_selesai && p.jam_mulai < q.jam_selesai })())
          if (lain) throw new Error(`Bentrok: ${t.nama_guru} sudah mengajar di kelas lain pada jam yang sama.`)
        }
        d.jadwal = d.jadwal.filter((s) => !(s.group_id === group && s.hari === hari && s.period_id === period))
        if (t) d.jadwal.push({ id: 's' + Date.now(), assignment_id: assignment, group_id: group, employee_id: t.employee_id, hari, period_id: period })
        return this.muat(true)
      }
      await rpc('atur_sel_jadwal', { p_group: group, p_hari: hari, p_period: period, p_assignment: assignment || null }); await this.muat(true)
    },
    async imporPenugasan(baris) {
      if (MODE_DEMO) return baris.map((b, i) => ({ baris: i + 1, ok: false, pesan: 'Mode demo: impor tidak disimpan.' }))
      const h = await rpc('impor_penugasan', { p_baris: baris }); await this.muat(true); return h
    },

    // ---------- Jurnal mengajar ----------
    async jadwalMengajar(tanggal) {
      if (MODE_DEMO) {
        const d = dataJadwalDemo(); const kel = useKelompokSantri(); await kel.muat()
        const dow = new Date(`${tanggal}T12:00:00+08:00`).getUTCDay(); if (dow === 0) return []
        return d.jadwal.filter((s) => s.employee_id === idSaya() && s.hari === dow).map((s) => {
          const t = d.penugasan.find((x) => x.id === s.assignment_id); const p = d.jam.find((x) => x.id === s.period_id); const g = kel.cari(t.group_id)
          const jr = d.jurnal.find((x) => x.assignment_id === t.id && x.tanggal === tanggal && x.period_id === p.id)
          const pakai = new Set(d.jurnal.filter((x) => x.tanggal !== tanggal).map((x) => x.plan_id))
          return { assignment_id: t.id, period_id: p.id, jam_ke: p.nama, jam_mulai: p.jam_mulai, jam_selesai: p.jam_selesai, group_id: t.group_id, kelas: g?.nama, jenjang: g?.jenjang,
            mapel: d.mapel.find((m) => m.id === t.subject_id)?.nama, jurnal: jr || null, rencana: d.rencana.filter((r) => r.assignment_id === t.id && !pakai.has(r.id)).sort((a, b) => a.urutan - b.urutan)[0] || null,
            materi_terakhir: null }
        }).sort((a, b) => a.jam_mulai.localeCompare(b.jam_mulai))
      }
      return (await rpc('jadwal_mengajar', { p_tanggal: tanggal })) || []
    },
    async simpanJurnal(tanggal, entri) {
      if (MODE_DEMO) { const d = dataJadwalDemo(); for (const e of entri) { d.jurnal = d.jurnal.filter((x) => !(x.assignment_id === e.assignment_id && x.tanggal === tanggal && x.period_id === e.period_id)); d.jurnal.push({ ...e, id: 'j' + Math.random(), tanggal }) } return entri.length }
      return rpc('simpan_jurnal_mengajar', { p: { tanggal, entri } })
    },
    async muatRencana(assignment) {
      if (MODE_DEMO) return dataJadwalDemo().rencana.filter((r) => r.assignment_id === assignment).sort((a, b) => a.urutan - b.urutan)
      const { data, error } = await supabase.from('teaching_plans').select('*').eq('assignment_id', assignment).order('urutan')
      if (error) throw new Error(pesanGalat(error)); return data
    },
    async simpanRencana(assignment, topik) {
      if (MODE_DEMO) { const d = dataJadwalDemo(); d.rencana = [...d.rencana.filter((r) => r.assignment_id !== assignment), ...topik.map((t, i) => ({ id: `r${Date.now()}${i}`, assignment_id: assignment, urutan: i + 1, topik: t }))]; return topik.length }
      return rpc('simpan_rencana_materi', { p_assignment: assignment, p_topik: topik })
    },
    async rekap(mulai, selesai, emp = null) {
      if (MODE_DEMO) {
        const d = dataJadwalDemo(); const kel = useKelompokSantri(); await kel.muat()
        return d.penugasan.filter((t) => !emp || t.employee_id === emp).map((t) => {
          const n = d.jadwal.filter((s) => s.assignment_id === t.id).length * 4; const ok = Math.max(0, n - (t.id.length % 3))
          return { employee_id: t.employee_id, guru: t.nama_guru, niy: null, assignment_id: t.id, kelas: kel.cari(t.group_id)?.nama, mapel: d.mapel.find((m) => m.id === t.subject_id)?.nama,
            jp_pekan: t.jp_pekan, jp_terjadwal: n, jp_terlaksana: ok, jp_tidak: n - ok > 0 ? 1 : 0, jp_kosong: Math.max(0, n - ok - 1) }
        })
      }
      return (await rpc('rekap_mengajar', { p_mulai: mulai, p_selesai: selesai, p_emp: emp })) || []
    },
    idSaya,
  },
})
