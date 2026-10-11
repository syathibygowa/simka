<!-- SIMKA PRO | src/pages/keuangan/TabPembayaran.vue | v1.0 | Fase 13 – Daftar pembayaran, kuitansi, rekap pemasukan | 11/10/2026 -->
<script setup>
// Pembayaran santri per rentang tanggal (bawaan: awal bulan ini s.d. hari ini): jumlah, tunai/transfer, per jenis biaya.
// Setiap baris: cetak kuitansi, kirim konfirmasi WA ke wali, buka rincian santri, batalkan beralasan (kuitansi dicabut).
// Rekap pemasukan dicetak F4 (Mengetahui Direktur di kiri, Bendahara di kanan) dan diekspor ke Excel.
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import * as XLSX from 'xlsx'
import { PhFileXls, PhPrinter, PhWhatsappLogo, PhXCircle, PhReceipt, PhHandCoins, PhMoney, PhBank, PhImage } from '@phosphor-icons/vue'
import { useKeuangan } from '@/stores/keuangan'
import { useLembaga } from '@/stores/lembaga'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { formatPendek, formatPanjang, hariIniISO } from '@/lib/tanggal'
import { rupiah, angka, CARA_BAYAR, pesanKuitansi } from '@/lib/keuangan'
import { tautanWA } from '@/lib/wa'
import { alamatBerkas } from '@/lib/penyimpanan'
import KartuStatistik from '@/components/KartuStatistik.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import CetakKeuangan from '@/components/cetak/CetakKeuangan.vue'

