<!-- SIMKA PRO | src/components/KartuTahfizhBeranda.vue | v1.0 | Fase 5 – Tahap 6 Penutup fase tahfizh | 05/10/2026 -->
<script setup>
// Kartu statistik tahfizh langsung di beranda (muhaffizh: halaqah asuhannya; pimpinan/admin: seluruh pondok).
// Diperbarui otomatis (Realtime) saat setoran disimpan atau ujian berubah.
import { computed, onMounted } from 'vue'
import { PhNotebook, PhExam, PhSealCheck, PhBookOpenText, PhCrown, PhTarget } from '@phosphor-icons/vue'
import { useTahfizh } from '@/stores/tahfizh'
import KartuStatistik from './KartuStatistik.vue'
const tz = useTahfizh()
onMounted(() => { tz.muatBeranda(); tz.dengarkanBeranda() })
const d = computed(() => tz.beranda || {})
const persenCapai = computed(() => (d.value.terdata ? `${Math.round(((d.value.tercapai || 0) / d.value.terdata) * 100)}%` : '–'))
</script>
<template>
  <section v-if="tz.beranda">
    <div class="mb-3 flex items-center justify-between gap-2">
      <h2 class="judul-bagian">Tahfizh {{ d.cakupan_semua ? 'hari ini' : 'halaqah saya' }}</h2>
      <router-link to="/tahfizh/laporan" class="text-sm font-semibold text-merah">Laporan tahfizh</router-link>
    </div>
    <div class="grid grid-cols-2 gap-3 sm:gap-4 lg:grid-cols-3 xl:grid-cols-6">
      <KartuStatistik judul="Setoran hari ini" :nilai="`${d.setoran_terisi ?? 0}/${d.setoran_dibuka ?? 0}`" :ikon="PhNotebook" warna="presensi" ke="/tahfizh/setoran"
        :keterangan="`Sesi terisi dari yang sudah dibuka (${d.setoran_total ?? 0} sesi hari ini)`" />
      <KartuStatistik judul="Capaian bulan ini" :nilai="persenCapai" :ikon="PhTarget" warna="tahfizh" ke="/tahfizh/capaian"
        :keterangan="`${d.tercapai ?? 0} tercapai · ${d.tidak_tercapai ?? 0} belum`" />
      <KartuStatistik :judul="d.ujian_untuk_saya ? 'Ujian untuk saya' : 'Ujian menunggu'" :nilai="d.ujian_untuk_saya || d.ujian_menunggu || 0" :ikon="PhExam" warna="agenda" ke="/tahfizh/ujian"
        :keterangan="d.ujian_untuk_saya ? 'Daftar tunggu dan jadwal Anda sebagai penguji' : 'Menunggu penguji atau terjadwal'" />
      <KartuStatistik judul="Usulan juz" :nilai="d.usulan_menunggu ?? 0" :ikon="PhSealCheck" warna="pengajuan" ke="/tahfizh/capaian?bagian=usulan" keterangan="Menunggu validasi" />
      <KartuStatistik judul="Rata-rata hafalan" :nilai="`${String(d.rata_juz ?? 0).replace('.', ',')} juz`" :ikon="PhBookOpenText" warna="santri" ke="/tahfizh/santri" :keterangan="`${d.santri ?? 0} santri aktif`" />
      <KartuStatistik judul="Khatam 30 juz" :nilai="d.khatam ?? 0" :ikon="PhCrown" warna="klinik" ke="/tahfizh/laporan" keterangan="Hafalan resmi 30 juz" />
    </div>
  </section>
</template>
