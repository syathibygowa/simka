<!-- SIMKA PRO | src/pages/tahfizh/TabSetoran.vue | v1.0 | Fase 5 – Tahap 2 Setoran per sesi halaqah | 05/10/2026 -->
<script setup>
// Daftar sesi setoran halaqah pada satu tanggal (bawaan hari ini). Muhaffizh: halaqah asuhannya.
// Admin/pimpinan Bidang Tahfizh: dapat beralih ke "Semua halaqah" untuk memantau kepatuhan pengisian (langsung/realtime).
// Ketuk kartu untuk membuka formulir halaqah (tab Absensi | Setoran).
import { ref, computed, onMounted, onBeforeUnmount, watch } from 'vue'
import { useRouter } from 'vue-router'
import { PhSunHorizon, PhSun, PhMoonStars, PhTrendUp, PhWarning, PhCheckCircle, PhClock, PhUsersThree, PhCaretRight, PhBookOpenText, PhListChecks } from '@phosphor-icons/vue'
import { useTahfizh } from '@/stores/tahfizh'
import { STATUS_SETORAN, formatPosisi } from '@/lib/tahfizh'
import { jam } from '@/lib/absensi'
import { hariIniISO, formatJam } from '@/lib/tanggal'
import KartuStatistik from '@/components/KartuStatistik.vue'
import InputTanggal from '@/components/InputTanggal.vue'

const tz = useTahfizh(); const router = useRouter()
const tanggal = ref(hariIniISO()); const semua = ref(false); const sesiPilih = ref('')
const bolehSemua = computed(() => tz.hak.atur || tz.hak.validasi || tz.hak.pimpinan)
const muat = () => tz.muatStatusSetoran(tanggal.value, semua.value)
onMounted(async () => {
  if (!tz.hakDimuat) await tz.muatHak()
  semua.value = bolehSemua.value && !tz.hak.muhaffizh
  await muat(); tz.dengarkanSetoran(muat)
})
onBeforeUnmount(() => tz.berhentiSetoran())
watch([tanggal, semua], muat)

