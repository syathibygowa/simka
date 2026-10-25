// SIMKA PRO | src/stores/alumni.js | v1.0 | 14.25.0: alumni (profil, rencana lanjut studi, buku alumni) dan arsip tahun ajaran | 25/10/2026
// Alumni = santri berstatus Lulus (otomatis saat kelulusan di Naik Kelas atau ubah status). Profil alumni berbentuk CV: biodata,
// orang tua, riwayat kelas/halaqah/kamar/ekskul seluruh tahun ajaran, hafalan resmi, sertifikat, prestasi, dan rencana lanjut studi.
// Arsip tahun ajaran: kelompok dan santri tahun ajaran mana pun (termasuk yang sudah lewat) untuk membuka rapor dan rekam lama.
// Semua fungsi khusus admin dan superadmin (diperiksa server).
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { useSantri } from './santri'
import { useKelompokSantri } from './kelompokSantri'

const rpc = async (nama, arg) => { const { data, error } = await supabase.rpc(nama, arg); if (error) throw new Error(pesanGalat(error)); return data }

// ---------- Mode demo ----------
const KAMPUS_DEMO = [
  ['kuliah', 'ptkin', 'UIN Alauddin Makassar', 'Syariah dan Hukum', 'Hukum Keluarga Islam', 'Makassar', 'SPAN-PTKIN', 'diterima'],
  ['kuliah', 'negeri', 'Universitas Hasanuddin', 'Kedokteran', 'Pendidikan Dokter', 'Makassar', 'SNBP', 'mendaftar'],
  ['kuliah', 'luar_negeri', 'Universitas Islam Madinah', "Syari'ah", "Syari'ah", 'Madinah', 'Seleksi mandiri', 'rencana'],
  ['kuliah', 'swasta', 'STIBA Makassar', 'Syariah', 'Perbandingan Mazhab', 'Makassar', 'Mandiri', 'diterima'],
  ['pengabdian', null, 'Pondok Pesantren Wahdah Islamiyah', null, null, 'Gowa', null, 'berjalan'],
  ['kuliah', 'kedinasan', 'Politeknik Keuangan Negara STAN', 'Akuntansi', 'D3 Akuntansi', 'Tangerang Selatan', 'SPMB PKN', 'rencana'],
]
let DEMO = null
function demo() {
  if (DEMO) return DEMO
  const san = useSantri().daftar.filter((s) => [9, 12].includes(Number(s.tingkat)))
  DEMO = { profil: {} }
  DEMO.daftar = san.map((s, i) => {
    const k = KAMPUS_DEMO[i % KAMPUS_DEMO.length]; const sma = s.jenjang === 'sma'
    const al = sma || i % 2 ? { tahun_lulus: 2026, lanjut: sma ? k[0] : 'pesantren', jenis_pt: sma ? k[1] : null, kampus: sma ? k[2] : 'SMA Pesantren Imam Asy-Syathiby', fakultas: sma ? k[3] : null,
      prodi: sma ? k[4] : null, kota: k[5], negara: k[1] === 'luar_negeri' ? 'Arab Saudi' : 'Indonesia', jalur: sma ? k[6] : null, status_daftar: k[7], tahun_mulai: 2026,
      beasiswa: i % 3 === 0 ? 'Beasiswa Tahfizh Pemerintah Daerah' : null, hp: s.kontak?.[0]?.no_hp || null, email: null, alamat_kini: null,
      cita_cita: ['Dokter muslim', 'Hakim agama', 'Dai dan pendidik', 'Ahli ekonomi syariah'][i % 4], motto: ['Ilmu sebelum berkata dan beramal', 'Al-Quran di dada, ilmu di kepala', 'Bersungguh-sungguh pasti berhasil'][i % 3],
      kesan_pesan: 'Terima kasih kepada para asatidzah yang telah membimbing kami dengan sabar. Semoga pondok terus menjadi cahaya bagi umat.', catatan: null, updated_at: new Date().toISOString() } : null
    return { id: s.id, nis: s.nis, nisn: s.nisn, nama: s.nama_lengkap, jenis_kelamin: s.jenis_kelamin, jenjang: s.jenjang, tingkat: s.tingkat, tempat_lahir: s.tempat_lahir,
      tanggal_lahir: s.tanggal_lahir, tanggal_masuk: s.tanggal_masuk, status_sejak: '2026-06-20', foto_id: s.foto_id || null, alamat: s.alamat, kota_kab: s.kota_kab,
      tahun_lulus: 2026, kelas: (s.kelompok || []).find((g) => g.jenis === 'kelas')?.nama || `${s.tingkat}`, halaqah: (s.kelompok || []).find((g) => g.jenis === 'halaqah')?.nama || null,
      total_juz: sma ? 10 + (i % 21) : 3 + (i % 8), ayah: s.kontak?.find((c) => c.hubungan === 'ayah')?.nama || null, ibu: s.kontak?.find((c) => c.hubungan === 'ibu')?.nama || null,
      prestasi: i % 3, alumni: al }
  })
  return DEMO
}
function profilDemo(id) {
  const a = demo().daftar.find((x) => x.id === id); if (!a) throw new Error('Santri tidak ditemukan.')
  const s = useSantri().cari(id) || {}; const lama = a.jenjang === 'sma' ? 3 : 3; const akhir = Number(a.tingkat)
  const riwayat = []
  for (let n = lama - 1; n >= 0; n--) {
    const th = 2025 - n; const ta = `${th}/${th + 1}`; const tk = akhir - n
    riwayat.push({ ta, ta_mulai: `${th}-07-14`, jenis: 'kelas', nama: `${tk}${a.jenis_kelamin === 'L' ? 'A' : 'B'}`, mulai: `${th}-07-14`, selesai: `${th + 1}-06-30`, pengasuh: ['Ust. Ahmad Syafii, S.Pd.', 'Ust. Muhammad Ridwan, Lc.', 'Usth. Nurul Hikmah, S.Pd.'][n % 3] })
    riwayat.push({ ta, ta_mulai: `${th}-07-14`, jenis: 'halaqah', nama: `Halaqah ${['Abu Bakar', 'Umar', 'Utsman'][n % 3]}`, mulai: `${th}-07-14`, selesai: `${th + 1}-06-30`, pengasuh: 'Ust. Hasan Basri, Lc.' })
    riwayat.push({ ta, ta_mulai: `${th}-07-14`, jenis: 'kamar', nama: `Kamar ${['Al-Fatih', 'Shalahuddin', 'Thariq'][n % 3]}`, mulai: `${th}-07-14`, selesai: `${th + 1}-06-30`, pengasuh: 'Ust. Abdul Hafidz' })
  }
  const juz = Array.from({ length: a.total_juz }, (_, i) => 30 - i)
  return { santri: { ...s, id }, tahun_lulus: a.tahun_lulus, kontak: (s.kontak || []).map((k) => ({ hubungan: k.hubungan, nama: k.nama, no_hp: k.no_hp, pekerjaan: k.pekerjaan })), riwayat,
    hafalan: { total_juz: a.total_juz, juz: juz.sort((x, y) => x - y), terakhir: '2026-05-20' },
    sertifikat: a.total_juz >= 5 ? [{ jenis: 'sertifikat_hafalan', nomor: `012/SH/TFZ/V/2026`, tanggal: '2026-05-25', predikat: 'Mumtaz', jenjang_juz: String(Math.floor(a.total_juz / 5) * 5), total_juz: String(a.total_juz) }] : [],
    prestasi: a.prestasi ? [{ tanggal: '2025-11-12', bidang: 'tahfizh', tingkat: 'kabupaten', kegiatan: 'MTQ Cabang Tahfizh 5 Juz', capaian: 'Juara 1', penyelenggara: 'LPTQ Kabupaten Gowa' }] : [],
    alumni: a.alumni }
}

