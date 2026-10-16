<!-- SIMKA PRO | src/pages/beranda/GrafikPeriodik.vue | v1.0 | Perbaikan 13.7.0: grafik periodik beranda (pengganti slider kartu statistik) | 16/10/2026 -->
<script setup>
// Grafik periodik di beranda pimpinan, admin, dan superadmin (kartu statistik harian kini di Layar Pantauan).
// Periode: 7 hari · 14 hari · 30 hari · 6 bulan. Grafik digeser kanan–kiri dengan usapan jari atau seret tetikus
// (tanpa tombol); penanda titik di bawah hanya menunjukkan posisi. Data dari fungsi SQL grafik_periodik().
import { ref, computed, onMounted, watch, onBeforeUnmount } from 'vue'
import { PhChartLineUp, PhUsersThree, PhStudent, PhBooks, PhFirstAidKit, PhChalkboardTeacher } from '@phosphor-icons/vue'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { BULAN, HARI, hariIniISO } from '@/lib/tanggal'
import GrafikDeret from '@/components/grafik/GrafikDeret.vue'
import IndikatorLangsung from './IndikatorLangsung.vue'

const PERIODE = [{ k: '7h', n: '7 hari' }, { k: '14h', n: '14 hari' }, { k: '30h', n: '30 hari' }, { k: '6b', n: '6 bulan' }]
const simpanan = (() => { try { return localStorage.getItem('simka.beranda.grafik') || '14h' } catch { return '14h' } })()
const periode = ref(PERIODE.some((p) => p.k === simpanan) ? simpanan : '14h')
const data = ref(null); const memuat = ref(false); const galat = ref(''); const diperbarui = ref(null)

/** Data contoh (mode demo): deterministik per tanggal */
function demo(p) {
  const bulanan = p === '6b'; const nHari = { '7h': 7, '14h': 14, '30h': 30, '6b': 6 }[p]
  const h = hariIniISO(); const titik = []
  for (let i = nHari - 1; i >= 0; i--) {
    const d = new Date(`${h}T12:00:00+08:00`)
    if (bulanan) { d.setUTCDate(1); d.setUTCMonth(d.getUTCMonth() - i) } else d.setUTCDate(d.getUTCDate() - i)
    titik.push(d.toISOString().slice(0, 10))
  }
  const acak = (s) => { const x = Math.sin(s) * 10000; return x - Math.floor(x) }
  const k = (t) => Number(t.replace(/-/g, '')) % 997
  const f = bulanan ? 22 : 1
  return {
    bulanan, titik,
    pegawai: titik.map((t) => { const n = 60 * f; const h = Math.round(n * (0.84 + acak(k(t)) * 0.12)); return { t, sesi: n, hadir: h, terlambat: Math.round(h * 0.08), izin: Math.round(n * 0.05), tanpa: Math.max(0, n - h - Math.round(n * 0.05)) } }),
    santri: titik.flatMap((t) => ['kelas', 'halaqah', 'asrama', 'ekskul'].map((j, q) => ({ t, jenis: j, persen: Math.round((88 + acak(k(t) + q) * 10 - (j === 'ekskul' ? 6 : 0)) * 10) / 10 }))),
    hafalan: titik.map((t) => ({ t, setor: Math.round((70 + acak(k(t) + 9) * 30) * f), tambah_hal: Math.round((90 + acak(k(t) + 3) * 60) * f) })),
    klinik: titik.map((t) => ({ t, kasus: Math.round((2 + acak(k(t) + 5) * 5) * f) })),
    izin: titik.map((t) => ({ t, keluar: Math.round((1 + acak(k(t) + 7) * 6) * f) })),
    jurnal: titik.map((t) => ({ t, persen: Math.round((86 + acak(k(t) + 11) * 13) * 10) / 10 })),
  }
}
async function muat() {
  memuat.value = true; galat.value = ''
  try {
    if (MODE_DEMO) data.value = demo(periode.value)
    else { const { data: d, error } = await supabase.rpc('grafik_periodik', { p_periode: periode.value }); if (error) throw error; data.value = d }
    diperbarui.value = new Date()
  } catch (e) { galat.value = e.message || 'Grafik gagal dimuat.'; data.value = null } finally { memuat.value = false }
}
watch(periode, (v) => { try { localStorage.setItem('simka.beranda.grafik', v) } catch { /* abaikan */ } muat() })
let detak = null
onMounted(() => { muat(); detak = setInterval(() => document.visibilityState === 'visible' && muat(), 5 * 60000) })
onBeforeUnmount(() => clearInterval(detak))

