<!-- SIMKA PRO | src/components/cetak/KopSurat.vue | v1.0 | Fase 1 – Pengaturan | 03/10/2026 -->
<script setup>
// Kop surat untuk layar dan cetak. Dua bentuk:
//   gambar : satu gambar kop utuh (bawaan: kop resmi pondok)
//   susun  : logo kiri + baris teks + logo kanan, lalu pita alamat atau garis ganda
import { computed } from 'vue'
import kopPondok from '@/assets/kop/kop-pondok.jpg'
import kopWustha from '@/assets/kop/kop-wustha.jpg'
import kopSma from '@/assets/kop/kop-sma.jpg'
import kopYayasan from '@/assets/kop/kop-yayasan.jpg'

const BAWAAN = { pondok: kopPondok, wustha: kopWustha, sma: kopSma, yayasan: kopYayasan }
const props = defineProps({ kop: { type: Object, default: null }, kode: { type: String, default: 'pondok' } })

/** Alamat gambar: kop bawaan dipakai dari paket aplikasi; selain itu URL penuh. */
function alamat(u) {
  if (!u) return ''
  const m = /^kop\/kop-(\w+)\.jpg$/.exec(u)
  if (m && BAWAAN[m[1]]) return BAWAAN[m[1]]
  if (/^(https?:|data:|blob:)/.test(u)) return u
  return new URL(u, document.baseURI).href
}
const k = computed(() => props.kop || { bentuk: 'gambar', gambar_url: `kop/kop-${props.kode}.jpg` })
const gambar = computed(() => alamat(k.value.gambar_url) || BAWAAN[props.kode] || kopPondok)
</script>
<template>
  <header class="kop">
    <img v-if="k.bentuk !== 'susun'" :src="gambar" :alt="k.nama || 'Kop surat'" />
    <template v-else>
      <div class="kop-susun">
        <div class="kop-logo"><img v-if="k.logo_kiri_url" :src="alamat(k.logo_kiri_url)" alt="Logo kiri" /></div>
        <div class="kop-teks">
          <p v-for="(b, i) in k.baris || []" :key="i" :style="{ fontWeight: b.tebal ? 700 : 400, fontSize: (b.ukuran || 12) + 'pt' }">{{ b.teks }}</p>
        </div>
        <div class="kop-logo"><img v-if="k.logo_kanan_url" :src="alamat(k.logo_kanan_url)" alt="Logo kanan" /></div>
      </div>
      <div v-if="k.pita_teks" class="kop-pita" :style="{ background: k.pita_warna || '#F8E02F' }">{{ k.pita_teks }}</div>
      <hr v-else class="kop-garis" />
    </template>
  </header>
</template>
<style>
.kop-susun { display: grid; grid-template-columns: 22mm 1fr 22mm; align-items: center; gap: 4mm; }
.kop-logo img { width: 22mm; height: 22mm; object-fit: contain; }
.kop-teks { text-align: center; line-height: 1.2; color: #000; }
.kop-teks p { margin: 0; }
.kop-pita { margin-top: 2mm; padding: 1.2mm 3mm; text-align: center; font-size: 8.5pt; font-weight: 700; color: #000;
  -webkit-print-color-adjust: exact; print-color-adjust: exact; }
</style>
