<!-- SIMKA PRO | src/pages/pengaturan/Pengaturan.vue | v1.1 | Fase 3 – Tahap 5 Agenda dan template WA | 04/10/2026 -->
<script setup>
// Menu Pengaturan lembaga (superadmin). Setiap tab memiliki ikon dan warna sendiri.
import { computed, onMounted, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { PhBuildings, PhCalendarDots, PhStamp, PhSignature, PhHash, PhPlugsConnected, PhWhatsappLogo } from '@phosphor-icons/vue'
import { useLembaga } from '@/stores/lembaga'
import TabIdentitas from './TabIdentitas.vue'
import TabKalender from './TabKalender.vue'
import TabKop from './TabKop.vue'
import TabPenandaTangan from './TabPenandaTangan.vue'
import TabPenomoran from './TabPenomoran.vue'
import TabIntegrasi from './TabIntegrasi.vue'
import TabTemplateWA from './TabTemplateWA.vue'

const props = defineProps({ tab: { type: String, default: 'identitas' } })
const router = useRouter()
const lembaga = useLembaga()
onMounted(async () => {
  lembaga.muat(true)
  await nextTick()
  document.querySelector('[role=tab][aria-selected=true]')?.scrollIntoView({ inline: 'center', block: 'nearest' })
})

const TAB = [
  { k: 'identitas', n: 'Identitas lembaga', ikon: PhBuildings, w: 'pengaturan', komp: TabIdentitas },
  { k: 'kalender', n: 'Tahun ajaran dan kalender', ikon: PhCalendarDots, w: 'tahfizh', komp: TabKalender },
  { k: 'kop', n: 'Kop surat', ikon: PhStamp, w: 'laporan', komp: TabKop },
  { k: 'penanda-tangan', n: 'Penanda tangan', ikon: PhSignature, w: 'pengajuan', komp: TabPenandaTangan },
  { k: 'penomoran', n: 'Penomoran dokumen', ikon: PhHash, w: 'santri', komp: TabPenomoran },
  { k: 'template-wa', n: 'Template WA', ikon: PhWhatsappLogo, w: 'presensi', komp: TabTemplateWA },
  { k: 'integrasi', n: 'Integrasi', ikon: PhPlugsConnected, w: 'sistem', komp: TabIntegrasi },
]
const aktif = computed(() => TAB.find((t) => t.k === props.tab) || TAB[0])
const pilih = (k) => router.replace(`/pengaturan/${k}`)
</script>
<template>
  <div class="lg:grid lg:grid-cols-[250px_1fr] lg:gap-6">
    <!-- Tab: chip bergulir di HP, daftar tegak di desktop -->
    <nav class="-mx-4 mb-4 flex gap-2 overflow-x-auto px-4 pb-1 lg:sticky lg:top-[96px] lg:mx-0 lg:mb-0 lg:h-fit lg:flex-col lg:overflow-visible lg:px-0" role="tablist" aria-label="Bagian pengaturan">
      <button v-for="t in TAB" :key="t.k" role="tab" :aria-selected="aktif.k === t.k" @click="pilih(t.k)"
        :class="['tab flex min-h-[44px] shrink-0 items-center gap-2.5 rounded-xl border px-3 text-left text-sm font-semibold transition', 'w-' + t.w,
                 aktif.k === t.k ? 'aktif text-teks' : 'border-garis bg-permukaan text-teks2 hover:text-teks lg:border-transparent lg:bg-transparent lg:hover:bg-permukaan2']">
        <span class="chip-ikon h-8 w-8 rounded-lg"><component :is="t.ikon" :size="20" weight="duotone" /></span>
        <span class="whitespace-nowrap">{{ t.n }}</span>
      </button>
    </nav>
    <section :class="'w-' + aktif.w" role="tabpanel" :aria-label="aktif.n">
      <div class="mb-4 hidden items-center gap-3 lg:flex">
        <span class="chip-ikon h-11 w-11"><component :is="aktif.ikon" :size="26" weight="duotone" /></span>
        <h2 class="text-lg font-bold">{{ aktif.n }}</h2>
      </div>
      <p v-if="!lembaga.dimuat" class="py-10 text-center text-teks3">Memuat pengaturan…</p>
      <component :is="aktif.komp" v-else :key="aktif.k" />
    </section>
  </div>
</template>
<style scoped>
.tab.aktif { border-color: color-mix(in srgb, var(--c) 35%, transparent); background: color-mix(in srgb, var(--c) 12%, rgb(var(--permukaan))); }
</style>
