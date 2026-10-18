<!-- SIMKA PRO | src/components/PengirimWABeruntun.vue | v1.0 | 14.7.0: pengirim WA berurutan (template, kemajuan 1/n, pratinjau, sebelumnya/lewati, Buka WhatsApp) | 18/10/2026 -->
<script setup>
// Pengirim pesan WhatsApp berurutan untuk banyak penerima (mis. tagihan ke wali santri):
//   • pilih template pesan (berlaku untuk semua penerima; pesan satu penerima dapat disunting sebelum dikirim)
//   • kemajuan "Penerima 2/15" dengan bilah, jumlah terkirim, dilewati, dan tanpa nomor
//   • kartu penerima + pratinjau pesan seperti tampilan WhatsApp (*tebal*, _miring_)
//   • tombol Sebelumnya, Lewati, dan "Buka WhatsApp" (hijau): membuka wa.me dengan pesan terisi, menandai terkirim, lalu maju
//   • daftar penerima untuk melompat; tanda terkirim disimpan selama sesi peramban (kunci)
// Tanpa layanan WA gateway, pesan tetap dikirim dengan menekan Kirim di WhatsApp.
import { ref, computed, watch } from 'vue'
import { PhWhatsappLogo, PhCaretLeft, PhSkipForward, PhCheckCircle, PhPencilSimple, PhEye, PhWarningCircle, PhListBullets, PhArrowCounterClockwise } from '@phosphor-icons/vue'
import { tautanWA } from '@/lib/wa'
import PratinjauWA from './PratinjauWA.vue'

const props = defineProps({
  penerima: { type: Array, default: () => [] },   // [{ id, nama, no_hp, santri?, ket? , ... }]
  templat: { type: Array, required: true },       // [{ k, n, f: (p) => teks }]
  templatAwal: { type: String, default: '' },
  kunci: { type: String, default: 'umum' },
})
const emit = defineEmits(['terkirim'])
const baca = (k) => { try { return JSON.parse(sessionStorage.getItem('simka.waurut.' + props.kunci) || '{}')[k] || [] } catch { return [] } }
const terkirim = ref(new Set(baca('kirim'))); const dilewati = ref(new Set(baca('lewat')))
const simpan = () => { try { sessionStorage.setItem('simka.waurut.' + props.kunci, JSON.stringify({ kirim: [...terkirim.value], lewat: [...dilewati.value] })) } catch { /* abaikan */ } }
const tpl = ref(props.templatAwal || props.templat[0]?.k)
const suntingan = ref({}); const sunting = ref(false); const daftar = ref(false)
const i = ref(0)
function awal() { const j = props.penerima.findIndex((p) => !terkirim.value.has(p.id) && !dilewati.value.has(p.id)); i.value = j >= 0 ? j : 0 }
watch(() => [props.kunci, props.penerima.length], () => { terkirim.value = new Set(baca('kirim')); dilewati.value = new Set(baca('lewat')); suntingan.value = {}; awal() }, { immediate: true })
watch(tpl, () => { suntingan.value = {}; sunting.value = false })

const p = computed(() => props.penerima[i.value])
const teks = computed({
  get: () => (p.value ? suntingan.value[p.value.id] ?? (props.templat.find((t) => t.k === tpl.value)?.f(p.value) || '') : ''),
  set: (v) => { suntingan.value = { ...suntingan.value, [p.value.id]: v } },
})
const n = computed(() => props.penerima.length)
const jumlahKirim = computed(() => props.penerima.filter((x) => terkirim.value.has(x.id)).length)
const jumlahLewat = computed(() => props.penerima.filter((x) => dilewati.value.has(x.id) && !terkirim.value.has(x.id)).length)
const tanpaHP = computed(() => props.penerima.filter((x) => !x.no_hp).length)
const selesai = computed(() => n.value && props.penerima.every((x) => terkirim.value.has(x.id) || dilewati.value.has(x.id)))
const keadaan = (x) => (terkirim.value.has(x.id) ? 'kirim' : dilewati.value.has(x.id) ? 'lewat' : !x.no_hp ? 'kosong' : 'tunggu')

