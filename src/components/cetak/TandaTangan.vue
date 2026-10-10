<!-- SIMKA PRO | src/components/cetak/TandaTangan.vue | v1.4 | Fase 8 – Perbaikan: nama menu ringkas | 10/10/2026 -->
<script setup>
// Kolom tanda tangan sejajar: kiri pimpinan/atasan, kanan pegawai terkait.
// Kolom kanan memuat tempat dan tanggal dokumen.
// Tanda tangan elektronik: isi { kode, waktu } pada sisi yang ditandatangani → QR Cek Keabsahan + "Ditandatangani
// secara elektronik" + waktu. Isian lama berupa teks (elektronik: '…') tetap didukung.
import { computed } from 'vue'
import { formatPanjang, formatPendek, formatJam } from '@/lib/tanggal'
import { svgQR, alamatCek } from '@/lib/dokumen'
import { useLembaga } from '@/stores/lembaga'
const lembaga = useLembaga()
const props = defineProps({
  kiri: { type: Object, required: true },   // { pengantar, jabatan, nama, niy, elektronik, kode, waktu }
  kanan: { type: Object, required: true },  // { jabatan, nama, niy, elektronik, kode, waktu }
  kota: { type: String, default: '' },  // bawaan: kota surat dari Setelan → Identitas
  tanggal: String,                           // yyyy-mm-dd; bawaan hari ini
})
const kotaSurat = computed(() => props.kota || lembaga.identitas?.kota_surat || 'Gowa')
const qr = (s) => (s?.kode ? svgQR(alamatCek(s.kode)) : '')
const waktuEl = (s) => (s?.waktu ? `${formatPendek(s.waktu)} ${formatJam(s.waktu)} WITA` : '')
</script>
<template>
  <section class="ttd">
    <div v-for="(s, i) in [kiri, kanan]" :key="i">
      <p v-if="i === 0">{{ s.pengantar || 'Mengetahui,' }}</p>
      <p v-else>{{ kotaSurat }}, {{ formatPanjang(tanggal || new Date()) }}</p>
      <p>{{ s.jabatan }}</p>
      <div class="ruang">
        <div v-if="s.kode" class="ttd-qr">
          <span class="qr" v-html="qr(s)" />
          <span class="ket">Ditandatangani secara elektronik<br>{{ waktuEl(s) }}</span>
        </div>
        <p v-else-if="s.elektronik" class="ttd-el">{{ s.elektronik }}</p>
      </div>
      <p class="nama">{{ s.nama }}</p>
      <p v-if="s.niy">NIY. {{ s.niy }}</p>
    </div>
  </section>
</template>
