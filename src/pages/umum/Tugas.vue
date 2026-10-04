<!-- SIMKA PRO | src/pages/umum/Tugas.vue | v1.4 | Fase 4 – Tahap 2 Kelompok santri | 04/10/2026 -->
<script setup>
// Peluncur menu ala aplikasi Android: semua menu sesuai peran, berkelompok, berwarna.
import { computed } from 'vue'
import { useSesi } from '@/stores/sesi'
import { menuUntuk, GRUP } from '@/lib/menu'
const sesi = useSesi()
const kelompok = computed(() => {
  const m = menuUntuk(sesi.peran, { shift: sesi.punyaShift, izin: sesi.izinAdmin, fitur: sesi.fitur, kelompok: sesi.kelompokSaya.length > 0 }).filter((x) => !['beranda', 'profil'].includes(x.kode))
  return GRUP.map((g) => ({ g, item: m.filter((x) => x.grup === g) })).filter((k) => k.item.length)
})
</script>
<template>
  <div class="space-y-5">
    <section v-for="k in kelompok" :key="k.g">
      <h2 class="mb-2 px-1 text-sm font-bold text-teks3">{{ k.g }}</h2>
      <ul class="grid grid-cols-3 gap-2.5 sm:grid-cols-4 lg:grid-cols-6">
        <li v-for="m in k.item" :key="m.kode" :class="'w-' + m.warna">
          <router-link :to="m.ke" class="kartu relative flex h-full flex-col items-center gap-2 px-2 py-4 text-center hover:bg-permukaan2">
            <span class="chip-ikon h-12 w-12 rounded-2xl"><component :is="m.ikon" :size="28" weight="duotone" /></span>
            <span class="text-[0.8rem] font-semibold leading-tight text-teks">{{ m.nama }}</span>
            <span v-if="m.fase" class="text-[11px] font-semibold text-teks3">Fase {{ m.fase }}</span>
          </router-link>
        </li>
      </ul>
    </section>
  </div>
</template>
