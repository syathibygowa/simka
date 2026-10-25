<!-- SIMKA PRO | src/pages/alumni/CVAlumni.vue | v1.0 | 14.25.0: lembar profil alumni (CV) untuk cetak dan buku alumni | 25/10/2026 -->
<script setup>
// Satu halaman profil alumni bergaya CV dalam <HalRapor> (F4, kop pondok): judul dulu, lalu identitas berfoto, data diri,
// orang tua, riwayat pendidikan di pondok per tahun ajaran, hafalan Al-Quran, sertifikat, prestasi, rencana lanjut studi,
// cita-cita, motto, serta kesan dan pesan. Dipakai di Profil Alumni (cetak satu) dan Buku Alumni (cetak kolektif).
import { computed } from 'vue'
import HalRapor from '@/components/cetak/rapor/HalRapor.vue'
import TtdRapor from '@/components/cetak/rapor/TtdRapor.vue'
import { formatPanjang } from '@/lib/tanggal'
import { ttl, JK_PANJANG } from '@/lib/rapor'
import { JENJANG } from '@/lib/santri'
import { LANJUT, JENIS_PT, STATUS_DAFTAR, JENIS_SERTIFIKAT, riwayatPerTA } from '@/lib/alumni'
import { BIDANG_PRESTASI, TINGKAT_PRESTASI } from '@/lib/prestasi'

const props = defineProps({ p: { type: Object, required: true }, foto: { type: String, default: '' }, nomor: { type: [Number, String], default: null }, tanpaKop: Boolean,
  ttd: { type: Object, default: null } }) // { kiri: { jabatan, nama }, kanan: { jabatan, nama } } — cetak satu profil
