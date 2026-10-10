// SIMKA PRO | src/lib/tahfizh.js | v1.4 | Fase 8 – Perbaikan: nama menu ringkas | 10/10/2026
// Konversi posisi hafalan (Juz + Halaman ↔ total halaman), rentang juz, label program, dan penanda tangan tahfizh.
// Posisi disimpan di server sebagai TOTAL HALAMAN: 20 halaman = 1 juz (10 juz 2 halaman = 202).
import { supabase, MODE_DEMO } from './supabase'

export const HAL_PER_JUZ = 20
export const MAKS_HAL = 30 * HAL_PER_JUZ
export const PROGRAM = { reguler: 'Reguler', takhassus: 'Takhassus' }
export const JENIS_POSISI = { sabaq: 'Sabaq', sabqi: 'Sabqi', manzil: 'Manzil' }
export const KET_POSISI = {
  sabaq: 'Hafalan baru (jumlah hafalan berjalan); dipakai menghitung penambahan dan target.',
  sabqi: "Muraja'ah hafalan yang baru disetor (posisi yang sedang diulang).",
  manzil: "Muraja'ah hafalan lama (posisi yang sedang diulang).",
}
export const SUMBER_JUZ = { awal: 'Data awal', ujian: 'Ujian kenaikan juz', sertifikasi: 'Sertifikasi', validasi: 'Usulan disetujui' }
export const JENIS_PENGUJI = { kenaikan: 'Ujian kenaikan juz', sertifikasi: 'Sertifikasi hafalan' }

/** Total halaman → { juz, hal } */
export const dariHal = (h) => { const n = Math.max(0, Number(h) || 0); return { juz: Math.floor(n / HAL_PER_JUZ), hal: n % HAL_PER_JUZ } }
/** Juz + halaman → total halaman (halaman ≥ 20 otomatis menjadi juz). */
export const keHal = (juz, hal) => Math.min(MAKS_HAL, Math.max(0, (Number(juz) || 0) * HAL_PER_JUZ + (Number(hal) || 0)))
/** "10 juz 2 hal" (bentuk singkat) atau "10 juz 2 halaman" (lengkap, untuk cetak). */
export function formatPosisi(h, lengkap = false) {
  const { juz, hal } = dariHal(h)
  const kh = lengkap ? 'halaman' : 'hal'
  if (!juz && !hal) return '0'
  if (!hal) return `${juz} juz`
  if (!juz) return `${hal} ${kh}`
  return `${juz} juz ${hal} ${kh}`
}
/** Halaman → teks juz desimal untuk ringkasan, mis. 205 → "10,25 juz" */
export const juzDesimal = (h) => `${(Math.round(((Number(h) || 0) / HAL_PER_JUZ) * 100) / 100).toLocaleString('id-ID')} juz`

/** "1-5, 30; 28" → [1,2,3,4,5,28,30]. Mengembalikan { juz, galat }. */
export function uraiJuz(teks) {
  const juz = new Set(); const galat = []
  String(teks ?? '').split(/[,;\s]+/).map((x) => x.trim()).filter(Boolean).forEach((b) => {
    const m = b.match(/^(\d{1,2})(?:\s*[-–sd.]+\s*(\d{1,2}))?$/i)
    if (!m) { galat.push(`"${b}" bukan nomor juz`); return }
    let a = Number(m[1]); let z = Number(m[2] ?? m[1]); if (a > z) [a, z] = [z, a]
    if (a < 1 || z > 30) { galat.push(`"${b}" di luar juz 1–30`); return }
    for (let i = a; i <= z; i++) juz.add(i)
  })
  return { juz: [...juz].sort((x, y) => x - y), galat }
}
/** [1,2,3,5,30] → "1–3, 5, 30" */
export function ringkasJuz(daftar) {
  const a = [...new Set((daftar || []).map(Number))].sort((x, y) => x - y)
  const hasil = []
  for (let i = 0; i < a.length; i++) {
    let j = i; while (j + 1 < a.length && a[j + 1] === a[j] + 1) j++
    hasil.push(j > i ? `${a[i]}–${a[j]}` : String(a[i])); i = j
  }
  return hasil.join(', ')
}

/** Kategori juz untuk grafik dan saringan (sesuai contoh pondok; batas bawah ikut kategori atasnya). */
export function kategoriJuz(total, terdata = true) {
  if (!terdata) return 'Tidak terdata'
  if (total >= 30) return 'Khatam 30 juz'
  if (total >= 25) return 'Di atas 25 juz'
  if (total >= 20) return 'Di atas 20 juz'
  if (total >= 15) return 'Di atas 15 juz'
  if (total >= 10) return 'Di atas 10 juz'
  if (total >= 5) return 'Di atas 5 juz'
  return 'Di bawah 5 juz'
}

/** Predikat untuk sebuah nilai menurut rentang pengaturan. */
export const predikatDari = (nilai, rentang = []) => rentang.find((r) => Number(nilai) >= Number(r.nilai_min) && Number(nilai) <= Number(r.nilai_maks)) || null

