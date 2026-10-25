// SIMKA PRO | src/router/index.js | v3.36 | 14.24.0: menu Pelaporan; Dokumen resmi di Persuratan; Ambang batas di Pelaporan | 25/10/2026
// Router berbasis hash (cocok untuk GitHub Pages). meta.cetak menampilkan tombol cetak
// di bilah atas; meta.peran membatasi halaman untuk peran tertentu; meta.menu/meta.izin/meta.boleh mengikuti Hak Akses.
import { createRouter, createWebHashHistory } from 'vue-router'
import { useSesi } from '@/stores/sesi'
import TataLetakAplikasi from '@/layouts/TataLetakAplikasi.vue'
import { adaSesiWali } from '@/lib/portalWali'
import { menuTerlihat, cariMenu } from '@/lib/menu'

const routes = [
  { path: '/masuk', component: () => import('@/pages/auth/Masuk.vue'), meta: { publik: true, judul: 'Masuk' } },
  { path: '/daftar', component: () => import('@/pages/auth/Daftar.vue'), meta: { publik: true, judul: 'Daftar akun' } },
  { path: '/lupa-sandi', component: () => import('@/pages/auth/LupaSandi.vue'), meta: { publik: true, judul: 'Lupa kata sandi' } },
  { path: '/cek-kartu/:kode?', component: () => import('@/pages/kartu/VerifikasiKartu.vue'), props: true, meta: { publik: true, bebas: true, judul: 'Verifikasi kartu pegawai' } },
  { path: '/atur-sandi', component: () => import('@/pages/auth/AturSandi.vue'), meta: { publik: true, bebas: true, judul: 'Atur kata sandi' } },
  { path: '/wali/:bagian?', component: () => import('@/pages/wali/PortalWali.vue'), props: true, meta: { publik: true, bebas: true, judul: 'Portal Wali' } },
  { path: '/cek/:kode?', component: () => import('@/pages/cek/CekDokumen.vue'), props: true, meta: { publik: true, bebas: true, judul: 'Cek Keabsahan Dokumen' } },
  { path: '/pantauan', component: () => import('@/pages/pantauan/Pantauan.vue'), meta: { judul: 'Layar Pantauan', boleh: (s) => s.isAdmin || s.tingkat('pantauan') >= 1 } },
  { path: '/ganti-sandi', component: () => import('@/pages/auth/GantiSandi.vue'), meta: { judul: 'Ganti kata sandi' } },
  {
    path: '/', component: TataLetakAplikasi,
    children: [
      { path: '', component: () => import('@/pages/beranda/Beranda.vue'), meta: { judul: 'Beranda' } },
      { path: 'notifikasi', component: () => import('@/pages/notifikasi/Notifikasi.vue'), meta: { judul: 'Notifikasi', kembali: '/' } },
      { path: 'tugas', component: () => import('@/pages/umum/Tugas.vue'), meta: { judul: 'Tugas dan menu' } },
      { path: 'profil', component: () => import('@/pages/profil/Profil.vue'), meta: { judul: 'Profil' } },
      { path: 'profil/data', component: () => import('@/pages/profil/DataSaya.vue'), meta: { judul: 'Data Kepegawaian Saya', kembali: '/profil' } },
      { path: 'profil/rekam', component: () => import('@/pages/pegawai/RekamPegawai.vue'), meta: { judul: 'Rekam Kepegawaian Saya', kembali: '/profil' } },
      { path: 'profil/teguran', component: () => import('@/pages/profil/TeguranSaya.vue'), meta: { judul: 'Surat Teguran Saya', cetak: false, kembali: '/profil' } },
      { path: 'pegawai', component: () => import('@/pages/pegawai/DaftarPegawai.vue'), meta: { judul: 'Data Pegawai', menu: 'pegawai', cetak: true, kembali: '/tugas' } },
      { path: 'pegawai/baru', component: () => import('@/pages/pegawai/FormPegawai.vue'), meta: { judul: 'Tambah Pegawai', menu: 'pegawai', izin: 'kelola_pegawai', kembali: '/pegawai' } },
      { path: 'pegawai/impor', component: () => import('@/pages/pegawai/ImporPegawai.vue'), meta: { judul: 'Impor Data Pegawai', menu: 'pegawai', izin: 'kelola_pegawai', kembali: '/pegawai' } },
      { path: 'pegawai/rekap', component: () => import('@/pages/pegawai/RekapPegawai.vue'), meta: { judul: 'Rekap Kepegawaian', menu: 'pegawai', cetak: true, kembali: '/pegawai' } },
      { path: 'pegawai/:id/rekam', component: () => import('@/pages/pegawai/RekamPegawai.vue'), meta: { judul: 'Rekam Kepegawaian', kembali: '/pegawai' } },
      { path: 'pegawai/:id/ubah', component: () => import('@/pages/pegawai/FormPegawai.vue'), meta: { judul: 'Ubah Data Pegawai', menu: 'pegawai', izin: 'kelola_pegawai', kembali: '/pegawai' } },
      { path: 'pegawai/:id', component: () => import('@/pages/pegawai/DetailPegawai.vue'), meta: { judul: 'Biodata Pegawai', menu: 'pegawai', cetak: true, kembali: '/pegawai' } },
      { path: 'santri', component: () => import('@/pages/santri/DaftarSantri.vue'), meta: { judul: 'Data Santri', cetak: true, kembali: '/tugas' } },
      { path: 'santri/baru', component: () => import('@/pages/santri/FormSantri.vue'), meta: { judul: 'Tambah Santri', kembali: '/santri' } },
      { path: 'santri/kelengkapan', component: () => import('@/pages/santri/KelengkapanSantri.vue'), meta: { judul: 'Kelengkapan Data Santri', cetak: true, kembali: '/santri' } },
      { path: 'santri/impor', component: () => import('@/pages/santri/ImporSantri.vue'), meta: { judul: 'Impor Data Santri', izin: 'kelola_santri', kembali: '/santri' } },
      { path: 'santri/portal-wali', redirect: '/portal-wali' },
      { path: 'portal-wali/:tab?', component: () => import('@/pages/santri/KelolaPortalWali.vue'), props: true, meta: { judul: 'Portal Wali', menu: 'portalwali', kembali: '/tugas' } },
      { path: 'santri/:id/rekam', component: () => import('@/pages/santri/RekamSantri.vue'), meta: { judul: 'Rekam Kesantrian', kembali: '/santri' } },
      { path: 'santri/:id/ubah', component: () => import('@/pages/santri/FormSantri.vue'), meta: { judul: 'Ubah Data Santri', kembali: '/santri' } },
      { path: 'santri/:id', component: () => import('@/pages/santri/DetailSantri.vue'), meta: { judul: 'Biodata Santri', cetak: true, kembali: '/santri' } },
      { path: 'absensi-santri/isi/:group/:tanggal/:sesi', component: () => import('@/pages/absensisantri/IsiAbsensi.vue'), meta: { judul: 'Isi Absensi Santri', kembali: '/absensi-santri' } },
      { path: 'disiplin-santri/:tab?', component: () => import('@/pages/disiplin/DisiplinSantri.vue'), props: true, meta: { judul: 'Kedisiplinan Santri', kembali: '/tugas' } },
      { path: 'prestasi-santri', component: () => import('@/pages/prestasi/PrestasiSantri.vue'), meta: { judul: 'Prestasi Santri', cetak: true, kembali: '/tugas' } },
      { path: 'absensi-santri/:tab?', component: () => import('@/pages/absensisantri/AbsensiSantri.vue'), props: true, meta: { judul: 'Absensi Santri', kembali: '/tugas' } },
      { path: 'statistik-santri', component: () => import('@/pages/santri/StatistikSantri.vue'), meta: { judul: 'Statistik Santri', cetak: true, kembali: '/tugas' } },
      { path: 'tahun-ajaran-baru', component: () => import('@/pages/santri/PergantianTA.vue'), meta: { judul: 'Naik Kelas', menu: 'tahunajaran', kembali: '/tugas' } },
      { path: 'jadwal-pelajaran/:tab?', component: () => import('@/pages/jadwal/JadwalPelajaran.vue'), props: true, meta: { judul: 'Jadwal Pelajaran', kembali: '/tugas' } },
      { path: 'tahfizh/impor', component: () => import('@/pages/tahfizh/ImporHafalan.vue'), meta: { judul: 'Impor Hafalan Awal', kembali: '/tahfizh' } },
      { path: 'tahfizh/:tab?', component: () => import('@/pages/tahfizh/Tahfizh.vue'), props: true, meta: { judul: 'Tahfizh', kembali: '/tugas' } },
      { path: 'wali-kelas/:tab?', component: () => import('@/pages/walikelas/WaliKelas.vue'), props: true, meta: { judul: 'Wali Kelas', kembali: '/tugas' } },
      { path: 'guru-mapel/nilai/:id', component: () => import('@/pages/gurumapel/IsiNilai.vue'), meta: { judul: 'Lembar Nilai', kembali: '/guru-mapel/nilai' } },
      { path: 'guru-mapel/:tab?', component: () => import('@/pages/gurumapel/GuruMapel.vue'), props: true, meta: { judul: 'Guru Mapel', kembali: '/tugas' } },
      { path: 'penilaian/:tab?', component: () => import('@/pages/penilaian/Penilaian.vue'), props: true, meta: { judul: 'Penilaian', kembali: '/tugas' } },
      { path: 'musyrif/:tab?', component: () => import('@/pages/musyrif/Musyrif.vue'), props: true, meta: { judul: 'Musyrif', kembali: '/tugas' } },
      // Libur santri menjadi menu tersendiri; tautan lama (notifikasi) diarahkan ke menu baru
      { path: 'izin-santri/libur', redirect: '/libur-santri' },
      { path: 'libur-santri', component: () => import('@/pages/izin/LiburSantri.vue'), meta: { judul: 'Libur Santri', kembali: '/tugas' } },
      // 14.20.0: tautan surat izin (registri dokumen) membuka pratinjau surat di menu Perizinan
      { path: 'izin-santri/surat/:id', component: () => import('@/pages/izin/IzinSantri.vue'), props: (r) => ({ tab: 'riwayat', surat: r.params.id }), meta: { judul: 'Perizinan', kembali: '/tugas' } },
      { path: 'izin-santri/:tab?', component: () => import('@/pages/izin/IzinSantri.vue'), props: true, meta: { judul: 'Perizinan', kembali: '/tugas' } },
      { path: 'persuratan/:tab?', component: () => import('@/pages/persuratan/Persuratan.vue'), props: true, meta: { judul: 'Persuratan', kembali: '/tugas' } },
      { path: 'segera/tatausaha', redirect: '/persuratan' },
      { path: 'lapor/:tab?', component: () => import('@/pages/lapor/Lapor.vue'), props: true, meta: { judul: 'Laporan', kembali: '/tugas' } },
      { path: 'security/:tab?', component: () => import('@/pages/security/Security.vue'), props: true, meta: { judul: 'Security', kembali: '/tugas' } },
      { path: 'klinik/:tab?', component: () => import('@/pages/klinik/Klinik.vue'), props: true, meta: { judul: 'Klinik', kembali: '/tugas' } },
      { path: 'ekskul/:tab?', component: () => import('@/pages/ekskul/Ekskul.vue'), props: true, meta: { judul: 'Ekskul', kembali: '/tugas' } },
      { path: 'kelompok-santri/impor', component: () => import('@/pages/kelompoksantri/ImporKelompok.vue'), meta: { judul: 'Impor Pembagian Kelompok', kembali: '/kelompok-santri' } },
      { path: 'kelompok-santri/k/:id', component: () => import('@/pages/kelompoksantri/DetailKelompok.vue'), meta: { judul: 'Kelompok Santri', cetak: true, kembali: '/kelompok-santri' } },
      { path: 'kelompok-santri/:tab?', component: () => import('@/pages/kelompoksantri/KelompokSantri.vue'), props: true, meta: { judul: 'Kelompok Santri', kembali: '/tugas' } },
      { path: 'gaji/:tab?', component: () => import('@/pages/gaji/Gaji.vue'), props: (r) => ({ tab: r.params.tab || '', menu: 'gaji' }), meta: { judul: 'Gaji', kembali: '/tugas' } },
      { path: 'tunjangan/:tab?', component: () => import('@/pages/gaji/Gaji.vue'), props: (r) => ({ tab: r.params.tab || '', menu: 'tunjangan' }), meta: { judul: 'Tunjangan', kembali: '/tugas' } },
      { path: 'jabatan-tunjangan/:tab?', redirect: '/tunjangan/peta' },
      { path: 'segera/gaji', redirect: '/gaji' },
      { path: 'keuangan/:tab?', component: () => import('@/pages/keuangan/Keuangan.vue'), props: (r) => ({ tab: r.params.tab || '' }), meta: { judul: 'Keuangan Santri', kembali: '/tugas' } },
      { path: 'presensi', component: () => import('@/pages/presensi/Presensi.vue'), meta: { judul: 'Presensi' } },
      { path: 'atur-presensi/:tab?', component: () => import('@/pages/presensi/AturPresensi.vue'), props: true, meta: { judul: 'Penjadwalan', menu: 'aturpresensi', kembali: '/tugas' } },
      { path: 'data-presensi/:tab?', component: () => import('@/pages/presensi/DataPresensi.vue'), props: true, meta: { judul: 'Data Presensi', menu: 'datapresensi', kembali: '/tugas' } },
      { path: 'verval-presensi/data', redirect: '/data-presensi' },
      { path: 'verval-presensi/:tab?', component: () => import('@/pages/verval/VervalPresensi.vue'), props: true, meta: { judul: 'Verval Presensi', menu: 'vervalpresensi', kembali: '/tugas' } },
      { path: 'rekap-presensi/:tab?', redirect: (to) => ({ path: `/rekap/${to.params.tab || 'harian'}`, query: to.query }) },
      { path: 'jadwal-shift', component: () => import('@/pages/shift/JadwalShift.vue'), meta: { judul: 'Jadwal Shift', kembali: '/tugas' } },
      { path: 'verifikasi/:tab?', component: () => import('@/pages/akun/Verifikasi.vue'), props: true, meta: { judul: 'Verifikasi dan Akun', menu: 'verifikasi', kembali: '/tugas' } },
      { path: 'organisasi/:tab?', component: () => import('@/pages/organisasi/Organisasi.vue'), props: true, meta: { judul: 'Organisasi', menu: 'organisasi', cetak: true, kembali: '/tugas' } },
      { path: 'hak-akses/:tab?', component: () => import('@/pages/hakakses/HakAkses.vue'), props: true, meta: { judul: 'Hak Akses Fitur', peran: ['superadmin'], kembali: '/tugas' } },
      { path: 'pengaturan/:tab?', component: () => import('@/pages/pengaturan/Pengaturan.vue'), props: true, meta: { judul: 'Setelan', peran: ['superadmin'], kembali: '/tugas' } },
      { path: 'pengumuman/:id?', component: () => import('@/pages/pengumuman/Pengumuman.vue'), props: true, meta: { judul: 'Pengumuman', kembali: '/' } },
      { path: 'pengajuan/:id?', component: () => import('@/pages/pengajuan/Pengajuan.vue'), props: true, meta: { judul: 'Pengajuan', kembali: '/tugas' } },
      { path: 'jurnal/:tab?', component: () => import('@/pages/jurnal/Jurnal.vue'), props: true, meta: { judul: 'Jurnal Harian', kembali: '/tugas' } },
      { path: 'berkas/:id?', component: () => import('@/pages/berkas/Berkas.vue'), props: true, meta: { judul: 'Berkas Saya', kembali: '/tugas' } },
      { path: 'kartu', component: () => import('@/pages/kartu/Kartu.vue'), meta: { judul: 'Kartu Pegawai', kembali: '/profil' } },
      { path: 'agenda/:id?', component: () => import('@/pages/agenda/Agenda.vue'), props: true, meta: { judul: 'Agenda', kembali: '/' } },
      { path: 'kelompok-pegawai', redirect: { path: '/pegawai', query: { tab: 'tim' } } },   // Tim Kerja kini tab di Data Pegawai
      { path: 'beban-kerja/:tab?', component: () => import('@/pages/beban/BebanKerja.vue'), props: true, meta: { judul: 'Ekuivalensi Jam Beban Kerja', kembali: '/tugas' } },
      { path: 'audit-log', component: () => import('@/pages/audit/AuditLog.vue'), meta: { judul: 'Audit Log', menu: 'auditlog', kembali: '/tugas' } },
      // 14.24.0: Dokumen resmi pindah ke Persuratan; Ambang kehadiran pindah dari Setelan ke Pelaporan (Ambang batas)
      { path: 'rekap/dokumen', redirect: (to) => ({ path: '/persuratan/dokumen', query: to.query }) },
      { path: 'pengaturan/ambang', redirect: '/rekap/ambang' },
      { path: 'rekap/:tab?', component: () => import('@/pages/laporan/Laporan.vue'), props: true, meta: { judul: 'Pelaporan', cetak: true, kembali: '/tugas' } },
      { path: 'laporan/:tab?', redirect: (to) => ({ path: `/rekap/${to.params.tab || ''}`, query: to.query }) },
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
  // Perangkat wali (ada sesi Portal Wali, tanpa akun pegawai): aplikasi terpasang langsung membuka Portal Wali
  if (!sesi.masuk && to.path === '/' && adaSesiWali()) return '/wali'
  if (!sesi.masuk) return { path: '/masuk', query: to.fullPath !== '/' ? { lanjut: to.fullPath } : {} }
  // Akun dengan sandi sementara wajib mengganti sandi lebih dulu
  if (sesi.wajibGantiSandi && to.path !== '/ganti-sandi') return '/ganti-sandi'
  if (to.meta.peran && !to.meta.peran.includes(sesi.peran)) return '/'
  // Hak Akses (14.0.0): halaman mengikuti hak menu, izin admin efektif, atau syarat khusus; keamanan tetap di server
  if (to.meta.menu && !menuTerlihat(cariMenu(to.meta.menu), sesi.peran, sesi.ciriMenu)) return '/'
  if (to.meta.izin && !sesi.bolehAdmin(to.meta.izin)) return '/'
  if (to.meta.boleh && !to.meta.boleh(sesi)) return '/'
  return true
})
router.afterEach((to) => { document.title = `${to.meta.judul || 'SIMKA PRO'} – SIMKA PRO` })

export default router