export const useAlumni = defineStore('alumni', {
  state: () => ({ daftar: [], memuat: false, dimuat: false }),
  actions: {
    async muat(paksa = false) {
      if (this.dimuat && !paksa) return this.daftar
      this.memuat = true
      try {
        if (MODE_DEMO) { await useSantri().muat(); this.daftar = demo().daftar.map((x) => ({ ...x, alumni: x.alumni ? { ...x.alumni } : null })) }
        else this.daftar = (await rpc('daftar_alumni', { p_tahun: null })) || []
        this.dimuat = true; return this.daftar
      } finally { this.memuat = false }
    },
    async profil(id) {
      if (MODE_DEMO) { await useSantri().muat(); return profilDemo(id) }
      return await rpc('profil_alumni', { p_student: id })
    },
    async simpan(id, isi) {
      if (MODE_DEMO) {
        const a = demo().daftar.find((x) => x.id === id); a.alumni = { ...(a.alumni || {}), ...isi, updated_at: new Date().toISOString() }
        if (isi.tahun_lulus) a.tahun_lulus = Number(isi.tahun_lulus)
      } else await rpc('simpan_alumni', { p_student: id, p: isi })
      await this.muat(true)
    },
    /** Profil lengkap banyak alumni sekaligus (buku alumni), dimuat bertahap. */
    async profilBanyak(ids, kemajuan) {
      const hasil = []
      for (let i = 0; i < ids.length; i += 6) {
        hasil.push(...(await Promise.all(ids.slice(i, i + 6).map((id) => this.profil(id)))))
        kemajuan?.(Math.min(ids.length, i + 6), ids.length)
      }
      return hasil
    },
    // ---------- Arsip tahun ajaran ----------
    async daftarTA() {
      const kel = useKelompokSantri()
      if (!kel.tahunAjaran.length) await kel.muat()
      const ta = [...kel.tahunAjaran]
      if (MODE_DEMO && ta.length < 2) ta.push({ id: 'ta0', nama: '2025/2026', mulai: '2025-07-14', selesai: '2026-06-30', aktif: false, terkunci: true })
      return ta.sort((a, b) => String(b.mulai).localeCompare(String(a.mulai)))
    },
    async arsip(taId) {
      if (MODE_DEMO) {
        const kel = useKelompokSantri(); if (!kel.daftar.length) await kel.muat(); const san = useSantri(); await san.muat()
        const ta = (await this.daftarTA()).find((t) => t.id === taId)
        const grup = kel.daftar.filter((g) => ['kelas', 'halaqah', 'kamar', 'ekskul'].includes(g.jenis))
        const urut = ['kelas', 'halaqah', 'kamar', 'ekskul']
        const kelompok = grup.map((g) => { const ang = san.daftar.filter((s) => (s.kelompok || []).some((k) => k.id === g.id))
          return { id: g.id, jenis: g.jenis, nama: g.nama, jenjang: g.jenjang, tingkat: g.tingkat, jk: g.jenis_kelamin, pengasuh: (g.pengasuh || []).filter((p) => p.peran === 'utama').map((p) => p.nama).join(', '),
            l: ang.filter((s) => s.jenis_kelamin === 'L').length, p: ang.filter((s) => s.jenis_kelamin === 'P').length } })
          .sort((a, b) => urut.indexOf(a.jenis) - urut.indexOf(b.jenis) || String(a.jenjang).localeCompare(String(b.jenjang)) || (a.tingkat || 0) - (b.tingkat || 0) || a.nama.localeCompare(b.nama))
        const g = (s, j) => (s.kelompok || []).find((k) => k.jenis === j)
        const santri = san.daftar.filter((s) => (s.kelompok || []).length).map((s) => ({ id: s.id, nis: s.nis, nama: s.nama_lengkap, jenis_kelamin: s.jenis_kelamin, jenjang: s.jenjang,
          status: taId === 'ta0' && [9, 12].includes(Number(s.tingkat)) ? 'lulus' : s.status, kelas: g(s, 'kelas')?.nama || null, kelas_id: g(s, 'kelas')?.id || null,
          halaqah: g(s, 'halaqah')?.nama || null, kamar: g(s, 'kamar')?.nama || null })).sort((a, b) => String(a.kelas).localeCompare(String(b.kelas)) || a.nama.localeCompare(b.nama))
        return { ta, kelompok, santri }
      }
      return await rpc('arsip_tahun_ajaran', { p_ta: taId })
    },
  },
})
