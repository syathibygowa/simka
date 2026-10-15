<!-- SIMKA PRO | src/pages/jurnal/Jurnal.vue | v1.3 | Perbaikan 13.5.0: tab bergaris bawah | 15/10/2026 -->
<script setup>
// Jurnal harian pegawai. Tab: Jurnal saya (semua pegawai), Verval (admin ber-izin verval_jurnal),
// Rekap (pegawai: dirinya; pimpinan: anggota unit; admin: semua), Template ceklist (admin ber-izin atur_jurnal).
import { computed, nextTick, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { PhNotebook, PhSealCheck, PhChartBar, PhListChecks, PhChalkboardTeacher } from '@phosphor-icons/vue'
import { useSesi } from '@/stores/sesi'
import TabHarian from './TabHarian.vue'
import TabVervalJurnal from './TabVervalJurnal.vue'
import TabRekapJurnal from './TabRekapJurnal.vue'
import TabTemplateJurnal from './TabTemplateJurnal.vue'
import TabMengajar from './TabMengajar.vue'

const props = defineProps({ tab: { type: String, default: 'harian' } })
const router = useRouter(); const route = useRoute(); const sesi = useSesi()
const TAB = computed(() => [
  { k: 'harian', n: 'Jurnal saya', ikon: PhNotebook, w: 'tatausaha' },
  (sesi.tugas?.mengajar || sesi.tingkat('jadwal_mengajar') >= 2 || sesi.isAdmin) && { k: 'mengajar', n: 'Jurnal mengajar', ikon: PhChalkboardTeacher, w: 'jadwal' },
  sesi.bolehAdmin('verval_jurnal') && { k: 'verval', n: 'Verval kegiatan', ikon: PhSealCheck, w: 'verval' },
  { k: 'rekap', n: 'Rekap dan laporan', ikon: PhChartBar, w: 'rekap' },
  sesi.bolehAdmin('atur_jurnal') && { k: 'template', n: 'Template ceklist', ikon: PhListChecks, w: 'pengaturan' },
].filter(Boolean))
const aktif = computed(() => TAB.value.find((t) => t.k === props.tab) || TAB.value[0])
onMounted(async () => { await nextTick(); document.querySelector('[role=tab][aria-selected=true]')?.scrollIntoView({ inline: 'center', block: 'nearest' }) })
</script>
<template>
  <div class="mx-auto max-w-5xl">
    <nav class="bilah-tab -mx-4 mb-4 px-4 lg:mx-0 lg:px-0" role="tablist" aria-label="Bagian jurnal harian">
      <button v-for="t in TAB" :key="t.k" role="tab" :aria-selected="aktif.k === t.k" @click="router.replace(`/jurnal/${t.k}`)"
        :class="['tab-garis', 'w-' + t.w, aktif.k === t.k && 'aktif']">
        <component :is="t.ikon" :size="20" weight="duotone" /><span>{{ t.n }}</span>
      </button>
    </nav>
    <div :class="['harian', 'mengajar'].includes(aktif.k) && 'mx-auto max-w-3xl'">
      <TabHarian v-if="aktif.k === 'harian'" :tanggal-awal="route.query.tanggal" />
      <TabMengajar v-else-if="aktif.k === 'mengajar'" />
      <TabVervalJurnal v-else-if="aktif.k === 'verval'" />
      <TabRekapJurnal v-else-if="aktif.k === 'rekap'" />
      <TabTemplateJurnal v-else-if="aktif.k === 'template'" />
    </div>
  </div>
</template>

