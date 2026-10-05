<!-- SIMKA PRO | src/pages/ekskul/TabDasborEkskul.vue | v1.0 | Fase 6 – Tahap 4 Lapor ke bidang dan dasbor ringkasan | 06/10/2026 -->
<script setup>
// Dasbor ekskul: perkembangan setiap ekskul pada periode — pertemuan terjadwal vs terlaksana, kehadiran anggota,
// jurnal materi terisi, dan pertemuan terakhir. Admin/pimpinan melihat semua ekskul; pembina melihat ekskul binaannya.
import { ref, computed, watch, onMounted } from 'vue'
import { PhChartLineUp, PhCalendarCheck, PhUsersThree, PhNotebook, PhMedal } from '@phosphor-icons/vue'
import { useAbsensiSantri } from '@/stores/absensiSantri'
import { useUI } from '@/stores/ui'
import { teksPersen } from '@/lib/absensi'
import { awalPekan, awalBulanDari, akhirBulanDari, tambahHari, teksRentang } from '@/lib/musyrif'
import { hariIniISO, formatPendek } from '@/lib/tanggal'
import KartuStatistik from '@/components/KartuStatistik.vue'

const emit = defineEmits(['rekap'])
const abs = useAbsensiSantri(); const ui = useUI(); const hari = hariIniISO()
const PERIODE = [{ k: 'pekan', n: 'Pekan ini', m: awalPekan(hari), s: hari }, { k: 'bulan', n: 'Bulan ini', m: awalBulanDari(hari), s: hari },
  { k: 'lalu', n: 'Bulan lalu', m: awalBulanDari(tambahHari(awalBulanDari(hari), -1)), s: akhirBulanDari(tambahHari(awalBulanDari(hari), -1)) },
  { k: 'semester', n: '6 bulan', m: tambahHari(hari, -182), s: hari }]
const periode = ref('bulan'); const data = ref([]); const memuat = ref(false)
const p = computed(() => PERIODE.find((x) => x.k === periode.value))
async function muat() { memuat.value = true; try { data.value = await abs.ringkasanEkskul(p.value.m, p.value.s) } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false } }
onMounted(muat)
watch(periode, muat)
const jumlah = (k) => data.value.reduce((a, x) => a + (Number(x[k]) || 0), 0)
const statistik = computed(() => [
  { judul: 'Kehadiran anggota', nilai: teksPersen(jumlah('anggota') ? Math.round((jumlah('hadir') / jumlah('anggota')) * 1000) / 10 : null), ikon: PhChartLineUp, warna: 'ekskul', ket: `${data.value.length} ekskul` },
  { judul: 'Pertemuan terlaksana', nilai: `${jumlah('pertemuan_terlaksana')}/${jumlah('pertemuan_rencana')}`, ikon: PhCalendarCheck, warna: 'agenda', ket: 'Terlaksana / terjadwal' },
  { judul: 'Anggota aktif', nilai: jumlah('anggota_aktif'), ikon: PhUsersThree, warna: 'santri', ket: 'Seluruh ekskul' },
  { judul: 'Jurnal materi', nilai: jumlah('jurnal_terisi'), ikon: PhNotebook, warna: 'laporan', ket: 'Pertemuan berjurnal' },
])
const warna = (v) => (v == null ? 'w-hakakses' : v >= 90 ? 'w-presensi' : v >= 75 ? 'w-agenda' : v >= 60 ? 'w-laporan' : 'w-klinik')
const keterlaksanaan = (x) => (x.pertemuan_rencana ? Math.min(100, Math.round((x.pertemuan_terlaksana / x.pertemuan_rencana) * 100)) : null)
</script>
<template>
  <div>
    <div class="mb-3 flex flex-wrap items-center gap-2">
      <button v-for="x in PERIODE" :key="x.k" :class="['min-h-[36px] rounded-full border px-3 text-sm font-semibold', periode === x.k ? 'border-transparent bg-[#9D174D] text-white' : 'border-garis bg-permukaan text-teks2']" @click="periode = x.k">{{ x.n }}</button>
      <span class="text-xs text-teks3">{{ teksRentang(p.m, p.s) }}</span>
    </div>
    <div class="-mx-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-4 sm:overflow-visible sm:px-0">
      <KartuStatistik v-for="k in statistik" :key="k.judul" class="w-[44%] shrink-0 snap-start sm:w-auto" :judul="k.judul" :nilai="memuat && !data.length ? '…' : k.nilai" :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket" />
    </div>
    <ul class="mt-4 grid gap-3 md:grid-cols-2 xl:grid-cols-3">
      <li v-for="x in data" :key="x.id" class="kartu p-4" :class="warna(x.persen)">
        <div class="flex items-start gap-3">
          <span class="chip-ikon h-11 w-11 shrink-0"><PhMedal :size="24" weight="duotone" /></span>
          <div class="min-w-0 flex-1"><b class="block truncate">{{ x.nama }}</b><span class="block truncate text-xs text-teks3">{{ x.anggota_aktif }} anggota · {{ x.pembina || 'belum ada pembina' }}</span></div>
          <span class="text-2xl font-extrabold tabular-nums" style="color: var(--c)">{{ teksPersen(x.persen) }}</span>
        </div>
        <div class="mt-3 h-2 overflow-hidden rounded-full bg-permukaan2" role="img" :aria-label="`Keterlaksanaan pertemuan ${keterlaksanaan(x) ?? 0}%`">
          <div class="h-full rounded-full" :style="{ width: (keterlaksanaan(x) ?? 0) + '%', background: 'var(--c)' }" /></div>
        <p class="mt-1 text-xs text-teks3">Pertemuan {{ x.pertemuan_terlaksana }}/{{ x.pertemuan_rencana }} · jurnal materi {{ x.jurnal_terisi }}</p>
        <div class="mt-2 flex flex-wrap gap-1.5 text-xs"><span class="lencana w-pengajuan">I {{ x.izin }}</span><span class="lencana w-klinik">S {{ x.sakit }}</span><span class="lencana w-beranda">A {{ x.absen }}</span></div>
        <p class="mt-2 text-xs text-teks2">Terakhir: {{ x.terakhir ? formatPendek(x.terakhir.tanggal) + (x.terakhir.topik ? ' · ' + x.terakhir.topik : '') : 'belum ada pertemuan' }}</p>
      </li>
    </ul>
    <p v-if="!data.length && !memuat" class="kartu mt-4 p-8 text-center text-sm text-teks3">Belum ada ekskul aktif.</p>
    <button class="tombol-teks mt-3 text-sm" @click="emit('rekap')">Buka rekap kehadiran dan jurnal materi per ekskul</button>
  </div>
</template>
