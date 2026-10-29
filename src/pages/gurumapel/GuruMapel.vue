<!-- SIMKA PRO | src/pages/gurumapel/GuruMapel.vue | v1.5 | 14.32.0: tab Pantauan harian dan Rekap periode terpisah | 29/10/2026 -->
<script setup>
// Menu Guru Mapel. Guru melihat tugas mengajarnya; admin, superadmin, dan pimpinan (pemegang hak Jadwal mengajar menurut
// jenjangnya) memantau seluruh guru. Tab:
//   Pantauan (pemantau) : jurnal mengajar per tanggal (jam terlaksana/belum diisi per guru, WA pengingat) dan rekap
//                         keterlaksanaan per guru untuk satu periode (cetak F4, Excel)
//   Hari ini (guru)     : jadwal mengajar hari ini dan status jurnalnya, tombol isi jurnal, jurnal kemarin yang belum diisi,
//                         kelas dan mapel yang diampu beserta wali kelasnya
//   Jadwal              : jadwal mengajar pekanan (pemantau dapat memilih guru)
//   Rekap               : keterlaksanaan mengajar per kelas/mapel untuk satu periode; cetak laporan individu F4
//   Jurnal mengajar   : (14.4.0) laporan jurnal per kelas–mapel, per mapel, atau semua; cetak F4 dan Excel
//   Kehadiran santri  : (14.3.0) kehadiran santri per mapel yang diampu dari absensi jurnal mengajar
//   Nilai (Fase 12)     : isian nilai per kelas–mapel dan semester (guru: miliknya; pengelola nilai/pimpinan: semua)
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { PhBroadcast, PhPresentationChart, PhSun, PhGridFour, PhChartBar, PhLockSimple, PhExam, PhUserCheck, PhNotebook } from '@phosphor-icons/vue'
import { useSesi } from '@/stores/sesi'
import BilahTab from '@/components/BilahTab.vue'
import TabPantauGuru from './TabPantauGuru.vue'
import TabHariIniGuru from './TabHariIniGuru.vue'
import TabJadwalGuru from './TabJadwalGuru.vue'
import TabRekapGuru from './TabRekapGuru.vue'
import TabNilaiGuru from './TabNilaiGuru.vue'
import TabKehadiranGuru from './TabKehadiranGuru.vue'
import TabJurnalGuru from './TabJurnalGuru.vue'

const props = defineProps({ tab: { type: String, default: '' } })
const router = useRouter(); const sesi = useSesi()
const pemantau = computed(() => sesi.isAdmin || sesi.luas('jadwal_mengajar') || sesi.tingkat('jadwal_mengajar') >= 3 || !!sesi.tugas?.pimpinan)
const mengajar = computed(() => !!sesi.tugas?.mengajar)
const TAB = computed(() => [
  // 14.32.0: pengontrolan harian dan rekap periode sebagai dua tab
  ...(pemantau.value ? [{ k: 'pantauan', n: 'Pantauan harian', ikon: PhBroadcast, w: 'gurumapel' }, { k: 'periode', n: 'Rekap periode', ikon: PhPresentationChart, w: 'agenda' }] : []),
  ...(mengajar.value ? [{ k: 'hari', n: 'Hari ini', ikon: PhSun, w: 'beranda' }] : []),
  ...(mengajar.value || pemantau.value ? [{ k: 'jadwal', n: 'Jadwal mengajar', ikon: PhGridFour, w: 'jadwal' }, { k: 'rekap', n: 'Rekap mengajar', ikon: PhChartBar, w: 'rekap' }, { k: 'jurnal', n: 'Jurnal mengajar', ikon: PhNotebook, w: 'tatausaha' }, { k: 'kehadiran', n: 'Kehadiran santri', ikon: PhUserCheck, w: 'presensi' }] : []),
  ...(mengajar.value || pemantau.value || sesi.penilaian ? [{ k: 'nilai', n: 'Nilai', ikon: PhExam, w: 'penilaian' }] : []),
])
const aktif = computed(() => (TAB.value.some((t) => t.k === props.tab) ? props.tab : TAB.value[0]?.k))
</script>
<template>
  <div class="w-gurumapel">
    <div v-if="!TAB.length" class="kartu flex items-center gap-3 p-5">
      <span class="chip-ikon h-11 w-11"><PhLockSimple :size="24" weight="duotone" /></span>
      <p class="text-sm text-teks2">Anda belum memiliki penugasan mengajar pada tahun ajaran aktif. Penugasan guru mapel diatur admin di menu Jadwal Pelajaran → Penugasan.</p>
    </div>
    <template v-else>
      <BilahTab class="mb-4" :tab="TAB" :model-value="aktif" label="Bagian guru mapel" @update:model-value="(x) => router.replace(`/guru-mapel/${x}`)" />
      <TabPantauGuru v-if="aktif === 'pantauan'" key="harian" mode="harian" />
      <TabPantauGuru v-else-if="aktif === 'periode'" key="periode" mode="periode" />
      <TabHariIniGuru v-else-if="aktif === 'hari'" />
      <TabJadwalGuru v-else-if="aktif === 'jadwal'" :pemantau="pemantau" :mengajar="mengajar" />
      <TabNilaiGuru v-else-if="aktif === 'nilai'" />
      <TabJurnalGuru v-else-if="aktif === 'jurnal'" :pemantau="pemantau" :mengajar="mengajar" />
      <TabKehadiranGuru v-else-if="aktif === 'kehadiran'" :pemantau="pemantau" />
      <TabRekapGuru v-else :pemantau="pemantau" :mengajar="mengajar" />
    </template>
  </div>
</template>
