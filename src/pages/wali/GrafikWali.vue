<!-- SIMKA PRO | src/pages/wali/GrafikWali.vue | v1.0 | Perbaikan 13.5.0: grafik tren kehadiran dan hafalan Portal Wali | 15/10/2026 -->
<script setup>
// Grafik SVG ringan tanpa pustaka untuk Portal Wali. Warna mengikuti kelas .w-* pada pembungkus (var(--c)).
// jenis 'garis': garis + area bergradasi (cocok untuk persentase); 'batang': batang membulat, opsional penanda target (garis putus-putus).
// titik: [{ label, nilai (null = belum ada data), target?, ket? }]
import { computed, useId } from 'vue'
const props = defineProps({
  titik: { type: Array, required: true },
  jenis: { type: String, default: 'garis' },
  satuan: { type: String, default: '' },
  maks: { type: Number, default: 0 },          // 0 = otomatis
  judul: { type: String, default: 'Grafik' },
})
const id = useId()
const L = 420; const T = 220; const kiri = 46; const kanan = 10; const atas = 28; const bawah = 30
const lebarArea = L - kiri - kanan; const tinggiArea = T - atas - bawah
// Puncak sumbu Y = 4 × langkah "bulat" (1, 2, 5, 10, 20, 25, 50, …) agar garis bantu berangka bulat.
const puncak = computed(() => {
  if (props.maks) return props.maks
  const m = Math.max(1, ...props.titik.map((t) => Math.max(Number(t.nilai) || 0, Number(t.target) || 0))) * 1.12
  const dasar = Math.pow(10, Math.floor(Math.log10(m / 4)))
  const langkah = [1, 2, 2.5, 5, 10].map((f) => f * dasar).find((x) => x * 4 >= m) || 10 * dasar
  return Math.max(4, langkah * 4)
})
const langkahX = computed(() => lebarArea / Math.max(1, props.titik.length))
const x = (i) => kiri + langkahX.value * i + langkahX.value / 2
const y = (v) => atas + tinggiArea * (1 - Math.min(Number(v) || 0, puncak.value) / puncak.value)
const kisi = computed(() => [0, 0.25, 0.5, 0.75, 1].map((f) => Math.round(puncak.value * f * 10) / 10))
const ada = computed(() => props.titik.map((t, i) => ({ ...t, i })).filter((t) => t.nilai != null))
const jalurGaris = computed(() => ada.value.map((t, j) => `${j ? 'L' : 'M'}${x(t.i)},${y(t.nilai)}`).join(' '))
const jalurArea = computed(() => {
  if (ada.value.length < 2) return ''
  const a = ada.value[0]; const z = ada.value[ada.value.length - 1]
  return `${jalurGaris.value} L${x(z.i)},${atas + tinggiArea} L${x(a.i)},${atas + tinggiArea} Z`
})
const lebarBatang = computed(() => Math.min(40, langkahX.value * 0.56))
const teks = (v) => (v == null ? '–' : `${String(Math.round(v * 10) / 10).replace('.', ',')}${props.satuan}`)
const ringkasan = computed(() => props.titik.map((t) => `${t.label}: ${teks(t.nilai)}`).join(', '))
</script>
<template>
  <figure class="grafik-wali">
    <svg :viewBox="`0 0 ${L} ${T}`" class="block w-full" role="img" :aria-label="`${judul}. ${ringkasan}`">
      <defs>
        <linearGradient :id="'area' + id" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" style="stop-color: var(--c); stop-opacity: .32" /><stop offset="100%" style="stop-color: var(--c); stop-opacity: 0" />
        </linearGradient>
        <linearGradient :id="'batang' + id" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" style="stop-color: var(--c)" /><stop offset="100%" style="stop-color: var(--c2, var(--c)); stop-opacity: .8" />
        </linearGradient>
      </defs>
      <g v-for="g in kisi" :key="g">
        <line :x1="kiri" :x2="L - kanan" :y1="y(g)" :y2="y(g)" class="kisi" />
        <text :x="kiri - 8" :y="y(g) + 4" text-anchor="end" class="sumbu">{{ g }}{{ satuan === '%' ? '%' : '' }}</text>
      </g>
      <text v-for="(t, i) in titik" :key="'l' + i" :x="x(i)" :y="T - 8" text-anchor="middle" :class="['sumbu', i === titik.length - 1 && 'kini']">{{ t.label }}</text>

      <template v-if="jenis === 'garis'">
        <path v-if="jalurArea" :d="jalurArea" :fill="`url(#area${id})`" />
        <path v-if="ada.length > 1" :d="jalurGaris" fill="none" style="stroke: var(--c)" stroke-width="2.75" stroke-linecap="round" stroke-linejoin="round" />
        <g v-for="t in ada" :key="'p' + t.i">
          <circle :cx="x(t.i)" :cy="y(t.nilai)" r="5" class="titik" stroke-width="3"><title>{{ t.label }}: {{ teks(t.nilai) }}{{ t.ket ? ' · ' + t.ket : '' }}</title></circle>
          <text :x="x(t.i)" :y="y(t.nilai) - 12" text-anchor="middle" class="nilai">{{ teks(t.nilai) }}</text>
        </g>
      </template>

      <template v-else>
        <g v-for="(t, i) in titik" :key="'b' + i">
          <rect :x="x(i) - lebarBatang / 2" :y="atas" :width="lebarBatang" :height="tinggiArea" rx="10" class="lajur" />
          <rect v-if="t.nilai" :x="x(i) - lebarBatang / 2" :y="y(t.nilai)" :width="lebarBatang" :height="Math.max(4, atas + tinggiArea - y(t.nilai))" rx="10" :fill="`url(#batang${id})`">
            <title>{{ t.label }}: {{ teks(t.nilai) }}{{ t.ket ? ' · ' + t.ket : '' }}</title></rect>
          <line v-if="t.target" :x1="x(i) - lebarBatang / 2 - 5" :x2="x(i) + lebarBatang / 2 + 5" :y1="y(t.target)" :y2="y(t.target)" class="target"><title>Target {{ teks(t.target) }}</title></line>
          <text :x="x(i)" :y="(t.nilai ? y(t.nilai) : atas + tinggiArea) - 8" text-anchor="middle" class="nilai">{{ t.nilai ? teks(t.nilai) : '' }}</text>
        </g>
      </template>
    </svg>
  </figure>
</template>
<style scoped>
.kisi { stroke: rgb(var(--garis)); stroke-width: 1; stroke-dasharray: 3 5; }
.sumbu { fill: rgb(var(--teks-3)); font-size: 12px; font-weight: 600; }
.sumbu.kini { fill: rgb(var(--teks)); font-weight: 800; }
.nilai { fill: rgb(var(--teks)); font-size: 12.5px; font-weight: 800; }
.titik { fill: rgb(var(--permukaan)); stroke: var(--c); }
.lajur { fill: rgb(var(--permukaan-2)); }
.target { stroke: rgb(var(--teks-2)); stroke-width: 2.5; stroke-dasharray: 5 4; stroke-linecap: round; }
</style>
