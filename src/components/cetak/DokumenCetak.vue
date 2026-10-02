<script setup>
// Kerangka dokumen cetak F4: kop surat, judul, isi (slot), tanda tangan, catatan cetak.
// Disembunyikan di layar kecuali :pratinjau aktif; selalu tampil saat dicetak.
import { computed } from 'vue'
import { formatPanjang, formatJam, sekarang } from '@/lib/tanggal'
import kopPondok from '@/assets/kop/kop-pondok.jpg'
import kopWustha from '@/assets/kop/kop-wustha.jpg'
import kopSma from '@/assets/kop/kop-sma.jpg'
import kopYayasan from '@/assets/kop/kop-yayasan.jpg'

const KOP = { pondok: kopPondok, wustha: kopWustha, sma: kopSma, yayasan: kopYayasan }
const props = defineProps({
  kop: { type: String, default: 'pondok' }, judul: String, subjudul: String,
  nomor: String, pratinjau: Boolean, pencetak: String,
})
const dicetak = computed(() => {
  const s = sekarang()
  const t = `Dicetak melalui SIMKA PRO pada ${formatPanjang(s)} pukul ${formatJam(s)} WITA${props.pencetak ? ' oleh ' + props.pencetak : ''}`
  return t.endsWith('.') ? t : t + '.'
})
</script>
<template>
  <div :class="['cetak-saja', pratinjau && 'tampil']">
    <article class="dok lembar-f4">
      <header class="kop"><img :src="KOP[kop] || KOP.pondok" :alt="'Kop surat ' + kop" /></header>
      <h1 class="judul-dok">{{ judul }}</h1>
      <p v-if="nomor" class="subjudul-dok">Nomor: {{ nomor }}</p>
      <p v-if="subjudul" class="subjudul-dok">{{ subjudul }}</p>
      <slot />
      <slot name="ttd" />
      <p class="catatan-cetak">{{ dicetak }}</p>
    </article>
  </div>
</template>
