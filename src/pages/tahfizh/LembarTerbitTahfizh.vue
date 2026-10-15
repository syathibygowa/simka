<!-- SIMKA PRO | src/pages/tahfizh/LembarTerbitTahfizh.vue | v1.0 | Tahap D: terbitkan dokumen tahfizh | 16/10/2026 -->
<script setup>
// Lembar penerbitan dokumen tahfizh bernomor:
//   ujian kenaikan juz Tuntas  → Surat Keterangan Ujian Kenaikan Juz (penguji langsung menerbitkan)
//   ujian sertifikasi Tuntas   → Sertifikat Hafalan
//   santri kelas 9/12          → Sertifikat Tahfizhul Quran (pimpinan tahfizh, Tata Usaha, superadmin)
// Pilihan tanda tangan: elektronik (QR; penanda tangan lain menerima permintaan di kotak Tanda tangan) atau basah.
// Setelah terbit, Kepala Bidang Tahfizh, Tata Usaha, dan admin/superadmin menerima notifikasi untuk dicetak.
import { ref, computed, watch } from 'vue'
import { PhCertificate, PhSignature, PhPenNib } from '@phosphor-icons/vue'
import { useTahfizh } from '@/stores/tahfizh'
import { useUI } from '@/stores/ui'
import { ringkasJuz } from '@/lib/tahfizh'
import { hariIniISO, formatPanjang } from '@/lib/tanggal'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'

