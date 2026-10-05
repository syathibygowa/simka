<!-- SIMKA PRO | src/pages/lapor/TabLaporan.vue | v1.0 | Fase 6 – Tahap 4 Lapor ke bidang dan dasbor ringkasan | 06/10/2026 -->
<script setup>
// Daftar laporan: "saya" (laporan yang saya kirim) atau "masuk" (laporan untuk unit yang saya tangani).
// Laporan mendesak dan belum diterima tampil paling atas. Penerima mengubah status: Diterima → Ditindaklanjuti → Selesai;
// pelapor mendapat notifikasi setiap perubahan. Diperbarui langsung.
import { ref, computed, watch, onMounted, onBeforeUnmount } from 'vue'
import { PhMegaphone, PhMagnifyingGlass, PhSiren, PhPaperPlaneTilt, PhCheck, PhArrowsClockwise, PhCheckCircle, PhMapPin, PhMaskHappy } from '@phosphor-icons/vue'
import { useLapor } from '@/stores/lapor'
import { useUI } from '@/stores/ui'
import { gayaKategori, STATUS_LAPOR, URUT_STATUS_LAPOR } from '@/lib/lapor'
import { formatWaktu, hariIniISO } from '@/lib/tanggal'
import KartuStatistik from '@/components/KartuStatistik.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import TombolAksi from '@/components/TombolAksi.vue'
import FotoBerkas from '@/components/FotoBerkas.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import LembarLapor from './LembarLapor.vue'

