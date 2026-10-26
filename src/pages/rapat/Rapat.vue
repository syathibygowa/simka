<!-- SIMKA PRO | src/pages/rapat/Rapat.vue | v1.0 | 14.28.0: menu Rapat (jadwal, rapat saya, rekap kehadiran) | 26/10/2026 -->
<script setup>
// Menu Rapat. Semua pegawai melihat rapat yang mengundangnya (dari Agenda jenis Rapat atau dibuat admin), konfirmasi hadir/izin,
// lalu membaca notulen. Admin dan superadmin melihat seluruh rapat, membuat/mengubah rapat, dan membuka Rekap kehadiran rapat.
//   Rapat     : mendatang (dengan status konfirmasi saya) dan yang sudah lewat; saringan jenis dan bulan
//   Rekap     : (admin) rapat dalam periode (hadir/izin/alpa/persentase) dan kehadiran per pegawai; cetak F4 dan Excel
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import * as XLSX from 'xlsx'
import { PhUsersThree, PhPlus, PhCalendarCheck, PhChartBar, PhCaretRight, PhClock, PhMapPin, PhNotebook, PhCheckCircle, PhHourglassMedium, PhPercent, PhPrinter, PhFileXls, PhCaretLeft } from '@phosphor-icons/vue'
import { useRapat } from '@/stores/rapat'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { JENIS_RAPAT, STATUS_RAPAT, KONFIRMASI, KEHADIRAN, jamRapat, persenHadir } from '@/lib/rapat'
import { hariIniISO, formatHari, formatPanjang, formatPendek, BULAN } from '@/lib/tanggal'
import { namaBerkas } from '@/lib/namaBerkas'
import { ambilPenandaTangan } from '@/lib/penandatangan'
import BilahTab from '@/components/BilahTab.vue'
import KartuStatistik from '@/components/KartuStatistik.vue'
import TombolAksi from '@/components/TombolAksi.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import LembarRapat from './LembarRapat.vue'

const route = useRoute(); const router = useRouter(); const rp = useRapat(); const sesi = useSesi(); const ui = useUI()
const admin = computed(() => sesi.isAdmin)
const TAB = computed(() => [
  { k: 'mendatang', n: 'Rapat mendatang', ikon: PhCalendarCheck, w: 'rapat' },
  { k: 'lewat', n: 'Sudah lewat', ikon: PhNotebook, w: 'tatausaha' },
  ...(admin.value ? [{ k: 'rekap', n: 'Rekap kehadiran', ikon: PhChartBar, w: 'rekap' }] : []),
])
const aktif = computed(() => (TAB.value.some((t) => t.k === route.query.tab) ? route.query.tab : 'mendatang'))
const pindah = (k) => router.replace({ query: { tab: k } })
const hari = hariIniISO()
const geser = (iso, n) => { const d = new Date(iso + 'T00:00:00Z'); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10) }
const jenis = ref('')
onMounted(() => rp.muat(geser(hari, -120), geser(hari, 60)).catch((e) => ui.toast(e.message, 'galat')))
const saring = (d) => d.filter((m) => !jenis.value || m.jenis === jenis.value)
const mendatang = computed(() => saring(rp.daftar.filter((m) => m.tanggal >= hari && m.status !== 'selesai')).sort((a, b) => a.tanggal.localeCompare(b.tanggal) || String(a.jam_mulai).localeCompare(String(b.jam_mulai))))
const lewat = computed(() => saring(rp.daftar.filter((m) => m.tanggal < hari || m.status === 'selesai')))
const statistik = computed(() => {
  const n = rp.memuat && !rp.daftar.length ? '…' : null
  const minggu = mendatang.value.filter((m) => m.tanggal <= geser(hari, 7) && m.status !== 'batal')
  const belumKonf = mendatang.value.filter((m) => m.saya?.konfirmasi === 'menunggu' && m.status !== 'batal')
  const ls = lewat.value.filter((m) => m.status === 'selesai'); const tot = ls.reduce((a, m) => a + m.peserta, 0); const hd = ls.reduce((a, m) => a + m.hadir, 0)
  return [
    { judul: 'Rapat pekan ini', nilai: n ?? minggu.length, ikon: PhCalendarCheck, warna: 'rapat', ket: '7 hari ke depan' },
    { judul: admin.value ? 'Menunggu konfirmasi' : 'Perlu konfirmasi saya', nilai: n ?? (admin.value ? mendatang.value.reduce((a, m) => a + Math.max(0, m.peserta - m.konf_hadir - m.konf_izin), 0) : belumKonf.length), ikon: PhHourglassMedium, warna: 'pengajuan', ket: admin.value ? 'Undangan belum dijawab' : 'Rapat yang belum Anda jawab' },
    { judul: 'Notulen tersedia', nilai: n ?? lewat.value.filter((m) => m.ada_notulen).length, ikon: PhNotebook, warna: 'tatausaha', ket: '4 bulan terakhir' },
    { judul: 'Kehadiran rapat', nilai: n ?? (tot ? persenHadir(hd, tot) : '–'), satuan: tot ? '%' : '', ikon: PhPercent, warna: 'presensi', ket: `${ls.length} rapat selesai` },
  ]
})
const buka = (m) => router.push(`/rapat/${m.id}`)
const lembar = ref(false)
const selesaiBuat = (id) => { rp.muat(geser(hari, -120), geser(hari, 60)); if (id) router.push(`/rapat/${id}`) }

