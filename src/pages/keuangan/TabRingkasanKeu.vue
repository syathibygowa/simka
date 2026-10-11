<!-- SIMKA PRO | src/pages/keuangan/TabRingkasanKeu.vue | v1.0 | Fase 13 – Ringkasan keuangan santri (angka langsung) | 11/10/2026 -->
<script setup>
// Ringkasan: kartu statistik langsung (diperbarui setiap menit), capaian per jenis biaya, pemasukan 6 bulan,
// dan tagihan yang akan jatuh tempo (ketuk untuk membuka rincian santri).
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { PhHandCoins, PhCalendarCheck, PhWallet, PhWarningCircle, PhUsersThree, PhClockCountdown, PhInvoice, PhReceipt, PhCaretRight } from '@phosphor-icons/vue'
import { useKeuangan } from '@/stores/keuangan'
import { useUI } from '@/stores/ui'
import { formatPendek, formatJam, sekarang } from '@/lib/tanggal'
import { rupiah, namaBulan, SIKLUS } from '@/lib/keuangan'
import KartuStatistik from '@/components/KartuStatistik.vue'

const keu = useKeuangan(); const ui = useUI(); const router = useRouter(); const route = useRoute()
const r = ref(null); const diperbarui = ref('')
async function muat() {
  try { r.value = await keu.ringkasan(); diperbarui.value = formatJam(sekarang()) } catch (e) { ui.toast(e.message, 'galat') }
}
let jam
onMounted(() => { muat(); jam = setInterval(muat, 60000) })
onBeforeUnmount(() => clearInterval(jam))
const persen = (a, b) => (Number(b) ? Math.round((100 * Number(a)) / Number(b)) : 0)
const maks = computed(() => Math.max(1, ...(r.value?.per_bulan || []).map((x) => Number(x.masuk))))
const buka = (sid) => router.replace({ query: { ...route.query, santri: sid } })
</script>
<template>
  <div>
    <p v-if="!r" class="kartu p-8 text-center text-sm text-teks3">Memuat…</p>
    <template v-else>
      <div class="mb-1 flex items-center justify-between gap-2">
        <h2 class="judul-bagian">Keuangan santri</h2>
        <p class="flex items-center gap-1.5 text-xs text-teks3"><span class="h-2 w-2 rounded-full bg-[#1E7D4F]" aria-hidden="true" /> Langsung – diperbarui {{ diperbarui }}</p>
      </div>
      <div class="-mx-4 mb-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-2 sm:overflow-visible sm:px-0 xl:grid-cols-3">
        <KartuStatistik class="w-[72%] shrink-0 snap-start sm:w-auto" judul="Pemasukan hari ini" :nilai="rupiah(r.masuk_hari_ini)" :ikon="PhHandCoins" warna="presensi" :keterangan="`${r.transaksi_hari_ini} transaksi`" ke="/keuangan/pembayaran" />
        <KartuStatistik class="w-[72%] shrink-0 snap-start sm:w-auto" judul="Pemasukan bulan ini" :nilai="rupiah(r.masuk_bulan_ini)" :ikon="PhCalendarCheck" warna="agenda" :keterangan="`${r.transaksi_bulan_ini} transaksi`" />
        <KartuStatistik class="w-[72%] shrink-0 snap-start sm:w-auto" judul="Sisa tagihan berjalan" :nilai="rupiah(r.sisa)" :ikon="PhWallet" warna="keuangan" :keterangan="`Terbayar ${persen(r.dibayar, r.tagihan)}% dari ${rupiah(r.tagihan)}`" ke="/keuangan/tagihan" />
        <KartuStatistik class="w-[72%] shrink-0 snap-start sm:w-auto" judul="Tunggakan lewat jatuh tempo" :nilai="rupiah(r.lewat)" :ikon="PhWarningCircle" warna="klinik" keterangan="Belum dibayar setelah jatuh tempo" ke="/keuangan/tunggakan" />
        <KartuStatistik class="w-[44%] shrink-0 snap-start sm:w-auto" judul="Santri menunggak" :nilai="r.santri_menunggak" :ikon="PhUsersThree" warna="pengajuan" keterangan="Ada tagihan lewat tempo" ke="/keuangan/santri?status=lewat" />
        <KartuStatistik class="w-[44%] shrink-0 snap-start sm:w-auto" judul="Jatuh tempo 7 hari" :nilai="r.tempo_pekan" :ikon="PhClockCountdown" warna="tahfizh" :keterangan="rupiah(r.tempo_pekan_nominal)" />
      </div>

      <div v-if="!r.jenis_biaya" class="kartu w-keuangan mb-4 flex flex-wrap items-center gap-3 p-4">
        <span class="chip-ikon h-10 w-10"><PhInvoice :size="22" weight="duotone" /></span>
        <p class="min-w-[200px] flex-1 text-sm">Mulai dengan mengisi <b>jenis biaya</b> (SPP, daftar ulang, uang pangkal, dan lainnya) beserta nominal standarnya.</p>
        <router-link to="/keuangan/pengaturan" class="tombol-utama">Atur jenis biaya</router-link>
      </div>

      <div class="grid gap-4 xl:grid-cols-2">
        <section class="kartu w-keuangan p-4 sm:p-5">
          <h3 class="judul-bagian mb-3">Capaian per jenis biaya</h3>
          <p v-if="!r.per_jenis.length" class="rounded-xl bg-permukaan2 p-3 text-sm text-teks3">Belum ada tagihan.</p>
          <ul class="space-y-3">
            <li v-for="x in r.per_jenis" :key="x.fee_type_id">
              <div class="flex flex-wrap items-baseline justify-between gap-2"><p class="font-semibold">{{ x.jenis }} <span :class="['lencana', 'w-' + SIKLUS[x.siklus]?.w]">{{ SIKLUS[x.siklus]?.n }}</span></p>
                <p class="text-sm tabular-nums text-teks2">{{ rupiah(x.dibayar) }} / {{ rupiah(x.tagihan) }}</p></div>
              <div class="mt-1.5 h-2.5 overflow-hidden rounded-full bg-permukaan2" role="progressbar" :aria-valuenow="persen(x.dibayar, x.tagihan)" aria-valuemin="0" aria-valuemax="100" :aria-label="'Terbayar ' + x.jenis">
                <div class="h-full rounded-full" :style="{ width: persen(x.dibayar, x.tagihan) + '%', background: 'var(--c)' }" /></div>
              <p class="mt-1 text-xs text-teks3">{{ persen(x.dibayar, x.tagihan) }}% terbayar · sisa {{ rupiah(x.sisa) }}</p>
            </li>
          </ul>
        </section>
        <section class="kartu w-presensi p-4 sm:p-5">
          <h3 class="judul-bagian mb-3">Pemasukan 6 bulan terakhir</h3>
          <div class="flex h-44 items-end gap-2" role="img" :aria-label="'Pemasukan per bulan: ' + r.per_bulan.map((x) => namaBulan(x.bulan) + ' ' + rupiah(x.masuk)).join(', ')">
            <div v-for="x in r.per_bulan" :key="x.bulan" class="flex h-full flex-1 flex-col items-center justify-end gap-1">
              <span class="text-[10px] font-semibold tabular-nums text-teks2">{{ Number(x.masuk) ? (Number(x.masuk) / 1e6).toLocaleString('id-ID', { maximumFractionDigits: 1 }) + ' jt' : '0' }}</span>
              <div class="w-full max-w-[44px] rounded-t-lg" :style="{ height: Math.max(2, (100 * Number(x.masuk)) / maks) + '%', background: 'linear-gradient(var(--c), var(--c2))' }" />
              <span class="text-xs text-teks3">{{ namaBulan(x.bulan).slice(0, 3) }}</span>
            </div>
          </div>
        </section>
        <section class="kartu w-tahfizh p-4 sm:p-5 xl:col-span-2">
          <div class="mb-2 flex items-center justify-between gap-2"><h3 class="judul-bagian">Jatuh tempo terdekat</h3>
            <router-link to="/keuangan/tagihan?status=tunggak" class="text-sm font-semibold" style="color: var(--c)">Semua tagihan</router-link></div>
          <p v-if="!r.tempo_terdekat.length" class="rounded-xl bg-permukaan2 p-3 text-sm text-teks3">Tidak ada tagihan yang akan jatuh tempo.</p>
          <ul class="divide-y divide-garis">
            <li v-for="x in r.tempo_terdekat" :key="x.bill_id">
              <button class="flex w-full items-center gap-3 py-2.5 text-left" @click="buka(x.student_id)">
                <span class="w-20 shrink-0 text-sm font-bold tabular-nums">{{ formatPendek(x.jatuh_tempo).slice(0, 5) }}</span>
                <span class="min-w-0 flex-1"><span class="block truncate font-semibold">{{ x.nama }}</span><span class="block truncate text-xs text-teks3">{{ x.nis }} · {{ x.kelas || '–' }} · {{ x.tagihan }}</span></span>
                <span class="font-bold tabular-nums">{{ rupiah(x.sisa) }}</span><PhCaretRight :size="16" class="text-teks3" />
              </button>
            </li>
          </ul>
        </section>
      </div>
      <div class="mt-4 flex flex-wrap gap-2">
        <router-link v-if="keu.hak.kelola" to="/keuangan/santri" class="tombol-utama"><PhReceipt :size="20" weight="duotone" /> Catat pembayaran</router-link>
        <router-link v-if="keu.hak.kelola" to="/keuangan/tagihan?buat=1" class="tombol-garis"><PhInvoice :size="20" weight="duotone" /> Buat tagihan</router-link>
      </div>
    </template>
  </div>
</template>
