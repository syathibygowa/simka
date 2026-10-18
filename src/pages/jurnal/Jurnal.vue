<!-- SIMKA PRO | src/pages/jurnal/Jurnal.vue | v1.4 | 14.2.0: tab Pengaturan (jurnal mengajar + template ceklist) | 17/10/2026 -->
<script setup>
// Jurnal harian pegawai. Tab: Jurnal saya (semua pegawai), Verval (admin ber-izin verval_jurnal),
// Rekap (pegawai: dirinya; pimpinan: anggota unit; admin: semua), Pengaturan: jurnal mengajar (admin ber-izin atur_jadwal)
// dan template ceklist jurnal harian (admin ber-izin atur_jurnal). v1.4: alamat lama /jurnal/template diarahkan ke Pengaturan.
import { computed, nextTick, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { PhNotebook, PhSealCheck, PhChartBar, PhGear, PhChalkboardTeacher } from '@phosphor-icons/vue'
import { useSesi } from '@/stores/sesi'
import TabHarian from './TabHarian.vue'
import TabVervalJurnal from './TabVervalJurnal.vue'
import TabRekapJurnal from './TabRekapJurnal.vue'
import TabTemplateJurnal from './TabTemplateJurnal.vue'
import TabMengajar from './TabMengajar.vue'
import PengaturanJurnalMengajar from './PengaturanJurnalMengajar.vue'

const props = defineProps({ tab: { type: String, default: 'harian' } })
const router = useRouter(); const route = useRoute(); const sesi = useSesi()
const aturMengajar = computed(() => sesi.isSuperadmin || sesi.bolehAdmin('atur_jadwal'))
const aturCeklist = computed(() => sesi.bolehAdmin('atur_jurnal'))
const TAB = computed(() => [
  { k: 'harian', n: 'Jurnal saya', ikon: PhNotebook, w: 'tatausaha' },
  (sesi.tugas?.mengajar || sesi.tingkat('jadwal_mengajar') >= 2 || sesi.isAdmin) && { k: 'mengajar', n: 'Jurnal mengajar', ikon: PhChalkboardTeacher, w: 'jadwal' },
  sesi.bolehAdmin('verval_jurnal') && { k: 'verval', n: 'Verval kegiatan', ikon: PhSealCheck, w: 'verval' },
  { k: 'rekap', n: 'Rekap dan laporan', ikon: PhChartBar, w: 'rekap' },
  (aturMengajar.value || aturCeklist.value) && { k: 'pengaturan', n: 'Pengaturan', ikon: PhGear, w: 'pengaturan' },
].filter(Boolean))
const aktif = computed(() => TAB.value.find((t) => t.k === (props.tab === 'template' ? 'pengaturan' : props.tab)) || TAB.value[0])
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
      <div v-else-if="aktif.k === 'pengaturan'" class="space-y-4">
        <PengaturanJurnalMengajar v-if="aturMengajar" />
        <section v-if="aturCeklist"><h2 class="judul-bagian mb-2 px-1">Template ceklist jurnal harian</h2><TabTemplateJurnal /></section>
      </div>
    </div>
  </div>
</template>

