<!-- SIMKA PRO | src/pages/wali/BerandaWali.vue | v2.0 | Perbaikan 13.5.0: kartu statistik, grafik kehadiran dan hafalan, tata letak dua kolom desktop | 15/10/2026 -->
<script setup>
// Beranda Portal Wali: sapaan, kartu identitas anak, kartu statistik, grafik 6 bulan (kehadiran dan hafalan),
// kehadiran hari ini, dan pengasuh. Desktop: dua kolom; HP: satu kolom dengan menu ikon.
// Bagian hanya tampil bila butirnya dinyalakan superadmin (server juga tidak mengirim data butir yang mati).
import { computed } from 'vue'
import {
  PhStudent, PhChalkboardTeacher, PhBed, PhBookOpenText, PhTarget, PhCalendarCheck, PhUsersThree, PhCake, PhCalendarBlank, PhCaretRight, PhMegaphone,
  PhChartLineUp, PhBooks, PhMedal,
} from '@phosphor-icons/vue'
import KartuStatistik from '@/components/KartuStatistik.vue'
import GrafikWali from './GrafikWali.vue'
import { usePortalWali } from '@/stores/portalWali'
import { KODE, JENIS_ABSENSI, teksPersen } from '@/lib/absensi'
import { HUBUNGAN_WALI } from '@/lib/portalWali'
import { formatHari, formatPanjang, formatHijriah, salamWaktu, BULAN } from '@/lib/tanggal'
import { inisial } from '@/lib/santri'

defineOptions({ inheritAttrs: false })
defineProps({ menu: { type: Array, default: () => [] } })
const emit = defineEmits(['buka'])
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

// ---------- Grafik dan statistik (data 6 bulan dari server) ----------
const labelBulan = (iso) => BULAN[Number(String(iso).slice(5, 7)) - 1]?.slice(0, 3) || ''
const trenHadir = computed(() => (b.value?.tren_hadir || []).map((x) => ({
  label: labelBulan(x.bulan), nilai: x.sesi ? x.persen : null, ket: x.sesi ? `hadir ${x.hadir} dari ${x.sesi} sesi` : 'belum ada absensi' })))
const trenHafalan = computed(() => (b.value?.tren_hafalan || []).map((x) => ({
  label: labelBulan(x.bulan), nilai: x.tambah_hal || 0, target: x.target_hal || null, ket: `${x.hari_setor} hari setoran` })))
const hafalBulanIni = computed(() => (b.value?.tren_hafalan || []).at(-1) || null)
const totalHal6 = computed(() => (b.value?.tren_hafalan || []).reduce((t, x) => t + (x.tambah_hal || 0), 0))
const juz6 = computed(() => (b.value?.tren_hafalan || []).reduce((t, x) => t + (x.juz_baru || 0), 0))
const rataHadir = computed(() => {
  const ada = (b.value?.tren_hadir || []).filter((x) => x.sesi)
  const sesi = ada.reduce((t, x) => t + x.sesi, 0)
  return sesi ? Math.round((ada.reduce((t, x) => t + x.hadir, 0) * 1000) / sesi) / 10 : null
})
const statistik = computed(() => {
  const hasil = []
  if (pw.butir.kehadiran) hasil.push({ k: 'hadir', judul: 'Kehadiran bulan ini', nilai: b.value?.bulan_ini?.sesi ? teksPersen(b.value.bulan_ini.persen) : '–', ikon: PhCalendarCheck, warna: 'presensi', ke: '/wali/kehadiran',
    keterangan: b.value?.bulan_ini?.sesi ? `Hadir ${b.value.bulan_ini.hadir} dari ${b.value.bulan_ini.sesi} sesi` : 'Belum ada absensi' })
  if (pw.butir.hafalan && hafalBulanIni.value) hasil.push({ k: 'hafal', judul: 'Hafalan bertambah', nilai: hafalBulanIni.value.tambah_hal || 0, satuan: 'hal', ikon: PhBookOpenText, warna: 'tahfizh', ke: '/wali/hafalan',
    keterangan: `Bulan ini · ${hafalBulanIni.value.hari_setor} hari setoran` })
  if (pw.butir.hafalan && hafalBulanIni.value) hasil.push({ k: 'juz', judul: 'Juz tercapai', nilai: juz6.value, satuan: 'juz', ikon: PhMedal, warna: 'prestasi', ke: '/wali/hafalan',
    keterangan: '6 bulan terakhir' })
  if (pw.butir.pengumuman) hasil.push({ k: 'info', judul: 'Pengumuman baru', nilai: b.value?.pengumuman_baru || 0, ikon: PhMegaphone, warna: 'pengumuman', ke: '/wali/pengumuman',
    keterangan: b.value?.pengumuman_baru ? 'Belum dibaca' : 'Semua sudah dibaca' })
  return hasil
})
</script>

