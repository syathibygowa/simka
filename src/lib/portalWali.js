// SIMKA PRO | src/lib/portalWali.js | v1.0 | Fase 9 – Tahap 13.0.0 Fondasi Portal Wali | 15/10/2026
// Daftar butir informasi Portal Wali (dinyalakan/dimatikan superadmin), label hubungan, dan penyimpanan sesi di perangkat.
// Server (portal_data) hanya mengirim butir yang dinyalakan; daftar ini untuk tampilan pengaturan dan menu portal.
import {
  PhIdentificationCard, PhUsersThree, PhCalendarCheck, PhDoorOpen, PhHandshake, PhPackage, PhFirstAidKit,
  PhBookOpenText, PhExam, PhChartBar, PhTrophy, PhFileText, PhWallet, PhMegaphone,
} from '@phosphor-icons/vue'

/** Butir informasi. sensitif: bawaan nonaktif dan diberi tanda. tahap: versi yang menampilkannya di portal. */
export const BUTIR_PORTAL = [
  { k: 'profil', n: 'Profil anak', ket: 'Kelas, kamar, halaqah, ekskul, tempat dan tanggal lahir', ikon: PhIdentificationCard, w: 'santri', tahap: '13.0' },
  { k: 'pengasuh', n: 'Nama pengasuh', ket: 'Nama wali kelas, musyrif, muhaffizh, dan pembina (tanpa nomor HP)', ikon: PhUsersThree, w: 'walikelas', tahap: '13.0' },
  { k: 'kehadiran', n: 'Kehadiran', ket: 'Absensi kelas, halaqah, asrama, dan ekskul (HISBAT) beserta persentase', ikon: PhCalendarCheck, w: 'presensi', tahap: '13.0' },
  { k: 'perizinan', n: 'Perizinan dan libur', ket: 'Izin keluar (tanpa jejak persetujuan internal), keluar/kembali di gerbang, libur santri', ikon: PhDoorOpen, w: 'pengajuan', tahap: '13.1' },
  { k: 'kunjungan', n: 'Kunjungan', ket: 'Kunjungan orang tua/wali yang tercatat Security', ikon: PhHandshake, w: 'security', tahap: '13.1' },
  { k: 'titipan', n: 'Titipan', ket: 'Titipan untuk anak: diterima dan diambil (tanpa foto)', ikon: PhPackage, w: 'tugas', tahap: '13.1' },
  { k: 'sakit', n: 'Riwayat sakit', ket: 'Tanggal, keluhan umum, dan status penanganan Klinik (tanpa diagnosis dan catatan pemeriksaan)', ikon: PhFirstAidKit, w: 'klinik', tahap: '13.1', sensitif: true },
  { k: 'hafalan', n: 'Hafalan', ket: 'Total juz resmi, posisi sabaq/sabqi/manzil, riwayat setoran, capaian bulanan yang disahkan', ikon: PhBookOpenText, w: 'tahfizh', tahap: '13.2' },
  { k: 'ujian', n: 'Ujian tahfizh', ket: 'Ujian kenaikan juz, sertifikasi, dan UTAS', ikon: PhExam, w: 'rapor', tahap: '13.2' },
  { k: 'nilai', n: 'Nilai rapor', ket: 'Nilai per mapel, predikat, dan catatan wali kelas setelah periode penilaian ditutup', ikon: PhChartBar, w: 'penilaian', tahap: '13.2' },
  { k: 'prestasi', n: 'Prestasi', ket: 'Prestasi santri yang tercatat', ikon: PhTrophy, w: 'prestasi', tahap: '13.2' },
  { k: 'keuangan', n: 'Keuangan', ket: 'Tagihan, pembayaran, dan tunggakan santri', ikon: PhWallet, w: 'keuangan', tahap: '13.2', sensitif: true },
  { k: 'pengumuman', n: 'Pengumuman untuk wali', ket: 'Pengumuman yang ditujukan kepada wali santri', ikon: PhMegaphone, w: 'pengumuman', tahap: '13.3' },
  { k: 'dokumen', n: 'Dokumen santri', ket: 'Unduh SKL, SKBB, Surat Keterangan Aktif, dan sertifikat tahfizh yang sudah sah', ikon: PhFileText, w: 'laporan', tahap: '13.4' },
]

