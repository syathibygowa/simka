<!-- SIMKA PRO | src/components/cetak/SuratResmi.vue | v1.6 | 14.1.0: kolom tanda tangan penerima (pegawai) di kanan, pimpinan di kiri | 17/10/2026 -->
<script setup>
// Isi surat keluar resmi di dalam DokumenCetak (kop dari DokumenCetak): kepala surat (judul di tengah, atau nomor/lampiran/hal
// di kiri dengan tempat-tanggal di kanan dan alamat tujuan), basmalah/salam/hamdalah/doa (Latin, miring), isi dari template,
// tempat dan tanggal ganda (Hijriah bergaris bawah, Masehi tepat di bawahnya rata kanan), satu atau dua penanda tangan (QR bila ditandatangani elektronik), tembusan,
// narahubung, dan catatan validasi (di kaki halaman). surat = data surat; ttd = baris tanda tangan registri (bila sudah diajukan).
// 14.1.0: opsi "penerima" (mis. Surat Teguran) menambah kolom "Yang menerima" berisi pegawai pada isian jenis pegawai, di KANAN;
// penanda tangan pimpinan pindah ke KIRI. diterima = waktu pegawai menyatakan menerima secara elektronik.
import { computed } from 'vue'
import { LAFAZ, susunKonteks, renderIsi, renderBaris } from '@/lib/suratKeluar'
import { formatPanjang, formatPendek, formatJam } from '@/lib/tanggal'
import { svgQR, alamatCek } from '@/lib/dokumen'
import CatatanValidasi from './CatatanValidasi.vue'

const props = defineProps({
  surat: { type: Object, required: true },   // { tampilan, nilai, perihal, kepada, lampiran, tembusan, narahubung, tanggal_surat, tanggal_hijriah, nomor, penanda }
  lembaga: { type: Object, default: () => ({}) }, // konteks_surat()
  ttd: { type: Array, default: () => [] },   // document_signatures
  kode: { type: String, default: '' },
  statusDokumen: { type: String, default: '' },
  mode: { type: String, default: 'pratinjau' }, // pratinjau | final
  diterima: { type: String, default: '' },      // waktu penerima menyatakan menerima (Surat Teguran)
})
const t = computed(() => props.surat.tampilan || {})
const opsi = computed(() => t.value.opsi || {})
const penanda = computed(() => (props.surat.penanda || []).map((p, i) => {
  const s = props.ttd.find((x) => x.urutan === i + 1) || props.ttd.find((x) => x.posisi === p.posisi && x.nama === p.nama)
  return { ...p, status: s?.status, waktu: s?.waktu, basah: s?.catatan === 'basah' }
}))
const ktx = computed(() => susunKonteks({ nilai: props.surat.nilai, isian: t.value.isian, lembaga: props.lembaga, kop_kode: props.surat.kop_kode, penanda: penanda.value,
  tanggal_surat: props.surat.tanggal_surat, tanggal_hijriah: props.surat.tanggal_hijriah, nomor: props.surat.nomor, perihal: props.surat.perihal }))
