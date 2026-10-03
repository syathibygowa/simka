<!-- SIMKA PRO | src/components/KartuDorong.vue | v1.0 | Fase 3 – Tahap 1 Pengumuman, audit log, notifikasi HP | 04/10/2026 -->
<script setup>
// Kartu pengaturan "Notifikasi di HP ini" (web push). Mode ringkas dipakai sebagai ajakan di halaman Notifikasi:
// hanya tampil bila belum aktif dan perangkat mendukung.
import { ref, computed, onMounted } from 'vue'
import { PhDeviceMobile, PhBellRinging, PhBellSlash, PhInfo } from '@phosphor-icons/vue'
import { dukungan, aktifDiSini, aktifkan, matikan, perangkatSaya } from '@/lib/dorong'
import { useUI } from '@/stores/ui'
import { formatPendek } from '@/lib/tanggal'

const props = defineProps({ ringkas: Boolean })
const ui = useUI()
const status = ref(dukungan()); const aktif = ref(false); const proses = ref(false); const perangkat = ref([])
onMounted(async () => { aktif.value = await aktifDiSini(); if (!props.ringkas) perangkat.value = await perangkatSaya() })

const PESAN = {
  demo: 'Mode demo: notifikasi HP dapat dicoba setelah aplikasi tersambung ke server.',
  tidak_didukung: 'Peramban ini belum mendukung notifikasi HP. Gunakan Chrome versi terbaru.',
  perlu_dipasang: 'Di iPhone/iPad, pasang SIMKA PRO ke Layar Utama lebih dulu (Bagikan → Tambahkan ke Layar Utama), lalu buka dari ikon itu.',
  ditolak: 'Izin notifikasi diblokir di peramban. Buka pengaturan situs, izinkan Notifikasi, lalu muat ulang.',
}
const tampil = computed(() => !props.ringkas || (status.value === 'siap' && !aktif.value))

async function ubah() {
  proses.value = true
  try {
    if (aktif.value) { await matikan(); aktif.value = false; ui.toast('Notifikasi HP dimatikan di perangkat ini.', 'info') }
    else { await aktifkan(); aktif.value = true; ui.toast('Notifikasi HP aktif. Pemberitahuan akan muncul walaupun aplikasi tertutup.', 'sukses') }
    perangkat.value = await perangkatSaya()
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false; status.value = dukungan() }
}
</script>
<template>
  <section v-if="tampil" :class="['kartu w-notifikasi', ringkas ? 'mb-4 flex items-center gap-3 p-4' : 'p-5']">
    <template v-if="ringkas">
      <span class="chip-ikon h-10 w-10 shrink-0"><PhBellRinging :size="22" weight="duotone" /></span>
      <p class="flex-1 text-sm text-teks2"><span class="block font-bold text-teks">Terima notifikasi di HP</span>Pemberitahuan tetap muncul walaupun aplikasi tertutup.</p>
      <button class="tombol-utama min-h-[40px] shrink-0 px-4 text-sm" :disabled="proses" @click="ubah">{{ proses ? 'Memproses…' : 'Aktifkan' }}</button>
    </template>
    <template v-else>
      <div class="flex items-center gap-3">
        <span class="chip-ikon h-10 w-10"><PhDeviceMobile :size="22" weight="duotone" /></span>
        <div class="flex-1"><h3 class="judul-bagian">Notifikasi di HP ini</h3>
          <p class="text-sm text-teks3">{{ aktif ? 'Aktif – pemberitahuan muncul walaupun aplikasi tertutup' : 'Belum aktif di perangkat ini' }}</p></div>
        <button v-if="status === 'siap'" :class="[aktif ? 'tombol-garis' : 'tombol-utama', 'min-h-[44px] shrink-0 px-4 text-sm']" :disabled="proses" @click="ubah">
          <component :is="aktif ? PhBellSlash : PhBellRinging" :size="18" weight="duotone" />{{ proses ? 'Memproses…' : aktif ? 'Matikan' : 'Aktifkan' }}</button>
      </div>
      <p v-if="PESAN[status]" class="mt-3 flex gap-2 rounded-xl bg-permukaan2 p-3 text-sm text-teks2"><PhInfo :size="18" class="mt-0.5 shrink-0" />{{ PESAN[status] }}</p>
      <div v-if="perangkat.length" class="mt-3">
        <p class="text-xs font-bold text-teks3">Perangkat terdaftar untuk akun ini</p>
        <ul class="mt-1 space-y-1 text-sm text-teks2">
          <li v-for="p in perangkat" :key="p.id">{{ p.perangkat || 'Perangkat' }} · didaftarkan {{ formatPendek(p.created_at) }}</li>
        </ul>
      </div>
    </template>
  </section>
</template>
