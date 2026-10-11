// SIMKA PRO | src/stores/keuangan.js | v1.2 | Fase 13 – Impor catatan keuangan lama | 12/10/2026
// Menu Keuangan (Blueprint Bagian 37). Hak dihitung server (hak_keuangan): superadmin dan pegawai yang ditunjuk
// superadmin untuk "keuangan" (Hak Akses → Fitur sensitif). Jabatan Bendahara Wustha/SMA tidak otomatis berhak.
// Semua penulisan lewat fungsi server; mode demo memakai lib/demoKeuangan.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { demo } from '@/lib/demoKeuangan'

async function rpc(nama, args) {
  const { data, error } = await supabase.rpc(nama, args)
  if (error) throw new Error(pesanGalat(error))
  return data
}
const D = (f, ...a) => Promise.resolve().then(() => f(...a))

export const PENGATURAN_KEUANGAN = { rekening: [], jatuh_tempo_hari: 10, batas_surat_hari: 7, pengingat_hari: 3, catatan_kuitansi: '', catatan_tagihan: '' }

export const useKeuangan = defineStore('keuangan', {
  state: () => ({ hak: {}, hakDimuat: false, pengaturan: { ...PENGATURAN_KEUANGAN }, jenis: [], jenisDimuat: false }),
  getters: {
    jabatanSaya: (s) => s.hak.jabatan_ttd || (s.hak.superadmin ? 'Pengelola Sistem' : 'Pengelola Keuangan'),
    jenisAktif: (s) => s.jenis.filter((f) => f.aktif),
  },
  actions: {
    async muatHak() {
      const h = MODE_DEMO ? demo.hak() : await rpc('hak_keuangan')
      this.hak = h || {}; this.pengaturan = { ...PENGATURAN_KEUANGAN, ...(h?.pengaturan || {}) }; this.hakDimuat = true
      return this.hak
    },
    async simpanPengaturan(p) {
      const r = MODE_DEMO ? demo.simpanPengaturan(p) : await rpc('simpan_pengaturan_keuangan', { p })
      this.pengaturan = { ...PENGATURAN_KEUANGAN, ...r }
    },
    // ---------- Jenis biaya ----------
    async muatJenis(paksa = false) {
      if (this.jenisDimuat && !paksa) return this.jenis
      this.jenis = MODE_DEMO ? demo.jenis() : (await rpc('daftar_jenis_biaya')) || []
      this.jenisDimuat = true; return this.jenis
    },
    async simpanJenis(p) { MODE_DEMO ? demo.simpanJenis(p) : await rpc('simpan_jenis_biaya', { p }); await this.muatJenis(true) },
    async hapusJenis(id) { const r = MODE_DEMO ? demo.hapusJenis(id) : await rpc('hapus_jenis_biaya', { p_id: id }); await this.muatJenis(true); return r },
    // ---------- Subsidi ----------
    daftarSubsidi() { return MODE_DEMO ? D(demo.subsidi) : rpc('daftar_subsidi').then((r) => r || []) },
    simpanSubsidi(p) { return MODE_DEMO ? D(demo.simpanSubsidi, p) : rpc('simpan_subsidi', { p }) },
    hapusSubsidi(id) { return MODE_DEMO ? D(demo.hapusSubsidi, id) : rpc('hapus_subsidi', { p_id: id }) },
    // ---------- Tagihan ----------
    pratinjauTagihan(p) { return MODE_DEMO ? D(demo.pratinjau, p) : rpc('pratinjau_tagihan', { p }) },
    buatTagihan(p) { return MODE_DEMO ? D(demo.buat, p) : rpc('buat_tagihan', { p }) },
    daftarTagihan(p = {}) { return MODE_DEMO ? D(demo.tagihan, p) : rpc('daftar_tagihan', { p }).then((r) => r || []) },
    ubahTagihan(id, p) { return MODE_DEMO ? D(demo.ubahTagihan, id, p) : rpc('ubah_tagihan', { p_id: id, p }) },
    batalkanTagihan(id, alasan) { return MODE_DEMO ? D(demo.batalTagihan, id, alasan) : rpc('batalkan_tagihan', { p_id: id, p_alasan: alasan }) },
    // ---------- Pembayaran ----------
    catatPembayaran(p) { return MODE_DEMO ? D(demo.bayar, p) : rpc('catat_pembayaran', { p }) },
    batalkanPembayaran(id, alasan) { return MODE_DEMO ? D(demo.batalBayar, id, alasan) : rpc('batalkan_pembayaran', { p_id: id, p_alasan: alasan }) },
    daftarPembayaran(p = {}) { return MODE_DEMO ? D(demo.pembayaran, p) : rpc('daftar_pembayaran', { p }).then((r) => r || []) },
    imporRiwayat(p) { return MODE_DEMO ? D(demo.imporRiwayat, p) : rpc('impor_riwayat_keuangan', { p }).then((r) => r || []) },
    kuitansi(ids) { return MODE_DEMO ? D(demo.kuitansi, ids) : rpc('kuitansi', { p_ids: ids }).then((r) => r || []) },
    // ---------- Surat tagihan ----------
    terbitkanSurat(p) { return MODE_DEMO ? D(demo.terbitkanSurat, p) : rpc('terbitkan_surat_tagihan', { p }).then((r) => r || []) },
    suratTagihan(ids) { return MODE_DEMO ? D(demo.surat, ids) : rpc('surat_tagihan', { p_ids: ids }).then((r) => r || []) },
    catatKirim(id) { return MODE_DEMO ? D(demo.kirimSurat, id) : rpc('catat_kirim_tagihan', { p_id: id }) },
    cabutSurat(id, alasan) { return MODE_DEMO ? D(demo.cabutSurat, id) : rpc('cabut_surat_tagihan', { p_id: id, p_alasan: alasan }) },
    // ---------- Laporan ----------
    santri(p = {}) { return MODE_DEMO ? D(demo.santri, p) : rpc('santri_keuangan', { p }).then((r) => r || []) },
    rincianSantri(id) { return MODE_DEMO ? D(demo.rincianSantri, id) : rpc('rincian_keuangan_santri', { p_sid: id }) },
    posisiTunggakan(tgl) { return MODE_DEMO ? D(demo.posisi, tgl) : rpc('posisi_tunggakan', { p_tanggal: tgl || null }).then((r) => r || []) },
    ringkasan() { return MODE_DEMO ? D(demo.ringkasan) : rpc('ringkasan_keuangan') },
    kelompok() { return MODE_DEMO ? D(demo.kelompok) : rpc('kelompok_keuangan').then((r) => r || []) },
    ringkasanBeranda() { return MODE_DEMO ? D(demo.beranda) : rpc('ringkasan_keuangan_beranda') },
  },
})
