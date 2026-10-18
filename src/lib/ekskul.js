// SIMKA PRO | src/lib/ekskul.js | v1.1 | 14.4.0: jurnal ekskul + jam latihan, alat, sumber, catatan | 17/10/2026
// Kategori ekskul (kelompok sekaligus saringan) dan isian jurnal pertemuan ekskul (setara jurnal mengajar guru).
import { PhSquaresFour, PhHouseLine, PhTree, PhQuestion } from '@phosphor-icons/vue'

export const KATEGORI_EKSKUL = {
  indoor: { n: 'Indoor', ket: 'Dalam ruangan', ikon: PhHouseLine, w: 'jadwal' },
  outdoor: { n: 'Outdoor', ket: 'Luar ruangan', ikon: PhTree, w: 'presensi' },
}
/** Sub-tab saringan: Semua · Indoor · Outdoor */
export const TAB_KATEGORI = [
  { k: '', n: 'Semua ekskul', ikon: PhSquaresFour, w: 'ekskul' },
  { k: 'indoor', n: 'Indoor', ikon: PhHouseLine, w: 'jadwal' },
  { k: 'outdoor', n: 'Outdoor', ikon: PhTree, w: 'presensi' },
]
export const BELUM_KATEGORI = { n: 'Belum dikategorikan', ikon: PhQuestion, w: 'hakakses' }
/** Cocok dengan saringan kategori ('' = semua). */
export const cocokKategori = (g, k) => !k || g?.kategori_ekskul === k

/** Metode dan media latihan bawaan (dapat ditambah pembina saat mengisi) */
export const METODE_EKSKUL = ['Demonstrasi', 'Latihan terbimbing', 'Latihan mandiri', 'Praktik berkelompok', 'Permainan', 'Simulasi/pertandingan', 'Ceramah singkat', 'Evaluasi/uji keterampilan']
export const MEDIA_EKSKUL = ['Alat latihan', 'Lapangan/arena', 'Ruang kelas', 'Video', 'Lembar latihan', 'Peralatan lomba']
/** Isian kosong jurnal rinci */
export const JURNAL_KOSONG = () => ({ materi: '', submateri: '', kegiatan: '', metode: [], media: [], capaian: '', kendala: '', tindak_lanjut: '',
  jam_mulai: '', jam_selesai: '', alat: [], sumber: [], catatan: '' })
export const ALAT_EKSKUL = ['Bola', 'Matras', 'Kostum/seragam', 'Alat musik', 'Laptop', 'Pengeras suara', 'Alat tulis', 'Perlengkapan lapangan']
export const SUMBER_EKSKUL = ['Modul pelatih', 'Buku panduan', 'Video tutorial', 'Pelatih tamu', 'Internet/artikel']
/** Pesan kekurangan isian wajib ('' = lengkap) */
export function kurangJurnal(j) {
  if ((j.materi || '').trim().length < 3) return 'Isi materi pokok pertemuan (minimal 3 huruf).'
  if ((j.submateri || '').trim().length < 3) return 'Isi sub-materi/pembahasan pertemuan.'
  if ((j.kegiatan || '').trim().length < 10) return 'Uraikan kegiatan latihan (minimal 10 huruf).'
  if (!(j.metode || []).length) return 'Pilih minimal satu metode latihan.'
  if ((j.capaian || '').trim().length < 3) return 'Isi capaian/hasil latihan santri.'
  if ((j.jam_mulai || j.jam_selesai) && !(j.jam_mulai && j.jam_selesai && j.jam_selesai > j.jam_mulai)) return 'Isi jam mulai dan jam selesai latihan (jam selesai setelah jam mulai).'
  return ''
}
