<!-- SIMKA PRO | src/components/cetak/rapor/TtdRapor.vue | v1.0 | Fase 12 – Tahap 5 Cetak rapor | 13/10/2026 -->
<script setup>
// Tanda tangan rapor (seragam): orang tua/wali di kiri, wali kelas/muhaffizh di kanan (dengan tempat dan tanggal),
// kepala ("Mengetahui,") di tengah bawah. Tanda tangan basah.
import { formatPanjang } from '@/lib/tanggal'
defineProps({
  kanan: { type: Object, required: true },   // { jabatan, nama, niy }
  tengah: { type: Object, default: null },   // { jabatan, nama, niy }
  kiri: { type: Object, default: () => ({ jabatan: 'Orang Tua/Wali', nama: '' }) },
  tempat: { type: String, default: 'Gowa' }, tanggal: String,
})
</script>
<template>
  <section class="ttd-rapor">
    <div class="baris">
      <div><p>{{ kiri.pengantar || 'Mengetahui,' }}</p><p>{{ kiri.jabatan }}</p><div class="ruang" /><p :class="kiri.nama && 'nama'">{{ kiri.nama || '(..................................)' }}</p></div>
      <div><p>{{ tempat }}, {{ formatPanjang(tanggal || new Date()) }}</p><p>{{ kanan.jabatan }}</p><div class="ruang" /><p class="nama">{{ kanan.nama || '..................................' }}</p><p v-if="kanan.niy">NIY. {{ kanan.niy }}</p></div>
    </div>
    <div v-if="tengah" class="tengah"><p>Mengetahui,</p><p>{{ tengah.jabatan }}</p><div class="ruang" /><p class="nama">{{ tengah.nama || '..................................' }}</p><p v-if="tengah.niy">NIY. {{ tengah.niy }}</p></div>
  </section>
</template>
