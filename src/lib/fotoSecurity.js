// SIMKA PRO | src/lib/fotoSecurity.js | v1.0 | Fase 7 – Tahap 2 Titipan, buku tamu, kunjungan | 06/10/2026
// Unggah foto Security ke Google Drive (lewat antrian): maks 720 px, simpan 6 bulan (Blueprint Bagian 39).
//   Titipan → SIMKA PRO/Security/Titipan/yyyy/mm · Gerbang, tamu, kunjungan → SIMKA PRO/Security/Gerbang/yyyy/mm
import { MODE_DEMO } from './supabase'
import { unggahKeDrive, kompresGambar, namaRapi } from './penyimpanan'
import { hariIniISO } from './tanggal'

export async function unggahFotoSecurity(file, { nama, nis = '', jenis, folder = 'Gerbang' }) {
  if (!file || MODE_DEMO) return null
  const blob = await kompresGambar(file, { maks: 720, kualitas: 0.6 }); const t = hariIniISO()
  return unggahKeDrive(blob, { nama: namaRapi(nama, nis, jenis, t.replaceAll('-', ''), Date.now() % 1000) + '.jpg',
    kategori: folder === 'Titipan' ? 'foto_titipan' : 'foto_gerbang', folder: `SIMKA PRO/Security/${folder}/${t.slice(0, 4)}/${t.slice(5, 7)}`, retensiHari: 183 })
}
