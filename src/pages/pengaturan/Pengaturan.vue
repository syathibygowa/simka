<!-- SIMKA PRO | src/pages/pengaturan/Pengaturan.vue | v1.2 | Perbaikan 13.5.0: tab bergaris bawah | 15/10/2026 -->
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
  <div>
    <nav class="bilah-tab -mx-4 mb-4 px-4 lg:mx-0 lg:px-0" role="tablist" aria-label="Bagian pengaturan">
      <button v-for="t in TAB" :key="t.k" role="tab" :aria-selected="aktif.k === t.k" @click="pilih(t.k)" :class="['tab-garis', 'w-' + t.w, aktif.k === t.k && 'aktif']">
        <component :is="t.ikon" :size="20" weight="duotone" /><span>{{ t.n }}</span>
      </button>
    </nav>
    <section :class="'w-' + aktif.w" role="tabpanel" :aria-label="aktif.n">
      <p v-if="!lembaga.dimuat" class="py-10 text-center text-teks3">Memuat pengaturan…</p>
      <component :is="aktif.komp" v-else :key="aktif.k" />
    </section>
  </div>
</template>

