<!-- SIMKA PRO | src/App.vue | v1.2 | Fase 4 – Perbaikan P3 (ikon PWA dari Pengaturan) | 05/10/2026 -->
<script setup>
// Ikon aplikasi (PWA Android/desktop, layar utama iOS, tab peramban) mengikuti "Ikon SIMKA PRO" dari Pengaturan.
import { watch } from 'vue'
import { useLembaga } from '@/stores/lembaga'
import { terapkanIkonPwa } from '@/lib/ikonPwa'
const lembaga = useLembaga()
lembaga.muatIdentitas()
watch(() => lembaga.identitas?.ikon_url, (url) => { if (url) terapkanIkonPwa(url) }, { immediate: true })
</script>
<template><router-view /></template>
