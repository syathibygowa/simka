// SIMKA PRO | src/stores/tahunAjaran.js | v1.0 | Fase 4 – Tahap 6 Tahun ajaran, statistik, laporan | 05/10/2026
// Pergantian tahun ajaran (draf kenaikan, kelompok draf, aktivasi) dan statistik santri (beranda, laporan, kohort).
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { useSantri } from './santri'
import { useKelompokSantri } from './kelompokSantri'
import { kelompokDari } from '@/lib/santri'

const rpc = async (nama, arg) => { const { data, error } = await supabase.rpc(nama, arg); if (error) throw new Error(pesanGalat(error)); return data }

/** Statistik dari daftar santri (mode demo dan cadangan). */
function hitungStatistik(daftar) {
  const aktif = daftar.filter((s) => s.status === 'aktif')
  const per = {}
  for (const s of aktif) { const k = `${s.jenjang}|${s.tingkat}`; per[k] ||= { jenjang: s.jenjang, tingkat: s.tingkat, L: 0, P: 0 }; per[k][s.jenis_kelamin]++ }
  const koh = {}
  for (const s of daftar) { koh[s.angkatan] ||= { angkatan: s.angkatan, tahun_masuk: s.tahun_masuk, total: 0, aktif: 0, lulus: 0, keluar: 0 }; const k = koh[s.angkatan]; k.total++
    if (['aktif', 'nonaktif'].includes(s.status)) k.aktif++; else if (s.status === 'lulus') k.lulus++; else k.keluar++ }
  return { aktif: aktif.length, putra: aktif.filter((s) => s.jenis_kelamin === 'L').length, putri: aktif.filter((s) => s.jenis_kelamin === 'P').length,
    wustha: aktif.filter((s) => s.jenjang === 'wustha').length, sma: aktif.filter((s) => s.jenjang === 'sma').length,
    nonaktif: daftar.filter((s) => s.status === 'nonaktif').length, lulus: daftar.filter((s) => s.status === 'lulus').length,
    keluar: daftar.filter((s) => ['mutasi_keluar', 'berhenti'].includes(s.status)).length,
    data_kurang: aktif.filter((s) => !s.nisn || !s.tempat_lahir || !s.tanggal_lahir).length,
    per_tingkat: Object.values(per).sort((a, b) => a.tingkat - b.tingkat), kohort: Object.values(koh).sort((a, b) => b.angkatan - a.angkatan),
    hari_ini: { sesi: 14, anggota: 260, hadir: 249, izin: 4, sakit: 5, absen: 2 } }
}

export const useTahunAjaran = defineStore('tahunAjaran', {
  state: () => ({ statistik: null, memuat: false, saluran: null, diperbarui: null }),
  actions: {
    async muatStatistik() {
      this.memuat = true
      try {
        if (MODE_DEMO) { const san = useSantri(); await san.muat(); this.statistik = hitungStatistik(san.daftar) }
        else this.statistik = await rpc('statistik_santri')
        this.diperbarui = new Date()
      } catch { this.statistik = this.statistik || null } finally { this.memuat = false }
    },
    /** Statistik langsung: dimuat ulang saat data santri atau absensi berubah. */
    dengarkan() {
      if (MODE_DEMO || this.saluran) return
      let jeda = null; const ulang = () => { clearTimeout(jeda); jeda = setTimeout(() => this.muatStatistik(), 1500) }
      this.saluran = supabase.channel('statistik-santri')
        .on('postgres_changes', { event: '*', schema: 'public', table: 'students' }, ulang)
        .on('postgres_changes', { event: '*', schema: 'public', table: 'student_attendance_sessions' }, ulang)
        .subscribe()
    },

    // ---------- Pergantian tahun ajaran ----------
    async rencana() {
      if (MODE_DEMO) {
        const san = useSantri(); await san.muat(); await useKelompokSantri().muat()
        return san.daftar.filter((s) => ['aktif', 'nonaktif'].includes(s.status)).map((s) => ({ student_id: s.id, nis: s.nis, nama: s.nama_lengkap, jenis_kelamin: s.jenis_kelamin,
          jenjang: s.jenjang, tingkat: s.tingkat, rombel: kelompokDari(s, 'kelas')?.nama || null, status: s.status, usulan: s.tingkat >= 12 ? 'lulus' : 'naik' }))
          .sort((a, b) => a.tingkat - b.tingkat || a.nama.localeCompare(b.nama, 'id'))
      }
      return (await rpc('rencana_kenaikan')) || []
    },
    async muatDraf() {
      if (MODE_DEMO) return []
      const { data, error } = await supabase.from('academic_years').select('id, nama, mulai, selesai, aktif, terkunci').eq('aktif', false).eq('terkunci', false).order('mulai')
      if (error) throw new Error(pesanGalat(error))
      const hasil = []
      for (const ta of data) {
        const [p, g] = await Promise.all([supabase.from('promotions').select('aksi', { count: 'exact' }).eq('academic_year_id', ta.id),
          supabase.from('student_groups').select('id', { count: 'exact', head: true }).eq('academic_year_id', ta.id)])
        hasil.push({ ...ta, naik: (p.data || []).filter((x) => x.aksi === 'naik').length, tinggal: (p.data || []).filter((x) => x.aksi === 'tinggal').length,
          lulus: (p.data || []).filter((x) => x.aksi === 'lulus').length, kelompok: g.count || 0 })
      }
      return hasil
    },
    async buatDraf(isi) {
      if (MODE_DEMO) throw new Error('Mode demo: pergantian tahun ajaran tidak dijalankan. Gunakan aplikasi yang tersambung ke server.')
      const h = await rpc('buat_draf_tahun_ajaran', { p: isi }); await useKelompokSantri().muat(); return h
    },
    async hapusDraf(id) { if (MODE_DEMO) return; await rpc('hapus_draf_tahun_ajaran', { p_ta: id }); await useKelompokSantri().muat() },
    async aktifkan(id) {
      if (MODE_DEMO) throw new Error('Mode demo: aktivasi tahun ajaran tidak dijalankan.')
      const h = await rpc('aktifkan_tahun_ajaran', { p_ta: id })
      const kel = useKelompokSantri(); kel.taDipilih = ''; await Promise.all([kel.muat(), useSantri().muat(true)])
      return h
    },
  },
})
