<!-- SIMKA PRO | src/pages/penilaian/cetak/LembarKelasRapor.vue | v1.0 | Fase 12 – Tahap 5 Lembar remidi dan tanda terima rapor | 13/10/2026 -->
<script setup>
// remidi  : lembar perbaikan nilai per santri yang memiliki nilai di bawah KKM/KKTP (kolom hasil perbaikan dan tanda tangan guru)
// terima  : tanda terima rapor per kelas (tanggal penyerahan dan tanda tangan orang tua/wali, berselang-seling)
import { computed } from 'vue'
import HalRapor from '@/components/cetak/rapor/HalRapor.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import { hitungLeger, kelompokkan, namaKelasRapor, SEMESTER_RAPOR, kopRapor, nisNisn, tanggalRapor, waliUtama } from '@/lib/rapor'

const props = defineProps({ D: { type: Object, required: true }, mode: { type: String, default: 'remidi' }, pilih: { type: Array, default: null } })
const ket = computed(() => props.D.ketentuan || {})
const kop = computed(() => kopRapor(ket.value, props.D.kelas.jenjang))
const leger = computed(() => hitungLeger(props.D))
const remidi = computed(() => leger.value.filter((b) => b.bawah.length && (!props.pilih || props.pilih.includes(b.s.id))))
const wali = computed(() => waliUtama(props.D))
const label = computed(() => ket.value.label_ambang || 'KKM')
</script>
<template>
  <template v-if="mode === 'remidi'">
    <HalRapor v-for="b in remidi" :key="b.s.id" :kop="kop">
      <template #kepala>
        <table class="identitas"><colgroup><col style="width:15%"><col style="width:47%"><col style="width:13%"><col style="width:25%"></colgroup><tbody>
          <tr><td>Nama Santri</td><td>: {{ b.s.nama }}</td><td>Kelas</td><td>: {{ namaKelasRapor(D.kelas) }}</td></tr>
          <tr><td>NIS/NISN</td><td>: {{ nisNisn(b.s) }}</td><td>Semester</td><td>: {{ SEMESTER_RAPOR[D.semester] }}</td></tr></tbody></table>
      </template>
      <p class="judul-rapor">Lembar Perbaikan Nilai</p>
      <table class="tabel"><colgroup><col style="width:6%"><col style="width:30%"><col style="width:8%"><col style="width:8%"><col style="width:13%"><col style="width:15%"><col style="width:20%"></colgroup>
        <thead><tr><th>No</th><th>Muatan Pelajaran</th><th>{{ label }}</th><th>Nilai</th><th>Keterangan</th><th>Hasil Perbaikan</th><th>Tanda Tangan Guru</th></tr></thead>
        <tbody><template v-for="g in kelompokkan(b.bawah)" :key="g.kelompok">
          <tr v-if="g.kelompok"><td colspan="7" class="kelompok">{{ g.kelompok }}</td></tr>
          <tr v-for="m in g.item" :key="m.id" style="height: 11mm"><td class="tengah">{{ m.no }}</td><td>{{ m.nama }}</td><td class="tengah">{{ Number(m.kkm) }}</td><td class="tengah">{{ m.nilai }}</td><td class="tengah">Remidi</td><td /><td /></tr>
        </template></tbody></table>
      <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: 'Orang Tua/Wali', nama: '' }" :kanan="{ jabatan: 'Wali Kelas', nama: wali?.nama || '', niy: wali?.niy }" :kota="ket.tempat || ''" :tanggal="tanggalRapor(D)" />
    </HalRapor>
    <HalRapor v-if="!remidi.length" :kop="kop"><p class="judul-rapor">Lembar Perbaikan Nilai</p><p style="text-align: center">Tidak ada santri dengan nilai di bawah {{ label }} pada {{ namaKelasRapor(D.kelas) }}.</p></HalRapor>
  </template>
  <HalRapor v-else :kop="kop">
    <template #kepala>
      <table class="identitas"><colgroup><col style="width:12%"><col style="width:50%"><col style="width:12%"><col style="width:26%"></colgroup><tbody>
        <tr><td>Kelas</td><td>: {{ namaKelasRapor(D.kelas) }}</td><td>Semester</td><td>: {{ SEMESTER_RAPOR[D.semester] }}</td></tr>
        <tr><td>Wali Kelas</td><td>: {{ wali?.nama || '-' }}</td><td>Tahun Ajaran</td><td>: {{ D.ta.nama }}</td></tr></tbody></table>
    </template>
    <p class="judul-rapor">Tanda Terima Rapor</p>
    <table class="tabel"><colgroup><col style="width:6%"><col style="width:20%"><col style="width:32%"><col style="width:14%"><col style="width:14%"><col style="width:14%"></colgroup>
      <thead><tr><th>No.</th><th>NIS/NISN</th><th>Nama Santri</th><th>Tanggal Penyerahan</th><th colspan="2">Tanda Tangan Orang Tua/Wali</th></tr></thead>
      <tbody><tr v-for="(s, i) in D.santri" :key="s.id" style="height: 11mm"><td class="tengah">{{ i + 1 }}</td><td>{{ nisNisn(s) }}</td><td>{{ s.nama }}</td><td />
        <td style="border-right: 0">{{ i % 2 === 0 ? `${i + 1}.` : '' }}</td><td style="border-left: 0">{{ i % 2 === 1 ? `${i + 1}.` : '' }}</td></tr></tbody></table>
    <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: D.penanda?.jabatan || 'Kepala Sekolah', nama: D.penanda?.nama || '', niy: D.penanda?.niy }" :kanan="{ jabatan: 'Wali Kelas', nama: wali?.nama || '', niy: wali?.niy }" :kota="ket.tempat || ''" :tanggal="tanggalRapor(D)" />
  </HalRapor>
</template>
