<!-- SIMKA PRO | src/components/grafik/GrafikBatang.vue | v1.0 | Fase 5 – Tahap 5 Laporan dan grafik tahfizh | 05/10/2026 -->
<script setup>
// Grafik batang (bisa bertumpuk) SVG tanpa pustaka. label: ['Jul', …]; seri: [{ n, warna, nilai: [..] }]
import { computed } from 'vue'
const props = defineProps({ label: { type: Array, required: true }, seri: { type: Array, required: true }, judul: String, sumbuY: { type: String, default: 'Jumlah santri' } })
const L = 760; const T = 300; const kiri = 44; const bawah = 34; const atas = 12
const total = computed(() => props.label.map((_, i) => props.seri.reduce((t, s) => t + Number(s.nilai[i] || 0), 0)))
const maks = computed(() => { const m = Math.max(1, ...total.value); const langkah = Math.pow(10, Math.floor(Math.log10(m))); return Math.ceil(m / langkah) * langkah })
const lebar = computed(() => (L - kiri - 8) / props.label.length)
const y = (v) => atas + (T - atas - bawah) * (1 - v / maks.value)
const garis = computed(() => Array.from({ length: 5 }, (_, i) => Math.round((maks.value / 4) * i)))
const batang = computed(() => props.label.map((lb, i) => {
  let dasar = 0
  return props.seri.map((s) => { const v = Number(s.nilai[i] || 0); const r = { x: kiri + i * lebar.value + lebar.value * 0.15, w: lebar.value * 0.7, y: y(dasar + v), h: y(dasar) - y(dasar + v), warna: s.warna, v, n: s.n, lb }; dasar += v; return r })
}))
</script>
<template>
  <figure class="grafik">
    <figcaption v-if="judul" class="mb-2 text-center font-bold">{{ judul }}</figcaption>
    <svg :viewBox="`0 0 ${L} ${T}`" class="w-full" role="img" :aria-label="judul || 'Grafik batang'">
      <g v-for="g in garis" :key="g"><line :x1="kiri" :x2="L - 4" :y1="y(g)" :y2="y(g)" class="garis" /><text :x="kiri - 6" :y="y(g) + 3.5" text-anchor="end" font-size="10" class="teks2">{{ g }}</text></g>
      <text :x="12" :y="T / 2" font-size="10" class="teks2" :transform="`rotate(-90 12 ${T / 2})`" text-anchor="middle">{{ sumbuY }}</text>
      <g v-for="(b, i) in batang" :key="i">
        <rect v-for="(s, j) in b" :key="j" :x="s.x" :y="s.y" :width="s.w" :height="Math.max(0, s.h)" :fill="s.warna" rx="2"><title>{{ s.lb }} · {{ s.n }}: {{ s.v }}</title></rect>
        <text v-if="total[i]" :x="b[0].x + b[0].w / 2" :y="y(total[i]) - 3" text-anchor="middle" font-size="9" font-weight="700" class="teks">{{ total[i] }}</text>
        <text :x="b[0].x + b[0].w / 2" :y="T - bawah + 13" text-anchor="middle" font-size="10" class="teks2">{{ label[i] }}</text>
      </g>
    </svg>
    <ul v-if="seri.length > 1" class="mt-1 flex flex-wrap justify-center gap-4 text-sm">
      <li v-for="s in seri" :key="s.n" class="flex items-center gap-1.5"><i class="inline-block h-3 w-3 rounded-sm" :style="{ background: s.warna }" />{{ s.n }} ({{ s.nilai.reduce((a, b) => a + Number(b || 0), 0) }})</li>
    </ul>
  </figure>
</template>
<style scoped>
.garis { stroke: rgb(var(--garis)); stroke-width: 1; } .teks { fill: rgb(var(--teks)); } .teks2 { fill: rgb(var(--teks-3)); }
:global(.dok) .garis { stroke: #bbb; } :global(.dok) .teks { fill: #000; } :global(.dok) .teks2 { fill: #333; }
</style>
