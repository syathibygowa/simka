<!-- SIMKA PRO | src/pages/klinik/TabKasus.vue | v1.0 | Fase 6 – Tahap 1 Dasar Klinik | 06/10/2026 -->
<script setup>
// Daftar kasus klinik untuk empat cakupan:
//   antrean      : rujukan menunggu pemeriksaan; yang lewat batas waktu ditandai merah dan tampil paling atas
//   dirawat      : kasus yang sedang ditangani (istirahat, rawat, rujuk, dipulangkan)
//   riwayat      : semua kasus pada rentang tanggal
//   rujukan_saya : rujukan yang saya buat / santri asuhan saya (hanya ringkasan, tanpa catatan medis)
// Daftar diperbarui langsung saat ada kasus baru atau berubah.
import { ref, computed, watch, onMounted, onBeforeUnmount } from 'vue'
import {
  PhMagnifyingGlass, PhStethoscope, PhUserPlus, PhPaperPlaneTilt, PhX, PhCheckCircle, PhHourglass, PhSiren, PhSun, PhMoon,
  PhBed, PhFirstAidKit, PhAmbulance, PhHouseLine, PhClipboardText, PhCalendarCheck, PhUsersThree, PhPersonSimpleWalk, PhArrowRight,
} from '@phosphor-icons/vue'
import { useKlinik } from '@/stores/klinik'
import { useUI } from '@/stores/ui'
import { KLINIK, STATUS_KASUS, TINDAK_LANJUT, SUMBER_RUJUKAN, labelKasus, sisaBatas } from '@/lib/klinik'
import { formatWaktu, formatPendek, hariIniISO } from '@/lib/tanggal'
import KartuStatistik from '@/components/KartuStatistik.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import TombolAksi from '@/components/TombolAksi.vue'
import LembarRujuk from './LembarRujuk.vue'
import LembarPeriksa from './LembarPeriksa.vue'
import LembarKasus from './LembarKasus.vue'

const props = defineProps({ cakupan: { type: String, required: true } })
const kl = useKlinik(); const ui = useUI()
const daftar = ref([]); const memuat = ref(false); const cari = ref(''); const klinik = ref('')
const awalBulan = () => hariIniISO().slice(0, 8) + '01'
const mulai = ref(awalBulan()); const selesai = ref(hariIniISO())
const kini = ref(Date.now()); let detak

