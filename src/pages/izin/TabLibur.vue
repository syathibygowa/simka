<!-- SIMKA PRO | src/pages/izin/TabLibur.vue | v1.0 | Fase 7 – Tahap 3 Libur santri | 06/10/2026 -->
<script setup>
// Penentuan libur santri (Blueprint Bagian 23).
//   Daftar periode → pilih periode → nilai otomatis (boleh / tidak / perlu pertimbangan, lengkap dengan angka)
//   → putuskan yang perlu pertimbangan / ubah keputusan dengan alasan → sahkan (izin libur otomatis ke gerbang)
//   → WA wali, Excel, cetak F4 (pilih daftar yang libur, yang tinggal, atau semua; ringkasan selalu memuat kedua jumlah).
// Ketentuan: syarat bawaan untuk periode baru. Pengasuh melihat hasil santri asuhannya setelah disahkan.
import { ref, computed, onMounted, watch } from 'vue'
import * as XLSX from 'xlsx'
import { PhCalendarPlus, PhCalculator, PhSealCheck, PhProhibit, PhPencilSimple, PhWhatsappLogo, PhEye, PhDownloadSimple, PhMagnifyingGlass,
  PhArrowLeft, PhUsersThree, PhCheckCircle, PhXCircle, PhHourglass, PhFloppyDisk, PhInfo, PhCalendarCheck } from '@phosphor-icons/vue'
import { useLibur } from '@/stores/libur'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { HASIL_LIBUR, STATUS_PERIODE, JENIS_PERIODE, SYARAT_LIBUR } from '@/lib/izin'
import { JENJANG_PENDEK, penandaKelompok } from '@/lib/santri'
import { pesanWA, tautanWA } from '@/lib/wa'
import { formatWaktu, formatPanjang, formatPendek } from '@/lib/tanggal'
import KartuStatistik from '@/components/KartuStatistik.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import TombolAksi from '@/components/TombolAksi.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import LembarPeriodeLibur from './LembarPeriodeLibur.vue'

