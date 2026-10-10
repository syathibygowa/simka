<!-- SIMKA PRO | src/pages/umum/Tugas.vue | v1.7 | Fase 8 – Tahap 0 tanpa teks fase | 10/10/2026 -->
<script setup>
// Peluncur menu ala aplikasi Android: semua menu sesuai peran, berkelompok, berwarna.
import { computed } from 'vue'
import { useSesi } from '@/stores/sesi'
import { menuUntuk, GRUP } from '@/lib/menu'
const sesi = useSesi()
const kelompok = computed(() => {
  const m = menuUntuk(sesi.peran, sesi.ciriMenu).filter((x) => !['beranda', 'profil'].includes(x.kode))
  return GRUP.map((g) => ({ g, item: m.filter((x) => x.grup === g) })).filter((k) => k.item.length)
})
</script>
<template>
  <div class="space-y-5">
    <section v-for="k in kelompok" :key="k.g">
      <h2 class="mb-2 px-1 text-xs font-bold uppercase tracking-wide text-teks3">{{ k.g }}</h2>
      <!-- 4 kolom di HP (ikon ringkas), 6 di tablet, 8 di desktop -->
      <ul class="grid grid-cols-4 gap-x-1.5 gap-y-3 rounded-2xl bg-permukaan p-2.5 shadow-kartu sm:grid-cols-6 lg:grid-cols-8">
        <li v-for="m in k.item" :key="m.kode" :class="'w-' + m.warna">
          <router-link :to="m.ke" class="relative flex h-full flex-col items-center gap-1.5 rounded-xl px-0.5 py-1.5 text-center transition hover:bg-permukaan2 active:scale-95">
            <span class="chip-ikon h-11 w-11 rounded-2xl"><component :is="m.ikon" :size="24" weight="duotone" /></span>
            <span class="line-clamp-2 text-[11px] font-semibold leading-tight text-teks">{{ m.nama }}</span>
          </router-link>
        </li>
      </ul>
    </section>
  </div>
</template>