async function muat() {
  memuat.value = true
  try {
    const rentang = ['riwayat', 'rujukan_saya'].includes(props.cakupan)
    daftar.value = await kl.daftar(props.cakupan, rentang ? mulai.value : null, rentang ? selesai.value : null, klinik.value || null)
  } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
watch(() => props.cakupan, muat)
watch([mulai, selesai, klinik], muat)
onMounted(() => { muat(); kl.dengarkan(muat); detak = setInterval(() => (kini.value = Date.now()), 30000) })
onBeforeUnmount(() => { kl.berhenti(); clearInterval(detak) })

/** Pilihan klinik hanya bila pengguna dapat melihat keduanya. */
const duaKlinik = computed(() => kl.hak.atur || kl.hak.pimpinan || kl.hak.petugas.length > 1)
const tampil = computed(() => {
  const q = cari.value.toLowerCase().trim()
  return daftar.value.filter((k) => !q || `${k.nama} ${k.nis} ${k.kelas || ''} ${k.kamar || ''} ${k.keluhan}`.toLowerCase().includes(q))
})
const hitung = (f) => daftar.value.filter(f).length
const statistik = computed(() => {
  const c = props.cakupan
  if (c === 'antrean') return [
    { judul: 'Menunggu', nilai: daftar.value.length, ikon: PhHourglass, warna: 'pengajuan', ket: 'Belum diperiksa' },
    { judul: 'Lewat batas', nilai: hitung((k) => k.lewat_batas), ikon: PhSiren, warna: 'klinik', ket: 'Segera periksa' },
    { judul: 'Periksa hari ini', nilai: hitung((k) => k.waktu_periksa !== 'besok'), ikon: PhSun, warna: 'beranda', ket: 'Rujukan hari ini' },
    { judul: 'Periksa besok', nilai: hitung((k) => k.waktu_periksa === 'besok'), ikon: PhMoon, warna: 'agenda', ket: 'Dijadwalkan besok' },
  ]
  if (c === 'dirawat') return [
    { judul: 'Istirahat di kamar', nilai: hitung((k) => k.tindak_lanjut === 'istirahat'), ikon: PhBed, warna: 'santri', ket: 'Dipantau musyrif' },
    { judul: 'Rawat di klinik', nilai: hitung((k) => k.tindak_lanjut === 'rawat'), ikon: PhFirstAidKit, warna: 'klinik', ket: 'Di ruang klinik' },
    { judul: 'Dirujuk', nilai: hitung((k) => k.tindak_lanjut === 'rujuk'), ikon: PhAmbulance, warna: 'shift', ket: 'RS/puskesmas' },
    { judul: 'Dipulangkan', nilai: hitung((k) => k.tindak_lanjut === 'pulang'), ikon: PhHouseLine, warna: 'pengumuman', ket: 'Pemulihan di rumah' },
  ]
  return [
    { judul: 'Jumlah kasus', nilai: daftar.value.length, ikon: PhClipboardText, warna: 'laporan', ket: c === 'riwayat' ? 'Pada rentang tanggal' : 'Rujukan terkait saya' },
    { judul: 'Menunggu', nilai: hitung((k) => k.status === 'menunggu'), ikon: PhHourglass, warna: 'pengajuan', ket: 'Belum diperiksa' },
    { judul: 'Ditangani', nilai: hitung((k) => k.status === 'ditangani'), ikon: PhStethoscope, warna: 'agenda', ket: 'Masih sakit' },
    { judul: 'Selesai', nilai: hitung((k) => k.status === 'selesai'), ikon: PhCheckCircle, warna: 'presensi', ket: 'Sembuh/kembali beraktivitas' },
  ]
})
const kosong = computed(() => ({
  antrean: 'Tidak ada rujukan yang menunggu. Alhamdulillah.', dirawat: 'Tidak ada santri yang sedang ditangani.',
  riwayat: 'Tidak ada kasus pada rentang tanggal ini.', rujukan_saya: 'Belum ada rujukan untuk santri asuhan Anda pada rentang ini.',
}[props.cakupan]))

// ---------- Lembar ----------
const lembarRujuk = ref(false); const lembarPeriksa = ref(false); const lembarKasus = ref(false)
const kasusPilih = ref(null); const idRincian = ref('')
function periksa(k) { kasusPilih.value = k; lembarPeriksa.value = true }
function pasienDatang() { kasusPilih.value = null; lembarPeriksa.value = true }
function rincian(k) { idRincian.value = k.id; lembarKasus.value = true }
const bisaPasienDatang = computed(() => kl.hak.atur || kl.hak.petugas.length > 0)

const lembarBatal = ref(false); const alasan = ref(''); const proses = ref(false)
function bukaBatal(k) { kasusPilih.value = k; alasan.value = ''; lembarBatal.value = true }
async function batal() {
  if (alasan.value.trim().length < 5) return ui.toast('Tuliskan alasan pembatalan (minimal 5 huruf).', 'galat')
  proses.value = true
  try { await kl.batalkan(kasusPilih.value.id, alasan.value.trim()); lembarBatal.value = false; ui.toast('Rujukan dibatalkan.'); await muat() }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
const lembarSembuh = ref(false); const catSembuh = ref('')
function bukaSembuh(k) { kasusPilih.value = k; catSembuh.value = ''; lembarSembuh.value = true }
async function sembuh() {
  proses.value = true
  try { await kl.selesaikan(kasusPilih.value.id, catSembuh.value.trim()); lembarSembuh.value = false; ui.toast(`${kasusPilih.value.nama} dinyatakan sembuh.`); await muat() }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
const selesaiLembar = async () => { await muat() }
const ikonStatus = (k) => (k.status === 'ditangani' && k.tindak_lanjut ? TINDAK_LANJUT[k.tindak_lanjut].ikon : k.status === 'selesai' && k.hasil === 'kembali' ? PhPersonSimpleWalk : STATUS_KASUS[k.status].ikon)
</script>
<template>
  <div>
    <div class="flex flex-wrap items-center gap-2">
      <select v-if="duaKlinik" v-model="klinik" class="isian w-auto" aria-label="Saring klinik">
        <option value="">Klinik putra dan putri</option><option value="putra">{{ KLINIK.putra }}</option><option value="putri">{{ KLINIK.putri }}</option>
      </select>
      <div class="relative min-w-[200px] flex-1"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
        <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari santri, kelas, kamar, atau keluhan" aria-label="Cari kasus" /></div>
      <button v-if="kl.hak.rujuk" class="tombol-utama hidden lg:inline-flex" @click="lembarRujuk = true"><PhPaperPlaneTilt :size="20" weight="duotone" /> Rujuk santri</button>
      <button v-if="bisaPasienDatang && cakupan !== 'rujukan_saya'" class="tombol-garis w-klinik" @click="pasienDatang"><PhUserPlus :size="20" weight="duotone" style="color: var(--c)" /> Pasien datang</button>
    </div>
    <div v-if="cakupan === 'riwayat' || cakupan === 'rujukan_saya'" class="mt-3 grid grid-cols-2 gap-3 sm:max-w-md">
      <InputTanggal v-model="mulai" label="Dari tanggal" /><InputTanggal v-model="selesai" label="Sampai tanggal" />
    </div>

    <div class="-mx-4 mt-3 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-4 sm:overflow-visible sm:px-0">
      <KartuStatistik v-for="k in statistik" :key="k.judul" class="w-[44%] shrink-0 snap-start sm:w-auto" :judul="k.judul" :nilai="memuat && !daftar.length ? '…' : k.nilai" :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket" />
    </div>

    <ul class="mt-4 grid gap-3 md:grid-cols-2">
      <li v-for="k in tampil" :key="k.id" class="kartu p-4" :class="[k.lewat_batas ? 'w-klinik kasus-lewat' : 'w-' + labelKasus(k).w]">
        <div class="flex items-start gap-3">
          <span class="chip-ikon h-11 w-11 shrink-0"><component :is="ikonStatus(k)" :size="24" weight="duotone" /></span>
          <div class="min-w-0 flex-1">
            <p class="flex flex-wrap items-center gap-1.5"><b class="truncate">{{ k.nama }}</b>
              <span class="lencana" :class="'w-' + labelKasus(k).w">{{ labelKasus(k).n }}</span>
              <span v-if="k.lewat_batas" class="lencana w-klinik"><PhSiren :size="12" weight="fill" /> Lewat batas</span></p>
            <p class="text-xs text-teks3">{{ k.nis }} · {{ k.kelas ? 'Kelas ' + k.kelas.replace(/^kelas\s*/i, '') : 'Kelas ' + (k.tingkat || '–') }} · {{ k.kamar || 'Kamar –' }} · {{ KLINIK[k.klinik] }}</p>
            <p class="mt-1.5 text-sm font-semibold text-teks">{{ k.keluhan }}</p>
            <p class="text-xs text-teks3">{{ SUMBER_RUJUKAN[k.sumber] }}{{ k.perujuk && k.sumber !== 'datang_sendiri' ? ' · ' + k.perujuk : '' }} · {{ formatWaktu(k.dibuka_pada) }}
              <template v-if="k.jumlah_rujukan > 1"> · {{ k.jumlah_rujukan }}× dirujuk</template></p>
            <p v-if="k.status === 'menunggu'" class="text-xs font-semibold" :class="k.lewat_batas ? 'text-merah' : 'text-teks2'">
              Periksa {{ k.waktu_periksa === 'besok' ? 'besok' : 'hari ini' }} · batas {{ formatWaktu(k.batas_waktu) }} ({{ sisaBatas(k.batas_waktu, kini) }})</p>
            <p v-if="k.kontrol_pada && k.status === 'ditangani'" class="text-xs font-semibold text-teks2"><PhCalendarCheck :size="14" class="inline" /> Kontrol {{ formatWaktu(k.kontrol_pada) }}</p>
            <p v-if="k.pemeriksaan_terakhir" class="mt-1 rounded-lg bg-permukaan2 px-2.5 py-1.5 text-xs text-teks2">
              <b>{{ k.pemeriksaan_terakhir.diagnosis || 'Diperiksa' }}</b>{{ k.pemeriksaan_terakhir.obat ? ' · ' + k.pemeriksaan_terakhir.obat : '' }}
              {{ k.pemeriksaan_terakhir.rujuk_ke ? ' · dirujuk ke ' + k.pemeriksaan_terakhir.rujuk_ke : '' }}
              <span class="block text-teks3">{{ k.pemeriksaan_terakhir.petugas }} · {{ formatWaktu(k.pemeriksaan_terakhir.waktu) }}</span></p>
            <p v-if="k.selesai_pada && k.status !== 'menunggu' && k.status !== 'ditangani'" class="text-xs text-teks3">{{ k.status === 'batal' ? 'Dibatalkan' : 'Ditutup' }} {{ formatPendek(k.selesai_pada) }}</p>
            <div class="mt-3 flex flex-wrap gap-2">
              <button v-if="k.boleh_periksa && ['menunggu', 'ditangani'].includes(k.status)" class="tombol-utama min-h-[38px] px-3 text-sm" @click="periksa(k)">
                <PhStethoscope :size="18" /> {{ k.status === 'menunggu' ? 'Periksa' : 'Kontrol' }}</button>
              <button v-if="k.boleh_periksa && k.status === 'ditangani'" class="tombol-garis min-h-[38px] px-3 text-sm" @click="bukaSembuh(k)"><PhCheckCircle :size="18" /> Sembuh</button>
              <button class="tombol-garis min-h-[38px] px-3 text-sm" @click="rincian(k)">Rincian <PhArrowRight :size="16" /></button>
              <button v-if="k.boleh_batal" class="tombol-garis min-h-[38px] px-3 text-sm" @click="bukaBatal(k)"><PhX :size="18" /> Batalkan</button>
            </div>
          </div>
        </div>
      </li>
    </ul>
    <p v-if="!tampil.length && !memuat" class="kartu mt-4 p-8 text-center text-sm text-teks3"><PhUsersThree :size="32" weight="duotone" class="mx-auto mb-2" />{{ kosong }}</p>

    <TombolAksi v-if="kl.hak.rujuk" label="Rujuk santri" :ikon="PhPaperPlaneTilt" warna="klinik" @klik="lembarRujuk = true" />

    <LembarRujuk v-model="lembarRujuk" @selesai="selesaiLembar" />
    <LembarPeriksa v-model="lembarPeriksa" :kasus="kasusPilih" @selesai="selesaiLembar" />
    <LembarKasus v-model="lembarKasus" :id="idRincian" @periksa="(k) => { lembarKasus = false; periksa(k) }" />

    <LembarBawah v-model="lembarBatal" judul="Batalkan rujukan">
      <div class="space-y-3 pb-2">
        <p v-if="kasusPilih" class="text-sm text-teks2">{{ kasusPilih.nama }} · {{ kasusPilih.keluhan }}</p>
        <textarea v-model="alasan" rows="2" class="isian" placeholder="Contoh: salah pilih santri, santri sudah sehat" aria-label="Alasan pembatalan" />
        <button class="tombol-utama w-full" :disabled="proses" @click="batal">Batalkan rujukan</button>
      </div>
    </LembarBawah>
    <LembarBawah v-model="lembarSembuh" judul="Nyatakan sembuh">
      <div class="space-y-3 pb-2">
        <p v-if="kasusPilih" class="text-sm text-teks2"><b>{{ kasusPilih.nama }}</b> kembali beraktivitas normal dan kasusnya ditutup. Perujuk mendapat notifikasi.</p>
        <input v-model="catSembuh" class="isian" placeholder="Catatan (opsional), contoh: suhu normal 2 hari" aria-label="Catatan sembuh" />
        <button class="tombol-utama w-full" :disabled="proses" @click="sembuh"><PhCheckCircle :size="20" weight="duotone" /> Nyatakan sembuh</button>
      </div>
    </LembarBawah>
  </div>
</template>
<style scoped>
.kasus-lewat { border-color: var(--c); box-shadow: inset 4px 0 0 var(--c); }
</style>