// ---------- Susun deret ----------
const titik = computed(() => data.value?.titik || [])
const label = computed(() => titik.value.map((t) => {
  const d = new Date(`${t}T12:00:00+08:00`)
  if (data.value?.bulanan) return BULAN[d.getUTCMonth()].slice(0, 3)
  return titik.value.length <= 7 ? HARI[d.getUTCDay()].slice(0, 3) : `${t.slice(8, 10)}/${t.slice(5, 7)}`
}))
const ambil = (arr, kunci, saring = () => true) => titik.value.map((t) => { const r = (arr || []).find((x) => x.t === t && saring(x)); return r ? r[kunci] ?? null : null })
const persen = (a, b) => (b ? Math.round((a * 1000) / b) / 10 : null)
const rata = (v) => { const x = v.filter((z) => z != null); return x.length ? Math.round((x.reduce((a, b) => a + b, 0) / x.length) * 10) / 10 : null }
const jumlah = (v) => v.reduce((a, b) => a + (Number(b) || 0), 0)
const fmt = (v, s = '') => (v == null ? '–' : `${String(v).replace('.', ',')}${s}`)

const grafik = computed(() => {
  if (!data.value) return []
  const d = data.value
  const pg = titik.value.map((t) => d.pegawai.find((x) => x.t === t))
  const hadirPeg = pg.map((x) => (x ? persen(x.hadir, x.sesi) : null))
  const prog = [['kelas', 'Kelas'], ['halaqah', 'Halaqah'], ['asrama', 'Asrama'], ['ekskul', 'Ekskul']]
  const tambah = ambil(d.hafalan, 'tambah_hal'); const setor = ambil(d.hafalan, 'setor')
  const jurnal = ambil(d.jurnal, 'persen')
  return [
    { k: 'pegawai', judul: 'Kehadiran pegawai', ket: 'Persentase sesi presensi hadir (termasuk terlambat dan dinas luar)', ikon: PhChartLineUp, w: 'presensi',
      angka: fmt(rata(hadirPeg), '%'), angkaKet: 'rata-rata', jenis: 'garis', satuan: '%', maks: 100, seri: [{ n: 'Hadir', nilai: hadirPeg }] },
    { k: 'komposisi', judul: 'Komposisi presensi pegawai', ket: 'Jumlah sesi menurut keadaan', ikon: PhUsersThree, w: 'pegawai',
      angka: fmt(jumlah(pg.map((x) => x?.terlambat))), angkaKet: 'sesi terlambat', jenis: 'tumpuk', satuan: '',
      seri: [{ n: 'Tepat waktu', nilai: pg.map((x) => (x ? x.hadir - x.terlambat : null)) }, { n: 'Terlambat', nilai: pg.map((x) => x?.terlambat ?? null) },
        { n: 'Izin/sakit/cuti', nilai: pg.map((x) => x?.izin ?? null) }, { n: 'Tanpa keterangan', nilai: pg.map((x) => x?.tanpa ?? null) }] },
    { k: 'santri', judul: 'Kehadiran santri per program', ket: 'Persentase hadir dari sesi yang terisi', ikon: PhStudent, w: 'santri',
      angka: fmt(rata(prog.flatMap(([j]) => ambil(d.santri, 'persen', (x) => x.jenis === j))), '%'), angkaKet: 'rata-rata', jenis: 'garis', satuan: '%', maks: 100,
      seri: prog.map(([j, n]) => ({ n, nilai: ambil(d.santri, 'persen', (x) => x.jenis === j) })).filter((s) => s.nilai.some((v) => v != null)) },
    { k: 'hafalan', judul: 'Tambahan hafalan', ket: `Halaman hafalan baru · rata-rata ${fmt(rata(setor))} santri setor ${d.bulanan ? 'per bulan' : 'per hari'}`, ikon: PhBooks, w: 'tahfizh',
      angka: fmt(jumlah(tambah)), angkaKet: 'halaman', jenis: 'batang', satuan: '', seri: [{ n: 'Halaman', nilai: tambah }] },
    { k: 'layanan', judul: 'Layanan santri', ket: 'Kasus klinik baru dan izin keluar santri', ikon: PhFirstAidKit, w: 'klinik',
      angka: fmt(jumlah(ambil(d.klinik, 'kasus'))), angkaKet: 'kasus klinik', jenis: 'batang', satuan: '',
      seri: [{ n: 'Kasus klinik', nilai: ambil(d.klinik, 'kasus').map((v) => v ?? 0) }, { n: 'Izin keluar', nilai: ambil(d.izin, 'keluar').map((v) => v ?? 0) }] },
    { k: 'jurnal', judul: 'Keterlaksanaan pelajaran', ket: 'Jurnal mengajar terisi yang terlaksana', ikon: PhChalkboardTeacher, w: 'gurumapel',
      angka: fmt(rata(jurnal), '%'), angkaKet: 'rata-rata', jenis: 'garis', satuan: '%', maks: 100, seri: [{ n: 'Terlaksana', nilai: jurnal }] },
  ].filter((g) => g.seri.length)
})

