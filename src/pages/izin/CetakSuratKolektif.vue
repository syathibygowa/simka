<!-- SIMKA PRO | src/pages/izin/CetakSuratKolektif.vue | v1.0 | 14.20.0: surat izin kolektif santri dengan daftar santri | 22/10/2026 -->
<script setup>
// Surat Izin Kolektif Santri (F4 tegak): satu surat untuk beberapa santri dari kelas/kamar berbeda (mis. lomba),
// memuat kegiatan, tempat, waktu, pendamping, dan daftar santri (NIS › Nama › JK › Kelas › Kamar) dengan kolom
// keluar/kembali yang terisi dari pencatatan gerbang. Tanda tangan elektronik: kiri pemutus terakhir, kanan pengusul.
import { computed } from 'vue'
import { formatPanjang, formatJam, formatWaktu } from '@/lib/tanggal'
import { namaBerkas } from '@/lib/namaBerkas'
import { useSesi } from '@/stores/sesi'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import CatatanValidasi from '@/components/cetak/CatatanValidasi.vue'

const pratinjau = defineModel('pratinjau', { type: Boolean, default: false })
const props = defineProps({ kolektif: { type: Object, default: null } })
const sesi = useSesi()
const k = computed(() => props.kolektif || {})
const anggota = computed(() => (k.value.anggota || []).filter((a) => !['dibatalkan', 'ditolak'].includes(a.status)))
const setuju = computed(() => (k.value.keputusan || []).filter((a) => a.keputusan === 'setuju'))
const pemutus = computed(() => setuju.value[setuju.value.length - 1] || null)
const tglWaktu = (v) => (v ? `${formatPanjang(v)}, pukul ${formatJam(v)} WITA` : '–')
const jam = (v) => (v ? formatWaktu(v) : '')
const draf = computed(() => !k.value.kode_validasi)
const tidakBerlaku = computed(() => (['dibatalkan', 'ditolak'].includes(k.value.status) ? 'dicabut' : ''))
</script>
<template>
  <DokumenCetak v-if="kolektif" jenis="izin_surat_kolektif" v-model:pratinjau="pratinjau" kop="pondok" judul="Surat Izin Kolektif Santri" :nomor="k.nomor_surat || 'belum bernomor'"
    :nama-berkas="namaBerkas(k.kegiatan, 'Surat Izin Kolektif Santri', k.nomor_surat)" :pencetak="sesi.pengguna?.nama_lengkap">
    <p style="text-align: justify">Yang bertanda tangan di bawah ini memberikan izin kepada {{ anggota.length }} ({{ anggota.length }}) santri yang namanya tercantum
      di bawah ini untuk {{ k.jenis === 'pulang' ? 'meninggalkan pondok (menginap)' : 'keluar pondok' }} dengan keterangan sebagai berikut:</p>
    <table class="data" style="margin: 4pt 0 6pt 12pt">
      <tbody>
        <tr><td style="width: 42mm">Kegiatan</td><td style="width: 4mm">:</td><td><b>{{ k.kegiatan }}</b></td></tr>
        <tr><td>Tempat</td><td>:</td><td>{{ k.tempat || '–' }}</td></tr>
        <tr><td>Keperluan</td><td>:</td><td>{{ k.alasan }}</td></tr>
        <tr><td>Waktu keluar</td><td>:</td><td>{{ tglWaktu(k.keluar_pada) }}</td></tr>
        <tr><td>Batas kembali</td><td>:</td><td><b>{{ tglWaktu(k.kembali_batas) }}</b></td></tr>
        <tr><td>Pendamping</td><td>:</td><td>{{ k.pendamping || '–' }}{{ k.hp_pendamping ? ', HP ' + k.hp_pendamping : '' }}</td></tr>
      </tbody>
    </table>
    <p style="margin: 4pt 0 2pt"><b>Daftar santri</b></p>
    <table class="tabel kecil">
      <colgroup><col style="width: 5%"><col style="width: 11%"><col style="width: 25%"><col style="width: 5%"><col style="width: 12%"><col style="width: 14%"><col style="width: 14%"><col style="width: 14%"></colgroup>
      <thead><tr><th>No.</th><th>NIS</th><th>Nama</th><th>JK</th><th>Kelas</th><th>Kamar</th><th>Keluar</th><th>Kembali</th></tr></thead>
      <tbody>
        <tr v-for="(a, i) in anggota" :key="a.student_id"><td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ a.nis || '–' }}</td><td>{{ a.nama }}</td><td class="tengah">{{ a.jenis_kelamin || '–' }}</td>
          <td>{{ a.kelas || '–' }}</td><td>{{ a.kamar || '–' }}</td><td class="tengah">{{ jam(a.keluar_aktual) }}</td><td class="tengah">{{ jam(a.kembali_pada) }}</td></tr>
      </tbody>
    </table>
    <p style="margin: 6pt 0 2pt"><b>Persetujuan</b></p>
    <table class="tabel kecil">
      <colgroup><col style="width: 6%"><col style="width: 32%"><col style="width: 34%"><col style="width: 28%"></colgroup>
      <thead><tr><th>No.</th><th>Jabatan</th><th>Nama</th><th>Waktu</th></tr></thead>
      <tbody>
        <tr v-for="(a, i) in setuju" :key="i"><td class="tengah">{{ i + 1 }}</td><td>{{ a.sebagai }}</td><td>{{ a.oleh }}</td><td class="tengah">{{ formatWaktu(a.pada) }} WITA</td></tr>
        <tr v-if="!setuju.length"><td colspan="4" class="tengah">Belum ada persetujuan.</td></tr>
      </tbody>
    </table>
    <p style="margin-top: 6pt; text-align: justify">Pendamping bertanggung jawab atas santri selama kegiatan. Surat ini ditunjukkan kepada petugas Security saat
      keluar dan kembali; santri wajib kembali ke pondok paling lambat {{ tglWaktu(k.kembali_batas) }}.</p>
    <template #ttd>
      <TandaTangan :tanggal="(pemutus?.pada || k.created_at || '').slice(0, 10) || undefined"
        :kiri="{ pengantar: 'Menyetujui,', jabatan: pemutus?.sebagai || 'Kepala Bidang Kesantrian', nama: pemutus?.oleh || '', niy: pemutus?.niy, kode: pemutus ? k.kode_validasi : null, waktu: pemutus?.pada }"
        :kanan="{ jabatan: 'Pengusul', nama: k.pengusul || '', niy: k.pengusul_niy, kode: k.kode_validasi, waktu: k.created_at }" />
      <CatatanValidasi :kode="k.kode_validasi" :draf="draf" :status="tidakBerlaku" />
    </template>
  </DokumenCetak>
</template>
