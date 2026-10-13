<!-- SIMKA PRO | src/pages/kelompoksantri/KelompokSantri.vue | v1.3 | Perbaikan: absensi hanya di rincian kelompok, penanda tangan rekap sesuai bidang | 14/10/2026 -->
<script setup>
// Pengaturan kelompok santri: kelas, kamar, halaqah, ekskul, lainnya per tahun ajaran (tab berwarna).
// Admin ber-izin kelompok_santri mengatur; pengasuh melihat kelompok asuhannya; pimpinan melihat semua.
// v1.2: warna kartu bervariasi; cetak rekap kelompok (pengasuh, jumlah L/P); cetak absensi manual harian/pekanan per kartu;
//       pengaturan pemisahan putra/putri per jenis (superadmin/admin ber-izin); posisi gulir dipulihkan saat kembali.
import { ref, computed, onMounted, watch, nextTick } from 'vue'
import { useRouter, onBeforeRouteLeave } from 'vue-router'
import BilahTab from '@/components/BilahTab.vue'
import * as XLSX from 'xlsx'
import {
  PhChalkboardTeacher, PhBed, PhBookOpenText, PhMedal, PhUsersThree, PhPlus, PhFileXls, PhDownloadSimple, PhCaretRight,
  PhWarningCircle, PhStar, PhUserCircle, PhGenderMale, PhGenderFemale, PhPrinter, PhGenderIntersex, PhFloppyDisk,
} from '@phosphor-icons/vue'
import { useKelompokSantri } from '@/stores/kelompokSantri'
import { useSantri } from '@/stores/santri'
import { useSesi } from '@/stores/sesi'
import { JENIS_KELOMPOK, PERAN_PENGASUH, subjudulKelompok, namaKelompok, kelompokDari, JENJANG_PENDEK, judulKelompok, penandaKelompok } from '@/lib/santri'
import { formatPendek } from '@/lib/tanggal'
import KartuStatistik from '@/components/KartuStatistik.vue'
import TombolAksi from '@/components/TombolAksi.vue'
import LembarKelompok from './LembarKelompok.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import { useUI } from '@/stores/ui'
import { formatPanjang } from '@/lib/tanggal'

const props = defineProps({ tab: { type: String, default: 'kelas' } })
const router = useRouter(); const kel = useKelompokSantri(); const san = useSantri(); const sesi = useSesi()
const IKON = { kelas: PhChalkboardTeacher, kamar: PhBed, halaqah: PhBookOpenText, ekskul: PhMedal, lainnya: PhUsersThree }
const bolehAtur = computed(() => sesi.bolehAdmin('kelompok_santri') || sesi.tingkat('kelompok_santri') >= 2)
const lihatSemua = computed(() => sesi.isAdmin || sesi.tingkat('data_santri') >= 1 || sesi.tingkat('kelompok_santri') >= 1)
const terkunci = computed(() => !!kel.taSekarang?.terkunci)
const jenis = ref(JENIS_KELOMPOK[props.tab] ? props.tab : 'kelas')
watch(() => props.tab, (t) => { if (JENIS_KELOMPOK[t]) jenis.value = t })
function pilih(j) { jenis.value = j; router.replace(`/kelompok-santri/${j}`) }
const lembar = ref(false); const tampilNonaktif = ref(false); const bukaBelum = ref(false)

