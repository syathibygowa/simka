<!-- SIMKA PRO | src/pages/security/Security.vue | v1.0 | Fase 7 – Tahap 1 Security: gerbang | 06/10/2026 -->
<script setup>
// Menu Security (Blueprint Bagian 24). Tahap 1: gerbang santri.
//   Gerbang   : cari santri (hijau/merah), siap keluar hari ini, catatan hari ini
//   Di luar   : santri yang sedang izin di luar pondok; terlambat kembali di atas (merah)
//   Riwayat   : catatan gerbang per rentang tanggal, Excel, cetak F4
//   Ketentuan : toleransi terlambat kembali, batas keluar lebih awal dari jadwal izin
// Pencatat gerbang: petugas Security. Pimpinan, yayasan, admin, dan superadmin dapat melihat (pantauan).
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { PhDoorOpen, PhSignOut, PhClockCounterClockwise, PhListChecks, PhFloppyDisk, PhInfo, PhLock } from '@phosphor-icons/vue'
import { useSecurity } from '@/stores/security'
import { useUI } from '@/stores/ui'
import BilahTab from '@/components/BilahTab.vue'
import TabGerbang from './TabGerbang.vue'
import TabRiwayatGerbang from './TabRiwayatGerbang.vue'

const props = defineProps({ tab: { type: String, default: '' } })
const router = useRouter(); const sc = useSecurity(); const ui = useUI()
onMounted(async () => { if (!sc.hakDimuat) await sc.muatHak().catch((e) => ui.toast(e.message, 'galat')); salin(); sc.muatBeranda() })
const TAB = computed(() => [
  { k: 'gerbang', n: 'Gerbang', ikon: PhDoorOpen, w: 'security' },
  { k: 'diluar', n: 'Di luar', ikon: PhSignOut, w: 'shift', jumlah: sc.beranda?.di_luar ?? null, lencana: sc.beranda?.terlambat || null },
  { k: 'riwayat', n: 'Riwayat', ikon: PhClockCounterClockwise, w: 'rekap' },
  { k: 'ketentuan', n: 'Ketentuan', ikon: PhListChecks, w: 'pengaturan' },
])
const aktif = computed(() => (TAB.value.some((t) => t.k === props.tab) ? props.tab : 'gerbang'))
const atur = ref({ toleransi_terlambat_menit: 0, keluar_lebih_awal_menit: 120 }); const proses = ref(false)
function salin() { atur.value = { ...sc.pengaturan } }
async function simpan() {
  proses.value = true
  try { await sc.simpanPengaturan({ toleransi_terlambat_menit: Number(atur.value.toleransi_terlambat_menit), keluar_lebih_awal_menit: Number(atur.value.keluar_lebih_awal_menit) }); salin(); ui.toast('Ketentuan Security tersimpan.') }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <div v-if="sc.hakDimuat && sc.hak.lihat">
    <BilahTab class="mb-4" :tab="TAB" :model-value="aktif" label="Bagian Security" @update:model-value="(k) => router.replace(`/security/${k}`)" />
    <TabRiwayatGerbang v-if="aktif === 'riwayat'" />
    <section v-else-if="aktif === 'ketentuan'" class="kartu w-security p-4 sm:p-5">
      <h2 class="judul-bagian">Ketentuan gerbang</h2>
      <ul class="mt-2 list-disc space-y-1 pl-5 text-sm text-teks2">
        <li>Pencatat keluar dan kembali santri adalah petugas Security (jabatan Petugas keamanan). Superadmin dan admin ber-izin kelola Security menjadi cadangan.</li>
        <li>Hijau: izin disetujui dan berlaku, santri boleh keluar. Merah: tidak ada izin, belum disetujui, belum waktunya, atau kedaluwarsa.</li>
        <li>Santri tanpa izin dicatat "ditolak di gerbang"; Kepala Bidang Kesantrian dan pengelola izin menerima notifikasi dan dapat membuat izin cepat.</li>
        <li>Santri yang melewati batas kembali (ditambah toleransi) ditandai merah; Kepala Bidang Kesantrian, pengusul, musyrif, wali kelas, dan muhaffizh menerima notifikasi sekali.</li>
        <li>Foto gerbang bersifat opsional dan disimpan 6 bulan di Google Drive pondok.</li>
      </ul>
      <div class="mt-4 grid gap-3 sm:max-w-lg sm:grid-cols-2">
        <div><label class="label-isian" for="sc-tol">Toleransi terlambat kembali (menit)</label><input id="sc-tol" v-model="atur.toleransi_terlambat_menit" type="number" min="0" max="720" class="isian tabular-nums" :disabled="!sc.hak.kelola" /></div>
        <div><label class="label-isian" for="sc-awal">Boleh keluar lebih awal dari jadwal izin (menit)</label><input id="sc-awal" v-model="atur.keluar_lebih_awal_menit" type="number" min="0" max="1440" class="isian tabular-nums" :disabled="!sc.hak.kelola" /></div>
      </div>
      <button v-if="sc.hak.kelola" class="tombol-utama mt-4" :disabled="proses" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> Simpan ketentuan</button>
      <p v-else class="mt-3 flex items-center gap-2 text-xs text-teks3"><PhInfo :size="16" /> Diatur oleh superadmin atau admin ber-izin kelola Security.</p>
    </section>
    <TabGerbang v-else :key="aktif" :mode="aktif === 'diluar' ? 'diluar' : 'gerbang'" />
  </div>
  <div v-else-if="sc.hakDimuat" class="kartu flex flex-col items-center gap-2 p-8 text-center text-sm text-teks2">
    <PhLock :size="36" weight="duotone" class="text-teks3" />
    Menu Security hanya untuk petugas Security, pimpinan, admin, dan superadmin.
  </div>
  <p v-else class="kartu p-8 text-center text-sm text-teks3">Memuat…</p>
</template>
