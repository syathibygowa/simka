<!-- SIMKA PRO | src/pages/prestasi/PrestasiSantri.vue | v1.0 | Tahap C: prestasi dan capaian santri | 16/10/2026 -->
<script setup>
// Prestasi dan capaian santri (santri yang terlihat oleh pengguna): kartu statistik langsung, saringan rentang tanggal,
// bidang, tingkat, jenjang, dan pencarian; catat/ubah/hapus (wali kelas, musyrif, muhaffizh, pembina ekskul santri tersebut,
// pimpinan, admin Kelola santri, superadmin); rekap cetak F4 mendatar dan ekspor Excel.
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import * as XLSX from 'xlsx'
import { PhTrophy, PhPlus, PhStudent, PhMedal, PhBookOpenText, PhNotebook, PhMagnifyingGlass, PhPrinter, PhFileXls, PhPencilSimple, PhTrash, PhCaretRight } from '@phosphor-icons/vue'
import { usePrestasi } from '@/stores/prestasi'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { BIDANG_PRESTASI, TINGKAT_PRESTASI } from '@/lib/prestasi'
import { formatPendek, formatPanjang, hariIniISO } from '@/lib/tanggal'
import { ambilPenandaTangan } from '@/lib/penandatangan'
import KartuStatistik from '@/components/KartuStatistik.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import TombolAksi from '@/components/TombolAksi.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import LembarPrestasi from './LembarPrestasi.vue'

const pr = usePrestasi(); const sesi = useSesi(); const ui = useUI(); const router = useRouter()
// Rentang bawaan: awal tahun ajaran berjalan (1 Juli) sampai hari ini
const hari = hariIniISO(); const th = Number(hari.slice(0, 4)) - (Number(hari.slice(5, 7)) < 7 ? 1 : 0)
const mulai = ref(`${th}-07-01`); const selesai = ref(hari)
const bidang = ref(''); const tingkat = ref(''); const jenjang = ref(''); const cari = ref('')
const data = ref([]); const memuat = ref(true); const lembar = ref(false); const ubah = ref(null); const pratinjau = ref(false)
const direktur = ref({ jabatan: 'Direktur', nama: '', niy: '' })

