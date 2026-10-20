<!-- SIMKA PRO | src/pages/laporan/TabKinerjaBidang.vue | v1.0 | 14.18.0: laporan indikator kinerja bidang untuk Direktur dan Yayasan | 21/10/2026 -->
<script setup>
// Rekap dan Laporan → Kinerja bidang. Enam indikator yang SAMA untuk setiap bidang (lib/kinerja.js): kehadiran, ketepatan
// waktu, ketertiban perizinan, pengisian jurnal harian, pengabsenan santri, pelaksanaan tupoksi. Skor = rata-rata indikator
// yang berlaku; predikat ≥90 sangat baik, 80–89 baik, 70–79 cukup, <70 perlu pembinaan.
// Tampilan: kartu ringkas, grafik skor, peta warna bidang × indikator, kartu per bidang dengan catatan otomatis, rincian
// pegawai dan kelompok santri per bidang, penjelasan rumus. Keluaran: Excel (4 lembar) dan cetak F4 (laporan seluruh bidang
// atau rincian satu bidang) dengan penanda tangan dari Setelan → Penanda tangan (dokumen kinerja_bidang).
// Hak lihat (diperiksa server): pengguna Layar Pantauan, pimpinan tinggi, pengelola laporan tingkat Input/ubah.
import { ref, computed, onMounted, watch, nextTick } from 'vue'
import { PhTarget, PhMagnifyingGlass, PhFileXls, PhPrinter, PhInfo, PhUsersThree, PhTrophy, PhWarningCircle, PhChartLine, PhCaretRight, PhX, PhStudent, PhListChecks } from '@phosphor-icons/vue'
import { useKinerja } from '@/stores/kinerja'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { INDIKATOR, PREDIKAT, PERIODE_KINERJA, periodeKinerja, persenTeks, skorTeks } from '@/lib/kinerja'
import { formatPanjang, formatPendek } from '@/lib/tanggal'
import KartuStatistik from '@/components/KartuStatistik.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import SaringCorong from '@/components/SaringCorong.vue'
import GrafikSkor from '@/components/grafik/GrafikSkor.vue'
import PetaKinerja from '@/components/kinerja/PetaKinerja.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const kn = useKinerja(); const sesi = useSesi(); const ui = useUI()
const cepat = ref('berjalan'); const awal = periodeKinerja('berjalan'); const mulai = ref(awal.mulai); const selesai = ref(awal.selesai)
const data = ref(null); const bukaSaring = ref(false); const pilihId = ref(null); const cari = ref('')
function pilihCepat(k) { cepat.value = k; const p = periodeKinerja(k); mulai.value = p.mulai; selesai.value = p.selesai; muat() }
watch([mulai, selesai], () => { const p = periodeKinerja(cepat.value); if (p.mulai !== mulai.value || p.selesai !== selesai.value) cepat.value = '' })
async function muat() {
  if (selesai.value < mulai.value) return ui.toast('Tanggal akhir tidak boleh sebelum tanggal mulai.', 'galat')
  const hari = (new Date(selesai.value) - new Date(mulai.value)) / 86400000
  if (hari > 92) return ui.toast('Rentang paling panjang 3 bulan (92 hari).', 'galat')
  try { data.value = await kn.muat(mulai.value, selesai.value); bukaSaring.value = false } catch (e) { ui.toast(e.message, 'galat') }
}
onMounted(muat)

const bidang = computed(() => (data.value?.bidang || []).filter((b) => b.skor != null || b.pegawai))
const urut = computed(() => [...bidang.value].sort((a, b) => (b.skor ?? -1) - (a.skor ?? -1)))
const pilih = computed(() => bidang.value.find((b) => (b.id ?? b.kode) === pilihId.value) || null)
const pegawaiPilih = computed(() => {
  const q = cari.value.trim().toLowerCase()
  return (data.value?.pegawai || []).filter((p) => p.bidang === pilih.value?.id && (!q || [p.nama, p.niy, p.jabatan].join(' ').toLowerCase().includes(q)))
    .sort((a, b) => (a.skor ?? 999) - (b.skor ?? 999))
})
const kelompokPilih = computed(() => (data.value?.kelompok || []).filter((g) => g.bidang === pilih.value?.id && g.ss).sort((a, b) => (a.p ?? 0) - (b.p ?? 0)))
async function bukaBidang(b) { pilihId.value = b.id ?? b.kode; cari.value = ''; await nextTick(); document.getElementById('rincian-bidang')?.scrollIntoView({ behavior: 'smooth', block: 'start' }) }

