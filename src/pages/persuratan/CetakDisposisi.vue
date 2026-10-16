<!-- SIMKA PRO | src/pages/persuratan/CetakDisposisi.vue | v1.1 | Perbaikan 13.8.0: ringkasan dan catatan disposisi tercetak dengan gaya teks | 16/10/2026 -->
<script setup>
// Lembar Disposisi F4: data surat, daftar pilihan instruksi (dicentang sesuai disposisi pimpinan), alur disposisi berjenjang
// beserta tindak lanjutnya. Bila belum ada disposisi, tersedia baris kosong untuk ditulis tangan.
// Tanda tangan: kiri pimpinan penerima surat, kanan petugas Tata Usaha pencatat.
import { computed } from 'vue'
import { usePersuratan } from '@/stores/persuratan'
import { teksKaya } from '@/lib/teksKaya'
import { useSesi } from '@/stores/sesi'
import { SIFAT_SURAT, namaCara, pohonDisposisi } from '@/lib/persuratan'
import { formatPanjang, formatPendek } from '@/lib/tanggal'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const pratinjau = defineModel('pratinjau', { type: Boolean, default: false })
const props = defineProps({ surat: { type: Object, required: true } })
const ps = usePersuratan(); const sesi = useSesi()
const alur = computed(() => pohonDisposisi(props.surat.disposisi || []))
const dicentang = computed(() => new Set((props.surat.disposisi || []).filter((d) => !d.induk_id).flatMap((d) => d.instruksi || [])))
const pilihan = computed(() => { const p = [...(ps.pengaturan.instruksi || [])]; for (const t of dicentang.value) if (!p.includes(t)) p.push(t); return p })
const kosong = computed(() => Math.max(0, 4 - alur.value.length))
</script>
<template>
  <DokumenCetak kop="pondok" judul="Lembar Disposisi" :subjudul="`Nomor agenda ${surat.nomor_agenda}`" v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap">
    <table class="tabel" style="margin-bottom: 8pt">
      <colgroup><col style="width: 19%" /><col style="width: 35%" /><col style="width: 17%" /><col style="width: 29%" /></colgroup>
      <tbody>
        <tr><td>Asal surat</td><td colspan="3">{{ surat.pengirim }}{{ surat.alamat_pengirim ? ', ' + surat.alamat_pengirim : '' }}</td></tr>
        <tr><td>Nomor surat</td><td>{{ surat.nomor_surat || '–' }}</td><td>Tanggal surat</td><td>{{ surat.tanggal_surat ? formatPanjang(surat.tanggal_surat) : '–' }}</td></tr>
        <tr><td>Tanggal diterima</td><td>{{ formatPanjang(surat.tanggal_terima) }}</td><td>Cara diterima</td><td>{{ namaCara(surat.cara) }}</td></tr>
        <tr><td>Sifat</td><td>{{ SIFAT_SURAT[surat.sifat].n }}</td><td>Lampiran</td><td>{{ surat.lampiran || '–' }}</td></tr>
        <tr><td>Perihal</td><td colspan="3">{{ surat.perihal }}</td></tr>
        <tr v-if="surat.ringkasan"><td>Ringkasan</td><td colspan="3" style="white-space: pre-line" v-html="teksKaya(surat.ringkasan)" /></tr>
        <tr><td>Diteruskan kepada</td><td colspan="3">{{ surat.tujuan ? `${surat.tujuan} (${surat.tujuan_jabatan})` : 'Diarsipkan tanpa disposisi' }}</td></tr>
      </tbody>
    </table>

    <table class="tabel" style="margin-bottom: 8pt">
      <thead><tr><th>Instruksi pimpinan</th></tr></thead>
      <tbody><tr><td>
        <span v-for="t in pilihan" :key="t" style="display: inline-block; min-width: 31%; padding: 1pt 4pt 1pt 0">{{ dicentang.has(t) ? '☑' : '☐' }} {{ t }}</span>
      </td></tr></tbody>
    </table>

    <table class="tabel">
      <colgroup><col style="width: 6%" /><col style="width: 16%" /><col style="width: 16%" /><col style="width: 24%" /><col style="width: 13%" /><col style="width: 25%" /></colgroup>
      <thead><tr><th>No.</th><th>Dari</th><th>Kepada</th><th>Instruksi dan catatan</th><th>Batas waktu</th><th>Tindak lanjut</th></tr></thead>
      <tbody>
        <tr v-for="(d, i) in alur" :key="d.id">
          <td class="tengah">{{ i + 1 }}</td>
          <td :style="{ paddingLeft: 3 + d.tingkat * 8 + 'pt' }">{{ d.dari }}<br><span style="font-size: 9pt">{{ d.dari_jabatan }}</span></td>
          <td>{{ d.kepada }}<br><span style="font-size: 9pt">{{ d.kepada_jabatan }}</span></td>
          <td><span style="white-space: pre-line" v-html="teksKaya([(d.instruksi || []).join(', '), d.catatan].filter(Boolean).join('. '))" /><br><span style="font-size: 9pt">{{ formatPendek(d.created_at) }}</span></td>
          <td class="tengah">{{ d.batas ? formatPendek(d.batas) : '–' }}</td>
          <td>{{ d.status === 'selesai' ? `Selesai ${formatPendek(d.selesai_pada)}: ${d.laporan}` : d.status === 'dibaca' ? 'Dibaca, belum selesai' : 'Belum dibaca' }}</td>
        </tr>
        <tr v-for="i in kosong" :key="'k' + i" style="height: 16mm"><td class="tengah">{{ alur.length + i }}</td><td></td><td></td><td></td><td></td><td></td></tr>
      </tbody>
    </table>
    <template #ttd>
      <TandaTangan :kiri="{ pengantar: 'Pimpinan penerima,', jabatan: surat.tujuan_jabatan || 'Direktur', nama: surat.tujuan || '', niy: '' }"
        :kanan="{ jabatan: 'Petugas Tata Usaha', nama: surat.dicatat_oleh || '', niy: '' }" :tanggal="surat.tanggal_terima" />
    </template>
  </DokumenCetak>
</template>
