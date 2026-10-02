<script setup>
// Kolom tanda tangan sejajar: kiri pimpinan/atasan, kanan pegawai terkait.
// Kolom kanan memuat tempat dan tanggal dokumen.
import { formatPanjang } from '@/lib/tanggal'
defineProps({
  kiri: { type: Object, required: true },   // { pengantar, jabatan, nama, niy }
  kanan: { type: Object, required: true },  // { jabatan, nama, niy }
  kota: { type: String, default: 'Gowa' },
  tanggal: String,                           // yyyy-mm-dd; bawaan hari ini
})
</script>
<template>
  <section class="ttd">
    <div>
      <p>{{ kiri.pengantar || 'Mengetahui,' }}</p>
      <p>{{ kiri.jabatan }}</p>
      <div class="ruang" />
      <p class="nama">{{ kiri.nama }}</p>
      <p v-if="kiri.niy">NIY. {{ kiri.niy }}</p>
    </div>
    <div>
      <p>{{ kota }}, {{ formatPanjang(tanggal || new Date()) }}</p>
      <p>{{ kanan.jabatan }}</p>
      <div class="ruang" />
      <p class="nama">{{ kanan.nama }}</p>
      <p v-if="kanan.niy">NIY. {{ kanan.niy }}</p>
    </div>
  </section>
</template>
