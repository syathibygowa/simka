// SIMKA PRO | src/stores/pantauan.js | v1.0 | Fase 7 – Tahap 4 Pantauan langsung pimpinan | 06/10/2026
// Pantauan Langsung (Blueprint Bagian 28): satu muatan kondisi hari ini (santri, pegawai, sesi kegiatan, Security),
// diperbarui langsung lewat Realtime (ditunda 4 detik agar tidak beruntun) dan disegarkan berkala tiap 60 detik.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { useSantri } from './santri'
import { useSecurity } from './security'
import { dataKelompokDemo } from '@/lib/demoKelompok'

const TABEL = ['attendances', 'student_attendance_sessions', 'student_attendance_exceptions', 'clinic_cases', 'student_permits', 'gate_logs', 'parcels', 'guest_logs', 'parent_visits']

async function demo() {
  const san = useSantri(); await san.muat(); const kel = dataKelompokDemo(san.daftar)
  const nama = (id, j) => kel.anggota.filter((a) => a.student_id === id && !a.selesai).map((a) => kel.kelompok.find((g) => g.id === a.group_id)).filter((g) => g?.jenis === j).map((g) => g.nama).join(', ') || null
  const santri = san.daftar.filter((s) => s.status === 'aktif').map((s, i) => ({ id: s.id, nama: s.nama_lengkap, nis: s.nis, jk: s.jenis_kelamin, jenjang: s.jenjang,
    kelas: nama(s.id, 'kelas'), kamar: nama(s.id, 'kamar'), halaqah: nama(s.id, 'halaqah'), kelas_sesi: 4, kelas_tidak: i % 9 === 0 ? 4 : i % 7 === 0 ? 1 : 0,
    sesi: { 'halaqah:subuh': { n: 'Halaqah subuh', k: i % 8 === 0 ? 'I' : 'H' }, 'halaqah:sore': { n: 'Halaqah sore', k: i % 6 === 0 ? 'A' : 'H' }, 'asrama:malam': { n: 'Asrama malam', k: i % 9 === 0 ? 'S' : 'H' } },
    sakit: i % 9 === 0 ? (i % 2 ? 'Dirawat di klinik' : 'Istirahat (sakit)') : null,
    luar: i === 3 ? { jenis: 'pulang', alasan: 'Keluarga sakit', keluar: new Date(Date.now() - 86400000).toISOString(), batas: new Date(Date.now() - 3600000).toISOString(), terlambat: true }
      : i === 5 ? { jenis: 'keluar', alasan: 'Mengurus KTP', keluar: new Date(Date.now() - 7200000).toISOString(), batas: new Date(Date.now() + 7200000).toISOString(), terlambat: false } : null }))
  const BID = [{ id: 'b1', nama: 'Bidang Kesantrian' }, { id: 'b2', nama: 'Bidang Tahfizh' }, { id: 'b3', nama: 'Bidang Pendidikan' }, { id: 'b4', nama: 'Bidang Umum' }]
  const NAMA = ['Hasan Basri, S.Pd.', 'Muhammad Ikhsan, S.Pd.I.', 'Abdul Rahman, Lc.', 'Nurhayati, S.Pd.', 'Syamsul Arifin, S.Pd.', 'Fatimah Zahra, S.Ag.', 'Ridwan Saleh', 'Andi Satpam', 'Budi Satpam',
    'Khadijah, S.Kep.', 'Umar Faruq, S.Pd.', 'Aminah, S.E.', 'Ilham Syah, S.Kom.', 'Rahmawati, S.Pd.']
  const ST = ['hadir', 'hadir', 'terlambat', 'hadir', 'dinas_luar', 'izin', 'hadir', 'hadir', 'libur', 'sakit', 'belum', 'hadir', 'cuti', 'belum']
  const pegawai = NAMA.map((n, i) => ({ id: 'p' + i, nama: n, jk: /Nurhayati|Fatimah|Khadijah|Aminah|Rahmawati/.test(n) ? 'P' : 'L', bidang_id: BID[i % 4].id, bidang: BID[i % 4].nama, unit: BID[i % 4].nama,
    jabatan: i === 1 ? 'Kepala Bidang' : i === 7 || i === 8 ? 'Petugas keamanan (security)' : i % 2 ? 'Musyrif' : 'Guru mapel', status: ST[i],
    ket: ST[i] === 'terlambat' ? 'Terlambat 12 menit' : ST[i] === 'hadir' ? 'Datang 06.5' + i : ST[i] === 'cuti' ? 'Cuti tahunan' : ST[i] === 'izin' ? 'Izin' : ST[i] === 'sakit' ? 'Sakit' : null }))
  const sesi = kel.kelompok.filter((g) => ['kelas', 'halaqah', 'kamar', 'ekskul'].includes(g.jenis)).flatMap((g, i) => {
    const j = g.jenis === 'kamar' ? 'asrama' : g.jenis
    const daftar = j === 'halaqah' ? [['Halaqah subuh', '04:45'], ['Halaqah sore', '16:00']] : j === 'asrama' ? [['Asrama malam', '21:00']] : j === 'kelas' ? [['Jam 1–4', '07:30'], ['Jam 5–8', '10:30']] : [['Ekskul', '15:30']]
    return daftar.map(([s, jam], k) => ({ group_id: g.id, jenis: j, kelompok: g.nama, jk: g.jenis_kelamin, jenjang: g.jenjang, sesi: s, jam_mulai: jam,
      status: (i + k) % 5 === 0 ? 'tidak_terisi' : (i + k) % 4 === 0 ? 'belum_buka' : 'terisi', hadir: 18, anggota: 20, pengampu: NAMA[(i + k) % NAMA.length] }))
  })
  const sc = useSecurity(); await sc.muatHak(); const d = await sc.daftar()
  return { tanggal: new Date().toISOString().slice(0, 10), waktu: new Date().toISOString(), santri, pegawai, sesi, bidang: BID,
    security: { gerbang: d.log_hari_ini.map((l) => ({ ...l, jk: 'L', jenjang: 'wustha' })), titipan: await sc.daftarTitipan('semua', '2000-01-01', '2100-01-01'),
      tamu: await sc.daftarTamu('semua', '2000-01-01', '2100-01-01'), kunjungan: await sc.daftarKunjungan('semua', '2000-01-01', '2100-01-01') } }
}

export const usePantauan = defineStore('pantauan', {
  state: () => ({ data: null, memuat: false, galat: '', saluran: null, tunda: null, berkala: null }),
  actions: {
    async muat() {
      this.memuat = true
      try {
        if (MODE_DEMO) this.data = await demo()
        else { const { data, error } = await supabase.rpc('pantauan_langsung'); if (error) throw new Error(pesanGalat(error)); this.data = data }
        this.galat = ''
      } catch (e) { this.galat = e.message } finally { this.memuat = false }
    },
    mulai() {
      this.muat()
      this.berkala = setInterval(() => this.muat(), 60000)
      if (MODE_DEMO || this.saluran) return
      const segarkan = () => { clearTimeout(this.tunda); this.tunda = setTimeout(() => this.muat(), 4000) }
      let ch = supabase.channel('pantauan-langsung')
      for (const t of TABEL) ch = ch.on('postgres_changes', { event: '*', schema: 'public', table: t }, segarkan)
      this.saluran = ch.subscribe()
    },
    berhenti() {
      clearInterval(this.berkala); clearTimeout(this.tunda)
      if (this.saluran) { supabase.removeChannel(this.saluran); this.saluran = null }
    },
  },
})