// ---------- Geser (usap/seret), tanpa tombol ----------
const rel = ref(null); const aktif = ref(0)
function gulir() {
  const el = rel.value; if (!el) return
  const anak = [...el.children]; const kiri = el.scrollLeft
  let terdekat = 0; let jarak = Infinity
  anak.forEach((c, i) => { const j = Math.abs(c.offsetLeft - el.offsetLeft - kiri); if (j < jarak) { jarak = j; terdekat = i } })
  aktif.value = terdekat
}
// Seret dengan tetikus (desktop); sentuh memakai gulir bawaan peramban
let seret = null
function mulaiSeret(e) { if (e.pointerType !== 'mouse') return; seret = { x: e.clientX, kiri: rel.value.scrollLeft, gerak: false }; rel.value.classList.add('menyeret') }
function geserSeret(e) { if (!seret) return; const dx = e.clientX - seret.x; if (Math.abs(dx) > 4) seret.gerak = true; rel.value.scrollLeft = seret.kiri - dx }
function akhirSeret() {
  if (!seret) return; const el = rel.value; el.classList.remove('menyeret'); seret = null
  // Lekatkan ke kartu terdekat
  gulir(); const c = el.children[aktif.value]; if (c) el.scrollTo({ left: c.offsetLeft - el.offsetLeft, behavior: 'smooth' })
}
</script>
<template>
  <section class="space-y-3" aria-labelledby="judul-grafik-periodik">
    <div class="flex flex-wrap items-center justify-between gap-2">
      <h2 id="judul-grafik-periodik" class="judul-bagian">Grafik periodik</h2>
      <IndikatorLangsung v-if="diperbarui" :waktu="diperbarui" />
    </div>
    <nav class="bilah-tab kecil" role="tablist" aria-label="Periode grafik">
      <button v-for="p in PERIODE" :key="p.k" type="button" role="tab" :aria-selected="periode === p.k" :class="['tab-garis', periode === p.k && 'aktif']" @click="periode = p.k">{{ p.n }}</button>
    </nav>
    <p v-if="galat" class="kartu p-4 text-sm text-teks2" role="alert">Grafik belum dapat dimuat: {{ galat }} Pastikan migrasi SQL 10800 sudah dijalankan.</p>
    <div v-else-if="memuat && !data" class="grid gap-3 md:grid-cols-2"><div v-for="i in 2" :key="i" class="kartu h-72 animate-pulse" /></div>
    <template v-else-if="data">
      <div ref="rel" class="rel-grafik -mx-4 flex snap-x snap-mandatory gap-3 overflow-x-auto px-4 pb-1 lg:mx-0 lg:px-0" @scroll.passive="gulir"
        @pointerdown="mulaiSeret" @pointermove="geserSeret" @pointerup="akhirSeret" @pointerleave="akhirSeret" aria-roledescription="carousel" aria-label="Grafik periodik, geser ke samping">
        <article v-for="g in grafik" :key="g.k + periode" :class="['kartu kartu-grafik shrink-0 snap-start p-4', 'w-' + g.w]" :aria-label="g.judul">
          <header class="mb-2 flex items-start gap-3">
            <span class="chip-ikon h-10 w-10"><component :is="g.ikon" :size="22" weight="duotone" /></span>
            <div class="min-w-0 flex-1"><h3 class="font-bold leading-tight">{{ g.judul }}</h3><p class="text-xs text-teks3">{{ g.ket }}</p></div>
            <div class="text-right"><p class="text-xl font-extrabold leading-tight tabular-nums">{{ g.angka }}</p><p class="text-xs text-teks3">{{ g.angkaKet }}</p></div>
          </header>
          <GrafikDeret :label="label" :seri="g.seri" :jenis="g.jenis" :satuan="g.satuan" :maks="g.maks || 0" :judul="g.judul" />
        </article>
      </div>
      <div class="flex justify-center gap-1.5" aria-hidden="true">
        <span v-for="(g, i) in grafik" :key="g.k" :class="['titik-posisi', i === aktif && 'aktif']" />
      </div>
    </template>
  </section>
</template>
<style scoped>
.rel-grafik { scrollbar-width: none; cursor: grab; }
.rel-grafik::-webkit-scrollbar { display: none; }
.rel-grafik.menyeret { cursor: grabbing; scroll-snap-type: none; user-select: none; }
/* HP: satu grafik per layar (sedikit mengintip berikutnya); desktop: dua grafik berdampingan */
.kartu-grafik { width: 88%; }
@media (min-width: 768px) { .kartu-grafik { width: calc(50% - .375rem); } }
.titik-posisi { width: 6px; height: 6px; border-radius: 9999px; background: rgb(var(--garis)); transition: width .2s, background .2s; }
.titik-posisi.aktif { width: 18px; background: var(--tab-aktif); }
</style>
