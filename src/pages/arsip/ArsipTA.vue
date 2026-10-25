<!-- SIMKA PRO | src/pages/arsip/ArsipTA.vue | v1.1 | 14.26.0: bilah tab di atas (seragam dengan menu lain) | 25/10/2026 -->
<script setup>
// Arsip Tahun Ajaran (khusus admin dan superadmin). Pergantian tahun ajaran (menu Naik Kelas) membuka lembaran baru tanpa
// menghapus data lama: kelompok, keanggotaan, nilai, dan rapor tahun ajaran sebelumnya tetap tersimpan dan dapat dibuka di sini.
//   Kelompok : kelas, halaqah, kamar, ekskul tahun ajaran terpilih beserta pengasuh dan jumlah anggota (cetak F4)
//   Santri   : santri tahun ajaran itu (termasuk yang kini lulus/keluar) dengan kelas, halaqah, kamar; tautan Rekam Kesantrian
//              rentang tahun ajaran tersebut dan profil alumni
//   Rapor    : pilih kelas dan semester tahun ajaran itu → cetak ulang rapor, leger, sampul, dan dokumen rapor lain
// Data berbasis tanggal (presensi, jurnal, surat, perizinan, klinik, hafalan) dibuka di menu masing-masing dengan rentang tanggal lampau.
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { PhArchive, PhUsersThree, PhStudent, PhExam, PhLockSimple, PhMagnifyingGlass, PhPrinter, PhCaretRight, PhInfo, PhChalkboardTeacher, PhBookOpenText, PhBed, PhMedal, PhGraduationCap } from '@phosphor-icons/vue'
import { useAlumni } from '@/stores/alumni'
import { useRapor } from '@/stores/rapor'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { STATUS_SANTRI, JENJANG_PENDEK } from '@/lib/santri'
import { LABEL_SEMESTER } from '@/lib/nilai'
import { formatPanjang } from '@/lib/tanggal'
import { ambilPenandaTangan } from '@/lib/penandatangan'
import BilahTab from '@/components/BilahTab.vue'
import KartuStatistik from '@/components/KartuStatistik.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import CetakRaporKelas from '@/pages/penilaian/CetakRaporKelas.vue'

const props = defineProps({ tab: { type: String, default: '' } })
const route = useRoute(); const router = useRouter()
const al = useAlumni(); const rp = useRapor(); const sesi = useSesi(); const ui = useUI()
const TAB = [
  { k: 'kelompok', n: 'Kelompok', ikon: PhUsersThree, w: 'kelompoksantri' },
  { k: 'santri', n: 'Santri', ikon: PhStudent, w: 'santri' },
  { k: 'rapor', n: 'Rapor', ikon: PhExam, w: 'rapor' },
]
const aktif = computed(() => (TAB.some((t) => t.k === props.tab) ? props.tab : 'kelompok'))
const pindahTab = (k) => router.replace({ path: `/arsip/${k}`, query: route.query })

const daftarTA = ref([]); const taId = ref(typeof route.query.ta === 'string' ? route.query.ta : '')
const A = ref(null); const memuat = ref(false)
const direktur = ref({ jabatan: 'Direktur', nama: '', niy: '' })
onMounted(async () => {
  ambilPenandaTangan('Direktur').then((d) => { direktur.value = d }).catch(() => {})
  try {
    daftarTA.value = await al.daftarTA()
    if (!taId.value || !daftarTA.value.some((t) => t.id === taId.value)) taId.value = (daftarTA.value.find((t) => !t.aktif) || daftarTA.value[0])?.id || ''
  } catch (e) { ui.toast(e.message, 'galat') }
})
async function muat() {
  if (!taId.value) return
  memuat.value = true; D.value = null; kelas.value = ''
  try { A.value = await al.arsip(taId.value) } catch (e) { ui.toast(e.message, 'galat'); A.value = null } finally { memuat.value = false }
  if (route.query.ta !== taId.value) router.replace({ query: { ...route.query, ta: taId.value } })
}
watch(taId, muat)
const ta = computed(() => A.value?.ta || daftarTA.value.find((t) => t.id === taId.value) || {})
const labelTA = (t) => `${t.nama}${t.aktif ? ' (berjalan)' : t.terkunci ? ' (terkunci)' : ''}`

