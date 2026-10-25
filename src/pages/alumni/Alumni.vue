<!-- SIMKA PRO | src/pages/alumni/Alumni.vue | v1.0 | 14.25.0: menu Alumni (daftar, rencana lanjut studi, buku alumni) | 25/10/2026 -->
<script setup>
// Menu Alumni (khusus admin dan superadmin). Alumni = santri berstatus Lulus; santri yang diluluskan di Naik Kelas
// otomatis pindah ke sini (tidak lagi tampil di Data Santri aktif), dan seluruh catatan semasa aktif tetap terbaca.
//   Daftar alumni : kartu berfoto, saringan tahun lulus, jenjang, rencana, kelengkapan profil; buka profil (CV)
//   Rencana studi : rekap rencana lanjut studi (kuliah/pesantren/pengabdian; negeri/swasta/luar negeri; status), cetak F4 dan Excel
//   Buku alumni   : sampul, daftar isi, dan satu halaman profil (CV berfoto) per alumni — dicetak kolektif lalu dijilid
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import * as XLSX from 'xlsx'
import {
  PhGraduationCap, PhUsersThree, PhBuildings, PhCheckCircle, PhWarningCircle, PhMagnifyingGlass, PhCaretRight, PhBookBookmark,
  PhChartBar, PhPrinter, PhFileXls, PhBookOpen, PhStudent,
} from '@phosphor-icons/vue'
import { useAlumni } from '@/stores/alumni'
import { useSantri } from '@/stores/santri'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { useLembaga } from '@/stores/lembaga'
import { LANJUT, JENIS_PT, STATUS_DAFTAR, ringkasStudi, profilLengkap } from '@/lib/alumni'
import { JENJANG, JENJANG_PENDEK, inisial } from '@/lib/santri'
import { namaBerkas } from '@/lib/namaBerkas'
import { ambilPenandaTangan } from '@/lib/penandatangan'
import BilahTab from '@/components/BilahTab.vue'
import KartuStatistik from '@/components/KartuStatistik.vue'
import SaringCorong from '@/components/SaringCorong.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import LembarRapor from '@/components/cetak/rapor/LembarRapor.vue'
import HalRapor from '@/components/cetak/rapor/HalRapor.vue'
import CVAlumni from './CVAlumni.vue'

const props = defineProps({ tab: { type: String, default: '' } })
const al = useAlumni(); const san = useSantri(); const sesi = useSesi(); const ui = useUI(); const lembaga = useLembaga(); const router = useRouter()
const TAB = [
  { k: 'daftar', n: 'Daftar alumni', ikon: PhUsersThree, w: 'alumni' },
  { k: 'studi', n: 'Rencana studi', ikon: PhChartBar, w: 'rapor' },
  { k: 'buku', n: 'Buku alumni', ikon: PhBookBookmark, w: 'prestasi' },
]
const aktif = computed(() => (TAB.some((t) => t.k === props.tab) ? props.tab : 'daftar'))
const direktur = ref({ jabatan: 'Direktur', nama: '', niy: '' })
onMounted(() => {
  al.muat(true).catch((e) => ui.toast(e.message, 'galat'))
  lembaga.muat(); ambilPenandaTangan('Direktur').then((d) => { direktur.value = d }).catch(() => {})
})

// ---------- Saringan ----------
const daftarTahun = computed(() => [...new Set(al.daftar.map((x) => x.tahun_lulus).filter(Boolean))].sort((a, b) => b - a))
const tahun = ref(''); const jenjang = ref(''); const lanjut = ref(''); const lengkap = ref(''); const cari = ref('')
watch(daftarTahun, (d) => { if (!tahun.value && d.length) tahun.value = String(d[0]) }, { immediate: true })
const jumlahSaring = computed(() => [jenjang.value, lanjut.value, lengkap.value].filter(Boolean).length)
const ringkasSaring = computed(() => [tahun.value ? `Lulusan ${tahun.value}` : 'Semua angkatan', jenjang.value && JENJANG_PENDEK[jenjang.value],
  lanjut.value && (LANJUT[lanjut.value]?.n || 'Belum diisi'), lengkap.value === 'belum' ? 'Profil belum lengkap' : lengkap.value === 'lengkap' ? 'Profil lengkap' : ''].filter(Boolean).join(' · '))
