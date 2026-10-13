<!-- SIMKA PRO | src/pages/penilaian/cetak/LegerRapor.vue | v1.0 | Fase 12 – Tahap 5 Leger dan laporan ketercapaian | 13/10/2026 -->
<script setup>
// Leger nilai (seragam SMA dan Wustha, F4 mendatar): nilai setiap mapel rapor, jumlah, rata-rata, peringkat, sikap
// (terbanyak dari isian guru; untuk SMA sikap hanya tampil di leger), dan ketidakhadiran (S, I, A dalam hari).
// Laporan ketercapaian (F4 tegak): rekap per santri (jumlah, rata-rata, kehadiran, peringkat), ketercapaian per mapel
// (rata-rata kelas terhadap KKM/KKTP, tertinggi, terendah, di bawah KKM, grafik batang) dan catatan kelompok mapel.
import { computed } from 'vue'
import HalRapor from '@/components/cetak/rapor/HalRapor.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import { hitungLeger, ringkasMapel, namaKelasRapor, SEMESTER_RAPOR, kopRapor, tanggalRapor, waliUtama } from '@/lib/rapor'

const props = defineProps({ D: { type: Object, required: true }, mode: { type: String, default: 'leger' } })
const ket = computed(() => props.D.ketentuan || {})
const leger = computed(() => hitungLeger(props.D))
const mapel = computed(() => ringkasMapel(props.D, leger.value))
const kop = computed(() => kopRapor(ket.value, props.D.kelas.jenjang))
const wali = computed(() => waliUtama(props.D))
const label = computed(() => ket.value.label_ambang || 'KKM')
const singkat = (m) => m.singkatan || m.nama.split(/\s+/).map((w) => w[0]).join('').slice(0, 5).toUpperCase()
const lebarMapel = computed(() => `${Math.max(3, Math.min(6, 58 / Math.max(1, mapel.value.length)))}%`)
const kiri = computed(() => ({ pengantar: 'Mengetahui,', jabatan: props.D.penanda?.jabatan || ket.value.jabatan_ttd || 'Kepala Sekolah', nama: props.D.penanda?.nama || '', niy: props.D.penanda?.niy }))
const kanan = computed(() => ({ jabatan: 'Wali Kelas', nama: wali.value?.nama || '', niy: wali.value?.niy }))
const catatan = computed(() => {
  const m = mapel.value.filter((x) => x.rata != null); const nm = (a) => a.map((x) => x.nama).join(', ') || '-'
  const maks = Math.max(...m.map((x) => x.rata), 0); const min = Math.min(...m.map((x) => x.rata), 100)
  return [[`Mata pelajaran dengan rata-rata nilai mencapai ${label.value}`, nm(m.filter((x) => x.rata >= Number(x.kkm)))],
    [`Mata pelajaran dengan rata-rata nilai di bawah ${label.value}`, nm(m.filter((x) => x.rata < Number(x.kkm)))],
    ['Mata pelajaran dengan ketercapaian tertinggi', nm(m.filter((x) => x.rata === maks))], ['Mata pelajaran dengan ketercapaian terendah', nm(m.filter((x) => x.rata === min))]]
})
</script>
<template>
  <HalRapor :kop="kop" :mendatar="mode === 'leger'">
    <template #kepala>
      <table class="identitas"><colgroup><col style="width:12%"><col style="width:48%"><col style="width:12%"><col style="width:28%"></colgroup><tbody>
        <tr><td>Kelas</td><td>: {{ namaKelasRapor(D.kelas) }}</td><td>Semester</td><td>: {{ SEMESTER_RAPOR[D.semester] }}</td></tr>
        <tr><td>Wali Kelas</td><td>: {{ wali?.nama || '-' }}</td><td>Tahun Ajaran</td><td>: {{ D.ta.nama }}</td></tr></tbody></table>
    </template>
    <template v-if="mode === 'leger'">
      <p class="judul-rapor">Leger Nilai {{ D.kelas.jenjang === 'sma' ? 'Rapor' : 'Rapor Wustha' }}</p>
      <table class="tabel kecil">
        <colgroup><col style="width:2.6%"><col style="width:6%"><col style="width:15%"><col style="width:2.4%"><col v-for="m in mapel" :key="m.id" :style="{ width: lebarMapel }">
          <col style="width:4.5%"><col style="width:4%"><col style="width:3.2%"><col style="width:3.2%"><col style="width:2.6%"><col style="width:2.6%"><col style="width:2.6%"></colgroup>
        <thead><tr><th rowspan="2">No.</th><th rowspan="2">NIS</th><th rowspan="2">Nama</th><th rowspan="2">JK</th><th :colspan="mapel.length">Nilai Mata Pelajaran</th>
          <th rowspan="2">Jumlah</th><th rowspan="2">Rata-rata</th><th rowspan="2">Rank</th><th rowspan="2">Sikap</th><th colspan="3">Absen</th></tr>
          <tr><th v-for="m in mapel" :key="m.id" :title="m.nama">{{ singkat(m) }}</th><th>S</th><th>I</th><th>A</th></tr>
          <tr><th colspan="4">{{ label }}</th><th v-for="m in mapel" :key="m.id">{{ Number(m.kkm) }}</th><th colspan="7" /></tr></thead>
        <tbody><tr v-for="(b, i) in leger" :key="b.s.id"><td class="tengah">{{ i + 1 }}</td><td>{{ b.s.nis }}</td><td>{{ b.s.nama }}</td><td class="tengah">{{ b.s.jenis_kelamin }}</td>
          <td v-for="x in b.n" :key="x.id" class="tengah" :style="x.tuntas === false ? 'text-decoration: underline' : ''">{{ x.nilai ?? '' }}</td>
          <td class="tengah">{{ b.jumlah || '' }}</td><td class="tengah">{{ b.rata ?? '' }}</td><td class="tengah">{{ b.peringkat ?? '' }}</td><td class="tengah">{{ b.sikap }}</td>
          <td class="tengah">{{ b.s.kehadiran?.sakit ?? 0 }}</td><td class="tengah">{{ b.s.kehadiran?.izin ?? 0 }}</td><td class="tengah">{{ b.s.kehadiran?.absen ?? 0 }}</td></tr>
          <tr><td colspan="4" class="kelompok">Rata-rata kelas</td><td v-for="m in mapel" :key="m.id" class="tengah">{{ m.rata != null ? Math.round(m.rata) : '' }}</td><td colspan="7" /></tr></tbody></table>
      <p style="margin-top: 3pt; font-size: 8pt">{{ mapel.map((m) => `${singkat(m)} = ${m.nama}`).join('; ') }}. Nilai bergaris bawah: di bawah {{ label }}. Absen dalam hari.</p>
    </template>
    <template v-else>
      <p class="judul-rapor">Laporan Ketercapaian Nilai Mata Pelajaran</p>
      <table class="tabel kecil"><colgroup><col style="width:5%"><col style="width:12%"><col style="width:39%"><col style="width:5%"><col style="width:10%"><col style="width:10%"><col style="width:10%"><col style="width:9%"></colgroup>
        <thead><tr><th>No.</th><th>NIS</th><th>Nama Lengkap Peserta Didik</th><th>JK</th><th>Total Nilai Mapel</th><th>Rata-rata Nilai Mapel</th><th>Kehadiran</th><th>Rank</th></tr></thead>
        <tbody><tr v-for="(b, i) in leger" :key="b.s.id"><td class="tengah">{{ i + 1 }}</td><td>{{ b.s.nis }}</td><td>{{ b.s.nama }}</td><td class="tengah">{{ b.s.jenis_kelamin }}</td>
          <td class="tengah">{{ b.jumlah || 0 }}</td><td class="tengah">{{ b.rata ?? 0 }}</td><td class="tengah">{{ b.hadir ?? 100 }}%</td><td class="tengah">{{ b.peringkat ?? '' }}</td></tr></tbody></table>
      <p class="sub-rapor">Grafik ketercapaian {{ label }} dan rata-rata nilai mata pelajaran</p>
      <table class="tabel kecil"><colgroup><col style="width:30%"><col style="width:7%"><col style="width:8%"><col style="width:8%"><col style="width:8%"><col style="width:8%"><col style="width:31%"></colgroup>
        <thead><tr><th>Mata Pelajaran</th><th>{{ label }}</th><th>Rata-rata</th><th>Tertinggi</th><th>Terendah</th><th>Di bawah {{ label }}</th><th>Grafik (rata-rata ▮ / {{ label }} │)</th></tr></thead>
        <tbody><tr v-for="m in mapel" :key="m.id"><td>{{ m.nama }}</td><td class="tengah">{{ Number(m.kkm) }}</td><td class="tengah">{{ m.rata ?? '' }}</td><td class="tengah">{{ m.maks ?? '' }}</td><td class="tengah">{{ m.min ?? '' }}</td>
          <td class="tengah">{{ m.terisi ? m.bawah : '' }}</td>
          <td style="vertical-align: middle"><div style="position: relative; height: 9pt; background: #F1F1F1; -webkit-print-color-adjust: exact; print-color-adjust: exact">
            <div :style="{ position: 'absolute', inset: '0 auto 0 0', width: `${m.rata || 0}%`, background: (m.rata ?? 0) >= Number(m.kkm) ? '#2F80C9' : '#D2453F', WebkitPrintColorAdjust: 'exact', printColorAdjust: 'exact' }" />
            <div :style="{ position: 'absolute', top: '-2pt', bottom: '-2pt', left: `${Number(m.kkm)}%`, borderLeft: '1.2pt solid #000' }" /></div></td></tr></tbody></table>
      <table class="tabel kecil" style="margin-top: 8pt"><colgroup><col style="width:5%"><col style="width:30%"><col style="width:65%"></colgroup>
        <thead><tr><th>No.</th><th>Catatan</th><th>Mata Pelajaran Terkait</th></tr></thead>
        <tbody><tr v-for="(c, i) in catatan" :key="i"><td class="tengah">{{ i + 1 }}</td><td>{{ c[0] }}</td><td>{{ c[1] }}</td></tr></tbody></table>
    </template>
    <TandaTangan :kiri="kiri" :kanan="kanan" :kota="ket.tempat || ''" :tanggal="tanggalRapor(D)" />
  </HalRapor>
</template>
