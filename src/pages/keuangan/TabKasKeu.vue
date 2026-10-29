<!-- SIMKA PRO | src/pages/keuangan/TabKasKeu.vue | v1.3 | 14.30.0: label saringan yang sudah jelas disembunyikan (hemat ruang) | 29/10/2026 -->
<script setup>
// Tab Kas dan bank:
//   • Kartu saldo setiap rekening/kas (langsung) dan total saldo.
//   • Buku kas / rekening koran: mutasi masuk-keluar dengan saldo berjalan per rekening atau gabungan pada rentang tanggal;
//     cetak F4 mendatar seperti rekening koran (kop, identitas rekening, saldo awal-akhir, tanda tangan) dan Excel.
//   • Transaksi lain: pengeluaran, pemasukan lain, pindah dana; batal dengan alasan; cetak bukti kas keluar/masuk.
import { ref, computed, onMounted, watch } from 'vue'
import { PhBank, PhWallet, PhArrowCircleUp, PhArrowCircleDown, PhArrowsLeftRight, PhPrinter, PhFileXls, PhBookOpen, PhListBullets, PhXCircle, PhReceipt, PhCoins } from '@phosphor-icons/vue'
import * as XLSX from 'xlsx'
import { useKeuangan } from '@/stores/keuangan'
import { useLembaga } from '@/stores/lembaga'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { formatPendek, formatPanjang, hariIniISO } from '@/lib/tanggal'
import { rupiah, angka, terbilang } from '@/lib/keuangan'
import { namaBerkas, periodeRentang } from '@/lib/namaBerkas'
import KartuStatistik from '@/components/KartuStatistik.vue'
import BilahTab from '@/components/BilahTab.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import SaringCorong from '@/components/SaringCorong.vue'
import TombolAksi from '@/components/TombolAksi.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import FotoBerkas from '@/components/FotoBerkas.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import LembarTransaksiKeu from './LembarTransaksiKeu.vue'

