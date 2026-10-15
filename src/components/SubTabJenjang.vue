<!-- SIMKA PRO | src/components/SubTabJenjang.vue | v1.0 | Perbaikan 13.6.0: sub-tab jenjang Wustha (SMP) / SMA | 15/10/2026 -->
<script setup>
// Sub-tab jenjang bergaris bawah: (Semua) · Wustha (SMP) · SMA. Ikon berwarna sesuai warna jenjang.
// v-model: '' (semua) | 'wustha' | 'sma' · semua: tampilkan pilihan "Semua jenjang" · jumlah: { '': n, wustha: n, sma: n } opsional.
import { PhSquaresFour, PhBackpack, PhGraduationCap } from '@phosphor-icons/vue'
import { JENJANG_TAB } from '@/lib/jadwal'
const nilai = defineModel({ type: String, default: '' })
defineProps({ semua: { type: Boolean, default: true }, jumlah: { type: Object, default: null }, label: { type: String, default: 'Jenjang' } })
const IKON = { '': PhSquaresFour, wustha: PhBackpack, sma: PhGraduationCap }
</script>
<template>
  <nav class="bilah-tab kecil" role="tablist" :aria-label="label">
    <button v-for="j in [...(semua ? [{ k: '', n: 'Semua jenjang', w: 'beranda' }] : []), ...Object.entries(JENJANG_TAB).map(([k, v]) => ({ k, ...v }))]" :key="j.k"
      type="button" role="tab" :aria-selected="nilai === j.k" :class="['tab-garis', 'w-' + j.w, nilai === j.k && 'aktif']" @click="nilai = j.k">
      <component :is="IKON[j.k]" :size="18" weight="duotone" /><span>{{ j.n }}</span>
      <span v-if="jumlah && jumlah[j.k] != null" class="angka-tab">{{ jumlah[j.k] }}</span>
    </button>
  </nav>
</template>
