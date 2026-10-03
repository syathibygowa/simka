<!-- SIMKA PRO | src/components/FotoBerkas.vue | v1.0 | Fase 2 – Tahap 6 Verval dan koreksi | 03/10/2026 -->
<script setup>
// Menampilkan foto privat (selfie presensi) berdasarkan id storage_objects. Dimuat saat terlihat,
// diketuk untuk memperbesar. Hak akses diperiksa server (Edge Function "berkas").
import { ref, onMounted, onBeforeUnmount } from 'vue'
import { PhImageBroken, PhUserFocus, PhX } from '@phosphor-icons/vue'
import { MODE_DEMO } from '@/lib/supabase'
import { ambilBerkasUrl } from '@/lib/penyimpanan'

const props = defineProps({ id: String, alt: { type: String, default: 'Selfie presensi' }, ukuran: { type: String, default: 'h-24 w-20' } })
const url = ref(null); const galat = ref(''); const besar = ref(false); const el = ref(null)
let amati
async function muat() {
  if (!props.id || MODE_DEMO) return
  try { url.value = await ambilBerkasUrl(props.id) } catch (e) { galat.value = e.message }
}
onMounted(() => {
  if (!('IntersectionObserver' in window)) return muat()
  amati = new IntersectionObserver((e) => { if (e[0].isIntersecting) { amati.disconnect(); muat() } })
  amati.observe(el.value)
})
onBeforeUnmount(() => amati?.disconnect())
</script>
<template>
  <span ref="el" class="inline-block shrink-0">
    <button v-if="url" type="button" :class="['overflow-hidden rounded-xl border border-garis', ukuran]" @click="besar = true" :aria-label="`Perbesar ${alt}`">
      <img :src="url" :alt="alt" class="h-full w-full object-cover" />
    </button>
    <span v-else :class="['grid place-items-center rounded-xl border border-dashed border-garis bg-permukaan2 text-teks3', ukuran]" :title="galat || (MODE_DEMO ? 'Mode demo: foto tidak tersedia' : 'Memuat foto…')">
      <component :is="galat ? PhImageBroken : PhUserFocus" :size="26" weight="duotone" />
    </span>
    <Teleport to="body">
      <div v-if="besar" class="layar-saja fixed inset-0 z-[70] grid place-items-center bg-black/85 p-4" role="dialog" aria-modal="true" :aria-label="alt" @click="besar = false">
        <img :src="url" :alt="alt" class="max-h-[90dvh] max-w-full rounded-xl" />
        <button class="absolute right-4 top-4 grid h-11 w-11 place-items-center rounded-full bg-white/15 text-white" aria-label="Tutup"><PhX :size="24" /></button>
      </div>
    </Teleport>
  </span>
</template>
