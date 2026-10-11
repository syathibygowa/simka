// SIMKA PRO | src/stores/verval.js | v1.1 | Fase 3 – Menu Data Presensi (harian per bidang) | 12/10/2026
// Panel admin presensi: antrian verval, permintaan koreksi, penanda kecurigaan, dan data presensi per pegawai.
// v1.1: hariSemua(tanggal, bidang) untuk menu Data Presensi; mode demo menyimpan perubahan di memori.
// Semua perubahan lewat fungsi server yang memeriksa hak dan mencatat riwayat status.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { hariIniISO } from '@/lib/tanggal'
import { usePegawai } from './pegawai'
import { useOrganisasi } from './organisasi'

async function rpc(nama, isi) {
  const { data, error } = await supabase.rpc(nama, isi)
  if (error) throw new Error(error.hint && error.message ? error.message : pesanGalat(error))
  return data
}
// ---------- Data presensi contoh (mode demo) ----------
const ubahanDemo = {}   // kunci emp|tanggal|sesi → { status, status_pulang, keterangan }
const acakDemo = (t) => { let x = 7; for (const c of t) x = (x * 31 + c.charCodeAt(0)) % 99991; const y = Math.sin(x) * 10000; return y - Math.floor(y) }
function sesiDemo(p, tanggal) {
  if (new Date(tanggal + 'T00:00:00Z').getUTCDay() === 0) return []
  const kini = new Date(); const hariIni = hariIniISO()
  const mulai = `${tanggal}T07:30:00+08:00`; const selesai = `${tanggal}T14:00:00+08:00`; const sid = 'sesi-kerja'
  const r = acakDemo(p.id + tanggal); const kunci = `${p.id}|${tanggal}|${sid}`
  const lewat = tanggal < hariIni || (tanggal === hariIni && kini > new Date(`${tanggal}T08:30:00+08:00`))
  let status = !lewat ? null : r < 0.74 ? 'hadir' : r < 0.86 ? 'terlambat' : r < 0.89 ? 'dinas_luar' : r < 0.93 ? 'izin' : r < 0.955 ? 'sakit' : r < 0.97 ? 'cuti' : 'tanpa_keterangan'
  const u = ubahanDemo[kunci]; if (u) status = u.status
  const hadir = ['hadir', 'terlambat'].includes(status); const tm = status === 'terlambat' ? 3 + (Math.round(r * 40) % 25) : 0
  return [{ tanggal, session_id: sid, nama_pola: (p.jabatan_fungsional || ['Staf'])[0], nama_sesi: 'Jam kerja', mulai, selesai, wajib_pulang: true, opsional: false,
    attendance_id: status ? 'demo-' + kunci : null, status, terlambat_menit: tm, sumber: u ? 'manual' : 'gps',
    datang_pada: hadir ? `${tanggal}T07:${String(20 + tm).padStart(2, '0')}:00+08:00` : null,
    status_pulang: u?.status_pulang || (hadir ? (tanggal < hariIni ? 'tepat' : 'belum') : null), pulang_pada: hadir && tanggal < hariIni ? `${tanggal}T14:05:00+08:00` : null,
    keterangan: u?.keterangan || (status === 'izin' ? 'Keperluan keluarga' : status === 'sakit' ? 'Demam' : status === 'dinas_luar' ? 'Rapat di kantor Kemenag' : null),
    keadaan: status ? 'selesai' : tanggal > hariIni || kini < new Date(`${tanggal}T07:00:00+08:00`) ? 'akan_datang' : 'terbuka' }]
}
const jamLalu = (j) => new Date(Date.now() - j * 3600e3).toISOString()
function panelDemo() {
  const t = hariIniISO()
  return {
    antrian: [
      { id: 'v1', nama: 'Ust. Hasan Basri, Lc.', niy: '2019070101', tanggal: t, nama_pola: 'Halaqah tahfizh', nama_sesi: 'Halaqah subuh', status: 'menunggu_verval', usulan_status: 'hadir', sumber: 'luar_area', bagian: 'datang', terlambat_menit: 0, dibuat: jamLalu(5),
        ev: { titik: 'Masjid', jarak_m: 1830, akurasi_m: 14, alasan: 'Mendampingi santri lomba MTQ tingkat kabupaten', pilihan: 'hadir', waktu: jamLalu(5), lat: -5.2, lng: 119.48 }, curiga: [] },
      { id: 'v2', nama: 'Ust. Abdul Hakim', niy: '2022020105', tanggal: t, nama_pola: 'Security', nama_sesi: 'Shift pagi', status: 'hadir', status_pulang: 'menunggu_verval', sumber: 'gps', bagian: 'pulang', cepat_pulang_menit: 40, dibuat: jamLalu(3),
        ev: { titik: 'Gedung sekolah', jarak_m: 640, akurasi_m: 120, alasan: 'Mengantar santri sakit ke puskesmas', waktu: jamLalu(3), lat: -5.21, lng: 119.49 }, curiga: ['akurasi_tidak_wajar'] },
      { id: 'v3', nama: 'Ustzh. Nurul Aini, S.Pd.', niy: '2020071502', tanggal: t, nama_pola: 'Guru', nama_sesi: 'Jam kerja', status: 'menunggu_verval', usulan_status: 'sakit', sumber: 'izin_sesi', bagian: 'datang', dibuat: jamLalu(1),
        keterangan: 'Izin sesi: Demam sejak semalam', ev: null, curiga: [] },
    ],
    koreksi: [
      { id: 'k1', status: 'menunggu', alasan: 'Lupa presensi, ada saksi rekan muhaffizh', status_baru: 'hadir', pulang_baru: null, dibuat: jamLalu(20), pengaju: 'Ust. Fadhil Rahman, S.Kom.',
        attendance_id: 'a1', nama: 'Ustzh. Khadijah Ramadhani, S.Ag.', tanggal: t, nama_sesi: 'Halaqah malam', nama_pola: 'Halaqah tahfizh', status_lama: 'tanpa_keterangan' },
    ],
    curiga: [
      { id: 'c1', jenis: 'perangkat_bersama', rincian: { pegawai_lain: ['Ust. Ilham Saputra, S.Sos.'] }, status: 'baru', dibuat: jamLalu(26), nama: 'Ust. Rizal Fahmi, S.E.',
        ev: { waktu: jamLalu(26), titik: 'Masjid', jarak_m: 15, akurasi_m: 9, di_area: true } },
      { id: 'c2', jenis: 'koordinat_identik', rincian: { lat: -5.2081, lng: 119.4949, jumlah_sebelumnya: 4 }, status: 'baru', dibuat: jamLalu(30), nama: 'Ust. Andi Saputra',
        ev: { waktu: jamLalu(30), titik: 'Masjid', jarak_m: 3, akurasi_m: 1, di_area: true } },
    ],
  }
}

