<!-- SIMKA PRO | src/components/grafik/GrafikDeret.vue | v1.0 | Perbaikan 13.7.0: grafik deret waktu (garis/batang/tumpuk) untuk beranda | 16/10/2026 -->
<script setup>
// Grafik deret waktu ringan (SVG, tanpa pustaka) dengan legenda, garis bantu tipis, dan tooltip saat disentuh/diarahkan.
// jenis: 'garis' (persentase/tren) · 'batang' (beberapa seri berdampingan) · 'tumpuk' (komposisi bertumpuk)
// seri: [{ n, nilai: [angka|null] }] — warna mengikuti urutan tetap (biru, jingga, hijau toska, kuning; tervalidasi
// buta warna untuk tema terang dan gelap). Satu sumbu Y saja.
import { computed, ref } from 'vue'

const props = defineProps({
  label: { type: Array, required: true },
  seri: { type: Array, required: true },
  jenis: { type: String, default: 'garis' },
  satuan: { type: String, default: '' },
  maks: { type: Number, default: 0 },
  judul: { type: String, default: 'Grafik' },
})
const L = 560; const T = 240; const kiri = 40; const kanan = 12; const atas = 16; const bawah = 28
const lebar = L - kiri - kanan; const tinggi = T - atas - bawah
const n = computed(() => props.label.length)
const total = (i) => props.seri.reduce((a, s) => a + (Number(s.nilai[i]) || 0), 0)
const puncak = computed(() => {
  if (props.maks) return props.maks
  const m = Math.max(1, ...props.label.map((_, i) => (props.jenis === 'tumpuk' ? total(i) : Math.max(0, ...props.seri.map((s) => Number(s.nilai[i]) || 0))))) * 1.1
  const dasar = Math.pow(10, Math.floor(Math.log10(m / 4)))
  const langkah = [1, 2, 2.5, 5, 10].map((f) => f * dasar).find((x) => x * 4 >= m) || 10 * dasar
  return Math.max(4, langkah * 4)
})
const lebarKolom = computed(() => lebar / Math.max(1, n.value))
const x = (i) => kiri + lebarKolom.value * i + lebarKolom.value / 2
const y = (v) => atas + tinggi * (1 - Math.min(Number(v) || 0, puncak.value) / puncak.value)
const kisi = computed(() => [0, 0.25, 0.5, 0.75, 1].map((f) => Math.round(puncak.value * f * 10) / 10))
// Label sumbu X: dijarangkan agar tidak bertumpuk
const langkahLabel = computed(() => Math.max(1, Math.ceil(n.value / 8)))
const tampilLabel = (i) => i % langkahLabel.value === 0 || i === n.value - 1

const jalur = (s) => {
  let d = ''; let putus = true
  s.nilai.forEach((v, i) => { if (v == null) { putus = true; return } d += `${putus ? 'M' : 'L'}${x(i)},${y(v)} `; putus = false })
  return d.trim()
}
const lebarBatang = computed(() => Math.max(2, Math.min(28, (lebarKolom.value * 0.7) / (props.jenis === 'batang' ? props.seri.length : 1))))
const batang = computed(() => props.label.map((_, i) => {
  if (props.jenis === 'tumpuk') {
    let dasar = 0
    return props.seri.map((s, k) => { const v = Number(s.nilai[i]) || 0; const r = { k, v, x: x(i) - lebarBatang.value / 2, y: y(dasar + v), h: Math.max(0, y(dasar) - y(dasar + v)) }; dasar += v; return r })
  }
  const lebarGrup = lebarBatang.value * props.seri.length + 2 * (props.seri.length - 1)
  return props.seri.map((s, k) => { const v = Number(s.nilai[i]) || 0; return { k, v, x: x(i) - lebarGrup / 2 + k * (lebarBatang.value + 2), y: y(v), h: Math.max(0, y(0) - y(v)) } })
}))
const teks = (v) => (v == null ? '–' : `${String(Math.round(v * 10) / 10).replace('.', ',')}${props.satuan}`)

