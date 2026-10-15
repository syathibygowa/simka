<!-- SIMKA PRO | src/components/TombolCetak.vue | v1.1 | Perbaikan: nama berkas PDF dari judul halaman dan bulan cetak | 16/10/2026 -->
<script setup>
// Tombol cetak halaman. Nama berkas PDF: "<Judul halaman> - <bulan>" (dokumen cetak di halaman dapat memasang nama sendiri).
import { useRoute } from 'vue-router'
import { PhPrinter } from '@phosphor-icons/vue'
import { namaBerkas, periodeBulan, pasangJudul, lepasJudul } from '@/lib/namaBerkas'
defineProps({ ringkas: Boolean, label: { type: String, default: 'Cetak' } })
const route = useRoute()
const cetak = () => { pasangJudul(namaBerkas(route.meta?.judul || 'SIMKA PRO', periodeBulan())); window.print(); setTimeout(lepasJudul, 1000) }
</script>
<template>
  <button v-if="ringkas" type="button" class="tombol-ikon w-laporan" style="color: var(--c)" @click="cetak" :aria-label="label" :title="label">
    <PhPrinter :size="24" weight="duotone" />
  </button>
  <button v-else type="button" class="tombol-garis w-laporan" @click="cetak">
    <PhPrinter :size="20" weight="duotone" style="color: var(--c)" /> {{ label }}
  </button>
</template>
