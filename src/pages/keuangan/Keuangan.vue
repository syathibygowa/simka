<!-- SIMKA PRO | src/pages/keuangan/Keuangan.vue | v1.0 | Fase 13 – Menu Keuangan santri | 11/10/2026 -->
<script setup>
// Menu Keuangan santri (Blueprint Bagian 37; Fase 13 dipercepat). Hanya superadmin dan pegawai yang ditunjuk
// superadmin (Hak Akses → Fitur sensitif → Keuangan santri), mis. Bendahara Pondok. Data tidak tampil di portal wali.
//   Ringkasan   : angka langsung (tagihan, terbayar, sisa, tunggakan, pemasukan), per jenis, 6 bulan, jatuh tempo terdekat
//   Santri      : per santri: tagihan, sisa, tunggakan → rincian, catat pembayaran, subsidi, surat tagihan, WA ke wali
//   Tagihan     : buat tagihan massal (bulanan/tahunan/sekali; per jenjang, tingkat, kelompok, santri) dan daftar tagihan
//   Pembayaran  : pembayaran per rentang tanggal, kuitansi, pembatalan, rekap pemasukan
//   Tunggakan   : posisi tunggakan per tanggal per santri/kelas/jenis/jenjang; cetak F4, Excel, WA ke wali
//   Pengaturan  : jenis biaya dan tarif, subsidi santri, ketentuan (rekening lembaga, jatuh tempo, catatan dokumen)
// Rincian seorang santri dibuka dari tab mana pun dengan ?santri=<id>.
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { PhChartPieSlice, PhStudent, PhInvoice, PhReceipt, PhWarningCircle, PhSlidersHorizontal, PhLockSimple, PhSignature } from '@phosphor-icons/vue'
import { useKeuangan } from '@/stores/keuangan'
import { useSesi } from '@/stores/sesi'
import BilahTab from '@/components/BilahTab.vue'
import TabRingkasanKeu from './TabRingkasanKeu.vue'
import TabSantriKeu from './TabSantriKeu.vue'
import TabTagihan from './TabTagihan.vue'
import TabPembayaran from './TabPembayaran.vue'
import TabTunggakan from './TabTunggakan.vue'
import TabPengaturanKeu from './TabPengaturanKeu.vue'
import LembarSantriKeu from './LembarSantriKeu.vue'

const props = defineProps({ tab: { type: String, default: '' } })
const router = useRouter(); const route = useRoute()
const keu = useKeuangan(); const sesi = useSesi()
const siap = ref(false); const galat = ref(''); const versi = ref(0)

const TAB = computed(() => (keu.hak.lihat ? [
  { k: 'ringkasan', n: 'Ringkasan', ikon: PhChartPieSlice, w: 'keuangan' },
  { k: 'santri', n: 'Santri', ikon: PhStudent, w: 'santri' },
  { k: 'tagihan', n: 'Tagihan', ikon: PhInvoice, w: 'agenda' },
  { k: 'pembayaran', n: 'Pembayaran', ikon: PhReceipt, w: 'presensi' },
  { k: 'tunggakan', n: 'Tunggakan', ikon: PhWarningCircle, w: 'klinik' },
  { k: 'pengaturan', n: 'Pengaturan', ikon: PhSlidersHorizontal, w: 'pengaturan' },
] : []))
const aktif = computed(() => (TAB.value.some((t) => t.k === props.tab) ? props.tab : TAB.value[0]?.k || ''))
watch(aktif, (k) => { if (k && k !== props.tab) router.replace({ path: `/keuangan/${k}`, query: route.query }) })

onMounted(async () => {
  try { await keu.muatHak(); if (keu.hak.lihat) await keu.muatJenis() } catch (e) { galat.value = e.message }
  siap.value = true
})
const santriId = computed(() => (typeof route.query.santri === 'string' ? route.query.santri : ''))
const tutupSantri = () => router.replace({ query: { ...route.query, santri: undefined } })
const berubah = () => { versi.value++ }
</script>
<template>
  <div>
    <p v-if="galat" class="kartu mb-4 p-4 text-sm font-semibold text-merah">{{ galat }} Pastikan SQL keuangan 7500–7700 sudah dijalankan di Supabase.</p>
    <p v-if="!siap" class="kartu p-8 text-center text-sm text-teks3">Memuat…</p>
    <div v-else-if="!TAB.length" class="kartu w-keuangan flex flex-col items-center gap-3 p-8 text-center">
      <span class="chip-ikon h-14 w-14"><PhLockSimple :size="30" weight="duotone" /></span>
      <p class="font-bold">Menu keuangan tidak tersedia untuk akun Anda</p>
      <p class="max-w-md text-sm text-teks3">Keuangan santri hanya dapat dibuka oleh pegawai yang ditunjuk superadmin.</p>
    </div>
    <template v-else>
      <BilahTab class="mb-3" :tab="TAB" :model-value="aktif" label="Bagian keuangan" @update:model-value="(k) => router.replace(`/keuangan/${k}`)" />
      <p v-if="!keu.hak.ada_penanda_tangan" class="kartu w-pengajuan mb-3 flex items-center gap-2 p-3 text-sm">
        <PhSignature :size="20" weight="duotone" style="color: var(--c)" class="shrink-0" />
        Superadmin belum menunjuk penanda tangan keuangan (Bendahara Pondok). Kuitansi dan surat tagihan belum dapat diterbitkan.</p>
      <p v-else-if="!keu.hak.kelola" class="mb-3 text-sm text-teks3">Anda memiliki akses lihat saja.</p>
      <div :class="'w-' + (TAB.find((t) => t.k === aktif)?.w || 'keuangan')">
        <TabRingkasanKeu v-if="aktif === 'ringkasan'" :key="'r' + versi" />
        <TabSantriKeu v-else-if="aktif === 'santri'" :key="'s' + versi" />
        <TabTagihan v-else-if="aktif === 'tagihan'" :key="'t' + versi" @berubah="berubah" />
        <TabPembayaran v-else-if="aktif === 'pembayaran'" :key="'p' + versi" @berubah="berubah" />
        <TabTunggakan v-else-if="aktif === 'tunggakan'" :key="'u' + versi" />
        <TabPengaturanKeu v-else-if="aktif === 'pengaturan'" />
      </div>
      <LembarSantriKeu v-if="santriId" :id="santriId" @tutup="tutupSantri" @berubah="berubah" />
    </template>
  </div>
</template>
