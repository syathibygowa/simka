<!-- SIMKA PRO | src/components/SliderStatistik.vue | v1.0 | Fase 8 – Perbaikan beranda pimpinan: statistik bergeser per kelompok | 10/10/2026 -->
<script setup>
// Kelompok kartu statistik beranda ditampilkan satu per satu (slider), bukan menumpuk ke bawah.
// Pindah kelompok: ketuk chip nama kelompok, tombol panah kiri/kanan, geser layar (HP), atau tombol panah papan ketik.
// Semua kelompok tetap dimuat (tetap langsung/Realtime); kelompok yang kosong (tidak ada hak atau data) disembunyikan.
// Kelompok terakhir yang dibuka diingat di perangkat.
import { ref, computed, onMounted, onBeforeUnmount, nextTick, watch } from 'vue'
import { PhCaretLeft, PhCaretRight } from '@phosphor-icons/vue'

const props = defineProps({ panel: { type: Array, required: true }, simpan: { type: String, default: 'simka.beranda.panel' } })
const baca = () => { try { return localStorage.getItem(props.simpan) } catch { return null } }
const tulis = (v) => { try { localStorage.setItem(props.simpan, v) } catch { /* penyimpanan peramban tidak tersedia */ } }

const wadah = ref({}); const kosong = ref({})
const terlihat = computed(() => props.panel.filter((p) => !kosong.value[p.k]))
const aktif = ref(baca() || props.panel[0]?.k)
const indeks = computed(() => Math.max(0, terlihat.value.findIndex((p) => p.k === aktif.value)))
watch(terlihat, (t) => { if (t.length && !t.some((p) => p.k === aktif.value)) aktif.value = t[0].k })
function ke(i) {
  const t = terlihat.value; if (!t.length) return
  aktif.value = t[(i + t.length) % t.length].k; tulis(aktif.value)
  nextTick(() => document.getElementById('chip-' + aktif.value)?.scrollIntoView({ inline: 'center', block: 'nearest', behavior: 'smooth' }))
}
const pilih = (k) => ke(terlihat.value.findIndex((p) => p.k === k))

// Kelompok kosong: komponen tidak menghasilkan elemen apa pun
function periksa() {
  const k = {}; for (const p of props.panel) { const el = wadah.value[p.k]; k[p.k] = !!el && el.childElementCount === 0 }
  kosong.value = k
}
let pengamat
onMounted(() => {
  periksa()
  pengamat = new MutationObserver(periksa)
  for (const p of props.panel) if (wadah.value[p.k]) pengamat.observe(wadah.value[p.k], { childList: true })
})
onBeforeUnmount(() => pengamat?.disconnect())

// Geser layar di HP
let x0 = null; let y0 = null
const mulai = (e) => { x0 = e.touches[0].clientX; y0 = e.touches[0].clientY }
const akhir = (e) => {
  if (x0 == null) return
  const dx = e.changedTouches[0].clientX - x0; const dy = e.changedTouches[0].clientY - y0; x0 = null
  if (Math.abs(dx) > 60 && Math.abs(dx) > Math.abs(dy) * 1.5) ke(indeks.value + (dx < 0 ? 1 : -1))
}
const tombol = (e) => { if (e.key === 'ArrowRight') ke(indeks.value + 1); else if (e.key === 'ArrowLeft') ke(indeks.value - 1) }
</script>
<template>
  <section class="space-y-3" aria-roledescription="slider" aria-label="Statistik beranda">
    <div v-show="terlihat.length > 1" class="flex items-center gap-2" @keydown="tombol">
      <button type="button" class="tombol-ikon shrink-0 border border-garis bg-permukaan" aria-label="Kelompok statistik sebelumnya" @click="ke(indeks - 1)"><PhCaretLeft :size="20" weight="bold" /></button>
      <nav class="flex min-w-0 flex-1 gap-2 overflow-x-auto py-0.5" role="tablist" aria-label="Kelompok statistik">
        <button v-for="p in terlihat" :id="'chip-' + p.k" :key="p.k" type="button" role="tab" :aria-selected="aktif === p.k" @click="pilih(p.k)"
          :class="['chip flex min-h-[40px] shrink-0 items-center gap-2 rounded-xl border px-2.5 text-sm font-semibold', 'w-' + p.w, aktif === p.k ? 'aktif text-teks' : 'border-garis bg-permukaan text-teks2 hover:text-teks']">
          <span class="chip-ikon h-7 w-7 rounded-lg"><component :is="p.ikon" :size="17" weight="duotone" /></span>
          <span class="whitespace-nowrap">{{ p.n }}</span>
        </button>
      </nav>
      <span class="hidden shrink-0 text-xs font-semibold tabular-nums text-teks3 sm:inline">{{ indeks + 1 }}/{{ terlihat.length }}</span>
      <button type="button" class="tombol-ikon shrink-0 border border-garis bg-permukaan" aria-label="Kelompok statistik berikutnya" @click="ke(indeks + 1)"><PhCaretRight :size="20" weight="bold" /></button>
    </div>
    <div @touchstart.passive="mulai" @touchend.passive="akhir">
      <div v-for="p in panel" :key="p.k" :ref="(el) => (wadah[p.k] = el)" v-show="aktif === p.k || (terlihat.length <= 1)" role="tabpanel" :aria-label="p.n" class="panel">
        <slot :name="p.k" />
      </div>
    </div>
    <div v-show="terlihat.length > 1" class="flex justify-center gap-1.5" aria-hidden="true">
      <span v-for="p in terlihat" :key="p.k" :class="['h-1.5 rounded-full transition-all', aktif === p.k ? 'w-6 bg-[#C7332F]' : 'w-1.5 bg-garis']" />
    </div>
  </section>
</template>
<style scoped>
.chip.aktif { border-color: color-mix(in srgb, var(--c) 35%, transparent); background: color-mix(in srgb, var(--c) 12%, rgb(var(--permukaan))); }
.panel > :deep(*) + :deep(*) { margin-top: 1rem; }
</style>
