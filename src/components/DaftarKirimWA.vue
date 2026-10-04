<!-- SIMKA PRO | src/components/DaftarKirimWA.vue | v1.0 | Fase 3 – Perbaikan P3 (berkas dan WA) | 04/10/2026 -->
<script setup>
// Daftar kirim WA berurutan untuk banyak penerima. Setiap ketukan membuka WhatsApp di HP pengirim dengan pesan
// yang sudah terisi (wa.me); pengirim menekan Kirim di WhatsApp lalu kembali ke sini. Penerima yang sudah dibuka
// ditandai (tersimpan selama sesi peramban). Tanpa layanan WA gateway, pesan tidak dapat terkirim otomatis.
import { ref, computed, watch } from 'vue'
import { PhWhatsappLogo, PhCheckCircle, PhArrowRight, PhWarningCircle } from '@phosphor-icons/vue'
import { tautanWA } from '@/lib/wa'

const props = defineProps({
  penerima: { type: Array, default: () => [] },        // [{ employee_id, nama, no_hp, unit, ... }]
  pesan: { type: Function, required: true },             // (p) => teks
  kunci: { type: String, default: 'umum' },              // pembeda penyimpanan tanda terkirim
  saringan: { type: Array, default: () => [] },          // [{ k, n, f: (p) => boolean }]
})
const muat = () => { try { return new Set(JSON.parse(sessionStorage.getItem('simka.wa.' + props.kunci) || '[]')) } catch { return new Set() } }
const terkirim = ref(muat()); const saring = ref(props.saringan[0]?.k || 'semua')
watch(() => props.kunci, () => { terkirim.value = muat() })
const simpan = () => { try { sessionStorage.setItem('simka.wa.' + props.kunci, JSON.stringify([...terkirim.value])) } catch { /* abaikan */ } }
const tampil = computed(() => { const s = props.saringan.find((x) => x.k === saring.value); return s ? props.penerima.filter(s.f) : props.penerima })
const berHP = computed(() => tampil.value.filter((p) => p.no_hp))
const sisa = computed(() => berHP.value.filter((p) => !terkirim.value.has(p.employee_id)))
function kirim(p) {
  window.open(tautanWA(p.no_hp, props.pesan(p)), '_blank', 'noopener')
  terkirim.value = new Set([...terkirim.value, p.employee_id]); simpan()
}
</script>
<template>
  <div class="w-presensi">
    <div v-if="saringan.length" class="mb-2 flex flex-wrap gap-1.5">
      <button v-for="s in saringan" :key="s.k" type="button" @click="saring = s.k"
        :class="['min-h-[36px] rounded-full border px-3 text-sm font-semibold', saring === s.k ? 'border-transparent bg-[#1E7D4F] text-white' : 'border-garis bg-permukaan text-teks2']">{{ s.n }} ({{ penerima.filter(s.f).length }})</button>
    </div>
    <div class="mb-2 flex flex-wrap items-center gap-2 rounded-xl p-3" style="background: color-mix(in srgb, var(--c) 10%, rgb(var(--permukaan)))">
      <p class="flex-1 text-sm"><span class="font-bold">{{ berHP.length - sisa.length }}/{{ berHP.length }}</span> sudah dibuka di WhatsApp<template v-if="tampil.length > berHP.length"> · {{ tampil.length - berHP.length }} tanpa nomor HP</template></p>
      <button v-if="sisa.length" type="button" class="tombol-utama min-h-[40px] px-4 text-sm" @click="kirim(sisa[0])"><PhArrowRight :size="18" weight="bold" /> Kirim berikutnya: {{ sisa[0].nama.split(' ').slice(0, 2).join(' ') }}</button>
    </div>
    <ul class="divide-y divide-garis">
      <li v-for="p in tampil" :key="p.employee_id" class="flex items-center gap-3 py-2.5">
        <div class="min-w-0 flex-1"><p class="font-semibold">{{ p.nama }}</p>
          <p class="text-xs text-teks3">{{ p.unit || '–' }}<template v-if="p.keterangan"> · {{ p.keterangan }}</template></p></div>
        <span v-if="!p.no_hp" class="flex items-center gap-1 text-xs text-teks3"><PhWarningCircle :size="14" /> Nomor HP kosong</span>
        <button v-else type="button" :class="['min-h-[40px] shrink-0 px-3 text-sm', terkirim.has(p.employee_id) ? 'tombol-garis' : 'tombol-utama']" @click="kirim(p)">
          <component :is="terkirim.has(p.employee_id) ? PhCheckCircle : PhWhatsappLogo" :size="18" weight="duotone" />{{ terkirim.has(p.employee_id) ? 'Terbuka' : 'WA' }}</button>
      </li>
      <li v-if="!tampil.length" class="py-3 text-sm text-teks3">Tidak ada penerima pada saringan ini.</li>
    </ul>
    <p class="mt-2 text-xs text-teks3">WhatsApp terbuka di HP Anda dengan pesan terisi; tekan Kirim di WhatsApp lalu kembali ke sini untuk penerima berikutnya. Isi pesan mengikuti Template WA di Pengaturan.</p>
  </div>
</template>
