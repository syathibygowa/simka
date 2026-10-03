<!-- SIMKA PRO | src/components/TataLetakAuth.vue | v1.0 | Fase 1 – Akun dan hak akses | 03/10/2026 -->
<script setup>
// Kerangka halaman di luar aplikasi (daftar, lupa sandi, atur sandi, ganti sandi).
import LogoSimka from './LogoSimka.vue'
import PolaKhatam from './PolaKhatam.vue'
defineProps({ judul: String, keterangan: String, lebar: { type: String, default: 'max-w-md' } })
</script>
<template>
  <div class="min-h-dvh bg-latar">
    <header class="kepala relative overflow-hidden px-5 pb-14 pt-[max(1.5rem,env(safe-area-inset-top))] text-white">
      <PolaKhatam :opasitas="0.13" :ukuran="56" />
      <router-link to="/masuk" class="relative mx-auto flex max-w-3xl items-center gap-3">
        <span class="grid h-11 w-11 place-items-center rounded-xl bg-white"><LogoSimka :size="32" /></span>
        <span><span class="block font-extrabold leading-tight">SIMKA PRO</span><span class="block text-sm text-white/90">Imam Asy-Syathiby Gowa</span></span>
      </router-link>
    </header>
    <main :class="['relative mx-auto -mt-8 px-4 pb-12', lebar]">
      <div class="kartu p-5 sm:p-7">
        <h1 class="text-2xl font-extrabold">{{ judul }}</h1>
        <p v-if="keterangan" class="mt-1 text-teks2">{{ keterangan }}</p>
        <div class="mt-5"><slot /></div>
      </div>
      <div class="mt-4 text-center text-sm"><slot name="bawah" /></div>
    </main>
  </div>
</template>
<style scoped>.kepala { background: var(--gradasi-utama); }</style>
