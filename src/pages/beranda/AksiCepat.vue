<script setup>
// Isi bottom sheet "Aksi cepat" (dari FAB) dan panel akses cepat desktop.
defineProps({ daftar: Array, kisi: Boolean })
defineEmits(['pilih'])
</script>
<template>
  <ul :class="kisi ? 'grid grid-cols-2 gap-2 sm:grid-cols-4' : 'space-y-1 pb-2'">
    <li v-for="a in daftar" :key="a.label" :class="'w-' + a.warna">
      <router-link :to="a.ke" @click="$emit('pilih')"
        :class="['flex items-center gap-3 rounded-2xl font-semibold hover:bg-permukaan2', kisi ? 'flex-col border border-garis p-4 text-center text-sm' : 'min-h-[56px] px-2']">
        <span class="chip-ikon h-11 w-11"><component :is="a.ikon" :size="24" weight="duotone" /></span>
        <span class="flex-1">
          <span class="block">{{ a.label }}</span>
          <span v-if="a.ket && !kisi" class="block text-sm font-normal text-teks3">{{ a.ket }}</span>
        </span>
      </router-link>
    </li>
  </ul>
</template>
