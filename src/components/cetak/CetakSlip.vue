<!-- SIMKA PRO | src/components/cetak/CetakSlip.vue | v1.1 | Perbaikan: catatan cetak dapat dinonaktifkan di Pengaturan | 14/10/2026 -->
<script setup>
// Slip gaji F4 tegak: kop, judul SLIP GAJI, periode dan nomor; identitas (NIY, nama, jabatan, unit, status, masa kerja,
// pendidikan, rekening); pendapatan dan potongan dengan subtotal; jumlah diterima beserta terbilang; tanda tangan
// sejajar dalam satu baris: ["Mengetahui" Direktur bila ikut menandatangani] · Bendahara (elektronik, QR) · pegawai penerima di kanan.
// Banyak slip dicetak sekaligus: setiap slip satu halaman dengan kop dan kode validasinya sendiri.
// Kelas pembungkus sama dengan DokumenCetak (cetak-saja/tampil) sehingga hanya slip yang dipratinjau yang tercetak.
import { ref, watch, onBeforeUnmount, computed } from 'vue'
import { PhPrinter, PhX } from '@phosphor-icons/vue'
import { useLembaga } from '@/stores/lembaga'
import { formatPanjang, formatPendek, formatJam, sekarang } from '@/lib/tanggal'
import { namaPeriode, rupiah, terbilang } from '@/lib/gaji'
import { PENDIDIKAN, STATUS_PEGAWAI } from '@/lib/kepegawaian'
import { svgQR, alamatCek } from '@/lib/dokumen'
import KopSurat from './KopSurat.vue'

const lembaga = useLembaga(); lembaga.muat()
const pratinjau = defineModel('pratinjau', { type: Boolean, default: false })
const props = defineProps({
  slip: { type: Array, default: () => [] },   // [{ data, item, periode, ttd, nomor_slip, kode_validasi, diterima, ... }]
  pengaturan: { type: Object, default: () => ({}) },
  pencetak: String,
})
const judul = computed(() => (props.slip.length === 1 ? `Slip Gaji ${props.slip[0].data?.nama || ''}` : `Slip Gaji (${props.slip.length} pegawai)`))
const skala = ref(1)
const ukur = () => { skala.value = Math.min(1, (window.innerWidth - 32) / 812) }
const esc = (e) => e.key === 'Escape' && (pratinjau.value = false)
watch(pratinjau, (v) => {
  document.body.style.overflow = v ? 'hidden' : ''
  if (v) { ukur(); addEventListener('resize', ukur); addEventListener('keydown', esc) } else { removeEventListener('resize', ukur); removeEventListener('keydown', esc) }
}, { immediate: true })
onBeforeUnmount(() => { document.body.style.overflow = ''; removeEventListener('resize', ukur); removeEventListener('keydown', esc) })
const cetak = () => window.print()

const pend = (s) => (s.item || []).filter((i) => i.jenis === 'pendapatan' && Number(i.besaran) !== 0)
const pot = (s) => (s.item || []).filter((i) => i.jenis === 'potongan' && Number(i.besaran) !== 0)
const jumlah = (d) => d.reduce((a, i) => a + Number(i.besaran), 0)
const jabatan = (d) => [d.jabatan_struktural, ...(d.jabatan_fungsional || [])].filter(Boolean).join(', ') || '–'
const rekening = (r) => (r?.cara_bayar === 'transfer' ? `${r.bank} ${r.nomor_rekening} a.n. ${r.atas_nama}` : r?.cara_bayar === 'tunai' ? 'Tunai' : '–')
const ttd = (s, peran) => (s.ttd || []).find((t) => t.peran === peran && t.status === 'ditandatangani')
const waktuEl = (w) => (w ? `${formatPendek(w)} ${formatJam(w)} WITA` : '')
const qr = (kode) => (kode ? svgQR(alamatCek(kode)) : '')
const kota = computed(() => lembaga.identitas?.kota_surat || 'Gowa')
const dicetak = computed(() => { const s = sekarang(); return `Dicetak melalui SIMKA PRO pada ${formatPanjang(s)} pukul ${formatJam(s)} WITA${props.pencetak ? ' oleh ' + props.pencetak : ''}.` })
const keterangan = (i) => (i.kategori === 'honor' && i.jumlah != null ? `${Number(i.jumlah)} jam × ${rupiah(i.tarif)}`
  : i.kategori === 'potongan_kehadiran' && i.rincian ? `${i.rincian.tanpa} dari ${i.rincian.wajib} ${i.rincian.satuan || 'sesi'}` : '')
