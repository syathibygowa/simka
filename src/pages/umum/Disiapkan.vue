<script setup>
// Halaman Fase 1 yang dikerjakan pada tahap berikutnya (verifikasi akun, organisasi, hak akses, pengaturan).
import { computed } from 'vue'
import { cariMenu } from '@/lib/menu'
const props = defineProps({ kode: String })
const m = computed(() => cariMenu(props.kode))
const ISI = {
  verifikasi: 'Daftar pendaftar, koreksi centang jabatan, aktifkan atau tolak akun, kirim email aktivasi dan pesan WA.',
  organisasi: 'Pohon bidang dan unit, jabatan fungsional (P1) dan struktural (P2).',
  hakakses: 'Akses fitur per jabatan, bidang, dan individu (lihat, input/ubah, kelola) beserta akses efektif.',
  pengaturan: 'Identitas lembaga, kalender, empat kop surat dengan cetak uji F4, penanda tangan, penomoran, dan integrasi.',
}
</script>
<template>
  <div :class="['mx-auto flex max-w-md flex-col items-center py-12 text-center', 'w-' + m.warna]">
    <span class="chip-ikon h-20 w-20 rounded-3xl"><component :is="m.ikon" :size="44" weight="duotone" /></span>
    <h2 class="mt-4 text-xl font-extrabold">{{ m.nama }}</h2>
    <span class="lencana mt-2">Fase 1, tahap berikutnya</span>
    <p class="mt-3 text-teks2">{{ ISI[kode] }}</p>
    <p class="mt-2 text-sm text-teks3">Basis data dan fungsi servernya sudah siap; halaman ini sedang disusun.</p>
    <router-link to="/" class="tombol-garis mt-6">Kembali ke beranda</router-link>
  </div>
</template>
