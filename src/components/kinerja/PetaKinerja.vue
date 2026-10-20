<!-- SIMKA PRO | src/components/kinerja/PetaKinerja.vue | v1.0 | 14.18.0: peta warna capaian indikator kinerja per bidang | 21/10/2026 -->
<script setup>
// Tabel peta warna: baris = bidang (atau pegawai), kolom = enam indikator yang sama + skor.
// Warna sel mengikuti predikat (≥90 sangat baik, ≥80 baik, ≥70 cukup, <70 perlu pembinaan); angka selalu tertulis
// sehingga tetap terbaca tanpa warna. Baris dapat diketuk untuk membuka rincian (emit pilih).
import { INDIKATOR, predikat, persenTeks, skorTeks } from '@/lib/kinerja'
defineProps({ baris: { type: Array, required: true }, judul: String, bisa: Boolean, total: Object })
const emit = defineEmits(['pilih'])
const warna = (p) => predikat(p)?.w || ''
</script>
<template>
  <figure class="peta w-full">
    <figcaption v-if="judul" class="mb-2 text-center font-bold">{{ judul }}</figcaption>
    <div class="overflow-x-auto">
      <table class="w-full min-w-[640px] border-separate border-spacing-1 text-sm">
        <thead><tr class="text-xs text-teks2">
          <th class="px-2 py-1 text-left font-bold">Bidang</th>
          <th v-for="x in INDIKATOR" :key="x.k" class="px-1 py-1 text-center font-bold leading-tight" :title="x.n">{{ x.pendek }}</th>
          <th class="px-1 py-1 text-center font-bold">Skor</th>
        </tr></thead>
        <tbody>
          <tr v-for="b in baris" :key="b.id ?? b.nama" :class="bisa && 'bisa'" :tabindex="bisa ? 0 : undefined" :role="bisa ? 'button' : undefined"
            :aria-label="bisa ? `${b.nama}: skor ${skorTeks(b.skor)}. Lihat rincian` : undefined" @click="bisa && emit('pilih', b)" @keydown.enter="bisa && emit('pilih', b)">
            <td class="max-w-[13rem] truncate px-2 py-1.5 font-semibold" :title="b.nama">{{ b.nama }}</td>
            <td v-for="x in INDIKATOR" :key="x.k" :class="['sel', warna(b.ind[x.k].p)]" :title="`${x.n}: ${b.ind[x.k].n} dari ${b.ind[x.k].d} ${x.satuan}`">{{ b.ind[x.k].p == null ? '–' : persenTeks(b.ind[x.k].p) }}</td>
            <td :class="['sel skor', b.predikat?.w]">{{ skorTeks(b.skor) }}</td>
          </tr>
          <tr v-if="total" class="jumlah">
            <td class="px-2 py-1.5 font-extrabold">{{ total.nama }}</td>
            <td v-for="x in INDIKATOR" :key="x.k" :class="['sel', warna(total.ind[x.k].p)]">{{ total.ind[x.k].p == null ? '–' : persenTeks(total.ind[x.k].p) }}</td>
            <td :class="['sel skor', total.predikat?.w]">{{ skorTeks(total.skor) }}</td>
          </tr>
        </tbody>
      </table>
    </div>
    <p class="mt-2 flex flex-wrap justify-center gap-x-3 gap-y-1 text-xs text-teks2">
      <span class="flex items-center gap-1"><i class="kotak w-presensi" /> ≥ 90 sangat baik</span><span class="flex items-center gap-1"><i class="kotak w-pegawai" /> 80–89 baik</span>
      <span class="flex items-center gap-1"><i class="kotak w-laporan" /> 70–79 cukup</span><span class="flex items-center gap-1"><i class="kotak w-klinik" /> &lt; 70 perlu pembinaan</span>
      <span>– = tidak berlaku</span></p>
  </figure>
</template>
<style scoped>
.sel { border-radius: .5rem; padding: .4rem .25rem; text-align: center; font-weight: 700; font-variant-numeric: tabular-nums; white-space: nowrap;
  color: rgb(var(--teks)); background: color-mix(in srgb, var(--c, rgb(var(--garis))) 20%, rgb(var(--permukaan))); box-shadow: inset 0 0 0 1px color-mix(in srgb, var(--c, rgb(var(--garis))) 35%, transparent); }
.sel.skor { font-weight: 800; background: color-mix(in srgb, var(--c, rgb(var(--garis))) 34%, rgb(var(--permukaan))); }
.jumlah td { border-top: 2px solid rgb(var(--garis)); }
tr.bisa { cursor: pointer; } tr.bisa:hover td:first-child, tr.bisa:focus-visible td:first-child { text-decoration: underline; } tr.bisa { outline: none; }
.kotak { display: inline-block; height: .75rem; width: .75rem; border-radius: .2rem; background: var(--c); }
</style>
