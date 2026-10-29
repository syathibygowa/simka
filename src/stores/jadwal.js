// SIMKA PRO | src/stores/jadwal.js | v1.8 | 14.34.0: kehadiran santri per jam pelajaran (harian) dan per pertemuan mapel | 30/10/2026
// Mata pelajaran, jam pelajaran, penugasan mengajar, jadwal pelajaran per kelas/guru, jurnal mengajar, dan rekap.
// Penulisan lewat fungsi SQL (hak atur_jadwal; guru menulis jurnal dan rencana materinya sendiri).
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { dataJadwalDemo } from '@/lib/demoJadwal'
import { dataKelompokDemo } from '@/lib/demoKelompok'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'
import { useKelompokSantri } from './kelompokSantri'
import { useSantri } from './santri'
import { HARI_JAM_BAWAAN } from '@/lib/jadwal'
import { hariIniISO } from '@/lib/tanggal'

const rpc = async (nama, arg) => { const { data, error } = await supabase.rpc(nama, arg); if (error) throw new Error(pesanGalat(error)); return data }
const j5 = (t) => String(t || '').slice(0, 5)
const idSaya = () => (MODE_DEMO ? 'p1' : useSesi().pengguna?.id)

export const ATUR_JURNAL_DEMO = { batas_hari: 1, absen_santri: true,
  metode: ['Ceramah', 'Tanya jawab', 'Diskusi', 'Demonstrasi', 'Praktik', 'Penugasan', 'Presentasi', 'Talaqqi/hafalan', 'Proyek', 'Permainan'],
  media: ['Papan tulis', 'Buku paket', 'Kitab', 'Lembar kerja', 'Proyektor/LCD', 'Video', 'Alat peraga', 'Lingkungan sekitar'],
  alat: ['Papan tulis dan spidol', 'Laptop', 'Proyektor/LCD', 'Pengeras suara', 'Alat peraga', 'Alat praktik/laboratorium', 'Mushaf/kitab'],
  sumber: ['Buku paket', 'Buku pendamping/LKS', 'Kitab', 'Modul guru', "Al-Qur'an dan tafsir", 'Internet/artikel', 'Video pembelajaran'],
  wajib: { subbab: true, metode: true, media: false, alat: false, sumber: false, tujuan: false, kegiatan: false } }

