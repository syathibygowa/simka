<!-- SIMKA PRO | src/components/cetak/CatatanValidasi.vue | v1.0 | Fase 8 – Tahap 1 Registri dokumen dan Cek Keabsahan | 10/10/2026 -->
<script setup>
// Catatan kaki dokumen bertanda tangan elektronik: cara memeriksa keaslian (pindai QR atau ketik kode validasi
// di halaman Cek Keabsahan Dokumen). Draf (belum disahkan) diberi tanda DRAF.
import { computed } from 'vue'
import { alamatCek } from '@/lib/dokumen'
const props = defineProps({ kode: String, draf: Boolean })
const alamat = computed(() => alamatCek('').replace(/#\/cek\/$/, '#/cek'))
</script>
<template>
  <p v-if="draf" class="catatan-validasi">DRAF – dokumen ini belum disahkan oleh semua penanda tangan dan belum memiliki kode validasi.</p>
  <p v-else-if="kode" class="catatan-validasi">Dokumen ini ditandatangani secara elektronik melalui SIMKA PRO. Keaslian dapat diperiksa dengan memindai QR
    atau membuka halaman Cek Keabsahan Dokumen ({{ alamat }}) dan memasukkan kode validasi <b>{{ kode }}</b>.</p>
</template>
