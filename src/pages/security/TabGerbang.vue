<!-- SIMKA PRO | src/pages/security/TabGerbang.vue | v1.1 | Fase 7 – Tahap 2 Titipan, buku tamu, kunjungan | 06/10/2026 -->
<script setup>
// Gerbang santri (mode "gerbang") dan santri di luar pondok (mode "diluar").
//   Gerbang : cari nama → daftar "Nama – Kelas" atau "Nama – Kamar" (pilihan akhiran); kata kedua boleh nama kelas/kamar
//             untuk mempersempit (contoh "ahmad 8A", "fauzan umar"). Di bawahnya: siap keluar hari ini dan catatan hari ini.
//   Di luar : santri yang sedang izin di luar; terlambat kembali di atas dan berwarna merah.
// Diperbarui langsung (Realtime). Tautan notifikasi ?santri=<id> membuka lembar santri itu.
import { ref, computed, watch, onMounted, onBeforeUnmount } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { PhMagnifyingGlass, PhCheckCircle, PhSignOut, PhSignIn, PhSiren, PhProhibit, PhCaretRight, PhClockCounterClockwise } from '@phosphor-icons/vue'
import { useSecurity } from '@/stores/security'
import { useUI } from '@/stores/ui'
import { STATUS_GERBANG, JENIS_LOG, durasi, akhiranSantri } from '@/lib/security'
import { formatJam, formatWaktu } from '@/lib/tanggal'
import KartuStatistik from '@/components/KartuStatistik.vue'
import FotoBerkas from '@/components/FotoBerkas.vue'
import LembarGerbang from './LembarGerbang.vue'

const props = defineProps({ mode: { type: String, default: 'gerbang' } })
const sc = useSecurity(); const ui = useUI(); const route = useRoute(); const router = useRouter()
const cari = ref(''); const hasil = ref([]); const mencari = ref(false)
const akhiran = ref((() => { try { return localStorage.getItem('simka.gerbang.akhiran') || 'kelas' } catch { return 'kelas' } })())
watch(akhiran, (v) => { try { localStorage.setItem('simka.gerbang.akhiran', v) } catch { /* abaikan */ } })
const data = ref({ siap: [], di_luar: [], log_hari_ini: [] }); const memuat = ref(false)

async function muat() {
  memuat.value = true
  try { data.value = await sc.daftar() } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
  if (cari.value.trim().length >= 2) cariSantri()
}
let tunda
watch(cari, () => { clearTimeout(tunda); tunda = setTimeout(cariSantri, 300) })
async function cariSantri() {
  const q = cari.value.trim(); if (q.length < 2) { hasil.value = []; return }
  mencari.value = true
  try { hasil.value = await sc.cari(q) } catch (e) { ui.toast(e.message, 'galat') } finally { mencari.value = false }
}
onMounted(async () => { await muat(); sc.dengarkan(muat); bukaDariTautan() })
onBeforeUnmount(() => sc.berhenti())

const lembar = ref(false); const pilih = ref(null)
function buka(s) { pilih.value = s; lembar.value = true }
async function bukaDariTautan() {
  const id = route.query.santri; if (!id) return
  try { const s = await sc.satu(id); if (s) buka(s) } catch (e) { ui.toast(e.message, 'galat') }
  router.replace({ query: {} })
}

