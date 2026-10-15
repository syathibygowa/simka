<!-- SIMKA PRO | src/components/KartuSantri.vue | v1.1 | Perbaikan: warna khas pondok merah gradasi jingga, kaki gradasi; berbeda bentuk dari kartu pegawai | 16/10/2026 -->
<script setup>
// Kartu pelajar santri TEGAK ukuran ID-1: 54 × 85,6 mm (cetak 1:1), warna khas pondok (merah gradasi jingga).
// Pembeda dari kartu pegawai: kepala miring (bukan melengkung), pita "SANTRI", foto bulat berbingkai jingga,
// jenjang dalam bingkai garis, sisi belakang berkepala gradasi. Kaki kartu gradasi jingga → merah (kartu pegawai merah → jingga).
// Depan : pas foto santri, nama, NIS/NISN, jenjang dan kelas, tempat/tanggal lahir, kode QR verifikasi (#/cek-kartu/KODE).
// Belakang: identitas lembaga, ketentuan kartu, alamat, tanda tangan Direktur pondok.
import { computed } from 'vue'
import { PhStudent } from '@phosphor-icons/vue'
import { svgQR, alamatVerifikasi, kodeRapi } from '@/lib/kartu'
import { formatPanjang } from '@/lib/tanggal'

const props = defineProps({
  d: { type: Object, required: true }, sisi: { type: String, default: 'depan' },
  foto: String, identitas: { type: Object, default: () => ({}) }, direktur: { type: Object, default: () => ({}) },
})
const qr = computed(() => (props.d.kode ? svgQR(alamatVerifikasi(props.d.kode)) : ''))
const jenjang = computed(() => (props.d.jenjang === 'sma' ? 'SMA' : 'Kesetaraan Wustha'))
const kelas = computed(() => props.d.kelas || (props.d.tingkat ? `Kelas ${props.d.tingkat}` : ''))
const ttl = computed(() => [props.d.tempat_lahir, props.d.tanggal_lahir ? formatPanjang(props.d.tanggal_lahir) : ''].filter(Boolean).join(', '))
const KETENTUAN = [
  'Kartu ini adalah tanda pengenal resmi santri dan wajib dibawa selama berada di lingkungan pondok maupun saat izin keluar.',
  'Kartu berlaku selama pemegang tercatat sebagai santri aktif; keabsahan dapat diperiksa dengan memindai kode QR.',
  'Kartu tidak boleh dipinjamkan atau dipindahtangankan.',
  'Kehilangan kartu segera dilaporkan kepada wali kelas atau bagian kesantrian.',
]
</script>
<template>
  <div :class="['kartu-p', 'kartu-s', sisi, !d.aktif && 'nonaktif']" :aria-label="`Kartu pelajar ${d.nama}, sisi ${sisi}`">
    <template v-if="sisi === 'depan'">
      <div class="atas">
        <div class="motif" aria-hidden="true" />
        <div class="kepala">
          <img v-if="identitas.logo_url" :src="identitas.logo_url" alt="" class="logo" />
          <div><p class="k1">KARTU PELAJAR</p><p class="k2">{{ identitas.nama_singkat || 'IMAM ASY-SYATHIBY' }}</p></div>
        </div>
        <span class="pil">SANTRI</span>
      </div>
      <div class="foto"><img v-if="foto" :src="foto" alt="" /><PhStudent v-else :size="44" weight="duotone" class="kosong" /></div>
      <div class="isi">
        <p class="nama">{{ d.nama }}</p>
        <p class="jab">{{ jenjang }}{{ kelas ? ' · ' + kelas : '' }}</p>
        <p class="niy">NIS {{ d.nis }}{{ d.nisn ? ' · NISN ' + d.nisn : '' }}</p>
        <p class="unit">{{ ttl }}</p>
      </div>
      <div class="bawah">
        <div class="qr" v-html="qr" />
        <div class="kode"><p class="kk">Pindai untuk verifikasi</p><p class="kv">{{ kodeRapi(d.kode) }}</p></div>
      </div>
      <div class="pita" aria-hidden="true" />
      <p v-if="!d.aktif" class="cap">TIDAK BERLAKU</p>
    </template>
    <template v-else>
      <div class="bel-atas">
        <div class="motif" aria-hidden="true" />
        <img v-if="identitas.logo_url" :src="identitas.logo_url" alt="" class="logo-b" />
        <p class="lembaga">{{ identitas.nama_lengkap || "Pondok Pesantren Tahfizhul Qur'an Imam Asy-Syathiby Wahdah Islamiyah Gowa" }}</p>
        <p class="izin">NPSN {{ identitas.npsn || '–' }} · NSPP {{ identitas.nspp || '–' }}</p>
      </div>
      <div class="bel-isi">
        <p class="sub">Ketentuan</p>
        <ol><li v-for="k in KETENTUAN" :key="k">{{ k }}</li></ol>
        <p class="sub">Alamat</p>
        <p class="alamat">{{ identitas.alamat || 'Jl. Poros Malino KM.04, Gowa' }}</p>
        <p class="alamat">{{ [identitas.telepon && 'Telp. ' + identitas.telepon, identitas.email].filter(Boolean).join(' · ') }}</p>
      </div>
      <div class="ttd">
        <p>{{ identitas.kota_surat || 'Gowa' }}, {{ direktur.jabatan_tertulis || 'Direktur' }}</p>
        <div class="ruang" />
        <p class="nm">{{ direktur.nama || '' }}</p>
        <p v-if="direktur.niy" class="ni">NIY {{ direktur.niy }}</p>
      </div>
      <div class="pita" aria-hidden="true" />
    </template>
  </div>
