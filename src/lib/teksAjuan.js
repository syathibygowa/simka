// SIMKA PRO | src/lib/teksAjuan.js | v1.0 | Fase 5 – Perbaikan: pegawai memperbarui data kepegawaiannya | 05/10/2026
// Menampilkan nilai kolom pengajuan perubahan data pegawai secara ramah (label pilihan, tanggal dd mmmm yyyy).
import { PENDIDIKAN, STATUS_KELUARGA, STATUS_PEGAWAI, KATEGORI_HONORER, LEVEL_MUHAFFIZH } from './kepegawaian'
import { formatPanjang } from './tanggal'
const PILIHAN = { pendidikan_terakhir: PENDIDIKAN, status_keluarga: STATUS_KELUARGA, status_kepegawaian: STATUS_PEGAWAI, kategori_honorer: KATEGORI_HONORER,
  level_muhaffizh: LEVEL_MUHAFFIZH, jenis_kelamin: { L: 'Laki-laki', P: 'Perempuan' } }
export function nilaiAjuan(k, v) {
  if (v == null || v === '') return '–'
  if (PILIHAN[k]) return PILIHAN[k][v] || v
  if (k === 'tanggal_lahir' || k === 'tmt_tugas') return formatPanjang(v)
  return String(v)
}
