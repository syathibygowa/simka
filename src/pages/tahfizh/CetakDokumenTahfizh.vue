<!-- SIMKA PRO | src/pages/tahfizh/CetakDokumenTahfizh.vue | v1.1 | Perbaikan: logo sertifikat dari pengaturan terkini; bawaan satu logo (pondok) | 16/10/2026 -->
<script setup>
// Cetak dokumen tahfizh F4 dari salinan beku (data) dokumen yang sudah terbit:
//   suket_juz          Surat Keterangan Ujian Kenaikan Juz — berkop pondok; tanda tangan Kepala Bidang Tahfizh (kiri) dan Penguji (kanan)
//   sertifikat_hafalan Sertifikat Hafalan (sertifikasi 5, 10, 15 … juz) — bingkai sertifikat; Kepala Bidang Tahfizh dan Penguji
//   sertifikat_tahfizh Sertifikat Tahfizhul Quran (ijazah hafalan akhir jenjang) — mengikuti format pondok; Direktur
// Tanda tangan elektronik tampil sebagai QR Cek Keabsahan; tanda tangan basah dikosongkan. Draf/dicabut diberi catatan.
import { computed, ref, onMounted } from 'vue'
import { useTahfizh } from '@/stores/tahfizh'
import { useLembaga } from '@/stores/lembaga'
import { formatPanjang, formatPendek, formatJam } from '@/lib/tanggal'
import { svgQR, alamatCek } from '@/lib/dokumen'
import { alamatAset } from '@/lib/penyimpanan'
import { ringkasJuz } from '@/lib/tahfizh'
import { PENGATURAN_SERTIFIKAT, miring } from '@/lib/dokumenTahfizh'
import logoLokal from '@/assets/logo-pondok.png'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import CatatanValidasi from '@/components/cetak/CatatanValidasi.vue'
import LembarRapor from '@/components/cetak/rapor/LembarRapor.vue'
import HalRapor from '@/components/cetak/rapor/HalRapor.vue'

const pratinjau = defineModel('pratinjau', { type: Boolean, default: false })
const props = defineProps({ dok: { type: Object, required: true } })
const lembaga = useLembaga(); lembaga.muat()
const d = computed(() => props.dok.data || {})
const ttd = computed(() => (props.dok.ttd?.length ? props.dok.ttd : d.value.penanda || []))
const status = computed(() => (props.dok.status === 'dicabut' ? 'dicabut' : props.dok.status_dokumen || ''))
const draf = computed(() => status.value === 'draf')
const basah = computed(() => props.dok.mode_ttd === 'basah')
const sisi = (t) => ({ pengantar: t?.pengantar || (t?.urutan === 1 && props.dok.jenis !== 'sertifikat_tahfizh' ? 'Mengetahui,' : ''), jabatan: t?.jabatan, nama: t?.nama, niy: t?.niy,
  kode: t?.status === 'ditandatangani' && !t?.basah && !basah.value && props.dok.kode ? props.dok.kode : '', waktu: t?.waktu })
