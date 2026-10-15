<!-- SIMKA PRO | src/pages/wali/KehadiranWali.vue | v1.1 | Fase 9 – Tahap 13.4.0 Unduh PDF rekap kehadiran | 15/10/2026 -->
<script setup>
// Kehadiran anak: persentase program pokok (kelas + halaqah + asrama; Terlambat dan Bolos dihitung hadir),
// rekap per kegiatan termasuk ekskul, jumlah HISBAT, dan catatan per tanggal. Periode bawaan bulan ini, paling panjang satu semester.
import { computed, ref, watch } from 'vue'
import { PhCalendarCheck, PhFilePdf } from '@phosphor-icons/vue'
import CetakWali from './CetakWali.vue'
import { usePortalWali } from '@/stores/portalWali'
import { KODE, JENIS_ABSENSI, teksPersen } from '@/lib/absensi'
import { formatHari } from '@/lib/tanggal'
import PilihPeriode from './PilihPeriode.vue'

defineOptions({ inheritAttrs: false })
const pw = usePortalWali()
const periode = ref({}); const d = ref(null); const memuat = ref(false); const galat = ref('')
const hanyaCatatan = ref(false); const cetak = ref(false)

async function muat() {
  if (!periode.value.mulai) return
  memuat.value = true; galat.value = ''
  try { d.value = await pw.ambil('kehadiran', periode.value) } catch (e) { galat.value = e.message } finally { memuat.value = false }
}
watch([periode, () => pw.aktif?.nis], muat, { deep: true, immediate: true })

const rekap = computed(() => d.value?.rekap || {})
const pokok = computed(() => rekap.value.pokok || { sesi: 0 })
const URUT = ['kelas', 'halaqah', 'asrama', 'ekskul']
const kegiatan = computed(() => URUT.filter((j) => rekap.value[j]?.sesi).map((j) => ({ j, ...rekap.value[j], ...JENIS_ABSENSI[j] })))
const jumlahKode = computed(() => [
  { k: 'I', n: pokok.value.izin }, { k: 'S', n: pokok.value.sakit }, { k: 'A', n: pokok.value.absen },
  { k: 'B', n: pokok.value.bolos }, { k: 'T', n: pokok.value.terlambat },
])
const warnaPersen = (p) => (p == null ? 'beranda' : p >= 90 ? 'presensi' : p >= 80 ? 'tahfizh' : 'klinik')

// Sesi dikelompokkan per tanggal
const hari = computed(() => {
  const peta = new Map()
  for (const s of d.value?.sesi || []) {
    if (hanyaCatatan.value && s.k === 'H') continue
    if (!peta.has(s.t)) peta.set(s.t, [])
    peta.get(s.t).push(s)
  }
  return [...peta.entries()].map(([t, sesi]) => ({ t, sesi }))
})
</script>

