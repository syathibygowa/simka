<!-- SIMKA PRO | src/pages/gaji/TabPermintaanSlip.vue | v1.0 | Fase 11 – Tahap 4 Permintaan slip dari pegawai | 11/10/2026 -->
<script setup>
// Permintaan slip gaji dari pegawai (diajukan lewat Profil bila slip tidak ditampilkan di akun pegawai).
// Pengelola gaji menanggapi: bukakan slip di akun pegawai itu, siapkan slip tercetak, atau tolak dengan alasan.
import { ref, computed, onMounted } from 'vue'
import { PhLockKeyOpen, PhPrinter, PhXCircle, PhTray, PhCheckCircle } from '@phosphor-icons/vue'
import { useGaji } from '@/stores/gaji'
import { useUI } from '@/stores/ui'
import { formatWaktu } from '@/lib/tanggal'

const emit = defineEmits(['berubah'])
const gaji = useGaji(); const ui = useUI()
const daftar = ref([]); const memuat = ref(true); const proses = ref(false); const semua = ref(false)
async function muat() { try { daftar.value = await gaji.daftarPermintaan() } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false } }
onMounted(muat)
const tampil = computed(() => daftar.value.filter((x) => semua.value || x.status === 'menunggu'))
const STATUS = { menunggu: { n: 'Menunggu', w: 'tahfizh' }, dibuka: { n: 'Dibukakan', w: 'presensi' }, dicetak: { n: 'Disiapkan tercetak', w: 'shift' }, ditolak: { n: 'Ditolak', w: 'klinik' } }
const tolak = ref({})
async function tanggapi(x, aksi) {
  const catatan = aksi === 'tolak' ? (tolak.value[x.id] || '').trim() : ''
  if (aksi === 'tolak' && catatan.length < 3) { tolak.value[x.id] = tolak.value[x.id] ?? ''; return ui.toast('Tulis alasan penolakan.', 'galat') }
  proses.value = true
  try {
    await gaji.tanggapiPermintaan(x.id, aksi, catatan)
    ui.toast({ buka: 'Slip dibukakan di akun pegawai.', cetak: 'Pegawai dikabari slip disiapkan tercetak.', tolak: 'Permintaan ditolak.' }[aksi])
    await muat(); emit('berubah')
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <div>
    <div class="mb-4 flex flex-wrap items-center gap-2">
      <p class="min-w-[220px] flex-1 text-sm text-teks3">Bila slip tidak ditampilkan di akun pegawai, pegawai dapat meminta slipnya dari Profil. Bukakan slip untuk pegawai itu saja,
        atau siapkan versi tercetak.</p>
      <label class="flex min-h-[44px] items-center gap-2 text-sm font-semibold"><input type="checkbox" v-model="semua" class="h-5 w-5 accent-[#C7332F]" /> Tampilkan yang sudah ditanggapi</label>
    </div>
    <p v-if="memuat" class="kartu p-8 text-center text-sm text-teks3">Memuat…</p>
    <div v-else-if="!tampil.length" class="kartu w-gaji flex flex-col items-center gap-3 p-8 text-center">
      <span class="chip-ikon h-14 w-14"><PhTray :size="30" weight="duotone" /></span><p class="font-bold">Tidak ada permintaan yang menunggu</p>
    </div>
    <ul v-else class="grid gap-3 md:grid-cols-2">
      <li v-for="x in tampil" :key="x.id" :class="['kartu p-4', 'w-' + STATUS[x.status].w]">
        <div class="flex items-start gap-2">
          <div class="min-w-0 flex-1"><p class="font-bold">{{ x.nama }}</p><p class="text-xs text-teks3">NIY {{ x.niy || '–' }} · {{ formatWaktu(x.created_at) }}</p></div>
          <span class="lencana">{{ STATUS[x.status].n }}</span>
        </div>
        <p class="mt-2 text-sm">Periode: <b>{{ x.periode || 'semua slip yang sudah terbit' }}</b></p>
        <p v-if="x.catatan" class="text-sm text-teks2">Keperluan: {{ x.catatan }}</p>
        <p v-if="x.status !== 'menunggu'" class="mt-1 flex gap-1 text-xs text-teks3"><PhCheckCircle :size="14" /> {{ x.ditanggapi_oleh }}{{ x.tanggapan ? ': ' + x.tanggapan : '' }}</p>
        <template v-if="x.status === 'menunggu' && gaji.hak.kelola">
          <input v-if="tolak[x.id] !== undefined" v-model="tolak[x.id]" class="isian mt-3" placeholder="Alasan penolakan" aria-label="Alasan penolakan" />
          <div class="mt-3 flex flex-wrap gap-2">
            <button class="tombol-utama" :disabled="proses" @click="tanggapi(x, 'buka')"><PhLockKeyOpen :size="20" weight="duotone" /> Bukakan slip</button>
            <button class="tombol-garis" :disabled="proses" @click="tanggapi(x, 'cetak')"><PhPrinter :size="20" /> Siapkan tercetak</button>
            <button class="tombol-garis" :disabled="proses" @click="tolak[x.id] === undefined ? (tolak[x.id] = '') : tanggapi(x, 'tolak')"><PhXCircle :size="20" /> Tolak</button>
          </div>
        </template>
      </li>
    </ul>
  </div>
</template>
