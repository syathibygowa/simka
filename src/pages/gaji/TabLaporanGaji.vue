<!-- SIMKA PRO | src/pages/gaji/TabLaporanGaji.vue | v1.1 | Fase 11 – Tahap 6 Jabatan penanda tangan dari penunjukan superadmin | 11/10/2026 -->
<script setup>
// Laporan atas satu periode gaji (jumlah yang benar-benar diterima, termasuk penyesuaian ketetapan yayasan):
//   1. Rekap per bidang      : jumlah pegawai, menurut skema, penyesuaian, pendapatan, potongan, diterima per bidang induk
//   2. Daftar penerimaan     : dikelompokkan per bank (transfer) dan tunai (dengan kolom tanda terima)
//   3. Perbandingan bulan lalu: selisih jumlah diterima tiap pegawai terhadap periode sebelumnya
// Setiap laporan dapat diekspor ke Excel dan dicetak F4 (Mengetahui Direktur di kiri, Bendahara di kanan).
import { ref, computed, onMounted, watch } from 'vue'
import * as XLSX from 'xlsx'
import { PhBuildings, PhBank, PhArrowsLeftRight, PhFileXls, PhPrinter, PhUsersThree, PhHandCoins, PhTrendUp, PhTrendDown, PhCalendarBlank } from '@phosphor-icons/vue'
import { useGaji } from '@/stores/gaji'
import { useOrganisasi } from '@/stores/organisasi'
import { useLembaga } from '@/stores/lembaga'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { formatPendek } from '@/lib/tanggal'
import { namaPeriode, STATUS_PERIODE, rupiah, angka } from '@/lib/gaji'
import KartuStatistik from '@/components/KartuStatistik.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const gaji = useGaji(); const org = useOrganisasi(); const lembaga = useLembaga(); const sesi = useSesi(); const ui = useUI()
const periode = ref([]); const pilih = ref(''); const r = ref(null); const memuat = ref(true)
const jenis = ref('bidang'); const pratinjau = ref(false)
const JENIS = [
  { k: 'bidang', n: 'Rekap per bidang', ikon: PhBuildings },
  { k: 'terima', n: 'Daftar penerimaan', ikon: PhBank },
  { k: 'banding', n: 'Perbandingan bulan lalu', ikon: PhArrowsLeftRight },
]

onMounted(async () => {
  try {
    periode.value = (await gaji.daftarPeriode()).filter((p) => p.status !== 'batal')
    pilih.value = periode.value[0]?.id || ''
  } catch (e) { ui.toast(e.message, 'galat') }
  if (!pilih.value) memuat.value = false
})
watch(pilih, async (id) => {
  if (!id) return
  memuat.value = true
  try { r.value = await gaji.rincianPeriode(id) } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
})
const pr = computed(() => r.value?.periode || {})
const baris = computed(() => r.value?.baris || [])
const jumlah = (d, k) => d.reduce((a, x) => a + Number(x[k] || 0), 0)

// ---------- 1. Rekap per bidang (bidang induk = unit tingkat pertama di bawah lembaga) ----------
function bidangDari(d) {
  let u = d.org_unit_id ? org.cariUnit(d.org_unit_id) : org.units.find((x) => x.nama === d.unit)
  if (!u) return d.unit || 'Tanpa bidang'
  while (u.parent_id) { const induk = org.cariUnit(u.parent_id); if (!induk?.parent_id) break; u = induk }
  return u.nama
}
const rekapBidang = computed(() => {
  const m = new Map()
  for (const b of baris.value) {
    const k = bidangDari(b.data)
    const x = m.get(k) || { bidang: k, pegawai: 0, total_skema: 0, total_penyesuaian: 0, total_pendapatan: 0, total_potongan: 0, diterima: 0 }
    x.pegawai++
    for (const f of ['total_skema', 'total_penyesuaian', 'total_pendapatan', 'total_potongan', 'diterima']) x[f] += Number(b[f] || 0)
    m.set(k, x)
  }
  return [...m.values()].sort((a, b) => b.diterima - a.diterima)
})

