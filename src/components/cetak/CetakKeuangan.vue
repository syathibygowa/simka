<!-- SIMKA PRO | src/components/cetak/CetakKeuangan.vue | v1.4 | 14.13.0: tombol disederhanakan (Pratinjau, Ekspor, Impor, Cetak Rekap) | 19/10/2026 -->
<script setup>
// Dokumen keuangan santri, kertas F4 tegak, satu dokumen per halaman (dapat banyak sekaligus):
//   • KUITANSI      : kop, nomor; telah terima dari, untuk santri, tanggal, cara bayar; rincian per tagihan (tagihan,
//                     dibayar, sisa); jumlah dan terbilang; sisa seluruh tagihan; tanda tangan penyetor (kiri) dan
//                     Bendahara Pondok bertanda tangan elektronik dengan QR (kanan).
//   • SURAT TAGIHAN : kop, nomor, perihal; kepada wali; identitas santri; rincian tagihan berjalan dan tunggakan;
//                     jumlah dan terbilang; batas pembayaran; rekening lembaga; tanda tangan elektronik Bendahara.
//   • BEBAS TUNGGAKAN (14.7.0): kop, judul, nomor; identitas santri; pernyataan tidak memiliki tunggakan sampai tanggal surat;
//                     keperluan; catatan; tanda tangan "Mengetahui" Direktur (kiri) dan Bendahara bertanda tangan elektronik (kanan).
// Pembungkus sama dengan CetakSlip (cetak-saja/tampil) sehingga hanya dokumen yang dipratinjau yang tercetak.
import { ref, watch, onBeforeUnmount, computed } from 'vue'
import { PhPrinter, PhX } from '@phosphor-icons/vue'
import { useLembaga } from '@/stores/lembaga'
import { formatPanjang, formatPendek, formatJam, sekarang } from '@/lib/tanggal'
import { rupiah, terbilang, CARA_BAYAR, JENJANG } from '@/lib/keuangan'
import { svgQR, alamatCek } from '@/lib/dokumen'
import KopSurat from './KopSurat.vue'
import { namaBerkas, pasangJudul, lepasJudul, periodeBulan } from '@/lib/namaBerkas'

const lembaga = useLembaga(); lembaga.muat()
const pratinjau = defineModel('pratinjau', { type: Boolean, default: false })
const props = defineProps({
  jenis: { type: String, default: 'kuitansi' },     // 'kuitansi' | 'tagihan' | 'bebas'
  dok: { type: Array, default: () => [] },
  pengaturan: { type: Object, default: () => ({}) },
  pencetak: String,
})
const kuitansi = computed(() => props.jenis === 'kuitansi')
const bebas = computed(() => props.jenis === 'bebas')
const NAMA = { kuitansi: 'Kuitansi', tagihan: 'Surat Tagihan', bebas: 'Surat Keterangan Bebas Tunggakan' }
const direktur = computed(() => lembaga.signatories?.find((x) => /^direktur$/i.test(x.jabatan_tertulis)) || {})
const judul = computed(() => NAMA[props.jenis] + (props.dok.length === 1 ? ` ${props.dok[0].santri?.nama || ''}` : ` (${props.dok.length} santri)`))
let dipasang = false
const namaPdf = computed(() => namaBerkas(props.dok.length === 1 ? props.dok[0].santri?.nama : `${props.dok.length} santri`, NAMA[props.jenis], props.dok.length === 1 ? props.dok[0].nomor : '', periodeBulan(props.dok[0]?.tanggal)))
const skala = ref(1)
const ukur = () => { skala.value = Math.min(1, (window.innerWidth - 32) / 812) }
const esc = (e) => e.key === 'Escape' && (pratinjau.value = false)
watch(pratinjau, (v) => {
  document.body.style.overflow = v ? 'hidden' : ''
  if (v) { ukur(); addEventListener('resize', ukur); addEventListener('keydown', esc); pasangJudul(namaPdf.value); dipasang = true } else { removeEventListener('resize', ukur); removeEventListener('keydown', esc); if (dipasang) { lepasJudul(); dipasang = false } }
}, { immediate: true })
onBeforeUnmount(() => { document.body.style.overflow = ''; removeEventListener('resize', ukur); removeEventListener('keydown', esc); if (dipasang) lepasJudul() })
const cetak = () => window.print()

