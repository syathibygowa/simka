<!-- SIMKA PRO | src/pages/auth/AturSandi.vue | v1.0 | Fase 1 – Akun dan hak akses | 03/10/2026 -->
<script setup>
// Dibuka dari tautan email: #/atur-sandi?token=...
import { ref } from 'vue'
import { useRoute } from 'vue-router'
import { PhCheckCircle } from '@phosphor-icons/vue'
import { useAkun } from '@/stores/akun'
import { periksaSandi } from '@/lib/sandi'
import TataLetakAuth from '@/components/TataLetakAuth.vue'
import InputSandi from '@/components/InputSandi.vue'
const route = useRoute(); const akun = useAkun()
const sandi = ref(''); const ulang = ref(''); const galat = ref(''); const proses = ref(false); const selesai = ref('')
const token = String(route.query.token || '')
async function kirim() {
  galat.value = periksaSandi(sandi.value, ulang.value); if (galat.value) return
  proses.value = true
  try { selesai.value = (await akun.aturSandi(token, sandi.value)).pesan } catch (e) { galat.value = e.message } finally { proses.value = false }
}
</script>
<template>
  <TataLetakAuth judul="Buat kata sandi baru">
    <div v-if="!token" class="text-teks2">Tautan tidak lengkap. Buka kembali tautan dari email, atau <router-link to="/lupa-sandi" class="font-semibold text-merah">minta tautan baru</router-link>.</div>
    <div v-else-if="selesai" class="w-presensi flex flex-col items-center py-4 text-center">
      <span class="chip-ikon h-16 w-16 rounded-2xl"><PhCheckCircle :size="34" weight="duotone" /></span>
      <p class="mt-3 font-semibold">{{ selesai }}</p>
      <router-link to="/masuk" class="tombol-utama mt-5">Masuk sekarang</router-link>
    </div>
    <form v-else class="space-y-4" @submit.prevent="kirim" novalidate>
      <InputSandi id="as1" v-model="sandi" label="Kata sandi baru" kekuatan />
      <InputSandi id="as2" v-model="ulang" label="Ulangi kata sandi baru" />
      <p v-if="galat" class="rounded-xl bg-[#C7332F]/10 px-3.5 py-2.5 text-sm font-semibold text-merah" role="alert">{{ galat }}</p>
      <button class="tombol-utama w-full" :disabled="proses">{{ proses ? 'Menyimpan…' : 'Simpan kata sandi baru' }}</button>
    </form>
  </TataLetakAuth>
</template>
