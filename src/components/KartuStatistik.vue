<!-- SIMKA PRO | src/components/KartuStatistik.vue | v1.1 | Fase 3 – Perbaikan P1 (kartu, kelompok, pengumuman) | 04/10/2026 -->
<script setup>
// Kartu statistik langsung. Setiap kartu memakai pasangan warna sendiri (kelas .w-*):
// latar gradasi tipis dua warna, chip ikon berwarna, angka besar berwarna teks utama
// agar kontras tetap tinggi di tema terang maupun gelap.
import { computed } from 'vue'
import { PhArrowUp, PhArrowDown } from '@phosphor-icons/vue'
const props = defineProps({
  judul: String, nilai: [Number, String], ikon: Object, warna: { type: String, default: 'beranda' },
  keterangan: String, perubahan: String, ke: String, satuan: String,
})
const tampil = computed(() => (typeof props.nilai === 'number' ? props.nilai.toLocaleString('id-ID') : props.nilai ?? '–'))
</script>
<template>
  <component :is="ke ? 'router-link' : 'div'" :to="ke"
    :class="['kartu-stat group relative block overflow-hidden rounded-kartu border p-4 sm:p-5 transition', 'w-' + warna, ke && 'hover:-translate-y-0.5 hover:shadow-apung']">
    <span class="garis-aksen" aria-hidden="true" />
    <component :is="ikon" class="ikon-latar" :size="96" weight="duotone" aria-hidden="true" />
    <div class="flex items-start justify-between gap-3">
      <span class="chip-padat grid h-11 w-11 place-items-center rounded-xl"><component :is="ikon" :size="24" weight="fill" /></span>
      <span v-if="perubahan" :class="['lencana', perubahan === 'naik' ? 'w-presensi' : 'w-klinik']" role="status">
        <component :is="perubahan === 'naik' ? PhArrowUp : PhArrowDown" :size="12" weight="bold" />
        {{ perubahan === 'naik' ? 'Bertambah' : 'Berkurang' }}
      </span>
    </div>
    <p class="angka relative mt-4 text-[1.9rem] font-extrabold leading-none tracking-tight tabular-nums">
      <span :class="perubahan && 'angka-berubah'">{{ tampil }}</span><span v-if="satuan" class="ml-1 text-base font-semibold text-teks2">{{ satuan }}</span>
    </p>
    <p class="relative mt-1.5 text-sm font-bold text-teks">{{ judul }}</p>
    <p v-if="keterangan" class="relative mt-0.5 text-xs font-medium text-teks2">{{ keterangan }}</p>
  </component>
</template>
<style scoped>
/* v1.1: warna lebih mencolok — latar gradasi lebih pekat, chip ikon padat, angka berwarna, ikon besar samar di sudut.
   Angka memakai --c (sudah memenuhi kontras AA terhadap permukaan di kedua tema). */
.kartu-stat {
  border-color: color-mix(in srgb, var(--c) 45%, rgb(var(--garis)));
  background:
    radial-gradient(120% 95% at 100% 0%, color-mix(in srgb, var(--c2) 34%, transparent) 0%, transparent 60%),
    linear-gradient(155deg, color-mix(in srgb, var(--c) 28%, rgb(var(--permukaan))) 0%, color-mix(in srgb, var(--c) 9%, rgb(var(--permukaan))) 78%);
  box-shadow: 0 6px 18px -10px color-mix(in srgb, var(--c) 55%, transparent);
}
.chip-padat { background: linear-gradient(135deg, var(--c), color-mix(in srgb, var(--c2) 70%, var(--c))); color: #fff; box-shadow: 0 4px 10px -4px var(--c); }
:global(.dark) .chip-padat { color: #1a1214; }
.angka { color: var(--c); }
.ikon-latar { position: absolute; right: -14px; bottom: -18px; color: var(--c); opacity: .13; pointer-events: none; }
.garis-aksen { position: absolute; left: 0; top: 14px; bottom: 14px; width: 5px; border-radius: 0 5px 5px 0;
  background: linear-gradient(180deg, var(--c), var(--c2)); }
.angka-berubah { animation: kedip 1.2s ease-out; }
@keyframes kedip { 0% { opacity: .35; } 100% { opacity: 1; } }
</style>