const angka = (n) => Math.round(Number(n) || 0).toLocaleString('id-ID')
const waktuEl = (w) => (w ? `${formatPendek(w)} ${formatJam(w)} WITA` : '')
const qr = (kode) => (kode ? svgQR(alamatCek(kode)) : '')
const kota = computed(() => lembaga.identitas?.kota_surat || 'Gowa')
const dicetak = computed(() => { const s = sekarang(); return `Dicetak melalui SIMKA PRO pada ${formatPanjang(s)} pukul ${formatJam(s)} WITA${props.pencetak ? ' oleh ' + props.pencetak : ''}.` })
const kelas = (s) => [s?.kelas, JENJANG[s?.jenjang]].filter(Boolean).join(' · ') || '–'
const HUB = { ayah: 'Ayah', ibu: 'Ibu', wali: 'Wali' }
const rekening = computed(() => props.pengaturan?.rekening || [])
const batal = (d) => d.status === 'batal' || d.status === 'dicabut'
</script>
<template>
  <Teleport to="body">
    <div :class="['cetak-saja', pratinjau && 'tampil munculan']" :role="pratinjau ? 'dialog' : undefined" :aria-modal="pratinjau || undefined" :aria-label="pratinjau ? 'Pratinjau ' + judul : undefined">
      <div v-if="pratinjau" class="bilah-munculan layar-saja">
        <div class="min-w-0 flex-1"><p class="truncate font-bold">Pratinjau: {{ judul }}</p><p class="text-xs opacity-80">Kertas F4 215 × 330 mm, margin 2 cm, satu dokumen per halaman</p></div>
        <button type="button" class="tombol-cetak" @click="cetak"><PhPrinter :size="20" weight="duotone" /> Cetak</button>
        <button type="button" class="tombol-tutup" @click="pratinjau = false" aria-label="Tutup pratinjau"><PhX :size="22" /></button>
      </div>
      <div :class="pratinjau && 'gulir-munculan'">
        <article v-for="d in dok" :key="d.id" class="dok lembar-f4 dok-keuangan" :style="pratinjau ? { zoom: skala } : null">
          <div v-if="batal(d)" class="cap-batal" aria-hidden="true">{{ kuitansi ? 'DIBATALKAN' : 'DICABUT' }}</div>
          <KopSurat :kop="lembaga.kop('pondok')" kode="pondok" />

          <!-- ================= KUITANSI ================= -->
          <template v-if="kuitansi">
            <h1 class="judul-dok">Kuitansi</h1>
            <p class="subjudul-dok">Nomor {{ d.nomor || '–' }}</p>
            <table class="meta-dok identitas">
              <tbody>
                <tr><td>Telah terima dari</td><td>: {{ d.penyetor || (d.santri?.wali ? `${d.santri.wali.nama} (${HUB[d.santri.wali.hubungan] || 'wali'})` : 'Orang tua/wali santri') }}</td></tr>
                <tr><td>Untuk pembayaran santri</td><td>: {{ d.santri?.nama }} · NIS {{ d.santri?.nis }} · {{ kelas(d.santri) }}</td></tr>
                <tr><td>Tanggal pembayaran</td><td>: {{ formatPanjang(d.tanggal) }}</td></tr>
                <tr><td>Cara pembayaran</td><td>: {{ CARA_BAYAR[d.cara] }}{{ d.rekening_tujuan ? ' ke ' + d.rekening_tujuan : '' }}</td></tr>
                <tr v-if="d.keterangan"><td>Keterangan</td><td>: {{ d.keterangan }}</td></tr>
              </tbody>
            </table>
            <table class="tabel">
              <colgroup><col style="width:7%"><col style="width:45%"><col style="width:16%"><col style="width:16%"><col style="width:16%"></colgroup>
              <thead><tr><th>No.</th><th>Pembayaran</th><th>Tagihan (Rp)</th><th>Dibayar (Rp)</th><th>Sisa (Rp)</th></tr></thead>
              <tbody>
                <tr v-for="(r, i) in d.rincian" :key="i"><td class="tengah">{{ i + 1 }}</td><td>{{ r.tagihan }}</td><td class="kanan">{{ angka(r.nominal) }}</td>
                  <td class="kanan">{{ angka(r.jumlah) }}</td><td class="kanan">{{ Number(r.sisa) ? angka(r.sisa) : 'Lunas' }}</td></tr>
              </tbody>
            </table>
            <table class="tabel jumlah-dok" style="margin-top: 6pt">
              <colgroup><col style="width:68%"><col style="width:32%"></colgroup>
              <tbody>
                <tr><th style="text-align: left">JUMLAH DITERIMA</th><th style="text-align: right">{{ rupiah(d.jumlah) }}</th></tr>
                <tr><td colspan="2"><i>Terbilang: {{ terbilang(d.jumlah) }}</i></td></tr>
              </tbody>
            </table>
            <p class="catatan-cetak" style="margin-top: 4pt">Sisa seluruh tagihan ananda setelah pembayaran ini: <b>{{ Number(d.sisa_total) ? rupiah(d.sisa_total) : 'tidak ada (lunas)' }}</b>.</p>
            <p v-if="batal(d)" class="catatan-cetak" style="margin-top: 4pt">Pembayaran ini telah DIBATALKAN: {{ d.alasan_batal }}.</p>
            <p v-if="pengaturan.catatan_kuitansi" class="catatan-cetak" style="margin-top: 4pt">{{ pengaturan.catatan_kuitansi }}</p>
            <section class="ttd-keu">
              <div><p>&nbsp;</p><p>Penyetor,</p><div class="ruang" /><p class="nama">{{ d.penyetor || d.santri?.wali?.nama || '.................................' }}</p></div>
              <div>
                <p>{{ kota }}, {{ formatPanjang(d.tanggal) }}</p><p>Yang menerima,</p><p>{{ d.ttd?.jabatan || 'Bendahara Pondok' }}</p>
                <div class="ruang"><div v-if="d.kode_validasi && !batal(d)" class="ttd-qr"><span class="qr" v-html="qr(d.kode_validasi)" />
                  <span class="ket">Ditandatangani secara elektronik<br>{{ waktuEl(d.ttd?.waktu) }}</span></div></div>
                <p class="nama">{{ d.ttd?.nama || '' }}</p><p v-if="d.ttd?.niy">NIY. {{ d.ttd.niy }}</p>
              </div>
            </section>
          </template>

          <!-- ================= BEBAS TUNGGAKAN (14.7.0) ================= -->
          <template v-else-if="bebas">
            <h1 class="judul-dok">Surat Keterangan Bebas Tunggakan</h1>
            <p class="subjudul-dok">Nomor {{ d.nomor || '–' }}</p>
            <p class="rata" style="margin-top: 10pt">Yang bertanda tangan di bawah ini, {{ d.ttd?.nama || '…' }}, {{ d.ttd?.jabatan || 'Bendahara Pondok' }}, atas nama {{ lembaga.identitas?.nama_lengkap || 'pondok' }}, menerangkan bahwa:</p>
            <table class="meta-dok identitas" style="margin: 6pt 0 6pt 12pt">
              <tbody>
                <tr><td>Nama santri</td><td>: <b>{{ d.santri?.nama }}</b></td></tr>
                <tr><td>NIS</td><td>: {{ d.santri?.nis }}</td></tr>
                <tr><td>Kelas/jenjang</td><td>: {{ kelas(d.santri) }}</td></tr>
                <tr><td>Orang tua/wali</td><td>: {{ d.santri?.wali?.nama || '–' }}</td></tr>
              </tbody>
            </table>
            <p class="rata">berdasarkan catatan keuangan santri sampai dengan tanggal surat ini, <b>tidak memiliki tunggakan</b> pembayaran kepada pondok
              ({{ d.ringkasan?.lunas?.tagihan || 0 }} tagihan telah lunas dengan jumlah {{ rupiah(d.ringkasan?.lunas?.jumlah || 0) }}).</p>
            <p class="rata" style="margin-top: 6pt">Surat keterangan ini diberikan untuk keperluan <b>{{ d.keperluan }}</b>.</p>
            <p v-if="d.ringkasan?.mendatang?.length" class="rata" style="margin-top: 6pt">Catatan: terdapat tagihan yang ditagihkan sesudah tanggal surat ini, yaitu
              {{ d.ringkasan.mendatang.map((b) => `${b.tagihan} (${rupiah(b.sisa)})`).join(', ') }}.</p>
            <p v-if="pengaturan.catatan_bebas" class="rata" style="margin-top: 6pt">{{ pengaturan.catatan_bebas }}</p>
            <p class="rata" style="margin-top: 6pt">Demikian surat keterangan ini dibuat dengan sebenarnya untuk dipergunakan sebagaimana mestinya.</p>
            <section class="ttd-keu">
              <div><p>&nbsp;</p><p>Mengetahui,</p><p>{{ direktur.jabatan_tertulis || 'Direktur' }}</p><div class="ruang" /><p class="nama">{{ direktur.nama || '.................................' }}</p><p v-if="direktur.niy">NIY. {{ direktur.niy }}</p></div>
              <div>
                <p>{{ kota }}, {{ formatPanjang(d.tanggal) }}</p><p>&nbsp;</p><p>{{ d.ttd?.jabatan || 'Bendahara Pondok' }}</p>
                <div class="ruang"><div v-if="d.kode_validasi && !batal(d)" class="ttd-qr"><span class="qr" v-html="qr(d.kode_validasi)" />
                  <span class="ket">Ditandatangani secara elektronik<br>{{ waktuEl(d.ttd?.waktu) }}</span></div></div>
                <p class="nama">{{ d.ttd?.nama || '' }}</p><p v-if="d.ttd?.niy">NIY. {{ d.ttd.niy }}</p>
              </div>
            </section>
          </template>

          <!-- ================= SURAT TAGIHAN ================= -->
          <template v-else>
            <table class="meta-dok kepala-surat">
              <tbody>
                <tr><td>Nomor</td><td>: {{ d.nomor || '–' }}</td><td class="kanan-surat">{{ kota }}, {{ formatPanjang(d.tanggal) }}</td></tr>
                <tr><td>Lampiran</td><td>: –</td><td></td></tr>
                <tr><td>Perihal</td><td>: <b>Tagihan Pembayaran Santri</b></td><td></td></tr>
              </tbody>
            </table>
            <p style="margin-top: 10pt">Kepada Yth.<br>Bapak/Ibu {{ d.santri?.wali?.nama || '.................................' }}<br>Orang tua/wali ananda {{ d.santri?.nama }}<br>di tempat</p>
            <p style="margin-top: 8pt"><i>Assalamu'alaikum warahmatullahi wabarakatuh.</i></p>
            <p class="rata">Bersama surat ini kami sampaikan rincian tagihan pembayaran ananda yang belum diselesaikan sampai dengan tanggal surat ini:</p>
            <table class="meta-dok identitas" style="margin: 4pt 0 6pt">
              <tbody>
                <tr><td>Nama santri</td><td>: {{ d.santri?.nama }}</td></tr>
                <tr><td>NIS</td><td>: {{ d.santri?.nis }}</td></tr>
                <tr><td>Kelas/jenjang</td><td>: {{ kelas(d.santri) }}</td></tr>
              </tbody>
            </table>
            <table class="tabel">
              <colgroup><col style="width:7%"><col style="width:37%"><col style="width:17%"><col style="width:13%"><col style="width:13%"><col style="width:13%"></colgroup>
              <thead><tr><th>No.</th><th>Tagihan</th><th>Jatuh tempo</th><th>Nominal (Rp)</th><th>Dibayar (Rp)</th><th>Sisa (Rp)</th></tr></thead>
              <tbody>
                <tr v-for="(r, i) in d.rincian" :key="i"><td class="tengah">{{ i + 1 }}</td><td>{{ r.tagihan }}{{ r.lewat ? ' *' : '' }}</td><td class="tengah">{{ formatPendek(r.jatuh_tempo) }}</td>
                  <td class="kanan">{{ angka(r.nominal) }}</td><td class="kanan">{{ angka(r.dibayar) }}</td><td class="kanan">{{ angka(r.sisa) }}</td></tr>
              </tbody>
            </table>
            <table class="tabel jumlah-dok" style="margin-top: 6pt">
              <colgroup><col style="width:68%"><col style="width:32%"></colgroup>
              <tbody>
                <tr><th style="text-align: left">JUMLAH TAGIHAN</th><th style="text-align: right">{{ rupiah(d.total) }}</th></tr>
                <tr><td colspan="2"><i>Terbilang: {{ terbilang(d.total) }}</i></td></tr>
              </tbody>
            </table>
            <p v-if="d.rincian?.some((r) => r.lewat)" class="catatan-cetak" style="margin-top: 3pt">* telah melewati jatuh tempo.</p>
            <p class="rata" style="margin-top: 6pt">Kami mohon tagihan tersebut dibayarkan paling lambat <b>{{ formatPanjang(d.batas_bayar) }}</b>, secara tunai kepada Bendahara Pondok atau melalui transfer ke rekening berikut:</p>
            <table class="tabel rekening" style="margin-top: 4pt">
              <colgroup><col style="width:7%"><col style="width:25%"><col style="width:30%"><col style="width:38%"></colgroup>
              <thead><tr><th>No.</th><th>Bank</th><th>Nomor rekening</th><th>Atas nama</th></tr></thead>
              <tbody>
                <tr v-for="(r, i) in rekening" :key="i"><td class="tengah">{{ i + 1 }}</td><td>{{ r.bank }}</td><td>{{ r.nomor }}</td><td>{{ r.atas_nama }}</td></tr>
                <tr v-if="!rekening.length"><td class="tengah">–</td><td colspan="3">Rekening lembaga belum diatur; pembayaran tunai kepada Bendahara Pondok.</td></tr>
              </tbody>
            </table>
            <p v-if="d.catatan" class="rata" style="margin-top: 6pt">{{ d.catatan }}</p>
            <p v-if="pengaturan.catatan_tagihan" class="rata" style="margin-top: 6pt">{{ pengaturan.catatan_tagihan }}</p>
            <p class="rata" style="margin-top: 6pt">Atas perhatian dan kerja sama Bapak/Ibu, kami ucapkan <i>jazakumullahu khairan</i>.</p>
            <p><i>Wassalamu'alaikum warahmatullahi wabarakatuh.</i></p>
            <section class="ttd-keu">
              <div />
              <div>
                <p>{{ kota }}, {{ formatPanjang(d.tanggal) }}</p><p>{{ d.ttd?.jabatan || 'Bendahara Pondok' }}</p>
                <div class="ruang"><div v-if="d.kode_validasi && !batal(d)" class="ttd-qr"><span class="qr" v-html="qr(d.kode_validasi)" />
                  <span class="ket">Ditandatangani secara elektronik<br>{{ waktuEl(d.ttd?.waktu) }}</span></div></div>
                <p class="nama">{{ d.ttd?.nama || '' }}</p><p v-if="d.ttd?.niy">NIY. {{ d.ttd.niy }}</p>
              </div>
            </section>
          </template>

          <p v-if="lembaga.catatanCetak" class="catatan-cetak">{{ dicetak }}</p>
          <p v-if="d.kode_validasi" class="catatan-keu">{{ kuitansi ? 'Kuitansi' : bebas ? 'Surat keterangan' : 'Surat tagihan' }} ini ditandatangani secara elektronik melalui SIMKA PRO. Keaslian dapat diperiksa dengan memindai QR
            atau membuka halaman Cek Keabsahan Dokumen dan memasukkan kode validasi <b>{{ d.kode_validasi }}</b>.</p>
        </article>
      </div>
    </div>
  </Teleport>