export const useVerval = defineStore('verval', {
  state: () => ({ panel: { antrian: [], koreksi: [], curiga: [] }, dimuat: false, memuat: false }),
  getters: {
    jumlah: (s) => ({ antrian: s.panel.antrian.length, koreksi: s.panel.koreksi.filter((k) => k.status === 'menunggu').length, curiga: s.panel.curiga.filter((c) => c.status === 'baru').length }),
  },
  actions: {
    async muat() {
      this.memuat = true
      try {
        if (MODE_DEMO) { if (!this.dimuat) this.panel = panelDemo() }
        else this.panel = await rpc('panel_verval', { p_hari: 30 })
        this.dimuat = true
      } finally { this.memuat = false }
    },
    async verval(id, bagian, status, alasan) {
      if (MODE_DEMO) { this.panel.antrian = this.panel.antrian.filter((a) => a.id !== id); return }
      await rpc('verval_presensi', { p_id: id, p_bagian: bagian, p_status: status, p_alasan: alasan }); await this.muat()
    },
    async ajukanKoreksi(id, status, pulang, alasan) {
      if (MODE_DEMO) return
      await rpc('ajukan_koreksi', { p_id: id, p_status: status, p_pulang: pulang || null, p_alasan: alasan }); await this.muat()
    },
    async putuskanKoreksi(id, setuju, catatan) {
      if (MODE_DEMO) { const k = this.panel.koreksi.find((x) => x.id === id); if (k) { k.status = setuju ? 'disetujui' : 'ditolak'; k.catatan = catatan } return }
      await rpc('putuskan_koreksi', { p_id: id, p_setuju: setuju, p_catatan: catatan || null }); await this.muat()
    },
    async ubah(id, status, pulang, alasan) {
      if (MODE_DEMO) { ubahanDemo[String(id).replace(/^demo-/, '')] = { status, status_pulang: pulang || null, keterangan: alasan }; return }
      await rpc('ubah_presensi', { p_id: id, p_status: status, p_pulang: pulang || null, p_alasan: alasan })
    },
    async catatManual(emp, tanggal, sesi, status, alasan) {
      if (MODE_DEMO) { ubahanDemo[`${emp}|${tanggal}|${sesi}`] = { status, keterangan: alasan }; return }
      await rpc('catat_presensi_manual', { p_emp: emp, p_tanggal: tanggal, p_session: sesi, p_status: status, p_alasan: alasan })
    },
    async tinjau(id, status, catatan) {
      if (MODE_DEMO) { const c = this.panel.curiga.find((x) => x.id === id); if (c) { c.status = status; c.catatan = catatan } return }
      await rpc('tinjau_kecurigaan', { p_id: id, p_status: status, p_catatan: catatan || null }); await this.muat()
    },
    async harianPegawai(emp, tanggal) {
      if (MODE_DEMO) { const p = usePegawai().cari(emp); return { employee_id: emp, tanggal, sesi: p ? sesiDemo(p, tanggal) : [] } }
      return await rpc('presensi_harian', { p_emp: emp, p_tanggal: tanggal })
    },
    /** Semua pegawai aktif (bidang beserta cabangnya) dan sesi presensinya pada satu tanggal */
    async hariSemua(tanggal, unit) {
      if (MODE_DEMO) {
        const peg = usePegawai(); if (!peg.daftar.length) await peg.muat()
        const org = useOrganisasi(); if (!org.dimuat) await org.muat()
        const cakup = unit ? org.turunan(unit) : null
        return { tanggal, pegawai: peg.daftar.filter((p) => p.status_akun === 'aktif' && (!cakup || cakup.has(p.org_unit_id)))
          .map((p) => ({ employee_id: p.id, nama: p.nama_lengkap, niy: p.niy, jenis_kelamin: p.jenis_kelamin, org_unit_id: p.org_unit_id, unit: p.nama_unit,
            jabatan: (p.jabatan_fungsional || []).join(', '), sesi: sesiDemo(p, tanggal) })).sort((a, b) => a.nama.localeCompare(b.nama)) }
      }
      return await rpc('presensi_hari_pegawai', { p_tanggal: tanggal, p_unit: unit || null })
    },
    async riwayat(id) {
      if (MODE_DEMO || !id) return []
      return await rpc('riwayat_presensi', { p_id: id })
    },
  },
})
