<!-- SIMKA PRO | src/pages/penilaian/Penilaian.vue | v1.3 | 14.30.0: label saringan yang sudah jelas disembunyikan (hemat ruang) | 29/10/2026 -->
<script setup>
// Menu Penilaian (kelompok menu Penilaian). v1.1: Rekap (kemajuan pengisian untuk pimpinan) dan Permintaan ubah nilai.
//   Rekap          : kemajuan pengisian rapor per kelas, guru, UTAS, ekskul (semester berjalan)
//   Permintaan     : permintaan ubah nilai setelah periode ditutup; disetujui/ditolak pengelola nilai (riwayat)
//   Periode        : periode penilaian per jenis rapor × semester (disiapkan/dibuka/ditutup), tanggal rapor, hari efektif, tema kokurikuler
//   Mapel rapor    : susunan mapel di rapor per jenis × tingkat (urutan, kelompok, KKM/KKTP, SUMBER NILAI dari mapel ajar)
//   Komponen nilai : kategori isian guru (Harian, Ulangan, UTS, UAS, …) beserta bobot, cara menentukan nilai rapor
//   Predikat       : SMA, Wustha, UTAS (bahasa Arab/Indonesia), pengembangan diri, sikap
//   Catatan        : bank kalimat catatan wali kelas, muhaffizh, dan kehadiran
//   Ketentuan      : judul, kop, label ambang, keterampilan, sikap, kokurikuler, fase, penanda tangan, juz UTAS
// Pengisian nilai tetap di menu kerja masing-masing (Guru Mapel, Tahfizh, Ekskul, Wali Kelas) mulai tahap berikutnya.
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { PhCalendarCheck, PhListNumbers, PhScales, PhMedal, PhChatText, PhGearSix, PhLockSimple, PhExam, PhChartBar, PhPencilLine } from '@phosphor-icons/vue'
import { usePenilaian } from '@/stores/penilaian'
import { useKelompokSantri } from '@/stores/kelompokSantri'
import { useUI } from '@/stores/ui'
import BilahTab from '@/components/BilahTab.vue'
import TabPeriodeNilai from './TabPeriodeNilai.vue'
import TabMapelRapor from './TabMapelRapor.vue'
import TabKomponenNilai from './TabKomponenNilai.vue'
import TabPredikatNilai from './TabPredikatNilai.vue'
import TabKalimatRapor from './TabKalimatRapor.vue'
import TabKetentuanNilai from './TabKetentuanNilai.vue'
import TabRekapNilai from './TabRekapNilai.vue'
import TabPermintaanNilai from './TabPermintaanNilai.vue'
import { useUbahNilai } from '@/stores/ubahNilai'

const props = defineProps({ tab: { type: String, default: '' } })
const router = useRouter(); const pn = usePenilaian(); const kel = useKelompokSantri(); const ui = useUI()
const un = useUbahNilai(); const ta = ref(''); const galat = ref('')
async function muat() { galat.value = ''; try { await pn.muat(ta.value) } catch (e) { galat.value = e.message } }
onMounted(async () => { un.muat('menunggu').catch(() => {}); try { await kel.muat() } catch { /* daftar tahun ajaran tidak tersedia */ } ta.value = kel.taAktif?.id || kel.tahunAjaran[0]?.id || ''; await muat() })
async function gantiTA() { await muat(); if (galat.value) ui.toast(galat.value, 'galat') }