function aturUlang() { jenjang.value = ''; lanjut.value = ''; lengkap.value = '' }
const tampil = computed(() => {
  const q = cari.value.toLowerCase().trim()
  return al.daftar.filter((x) => (!tahun.value || String(x.tahun_lulus) === tahun.value) && (!jenjang.value || x.jenjang === jenjang.value)
    && (!lanjut.value || (lanjut.value === '-' ? !x.alumni?.lanjut : x.alumni?.lanjut === lanjut.value))
    && (!lengkap.value || (lengkap.value === 'lengkap') === profilLengkap(x.alumni))
    && (!q || `${x.nama} ${x.nis} ${x.alumni?.kampus || ''} ${x.alumni?.prodi || ''}`.toLowerCase().includes(q)))
    .sort((a, b) => String(a.jenjang).localeCompare(String(b.jenjang)) || String(a.kelas).localeCompare(String(b.kelas)) || a.nama.localeCompare(b.nama))
})
const statistik = computed(() => {
  const d = tampil.value; const n = al.memuat && !al.dimuat ? '…' : null
  return [
    { judul: 'Alumni', nilai: n ?? d.length, ikon: PhGraduationCap, warna: 'alumni', ket: tahun.value ? `Lulusan ${tahun.value}` : `${al.daftar.length} alumni tercatat` },
    { judul: 'Melanjutkan kuliah', nilai: n ?? d.filter((x) => x.alumni?.lanjut === 'kuliah').length, ikon: PhBuildings, warna: 'rapor', ket: 'Rencana kuliah' },
    { judul: 'Sudah diterima', nilai: n ?? d.filter((x) => ['diterima', 'berjalan'].includes(x.alumni?.status_daftar)).length, ikon: PhCheckCircle, warna: 'presensi', ket: 'Diterima atau sedang menjalani' },
    { judul: 'Profil belum lengkap', nilai: n ?? d.filter((x) => !profilLengkap(x.alumni)).length, ikon: PhWarningCircle, warna: 'laporan', ket: 'Rencana dan tujuan belum diisi' },
    { judul: 'Rata-rata hafalan', nilai: n ?? (d.length ? (d.reduce((s, x) => s + Number(x.total_juz || 0), 0) / d.length).toFixed(1).replace('.', ',') : 0), satuan: 'juz', ikon: PhBookOpen, warna: 'tahfizh', ket: 'Hafalan resmi' },
  ]
})

// ---------- Foto ----------
const foto = ref({})
watch(tampil, async (d) => {
  for (const x of d.slice(0, 60)) if (x.foto_id && foto.value[x.id] === undefined) {
    foto.value = { ...foto.value, [x.id]: null }
    san.urlFoto({ id: x.id, foto_id: x.foto_id }).then((u) => { foto.value = { ...foto.value, [x.id]: u } }).catch(() => {})
  }
}, { immediate: true })

// ---------- Rencana studi ----------
const rekapLanjut = computed(() => [...Object.entries(LANJUT).map(([k, v]) => ({ k, n: v.n, w: v.w, j: tampil.value.filter((x) => x.alumni?.lanjut === k).length })),
  { k: '-', n: 'Belum diisi', w: 'audit', j: tampil.value.filter((x) => !x.alumni?.lanjut).length }].filter((x) => x.j))