async function muat() {
  if (selesai.value < mulai.value) return ui.toast('Tanggal akhir tidak boleh sebelum tanggal awal.', 'galat')
  memuat.value = true
  try { data.value = await pr.daftar({ mulai: mulai.value, selesai: selesai.value }) } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
onMounted(() => { pr.muatHak().catch(() => {}); muat(); ambilPenandaTangan('Direktur').then((d) => { direktur.value = d }).catch(() => {}) })
watch([mulai, selesai], muat)

const tampil = computed(() => {
  const q = cari.value.toLowerCase().trim()
  return data.value.filter((x) => (!bidang.value || x.bidang === bidang.value) && (!tingkat.value || x.tingkat === tingkat.value) && (!jenjang.value || x.jenjang === jenjang.value)
    && (!q || `${x.nama} ${x.nis} ${x.nama_kegiatan} ${x.capaian} ${x.penyelenggara || ''}`.toLowerCase().includes(q)))
})
const LUAR = ['kabupaten', 'provinsi', 'nasional', 'internasional']
const statistik = computed(() => {
  const d = tampil.value; const n = memuat.value ? '…' : null
  return [
    { judul: 'Prestasi tercatat', nilai: n ?? d.length, ikon: PhTrophy, warna: 'prestasi', ket: `${formatPendek(mulai.value)} – ${formatPendek(selesai.value)}` },
    { judul: 'Santri berprestasi', nilai: n ?? new Set(d.map((x) => x.student_id)).size, ikon: PhStudent, warna: 'santri', ket: 'Santri berbeda' },
    { judul: 'Kabupaten ke atas', nilai: n ?? d.filter((x) => LUAR.includes(x.tingkat)).length, ikon: PhMedal, warna: 'laporan', ket: 'Kabupaten, provinsi, nasional' },
    { judul: 'Bidang tahfizh', nilai: n ?? d.filter((x) => x.bidang === 'tahfizh').length, ikon: PhBookOpenText, warna: 'tahfizh', ket: 'Lomba dan capaian hafalan' },
    { judul: 'Masuk rapor', nilai: n ?? d.filter((x) => x.masuk_rapor).length, ikon: PhNotebook, warna: 'pengajuan', ket: 'Tampil di rapor semester' },
  ]
})

function tambah() { ubah.value = null; lembar.value = true }
function sunting(x) { ubah.value = x; lembar.value = true }
async function hapus(x) {
  if (!(await ui.konfirmasi({ judul: 'Hapus prestasi?', pesan: `${x.capaian} · ${x.nama_kegiatan} (${x.nama}) akan dihapus.`, ya: 'Hapus', bahaya: true }))) return
  try { await pr.hapus(x.id); ui.toast('Prestasi dihapus.'); muat() } catch (e) { ui.toast(e.message, 'galat') }
}
const subjudul = computed(() => [`Periode ${formatPanjang(mulai.value)} s.d. ${formatPanjang(selesai.value)}`, bidang.value && `Bidang ${BIDANG_PRESTASI[bidang.value].n}`,
  tingkat.value && `Tingkat ${TINGKAT_PRESTASI[tingkat.value]}`, jenjang.value && (jenjang.value === 'sma' ? 'SMA' : 'Kesetaraan Wustha')].filter(Boolean).join(' · '))
function eksporExcel() {
  const kolom = ['No.', 'NIS', 'Nama', 'JK', 'Kelas', 'Tanggal', 'Bidang', 'Tingkat', 'Kegiatan/lomba', 'Capaian', 'Penyelenggara', 'Masuk rapor', 'Dicatat oleh']
  const baris = tampil.value.map((x, i) => [i + 1, x.nis, x.nama, x.jenis_kelamin, x.kelas || '', formatPendek(x.tanggal), BIDANG_PRESTASI[x.bidang]?.n, TINGKAT_PRESTASI[x.tingkat],
    x.nama_kegiatan, x.capaian, x.penyelenggara || '', x.masuk_rapor ? 'Ya' : 'Tidak', x.pencatat || ''])
  const ws = XLSX.utils.aoa_to_sheet([kolom, ...baris])
  ws['!cols'] = kolom.map((k, i) => ({ wch: Math.min(40, Math.max(k.length, ...baris.map((r) => String(r[i] ?? '').length)) + 2) }))
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Prestasi santri')
  XLSX.writeFile(wb, `Prestasi-Santri-${formatPendek(mulai.value).replace(/\//g, '-')}-sd-${formatPendek(selesai.value).replace(/\//g, '-')}.xlsx`)
}
</script>
<template>
  <div>
    <div class="layar-saja">
      <div class="mb-5 hidden items-center gap-3 lg:flex">
        <span class="w-prestasi chip-ikon h-12 w-12"><PhTrophy :size="28" weight="duotone" /></span>
        <div class="flex-1"><h2 class="text-lg font-bold">Prestasi Santri</h2><p class="text-sm text-teks3">Prestasi dan capaian santri; yang bertanda rapor tampil di rapor semester.</p></div>
        <button v-if="pr.boleh" class="tombol-utama" @click="tambah"><PhPlus :size="20" weight="bold" /> Catat prestasi</button>
      </div>

      <div class="-mx-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-3 sm:overflow-visible sm:px-0 xl:grid-cols-5">
        <KartuStatistik v-for="k in statistik" :key="k.judul" class="w-[46%] shrink-0 snap-start sm:w-auto" :judul="k.judul" :nilai="k.nilai" :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket" />
      </div>

      <div class="kartu mt-4 grid grid-cols-2 gap-3 p-4 lg:grid-cols-4">
        <InputTanggal v-model="mulai" label="Dari tanggal" />
        <InputTanggal v-model="selesai" label="Sampai tanggal" />
        <div><label class="label-isian" for="ps-bidang">Bidang</label>
          <select id="ps-bidang" v-model="bidang" class="isian"><option value="">Semua bidang</option><option v-for="(b, k) in BIDANG_PRESTASI" :key="k" :value="k">{{ b.n }}</option></select></div>
        <div><label class="label-isian" for="ps-tingkat">Tingkat</label>
          <select id="ps-tingkat" v-model="tingkat" class="isian"><option value="">Semua tingkat</option><option v-for="(n, k) in TINGKAT_PRESTASI" :key="k" :value="k">{{ n }}</option></select></div>
        <div class="relative col-span-2 lg:col-span-3"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
          <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari nama santri, NIS, kegiatan, atau capaian" aria-label="Cari prestasi" /></div>
        <select v-model="jenjang" class="isian col-span-2 lg:col-span-1" aria-label="Saring jenjang"><option value="">Semua jenjang</option><option value="wustha">Kesetaraan Wustha</option><option value="sma">SMA</option></select>
      </div>

      <div class="-mx-4 my-4 flex gap-2 overflow-x-auto px-4 pb-1 lg:mx-0 lg:px-0">
        <button class="w-pengajuan tombol-garis shrink-0 px-4 text-sm" :disabled="!tampil.length" @click="pratinjau = true"><PhPrinter :size="20" weight="duotone" style="color: var(--c)" /> Cetak rekap</button>
        <button class="w-gaji tombol-garis shrink-0 px-4 text-sm" :disabled="!tampil.length" @click="eksporExcel"><PhFileXls :size="20" weight="duotone" style="color: var(--c)" /> Ekspor Excel</button>
      </div>

      <p v-if="memuat" class="py-10 text-center text-teks3">Memuat prestasi…</p>
      <ul v-else-if="tampil.length" class="grid gap-3 lg:grid-cols-2">
        <li v-for="x in tampil" :key="x.id" :class="['kartu min-w-0 p-4', 'w-' + (BIDANG_PRESTASI[x.bidang]?.w || 'ekskul')]">
          <div class="flex items-start gap-3">
            <span class="chip-ikon h-11 w-11 shrink-0"><PhTrophy :size="24" weight="duotone" /></span>
            <div class="min-w-0 flex-1">
              <p class="font-bold leading-snug">{{ x.capaian }} · {{ x.nama_kegiatan }}</p>
              <router-link :to="`/santri/${x.student_id}`" class="mt-0.5 flex items-center gap-1 text-sm font-semibold hover:underline">{{ x.nama }} <span class="font-normal text-teks3">· {{ x.nis }}{{ x.kelas ? ' · ' + x.kelas : '' }}</span><PhCaretRight :size="14" class="shrink-0" /></router-link>
              <p class="text-sm text-teks2">{{ formatPanjang(x.tanggal) }} · {{ TINGKAT_PRESTASI[x.tingkat] }}{{ x.penyelenggara ? ' · ' + x.penyelenggara : '' }}</p>
              <p class="mt-1.5 flex flex-wrap items-center gap-1.5 text-xs"><span class="lencana">{{ BIDANG_PRESTASI[x.bidang]?.n }}</span>
                <span v-if="x.masuk_rapor" class="lencana w-laporan"><PhNotebook :size="13" weight="fill" /> Rapor</span>
                <span v-if="x.pencatat" class="text-teks3">dicatat {{ x.pencatat }}</span></p>
            </div>
            <div v-if="x.boleh_ubah" class="flex shrink-0 flex-col gap-1">
              <button class="tombol-ikon" aria-label="Ubah prestasi" @click="sunting(x)"><PhPencilSimple :size="20" /></button>
              <button class="tombol-ikon" aria-label="Hapus prestasi" @click="hapus(x)"><PhTrash :size="20" /></button>
            </div>
          </div>
        </li>
      </ul>
      <div v-else class="kartu p-8 text-center">
        <PhTrophy :size="40" weight="duotone" class="mx-auto text-teks3" />
        <p class="mt-2 font-semibold">Belum ada prestasi pada periode ini.</p>
        <p class="text-sm text-teks3">{{ pr.boleh ? 'Catat prestasi santri asuhan Anda dengan tombol Catat prestasi.' : 'Prestasi dicatat oleh wali kelas, musyrif, muhaffizh, pimpinan, atau admin.' }}</p>
      </div>
    </div>

    <TombolAksi v-if="pr.boleh" class="lg:hidden" label="Catat" :ikon="PhPlus" warna="prestasi" @klik="tambah" />
    <LembarPrestasi v-model="lembar" :data="ubah" @selesai="muat" />

    <DokumenCetak judul="Rekap Prestasi Santri" :subjudul="subjudul" mendatar v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap">
      <table class="tabel">
        <colgroup><col style="width:4%"><col style="width:8%"><col style="width:16%"><col style="width:4%"><col style="width:7%"><col style="width:9%"><col style="width:9%"><col style="width:10%"><col style="width:16%"><col style="width:9%"><col style="width:8%"></colgroup>
        <thead><tr><th>No.</th><th>NIS</th><th>Nama</th><th>JK</th><th>Kelas</th><th>Tanggal</th><th>Bidang</th><th>Tingkat</th><th>Kegiatan/lomba</th><th>Capaian</th><th>Penyelenggara</th></tr></thead>
        <tbody><tr v-for="(x, i) in tampil" :key="x.id"><td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ x.nis }}</td><td>{{ x.nama }}</td><td class="tengah">{{ x.jenis_kelamin }}</td>
          <td class="tengah">{{ x.kelas || '–' }}</td><td class="tengah">{{ formatPendek(x.tanggal) }}</td><td>{{ BIDANG_PRESTASI[x.bidang]?.n }}</td><td>{{ TINGKAT_PRESTASI[x.tingkat] }}</td>
          <td>{{ x.nama_kegiatan }}</td><td>{{ x.capaian }}</td><td>{{ x.penyelenggara || '–' }}</td></tr></tbody>
      </table>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan || 'Direktur', nama: direktur.nama, niy: direktur.niy }"
          :kanan="{ jabatan: 'Yang membuat,', nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
      </template>
    </DokumenCetak>
  </div>
</template>