</template>
<style scoped>
.kartu-p { position: relative; width: 54mm; height: 85.6mm; border-radius: 3.2mm; overflow: hidden; background: #fff; color: #1f1416;
  font-family: 'Plus Jakarta Sans', Arial, sans-serif; box-shadow: 0 0 0 0.2mm #e6cfc6; flex-shrink: 0; text-align: left;
  -webkit-print-color-adjust: exact; print-color-adjust: exact; display: flex; flex-direction: column; }
.kartu-p p { margin: 0; }
/* ---------- Depan: kepala miring merah → jingga ---------- */
.depan .atas { position: relative; height: 29mm; color: #fff; background: linear-gradient(120deg, #8E1B17 0%, #C7332F 45%, #F08A3E 100%);
  clip-path: polygon(0 0, 100% 0, 100% 72%, 0 100%); }
.depan .motif { position: absolute; inset: 0; opacity: .16;
  background-image: radial-gradient(circle, #fff 0.35mm, transparent 0.45mm); background-size: 3.2mm 3.2mm; }
.depan .kepala { position: relative; display: flex; align-items: center; gap: 2mm; padding: 3mm 3.5mm 0; }
.depan .logo { width: 8.5mm; height: 8.5mm; border-radius: 50%; background: #fff; padding: 0.5mm; object-fit: contain; }
.depan .k1 { font-size: 5pt; font-weight: 800; letter-spacing: .45mm; color: #FFE2C7; }
.depan .k2 { font-size: 7.6pt; font-weight: 800; line-height: 1.1; }
.depan .pil { position: absolute; top: 13.5mm; right: 3mm; padding: 0.4mm 2mm; border-radius: 9999px; background: #fff; color: #C7332F; font-size: 5.2pt; font-weight: 800; letter-spacing: .4mm; }
.depan .foto { position: relative; z-index: 1; width: 26mm; height: 26mm; margin: -15mm auto 0; border-radius: 50%; overflow: hidden; background: #fbeee6;
  border: 0.9mm solid #fff; box-shadow: 0 0 0 0.6mm #F08A3E, 0 1.2mm 3mm rgba(142, 27, 23, .3); display: grid; place-items: center; }
.depan .foto img { width: 100%; height: 100%; object-fit: cover; object-position: center 25%; }
.depan .kosong { color: #c08a78; }
.depan .isi { text-align: center; padding: 2mm 3mm 0; }
.depan .nama { font-size: 8.4pt; font-weight: 800; line-height: 1.18; color: #5a1410; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; }
.depan .jab { display: inline-block; margin-top: 1.2mm !important; padding: 0.3mm 2.2mm; border-radius: 1mm; font-size: 6pt; font-weight: 800; color: #C7332F;
  border: 0.35mm solid #C7332F; background: #fff4ec; }
.depan .niy { margin-top: 1mm !important; font-size: 6.2pt; font-weight: 600; letter-spacing: .1mm; }
.depan .unit { font-size: 5.8pt; color: #6b5658; }
.depan .bawah { margin-top: auto; display: flex; align-items: center; gap: 2mm; padding: 0 3.5mm 4mm; }
.depan .qr { width: 15mm; height: 15mm; padding: 0.6mm; background: #fff; border: 0.25mm solid #f0d4c6; border-radius: 1mm; flex-shrink: 0; }
.depan .qr :deep(svg) { width: 100%; height: 100%; display: block; }
.depan .kk { font-size: 5pt; color: #6b5658; }
.depan .kv { font-size: 6.6pt; font-weight: 800; letter-spacing: .2mm; color: #5a1410; }
.pita { position: absolute; left: 0; right: 0; bottom: 0; height: 2.4mm; background: linear-gradient(90deg, #F39A4E 0%, #E0592F 50%, #8E1B17 100%); }
.cap { position: absolute; top: 45mm; left: 50%; transform: translateX(-50%) rotate(-14deg); border: 0.6mm solid #C7332F; color: #C7332F; font-weight: 800; font-size: 10pt;
  padding: 0.5mm 2mm; background: rgba(255,255,255,.88); white-space: nowrap; }
/* ---------- Belakang: kepala gradasi ---------- */
.belakang { background: #fffaf6; }
.belakang .bel-atas { position: relative; text-align: center; padding: 3mm 3.5mm 2mm; color: #fff; background: linear-gradient(120deg, #8E1B17 0%, #C7332F 50%, #F08A3E 100%); }
.belakang .bel-atas .motif { position: absolute; inset: 0; opacity: .14; background-image: radial-gradient(circle, #fff 0.35mm, transparent 0.45mm); background-size: 3.2mm 3.2mm; }
.belakang .logo-b { position: relative; width: 8.5mm; height: 8.5mm; object-fit: contain; margin: 0 auto 0.8mm; display: block; background: #fff; border-radius: 50%; padding: 0.5mm; }
.belakang .lembaga { position: relative; font-size: 6.2pt; font-weight: 800; line-height: 1.22; }
.belakang .izin { position: relative; font-size: 5pt; color: #FFE2C7; margin-top: 0.6mm !important; }
.belakang .bel-isi { padding: 1.4mm 3.5mm 0; font-size: 4.7pt; line-height: 1.28; text-align: left; }
.belakang .sub { font-size: 5.2pt; font-weight: 800; color: #C7332F; margin-top: 1mm !important; letter-spacing: .2mm; text-transform: uppercase; }
.belakang ol { margin: 0.4mm 0 0; padding-left: 2.6mm; list-style: decimal; }
.belakang li { margin-bottom: 0.3mm; padding-left: 0.3mm; }
.belakang .alamat { color: #3d2c2e; }
.belakang .ttd { margin-top: auto; padding: 0 3.5mm 4mm; text-align: center; font-size: 5.2pt; }
.belakang .ruang { height: 5mm; }
.belakang .nm { font-weight: 800; text-decoration: underline; font-size: 5.8pt; }
.belakang .ni { color: #6b5658; }
</style>