const rekapPT = computed(() => Object.entries(JENIS_PT).map(([k, n]) => ({ k, n, j: tampil.value.filter((x) => x.alumni?.lanjut === 'kuliah' && x.alumni?.jenis_pt === k).length })).filter((x) => x.j))
const rekapKampus = computed(() => {
  const m = new Map()
  for (const x of tampil.value) if (x.alumni?.kampus) { const k = x.alumni.kampus; m.set(k, { kampus: k, j: (m.get(k)?.j || 0) + 1, diterima: (m.get(k)?.diterima || 0) + (['diterima', 'berjalan'].includes(x.alumni.status_daftar) ? 1 : 0) }) }
  return [...m.values()].sort((a, b) => b.j - a.j || a.kampus.localeCompare(b.kampus))
})
const maksLanjut = computed(() => Math.max(1, ...rekapLanjut.value.map((x) => x.j)))
const subjudul = computed(() => [tahun.value ? `Lulusan Tahun ${tahun.value}` : 'Seluruh angkatan', jenjang.value && JENJANG[jenjang.value], lanjut.value && (LANJUT[lanjut.value]?.n || 'Rencana belum diisi')].filter(Boolean).join(' · '))
const pratinjauStudi = ref(false)
function eksporExcel() {
  const kolom = ['No.', 'NIS', 'Nama', 'JK', 'Jenjang', 'Kelas akhir', 'Tahun lulus', 'Hafalan (juz)', 'Rencana', 'Jenis PT', 'Kampus/lembaga', 'Fakultas', 'Program studi', 'Kota', 'Negara', 'Jalur', 'Status', 'Tahun mulai', 'Beasiswa', 'Nomor HP', 'E-mail', 'Cita-cita']
  const baris = tampil.value.map((x, i) => { const a = x.alumni || {}
    return [i + 1, x.nis, x.nama, x.jenis_kelamin, JENJANG_PENDEK[x.jenjang] || '', x.kelas || '', x.tahun_lulus || '', Number(x.total_juz || 0), LANJUT[a.lanjut]?.n || '', JENIS_PT[a.jenis_pt] || '',
      a.kampus || '', a.fakultas || '', a.prodi || '', a.kota || '', a.negara || '', a.jalur || '', STATUS_DAFTAR[a.status_daftar]?.n || '', a.tahun_mulai || '', a.beasiswa || '', a.hp || '', a.email || '', a.cita_cita || ''] })
  const ws = XLSX.utils.aoa_to_sheet([kolom, ...baris])
  ws['!cols'] = kolom.map((k, i) => ({ wch: Math.min(40, Math.max(k.length, ...baris.map((r) => String(r[i] ?? '').length)) + 2) }))
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Alumni')
  XLSX.writeFile(wb, `${namaBerkas('Alumni', 'Rencana Lanjut Studi', tahun.value ? 'Lulusan ' + tahun.value : 'Semua angkatan')}.xlsx`)
}

