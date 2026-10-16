<!-- SIMKA PRO | src/components/IsianTeksKaya.vue | v2.0 | Perbaikan 13.8.0: garis bawah, daftar bernomor, daftar simbol, penomoran otomatis | 16/10/2026 -->
<script setup>
// Kotak isian teks panjang dengan bilah gaya: Tebal (*teks*), Miring (_teks_), Garis bawah (__teks__), Normal (lepas gaya),
// Daftar bernomor (1. 2. 3.), Daftar simbol (- → •), dan Pratinjau. Baris baru dipertahankan.
// Penomoran otomatis: Enter di dalam butir daftar melanjutkan nomor/simbol berikutnya; Enter pada butir kosong mengakhiri daftar;
// nomor sesudahnya ikut diurutkan ulang. Pintasan papan ketik: Ctrl/⌘ + B, I, U.
// Dipakai di Pengumuman, Pengumuman wali, Agenda, Berkas/informasi, Surat masuk, Disposisi, dan Surat keluar.
import { ref, nextTick } from 'vue'
import { PhTextB, PhTextItalic, PhTextUnderline, PhTextT, PhListNumbers, PhListBullets, PhEye, PhPencilSimpleLine } from '@phosphor-icons/vue'
import { teksKaya, terapkanGaya, enterDaftar } from '@/lib/teksKaya'

const props = defineProps({
  modelValue: { type: String, default: '' }, id: { type: String, default: 'isian-kaya' }, label: { type: String, default: '' },
  placeholder: { type: String, default: '' }, wajib: { type: Boolean, default: false }, tinggi: { type: String, default: '9rem' },
  kelas: { type: String, default: '' }, petunjuk: { type: Boolean, default: true },
})
const emit = defineEmits(['update:modelValue'])
const kotak = ref(null); const pratinjau = ref(false)

async function pasang(h) {
  emit('update:modelValue', h.nilai)
  await nextTick(); const el = kotak.value; if (!el) return
  el.focus(); el.setSelectionRange(h.awal ?? h.kursor, h.akhir ?? h.kursor)
}
async function gaya(jenis) {
  if (pratinjau.value) pratinjau.value = false
  await nextTick()
  const el = kotak.value; if (!el) return
  await pasang(terapkanGaya(props.modelValue || '', el.selectionStart, el.selectionEnd, jenis))
}
function tombol(e) {
  if (e.key === 'Enter' && !e.shiftKey && !e.ctrlKey && !e.metaKey && !e.altKey && !e.isComposing) {
    const el = e.target; if (el.selectionStart !== el.selectionEnd) return
    const h = enterDaftar(props.modelValue || '', el.selectionStart)
    if (h) { e.preventDefault(); pasang(h) }
    return
  }
  if (!(e.ctrlKey || e.metaKey)) return
  const k = e.key.toLowerCase()
  const peta = { b: 'tebal', i: 'miring', u: 'garis' }
  if (peta[k]) { e.preventDefault(); gaya(peta[k]) }
}
const TOMBOL = [
  { k: 'tebal', n: 'Tebal', ikon: PhTextB, ket: 'Tebal (Ctrl+B)' },
  { k: 'miring', n: 'Miring', ikon: PhTextItalic, ket: 'Miring (Ctrl+I)' },
  { k: 'garis', n: 'Garis bawah', ikon: PhTextUnderline, ket: 'Garis bawah (Ctrl+U)' },
  { k: 'normal', n: 'Normal', ikon: PhTextT, ket: 'Kembalikan ke teks normal' },
]
const DAFTAR = [
  { k: 'nomor', n: 'Nomor', ikon: PhListNumbers, ket: 'Daftar bernomor otomatis (1. 2. 3.)' },
  { k: 'simbol', n: 'Simbol', ikon: PhListBullets, ket: 'Daftar simbol otomatis (•)' },
]
</script>
<template>
  <div>
    <label v-if="label" class="label-isian" :for="id">{{ label }} <span v-if="wajib" class="text-merah">*</span></label>
    <div class="overflow-hidden rounded-xl border border-garis bg-permukaan focus-within:border-[#2F5FA8]">
      <div class="flex flex-wrap items-center gap-0.5 border-b border-garis bg-permukaan2 px-1.5 py-1" role="toolbar" aria-label="Gaya teks">
        <button v-for="t in TOMBOL" :key="t.k" type="button" class="bilah-gaya" :title="t.ket" :aria-label="t.ket" @mousedown.prevent @click="gaya(t.k)">
          <component :is="t.ikon" :size="18" weight="bold" />
        </button>
        <span class="mx-1 h-6 w-px bg-garis" aria-hidden="true" />
        <button v-for="t in DAFTAR" :key="t.k" type="button" class="bilah-gaya" :title="t.ket" :aria-label="t.ket" @mousedown.prevent @click="gaya(t.k)">
          <component :is="t.ikon" :size="18" weight="bold" /><span class="hidden sm:inline">{{ t.n }}</span>
        </button>
        <span class="flex-1" />
        <button type="button" class="bilah-gaya" :aria-pressed="pratinjau" @click="pratinjau = !pratinjau">
          <component :is="pratinjau ? PhPencilSimpleLine : PhEye" :size="18" weight="duotone" /><span>{{ pratinjau ? 'Ubah' : 'Pratinjau' }}</span>
        </button>
      </div>
      <textarea v-show="!pratinjau" :id="id" ref="kotak" :value="modelValue" :required="wajib" :placeholder="placeholder" :style="{ minHeight: tinggi }"
        :class="['block w-full resize-y bg-transparent px-3 py-2 text-teks outline-none placeholder:text-teks3', kelas]" @input="emit('update:modelValue', $event.target.value)" @keydown="tombol" />
      <!-- eslint-disable-next-line vue/no-v-html -- teks sudah di-escape oleh teksKaya() -->
      <div v-if="pratinjau" class="whitespace-pre-line px-3 py-2 leading-relaxed text-teks" :style="{ minHeight: tinggi }" v-html="teksKaya(modelValue) || '<span class=&quot;text-teks3&quot;>Belum ada isi.</span>'" />
    </div>
    <p v-if="petunjuk" class="mt-1 text-xs text-teks3">Pilih kata lalu ketuk <strong>Tebal</strong>, <em>Miring</em>, atau <u>Garis bawah</u>. Ketuk <b>Nomor</b>/<b>Simbol</b> untuk daftar; Enter melanjutkan nomor berikutnya.
      Penulisan langsung juga bisa: *tebal*, _miring_, __garis bawah__, "1. " dan "- ".</p>
  </div>
</template>
<style scoped>
.bilah-gaya { display: inline-flex; min-height: 36px; min-width: 36px; justify-content: center; align-items: center; gap: .35rem; border-radius: .6rem; padding: 0 .5rem; font-size: .8125rem; font-weight: 600; color: rgb(var(--teks-2)); }
.bilah-gaya:hover, .bilah-gaya[aria-pressed='true'] { background: rgb(var(--permukaan)); color: rgb(var(--teks)); }
</style>
