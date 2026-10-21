<!-- SIMKA PRO | src/pages/persuratan/TabSuratKeluar.vue | v1.2 | 14.19.0: saringan dan penanda bagian penerbit (kop) | 21/10/2026 -->
<script setup>
// Daftar surat keluar: yang perlu tindakan (diperiksa TU, menunggu tanda tangan saya, ditolak) di atas, lalu draf dan surat terbit.
// Diketuk membuka rincian; Tata Usaha dan pimpinan menyusun surat baru dari template.
// v1.2: saringan bagian penerbit (Yayasan, Pondok, Wustha, SMA) dan lencana bagian pada setiap surat.
import { ref, computed, watch, onMounted } from 'vue'
import { PhMagnifyingGlass, PhPlus, PhNotePencil, PhHandPointing } from '@phosphor-icons/vue'
import { usePersuratan } from '@/stores/persuratan'
import { useUI } from '@/stores/ui'
import { STATUS_KELUAR, KATEGORI_TEMPLATE } from '@/lib/suratKeluar'
import { tambahHari, daftarBagian } from '@/lib/persuratan'
import { useLembaga } from '@/stores/lembaga'
import { formatPendek, hariIniISO } from '@/lib/tanggal'
import InputTanggal from '@/components/InputTanggal.vue'
import SaringCorong from '@/components/SaringCorong.vue'
import TombolAksi from '@/components/TombolAksi.vue'

