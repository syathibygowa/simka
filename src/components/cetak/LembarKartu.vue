<!-- SIMKA PRO | src/components/cetak/LembarKartu.vue | v1.0 | Fase 3 – Tahap 4 Berkas Saya dan kartu pegawai | 04/10/2026 -->
<script setup>
// Lembar cetak kartu pegawai di kertas F4 (215 × 330 mm, margin 2 cm): 10 kartu per halaman (2 kolom × 5 baris).
// Mode bolak-balik: halaman sisi belakang dicerminkan per baris agar pas saat dicetak dua sisi (balik tepi panjang).
// Mode berdampingan: depan dan belakang satu pegawai bersebelahan (dilipat atau ditempel).
import { computed, ref, watch, onBeforeUnmount } from 'vue'
import { PhPrinter, PhX } from '@phosphor-icons/vue'
import KartuPegawai from '@/components/KartuPegawai.vue'

const pratinjau = defineModel('pratinjau', { type: Boolean, default: false })
const props = defineProps({
  kartu: { type: Array, default: () => [] }, foto: { type: Object, default: () => ({}) },
  identitas: Object, direktur: Object, mode: { type: String, default: 'berdampingan' }, // 'berdampingan' | 'bolak_balik'
})
const PER = 10
const halaman = computed(() => {
  const k = props.kartu; const out = []
  if (props.mode === 'berdampingan') {
    for (let i = 0; i < k.length; i += 5) out.push({ judul: 'Depan dan belakang', sel: k.slice(i, i + 5).flatMap((d) => [{ d, sisi: 'depan' }, { d, sisi: 'belakang' }]) })
    return out
  }
  for (let i = 0; i < k.length; i += PER) {
    const grup = k.slice(i, i + PER)
    out.push({ judul: `Sisi depan (halaman ${out.length / 2 + 1})`, sel: grup.map((d) => ({ d, sisi: 'depan' })) })
    const belakang = []
    for (let r = 0; r < grup.length; r += 2) { const a = grup[r]; const b = grup[r + 1]; belakang.push(b ? { d: b, sisi: 'belakang' } : null, { d: a, sisi: 'belakang' }) }
    out.push({ judul: `Sisi belakang (halaman ${(out.length - 1) / 2 + 1}) – dicerminkan untuk cetak bolak-balik`, sel: belakang })
  }
  return out
})
const skala = ref(1)
const ukur = () => { skala.value = Math.min(1, (window.innerWidth - 32) / 812) }
const cetak = () => window.print()
const esc = (e) => e.key === 'Escape' && (pratinjau.value = false)
watch(pratinjau, (v) => {
  document.body.style.overflow = v ? 'hidden' : ''
  if (v) { ukur(); addEventListener('resize', ukur); addEventListener('keydown', esc) } else { removeEventListener('resize', ukur); removeEventListener('keydown', esc) }
}, { immediate: true })
onBeforeUnmount(() => { document.body.style.overflow = ''; removeEventListener('resize', ukur); removeEventListener('keydown', esc) })
</script>
<template>
  <Teleport to="body">
    <div :class="['cetak-saja', pratinjau && 'tampil munculan']" :role="pratinjau ? 'dialog' : undefined" :aria-modal="pratinjau || undefined" :aria-label="pratinjau ? 'Pratinjau cetak kartu pegawai' : undefined">
      <div v-if="pratinjau" class="bilah-munculan layar-saja">
        <div class="min-w-0 flex-1"><p class="truncate font-bold">Pratinjau cetak kartu pegawai ({{ kartu.length }})</p>
          <p class="text-xs opacity-80">F4 215 × 330 mm, margin 2 cm · {{ mode === 'bolak_balik' ? '10 kartu per lembar, cetak bolak-balik' : '5 pegawai per lembar, depan dan belakang berdampingan' }}</p></div>
        <button type="button" class="tombol-cetak" @click="cetak"><PhPrinter :size="20" weight="duotone" /> Cetak</button>
        <button type="button" class="tombol-tutup" aria-label="Tutup pratinjau" @click="pratinjau = false"><PhX :size="22" /></button>
      </div>
      <div :class="pratinjau && 'gulir-munculan'">
        <section v-for="(h, i) in halaman" :key="i" class="lembar-f4 halaman-kartu" :style="pratinjau ? { zoom: skala } : null">
          <p class="judul-lembar">Kartu Pegawai · {{ h.judul }} · potong mengikuti garis tepi kartu</p>
          <div class="kisi">
            <div v-for="(s, j) in h.sel" :key="j" class="sel">
              <KartuPegawai v-if="s" :d="s.d" :sisi="s.sisi" :foto="foto[s.d.employee_id]" :identitas="identitas" :direktur="direktur" />
            </div>
          </div>
        </section>
      </div>
    </div>
  </Teleport>
</template>
<style>
.halaman-kartu { background: #fff; color: #000; }
.halaman-kartu .judul-lembar { margin: 0 0 3mm; font: 7.5pt Arial, sans-serif; color: #555; }
.halaman-kartu .kisi { display: grid; grid-template-columns: repeat(2, 85.6mm); grid-auto-rows: 54mm; gap: 2mm 2.5mm; justify-content: center; }
.halaman-kartu .sel { width: 85.6mm; height: 54mm; outline: 0.2mm dashed #bbb; outline-offset: 0.3mm; }
@media screen { .munculan .halaman-kartu { margin: 0 auto 16px; } }
@media print {
  .halaman-kartu { break-after: page; }
  .halaman-kartu:last-child { break-after: auto; }
  .halaman-kartu .kartu-id { box-shadow: none; }
}
</style>
