<script setup>
import { useSesi } from '@/stores/sesi'
defineProps({ size: { type: Number, default: 40 } })
const sesi = useSesi()
</script>
<template>
  <span class="avatar grid shrink-0 place-items-center rounded-full font-bold text-white" :style="{ width: size + 'px', height: size + 'px', fontSize: size * 0.38 + 'px' }" aria-hidden="true">
    {{ sesi.inisial }}
  </span>
</template>
<style scoped>.avatar { background: linear-gradient(135deg, #8E1C19, #C7332F); }</style>
