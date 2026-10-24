// SIMKA PRO | src/stores/tahsin.js | v1.1 | 14.21.0: ujian tahsin (Makhraj, Shifat, hasil) dan riwayat ujian | 24/10/2026
// Tahsin terpadu dengan Tahfizh. Penulisan hanya lewat fungsi SQL (security definer). Mode demo menyimpan data di memori.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'
import { useTahfizh } from './tahfizh'
import { TAHAPAN_BAWAAN, CATATAN_LULUS_BAWAAN } from '@/lib/tahsin'
import { PEGAWAI_DEMO } from '@/lib/demo'
import { hariIniISO } from '@/lib/tanggal'

const rpc = async (nama, arg) => { const { data, error } = await supabase.rpc(nama, arg); if (error) throw new Error(pesanGalat(error)); return data }

// ---------- Mode demo ----------
let DEMO = null; let SET = null; let urut = 0
const geser = (hari) => { const d = new Date(Date.now() + 8 * 3600e3 - hari * 864e5); return d.toISOString().slice(0, 10) }
const selisih = (a, b = hariIniISO()) => Math.round((new Date(b) - new Date(a)) / 864e5)
const setDemo = () => (SET || (SET = { tahapan: TAHAPAN_BAWAAN.map((t) => ({ ...t })), catatan_lulus: CATATAN_LULUS_BAWAAN }))
const pengelolaDemo = () => useSesi().peran !== 'pegawai'
const namaSaya = () => useSesi().pengguna?.nama_lengkap || 'Ust. Hasan Basri, Lc.'
async function demo() {
  if (DEMO) return DEMO
  const tz = useTahfizh(); if (!tz.santri.length) await tz.muatSantri()
  const calon = [...tz.santri].sort((a, b) => a.sabaq_hal - b.sabaq_hal).slice(0, 4)
  const MATERI = ['Makhraj halqi (tenggorokan)', 'Makhraj lisani', 'Sifat hams dan jahr', 'Qalqalah sughra dan kubra', 'Tanwin dan tasydid', 'Izhar halqi', 'Ikhfa haqiqi']
  DEMO = calon.map((s, i) => {
    const mulai = geser(20 + i * 12); const tahap = [2, 3, 5, 8][i] || 1
    const n = 3 + i * 2; const tl = (k) => Math.max(1, tahap - (n - 1 - k))
    const log = Array.from({ length: n }, (_, k) => {
      const naik = k < n - 1 && tl(k + 1) > tl(k)
      return { id: `tl${i}-${k}`, tanggal: geser(18 + i * 12 - k * 2), tahap: tl(k), materi: MATERI[(k + i) % MATERI.length],
        nilai: naik ? 'lancar' : k % 3 === 2 ? 'cukup' : k % 4 === 3 ? 'perlu_ulang' : 'lancar', naik_tahap: naik, catatan: k === 0 ? 'Huruf ain dan hamzah masih tertukar.' : '', oleh: 'Ust. Hasan Basri, Lc.' }
    }).sort((a, b) => (a.tanggal < b.tanggal ? 1 : -1))
    return { id: 'ts' + i, student_id: s.student_id, nis: s.nis, nama: s.nama, jenis_kelamin: s.jenis_kelamin, kelas: s.kelas, halaqah: s.halaqah, status: 'berjalan', mulai, selesai: null,
      sumber: i === 1 ? 'pindahan' : 'santri_baru', tahap_awal: 1, tahap, catatan: i === 1 ? 'Pindahan dari pesantren lain; bacaan cepat tetapi makhraj belum tepat.' : null,
      pembina_id: 'p1', pembina: 'Ust. Hasan Basri, Lc.', muhaffizh: 'Ust. Hasan Basri, Lc.', wali: { nama: 'Bapak ' + s.nama.split(' ')[0], hubungan: 'ayah', no_hp: '081355500123' },
      diajukan_lulus_pada: i === 3 ? new Date(Date.now() - 864e5).toISOString() : null, pengaju: i === 3 ? 'Ust. Hasan Basri, Lc.' : null, catatan_ajuan: i === 3 ? 'Seluruh tahapan tuntas; tilawah sudah tartil.' : null,
      dicatat_oleh: 'Ust. Hasan Basri, Lc.', dicatat_pada: mulai, _log: log, _ujian: [] }
  })
  // 14.21.0: contoh satu santri yang sudah lulus ujian tahsin
  const s = tz.santri[5] || tz.santri[0]
  if (s) DEMO.push({ id: 'tsL', student_id: s.student_id, nis: s.nis, nama: s.nama, jenis_kelamin: s.jenis_kelamin, kelas: s.kelas, halaqah: s.halaqah, status: 'lulus', mulai: geser(70), selesai: geser(5),
    sumber: 'santri_baru', tahap_awal: 1, tahap: 8, catatan: null, pembina_id: 'p1', pembina: 'Ust. Hasan Basri, Lc.', muhaffizh: 'Ust. Hasan Basri, Lc.', wali: { nama: 'Bapak ' + s.nama.split(' ')[0], hubungan: 'ayah', no_hp: '081355500123' },
    pemutus: 'Ust. Abdurrahman Hafizh, Lc.', catatan_selesai: 'Lulus ujian tahsin (Makhraj 86, Shifat 82)', _log: [],
    _ujian: [{ id: 'ux1', tanggal: geser(5), makhraj: 86, shifat: 82, nilai: 84, hasil: 'lulus', catatan: 'Makhraj dan sifat huruf sudah tepat.', penguji: 'Ust. Abdurrahman Hafizh, Lc.', dokumen_id: null }] })
  return DEMO
}
function bentukDemo(t) {
  const n = setDemo().tahapan.length; const b = t.status === 'berjalan'
  return { ...t, _log: undefined, tahap_nama: setDemo().tahapan[t.tahap - 1]?.nama || `Tahap ${t.tahap}`, jumlah_tahap: n, lama_hari: selisih(t.mulai, t.selesai || hariIniISO()),
    pertemuan: t._log.length, lancar: t._log.filter((l) => l.nilai === 'lancar').length, terakhir: t._log[0] || null,
    boleh_bina: b, boleh_putus: b && pengelolaDemo(), boleh_uji: b && pengelolaDemo(), boleh_hapus: t.status === 'dihentikan' && pengelolaDemo(), ujian: t._ujian || [] }
}

