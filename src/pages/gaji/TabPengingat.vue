<!-- SIMKA PRO | src/pages/gaji/TabPengingat.vue | v1.1 | 14.13.0: tombol disederhanakan (Pratinjau, Ekspor, Impor, Cetak Rekap) | 19/10/2026 -->
<script setup>
// Pengingat kenaikan (Blueprint Bagian 36):
//   • Pegawai yang naik tingkat masa kerja pada bulan terpilih (bawaan bulan ini; ada pilihan bulan depan) beserta selisih tunjangan.
//     Kenaikan sudah otomatis terhitung saat periode gaji bulan itu dibuat atau dihitung ulang.
//   • Perubahan data penentu gaji 60 hari terakhir (status, pendidikan, level muhaffizh, kategori honorer, jabatan).
// Setiap tanggal 1 pukul 07.00 WITA pengelola gaji menerima notifikasi kenaikan masa kerja bulan berikutnya.
import { ref, computed, onMounted, watch } from 'vue'
import * as XLSX from 'xlsx'
import { PhTrendUp, PhClockCounterClockwise, PhFileXls, PhArrowRight, PhCalendarBlank } from '@phosphor-icons/vue'
import { useGaji } from '@/stores/gaji'
import { useUI } from '@/stores/ui'
import { formatPendek, formatPanjang, formatWaktu, hariIniISO, BULAN } from '@/lib/tanggal'
import { rupiah } from '@/lib/gaji'
import { PENDIDIKAN, STATUS_PEGAWAI, LEVEL_MUHAFFIZH, KATEGORI_HONORER } from '@/lib/kepegawaian'
import KartuStatistik from '@/components/KartuStatistik.vue'

const gaji = useGaji(); const ui = useUI()
const awal = hariIniISO().slice(0, 8) + '01'
const tambahBulan = (iso, n) => new Date(Date.UTC(Number(iso.slice(0, 4)), Number(iso.slice(5, 7)) - 1 + n, 1)).toISOString().slice(0, 10)
const PILIHAN = Array.from({ length: 14 }, (_, i) => tambahBulan(awal, i - 1))
const bulan = ref(awal); const d = ref(null); const memuat = ref(true)
async function muat() { memuat.value = true; try { d.value = await gaji.pengingat(bulan.value) } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false } }
onMounted(muat)
watch(bulan, muat)
const nama = (iso) => `${BULAN[Number(iso.slice(5, 7)) - 1]} ${iso.slice(0, 4)}`
const totalSelisih = computed(() => (d.value?.masa_kerja || []).reduce((a, x) => a + Number(x.selisih), 0))

const JENIS = { status_kepegawaian: 'Status kepegawaian', pendidikan: 'Pendidikan', level_muhaffizh: 'Level muhaffizh', kategori_honorer: 'Kategori honorer',
  jabatan_struktural: 'Jabatan struktural', jabatan_fungsional: 'Jabatan fungsional' }
const NILAI = { status_kepegawaian: STATUS_PEGAWAI, pendidikan: PENDIDIKAN, level_muhaffizh: LEVEL_MUHAFFIZH, kategori_honorer: KATEGORI_HONORER }
const teks = (jenis, v) => (v == null || v === '' ? '–' : NILAI[jenis]?.[v] || v)

