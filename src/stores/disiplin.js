// SIMKA PRO | src/stores/disiplin.js | v1.0 | 14.6.0: Kedisiplinan Santri (pelanggaran tanpa poin, SP santri SP1–SP3, ketentuan) | 18/10/2026
// Toko Kedisiplinan Santri. Semua hak diperiksa server (hak_disiplin, boleh_catat_pelanggaran, boleh_lihat_disiplin, RLS);
// surat peringatan adalah surat keluar biasa di Persuratan (diperiksa TU, ditandatangani Direktur, nomor IZ).
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'
import { useSantri } from './santri'
import { hariIniISO } from '@/lib/tanggal'
import { tambahHari } from '@/lib/persuratan'
import { HAK_DISIPLIN_KOSONG, SET_DISIPLIN_BAWAAN, tingkatKategori } from '@/lib/disiplin'

const rpc = async (nama, arg) => { const { data, error } = await supabase.rpc(nama, arg); if (error) throw new Error(pesanGalat(error)); return data }
const salin = (o) => JSON.parse(JSON.stringify(o))

// ---------------------------------------------------------------------------------------------- mode demo
let DEMO = null
const hari = (n) => tambahHari(hariIniISO(), n)
const kel = (s, j) => (s?.kelompok || []).find((k) => k.jenis === j)?.nama || ''
function ringkasSantri(s) { return { student_id: s.id, nama: s.nama_lengkap, nis: s.nis, jenis_kelamin: s.jenis_kelamin, jenjang: s.jenjang, kelas: kel(s, 'kelas'), kamar: kel(s, 'kamar') } }
function demo() {
  if (DEMO) return DEMO
  const san = useSantri().daftar.filter((s) => s.status === 'aktif')
  const set = setDemo()
  const contoh = [
    [0, 2, 'Keluar lingkungan pondok tanpa izin', 'Keluar ke warung depan pondok setelah isya tanpa izin musyrif.', 'Gerbang belakang', '21:40', 'Dinasihati dan diminta membuat surat pernyataan'],
    [0, 9, 'Tidak mengikuti kegiatan tanpa izin', 'Tidak mengikuti halaqah subuh dua hari berturut-turut.', 'Masjid', '04:45', 'Diingatkan musyrif'],
    [0, 15, 'Membawa atau menggunakan telepon genggam/barang elektronik tanpa izin', 'Ditemukan membawa telepon genggam di lemari kamar.', 'Kamar Umar', '13:10', 'Telepon genggam disita dan diserahkan ke Kesantrian'],
    [3, 4, 'Terlambat mengikuti kegiatan pondok', 'Terlambat masuk kelas jam pertama.', 'Kelas', '07:20', 'Ditegur wali kelas'],
    [5, 6, 'Berkelahi atau melakukan kekerasan', 'Berkelahi dengan teman sekamar karena berebut tempat jemuran.', 'Asrama', '16:30', 'Dipisahkan dan didamaikan; dilaporkan ke Kesantrian'],
    [7, 1, 'Tidak menjaga kebersihan kamar atau lingkungan', 'Tidak melaksanakan piket kamar.', 'Kamar Ali', '06:30', 'Piket tambahan dua hari'],
    [9, 20, 'Merokok', 'Ditemukan merokok di belakang dapur.', 'Belakang dapur', '15:05', 'Dibina Bidang Kesantrian'],
    [9, 40, 'Meninggalkan pondok tanpa izin (kabur)', 'Meninggalkan pondok pada malam hari dan dijemput keluarga keesokan harinya.', 'Pondok', '23:00', 'Orang tua dipanggil'],
  ]
  const pel = contoh.filter((c) => san[c[0]]).map((c, i) => ({ id: 'pl' + i, ...ringkasSantri(san[c[0]]), tanggal: hari(-c[1]), jam: c[5], kategori: c[2],
    tingkat: tingkatKategori(set, c[2]), tempat: c[4], uraian: c[3], tindakan: c[6], saksi: null, bukti_id: null, warning_id: null, sp_tingkat: null,
    dicatat_oleh: 'p1', pencatat: i % 2 ? 'Ust. Rifqi Maulana (Security)' : 'Ust. Hasan Basri, Lc.', dicatat_pada: new Date(Date.now() - c[1] * 864e5).toISOString(), boleh_ubah: true }))
  const sp = []
  if (san[9]) {
    const dasar = pel.filter((p) => p.student_id === san[9].id)
    const w = { id: 'sps-1', ...ringkasSantri(san[9]), status_santri: 'aktif', tingkat: 2, kategori: dasar.map((p) => p.kategori), sanksi: set.sanksi[2], uraian: 'Pelanggaran berat berulang setelah SP-1.',
      pelanggaran: dasar.map((p) => ({ id: p.id, tanggal: p.tanggal, kategori: p.kategori, tingkat: p.tingkat, uraian: p.uraian })),
      diusulkan_oleh: 'e-kst', pengusul: 'Ust. Muhammad Ikhsan, S.Pd.I.', diusulkan_pada: new Date(Date.now() - 18 * 864e5).toISOString(), letter_id: 'sk-sps1', status_surat: 'terbit',
      status: 'terbit', keadaan: 'aktif', nomor: 'D.021/IZ/PPTQ-IAS/IV/1448', tanggal_surat: hari(-17), berlaku_mulai: hari(-17), berlaku_sampai: tambahHari(hari(-17), 182),
      status_diubah: false, diserahkan_pada: hari(-15), diserahkan_ket: 'Diserahkan saat pemanggilan orang tua', dicabut_pada: null, alasan: null, wali: 'Bapak Ahmad', hp_wali: '081234567890', saya_pengusul: false }
    dasar.forEach((p) => { p.warning_id = w.id; p.sp_tingkat = 2 })
    sp.push(w)
  }
  if (san[5]) {
    const dasar = pel.filter((p) => p.student_id === san[5].id)
    sp.push({ id: 'sps-2', ...ringkasSantri(san[5]), status_santri: 'aktif', tingkat: 1, kategori: dasar.map((p) => p.kategori), sanksi: set.sanksi[1], uraian: null,
      pelanggaran: dasar.map((p) => ({ id: p.id, tanggal: p.tanggal, kategori: p.kategori, tingkat: p.tingkat, uraian: p.uraian })),
      diusulkan_oleh: 'e-kst', pengusul: 'Ust. Muhammad Ikhsan, S.Pd.I.', diusulkan_pada: new Date(Date.now() - 3 * 36e5).toISOString(), letter_id: null, status_surat: 'diperiksa',
      status: 'diusulkan', keadaan: 'diusulkan', nomor: null, tanggal_surat: null, berlaku_mulai: null, berlaku_sampai: null, status_diubah: false, diserahkan_pada: null,
      diserahkan_ket: null, dicabut_pada: null, alasan: null, wali: 'Ibu Hasnah', hp_wali: '082345678901', saya_pengusul: false })
    dasar.forEach((p) => { p.warning_id = 'sps-2'; p.sp_tingkat = 1 })
  }
  const hasil = { pel, sp, set }
  if (san.length) DEMO = hasil   // simpan hanya setelah data santri demo termuat
  return hasil
}
let SET_DEMO = null
function setDemo() { SET_DEMO ??= salin(SET_DISIPLIN_BAWAAN); return SET_DEMO }
function terbukaDemo(sid) {
  const D = demo(); const batas = hari(-(setDemo().jendela_hari || 180))
  const x = D.pel.filter((p) => p.student_id === sid && !p.warning_id && p.tanggal >= batas)
  return { ringan: x.filter((p) => p.tingkat === 'ringan').length, sedang: x.filter((p) => p.tingkat === 'sedang').length, berat: x.filter((p) => p.tingkat === 'berat').length, jumlah: x.length }
}
function ambangDemo(sid) {
  const a = setDemo().ambang; const t = terbukaDemo(sid)
  return ['berat', 'sedang', 'ringan'].find((k) => a[k] > 0 && t[k] >= a[k]) || null
}

