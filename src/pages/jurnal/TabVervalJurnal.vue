<!-- SIMKA PRO | src/pages/jurnal/TabVervalJurnal.vue | v1.0 | Fase 3 – Tahap 3 Jurnal harian | 04/10/2026 -->
<script setup>
// Verval kegiatan jurnal yang ditulis sendiri (admin ber-izin verval_jurnal dan superadmin):
// pilih satu atau beberapa, setujui sekaligus, atau kembalikan dengan catatan. Pegawai mendapat notifikasi.
import { ref, computed, onMounted, watch } from 'vue'
import { PhCheckCircle, PhArrowUUpLeft, PhCheckSquare, PhSquare, PhSealCheck } from '@phosphor-icons/vue'
import { useJurnal } from '@/stores/jurnal'
import { useUI } from '@/stores/ui'
import { formatHari, formatWaktu } from '@/lib/tanggal'
import LembarBawah from '@/components/LembarBawah.vue'
import FotoBerkas from '@/components/FotoBerkas.vue'

const jr = useJurnal(); const ui = useUI()
const status = ref('menunggu'); const pilih = ref(new Set()); const kembali = ref(null); const proses = ref(false)
onMounted(() => muat())
watch(status, () => muat())
async function muat() { pilih.value = new Set(); try { await jr.muatAntrian(status.value) } catch (e) { ui.toast(e.message, 'galat') } }
const jam = (v) => String(v || '').slice(0, 5).replace(':', '.')
const semua = computed(() => jr.antrian.length > 0 && pilih.value.size === jr.antrian.length)
function balik(id) { const s = new Set(pilih.value); s.has(id) ? s.delete(id) : s.add(id); pilih.value = s }
function pilihSemua() { pilih.value = semua.value ? new Set() : new Set(jr.antrian.map((a) => a.id)) }

async function setujui(ids) {
  proses.value = true
  try { const n = await jr.verval(ids, true); ui.toast(`${n ?? ids.length} kegiatan disetujui.`, 'info'); pilih.value = new Set() } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
async function kirimKembali() {
  if (kembali.value.catatan.trim().length < 5) return ui.toast('Tuliskan catatan perbaikan (minimal 5 karakter).', 'galat')
  proses.value = true
  try { await jr.verval(kembali.value.ids, false, kembali.value.catatan.trim()); ui.toast('Kegiatan dikembalikan kepada pegawai.', 'info'); kembali.value = null; pilih.value = new Set() }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <div>
    <div class="mb-3 flex flex-wrap items-center gap-2">
      <button v-for="s in [{ k: 'menunggu', n: 'Menunggu verval' }, { k: 'disetujui', n: 'Disetujui (30 hari)' }, { k: 'dikembalikan', n: 'Dikembalikan (30 hari)' }]" :key="s.k" @click="status = s.k"
        :class="['min-h-[40px] rounded-full border px-3.5 text-sm font-semibold', status === s.k ? 'border-transparent bg-[#C7332F] text-white' : 'border-garis bg-permukaan text-teks2']">{{ s.n }}</button>
    </div>
    <div v-if="status === 'menunggu' && jr.antrian.length" class="kartu mb-3 flex flex-wrap items-center gap-2 p-2">
      <button class="tombol-teks" @click="pilihSemua"><component :is="semua ? PhCheckSquare : PhSquare" :size="20" /> {{ semua ? 'Batalkan pilihan' : 'Pilih semua' }}</button>
      <span class="text-sm text-teks3">{{ pilih.size }} dipilih</span>
      <button class="tombol-utama ml-auto min-h-[40px] px-4 text-sm" :disabled="!pilih.size || proses" @click="setujui([...pilih])"><PhCheckCircle :size="18" weight="duotone" /> Setujui</button>
      <button class="tombol-garis min-h-[40px] px-4 text-sm" :disabled="!pilih.size || proses" @click="kembali = { ids: [...pilih], catatan: '' }"><PhArrowUUpLeft :size="18" /> Kembalikan</button>
    </div>

    <p v-if="jr.memuat" class="py-8 text-center text-teks3">Memuat…</p>
    <ul v-else class="space-y-2.5">
      <li v-for="a in jr.antrian" :key="a.id" :class="['kartu w-verval flex gap-3 p-3.5', pilih.has(a.id) && 'dipilih']">
        <button v-if="status === 'menunggu'" class="tombol-ikon -ml-1 shrink-0" :aria-pressed="pilih.has(a.id)" :aria-label="`Pilih kegiatan ${a.nama}`" @click="balik(a.id)">
          <component :is="pilih.has(a.id) ? PhCheckSquare : PhSquare" :size="24" :weight="pilih.has(a.id) ? 'fill' : 'regular'" :style="pilih.has(a.id) ? 'color: var(--c)' : ''" /></button>
        <div class="min-w-0 flex-1">
          <p class="font-bold">{{ a.nama }}</p>
          <p class="text-xs text-teks3">{{ a.unit }} · {{ formatHari(a.tanggal) }} · {{ jam(a.jam_mulai) }}–{{ jam(a.jam_selesai) }}</p>
          <p class="mt-1 text-sm">{{ a.uraian }}</p>
          <p v-if="a.catatan_verval" class="mt-1 text-xs italic text-teks2">Catatan: “{{ a.catatan_verval }}”</p>
          <p v-if="a.diverval_pada" class="text-xs text-teks3">Diverval {{ formatWaktu(a.diverval_pada) }}</p>
          <div v-if="a.foto_id" class="mt-2"><FotoBerkas :id="a.foto_id" alt="Foto kegiatan" ukuran="h-24 w-32" /></div>
          <div v-if="status === 'menunggu'" class="mt-2 flex flex-wrap gap-2">
            <button class="tombol-garis min-h-[40px] px-3 text-sm" :disabled="proses" @click="setujui([a.id])"><PhCheckCircle :size="18" weight="duotone" /> Setujui</button>
            <button class="tombol-garis min-h-[40px] px-3 text-sm" :disabled="proses" @click="kembali = { ids: [a.id], catatan: '' }"><PhArrowUUpLeft :size="18" /> Kembalikan</button>
          </div>
        </div>
      </li>
    </ul>
    <div v-if="!jr.memuat && !jr.antrian.length" class="flex flex-col items-center py-12 text-center">
      <span class="chip-ikon w-verval h-16 w-16 rounded-2xl"><PhSealCheck :size="34" weight="duotone" /></span>
      <p class="mt-3 font-bold">{{ status === 'menunggu' ? 'Tidak ada kegiatan yang menunggu verval' : 'Belum ada data' }}</p>
    </div>

    <LembarBawah :model-value="!!kembali" @update:model-value="(v) => !v && (kembali = null)" judul="Kembalikan kegiatan">
      <form v-if="kembali" class="space-y-3 pb-2" @submit.prevent="kirimKembali">
        <p class="text-sm text-teks2">{{ kembali.ids.length }} kegiatan akan dikembalikan. Pegawai dapat memperbaikinya dalam 7 hari.</p>
        <textarea v-model="kembali.catatan" class="isian min-h-[5rem] py-2" aria-label="Catatan perbaikan" placeholder="Contoh: lengkapi hasil kegiatan dan jumlah peserta." />
        <button class="tombol-utama w-full" :disabled="proses">Kembalikan dengan catatan</button>
      </form>
    </LembarBawah>
  </div>
</template>
<style scoped>.dipilih { box-shadow: inset 0 0 0 2px var(--c); }</style>
