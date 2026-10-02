<script setup>
// Tombol aksi melayang (FAB) ala Android — hanya di layar kecil, di atas navigasi bawah.
defineProps({ label: String, ikon: Object, warna: { type: String, default: 'beranda' }, diperluas: { type: Boolean, default: true } })
defineEmits(['klik'])
</script>
<template>
  <button type="button" :class="['fab layar-saja fixed right-4 z-30 inline-flex items-center gap-2 font-bold text-white shadow-apung lg:hidden', 'w-' + warna, diperluas ? 'h-14 rounded-2xl px-5' : 'h-14 w-14 justify-center rounded-2xl']"
    :aria-label="label" @click="$emit('klik')">
    <component :is="ikon" :size="24" weight="bold" />
    <span v-if="diperluas">{{ label }}</span>
  </button>
</template>
<style scoped>
.fab { bottom: calc(84px + env(safe-area-inset-bottom)); background: linear-gradient(135deg, #9A2320, #C7332F); }
.fab:active { transform: scale(.97); }
</style>
