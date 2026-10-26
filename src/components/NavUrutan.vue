<!-- SIMKA PRO | src/components/NavUrutan.vue | v1.0 | 14.27.0: tombol Kembali, Sebelumnya, Berikutnya di halaman isian | 26/10/2026 -->
<script setup>
// Bilah navigasi halaman isian (Isi Absensi, Lembar Nilai): Kembali ke halaman asal, serta Sebelumnya/Berikutnya menurut urutan
// daftar asal (lib/urutan.js). Dipasang di atas dan di bawah isi halaman. Bila ada perubahan belum tersimpan, halaman isian
// sendiri yang meminta konfirmasi (onBeforeRouteLeave).
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { PhArrowLeft, PhCaretLeft, PhCaretRight } from '@phosphor-icons/vue'
import { tetangga } from '@/lib/urutan'

const props = defineProps({ jenis: { type: String, required: true }, kembali: { type: String, default: '' }, labelKembali: { type: String, default: 'Kembali' } })
const route = useRoute(); const router = useRouter()
const t = computed(() => tetangga(props.jenis, route.path))
function balik() {
  const asal = window.history.state?.back
  if (asal && !/^\/(absensi-santri\/isi|guru-mapel\/nilai\/)/.test(asal)) return router.back()
  router.push(props.kembali || route.meta?.kembali || '/')
}
const pergi = (x) => x && router.push(x.ke)
</script>
<template>
  <nav class="flex flex-wrap items-center gap-2" aria-label="Navigasi halaman">
    <button type="button" class="tombol-garis min-h-[42px] px-3 text-sm" @click="balik"><PhArrowLeft :size="18" weight="bold" /> {{ labelKembali }}</button>
    <span class="flex-1" />
    <template v-if="t && t.total > 1">
      <button type="button" class="tombol-garis min-h-[42px] max-w-[42vw] px-3 text-sm sm:max-w-xs" :disabled="!t.sebelum" :title="t.sebelum?.label" @click="pergi(t.sebelum)">
        <PhCaretLeft :size="18" weight="bold" class="shrink-0" /><span class="truncate">Sebelumnya</span></button>
      <span class="text-xs tabular-nums text-teks3">{{ t.posisi }}/{{ t.total }}</span>
      <button type="button" class="tombol-garis min-h-[42px] max-w-[42vw] px-3 text-sm sm:max-w-xs" :disabled="!t.sesudah" :title="t.sesudah?.label" @click="pergi(t.sesudah)">
        <span class="truncate">Berikutnya</span><PhCaretRight :size="18" weight="bold" class="shrink-0" /></button>
    </template>
  </nav>
</template>
