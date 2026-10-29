<!-- SIMKA PRO | src/pages/ekskul/TabLegerEkskul.vue | v1.2 | 14.30.0: label saringan yang sudah jelas disembunyikan (hemat ruang) | 29/10/2026 -->
<script setup>
// Ekskul → Leger: satu baris per santri aktif (No, NIS, Nama, JK, Kelas), lalu untuk setiap ekskul: persentase kehadiran
// semester ini dan nilai pengembangan diri (A–D). Santri yang tidak tercatat di ekskul mana pun (tanpa keanggotaan, kehadiran,
// v1.1 (14.27.0): hanya NIS; lebar kolom cetak dihitung dari jumlah ekskul (nama tidak terlalu lebar/sempit, tabel di tengah).
// maupun nilai) ditandai merah muda dan dapat disaring. Saringan jenjang, kelas, kategori indoor/outdoor; cetak F4 mendatar dan Excel.
import { ref, computed, onMounted, watch } from 'vue'
import * as XLSX from 'xlsx'
import { PhStudent, PhMedal, PhWarningCircle, PhChartLineUp, PhPrinter, PhFileXls, PhMagnifyingGlass } from '@phosphor-icons/vue'
import { useRapor } from '@/stores/rapor'
import { usePenilaian } from '@/stores/penilaian'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { useAmbang } from '@/stores/ambang'
import { LABEL_SEMESTER } from '@/lib/nilai'
import { JENJANG, JENJANG_PENDEK } from '@/lib/santri'
import { KATEGORI_EKSKUL } from '@/lib/ekskul'
import { formatPanjang } from '@/lib/tanggal'
import { namaBerkas } from '@/lib/namaBerkas'
import { ambilPenandaTangan } from '@/lib/penandatangan'
import KartuStatistik from '@/components/KartuStatistik.vue'
import SaringCorong from '@/components/SaringCorong.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const props = defineProps({ kategori: { type: String, default: '' } })
const rp = useRapor(); const pn = usePenilaian(); const sesi = useSesi(); const ui = useUI(); const amb = useAmbang(); amb.muat()
const semester = ref(null); const L = ref(null); const memuat = ref(false); const pratinjau = ref(false)
const jenjang = ref(''); const kelas = ref(''); const hanyaTanpa = ref(false); const cari = ref('')
const direktur = ref({ jabatan: 'Direktur', nama: '', niy: '' })
async function muat(s) {
  memuat.value = true
  try {
    if (!pn.dimuat) await pn.muat().catch(() => {})
    semester.value = s || semester.value || pn.ta?.semester || 1
    L.value = await rp.legerEkskul(semester.value)
  } catch (e) { ui.toast(e.message, 'galat'); L.value = null } finally { memuat.value = false }
}
onMounted(() => { muat(); ambilPenandaTangan('Direktur').then((d) => { direktur.value = d }).catch(() => {}) })

