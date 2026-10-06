<!-- SIMKA PRO | src/components/KartuSecurityBeranda.vue | v1.0 | Fase 7 – Tahap 1 Security: gerbang | 06/10/2026 -->
<script setup>
// Kartu statistik langsung Security di Beranda (petugas Security, pimpinan, yayasan, admin, superadmin):
// siap keluar, di luar pondok, terlambat kembali, catatan gerbang hari ini. Diperbarui otomatis (Realtime).
import { computed, onMounted } from 'vue'
import { PhCheckCircle, PhSignOut, PhSiren, PhSignIn } from '@phosphor-icons/vue'
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
