<!-- SIMKA PRO | src/pages/persuratan/Persuratan.vue | v1.2 | Fase 10 – Penutup: buka revisi surat, buku agenda inventaris semua surat | 11/10/2026 -->
<script setup>
// Persuratan (Blueprint Bagian 35), satu menu bertab:
//   Untuk saya  : surat yang perlu saya disposisikan dan disposisi yang ditujukan kepada saya
//   Surat keluar: surat dari template, diperiksa TU, ditandatangani pejabat (elektronik/basah), nomor terbit saat sah
//   Surat masuk : seluruh surat masuk (Tata Usaha dan pimpinan puncak); TU mencatat dan meneruskan ke pimpinan
//   Buku agenda : surat masuk, dan inventaris SEMUA surat keluar (Persuratan + surat dari modul lain) per rentang tanggal; Excel, cetak F4
//   Template    : template surat (isi awal pedoman Wahdah Islamiyah; TU menyunting, menyalin, menambah)
//   Ketentuan   : pilihan instruksi disposisi dan batas waktu bawaan
// ?surat=<id> membuka rincian surat (dipakai notifikasi); pada tab Surat keluar ?resmi=<id dokumen> dari kotak Tanda tangan.
import { computed, onMounted, onBeforeUnmount, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { PhTray, PhEnvelopeOpen, PhBookBookmark, PhListChecks, PhHandPointing, PhPaperPlaneTilt, PhStamp, PhWarningCircle, PhCheckCircle, PhCalendarBlank, PhPaperPlaneRight, PhFileText, PhSignature, PhNotePencil, PhSealCheck } from '@phosphor-icons/vue'
import { usePersuratan } from '@/stores/persuratan'
import { useUI } from '@/stores/ui'
import BilahTab from '@/components/BilahTab.vue'
import KartuStatistik from '@/components/KartuStatistik.vue'
import TabSuratMasuk from './TabSuratMasuk.vue'
import TabBukuAgenda from './TabBukuAgenda.vue'
import TabKetentuanSurat from './TabKetentuanSurat.vue'
import LembarRincianSurat from './LembarRincianSurat.vue'
import LembarCatatSurat from './LembarCatatSurat.vue'
import TabSuratKeluar from './TabSuratKeluar.vue'
import TabTemplateSurat from './TabTemplateSurat.vue'
import LembarSusunSurat from './LembarSusunSurat.vue'
import LembarRincianKeluar from './LembarRincianKeluar.vue'

const props = defineProps({ tab: { type: String, default: '' } })
const route = useRoute(); const router = useRouter(); const ps = usePersuratan(); const ui = useUI()
const TAB = computed(() => [
  { k: 'untuk-saya', n: 'Untuk saya', ikon: PhTray, w: 'pengajuan', lencana: ringkas.value.perlu_tindakan_saya || 0 },
  { k: 'keluar', n: 'Surat keluar', ikon: PhPaperPlaneRight, w: 'shift', lencana: (ringkas.value.ttd_saya || 0) + (ringkas.value.keluar_diperiksa || 0) },
  ...(ps.bolehAgenda ? [{ k: 'masuk', n: 'Surat masuk', ikon: PhEnvelopeOpen, w: 'tatausaha' }, { k: 'agenda', n: 'Buku agenda', ikon: PhBookBookmark, w: 'rekap' }] : []),
  ...(ps.hak.susun ? [{ k: 'template', n: 'Template', ikon: PhFileText, w: 'pengumuman' }] : []),
  { k: 'ketentuan', n: 'Ketentuan', ikon: PhListChecks, w: 'pengaturan' },
])
const aktif = computed(() => (TAB.value.some((t) => t.k === props.tab) ? props.tab : ps.hak.kelola ? 'masuk' : 'untuk-saya'))

// ---------- Ringkasan langsung ----------
const ringkas = ref({}); const versi = ref(0)
async function muatRingkas() { try { ringkas.value = await ps.ringkasan() } catch (e) { ui.toast(e.message, 'galat') } }
const segarkan = () => { versi.value++; muatRingkas() }
let jeda
onMounted(async () => {
  try { if (!ps.hakDimuat) await ps.muatHak() } catch (e) { ui.toast(e.message, 'galat') }
  muatRingkas(); ps.dengarkan(segarkan); jeda = setInterval(muatRingkas, 60000)
})
onBeforeUnmount(() => { ps.berhenti(); clearInterval(jeda) })
const kartu = computed(() => {
  const r = ringkas.value; const muat = r.menunggu_disposisi === undefined ? '…' : null
  const umum = [
    { judul: 'Perlu tindakan saya', nilai: muat ?? r.perlu_tindakan_saya, ikon: PhHandPointing, warna: 'pengajuan', ket: 'Disposisi atau keputusan' },
    { judul: 'Lewat batas (saya)', nilai: muat ?? r.lewat_batas_saya, ikon: PhWarningCircle, warna: 'klinik', ket: 'Disposisi untuk saya' },
  ]
  if (aktif.value === 'keluar') return [
    { judul: 'Tanda tangan saya', nilai: muat ?? r.ttd_saya, ikon: PhSignature, warna: 'verifikasi', ket: 'Surat menunggu tanda tangan Anda' },
    ...(ps.hak.kelola ? [{ judul: 'Perlu diperiksa', nilai: muat ?? r.keluar_diperiksa, ikon: PhNotePencil, warna: 'pengajuan', ket: 'Draf dari pimpinan' }] : []),
    { judul: 'Menunggu tanda tangan', nilai: muat ?? r.keluar_menunggu_ttd, ikon: PhStamp, warna: 'shift', ket: 'Sudah diajukan' },
    { judul: 'Terbit bulan ini', nilai: muat ?? r.keluar_terbit_bulan_ini, ikon: PhSealCheck, warna: 'presensi', ket: 'Bernomor dan sah' },
  ]
  if (!ps.bolehAgenda) return umum
  return [
    umum[0],
    { judul: 'Menunggu disposisi', nilai: muat ?? r.menunggu_disposisi, ikon: PhPaperPlaneTilt, warna: 'tatausaha', ket: 'Di meja pimpinan' },
    { judul: 'Disposisi berjalan', nilai: muat ?? r.berjalan, ikon: PhStamp, warna: 'shift', ket: 'Sedang ditindaklanjuti' },
    { judul: 'Lewat batas waktu', nilai: muat ?? r.lewat_batas, ikon: PhWarningCircle, warna: 'klinik', ket: 'Surat dengan disposisi terlambat' },
    { judul: 'Masuk bulan ini', nilai: muat ?? r.masuk_bulan_ini, ikon: PhCalendarBlank, warna: 'agenda', ket: 'Tercatat di buku agenda' },
    { judul: 'Selesai bulan ini', nilai: muat ?? r.selesai_bulan_ini, ikon: PhCheckCircle, warna: 'presensi', ket: 'Tuntas ditindaklanjuti' },
  ]
})

// ---------- Rincian dari ?surat= ----------
const suratId = computed(() => (typeof route.query.surat === 'string' ? route.query.surat : ''))
const resmiId = computed(() => (typeof route.query.resmi === 'string' ? route.query.resmi : ''))
const diKeluar = computed(() => aktif.value === 'keluar')
const bukaRincian = computed({ get: () => !diKeluar.value && !!suratId.value, set: (v) => { if (!v) router.replace({ query: { ...route.query, surat: undefined } }) } })
const bukaKeluar = computed({ get: () => diKeluar.value && !!(suratId.value || resmiId.value), set: (v) => { if (!v) router.replace({ query: { ...route.query, surat: undefined, resmi: undefined } }) } })
// Susun/ubah surat keluar
const lembarSusun = ref(false); const suratSusun = ref(null)
function susun(s = null) { suratSusun.value = s; if (s) bukaKeluar.value = false; lembarSusun.value = true }
const pilih = (id) => router.replace({ query: { ...route.query, surat: id } })
// Ubah surat (TU): rincian ditutup, formulir dibuka; setelah tersimpan rincian dibuka kembali
const suratUbah = ref(null); const lembarUbah = ref(false)
function ubah(s) { suratUbah.value = s; bukaRincian.value = false; lembarUbah.value = true }
</script>
<template>
  <div v-if="ps.hakDimuat">
    <BilahTab class="mb-4" :tab="TAB" :model-value="aktif" label="Bagian persuratan" @update:model-value="(k) => router.replace(`/persuratan/${k}`)" />
    <div v-if="!['ketentuan', 'template'].includes(aktif)" class="-mx-4 mb-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:overflow-visible sm:px-0"
      :class="kartu.length > 4 ? 'sm:grid-cols-3 xl:grid-cols-6' : kartu.length > 2 ? 'sm:grid-cols-4' : 'sm:grid-cols-2 sm:max-w-xl'">
      <KartuStatistik v-for="k in kartu" :key="k.judul" class="w-[44%] shrink-0 snap-start sm:w-auto" :judul="k.judul" :nilai="k.nilai" :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket" />
    </div>
    <TabSuratMasuk v-if="aktif === 'untuk-saya' || aktif === 'masuk'" :key="aktif" :cakupan="aktif === 'masuk' ? 'masuk' : 'untuk_saya'" :versi="versi" @pilih="pilih" @berubah="segarkan" />
    <TabSuratKeluar v-else-if="aktif === 'keluar'" :versi="versi" @pilih="pilih" @susun="susun()" />
    <TabBukuAgenda v-else-if="aktif === 'agenda'" />
    <TabTemplateSurat v-else-if="aktif === 'template'" />
    <TabKetentuanSurat v-else />
    <LembarRincianSurat v-model="bukaRincian" :id="suratId" :versi="versi" @berubah="segarkan" @ubah="ubah" />
    <LembarCatatSurat v-model="lembarUbah" :surat="suratUbah" @selesai="(id) => { segarkan(); pilih(id) }" />
    <LembarRincianKeluar v-model="bukaKeluar" :id="suratId" :doc="suratId ? '' : resmiId" :versi="versi" @berubah="segarkan" @ubah="susun" @revisi="(id) => router.replace({ path: '/persuratan/keluar', query: { surat: id } })" />
    <LembarSusunSurat v-model="lembarSusun" :surat="suratSusun" @selesai="(id) => { segarkan(); router.replace({ path: '/persuratan/keluar', query: { surat: id } }) }" />
  </div>
  <p v-else class="kartu p-8 text-center text-sm text-teks3">Memuat…</p>
</template>
