// Router berbasis hash (cocok untuk GitHub Pages). meta.cetak menampilkan tombol cetak
// di bilah atas; meta.peran membatasi halaman untuk peran tertentu.
import { createRouter, createWebHashHistory } from 'vue-router'
import { useSesi } from '@/stores/sesi'
import TataLetakAplikasi from '@/layouts/TataLetakAplikasi.vue'

const ADMIN = ['admin', 'superadmin']
const routes = [
  { path: '/masuk', component: () => import('@/pages/auth/Masuk.vue'), meta: { publik: true, judul: 'Masuk' } },
  {
    path: '/', component: TataLetakAplikasi,
    children: [
      { path: '', component: () => import('@/pages/beranda/Beranda.vue'), meta: { judul: 'Beranda' } },
      { path: 'notifikasi', component: () => import('@/pages/notifikasi/Notifikasi.vue'), meta: { judul: 'Notifikasi', kembali: '/' } },
      { path: 'tugas', component: () => import('@/pages/umum/Tugas.vue'), meta: { judul: 'Tugas dan menu' } },
      { path: 'profil', component: () => import('@/pages/profil/Profil.vue'), meta: { judul: 'Profil' } },
      { path: 'pegawai', component: () => import('@/pages/pegawai/DaftarPegawai.vue'), meta: { judul: 'Data Pegawai', peran: ADMIN, cetak: true, kembali: '/tugas' } },
      { path: 'pegawai/:id', component: () => import('@/pages/pegawai/DetailPegawai.vue'), meta: { judul: 'Biodata Pegawai', peran: ADMIN, cetak: true, kembali: '/pegawai' } },
      { path: 'presensi', component: () => import('@/pages/umum/Segera.vue'), props: { kode: 'presensi' }, meta: { judul: 'Presensi' } },
      { path: 'verifikasi', component: () => import('@/pages/umum/Disiapkan.vue'), props: { kode: 'verifikasi' }, meta: { judul: 'Verifikasi Akun', peran: ADMIN, kembali: '/tugas' } },
      { path: 'organisasi', component: () => import('@/pages/umum/Disiapkan.vue'), props: { kode: 'organisasi' }, meta: { judul: 'Struktur Organisasi', peran: ['superadmin'], kembali: '/tugas' } },
      { path: 'hak-akses', component: () => import('@/pages/umum/Disiapkan.vue'), props: { kode: 'hakakses' }, meta: { judul: 'Hak Akses', peran: ['superadmin'], kembali: '/tugas' } },
      { path: 'pengaturan', component: () => import('@/pages/umum/Disiapkan.vue'), props: { kode: 'pengaturan' }, meta: { judul: 'Pengaturan', peran: ['superadmin'], kembali: '/tugas' } },
      { path: 'segera/:kode', component: () => import('@/pages/umum/Segera.vue'), props: true, meta: { judul: 'Segera hadir', kembali: '/tugas' } },
      { path: ':salah(.*)*', component: () => import('@/pages/umum/TidakDitemukan.vue'), meta: { judul: 'Halaman tidak ditemukan', kembali: '/' } },
    ],
  },
]

const router = createRouter({ history: createWebHashHistory(), routes, scrollBehavior: () => ({ top: 0 }) })

router.beforeEach(async (to) => {
  const sesi = useSesi()
  if (!sesi.siap) await sesi.mulai()
  if (to.meta.publik) return sesi.masuk && to.path === '/masuk' ? (to.query.lanjut || '/') : true
  if (!sesi.masuk) return { path: '/masuk', query: to.fullPath !== '/' ? { lanjut: to.fullPath } : {} }
  if (to.meta.peran && !to.meta.peran.includes(sesi.peran)) return '/'
  return true
})
router.afterEach((to) => { document.title = `${to.meta.judul || 'SIMKA PRO'} – SIMKA PRO` })

export default router
