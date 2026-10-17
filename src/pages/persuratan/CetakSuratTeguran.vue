<!-- SIMKA PRO | src/pages/persuratan/CetakSuratTeguran.vue | v1.0 | 14.1.0: baca dan cetak surat teguran (pegawai penerima, pengusul, pimpinan) | 17/10/2026 -->
<script setup>
// Membuka surat keluar milik sebuah SP dalam pratinjau cetak F4 (kop, nomor, tanda tangan elektronik Direktur di kiri,
// kolom "Yang menerima" di kanan beserta waktu penerimaan elektronik). Hak baca diperiksa server (boleh_baca_surat_keluar).
import { ref, computed, watch } from 'vue'
import { usePersuratan } from '@/stores/persuratan'
import { useUI } from '@/stores/ui'
import { namaBerkas, periodeBulan } from '@/lib/namaBerkas'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import SuratResmi from '@/components/cetak/SuratResmi.vue'

const buka = defineModel({ type: Boolean, default: false })
const props = defineProps({ sp: { type: Object, default: null } }) // baris daftar_teguran / teguran_saya
const ps = usePersuratan(); const ui = useUI()
const s = ref(null)
watch(buka, async (b) => {
  if (!b) return
  s.value = null
  if (!props.sp?.letter_id) { ui.toast('Surat belum tersedia. Surat dibuat Tata Usaha setelah usulan diproses.', 'galat'); buka.value = false; return }
  try { await ps.muatKonteks(); s.value = await ps.rincianKeluar({ id: props.sp.letter_id }) } catch (e) { ui.toast(e.message, 'galat'); buka.value = false }
})
const beku = computed(() => s.value?.dokumen?.isi || null)
const surat = computed(() => {
  if (!s.value) return null
  const dasar = beku.value ? { ...beku.value } : { ...s.value }
  return { ...dasar, nomor: s.value.nomor || s.value.dokumen?.nomor || dasar.nomor, tanggal_hijriah: dasar.tanggal_hijriah || s.value.tanggal_hijriah, mode_ttd: s.value.mode_ttd }
})
const sah = computed(() => s.value?.dokumen?.status === 'sah')
</script>
<template>
  <DokumenCetak v-if="s && surat" :kop="surat.kop_kode || s.kop_kode" :judul="`${s.jenis_nama}${s.nomor ? ' ' + s.nomor : ''}`"
    :nama-berkas="namaBerkas(sp?.nama, s.jenis_nama, s.nomor || 'draf', periodeBulan(s.tanggal_surat))" v-model:pratinjau="buka" sembunyikan-judul tanpa-catatan>
    <SuratResmi :surat="surat" :lembaga="beku?.lembaga || ps.konteks || {}" :ttd="s.dokumen?.penanda || []" :kode="s.dokumen?.kode || ''"
      :status-dokumen="s.dokumen?.status || ''" :mode="sah ? 'final' : 'pratinjau'" :diterima="sp?.diterima_pada || ''" />
  </DokumenCetak>
</template>
