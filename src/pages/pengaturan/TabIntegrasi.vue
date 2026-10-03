<!-- SIMKA PRO | src/pages/pengaturan/TabIntegrasi.vue | v1.0 | Fase 1 – Pengaturan | 03/10/2026 -->
<script setup>
import { ref, onMounted, computed } from 'vue'
import { PhFloppyDisk, PhHeartbeat, PhCloudArrowUp, PhWarningCircle, PhShieldCheck } from '@phosphor-icons/vue'
import { useLembaga } from '@/stores/lembaga'
import { useUI } from '@/stores/ui'
import { formatRelatif, formatWaktu } from '@/lib/tanggal'

const lembaga = useLembaga(); const ui = useUI()
const f = ref({ ...lembaga.integrasi })
const status = ref(null)
onMounted(async () => { status.value = await lembaga.statusLayanan() })
const sehat = computed(() => status.value?.heartbeat_terakhir && (Date.now() - new Date(status.value.heartbeat_terakhir)) < 30 * 3600e3)
const ISIAN = [
  { k: 'domain_aplikasi', l: 'Alamat aplikasi', ph: 'https://syathibygowa.github.io/simka' },
  { k: 'gas_url', l: 'URL Web App Google Apps Script', ph: 'https://script.google.com/macros/s/…/exec' },
  { k: 'drive_folder_nama', l: 'Nama folder Google Drive' }, { k: 'drive_folder_id', l: 'ID folder Google Drive' },
  { k: 'email_pengirim', l: 'Email pengirim' }, { k: 'nama_pengirim', l: 'Nama pengirim email' },
]
async function simpan() {
  try { await lembaga.simpanPengaturan('integrasi', f.value); ui.toast('Catatan integrasi disimpan.') } catch (e) { ui.toast(e.message, 'galat') }
}
</script>
<template>
  <div class="space-y-5">
    <section class="grid gap-3 sm:grid-cols-3">
      <div :class="['kartu flex items-center gap-3 p-4', sehat ? 'w-presensi' : 'w-klinik']">
        <span class="chip-ikon h-11 w-11"><component :is="sehat ? PhHeartbeat : PhWarningCircle" :size="24" weight="duotone" /></span>
        <div><p class="text-sm text-teks3">Heartbeat terakhir</p>
          <p class="font-bold" :title="status?.heartbeat_terakhir ? formatWaktu(status.heartbeat_terakhir) : ''">{{ status?.heartbeat_terakhir ? formatRelatif(status.heartbeat_terakhir) : 'Belum ada' }}</p></div>
      </div>
      <div class="kartu w-laporan flex items-center gap-3 p-4">
        <span class="chip-ikon h-11 w-11"><PhCloudArrowUp :size="24" weight="duotone" /></span>
        <div><p class="text-sm text-teks3">Berkas menunggu ke Drive</p><p class="font-bold tabular-nums">{{ status?.berkas_antri ?? '–' }}</p></div>
      </div>
      <div :class="['kartu flex items-center gap-3 p-4', status?.berkas_gagal ? 'w-klinik' : 'w-gaji']">
        <span class="chip-ikon h-11 w-11"><PhShieldCheck :size="24" weight="duotone" /></span>
        <div><p class="text-sm text-teks3">Berkas gagal dipindah</p><p class="font-bold tabular-nums">{{ status?.berkas_gagal ?? '–' }}</p></div>
      </div>
    </section>

    <section class="kartu p-5">
      <h3 class="judul-bagian">Catatan sambungan layanan</h3>
      <p class="mb-4 text-sm text-teks3">Isian ini hanya catatan untuk superadmin. Kunci rahasia (service_role key, GAS_SECRET) <strong class="font-semibold text-teks2">tidak disimpan di sini</strong>, tetapi di Supabase Secrets dan Script Properties GAS.</p>
      <div class="grid gap-4 sm:grid-cols-2">
        <div v-for="i in ISIAN" :key="i.k"><label class="label-isian" :for="'in-' + i.k">{{ i.l }}</label><input :id="'in-' + i.k" v-model="f[i.k]" class="isian" :placeholder="i.ph" /></div>
      </div>
      <div class="mt-4 flex justify-end"><button class="tombol-utama" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> Simpan</button></div>
    </section>
  </div>
</template>
