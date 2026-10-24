<!-- SIMKA PRO | src/pages/izin/CetakRekapIzin.vue | v1.0 | 14.20.0: rekap perizinan per santri (pengganti buku saku perizinan) | 22/10/2026 -->
<script setup>
// Rekap Perizinan Santri (F4 mendatar) — pengganti buku saku perizinan manual: identitas santri, ringkasan (jumlah izin,
// pulang, keluar, sakit/klinik, kolektif, total hari, terlambat kembali), dan tabel semua izin yang disetujui beserta
// waktu keluar/kembali tercatat di gerbang, keterlambatan, nomor surat, dan penyetuju.
import { computed } from 'vue'
import { formatPanjang, formatPendek, formatWaktu } from '@/lib/tanggal'
import { namaBerkas } from '@/lib/namaBerkas'
import { useSesi } from '@/stores/sesi'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const pratinjau = defineModel('pratinjau', { type: Boolean, default: false })
const props = defineProps({ rekap: { type: Object, default: null } })
const sesi = useSesi()
const s = computed(() => props.rekap?.santri || {})
const izin = computed(() => props.rekap?.izin || [])
const ringkas = computed(() => {
  const x = izin.value
  return { jumlah: x.length, pulang: x.filter((i) => i.jenis === 'pulang').length, keluar: x.filter((i) => i.jenis === 'keluar').length,
    sakit: x.filter((i) => i.sumber === 'klinik').length, kolektif: x.filter((i) => i.sumber === 'kolektif').length, libur: x.filter((i) => i.jenis === 'libur').length,
    hari: x.filter((i) => i.jenis !== 'keluar').reduce((n, i) => n + (Number(i.lama_hari) || 0), 0), terlambat: x.filter((i) => i.terlambat_menit > 0).length }
})
const JENIS = { pulang: 'Pulang', keluar: 'Keluar', libur: 'Libur pondok' }
const jenis = (i) => (i.sumber === 'klinik' ? 'Pulang (sakit)' : i.sumber === 'kolektif' ? `Kolektif (${JENIS[i.jenis]?.toLowerCase()})` : JENIS[i.jenis] || i.jenis)
const telat = (m) => (!m ? '–' : m >= 1440 ? `${Math.floor(m / 1440)} hari ${Math.round((m % 1440) / 60)} jam` : m >= 60 ? `${Math.floor(m / 60)} jam ${m % 60} mnt` : `${m} mnt`)
const kelas = computed(() => [s.value.kelas, s.value.kamar].filter(Boolean).join(' / ') || '–')
</script>
<template>
  <DokumenCetak v-if="rekap" jenis="izin_rekap_santri" v-model:pratinjau="pratinjau" kop="pondok" :konteks="{ jenjang: s.jenjang }" judul="Rekap Perizinan Santri"
    :subjudul="`Sampai dengan ${formatPanjang(new Date())}`" mendatar :nama-berkas="namaBerkas(s.nama, 'Rekap Perizinan', formatPendek(new Date()))" :pencetak="sesi.pengguna?.nama_lengkap">
    <table class="data" style="margin-bottom: 6pt">
      <tbody>
        <tr><td style="width: 38mm">Nama</td><td style="width: 4mm">:</td><td><b>{{ s.nama }}</b></td><td style="width: 38mm">Kelas / kamar</td><td style="width: 4mm">:</td><td>{{ kelas }}</td></tr>
        <tr><td>NIS / NISN</td><td>:</td><td>{{ s.nis || '–' }} / {{ s.nisn || '–' }}</td><td>Halaqah</td><td>:</td><td>{{ s.halaqah || '–' }}</td></tr>
        <tr><td>Tempat, tanggal lahir</td><td>:</td><td>{{ s.tempat_lahir || '–' }}{{ s.tanggal_lahir ? ', ' + formatPanjang(s.tanggal_lahir) : '' }}</td>
          <td>Ringkasan</td><td>:</td><td>{{ ringkas.jumlah }} izin ({{ ringkas.pulang }} pulang, {{ ringkas.keluar }} keluar{{ ringkas.sakit ? `, ${ringkas.sakit} karena sakit` : '' }}{{ ringkas.kolektif ? `, ${ringkas.kolektif} kolektif` : '' }}) ·
            {{ ringkas.hari }} hari di luar · terlambat kembali {{ ringkas.terlambat }} kali</td></tr>
      </tbody>
    </table>
    <table class="tabel kecil">
      <colgroup><col style="width: 3%"><col style="width: 9%"><col style="width: 21%"><col style="width: 16%"><col style="width: 15%"><col style="width: 8%"><col style="width: 12%"><col style="width: 16%"></colgroup>
      <thead><tr><th>No.</th><th>Jenis</th><th>Keperluan</th><th>Izin (keluar s.d. batas kembali)</th><th>Tercatat di gerbang</th><th>Terlambat</th><th>Nomor surat</th><th>Disetujui</th></tr></thead>
      <tbody>
        <tr v-for="(i, n) in izin" :key="i.id">
          <td class="tengah">{{ n + 1 }}</td><td>{{ jenis(i) }}</td><td>{{ i.alasan }}</td>
          <td>{{ formatWaktu(i.keluar_pada) }} s.d. {{ formatWaktu(i.kembali_batas) }}</td>
          <td>{{ i.keluar_aktual ? 'Keluar ' + formatWaktu(i.keluar_aktual) : '–' }}{{ i.kembali_pada ? '; kembali ' + formatWaktu(i.kembali_pada) : i.masih_di_luar ? '; belum kembali' : '' }}</td>
          <td class="tengah">{{ telat(i.terlambat_menit) }}</td><td>{{ i.nomor_surat || '–' }}</td><td>{{ i.disetujui || '–' }}</td>
        </tr>
        <tr v-if="!izin.length"><td colspan="8" class="tengah">Belum ada izin yang disetujui.</td></tr>
      </tbody>
    </table>
    <p style="margin-top: 4pt; font-size: 8pt">Memuat izin yang disetujui (termasuk izin dari Klinik dan izin kolektif). Izin ditolak: {{ rekap.ditolak || 0 }} kali; dibatalkan: {{ rekap.dibatalkan || 0 }} kali.
      Waktu dalam WITA.</p>
    <template #ttd>
      <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: 'Kepala Bidang Kesantrian', nama: '' }" :kanan="{ jabatan: 'Pembuat Rekap', nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
    </template>
  </DokumenCetak>
</template>