// Posisi gulir dipulihkan saat kembali dari halaman kelompok
const KUNCI_GULIR = 'simka.kelompok.gulir'
onBeforeRouteLeave((to) => { try { sessionStorage.setItem(KUNCI_GULIR, JSON.stringify({ jenis: jenis.value, y: window.scrollY, ke: to.path })) } catch { /* abaikan */ } })
onMounted(async () => {
  await Promise.all([kel.daftar.length ? null : kel.muat(), san.muat(), kel.muatPengaturan().catch(() => {})])
  try {
    const g = JSON.parse(sessionStorage.getItem(KUNCI_GULIR) || 'null')
    if (g && g.jenis === jenis.value && g.ke?.startsWith('/kelompok-santri/k/')) { await nextTick(); requestAnimationFrame(() => window.scrollTo({ top: g.y })) }
    sessionStorage.removeItem(KUNCI_GULIR)
  } catch { /* abaikan */ }
})
const ui = useUI()
// ---------- Warna kartu bervariasi ----------
const WARNA = ['laporan', 'tahfizh', 'presensi', 'agenda', 'santri', 'gurumapel', 'ekskul', 'walikelas', 'musyrif', 'jadwal', 'pengajuan', 'penilaian', 'rapor', 'keuangan', 'kelompoksantri', 'pengumuman']
const warnaKartu = (i) => WARNA[(i + Object.keys(JENIS_KELOMPOK).indexOf(jenis.value) * 3) % WARNA.length]
// ---------- Cetak absensi dan rekap ----------
const pratinjauRekap = ref(false)
const penandaRekap = ref({ jabatan: '', nama: '', niy: '' })
// Mengetahui: kepala bidang sesuai jenis (kelas satu jenjang → kepala sekolahnya; kelas lintas jenjang → Direktur)
async function bukaRekap() {
  const jenjang = [...new Set(dariJenis.value.filter((g) => g.aktif).map((g) => g.jenjang))]
  penandaRekap.value = await penandaKelompok({ jenis: jenis.value, jenjang: jenis.value === 'kelas' && jenjang.length === 1 ? jenjang[0] : null }).catch(() => ({ jabatan: 'Pimpinan', nama: '', niy: '' }))
  pratinjauRekap.value = true
}
const totalRekap = computed(() => dariJenis.value.filter((g) => g.aktif).reduce((t, g) => ({ l: t.l + (g.jumlah_l || 0), p: t.p + (g.jumlah_p || 0), n: t.n + (g.jumlah || 0) }), { l: 0, p: 0, n: 0 }))
const JK_NAMA = { L: 'Putra', P: 'Putri' }
// ---------- Pemisahan putra/putri (superadmin dan admin ber-izin) ----------
const bolehPengaturan = computed(() => sesi.isSuperadmin || sesi.bolehAdmin('kelompok_santri'))
const lembarPisah = ref(false); const pisah = ref({}); const prosesPisah = ref(false)
function bukaPisah() { pisah.value = { ...(kel.pengaturan?.pisah_jk || {}) }; for (const j of Object.keys(JENIS_KELOMPOK)) pisah.value[j] = kel.pisahJk(j); lembarPisah.value = true }
async function simpanPisah() {
  prosesPisah.value = true
  try { await kel.simpanPengaturan(pisah.value); lembarPisah.value = false; ui.toast('Pengaturan pemisahan putra/putri disimpan.') } catch (e) { ui.toast(e.message, 'galat') } finally { prosesPisah.value = false }
}

const kelompokTA = computed(() => kel.dariTA)
const dariJenis = computed(() => kelompokTA.value.filter((g) => g.jenis === jenis.value && (tampilNonaktif.value || g.aktif)))
const hitung = (j) => kelompokTA.value.filter((g) => g.jenis === j && g.aktif).length
const santriAktif = computed(() => san.daftar.filter((s) => s.status === 'aktif'))
const taBerjalan = computed(() => !kel.taSekarang || kel.taSekarang.aktif)
const belum = computed(() => (['kelas', 'kamar', 'halaqah'].includes(jenis.value) && taBerjalan.value
  ? santriAktif.value.filter((s) => !kelompokDari(s, jenis.value)) : []))
const belumLengkap = computed(() => santriAktif.value.filter((s) => ['kelas', 'kamar', 'halaqah'].some((j) => !kelompokDari(s, j))).length)

const statistik = computed(() => [
  ...['kelas', 'kamar', 'halaqah', 'ekskul'].map((j) => ({
    judul: JENIS_KELOMPOK[j].jamak, nilai: hitung(j), ikon: IKON[j], warna: JENIS_KELOMPOK[j].warna,
    ket: `${kelompokTA.value.filter((g) => g.jenis === j && g.aktif).reduce((n, g) => n + (g.jumlah || 0), 0)} keanggotaan santri`,
  })),
  ...(lihatSemua.value ? [{ judul: 'Belum lengkap', nilai: belumLengkap.value, ikon: PhWarningCircle, warna: 'klinik', ket: 'Santri aktif tanpa kelas, kamar, atau halaqah' }] : []),
])
const utama = (g) => (g.pengasuh || []).filter((p) => p.berlaku !== false)

