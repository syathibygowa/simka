<script setup>
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { PhChecks, PhEnvelopeOpen, PhEnvelopeSimple, PhTrash, PhArrowSquareOut, PhBellSlash } from '@phosphor-icons/vue'
import { useNotifikasi } from '@/stores/notifikasi'
import ItemNotifikasi from '@/components/ItemNotifikasi.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import { formatPanjang, formatPendek, sekarang } from '@/lib/tanggal'

const notif = useNotifikasi(); const router = useRouter()
const tab = ref('semua')
const pilihan = ref(null)
const tampil = computed(() => (tab.value === 'belum' ? notif.daftar.filter((n) => !n.dibaca_pada) : notif.daftar))
// Kelompokkan per tanggal: Hari ini, Kemarin, lalu tanggal panjang
const kelompok = computed(() => {
  const hariIni = formatPendek(sekarang()); const kemarin = formatPendek(new Date(sekarang() - 86400000))
  const g = []
  for (const n of tampil.value) {
    const t = formatPendek(n.created_at)
    const label = t === hariIni ? 'Hari ini' : t === kemarin ? 'Kemarin' : formatPanjang(n.created_at)
    if (!g.length || g[g.length - 1].label !== label) g.push({ label, item: [] })
    g[g.length - 1].item.push(n)
  }
  return g
})
async function buka(n) { pilihan.value = null; await notif.tandai(n.id); if (n.tautan) router.push(n.tautan) }
</script>
<template>
  <div class="mx-auto max-w-3xl">
    <div class="mb-4 flex flex-wrap items-center gap-2">
      <div class="flex rounded-full bg-permukaan2 p-1" role="tablist" aria-label="Saring notifikasi">
        <button v-for="t in [{ k: 'semua', n: 'Semua' }, { k: 'belum', n: 'Belum dibaca' }]" :key="t.k" role="tab" :aria-selected="tab === t.k"
          :class="['min-h-[40px] rounded-full px-4 text-sm font-semibold transition', tab === t.k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']" @click="tab = t.k">
          {{ t.n }}<span v-if="t.k === 'belum' && notif.belumDibaca" class="ml-1.5 rounded-full bg-[#C7332F] px-1.5 text-xs text-white">{{ notif.belumDibaca }}</span>
        </button>
      </div>
      <button v-if="notif.belumDibaca" class="tombol-teks ml-auto text-sm" @click="notif.tandaiSemua()"><PhChecks :size="18" weight="bold" /> Tandai semua dibaca</button>
    </div>

    <div v-for="g in kelompok" :key="g.label" class="mb-5">
      <h2 class="mb-2 px-1 text-sm font-bold text-teks3">{{ g.label }}</h2>
      <ul class="kartu space-y-1 p-2">
        <ItemNotifikasi v-for="n in g.item" :key="n.id" :n="n" @menu="pilihan = $event" />
      </ul>
    </div>
    <div v-if="!tampil.length" class="w-notifikasi flex flex-col items-center py-16 text-center">
      <span class="chip-ikon h-16 w-16 rounded-2xl"><PhBellSlash :size="34" weight="duotone" /></span>
      <p class="mt-3 font-bold">{{ tab === 'belum' ? 'Semua notifikasi sudah dibaca' : 'Belum ada notifikasi' }}</p>
      <p class="mt-1 text-sm text-teks3">Pemberitahuan baru akan muncul di sini secara langsung.</p>
    </div>

    <LembarBawah :model-value="!!pilihan" @update:model-value="(v) => !v && (pilihan = null)" :judul="pilihan?.judul">
      <ul v-if="pilihan" class="space-y-1 pb-2">
        <li v-if="pilihan.tautan"><button class="w-pegawai flex min-h-[52px] w-full items-center gap-3 rounded-xl px-2 font-semibold hover:bg-permukaan2" @click="buka(pilihan)">
          <PhArrowSquareOut :size="22" weight="duotone" style="color: var(--c)" /> Buka halaman terkait</button></li>
        <li><button class="w-presensi flex min-h-[52px] w-full items-center gap-3 rounded-xl px-2 font-semibold hover:bg-permukaan2"
          @click="pilihan.dibaca_pada ? notif.tandaiBelum(pilihan.id) : notif.tandai(pilihan.id); pilihan = null">
          <component :is="pilihan.dibaca_pada ? PhEnvelopeSimple : PhEnvelopeOpen" :size="22" weight="duotone" style="color: var(--c)" />
          {{ pilihan.dibaca_pada ? 'Tandai belum dibaca' : 'Tandai sudah dibaca' }}</button></li>
        <li><button class="w-beranda flex min-h-[52px] w-full items-center gap-3 rounded-xl px-2 font-semibold hover:bg-permukaan2" @click="notif.hapus(pilihan.id); pilihan = null">
          <PhTrash :size="22" weight="duotone" style="color: var(--c)" /> Hapus notifikasi</button></li>
      </ul>
    </LembarBawah>
  </div>
</template>
