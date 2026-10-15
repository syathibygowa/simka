<!-- SIMKA PRO | src/pages/tahfizh/TabDokumenTahfizh.vue | v1.0 | Tahap D: daftar dan cetak dokumen tahfizh, Sertifikat Tahfizhul Quran kelas 9/12 | 16/10/2026 -->
<script setup>
// Tab Dokumen pada menu Tahfizh:
//   Dokumen terbit : suket ujian kenaikan juz, sertifikat hafalan, Sertifikat Tahfizhul Quran (kartu statistik, saringan, cetak, cabut)
//   Sertifikat Tahfizhul Quran : calon santri kelas 9 dan 12 (aktif/lulus) beserta hafalan resmi; terbitkan sertifikat
//   Pengaturan sertifikat : baris kepala yayasan/pondok, logo, kalimat (pengatur tahfizh)
// ?dok=<id> membuka cetak dokumen (dari notifikasi); ?resmi=<id registri> dari kotak Tanda tangan.
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { PhCertificate, PhFileText, PhSealCheck, PhHourglass, PhPrinter, PhProhibit, PhMagnifyingGlass, PhGraduationCap, PhGearSix, PhStudent } from '@phosphor-icons/vue'
import { useTahfizh } from '@/stores/tahfizh'
import { useUI } from '@/stores/ui'
import { JENIS_DOK_TAHFIZH, statusDok, PENGATURAN_SERTIFIKAT } from '@/lib/dokumenTahfizh'
import { ringkasJuz } from '@/lib/tahfizh'
import { formatPanjang, formatPendek, hariIniISO } from '@/lib/tanggal'
import KartuStatistik from '@/components/KartuStatistik.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import CetakDokumenTahfizh from './CetakDokumenTahfizh.vue'
import LembarTerbitTahfizh from './LembarTerbitTahfizh.vue'

