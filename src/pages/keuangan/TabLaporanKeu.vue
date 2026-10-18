<!-- SIMKA PRO | src/pages/keuangan/TabLaporanKeu.vue | v1.0 | 14.7.0: laporan keuangan satu halaman (pemasukan, pengeluaran, saldo, tagihan dan persentase lunas) | 18/10/2026 -->
<script setup>
// Laporan keuangan satu halaman untuk pimpinan pada rentang tanggal (bawaan bulan berjalan):
//   A. Arus kas per rekening (saldo awal, masuk, keluar, saldo akhir)
//   B. Pemasukan: pembayaran tagihan per jenis biaya dan pemasukan lain per kategori
//   C. Pengeluaran per kategori
//   D. Tagihan yang jatuh tempo pada rentang per jenis: nominal, dibayar, sisa, persentase lunas; posisi tunggakan hari ini
// Cetak F4 tegak satu halaman (kop, tanda tangan Direktur kiri dan Bendahara kanan) dan Excel.
import { ref, computed, onMounted, watch } from 'vue'
import * as XLSX from 'xlsx'
import { PhPrinter, PhFileXls, PhArrowCircleDown, PhArrowCircleUp, PhScales, PhPercent } from '@phosphor-icons/vue'
import { useKeuangan } from '@/stores/keuangan'
import { useLembaga } from '@/stores/lembaga'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { formatPanjang, formatPendek, hariIniISO } from '@/lib/tanggal'
import { rupiah, angka, SIKLUS } from '@/lib/keuangan'
import { namaBerkas, periodeRentang } from '@/lib/namaBerkas'
import KartuStatistik from '@/components/KartuStatistik.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const keu = useKeuangan(); const lembaga = useLembaga(); const sesi = useSesi(); const ui = useUI()
const hari = hariIniISO()
const akhirBulan = (iso) => { const d = new Date(iso.slice(0, 7) + '-01T00:00:00Z'); d.setUTCMonth(d.getUTCMonth() + 1); d.setUTCDate(0); return d.toISOString().slice(0, 10) }
const bulanLalu = (() => { const d = new Date(hari.slice(0, 7) + '-01T00:00:00Z'); d.setUTCMonth(d.getUTCMonth() - 1); return d.toISOString().slice(0, 10) })()
const thTA = Number(hari.slice(0, 4)) - (Number(hari.slice(5, 7)) < 7 ? 1 : 0)
const PRESET = [
  { k: 'bulan', n: 'Bulan ini', m: hari.slice(0, 8) + '01', s: akhirBulan(hari) },
  { k: 'lalu', n: 'Bulan lalu', m: bulanLalu, s: akhirBulan(bulanLalu) },
  { k: 'semester', n: 'Semester berjalan', m: Number(hari.slice(5, 7)) >= 7 ? `${thTA}-07-01` : `${thTA + 1}-01-01`, s: Number(hari.slice(5, 7)) >= 7 ? `${thTA}-12-31` : `${thTA + 1}-06-30` },
  { k: 'ta', n: 'Tahun ajaran', m: `${thTA}-07-01`, s: `${thTA + 1}-06-30` },
]
const preset = ref('bulan'); const mulai = ref(PRESET[0].m); const selesai = ref(PRESET[0].s)
function pilihPreset(p) { preset.value = p.k; mulai.value = p.m; selesai.value = p.s }
const L = ref(null); const memuat = ref(false)
async function muat() {
  if (selesai.value < mulai.value) return ui.toast('Tanggal akhir tidak boleh sebelum tanggal awal.', 'galat')
  memuat.value = true
  try { L.value = await keu.laporan({ mulai: mulai.value, selesai: selesai.value }) } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
onMounted(() => { muat(); lembaga.muat().catch(() => {}) })
watch([mulai, selesai], muat)

const jml = (a, k = 'jumlah') => (a || []).reduce((x, y) => x + Number(y[k] || 0), 0)
const T = computed(() => {
  const l = L.value || {}
  const mt = jml(l.masuk_tagihan); const ml = jml(l.masuk_lain); const kl = jml(l.keluar)
  const nom = jml(l.tagihan, 'nominal'); const dib = jml(l.tagihan, 'dibayar')
  return { mt, ml, masuk: mt + ml, keluar: kl, selisih: mt + ml - kl, nominal: nom, dibayar: dib, sisa: nom - dib, persen: nom ? Math.round(dib * 1000 / nom) / 10 : 100,
    awal: jml(l.akun, 'saldo_awal'), akhir: jml(l.akun, 'saldo_akhir') }
})
const KARTU = computed(() => [
  { judul: 'Pemasukan', nilai: L.value ? rupiah(T.value.masuk) : '…', ikon: PhArrowCircleDown, warna: 'presensi', ket: `Tagihan ${rupiah(T.value.mt)} · lain ${rupiah(T.value.ml)}` },
  { judul: 'Pengeluaran', nilai: L.value ? rupiah(T.value.keluar) : '…', ikon: PhArrowCircleUp, warna: 'klinik', ket: `${(L.value?.keluar || []).length} kategori` },
  { judul: 'Saldo akhir', nilai: L.value ? rupiah(T.value.akhir) : '…', ikon: PhScales, warna: 'shift', ket: `Saldo awal ${rupiah(T.value.awal)}` },
  { judul: 'Tagihan terbayar', nilai: L.value ? `${String(T.value.persen).replace('.', ',')}%` : '…', ikon: PhPercent, warna: 'keuangan', ket: `Sisa ${rupiah(T.value.sisa)}` },
])
const persen = (v) => `${String(Number(v).toFixed(1)).replace('.', ',')}%`
const pratinjau = ref(false)
const subjudul = computed(() => `Periode ${formatPanjang(mulai.value)} s.d. ${formatPanjang(selesai.value)}`)
const direktur = computed(() => lembaga.signatories?.find((s) => /^direktur$/i.test(s.jabatan_tertulis)) || {})
function excel() {
  const l = L.value; if (!l) return
  const wb = XLSX.utils.book_new(); const tambah = (nama, aoa, lebar) => { const ws = XLSX.utils.aoa_to_sheet(aoa); ws['!cols'] = lebar.map((w) => ({ wch: w })); XLSX.utils.book_append_sheet(wb, ws, nama) }
  tambah('Arus kas', [['Laporan Keuangan', subjudul.value], [], ['Rekening/kas', 'Saldo awal', 'Masuk', 'Keluar', 'Saldo akhir'],
    ...l.akun.map((a) => [a.nama, Number(a.saldo_awal), Number(a.masuk), Number(a.keluar), Number(a.saldo_akhir)]), ['Jumlah', T.value.awal, jml(l.akun, 'masuk'), jml(l.akun, 'keluar'), T.value.akhir]], [32, 15, 15, 15, 15])
  tambah('Pemasukan', [['Sumber', 'Uraian', 'Transaksi', 'Jumlah'], ...l.masuk_tagihan.map((x) => ['Pembayaran tagihan', x.jenis, x.transaksi, Number(x.jumlah)]),
    ...l.masuk_lain.map((x) => ['Pemasukan lain', x.kategori, x.transaksi, Number(x.jumlah)]), ['Jumlah', '', '', T.value.masuk]], [22, 32, 10, 15])
  tambah('Pengeluaran', [['Kategori', 'Transaksi', 'Jumlah'], ...l.keluar.map((x) => [x.kategori, x.transaksi, Number(x.jumlah)]), ['Jumlah', '', T.value.keluar]], [32, 10, 15])
  tambah('Tagihan', [['Jenis', 'Siklus', 'Tagihan', 'Santri', 'Lunas', 'Nominal', 'Dibayar', 'Sisa', '% lunas'],
    ...l.tagihan.map((x) => [x.jenis, SIKLUS[x.siklus]?.n, x.tagihan, x.santri, x.lunas, Number(x.nominal), Number(x.dibayar), Number(x.sisa), Number(x.persen)]),
    ['Jumlah', '', '', '', '', T.value.nominal, T.value.dibayar, T.value.sisa, T.value.persen]], [26, 12, 9, 9, 9, 15, 15, 15, 9])
  XLSX.writeFile(wb, `${namaBerkas('Laporan Keuangan', periodeRentang(mulai.value, selesai.value))}.xlsx`)
}
</script>
<template>
  <div>
    <div class="layar-saja">
      <div class="bilah-tab kecil mb-3" role="tablist" aria-label="Periode laporan">
        <button v-for="p in PRESET" :key="p.k" type="button" role="tab" :aria-selected="preset === p.k" :class="['tab-garis', preset === p.k && 'aktif']" @click="pilihPreset(p)">{{ p.n }}</button>
        <button type="button" role="tab" :aria-selected="preset === 'atur'" :class="['tab-garis', preset === 'atur' && 'aktif']" @click="preset = 'atur'">Atur sendiri</button>
      </div>
      <div class="kartu mb-3 grid grid-cols-2 gap-3 p-4 md:grid-cols-[1fr_1fr_auto]">
        <InputTanggal v-model="mulai" label="Dari tanggal" @update:model-value="preset = 'atur'" /><InputTanggal v-model="selesai" label="Sampai tanggal" @update:model-value="preset = 'atur'" />
        <div class="col-span-2 flex items-end gap-2 md:col-span-1">
          <button class="tombol-garis min-h-[48px] flex-1 px-3 text-sm" :disabled="!L" @click="excel"><PhFileXls :size="18" weight="duotone" /> Excel</button>
          <button class="tombol-utama min-h-[48px] flex-1 px-3 text-sm" :disabled="!L" @click="pratinjau = true"><PhPrinter :size="18" weight="duotone" /> Cetak 1 halaman</button></div>
      </div>
      <div class="-mx-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-2 sm:overflow-visible sm:px-0 xl:grid-cols-4">
        <KartuStatistik v-for="k in KARTU" :key="k.judul" class="w-[60%] shrink-0 snap-start sm:w-auto" :judul="k.judul" :nilai="k.nilai" :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket" />
      </div>
      <p v-if="memuat && !L" class="py-10 text-center text-teks3">Memuat laporan…</p>
      <div v-else-if="L" class="mt-4 grid gap-4 xl:grid-cols-2">
        <section class="kartu w-shift p-4">
          <h3 class="judul-bagian mb-2">A. Arus kas per rekening</h3>
          <table class="w-full text-sm"><thead class="text-left text-teks3"><tr><th class="py-1.5">Rekening/kas</th><th class="py-1.5 text-right">Awal</th><th class="py-1.5 text-right">Masuk</th><th class="py-1.5 text-right">Keluar</th><th class="py-1.5 text-right">Akhir</th></tr></thead>
            <tbody class="divide-y divide-garis"><tr v-for="a in L.akun" :key="a.nama"><td class="py-1.5">{{ a.nama }}</td><td class="py-1.5 text-right tabular-nums">{{ angka(a.saldo_awal) }}</td>
              <td class="py-1.5 text-right tabular-nums">{{ angka(a.masuk) }}</td><td class="py-1.5 text-right tabular-nums">{{ angka(a.keluar) }}</td><td class="py-1.5 text-right font-bold tabular-nums">{{ angka(a.saldo_akhir) }}</td></tr></tbody></table>
        </section>
        <section class="kartu w-presensi p-4">
          <h3 class="judul-bagian mb-2">B. Pemasukan</h3>
          <ul class="divide-y divide-garis text-sm">
            <li v-for="x in L.masuk_tagihan" :key="'t' + x.jenis" class="flex justify-between py-1.5"><span>{{ x.jenis }} <span class="text-xs text-teks3">({{ x.transaksi }} transaksi)</span></span><b class="tabular-nums">{{ rupiah(x.jumlah) }}</b></li>
            <li v-for="x in L.masuk_lain" :key="'l' + x.kategori" class="flex justify-between py-1.5"><span>{{ x.kategori }} <span class="text-xs text-teks3">(lain)</span></span><b class="tabular-nums">{{ rupiah(x.jumlah) }}</b></li>
            <li v-if="!L.masuk_tagihan.length && !L.masuk_lain.length" class="py-2 text-teks3">Tidak ada pemasukan.</li>
            <li class="flex justify-between py-1.5 font-extrabold"><span>Jumlah pemasukan</span><span class="tabular-nums">{{ rupiah(T.masuk) }}</span></li>
          </ul>
        </section>
        <section class="kartu w-klinik p-4">
          <h3 class="judul-bagian mb-2">C. Pengeluaran</h3>
          <ul class="divide-y divide-garis text-sm">
            <li v-for="x in L.keluar" :key="x.kategori" class="py-1.5"><div class="flex justify-between"><span>{{ x.kategori }} <span class="text-xs text-teks3">({{ x.transaksi }})</span></span><b class="tabular-nums">{{ rupiah(x.jumlah) }}</b></div>
              <div class="mt-1 h-1.5 overflow-hidden rounded-full bg-permukaan2"><div class="h-full rounded-full" style="background: var(--c)" :style="{ width: (T.keluar ? x.jumlah / T.keluar * 100 : 0) + '%' }" /></div></li>
            <li v-if="!L.keluar.length" class="py-2 text-teks3">Tidak ada pengeluaran.</li>
            <li class="flex justify-between py-1.5 font-extrabold"><span>Jumlah pengeluaran</span><span class="tabular-nums">{{ rupiah(T.keluar) }}</span></li>
            <li :class="['flex justify-between py-1.5 font-extrabold', T.selisih < 0 && 'text-merah']"><span>Selisih pemasukan − pengeluaran</span><span class="tabular-nums">{{ rupiah(T.selisih) }}</span></li>
          </ul>
        </section>
        <section class="kartu w-keuangan p-4">
          <h3 class="judul-bagian mb-2">D. Tagihan jatuh tempo pada periode</h3>
          <ul class="space-y-2 text-sm">
            <li v-for="x in L.tagihan" :key="x.jenis"><div class="flex justify-between gap-2"><span class="font-semibold">{{ x.jenis }} <span class="text-xs font-normal text-teks3">{{ x.lunas }}/{{ x.tagihan }} lunas</span></span>
              <span class="tabular-nums"><b>{{ persen(x.persen) }}</b> · sisa {{ rupiah(x.sisa) }}</span></div>
              <div class="mt-1 h-2 overflow-hidden rounded-full bg-permukaan2"><div class="h-full rounded-full" :style="{ width: x.persen + '%', background: x.persen >= 80 ? '#1E7D4F' : x.persen >= 50 ? '#B5501A' : '#C7332F' }" /></div></li>
            <li v-if="!L.tagihan.length" class="text-teks3">Tidak ada tagihan yang jatuh tempo pada periode ini.</li>
          </ul>
          <p class="mt-3 text-sm text-teks2">Posisi tunggakan hari ini: <b>{{ rupiah(L.tunggakan.jumlah) }}</b> dari {{ L.tunggakan.santri }} santri. Subsidi pada periode: {{ rupiah(L.subsidi) }}.</p>
        </section>
      </div>
    </div>

    <!-- Cetak satu halaman F4 -->
    <DokumenCetak v-if="L" v-model:pratinjau="pratinjau" judul="Laporan Keuangan" :subjudul="subjudul" :pencetak="sesi.pengguna?.nama_lengkap"
      :nama-berkas="namaBerkas('Laporan Keuangan', periodeRentang(mulai, selesai))">
      <div class="lap-ringkas">
        <p class="sub">A. Arus kas per rekening</p>
        <table class="tabel"><colgroup><col style="width:5%"><col style="width:35%"><col style="width:15%"><col style="width:15%"><col style="width:15%"><col style="width:15%"></colgroup>
          <thead><tr><th>No.</th><th>Rekening/kas</th><th>Saldo awal</th><th>Masuk</th><th>Keluar</th><th>Saldo akhir</th></tr></thead>
          <tbody><tr v-for="(a, i) in L.akun" :key="a.nama"><td class="tengah">{{ i + 1 }}</td><td>{{ a.nama }}</td><td class="kanan">{{ angka(a.saldo_awal) }}</td><td class="kanan">{{ angka(a.masuk) }}</td><td class="kanan">{{ angka(a.keluar) }}</td><td class="kanan">{{ angka(a.saldo_akhir) }}</td></tr>
            <tr><th colspan="2">Jumlah</th><th class="kanan">{{ angka(T.awal) }}</th><th class="kanan">{{ angka(jml(L.akun, 'masuk')) }}</th><th class="kanan">{{ angka(jml(L.akun, 'keluar')) }}</th><th class="kanan">{{ angka(T.akhir) }}</th></tr></tbody></table>
        <div class="dua">
          <div><p class="sub">B. Pemasukan</p>
            <table class="tabel"><colgroup><col style="width:62%"><col style="width:38%"></colgroup>
              <thead><tr><th>Uraian</th><th>Jumlah (Rp)</th></tr></thead>
              <tbody><tr v-for="x in L.masuk_tagihan" :key="'t' + x.jenis"><td>{{ x.jenis }}</td><td class="kanan">{{ angka(x.jumlah) }}</td></tr>
                <tr v-for="x in L.masuk_lain" :key="'l' + x.kategori"><td>{{ x.kategori }} (lain)</td><td class="kanan">{{ angka(x.jumlah) }}</td></tr>
                <tr v-if="!L.masuk_tagihan.length && !L.masuk_lain.length"><td colspan="2" class="tengah">Tidak ada</td></tr>
                <tr><th>Jumlah</th><th class="kanan">{{ angka(T.masuk) }}</th></tr></tbody></table></div>
          <div><p class="sub">C. Pengeluaran</p>
            <table class="tabel"><colgroup><col style="width:62%"><col style="width:38%"></colgroup>
              <thead><tr><th>Kategori</th><th>Jumlah (Rp)</th></tr></thead>
              <tbody><tr v-for="x in L.keluar" :key="x.kategori"><td>{{ x.kategori }}</td><td class="kanan">{{ angka(x.jumlah) }}</td></tr>
                <tr v-if="!L.keluar.length"><td colspan="2" class="tengah">Tidak ada</td></tr>
                <tr><th>Jumlah</th><th class="kanan">{{ angka(T.keluar) }}</th></tr>
                <tr><th>Selisih</th><th class="kanan">{{ angka(T.selisih) }}</th></tr></tbody></table></div>
        </div>
        <p class="sub">D. Tagihan jatuh tempo pada periode</p>
        <table class="tabel"><colgroup><col style="width:5%"><col style="width:27%"><col style="width:12%"><col style="width:15%"><col style="width:15%"><col style="width:15%"><col style="width:11%"></colgroup>
          <thead><tr><th>No.</th><th>Jenis biaya</th><th>Lunas/tagihan</th><th>Nominal</th><th>Dibayar</th><th>Sisa</th><th>% lunas</th></tr></thead>
          <tbody><tr v-for="(x, i) in L.tagihan" :key="x.jenis"><td class="tengah">{{ i + 1 }}</td><td>{{ x.jenis }}</td><td class="tengah">{{ x.lunas }}/{{ x.tagihan }}</td><td class="kanan">{{ angka(x.nominal) }}</td>
            <td class="kanan">{{ angka(x.dibayar) }}</td><td class="kanan">{{ angka(x.sisa) }}</td><td class="tengah">{{ persen(x.persen) }}</td></tr>
            <tr v-if="!L.tagihan.length"><td colspan="7" class="tengah">Tidak ada tagihan yang jatuh tempo pada periode ini</td></tr>
            <tr><th colspan="3">Jumlah</th><th class="kanan">{{ angka(T.nominal) }}</th><th class="kanan">{{ angka(T.dibayar) }}</th><th class="kanan">{{ angka(T.sisa) }}</th><th>{{ persen(T.persen) }}</th></tr></tbody></table>
        <p class="ket">Posisi tunggakan per {{ formatPendek(hari) }}: {{ rupiah(L.tunggakan.jumlah) }} dari {{ L.tunggakan.santri }} santri. Subsidi/keringanan pada periode: {{ rupiah(L.subsidi) }}.
          Pemasukan dihitung dari tanggal pembayaran; tagihan dihitung dari tanggal jatuh tempo.</p>
      </div>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan_tertulis || 'Direktur', nama: direktur.nama || '', niy: direktur.niy }"
          :kanan="{ jabatan: keu.jabatanSaya, nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
      </template>
    </DokumenCetak>
  </div>
</template>
<style>
.lap-ringkas { font-size: 9.5pt; }
.lap-ringkas .sub { font-weight: 700; margin: 6pt 0 3pt; }
.lap-ringkas table.tabel { font-size: 9pt; }
.lap-ringkas .dua { display: grid; grid-template-columns: 1fr 1fr; gap: 6mm; }
.lap-ringkas .ket { font-size: 8.5pt; margin-top: 4pt; }
</style>
