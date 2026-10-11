<!-- SIMKA PRO | src/pages/gaji/TabTtdGaji.vue | v1.0 | Fase 11 – Tahap 4 Tanda tangan daftar gaji bagi pejabat tanpa akses data gaji | 11/10/2026 -->
<script setup>
// Untuk penanda tangan yang tidak memegang hak baca data gaji (mis. Direktur bila Ketentuan meminta tanda tangan Direktur):
// ringkasan daftar gaji per unit (tanpa rincian per pegawai), lalu tanda tangani atau tolak beralasan.
import { ref, onMounted } from 'vue'
import { PhSignature, PhXCircle, PhSealCheck, PhClock, PhUsersThree, PhHandCoins } from '@phosphor-icons/vue'
import { useGaji } from '@/stores/gaji'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { formatWaktu, formatPendek } from '@/lib/tanggal'
import { namaPeriode, rupiah } from '@/lib/gaji'

const gaji = useGaji(); const sesi = useSesi(); const ui = useUI()
const daftar = ref([]); const memuat = ref(true); const proses = ref(false); const tolak = ref({})
async function muat() { try { daftar.value = await gaji.ttdSaya() } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false } }
onMounted(muat)
const menunggu = (r) => r.periode.status === 'diajukan' && r.ttd.some((t) => t.status === 'menunggu' && t.saya)
async function tanda(r, setuju) {
  const cat = (tolak.value[r.periode.id] || '').trim()
  if (!setuju && cat.length < 3) { tolak.value[r.periode.id] = tolak.value[r.periode.id] ?? ''; return ui.toast('Tulis alasan penolakan.', 'galat') }
  if (setuju && !(await ui.konfirmasi({ judul: 'Tanda tangani daftar gaji?', pesan: `Gaji ${namaPeriode(r.periode)}: ${r.jumlah.pegawai} pegawai, ${rupiah(r.jumlah.diterima)}.`, ya: 'Tanda tangani' }))) return
  proses.value = true
  try { await gaji.tandatangani(r.periode.id, setuju, cat); ui.toast(setuju ? 'Daftar gaji ditandatangani.' : 'Pengajuan dikembalikan.'); await muat(); gaji.muatHak() }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <div>
    <p v-if="memuat" class="kartu p-8 text-center text-sm text-teks3">Memuat…</p>
    <p v-else-if="!daftar.length" class="kartu p-8 text-center text-sm text-teks3">Tidak ada daftar gaji yang menunggu tanda tangan Anda.</p>
    <section v-for="r in daftar" :key="r.periode.id" :class="['kartu mb-3 p-4', menunggu(r) ? 'w-verifikasi' : 'w-presensi']">
      <div class="flex flex-wrap items-start gap-3">
        <span class="chip-ikon h-11 w-11 shrink-0"><component :is="menunggu(r) ? PhSignature : PhSealCheck" :size="24" weight="duotone" /></span>
        <div class="min-w-[200px] flex-1">
          <p class="text-lg font-extrabold">Gaji {{ namaPeriode(r.periode) }}</p>
          <p class="text-sm text-teks3">Diajukan {{ r.periode.diajukan_oleh || '–' }}, {{ formatWaktu(r.periode.diajukan_pada) }} · dibayar {{ formatPendek(r.periode.tanggal_bayar) }}</p>
        </div>
      </div>
      <div class="mt-3 grid grid-cols-2 gap-3 sm:grid-cols-4">
        <p class="rounded-xl bg-permukaan2 p-3"><PhUsersThree :size="18" class="text-teks3" /><span class="block text-xl font-extrabold tabular-nums">{{ r.jumlah.pegawai }}</span><span class="text-xs text-teks3">pegawai</span></p>
        <p class="col-span-1 rounded-xl bg-permukaan2 p-3 sm:col-span-3"><PhHandCoins :size="18" class="text-teks3" /><span class="block text-xl font-extrabold tabular-nums">{{ rupiah(r.jumlah.diterima) }}</span>
          <span class="text-xs text-teks3">jumlah diterima · pendapatan {{ rupiah(r.jumlah.pendapatan) }} · potongan {{ rupiah(r.jumlah.potongan) }}</span></p>
      </div>
      <table class="mt-3 w-full text-left text-sm">
        <thead class="text-teks3"><tr><th class="py-1 font-semibold">Bidang/unit</th><th class="py-1 text-right font-semibold">Pegawai</th><th class="py-1 text-right font-semibold">Diterima</th></tr></thead>
        <tbody class="divide-y divide-garis"><tr v-for="u in r.per_unit" :key="u.unit"><td class="py-1.5">{{ u.unit }}</td><td class="py-1.5 text-right tabular-nums">{{ u.pegawai }}</td>
          <td class="py-1.5 text-right tabular-nums">{{ rupiah(u.diterima) }}</td></tr></tbody>
      </table>
      <ul class="mt-3 flex flex-wrap gap-2">
        <li v-for="t in r.ttd" :key="t.peran" :class="['lencana', t.status === 'ditandatangani' ? 'w-presensi' : 'w-tahfizh']">
          <component :is="t.status === 'ditandatangani' ? PhSealCheck : PhClock" :size="14" /> {{ t.peran === 'bendahara' ? 'Bendahara' : 'Direktur' }}:
          {{ t.status === 'ditandatangani' ? t.nama : 'menunggu' }}</li>
      </ul>
      <div v-if="menunggu(r)" class="mt-3 space-y-2">
        <input v-if="tolak[r.periode.id] !== undefined" v-model="tolak[r.periode.id]" class="isian" placeholder="Alasan penolakan" aria-label="Alasan penolakan" />
        <div class="flex flex-wrap gap-2">
          <button class="tombol-utama" :disabled="proses" @click="tanda(r, true)"><PhSignature :size="20" weight="duotone" /> Tanda tangani</button>
          <button class="tombol-garis" :disabled="proses" @click="tolak[r.periode.id] === undefined ? (tolak[r.periode.id] = '') : tanda(r, false)"><PhXCircle :size="20" /> Tolak</button>
        </div>
      </div>
    </section>
  </div>
</template>
