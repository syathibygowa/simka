<!-- SIMKA PRO | src/pages/verval/LembarKeputusan.vue | v1.0 | Fase 2 – Tahap 6 Verval dan koreksi | 03/10/2026 -->
<script setup>
// Lembar keputusan bersama: pilih status (dan status pulang bila perlu) lalu tulis alasan (wajib).
// Dipakai untuk verval, ajukan koreksi, ubah langsung superadmin, catat manual, dan penolakan.
import { ref, watch } from 'vue'
import { PhCheck } from '@phosphor-icons/vue'
import { useUI } from '@/stores/ui'
import LembarBawah from '@/components/LembarBawah.vue'

const buka = defineModel({ type: Boolean, default: false })
const props = defineProps({
  judul: String, ringkasan: String, catatan: String,
  pilihan: { type: Array, default: () => [] },          // [{ k, n, w }]
  pilihanPulang: { type: Array, default: null },        // [{ k, n, w }] atau null
  bawaan: String, bawaanPulang: String,
  labelTombol: { type: String, default: 'Simpan keputusan' }, bahaya: Boolean,
  contohAlasan: { type: String, default: 'Contoh: surat tugas dari kepala bidang' },
})
const emit = defineEmits(['kirim'])
const ui = useUI()
const status = ref(''); const pulang = ref(''); const alasan = ref(''); const proses = ref(false)
watch(buka, (v) => { if (v) { status.value = props.bawaan || props.pilihan[0]?.k || ''; pulang.value = props.bawaanPulang || ''; alasan.value = '' } })
async function kirim() {
  if (props.pilihan.length && !status.value) return ui.toast('Pilih status lebih dulu.', 'galat')
  if (alasan.value.trim().length < 5) return ui.toast('Alasan wajib diisi (minimal 5 karakter).', 'galat')
  proses.value = true
  try { await new Promise((res, rej) => emit('kirim', { status: status.value, pulang: pulang.value || null, alasan: alasan.value.trim() }, res, rej)); buka.value = false }
  catch (e) { if (e) ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <LembarBawah v-model="buka" :judul="judul">
    <div class="space-y-4 pb-2">
      <p v-if="ringkasan" class="rounded-xl bg-permukaan2 p-3 text-sm text-teks2">{{ ringkasan }}</p>
      <fieldset v-if="pilihan.length">
        <legend class="label-isian">Status</legend>
        <div class="flex flex-wrap gap-2">
          <label v-for="p in pilihan" :key="p.k" :class="['flex min-h-[44px] cursor-pointer items-center gap-2 rounded-full border px-3.5 text-sm font-semibold', 'w-' + p.w, status === p.k ? 'pilih' : 'border-garis text-teks2']">
            <input v-model="status" type="radio" :value="p.k" class="sr-only" /><span class="h-2.5 w-2.5 rounded-full" style="background: var(--c)" />{{ p.n }}</label>
        </div>
      </fieldset>
      <fieldset v-if="pilihanPulang && ['hadir', 'terlambat', 'dinas_luar'].includes(status)">
        <legend class="label-isian">Status pulang</legend>
        <div class="flex flex-wrap gap-2">
          <label v-for="p in [{ k: '', n: 'Tidak diubah', w: 'hakakses' }, ...pilihanPulang]" :key="p.k" :class="['flex min-h-[44px] cursor-pointer items-center gap-2 rounded-full border px-3.5 text-sm font-semibold', 'w-' + p.w, pulang === p.k ? 'pilih' : 'border-garis text-teks2']">
            <input v-model="pulang" type="radio" :value="p.k" class="sr-only" />{{ p.n }}</label>
        </div>
      </fieldset>
      <div><label class="label-isian" for="lk-alasan">Alasan <span class="text-merah">*</span></label>
        <textarea id="lk-alasan" v-model="alasan" rows="3" class="isian py-2.5" :placeholder="contohAlasan" /></div>
      <p v-if="catatan" class="text-xs text-teks3">{{ catatan }}</p>
      <button :class="['w-full', bahaya ? 'tombol-utama' : 'tombol-utama']" :disabled="proses" @click="kirim"><PhCheck :size="20" weight="bold" /> {{ proses ? 'Menyimpan…' : labelTombol }}</button>
    </div>
  </LembarBawah>
</template>
<style scoped>
.pilih { border-color: var(--c); color: var(--c); background: color-mix(in srgb, var(--c) 12%, rgb(var(--permukaan))); }
</style>
