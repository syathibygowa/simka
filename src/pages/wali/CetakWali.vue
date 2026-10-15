<!-- SIMKA PRO | src/pages/wali/CetakWali.vue | v1.0 | Fase 9 – Tahap 13.4.0 Unduh PDF Portal Wali | 15/10/2026 -->
<script setup>
// Lembar cetak F4 (Simpan sebagai PDF) dari data yang sedang tampil di Portal Wali, periode paling panjang satu semester.
// jenis: kehadiran | hafalan | perizinan | kunjungan | titipan | sakit | nilai.  data = hasil portal_data bagian tersebut.
// Kop Pondok, identitas santri, tabel ½ pt (tebal hanya judul dan kepala tabel), catatan "dicetak dari Portal Wali, bukan dokumen resmi".
// Nama berkas: "Nama santri - Judul dokumen - Periode".
import { computed } from 'vue'
import { usePortalWali } from '@/stores/portalWali'
import { KODE, JENIS_ABSENSI } from '@/lib/absensi'
import { PROGRAM, STATUS_BULANAN, formatPosisi, labelBulan } from '@/lib/tahfizh'
import { STATUS_IZIN, JENIS_IZIN } from '@/lib/izin'
import { JENIS_TITIPAN, STATUS_TITIPAN, PENGAMBIL, rupiah } from '@/lib/security'
import { STATUS_KASUS, TINDAK_LANJUT } from '@/lib/klinik'
import { SEMESTER_RAPOR, teksKeputusan } from '@/lib/rapor'
import { HUBUNGAN_WALI } from '@/lib/portalWali'
import { formatPanjang, formatPendek, formatWaktu, formatHari } from '@/lib/tanggal'
import { namaBerkas, periodeRentang } from '@/lib/namaBerkas'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'

const pratinjau = defineModel('pratinjau', { type: Boolean, default: false })
const props = defineProps({ jenis: { type: String, required: true }, data: { type: Object, default: null } })
const pw = usePortalWali()
const s = computed(() => pw.beranda?.santri || pw.aktif || {})
const d = computed(() => props.data || {})
const JUDUL = { kehadiran: 'Rekap Kehadiran Santri', hafalan: 'Laporan Hafalan Santri', perizinan: 'Riwayat Perizinan dan Libur Santri',
  kunjungan: 'Riwayat Kunjungan Wali', titipan: 'Riwayat Titipan Santri', sakit: 'Riwayat Kunjungan Klinik', nilai: 'Ringkasan Nilai Semester' }
const judul = computed(() => JUDUL[props.jenis] || 'Laporan Portal Wali')
const periode = computed(() => props.jenis === 'nilai' ? `Semester ${SEMESTER_RAPOR[d.value.semester] || d.value.semester} Tahun Ajaran ${d.value.ta || ''}`
  : d.value.mulai ? `${formatPanjang(d.value.mulai)} s.d. ${formatPanjang(d.value.selesai)}` : '')
const namaPdf = computed(() => namaBerkas(s.value.nama, judul.value, props.jenis === 'nilai' ? `Semester ${d.value.semester} ${d.value.ta || ''}` : periodeRentang(d.value.mulai, d.value.selesai)))
const pencetak = computed(() => `Portal Wali (${(HUBUNGAN_WALI[pw.beranda?.wali?.hubungan] || 'wali').toLowerCase()})`)
const angka = (n) => (n == null ? '–' : Number(n).toLocaleString('id-ID', { maximumFractionDigits: 2 }))
const persen = (p) => (p == null ? '–' : `${String(p).replace('.', ',')}%`)

// Kehadiran: sesi dengan catatan (selain Hadir)
const URUT = ['kelas', 'halaqah', 'asrama', 'ekskul']
const rekap = computed(() => d.value.rekap || {})
const catatanHadir = computed(() => (d.value.sesi || []).filter((x) => x.k !== 'H'))
</script>

