// SIMKA PRO | src/stores/rapat.js | v1.1 | 14.29.0: demo peserta dan rekap urut jabatan | 26/10/2026
// Rapat lahir dari Agenda berjenis Rapat (peserta = sasaran agenda: tim kerja, bidang, jabatan, pegawai) atau dibuat admin.
// Peserta melihat rapatnya, konfirmasi hadir/izin, menekan "Saya hadir", dan membaca notulen. Admin/superadmin mengelola.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'
import { usePegawai } from './pegawai'
import { hariIniISO } from '@/lib/tanggal'
import { urutJabatan, urutkanPeserta } from '@/lib/rapat'

const rpc = async (nama, arg) => { const { data, error } = await supabase.rpc(nama, arg); if (error) throw new Error(pesanGalat(error)); return data }
const geser = (n) => { const d = new Date(hariIniISO() + 'T00:00:00Z'); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10) }

// ---------- Mode demo ----------
let DEMO = null
const saya = () => (useSesi().peran === 'pegawai' ? 'p1' : null)
async function demo() {
  if (DEMO) return DEMO
  const peg = usePegawai(); if (!peg.daftar.length) await peg.muat()
  const P = peg.daftar
  const ambil = (f) => P.filter(f).map((p) => p.id)
  const semua = P.map((p) => p.id)
  const buat = (id, h, judul, jenis, jam, js, lokasi, peserta, x = {}) => ({
    id, agenda_id: x.agenda ? 'ag5' : null, tanggal: geser(h), judul, jenis, org_unit_id: null, unit: x.unit || null, jam_mulai: jam, jam_selesai: js, lokasi, tautan: null,
    pimpinan_id: peserta[0], notulis_id: peserta[1] || null, ringkasan_sasaran: x.sasaran || null, status: x.status || (h < 0 ? 'selesai' : 'dijadwalkan'),
    pembahasan: x.pembahasan || null, keputusan: x.keputusan || null, tindak_lanjut: x.tl || [], catatan: null, notulen_pada: x.pembahasan ? new Date().toISOString() : null,
    peserta: peserta.map((e, i) => {
      const lalu = h < 0; const r = (i * 7 + h * 3 + 11) % 10
      const konf = lalu ? (r < 7 ? 'hadir' : r < 9 ? 'izin' : 'menunggu') : (r < 4 ? 'hadir' : r < 5 ? 'izin' : 'menunggu')
      return { employee_id: e, konfirmasi: konf, alasan: konf === 'izin' ? 'Mendampingi santri lomba' : null, dikonfirmasi_pada: konf !== 'menunggu' ? new Date().toISOString() : null,
        kehadiran: lalu ? (konf === 'hadir' ? (r === 3 ? 'terlambat' : 'hadir') : konf === 'izin' ? 'izin' : 'alpa') : null, hadir_pada: null, catatan: null }
    }),
  })
  DEMO = [
    buat('rp1', 1, 'Rapat pekanan Pengurus Harian', 'pimpinan', '20:30', '21:30', 'Ruang Direktur', ambil((p) => /Kepala|Direktur|Wakil/i.test(p.jabatan_struktural || '')).concat(['p1']).slice(0, 8), { agenda: true, sasaran: 'Tim kerja: Pengurus Harian (PH)' }),
    buat('rp2', 3, 'Rapat Bidang Tahfizh: persiapan ujian kenaikan juz', 'bidang', '13:30', '15:00', 'Masjid Pondok', ambil((p) => /Tahfizh/.test(p.nama_unit || '')).concat(['p1']), { unit: 'Bidang Tahfizh', sasaran: 'Bidang Tahfizh' }),
    buat('rp3', 6, 'Rapat koordinasi seluruh pegawai', 'koordinasi', '20:00', '21:30', 'Aula Utama', semua, { sasaran: 'Semua pegawai' }),
    buat('rp4', -4, 'Rapat pekanan Pengurus Harian', 'pimpinan', '20:30', '21:30', 'Ruang Direktur', ambil((p) => /Kepala|Direktur|Wakil/i.test(p.jabatan_struktural || '')).concat(['p1']).slice(0, 8), {
      agenda: true, sasaran: 'Tim kerja: Pengurus Harian (PH)', pembahasan: 'Evaluasi kegiatan pekan lalu, persiapan ujian semester, dan kebersihan asrama.',
      keputusan: '1. Ujian tengah semester dimulai 10 November.\n2. Jadwal piket kebersihan asrama diperbarui mulai Sabtu.', tl: [{ tugas: 'Menyusun jadwal ujian', pj: 'Bidang Kesetaraan Wustha', tenggat: geser(3) }, { tugas: 'Membagikan jadwal piket baru', pj: 'Bidang Kesantrian', tenggat: geser(1) }] }),
    buat('rp5', -11, 'Rapat Bidang Kesantrian', 'bidang', '16:00', '17:00', 'Kantor Kesantrian', ambil((p) => /Kesantrian|Security|Klinik/.test(p.nama_unit || '')).concat(['p1']), {
      unit: 'Bidang Kesantrian', pembahasan: 'Pembinaan santri yang sering terlambat kembali ke asrama.', keputusan: 'Musyrif mencatat keterlambatan harian dan melapor tiap Kamis.' }),
  ]
  return DEMO
}
function ringkasDemo(m) {
  const n = (f) => m.peserta.filter(f).length; const s = saya()
  const p = m.peserta.find((x) => x.employee_id === s)
  return { id: m.id, agenda_id: m.agenda_id, tanggal: m.tanggal, judul: m.judul, jenis: m.jenis, unit: m.unit, jam_mulai: m.jam_mulai, jam_selesai: m.jam_selesai, lokasi: m.lokasi, status: m.status,
    ringkasan_sasaran: m.ringkasan_sasaran, pimpinan: usePegawai().cari(m.pimpinan_id)?.nama_lengkap, ada_notulen: !!m.notulen_pada, peserta: m.peserta.length,
    konf_hadir: n((x) => x.konfirmasi === 'hadir'), konf_izin: n((x) => ['izin', 'sakit', 'dinas_luar'].includes(x.konfirmasi)), hadir: n((x) => ['hadir', 'terlambat'].includes(x.kehadiran)),
    tercatat: n((x) => x.kehadiran), saya: p ? { konfirmasi: p.konfirmasi, kehadiran: p.kehadiran } : null }
}
function detailDemo(m) {
  const peg = usePegawai(); const s = saya(); const admin = useSesi().isAdmin
  if (!admin && !m.peserta.some((x) => x.employee_id === s)) throw new Error('Rapat ini hanya dapat dibuka peserta yang diundang.')
  const nama = (id) => peg.cari(id)?.nama_lengkap || null
  return { rapat: { ...m, peserta: undefined, pimpinan: nama(m.pimpinan_id), pimpinan_niy: peg.cari(m.pimpinan_id)?.niy, notulis: nama(m.notulis_id), notulis_niy: peg.cari(m.notulis_id)?.niy,
      agenda_judul: m.agenda_id ? m.judul : null }, boleh_kelola: admin, saya: m.peserta.find((x) => x.employee_id === s) || null,
    peserta: urutkanPeserta(m.peserta.map((x) => { const p = peg.cari(x.employee_id) || {}
      return { ...x, nama: p.nama_lengkap, niy: p.niy, jenis_kelamin: p.jenis_kelamin, no_hp: admin ? p.no_hp || '081234500000' : null, unit: p.nama_unit, jabatan: p.jabatan_struktural || (p.jabatan_fungsional || []).join(', '), urut: urutJabatan(p.jabatan_struktural, p.jabatan_fungsional) } })) }
}