// ---------------------------------------------------------------------------------------------- toko
export const useDisiplin = defineStore('disiplin', {
  state: () => ({ hak: { ...HAK_DISIPLIN_KOSONG }, hakDimuat: false, set: null }),
  actions: {
    async muatHak() {
      if (MODE_DEMO) {
        const p = useSesi().peran
        this.hak = { lihat_semua: p !== 'pegawai', catat: true, catat_semua: p !== 'pegawai', usul: p === 'superadmin', kelola: p === 'superadmin', tu: p === 'admin',
          kesantrian: p === 'superadmin', pimpinan: p === 'superadmin', tampil: true }
      } else this.hak = { ...HAK_DISIPLIN_KOSONG, ...((await rpc('hak_disiplin')) || {}) }
      this.hakDimuat = true; return this.hak
    },
    async muatSet() {
      this.set = MODE_DEMO ? { ...salin(setDemo()), boleh_ubah: useSesi().peran === 'superadmin' } : await rpc('pengaturan_disiplin')
      return this.set
    },
    async simpanSet(p) {
      if (MODE_DEMO) { Object.assign(setDemo(), salin(p)); return this.muatSet() }
      this.set = await rpc('simpan_pengaturan_disiplin', { p }); return this.set
    },
    // ---------- Pelanggaran ----------
    async daftar({ mulai = null, selesai = null, santri = null } = {}) {
      if (MODE_DEMO) { await useSantri().muat(); return salin(demo().pel.filter((x) => (!santri || x.student_id === santri) && (!mulai || x.tanggal >= mulai) && (!selesai || x.tanggal <= selesai))) }
      return (await rpc('daftar_pelanggaran', { p_mulai: mulai, p_selesai: selesai, p_santri: santri })) || []
    },
    async cariSantri(q = '') {
      if (MODE_DEMO) {
        const san = useSantri(); await san.muat(); const t = q.toLowerCase().trim()
        return san.daftar.filter((s) => s.status === 'aktif' && (t.length < 2 ? (s.kelompok || []).length : `${s.nama_lengkap} ${s.nis}`.toLowerCase().includes(t))).slice(0, 40)
          .map((s) => ({ id: s.id, nama: s.nama_lengkap, nis: s.nis, jenis_kelamin: s.jenis_kelamin, jenjang: s.jenjang, kelas: kel(s, 'kelas'), kamar: kel(s, 'kamar'),
            sp_aktif: demo().sp.filter((w) => w.student_id === s.id && w.keadaan === 'aktif').reduce((m, w) => Math.max(m, w.tingkat), 0) || null, terbuka: terbukaDemo(s.id) }))
      }
      return (await rpc('cari_santri_disiplin', { p_cari: q })) || []
    },
    async simpan(isi) {
      if (MODE_DEMO) {
        await useSantri().muat(); const D = demo()
        const tingkat = isi.kategori === 'Lainnya' ? (isi.tingkat || 'ringan') : tingkatKategori(setDemo(), isi.kategori)
        if (isi.id) { Object.assign(D.pel.find((x) => x.id === isi.id), { ...isi, tingkat }); return isi.id }
        const s = useSantri().cari(isi.student_id) || {}
        const baru = { id: 'pl' + Date.now(), ...ringkasSantri(s), tempat: null, tindakan: null, saksi: null, bukti_id: null, warning_id: null, sp_tingkat: null, ...isi, tingkat,
          dicatat_oleh: 'saya', pencatat: useSesi().pengguna?.nama_lengkap, dicatat_pada: new Date().toISOString(), boleh_ubah: true }
        D.pel.unshift(baru); return baru.id
      }
      return rpc('simpan_pelanggaran', { p: isi })
    },
    async hapus(id, alasan = null) {
      if (MODE_DEMO) { const D = demo(); const x = D.pel.find((p) => p.id === id); if (x?.warning_id && D.sp.some((w) => w.id === x.warning_id && ['diusulkan', 'terbit'].includes(w.status))) throw new Error('Catatan ini menjadi dasar surat peringatan yang masih berlaku dan tidak dapat dihapus.'); D.pel = D.pel.filter((p) => p.id !== id); return }
      return rpc('hapus_pelanggaran', { p_id: id, p_alasan: alasan })
    },
    // ---------- Surat peringatan ----------
    async daftarSP({ mulai = null, selesai = null, santri = null } = {}) {
      if (MODE_DEMO) { await useSantri().muat(); return salin(demo().sp.filter((x) => (!santri || x.student_id === santri) && (!mulai || x.diusulkan_pada.slice(0, 10) >= mulai) && (!selesai || x.diusulkan_pada.slice(0, 10) <= selesai))) }
      return (await rpc('daftar_sp_santri', { p_mulai: mulai, p_selesai: selesai, p_santri: santri })) || []
    },
    async saran(sid) {
      if (MODE_DEMO) {
        await useSantri().muat(); const D = demo(); const aktif = D.sp.filter((w) => w.student_id === sid && w.keadaan === 'aktif'); const maks = aktif.reduce((m, w) => Math.max(m, w.tingkat), 0)
        return { saran: Math.min(maks + 1, 3), sp3: D.sp.some((w) => w.student_id === sid && w.tingkat === 3 && w.status === 'terbit'), diusulkan: D.sp.some((w) => w.student_id === sid && w.status === 'diusulkan'),
          aktif: aktif.map((w) => ({ id: w.id, tingkat: w.tingkat, nomor: w.nomor, tanggal_surat: w.tanggal_surat, berlaku_sampai: w.berlaku_sampai })),
          terbuka: terbukaDemo(sid), ambang: ambangDemo(sid), pelanggaran: salin(D.pel.filter((p) => p.student_id === sid && !p.warning_id)) }
      }
      return rpc('saran_sp_santri', { p_santri: sid })
    },
    async usul(p) {
      if (MODE_DEMO) {
        await useSantri().muat(); const D = demo(); const s = useSantri().cari(p.student_id) || {}
        const dasar = D.pel.filter((x) => p.pelanggaran_ids.includes(x.id))
        const w = { id: 'sps-' + Date.now(), ...ringkasSantri(s), status_santri: 'aktif', tingkat: p.tingkat, kategori: [...new Set(dasar.map((x) => x.kategori))], sanksi: p.sanksi, uraian: p.uraian || null,
          pelanggaran: dasar.map((x) => ({ id: x.id, tanggal: x.tanggal, kategori: x.kategori, tingkat: x.tingkat, uraian: x.uraian })), diusulkan_oleh: 'saya', pengusul: useSesi().pengguna?.nama_lengkap,
          diusulkan_pada: new Date().toISOString(), letter_id: null, status_surat: 'diperiksa', status: 'diusulkan', keadaan: 'diusulkan', nomor: null, tanggal_surat: null, berlaku_mulai: null,
          berlaku_sampai: null, status_diubah: false, diserahkan_pada: null, diserahkan_ket: null, dicabut_pada: null, alasan: null, wali: null, hp_wali: null, saya_pengusul: true }
        dasar.forEach((x) => { x.warning_id = w.id; x.sp_tingkat = p.tingkat })
        D.sp.unshift(w); return w.id
      }
      return rpc('usul_sp_santri', { p })
    },
    async batal(id, alasan) {
      if (MODE_DEMO) { const D = demo(); Object.assign(D.sp.find((x) => x.id === id), { status: 'batal', keadaan: 'batal', status_surat: 'dibatalkan', alasan }); D.pel.filter((p) => p.warning_id === id).forEach((p) => { p.warning_id = null; p.sp_tingkat = null }); return }
      return rpc('batal_sp_santri', { p_id: id, p_alasan: alasan })
    },
    async cabut(id, alasan) {
      if (MODE_DEMO) { Object.assign(demo().sp.find((x) => x.id === id), { status: 'dicabut', keadaan: 'dicabut', alasan, dicabut_pada: new Date().toISOString() }); return }
      return rpc('cabut_sp_santri', { p_id: id, p_alasan: alasan })
    },
    async serah(id, tanggal, ket) {
      if (MODE_DEMO) { Object.assign(demo().sp.find((x) => x.id === id), { diserahkan_pada: tanggal, diserahkan_ket: ket || null }); return }
      return rpc('serah_sp_santri', { p_id: id, p_tanggal: tanggal, p_ket: ket })
    },
  },
})
