<!-- SIMKA PRO | src/components/KartuSecurityBeranda.vue | v1.1 | Fase 7 – Tahap 2 Titipan, buku tamu, kunjungan | 06/10/2026 -->
<script setup>
// Kartu statistik langsung Security di Beranda (petugas Security, pimpinan, yayasan, admin, superadmin):
// gerbang (siap keluar, di luar, terlambat, catatan hari ini) dan layanan pos (titipan, tamu, kunjungan).
// Diperbarui otomatis (Realtime).
import { computed, onMounted } from 'vue'
import { PhCheckCircle, PhSignOut, PhSiren, PhSignIn, PhPackage, PhIdentificationBadge, PhUsersThree, PhHandArrowDown } from '@phosphor-icons/vue'
import { useSecurity } from '@/stores/security'
import KartuStatistik from './KartuStatistik.vue'
const sc = useSecurity()
onMounted(() => { sc.muatBeranda(); sc.dengarkanBeranda() })
const d = computed(() => sc.beranda)
const kartu = computed(() => !d.value ? [] : [
  { j: 'Siap keluar', v: d.value.siap, i: PhCheckCircle, w: 'presensi', ke: '/security/gerbang', ket: 'Izin berlaku hari ini' },
  { j: 'Santri di luar', v: d.value.di_luar, i: PhSignOut, w: 'security', ke: '/security/diluar', ket: 'Belum kembali' },
  { j: 'Terlambat kembali', v: d.value.terlambat, i: PhSiren, w: 'klinik', ke: '/security/diluar', ket: d.value.terlambat ? 'Segera tindak lanjuti' : 'Semua tepat waktu' },
  { j: 'Gerbang hari ini', v: d.value.kembali_hari_ini, i: PhSignIn, w: 'rekap', ke: '/security/riwayat', ket: `kembali · ${d.value.keluar_hari_ini} keluar · ${d.value.ditolak_hari_ini} ditolak` },
  { j: 'Titipan di pos', v: d.value.titipan_di_pos ?? 0, i: PhPackage, w: 'pengajuan', ke: '/security/titipan', ket: d.value.titipan_lama ? `${d.value.titipan_lama} lewat batas ambil` : `${d.value.titipan_hari_ini ?? 0} masuk hari ini` },
  { j: 'Titipan diambil', v: d.value.diambil_hari_ini ?? 0, i: PhHandArrowDown, w: 'gaji', ke: '/security/titipan', ket: 'Hari ini, tercatat pengambilnya' },
  { j: 'Tamu di dalam', v: d.value.tamu_di_dalam ?? 0, i: PhIdentificationBadge, w: 'pegawai', ke: '/security/tamu', ket: `${d.value.tamu_hari_ini ?? 0} tamu hari ini` },
  { j: 'Kunjungan wali', v: d.value.kunjungan_berlangsung ?? 0, i: PhUsersThree, w: 'tahfizh', ke: '/security/kunjungan', ket: `berlangsung · ${d.value.kunjungan_hari_ini ?? 0} hari ini` },
])
</script>
<template>
  <section v-if="kartu.length">
    <div class="mb-3 flex items-center justify-between gap-2">
      <h2 class="judul-bagian">Security dan gerbang</h2>
      <router-link to="/security" class="text-sm font-semibold text-merah">Buka Security</router-link>
    </div>
    <div class="grid grid-cols-2 gap-3 sm:gap-4 lg:grid-cols-4">
      <KartuStatistik v-for="x in kartu" :key="x.j" :judul="x.j" :nilai="x.v ?? 0" :ikon="x.i" :warna="x.w" :ke="x.ke" :keterangan="x.ket" />
    </div>
  </section>
</template>