const ekskul = computed(() => (L.value?.ekskul || []).filter((g) => !props.kategori || g.kategori === props.kategori))
const daftarKelas = computed(() => [...new Set((L.value?.santri || []).filter((s) => !jenjang.value || s.jenjang === jenjang.value).map((s) => s.kelas).filter(Boolean))].sort((a, b) => a.localeCompare(b, 'id', { numeric: true })))
watch(jenjang, () => { if (!daftarKelas.value.includes(kelas.value)) kelas.value = '' })
const sel = (s, g) => s.ekskul?.[g.id] || null
const ikut = (s, g) => { const x = sel(s, g); return !!(x && (x.a || x.s || x.n)) }
const persen = (x) => (x?.s ? Math.round((x.h / x.s) * 100) : null)
/** Ekskul yang diikuti santri: semua ekskul (bukan hanya kategori tampil), agar "tanpa ekskul" benar-benar tanpa ekskul mana pun. */
const jumlahIkut = (s) => (L.value?.ekskul || []).filter((g) => ikut(s, g)).length
const baris = computed(() => {
  const q = cari.value.toLowerCase().trim()
  return (L.value?.santri || []).filter((s) => (!jenjang.value || s.jenjang === jenjang.value) && (!kelas.value || s.kelas === kelas.value)
    && (!hanyaTanpa.value || !jumlahIkut(s)) && (!q || `${s.nama} ${s.nis}`.toLowerCase().includes(q)))
})
const statistik = computed(() => {
  const d = baris.value; const n = memuat.value ? '…' : null
  const semuaP = d.flatMap((s) => ekskul.value.map((g) => persen(sel(s, g))).filter((v) => v != null))
  return [
    { judul: 'Santri', nilai: n ?? d.length, ikon: PhStudent, warna: 'santri', ket: kelas.value ? `Kelas ${kelas.value}` : jenjang.value ? JENJANG[jenjang.value] : 'Seluruh santri aktif' },
    { judul: 'Mengikuti ekskul', nilai: n ?? d.filter((s) => jumlahIkut(s)).length, ikon: PhMedal, warna: 'ekskul', ket: `${ekskul.value.length} ekskul${props.kategori ? ' ' + (KATEGORI_EKSKUL[props.kategori]?.n || '').toLowerCase() : ''}` },
    { judul: 'Tanpa ekskul', nilai: n ?? d.filter((s) => !jumlahIkut(s)).length, ikon: PhWarningCircle, warna: 'klinik', ket: 'Tidak tercatat di ekskul mana pun' },
    { judul: 'Rata-rata kehadiran', nilai: n ?? (semuaP.length ? Math.round(semuaP.reduce((a, b) => a + b, 0) / semuaP.length) : '–'), satuan: semuaP.length ? '%' : '', ikon: PhChartLineUp, warna: 'presensi', ket: LABEL_SEMESTER[semester.value] || '' },
  ]
})
const jumlahSaring = computed(() => [jenjang.value, kelas.value, hanyaTanpa.value].filter(Boolean).length)
const ringkasSaring = computed(() => [jenjang.value && JENJANG_PENDEK[jenjang.value], kelas.value && 'Kelas ' + kelas.value, hanyaTanpa.value && 'Hanya tanpa ekskul'].filter(Boolean).join(' · ') || 'Semua santri')
const subjudul = computed(() => [`Tahun Ajaran ${L.value?.ta || ''} · ${LABEL_SEMESTER[semester.value] || ''}`, jenjang.value && JENJANG[jenjang.value], kelas.value && 'Kelas ' + kelas.value,
  props.kategori && 'Ekskul ' + (KATEGORI_EKSKUL[props.kategori]?.n || '').toLowerCase(), hanyaTanpa.value && 'Santri tanpa ekskul'].filter(Boolean).join(' · '))
// Lebar kolom cetak (14.27.0): No 4, NIS 9, JK 4, Kelas 6, Jumlah 5 (= 28); setiap ekskul (Hadir + Nilai) paling lebar 12 dan
// nama 22–30. Bila ekskul sedikit, tabel tidak dipaksa selebar kertas (ditengahkan) agar kolom tetap proporsional.
const tata = computed(() => {
  const n = ekskul.value.length; const tetap = 28
  const pasang = n ? Math.min(12, (100 - tetap - 22) / n) : 0
  const nama = Math.min(30, 100 - tetap - n * pasang)
  const total = tetap + nama + n * pasang; const k = 100 / total
  const c = (v) => `${(v * k).toFixed(2)}%`
  return { lebar: `${Math.min(100, total).toFixed(1)}%`, no: c(4), nis: c(9), nama: c(nama), jk: c(4), kelas: c(6), jml: c(5), hadir: c(pasang * 0.55), nilai: c(pasang * 0.45), kecil: n > 6 }
})

