// SIMKA PRO | src/router/index.js | v3.3 | Fase 4 – Tahap 6 Tahun ajaran, statistik, laporan | 05/10/2026
// Router berbasis hash (cocok untuk GitHub Pages). meta.cetak menampilkan tombol cetak
// di bilah atas; meta.peran membatasi halaman untuk peran tertentu.
import { createRouter, createWebHashHistory } from 'vue-router'
import { useSesi } from '@/stores/sesi'
import TataLetakAplikasi from '@/layouts/TataLetakAplikasi.vue'

const ADMIN = ['admin', 'superadmin']
const routes = [
  { path: '/masuk', component: () => import('@/pages/auth/Masuk.vue'), meta: { publik: true, judul: 'Masuk' } },
  { path: '/daftar', component: () => import('@/pages/auth/Daftar.vue'), meta: { publik: true, judul: 'Daftar akun' } },
  { path: '/lupa-sandi', component: () => import('@/pages/auth/LupaSandi.vue'), meta: { publik: true, judul: 'Lupa kata sandi' } },
  { path: '/cek-kartu/:kode?', component: () => import('@/pages/kartu/VerifikasiKartu.vue'), props: true, meta: { publik: true, bebas: true, judul: 'Verifikasi kartu pegawai' } },
  { path: '/atur-sandi', component: () => import('@/pages/auth/AturSandi.vue'), meta: { publik: true, bebas: true, judul: 'Atur kata sandi' } },
  { path: '/ganti-sandi', component: () => import('@/pages/auth/GantiSandi.vue'), meta: { judul: 'Ganti kata sandi' } },
  {
    path: '/', component: TataLetakAplikasi,
    children: [
      { path: '', component: () => import('@/pages/beranda/Beranda.vue'), meta: { judul: 'Beranda' } },
      { path: 'notifikasi', component: () => import('@/pages/notifikasi/Notifikasi.vue'), meta: { judul: 'Notifikasi', kembali: '/' } },
      { path: 'tugas', component: () => import('@/pages/umum/Tugas.vue'), meta: { judul: 'Tugas dan menu' } },
      { path: 'profil', component: () => import('@/pages/profil/Profil.vue'), meta: { judul: 'Profil' } },
      { path: 'pegawai', component: () => import('@/pages/pegawai/DaftarPegawai.vue'), meta: { judul: 'Data Pegawai', peran: ADMIN, cetak: true, kembali: '/tugas' } },
      { path: 'pegawai/baru', component: () => import('@/pages/pegawai/FormPegawai.vue'), meta: { judul: 'Tambah Pegawai', peran: ADMIN, kembali: '/pegawai' } },
      { path: 'pegawai/impor', component: () => import('@/pages/pegawai/ImporPegawai.vue'), meta: { judul: 'Impor Data Pegawai', peran: ADMIN, kembali: '/pegawai' } },
      { path: 'pegawai/rekap', component: () => import('@/pages/pegawai/RekapPegawai.vue'), meta: { judul: 'Rekap Kepegawaian', peran: ADMIN, cetak: true, kembali: '/pegawai' } },
      { path: 'pegawai/:id/ubah', component: () => import('@/pages/pegawai/FormPegawai.vue'), meta: { judul: 'Ubah Data Pegawai', peran: ADMIN, kembali: '/pegawai' } },
      { path: 'pegawai/:id', component: () => import('@/pages/pegawai/DetailPegawai.vue'), meta: { judul: 'Biodata Pegawai', peran: ADMIN, cetak: true, kembali: '/pegawai' } },
      { path: 'santri', component: () => import('@/pages/santri/DaftarSantri.vue'), meta: { judul: 'Data Santri', cetak: true, kembali: '/tugas' } },
      { path: 'santri/baru', component: () => import('@/pages/santri/FormSantri.vue'), meta: { judul: 'Tambah Santri', kembali: '/santri' } },
      { path: 'santri/impor', component: () => import('@/pages/santri/ImporSantri.vue'), meta: { judul: 'Impor Data Santri', peran: ADMIN, kembali: '/santri' } },
      { path: 'santri/:id/ubah', component: () => import('@/pages/santri/FormSantri.vue'), meta: { judul: 'Ubah Data Santri', kembali: '/santri' } },
      { path: 'santri/:id', component: () => import('@/pages/santri/DetailSantri.vue'), meta: { judul: 'Biodata Santri', cetak: true, kembali: '/santri' } },
      { path: 'absensi-santri/isi/:group/:tanggal/:sesi', component: () => import('@/pages/absensisantri/IsiAbsensi.vue'), meta: { judul: 'Isi Absensi Santri', kembali: '/absensi-santri' } },
      { path: 'absensi-santri/:tab?', component: () => import('@/pages/absensisantri/AbsensiSantri.vue'), props: true, meta: { judul: 'Absensi Santri', kembali: '/tugas' } },
      { path: 'statistik-santri', component: () => import('@/pages/santri/StatistikSantri.vue'), meta: { judul: 'Statistik Santri', cetak: true, kembali: '/tugas' } },
      { path: 'tahun-ajaran-baru', component: () => import('@/pages/santri/PergantianTA.vue'), meta: { judul: 'Pergantian Tahun Ajaran', peran: ADMIN, kembali: '/tugas' } },
      { path: 'jadwal-pelajaran/:tab?', component: () => import('@/pages/jadwal/JadwalPelajaran.vue'), props: true, meta: { judul: 'Jadwal Pelajaran', kembali: '/tugas' } },
      { path: 'ekskul/:tab?', component: () => import('@/pages/ekskul/Ekskul.vue'), props: true, meta: { judul: 'Ekskul', kembali: '/tugas' } },
      { path: 'kelompok-santri/impor', component: () => import('@/pages/kelompoksantri/ImporKelompok.vue'), meta: { judul: 'Impor Pembagian Kelompok', kembali: '/kelompok-santri' } },
      { path: 'kelompok-santri/k/:id', component: () => import('@/pages/kelompoksantri/DetailKelompok.vue'), meta: { judul: 'Kelompok Santri', cetak: true, kembali: '/kelompok-santri' } },
      { path: 'kelompok-santri/:tab?', component: () => import('@/pages/kelompoksantri/KelompokSantri.vue'), props: true, meta: { judul: 'Kelompok Santri', kembali: '/tugas' } },
      { path: 'jabatan-tunjangan/:tab?', component: () => import('@/pages/tunjangan/JabatanTunjangan.vue'), props: true, meta: { judul: 'Jabatan dan Tunjangan', peran: ['superadmin'], kembali: '/tugas' } },
      { path: 'presensi', component: () => import('@/pages/presensi/Presensi.vue'), meta: { judul: 'Presensi' } },
      { path: 'atur-presensi/:tab?', component: () => import('@/pages/presensi/AturPresensi.vue'), props: true, meta: { judul: 'Pengaturan Presensi', peran: ADMIN, kembali: '/tugas' } },
      { path: 'verval-presensi/:tab?', component: () => import('@/pages/verval/VervalPresensi.vue'), props: true, meta: { judul: 'Verval Presensi', peran: ADMIN, kembali: '/tugas' } },
      { path: 'rekap-presensi/:tab?', component: () => import('@/pages/rekap/RekapPresensi.vue'), props: true, meta: { judul: 'Rekap Presensi', peran: ADMIN, kembali: '/tugas' } },
      { path: 'jadwal-shift', component: () => import('@/pages/shift/JadwalShift.vue'), meta: { judul: 'Jadwal Shift', kembali: '/tugas' } },
      { path: 'verifikasi/:tab?', component: () => import('@/pages/akun/Verifikasi.vue'), props: true, meta: { judul: 'Verifikasi dan Akun', peran: ADMIN, kembali: '/tugas' } },
      { path: 'organisasi/:tab?', component: () => import('@/pages/organisasi/Organisasi.vue'), props: true, meta: { judul: 'Struktur Organisasi', peran: ['superadmin'], cetak: true, kembali: '/tugas' } },
      { path: 'hak-akses/:tab?', component: () => import('@/pages/hakakses/HakAkses.vue'), props: true, meta: { judul: 'Hak Akses Fitur', peran: ['superadmin'], kembali: '/tugas' } },
      { path: 'pengaturan/:tab?', component: () => import('@/pages/pengaturan/Pengaturan.vue'), props: true, meta: { judul: 'Pengaturan', peran: ['superadmin'], kembali: '/tugas' } },
      { path: 'pengumuman/:id?', component: () => import('@/pages/pengumuman/Pengumuman.vue'), props: true, meta: { judul: 'Pengumuman', kembali: '/' } },
      { path: 'pengajuan/:id?', component: () => import('@/pages/pengajuan/Pengajuan.vue'), props: true, meta: { judul: 'Pengajuan', kembali: '/tugas' } },
      { path: 'jurnal/:tab?', component: () => import('@/pages/jurnal/Jurnal.vue'), props: true, meta: { judul: 'Jurnal Harian', kembali: '/tugas' } },
      { path: 'berkas/:id?', component: () => import('@/pages/berkas/Berkas.vue'), props: true, meta: { judul: 'Berkas Saya', kembali: '/tugas' } },
      { path: 'kartu', component: () => import('@/pages/kartu/Kartu.vue'), meta: { judul: 'Kartu Pegawai', kembali: '/tugas' } },
      { path: 'agenda/:id?', component: () => import('@/pages/agenda/Agenda.vue'), props: true, meta: { judul: 'Agenda', kembali: '/' } },
      { path: 'kelompok-pegawai', component: () => import('@/pages/kelompok/KelompokPegawai.vue'), meta: { judul: 'Kelompok Pegawai', peran: ADMIN, kembali: '/tugas' } },
      { path: 'beban-kerja/:tab?', component: () => import('@/pages/beban/BebanKerja.vue'), props: true, meta: { judul: 'Ekuivalensi Jam Beban Kerja', kembali: '/tugas' } },
      { path: 'audit-log', component: () => import('@/pages/audit/AuditLog.vue'), meta: { judul: 'Audit Log', kembali: '/tugas' } },
      { path: 'segera/:kode', component: () => import('@/pages/umum/Segera.vue'), props: true, meta: { judul: 'Segera hadir', kembali: '/tugas' } },
      { path: ':salah(.*)*', component: () => import('@/pages/umum/TidakDitemukan.vue'), meta: { judul: 'Halaman tidak ditemukan', kembali: '/' } },
    ],
  },
]

const router = createRouter({ history: createWebHashHistory(), routes, scrollBehavior: () => ({ top: 0 }) })

router.beforeEach(async (to) => {
  const sesi = useSesi()
  if (!sesi.siap) await sesi.mulai()
  if (to.meta.publik) return sesi.masuk && !to.meta.bebas ? (to.query.lanjut || '/') : true
  if (!sesi.masuk) return { path: '/masuk', query: to.fullPath !== '/' ? { lanjut: to.fullPath } : {} }
  // Akun dengan sandi sementara wajib mengganti sandi lebih dulu
  if (sesi.wajibGantiSandi && to.path !== '/ganti-sandi') return '/ganti-sandi'
  if (to.meta.peran && !to.meta.peran.includes(sesi.peran)) return '/'
  return true
})
router.afterEach((to) => { document.title = `${to.meta.judul || 'SIMKA PRO'} – SIMKA PRO` })

export default router
