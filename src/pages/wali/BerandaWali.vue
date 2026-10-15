<!-- SIMKA PRO | src/pages/wali/BerandaWali.vue | v1.0 | Fase 9 – Tahap 13.0.0 Fondasi Portal Wali | 15/10/2026 -->
<script setup>
// Beranda Portal Wali: sapaan, kartu identitas anak, kegiatan hari ini (kehadiran), dan pengasuh.
// Bagian hanya tampil bila butirnya dinyalakan superadmin (server juga tidak mengirim data butir yang mati).
import { computed } from 'vue'
import {
  PhStudent, PhChalkboardTeacher, PhBed, PhBookOpenText, PhTarget, PhCalendarCheck, PhUsersThree, PhCake, PhCalendarBlank,
} from '@phosphor-icons/vue'
import { usePortalWali } from '@/stores/portalWali'
import { KODE, JENIS_ABSENSI } from '@/lib/absensi'
import { HUBUNGAN_WALI } from '@/lib/portalWali'
import { formatHari, formatPanjang, formatHijriah, salamWaktu } from '@/lib/tanggal'
import { inisial } from '@/lib/santri'

const pw = usePortalWali()
const b = computed(() => pw.beranda)
const s = computed(() => b.value?.santri || {})
const sapaWali = computed(() => {
  const w = b.value?.wali
  if (!w) return 'Bapak/Ibu'
  return w.hubungan === 'ayah' ? `Bapak ${w.nama || ''}`.trim() : w.hubungan === 'ibu' ? `Ibu ${w.nama || ''}`.trim() : (w.nama || 'Bapak/Ibu Wali')
})
const NAMA_JENJANG = { wustha: 'Kesetaraan Wustha', sma: 'SMA' }
const PROGRAM = { reguler: 'Reguler', takhassus: 'Takhassus' }
const kelompok = computed(() => [
  { k: 'kelas', n: 'Kelas', v: s.value.kelas, ikon: PhChalkboardTeacher, w: 'walikelas' },
  { k: 'halaqah', n: 'Halaqah', v: s.value.halaqah, ikon: PhBookOpenText, w: 'tahfizh' },
  { k: 'kamar', n: 'Kamar', v: s.value.kamar, ikon: PhBed, w: 'musyrif' },
  { k: 'ekskul', n: 'Ekskul', v: s.value.ekskul, ikon: PhTarget, w: 'ekskul' },
].filter((x) => x.v))
const hariIni = computed(() => b.value?.hari_ini || [])
const ringkasHari = computed(() => {
  const n = hariIni.value.length
  if (!n) return ''
  const hadir = hariIni.value.filter((x) => ['H', 'T'].includes(x.kode)).length
  return `${hadir} dari ${n} kegiatan hadir`
})
</script>