const emit = defineEmits(['berubah'])
const keu = useKeuangan(); const lembaga = useLembaga(); const sesi = useSesi(); const ui = useUI(); const router = useRouter(); const route = useRoute()
const mulai = ref(hariIniISO().slice(0, 8) + '01'); const akhir = ref(hariIniISO()); const cara = ref(''); const tampilBatal = ref(false)
const daftar = ref([]); const memuat = ref(true)
async function muat() {
  memuat.value = true
  try { daftar.value = await keu.daftarPembayaran({ mulai: mulai.value, akhir: akhir.value, cara: cara.value }) } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
onMounted(() => { muat(); lembaga.muat() })
watch([mulai, akhir, cara], muat)
const sah = computed(() => daftar.value.filter((p) => p.status === 'sah'))
const tampil = computed(() => (tampilBatal.value ? daftar.value : sah.value))
const jml = (a) => a.reduce((x, p) => x + Number(p.jumlah), 0)
const perJenis = computed(() => {
  const m = new Map()
  for (const p of sah.value) for (const r of p.rincian || []) m.set(r.jenis, (m.get(r.jenis) || 0) + Number(r.jumlah))
  return [...m.entries()].map(([jenis, jumlah]) => ({ jenis, jumlah })).sort((a, b) => b.jumlah - a.jumlah)
})
const buka = (p) => router.replace({ query: { ...route.query, santri: p.student_id } })

// ---------- Aksi ----------
const kuitansi = ref([]); const pratinjauK = ref(false)
async function cetak(p) { try { kuitansi.value = await keu.kuitansi([p.id]); pratinjauK.value = true } catch (e) { ui.toast(e.message, 'galat') } }
async function wa(p) {
  if (!p.wali?.no_hp) return ui.toast('Nomor HP wali belum diisi di Data Santri.', 'galat')
  try { const k = (await keu.kuitansi([p.id]))[0]; window.open(tautanWA(p.wali.no_hp, pesanKuitansi(k)), '_blank', 'noopener') } catch (e) { ui.toast(e.message, 'galat') }
}
async function bukti(p) { try { const u = await alamatBerkas(p.bukti_id); if (u) window.open(u, '_blank', 'noopener') } catch (e) { ui.toast(e.message, 'galat') } }
const batal = ref(null)
async function simpanBatal() {
  if ((batal.value.teks || '').trim().length < 5) return ui.toast('Tulis alasan paling sedikit 5 karakter.', 'galat')
  try { await keu.batalkanPembayaran(batal.value.p.id, batal.value.teks.trim()); ui.toast('Pembayaran dibatalkan; kuitansi dicabut.'); batal.value = null; await muat(); emit('berubah') }
  catch (e) { ui.toast(e.message, 'galat') }
}

function ekspor() {
  const aoa = [['No.', 'Tanggal', 'Nomor kuitansi', 'NIS', 'Nama', 'JK', 'Kelas', 'Pembayaran', 'Cara', 'Rekening tujuan', 'Penyetor', 'Jumlah', 'Status', 'Dicatat oleh'],
    ...tampil.value.map((p, i) => [i + 1, formatPendek(p.tanggal), p.nomor, p.nis, p.nama, p.jk, p.kelas || '', (p.rincian || []).map((r) => `${r.tagihan} (${angka(r.jumlah)})`).join('; '),
      CARA_BAYAR[p.cara], p.rekening_tujuan || '', p.penyetor || '', Number(p.jumlah), p.status === 'sah' ? 'Sah' : 'Dibatalkan: ' + (p.alasan_batal || ''), p.dicatat || ''])]
  const ws = XLSX.utils.aoa_to_sheet([[`Pembayaran santri ${formatPendek(mulai.value)} s.d. ${formatPendek(akhir.value)}`], [], ...aoa])
  ws['!cols'] = aoa[0].map((j) => ({ wch: ['Nama', 'Pembayaran'].includes(j) ? 34 : 14 }))
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Pembayaran'); XLSX.writeFile(wb, `Pembayaran-Santri-${mulai.value}-${akhir.value}.xlsx`)
}
const pratinjau = ref(false)
const direktur = computed(() => lembaga.signatories.find((s) => /^direktur$/i.test(s.jabatan_tertulis)) || {})
</script>
<template>
  <div>
    <div class="mb-3 grid gap-2 sm:grid-cols-[1fr_1fr_auto] lg:grid-cols-[200px_200px_180px_1fr]">
      <InputTanggal v-model="mulai" label="Dari tanggal" />
      <InputTanggal v-model="akhir" label="Sampai tanggal" />
      <div><label class="label-isian" for="pb-cara">Cara bayar</label><select id="pb-cara" v-model="cara" class="isian"><option value="">Semua</option><option v-for="(n, k) in CARA_BAYAR" :key="k" :value="k">{{ n }}</option></select></div>
      <div class="flex flex-wrap items-end justify-end gap-2">
        <label class="flex min-h-[44px] items-center gap-2 text-sm"><input v-model="tampilBatal" type="checkbox" class="h-5 w-5" /> Tampilkan yang dibatalkan</label>
        <button class="tombol-garis" :disabled="!tampil.length" @click="ekspor"><PhFileXls :size="20" weight="duotone" /> Excel</button>
        <button class="tombol-garis" :disabled="!sah.length" @click="pratinjau = true"><PhPrinter :size="20" weight="duotone" /> Rekap</button>
      </div>
    </div>
    <div class="-mx-4 mb-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-3 sm:overflow-visible sm:px-0">
      <KartuStatistik class="w-[72%] shrink-0 snap-start sm:w-auto" judul="Pemasukan" :nilai="rupiah(jml(sah))" :ikon="PhHandCoins" warna="presensi" :keterangan="`${sah.length} transaksi`" />
      <KartuStatistik class="w-[72%] shrink-0 snap-start sm:w-auto" judul="Tunai" :nilai="rupiah(jml(sah.filter((p) => p.cara === 'tunai')))" :ikon="PhMoney" warna="tahfizh" :keterangan="`${sah.filter((p) => p.cara === 'tunai').length} transaksi`" />
      <KartuStatistik class="w-[72%] shrink-0 snap-start sm:w-auto" judul="Transfer" :nilai="rupiah(jml(sah.filter((p) => p.cara === 'transfer')))" :ikon="PhBank" warna="shift" :keterangan="`${sah.filter((p) => p.cara === 'transfer').length} transaksi`" />
    </div>
    <p v-if="perJenis.length" class="mb-3 flex flex-wrap gap-1.5 text-sm">
      <span v-for="x in perJenis" :key="x.jenis" class="lencana w-keuangan">{{ x.jenis }}: {{ rupiah(x.jumlah) }}</span></p>

    <p v-if="memuat" class="kartu p-8 text-center text-sm text-teks3">Memuat…</p>
    <p v-else-if="!tampil.length" class="kartu p-8 text-center text-sm text-teks3">Belum ada pembayaran pada rentang ini.</p>
    <ul v-else class="space-y-2.5">
      <li v-for="p in tampil" :key="p.id" :class="['kartu p-3.5', p.status === 'batal' && 'opacity-60']">
        <div class="flex flex-wrap items-start gap-2">
          <button class="min-w-[180px] flex-1 text-left" @click="buka(p)">
            <p class="font-bold">{{ p.nama }} <span class="text-xs font-normal text-teks3">{{ p.nis }} · {{ p.kelas || '–' }}</span></p>
            <p class="text-xs text-teks3">{{ formatPendek(p.tanggal) }} · {{ CARA_BAYAR[p.cara] }}{{ p.rekening_tujuan ? ' ke ' + p.rekening_tujuan : '' }} · {{ p.nomor }}</p>
            <p class="text-sm text-teks2">{{ (p.rincian || []).map((r) => r.tagihan).join(', ') }}</p>
            <p v-if="p.status === 'batal'" class="text-xs font-semibold text-merah">Dibatalkan: {{ p.alasan_batal }}</p>
          </button>
          <p class="text-lg font-extrabold tabular-nums">{{ rupiah(p.jumlah) }}</p>
        </div>
        <div class="mt-2 flex flex-wrap gap-1.5">
          <button class="tombol-garis min-h-[40px] px-3 text-sm" @click="cetak(p)"><PhReceipt :size="18" weight="duotone" /> Kuitansi</button>
          <button v-if="p.status === 'sah'" class="tombol-garis min-h-[40px] px-3 text-sm" :disabled="!p.wali?.no_hp" @click="wa(p)"><PhWhatsappLogo :size="18" weight="duotone" /> WA wali</button>
          <button v-if="p.bukti_id" class="tombol-garis min-h-[40px] px-3 text-sm" @click="bukti(p)"><PhImage :size="18" /> Bukti</button>
          <button v-if="keu.hak.kelola && p.status === 'sah'" class="tombol-garis min-h-[40px] px-3 text-sm text-merah" @click="batal = { p, teks: '' }"><PhXCircle :size="18" /> Batalkan</button>
        </div>
      </li>
    </ul>

    <CetakKeuangan v-model:pratinjau="pratinjauK" jenis="kuitansi" :dok="kuitansi" :pengaturan="keu.pengaturan" :pencetak="sesi.pengguna?.nama_lengkap" />
    <LembarBawah :model-value="!!batal" @update:model-value="(v) => !v && (batal = null)" :judul="batal ? `Batalkan pembayaran ${rupiah(batal.p.jumlah)}?` : ''">
      <div v-if="batal" class="space-y-3 pb-2">
        <p class="text-sm text-teks2">{{ batal.p.nama }} · {{ batal.p.nomor }}. Tagihan kembali terbuka dan kuitansi dicabut (Cek Keabsahan menampilkan "Dicabut").</p>
        <label class="label-isian" for="pb-als">Alasan pembatalan</label><input id="pb-als" v-model="batal.teks" class="isian" placeholder="Contoh: Salah memilih santri" />
        <button class="tombol-utama w-full bg-[#C7332F]" @click="simpanBatal"><PhXCircle :size="20" weight="duotone" /> Batalkan pembayaran</button>
      </div>
    </LembarBawah>
    <DokumenCetak v-model:pratinjau="pratinjau" mendatar judul="Rekap Pemasukan Keuangan Santri" :subjudul="`${formatPanjang(mulai)} s.d. ${formatPanjang(akhir)}${cara ? ' · ' + CARA_BAYAR[cara] : ''}`" :pencetak="sesi.pengguna?.nama_lengkap">
      <table class="tabel">
        <colgroup><col style="width:4%"><col style="width:9%"><col style="width:16%"><col style="width:9%"><col style="width:20%"><col style="width:7%"><col style="width:23%"><col style="width:12%"></colgroup>
        <thead><tr><th>No.</th><th>Tanggal</th><th>Nomor kuitansi</th><th>NIS</th><th>Nama</th><th>Cara</th><th>Pembayaran</th><th>Jumlah (Rp)</th></tr></thead>
        <tbody><tr v-for="(p, i) in sah" :key="p.id"><td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ formatPendek(p.tanggal) }}</td><td>{{ p.nomor }}</td><td>{{ p.nis }}</td><td>{{ p.nama }}</td>
          <td>{{ CARA_BAYAR[p.cara] }}</td><td>{{ (p.rincian || []).map((r) => r.tagihan).join(', ') }}</td><td class="kanan">{{ angka(p.jumlah) }}</td></tr>
          <tr><th colspan="7">Jumlah pemasukan</th><th class="kanan">{{ angka(jml(sah)) }}</th></tr></tbody>
      </table>
      <table class="tabel" style="margin-top: 8pt; width: 60%">
        <colgroup><col style="width:10%"><col style="width:60%"><col style="width:30%"></colgroup>
        <thead><tr><th>No.</th><th>Rekap per jenis biaya</th><th>Jumlah (Rp)</th></tr></thead>
        <tbody><tr v-for="(x, i) in perJenis" :key="x.jenis"><td class="tengah">{{ i + 1 }}</td><td>{{ x.jenis }}</td><td class="kanan">{{ angka(x.jumlah) }}</td></tr>
          <tr><td /><td>Tunai / transfer</td><td class="kanan">{{ angka(jml(sah.filter((p) => p.cara === 'tunai'))) }} / {{ angka(jml(sah.filter((p) => p.cara === 'transfer'))) }}</td></tr></tbody>
      </table>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan_tertulis || 'Direktur', nama: direktur.nama || '', niy: direktur.niy }"
          :kanan="{ jabatan: keu.jabatanSaya, nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" :tanggal="akhir" />
      </template>
    </DokumenCetak>
  </div>
</template>
