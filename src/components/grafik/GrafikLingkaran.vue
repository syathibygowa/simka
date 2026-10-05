<!-- SIMKA PRO | src/components/grafik/GrafikLingkaran.vue | v1.0 | Fase 5 – Tahap 5 Laporan dan grafik tahfizh | 05/10/2026 -->
<script setup>
// Grafik lingkaran (donat) SVG tanpa pustaka: tampil di layar maupun cetak. data: [{ n, nilai, warna }]
import { computed } from 'vue'
const props = defineProps({ data: { type: Array, required: true }, judul: String, satuan: { type: String, default: 'santri' } })
const total = computed(() => props.data.reduce((t, d) => t + Number(d.nilai || 0), 0))
const irisan = computed(() => {
  let sudut = -Math.PI / 2
  return props.data.filter((d) => d.nilai > 0).map((d) => {
    const besar = (d.nilai / (total.value || 1)) * Math.PI * 2; const a0 = sudut; const a1 = sudut + besar; sudut = a1
    const R = 90; const r = 52; const p = (a, rr) => [100 + rr * Math.cos(a), 100 + rr * Math.sin(a)]
    const [x0, y0] = p(a0, R); const [x1, y1] = p(a1 - 0.0001, R); const [x2, y2] = p(a1 - 0.0001, r); const [x3, y3] = p(a0, r)
    const besarB = besar > Math.PI ? 1 : 0
    const tengah = (a0 + a1) / 2; const [lx, ly] = p(tengah, (R + r) / 2)
    return { ...d, path: `M${x0},${y0} A${R},${R} 0 ${besarB} 1 ${x1},${y1} L${x2},${y2} A${r},${r} 0 ${besarB} 0 ${x3},${y3} Z`, lx, ly, persen: Math.round((d.nilai / (total.value || 1)) * 1000) / 10 }
  })
})
</script>
<template>
  <figure class="grafik">
    <figcaption v-if="judul" class="mb-2 text-center font-bold">{{ judul }}</figcaption>
    <div class="flex flex-wrap items-center justify-center gap-6">
      <svg viewBox="0 0 200 200" class="h-56 w-56 shrink-0" role="img" :aria-label="`${judul || 'Grafik'}: ` + data.map((d) => `${d.n} ${d.nilai}`).join(', ')">
        <path v-for="s in irisan" :key="s.n" :d="s.path" :fill="s.warna" stroke="#fff" stroke-width="1.5" />
        <text v-for="s in irisan.filter((x) => x.persen >= 6)" :key="'t' + s.n" :x="s.lx" :y="s.ly + 3.5" text-anchor="middle" font-size="10" font-weight="700" fill="#fff">{{ s.nilai }}</text>
        <text x="100" y="96" text-anchor="middle" font-size="22" font-weight="800" class="isi-teks">{{ total }}</text>
        <text x="100" y="113" text-anchor="middle" font-size="10" class="isi-teks2">{{ satuan }}</text>
      </svg>
      <ul class="min-w-[200px] space-y-1 text-sm">
        <li v-for="d in data" :key="d.n" class="flex items-center gap-2">
          <i class="inline-block h-3 w-3 shrink-0 rounded-sm" :style="{ background: d.warna }" /><span class="flex-1">{{ d.n }}</span>
          <b class="tabular-nums">{{ d.nilai }}</b><span class="w-14 text-right tabular-nums text-teks3">{{ (total ? Math.round((d.nilai / total) * 1000) / 10 : 0).toLocaleString('id-ID') }}%</span>
        </li>
      </ul>
    </div>
  </figure>
</template>
<style scoped>
.isi-teks { fill: rgb(var(--teks)); } .isi-teks2 { fill: rgb(var(--teks-3)); }
:global(.dok) .isi-teks { fill: #000; } :global(.dok) .isi-teks2 { fill: #444; }
</style>