export const useTahsin = defineStore('tahsin', {
  state: () => ({ pengaturan: null, penanda: {}, penandaDimuat: false }),
  getters: {
    tahapan: (s) => s.pengaturan?.tahapan?.length ? s.pengaturan.tahapan : TAHAPAN_BAWAAN,
    bolehKelola: (s) => !!s.pengaturan?.boleh_kelola,
    bolehAtur: (s) => !!s.pengaturan?.boleh_atur,
  },
  actions: {
    async muatPengaturan() {
      if (MODE_DEMO) { this.pengaturan = { ...setDemo(), boleh_kelola: pengelolaDemo(), boleh_atur: pengelolaDemo() }; return this.pengaturan }
      this.pengaturan = (await rpc('pengaturan_tahsin')) || {}
      return this.pengaturan
    },
    async simpanPengaturan(p) {
      if (MODE_DEMO) {
        const t = (p.tahapan || []).filter((x) => String(x.nama || '').trim().length >= 3)
        if (t.length < 2 || t.length > 20) throw new Error('Tahapan tahsin berisi 2 sampai 20 tahap (nama minimal 3 huruf).')
        SET = { tahapan: t.map((x) => ({ nama: x.nama.trim(), uraian: (x.uraian || '').trim() || null })), catatan_lulus: p.catatan_lulus }
        ;(DEMO || []).forEach((x) => { if (x.tahap > t.length) x.tahap = t.length })
        return this.muatPengaturan()
      }
      await rpc('simpan_pengaturan_tahsin', { p }); return this.muatPengaturan()
    },
    /** Penanda santri yang sedang tahsin: { student_id: { id, tahap, tahap_nama, jumlah_tahap, mulai } } — dipakai Setoran dan Data hafalan. */
    async muatPenanda() {
      try {
        if (MODE_DEMO) { const d = await demo(); this.penanda = Object.fromEntries(d.filter((t) => t.status === 'berjalan').map((t) => { const x = bentukDemo(t); return [t.student_id, { id: t.id, tahap: x.tahap, tahap_nama: x.tahap_nama, jumlah_tahap: x.jumlah_tahap, mulai: t.mulai }] })) }
        else this.penanda = (await rpc('santri_tahsin_aktif')) || {}
      } catch { this.penanda = {} }
      this.penandaDimuat = true
      return this.penanda
    },
    async daftar(status = 'berjalan') {
      if (MODE_DEMO) {
        const d = await demo()
        return d.filter((t) => !status || t.status === status || (status === 'menunggu' && t.status === 'berjalan' && t.diajukan_lulus_pada)).map(bentukDemo)
          .sort((a, b) => String(a.halaqah).localeCompare(String(b.halaqah), 'id') || a.nama.localeCompare(b.nama, 'id'))
      }
      return (await rpc('daftar_tahsin', { p_status: status })) || []
    },
    async calon() {
      if (MODE_DEMO) {
        const tz = useTahfizh(); const d = await demo(); const ada = new Set(d.filter((t) => t.status === 'berjalan').map((t) => t.student_id))
        return tz.santri.filter((s) => !ada.has(s.student_id)).map((s) => ({ student_id: s.student_id, nis: s.nis, nama: s.nama, jenis_kelamin: s.jenis_kelamin, kelas: s.kelas, halaqah: s.halaqah,
          jalur_masuk: 'baru', baru: s.tingkat === 7 || s.tingkat === 10, total_resmi: s.total_resmi, sabaq_hal: s.sabaq_hal, pernah_tahsin: d.some((t) => t.student_id === s.student_id && t.status === 'lulus') }))
          .sort((a, b) => Number(b.baru) - Number(a.baru) || a.sabaq_hal - b.sabaq_hal || a.nama.localeCompare(b.nama, 'id'))
      }
      return (await rpc('calon_tahsin')) || []
    },
    async pembina() {
      if (MODE_DEMO) return PEGAWAI_DEMO.filter((p) => p[4].includes('Muhaffizh') || p[3] === 'Bidang Tahfizh').map((p, i) => ({ id: 'p' + (i + 1), nama: p[0], niy: p[1] }))
      return (await rpc('pembina_tahsin')) || []
    },
    async riwayat(id) {
      if (MODE_DEMO) { const t = (await demo()).find((x) => x.id === id); const n = setDemo().tahapan; return (t?._log || []).map((l) => ({ ...l, tahap_nama: n[l.tahap - 1]?.nama || `Tahap ${l.tahap}` })) }
      return (await rpc('riwayat_tahsin', { p_id: id })) || []
    },
    /** p: { mulai, sumber, tahap, pembina_id, catatan } */
    async tandai(ids, p) {
      if (MODE_DEMO) {
        const c = await this.calon(); const d = await demo(); let n = 0
        if (p.mulai > hariIniISO()) throw new Error('Tanggal mulai tahsin tidak boleh melewati hari ini.')
        const pb = (await this.pembina()).find((x) => x.id === p.pembina_id)
        ids.forEach((id) => { const s = c.find((x) => x.student_id === id); if (!s) return; n++
          d.unshift({ id: 'ts' + Date.now() + n, ...s, status: 'berjalan', mulai: p.mulai || hariIniISO(), selesai: null, sumber: p.sumber || 'santri_baru', tahap_awal: Number(p.tahap) || 1, tahap: Number(p.tahap) || 1,
            catatan: p.catatan || null, pembina_id: pb?.id || 'p1', pembina: pb?.nama || 'Ust. Hasan Basri, Lc.', muhaffizh: 'Ust. Hasan Basri, Lc.', wali: { nama: 'Bapak ' + s.nama.split(' ')[0], hubungan: 'ayah', no_hp: '081355500123' },
            diajukan_lulus_pada: null, dicatat_oleh: namaSaya(), dicatat_pada: hariIniISO(), _log: [] }) })
        await this.muatPenanda(); return n
      }
      const n = await rpc('tandai_tahsin', { p_santri: ids, p }); await this.muatPenanda(); return n
    },
    /** isi: [{ id, materi, nilai, naik, catatan }] */
    async catat(tanggal, isi) {
      if (MODE_DEMO) {
        if (tanggal > hariIniISO()) throw new Error('Tanggal pertemuan tidak boleh melewati hari ini.')
        const d = await demo(); const maks = setDemo().tahapan.length; let n = 0
        isi.filter((x) => x.nilai).forEach((x) => {
          const t = d.find((y) => y.id === x.id); if (!t) return
          if (tanggal < t.mulai) throw new Error('Tanggal pertemuan sebelum tanggal mulai tahsin.')
          const lama = t._log.find((l) => l.tanggal === tanggal)
          const log = { id: lama?.id || 'tl' + Date.now() + n, tanggal, tahap: lama?.tahap || t.tahap, materi: x.materi || null, nilai: x.nilai, naik_tahap: !!x.naik && x.nilai === 'lancar', catatan: x.catatan || null, oleh: namaSaya() }
          t._log = [log, ...t._log.filter((l) => l.tanggal !== tanggal)].sort((a, b) => (a.tanggal < b.tanggal ? 1 : -1))
          const naik = t._log.filter((l) => l.naik_tahap).map((l) => l.tahap + 1)
          t.tahap = Math.min(maks, Math.max(t.tahap_awal, ...naik)); n++
        })
        await this.muatPenanda(); return n
      }
      const n = await rpc('catat_tahsin', { p_tanggal: tanggal, p_isi: isi }); await this.muatPenanda(); return n
    },
    async hapusCatatan(logId, tahsinId) {
      if (MODE_DEMO) { const t = (await demo()).find((x) => x.id === tahsinId); t._log = t._log.filter((l) => l.id !== logId); t.tahap = Math.min(setDemo().tahapan.length, Math.max(t.tahap_awal, ...t._log.filter((l) => l.naik_tahap).map((l) => l.tahap + 1))); return }
      return rpc('hapus_catatan_tahsin', { p_log: logId })
    },
    /** p: { pembina_id, tahap, catatan } */
    async ubah(id, p) {
      if (MODE_DEMO) { const t = (await demo()).find((x) => x.id === id); const pb = (await this.pembina()).find((x) => x.id === p.pembina_id)
        Object.assign(t, { tahap: Number(p.tahap) || t.tahap, tahap_awal: Math.min(t.tahap_awal, Number(p.tahap) || t.tahap), catatan: p.catatan ?? t.catatan, pembina_id: pb?.id || t.pembina_id, pembina: pb?.nama || t.pembina }); await this.muatPenanda(); return }
      await rpc('ubah_tahsin', { p_id: id, p }); await this.muatPenanda()
    },
    async ajukanLulus(id, catatan) {
      if (MODE_DEMO) { const t = (await demo()).find((x) => x.id === id); if (!t._log.length) throw new Error('Catat perkembangan tahsin sedikitnya satu kali sebelum mengajukan lulus.')
        Object.assign(t, { diajukan_lulus_pada: new Date().toISOString(), pengaju: namaSaya(), catatan_ajuan: catatan || null }); return }
      return rpc('ajukan_lulus_tahsin', { p_id: id, p_catatan: catatan || null })
    },
    async putuskan(id, lulus, catatan) {
      if (MODE_DEMO) {
        const t = (await demo()).find((x) => x.id === id)
        if (lulus) Object.assign(t, { status: 'lulus', selesai: hariIniISO(), tahap: setDemo().tahapan.length, pemutus: namaSaya(), catatan_selesai: catatan || null })
        else { if (String(catatan || '').trim().length < 5) throw new Error('Tuliskan catatan perbaikan (minimal 5 huruf).'); Object.assign(t, { diajukan_lulus_pada: null, pengaju: null, catatan_ajuan: 'Belum lulus: ' + catatan.trim() }) }
        await this.muatPenanda(); return
      }
      await rpc('putuskan_tahsin', { p_id: id, p_lulus: lulus, p_catatan: catatan || null }); await this.muatPenanda()
    },
    /** 14.21.0: nilai ujian tahsin. p: { tanggal, makhraj, shifat, hasil (lulus|belum_lulus), catatan } → { exam_id, nilai, hasil, dokumen } */
    async nilaiUjian(id, p) {
      if (MODE_DEMO) {
        const t = (await demo()).find((x) => x.id === id); const m = Number(p.makhraj); const sf = Number(p.shifat)
        if (!(m >= 0 && m <= 100 && sf >= 0 && sf <= 100) || p.makhraj === '' || p.shifat === '') throw new Error('Nilai Makhraj dan Shifat harus 0–100.')
        if (!['lulus', 'belum_lulus'].includes(p.hasil)) throw new Error('Pilih hasil ujian: Lulus atau Belum lulus.')
        if (p.hasil === 'belum_lulus' && String(p.catatan || '').trim().length < 5) throw new Error('Tuliskan catatan perbaikan untuk santri yang belum lulus (minimal 5 huruf).')
        const u = { id: 'ux' + Date.now(), tanggal: p.tanggal || hariIniISO(), makhraj: m, shifat: sf, nilai: Math.round(((m + sf) / 2) * 100) / 100, hasil: p.hasil, catatan: p.catatan || null, penguji: namaSaya(), dokumen_id: null }
        t._ujian = [u, ...(t._ujian || [])]
        if (p.hasil === 'lulus') Object.assign(t, { status: 'lulus', selesai: u.tanggal, tahap: setDemo().tahapan.length, pemutus: namaSaya(), catatan_selesai: `Lulus ujian tahsin (Makhraj ${m}, Shifat ${sf})` })
        else Object.assign(t, { diajukan_lulus_pada: null, pengaju: null, catatan_ajuan: `Belum lulus ujian tahsin: ${p.catatan}` })
        let dok = null
        if (p.hasil === 'lulus') {
          const tz = useTahfizh(); if (!tz.santri.length) await tz.muatSantri()
          const s = tz.santri.find((x) => x.student_id === t.student_id) || { student_id: t.student_id, nama: t.nama, nis: t.nis, kelas: t.kelas, halaqah: t.halaqah }
          dok = tz.demoDokumenBaru('suket_tahsin', s, { tanggal_ujian: u.tanggal, makhraj: m, shifat: sf, nilai: u.nilai, hasil: 'lulus', catatan: u.catatan, penguji: u.penguji, muhaffizh: t.muhaffizh, kkm: 75 })
          u.dokumen_id = dok.id
        }
        await this.muatPenanda(); return { exam_id: u.id, nilai: u.nilai, hasil: u.hasil, dokumen: dok ? { id: dok.id, nomor: dok.nomor } : null }
      }
      const h = await rpc('nilai_ujian_tahsin', { p_id: id, p }); await this.muatPenanda(); return h
    },
    /** 14.21.0: riwayat ujian tahsin pada rentang tanggal. */
    async daftarUjian(mulai = null, selesai = null) {
      if (MODE_DEMO) {
        return (await demo()).flatMap((t) => (t._ujian || []).map((u) => ({ ...u, tahsin_id: t.id, student_id: t.student_id, nis: t.nis, nama: t.nama, jenis_kelamin: t.jenis_kelamin,
          kelas: t.kelas, halaqah: t.halaqah, muhaffizh: t.muhaffizh, wali: t.wali, nomor: u.dokumen_id ? 'SKT.004/PPTQ-IAS/V/1448' : null })))
          .filter((u) => (!mulai || u.tanggal >= mulai) && (!selesai || u.tanggal <= selesai)).sort((a, b) => (a.tanggal < b.tanggal ? 1 : -1))
      }
      return (await rpc('daftar_ujian_tahsin', { p_mulai: mulai, p_selesai: selesai })) || []
    },
    async hentikan(id, alasan) {
      if (MODE_DEMO) { if (String(alasan || '').trim().length < 5) throw new Error('Tuliskan alasan penghentian (minimal 5 huruf).')
        Object.assign((await demo()).find((x) => x.id === id), { status: 'dihentikan', selesai: hariIniISO(), catatan_selesai: alasan.trim(), pemutus: namaSaya() }); await this.muatPenanda(); return }
      await rpc('hentikan_tahsin', { p_id: id, p_alasan: alasan }); await this.muatPenanda()
    },
  },
})
