<!-- SIMKA PRO | src/pages/wali/HafalanWali.vue | v1.1 | Fase 9 – Tahap 13.4.0 Unduh PDF laporan hafalan | 15/10/2026 -->
<script setup>
// Hafalan anak: total juz resmi (kisi juz 1–30), posisi sabaq/sabqi/manzil terakhir, capaian bulanan yang sudah disahkan,
// dan riwayat setoran per periode. Sumber: data Tahfizh yang diisi muhaffizh dan disahkan validator.
import { computed, ref, watch } from 'vue'
import { PhBookOpenText, PhTarget, PhListChecks, PhNotePencil, PhFilePdf } from '@phosphor-icons/vue'
import CetakWali from './CetakWali.vue'
import { usePortalWali } from '@/stores/portalWali'
import { PROGRAM, SUMBER_JUZ, STATUS_BULANAN, formatPosisi, labelBulan } from '@/lib/tahfizh'
import { formatHari, formatPanjang } from '@/lib/tanggal'
import { periodeBulanIni } from '@/lib/portalWali'
import PilihPeriode from './PilihPeriode.vue'

defineOptions({ inheritAttrs: false })
const pw = usePortalWali()
const periode = ref(periodeBulanIni()); const cetak = ref(false); const d = ref(null); const memuat = ref(false); const galat = ref('')
async function muat() {
  if (!periode.value.mulai) return
  memuat.value = true; galat.value = ''
  try { d.value = await pw.ambil('hafalan', periode.value) } catch (e) { galat.value = e.message } finally { memuat.value = false }
}
watch([periode, () => pw.aktif?.nis], muat, { deep: true, immediate: true })

const juzSet = computed(() => new Set((d.value?.juz || []).map((j) => Number(j.juz))))
const POSISI = [
  { k: 'sabaq_hal', n: 'Sabaq', ket: 'Hafalan baru (jumlah hafalan berjalan)', w: 'tahfizh' },
  { k: 'sabqi_hal', n: 'Sabqi', ket: "Muraja'ah hafalan dekat", w: 'presensi' },
  { k: 'manzil_hal', n: 'Manzil', ket: "Muraja'ah hafalan lama", w: 'laporan' },
]
const sumberJuz = computed(() => {
  const n = {}; for (const j of d.value?.juz || []) n[j.sumber] = (n[j.sumber] || 0) + 1
  return Object.entries(n).map(([k, v]) => `${v} juz ${(SUMBER_JUZ[k] || k).toLowerCase()}`).join(', ')
})
</script>

