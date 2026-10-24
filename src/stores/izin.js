// SIMKA PRO | src/stores/izin.js | v1.2 | 14.20.0: surat izin, kontak pemutus (WA), izin kolektif, rekap izin per santri | 22/10/2026
// v1.2: kontakPemutus (tingkat 1 kepala bidang/unit, tingkat 2 Direktur/Wadir) untuk tombol WA "Minta persetujuan"; surat(id)
//       data cetak surat izin bernomor dan berkode validasi; rekap(santri) pengganti buku saku perizinan; izin kolektif
//       (daftarKolektif, ajukanKolektif, putuskanKolektif, batalkanKolektif, catatKolektif).
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
const HAK_KOSONG = { kelola: false, puncak: false, unit_putus: [], ajukan: false, lihat: false, kolektif: false }

const UNIT_LABEL = { KESANTRIAN: 'Kepala Bidang Kesantrian', TAHFIZH: 'Kepala Bidang Tahfizh', WUSTHA: 'Kepala Kesetaraan Wustha', SMA: 'Kepala SMA' }
let KOL = null
/** Contoh izin kolektif (mode demo): lomba MTQ (menunggu Direktur) dan olimpiade (disetujui). */
function DEMO_KOL() {
  if (KOL) return KOL
  const san = useSantri(); const d = dataKelompokDemo(san.daftar)
  const kelDari = (id, j) => d.anggota.filter((a) => a.student_id === id && !a.selesai).map((a) => d.kelompok.find((g) => g.id === a.group_id)).filter((g) => g?.jenis === j).map((g) => g.nama).join(', ') || null
  const ag = (s, st) => s && ({ permit_id: 'kp' + s.id, student_id: s.id, nama: s.nama_lengkap, nis: s.nis, jenis_kelamin: s.jenis_kelamin, jenjang: s.jenjang, kelas: kelDari(s.id, 'kelas'), kamar: kelDari(s.id, 'kamar'), status: st, keluar_aktual: null, kembali_pada: null })
  const putra = san.daftar.filter((s) => s.status === 'aktif' && s.jenis_kelamin === 'L')
  KOL = [
    { id: 'kol1', kegiatan: 'Lomba MTQ Kabupaten Gowa', tempat: 'Masjid Agung Syekh Yusuf, Sungguminasa', alasan: 'Mewakili pondok pada cabang tilawah dan hifzh 5 juz', jenis: 'pulang',
      keluar_pada: jam(26), kembali_batas: jam(98), lama_hari: 3, status: 'disetujui_bidang', perlu_pimpinan: true, nomor_surat: null, kode_validasi: null,
      pendamping: 'Ust. Hasan Basri, Lc.', pendamping_niy: '2019070101', hp_pendamping: '081234500010', pengusul: 'Ust. Hasan Basri, Lc.', pengusul_niy: '2019070101', created_at: jam(-5),
      keputusan: [{ tingkat: 1, keputusan: 'setuju', sebagai: 'Kepala Bidang Kesantrian', oleh: 'Ust. Muhammad Ikhsan, S.Pd.I.', niy: '2018010101', catatan: 'Jaga adab dan shalat berjamaah', pada: jam(-2) }],
      anggota: [ag(putra[0], 'disetujui_bidang'), ag(putra[4], 'disetujui_bidang'), ag(putra[9], 'disetujui_bidang'), ag(putra[13], 'disetujui_bidang')].filter(Boolean) },
    { id: 'kol2', kegiatan: 'Olimpiade Sains Nasional tingkat provinsi', tempat: 'Universitas Negeri Makassar', alasan: 'Peserta bidang matematika dan biologi', jenis: 'keluar',
      keluar_pada: jam(2), kembali_batas: jam(11), lama_hari: 1, status: 'disetujui', perlu_pimpinan: false, nomor_surat: 'SIK.019/PPTQ-IAS/V/1448', kode_validasi: 'R4KD-7MQX',
      pendamping: 'Ust. Muhammad Ilham, M.Pd.', pendamping_niy: '2020080202', hp_pendamping: '081234500011', pengusul: 'Ust. Muhammad Ilham, M.Pd.', pengusul_niy: '2020080202', created_at: jam(-30),
      keputusan: [{ tingkat: 1, keputusan: 'setuju', sebagai: 'Kepala Bidang Kesantrian', oleh: 'Ust. Muhammad Ikhsan, S.Pd.I.', niy: '2018010101', catatan: null, pada: jam(-26) }],
      anggota: [ag(putra[2], 'disetujui'), ag(putra[6], 'disetujui'), ag(putra[11], 'disetujui')].filter(Boolean) },
  ]
  return KOL
}

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
  DEMO.forEach((x, i) => { if (['disetujui', 'keluar', 'kembali'].includes(x.status)) Object.assign(x, { nomor_surat: `SIK.0${11 + i}/PPTQ-IAS/V/1448`, kode_validasi: ['K7PW-3HQA', 'M4TR-9XZB', 'P2LD-8NCE', 'H6JC-4WRT'][i % 4] }) })
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
      } else {
        this.hak = { ...HAK_KOSONG, ...((await rpc('hak_izin')) || {}) }
        try { this.hak.kolektif = !!(await rpc('boleh_ajukan_kolektif')) } catch { this.hak.kolektif = false }
      }
      if (MODE_DEMO) this.hak.kolektif = true
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
          boleh_batal: ['diajukan', 'disetujui_bidang', 'disetujui'].includes(x.status), boleh_catat: ['disetujui', 'keluar'].includes(x.status) && sesi.peran !== 'pegawai',
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
      const id = 'iz' + Date.now()
      demo().unshift({ ...isi, id, status: 'diajukan', lama_hari: lama, sumber: 'pengasuh', peran_pengusul: isi.peran, pengusul: useSesi().pengguna?.nama_lengkap,
        unit_kode: unit, perlu_pimpinan: lama > this.pengaturan.batas_hari_bidang, keluar_aktual: null, kembali_pada: null, created_at: new Date().toISOString(), keputusan: [] })
      return id
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
      if (x.status === 'disetujui' && !x.nomor_surat) Object.assign(x, { nomor_surat: `SIK.0${10 + demo().indexOf(x)}/PPTQ-IAS/V/1448`, kode_validasi: 'DEMO-' + String(1000 + demo().indexOf(x)) })
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

    // ------------------------------------------------------------------ 14.20.0
    /** Pemutus izin per unit dengan nomor HP: [{ tingkat: 1|2, nama, jabatan, no_hp }] (disimpan per unit). */
    async kontakPemutus(unit) {
      const k = unit || 'KESANTRIAN'
      if (this._kontak?.[k]) return this._kontak[k]
      const hasil = MODE_DEMO ? [
        { tingkat: 1, nama: { KESANTRIAN: 'Ust. Muhammad Ikhsan, S.Pd.I.', TAHFIZH: 'Ust. Abdul Hafizh, Lc.', WUSTHA: 'Ust. Ahmad Syarif, S.Pd.', SMA: 'Ust. Muhammad Ilham, M.Pd.' }[k], jabatan: UNIT_LABEL[k], no_hp: '081234500001' },
        { tingkat: 2, nama: 'Ust. Abdurrahman Hakim, Lc., M.Ag.', jabatan: 'Direktur (Mudir)', no_hp: '081234500002' },
      ] : ((await rpc('kontak_pemutus_izin', { p_unit: k })) || [])
      this._kontak = { ...(this._kontak || {}), [k]: hasil }
      return hasil
    },
    /** Data cetak surat izin perorangan; bila bagian izin kolektif → { kolektif_id }. */
    async surat(id) {
      if (!MODE_DEMO) return rpc('surat_izin_santri', { p_id: id })
      const x = demo().find((y) => y.id === id) || DEMO_KOL().flatMap((k) => k.anggota.map((a) => ({ ...a, kolektif_id: k.id }))).find((a) => a.permit_id === id)
      if (!x) throw new Error('Izin tidak ditemukan.')
      if (x.kolektif_id) return { kolektif_id: x.kolektif_id }
      const san = useSantri(); const s = san.cari(x.student_id) || {}; const kel = dataKelompokDemo(san.daftar)
      const kelDari = (j) => kel.anggota.filter((a) => a.student_id === x.student_id && !a.selesai).map((a) => kel.kelompok.find((g) => g.id === a.group_id)).filter((g) => g?.jenis === j).map((g) => g.nama).join(', ') || null
      return { ...x, nomor: x.nomor_surat || 'SIK.014/PPTQ-IAS/V/1448', kode_validasi: x.kode_validasi || 'K7PW-3HQA', kop: { SMA: 'sma', WUSTHA: 'wustha' }[x.unit_kode] || 'pondok',
        santri: { nama: s.nama_lengkap, nis: s.nis, nisn: s.nisn, jenjang: s.jenjang, tempat_lahir: s.tempat_lahir, tanggal_lahir: s.tanggal_lahir, kelas: kelDari('kelas'), kamar: kelDari('kamar'), halaqah: kelDari('halaqah') },
        pengusul: { nama: x.pengusul, niy: '2019070101', peran: x.peran_pengusul },
        persetujuan: x.keputusan.map((k) => ({ ...k, nama: k.oleh, niy: '2018010101' })), wali: { nama: 'Bapak ' + (s.nama_lengkap || '').split(' ')[0], hubungan: 'Ayah', no_hp: '081234567890' } }
    },
    /** Rekap izin seorang santri (pengganti buku saku perizinan). */
    async rekap(santriId) {
      if (!MODE_DEMO) return rpc('rekap_izin_santri', { p_student: santriId })
      const san = useSantri(); await san.muat(); const s = san.cari(santriId) || {}
      const milik = [...demo().filter((x) => x.student_id === santriId), ...DEMO_KOL().flatMap((k) => k.anggota.filter((a) => a.student_id === santriId).map((a) => ({ ...a, id: a.permit_id, jenis: k.jenis, alasan: k.kegiatan + ': ' + k.alasan,
        keluar_pada: k.keluar_pada, kembali_batas: k.kembali_batas, lama_hari: k.lama_hari, kegiatan: k.kegiatan, nomor_surat: k.nomor_surat, keputusan: k.keputusan, sumber: 'kolektif', pengusul: k.pengusul })))]
      // contoh riwayat lebih panjang agar buku saku terisi
      const lama = [-60, -45, -30, -12].map((h, i) => ({ id: 'rk' + i, jenis: i % 2 ? 'keluar' : 'pulang', sumber: i === 2 ? 'klinik' : 'pengasuh', alasan: ['Acara keluarga', 'Periksa gigi', 'Dipulangkan klinik untuk pemulihan: demam', 'Pernikahan kakak'][i],
        status: 'kembali', keluar_pada: jam(h * 24), kembali_batas: jam(h * 24 + (i % 2 ? 4 : 48)), lama_hari: i % 2 ? 1 : 2, keluar_aktual: jam(h * 24 + 0.5), kembali_pada: jam(h * 24 + (i % 2 ? 3.5 : 49.5)),
        nomor_surat: `SIK.00${i + 1}/PPTQ-IAS/IV/1448`, penjemput: 'Ayah', hubungan_penjemput: 'Ayah', pengusul: 'Ust. Syamsul Arifin, S.Pd.', peran_pengusul: i === 2 ? 'petugas_klinik' : 'musyrif',
        keputusan: [{ keputusan: 'setuju', oleh: 'Ust. Muhammad Ikhsan, S.Pd.I.', sebagai: 'Kepala Bidang Kesantrian' }] }))
      const izin = [...lama, ...milik].filter((x) => ['disetujui', 'keluar', 'kembali'].includes(x.status)).map((x) => ({ ...x,
        terlambat_menit: x.kembali_pada && new Date(x.kembali_pada) > new Date(x.kembali_batas) ? Math.round((new Date(x.kembali_pada) - new Date(x.kembali_batas)) / 60000) : null,
        disetujui: (x.keputusan || []).filter((k) => k.keputusan === 'setuju').map((k) => `${k.oleh} (${k.sebagai})`).join('; ') || null })).sort((a, b) => a.keluar_pada.localeCompare(b.keluar_pada))
      const kel = dataKelompokDemo(san.daftar)
      const kelDari = (j) => kel.anggota.filter((a) => a.student_id === santriId && !a.selesai).map((a) => kel.kelompok.find((g) => g.id === a.group_id)).filter((g) => g?.jenis === j).map((g) => g.nama).join(', ') || null
      return { santri: { id: s.id, nama: s.nama_lengkap, nis: s.nis, nisn: s.nisn, jenjang: s.jenjang, tempat_lahir: s.tempat_lahir, tanggal_lahir: s.tanggal_lahir, kelas: kelDari('kelas'), kamar: kelDari('kamar'), halaqah: kelDari('halaqah') },
        izin, ditolak: 1, dibatalkan: 0 }
    },

    // ---------- Izin kolektif ----------
    async daftarKolektif(cakupan = 'semua', id = null) {
      if (!MODE_DEMO) return (await rpc('daftar_izin_kolektif', { p_cakupan: cakupan, p_id: id })) || []
      const atas = useSesi().peran === 'superadmin'
      return DEMO_KOL().filter((k) => (!id || k.id === id) && (cakupan !== 'persetujuan' || ['diajukan', 'disetujui_bidang'].includes(k.status)))
        .map((k) => ({ ...k, boleh_putus: atas && ['diajukan', 'disetujui_bidang'].includes(k.status), boleh_batal: ['diajukan', 'disetujui_bidang', 'disetujui'].includes(k.status),
          boleh_catat: k.status === 'disetujui' && useSesi().peran !== 'pegawai' }))
    },
    async ajukanKolektif(isi) {
      if (!MODE_DEMO) return rpc('ajukan_izin_kolektif', { p: isi })
      const san = useSantri(); const id = 'kol' + Date.now(); const lama = Math.max(1, Math.ceil((new Date(isi.kembali_batas) - new Date(isi.keluar_pada)) / 86400000))
      DEMO_KOL().unshift({ id, ...isi, lama_hari: lama, status: 'diajukan', perlu_pimpinan: lama > this.pengaturan.batas_hari_bidang, pengusul: useSesi().pengguna?.nama_lengkap, pengusul_niy: '2019070101',
        pendamping: isi.pendamping_nama || isi.pendamping_lain, keputusan: [], created_at: new Date().toISOString(),
        anggota: isi.santri.map((sid) => { const s = san.cari(sid) || {}; const kel = dataKelompokDemo(san.daftar)
          const dari = (j) => kel.anggota.filter((a) => a.student_id === sid && !a.selesai).map((a) => kel.kelompok.find((g) => g.id === a.group_id)).filter((g) => g?.jenis === j).map((g) => g.nama).join(', ') || null
          return { permit_id: 'kp' + sid, student_id: sid, nama: s.nama_lengkap, nis: s.nis, jenis_kelamin: s.jenis_kelamin, jenjang: s.jenjang, kelas: dari('kelas'), kamar: dari('kamar'), status: 'diajukan' } }) })
      return id
    },
    async putuskanKolektif(id, keputusan, catatan) {
      if (!MODE_DEMO) return rpc('putuskan_izin_kolektif', { p_id: id, p_keputusan: keputusan, p_catatan: catatan || null })
      const k = DEMO_KOL().find((x) => x.id === id); const tingkat = k.status === 'diajukan' ? 1 : 2
      k.keputusan = [...k.keputusan, { tingkat, keputusan, sebagai: tingkat === 1 ? 'Kepala Bidang Kesantrian' : 'Direktur/Wakil Direktur', oleh: useSesi().pengguna?.nama_lengkap, catatan, pada: new Date().toISOString() }]
      k.status = keputusan === 'tolak' ? 'ditolak' : tingkat === 1 && k.perlu_pimpinan ? 'disetujui_bidang' : 'disetujui'
      if (k.status === 'disetujui') Object.assign(k, { nomor_surat: 'SIK.021/PPTQ-IAS/V/1448', kode_validasi: 'R4KD-7MQX' })
      k.anggota.forEach((a) => { a.status = k.status })
      return k.status
    },
    async batalkanKolektif(id, alasan) {
      if (!MODE_DEMO) return rpc('batalkan_izin_kolektif', { p_id: id, p_alasan: alasan })
      const k = DEMO_KOL().find((x) => x.id === id); k.status = 'dibatalkan'; k.anggota.forEach((a) => { a.status = 'dibatalkan' })
    },
    async catatKolektif(id, aksi) {
      if (!MODE_DEMO) return rpc('catat_gerbang_kolektif', { p_id: id, p_aksi: aksi })
      const k = DEMO_KOL().find((x) => x.id === id); const t = new Date().toISOString(); let n = 0
      k.anggota.forEach((a) => { if (aksi === 'keluar' && a.status === 'disetujui') { a.status = 'keluar'; a.keluar_aktual = t; n++ } else if (aksi === 'kembali' && a.status === 'keluar') { a.status = 'kembali'; a.kembali_pada = t; n++ } })
      if (k.anggota.every((a) => ['kembali', 'dibatalkan', 'ditolak'].includes(a.status))) k.status = 'selesai'
      return { tercatat: n, gagal: [] }
    },

    dengarkan(fn) {
      if (MODE_DEMO || this.saluran) return
      this.saluran = supabase.channel('izin-santri').on('postgres_changes', { event: '*', schema: 'public', table: 'student_permits' }, () => fn()).subscribe()
    },
    berhenti() { if (this.saluran) { supabase.removeChannel(this.saluran); this.saluran = null } },
  },
})