// ---------- Kelompok ----------
const IKON = { kelas: PhChalkboardTeacher, halaqah: PhBookOpenText, kamar: PhBed, ekskul: PhMedal }
const W = { kelas: 'walikelas', halaqah: 'tahfizh', kamar: 'musyrif', ekskul: 'ekskul' }
const NAMA_JENIS = { kelas: 'Kelas', halaqah: 'Halaqah', kamar: 'Kamar', ekskul: 'Ekskul' }
const PENGASUH = { kelas: 'Wali kelas', halaqah: 'Muhaffizh', kamar: 'Musyrif', ekskul: 'Pembina' }
const perJenis = computed(() => ['kelas', 'halaqah', 'kamar', 'ekskul'].map((j) => ({ j, g: (A.value?.kelompok || []).filter((x) => x.jenis === j) })).filter((x) => x.g.length))
const santri = computed(() => A.value?.santri || [])
const statistik = computed(() => {
  const n = memuat.value ? '…' : null; const k = (j) => (A.value?.kelompok || []).filter((x) => x.jenis === j).length
  return [
    { judul: 'Santri', nilai: n ?? santri.value.length, ikon: PhStudent, warna: 'santri', ket: `Putra ${santri.value.filter((s) => s.jenis_kelamin === 'L').length} · Putri ${santri.value.filter((s) => s.jenis_kelamin === 'P').length}` },
    { judul: 'Kelas', nilai: n ?? k('kelas'), ikon: PhChalkboardTeacher, warna: 'walikelas', ket: 'Rombongan belajar' },
    { judul: 'Halaqah', nilai: n ?? k('halaqah'), ikon: PhBookOpenText, warna: 'tahfizh', ket: 'Kelompok tahfizh' },
    { judul: 'Kamar', nilai: n ?? k('kamar'), ikon: PhBed, warna: 'musyrif', ket: 'Asrama' },
    { judul: 'Kini alumni', nilai: n ?? santri.value.filter((s) => s.status === 'lulus').length, ikon: PhGraduationCap, warna: 'alumni', ket: 'Berstatus lulus' },
  ]
})
const pratinjauKelompok = ref(false); const pratinjauSantri = ref(false)
const subjudul = computed(() => `Tahun Ajaran ${ta.value.nama || ''}${ta.value.mulai ? ` (${formatPanjang(ta.value.mulai)} s.d. ${formatPanjang(ta.value.selesai)})` : ''}`)

// ---------- Santri ----------
const cari = ref(''); const saringKelas = ref('')
const daftarKelas = computed(() => (A.value?.kelompok || []).filter((g) => g.jenis === 'kelas'))
const santriTampil = computed(() => {
  const q = cari.value.toLowerCase().trim()
  return santri.value.filter((s) => (!saringKelas.value || s.kelas_id === saringKelas.value) && (!q || `${s.nama} ${s.nis}`.toLowerCase().includes(q)))
})
const tautanRekam = (s) => ({ path: `/santri/${s.id}/rekam`, query: { mulai: ta.value.mulai, selesai: ta.value.selesai, preset: 'ta-lama' } })

