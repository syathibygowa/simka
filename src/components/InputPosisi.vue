<!-- SIMKA PRO | src/components/InputPosisi.vue | v1.1 | Fase 5 – Tahap 2 Setoran per sesi halaqah | 05/10/2026 -->
<script setup>
// Isian posisi hafalan Juz + Halaman. Nilai (v-model) = total halaman (20 halaman = 1 juz).
// Halaman 20 atau lebih otomatis menjadi juz; tombol − dan + besar agar mudah diketuk di HP.
import { computed } from 'vue'
import { PhMinus, PhPlus } from '@phosphor-icons/vue'
import { HAL_PER_JUZ, MAKS_HAL, dariHal, keHal, formatPosisi } from '@/lib/tahfizh'

const nilai = defineModel({ type: Number, default: 0 })
const props = defineProps({ label: String, namaAria: String, ringkas: Boolean, id: { type: String, required: true }, keterangan: String, nonaktif: Boolean })
const nama = computed(() => props.label || props.namaAria || 'Posisi')
const juz = computed(() => dariHal(nilai.value).juz)
const hal = computed(() => dariHal(nilai.value).hal)
const atur = (j, h) => { nilai.value = keHal(j, h) }
const geser = (n) => { nilai.value = Math.min(MAKS_HAL, Math.max(0, (nilai.value || 0) + n)) }
function ketikJuz(e) { const j = Math.min(30, Math.max(0, parseInt(e.target.value, 10) || 0)); atur(j, j >= 30 ? 0 : hal.value); e.target.value = juz.value }
function ketikHal(e) { const h = Math.max(0, parseInt(e.target.value, 10) || 0); atur(juz.value + Math.floor(h / HAL_PER_JUZ), h % HAL_PER_JUZ); e.target.value = hal.value }
</script>
<template>
  <div>
    <label v-if="label" class="label-isian" :for="`${id}-juz`">{{ label }}</label>
    <div :class="['flex items-center', ringkas ? 'gap-1.5' : 'gap-2']">
      <button :class="['tombol-ikon shrink-0 border border-garis', ringkas ? 'h-10 w-10' : 'h-11 w-11']" type="button" :disabled="nonaktif || !nilai" :aria-label="`Kurangi satu halaman ${nama}`" @click="geser(-1)"><PhMinus :size="18" weight="bold" /></button>
      <div class="grid flex-1 grid-cols-2 gap-2">
        <div class="relative">
          <input :id="`${id}-juz`" type="number" inputmode="numeric" min="0" max="30" :class="['isian text-center font-bold tabular-nums', ringkas ? 'min-h-[40px] pl-1 pr-8 text-base' : 'pr-10 text-lg']" :value="juz" :disabled="nonaktif" @change="ketikJuz" :aria-label="`${nama}: juz`" />
          <span :class="['pointer-events-none absolute top-1/2 -translate-y-1/2 text-xs font-semibold text-teks3', ringkas ? 'right-2' : 'right-3']">juz</span>
        </div>
        <div class="relative">
          <input :id="`${id}-hal`" type="number" inputmode="numeric" min="0" max="19" :class="['isian text-center font-bold tabular-nums', ringkas ? 'min-h-[40px] pl-1 pr-8 text-base' : 'pr-10 text-lg']" :value="hal" :disabled="nonaktif || juz >= 30" @change="ketikHal" :aria-label="`${nama}: halaman`" />
          <span :class="['pointer-events-none absolute top-1/2 -translate-y-1/2 text-xs font-semibold text-teks3', ringkas ? 'right-2' : 'right-3']">hal</span>
        </div>
      </div>
      <button :class="['tombol-ikon shrink-0 border border-garis', ringkas ? 'h-10 w-10' : 'h-11 w-11']" type="button" :disabled="nonaktif || nilai >= MAKS_HAL" :aria-label="`Tambah satu halaman ${nama}`" @click="geser(1)"><PhPlus :size="18" weight="bold" /></button>
    </div>
    <p class="mt-1 text-xs text-teks3">{{ keterangan ? keterangan + ' · ' : '' }}{{ juz ? `${formatPosisi(nilai, true)} = ${nilai} halaman` : `${nilai || 0} halaman` }}</p>
  </div>
</template>