/** Penanda tangan dokumen tahfizh: Kepala Bidang Tahfizh dari Setelan → Penanda tangan (bila belum ada, nama dikosongkan). */
export async function penandaTahfizh() {
  if (MODE_DEMO) return { jabatan: 'Kepala Bidang Tahfizh', nama: 'Ust. Abdurrahman Saleh, Lc.', niy: '1985061201201201' }
  const { data } = await supabase.from('signatories').select('jabatan_tertulis, nama, niy').eq('aktif', true)
    .ilike('jabatan_tertulis', 'Kepala%Tahfi%').order('urutan').limit(1).maybeSingle()
  return data ? { jabatan: data.jabatan_tertulis, nama: data.nama, niy: data.niy } : { jabatan: 'Kepala Bidang Tahfizh', nama: '', niy: '' }
}

/** Nama bulan dan tahun dari tanggal "yyyy-mm-01". */
export const labelBulan = (iso) => {
  const [y, m] = String(iso).split('-').map(Number)
  return `${['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'][m - 1]} ${y}`
}

/** Tanda isian setoran janggal (dihitung server). */
export const TANDA_JANGGAL = {
  turun: 'Posisi sabaq turun dari sebelumnya',
  lonjakan: 'Penambahan melebihi batas per sesi',
  melebihi_sabaq: 'Sabqi/manzil melebihi posisi sabaq',
}
/** Periksa satu isian di perangkat (sama dengan aturan server) untuk peringatan langsung. */
export function periksaIsian({ sabaq_lama, sabqi_lama, manzil_lama, sabaq_hal, sabqi_hal, manzil_hal }, batas = 10) {
  const t = []; const sb = sabaq_hal ?? sabaq_lama
  if (sabaq_hal != null && sabaq_hal < sabaq_lama) t.push('turun')
  if (sabaq_hal != null && sabaq_hal - sabaq_lama > batas) t.push('lonjakan')
  if ((sabqi_hal ?? sabqi_lama) > sb || (manzil_hal ?? manzil_lama) > sb) t.push('melebihi_sabaq')
  return t
}
/** Status sesi setoran untuk kartu daftar. */
export const STATUS_SETORAN = {
  terisi: { n: 'Terisi', w: 'presensi' }, terbuka: { n: 'Belum diisi', w: 'pengajuan' }, lewat: { n: 'Lewat jendela', w: 'laporan' },
  belum_buka: { n: 'Belum dibuka', w: 'hakakses' }, tidak_terisi: { n: 'Tidak diisi', w: 'klinik' },
}

/** Status capaian bulanan (urutan tampilan, label, warna). */
export const STATUS_BULANAN = {
  tercapai: { n: 'Tercapai', w: 'presensi' }, tidak_tercapai: { n: 'Tidak tercapai', w: 'klinik' }, murojaah: { n: 'Murojaah', w: 'pegawai' },
  khatam: { n: 'Khatam', w: 'tahfizh' }, tidak_terdata: { n: 'Tidak terdata', w: 'hakakses' },
}
export const STATUS_USULAN = { menunggu: { n: 'Menunggu validasi', w: 'pengajuan' }, disetujui: { n: 'Disetujui', w: 'presensi' }, dikembalikan: { n: 'Dikembalikan', w: 'klinik' } }
export const SUMBER_USULAN = { ceklist: 'Ceklist muhaffizh', ujian: 'Ujian kenaikan juz', sertifikasi: 'Sertifikasi' }

/** Ujian kenaikan juz dan sertifikasi. */
export const STATUS_UJIAN = {
  menunggu: { n: 'Menunggu penguji', w: 'pengajuan' }, dijadwalkan: { n: 'Dijadwalkan', w: 'agenda' },
  selesai: { n: 'Selesai', w: 'presensi' }, dibatalkan: { n: 'Dibatalkan', w: 'hakakses' },
}
export const HASIL_UJIAN = { tuntas: { n: 'Tuntas', w: 'presensi' }, remidi: { n: 'Remidi', w: 'klinik' } }
export const JENJANG_SERTIFIKASI = [5, 10, 15, 20, 25, 30]
/** Pratinjau nilai akhir sesuai bobot pengaturan (perhitungan resmi tetap di server). */
export function hitungNilai(tajwid, itqan, pengaturan, rentang = []) {
  if (tajwid === '' || itqan === '' || tajwid == null || itqan == null) return null
  const bt = Number(pengaturan?.bobot_tajwid ?? 50); const bi = Number(pengaturan?.bobot_itqan ?? 50)
  const akhir = Math.round((Number(tajwid) * bt + Number(itqan) * bi)) / 100
  const p = predikatDari(akhir, rentang)
  return { akhir, huruf: p?.huruf || '–', predikat: p?.deskripsi_rapor || '–', hasil: akhir >= Number(pengaturan?.kkm ?? 80) ? 'tuntas' : 'remidi' }
}
