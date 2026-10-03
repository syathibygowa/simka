// SIMKA PRO | src/stores/verval.js | v1.0 | Fase 2 – Tahap 6 Verval dan koreksi | 03/10/2026
// Panel admin presensi: antrian verval, permintaan koreksi, penanda kecurigaan, dan data presensi per pegawai.
// Semua perubahan lewat fungsi server yang memeriksa hak dan mencatat riwayat status.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { hariIniISO } from '@/lib/tanggal'

async function rpc(nama, isi) {
  const { data, error } = await supabase.rpc(nama, isi)
  if (error) throw new Error(error.hint && error.message ? error.message : pesanGalat(error))
  return data
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
      if (MODE_DEMO) return
      await rpc('ubah_presensi', { p_id: id, p_status: status, p_pulang: pulang || null, p_alasan: alasan })
    },
    async catatManual(emp, tanggal, sesi, status, alasan) {
      if (MODE_DEMO) return
      await rpc('catat_presensi_manual', { p_emp: emp, p_tanggal: tanggal, p_session: sesi, p_status: status, p_alasan: alasan })
    },
    async tinjau(id, status, catatan) {
      if (MODE_DEMO) { const c = this.panel.curiga.find((x) => x.id === id); if (c) { c.status = status; c.catatan = catatan } return }
      await rpc('tinjau_kecurigaan', { p_id: id, p_status: status, p_catatan: catatan || null }); await this.muat()
    },
    async harianPegawai(emp, tanggal) {
      if (MODE_DEMO) return { sesi: [] }
      return await rpc('presensi_harian', { p_emp: emp, p_tanggal: tanggal })
    },
    async riwayat(id) {
      if (MODE_DEMO || !id) return []
      return await rpc('riwayat_presensi', { p_id: id })
    },
  },
})
