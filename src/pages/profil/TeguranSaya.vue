<!-- SIMKA PRO | src/pages/profil/TeguranSaya.vue | v1.0 | 14.1.0: surat teguran milik pegawai (baca, cetak, tanda terima) | 17/10/2026 -->
<script setup>
// Profil → Surat Teguran: surat teguran yang sudah terbit untuk akun ini (usulan yang belum terbit tidak tampil).
// Pegawai membaca dan mencetak suratnya, lalu menyatakan "Saya telah menerima" (waktu tercatat dan tampil di surat).
import { ref, computed, onMounted } from 'vue'
import { PhPrinter, PhCheckCircle, PhInfo, PhSealCheck } from '@phosphor-icons/vue'
import { useTeguran } from '@/stores/teguran'
import { useUI } from '@/stores/ui'
import { TINGKAT_SP, KEADAAN_SP, sisaHari } from '@/lib/teguran'
import { formatPanjang, formatWaktu, hariIniISO } from '@/lib/tanggal'
import CetakSuratTeguran from '@/pages/persuratan/CetakSuratTeguran.vue'

const tg = useTeguran(); const ui = useUI()
const daftar = ref([]); const memuat = ref(true); const proses = ref('')
async function muat() { try { daftar.value = await tg.saya() } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false } }
onMounted(muat)
const hi = hariIniISO()
const pilihan = ref(null); const cetak = ref(false)
function baca(x) { pilihan.value = x; cetak.value = true }
async function terima(x) {
  if (!(await ui.konfirmasi({ judul: 'Nyatakan telah menerima?', pesan: `Anda menyatakan telah menerima dan membaca ${TINGKAT_SP[x.tingkat].nama} Nomor ${x.nomor}. Pernyataan ini tercatat beserta waktunya dan diketahui pengusul.`, ya: 'Ya, saya telah menerima' }))) return
  proses.value = x.id
  try { await tg.terima(x.id); ui.toast('Tanda terima tercatat. Semoga Allah memudahkan perbaikannya.'); await muat() } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = '' }
}
const aktif = computed(() => daftar.value.filter((x) => x.keadaan === 'aktif'))
</script>
<template>
  <div class="mx-auto max-w-3xl space-y-4">
    <p class="flex gap-2 text-sm text-teks3"><PhInfo :size="18" class="mt-0.5 shrink-0" />Surat teguran adalah bentuk pembinaan. Bacalah dengan saksama, lalu ketuk
      "Saya telah menerima". Surat ini hanya dapat dilihat oleh Anda, pimpinan Anda, Tata Usaha, dan pengelola yang berwenang.</p>
    <p v-if="memuat" class="py-10 text-center text-teks3">Memuat…</p>
    <div v-else-if="!daftar.length" class="kartu flex flex-col items-center p-10 text-center">
      <span class="chip-ikon w-presensi h-14 w-14 rounded-2xl"><PhSealCheck :size="30" weight="duotone" /></span>
      <p class="mt-3 font-semibold">Anda tidak memiliki surat teguran.</p>
    </div>
    <ul v-else class="space-y-3">
      <li v-for="x in daftar" :key="x.id" :class="['kartu sp p-4 sm:p-5', 'w-' + TINGKAT_SP[x.tingkat].w, x.keadaan !== 'aktif' && 'redup']">
        <div class="flex items-start gap-3">
          <span class="chip-ikon h-12 w-12 text-sm font-extrabold">{{ TINGKAT_SP[x.tingkat].singkat }}</span>
          <div class="min-w-0 flex-1">
            <p class="font-bold">{{ TINGKAT_SP[x.tingkat].nama }}</p>
            <p class="text-sm tabular-nums text-teks2">{{ x.nomor }} · {{ formatPanjang(x.tanggal_surat) }}</p>
            <p class="mt-1 flex flex-wrap gap-1"><span :class="['lencana', 'w-' + KEADAAN_SP[x.keadaan].w]">{{ KEADAAN_SP[x.keadaan].n }}</span>
              <span v-if="x.keadaan === 'aktif'" class="lencana w-shift">Berlaku sampai {{ formatPanjang(x.berlaku_sampai) }} ({{ sisaHari(x.berlaku_sampai, hi) }} hari lagi)</span></p>
          </div>
        </div>
        <ol class="ml-5 mt-3 list-decimal space-y-0.5 text-sm"><li v-for="k in x.kategori" :key="k">{{ k }}</li></ol>
        <p class="mt-2 whitespace-pre-line text-sm text-teks2">{{ x.uraian }}</p>
        <p v-if="x.keadaan === 'dicabut'" class="mt-2 text-sm text-teks2">Dicabut {{ formatWaktu(x.dicabut_pada) }}: {{ x.alasan }}</p>
        <div class="mt-3 flex flex-wrap items-center gap-2">
          <button class="tombol-garis" @click="baca(x)"><PhPrinter :size="20" weight="duotone" /> Baca dan cetak surat</button>
          <button v-if="!x.diterima_pada && x.status === 'terbit'" class="tombol-utama" :disabled="proses === x.id" @click="terima(x)"><PhCheckCircle :size="20" weight="duotone" /> Saya telah menerima</button>
          <span v-else-if="x.diterima_pada" class="w-presensi inline-flex items-center gap-1 text-sm font-semibold" style="color: var(--c)"><PhCheckCircle :size="18" weight="fill" /> Diterima {{ formatWaktu(x.diterima_pada) }}</span>
        </div>
      </li>
    </ul>
    <p v-if="aktif.length" class="text-xs text-teks3">Surat teguran berakhir otomatis setelah masa berlakunya lewat dan tetap tercatat di riwayat kepegawaian.</p>
    <CetakSuratTeguran v-model="cetak" :sp="pilihan" />
  </div>
</template>
<style scoped>
.kartu.sp { border-left: 4px solid var(--c); }
.redup { opacity: .78; }
</style>