// ---------- Buku alumni ----------
const buku = ref([]); const fotoBuku = ref({}); const menyusun = ref(''); const pratinjauBuku = ref(false)
const logo = computed(() => lembaga.urlLogo('logo:pondok'))
const namaPondok = computed(() => lembaga.identitas?.nama_lengkap || 'Pondok Pesantren Tahfizhul Quran Imam Asy-Syathiby')
const jenjangBuku = computed(() => (jenjang.value ? JENJANG[jenjang.value] : [...new Set(tampil.value.map((x) => JENJANG[x.jenjang]).filter(Boolean))].join(' dan ')))
async function susunBuku() {
  const ids = tampil.value.map((x) => x.id)
  if (!ids.length) return ui.toast('Tidak ada alumni pada saringan ini.', 'galat')
  menyusun.value = `Memuat profil 0/${ids.length}…`
  try {
    buku.value = await al.profilBanyak(ids, (a, b) => { menyusun.value = `Memuat profil ${a}/${b}…` })
    menyusun.value = 'Memuat pas foto…'; const peta = {}
    const ber = tampil.value.filter((x) => x.foto_id)
    for (let i = 0; i < ber.length; i += 8) await Promise.all(ber.slice(i, i + 8).map(async (x) => { peta[x.id] = await san.urlFoto({ id: x.id, foto_id: x.foto_id }).catch(() => null) }))
    fotoBuku.value = peta; pratinjauBuku.value = true
  } catch (e) { ui.toast(e.message, 'galat') } finally { menyusun.value = '' }
}
const tentangBuku = computed(() => `${tampil.value.length} alumni · ${tampil.value.length + 2} halaman (sampul, daftar isi, dan satu halaman profil per alumni)`)
</script>
<template>
  <div class="w-alumni">
    <div class="mb-4 hidden items-center gap-3 lg:flex">
      <span class="chip-ikon h-12 w-12"><PhGraduationCap :size="28" weight="duotone" /></span>
      <div class="flex-1"><h2 class="text-lg font-bold">Alumni</h2>
        <p class="text-sm text-teks3">Santri yang telah lulus beserta profil (CV), rencana lanjut studi, dan buku alumni. Seluruh catatan semasa aktif tetap terbaca.</p></div>
    </div>
    <BilahTab class="mb-4" :tab="TAB" :model-value="aktif" label="Bagian alumni" @update:model-value="(k) => router.replace(`/alumni/${k}`)" />

    <div class="-mx-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-3 sm:overflow-visible sm:px-0 xl:grid-cols-5">
      <KartuStatistik v-for="k in statistik" :key="k.judul" class="w-[46%] shrink-0 snap-start sm:w-auto" :judul="k.judul" :nilai="k.nilai" :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket" :satuan="k.satuan" />
    </div>

    <SaringCorong class="mt-4" :jumlah="jumlahSaring" :ringkasan="ringkasSaring" judul="Saring alumni" bisa-atur-ulang @atur-ulang="aturUlang">
      <template #cari><div class="relative"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
        <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari nama, NIS, kampus, prodi" aria-label="Cari alumni" /></div></template>
      <div><label class="label-isian" for="al-tahun">Tahun lulus</label>
        <select id="al-tahun" v-model="tahun" class="isian w-auto max-w-full"><option value="">Semua angkatan</option><option v-for="t in daftarTahun" :key="t" :value="String(t)">{{ t }}</option></select></div>
      <div><label class="label-isian" for="al-jenjang">Jenjang</label>
        <select id="al-jenjang" v-model="jenjang" class="isian w-auto max-w-full"><option value="">Semua jenjang</option><option value="wustha">Kesetaraan Wustha</option><option value="sma">SMA</option></select></div>
      <div><label class="label-isian" for="al-lanjut">Rencana</label>
        <select id="al-lanjut" v-model="lanjut" class="isian w-auto max-w-full"><option value="">Semua rencana</option><option v-for="(v, k) in LANJUT" :key="k" :value="k">{{ v.n }}</option><option value="-">Belum diisi</option></select></div>
      <div><label class="label-isian" for="al-lengkap">Profil</label>
        <select id="al-lengkap" v-model="lengkap" class="isian w-auto max-w-full"><option value="">Semua</option><option value="lengkap">Lengkap</option><option value="belum">Belum lengkap</option></select></div>
    </SaringCorong>

    <!-- Daftar alumni -->
    <template v-if="aktif === 'daftar'">
      <p v-if="al.memuat && !al.dimuat" class="py-10 text-center text-teks3">Memuat alumni…</p>
      <ul v-else-if="tampil.length" class="mt-4 grid gap-3 md:grid-cols-2 xl:grid-cols-3">
        <li v-for="x in tampil" :key="x.id">
          <router-link :to="`/alumni/profil/${x.id}`" class="kartu flex min-h-[96px] items-start gap-3 p-4 hover:bg-permukaan2">
            <span class="w-alumni grid h-16 w-12 shrink-0 place-items-center overflow-hidden rounded-xl font-bold" style="background: color-mix(in srgb, var(--c) 16%, transparent); color: var(--c)">
              <img v-if="foto[x.id]" :src="foto[x.id]" alt="" class="h-full w-full object-cover" /><template v-else>{{ inisial(x.nama) }}</template></span>
            <span class="min-w-0 flex-1">
              <b class="block truncate">{{ x.nama }}</b>
              <span class="block text-xs text-teks3">{{ x.nis }} · {{ JENJANG_PENDEK[x.jenjang] }} {{ x.kelas ? '· Kelas ' + x.kelas : '' }} · Lulus {{ x.tahun_lulus || '–' }}</span>
              <span class="mt-1 block truncate text-sm text-teks2">{{ ringkasStudi(x.alumni) || 'Rencana lanjut studi belum diisi' }}</span>
              <span class="mt-1.5 flex flex-wrap gap-1.5 text-xs">
                <span class="lencana w-tahfizh">{{ x.total_juz || 0 }} juz</span>
                <span v-if="x.alumni?.status_daftar" :class="['lencana', 'w-' + STATUS_DAFTAR[x.alumni.status_daftar]?.w]">{{ STATUS_DAFTAR[x.alumni.status_daftar]?.n }}</span>
                <span v-if="!profilLengkap(x.alumni)" class="lencana w-laporan">Belum lengkap</span>
              </span>
            </span>
            <PhCaretRight :size="18" class="mt-1 shrink-0 text-teks3" />
          </router-link>
        </li>
      </ul>
      <div v-else class="kartu mt-4 p-8 text-center">
        <PhGraduationCap :size="40" weight="duotone" class="mx-auto text-teks3" />
        <p class="mt-2 font-semibold">Belum ada alumni pada saringan ini.</p>
        <p class="text-sm text-teks3">Santri tampil di sini setelah diluluskan di menu Naik Kelas atau status santrinya diubah menjadi Lulus.</p>
      </div>
    </template>

    <!-- Rencana studi -->
    <template v-else-if="aktif === 'studi'">
      <div class="-mx-4 my-4 flex gap-2 overflow-x-auto px-4 pb-1 lg:mx-0 lg:px-0">
        <button class="w-pengajuan tombol-garis shrink-0 px-4 text-sm" :disabled="!tampil.length" @click="pratinjauStudi = true"><PhPrinter :size="20" weight="duotone" style="color: var(--c)" /> Cetak Rekap</button>
        <button class="w-gaji tombol-garis shrink-0 px-4 text-sm" :disabled="!tampil.length" @click="eksporExcel"><PhFileXls :size="20" weight="duotone" style="color: var(--c)" /> Ekspor</button>
      </div>
      <div class="grid gap-3 lg:grid-cols-3">
        <section class="kartu p-4">
          <h3 class="mb-3 font-bold">Rencana setelah lulus</h3>
          <ul class="space-y-2.5">
            <li v-for="r in rekapLanjut" :key="r.k" :class="'w-' + r.w">
              <div class="flex justify-between text-sm"><span class="font-semibold">{{ r.n }}</span><span class="tabular-nums">{{ r.j }}</span></div>
              <div class="mt-1 h-2.5 overflow-hidden rounded-full bg-permukaan2"><div class="h-full rounded-full" :style="{ width: (r.j / maksLanjut * 100) + '%', background: 'var(--c)' }" /></div>
            </li>
            <li v-if="!rekapLanjut.length" class="text-sm text-teks3">Belum ada data.</li>
          </ul>
          <h3 v-if="rekapPT.length" class="mb-2 mt-5 font-bold">Jenis perguruan tinggi</h3>
          <ul class="divide-y divide-garis text-sm"><li v-for="r in rekapPT" :key="r.k" class="flex justify-between py-2"><span>{{ r.n }}</span><b class="tabular-nums">{{ r.j }}</b></li></ul>
        </section>
        <section class="kartu p-4 lg:col-span-2">
          <h3 class="mb-3 font-bold">Kampus dan lembaga tujuan</h3>
          <div class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead><tr class="border-b border-garis text-left text-teks3"><th class="py-2 pr-2">Kampus/lembaga</th><th class="px-2 text-right">Alumni</th><th class="pl-2 text-right">Diterima</th></tr></thead>
              <tbody><tr v-for="k in rekapKampus" :key="k.kampus" class="border-b border-garis/60"><td class="py-2 pr-2">{{ k.kampus }}</td><td class="px-2 text-right tabular-nums">{{ k.j }}</td><td class="pl-2 text-right tabular-nums">{{ k.diterima }}</td></tr>
                <tr v-if="!rekapKampus.length"><td colspan="3" class="py-4 text-center text-teks3">Belum ada kampus/lembaga tujuan yang diisi.</td></tr></tbody>
            </table>
          </div>
        </section>
      </div>
      <section class="kartu mt-3 overflow-x-auto p-4">
        <h3 class="mb-3 font-bold">Rincian per alumni</h3>
        <table class="w-full min-w-[720px] text-sm">
          <thead><tr class="border-b border-garis text-left text-teks3"><th class="py-2 pr-2">NIS</th><th class="px-2">Nama</th><th class="px-2">JK</th><th class="px-2">Rencana</th><th class="px-2">Kampus/lembaga</th><th class="px-2">Program studi</th><th class="pl-2">Status</th></tr></thead>
          <tbody><tr v-for="x in tampil" :key="x.id" class="border-b border-garis/60">
            <td class="py-2 pr-2 tabular-nums">{{ x.nis }}</td><td class="px-2"><router-link :to="`/alumni/profil/${x.id}`" class="font-semibold hover:underline">{{ x.nama }}</router-link></td><td class="px-2">{{ x.jenis_kelamin }}</td>
            <td class="px-2">{{ LANJUT[x.alumni?.lanjut]?.n || '–' }}</td><td class="px-2">{{ x.alumni?.kampus || '–' }}</td><td class="px-2">{{ x.alumni?.prodi || '–' }}</td><td class="pl-2">{{ STATUS_DAFTAR[x.alumni?.status_daftar]?.n || '–' }}</td></tr></tbody>
        </table>
      </section>

      <DokumenCetak judul="Rekap Rencana Lanjut Studi Alumni" :subjudul="subjudul" mendatar v-model:pratinjau="pratinjauStudi" :pencetak="sesi.pengguna?.nama_lengkap">
        <table class="tabel">
          <colgroup><col style="width:4%"><col style="width:8%"><col style="width:17%"><col style="width:4%"><col style="width:6%"><col style="width:9%"><col style="width:9%"><col style="width:17%"><col style="width:15%"><col style="width:11%"></colgroup>
          <thead><tr><th>No.</th><th>NIS</th><th>Nama</th><th>JK</th><th>Kelas</th><th>Rencana</th><th>Jenis PT</th><th>Kampus/lembaga</th><th>Fakultas/prodi</th><th>Status</th></tr></thead>
          <tbody><tr v-for="(x, i) in tampil" :key="x.id"><td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ x.nis }}</td><td>{{ x.nama }}</td><td class="tengah">{{ x.jenis_kelamin }}</td>
            <td class="tengah">{{ x.kelas || '–' }}</td><td>{{ LANJUT[x.alumni?.lanjut]?.n || '–' }}</td><td>{{ JENIS_PT[x.alumni?.jenis_pt] || '–' }}</td><td>{{ x.alumni?.kampus || '–' }}</td>
            <td>{{ [x.alumni?.fakultas, x.alumni?.prodi].filter(Boolean).join(' / ') || '–' }}</td><td>{{ STATUS_DAFTAR[x.alumni?.status_daftar]?.n || '–' }}</td></tr></tbody>
        </table>
        <table class="tabel" style="width: 50%; margin-top: 8pt">
          <colgroup><col style="width:70%"><col style="width:30%"></colgroup>
          <thead><tr><th>Rencana setelah lulus</th><th>Jumlah</th></tr></thead>
          <tbody><tr v-for="r in rekapLanjut" :key="r.k"><td>{{ r.n }}</td><td class="tengah">{{ r.j }}</td></tr>
            <tr><td>Jumlah alumni</td><td class="tengah">{{ tampil.length }}</td></tr></tbody>
        </table>
        <template #ttd>
          <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan || 'Direktur', nama: direktur.nama, niy: direktur.niy }"
            :kanan="{ jabatan: 'Yang membuat,', nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
        </template>
      </DokumenCetak>
    </template>

    <!-- Buku alumni -->
    <template v-else>
      <section class="kartu mt-4 p-5">
        <div class="flex items-start gap-3">
          <span class="w-prestasi chip-ikon h-12 w-12 shrink-0"><PhBookBookmark :size="28" weight="duotone" /></span>
          <div class="min-w-0 flex-1">
            <h3 class="font-bold">Buku Alumni {{ tahun ? 'Lulusan ' + tahun : '' }}</h3>
            <p class="text-sm text-teks2">{{ tentangBuku }}. Kertas F4, siap dicetak kolektif lalu dijilid. Isi mengikuti saringan di atas (tahun lulus, jenjang, rencana).</p>
            <ul class="mt-2 list-disc space-y-0.5 pl-5 text-sm text-teks3">
              <li>Sampul berlogo pondok dan daftar isi berurutan kelas lalu nama.</li>
              <li>Satu halaman profil per alumni: pas foto, data diri, orang tua, riwayat kelas/halaqah/kamar, hafalan, sertifikat, prestasi, rencana studi, kesan dan pesan.</li>
              <li>Profil yang belum lengkap tetap tercetak; lengkapi dahulu di Daftar alumni agar buku lebih baik.</li>
            </ul>
          </div>
        </div>
        <button class="tombol-utama mt-4 w-full sm:w-auto" :disabled="!tampil.length || !!menyusun" @click="susunBuku"><PhPrinter :size="20" weight="bold" /> {{ menyusun || 'Susun dan pratinjau buku' }}</button>
      </section>

      <LembarRapor v-model:pratinjau="pratinjauBuku" judul="Buku Alumni" :keterangan="subjudul" :nama-berkas="namaBerkas('Buku Alumni', subjudul)">
        <HalRapor tanpa-kop>
          <div class="sampul" style="padding-top: 22mm">
            <img v-if="logo" :src="logo" alt="Logo" style="width: 44mm; height: 44mm; object-fit: contain" />
            <p style="margin-top: 14mm; font-size: 30pt; font-weight: 700; letter-spacing: 2pt">BUKU ALUMNI</p>
            <p style="margin-top: 4mm; font-size: 15pt; font-weight: 700">{{ tahun ? 'LULUSAN TAHUN ' + tahun : 'SELURUH ANGKATAN' }}</p>
            <p v-if="jenjangBuku" style="font-size: 13pt; font-weight: 700; text-transform: uppercase">{{ jenjangBuku }}</p>
            <p style="margin-top: 30mm; font-size: 14pt; font-weight: 700; text-transform: uppercase; max-width: 80%">{{ namaPondok }}</p>
            <p style="font-size: 11pt">{{ lembaga.identitas?.alamat || '' }}</p>
            <p style="margin-top: auto; padding-top: 20mm; font-size: 11pt">{{ tampil.length }} alumni</p>
          </div>
        </HalRapor>
        <HalRapor>
          <template #kepala><p class="judul-rapor">DAFTAR ISI</p><p style="text-align: center; font-size: 10pt">{{ subjudul }}</p></template>
          <table class="tabel padat">
            <colgroup><col style="width:7%"><col style="width:12%"><col style="width:31%"><col style="width:5%"><col style="width:9%"><col style="width:36%"></colgroup>
            <thead><tr><th>No.</th><th>NIS</th><th>Nama</th><th>JK</th><th>Kelas</th><th>Rencana lanjut studi</th></tr></thead>
            <tbody><tr v-for="(x, i) in tampil" :key="x.id"><td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ x.nis }}</td><td>{{ x.nama }}</td><td class="tengah">{{ x.jenis_kelamin }}</td>
              <td class="tengah">{{ x.kelas || '–' }}</td><td>{{ ringkasStudi(x.alumni) || '–' }}</td></tr></tbody>
          </table>
          <p style="margin-top: 4pt; font-size: 9pt">Nomor pada daftar ini sama dengan nomor di bawah judul setiap halaman profil.</p>
        </HalRapor>
        <CVAlumni v-for="(p, i) in buku" :key="p.santri?.id || i" :p="p" :foto="fotoBuku[p.santri?.id] || ''" :nomor="i + 1" />
      </LembarRapor>
    </template>
    <p class="mt-6 flex items-center gap-2 text-xs text-teks3"><PhStudent :size="16" /> Alumni dan arsip tahun ajaran hanya dapat dibuka admin dan superadmin.</p>
  </div>
</template>
