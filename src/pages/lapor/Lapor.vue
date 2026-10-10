<!-- SIMKA PRO | src/pages/lapor/Lapor.vue | v1.1 | Fase 8 – Perbaikan: nama menu ringkas | 10/10/2026 -->
<script setup>
// Laporan Terkait (Blueprint Bagian 30).
//   Laporan saya : laporan yang saya kirim beserta statusnya
//   Masuk        : laporan untuk unit yang saya tangani (anggota unit, pejabat di atasnya, pimpinan, pengelola)
//   Rekap        : jumlah per kategori dan unit pada rentang; cetak F4 dan Excel
//   Ketentuan    : pelapor anonim (aktif/nonaktif — superadmin) dan kategori/penerima (pengelola)
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import * as XLSX from 'xlsx'
import { PhPaperPlaneTilt, PhTray, PhChartPie, PhListChecks, PhMaskHappy, PhEye, PhDownloadSimple, PhFloppyDisk } from '@phosphor-icons/vue'
import { useLapor } from '@/stores/lapor'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { UNIT_PILIHAN, gayaKategori } from '@/lib/lapor'
import { hariIniISO, formatPanjang } from '@/lib/tanggal'
import BilahTab from '@/components/BilahTab.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import TabLaporan from './TabLaporan.vue'

const props = defineProps({ tab: { type: String, default: '' } })
const router = useRouter(); const lp = useLapor(); const sesi = useSesi(); const ui = useUI()
onMounted(() => lp.hakDimuat || lp.muatHak().catch((e) => ui.toast(e.message, 'galat')))
const TAB = computed(() => [
  { k: 'saya', n: 'Laporan saya', ikon: PhPaperPlaneTilt, w: 'laporan' },
  ...(lp.penerima ? [{ k: 'masuk', n: 'Masuk', ikon: PhTray, w: 'pengajuan' }] : []),
  { k: 'rekap', n: 'Rekap', ikon: PhChartPie, w: 'rekap' },
  { k: 'ketentuan', n: 'Ketentuan', ikon: PhListChecks, w: 'pengaturan' },
])
const aktif = computed(() => (TAB.value.some((t) => t.k === props.tab) ? props.tab : lp.penerima ? 'masuk' : 'saya'))

// ---------- Rekap ----------
const mulai = ref(hariIniISO().slice(0, 8) + '01'); const selesai = ref(hariIniISO()); const rekap = ref([]); const pratinjau = ref(false)
async function muatRekap() { try { rekap.value = await lp.rekap(mulai.value, selesai.value) } catch (e) { ui.toast(e.message, 'galat') } }
watch([aktif, mulai, selesai], () => { if (aktif.value === 'rekap') muatRekap() }, { immediate: true })
const total = computed(() => rekap.value.reduce((a, r) => { for (const k of ['jumlah', 'terkirim', 'diterima', 'ditindaklanjuti', 'selesai', 'mendesak']) a[k] = (a[k] || 0) + r[k]; return a }, {}))
const periode = computed(() => `${formatPanjang(mulai.value)} s.d. ${formatPanjang(selesai.value)}`)
function ekspor() {
  const kolom = ['No.', 'Kategori', 'Bidang/unit', 'Jumlah', 'Terkirim', 'Diterima', 'Ditindaklanjuti', 'Selesai', 'Mendesak']
  const isi = rekap.value.map((r, i) => [i + 1, r.kategori, r.unit, r.jumlah, r.terkirim, r.diterima, r.ditindaklanjuti, r.selesai, r.mendesak])
  const ws = XLSX.utils.aoa_to_sheet([[`Rekap Laporan – ${periode.value}`], [], kolom, ...isi])
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Rekap'); XLSX.writeFile(wb, `Rekap-Lapor-${mulai.value}-${selesai.value}.xlsx`)
}

