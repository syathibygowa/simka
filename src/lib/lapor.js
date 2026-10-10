// SIMKA PRO | src/lib/lapor.js | v1.1 | Fase 8 – Perbaikan: nama menu ringkas | 10/10/2026
// Label baku Laporan Terkait (Blueprint Bagian 30).
import { PhGavel, PhFirstAidKit, PhShieldCheck, PhWrench, PhBookOpenText, PhDotsThreeCircle, PhPaperPlaneTilt, PhCheck, PhArrowsClockwise, PhCheckCircle } from '@phosphor-icons/vue'

export const IKON_KATEGORI = {
  pelanggaran: { ikon: PhGavel, w: 'laporan' }, kesehatan: { ikon: PhFirstAidKit, w: 'klinik' }, keamanan: { ikon: PhShieldCheck, w: 'security' },
  sarana: { ikon: PhWrench, w: 'shift' }, akademik: { ikon: PhBookOpenText, w: 'tahfizh' }, lainnya: { ikon: PhDotsThreeCircle, w: 'hakakses' },
}
export const gayaKategori = (k) => IKON_KATEGORI[k] || IKON_KATEGORI.lainnya
export const STATUS_LAPOR = {
  terkirim: { n: 'Terkirim', w: 'pengajuan', ikon: PhPaperPlaneTilt },
  diterima: { n: 'Diterima', w: 'agenda', ikon: PhCheck },
  ditindaklanjuti: { n: 'Ditindaklanjuti', w: 'shift', ikon: PhArrowsClockwise },
  selesai: { n: 'Selesai', w: 'presensi', ikon: PhCheckCircle },
}
export const URUT_STATUS_LAPOR = ['terkirim', 'diterima', 'ditindaklanjuti', 'selesai']
/** Unit penerima yang dapat dipilih pelapor bila kategori tidak menentukan (Akademik/Lainnya). */
export const UNIT_PILIHAN = [
  { kode: 'KESANTRIAN', n: 'Bidang Kesantrian' }, { kode: 'TAHFIZH', n: 'Bidang Tahfizh' }, { kode: 'WUSTHA', n: 'Bidang Kesetaraan Wustha' },
  { kode: 'SMA', n: 'Bidang SMA' }, { kode: 'SARANA', n: 'Bidang Sarana' }, { kode: 'BAHASA', n: 'Bidang Bahasa' }, { kode: 'MEDIA', n: 'Bidang Media' },
  { kode: 'UMUM', n: 'Bidang Umum' }, { kode: 'SECURITY', n: 'Unit Security' }, { kode: 'KLINIK', n: 'Unit Klinik' }, { kode: 'DAPUR', n: 'Unit Dapur' },
  { kode: 'TU', n: 'Unit Tata Usaha' }, { kode: 'PIMPINAN', n: 'Pimpinan Pondok' },
]
