// SIMKA PRO | src/stores/lapor.js | v1.0 | Fase 6 – Tahap 4 Lapor ke bidang dan dasbor ringkasan | 06/10/2026
// Lapor ke Bidang Terkait: hak, kategori, pengaturan anonim (superadmin), kirim, tindak lanjut, daftar, rekap.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'
import { useSantri } from './santri'
import { UNIT_PILIHAN } from '@/lib/lapor'

const rpc = async (nama, arg) => { const { data, error } = await supabase.rpc(nama, arg); if (error) throw new Error(pesanGalat(error)); return data }
const HAK_KOSONG = { kelola: false, superadmin: false, unit: [], anonim_diizinkan: false }
const KATEGORI_DEMO = [
  { kode: 'pelanggaran', nama: 'Pelanggaran/kedisiplinan', unit_kode: 'KESANTRIAN', ke_klinik: false, contoh: 'Santri berkelahi, keluar tanpa izin', aktif: true, urutan: 1 },
  { kode: 'kesehatan', nama: 'Kesehatan', unit_kode: 'KLINIK', ke_klinik: true, contoh: 'Santri tampak sakit', aktif: true, urutan: 2 },
  { kode: 'keamanan', nama: 'Keamanan', unit_kode: 'SECURITY', ke_klinik: false, contoh: 'Orang asing di area asrama', aktif: true, urutan: 3 },
  { kode: 'sarana', nama: 'Sarana', unit_kode: 'SARANA', ke_klinik: false, contoh: 'Kran asrama rusak, lampu mati', aktif: true, urutan: 4 },
  { kode: 'akademik', nama: 'Akademik/tahfizh', unit_kode: null, ke_klinik: false, contoh: 'Santri sering tidak membawa mushaf', aktif: true, urutan: 5 },
  { kode: 'lainnya', nama: 'Lainnya', unit_kode: null, ke_klinik: false, contoh: 'Informasi umum', aktif: true, urutan: 6 },
]
const jam = (j) => new Date(Date.now() + j * 3600000).toISOString()
let DEMO = null
function demo() {
  if (DEMO) return DEMO
  const s = useSantri().daftar
  const nUnit = (k) => UNIT_PILIHAN.find((u) => u.kode === k)?.n
  const r = (o) => ({ id: 'lp' + Math.random().toString(36).slice(2, 8), santri: [], lokasi: null, foto_id: null, mendesak: false, anonim: false, saya_pelapor: false, selesai_pada: null, jejak: [], ...o, unit: nUnit(o.unit_kode),
    nama_kategori: KATEGORI_DEMO.find((k) => k.kode === o.kategori).nama })
  DEMO = {
    pengaturan: { anonim_diizinkan: false },
    laporan: [
      r({ kategori: 'sarana', unit_kode: 'SARANA', pelapor: 'Ust. Syamsul Arifin, S.Pd.', lokasi: 'Kamar mandi Asrama Putra 1', uraian: 'Kran kamar mandi bocor sejak subuh, air terus mengalir.', mendesak: true, status: 'terkirim',
        waktu_kejadian: jam(-3), created_at: jam(-3), jejak: [{ status: 'terkirim', pada: jam(-3), oleh: 'Ust. Syamsul Arifin, S.Pd.' }] }),
      r({ kategori: 'pelanggaran', unit_kode: 'KESANTRIAN', pelapor: 'Ust. Hasan Basri, Lc.', saya_pelapor: true, lokasi: 'Halaman masjid', uraian: 'Dua santri berselisih setelah shalat Isya, sempat saling dorong.',
        santri: s.slice(3, 5).map((x) => ({ id: x.id, nama: x.nama_lengkap, kamar: null })), status: 'ditindaklanjuti', waktu_kejadian: jam(-20), created_at: jam(-19),
        jejak: [{ status: 'terkirim', pada: jam(-19), oleh: 'Ust. Hasan Basri, Lc.' }, { status: 'diterima', pada: jam(-18), oleh: 'Ust. Muhammad Ikhsan, S.Pd.I.' },
          { status: 'ditindaklanjuti', catatan: 'Kedua santri sudah dipanggil dan didamaikan; orang tua dikabari.', pada: jam(-10), oleh: 'Ust. Muhammad Ikhsan, S.Pd.I.' }] }),
      r({ kategori: 'kesehatan', unit_kode: 'KLINIK', pelapor: 'Ustzh. Khadijah Ramadhani, S.Ag.', uraian: 'Santri tampak pucat dan lemas saat halaqah sore.', santri: s.slice(8, 9).map((x) => ({ id: x.id, nama: x.nama_lengkap, kamar: null })),
        status: 'diterima', waktu_kejadian: jam(-6), created_at: jam(-6), jejak: [{ status: 'terkirim', pada: jam(-6), oleh: 'Ustzh. Khadijah Ramadhani, S.Ag.' }, { status: 'diterima', catatan: 'Otomatis menjadi rujukan Klinik.', pada: jam(-6) }] }),
      r({ kategori: 'keamanan', unit_kode: 'SECURITY', pelapor: null, anonim: true, lokasi: 'Pagar belakang asrama putri', uraian: 'Terlihat orang tidak dikenal mondar-mandir di luar pagar sekitar pukul 22.00.',
        status: 'selesai', waktu_kejadian: jam(-50), created_at: jam(-49), selesai_pada: jam(-40), jejak: [{ status: 'terkirim', pada: jam(-49) }, { status: 'selesai', catatan: 'Patroli malam ditambah; lampu pagar diperbaiki.', pada: jam(-40), oleh: 'Pak Rahmat (Security)' }] }),
      r({ kategori: 'akademik', unit_kode: 'TAHFIZH', pelapor: 'Ust. Yusuf Maulana, S.Pd.', uraian: 'Santri sering tidak membawa mushaf ke halaqah pekan ini.', santri: s.slice(1, 2).map((x) => ({ id: x.id, nama: x.nama_lengkap, kamar: null })),
        status: 'terkirim', waktu_kejadian: jam(-30), created_at: jam(-30), jejak: [{ status: 'terkirim', pada: jam(-30), oleh: 'Ust. Yusuf Maulana, S.Pd.' }] }),
    ],
  }
  return DEMO
}

