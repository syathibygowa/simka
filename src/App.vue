<!-- SIMKA PRO | src/App.vue | v1.3 | Perbaikan darurat: pemasangan di HP Xiaomi/Redmi | 06/10/2026 -->
<script setup>
// Ikon tab peramban dan layar utama iOS mengikuti "Ikon SIMKA PRO" dari Pengaturan (manifest PWA tetap dari build).
import { watch } from 'vue'
import { useLembaga } from '@/stores/lembaga'
import { terapkanIkonPwa } from '@/lib/ikonPwa'
const lembaga = useLembaga()
lembaga.muatIdentitas()
watch(() => lembaga.identitas?.ikon_url, (url) => { if (url) terapkanIkonPwa(url) }, { immediate: true })
</script>
<template><router-view /></template>
