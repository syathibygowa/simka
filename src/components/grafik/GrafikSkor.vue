<!-- SIMKA PRO | src/components/grafik/GrafikSkor.vue | v1.0 | 14.18.0: grafik batang mendatar skor 0–100 (indikator kinerja bidang) | 21/10/2026 -->
<script setup>
// Grafik batang mendatar SVG tanpa pustaka untuk nilai 0–100 dengan garis ambang predikat (70, 80, 90).
// data: [{ n: 'Bidang Tahfizh', v: 86.4, warna: '#2F5FA8', ket: 'Baik', id }]; baris dapat diketuk (emit pilih).
import { computed } from 'vue'
const props = defineProps({ data: { type: Array, required: true }, judul: String, ambang: { type: Array, default: () => [70, 80, 90] }, bisa: Boolean })
const emit = defineEmits(['pilih'])
const L = 760; const kiri = 220; const kanan = 118; const tinggiBaris = 34; const atas = 22
const T = computed(() => atas + props.data.length * tinggiBaris + 8)
const x = (v) => kiri + ((L - kiri - kanan) * Math.max(0, Math.min(100, v || 0))) / 100
const pendek = (s) => (s.length > 30 ? s.slice(0, 29) + '…' : s)
const angka = (v) => (v == null ? '–' : String(v).replace('.', ','))
</script>
<template>
  <figure class="grafik">
    <figcaption v-if="judul" class="mb-2 text-center font-bold">{{ judul }}</figcaption>
    <svg :viewBox="`0 0 ${L} ${T}`" class="w-full" role="img" :aria-label="judul || 'Grafik skor'">
      <g v-for="g in [0, ...ambang, 100]" :key="g">
        <line :x1="x(g)" :x2="x(g)" :y1="atas - 6" :y2="T - 6" :class="g === 0 || g === 100 ? 'garis' : 'ambang'" />
        <text :x="x(g)" :y="atas - 10" text-anchor="middle" font-size="10" class="teks2">{{ g }}</text>
      </g>
      <g v-for="(d, i) in data" :key="d.id ?? d.n" :class="bisa && 'baris'" :role="bisa ? 'button' : undefined" :tabindex="bisa ? 0 : undefined"
        :aria-label="bisa ? `${d.n}: ${angka(d.v)}. Lihat rincian` : undefined" @click="bisa && emit('pilih', d)" @keydown.enter="bisa && emit('pilih', d)">
        <rect v-if="bisa" :x="0" :y="atas + i * tinggiBaris" :width="L" :height="tinggiBaris" fill="transparent" />
        <text :x="kiri - 10" :y="atas + i * tinggiBaris + tinggiBaris / 2 + 4" text-anchor="end" font-size="13" font-weight="600" class="teks">{{ pendek(d.n) }}<title>{{ d.n }}</title></text>
        <rect :x="kiri" :y="atas + i * tinggiBaris + 7" :width="L - kiri - kanan" :height="tinggiBaris - 14" rx="4" class="jalur" />
        <rect :x="kiri" :y="atas + i * tinggiBaris + 7" :width="Math.max(0, x(d.v) - kiri)" :height="tinggiBaris - 14" rx="4" :fill="d.warna" />
        <text :x="L - kanan + 8" :y="atas + i * tinggiBaris + tinggiBaris / 2 + 4" font-size="13" font-weight="800" class="teks">{{ angka(d.v) }}<tspan v-if="d.ket" dx="5" font-weight="500" font-size="11" class="teks2">{{ d.ket }}</tspan></text>
      </g>
    </svg>
  </figure>
</template>
<style scoped>
.garis { stroke: rgb(var(--garis)); stroke-width: 1; } .ambang { stroke: rgb(var(--teks-3)); stroke-width: 1; stroke-dasharray: 4 4; opacity: .7; }
.jalur { fill: rgb(var(--permukaan-2)); }
.teks { fill: rgb(var(--teks)); } .teks2 { fill: rgb(var(--teks-2)); }
.baris { cursor: pointer; outline: none; } .baris:hover rect:first-child, .baris:focus-visible rect:first-child { fill: rgb(var(--garis) / .35); }
:global(.dok) .garis { stroke: #bbb; } :global(.dok) .ambang { stroke: #888; } :global(.dok) .jalur { fill: #eee; } :global(.dok) .teks { fill: #000; } :global(.dok) .teks2 { fill: #333; }
</style>
