<!-- SIMKA PRO | src/pages/laporan/Laporan.vue | v1.3 | Fase 8 – Tahap 3 tab Kehadiran santri; menu Dokumen | 10/10/2026 -->
<script setup>
// Menu Dokumen: satu menu bertab untuk semua rekap dan laporan resmi (hemat menu sidebar).
// Tab: Presensi harian (admin/superadmin; dahulu menu Rekap Presensi), Kehadiran pegawai (semua pegawai: dirinya;
// pimpinan: bidangnya; admin, Direktur, Wadir, Yayasan: seluruh pondok), Dokumen resmi (registri dokumen bertanda
// tangan elektronik), Kehadiran santri (pengasuh: kelompok asuhannya). Rekap bulanan/periode lama diganti tab Kehadiran pegawai. Laporan modul lain menyusul di sini.
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { PhSealCheck, PhCalendarCheck, PhUsersThree, PhStudent } from '@phosphor-icons/vue'
import { useSesi } from '@/stores/sesi'
import BilahTab from '@/components/BilahTab.vue'
import RekapPresensi from '@/pages/rekap/RekapPresensi.vue'
import TabKehadiranPegawai from './TabKehadiranPegawai.vue'
import TabDokumenResmi from './TabDokumenResmi.vue'
import TabKehadiranSantri from './TabKehadiranSantri.vue'

const props = defineProps({ tab: { type: String, default: '' } })
const router = useRouter(); const sesi = useSesi()
const TAB = computed(() => [
  ...(sesi.isAdmin ? [{ k: 'harian', n: 'Presensi harian', ikon: PhCalendarCheck, w: 'presensi' }] : []),
  { k: 'pegawai', n: sesi.isAdmin || sesi.pimpinanTinggi ? 'Kehadiran pegawai' : 'Kehadiran saya', ikon: PhUsersThree, w: 'pegawai' },
  // Kehadiran santri: pemantau (admin, pimpinan, pemegang hak data santri) dan pengasuh kelompok
  ...(sesi.isAdmin || sesi.pimpinanTinggi || sesi.luas('data_santri') || sesi.kelompokSaya.length ? [{ k: 'santri', n: 'Kehadiran santri', ikon: PhStudent, w: 'santri' }] : []),
  { k: 'dokumen', n: 'Dokumen resmi', ikon: PhSealCheck, w: 'verifikasi' },
])
const ALIAS = { periode: 'pegawai' }
const aktif = computed({
  get: () => { const t = ALIAS[props.tab] || props.tab; return TAB.value.some((x) => x.k === t) ? t : TAB.value[0].k },
  set: (k) => router.replace(`/rekap/${k}`),
})
</script>
<template>
  <div class="space-y-4">
    <BilahTab v-model="aktif" :tab="TAB" label="Bagian rekap" />
    <RekapPresensi v-if="aktif === 'harian'" tab="harian" tertanam />
    <TabKehadiranPegawai v-else-if="aktif === 'pegawai'" />
    <TabKehadiranSantri v-else-if="aktif === 'santri'" />
    <TabDokumenResmi v-else-if="aktif === 'dokumen'" />
  </div>
</template>
