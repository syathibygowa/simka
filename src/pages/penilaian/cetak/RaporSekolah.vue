<!-- SIMKA PRO | src/pages/penilaian/cetak/RaporSekolah.vue | v1.2 | 14.22.0: judul rapor di atas identitas; identitas Wustha 2 kolom 3 baris Title Case | 25/10/2026 -->
<script setup>
// Rapor sekolah per santri (data_rapor):
//   SMA (Kurikulum Merdeka) : Nilai + Capaian Kompetensi per mapel (berkelompok), Kokurikuler, Ekstrakurikuler,
//                             Ketidakhadiran + persentase + catatan, Catatan wali kelas, Keputusan (semester 2)
//   Wustha (K13 disesuaikan): KKM, Pengetahuan & Keterampilan (angka, predikat, deskripsi), Sikap, rata-rata;
//                             Pengembangan Diri, Pencapaian Program Tahfizhul Qur'an, Ketidakhadiran, Catatan, Kenaikan kelas
// Tanda tangan: orang tua kiri, wali kelas kanan, kepala tengah bawah. Kepala rapor (kop + identitas) berulang per halaman.
// v1.1: tabel Prestasi tampil bila santri memiliki prestasi bertanda rapor dalam rentang semester (menu Prestasi Santri).
// v1.2 (14.22.0): judul rapor di atas identitas (SMA dan Wustha); identitas Wustha Nama/NISN/NIS · Kelas/Semester/Tahun Ajaran dalam Title Case.
import { computed } from 'vue'
import HalRapor from '@/components/cetak/rapor/HalRapor.vue'
import TtdRapor from '@/components/cetak/rapor/TtdRapor.vue'
import { barisNilai, kelompokkan, hitungLeger, namaKelasRapor, SEMESTER_RAPOR, nisNisn, persenHadir, kalimatHadir, deskripsiKok, barisPd,
  teksKeputusan, kopRapor, tanggalRapor, waliUtama } from '@/lib/rapor'
import { predikatDari, sebutanPredikat } from '@/lib/penilaian'
import { ringkasJuz } from '@/lib/tahfizh'
import { formatPanjang } from '@/lib/tanggal'
import { htmlMiring } from '@/lib/catatanRapor'
import { TINGKAT_PRESTASI } from '@/lib/prestasi'