</script>
<template>
  <Teleport to="body">
    <div :class="['cetak-saja', pratinjau && 'tampil munculan']" :role="pratinjau ? 'dialog' : undefined" :aria-modal="pratinjau || undefined" :aria-label="pratinjau ? 'Pratinjau cetak ' + judul : undefined">
      <div v-if="pratinjau" class="bilah-munculan layar-saja">
        <div class="min-w-0 flex-1"><p class="truncate font-bold">Pratinjau cetak: {{ judul }}</p><p class="text-xs opacity-80">Kertas F4 215 × 330 mm, margin 2 cm, satu slip per halaman</p></div>
        <button type="button" class="tombol-cetak" @click="cetak"><PhPrinter :size="20" weight="duotone" /> Cetak</button>
        <button type="button" class="tombol-tutup" @click="pratinjau = false" aria-label="Tutup pratinjau"><PhX :size="22" /></button>
      </div>
      <div :class="pratinjau && 'gulir-munculan'">
        <article v-for="s in slip" :key="s.id" class="dok lembar-f4 slip-gaji" :style="pratinjau ? { zoom: skala } : null">
          <KopSurat :kop="lembaga.kop('pondok')" kode="pondok" />
          <h1 class="judul-dok">Slip Gaji</h1>
          <p class="subjudul-dok">Periode {{ namaPeriode(s.periode) }}<template v-if="s.nomor_slip"> · Nomor {{ s.nomor_slip }}</template></p>
          <table class="meta-dok identitas">
            <tbody>
              <tr><td>NIY</td><td>: {{ s.data.niy || '–' }}</td><td>Status kepegawaian</td><td>: {{ STATUS_PEGAWAI[s.data.status] || '–' }}</td></tr>
              <tr><td>Nama</td><td>: {{ s.data.nama }}</td><td>Masa kerja</td><td>: {{ s.data.tmt ? `${s.data.masa_kerja_tahun} tahun ${s.data.masa_kerja_bulan} bulan` : '–' }}</td></tr>
              <tr><td>Jabatan</td><td>: {{ jabatan(s.data) }}</td><td>Pendidikan</td><td>: {{ PENDIDIKAN[s.data.pendidikan] || '–' }}</td></tr>
              <tr><td>Bidang/unit</td><td>: {{ s.data.unit || '–' }}</td><td>Dibayar</td><td>: {{ formatPanjang(s.periode?.tanggal_bayar) }}</td></tr>
              <tr><td>Rekening</td><td colspan="3">: {{ rekening(s.data.rekening) }}</td></tr>
            </tbody>
          </table>
          <table class="tabel">
            <colgroup><col style="width:7%"><col style="width:53%"><col style="width:20%"><col style="width:20%"></colgroup>
            <thead><tr><th>No.</th><th>Pendapatan</th><th>Keterangan</th><th>Jumlah (Rp)</th></tr></thead>
            <tbody>
              <tr v-for="(i, n) in pend(s)" :key="'p' + n"><td class="tengah">{{ n + 1 }}</td><td>{{ i.label }}</td><td>{{ keterangan(i) }}</td>
                <td class="kanan">{{ Number(i.besaran) < 0 ? '−' : '' }}{{ Math.abs(Number(i.besaran)).toLocaleString('id-ID') }}</td></tr>
              <tr><td></td><td colspan="2">Jumlah pendapatan</td><td class="kanan">{{ jumlah(pend(s)).toLocaleString('id-ID') }}</td></tr>
            </tbody>
          </table>
          <table class="tabel" style="margin-top: 6pt">
            <colgroup><col style="width:7%"><col style="width:53%"><col style="width:20%"><col style="width:20%"></colgroup>
            <thead><tr><th>No.</th><th>Potongan</th><th>Keterangan</th><th>Jumlah (Rp)</th></tr></thead>
            <tbody>
              <tr v-for="(i, n) in pot(s)" :key="'k' + n"><td class="tengah">{{ n + 1 }}</td><td>{{ i.label }}</td><td>{{ keterangan(i) }}</td><td class="kanan">{{ Number(i.besaran).toLocaleString('id-ID') }}</td></tr>
              <tr v-if="!pot(s).length"><td class="tengah">–</td><td>Tidak ada potongan</td><td></td><td class="kanan">0</td></tr>
              <tr><td></td><td colspan="2">Jumlah potongan</td><td class="kanan">{{ jumlah(pot(s)).toLocaleString('id-ID') }}</td></tr>
            </tbody>
          </table>
          <table class="tabel diterima" style="margin-top: 6pt">
            <colgroup><col style="width:80%"><col style="width:20%"></colgroup>
            <tbody>
              <tr><th style="text-align: left">JUMLAH DITERIMA</th><th style="text-align: right">{{ Number(s.diterima).toLocaleString('id-ID') }}</th></tr>
              <tr><td colspan="2"><i>Terbilang: {{ terbilang(s.diterima) }}</i></td></tr>
            </tbody>
          </table>
          <p v-if="s.revisi_ke > 0" class="catatan-cetak" style="margin-top: 4pt">Slip revisi ke-{{ s.revisi_ke }}; menggantikan slip sebelumnya untuk periode yang sama.</p>
          <p v-if="pengaturan.catatan_slip" class="catatan-cetak" style="margin-top: 4pt">{{ pengaturan.catatan_slip }}</p>

          <!-- Tanda tangan sejajar: [Direktur "Mengetahui"] · Bendahara · pegawai penerima -->
          <section :class="['ttd-slip', ttd(s, 'direktur') ? 'tiga' : 'dua']">
            <div v-if="ttd(s, 'direktur')">
              <p>Mengetahui,</p><p>{{ ttd(s, 'direktur').jabatan || 'Direktur' }}</p>
              <div class="ruang"><div v-if="s.kode_validasi" class="ttd-qr"><span class="qr" v-html="qr(s.kode_validasi)" />
                <span class="ket">Ditandatangani secara elektronik<br>{{ waktuEl(ttd(s, 'direktur').waktu) }}</span></div></div>
              <p class="nama">{{ ttd(s, 'direktur').nama }}</p><p v-if="ttd(s, 'direktur').niy">NIY. {{ ttd(s, 'direktur').niy }}</p>
            </div>
            <div>
              <p>Yang menyerahkan,</p><p>Bendahara</p>
              <div class="ruang"><div v-if="ttd(s, 'bendahara') && s.kode_validasi" class="ttd-qr"><span class="qr" v-html="qr(s.kode_validasi)" />
                <span class="ket">Ditandatangani secara elektronik<br>{{ waktuEl(ttd(s, 'bendahara').waktu) }}</span></div></div>
              <p class="nama">{{ ttd(s, 'bendahara')?.nama || '' }}</p><p v-if="ttd(s, 'bendahara')?.niy">NIY. {{ ttd(s, 'bendahara').niy }}</p>
            </div>
            <div>
              <p>{{ kota }}, {{ formatPanjang(s.periode?.tanggal_bayar || sekarang()) }}</p><p>Yang menerima,</p>
              <div class="ruang" />
              <p class="nama">{{ s.data.nama }}</p><p v-if="s.data.niy">NIY. {{ s.data.niy }}</p>
            </div>
          </section>
          <p v-if="lembaga.catatanCetak" class="catatan-cetak">{{ dicetak }}</p>
          <p v-if="s.kode_validasi" class="catatan-slip">Slip ini ditandatangani secara elektronik melalui SIMKA PRO. Keaslian dapat diperiksa dengan memindai QR
            atau membuka halaman Cek Keabsahan Dokumen dan memasukkan kode validasi <b>{{ s.kode_validasi }}</b>. Dokumen bersifat rahasia.</p>
          <p v-else class="catatan-slip">DRAF – slip belum diterbitkan dan belum ditandatangani.</p>
        </article>
      </div>
    </div>
  </Teleport>