const statistik = computed(() => {
  const d = data.value; if (!d) return []
  const dinilai = bidang.value.filter((b) => b.skor != null); const terbaik = urut.value[0]
  return [
    { judul: 'Skor seluruh pondok', nilai: skorTeks(d.pondok.skor), ikon: PhTarget, warna: 'rekap', keterangan: `${d.pondok.predikat?.n || '–'} · ${d.pondok.pegawai} pegawai` },
    { judul: 'Bidang terbaik', nilai: terbaik ? skorTeks(terbaik.skor) : '–', ikon: PhTrophy, warna: 'presensi', keterangan: terbaik?.nama || '–' },
    { judul: 'Baik ke atas (≥ 80)', nilai: dinilai.filter((b) => b.skor >= 80).length, ikon: PhChartLine, warna: 'jadwal', keterangan: `dari ${dinilai.length} bidang dinilai` },
    { judul: 'Perlu pembinaan (< 70)', nilai: dinilai.filter((b) => b.skor < 70).length, ikon: PhWarningCircle, warna: 'klinik', keterangan: 'Bidang dengan skor di bawah 70' },
  ]
})
const periodeTeks = computed(() => (data.value ? `${formatPendek(data.value.mulai)} s.d. ${formatPendek(data.value.selesai)}` : ''))
const periodePanjang = computed(() => (data.value ? `Periode ${formatPanjang(data.value.mulai)} s.d. ${formatPanjang(data.value.selesai)}` : ''))
const JENIS_KEL = { kelas: 'Kelas', halaqah: 'Halaqah', kamar: 'Kamar', ekskul: 'Ekskul' }

// ---------- Excel ----------
async function excel() {
  const XLSX = await import('xlsx'); const d = data.value; const per = periodePanjang.value
  const kolInd = INDIKATOR.map((x) => x.n)
  const baris = (r) => INDIKATOR.map((x) => (r.ind[x.k].p == null ? '–' : r.ind[x.k].p))
  const s1 = XLSX.utils.aoa_to_sheet([['LAPORAN INDIKATOR KINERJA BIDANG'], [per], [],
    ['No', 'Bidang', 'Kepala', 'Pegawai', ...kolInd, 'Skor', 'Predikat', 'Catatan'],
    ...urut.value.map((b, i) => [i + 1, b.nama, b.kepala || '', b.pegawai, ...baris(b), b.skor ?? '–', b.predikat?.n || '–', b.catatan.join(' ')]),
    ['', 'Seluruh pondok', '', d.pondok.pegawai, ...baris(d.pondok), d.pondok.skor ?? '–', d.pondok.predikat?.n || '–', '']])
  s1['!cols'] = [5, 28, 26, 8, ...kolInd.map(() => 12), 7, 14, 80].map((w) => ({ wch: w }))
  const namaB = Object.fromEntries(d.bidang.map((b) => [b.id, b.nama]))
  const s2 = XLSX.utils.aoa_to_sheet([['RINCIAN KINERJA PEGAWAI'], [per], [],
    ['No', 'NIY', 'Nama', 'Bidang', 'Jabatan', ...kolInd, 'Skor', 'Predikat', 'Sesi wajib', 'Hadir', 'Terlambat', 'Dinas luar', 'Izin', 'Sakit', 'Cuti', 'Tanpa ket.',
      'Hari wajib jurnal', 'Jurnal terisi', 'Sesi absen santri', 'Terisi', 'JP terjadwal', 'JP terlaksana', 'Butir tupoksi wajib', 'Butir dicentang'],
    ...[...d.pegawai].sort((a, b) => (namaB[a.bidang] || 'zz').localeCompare(namaB[b.bidang] || 'zz') || a.nama.localeCompare(b.nama))
      .map((p, i) => [i + 1, p.niy || '', p.nama, namaB[p.bidang] || 'Belum berbidang', p.jabatan || '', ...baris(p), p.skor ?? '–', p.predikat?.n || '–',
        p.wajib, p.hadir, p.terlambat, p.dinas, p.izin, p.sakit, p.cuti, p.tk, p.jur_wajib, p.jur_isi, p.ss, p.ss_isi, p.jp, p.jp_isi, p.butir, p.butir_isi])])
  s2['!cols'] = [5, 14, 28, 24, 24, ...kolInd.map(() => 12), 7, 14, ...Array(16).fill(10)].map((w) => ({ wch: w }))
  const s3 = XLSX.utils.aoa_to_sheet([['ABSENSI SANTRI PER KELOMPOK'], [per], [], ['No', 'Kelompok', 'Jenis', 'Bidang', 'Pengasuh', 'Sesi terjadwal', 'Terisi', 'Diisi terlambat', 'Capaian (%)'],
    ...d.kelompok.map((g, i) => [i + 1, g.nama, JENIS_KEL[g.jenis] || g.jenis, namaB[g.bidang] || '', g.pengasuh || '', g.ss, g.ss_isi, g.ss_telat, g.p ?? '–'])])
  s3['!cols'] = [5, 22, 10, 26, 30, 12, 10, 12, 12].map((w) => ({ wch: w }))
  const s4 = XLSX.utils.aoa_to_sheet([['PENJELASAN INDIKATOR'], [], ['No', 'Indikator', 'Aspek', 'Rumus', 'Keterangan'],
    ...INDIKATOR.map((x, i) => [i + 1, x.n, x.aspek, x.rumus, x.ket]), [], ['Skor = rata-rata indikator yang berlaku (bobot sama).'],
    ...PREDIKAT.map((p, i) => [i ? `${p.min}–${PREDIKAT[i - 1].min - 1}` : `≥ ${p.min}`, p.n])])
  s4['!cols'] = [6, 26, 22, 70, 90].map((w) => ({ wch: w }))
  const wb = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(wb, s1, 'Ringkasan bidang'); XLSX.utils.book_append_sheet(wb, s2, 'Pegawai')
  XLSX.utils.book_append_sheet(wb, s3, 'Kelompok santri'); XLSX.utils.book_append_sheet(wb, s4, 'Penjelasan indikator')
  XLSX.writeFile(wb, `Indikator-Kinerja-Bidang-${d.mulai}-sd-${d.selesai}.xlsx`)
}

