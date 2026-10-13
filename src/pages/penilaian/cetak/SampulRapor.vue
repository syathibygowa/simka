<!-- SIMKA PRO | src/pages/penilaian/cetak/SampulRapor.vue | v1.0 | Fase 12 – Tahap 5 Sampul dan identitas rapor | 13/10/2026 -->
<script setup>
// Halaman depan rapor:
//   sampul   : logo, judul laporan, nama sekolah dan alamat, nama dan NIS/NISN santri, kementerian
//   sekolah  : identitas sekolah (nama, NPSN, NSS, alamat, kode pos, kelurahan, kecamatan, kota, provinsi, e-mail)
//   santri   : identitas peserta didik (biodata, orang tua, wali) dengan kolom pas foto dan tanda tangan kepala
// Identitas sekolah diatur di Penilaian → Ketentuan; biodata dari Data Santri.
import { computed } from 'vue'
import HalRapor from '@/components/cetak/rapor/HalRapor.vue'
import { useLembaga } from '@/stores/lembaga'
import { nisNisn, ttl, JK_PANJANG, ROMAWI } from '@/lib/rapor'
import { formatPanjang } from '@/lib/tanggal'

const props = defineProps({ D: { type: Object, required: true }, mode: { type: String, default: 'sampul' }, pilih: { type: Array, default: null } })
const lembaga = useLembaga()
const ket = computed(() => props.D.ketentuan || {})
const idn = computed(() => ket.value.identitas || {})
const jenjang = computed(() => props.D.kelas?.jenjang || props.D.kelompok?.jenjang)
const sma = computed(() => jenjang.value === 'sma')
const logo = computed(() => idn.value.logo_url || lembaga.identitas?.logo_url || '')
const daftar = computed(() => (props.D.santri || []).filter((s) => !props.pilih || props.pilih.includes(s.id)))
const judulSampul = computed(() => (sma.value ? 'HASIL CAPAIAN KOMPETENSI PESERTA DIDIK' : 'PENCAPAIAN KOMPETENSI PESERTA DIDIK'))
const BARIS_SEKOLAH = [['Nama Sekolah', 'nama_sekolah'], ['NPSN', 'npsn'], [null, 'nss'], ['Alamat Sekolah', 'alamat'], ['Kode Pos', 'kode_pos'], ['Telepon', 'telepon'],
  ['Kelurahan/Desa', 'kelurahan'], ['Kecamatan', 'kecamatan'], ['Kabupaten/Kota', 'kota'], ['Provinsi', 'provinsi'], ['E-mail', 'email']]
