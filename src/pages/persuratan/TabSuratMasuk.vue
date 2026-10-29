<!-- SIMKA PRO | src/pages/persuratan/TabSuratMasuk.vue | v1.3 | 14.30.0: label saringan yang sudah jelas disembunyikan (hemat ruang) | 29/10/2026 -->
<script setup>
// Daftar surat masuk. cakupan "untuk_saya": surat yang perlu saya disposisikan/tindak lanjuti (paling atas) dan yang melibatkan saya;
// "masuk": semua surat yang boleh saya baca pada rentang tanggal terima. Diketuk membuka rincian. TU mencatat surat dari sini.
// v1.2: saringan bagian penerima dan lencana bagian pada setiap surat.
import { ref, computed, watch, onMounted } from 'vue'
import { PhMagnifyingGlass, PhPlus, PhPaperclip, PhClock, PhHandPointing, PhArrowBendDownRight } from '@phosphor-icons/vue'
import { usePersuratan } from '@/stores/persuratan'
import { useUI } from '@/stores/ui'
import { SIFAT_SURAT, STATUS_SURAT, tambahHari, daftarBagian } from '@/lib/persuratan'
import { useLembaga } from '@/stores/lembaga'
import { formatPendek, hariIniISO } from '@/lib/tanggal'
import InputTanggal from '@/components/InputTanggal.vue'
import SaringCorong from '@/components/SaringCorong.vue'
import TombolAksi from '@/components/TombolAksi.vue'
import LembarCatatSurat from './LembarCatatSurat.vue'