<template>
  <div class="space-y-4">
    <div class="flex flex-col gap-2 sm:flex-row sm:items-start"><PilihPeriode v-model="periode" class="min-w-0 flex-1" /><button v-if="d && !d.nonaktif" type="button" class="tombol-garis min-h-[40px] self-start px-3.5 text-sm" @click="cetak = true"><PhFilePdf :size="18" weight="duotone" /> Unduh PDF</button></div>
    <p v-if="galat" class="kartu p-4 text-sm font-semibold text-merah" role="alert">{{ galat }}</p>
    <div v-if="memuat && !d" class="kartu h-40 animate-pulse" aria-busy="true" />

    <template v-if="d">
      <!-- Persentase program pokok -->
      <section :class="['kartu p-4 sm:p-5', 'w-' + warnaPersen(pokok.persen)]">
        <div class="flex items-center gap-4">
          <div class="cincin grid h-20 w-20 shrink-0 place-items-center rounded-full" :style="{ '--p': (pokok.persen || 0) + '%' }">
            <span class="grid h-[64px] w-[64px] place-items-center rounded-full bg-permukaan text-lg font-extrabold tabular-nums">{{ teksPersen(pokok.persen) }}</span>
          </div>
          <div class="min-w-0">
            <h2 class="judul-bagian">Kehadiran program pokok</h2>
            <p class="text-sm text-teks2">{{ pokok.sesi ? `Hadir ${pokok.hadir} dari ${pokok.sesi} sesi kelas, halaqah, dan asrama` : 'Belum ada absensi pada periode ini.' }}</p>
            <p class="text-xs text-teks3">Terlambat dan Bolos tetap dihitung hadir.</p>
          </div>
        </div>
        <div v-if="pokok.sesi" class="mt-3 flex flex-wrap gap-1.5">
          <span v-for="x in jumlahKode" :key="x.k" :class="['lencana kode', 'w-' + KODE[x.k].w]">{{ KODE[x.k].n }} {{ x.n }}</span>
        </div>
      </section>

      <!-- Per kegiatan -->
      <section v-if="kegiatan.length" class="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <div v-for="k in kegiatan" :key="k.j" :class="['kartu p-3.5', 'w-' + k.warna]">
          <p class="flex items-center gap-2 text-sm font-semibold"><span class="titik h-2.5 w-2.5 rounded-full" />{{ k.n }}</p>
          <p class="mt-1 text-2xl font-extrabold tabular-nums">{{ teksPersen(k.persen) }}</p>
          <p class="text-xs text-teks3">Hadir {{ k.hadir }}/{{ k.sesi }} sesi<template v-if="k.j === 'ekskul'"> · di luar program pokok</template></p>
          <div class="mt-2 h-1.5 overflow-hidden rounded-full bg-permukaan2"><div class="batang h-full rounded-full" :style="{ width: (k.persen || 0) + '%' }" /></div>
        </div>
      </section>

      <!-- Per tanggal -->
      <section class="kartu w-presensi p-4 sm:p-5">
        <div class="flex flex-wrap items-center gap-3">
          <span class="chip-ikon h-10 w-10"><PhCalendarCheck :size="22" weight="duotone" /></span>
          <h2 class="judul-bagian flex-1">Rincian per tanggal</h2>
          <div class="flex w-full rounded-xl bg-permukaan2 p-1 text-sm font-semibold sm:w-auto" role="radiogroup" aria-label="Tampilan rincian">
            <button type="button" role="radio" :aria-checked="!hanyaCatatan" :class="['min-h-[36px] flex-1 rounded-lg px-3', !hanyaCatatan ? 'bg-permukaan shadow-kartu' : 'text-teks2']" @click="hanyaCatatan = false">Semua</button>
            <button type="button" role="radio" :aria-checked="hanyaCatatan" :class="['min-h-[36px] flex-1 rounded-lg px-3', hanyaCatatan ? 'bg-permukaan shadow-kartu' : 'text-teks2']" @click="hanyaCatatan = true">Hanya catatan</button>
          </div>
        </div>
        <p class="mt-2 flex flex-wrap gap-x-3 gap-y-1 text-xs text-teks3">
          <span v-for="(v, k) in KODE" :key="k"><b :class="['kode-huruf', 'w-' + v.w]">{{ k }}</b> {{ v.n }}</span>
        </p>
        <p v-if="!hari.length" class="py-6 text-center text-sm text-teks3">{{ hanyaCatatan ? 'Tidak ada catatan ketidakhadiran pada periode ini. Alhamdulillah.' : 'Belum ada absensi pada periode ini.' }}</p>
        <ul v-else class="mt-2 divide-y divide-garis/70">
          <li v-for="h in hari" :key="h.t" class="py-2.5">
            <p class="text-sm font-semibold">{{ formatHari(h.t) }}</p>
            <ul class="mt-1.5 flex flex-wrap gap-1.5">
              <li v-for="(s, i) in h.sesi" :key="i" :class="['sesi flex items-center gap-1.5 rounded-lg px-2 py-1 text-xs', 'w-' + KODE[s.k]?.w]"
                :title="`${s.s} · ${s.g}: ${KODE[s.k]?.n}`">
                <b class="kode-huruf">{{ s.k }}</b>
                <span>{{ s.s }}</span><span v-if="s.jam" class="tabular-nums text-teks3">{{ s.jam }}</span>
              </li>
            </ul>
            <p v-for="(s, i) in h.sesi.filter((x) => x.ket)" :key="'k' + i" class="mt-1 text-xs text-teks2">{{ s.s }}: {{ KODE[s.k]?.n }} – {{ s.ket }}</p>
          </li>
        </ul>
      </section>
    </template>
    <CetakWali v-if="d && !d.nonaktif" :jenis="'kehadiran'" :data="d" v-model:pratinjau="cetak" />
  </div>
</template>
<style scoped>
.cincin { background: conic-gradient(var(--c) var(--p), rgb(var(--garis)) 0); }
.titik, .batang { background: var(--c); }
.lencana.kode, .sesi { color: rgb(var(--teks)); background: color-mix(in srgb, var(--c) 16%, rgb(var(--permukaan))); }
.kode-huruf { display: inline-grid; place-items: center; min-width: 1.25rem; height: 1.25rem; border-radius: .375rem; color: #fff; background: var(--c); font-weight: 700; font-size: .7rem; }
</style>
