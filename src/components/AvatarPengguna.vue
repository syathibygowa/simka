<!-- SIMKA PRO | src/components/AvatarPengguna.vue | v1.1 | Fase 3 – Perbaikan P4 (kartu pegawai portrait) | 04/10/2026 -->
<script setup>
// Avatar akun: foto profil bila ada (sama dengan foto kartu pegawai), bila tidak inisial nama.
import { ref, watch } from 'vue'
import { useSesi } from '@/stores/sesi'
defineProps({ size: { type: Number, default: 40 } })
const sesi = useSesi(); const gagal = ref(false)
watch(() => sesi.fotoUrl, () => { gagal.value = false })
</script>
<template>
  <img v-if="sesi.fotoUrl && !gagal" :src="sesi.fotoUrl" alt="" class="shrink-0 rounded-full object-cover" :style="{ width: size + 'px', height: size + 'px' }" @error="gagal = true" />
  <span v-else class="avatar grid shrink-0 place-items-center rounded-full font-bold text-white" :style="{ width: size + 'px', height: size + 'px', fontSize: size * 0.38 + 'px' }" aria-hidden="true">
    {{ sesi.inisial }}
  </span>
</template>
<style scoped>.avatar { background: linear-gradient(135deg, #8E1C19, #C7332F); }</style>
