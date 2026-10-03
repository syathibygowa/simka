<!-- SIMKA PRO | src/components/cetak/DokumenCetak.vue | v1.1 | Fase 1 – Pengaturan | 03/10/2026 -->
<script setup>
// Kerangka dokumen cetak F4: kop surat, judul, isi (slot), tanda tangan, catatan cetak.
// Disembunyikan di layar kecuali :pratinjau aktif; selalu tampil saat dicetak.
import { computed } from 'vue'
import { formatPanjang, formatJam, sekarang } from '@/lib/tanggal'
import { useLembaga } from '@/stores/lembaga'
import KopSurat from './KopSurat.vue'

const lembaga = useLembaga()
lembaga.muat()
const props = defineProps({
  kop: { type: String, default: 'pondok' }, judul: String, subjudul: String,
  nomor: String, pratinjau: Boolean, pencetak: String,
  kopData: { type: Object, default: null }, // draf kop (cetak uji dari Pengaturan)
})
const dicetak = computed(() => {
  const s = sekarang()
  const t = `Dicetak melalui SIMKA PRO pada ${formatPanjang(s)} pukul ${formatJam(s)} WITA${props.pencetak ? ' oleh ' + props.pencetak : ''}`
  return t.endsWith('.') ? t : t + '.'
})
</script>
<template>
  <!-- Tanpa pratinjau, dokumen dipindah ke <body> agar saat dicetak hanya dokumen yang tampil -->
  <Teleport to="body" :disabled="pratinjau">
  <div :class="['cetak-saja', pratinjau && 'tampil']">
    <article class="dok lembar-f4">
      <KopSurat :kop="kopData || lembaga.kop(kop)" :kode="kop" />
      <h1 class="judul-dok">{{ judul }}</h1>
      <p v-if="nomor" class="subjudul-dok">Nomor: {{ nomor }}</p>
      <p v-if="subjudul" class="subjudul-dok">{{ subjudul }}</p>
      <slot />
      <slot name="ttd" />
      <p class="catatan-cetak">{{ dicetak }}</p>
    </article>
  </div>
  </Teleport>
</template>
