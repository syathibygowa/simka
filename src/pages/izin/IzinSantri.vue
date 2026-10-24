<!-- SIMKA PRO | src/pages/izin/IzinSantri.vue | v1.4 | 14.20.0: tab Kolektif, buka surat izin dari tautan registri | 22/10/2026 -->
<script setup>
// Perizinan berjenjang (Blueprint Bagian 22, dimajukan dari Fase 7).
//   Persetujuan : izin yang menunggu keputusan saya (kepala bidang/unit, Direktur/Wadir, Plt, superadmin)
//   Menunggu    : semua izin yang belum diputus (yang dapat saya lihat)
//   Aktif       : disetujui atau sedang di luar pondok (terlambat kembali ditandai merah)
//   Riwayat     : semua izin pada rentang tanggal
//   Kolektif    : izin beberapa santri sekaligus (lomba/kegiatan luar) dengan surat izin kolektif (14.20.0)
//   (Libur santri kini menu tersendiri: #/libur-santri)
//   Ketentuan   : batas hari persetujuan kepala bidang, lama izin bawaan
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { PhSealCheck, PhHourglass, PhSignOut, PhClockCounterClockwise, PhListChecks, PhFloppyDisk, PhInfo, PhUsersThree } from '@phosphor-icons/vue'
import { useIzin } from '@/stores/izin'
import { useUI } from '@/stores/ui'
import BilahTab from '@/components/BilahTab.vue'
import TabIzin from './TabIzin.vue'
import TabKolektif from './TabKolektif.vue'
import CetakSuratIzin from './CetakSuratIzin.vue'
import CetakSuratKolektif from './CetakSuratKolektif.vue'

const props = defineProps({ tab: { type: String, default: '' }, surat: { type: String, default: '' } })
const router = useRouter(); const iz = useIzin(); const ui = useUI()
onMounted(async () => { if (!iz.hakDimuat) await iz.muatHak().catch((e) => ui.toast(e.message, 'galat')); salin(); if (props.surat) bukaSurat(props.surat) })
// Tautan registri dokumen /izin-santri/surat/:id → pratinjau surat (anggota kolektif → surat kolektif)
const suratCetak = ref(null); const pratSurat = ref(false); const kolCetak = ref(null); const pratKol = ref(false)
async function bukaSurat(id) {
  try {
    const d = await iz.surat(id)
    if (d?.kolektif_id) { kolCetak.value = (await iz.daftarKolektif('semua', d.kolektif_id))[0] || null; pratKol.value = !!kolCetak.value }
    else { suratCetak.value = d; pratSurat.value = true }
  } catch (e) { ui.toast(e.message, 'galat') }
}
const TAB = computed(() => [
  ...(iz.pemutus ? [{ k: 'persetujuan', n: 'Persetujuan', ikon: PhSealCheck, w: 'pengajuan' }] : []),
  { k: 'menunggu', n: 'Menunggu', ikon: PhHourglass, w: 'agenda' },
  { k: 'aktif', n: 'Aktif', ikon: PhSignOut, w: 'shift' },
  { k: 'riwayat', n: 'Riwayat', ikon: PhClockCounterClockwise, w: 'rekap' },
  { k: 'kolektif', n: 'Kolektif', ikon: PhUsersThree, w: 'ekskul' },
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
        <li>Setiap izin yang disetujui (termasuk izin keluar, izin sakit dari Klinik, dan izin cepat) mendapat Surat Izin bernomor dan berkode validasi untuk ditunjukkan kepada Security; buku/selembaran izin manual tidak diperlukan lagi.</li>
        <li>Izin kolektif (lomba atau kegiatan luar beberapa santri, boleh beda kelas/kamar) diputus sekali oleh Kepala Bidang Kesantrian, dengan tembusan ke musyrif, wali kelas, dan kepala sekolah santri terkait.</li>
        <li>Rekap perizinan tiap santri (pengganti buku saku perizinan) dicetak dari Data Santri › detail santri › Rekap izin.</li>
      </ul>
      <div class="mt-4 grid gap-3 sm:max-w-lg sm:grid-cols-2">
        <div><label class="label-isian" for="iz-bh">Batas hari persetujuan kepala bidang</label><input id="iz-bh" v-model="atur.batas_hari_bidang" type="number" min="1" max="30" class="isian tabular-nums" :disabled="!iz.hak.kelola" /></div>
        <div><label class="label-isian" for="iz-lb">Lama izin bawaan (hari)</label><input id="iz-lb" v-model="atur.lama_bawaan_hari" type="number" min="1" max="30" class="isian tabular-nums" :disabled="!iz.hak.kelola" /></div>
      </div>
      <button v-if="iz.hak.kelola" class="tombol-utama mt-4" :disabled="proses" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> Simpan ketentuan</button>
      <p v-else class="mt-3 flex items-center gap-2 text-xs text-teks3"><PhInfo :size="16" /> Diatur oleh superadmin atau admin ber-izin kelola izin santri.</p>
    </section>
    <TabKolektif v-else-if="aktif === 'kolektif'" />
    <TabIzin v-else :key="aktif" :cakupan="aktif === 'riwayat' ? 'semua' : aktif" />
  </div>
  <p v-else class="kartu p-8 text-center text-sm text-teks3">Memuat…</p>
  <CetakSuratIzin v-model:pratinjau="pratSurat" :surat="suratCetak" />
  <CetakSuratKolektif v-model:pratinjau="pratKol" :kolektif="kolCetak" />
</template>
