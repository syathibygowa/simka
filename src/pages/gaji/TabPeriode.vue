<!-- SIMKA PRO | src/pages/gaji/TabPeriode.vue | v1.0 | Fase 11 – Tahap 2 Daftar dan pembuatan periode gaji | 11/10/2026 -->
<script setup>
// Daftar periode gaji bulanan. Pengelola gaji membuat periode → semua komponen terhitung otomatis dari skema,
// penetapan yayasan, dan honor per jam. Mengetuk periode membuka rinciannya (?periode=<id>).
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { PhPlus, PhCalendarBlank, PhUsersThree, PhWarningCircle, PhCaretRight, PhCoins } from '@phosphor-icons/vue'
import { useGaji } from '@/stores/gaji'
import { useUI } from '@/stores/ui'
import { hariIniISO, BULAN, formatPendek } from '@/lib/tanggal'
import { namaPeriode, STATUS_PERIODE, rupiah } from '@/lib/gaji'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import PeriodeRinci from './PeriodeRinci.vue'

const route = useRoute(); const router = useRouter(); const gaji = useGaji(); const ui = useUI()
const daftar = ref([]); const memuat = ref(true)
async function muat() {
  memuat.value = true
  try { daftar.value = await gaji.daftarPeriode() } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
onMounted(muat)
const periodeId = computed(() => (typeof route.query.periode === 'string' ? route.query.periode : ''))
watch(periodeId, (v) => { if (!v) muat() })
const buka = (id) => router.replace({ query: { ...route.query, periode: id } })
const tutup = () => router.replace({ query: { ...route.query, periode: undefined } })

// ---------- Buat periode ----------
const f = ref(null); const proses = ref(false)
const tahunIni = Number(hariIniISO().slice(0, 4)); const bulanIni = Number(hariIniISO().slice(5, 7))
function bukaBuat() {
  // Bawaan: bulan berjalan; bila sudah ada, bulan berikutnya yang belum dibuat
  let t = tahunIni, b = bulanIni
  while (daftar.value.some((p) => p.tahun === t && p.bulan === b)) { b++; if (b > 12) { b = 1; t++ } }
  f.value = { tahun: t, bulan: b, tanggal_bayar: bayarUntuk(t, b) }
}
/** Tanggal gajian bawaan: tanggal di Ketentuan pada bulan berikutnya. */
function bayarUntuk(tahun, bulan) {
  const t = bulan === 12 ? tahun + 1 : tahun; const b = bulan === 12 ? 1 : bulan + 1
  return `${t}-${String(b).padStart(2, '0')}-${String(gaji.pengaturan.tanggal_gajian || 1).padStart(2, '0')}`
}
watch(() => f.value && [f.value.tahun, f.value.bulan], (v) => { if (v) f.value.tanggal_bayar = bayarUntuk(v[0], v[1]) })
async function buat() {
  proses.value = true
  try {
    const id = await gaji.buatPeriode(Number(f.value.tahun), Number(f.value.bulan), f.value.tanggal_bayar || null)
    ui.toast(`Periode gaji ${BULAN[f.value.bulan - 1]} ${f.value.tahun} dibuat dan dihitung.`); f.value = null
    await muat(); buka(id)
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <PeriodeRinci v-if="periodeId" :id="periodeId" @tutup="tutup" />
  <div v-else>
    <div class="mb-4 flex flex-wrap items-center gap-2">
      <p class="min-w-[220px] flex-1 text-sm text-teks3">Setiap periode memuat gaji yang benar-benar diterima pegawai: komponen skema, honor per jam,
        dan penyesuaian ketetapan yayasan.</p>
      <button v-if="gaji.hak.kelola" class="tombol-utama" @click="bukaBuat"><PhPlus :size="20" weight="bold" /> Buat periode gaji</button>
    </div>
    <p v-if="memuat" class="kartu p-8 text-center text-sm text-teks3">Memuat…</p>
    <div v-else-if="!daftar.length" class="kartu w-gaji flex flex-col items-center gap-3 p-8 text-center">
      <span class="chip-ikon h-14 w-14"><PhCalendarBlank :size="30" weight="duotone" /></span>
      <p class="font-bold">Belum ada periode gaji</p>
      <p class="max-w-md text-sm text-teks3">Buat periode bulan ini. Bila sudah memiliki data gaji yang diterima, impor dari Excel setelah periode dibuat.</p>
    </div>
    <ul v-else class="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
      <li v-for="p in daftar" :key="p.id">
        <button :class="['kartu w-full p-4 text-left transition hover:-translate-y-0.5 hover:shadow-apung', 'w-' + STATUS_PERIODE[p.status].w]" @click="buka(p.id)">
          <div class="flex items-start gap-3">
            <span class="chip-ikon h-11 w-11 shrink-0"><PhCoins :size="24" weight="duotone" /></span>
            <div class="min-w-0 flex-1">
              <p class="text-lg font-extrabold">{{ namaPeriode(p) }}</p>
              <p class="text-xs text-teks3">Dibayar {{ formatPendek(p.tanggal_bayar) }}</p>
            </div>
            <span class="lencana">{{ STATUS_PERIODE[p.status].n }}</span>
          </div>
          <p class="mt-3 text-sm text-teks3">Jumlah diterima</p>
          <p class="text-2xl font-extrabold tabular-nums">{{ rupiah(p.total_diterima) }}</p>
          <div class="mt-2 flex flex-wrap gap-x-4 gap-y-1 text-sm text-teks2">
            <span class="inline-flex items-center gap-1"><PhUsersThree :size="16" /> {{ p.pegawai }} pegawai</span>
            <span v-if="p.total_penyesuaian" class="tabular-nums">Penyesuaian {{ rupiah(p.total_penyesuaian) }}</span>
            <span v-if="p.data_kurang" class="w-klinik inline-flex items-center gap-1 font-semibold" style="color: var(--c)"><PhWarningCircle :size="16" /> {{ p.data_kurang }} data kurang</span>
          </div>
          <p class="mt-2 flex items-center justify-end gap-1 text-sm font-semibold" style="color: var(--c)">Buka rincian <PhCaretRight :size="16" /></p>
        </button>
      </li>
    </ul>

    <LembarBawah :model-value="!!f" @update:model-value="(x) => !x && (f = null)" judul="Buat periode gaji">
      <div v-if="f" class="space-y-4 pb-2">
        <div class="grid grid-cols-2 gap-3">
          <div><label class="label-isian" for="pg-bln">Bulan</label>
            <select id="pg-bln" v-model.number="f.bulan" class="isian"><option v-for="(n, i) in BULAN" :key="n" :value="i + 1">{{ n }}</option></select></div>
          <div><label class="label-isian" for="pg-th">Tahun</label>
            <select id="pg-th" v-model.number="f.tahun" class="isian"><option v-for="t in [tahunIni - 2, tahunIni - 1, tahunIni, tahunIni + 1]" :key="t" :value="t">{{ t }}</option></select></div>
        </div>
        <div><InputTanggal v-model="f.tanggal_bayar" label="Tanggal pembayaran" />
          <p class="mt-1 text-xs text-teks3">Bawaan: tanggal gajian di Ketentuan pada bulan berikutnya.</p></div>
        <p class="rounded-xl bg-permukaan2 p-3 text-sm text-teks2">Semua pegawai aktif dimasukkan dan dihitung otomatis. Periode bulan lalu boleh dibuat untuk
          mengarsipkan gaji yang sudah dibayar, lalu isi jumlah diterima lewat impor Excel.</p>
        <button class="tombol-utama w-full" :disabled="proses" @click="buat"><PhPlus :size="20" weight="bold" /> {{ proses ? 'Menghitung…' : 'Buat dan hitung' }}</button>
      </div>
    </LembarBawah>
  </div>
</template>