const tz = useTahfizh(); const ui = useUI(); const route = useRoute(); const router = useRouter()
const bagian = ref('terbit')
const hari = hariIniISO(); const th = Number(hari.slice(0, 4)) - (Number(hari.slice(5, 7)) < 7 ? 1 : 0)
const mulai = ref(`${th}-07-01`); const selesai = ref(hari); const jenis = ref(''); const cari = ref('')
const daftar = ref([]); const memuat = ref(true)
async function muat() {
  memuat.value = true
  try { daftar.value = await tz.daftarDokumen({ mulai: mulai.value, selesai: selesai.value }) } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
watch([mulai, selesai], muat)

// ---------- Cetak ----------
const dokCetak = ref(null); const pratinjau = ref(false)
async function cetak(d) { dokCetak.value = d; pratinjau.value = true }
async function bukaDariQuery() {
  const id = typeof route.query.dok === 'string' ? route.query.dok : ''; const resmi = typeof route.query.resmi === 'string' ? route.query.resmi : ''
  if (!id && !resmi) return
  try {
    let d = id ? (await tz.daftarDokumen({ id }))[0] : daftar.value.find((x) => x.document_id === resmi)
    if (!d && resmi) d = (await tz.daftarDokumen({})).find((x) => x.document_id === resmi)
    if (d) cetak(d); else ui.toast('Dokumen tidak ditemukan atau Anda tidak berwenang membukanya.', 'galat')
  } catch (e) { ui.toast(e.message, 'galat') }
  router.replace({ query: {} })
}
onMounted(async () => { if (!tz.hakDimuat) await tz.muatHak(); await muat(); bukaDariQuery() })
watch(() => [route.query.dok, route.query.resmi], () => bukaDariQuery())

const tampil = computed(() => {
  const q = cari.value.toLowerCase().trim()
  return daftar.value.filter((d) => (!jenis.value || d.jenis === jenis.value) && (!q || `${d.data?.nama} ${d.data?.nis} ${d.nomor}`.toLowerCase().includes(q)))
})
const statistik = computed(() => {
  const d = daftar.value.filter((x) => x.status === 'terbit'); const n = memuat.value ? '…' : null
  return [
    { judul: 'Dokumen terbit', nilai: n ?? d.length, ikon: PhCertificate, warna: 'tahfizh', ket: `${formatPendek(mulai.value)} – ${formatPendek(selesai.value)}` },
    { judul: 'Suket kenaikan juz', nilai: n ?? d.filter((x) => x.jenis === 'suket_juz').length, ikon: PhFileText, warna: 'agenda', ket: 'Ujian kenaikan juz Tuntas' },
    { judul: 'Sertifikat hafalan', nilai: n ?? d.filter((x) => x.jenis === 'sertifikat_hafalan').length, ikon: PhSealCheck, warna: 'presensi', ket: 'Sertifikasi 5, 10, 15 … juz' },
    { judul: 'Sertifikat Tahfizhul Quran', nilai: n ?? d.filter((x) => x.jenis === 'sertifikat_tahfizh').length, ikon: PhGraduationCap, warna: 'prestasi', ket: 'Akhir jenjang kelas 9/12' },
    { judul: 'Menunggu tanda tangan', nilai: n ?? d.filter((x) => x.status_dokumen === 'draf').length, ikon: PhHourglass, warna: 'pengajuan', ket: 'Tanda tangan elektronik' },
  ]
})
const ketDok = (d) => (d.jenis === 'suket_juz' ? `Juz ${ringkasJuz(d.data?.juz || [])} · nilai ${String(d.data?.nilai_akhir).replace('.', ',')}` : d.jenis === 'sertifikat_hafalan' ? `Sertifikasi ${d.data?.jenjang_juz} juz · nilai ${String(d.data?.nilai_akhir).replace('.', ',')}` : `Hafalan ${d.data?.total_juz} juz · ${d.data?.predikat}`)

// ---------- Cabut ----------
const lembarCabut = ref(false); const dokCabut = ref(null); const alasan = ref(''); const proses = ref(false)
function bukaCabut(d) { dokCabut.value = d; alasan.value = ''; lembarCabut.value = true }
async function cabut() {
  proses.value = true
  try { await tz.cabutDokumen(dokCabut.value.id, alasan.value.trim()); ui.toast('Dokumen dicabut. Nomor tidak dipakai ulang.'); lembarCabut.value = false; muat() }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}

// ---------- Sertifikat Tahfizhul Quran (calon) ----------
const calon = ref([]); const memuatCalon = ref(false); const cariCalon = ref(''); const tingkatCalon = ref('')
async function muatCalon() { memuatCalon.value = true; try { calon.value = await tz.calonSertifikat() } catch (e) { ui.toast(e.message, 'galat') } finally { memuatCalon.value = false } }
watch(bagian, (b) => { if (b === 'sertifikat' && !calon.value.length) muatCalon() })
const calonTampil = computed(() => { const q = cariCalon.value.toLowerCase().trim(); return calon.value.filter((s) => (!tingkatCalon.value || s.tingkat === Number(tingkatCalon.value)) && (!q || `${s.nama} ${s.nis}`.toLowerCase().includes(q))) })
const lembarTerbit = ref(false); const calonPilih = ref(null)
function terbitkan(s) { calonPilih.value = s; lembarTerbit.value = true }
async function sesudahTerbit(h) { await Promise.all([muat(), muatCalon()]); const d = daftar.value.find((x) => x.id === h.id) || (await tz.daftarDokumen({ id: h.id }))[0]; if (d) cetak(d) }
async function cetakCalon(s) { const d = daftar.value.find((x) => x.id === s.dokumen_id) || (await tz.daftarDokumen({ id: s.dokumen_id }))[0]; if (d) cetak(d) }

// ---------- Pengaturan sertifikat ----------
const lembarAtur = ref(false); const atur = ref({ ...PENGATURAN_SERTIFIKAT })
async function bukaAtur() { try { atur.value = await tz.pengaturanSertifikat(); lembarAtur.value = true } catch (e) { ui.toast(e.message, 'galat') } }
async function simpanAtur() {
  proses.value = true
  try { await tz.simpanPengaturanSertifikat({ ...atur.value }); ui.toast('Pengaturan sertifikat tersimpan. Berlaku untuk sertifikat yang terbit berikutnya.'); lembarAtur.value = false }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
const BAGIAN = computed(() => [{ k: 'terbit', n: 'Dokumen terbit', i: PhCertificate }, ...(tz.hak.dokumen ? [{ k: 'sertifikat', n: 'Sertifikat Tahfizhul Quran', i: PhGraduationCap }] : [])])
</script>
<template>
  <div>
    <div class="-mx-4 mb-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-3 sm:overflow-visible sm:px-0 xl:grid-cols-5">
      <KartuStatistik v-for="k in statistik" :key="k.judul" class="w-[46%] shrink-0 snap-start sm:w-auto" :judul="k.judul" :nilai="k.nilai" :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket" />
    </div>

    <div class="mb-4 flex flex-wrap items-center gap-2">
      <button v-for="b in BAGIAN" :key="b.k" type="button" :aria-pressed="bagian === b.k" @click="bagian = b.k"
        :class="['flex min-h-[40px] items-center gap-2 rounded-full border px-4 text-sm font-semibold', bagian === b.k ? 'border-transparent bg-[#0B6B57] text-white dark:bg-[#5BD6A9] dark:text-[#06291F]' : 'border-garis bg-permukaan text-teks2']">
        <component :is="b.i" :size="18" weight="duotone" />{{ b.n }}</button>
      <button v-if="tz.hak.atur" type="button" class="tombol-teks ml-auto text-sm" @click="bukaAtur"><PhGearSix :size="18" /> Atur sertifikat</button>
    </div>

    <!-- ===== Dokumen terbit ===== -->
    <template v-if="bagian === 'terbit'">
      <div class="kartu mb-4 grid grid-cols-2 gap-3 p-4 lg:grid-cols-4">
        <InputTanggal v-model="mulai" label="Dari tanggal" />
        <InputTanggal v-model="selesai" label="Sampai tanggal" />
        <div><label class="label-isian" for="dt-jenis">Jenis dokumen</label>
          <select id="dt-jenis" v-model="jenis" class="isian"><option value="">Semua jenis</option><option v-for="(j, k) in JENIS_DOK_TAHFIZH" :key="k" :value="k">{{ j.n }}</option></select></div>
        <div class="relative self-end"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
          <input v-model="cari" type="search" class="isian pl-11" placeholder="Nama, NIS, nomor" aria-label="Cari dokumen" /></div>
      </div>
      <p v-if="memuat" class="py-10 text-center text-teks3">Memuat dokumen…</p>
      <ul v-else-if="tampil.length" class="grid gap-3 lg:grid-cols-2">
        <li v-for="d in tampil" :key="d.id" :class="['kartu min-w-0 p-4', 'w-' + JENIS_DOK_TAHFIZH[d.jenis].w, d.status === 'dicabut' && 'opacity-70']">
          <div class="flex items-start gap-3">
            <span class="chip-ikon h-11 w-11 shrink-0"><PhCertificate :size="24" weight="duotone" /></span>
            <div class="min-w-0 flex-1">
              <p class="text-xs font-semibold uppercase tracking-wide" style="color: var(--c)">{{ JENIS_DOK_TAHFIZH[d.jenis].panjang }}</p>
              <p class="font-bold leading-snug">{{ d.data?.nama }}</p>
              <p class="text-sm text-teks2">{{ ketDok(d) }}</p>
              <p class="text-xs text-teks3 tabular-nums">{{ d.nomor }} · {{ formatPanjang(d.tanggal) }} · kode {{ d.kode || '–' }}</p>
              <p class="mt-1.5 flex flex-wrap items-center gap-1.5 text-xs">
                <span :class="['lencana', 'w-' + statusDok(d).w]">{{ statusDok(d).n }}</span>
                <span v-for="t in d.ttd" :key="t.urutan" class="text-teks3">{{ t.jabatan }}: {{ t.status === 'ditandatangani' ? '✓' : 'menunggu' }}</span>
              </p>
              <p v-if="d.alasan_cabut" class="mt-1 text-xs text-teks3">Dicabut: {{ d.alasan_cabut }}</p>
            </div>
          </div>
          <div class="mt-3 flex flex-wrap gap-2">
            <button class="tombol-utama min-h-[40px] px-4 text-sm" @click="cetak(d)"><PhPrinter :size="18" weight="duotone" /> {{ d.status === 'dicabut' ? 'Lihat' : 'Cetak' }}</button>
            <button v-if="d.boleh_cabut" class="tombol-garis min-h-[40px] px-3 text-sm" @click="bukaCabut(d)"><PhProhibit :size="18" /> Cabut</button>
          </div>
        </li>
      </ul>
      <div v-else class="kartu p-8 text-center">
        <PhCertificate :size="40" weight="duotone" class="mx-auto text-teks3" />
        <p class="mt-2 font-semibold">Belum ada dokumen tahfizh pada periode ini.</p>
        <p class="text-sm text-teks3">Suket kenaikan juz dan sertifikat hafalan diterbitkan penguji dari tab Ujian setelah ujian dinilai Tuntas.</p>
      </div>
    </template>

    <!-- ===== Sertifikat Tahfizhul Quran ===== -->
    <template v-else>
      <div class="kartu mb-4 flex flex-wrap gap-3 p-4">
        <div class="relative min-w-[200px] flex-1"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
          <input v-model="cariCalon" type="search" class="isian pl-11" placeholder="Cari nama atau NIS" aria-label="Cari santri" /></div>
        <select v-model="tingkatCalon" class="isian w-auto" aria-label="Saring kelas"><option value="">Kelas 9 dan 12</option><option value="9">Kelas 9 (Wustha)</option><option value="12">Kelas 12 (SMA)</option></select>
      </div>
      <p class="mb-3 text-sm text-teks3">Sertifikat (ijazah) hafalan untuk santri akhir jenjang. Jumlah juz diambil dari capaian juz resmi; tanggal hafalan dan predikat dapat disesuaikan saat terbit.</p>
      <p v-if="memuatCalon" class="py-10 text-center text-teks3">Memuat santri…</p>
      <ul v-else-if="calonTampil.length" class="kartu divide-y divide-garis">
        <li v-for="s in calonTampil" :key="s.student_id" class="flex flex-wrap items-center gap-3 p-3">
          <span class="w-santri chip-ikon h-10 w-10 shrink-0"><PhStudent :size="22" weight="duotone" /></span>
          <div class="min-w-0 flex-1">
            <p class="font-semibold">{{ s.nama }}</p>
            <p class="text-xs text-teks3">{{ s.nis }} · {{ s.kelas || 'Kelas ' + s.tingkat }}{{ s.status === 'lulus' ? ' · lulus' : '' }} · hafalan resmi <b class="text-teks2">{{ s.total_juz }} juz</b>{{ s.predikat ? ' · ' + s.predikat : '' }}</p>
          </div>
          <button v-if="s.dokumen_id" class="tombol-garis min-h-[40px] px-3 text-sm" @click="cetakCalon(s)"><PhPrinter :size="18" weight="duotone" /> Cetak sertifikat</button>
          <button v-else class="tombol-utama min-h-[40px] px-3 text-sm" :disabled="!s.total_juz" @click="terbitkan(s)"><PhCertificate :size="18" weight="duotone" /> Terbitkan</button>
        </li>
      </ul>
      <p v-else class="kartu p-6 text-center text-sm text-teks3">Tidak ada santri kelas 9 atau 12 yang sesuai.</p>
    </template>

    <CetakDokumenTahfizh v-if="dokCetak" :key="dokCetak.id" v-model:pratinjau="pratinjau" :dok="dokCetak" />
    <LembarTerbitTahfizh v-model="lembarTerbit" :calon="calonPilih" @terbit="sesudahTerbit" />

    <LembarBawah v-model="lembarCabut" judul="Cabut dokumen tahfizh">
      <div v-if="dokCabut" class="space-y-4 pb-2">
        <p class="text-sm text-teks2"><b>{{ JENIS_DOK_TAHFIZH[dokCabut.jenis].panjang }}</b> {{ dokCabut.data?.nama }} nomor {{ dokCabut.nomor }} akan dinyatakan tidak berlaku. Pemeriksaan kode validasi menampilkan status dicabut.</p>
        <div><label class="label-isian" for="dt-alasan">Alasan <span class="text-merah">*</span></label>
          <textarea id="dt-alasan" v-model="alasan" rows="3" class="isian min-h-[80px]" placeholder="Contoh: salah tanggal ujian, diterbitkan ulang" /></div>
        <button class="tombol-utama w-full" :disabled="proses" @click="cabut">{{ proses ? 'Menyimpan…' : 'Cabut dokumen' }}</button>
      </div>
    </LembarBawah>

    <LembarBawah v-model="lembarAtur" judul="Pengaturan Sertifikat Tahfizhul Quran" lebar>
      <div class="space-y-3 pb-2">
        <p class="text-sm text-teks2">Kepala dan kalimat sertifikat. Gunakan _teks_ untuk huruf miring. Perubahan berlaku untuk sertifikat yang terbit berikutnya.</p>
        <div v-for="[k, n] in [['baris1', 'Baris 1 (yayasan)'], ['baris2', 'Baris 2 (pondok, tebal)'], ['baris3', 'Baris 3 (tebal)']]" :key="k">
          <label class="label-isian" :for="'as-' + k">{{ n }}</label><input :id="'as-' + k" v-model="atur[k]" class="isian" /></div>
        <div v-for="[k, n] in [['pembuka', 'Kalimat pembuka'], ['program', 'Kalimat program (sebelum jumlah juz)'], ['penutup', 'Kalimat penutup']]" :key="k">
          <label class="label-isian" :for="'as-' + k">{{ n }}</label><textarea :id="'as-' + k" v-model="atur[k]" rows="2" class="isian min-h-[64px]" /></div>
        <div class="grid gap-3 sm:grid-cols-2">
          <div><label class="label-isian" for="as-lk">Logo kiri (alamat gambar)</label><input id="as-lk" v-model="atur.logo_kiri" class="isian" placeholder="kop/logo-ypwi.png" /></div>
          <div><label class="label-isian" for="as-lka">Logo kanan (kosong = logo pondok)</label><input id="as-lka" v-model="atur.logo_kanan" class="isian" placeholder="Logo pondok di Setelan → Identitas" /></div>
        </div>
        <button class="tombol-utama w-full" :disabled="proses" @click="simpanAtur">{{ proses ? 'Menyimpan…' : 'Simpan pengaturan' }}</button>
      </div>
    </LembarBawah>
  </div>
</template>
