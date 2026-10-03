<!-- SIMKA PRO | src/components/cetak/TandaTangan.vue | v1.1 | Fase 1 – Pengaturan | 03/10/2026 -->
<script setup>
// Kolom tanda tangan sejajar: kiri pimpinan/atasan, kanan pegawai terkait.
// Kolom kanan memuat tempat dan tanggal dokumen.
import { computed } from 'vue'
import { formatPanjang } from '@/lib/tanggal'
import { useLembaga } from '@/stores/lembaga'
const lembaga = useLembaga()
const props = defineProps({
  kiri: { type: Object, required: true },   // { pengantar, jabatan, nama, niy }
  kanan: { type: Object, required: true },  // { jabatan, nama, niy }
  kota: { type: String, default: '' },  // bawaan: kota surat dari Pengaturan → Identitas
  tanggal: String,                           // yyyy-mm-dd; bawaan hari ini
})
const kotaSurat = computed(() => props.kota || lembaga.identitas?.kota_surat || 'Gowa')
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
      <p>{{ kotaSurat }}, {{ formatPanjang(tanggal || new Date()) }}</p>
      <p>{{ kanan.jabatan }}</p>
      <div class="ruang" />
      <p class="nama">{{ kanan.nama }}</p>
      <p v-if="kanan.niy">NIY. {{ kanan.niy }}</p>
    </div>
  </section>
</template>
