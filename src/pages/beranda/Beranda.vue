<script setup>
import { onMounted, onBeforeUnmount } from 'vue'
import { useSesi } from '@/stores/sesi'
import { useStatistik } from '@/stores/statistik'
import DasborSuperadmin from './DasborSuperadmin.vue'
import DasborAdmin from './DasborAdmin.vue'
import DasborPegawai from './DasborPegawai.vue'
const sesi = useSesi(); const stat = useStatistik()
onMounted(() => { if (sesi.isAdmin) stat.mulai() })
onBeforeUnmount(() => stat.berhenti())
</script>
<template>
  <DasborSuperadmin v-if="sesi.isSuperadmin" />
  <DasborAdmin v-else-if="sesi.isAdmin" />
  <DasborPegawai v-else />
</template>