function ekspor() {
  const kepala1 = ['No.', 'NIS', 'Nama', 'JK', 'Kelas', ...ekskul.value.flatMap((g) => [g.nama, '']), 'Jumlah ekskul']
  const kepala2 = ['', '', '', '', '', ...ekskul.value.flatMap(() => ['Hadir (%)', 'Nilai']), '']
  const isi = baris.value.map((s, i) => [i + 1, s.nis, s.nama, s.jenis_kelamin, s.kelas || '',
    ...ekskul.value.flatMap((g) => { const x = sel(s, g); return ikut(s, g) ? [persen(x) ?? '', x?.n || ''] : ['', ''] }), jumlahIkut(s)])
  const ws = XLSX.utils.aoa_to_sheet([kepala1, kepala2, ...isi])
  ws['!merges'] = ekskul.value.map((_, i) => ({ s: { r: 0, c: 5 + i * 2 }, e: { r: 0, c: 6 + i * 2 } }))
  ws['!cols'] = kepala1.map((k, i) => ({ wch: i === 2 ? 28 : i < 5 ? 10 : 10 }))
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Leger ekskul')
  XLSX.writeFile(wb, `${namaBerkas('Leger Ekskul', L.value?.ta?.replace('/', '-'), 'Semester ' + semester.value)}.xlsx`)
}
</script>
<template>
  <div class="w-ekskul">
    <div class="mb-3 flex flex-wrap items-center gap-2">
      <div class="bilah-tab kecil" role="tablist" aria-label="Semester">
        <button v-for="s in [1, 2]" :key="s" type="button" role="tab" :aria-selected="semester === s" @click="muat(s)" :class="['tab-garis w-agenda', semester === s && 'aktif']">{{ LABEL_SEMESTER[s] }}</button>
      </div>
      <span class="flex-1" />
      <button class="w-pengajuan tombol-garis px-4 text-sm" :disabled="!baris.length" @click="pratinjau = true"><PhPrinter :size="20" weight="duotone" style="color: var(--c)" /> Cetak leger</button>
      <button class="w-gaji tombol-garis px-4 text-sm" :disabled="!baris.length" @click="ekspor"><PhFileXls :size="20" weight="duotone" style="color: var(--c)" /> Ekspor</button>
    </div>

    <div class="-mx-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-2 sm:overflow-visible sm:px-0 xl:grid-cols-4">
      <KartuStatistik v-for="k in statistik" :key="k.judul" class="w-[46%] shrink-0 snap-start sm:w-auto" :judul="k.judul" :nilai="k.nilai" :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket" :satuan="k.satuan" />
    </div>

    <SaringCorong class="mt-4" :jumlah="jumlahSaring" :ringkasan="ringkasSaring" judul="Saring leger" bisa-atur-ulang @atur-ulang="jenjang = ''; kelas = ''; hanyaTanpa = false">
      <template #cari><div class="relative"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
        <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari nama atau NIS" aria-label="Cari santri" /></div></template>
      <div><label class="label-isian sr-only" for="lg-jenjang">Jenjang</label>
        <select id="lg-jenjang" v-model="jenjang" class="isian w-auto max-w-full"><option value="">Semua jenjang</option><option value="wustha">Kesetaraan Wustha</option><option value="sma">SMA</option></select></div>
      <div><label class="label-isian sr-only" for="lg-kelas">Kelas</label>
        <select id="lg-kelas" v-model="kelas" class="isian w-auto max-w-full"><option value="">Semua kelas</option><option v-for="k in daftarKelas" :key="k" :value="k">{{ k }}</option></select></div>
      <label class="flex min-h-[44px] items-center gap-2 self-end text-sm font-semibold"><input v-model="hanyaTanpa" type="checkbox" class="h-5 w-5 accent-[#C7332F]" /> Hanya santri tanpa ekskul</label>
    </SaringCorong>

    <p v-if="memuat" class="py-10 text-center text-teks3">Memuat leger ekskul…</p>
    <p v-else-if="!L" class="kartu mt-4 p-8 text-center text-sm text-teks3">Leger belum dapat dimuat.</p>
    <div v-else class="kartu mt-4 overflow-auto">
      <table class="w-full min-w-[720px] text-sm">
        <thead class="sticky top-0 z-10 bg-permukaan2 text-xs text-teks2">
          <tr><th rowspan="2" class="px-2 py-2">No.</th><th rowspan="2" class="px-2 text-left">NIS</th><th rowspan="2" class="sticky left-0 bg-permukaan2 px-2 text-left">Nama</th><th rowspan="2" class="px-2">JK</th><th rowspan="2" class="px-2">Kelas</th>
            <th v-for="g in ekskul" :key="g.id" colspan="2" class="border-l border-garis px-2 py-1.5" :title="g.pembina ? 'Pembina: ' + g.pembina : ''">{{ g.nama }}</th>
            <th rowspan="2" class="border-l border-garis px-2">Jumlah</th></tr>
          <tr><template v-for="g in ekskul" :key="g.id + 'k'"><th class="border-l border-garis px-1.5 pb-1.5 font-semibold">Hadir</th><th class="px-1.5 pb-1.5 font-semibold">Nilai</th></template></tr>
        </thead>
        <tbody class="divide-y divide-garis">
          <tr v-for="(s, i) in baris" :key="s.id" :class="!jumlahIkut(s) && 'baris-tanpa'">
            <td class="px-2 py-2 text-center tabular-nums text-teks3">{{ i + 1 }}</td>
            <td class="px-2 tabular-nums text-teks2">{{ s.nis }}</td>
            <td class="sticky left-0 bg-permukaan px-2 font-semibold">{{ s.nama }}<span v-if="!jumlahIkut(s)" class="block text-[11px] font-semibold text-merah">Tanpa ekskul</span></td>
            <td class="px-2 text-center">{{ s.jenis_kelamin }}</td>
            <td class="px-2 text-center">{{ s.kelas || '–' }}</td>
            <template v-for="g in ekskul" :key="g.id + s.id">
              <td :class="['border-l border-garis px-1.5 text-center tabular-nums', ikut(s, g) && amb.bawah(persen(sel(s, g))) && 'persen-ambang']">{{ ikut(s, g) ? (persen(sel(s, g)) != null ? persen(sel(s, g)) + '%' : '–') : '' }}</td>
              <td class="px-1.5 text-center font-bold">{{ ikut(s, g) ? sel(s, g)?.n || '–' : '' }}</td>
            </template>
            <td class="border-l border-garis px-2 text-center font-bold tabular-nums">{{ jumlahIkut(s) }}</td>
          </tr>
          <tr v-if="!baris.length"><td :colspan="6 + ekskul.length * 2" class="p-6 text-center text-teks3">Tidak ada santri pada saringan ini.</td></tr>
        </tbody>
      </table>
    </div>
    <p class="mt-2 text-xs text-teks3">Hadir = persentase kehadiran di ekskul pada {{ (LABEL_SEMESTER[semester] || '').toLowerCase() }}{{ L?.mulai ? ` (${formatPanjang(L.mulai)} – ${formatPanjang(L.selesai)})` : '' }}; Nilai = nilai pengembangan diri di rapor. Sel kosong = bukan anggota ekskul tersebut. Baris merah muda = tidak tercatat di ekskul mana pun.</p>

    <DokumenCetak judul="Leger Ekskul Santri" :subjudul="subjudul" mendatar v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap"
      :nama-berkas="namaBerkas('Leger Ekskul', subjudul)">
      <table :class="['tabel leger-ekskul', tata.kecil && 'kecil']" :style="{ width: tata.lebar, margin: '0 auto', tableLayout: 'fixed' }">
        <colgroup><col :style="{ width: tata.no }"><col :style="{ width: tata.nis }"><col :style="{ width: tata.nama }"><col :style="{ width: tata.jk }"><col :style="{ width: tata.kelas }">
          <template v-for="g in ekskul" :key="g.id"><col :style="{ width: tata.hadir }"><col :style="{ width: tata.nilai }"></template><col :style="{ width: tata.jml }"></colgroup>
        <thead>
          <tr><th rowspan="2">No.</th><th rowspan="2">NIS</th><th rowspan="2">Nama</th><th rowspan="2">JK</th><th rowspan="2">Kelas</th>
            <th v-for="g in ekskul" :key="g.id" colspan="2">{{ g.nama }}</th><th rowspan="2">Jml</th></tr>
          <tr><template v-for="g in ekskul" :key="g.id + 'c'"><th>Hadir</th><th>Nilai</th></template></tr>
        </thead>
        <tbody>
          <tr v-for="(s, i) in baris" :key="s.id" :class="!jumlahIkut(s) && 'cetak-tanpa'">
            <td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ s.nis }}</td><td>{{ s.nama }}</td><td class="tengah">{{ s.jenis_kelamin }}</td><td class="tengah">{{ s.kelas || '–' }}</td>
            <template v-for="g in ekskul" :key="g.id + s.id + 'c'"><td class="tengah">{{ ikut(s, g) ? (persen(sel(s, g)) != null ? persen(sel(s, g)) + '%' : '–') : '' }}</td><td class="tengah">{{ ikut(s, g) ? sel(s, g)?.n || '–' : '' }}</td></template>
            <td class="tengah">{{ jumlahIkut(s) }}</td>
          </tr>
        </tbody>
      </table>
      <p style="margin-top: 4pt; font-size: 8.5pt">Hadir = persentase kehadiran ekskul semester ini; Nilai = nilai pengembangan diri. Sel kosong = bukan anggota. Jumlah santri: {{ baris.length }}; tanpa ekskul: {{ baris.filter((s) => !jumlahIkut(s)).length }} (baris berlatar merah muda).</p>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan || 'Direktur', nama: direktur.nama, niy: direktur.niy }"
          :kanan="{ jabatan: 'Yang membuat,', nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
      </template>
    </DokumenCetak>
  </div>
</template>
<style>
.baris-tanpa td { background: color-mix(in srgb, #E5484D 9%, rgb(var(--permukaan))) !important; }
.dok table.tabel.leger-ekskul { font-size: 9pt; }
.dok table.tabel.leger-ekskul.kecil { font-size: 7.5pt; }
.dok table.tabel.leger-ekskul th, .dok table.tabel.leger-ekskul td { overflow-wrap: anywhere; padding-left: 3pt; padding-right: 3pt; }
.dok table.tabel.leger-ekskul tr.cetak-tanpa td { background: #FDE2DF; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
</style>