const IKON_SESI = { SUBUH: PhSunHorizon, SORE: PhSun, MALAM: PhMoonStars }
const daftarSesi = computed(() => [...new Map(tz.sesiSetoran.map((x) => [x.sesi, x.nama_sesi])).entries()])
const tampil = computed(() => tz.sesiSetoran.filter((x) => !sesiPilih.value || x.sesi === sesiPilih.value))
const statistik = computed(() => {
  const d = tampil.value; const terisi = d.filter((x) => x.status === 'terisi')
  return [
    { judul: 'Sesi terisi', nilai: `${terisi.length}/${d.filter((x) => x.status !== 'belum_buka').length}`, ikon: PhCheckCircle, warna: 'presensi', ket: 'Setoran sudah disimpan' },
    { judul: 'Santri bertambah', nilai: terisi.reduce((n, x) => n + (x.jumlah_bertambah || 0), 0), ikon: PhTrendUp, warna: 'tahfizh', ket: 'Sabaq maju pada sesi terisi' },
    { judul: 'Total penambahan', nilai: formatPosisi(terisi.reduce((n, x) => n + (x.total_tambah_hal || 0), 0)) || '0', ikon: PhBookOpenText, warna: 'pengajuan', ket: 'Jumlah halaman sabaq baru' },
    { judul: 'Isian janggal', nilai: terisi.reduce((n, x) => n + (x.jumlah_janggal || 0), 0), ikon: PhWarning, warna: 'klinik', ket: 'Perlu dicek pimpinan' },
  ]
})
function buka(x) {
  router.push({ path: `/absensi-santri/isi/${x.group_id}/${x.tanggal}/${x.sesi}`, query: x.absensi === 'terisi' ? { tab: 'setoran' } : {} })
}
</script>
<template>
  <div>
    <div class="flex flex-wrap items-end gap-2">
      <div class="w-48"><InputTanggal v-model="tanggal" label="Tanggal setoran" /></div>
      <select v-model="sesiPilih" class="isian w-auto" aria-label="Saring sesi"><option value="">Semua sesi</option><option v-for="[k, n] in daftarSesi" :key="k" :value="k">{{ n }}</option></select>
      <div v-if="bolehSemua" class="grid grid-cols-2 gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" aria-label="Cakupan">
        <button type="button" role="radio" :aria-checked="!semua" @click="semua = false" :class="['min-h-[40px] rounded-xl px-3 text-sm font-semibold', !semua ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">Asuhan saya</button>
        <button type="button" role="radio" :aria-checked="semua" @click="semua = true" :class="['min-h-[40px] rounded-xl px-3 text-sm font-semibold', semua ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">Semua halaqah</button>
      </div>
    </div>
    <p class="mt-2 text-sm text-teks3">Ketuk kartu halaqah: isi absensi dahulu, lalu setoran pada halaman yang sama.</p>

    <div class="-mx-4 mt-3 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-4 sm:overflow-visible sm:px-0">
      <KartuStatistik v-for="k in statistik" :key="k.judul" class="w-[46%] shrink-0 snap-start sm:w-auto" :judul="k.judul" :nilai="tz.memuatSetoran && !tz.sesiSetoran.length ? '…' : k.nilai" :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket" />
    </div>

    <p v-if="tz.galat" class="mt-4 rounded-xl bg-[#C7332F]/10 p-3 text-sm font-semibold text-merah">{{ tz.galat }}</p>
    <ul class="mt-4 grid gap-3 md:grid-cols-2 xl:grid-cols-3">
      <li v-for="x in tampil" :key="x.group_id + x.sesi">
        <button type="button" :class="['kartu w-full p-4 text-left active:bg-permukaan2', 'w-' + STATUS_SETORAN[x.status].w]" :disabled="x.status === 'belum_buka'" @click="buka(x)">
          <span class="flex items-center gap-3">
            <span class="chip-ikon h-11 w-11"><component :is="IKON_SESI[x.sesi] || PhClock" :size="24" weight="duotone" /></span>
            <span class="min-w-0 flex-1"><b class="block truncate">{{ x.nama_kelompok }}</b>
              <span class="block truncate text-sm text-teks3">{{ x.nama_sesi }} · {{ jam(x.jam_mulai) }}–{{ jam(x.jam_selesai) }}<template v-if="semua && x.pengampu"> · {{ x.pengampu }}</template></span></span>
            <PhCaretRight :size="18" class="text-teks3" />
          </span>
          <span class="mt-3 flex flex-wrap gap-1.5 text-xs">
            <span class="lencana" :class="'w-' + STATUS_SETORAN[x.status].w">Setoran: {{ STATUS_SETORAN[x.status].n }}</span>
            <span :class="['lencana', x.absensi === 'terisi' ? 'w-absensi' : 'w-hakakses']"><PhListChecks :size="13" /> Absensi {{ x.absensi === 'terisi' ? 'terisi' : 'belum' }}</span>
            <span class="lencana w-santri"><PhUsersThree :size="13" /> {{ x.jumlah_anggota }} santri</span>
            <template v-if="x.status === 'terisi'">
              <span class="lencana w-presensi"><PhTrendUp :size="13" /> {{ x.jumlah_bertambah }} bertambah · +{{ x.total_tambah_hal }} hal</span>
              <span v-if="x.jumlah_tidak_setor" class="lencana w-klinik">{{ x.jumlah_tidak_setor }} tidak setor</span>
              <span v-if="x.jumlah_janggal" class="lencana w-laporan"><PhWarning :size="13" /> {{ x.jumlah_janggal }} janggal</span>
            </template>
            <span v-else-if="x.status === 'belum_buka'" class="lencana w-hakakses">Dibuka {{ formatJam(x.buka) }}</span>
          </span>
        </button>
      </li>
    </ul>
    <p v-if="!tampil.length && !tz.memuatSetoran" class="kartu mt-4 p-8 text-center text-sm text-teks3">
      {{ semua ? 'Tidak ada sesi halaqah pada tanggal ini (hari libur atau halaqah belum dibentuk).' : 'Tidak ada halaqah asuhan Anda pada tanggal ini.' }}</p>
  </div>
</template>
