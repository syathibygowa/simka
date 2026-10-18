<!-- SIMKA PRO | src/pages/disiplin/DisiplinSantri.vue | v1.0 | 14.6.0: menu Kedisiplinan Santri (pelanggaran, surat peringatan, rekap, ketentuan) | 18/10/2026 -->
<script setup>
// Menu Kedisiplinan Santri, bertab:
//   Pelanggaran      : catatan pelanggaran tanpa poin (pengasuh santri, Security, Kesantrian, pemegang fitur); ?santri=<id> riwayat satu santri
//   Surat peringatan : SP-1/SP-2/SP-3 santri (usul Kesantrian → Tata Usaha → tanda tangan Direktur); ?sp=<id> membuka rinciannya
//   Rekap            : per santri, kelas, kamar, atau kategori; cetak F4 dan Excel
//   Ketentuan        : kategori dan tingkat pelanggaran, sanksi per SP, masa berlaku, penanda tangan, ambang pemberitahuan
import { computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { PhGavel, PhWarningOctagon, PhChartBar, PhListChecks, PhLockSimple } from '@phosphor-icons/vue'
import { useDisiplin } from '@/stores/disiplin'
import { useUI } from '@/stores/ui'
import BilahTab from '@/components/BilahTab.vue'
import TabPelanggaran from './TabPelanggaran.vue'
import TabSPSantri from './TabSPSantri.vue'
import TabRekapDisiplin from './TabRekapDisiplin.vue'
import TabKetentuanDisiplin from './TabKetentuanDisiplin.vue'

const props = defineProps({ tab: { type: String, default: '' } })
const router = useRouter(); const ds = useDisiplin(); const ui = useUI()
onMounted(async () => {
  try { await Promise.all([ds.hakDimuat ? null : ds.muatHak(), ds.set ? null : ds.muatSet()]) } catch (e) { ui.toast(e.message, 'galat') }
})
const TAB = computed(() => [
  { k: 'pelanggaran', n: 'Pelanggaran', ikon: PhGavel, w: 'disiplin' },
  { k: 'sp', n: 'Surat peringatan', ikon: PhWarningOctagon, w: 'laporan' },
  { k: 'rekap', n: 'Rekap', ikon: PhChartBar, w: 'rekap' },
  { k: 'ketentuan', n: 'Ketentuan', ikon: PhListChecks, w: 'pengaturan' },
])
const aktif = computed(() => (TAB.value.some((t) => t.k === props.tab) ? props.tab : 'pelanggaran'))
</script>
<template>
  <div class="w-disiplin">
    <div v-if="ds.hakDimuat && !ds.hak.tampil" class="kartu flex items-center gap-3 p-5">
      <span class="chip-ikon h-11 w-11"><PhLockSimple :size="24" weight="duotone" /></span>
      <p class="text-sm text-teks2">Kedisiplinan Santri terbuka bagi pengasuh santri (wali kelas, musyrif, muhaffizh, pembina ekskul), petugas Security, Bidang Kesantrian, pimpinan, Tata Usaha, dan pemegang hak Kedisiplinan santri.</p>
    </div>
    <template v-else-if="ds.hakDimuat">
      <div class="mb-4 hidden items-center gap-3 lg:flex">
        <span class="chip-ikon h-12 w-12"><PhGavel :size="28" weight="duotone" /></span>
        <div class="flex-1"><h2 class="text-lg font-bold">Kedisiplinan Santri</h2>
          <p class="text-sm text-teks3">Catatan pelanggaran tanpa poin dan Surat Peringatan SP-1 sampai SP-3 yang diproses Tata Usaha dan ditandatangani Direktur.</p></div>
      </div>
      <BilahTab class="mb-4" :tab="TAB" :model-value="aktif" label="Bagian kedisiplinan santri" @update:model-value="(k) => router.replace(`/disiplin-santri/${k}`)" />
      <TabPelanggaran v-if="aktif === 'pelanggaran'" />
      <TabSPSantri v-else-if="aktif === 'sp'" />
      <TabRekapDisiplin v-else-if="aktif === 'rekap'" />
      <TabKetentuanDisiplin v-else />
    </template>
    <p v-else class="kartu p-8 text-center text-sm text-teks3">Memuat…</p>
  </div>
</template>
