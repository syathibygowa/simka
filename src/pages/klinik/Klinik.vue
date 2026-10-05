<!-- SIMKA PRO | src/pages/klinik/Klinik.vue | v1.0 | Fase 6 – Tahap 1 Dasar Klinik | 06/10/2026 -->
<script setup>
// Menu Klinik (Blueprint Bagian 21). Klinik Putra dan Putri dipisah.
//   Tenaga klinik (petugas, pengelola, pimpinan Kesantrian): Antrean, Dirawat, Riwayat, Ketentuan.
//   Pengasuh/pegawai lain yang dapat melihat santri: Rujukan (merujuk santri asuhan dan memantau statusnya).
import { computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { PhHourglass, PhBed, PhClockCounterClockwise, PhListChecks, PhPaperPlaneTilt, PhLockSimple } from '@phosphor-icons/vue'
import { useKlinik } from '@/stores/klinik'
import BilahTab from '@/components/BilahTab.vue'
import TabKasus from './TabKasus.vue'
import TabKetentuanKlinik from './TabKetentuanKlinik.vue'

const props = defineProps({ tab: { type: String, default: '' } })
const router = useRouter(); const kl = useKlinik()
onMounted(() => kl.hakDimuat || kl.muatHak())
const TAB = computed(() => [
  ...(kl.tenagaKlinik ? [
    { k: 'antrean', n: 'Antrean', ikon: PhHourglass, w: 'pengajuan' },
    { k: 'dirawat', n: 'Dirawat', ikon: PhBed, w: 'klinik' },
    { k: 'riwayat', n: 'Riwayat', ikon: PhClockCounterClockwise, w: 'laporan' },
  ] : []),
  ...(kl.hak.rujuk ? [{ k: 'rujukan', n: kl.tenagaKlinik ? 'Rujukan saya' : 'Rujukan', ikon: PhPaperPlaneTilt, w: 'santri' }] : []),
  { k: 'ketentuan', n: 'Ketentuan', ikon: PhListChecks, w: 'pengaturan' },
])
const aktif = computed(() => (TAB.value.some((t) => t.k === props.tab) ? props.tab : TAB.value[0].k))
</script>
<template>
  <div>
    <div v-if="kl.hakDimuat && !kl.hak.lihat" class="kartu w-klinik flex items-center gap-3 p-5">
      <span class="chip-ikon h-11 w-11"><PhLockSimple :size="24" weight="duotone" /></span>
      <p class="text-sm text-teks2">Menu Klinik terbuka bagi petugas klinik, pimpinan Kesantrian, admin, dan pengasuh santri (wali kelas, musyrif, muhaffizh, pembina).</p>
    </div>
    <template v-else-if="kl.hakDimuat">
      <BilahTab class="mb-4" :tab="TAB" :model-value="aktif" label="Bagian klinik" @update:model-value="(k) => router.replace(`/klinik/${k}`)" />
      <TabKetentuanKlinik v-if="aktif === 'ketentuan'" />
      <TabKasus v-else :key="aktif" :cakupan="aktif === 'rujukan' ? 'rujukan_saya' : aktif" />
    </template>
  </div>
</template>