// Ekspor pembagian (sekaligus dapat dipakai sebagai templat impor)
function eksporPembagian() {
  const kolom = ['No.', 'NIS', 'Nama', 'L/P', 'Kelas (tingkat)', 'Kelas', 'Kamar', 'Halaqah', 'Ekskul']
  const data = santriAktif.value.map((s, i) => [i + 1, s.nis, s.nama_lengkap, s.jenis_kelamin, `${s.tingkat} ${JENJANG_PENDEK[s.jenjang]}`,
    namaKelompok(s, 'kelas'), namaKelompok(s, 'kamar'), namaKelompok(s, 'halaqah'), namaKelompok(s, 'ekskul')])
  const ws = XLSX.utils.aoa_to_sheet([kolom, ...data])
  ws['!cols'] = [{ wch: 5 }, { wch: 10 }, { wch: 30 }, { wch: 5 }, { wch: 14 }, { wch: 12 }, { wch: 22 }, { wch: 26 }, { wch: 30 }]
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Pembagian kelompok')
  XLSX.writeFile(wb, `Pembagian-Kelompok-Santri-${formatPendek(new Date()).replace(/\//g, '-')}.xlsx`)
}
</script>
<template>
  <div>
    <!-- Kepala halaman -->
    <div class="mb-4 flex flex-wrap items-center gap-3">
      <span class="w-kelompoksantri chip-ikon hidden h-12 w-12 lg:grid"><PhUsersThree :size="28" weight="duotone" /></span>
      <div class="min-w-[200px] flex-1">
        <h2 class="text-lg font-bold">{{ lihatSemua ? 'Kelompok Santri' : 'Kelompok asuhan saya' }}</h2>
        <p class="text-sm text-teks3">Tahun ajaran {{ kel.taSekarang?.nama || '–' }}{{ terkunci ? ' (arsip, baca saja)' : '' }}</p>
      </div>
      <select v-if="kel.tahunAjaran.length > 1" v-model="kel.taDipilih" class="isian w-auto" aria-label="Pilih tahun ajaran">
        <option v-for="t in kel.tahunAjaran" :key="t.id" :value="t.id">{{ t.nama }}{{ t.aktif ? ' (aktif)' : t.terkunci ? ' (arsip)' : '' }}</option>
      </select>
      <button v-if="bolehAtur && !terkunci" class="tombol-utama hidden lg:inline-flex" @click="lembar = true"><PhPlus :size="20" weight="bold" /> Tambah {{ JENIS_KELOMPOK[jenis].n.toLowerCase() }}</button>
    </div>

    <!-- Kartu statistik -->
    <div class="-mx-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-3 sm:overflow-visible sm:px-0 xl:grid-cols-5">
      <KartuStatistik v-for="k in statistik" :key="k.judul" class="w-[46%] shrink-0 snap-start sm:w-auto" :judul="k.judul" :nilai="kel.memuat && !kel.daftar.length ? '…' : k.nilai"
        :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket" />
    </div>

    <!-- Aksi -->
    <div v-if="lihatSemua" class="-mx-4 mt-4 flex gap-2 overflow-x-auto px-4 pb-1 lg:mx-0 lg:px-0">
      <router-link v-if="bolehAtur && !terkunci" to="/kelompok-santri/impor" class="w-gaji tombol-garis shrink-0 px-4 text-sm"><PhFileXls :size="20" weight="duotone" style="color: var(--c)" /> Impor pembagian</router-link>
      <button class="w-santri tombol-garis shrink-0 px-4 text-sm" @click="eksporPembagian"><PhDownloadSimple :size="20" weight="duotone" style="color: var(--c)" /> Ekspor pembagian</button>
      <button class="w-pengajuan tombol-garis shrink-0 px-4 text-sm" @click="bukaRekap"><PhPrinter :size="20" weight="duotone" style="color: var(--c)" /> Cetak rekap {{ JENIS_KELOMPOK[jenis].jamak.toLowerCase() }}</button>
      <button v-if="bolehPengaturan" class="w-penilaian tombol-garis shrink-0 px-4 text-sm" @click="bukaPisah"><PhGenderIntersex :size="20" weight="duotone" style="color: var(--c)" /> Pemisahan putra/putri</button>
      <label class="tombol-garis shrink-0 cursor-pointer px-4 text-sm"><input v-model="tampilNonaktif" type="checkbox" class="h-4 w-4 accent-[#0B7F81]" /> Tampilkan nonaktif</label>
    </div>

    <!-- Tab jenis kelompok (warna berbeda per tab) -->
    <BilahTab class="mt-4" :tab="Object.entries(JENIS_KELOMPOK).map(([k, j]) => ({ k, n: j.jamak, ikon: IKON[k], w: j.warna, jumlah: hitung(k) }))" :model-value="jenis" label="Jenis kelompok" @update:model-value="pilih" />

    <p v-if="kel.galat" class="mt-4 rounded-xl bg-[#C7332F]/10 p-3 text-sm font-semibold text-merah">{{ kel.galat }}</p>

    <!-- Santri belum berkelompok -->
    <div v-if="lihatSemua && belum.length" class="kartu w-klinik mt-4 p-4">
      <button class="flex w-full items-center gap-3 text-left" :aria-expanded="bukaBelum" @click="bukaBelum = !bukaBelum">
        <span class="chip-ikon h-10 w-10"><PhWarningCircle :size="22" weight="duotone" /></span>
        <span class="flex-1"><span class="block font-bold">{{ belum.length }} santri aktif belum memiliki {{ JENIS_KELOMPOK[jenis].n.toLowerCase() }}</span>
          <span class="block text-sm text-teks3">Ketuk untuk melihat daftarnya; masukkan lewat halaman kelompok atau impor pembagian.</span></span>
        <PhCaretRight :size="20" :class="['text-teks3 transition', bukaBelum && 'rotate-90']" />
      </button>
      <ul v-if="bukaBelum" class="mt-3 flex flex-wrap gap-1.5">
        <li v-for="s in belum" :key="s.id"><router-link :to="`/santri/${s.id}`" class="lencana px-3 py-1 text-sm">{{ s.nama_lengkap }} · {{ s.tingkat }} {{ JENJANG_PENDEK[s.jenjang] }}</router-link></li>
      </ul>
    </div>

    <!-- Daftar kelompok -->
    <ul class="mt-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
      <li v-for="(g, i) in dariJenis" :key="g.id" :class="['kartu kartu-kelompok flex h-full flex-col transition hover:-translate-y-0.5 hover:shadow-apung', 'w-' + warnaKartu(i), !g.aktif && 'opacity-70']">
        <router-link :to="`/kelompok-santri/k/${g.id}`" class="flex flex-1 flex-col gap-3 p-4">
          <div class="flex items-start gap-3">
            <span class="chip-ikon h-11 w-11"><component :is="IKON[g.jenis]" :size="24" weight="duotone" /></span>
            <div class="min-w-0 flex-1">
              <p class="truncate font-bold">{{ judulKelompok(g) }}</p>
              <p class="text-sm text-teks3">{{ subjudulKelompok(g) }}{{ g.keterangan ? ' · ' + g.keterangan : '' }}</p>
            </div>
            <span v-if="g.asuhan_saya" class="lencana w-tahfizh"><PhStar :size="12" weight="fill" /> Asuhan Anda</span>
            <span v-else-if="!g.aktif" class="lencana w-hakakses">Nonaktif</span>
          </div>
          <div class="flex flex-wrap items-center gap-x-4 gap-y-1 text-sm">
            <span class="font-extrabold tabular-nums" style="color: var(--c)">{{ g.jumlah || 0 }} santri</span>
            <span class="inline-flex items-center gap-1 text-teks2"><PhGenderMale :size="15" /> {{ g.jumlah_l || 0 }}</span>
            <span class="inline-flex items-center gap-1 text-teks2"><PhGenderFemale :size="15" /> {{ g.jumlah_p || 0 }}</span>
          </div>
          <div class="mt-auto flex items-start gap-2 border-t border-garis pt-3 text-sm">
            <PhUserCircle :size="18" class="mt-0.5 shrink-0 text-teks3" />
            <span v-if="utama(g).length" class="text-teks2">
              <template v-for="(p, i) in utama(g)" :key="p.employee_id">{{ i ? ', ' : '' }}{{ p.nama }}<span v-if="p.peran !== 'utama'" class="text-teks3"> ({{ PERAN_PENGASUH[p.peran].toLowerCase() }})</span></template>
            </span>
            <span v-else class="font-semibold text-merah">{{ JENIS_KELOMPOK[g.jenis].pengasuh }} belum ditetapkan</span>
          </div>
        </router-link>
      </li>
    </ul>
    <p v-if="!dariJenis.length && !kel.memuat" class="kartu mt-4 py-10 text-center text-sm text-teks3">
      {{ lihatSemua ? `Belum ada ${JENIS_KELOMPOK[jenis].jamak.toLowerCase()} di tahun ajaran ini.` : `Anda belum ditetapkan sebagai ${JENIS_KELOMPOK[jenis].pengasuh.toLowerCase()} pada tahun ajaran ini.` }}
      <template v-if="bolehAtur && !terkunci"><br />Ketuk Tambah atau gunakan Impor pembagian.</template>
    </p>

    <TombolAksi v-if="bolehAtur && !terkunci" label="Tambah" :ikon="PhPlus" warna="kelompoksantri" @klik="lembar = true" />
    <LembarKelompok v-model="lembar" :jenis="jenis" @tersimpan="(id) => router.push(`/kelompok-santri/k/${id}`)" />

    <LembarBawah v-model="lembarPisah" judul="Pemisahan putra/putri">
      <div class="space-y-3 pb-2">
        <p class="text-sm text-teks2">Bila aktif, kelompok jenis itu wajib ditentukan putra atau putri, dan hanya santri berjenis kelamin sama yang dapat dimasukkan. Bila nonaktif, kelompok boleh campuran.</p>
        <ul class="divide-y divide-garis rounded-xl border border-garis">
          <li v-for="(j, k) in JENIS_KELOMPOK" :key="k" class="flex items-center gap-3 px-3 py-2.5">
            <div class="min-w-0 flex-1"><p class="text-sm font-semibold">{{ j.jamak }}</p>
              <p class="text-xs text-teks3">{{ pisah[k] ? 'Dipisah putra/putri' : 'Boleh campuran' }}{{ kel.pengaturan?.campuran?.[k] ? ` · ${kel.pengaturan.campuran[k]} kelompok campuran saat ini` : '' }}</p></div>
            <button type="button" role="switch" :aria-checked="!!pisah[k]" :aria-label="`Pisahkan putra/putri: ${j.jamak}`" @click="pisah[k] = !pisah[k]"
              :class="['relative h-8 w-14 shrink-0 rounded-full transition', pisah[k] ? 'bg-[#1E7D4F]' : 'bg-garis']"><span :class="['absolute top-1 h-6 w-6 rounded-full bg-white shadow transition-all', pisah[k] ? 'left-7' : 'left-1']" /></button>
          </li>
        </ul>
        <p class="text-xs text-teks3">Kelompok campuran yang sudah ada tetap berjalan; saat diubah, putra/putri harus dipilih bila pemisahan diaktifkan.</p>
        <button class="tombol-utama w-full" :disabled="prosesPisah" @click="simpanPisah"><PhFloppyDisk :size="20" weight="duotone" /> {{ prosesPisah ? 'Menyimpan…' : 'Simpan pengaturan' }}</button>
      </div>
    </LembarBawah>

    <DokumenCetak kop="pondok" :judul="`Rekap ${JENIS_KELOMPOK[jenis].jamak}`" :subjudul="`Tahun ajaran ${kel.taSekarang?.nama || '–'} · keadaan ${formatPanjang(new Date())}`"
      v-model:pratinjau="pratinjauRekap" :pencetak="sesi.pengguna?.nama_lengkap">
      <table class="tabel kecil"><colgroup><col style="width:5%"><col style="width:20%"><col style="width:12%"><col style="width:33%"><col style="width:10%"><col style="width:10%"><col style="width:10%"></colgroup>
        <thead><tr><th>No.</th><th>{{ JENIS_KELOMPOK[jenis].n }}</th><th>{{ jenis === 'kelas' ? 'Jenjang' : 'Putra/Putri' }}</th><th>{{ JENIS_KELOMPOK[jenis].pengasuh }}</th><th>L</th><th>P</th><th>Jumlah</th></tr></thead>
        <tbody>
          <tr v-for="(g, i) in dariJenis.filter((x) => x.aktif)" :key="g.id"><td class="tengah">{{ i + 1 }}</td><td>{{ judulKelompok(g) }}{{ g.keterangan ? ` (${g.keterangan})` : '' }}</td>
            <td class="tengah">{{ jenis === 'kelas' ? `${JENJANG_PENDEK[g.jenjang] || ''} ${g.tingkat || ''}` : JK_NAMA[g.jenis_kelamin] || 'Campuran' }}</td>
            <td>{{ utama(g).map((p) => p.nama).join(', ') || '–' }}</td><td class="tengah">{{ g.jumlah_l || 0 }}</td><td class="tengah">{{ g.jumlah_p || 0 }}</td><td class="tengah">{{ g.jumlah || 0 }}</td></tr>
          <tr><td colspan="4" class="tengah" style="font-weight: 700">Jumlah</td><td class="tengah">{{ totalRekap.l }}</td><td class="tengah">{{ totalRekap.p }}</td><td class="tengah">{{ totalRekap.n }}</td></tr>
        </tbody></table>
      <template #ttd><TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: penandaRekap.jabatan, nama: penandaRekap.nama, niy: penandaRekap.niy }" :kanan="{ jabatan: sesi.pengguna?.jabatan || 'Pencetak', nama: sesi.pengguna?.nama_lengkap || '' }" /></template>
    </DokumenCetak>
  </div>
</template>
