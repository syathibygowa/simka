<!-- SIMKA PRO | src/components/AksiWajib.vue | v1.0 | Perbaikan: tombol cepat wajib Laporan, Perizinan, Rujuk (isian muncul langsung) | 14/10/2026 -->
<script setup>
// Tiga tombol cepat yang selalu ada di beranda pegawai fungsional; isiannya muncul sebagai lembar (pop-up), tanpa
// berpindah halaman:
//   Laporan    → laporan kejadian ke bidang terkait (menu Lapor)
//   Perizinan  → pengajuan izin, sakit, dinas luar, atau cuti pegawai (menu Pengajuan)
//   Rujuk      → rujukan santri sakit/perlu pertolongan ke klinik (menu Klinik)
import { ref } from 'vue'
import { PhMegaphone, PhFileText, PhFirstAidKit } from '@phosphor-icons/vue'
import { useLapor } from '@/stores/lapor'
import { usePengajuan } from '@/stores/pengajuan'
import { useLembaga } from '@/stores/lembaga'
import { useKlinik } from '@/stores/klinik'
import { useUI } from '@/stores/ui'
import LembarBawah from '@/components/LembarBawah.vue'
import LembarLapor from '@/pages/lapor/LembarLapor.vue'
import LembarRujuk from '@/pages/klinik/LembarRujuk.vue'
import FormPengajuan from '@/pages/pengajuan/FormPengajuan.vue'

const lp = useLapor(); const pg = usePengajuan(); const lembaga = useLembaga(); const kl = useKlinik(); const ui = useUI()
const lapor = ref(false); const izin = ref(false); const rujuk = ref(false); const memuat = ref('')
async function buka(k) {
  memuat.value = k
  try {
    if (k === 'lapor') { if (!lp.hakDimuat) await lp.muatHak(); lapor.value = true }
    if (k === 'izin') { await Promise.all([pg.muatKetentuan(), lembaga.muat()]); izin.value = true }
    if (k === 'rujuk') { await kl.muatHak().catch(() => {}); rujuk.value = true }
  } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = '' }
}
const AKSI = [
  { k: 'lapor', n: 'Laporan', ket: 'Laporkan kejadian', ikon: PhMegaphone, w: 'laporan' },
  { k: 'izin', n: 'Perizinan', ket: 'Ajukan izin/cuti', ikon: PhFileText, w: 'pengajuan' },
  { k: 'rujuk', n: 'Rujuk', ket: 'Santri sakit', ikon: PhFirstAidKit, w: 'klinik' },
]
</script>
<template>
  <section class="grid grid-cols-3 gap-2 sm:gap-3" aria-label="Tombol cepat">
    <button v-for="a in AKSI" :key="a.k" type="button" :class="['kartu flex flex-col items-center gap-1.5 p-3 text-center transition active:scale-95 sm:flex-row sm:text-left', 'w-' + a.w]"
      :disabled="memuat === a.k" @click="buka(a.k)">
      <span class="chip-ikon h-11 w-11 shrink-0 rounded-2xl"><component :is="a.ikon" :size="24" weight="duotone" /></span>
      <span class="min-w-0"><b class="block text-sm">{{ memuat === a.k ? 'Membuka…' : a.n }}</b><span class="hidden text-xs text-teks3 sm:block">{{ a.ket }}</span></span>
    </button>
  </section>
  <LembarLapor v-model="lapor" @selesai="lapor = false" />
  <LembarBawah v-model="izin" judul="Ajukan izin, sakit, atau cuti"><FormPengajuan v-if="izin" @selesai="izin = false; ui.toast('Pengajuan terkirim. Pantau statusnya di menu Pengajuan.')" /></LembarBawah>
  <LembarRujuk v-model="rujuk" @selesai="rujuk = false" />
</template>
