// SIMKA PRO | src/stores/keuangan.js | v1.3 | 14.7.0: rekening/kas, transaksi lain, pindah dana, buku kas, laporan, bebas tunggakan | 18/10/2026
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

export const PENGATURAN_KEUANGAN = { rekening: [], jatuh_tempo_hari: 10, batas_surat_hari: 7, pengingat_hari: 3, catatan_kuitansi: '', catatan_tagihan: '', catatan_bebas: '', kategori_keluar: [], kategori_masuk: [] }

export const useKeuangan = defineStore('keuangan', {
  state: () => ({ hak: {}, hakDimuat: false, pengaturan: { ...PENGATURAN_KEUANGAN }, jenis: [], jenisDimuat: false, akun: [] }),
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
    // ---------- 14.7.0: rekening dan kas ----------
    async muatAkun() { this.akun = MODE_DEMO ? demo.rekening() : (await rpc('daftar_rekening_keu')) || []; return this.akun },
    async simpanAkun(p) { MODE_DEMO ? demo.simpanRekening(p) : await rpc('simpan_rekening_keu', { p }); await Promise.all([this.muatAkun(), this.muatHak()]) },
    async hapusAkun(id) { const r = MODE_DEMO ? demo.hapusRekening(id) : await rpc('hapus_rekening_keu', { p_id: id }); await Promise.all([this.muatAkun(), this.muatHak()]); return r },
    catatTransaksi(p) { return MODE_DEMO ? D(demo.catatTransaksi, p) : rpc('catat_transaksi_keu', { p }) },
    batalTransaksi(id, alasan) { return MODE_DEMO ? D(demo.batalTransaksi, id, alasan) : rpc('batal_transaksi_keu', { p_id: id, p_alasan: alasan }) },
    catatPindah(p) { return MODE_DEMO ? D(demo.catatPindah, p) : rpc('catat_pindah_dana', { p }) },
    batalPindah(id, alasan) { return MODE_DEMO ? D(demo.batalPindah, id, alasan) : rpc('batal_pindah_dana', { p_id: id, p_alasan: alasan }) },
    transaksi(p) { return MODE_DEMO ? D(demo.transaksi, p) : rpc('daftar_transaksi_keu', { p }).then((r) => r || []) },
    bukuKas(p) { return MODE_DEMO ? D(demo.bukuKas, p) : rpc('buku_kas', { p }) },
    laporan(p) { return MODE_DEMO ? D(demo.laporan, p) : rpc('laporan_keuangan', { p }) },
    // ---------- 14.7.0: Surat Keterangan Bebas Tunggakan ----------
    cekBebas(sid) { return MODE_DEMO ? D(demo.cekBebas, sid) : rpc('cek_bebas_tunggakan', { p_sid: sid }) },
    terbitkanBebas(p) { return MODE_DEMO ? D(demo.terbitkanBebas, p) : rpc('terbitkan_bebas_tunggakan', { p }) },
    suratBebas(ids) { return MODE_DEMO ? D(demo.suratBebas, ids) : rpc('surat_bebas_tunggakan', { p_ids: ids }).then((r) => r || []) },
    daftarBebas(p = {}) { return MODE_DEMO ? D(demo.daftarBebas, p) : rpc('daftar_bebas_tunggakan', { p }).then((r) => r || []) },
    cabutBebas(id, alasan) { return MODE_DEMO ? D(demo.cabutBebas, id, alasan) : rpc('cabut_bebas_tunggakan', { p_id: id, p_alasan: alasan }) },
  },
})
