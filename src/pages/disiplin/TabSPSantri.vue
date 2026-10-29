<!-- SIMKA PRO | src/pages/disiplin/TabSPSantri.vue | v1.3 | 14.30.0: label saringan yang sudah jelas disembunyikan (hemat ruang) | 29/10/2026 -->
<script setup>
// Tab Surat peringatan (santri):
//   Daftar  : SP yang boleh dilihat; saring keadaan, tingkat, jenjang, rentang tanggal usul. ?sp=<id> membuka rinciannya (notifikasi).
//   Rincian : pelanggaran dasar, sanksi, status surat, penyerahan kepada orang tua; baca/cetak surat, buka di Surat keluar (TU),
//             WA orang tua/wali (setelah terbit), catat penyerahan, batalkan usulan, cabut SP (Kesantrian).
//   Rekap   : cetak F4 mendatar berkop dan Excel.
import { ref, computed, watch, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { PhPlus, PhMagnifyingGlass, PhWarningOctagon, PhHourglassMedium, PhCheckCircle, PhArrowCounterClockwise, PhPrinter, PhFileXls,
  PhEnvelopeOpen, PhProhibit, PhXCircle, PhUserCircle, PhHandshake, PhSignOut } from '@phosphor-icons/vue'
import { useDisiplin } from '@/stores/disiplin'
import { useLembaga } from '@/stores/lembaga'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { TINGKAT_SP_SANTRI, KEADAAN_SP_SANTRI, TINGKAT_PELANGGARAN, pesanSPWali } from '@/lib/disiplin'
import { STATUS_SURAT_SP, sisaHari } from '@/lib/teguran'
import { formatPendek, formatPanjang, formatWaktu, hariIniISO } from '@/lib/tanggal'
import { tambahHari } from '@/lib/persuratan'
import { eksporExcel } from '@/lib/excel'
import { namaBerkas, periodeRentang } from '@/lib/namaBerkas'
import SaringCorong from '@/components/SaringCorong.vue'
import KartuStatistik from '@/components/KartuStatistik.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import TombolAksi from '@/components/TombolAksi.vue'
import TombolWA from '@/components/TombolWA.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import CetakSuratTeguran from '@/pages/persuratan/CetakSuratTeguran.vue'
import LembarUsulSPSantri from './LembarUsulSPSantri.vue'

const route = useRoute(); const router = useRouter()
const ds = useDisiplin(); const lembaga = useLembaga(); const sesi = useSesi(); const ui = useUI()
const hak = computed(() => ds.hak)
const daftar = ref([]); const memuat = ref(false)
const mulai = ref(tambahHari(hariIniISO(), -365)); const selesai = ref(hariIniISO())
async function muat() {
  memuat.value = true
  try { daftar.value = await ds.daftarSP({ mulai: mulai.value, selesai: selesai.value }) } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
onMounted(() => { muat(); lembaga.muat().catch(() => {}); bukaDariQuery() })
watch([mulai, selesai], muat)

const cari = ref(''); const keadaan = ref(''); const tingkat = ref(''); const jenjang = ref('')
const tampil = computed(() => {
  const q = cari.value.toLowerCase().trim()
  return daftar.value.filter((x) => (!keadaan.value || x.keadaan === keadaan.value) && (!tingkat.value || x.tingkat === Number(tingkat.value))
    && (!jenjang.value || x.jenjang === jenjang.value) && (!q || `${x.nama} ${x.nis} ${x.nomor || ''} ${x.kelas || ''} ${x.pengusul || ''}`.toLowerCase().includes(q)))
})
const hitung = (k) => daftar.value.filter((x) => x.keadaan === k).length
const KARTU = computed(() => [
  { judul: 'SP aktif', nilai: memuat.value ? '…' : hitung('aktif'), ikon: PhWarningOctagon, warna: 'disiplin', ket: 'Masih dalam masa berlaku' },
  { judul: 'Diproses Tata Usaha', nilai: memuat.value ? '…' : hitung('diusulkan'), ikon: PhHourglassMedium, warna: 'shift', ket: 'Usulan belum terbit' },
  { judul: 'SP-3 (dikeluarkan)', nilai: memuat.value ? '…' : daftar.value.filter((x) => x.tingkat === 3 && x.status === 'terbit').length, ikon: PhSignOut, warna: 'klinik', ket: 'Dikembalikan kepada orang tua' },
  { judul: 'Berakhir/dicabut', nilai: memuat.value ? '…' : hitung('berakhir') + hitung('dicabut'), ikon: PhCheckCircle, warna: 'presensi', ket: 'Tidak lagi berlaku' },
])
const hi = hariIniISO()
const lembarUsul = ref(false)

// ---------- Rincian ----------
const pilihan = ref(null); const lembarRinci = ref(false); const mode = ref(''); const alasan = ref(''); const proses = ref(false); const cetakSurat = ref(false)
const serah = ref({ tanggal: hi, ket: '' })
function buka(x) { pilihan.value = x; mode.value = ''; alasan.value = ''; serah.value = { tanggal: hi, ket: x.diserahkan_ket || '' }; lembarRinci.value = true }
function bukaDariQuery() {
  const id = route.query.sp
  if (typeof id !== 'string') return
  const tunggu = setInterval(() => { if (!memuat.value) { clearInterval(tunggu); const x = daftar.value.find((d) => d.id === id); if (x) buka(x); else ui.toast('Surat peringatan tidak ditemukan pada rentang ini.', 'galat') } }, 200)
  setTimeout(() => clearInterval(tunggu), 8000)
  router.replace({ path: '/disiplin-santri/sp', query: {} })
}
const bolehBatal = (x) => x?.status === 'diusulkan' && (x.saya_pengusul || hak.value.tu || hak.value.kelola)
const bolehCabut = (x) => x?.status === 'terbit' && hak.value.kelola
async function jalankan(fn, pesan) {
  if (alasan.value.trim().length < 5) return ui.toast('Tuliskan alasannya (minimal 5 huruf).', 'galat')
  proses.value = true
  try { await fn(); ui.toast(pesan); lembarRinci.value = false; await muat() } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
const batalkan = () => jalankan(() => ds.batal(pilihan.value.id, alasan.value.trim()), 'Usulan dibatalkan; draf suratnya ikut dibatalkan dan catatan pelanggaran dilepas.')
const cabut = () => jalankan(() => ds.cabut(pilihan.value.id, alasan.value.trim()), 'Surat peringatan dicabut dan pengasuh santri diberi tahu.')
async function simpanSerah() {
  proses.value = true
  try { await ds.serah(pilihan.value.id, serah.value.tanggal, serah.value.ket.trim()); ui.toast('Penyerahan surat kepada orang tua/wali tercatat.'); mode.value = ''; await muat(); pilihan.value = daftar.value.find((d) => d.id === pilihan.value.id) || pilihan.value }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
function bukaSurat(x) { lembarRinci.value = false; router.push({ path: '/persuratan/keluar', query: { surat: x.letter_id } }) }

// ---------- Rekap ----------
const pratinjau = ref(false)
const KOLOM = [
  { judul: 'NIS', kunci: 'nis' }, { judul: 'Nama', kunci: 'nama' }, { judul: 'JK', kunci: 'jenis_kelamin' }, { judul: 'Kelas', kunci: 'kelas' },
  { judul: 'Tingkat', kunci: 'tingkat', format: (v) => TINGKAT_SP_SANTRI[v]?.singkat }, { judul: 'Pelanggaran', kunci: 'kategori' }, { judul: 'Sanksi', kunci: 'sanksi' },
  { judul: 'Nomor surat', kunci: 'nomor' }, { judul: 'Tanggal surat', kunci: 'tanggal_surat', tanggal: true }, { judul: 'Berlaku sampai', kunci: 'berlaku_sampai', tanggal: true },
  { judul: 'Keadaan', kunci: 'keadaan', format: (v) => KEADAAN_SP_SANTRI[v]?.n }, { judul: 'Diserahkan ke orang tua', kunci: 'diserahkan_pada', tanggal: true },
  { judul: 'Pengusul', kunci: 'pengusul' }, { judul: 'Alasan batal/cabut', kunci: 'alasan' },
]
function excel() {
  if (!tampil.value.length) return ui.toast('Tidak ada data untuk diekspor.', 'galat')
  eksporExcel(`${namaBerkas('Rekap Surat Peringatan Santri', periodeRentang(mulai.value, selesai.value))}.xlsx`, KOLOM, tampil.value, 'SP Santri')
}
const direktur = computed(() => lembaga.signatories?.find((s) => /^direktur$/i.test(s.jabatan_tertulis)) || lembaga.signatories?.[0] || {})
const kesantrian = computed(() => lembaga.signatories?.find((s) => /kesantrian/i.test(s.jabatan_tertulis)) || null)
</script>
<template>
  <div>
    <section class="grid grid-cols-2 gap-3 lg:grid-cols-4">
      <KartuStatistik v-for="k in KARTU" :key="k.judul" :judul="k.judul" :nilai="k.nilai" :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket" />
    </section>

    <SaringCorong class="mt-4" :jumlah="[keadaan, tingkat, jenjang].filter(Boolean).length" judul="Saring surat peringatan"
      :ringkasan="[`${formatPendek(mulai)} – ${formatPendek(selesai)}`, keadaan && KEADAAN_SP_SANTRI[keadaan].n, tingkat && TINGKAT_SP_SANTRI[tingkat].singkat, jenjang && (jenjang === 'sma' ? 'SMA' : 'Wustha')].filter(Boolean).join(' · ')">
      <template #cari><div class="relative"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
        <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari nama, NIS, nomor surat" aria-label="Cari surat peringatan" /></div></template>
      <select v-model="keadaan" class="isian md:w-auto" aria-label="Saring keadaan"><option value="">Semua keadaan</option>
        <option v-for="(v, k) in KEADAAN_SP_SANTRI" :key="k" :value="k">{{ v.n }}</option></select>
      <select v-model="tingkat" class="isian md:w-auto" aria-label="Saring tingkat"><option value="">Semua tingkat</option>
        <option v-for="t in [1, 2, 3]" :key="t" :value="t">{{ TINGKAT_SP_SANTRI[t].singkat }}</option></select>
      <select v-model="jenjang" class="isian md:w-auto" aria-label="Saring jenjang"><option value="">Semua jenjang</option><option value="wustha">Kesetaraan Wustha</option><option value="sma">SMA</option></select>
      <div class="grid w-full grid-cols-2 gap-3 md:w-auto md:min-w-[22rem]"><InputTanggal class="tanpa-label" v-model="mulai" label="Diusulkan dari" /><InputTanggal class="tanpa-label" v-model="selesai" label="Sampai" /></div>
      <button v-if="hak.usul" class="tombol-utama hidden lg:inline-flex" @click="lembarUsul = true"><PhPlus :size="20" weight="bold" /> Usulkan SP</button>
    </SaringCorong>
    <div class="mt-3 flex flex-wrap items-end gap-2 md:justify-end">
      <button class="tombol-garis min-h-[44px] px-3 text-sm" :disabled="!tampil.length" @click="excel"><PhFileXls :size="18" weight="duotone" /> Ekspor</button>
      <button class="tombol-garis min-h-[44px] px-3 text-sm" :disabled="!tampil.length" @click="pratinjau = true"><PhPrinter :size="18" weight="duotone" /> Cetak Rekap</button>
    </div>

    <p v-if="memuat && !daftar.length" class="py-10 text-center text-teks3">Memuat surat peringatan…</p>
    <div v-else-if="!tampil.length" class="kartu mt-4 flex flex-col items-center p-10 text-center">
      <span class="chip-ikon w-presensi h-14 w-14 rounded-2xl"><PhCheckCircle :size="30" weight="duotone" /></span>
      <p class="mt-3 font-semibold">Tidak ada surat peringatan pada rentang ini.</p>
      <p v-if="hak.usul" class="mt-1 text-sm text-teks3">Ketuk "Usulkan SP" untuk mengusulkan surat peringatan berdasarkan catatan pelanggaran.</p>
    </div>
    <ul v-else class="mt-4 grid gap-3 md:grid-cols-2">
      <li v-for="x in tampil" :key="x.id">
        <button type="button" :class="['kartu sp flex w-full items-start gap-3 p-4 text-left transition hover:shadow-apung', 'w-' + TINGKAT_SP_SANTRI[x.tingkat].w, ['batal', 'dicabut', 'berakhir'].includes(x.keadaan) && 'redup']" @click="buka(x)">
          <span class="chip-ikon h-12 w-12 text-sm font-extrabold">{{ TINGKAT_SP_SANTRI[x.tingkat].singkat }}</span>
          <span class="min-w-0 flex-1">
            <span class="flex flex-wrap items-center gap-1.5"><span :class="['lencana', 'w-' + KEADAAN_SP_SANTRI[x.keadaan].w]">{{ KEADAAN_SP_SANTRI[x.keadaan].n }}</span>
              <span v-if="x.status === 'terbit' && !x.diserahkan_pada" class="lencana w-pengajuan">Belum diserahkan ke orang tua</span>
              <span v-if="x.status_diubah" class="lencana w-klinik">Status santri: Berhenti</span></span>
            <span class="mt-1 block font-bold leading-snug text-teks">{{ x.nama }}</span>
            <span class="block truncate text-sm text-teks2">{{ x.nis }} · {{ x.kelas || '–' }}{{ x.kamar ? ' · ' + x.kamar : '' }}</span>
            <span class="mt-0.5 block truncate text-xs text-teks3">{{ x.kategori.join(', ') }}</span>
            <span class="mt-0.5 block text-xs tabular-nums text-teks3">
              <template v-if="x.nomor">{{ x.nomor }} · {{ formatPendek(x.tanggal_surat) }}</template>
              <template v-else>Diusulkan {{ formatPendek(x.diusulkan_pada) }} oleh {{ x.pengusul || '–' }}</template>
              <template v-if="x.keadaan === 'aktif' && x.tingkat < 3"> · berlaku sampai {{ formatPendek(x.berlaku_sampai) }} ({{ sisaHari(x.berlaku_sampai, hi) }} hari lagi)</template></span>
          </span>
        </button>
      </li>
    </ul>
    <TombolAksi v-if="hak.usul" label="Usulkan SP" :ikon="PhPlus" warna="disiplin" class="lg:hidden" @klik="lembarUsul = true" />
    <LembarUsulSPSantri v-if="hak.usul" v-model="lembarUsul" @tersimpan="muat" />

    <!-- Rincian -->
    <LembarBawah v-model="lembarRinci" :judul="pilihan ? `${TINGKAT_SP_SANTRI[pilihan.tingkat].nama} (${TINGKAT_SP_SANTRI[pilihan.tingkat].singkat})` : ''">
      <div v-if="pilihan" :class="['space-y-4 pb-2', 'w-' + TINGKAT_SP_SANTRI[pilihan.tingkat].w]">
        <div class="flex items-start gap-3">
          <span class="chip-ikon h-12 w-12 text-sm font-extrabold">{{ TINGKAT_SP_SANTRI[pilihan.tingkat].singkat }}</span>
          <div class="min-w-0 flex-1"><p class="text-lg font-bold">{{ pilihan.nama }}</p>
            <p class="text-sm text-teks3">NIS {{ pilihan.nis }} · {{ pilihan.kelas || '–' }}{{ pilihan.kamar ? ' · ' + pilihan.kamar : '' }}</p>
            <p class="mt-1 flex flex-wrap gap-1"><span :class="['lencana', 'w-' + KEADAAN_SP_SANTRI[pilihan.keadaan].w]">{{ KEADAAN_SP_SANTRI[pilihan.keadaan].n }}</span>
              <span v-if="pilihan.status_surat" class="lencana w-tatausaha">Surat: {{ STATUS_SURAT_SP[pilihan.status_surat] || pilihan.status_surat }}</span>
              <span v-if="pilihan.status_diubah" class="lencana w-klinik">Status santri diubah: Berhenti</span></p></div>
        </div>
        <dl class="divide-y divide-garis rounded-xl border border-garis px-4 text-sm">
          <div class="grid grid-cols-[40%_1fr] gap-2 py-2"><dt class="text-teks3">Nomor surat</dt><dd class="font-semibold">{{ pilihan.nomor || 'Belum terbit' }}</dd></div>
          <div v-if="pilihan.tanggal_surat" class="grid grid-cols-[40%_1fr] gap-2 py-2"><dt class="text-teks3">{{ pilihan.tingkat === 3 ? 'Berlaku sejak' : 'Masa berlaku' }}</dt>
            <dd class="font-semibold">{{ formatPanjang(pilihan.berlaku_mulai) }}{{ pilihan.tingkat < 3 ? ' – ' + formatPanjang(pilihan.berlaku_sampai) : '' }}</dd></div>
          <div class="grid grid-cols-[40%_1fr] gap-2 py-2"><dt class="text-teks3">Diusulkan</dt><dd>{{ formatWaktu(pilihan.diusulkan_pada) }} oleh {{ pilihan.pengusul || '–' }}</dd></div>
          <div v-if="['terbit', 'dicabut'].includes(pilihan.status)" class="grid grid-cols-[40%_1fr] gap-2 py-2"><dt class="text-teks3">Diserahkan ke orang tua/wali</dt>
            <dd :class="pilihan.diserahkan_pada ? 'font-semibold' : 'text-merah'">{{ pilihan.diserahkan_pada ? formatPanjang(pilihan.diserahkan_pada) + (pilihan.diserahkan_ket ? ' · ' + pilihan.diserahkan_ket : '') : 'Belum dicatat' }}</dd></div>
          <div v-if="pilihan.wali" class="grid grid-cols-[40%_1fr] gap-2 py-2"><dt class="text-teks3">Orang tua/wali</dt><dd>{{ pilihan.wali }}</dd></div>
          <div v-if="pilihan.alasan" class="grid grid-cols-[40%_1fr] gap-2 py-2"><dt class="text-teks3">{{ pilihan.status === 'dicabut' ? 'Alasan pencabutan' : 'Alasan pembatalan' }}</dt><dd>{{ pilihan.alasan }}</dd></div>
        </dl>
        <div><p class="label-isian">Pelanggaran yang menjadi dasar</p>
          <ol class="ml-5 list-decimal space-y-1 text-sm">
            <li v-for="p in pilihan.pelanggaran" :key="p.id"><b>{{ p.kategori }}</b> <span :class="['lencana', 'w-' + TINGKAT_PELANGGARAN[p.tingkat].w]">{{ TINGKAT_PELANGGARAN[p.tingkat].n }}</span>
              <span class="block text-xs text-teks3">{{ formatPendek(p.tanggal) }} · {{ p.uraian }}</span></li>
          </ol></div>
        <div><p class="label-isian">Sanksi</p><ol class="ml-5 list-[lower-alpha] space-y-0.5 text-sm"><li v-for="k in pilihan.sanksi" :key="k">{{ k }}</li></ol></div>
        <div v-if="pilihan.uraian"><p class="label-isian">Uraian</p><p class="whitespace-pre-line text-sm">{{ pilihan.uraian }}</p></div>

        <div v-if="mode === 'serah'" class="space-y-2 rounded-xl border border-garis p-3">
          <InputTanggal v-model="serah.tanggal" label="Tanggal diserahkan" wajib />
          <div><label class="label-isian" for="sps-serah">Keterangan</label><input id="sps-serah" v-model="serah.ket" class="isian" placeholder="Contoh: diserahkan langsung saat pemanggilan orang tua" /></div>
          <div class="flex gap-2"><button class="tombol-garis flex-1" @click="mode = ''">Kembali</button><button class="tombol-utama flex-1" :disabled="proses" @click="simpanSerah">Simpan</button></div>
        </div>
        <div v-else-if="mode" class="space-y-2">
          <label class="label-isian" for="sps-alasan">{{ mode === 'batal' ? 'Alasan pembatalan usulan' : 'Alasan pencabutan surat peringatan' }}</label>
          <textarea id="sps-alasan" v-model="alasan" rows="3" class="isian" />
          <p v-if="mode === 'cabut' && pilihan.status_diubah" class="text-xs text-merah">Status santri yang sudah diubah menjadi Berhenti tidak dipulihkan otomatis; pulihkan di Data Santri bila diperlukan.</p>
          <div class="flex gap-2"><button class="tombol-garis flex-1" @click="mode = ''">Kembali</button>
            <button class="tombol-utama flex-1" :disabled="proses" @click="mode === 'batal' ? batalkan() : cabut()">{{ mode === 'batal' ? 'Batalkan usulan' : 'Cabut surat peringatan' }}</button></div>
        </div>
        <div v-else class="flex flex-wrap gap-2">
          <button v-if="pilihan.letter_id" class="tombol-utama" @click="cetakSurat = true"><PhPrinter :size="20" weight="duotone" /> {{ ['terbit', 'dicabut'].includes(pilihan.status) ? 'Baca dan cetak surat' : 'Pratinjau surat' }}</button>
          <TombolWA v-if="pilihan.status === 'terbit'" :hp="pilihan.hp_wali" :pesan="pesanSPWali(pilihan, lembaga.identitas || {})" label="WA orang tua" />
          <button v-if="['terbit', 'dicabut'].includes(pilihan.status)" class="tombol-garis" @click="mode = 'serah'"><PhHandshake :size="20" weight="duotone" /> {{ pilihan.diserahkan_pada ? 'Ubah penyerahan' : 'Catat penyerahan' }}</button>
          <button v-if="pilihan.letter_id && hak.tu" class="tombol-garis" @click="bukaSurat(pilihan)"><PhEnvelopeOpen :size="20" weight="duotone" /> Buka di Surat keluar</button>
          <button v-if="bolehBatal(pilihan)" class="tombol-garis text-merah" @click="mode = 'batal'"><PhXCircle :size="20" weight="duotone" /> Batalkan usulan</button>
          <button v-if="bolehCabut(pilihan)" class="tombol-garis text-merah" @click="mode = 'cabut'"><PhProhibit :size="20" weight="duotone" /> Cabut SP</button>
          <router-link :to="`/santri/${pilihan.student_id}`" class="tombol-garis"><PhUserCircle :size="20" weight="duotone" /> Biodata</router-link>
        </div>
      </div>
    </LembarBawah>
    <CetakSuratTeguran v-model="cetakSurat" :sp="pilihan" />

    <!-- Cetak rekap F4 mendatar -->
    <DokumenCetak jenis="disiplin_sp" v-model:pratinjau="pratinjau" mendatar :judul="`Rekap Surat Peringatan Santri ${periodeRentang(mulai, selesai)}`" :subjudul="jenjang ? (jenjang === 'sma' ? 'SMA' : 'Kesetaraan Wustha') : 'Seluruh jenjang'"
      :pencetak="sesi.pengguna?.nama_lengkap" :nama-berkas="namaBerkas('Rekap Surat Peringatan Santri', periodeRentang(mulai, selesai))">
      <table class="tabel" style="font-size: 9pt">
        <colgroup><col style="width:3%"><col style="width:7%"><col style="width:14%"><col style="width:6%"><col style="width:5%"><col style="width:20%"><col style="width:13%"><col style="width:8%"><col style="width:8%"><col style="width:8%"><col style="width:8%"></colgroup>
        <thead><tr><th>No.</th><th>NIS</th><th>Nama</th><th>Kelas</th><th>Tingkat</th><th>Pelanggaran</th><th>Nomor surat</th><th>Tanggal surat</th><th>Berlaku sampai</th><th>Keadaan</th><th>Diserahkan</th></tr></thead>
        <tbody>
          <tr v-for="(x, i) in tampil" :key="x.id">
            <td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ x.nis }}</td><td>{{ x.nama }}</td><td class="tengah">{{ x.kelas || '–' }}</td>
            <td class="tengah">{{ TINGKAT_SP_SANTRI[x.tingkat].singkat }}</td><td>{{ x.kategori.join('; ') }}</td><td>{{ x.nomor || 'Belum terbit' }}</td>
            <td class="tengah">{{ x.tanggal_surat ? formatPendek(x.tanggal_surat) : '–' }}</td><td class="tengah">{{ x.tingkat < 3 && x.berlaku_sampai ? formatPendek(x.berlaku_sampai) : '–' }}</td>
            <td>{{ KEADAAN_SP_SANTRI[x.keadaan].n }}</td><td class="tengah">{{ x.diserahkan_pada ? formatPendek(x.diserahkan_pada) : '–' }}</td>
          </tr>
        </tbody>
      </table>
      <p style="margin-top: 6pt; font-size: 9pt">Jumlah: {{ tampil.length }} surat peringatan (SP-1 {{ tampil.filter((x) => x.tingkat === 1).length }}, SP-2 {{ tampil.filter((x) => x.tingkat === 2).length }},
        SP-3 {{ tampil.filter((x) => x.tingkat === 3).length }}). Dokumen ini bersifat terbatas.</p>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan_tertulis || 'Direktur', nama: direktur.nama || '', niy: direktur.niy }"
          :kanan="kesantrian ? { jabatan: kesantrian.jabatan_tertulis, nama: kesantrian.nama, niy: kesantrian.niy } : { jabatan: 'Yang membuat rekap', nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
      </template>
    </DokumenCetak>
  </div>
</template>
<style scoped>
.kartu.sp { border-left: 4px solid var(--c); }
.redup { opacity: .72; }
</style>