function ekspor() {
  const wb = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet([['NIY', 'Nama', 'TMT', 'Naik pada', 'Masa kerja baru (tahun)', 'Tunjangan lama', 'Tunjangan baru', 'Selisih'],
    ...(d.value?.masa_kerja || []).map((x) => [x.niy || '', x.nama, formatPendek(x.tmt), formatPendek(x.tanggal), x.tahun_baru, Number(x.tarif_lama), Number(x.tarif_baru), Number(x.selisih)])]), 'Masa kerja')
  XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet([['NIY', 'Nama', 'Perubahan', 'Sebelumnya', 'Menjadi', 'Dicatat', 'Oleh'],
    ...(d.value?.perubahan || []).map((x) => [x.niy || '', x.nama, JENIS[x.jenis] || x.jenis, teks(x.jenis, x.nilai_lama), teks(x.jenis, x.nilai_baru), formatWaktu(x.dicatat), x.oleh || ''])]), 'Perubahan data')
  XLSX.writeFile(wb, `Pengingat-Kenaikan-${nama(bulan.value).replace(' ', '-')}.xlsx`)
}
</script>
<template>
  <div>
    <div class="mb-4 flex flex-wrap items-end gap-2">
      <div class="w-56"><label class="label-isian" for="pk-bln"><PhCalendarBlank :size="14" class="inline" /> Bulan</label>
        <select id="pk-bln" v-model="bulan" class="isian"><option v-for="b in PILIHAN" :key="b" :value="b">{{ nama(b) }}{{ b === awal ? ' (bulan ini)' : '' }}</option></select></div>
      <p class="min-w-[220px] flex-1 text-sm text-teks3">Kenaikan masa kerja otomatis terhitung pada periode gaji bulan tersebut. Notifikasi dikirim setiap tanggal 1 untuk bulan berikutnya.</p>
      <button class="tombol-garis" :disabled="!d" @click="ekspor"><PhFileXls :size="20" weight="duotone" /> Ekspor</button>
    </div>
    <p v-if="memuat" class="kartu p-8 text-center text-sm text-teks3">Memuat…</p>
    <template v-else-if="d">
      <div class="-mx-4 mb-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-3 sm:overflow-visible sm:px-0">
        <KartuStatistik class="w-[44%] shrink-0 snap-start sm:w-auto" judul="Naik masa kerja" :nilai="d.masa_kerja.length" :ikon="PhTrendUp" warna="presensi" :keterangan="nama(bulan)" />
        <KartuStatistik class="w-[72%] shrink-0 snap-start sm:w-auto" judul="Tambahan tunjangan" :nilai="rupiah(totalSelisih)" :ikon="PhTrendUp" warna="tahfizh" keterangan="Per bulan, mulai bulan ini" />
        <KartuStatistik class="w-[44%] shrink-0 snap-start sm:w-auto" judul="Perubahan data" :nilai="d.perubahan.length" :ikon="PhClockCounterClockwise" warna="verifikasi" keterangan="60 hari terakhir" />
      </div>
      <div class="grid gap-4 xl:grid-cols-2">
        <section class="kartu w-presensi p-4 sm:p-5">
          <h3 class="judul-bagian mb-2 flex items-center gap-2"><PhTrendUp :size="20" weight="duotone" style="color: var(--c)" /> Naik masa kerja – {{ nama(bulan) }}</h3>
          <p v-if="!d.masa_kerja.length" class="rounded-xl bg-permukaan2 p-3 text-sm text-teks3">Tidak ada pegawai yang naik tingkat masa kerja pada bulan ini.</p>
          <ul v-else class="divide-y divide-garis">
            <li v-for="x in d.masa_kerja" :key="x.employee_id" class="flex flex-wrap items-center gap-2 py-2.5">
              <div class="min-w-[160px] flex-1"><p class="font-semibold">{{ x.nama }}</p>
                <p class="text-xs text-teks3">NIY {{ x.niy || '–' }} · TMT {{ formatPendek(x.tmt) }} · genap {{ x.tahun_baru }} tahun pada {{ formatPanjang(x.tanggal) }}</p></div>
              <p class="flex items-center gap-1 text-sm tabular-nums text-teks2">{{ rupiah(x.tarif_lama) }} <PhArrowRight :size="14" /> <span class="font-bold text-teks">{{ rupiah(x.tarif_baru) }}</span></p>
              <span class="lencana w-presensi">+{{ rupiah(x.selisih) }}</span>
            </li>
          </ul>
          <p class="mt-2 text-xs text-teks3">Tunjangan masa kerja dihitung dari tahun penuh sejak TMT, paling banyak 12 tahun. Honorer tidak termasuk.</p>
        </section>
        <section class="kartu w-verifikasi p-4 sm:p-5">
          <h3 class="judul-bagian mb-2 flex items-center gap-2"><PhClockCounterClockwise :size="20" weight="duotone" style="color: var(--c)" /> Perubahan data penentu gaji</h3>
          <p v-if="!d.perubahan.length" class="rounded-xl bg-permukaan2 p-3 text-sm text-teks3">Tidak ada perubahan dalam 60 hari terakhir.</p>
          <ul v-else class="divide-y divide-garis">
            <li v-for="(x, i) in d.perubahan" :key="i" class="py-2.5">
              <p class="font-semibold">{{ x.nama }} <span class="text-xs font-normal text-teks3">NIY {{ x.niy || '–' }}</span></p>
              <p class="flex flex-wrap items-center gap-1 text-sm"><span class="lencana w-verifikasi">{{ JENIS[x.jenis] || x.jenis }}</span>
                {{ teks(x.jenis, x.nilai_lama) }} <PhArrowRight :size="14" /> <b>{{ teks(x.jenis, x.nilai_baru) }}</b></p>
              <p class="text-xs text-teks3">{{ formatWaktu(x.dicatat) }}{{ x.oleh ? ' · ' + x.oleh : '' }}</p>
            </li>
          </ul>
          <p class="mt-2 text-xs text-teks3">Perubahan ini terhitung pada periode gaji yang dibuat atau dihitung ulang sesudahnya. Periode yang sudah terbit tidak berubah.</p>
        </section>
      </div>
    </template>
  </div>
</template>
