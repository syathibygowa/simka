<!-- SIMKA PRO | src/pages/penilaian/cetak/RaporTahfizh.vue | v1.0 | Fase 12 – Tahap 5 Cetak rapor tahfizh | 13/10/2026 -->
<script setup>
// Rapor tahfizh per santri (data_rapor_tahfizh), mengikuti rancangan "Laporan Hasil Capaian Hafalan Al-Qur'an":
//   Laporan capaian hafalan per bulan (total hafalan akhir bulan, capaian bulan itu, keterangan target),
//   Ujian kenaikan juz semester ini (Tajwid, Itqan, predikat), Ujian Tahfizh Akhir Semester (UTAS),
//   Kehadiran halaqah dalam hari (sakit, izin, tanpa keterangan, persentase, catatan), Catatan muhaffizh.
// Tanda tangan: orang tua kiri, muhaffizh kanan, kepala tahfizh tengah bawah. Kop: ketentuan tahfizh, bawaan jenjang santri.
import { computed } from 'vue'
import HalRapor from '@/components/cetak/rapor/HalRapor.vue'
import TtdRapor from '@/components/cetak/rapor/TtdRapor.vue'
import { SEMESTER_RAPOR, nisNisn, persenHadir, kalimatHadir, kopRapor, tanggalRapor, namaKelasRapor } from '@/lib/rapor'
import { predikatDari, sebutanPredikat } from '@/lib/penilaian'
import { formatPosisi, ringkasJuz, STATUS_BULANAN } from '@/lib/tahfizh'
import { BULAN } from '@/lib/tanggal'
import { htmlMiring } from '@/lib/catatanRapor'