<template>
  <div class="space-y-4">
    <p v-if="pw.galat" class="kartu p-4 text-sm font-semibold text-merah" role="alert">{{ pw.galat }}</p>
    <div v-if="!b && pw.memuat" class="space-y-3" aria-busy="true">
      <div class="kartu h-28 animate-pulse" /><div class="kartu h-40 animate-pulse" />
    </div>

    <template v-if="b">
      <!-- Sapaan -->
      <section>
        <p class="text-sm text-teks2">{{ salamWaktu() }},</p>
        <h1 class="text-xl font-extrabold">{{ sapaWali }}</h1>
        <p class="mt-0.5 text-sm text-teks3">{{ formatHari(b.tanggal) }} · {{ formatHijriah() }}</p>
      </section>

      <!-- Identitas anak -->
      <section class="kartu w-santri overflow-hidden">
        <div class="kepala-anak flex items-center gap-4 p-4 sm:p-5">
          <span class="grid h-16 w-16 shrink-0 place-items-center rounded-2xl bg-white/95 text-xl font-extrabold text-[#9A2622]">{{ inisial(s.nama) }}</span>
          <div class="min-w-0 text-white">
            <p class="truncate text-lg font-extrabold leading-tight">{{ s.nama }}</p>
            <p class="text-sm tabular-nums text-white/90">NIS {{ s.nis }} · {{ s.jk === 'P' ? 'Putri' : 'Putra' }}</p>
            <p class="text-sm text-white/90">{{ NAMA_JENJANG[s.jenjang] || '' }}<template v-if="s.tingkat"> · Kelas {{ s.tingkat }}</template>
              <template v-if="s.program"> · Program {{ PROGRAM[s.program] || s.program }}</template></p>
          </div>
        </div>
        <div v-if="kelompok.length" class="grid grid-cols-2 gap-px bg-garis/60 sm:grid-cols-4">
          <div v-for="k in kelompok" :key="k.k" :class="['flex items-center gap-2.5 bg-permukaan p-3', 'w-' + k.w]">
            <span class="chip-ikon h-9 w-9 rounded-lg"><component :is="k.ikon" :size="20" weight="duotone" /></span>
            <span class="min-w-0"><span class="block text-xs text-teks3">{{ k.n }}</span><span class="block truncate text-sm font-semibold">{{ k.v }}</span></span>
          </div>
        </div>
        <div v-if="s.tanggal_lahir || s.tahun_masuk" class="flex flex-wrap gap-x-5 gap-y-1 border-t border-garis/70 px-4 py-3 text-sm text-teks2">
          <span v-if="s.tanggal_lahir" class="flex items-center gap-1.5"><PhCake :size="16" weight="duotone" />
            {{ [s.tempat_lahir, formatPanjang(s.tanggal_lahir)].filter(Boolean).join(', ') }}</span>
          <span v-if="s.tahun_masuk" class="flex items-center gap-1.5"><PhCalendarBlank :size="16" weight="duotone" /> Masuk pondok {{ s.tahun_masuk }}</span>
        </div>
      </section>

      <!-- Kegiatan hari ini -->
      <section v-if="pw.butir.kehadiran" class="kartu w-presensi p-4 sm:p-5">
        <div class="flex items-center gap-3">
          <span class="chip-ikon h-10 w-10"><PhCalendarCheck :size="22" weight="duotone" /></span>
          <div class="flex-1"><h2 class="judul-bagian">Kehadiran hari ini</h2>
            <p class="text-sm text-teks3">{{ ringkasHari || 'Belum ada absensi yang diisi pengasuh hari ini.' }}</p></div>
        </div>
        <ul v-if="hariIni.length" class="mt-3 divide-y divide-garis/70">
          <li v-for="(x, i) in hariIni" :key="i" class="flex items-center gap-3 py-2.5">
            <span :class="['w-' + (JENIS_ABSENSI[x.jenis]?.warna || 'beranda'), 'chip-ikon h-9 w-12 rounded-lg text-xs font-bold tabular-nums']">{{ x.jam || '–' }}</span>
            <span class="min-w-0 flex-1"><span class="block truncate font-semibold">{{ x.sesi }}</span>
              <span class="block truncate text-sm text-teks3">{{ JENIS_ABSENSI[x.jenis]?.n || x.jenis }} · {{ x.kelompok }}</span></span>
            <span :class="['lencana', 'w-' + (KODE[x.kode]?.w || 'beranda'), 'kode']">{{ KODE[x.kode]?.n || x.kode }}</span>
          </li>
        </ul>
      </section>

      <!-- Pengasuh -->
      <section v-if="pw.butir.pengasuh && b.pengasuh?.length" class="kartu w-walikelas p-4 sm:p-5">
        <div class="flex items-center gap-3">
          <span class="chip-ikon h-10 w-10"><PhUsersThree :size="22" weight="duotone" /></span>
          <div><h2 class="judul-bagian">Pengasuh ananda</h2><p class="text-sm text-teks3">Hubungi lewat grup WA kelas/kamar atau Tata Usaha pondok.</p></div>
        </div>
        <ul class="mt-3 grid gap-2 sm:grid-cols-2">
          <li v-for="(p, i) in b.pengasuh" :key="i" class="flex items-center gap-3 rounded-xl bg-permukaan2 p-3">
            <span class="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-permukaan text-sm font-bold text-teks2">{{ inisial(p.nama) }}</span>
            <span class="min-w-0"><span class="block truncate font-semibold">{{ p.nama }}</span>
              <span class="block truncate text-sm text-teks3">{{ p.tugas }} · {{ p.kelompok }}</span></span>
          </li>
        </ul>
      </section>

      <p class="px-1 text-center text-xs text-teks3">
        <PhStudent :size="14" weight="duotone" class="inline" /> {{ b.lembaga }} · data {{ HUBUNGAN_WALI[b.wali?.hubungan] ? 'untuk ' + HUBUNGAN_WALI[b.wali.hubungan].toLowerCase() : 'wali' }} santri
      </p>
    </template>
  </div>
</template>
<style scoped>
.kepala-anak { background: var(--gradasi-utama); }
.lencana.kode { color: rgb(var(--teks)); background: color-mix(in srgb, var(--c) 18%, rgb(var(--permukaan))); }
</style>
