<!-- SIMKA PRO | src/components/InputSandi.vue | v1.0 | Fase 1 – Akun dan hak akses | 03/10/2026 -->
<script setup>
import { ref, computed } from 'vue'
import { PhLockKey, PhEye, PhEyeSlash } from '@phosphor-icons/vue'
import { kekuatanSandi } from '@/lib/sandi'
const model = defineModel({ type: String, default: '' })
const props = defineProps({ label: String, id: String, kekuatan: Boolean, autocomplete: { type: String, default: 'new-password' } })
const lihat = ref(false)
const n = computed(() => kekuatanSandi(model.value))
const LABEL = ['Terlalu pendek', 'Lemah', 'Cukup', 'Kuat']
const WARNA = ['bg-garis', 'bg-[#C7332F]', 'bg-[#B27A00]', 'bg-[#1E7D4F]']
</script>
<template>
  <div>
    <label :for="id" class="label-isian">{{ label }}</label>
    <div class="relative">
      <PhLockKey :size="20" weight="duotone" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
      <input :id="id" v-model="model" :type="lihat ? 'text' : 'password'" class="isian pl-11 pr-12" :autocomplete="autocomplete" />
      <button type="button" class="tombol-ikon absolute right-0.5 top-1/2 -translate-y-1/2" @click="lihat = !lihat" :aria-label="lihat ? 'Sembunyikan kata sandi' : 'Tampilkan kata sandi'">
        <component :is="lihat ? PhEyeSlash : PhEye" :size="22" />
      </button>
    </div>
    <div v-if="kekuatan && model" class="mt-1.5 flex items-center gap-2">
      <div class="flex flex-1 gap-1"><span v-for="i in 3" :key="i" :class="['h-1.5 flex-1 rounded-full', i <= n ? WARNA[n] : 'bg-garis']" /></div>
      <span class="text-xs font-semibold text-teks3">{{ LABEL[n] }}</span>
    </div>
    <p v-if="kekuatan" class="mt-1 text-xs text-teks3">Minimal 8 karakter, memuat huruf dan angka.</p>
  </div>
</template>
