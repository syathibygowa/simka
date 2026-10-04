<!-- SIMKA PRO | src/components/KartuSantriBeranda.vue | v1.0 | Fase 4 – Tahap 6 Tahun ajaran, statistik, laporan | 05/10/2026 -->
<script setup>
// Kartu statistik santri langsung di beranda (admin, superadmin, dan pimpinan pemegang hak data santri).
// Diperbarui otomatis (Realtime) saat data santri atau absensi berubah.
import { computed, onMounted } from 'vue'
import { PhStudent, PhGenderMale, PhGenderFemale, PhCheckSquareOffset, PhWarningCircle, PhBooks } from '@phosphor-icons/vue'
import { useTahunAjaran } from '@/stores/tahunAjaran'
import { persen, teksPersen } from '@/lib/absensi'
import KartuStatistik from './KartuStatistik.vue'
const ta = useTahunAjaran()
onMounted(() => { ta.muatStatistik(); ta.dengarkan() })
const d = computed(() => ta.statistik || {})
const h = computed(() => d.value.hari_ini || {})
</script>
<template>
  <section>
    <div class="mb-3 flex items-center justify-between gap-2">
      <h2 class="judul-bagian">Santri hari ini</h2>
      <router-link to="/statistik-santri" class="text-sm font-semibold text-merah">Statistik lengkap</router-link>
    </div>
    <div class="grid grid-cols-2 gap-3 sm:gap-4 lg:grid-cols-3 xl:grid-cols-6">
      <KartuStatistik judul="Santri aktif" :nilai="d.aktif ?? '…'" :ikon="PhStudent" warna="santri" ke="/santri" :keterangan="`Wustha ${d.wustha ?? 0} · SMA ${d.sma ?? 0}`" />
      <KartuStatistik judul="Putra" :nilai="d.putra ?? '…'" :ikon="PhGenderMale" warna="pegawai" keterangan="Santri aktif laki-laki" />
      <KartuStatistik judul="Putri" :nilai="d.putri ?? '…'" :ikon="PhGenderFemale" warna="klinik" keterangan="Santri aktif perempuan" />
      <KartuStatistik judul="Kehadiran hari ini" :nilai="teksPersen(persen(h.hadir, h.anggota))" :ikon="PhCheckSquareOffset" warna="absensi" ke="/absensi-santri/pantauan"
        :keterangan="`${h.sesi || 0} sesi program pokok terisi`" />
      <KartuStatistik judul="Izin · Sakit · Absen" :nilai="`${h.izin || 0} · ${h.sakit || 0} · ${h.absen || 0}`" :ikon="PhWarningCircle" warna="pengajuan" keterangan="Kehadiran santri hari ini" />
      <KartuStatistik judul="Data wajib kurang" :nilai="d.data_kurang ?? '…'" :ikon="PhBooks" warna="tahfizh" ke="/santri" keterangan="NISN/tempat/tanggal lahir" />
    </div>
  </section>
</template>
