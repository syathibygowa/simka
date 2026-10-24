<!-- SIMKA PRO | src/pages/izin/CetakSuratIzin.vue | v1.0 | 14.20.0: surat izin keluar/pulang santri bernomor dan berkode validasi | 22/10/2026 -->
<script setup>
// Surat Izin Keluar/Pulang Santri (F4 tegak) — pengganti buku/selembaran izin yang dulu ditandatangani musyrif dan
// kesantrian. Nomor SIK dan kode validasi terbit otomatis saat izin disetujui (termasuk usulan Klinik untuk santri sakit
// dan izin cepat). Tanda tangan elektronik: kiri pemutus terakhir (kepala bidang/unit atau Direktur/Wadir), kanan pengusul.
// Kolom catatan Security diisi waktu keluar/kembali yang tercatat di gerbang (kosong untuk ditulis tangan bila belum).
// Kop mengikuti unit pemutus (Wustha/SMA untuk izin dari wali kelas, selain itu Pondok).
import { computed } from 'vue'
import { formatPanjang, formatJam, formatWaktu } from '@/lib/tanggal'
import { PERAN_PENGUSUL } from '@/lib/izin'
import { namaBerkas } from '@/lib/namaBerkas'
import { useSesi } from '@/stores/sesi'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import CatatanValidasi from '@/components/cetak/CatatanValidasi.vue'