const props = defineProps({ cakupan: { type: String, required: true } })
const lp = useLapor(); const ui = useUI()
const daftar = ref([]); const memuat = ref(false); const cari = ref(''); const kategori = ref('')
const awal = () => { const d = new Date(`${hariIniISO()}T00:00:00`); d.setDate(d.getDate() - 30); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}` }
const mulai = ref(awal()); const selesai = ref(hariIniISO())
async function muat() {
  memuat.value = true
  try { if (!lp.hakDimuat) await lp.muatHak(); daftar.value = await lp.daftar(props.cakupan, mulai.value, selesai.value) }
  catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
onMounted(() => { muat(); lp.dengarkan(muat) })
onBeforeUnmount(() => lp.berhenti())
watch([() => props.cakupan, mulai, selesai], muat)

const tampil = computed(() => { const q = cari.value.toLowerCase().trim()
  return daftar.value.filter((r) => (!kategori.value || r.kategori === kategori.value) && (!q || `${r.uraian} ${r.lokasi || ''} ${r.santri.map((s) => s.nama).join(' ')} ${r.pelapor || ''}`.toLowerCase().includes(q))) })
const n = (f) => daftar.value.filter(f).length
const statistik = computed(() => [
  { judul: 'Belum diterima', nilai: n((r) => r.status === 'terkirim'), ikon: PhPaperPlaneTilt, warna: 'pengajuan', ket: 'Menunggu unit penerima' },
  { judul: 'Mendesak', nilai: n((r) => r.mendesak && r.status !== 'selesai'), ikon: PhSiren, warna: 'klinik', ket: 'Belum selesai' },
  { judul: 'Ditindaklanjuti', nilai: n((r) => ['diterima', 'ditindaklanjuti'].includes(r.status)), ikon: PhArrowsClockwise, warna: 'shift', ket: 'Sedang ditangani' },
  { judul: 'Selesai', nilai: n((r) => r.status === 'selesai'), ikon: PhCheckCircle, warna: 'presensi', ket: '30 hari terakhir' },
])
const lanjutan = (r) => URUT_STATUS_LAPOR.slice(URUT_STATUS_LAPOR.indexOf(r.status) + 1)

const lembarLapor = ref(false)
const lembarStatus = ref(false); const pilih = ref(null); const status = ref(''); const catatan = ref(''); const proses = ref(false)
function bukaStatus(r, s) { pilih.value = r; status.value = s; catatan.value = ''; lembarStatus.value = true }
async function simpanStatus() {
  if (status.value !== 'diterima' && catatan.value.trim().length < 5) return ui.toast('Tuliskan catatan tindak lanjut (minimal 5 huruf).', 'galat')
  proses.value = true
  try { await lp.ubahStatus(pilih.value.id, status.value, catatan.value.trim()); lembarStatus.value = false; ui.toast(`Laporan ${STATUS_LAPOR[status.value].n.toLowerCase()}. Pelapor mendapat notifikasi.`); await muat() }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <div>
    <div class="flex flex-wrap items-center gap-2">
      <select v-model="kategori" class="isian w-auto" aria-label="Saring kategori"><option value="">Semua kategori</option><option v-for="k in lp.kategori" :key="k.kode" :value="k.kode">{{ k.nama }}</option></select>
      <div class="relative min-w-[180px] flex-1"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
        <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari uraian, lokasi, santri" aria-label="Cari laporan" /></div>
      <button class="tombol-utama hidden lg:inline-flex" @click="lembarLapor = true"><PhMegaphone :size="20" weight="duotone" /> Buat laporan</button>
    </div>
    <div class="mt-3 grid grid-cols-2 gap-3 sm:max-w-md"><InputTanggal v-model="mulai" label="Dari" /><InputTanggal v-model="selesai" label="Sampai" /></div>
    <div class="-mx-4 mt-3 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-4 sm:overflow-visible sm:px-0">
      <KartuStatistik v-for="k in statistik" :key="k.judul" class="w-[44%] shrink-0 snap-start sm:w-auto" :judul="k.judul" :nilai="memuat && !daftar.length ? '…' : k.nilai" :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket" />
    </div>

    <ul class="mt-4 grid gap-3 md:grid-cols-2">
      <li v-for="r in tampil" :key="r.id" class="kartu p-4" :class="['w-' + gayaKategori(r.kategori).w, r.mendesak && r.status !== 'selesai' ? 'lapor-desak' : '']">
        <div class="flex items-start gap-3">
          <span class="chip-ikon h-11 w-11 shrink-0"><component :is="gayaKategori(r.kategori).ikon" :size="24" weight="duotone" /></span>
          <div class="min-w-0 flex-1">
            <p class="flex flex-wrap items-center gap-1.5"><b>{{ r.nama_kategori }}</b><span class="lencana" :class="'w-' + STATUS_LAPOR[r.status].w">{{ STATUS_LAPOR[r.status].n }}</span>
              <span v-if="r.mendesak" class="lencana w-klinik"><PhSiren :size="12" weight="fill" /> Mendesak</span></p>
            <p class="text-xs text-teks3">Ke {{ r.unit }} · {{ formatWaktu(r.created_at) }}</p>
            <p class="mt-1.5 whitespace-pre-line text-sm text-teks">{{ r.uraian }}</p>
            <p v-if="r.lokasi" class="mt-1 flex items-center gap-1 text-xs text-teks2"><PhMapPin :size="14" /> {{ r.lokasi }} · kejadian {{ formatWaktu(r.waktu_kejadian) }}</p>
            <p v-if="r.santri.length" class="text-xs text-teks2">Santri: {{ r.santri.map((s) => s.nama + (s.kamar ? ' (' + s.kamar + ')' : '')).join(', ') }}</p>
            <p class="text-xs text-teks3"><template v-if="r.anonim && !r.pelapor"><PhMaskHappy :size="13" class="inline" /> Pelapor anonim</template><template v-else>Pelapor: {{ r.pelapor || '–' }}{{ r.anonim ? ' (anonim)' : '' }}</template></p>
            <FotoBerkas v-if="r.foto_id" :id="r.foto_id" alt="Foto laporan" ukuran="mt-2 h-24 w-32" />
            <ol v-if="r.jejak.length > 1" class="mt-2 space-y-0.5 rounded-lg bg-permukaan2 px-2.5 py-1.5 text-xs">
              <li v-for="(j, i) in r.jejak.slice(1)" :key="i"><b>{{ STATUS_LAPOR[j.status]?.n || j.status }}</b> · {{ formatWaktu(j.pada) }}{{ j.oleh ? ' · ' + j.oleh : '' }}{{ j.catatan ? ' · ' + j.catatan : '' }}</li>
            </ol>
            <div v-if="r.boleh_tangani && r.status !== 'selesai' && cakupan !== 'saya'" class="mt-3 flex flex-wrap gap-2">
              <button v-for="s in lanjutan(r)" :key="s" :class="[s === 'selesai' ? 'tombol-utama' : 'tombol-garis', 'min-h-[38px] px-3 text-sm']" @click="bukaStatus(r, s)">
                <component :is="STATUS_LAPOR[s].ikon" :size="18" /> {{ s === 'diterima' ? 'Terima' : s === 'ditindaklanjuti' ? 'Tindak lanjut' : 'Selesai' }}</button>
            </div>
          </div>
        </div>
      </li>
    </ul>
    <p v-if="!tampil.length && !memuat" class="kartu mt-4 p-8 text-center text-sm text-teks3">{{ cakupan === 'saya' ? 'Belum ada laporan yang Anda kirim.' : 'Tidak ada laporan untuk unit Anda pada rentang ini.' }}</p>

    <TombolAksi label="Buat laporan" :ikon="PhMegaphone" warna="laporan" @klik="lembarLapor = true" />
    <LembarLapor v-model="lembarLapor" @selesai="muat" />
    <LembarBawah v-model="lembarStatus" :judul="pilih ? `${STATUS_LAPOR[status]?.n}: ${pilih.nama_kategori}` : ''">
      <div v-if="pilih" class="space-y-3 pb-2">
        <p class="text-sm text-teks2">{{ pilih.uraian }}</p>
        <textarea v-model="catatan" rows="3" class="isian" :placeholder="status === 'diterima' ? 'Catatan (opsional)' : 'Tindakan yang dilakukan (wajib)'" aria-label="Catatan tindak lanjut" />
        <button class="tombol-utama w-full" :disabled="proses" @click="simpanStatus"><PhCheck :size="20" weight="bold" /> Simpan</button>
      </div>
    </LembarBawah>
  </div>
</template>
<style scoped>
.lapor-desak { border-color: #C7332F; box-shadow: inset 4px 0 0 #C7332F; }
</style>
