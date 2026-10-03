<!-- SIMKA PRO | src/pages/auth/GantiSandi.vue | v1.0 | Fase 1 – Akun dan hak akses | 03/10/2026 -->
<script setup>
// Ganti kata sandi: wajib saat masuk pertama dengan sandi sementara, atau atas kemauan sendiri dari Profil.
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAkun } from '@/stores/akun'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { periksaSandi } from '@/lib/sandi'
import TataLetakAuth from '@/components/TataLetakAuth.vue'
import InputSandi from '@/components/InputSandi.vue'
const akun = useAkun(); const sesi = useSesi(); const ui = useUI(); const router = useRouter()
const sandi = ref(''); const ulang = ref(''); const galat = ref(''); const proses = ref(false)
const wajib = sesi.wajibGantiSandi
async function kirim() {
  galat.value = periksaSandi(sandi.value, ulang.value); if (galat.value) return
  proses.value = true
  try {
    await akun.gantiSandi(sandi.value)
    sesi.wajibGantiSandi = false
    ui.toast('Kata sandi diperbarui.')
    router.replace('/')
  } catch (e) { galat.value = e.message } finally { proses.value = false }
}
</script>
<template>
  <TataLetakAuth judul="Ganti kata sandi" :keterangan="wajib ? 'Anda masuk dengan kata sandi sementara. Buat kata sandi baru sebelum melanjutkan.' : 'Buat kata sandi baru untuk akun Anda.'">
    <form class="space-y-4" @submit.prevent="kirim" novalidate>
      <InputSandi id="gs1" v-model="sandi" label="Kata sandi baru" kekuatan />
      <InputSandi id="gs2" v-model="ulang" label="Ulangi kata sandi baru" />
      <p v-if="galat" class="rounded-xl bg-[#C7332F]/10 px-3.5 py-2.5 text-sm font-semibold text-merah" role="alert">{{ galat }}</p>
      <button class="tombol-utama w-full" :disabled="proses">{{ proses ? 'Menyimpan…' : 'Simpan kata sandi baru' }}</button>
    </form>
    <template #bawah><router-link v-if="!wajib" to="/profil" class="font-semibold text-merah">Batal</router-link></template>
  </TataLetakAuth>
</template>