// ---------- Cetak ----------
const pratinjau = ref(false); const modeCetak = ref('pondok'); const sertaPegawai = ref(false)
function cetak(mode) { modeCetak.value = mode; pratinjau.value = true }
const cetakBidang = computed(() => (modeCetak.value === 'bidang' && pilih.value ? [pilih.value] : urut.value))
const pegawaiBidang = (b) => (data.value?.pegawai || []).filter((p) => p.bidang === b.id).sort((a, x) => a.nama.localeCompare(x.nama))
const judulCetak = computed(() => (modeCetak.value === 'bidang' && pilih.value ? `Laporan Kinerja ${pilih.value.nama}` : 'Laporan Indikator Kinerja Bidang'))
</script>
<template>
  <div class="space-y-4">
    <SaringCorong v-model:buka="bukaSaring" :lipat="!!data" :ringkasan="periodeTeks" judul="Ubah periode" tanpa-tombol>
      <div class="kartu w-full min-w-0 space-y-4 p-4">
        <p class="flex items-start gap-1.5 text-sm text-teks2"><PhInfo :size="16" class="mt-0.5 shrink-0" />
          Enam indikator yang sama untuk setiap bidang. Dihitung dari data SIMKA sampai kemarin; rentang paling panjang 3 bulan.</p>
        <div class="bilah-tab kecil" role="tablist" aria-label="Periode cepat">
          <button v-for="p in PERIODE_KINERJA" :key="p.k" type="button" role="tab" :aria-selected="cepat === p.k" :class="['tab-garis w-rekap', cepat === p.k && 'aktif']" @click="pilihCepat(p.k)">{{ p.n }}</button>
        </div>
        <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-[1fr_1fr_auto] lg:items-end">
          <InputTanggal v-model="mulai" label="Dari tanggal" />
          <InputTanggal v-model="selesai" label="Sampai tanggal" />
          <button type="button" class="tombol-utama" :disabled="kn.memuat" @click="muat"><PhMagnifyingGlass :size="20" weight="bold" /> Tampilkan</button>
        </div>
      </div>
    </SaringCorong>

    <p v-if="kn.memuat && !data" class="py-10 text-center text-teks3">Menghitung indikator kinerja…</p>
    <p v-else-if="!data" class="kartu p-8 text-center text-teks3">{{ kn.galat || 'Pilih periode lalu tekan Tampilkan.' }}</p>
    <template v-else>
      <div class="flex flex-wrap items-center gap-2">
        <p class="flex-1 text-sm text-teks2">{{ periodePanjang }} · {{ data.hari }} hari · {{ bidang.length }} bidang</p>
        <button type="button" class="tombol-garis" @click="excel"><PhFileXls :size="18" weight="duotone" /> Ekspor</button>
        <label class="flex min-h-[44px] items-center gap-2 text-sm text-teks2"><input v-model="sertaPegawai" type="checkbox" class="h-4 w-4" /> Cetak beserta rincian pegawai</label>
        <button type="button" class="tombol-garis" @click="cetak('pondok')"><PhPrinter :size="18" weight="duotone" /> Cetak laporan</button>
      </div>
      <div class="grid grid-cols-2 gap-3 lg:grid-cols-4"><KartuStatistik v-for="s in statistik" :key="s.judul" v-bind="s" /></div>

      <div class="grid gap-4">
        <section class="kartu hidden p-4 sm:block"><GrafikSkor :data="urut.filter((b) => b.skor != null).map((b) => ({ id: b.id ?? b.kode, n: b.nama, v: b.skor, warna: b.predikat?.warna, ket: b.predikat?.n, b }))"
          judul="Skor kinerja per bidang (0–100)" bisa @pilih="(x) => bukaBidang(x.b)" /></section>
        <section class="kartu p-4"><PetaKinerja :baris="urut" :total="data.pondok" judul="Capaian enam indikator per bidang" bisa @pilih="bukaBidang" /></section>
      </div>

      <!-- Kartu per bidang -->
      <div class="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
        <button v-for="b in urut" :key="b.id ?? b.kode" type="button" :class="['kartu-bidang kartu p-4 text-left', 'w-' + (b.predikat?.w || 'sistem'), (b.id ?? b.kode) === pilihId && 'terpilih']" @click="bukaBidang(b)">
          <div class="flex items-start gap-3">
            <div class="min-w-0 flex-1"><p class="font-bold leading-tight">{{ b.nama }}</p><p class="truncate text-xs text-teks3">{{ b.kepala ? 'Kepala: ' + b.kepala : 'Kepala belum ditetapkan' }} · {{ b.pegawai }} pegawai</p></div>
            <div class="text-right"><p class="angka-skor">{{ skorTeks(b.skor) }}</p><p class="text-xs font-bold" style="color: var(--c)">{{ b.predikat?.n || '–' }}</p></div>
          </div>
          <ul class="mt-3 space-y-1.5">
            <li v-for="x in INDIKATOR" :key="x.k" class="grid grid-cols-[7.5rem_1fr_3.6rem] items-center gap-2 text-xs">
              <span class="truncate text-teks2">{{ x.pendek }}</span>
              <span class="h-2 overflow-hidden rounded-full bg-permukaan2"><span class="block h-full rounded-full" :style="{ width: (b.ind[x.k].p || 0) + '%', background: x.warna }" /></span>
              <span class="text-right font-semibold tabular-nums">{{ b.ind[x.k].p == null ? '–' : persenTeks(b.ind[x.k].p) }}</span>
            </li>
          </ul>
          <p v-if="INDIKATOR.some((x) => b.ind[x.k].p == null)" class="mt-1 text-[11px] text-teks3">– = tidak berlaku bagi bidang ini</p>
          <ul class="mt-3 space-y-0.5 text-xs text-teks2"><li v-for="(c, i) in b.catatan.slice(0, 3)" :key="i">• {{ c }}</li></ul>
          <span class="mt-2 flex items-center gap-1 text-xs font-bold" style="color: var(--c)">Lihat rincian <PhCaretRight :size="14" weight="bold" /></span>
        </button>
      </div>

      <!-- Rincian bidang -->
      <section v-if="pilih" id="rincian-bidang" :class="['kartu scroll-mt-20 space-y-3 p-4', 'w-' + (pilih.predikat?.w || 'sistem')]">
        <div class="flex flex-wrap items-start gap-2">
          <div class="min-w-0 flex-1"><h3 class="text-lg font-extrabold">{{ pilih.nama }}</h3>
            <p class="text-sm text-teks2">Skor <b>{{ skorTeks(pilih.skor) }}</b> · {{ pilih.predikat?.n || '–' }} · {{ pilih.kepala ? 'Kepala: ' + pilih.kepala : 'Kepala belum ditetapkan' }}</p></div>
          <button type="button" class="tombol-garis" @click="cetak('bidang')"><PhPrinter :size="18" weight="duotone" /> Cetak rincian</button>
          <button type="button" class="tombol-ikon" aria-label="Tutup rincian" @click="pilihId = null"><PhX :size="20" /></button>
        </div>
        <ul class="space-y-1 rounded-xl bg-permukaan2 p-3 text-sm text-teks2"><li v-for="(c, i) in pilih.catatan" :key="i" class="flex gap-1.5"><span class="text-teks3">•</span><span>{{ c }}</span></li></ul>

        <h4 class="flex items-center gap-1.5 font-bold"><PhUsersThree :size="18" style="color: var(--c)" /> Pegawai ({{ pegawaiPilih.length }})</h4>
        <label class="relative block"><span class="sr-only">Cari pegawai</span><PhMagnifyingGlass :size="18" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-teks3" />
          <input v-model="cari" class="isian pl-10" placeholder="Cari nama, NIY, atau jabatan" /></label>
        <p v-if="!pegawaiPilih.length" class="py-4 text-center text-sm text-teks3">Tidak ada pegawai.</p>
        <ul v-else class="space-y-2 lg:hidden">
          <li v-for="p in pegawaiPilih" :key="p.id" class="rounded-xl border border-garis p-3">
            <div class="flex items-start gap-2"><span class="min-w-0 flex-1"><span v-if="p.niy" class="block text-xs tabular-nums text-teks3">{{ p.niy }}</span><span class="block font-bold">{{ p.nama }}</span>
              <span class="block truncate text-xs text-teks3">{{ p.jabatan || '–' }}</span></span>
              <span class="text-right"><span class="block text-xl font-extrabold tabular-nums">{{ skorTeks(p.skor) }}</span><span class="block text-xs font-semibold" :class="'w-' + (p.predikat?.w || 'sistem')" style="color: var(--c)">{{ p.predikat?.n || '–' }}</span></span></div>
            <div class="mt-2 grid grid-cols-3 gap-1.5 text-center text-xs">
              <span v-for="x in INDIKATOR" :key="x.k" class="rounded-lg bg-permukaan2 px-1 py-1"><b class="block tabular-nums">{{ p.ind[x.k].p == null ? '–' : persenTeks(p.ind[x.k].p) }}</b><span class="text-teks3">{{ x.pendek }}</span></span></div>
          </li>
        </ul>
        <div v-if="pegawaiPilih.length" class="hidden overflow-x-auto lg:block">
          <table class="w-full text-sm">
            <thead><tr class="border-b border-garis text-left [&>th]:p-2"><th>NIY</th><th>Nama</th><th v-for="x in INDIKATOR" :key="x.k" class="text-right">{{ x.pendek }}</th><th class="text-right">Skor</th><th>Predikat</th><th>Catatan</th></tr></thead>
            <tbody>
              <tr v-for="p in pegawaiPilih" :key="p.id" class="border-b border-garis align-top last:border-0 [&>td]:p-2">
                <td class="whitespace-nowrap text-xs tabular-nums">{{ p.niy || '–' }}</td><td><span class="block font-semibold">{{ p.nama }}</span><span class="block text-xs text-teks3">{{ p.jabatan || '–' }}</span></td>
                <td v-for="x in INDIKATOR" :key="x.k" class="text-right tabular-nums" :title="`${p.ind[x.k].n} dari ${p.ind[x.k].d} ${x.satuan}`">{{ p.ind[x.k].p == null ? '–' : persenTeks(p.ind[x.k].p) }}</td>
                <td class="text-right font-extrabold tabular-nums">{{ skorTeks(p.skor) }}</td>
                <td :class="['whitespace-nowrap text-xs font-bold', 'w-' + (p.predikat?.w || 'sistem')]" style="color: var(--c)">{{ p.predikat?.n || '–' }}</td>
                <td class="max-w-[20rem] text-xs text-teks3">{{ p.catatan.filter((c) => !c.startsWith('Kekuatan')).slice(0, 2).join(' ') }}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <template v-if="kelompokPilih.length">
          <h4 class="flex items-center gap-1.5 pt-2 font-bold"><PhStudent :size="18" style="color: var(--c)" /> Absensi santri per kelompok ({{ kelompokPilih.length }})</h4>
          <ul class="grid gap-2 sm:grid-cols-2 xl:grid-cols-3">
            <li v-for="g in kelompokPilih" :key="g.id" class="rounded-xl border border-garis p-3 text-sm">
              <p class="flex items-center gap-2"><b class="flex-1">{{ JENIS_KEL[g.jenis] }} {{ g.nama }}</b><b class="tabular-nums">{{ persenTeks(g.p) }}</b></p>
              <p class="text-xs text-teks3">{{ g.pengasuh || 'Pengasuh belum ditetapkan' }} · {{ g.ss_isi }}/{{ g.ss }} sesi terisi{{ g.ss_telat ? ` · ${g.ss_telat} diisi terlambat` : '' }}</p>
            </li>
          </ul>
        </template>
      </section>

      <!-- Penjelasan indikator -->
      <details class="kartu p-4">
        <summary class="flex cursor-pointer items-center gap-2 font-bold"><PhListChecks :size="20" class="text-[#1D6B5F] dark:text-[#5FD3BE]" /> Penjelasan indikator dan cara menghitung</summary>
        <ol class="mt-3 space-y-3 text-sm">
          <li v-for="(x, i) in INDIKATOR" :key="x.k" class="flex gap-3"><span class="grid h-7 w-7 shrink-0 place-items-center rounded-lg text-xs font-extrabold text-white" :style="{ background: x.warna }">{{ i + 1 }}</span>
            <span><b>{{ x.n }}</b> <span class="text-teks3">({{ x.aspek }})</span><span class="block font-mono text-xs text-teks2">{{ x.rumus }}</span><span class="block text-teks2">{{ x.ket }}</span></span></li>
        </ol>
        <p class="mt-3 text-sm text-teks2">Skor bidang = rata-rata indikator yang berlaku dengan bobot sama. Indikator yang tidak dimiliki bidang (mis. tidak mengasuh kelompok santri) ditulis "tidak berlaku" dan tidak memengaruhi skor.
          Predikat: ≥ 90 sangat baik; 80–89 baik; 70–79 cukup; &lt; 70 perlu pembinaan.</p>
      </details>
    </template>

    <!-- Cetak F4 -->
    <DokumenCetak v-if="data" jenis="kinerja_bidang" v-model:pratinjau="pratinjau" kop="pondok" :judul="judulCetak" :subjudul="periodePanjang" :pencetak="sesi.pengguna?.nama_lengkap">
      <p class="sub-judul">A. Ringkasan capaian</p>
      <table class="tabel kecil">
        <colgroup><col style="width:4%"><col style="width:22%"><col v-for="x in INDIKATOR" :key="x.k" style="width:8.5%"><col style="width:7%"><col style="width:16%"></colgroup>
        <thead><tr><th>No.</th><th>Bidang</th><th v-for="x in INDIKATOR" :key="x.k">{{ x.pendek }}</th><th>Skor</th><th>Predikat</th></tr></thead>
        <tbody>
          <tr v-for="(b, i) in cetakBidang" :key="b.id ?? b.kode"><td class="tengah">{{ i + 1 }}</td><td>{{ b.nama }}</td>
            <td v-for="x in INDIKATOR" :key="x.k" class="tengah">{{ b.ind[x.k].p == null ? '–' : persenTeks(b.ind[x.k].p) }}</td><td class="tengah">{{ skorTeks(b.skor) }}</td><td>{{ b.predikat?.n || '–' }}</td></tr>
          <tr v-if="modeCetak === 'pondok'"><td /><td>Seluruh pondok</td>
            <td v-for="x in INDIKATOR" :key="x.k" class="tengah">{{ data.pondok.ind[x.k].p == null ? '–' : persenTeks(data.pondok.ind[x.k].p) }}</td><td class="tengah">{{ skorTeks(data.pondok.skor) }}</td><td>{{ data.pondok.predikat?.n || '–' }}</td></tr>
        </tbody>
      </table>
      <div v-if="modeCetak === 'pondok'" style="margin: 8pt 0; break-inside: avoid"><GrafikSkor :data="urut.filter((b) => b.skor != null).map((b) => ({ n: b.nama, v: b.skor, warna: b.predikat?.warna, ket: b.predikat?.n }))" judul="Skor kinerja per bidang" /></div>

      <p class="sub-judul">B. Catatan per bidang</p>
      <div v-for="(b, i) in cetakBidang" :key="'c' + (b.id ?? b.kode)" style="margin-bottom: 6pt; break-inside: avoid">
        <p style="margin: 0"><b>{{ i + 1 }}. {{ b.nama }}</b> — skor {{ skorTeks(b.skor) }} ({{ b.predikat?.n || '–' }}){{ b.kepala ? '; kepala: ' + b.kepala : '' }}; {{ b.pegawai }} pegawai.</p>
        <ul style="margin: 2pt 0 0; padding-left: 14pt"><li v-for="(c, j) in b.catatan" :key="j">{{ c }}</li></ul>
      </div>

      <template v-if="modeCetak === 'bidang' || sertaPegawai">
        <p class="sub-judul">C. Rincian pegawai</p>
        <div v-for="b in cetakBidang" :key="'p' + (b.id ?? b.kode)" style="margin-bottom: 8pt">
          <p v-if="cetakBidang.length > 1" style="margin: 0 0 2pt"><b>{{ b.nama }}</b></p>
          <table class="tabel kecil">
            <colgroup><col style="width:4%"><col style="width:11%"><col style="width:21%"><col v-for="x in INDIKATOR" :key="x.k" style="width:8%"><col style="width:6%"><col style="width:10%"></colgroup>
            <thead><tr><th>No.</th><th>NIY</th><th>Nama</th><th v-for="x in INDIKATOR" :key="x.k">{{ x.pendek }}</th><th>Skor</th><th>Predikat</th></tr></thead>
            <tbody>
              <tr v-for="(p, j) in pegawaiBidang(b)" :key="p.id"><td class="tengah">{{ j + 1 }}</td><td class="tengah">{{ p.niy || '–' }}</td><td>{{ p.nama }}</td>
                <td v-for="x in INDIKATOR" :key="x.k" class="tengah">{{ p.ind[x.k].p == null ? '–' : persenTeks(p.ind[x.k].p) }}</td><td class="tengah">{{ skorTeks(p.skor) }}</td><td>{{ p.predikat?.n || '–' }}</td></tr>
              <tr v-if="!pegawaiBidang(b).length"><td colspan="11" class="tengah">Tidak ada pegawai.</td></tr>
            </tbody>
          </table>
        </div>
      </template>

      <p class="sub-judul">{{ modeCetak === 'bidang' || sertaPegawai ? 'D' : 'C' }}. Penjelasan indikator</p>
      <table class="tabel kecil">
        <colgroup><col style="width:4%"><col style="width:18%"><col style="width:36%"><col style="width:42%"></colgroup>
        <thead><tr><th>No.</th><th>Indikator</th><th>Rumus</th><th>Keterangan</th></tr></thead>
        <tbody><tr v-for="(x, i) in INDIKATOR" :key="x.k"><td class="tengah">{{ i + 1 }}</td><td>{{ x.n }}</td><td>{{ x.rumus }}</td><td>{{ x.ket }}</td></tr></tbody>
      </table>
      <p style="margin-top: 4pt">Skor = rata-rata indikator yang berlaku dengan bobot sama ("–" = tidak berlaku). Predikat: ≥ 90 sangat baik; 80–89 baik; 70–79 cukup; &lt; 70 perlu pembinaan.
        Data dihitung dari presensi sesi kerja, jurnal harian, absensi santri, jurnal mengajar, dan ceklist tupoksi di SIMKA sampai {{ formatPanjang(data.selesai) }}.</p>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: 'Direktur', nama: '' }" :kanan="{ jabatan: 'Pembuat Laporan', nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
      </template>
    </DokumenCetak>
  </div>
</template>
<style scoped>
.kartu-bidang { box-shadow: inset 4px 0 0 var(--c); transition: transform .15s, box-shadow .15s; }
.kartu-bidang:hover { transform: translateY(-2px); }
.kartu-bidang.terpilih { box-shadow: inset 4px 0 0 var(--c), 0 0 0 2px var(--c); }
.angka-skor { font-size: 1.9rem; font-weight: 800; line-height: 1; color: var(--c); font-variant-numeric: tabular-nums; }
:global(.dok .sub-judul) { margin: 8pt 0 4pt; font-weight: bold; }
</style>
