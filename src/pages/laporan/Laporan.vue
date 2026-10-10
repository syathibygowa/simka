<!-- SIMKA PRO | src/pages/laporan/Laporan.vue | v1.1 | Fase 8 – Perbaikan: menu Rekap bertab (gabung Rekap Presensi) | 10/10/2026 -->
<script setup>
// Menu Rekap: satu menu bertab untuk semua rekap dan laporan resmi (hemat menu sidebar).
// Tab: Presensi harian dan Presensi periode (admin/superadmin; dahulu menu Rekap Presensi), Dokumen resmi
// (registri dokumen bertanda tangan elektronik). Tab laporan kehadiran dan laporan modul lain menyusul di sini.
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { PhSealCheck, PhCalendarCheck, PhCalendarDots } from '@phosphor-icons/vue'
import { useSesi } from '@/stores/sesi'
import BilahTab from '@/components/BilahTab.vue'
import RekapPresensi from '@/pages/rekap/RekapPresensi.vue'
import TabDokumenResmi from './TabDokumenResmi.vue'

const props = defineProps({ tab: { type: String, default: '' } })
const router = useRouter(); const sesi = useSesi()
const TAB = computed(() => [
  ...(sesi.isAdmin ? [{ k: 'harian', n: 'Presensi harian', ikon: PhCalendarCheck, w: 'presensi' }, { k: 'periode', n: 'Presensi periode', ikon: PhCalendarDots, w: 'laporan' }] : []),
  { k: 'dokumen', n: 'Dokumen resmi', ikon: PhSealCheck, w: 'verifikasi' },
])
const aktif = computed({
  get: () => (TAB.value.some((t) => t.k === props.tab) ? props.tab : TAB.value[0].k),
  set: (k) => router.replace(`/rekap/${k}`),
})
</script>
<template>
  <div class="space-y-4">
    <BilahTab v-model="aktif" :tab="TAB" label="Bagian rekap" />
    <RekapPresensi v-if="aktif === 'harian' || aktif === 'periode'" :tab="aktif" tertanam />
    <TabDokumenResmi v-else-if="aktif === 'dokumen'" />
  </div>
</template>
