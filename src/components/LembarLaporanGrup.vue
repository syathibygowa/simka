<!-- SIMKA PRO | src/components/LembarLaporanGrup.vue | v1.0 | Perbaikan 13.8.0: lembar kirim laporan ke grup WhatsApp | 16/10/2026 -->
<script setup>
// Lembar laporan untuk grup WhatsApp: pratinjau teks (dapat disunting), pilihan format, lalu
//   • Kirim ke WhatsApp → WhatsApp terbuka dan meminta memilih chat/grup tujuan (mis. grup bidang),
//   • Salin teks → tempel sendiri di grup mana pun,
//   • Buka grup kelompok (bila tautan grup internal pengasuh tersedia; teks otomatis disalin lebih dulu),
//   • Bagikan (HP yang mendukung lembar bagikan bawaan).
// WhatsApp tidak mengizinkan pesan terisi langsung ke tautan undangan grup, sehingga untuk grup dipakai salin-tempel.
import { ref, watch, computed } from 'vue'
import { PhWhatsappLogo, PhCopySimple, PhShareNetwork, PhUsersThree, PhArrowCounterClockwise, PhCheck } from '@phosphor-icons/vue'
import { useUI } from '@/stores/ui'
import LembarBawah from './LembarBawah.vue'

const buka = defineModel({ type: Boolean, default: false })
const format = defineModel('format', { type: String, default: '' })
const props = defineProps({
  judul: { type: String, default: 'Laporan ke grup WhatsApp' },
  teks: { type: String, default: '' },
  pilihanFormat: { type: Array, default: () => [] },   // [{ k, n, ket }]
  tautanGrup: { type: String, default: '' },           // tautan undangan grup (opsional)
  namaGrup: { type: String, default: 'grup kelompok' },
})
const ui = useUI()
const isi = ref(''); const disalin = ref(false)
watch(() => [props.teks, buka.value], () => { if (buka.value) { isi.value = props.teks; disalin.value = false } }, { immediate: true })
const diubah = computed(() => isi.value !== props.teks)
const bisaBagikan = typeof navigator !== 'undefined' && !!navigator.share

async function salin(diam = false) {
  try { await navigator.clipboard.writeText(isi.value); disalin.value = true; if (!diam) ui.toast('Teks laporan disalin. Tempel di grup WhatsApp.'); return true }
  catch { ui.toast('Gagal menyalin otomatis. Tekan lama pada teks lalu pilih Salin.', 'galat'); return false }
}
const kirimWA = () => window.open(`https://wa.me/?text=${encodeURIComponent(isi.value)}`, '_blank', 'noopener')
async function bukaGrup() { await salin(true); ui.toast('Teks laporan disalin. Tempel di grup lalu kirim.'); window.open(props.tautanGrup, '_blank', 'noopener') }
async function bagikan() { try { await navigator.share({ text: isi.value }) } catch { /* dibatalkan */ } }
const baris = computed(() => isi.value.split('\n').length)
</script>
<template>
  <LembarBawah v-model="buka" :judul="judul" lebar>
    <div class="w-presensi space-y-3 pb-2">
      <div v-if="pilihanFormat.length" class="grid gap-1 rounded-2xl bg-permukaan2 p-1" :style="{ gridTemplateColumns: `repeat(${pilihanFormat.length}, minmax(0, 1fr))` }" role="radiogroup" aria-label="Format laporan">
        <button v-for="f in pilihanFormat" :key="f.k" type="button" role="radio" :aria-checked="format === f.k" @click="format = f.k"
          :class="['min-h-[44px] rounded-xl px-2 text-sm font-semibold', format === f.k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">
          {{ f.n }}<span class="hidden text-xs font-normal text-teks3 sm:block">{{ f.ket }}</span></button>
      </div>

      <div>
        <div class="mb-1 flex items-center gap-2">
          <label class="label-isian mb-0 flex-1" for="lap-grup">Pratinjau pesan <span class="font-normal text-teks3">(dapat disunting sebelum dikirim)</span></label>
          <button v-if="diubah" type="button" class="tombol-teks h-8 min-h-0 text-xs" @click="isi = teks"><PhArrowCounterClockwise :size="14" /> Kembalikan</button>
        </div>
        <textarea id="lap-grup" v-model="isi" class="isian pesan font-mono text-[13px] leading-relaxed" :rows="Math.min(18, Math.max(8, baris))" spellcheck="false" />
      </div>

      <div class="grid gap-2 sm:grid-cols-2">
        <button type="button" class="tombol-utama w-full" @click="kirimWA"><PhWhatsappLogo :size="20" weight="duotone" /> Kirim ke WhatsApp</button>
        <button type="button" class="tombol-garis w-full" @click="salin()"><component :is="disalin ? PhCheck : PhCopySimple" :size="20" /> {{ disalin ? 'Sudah disalin' : 'Salin teks' }}</button>
        <button v-if="tautanGrup" type="button" class="tombol-garis w-full sm:col-span-2" @click="bukaGrup"><PhUsersThree :size="20" weight="duotone" style="color: var(--c)" /> Salin lalu buka {{ namaGrup }}</button>
        <button v-if="bisaBagikan" type="button" class="tombol-garis w-full sm:col-span-2" @click="bagikan"><PhShareNetwork :size="20" /> Bagikan lewat aplikasi lain</button>
      </div>
      <p class="text-xs text-teks3">"Kirim ke WhatsApp" membuka WhatsApp lalu meminta Anda memilih grup tujuan, mis. grup bidang. Tanda *bintang* tampil tebal di WhatsApp.</p>
    </div>
  </LembarBawah>
</template>
<style scoped>
.pesan { white-space: pre-wrap; resize: vertical; }
</style>
