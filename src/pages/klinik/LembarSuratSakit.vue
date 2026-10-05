<!-- SIMKA PRO | src/pages/klinik/LembarSuratSakit.vue | v1.0 | Fase 6 – Tahap 3 Jurnal musyrif dan klinik lanjutan | 06/10/2026 -->
<script setup>
// Buat surat keterangan sakit: masa istirahat (bawaan hari ini), keperluan, dan pilihan mencantumkan diagnosis.
// Setelah dibuat, pratinjau cetak langsung terbuka.
import { ref, watch } from 'vue'
import { PhFileText, PhInfo } from '@phosphor-icons/vue'
import { useKlinik } from '@/stores/klinik'
import { useUI } from '@/stores/ui'
import { hariIniISO } from '@/lib/tanggal'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'

const buka = defineModel({ type: Boolean, default: false })
const props = defineProps({ kasus: { type: Object, default: null }, diagnosis: { type: String, default: '' } })
const emit = defineEmits(['dibuat'])
const kl = useKlinik(); const ui = useUI()
const isi = ref({}); const proses = ref(false)
watch(buka, (v) => { if (v) isi.value = { istirahat_mulai: hariIniISO(), istirahat_sampai: hariIniISO(), keperluan: '', cantumkan_diagnosis: false, diagnosis: props.diagnosis || '' } })
async function buat() {
  if (isi.value.istirahat_sampai < isi.value.istirahat_mulai) return ui.toast('Akhir masa istirahat sebelum awalnya.', 'galat')
  proses.value = true
  try { const s = await kl.buatSurat({ ...isi.value, case_id: props.kasus.id }); ui.toast(`Surat ${s.nomor} dibuat.`); buka.value = false; emit('dibuat', s) }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <LembarBawah v-model="buka" judul="Surat keterangan sakit">
    <div v-if="kasus" class="space-y-3 pb-2">
      <p class="rounded-xl bg-permukaan2 p-3 text-sm"><b>{{ kasus.nama }}</b><span class="block text-xs text-teks3">Keluhan: {{ kasus.keluhan }}</span></p>
      <div class="grid gap-3 sm:grid-cols-2"><InputTanggal v-model="isi.istirahat_mulai" label="Istirahat mulai" wajib /><InputTanggal v-model="isi.istirahat_sampai" label="Sampai" wajib /></div>
      <div><label class="label-isian" for="ss-kep">Keperluan</label><input id="ss-kep" v-model="isi.keperluan" class="isian" placeholder="Contoh: izin tidak mengikuti KBM dan ujian" /></div>
      <label class="flex min-h-[44px] items-center gap-3 text-sm"><input v-model="isi.cantumkan_diagnosis" type="checkbox" class="h-5 w-5 accent-[#B42A5E]" /> Cantumkan diagnosis di surat</label>
      <input v-if="isi.cantumkan_diagnosis" v-model="isi.diagnosis" class="isian" placeholder="Diagnosis" aria-label="Diagnosis" />
      <p class="flex items-start gap-2 text-xs text-teks3"><PhInfo :size="16" class="shrink-0" /> Nomor surat (SKS) dan kode validasi dibuat otomatis. Surat ditandatangani elektronik atas nama Anda.</p>
      <button class="tombol-utama w-full" :disabled="proses" @click="buat"><PhFileText :size="20" weight="duotone" /> Buat dan cetak surat</button>
    </div>
  </LembarBawah>
</template>
