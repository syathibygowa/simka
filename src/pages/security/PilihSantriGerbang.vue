<!-- SIMKA PRO | src/pages/security/PilihSantriGerbang.vue | v1.0 | Fase 7 – Tahap 2 Titipan, buku tamu, kunjungan | 06/10/2026 -->
<script setup>
// Pilih santri untuk titipan dan kunjungan: ketik nama (boleh ditambah kelas/kamar), daftar tampil "Nama – Kelas" dan kamar.
import { ref, watch } from 'vue'
import { PhMagnifyingGlass, PhX, PhUser } from '@phosphor-icons/vue'
import { useSecurity } from '@/stores/security'
import { useUI } from '@/stores/ui'
const model = defineModel({ type: Object, default: null })
defineProps({ label: { type: String, default: 'Santri' } })
const sc = useSecurity(); const ui = useUI()
const cari = ref(''); const hasil = ref([]); let tunda
watch(cari, () => { clearTimeout(tunda); tunda = setTimeout(async () => {
  const q = cari.value.trim(); if (q.length < 2) { hasil.value = []; return }
  try { hasil.value = await sc.cari(q) } catch (e) { ui.toast(e.message, 'galat') }
}, 300) })
function pilih(s) { model.value = s; cari.value = ''; hasil.value = [] }
</script>
<template>
  <div>
    <p class="label-isian">{{ label }}<span class="text-merah"> *</span></p>
    <div v-if="model" class="flex items-center gap-3 rounded-xl border border-garis p-2.5">
      <span class="chip-ikon w-santri h-10 w-10 shrink-0"><PhUser :size="22" weight="duotone" /></span>
      <div class="min-w-0 flex-1"><p class="font-bold leading-snug">{{ model.nama }}{{ model.kelas ? ' – ' + model.kelas : '' }}</p><p class="text-xs text-teks3">{{ model.nis }} · {{ model.kamar || 'Kamar –' }}</p></div>
      <button type="button" class="tombol-teks min-h-[36px] px-2" aria-label="Ganti santri" @click="model = null"><PhX :size="18" /></button>
    </div>
    <template v-else>
      <div class="relative"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
        <input v-model="cari" type="search" class="isian pl-11" placeholder="Ketik nama santri, boleh ditambah kelas/kamar" aria-label="Cari santri" autocomplete="off" /></div>
      <ul v-if="hasil.length" class="mt-2 max-h-60 divide-y divide-garis overflow-y-auto rounded-xl border border-garis">
        <li v-for="s in hasil" :key="s.student_id"><button type="button" class="w-full px-3 py-2 text-left hover:bg-permukaan2" @click="pilih(s)">
          <span class="block font-semibold leading-snug">{{ s.nama }}{{ s.kelas ? ' – ' + s.kelas : '' }}</span><span class="block text-xs text-teks3">{{ s.nis }} · {{ s.kamar || 'Kamar –' }}</span></button></li>
      </ul>
    </template>
  </div>
</template>