function maju() {
  for (let k = 1; k <= n.value; k++) { const j = (i.value + k) % n.value; const x = props.penerima[j]; if (!terkirim.value.has(x.id) && !dilewati.value.has(x.id)) { i.value = j; sunting.value = false; return } }
  sunting.value = false
}
function kirim() {
  if (!p.value?.no_hp) return
  window.open(tautanWA(p.value.no_hp, teks.value), '_blank', 'noopener')
  terkirim.value = new Set([...terkirim.value, p.value.id]); dilewati.value.delete(p.value.id); simpan(); emit('terkirim', p.value); maju()
}
function lewati() { if (!p.value) return; dilewati.value = new Set([...dilewati.value, p.value.id]); simpan(); maju() }
function sebelumnya() { if (i.value > 0) { i.value--; sunting.value = false } }
function ulang() { terkirim.value = new Set(); dilewati.value = new Set(); simpan(); i.value = 0 }
const inisial = (s) => String(s || '?').replace(/^(Bapak|Ibu|Bpk\.?|Ust\.?|Ustzh\.?)\s+/i, '').split(' ').slice(0, 2).map((x) => x[0]).join('').toUpperCase()
</script>
<template>
  <div class="w-presensi">
    <p v-if="!n" class="rounded-xl bg-permukaan2 p-4 text-sm text-teks3">Tidak ada penerima.</p>
    <template v-else>
      <!-- Template -->
      <div v-if="templat.length > 1" class="mb-3">
        <p class="label-isian">Template pesan</p>
        <div class="flex flex-wrap gap-1.5" role="radiogroup" aria-label="Template pesan">
          <button v-for="t in templat" :key="t.k" type="button" role="radio" :aria-checked="tpl === t.k" @click="tpl = t.k"
            :class="['min-h-[40px] rounded-full border px-3 text-sm font-semibold', tpl === t.k ? 'pilih border-transparent' : 'border-garis text-teks2']">{{ t.n }}</button>
        </div>
      </div>
      <!-- Kemajuan -->
      <div class="rounded-2xl p-3" style="background: color-mix(in srgb, var(--c) 10%, rgb(var(--permukaan)))">
        <div class="flex items-center gap-2 text-sm">
          <p class="flex-1 font-bold">Penerima {{ i + 1 }}/{{ n }}</p>
          <span class="lencana w-presensi"><PhCheckCircle :size="13" weight="fill" /> {{ jumlahKirim }} terkirim</span>
          <span v-if="jumlahLewat" class="lencana w-tahfizh">{{ jumlahLewat }} dilewati</span>
          <span v-if="tanpaHP" class="lencana w-klinik">{{ tanpaHP }} tanpa nomor</span>
        </div>
        <div class="mt-2 h-2 overflow-hidden rounded-full bg-permukaan" role="progressbar" :aria-valuenow="jumlahKirim" :aria-valuemax="n" aria-label="Kemajuan pengiriman">
          <div class="h-full rounded-full transition-all" style="background: #1E7D4F" :style="{ width: (jumlahKirim / n) * 100 + '%' }" /></div>
      </div>

      <p v-if="selesai" class="mt-3 flex items-center gap-2 rounded-xl border border-garis p-3 text-sm font-semibold">
        <PhCheckCircle :size="20" weight="duotone" style="color: var(--c)" /> Semua penerima sudah diproses.
        <button type="button" class="tombol-teks ml-auto min-h-[36px] px-2 text-sm" @click="ulang"><PhArrowCounterClockwise :size="16" /> Ulangi</button></p>

      <!-- Penerima -->
      <div v-if="p" class="mt-3 rounded-2xl border border-garis p-3">
        <div class="flex items-center gap-3">
          <span class="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-[#1E7D4F] text-sm font-bold text-white">{{ inisial(p.nama) }}</span>
          <div class="min-w-0 flex-1"><p class="truncate font-bold">{{ p.nama }}</p>
            <p class="truncate text-xs text-teks3">{{ p.no_hp || 'Nomor HP belum diisi' }}{{ p.ket ? ' · ' + p.ket : '' }}</p></div>
          <span v-if="keadaan(p) === 'kirim'" class="lencana w-presensi shrink-0">Terkirim</span>
          <span v-else-if="keadaan(p) === 'lewat'" class="lencana w-tahfizh shrink-0">Dilewati</span>
        </div>
        <div class="mt-3">
          <div class="mb-1.5 flex items-center gap-2"><p class="flex-1 text-xs font-semibold text-teks3">{{ sunting ? 'Sunting pesan untuk penerima ini' : 'Pratinjau pesan' }}</p>
            <button type="button" class="tombol-teks min-h-[32px] px-2 text-xs" @click="sunting = !sunting"><component :is="sunting ? PhEye : PhPencilSimple" :size="14" /> {{ sunting ? 'Pratinjau' : 'Sunting' }}</button></div>
          <textarea v-if="sunting" v-model="teks" rows="10" class="isian font-mono text-sm" aria-label="Isi pesan" />
          <PratinjauWA v-else :teks="teks" />
        </div>
        <p v-if="!p.no_hp" class="mt-2 flex items-center gap-1.5 text-sm text-merah"><PhWarningCircle :size="16" /> Nomor HP wali belum diisi di Data Santri. Lewati penerima ini.</p>
        <div class="mt-3 grid grid-cols-[auto_auto_1fr] gap-2">
          <button type="button" class="tombol-garis min-h-[48px] px-3" :disabled="i === 0" aria-label="Penerima sebelumnya" @click="sebelumnya"><PhCaretLeft :size="20" /></button>
          <button type="button" class="tombol-garis min-h-[48px] px-3 text-sm" @click="lewati"><PhSkipForward :size="18" /> Lewati</button>
          <button type="button" class="tombol-wa min-h-[48px] justify-center" :disabled="!p.no_hp" @click="kirim"><PhWhatsappLogo :size="22" weight="fill" /> Buka WhatsApp</button>
        </div>
      </div>

      <!-- Daftar penerima -->
      <button type="button" class="tombol-teks mt-2 min-h-[40px] px-1 text-sm" @click="daftar = !daftar"><PhListBullets :size="16" /> {{ daftar ? 'Sembunyikan' : 'Tampilkan' }} daftar penerima</button>
      <ul v-if="daftar" class="mt-1 max-h-72 divide-y divide-garis overflow-y-auto rounded-xl border border-garis">
        <li v-for="(x, j) in penerima" :key="x.id"><button type="button" :class="['flex min-h-[44px] w-full items-center gap-2 px-3 text-left text-sm', j === i && 'bg-permukaan2']" @click="(i = j), (sunting = false)">
          <span class="w-7 text-xs tabular-nums text-teks3">{{ j + 1 }}</span><span class="min-w-0 flex-1 truncate">{{ x.nama }}</span>
          <PhCheckCircle v-if="keadaan(x) === 'kirim'" :size="18" weight="fill" class="text-[#1E7D4F]" />
          <span v-else-if="keadaan(x) === 'lewat'" class="text-xs text-teks3">dilewati</span>
          <PhWarningCircle v-else-if="keadaan(x) === 'kosong'" :size="16" class="text-merah" /></button></li>
      </ul>
      <p class="mt-2 text-xs text-teks3">WhatsApp terbuka dengan pesan terisi; tekan Kirim di WhatsApp lalu kembali ke sini. Isi template diatur di Setelan → Template WA.</p>
    </template>
  </div>
</template>
<style scoped>
.pilih { background: color-mix(in srgb, var(--c) 16%, rgb(var(--permukaan))); box-shadow: inset 0 0 0 2px var(--c); color: rgb(var(--teks)); }
</style>
