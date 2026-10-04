<!-- SIMKA PRO | src/pages/kartu/VerifikasiKartu.vue | v1.0 | Fase 3 – Tahap 4 Berkas Saya dan kartu pegawai | 04/10/2026 -->
<script setup>
// Halaman publik hasil pindai QR kartu pegawai: menampilkan keabsahan kartu dengan data minimal.
// Dapat dibuka tanpa masuk. Kartu dengan kode lama (diganti) atau pegawai nonaktif dinyatakan tidak berlaku.
import { ref, onMounted } from 'vue'
import { PhSealCheck, PhSealWarning, PhXCircle, PhMagnifyingGlass } from '@phosphor-icons/vue'
import { useKartu } from '@/stores/kartu'
import { kodeRapi } from '@/lib/kartu'
import { formatWaktu, sekarang } from '@/lib/tanggal'
import TataLetakAuth from '@/components/TataLetakAuth.vue'

const props = defineProps({ kode: String })
const kt = useKartu(); const hasil = ref(null); const memuat = ref(true); const kodeIsi = ref(props.kode || ''); const waktu = ref('')
async function periksa(k) {
  memuat.value = true
  try { hasil.value = await kt.cek(k); waktu.value = formatWaktu(sekarang()) } catch { hasil.value = { galat: true } } finally { memuat.value = false }
}
onMounted(() => (props.kode ? periksa(props.kode) : (memuat.value = false)))
</script>
<template>
  <TataLetakAuth judul="Verifikasi Kartu Pegawai" keterangan="Pemeriksaan keabsahan kartu pegawai SIMKA PRO.">
    <p v-if="memuat" class="py-6 text-center text-teks3">Memeriksa kartu…</p>
    <template v-else-if="hasil">
      <div v-if="hasil.ditemukan" :class="['rounded-2xl p-4', hasil.berlaku ? 'w-presensi' : 'w-beranda']" style="background: color-mix(in srgb, var(--c) 10%, rgb(var(--permukaan)))">
        <p class="flex items-center gap-2 text-lg font-extrabold" style="color: var(--c)">
          <component :is="hasil.berlaku ? PhSealCheck : PhSealWarning" :size="30" weight="duotone" />{{ hasil.berlaku ? 'Kartu sah dan berlaku' : 'Kartu tidak berlaku' }}</p>
        <dl class="mt-3 grid grid-cols-[6.5rem_1fr] gap-x-2 gap-y-1 text-sm">
          <dt class="text-teks3">Nama</dt><dd class="font-bold">{{ hasil.nama }}</dd>
          <dt class="text-teks3">NIY</dt><dd>{{ hasil.niy || '–' }}</dd>
          <dt class="text-teks3">Jabatan</dt><dd>{{ hasil.jabatan || '–' }}</dd>
          <dt class="text-teks3">Bidang/Unit</dt><dd>{{ hasil.unit || '–' }}</dd>
          <dt class="text-teks3">Lembaga</dt><dd>{{ hasil.lembaga }}</dd>
        </dl>
        <p v-if="!hasil.berlaku" class="mt-3 text-sm font-semibold text-teks">Pemegang kartu tidak lagi tercatat sebagai pegawai aktif.</p>
      </div>
      <div v-else class="w-beranda rounded-2xl p-4" style="background: color-mix(in srgb, var(--c) 10%, rgb(var(--permukaan)))">
        <p class="flex items-center gap-2 text-lg font-extrabold" style="color: var(--c)"><PhXCircle :size="30" weight="duotone" /> {{ hasil.galat ? 'Pemeriksaan gagal' : 'Kartu tidak dikenal' }}</p>
        <p class="mt-2 text-sm text-teks2">{{ hasil.galat ? 'Periksa koneksi internet lalu coba lagi.' : 'Kode tidak terdaftar atau kartu sudah diganti karena hilang. Kartu ini tidak sah.' }}</p>
      </div>
      <p class="mt-3 text-xs text-teks3">Kode {{ kodeRapi(kode) }} · diperiksa {{ waktu }} WITA</p>
    </template>
    <form class="mt-5 flex gap-2" @submit.prevent="periksa(kodeIsi)">
      <label class="sr-only" for="vk-kode">Kode kartu</label>
      <input id="vk-kode" v-model="kodeIsi" class="isian flex-1 uppercase" placeholder="Ketik kode kartu" autocomplete="off" />
      <button class="tombol-utama shrink-0"><PhMagnifyingGlass :size="20" weight="bold" /> Periksa</button>
    </form>
  </TataLetakAuth>
</template>
