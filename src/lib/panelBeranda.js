// SIMKA PRO | src/lib/panelBeranda.js | v1.0 | Fase 8 – Perbaikan beranda pimpinan: statistik bergeser per kelompok | 10/10/2026
// Daftar kelompok statistik beranda (urutan, nama chip, ikon, warna) untuk komponen SliderStatistik.
import { PhFingerprint, PhClipboardText, PhUsersThree, PhStudent, PhBookOpenText, PhFirstAidKit, PhShieldCheck, PhBuildings, PhSparkle, PhUserGear } from '@phosphor-icons/vue'
const P = {
  presensi: { n: 'Presensi', ikon: PhFingerprint, w: 'presensi' },
  pimpinan: { n: 'Unit saya', ikon: PhUsersThree, w: 'pegawai' },
  kelola: { n: 'Administrasi', ikon: PhClipboardText, w: 'tatausaha' },
  santri: { n: 'Santri', ikon: PhStudent, w: 'santri' },
  tahfizh: { n: 'Tahfizh', ikon: PhBookOpenText, w: 'tahfizh' },
  layanan: { n: 'Layanan santri', ikon: PhFirstAidKit, w: 'klinik' },
  security: { n: 'Security', ikon: PhShieldCheck, w: 'security' },
  pondok: { n: 'Pondok', ikon: PhBuildings, w: 'beranda' },
  kendali: { n: 'Data pegawai', ikon: PhUserGear, w: 'verifikasi' },
  pribadi: { n: 'Untuk Anda', ikon: PhSparkle, w: 'agenda' },
}
export const panelBeranda = (kode) => kode.filter((k) => P[k]).map((k) => ({ k, ...P[k] }))