const props = defineProps({ versi: { type: Number, default: 0 } })
const emit = defineEmits(['pilih', 'susun'])
const ps = usePersuratan(); const ui = useUI(); const lembaga = useLembaga()
const daftar = ref([]); const memuat = ref(false); const cari = ref(''); const status = ref(''); const bagian = ref('')
const BAGIAN = computed(() => daftarBagian(lembaga.letterheads)); const infoBagian = (k) => BAGIAN.value.find((b) => b.k === (k || 'pondok'))
const mulai = ref(tambahHari(hariIniISO(), -90)); const selesai = ref(hariIniISO())
async function muat() {
  memuat.value = true
  try { daftar.value = await ps.daftarKeluar(mulai.value, selesai.value) } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
onMounted(muat)
watch([mulai, selesai, () => props.versi], muat)
const perluTindakan = (o) => (o.status === 'diperiksa' && ps.hak.kelola) || o.menunggu_saya || (o.status === 'ditolak' && (o.saya_penyusun || ps.hak.kelola))
const tampil = computed(() => {
  const q = cari.value.toLowerCase().trim()
  return daftar.value.filter((o) => (!bagian.value || (o.kop_kode || 'pondok') === bagian.value) && (!status.value || o.status === status.value) && (!q || `${o.nomor || ''} ${o.perihal} ${o.kepada || ''} ${o.jenis_nama}`.toLowerCase().includes(q)))
})
const grup = computed(() => [{ judul: 'Perlu tindakan Anda', isi: tampil.value.filter(perluTindakan) }, { judul: 'Surat keluar', isi: tampil.value.filter((o) => !perluTindakan(o)) }])
const ketTindakan = (o) => (o.menunggu_saya ? 'Menunggu tanda tangan Anda' : o.status === 'diperiksa' ? 'Periksa dan ajukan tanda tangan' : 'Perbaiki lalu ajukan ulang')
</script>
<template>
  <div>
    <SaringCorong :jumlah="[bagian, status].filter(Boolean).length" :ringkasan="`${formatPendek(mulai)} – ${formatPendek(selesai)}${bagian ? ' · ' + infoBagian(bagian)?.n : ''}${status ? ' · ' + STATUS_KELUAR[status].n : ''}`" judul="Saring surat keluar">
      <template #cari><div class="relative"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
        <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari nomor, perihal, tujuan" aria-label="Cari surat keluar" /></div></template>
      <select v-model="bagian" class="isian md:w-auto" aria-label="Saring bagian penerbit"><option value="">Semua bagian</option>
        <option v-for="b in BAGIAN" :key="b.k" :value="b.k">{{ b.n }}</option></select>
      <select v-model="status" class="isian md:w-auto" aria-label="Saring status"><option value="">Semua status</option>
        <option v-for="(v, k) in STATUS_KELUAR" :key="k" :value="k">{{ v.n }}</option></select>
      <div class="grid w-full grid-cols-2 gap-3 md:w-auto md:min-w-[22rem]"><InputTanggal v-model="mulai" label="Tanggal surat dari" /><InputTanggal v-model="selesai" label="Sampai" /></div>
      <button v-if="ps.hak.susun" class="tombol-utama hidden lg:inline-flex" @click="emit('susun')"><PhPlus :size="20" weight="bold" /> Susun surat</button>
    </SaringCorong>

    <template v-for="(g, gi) in grup" :key="gi">
      <h2 v-if="g.isi.length && (gi === 0 || grup[0].isi.length)" class="judul-bagian mb-2 mt-5 flex items-center gap-2">
        <PhHandPointing v-if="gi === 0" :size="20" weight="duotone" class="text-merah" />{{ g.judul }}<span class="text-sm font-normal text-teks3">({{ g.isi.length }})</span></h2>
      <ul :class="['grid gap-3 md:grid-cols-2', gi === 1 && !grup[0].isi.length && 'mt-4']">
        <li v-for="o in g.isi" :key="o.id">
          <button type="button" class="kartu surat flex w-full items-start gap-3 p-4 text-left transition hover:shadow-apung"
            :class="['w-' + (KATEGORI_TEMPLATE[o.kategori]?.w || 'tatausaha'), gi === 0 && 'perlu', ['dibatalkan', 'dicabut'].includes(o.status) && 'opacity-60']" @click="emit('pilih', o.id)">
            <span class="chip-ikon h-11 w-11 text-xs font-extrabold">{{ o.perihal_kode }}</span>
            <span class="min-w-0 flex-1">
              <span class="flex flex-wrap items-center gap-1.5"><span class="lencana" :class="'w-' + STATUS_KELUAR[o.status].w">{{ STATUS_KELUAR[o.status].n }}</span>
                <span v-if="infoBagian(o.kop_kode)" class="lencana" :class="'w-' + infoBagian(o.kop_kode).w">{{ infoBagian(o.kop_kode).n }}</span>
                <span class="text-xs font-semibold text-teks3">{{ o.jenis_nama }}</span></span>
              <span class="mt-1 block font-bold leading-snug text-teks [overflow-wrap:anywhere]">{{ o.perihal }}</span>
              <span v-if="o.kepada" class="block truncate text-sm text-teks2">{{ o.kepada.split('\n')[0] }}</span>
              <span class="mt-0.5 block text-xs tabular-nums text-teks3">{{ formatPendek(o.tanggal_surat) }} · {{ o.nomor || 'belum bernomor' }} · {{ o.disusun_oleh }}</span>
              <span v-if="gi === 0" class="mt-1.5 inline-flex rounded-lg bg-[#C7332F]/10 px-2 py-0.5 text-xs font-bold text-merah">{{ ketTindakan(o) }}</span>
            </span>
          </button>
        </li>
      </ul>
    </template>
    <div v-if="!tampil.length && !memuat" class="kartu mt-4 flex flex-col items-center p-8 text-center">
      <span class="chip-ikon w-tatausaha h-14 w-14 rounded-2xl"><PhNotePencil :size="30" weight="duotone" /></span>
      <p class="mt-3 font-bold">Belum ada surat keluar</p>
      <p class="mt-1 text-sm text-teks3">{{ ps.hak.susun ? 'Ketuk "Susun surat" untuk membuat surat dari template.' : 'Surat yang melibatkan Anda tampil di sini.' }}</p>
    </div>
    <TombolAksi v-if="ps.hak.susun" label="Susun surat" :ikon="PhPlus" warna="tatausaha" @klik="emit('susun')" />
  </div>
</template>
<style scoped>
.surat.perlu { border-color: #C7332F; box-shadow: inset 4px 0 0 #C7332F; }
</style>
