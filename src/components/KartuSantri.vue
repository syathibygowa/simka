<!-- SIMKA PRO | src/components/KartuSantri.vue | v1.0 | Tahap C: kartu pelajar santri | 16/10/2026 -->
<script setup>
// Kartu pelajar santri TEGAK ukuran ID-1: 54 × 85,6 mm (cetak 1:1), bernuansa hijau pondok dan emas.
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
.kartu-p { position: relative; width: 54mm; height: 85.6mm; border-radius: 3.2mm; overflow: hidden; background: #fff; color: #0f2a22;
  font-family: 'Plus Jakarta Sans', Arial, sans-serif; box-shadow: 0 0 0 0.2mm #c9dcd3; flex-shrink: 0; text-align: left;
  -webkit-print-color-adjust: exact; print-color-adjust: exact; display: flex; flex-direction: column; }
.kartu-p p { margin: 0; }
/* ---------- Depan ---------- */
.depan .atas { position: relative; height: 30mm; background: linear-gradient(150deg, #053F35 0%, #0B6B57 50%, #1F9A73 100%);
  border-bottom-left-radius: 50% 9mm; border-bottom-right-radius: 50% 9mm; color: #fff; }
.depan .motif { position: absolute; inset: 0; opacity: .16; border-bottom-left-radius: inherit; border-bottom-right-radius: inherit;
  background-image: linear-gradient(45deg, #F2C24B 0.25mm, transparent 0.25mm), linear-gradient(-45deg, #F2C24B 0.25mm, transparent 0.25mm);
  background-size: 5mm 5mm; }
.depan .kepala { position: relative; display: flex; align-items: center; gap: 2mm; padding: 3mm 3.5mm 0; }
.depan .logo { width: 8.5mm; height: 8.5mm; border-radius: 50%; background: #fff; padding: 0.5mm; object-fit: contain; }
.depan .k1 { font-size: 5pt; font-weight: 700; letter-spacing: .45mm; color: #F7D774; }
.depan .k2 { font-size: 7.6pt; font-weight: 800; line-height: 1.1; }
.depan .foto { position: relative; z-index: 1; width: 25mm; height: 31mm; margin: -16mm auto 0; border-radius: 2.4mm; overflow: hidden; background: #e8f3ee;
  border: 0.9mm solid #fff; box-shadow: 0 1.2mm 3mm rgba(5, 63, 53, .3); display: grid; place-items: center; }
.depan .foto img { width: 100%; height: 100%; object-fit: cover; }
.depan .kosong { color: #6f9c8b; }
.depan .isi { text-align: center; padding: 2mm 3mm 0; }
.depan .nama { font-size: 8.4pt; font-weight: 800; line-height: 1.18; color: #053F35; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; }
.depan .jab { display: inline-block; margin-top: 1.2mm !important; padding: 0.5mm 2.4mm; border-radius: 9999px; font-size: 6.2pt; font-weight: 700; color: #3b2a00;
  background: linear-gradient(90deg, #F2C24B, #F7D774); }
.depan .niy { margin-top: 1mm !important; font-size: 6.2pt; font-weight: 600; letter-spacing: .1mm; }
.depan .unit { font-size: 5.8pt; color: #4d6b60; }
.depan .bawah { margin-top: auto; display: flex; align-items: center; gap: 2mm; padding: 0 3.5mm 4mm; }
.depan .qr { width: 15mm; height: 15mm; padding: 0.6mm; background: #fff; border: 0.25mm solid #cfe2d9; border-radius: 1mm; flex-shrink: 0; }
.depan .qr :deep(svg) { width: 100%; height: 100%; display: block; }
.depan .kk { font-size: 5pt; color: #4d6b60; }
.depan .kv { font-size: 6.6pt; font-weight: 800; letter-spacing: .2mm; color: #053F35; }
.pita { position: absolute; left: 0; right: 0; bottom: 0; height: 1.8mm; background: repeating-linear-gradient(90deg, #0B6B57 0 7mm, #F2C24B 7mm 10mm, #C7332F 10mm 13mm); }
.cap { position: absolute; top: 45mm; left: 50%; transform: translateX(-50%) rotate(-14deg); border: 0.6mm solid #C7332F; color: #C7332F; font-weight: 800; font-size: 10pt;
  padding: 0.5mm 2mm; background: rgba(255,255,255,.88); white-space: nowrap; }
/* ---------- Belakang ---------- */
.belakang { background: linear-gradient(180deg, #fff 0%, #eef6f1 100%); }
.belakang .bel-atas { text-align: center; padding: 3mm 3.5mm 1.6mm; border-bottom: 0.3mm solid #d3e5dc; }
.belakang .logo-b { width: 8.5mm; height: 8.5mm; object-fit: contain; margin: 0 auto 0.8mm; display: block; }
.belakang .lembaga { font-size: 6.4pt; font-weight: 800; line-height: 1.22; color: #053F35; }
.belakang .izin { font-size: 5pt; color: #4d6b60; margin-top: 0.6mm !important; }
.belakang .bel-isi { padding: 1.4mm 3.5mm 0; font-size: 4.7pt; line-height: 1.28; text-align: left; }
.belakang .sub { font-size: 5.2pt; font-weight: 800; color: #0B6B57; margin-top: 1mm !important; letter-spacing: .2mm; text-transform: uppercase; }
.belakang ol { margin: 0.4mm 0 0; padding-left: 2.6mm; list-style: decimal; }
.belakang li { margin-bottom: 0.3mm; padding-left: 0.3mm; }
.belakang .alamat { color: #24433a; }
.belakang .ttd { margin-top: auto; padding: 0 3.5mm 3.6mm; text-align: center; font-size: 5.2pt; }
.belakang .ruang { height: 5.5mm; }
.belakang .nm { font-weight: 800; text-decoration: underline; font-size: 5.8pt; }
.belakang .ni { color: #4d6b60; }
</style>
