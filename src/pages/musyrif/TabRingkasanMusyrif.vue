<!-- SIMKA PRO | src/pages/musyrif/TabRingkasanMusyrif.vue | v1.1 | Fase 6 – Perbaikan: dasbor Semua kamar selalu tampil bagi admin/pimpinan | 06/10/2026 -->
<script setup>
// Dasbor pemantauan seluruh kamar untuk admin, superadmin, dan pimpinan: kehadiran asrama, keterisian sesi,
// santri sakit/izin, dan keaktifan jurnal musyrif per kamar. Ketuk kartu kamar untuk membuka dasbor kamar itu.
import { ref, computed, watch, onMounted, onBeforeUnmount } from 'vue'
import { PhChartLineUp, PhCheckSquareOffset, PhFirstAidKit, PhSignOut, PhNotePencil, PhStar, PhArrowRight, PhWarningCircle } from '@phosphor-icons/vue'
import { useMusyrif } from '@/stores/musyrif'
import { useUI } from '@/stores/ui'
import { teksPersen } from '@/lib/absensi'
import { awalPekan, awalBulanDari, akhirBulanDari, tambahHari, teksRentang } from '@/lib/musyrif'
import { hariIniISO, formatPendek } from '@/lib/tanggal'
import KartuStatistik from '@/components/KartuStatistik.vue'

const emit = defineEmits(['buka'])
const mu = useMusyrif(); const ui = useUI(); const hari = hariIniISO()
const PERIODE = [{ k: 'hari', n: 'Hari ini', m: hari, s: hari }, { k: 'pekan', n: 'Pekan ini', m: awalPekan(hari), s: hari },
  { k: 'bulan', n: 'Bulan ini', m: awalBulanDari(hari), s: hari }, { k: 'lalu', n: 'Bulan lalu', m: awalBulanDari(tambahHari(awalBulanDari(hari), -1)), s: akhirBulanDari(tambahHari(awalBulanDari(hari), -1)) }]
const periode = ref('pekan'); const data = ref([]); const memuat = ref(false); const galat = ref('')
const p = computed(() => PERIODE.find((x) => x.k === periode.value))
async function muat() { memuat.value = true; galat.value = ''; try { data.value = await mu.ringkasan(p.value.m, p.value.s) } catch (e) { galat.value = e.message } finally { memuat.value = false } }
onMounted(() => { muat(); mu.dengarkan(muat) })
onBeforeUnmount(() => mu.berhenti())
watch(periode, muat)