<template>
  <div class="space-y-4 lg:space-y-5">
    <p v-if="pw.galat" class="kartu p-4 text-sm font-semibold text-merah" role="alert">{{ pw.galat }}</p>
    <div v-if="!b && pw.memuat" class="space-y-3" aria-busy="true">
      <div class="kartu h-28 animate-pulse" /><div class="grid grid-cols-2 gap-3 lg:grid-cols-4"><div v-for="i in 4" :key="i" class="kartu h-32 animate-pulse" /></div><div class="kartu h-56 animate-pulse" />
    </div>

    <template v-if="b">
      <!-- Sapaan -->
      <section class="flex flex-wrap items-end justify-between gap-x-4 gap-y-1">
        <div>
          <p class="text-sm text-teks2">{{ salamWaktu() }},</p>
          <h1 class="text-xl font-extrabold lg:text-2xl">{{ sapaWali }}</h1>
        </div>
        <p class="text-sm text-teks3">{{ formatHari(b.tanggal) }} · {{ formatHijriah() }}</p>
      </section>

      <!-- Pengumuman baru -->
      <button v-if="b.pengumuman_baru" type="button" class="pengumuman-baru flex w-full items-center gap-3 rounded-2xl p-4 text-left text-white" @click="emit('buka', 'pengumuman')">
        <span class="grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-white/20"><PhMegaphone :size="24" weight="fill" /></span>
        <span class="min-w-0 flex-1"><span class="block font-bold">{{ b.pengumuman_baru }} pengumuman baru dari pondok</span><span class="block text-sm text-white/90">Ketuk untuk membaca</span></span>
        <PhCaretRight :size="22" weight="bold" />
      </button>

      <!-- Identitas anak -->
      <section class="kartu w-santri overflow-hidden">
        <div class="kepala-anak relative flex items-center gap-4 overflow-hidden p-4 sm:p-5">
          <span class="lingkar" aria-hidden="true" />
          <span class="relative grid h-16 w-16 shrink-0 place-items-center rounded-2xl bg-white/95 text-xl font-extrabold text-[#9A2622] shadow-md lg:h-20 lg:w-20 lg:text-2xl">{{ inisial(s.nama) }}</span>
          <div class="relative min-w-0 text-white">
            <p class="text-lg font-extrabold leading-tight lg:text-xl">{{ s.nama }}</p>
            <p class="mt-0.5 text-sm tabular-nums text-white/90">NIS {{ s.nis }} · {{ s.jk === 'P' ? 'Putri' : 'Putra' }}</p>
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

      <!-- Kartu statistik -->
      <section v-if="statistik.length" :class="['grid grid-cols-2 gap-3', { 1: 'lg:grid-cols-1', 2: 'lg:grid-cols-2', 3: 'lg:grid-cols-3' }[statistik.length] || 'lg:grid-cols-4']" aria-label="Ringkasan">
        <KartuStatistik v-for="x in statistik" :key="x.k" :judul="x.judul" :nilai="x.nilai" :satuan="x.satuan" :ikon="x.ikon" :warna="x.warna" :keterangan="x.keterangan" :ke="x.ke" />
      </section>

      <!-- Menu (HP) -->
      <section v-if="menu.length" class="kartu grid grid-cols-4 gap-1 p-2 sm:grid-cols-5 lg:hidden" aria-label="Menu Portal Wali">
        <button v-for="m in menu" :key="m.k" type="button" :class="['flex flex-col items-center gap-1.5 rounded-2xl p-2 text-center hover:bg-permukaan2', 'w-' + m.w]" @click="emit('buka', m.k)">
          <span class="chip-ikon h-12 w-12 rounded-2xl"><component :is="m.ikon" :size="26" weight="duotone" /></span>
          <span class="text-xs font-semibold leading-tight">{{ m.n }}</span>
        </button>
      </section>

      <!-- Grafik -->
      <section v-if="trenHadir.length || trenHafalan.length" class="grid gap-4 lg:grid-cols-2">
        <article v-if="pw.butir.kehadiran && trenHadir.length" class="kartu w-presensi p-4 sm:p-5">
          <header class="mb-2 flex items-start gap-3">
            <span class="chip-ikon h-10 w-10"><PhChartLineUp :size="22" weight="duotone" /></span>
            <div class="min-w-0 flex-1"><h2 class="judul-bagian">Tren kehadiran</h2><p class="text-sm text-teks3">Program pokok, 6 bulan terakhir</p></div>
            <div v-if="rataHadir != null" class="text-right"><p class="text-xl font-extrabold leading-tight tabular-nums">{{ teksPersen(rataHadir) }}</p><p class="text-xs text-teks3">rata-rata</p></div>
          </header>
          <GrafikWali :titik="trenHadir" jenis="garis" satuan="%" :maks="100" judul="Persentase kehadiran per bulan" />
          <button type="button" class="tombol-teks -mb-1 mt-1 min-h-[40px] px-2 text-sm" @click="emit('buka', 'kehadiran')">Lihat rincian kehadiran <PhCaretRight :size="16" weight="bold" /></button>
        </article>
        <article v-if="pw.butir.hafalan && trenHafalan.length" class="kartu w-tahfizh p-4 sm:p-5">
          <header class="mb-2 flex items-start gap-3">
            <span class="chip-ikon h-10 w-10"><PhBooks :size="22" weight="duotone" /></span>
            <div class="min-w-0 flex-1"><h2 class="judul-bagian">Perkembangan hafalan</h2><p class="text-sm text-teks3">Tambahan halaman per bulan</p></div>
            <div class="text-right"><p class="text-xl font-extrabold leading-tight tabular-nums">{{ totalHal6 }} <span class="text-sm font-semibold text-teks2">hal</span></p><p class="text-xs text-teks3">6 bulan</p></div>
          </header>
          <GrafikWali :titik="trenHafalan" jenis="batang" satuan="" judul="Tambahan hafalan (halaman) per bulan" />
          <div class="mt-1 flex flex-wrap items-center justify-between gap-2">
            <p v-if="trenHafalan.some((x) => x.target)" class="flex items-center gap-1.5 text-xs text-teks3"><span class="tanda-target" aria-hidden="true" /> Target bulanan yang sudah disahkan</p>
            <button type="button" class="tombol-teks -mb-1 ml-auto min-h-[40px] px-2 text-sm" @click="emit('buka', 'hafalan')">Lihat rincian hafalan <PhCaretRight :size="16" weight="bold" /></button>
          </div>
        </article>
      </section>

      <div class="grid gap-4 lg:grid-cols-2">
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
          <ul class="mt-3 grid gap-2">
            <li v-for="(p, i) in b.pengasuh" :key="i" class="flex items-center gap-3 rounded-xl bg-permukaan2 p-3">
              <span class="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-permukaan text-sm font-bold text-teks2">{{ inisial(p.nama) }}</span>
              <span class="min-w-0"><span class="block truncate font-semibold">{{ p.nama }}</span>
                <span class="block truncate text-sm text-teks3">{{ p.tugas }} · {{ p.kelompok }}</span></span>
            </li>
          </ul>
        </section>
      </div>

      <p class="px-1 text-center text-xs text-teks3">
        <PhStudent :size="14" weight="duotone" class="inline" /> {{ b.lembaga }} · data {{ HUBUNGAN_WALI[b.wali?.hubungan] ? 'untuk ' + HUBUNGAN_WALI[b.wali.hubungan].toLowerCase() : 'wali' }} santri
      </p>
    </template>
  </div>
</template>
<style scoped>
.kepala-anak { background: linear-gradient(120deg, #0B5E60 0%, #0B7F81 45%, #2F5FA8 100%); }
.lingkar { position: absolute; right: -60px; top: -80px; width: 240px; height: 240px; border-radius: 50%; border: 36px solid rgba(255, 255, 255, .08); }
.tanda-target { display: inline-block; width: 18px; border-top: 2.5px dashed rgb(var(--teks-2)); }
.pengumuman-baru { background: linear-gradient(120deg, #B3261E 0%, #C7332F 45%, #C2410C 100%); }
.lencana.kode { color: rgb(var(--teks)); background: color-mix(in srgb, var(--c) 18%, rgb(var(--permukaan))); }
</style>