/** Butir yang tampil di portal pada versi aplikasi tertentu (butir dengan tahap lebih baru ditandai "Menyusul"). */
export const sudahTersedia = (b, versi) => {
  const [a1, a2] = String(versi).split('.').map(Number); const [b1, b2] = String(b.tahap).split('.').map(Number)
  return a1 > b1 || (a1 === b1 && a2 >= b2)
}

export const HUBUNGAN_WALI = { ayah: 'Ayah', ibu: 'Ibu', wali: 'Wali' }

export const PENGATURAN_BAWAAN = {
  aktif: false, identitas: 'nis_nisn', lama_sesi_hari: 30, maks_salah: 5, kunci_menit: 15,
  pesan_tutup: 'Portal Wali belum dibuka. Silakan hubungi pengasuh atau Tata Usaha pondok.',
  butir: Object.fromEntries(BUTIR_PORTAL.map((b) => [b.k, !b.sensitif])),
}

// ---------- Sesi di perangkat ----------
// Disimpan: [{ token, nis, nama, panggilan, jk, kelas, hubungan, kedaluwarsa }] dan nis anak yang sedang dibuka.
// Token hanya berlaku di portal wali (bukan akun pegawai) dan dapat dicabut pengelola kapan saja.
const KUNCI_ANAK = 'simka.wali.anak'
const KUNCI_AKTIF = 'simka.wali.aktif'

export function bacaAnak() {
  try {
    const d = JSON.parse(localStorage.getItem(KUNCI_ANAK) || '[]')
    return Array.isArray(d) ? d.filter((a) => a && a.token && (!a.kedaluwarsa || new Date(a.kedaluwarsa) > new Date())) : []
  } catch { return [] }
}
export function simpanAnak(daftar) {
  try { localStorage.setItem(KUNCI_ANAK, JSON.stringify(daftar)) } catch { /* penyimpanan tidak tersedia */ }
}
export function bacaAktif() { try { return localStorage.getItem(KUNCI_AKTIF) || '' } catch { return '' } }
export function simpanAktif(nis) { try { nis ? localStorage.setItem(KUNCI_AKTIF, nis) : localStorage.removeItem(KUNCI_AKTIF) } catch { /* abaikan */ } }
/** Ada sesi wali tersimpan di perangkat ini (dipakai router: buka portal bila tidak ada akun pegawai). */
export const adaSesiWali = () => bacaAnak().length > 0

/** Nama perangkat ringkas untuk daftar sesi pengelola, mis. "Android · Chrome". */
export function namaPerangkat() {
  const u = navigator.userAgent || ''
  const os = /Android/i.test(u) ? 'Android' : /iPhone|iPad/i.test(u) ? 'iPhone/iPad' : /Windows/i.test(u) ? 'Windows' : /Mac OS/i.test(u) ? 'Mac' : /Linux/i.test(u) ? 'Linux' : 'Perangkat lain'
  const br = /Edg\//.test(u) ? 'Edge' : /SamsungBrowser/i.test(u) ? 'Samsung Internet' : /Chrome\//.test(u) ? 'Chrome' : /Firefox\//.test(u) ? 'Firefox' : /Safari\//.test(u) ? 'Safari' : 'Peramban'
  return `${os} · ${br}`
}

/** Sapaan untuk wali sesuai hubungan dan jenis kelamin anak. */
export function sapaanAnak(a) {
  const nama = a?.panggilan || (a?.nama || '').split(' ')[0] || 'Ananda'
  return `Ananda ${nama}`
}
