<script setup>
// Satu notifikasi. Belum dibaca: latar berwarna, judul tebal, titik penanda.
// Diketuk: ditandai dibaca lalu membuka halaman terkait.
import { useRouter } from 'vue-router'
import { PhDotsThreeVertical } from '@phosphor-icons/vue'
import IkonDinamis from './IkonDinamis.vue'
import { useNotifikasi } from '@/stores/notifikasi'
import { formatRelatif, formatWaktu } from '@/lib/tanggal'

const props = defineProps({ n: Object, ringkas: Boolean })
const emit = defineEmits(['dibuka', 'menu'])
const router = useRouter()
const notif = useNotifikasi()
async function buka() {
  await notif.tandai(props.n.id)
  emit('dibuka')
  if (props.n.tautan) router.push(props.n.tautan)
}
</script>
<template>
  <li :class="['item relative flex gap-3 rounded-2xl', 'n-' + (n.warna || 'merah'), !n.dibaca_pada && 'belum', ringkas ? 'p-2.5' : 'p-3.5']">
    <button type="button" class="absolute inset-0 rounded-2xl" @click="buka"
      :aria-label="`${n.dibaca_pada ? '' : 'Belum dibaca. '}${n.judul}. ${n.isi || ''}. Buka halaman terkait`" />
    <span class="chip-ikon h-10 w-10"><IkonDinamis :nama="n.ikon" /></span>
    <div class="min-w-0 flex-1">
      <div class="flex items-start gap-2">
        <p :class="['flex-1 text-sm leading-snug', n.dibaca_pada ? 'font-medium text-teks2' : 'font-bold text-teks']">{{ n.judul }}</p>
        <span v-if="!n.dibaca_pada" class="titik mt-1.5 h-2.5 w-2.5 shrink-0 rounded-full" aria-hidden="true" />
      </div>
      <p v-if="n.isi" :class="['mt-0.5 text-sm leading-snug', n.dibaca_pada ? 'text-teks3' : 'text-teks2', ringkas && 'line-clamp-2']">{{ n.isi }}</p>
      <p class="mt-1 text-xs text-teks3" :title="formatWaktu(n.created_at)">
        {{ formatRelatif(n.created_at) }}<template v-if="!n.dibaca_pada"> – <span class="font-semibold" style="color: var(--c)">Belum dibaca</span></template>
      </p>
    </div>
    <button v-if="!ringkas" type="button" class="tombol-ikon relative z-10 -mr-2 -mt-1.5 shrink-0" @click.stop="emit('menu', n)" aria-label="Pilihan notifikasi">
      <PhDotsThreeVertical :size="22" weight="bold" />
    </button>
  </li>
</template>
<style scoped>
.item { transition: background-color .15s; }
.item:hover { background: rgb(var(--permukaan-2)); }
.item.belum { background: color-mix(in srgb, var(--c) 9%, rgb(var(--permukaan))); }
.item.belum:hover { background: color-mix(in srgb, var(--c) 14%, rgb(var(--permukaan))); }
.titik { background: var(--c); }
</style>
