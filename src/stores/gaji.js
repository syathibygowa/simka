// SIMKA PRO | src/stores/gaji.js | v1.3 | Fase 11 – Tahap 4 Penerbitan slip, Slip saya, permintaan slip | 11/10/2026
// Modul Gaji (Blueprint Bagian 36). Hak dihitung server (hak_gaji):
//   kelola = superadmin, Bendahara (hak fitur slip_gaji 3), admin ber-izin kelola_gaji
//   lihat  = kelola + admin ber-izin lihat_gaji
//   slip_saya = slip ditampilkan di akun pegawai (ketentuan, bawaan TIDAK sesuai arahan yayasan)
// Data pegawai untuk gaji dibaca lewat pegawai_gaji() karena Bendahara secara peran adalah pegawai biasa.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { usePegawai } from './pegawai'
import { useTunjangan } from './tunjangan'
import { useOrganisasi } from './organisasi'
import { demoGaji } from '@/lib/demoGaji'

export const PENGATURAN_BAWAAN = {
  slip_pegawai: false, ttd_direktur: false, pembulatan: 100, potong_izin: false, potong_sakit: false, potong_cuti: false,
  potong_terlambat: false, tanggal_gajian: 1, honorer_tunjangan_jabatan: true, info_beban_kerja: true, catatan_slip: '',
  label_penyesuaian: 'Penyesuaian ketetapan yayasan', potong_kehadiran: false,
}
const BANK_DEMO = ['BSI', 'BRI', 'BNI', 'Bank Mandiri', 'BSI']
let demoPengaturan = { ...PENGATURAN_BAWAAN }
const demoRekening = {}

async function rpc(nama, args) {
  const { data, error } = await supabase.rpc(nama, args)
  if (error) throw new Error(pesanGalat(error))
  return data
}

