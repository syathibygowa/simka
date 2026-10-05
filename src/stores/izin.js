// SIMKA PRO | src/stores/izin.js | v1.0 | Fase 6 – Tahap 2 Status otomatis dan perizinan santri | 06/10/2026
// Perizinan santri berjenjang: hak, ketentuan, peran pengusul, ajukan, ubah, putuskan, batalkan, catat keluar/kembali,
// dan daftar (persetujuan, menunggu, aktif, semua; dapat disaring per kelompok/kamar).
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'
import { useSantri } from './santri'
import { dataKelompokDemo } from '@/lib/demoKelompok'

const rpc = async (nama, arg) => { const { data, error } = await supabase.rpc(nama, arg); if (error) throw new Error(pesanGalat(error)); return data }
const jam = (j) => new Date(Date.now() + j * 3600000).toISOString()
const HAK_KOSONG = { kelola: false, puncak: false, unit_putus: [], ajukan: false, lihat: false }

let DEMO = null
function demo() {
  if (DEMO) return DEMO
  const san = useSantri(); const d = dataKelompokDemo(san.daftar)
  const kamar = (id) => d.anggota.filter((a) => a.group_id === id && !a.selesai).map((a) => san.cari(a.student_id)).filter(Boolean)
  const um = kamar('g-kum'); const ab = kamar('g-kab'); const ai = kamar('g-kai')
  const buat = (s, o) => s && ({ id: 'iz' + Math.random().toString(36).slice(2, 8), student_id: s.id, jenis: 'pulang', penjemput: 'Ayah', hubungan_penjemput: 'Ayah', hp_penjemput: '081234567890',
    lama_hari: 1, sumber: 'pengasuh', peran_pengusul: 'musyrif', pengusul: 'Ust. Syamsul Arifin, S.Pd.', unit_kode: 'KESANTRIAN', perlu_pimpinan: false,
    keluar_aktual: null, kembali_pada: null, catatan: null, created_at: jam(-30), keputusan: [], ...o })
  DEMO = [
    buat(um[3], { alasan: 'Acara pernikahan kakak', status: 'diajukan', keluar_pada: jam(20), kembali_batas: jam(68), lama_hari: 2, created_at: jam(-1) }),
    buat(ab[1], { alasan: 'Kontrol gigi ke dokter keluarga', status: 'diajukan', jenis: 'keluar', keluar_pada: jam(3), kembali_batas: jam(7), pengusul: 'Ust. Muhammad Ikhsan, S.Pd.I.', created_at: jam(-2) }),
    buat(ai[2], { alasan: 'Ziarah keluarga di Bone', status: 'disetujui_bidang', keluar_pada: jam(30), kembali_batas: jam(126), lama_hari: 4, perlu_pimpinan: true, pengusul: 'Ustzh. Nurul Aini, S.Pd.',
      keputusan: [{ tingkat: 1, keputusan: 'setuju', sebagai: 'Kepala Bidang Kesantrian', oleh: 'Ust. Muhammad Ikhsan, S.Pd.I.', catatan: null, pada: jam(-3) }] }),
    buat(um[5], { alasan: 'Keluarga sakit', status: 'keluar', keluar_pada: jam(-26), keluar_aktual: jam(-25), kembali_batas: jam(-2), terlambat: true,
      keputusan: [{ tingkat: 1, keputusan: 'setuju', sebagai: 'Kepala Bidang Kesantrian', oleh: 'Ust. Muhammad Ikhsan, S.Pd.I.', catatan: null, pada: jam(-27) }] }),
    buat(ab[0], { alasan: 'Mengurus KTP', status: 'disetujui', jenis: 'keluar', keluar_pada: jam(1), kembali_batas: jam(5), pengusul: 'Ust. Muhammad Ikhsan, S.Pd.I.',
      keputusan: [{ tingkat: 1, keputusan: 'setuju', sebagai: 'Kepala Bidang Kesantrian', oleh: 'Ust. Muhammad Ikhsan, S.Pd.I.', catatan: null, pada: jam(-4) }] }),
    buat(um[1], { alasan: 'Libur keluarga', status: 'kembali', keluar_pada: jam(-120), keluar_aktual: jam(-120), kembali_batas: jam(-72), kembali_pada: jam(-74), lama_hari: 2,
      keputusan: [{ tingkat: 1, keputusan: 'setuju', sebagai: 'Kepala Bidang Kesantrian', oleh: 'Ust. Muhammad Ikhsan, S.Pd.I.', catatan: null, pada: jam(-130) }] }),
    buat(ab[2], { alasan: 'Acara keluarga mendadak', status: 'ditolak', keluar_pada: jam(-50), kembali_batas: jam(-26), pengusul: 'Ust. Muhammad Ikhsan, S.Pd.I.',
      keputusan: [{ tingkat: 1, keputusan: 'tolak', sebagai: 'Kepala Bidang Kesantrian', oleh: 'Ust. Muhammad Ikhsan, S.Pd.I.', catatan: 'Bertepatan dengan ujian tahfizh', pada: jam(-48) }] }),
  ].filter(Boolean)
  return DEMO
}