</template>
<style>
.dok.slip-gaji { display: flex; flex-direction: column; }
.dok.slip-gaji .identitas td { padding: 1pt 6pt 1pt 0; vertical-align: top; }
.dok.slip-gaji .identitas td:nth-child(1), .dok.slip-gaji .identitas td:nth-child(3) { white-space: nowrap; }
.dok.slip-gaji table.tabel.diterima th { font-size: 11pt; }
.dok.slip-gaji table.tabel { font-size: 9.5pt; }
.dok.slip-gaji table.tabel th, .dok.slip-gaji table.tabel td { padding-top: 1.5pt; padding-bottom: 1.5pt; }
.dok.slip-gaji .ttd-slip { display: grid; gap: 6mm; margin-top: 10pt; text-align: center; break-inside: avoid; }
.dok.slip-gaji .ttd-slip.dua { grid-template-columns: 1fr 1fr; }
.dok.slip-gaji .ttd-slip.tiga { grid-template-columns: 1fr 1fr 1fr; gap: 3mm; font-size: 10pt; }
.dok.slip-gaji .ttd-slip p { margin: 0; }
.dok.slip-gaji .ttd-slip .ruang { height: 21mm; display: flex; align-items: center; justify-content: center; }
.dok.slip-gaji .ttd-slip .nama { text-decoration: underline; }
.dok.slip-gaji .ttd-slip .ttd-qr { display: flex; align-items: center; gap: 2mm; text-align: left; }
.dok.slip-gaji .ttd-slip .ttd-qr .qr { display: block; width: 18mm; height: 18mm; flex-shrink: 0; }
.dok.slip-gaji .ttd-slip .ttd-qr .qr svg { width: 100%; height: 100%; display: block; }
.dok.slip-gaji .ttd-slip .ttd-qr .ket { font-size: 7pt; line-height: 1.25; font-style: italic; }
.dok.slip-gaji .catatan-slip { margin-top: auto; padding-top: 4pt; border-top: 0.5pt solid #777; font-size: 8.5pt; line-height: 1.35; text-align: justify; }
@media screen { .munculan .dok.slip-gaji { min-height: 330mm; margin-bottom: 16px; } .munculan .dok.slip-gaji .catatan-slip { margin-top: auto; } }
@media print { .dok.slip-gaji { min-height: 284mm; break-after: page; } .dok.slip-gaji:last-child { break-after: auto; } }
</style>
