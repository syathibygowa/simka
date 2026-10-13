// SIMKA PRO | src/stores/pantauan.js | v1.3 | Perbaikan: data contoh sesi pegawai, rekap kelompok, asrama pagi | 14/10/2026
// v1.3: muatan memuat pegawai_sesi (kehadiran pegawai per sesi kerja) dan grup (rekap kelompok aktif L/P dan pengasuh).
// v1.2: muat(tanggal) — hari sebelumnya = keadaan pada akhir hari itu (23.59 WITA); Realtime/berkala hanya untuk hari ini.
// Pantauan Langsung (Blueprint Bagian 28): satu muatan kondisi hari ini (santri, pegawai, sesi kegiatan, Security),
// diperbarui langsung lewat Realtime (ditunda 4 detik agar tidak beruntun) dan disegarkan berkala tiap 60 detik.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { useSantri } from './santri'
import { useSecurity } from './security'
import { dataKelompokDemo } from '@/lib/demoKelompok'

const TABEL = ['teaching_journals', 'incident_reports', 'leave_requests', 'tahfizh_exams', 'memorization_logs', 'attendances', 'student_attendance_sessions', 'student_attendance_exceptions', 'clinic_cases', 'student_permits', 'gate_logs', 'parcels', 'guest_logs', 'parent_visits']

