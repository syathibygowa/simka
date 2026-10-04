<!-- SIMKA PRO | src/components/KartuPegawai.vue | v1.0 | Fase 3 – Tahap 4 Berkas Saya dan kartu pegawai | 04/10/2026 -->
<script setup>
// Kartu pegawai ukuran ID-1 (85,6 × 54 mm). Sisi depan: identitas dan pas foto; sisi belakang: kode QR
// verifikasi, masa berlaku, dan Direktur. Ukuran dalam milimeter sehingga cetak 1:1.
import { computed } from 'vue'
import { PhUser } from '@phosphor-icons/vue'
import { svgQR, alamatVerifikasi, kodeRapi } from '@/lib/kartu'

const props = defineProps({
  d: { type: Object, required: true }, sisi: { type: String, default: 'depan' },
  foto: String, identitas: { type: Object, default: () => ({}) }, direktur: { type: Object, default: () => ({}) },
})
const qr = computed(() => (props.d.kode ? svgQR(alamatVerifikasi(props.d.kode)) : ''))
const logo = computed(() => props.identitas.logo_url || '')
</script>
<template>
  <div :class="['kartu-id', sisi, !d.aktif && 'nonaktif']" :aria-label="`Kartu pegawai ${d.nama}, sisi ${sisi}`">
    <template v-if="sisi === 'depan'">
      <div class="pita">
        <img v-if="logo" :src="logo" alt="" class="logo" />
        <div class="judul"><p class="kecil">KARTU PEGAWAI</p><p class="lembaga">{{ identitas.nama_singkat || 'IMAM ASY-SYATHIBY' }}</p><p class="sub">Wahdah Islamiyah Gowa</p></div>
      </div>
      <div class="badan">
        <div class="foto"><img v-if="foto" :src="foto" alt="" /><PhUser v-else :size="40" weight="duotone" class="kosong" /></div>
        <div class="data">
          <p class="nama">{{ d.nama }}</p>
          <p class="niy">NIY {{ d.niy || '–' }}</p>
          <p class="jab">{{ d.jabatan || 'Pegawai' }}</p>
          <p class="unit">{{ d.unit || '' }}</p>
        </div>
      </div>
      <div class="kaki" />
      <p v-if="!d.aktif" class="cap">TIDAK BERLAKU</p>
    </template>
    <template v-else>
      <p class="atas">{{ identitas.nama_lengkap || "Pondok Pesantren Tahfizhul Qur'an Imam Asy-Syathiby Wahdah Islamiyah Gowa" }}</p>
      <div class="isi">
        <div class="qr" v-html="qr" />
        <div class="ket">
          <p><b>Kode kartu</b><br />{{ kodeRapi(d.kode) }}</p>
          <p>Berlaku selama pemegang tercatat sebagai pegawai aktif. Pindai kode QR untuk memeriksa keabsahan kartu.</p>
          <p class="ttd">{{ identitas.kota_surat || 'Gowa' }}, {{ direktur.jabatan_tertulis || 'Direktur' }}<br /><span class="nm">{{ direktur.nama || '' }}</span></p>
        </div>
      </div>
      <p class="bawah">Bila menemukan kartu ini, mohon dikembalikan ke: {{ identitas.alamat || 'Jl. Poros Malino KM.04, Gowa' }}{{ identitas.telepon ? ' · Telp. ' + identitas.telepon : '' }}</p>
    </template>
  </div>
</template>
<style scoped>
.kartu-id { position: relative; width: 85.6mm; height: 54mm; border-radius: 3.2mm; overflow: hidden; background: #fff; color: #1f1416;
  font-family: 'Plus Jakarta Sans', Arial, sans-serif; box-shadow: 0 0 0 0.2mm #d9c7c0; -webkit-print-color-adjust: exact; print-color-adjust: exact; flex-shrink: 0; }
.depan .pita { height: 14mm; display: flex; align-items: center; gap: 2.5mm; padding: 0 3.5mm; color: #fff;
  background: linear-gradient(100deg, #8E1C19, #C7332F 55%, #F39A4E); }
.depan .logo { height: 10mm; width: 10mm; object-fit: contain; background: #fff; border-radius: 50%; padding: 0.6mm; }
.depan .judul p { margin: 0; line-height: 1.15; }
.depan .kecil { font-size: 5.2pt; letter-spacing: 0.35mm; font-weight: 700; opacity: .92; }
.depan .lembaga { font-size: 8.5pt; font-weight: 800; }
.depan .sub { font-size: 5.5pt; opacity: .92; }
.depan .badan { display: flex; gap: 3mm; padding: 3mm 3.5mm 0; }
.depan .foto { width: 20mm; height: 26mm; border-radius: 1.6mm; overflow: hidden; background: #f4ebe7; display: grid; place-items: center; flex-shrink: 0; border: 0.3mm solid #e9d8d0; }
.depan .foto img { width: 100%; height: 100%; object-fit: cover; }
.depan .kosong { color: #b08d84; }
.depan .data { min-width: 0; padding-top: 0.5mm; }
.depan .data p { margin: 0; }
.depan .nama { font-size: 8.6pt; font-weight: 800; line-height: 1.2; color: #8E1C19; }
.depan .niy { font-size: 6.6pt; font-weight: 600; margin-top: 0.8mm !important; }
.depan .jab { font-size: 6.4pt; line-height: 1.25; margin-top: 1.4mm !important; display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden; }
.depan .unit { font-size: 6.2pt; color: #6b5658; margin-top: 0.6mm !important; }
.depan .kaki { position: absolute; left: 0; right: 0; bottom: 0; height: 2.2mm; background: repeating-linear-gradient(90deg, #C7332F 0 6mm, #F39A4E 6mm 9mm, #0B7F81 9mm 12mm); }
.cap { position: absolute; top: 22mm; left: 50%; transform: translateX(-50%) rotate(-12deg); border: 0.6mm solid #C7332F; color: #C7332F; font-weight: 800; font-size: 11pt; padding: 0.5mm 2mm; background: rgba(255,255,255,.85); }
.belakang { padding: 3mm 3.5mm; display: flex; flex-direction: column; background: linear-gradient(180deg, #fff, #fbf3ef); }
.belakang p { margin: 0; }
.belakang .atas { font-size: 5.8pt; font-weight: 700; text-align: center; color: #8E1C19; line-height: 1.25; }
.belakang .isi { display: flex; gap: 3mm; margin-top: 2.2mm; flex: 1; }
.belakang .qr { width: 24mm; height: 24mm; flex-shrink: 0; padding: 1mm; background: #fff; border: 0.3mm solid #e9d8d0; border-radius: 1mm; }
.belakang .qr :deep(svg) { width: 100%; height: 100%; display: block; }
.belakang .ket { font-size: 5.6pt; line-height: 1.3; display: flex; flex-direction: column; gap: 1.2mm; }
.belakang .ket b { font-size: 5.6pt; }
.belakang .ttd { margin-top: auto !important; }
.belakang .nm { font-weight: 700; text-decoration: underline; }
.belakang .bawah { font-size: 4.8pt; color: #6b5658; line-height: 1.25; border-top: 0.2mm solid #e9d8d0; padding-top: 1mm; margin-top: 1mm !important; }
</style>
