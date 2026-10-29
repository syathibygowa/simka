<!-- SIMKA PRO | src/pages/persuratan/TabSuratTeguran.vue | v1.4 | 14.30.0: label saringan yang sudah jelas disembunyikan (hemat ruang) | 29/10/2026 -->
<script setup>
// Tab Persuratan → Surat Teguran.
//   Daftar    : SP yang boleh dilihat (penerima tidak melihat usulan sebelum terbit; atasan langsung melihat anggota unitnya;
//               pemegang fitur Surat teguran melihat semua). Saring keadaan, tingkat, bidang, rentang tanggal usul.
//   Rincian   : pelanggaran, uraian, ringkasan kehadiran, status surat, tanda terima; buka surat, batalkan usulan, cabut SP.
//   Rekap     : cetak F4 mendatar berkop dan Excel (NIY › Nama › JK).
//   Ketentuan : masa berlaku, penanda tangan, kategori pelanggaran, tembusan (diubah tingkat Kelola).
import { ref, computed, watch, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { PhPlus, PhMagnifyingGlass, PhWarningOctagon, PhHourglassMedium, PhCheckCircle, PhArrowCounterClockwise, PhPrinter, PhFileXls,
  PhListChecks, PhGearSix, PhEnvelopeOpen, PhProhibit, PhXCircle, PhClockCountdown, PhUserCircle } from '@phosphor-icons/vue'
import { useTeguran } from '@/stores/teguran'
import { usePersuratan } from '@/stores/persuratan'
import { useLembaga } from '@/stores/lembaga'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { TINGKAT_SP, KEADAAN_SP, STATUS_SURAT_SP, teksPresensi, sisaHari } from '@/lib/teguran'
import { formatPendek, formatPanjang, formatWaktu, hariIniISO } from '@/lib/tanggal'
import { tambahHari } from '@/lib/persuratan'
import { eksporExcel } from '@/lib/excel'
import { namaBerkas, periodeRentang } from '@/lib/namaBerkas'
import BilahTab from '@/components/BilahTab.vue'
import SaringCorong from '@/components/SaringCorong.vue'
import KartuStatistik from '@/components/KartuStatistik.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import TombolAksi from '@/components/TombolAksi.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import LembarUsulTeguran from './LembarUsulTeguran.vue'
import TabKetentuanTeguran from './TabKetentuanTeguran.vue'
import CetakSuratTeguran from './CetakSuratTeguran.vue'

const props = defineProps({ versi: { type: Number, default: 0 } })
const route = useRoute(); const router = useRouter()
const tg = useTeguran(); const ps = usePersuratan(); const lembaga = useLembaga(); const sesi = useSesi(); const ui = useUI()
const hak = computed(() => ps.hak.teguran || {})
const bagian = ref('daftar')
const BAGIAN = computed(() => [
  { k: 'daftar', n: 'Daftar dan rekap', ikon: PhListChecks, w: 'klinik' },
  ...(hak.value.lihat || hak.value.kelola ? [{ k: 'ketentuan', n: 'Ketentuan', ikon: PhGearSix, w: 'pengaturan' }] : []),
])

// ---------- Data ----------
const daftar = ref([]); const memuat = ref(false)
const mulai = ref(tambahHari(hariIniISO(), -365)); const selesai = ref(hariIniISO())
async function muat() {
  memuat.value = true
  try { daftar.value = await tg.daftar(mulai.value, selesai.value) } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
onMounted(() => { muat(); lembaga.muat().catch(() => {}); bukaDariQuery() })
watch([mulai, selesai, () => props.versi], muat)

const cari = ref(''); const keadaan = ref(''); const tingkat = ref(''); const bidang = ref('')
const daftarBidang = computed(() => [...new Set(daftar.value.map((x) => x.bidang).filter(Boolean))].sort())
const tampil = computed(() => {
  const q = cari.value.toLowerCase().trim()
  return daftar.value.filter((x) => (!keadaan.value || x.keadaan === keadaan.value) && (!tingkat.value || x.tingkat === Number(tingkat.value))
    && (!bidang.value || x.bidang === bidang.value) && (!q || `${x.nama} ${x.niy || ''} ${x.nomor || ''} ${x.unit || ''} ${x.pengusul || ''}`.toLowerCase().includes(q)))
})
const hitung = (k) => daftar.value.filter((x) => x.keadaan === k).length
const KARTU = computed(() => [
  { judul: 'SP aktif', nilai: memuat.value ? '…' : hitung('aktif'), ikon: PhWarningOctagon, warna: 'klinik', ket: 'Masih dalam masa berlaku' },
  { judul: 'Diproses Tata Usaha', nilai: memuat.value ? '…' : hitung('diusulkan'), ikon: PhHourglassMedium, warna: 'shift', ket: 'Usulan belum terbit' },
  { judul: 'Berakhir', nilai: memuat.value ? '…' : hitung('berakhir'), ikon: PhCheckCircle, warna: 'presensi', ket: 'Masa berlaku lewat' },
  { judul: 'Dicabut', nilai: memuat.value ? '…' : hitung('dicabut'), ikon: PhArrowCounterClockwise, warna: 'hakakses', ket: 'Tidak lagi dihitung' },
])
const hi = hariIniISO()

// ---------- Usul ----------
const lembarUsul = ref(false)

// ---------- Rincian ----------
const pilihan = ref(null); const lembarRinci = ref(false); const mode = ref(''); const alasan = ref(''); const proses = ref(false); const cetakSurat = ref(false)
function buka(x) { pilihan.value = x; mode.value = ''; alasan.value = ''; lembarRinci.value = true }
function bukaDariQuery() {
  const id = route.query.sp
  if (typeof id !== 'string') return
  const tunggu = setInterval(() => { if (!memuat.value) { clearInterval(tunggu); const x = daftar.value.find((d) => d.id === id); if (x) buka(x) } }, 200)
  setTimeout(() => clearInterval(tunggu), 8000)
  router.replace({ path: '/persuratan/teguran', query: {} })
}
const bolehBatal = (x) => x?.status === 'diusulkan' && (x.saya_pengusul || hak.value.tu || hak.value.kelola)
const bolehCabut = (x) => x?.status === 'terbit' && hak.value.kelola
async function jalankan(fn, pesan) {
  if (alasan.value.trim().length < 5) return ui.toast('Tuliskan alasannya (minimal 5 huruf).', 'galat')
  proses.value = true
  try { await fn(); ui.toast(pesan); lembarRinci.value = false; await muat() } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
const batalkan = () => jalankan(() => tg.batal(pilihan.value.id, alasan.value.trim()), 'Usulan surat teguran dibatalkan; draf suratnya ikut dibatalkan.')
const cabut = () => jalankan(() => tg.cabut(pilihan.value.id, alasan.value.trim()), 'Surat teguran dicabut dan pegawai diberi tahu.')
function bukaSurat(x) { lembarRinci.value = false; router.push({ path: '/persuratan/keluar', query: { surat: x.letter_id } }) }

// ---------- Rekap ----------
const pratinjau = ref(false)
const KOLOM = [
  { judul: 'NIY', kunci: 'niy' }, { judul: 'Nama', kunci: 'nama' }, { judul: 'JK', kunci: 'jenis_kelamin' }, { judul: 'Bidang/unit', kunci: 'unit' },
  { judul: 'Tingkat', kunci: 'tingkat', format: (v) => TINGKAT_SP[v]?.singkat }, { judul: 'Pelanggaran', kunci: 'kategori' }, { judul: 'Uraian', kunci: 'uraian' },
  { judul: 'Nomor surat', kunci: 'nomor' }, { judul: 'Tanggal surat', kunci: 'tanggal_surat', tanggal: true }, { judul: 'Berlaku sampai', kunci: 'berlaku_sampai', tanggal: true },
  { judul: 'Keadaan', kunci: 'keadaan', format: (v) => KEADAAN_SP[v]?.n }, { judul: 'Diterima pegawai', kunci: 'diterima_pada', format: (v) => (v ? formatWaktu(v) : 'Belum') },
  { judul: 'Pengusul', kunci: 'pengusul' }, { judul: 'Alasan batal/cabut', kunci: 'alasan' },
]
const judulRekap = computed(() => `Rekap Surat Teguran ${periodeRentang(mulai.value, selesai.value)}`)
function excel() {
  if (!tampil.value.length) return ui.toast('Tidak ada data untuk diekspor.', 'galat')
  eksporExcel(`${namaBerkas('Rekap Surat Teguran', periodeRentang(mulai.value, selesai.value))}.xlsx`, KOLOM, tampil.value, 'Surat Teguran')
}
const direktur = computed(() => lembaga.signatories?.find((s) => /^direktur$/i.test(s.jabatan_tertulis)) || lembaga.signatories?.[0] || {})
</script>
<template>
  <div>
    <BilahTab v-if="BAGIAN.length > 1" v-model="bagian" :tab="BAGIAN" kecil label="Bagian surat teguran" class="mb-4" />
    <TabKetentuanTeguran v-if="bagian === 'ketentuan'" />
    <template v-else>
      <section class="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <KartuStatistik v-for="k in KARTU" :key="k.judul" :judul="k.judul" :nilai="k.nilai" :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket" />
      </section>

      <SaringCorong class="mt-4" :jumlah="[keadaan, tingkat, bidang].filter(Boolean).length" :ringkasan="[`${formatPendek(mulai)} – ${formatPendek(selesai)}`, keadaan && KEADAAN_SP[keadaan].n, tingkat && TINGKAT_SP[tingkat].singkat, bidang].filter(Boolean).join(' · ')" judul="Saring surat teguran">
        <template #cari><div class="relative"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
        <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari nama, NIY, nomor surat" aria-label="Cari surat teguran" /></div></template>
        <select v-model="keadaan" class="isian md:w-auto" aria-label="Saring keadaan"><option value="">Semua keadaan</option>
          <option v-for="(v, k) in KEADAAN_SP" :key="k" :value="k">{{ v.n }}</option></select>
        <select v-model="tingkat" class="isian md:w-auto" aria-label="Saring tingkat"><option value="">Semua tingkat</option>
          <option v-for="t in [1, 2, 3]" :key="t" :value="t">{{ TINGKAT_SP[t].singkat }}</option></select>
        <select v-if="daftarBidang.length > 1" v-model="bidang" class="isian md:w-auto" aria-label="Saring bidang"><option value="">Semua bidang</option>
          <option v-for="b in daftarBidang" :key="b" :value="b">{{ b }}</option></select>
        <div class="grid w-full grid-cols-2 gap-3 md:w-auto md:min-w-[22rem]"><InputTanggal class="tanpa-label" v-model="mulai" label="Diusulkan dari" /><InputTanggal class="tanpa-label" v-model="selesai" label="Sampai" /></div>
        <button v-if="hak.usul" class="tombol-utama hidden lg:inline-flex" @click="lembarUsul = true"><PhPlus :size="20" weight="bold" /> Usulkan SP</button>
      </SaringCorong>
      <div class="mt-3 flex flex-wrap items-end gap-2 md:justify-end">
        <button class="tombol-garis min-h-[44px] px-3 text-sm" :disabled="!tampil.length" @click="excel"><PhFileXls :size="18" weight="duotone" /> Ekspor</button>
        <button class="tombol-garis min-h-[44px] px-3 text-sm" :disabled="!tampil.length" @click="pratinjau = true"><PhPrinter :size="18" weight="duotone" /> Cetak Rekap</button>
      </div>

      <p v-if="memuat && !daftar.length" class="py-10 text-center text-teks3">Memuat surat teguran…</p>
      <div v-else-if="!tampil.length" class="kartu mt-4 flex flex-col items-center p-10 text-center">
        <span class="chip-ikon w-presensi h-14 w-14 rounded-2xl"><PhCheckCircle :size="30" weight="duotone" /></span>
        <p class="mt-3 font-semibold">Tidak ada surat teguran pada rentang ini.</p>
        <p v-if="hak.usul" class="mt-1 text-sm text-teks3">Ketuk "Usulkan SP" untuk mengusulkan surat teguran bagi pegawai yang Anda pimpin.</p>
      </div>
      <ul v-else class="mt-4 grid gap-3 md:grid-cols-2">
        <li v-for="x in tampil" :key="x.id">
          <button type="button" :class="['kartu sp flex w-full items-start gap-3 p-4 text-left transition hover:shadow-apung', 'w-' + TINGKAT_SP[x.tingkat].w, ['batal', 'dicabut', 'berakhir'].includes(x.keadaan) && 'redup']" @click="buka(x)">
            <span class="chip-ikon h-12 w-12 text-sm font-extrabold">{{ TINGKAT_SP[x.tingkat].singkat }}</span>
            <span class="min-w-0 flex-1">
              <span class="flex flex-wrap items-center gap-1.5"><span :class="['lencana', 'w-' + KEADAAN_SP[x.keadaan].w]">{{ KEADAAN_SP[x.keadaan].n }}</span>
                <span v-if="x.keadaan === 'aktif' && !x.diterima_pada" class="lencana w-pengajuan">Belum diterima pegawai</span></span>
              <span class="mt-1 block font-bold leading-snug text-teks">{{ x.nama }}</span>
              <span class="block truncate text-sm text-teks2">{{ x.niy || 'NIY –' }} · {{ x.unit || '–' }}</span>
              <span class="mt-0.5 block truncate text-xs text-teks3">{{ x.kategori.join(', ') }}</span>
              <span class="mt-0.5 block text-xs tabular-nums text-teks3">
                <template v-if="x.nomor">{{ x.nomor }} · {{ formatPendek(x.tanggal_surat) }}</template>
                <template v-else>Diusulkan {{ formatPendek(x.diusulkan_pada) }} oleh {{ x.pengusul || '–' }}</template>
                <template v-if="x.keadaan === 'aktif'"> · berlaku sampai {{ formatPendek(x.berlaku_sampai) }} ({{ sisaHari(x.berlaku_sampai, hi) }} hari lagi)</template></span>
            </span>
          </button>
        </li>
      </ul>
      <TombolAksi v-if="hak.usul" label="Usulkan SP" :ikon="PhPlus" warna="klinik" class="lg:hidden" @klik="lembarUsul = true" />
    </template>

    <LembarUsulTeguran v-model="lembarUsul" @tersimpan="muat" />

    <!-- Rincian -->
    <LembarBawah v-model="lembarRinci" :judul="pilihan ? `${TINGKAT_SP[pilihan.tingkat].nama}` : ''">
      <div v-if="pilihan" :class="['space-y-4 pb-2', 'w-' + TINGKAT_SP[pilihan.tingkat].w]">
        <div class="flex items-start gap-3">
          <span class="chip-ikon h-12 w-12 text-sm font-extrabold">{{ TINGKAT_SP[pilihan.tingkat].singkat }}</span>
          <div class="min-w-0 flex-1"><p class="text-lg font-bold">{{ pilihan.nama }}</p>
            <p class="text-sm text-teks3">{{ pilihan.niy || 'NIY –' }} · {{ pilihan.jabatan || '' }} · {{ pilihan.unit || '–' }}</p>
            <p class="mt-1 flex flex-wrap gap-1"><span :class="['lencana', 'w-' + KEADAAN_SP[pilihan.keadaan].w]">{{ KEADAAN_SP[pilihan.keadaan].n }}</span>
              <span v-if="pilihan.status_surat" class="lencana w-tatausaha">Surat: {{ STATUS_SURAT_SP[pilihan.status_surat] || pilihan.status_surat }}</span></p></div>
        </div>
        <dl class="divide-y divide-garis rounded-xl border border-garis px-4 text-sm">
          <div class="grid grid-cols-[40%_1fr] gap-2 py-2"><dt class="text-teks3">Nomor surat</dt><dd class="font-semibold">{{ pilihan.nomor || 'Belum terbit' }}</dd></div>
          <div v-if="pilihan.tanggal_surat" class="grid grid-cols-[40%_1fr] gap-2 py-2"><dt class="text-teks3">Masa berlaku</dt>
            <dd class="font-semibold">{{ formatPanjang(pilihan.berlaku_mulai) }} – {{ formatPanjang(pilihan.berlaku_sampai) }}</dd></div>
          <div class="grid grid-cols-[40%_1fr] gap-2 py-2"><dt class="text-teks3">Diusulkan</dt><dd>{{ formatWaktu(pilihan.diusulkan_pada) }} oleh {{ pilihan.pengusul || '–' }}</dd></div>
          <div v-if="pilihan.status === 'terbit' || pilihan.status === 'dicabut'" class="grid grid-cols-[40%_1fr] gap-2 py-2"><dt class="text-teks3">Diterima pegawai</dt>
            <dd :class="pilihan.diterima_pada ? 'font-semibold' : 'text-merah'">{{ pilihan.diterima_pada ? formatWaktu(pilihan.diterima_pada) : 'Belum menyatakan menerima' }}</dd></div>
          <div v-if="pilihan.alasan" class="grid grid-cols-[40%_1fr] gap-2 py-2"><dt class="text-teks3">{{ pilihan.status === 'dicabut' ? 'Alasan pencabutan' : 'Alasan pembatalan' }}</dt><dd>{{ pilihan.alasan }}</dd></div>
        </dl>
        <div><p class="label-isian">Pelanggaran</p><ol class="ml-5 list-decimal space-y-0.5 text-sm"><li v-for="k in pilihan.kategori" :key="k">{{ k }}</li></ol></div>
        <div><p class="label-isian">Uraian</p><p class="whitespace-pre-line text-sm">{{ pilihan.uraian }}</p></div>
        <p v-if="pilihan.ringkasan_presensi" class="rounded-lg bg-permukaan2 p-3 text-sm">{{ teksPresensi(pilihan.ringkasan_presensi) }}</p>

        <div v-if="mode" class="space-y-2">
          <label class="label-isian" for="sp-alasan">{{ mode === 'batal' ? 'Alasan pembatalan usulan' : 'Alasan pencabutan surat teguran' }}</label>
          <textarea id="sp-alasan" v-model="alasan" rows="3" class="isian" />
          <div class="flex gap-2"><button class="tombol-garis flex-1" @click="mode = ''">Kembali</button>
            <button class="tombol-utama flex-1" :disabled="proses" @click="mode === 'batal' ? batalkan() : cabut()">{{ mode === 'batal' ? 'Batalkan usulan' : 'Cabut surat teguran' }}</button></div>
        </div>
        <div v-else class="flex flex-wrap gap-2">
          <button v-if="pilihan.letter_id && ['terbit', 'dicabut'].includes(pilihan.status)" class="tombol-utama" @click="cetakSurat = true"><PhPrinter :size="20" weight="duotone" /> Baca dan cetak surat</button>
          <button v-if="pilihan.letter_id && (hak.tu || pilihan.saya_pengusul)" class="tombol-garis" @click="bukaSurat(pilihan)"><PhEnvelopeOpen :size="20" weight="duotone" /> Buka di Surat keluar</button>
          <button v-if="bolehBatal(pilihan)" class="tombol-garis text-merah" @click="mode = 'batal'"><PhXCircle :size="20" weight="duotone" /> Batalkan usulan</button>
          <button v-if="bolehCabut(pilihan)" class="tombol-garis text-merah" @click="mode = 'cabut'"><PhProhibit :size="20" weight="duotone" /> Cabut SP</button>
          <router-link v-if="sesi.bolehAdmin('kelola_pegawai') || sesi.tingkat('data_pegawai') >= 1" :to="`/pegawai/${pilihan.employee_id}`" class="tombol-garis"><PhUserCircle :size="20" weight="duotone" /> Biodata</router-link>
        </div>
        <p v-if="pilihan.keadaan === 'diusulkan'" class="flex gap-2 text-xs text-teks3"><PhClockCountdown :size="16" class="shrink-0" />Pegawai belum melihat usulan ini. Surat dikirim kepadanya setelah ditandatangani dan terbit.</p>
      </div>
    </LembarBawah>
    <CetakSuratTeguran v-model="cetakSurat" :sp="pilihan" />

    <!-- Cetak rekap F4 mendatar -->
    <DokumenCetak jenis="teguran_rekap" v-model:pratinjau="pratinjau" mendatar :judul="judulRekap" :subjudul="bidang || 'Seluruh bidang'" :pencetak="sesi.pengguna?.nama_lengkap"
      :nama-berkas="namaBerkas(bidang || 'Seluruh bidang', 'Rekap Surat Teguran', periodeRentang(mulai, selesai))">
      <table class="tabel" style="font-size: 9pt">
        <colgroup><col style="width:3%"><col style="width:9%"><col style="width:13%"><col style="width:3%"><col style="width:10%"><col style="width:5%"><col style="width:17%">
          <col style="width:13%"><col style="width:8%"><col style="width:8%"><col style="width:7%"><col style="width:7%"></colgroup>
        <thead><tr><th>No.</th><th>NIY</th><th>Nama</th><th>JK</th><th>Bidang/unit</th><th>Tingkat</th><th>Pelanggaran</th><th>Nomor surat</th><th>Tanggal surat</th>
          <th>Berlaku sampai</th><th>Keadaan</th><th>Diterima</th></tr></thead>
        <tbody>
          <tr v-for="(x, i) in tampil" :key="x.id">
            <td class="tengah">{{ i + 1 }}</td><td>{{ x.niy || '–' }}</td><td>{{ x.nama }}</td><td class="tengah">{{ x.jenis_kelamin }}</td><td>{{ x.unit || '–' }}</td>
            <td class="tengah">{{ TINGKAT_SP[x.tingkat].singkat }}</td><td>{{ x.kategori.join('; ') }}</td><td>{{ x.nomor || 'Belum terbit' }}</td>
            <td class="tengah">{{ x.tanggal_surat ? formatPendek(x.tanggal_surat) : '–' }}</td><td class="tengah">{{ x.berlaku_sampai ? formatPendek(x.berlaku_sampai) : '–' }}</td>
            <td>{{ KEADAAN_SP[x.keadaan].n }}</td><td class="tengah">{{ x.diterima_pada ? formatPendek(x.diterima_pada) : '–' }}</td>
          </tr>
        </tbody>
      </table>
      <p style="margin-top: 6pt; font-size: 9pt">Jumlah: {{ tampil.length }} surat teguran (aktif {{ tampil.filter((x) => x.keadaan === 'aktif').length }}, diproses {{ tampil.filter((x) => x.keadaan === 'diusulkan').length }},
        berakhir {{ tampil.filter((x) => x.keadaan === 'berakhir').length }}, dicabut {{ tampil.filter((x) => x.keadaan === 'dicabut').length }}). Dokumen ini bersifat terbatas.</p>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan_tertulis || 'Direktur', nama: direktur.nama || '', niy: direktur.niy }"
          :kanan="{ jabatan: 'Yang membuat rekap', nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
      </template>
    </DokumenCetak>
  </div>
</template>
<style scoped>
.kartu.sp { border-left: 4px solid var(--c); }
.redup { opacity: .72; }
</style>
