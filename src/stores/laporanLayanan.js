// SIMKA PRO | src/stores/laporanLayanan.js | v1.0 | Fase 8 – Tahap 4 Laporan modul lain | 10/10/2026
// Laporan periode modul layanan: Security, libur santri, pengajuan pegawai, klinik (hak diperiksa server).
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { daftarTanggal } from '@/lib/laporanKehadiran'

const acak = (s) => { let x = 7; for (const c of s) x = (x * 31 + c.charCodeAt(0)) % 99991; const y = Math.sin(x) * 10000; return y - Math.floor(y) }
const SANTRI = [['2514001', 'Abdullah Hanif', 'L', '8A', 'Kamar Umar'], ['2615008', 'Fatimah Azzahra', 'P', '7B', 'Kamar Aisyah'], ['2413003', 'Hasan Basyir', 'L', '9A', 'Kamar Ali'],
  ['2514006', 'Khadijah Salsabila', 'P', '8B', 'Kamar Khadijah'], ['2615004', 'Ilham Akbar', 'L', '7A', 'Kamar Umar']].map(([nis, nama, jk, kelas, kamar]) => ({ nis, nama, jk, kelas, kamar }))
const jam = (d, h) => `${d}T${String(h).padStart(2, '0')}:15:00+08:00`
function demo(jenis, mulai, selesai) {
  const hari = daftarTanggal(mulai, selesai)
  if (jenis === 'security') {
    const harian = hari.map((d) => { const r = acak(d); return { tanggal: d, keluar: Math.round(r * 9), kembali: Math.round(r * 8), terlambat: r > 0.7 ? 1 : 0, ditolak: r > 0.85 ? 1 : 0, titipan: Math.round(r * 5), tamu: Math.round(r * 4), kunjungan: Math.round(r * 6) } })
    const sum = (k) => harian.reduce((n, h) => n + h[k], 0)
    return { ringkas: { keluar: sum('keluar'), kembali: sum('kembali'), terlambat: sum('terlambat'), ditolak: sum('ditolak'), titipan: sum('titipan'), titipan_diambil: sum('titipan') - 3, titipan_dikembalikan: 1, titipan_belum: 2,
      tamu: sum('tamu'), tamu_orang: sum('tamu') * 2, kunjungan: sum('kunjungan'), kunjungan_luar_jadwal: 2 }, harian,
      terlambat: SANTRI.slice(0, 3).map((s, i) => ({ ...s, waktu: jam(hari[Math.min(i * 3, hari.length - 1)], 17), menit: 15 + i * 20, alasan: 'Pulang menjenguk keluarga sakit' })),
      ditolak_daftar: SANTRI.slice(3, 4).map((s) => ({ ...s, waktu: jam(hari[0], 10), catatan: 'Tidak ada izin yang berlaku' })),
      titipan_belum_daftar: SANTRI.slice(1, 3).map((s) => ({ ...s, diterima: jam(hari[hari.length - 1], 9), jenis: 'paket', uraian: 'Kardus kecil (pakaian)', pengirim: 'Orang tua' })) }
  }
  if (jenis === 'libur') return {
    periode: [{ id: 'l1', nama: 'Libur bulanan Oktober (putra)', jenis: 'bulanan', pulang_pada: jam(hari[Math.min(4, hari.length - 1)], 13), kembali_batas: jam(hari[Math.min(6, hari.length - 1)], 17), jenjang: null, jenis_kelamin: 'L', status: 'disahkan',
      peserta: 312, boleh: 288, tidak: 24, pertimbangan: 0, pulang: 271, kembali_tepat: 259, kembali_terlambat: 9, belum_kembali: 3 }],
    masalah: SANTRI.slice(0, 3).map((s, i) => ({ ...s, periode: 'Libur bulanan Oktober (putra)', batas: jam(hari[Math.min(6, hari.length - 1)], 17), kembali: i < 2 ? jam(hari[Math.min(6, hari.length - 1)], 19) : null, keadaan: i < 2 ? 'Terlambat kembali' : 'Belum kembali', menit: i < 2 ? 120 + i * 30 : null })) }
  if (jenis === 'pengajuan') {
    const J = [{ id: 'j1', nama: 'Izin', kelompok: 'izin' }, { id: 'j2', nama: 'Sakit', kelompok: 'sakit' }, { id: 'j3', nama: 'Dinas luar', kelompok: 'dinas_luar' }, { id: 'j4', nama: 'Cuti tahunan', kelompok: 'cuti' }]
    const P = [['2019070101', 'Ust. Hasan Basri, Lc.', 'L', 'Bidang Tahfizh'], ['2020071502', 'Ustzh. Nurul Aini, S.Pd.', 'P', 'Bidang Kesetaraan Wustha'], ['2018010303', 'Ust. Muhammad Ikhsan, S.Pd.I.', 'L', 'Bidang Kesantrian'],
      ['2021080104', 'Ustzh. Fatimah Az-Zahra, A.Md.Kep.', 'P', 'Unit Klinik'], ['2022020105', 'Ust. Abdul Hakim', 'L', 'Unit Security']]
    return { jenis: J, pegawai: P.map(([niy, nama, jk, unit], i) => {
      const per = {}; let tot = 0; J.forEach((j, k) => { const r = acak(nama + j.id); if (r > 0.45) { const hr = 1 + Math.round(r * 3); per[j.id] = { kali: 1 + (r > 0.8 ? 1 : 0), hari: hr }; tot += hr } })
      return { employee_id: 'p' + i, niy, nama, jk, unit, per_jenis: per, menunggu: i === 0 ? 1 : 0, ditolak: i === 3 ? 1 : 0, total_hari: tot } }) }
  }
  // klinik
  const harian = hari.map((d) => { const r = acak('k' + d); return { tanggal: d, kasus: Math.round(r * 4), pemeriksaan: Math.round(r * 5), dirawat: Math.round(r * 3) } })
  const pk = (k, f) => ({ klinik: k, kasus: Math.round(18 * f), rujukan: Math.round(12 * f), datang_sendiri: Math.round(6 * f), pemeriksaan: Math.round(21 * f), kontrol: Math.round(7 * f),
    kembali: Math.round(9 * f), istirahat: Math.round(8 * f), rawat: Math.round(3 * f), rujuk: Math.round(1 * f), pulang: Math.round(2 * f), sembuh: Math.round(15 * f), surat_sakit: Math.round(4 * f) })
  return { klinik: ['putra', 'putri'], per_klinik: [pk('putra', 1), pk('putri', 0.7)], harian,
    kasus: SANTRI.map((s, i) => ({ ...s, dibuka: jam(hari[Math.min(i * 2, hari.length - 1)], 8), klinik: s.jk === 'P' ? 'putri' : 'putra', keluhan: ['Demam dan pusing', 'Batuk pilek', 'Sakit perut', 'Gatal-gatal', 'Sakit gigi'][i],
      tindak_lanjut: ['istirahat', 'kembali', 'rawat', 'kembali', 'rujuk'][i], status: i === 2 ? 'ditangani' : 'selesai', hasil: i === 2 ? null : 'sembuh', selesai: null })) }
}

export const useLaporanLayanan = defineStore('laporanLayanan', {
  state: () => ({ data: null, jenis: '', memuat: false, galat: '' }),
  actions: {
    async muat(jenis, mulai, selesai, unit = null) {
      this.memuat = true; this.galat = ''; this.data = null
      try {
        if (MODE_DEMO) { this.data = demo(jenis, mulai, selesai); this.jenis = jenis; return }
        const arg = { p_mulai: mulai, p_selesai: selesai }; if (jenis === 'pengajuan') arg.p_unit = unit
        const { data, error } = await supabase.rpc('laporan_' + jenis, arg)
        if (error) throw new Error(pesanGalat(error))
        this.data = data; this.jenis = jenis
      } catch (e) { this.galat = e.message } finally { this.memuat = false }
    },
  },
})
