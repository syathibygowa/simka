<!-- SIMKA PRO | src/pages/santri/StatistikSantri.vue | v1.0 | Fase 4 – Tahap 6 Tahun ajaran, statistik, laporan | 05/10/2026 -->
<script setup>
// Statistik dan laporan data santri: jumlah per jenjang dan kelas (putra/putri), kohort angkatan (masuk, aktif,
// lulus, keluar, retensi), kehadiran hari ini. Ekspor Excel dan cetak F4 "Rekapitulasi Jumlah Santri".
import { computed, onMounted, ref } from 'vue'
import * as XLSX from 'xlsx'
import { PhStudent, PhGraduationCap, PhSignOut, PhUsersThree, PhDownloadSimple, PhEye, PhCalendarPlus } from '@phosphor-icons/vue'
import { useTahunAjaran } from '@/stores/tahunAjaran'
import { useKelompokSantri } from '@/stores/kelompokSantri'
import { useSesi } from '@/stores/sesi'
import { JENJANG, JENJANG_PENDEK } from '@/lib/santri'
import { persen, teksPersen } from '@/lib/absensi'
import { hariIniISO, formatPanjang } from '@/lib/tanggal'
import { ambilPenandaTangan } from '@/lib/penandatangan'
import KartuSantriBeranda from '@/components/KartuSantriBeranda.vue'
import KartuStatistik from '@/components/KartuStatistik.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const ta = useTahunAjaran(); const kel = useKelompokSantri(); const sesi = useSesi()
const pratinjau = ref(false); const pimpinan = ref({ jabatan: 'Direktur', nama: '', niy: '' })
onMounted(async () => { await Promise.all([ta.muatStatistik(), kel.muat()]); pimpinan.value = await ambilPenandaTangan('Direktur') })
const d = computed(() => ta.statistik || { per_tingkat: [], kohort: [] })
const bolehGantiTA = computed(() => sesi.isSuperadmin || (sesi.bolehAdmin('kelola_santri') && sesi.bolehAdmin('kelompok_santri')))
const perJenjang = computed(() => ['wustha', 'sma'].map((j) => {
  const r = d.value.per_tingkat.filter((x) => x.jenjang === j)
  return { j, r, L: r.reduce((n, x) => n + x.L, 0), P: r.reduce((n, x) => n + x.P, 0) }
}))
const maks = computed(() => Math.max(1, ...d.value.per_tingkat.map((x) => x.L + x.P)))
const totalL = computed(() => perJenjang.value.reduce((n, x) => n + x.L, 0)); const totalP = computed(() => perJenjang.value.reduce((n, x) => n + x.P, 0))