export const useGaji = defineStore('gaji', {
  state: () => ({ hak: {}, hakDimuat: false, pengaturan: { ...PENGATURAN_BAWAAN }, pegawai: [], pegawaiDimuat: false }),
  actions: {
    async muatHak() {
      if (MODE_DEMO) {
        const { useSesi } = await import('./sesi'); const peran = useSesi().peran
        const kelola = peran !== 'pegawai'
        this.hak = { kelola, lihat: kelola, superadmin: peran === 'superadmin', bendahara: false, slip_saya: demoPengaturan.slip_pegawai, tampil: kelola || demoPengaturan.slip_pegawai }
        this.pengaturan = { ...demoPengaturan }
      } else {
        const h = await rpc('hak_gaji')
        this.hak = h || {}
        this.pengaturan = { ...PENGATURAN_BAWAAN, ...(h?.pengaturan || {}) }
      }
      this.hakDimuat = true
      return this.hak
    },

    async muatPegawai(paksa = false) {
      if (this.pegawaiDimuat && !paksa) return this.pegawai
      if (MODE_DEMO) {
        const peg = usePegawai(); if (!peg.daftar.length) await peg.muat()
        this.pegawai = peg.daftar.filter((p) => p.status_keaktifan === 'aktif').map((p, i) => ({
          ...p, pendidikan_terakhir: p.pendidikan_terakhir || ['S1', 'S1-LN', 'S2', 'SMA'][i % 4],
          rekening: demoRekening[p.id] !== undefined ? demoRekening[p.id]
            : i % 5 === 4 ? null : i % 7 === 3 ? { cara_bayar: 'tunai' }
              : { cara_bayar: 'transfer', bank: BANK_DEMO[i % 5], nomor_rekening: String(7100000000 + i * 1234567), atas_nama: p.nama_lengkap.replace(/^(Ust\.|Ustzh\.)\s*/, '').split(',')[0] },
        }))
      } else {
        this.pegawai = (await rpc('pegawai_gaji')) || []
      }
      this.pegawaiDimuat = true
      return this.pegawai
    },

    async simpanPengaturan(isi) {
      if (MODE_DEMO) { demoPengaturan = { ...demoPengaturan, ...isi }; this.pengaturan = { ...demoPengaturan }; this.hak.slip_saya = demoPengaturan.slip_pegawai; return this.pengaturan }
      this.pengaturan = { ...PENGATURAN_BAWAAN, ...(await rpc('simpan_pengaturan_gaji', { p: isi })) }
      this.hak.slip_saya = !!this.pengaturan.slip_pegawai
      return this.pengaturan
    },

    /** Simpan satu rekening (objek) atau banyak (larik hasil impor Excel). Hasil: { disimpan, gagal[] }. */
    async simpanRekening(isi) {
      if (MODE_DEMO) {
        const daftar = Array.isArray(isi) ? isi : [isi]; let n = 0
        for (const r of daftar) {
          const p = this.pegawai.find((x) => x.id === r.employee_id || (r.niy && x.niy === String(r.niy)))
          if (!p) continue
          p.rekening = r.cara_bayar === 'tunai' ? { cara_bayar: 'tunai', catatan: r.catatan || null } : { cara_bayar: 'transfer', bank: r.bank, nomor_rekening: String(r.nomor_rekening).replace(/\s+/g, ''), atas_nama: r.atas_nama, catatan: r.catatan || null }
          demoRekening[p.id] = p.rekening; n++
        }
        return { disimpan: n, gagal: [] }
      }
      const hasil = await rpc('simpan_rekening', { p: isi })
      await this.muatPegawai(true)
      return hasil
    },

    // ---------- Periode gaji ----------
    /** Konteks mesin demo (tarif, organisasi, pegawai, ketentuan). */
    async _ctx() {
      const tunj = useTunjangan(); const org = useOrganisasi()
      await Promise.all([tunj.muat(), org.muat(), this.muatPegawai()])
      return { tarif: tunj.tarif, org, pegawai: this.pegawai, pengaturan: this.pengaturan }
    },
    async daftarPeriode() { return MODE_DEMO ? demoGaji.daftar() : (await rpc('daftar_periode_gaji')) || [] },
    async buatPeriode(tahun, bulan, tanggalBayar = null) {
      if (MODE_DEMO) return demoGaji.buat(tahun, bulan, tanggalBayar, await this._ctx())
      return rpc('buat_periode_gaji', { p_tahun: tahun, p_bulan: bulan, p_tanggal_bayar: tanggalBayar || null })
    },
    async rincianPeriode(id) { return MODE_DEMO ? demoGaji.rincian(id) : rpc('rincian_periode_gaji', { p_period: id }) },
    async hitungUlang(id) { return MODE_DEMO ? demoGaji.hitungUlang(id, await this._ctx()) : rpc('hitung_ulang_periode_gaji', { p_period: id }) },
    async ubahPeriode(id, isi) { return MODE_DEMO ? demoGaji.ubahPeriode(id, isi) : rpc('ubah_periode_gaji', { p_period: id, p: isi }) },
    async hapusPeriode(id) { return MODE_DEMO ? demoGaji.hapusPeriode(id) : rpc('hapus_periode_gaji', { p_period: id }) },
    async tambahBaris(periodId, empId) { return MODE_DEMO ? null : rpc('tambah_baris_gaji', { p_period: periodId, p_emp: empId }) },
    async hapusBaris(lineId) { return MODE_DEMO ? demoGaji.hapusBaris(lineId) : rpc('hapus_baris_gaji', { p_line: lineId }) },
    async ubahItem(itemId, besaran, jumlah, alasan) {
      if (MODE_DEMO) return demoGaji.ubahItem(itemId, besaran, jumlah, alasan, await this._ctx())
      return rpc('ubah_item_gaji', { p_item: itemId, p_besaran: besaran, p_jumlah: jumlah, p_alasan: alasan })
    },
    async kembalikanItem(itemId) { return MODE_DEMO ? demoGaji.kembalikan(itemId, await this._ctx()) : rpc('kembalikan_item_gaji', { p_item: itemId }) },
    async tambahItem(lineId, isi) { return MODE_DEMO ? demoGaji.tambahItem(lineId, isi, await this._ctx()) : rpc('tambah_item_gaji', { p_line: lineId, p: isi }) },
    async hapusItem(itemId) { return MODE_DEMO ? demoGaji.hapusItem(itemId, await this._ctx()) : rpc('hapus_item_gaji', { p_item: itemId }) },
    async aturDiterima(lineId, nilai, alasan) {
      if (MODE_DEMO) return demoGaji.aturDiterima(lineId, nilai, alasan, await this._ctx())
      return rpc('atur_diterima_gaji', { p_line: lineId, p_diterima: nilai, p_alasan: alasan })
    },
    async imporDiterima(periodId, baris) {
      if (MODE_DEMO) return demoGaji.imporDiterima(periodId, baris, await this._ctx())
      return rpc('impor_diterima_gaji', { p_period: periodId, p: baris })
    },

    // ---------- Penetapan yayasan ----------
    async daftarPenetapan() { return MODE_DEMO ? demoGaji.penetapan() : (await rpc('daftar_penetapan_gaji')) || [] },
    async simpanPenetapan(isi) { return MODE_DEMO ? demoGaji.simpanPenetapan(isi, await this._ctx()) : rpc('simpan_penetapan_gaji', { p: isi }) },
    async hapusPenetapan(id) { return MODE_DEMO ? demoGaji.hapusPenetapan(id) : rpc('hapus_penetapan_gaji', { p_id: id }) },

    // ---------- Pinjaman ----------
    async daftarPinjaman() { return MODE_DEMO ? demoGaji.pinjaman() : (await rpc('daftar_pinjaman')) || [] },
    async simpanPinjaman(isi) { return MODE_DEMO ? demoGaji.simpanPinjaman(isi, await this._ctx()) : rpc('simpan_pinjaman', { p: isi }) },
    async bayarPinjaman(id, besaran, tanggal, ket) {
      return MODE_DEMO ? demoGaji.bayarPinjaman(id, besaran, tanggal, ket) : rpc('bayar_pinjaman', { p_loan: id, p_besaran: besaran, p_tanggal: tanggal || null, p_keterangan: ket })
    },
    async batalkanPinjaman(id, alasan) { return MODE_DEMO ? demoGaji.batalkanPinjaman(id) : rpc('batalkan_pinjaman', { p_loan: id, p_alasan: alasan }) },

    // ---------- Simpanan program ----------
    async daftarSimpanan() { return MODE_DEMO ? demoGaji.simpanan() : (await rpc('daftar_simpanan')) || [] },
    async simpanProgram(isi) { return MODE_DEMO ? demoGaji.simpanProgram(isi) : rpc('simpan_program_simpanan', { p: isi }) },
    async simpanAnggota(isi) { return MODE_DEMO ? demoGaji.simpanAnggota(isi, await this._ctx()) : rpc('simpan_anggota_simpanan', { p: isi }) },
    async catatTransaksi(isi) { return MODE_DEMO ? demoGaji.catatTransaksi(isi) : rpc('catat_transaksi_simpanan', { p: isi }) },

    // ---------- Penerbitan dan slip ----------
    async ajukanTerbit(id) { return MODE_DEMO ? demoGaji.ajukan(id, this.pengaturan) : rpc('ajukan_periode_gaji', { p_period: id }) },
    async tandatangani(id, setuju, catatan) { return MODE_DEMO ? demoGaji.tandatangani(id, setuju) : rpc('tandatangani_periode_gaji', { p_period: id, p_setuju: setuju, p_catatan: catatan || null }) },
    async tarikPengajuan(id) { return MODE_DEMO ? demoGaji.tarik(id) : rpc('tarik_pengajuan_gaji', { p_period: id }) },
    async mulaiRevisi(lineId, alasan) { return MODE_DEMO ? demoGaji.mulaiRevisi(lineId, alasan) : rpc('mulai_revisi_slip', { p_line: lineId, p_alasan: alasan }) },
    async terbitkanRevisi(lineId) { return MODE_DEMO ? demoGaji.terbitkanRevisi(lineId) : rpc('terbitkan_revisi_slip', { p_line: lineId }) },
    async batalkanRevisi(lineId) { return MODE_DEMO ? demoGaji.batalkanRevisi(lineId) : rpc('batalkan_revisi_slip', { p_line: lineId }) },
    async tutupSlip(lineId) { return MODE_DEMO ? demoGaji.tutupSlip(lineId) : rpc('tutup_slip_pegawai', { p_line: lineId }) },
    async slipSaya() { return MODE_DEMO ? demoGaji.slipSaya(this.pengaturan) : rpc('slip_saya') },
    async slipGaji(lineId) { return MODE_DEMO ? demoGaji.slip(lineId) : rpc('slip_gaji', { p_line: lineId }) },
    async periodeSaya() { return MODE_DEMO ? demoGaji.periodeSaya() : (await rpc('periode_gaji_saya')) || [] },
    async mintaSlip(periodId, catatan) { return MODE_DEMO ? demoGaji.minta(periodId, catatan) : rpc('minta_slip_gaji', { p_period: periodId || null, p_catatan: catatan || null }) },
    async daftarPermintaan() { return MODE_DEMO ? demoGaji.permintaan() : (await rpc('daftar_permintaan_slip')) || [] },
    async tanggapiPermintaan(id, aksi, catatan) { return MODE_DEMO ? demoGaji.tanggapi(id, aksi, catatan) : rpc('tanggapi_permintaan_slip', { p_id: id, p_aksi: aksi, p_catatan: catatan || null }) },
    async ttdSaya() { return MODE_DEMO ? [] : (await rpc('ttd_gaji_saya')) || [] },

    async hapusRekening(id) {
      if (MODE_DEMO) { const p = this.pegawai.find((x) => x.id === id); if (p) p.rekening = null; demoRekening[id] = null; return }
      await rpc('hapus_rekening', { p_emp: id })
      const p = this.pegawai.find((x) => x.id === id); if (p) p.rekening = null
    },
  },
})
