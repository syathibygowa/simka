<!-- SIMKA PRO | src/pages/persuratan/FormDisposisi.vue | v1.1 | Perbaikan 13.8.0: catatan disposisi dengan gaya teks dan daftar otomatis | 16/10/2026 -->
<script setup>
// Formulir disposisi (tampil di dalam rincian surat): penerima (boleh lebih dari satu; pimpinan di atas), instruksi (pilihan dari
// Ketentuan), catatan, dan batas waktu (bawaan hari ini + N hari dari Ketentuan; boleh tanpa batas).
// induk diisi bila penerima disposisi meneruskan ke stafnya (disposisi berantai).
import { ref, computed, onMounted } from 'vue'
import { PhMagnifyingGlass, PhX, PhStamp, PhArrowLeft, PhCheck } from '@phosphor-icons/vue'
import { usePersuratan } from '@/stores/persuratan'
import { useUI } from '@/stores/ui'
import { hariIniISO } from '@/lib/tanggal'
import { tambahHari } from '@/lib/persuratan'
import InputTanggal from '@/components/InputTanggal.vue'
import IsianTeksKaya from '@/components/IsianTeksKaya.vue'

const props = defineProps({ surat: { type: Object, required: true }, induk: { type: Object, default: null } })
const emit = defineEmits(['batal', 'selesai'])
const ps = usePersuratan(); const ui = useUI()
const kepada = ref([]); const instruksi = ref([]); const catatan = ref(''); const cari = ref(''); const proses = ref(false)
const pakaiBatas = ref(true); const batas = ref(tambahHari(hariIniISO(), ps.pengaturan.batas_bawaan_hari ?? 3))
onMounted(() => ps.muatPegawai().catch((e) => ui.toast(e.message, 'galat')))
const sudah = computed(() => new Set((props.surat.disposisi || []).filter((d) => d.saya_pemberi).map((d) => d.kepada_id)))
const hasil = computed(() => {
  const q = cari.value.toLowerCase().trim()
  return ps.pegawai.filter((p) => !kepada.value.some((k) => k.id === p.id) && !sudah.value.has(p.id)
    && (!q ? p.pimpinan : `${p.nama} ${p.jabatan || ''} ${p.unit || ''} ${p.niy || ''}`.toLowerCase().includes(q))).slice(0, q ? 30 : 12)
})
const tambah = (p) => { kepada.value.push(p); cari.value = '' }
const alih = (t) => { instruksi.value = instruksi.value.includes(t) ? instruksi.value.filter((x) => x !== t) : [...instruksi.value, t] }

async function kirim() {
  if (!kepada.value.length) return ui.toast('Pilih minimal satu penerima disposisi.', 'galat')
  if (!instruksi.value.length && catatan.value.trim().length < 3) return ui.toast('Pilih instruksi atau tuliskan catatan disposisi.', 'galat')
  if (pakaiBatas.value && batas.value < hariIniISO()) return ui.toast('Batas waktu tidak boleh sebelum hari ini.', 'galat')
  proses.value = true
  try {
    const urut = ps.pengaturan.instruksi || []
    const n = await ps.disposisi({ surat_id: props.surat.id, induk_id: props.induk?.id || null, kepada: kepada.value.map((k) => k.id),
      instruksi: [...instruksi.value].sort((a, b) => urut.indexOf(a) - urut.indexOf(b)), catatan: catatan.value.trim(), batas: pakaiBatas.value ? batas.value : null })
    ui.toast(`Disposisi terkirim kepada ${n} orang. Penerima mendapat notifikasi.`); emit('selesai')
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <div class="space-y-4">
    <button type="button" class="tombol-teks -ml-3 px-3" @click="emit('batal')"><PhArrowLeft :size="18" /> Kembali ke rincian</button>
    <p class="rounded-xl bg-permukaan2 px-3 py-2 text-sm"><b>{{ induk ? 'Teruskan disposisi' : 'Disposisi' }}:</b> {{ surat.perihal }}
      <span v-if="induk" class="block text-xs text-teks2">Dari {{ induk.dari }}: {{ [...(induk.instruksi || []), induk.catatan].filter(Boolean).join(' · ') }}</span></p>

    <div><p class="label-isian">Kepada <span class="text-merah">*</span></p>
      <div v-if="kepada.length" class="mb-2 flex flex-wrap gap-1.5">
        <span v-for="k in kepada" :key="k.id" class="lencana w-shift py-1 text-sm">{{ k.nama }}
          <button type="button" class="ml-1" :aria-label="`Hapus ${k.nama}`" @click="kepada = kepada.filter((x) => x.id !== k.id)"><PhX :size="13" /></button></span>
      </div>
      <div class="relative"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
        <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari nama, jabatan, atau bidang" aria-label="Cari penerima disposisi" /></div>
      <p v-if="!cari" class="mt-1 text-xs text-teks3">Pimpinan ditampilkan lebih dulu. Ketik untuk mencari pegawai lain.</p>
      <ul v-if="hasil.length" class="mt-1 max-h-56 divide-y divide-garis overflow-y-auto rounded-xl border border-garis">
        <li v-for="p in hasil" :key="p.id"><button type="button" class="flex min-h-[48px] w-full items-center gap-2 px-3 text-left text-sm hover:bg-permukaan2" @click="tambah(p)">
          <span class="min-w-0 flex-1"><b class="block truncate">{{ p.nama }}</b><span class="block truncate text-xs text-teks3">{{ p.jabatan }}{{ p.unit ? ' · ' + p.unit : '' }}</span></span>
          <span v-if="p.pimpinan" class="lencana w-tatausaha">Pimpinan</span></button></li>
      </ul></div>

    <div><p class="label-isian">Instruksi</p>
      <div class="flex flex-wrap gap-2">
        <button v-for="t in ps.pengaturan.instruksi" :key="t" type="button" :aria-pressed="instruksi.includes(t)" @click="alih(t)"
          :class="['inline-flex min-h-[40px] items-center gap-1.5 rounded-xl border px-3 text-sm font-semibold w-shift', instruksi.includes(t) ? 'pilih' : 'border-garis text-teks2']">
          <PhCheck v-if="instruksi.includes(t)" :size="16" weight="bold" style="color: var(--c)" />{{ t }}</button>
      </div></div>
    <IsianTeksKaya id="dp-cat" v-model="catatan" label="Catatan disposisi" tinggi="5rem" :petunjuk="false" placeholder="Arahan tambahan untuk penerima" />
    <div class="grid items-end gap-3 sm:grid-cols-2">
      <InputTanggal v-if="pakaiBatas" v-model="batas" label="Batas waktu" />
      <label class="flex min-h-[46px] items-center gap-2 text-sm"><input v-model="pakaiBatas" type="checkbox" class="h-5 w-5" /> Pakai batas waktu</label>
    </div>
    <button class="tombol-utama w-full" :disabled="proses" @click="kirim"><PhStamp :size="20" weight="duotone" /> {{ proses ? 'Mengirim…' : 'Kirim disposisi' }}</button>
  </div>
</template>
<style scoped>
.pilih { border-color: var(--c); border-width: 2px; background: color-mix(in srgb, var(--c) 12%, transparent); color: rgb(var(--teks)); }
</style>