// ---------- Rapor ----------
const kelas = ref(''); const semester = ref(2); const D = ref(null); const memuatRapor = ref(false)
async function bukaRapor() {
  if (!kelas.value) return ui.toast('Pilih kelas terlebih dahulu.', 'galat')
  memuatRapor.value = true; D.value = null
  try { D.value = await rp.dataRapor(kelas.value, semester.value) } catch (e) { ui.toast(e.message, 'galat') } finally { memuatRapor.value = false }
}
watch([kelas, semester], () => { D.value = null })
</script>
<template>
  <div class="w-arsip">
    <div class="mb-4 hidden items-center gap-3 lg:flex">
      <span class="chip-ikon h-12 w-12"><PhArchive :size="28" weight="duotone" /></span>
      <div class="flex-1"><h2 class="text-lg font-bold">Arsip Tahun Ajaran</h2>
        <p class="text-sm text-teks3">Buka kembali kelompok, santri, dan rapor tahun ajaran mana pun. Pergantian tahun ajaran membuka lembaran baru tanpa menghapus data lama.</p></div>
    </div>

    <BilahTab class="mb-4" :tab="TAB" :model-value="aktif" label="Bagian arsip tahun ajaran" @update:model-value="pindahTab" />

    <section class="kartu flex flex-wrap items-end gap-3 p-4">
      <div class="min-w-[200px] flex-1"><label class="label-isian" for="ar-ta">Tahun ajaran</label>
        <select id="ar-ta" v-model="taId" class="isian"><option v-for="t in daftarTA" :key="t.id" :value="t.id">{{ labelTA(t) }}</option></select></div>
      <p v-if="ta.terkunci" class="lencana w-hakakses mb-2"><PhLockSimple :size="14" weight="fill" /> Terkunci (hanya baca)</p>
      <p v-if="ta.mulai" class="mb-2 text-sm text-teks3">{{ formatPanjang(ta.mulai) }} – {{ formatPanjang(ta.selesai) }}</p>
    </section>

    <div class="-mx-4 my-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-3 sm:overflow-visible sm:px-0 xl:grid-cols-5">
      <KartuStatistik v-for="k in statistik" :key="k.judul" class="w-[46%] shrink-0 snap-start sm:w-auto" :judul="k.judul" :nilai="k.nilai" :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket" />
    </div>

    <p v-if="memuat" class="py-10 text-center text-teks3">Memuat arsip…</p>
    <template v-else-if="A">
      <!-- Kelompok -->
      <template v-if="aktif === 'kelompok'">
        <div class="mb-3 flex justify-end"><button class="w-pengajuan tombol-garis px-4 text-sm" :disabled="!A.kelompok.length" @click="pratinjauKelompok = true"><PhPrinter :size="20" weight="duotone" style="color: var(--c)" /> Cetak daftar kelompok</button></div>
        <section v-for="x in perJenis" :key="x.j" :class="['kartu mb-3 p-4', 'w-' + W[x.j]]">
          <h3 class="mb-2 flex items-center gap-2 font-bold"><component :is="IKON[x.j]" :size="20" weight="duotone" style="color: var(--c)" /> {{ NAMA_JENIS[x.j] }} <span class="text-sm font-normal text-teks3">({{ x.g.length }})</span></h3>
          <ul class="grid gap-2 sm:grid-cols-2 xl:grid-cols-3">
            <li v-for="g in x.g" :key="g.id" class="rounded-2xl border border-garis p-3">
              <p class="font-semibold">{{ g.nama }} <span v-if="g.jenjang" class="text-xs font-normal text-teks3">· {{ JENJANG_PENDEK[g.jenjang] }}</span></p>
              <p class="text-sm text-teks2">{{ PENGASUH[x.j] }}: {{ g.pengasuh || '–' }}</p>
              <p class="text-xs text-teks3">Putra {{ g.l }} · Putri {{ g.p }} · Jumlah {{ g.l + g.p }}</p>
            </li>
          </ul>
        </section>
        <p v-if="!perJenis.length" class="kartu p-8 text-center text-sm text-teks3">Belum ada kelompok pada tahun ajaran ini.</p>

        <DokumenCetak judul="Daftar Kelompok Santri" :subjudul="subjudul" v-model:pratinjau="pratinjauKelompok" :pencetak="sesi.pengguna?.nama_lengkap">
          <template v-for="x in perJenis" :key="x.j">
            <p style="margin: 6pt 0 3pt; font-weight: 700">{{ NAMA_JENIS[x.j] }}</p>
            <table class="tabel">
              <colgroup><col style="width:6%"><col style="width:26%"><col style="width:36%"><col style="width:10%"><col style="width:10%"><col style="width:12%"></colgroup>
              <thead><tr><th>No.</th><th>{{ NAMA_JENIS[x.j] }}</th><th>{{ PENGASUH[x.j] }}</th><th>Putra</th><th>Putri</th><th>Jumlah</th></tr></thead>
              <tbody><tr v-for="(g, i) in x.g" :key="g.id"><td class="tengah">{{ i + 1 }}</td><td>{{ g.nama }}</td><td>{{ g.pengasuh || '–' }}</td><td class="tengah">{{ g.l }}</td><td class="tengah">{{ g.p }}</td><td class="tengah">{{ g.l + g.p }}</td></tr></tbody>
            </table>
          </template>
          <template #ttd>
            <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan || 'Direktur', nama: direktur.nama, niy: direktur.niy }"
              :kanan="{ jabatan: 'Yang membuat,', nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
          </template>
        </DokumenCetak>
      </template>

      <!-- Santri -->
      <template v-else-if="aktif === 'santri'">
        <div class="mb-3 flex flex-wrap items-end gap-2">
          <div class="relative min-w-[220px] flex-1"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
            <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari nama atau NIS" aria-label="Cari santri" /></div>
          <select v-model="saringKelas" class="isian w-auto" aria-label="Saring kelas"><option value="">Semua kelas</option><option v-for="g in daftarKelas" :key="g.id" :value="g.id">{{ g.nama }}</option></select>
          <button class="w-pengajuan tombol-garis px-4 text-sm" :disabled="!santriTampil.length" @click="pratinjauSantri = true"><PhPrinter :size="20" weight="duotone" style="color: var(--c)" /> Cetak</button>
        </div>
        <ul class="divide-y divide-garis overflow-hidden rounded-2xl border border-garis bg-permukaan">
          <li v-for="s in santriTampil" :key="s.id" class="flex flex-wrap items-center gap-x-3 gap-y-1 px-4 py-3">
            <div class="min-w-[180px] flex-1">
              <p class="font-semibold">{{ s.nama }} <span :class="['lencana ml-1 text-xs', 'w-' + (STATUS_SANTRI[s.status]?.w || 'audit')]">{{ STATUS_SANTRI[s.status]?.n || s.status }}</span></p>
              <p class="text-xs text-teks3">{{ s.nis }} · {{ s.jenis_kelamin }} · Kelas {{ s.kelas || '–' }} · {{ s.halaqah || 'tanpa halaqah' }} · {{ s.kamar || 'tanpa kamar' }}</p>
            </div>
            <router-link :to="tautanRekam(s)" class="inline-flex min-h-[40px] items-center gap-1 text-sm font-semibold text-teks2 hover:underline">Rekam {{ ta.nama }} <PhCaretRight :size="14" /></router-link>
            <router-link v-if="s.status === 'lulus'" :to="`/alumni/profil/${s.id}`" class="w-alumni inline-flex min-h-[40px] items-center gap-1 text-sm font-semibold" style="color: var(--c)">Profil alumni <PhCaretRight :size="14" /></router-link>
          </li>
          <li v-if="!santriTampil.length" class="p-6 text-center text-sm text-teks3">Tidak ada santri.</li>
        </ul>

        <DokumenCetak judul="Daftar Santri" :subjudul="subjudul + (saringKelas ? ' · Kelas ' + (daftarKelas.find((g) => g.id === saringKelas)?.nama || '') : '')" v-model:pratinjau="pratinjauSantri" :pencetak="sesi.pengguna?.nama_lengkap">
          <table class="tabel">
            <colgroup><col style="width:6%"><col style="width:12%"><col style="width:30%"><col style="width:5%"><col style="width:9%"><col style="width:17%"><col style="width:13%"><col style="width:8%"></colgroup>
            <thead><tr><th>No.</th><th>NIS</th><th>Nama</th><th>JK</th><th>Kelas</th><th>Halaqah</th><th>Kamar</th><th>Status kini</th></tr></thead>
            <tbody><tr v-for="(s, i) in santriTampil" :key="s.id"><td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ s.nis }}</td><td>{{ s.nama }}</td><td class="tengah">{{ s.jenis_kelamin }}</td>
              <td class="tengah">{{ s.kelas || '–' }}</td><td>{{ s.halaqah || '–' }}</td><td>{{ s.kamar || '–' }}</td><td>{{ STATUS_SANTRI[s.status]?.n || s.status }}</td></tr></tbody>
          </table>
          <template #ttd>
            <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan || 'Direktur', nama: direktur.nama, niy: direktur.niy }"
              :kanan="{ jabatan: 'Yang membuat,', nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
          </template>
        </DokumenCetak>
      </template>

      <!-- Rapor -->
      <template v-else>
        <section class="kartu w-rapor flex flex-wrap items-end gap-3 p-4">
          <div class="min-w-[160px] flex-1"><label class="label-isian" for="ar-kelas">Kelas</label>
            <select id="ar-kelas" v-model="kelas" class="isian" aria-label="Pilih kelas arsip"><option value="">Pilih kelas</option><option v-for="g in daftarKelas" :key="g.id" :value="g.id">{{ g.nama }} · {{ JENJANG_PENDEK[g.jenjang] || '' }}</option></select></div>
          <div class="bilah-tab kecil" role="tablist" aria-label="Semester">
            <button v-for="s in [1, 2]" :key="s" type="button" role="tab" :aria-selected="semester === s" @click="semester = s" :class="['tab-garis', semester === s && 'aktif']">{{ LABEL_SEMESTER[s] }}</button>
          </div>
          <button class="tombol-utama" :disabled="!kelas || memuatRapor" @click="bukaRapor"><PhExam :size="20" weight="bold" /> {{ memuatRapor ? 'Memuat…' : 'Buka rapor' }}</button>
        </section>
        <p class="mt-2 flex gap-2 text-xs text-teks3"><PhInfo :size="16" class="shrink-0" /> Rapor tahun ajaran lampau dicetak ulang dari nilai yang tersimpan; nilai tidak dapat diubah bila tahun ajaran terkunci atau periode penilaian ditutup.</p>
        <div class="mt-3">
          <CetakRaporKelas v-if="D" :key="'arsip' + kelas + semester" :D="D" />
          <p v-else-if="!daftarKelas.length" class="kartu p-6 text-center text-sm text-teks3">Belum ada kelas pada tahun ajaran ini.</p>
        </div>
      </template>
    </template>

    <section class="kartu w-audit mt-5 p-4 text-sm text-teks2">
      <p class="mb-1 flex items-center gap-2 font-bold text-teks"><PhInfo :size="18" weight="duotone" style="color: var(--c)" /> Data lain dari tahun ajaran lampau</p>
      <p>Presensi pegawai, jurnal, persuratan, perizinan, klinik, kedisiplinan, dan catatan hafalan tersimpan menurut tanggal. Bukalah di menu masing-masing dengan memilih rentang tanggal tahun ajaran tersebut, atau lewat Rekam Kesantrian (per santri) dan Rekam Pegawai.</p>
    </section>
  </div>
</template>
