<!-- SIMKA PRO | src/pages/beranda/Beranda.vue | v1.1 | Fase 3 – Tahap 6 Dashboard per peran | 04/10/2026 -->
<script setup>
import { onMounted, onBeforeUnmount } from 'vue'
import { useSesi } from '@/stores/sesi'
import { useStatistik } from '@/stores/statistik'
import { useBeranda } from '@/stores/beranda'
import DasborSuperadmin from './DasborSuperadmin.vue'
import DasborAdmin from './DasborAdmin.vue'
import DasborPegawai from './DasborPegawai.vue'
const sesi = useSesi(); const stat = useStatistik(); const br = useBeranda()
onMounted(() => { if (sesi.isAdmin) stat.mulai(); br.mulai() })
onBeforeUnmount(() => { stat.berhenti(); br.berhenti() })
</script>
<template>
  <DasborSuperadmin v-if="sesi.isSuperadmin" />
  <DasborAdmin v-else-if="sesi.isAdmin" />
  <DasborPegawai v-else />
</template>