// ---------- 2. Daftar penerimaan per bank dan tunai ----------
const kelompok = computed(() => {
  const m = new Map()
  for (const b of baris.value) {
    const rk = b.data.rekening || {}
    const k = !b.data.rekening ? 'Belum ada data rekening' : rk.cara_bayar === 'tunai' ? 'Tunai' : `Transfer ${rk.bank || '(bank belum diisi)'}`
    if (!m.has(k)) m.set(k, { nama: k, tunai: rk.cara_bayar === 'tunai' || !b.data.rekening, isi: [] })
    m.get(k).isi.push(b)
  }
  // Transfer lebih dulu (urut nama bank), lalu tunai, lalu yang belum berekening
  return [...m.values()].sort((a, b) => a.tunai - b.tunai || (a.nama === 'Belum ada data rekening') - (b.nama === 'Belum ada data rekening') || a.nama.localeCompare(b.nama))
})
const jumlahTransfer = computed(() => kelompok.value.filter((k) => !k.tunai).reduce((a, k) => a + jumlah(k.isi, 'diterima'), 0))
const jumlahTunai = computed(() => kelompok.value.filter((k) => k.tunai).reduce((a, k) => a + jumlah(k.isi, 'diterima'), 0))

// ---------- 3. Perbandingan dengan bulan lalu ----------
const banding = computed(() => baris.value.map((b) => {
  const l = b.bulan_lalu
  const lalu = l ? Number(l.diterima) : null
  return { b, lalu, kini: Number(b.diterima), selisih: lalu == null ? null : Number(b.diterima) - lalu, periodeLalu: l?.periode || '' }
}).sort((a, b) => Math.abs(b.selisih ?? 0) - Math.abs(a.selisih ?? 0) || a.b.data.nama.localeCompare(b.b.data.nama)))
const periodeLalu = computed(() => banding.value.find((x) => x.periodeLalu)?.periodeLalu || '')
const naik = computed(() => banding.value.filter((x) => x.selisih > 0).length)
const turun = computed(() => banding.value.filter((x) => x.selisih < 0).length)
const baru = computed(() => banding.value.filter((x) => x.selisih == null).length)
const totalLalu = computed(() => banding.value.reduce((a, x) => a + (x.lalu || 0), 0))
const tanda = (v) => (v == null ? 'Baru' : v === 0 ? 'Tetap' : (v > 0 ? '+' : '−') + rupiah(Math.abs(v)))
const sebabBerubah = (b) => {
  const s = []
  if (b.lalu == null) return 'Tidak ada pada periode sebelumnya'
  const l = b.b.bulan_lalu
  if (Number(b.b.total_skema) !== Number(l.skema)) s.push('skema ' + (Number(b.b.total_skema) > Number(l.skema) ? 'naik' : 'turun'))
  if (Number(b.b.total_potongan) !== Number(l.potongan)) s.push('potongan ' + (Number(b.b.total_potongan) > Number(l.potongan) ? 'bertambah' : 'berkurang'))
  if (b.selisih && !s.length) s.push('penyesuaian berubah')
  return s.join(', ')
}

