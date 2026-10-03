<!-- SIMKA PRO | src/pages/presensi/AturPresensi.vue | v1.0 | Fase 2 – Tahap 3 Pengaturan presensi | 03/10/2026 -->
<script setup>
// Pengaturan Presensi (admin dan superadmin): titik GPS, pola sesi, jadwal pegawai, dan aturan umum.
// Setiap tab memiliki ikon dan warna sendiri.
import { ref, computed, onMounted, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { PhMapPinArea, PhClockCountdown, PhCalendarCheck, PhSlidersHorizontal } from '@phosphor-icons/vue'
import { useAturPresensi } from '@/stores/aturPresensi'
import { useOrganisasi } from '@/stores/organisasi'
import { usePegawai } from '@/stores/pegawai'
import { useLembaga } from '@/stores/lembaga'
import TabTitik from './TabTitik.vue'
import TabPola from './TabPola.vue'
import TabJadwal from './TabJadwal.vue'
import TabUmum from './TabUmum.vue'

const props = defineProps({ tab: { type: String, default: 'titik' } })
const router = useRouter()
const atur = useAturPresensi(); const org = useOrganisasi(); const peg = usePegawai(); const lembaga = useLembaga()
const galat = ref('')
onMounted(async () => {
  try { await Promise.all([org.muat(), lembaga.muat(), peg.daftar.length ? null : peg.muat()]); await atur.muat(true) }
  catch (e) { galat.value = e.message }
  await nextTick(); document.querySelector('[role=tab][aria-selected=true]')?.scrollIntoView({ inline: 'center', block: 'nearest' })
})
const TAB = [
  { k: 'titik', n: 'Titik GPS', ikon: PhMapPinArea, w: 'santri', komp: TabTitik },
  { k: 'pola', n: 'Pola dan sesi', ikon: PhClockCountdown, w: 'tahfizh', komp: TabPola },
  { k: 'jadwal', n: 'Jadwal pegawai', ikon: PhCalendarCheck, w: 'pegawai', komp: TabJadwal },
  { k: 'umum', n: 'Aturan umum', ikon: PhSlidersHorizontal, w: 'pengaturan', komp: TabUmum },
]
const aktif = computed(() => TAB.find((t) => t.k === props.tab) || TAB[0])
</script>
<template>
  <div>
    <nav class="layar-saja -mx-4 mb-4 flex gap-2 overflow-x-auto px-4 pb-1 lg:mx-0 lg:px-0" role="tablist" aria-label="Bagian pengaturan presensi">
      <button v-for="t in TAB" :key="t.k" role="tab" :aria-selected="aktif.k === t.k" @click="router.replace(`/atur-presensi/${t.k}`)"
        :class="['tab flex min-h-[44px] shrink-0 items-center gap-2.5 rounded-xl border px-3 text-sm font-semibold', 'w-' + t.w, aktif.k === t.k ? 'aktif text-teks' : 'border-garis bg-permukaan text-teks2 hover:text-teks']">
        <span class="chip-ikon h-8 w-8 rounded-lg"><component :is="t.ikon" :size="20" weight="duotone" /></span><span class="whitespace-nowrap">{{ t.n }}</span>
      </button>
    </nav>
    <p v-if="galat" class="rounded-xl bg-[#C7332F]/10 p-3 text-sm font-semibold text-merah">{{ galat }} Pastikan migrasi SQL presensi 1200–1500 sudah dijalankan di Supabase.</p>
    <p v-else-if="!atur.dimuat" class="py-10 text-center text-teks3">Memuat pengaturan presensi…</p>
    <section v-else :class="'w-' + aktif.w" role="tabpanel" :aria-label="aktif.n">
      <component :is="aktif.komp" :key="aktif.k" />
    </section>
  </div>
</template>
<style scoped>
.tab.aktif { border-color: color-mix(in srgb, var(--c) 35%, transparent); background: color-mix(in srgb, var(--c) 12%, rgb(var(--permukaan))); }
</style>
