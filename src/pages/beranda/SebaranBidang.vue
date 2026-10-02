<script setup>
// Batang horizontal jumlah pegawai per bidang; setiap bidang dengan warna sendiri.
import { computed } from 'vue'
const props = defineProps({ data: { type: Array, default: () => [] } })
const WARNA = ['tahfizh', 'santri', 'pegawai', 'klinik', 'gaji', 'pengumuman', 'laporan', 'hakakses']
const maks = computed(() => Math.max(1, ...props.data.map((d) => d.jumlah)))
</script>
<template>
  <ul class="space-y-3">
    <li v-for="(d, i) in data" :key="d.bidang" :class="'w-' + WARNA[i % WARNA.length]">
      <div class="mb-1 flex justify-between gap-3 text-sm">
        <span class="font-semibold text-teks2">{{ d.bidang.replace('Bidang ', '') }}</span>
        <span class="font-bold tabular-nums text-teks">{{ d.jumlah }}</span>
      </div>
      <div class="h-2.5 overflow-hidden rounded-full bg-permukaan2" role="img" :aria-label="`${d.bidang}: ${d.jumlah} pegawai`">
        <div class="batang h-full rounded-full" :style="{ width: (d.jumlah / maks) * 100 + '%' }" />
      </div>
    </li>
  </ul>
</template>
<style scoped>.batang { background: linear-gradient(90deg, var(--c), var(--c2)); transition: width .6s ease; }</style>