// ---------- Ketentuan ----------
const proses = ref(false)
async function alihAnonim() {
  proses.value = true
  try { await lp.simpanAnonim(!lp.hak.anonim_diizinkan); ui.toast(lp.hak.anonim_diizinkan ? 'Pelaporan anonim diaktifkan.' : 'Pelaporan anonim dinonaktifkan.') }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
async function simpanKategori(k) {
  try { await lp.simpanKategori({ kode: k.kode, nama: k.nama, unit_kode: k.unit_kode || '', contoh: k.contoh, aktif: k.aktif }); ui.toast(`Kategori ${k.nama} tersimpan.`) }
  catch (e) { ui.toast(e.message, 'galat') }
}
</script>
<template>
  <div v-if="lp.hakDimuat">
    <BilahTab class="mb-4" :tab="TAB" :model-value="aktif" label="Bagian lapor" @update:model-value="(k) => router.replace(`/lapor/${k}`)" />
    <TabLaporan v-if="aktif === 'saya' || aktif === 'masuk'" :key="aktif" :cakupan="aktif" />

    <template v-else-if="aktif === 'rekap'">
      <div class="kartu mb-4 grid grid-cols-2 gap-3 p-4 sm:grid-cols-[1fr_1fr_auto]">
        <InputTanggal v-model="mulai" label="Dari" wajib /><InputTanggal v-model="selesai" label="Sampai" wajib />
        <div class="col-span-2 flex items-end gap-2 sm:col-span-1">
          <button class="tombol-garis w-pengajuan min-h-[44px] px-3 text-sm" @click="pratinjau = true"><PhEye :size="18" style="color: var(--c)" /> Cetak</button>
          <button class="tombol-garis w-santri min-h-[44px] px-3 text-sm" @click="ekspor"><PhDownloadSimple :size="18" style="color: var(--c)" /> Excel</button>
        </div>
      </div>
      <div class="kartu overflow-x-auto">
        <table class="w-full min-w-[640px] text-left text-sm">
          <thead class="border-b border-garis bg-permukaan2 text-teks2"><tr><th class="px-3 py-2.5 font-bold">Kategori</th><th class="px-3 py-2.5 font-bold">Bidang/unit</th>
            <th v-for="h in ['Jumlah', 'Terkirim', 'Diterima', 'Tindak lanjut', 'Selesai', 'Mendesak']" :key="h" class="px-3 py-2.5 text-center font-bold">{{ h }}</th></tr></thead>
          <tbody class="divide-y divide-garis">
            <tr v-for="(r, i) in rekap" :key="i"><td class="px-3 py-2">{{ r.kategori }}</td><td class="px-3 py-2">{{ r.unit }}</td>
              <td class="px-3 py-2 text-center tabular-nums">{{ r.jumlah }}</td><td class="px-3 py-2 text-center tabular-nums">{{ r.terkirim }}</td><td class="px-3 py-2 text-center tabular-nums">{{ r.diterima }}</td>
              <td class="px-3 py-2 text-center tabular-nums">{{ r.ditindaklanjuti }}</td><td class="px-3 py-2 text-center tabular-nums">{{ r.selesai }}</td><td class="px-3 py-2 text-center tabular-nums">{{ r.mendesak }}</td></tr>
            <tr v-if="rekap.length" class="bg-permukaan2 font-bold"><td class="px-3 py-2" colspan="2">Jumlah</td>
              <td v-for="k in ['jumlah', 'terkirim', 'diterima', 'ditindaklanjuti', 'selesai', 'mendesak']" :key="k" class="px-3 py-2 text-center tabular-nums">{{ total[k] }}</td></tr>
          </tbody>
        </table>
        <p v-if="!rekap.length" class="py-8 text-center text-sm text-teks3">Belum ada laporan pada rentang ini.</p>
      </div>
      <DokumenCetak kop="pondok" judul="Rekap Laporan Terkait" :subjudul="periode" v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap">
        <table class="tabel">
          <thead><tr><th style="width:5%">No.</th><th style="width:22%">Kategori</th><th>Bidang/unit</th><th style="width:9%">Jumlah</th><th style="width:9%">Terkirim</th>
            <th style="width:9%">Diterima</th><th style="width:11%">Ditindaklanjuti</th><th style="width:8%">Selesai</th><th style="width:9%">Mendesak</th></tr></thead>
          <tbody>
            <tr v-for="(r, i) in rekap" :key="i"><td class="tengah">{{ i + 1 }}</td><td>{{ r.kategori }}</td><td>{{ r.unit }}</td><td class="tengah">{{ r.jumlah }}</td><td class="tengah">{{ r.terkirim }}</td>
              <td class="tengah">{{ r.diterima }}</td><td class="tengah">{{ r.ditindaklanjuti }}</td><td class="tengah">{{ r.selesai }}</td><td class="tengah">{{ r.mendesak }}</td></tr>
            <tr><td></td><td colspan="2">Jumlah</td><td v-for="k in ['jumlah', 'terkirim', 'diterima', 'ditindaklanjuti', 'selesai', 'mendesak']" :key="k" class="tengah">{{ total[k] || 0 }}</td></tr>
          </tbody>
        </table>
        <template #ttd>
          <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: 'Direktur', nama: '', niy: '' }" :kanan="{ jabatan: 'Pembuat rekap', nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
        </template>
      </DokumenCetak>
    </template>

    <div v-else class="space-y-4">
      <section class="kartu w-verval p-4 sm:p-5">
        <div class="flex flex-wrap items-center gap-3">
          <span class="chip-ikon h-11 w-11"><PhMaskHappy :size="24" weight="duotone" /></span>
          <div class="min-w-[200px] flex-1"><h2 class="judul-bagian">Pelapor anonim</h2>
            <p class="text-sm text-teks2">{{ lp.hak.anonim_diizinkan ? 'Aktif: pelapor dapat menyembunyikan namanya dari penerima. Superadmin tetap dapat melihat identitasnya.' : 'Nonaktif: semua laporan menampilkan nama pelapor.' }}</p></div>
          <button v-if="lp.hak.superadmin" role="switch" :aria-checked="lp.hak.anonim_diizinkan" :disabled="proses" @click="alihAnonim"
            :class="['relative h-8 w-14 shrink-0 rounded-full transition', lp.hak.anonim_diizinkan ? 'bg-[#6D44B8]' : 'bg-garis']" aria-label="Aktifkan pelapor anonim">
            <span :class="['absolute top-1 h-6 w-6 rounded-full bg-white shadow transition-all', lp.hak.anonim_diizinkan ? 'left-7' : 'left-1']" /></button>
          <span v-else class="lencana" :class="lp.hak.anonim_diizinkan ? 'w-verval' : 'w-hakakses'">{{ lp.hak.anonim_diizinkan ? 'Aktif' : 'Nonaktif' }}</span>
        </div>
        <p v-if="!lp.hak.superadmin" class="mt-2 text-xs text-teks3">Hanya superadmin yang dapat mengubah pengaturan ini.</p>
      </section>
      <section class="kartu p-4 sm:p-5">
        <h2 class="judul-bagian">Kategori dan penerima</h2>
        <p class="mt-1 text-sm text-teks2">Kesehatan selalu menjadi rujukan klinik. Kategori tanpa penerima tetap: pelapor memilih bidang/unit.</p>
        <ul class="mt-3 divide-y divide-garis">
          <li v-for="k in lp.kategori" :key="k.kode" class="grid gap-2 py-3 sm:grid-cols-[auto_1fr_1fr_auto_auto] sm:items-center" :class="'w-' + gayaKategori(k.kode).w">
            <span class="chip-ikon h-10 w-10"><component :is="gayaKategori(k.kode).ikon" :size="22" weight="duotone" /></span>
            <input v-model="k.nama" class="isian" :disabled="!lp.hak.kelola" :aria-label="`Nama kategori ${k.kode}`" />
            <select v-model="k.unit_kode" class="isian" :disabled="!lp.hak.kelola || k.ke_klinik" :aria-label="`Penerima ${k.nama}`">
              <option :value="null">Dipilih pelapor</option><option v-for="u in UNIT_PILIHAN" :key="u.kode" :value="u.kode">{{ u.n }}</option></select>
            <label class="flex items-center gap-2 text-sm"><input v-model="k.aktif" type="checkbox" class="h-5 w-5" :disabled="!lp.hak.kelola || k.ke_klinik" /> Aktif</label>
            <button v-if="lp.hak.kelola" class="tombol-garis min-h-[40px] px-3 text-sm" @click="simpanKategori(k)"><PhFloppyDisk :size="18" /> Simpan</button>
          </li>
        </ul>
      </section>
    </div>
  </div>
  <p v-else class="kartu p-8 text-center text-sm text-teks3">Memuat…</p>
</template>
