<!-- SIMKA PRO | src/pages/disiplin/TabPelanggaran.vue | v1.3 | 14.30.0: label saringan yang sudah jelas disembunyikan (hemat ruang) | 29/10/2026 -->
<script setup>
// Tab Pelanggaran: kartu statistik langsung, saringan (rentang tanggal, tingkat, kategori, jenjang, pencarian; corong di HP),
// daftar catatan dengan lencana SP, ubah/hapus (pencatat atau Kesantrian), cetak rekap F4 mendatar berkop dan Excel.
// ?santri=<id>: riwayat satu santri (dari notifikasi atau biodata) beserta tombol "Usulkan SP" bagi Bidang Kesantrian.
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { PhGavel, PhPlus, PhStudent, PhWarningOctagon, PhHourglassMedium, PhMagnifyingGlass, PhPrinter, PhFileXls, PhPencilSimple, PhTrash,
  PhCaretRight, PhMapPin, PhClock, PhArrowLeft, PhUserCircle, PhHandPalm, PhImage } from '@phosphor-icons/vue'
import { useDisiplin } from '@/stores/disiplin'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { TINGKAT_PELANGGARAN, TINGKAT_SP_SANTRI } from '@/lib/disiplin'
import { formatPendek, formatPanjang, hariIniISO } from '@/lib/tanggal'
import { eksporExcel } from '@/lib/excel'
import { namaBerkas, periodeRentang } from '@/lib/namaBerkas'
import { ambilPenandaTangan } from '@/lib/penandatangan'
import KartuStatistik from '@/components/KartuStatistik.vue'
import SaringCorong from '@/components/SaringCorong.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import TombolAksi from '@/components/TombolAksi.vue'
import FotoBerkas from '@/components/FotoBerkas.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import LembarPelanggaran from './LembarPelanggaran.vue'
import LembarUsulSPSantri from './LembarUsulSPSantri.vue'

const route = useRoute(); const router = useRouter()
const ds = useDisiplin(); const sesi = useSesi(); const ui = useUI()
const hari = hariIniISO(); const th = Number(hari.slice(0, 4)) - (Number(hari.slice(5, 7)) < 7 ? 1 : 0)
const mulai = ref(`${th}-07-01`); const selesai = ref(hari)
const tingkat = ref(''); const kategori = ref(''); const jenjang = ref(''); const cari = ref('')
const santriId = computed(() => (typeof route.query.santri === 'string' ? route.query.santri : ''))
const data = ref([]); const memuat = ref(true)
const kepalaKesantrian = ref({ jabatan: 'Kepala Bidang Kesantrian', nama: '', niy: '' })

