<!-- SIMKA PRO | src/pages/beranda/StatistikPresensi.vue | v1.0 | Fase 2 – Tahap 7 Statistik, rekap, pengingat | 03/10/2026 -->
<script setup>
// Kartu statistik presensi hari ini (admin dan superadmin), diperbarui langsung lewat Realtime.
// Setiap kartu memakai pasangan warna sendiri.
import { computed, onMounted, onBeforeUnmount } from 'vue'
import { PhUserCheck, PhChartPieSlice, PhClockCountdown, PhTray, PhFirstAidKit, PhWarningOctagon, PhHourglassMedium, PhXCircle } from '@phosphor-icons/vue'
import { useRekapPresensi } from '@/stores/rekapPresensi'
import KartuStatistik from '@/components/KartuStatistik.vue'
import IndikatorLangsung from './IndikatorLangsung.vue'

const rp = useRekapPresensi()
onMounted(() => rp.mulai())
onBeforeUnmount(() => rp.berhenti())
const d = computed(() => rp.stat || {}); const ch = computed(() => rp.berubah)
const persen = (a, b) => (b ? Math.round((100 * a) / b) : 0)
</script>
<template>
  <section class="space-y-3">
    <div class="flex flex-wrap items-center justify-between gap-2">
      <h2 class="judul-bagian">Presensi hari ini</h2>
      <IndikatorLangsung :waktu="rp.diperbarui" />
    </div>
    <div class="grid grid-cols-2 gap-3 sm:gap-4 xl:grid-cols-4">
      <KartuStatistik judul="Pegawai hadir" :nilai="d.pegawai_hadir" :ikon="PhUserCheck" warna="presensi" ke="/rekap-presensi/harian"
        :keterangan="`dari ${d.pegawai_terjadwal ?? 0} pegawai terjadwal`" :perubahan="ch.pegawai_hadir" />
      <KartuStatistik judul="Tingkat kehadiran" :nilai="d.persen_kehadiran ?? '–'" satuan="%" :ikon="PhChartPieSlice" warna="gaji" ke="/rekap-presensi/harian"
        :keterangan="`${d.sesi_tercatat ?? 0} dari ${d.sesi_wajib ?? 0} sesi tercatat`" :perubahan="ch.persen_kehadiran" />
      <KartuStatistik judul="Terlambat" :nilai="d.terlambat" :ikon="PhClockCountdown" warna="tahfizh" ke="/rekap-presensi/harian"
        :keterangan="`${persen(d.terlambat, d.sesi_tercatat)}% dari sesi tercatat`" :perubahan="ch.terlambat" />
      <KartuStatistik judul="Menunggu verval" :nilai="d.verval_menunggu" :ikon="PhTray" warna="verval" ke="/verval-presensi/antrian"
        keterangan="Luar area dan izin sesi" :perubahan="ch.verval_menunggu" />
      <KartuStatistik judul="Izin, sakit, cuti" :nilai="d.izin_sakit_cuti" :ikon="PhFirstAidKit" warna="klinik" ke="/rekap-presensi/harian"
        :keterangan="`${d.dinas_luar ?? 0} sesi dinas luar`" :perubahan="ch.izin_sakit_cuti" />
      <KartuStatistik judul="Sedang terbuka" :nilai="d.terbuka_belum" :ikon="PhHourglassMedium" warna="santri" ke="/rekap-presensi/harian"
        :keterangan="`${d.akan_datang ?? 0} sesi akan datang`" :perubahan="ch.terbuka_belum" />
      <KartuStatistik judul="Terlewat / tanpa keterangan" :nilai="(d.terlewat_belum ?? 0) + (d.tanpa_keterangan ?? 0)" :ikon="PhXCircle" warna="beranda" ke="/rekap-presensi/harian"
        keterangan="Sesi wajib tanpa presensi" :perubahan="ch.tanpa_keterangan" />
      <KartuStatistik judul="Penanda kecurigaan" :nilai="d.curiga_baru" :ikon="PhWarningOctagon" warna="pengumuman" ke="/verval-presensi/kecurigaan"
        keterangan="Perlu ditinjau" :perubahan="ch.curiga_baru" />
    </div>
    <div v-if="d.per_pola?.length" class="kartu p-4">
      <h3 class="mb-2 text-sm font-bold text-teks2">Kehadiran per pola tugas</h3>
      <ul class="space-y-2">
        <li v-for="p in d.per_pola" :key="p.pola" class="grid grid-cols-[minmax(7rem,10rem)_1fr_4.5rem] items-center gap-3 text-sm">
          <span class="truncate font-semibold">{{ p.pola }}</span>
          <span class="h-2.5 overflow-hidden rounded-full bg-permukaan2"><span class="block h-full rounded-full bg-[#1E7D4F] dark:bg-[#5BD69A]" :style="{ width: persen(p.hadir, p.wajib) + '%' }" /></span>
          <span class="text-right tabular-nums text-teks2">{{ p.hadir }}/{{ p.wajib }}</span>
        </li>
      </ul>
    </div>
  </section>
</template>