const qr = (t) => (sisi(t).kode ? svgQR(alamatCek(props.dok.kode)) : '')
const waktuEl = (t) => (t?.waktu ? `${formatPendek(t.waktu)} ${formatJam(t.waktu)} WITA` : '')
const ttl = computed(() => [d.value.tempat_lahir, d.value.tanggal_lahir ? formatPanjang(d.value.tanggal_lahir) : ''].filter(Boolean).join(', '))
const nisNisn = computed(() => `NIS. ${d.value.nis || '–'}${d.value.nisn ? '/NISN. ' + d.value.nisn : ''}`)
const jenjangSekolah = computed(() => (d.value.jenjang === 'sma' ? 'SMA' : 'Kesetaraan Wustha'))
const juzTeks = computed(() => ringkasJuz(d.value.juz || []))
const angka = (n) => (n == null ? '–' : String(n).replace('.', ','))
const kota = computed(() => lembaga.identitas?.kota_surat || 'Gowa')
const tglGanda = (m, h) => [m ? formatPanjang(m) : '', h].filter(Boolean).join('/')
// Pengaturan kepala sertifikat (dibekukan saat terbit untuk Sertifikat Tahfizhul Quran)
const atur = computed(() => ({ ...PENGATURAN_SERTIFIKAT, ...(d.value.pengaturan || {}) }))
// Logo selalu dari pengaturan terkini (logo bukan isi resmi sertifikat): logo utama (kosong = logo pondok) dan logo tambahan (opsional)
const tz = useTahfizh(); const aturKini = ref(null)
onMounted(async () => { try { aturKini.value = await tz.pengaturanSertifikat() } catch { aturKini.value = null } })
const sumberLogo = computed(() => aturKini.value || atur.value)
const bukanLama = (u) => (u && !/logo-ypwi/i.test(u) ? u : '')
const logoKiri = computed(() => (bukanLama(sumberLogo.value.logo_kiri) ? alamatAset(sumberLogo.value.logo_kiri) : ''))
const logoKanan = computed(() => alamatAset(bukanLama(sumberLogo.value.logo_kanan) || lembaga.identitas?.logo_url || '') || logoLokal)
// Logo dari situs lain yang gagal dimuat diganti logo pondok bawaan aplikasi
const ganti = (e) => { if (!e.target.src.endsWith(logoLokal)) e.target.src = logoLokal }
const judulPratinjau = computed(() => ({ suket_juz: 'Surat Keterangan Ujian Kenaikan Juz', sertifikat_hafalan: 'Sertifikat Hafalan', sertifikat_tahfizh: 'Sertifikat Tahfizhul Quran' }[props.dok.jenis]))
</script>
<template>
  <!-- ============ SURAT KETERANGAN UJIAN KENAIKAN JUZ ============ -->
  <DokumenCetak v-if="dok.jenis === 'suket_juz'" kop="pondok" judul="Surat Keterangan Ujian Kenaikan Juz" :nomor="dok.nomor" v-model:pratinjau="pratinjau" tanpa-catatan>
    <p style="text-align: justify">Yang bertanda tangan di bawah ini, Penguji Ujian Kenaikan Juz dan Kepala Bidang Tahfizh Pondok Pesantren Tahfizhul Qur'an
      Imam Asy-Syathiby Wahdah Islamiyah Gowa, menerangkan bahwa:</p>
    <table class="data" style="margin: 6pt 0 8pt 10mm">
      <tbody>
        <tr><td style="width: 44mm">Nama</td><td style="width: 4mm">:</td><td><b>{{ d.nama }}</b></td></tr>
        <tr><td>NIS/NISN</td><td>:</td><td>{{ d.nis }}{{ d.nisn ? ' / ' + d.nisn : '' }}</td></tr>
        <tr><td>Tempat, tanggal lahir</td><td>:</td><td>{{ ttl || '–' }}</td></tr>
        <tr><td>Kelas / halaqah</td><td>:</td><td>{{ d.kelas || '–' }} / {{ d.halaqah || '–' }}</td></tr>
      </tbody>
    </table>
    <p style="text-align: justify">telah mengikuti Ujian Kenaikan Juz{{ d.ujian_ke > 1 ? ` (ujian ke-${d.ujian_ke})` : '' }} pada tanggal {{ d.tanggal_ujian ? formatPanjang(d.tanggal_ujian) : '–' }} dengan hasil sebagai berikut:</p>
    <table class="tabel" style="margin: 6pt 0">
      <colgroup><col style="width: 22%"><col style="width: 13%"><col style="width: 13%"><col style="width: 14%"><col style="width: 24%"><col style="width: 14%"></colgroup>
      <thead><tr><th>Juz yang diujikan</th><th>Tajwid</th><th>Itqan</th><th>Nilai akhir</th><th>Predikat</th><th>Keterangan</th></tr></thead>
      <tbody><tr><td class="tengah">Juz {{ juzTeks }}</td><td class="tengah">{{ angka(d.nilai_tajwid) }}</td><td class="tengah">{{ angka(d.nilai_itqan) }}</td>
        <td class="tengah">{{ angka(d.nilai_akhir) }}</td><td class="tengah">{{ d.huruf ? d.huruf + ' – ' : '' }}{{ d.predikat || '–' }}</td><td class="tengah">Tuntas</td></tr></tbody>
    </table>
    <p style="text-align: justify">Dengan demikian, yang bersangkutan dinyatakan <b>TUNTAS</b> pada juz tersebut (KKM {{ angka(d.kkm) }}) dan juz tersebut diusulkan menjadi capaian hafalan resmi.
      Jumlah hafalan resmi saat surat ini diterbitkan: {{ d.total_juz ?? '–' }} juz.</p>
    <p style="margin-top: 6pt; text-align: justify">Demikian surat keterangan ini dibuat dengan sebenarnya untuk dipergunakan sebagaimana mestinya.</p>
    <template #ttd>
      <TandaTangan :tanggal="dok.tanggal" :kiri="sisi(ttd[0])" :kanan="sisi(ttd[1])" />
      <CatatanValidasi :kode="dok.kode" :draf="draf" :basah="basah" :status="status" />
    </template>
  </DokumenCetak>

  <!-- ============ SERTIFIKAT (bingkai) ============ -->
  <LembarRapor v-else v-model:pratinjau="pratinjau" :judul="judulPratinjau" :keterangan="dok.nomor">
    <HalRapor tanpa-kop>
      <div class="sertifikat">
        <div class="bingkai">
          <span v-for="p in ['ki-at', 'ka-at', 'ki-bw', 'ka-bw']" :key="p" :class="['sudut', p]" aria-hidden="true" />
          <img class="tanda-air" :src="logoKanan" alt="" aria-hidden="true" @error="ganti" />
          <div class="logo">
            <img v-if="logoKiri" :src="logoKiri" alt="" @error="(e) => (e.target.style.display = 'none')" />
            <img :src="logoKanan" alt="" @error="ganti" />
          </div>
          <p class="baris1">{{ atur.baris1 }}</p>
          <p class="baris2">{{ atur.baris2 }}</p>
          <p class="baris2">{{ atur.baris3 }}</p>

          <!-- Sertifikat Tahfizhul Quran (format pondok) -->
          <template v-if="dok.jenis === 'sertifikat_tahfizh'">
            <h1 class="judul">SERTIFIKAT<br>TAHFIZHUL QURAN</h1>
            <p class="nomor">Nomor {{ dok.nomor }}</p>
            <p class="teks" v-html="miring(atur.pembuka)" />
            <p class="nama">{{ String(d.nama || '').toUpperCase() }}</p>
            <p class="teks rapat">{{ ttl }}</p>
            <p class="teks rapat">{{ nisNisn }}</p>
            <p class="teks">{{ atur.program }} dengan capaian hafalan sebanyak <b>{{ d.total_juz }} Juz</b> yang telah dihafalkan hingga tanggal
              {{ tglGanda(d.tanggal_hafal, d.tanggal_hafal_hijriah) }} dengan predikat:</p>
            <p class="predikat">{{ d.predikat }}</p>
            <p class="teks">{{ atur.penutup }}</p>
            <div class="ttd-tunggal">
              <p>{{ tglGanda(dok.tanggal, dok.tanggal_hijriah) }}</p>
              <p>{{ ttd[0]?.jabatan || 'Direktur' }}</p>
              <div class="ruang"><div v-if="qr(ttd[0])" class="qr-el"><span class="qr" v-html="qr(ttd[0])" /><span class="ket">Ditandatangani secara elektronik<br>{{ waktuEl(ttd[0]) }}</span></div></div>
              <p class="nm">{{ ttd[0]?.nama }}</p>
              <p v-if="ttd[0]?.niy" class="ni">NIY. {{ ttd[0].niy }}</p>
            </div>
          </template>

          <!-- Sertifikat Hafalan (sertifikasi berjenjang) -->
          <template v-else>
            <h1 class="judul kecil">SERTIFIKAT HAFALAN<br>AL-QUR'AN {{ d.jenjang_juz }} JUZ</h1>
            <p class="nomor">Nomor {{ dok.nomor }}</p>
            <p class="teks">Dengan memohon ridho Allah <i>Subhanahu Wata'ala</i>, Bidang Tahfizh Pondok Pesantren Tahfizhul Quran Imam Asy-Syathiby Wahdah Islamiyah Gowa menerangkan bahwa:</p>
            <p class="nama">{{ String(d.nama || '').toUpperCase() }}</p>
            <p class="teks rapat">{{ ttl }}</p>
            <p class="teks rapat">{{ nisNisn }}</p>
            <p class="teks">telah mengikuti dan dinyatakan lulus Sertifikasi Hafalan Al-Qur'an jenjang <b>{{ d.jenjang_juz }} Juz</b>{{ juzTeks ? ` (juz ${juzTeks})` : '' }}
              pada tanggal {{ d.tanggal_ujian ? formatPanjang(d.tanggal_ujian) : '–' }} dengan nilai <b>{{ angka(d.nilai_akhir) }}</b> dan predikat:</p>
            <p class="predikat">{{ String(d.predikat_sertifikat || d.predikat || '').toUpperCase() }}</p>
            <p class="teks">Semoga Allah menjaga hafalan ini dan menjadikannya amal yang memberatkan timbangan kebaikan.</p>
            <p class="teks rapat" style="margin-top: 4mm">{{ kota }}, {{ tglGanda(dok.tanggal, dok.tanggal_hijriah) }}</p>
            <div class="ttd-dua">
              <div v-for="(t, i) in ttd.slice(0, 2)" :key="i">
                <p>{{ i === 0 ? 'Mengetahui,' : '&nbsp;' }}</p>
                <p>{{ t.jabatan }}</p>
                <div class="ruang"><div v-if="qr(t)" class="qr-el"><span class="qr" v-html="qr(t)" /><span class="ket">Ditandatangani secara elektronik<br>{{ waktuEl(t) }}</span></div></div>
                <p class="nm">{{ t.nama }}</p>
                <p v-if="t.niy" class="ni">NIY. {{ t.niy }}</p>
              </div>
            </div>
          </template>

          <p v-if="status === 'dicabut'" class="validasi tegas">TIDAK BERLAKU – dokumen ini sudah dicabut{{ dok.kode ? ` (kode ${dok.kode})` : '' }}.</p>
          <p v-else-if="draf" class="validasi tegas">DRAF – belum disahkan oleh semua penanda tangan.</p>
          <p v-else-if="dok.kode" class="validasi">Keaslian sertifikat dapat diperiksa di halaman Cek Keabsahan Dokumen SIMKA PRO dengan kode validasi <b>{{ dok.kode }}</b>.</p>
        </div>
      </div>
    </HalRapor>
  </LembarRapor>
