<!-- SIMKA PRO | src/components/InputPosisi.vue | v1.0 | Fase 5 – Tahap 1 Pengaturan tahfizh dan data hafalan awal | 05/10/2026 -->
<script setup>
// Isian posisi hafalan Juz + Halaman. Nilai (v-model) = total halaman (20 halaman = 1 juz).
// Halaman 20 atau lebih otomatis menjadi juz; tombol − dan + besar agar mudah diketuk di HP.
import { computed } from 'vue'
import { PhMinus, PhPlus } from '@phosphor-icons/vue'
import { HAL_PER_JUZ, MAKS_HAL, dariHal, keHal, formatPosisi } from '@/lib/tahfizh'

const nilai = defineModel({ type: Number, default: 0 })
const props = defineProps({ label: String, id: { type: String, required: true }, keterangan: String, nonaktif: Boolean })
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
    <div class="flex items-center gap-2">
      <button type="button" class="tombol-ikon h-11 w-11 shrink-0 border border-garis" :disabled="nonaktif || !nilai" :aria-label="`Kurangi satu halaman ${label || ''}`" @click="geser(-1)"><PhMinus :size="18" weight="bold" /></button>
      <div class="grid flex-1 grid-cols-2 gap-2">
        <div class="relative">
          <input :id="`${id}-juz`" type="number" inputmode="numeric" min="0" max="30" class="isian pr-10 text-center text-lg font-bold tabular-nums" :value="juz" :disabled="nonaktif" @change="ketikJuz" :aria-label="`${label || 'Posisi'}: juz`" />
          <span class="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-xs font-semibold text-teks3">juz</span>
        </div>
        <div class="relative">
          <input :id="`${id}-hal`" type="number" inputmode="numeric" min="0" max="19" class="isian pr-10 text-center text-lg font-bold tabular-nums" :value="hal" :disabled="nonaktif || juz >= 30" @change="ketikHal" :aria-label="`${label || 'Posisi'}: halaman`" />
          <span class="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-xs font-semibold text-teks3">hal</span>
        </div>
      </div>
      <button type="button" class="tombol-ikon h-11 w-11 shrink-0 border border-garis" :disabled="nonaktif || nilai >= MAKS_HAL" :aria-label="`Tambah satu halaman ${label || ''}`" @click="geser(1)"><PhPlus :size="18" weight="bold" /></button>
    </div>
    <p class="mt-1 text-xs text-teks3">{{ keterangan ? keterangan + ' · ' : '' }}{{ juz ? `${formatPosisi(nilai, true)} = ${nilai} halaman` : `${nilai || 0} halaman` }}</p>
  </div>
</template>