<template>
  <div class="space-y-4">
    <p v-if="galat" class="kartu p-4 text-sm font-semibold text-merah" role="alert">{{ galat }}</p>
    <div v-if="memuat && !d" class="kartu h-40 animate-pulse" aria-busy="true" />
    <p v-if="d?.nonaktif" class="kartu p-6 text-center text-teks3">Informasi ini tidak ditampilkan oleh pondok.</p>

    <template v-if="d && !d.nonaktif">
      <div class="flex justify-end"><button v-if="d && !d.nonaktif" type="button" class="tombol-garis min-h-[40px] px-3.5 text-sm" @click="cetak = true"><PhFilePdf :size="18" weight="duotone" /> Unduh PDF</button></div>
      <!-- Total juz resmi -->
      <section class="kartu w-tahfizh p-4 sm:p-5">
        <div class="flex items-center gap-3">
          <span class="chip-ikon h-11 w-11"><PhBookOpenText :size="24" weight="duotone" /></span>
          <div class="min-w-0 flex-1">
            <h2 class="judul-bagian">Hafalan resmi</h2>
            <p class="text-sm text-teks3">Program {{ PROGRAM[d.program] || d.program }}<template v-if="d.halaqah"> · {{ d.halaqah }}</template></p>
          </div>
          <p class="text-right"><span class="block text-3xl font-extrabold leading-none tabular-nums">{{ juzSet.size }}</span><span class="text-xs text-teks3">dari 30 juz</span></p>
        </div>
        <div class="mt-3 grid grid-cols-10 gap-1" role="img" :aria-label="`Juz resmi: ${[...juzSet].sort((a, b) => a - b).join(', ') || 'belum ada'}`">
          <span v-for="j in 30" :key="j" :class="['grid h-8 place-items-center rounded-lg text-xs font-bold tabular-nums',
            juzSet.has(j) ? 'juz-resmi' : d.juz_sedang === j ? 'juz-sedang' : 'bg-permukaan2 text-teks3']">{{ j }}</span>
        </div>
        <p class="mt-2 flex flex-wrap gap-x-4 gap-y-1 text-xs text-teks3">
          <span class="inline-flex items-center gap-1"><i class="juz-resmi inline-block h-3 w-3 rounded" /> Juz resmi</span>
          <span v-if="d.juz_sedang" class="inline-flex items-center gap-1"><i class="juz-sedang inline-block h-3 w-3 rounded" /> Sedang dihafal (juz {{ d.juz_sedang }})</span>
          <span v-if="sumberJuz">{{ sumberJuz }}</span>
        </p>
      </section>

      <!-- Posisi terakhir -->
      <section class="grid grid-cols-3 gap-3">
        <div v-for="x in POSISI" :key="x.k" :class="['kartu p-3', 'w-' + x.w]">
          <p class="flex items-center gap-1.5 text-sm font-semibold"><span class="titik h-2.5 w-2.5 rounded-full" />{{ x.n }}</p>
          <p class="mt-1 text-lg font-extrabold leading-tight tabular-nums">{{ formatPosisi(d[x.k]) }}</p>
          <p class="text-xs text-teks3">{{ x.ket }}</p>
        </div>
      </section>
      <p v-if="d.posisi_pada" class="-mt-2 px-1 text-xs text-teks3">Posisi terakhir dicatat {{ formatPanjang(d.posisi_pada) }}.</p>

      <!-- Capaian bulanan -->
      <section class="kartu w-rapor p-4 sm:p-5">
        <div class="flex items-center gap-3">
          <span class="chip-ikon h-10 w-10"><PhTarget :size="22" weight="duotone" /></span>
          <div><h2 class="judul-bagian">Capaian bulanan</h2><p class="text-sm text-teks3">Target bulanan yang sudah disahkan pengelola tahfizh.</p></div>
        </div>
        <p v-if="!d.bulanan?.length" class="py-4 text-center text-sm text-teks3">Belum ada capaian bulanan yang disahkan.</p>
        <ul v-else class="mt-3 divide-y divide-garis/70">
          <li v-for="b in d.bulanan" :key="b.bulan" class="flex items-center gap-3 py-2.5">
            <div class="min-w-0 flex-1">
              <p class="font-semibold">{{ labelBulan(b.bulan) }}</p>
              <p class="text-sm text-teks2">Bertambah {{ formatPosisi(b.tambah_hal) }}<template v-if="b.target_hal"> dari target {{ formatPosisi(b.target_hal) }}</template></p>
              <p v-if="b.status === 'murojaah' && b.alasan_murojaah" class="text-xs text-teks3">{{ b.alasan_murojaah }}</p>
            </div>
            <span :class="['lencana shrink-0', 'w-' + (STATUS_BULANAN[b.status]?.w || 'hakakses')]">{{ STATUS_BULANAN[b.status]?.n || b.status }}</span>
          </li>
        </ul>
      </section>

      <!-- Riwayat setoran -->
      <section class="kartu w-presensi p-4 sm:p-5">
        <div class="mb-3 flex items-center gap-3">
          <span class="chip-ikon h-10 w-10"><PhListChecks :size="22" weight="duotone" /></span>
          <div><h2 class="judul-bagian">Riwayat setoran</h2><p class="text-sm text-teks3">Perubahan posisi dan catatan muhaffizh di halaqah.</p></div>
        </div>
        <PilihPeriode v-model="periode" />
        <p v-if="!d.setoran?.length" class="py-4 text-center text-sm text-teks3">Belum ada catatan setoran pada periode ini.</p>
        <ul v-else class="mt-2 divide-y divide-garis/70">
          <li v-for="(s, i) in d.setoran" :key="i" class="py-2.5">
            <div class="flex items-center gap-2">
              <p class="min-w-0 flex-1 text-sm font-semibold">{{ formatHari(s.tanggal) }} <span class="font-normal text-teks3">· {{ s.sesi }}</span></p>
              <span v-if="s.tambah_hal > 0" class="lencana w-presensi shrink-0">+{{ formatPosisi(s.tambah_hal) }}</span>
            </div>
            <p class="text-xs text-teks2">Sabaq {{ formatPosisi(s.sabaq_hal) }} · Sabqi {{ formatPosisi(s.sabqi_hal) }} · Manzil {{ formatPosisi(s.manzil_hal) }}</p>
            <p v-if="s.catatan" class="mt-1 flex items-start gap-1.5 text-xs text-teks2"><PhNotePencil :size="14" class="mt-0.5 shrink-0" /> {{ s.catatan }}</p>
          </li>
        </ul>
      </section>
    </template>
    <CetakWali v-if="d && !d.nonaktif" :jenis="'hafalan'" :data="d" v-model:pratinjau="cetak" />
  </div>
</template>
<style scoped>
.titik { background: var(--c); }
.juz-resmi { background: #8C6200; color: #fff; }
.juz-sedang { box-shadow: inset 0 0 0 2px #2F5FA8; color: rgb(var(--teks)); }
:global(html.dark) .juz-resmi { background: #F2C24B; color: #2B1D00; }
:global(html.dark) .juz-sedang { box-shadow: inset 0 0 0 2px #8AB4F8; }
</style>
