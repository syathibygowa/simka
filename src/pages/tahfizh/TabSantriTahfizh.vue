<!-- SIMKA PRO | src/pages/tahfizh/TabSantriTahfizh.vue | v1.0 | Fase 5 – Tahap 1 Pengaturan tahfizh dan data hafalan awal | 05/10/2026 -->
<script setup>
// Data hafalan santri sesuai cakupan (muhaffizh: halaqahnya; pimpinan/admin: semua): program, posisi sabaq/sabqi/manzil,
// juz sedang dihafal, ceklist juz resmi. Pemegang validasi tahfizh mengisi data hafalan awal (satu per satu atau impor Excel)
// dan mengatur program Reguler/Takhassus. Ekspor Excel = susunan templat impor. Cetak daftar F4 mendatar.
import { ref, computed, onMounted } from 'vue'
import * as XLSX from 'xlsx'
import {
  PhMagnifyingGlass, PhUsersThree, PhSealCheck, PhCrown, PhStar, PhQuestion, PhFileXls, PhDownloadSimple, PhEye,
  PhCaretRight, PhUserSwitch, PhFloppyDisk,
} from '@phosphor-icons/vue'
import { useTahfizh } from '@/stores/tahfizh'
import { useKelompokSantri } from '@/stores/kelompokSantri'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { PROGRAM, KET_POSISI, formatPosisi, ringkasJuz, kategoriJuz, dariHal, penandaTahfizh } from '@/lib/tahfizh'
import { inisial, JENJANG_PENDEK } from '@/lib/santri'
import { formatPanjang, formatPendek, formatWaktu, hariIniISO } from '@/lib/tanggal'
import KartuStatistik from '@/components/KartuStatistik.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import GridJuz from '@/components/GridJuz.vue'
import InputPosisi from '@/components/InputPosisi.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const tz = useTahfizh(); const kel = useKelompokSantri(); const sesi = useSesi(); const ui = useUI()
onMounted(async () => { if (!tz.hakDimuat) await tz.muatHak(); await kel.muat(); await tz.muatSantri() })
const bolehUbah = computed(() => tz.hak.validasi)
const bolehProgram = computed(() => tz.hak.validasi || tz.hak.atur)

// ---------- Saringan ----------
const cari = ref(''); const halaqah = ref(''); const program = ref(''); const kategori = ref('')
const halaqahList = computed(() => [...new Map(tz.santri.filter((s) => s.halaqah_id).map((s) => [s.halaqah_id, s.halaqah])).entries()]
  .map(([id, nama]) => ({ id, nama })).sort((a, b) => a.nama.localeCompare(b.nama, 'id', { numeric: true })))
const terdata = (s) => s.total_resmi > 0 || s.sabaq_hal > 0 || !!s.posisi_pada
const tampil = computed(() => {
  const q = cari.value.toLowerCase().trim()
  return tz.santri.filter((s) => (!halaqah.value || (halaqah.value === '-' ? !s.halaqah_id : s.halaqah_id === halaqah.value))
    && (!program.value || s.program === program.value)
    && (!kategori.value || kategoriJuz(s.total_resmi, terdata(s)) === kategori.value)
    && (!q || `${s.nama} ${s.nis} ${s.kelas || ''} ${s.halaqah || ''}`.toLowerCase().includes(q)))
})
const KATEGORI = ['Tidak terdata', 'Di bawah 5 juz', 'Di atas 5 juz', 'Di atas 10 juz', 'Di atas 15 juz', 'Di atas 20 juz', 'Di atas 25 juz', 'Khatam 30 juz']

// ---------- Kartu statistik (dihitung dari data yang tampil) ----------
const statistik = computed(() => {
  const d = tampil.value; const n = d.length || 1
  const rata = d.reduce((t, s) => t + s.total_resmi, 0) / n
  return [
    { judul: 'Santri', nilai: d.length, ikon: PhUsersThree, warna: 'santri', ket: halaqah.value ? 'Di halaqah terpilih' : 'Sesuai saringan' },
    { judul: 'Rata-rata hafalan resmi', nilai: `${rata.toLocaleString('id-ID', { maximumFractionDigits: 1 })} juz`, ikon: PhSealCheck, warna: 'tahfizh', ket: 'Dari juz yang sudah ditetapkan' },
    { judul: 'Khatam 30 juz', nilai: d.filter((s) => s.total_resmi >= 30).length, ikon: PhCrown, warna: 'presensi', ket: 'Total hafalan resmi 30 juz' },
    { judul: 'Program Takhassus', nilai: d.filter((s) => s.program === 'takhassus').length, ikon: PhStar, warna: 'pengajuan', ket: `${d.filter((s) => s.program === 'reguler').length} santri Reguler` },
    { judul: 'Belum terdata', nilai: d.filter((s) => !terdata(s)).length, ikon: PhQuestion, warna: 'klinik', ket: 'Posisi dan juz resmi masih kosong · ketuk untuk menyaring', saring: true },
  ]
})

