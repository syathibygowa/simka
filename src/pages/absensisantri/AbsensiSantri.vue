<!-- SIMKA PRO | src/pages/absensisantri/AbsensiSantri.vue | v1.0 | Fase 4 – Tahap 3 Absensi HISBAT | 04/10/2026 -->
<script setup>
// Absensi santri HISBAT. Tab: Sesi saya (pengasuh), Pantauan (admin/pimpinan: semua kelompok, langsung),
// Rekap (per kelompok dan periode; Excel, cetak F4, WA ke wali).
import { ref, computed, onMounted, onBeforeUnmount, watch } from 'vue'
import { useRouter } from 'vue-router'
import { PhListChecks, PhBroadcast, PhChartBar, PhCaretRight, PhCheckCircle, PhHourglassMedium, PhWarningCircle, PhUsersThree, PhUserSwitch } from '@phosphor-icons/vue'
import { useAbsensiSantri } from '@/stores/absensiSantri'
import { useSesi } from '@/stores/sesi'
import { JENIS_ABSENSI, STATUS_SESI, jam, persen, teksPersen } from '@/lib/absensi'
import { judulKelompok } from '@/lib/santri'
import { hariIniISO, formatHari, formatJam } from '@/lib/tanggal'
import KartuStatistik from '@/components/KartuStatistik.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import TabRekapAbsensi from './TabRekapAbsensi.vue'

const props = defineProps({ tab: { type: String, default: '' } })
const router = useRouter(); const abs = useAbsensiSantri(); const sesi = useSesi()
const bolehPantau = computed(() => sesi.isAdmin || (sesi.tingkat('absensi_kelas') >= 1 && sesi.tingkat('data_santri') >= 1))
const punyaAsuhan = computed(() => sesi.kelompokSaya.some((k) => ['kelas', 'halaqah', 'kamar'].includes(k.jenis)))
const TAB = computed(() => [
  ...(punyaAsuhan.value || !bolehPantau.value ? [{ k: 'sesi', n: 'Sesi saya', ikon: PhListChecks, w: 'absensi' }] : []),
  ...(bolehPantau.value ? [{ k: 'pantauan', n: 'Pantauan', ikon: PhBroadcast, w: 'shift' }] : []),
  { k: 'rekap', n: 'Rekap', ikon: PhChartBar, w: 'rekap' },
])
const aktif = computed(() => (TAB.value.some((t) => t.k === props.tab) ? props.tab : TAB.value[0].k))
const tanggal = ref(hariIniISO()); const saringJenis = ref(''); const saringStatus = ref('')
const semua = computed(() => aktif.value === 'pantauan')
async function muat() { if (aktif.value !== 'rekap') await abs.muatSesi(tanggal.value, semua.value) }
let jeda = null
onMounted(() => { muat(); abs.dengarkan(() => muat()); jeda = setInterval(() => { if (aktif.value !== 'rekap') muat() }, 60000) })
onBeforeUnmount(() => { clearInterval(jeda); abs.berhenti() })
watch([aktif, tanggal], muat)