export const useJadwal = defineStore('jadwal', {
  state: () => ({ mapel: [], jam: [], penugasan: [], jadwal: [], hariJam: { wustha: { ...HARI_JAM_BAWAAN }, sma: { ...HARI_JAM_BAWAAN } }, memuat: false, dimuat: false, aturJurnal: null }),
  getters: {
    jamUntuk: (s) => (jenjang, jenisHari) => s.jam.filter((p) => p.jenjang === jenjang && p.jenis_hari === jenisHari).sort((a, b) => a.urutan - b.urutan),
    /** Kumpulan jam (reguler/jumat/sabtu) yang dipakai hari h pada jenjang tertentu (Mapel dan jam → Pembagian jam per hari). */
    jenisHariUntuk: (s) => (jenjang, h) => s.hariJam?.[jenjang]?.[String(h)] || HARI_JAM_BAWAAN[h] || 'reguler',
    /** Jam pelajaran untuk satu hari pada jenjang tertentu. */
    jamHari: (s) => (jenjang, h) => {
      const jh = s.hariJam?.[jenjang]?.[String(h)] || HARI_JAM_BAWAAN[h] || 'reguler'
      return s.jam.filter((p) => p.jenjang === jenjang && p.jenis_hari === jh).sort((a, b) => a.urutan - b.urutan)
    },
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
        const [m, j, t, s, st] = await Promise.all([
          supabase.from('subjects').select('*').order('urutan'),
          supabase.from('lesson_periods').select('*').order('urutan'),
          supabase.from('teaching_assignments').select('*, guru:employee_id(nama_lengkap, niy)').order('created_at'),
          supabase.from('class_schedules').select('*'),
          supabase.from('institution_settings').select('nilai').eq('kunci', 'jadwal_pelajaran').maybeSingle(),
        ])
        for (const r of [m, j, t, s]) if (r.error) throw new Error(pesanGalat(r.error))
        this.mapel = m.data
        const hj = st.data?.nilai?.hari_jam || {}
        this.hariJam = { wustha: { ...HARI_JAM_BAWAAN, ...(hj.wustha || {}) }, sma: { ...HARI_JAM_BAWAAN, ...(hj.sma || {}) } }
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
    /** Simpan pembagian hari → kumpulan jam satu jenjang. peta: { '1': 'reguler', …, '6': 'sabtu' } */
    async simpanHariJam(jenjang, peta) {
      if (MODE_DEMO) {
        const d = dataJadwalDemo()
        for (const [h, jh] of Object.entries(peta)) {
          const lama = this.jenisHariUntuk(jenjang, h)
          if (lama === jh) continue
          if (!d.jam.some((p) => p.jenjang === jenjang && p.jenis_hari === jh)) d.jam.push(...d.jam.filter((p) => p.jenjang === jenjang && p.jenis_hari === lama).map((p) => ({ ...p, id: `p-${jenjang}|${jh}-${p.urutan}`, jenis_hari: jh })))
          for (const x of d.jadwal.filter((x) => Number(x.hari) === Number(h))) {
            const p = d.jam.find((q) => q.id === x.period_id); if (!p || p.jenjang !== jenjang) continue
            const baru = d.jam.find((q) => q.jenjang === jenjang && q.jenis_hari === jh && q.urutan === p.urutan && q.jenis === 'jp')
            if (baru) x.period_id = baru.id; else d.jadwal.splice(d.jadwal.indexOf(x), 1)
          }
        }
        const sim = { ...this.hariJam, [jenjang]: { ...this.hariJam[jenjang], ...peta } }
        await this.muat(true); this.hariJam = sim
        return { dipindah: 0, dikosongkan: 0 }
      }
      const r = await rpc('simpan_hari_jam', { p_jenjang: jenjang, p_peta: peta }); await this.muat(true); return r
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
          const t = d.penugasan.find((x) => x.id === s.assignment_id); const p = d.jam.find((x) => x.id === s.period_id); const g = kel.cari(t.group_id) || dataKelompokDemo([]).kelompok.find((x) => x.id === t.group_id)
          const jr = d.jurnal.find((x) => x.assignment_id === t.id && x.tanggal === tanggal && x.period_id === p.id)
          const pakai = new Set(d.jurnal.filter((x) => x.tanggal !== tanggal).map((x) => x.plan_id))
          return { assignment_id: t.id, period_id: p.id, jam_ke: p.nama, jam_mulai: p.jam_mulai, jam_selesai: p.jam_selesai, group_id: t.group_id, kelas: g?.nama, jenjang: g?.jenjang,
            mapel: d.mapel.find((m) => m.id === t.subject_id)?.nama, jurnal: jr || null, rencana: d.rencana.filter((r) => r.assignment_id === t.id && !pakai.has(r.id)).sort((a, b) => a.urutan - b.urutan)[0] || null,
            materi_terakhir: null }
        }).sort((a, b) => a.jam_mulai.localeCompare(b.jam_mulai))
      }
      return (await rpc('jadwal_mengajar', { p_tanggal: tanggal })) || []
    },
    /** Semua jam pelajaran guru lain pada satu tanggal, untuk diisi sebagai guru pengganti. */
    async slotPengganti(tanggal) {
      if (MODE_DEMO) {
        const d = dataJadwalDemo(); const kel = useKelompokSantri(); await kel.muat()
        const dow = new Date(`${tanggal}T12:00:00+08:00`).getUTCDay(); if (dow === 0) return []
        return d.jadwal.filter((s) => s.employee_id !== idSaya() && s.hari === dow).map((s) => {
          const t = d.penugasan.find((x) => x.id === s.assignment_id); const p = d.jam.find((x) => x.id === s.period_id); const g = kel.cari(t.group_id) || dataKelompokDemo([]).kelompok.find((x) => x.id === t.group_id)
          const jr = d.jurnal.find((x) => x.assignment_id === t.id && x.tanggal === tanggal && x.period_id === p.id)
          return { tanggal, terbuka: true, assignment_id: t.id, period_id: p.id, jam_ke: p.nama, jam_mulai: p.jam_mulai, jam_selesai: p.jam_selesai, group_id: t.group_id, kelas: g?.nama, jenjang: g?.jenjang,
            mapel: d.mapel.find((m) => m.id === t.subject_id)?.nama, employee_id: t.employee_id, guru: t.nama_guru, jurnal: jr ? { ...jr, milik_saya: !!jr.pengganti, oleh_guru: !jr.pengganti } : null, terakhir: null }
        }).sort((a, b) => String(a.kelas).localeCompare(String(b.kelas), 'id', { numeric: true }) || a.jam_mulai.localeCompare(b.jam_mulai))
      }
      return (await rpc('slot_pengganti', { p_tanggal: tanggal })) || []
    },
    /** Jadwal mengajar Senin–Sabtu pekan yang memuat tanggal: [{ tanggal, libur, terbuka, slot: [...] }]. */
    async jadwalPekan(tanggal) {
      if (MODE_DEMO) {
        const d0 = new Date(`${tanggal}T12:00:00+08:00`); d0.setUTCDate(d0.getUTCDate() - ((d0.getUTCDay() + 6) % 7))
        const batas = this.aturJurnal?.batas_hari ?? 1; const hari = new Date(Date.now() + 8 * 3600e3).toISOString().slice(0, 10); const hasil = []
        for (let i = 0; i < 6; i++) {
          const t = new Date(d0.getTime() + i * 864e5).toISOString().slice(0, 10)
          const sel = Math.round((new Date(`${hari}T12:00:00Z`) - new Date(`${t}T12:00:00Z`)) / 864e5); const terbuka = sel >= 0 && sel <= batas
          hasil.push({ tanggal: t, libur: false, terbuka, slot: (await this.jadwalMengajar(t)).map((x) => ({ ...x, tanggal: t, terbuka })) })
        }
        return hasil
      }
      return (await rpc('jadwal_mengajar_pekan', { p_tanggal: tanggal, p_emp: null })) || []
    },
    /** Santri kelas pada tanggal itu; kode_kelas = sudah tercatat tidak hadir di absensi kelas harian. */
    /** 14.16.0: jam pelajaran (jamMulai, jamSelesai) menentukan status sakit/izin otomatis pada pelajaran itu. */
    async peserta(assignment, tanggal, jamMulai = null, jamSelesai = null) {
      if (MODE_DEMO) {
        const d = dataJadwalDemo(); const t = d.penugasan.find((x) => x.id === assignment); const san = useSantri(); await san.muat(); const kel = dataKelompokDemo(san.daftar)
        return kel.anggota.filter((a) => a.group_id === t?.group_id && !a.selesai).map((a) => san.cari(a.student_id)).filter(Boolean)
          .map((s, i) => ({ id: s.id, nis: s.nis, nama: s.nama_lengkap, jk: s.jenis_kelamin, kode_kelas: i === 1 ? 'S' : null, sakit: i === 1, izin: false }))
          .sort((a, b) => a.nama.localeCompare(b.nama, 'id'))
      }
      return (await rpc('peserta_pelajaran', { p_assignment: assignment, p_tanggal: tanggal, p_jam_mulai: jamMulai ? String(jamMulai).slice(0, 5) : null, p_jam_selesai: jamSelesai ? String(jamSelesai).slice(0, 5) : null })) || []
    },
    async muatAturJurnal() {
      if (MODE_DEMO) { this.aturJurnal = this.aturJurnal || { ...ATUR_JURNAL_DEMO }; return this.aturJurnal }
      this.aturJurnal = await rpc('pengaturan_jurnal_mengajar'); return this.aturJurnal
    },
    async simpanAturJurnal(p) {
      if (MODE_DEMO) { this.aturJurnal = { ...this.aturJurnal, ...p }; return this.aturJurnal }
      this.aturJurnal = await rpc('simpan_pengaturan_jurnal_mengajar', { p }); return this.aturJurnal
    },
    async simpanJurnal(tanggal, entri) {
      if (MODE_DEMO) { const d = dataJadwalDemo(); for (const e of entri) { d.jurnal = d.jurnal.filter((x) => !(x.assignment_id === e.assignment_id && x.tanggal === tanggal && x.period_id === e.period_id)); d.jurnal.push({ ...e, id: 'j' + Math.random(), tanggal, pengganti: e.pengganti ? useSesi().pengguna?.nama_lengkap : null }) } return entri.length }
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
    /** Setiap jam pelajaran terjadwal pada rentang beserta status jurnal (terlaksana | tidak_terlaksana | belum) dan lewat. */
    /** 14.3.0: matriks kehadiran santri × mapel dari absensi guru mapel. p: { group_id | assignment_id, mulai, selesai } */
    async rekapKehadiranMapel(p) {
      if (!MODE_DEMO) return rpc('rekap_kehadiran_mapel', { p })
      await this.muat(); const d = dataJadwalDemo(); const san = useSantri(); await san.muat(); const kel = dataKelompokDemo(san.daftar)
      const grup = p.group_id || d.penugasan.find((x) => x.id === p.assignment_id)?.group_id
      const tugas = d.penugasan.filter((t) => t.group_id === grup && (!p.assignment_id || t.id === p.assignment_id))
      const anggota = kel.anggota.filter((a) => a.group_id === grup && !a.selesai).map((a) => san.cari(a.student_id)).filter(Boolean)
      const mapel = tugas.map((t, i) => ({ assignment_id: t.id, mapel: this.cariMapel(t.subject_id)?.nama || 'Mapel', kode: this.cariMapel(t.subject_id)?.kode || '', guru: t.guru || t.nama_guru || '', pertemuan: 8 + (i % 4) }))
      return { mulai: p.mulai, selesai: p.selesai, kelas: { id: grup, nama: kel.kelompok.find((g) => g.id === grup)?.nama || 'Kelas' },
        mapel, santri: anggota.map((st, si) => ({ student_id: st.id, nis: st.nis, nama: st.nama_lengkap, jk: st.jenis_kelamin,
          mapel: Object.fromEntries(mapel.map((m, mi) => { const tidak = (si * 3 + mi * 5) % 7 === 0 ? 3 : (si + mi) % 5 === 0 ? 1 : 0; const h = m.pertemuan - tidak
            return [m.assignment_id, { p: m.pertemuan, h, t: (si + mi) % 6 === 0 ? 1 : 0, s: tidak > 1 ? 1 : 0, i: tidak > 2 ? 1 : 0, a: tidak ? 1 : 0, b: 0, persen: Math.round((1000 * h) / m.pertemuan) / 10 }] })) })) }
    },
    /** 14.34.0: kehadiran santri per jam pelajaran (JP) satu kelas pada satu tanggal, dari absensi jurnal mengajar. */
    async kehadiranKelasHarian(group, tanggal) {
      if (!MODE_DEMO) return rpc('kehadiran_kelas_harian', { p_group: group, p_tanggal: tanggal })
      await this.muat(); const d = dataJadwalDemo(); const san = useSantri(); await san.muat(); const kel = dataKelompokDemo(san.daftar)
      const hari = new Date(tanggal + 'T00:00:00').getDay() || 7; const lewat = tanggal <= hariIniISO()
      const jp = d.jadwal.filter((x) => x.group_id === group && x.hari === hari).map((x) => ({ x, p: d.jam.find((q) => q.id === x.period_id) })).filter((y) => y.p)
        .sort((a, b) => a.p.urutan - b.p.urutan).map(({ x, p }, i) => { const t = d.penugasan.find((q) => q.id === x.assignment_id); const m = this.cariMapel(t?.subject_id)
          return { period_id: p.id, urutan: Number(p.nama.replace(/\D/g, '')) || p.urutan, nama: p.nama, jam: `${p.jam_mulai}–${p.jam_selesai}`.replace(/:/g, '.'), assignment_id: t?.id, mapel: m?.nama, kode_mapel: m?.kode,
            guru: t?.nama_guru, materi: null, keadaan: !lewat ? 'belum' : i === 5 ? 'belum' : i === 4 && hari === 3 ? 'tidak' : 'terisi' } })
      const anggota = kel.anggota.filter((a) => a.group_id === group && !a.selesai).map((a) => san.cari(a.student_id)).filter((x) => x && x.status !== 'nonaktif')
      const kode = ['S', 'I', 'A', 'T', 'B']
      return { tanggal, kelas: { id: group, nama: kel.kelompok.find((g) => g.id === group)?.nama || 'Kelas' }, jp,
        santri: anggota.sort((a, b) => a.nama_lengkap.localeCompare(b.nama_lengkap)).map((st, si) => ({ student_id: st.id, nis: st.nis, nama: st.nama_lengkap, jk: st.jenis_kelamin,
          kode: Object.fromEntries(jp.filter((j) => j.keadaan === 'terisi').map((j, ji) => [j.period_id, si === 2 ? 'S' : (si * 7 + ji * 3 + hari) % 17 === 0 ? kode[(si + ji) % 5] : 'H'])) })) }
    },
    /** 14.34.0: kehadiran santri per pertemuan (P1, P2, …) satu penugasan mapel. */
    async kehadiranPertemuanMapel(assignment, mulai, selesai) {
      if (!MODE_DEMO) return rpc('kehadiran_pertemuan_mapel', { p_assignment: assignment, p_mulai: mulai, p_selesai: selesai })
      await this.muat(); const d = dataJadwalDemo(); const san = useSantri(); await san.muat(); const kel = dataKelompokDemo(san.daftar)
      const t = d.penugasan.find((x) => x.id === assignment); if (!t) throw new Error('Penugasan mengajar tidak ditemukan.')
      const hariAjar = [...new Set(d.jadwal.filter((x) => x.assignment_id === assignment).map((x) => x.hari))]
      const per = []; const akhir = selesai > hariIniISO() ? hariIniISO() : selesai
      for (let x = new Date(mulai + 'T00:00:00'); x.toISOString().slice(0, 10) <= akhir && per.length < 40; x.setDate(x.getDate() + 1)) {
        const tg = `${x.getFullYear()}-${String(x.getMonth() + 1).padStart(2, '0')}-${String(x.getDate()).padStart(2, '0')}`
        if (hariAjar.includes(x.getDay() || 7) && tg <= akhir) per.push({ ke: per.length + 1, tanggal: tg, jp: 'JP ' + (1 + (per.length % 3) * 2) + '–' + (2 + (per.length % 3) * 2), materi: `Pembahasan ${per.length + 1}` })
      }
      const m = this.cariMapel(t.subject_id)
      const anggota = kel.anggota.filter((a) => a.group_id === t.group_id && !a.selesai).map((a) => san.cari(a.student_id)).filter((x) => x && x.status !== 'nonaktif')
      return { mulai, selesai, kelas: { id: t.group_id, nama: kel.kelompok.find((g) => g.id === t.group_id)?.nama || 'Kelas' }, mapel: { assignment_id: t.id, nama: m?.nama, kode: m?.kode, guru: t.nama_guru },
        pertemuan: per, santri: anggota.sort((a, b) => a.nama_lengkap.localeCompare(b.nama_lengkap)).map((st, si) => {
          const kode = per.map((p, pi) => ((si * 5 + pi * 3) % 13 === 0 ? ['S', 'I', 'A', 'T', 'B'][(si + pi) % 5] : 'H'))
          const hadir = kode.filter((k) => ['H', 'T'].includes(k)).length
          return { student_id: st.id, nis: st.nis, nama: st.nama_lengkap, jk: st.jenis_kelamin, kode, hadir, total: kode.length, persen: kode.length ? Math.round((1000 * hadir) / kode.length) / 10 : null } }) }
    },
    /** 14.4.0: laporan jurnal mengajar. p: { assignment_id | group_id | employee_id, subject_id?, mulai, selesai } */
    async laporanJurnal(p) {
      if (!MODE_DEMO) return rpc('laporan_jurnal_mengajar', { p })
      await this.muat(); const d = dataJadwalDemo()
      const tugas = d.penugasan.filter((t) => (!p.assignment_id || t.id === p.assignment_id) && (!p.group_id || t.group_id === p.group_id)
        && (!p.employee_id || t.employee_id === p.employee_id) && (!p.subject_id || t.subject_id === p.subject_id))
      const ids = new Set(tugas.map((t) => t.id)); const kel = dataKelompokDemo([]).kelompok
      const slot = (await this.slot(p.mulai, p.selesai)).filter((x) => ids.has(x.assignment_id) && ['terlaksana', 'tidak_terlaksana'].includes(x.status))
      const per = new Map()
      for (const x of slot) { const k = x.assignment_id + x.tanggal; const a = per.get(k); if (a) { a.jp++; a.jam_selesai = x.jam_selesai; a.jam_ke = a.jam_ke.split(' – ')[0] + ' – ' + x.jam_ke } else per.set(k, { ...x, jp: 1 }) }
      const METODE = [['Ceramah', 'Tanya jawab'], ['Diskusi'], ['Penugasan', 'Praktik'], ['Demonstrasi']]
      return { mulai: p.mulai, selesai: p.selesai,
        penugasan: tugas.map((t) => ({ assignment_id: t.id, group_id: t.group_id, kelas: kel.find((g) => g.id === t.group_id)?.nama, subject_id: t.subject_id, mapel: this.cariMapel(t.subject_id)?.nama,
          kode_mapel: this.cariMapel(t.subject_id)?.kode, employee_id: t.employee_id, guru: t.nama_guru, niy: null, wali: { nama: (kel.find((g) => g.id === t.group_id)?.pengasuh || [])[0]?.nama || '', niy: null } })),
        pertemuan: [...per.values()].map((x, i) => ({ assignment_id: x.assignment_id, tanggal: x.tanggal, kelas: x.kelas, mapel: x.mapel, guru: x.guru, jp: x.jp, jam_ke: x.jam_ke,
          jam_mulai: x.jam_mulai, jam_selesai: x.jam_selesai, status: x.status, bab: x.materi, subbab: x.status === 'terlaksana' ? 'Pembahasan ' + (i % 5 + 1) : null, materi: x.materi,
          tujuan: x.status === 'terlaksana' ? 'Santri memahami ' + String(x.materi || '').toLowerCase() : null, kegiatan: null,
          metode: x.status === 'terlaksana' ? METODE[i % 4] : [], media: x.status === 'terlaksana' ? ['Papan tulis'] : [], alat: i % 3 ? ['Laptop'] : [], sumber: x.status === 'terlaksana' ? ['Buku paket'] : [],
          keterangan: x.keterangan, jumlah_anggota: x.status === 'terlaksana' ? 3 : null, jumlah_hadir: x.status === 'terlaksana' ? 3 - (i % 4 === 0 ? 1 : 0) : null,
          tidak_hadir: x.status === 'terlaksana' && i % 4 === 0 ? [{ nama: 'Ahmad Fauzan', kode: 'S' }] : [] })) }
    },
    async slot(mulai, selesai, group = null, emp = null) {
      if (!MODE_DEMO) return (await rpc('slot_mengajar', { p_mulai: mulai, p_selesai: selesai, p_group: group, p_emp: emp })) || []
      await this.muat(); const d = dataJadwalDemo(); const kel = useKelompokSantri(); await kel.muat()
      const kini = new Date(); const hasil = []; const MATERI = ['Pengenalan bab baru', 'Latihan soal', 'Diskusi kelompok', 'Ulangan harian', 'Pembahasan tugas', 'Praktik']
      for (let t = mulai; t <= selesai; ) {
        const dt = new Date(`${t}T12:00:00+08:00`); const dow = dt.getUTCDay()
        if (dow !== 0) {
          for (const sc of d.jadwal.filter((x) => x.hari === dow && (!group || x.group_id === group) && (!emp || x.employee_id === emp))) {
            const tg = d.penugasan.find((x) => x.id === sc.assignment_id); const p = d.jam.find((x) => x.id === sc.period_id); const g = dataKelompokDemo([]).kelompok.find((x) => x.id === sc.group_id)
            const lewat = new Date(`${t}T${p.jam_selesai}:00+08:00`) <= kini
            const jr = d.jurnal.find((x) => x.assignment_id === tg.id && x.tanggal === t && x.period_id === p.id)
            const h = [...(t + sc.id)].reduce((n, c) => (n * 31 + c.charCodeAt(0)) % 997, 7)
            const st = jr ? jr.status : !lewat ? 'belum' : h % 17 === 0 ? 'tidak_terlaksana' : h % 9 === 0 ? 'belum' : 'terlaksana'
            hasil.push({ tanggal: t, jam_ke: p.nama, urutan: p.urutan, jam_mulai: p.jam_mulai, jam_selesai: p.jam_selesai, group_id: sc.group_id, kelas: g?.nama, jenjang: g?.jenjang,
              assignment_id: tg.id, period_id: p.id, mapel: d.mapel.find((m) => m.id === tg.subject_id)?.nama, employee_id: tg.employee_id, guru: tg.nama_guru, niy: null, no_hp: '081234500000', wali_kelas: (g?.pengasuh || []).map((x) => x.nama).join(', ') || null,
              status: st, materi: jr?.materi || (st === 'terlaksana' ? MATERI[h % MATERI.length] : null), keterangan: jr?.keterangan || (st === 'tidak_terlaksana' ? 'Guru dinas luar' : null), pengisi: null, lewat })
          }
        }
        dt.setUTCDate(dt.getUTCDate() + 1); t = dt.toISOString().slice(0, 10)
      }
      return hasil.sort((a, b) => a.tanggal.localeCompare(b.tanggal) || a.jam_mulai.localeCompare(b.jam_mulai) || String(a.kelas).localeCompare(String(b.kelas)))
    },
    idSaya,
  },
})
