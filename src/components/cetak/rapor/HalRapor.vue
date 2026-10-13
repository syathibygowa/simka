<!-- SIMKA PRO | src/components/cetak/rapor/HalRapor.vue | v1.0 | Fase 12 – Tahap 5 Cetak rapor | 13/10/2026 -->
<script setup>
// Satu dokumen dalam LembarRapor (mis. rapor satu santri): dimulai di halaman baru; kop dan slot "kepala"
// (identitas santri) berulang di setiap halaman lanjutan. tanpaKop: sampul/identitas tanpa kop.
import KopSurat from '../KopSurat.vue'
import { useLembaga } from '@/stores/lembaga'
const lembaga = useLembaga()
defineProps({ kop: { type: String, default: 'pondok' }, tanpaKop: Boolean, mendatar: Boolean })
</script>
<template>
  <article :class="['dok lembar-f4 hal-rapor', mendatar && 'mendatar']">
    <table class="tata-rapor">
      <thead><tr><td>
        <KopSurat v-if="!tanpaKop" :kop="lembaga.kop(kop)" :kode="kop" :mendatar="mendatar" />
        <div v-if="$slots.kepala" class="kepala-rapor"><slot name="kepala" /></div>
      </td></tr></thead>
      <tbody><tr><td><slot /></td></tr></tbody>
    </table>
  </article>
</template>
