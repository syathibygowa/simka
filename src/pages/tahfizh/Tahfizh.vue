<!-- SIMKA PRO | src/pages/tahfizh/Tahfizh.vue | v1.1 | Fase 5 – Tahap 2 Setoran per sesi halaqah | 05/10/2026 -->
<script setup>
// Menu Tahfizh. Tahap 2: tab Setoran (sesi halaqah per tanggal). Tahap 1: tab Data hafalan (program, posisi, capaian juz resmi, data awal) dan
// Ketentuan (KKM, target, predikat, pekan efektif, penguji; diubah oleh pemegang izin atur_tahfizh).
// Tab Setoran, Capaian, Ujian, dan Laporan ditambahkan pada tahap berikutnya.
import { computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { PhBookOpenText, PhListChecks, PhLockSimple, PhNotebook } from '@phosphor-icons/vue'
import { useTahfizh } from '@/stores/tahfizh'
import TabSetoran from './TabSetoran.vue'
import TabSantriTahfizh from './TabSantriTahfizh.vue'
import TabKetentuanTahfizh from './TabKetentuanTahfizh.vue'

const props = defineProps({ tab: { type: String, default: '' } })
const router = useRouter(); const tz = useTahfizh()
onMounted(() => tz.hakDimuat || tz.muatHak())
const TAB = [
  { k: 'setoran', n: 'Setoran', ikon: PhNotebook, w: 'presensi' },
  { k: 'santri', n: 'Data hafalan', ikon: PhBookOpenText, w: 'tahfizh' },
  { k: 'ketentuan', n: 'Ketentuan', ikon: PhListChecks, w: 'pengaturan' },
]
const aktif = computed(() => (TAB.some((t) => t.k === props.tab) ? props.tab : 'setoran'))
</script>
<template>
  <div>
    <div class="-mx-4 mb-4 flex gap-2 overflow-x-auto px-4 pb-1 lg:mx-0 lg:px-0" role="tablist">
      <button v-for="t in TAB" :key="t.k" role="tab" :aria-selected="aktif === t.k" @click="router.replace(`/tahfizh/${t.k}`)"
        :class="['inline-flex min-h-[44px] shrink-0 items-center gap-2 rounded-full border-2 px-4 text-sm font-semibold', 'w-' + t.w, aktif === t.k ? 'text-teks' : 'border-garis bg-permukaan text-teks2']"
        :style="aktif === t.k ? 'border-color: var(--c); background: color-mix(in srgb, var(--c) 14%, transparent)' : ''">
        <component :is="t.ikon" :size="18" weight="duotone" style="color: var(--c)" />{{ t.n }}</button>
    </div>

    <div v-if="tz.hakDimuat && !tz.hak.lihat" class="kartu w-tahfizh flex items-center gap-3 p-5">
      <span class="chip-ikon h-11 w-11"><PhLockSimple :size="24" weight="duotone" /></span>
      <p class="text-sm text-teks2">Menu Tahfizh terbuka bagi muhaffizh (halaqah yang diasuh), pimpinan Bidang Tahfizh, admin, dan pemegang hak fitur Tahfizh.</p>
    </div>
    <template v-else>
      <TabSetoran v-if="aktif === 'setoran'" />
      <TabSantriTahfizh v-else-if="aktif === 'santri'" />
      <TabKetentuanTahfizh v-else />
    </template>
  </div>
</template>