const jumlah = (k) => data.value.reduce((a, x) => a + (Number(x[k]) || 0), 0)
const rata = computed(() => { const n = jumlah('anggota'); return n ? Math.round((jumlah('hadir') / n) * 1000) / 10 : null })
const statistik = computed(() => [
  { judul: 'Kehadiran asrama', nilai: teksPersen(rata.value), ikon: PhChartLineUp, warna: 'musyrif', ket: `${data.value.length} kamar` },
  { judul: 'Sesi terisi', nilai: `${jumlah('sesi_terisi')}/${data.value.reduce((a, x) => a + x.sesi_rencana, 0)}`, ikon: PhCheckSquareOffset, warna: 'absensi', ket: 'Terisi / seharusnya' },
  { judul: 'Sakit di klinik', nilai: jumlah('sakit_aktif'), ikon: PhFirstAidKit, warna: 'klinik', ket: 'Sedang ditangani' },
  { judul: 'Izin aktif', nilai: jumlah('izin_aktif'), ikon: PhSignOut, warna: 'pengajuan', ket: `${jumlah('izin_terlambat')} terlambat kembali` },
])
const warna = (v) => (v == null ? 'w-hakakses' : v >= 95 ? 'w-presensi' : v >= 85 ? 'w-agenda' : v >= 75 ? 'w-laporan' : 'w-klinik')
const persenIsi = (x) => (x.sesi_rencana ? Math.round((x.sesi_terisi / x.sesi_rencana) * 100) : null)
const urut = computed(() => [...data.value].sort((a, b) => (a.persen ?? 101) - (b.persen ?? 101)))
function buka(x) { mu.pilih = x.id; emit('buka') }
</script>
<template>
  <div>
    <div class="mb-3 flex flex-wrap items-center gap-2">
      <button v-for="x in PERIODE" :key="x.k" :class="['min-h-[36px] rounded-full border px-3 text-sm font-semibold', periode === x.k ? 'border-transparent bg-[#245E3F] text-white' : 'border-garis bg-permukaan text-teks2']" @click="periode = x.k">{{ x.n }}</button>
      <span class="text-xs text-teks3">{{ teksRentang(p.m, p.s) }}</span>
    </div>
    <div class="-mx-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-4 sm:overflow-visible sm:px-0">
      <KartuStatistik v-for="k in statistik" :key="k.judul" class="w-[44%] shrink-0 snap-start sm:w-auto" :judul="k.judul" :nilai="memuat && !data.length ? '…' : k.nilai" :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket" />
    </div>
    <ul class="mt-4 grid gap-3 md:grid-cols-2 xl:grid-cols-3">
      <li v-for="x in urut" :key="x.id">
        <button class="kartu w-full p-4 text-left transition hover:-translate-y-0.5" :class="warna(x.persen)" @click="buka(x)">
          <div class="flex items-start gap-3">
            <div class="min-w-0 flex-1"><b class="block truncate">{{ x.nama }}</b>
              <span class="block truncate text-xs text-teks3">{{ x.santri }} santri · {{ x.musyrif || 'belum ada musyrif' }}</span></div>
            <span class="text-2xl font-extrabold tabular-nums" style="color: var(--c)">{{ teksPersen(x.persen) }}</span>
          </div>
          <div class="mt-3 h-2 overflow-hidden rounded-full bg-permukaan2" role="img" :aria-label="`Keterisian sesi ${persenIsi(x) ?? 0}%`">
            <div class="h-full rounded-full" :style="{ width: (persenIsi(x) ?? 0) + '%', background: 'var(--c)' }" /></div>
          <p class="mt-1 text-xs text-teks3">Sesi terisi {{ x.sesi_terisi }}/{{ x.sesi_rencana }}{{ x.hari_ini_terisi ? ` · hari ini ${x.hari_ini_terisi} sesi` : ' · hari ini belum diisi' }}</p>
          <div class="mt-2 flex flex-wrap gap-1.5 text-xs">
            <span class="lencana w-pengajuan">I {{ x.izin }}</span><span class="lencana w-klinik">S {{ x.sakit }}</span><span class="lencana w-beranda">A {{ x.absen }}</span>
            <span v-if="x.sakit_aktif" class="lencana w-klinik"><PhFirstAidKit :size="12" /> {{ x.sakit_aktif }} di klinik</span>
            <span v-if="x.izin_aktif" class="lencana w-pengajuan"><PhSignOut :size="12" /> {{ x.izin_aktif }} izin</span>
            <span v-if="x.izin_terlambat" class="lencana w-klinik"><PhWarningCircle :size="12" /> {{ x.izin_terlambat }} terlambat</span>
          </div>
          <p class="mt-2 flex items-center gap-1.5 text-xs text-teks2"><PhNotePencil :size="14" /> {{ x.jurnal }} jurnal<template v-if="x.jurnal_penting"> · <PhStar :size="12" weight="fill" class="text-[#B5501A]" /> {{ x.jurnal_penting }} penting</template>
            · terakhir {{ x.jurnal_terakhir ? formatPendek(x.jurnal_terakhir) : '–' }}<PhArrowRight :size="14" class="ml-auto" /></p>
        </button>
      </li>
    </ul>
    <p v-if="galat" class="kartu w-klinik mt-4 p-5 text-sm font-semibold" style="color: var(--c)">Ringkasan gagal dimuat: {{ galat }}</p>
    <div v-else-if="!data.length && !memuat" class="kartu mt-4 p-6 text-center text-sm text-teks2">
      <p class="font-semibold">Belum ada kamar aktif pada tahun ajaran aktif.</p>
      <p class="mt-1 text-teks3">Dasbor terisi setelah kamar dibuat dan diisi santri serta musyrifnya di Kelompok Santri → Kamar.</p>
      <router-link to="/kelompok-santri" class="tombol-utama mt-3 inline-flex">Buka Kelompok Santri</router-link>
    </div>
    <p class="mt-3 text-xs text-teks3">Kamar diurutkan dari kehadiran terendah. Ketuk kartu untuk membuka dasbor kamar.</p>
  </div>
</template>
