<!-- SIMKA PRO | src/pages/tahfizh/TabCapaian.vue | v1.0 | Fase 5 – Tahap 3 Validasi capaian juz dan status bulanan | 05/10/2026 -->
<script setup>
// Capaian tahfizh:
//  * Status bulanan — dihitung otomatis dari setoran (penambahan sabaq sebulan vs target pekan × pekan efektif).
//    Muhaffizh menandai Murojaah (dengan alasan); validator mengesahkan per halaqah (salinan beku) atau membatalkannya.
//  * Usulan juz — muhaffizh mengusulkan juz yang sudah dikuasai; validator menyetujui (menjadi juz resmi) atau mengembalikan.
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  PhCalendarCheck, PhSealCheck, PhCheckCircle, PhXCircle, PhArrowsClockwise, PhCrown, PhQuestion, PhUsersThree, PhEye, PhStamp,
  PhArrowCounterClockwise, PhPaperPlaneTilt, PhMagnifyingGlass, PhCheck, PhX, PhHourglass,
} from '@phosphor-icons/vue'
import { useTahfizh } from '@/stores/tahfizh'
import { useKelompokSantri } from '@/stores/kelompokSantri'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { STATUS_BULANAN, STATUS_USULAN, SUMBER_USULAN, PROGRAM, formatPosisi, labelBulan, penandaTahfizh, ringkasJuz } from '@/lib/tahfizh'
import { formatWaktu, formatPanjang, hariIniISO } from '@/lib/tanggal'
import KartuStatistik from '@/components/KartuStatistik.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import GridJuz from '@/components/GridJuz.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const tz = useTahfizh(); const kel = useKelompokSantri(); const sesi = useSesi(); const ui = useUI(); const route = useRoute(); const router = useRouter()
const bagian = ref(route.query.bagian === 'usulan' ? 'usulan' : 'bulanan')
watch(bagian, (b) => router.replace({ query: { ...route.query, bagian: b === 'usulan' ? 'usulan' : undefined } }))
const validator = computed(() => tz.hak.validasi)

// ===================== STATUS BULANAN =====================
const bulanIni = hariIniISO().slice(0, 8) + '01'
const bulan = ref(bulanIni); const halaqah = ref(''); const statusSaring = ref(''); const baris = ref([]); const memuat = ref(false); const proses = ref(false)
const daftarBulan = computed(() => tz.bulan.filter((b) => b.bulan <= bulanIni).map((b) => b.bulan).reverse())
const halaqahList = computed(() => [...new Map(baris.value.filter((s) => s.halaqah_id).map((s) => [s.halaqah_id, s.halaqah])).entries()]
  .map(([id, nama]) => ({ id, nama })).sort((a, b) => a.nama.localeCompare(b.nama, 'id', { numeric: true })))
async function muatBulanan() {
  memuat.value = true
  try { baris.value = await tz.capaianBulanan(bulan.value, null) } catch (e) { ui.toast(e.message, 'galat'); baris.value = [] } finally { memuat.value = false }
}
watch(bulan, muatBulanan)
const tampil = computed(() => baris.value.filter((r) => (!halaqah.value || r.halaqah_id === halaqah.value) && (!statusSaring.value || r.status === statusSaring.value)))
const dalamHalaqah = computed(() => baris.value.filter((r) => !halaqah.value || r.halaqah_id === halaqah.value))
const hitungStatus = computed(() => Object.fromEntries(Object.keys(STATUS_BULANAN).map((k) => [k, dalamHalaqah.value.filter((r) => r.status === k).length])))
const statistik = computed(() => [
  { k: 'tercapai', ikon: PhCheckCircle, ket: 'Penambahan ≥ target' }, { k: 'tidak_tercapai', ikon: PhXCircle, ket: 'Penambahan < target' },
  { k: 'murojaah', ikon: PhArrowsClockwise, ket: "Fokus muraja'ah (beralasan)" }, { k: 'khatam', ikon: PhCrown, ket: 'Hafalan 30 juz' },
  { k: 'tidak_terdata', ikon: PhQuestion, ket: 'Tidak ada setoran tercatat' },
].map((x) => ({ ...x, judul: STATUS_BULANAN[x.k].n, nilai: hitungStatus.value[x.k], warna: STATUS_BULANAN[x.k].w })))
const sudahSah = computed(() => dalamHalaqah.value.length > 0 && dalamHalaqah.value.every((r) => r.disahkan))
const sebagianSah = computed(() => dalamHalaqah.value.some((r) => r.disahkan))
const persen = (r) => (r.target_hal ? Math.min(100, Math.round((Math.max(0, r.tambah_hal) / r.target_hal) * 100)) : 100)

