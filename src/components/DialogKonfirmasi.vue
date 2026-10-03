<!-- SIMKA PRO | src/components/DialogKonfirmasi.vue | v1.0 | Fase 1 – Pengaturan | 03/10/2026 -->
<script setup>
import { PhWarning, PhQuestion } from '@phosphor-icons/vue'
import { useUI } from '@/stores/ui'
const ui = useUI()
</script>
<template>
  <Teleport to="body">
    <div v-if="ui.dialog.buka" class="layar-saja fixed inset-0 z-[70] grid place-items-end p-0 sm:place-items-center sm:p-4" role="alertdialog" aria-modal="true" :aria-label="ui.dialog.judul">
      <div class="absolute inset-0 bg-black/45" @click="ui.jawab(false)" />
      <div :class="['relative w-full rounded-t-[1.75rem] bg-permukaan p-6 pb-[max(1.5rem,env(safe-area-inset-bottom))] shadow-apung sm:max-w-md sm:rounded-[1.5rem]', ui.dialog.bahaya ? 'w-beranda' : 'w-pegawai']">
        <span class="chip-ikon h-12 w-12"><component :is="ui.dialog.bahaya ? PhWarning : PhQuestion" :size="26" weight="duotone" /></span>
        <h2 class="mt-3 text-lg font-bold">{{ ui.dialog.judul }}</h2>
        <p class="mt-1 text-teks2">{{ ui.dialog.pesan }}</p>
        <div class="mt-5 grid grid-cols-2 gap-2">
          <button class="tombol-garis" @click="ui.jawab(false)">Batal</button>
          <button :class="ui.dialog.bahaya ? 'tombol-utama' : 'tombol-utama'" @click="ui.jawab(true)">{{ ui.dialog.ya }}</button>
        </div>
      </div>
    </div>
  </Teleport>
</template>
