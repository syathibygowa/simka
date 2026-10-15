<!-- SIMKA PRO | src/pages/wali/PengumumanWali.vue | v1.0 | Fase 9 – Tahap 13.3.0 Pengumuman di Portal Wali | 15/10/2026 -->
<script setup>
// Pengumuman pondok untuk wali: pengumuman penting yang belum dibaca di atas; diketuk untuk membuka isi lengkap
// (teks tebal/miring), dan saat dibuka otomatis ditandai dibaca. Kartu ajakan menyalakan notifikasi HP.
import { computed, onMounted, ref, watch } from 'vue'
import { PhMegaphone, PhPushPin, PhLink, PhBellRinging, PhCaretDown } from '@phosphor-icons/vue'
import { usePortalWali } from '@/stores/portalWali'
import { useUI } from '@/stores/ui'
import { teksKaya, teksPolos } from '@/lib/teksKaya'
import { formatRelatif, formatWaktu } from '@/lib/tanggal'
import { statusWali, aktifkanWali, dukungan } from '@/lib/dorongWali'

defineOptions({ inheritAttrs: false })
const pw = usePortalWali(); const ui = useUI()
const d = ref(null); const memuat = ref(false); const galat = ref(''); const buka = ref('')
async function muat() {
  memuat.value = true; galat.value = ''
  try { d.value = await pw.ambil('pengumuman') } catch (e) { galat.value = e.message } finally { memuat.value = false }
}
watch(() => pw.aktif?.nis, muat, { immediate: true })
const daftar = computed(() => d.value?.pengumuman || [])
function ketuk(p) {
  buka.value = buka.value === p.id ? '' : p.id
  if (buka.value) pw.bacaPengumuman(p.id)
}

// Notifikasi HP
const notifAktif = ref(true); const menyalakan = ref(false)
const bisaNotif = !['demo', 'tidak_didukung'].includes(dukungan())
onMounted(async () => { notifAktif.value = !bisaNotif || (await statusWali(pw.aktif?.token)) })
async function nyalakan() {
  menyalakan.value = true
  try { await aktifkanWali(pw.anak.map((a) => a.token)); notifAktif.value = true; ui.toast('Notifikasi HP menyala. Pengumuman baru akan muncul di HP Bapak/Ibu.', 'sukses') }
  catch (e) { ui.toast(e.message, 'galat') } finally { menyalakan.value = false }
}
</script>

<template>
  <div class="w-pengumuman space-y-3">
    <section v-if="!notifAktif" class="kartu w-notifikasi flex flex-wrap items-center gap-3 p-4">
      <span class="chip-ikon h-10 w-10"><PhBellRinging :size="22" weight="duotone" /></span>
      <p class="min-w-0 flex-1 text-sm text-teks2"><b class="text-teks">Nyalakan notifikasi HP</b> agar pengumuman pondok langsung masuk ke HP Bapak/Ibu{{ pw.anak.length > 1 ? ' untuk semua anak di perangkat ini' : '' }}.</p>
      <button type="button" class="tombol-utama" :disabled="menyalakan" @click="nyalakan">{{ menyalakan ? 'Menyalakan…' : 'Nyalakan' }}</button>
    </section>

    <p v-if="galat" class="kartu p-4 text-sm font-semibold text-merah" role="alert">{{ galat }}</p>
    <div v-if="memuat && !d" class="kartu h-32 animate-pulse" aria-busy="true" />
    <p v-if="d?.nonaktif" class="kartu p-6 text-center text-teks3">Informasi ini tidak ditampilkan oleh pondok.</p>
    <div v-else-if="d && !daftar.length" class="kartu p-8 text-center">
      <span class="chip-ikon h-14 w-14 rounded-2xl"><PhMegaphone :size="30" weight="duotone" /></span>
      <p class="mt-3 font-bold">Belum ada pengumuman</p><p class="text-sm text-teks3">Pengumuman pondok untuk wali akan tampil di sini.</p>
    </div>

    <article v-for="p in daftar" :key="p.id" :class="['kartu overflow-hidden', !p.dibaca_pada && 'belum', p.penting && 'penting']">
      <button type="button" class="flex w-full items-start gap-3 p-4 text-left" :aria-expanded="buka === p.id" @click="ketuk(p)">
        <span class="chip-ikon h-10 w-10 shrink-0"><component :is="p.penting ? PhPushPin : PhMegaphone" :size="22" weight="duotone" /></span>
        <span class="min-w-0 flex-1">
          <span class="flex flex-wrap gap-1.5">
            <span v-if="p.penting" class="lencana w-beranda">Penting</span>
            <span v-if="!p.dibaca_pada" class="lencana w-notifikasi">Baru</span>
          </span>
          <span :class="['mt-1 block leading-snug', p.dibaca_pada ? 'font-bold' : 'font-extrabold']">{{ p.judul }}</span>
          <span v-if="buka !== p.id" class="mt-0.5 line-clamp-2 block text-sm text-teks2">{{ teksPolos(p.isi) }}</span>
          <span class="mt-1 block text-xs text-teks3">{{ formatRelatif(p.created_at) }}<template v-if="p.pengirim"> · {{ p.pengirim }}</template></span>
        </span>
        <PhCaretDown :size="18" :class="['mt-1 shrink-0 text-teks3 transition', buka === p.id && 'rotate-180']" />
      </button>
      <div v-if="buka === p.id" class="border-t border-garis/70 px-4 pb-4 pt-3">
        <!-- teksKaya selalu meng-escape isi sebelum menambah <strong>/<em> -->
        <p class="whitespace-pre-line text-[15px] leading-relaxed" v-html="teksKaya(p.isi)" />
        <a v-if="p.tautan" :href="p.tautan" target="_blank" rel="noopener" class="tombol-garis mt-3 text-sm"><PhLink :size="18" /> {{ p.nama_tautan || 'Buka tautan' }}</a>
        <p class="mt-3 text-xs text-teks3">Diterbitkan {{ formatWaktu(p.created_at) }} WITA</p>
      </div>
    </article>
  </div>
</template>
<style scoped>
.kartu.belum { border-color: color-mix(in srgb, #C7332F 35%, transparent); }
.kartu.penting { box-shadow: inset 4px 0 0 #C7332F; }
</style>
