<!-- SIMKA PRO | src/components/TombolPantauan.vue | v1.1 | Fase 8 – Perbaikan: tombol ringkas tanpa teks keterangan | 10/10/2026 -->
<script setup>
// Tombol menonjol di Beranda untuk membuka Layar Pantauan (slide presentasi/SmartTV).
// Tampil bagi admin, superadmin, jabatan struktural (pimpinan, termasuk Direktur/Wadir), dan pemegang hak pantauan (yayasan).
import { computed } from 'vue'
import { PhPresentationChart, PhArrowRight } from '@phosphor-icons/vue'
import { useSesi } from '@/stores/sesi'
const sesi = useSesi()
const boleh = computed(() => sesi.isAdmin || sesi.ciriMenu.struktural || Number(sesi.ciriMenu.fitur?.pantauan ?? 0) >= 1)
</script>
<template>
  <router-link v-if="boleh" to="/pantauan" class="tombol-layar group relative flex items-center gap-3 overflow-hidden rounded-2xl px-4 py-3 text-white" aria-label="Buka Layar Pantauan">
    <span class="grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-white/20"><PhPresentationChart :size="28" weight="duotone" /></span>
    <span class="min-w-0 flex-1">
      <span class="flex items-center gap-2 text-lg font-extrabold leading-tight sm:text-xl">Layar Pantauan
        <span class="inline-flex items-center gap-1 rounded-full bg-white/25 px-2 py-0.5 text-[11px] font-bold"><span class="h-2 w-2 animate-pulse rounded-full bg-[#7DFFB0]" /> LANGSUNG</span></span>
    </span>
    <PhArrowRight :size="26" weight="bold" class="shrink-0 transition-transform group-hover:translate-x-1" />
  </router-link>
</template>
<style scoped>
.tombol-layar { background: linear-gradient(120deg, #24498A 0%, #2F5FA8 35%, #127A7A 70%, #1E7D4F 100%); box-shadow: 0 14px 30px -16px rgba(36, 73, 138, .8); }
.tombol-layar:hover { filter: brightness(1.06); }
</style>
