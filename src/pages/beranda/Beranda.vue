<!-- SIMKA PRO | src/pages/beranda/Beranda.vue | v1.2 | Fase 8 – Tahap 0 Beranda pegawai fungsional tanpa statistik | 10/10/2026 -->
<script setup>
import { onMounted, onBeforeUnmount } from 'vue'
import { useSesi } from '@/stores/sesi'
import { useStatistik } from '@/stores/statistik'
import { useBeranda } from '@/stores/beranda'
import DasborSuperadmin from './DasborSuperadmin.vue'
import DasborAdmin from './DasborAdmin.vue'
import DasborPegawai from './DasborPegawai.vue'
import DasborFungsional from './DasborFungsional.vue'
const sesi = useSesi(); const stat = useStatistik(); const br = useBeranda()
onMounted(() => { if (sesi.isAdmin) stat.mulai(); br.mulai() })
onBeforeUnmount(() => { stat.berhenti(); br.berhenti() })
</script>
<template>
  <DasborSuperadmin v-if="sesi.isSuperadmin" />
  <DasborAdmin v-else-if="sesi.isAdmin" />
  <!-- Pimpinan tinggi (Direktur, Wadir, Yayasan, Kepala Bidang/Unit, Plt): beranda berstatistik; pegawai lain: beranda ringkas -->
  <DasborPegawai v-else-if="sesi.pimpinanTinggi" />
  <DasborFungsional v-else />
</template>