// ---------- Excel ----------
const judulLaporan = computed(() => ({ bidang: 'Rekap Gaji per Bidang', terima: 'Daftar Penerimaan Gaji', banding: 'Perbandingan Gaji dengan Bulan Lalu' }[jenis.value]))
function ekspor() {
  const nm = namaPeriode(pr.value)
  let aoa
  if (jenis.value === 'bidang') {
    aoa = [['No.', 'Bidang', 'Jumlah pegawai', 'Menurut skema', 'Penyesuaian', 'Jumlah pendapatan', 'Potongan', 'Jumlah diterima'],
      ...rekapBidang.value.map((x, i) => [i + 1, x.bidang, x.pegawai, x.total_skema, x.total_penyesuaian, x.total_pendapatan, x.total_potongan, x.diterima]),
      ['', 'Jumlah', baris.value.length, jumlah(baris.value, 'total_skema'), jumlah(baris.value, 'total_penyesuaian'), jumlah(baris.value, 'total_pendapatan'), jumlah(baris.value, 'total_potongan'), jumlah(baris.value, 'diterima')]]
  } else if (jenis.value === 'terima') {
    aoa = [['Kelompok', 'No.', 'NIY', 'Nama', 'JK', 'Bank', 'Nomor rekening', 'Atas nama', 'Jumlah diterima']]
    for (const k of kelompok.value) {
      k.isi.forEach((b, i) => { const rk = b.data.rekening || {}
        aoa.push([k.nama, i + 1, b.data.niy || '', b.data.nama, b.data.jk || '', rk.bank || '', rk.nomor_rekening || '', rk.atas_nama || '', Number(b.diterima)]) })
      aoa.push([`Jumlah ${k.nama}`, '', '', '', '', '', '', '', jumlah(k.isi, 'diterima')])
    }
    aoa.push(['Jumlah seluruhnya', '', '', '', '', '', '', '', jumlah(baris.value, 'diterima')])
  } else {
    aoa = [['No.', 'NIY', 'Nama', 'JK', `Diterima ${periodeLalu.value || 'bulan lalu'}`, `Diterima ${nm}`, 'Selisih', 'Keterangan'],
      ...banding.value.map((x, i) => [i + 1, x.b.data.niy || '', x.b.data.nama, x.b.data.jk || '', x.lalu ?? '', x.kini, x.selisih ?? '', sebabBerubah(x)]),
      ['', '', 'Jumlah', '', totalLalu.value, jumlah(baris.value, 'diterima'), jumlah(baris.value, 'diterima') - totalLalu.value, '']]
  }
  const ws = XLSX.utils.aoa_to_sheet([[`${judulLaporan.value} – ${nm}`], [], ...aoa])
  ws['!cols'] = aoa[0].map((j) => ({ wch: /Nama|Bidang|Kelompok|Keterangan/.test(j) ? 32 : 16 }))
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Laporan')
  XLSX.writeFile(wb, `${judulLaporan.value.replace(/ /g, '-')}-${nm.replace(' ', '-')}.xlsx`)
}

