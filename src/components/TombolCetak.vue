<script setup>
import { PhPrinter } from '@phosphor-icons/vue'
defineProps({ ringkas: Boolean, label: { type: String, default: 'Cetak' } })
const cetak = () => window.print()
</script>
<template>
  <button v-if="ringkas" type="button" class="tombol-ikon w-laporan" style="color: var(--c)" @click="cetak" :aria-label="label" :title="label">
    <PhPrinter :size="24" weight="duotone" />
  </button>
  <button v-else type="button" class="tombol-garis w-laporan" @click="cetak">
    <PhPrinter :size="20" weight="duotone" style="color: var(--c)" /> {{ label }}
  </button>
</template>
