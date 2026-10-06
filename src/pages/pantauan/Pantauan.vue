<!-- SIMKA PRO | src/pages/pantauan/Pantauan.vue | v2.0 | Fase 7 – Perbaikan uji coba: Layar Pantauan berbentuk slide | 06/10/2026 -->
<script setup>
// Layar Pantauan (Blueprint Bagian 28) berbentuk SLIDE layar penuh untuk presentasi dan SmartTV.
//   Dibuka dari tombol "Layar Pantauan" di Beranda (bukan menu). Slide: Santri, Pegawai, Sekolah SMP, Sekolah SMA, Tahfizh,
//   Hafalan Santri, Asrama dan Musyrif, Kegiatan dan Pengampu, Medis dan Klinik, Security, Ekskul.
//   Isi: kartu statistik berwarna + grafik. Diperbarui langsung (Realtime + tiap 60 detik); jam berjalan dan jam pembaruan.
//   Pindah slide: geser samping atau atas-bawah, roda tetikus, tombol panah/penunjuk, papan ketik (← → ↑ ↓ Spasi), putar otomatis.
//   Saringan: putra/putri, SMP/SMA, bidang (pegawai). Admin/superadmin: ketuk kartu → daftar nama → cetak F4/Excel.
import { ref, computed, onMounted, onBeforeUnmount, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import * as XLSX from 'xlsx'
import { PhFunnel, PhArrowLeft, PhCaretLeft, PhCaretRight, PhPlay, PhPause, PhArrowsOut, PhArrowsIn, PhArrowClockwise, PhEye, PhDownloadSimple, PhLock } from '@phosphor-icons/vue'
import { usePantauan } from '@/stores/pantauan'
import { useSesi } from '@/stores/sesi'
import { susunSlide } from '@/lib/slidePantauan'
import { JENJANG_PENDEK, penandaKelompok } from '@/lib/santri'
import { formatJam, formatPanjang } from '@/lib/tanggal'
import LogoSimka from '@/components/LogoSimka.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import GrafikBatang from '@/components/grafik/GrafikBatang.vue'
import GrafikLingkaran from '@/components/grafik/GrafikLingkaran.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const pt = usePantauan(); const sesi = useSesi(); const router = useRouter(); const route = useRoute()
const admin = computed(() => ['admin', 'superadmin'].includes(sesi.peran))

// ---------- Saringan (tersimpan di perangkat) ----------
const simpanan = (() => { try { return JSON.parse(localStorage.getItem('simka.layar.saring') || '{}') } catch { return {} } })()
const f = ref({ jk: simpanan.jk || '', jenjang: simpanan.jenjang || '', bidang: simpanan.bidang || '' })
watch(f, (v) => { try { localStorage.setItem('simka.layar.saring', JSON.stringify(v)) } catch { /* abaikan */ } }, { deep: true })
const slide = computed(() => (pt.data ? susunSlide(pt.data, f.value) : []))
const saringanTeks = computed(() => [f.value.jk === 'L' ? 'putra' : f.value.jk === 'P' ? 'putri' : '', f.value.jenjang ? JENJANG_PENDEK[f.value.jenjang] : '',
  f.value.bidang ? pt.data?.bidang.find((b) => b.id === f.value.bidang)?.nama : ''].filter(Boolean).join(', '))

// ---------- Slide aktif ----------
const idx = ref(0); let sudahAwal = false
const aktif = computed(() => slide.value[idx.value])
watch(slide, (s) => { if (!sudahAwal && s.length) { sudahAwal = true; const i = s.findIndex((x) => x.k === route.query.slide); if (i >= 0) idx.value = i } }, { immediate: true })
function ke(i, manual = true) {
  const n = slide.value.length; if (!n) return
  idx.value = (i + n) % n
  router.replace({ query: { ...route.query, slide: slide.value[idx.value].k } })
  if (manual) jedaOtomatis()
}
const lanjut = (m = true) => ke(idx.value + 1, m)
const mundur = () => ke(idx.value - 1)

// ---------- Putar otomatis ----------
const putar = ref(false); const detik = ref(20); let pewaktu = null; let jeda = null
function aturPutar() { clearInterval(pewaktu); if (putar.value) pewaktu = setInterval(() => lanjut(false), detik.value * 1000) }
function jedaOtomatis() { if (!putar.value) return; clearInterval(pewaktu); clearTimeout(jeda); jeda = setTimeout(aturPutar, 30000) }
watch([putar, detik], aturPutar)

// ---------- Jam berjalan ----------
const kini = ref(new Date()); let detak = null
const jam = computed(() => kini.value.toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit', second: '2-digit', timeZone: 'Asia/Makassar' }).replace(/:/g, '.'))

// ---------- Layar penuh ----------
const penuh = ref(false)
async function alihPenuh() {
  try { if (document.fullscreenElement) await document.exitFullscreen(); else await document.documentElement.requestFullscreen() } catch { /* tidak didukung */ }
}
const cekPenuh = () => { penuh.value = !!document.fullscreenElement }

// ---------- Geser, roda, papan ketik ----------
const isi = ref([]); let awal = null; let kunciRoda = false
const tepi = (arah) => { const el = isi.value[idx.value]; if (!el) return true; return arah > 0 ? el.scrollTop + el.clientHeight >= el.scrollHeight - 4 : el.scrollTop <= 4 }
function sentuhMulai(e) { if (lembar.value || pratinjau.value) return; const t = e.touches?.[0]; if (t) awal = { x: t.clientX, y: t.clientY } }
function sentuhAkhir(e) {
  if (!awal) return; const t = e.changedTouches?.[0]; const dx = t.clientX - awal.x; const dy = t.clientY - awal.y; awal = null
  if (Math.abs(dx) > 60 && Math.abs(dx) > Math.abs(dy) * 1.2) return dx < 0 ? lanjut() : mundur()
  if (Math.abs(dy) > 80 && Math.abs(dy) > Math.abs(dx) * 1.2) { if (dy < 0 && tepi(1)) lanjut(); else if (dy > 0 && tepi(-1)) mundur() }
}
function roda(e) {
  if (lembar.value || pratinjau.value || kunciRoda || Math.abs(e.deltaY) < 30) return
  const arah = e.deltaY > 0 ? 1 : -1; if (!tepi(arah)) return
  kunciRoda = true; setTimeout(() => (kunciRoda = false), 800); arah > 0 ? lanjut() : mundur()
}
function tombol(e) {
  if (['INPUT', 'SELECT', 'TEXTAREA'].includes(e.target.tagName) || lembar.value || pratinjau.value) return
  if (['ArrowRight', 'ArrowDown', 'PageDown', ' '].includes(e.key)) { e.preventDefault(); lanjut() }
  else if (['ArrowLeft', 'ArrowUp', 'PageUp'].includes(e.key)) { e.preventDefault(); mundur() }
  else if (e.key === 'f' || e.key === 'F') alihPenuh()
  else if (e.key === 'p' || e.key === 'P') putar.value = !putar.value
}

onMounted(() => {
  pt.mulai(); detak = setInterval(() => (kini.value = new Date()), 1000)
  window.addEventListener('keydown', tombol); document.addEventListener('fullscreenchange', cekPenuh)
})
onBeforeUnmount(() => {
  pt.berhenti(); clearInterval(detak); clearInterval(pewaktu); clearTimeout(jeda)
  window.removeEventListener('keydown', tombol); document.removeEventListener('fullscreenchange', cekPenuh)
  if (document.fullscreenElement) document.exitFullscreen().catch(() => {})
})

// ---------- Detail (admin/superadmin): daftar, cetak, Excel ----------
const lembar = ref(false); const daftar = ref(null); const pratinjau = ref(false); const penanda = ref({ jabatan: 'Direktur', nama: '', niy: '' })
function buka(k) { if (!admin.value || !k.daftar) return; daftar.value = k.daftar; lembar.value = true; jedaOtomatis() }
async function cetak() { penanda.value = await penandaKelompok({ jenis: 'umum' }).catch(() => penanda.value); pratinjau.value = true }
function ekspor() {
  const x = daftar.value
  const ws = XLSX.utils.aoa_to_sheet([[x.judul], [`${formatPanjang(pt.data.tanggal)}, pukul ${formatJam(pt.data.waktu)} WITA${saringanTeks.value ? ' · ' + saringanTeks.value : ''}`], [],
    ['No.', ...x.kolom.map((c) => c[1])], ...x.baris.map((b, i) => [i + 1, ...x.kolom.map((c) => b[c[0]] ?? '')])])
  ws['!cols'] = [{ wch: 5 }, ...x.kolom.map((c) => ({ wch: c[2] + 6 }))]
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Pantauan'); XLSX.writeFile(wb, `Pantauan-${x.judul.replace(/[^\w]+/g, '-')}-${pt.data.tanggal}.xlsx`)
}
const keluar = () => router.push('/')
const kendali = ref(false) // HP: saringan dan tombol disembunyikan agar slide lapang
</script>
<template>
  <div class="flex h-[100dvh] flex-col overflow-hidden bg-latar text-teks" @touchstart.passive="sentuhMulai" @touchend.passive="sentuhAkhir" @wheel.passive="roda">
    <!-- Bilah atas -->
    <header class="flex flex-wrap items-center gap-2 border-b border-garis bg-permukaan px-3 pb-2 pt-[max(0.5rem,env(safe-area-inset-top))] lg:px-5">
      <button class="tombol-ikon" aria-label="Kembali ke Beranda" @click="keluar"><PhArrowLeft :size="22" /></button>
      <LogoSimka :size="34" class="hidden text-[#C7332F] sm:block dark:text-[#FF8070]" />
      <div class="min-w-0 flex-1">
        <p class="truncate text-base font-extrabold leading-tight lg:text-xl">Layar Pantauan<span v-if="aktif" class="font-semibold text-teks2"> · {{ aktif.judul }}</span></p>
        <p class="flex items-center gap-1.5 text-xs text-teks2 lg:text-sm">
          <span class="relative flex h-2.5 w-2.5"><span class="absolute inline-flex h-full w-full animate-ping rounded-full bg-[#1E7D4F] opacity-60" /><span class="relative inline-flex h-2.5 w-2.5 rounded-full bg-[#1E7D4F]" /></span>
          <b>Langsung</b><b class="tabular-nums sm:hidden"> {{ jam }}</b> · diperbarui {{ pt.data ? formatJam(pt.data.waktu) : '…' }} WITA<span v-if="pt.data" class="hidden sm:inline"> · {{ formatPanjang(pt.data.tanggal) }}</span></p>
      </div>
      <button class="tombol-ikon lg:hidden" :aria-expanded="kendali" aria-label="Saringan dan kendali" @click="kendali = !kendali"><PhFunnel :size="22" :weight="kendali ? 'fill' : 'regular'" /></button>
      <p class="hidden text-2xl font-extrabold tabular-nums sm:block lg:text-3xl" aria-label="Jam sekarang">{{ jam }} <span class="text-sm font-bold text-teks2">WITA</span></p>
      <div :class="['w-full flex-wrap items-center gap-1.5 lg:flex lg:w-auto', kendali ? 'flex' : 'hidden']">
        <select v-model="f.jk" class="isian min-h-[38px] w-auto py-1 text-sm" aria-label="Saring putra/putri"><option value="">Putra dan putri</option><option value="L">Putra</option><option value="P">Putri</option></select>
        <select v-model="f.jenjang" class="isian min-h-[38px] w-auto py-1 text-sm" aria-label="Saring jenjang"><option value="">SMP dan SMA</option><option value="wustha">SMP (Wustha)</option><option value="sma">SMA</option></select>
        <select v-model="f.bidang" class="isian min-h-[38px] w-auto py-1 text-sm" aria-label="Saring bidang pegawai"><option value="">Semua bidang</option><option v-for="b in pt.data?.bidang || []" :key="b.id" :value="b.id">{{ b.nama }}</option></select>
        <button class="tombol-ikon" :aria-label="putar ? 'Hentikan putar otomatis' : 'Putar otomatis'" :title="putar ? 'Hentikan putar otomatis (P)' : 'Putar otomatis (P)'" @click="putar = !putar">
          <component :is="putar ? PhPause : PhPlay" :size="22" weight="fill" :class="putar && 'text-[#1E7D4F]'" /></button>
        <select v-if="putar" v-model.number="detik" class="isian min-h-[38px] w-auto py-1 text-sm" aria-label="Lama tiap slide"><option :value="10">10 dtk</option><option :value="20">20 dtk</option><option :value="30">30 dtk</option><option :value="60">60 dtk</option></select>
        <button class="tombol-ikon" aria-label="Muat ulang" :disabled="pt.memuat" @click="pt.muat()"><PhArrowClockwise :size="22" :class="pt.memuat && 'animate-spin'" /></button>
        <button class="tombol-ikon" :aria-label="penuh ? 'Keluar layar penuh' : 'Layar penuh'" title="Layar penuh (F)" @click="alihPenuh"><component :is="penuh ? PhArrowsIn : PhArrowsOut" :size="22" /></button>
      </div>
    </header>

    <div v-if="pt.galat && !pt.data" class="grid flex-1 place-items-center p-6 text-center text-teks2"><div><PhLock :size="44" weight="duotone" class="mx-auto text-teks3" /><p class="mt-2">{{ pt.galat }}</p></div></div>
    <p v-else-if="!pt.data" class="grid flex-1 place-items-center text-teks3">Memuat Layar Pantauan…</p>

    <!-- Slide -->
    <main v-else class="relative flex-1 overflow-hidden">
      <div class="flex h-full transition-transform duration-500 ease-out" :style="{ transform: `translateX(-${idx * 100}%)` }">
        <section v-for="(s, i) in slide" :key="s.k" :ref="(el) => (isi[i] = el)" class="h-full w-full shrink-0 overflow-y-auto px-4 pb-6 pt-4 lg:px-12 lg:pt-6" :class="'w-' + s.w" :aria-hidden="i !== idx" :inert="i !== idx || undefined">
          <div class="mb-4 flex items-center gap-3 lg:mb-6">
            <span class="ikon-judul"><component :is="s.ikon" :size="34" weight="duotone" /></span>
            <div class="min-w-0"><h1 class="text-2xl font-extrabold leading-tight lg:text-4xl">{{ s.judul }}</h1><p class="text-sm text-teks2 lg:text-lg">{{ s.sub }}<template v-if="saringanTeks"> · {{ saringanTeks }}</template></p></div>
            <span class="ml-auto hidden text-sm font-bold text-teks3 sm:block lg:text-lg">{{ i + 1 }}/{{ slide.length }}</span>
          </div>
          <div class="grid grid-cols-2 gap-3 md:grid-cols-3 lg:gap-5 xl:grid-cols-4">
            <component :is="admin ? 'button' : 'div'" v-for="k in s.kartu" :key="k.j" :type="admin ? 'button' : undefined" :class="['kartu-slide', 'w-' + k.w, admin && 'bisa']" :aria-label="admin ? `${k.j}: ${k.v}. Lihat daftar` : undefined" @click="buka(k)">
              <span class="ikon-slide"><component :is="k.i" :size="26" weight="duotone" /></span>
              <span class="angka">{{ k.v }}</span>
              <span class="judul">{{ k.j }}</span>
              <span class="ket">{{ k.ket }}</span>
            </component>
          </div>
          <div v-if="s.grafik?.length" class="mt-4 grid gap-4 lg:mt-6 lg:grid-cols-2 lg:gap-5">
            <div v-for="g in s.grafik" :key="g.judul" class="kartu grafik-slide flex items-center justify-center p-4 lg:p-5">
              <GrafikBatang v-if="g.tipe === 'batang' && g.label.length" class="w-full" :judul="g.judul" :label="g.label" :seri="g.seri" :sumbu-y="g.sumbuY" />
              <GrafikLingkaran v-else-if="g.tipe === 'lingkaran' && g.data.some((x) => x.nilai)" :judul="g.judul" :data="g.data" :satuan="g.satuan || 'santri'" />
              <p v-else class="py-10 text-center text-sm text-teks3">{{ g.judul }}: belum ada data hari ini.</p>
            </div>
          </div>
        </section>
      </div>
      <button class="panah left-2" aria-label="Slide sebelumnya" @click="mundur"><PhCaretLeft :size="28" weight="bold" /></button>
      <button class="panah right-2" aria-label="Slide berikutnya" @click="lanjut()"><PhCaretRight :size="28" weight="bold" /></button>
    </main>

    <!-- Penunjuk slide -->
    <nav v-if="slide.length" class="flex gap-1.5 overflow-x-auto border-t border-garis bg-permukaan px-3 pb-[max(0.5rem,env(safe-area-inset-bottom))] pt-2" aria-label="Daftar slide">
      <button v-for="(s, i) in slide" :key="s.k" type="button" :aria-current="i === idx ? 'true' : undefined" @click="ke(i)"
        :class="['flex min-h-[36px] shrink-0 items-center gap-1.5 rounded-full border px-3 text-xs font-semibold lg:text-sm', 'w-' + s.w, i === idx ? 'titik-aktif text-teks' : 'border-garis text-teks2']">
        <component :is="s.ikon" :size="16" weight="duotone" style="color: var(--c)" /> {{ s.judul }}</button>
    </nav>

    <LembarBawah v-model="lembar" lebar :judul="daftar?.judul || 'Daftar'">
      <div v-if="daftar" class="pb-2">
        <div class="mb-3 flex flex-wrap items-center gap-2">
          <p class="flex-1 text-sm text-teks2">{{ daftar.baris.length }} data · {{ formatPanjang(pt.data.tanggal) }}{{ saringanTeks ? ' · ' + saringanTeks : '' }}</p>
          <button class="tombol-garis w-pengajuan min-h-[40px] px-3 text-sm" @click="cetak"><PhEye :size="18" style="color: var(--c)" /> Cetak</button>
          <button class="tombol-garis w-santri min-h-[40px] px-3 text-sm" @click="ekspor"><PhDownloadSimple :size="18" style="color: var(--c)" /> Excel</button>
        </div>
        <div class="max-h-[60vh] overflow-auto rounded-xl border border-garis">
          <table class="w-full min-w-[560px] text-left text-sm">
            <thead class="sticky top-0 bg-permukaan2 text-teks2"><tr><th class="px-3 py-2 font-bold">No.</th><th v-for="c in daftar.kolom" :key="c[0]" class="px-3 py-2 font-bold">{{ c[1] }}</th></tr></thead>
            <tbody class="divide-y divide-garis">
              <tr v-for="(r, i) in daftar.baris" :key="i"><td class="px-3 py-2 tabular-nums text-teks3">{{ i + 1 }}</td><td v-for="c in daftar.kolom" :key="c[0]" class="px-3 py-2">{{ r[c[0]] ?? '–' }}</td></tr>
            </tbody>
          </table>
          <p v-if="!daftar.baris.length" class="py-6 text-center text-sm text-teks3">Tidak ada data.</p>
        </div>
      </div>
    </LembarBawah>

    <DokumenCetak v-if="daftar" kop="pondok" :judul="daftar.judul" :subjudul="`${formatPanjang(pt.data.tanggal)}, pukul ${formatJam(pt.data.waktu)} WITA${saringanTeks ? ' · ' + saringanTeks : ''}`"
      v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap" :mendatar="daftar.kolom.length > 5">
      <p style="margin: 0 0 6pt">Jumlah: {{ daftar.baris.length }}</p>
      <table class="tabel kecil">
        <thead><tr><th style="width:5%">No.</th><th v-for="c in daftar.kolom" :key="c[0]" :style="{ width: c[2] + '%' }">{{ c[1] }}</th></tr></thead>
        <tbody>
          <tr v-for="(r, i) in daftar.baris" :key="i"><td class="tengah">{{ i + 1 }}</td><td v-for="c in daftar.kolom" :key="c[0]">{{ r[c[0]] ?? '–' }}</td></tr>
          <tr v-if="!daftar.baris.length"><td :colspan="daftar.kolom.length + 1" class="tengah">Tidak ada data.</td></tr>
        </tbody>
      </table>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: penanda.jabatan || 'Direktur', nama: penanda.nama, niy: penanda.niy }"
          :kanan="{ jabatan: sesi.pengguna?.jabatan || 'Pencetak', nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
      </template>
    </DokumenCetak>
  </div>
</template>
<style scoped>
.ikon-judul { display: grid; place-items: center; height: 3.25rem; width: 3.25rem; flex-shrink: 0; border-radius: 1rem; color: #fff;
  background: linear-gradient(135deg, var(--c), color-mix(in srgb, var(--c) 65%, #000)); }
@media (min-width: 1024px) { .ikon-judul { height: 4rem; width: 4rem; } }
.kartu-slide {
  position: relative; display: flex; flex-direction: column; align-items: flex-start; gap: 2px; overflow: hidden; border-radius: 1.25rem; padding: 1rem 1rem 1.1rem;
  text-align: left; border: 1px solid color-mix(in srgb, var(--c) 30%, transparent);
  background: linear-gradient(140deg, color-mix(in srgb, var(--c) 18%, rgb(var(--permukaan))), color-mix(in srgb, var(--c2, var(--c)) 6%, rgb(var(--permukaan))));
  box-shadow: inset 4px 0 0 var(--c);
}
.kartu-slide.bisa { cursor: pointer; transition: transform .15s, box-shadow .15s; }
.kartu-slide.bisa:hover { transform: translateY(-2px); box-shadow: inset 4px 0 0 var(--c), 0 10px 24px -14px var(--c); }
.ikon-slide { display: grid; place-items: center; height: 2.75rem; width: 2.75rem; border-radius: .9rem; color: #fff; margin-bottom: .5rem;
  background: linear-gradient(135deg, var(--c), color-mix(in srgb, var(--c) 65%, #000)); }
.angka { font-size: clamp(1.8rem, 3.6vw, 3.6rem); font-weight: 800; line-height: 1.05; color: var(--c); font-variant-numeric: tabular-nums; }
.judul { font-size: clamp(.9rem, 1.25vw, 1.35rem); font-weight: 700; line-height: 1.25; }
.ket { font-size: clamp(.72rem, .95vw, 1rem); color: rgb(var(--teks-2)); line-height: 1.3; }
.panah { position: absolute; top: 50%; transform: translateY(-50%); display: none; height: 3rem; width: 3rem; place-items: center; border-radius: 999px;
  background: rgb(var(--permukaan) / .85); border: 1px solid rgb(var(--garis)); box-shadow: 0 6px 18px -10px rgba(0,0,0,.4); }
@media (min-width: 1024px) { .panah { display: grid; } }
.grafik-slide :deep(svg) { max-height: 32vh; }
.titik-aktif { border-color: var(--c); background: color-mix(in srgb, var(--c) 14%, rgb(var(--permukaan))); }
</style>