const kurangSumber = computed(() => pn.mapel.filter((m) => m.aktif && m.sumber === 'mapel' && !(m.sumber_mapel || []).length).length)
const dibuka = computed(() => pn.periode.filter((p) => p.status === 'dibuka').length)
const TAB = computed(() => [
  { k: 'rekap', n: 'Rekap', ikon: PhChartBar, w: 'laporan' },
  { k: 'permintaan', n: 'Permintaan ubah nilai', ikon: PhPencilLine, w: 'pengajuan', lencana: un.menunggu || null },
  { k: 'periode', n: 'Periode', ikon: PhCalendarCheck, w: 'agenda', jumlah: dibuka.value ? `${dibuka.value} dibuka` : null },
  { k: 'mapel', n: 'Mapel rapor', ikon: PhListNumbers, w: 'rapor', lencana: kurangSumber.value || null },
  { k: 'komponen', n: 'Komponen nilai', ikon: PhScales, w: 'gurumapel' },
  { k: 'predikat', n: 'Predikat', ikon: PhMedal, w: 'prestasi' },
  { k: 'catatan', n: 'Catatan otomatis', ikon: PhChatText, w: 'walikelas' },
  { k: 'ketentuan', n: 'Ketentuan rapor', ikon: PhGearSix, w: 'pengaturan' },
])
const aktif = computed(() => (TAB.value.some((t) => t.k === props.tab) ? props.tab : 'rekap'))
const pindah = (x) => router.replace(`/penilaian/${x}`)
const bisaUbah = computed(() => pn.bolehAtur() && !pn.terkunci)
</script>
<template>
  <div class="w-penilaian">
    <section class="kartu kepala mb-4 flex flex-wrap items-center gap-3 p-4 sm:p-5">
      <span class="chip-ikon h-12 w-12"><PhExam :size="26" weight="duotone" /></span>
      <div class="min-w-0 flex-1 basis-[55%]">
        <h2 class="text-lg font-bold">Penilaian dan rapor</h2>
        <p class="text-sm text-teks2">Rapor SMA (Kurikulum Merdeka), Rapor Wustha (K13 disesuaikan), dan Rapor Tahfizh. Pengaturan berlaku per tahun ajaran dan disalin otomatis ke tahun ajaran berikutnya.</p>
      </div>
      <div class="w-full sm:w-56"><label class="label-isian sr-only" for="pn-ta">Tahun ajaran</label>
        <select id="pn-ta" v-model="ta" class="isian" @change="gantiTA">
          <option v-for="t in kel.tahunAjaran" :key="t.id" :value="t.id">{{ t.nama }}{{ t.aktif ? ' (aktif)' : '' }}{{ t.terkunci ? ' – arsip' : '' }}</option></select></div>
      <p v-if="pn.dimuat && !bisaUbah" class="flex w-full items-center gap-2 text-sm text-teks3"><PhLockSimple :size="16" />
        {{ pn.terkunci ? 'Tahun ajaran ini sudah dikunci sebagai arsip (baca saja).' : 'Baca saja. Pengaturan diubah oleh admin ber-izin "Mengatur penilaian" atau pimpinan bidang terkait.' }}</p>
    </section>

    <div v-if="galat" class="kartu w-klinik flex flex-wrap items-center gap-3 p-5">
      <p class="min-w-[200px] flex-1 text-sm font-semibold" style="color: var(--c)">Pengaturan penilaian gagal dimuat: {{ galat }} Pastikan migrasi SQL 8200 sudah dijalankan.</p>
      <button class="tombol-utama" @click="muat">Coba lagi</button>
    </div>
    <template v-else-if="pn.dimuat && pn.ta">
      <BilahTab class="mb-4" :tab="TAB" :model-value="aktif" label="Bagian pengaturan penilaian" @update:model-value="pindah" />
      <TabRekapNilai v-if="aktif === 'rekap'" @permintaan="pindah('permintaan')" />
      <TabPermintaanNilai v-else-if="aktif === 'permintaan'" />
      <TabPeriodeNilai v-else-if="aktif === 'periode'" />
      <TabMapelRapor v-else-if="aktif === 'mapel'" />
      <TabKomponenNilai v-else-if="aktif === 'komponen'" />
      <TabPredikatNilai v-else-if="aktif === 'predikat'" />
      <TabKalimatRapor v-else-if="aktif === 'catatan'" />
      <TabKetentuanNilai v-else />
    </template>
    <p v-else-if="pn.dimuat" class="kartu p-8 text-center text-sm text-teks3">Belum ada tahun ajaran. Tambahkan tahun ajaran di Setelan → Kalender.</p>
    <p v-else class="kartu p-8 text-center text-sm text-teks3">Memuat pengaturan penilaian…</p>
  </div>
</template>
<style scoped>
.kepala { background: linear-gradient(135deg, color-mix(in srgb, var(--c) 12%, rgb(var(--permukaan))), rgb(var(--permukaan)) 70%); }
</style>
