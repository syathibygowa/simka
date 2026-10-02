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
    <div class="flex items-start justify-between gap-3">
      <span class="chip-ikon h-11 w-11"><component :is="ikon" :size="24" weight="duotone" /></span>
      <span v-if="perubahan" :class="['lencana', perubahan === 'naik' ? 'w-presensi' : 'w-klinik']" role="status">
        <component :is="perubahan === 'naik' ? PhArrowUp : PhArrowDown" :size="12" weight="bold" />
        {{ perubahan === 'naik' ? 'Bertambah' : 'Berkurang' }}
      </span>
    </div>
    <p class="mt-4 text-[1.9rem] font-extrabold leading-none tracking-tight text-teks tabular-nums">
      <span :class="perubahan && 'angka-berubah'">{{ tampil }}</span><span v-if="satuan" class="ml-1 text-base font-semibold text-teks2">{{ satuan }}</span>
    </p>
    <p class="mt-1.5 text-sm font-semibold text-teks2">{{ judul }}</p>
    <p v-if="keterangan" class="mt-0.5 text-xs text-teks3">{{ keterangan }}</p>
  </component>
</template>
<style scoped>
.kartu-stat {
  border-color: color-mix(in srgb, var(--c) 22%, rgb(var(--garis)));
  background:
    radial-gradient(120% 90% at 100% 0%, color-mix(in srgb, var(--c2) 20%, transparent) 0%, transparent 62%),
    linear-gradient(160deg, color-mix(in srgb, var(--c) 15%, rgb(var(--permukaan))) 0%, color-mix(in srgb, var(--c) 4%, rgb(var(--permukaan))) 75%);
}
.garis-aksen { position: absolute; left: 0; top: 16px; bottom: 16px; width: 4px; border-radius: 0 4px 4px 0;
  background: linear-gradient(180deg, var(--c), var(--c2)); }
.angka-berubah { animation: kedip 1.2s ease-out; }
@keyframes kedip { 0% { color: var(--c); } 100% { color: inherit; } }
</style>
