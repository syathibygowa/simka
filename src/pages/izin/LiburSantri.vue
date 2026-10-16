<!-- SIMKA PRO | src/pages/izin/LiburSantri.vue | v1.0 | Perbaikan 13.7.0: Libur Santri menjadi menu tersendiri | 16/10/2026 -->
<script setup>
// Menu Libur Santri (sebelumnya tab di menu Perizinan): periode libur, penilaian kelayakan, pengesahan, WA wali, dan cetak.
// Isi halaman tetap komponen TabLibur agar alur dan hak akses tidak berubah.
import TabLibur from './TabLibur.vue'
</script>
<template>
  <div class="w-agenda"><TabLibur /></div>
</template>
