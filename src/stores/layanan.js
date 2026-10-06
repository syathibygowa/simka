// SIMKA PRO | src/stores/layanan.js | v1.0 | Fase 6 – Tahap 5 Penutup fase klinik dan lapor | 06/10/2026
// Ringkasan layanan santri (Klinik, Perizinan, Lapor ke Bidang) untuk Beranda dan profil santri terpadu.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'
import { useKlinik } from './klinik'
import { useIzin } from './izin'
import { useLapor } from './lapor'

const rpc = async (nama, arg) => { const { data, error } = await supabase.rpc(nama, arg); if (error) throw new Error(pesanGalat(error)); return data }

export const useLayanan = defineStore('layanan', {
  state: () => ({ beranda: null, saluran: null }),
  actions: {
    async muatBeranda() {
      try {
        if (!MODE_DEMO) { this.beranda = await rpc('ringkasan_layanan_beranda'); return }
        const p = useSesi().peran; const atas = p !== 'pegawai'
        const kl = await useKlinik().demo(); const iz = await useIzin().daftar('semua'); const lpS = useLapor(); if (!lpS.hakDimuat) await lpS.muatHak(); const lp = await lpS.daftar('masuk')
        this.beranda = {
          klinik: atas ? { menunggu: kl.kasus.filter((k) => k.status === 'menunggu').length, lewat: 1, dirawat: kl.kasus.filter((k) => k.status === 'ditangani').length, kontrol_hari_ini: 1, selesai_hari_ini: 0 } : null,
          rujukan_saya: atas ? 0 : 1,
          izin: { putuskan: atas ? iz.filter((x) => ['diajukan', 'disetujui_bidang'].includes(x.status)).length : 0, diajukan_saya: atas ? 0 : 1,
            di_luar: iz.filter((x) => x.status === 'keluar').length, terlambat: iz.filter((x) => x.status === 'keluar' && x.terlambat).length, tampil: atas },
          lapor: { baru: atas ? lp.filter((r) => r.status === 'terkirim').length : 0, mendesak: atas ? lp.filter((r) => r.mendesak && r.status !== 'selesai').length : 0,
            proses: atas ? lp.filter((r) => ['diterima', 'ditindaklanjuti'].includes(r.status)).length : 0, saya_terbuka: 1, penerima: atas },
        }
      } catch { this.beranda = null }
    },
    dengarkanBeranda() {
      if (MODE_DEMO || this.saluran) return
      const muat = () => this.muatBeranda()
      this.saluran = supabase.channel('layanan-beranda')
        .on('postgres_changes', { event: '*', schema: 'public', table: 'clinic_cases' }, muat)
        .on('postgres_changes', { event: '*', schema: 'public', table: 'student_permits' }, muat)
        .on('postgres_changes', { event: '*', schema: 'public', table: 'incident_reports' }, muat).subscribe()
    },
    async riwayatSantri(id) {
      if (!MODE_DEMO) return rpc('riwayat_layanan_santri', { p_santri: id })
      const kl = await useKlinik().demo(); const iz = await useIzin().daftar('semua'); const lp = await useLapor().daftar('semua')
      const detail = useSesi().peran !== 'pegawai'
      return { detail_klinik: detail,
        klinik: kl.kasus.filter((k) => k.student_id === id).map((k) => ({ ...k, diagnosis: detail ? kl.periksa.filter((v) => v.case_id === k.id).at(-1)?.diagnosis || null : null, surat: (kl.surat || []).filter((x) => x.case_id === k.id).length })),
        izin: iz.filter((x) => x.student_id === id), laporan: lp.filter((r) => r.santri.some((s) => s.id === id)).map((r) => ({ ...r, kategori: r.nama_kategori, kode: r.kategori })) }
    },
  },
})