const isiHtml = computed(() => renderIsi(t.value.isi, ktx.value, props.mode))
const judulHtml = computed(() => renderBaris(t.value.judul, ktx.value, props.mode))
const subjudulHtml = computed(() => renderBaris(t.value.subjudul, ktx.value, props.mode))
const nomor = computed(() => props.surat.nomor || (props.mode === 'final' ? '' : '…/…/…/…/…'))
const kota = computed(() => props.lembaga?.kota || 'Gowa')
// Tanggal ganda: "Gowa, 17 Jumadil Awal 1446" bergaris bawah, lalu "19 November 2024" di bawah tanggal Hijriah (bukan sejajar nama kota)
const hijri = computed(() => String(props.surat.tanggal_hijriah || '').replace(/\s*H\.?$/, '').trim())
const masehi = computed(() => (props.surat.tanggal_surat ? formatPanjang(props.surat.tanggal_surat) : ''))
const kepada = computed(() => String(props.surat.kepada || '').split('\n').map((x) => x.trim()).filter(Boolean))
const tembusan = computed(() => (props.surat.tembusan || []).filter((x) => String(x).trim()))
const draf = computed(() => props.statusDokumen === 'draf' || (!props.kode && props.mode !== 'final'))
const qr = (p) => (props.kode && p.status === 'ditandatangani' && !p.basah ? svgQR(alamatCek(props.kode)) : '')
const waktuEl = (p) => (p.waktu ? `${formatPendek(p.waktu)} ${formatJam(p.waktu)} WITA` : '')
// Penerima: pegawai pada isian jenis pegawai pertama (opsi.penerima)
const penerima = computed(() => {
  if (!opsi.value.penerima) return null
  const i = (t.value.isian || []).find((x) => x.jenis === 'pegawai')
  const v = i ? (props.surat.nilai || {})[i.kunci] : null
  return { nama: v?.nama || '', niy: v?.niy || '' }
})
</script>
<template>
  <div class="surat">
    <p v-if="opsi.basmalah" class="lafaz tengah-p">{{ LAFAZ.basmalah }}</p>

    <template v-if="t.bentuk === 'tengah'">
      <h1 class="judul-surat" v-html="judulHtml" />
      <p class="nomor-surat">Nomor: {{ nomor }}</p>
      <p v-if="t.subjudul" class="subjudul-surat" v-html="subjudulHtml" />
    </template>
    <template v-else>
      <table class="kepala-kiri">
        <tr><td class="lbl">Nomor</td><td class="tt">:</td><td>{{ nomor }}</td><td class="kanan" rowspan="3">{{ kota }}, <span class="tg-ganda"><span class="tg-h">{{ hijri || masehi }}</span><span v-if="hijri && masehi" class="tg-m">{{ masehi }}</span></span></td></tr>
        <tr><td class="lbl">Lampiran</td><td class="tt">:</td><td>{{ surat.lampiran || '–' }}</td></tr>
        <tr><td class="lbl">Hal</td><td class="tt">:</td><td>{{ surat.perihal }}</td></tr>
      </table>
      <div class="tujuan">
        <p>Kepada Yth.</p>
        <p v-for="(k, i) in kepada" :key="i">{{ k }}</p>
        <p v-if="!kepada.length && mode !== 'final'"><span class="isian-kosong">[penerima surat]</span></p>
        <p>di-</p><p class="tempat">Tempat</p>
      </div>
    </template>

    <p v-if="opsi.salam" class="lafaz">{{ LAFAZ.salam }}</p>
    <p v-if="opsi.hamdalah" class="lafaz">{{ LAFAZ.hamdalah }}</p>
    <div class="isi" v-html="isiHtml" />
    <p v-if="opsi.doa" class="lafaz">{{ LAFAZ.doa }}</p>
    <p v-if="opsi.salam_penutup" class="lafaz">{{ LAFAZ.salam_penutup }}</p>

    <div class="penutup">
      <table v-if="t.bentuk === 'tengah' && opsi.ditetapkan" class="ditetapkan">
        <tr><td>Ditetapkan di</td><td class="tt">:</td><td>{{ kota }}</td></tr>
        <tr><td>Pada tanggal</td><td class="tt">:</td><td><span class="tg-ganda"><span class="tg-h">{{ hijri || masehi }}</span><span v-if="hijri && masehi" class="tg-m">{{ masehi }}</span></span></td></tr>
      </table>
      <p v-else-if="t.bentuk === 'tengah'" class="tgl-ttd">{{ kota }}, <span class="tg-ganda"><span class="tg-h">{{ hijri || masehi }}</span><span v-if="hijri && masehi" class="tg-m">{{ masehi }}</span></span></p>
      <div :class="['blok-ttd', penanda.length > 1 || opsi.pas_foto || penerima ? 'dua' : 'satu']">
        <div v-if="opsi.pas_foto" class="pas-foto">Pas foto<br>3 × 4</div>
        <div v-for="(p, i) in penanda" :key="i" class="ttd-surat">
          <p v-if="p.pengantar">{{ p.pengantar }}</p>
          <p v-if="p.an">a.n. {{ p.an }}</p>
          <p>{{ p.jabatan }}{{ penanda.length === 1 && !p.an ? ',' : '' }}</p>
          <div class="ruang-ttd">
            <div v-if="qr(p)" class="ttd-qr"><span class="qr" v-html="qr(p)" /><span class="ket">Ditandatangani secara elektronik<br>{{ waktuEl(p) }}</span></div>
          </div>
          <p class="nama-ttd">{{ p.nama || '……………………' }}</p>
          <p v-if="p.niy">NIY. {{ p.niy }}</p>
        </div>
        <div v-if="penerima" class="ttd-surat">
          <p>Yang menerima,</p>
          <div class="ruang-ttd"><span v-if="diterima" class="ket-terima">Diterima secara elektronik<br>{{ formatPendek(diterima) }} {{ formatJam(diterima) }} WITA</span></div>
          <p class="nama-ttd">{{ penerima.nama || '……………………' }}</p>
          <p v-if="penerima.niy">NIY. {{ penerima.niy }}</p>
        </div>
      </div>
    </div>

    <div v-if="(tembusan.length && opsi.tembusan) || (opsi.narahubung && surat.narahubung)" class="kaki">
      <div v-if="tembusan.length && opsi.tembusan" class="tembusan">
        <p><u>Tembusan</u>:</p>
        <ol><li v-for="(x, i) in tembusan" :key="i">{{ x }}</li></ol>
      </div>
      <p v-if="opsi.narahubung && surat.narahubung" class="tembusan">Narahubung:<br>{{ surat.narahubung }}</p>
    </div>
    <CatatanValidasi :kode="kode" :draf="draf" :basah="surat.mode_ttd === 'basah'" :status="statusDokumen" />
  </div>
