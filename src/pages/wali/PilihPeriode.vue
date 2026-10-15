<!-- SIMKA PRO | src/pages/wali/PilihPeriode.vue | v1.0 | Fase 9 – Tahap 13.1.0 Periode data Portal Wali | 15/10/2026 -->
<script setup>
// Pilihan periode Portal Wali: Bulan ini (bawaan), Bulan lalu, 30 hari, atau Rentang tanggal (paling panjang satu semester ≈ 186 hari).
// v-model = { mulai: 'yyyy-mm-dd', selesai: 'yyyy-mm-dd' }
import { ref } from 'vue'
import { PhCalendarDots } from '@phosphor-icons/vue'
import { hariIniISO, formatPanjang } from '@/lib/tanggal'
import InputTanggal from '@/components/InputTanggal.vue'

const model = defineModel({ type: Object, default: () => ({}) })
const PILIHAN = [{ k: 'bulan', n: 'Bulan ini' }, { k: 'lalu', n: 'Bulan lalu' }, { k: '30', n: '30 hari' }, { k: 'rentang', n: 'Rentang' }]
const pilihan = ref('bulan')
const iso = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
const hari = () => { const [y, m, d] = hariIniISO().split('-').map(Number); return new Date(y, m - 1, d) }
const mulaiR = ref(''); const selesaiR = ref(''); const galat = ref('')

function hitung(k) {
  const h = hari()
  if (k === 'bulan') return { mulai: iso(new Date(h.getFullYear(), h.getMonth(), 1)), selesai: iso(h) }
  if (k === 'lalu') return { mulai: iso(new Date(h.getFullYear(), h.getMonth() - 1, 1)), selesai: iso(new Date(h.getFullYear(), h.getMonth(), 0)) }
  if (k === '30') { const m = new Date(h); m.setDate(m.getDate() - 29); return { mulai: iso(m), selesai: iso(h) } }
  return null
}
function pilih(k) {
  pilihan.value = k; galat.value = ''
  if (k === 'rentang') { mulaiR.value = model.value.mulai || hitung('bulan').mulai; selesaiR.value = model.value.selesai || iso(hari()); return }
  model.value = hitung(k)
}
function terapkan() {
  galat.value = ''
  if (!mulaiR.value || !selesaiR.value) { galat.value = 'Isi tanggal awal dan akhir.'; return }
  if (mulaiR.value > selesaiR.value) { galat.value = 'Tanggal awal harus sebelum tanggal akhir.'; return }
  const lama = (new Date(selesaiR.value) - new Date(mulaiR.value)) / 864e5
  if (lama > 185) { galat.value = 'Rentang paling panjang satu semester (186 hari).'; return }
  model.value = { mulai: mulaiR.value, selesai: selesaiR.value }
}
if (!model.value?.mulai) model.value = hitung('bulan')
</script>

<template>
  <div class="space-y-2">
    <div class="flex gap-2 overflow-x-auto pb-1" role="radiogroup" aria-label="Periode">
      <button v-for="p in PILIHAN" :key="p.k" type="button" role="radio" :aria-checked="pilihan === p.k" @click="pilih(p.k)"
        :class="['min-h-[40px] shrink-0 rounded-xl border px-3.5 text-sm font-semibold transition',
                 pilihan === p.k ? 'border-[#C7332F]/40 bg-[#C7332F]/10 text-teks' : 'border-garis bg-permukaan text-teks2 hover:text-teks']">{{ p.n }}</button>
    </div>
    <div v-if="pilihan === 'rentang'" class="kartu grid gap-3 p-3 sm:grid-cols-[1fr_1fr_auto] sm:items-end">
      <InputTanggal v-model="mulaiR" label="Dari tanggal" bawaan-kosong />
      <InputTanggal v-model="selesaiR" label="Sampai tanggal" bawaan-kosong />
      <button type="button" class="tombol-utama" @click="terapkan">Tampilkan</button>
      <p v-if="galat" class="text-sm font-semibold text-merah sm:col-span-3" role="alert">{{ galat }}</p>
    </div>
    <p class="flex items-center gap-1.5 text-sm text-teks3"><PhCalendarDots :size="16" weight="duotone" />
      {{ formatPanjang(model.mulai) }} – {{ formatPanjang(model.selesai) }}</p>
  </div>
</template>
