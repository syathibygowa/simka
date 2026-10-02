<script setup>
// Kartu sapaan beranda: gradasi merah pondok dengan pola khatam, tanggal Masehi dan Hijriah.
import { ref, onMounted, onBeforeUnmount } from 'vue'
import { useSesi } from '@/stores/sesi'
import { formatHari, formatHijriah, formatJam, salamWaktu, sekarang } from '@/lib/tanggal'
import PolaKhatam from '@/components/PolaKhatam.vue'
defineProps({ keterangan: String })
const sesi = useSesi()
const kini = ref(sekarang()); let t
onMounted(() => (t = setInterval(() => (kini.value = sekarang()), 1000)))
onBeforeUnmount(() => clearInterval(t))
const PERAN = { superadmin: 'Superadmin', admin: 'Admin', pegawai: 'Pegawai' }
</script>
<template>
  <section class="sapaan relative overflow-hidden rounded-[1.5rem] p-5 text-white sm:p-7">
    <PolaKhatam :opasitas="0.13" :ukuran="58" />
    <div class="relative flex flex-wrap items-end justify-between gap-5">
      <div class="min-w-0">
        <p class="text-sm font-semibold text-white/90">{{ salamWaktu() }},</p>
        <h2 class="mt-0.5 text-2xl font-extrabold leading-tight text-white sm:text-[1.9rem]">{{ sesi.pengguna?.nama_lengkap }}</h2>
        <p class="mt-1.5 text-sm text-white/90">{{ PERAN[sesi.peran] }} – {{ sesi.pengguna?.jabatan }}</p>
        <p v-if="keterangan" class="mt-3 max-w-xl text-[0.95rem] text-white">{{ keterangan }}</p>
      </div>
      <div class="text-left sm:text-right">
        <p class="text-[2.4rem] font-extrabold leading-none tabular-nums tracking-tight">{{ formatJam(kini) }}<span class="ml-1 text-base font-bold">WITA</span></p>
        <p class="mt-1.5 text-sm font-semibold">{{ formatHari(kini) }}</p>
        <p class="text-sm text-white/90">{{ formatHijriah(kini) }}</p>
      </div>
    </div>
    <div class="relative"><slot /></div>
  </section>
</template>
<style scoped>.sapaan { background: var(--gradasi-utama); }</style>
