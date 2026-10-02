<script setup>
// Isian jam. Bawaan mengikuti jam sistem saat ini dan terus berjalan
// sampai pengguna mengubahnya sendiri; tombol "Sekarang" mengembalikannya.
import { ref, onMounted, onBeforeUnmount } from 'vue'
import { PhClock } from '@phosphor-icons/vue'
import { jamSekarang } from '@/lib/tanggal'

const model = defineModel({ type: String, default: '' })
const props = defineProps({ label: String, wajib: Boolean, id: { type: String, default: () => 'jam-' + Math.random().toString(36).slice(2, 7) } })
const ikutJam = ref(!model.value)
let detak
const segarkan = () => { if (ikutJam.value) model.value = jamSekarang() }
onMounted(() => { segarkan(); detak = setInterval(segarkan, 1000) })
onBeforeUnmount(() => clearInterval(detak))
function ubah(e) { ikutJam.value = false; model.value = e.target.value }
function kembali() { ikutJam.value = true; segarkan() }
</script>
<template>
  <div>
    <label v-if="label" :for="id" class="label-isian">{{ label }}<span v-if="wajib" class="text-merah"> *</span></label>
    <div class="flex gap-2">
      <div class="relative flex-1">
        <PhClock :size="20" weight="duotone" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-teks3" />
        <input :id="id" type="time" class="isian pl-10 tabular-nums" :value="model" @input="ubah" />
      </div>
      <button type="button" class="tombol-garis px-4 text-sm" :disabled="ikutJam" @click="kembali">Sekarang</button>
    </div>
    <p class="mt-1 text-xs text-teks3">{{ ikutJam ? 'Mengikuti jam saat ini (WITA)' : 'Diatur manual' }}</p>
  </div>
</template>