<template>
  <DokumenCetak kop="pondok" :judul="judul" :subjudul="periode" :nama-berkas="namaPdf" :pencetak="pencetak" v-model:pratinjau="pratinjau">
    <table class="meta-dok">
      <tr><td>Nama santri</td><td>:</td><td>{{ s.nama }}</td></tr>
      <tr><td>NIS</td><td>:</td><td>{{ s.nis }}</td></tr>
      <tr><td>Kelas</td><td>:</td><td>{{ jenis === 'nilai' ? d.kelas : s.kelas || '–' }}</td></tr>
    </table>

    <!-- KEHADIRAN -->
    <template v-if="jenis === 'kehadiran'">
      <table class="tabel">
        <colgroup><col style="width: 22%"><col><col><col><col><col><col><col><col style="width: 13%"></colgroup>
        <thead><tr><th>Kegiatan</th><th>Sesi</th><th>Hadir</th><th>Izin</th><th>Sakit</th><th>Absen</th><th>Bolos</th><th>Terlambat</th><th>Persentase</th></tr></thead>
        <tbody>
          <tr v-for="j in URUT.filter((x) => rekap[x]?.sesi)" :key="j"><td>{{ JENIS_ABSENSI[j].n }}{{ j === 'ekskul' ? ' (di luar program pokok)' : '' }}</td>
            <td class="tengah">{{ rekap[j].sesi }}</td><td class="tengah">{{ rekap[j].hadir }}</td><td class="tengah">{{ rekap[j].izin }}</td><td class="tengah">{{ rekap[j].sakit }}</td>
            <td class="tengah">{{ rekap[j].absen }}</td><td class="tengah">{{ rekap[j].bolos }}</td><td class="tengah">{{ rekap[j].terlambat }}</td><td class="tengah">{{ persen(rekap[j].persen) }}</td></tr>
          <tr v-if="rekap.pokok?.sesi"><td>Program pokok (kelas, halaqah, asrama)</td>
            <td class="tengah">{{ rekap.pokok.sesi }}</td><td class="tengah">{{ rekap.pokok.hadir }}</td><td class="tengah">{{ rekap.pokok.izin }}</td><td class="tengah">{{ rekap.pokok.sakit }}</td>
            <td class="tengah">{{ rekap.pokok.absen }}</td><td class="tengah">{{ rekap.pokok.bolos }}</td><td class="tengah">{{ rekap.pokok.terlambat }}</td><td class="tengah">{{ persen(rekap.pokok.persen) }}</td></tr>
        </tbody>
      </table>
      <p style="margin: 4pt 0 10pt; font-size: 9pt">Terlambat dan Bolos tetap dihitung hadir.</p>
      <p style="margin: 0 0 4pt"><b>Catatan ketidakhadiran dan keterlambatan</b></p>
      <table v-if="catatanHadir.length" class="tabel">
        <colgroup><col style="width: 6%"><col style="width: 26%"><col style="width: 30%"><col style="width: 14%"><col></colgroup>
        <thead><tr><th>No.</th><th>Hari, tanggal</th><th>Kegiatan</th><th>Keterangan</th><th>Catatan</th></tr></thead>
        <tbody><tr v-for="(x, i) in catatanHadir" :key="i"><td class="tengah">{{ i + 1 }}</td><td>{{ formatHari(x.t) }}</td><td>{{ x.s }}<template v-if="x.jam"> ({{ x.jam }})</template></td>
          <td>{{ KODE[x.k]?.n || x.k }}</td><td>{{ x.ket || '' }}</td></tr></tbody>
      </table>
      <p v-else>Tidak ada catatan ketidakhadiran pada periode ini.</p>
    </template>

    <!-- HAFALAN -->
    <template v-if="jenis === 'hafalan'">
      <table class="meta-dok">
        <tr><td>Program</td><td>:</td><td>{{ PROGRAM[d.program] || d.program }}<template v-if="d.halaqah"> · {{ d.halaqah }}</template></td></tr>
        <tr><td>Hafalan resmi</td><td>:</td><td>{{ (d.juz || []).length }} juz ({{ (d.juz || []).map((j) => j.juz).sort((a, b) => a - b).join(', ') || '–' }})</td></tr>
        <tr><td>Posisi terakhir</td><td>:</td><td>Sabaq {{ formatPosisi(d.sabaq_hal, true) }} · Sabqi {{ formatPosisi(d.sabqi_hal, true) }} · Manzil {{ formatPosisi(d.manzil_hal, true) }}</td></tr>
      </table>
      <template v-if="d.bulanan?.length">
        <p style="margin: 6pt 0 4pt"><b>Capaian bulanan yang disahkan</b></p>
        <table class="tabel">
          <thead><tr><th style="width: 6%">No.</th><th>Bulan</th><th>Bertambah</th><th>Target</th><th>Status</th></tr></thead>
          <tbody><tr v-for="(b, i) in d.bulanan" :key="b.bulan"><td class="tengah">{{ i + 1 }}</td><td>{{ labelBulan(b.bulan) }}</td><td>{{ formatPosisi(b.tambah_hal, true) }}</td>
            <td>{{ b.target_hal ? formatPosisi(b.target_hal, true) : '–' }}</td><td>{{ STATUS_BULANAN[b.status]?.n || b.status }}</td></tr></tbody>
        </table>
      </template>
      <p style="margin: 8pt 0 4pt"><b>Riwayat setoran</b></p>
      <table v-if="d.setoran?.length" class="tabel">
        <colgroup><col style="width: 6%"><col style="width: 24%"><col style="width: 16%"><col><col><col><col style="width: 22%"></colgroup>
        <thead><tr><th>No.</th><th>Hari, tanggal</th><th>Sesi</th><th>Sabaq</th><th>Sabqi</th><th>Manzil</th><th>Catatan</th></tr></thead>
        <tbody><tr v-for="(x, i) in d.setoran" :key="i"><td class="tengah">{{ i + 1 }}</td><td>{{ formatHari(x.tanggal) }}</td><td>{{ x.sesi }}</td>
          <td>{{ formatPosisi(x.sabaq_hal) }}<template v-if="x.tambah_hal > 0"> (+{{ formatPosisi(x.tambah_hal) }})</template></td><td>{{ formatPosisi(x.sabqi_hal) }}</td><td>{{ formatPosisi(x.manzil_hal) }}</td><td>{{ x.catatan || '' }}</td></tr></tbody>
      </table>
      <p v-else>Belum ada catatan setoran pada periode ini.</p>
    </template>

    <!-- PERIZINAN -->
    <template v-if="jenis === 'perizinan'">
      <table v-if="d.izin?.length" class="tabel">
        <colgroup><col style="width: 6%"><col style="width: 15%"><col><col style="width: 25%"><col style="width: 20%"><col style="width: 13%"></colgroup>
        <thead><tr><th>No.</th><th>Jenis</th><th>Alasan</th><th>Rencana keluar – kembali</th><th>Keluar/kembali gerbang</th><th>Status</th></tr></thead>
        <tbody><tr v-for="(x, i) in d.izin" :key="i"><td class="tengah">{{ i + 1 }}</td><td>{{ JENIS_IZIN[x.jenis] || x.jenis }}</td><td>{{ x.alasan }}</td>
          <td>{{ formatWaktu(x.keluar_pada) }} – {{ formatWaktu(x.kembali_batas) }}</td>
          <td>{{ x.keluar_aktual ? formatWaktu(x.keluar_aktual) : '–' }} / {{ x.kembali_pada ? formatWaktu(x.kembali_pada) : '–' }}</td>
          <td>{{ STATUS_IZIN[x.status]?.n || x.status }}{{ x.terlambat ? ' (terlambat)' : '' }}</td></tr></tbody>
      </table>
      <p v-else>Tidak ada izin keluar pada periode ini.</p>
      <template v-if="d.libur?.length">
        <p style="margin: 8pt 0 4pt"><b>Libur santri</b></p>
        <table class="tabel"><thead><tr><th style="width: 6%">No.</th><th>Libur</th><th>Pulang</th><th>Kembali paling lambat</th><th>Keputusan</th></tr></thead>
          <tbody><tr v-for="(l, i) in d.libur" :key="i"><td class="tengah">{{ i + 1 }}</td><td>{{ l.nama }}</td><td>{{ formatWaktu(l.pulang_pada) }}</td><td>{{ formatWaktu(l.kembali_batas) }}</td>
            <td>{{ l.keputusan === 'boleh' ? 'Boleh libur' : 'Tidak libur' }}</td></tr></tbody></table>
      </template>
    </template>

    <!-- KUNJUNGAN -->
    <template v-if="jenis === 'kunjungan'">
      <table v-if="d.kunjungan?.length" class="tabel">
        <thead><tr><th style="width: 6%">No.</th><th>Hari, tanggal</th><th>Pengunjung</th><th>Jumlah</th><th>Datang</th><th>Pulang</th></tr></thead>
        <tbody><tr v-for="(v, i) in d.kunjungan" :key="i"><td class="tengah">{{ i + 1 }}</td><td>{{ formatHari(v.datang_pada) }}</td><td>{{ v.pengunjung }}<template v-if="v.hubungan"> ({{ v.hubungan }})</template></td>
          <td class="tengah">{{ v.jumlah_orang }}</td><td>{{ formatWaktu(v.datang_pada) }}</td><td>{{ v.pulang_pada ? formatWaktu(v.pulang_pada) : '–' }}</td></tr></tbody>
      </table>
      <p v-else>Tidak ada kunjungan pada periode ini.</p>
    </template>

    <!-- TITIPAN -->
    <template v-if="jenis === 'titipan'">
      <table v-if="d.titipan?.length" class="tabel">
        <thead><tr><th style="width: 6%">No.</th><th>Jenis dan uraian</th><th>Pengirim</th><th>Diterima pos</th><th>Diambil</th><th>Status</th></tr></thead>
        <tbody><tr v-for="(t, i) in d.titipan" :key="i"><td class="tengah">{{ i + 1 }}</td><td>{{ JENIS_TITIPAN[t.jenis]?.n || t.jenis }}<template v-if="t.uraian">: {{ t.uraian }}</template><template v-if="t.nominal"> ({{ rupiah(t.nominal) }})</template></td>
          <td>{{ t.pengirim || '–' }}</td><td>{{ formatWaktu(t.diterima_pada) }}</td><td>{{ t.diambil_pada ? `${formatWaktu(t.diambil_pada)} oleh ${t.pengambil_nama || PENGAMBIL[t.pengambil_jenis] || '–'}` : '–' }}</td>
          <td>{{ STATUS_TITIPAN[t.status]?.n || t.status }}</td></tr></tbody>
      </table>
      <p v-else>Tidak ada titipan pada periode ini.</p>
    </template>

    <!-- SAKIT -->
    <template v-if="jenis === 'sakit'">
      <table v-if="d.kasus?.length" class="tabel">
        <thead><tr><th style="width: 6%">No.</th><th>Hari, tanggal</th><th>Keluhan</th><th>Penanganan</th><th>Status</th><th>Selesai</th></tr></thead>
        <tbody><tr v-for="(c, i) in d.kasus" :key="i"><td class="tengah">{{ i + 1 }}</td><td>{{ formatHari(c.dibuka_pada) }}</td><td>{{ c.keluhan || '–' }}</td>
          <td>{{ TINDAK_LANJUT[c.tindak_lanjut]?.n || c.tindak_lanjut || '–' }}</td><td>{{ STATUS_KASUS[c.status]?.n || c.status }}</td><td>{{ c.selesai_pada ? formatPendek(c.selesai_pada) : '–' }}</td></tr></tbody>
      </table>
      <p v-else>Tidak ada kunjungan Klinik pada periode ini.</p>
    </template>

    <!-- NILAI -->
    <template v-if="jenis === 'nilai'">
      <table class="tabel">
        <colgroup><col style="width: 6%"><col style="width: 28%"><col style="width: 9%"><col style="width: 9%"><col style="width: 12%"><col></colgroup>
        <thead><tr><th>No.</th><th>Mata pelajaran</th><th>{{ d.label_ambang || 'KKM' }}</th><th>Nilai</th><th>Predikat</th><th>Deskripsi</th></tr></thead>
        <tbody><tr v-for="(m, i) in d.mapel || []" :key="i"><td class="tengah">{{ i + 1 }}</td><td>{{ m.nama }}</td><td class="tengah">{{ angka(m.kkm) }}</td>
          <td class="tengah">{{ m.nilai == null ? '–' : Math.round(m.nilai) }}</td><td class="tengah">{{ m.predikat || '–' }}</td><td>{{ m.deskripsi || '' }}</td></tr></tbody>
      </table>
      <table v-if="d.kehadiran" class="meta-dok" style="margin-top: 8pt">
        <tr><td>Kehadiran</td><td>:</td><td>Hadir {{ d.kehadiran.hadir }} dari {{ d.kehadiran.hari }} hari · Sakit {{ d.kehadiran.sakit }} · Izin {{ d.kehadiran.izin }} · Tanpa keterangan {{ d.kehadiran.absen }}</td></tr>
        <tr v-if="d.catatan"><td>Catatan wali kelas</td><td>:</td><td>{{ d.catatan }}</td></tr>
        <tr v-if="d.keputusan?.keputusan"><td>Keputusan</td><td>:</td><td>{{ teksKeputusan(d.keputusan, d.tingkat) }}</td></tr>
      </table>
    </template>

    <p style="margin-top: 12pt; font-size: 9pt; font-style: italic">Dokumen ini dicetak dari Portal Wali SIMKA PRO sebagai informasi untuk orang tua/wali dan bukan dokumen resmi pondok.</p>
  </DokumenCetak>
</template>
