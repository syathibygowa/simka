<!-- SIMKA PRO | src/components/TombolWA.vue | v1.0 | Fase 3 – Perbaikan P3 (berkas dan WA) | 04/10/2026 -->
<script setup>
// Tombol WA untuk satu penerima (membuka wa.me dengan pesan terisi). Nonaktif bila nomor HP kosong.
import { PhWhatsappLogo } from '@phosphor-icons/vue'
import { tautanWA } from '@/lib/wa'
const props = defineProps({ hp: String, pesan: String, label: { type: String, default: 'WA' }, kecil: Boolean })
</script>
<template>
  <a v-if="hp" :href="tautanWA(hp, pesan)" target="_blank" rel="noopener" :class="['tombol-garis w-presensi', kecil && 'min-h-[40px] px-3 text-sm']" style="color: var(--c)">
    <PhWhatsappLogo :size="kecil ? 18 : 20" weight="duotone" />{{ label }}</a>
  <span v-else :class="['tombol-garis cursor-not-allowed opacity-60', kecil && 'min-h-[40px] px-3 text-sm']" title="Nomor HP belum diisi di Data Pegawai"><PhWhatsappLogo :size="kecil ? 18 : 20" />{{ label }} (HP kosong)</span>
</template>