const labelNss = computed(() => (sma.value ? 'NSS' : 'NSPP'))
const kepala = computed(() => props.D.penanda || {})
const ortu = (s, k) => s[k]?.nama || '-'
</script>
<template>
  <!-- Sampul: satu per santri -->
  <template v-if="mode === 'sampul'">
    <HalRapor v-for="s in daftar" :key="s.id" tanpa-kop>
      <div class="sampul" style="padding-top: 18mm">
        <img v-if="logo" :src="logo" alt="Logo" style="width: 42mm; height: 42mm; object-fit: contain" />
        <p style="margin-top: 10mm; font-size: 26pt; font-weight: 700">LAPORAN</p>
        <p style="font-size: 15pt; font-weight: 700">{{ judulSampul }}</p>
        <p style="font-size: 15pt; font-weight: 700; text-transform: uppercase">{{ idn.jenjang || '' }}</p>
        <p style="margin-top: 16mm; font-size: 14pt; font-weight: 700; text-transform: uppercase">{{ idn.nama_sekolah || '' }}</p>
        <p style="font-size: 11pt; font-weight: 700">{{ idn.alamat || '' }}</p>
        <div style="margin-top: 26mm; width: 70%">
          <p style="font-size: 11pt">Nama Peserta Didik</p>
          <p style="border: 1pt solid #000; padding: 6pt; font-size: 14pt; font-weight: 700">{{ s.nama.toUpperCase() }}</p>
          <p style="margin-top: 6mm; font-size: 11pt">NIS/NISN</p>
          <p style="border: 1pt solid #000; padding: 6pt; font-size: 14pt; font-weight: 700">{{ nisNisn(s) }}</p>
        </div>
        <p style="margin-top: auto; padding-top: 20mm; font-size: 14pt; font-weight: 700; text-transform: uppercase">{{ idn.kementerian || '' }}</p>
      </div>
    </HalRapor>
  </template>

  <!-- Identitas sekolah: satu halaman (dicetak sekali, digandakan bila perlu) -->
  <HalRapor v-else-if="mode === 'sekolah'" tanpa-kop>
    <div class="sampul" style="padding-top: 10mm">
      <img v-if="logo" :src="logo" alt="Logo" style="width: 36mm; height: 36mm; object-fit: contain" />
      <p style="margin-top: 8mm; font-size: 22pt; font-weight: 700">LAPORAN</p>
      <p style="margin-top: 4mm; font-size: 14pt; font-weight: 700">HASIL BELAJAR PESERTA DIDIK</p>
      <p style="margin-top: 8mm; font-size: 14pt; font-weight: 700; text-transform: uppercase">{{ idn.jenjang || '' }}</p>
      <table class="identitas" style="margin-top: 18mm; width: 88%; font-size: 11.5pt; text-align: left"><colgroup><col style="width:30%"><col style="width:3%"><col style="width:67%"></colgroup><tbody>
        <template v-for="[n, k] in BARIS_SEKOLAH" :key="k">
          <tr><td style="padding: 4pt 2pt">{{ n || labelNss }}</td><td style="padding: 4pt 0">:</td><td style="padding: 4pt 2pt; font-weight: 700">{{ idn[k] || '' }}</td></tr>
        </template></tbody></table>
    </div>
  </HalRapor>

  <!-- Identitas peserta didik -->
  <template v-else>
    <HalRapor v-for="s in daftar" :key="s.id" tanpa-kop>
      <p class="judul-rapor" style="margin-top: 4mm">IDENTITAS PESERTA DIDIK</p>
      <p style="text-align: center; font-weight: 700; text-transform: uppercase; margin-bottom: 10pt">{{ idn.nama_sekolah || '' }}</p>
      <table class="identitas" style="font-size: 11pt"><colgroup><col style="width:5%"><col style="width:33%"><col style="width:3%"><col style="width:59%"></colgroup><tbody>
        <tr><td>1.</td><td>Nama Peserta Didik</td><td>:</td><td>{{ s.nama.toUpperCase() }}</td></tr>
        <tr><td>2.</td><td>Nomor Induk/NISN</td><td>:</td><td>{{ nisNisn(s) }}</td></tr>
        <tr><td>3.</td><td>Tempat, Tanggal Lahir</td><td>:</td><td>{{ ttl(s) || '-' }}</td></tr>
        <tr><td>4.</td><td>Jenis Kelamin</td><td>:</td><td>{{ JK_PANJANG[s.jenis_kelamin] || '-' }}</td></tr>
        <tr><td>5.</td><td>Agama</td><td>:</td><td>{{ s.agama || 'Islam' }}</td></tr>
        <tr><td>6.</td><td>Status dalam Keluarga</td><td>:</td><td>{{ s.status_keluarga || '-' }}</td></tr>
        <tr><td>7.</td><td>Anak ke</td><td>:</td><td>{{ s.anak_ke || '-' }}</td></tr>
        <tr><td>8.</td><td>Alamat Peserta Didik</td><td>:</td><td>{{ s.alamat || '-' }}</td></tr>
        <tr><td>9.</td><td>Nomor Telepon Rumah</td><td>:</td><td>{{ s.telepon_rumah || '-' }}</td></tr>
        <tr><td>10.</td><td>Sekolah Asal</td><td>:</td><td>{{ s.asal_sekolah || '-' }}</td></tr>
        <tr><td>11.</td><td>Diterima di sekolah ini</td><td></td><td></td></tr>
        <tr><td></td><td>a. Di Kelas</td><td>:</td><td>{{ ROMAWI[s.diterima_tingkat] || s.diterima_tingkat || '-' }}</td></tr>
        <tr><td></td><td>b. Pada Tanggal</td><td>:</td><td>{{ s.tanggal_masuk ? formatPanjang(s.tanggal_masuk) : '-' }}</td></tr>
        <tr><td>12.</td><td>Nama Orang Tua</td><td></td><td></td></tr>
        <tr><td></td><td>a. Ayah</td><td>:</td><td>{{ ortu(s, 'ayah') }}</td></tr>
        <tr><td></td><td>b. Ibu</td><td>:</td><td>{{ ortu(s, 'ibu') }}</td></tr>
        <tr><td></td><td>c. Alamat</td><td>:</td><td>{{ s.alamat_ortu || s.ayah?.alamat || s.ibu?.alamat || '-' }}</td></tr>
        <tr><td></td><td>d. Nomor Telepon</td><td>:</td><td>{{ s.ayah?.no_hp || s.ibu?.no_hp || '-' }}</td></tr>
        <tr><td>13.</td><td>Pekerjaan Orang Tua</td><td></td><td></td></tr>
        <tr><td></td><td>a. Ayah</td><td>:</td><td>{{ s.ayah?.pekerjaan || '-' }}</td></tr>
        <tr><td></td><td>b. Ibu</td><td>:</td><td>{{ s.ibu?.pekerjaan || '-' }}</td></tr>
        <tr><td>14.</td><td>Nama Wali Peserta Didik</td><td>:</td><td>{{ s.wali?.nama || '-' }}</td></tr>
        <tr><td></td><td>a. Alamat</td><td>:</td><td>{{ s.wali?.alamat || '-' }}</td></tr>
        <tr><td></td><td>b. Nomor Telepon</td><td>:</td><td>{{ s.wali?.no_hp || '-' }}</td></tr>
        <tr><td></td><td>c. Pekerjaan</td><td>:</td><td>{{ s.wali?.pekerjaan || '-' }}</td></tr>
      </tbody></table>
      <div style="display: grid; grid-template-columns: 1fr 1fr; column-gap: 16mm; margin-top: 16pt; break-inside: avoid">
        <div style="display: flex; justify-content: center"><div style="width: 30mm; height: 40mm; border: .5pt solid #000; display: grid; place-items: center; font-size: 9pt">Pas foto<br>3 × 4</div></div>
        <div style="text-align: center; font-size: 11pt"><p>{{ ket.tempat || 'Gowa' }}, {{ formatPanjang(s.tanggal_masuk || new Date()) }}</p><p>{{ kepala.jabatan || ket.jabatan_ttd || 'Kepala Sekolah' }}</p>
          <div style="height: 22mm" /><p style="font-weight: 700; text-decoration: underline">{{ kepala.nama || '..................................' }}</p><p v-if="kepala.niy">NIY. {{ kepala.niy }}</p></div>
      </div>
    </HalRapor>
  </template>
</template>