const props = defineProps({ D: { type: Object, required: true }, pilih: { type: Array, default: null }, penanda: { type: Object, default: null } })
const ket = computed(() => props.D.ketentuan || {})
const daftar = computed(() => (props.D.santri || []).filter((s) => !props.pilih || props.pilih.includes(s.id)))
const bahasa = computed(() => ket.value.bahasa_predikat || 'indonesia')
const sebut = (n) => { const t = sebutanPredikat(predikatDari(n, props.D.predikat), bahasa.value); return t }
// Bulan semester: dari awal rentang sampai akhir rentang
const bulanSemester = computed(() => {
  const r = props.D.rentang || {}; if (!r.mulai) return []
  const [y0, m0] = r.mulai.split('-').map(Number); const [y1, m1] = r.selesai.split('-').map(Number); const hasil = []
  for (let y = y0, m = m0; y < y1 || (y === y1 && m <= m1); m === 12 ? (y++, m = 1) : m++) hasil.push(`${y}-${String(m).padStart(2, '0')}-01`)
  return hasil
})
const bulanan = (s) => bulanSemester.value.map((b) => ({ bulan: b, ...((s.bulanan || []).find((x) => String(x.bulan).slice(0, 7) === b.slice(0, 7)) || {}) }))
const namaBulan = (iso) => BULAN[Number(iso.slice(5, 7)) - 1]
const fase = (s) => (props.D.fase?.[s.jenjang] || {})[s.tingkat] || ''
const kelas = (s) => (s.kelas ? namaKelasRapor({ nama: s.kelas, jenjang: s.jenjang }) : '-')
const tengah = computed(() => {
  const p = props.D.penanda?.nama ? props.D.penanda : props.penanda
  return p?.nama ? { jabatan: ket.value.jabatan_ttd || p.jabatan || 'Kepala Tahfizh', nama: p.nama, niy: p.niy } : { jabatan: ket.value.jabatan_ttd || 'Kepala Tahfizh', nama: '' }
})
const kop = (s) => kopRapor(ket.value, s.jenjang)
const posisi = (h) => (h == null ? '' : formatPosisi(h))
</script>
<template>
  <HalRapor v-for="s in daftar" :key="s.id" :kop="kop(s)">
    <template #kepala>
      <p class="judul-rapor" style="margin-top: 2pt">{{ ket.judul || "Laporan Hasil Capaian Hafalan Al-Qur'an" }}</p>
      <table class="identitas"><colgroup><col style="width:16%"><col style="width:46%"><col style="width:15%"><col style="width:23%"></colgroup><tbody>
        <tr><td>Nama Santri</td><td>: {{ s.nama.toUpperCase() }}</td><td>Fase</td><td>: {{ fase(s) }}</td></tr>
        <tr><td>NIS/NISN</td><td>: {{ nisNisn(s) }}</td><td>Semester</td><td>: {{ SEMESTER_RAPOR[D.semester] }}</td></tr>
        <tr><td>Kelas</td><td>: {{ kelas(s) }}</td><td>Tahun Ajaran</td><td>: {{ D.ta.nama }}</td></tr>
        <tr><td>Halaqah</td><td>: {{ s.halaqah || '-' }}</td><td>Hafalan resmi</td><td>: {{ s.total_juz }} juz</td></tr></tbody></table>
    </template>

    <p class="sub-rapor">LAPORAN CAPAIAN HAFALAN</p>
    <table class="tabel padat"><colgroup><col style="width:7%"><col style="width:22%"><col style="width:24%"><col style="width:22%"><col style="width:25%"></colgroup>
      <thead><tr><th>No</th><th>Bulan</th><th>Total Hafalan</th><th>Capaian Tahfizh</th><th>Keterangan</th></tr></thead>
      <tbody><tr v-for="(b, i) in bulanan(s)" :key="b.bulan"><td class="tengah">{{ i + 1 }}</td><td>{{ namaBulan(b.bulan) }}</td>
        <td class="tengah">{{ posisi(b.posisi_akhir_hal) }}</td><td class="tengah">{{ b.tambah_hal != null ? (b.tambah_hal > 0 ? formatPosisi(b.tambah_hal) : '0') : '' }}</td>
        <td class="tengah">{{ b.status ? STATUS_BULANAN[b.status]?.n : '' }}</td></tr></tbody></table>

    <p class="sub-rapor">UJIAN KENAIKAN JUZ</p>
    <table class="tabel padat"><colgroup><col style="width:7%"><col style="width:33%"><col style="width:15%"><col style="width:15%"><col style="width:30%"></colgroup>
      <thead><tr><th rowspan="2">No</th><th rowspan="2">Juz</th><th colspan="2">Penilaian</th><th rowspan="2">Predikat</th></tr><tr><th>Tajwid</th><th>Itqan</th></tr></thead>
      <tbody><tr v-for="(u, i) in (s.kenaikan.length ? s.kenaikan : [{}])" :key="i"><td class="tengah">{{ i + 1 }}</td><td>{{ u.juz ? `Juz ke-${u.juz}` : '' }}</td>
        <td class="tengah">{{ u.tajwid ?? '' }}</td><td class="tengah">{{ u.itqan ?? '' }}</td><td class="tengah">{{ u.predikat || (u.nilai != null ? sebut(u.nilai) : '') }}{{ u.hasil === 'remidi' ? ' (Remidi)' : '' }}</td></tr></tbody></table>

    <p class="sub-rapor">UJIAN TAHFIZH AKHIR SEMESTER (UTAS)</p>
    <table class="tabel padat"><colgroup><col style="width:17%"><col style="width:27%"><col style="width:12%"><col style="width:12%"><col style="width:12%"><col style="width:20%"></colgroup>
      <thead><tr><th rowspan="2">Total Capaian</th><th rowspan="2">Hafalan yang Diujikan</th><th colspan="2">Penilaian</th><th rowspan="2">Nilai Akhir</th><th rowspan="2">Keterangan</th></tr><tr><th>Tajwid</th><th>Itqan</th></tr></thead>
      <tbody><tr><td class="tengah">{{ s.utas?.total_juz ?? s.total_juz }} juz</td><td class="tengah">{{ s.utas?.juz?.length ? `${s.utas.juz.length} juz (${ringkasJuz(s.utas.juz)})` : '-' }}</td>
        <td class="tengah">{{ s.utas?.tajwid ?? '' }}</td><td class="tengah">{{ s.utas?.itqan ?? '' }}</td><td class="tengah">{{ s.utas?.nilai ?? '' }}</td>
        <td class="tengah"><template v-if="s.utas?.nilai != null"><i v-if="bahasa === 'arab'">{{ sebut(s.utas.nilai) }}</i><template v-else>{{ sebut(s.utas.nilai) }}</template>{{ s.utas.tuntas === false ? ' (Remedial)' : '' }}</template></td></tr></tbody></table>

    <p class="sub-rapor">KEHADIRAN HALAQAH</p>
    <table class="tabel padat"><colgroup><col style="width:5%"><col style="width:22%"><col style="width:13%"><col style="width:15%"><col style="width:45%"></colgroup>
      <thead><tr><th colspan="3">Ketidakhadiran</th><th>Persentase</th><th>Catatan/Keterangan</th></tr></thead>
      <tbody>
        <tr><td class="tengah">1</td><td>Sakit</td><td class="tengah">{{ s.kehadiran?.sakit ?? 0 }} Hari</td>
          <td rowspan="3" class="tengah" style="vertical-align: middle; font-size: 12pt">{{ persenHadir(s.kehadiran) ?? 100 }}%</td>
          <td rowspan="3" style="vertical-align: middle; text-align: justify">{{ kalimatHadir(persenHadir(s.kehadiran) ?? 100, D.kalimat_hadir) }}</td></tr>
        <tr><td class="tengah">2</td><td>Izin</td><td class="tengah">{{ s.kehadiran?.izin ?? 0 }} Hari</td></tr>
        <tr><td class="tengah">3</td><td>Tanpa Keterangan</td><td class="tengah">{{ s.kehadiran?.absen ?? 0 }} Hari</td></tr>
      </tbody></table>

    <p class="sub-rapor">CATATAN MUHAFFIZH</p>
    <div class="kotak" v-html="htmlMiring(s.catatan || '')" />
    <TtdRapor :kanan="{ jabatan: 'Muhaffizh', nama: s.muhaffizh?.nama || '', niy: s.muhaffizh?.niy }" :tengah="tengah" :tempat="ket.tempat || 'Gowa'" :tanggal="tanggalRapor(D)" />
  </HalRapor>
</template>