const diLuar = computed(() => [...data.value.di_luar].sort((a, b) => (a.status.kode === 'terlambat' ? 0 : 1) - (b.status.kode === 'terlambat' ? 0 : 1) || a.izin.kembali_batas.localeCompare(b.izin.kembali_batas)))
const n = (j) => data.value.log_hari_ini.filter((l) => l.jenis === j).length
const statistik = computed(() => [
  { judul: 'Siap keluar', nilai: data.value.siap.filter((s) => s.status.kode === 'boleh').length, ikon: PhCheckCircle, warna: 'presensi', ket: 'Izin berlaku hari ini' },
  { judul: 'Di luar pondok', nilai: data.value.di_luar.length, ikon: PhSignOut, warna: 'security', ket: 'Belum kembali' },
  { judul: 'Terlambat kembali', nilai: data.value.di_luar.filter((s) => s.status.kode === 'terlambat').length, ikon: PhSiren, warna: 'klinik', ket: 'Lewat batas' },
  { judul: 'Kembali hari ini', nilai: n('kembali'), ikon: PhSignIn, warna: 'rekap', ket: `${n('keluar')} keluar · ${n('ditolak')} ditolak` },
])
const telat = (s) => Math.floor((Date.now() - new Date(s.izin.kembali_batas)) / 60000)
</script>
<template>
  <div>
    <div class="-mx-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-4 sm:overflow-visible sm:px-0">
      <KartuStatistik v-for="k in statistik" :key="k.judul" class="w-[44%] shrink-0 snap-start sm:w-auto" :judul="k.judul" :nilai="memuat && !data.log_hari_ini.length && !data.siap.length ? '…' : k.nilai" :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket" />
    </div>

    <template v-if="mode === 'gerbang'">
      <section class="kartu w-security mt-4 p-4">
        <div class="flex flex-wrap items-center gap-2">
          <div class="relative min-w-[200px] flex-1"><PhMagnifyingGlass :size="22" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
            <input v-model="cari" type="search" class="isian min-h-[52px] pl-12 text-base" placeholder="Ketik nama santri, boleh ditambah kelas/kamar" aria-label="Cari santri di gerbang" autocomplete="off" /></div>
          <div class="flex gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" aria-label="Akhiran nama">
            <button v-for="a in [{ k: 'kelas', n: 'Nama – Kelas' }, { k: 'kamar', n: 'Nama – Kamar' }]" :key="a.k" type="button" role="radio" :aria-checked="akhiran === a.k" @click="akhiran = a.k"
              :class="['min-h-[44px] rounded-xl px-3 text-sm font-semibold', akhiran === a.k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">{{ a.n }}</button>
          </div>
        </div>
        <p class="mt-2 text-xs text-teks3">Contoh: <b>ahmad 8A</b> (nama + kelas) atau <b>fauzan umar</b> (nama + kamar). Hijau berarti boleh keluar; merah tidak boleh keluar.</p>
        <ul v-if="hasil.length" class="mt-3 divide-y divide-garis overflow-hidden rounded-xl border border-garis">
          <li v-for="s in hasil" :key="s.student_id">
            <button type="button" class="baris flex w-full items-center gap-3 px-3 py-2.5 text-left hover:bg-permukaan2" :class="'w-' + (STATUS_GERBANG[s.status.kode]?.w || 'klinik')" @click="buka(s)">
              <span class="chip-ikon h-10 w-10 shrink-0"><component :is="STATUS_GERBANG[s.status.kode]?.ikon" :size="22" weight="fill" /></span>
              <span class="min-w-0 flex-1">
                <span class="block font-bold leading-snug">{{ s.nama }}<span class="whitespace-nowrap font-semibold text-teks2"> – {{ akhiranSantri(s, akhiran) || 'tanpa ' + (akhiran === 'kamar' ? 'kamar' : 'kelas') }}</span></span>
                <span class="block text-xs text-teks3">{{ s.nis }} · {{ akhiran === 'kamar' ? 'Kelas ' + (s.kelas || '–') : s.kamar || 'Kamar –' }}</span>
              </span>
              <span :class="['status-pil shrink-0', 'sp-' + s.status.warna]">{{ STATUS_GERBANG[s.status.kode]?.n }}</span>
              <PhCaretRight :size="18" class="shrink-0 text-teks3" />
            </button>
          </li>
        </ul>
        <p v-else-if="cari.trim().length >= 2 && !mencari" class="mt-3 text-sm text-teks3">Tidak ada santri aktif yang cocok.</p>
      </section>

      <section class="mt-5">
        <h2 class="judul-bagian mb-2">Siap keluar hari ini</h2>
        <ul class="grid gap-2 md:grid-cols-2">
          <li v-for="s in data.siap" :key="s.student_id">
            <button type="button" class="kartu flex w-full items-center gap-3 p-3 text-left" :class="'w-' + (s.status.kode === 'boleh' ? 'presensi' : 'agenda')" @click="buka(s)">
              <span class="chip-ikon h-10 w-10 shrink-0"><PhCheckCircle :size="22" weight="fill" /></span>
              <span class="min-w-0 flex-1"><b class="block leading-snug">{{ s.nama }}{{ akhiranSantri(s, akhiran) ? ' – ' + akhiranSantri(s, akhiran) : '' }}</b>
                <span class="block text-xs text-teks2">{{ s.izin?.alasan }} · penjemput {{ s.izin?.penjemput || '–' }}</span>
                <span class="block text-xs text-teks3">{{ formatWaktu(s.izin?.keluar_pada) }} s.d. {{ formatWaktu(s.izin?.kembali_batas) }} WITA</span></span>
              <span :class="['status-pil shrink-0', 'sp-' + s.status.warna]">{{ s.status.kode === 'boleh' ? 'Boleh keluar' : 'Nanti' }}</span>
            </button>
          </li>
        </ul>
        <p v-if="!data.siap.length && !memuat" class="kartu p-6 text-center text-sm text-teks3">Belum ada izin yang berlaku untuk keluar hari ini.</p>
      </section>

      <section class="mt-5">
        <h2 class="judul-bagian mb-2 flex items-center gap-2"><PhClockCounterClockwise :size="20" weight="duotone" /> Catatan gerbang hari ini</h2>
        <ul class="kartu divide-y divide-garis">
          <li v-for="l in data.log_hari_ini" :key="l.id" class="flex items-center gap-3 p-3" :class="'w-' + JENIS_LOG[l.jenis].w">
            <span class="chip-ikon h-9 w-9 shrink-0"><component :is="JENIS_LOG[l.jenis].ikon" :size="20" weight="duotone" /></span>
            <div class="min-w-0 flex-1">
              <p class="text-sm leading-snug"><b>{{ formatJam(l.waktu) }}</b> · {{ JENIS_LOG[l.jenis].n }} · <b>{{ l.nama }}</b>{{ akhiranSantri(l, akhiran) ? ' – ' + akhiranSantri(l, akhiran) : '' }}</p>
              <p class="truncate text-xs text-teks3">{{ l.penjemput ? 'Penjemput ' + l.penjemput + ' · ' : '' }}{{ l.terlambat_menit ? 'Terlambat ' + durasi(l.terlambat_menit) + ' · ' : '' }}{{ l.catatan ? l.catatan + ' · ' : '' }}Petugas {{ l.petugas || '–' }}</p>
            </div>
            <FotoBerkas v-if="l.foto_id" :id="l.foto_id" alt="Foto gerbang" ukuran="h-12 w-12" />
          </li>
        </ul>
        <p v-if="!data.log_hari_ini.length && !memuat" class="kartu p-6 text-center text-sm text-teks3">Belum ada catatan gerbang hari ini.</p>
      </section>
    </template>

    <template v-else>
      <ul class="mt-4 grid gap-3 md:grid-cols-2">
        <li v-for="s in diLuar" :key="s.student_id">
          <button type="button" class="kartu flex w-full items-start gap-3 p-4 text-left" :class="['w-' + (s.status.kode === 'terlambat' ? 'klinik' : 'security'), s.status.kode === 'terlambat' && 'lewat']" @click="buka(s)">
            <span class="chip-ikon h-11 w-11 shrink-0"><component :is="s.status.kode === 'terlambat' ? PhSiren : PhSignOut" :size="24" weight="duotone" /></span>
            <span class="min-w-0 flex-1">
              <span class="flex flex-wrap items-center gap-1.5"><b class="leading-snug">{{ s.nama }}{{ akhiranSantri(s, akhiran) ? ' – ' + akhiranSantri(s, akhiran) : '' }}</b>
                <span :class="['status-pil', 'sp-' + s.status.warna]">{{ s.status.kode === 'terlambat' ? 'Terlambat ' + durasi(telat(s)) : 'Di luar' }}</span></span>
              <span class="block text-xs text-teks3">{{ s.nis }} · {{ akhiran === 'kamar' ? 'Kelas ' + (s.kelas || '–') : s.kamar || 'Kamar –' }}</span>
              <span class="mt-1 block text-sm font-semibold">{{ s.izin?.alasan }}</span>
              <span class="block text-xs text-teks2">Keluar {{ formatWaktu(s.izin?.keluar_aktual || s.izin?.keluar_pada) }} · batas kembali <b>{{ formatWaktu(s.izin?.kembali_batas) }}</b> WITA</span>
              <span class="block text-xs text-teks3">Penjemput {{ s.izin?.penjemput || '–' }}{{ s.izin?.hp_penjemput ? ' · ' + s.izin.hp_penjemput : '' }}</span>
            </span>
          </button>
        </li>
      </ul>
      <p v-if="!diLuar.length && !memuat" class="kartu mt-4 p-8 text-center text-sm text-teks3">Tidak ada santri yang sedang di luar pondok.</p>
    </template>

    <LembarGerbang v-model="lembar" :santri="pilih" @selesai="muat" />
  </div>
</template>
<style scoped>
.status-pil { display: inline-flex; align-items: center; border-radius: 999px; padding: 2px 8px; font-size: 11px; line-height: 1.5; font-weight: 700; color: #fff; white-space: nowrap; }
.sp-hijau { background: #1E7D4F; } .sp-merah { background: #C7332F; } .sp-biru { background: #2F5FA8; }
.lewat { border-color: var(--c); box-shadow: inset 4px 0 0 var(--c); }
</style>