const props = defineProps({ D: { type: Object, required: true }, pilih: { type: Array, default: null } })
const ket = computed(() => props.D.ketentuan || {})
const sma = computed(() => props.D.kelas.jenjang === 'sma')
const kop = computed(() => kopRapor(ket.value, props.D.kelas.jenjang))
const kelas = computed(() => namaKelasRapor(props.D.kelas))
const leger = computed(() => hitungLeger(props.D))
const daftar = computed(() => leger.value.filter((b) => !props.pilih || props.pilih.includes(b.s.id)))
const fase = computed(() => ket.value.fase?.[props.D.kelas.tingkat] || '')
const wali = computed(() => waliUtama(props.D))
const tengah = computed(() => (props.D.penanda?.nama ? { jabatan: props.D.penanda.jabatan || 'Kepala Sekolah', nama: props.D.penanda.nama, niy: props.D.penanda.niy } : { jabatan: ket.value.jabatan_ttd || 'Kepala Sekolah', nama: '' }))
const kanan = computed(() => ({ jabatan: 'Wali Kelas', nama: wali.value?.nama || '', niy: wali.value?.niy }))
const tanggal = computed(() => tanggalRapor(props.D))
const utasPred = computed(() => (props.D.predikat || []).filter((p) => p.kelompok === 'utas'))
const bahasaUtas = 'indonesia'
const sebutUtas = (n) => sebutanPredikat(predikatDari(n, utasPred.value), bahasaUtas)
const sebutSikap = (h) => (props.D.predikat || []).find((p) => p.kelompok === 'sikap' && p.huruf === h)?.sebutan || h || '-'
const smt2 = computed(() => Number(props.D.semester) === 2)
const label = computed(() => ket.value.label_ambang || 'KKM')
const rataKelas = (b, f) => { const v = b.n.map((x) => x[f]).filter((x) => x != null); return v.length ? Math.round(v.reduce((a, x) => a + Number(x), 0) / v.length) : '' }
</script>
<template>
  <HalRapor v-for="b in daftar" :key="b.s.id" :kop="kop">
    <template #kepala>
      <!-- 14.22.0: judul rapor di atas identitas (seperti rapor tahfizh); identitas Wustha 2 kolom × 3 baris, Title Case -->
      <p class="judul-rapor" style="margin-top: 2pt">{{ ket.judul || 'Laporan Hasil Belajar' }}</p>
      <table v-if="sma" class="identitas"><colgroup><col style="width:17%"><col style="width:45%"><col style="width:15%"><col style="width:23%"></colgroup><tbody>
        <tr><td>Nama Murid</td><td>: {{ b.s.nama.toUpperCase() }}</td><td>Fase</td><td>: {{ fase }}</td></tr>
        <tr><td>NIS/NISN</td><td>: {{ nisNisn(b.s) }}</td><td>Semester</td><td>: {{ SEMESTER_RAPOR[D.semester] }}</td></tr>
        <tr><td>Kelas</td><td>: {{ kelas }}</td><td>Tahun Ajaran</td><td>: {{ D.ta.nama }}</td></tr></tbody></table>
      <table v-else class="identitas"><colgroup><col style="width:15%"><col style="width:47%"><col style="width:15%"><col style="width:23%"></colgroup><tbody>
        <tr><td>Nama</td><td>: {{ b.s.nama.toUpperCase() }}</td><td>Kelas</td><td>: {{ kelas }}</td></tr>
        <tr><td>NISN</td><td>: {{ b.s.nisn || '-' }}</td><td>Semester</td><td>: {{ SEMESTER_RAPOR[D.semester] }}</td></tr>
        <tr><td>NIS</td><td>: {{ b.s.nis || '-' }}</td><td>Tahun Ajaran</td><td>: {{ D.ta.nama }}</td></tr></tbody></table>
    </template>

    <!-- ================= SMA ================= -->
    <template v-if="sma">
      <table class="tabel" style="margin-top: 4pt"><colgroup><col style="width:6%"><col style="width:27%"><col style="width:9%"><col style="width:58%"></colgroup>
        <thead><tr><th>No</th><th>Mata Pelajaran</th><th>Nilai</th><th>Capaian Kompetensi</th></tr></thead>
        <tbody><template v-for="g in kelompokkan(b.n)" :key="g.kelompok">
          <tr v-if="g.kelompok"><td colspan="4" class="kelompok">{{ g.kelompok }}</td></tr>
          <tr v-for="m in g.item" :key="m.id"><td class="tengah">{{ m.no }}</td><td>{{ m.nama }}</td><td class="tengah">{{ m.nilai ?? '' }}</td><td style="text-align: justify">{{ m.deskripsi }}</td></tr>
        </template>
        <tr v-if="ket.tampil_rata"><td colspan="2" class="kelompok">Rata-rata nilai</td><td class="tengah">{{ b.rata ?? '' }}</td><td /></tr>
        <tr v-if="ket.tampil_peringkat"><td colspan="2" class="kelompok">Peringkat kelas</td><td class="tengah">{{ b.peringkat ?? '' }}</td><td>dari {{ leger.length }} santri</td></tr>
        </tbody></table>

      <template v-if="ket.pakai_kokurikuler">
        <table class="tabel" style="margin-top: 8pt"><thead><tr><th>KOKURIKULER</th></tr></thead><tbody><tr><td style="text-align: justify; min-height: 12mm">{{ deskripsiKok(b.s, D) }}</td></tr></tbody></table>
      </template>
      <table class="tabel" style="margin-top: 8pt"><colgroup><col style="width:6%"><col style="width:34%"><col style="width:12%"><col style="width:48%"></colgroup>
        <thead><tr><th>No.</th><th>Kegiatan Ekstrakurikuler</th><th>Predikat</th><th>Deskripsi</th></tr></thead>
        <tbody><tr v-for="(x, i) in (barisPd(b.s, D).length ? barisPd(b.s, D) : [{}, {}])" :key="i"><td class="tengah">{{ i + 1 }}</td><td>{{ x.kegiatan || '' }}</td><td class="tengah">{{ x.nilai || '' }}</td><td>{{ x.deskripsi || '' }}</td></tr></tbody></table>
    </template>

    <!-- ================= WUSTHA ================= -->
    <template v-else>
      <table class="tabel kecil" style="margin-top: 4pt"><colgroup><col style="width:4.5%"><col style="width:15.5%"><col style="width:5.5%"><col style="width:6%"><col style="width:7.5%"><col :style="{ width: ket.sikap_di_rapor ? '18.5%' : '23%' }"><col style="width:6%"><col style="width:7.5%"><col :style="{ width: ket.sikap_di_rapor ? '18.5%' : '23%' }"><col v-if="ket.sikap_di_rapor" style="width:10.5%"></colgroup>
        <thead>
          <tr><th rowspan="2">No.</th><th rowspan="2">MATA PELAJARAN</th><th rowspan="2">{{ label }}</th><th colspan="3">PENGETAHUAN</th><th colspan="3">KETERAMPILAN</th><th v-if="ket.sikap_di_rapor" rowspan="2">SIKAP</th></tr>
          <tr><th>Angka</th><th>Pre&shy;dikat</th><th>Deskripsi</th><th>Angka</th><th>Pre&shy;dikat</th><th>Deskripsi</th></tr>
        </thead>
        <tbody><template v-for="g in kelompokkan(b.n)" :key="g.kelompok">
          <tr v-if="g.kelompok"><td :colspan="ket.sikap_di_rapor ? 10 : 9" class="kelompok">{{ g.kelompok }}</td></tr>
          <tr v-for="m in g.item" :key="m.id"><td class="tengah">{{ m.no }}.</td><td>{{ m.nama }}</td><td class="tengah">{{ Number(m.kkm) }}</td>
            <td class="tengah">{{ m.nilai ?? '' }}</td><td class="tengah">{{ m.huruf }}</td><td>{{ m.deskripsi }}</td>
            <td class="tengah">{{ m.keterampilan ?? '' }}</td><td class="tengah">{{ m.huruf_ket }}</td><td>{{ m.deskripsi_2 }}</td>
            <td v-if="ket.sikap_di_rapor" class="tengah">{{ m.sikap ? sebutSikap(m.sikap) : '-' }}</td></tr>
        </template>
        <tr v-if="ket.tampil_rata"><td colspan="3" class="kelompok tengah">Rata-rata Nilai</td><td colspan="3" class="tengah">Nilai Pengetahuan: {{ rataKelas(b, 'nilai') }}</td>
          <td colspan="3" class="tengah">Nilai Keterampilan: {{ rataKelas(b, 'keterampilan') }}</td><td v-if="ket.sikap_di_rapor" /></tr>
        <tr v-if="ket.tampil_peringkat"><td colspan="3" class="kelompok tengah">Peringkat Kelas</td><td :colspan="ket.sikap_di_rapor ? 7 : 6">{{ b.peringkat ?? '' }} dari {{ leger.length }} santri</td></tr>
        </tbody></table>

      <table class="tabel" style="margin-top: 10pt"><colgroup><col style="width:6%"><col style="width:28%"><col style="width:9%"><col style="width:14%"><col style="width:43%"></colgroup>
        <thead><tr><th colspan="5">PENILAIAN PENGEMBANGAN DIRI</th></tr><tr><th>No.</th><th>Pengembangan Diri</th><th>Nilai</th><th>Predikat</th><th>Keterangan</th></tr></thead>
        <tbody><tr v-for="(x, i) in (barisPd(b.s, D).length ? barisPd(b.s, D) : [{}, {}])" :key="i"><td class="tengah">{{ i + 1 }}.</td><td>{{ x.kegiatan || '-' }}</td><td class="tengah">{{ x.nilai || '-' }}</td>
          <td class="tengah">{{ x.sebutan || '-' }}</td><td>{{ x.deskripsi || '-' }}</td></tr></tbody></table>

      <table class="tabel" style="margin-top: 10pt"><colgroup><col style="width:22%"><col style="width:30%"><col style="width:22%"><col style="width:26%"></colgroup>
        <thead><tr><th colspan="4">PENCAPAIAN PROGRAM TAHFIZHUL QUR'AN</th></tr><tr><th>Jumlah Hafalan</th><th>Juz yang Diujikan</th><th>Tanggal Ujian</th><th>Predikat</th></tr></thead>
        <tbody><tr><td class="tengah">{{ b.s.tahfizh?.total_juz ?? 0 }} juz</td><td class="tengah">{{ ringkasJuz(b.s.tahfizh?.utas?.juz || []) || '-' }}</td>
          <td class="tengah">{{ b.s.tahfizh?.utas?.diuji_pada ? formatPanjang(b.s.tahfizh.utas.diuji_pada) : '-' }}</td>
          <td class="tengah">{{ b.s.tahfizh?.utas?.nilai != null ? sebutUtas(b.s.tahfizh.utas.nilai) : '-' }}</td></tr></tbody></table>
    </template>

    <!-- ================= Bersama ================= -->
    <table v-if="b.s.prestasi?.length" class="tabel" style="margin-top: 10pt"><colgroup><col style="width:6%"><col style="width:44%"><col style="width:50%"></colgroup>
      <thead><tr><th>No.</th><th>{{ sma ? 'Prestasi' : 'PRESTASI' }}</th><th>{{ sma ? 'Keterangan' : 'KETERANGAN' }}</th></tr></thead>
      <tbody><tr v-for="(x, i) in b.s.prestasi" :key="i"><td class="tengah">{{ i + 1 }}{{ sma ? '' : '.' }}</td><td>{{ x.capaian }} {{ x.nama_kegiatan }}</td>
        <td>{{ ['Tingkat ' + (TINGKAT_PRESTASI[x.tingkat] || x.tingkat), x.penyelenggara, formatPanjang(x.tanggal)].filter(Boolean).join(', ') }}</td></tr></tbody></table>

    <table class="tabel" style="margin-top: 10pt"><colgroup><col style="width:5%"><col style="width:22%"><col style="width:13%"><col style="width:15%"><col style="width:45%"></colgroup>
      <thead><tr><th colspan="3">Ketidakhadiran</th><th>Persentase Kehadiran</th><th>Catatan/Keterangan</th></tr></thead>
      <tbody>
        <tr><td class="tengah">1</td><td>Sakit</td><td class="tengah">{{ b.s.kehadiran?.sakit ?? 0 }} Hari</td>
          <td rowspan="3" class="tengah" style="vertical-align: middle; font-size: 12pt">{{ persenHadir(b.s.kehadiran) ?? 100 }}%</td>
          <td rowspan="3" style="vertical-align: middle; text-align: justify">{{ kalimatHadir(persenHadir(b.s.kehadiran) ?? 100, D.kalimat_hadir) }}</td></tr>
        <tr><td class="tengah">2</td><td>Izin</td><td class="tengah">{{ b.s.kehadiran?.izin ?? 0 }} Hari</td></tr>
        <tr><td class="tengah">3</td><td>Tanpa Keterangan</td><td class="tengah">{{ b.s.kehadiran?.absen ?? 0 }} Hari</td></tr>
      </tbody></table>

    <p class="sub-rapor">CATATAN WALI KELAS</p>
    <div class="kotak" v-html="htmlMiring(b.s.catatan || '')" />
    <template v-if="smt2">
      <p class="sub-rapor">{{ [9, 12].includes(Number(D.kelas.tingkat)) ? 'KETERANGAN KELULUSAN' : 'KETERANGAN KENAIKAN KELAS' }}</p>
      <div class="kotak" style="min-height: 0; text-align: center; font-weight: 700; font-size: 12pt">{{ teksKeputusan(b.s.keputusan, D.kelas.tingkat) || '.....................................' }}</div>
    </template>
    <TtdRapor :kanan="kanan" :tengah="tengah" :tempat="ket.tempat || 'Gowa'" :tanggal="tanggal" />
  </HalRapor>
</template>