</template>
<style>
.dok.dok-keuangan { display: flex; flex-direction: column; position: relative; }
.dok.dok-keuangan .identitas td { padding: 1pt 6pt 1pt 0; vertical-align: top; }
.dok.dok-keuangan .identitas td:first-child { white-space: nowrap; width: 1%; }
.dok.dok-keuangan .kepala-surat td { padding: 0 6pt 0 0; vertical-align: top; }
.dok.dok-keuangan .kepala-surat td:first-child { white-space: nowrap; width: 1%; }
.dok.dok-keuangan .kepala-surat .kanan-surat { text-align: right; white-space: nowrap; }
.dok.dok-keuangan .rata { text-align: justify; }
.dok.dok-keuangan p { margin: 0; }
.dok.dok-keuangan table.tabel { font-size: 10pt; }
.dok.dok-keuangan table.tabel.jumlah-dok th { font-size: 11pt; }
.dok.dok-keuangan .ttd-keu { display: grid; grid-template-columns: 1fr 1fr; gap: 8mm; margin-top: 12pt; text-align: center; break-inside: avoid; }
.dok.dok-keuangan .ttd-keu .ruang { height: 21mm; display: flex; align-items: center; justify-content: center; }
.dok.dok-keuangan .ttd-keu .nama { text-decoration: underline; }
.dok.dok-keuangan .ttd-qr { display: flex; align-items: center; gap: 2mm; text-align: left; }
.dok.dok-keuangan .ttd-qr .qr { display: block; width: 18mm; height: 18mm; flex-shrink: 0; }
.dok.dok-keuangan .ttd-qr .qr svg { width: 100%; height: 100%; display: block; }
.dok.dok-keuangan .ttd-qr .ket { font-size: 7pt; line-height: 1.25; font-style: italic; }
.dok.dok-keuangan .catatan-keu { margin-top: auto; padding-top: 4pt; border-top: 0.5pt solid #777; font-size: 8.5pt; line-height: 1.35; text-align: justify; }
.dok.dok-keuangan .cap-batal { position: absolute; top: 120mm; left: 50%; transform: translateX(-50%) rotate(-20deg); font-size: 46pt; font-weight: 800;
  color: rgba(199, 51, 47, 0.28); border: 4pt solid rgba(199, 51, 47, 0.28); padding: 2mm 8mm; letter-spacing: 4pt; pointer-events: none; }
@media screen { .munculan .dok.dok-keuangan { min-height: 330mm; margin-bottom: 16px; } }
@media print { .dok.dok-keuangan { min-height: 284mm; break-after: page; } .dok.dok-keuangan:last-child { break-after: auto; } }
</style>
