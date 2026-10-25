<!-- SIMKA PRO | src/pages/tahfizh/Tahfizh.vue | v1.11 | 14.26.0: warna tab tidak kembar (gaya tab seragam) | 25/10/2026 -->
<script setup>
// Menu Tahfizh. Tahap D: tab Dokumen (dokumen tahfizh bernomor; terbuka juga bagi penguji dan Tata Usaha). Fase 12: tab Rapor (catatan muhaffizh per halaqah); UTAS di tab Ujian. Tahap 5: tab Laporan (15 laporan dan grafik). Tahap 4: tab Ujian (kenaikan juz, sertifikasi). Tahap 3: tab Capaian (status bulanan, usulan juz). Tahap 2: tab Setoran (sesi halaqah per tanggal). Tahap 1: tab Data hafalan (program, posisi, capaian juz resmi, data awal) dan
// Ketentuan (KKM, target, predikat, pekan efektif, penguji; diubah oleh pemegang izin atur_tahfizh).
// Tab Setoran, Capaian, Ujian, dan Laporan ditambahkan pada tahap berikutnya.
import { computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { PhBookOpenText, PhListChecks, PhLockSimple, PhNotebook, PhSealCheck, PhExam, PhChartPieSlice, PhNotePencil, PhCertificate, PhCrown, PhUserSound } from '@phosphor-icons/vue'
import { useTahfizh } from '@/stores/tahfizh'
import { useSesi } from '@/stores/sesi'
import BilahTab from '@/components/BilahTab.vue'
import TabSetoran from './TabSetoran.vue'
import TabSantriTahfizh from './TabSantriTahfizh.vue'
import TabCapaian from './TabCapaian.vue'
import TabUjian from './TabUjian.vue'
import TabLaporan from './TabLaporan.vue'
import TabRaporTahfizh from './TabRaporTahfizh.vue'
import TabKetentuanTahfizh from './TabKetentuanTahfizh.vue'
import TabDokumenTahfizh from './TabDokumenTahfizh.vue'
import TabKhataman from './TabKhataman.vue'
import TabTahsin from './TabTahsin.vue'

const props = defineProps({ tab: { type: String, default: '' } })
const router = useRouter(); const tz = useTahfizh(); const sesi = useSesi()
// Pengguna tanpa hak lihat tahfizh: penguji (UTAS/kenaikan/sertifikasi) membuka tab Ujian; penguji dan Tata Usaha membuka tab Dokumen
const penguji = computed(() => sesi.pengujiUtas || tz.hak.penguji_kenaikan || tz.hak.penguji_sertifikasi)
const terbatas = computed(() => tz.hakDimuat && !tz.hak.lihat)
const hanyaUtas = computed(() => terbatas.value && sesi.pengujiUtas && !tz.hak.penguji_kenaikan && !tz.hak.penguji_sertifikasi)
const bolehDokumen = computed(() => tz.hak.lihat || tz.hak.dokumen || penguji.value)
onMounted(() => tz.hakDimuat || tz.muatHak())
const TAB = [
  { k: 'setoran', n: 'Setoran', ikon: PhNotebook, w: 'presensi' },
  { k: 'tahsin', n: 'Tahsin', ikon: PhUserSound, w: 'tahsin' },
  { k: 'capaian', n: 'Capaian', ikon: PhSealCheck, w: 'pengajuan' },
  { k: 'ujian', n: 'Ujian', ikon: PhExam, w: 'agenda' },
  { k: 'khataman', n: 'Khataman', ikon: PhCrown, w: 'prestasi' },
  { k: 'laporan', n: 'Laporan', ikon: PhChartPieSlice, w: 'laporan' },
  { k: 'dokumen', n: 'Dokumen', ikon: PhCertificate, w: 'tatausaha' },
  { k: 'rapor', n: 'Rapor', ikon: PhNotePencil, w: 'rapor' },
  { k: 'santri', n: 'Data hafalan', ikon: PhBookOpenText, w: 'tahfizh' },
  { k: 'ketentuan', n: 'Ketentuan', ikon: PhListChecks, w: 'pengaturan' },
]
const tabTampil = computed(() => (!terbatas.value ? TAB : TAB.filter((t) => (t.k === 'ujian' && penguji.value) || (t.k === 'dokumen' && bolehDokumen.value))))
const aktif = computed(() => (tabTampil.value.some((t) => t.k === props.tab) ? props.tab : tabTampil.value[0]?.k || 'setoran'))
</script>
<template>
  <div>
    <BilahTab class="mb-4" :tab="tabTampil" :model-value="aktif" label="Bagian tahfizh" @update:model-value="(k) => router.replace(`/tahfizh/${k}`)" />

    <div v-if="terbatas && !tabTampil.length" class="kartu w-tahfizh flex items-center gap-3 p-5">
      <span class="chip-ikon h-11 w-11"><PhLockSimple :size="24" weight="duotone" /></span>
      <p class="text-sm text-teks2">Menu Tahfizh terbuka bagi muhaffizh (halaqah yang diasuh), pimpinan Bidang Tahfizh, admin, dan pemegang hak fitur Tahfizh.</p>
    </div>
    <template v-else>
      <TabSetoran v-if="aktif === 'setoran'" />
      <TabCapaian v-else-if="aktif === 'capaian'" />
      <TabUjian v-else-if="aktif === 'ujian'" :hanya-utas="hanyaUtas" />
      <TabLaporan v-else-if="aktif === 'laporan'" />
      <TabDokumenTahfizh v-else-if="aktif === 'dokumen'" />
      <TabKhataman v-else-if="aktif === 'khataman'" />
      <TabTahsin v-else-if="aktif === 'tahsin'" />
      <TabRaporTahfizh v-else-if="aktif === 'rapor'" />
      <TabSantriTahfizh v-else-if="aktif === 'santri'" />
      <TabKetentuanTahfizh v-else />
    </template>
  </div>
</template>