const lb = useLibur(); const sesi = useSesi(); const ui = useUI()
const periode = ref([]); const pilih = ref(null); const detail = ref(null); const memuat = ref(false); const proses = ref(false)
onMounted(async () => { if (!lb.hakDimuat) await lb.muatHak().catch((e) => ui.toast(e.message, 'galat')); salinSyarat(); await muat() })
async function muat() {
  memuat.value = true
  try { periode.value = await lb.daftar(); if (pilih.value) await bukaDetail(pilih.value) } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
async function bukaDetail(id) {
  pilih.value = id
  try { detail.value = await lb.detail(id) } catch (e) { ui.toast(e.message, 'galat'); pilih.value = null }
}
function tutupDetail() { pilih.value = null; detail.value = null; saring.value = 'semua'; cari.value = '' }

// ---------- Periode ----------
const lembarPeriode = ref(false); const ubahPeriode = ref(null)
function baru() { ubahPeriode.value = null; lembarPeriode.value = true }
function ubah() { ubahPeriode.value = detail.value; lembarPeriode.value = true }
async function tersimpan(id) { await muat(); await bukaDetail(id) }
async function jalankan(fn, pesan) {
  proses.value = true
  try { await fn(); if (pesan) ui.toast(pesan); await muat() } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
const nilai = () => jalankan(() => lb.nilai(pilih.value), 'Penilaian selesai. Periksa santri yang perlu pertimbangan.')
async function sahkan() {
  const r = detail.value.ringkasan
  if (!(await ui.konfirmasi({ judul: 'Sahkan daftar libur', pesan: `${r.boleh} santri libur dan ${r.tidak} tinggal di pondok. Izin libur otomatis dibuat dan dikirim ke Security. Lanjutkan?`, ya: 'Sahkan' }))) return
  jalankan(() => lb.sahkan(pilih.value), 'Daftar libur disahkan. Security dan pengasuh telah dikabari.')
}
const lembarBatal = ref(false); const alasanBatal = ref('')
async function batalkan() {
  if (alasanBatal.value.trim().length < 5) return ui.toast('Tuliskan alasan pembatalan.', 'galat')
  await jalankan(() => lb.batalkan(pilih.value, alasanBatal.value.trim()), 'Periode libur dibatalkan.'); lembarBatal.value = false
}

// ---------- Hasil santri ----------
const saring = ref('semua'); const cari = ref('')
const santri = computed(() => detail.value?.santri || [])
const tampil = computed(() => {
  const q = cari.value.toLowerCase().trim()
  return santri.value.filter((s) => (saring.value === 'semua' || (saring.value === 'belum' ? !s.keputusan : saring.value === 'diubah' ? s.diubah : s.keputusan === saring.value))
    && (!q || `${s.nama} ${s.nis} ${s.kelas || ''} ${s.kamar || ''}`.toLowerCase().includes(q)))
})
const r = computed(() => detail.value?.ringkasan || {})
const kartu = computed(() => [
  { k: 'semua', j: 'Santri dinilai', v: r.value.jumlah, i: PhUsersThree, w: 'santri', ket: `${r.value.diubah || 0} keputusan diubah` },
  { k: 'boleh', j: 'Boleh libur', v: r.value.boleh, i: PhCheckCircle, w: 'presensi', ket: detail.value?.status === 'disahkan' ? `${r.value.izin_dibuat} izin libur dibuat` : 'Keputusan saat ini' },
  { k: 'tidak', j: 'Tinggal di pondok', v: r.value.tidak, i: PhXCircle, w: 'klinik', ket: 'Tidak libur' },
  { k: 'belum', j: 'Perlu diputuskan', v: r.value.belum, i: PhHourglass, w: 'pengajuan', ket: `${r.value.pertimbangan || 0} perlu pertimbangan` },
])
const bolehUbah = computed(() => lb.hak.kelola && ['dinilai', 'disahkan'].includes(detail.value?.status) && (detail.value.status !== 'disahkan' || lb.hak.sahkan))
const persen = (s, k) => (s.rincian?.[k]?.persen == null ? '–' : s.rincian[k].persen + '%')
const syaratTeks = computed(() => (detail.value ? SYARAT_LIBUR.filter((x) => detail.value.syarat?.[x.k] != null && x.k !== 'margin' && !(x.k === 'hafalan_min_halaman' && !detail.value.syarat[x.k]))
  .map((x) => `${x.n.replace(' minimal', ' ≥').replace(' maksimal', ' ≤')} ${detail.value.syarat[x.k]}${x.s === '%' ? '%' : ' ' + x.s}`).join(' · ') : ''))

const lembarUbah = ref(false); const pilihSantri = ref(null); const keputusan = ref('boleh'); const alasan = ref('')
function bukaUbah(s) { pilihSantri.value = s; keputusan.value = s.keputusan || (s.otomatis === 'tidak' ? 'tidak' : 'boleh'); alasan.value = s.alasan_ubah || ''; lembarUbah.value = true }
async function simpanUbah() {
  proses.value = true
  try { await lb.ubah(pilihSantri.value.id, keputusan.value, alasan.value.trim()); ui.toast('Keputusan tersimpan.'); lembarUbah.value = false; await bukaDetail(pilih.value); periode.value = await lb.daftar() }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
function waWali(s) {
  if (!s.wali?.no_hp) return ui.toast('Nomor HP orang tua/wali santri ini belum diisi.', 'galat')
  const libur = s.keputusan === 'boleh'
  const pesan = pesanWA('libur_santri', { nama_wali: s.wali.nama || 'orang tua/wali', nama_santri: s.nama, kelas: s.kelas || '', periode_libur: detail.value.nama,
    status_libur: libur ? 'diizinkan libur' : 'belum diizinkan libur dan tetap tinggal di pondok', waktu_pulang: libur ? formatWaktu(detail.value.pulang_pada) + ' WITA' : '-',
    batas_kembali: libur ? formatWaktu(detail.value.kembali_batas) + ' WITA' : '-',
    keterangan: libur ? '' : 'Keterangan: ' + ([...(s.rincian?.gagal || []), ...(s.rincian?.timbang || [])].join('; ') || s.alasan_ubah || 'sesuai ketentuan pondok') })
  window.open(tautanWA(s.wali.no_hp, pesan), '_blank', 'noopener')
}

// ---------- Ekspor dan cetak ----------
function ekspor() {
  const d = detail.value
  const judul = ['No.', 'NIS', 'Nama santri', 'L/P', 'Jenjang', 'Kelas', 'Kamar', 'Halaqah', 'Kelas (%)', 'Halaqah (%)', 'Asrama (%)', 'Izin keluar', 'Terlambat', 'Tambahan hafalan (hal)', 'Hasil otomatis', 'Keputusan', 'Alasan/keterangan']
  const isi = tampil.value.map((s, i) => [i + 1, s.nis, s.nama, s.jenis_kelamin, JENJANG_PENDEK[s.jenjang] || '', s.kelas || '', s.kamar || '', s.halaqah || '',
    s.rincian?.kelas?.persen ?? '', s.rincian?.halaqah?.persen ?? '', s.rincian?.asrama?.persen ?? '', s.rincian?.izin ?? 0, s.rincian?.terlambat ?? 0, s.rincian?.hafalan ?? 0,
    HASIL_LIBUR[s.otomatis].n, s.keputusan ? HASIL_LIBUR[s.keputusan].n : 'Belum diputuskan', [s.alasan_ubah, ...(s.rincian?.gagal || []), ...(s.rincian?.timbang || [])].filter(Boolean).join('; ')])
  const ws = XLSX.utils.aoa_to_sheet([[d.nama], [`Pulang ${formatWaktu(d.pulang_pada)} · kembali ${formatWaktu(d.kembali_batas)} WITA`], [], judul, ...isi])
  ws['!cols'] = [5, 10, 26, 5, 8, 7, 16, 16, 9, 10, 9, 9, 9, 10, 18, 18, 40].map((w) => ({ wch: w }))
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Libur'); XLSX.writeFile(wb, `${d.nama.replace(/[^\w-]+/g, '-')}.xlsx`)
}
const lembarCetak = ref(false); const daftarCetak = ref('boleh'); const pratinjau = ref(false); const penanda = ref({ jabatan: 'Kepala Bidang Kesantrian', nama: '', niy: '' })
const isiCetak = computed(() => santri.value.filter((s) => daftarCetak.value === 'semua' || s.keputusan === daftarCetak.value))
const judulCetak = computed(() => (daftarCetak.value === 'boleh' ? 'Daftar Santri yang Diizinkan Libur' : daftarCetak.value === 'tidak' ? 'Daftar Santri yang Tinggal di Pondok' : 'Daftar Penentuan Libur Santri'))
async function cetak() { penanda.value = await penandaKelompok({ jenis: 'kamar' }).catch(() => penanda.value); lembarCetak.value = false; pratinjau.value = true }

// ---------- Ketentuan (syarat bawaan) ----------
const tampilSyarat = ref(false); const sy = ref({})
function salinSyarat() { sy.value = { ...lb.syarat } }
watch(() => lb.syarat, salinSyarat)
async function simpanSyarat() {
  proses.value = true
  try { await lb.simpanSyarat(Object.fromEntries(Object.entries(sy.value).map(([k, v]) => [k, v === '' || v == null ? null : typeof v === 'boolean' ? v : Number(v)]))); ui.toast('Syarat bawaan libur tersimpan.') }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <div>
    <!-- ================= DAFTAR PERIODE ================= -->
    <template v-if="!pilih">
      <div class="flex flex-wrap items-center gap-2">
        <h2 class="judul-bagian flex-1">Periode libur santri</h2>
        <button v-if="lb.hak.kelola" class="tombol-garis min-h-[44px] px-3 text-sm" @click="tampilSyarat = !tampilSyarat"><PhInfo :size="18" /> Syarat bawaan</button>
        <button v-if="lb.hak.kelola" class="tombol-utama hidden lg:inline-flex" @click="baru"><PhCalendarPlus :size="20" weight="duotone" /> Periode baru</button>
      </div>
      <section v-if="tampilSyarat" class="kartu w-pengaturan mt-3 p-4">
        <p class="text-sm text-teks2">Syarat bawaan dipakai untuk periode baru dan dapat diubah per periode. Kosongkan kolom bila syarat tidak dipakai.</p>
        <div class="mt-3 grid gap-3 sm:grid-cols-3">
          <div v-for="s in SYARAT_LIBUR" :key="s.k"><label class="label-isian" :for="'sb-' + s.k">{{ s.n }} ({{ s.s }})</label>
            <input :id="'sb-' + s.k" v-model="sy[s.k]" type="number" min="0" class="isian tabular-nums" placeholder="Tidak dipakai" /></div>
        </div>
        <label class="mt-3 flex items-center gap-2 text-sm"><input v-model="sy.abaikan_izin_sakit" type="checkbox" class="h-5 w-5 accent-[#C7332F]" /> Izin dan sakit tidak mengurangi persentase kehadiran</label>
        <button class="tombol-utama mt-3" :disabled="proses" @click="simpanSyarat"><PhFloppyDisk :size="20" weight="duotone" /> Simpan syarat bawaan</button>
      </section>
      <ul class="mt-3 grid gap-3 md:grid-cols-2">
        <li v-for="h in periode" :key="h.id">
          <button type="button" class="kartu flex w-full items-start gap-3 p-4 text-left" :class="'w-' + STATUS_PERIODE[h.status].w" @click="bukaDetail(h.id)">
            <span class="chip-ikon h-11 w-11 shrink-0"><PhCalendarCheck :size="24" weight="duotone" /></span>
            <span class="min-w-0 flex-1">
              <span class="flex flex-wrap items-center gap-1.5"><b class="leading-snug">{{ h.nama }}</b><span class="lencana">{{ h.selesai ? 'Selesai' : STATUS_PERIODE[h.status].n }}</span></span>
              <span class="block text-xs text-teks3">{{ JENIS_PERIODE[h.jenis] }} · pulang {{ formatWaktu(h.pulang_pada) }} · kembali {{ formatWaktu(h.kembali_batas) }} WITA</span>
              <span v-if="h.ringkasan?.jumlah" class="mt-1 block text-sm"><b class="text-[#1E7D4F] dark:text-[#6FD19A]">{{ h.ringkasan.boleh }} libur</b> · <b class="text-merah">{{ h.ringkasan.tidak }} tinggal</b>
                <template v-if="h.ringkasan.belum"> · {{ h.ringkasan.belum }} perlu diputuskan</template></span>
              <span v-else class="mt-1 block text-sm text-teks3">Belum dinilai</span>
            </span>
          </button>
        </li>
      </ul>
      <p v-if="!periode.length && !memuat" class="kartu mt-3 p-8 text-center text-sm text-teks3">{{ lb.hak.kelola ? 'Belum ada periode libur. Buat periode baru untuk mulai menilai santri.' : 'Belum ada daftar libur yang disahkan untuk santri asuhan Anda.' }}</p>
      <TombolAksi v-if="lb.hak.kelola" label="Periode baru" :ikon="PhCalendarPlus" warna="agenda" @klik="baru" />
    </template>

    <!-- ================= DETAIL PERIODE ================= -->
    <template v-else-if="detail">
      <button class="tombol-teks mb-2 min-h-[40px] px-1 text-sm" @click="tutupDetail"><PhArrowLeft :size="18" /> Semua periode</button>
      <section class="kartu p-4" :class="'w-' + STATUS_PERIODE[detail.status].w">
        <div class="flex flex-wrap items-start gap-3">
          <div class="min-w-0 flex-1">
            <p class="flex flex-wrap items-center gap-1.5"><b class="text-lg leading-snug">{{ detail.nama }}</b><span class="lencana">{{ detail.selesai ? 'Selesai' : STATUS_PERIODE[detail.status].n }}</span></p>
            <p class="text-sm text-teks2">{{ JENIS_PERIODE[detail.jenis] }} · pulang <b>{{ formatWaktu(detail.pulang_pada) }}</b> · kembali paling lambat <b>{{ formatWaktu(detail.kembali_batas) }}</b> WITA</p>
            <p class="text-xs text-teks3">Rentang hitung {{ formatPendek(detail.hitung_mulai) }} s.d. {{ formatPendek(detail.hitung_selesai) }} · {{ detail.jenjang?.length ? detail.jenjang.map((j) => JENJANG_PENDEK[j]).join(', ') : 'semua jenjang' }} · {{ detail.jenis_kelamin === 'L' ? 'putra' : detail.jenis_kelamin === 'P' ? 'putri' : 'putra dan putri' }}</p>
            <p class="text-xs text-teks3">Syarat: {{ syaratTeks || 'tidak ada' }}</p>
            <p v-if="detail.pengesah" class="text-xs text-teks2">Disahkan oleh {{ detail.pengesah }}{{ detail.disahkan_pada ? ', ' + formatWaktu(detail.disahkan_pada) : '' }}</p>
          </div>
          <div v-if="lb.hak.kelola && detail.status !== 'batal'" class="flex flex-wrap gap-2">
            <button v-if="['draf', 'dinilai'].includes(detail.status)" class="tombol-garis min-h-[40px] px-3 text-sm" @click="ubah"><PhPencilSimple :size="18" /> Ubah</button>
            <button v-if="['draf', 'dinilai'].includes(detail.status)" class="tombol-garis w-agenda min-h-[40px] px-3 text-sm" :disabled="proses" @click="nilai"><PhCalculator :size="18" style="color: var(--c)" /> {{ detail.status === 'draf' ? 'Nilai santri' : 'Nilai ulang' }}</button>
            <button v-if="detail.status === 'dinilai' && lb.hak.sahkan" class="tombol-utama min-h-[40px] px-3 text-sm" :disabled="proses" @click="sahkan"><PhSealCheck :size="18" weight="bold" /> Sahkan</button>
            <button v-if="detail.status !== 'disahkan' || lb.hak.sahkan" class="tombol-garis min-h-[40px] px-3 text-sm" @click="alasanBatal = ''; lembarBatal = true"><PhProhibit :size="18" /> Batalkan</button>
          </div>
        </div>
        <p v-if="detail.status === 'dinilai' && !lb.hak.sahkan" class="mt-2 flex items-center gap-1.5 text-xs text-teks3"><PhInfo :size="14" /> Pengesahan oleh Kepala Bidang Kesantrian, Direktur/Wadir, atau Plt.</p>
      </section>

      <template v-if="santri.length">
        <div class="-mx-4 mt-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-4 sm:overflow-visible sm:px-0">
          <button v-for="k in kartu" :key="k.k" type="button" class="w-[44%] shrink-0 snap-start text-left sm:w-auto" :aria-pressed="saring === k.k" @click="saring = saring === k.k ? 'semua' : k.k">
            <KartuStatistik :judul="k.j" :nilai="k.v ?? 0" :ikon="k.i" :warna="k.w" :keterangan="k.ket" :class="saring === k.k && 'ring-2 ring-[var(--c)]'" />
          </button>
        </div>
        <div class="mt-3 flex flex-wrap items-center gap-2">
          <div class="relative min-w-[180px] flex-1"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
            <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari nama, NIS, kelas, kamar" aria-label="Cari santri" /></div>
          <button class="tombol-garis min-h-[44px] px-3 text-sm" :class="saring === 'diubah' && 'border-[#3B4CB0]'" @click="saring = saring === 'diubah' ? 'semua' : 'diubah'"><PhPencilSimple :size="18" /> Diubah</button>
          <button class="tombol-garis w-pengajuan min-h-[44px] px-3 text-sm" @click="lembarCetak = true"><PhEye :size="18" style="color: var(--c)" /> Cetak</button>
          <button class="tombol-garis w-santri min-h-[44px] px-3 text-sm" @click="ekspor"><PhDownloadSimple :size="18" style="color: var(--c)" /> Excel</button>
        </div>
        <ul class="mt-3 grid gap-2 lg:grid-cols-2">
          <li v-for="s in tampil" :key="s.id" class="kartu p-3" :class="'w-' + (s.keputusan ? HASIL_LIBUR[s.keputusan].w : 'pengajuan')">
            <div class="flex items-start gap-3">
              <span class="chip-ikon h-10 w-10 shrink-0"><component :is="s.keputusan ? HASIL_LIBUR[s.keputusan].ikon : PhHourglass" :size="22" weight="duotone" /></span>
              <div class="min-w-0 flex-1">
                <p class="flex flex-wrap items-center gap-1.5"><b class="leading-snug">{{ s.nama }}{{ s.kelas ? ' – ' + s.kelas : '' }}</b>
                  <span class="lencana">{{ s.keputusan ? HASIL_LIBUR[s.keputusan].n : 'Perlu diputuskan' }}</span>
                  <span v-if="s.diubah" class="text-xs font-semibold text-teks3">(otomatis: {{ HASIL_LIBUR[s.otomatis].n.toLowerCase() }})</span></p>
                <p class="text-xs text-teks3">{{ s.nis }} · {{ s.kamar || 'Kamar –' }}{{ s.halaqah ? ' · ' + s.halaqah : '' }}</p>
                <p class="mt-1 flex flex-wrap gap-x-3 gap-y-0.5 text-xs tabular-nums text-teks2">
                  <span>Kelas <b>{{ persen(s, 'kelas') }}</b></span><span>Halaqah <b>{{ persen(s, 'halaqah') }}</b></span><span>Asrama <b>{{ persen(s, 'asrama') }}</b></span>
                  <span>Izin <b>{{ s.rincian?.izin ?? 0 }}</b></span><span>Terlambat <b>{{ s.rincian?.terlambat ?? 0 }}</b></span><span>Hafalan <b>{{ s.rincian?.hafalan ?? 0 }} hal</b></span></p>
                <p v-for="g in s.rincian?.gagal || []" :key="g" class="text-xs font-semibold text-merah">✗ {{ g }}</p>
                <p v-for="g in s.rincian?.timbang || []" :key="g" class="text-xs font-semibold text-[#9A5B00] dark:text-[#FFC266]">△ {{ g }}</p>
                <p v-if="s.alasan_ubah" class="text-xs text-teks2">Alasan: {{ s.alasan_ubah }}{{ s.pengubah ? ' (' + s.pengubah + ')' : '' }}</p>
                <p v-if="s.rincian?.catatan_izin" class="text-xs text-teks3">{{ s.rincian.catatan_izin }}</p>
                <div class="mt-2 flex flex-wrap gap-2">
                  <button v-if="bolehUbah" class="tombol-garis min-h-[36px] px-3 text-sm" @click="bukaUbah(s)"><PhPencilSimple :size="16" /> {{ s.keputusan ? 'Ubah' : 'Putuskan' }}</button>
                  <button v-if="detail.status === 'disahkan' && s.keputusan" class="tombol-garis w-presensi min-h-[36px] px-3 text-sm" @click="waWali(s)"><PhWhatsappLogo :size="16" weight="duotone" style="color: var(--c)" /> Wali</button>
                </div>
              </div>
            </div>
          </li>
        </ul>
        <p v-if="!tampil.length" class="kartu mt-3 p-6 text-center text-sm text-teks3">Tidak ada santri pada saringan ini.</p>
      </template>
      <p v-else class="kartu mt-4 p-8 text-center text-sm text-teks3">{{ detail.status === 'draf' ? 'Periode belum dinilai. Klik "Nilai santri" untuk menyusun daftar otomatis.' : 'Tidak ada santri pada periode ini.' }}</p>
    </template>

    <LembarPeriodeLibur v-model="lembarPeriode" :periode="ubahPeriode" @tersimpan="tersimpan" />

    <LembarBawah v-model="lembarUbah" :judul="pilihSantri?.keputusan ? 'Ubah keputusan libur' : 'Putuskan libur'">
      <div v-if="pilihSantri" class="space-y-3 pb-2">
        <p class="text-sm"><b>{{ pilihSantri.nama }}</b>{{ pilihSantri.kelas ? ' – ' + pilihSantri.kelas : '' }} · hasil otomatis: <b>{{ HASIL_LIBUR[pilihSantri.otomatis].n }}</b></p>
        <div class="grid grid-cols-2 gap-2" role="radiogroup" aria-label="Keputusan">
          <button v-for="k in ['boleh', 'tidak']" :key="k" type="button" role="radio" :aria-checked="keputusan === k" @click="keputusan = k"
            :class="['flex min-h-[48px] items-center justify-center gap-2 rounded-xl border text-sm font-bold', 'w-' + HASIL_LIBUR[k].w, keputusan === k ? 'pilih-aktif text-teks' : 'border-garis text-teks2']">
            <component :is="HASIL_LIBUR[k].ikon" :size="20" weight="duotone" style="color: var(--c)" /> {{ HASIL_LIBUR[k].n }}</button>
        </div>
        <textarea v-model="alasan" rows="3" class="isian" placeholder="Alasan keputusan (wajib bila berbeda dari hasil otomatis), contoh: absen karena dirawat di rumah sakit" aria-label="Alasan" />
        <p v-if="detail?.status === 'disahkan'" class="text-xs text-teks3">Periode sudah disahkan: izin libur santri ini ikut dibuat atau dibatalkan.</p>
        <button class="tombol-utama w-full" :disabled="proses" @click="simpanUbah"><PhFloppyDisk :size="20" weight="duotone" /> Simpan keputusan</button>
      </div>
    </LembarBawah>

    <LembarBawah v-model="lembarBatal" judul="Batalkan periode libur">
      <div class="space-y-3 pb-2">
        <p class="text-sm text-teks2">Izin libur yang belum dipakai keluar akan ikut dibatalkan.</p>
        <textarea v-model="alasanBatal" rows="2" class="isian" placeholder="Alasan pembatalan" aria-label="Alasan pembatalan" />
        <button class="tombol-utama w-full" :disabled="proses" @click="batalkan"><PhProhibit :size="20" /> Batalkan periode</button>
      </div>
    </LembarBawah>

    <LembarBawah v-model="lembarCetak" judul="Pilih daftar yang dicetak">
      <div class="space-y-2 pb-2">
        <button v-for="o in [{ k: 'boleh', n: `Santri yang libur (${r.boleh || 0})` }, { k: 'tidak', n: `Santri yang tinggal di pondok (${r.tidak || 0})` }, { k: 'semua', n: `Semua santri (${r.jumlah || 0})` }]" :key="o.k"
          type="button" role="radio" :aria-checked="daftarCetak === o.k" @click="daftarCetak = o.k"
          :class="['flex min-h-[48px] w-full items-center rounded-xl border px-4 text-left text-sm font-semibold', daftarCetak === o.k ? 'border-[#3B4CB0] bg-[#3B4CB0]/10 text-teks' : 'border-garis text-teks2']">{{ o.n }}</button>
        <p class="text-xs text-teks3">Ringkasan jumlah yang libur dan yang tinggal tetap tercantum di dokumen.</p>
        <button class="tombol-utama w-full" @click="cetak"><PhEye :size="20" /> Pratinjau cetak</button>
      </div>
    </LembarBawah>

    <DokumenCetak v-if="detail" kop="pondok" :judul="judulCetak" :subjudul="detail.nama" v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap">
      <p style="margin: 0 0 6pt; line-height: 1.5">Waktu pulang: {{ formatWaktu(detail.pulang_pada) }} WITA · Batas kembali: {{ formatWaktu(detail.kembali_batas) }} WITA<br />
        Ringkasan: {{ r.boleh }} santri libur dan {{ r.tidak }} santri tinggal di pondok (jumlah {{ r.jumlah }}) · Status: {{ STATUS_PERIODE[detail.status].n }}{{ detail.pengesah ? ' oleh ' + detail.pengesah : '' }}</p>
      <table class="tabel kecil">
        <thead><tr><th style="width:5%">No.</th><th style="width:25%">Nama santri</th><th style="width:7%">Kelas</th><th style="width:14%">Kamar</th>
          <th style="width:7%">Kelas</th><th style="width:7%">Halaqah</th><th style="width:7%">Asrama</th><th style="width:5%">Izin</th><th v-if="daftarCetak === 'semua'" style="width:9%">Hasil</th><th>Keterangan</th></tr></thead>
        <tbody>
          <tr v-for="(s, i) in isiCetak" :key="s.id"><td class="tengah">{{ i + 1 }}</td><td>{{ s.nama }}</td><td class="tengah">{{ s.kelas || '–' }}</td><td>{{ s.kamar || '–' }}</td>
            <td class="tengah">{{ persen(s, 'kelas') }}</td><td class="tengah">{{ persen(s, 'halaqah') }}</td><td class="tengah">{{ persen(s, 'asrama') }}</td><td class="tengah">{{ s.rincian?.izin ?? 0 }}</td>
            <td v-if="daftarCetak === 'semua'" class="tengah">{{ s.keputusan === 'boleh' ? 'Libur' : s.keputusan === 'tidak' ? 'Tinggal' : '–' }}</td>
            <td>{{ [s.alasan_ubah, ...(s.rincian?.gagal || []), ...(s.rincian?.timbang || [])].filter(Boolean).join('; ') || '–' }}</td></tr>
          <tr v-if="!isiCetak.length"><td :colspan="daftarCetak === 'semua' ? 10 : 9" class="tengah">Tidak ada santri.</td></tr>
        </tbody>
      </table>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: penanda.jabatan || 'Kepala Bidang Kesantrian', nama: penanda.nama, niy: penanda.niy }"
          :kanan="{ jabatan: 'Pembuat daftar', nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
      </template>
    </DokumenCetak>
  </div>
</template>
<style scoped>
.pilih-aktif { border-color: var(--c); background: color-mix(in srgb, var(--c) 12%, rgb(var(--permukaan))); }
</style>