const pratinjau = defineModel('pratinjau', { type: Boolean, default: false })
const props = defineProps({ surat: { type: Object, default: null } })
const sesi = useSesi()
const s = computed(() => props.surat || {})
const judul = computed(() => (s.value.jenis === 'keluar' ? 'Surat Izin Keluar Santri' : 'Surat Izin Pulang Santri'))
const setuju = computed(() => (s.value.persetujuan || []).filter((a) => a.keputusan === 'setuju'))
const pemutus = computed(() => setuju.value[setuju.value.length - 1] || null)
const tidakBerlaku = computed(() => (['dibatalkan', 'ditolak'].includes(s.value.status) ? 'dicabut' : ''))
const kelas = computed(() => [s.value.santri?.kelas && `Kelas ${String(s.value.santri.kelas).replace(/^kelas\s*/i, '')}`, s.value.santri?.kamar].filter(Boolean).join(' / ') || '–')
const tglWaktu = (v) => (v ? `${formatPanjang(v)}, pukul ${formatJam(v)} WITA` : '–')
const keperluan = computed(() => (s.value.sumber === 'klinik' ? `${s.value.alasan} (usulan Klinik, santri sakit)` : s.value.alasan))
</script>
<template>
  <DokumenCetak v-if="surat" jenis="izin_surat_santri" v-model:pratinjau="pratinjau" :kop="s.kop || 'pondok'" :konteks="{ jenjang: s.santri?.jenjang }" :judul="judul" :nomor="s.nomor"
    :nama-berkas="namaBerkas(s.santri?.nama, judul, s.nomor)" :pencetak="sesi.pengguna?.nama_lengkap">
    <p>Yang bertanda tangan di bawah ini memberikan izin kepada santri:</p>
    <table class="data" style="margin: 4pt 0 6pt 12pt">
      <tbody>
        <tr><td style="width: 42mm">Nama</td><td style="width: 4mm">:</td><td><b>{{ s.santri?.nama }}</b></td></tr>
        <tr><td>NIS / NISN</td><td>:</td><td>{{ s.santri?.nis || '–' }} / {{ s.santri?.nisn || '–' }}</td></tr>
        <tr><td>Kelas / kamar</td><td>:</td><td>{{ kelas }}</td></tr>
        <tr v-if="s.santri?.halaqah"><td>Halaqah</td><td>:</td><td>{{ s.santri.halaqah }}</td></tr>
      </tbody>
    </table>
    <p>untuk {{ s.jenis === 'keluar' ? 'keluar pondok beberapa jam' : 'pulang ke rumah' }} dengan keterangan sebagai berikut:</p>
    <table class="data" style="margin: 4pt 0 6pt 12pt">
      <tbody>
        <tr><td style="width: 42mm">Keperluan</td><td style="width: 4mm">:</td><td>{{ keperluan }}</td></tr>
        <tr><td>Waktu keluar</td><td>:</td><td>{{ tglWaktu(s.keluar_pada) }}</td></tr>
        <tr><td>Batas kembali</td><td>:</td><td><b>{{ tglWaktu(s.kembali_batas) }}</b></td></tr>
        <tr><td>Lama izin</td><td>:</td><td>{{ s.jenis === 'keluar' ? 'beberapa jam' : `${s.lama_hari} hari` }}</td></tr>
        <tr><td>Penjemput</td><td>:</td><td>{{ s.penjemput ? `${s.penjemput}${s.hubungan_penjemput ? ' (' + s.hubungan_penjemput + ')' : ''}${s.hp_penjemput ? ', HP ' + s.hp_penjemput : ''}` : '–' }}</td></tr>
        <tr><td>Diusulkan oleh</td><td>:</td><td>{{ s.pengusul?.nama || '–' }}{{ PERAN_PENGUSUL[s.pengusul?.peran] ? ' (' + PERAN_PENGUSUL[s.pengusul.peran] + ')' : '' }}</td></tr>
        <tr v-if="s.catatan"><td>Catatan</td><td>:</td><td>{{ s.catatan }}</td></tr>
      </tbody>
    </table>

    <p style="margin: 6pt 0 2pt"><b>Persetujuan</b></p>
    <table class="tabel kecil">
      <colgroup><col style="width: 6%"><col style="width: 32%"><col style="width: 34%"><col style="width: 28%"></colgroup>
      <thead><tr><th>No.</th><th>Jabatan</th><th>Nama</th><th>Waktu</th></tr></thead>
      <tbody>
        <tr v-for="(a, i) in setuju" :key="i"><td class="tengah">{{ i + 1 }}</td><td>{{ a.sebagai }}</td><td>{{ a.nama }}</td><td class="tengah">{{ formatWaktu(a.pada) }} WITA</td></tr>
        <tr v-if="!setuju.length"><td colspan="4" class="tengah">Belum ada persetujuan.</td></tr>
      </tbody>
    </table>

    <p style="margin: 8pt 0 2pt"><b>Catatan petugas Security</b></p>
    <table class="tabel kecil">
      <colgroup><col style="width: 22%"><col style="width: 38%"><col style="width: 24%"><col style="width: 16%"></colgroup>
      <thead><tr><th>Kejadian</th><th>Tanggal dan jam</th><th>Petugas</th><th>Paraf</th></tr></thead>
      <tbody>
        <tr><td>Keluar pondok</td><td class="tengah">{{ s.keluar_aktual ? formatWaktu(s.keluar_aktual) + ' WITA' : '' }}</td><td /><td /></tr>
        <tr><td>Kembali ke pondok</td><td class="tengah">{{ s.kembali_pada ? formatWaktu(s.kembali_pada) + ' WITA' : '' }}</td><td /><td /></tr>
      </tbody>
    </table>
    <p style="margin-top: 6pt; text-align: justify">Surat ini ditunjukkan kepada petugas Security saat keluar dan kembali. Santri wajib kembali ke pondok paling lambat
      {{ tglWaktu(s.kembali_batas) }}; keterlambatan dicatat dan menjadi pertimbangan izin berikutnya.</p>
    <template #ttd>
      <TandaTangan :tanggal="(pemutus?.pada || s.created_at || '').slice(0, 10) || undefined"
        :kiri="{ pengantar: 'Menyetujui,', jabatan: pemutus?.sebagai || 'Kepala Bidang Kesantrian', nama: pemutus?.nama || '', niy: pemutus?.niy, kode: pemutus ? s.kode_validasi : null, waktu: pemutus?.pada }"
        :kanan="{ jabatan: PERAN_PENGUSUL[s.pengusul?.peran] || 'Pengusul', nama: s.pengusul?.nama || '', niy: s.pengusul?.niy, kode: s.kode_validasi, waktu: s.created_at }" />
      <CatatanValidasi :kode="s.kode_validasi" :status="tidakBerlaku" />
    </template>
  </DokumenCetak>
</template>