const direktur = computed(() => lembaga.signatories.find((s) => /^direktur$/i.test(s.jabatan_tertulis)) || {})
const ttdKanan = computed(() => ({ jabatan: gaji.jabatanSaya, nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }))
</script>
<template>
  <div>
    <div class="mb-3 flex flex-wrap items-end gap-2">
      <div class="w-56"><label class="label-isian" for="lg-per"><PhCalendarBlank :size="14" class="inline" /> Periode gaji</label>
        <select id="lg-per" v-model="pilih" class="isian" :disabled="!periode.length">
          <option v-for="p in periode" :key="p.id" :value="p.id">{{ namaPeriode(p) }} · {{ STATUS_PERIODE[p.status]?.n || p.status }}</option></select></div>
      <div class="flex-1" />
      <button class="tombol-garis" :disabled="!baris.length" @click="ekspor"><PhFileXls :size="20" weight="duotone" /> Ekspor Excel</button>
      <button class="tombol-utama" :disabled="!baris.length" @click="pratinjau = true"><PhPrinter :size="20" weight="duotone" /> Cetak</button>
    </div>
    <div class="mb-4 flex flex-wrap gap-2" role="tablist" aria-label="Jenis laporan">
      <button v-for="j in JENIS" :key="j.k" role="tab" :aria-selected="jenis === j.k" :class="['lencana min-h-[40px] px-3 text-sm', jenis === j.k ? 'w-rekap ring-2 ring-[var(--c)]' : 'bg-permukaan2 text-teks2']" @click="jenis = j.k">
        <component :is="j.ikon" :size="18" weight="duotone" /> {{ j.n }}</button>
    </div>

    <p v-if="!memuat && !periode.length" class="kartu p-8 text-center text-sm text-teks3">Belum ada periode gaji. Buat periode di tab Periode gaji.</p>
    <p v-else-if="memuat" class="kartu p-8 text-center text-sm text-teks3">Memuat…</p>
    <template v-else-if="r">
      <p v-if="pr.status === 'draf'" class="mb-3 rounded-xl bg-permukaan2 p-3 text-sm text-teks2">Periode ini masih draf; angka dapat berubah sampai slip diterbitkan.</p>
      <div class="-mx-4 mb-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-3 sm:overflow-visible sm:px-0">
        <KartuStatistik class="w-[44%] shrink-0 snap-start sm:w-auto" judul="Pegawai" :nilai="baris.length" :ikon="PhUsersThree" warna="agenda" :keterangan="namaPeriode(pr)" />
        <KartuStatistik class="w-[72%] shrink-0 snap-start sm:w-auto" judul="Jumlah diterima" :nilai="rupiah(jumlah(baris, 'diterima'))" :ikon="PhHandCoins" warna="gaji" :keterangan="`Dibayar ${formatPendek(pr.tanggal_bayar)}`" />
        <KartuStatistik v-if="jenis === 'banding'" class="w-[72%] shrink-0 snap-start sm:w-auto" judul="Dibanding bulan lalu" :nilai="tanda(jumlah(baris, 'diterima') - totalLalu)" :ikon="PhArrowsLeftRight" warna="verifikasi" :keterangan="`${naik} naik · ${turun} turun · ${baru} baru`" />
        <KartuStatistik v-else class="w-[72%] shrink-0 snap-start sm:w-auto" judul="Transfer · tunai" :nilai="rupiah(jumlahTransfer)" :ikon="PhBank" warna="shift" :keterangan="`Tunai ${rupiah(jumlahTunai)}`" />
      </div>

      <!-- 1. Rekap per bidang -->
      <section v-if="jenis === 'bidang'" class="kartu overflow-x-auto p-0">
        <table class="w-full min-w-[720px] text-left text-sm">
          <thead class="bg-permukaan2 text-teks2"><tr><th class="px-3 py-2.5">Bidang</th><th class="px-3 py-2.5 text-right">Pegawai</th><th class="px-3 py-2.5 text-right">Menurut skema</th>
            <th class="px-3 py-2.5 text-right">Penyesuaian</th><th class="px-3 py-2.5 text-right">Pendapatan</th><th class="px-3 py-2.5 text-right">Potongan</th><th class="px-3 py-2.5 text-right">Diterima</th></tr></thead>
          <tbody class="divide-y divide-garis tabular-nums">
            <tr v-for="x in rekapBidang" :key="x.bidang"><td class="px-3 py-2.5 font-semibold">{{ x.bidang }}</td><td class="px-3 py-2.5 text-right">{{ x.pegawai }}</td>
              <td class="px-3 py-2.5 text-right">{{ angka(x.total_skema) }}</td><td class="px-3 py-2.5 text-right">{{ angka(x.total_penyesuaian) }}</td>
              <td class="px-3 py-2.5 text-right">{{ angka(x.total_pendapatan) }}</td><td class="px-3 py-2.5 text-right">{{ angka(x.total_potongan) }}</td>
              <td class="px-3 py-2.5 text-right font-bold">{{ angka(x.diterima) }}</td></tr>
          </tbody>
          <tfoot class="bg-permukaan2 font-bold tabular-nums"><tr><td class="px-3 py-2.5">Jumlah</td><td class="px-3 py-2.5 text-right">{{ baris.length }}</td>
            <td class="px-3 py-2.5 text-right">{{ angka(jumlah(baris, 'total_skema')) }}</td><td class="px-3 py-2.5 text-right">{{ angka(jumlah(baris, 'total_penyesuaian')) }}</td>
            <td class="px-3 py-2.5 text-right">{{ angka(jumlah(baris, 'total_pendapatan')) }}</td><td class="px-3 py-2.5 text-right">{{ angka(jumlah(baris, 'total_potongan')) }}</td>
            <td class="px-3 py-2.5 text-right">{{ angka(jumlah(baris, 'diterima')) }}</td></tr></tfoot>
        </table>
      </section>

      <!-- 2. Daftar penerimaan -->
      <template v-else-if="jenis === 'terima'">
        <section v-for="k in kelompok" :key="k.nama" :class="['kartu mb-3 p-4', k.tunai ? 'w-tahfizh' : 'w-shift']">
          <h3 class="judul-bagian mb-2 flex flex-wrap items-center gap-2"><component :is="k.tunai ? PhHandCoins : PhBank" :size="20" weight="duotone" style="color: var(--c)" />
            {{ k.nama }} <span class="lencana">{{ k.isi.length }} orang · {{ rupiah(jumlah(k.isi, 'diterima')) }}</span></h3>
          <ul class="divide-y divide-garis">
            <li v-for="b in k.isi" :key="b.id" class="flex flex-wrap items-center gap-2 py-2">
              <div class="min-w-[180px] flex-1"><p class="font-semibold">{{ b.data.nama }}</p>
                <p class="text-xs text-teks3">NIY {{ b.data.niy || '–' }}<template v-if="b.data.rekening?.nomor_rekening"> · {{ b.data.rekening.nomor_rekening }} a.n. {{ b.data.rekening.atas_nama }}</template></p></div>
              <p class="font-bold tabular-nums">{{ rupiah(b.diterima) }}</p>
            </li>
          </ul>
        </section>
      </template>

      <!-- 3. Perbandingan bulan lalu -->
      <section v-else class="kartu p-4">
        <p class="mb-2 text-sm text-teks3">{{ periodeLalu ? `Dibandingkan dengan ${periodeLalu}.` : 'Belum ada periode sebelumnya untuk dibandingkan.' }} Diurutkan dari selisih terbesar.</p>
        <ul class="divide-y divide-garis">
          <li v-for="x in banding" :key="x.b.id" class="flex flex-wrap items-center gap-2 py-2.5">
            <div class="min-w-[180px] flex-1"><p class="font-semibold">{{ x.b.data.nama }}</p>
              <p class="text-xs text-teks3">NIY {{ x.b.data.niy || '–' }} · {{ x.lalu == null ? '–' : rupiah(x.lalu) }} → {{ rupiah(x.kini) }}<template v-if="sebabBerubah(x) && x.selisih !== 0"> · {{ sebabBerubah(x) }}</template></p></div>
            <span :class="['lencana', x.selisih == null ? 'w-agenda' : x.selisih > 0 ? 'w-presensi' : x.selisih < 0 ? 'w-pengajuan' : 'bg-permukaan2 text-teks2']">
              <PhTrendUp v-if="x.selisih > 0" :size="14" /><PhTrendDown v-else-if="x.selisih < 0" :size="14" /> {{ tanda(x.selisih) }}</span>
          </li>
        </ul>
      </section>
    </template>

    <DokumenCetak v-if="r" v-model:pratinjau="pratinjau" :judul="judulLaporan" :subjudul="`Periode ${namaPeriode(pr)} · dibayar ${formatPendek(pr.tanggal_bayar)}`" :pencetak="sesi.pengguna?.nama_lengkap">
      <table v-if="jenis === 'bidang'" class="tabel">
        <colgroup><col style="width:6%"><col style="width:24%"><col style="width:9%"><col v-for="n in 5" :key="n" style="width:12.2%"></colgroup>
        <thead><tr><th>No.</th><th>Bidang</th><th>Pegawai</th><th>Menurut skema</th><th>Penyesuaian</th><th>Pendapatan</th><th>Potongan</th><th>Diterima</th></tr></thead>
        <tbody><tr v-for="(x, i) in rekapBidang" :key="x.bidang"><td class="tengah">{{ i + 1 }}</td><td>{{ x.bidang }}</td><td class="tengah">{{ x.pegawai }}</td>
          <td class="kanan">{{ angka(x.total_skema) }}</td><td class="kanan">{{ angka(x.total_penyesuaian) }}</td><td class="kanan">{{ angka(x.total_pendapatan) }}</td>
          <td class="kanan">{{ angka(x.total_potongan) }}</td><td class="kanan">{{ angka(x.diterima) }}</td></tr>
          <tr><th colspan="2">Jumlah</th><th>{{ baris.length }}</th><th class="kanan">{{ angka(jumlah(baris, 'total_skema')) }}</th><th class="kanan">{{ angka(jumlah(baris, 'total_penyesuaian')) }}</th>
            <th class="kanan">{{ angka(jumlah(baris, 'total_pendapatan')) }}</th><th class="kanan">{{ angka(jumlah(baris, 'total_potongan')) }}</th><th class="kanan">{{ angka(jumlah(baris, 'diterima')) }}</th></tr></tbody>
      </table>
      <template v-else-if="jenis === 'terima'">
        <template v-for="k in kelompok" :key="k.nama">
          <p style="margin: 8pt 0 3pt; font-weight: bold">{{ k.nama }}</p>
          <table class="tabel">
            <colgroup v-if="k.tunai"><col style="width:6%"><col style="width:14%"><col style="width:34%"><col style="width:5%"><col style="width:18%"><col style="width:23%"></colgroup>
            <colgroup v-else><col style="width:6%"><col style="width:14%"><col style="width:26%"><col style="width:5%"><col style="width:16%"><col style="width:16%"><col style="width:17%"></colgroup>
            <thead><tr><th>No.</th><th>NIY</th><th>Nama</th><th>JK</th><template v-if="!k.tunai"><th>Nomor rekening</th><th>Atas nama</th></template><th>Jumlah diterima</th><th v-if="k.tunai">Tanda terima</th></tr></thead>
            <tbody><tr v-for="(b, i) in k.isi" :key="b.id" :style="k.tunai ? 'height: 9mm' : ''"><td class="tengah">{{ i + 1 }}</td><td>{{ b.data.niy || '' }}</td><td>{{ b.data.nama }}</td><td class="tengah">{{ b.data.jk || '' }}</td>
              <template v-if="!k.tunai"><td>{{ b.data.rekening?.nomor_rekening || '' }}</td><td>{{ b.data.rekening?.atas_nama || '' }}</td></template>
              <td class="kanan">{{ angka(b.diterima) }}</td><td v-if="k.tunai">{{ i + 1 }}.</td></tr>
              <tr><th :colspan="k.tunai ? 4 : 6">Jumlah</th><th class="kanan">{{ angka(jumlah(k.isi, 'diterima')) }}</th><th v-if="k.tunai"></th></tr></tbody>
          </table>
        </template>
        <p style="margin-top: 6pt">Jumlah seluruhnya {{ rupiah(jumlah(baris, 'diterima')) }}: transfer {{ rupiah(jumlahTransfer) }}, tunai {{ rupiah(jumlahTunai) }}.</p>
      </template>
      <template v-else>
        <table class="tabel">
          <colgroup><col style="width:6%"><col style="width:14%"><col style="width:25%"><col style="width:5%"><col style="width:12%"><col style="width:12%"><col style="width:11%"><col style="width:15%"></colgroup>
          <thead><tr><th>No.</th><th>NIY</th><th>Nama</th><th>JK</th><th>{{ periodeLalu || 'Bulan lalu' }}</th><th>{{ namaPeriode(pr) }}</th><th>Selisih</th><th>Keterangan</th></tr></thead>
          <tbody><tr v-for="(x, i) in banding" :key="x.b.id"><td class="tengah">{{ i + 1 }}</td><td>{{ x.b.data.niy || '' }}</td><td>{{ x.b.data.nama }}</td><td class="tengah">{{ x.b.data.jk || '' }}</td>
            <td class="kanan">{{ x.lalu == null ? '–' : angka(x.lalu) }}</td><td class="kanan">{{ angka(x.kini) }}</td><td class="kanan">{{ x.selisih == null ? '–' : (x.selisih > 0 ? '+' : x.selisih < 0 ? '−' : '') + angka(Math.abs(x.selisih)) }}</td>
            <td>{{ x.selisih === 0 ? '' : sebabBerubah(x) }}</td></tr>
            <tr><th colspan="4">Jumlah</th><th class="kanan">{{ angka(totalLalu) }}</th><th class="kanan">{{ angka(jumlah(baris, 'diterima')) }}</th><th class="kanan">{{ angka(jumlah(baris, 'diterima') - totalLalu) }}</th><th></th></tr></tbody>
        </table>
      </template>
      <p class="catatan-cetak">Nominal dalam rupiah, sesuai jumlah yang benar-benar diterima (termasuk {{ (gaji.pengaturan.label_penyesuaian || 'penyesuaian ketetapan yayasan').toLowerCase() }}).</p>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan_tertulis || 'Direktur', nama: direktur.nama || '', niy: direktur.niy }" :kanan="ttdKanan" :tanggal="pr.tanggal_bayar" />
      </template>
    </DokumenCetak>
  </div>
</template>
