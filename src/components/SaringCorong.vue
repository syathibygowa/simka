<!-- SIMKA PRO | src/components/SaringCorong.vue | v1.0 | 14.2.0: saringan ringkas bertombol corong di HP | 17/10/2026 -->
<script setup>
// Wadah saringan halaman. Desktop/tablet (≥ 768 px): isi saringan tampil sebaris seperti biasa.
// HP: hanya kolom cari (slot "cari", bila ada) + tombol corong berlencana jumlah saringan aktif; saringan lain
// (bidang, tanggal, status, …) dibuka dalam lembar bawah. Ringkasan saringan aktif tampil kecil di bawahnya,
// sehingga bagian atas layar tetap lega untuk informasi.
// Laporan (isi saringan lalu "Tampilkan"): :lipat="!!data" — sebelum ada hasil, saringan tampil utuh di HP; setelah
// hasil tampil, saringan dilipat menjadi bilah ringkasan bertombol corong. v-model:buka untuk menutup lembar dari halaman.
import { ref, computed, onMounted, onBeforeUnmount, useSlots } from 'vue'
import { PhFunnel, PhArrowCounterClockwise } from '@phosphor-icons/vue'
import LembarBawah from './LembarBawah.vue'

const props = defineProps({
  jumlah: { type: Number, default: 0 },          // jumlah saringan yang tidak bawaan
  ringkasan: { type: String, default: '' },      // mis. "Oktober 2026 · Bidang Kesantrian"
  judul: { type: String, default: 'Saring data' },
  bisaAturUlang: Boolean,                        // tampilkan tombol "Atur ulang" (emit atur-ulang)
  lipat: { type: Boolean, default: true },       // false = di HP tetap tampil utuh (mis. laporan belum ditampilkan)
  tanpaTombol: Boolean,                          // lembar tanpa tombol "Tampilkan" (halaman punya tombolnya sendiri)
})
const emit = defineEmits(['atur-ulang'])
const slots = useSlots()
const kecil = ref(false); const buka = defineModel('buka', { type: Boolean, default: false })
let mq
const ukur = () => { kecil.value = !!mq?.matches }
onMounted(() => { mq = window.matchMedia('(max-width: 767px)'); ukur(); mq.addEventListener?.('change', ukur) })
onBeforeUnmount(() => mq?.removeEventListener?.('change', ukur))
const adaCari = computed(() => !!slots.cari)
</script>
<template>
  <div class="saring-corong">
    <template v-if="!kecil || !lipat">
      <div class="flex flex-wrap items-end gap-2">
        <div v-if="adaCari" class="min-w-[220px] flex-1"><slot name="cari" /></div>
        <slot />
      </div>
    </template>
    <template v-else>
      <div class="flex items-center gap-2">
        <div v-if="adaCari" class="min-w-0 flex-1"><slot name="cari" /></div>
        <p v-else class="min-w-0 flex-1 truncate text-xs text-teks3">{{ ringkasan || 'Semua data' }}</p>
        <button type="button" :class="['relative inline-flex h-[44px] shrink-0 items-center gap-1.5 rounded-xl border px-3 text-sm font-semibold',
          jumlah ? 'border-[#C7332F]/50 text-merah' : 'border-garis text-teks2']" :aria-label="`Saringan${jumlah ? ` (${jumlah} aktif)` : ''}`" @click="buka = true">
          <PhFunnel :size="20" :weight="jumlah ? 'fill' : 'duotone'" /><span v-if="!adaCari">Saring</span>
          <span v-if="jumlah" class="absolute -right-1.5 -top-1.5 grid h-5 min-w-[20px] place-items-center rounded-full bg-[#C7332F] px-1 text-[11px] font-bold text-white">{{ jumlah }}</span>
        </button>
      </div>
      <p v-if="adaCari && ringkasan" class="mt-1 truncate px-1 text-xs text-teks3">{{ ringkasan }}</p>
      <LembarBawah v-model="buka" :judul="judul">
        <div class="saring-lembar space-y-3 pb-2">
          <slot />
          <div v-if="!tanpaTombol || (bisaAturUlang && jumlah)" class="flex gap-2 pt-1">
            <button v-if="bisaAturUlang && jumlah" type="button" class="tombol-garis flex-1" @click="emit('atur-ulang')"><PhArrowCounterClockwise :size="18" /> Atur ulang</button>
            <button v-if="!tanpaTombol" type="button" class="tombol-utama flex-1" @click="buka = false">Tampilkan</button>
          </div>
        </div>
      </LembarBawah>
    </template>
  </div>
</template>
<style scoped>
/* Di lembar bawah, setiap saringan mengisi selebar lembar */
.saring-lembar :deep(select.isian), .saring-lembar :deep(input.isian), .saring-lembar :deep(.w-auto) { width: 100% !important; max-width: 100% !important; }
.saring-lembar :deep(> div), .saring-lembar :deep(> label) { width: 100%; }
</style>
