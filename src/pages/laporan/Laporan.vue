<!-- SIMKA PRO | src/pages/laporan/Laporan.vue | v1.0 | Fase 8 – Tahap 1 Registri dokumen dan Cek Keabsahan | 10/10/2026 -->
<script setup>
// Menu Laporan: pusat laporan resmi SIMKA PRO. Tahap ini: tab Dokumen resmi (registri dokumen bertanda tangan
// elektronik beserta kode validasinya). Tab laporan kehadiran pegawai/santri dan laporan modul lain menyusul.
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { PhSealCheck } from '@phosphor-icons/vue'
import BilahTab from '@/components/BilahTab.vue'
import TabDokumenResmi from './TabDokumenResmi.vue'

const props = defineProps({ tab: { type: String, default: 'dokumen' } })
const router = useRouter()
const TAB = [{ k: 'dokumen', n: 'Dokumen resmi', ikon: PhSealCheck, w: 'presensi' }]
const aktif = computed({ get: () => (TAB.some((t) => t.k === props.tab) ? props.tab : 'dokumen'), set: (k) => router.replace(`/laporan/${k}`) })
</script>
<template>
  <div class="space-y-4">
    <BilahTab v-model="aktif" :tab="TAB" label="Bagian laporan" />
    <TabDokumenResmi v-if="aktif === 'dokumen'" />
  </div>
</template>
