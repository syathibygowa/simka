<!-- SIMKA PRO | src/pages/organisasi/SimpulUnit.vue | v1.0 | Fase 1 – Struktur organisasi | 03/10/2026 -->
<script setup>
// Satu simpul pohon bidang/unit beserta anak-anaknya (rekursif).
import { PhCrown, PhBuildings, PhUsersFour, PhPlus, PhPencilSimple, PhStar } from '@phosphor-icons/vue'
import { useOrganisasi } from '@/stores/organisasi'
defineOptions({ name: 'SimpulUnit' })
const props = defineProps({ unit: Object, tingkat: { type: Number, default: 0 } })
const emit = defineEmits(['tambah', 'ubah'])
const org = useOrganisasi()
const GAYA = { pimpinan: { ikon: PhCrown, w: 'pengaturan', n: 'Pimpinan' }, bidang: { ikon: PhBuildings, w: 'santri', n: 'Bidang' }, unit: { ikon: PhUsersFour, w: 'tahfizh', n: 'Unit' } }
</script>
<template>
  <li>
    <div :class="['simpul flex items-center gap-3 rounded-xl px-2 py-2 hover:bg-permukaan2', 'w-' + GAYA[unit.jenis].w, !unit.aktif && 'opacity-60']">
      <span class="chip-ikon h-10 w-10"><component :is="GAYA[unit.jenis].ikon" :size="22" weight="duotone" /></span>
      <div class="min-w-0 flex-1">
        <p class="flex flex-wrap items-center gap-1.5 font-semibold">
          <span class="truncate">{{ unit.nama }}</span>
          <PhStar v-if="unit.prioritas && unit.jenis !== 'pimpinan'" :size="14" weight="fill" class="text-[#B27A00] dark:text-[#F2C24B]" aria-label="Bidang prioritas" />
          <span v-if="!unit.aktif" class="lencana w-hakakses">Nonaktif</span>
        </p>
        <p class="text-xs text-teks3">{{ GAYA[unit.jenis].n }} – kode {{ unit.kode }} – {{ org.jumlahCabang(unit.id) }} pegawai</p>
      </div>
      <button class="tombol-ikon h-10 w-10" @click="emit('tambah', unit)" :aria-label="`Tambah unit di bawah ${unit.nama}`" title="Tambah di bawahnya"><PhPlus :size="20" /></button>
      <button class="tombol-ikon h-10 w-10" @click="emit('ubah', unit)" :aria-label="`Ubah ${unit.nama}`" title="Ubah"><PhPencilSimple :size="20" /></button>
    </div>
    <ul v-if="org.anak(unit.id).length" class="cabang ml-5 border-l-2 border-garis pl-3">
      <SimpulUnit v-for="a in org.anak(unit.id)" :key="a.id" :unit="a" :tingkat="tingkat + 1" @tambah="(x) => emit('tambah', x)" @ubah="(x) => emit('ubah', x)" />
    </ul>
  </li>
</template>
