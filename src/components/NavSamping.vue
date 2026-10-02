<script setup>
// Sidebar desktop: menu berkelompok, setiap menu dengan ikon dan warna sendiri.
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { useSesi } from '@/stores/sesi'
import { useNotifikasi } from '@/stores/notifikasi'
import { menuUntuk, GRUP } from '@/lib/menu'
import LogoSimka from './LogoSimka.vue'
import PolaKhatam from './PolaKhatam.vue'

const sesi = useSesi()
const notif = useNotifikasi()
const route = useRoute()
const kelompok = computed(() => {
  const m = menuUntuk(sesi.peran).filter((x) => x.kode !== 'profil')
  return GRUP.map((g) => ({ g, item: m.filter((x) => x.grup === g) })).filter((k) => k.item.length)
})
const aktif = (m) => (m.ke === '/' ? route.path === '/' : route.path.startsWith(m.ke))
</script>
<template>
  <aside class="layar-saja fixed inset-y-0 left-0 z-30 hidden w-[272px] flex-col border-r border-garis bg-permukaan lg:flex">
    <div class="relative overflow-hidden px-5 pb-4 pt-5 text-[#C7332F] dark:text-[#FF8070]">
      <PolaKhatam :opasitas="0.08" :ukuran="44" />
      <router-link to="/" class="relative flex items-center gap-3">
        <LogoSimka :size="42" />
        <span>
          <span class="block text-[1.05rem] font-extrabold leading-tight text-teks">SIMKA PRO</span>
          <span class="block text-xs font-medium leading-tight text-teks2">Imam Asy-Syathiby Gowa</span>
        </span>
      </router-link>
    </div>
    <nav class="flex-1 overflow-y-auto px-3 pb-6" aria-label="Menu utama">
      <div v-for="k in kelompok" :key="k.g" class="mt-3">
        <p class="px-3 pb-1 text-xs font-semibold text-teks3">{{ k.g }}</p>
        <router-link v-for="m in k.item" :key="m.kode" :to="m.ke"
          :class="['menu group flex min-h-[44px] items-center gap-3 rounded-xl px-3 text-[0.93rem] font-semibold', 'w-' + m.warna, aktif(m) ? 'aktif text-teks' : 'text-teks2 hover:bg-permukaan2 hover:text-teks']"
          :aria-current="aktif(m) ? 'page' : undefined">
          <span class="chip-ikon h-8 w-8 rounded-lg"><component :is="m.ikon" :size="20" weight="duotone" /></span>
          <span class="flex-1 truncate">{{ m.nama }}</span>
          <span v-if="m.kode === 'notifikasi' && notif.belumDibaca" class="rounded-full bg-[#C7332F] px-1.5 text-xs font-bold leading-5 text-white">{{ notif.belumDibaca }}</span>
          <span v-else-if="m.fase" class="text-[11px] font-semibold text-teks3">Fase {{ m.fase }}</span>
        </router-link>
      </div>
    </nav>
  </aside>
</template>
<style scoped>
.menu.aktif { background: color-mix(in srgb, var(--c) 12%, rgb(var(--permukaan))); box-shadow: inset 3px 0 0 var(--c); }
</style>