const buka = defineModel({ type: Boolean, default: false })
const props = defineProps({ ujian: { type: Object, default: null }, calon: { type: Object, default: null } })
const emit = defineEmits(['terbit'])
const tz = useTahfizh(); const ui = useUI()
const jenis = computed(() => (props.calon ? 'sertifikat_tahfizh' : props.ujian?.jenis === 'sertifikasi' ? 'sertifikat_hafalan' : 'suket_juz'))
const JUDUL = { suket_juz: 'Surat Keterangan Ujian Kenaikan Juz', sertifikat_hafalan: 'Sertifikat Hafalan', sertifikat_tahfizh: 'Sertifikat Tahfizhul Quran' }
const f = ref({}); const proses = ref(false)
const indo = (t) => String(t || '').replace(/^(.+?)\s*\((.+)\)$/, '$2 ($1)')
const saranPredikat = computed(() => [...new Set((tz.predikat || []).map((p) => indo(p.deskripsi_rapor)).filter(Boolean))])
watch(buka, async (v) => {
  if (!v) return
  if (props.calon && !tz.predikat.length) await tz.muatPengaturan().catch(() => {})
  f.value = { tanggal: hariIniISO(), mode: 'elektronik', tanggal_hafal: props.calon?.tanggal_hafal || hariIniISO(), predikat: props.calon?.predikat ? indo(props.calon.predikat) : '' }
})
async function terbitkan() {
  if (jenis.value === 'sertifikat_tahfizh' && !f.value.predikat.trim()) return ui.toast('Isi predikat sertifikat, misalnya Istimewa (Mumtaz).', 'galat')
  const nama = props.calon?.nama || props.ujian?.nama
  if (!(await ui.konfirmasi({ judul: `Terbitkan ${JUDUL[jenis.value]}?`, pesan: `${nama} akan mendapat nomor dokumen baru. Nomor tidak dapat diubah; bila salah, dokumen dicabut lalu diterbitkan ulang.`, ya: 'Terbitkan' }))) return
  proses.value = true
  try {
    const h = await tz.terbitkanDokumen({ jenis: jenis.value, exam_id: props.ujian?.id || null, student_id: props.calon?.student_id || null, tanggal: f.value.tanggal, mode: f.value.mode,
      predikat: jenis.value === 'sertifikat_tahfizh' ? f.value.predikat.trim() : null, tanggal_hafal: jenis.value === 'sertifikat_tahfizh' ? f.value.tanggal_hafal : null })
    ui.toast(`${JUDUL[jenis.value]} terbit: ${h.nomor}.${h.status === 'draf' ? ' Menunggu tanda tangan elektronik penanda tangan lain.' : ''}`)
    buka.value = false; emit('terbit', h)
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <LembarBawah v-model="buka" :judul="'Terbitkan ' + JUDUL[jenis]">
    <div class="space-y-4 pb-2">
      <div class="w-tahfizh flex items-start gap-3 rounded-2xl border border-garis p-3">
        <span class="chip-ikon h-11 w-11 shrink-0"><PhCertificate :size="24" weight="duotone" /></span>
        <div class="min-w-0 text-sm">
          <p class="font-bold">{{ calon?.nama || ujian?.nama }}</p>
          <p v-if="ujian" class="text-teks2">{{ ujian.jenis === 'kenaikan' ? `Kenaikan juz ${ringkasJuz(ujian.juz)}` : `Sertifikasi ${ujian.jenjang} juz` }} · nilai {{ ujian.nilai_akhir }} ({{ ujian.huruf }}, {{ ujian.predikat }}) · Tuntas</p>
          <p v-if="ujian" class="text-xs text-teks3">Penguji {{ ujian.penguji || '–' }} · {{ ujian.diuji_pada ? formatPanjang(ujian.diuji_pada.slice(0, 10)) : '' }}</p>
          <p v-if="calon" class="text-teks2">NIS {{ calon.nis }} · {{ calon.kelas || 'Kelas ' + calon.tingkat }} · hafalan resmi <b>{{ calon.total_juz }} juz</b></p>
        </div>
      </div>
      <InputTanggal v-model="f.tanggal" :label="jenis === 'sertifikat_tahfizh' ? 'Tanggal sertifikat' : 'Tanggal dokumen'" wajib />
      <template v-if="jenis === 'sertifikat_tahfizh'">
        <InputTanggal v-model="f.tanggal_hafal" label="Dihafalkan hingga tanggal" wajib />
        <div><label class="label-isian" for="tt-pred">Predikat <span class="text-merah">*</span></label>
          <input id="tt-pred" v-model="f.predikat" class="isian" list="tt-pred-saran" placeholder="Contoh: Istimewa (Mumtaz)" />
          <datalist id="tt-pred-saran"><option v-for="p in saranPredikat" :key="p" :value="p" /></datalist>
          <p class="mt-1 text-xs text-teks3">Dicetak dengan huruf kapital, misalnya ISTIMEWA (MUMTAZ).</p></div>
      </template>
      <fieldset><legend class="label-isian">Tanda tangan</legend>
        <div class="grid gap-2 sm:grid-cols-2">
          <label v-for="m in [{ k: 'elektronik', n: 'Elektronik (QR)', ket: 'Penanda tangan lain menyetujui di kotak Tanda tangan', i: PhSignature }, { k: 'basah', n: 'Basah', ket: 'Ditandatangani di kertas setelah dicetak', i: PhPenNib }]" :key="m.k"
            :class="['flex min-h-[64px] cursor-pointer items-start gap-3 rounded-2xl border-2 p-3', f.mode === m.k ? 'w-tahfizh' : 'border-garis']" :style="f.mode === m.k ? 'border-color: var(--c)' : ''">
            <input v-model="f.mode" type="radio" :value="m.k" class="mt-1 h-5 w-5 accent-[#0B6B57]" />
            <span><b class="flex items-center gap-1.5 text-sm"><component :is="m.i" :size="18" weight="duotone" />{{ m.n }}</b><span class="text-xs text-teks3">{{ m.ket }}</span></span>
          </label>
        </div></fieldset>
      <p class="rounded-xl bg-permukaan2 p-3 text-xs text-teks2">Penanda tangan: {{ jenis === 'sertifikat_tahfizh' ? 'Direktur' : 'Kepala Bidang Tahfizh (mengetahui) dan Penguji' }}.
        Kepala Bidang Tahfizh, Tata Usaha, dan admin menerima notifikasi untuk mencetak.</p>
      <button class="tombol-utama w-full" :disabled="proses" @click="terbitkan"><PhCertificate :size="20" weight="duotone" /> {{ proses ? 'Menerbitkan…' : 'Terbitkan dan beri nomor' }}</button>
    </div>
  </LembarBawah>
</template>