const keu = useKeuangan(); const lembaga = useLembaga(); const sesi = useSesi(); const ui = useUI()
const hari = hariIniISO()
const mulai = ref(hari.slice(0, 8) + '01'); const selesai = ref(hari); const akun = ref('')
const bagian = ref('buku')
const BAGIAN = [{ k: 'buku', n: 'Buku kas / rekening koran', ikon: PhBookOpen, w: 'shift' }, { k: 'transaksi', n: 'Pengeluaran dan pemasukan lain', ikon: PhListBullets, w: 'klinik' }]
const buku = ref(null); const trx = ref([]); const memuat = ref(false); const lembar = ref('')
async function muat() {
  if (selesai.value < mulai.value) return ui.toast('Tanggal akhir tidak boleh sebelum tanggal awal.', 'galat')
  memuat.value = true
  try {
    const p = { mulai: mulai.value, selesai: selesai.value, account_id: akun.value || null }
    ;[buku.value, trx.value] = await Promise.all([keu.bukuKas(p), keu.transaksi(p), keu.muatAkun()])
  } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
onMounted(() => { muat(); lembaga.muat().catch(() => {}) })
watch([mulai, selesai, akun], muat)

const aktif = computed(() => keu.akun.filter((a) => a.aktif))
const total = computed(() => aktif.value.reduce((x, a) => x + Number(a.saldo), 0))
const akunPilih = computed(() => keu.akun.find((a) => a.id === akun.value))
const KARTU = computed(() => [
  { judul: 'Total saldo', nilai: rupiah(total.value), ikon: PhCoins, warna: 'keuangan', ket: `${aktif.value.length} rekening/kas aktif` },
  { judul: 'Masuk pada rentang', nilai: buku.value ? rupiah(buku.value.masuk) : '…', ikon: PhArrowCircleDown, warna: 'presensi', ket: `${formatPendek(mulai.value)} – ${formatPendek(selesai.value)}` },
  { judul: 'Keluar pada rentang', nilai: buku.value ? rupiah(buku.value.keluar) : '…', ikon: PhArrowCircleUp, warna: 'klinik', ket: akunPilih.value?.nama || 'Semua rekening' },
  { judul: 'Saldo akhir rentang', nilai: buku.value ? rupiah(buku.value.saldo_akhir) : '…', ikon: PhBank, warna: 'shift', ket: `Per ${formatPendek(selesai.value)}` },
])
const SUMBER = { pembayaran: 'Pembayaran santri', masuk_lain: 'Pemasukan lain', keluar: 'Pengeluaran', pindah_masuk: 'Pindah dana masuk', pindah_keluar: 'Pindah dana keluar', saldo_awal: 'Saldo awal' }
const JENIS_TRX = { keluar: { n: 'Pengeluaran', w: 'klinik' }, masuk: { n: 'Pemasukan lain', w: 'presensi' }, pindah: { n: 'Pindah dana', w: 'shift' } }
const saringTrx = ref('')
const trxTampil = computed(() => trx.value.filter((t) => !saringTrx.value || t.jenis === saringTrx.value))

const batalT = ref(null); const alasan = ref(''); const prosesBatal = ref(false)
function batal(t) { batalT.value = t; alasan.value = '' }
async function simpanBatal() {
  const t = batalT.value
  if (alasan.value.trim().length < 5) return ui.toast('Tuliskan alasan pembatalan (minimal 5 huruf).', 'galat')
  prosesBatal.value = true
  try { await (t.jenis === 'pindah' ? keu.batalPindah(t.id, alasan.value.trim()) : keu.batalTransaksi(t.id, alasan.value.trim())); ui.toast('Transaksi dibatalkan; saldo dihitung ulang.'); batalT.value = null; muat() }
  catch (e) { ui.toast(e.message, 'galat') } finally { prosesBatal.value = false }
}

// ---------- Cetak dan Excel ----------
const pratinjau = ref(false); const bukti = ref(null)
const judulBuku = computed(() => (akunPilih.value?.jenis === 'bank' ? 'Rekening Koran' : 'Buku Kas'))
const subjudul = computed(() => `${akunPilih.value ? akunPilih.value.nama : 'Gabungan seluruh rekening dan kas'} · ${formatPanjang(mulai.value)} s.d. ${formatPanjang(selesai.value)}`)
const direktur = computed(() => lembaga.signatories?.find((s) => /^direktur$/i.test(s.jabatan_tertulis)) || {})
function excel() {
  if (!buku.value) return
  const b = buku.value
  const aoa = [[`${judulBuku.value} – ${subjudul.value}`], [], ['Tanggal', 'Nomor', 'Uraian', 'Pihak', 'Rekening', 'Masuk', 'Keluar', 'Saldo'], ['', '', 'Saldo awal', '', '', '', '', Number(b.saldo_awal)],
    ...b.baris.map((r) => [formatPendek(r.tanggal), r.nomor || '', r.uraian, r.pihak || '', r.akun, Number(r.masuk) || '', Number(r.keluar) || '', Number(r.saldo)]),
    ['', '', 'Jumlah', '', '', Number(b.masuk), Number(b.keluar), Number(b.saldo_akhir)]]
  const ws = XLSX.utils.aoa_to_sheet(aoa); ws['!cols'] = [12, 22, 48, 26, 24, 14, 14, 15].map((w) => ({ wch: w }))
  const ws2 = XLSX.utils.aoa_to_sheet([['Rekening/kas', 'Saldo awal', 'Masuk', 'Keluar', 'Saldo akhir'], ...b.akun.map((a) => [a.nama, Number(a.saldo_awal), Number(a.masuk), Number(a.keluar), Number(a.saldo_akhir)])])
  ws2['!cols'] = [30, 15, 15, 15, 15].map((w) => ({ wch: w }))
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, judulBuku.value); XLSX.utils.book_append_sheet(wb, ws2, 'Ringkasan rekening')
  XLSX.writeFile(wb, `${namaBerkas(akunPilih.value?.nama || 'Semua rekening', judulBuku.value, periodeRentang(mulai.value, selesai.value))}.xlsx`)
}
</script>
<template>
  <div>
    <div class="layar-saja">
      <div class="-mx-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-2 sm:overflow-visible sm:px-0 xl:grid-cols-4">
        <KartuStatistik v-for="k in KARTU" :key="k.judul" class="w-[60%] shrink-0 snap-start sm:w-auto" :judul="k.judul" :nilai="k.nilai" :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket" />
      </div>
      <!-- Saldo per rekening -->
      <div class="-mx-4 mt-3 flex gap-2 overflow-x-auto px-4 pb-1 sm:mx-0 sm:flex-wrap sm:px-0">
        <button v-for="a in aktif" :key="a.id" type="button" @click="akun = akun === a.id ? '' : a.id"
          :class="['kartu flex min-w-[13rem] shrink-0 items-center gap-3 p-3 text-left', a.jenis === 'kas' ? 'w-keuangan' : 'w-shift', akun === a.id && 'terpilih']">
          <span class="chip-ikon h-10 w-10 shrink-0"><component :is="a.jenis === 'kas' ? PhWallet : PhBank" :size="22" weight="duotone" /></span>
          <span class="min-w-0"><span class="block truncate text-sm font-semibold">{{ a.nama }}</span><span class="block font-extrabold tabular-nums">{{ rupiah(a.saldo) }}</span></span>
        </button>
      </div>

      <div v-if="keu.hak.kelola" class="mt-3 flex flex-wrap gap-2">
        <button class="tombol-utama" @click="lembar = 'keluar'"><PhArrowCircleUp :size="20" weight="duotone" /> Pengeluaran</button>
        <button class="tombol-garis" @click="lembar = 'masuk'"><PhArrowCircleDown :size="20" weight="duotone" /> Pemasukan lain</button>
        <button class="tombol-garis" @click="lembar = 'pindah'"><PhArrowsLeftRight :size="20" weight="duotone" /> Pindah dana</button>
      </div>

      <SaringCorong class="mt-3" :jumlah="akun ? 1 : 0" :ringkasan="[`${formatPendek(mulai)} – ${formatPendek(selesai)}`, keu.akun.find((a) => a.id === akun)?.nama || 'Gabungan semua'].join(' · ')" judul="Saring kas dan bank">
        <div class="sm:w-44"><InputTanggal class="tanpa-label" v-model="mulai" label="Dari tanggal" /></div><div class="sm:w-44"><InputTanggal class="tanpa-label" v-model="selesai" label="Sampai tanggal" /></div>
        <div><label class="label-isian" for="kas-akun">Rekening/kas</label>
          <select id="kas-akun" v-model="akun" class="isian w-auto max-w-full"><option value="">Gabungan semua</option><option v-for="a in keu.akun" :key="a.id" :value="a.id">{{ a.nama }}{{ a.aktif ? '' : ' (nonaktif)' }}</option></select></div>
      </SaringCorong>
      <div class="mt-3 flex flex-wrap gap-2">
        <button class="tombol-garis min-h-[44px] px-3 text-sm" :disabled="!buku" @click="excel"><PhFileXls :size="18" weight="duotone" /> Ekspor</button>
        <button class="tombol-garis min-h-[44px] px-3 text-sm" :disabled="!buku" @click="pratinjau = true"><PhPrinter :size="18" weight="duotone" /> Cetak</button>
      </div>

      <BilahTab v-model="bagian" :tab="BAGIAN" kecil label="Bagian kas" class="mt-4" />

      <p v-if="memuat && !buku" class="py-10 text-center text-teks3">Memuat…</p>
      <!-- Buku kas -->
      <template v-else-if="bagian === 'buku' && buku">
        <p class="mt-3 text-sm text-teks2">Saldo awal <b>{{ rupiah(buku.saldo_awal) }}</b> · masuk <b class="text-[#1E7D4F] dark:text-[#5BD69A]">{{ rupiah(buku.masuk) }}</b> · keluar <b class="text-merah">{{ rupiah(buku.keluar) }}</b> · saldo akhir <b>{{ rupiah(buku.saldo_akhir) }}</b>
          <span v-if="!akun" class="text-xs text-teks3"> (pindah dana antarrekening tidak ditampilkan pada buku gabungan)</span></p>
        <div class="kartu mt-2 hidden overflow-x-auto lg:block">
          <table class="w-full text-left text-sm">
            <thead class="border-b border-garis bg-permukaan2 text-teks2"><tr><th class="px-3 py-3">Tanggal</th><th class="px-3 py-3">Uraian</th><th v-if="!akun" class="px-3 py-3">Rekening</th>
              <th class="px-3 py-3 text-right">Masuk</th><th class="px-3 py-3 text-right">Keluar</th><th class="px-3 py-3 text-right">Saldo</th></tr></thead>
            <tbody class="divide-y divide-garis">
              <tr class="bg-permukaan2/50"><td class="px-3 py-2 tabular-nums">{{ formatPendek(mulai) }}</td><td class="px-3 py-2 font-semibold" :colspan="akun ? 3 : 4">Saldo awal</td><td class="px-3 py-2 text-right font-bold tabular-nums">{{ angka(buku.saldo_awal) }}</td></tr>
              <tr v-for="(r, i) in buku.baris" :key="i">
                <td class="px-3 py-2 tabular-nums text-teks2">{{ formatPendek(r.tanggal) }}</td>
                <td class="px-3 py-2"><p>{{ r.uraian }}</p><p class="text-xs text-teks3">{{ [SUMBER[r.sumber], r.nomor, r.pihak].filter(Boolean).join(' · ') }}</p></td>
                <td v-if="!akun" class="px-3 py-2 text-teks2">{{ r.akun }}</td>
                <td class="px-3 py-2 text-right tabular-nums text-[#1E7D4F] dark:text-[#5BD69A]">{{ Number(r.masuk) ? angka(r.masuk) : '' }}</td>
                <td class="px-3 py-2 text-right tabular-nums text-merah">{{ Number(r.keluar) ? angka(r.keluar) : '' }}</td>
                <td class="px-3 py-2 text-right font-semibold tabular-nums">{{ angka(r.saldo) }}</td></tr>
              <tr v-if="!buku.baris.length"><td class="px-3 py-6 text-center text-teks3" :colspan="akun ? 5 : 6">Tidak ada mutasi pada rentang ini.</td></tr>
            </tbody>
          </table>
        </div>
        <ul class="mt-2 space-y-2 lg:hidden">
          <li v-for="(r, i) in buku.baris" :key="i" class="kartu flex items-start gap-3 p-3">
            <span :class="['chip-ikon h-9 w-9 shrink-0', Number(r.masuk) ? 'w-presensi' : 'w-klinik']"><component :is="Number(r.masuk) ? PhArrowCircleDown : PhArrowCircleUp" :size="20" weight="duotone" /></span>
            <div class="min-w-0 flex-1"><p class="text-sm font-semibold leading-snug">{{ r.uraian }}</p>
              <p class="truncate text-xs text-teks3">{{ formatPendek(r.tanggal) }} · {{ SUMBER[r.sumber] }}{{ !akun ? ' · ' + r.akun : '' }}</p></div>
            <div class="shrink-0 text-right"><p :class="['font-bold tabular-nums', Number(r.masuk) ? 'text-[#1E7D4F] dark:text-[#5BD69A]' : 'text-merah']">{{ Number(r.masuk) ? '+' + angka(r.masuk) : '−' + angka(r.keluar) }}</p>
              <p class="text-xs tabular-nums text-teks3">saldo {{ angka(r.saldo) }}</p></div>
          </li>
          <li v-if="!buku.baris.length" class="kartu p-6 text-center text-sm text-teks3">Tidak ada mutasi pada rentang ini.</li>
        </ul>
      </template>
      <!-- Transaksi lain -->
      <template v-else-if="bagian === 'transaksi'">
        <div class="bilah-tab kecil mt-3" role="tablist" aria-label="Saring transaksi">
          <button v-for="(v, k) in { '': { n: 'Semua' }, ...JENIS_TRX }" :key="k" type="button" role="tab" :aria-selected="saringTrx === k" :class="['tab-garis', saringTrx === k && 'aktif']" @click="saringTrx = k">{{ v.n }}</button>
        </div>
        <ul class="mt-3 grid gap-2 lg:grid-cols-2">
          <li v-for="t in trxTampil" :key="t.id" :class="['kartu p-3', 'w-' + JENIS_TRX[t.jenis].w, t.status === 'batal' && 'opacity-60']">
            <div class="flex items-start gap-3">
              <span class="chip-ikon h-10 w-10 shrink-0"><component :is="t.jenis === 'keluar' ? PhArrowCircleUp : t.jenis === 'masuk' ? PhArrowCircleDown : PhArrowsLeftRight" :size="22" weight="duotone" /></span>
              <div class="min-w-0 flex-1">
                <p class="flex flex-wrap items-center gap-1.5"><span :class="['lencana', 'w-' + JENIS_TRX[t.jenis].w]">{{ JENIS_TRX[t.jenis].n }}</span><span class="text-xs text-teks3">{{ t.kategori }}</span>
                  <span v-if="t.status === 'batal'" class="lencana w-hakakses">Dibatalkan</span></p>
                <p class="mt-0.5 font-semibold leading-snug">{{ t.uraian }}</p>
                <p class="text-xs text-teks3">{{ formatPendek(t.tanggal) }} · {{ t.jenis === 'pindah' ? `${t.akun} → ${t.akun_tujuan}` : t.akun }}{{ t.pihak ? ' · ' + t.pihak : '' }}{{ t.nomor ? ' · ' + t.nomor : '' }}</p>
                <p v-if="t.status === 'batal'" class="text-xs text-merah">Alasan: {{ t.alasan_batal }}</p>
              </div>
              <div class="flex shrink-0 flex-col items-end gap-1">
                <p class="font-extrabold tabular-nums">{{ rupiah(t.jumlah) }}</p>
                <FotoBerkas v-if="t.bukti_id" :id="t.bukti_id" alt="Foto nota" ukuran="h-10 w-10" />
                <div class="flex gap-1">
                  <button v-if="t.jenis !== 'pindah' && t.status === 'sah'" class="tombol-ikon" aria-label="Cetak bukti kas" @click="bukti = t"><PhReceipt :size="20" /></button>
                  <button v-if="keu.hak.kelola && t.status === 'sah'" class="tombol-ikon text-merah" aria-label="Batalkan transaksi" @click="batal(t)"><PhXCircle :size="20" /></button>
                </div>
              </div>
            </div>
          </li>
          <li v-if="!trxTampil.length" class="kartu p-6 text-center text-sm text-teks3 lg:col-span-2">Tidak ada transaksi pada rentang ini.</li>
        </ul>
      </template>
    </div>
    <TombolAksi v-if="keu.hak.kelola" class="lg:hidden" label="Pengeluaran" :ikon="PhArrowCircleUp" warna="klinik" @klik="lembar = 'keluar'" />
    <LembarTransaksiKeu :jenis="lembar" @tutup="lembar = ''" @tersimpan="muat" />
    <LembarBawah :model-value="!!batalT" @update:model-value="(v) => !v && (batalT = null)" :judul="batalT ? `Batalkan ${JENIS_TRX[batalT.jenis].n.toLowerCase()}` : ''">
      <div v-if="batalT" class="space-y-3 pb-2">
        <p class="rounded-xl bg-permukaan2 p-3 text-sm">{{ batalT.uraian }} · <b>{{ rupiah(batalT.jumlah) }}</b> · {{ formatPendek(batalT.tanggal) }}</p>
        <div><label class="label-isian" for="kas-alasan">Alasan pembatalan</label><textarea id="kas-alasan" v-model="alasan" rows="2" class="isian" placeholder="Contoh: salah mencatat jumlah" /></div>
        <button class="tombol-utama w-full" :disabled="prosesBatal" @click="simpanBatal"><PhXCircle :size="20" weight="duotone" /> Batalkan transaksi</button>
      </div>
    </LembarBawah>

    <!-- Cetak buku kas / rekening koran -->
    <DokumenCetak jenis="keu_kas" v-if="buku" v-model:pratinjau="pratinjau" mendatar :judul="judulBuku" :subjudul="subjudul" :pencetak="sesi.pengguna?.nama_lengkap"
      :nama-berkas="namaBerkas(akunPilih?.nama || 'Semua rekening', judulBuku, periodeRentang(mulai, selesai))">
      <table v-if="akunPilih" class="meta-dok" style="margin-bottom: 6pt; font-size: 10pt">
        <tbody><tr><td style="width: 22%">Rekening/kas</td><td>: {{ akunPilih.nama }}</td><td style="width: 22%">Saldo awal</td><td>: {{ rupiah(buku.saldo_awal) }}</td></tr>
          <tr><td>{{ akunPilih.jenis === 'bank' ? 'Bank / nomor' : 'Jenis' }}</td><td>: {{ akunPilih.jenis === 'bank' ? `${akunPilih.bank} ${akunPilih.nomor}` : 'Kas tunai' }}</td><td>Jumlah masuk</td><td>: {{ rupiah(buku.masuk) }}</td></tr>
          <tr><td>Atas nama</td><td>: {{ akunPilih.atas_nama || '–' }}</td><td>Jumlah keluar</td><td>: {{ rupiah(buku.keluar) }}</td></tr>
          <tr><td>Periode</td><td>: {{ formatPendek(mulai) }} s.d. {{ formatPendek(selesai) }}</td><td>Saldo akhir</td><td>: <b>{{ rupiah(buku.saldo_akhir) }}</b></td></tr></tbody>
      </table>
      <table class="tabel" style="font-size: 9pt">
        <colgroup><col style="width:4%"><col style="width:9%"><col style="width:15%"><col :style="`width:${akunPilih ? 36 : 26}%`"><col v-if="!akunPilih" style="width:10%"><col style="width:12%"><col style="width:12%"><col style="width:12%"></colgroup>
        <thead><tr><th>No.</th><th>Tanggal</th><th>Nomor</th><th>Uraian</th><th v-if="!akunPilih">Rekening</th><th>Masuk (Rp)</th><th>Keluar (Rp)</th><th>Saldo (Rp)</th></tr></thead>
        <tbody>
          <tr><td></td><td class="tengah">{{ formatPendek(mulai) }}</td><td></td><td>Saldo awal</td><td v-if="!akunPilih"></td><td></td><td></td><td class="kanan">{{ angka(buku.saldo_awal) }}</td></tr>
          <tr v-for="(r, i) in buku.baris" :key="i"><td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ formatPendek(r.tanggal) }}</td><td>{{ r.nomor || '–' }}</td>
            <td>{{ r.uraian }}{{ r.pihak ? ' (' + r.pihak + ')' : '' }}</td><td v-if="!akunPilih">{{ r.akun }}</td>
            <td class="kanan">{{ Number(r.masuk) ? angka(r.masuk) : '' }}</td><td class="kanan">{{ Number(r.keluar) ? angka(r.keluar) : '' }}</td><td class="kanan">{{ angka(r.saldo) }}</td></tr>
          <tr><th :colspan="akunPilih ? 4 : 5">Jumlah</th><th class="kanan">{{ angka(buku.masuk) }}</th><th class="kanan">{{ angka(buku.keluar) }}</th><th class="kanan">{{ angka(buku.saldo_akhir) }}</th></tr>
        </tbody>
      </table>
      <table v-if="!akunPilih" class="tabel" style="font-size: 9pt; margin-top: 8pt">
        <colgroup><col style="width:4%"><col style="width:36%"><col style="width:15%"><col style="width:15%"><col style="width:15%"><col style="width:15%"></colgroup>
        <thead><tr><th>No.</th><th>Rekening/kas</th><th>Saldo awal</th><th>Masuk</th><th>Keluar</th><th>Saldo akhir</th></tr></thead>
        <tbody><tr v-for="(a, i) in buku.akun" :key="a.id"><td class="tengah">{{ i + 1 }}</td><td>{{ a.nama }}</td><td class="kanan">{{ angka(a.saldo_awal) }}</td><td class="kanan">{{ angka(a.masuk) }}</td>
          <td class="kanan">{{ angka(a.keluar) }}</td><td class="kanan">{{ angka(a.saldo_akhir) }}</td></tr></tbody>
      </table>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan_tertulis || 'Direktur', nama: direktur.nama || '', niy: direktur.niy }"
          :kanan="{ jabatan: keu.jabatanSaya, nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
      </template>
    </DokumenCetak>

    <!-- Cetak bukti kas keluar/masuk -->
    <DokumenCetak jenis="keu_bukti" v-if="bukti" :pratinjau="!!bukti" @update:pratinjau="(v) => !v && (bukti = null)" :judul="bukti.jenis === 'keluar' ? 'Bukti Kas Keluar' : 'Bukti Kas Masuk'" :nomor="bukti.nomor"
      :pencetak="sesi.pengguna?.nama_lengkap" :nama-berkas="namaBerkas(bukti.pihak || bukti.kategori, bukti.jenis === 'keluar' ? 'Bukti Kas Keluar' : 'Bukti Kas Masuk', bukti.nomor)">
      <table class="meta-dok" style="font-size: 11pt">
        <tbody>
          <tr><td style="width: 30%">Tanggal</td><td>: {{ formatPanjang(bukti.tanggal) }}</td></tr>
          <tr><td>{{ bukti.jenis === 'keluar' ? 'Dibayarkan kepada' : 'Diterima dari' }}</td><td>: {{ bukti.pihak || '–' }}</td></tr>
          <tr><td>{{ bukti.jenis === 'keluar' ? 'Dibayar dari' : 'Masuk ke' }}</td><td>: {{ bukti.akun }}</td></tr>
          <tr><td>Kategori</td><td>: {{ bukti.kategori }}</td></tr>
          <tr v-if="bukti.nomor_bukti"><td>Nomor nota</td><td>: {{ bukti.nomor_bukti }}</td></tr>
        </tbody>
      </table>
      <table class="tabel" style="margin-top: 8pt">
        <colgroup><col style="width:8%"><col style="width:62%"><col style="width:30%"></colgroup>
        <thead><tr><th>No.</th><th>Uraian</th><th>Jumlah (Rp)</th></tr></thead>
        <tbody><tr><td class="tengah">1</td><td>{{ bukti.uraian }}</td><td class="kanan">{{ angka(bukti.jumlah) }}</td></tr>
          <tr><th colspan="2">Jumlah</th><th class="kanan">{{ angka(bukti.jumlah) }}</th></tr></tbody>
      </table>
      <p style="margin-top: 4pt"><i>Terbilang: {{ terbilang(bukti.jumlah) }}</i></p>
      <template #ttd>
        <TandaTangan :kiri="{ jabatan: bukti.jenis === 'keluar' ? 'Yang menerima,' : 'Yang menyerahkan,', nama: bukti.pihak || '' }"
          :kanan="{ jabatan: keu.jabatanSaya, nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
      </template>
    </DokumenCetak>
  </div>
</template>
<style scoped>
.terpilih { box-shadow: inset 0 0 0 2px var(--c); }
</style>
