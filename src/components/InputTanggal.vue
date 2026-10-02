<script setup>
// Isian tanggal dd/mm/yyyy. Nilai (v-model) disimpan sebagai yyyy-mm-dd.
// Bawaan hari ini (WITA), kecuali diberi :bawaan-kosong (mis. tanggal lahir).
import { ref, watch, onMounted } from 'vue'
import { PhCalendarBlank } from '@phosphor-icons/vue'
import { hariIniISO, formatPendek, formatHari, uraiPendek } from '@/lib/tanggal'

const model = defineModel({ type: String, default: '' })
const props = defineProps({ label: String, bawaanKosong: Boolean, wajib: Boolean, id: { type: String, default: () => 'tgl-' + Math.random().toString(36).slice(2, 7) } })
const teks = ref('')
const galat = ref('')
const pemilih = ref(null)

onMounted(() => { if (!model.value && !props.bawaanKosong) model.value = hariIniISO() })
watch(model, (v) => { teks.value = v ? formatPendek(v) : ''; galat.value = '' }, { immediate: true })

function ketik(e) {
  // Sisipkan garis miring otomatis: 03102026 → 03/10/2026
  let v = e.target.value.replace(/[^\d/]/g, '')
  if (/^\d{3,}$/.test(v)) v = v.slice(0, 2) + '/' + v.slice(2)
  if (/^\d{2}\/\d{3,}$/.test(v)) v = v.slice(0, 5) + '/' + v.slice(5)
  teks.value = v.slice(0, 10)
}
function tetapkan() {
  if (!teks.value) { model.value = ''; galat.value = props.wajib ? 'Tanggal wajib diisi.' : ''; return }
  const iso = uraiPendek(teks.value)
  if (iso) { model.value = iso; galat.value = '' } else galat.value = 'Tulis tanggal dengan format dd/mm/yyyy, contoh 03/10/2026.'
}
function bukaPemilih() { try { pemilih.value.showPicker() } catch { pemilih.value.focus() } }
</script>
<template>
  <div>
    <label v-if="label" :for="id" class="label-isian">{{ label }}<span v-if="wajib" class="text-merah"> *</span></label>
    <div class="relative">
      <input :id="id" class="isian pr-12 tabular-nums" inputmode="numeric" placeholder="dd/mm/yyyy" autocomplete="off"
        :value="teks" @input="ketik" @blur="tetapkan" @keydown.enter.prevent="tetapkan"
        :aria-invalid="!!galat" :aria-describedby="id + '-ket'" />
      <button type="button" class="tombol-ikon absolute right-0.5 top-1/2 -translate-y-1/2" @click="bukaPemilih" aria-label="Buka kalender">
        <PhCalendarBlank :size="22" weight="duotone" />
      </button>
      <input ref="pemilih" type="date" tabindex="-1" aria-hidden="true" class="pointer-events-none absolute bottom-0 right-2 h-0 w-0 opacity-0"
        :value="model" @change="model = $event.target.value" />
    </div>
    <p :id="id + '-ket'" :class="['mt-1 text-xs', galat ? 'text-merah font-semibold' : 'text-teks3']">
      {{ galat || (model ? formatHari(model) : 'Belum diisi') }}
    </p>
  </div>
</template>