</template>
<style scoped>
.sertifikat { min-height: 284mm; display: flex; color: #111; }
.bingkai { position: relative; flex: 1; display: flex; flex-direction: column; align-items: center; text-align: center; padding: 9mm 12mm 7mm;
  border: 1.4mm double #0B6B57; outline: 0.35mm solid #C9A227; outline-offset: -3.2mm; -webkit-print-color-adjust: exact; print-color-adjust: exact; overflow: hidden; }
.sudut { position: absolute; width: 14mm; height: 14mm; border: 0.6mm solid #C9A227; }
.sudut.ki-at { top: 5mm; left: 5mm; border-right: 0; border-bottom: 0; }
.sudut.ka-at { top: 5mm; right: 5mm; border-left: 0; border-bottom: 0; }
.sudut.ki-bw { bottom: 5mm; left: 5mm; border-right: 0; border-top: 0; }
.sudut.ka-bw { bottom: 5mm; right: 5mm; border-left: 0; border-top: 0; }
.tanda-air { position: absolute; top: 50%; left: 50%; width: 115mm; transform: translate(-50%, -45%); opacity: .06; pointer-events: none; }
.bingkai p { margin: 0; position: relative; }
.logo { display: flex; gap: 6mm; justify-content: center; align-items: center; margin-bottom: 3mm; position: relative; }
.logo img { height: 25mm; width: auto; object-fit: contain; }
.baris1 { font-family: 'Times New Roman', Times, serif; font-size: 12.5pt; letter-spacing: .2mm; }
.baris2 { font-family: 'Times New Roman', Times, serif; font-size: 12.5pt; font-weight: 700; }
.judul { position: relative; margin: 5mm 0 2mm; font-family: 'Times New Roman', Times, serif; font-weight: 400; font-size: 37pt; line-height: 1.05; letter-spacing: .2mm; white-space: nowrap; }
.judul.kecil { font-size: 27pt; }
.nomor { font-size: 11pt; margin-bottom: 4mm !important; }
.teks { font-size: 13pt; line-height: 1.38; margin-top: 2.5mm !important; max-width: 160mm; }
.teks.rapat { margin-top: 0.5mm !important; }
.nama { margin-top: 4mm !important; font-family: 'Times New Roman', Times, serif; font-size: 22pt; font-weight: 700; letter-spacing: .3mm; }
.predikat { margin-top: 3mm !important; font-family: 'Times New Roman', Times, serif; font-size: 15pt; font-weight: 700; }
.ttd-tunggal { margin-top: 5mm; font-size: 13pt; line-height: 1.35; }
.ttd-dua { margin-top: 3mm; width: 100%; display: grid; grid-template-columns: 1fr 1fr; column-gap: 14mm; font-size: 12.5pt; line-height: 1.35; }
.ruang { height: 22mm; display: flex; align-items: center; justify-content: center; }
.nm { font-weight: 700; }
.ni { font-size: 11pt; }
.qr-el { display: flex; align-items: center; gap: 3mm; text-align: left; }
.qr-el .qr { display: block; width: 19mm; height: 19mm; }
.qr-el .qr :deep(svg) { width: 100%; height: 100%; display: block; }
.qr-el .ket { font-size: 8pt; line-height: 1.25; font-style: italic; }
.validasi { margin-top: auto !important; padding-top: 4mm; font-size: 8.5pt; color: #333; }
.validasi.tegas { font-weight: 700; color: #9b1c1c; }
</style>