const props = defineProps({ cakupan: { type: String, required: true }, versi: { type: Number, default: 0 } })
const emit = defineEmits(['pilih', 'berubah'])
const ps = usePersuratan(); const ui = useUI(); const lembaga = useLembaga()
const daftar = ref([]); const memuat = ref(false); const cari = ref(''); const sifat = ref(''); const status = ref(''); const bagian = ref('')
const BAGIAN = computed(() => daftarBagian(lembaga.letterheads)); const infoBagian = (k) => BAGIAN.value.find((b) => b.k === (k || 'pondok'))
const mulai = ref(tambahHari(hariIniISO(), props.cakupan === 'masuk' ? -30 : -90)); const selesai = ref(hariIniISO())
async function muat() {
  memuat.value = true
  try { daftar.value = await ps.daftar(props.cakupan, mulai.value, selesai.value) } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
onMounted(muat)
watch([mulai, selesai, () => props.versi], muat)

const tampil = computed(() => {
  const q = cari.value.toLowerCase().trim()
  return daftar.value.filter((s) => (!bagian.value || (s.kop_kode || 'pondok') === bagian.value) && (!sifat.value || s.sifat === sifat.value) && (!status.value || s.status === status.value)
    && (!q || `${s.nomor_agenda} ${s.nomor_surat || ''} ${s.pengirim} ${s.perihal} ${s.tujuan || ''}`.toLowerCase().includes(q)))
})
const perlu = computed(() => tampil.value.filter((s) => s.perlu_tindakan))
const lain = computed(() => tampil.value.filter((s) => !s.perlu_tindakan))
const lembarCatat = ref(false)
const hariIni = hariIniISO()
function keteranganSaya(s) {
  if (s.peran_saya === 'tujuan' && s.status === 'diteruskan') return 'Menunggu disposisi Anda'
  if (s.perlu_tindakan) return 'Disposisi untuk Anda' + (s.batas_saya ? ` · batas ${formatPendek(s.batas_saya)}` : '')
  return null
}
</script>
<template>
  <div>
    <SaringCorong :jumlah="[bagian, sifat, status].filter(Boolean).length" :ringkasan="[`${formatPendek(mulai)} – ${formatPendek(selesai)}`, bagian && infoBagian(bagian)?.n, sifat && SIFAT_SURAT[sifat].n, status && STATUS_SURAT[status].n].filter(Boolean).join(' · ')" judul="Saring surat">
      <template #cari><div class="relative"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
        <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari nomor, pengirim, perihal" aria-label="Cari surat" /></div></template>
      <select v-model="bagian" class="isian md:w-auto" aria-label="Saring bagian"><option value="">Semua bagian</option>
        <option v-for="b in BAGIAN" :key="b.k" :value="b.k">{{ b.n }}</option></select>
      <select v-model="sifat" class="isian md:w-auto" aria-label="Saring sifat"><option value="">Semua sifat</option>
        <option v-for="(v, k) in SIFAT_SURAT" :key="k" :value="k">{{ v.n }}</option></select>
      <select v-model="status" class="isian md:w-auto" aria-label="Saring status"><option value="">Semua status</option>
        <option v-for="(v, k) in STATUS_SURAT" :key="k" :value="k">{{ v.n }}</option></select>
      <div class="grid w-full grid-cols-2 gap-3 md:w-auto md:min-w-[22rem]"><InputTanggal class="tanpa-label" v-model="mulai" label="Diterima dari" /><InputTanggal class="tanpa-label" v-model="selesai" label="Sampai" /></div>
      <button v-if="cakupan === 'masuk' && ps.hak.kelola" class="tombol-utama hidden lg:inline-flex" @click="lembarCatat = true"><PhPlus :size="20" weight="bold" /> Catat surat masuk</button>
    </SaringCorong>

    <template v-for="(grup, gi) in [{ judul: 'Perlu tindakan Anda', isi: perlu }, { judul: cakupan === 'masuk' ? 'Daftar surat' : 'Riwayat surat yang melibatkan Anda', isi: lain }]" :key="gi">
      <h2 v-if="grup.isi.length && (cakupan === 'untuk_saya' || gi === 1 && perlu.length)" class="judul-bagian mb-2 mt-5 flex items-center gap-2">
        <PhHandPointing v-if="gi === 0" :size="20" weight="duotone" class="text-merah" />{{ grup.judul }}<span class="text-sm font-normal text-teks3">({{ grup.isi.length }})</span></h2>
      <ul :class="['grid gap-3 md:grid-cols-2', !(cakupan === 'untuk_saya' || gi === 1 && perlu.length) && 'mt-4']">
        <li v-for="s in grup.isi" :key="s.id">
          <button type="button" class="kartu surat flex w-full items-start gap-3 p-4 text-left transition hover:shadow-apung" :class="['w-' + SIFAT_SURAT[s.sifat].w, s.perlu_tindakan && 'perlu', s.status === 'batal' && 'opacity-60']" @click="emit('pilih', s.id)">
            <span class="chip-ikon h-11 w-11"><component :is="SIFAT_SURAT[s.sifat].ikon" :size="24" weight="duotone" /></span>
            <span class="min-w-0 flex-1">
              <span class="flex flex-wrap items-center gap-1.5">
                <span class="text-xs font-bold tabular-nums text-teks2">{{ s.nomor_agenda }}</span>
                <span v-if="infoBagian(s.kop_kode)" class="lencana" :class="'w-' + infoBagian(s.kop_kode).w">{{ infoBagian(s.kop_kode).n }}</span>
                <span class="lencana" :class="'w-' + STATUS_SURAT[s.status].w">{{ STATUS_SURAT[s.status].n }}</span>
                <span v-if="s.sifat !== 'biasa'" class="lencana" :class="'w-' + SIFAT_SURAT[s.sifat].w">{{ SIFAT_SURAT[s.sifat].n }}</span>
                <span v-if="s.baru_saya" class="lencana w-klinik">Baru</span>
                <span v-if="s.lewat_batas" class="lencana w-klinik"><PhClock :size="12" weight="bold" /> Lewat batas</span>
              </span>
              <span class="mt-1 block font-bold leading-snug text-teks [overflow-wrap:anywhere]">{{ s.perihal }}</span>
              <span class="block text-sm text-teks2 [overflow-wrap:anywhere]">{{ s.pengirim }}</span>
              <span class="mt-0.5 block text-xs text-teks3">Diterima {{ formatPendek(s.tanggal_terima) }}<template v-if="s.nomor_surat"> · No. {{ s.nomor_surat }}</template>
                <template v-if="s.jumlah_berkas"> · <PhPaperclip :size="12" class="inline" /> {{ s.jumlah_berkas }}</template></span>
              <span v-if="s.tujuan" class="mt-1 flex items-center gap-1 text-xs text-teks2"><PhArrowBendDownRight :size="14" /> {{ s.tujuan }}
                <template v-if="s.disposisi_ringkas.length"> → {{ s.disposisi_ringkas.map((d) => d.kepada).join(', ') }}</template></span>
              <span v-if="keteranganSaya(s)" class="mt-1.5 inline-flex rounded-lg bg-[#C7332F]/10 px-2 py-0.5 text-xs font-bold text-merah"
                :class="s.batas_saya && s.batas_saya < hariIni && 'ring-1 ring-[#C7332F]'">{{ keteranganSaya(s) }}</span>
            </span>
          </button>
        </li>
      </ul>
    </template>
    <p v-if="!tampil.length && !memuat" class="kartu mt-4 p-8 text-center text-sm text-teks3">
      {{ cakupan === 'masuk' ? 'Belum ada surat masuk pada rentang ini.' : 'Tidak ada surat yang perlu Anda tindak lanjuti.' }}</p>
    <p v-if="memuat && !daftar.length" class="kartu mt-4 p-8 text-center text-sm text-teks3">Memuat…</p>

    <template v-if="cakupan === 'masuk' && ps.hak.kelola">
      <TombolAksi label="Catat surat" :ikon="PhPlus" warna="tatausaha" @klik="lembarCatat = true" />
      <LembarCatatSurat v-model="lembarCatat" @selesai="(id) => { emit('berubah'); emit('pilih', id) }" />
    </template>
  </div>
</template>
<style scoped>
.surat.perlu { border-color: #C7332F; box-shadow: inset 4px 0 0 #C7332F; }
</style>
