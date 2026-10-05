<!-- SIMKA PRO | src/components/BilahTab.vue | v1.0 | Fase 5 – Perbaikan tampilan tab seragam | 05/10/2026 -->
<script setup>
// Bilah tab seragam untuk semua menu: kotak sudut membulat, terpisah, ikon dalam chip berwarna (warna berbeda per tab),
// angka jumlah (abu-abu) atau lencana merah (perlu tindakan). Menggulung mendatar di HP.
// tab: [{ k, n, ikon, w, jumlah?, lencana? }] · v-model = kunci tab aktif.
const aktif = defineModel({ type: String, default: '' })
defineProps({ tab: { type: Array, required: true }, label: { type: String, default: 'Bagian halaman' }, tepi: { type: Boolean, default: true } })
</script>
<template>
  <nav :class="['flex gap-2 overflow-x-auto pb-1', tepi ? '-mx-4 px-4 lg:mx-0 lg:px-0' : '']" role="tablist" :aria-label="label">
    <button v-for="t in tab" :key="t.k" type="button" role="tab" :aria-selected="aktif === t.k" @click="aktif = t.k"
      :class="['tab flex min-h-[44px] shrink-0 items-center gap-2.5 rounded-xl border px-3 text-sm font-semibold', 'w-' + (t.w || 'beranda'),
               aktif === t.k ? 'aktif text-teks' : 'border-garis bg-permukaan text-teks2 hover:text-teks']">
      <span v-if="t.ikon" class="chip-ikon h-8 w-8 rounded-lg"><component :is="t.ikon" :size="20" weight="duotone" /></span>
      <span class="whitespace-nowrap">{{ t.n }}</span>
      <span v-if="t.jumlah != null" class="rounded-full bg-permukaan2 px-2 text-xs font-bold tabular-nums">{{ t.jumlah }}</span>
      <span v-if="t.lencana" class="grid h-6 min-w-[1.5rem] place-items-center rounded-full bg-[#C7332F] px-1.5 text-xs font-bold text-white">{{ t.lencana }}</span>
      <span v-if="t.ket" class="text-xs font-normal text-teks3">{{ t.ket }}</span>
    </button>
  </nav>
</template>
<style scoped>
.tab.aktif { border-color: color-mix(in srgb, var(--c) 35%, transparent); background: color-mix(in srgb, var(--c) 12%, rgb(var(--permukaan))); }
</style>