async function demo(tanggal) {
  const san = useSantri(); await san.muat(); const kel = dataKelompokDemo(san.daftar)
  const nama = (id, j) => kel.anggota.filter((a) => a.student_id === id && !a.selesai).map((a) => kel.kelompok.find((g) => g.id === a.group_id)).filter((g) => g?.jenis === j).map((g) => g.nama).join(', ') || null
  const santri = san.daftar.filter((s) => s.status === 'aktif').map((s, i) => ({ id: s.id, nama: s.nama_lengkap, nis: s.nis, jk: s.jenis_kelamin, jenjang: s.jenjang,
    kelas: nama(s.id, 'kelas'), kamar: nama(s.id, 'kamar'), halaqah: nama(s.id, 'halaqah'), ekskul: nama(s.id, 'ekskul'), kelas_sesi: 4, kelas_tidak: i % 9 === 0 ? 4 : i % 7 === 0 ? 1 : 0,
    sesi: { 'halaqah:subuh': { n: 'Halaqah subuh', k: i % 8 === 0 ? 'I' : 'H' }, 'halaqah:sore': { n: 'Halaqah sore', k: i % 6 === 0 ? 'A' : 'H' }, 'asrama:pagi': { n: 'Asrama pagi', k: i % 11 === 0 ? 'A' : 'H' }, 'asrama:malam': { n: 'Asrama malam', k: i % 9 === 0 ? 'S' : 'H' } },
    sakit: i % 9 === 0 ? (i % 2 ? 'Dirawat di klinik' : 'Istirahat (sakit)') : null,
    luar: i === 3 ? { jenis: 'pulang', alasan: 'Keluarga sakit', keluar: new Date(Date.now() - 86400000).toISOString(), batas: new Date(Date.now() - 3600000).toISOString(), terlambat: true }
      : i === 5 ? { jenis: 'keluar', alasan: 'Mengurus KTP', keluar: new Date(Date.now() - 7200000).toISOString(), batas: new Date(Date.now() + 7200000).toISOString(), terlambat: false } : null }))
  const BID = [{ id: 'b1', nama: 'Bidang Kesantrian', kode: 'KESANTRIAN' }, { id: 'b2', nama: 'Bidang Tahfizh', kode: 'TAHFIZH' }, { id: 'b3', nama: 'Bidang Kesetaraan Wustha', kode: 'WUSTHA' }, { id: 'b4', nama: 'Bidang SMA', kode: 'SMA' }]
  const NAMA = ['Hasan Basri, S.Pd.', 'Muhammad Ikhsan, S.Pd.I.', 'Abdul Rahman, Lc.', 'Nurhayati, S.Pd.', 'Syamsul Arifin, S.Pd.', 'Fatimah Zahra, S.Ag.', 'Ridwan Saleh', 'Andi Satpam', 'Budi Satpam',
    'Khadijah, S.Kep.', 'Umar Faruq, S.Pd.', 'Aminah, S.E.', 'Ilham Syah, S.Kom.', 'Rahmawati, S.Pd.']
  const ST = ['hadir', 'hadir', 'terlambat', 'hadir', 'dinas_luar', 'izin', 'hadir', 'hadir', 'libur', 'sakit', 'belum', 'hadir', 'cuti', 'belum']
  const lalu = !!tanggal && tanggal < new Date(Date.now() + 8 * 3600000).toISOString().slice(0, 10)
  const pegawai = NAMA.map((n, i) => ({ id: 'p' + i, nama: n, jk: /Nurhayati|Fatimah|Khadijah|Aminah|Rahmawati/.test(n) ? 'P' : 'L', bidang_id: BID[i % 4].id, bidang: BID[i % 4].nama, unit: BID[i % 4].nama,
    bidang_kode: BID[i % 4].kode, unit_kode: i === 7 || i === 8 ? 'SECURITY' : i === 9 ? 'KLINIK' : null, musyrif: i % 2 === 1, muhaffizh: i % 4 === 1,
    jabatan: i === 1 ? 'Kepala Bidang' : i === 7 || i === 8 ? 'Petugas keamanan (security)' : i % 2 ? 'Musyrif' : 'Guru mapel', status: ST[i],
    ket: ST[i] === 'terlambat' ? 'Terlambat 12 menit' : ST[i] === 'hadir' ? 'Datang 06.5' + i : ST[i] === 'cuti' ? 'Cuti tahunan' : ST[i] === 'izin' ? 'Izin' : ST[i] === 'sakit' ? 'Sakit' : null,
    bertugas: !lalu && ['hadir', 'terlambat'].includes(ST[i]) && i % 3 !== 0, sesi_kini: !lalu && ['hadir', 'terlambat'].includes(ST[i]) && i % 3 !== 0 ? (i % 2 ? 'Asrama sore' : 'Sekolah') : null,
    pulang_pada: ['hadir', 'terlambat'].includes(ST[i]) && (lalu || i % 3 === 0) ? new Date(Date.now() - 3600000 * (i % 4 + 1)).toISOString() : null,
    cepat_menit: i === 6 ? 25 : null, sudah_pulang: ST[i] === 'libur' || (['hadir', 'terlambat'].includes(ST[i]) && (lalu || i % 3 === 0)) }))
  const sesi = kel.kelompok.filter((g) => ['kelas', 'halaqah', 'kamar', 'ekskul'].includes(g.jenis)).flatMap((g, i) => {
    const j = g.jenis === 'kamar' ? 'asrama' : g.jenis
    const daftar = j === 'halaqah' ? [['Halaqah subuh', '04:45'], ['Halaqah sore', '16:00']] : j === 'asrama' ? [['Asrama pagi', '05:30'], ['Asrama malam', '21:00']] : j === 'kelas' ? [['Jam 1–4', '07:30'], ['Jam 5–8', '10:30']] : [['Ekskul', '15:30']]
    return daftar.map(([s, jam], k) => ({ group_id: g.id, jenis: j, kelompok: g.nama, jk: g.jenis_kelamin, jenjang: g.jenjang, sesi: s, jam_mulai: jam,
      status: (i + k) % 5 === 0 ? 'tidak_terisi' : (i + k) % 4 === 0 ? 'belum_buka' : 'terisi', hadir: 18, anggota: 20, pengampu: NAMA[(i + k) % NAMA.length] }))
  })
  const sc = useSecurity(); await sc.muatHak(); const d = await sc.daftar()
  const kini = Date.now(); const iso = (j) => new Date(kini - j * 3600000).toISOString()
  const klinik = santri.filter((x) => x.sakit).map((x, i) => ({ id: 'k' + i, student_id: x.id, nama: x.nama, jk: x.jk, jenjang: x.jenjang, kelas: x.kelas, kamar: x.kamar,
    klinik: x.jk === 'P' ? 'putri' : 'putra', status: 'ditangani', tindak_lanjut: /Dirawat/.test(x.sakit) ? 'rawat' : 'istirahat', keluhan: ['Demam', 'Batuk pilek', 'Sakit perut'][i % 3],
    dibuka_pada: iso(5 + i), periksa_hari_ini: 1 })).concat(santri.slice(1, 3).map((x, i) => ({ id: 'kk' + i, student_id: x.id, nama: x.nama, jk: x.jk, jenjang: x.jenjang, kelas: x.kelas, kamar: x.kamar,
    klinik: x.jk === 'P' ? 'putri' : 'putra', status: i ? 'menunggu' : 'selesai', tindak_lanjut: null, keluhan: 'Pusing', dibuka_pada: iso(3), selesai_pada: i ? null : iso(1), periksa_hari_ini: i ? 0 : 1 })))
  const hafalan = santri.map((x, i) => ({ id: x.id, resmi: (i * 7) % 31, tambah: 10 + ((i * 5) % 17), target: 20, status: i % 5 === 0 ? 'tidak_tercapai' : i % 9 === 0 ? 'tidak_terdata' : (i * 7) % 31 >= 30 ? 'khatam' : 'tercapai',
    posisi: 100 + i * 9, halaqah: x.halaqah, program: 'reguler', hari_ini: i % 3 === 0 ? 0 : 1 + (i % 2), setor_hari_ini: i % 3 !== 0 }))
  const kelompok = kel.kelompok.reduce((a, g) => { a[g.jenis] = (a[g.jenis] || 0) + 1; return a }, {})
  const tgl = tanggal || new Date(kini + 8 * 3600000).toISOString().slice(0, 10)
  const kls = kel.kelompok.filter((g) => g.jenis === 'kelas')
  const MAPEL = ['Matematika', 'Bahasa Arab', 'Bahasa Indonesia', 'Fiqih', 'IPA', 'Bahasa Inggris']
  const pelajaran = kls.flatMap((g, i) => [1, 2, 3, 4].map((jp) => ({ kelas: g.nama, jenjang: g.jenjang, jk: g.jenis_kelamin, mapel: MAPEL[(i + jp) % MAPEL.length], guru: NAMA[(i + jp) % NAMA.length],
    jp: `Jam ke-${jp}`, urutan: jp, jam_mulai: ['07:30', '08:10', '08:50', '09:45'][jp - 1], jam_selesai: ['08:10', '08:50', '09:30', '10:25'][jp - 1],
    status: lalu ? ((i + jp) % 7 === 0 ? 'belum_diisi' : (i + jp) % 9 === 0 ? 'tidak_terlaksana' : 'terlaksana') : jp <= 2 ? ((i + jp) % 5 === 0 ? 'belum_diisi' : 'terlaksana') : jp === 3 ? 'berlangsung' : 'akan_datang', materi: null })))
  const sx = (i) => santri[i] || santri[0]
  const izin = { santri: [
      { id: 'iz1', ...sx(3), jenis: 'pulang', alasan: 'Keluarga sakit', status: 'keluar', diajukan: iso(30), keluar: iso(26), batas: iso(1), kembali: null, menunggu: false, keluar_hari_ini: false, kembali_hari_ini: false, terlambat: true },
      { id: 'iz2', ...sx(5), jenis: 'keluar', alasan: 'Mengurus KTP', status: 'keluar', diajukan: iso(4), keluar: iso(2), batas: iso(-2), kembali: null, menunggu: false, keluar_hari_ini: true, kembali_hari_ini: false, terlambat: false },
      { id: 'iz3', ...sx(8), jenis: 'pulang', alasan: 'Acara keluarga', status: 'diajukan', diajukan: iso(2), keluar: null, batas: iso(-48), kembali: null, menunggu: !lalu, keluar_hari_ini: false, kembali_hari_ini: false, terlambat: false },
      { id: 'iz4', ...sx(10), jenis: 'keluar', alasan: 'Berobat gigi', status: 'kembali', diajukan: iso(8), keluar: iso(6), batas: iso(3), kembali: iso(3.5), menunggu: false, keluar_hari_ini: true, kembali_hari_ini: true, terlambat: false }],
    pegawai: [{ id: 'lv1', nama: NAMA[12], jk: 'L', jenis: 'Cuti tahunan', status: 'disetujui', mulai: tgl, selesai: tgl, hari: 1, alasan: 'Keperluan keluarga', berlaku: true, diajukan: iso(72) },
      { id: 'lv2', nama: NAMA[3], jk: 'P', jenis: 'Izin', status: 'menunggu', mulai: tgl, selesai: tgl, hari: 1, alasan: 'Mengantar anak berobat', berlaku: false, diajukan: iso(3) }] }
  const lapor = [{ id: 'lp1', kategori: 'sarana', unit_kode: 'UMUM', lokasi: 'Kamar mandi asrama putra', waktu: iso(5), uraian: 'Keran air bocor', mendesak: false, status: 'diterima', hari_ini: true },
    { id: 'lp2', kategori: 'keamanan', unit_kode: 'SECURITY', lokasi: 'Gerbang belakang', waktu: iso(30), uraian: 'Lampu gerbang padam', mendesak: true, status: 'ditindaklanjuti', hari_ini: false }]
  const agenda = [{ id: 'ag1', judul: 'Rapat koordinasi wali kelas', jenis: 'rapat', jam_mulai: '13:30', jam_selesai: '15:00', lokasi: 'Aula', sasaran: 'Wali kelas' }]
  const ujian = [{ id: 'uj1', jenis: 'kenaikan', juz: 5, nama: sx(2).nama, nis: sx(2).nis, jk: sx(2).jk, jenjang: sx(2).jenjang, kelas: sx(2).kelas, halaqah: sx(2).halaqah, status: 'selesai', hasil: 'tuntas', nilai: 86, jadwal: iso(4), penguji: NAMA[1] },
    { id: 'uj2', jenis: 'sertifikasi', juz: null, jenjang_sertifikasi: 5, nama: sx(4).nama, nis: sx(4).nis, jk: sx(4).jk, jenjang: sx(4).jenjang, kelas: sx(4).kelas, halaqah: sx(4).halaqah, status: 'dijadwalkan', hasil: null, nilai: null, jadwal: iso(-2), penguji: NAMA[5] }]
  const stSesi = (st, k) => (['izin', 'sakit', 'cuti', 'dinas_luar'].includes(st) ? st : st === 'libur' ? null : st === 'belum' ? (k ? 'akan_datang' : 'belum') : k && st === 'terlambat' ? 'hadir' : st)
  const pegawai_sesi = Object.fromEntries(pegawai.filter((p) => p.status !== 'libur').map((p, i) => [p.id, p.musyrif
    ? [{ n: 'Asrama pagi', mulai: '05:00', st: stSesi(p.status, 0) }, { n: 'Asrama malam', mulai: '20:00', st: lalu ? (i % 3 ? 'hadir' : 'tanpa_keterangan') : stSesi(p.status, 1) }]
    : [{ n: 'Sekolah', mulai: '07:00', st: stSesi(p.status, 0) }]]))
  const grup = kel.kelompok.filter((g) => g.aktif !== false && ['kelas', 'kamar', 'halaqah', 'ekskul'].includes(g.jenis)).map((g) => {
    const ang = kel.anggota.filter((a) => a.group_id === g.id && !a.selesai).map((a) => santri.find((x) => x.id === a.student_id)).filter(Boolean)
    return { id: g.id, jenis: g.jenis, nama: g.nama, jk: g.jenis_kelamin, jenjang: g.jenjang, tingkat: g.tingkat, pengasuh: (g.pengasuh || []).map((x) => x.nama).join(', ') || null,
      l: ang.filter((x) => x.jk === 'L').length, p: ang.filter((x) => x.jk === 'P').length }
  })
  return { tanggal: tgl, waktu: lalu ? `${tgl}T23:59:59+08:00` : new Date().toISOString(), lalu, santri, pegawai, pegawai_sesi, grup, sesi, bidang: BID, klinik, hafalan, kelompok, pelajaran, izin, lapor, agenda, ujian,
    security: { gerbang: d.log_hari_ini.map((l) => ({ ...l, jk: 'L', jenjang: 'wustha' })), titipan: await sc.daftarTitipan('semua', '2000-01-01', '2100-01-01'),
      tamu: await sc.daftarTamu('semua', '2000-01-01', '2100-01-01'), kunjungan: await sc.daftarKunjungan('semua', '2000-01-01', '2100-01-01') } }
}

export const usePantauan = defineStore('pantauan', {
  state: () => ({ data: null, memuat: false, galat: '', saluran: null, tunda: null, berkala: null, tanggal: null }),
  actions: {
    /** tanggal: null = hari ini (langsung); yyyy-mm-dd = keadaan akhir hari itu. */
    async muat(tanggal) {
      if (tanggal !== undefined) this.tanggal = tanggal
      this.memuat = true
      try {
        if (MODE_DEMO) this.data = await demo(this.tanggal)
        else { const { data, error } = await supabase.rpc('pantauan_langsung', { p_tanggal: this.tanggal || null }); if (error) throw new Error(pesanGalat(error)); this.data = data }
        this.galat = ''
      } catch (e) { this.galat = e.message } finally { this.memuat = false }
    },
    mulai(tanggal = null) {
      this.muat(tanggal)
      this.berkala = setInterval(() => { if (!this.tanggal) this.muat() }, 60000)
      if (MODE_DEMO || this.saluran) return
      const segarkan = () => { if (this.tanggal) return; clearTimeout(this.tunda); this.tunda = setTimeout(() => this.muat(), 4000) }
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
