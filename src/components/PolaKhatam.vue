<script setup>
// Pola bintang delapan (khatam) khas ornamen masjid, dipakai tipis sebagai latar.
defineProps({ opasitas: { type: Number, default: 0.16 }, ukuran: { type: Number, default: 56 } })
const id = 'khatam-' + Math.random().toString(36).slice(2, 8)
</script>
<template>
  <svg class="pointer-events-none absolute inset-0 h-full w-full" aria-hidden="true">
    <defs>
      <pattern :id="id" :width="ukuran" :height="ukuran" patternUnits="userSpaceOnUse">
        <g :transform="`translate(${ukuran / 2} ${ukuran / 2})`" fill="none" stroke="currentColor" stroke-width="1.1">
          <rect :x="-ukuran * 0.25" :y="-ukuran * 0.25" :width="ukuran * 0.5" :height="ukuran * 0.5" />
          <rect :x="-ukuran * 0.25" :y="-ukuran * 0.25" :width="ukuran * 0.5" :height="ukuran * 0.5" transform="rotate(45)" />
          <circle r="2" fill="currentColor" stroke="none" />
        </g>
        <path :d="`M0 0 L${ukuran * 0.14} 0 M0 0 L0 ${ukuran * 0.14}`" stroke="currentColor" stroke-width="1.1" />
      </pattern>
    </defs>
    <rect width="100%" height="100%" :fill="`url(#${id})`" :style="{ opacity: opasitas }" />
  </svg>
</template>
