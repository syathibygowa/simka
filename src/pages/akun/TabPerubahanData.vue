<!-- SIMKA PRO | src/pages/akun/TabPerubahanData.vue | v1.0 | Fase 5 – Perbaikan: pegawai memperbarui data kepegawaiannya | 05/10/2026 -->
<script setup>
// Superadmin: verifikasi-validasi pengajuan perubahan data kepegawaian dari pegawai. Dapat mengoreksi nilai sebelum menyetujui.
import { ref, computed, onMounted, watch } from 'vue'
import { PhCheck, PhX, PhPencilSimple } from '@phosphor-icons/vue'
import { usePerubahanData } from '@/stores/perubahanData'
import { useUI } from '@/stores/ui'
import { KOLOM_AJUAN } from '@/lib/kepegawaian'
import { nilaiAjuan } from '@/lib/teksAjuan'
import { formatWaktu, formatPanjang } from '@/lib/tanggal'
import LembarBawah from '@/components/LembarBawah.vue'

const pd = usePerubahanData(); const ui = useUI()
const status = ref('menunggu'); const lembar = ref(false); const pilih = ref(null); const koreksi = ref({}); const catatan = ref(''); const proses = ref(false)
const muat = () => pd.muat(status.value || null).catch((e) => ui.toast(e.message, 'galat'))
onMounted(muat); watch(status, muat)
const STATUS = { menunggu: 'w-pengajuan', disetujui: 'w-presensi', ditolak: 'w-klinik', dibatalkan: 'w-hakakses' }
function buka(r) { pilih.value = r; koreksi.value = { ...r.data }; catatan.value = ''; lembar.value = true }
const dikoreksi = computed(() => (pilih.value ? Object.fromEntries(Object.entries(koreksi.value).filter(([k, v]) => String(v ?? '') !== String(pilih.value.data[k] ?? ''))) : {}))
async function putuskan(setuju) {
  if (!setuju && catatan.value.trim().length < 5) return ui.toast('Tuliskan alasan penolakan (minimal 5 huruf).', 'galat')
  proses.value = true
  try {
    await pd.putuskan(pilih.value.id, setuju, catatan.value.trim(), Object.keys(dikoreksi.value).length ? dikoreksi.value : null)
    lembar.value = false; ui.toast(setuju ? 'Disetujui; data pegawai sudah diperbarui.' : 'Pengajuan ditolak.'); await muat()
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <section class="w-pengajuan">
    <select v-model="status" class="isian mb-3 w-auto" aria-label="Saring status pengajuan">
      <option value="menunggu">Menunggu verifikasi</option><option value="disetujui">Disetujui</option><option value="ditolak">Ditolak</option><option value="">Semua</option></select>
    <ul class="grid gap-3 lg:grid-cols-2">
      <li v-for="r in pd.daftar" :key="r.id">
        <button class="kartu w-full p-4 text-left hover:bg-permukaan2" :class="STATUS[r.status]" :disabled="r.status !== 'menunggu'" @click="buka(r)">
          <span class="flex items-center gap-2"><b class="flex-1">{{ r.nama }}</b><span class="lencana" :class="STATUS[r.status]">{{ r.status }}</span></span>
          <span class="block text-xs text-teks3">NIY {{ r.niy || '–' }} · diajukan {{ formatWaktu(r.diajukan_pada) }} WITA</span>
          <span class="mt-2 block space-y-0.5 text-sm text-teks2">
            <span v-for="(v, k) in r.data" :key="k" class="block">{{ KOLOM_AJUAN[k] }}: {{ nilaiAjuan(k, r.lama[k]) }} → <b class="text-teks">{{ nilaiAjuan(k, v) }}</b></span></span>
          <span v-if="r.alasan" class="mt-1 block text-xs text-teks3">Alasan: {{ r.alasan }}</span>
          <span v-if="r.catatan_verifikator" class="mt-1 block text-xs text-teks3">Catatan: {{ r.catatan_verifikator }}</span>
        </button>
      </li>
    </ul>
    <p v-if="!pd.daftar.length && !pd.memuat" class="py-16 text-center text-teks3">Tidak ada pengajuan perubahan data pada saringan ini.</p>

    <LembarBawah v-model="lembar" :judul="pilih ? `Perubahan data · ${pilih.nama}` : ''">
      <div v-if="pilih" class="space-y-3 pb-2">
        <p class="text-sm text-teks2">Alasan: {{ pilih.alasan }}<template v-if="pilih.tanggal_berlaku"> · berlaku {{ formatPanjang(pilih.tanggal_berlaku) }}</template></p>
        <div v-for="(v, k) in pilih.data" :key="k" class="rounded-xl bg-permukaan2 p-3 text-sm">
          <p class="font-bold">{{ KOLOM_AJUAN[k] }}</p>
          <p class="text-teks3">Lama: {{ nilaiAjuan(k, pilih.lama[k]) }} · diajukan: <b class="text-teks">{{ nilaiAjuan(k, v) }}</b></p>
          <label class="mt-1 flex items-center gap-2 text-xs text-teks3"><PhPencilSimple :size="14" /> Koreksi (bila perlu)
            <input v-model="koreksi[k]" class="isian min-h-[36px] flex-1 text-sm" :aria-label="`Koreksi ${KOLOM_AJUAN[k]}`" /></label>
        </div>
        <textarea v-model="catatan" rows="2" class="isian" placeholder="Catatan untuk pegawai (wajib bila ditolak)" aria-label="Catatan verifikator" />
        <div class="grid grid-cols-2 gap-2">
          <button class="tombol-garis" :disabled="proses" @click="putuskan(false)"><PhX :size="20" /> Tolak</button>
          <button class="tombol-utama" :disabled="proses" @click="putuskan(true)"><PhCheck :size="20" weight="bold" /> Setujui</button>
        </div>
        <p class="text-xs text-teks3">Disetujui = data pegawai langsung diperbarui dan tercatat di riwayat kepegawaian sesuai tanggal berlaku.</p>
      </div>
    </LembarBawah>
  </section>
</template>