// ---------- Rekap (admin) ----------
const bulanAwal = hari.slice(0, 7); const rMulai = ref(bulanAwal + '-01'); const rSelesai = ref(hari); const R = ref(null); const memuatR = ref(false); const pratinjau = ref(false)
const direktur = ref({ jabatan: 'Direktur', nama: '', niy: '' })
async function muatRekap() {
  memuatR.value = true
  try { R.value = await rp.rekap(rMulai.value, rSelesai.value, jenis.value || null) } catch (e) { ui.toast(e.message, 'galat') } finally { memuatR.value = false }
}
watch([aktif, rMulai, rSelesai, jenis], () => { if (aktif.value === 'rekap') muatRekap() }, { immediate: true })
onMounted(() => ambilPenandaTangan('Direktur').then((d) => { direktur.value = d }).catch(() => {}))
function pilihBulan(n) { const [y, m] = rMulai.value.slice(0, 7).split('-').map(Number); const d = new Date(Date.UTC(y, m - 1 + n, 1)); const a = d.toISOString().slice(0, 10)
  const e = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 0)).toISOString().slice(0, 10); rMulai.value = a; rSelesai.value = e > hari ? hari : e }
const labelBulan = computed(() => { const [y, m] = rMulai.value.slice(0, 7).split('-').map(Number); return `${BULAN[m - 1]} ${y}` })
const subjudul = computed(() => `Periode ${formatPanjang(rMulai.value)} s.d. ${formatPanjang(rSelesai.value)}${jenis.value ? ' · ' + JENIS_RAPAT[jenis.value].n : ''}`)
const pegawaiR = computed(() => (R.value?.pegawai || []).map((p) => ({ ...p, persen: p.undangan ? persenHadir(p.hadir, p.undangan) : null })))
function ekspor() {
  const wb = XLSX.utils.book_new()
  const a = [['No.', 'Tanggal', 'Rapat', 'Jenis', 'Bidang', 'Peserta', 'Hadir', 'Terlambat', 'Izin/sakit/dinas', 'Tanpa keterangan', 'Kehadiran (%)'],
    ...(R.value?.rapat || []).map((m, i) => [i + 1, formatPendek(m.tanggal), m.judul, JENIS_RAPAT[m.jenis]?.n, m.unit || '', m.peserta, m.hadir, m.terlambat, m.izin, m.alpa, persenHadir(m.hadir, m.peserta)])]
  XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet(a), 'Rapat')
  const b = [['No.', 'NIY', 'Nama', 'Bidang', 'Undangan', 'Hadir', 'Terlambat', 'Izin/sakit/dinas', 'Tanpa keterangan', 'Kehadiran (%)'],
    ...pegawaiR.value.map((p, i) => [i + 1, p.niy || '', p.nama, p.unit || '', p.undangan, p.hadir, p.terlambat, p.izin, p.alpa, p.persen ?? ''])]
  XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet(b), 'Per pegawai')
  XLSX.writeFile(wb, `${namaBerkas('Rekap Kehadiran Rapat', subjudul.value)}.xlsx`)
}
</script>
<template>
  <div class="w-rapat">
    <div class="mb-4 hidden items-center gap-3 lg:flex">
      <span class="chip-ikon h-12 w-12"><PhUsersThree :size="28" weight="duotone" /></span>
      <div class="flex-1"><h2 class="text-lg font-bold">Rapat</h2>
        <p class="text-sm text-teks3">Undangan, konfirmasi kehadiran, presensi, dan notulen rapat pimpinan, bidang, rutin, koordinasi, serta tim kerja.</p></div>
      <button v-if="admin" class="tombol-utama" @click="lembar = true"><PhPlus :size="20" weight="bold" /> Rapat baru</button>
    </div>
    <BilahTab class="mb-4" :tab="TAB" :model-value="aktif" label="Bagian rapat" @update:model-value="pindah" />

    <div class="-mx-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-2 sm:overflow-visible sm:px-0 xl:grid-cols-4">
      <KartuStatistik v-for="k in statistik" :key="k.judul" class="w-[46%] shrink-0 snap-start sm:w-auto" :judul="k.judul" :nilai="k.nilai" :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket" :satuan="k.satuan" />
    </div>

    <div class="my-4 flex flex-wrap gap-1.5" role="radiogroup" aria-label="Saring jenis rapat">
      <button type="button" role="radio" :aria-checked="!jenis" :class="['min-h-[38px] rounded-full border px-3 text-sm font-semibold', !jenis ? 'border-transparent bg-[#C7332F] text-white' : 'border-garis text-teks2']" @click="jenis = ''">Semua jenis</button>
      <button v-for="(v, k) in JENIS_RAPAT" :key="k" type="button" role="radio" :aria-checked="jenis === k" :class="['min-h-[38px] rounded-full border px-3 text-sm font-semibold', 'w-' + v.w, jenis === k ? 'text-teks' : 'border-garis text-teks2']"
        :style="jenis === k ? 'border-color: var(--c); background: color-mix(in srgb, var(--c) 16%, transparent)' : ''" @click="jenis = k">{{ v.n }}</button>
    </div>

    <!-- Daftar rapat -->
    <template v-if="aktif !== 'rekap'">
      <p v-if="rp.memuat && !rp.daftar.length" class="py-10 text-center text-teks3">Memuat rapat…</p>
      <ul v-else-if="(aktif === 'mendatang' ? mendatang : lewat).length" class="grid gap-3 lg:grid-cols-2">
        <li v-for="m in (aktif === 'mendatang' ? mendatang : lewat)" :key="m.id">
          <button type="button" :class="['kartu flex w-full items-start gap-3 p-4 text-left transition hover:shadow-lg', 'w-' + JENIS_RAPAT[m.jenis]?.w, m.status === 'batal' && 'opacity-60']" @click="buka(m)">
            <span class="grid w-14 shrink-0 place-items-center rounded-2xl py-2 text-center" style="background: color-mix(in srgb, var(--c) 14%, transparent); color: var(--c)">
              <span class="text-xl font-extrabold leading-none">{{ m.tanggal.slice(8, 10) }}</span><span class="text-[11px] font-bold uppercase">{{ BULAN[Number(m.tanggal.slice(5, 7)) - 1].slice(0, 3) }}</span></span>
            <span class="min-w-0 flex-1">
              <span class="block font-bold leading-snug">{{ m.judul }}</span>
              <span class="mt-0.5 flex flex-wrap gap-x-3 text-xs text-teks3"><span>{{ formatHari(m.tanggal) }}</span><span v-if="jamRapat(m)" class="flex items-center gap-1"><PhClock :size="13" />{{ jamRapat(m) }}</span>
                <span v-if="m.lokasi" class="flex items-center gap-1"><PhMapPin :size="13" />{{ m.lokasi }}</span></span>
              <span class="mt-1.5 flex flex-wrap items-center gap-1.5 text-xs">
                <span class="lencana">{{ JENIS_RAPAT[m.jenis]?.n }}</span>
                <span v-if="m.status !== 'dijadwalkan'" :class="['lencana', 'w-' + STATUS_RAPAT[m.status].w]">{{ STATUS_RAPAT[m.status].n }}</span>
                <span v-if="m.saya && m.status === 'dijadwalkan'" :class="['lencana', 'w-' + KONFIRMASI[m.saya.konfirmasi].w]">Saya: {{ KONFIRMASI[m.saya.konfirmasi].n }}</span>
                <span v-if="m.saya?.kehadiran" :class="['lencana', 'w-' + KEHADIRAN[m.saya.kehadiran].w]">Saya: {{ KEHADIRAN[m.saya.kehadiran].n }}</span>
                <span v-if="m.ada_notulen" class="lencana w-tatausaha"><PhNotebook :size="12" weight="fill" /> Notulen</span>
                <span class="text-teks3">{{ m.status === 'selesai' || m.tercatat ? `hadir ${m.hadir}/${m.peserta} (${persenHadir(m.hadir, m.peserta)}%)` : `${m.peserta} peserta · ${m.konf_hadir} akan hadir · ${m.konf_izin} izin` }}</span>
              </span>
              <span v-if="m.ringkasan_sasaran" class="mt-1 block truncate text-xs text-teks3">Peserta: {{ m.ringkasan_sasaran }}</span>
            </span>
            <PhCaretRight :size="18" class="mt-1 shrink-0 text-teks3" />
          </button>
        </li>
      </ul>
      <div v-else class="kartu p-8 text-center">
        <PhUsersThree :size="40" weight="duotone" class="mx-auto text-teks3" />
        <p class="mt-2 font-semibold">{{ aktif === 'mendatang' ? 'Belum ada rapat mendatang.' : 'Belum ada rapat yang lewat.' }}</p>
        <p class="text-sm text-teks3">Rapat yang dijadwalkan di Agenda (jenis Rapat) tampil otomatis 14 hari sebelumnya{{ admin ? '; rapat lain dapat dibuat dengan tombol Rapat baru' : '' }}.</p>
      </div>
    </template>

    <!-- Rekap (admin) -->
    <template v-else>
      <section class="kartu flex flex-wrap items-center gap-2 p-3">
        <button class="tombol-ikon" aria-label="Bulan sebelumnya" @click="pilihBulan(-1)"><PhCaretLeft :size="20" /></button>
        <p class="min-w-[140px] text-center font-bold">{{ labelBulan }}</p>
        <button class="tombol-ikon" aria-label="Bulan berikutnya" @click="pilihBulan(1)"><PhCaretRight :size="20" /></button>
        <span class="text-xs text-teks3">{{ formatPendek(rMulai) }} – {{ formatPendek(rSelesai) }}</span>
        <span class="flex-1" />
        <button class="w-pengajuan tombol-garis px-4 text-sm" :disabled="!R?.rapat?.length" @click="pratinjau = true"><PhPrinter :size="20" weight="duotone" style="color: var(--c)" /> Cetak rekap</button>
        <button class="w-gaji tombol-garis px-4 text-sm" :disabled="!R?.rapat?.length" @click="ekspor"><PhFileXls :size="20" weight="duotone" style="color: var(--c)" /> Ekspor</button>
      </section>
      <p v-if="memuatR" class="py-10 text-center text-teks3">Memuat rekap…</p>
      <template v-else-if="R">
        <section class="kartu mt-3 overflow-x-auto p-4">
          <h3 class="mb-2 font-bold">Rapat dalam periode</h3>
          <table class="w-full min-w-[640px] text-sm">
            <thead><tr class="border-b border-garis text-left text-xs text-teks3"><th class="py-2 pr-2">Tanggal</th><th class="px-2">Rapat</th><th class="px-2">Jenis</th><th class="px-2 text-center">Peserta</th><th class="px-2 text-center">Hadir</th><th class="px-2 text-center">Izin</th><th class="px-2 text-center">Alpa</th><th class="pl-2 text-center">%</th></tr></thead>
            <tbody><tr v-for="m in R.rapat" :key="m.id" class="cursor-pointer border-b border-garis/60 hover:bg-permukaan2" @click="buka(m)">
              <td class="py-2 pr-2 tabular-nums">{{ formatPendek(m.tanggal) }}</td><td class="px-2 font-semibold">{{ m.judul }}</td><td class="px-2">{{ JENIS_RAPAT[m.jenis]?.n }}</td>
              <td class="px-2 text-center tabular-nums">{{ m.peserta }}</td><td class="px-2 text-center tabular-nums">{{ m.hadir }}</td><td class="px-2 text-center tabular-nums">{{ m.izin }}</td><td class="px-2 text-center tabular-nums">{{ m.alpa }}</td>
              <td class="pl-2 text-center font-bold tabular-nums">{{ persenHadir(m.hadir, m.peserta) }}</td></tr>
              <tr v-if="!R.rapat.length"><td colspan="8" class="py-6 text-center text-teks3">Tidak ada rapat pada periode ini.</td></tr></tbody>
          </table>
        </section>
        <section class="kartu mt-3 overflow-x-auto p-4">
          <h3 class="mb-2 font-bold">Kehadiran per pegawai</h3>
          <table class="w-full min-w-[640px] text-sm">
            <thead><tr class="border-b border-garis text-left text-xs text-teks3"><th class="py-2 pr-2">Nama</th><th class="px-2">Bidang</th><th class="px-2 text-center">Undangan</th><th class="px-2 text-center">Hadir</th><th class="px-2 text-center">Terlambat</th><th class="px-2 text-center">Izin</th><th class="px-2 text-center">Alpa</th><th class="pl-2 text-center">%</th></tr></thead>
            <tbody><tr v-for="p in pegawaiR" :key="p.employee_id" class="border-b border-garis/60">
              <td class="py-2 pr-2 font-semibold">{{ p.nama }}</td><td class="px-2 text-teks2">{{ p.unit || '–' }}</td><td class="px-2 text-center tabular-nums">{{ p.undangan }}</td><td class="px-2 text-center tabular-nums">{{ p.hadir }}</td>
              <td class="px-2 text-center tabular-nums">{{ p.terlambat }}</td><td class="px-2 text-center tabular-nums">{{ p.izin }}</td><td class="px-2 text-center tabular-nums">{{ p.alpa }}</td>
              <td :class="['pl-2 text-center font-bold tabular-nums', p.persen != null && p.persen < 75 && 'persen-ambang']">{{ p.persen ?? '–' }}</td></tr></tbody>
          </table>
        </section>
      </template>

      <DokumenCetak judul="Rekap Kehadiran Rapat" :subjudul="subjudul" mendatar v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap">
        <p style="font-weight: 700; margin: 4pt 0">A. Rapat dalam periode</p>
        <table class="tabel">
          <colgroup><col style="width:4%"><col style="width:10%"><col style="width:34%"><col style="width:14%"><col style="width:7%"><col style="width:7%"><col style="width:8%"><col style="width:8%"><col style="width:8%"></colgroup>
          <thead><tr><th>No.</th><th>Tanggal</th><th>Rapat</th><th>Jenis</th><th>Peserta</th><th>Hadir</th><th>Izin/sakit</th><th>Tanpa ket.</th><th>Kehadiran</th></tr></thead>
          <tbody><tr v-for="(m, i) in R?.rapat || []" :key="m.id"><td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ formatPendek(m.tanggal) }}</td><td>{{ m.judul }}</td><td>{{ JENIS_RAPAT[m.jenis]?.n }}</td>
            <td class="tengah">{{ m.peserta }}</td><td class="tengah">{{ m.hadir }}</td><td class="tengah">{{ m.izin }}</td><td class="tengah">{{ m.alpa }}</td><td class="tengah">{{ persenHadir(m.hadir, m.peserta) }}%</td></tr></tbody>
        </table>
        <p style="font-weight: 700; margin: 8pt 0 4pt">B. Kehadiran per pegawai</p>
        <table class="tabel">
          <colgroup><col style="width:4%"><col style="width:12%"><col style="width:28%"><col style="width:20%"><col style="width:7%"><col style="width:7%"><col style="width:7%"><col style="width:7%"><col style="width:8%"></colgroup>
          <thead><tr><th>No.</th><th>NIY</th><th>Nama</th><th>Bidang</th><th>Undangan</th><th>Hadir</th><th>Izin/sakit</th><th>Tanpa ket.</th><th>Kehadiran</th></tr></thead>
          <tbody><tr v-for="(p, i) in pegawaiR" :key="p.employee_id"><td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ p.niy || '–' }}</td><td>{{ p.nama }}</td><td>{{ p.unit || '–' }}</td>
            <td class="tengah">{{ p.undangan }}</td><td class="tengah">{{ p.hadir }}</td><td class="tengah">{{ p.izin }}</td><td class="tengah">{{ p.alpa }}</td><td class="tengah">{{ p.persen != null ? p.persen + '%' : '–' }}</td></tr></tbody>
        </table>
        <template #ttd>
          <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan || 'Direktur', nama: direktur.nama, niy: direktur.niy }"
            :kanan="{ jabatan: 'Yang membuat,', nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
        </template>
      </DokumenCetak>
    </template>

    <TombolAksi v-if="admin" class="lg:hidden" label="Rapat" :ikon="PhPlus" warna="rapat" @klik="lembar = true" />
    <LembarRapat v-model="lembar" @selesai="selesaiBuat" />
  </div>
</template>
