<!-- SIMKA PRO | src/pages/umum/Segera.vue | v1.1 | Fase 8 – Tahap 0 tanpa teks fase | 10/10/2026 -->
<script setup>
// Menu yang dibangun pada fase berikutnya.
import { computed } from 'vue'
import { cariMenu } from '@/lib/menu'
const props = defineProps({ kode: String })
const m = computed(() => cariMenu(props.kode) || { nama: 'Menu', warna: 'beranda', fase: '-' })
const ISI = {
  presensi: 'Presensi GPS dengan selfie wajib, titik lokasi pondok, pola sesi per tugas, dan verval presensi di luar area.',
  pengajuan: 'Pengajuan izin, sakit, dan cuti berjenjang beserta dokumen cetaknya.',
  jurnal: 'Jurnal harian pegawai dengan template per jabatan.', kartu: 'Kartu pegawai dengan QR verifikasi.',
  santri: 'Data santri, mutasi, tahun ajaran, kelompok, dan absensi HISBAT.', tahfizh: 'Setoran sabaq, sabqi, manzil, validasi capaian, ujian, dan sertifikasi.',
  klinik: 'Rujukan santri sakit, pemeriksaan, dan tindak lanjut.', security: 'Gerbang, izin keluar, titipan, tamu, dan kunjungan.',
  laporan: 'Rekap kehadiran semua cakupan, PDF F4, Excel, dan tanda tangan elektronik.', tatausaha: 'Surat masuk, disposisi, dan surat keluar dari template.',
  gaji: 'Komponen gaji, potongan berbasis kehadiran, dan slip gaji.', pengumuman: 'Pengumuman dengan sasaran per bidang, jabatan, atau orang tertentu.',
}
</script>
<template>
  <div :class="['mx-auto flex max-w-md flex-col items-center py-12 text-center', 'w-' + m.warna]">
    <span class="chip-ikon h-20 w-20 rounded-3xl"><component :is="m.ikon" :size="44" weight="duotone" /></span>
    <h2 class="mt-4 text-xl font-extrabold">{{ m.nama }}</h2>
    <span class="lencana mt-2">Segera tersedia</span>
    <p class="mt-3 text-teks2">{{ ISI[kode] || 'Menu ini sedang disiapkan dan akan segera tersedia.' }}</p>
    <router-link to="/" class="tombol-garis mt-6">Kembali ke beranda</router-link>
  </div>
</template>
