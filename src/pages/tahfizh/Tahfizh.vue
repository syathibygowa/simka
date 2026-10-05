<!-- SIMKA PRO | src/pages/tahfizh/Tahfizh.vue | v1.5 | Fase 5 – Tahap 5 Laporan dan grafik tahfizh | 05/10/2026 -->
<script setup>
// Menu Tahfizh. Tahap 5: tab Laporan (15 laporan dan grafik). Tahap 4: tab Ujian (kenaikan juz, sertifikasi). Tahap 3: tab Capaian (status bulanan, usulan juz). Tahap 2: tab Setoran (sesi halaqah per tanggal). Tahap 1: tab Data hafalan (program, posisi, capaian juz resmi, data awal) dan
// Ketentuan (KKM, target, predikat, pekan efektif, penguji; diubah oleh pemegang izin atur_tahfizh).
// Tab Setoran, Capaian, Ujian, dan Laporan ditambahkan pada tahap berikutnya.
import { computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { PhBookOpenText, PhListChecks, PhLockSimple, PhNotebook, PhSealCheck, PhExam, PhChartPieSlice } from '@phosphor-icons/vue'
import { useTahfizh } from '@/stores/tahfizh'
import BilahTab from '@/components/BilahTab.vue'
import TabSetoran from './TabSetoran.vue'
import TabSantriTahfizh from './TabSantriTahfizh.vue'
import TabCapaian from './TabCapaian.vue'
import TabUjian from './TabUjian.vue'
import TabLaporan from './TabLaporan.vue'
import TabKetentuanTahfizh from './TabKetentuanTahfizh.vue'

const props = defineProps({ tab: { type: String, default: '' } })
const router = useRouter(); const tz = useTahfizh()
onMounted(() => tz.hakDimuat || tz.muatHak())
const TAB = [
  { k: 'setoran', n: 'Setoran', ikon: PhNotebook, w: 'presensi' },
  { k: 'capaian', n: 'Capaian', ikon: PhSealCheck, w: 'pengajuan' },
  { k: 'ujian', n: 'Ujian', ikon: PhExam, w: 'agenda' },
  { k: 'laporan', n: 'Laporan', ikon: PhChartPieSlice, w: 'laporan' },
  { k: 'santri', n: 'Data hafalan', ikon: PhBookOpenText, w: 'tahfizh' },
  { k: 'ketentuan', n: 'Ketentuan', ikon: PhListChecks, w: 'pengaturan' },
]
const aktif = computed(() => (TAB.some((t) => t.k === props.tab) ? props.tab : 'setoran'))
</script>
<template>
  <div>
    <BilahTab class="mb-4" :tab="TAB" :model-value="aktif" label="Bagian tahfizh" @update:model-value="(k) => router.replace(`/tahfizh/${k}`)" />

    <div v-if="tz.hakDimuat && !tz.hak.lihat" class="kartu w-tahfizh flex items-center gap-3 p-5">
      <span class="chip-ikon h-11 w-11"><PhLockSimple :size="24" weight="duotone" /></span>
      <p class="text-sm text-teks2">Menu Tahfizh terbuka bagi muhaffizh (halaqah yang diasuh), pimpinan Bidang Tahfizh, admin, dan pemegang hak fitur Tahfizh.</p>
    </div>
    <template v-else>
      <TabSetoran v-if="aktif === 'setoran'" />
      <TabCapaian v-else-if="aktif === 'capaian'" />
      <TabUjian v-else-if="aktif === 'ujian'" />
      <TabLaporan v-else-if="aktif === 'laporan'" />
      <TabSantriTahfizh v-else-if="aktif === 'santri'" />
      <TabKetentuanTahfizh v-else />
    </template>
  </div>
</template>
