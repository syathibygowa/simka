<!-- SIMKA PRO | src/components/NavBawah.vue | v1.5 | Fase 4 – Perbaikan P3 (navigasi bawah 5 menu) | 05/10/2026 -->
<script setup>
// Navigasi bawah ala aplikasi Android: 5 menu (Beranda, Jurnal, Presensi, Tugas, Profil).
// Presensi di tengah tampil sebagai tombol bulat menonjol (seperti tombol QRIS pada aplikasi pembayaran).
import { useRoute } from 'vue-router'
import { NAV_BAWAH } from '@/lib/menu'
const route = useRoute()
const BUKAN_TUGAS = ['/', '/jurnal', '/presensi', '/profil']
const aktif = (t) => t.ke === '/' ? route.path === '/'
  : t.kode === 'tugas' ? !BUKAN_TUGAS.some((p) => (p === '/' ? route.path === '/' : route.path.startsWith(p)))
  : route.path.startsWith(t.ke)
</script>
<template>
  <nav class="layar-saja fixed inset-x-0 bottom-0 z-30 lg:hidden" style="padding-bottom: env(safe-area-inset-bottom)" aria-label="Navigasi utama">
    <div class="absolute inset-0 border-t border-garis bg-permukaan/95 backdrop-blur" aria-hidden="true" />
    <ul class="relative mx-auto grid max-w-xl grid-cols-5">
      <li v-for="t in NAV_BAWAH" :key="t.kode" :class="'w-' + t.warna">
        <router-link v-if="t.utama" :to="t.ke" class="flex h-[68px] flex-col items-center justify-end gap-1 pb-2" :aria-current="aktif(t) ? 'page' : undefined" :aria-label="t.nama">
          <span :class="['tombol-tengah -mt-7 grid h-[62px] w-[62px] place-items-center rounded-full text-white ring-4 ring-latar transition active:scale-95', aktif(t) && 'aktif']">
            <component :is="t.ikon" :size="32" weight="fill" />
          </span>
          <span :class="['text-[11px] leading-none', aktif(t) ? 'font-bold text-teks' : 'font-semibold text-teks2']">{{ t.nama }}</span>
        </router-link>
        <router-link v-else :to="t.ke" class="flex h-[68px] flex-col items-center justify-center gap-1" :aria-current="aktif(t) ? 'page' : undefined">
          <span :class="['pil grid h-8 w-14 place-items-center rounded-full transition', aktif(t) && 'aktif']">
            <component :is="t.ikon" :size="24" :weight="aktif(t) ? 'fill' : 'duotone'" :style="{ color: aktif(t) ? 'var(--c)' : undefined }" :class="!aktif(t) && 'text-teks2'" />
          </span>
          <span :class="['text-[11px] leading-none', aktif(t) ? 'font-bold text-teks' : 'font-medium text-teks2']">{{ t.nama }}</span>
        </router-link>
      </li>
    </ul>
  </nav>
</template>
<style scoped>
.pil.aktif { background: color-mix(in srgb, var(--c) 16%, rgb(var(--permukaan))); }
.tombol-tengah { background: linear-gradient(145deg, #C7332F 0%, #E0603A 55%, #F08A45 100%);
  box-shadow: 0 10px 22px -8px rgba(199, 51, 47, .65), inset 0 1px 0 rgba(255, 255, 255, .35); }
.tombol-tengah.aktif { background: linear-gradient(145deg, #A82824 0%, #C7332F 60%, #E0603A 100%); }
:global(html.dark) .tombol-tengah { box-shadow: 0 10px 24px -8px rgba(0, 0, 0, .8); }
</style>
