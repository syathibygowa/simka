<!-- SIMKA PRO | src/components/KartuLayananBeranda.vue | v1.0 | Fase 6 – Tahap 5 Penutup fase klinik dan lapor | 06/10/2026 -->
<script setup>
// Kartu statistik langsung layanan santri di Beranda: Klinik (antrean, lewat batas, dirawat, kontrol), Perizinan
// (menunggu keputusan, di luar pondok, terlambat kembali), dan Lapor ke Bidang (laporan baru, mendesak, laporan saya).
// Kartu tampil sesuai hak; diperbarui otomatis saat ada perubahan.
import { computed, onMounted } from 'vue'
import { PhHourglass, PhSiren, PhBed, PhCalendarCheck, PhSealCheck, PhSignOut, PhWarningCircle, PhMegaphone, PhTray, PhPaperPlaneTilt, PhFirstAidKit } from '@phosphor-icons/vue'
import { useLayanan } from '@/stores/layanan'
import KartuStatistik from './KartuStatistik.vue'
const ly = useLayanan()
onMounted(() => { ly.muatBeranda(); ly.dengarkanBeranda() })
const kartu = computed(() => {
  const d = ly.beranda; if (!d) return []
  const k = []
  if (d.klinik) {
    k.push({ j: 'Antrean klinik', v: d.klinik.menunggu, i: PhHourglass, w: 'pengajuan', ke: '/klinik/antrean', ket: 'Rujukan belum diperiksa' })
    k.push({ j: 'Rujukan lewat batas', v: d.klinik.lewat, i: PhSiren, w: 'klinik', ke: '/klinik/antrean', ket: d.klinik.lewat ? 'Segera periksa' : 'Semua tepat waktu' })
    k.push({ j: 'Santri dirawat', v: d.klinik.dirawat, i: PhBed, w: 'santri', ke: '/klinik/dirawat', ket: `${d.klinik.kontrol_hari_ini} kontrol hari ini` })
  } else if (d.rujukan_saya) k.push({ j: 'Rujukan saya', v: d.rujukan_saya, i: PhFirstAidKit, w: 'klinik', ke: '/klinik/rujukan', ket: 'Santri asuhan di klinik' })
  if (d.izin?.tampil || d.izin?.putuskan) {
    k.push({ j: 'Izin menunggu Anda', v: d.izin.putuskan, i: PhSealCheck, w: 'agenda', ke: '/izin-santri/persetujuan', ket: 'Perlu keputusan' })
    k.push({ j: 'Santri di luar', v: d.izin.di_luar, i: PhSignOut, w: 'shift', ke: '/izin-santri/aktif', ket: `${d.izin.terlambat} terlambat kembali` })
  } else if (d.izin?.diajukan_saya) k.push({ j: 'Izin diajukan', v: d.izin.diajukan_saya, i: PhSignOut, w: 'agenda', ke: '/izin-santri/menunggu', ket: 'Menunggu keputusan' })
  if (d.izin?.terlambat && !(d.izin?.tampil || d.izin?.putuskan)) k.push({ j: 'Terlambat kembali', v: d.izin.terlambat, i: PhWarningCircle, w: 'klinik', ke: '/izin-santri/aktif', ket: 'Santri asuhan' })
  if (d.lapor?.penerima) {
    k.push({ j: 'Laporan masuk', v: d.lapor.baru, i: PhTray, w: 'laporan', ke: '/lapor/masuk', ket: `${d.lapor.proses} sedang ditangani` })
    k.push({ j: 'Laporan mendesak', v: d.lapor.mendesak, i: PhMegaphone, w: 'klinik', ke: '/lapor/masuk', ket: 'Belum selesai' })
  }
  if (d.lapor?.saya_terbuka) k.push({ j: 'Laporan saya', v: d.lapor.saya_terbuka, i: PhPaperPlaneTilt, w: 'laporan', ke: '/lapor/saya', ket: 'Belum selesai' })
  return k
})
</script>
<template>
  <section v-if="kartu.length">
    <div class="mb-3 flex items-center justify-between gap-2">
      <h2 class="judul-bagian">Layanan santri</h2>
      <router-link to="/lapor" class="text-sm font-semibold text-merah">Lapor ke bidang</router-link>
    </div>
    <div class="grid grid-cols-2 gap-3 sm:gap-4 lg:grid-cols-3 xl:grid-cols-4">
      <KartuStatistik v-for="x in kartu" :key="x.j" :judul="x.j" :nilai="x.v ?? 0" :ikon="x.i" :warna="x.w" :ke="x.ke" :keterangan="x.ket" />
    </div>
  </section>
</template>
