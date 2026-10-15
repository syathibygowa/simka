<!-- SIMKA PRO | src/components/BilahTab.vue | v2.0 | Perbaikan 13.5.0: desain tab bergaris bawah (ikon berwarna, aktif merah bergaris tebal) | 15/10/2026 -->
<script setup>
// Bilah tab seragam untuk semua menu: garis tipis di bawah, ikon berwarna per tab (kelas .w-*), label abu-abu;
// tab aktif berlabel merah dengan garis bawah merah tebal. Menggulung mendatar bila tidak muat.
// tab: [{ k, n, ikon, w, jumlah?, lencana?, ket? }] · v-model = kunci tab aktif · kecil = gaya sub-tab.
const aktif = defineModel({ type: String, default: '' })
defineProps({
  tab: { type: Array, required: true },
  label: { type: String, default: 'Bagian halaman' },
  tepi: { type: Boolean, default: true },
  kecil: { type: Boolean, default: false },
})
</script>
<template>
  <nav :class="['bilah-tab', kecil && 'kecil', tepi ? '-mx-4 px-4 lg:mx-0 lg:px-0' : '']" role="tablist" :aria-label="label">
    <button v-for="t in tab" :key="t.k" type="button" role="tab" :aria-selected="aktif === t.k" @click="aktif = t.k"
      :class="['tab-garis', 'w-' + (t.w || 'beranda'), aktif === t.k && 'aktif']">
      <component :is="t.ikon" v-if="t.ikon" :size="kecil ? 18 : 20" weight="duotone" />
      <span>{{ t.n }}</span>
      <span v-if="t.jumlah != null" class="angka-tab">{{ t.jumlah }}</span>
      <span v-if="t.lencana" class="lencana-tab">{{ t.lencana }}</span>
      <span v-if="t.ket" class="text-xs font-normal text-teks3">{{ t.ket }}</span>
    </button>
  </nav>
</template>
