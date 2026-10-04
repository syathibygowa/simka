<!-- SIMKA PRO | src/components/cetak/LembarKartu.vue | v2.0 | Fase 3 – Perbaikan P4 (kartu pegawai portrait) | 04/10/2026 -->
<script setup>
// Lembar cetak kartu pegawai TEGAK (54 × 85,6 mm) di kertas F4 (215 × 330 mm, margin 2 cm).
// Mode bolak-balik: 9 kartu per halaman (3 kolom × 3 baris); halaman belakang dicerminkan per baris (balik tepi panjang).
// Mode berdampingan: depan dan belakang satu pegawai bersebelahan, 3 pegawai per halaman (dilipat atau ditempel).
import { computed, ref, watch, onBeforeUnmount } from 'vue'
import { PhPrinter, PhX } from '@phosphor-icons/vue'
import KartuPegawai from '@/components/KartuPegawai.vue'

const pratinjau = defineModel('pratinjau', { type: Boolean, default: false })
const props = defineProps({
  kartu: { type: Array, default: () => [] }, foto: { type: Object, default: () => ({}) },
  identitas: Object, direktur: Object, mode: { type: String, default: 'berdampingan' }, // 'berdampingan' | 'bolak_balik'
})
const PER = 9; const KOLOM = 3
const halaman = computed(() => {
  const k = props.kartu; const out = []
  if (props.mode === 'berdampingan') {
    for (let i = 0; i < k.length; i += 3) out.push({ judul: 'Depan dan belakang', dua: true, sel: k.slice(i, i + 3).flatMap((d) => [{ d, sisi: 'depan' }, { d, sisi: 'belakang' }]) })
    return out
  }
  for (let i = 0; i < k.length; i += PER) {
    const grup = k.slice(i, i + PER)
    out.push({ judul: `Sisi depan (halaman ${out.length / 2 + 1})`, sel: grup.map((d) => ({ d, sisi: 'depan' })) })
    const belakang = []
    for (let r = 0; r < grup.length; r += KOLOM) { const baris = grup.slice(r, r + KOLOM); while (baris.length < KOLOM) baris.push(null); baris.reverse().forEach((d) => belakang.push(d ? { d, sisi: 'belakang' } : null)) }
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
          <p class="text-xs opacity-80">F4 215 × 330 mm, margin 2 cm · {{ mode === 'bolak_balik' ? '9 kartu per lembar, cetak bolak-balik' : '3 pegawai per lembar, depan dan belakang berdampingan' }}</p></div>
        <button type="button" class="tombol-cetak" @click="cetak"><PhPrinter :size="20" weight="duotone" /> Cetak</button>
        <button type="button" class="tombol-tutup" aria-label="Tutup pratinjau" @click="pratinjau = false"><PhX :size="22" /></button>
      </div>
      <div :class="pratinjau && 'gulir-munculan'">
        <section v-for="(h, i) in halaman" :key="i" class="lembar-f4 halaman-kartu" :style="pratinjau ? { zoom: skala } : null">
          <p class="judul-lembar">Kartu Pegawai · {{ h.judul }} · potong mengikuti garis tepi kartu</p>
          <div :class="['kisi', h.dua && 'dua']">
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
.halaman-kartu .kisi { display: grid; grid-template-columns: repeat(3, 54mm); grid-auto-rows: 85.6mm; gap: 3mm 4mm; justify-content: center; }
.halaman-kartu .kisi.dua { grid-template-columns: repeat(2, 54mm); gap: 3mm 0.6mm; }
.halaman-kartu .sel { width: 54mm; height: 85.6mm; outline: 0.2mm dashed #bbb; outline-offset: 0.3mm; }
@media screen { .munculan .halaman-kartu { margin: 0 auto 16px; } }
@media print {
  .halaman-kartu { break-after: page; }
  .halaman-kartu:last-child { break-after: auto; }
  .halaman-kartu .kartu-p { box-shadow: none; }
}
</style>