export const useIzin = defineStore('izin', {
  state: () => ({ hak: { ...HAK_KOSONG }, hakDimuat: false, pengaturan: { batas_hari_bidang: 2, lama_bawaan_hari: 2 }, saluran: null }),
  getters: {
    pemutus: (s) => s.hak.puncak || s.hak.unit_putus.length > 0,
  },
  actions: {
    async muatHak() {
      if (MODE_DEMO) {
        const p = useSesi().peran
        this.hak = p === 'superadmin' ? { kelola: true, puncak: true, unit_putus: ['KESANTRIAN', 'TAHFIZH', 'WUSTHA', 'SMA'], ajukan: true, lihat: true }
          : p === 'admin' ? { ...HAK_KOSONG, kelola: true, ajukan: true, lihat: true } : { ...HAK_KOSONG, ajukan: true, lihat: true }
      } else this.hak = { ...HAK_KOSONG, ...((await rpc('hak_izin')) || {}) }
      this.hakDimuat = true
      try { this.pengaturan = MODE_DEMO ? this.pengaturan : await rpc('pengaturan_izin') } catch { /* bawaan */ }
      return this.hak
    },
    async simpanPengaturan(isi) {
      if (MODE_DEMO) { this.pengaturan = { ...isi }; return }
      this.pengaturan = await rpc('simpan_pengaturan_izin', { p: isi })
    },

    /** cakupan: persetujuan | menunggu | aktif | semua; group: saring kamar/kelompok. */
    async daftar(cakupan, { mulai = null, selesai = null, group = null } = {}) {
      if (!MODE_DEMO) return (await rpc('daftar_izin', { p_cakupan: cakupan, p_mulai: mulai, p_selesai: selesai, p_group: group })) || []
      const san = useSantri(); await san.muat(); const kel = dataKelompokDemo(san.daftar); const sesi = useSesi(); const atas = sesi.peran === 'superadmin'
      const anggota = group ? new Set(kel.anggota.filter((a) => a.group_id === group && !a.selesai).map((a) => a.student_id)) : null
      const terlihat = new Set(san.daftar.map((s) => s.id))
      const kelDari = (id, j) => kel.anggota.filter((a) => a.student_id === id && !a.selesai).map((a) => kel.kelompok.find((g) => g.id === a.group_id)).filter((g) => g?.jenis === j).map((g) => g.nama).join(', ') || null
      return demo().filter((x) => terlihat.has(x.student_id) && (!anggota || anggota.has(x.student_id))).filter((x) => {
        if (cakupan === 'persetujuan') return atas && ['diajukan', 'disetujui_bidang'].includes(x.status)
        if (cakupan === 'menunggu') return ['diajukan', 'disetujui_bidang'].includes(x.status)
        if (cakupan === 'aktif') return ['disetujui', 'keluar'].includes(x.status)
        const t = x.keluar_pada.slice(0, 10)
        return (!mulai || t >= mulai) && (!selesai || t <= selesai) || ['diajukan', 'disetujui_bidang', 'disetujui', 'keluar'].includes(x.status)
      }).map((x) => { const s = san.cari(x.student_id) || {}
        return { ...x, nama: s.nama_lengkap, nis: s.nis, jenis_kelamin: s.jenis_kelamin, kelas: kelDari(x.student_id, 'kelas'), kamar: kelDari(x.student_id, 'kamar'),
          pemutus: 'Kepala Bidang Kesantrian', terlambat: !!x.terlambat,
          boleh_putus: atas && ['diajukan', 'disetujui_bidang'].includes(x.status), boleh_ubah: x.status === 'diajukan',
          boleh_batal: ['diajukan', 'disetujui_bidang', 'disetujui'].includes(x.status), boleh_catat: ['disetujui', 'keluar'].includes(x.status),
          urut: ['diajukan', 'disetujui_bidang'].includes(x.status) ? '0' : x.terlambat ? '1' : ['disetujui', 'keluar'].includes(x.status) ? '2' : '3' }
      }).sort((a, b) => a.urut.localeCompare(b.urut) || b.keluar_pada.localeCompare(a.keluar_pada))
    },

    async peranPengusul(santriId) {
      if (!MODE_DEMO) return (await rpc('peran_pengusul_izin', { p_santri: santriId })) || []
      const san = useSantri(); const kel = dataKelompokDemo(san.daftar); const s = san.cari(santriId)
      const peg = useSesi().peran === 'pegawai'
      const hasil = kel.anggota.filter((a) => a.student_id === santriId && !a.selesai).map((a) => kel.kelompok.find((g) => g.id === a.group_id))
        .filter((g) => g && ['kamar', 'halaqah', 'kelas'].includes(g.jenis) && (!peg || g.pengasuh.some((p) => p.employee_id === 'p1')))
        .map((g) => ({ peran: g.jenis === 'kamar' ? 'musyrif' : g.jenis === 'halaqah' ? 'muhaffizh' : 'wali_kelas',
          unit: g.jenis === 'kamar' ? 'KESANTRIAN' : g.jenis === 'halaqah' ? 'TAHFIZH' : s?.jenjang === 'sma' ? 'SMA' : 'WUSTHA', kelompok: g.nama }))
      return peg ? hasil : [...hasil, { peran: 'admin', unit: 'KESANTRIAN', kelompok: null }]
    },

    async ajukan(isi) {
      if (!MODE_DEMO) return rpc('ajukan_izin', { p: isi })
      const lama = Math.max(1, Math.ceil((new Date(isi.kembali_batas) - new Date(isi.keluar_pada)) / 86400000))
      const unit = { musyrif: 'KESANTRIAN', muhaffizh: 'TAHFIZH', admin: 'KESANTRIAN' }[isi.peran] || 'WUSTHA'
      demo().unshift({ ...isi, id: 'iz' + Date.now(), status: 'diajukan', lama_hari: lama, sumber: 'pengasuh', peran_pengusul: isi.peran, pengusul: useSesi().pengguna?.nama_lengkap,
        unit_kode: unit, perlu_pimpinan: lama > this.pengaturan.batas_hari_bidang, keluar_aktual: null, kembali_pada: null, created_at: new Date().toISOString(), keputusan: [] })
    },
    async ubah(id, isi) {
      if (!MODE_DEMO) return rpc('lengkapi_izin', { p_id: id, p: isi })
      Object.assign(demo().find((x) => x.id === id), isi)
    },
    async putuskan(id, keputusan, catatan) {
      if (!MODE_DEMO) return rpc('putuskan_izin', { p_id: id, p_keputusan: keputusan, p_catatan: catatan || null })
      const x = demo().find((y) => y.id === id); const tingkat = x.status === 'diajukan' ? 1 : 2
      x.keputusan = [...x.keputusan, { tingkat, keputusan, sebagai: tingkat === 1 ? 'Kepala Bidang Kesantrian' : 'Direktur/Wakil Direktur', oleh: useSesi().pengguna?.nama_lengkap, catatan, pada: new Date().toISOString() }]
      x.status = keputusan === 'tolak' ? 'ditolak' : 'disetujui'
      return x.status
    },
    async batalkan(id, alasan) {
      if (!MODE_DEMO) return rpc('batalkan_izin', { p_id: id, p_alasan: alasan })
      Object.assign(demo().find((x) => x.id === id), { status: 'dibatalkan', catatan: 'Dibatalkan: ' + alasan })
    },
    async catat(id, aksi, waktu = null) {
      if (!MODE_DEMO) return rpc('catat_gerbang_izin', { p_id: id, p_aksi: aksi, p_waktu: waktu })
      const x = demo().find((y) => y.id === id); const t = waktu || new Date().toISOString()
      if (aksi === 'keluar') Object.assign(x, { status: 'keluar', keluar_aktual: t })
      else Object.assign(x, { status: 'kembali', kembali_pada: t, terlambat: new Date(t) > new Date(x.kembali_batas) })
    },

    dengarkan(fn) {
      if (MODE_DEMO || this.saluran) return
      this.saluran = supabase.channel('izin-santri').on('postgres_changes', { event: '*', schema: 'public', table: 'student_permits' }, () => fn()).subscribe()
    },
    berhenti() { if (this.saluran) { supabase.removeChannel(this.saluran); this.saluran = null } },
  },
})