</template>
<style scoped>
.surat { font-size: 11.5pt; line-height: 1.45; padding-top: 12pt; }   /* jarak kop surat dengan baris nomor/judul */
.surat p { margin: 0; }
.lafaz { font-style: italic; margin: 2pt 0 4pt !important; }

.judul-surat { text-align: center; font-size: 13pt; font-weight: 700; text-decoration: underline; margin: 6pt 0 0; line-height: 1.35; }
.nomor-surat { text-align: center; margin-bottom: 4pt !important; }
.subjudul-surat { text-align: center; font-weight: 700; margin: 2pt 0 10pt !important; }
.kepala-kiri { width: 100%; border-collapse: collapse; margin: 2pt 0 6pt; }
.kepala-kiri td { padding: 0 3pt 1pt 0; vertical-align: top; }
.kepala-kiri .lbl { width: 18mm; }
.kepala-kiri .tt, .ditetapkan .tt { width: 3mm; }
.kepala-kiri .kanan { text-align: right; white-space: nowrap; width: 40%; }
.tujuan { margin: 0 0 6pt; }
.tujuan .tempat { text-indent: 8mm; }
.isi { margin: 5pt 0; text-align: justify; }
.isi :deep(p) { margin: 0 0 5pt; }
.isi :deep(.tengah-p), .tengah-p { text-align: center; }
.isi :deep(ol), .isi :deep(ul) { margin: 0 0 7pt; padding-left: 7mm; list-style: decimal; }
.isi :deep(ol[type='a']) { list-style: lower-alpha; }
.isi :deep(ul) { list-style: disc; }
.isi :deep(li) { margin: 0 0 2pt; }
.isi :deep(table.sejajar) { border-collapse: collapse; margin: 0 0 7pt 8mm; width: calc(100% - 8mm); }
.isi :deep(table.sejajar td) { padding: 0 3pt 2pt 0; vertical-align: top; border: 0; text-align: left; }
.isi :deep(table.sejajar td.lbl) { width: 42mm; }
.isi :deep(table.sejajar td.tt) { width: 3mm; }
.isi :deep(table.sejajar ol) { margin: 0; }
.isi :deep(table.isi-tabel) { margin: 0 0 8pt; }
.isi :deep(.isian-kosong), .isian-kosong { background: #FFF1B8; color: #7A4E00; padding: 0 2px; border-radius: 2px; }
.penutup { margin-top: 6pt; break-inside: avoid; }
.ditetapkan { margin: 0 0 6pt auto; border-collapse: collapse; }
.ditetapkan td { padding: 0 3pt 0 0; vertical-align: top; }
.tgl-ttd { text-align: right; margin-bottom: 4pt !important; }
.tg-ganda { display: inline-block; vertical-align: top; text-align: right; }
.tg-h { display: block; border-bottom: 0.75pt solid currentColor; padding-bottom: 0.5pt; }
.tg-m { display: block; padding-top: 0.5pt; }
.blok-ttd { display: flex; gap: 8mm; }
.blok-ttd.satu { justify-content: flex-end; }
.blok-ttd.dua { justify-content: space-between; }
.pas-foto { width: 30mm; height: 40mm; flex-shrink: 0; align-self: flex-end; margin-left: 10mm; border: 0.5pt solid #000; display: grid; place-items: center; text-align: center; font-size: 9pt; line-height: 1.3; }
.ttd-surat { width: 46%; text-align: center; }
.ruang-ttd { height: 18mm; display: flex; align-items: center; justify-content: center; }
.nama-ttd { text-decoration: underline; }
.ttd-qr { display: flex; align-items: center; gap: 3mm; text-align: left; }
.ttd-qr .qr { display: block; width: 19mm; height: 19mm; flex-shrink: 0; }
.ttd-qr .qr :deep(svg) { width: 100%; height: 100%; }
.ttd-qr .ket { font-size: 8pt; line-height: 1.25; }
.ket-terima { font-size: 8pt; line-height: 1.25; font-style: italic; }
.tembusan { margin-top: 6pt !important; font-size: 9.5pt; line-height: 1.3; }
.kaki { display: flex; gap: 8mm; align-items: flex-start; }
.kaki > * { flex: 1; }
.tembusan ol { margin: 0; padding-left: 6mm; list-style: decimal; }
</style>
