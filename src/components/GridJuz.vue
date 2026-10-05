<!-- SIMKA PRO | src/components/GridJuz.vue | v1.1 | Fase 5 – Tahap 3 Validasi capaian juz dan status bulanan | 05/10/2026 -->
<script setup>
// Ceklist juz 1–30 berbentuk kisi. Urutan hafalan bebas (boleh dimulai dari juz 30).
// v-model = daftar juz terpilih. "terkunci" = juz dari ujian/sertifikasi (tidak dapat diubah di sini).
// Mode ringkas (tanpa v-model) dipakai sebagai tampilan kecil di daftar santri.
import { computed } from 'vue'
import { PhLockSimple } from '@phosphor-icons/vue'

const pilih = defineModel({ type: Array, default: () => [] })
const props = defineProps({ terkunci: { type: Array, default: () => [] }, sedang: Number, ringkas: Boolean, bacaSaja: Boolean, label: { type: String, default: 'Ceklist juz' },
  labelPilih: { type: String, default: 'Data awal' }, labelKunci: { type: String, default: 'Lulus ujian/disetujui (terkunci)' } })
const set = computed(() => new Set([...pilih.value, ...props.terkunci].map(Number)))
const kunci = computed(() => new Set(props.terkunci.map(Number)))
function ketuk(j) {
  if (props.bacaSaja || props.ringkas || kunci.value.has(j)) return
  pilih.value = set.value.has(j) ? pilih.value.filter((x) => Number(x) !== j) : [...pilih.value, j].sort((a, b) => a - b)
}
</script>
<template>
  <div v-if="ringkas" class="grid grid-cols-[repeat(15,minmax(0,1fr))] gap-[3px]" role="img" :aria-label="`${label}: ${set.size} dari 30 juz`">
    <span v-for="j in 30" :key="j" :title="`Juz ${j}`"
      :class="['h-2.5 rounded-sm', set.has(j) ? (kunci.has(j) ? 'bg-[#8C6200] dark:bg-[#F2C24B]' : 'bg-[#1E7D4F] dark:bg-[#5BD69A]') : sedang === j ? 'bg-[#2F5FA8]/60 dark:bg-[#8AB4F8]/70' : 'bg-garis']" />
  </div>
  <div v-else role="group" :aria-label="label">
    <div class="grid grid-cols-6 gap-1.5 sm:grid-cols-10">
      <button v-for="j in 30" :key="j" type="button" :aria-pressed="set.has(j)" :disabled="bacaSaja || kunci.has(j)" @click="ketuk(j)"
        :class="['relative flex min-h-[44px] items-center justify-center rounded-xl border-2 text-sm font-bold tabular-nums transition',
          kunci.has(j) ? 'border-transparent bg-[#8C6200] text-white dark:bg-[#F2C24B] dark:text-[#2B1D00]'
          : set.has(j) ? 'border-transparent bg-[#1E7D4F] text-white dark:bg-[#5BD69A] dark:text-[#0A2A1A]'
          : sedang === j ? 'border-[#2F5FA8] bg-[#2F5FA8]/10 text-teks dark:border-[#8AB4F8]' : 'border-garis bg-permukaan text-teks2 hover:border-teks3']">
        {{ j }}<PhLockSimple v-if="kunci.has(j)" :size="10" weight="bold" class="absolute right-1 top-1" />
      </button>
    </div>
    <p class="mt-2 flex flex-wrap gap-x-4 gap-y-1 text-xs text-teks3">
      <span class="inline-flex items-center gap-1"><i class="inline-block h-3 w-3 rounded bg-[#1E7D4F] dark:bg-[#5BD69A]" /> {{ labelPilih }}</span>
      <span class="inline-flex items-center gap-1"><i class="inline-block h-3 w-3 rounded bg-[#8C6200] dark:bg-[#F2C24B]" /> {{ labelKunci }}</span>
      <span v-if="sedang" class="inline-flex items-center gap-1"><i class="inline-block h-3 w-3 rounded border-2 border-[#2F5FA8] dark:border-[#8AB4F8]" /> Sedang dihafal</span>
      <span class="font-semibold text-teks2">{{ set.size }} dari 30 juz</span>
    </p>
  </div>
</template>