export const useRapat = defineStore('rapat', {
  state: () => ({ daftar: [], memuat: false }),
  actions: {
    async muat(mulai, selesai) {
      this.memuat = true
      try {
        if (MODE_DEMO) { const d = await demo(); const s = saya(); this.daftar = d.filter((m) => m.tanggal >= mulai && m.tanggal <= selesai && (useSesi().isAdmin || m.peserta.some((x) => x.employee_id === s))).map(ringkasDemo).sort((a, b) => b.tanggal.localeCompare(a.tanggal)) }
        else this.daftar = (await rpc('daftar_rapat', { p_mulai: mulai, p_selesai: selesai })) || []
        return this.daftar
      } finally { this.memuat = false }
    },
    async detail(id) {
      if (MODE_DEMO) { const m = (await demo()).find((x) => x.id === id); if (!m) throw new Error('Rapat tidak ditemukan.'); return detailDemo(m) }
      return await rpc('detail_rapat', { p_id: id })
    },
    async dariAgenda(agenda, tanggal) {
      if (MODE_DEMO) { const d = await demo(); return (d.find((m) => m.agenda_id && m.tanggal === tanggal) || d[0]).id }
      return await rpc('rapat_dari_agenda', { p_agenda: agenda, p_tanggal: tanggal })
    },
    async simpan(isi) {
      if (MODE_DEMO) {
        const d = await demo(); const peg = usePegawai()
        let m = d.find((x) => x.id === isi.id)
        if (!m) { m = { id: 'rp' + Date.now(), agenda_id: null, peserta: [], tindak_lanjut: [], status: 'dijadwalkan', notulen_pada: null }; d.unshift(m) }
        Object.assign(m, { tanggal: isi.tanggal, judul: isi.judul, jenis: isi.jenis, org_unit_id: isi.org_unit_id || null, jam_mulai: isi.jam_mulai || null, jam_selesai: isi.jam_selesai || null,
          lokasi: isi.lokasi || null, tautan: isi.tautan || null, pimpinan_id: isi.pimpinan_id || null, notulis_id: isi.notulis_id || null, status: isi.status || m.status,
          ringkasan_sasaran: isi.ringkasan_sasaran || m.ringkasan_sasaran || null, unit: null })
        const tambah = [...(isi.tambah || []), ...(isi.sasaran ? (isi.sasaran.jenis === 'semua' ? peg.daftar.map((p) => p.id) : [...(isi.sasaran.pegawai || []), ...peg.daftar.filter((p) => (isi.sasaran.unit || []).length && (isi.sasaran.unit || []).includes(p.org_unit_id)).map((p) => p.id)]) : []), isi.pimpinan_id, isi.notulis_id].filter(Boolean)
        for (const e of tambah) if (!m.peserta.some((x) => x.employee_id === e)) m.peserta.push({ employee_id: e, konfirmasi: 'menunggu', alasan: null, kehadiran: null })
        m.peserta = m.peserta.filter((x) => !(isi.hapus || []).includes(x.employee_id))
        return m.id
      }
      return await rpc('simpan_rapat', { p: isi })
    },
    async hapus(id) {
      if (MODE_DEMO) { DEMO = (await demo()).filter((x) => x.id !== id); return }
      await rpc('hapus_rapat', { p_id: id })
    },
    async konfirmasi(id, status, alasan) {
      if (MODE_DEMO) {
        const p = (await demo()).find((x) => x.id === id)?.peserta.find((x) => x.employee_id === saya())
        if (!p) throw new Error('Anda tidak termasuk peserta rapat ini.')
        if (status !== 'hadir' && (alasan || '').trim().length < 3) throw new Error('Tuliskan alasan singkat (minimal 3 huruf).')
        Object.assign(p, { konfirmasi: status, alasan: status === 'hadir' ? null : alasan.trim(), dikonfirmasi_pada: new Date().toISOString() }); return
      }
      await rpc('konfirmasi_rapat', { p_id: id, p_status: status, p_alasan: alasan || null })
    },
    async hadir(id) {
      if (MODE_DEMO) { const p = (await demo()).find((x) => x.id === id)?.peserta.find((x) => x.employee_id === saya()); if (!p) throw new Error('Anda tidak termasuk peserta rapat ini.'); Object.assign(p, { kehadiran: 'hadir', konfirmasi: 'hadir', hadir_pada: new Date().toISOString() }); return 'hadir' }
      return await rpc('hadir_rapat', { p_id: id })
    },
    /** isi: [{ employee_id, kehadiran, catatan? }] */
    async simpanKehadiran(id, isi) {
      if (MODE_DEMO) { const m = (await demo()).find((x) => x.id === id); for (const r of isi) { const p = m.peserta.find((x) => x.employee_id === r.employee_id); if (p) { p.kehadiran = r.kehadiran || null; if ('catatan' in r) p.catatan = r.catatan } } return }
      await rpc('simpan_kehadiran_rapat', { p_id: id, p: isi })
    },
    async simpanNotulen(id, isi) {
      if (MODE_DEMO) {
        const m = (await demo()).find((x) => x.id === id); Object.assign(m, { pembahasan: isi.pembahasan, keputusan: isi.keputusan, tindak_lanjut: isi.tindak_lanjut, catatan: isi.catatan })
        if (isi.selesai) { m.status = 'selesai'; m.notulen_pada ||= new Date().toISOString(); for (const p of m.peserta) if (!p.kehadiran) p.kehadiran = ['izin', 'sakit', 'dinas_luar'].includes(p.konfirmasi) ? p.konfirmasi : 'alpa' }
        return
      }
      await rpc('simpan_notulen_rapat', { p_id: id, p: isi })
    },
    async rekap(mulai, selesai, jenis = null, unit = null) {
      if (MODE_DEMO) {
        const d = (await demo()).filter((m) => m.tanggal >= mulai && m.tanggal <= selesai && m.status !== 'batal' && (!jenis || m.jenis === jenis)); const peg = usePegawai(); const per = {}
        for (const m of d) for (const p of m.peserta) { const x = per[p.employee_id] ||= { employee_id: p.employee_id, nama: peg.cari(p.employee_id)?.nama_lengkap, niy: peg.cari(p.employee_id)?.niy, unit: peg.cari(p.employee_id)?.nama_unit, urut: urutJabatan(peg.cari(p.employee_id)?.jabatan_struktural, peg.cari(p.employee_id)?.jabatan_fungsional), undangan: 0, hadir: 0, terlambat: 0, izin: 0, alpa: 0 }
          if (m.status === 'selesai' || m.tanggal < hariIniISO()) x.undangan++; if (['hadir', 'terlambat'].includes(p.kehadiran)) x.hadir++; if (p.kehadiran === 'terlambat') x.terlambat++; if (['izin', 'sakit', 'dinas_luar'].includes(p.kehadiran)) x.izin++; if (p.kehadiran === 'alpa') x.alpa++ }
        return { rapat: d.map((m) => ({ id: m.id, tanggal: m.tanggal, judul: m.judul, jenis: m.jenis, unit: m.unit, status: m.status, peserta: m.peserta.length,
          hadir: m.peserta.filter((p) => ['hadir', 'terlambat'].includes(p.kehadiran)).length, terlambat: m.peserta.filter((p) => p.kehadiran === 'terlambat').length,
          izin: m.peserta.filter((p) => ['izin', 'sakit', 'dinas_luar'].includes(p.kehadiran)).length, alpa: m.peserta.filter((p) => p.kehadiran === 'alpa').length })).sort((a, b) => a.tanggal.localeCompare(b.tanggal)),
          pegawai: urutkanPeserta(Object.values(per)) }
      }
      return await rpc('rekap_rapat', { p_mulai: mulai, p_selesai: selesai, p_jenis: jenis, p_unit: unit })
    },
  },
})
