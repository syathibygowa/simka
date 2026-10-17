<!-- SIMKA PRO | src/pages/laporan/Laporan.vue | v1.6 | Perbaikan 14.0.0: pemantau termasuk pemegang Dokumen tingkat Input/ubah | 17/10/2026 -->
<script setup>
// Menu Dokumen: satu menu bertab untuk semua rekap dan laporan resmi (hemat menu sidebar).
// Tab: Presensi harian (admin/superadmin; dahulu menu Rekap Presensi), Kehadiran pegawai (semua pegawai: dirinya;
// pimpinan: bidangnya; admin, Direktur, Wadir, Yayasan: seluruh pondok), Dokumen resmi (registri dokumen bertanda
// tangan elektronik), Tanda tangan (kotak masuk permintaan tanda tangan laporan resmi), Kehadiran santri (pengasuh: kelompok asuhannya). Rekap bulanan/periode lama diganti tab Kehadiran pegawai. Laporan modul lain menyusul di sini.
import { computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { PhSealCheck, PhCalendarCheck, PhUsersThree, PhStudent, PhSquaresFour, PhSignature } from '@phosphor-icons/vue'
import { useSesi } from '@/stores/sesi'
import { useDokumenResmi } from '@/stores/dokumenResmi'
import BilahTab from '@/components/BilahTab.vue'
import RekapPresensi from '@/pages/rekap/RekapPresensi.vue'
import TabKehadiranPegawai from './TabKehadiranPegawai.vue'
import TabDokumenResmi from './TabDokumenResmi.vue'
import TabKehadiranSantri from './TabKehadiranSantri.vue'
import TabRekapLayanan from './TabRekapLayanan.vue'
import TabTandaTangan from './TabTandaTangan.vue'

const props = defineProps({ tab: { type: String, default: '' } })
const router = useRouter(); const sesi = useSesi(); const dr = useDokumenResmi()
onMounted(() => dr.muatMasuk().catch(() => {}))
// Pemantau seluruh pegawai/santri: admin, pimpinan (anggota unitnya), dan pemegang Dokumen tingkat Input/ubah (Hak Akses)
const pantau = computed(() => sesi.isAdmin || sesi.pimpinanTinggi || sesi.tingkat('laporan') >= 2)
const lihatPresensi = computed(() => sesi.isAdmin || ['verval_presensi', 'atur_presensi', 'data_pegawai'].some((k) => sesi.tingkat(k) >= 1) || sesi.tingkat('laporan') >= 2)
const TAB = computed(() => [
  ...(lihatPresensi.value ? [{ k: 'harian', n: 'Presensi harian', ikon: PhCalendarCheck, w: 'presensi' }] : []),
  { k: 'pegawai', n: pantau.value ? 'Kehadiran pegawai' : 'Kehadiran saya', ikon: PhUsersThree, w: 'pegawai' },
  // Kehadiran santri: pemantau (admin, pimpinan, pemegang hak data santri) dan pengasuh kelompok
  ...(pantau.value || sesi.luas('data_santri') || sesi.kelompokSaya.length ? [{ k: 'santri', n: 'Kehadiran santri', ikon: PhStudent, w: 'santri' }] : []),
  // Rekap layanan: Security, libur santri, pengajuan pegawai, klinik (pilihan sesuai hak)
  { k: 'layanan', n: 'Rekap layanan', ikon: PhSquaresFour, w: 'security' },
  { k: 'dokumen', n: 'Dokumen resmi', ikon: PhSealCheck, w: 'verifikasi' },
  // Tanda tangan: pimpinan, admin, dan siapa pun yang pernah diminta tanda tangan
  ...(sesi.isAdmin || sesi.pimpinanTinggi || dr.masuk.length || props.tab === 'tandatangan'
    ? [{ k: 'tandatangan', n: dr.menunggu.length ? `Tanda tangan (${dr.menunggu.length})` : 'Tanda tangan', ikon: PhSignature, w: 'pengajuan' }] : []),
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
    <TabRekapLayanan v-else-if="aktif === 'layanan'" />
    <TabDokumenResmi v-else-if="aktif === 'dokumen'" />
    <TabTandaTangan v-else-if="aktif === 'tandatangan'" />
  </div>
</template>
