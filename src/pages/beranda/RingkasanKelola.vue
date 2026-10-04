<!-- SIMKA PRO | src/pages/beranda/RingkasanKelola.vue | v1.0 | Fase 3 – Tahap 6 Dashboard per peran | 04/10/2026 -->
<script setup>
// Kartu statistik langsung modul Fase 3 untuk admin/superadmin. Kartu yang memerlukan izin admin tertentu
// hanya tampil bila izinnya dimiliki (nilai null dari server).
import { computed } from 'vue'
import { PhSealCheck, PhFileText, PhUserMinus, PhCalendarCheck, PhFolderOpen, PhIdentificationCard, PhNotebook, PhDeviceMobile, PhWarningCircle, PhMegaphone } from '@phosphor-icons/vue'
import KartuStatistik from '@/components/KartuStatistik.vue'

const props = defineProps({ d: { type: Object, default: () => ({}) } })
const kartu = computed(() => [
  { k: 'verval_jurnal', judul: 'Kegiatan jurnal menunggu verval', ikon: PhSealCheck, warna: 'verval', ke: '/jurnal/verval', ket: 'Ketuk untuk memverval' },
  { k: 'pengajuan_menunggu', judul: 'Pengajuan dalam proses', ikon: PhFileText, warna: 'pengajuan', ke: '/pengajuan?tab=semua', ket: `${props.d.pengajuan_bulan_ini ?? 0} disetujui bulan ini` },
  { k: 'sedang_izin', judul: 'Pegawai izin/cuti hari ini', ikon: PhUserMinus, warna: 'klinik', ke: '/pengajuan?tab=semua', ket: 'Izin, sakit, cuti, dinas luar' },
  { k: 'jurnal_hari_ini', judul: 'Pegawai mengisi jurnal hari ini', ikon: PhNotebook, warna: 'tatausaha', ke: '/jurnal/rekap', ket: `dari ${props.d.akun_aktif ?? 0} akun aktif` },
  { k: 'agenda_bulan_ini', judul: 'Agenda bulan ini', ikon: PhCalendarCheck, warna: 'agenda', ke: '/agenda', ket: `${props.d.agenda_pekan_ini ?? 0} dalam 7 hari ke depan` },
  { k: 'pengumuman_aktif', judul: 'Pengumuman aktif', ikon: PhMegaphone, warna: 'pengumuman', ke: '/pengumuman' },
  { k: 'berkas_belum_dibuka', judul: 'Berkas belum dibuka penerima', ikon: PhFolderOpen, warna: 'berkas', ke: '/berkas' },
  { k: 'kartu_terbit', judul: 'Kartu pegawai terbit', ikon: PhIdentificationCard, warna: 'profil', ke: '/kartu', ket: `${props.d.tanpa_foto ?? 0} akun belum berpas foto` },
  { k: 'perangkat_push', judul: 'Pegawai dengan notifikasi HP', ikon: PhDeviceMobile, warna: 'notifikasi', ket: `dari ${props.d.akun_aktif ?? 0} akun aktif` },
  { k: 'tanpa_niy', judul: 'Pegawai aktif tanpa NIY', ikon: PhWarningCircle, warna: 'beranda', ke: '/pegawai', ket: 'Lengkapi sebelum cetak kartu' },
].filter((x) => props.d[x.k] != null))
</script>
<template>
  <div class="grid grid-cols-2 gap-3 sm:gap-4 lg:grid-cols-5">
    <KartuStatistik v-for="x in kartu" :key="x.k" :judul="x.judul" :nilai="d[x.k]" :ikon="x.ikon" :warna="x.warna" :ke="x.ke" :keterangan="x.ket" />
  </div>
</template>
