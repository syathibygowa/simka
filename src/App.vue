<!-- SIMKA PRO | src/App.vue | v1.4 | Perbaikan 13.5.0: logo dan nama pondok untuk layar pembuka | 15/10/2026 -->
<script setup>
// Ikon tab peramban dan layar utama iOS mengikuti "Ikon SIMKA PRO" dari Pengaturan (manifest PWA tetap dari build).
import { watch } from 'vue'
import { useLembaga } from '@/stores/lembaga'
import { terapkanIkonPwa } from '@/lib/ikonPwa'
import { alamatAset } from '@/lib/penyimpanan'
const lembaga = useLembaga()
lembaga.muatIdentitas()
watch(() => lembaga.identitas?.ikon_url, (url) => { if (url) terapkanIkonPwa(url) }, { immediate: true })
// Layar pembuka (index.html) memakai logo dan nama lengkap pondok yang tersimpan dari kunjungan sebelumnya.
watch(() => [lembaga.identitas?.nama_lengkap, lembaga.identitas?.logo_url], ([nama, logo]) => {
  if (!nama && !logo) return
  try { localStorage.setItem('simka.pembuka', JSON.stringify({ nama: nama || '', logo: logo ? alamatAset(logo) : '' })) } catch { /* penyimpanan peramban tidak tersedia */ }
}, { immediate: true })
</script>
<template><router-view /></template>
