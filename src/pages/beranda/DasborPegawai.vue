<script setup>
import { computed } from 'vue'
import { PhFingerprint, PhCaretRight, PhSquaresFour } from '@phosphor-icons/vue'
import { useRouter } from 'vue-router'
import { useNotifikasi } from '@/stores/notifikasi'
import { useSesi } from '@/stores/sesi'
import { menuUntuk } from '@/lib/menu'
import Sapaan from './Sapaan.vue'
import ItemNotifikasi from '@/components/ItemNotifikasi.vue'
import TombolAksi from '@/components/TombolAksi.vue'

const notif = useNotifikasi(); const sesi = useSesi(); const router = useRouter()
const menu = computed(() => menuUntuk(sesi.peran).filter((m) => !['beranda', 'notifikasi', 'profil'].includes(m.kode)).slice(0, 8))
</script>
<template>
  <div class="space-y-5 lg:space-y-6">
    <Sapaan>
      <router-link to="/presensi" class="mt-5 flex items-center gap-4 rounded-2xl bg-white p-3.5 pr-4 text-[#1F1416] shadow-apung">
        <span class="grid h-14 w-14 shrink-0 place-items-center rounded-2xl bg-[#E2F1E8] text-[#1E7D4F]"><PhFingerprint :size="32" weight="duotone" /></span>
        <span class="flex-1">
          <span class="block text-lg font-extrabold leading-tight">Presensi hari ini</span>
          <span class="block text-sm text-[#544245]">Presensi GPS dengan selfie dibuka pada Fase 2</span>
        </span>
        <PhCaretRight :size="22" class="text-[#705E61]" />
      </router-link>
    </Sapaan>

    <div class="grid gap-4 lg:grid-cols-[1.4fr_1fr] lg:gap-6">
      <section class="kartu p-3 sm:p-4">
        <div class="mb-1 flex items-center justify-between px-2">
          <h2 class="judul-bagian">Notifikasi terbaru</h2>
          <router-link to="/notifikasi" class="tombol-teks h-9 min-h-0 text-sm">Lihat semua</router-link>
        </div>
        <ul class="space-y-1">
          <ItemNotifikasi v-for="n in notif.terbaru" :key="n.id" :n="n" ringkas />
          <li v-if="!notif.daftar.length" class="py-8 text-center text-sm text-teks3">Belum ada notifikasi.</li>
        </ul>
      </section>
      <section class="kartu p-5">
        <h2 class="judul-bagian mb-3">Menu kerja</h2>
        <ul class="grid grid-cols-4 gap-y-4">
          <li v-for="m in menu" :key="m.kode" :class="'w-' + m.warna">
            <router-link :to="m.ke" class="flex flex-col items-center gap-1.5 text-center">
              <span class="chip-ikon h-12 w-12 rounded-2xl"><component :is="m.ikon" :size="26" weight="duotone" /></span>
              <span class="text-xs font-semibold leading-tight text-teks2">{{ m.nama }}</span>
            </router-link>
          </li>
        </ul>
      </section>
    </div>
    <TombolAksi label="Presensi" :ikon="PhFingerprint" warna="presensi" @klik="router.push('/presensi')" />
  </div>
</template>