export const useLapor = defineStore('lapor', {
  state: () => ({ hak: { ...HAK_KOSONG }, hakDimuat: false, kategori: [], saluran: null }),
  getters: { penerima: (s) => s.hak.kelola || s.hak.unit.length > 0 },
  actions: {
    async muatHak() {
      if (MODE_DEMO) {
        const p = useSesi().peran; const d = demo()
        this.hak = p === 'superadmin' ? { kelola: true, superadmin: true, unit: UNIT_PILIHAN.map((u) => u.kode), anonim_diizinkan: d.pengaturan.anonim_diizinkan }
          : p === 'admin' ? { ...HAK_KOSONG, kelola: true, unit: UNIT_PILIHAN.map((u) => u.kode), anonim_diizinkan: d.pengaturan.anonim_diizinkan }
            : { ...HAK_KOSONG, anonim_diizinkan: d.pengaturan.anonim_diizinkan }
        this.kategori = KATEGORI_DEMO.map((k) => ({ ...k }))
      } else {
        const [h, { data, error }] = await Promise.all([rpc('hak_lapor'), supabase.from('report_categories').select('*').order('urutan')])
        if (error) throw new Error(pesanGalat(error))
        this.hak = { ...HAK_KOSONG, ...(h || {}) }; this.kategori = data || []
      }
      this.hakDimuat = true; return this.hak
    },
    async simpanAnonim(aktif) {
      if (MODE_DEMO) { demo().pengaturan.anonim_diizinkan = aktif; this.hak.anonim_diizinkan = aktif; return }
      const h = await rpc('simpan_pengaturan_lapor', { p: { anonim_diizinkan: aktif } }); this.hak.anonim_diizinkan = !!h?.anonim_diizinkan
    },
    async simpanKategori(k) {
      if (MODE_DEMO) { Object.assign(this.kategori.find((x) => x.kode === k.kode), k); return }
      await rpc('simpan_kategori_lapor', { p: k }); await this.muatHak()
    },
    async cariSantri(q) {
      if (!MODE_DEMO) return (await rpc('cari_santri_lapor', { p_cari: q })) || []
      const t = q.toLowerCase().trim(); if (t.length < 2) return []
      return useSantri().daftar.filter((s) => s.status === 'aktif' && `${s.nama_lengkap} ${s.nis}`.toLowerCase().includes(t)).slice(0, 20)
        .map((s) => ({ id: s.id, nama: s.nama_lengkap, nis: s.nis, kamar: (s.kelompok || []).find((g) => g.jenis === 'kamar')?.nama || null }))
    },
    async kirim(isi) {
      if (!MODE_DEMO) return rpc('kirim_laporan', { p: isi })
      const k = this.kategori.find((x) => x.kode === isi.kategori); const unit = k.unit_kode || isi.unit_kode; const nama = useSesi().pengguna?.nama_lengkap
      demo().laporan.unshift({ ...isi, id: 'lp' + Date.now(), unit_kode: unit, unit: UNIT_PILIHAN.find((u) => u.kode === unit)?.n, nama_kategori: k.nama, pelapor: nama, saya_pelapor: true,
        santri: isi.santri || [], status: k.ke_klinik ? 'diterima' : 'terkirim', created_at: new Date().toISOString(), selesai_pada: null,
        jejak: [{ status: 'terkirim', pada: new Date().toISOString(), oleh: isi.anonim ? null : nama }] })
    },
    async ubahStatus(id, status, catatan) {
      if (!MODE_DEMO) return rpc('ubah_status_laporan', { p_id: id, p_status: status, p_catatan: catatan || null })
      const r = demo().laporan.find((x) => x.id === id)
      Object.assign(r, { status, selesai_pada: status === 'selesai' ? new Date().toISOString() : r.selesai_pada })
      r.jejak.push({ status, catatan, pada: new Date().toISOString(), oleh: useSesi().pengguna?.nama_lengkap })
    },
    /** cakupan: saya | masuk | semua */
    async daftar(cakupan, mulai = null, selesai = null) {
      if (!MODE_DEMO) return (await rpc('daftar_laporan', { p_cakupan: cakupan, p_mulai: mulai, p_selesai: selesai })) || []
      await useSantri().muat(); const super_ = useSesi().peran === 'superadmin'
      return demo().laporan.filter((r) => cakupan === 'saya' ? r.saya_pelapor : cakupan === 'masuk' ? this.penerima : true)
        .map((r) => ({ ...r, pelapor: r.anonim && !super_ ? null : r.pelapor || (r.anonim ? 'Pelapor anonim (contoh)' : null), boleh_tangani: this.penerima,
          urut: r.status === 'selesai' ? '3' : r.mendesak ? '0' : r.status === 'terkirim' ? '1' : '2' }))
        .sort((a, b) => a.urut.localeCompare(b.urut) || b.created_at.localeCompare(a.created_at))
    },
    async rekap(mulai, selesai) {
      if (!MODE_DEMO) return (await rpc('rekap_laporan', { p_mulai: mulai, p_selesai: selesai })) || []
      const g = {}
      for (const r of demo().laporan) {
        const k = `${r.nama_kategori}|${r.unit}`; const x = (g[k] ||= { kategori: r.nama_kategori, unit: r.unit, jumlah: 0, terkirim: 0, diterima: 0, ditindaklanjuti: 0, selesai: 0, mendesak: 0 })
        x.jumlah++; x[r.status]++; if (r.mendesak) x.mendesak++
      }
      return Object.values(g)
    },
    dengarkan(fn) {
      if (MODE_DEMO || this.saluran) return
      this.saluran = supabase.channel('lapor-bidang').on('postgres_changes', { event: '*', schema: 'public', table: 'incident_reports' }, () => fn()).subscribe()
    },
    berhenti() { if (this.saluran) { supabase.removeChannel(this.saluran); this.saluran = null } },
  },
})
