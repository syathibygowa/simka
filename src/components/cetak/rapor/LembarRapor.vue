<!-- SIMKA PRO | src/components/cetak/rapor/LembarRapor.vue | v1.0 | Fase 12 – Tahap 5 Cetak rapor | 13/10/2026 -->
<script setup>
// Pratinjau dan cetak dokumen BERHALAMAN BANYAK (rapor per santri, sampul, leger). Isi berupa beberapa <HalRapor>;
// setiap HalRapor dimulai pada halaman baru dan kepalanya (kop + identitas) berulang di setiap halaman lanjutan.
// Kertas F4 215 × 330 mm (mendatar 330 × 215 mm), margin 2 cm.
import { ref, watch, onBeforeUnmount } from 'vue'
import { PhPrinter, PhX } from '@phosphor-icons/vue'
import { useLembaga } from '@/stores/lembaga'

const lembaga = useLembaga(); lembaga.muat()
const pratinjau = defineModel('pratinjau', { type: Boolean, default: false })
const props = defineProps({ judul: String, keterangan: String, mendatar: Boolean })
const skala = ref(1)
const ukur = () => { skala.value = Math.min(1, (window.innerWidth - 32) / (props.mendatar ? 1247 : 812)) }
const esc = (e) => e.key === 'Escape' && (pratinjau.value = false)
watch(pratinjau, (v) => {
  document.body.style.overflow = v ? 'hidden' : ''
  if (v) { ukur(); addEventListener('resize', ukur); addEventListener('keydown', esc) } else { removeEventListener('resize', ukur); removeEventListener('keydown', esc) }
}, { immediate: true })
onBeforeUnmount(() => { document.body.style.overflow = ''; removeEventListener('resize', ukur); removeEventListener('keydown', esc) })
const cetak = () => window.print()
</script>
<template>
  <Teleport to="body">
    <div v-if="pratinjau" class="cetak-saja tampil munculan" role="dialog" aria-modal="true" :aria-label="'Pratinjau cetak ' + judul">
      <div class="bilah-munculan layar-saja">
        <div class="min-w-0 flex-1">
          <p class="truncate font-bold">Pratinjau cetak: {{ judul }}</p>
          <p class="text-xs opacity-80">{{ keterangan || '' }}{{ keterangan ? ' · ' : '' }}Kertas F4 {{ mendatar ? '330 × 215 mm (mendatar)' : '215 × 330 mm' }}, margin 2 cm</p>
        </div>
        <button type="button" class="tombol-cetak" @click="cetak"><PhPrinter :size="20" weight="duotone" /> Cetak</button>
        <button type="button" class="tombol-tutup" aria-label="Tutup pratinjau" @click="pratinjau = false"><PhX :size="22" /></button>
      </div>
      <div class="gulir-munculan">
        <div :class="['tumpuk-rapor', mendatar && 'mendatar']" :style="{ zoom: skala }"><slot /></div>
      </div>
    </div>
  </Teleport>
</template>
<style>
@media screen {
  .munculan { position: fixed; inset: 0; z-index: 80; display: flex !important; flex-direction: column; background: rgba(20, 12, 14, .82); }
  .bilah-munculan { display: flex; align-items: center; gap: 8px; padding: 10px 14px; padding-top: max(10px, env(safe-area-inset-top)); color: #fff; background: #2B1F22; }
  .bilah-munculan .tombol-cetak { display: inline-flex; align-items: center; gap: 6px; min-height: 44px; padding: 0 18px; border-radius: 999px; background: #C7332F; color: #fff; font-weight: 700; }
  .bilah-munculan .tombol-tutup { display: grid; place-items: center; width: 44px; height: 44px; border-radius: 999px; color: #fff; }
  .gulir-munculan { flex: 1; overflow: auto; padding: 16px; }
  .tumpuk-rapor .hal-rapor { margin: 0 auto 16px; }
  .tumpuk-rapor.mendatar .hal-rapor { width: 330mm; min-height: 215mm; }
}
@media print {
  .munculan { position: static !important; background: none !important; }
  .gulir-munculan { padding: 0 !important; overflow: visible !important; }
  .tumpuk-rapor { zoom: 1 !important; }
  .tumpuk-rapor .hal-rapor { break-after: page; }
  .tumpuk-rapor .hal-rapor:last-child { break-after: auto; }
  .tumpuk-rapor.mendatar .hal-rapor { page: mendatar; }
}
@page mendatar { size: 330mm 215mm; margin: 20mm; }

/* Tata rapor */
.hal-rapor table.tata-rapor { width: 100%; border-collapse: collapse; }
.hal-rapor table.tata-rapor > thead { display: table-header-group; }
.hal-rapor table.tata-rapor > thead > tr > td, .hal-rapor table.tata-rapor > tbody > tr > td { padding: 0; border: 0; }
.hal-rapor .kepala-rapor { margin: 6pt 0 8pt; }
.hal-rapor table.identitas { width: 100%; border-collapse: collapse; font-size: 10pt; }
.hal-rapor table.identitas td { padding: 0.5pt 2pt; vertical-align: top; border: 0; }
.hal-rapor .judul-rapor { margin: 4pt 0 5pt; text-align: center; font-size: 12pt; font-weight: 700; text-transform: uppercase; }
.hal-rapor .sub-rapor { margin: 5pt 0 2pt; font-size: 10.5pt; font-weight: 700; }
.hal-rapor table.tabel { font-size: 9.5pt; }
.hal-rapor table.tabel td.kelompok { font-weight: 700; }
.hal-rapor table.tabel th { background: #E8EEF6; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
.hal-rapor .kotak { border: .5pt solid #000; padding: 4pt 6pt; font-size: 10pt; min-height: 10mm; text-align: justify; }
.hal-rapor .ttd-rapor { margin-top: 8pt; break-inside: avoid; font-size: 10pt; line-height: 1.25; text-align: center; }
.hal-rapor .ttd-rapor .baris { display: grid; grid-template-columns: 1fr 1fr; column-gap: 20mm; }
.hal-rapor .ttd-rapor .ruang { height: 14mm; }
.hal-rapor .ttd { margin-top: 8pt; }
.hal-rapor .ttd .ruang { height: 17mm; }
.hal-rapor.mendatar .ttd { margin-top: 4pt; }
.hal-rapor.mendatar .ttd .ruang { height: 13mm; }
.hal-rapor .ttd-rapor .nama { font-weight: 700; text-decoration: underline; }
/* Kepala di tengah bawah, sedikit naik agar ringkas */
.hal-rapor .ttd-rapor .tengah { width: 50%; margin: -4mm auto 0; }
.hal-rapor table.tabel.padat { font-size: 9pt; }
.hal-rapor table.tabel.padat th, .hal-rapor table.tabel.padat td { padding: 1.2pt 4pt; }
.hal-rapor .sampul { min-height: 285mm; display: flex; flex-direction: column; align-items: center; text-align: center; }
.hal-rapor .rata-kanan { text-align: right; }
</style>
