// SIMKA PRO | src/stores/shift.js | v1.0 | Fase 2 – Tahap 5 Jadwal shift | 03/10/2026
// Jadwal shift (medis, security) dan tukar shift. Semua penulisan lewat fungsi server
// (simpan_jadwal_shift, ajukan/jawab/putuskan/batalkan_tukar_shift) yang memeriksa hak.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { useAturPresensi } from './aturPresensi'
import { usePegawai } from './pegawai'
import { useSesi } from './sesi'
import { buatBergilir, seninDari, tambahHari } from '@/lib/shift'
import { hariIniISO, sekarang } from '@/lib/tanggal'

async function rpc(nama, isi) {
  const { data, error } = await supabase.rpc(nama, isi)
  if (error) throw new Error(error.hint && error.message ? error.message : pesanGalat(error))
  return data
}
const idDemo = () => 'r-' + Math.random().toString(36).slice(2, 10)

export const useShift = defineStore('shift', {
  state: () => ({ demoRoster: [], demoTukar: [], demoSiap: false }),
  actions: {
    /** Mode demo: susun jadwal bergilir 6 pekan untuk semua pola shift. */
    siapkanDemo() {
      if (this.demoSiap) return
      const atur = useAturPresensi()
      const senin = tambahHari(seninDari(hariIniISO()), -7)
      for (const p of atur.pola.filter((x) => x.jenis === 'shift')) {
        const pegawai = [...new Set(atur.jadwal.filter((j) => j.pattern_id === p.id && j.aktif).map((j) => j.employee_id))]
        const sesi = atur.sesiPola(p.id).filter((s) => s.aktif).map((s) => s.id)
        if (pegawai.length < sesi.length) continue
        buatBergilir({ pegawai, sesi, mulai: senin, hari: 42, blok: pegawai.length > sesi.length ? 2 : 1 })
          .forEach((r) => this.demoRoster.push({ ...r, id: idDemo(), catatan: null }))
      }
      this.demoSiap = true
    },
    demoMulai(r) {
      const s = useAturPresensi().sesi.find((x) => x.id === r.session_id)
      return new Date(`${r.tanggal}T${String(s?.jam_mulai || '00:00').slice(0, 5)}:00+08:00`)
    },

    /** { pegawai:[{id,nama,niy}], roster:[…], tukar:[…] } untuk satu pola pada rentang tanggal */
    async muat(polaId, mulai, akhir) {
      if (!MODE_DEMO) return await rpc('data_shift', { p_pola: polaId, p_mulai: mulai, p_akhir: akhir })
      this.siapkanDemo()
      const atur = useAturPresensi(); const peg = usePegawai()
      const sesiIds = atur.sesiPola(polaId).map((s) => s.id)
      const pegawai = [...new Set(atur.jadwal.filter((j) => j.pattern_id === polaId && j.aktif).map((j) => j.employee_id))]
        .map((id) => peg.cari(id)).filter(Boolean).map((p) => ({ id: p.id, nama: p.nama_lengkap, niy: p.niy }))
        .sort((a, b) => a.nama.localeCompare(b.nama))
      const kini = sekarang()
      const roster = this.demoRoster.filter((r) => sesiIds.includes(r.session_id) && r.tanggal >= mulai && r.tanggal <= akhir)
        .map((r) => ({ ...r, ada_presensi: false, sudah_mulai: this.demoMulai(r) <= kini }))
      const nama = (id) => peg.cari(id)?.nama_lengkap || '–'
      const sesiNama = (id) => atur.sesi.find((s) => s.id === id)?.nama
      const tukar = this.demoTukar.filter((t) => sesiIds.includes(this.demoRoster.find((r) => r.id === t.roster_pemohon_id)?.session_id)).map((t) => {
        const a = this.demoRoster.find((r) => r.id === t.roster_pemohon_id); const b = this.demoRoster.find((r) => r.id === t.roster_penerima_id)
        return { ...t, pemohon: nama(t.pemohon_id), penerima: nama(t.penerima_id), tanggal_pemohon: a?.tanggal, sesi_pemohon: sesiNama(a?.session_id),
          tanggal_penerima: b?.tanggal || null, sesi_penerima: b ? sesiNama(b.session_id) : null }
      })
      return { pegawai, roster, tukar }
    },

    /** Simpan seluruh jadwal pola pada rentang (baris = [{employee_id, tanggal, session_id}]) */
    async simpan(polaId, mulai, akhir, baris) {
      if (!MODE_DEMO) return await rpc('simpan_jadwal_shift', { p_pola: polaId, p_mulai: mulai, p_akhir: akhir, p_baris: baris })
      const sesiIds = useAturPresensi().sesiPola(polaId).map((s) => s.id)
      const lama = this.demoRoster.filter((r) => sesiIds.includes(r.session_id) && r.tanggal >= mulai && r.tanggal <= akhir)
      const kunci = (r) => `${r.employee_id}|${r.tanggal}|${r.session_id}`
      const baru = new Set(baris.map(kunci)); const ada = new Set(lama.map(kunci))
      const dihapus = lama.filter((r) => !baru.has(kunci(r)))
      this.demoRoster = this.demoRoster.filter((r) => !dihapus.includes(r))
      const ditambah = baris.filter((r) => !ada.has(kunci(r)))
      ditambah.forEach((r) => this.demoRoster.push({ ...r, id: idDemo(), catatan: null }))
      return { dihapus: dihapus.length, ditambah: ditambah.length }
    },

    async ajukan({ roster, rekan, rosterRekan, alasan }) {
      if (!MODE_DEMO) return await rpc('ajukan_tukar_shift', { p_roster: roster, p_rekan: rekan, p_roster_rekan: rosterRekan || null, p_alasan: alasan })
      if (this.demoTukar.some((t) => ['menunggu_rekan', 'menunggu_admin'].includes(t.status) && [t.roster_pemohon_id, t.roster_penerima_id].includes(roster)))
        throw new Error('Shift ini sedang dalam permintaan tukar yang lain.')
      this.demoTukar.unshift({ id: idDemo(), pemohon_id: useSesi().pengguna?.id, penerima_id: rekan, roster_pemohon_id: roster, roster_penerima_id: rosterRekan || null,
        alasan, status: 'menunggu_rekan', created_at: new Date().toISOString() })
    },
    async jawab(id, setuju, catatan) {
      if (!MODE_DEMO) return await rpc('jawab_tukar_shift', { p_id: id, p_setuju: setuju, p_catatan: catatan || null })
      const t = this.demoTukar.find((x) => x.id === id); t.status = setuju ? 'menunggu_admin' : 'ditolak'; t.catatan_rekan = catatan
    },
    async putuskan(id, setuju, catatan) {
      if (!MODE_DEMO) return await rpc('putuskan_tukar_shift', { p_id: id, p_setuju: setuju, p_catatan: catatan || null })
      const t = this.demoTukar.find((x) => x.id === id)
      if (setuju) {
        const a = this.demoRoster.find((r) => r.id === t.roster_pemohon_id); if (a) a.employee_id = t.penerima_id
        const b = this.demoRoster.find((r) => r.id === t.roster_penerima_id); if (b) b.employee_id = t.pemohon_id
      }
      t.status = setuju ? 'disetujui' : 'ditolak'; t.catatan_admin = catatan
    },
    async batalkan(id) {
      if (!MODE_DEMO) return await rpc('batalkan_tukar_shift', { p_id: id })
      const t = this.demoTukar.find((x) => x.id === id); if (t) t.status = 'dibatalkan'
    },
  },
})
