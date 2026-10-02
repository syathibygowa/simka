<script setup>
import { computed } from 'vue'
import { formatJam } from '@/lib/tanggal'
const props = defineProps({ waktu: Date })
const teks = computed(() => (props.waktu ? `Diperbarui ${formatJam(props.waktu, true)}` : 'Memuat…'))
</script>
<template>
  <span class="inline-flex items-center gap-2 text-xs font-semibold text-teks3" role="status">
    <span class="relative flex h-2.5 w-2.5" aria-hidden="true">
      <span class="denyut absolute inline-flex h-full w-full rounded-full bg-[#1E7D4F] opacity-60" />
      <span class="relative inline-flex h-2.5 w-2.5 rounded-full bg-[#1E7D4F] dark:bg-[#5BD69A]" />
    </span>
    Langsung – {{ teks }}
  </span>
</template>
<style scoped>
.denyut { animation: denyut 1.8s cubic-bezier(0,0,.2,1) infinite; }
@keyframes denyut { 75%, 100% { transform: scale(2.2); opacity: 0; } }
</style>
