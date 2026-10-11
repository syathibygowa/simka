<!-- SIMKA PRO | src/pages/gaji/TabSlipSaya.vue | v1.0 | Fase 11 – Tahap 4 Slip gaji milik pegawai | 11/10/2026 -->
<script setup>
// Slip gaji milik akun yang sedang masuk: tampil bila Ketentuan "slip di akun pegawai" aktif, atau slip dibukakan Bendahara.
// Daftar per bulan, rincian, cetak/unduh PDF (Simpan sebagai PDF di jendela cetak), ringkasan pinjaman dan simpanan.
// ?slip=<id> membuka rincian (dari notifikasi).
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { PhReceipt, PhCaretRight, PhHandCoins, PhPiggyBank, PhLockSimple, PhSealCheck } from '@phosphor-icons/vue'
import { useGaji } from '@/stores/gaji'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { formatPendek } from '@/lib/tanggal'
import { namaPeriode, rupiah, terbilang } from '@/lib/gaji'
import LembarBawah from '@/components/LembarBawah.vue'
import CetakSlip from '@/components/cetak/CetakSlip.vue'

const route = useRoute(); const router = useRouter(); const gaji = useGaji(); const sesi = useSesi(); const ui = useUI()
const isi = ref(null); const memuat = ref(true)
async function muat() { try { isi.value = await gaji.slipSaya() } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false } }
onMounted(muat)
const slipId = computed(() => (typeof route.query.slip === 'string' ? route.query.slip : ''))
const pilihan = computed(() => isi.value?.slip?.find((s) => s.id === slipId.value) || null)
const buka = computed({ get: () => !!pilihan.value, set: (v) => { if (!v) router.replace({ query: { ...route.query, slip: undefined } }) } })
watch([slipId, isi], () => { if (slipId.value && isi.value && !pilihan.value) ui.toast('Slip tidak dapat dibuka dari akun Anda.', 'galat') })
const pratinjau = ref(false)
const pend = computed(() => (pilihan.value?.item || []).filter((i) => i.jenis === 'pendapatan' && Number(i.besaran) !== 0))
const pot = computed(() => (pilihan.value?.item || []).filter((i) => i.jenis === 'potongan' && Number(i.besaran) !== 0))
</script>
<template>
  <div>
    <p v-if="memuat" class="kartu p-8 text-center text-sm text-teks3">Memuat…</p>
    <template v-else-if="isi">
      <div v-if="!isi.slip?.length" class="kartu w-gaji flex flex-col items-center gap-3 p-8 text-center">
        <span class="chip-ikon h-14 w-14"><component :is="isi.terbuka ? PhReceipt : PhLockSimple" :size="30" weight="duotone" /></span>
        <p class="font-bold">{{ isi.terbuka ? 'Belum ada slip gaji' : 'Slip gaji tidak ditampilkan' }}</p>
        <p class="max-w-md text-sm text-teks3">{{ isi.terbuka ? 'Slip gaji Anda tampil di sini setelah Bendahara menerbitkannya.' : 'Bila memerlukan slip, ajukan permintaan kepada Bendahara melalui Profil → Slip gaji.' }}</p>
      </div>
      <ul v-else class="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
        <li v-for="s in isi.slip" :key="s.id">
          <button class="kartu w-gaji w-full p-4 text-left transition hover:-translate-y-0.5 hover:shadow-apung" @click="router.replace({ query: { ...route.query, slip: s.id } })">
            <div class="flex items-start gap-3">
              <span class="chip-ikon h-11 w-11 shrink-0"><PhReceipt :size="24" weight="duotone" /></span>
              <div class="min-w-0 flex-1"><p class="text-lg font-extrabold">{{ namaPeriode(s.periode) }}</p><p class="text-xs text-teks3">{{ s.nomor_slip }}</p></div>
              <span v-if="s.revisi_ke" class="lencana w-shift">Revisi {{ s.revisi_ke }}</span>
            </div>
            <p class="mt-3 text-sm text-teks3">Jumlah diterima</p>
            <p class="text-2xl font-extrabold tabular-nums">{{ rupiah(s.diterima) }}</p>
            <p class="mt-1 flex items-center justify-end gap-1 text-sm font-semibold" style="color: var(--c)">Lihat slip <PhCaretRight :size="16" /></p>
          </button>
        </li>
      </ul>

      <div v-if="isi.pinjaman?.length || isi.simpanan?.length" class="mt-4 grid gap-3 md:grid-cols-2">
        <section v-if="isi.pinjaman?.length" class="kartu w-shift p-4">
          <h3 class="judul-bagian mb-2 flex items-center gap-2"><PhHandCoins :size="20" weight="duotone" style="color: var(--c)" /> Pinjaman saya</h3>
          <ul class="space-y-2 text-sm"><li v-for="(x, i) in isi.pinjaman" :key="i" class="flex justify-between gap-2">
            <span>{{ x.keterangan || 'Pinjaman' }} <span class="text-teks3">({{ x.status === 'lunas' ? 'lunas' : `cicilan ${rupiah(x.cicilan)}` }})</span></span>
            <span class="font-bold tabular-nums">sisa {{ rupiah(x.sisa) }}</span></li></ul>
        </section>
        <section v-if="isi.simpanan?.length" class="kartu w-berkas p-4">
          <h3 class="judul-bagian mb-2 flex items-center gap-2"><PhPiggyBank :size="20" weight="duotone" style="color: var(--c)" /> Simpanan saya</h3>
          <ul class="space-y-2 text-sm"><li v-for="(x, i) in isi.simpanan" :key="i" class="flex justify-between gap-2">
            <span>{{ x.program }} <span class="text-teks3">({{ rupiah(x.setoran) }}/bulan)</span></span><span class="font-bold tabular-nums">{{ rupiah(x.saldo) }}</span></li></ul>
        </section>
      </div>

      <LembarBawah v-model="buka" :judul="pilihan ? `Slip gaji ${namaPeriode(pilihan.periode)}` : ''" lebar>
        <div v-if="pilihan" class="space-y-4 pb-2">
          <p class="flex flex-wrap items-center gap-2 text-sm text-teks2"><PhSealCheck :size="18" weight="duotone" class="text-[#1E7D4F]" />
            {{ pilihan.nomor_slip }} · kode validasi {{ pilihan.kode_validasi }} · dibayar {{ formatPendek(pilihan.periode.tanggal_bayar) }}</p>
          <section>
            <h3 class="judul-bagian mb-1">Pendapatan</h3>
            <ul class="divide-y divide-garis rounded-xl border border-garis">
              <li v-for="(i, n) in pend" :key="n" class="flex justify-between gap-2 px-3 py-2 text-sm"><span>{{ i.label }}<span v-if="i.alasan" class="block text-xs text-teks3">{{ i.alasan }}</span></span>
                <span class="font-semibold tabular-nums">{{ rupiah(i.besaran) }}</span></li>
              <li class="flex justify-between px-3 py-2 text-sm font-bold"><span>Jumlah pendapatan</span><span class="tabular-nums">{{ rupiah(pilihan.total_pendapatan) }}</span></li>
            </ul>
          </section>
          <section>
            <h3 class="judul-bagian mb-1">Potongan</h3>
            <ul class="divide-y divide-garis rounded-xl border border-garis">
              <li v-for="(i, n) in pot" :key="n" class="flex justify-between gap-2 px-3 py-2 text-sm"><span>{{ i.label }}</span><span class="font-semibold tabular-nums">{{ rupiah(i.besaran) }}</span></li>
              <li v-if="!pot.length" class="px-3 py-2 text-sm text-teks3">Tidak ada potongan.</li>
              <li class="flex justify-between px-3 py-2 text-sm font-bold"><span>Jumlah potongan</span><span class="tabular-nums">{{ rupiah(pilihan.total_potongan) }}</span></li>
            </ul>
          </section>
          <div class="w-presensi rounded-xl p-4" style="background: color-mix(in srgb, var(--c) 10%, rgb(var(--permukaan)))">
            <p class="text-sm text-teks3">Jumlah diterima</p>
            <p class="text-3xl font-extrabold tabular-nums" style="color: var(--c)">{{ rupiah(pilihan.diterima) }}</p>
            <p class="text-sm italic text-teks2">{{ terbilang(pilihan.diterima) }}</p>
          </div>
          <button class="tombol-utama w-full" @click="pratinjau = true"><PhReceipt :size="20" weight="duotone" /> Cetak atau simpan PDF</button>
          <p class="text-xs text-teks3">Untuk menyimpan PDF, pilih "Simpan sebagai PDF" pada jendela cetak. Slip bersifat rahasia.</p>
        </div>
      </LembarBawah>
      <CetakSlip v-if="pilihan" v-model:pratinjau="pratinjau" :slip="[pilihan]" :pengaturan="isi.pengaturan || {}" :pencetak="sesi.pengguna?.nama_lengkap" />
    </template>
  </div>
</template>
