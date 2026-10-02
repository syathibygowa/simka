<script setup>
// Pilihan tema: Terang, Gelap, Ikuti sistem (bawaan).
import { PhSun, PhMoon, PhDesktop } from '@phosphor-icons/vue'
import { useTema } from '@/stores/tema'
import { useSesi } from '@/stores/sesi'
const tema = useTema()
const sesi = useSesi()
const PILIHAN = [
  { k: 'terang', label: 'Terang', ikon: PhSun },
  { k: 'gelap', label: 'Gelap', ikon: PhMoon },
  { k: 'sistem', label: 'Ikuti sistem', ikon: PhDesktop },
]
</script>
<template>
  <div class="grid grid-cols-3 gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" aria-label="Tema tampilan">
    <button v-for="p in PILIHAN" :key="p.k" type="button" role="radio" :aria-checked="tema.pilihan === p.k"
      :class="['flex min-h-[44px] items-center justify-center gap-1.5 rounded-xl px-2 text-sm font-semibold transition',
               tema.pilihan === p.k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2 hover:text-teks']"
      @click="tema.atur(p.k, sesi.pengguna?.id)">
      <component :is="p.ikon" :size="18" weight="duotone" /> {{ p.label }}
    </button>
  </div>
</template>
