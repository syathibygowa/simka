<!-- SIMKA PRO | src/pages/wali/MasukWali.vue | v1.1 | Fase 9 – Perbaikan: keterangan nomor HP dan tambah anak dihapus | 15/10/2026 -->
<script setup>
// Halaman Masuk Portal Wali (tampil bila belum ada anak tersimpan di perangkat ini).
import { PhLockKey } from '@phosphor-icons/vue'
import { usePortalWali } from '@/stores/portalWali'
import { formatHari, formatHijriah } from '@/lib/tanggal'
import LogoSimka from '@/components/LogoSimka.vue'
import PolaKhatam from '@/components/PolaKhatam.vue'
import PilihTema from '@/components/PilihTema.vue'
import FormMasukWali from './FormMasukWali.vue'

const emit = defineEmits(['selesai'])
const pw = usePortalWali()
</script>

<template>
  <div class="grid min-h-dvh lg:grid-cols-[1.05fr_1fr]">
    <section class="panel-merek relative overflow-hidden px-6 pb-16 pt-[max(2.5rem,env(safe-area-inset-top))] text-white lg:flex lg:flex-col lg:justify-between lg:p-14">
      <PolaKhatam :opasitas="0.14" :ukuran="64" />
      <div class="relative flex items-center gap-3">
        <span class="grid h-14 w-14 place-items-center rounded-2xl bg-white"><LogoSimka :size="40" /></span>
        <div>
          <p class="text-xl font-extrabold leading-tight">Portal Wali Santri</p>
          <p class="text-sm text-white/90">SIMKA PRO · Imam Asy-Syathiby Gowa</p>
        </div>
      </div>
      <div class="relative mt-10 lg:mt-0">
        <p class="max-w-md text-[1.75rem] font-extrabold leading-[1.15] lg:text-[2.4rem]">Pantau perkembangan ananda di pondok</p>
        <p class="mt-3 max-w-md text-white/90">Kehadiran, hafalan, dan informasi pondok untuk orang tua dan wali santri.</p>
      </div>
      <p class="relative mt-8 hidden text-sm text-white/90 lg:block">{{ formatHari(new Date()) }}, {{ formatHijriah() }}</p>
    </section>

    <section class="relative -mt-8 rounded-t-[2rem] bg-latar px-5 pb-10 pt-8 sm:px-10 lg:mt-0 lg:flex lg:items-center lg:justify-center lg:rounded-none">
      <div class="mx-auto w-full max-w-md">
        <h1 class="text-2xl font-extrabold">Masuk Portal Wali</h1>
        <p class="mt-1 text-teks2">Gunakan data santri dan nomor HP orang tua/wali yang terdaftar di pondok.</p>
        <p v-if="pw.pesanKeluar" class="mt-4 rounded-xl bg-[#B45309]/10 px-3.5 py-2.5 text-sm font-semibold text-teks" role="status">{{ pw.pesanKeluar }}</p>
        <p v-if="pw.tutup" class="w-pengajuan mt-4 flex gap-2.5 rounded-xl border border-garis bg-permukaan px-3.5 py-3 text-sm font-semibold" role="status">
          <PhLockKey :size="20" weight="duotone" style="color: var(--c)" class="shrink-0" /> {{ pw.tutup }}</p>

        <FormMasukWali class="mt-6" @selesai="emit('selesai', $event)" />


        <div class="mt-8"><PilihTema /></div>
        <p class="mt-6 text-center text-sm text-teks2">Pegawai pondok? <router-link to="/masuk" class="font-semibold text-merah">Masuk akun pegawai</router-link></p>
      </div>
    </section>
  </div>
</template>
<style scoped>.panel-merek { background: var(--gradasi-utama); }</style>