// ---------- Tooltip ----------
const kotak = ref(null); const pilih = ref(null)
function arah(e) {
  const r = kotak.value?.getBoundingClientRect(); if (!r) return
  const px = ((e.clientX - r.left) / r.width) * L
  const i = Math.floor((px - kiri) / lebarKolom.value)
  pilih.value = i >= 0 && i < n.value ? i : null
}
const posTip = computed(() => (pilih.value == null ? 0 : (x(pilih.value) / L) * 100))
const terakhir = (s) => { for (let i = s.nilai.length - 1; i >= 0; i--) if (s.nilai[i] != null) return s.nilai[i]; return null }
const ringkas = computed(() => props.label.map((l, i) => `${l}: ${props.seri.map((s) => `${s.n} ${teks(s.nilai[i])}`).join(', ')}`).join('; '))
</script>
<template>
  <figure class="grafik-deret">
    <!-- Legenda (selalu ada bila lebih dari satu seri) -->
    <figcaption v-if="seri.length > 1" class="mb-2 flex flex-wrap gap-x-4 gap-y-1 text-xs text-teks2">
      <span v-for="(s, k) in seri" :key="s.n" class="inline-flex items-center gap-1.5"><span :class="['tanda', 's' + k, jenis === 'garis' && 'garis']" aria-hidden="true" />{{ s.n }}
        <b v-if="jenis === 'garis'" class="tabular-nums text-teks">{{ teks(terakhir(s)) }}</b></span>
    </figcaption>
    <div ref="kotak" class="relative" @pointermove="arah" @pointerleave="pilih = null" @pointerdown="arah">
      <svg :viewBox="`0 0 ${L} ${T}`" class="block w-full touch-pan-y" role="img" :aria-label="`${judul}. ${ringkas}`">
        <g v-for="g in kisi" :key="g">
          <line :x1="kiri" :x2="L - kanan" :y1="y(g)" :y2="y(g)" class="kisi" />
          <text :x="kiri - 6" :y="y(g) + 4" text-anchor="end" class="sumbu">{{ g }}{{ satuan === '%' ? '%' : '' }}</text>
        </g>
        <template v-for="(lb, i) in label" :key="'l' + i"><text v-if="tampilLabel(i)" :x="x(i)" :y="T - 8" text-anchor="middle" class="sumbu">{{ lb }}</text></template>
        <line v-if="pilih != null" :x1="x(pilih)" :x2="x(pilih)" :y1="atas" :y2="atas + tinggi" class="silang" />
        <template v-if="jenis === 'garis'">
          <path v-for="(s, k) in seri" :key="'g' + k" :d="jalur(s)" :class="['garis-seri', 's' + k]" fill="none" />
          <template v-for="(s, k) in seri" :key="'t' + k">
            <template v-for="(v, i) in s.nilai" :key="i">
              <circle v-if="v != null && (pilih === i || i === s.nilai.length - 1 || s.nilai.filter((z) => z != null).length === 1)" :cx="x(i)" :cy="y(v)" r="4.5" :class="['titik', 's' + k]" />
            </template>
          </template>
        </template>
        <template v-else>
          <g v-for="(b, i) in batang" :key="'b' + i" :class="pilih != null && pilih !== i && 'redup'">
            <rect v-for="r in b.filter((q) => q.h > 0)" :key="r.k" :x="r.x" :y="r.y" :width="lebarBatang" :height="r.h" :rx="jenis === 'tumpuk' ? 1.5 : 3" :class="['batang', 's' + r.k]" />
          </g>
        </template>
      </svg>
      <!-- Tooltip -->
      <div v-if="pilih != null" class="tip" :style="{ left: `clamp(0px, calc(${posTip}% - 80px), calc(100% - 160px))` }" role="status">
        <p class="mb-1 font-bold">{{ label[pilih] }}</p>
        <p v-for="(s, k) in seri" :key="k" class="flex items-center gap-1.5"><span :class="['tanda', 's' + k]" aria-hidden="true" /><span class="flex-1">{{ s.n }}</span><b class="tabular-nums">{{ teks(s.nilai[pilih]) }}</b></p>
        <p v-if="jenis === 'tumpuk'" class="mt-1 border-t border-garis pt-1 text-teks3">Jumlah <b class="tabular-nums text-teks">{{ teks(total(pilih)) }}</b></p>
      </div>
    </div>
  </figure>
</template>
<style scoped>
/* Palet seri tervalidasi (validate_palette): terang dan gelap masing-masing lulus pemeriksaan buta warna */
.grafik-deret { --s0: #2a78d6; --s1: #eb6834; --s2: #1baf7a; --s3: #eda100; }
:global(.dark) .grafik-deret { --s0: #3987e5; --s1: #d95926; --s2: #199e70; --s3: #c98500; }
.s0 { --w: var(--s0); } .s1 { --w: var(--s1); } .s2 { --w: var(--s2); } .s3 { --w: var(--s3); }
.kisi { stroke: rgb(var(--garis)); stroke-width: 1; }
.sumbu { fill: rgb(var(--teks-3)); font-size: 12px; font-weight: 600; }
.silang { stroke: rgb(var(--teks-3)); stroke-width: 1; stroke-dasharray: 3 3; }
.garis-seri { stroke: var(--w); stroke-width: 2.25; stroke-linejoin: round; stroke-linecap: round; }
.titik { fill: var(--w); stroke: rgb(var(--permukaan)); stroke-width: 2; }
.batang { fill: var(--w); stroke: rgb(var(--permukaan)); stroke-width: 1; }
.redup { opacity: .45; }
.tanda { display: inline-block; width: 10px; height: 10px; border-radius: 3px; background: var(--w); flex-shrink: 0; }
.tanda.garis { height: 3px; width: 14px; border-radius: 2px; }
.tip { position: absolute; top: 4px; width: 160px; padding: .5rem .625rem; border-radius: .75rem; font-size: .75rem; color: rgb(var(--teks));
  background: rgb(var(--permukaan)); border: 1px solid rgb(var(--garis)); box-shadow: 0 8px 24px rgba(0, 0, 0, .14); pointer-events: none; }
</style>
