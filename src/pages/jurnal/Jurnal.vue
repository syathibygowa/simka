<!-- SIMKA PRO | src/pages/jurnal/Jurnal.vue | v1.0 | Fase 3 – Tahap 3 Jurnal harian | 04/10/2026 -->
<script setup>
// Jurnal harian pegawai. Tab: Jurnal saya (semua pegawai), Verval (admin ber-izin verval_jurnal),
// Rekap (pegawai: dirinya; pimpinan: anggota unit; admin: semua), Template ceklist (admin ber-izin atur_jurnal).
import { computed, nextTick, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { PhNotebook, PhSealCheck, PhChartBar, PhListChecks } from '@phosphor-icons/vue'
import { useSesi } from '@/stores/sesi'
import TabHarian from './TabHarian.vue'
import TabVervalJurnal from './TabVervalJurnal.vue'
import TabRekapJurnal from './TabRekapJurnal.vue'
import TabTemplateJurnal from './TabTemplateJurnal.vue'

const props = defineProps({ tab: { type: String, default: 'harian' } })
const router = useRouter(); const route = useRoute(); const sesi = useSesi()
const TAB = computed(() => [
  { k: 'harian', n: 'Jurnal saya', ikon: PhNotebook, w: 'tatausaha' },
  sesi.bolehAdmin('verval_jurnal') && { k: 'verval', n: 'Verval kegiatan', ikon: PhSealCheck, w: 'verval' },
  { k: 'rekap', n: 'Rekap dan laporan', ikon: PhChartBar, w: 'rekap' },
  sesi.bolehAdmin('atur_jurnal') && { k: 'template', n: 'Template ceklist', ikon: PhListChecks, w: 'pengaturan' },
].filter(Boolean))
const aktif = computed(() => TAB.value.find((t) => t.k === props.tab) || TAB.value[0])
onMounted(async () => { await nextTick(); document.querySelector('[role=tab][aria-selected=true]')?.scrollIntoView({ inline: 'center', block: 'nearest' }) })
</script>
<template>
  <div class="mx-auto max-w-5xl">
    <nav class="-mx-4 mb-4 flex gap-2 overflow-x-auto px-4 pb-1 lg:mx-0 lg:px-0" role="tablist" aria-label="Bagian jurnal harian">
      <button v-for="t in TAB" :key="t.k" role="tab" :aria-selected="aktif.k === t.k" @click="router.replace(`/jurnal/${t.k}`)"
        :class="['tab flex min-h-[44px] shrink-0 items-center gap-2.5 rounded-xl border px-3 text-sm font-semibold', 'w-' + t.w, aktif.k === t.k ? 'aktif text-teks' : 'border-garis bg-permukaan text-teks2 hover:text-teks']">
        <span class="chip-ikon h-8 w-8 rounded-lg"><component :is="t.ikon" :size="20" weight="duotone" /></span><span class="whitespace-nowrap">{{ t.n }}</span>
      </button>
    </nav>
    <div :class="aktif.k === 'harian' && 'mx-auto max-w-3xl'">
      <TabHarian v-if="aktif.k === 'harian'" :tanggal-awal="route.query.tanggal" />
      <TabVervalJurnal v-else-if="aktif.k === 'verval'" />
      <TabRekapJurnal v-else-if="aktif.k === 'rekap'" />
      <TabTemplateJurnal v-else-if="aktif.k === 'template'" />
    </div>
  </div>
</template>
<style scoped>
.tab.aktif { border-color: color-mix(in srgb, var(--c) 35%, transparent); background: color-mix(in srgb, var(--c) 12%, rgb(var(--permukaan))); }
</style>
