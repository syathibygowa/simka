<script setup>
// Tanda SIMKA PRO: bintang delapan bergradasi merah–oranye.
defineProps({ size: { type: Number, default: 40 } })
</script>
<template>
  <svg :width="size" :height="size" viewBox="0 0 48 48" aria-hidden="true">
    <defs>
      <linearGradient id="lg-simka" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0" stop-color="#B02A26" /><stop offset="1" stop-color="#F08A45" />
      </linearGradient>
    </defs>
    <rect x="10" y="10" width="28" height="28" rx="4" fill="url(#lg-simka)" />
    <rect x="10" y="10" width="28" height="28" rx="4" fill="url(#lg-simka)" transform="rotate(45 24 24)" />
    <circle cx="24" cy="24" r="8.5" fill="none" stroke="#fff" stroke-width="2.4" />
    <circle cx="24" cy="24" r="3" fill="#fff" />
  </svg>
</template>
