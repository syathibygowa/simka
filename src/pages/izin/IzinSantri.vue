<!-- SIMKA PRO | src/pages/izin/IzinSantri.vue | v1.2 | Fase 8 – Perbaikan: nama menu ringkas | 10/10/2026 -->
<script setup>
// Perizinan berjenjang (Blueprint Bagian 22, dimajukan dari Fase 7).
//   Persetujuan : izin yang menunggu keputusan saya (kepala bidang/unit, Direktur/Wadir, Plt, superadmin)
//   Menunggu    : semua izin yang belum diputus (yang dapat saya lihat)
//   Aktif       : disetujui atau sedang di luar pondok (terlambat kembali ditandai merah)
//   Riwayat     : semua izin pada rentang tanggal
//   Libur       : penentuan libur santri (Bagian 23): periode, syarat, penilaian, pengesahan, cetak
//   Ketentuan   : batas hari persetujuan kepala bidang, lama izin bawaan
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { PhSealCheck, PhHourglass, PhSignOut, PhClockCounterClockwise, PhListChecks, PhFloppyDisk, PhInfo, PhCalendarCheck } from '@phosphor-icons/vue'
import { useIzin } from '@/stores/izin'
import { useUI } from '@/stores/ui'
import BilahTab from '@/components/BilahTab.vue'
import TabIzin from './TabIzin.vue'
import TabLibur from './TabLibur.vue'

const props = defineProps({ tab: { type: String, default: '' } })
const router = useRouter(); const iz = useIzin(); const ui = useUI()
onMounted(async () => { if (!iz.hakDimuat) await iz.muatHak().catch((e) => ui.toast(e.message, 'galat')); salin() })
const TAB = computed(() => [
  ...(iz.pemutus ? [{ k: 'persetujuan', n: 'Persetujuan', ikon: PhSealCheck, w: 'pengajuan' }] : []),
  { k: 'menunggu', n: 'Menunggu', ikon: PhHourglass, w: 'agenda' },
  { k: 'aktif', n: 'Aktif', ikon: PhSignOut, w: 'shift' },
  { k: 'riwayat', n: 'Riwayat', ikon: PhClockCounterClockwise, w: 'rekap' },
  { k: 'libur', n: 'Libur santri', ikon: PhCalendarCheck, w: 'agenda' },
  { k: 'ketentuan', n: 'Ketentuan', ikon: PhListChecks, w: 'pengaturan' },
])
const aktif = computed(() => (TAB.value.some((t) => t.k === props.tab) ? props.tab : TAB.value[0].k))
const atur = ref({ batas_hari_bidang: 2, lama_bawaan_hari: 2 }); const proses = ref(false)
function salin() { atur.value = { ...iz.pengaturan } }
async function simpan() {
  proses.value = true
  try { await iz.simpanPengaturan({ batas_hari_bidang: Number(atur.value.batas_hari_bidang), lama_bawaan_hari: Number(atur.value.lama_bawaan_hari) }); salin(); ui.toast('Ketentuan perizinan tersimpan.') }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <div v-if="iz.hakDimuat">
    <BilahTab class="mb-4" :tab="TAB" :model-value="aktif" label="Bagian perizinan" @update:model-value="(k) => router.replace(`/izin-santri/${k}`)" />
    <section v-if="aktif === 'ketentuan'" class="kartu w-pengajuan p-4 sm:p-5">
      <h2 class="judul-bagian">Ketentuan perizinan santri</h2>
      <ul class="mt-2 list-disc space-y-1 pl-5 text-sm text-teks2">
        <li>Pengusul: musyrif (diputus Kepala Bidang Kesantrian), muhaffizh (Kepala Bidang Tahfizh), wali kelas (Kepala Kesetaraan Wustha atau Kepala SMA sesuai jenjang santri). Plt dapat menggantikan.</li>
        <li>Izin lebih dari batas hari di bawah ini naik ke Direktur/Wakil Direktur setelah disetujui kepala bidang.</li>
        <li>Selama izin berlaku, santri otomatis berstatus Izin di semua absensi. Santri yang sakit (Klinik) tetap berstatus Sakit.</li>
        <li>Santri yang dipulangkan Klinik otomatis menjadi usulan izin ke Kepala Bidang Kesantrian.</li>
      </ul>
      <div class="mt-4 grid gap-3 sm:max-w-lg sm:grid-cols-2">
        <div><label class="label-isian" for="iz-bh">Batas hari persetujuan kepala bidang</label><input id="iz-bh" v-model="atur.batas_hari_bidang" type="number" min="1" max="30" class="isian tabular-nums" :disabled="!iz.hak.kelola" /></div>
        <div><label class="label-isian" for="iz-lb">Lama izin bawaan (hari)</label><input id="iz-lb" v-model="atur.lama_bawaan_hari" type="number" min="1" max="30" class="isian tabular-nums" :disabled="!iz.hak.kelola" /></div>
      </div>
      <button v-if="iz.hak.kelola" class="tombol-utama mt-4" :disabled="proses" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> Simpan ketentuan</button>
      <p v-else class="mt-3 flex items-center gap-2 text-xs text-teks3"><PhInfo :size="16" /> Diatur oleh superadmin atau admin ber-izin kelola izin santri.</p>
    </section>
    <TabLibur v-else-if="aktif === 'libur'" />
    <TabIzin v-else :key="aktif" :cakupan="aktif === 'riwayat' ? 'semua' : aktif" />
  </div>
  <p v-else class="kartu p-8 text-center text-sm text-teks3">Memuat…</p>
</template>