async function muat() {
  if (selesai.value < mulai.value) return ui.toast('Tanggal akhir tidak boleh sebelum tanggal awal.', 'galat')
  memuat.value = true
  try { data.value = await ds.daftar(santriId.value ? { santri: santriId.value } : { mulai: mulai.value, selesai: selesai.value }) }
  catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
onMounted(() => { muat(); ambilPenandaTangan('%Kesantrian%').then((d) => { if (d?.nama) kepalaKesantrian.value = d }).catch(() => {}) })
watch([mulai, selesai, santriId], muat)

const daftarKategori = computed(() => [...new Set(data.value.map((x) => x.kategori))].sort())
const tampil = computed(() => {
  const q = cari.value.toLowerCase().trim()
  return data.value.filter((x) => (!tingkat.value || x.tingkat === tingkat.value) && (!kategori.value || x.kategori === kategori.value) && (!jenjang.value || x.jenjang === jenjang.value)
    && (!q || `${x.nama} ${x.nis} ${x.kategori} ${x.uraian} ${x.kelas || ''} ${x.kamar || ''} ${x.pencatat || ''}`.toLowerCase().includes(q)))
})
const santriRiwayat = computed(() => (santriId.value ? data.value[0] || null : null))
// Santri yang mencapai ambang (pelanggaran belum ditindaklanjuti SP)
const perluTindak = computed(() => {
  const a = ds.set?.ambang || {}; const per = {}
  for (const x of data.value.filter((p) => !p.warning_id)) { per[x.student_id] ??= { ringan: 0, sedang: 0, berat: 0 }; per[x.student_id][x.tingkat]++ }
  return Object.values(per).filter((t) => ['ringan', 'sedang', 'berat'].some((k) => a[k] > 0 && t[k] >= a[k])).length
})
const statistik = computed(() => {
  const d = tampil.value; const n = memuat.value ? '…' : null
  return [
    { judul: 'Pelanggaran tercatat', nilai: n ?? d.length, ikon: PhGavel, warna: 'disiplin', ket: santriId.value ? 'Seluruh riwayat santri' : `${formatPendek(mulai.value)} – ${formatPendek(selesai.value)}` },
    { judul: 'Santri tercatat', nilai: n ?? new Set(d.map((x) => x.student_id)).size, ikon: PhStudent, warna: 'santri', ket: 'Santri berbeda' },
    { judul: 'Pelanggaran berat', nilai: n ?? d.filter((x) => x.tingkat === 'berat').length, ikon: PhWarningOctagon, warna: 'klinik', ket: 'Diberitahukan ke Kesantrian' },
    { judul: 'Perlu dipertimbangkan SP', nilai: n ?? perluTindak.value, ikon: PhHourglassMedium, warna: 'pengajuan', ket: 'Santri mencapai ambang' },
  ]
})

const lembar = ref(false); const ubah = ref(null); const lembarSP = ref(false)
function tambah() { ubah.value = null; lembar.value = true }
function sunting(x) { ubah.value = x; lembar.value = true }
async function hapus(x) {
  if (!(await ui.konfirmasi({ judul: 'Hapus catatan pelanggaran?', pesan: `${x.kategori} (${x.nama}, ${formatPendek(x.tanggal)}) akan dihapus. Penghapusan tercatat di Audit Log.`, ya: 'Hapus', bahaya: true }))) return
  try { await ds.hapus(x.id); ui.toast('Catatan pelanggaran dihapus.'); muat() } catch (e) { ui.toast(e.message, 'galat') }
}
const lihatSantri = (id) => router.replace({ path: '/disiplin-santri/pelanggaran', query: { santri: id } })
const tutupRiwayat = () => router.replace({ path: '/disiplin-santri/pelanggaran', query: {} })
const santriKunci = computed(() => (santriRiwayat.value ? { id: santriRiwayat.value.student_id, nama: santriRiwayat.value.nama, nis: santriRiwayat.value.nis, kelas: santriRiwayat.value.kelas, kamar: santriRiwayat.value.kamar } : null))

// ---------- Cetak dan Excel ----------
const pratinjau = ref(false)
const subjudul = computed(() => [santriRiwayat.value ? `${santriRiwayat.value.nama} (NIS ${santriRiwayat.value.nis})` : `Periode ${formatPanjang(mulai.value)} s.d. ${formatPanjang(selesai.value)}`,
  tingkat.value && `Tingkat ${TINGKAT_PELANGGARAN[tingkat.value].n.toLowerCase()}`, kategori.value, jenjang.value && (jenjang.value === 'sma' ? 'SMA' : 'Kesetaraan Wustha')].filter(Boolean).join(' · '))
const KOLOM = [
  { judul: 'Tanggal', kunci: 'tanggal', tanggal: true }, { judul: 'Jam', kunci: 'jam' }, { judul: 'NIS', kunci: 'nis' }, { judul: 'Nama', kunci: 'nama' }, { judul: 'JK', kunci: 'jenis_kelamin' },
  { judul: 'Kelas', kunci: 'kelas' }, { judul: 'Kamar', kunci: 'kamar' }, { judul: 'Tingkat', kunci: 'tingkat', format: (v) => TINGKAT_PELANGGARAN[v]?.n }, { judul: 'Kategori', kunci: 'kategori' },
  { judul: 'Tempat', kunci: 'tempat' }, { judul: 'Uraian', kunci: 'uraian' }, { judul: 'Tindakan', kunci: 'tindakan' }, { judul: 'Saksi', kunci: 'saksi' },
  { judul: 'Surat peringatan', kunci: 'sp_tingkat', format: (v) => (v ? TINGKAT_SP_SANTRI[v].singkat : '') }, { judul: 'Dicatat oleh', kunci: 'pencatat' },
]
function excel() {
  if (!tampil.value.length) return ui.toast('Tidak ada data untuk diekspor.', 'galat')
  eksporExcel(`${namaBerkas(santriRiwayat.value?.nama || 'Seluruh santri', 'Catatan Pelanggaran Santri', santriRiwayat.value ? '' : periodeRentang(mulai.value, selesai.value))}.xlsx`, KOLOM, tampil.value, 'Pelanggaran')
}
</script>
<template>
  <div>
    <div class="layar-saja">
      <div v-if="santriId" class="kartu mb-4 flex flex-wrap items-center gap-3 p-4">
        <button class="tombol-ikon" aria-label="Kembali ke semua pelanggaran" @click="tutupRiwayat"><PhArrowLeft :size="22" /></button>
        <div class="min-w-0 flex-1"><p class="text-xs text-teks3">Riwayat pelanggaran</p>
          <p class="truncate font-bold">{{ santriRiwayat?.nama || 'Santri' }}<span v-if="santriRiwayat" class="font-normal text-teks3"> · {{ santriRiwayat.nis }}{{ santriRiwayat.kelas ? ' · ' + santriRiwayat.kelas : '' }}</span></p></div>
        <router-link v-if="santriRiwayat" :to="`/santri/${santriId}`" class="tombol-garis min-h-[44px] px-3 text-sm"><PhUserCircle :size="18" weight="duotone" /> Biodata</router-link>
        <button v-if="ds.hak.usul && santriRiwayat" class="tombol-utama min-h-[44px] px-3 text-sm" @click="lembarSP = true"><PhWarningOctagon :size="18" weight="duotone" /> Usulkan SP</button>
      </div>

      <div class="-mx-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-4 sm:overflow-visible sm:px-0">
        <KartuStatistik v-for="k in statistik" :key="k.judul" class="w-[46%] shrink-0 snap-start sm:w-auto" :judul="k.judul" :nilai="k.nilai" :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket" />
      </div>

      <SaringCorong class="mt-4" :jumlah="[tingkat, kategori, jenjang].filter(Boolean).length"
        :ringkasan="[santriId ? 'Seluruh riwayat' : `${formatPendek(mulai)} – ${formatPendek(selesai)}`, tingkat && TINGKAT_PELANGGARAN[tingkat].n, kategori, jenjang && (jenjang === 'sma' ? 'SMA' : 'Wustha')].filter(Boolean).join(' · ')" judul="Saring pelanggaran">
        <template #cari><div class="relative"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
          <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari nama, NIS, kategori, uraian" aria-label="Cari pelanggaran" /></div></template>
        <select v-model="tingkat" class="isian md:w-auto" aria-label="Saring tingkat"><option value="">Semua tingkat</option>
          <option v-for="(t, k) in TINGKAT_PELANGGARAN" :key="k" :value="k">{{ t.n }}</option></select>
        <select v-model="kategori" class="isian md:w-auto md:max-w-[16rem]" aria-label="Saring kategori"><option value="">Semua kategori</option>
          <option v-for="k in daftarKategori" :key="k" :value="k">{{ k }}</option></select>
        <select v-model="jenjang" class="isian md:w-auto" aria-label="Saring jenjang"><option value="">Semua jenjang</option><option value="wustha">Kesetaraan Wustha</option><option value="sma">SMA</option></select>
        <div v-if="!santriId" class="grid w-full grid-cols-2 gap-3 md:w-auto md:min-w-[22rem]"><InputTanggal class="tanpa-label" v-model="mulai" label="Dari tanggal" /><InputTanggal class="tanpa-label" v-model="selesai" label="Sampai" /></div>
        <button v-if="ds.hak.catat" class="tombol-utama hidden lg:inline-flex" @click="tambah"><PhPlus :size="20" weight="bold" /> Catat pelanggaran</button>
      </SaringCorong>
      <div class="mt-3 flex flex-wrap items-end gap-2 md:justify-end">
        <button class="tombol-garis min-h-[44px] px-3 text-sm" :disabled="!tampil.length" @click="excel"><PhFileXls :size="18" weight="duotone" /> Ekspor</button>
        <button class="tombol-garis min-h-[44px] px-3 text-sm" :disabled="!tampil.length" @click="pratinjau = true"><PhPrinter :size="18" weight="duotone" /> Cetak</button>
      </div>

      <p v-if="memuat" class="py-10 text-center text-teks3">Memuat catatan pelanggaran…</p>
      <ul v-else-if="tampil.length" class="mt-4 grid gap-3 lg:grid-cols-2">
        <li v-for="x in tampil" :key="x.id" :class="['kartu pl min-w-0 p-4', 'w-' + TINGKAT_PELANGGARAN[x.tingkat].w]">
          <div class="flex items-start gap-3">
            <span class="chip-ikon h-11 w-11 shrink-0"><PhGavel :size="24" weight="duotone" /></span>
            <div class="min-w-0 flex-1">
              <p class="flex flex-wrap items-center gap-1.5"><span :class="['lencana', 'w-' + TINGKAT_PELANGGARAN[x.tingkat].w]">{{ TINGKAT_PELANGGARAN[x.tingkat].n }}</span>
                <span v-if="x.sp_tingkat" :class="['lencana', 'w-' + TINGKAT_SP_SANTRI[x.sp_tingkat].w]">Dasar {{ TINGKAT_SP_SANTRI[x.sp_tingkat].singkat }}</span></p>
              <p class="mt-1 font-bold leading-snug">{{ x.kategori }}</p>
              <button v-if="!santriId" type="button" class="mt-0.5 flex max-w-full items-center gap-1 text-left text-sm font-semibold hover:underline" @click="lihatSantri(x.student_id)">
                <span class="truncate">{{ x.nama }}</span><span class="shrink-0 font-normal text-teks3">· {{ x.nis }}{{ x.kelas ? ' · ' + x.kelas : '' }}</span><PhCaretRight :size="14" class="shrink-0" /></button>
              <p class="mt-1 whitespace-pre-line text-sm text-teks2">{{ x.uraian }}</p>
              <p v-if="x.tindakan" class="mt-1 flex gap-1.5 text-sm text-teks2"><PhHandPalm :size="16" class="mt-0.5 shrink-0" />{{ x.tindakan }}</p>
              <p class="mt-1.5 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-teks3">
                <span>{{ formatPanjang(x.tanggal) }}</span><span v-if="x.jam" class="flex items-center gap-1"><PhClock :size="13" />{{ x.jam }}</span>
                <span v-if="x.tempat" class="flex items-center gap-1"><PhMapPin :size="13" />{{ x.tempat }}</span>
                <span v-if="x.pencatat">dicatat {{ x.pencatat }}</span><span v-if="x.bukti_id" class="flex items-center gap-1"><PhImage :size="13" />bukti</span></p>
            </div>
            <div class="flex shrink-0 flex-col items-end gap-1">
              <FotoBerkas v-if="x.bukti_id" :id="x.bukti_id" alt="Bukti pelanggaran" ukuran="h-14 w-14" />
              <button v-if="x.boleh_ubah" class="tombol-ikon" aria-label="Ubah catatan" @click="sunting(x)"><PhPencilSimple :size="20" /></button>
              <button v-if="x.boleh_ubah" class="tombol-ikon" aria-label="Hapus catatan" @click="hapus(x)"><PhTrash :size="20" /></button>
            </div>
          </div>
        </li>
      </ul>
      <div v-else class="kartu mt-4 p-8 text-center">
        <PhGavel :size="40" weight="duotone" class="mx-auto text-teks3" />
        <p class="mt-2 font-semibold">{{ santriId ? 'Belum ada catatan pelanggaran untuk santri ini.' : 'Tidak ada catatan pelanggaran pada periode ini.' }}</p>
        <p class="text-sm text-teks3">{{ ds.hak.catat ? 'Catat pelanggaran dengan tombol Catat.' : 'Pelanggaran dicatat pengasuh santri, Security, dan Bidang Kesantrian.' }}</p>
      </div>
    </div>

    <TombolAksi v-if="ds.hak.catat" class="lg:hidden" label="Catat" :ikon="PhPlus" warna="disiplin" @klik="tambah" />
    <LembarPelanggaran v-model="lembar" :data="ubah" :santri="ubah ? null : santriKunci" @selesai="muat" />
    <LembarUsulSPSantri v-if="ds.hak.usul" v-model="lembarSP" :santri-awal="santriKunci" @tersimpan="muat" />

    <DokumenCetak jenis="disiplin_pelanggaran" :judul="santriRiwayat ? 'Riwayat Pelanggaran Santri' : 'Rekap Pelanggaran Santri'" :subjudul="subjudul" mendatar v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap"
      :nama-berkas="namaBerkas(santriRiwayat?.nama || 'Seluruh santri', 'Catatan Pelanggaran Santri', santriRiwayat ? '' : periodeRentang(mulai, selesai))">
      <table class="tabel" style="font-size: 9pt">
        <colgroup><col style="width:3%"><col style="width:8%"><col style="width:7%"><col style="width:13%"><col style="width:6%"><col style="width:6%"><col style="width:14%"><col style="width:21%"><col style="width:13%"><col style="width:9%"></colgroup>
        <thead><tr><th>No.</th><th>Tanggal</th><th>NIS</th><th>Nama</th><th>Kelas</th><th>Tingkat</th><th>Kategori</th><th>Uraian</th><th>Tindakan</th><th>Dicatat oleh</th></tr></thead>
        <tbody><tr v-for="(x, i) in tampil" :key="x.id"><td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ formatPendek(x.tanggal) }}{{ x.jam ? ' ' + x.jam : '' }}</td><td class="tengah">{{ x.nis }}</td>
          <td>{{ x.nama }}</td><td class="tengah">{{ x.kelas || '–' }}</td><td class="tengah">{{ TINGKAT_PELANGGARAN[x.tingkat].n }}</td><td>{{ x.kategori }}</td>
          <td>{{ x.uraian }}{{ x.tempat ? ' (' + x.tempat + ')' : '' }}</td><td>{{ x.tindakan || '–' }}</td><td>{{ x.pencatat || '–' }}</td></tr></tbody>
      </table>
      <p style="margin-top: 6pt; font-size: 9pt">Jumlah: {{ tampil.length }} catatan (ringan {{ tampil.filter((x) => x.tingkat === 'ringan').length }}, sedang {{ tampil.filter((x) => x.tingkat === 'sedang').length }},
        berat {{ tampil.filter((x) => x.tingkat === 'berat').length }}). Dokumen ini bersifat terbatas.</p>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: kepalaKesantrian.jabatan || 'Kepala Bidang Kesantrian', nama: kepalaKesantrian.nama, niy: kepalaKesantrian.niy }"
          :kanan="{ jabatan: 'Yang membuat,', nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
      </template>
    </DokumenCetak>
  </div>
</template>
<style scoped>
.kartu.pl { border-left: 4px solid var(--c); }
</style>
