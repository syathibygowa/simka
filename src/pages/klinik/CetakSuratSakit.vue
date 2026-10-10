<!-- SIMKA PRO | src/pages/klinik/CetakSuratSakit.vue | v1.1 | Fase 8 – Tahap 1 QR dan Cek Keabsahan | 10/10/2026 -->
<script setup>
// Surat Keterangan Sakit santri (F4, Kop Pondok). Nomor SKS otomatis; tanda tangan elektronik petugas klinik
// (kanan) dengan kode validasi; kolom "Mengetahui" Kepala Bidang Kesantrian (kiri). Diagnosis hanya tercantum
// bila petugas memilihnya saat membuat surat.
import { ref, computed, watch } from 'vue'
import { penandaKelompok } from '@/lib/santri'
import { formatPanjang, formatPendek, formatJam } from '@/lib/tanggal'
import { useSesi } from '@/stores/sesi'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import CatatanValidasi from '@/components/cetak/CatatanValidasi.vue'

const pratinjau = defineModel('pratinjau', { type: Boolean, default: false })
const props = defineProps({ surat: { type: Object, default: null } })
const sesi = useSesi(); const penanda = ref({ jabatan: 'Kepala Bidang Kesantrian', nama: '', niy: '' })
watch(pratinjau, async (v) => { if (v) penanda.value = await penandaKelompok({ jenis: 'kamar' }).catch(() => penanda.value) })
const lama = computed(() => props.surat ? Math.round((new Date(props.surat.istirahat_sampai) - new Date(props.surat.istirahat_mulai)) / 86400000) + 1 : 0)
const kelas = computed(() => (props.surat?.kelas ? `Kelas ${props.surat.kelas.replace(/^kelas\s*/i, '')}` : props.surat?.tingkat ? `Kelas ${props.surat.tingkat}` : '–'))
</script>
<template>
  <DokumenCetak v-if="surat" v-model:pratinjau="pratinjau" kop="pondok" judul="Surat Keterangan Sakit" :nomor="surat.nomor" :pencetak="sesi.pengguna?.nama_lengkap">
    <p>Yang bertanda tangan di bawah ini, petugas Klinik Pondok Pesantren, menerangkan bahwa santri:</p>
    <table class="data" style="margin: 6pt 0 8pt 12pt">
      <tbody>
        <tr><td style="width: 40mm">Nama</td><td style="width: 4mm">:</td><td>{{ surat.nama }}</td></tr>
        <tr><td>NIS</td><td>:</td><td>{{ surat.nis }}</td></tr>
        <tr><td>Tempat, tanggal lahir</td><td>:</td><td>{{ surat.tempat_lahir || '–' }}{{ surat.tanggal_lahir ? ', ' + formatPanjang(surat.tanggal_lahir) : '' }}</td></tr>
        <tr><td>Kelas / kamar</td><td>:</td><td>{{ kelas }} / {{ surat.kamar || '–' }}</td></tr>
        <tr><td>Diperiksa pada</td><td>:</td><td>{{ formatPanjang(surat.diperiksa_pada) }} pukul {{ formatJam(surat.diperiksa_pada) }} WITA</td></tr>
        <tr><td>Keluhan</td><td>:</td><td>{{ surat.keluhan }}</td></tr>
        <tr v-if="surat.diagnosis"><td>Diagnosis</td><td>:</td><td>{{ surat.diagnosis }}</td></tr>
      </tbody>
    </table>
    <p style="text-align: justify">berdasarkan hasil pemeriksaan, yang bersangkutan dalam keadaan sakit dan memerlukan istirahat selama
      {{ lama }} ({{ lama === 1 ? 'satu' : lama }}) hari, terhitung mulai tanggal {{ formatPanjang(surat.istirahat_mulai) }}{{ lama > 1 ? ' sampai dengan ' + formatPanjang(surat.istirahat_sampai) : '' }}.</p>
    <p v-if="surat.keperluan" style="margin-top: 6pt; text-align: justify">Surat keterangan ini dibuat untuk keperluan: {{ surat.keperluan }}.</p>
    <p style="margin-top: 6pt; text-align: justify">Demikian surat keterangan ini dibuat dengan sebenarnya untuk dipergunakan sebagaimana mestinya.</p>
    <template #ttd>
      <TandaTangan :tanggal="surat.tanggal"
        :kiri="{ pengantar: 'Mengetahui,', jabatan: penanda.jabatan || 'Kepala Bidang Kesantrian', nama: penanda.nama, niy: penanda.niy }"
        :kanan="{ jabatan: 'Petugas Klinik', nama: surat.petugas || '', niy: surat.petugas_niy,
                  kode: surat.kode_validasi, waktu: surat.created_at || surat.tanggal }" />
      <CatatanValidasi :kode="surat.kode_validasi" />
    </template>
  </DokumenCetak>
</template>