// ---------- Rincian dan ubah data awal ----------
const lembar = ref(false); const pilih = ref(null); const form = ref(null); const proses = ref(false)
function buka(s) {
  pilih.value = s
  form.value = { program: s.program, juz: [...s.juz_awal], sabaq_hal: s.sabaq_hal, sabqi_hal: s.sabqi_hal, manzil_hal: s.manzil_hal, juz_sedang: s.juz_sedang || '' }
  lembar.value = true
}
const juzTerkunci = computed(() => (pilih.value ? pilih.value.juz_resmi.filter((j) => !pilih.value.juz_awal.includes(j)) : []))
const peringatan = computed(() => {
  if (!form.value) return []
  const p = []; const total = new Set([...form.value.juz, ...juzTerkunci.value]).size
  if (form.value.sabaq_hal < total * 20) p.push(`Posisi sabaq (${formatPosisi(form.value.sabaq_hal)}) lebih kecil dari total juz resmi (${total} juz). Periksa kembali.`)
  if (form.value.juz_sedang && [...form.value.juz, ...juzTerkunci.value].includes(Number(form.value.juz_sedang))) p.push(`Juz ${form.value.juz_sedang} sudah tercentang sebagai hafalan resmi.`)
  return p
})
async function simpan() {
  if (!(await ui.konfirmasi({ judul: 'Simpan data hafalan awal?', pesan: `Juz data awal ${pilih.value.nama} diganti dengan pilihan ini (${ringkasJuz(form.value.juz) || 'tidak ada'}). Juz hasil ujian/sertifikasi tidak berubah.`, ya: 'Simpan' }))) return
  proses.value = true
  try {
    await tz.simpanHafalanAwal(pilih.value.student_id, { ...form.value, juz_sedang: form.value.juz_sedang || null })
    lembar.value = false; ui.toast('Data hafalan awal disimpan.')
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}

// ---------- Program massal ----------
const lembarProgram = ref(false); const programBaru = ref('takhassus'); const centang = ref([])
function bukaProgram() { centang.value = []; programBaru.value = 'takhassus'; lembarProgram.value = true }
const semuaTercentang = computed(() => tampil.value.length > 0 && tampil.value.every((s) => centang.value.includes(s.student_id)))
const centangSemua = () => { centang.value = semuaTercentang.value ? [] : tampil.value.map((s) => s.student_id) }
async function simpanProgram() {
  if (!centang.value.length) return ui.toast('Pilih sedikitnya satu santri.', 'galat')
  proses.value = true
  try { const n = await tz.aturProgram(centang.value, programBaru.value); lembarProgram.value = false; ui.toast(`${n} santri kini program ${PROGRAM[programBaru.value]}.`) }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}

// ---------- Ekspor Excel (susunan templat impor) ----------
function eksporExcel() {
  const judul = ['NIS', 'Info: Nama', 'Info: Kelas', 'Info: Halaqah', 'Program (Reguler/Takhassus)', 'Juz resmi (mis. 1-5, 30)', 'Sabaq juz', 'Sabaq halaman',
    'Sabqi juz', 'Sabqi halaman', 'Manzil juz', 'Manzil halaman', 'Juz sedang dihafal']
  const data = tampil.value.map((s) => [s.nis, s.nama, s.kelas || '', s.halaqah || '', PROGRAM[s.program], ringkasJuz(s.juz_resmi).replace(/–/g, '-'),
    dariHal(s.sabaq_hal).juz, dariHal(s.sabaq_hal).hal, dariHal(s.sabqi_hal).juz, dariHal(s.sabqi_hal).hal, dariHal(s.manzil_hal).juz, dariHal(s.manzil_hal).hal, s.juz_sedang || ''])
  const ws = XLSX.utils.aoa_to_sheet([judul, ...data])
  ws['!cols'] = judul.map((j, i) => ({ wch: Math.min(34, Math.max(j.length, ...data.map((r) => String(r[i]).length)) + 2) }))
  for (const r of Object.keys(ws)) if (!r.startsWith('!') && ws[r].t === 's') ws[r].z = '@'
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Hafalan')
  const p = XLSX.utils.aoa_to_sheet([['Data Hafalan Santri SIMKA PRO (susunan templat impor hafalan awal v1.0)'], [''],
    ['1. Kolom NIS dipakai untuk mencocokkan santri; jangan diubah. Kolom berawalan "Info:" tidak diimpor.'],
    ['2. Juz resmi: tulis nomor juz yang sudah hafal, dipisah koma; rentang boleh memakai tanda minus (1-5, 30). Urutan bebas.'],
    ['3. Posisi ditulis Juz + Halaman (20 halaman = 1 juz). Sabaq = jumlah hafalan berjalan; sabqi dan manzil = posisi muraja\'ah.'],
    ['4. Juz hasil ujian/sertifikasi tidak dapat dihapus lewat impor. Sel posisi yang kosong tidak mengubah data lama.'],
    ['5. Impor di Tahfizh → Data hafalan → Impor Excel.']])
  p['!cols'] = [{ wch: 120 }]; XLSX.utils.book_append_sheet(wb, p, 'Petunjuk')
  XLSX.writeFile(wb, `Data-Hafalan-Santri-${formatPendek(new Date()).replace(/\//g, '-')}.xlsx`)
}

// ---------- Cetak ----------
const pratinjau = ref(false); const kepala = ref({ jabatan: '', nama: '', niy: '' })
const muhaffizhCetak = computed(() => {
  if (!halaqah.value || halaqah.value === '-') return null
  const g = kel.cari(halaqah.value); const p = (g?.pengasuh || []).find((x) => x.peran === 'utama' && x.berlaku !== false)
  return { jabatan: 'Muhaffizh', nama: p?.nama || '', niy: p?.niy || '' }
})
async function cetak() { kepala.value = await penandaTahfizh(); pratinjau.value = true }
const judulCetak = computed(() => `Daftar Hafalan Santri${halaqah.value && halaqah.value !== '-' ? ' ' + (halaqahList.value.find((h) => h.id === halaqah.value)?.nama || '') : ''}`)
</script>
<template>
  <div>
    <div class="layar-saja">
      <!-- Kartu statistik -->
      <div class="-mx-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-3 sm:overflow-visible sm:px-0 xl:grid-cols-5">
        <KartuStatistik v-for="k in statistik" :key="k.judul" class="w-[46%] shrink-0 snap-start sm:w-auto" :judul="k.judul" :nilai="tz.memuat && !tz.santri.length ? '…' : k.nilai"
          :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket" :class="k.saring && 'cursor-pointer'" @click="k.saring && (kategori = kategori === 'Tidak terdata' ? '' : 'Tidak terdata')" />
      </div>

      <!-- Aksi -->
      <div class="-mx-4 mb-4 mt-4 flex gap-2 overflow-x-auto px-4 pb-1 lg:mx-0 lg:px-0">
        <router-link v-if="bolehUbah" to="/tahfizh/impor" class="w-gaji tombol-garis shrink-0 px-4 text-sm"><PhFileXls :size="20" weight="duotone" style="color: var(--c)" /> Impor hafalan awal</router-link>
        <button v-if="bolehProgram" class="w-pengajuan tombol-garis shrink-0 px-4 text-sm" @click="bukaProgram"><PhUserSwitch :size="20" weight="duotone" style="color: var(--c)" /> Atur program</button>
        <button class="w-santri tombol-garis shrink-0 px-4 text-sm" @click="eksporExcel"><PhDownloadSimple :size="20" weight="duotone" style="color: var(--c)" /> Ekspor Excel</button>
        <button class="w-laporan tombol-garis shrink-0 px-4 text-sm" @click="cetak"><PhEye :size="20" weight="duotone" style="color: var(--c)" /> Pratinjau cetak</button>
      </div>

      <!-- Saringan -->
      <div class="flex flex-wrap gap-2">
        <div class="relative min-w-[220px] flex-1">
          <PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
          <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari nama, NIS, kelas, atau halaqah" aria-label="Cari santri" />
        </div>
        <select v-model="halaqah" class="isian w-auto" aria-label="Saring halaqah">
          <option value="">Semua halaqah</option><option v-for="h in halaqahList" :key="h.id" :value="h.id">{{ h.nama }}</option><option value="-">Belum masuk halaqah</option>
        </select>
        <select v-model="program" class="isian w-auto" aria-label="Saring program"><option value="">Semua program</option><option v-for="(n, k) in PROGRAM" :key="k" :value="k">{{ n }}</option></select>
        <select v-model="kategori" class="isian w-auto" aria-label="Saring kategori hafalan"><option value="">Semua kategori</option><option v-for="k in KATEGORI" :key="k" :value="k">{{ k }}</option></select>
      </div>

      <p v-if="tz.galat" class="mt-4 rounded-xl bg-[#C7332F]/10 p-3 text-sm font-semibold text-merah">{{ tz.galat }}</p>

      <!-- Tabel desktop -->
      <div class="kartu mt-4 hidden overflow-x-auto lg:block">
        <table class="w-full text-left text-sm">
          <thead class="border-b border-garis bg-permukaan2 text-teks2">
            <tr><th class="px-4 py-3 font-bold">NIS</th><th class="px-4 py-3 font-bold">Nama</th><th class="px-4 py-3 font-bold">Kelas · halaqah</th><th class="px-4 py-3 font-bold">Program</th>
              <th class="px-4 py-3 font-bold">Sabaq</th><th class="px-4 py-3 font-bold">Sedang</th><th class="w-56 px-4 py-3 font-bold">Juz resmi</th><th class="px-4 py-3 text-right font-bold">Total</th><th class="w-10" /></tr>
          </thead>
          <tbody class="divide-y divide-garis">
            <tr v-for="s in tampil" :key="s.student_id" class="cursor-pointer hover:bg-permukaan2" @click="buka(s)">
              <td class="px-4 py-3 tabular-nums text-teks2">{{ s.nis }}</td>
              <td class="px-4 py-3 font-semibold text-teks">{{ s.nama }}</td>
              <td class="px-4 py-3 text-teks2">{{ s.kelas || `Kelas ${s.tingkat}` }} · {{ s.halaqah || 'belum masuk halaqah' }}</td>
              <td class="px-4 py-3"><span :class="['lencana', s.program === 'takhassus' ? 'w-pengajuan' : 'w-hakakses']">{{ PROGRAM[s.program] }}</span></td>
              <td class="whitespace-nowrap px-4 py-3 tabular-nums text-teks2">{{ formatPosisi(s.sabaq_hal) }}</td>
              <td class="whitespace-nowrap px-4 py-3 tabular-nums text-teks2">{{ s.juz_sedang ? `Juz ${s.juz_sedang}` : '–' }}</td>
              <td class="px-4 py-3"><GridJuz ringkas :model-value="s.juz_awal" :terkunci="s.juz_resmi.filter((j) => !s.juz_awal.includes(j))" :sedang="s.juz_sedang" /></td>
              <td class="px-4 py-3 text-right font-bold tabular-nums">{{ s.total_resmi }} juz</td>
              <td class="pr-3"><PhCaretRight :size="18" class="text-teks3" /></td>
            </tr>
          </tbody>
        </table>
        <p v-if="!tampil.length && !tz.memuat" class="py-10 text-center text-sm text-teks3">{{ tz.santri.length ? 'Tidak ada santri yang cocok dengan saringan.' : 'Belum ada santri pada cakupan Anda. Pastikan halaqah dan anggotanya sudah diatur di Kelompok Santri.' }}</p>
      </div>

      <!-- Kartu mobile -->
      <ul class="mt-4 space-y-2.5 lg:hidden">
        <li v-for="s in tampil" :key="s.student_id">
          <button type="button" class="kartu w-full p-3.5 text-left active:bg-permukaan2" @click="buka(s)">
            <span class="flex items-center gap-3">
              <span :class="['chip-ikon h-11 w-11 text-sm font-extrabold', s.jenis_kelamin === 'P' ? 'w-klinik' : 'w-tahfizh']">{{ inisial(s.nama) }}</span>
              <span class="min-w-0 flex-1">
                <span class="block truncate font-bold">{{ s.nama }}</span>
                <span class="block truncate text-sm text-teks3">{{ s.nis }} · {{ s.kelas || `Kelas ${s.tingkat}` }} · {{ s.halaqah || 'tanpa halaqah' }}</span>
              </span>
              <span class="text-right"><b class="block text-lg tabular-nums leading-tight">{{ s.total_resmi }}</b><span class="text-[11px] text-teks3">juz resmi</span></span>
            </span>
            <span class="mt-2.5 block"><GridJuz ringkas :model-value="s.juz_awal" :terkunci="s.juz_resmi.filter((j) => !s.juz_awal.includes(j))" :sedang="s.juz_sedang" /></span>
            <span class="mt-2 flex flex-wrap gap-1.5 text-xs">
              <span :class="['lencana', s.program === 'takhassus' ? 'w-pengajuan' : 'w-hakakses']">{{ PROGRAM[s.program] }}</span>
              <span class="lencana w-tahfizh">Sabaq {{ formatPosisi(s.sabaq_hal) }}</span>
              <span v-if="s.juz_sedang" class="lencana w-pegawai">Sedang juz {{ s.juz_sedang }}</span>
            </span>
          </button>
        </li>
        <li v-if="!tampil.length && !tz.memuat" class="py-10 text-center text-sm text-teks3">{{ tz.santri.length ? 'Tidak ada santri yang cocok dengan saringan.' : 'Belum ada santri pada cakupan Anda.' }}</li>
      </ul>
    </div>

    <!-- Rincian / data hafalan awal -->
    <LembarBawah v-model="lembar" :judul="pilih ? pilih.nama : ''">
      <div v-if="pilih && form" class="space-y-4 pb-2">
        <p class="text-sm text-teks3">{{ pilih.nis }} · {{ pilih.kelas || `Kelas ${pilih.tingkat} ${JENJANG_PENDEK[pilih.jenjang]}` }} · {{ pilih.halaqah || 'belum masuk halaqah' }}
          <template v-if="pilih.posisi_pada"><br />Posisi terakhir {{ pilih.posisi_sumber === 'awal' ? 'dari data awal' : 'dari setoran' }}, {{ formatWaktu(pilih.posisi_pada) }} WITA</template></p>

        <div v-if="bolehUbah" class="w-tahfizh rounded-xl p-3 text-sm" style="background: color-mix(in srgb, var(--c) 10%, transparent)">
          Data awal = hafalan santri sebelum SIMKA dipakai; langsung dianggap resmi tanpa ujian. Hafalan berikutnya ditetapkan lewat ujian kenaikan juz.
        </div>

        <div v-if="bolehProgram">
          <p class="label-isian">Program tahfizh</p>
          <div class="grid grid-cols-2 gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" aria-label="Program tahfizh">
            <button v-for="(n, k) in PROGRAM" :key="k" type="button" role="radio" :aria-checked="form.program === k" @click="form.program = k"
              :class="['min-h-[44px] rounded-xl text-sm font-semibold', form.program === k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">{{ n }}</button>
          </div>
        </div>
        <p v-else class="text-sm"><b>Program:</b> {{ PROGRAM[pilih.program] }}</p>

        <div>
          <p class="label-isian">Ceklist juz resmi</p>
          <GridJuz v-model="form.juz" :terkunci="juzTerkunci" :sedang="Number(form.juz_sedang) || null" :baca-saja="!bolehUbah" />
        </div>

        <template v-if="bolehUbah">
          <InputPosisi id="ha-sabaq" v-model="form.sabaq_hal" label="Sabaq (hafalan berjalan)" :keterangan="'Dasar penambahan dan target'" />
          <InputPosisi id="ha-sabqi" v-model="form.sabqi_hal" label="Sabqi" />
          <InputPosisi id="ha-manzil" v-model="form.manzil_hal" label="Manzil" />
          <div><label class="label-isian" for="ha-sedang">Juz yang sedang dihafal</label>
            <select id="ha-sedang" v-model="form.juz_sedang" class="isian"><option value="">Belum ditentukan</option><option v-for="j in 30" :key="j" :value="j">Juz {{ j }}</option></select></div>
          <ul v-if="peringatan.length" class="space-y-1 rounded-xl bg-[#B5501A]/10 p-3 text-sm text-teks"><li v-for="p in peringatan" :key="p">⚠ {{ p }}</li></ul>
          <button class="tombol-utama w-full" :disabled="proses" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses ? 'Menyimpan…' : 'Simpan data hafalan' }}</button>
        </template>
        <dl v-else class="grid grid-cols-3 gap-2 text-center text-sm">
          <div v-for="k in ['sabaq', 'sabqi', 'manzil']" :key="k" class="rounded-xl bg-permukaan2 p-2.5" :title="KET_POSISI[k]">
            <dt class="text-xs font-semibold capitalize text-teks3">{{ k }}</dt><dd class="font-bold tabular-nums">{{ formatPosisi(pilih[k + '_hal']) }}</dd></div>
        </dl>
      </div>
    </LembarBawah>

    <!-- Program massal -->
    <LembarBawah v-model="lembarProgram" judul="Atur program tahfizh">
      <div class="space-y-3 pb-2">
        <div class="grid grid-cols-2 gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" aria-label="Program baru">
          <button v-for="(n, k) in PROGRAM" :key="k" type="button" role="radio" :aria-checked="programBaru === k" @click="programBaru = k"
            :class="['min-h-[44px] rounded-xl text-sm font-semibold', programBaru === k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">Jadikan {{ n }}</button>
        </div>
        <label class="flex min-h-[44px] items-center gap-3 rounded-xl border border-garis px-3 text-sm font-semibold">
          <input type="checkbox" class="h-5 w-5 accent-[#8C6200]" :checked="semuaTercentang" @change="centangSemua" /> Pilih semua yang tampil ({{ tampil.length }})</label>
        <ul class="max-h-[45dvh] divide-y divide-garis overflow-y-auto rounded-xl border border-garis">
          <li v-for="s in tampil" :key="s.student_id">
            <label class="flex min-h-[48px] items-center gap-3 px-3 text-sm">
              <input v-model="centang" type="checkbox" :value="s.student_id" class="h-5 w-5 accent-[#8C6200]" />
              <span class="min-w-0 flex-1"><b class="block truncate">{{ s.nama }}</b><span class="text-xs text-teks3">{{ s.kelas || `Kelas ${s.tingkat}` }} · {{ s.halaqah || '–' }}</span></span>
              <span :class="['lencana', s.program === 'takhassus' ? 'w-pengajuan' : 'w-hakakses']">{{ PROGRAM[s.program] }}</span>
            </label>
          </li>
        </ul>
        <p class="text-xs text-teks3">Saring daftar lebih dulu (mis. per kelas atau halaqah) agar pemilihan lebih cepat. Target hafalan mengikuti program dan tingkat kelas santri.</p>
        <button class="tombol-utama w-full" :disabled="proses || !centang.length" @click="simpanProgram">Simpan untuk {{ centang.length }} santri</button>
      </div>
    </LembarBawah>

    <!-- Cetak -->
    <DokumenCetak kop="pondok" :judul="judulCetak" :subjudul="`Tahun Ajaran ${kel.taSekarang?.nama || ''} · keadaan ${formatPanjang(hariIniISO())}`"
      v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap" mendatar>
      <table class="tabel kecil">
        <colgroup><col style="width:4%"><col style="width:8%"><col style="width:20%"><col style="width:7%"><col style="width:15%"><col style="width:8%">
          <col style="width:10%"><col style="width:6%"><col style="width:16%"><col style="width:6%"></colgroup>
        <thead><tr><th>No.</th><th>NIS</th><th>Nama</th><th>Kelas</th><th>Halaqah</th><th>Program</th><th>Posisi sabaq</th><th>Sedang</th><th>Juz resmi</th><th>Total</th></tr></thead>
        <tbody>
          <tr v-for="(s, i) in tampil" :key="s.student_id">
            <td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ s.nis }}</td><td>{{ s.nama }}</td><td class="tengah">{{ s.kelas || s.tingkat }}</td><td>{{ s.halaqah || '–' }}</td>
            <td class="tengah">{{ PROGRAM[s.program] }}</td><td class="tengah">{{ formatPosisi(s.sabaq_hal, true) }}</td><td class="tengah">{{ s.juz_sedang || '–' }}</td>
            <td>{{ ringkasJuz(s.juz_resmi) || '–' }}</td><td class="tengah">{{ s.total_resmi }}</td>
          </tr>
        </tbody>
      </table>
      <p style="margin-top: 6pt; font-size: 9pt">Jumlah santri {{ tampil.length }} orang, terdata {{ tampil.filter(terdata).length }} orang, tidak terdata {{ tampil.filter((s) => !terdata(s)).length }} orang. Hal = Halaman (1 Juz = 20 Hal).</p>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: kepala.jabatan, nama: kepala.nama, niy: kepala.niy }"
          :kanan="muhaffizhCetak || { jabatan: 'Pencetak', nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
      </template>
    </DokumenCetak>
  </div>
</template>