const s = computed(() => props.p.santri || {})
const a = computed(() => props.p.alumni || {})
const ortu = (h) => (props.p.kontak || []).find((k) => k.hubungan === h)
const perTA = computed(() => riwayatPerTA(props.p.riwayat))
const nama = (xs) => xs.map((x) => x.nama).join(', ') || '–'
const alamat = computed(() => [s.value.alamat, s.value.kelurahan, s.value.kecamatan, s.value.kota_kab, s.value.provinsi].filter(Boolean).join(', '))
const DIRI = computed(() => [
  ['Nama lengkap', s.value.nama_lengkap], ['NIS / NISN', [s.value.nis, s.value.nisn].filter(Boolean).join(' / ')],
  ['Tempat, tanggal lahir', ttl(s.value) || '–'], ['Jenis kelamin', JK_PANJANG[s.value.jenis_kelamin] || '–'],
  ['Jenjang terakhir', JENJANG[s.value.jenjang] || '–'], ['Masuk pondok', s.value.tanggal_masuk ? formatPanjang(s.value.tanggal_masuk) : '–'],
  ['Tahun lulus', props.p.tahun_lulus || '–'], ['Alamat asal', alamat.value || '–'],
])
const STUDI = computed(() => [
  ['Rencana', LANJUT[a.value.lanjut]?.n], ['Jenis perguruan tinggi', JENIS_PT[a.value.jenis_pt]], ['Kampus/lembaga tujuan', a.value.kampus],
  ['Fakultas', a.value.fakultas], ['Program studi', a.value.prodi], ['Kota/negara', [a.value.kota, a.value.negara].filter(Boolean).join(', ')],
  ['Jalur masuk', a.value.jalur], ['Status', STATUS_DAFTAR[a.value.status_daftar]?.n], ['Tahun mulai', a.value.tahun_mulai], ['Beasiswa', a.value.beasiswa],
].filter((r) => r[1]))
const KONTAK = computed(() => [['Nomor HP', a.value.hp], ['E-mail', a.value.email], ['Alamat sekarang', a.value.alamat_kini]].filter((r) => r[1]))
</script>
<template>
  <HalRapor :tanpa-kop="tanpaKop">
    <template #kepala>
      <p class="judul-rapor" style="margin-bottom: 1pt">PROFIL ALUMNI</p>
      <p style="text-align: center; font-size: 10pt">Lulusan Tahun {{ p.tahun_lulus || '–' }}{{ nomor ? ` · Nomor ${nomor}` : '' }}</p>
    </template>
    <div class="cv-alumni">
      <div class="cv-atas">
        <div class="cv-foto"><img v-if="foto" :src="foto" alt="Pas foto" /><span v-else>Pas foto<br />3 × 4</span></div>
        <div style="flex: 1; min-width: 0">
          <p class="cv-nama">{{ s.nama_lengkap }}</p>
          <p v-if="a.motto" class="cv-motto">“{{ a.motto }}”</p>
          <table class="identitas" style="margin-top: 3pt"><colgroup><col style="width: 34%"><col style="width: 3%"><col></colgroup><tbody>
            <tr v-for="[k, v] in DIRI" :key="k"><td>{{ k }}</td><td>:</td><td>{{ v }}</td></tr>
          </tbody></table>
        </div>
      </div>

      <p class="sub-rapor">A. Orang Tua</p>
      <table class="tabel padat"><colgroup><col style="width: 16%"><col style="width: 38%"><col style="width: 26%"><col style="width: 20%"></colgroup>
        <thead><tr><th>Hubungan</th><th>Nama</th><th>Pekerjaan</th><th>Nomor HP</th></tr></thead>
        <tbody><tr v-for="h in ['ayah', 'ibu']" :key="h"><td>{{ h === 'ayah' ? 'Ayah' : 'Ibu' }}</td><td>{{ ortu(h)?.nama || '–' }}</td><td>{{ ortu(h)?.pekerjaan || '–' }}</td><td class="tengah">{{ ortu(h)?.no_hp || '–' }}</td></tr></tbody>
      </table>

      <p class="sub-rapor">B. Riwayat di Pondok</p>
      <table class="tabel padat"><colgroup><col style="width: 15%"><col style="width: 13%"><col style="width: 26%"><col style="width: 22%"><col style="width: 24%"></colgroup>
        <thead><tr><th>Tahun ajaran</th><th>Kelas</th><th>Wali kelas</th><th>Halaqah</th><th>Kamar</th></tr></thead>
        <tbody>
          <tr v-for="r in perTA" :key="r.ta"><td class="tengah">{{ r.ta }}</td><td class="tengah">{{ nama(r.kelas) }}</td><td>{{ r.kelas.map((x) => x.pengasuh).filter(Boolean).join(', ') || '–' }}</td>
            <td>{{ nama(r.halaqah) }}</td><td>{{ nama(r.kamar) }}</td></tr>
          <tr v-if="!perTA.length"><td colspan="5" class="tengah">Riwayat kelompok belum tercatat di SIMKA.</td></tr>
        </tbody>
      </table>

      <p class="sub-rapor">C. Hafalan Al-Quran</p>
      <p style="font-size: 10pt">Total hafalan resmi <b>{{ p.hafalan?.total_juz || 0 }} juz</b>{{ p.hafalan?.juz?.length ? ` (juz ${p.hafalan.juz.join(', ')})` : '' }}{{ p.hafalan?.terakhir ? `; penetapan terakhir ${formatPanjang(p.hafalan.terakhir)}` : '' }}.</p>
      <table v-if="p.sertifikat?.length" class="tabel padat" style="margin-top: 3pt"><colgroup><col style="width: 30%"><col style="width: 28%"><col style="width: 20%"><col style="width: 22%"></colgroup>
        <thead><tr><th>Sertifikat</th><th>Nomor</th><th>Tanggal</th><th>Keterangan</th></tr></thead>
        <tbody><tr v-for="c in p.sertifikat" :key="c.nomor"><td>{{ JENIS_SERTIFIKAT[c.jenis] || c.jenis }}</td><td>{{ c.nomor }}</td><td class="tengah">{{ formatPanjang(c.tanggal) }}</td>
          <td>{{ [c.jenjang_juz ? c.jenjang_juz + ' juz' : '', c.predikat].filter(Boolean).join(' · ') || '–' }}</td></tr></tbody>
      </table>

      <template v-if="p.prestasi?.length">
        <p class="sub-rapor">D. Prestasi</p>
        <table class="tabel padat"><colgroup><col style="width: 15%"><col style="width: 37%"><col style="width: 18%"><col style="width: 15%"><col style="width: 15%"></colgroup>
          <thead><tr><th>Tanggal</th><th>Kegiatan/lomba</th><th>Capaian</th><th>Bidang</th><th>Tingkat</th></tr></thead>
          <tbody><tr v-for="(x, i) in p.prestasi" :key="i"><td class="tengah">{{ formatPanjang(x.tanggal) }}</td><td>{{ x.kegiatan }}</td><td>{{ x.capaian }}</td>
            <td>{{ BIDANG_PRESTASI[x.bidang]?.n || x.bidang }}</td><td>{{ TINGKAT_PRESTASI[x.tingkat] || x.tingkat }}</td></tr></tbody>
        </table>
      </template>

      <p class="sub-rapor">{{ p.prestasi?.length ? 'E' : 'D' }}. Rencana Lanjut Studi</p>
      <table v-if="STUDI.length" class="identitas"><colgroup><col style="width: 30%"><col style="width: 3%"><col></colgroup><tbody>
        <tr v-for="[k, v] in STUDI" :key="k"><td>{{ k }}</td><td>:</td><td>{{ v }}</td></tr>
      </tbody></table>
      <p v-else style="font-size: 10pt">Belum diisi.</p>

      <template v-if="a.cita_cita || KONTAK.length">
        <p class="sub-rapor">{{ p.prestasi?.length ? 'F' : 'E' }}. Cita-cita dan Kontak</p>
        <table class="identitas"><colgroup><col style="width: 30%"><col style="width: 3%"><col></colgroup><tbody>
          <tr v-if="a.cita_cita"><td>Cita-cita</td><td>:</td><td>{{ a.cita_cita }}</td></tr>
          <tr v-for="[k, v] in KONTAK" :key="k"><td>{{ k }}</td><td>:</td><td>{{ v }}</td></tr>
        </tbody></table>
      </template>

      <template v-if="a.kesan_pesan">
        <p class="sub-rapor">Kesan dan Pesan</p>
        <div class="kotak">{{ a.kesan_pesan }}</div>
      </template>
      <TtdRapor v-if="ttd" :kiri="ttd.kiri" :kanan="ttd.kanan" />
    </div>
  </HalRapor>
</template>
<style>
.cv-alumni .cv-atas { display: flex; gap: 6mm; align-items: flex-start; margin-bottom: 2pt; }
.cv-alumni .cv-foto { width: 30mm; height: 40mm; flex-shrink: 0; border: .5pt solid #000; display: grid; place-items: center; text-align: center; font-size: 8.5pt; color: #555; overflow: hidden; }
.cv-alumni .cv-foto img { width: 100%; height: 100%; object-fit: cover; }
.cv-alumni .cv-nama { font-size: 15pt; font-weight: 700; line-height: 1.2; }
.cv-alumni .cv-motto { font-size: 10pt; font-style: italic; margin-top: 1pt; }
.cv-alumni .sub-rapor { margin-top: 7pt; }
.cv-alumni table.tabel td.tengah, .cv-alumni table.tabel th { text-align: center; }
</style>