// Murojaah
const lembarMur = ref(false); const murSantri = ref(null); const alasan = ref('')
function bukaMurojaah(r) { murSantri.value = r; alasan.value = r.alasan_murojaah || ''; lembarMur.value = true }
const bolehMur = (r) => !r.disahkan && (r.muhaffizh_saya || validator.value) && r.status !== 'khatam'
async function simpanMur(aktif) {
  if (aktif && alasan.value.trim().length < 5) return ui.toast('Tuliskan alasan Murojaah (minimal 5 huruf).', 'galat')
  proses.value = true
  try { await tz.tandaiMurojaah([murSantri.value.student_id], bulan.value, aktif, alasan.value.trim()); lembarMur.value = false; ui.toast(aktif ? 'Ditandai Murojaah.' : 'Tanda Murojaah dicabut.'); await muatBulanan() }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
// Pengesahan
async function sahkan() {
  const nama = halaqah.value ? halaqahList.value.find((h) => h.id === halaqah.value)?.nama : 'semua santri yang tampil'
  if (!(await ui.konfirmasi({ judul: `Sahkan capaian ${labelBulan(bulan.value)}?`, pesan: `Status ${dalamHalaqah.value.filter((r) => !r.disahkan).length} santri (${nama}) dibekukan sebagai capaian resmi bulan ini. Setoran yang dikoreksi sesudahnya tidak mengubah status yang sudah disahkan.`, ya: 'Sahkan' }))) return
  proses.value = true
  try { const n = await tz.sahkanCapaian(bulan.value, halaqah.value || null, dalamHalaqah.value); ui.toast(`${n} santri disahkan.`); await muatBulanan() }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
async function batalSahkan() {
  if (!(await ui.konfirmasi({ judul: 'Batalkan pengesahan?', pesan: 'Status kembali dihitung otomatis dari setoran dan Murojaah dapat diubah lagi.', ya: 'Batalkan', bahaya: true }))) return
  proses.value = true
  try { const n = await tz.batalSahkanCapaian(bulan.value, halaqah.value || null, dalamHalaqah.value); ui.toast(`Pengesahan ${n} santri dibatalkan.`); await muatBulanan() }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}

// ===================== USULAN JUZ =====================
const usulan = ref([]); const saringUsulan = ref('menunggu'); const pilihUsulan = ref([]); const catatanTolak = ref(''); const lembarTolak = ref(false)
async function muatUsulan() { try { usulan.value = await tz.daftarUsulan(saringUsulan.value || null) } catch (e) { ui.toast(e.message, 'galat') } pilihUsulan.value = [] }
watch(saringUsulan, muatUsulan)
const menunggu = computed(() => usulan.value.filter((u) => u.status === 'menunggu'))
const semuaDipilih = computed(() => menunggu.value.length > 0 && menunggu.value.every((u) => pilihUsulan.value.includes(u.id)))
const pilihSemua = () => { pilihUsulan.value = semuaDipilih.value ? [] : menunggu.value.map((u) => u.id) }
async function putuskan(setuju, ids = pilihUsulan.value) {
  if (!ids.length) return ui.toast('Pilih usulan lebih dulu.', 'galat')
  if (!setuju && catatanTolak.value.trim().length < 5) return ui.toast('Tuliskan alasan pengembalian (minimal 5 huruf).', 'galat')
  if (setuju && !(await ui.konfirmasi({ judul: `Setujui ${ids.length} usulan?`, pesan: 'Juz yang disetujui langsung menjadi hafalan resmi santri.', ya: 'Setujui' }))) return
  proses.value = true
  try { const n = await tz.putuskanUsulan(ids, setuju, catatanTolak.value.trim()); lembarTolak.value = false; catatanTolak.value = ''; ui.toast(`${n} usulan ${setuju ? 'disetujui' : 'dikembalikan'}.`); await muatUsulan() }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
// Ajukan usulan (muhaffizh)
const lembarUsul = ref(false); const cariSantri = ref(''); const santriUsul = ref(null); const juzUsul = ref([]); const catatanUsul = ref('')
const calonSantri = computed(() => { const q = cariSantri.value.toLowerCase().trim(); return tz.santri.filter((s) => !q || `${s.nama} ${s.nis} ${s.halaqah || ''}`.toLowerCase().includes(q)).slice(0, 40) })
const menungguSantri = computed(() => (santriUsul.value ? usulan.value.filter((u) => u.student_id === santriUsul.value.student_id && u.status === 'menunggu').map((u) => u.juz) : []))
function bukaUsul() { santriUsul.value = null; juzUsul.value = []; catatanUsul.value = ''; cariSantri.value = ''; lembarUsul.value = true }
async function ajukan() {
  if (!santriUsul.value || !juzUsul.value.length) return ui.toast('Pilih santri dan juz yang diusulkan.', 'galat')
  proses.value = true
  try {
    const n = await tz.usulkanJuz(santriUsul.value.student_id, juzUsul.value, catatanUsul.value.trim())
    lembarUsul.value = false; ui.toast(n ? `${n} juz diusulkan. Validator menerima notifikasi.` : 'Juz tersebut sudah menunggu validasi.'); saringUsulan.value = 'menunggu'; await muatUsulan()
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}

onMounted(async () => {
  if (!tz.hakDimuat) await tz.muatHak()
  await kel.muat(); if (!tz.bulan.length) await tz.muatPengaturan()
  if (!tz.santri.length) await tz.muatSantri()
  await Promise.all([muatBulanan(), muatUsulan()])
})

// Cetak rekap status bulanan
const pratinjau = ref(false); const kepala = ref({ jabatan: '', nama: '', niy: '' })
const muhaffizhCetak = computed(() => {
  if (!halaqah.value) return null
  const g = kel.cari(halaqah.value); const p = (g?.pengasuh || []).find((x) => x.peran === 'utama' && x.berlaku !== false)
  return { jabatan: 'Muhaffizh', nama: p?.nama || '', niy: p?.niy || '' }
})
async function cetak() { kepala.value = await penandaTahfizh(); pratinjau.value = true }
</script>
<template>
  <div>
    <div class="layar-saja">
      <div class="mb-4 grid grid-cols-2 gap-1 rounded-2xl bg-permukaan2 p-1 sm:w-[28rem]" role="tablist" aria-label="Bagian capaian">
        <button role="tab" :aria-selected="bagian === 'bulanan'" @click="bagian = 'bulanan'" :class="['inline-flex min-h-[44px] items-center justify-center gap-2 rounded-xl text-sm font-semibold w-agenda', bagian === 'bulanan' ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">
          <PhCalendarCheck :size="18" weight="duotone" style="color: var(--c)" /> Status bulanan</button>
        <button role="tab" :aria-selected="bagian === 'usulan'" @click="bagian = 'usulan'" :class="['inline-flex min-h-[44px] items-center justify-center gap-2 rounded-xl text-sm font-semibold w-pengajuan', bagian === 'usulan' ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">
          <PhSealCheck :size="18" weight="duotone" style="color: var(--c)" /> Usulan juz<span v-if="menunggu.length && saringUsulan === 'menunggu'" class="rounded-full bg-[#C7332F] px-1.5 text-xs text-white">{{ menunggu.length }}</span></button>
      </div>

      <!-- ============ STATUS BULANAN ============ -->
      <template v-if="bagian === 'bulanan'">
        <div class="flex flex-wrap items-end gap-2">
          <div><label class="label-isian" for="cp-bulan">Bulan</label>
            <select id="cp-bulan" v-model="bulan" class="isian w-auto"><option v-for="b in daftarBulan" :key="b" :value="b">{{ labelBulan(b) }}</option></select></div>
          <select v-model="halaqah" class="isian w-auto" aria-label="Saring halaqah"><option value="">Semua halaqah</option><option v-for="h in halaqahList" :key="h.id" :value="h.id">{{ h.nama }}</option></select>
          <select v-model="statusSaring" class="isian w-auto" aria-label="Saring status"><option value="">Semua status</option><option v-for="(v, k) in STATUS_BULANAN" :key="k" :value="k">{{ v.n }}</option></select>
          <button class="tombol-garis w-laporan" @click="cetak"><PhEye :size="20" weight="duotone" style="color: var(--c)" /> Pratinjau cetak</button>
        </div>

        <div class="-mx-4 mt-3 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-5 sm:overflow-visible sm:px-0">
          <KartuStatistik v-for="k in statistik" :key="k.k" class="w-[42%] shrink-0 cursor-pointer snap-start sm:w-auto" :judul="k.judul" :nilai="memuat ? '…' : k.nilai" :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket"
            @click="statusSaring = statusSaring === k.k ? '' : k.k" />
        </div>

        <div class="kartu mt-4 flex flex-wrap items-center gap-3 p-4" :class="sudahSah ? 'w-presensi' : 'w-pengajuan'">
          <span class="chip-ikon h-11 w-11"><component :is="sudahSah ? PhStamp : PhHourglass" :size="24" weight="duotone" /></span>
          <p class="min-w-[200px] flex-1 text-sm text-teks2">
            <b class="text-teks">{{ sudahSah ? 'Sudah disahkan' : sebagianSah ? 'Sebagian sudah disahkan' : 'Belum disahkan' }}</b> ·
            {{ sudahSah ? 'status di bawah adalah capaian resmi bulan ini.' : 'status dihitung langsung dari setoran dan dapat berubah sampai disahkan validator.' }}</p>
          <template v-if="validator">
            <button v-if="!sudahSah" class="tombol-utama" :disabled="proses || !dalamHalaqah.length" @click="sahkan"><PhStamp :size="20" weight="duotone" /> Sahkan {{ halaqah ? 'halaqah ini' : 'semua' }}</button>
            <button v-if="sebagianSah" class="tombol-garis" :disabled="proses" @click="batalSahkan"><PhArrowCounterClockwise :size="20" /> Batalkan pengesahan</button>
          </template>
        </div>

        <!-- Desktop -->
        <div class="kartu mt-4 hidden overflow-x-auto lg:block">
          <table class="w-full text-left text-sm">
            <thead class="border-b border-garis bg-permukaan2 text-teks2"><tr>
              <th class="px-4 py-3 font-bold">Nama</th><th class="px-4 py-3 font-bold">Halaqah</th><th class="px-4 py-3 font-bold">Awal → akhir</th>
              <th class="w-48 px-4 py-3 font-bold">Penambahan / target</th><th class="px-4 py-3 font-bold">Status</th><th class="w-32 px-4 py-3" /></tr></thead>
            <tbody class="divide-y divide-garis">
              <tr v-for="r in tampil" :key="r.student_id">
                <td class="px-4 py-3"><b>{{ r.nama }}</b><span class="block text-xs text-teks3">{{ r.nis }} · {{ r.kelas || r.tingkat }} · {{ PROGRAM[r.program] }}</span></td>
                <td class="px-4 py-3 text-teks2">{{ r.halaqah || '–' }}</td>
                <td class="whitespace-nowrap px-4 py-3 tabular-nums text-teks2">{{ formatPosisi(r.posisi_awal_hal) }} → <b class="text-teks">{{ formatPosisi(r.posisi_akhir_hal) }}</b></td>
                <td class="px-4 py-3"><div class="flex items-center gap-2 tabular-nums"><b>{{ r.tambah_hal }}</b><span class="text-teks3">/ {{ r.target_hal }} hal</span></div>
                  <div class="mt-1 h-1.5 overflow-hidden rounded-full bg-garis"><div class="h-full rounded-full" :class="'w-' + STATUS_BULANAN[r.status].w" :style="`width:${persen(r)}%;background:var(--c)`" /></div></td>
                <td class="px-4 py-3"><span class="lencana" :class="'w-' + STATUS_BULANAN[r.status].w">{{ STATUS_BULANAN[r.status].n }}</span>
                  <PhStamp v-if="r.disahkan" :size="16" weight="duotone" class="ml-1 inline text-teks3" :title="`Disahkan ${formatWaktu(r.disahkan_pada)} oleh ${r.disahkan_oleh}`" />
                  <span v-if="r.murojaah && r.alasan_murojaah" class="block text-xs text-teks3">{{ r.alasan_murojaah }}</span></td>
                <td class="px-4 py-3 text-right"><button v-if="bolehMur(r)" class="tombol-garis min-h-[36px] px-3 text-xs" @click="bukaMurojaah(r)"><PhArrowsClockwise :size="14" /> Murojaah</button></td>
              </tr>
            </tbody>
          </table>
          <p v-if="!tampil.length && !memuat" class="py-10 text-center text-sm text-teks3">Tidak ada santri pada saringan ini.</p>
        </div>
        <!-- HP -->
        <ul class="mt-4 space-y-2.5 lg:hidden">
          <li v-for="r in tampil" :key="r.student_id" class="kartu p-3.5">
            <div class="flex items-center gap-2"><span class="min-w-0 flex-1"><b class="block truncate">{{ r.nama }}</b><span class="block truncate text-xs text-teks3">{{ r.halaqah || '–' }} · {{ PROGRAM[r.program] }}</span></span>
              <span class="lencana" :class="'w-' + STATUS_BULANAN[r.status].w">{{ STATUS_BULANAN[r.status].n }}</span><PhStamp v-if="r.disahkan" :size="16" weight="duotone" class="text-teks3" /></div>
            <div class="mt-2 flex items-center gap-2 text-sm tabular-nums"><span class="text-teks3">{{ formatPosisi(r.posisi_awal_hal) }} →</span><b>{{ formatPosisi(r.posisi_akhir_hal) }}</b>
              <span class="ml-auto"><b>{{ r.tambah_hal }}</b><span class="text-teks3"> / {{ r.target_hal }} hal</span></span></div>
            <div class="mt-1.5 h-1.5 overflow-hidden rounded-full bg-garis"><div class="h-full rounded-full" :class="'w-' + STATUS_BULANAN[r.status].w" :style="`width:${persen(r)}%;background:var(--c)`" /></div>
            <p v-if="r.murojaah && r.alasan_murojaah" class="mt-1.5 text-xs text-teks3">Murojaah: {{ r.alasan_murojaah }}</p>
            <button v-if="bolehMur(r)" class="tombol-garis mt-2 min-h-[38px] w-full text-xs" @click="bukaMurojaah(r)"><PhArrowsClockwise :size="14" /> {{ r.murojaah ? 'Ubah Murojaah' : 'Tandai Murojaah' }}</button>
          </li>
          <li v-if="!tampil.length && !memuat" class="py-10 text-center text-sm text-teks3">Tidak ada santri pada saringan ini.</li>
        </ul>
        <p class="mt-3 text-xs text-teks3">Penambahan = posisi sabaq akhir bulan − awal bulan. Target = target pekan (program dan kelas) × pekan efektif bulan itu. Tidak terdata = tidak ada sesi setoran yang diikuti santri.</p>
      </template>

      <!-- ============ USULAN JUZ ============ -->
      <template v-else>
        <div class="flex flex-wrap items-center gap-2">
          <select v-model="saringUsulan" class="isian w-auto" aria-label="Saring status usulan"><option value="menunggu">Menunggu validasi</option><option value="disetujui">Disetujui (90 hari)</option><option value="dikembalikan">Dikembalikan (90 hari)</option><option value="">Semua</option></select>
          <button v-if="tz.hak.muhaffizh || validator" class="tombol-utama" @click="bukaUsul"><PhPaperPlaneTilt :size="20" weight="duotone" /> Usulkan juz</button>
        </div>
        <p class="mt-2 text-sm text-teks3">Usulan dari ceklist dipakai bila juz sudah dikuasai dan diuji di luar sistem. Ujian kenaikan juz yang Tuntas (tahap berikutnya) otomatis menjadi usulan.</p>

        <div v-if="validator && menunggu.length" class="kartu w-pengajuan mt-4 flex flex-wrap items-center gap-2 p-3">
          <label class="flex min-h-[44px] flex-1 items-center gap-3 px-1 text-sm font-semibold"><input type="checkbox" class="h-5 w-5 accent-[#8C6200]" :checked="semuaDipilih" @change="pilihSemua" /> Pilih semua ({{ pilihUsulan.length }}/{{ menunggu.length }})</label>
          <button class="tombol-utama" :disabled="proses || !pilihUsulan.length" @click="putuskan(true)"><PhCheck :size="20" weight="bold" /> Setujui</button>
          <button class="tombol-garis" :disabled="proses || !pilihUsulan.length" @click="lembarTolak = true"><PhX :size="20" /> Kembalikan</button>
        </div>

        <ul class="mt-4 grid gap-2.5 md:grid-cols-2">
          <li v-for="u in usulan" :key="u.id" class="kartu flex gap-3 p-3.5" :class="'w-' + STATUS_USULAN[u.status].w">
            <input v-if="validator && u.status === 'menunggu'" v-model="pilihUsulan" type="checkbox" :value="u.id" class="mt-1 h-5 w-5 shrink-0 accent-[#8C6200]" :aria-label="`Pilih ${u.nama} juz ${u.juz}`" />
            <span class="chip-ikon h-11 w-11 shrink-0 text-base font-extrabold">{{ u.juz }}</span>
            <div class="min-w-0 flex-1">
              <p class="flex flex-wrap items-center gap-1.5"><b>{{ u.nama }}</b><span class="lencana" :class="'w-' + STATUS_USULAN[u.status].w">{{ STATUS_USULAN[u.status].n }}</span></p>
              <p class="text-xs text-teks3">{{ u.halaqah || '–' }} · {{ SUMBER_USULAN[u.sumber] }} · resmi {{ u.total_resmi }} juz</p>
              <p class="text-xs text-teks3">Diusulkan {{ formatWaktu(u.diusulkan_pada) }} oleh {{ u.diusulkan_oleh || '–' }}{{ u.catatan ? ' · ' + u.catatan : '' }}</p>
              <p v-if="u.diputuskan_pada" class="text-xs" :class="u.status === 'dikembalikan' ? 'font-semibold text-merah' : 'text-teks3'">{{ u.status === 'disetujui' ? 'Disetujui' : 'Dikembalikan' }} {{ formatWaktu(u.diputuskan_pada) }} oleh {{ u.diputuskan_oleh }}{{ u.catatan_validator ? ': ' + u.catatan_validator : '' }}</p>
            </div>
          </li>
        </ul>
        <p v-if="!usulan.length" class="kartu mt-4 p-8 text-center text-sm text-teks3">Tidak ada usulan pada saringan ini.</p>
      </template>
    </div>

    <!-- Murojaah -->
    <LembarBawah v-model="lembarMur" :judul="murSantri ? `Murojaah · ${murSantri.nama}` : ''">
      <div v-if="murSantri" class="space-y-3 pb-2">
        <p class="text-sm text-teks2">{{ labelBulan(bulan) }}. Santri berstatus Murojaah sedang fokus mengulang hafalan, sehingga tidak dihitung Tidak tercapai.</p>
        <div><label class="label-isian" for="mr-alasan">Alasan <span class="text-merah">*</span></label>
          <textarea id="mr-alasan" v-model="alasan" rows="3" class="isian" placeholder="Contoh: mengulang juz 28–30 sebelum ujian kenaikan juz" /></div>
        <button class="tombol-utama w-full" :disabled="proses" @click="simpanMur(true)"><PhArrowsClockwise :size="20" weight="duotone" /> {{ murSantri.murojaah ? 'Simpan alasan' : 'Tandai Murojaah' }}</button>
        <button v-if="murSantri.murojaah" class="tombol-garis w-full" :disabled="proses" @click="simpanMur(false)">Cabut tanda Murojaah</button>
      </div>
    </LembarBawah>

    <!-- Kembalikan usulan -->
    <LembarBawah v-model="lembarTolak" judul="Kembalikan usulan">
      <div class="space-y-3 pb-2">
        <p class="text-sm text-teks2">{{ pilihUsulan.length }} usulan dikembalikan ke muhaffizh dengan catatan berikut.</p>
        <textarea v-model="catatanTolak" rows="3" class="isian" placeholder="Contoh: bacaan juz 28 belum lancar, ulangi setoran" aria-label="Alasan pengembalian" />
        <button class="tombol-utama w-full" :disabled="proses" @click="putuskan(false)">Kembalikan</button>
      </div>
    </LembarBawah>

    <!-- Ajukan usulan -->
    <LembarBawah v-model="lembarUsul" judul="Usulkan capaian juz">
      <div class="space-y-3 pb-2">
        <template v-if="!santriUsul">
          <div class="relative"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
            <input v-model="cariSantri" type="search" class="isian pl-11" placeholder="Cari santri" aria-label="Cari santri" /></div>
          <ul class="max-h-[50dvh] divide-y divide-garis overflow-y-auto rounded-xl border border-garis">
            <li v-for="s in calonSantri" :key="s.student_id"><button type="button" class="flex min-h-[52px] w-full items-center gap-3 px-3 text-left text-sm hover:bg-permukaan2" @click="santriUsul = s">
              <span class="min-w-0 flex-1"><b class="block truncate">{{ s.nama }}</b><span class="text-xs text-teks3">{{ s.halaqah || '–' }} · resmi {{ s.total_resmi }} juz{{ s.juz_sedang ? ` · sedang juz ${s.juz_sedang}` : '' }}</span></span>
              <PhUsersThree :size="18" class="text-teks3" /></button></li>
          </ul>
        </template>
        <template v-else>
          <div class="flex items-center gap-2 rounded-xl bg-permukaan2 p-3"><span class="min-w-0 flex-1"><b class="block truncate">{{ santriUsul.nama }}</b><span class="text-xs text-teks3">Resmi: {{ ringkasJuz(santriUsul.juz_resmi) || '–' }}</span></span>
            <button class="tombol-garis min-h-[36px] px-3 text-xs" @click="santriUsul = null; juzUsul = []">Ganti</button></div>
          <p class="label-isian">Pilih juz yang diusulkan</p>
          <GridJuz v-model="juzUsul" :terkunci="[...santriUsul.juz_resmi, ...menungguSantri]" :sedang="santriUsul.juz_sedang" label="Juz yang diusulkan" label-pilih="Diusulkan" label-kunci="Resmi atau menunggu validasi (terkunci)" />
          <p v-if="menungguSantri.length" class="text-xs text-teks3">Juz {{ ringkasJuz(menungguSantri) }} sedang menunggu validasi (ikut terkunci).</p>
          <div><label class="label-isian" for="us-cat">Keterangan</label><input id="us-cat" v-model="catatanUsul" class="isian" placeholder="Contoh: sudah diuji ketua halaqah, lancar" /></div>
          <button class="tombol-utama w-full" :disabled="proses || !juzUsul.length" @click="ajukan"><PhPaperPlaneTilt :size="20" weight="duotone" /> Usulkan {{ juzUsul.length }} juz</button>
        </template>
      </div>
    </LembarBawah>

    <!-- Cetak rekap status bulanan -->
    <DokumenCetak kop="pondok" judul="Rekap Status Capaian Hafalan Bulanan"
      :subjudul="`${labelBulan(bulan)}${halaqah ? ' · ' + (halaqahList.find((h) => h.id === halaqah)?.nama || '') : ''} · ${sudahSah ? 'disahkan' : 'belum disahkan, keadaan ' + formatPanjang(hariIniISO())}`"
      v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap">
      <table class="tabel kecil">
        <colgroup><col style="width:5%"><col style="width:10%"><col style="width:24%"><col style="width:7%"><col style="width:16%"><col style="width:10%"><col style="width:10%"><col style="width:7%"><col style="width:11%"></colgroup>
        <thead><tr><th>No.</th><th>NIS</th><th>Nama</th><th>Kelas</th><th>Halaqah</th><th>Posisi awal</th><th>Posisi akhir</th><th>Tambah/ target</th><th>Status</th></tr></thead>
        <tbody><tr v-for="(r, i) in tampil" :key="r.student_id">
          <td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ r.nis }}</td><td>{{ r.nama }}</td><td class="tengah">{{ r.kelas || r.tingkat }}</td><td>{{ r.halaqah || '–' }}</td>
          <td class="tengah">{{ formatPosisi(r.posisi_awal_hal) }}</td><td class="tengah">{{ formatPosisi(r.posisi_akhir_hal) }}</td><td class="tengah">{{ r.tambah_hal }}/{{ r.target_hal }}</td><td class="tengah">{{ STATUS_BULANAN[r.status].n }}</td></tr></tbody>
      </table>
      <p style="margin-top: 6pt; font-size: 9pt">Tercapai {{ hitungStatus.tercapai }}, Tidak tercapai {{ hitungStatus.tidak_tercapai }}, Murojaah {{ hitungStatus.murojaah }}, Khatam {{ hitungStatus.khatam }}, Tidak terdata {{ hitungStatus.tidak_terdata }} santri. Satuan tambah/target: halaman (1 juz = 20 halaman).</p>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: kepala.jabatan, nama: kepala.nama, niy: kepala.niy }"
          :kanan="muhaffizhCetak || { jabatan: 'Pencetak', nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
      </template>
    </DokumenCetak>
  </div>
</template>
