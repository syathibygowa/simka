<!-- SIMKA PRO | src/components/PanelNotifikasi.vue | v1.1 | Fase 7 – Perbaikan uji coba: lonceng hanya belum dibaca | 06/10/2026 -->
<script setup>
// Lonceng notifikasi. Desktop: panel tarik-turun berisi HANYA notifikasi yang belum dibaca (riwayat lengkap di halaman
// Notifikasi). Mobile: membuka halaman Notifikasi.
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import { useRouter } from 'vue-router'
import { PhBell, PhChecks } from '@phosphor-icons/vue'
import { useNotifikasi } from '@/stores/notifikasi'
import ItemNotifikasi from './ItemNotifikasi.vue'

const notif = useNotifikasi()
const router = useRouter()
const buka = ref(false)
const belum = computed(() => notif.daftar.filter((n) => !n.dibaca_pada).slice(0, 30))
const akar = ref(null)
const lebar = () => window.matchMedia('(min-width: 1024px)').matches
function klik() { lebar() ? (buka.value = !buka.value) : router.push('/notifikasi') }
const luar = (e) => { if (akar.value && !akar.value.contains(e.target)) buka.value = false }
onMounted(() => document.addEventListener('pointerdown', luar))
onBeforeUnmount(() => document.removeEventListener('pointerdown', luar))
</script>
<template>
  <div ref="akar" class="relative w-notifikasi">
    <button type="button" class="tombol-ikon relative" @click="klik" :aria-expanded="buka"
      :aria-label="notif.belumDibaca ? `Notifikasi, ${notif.belumDibaca} belum dibaca` : 'Notifikasi'">
      <PhBell :size="24" weight="duotone" :style="{ color: notif.belumDibaca ? 'var(--c)' : undefined }" />
      <span v-if="notif.belumDibaca" class="absolute right-1.5 top-1.5 grid h-[18px] min-w-[18px] place-items-center rounded-full bg-[#C7332F] px-1 text-[11px] font-bold text-white ring-2 ring-permukaan">
        {{ notif.belumDibaca > 99 ? '99+' : notif.belumDibaca }}
      </span>
    </button>
    <Transition name="turun">
      <div v-if="buka" class="absolute right-0 top-12 z-40 w-[400px] overflow-hidden rounded-[1.25rem] border border-garis bg-permukaan shadow-apung">
        <div class="flex items-center justify-between border-b border-garis px-4 py-3">
          <div>
            <p class="font-bold">Notifikasi</p>
            <p class="text-xs text-teks3">{{ notif.belumDibaca ? `${notif.belumDibaca} belum dibaca` : 'Semua sudah dibaca' }}</p>
          </div>
          <button v-if="notif.belumDibaca" class="tombol-teks h-9 min-h-0 text-sm" @click="notif.tandaiSemua()">
            <PhChecks :size="18" weight="bold" /> Tandai semua dibaca
          </button>
        </div>
        <ul class="max-h-[60vh] space-y-1 overflow-y-auto p-2">
          <ItemNotifikasi v-for="n in belum" :key="n.id" :n="n" ringkas @dibuka="buka = false" />
          <li v-if="!belum.length" class="px-4 py-10 text-center text-sm text-teks3">Tidak ada notifikasi baru. Riwayat lengkap ada di halaman Notifikasi.</li>
        </ul>
        <router-link to="/notifikasi" class="block border-t border-garis py-3 text-center text-sm font-semibold text-merah hover:bg-permukaan2" @click="buka = false">
          Lihat semua notifikasi (riwayat)
        </router-link>
      </div>
    </Transition>
  </div>
</template>
<style scoped>
.turun-enter-active, .turun-leave-active { transition: opacity .15s, transform .15s; }
.turun-enter-from, .turun-leave-to { opacity: 0; transform: translateY(-6px); }
</style>
