<!-- SIMKA PRO | src/pages/auth/LupaSandi.vue | v1.0 | Fase 1 – Akun dan hak akses | 03/10/2026 -->
<script setup>
import { ref } from 'vue'
import { PhUser, PhEnvelopeSimple } from '@phosphor-icons/vue'
import { useAkun } from '@/stores/akun'
import TataLetakAuth from '@/components/TataLetakAuth.vue'
const akun = useAkun()
const username = ref(''); const proses = ref(false); const galat = ref(''); const terkirim = ref('')
async function kirim() {
  galat.value = ''
  if (!username.value.trim()) { galat.value = 'Isi username Anda.'; return }
  proses.value = true
  try { terkirim.value = (await akun.mintaReset(username.value.trim())).pesan } catch (e) { galat.value = e.message } finally { proses.value = false }
}
</script>
<template>
  <TataLetakAuth judul="Lupa kata sandi" keterangan="Masukkan username Anda. Tautan untuk membuat kata sandi baru dikirim ke email yang terdaftar dan berlaku 30 menit.">
    <div v-if="terkirim" class="w-presensi flex flex-col items-center py-4 text-center">
      <span class="chip-ikon h-16 w-16 rounded-2xl"><PhEnvelopeSimple :size="34" weight="duotone" /></span>
      <p class="mt-3 font-semibold">{{ terkirim }}</p>
      <p class="mt-1 text-sm text-teks3">Bila email tidak datang dalam beberapa menit, periksa folder Spam atau hubungi admin pondok.</p>
    </div>
    <form v-else class="space-y-4" @submit.prevent="kirim" novalidate>
      <div>
        <label for="lu" class="label-isian">Username</label>
        <div class="relative"><PhUser :size="20" weight="duotone" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
          <input id="lu" v-model="username" class="isian pl-11" autocomplete="username" autocapitalize="none" /></div>
      </div>
      <p v-if="galat" class="rounded-xl bg-[#C7332F]/10 px-3.5 py-2.5 text-sm font-semibold text-merah" role="alert">{{ galat }}</p>
      <button class="tombol-utama w-full" :disabled="proses">{{ proses ? 'Mengirim…' : 'Kirim tautan ke email' }}</button>
    </form>
    <template #bawah><router-link to="/masuk" class="font-semibold text-merah">Kembali ke halaman masuk</router-link></template>
  </TataLetakAuth>
</template>