function ekspor() {
  const wb = XLSX.utils.book_new()
  const a = [['Jenjang', 'Kelas', 'Putra', 'Putri', 'Jumlah'], ...d.value.per_tingkat.map((x) => [JENJANG[x.jenjang], x.tingkat, x.L, x.P, x.L + x.P]), ['Jumlah', '', totalL.value, totalP.value, totalL.value + totalP.value]]
  XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet(a), 'Per kelas')
  const b = [['Angkatan', 'Tahun masuk', 'Jumlah masuk', 'Aktif', 'Lulus', 'Keluar', 'Retensi (%)'], ...d.value.kohort.map((k) => [k.angkatan, k.tahun_masuk, k.total, k.aktif, k.lulus, k.keluar, persen(k.aktif + k.lulus, k.total) ?? ''])]
  XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet(b), 'Kohort angkatan')
  XLSX.writeFile(wb, `Statistik-Santri-${hariIniISO()}.xlsx`)
}
</script>
<template>
  <div class="space-y-5">
    <KartuSantriBeranda />
    <div class="grid grid-cols-2 gap-3 sm:gap-4 lg:grid-cols-4">
      <KartuStatistik judul="Nonaktif sementara" :nilai="d.nonaktif ?? '…'" :ikon="PhUsersThree" warna="tahfizh" keterangan="Masih terdata, tidak mengikuti kegiatan" />
      <KartuStatistik judul="Lulus" :nilai="d.lulus ?? '…'" :ikon="PhGraduationCap" warna="laporan" keterangan="Alumni tercatat" />
      <KartuStatistik judul="Keluar" :nilai="d.keluar ?? '…'" :ikon="PhSignOut" warna="hakakses" keterangan="Mutasi keluar dan berhenti" />
      <KartuStatistik judul="Angkatan" :nilai="d.kohort.length" :ikon="PhStudent" warna="agenda" keterangan="Kohort yang terdata" />
    </div>

    <div class="-mx-4 flex gap-2 overflow-x-auto px-4 pb-1 lg:mx-0 lg:px-0">
      <button class="w-santri tombol-garis shrink-0 px-4 text-sm" @click="ekspor"><PhDownloadSimple :size="20" weight="duotone" style="color: var(--c)" /> Excel</button>
      <button class="w-pengajuan tombol-garis shrink-0 px-4 text-sm" @click="pratinjau = true"><PhEye :size="20" weight="duotone" style="color: var(--c)" /> Cetak rekapitulasi</button>
      <router-link v-if="bolehGantiTA" to="/tahun-ajaran-baru" class="w-agenda tombol-garis shrink-0 px-4 text-sm"><PhCalendarPlus :size="20" weight="duotone" style="color: var(--c)" /> Pergantian tahun ajaran</router-link>
    </div>

    <div class="grid gap-4 lg:grid-cols-2">
      <section class="kartu w-santri p-5">
        <h2 class="judul-bagian mb-3">Santri aktif per kelas</h2>
        <div v-for="x in perJenjang" :key="x.j" class="mb-4">
          <p class="mb-2 text-sm font-bold text-teks2">{{ JENJANG[x.j] }} · {{ x.L + x.P }} santri (putra {{ x.L }}, putri {{ x.P }})</p>
          <ul class="space-y-2">
            <li v-for="r in x.r" :key="r.tingkat" class="flex items-center gap-3 text-sm">
              <span class="w-16 shrink-0 font-semibold">Kelas {{ r.tingkat }}</span>
              <span class="flex h-6 flex-1 overflow-hidden rounded-full bg-permukaan2" :aria-label="`Putra ${r.L}, putri ${r.P}`">
                <span class="h-full bg-[#2F5FA8] dark:bg-[#8FB3F0]" :style="{ width: (r.L / maks) * 100 + '%' }" />
                <span class="h-full bg-[#B42A5E] dark:bg-[#F49AB9]" :style="{ width: (r.P / maks) * 100 + '%' }" />
              </span>
              <span class="w-20 shrink-0 text-right tabular-nums text-teks2">{{ r.L }} · {{ r.P }}</span>
            </li>
            <li v-if="!x.r.length" class="text-sm text-teks3">Belum ada santri aktif.</li>
          </ul>
        </div>
        <p class="flex gap-4 text-xs text-teks3"><span><span class="mr-1 inline-block h-2.5 w-2.5 rounded-full bg-[#2F5FA8] dark:bg-[#8FB3F0]" />Putra</span><span><span class="mr-1 inline-block h-2.5 w-2.5 rounded-full bg-[#B42A5E] dark:bg-[#F49AB9]" />Putri</span></p>
      </section>

      <section class="kartu w-agenda overflow-x-auto p-5">
        <h2 class="judul-bagian mb-1">Kohort angkatan</h2>
        <p class="mb-3 text-sm text-teks3">Retensi = (aktif + lulus) ÷ jumlah masuk angkatan.</p>
        <table class="w-full min-w-[420px] text-left text-sm">
          <thead class="border-b border-garis text-teks2"><tr><th class="py-2 font-bold">Angkatan</th><th class="py-2 text-center font-bold">Masuk</th><th class="py-2 text-center font-bold">Aktif</th>
            <th class="py-2 text-center font-bold">Lulus</th><th class="py-2 text-center font-bold">Keluar</th><th class="py-2 text-center font-bold">Retensi</th></tr></thead>
          <tbody class="divide-y divide-garis">
            <tr v-for="k in d.kohort" :key="k.angkatan"><td class="py-2 font-semibold">{{ k.angkatan }} <span class="font-normal text-teks3">({{ k.tahun_masuk }})</span></td>
              <td class="py-2 text-center tabular-nums">{{ k.total }}</td><td class="py-2 text-center tabular-nums">{{ k.aktif }}</td><td class="py-2 text-center tabular-nums">{{ k.lulus }}</td>
              <td class="py-2 text-center tabular-nums">{{ k.keluar }}</td><td class="py-2 text-center font-bold tabular-nums">{{ teksPersen(persen(k.aktif + k.lulus, k.total)) }}</td></tr>
          </tbody>
        </table>
      </section>
    </div>

    <DokumenCetak kop="pondok" judul="Rekapitulasi Jumlah Santri" :subjudul="`Tahun Ajaran ${kel.taAktif?.nama || ''} · keadaan ${formatPanjang(hariIniISO())}`" v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap">
      <table class="tabel">
        <thead><tr><th style="width:8%">No.</th><th>Jenjang</th><th style="width:14%">Kelas</th><th style="width:14%">Putra</th><th style="width:14%">Putri</th><th style="width:14%">Jumlah</th></tr></thead>
        <tbody>
          <tr v-for="(r, i) in d.per_tingkat" :key="r.jenjang + r.tingkat"><td class="tengah">{{ i + 1 }}</td><td>{{ JENJANG[r.jenjang] }}</td><td class="tengah">{{ r.tingkat }}</td>
            <td class="tengah">{{ r.L }}</td><td class="tengah">{{ r.P }}</td><td class="tengah">{{ r.L + r.P }}</td></tr>
          <tr><td colspan="3" class="tengah"><b>Jumlah</b></td><td class="tengah">{{ totalL }}</td><td class="tengah">{{ totalP }}</td><td class="tengah">{{ totalL + totalP }}</td></tr>
        </tbody>
      </table>
      <p style="margin: 8pt 0 4pt">Kohort angkatan</p>
      <table class="tabel">
        <thead><tr><th>Angkatan</th><th>Tahun masuk</th><th>Jumlah masuk</th><th>Aktif</th><th>Lulus</th><th>Keluar</th><th>Retensi</th></tr></thead>
        <tbody><tr v-for="k in d.kohort" :key="k.angkatan"><td class="tengah">{{ k.angkatan }}</td><td class="tengah">{{ k.tahun_masuk }}</td><td class="tengah">{{ k.total }}</td>
          <td class="tengah">{{ k.aktif }}</td><td class="tengah">{{ k.lulus }}</td><td class="tengah">{{ k.keluar }}</td><td class="tengah">{{ teksPersen(persen(k.aktif + k.lulus, k.total)) }}</td></tr></tbody>
      </table>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: pimpinan.jabatan, nama: pimpinan.nama, niy: pimpinan.niy }"
          :kanan="{ jabatan: sesi.isSuperadmin ? 'Pengelola Sistem' : 'Petugas Data Santri', nama: sesi.pengguna?.nama_lengkap, niy: sesi.pengguna?.niy }" />
      </template>
    </DokumenCetak>
  </div>
</template>