const daftar = computed(() => abs.sesiHari.filter((s) => (!saringJenis.value || s.jenis === saringJenis.value) && (!saringStatus.value || s.status === saringStatus.value)))
const terisi = computed(() => abs.sesiHari.filter((s) => s.status === 'terisi'))
const statistik = computed(() => {
  const t = terisi.value; const sum = (k) => t.reduce((n, s) => n + (s[k] || 0), 0)
  const ang = t.reduce((n, s) => n + (s.jumlah_anggota || 0), 0)
  return [
    { judul: 'Sesi terisi', nilai: `${t.length}/${abs.sesiHari.length}`, ikon: PhCheckCircle, warna: 'presensi', ket: 'Sesi hari ini yang sudah diabsen' },
    { judul: 'Belum diisi', nilai: abs.sesiHari.filter((s) => ['lewat', 'tidak_terisi', 'terbuka'].includes(s.status)).length, ikon: PhHourglassMedium, warna: 'klinik', ket: 'Sedang berlangsung atau lewat jam' },
    { judul: 'Kehadiran', nilai: teksPersen(persen(sum('jumlah_hadir'), ang)), ikon: PhUsersThree, warna: 'absensi', ket: `${sum('jumlah_hadir')} dari ${ang} kehadiran tercatat` },
    { judul: 'Izin · Sakit · Absen', nilai: `${sum('jumlah_izin')} · ${sum('jumlah_sakit')} · ${sum('jumlah_absen')}`, ikon: PhWarningCircle, warna: 'pengajuan', ket: `Bolos ${sum('jumlah_bolos')} · Terlambat ${sum('jumlah_terlambat')}` },
  ]
})
const buka = (s) => router.push(`/absensi-santri/isi/${s.group_id}/${s.tanggal}/${s.sesi}`)
const pilihTab = (k) => router.replace(`/absensi-santri/${k}`)
</script>
<template>
  <div>
    <div class="-mx-4 mb-4 flex gap-2 overflow-x-auto px-4 pb-1 lg:mx-0 lg:px-0" role="tablist">
      <button v-for="t in TAB" :key="t.k" role="tab" :aria-selected="aktif === t.k" @click="pilihTab(t.k)"
        :class="['inline-flex min-h-[44px] shrink-0 items-center gap-2 rounded-full border-2 px-4 text-sm font-semibold', 'w-' + t.w, aktif === t.k ? 'text-teks' : 'border-garis bg-permukaan text-teks2']"
        :style="aktif === t.k ? 'border-color: var(--c); background: color-mix(in srgb, var(--c) 14%, transparent)' : ''">
        <component :is="t.ikon" :size="18" weight="duotone" style="color: var(--c)" />{{ t.n }}</button>
    </div>

    <TabRekapAbsensi v-if="aktif === 'rekap'" :semua="bolehPantau" />

    <template v-else>
      <div class="mb-4 flex flex-wrap items-end gap-3">
        <div class="w-48"><InputTanggal v-model="tanggal" label="Tanggal" wajib /></div>
        <p class="flex-1 pb-3 text-sm text-teks3">{{ formatHari(tanggal) }} · halaqah dan asrama mengikuti jam sesi di Pengaturan Presensi.</p>
      </div>

      <div v-if="semua" class="-mx-4 mb-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-2 sm:overflow-visible sm:px-0 xl:grid-cols-4">
        <KartuStatistik v-for="k in statistik" :key="k.judul" class="w-[46%] shrink-0 snap-start sm:w-auto" :judul="k.judul" :nilai="abs.memuat && !abs.sesiHari.length ? '…' : k.nilai" :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket" />
      </div>

      <div class="-mx-4 mb-3 flex gap-2 overflow-x-auto px-4 pb-1 lg:mx-0 lg:px-0">
        <button v-for="j in [{ k: '', n: 'Semua' }, ...Object.entries(JENIS_ABSENSI).map(([k, v]) => ({ k, n: v.n, w: v.warna }))]" :key="j.k" :aria-pressed="saringJenis === j.k" @click="saringJenis = j.k"
          :class="['min-h-[40px] shrink-0 rounded-full border px-4 text-sm font-semibold', saringJenis === j.k ? 'border-transparent bg-[#4338CA] text-white dark:bg-[#A5B4FC] dark:text-[#1E1B4B]' : 'border-garis bg-permukaan text-teks2']">{{ j.n }}</button>
        <select v-if="semua" v-model="saringStatus" class="isian w-auto shrink-0" aria-label="Saring status">
          <option value="">Semua status</option><option v-for="(s, k) in STATUS_SESI" :key="k" :value="k">{{ s.n }}</option>
        </select>
      </div>

      <p v-if="abs.galat" class="mb-3 rounded-xl bg-[#C7332F]/10 p-3 text-sm font-semibold text-merah">{{ abs.galat }}</p>

      <ul class="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
        <li v-for="s in daftar" :key="s.group_id + s.sesi">
          <button type="button" :class="['kartu flex h-full w-full flex-col gap-2 p-4 text-left transition hover:-translate-y-0.5 hover:shadow-apung', 'w-' + JENIS_ABSENSI[s.jenis].warna]" @click="buka(s)">
            <div class="flex items-start gap-3">
              <span class="chip-ikon h-11 w-11 shrink-0 text-xs font-extrabold">{{ jam(s.jam_mulai) }}</span>
              <div class="min-w-0 flex-1">
                <p class="truncate font-bold">{{ judulKelompok({ jenis: s.jenis_kelompok, nama: s.nama_kelompok }) }}</p>
                <p class="text-sm text-teks3">{{ s.nama_sesi }} · {{ jam(s.jam_mulai) }}–{{ jam(s.jam_selesai) }}</p>
              </div>
              <PhCaretRight :size="18" class="mt-1 text-teks3" />
            </div>
            <div class="flex flex-wrap items-center gap-2">
              <span :class="['lencana', 'w-' + STATUS_SESI[s.status].w]">{{ STATUS_SESI[s.status].n }}</span>
              <span v-if="s.status === 'belum_buka'" class="text-xs text-teks3">dibuka {{ formatJam(s.buka) }}</span>
              <span v-if="s.atas_nama" class="lencana w-verval"><PhUserSwitch :size="12" /> atas nama</span>
              <span v-if="s.diisi_terlambat" class="lencana w-hakakses">diisi terlambat</span>
            </div>
            <p v-if="s.status === 'terisi'" class="text-sm"><b class="tabular-nums" style="color: var(--c)">{{ s.jumlah_hadir }}/{{ s.jumlah_anggota }} hadir</b>
              <span class="text-teks2">{{ [s.jumlah_izin && `I ${s.jumlah_izin}`, s.jumlah_sakit && `S ${s.jumlah_sakit}`, s.jumlah_bolos && `B ${s.jumlah_bolos}`, s.jumlah_absen && `A ${s.jumlah_absen}`, s.jumlah_terlambat && `T ${s.jumlah_terlambat}`].filter(Boolean).map((x) => ' · ' + x).join('') }}</span></p>
            <p v-else class="text-sm text-teks2">{{ s.jumlah_anggota }} santri</p>
            <p v-if="semua" class="mt-auto border-t border-garis pt-2 text-xs text-teks3">{{ JENIS_ABSENSI[s.jenis].pengampu }}: {{ s.pengampu || 'belum ditetapkan' }}</p>
          </button>
        </li>
      </ul>
      <p v-if="!daftar.length && !abs.memuat" class="kartu py-10 text-center text-sm text-teks3">
        {{ semua ? 'Tidak ada sesi absensi pada tanggal ini (hari libur atau belum ada kelompok).' : 'Tidak ada sesi absensi untuk kelompok asuhan Anda pada tanggal ini.' }}</p>
    </template>
  </div>
</template>
