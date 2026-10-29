<!-- SIMKA PRO | src/components/KehadiranPerJP.vue | v1.0 | 14.34.0: kehadiran santri per jam pelajaran (HISBAT) satu kelas per hari | 30/10/2026 -->
<script setup>
// Kehadiran harian kelas per jam pelajaran: No · NIS · Nama · JP 1 · JP 2 · … · ringkasan, dari absensi yang diisi guru mapel
// di Jurnal mengajar (santri yang tidak ditandai dianggap hadir). JP yang belum diisi jurnalnya ditandai "belum diisi";
// JP yang tidak terlaksana ditandai "tidak terlaksana". Dipakai di Wali Kelas → Kehadiran kelas.
import { ref, computed, watch, onMounted } from 'vue'
import { PhCaretLeft, PhCaretRight, PhPrinter, PhFileXls, PhClock, PhCheckCircle, PhHourglassMedium, PhWarningCircle } from '@phosphor-icons/vue'
import { useJadwal } from '@/stores/jadwal'
import { useSesi } from '@/stores/sesi'
import { useLembaga } from '@/stores/lembaga'
import { useUI } from '@/stores/ui'
import { hariIniISO, formatPanjang, formatHari } from '@/lib/tanggal'
import { KODE } from '@/lib/absensi'
import { tambahHari } from '@/lib/shift'
import InputTanggal from './InputTanggal.vue'
import KartuStatistik from './KartuStatistik.vue'
import DokumenCetak from './cetak/DokumenCetak.vue'
import TandaTangan from './cetak/TandaTangan.vue'

const props = defineProps({
  groupId: { type: String, required: true },
  ttdKanan: { type: Object, default: () => ({}) },
})
const jd = useJadwal(); const sesi = useSesi(); const ui = useUI(); const lembaga = useLembaga()
const direktur = computed(() => lembaga.signatories.find((x) => x.sumber_jabatan === 'DIREKTUR' || /^direktur/i.test(x.jabatan_tertulis)) || {})
const tanggal = ref(hariIniISO()); const d = ref(null); const memuat = ref(false); const pratinjau = ref(false)
async function muat() {
  if (!props.groupId || !tanggal.value) return
  memuat.value = true
  try { d.value = await jd.kehadiranKelasHarian(props.groupId, tanggal.value) } catch (e) { ui.toast(e.message, 'galat'); d.value = null } finally { memuat.value = false }
}
onMounted(() => { lembaga.muat().catch(() => {}); muat() })
watch(() => [props.groupId, tanggal.value], muat)
const geser = (n) => { tanggal.value = tambahHari(tanggal.value, n) }

const jp = computed(() => d.value?.jp || [])
const jpIsi = computed(() => jp.value.filter((j) => j.keadaan === 'terisi'))
const KEADAAN = { belum: { n: 'Belum diisi', t: '·' }, tidak: { n: 'Tidak terlaksana', t: '×' }, tanpa_absen: { n: 'Absensi tidak diisi', t: '–' } }
const kodeSel = (s, j) => (j.keadaan === 'terisi' ? s.kode?.[j.period_id] || 'H' : null)
const URUT = ['S', 'I', 'A', 'B', 'T']
const ringkasSantri = (s) => {
  const n = {}; for (const j of jpIsi.value) { const k = kodeSel(s, j); n[k] = (n[k] || 0) + 1 }
  return n
}
const baris = computed(() => (d.value?.santri || []).map((s) => {
  const n = ringkasSantri(s); const hadir = (n.H || 0) + (n.T || 0)
  return { ...s, n, hadir, teks: URUT.filter((k) => n[k]).map((k) => `${k}${n[k] > 1 ? n[k] : ''}`).join(' ') }
}))
const statistik = computed(() => {
  const sel = baris.value.length * jpIsi.value.length; const hadir = baris.value.reduce((a, s) => a + s.hadir, 0)
  const tidak = baris.value.filter((s) => s.hadir < jpIsi.value.length).length
  return [
    { judul: 'Jam pelajaran', nilai: jp.value.length, ikon: PhClock, warna: 'jadwal', keterangan: formatHari(tanggal.value) },
    { judul: 'Absensi terisi', nilai: jpIsi.value.length, ikon: PhCheckCircle, warna: 'presensi', keterangan: `${jp.value.length - jpIsi.value.length} JP belum/tidak terlaksana` },
    { judul: 'Kehadiran', nilai: sel ? Math.round((1000 * hadir) / sel) / 10 : '–', satuan: sel ? '%' : '', ikon: PhHourglassMedium, warna: 'walikelas', keterangan: `${hadir} dari ${sel} jam santri` },
    { judul: 'Santri tidak hadir', nilai: tidak, ikon: PhWarningCircle, warna: 'klinik', keterangan: 'Minimal satu JP' },
  ]
})
const namaKelas = computed(() => d.value?.kelas?.nama || '')
const judulCetak = 'Kehadiran Santri per Jam Pelajaran'
const subjudul = computed(() => `Kelas ${namaKelas.value} · ${formatHari(tanggal.value)}, ${formatPanjang(tanggal.value)}`)

async function excel() {
  const XLSX = await import('xlsx')
  const kepala = ['No', 'NIS', 'Nama', ...jp.value.map((j) => `JP ${j.urutan}${j.kode_mapel ? ' ' + j.kode_mapel : ''}`), 'Hadir', 'Keterangan']
  const isi = baris.value.map((s, i) => [i + 1, s.nis, s.nama, ...jp.value.map((j) => kodeSel(s, j) || KEADAAN[j.keadaan]?.n || ''), `${s.hadir}/${jpIsi.value.length}`, s.teks])
  const ws = XLSX.utils.aoa_to_sheet([[judulCetak.toUpperCase()], [subjudul.value], [], kepala, ...isi, [],
    ...jp.value.map((j) => [`JP ${j.urutan}`, j.jam, j.mapel || '', j.guru || '', KEADAAN[j.keadaan]?.n || 'Terisi'])])
  ws['!cols'] = [{ wch: 5 }, { wch: 12 }, { wch: 30 }, ...jp.value.map(() => ({ wch: 9 })), { wch: 8 }, { wch: 14 }]
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Per JP')
  XLSX.writeFile(wb, `Kehadiran-per-JP-${namaKelas.value.replace(/[^A-Za-z0-9]+/g, '-')}-${tanggal.value}.xlsx`)
}
</script>
<template>
  <div>
    <div class="mb-3 flex flex-wrap items-center gap-2">
      <button class="tombol-ikon h-11 w-11" aria-label="Hari sebelumnya" @click="geser(-1)"><PhCaretLeft :size="20" weight="bold" /></button>
      <div class="w-44"><InputTanggal class="tanpa-label" v-model="tanggal" label="Tanggal" /></div>
      <button class="tombol-ikon h-11 w-11" aria-label="Hari berikutnya" @click="geser(1)"><PhCaretRight :size="20" weight="bold" /></button>
      <button v-if="tanggal !== hariIniISO()" class="tombol-garis min-h-[44px] px-3 text-sm" @click="tanggal = hariIniISO()">Hari ini</button>
      <span class="flex-1" />
      <button class="tombol-garis min-h-[44px] px-3 text-sm" :disabled="!baris.length" @click="excel"><PhFileXls :size="18" weight="duotone" /> Ekspor</button>
      <button class="tombol-garis min-h-[44px] px-3 text-sm" :disabled="!baris.length" @click="pratinjau = true"><PhPrinter :size="18" weight="duotone" /> Cetak</button>
    </div>

    <div v-if="d" class="mb-3 grid grid-cols-2 gap-3 lg:grid-cols-4"><KartuStatistik v-for="k in statistik" :key="k.judul" v-bind="k" /></div>

    <p v-if="memuat && !d" class="kartu p-8 text-center text-sm text-teks3">Memuat kehadiran per jam pelajaran…</p>
    <p v-else-if="d && !jp.length" class="kartu p-8 text-center text-sm text-teks3">Tidak ada jam pelajaran terjadwal pada {{ formatHari(tanggal) }}, {{ formatPanjang(tanggal) }}.</p>
    <template v-else-if="d">
      <!-- HP: kartu per santri -->
      <ul class="space-y-2 md:hidden">
        <li v-for="(s, i) in baris" :key="s.student_id" :class="['kartu p-3', s.hadir < jpIsi.length && 'baris-ambang']">
          <div class="flex items-center gap-2"><span class="w-6 text-xs text-teks3">{{ i + 1 }}</span>
            <p class="min-w-0 flex-1 truncate font-semibold">{{ s.nama }}<span class="ml-1 text-xs font-normal text-teks3">{{ s.nis }}</span></p>
            <span class="text-sm font-bold tabular-nums">{{ s.hadir }}/{{ jpIsi.length }}</span></div>
          <div class="mt-2 flex flex-wrap gap-1">
            <span v-for="j in jp" :key="j.period_id" :title="`JP ${j.urutan} · ${j.mapel || ''}`"
              :class="['grid h-9 min-w-[2.6rem] place-items-center rounded-lg px-1 text-[11px] leading-tight', kodeSel(s, j) ? 'chip-ikon w-' + KODE[kodeSel(s, j)].w : 'bg-permukaan2 text-teks3']">
              <span class="text-[10px] opacity-80">JP{{ j.urutan }}</span><b>{{ kodeSel(s, j) || KEADAAN[j.keadaan]?.t }}</b></span>
          </div>
        </li>
      </ul>
      <!-- Desktop: matriks -->
      <div class="kartu hidden overflow-auto md:block">
        <table class="w-full text-sm">
          <thead class="bg-permukaan2 text-xs text-teks2"><tr>
            <th class="w-10 px-2 py-2 text-center">No</th><th class="px-2 text-left">NIS</th><th class="px-2 text-left">Nama</th>
            <th v-for="j in jp" :key="j.period_id" class="px-1 py-1.5 text-center" :title="`${j.jam} · ${j.mapel || '-'} · ${j.guru || '-'}${j.materi ? ' · ' + j.materi : ''}`">
              JP {{ j.urutan }}<span class="block font-normal text-teks3">{{ j.kode_mapel || j.mapel || '–' }}</span>
              <span v-if="j.keadaan !== 'terisi'" class="block text-[10px] font-semibold text-merah">{{ KEADAAN[j.keadaan].n }}</span></th>
            <th class="px-2 text-center">Hadir</th><th class="px-2 text-left">Keterangan</th></tr></thead>
          <tbody class="divide-y divide-garis">
            <tr v-for="(s, i) in baris" :key="s.student_id" :class="s.hadir < jpIsi.length && 'baris-ambang'">
              <td class="px-2 py-1.5 text-center text-teks3">{{ i + 1 }}</td><td class="px-2 tabular-nums">{{ s.nis }}</td>
              <td class="max-w-[240px] truncate px-2 font-semibold">{{ s.nama }}</td>
              <td v-for="j in jp" :key="j.period_id" class="px-1 text-center">
                <span v-if="kodeSel(s, j)" :class="['inline-grid h-7 w-7 place-items-center rounded-md text-xs font-bold', kodeSel(s, j) === 'H' ? 'text-teks3' : 'chip-ikon w-' + KODE[kodeSel(s, j)].w]"
                  :title="KODE[kodeSel(s, j)].n">{{ kodeSel(s, j) }}</span>
                <span v-else class="text-teks3" :title="KEADAAN[j.keadaan]?.n">{{ KEADAAN[j.keadaan]?.t }}</span></td>
              <td class="px-2 text-center font-bold tabular-nums">{{ s.hadir }}/{{ jpIsi.length }}</td>
              <td class="px-2 text-xs font-semibold">{{ s.teks }}</td>
            </tr>
          </tbody>
        </table>
      </div>
      <p class="mt-2 text-xs text-teks3">Diambil dari absensi guru mapel di Jurnal mengajar. H = hadir, I = izin, S = sakit, B = bolos, A = absen, T = terlambat (tetap hadir);
        · = jurnal belum diisi, × = pelajaran tidak terlaksana, – = absensi tidak diisi.</p>

      <DokumenCetak jenis="wk_kehadiran_jp" :konteks="{ groupIds: [groupId] }" v-model:pratinjau="pratinjau" :mendatar="jp.length > 8" :judul="judulCetak" :subjudul="subjudul" :pencetak="sesi.pengguna?.nama_lengkap">
        <table class="tabel kecil">
          <thead><tr><th style="width: 5%">No.</th><th style="width: 11%">NIS</th><th>Nama</th>
            <th v-for="j in jp" :key="j.period_id" style="width: 6%">JP {{ j.urutan }}</th><th style="width: 8%">Hadir</th><th style="width: 12%">Keterangan</th></tr></thead>
          <tbody>
            <tr v-for="(s, i) in baris" :key="s.student_id">
              <td class="tengah">{{ i + 1 }}</td><td>{{ s.nis }}</td><td>{{ s.nama }}</td>
              <td v-for="j in jp" :key="j.period_id" class="tengah">{{ kodeSel(s, j) || KEADAAN[j.keadaan]?.t }}</td>
              <td class="tengah">{{ s.hadir }}/{{ jpIsi.length }}</td><td>{{ s.teks }}</td>
            </tr>
          </tbody>
        </table>
        <table class="tabel kecil" style="margin-top: 6pt">
          <thead><tr><th style="width: 8%">JP</th><th style="width: 14%">Pukul</th><th>Mata pelajaran</th><th>Guru</th><th style="width: 18%">Keadaan</th></tr></thead>
          <tbody><tr v-for="j in jp" :key="j.period_id"><td class="tengah">{{ j.urutan }}</td><td class="tengah">{{ j.jam }}</td><td>{{ j.mapel || '–' }}</td><td>{{ j.guru || '–' }}</td>
            <td>{{ KEADAAN[j.keadaan]?.n || 'Absensi terisi' }}</td></tr></tbody>
        </table>
        <p style="margin-top: 4pt; font-size: 8pt">Keterangan: H = hadir, I = izin, S = sakit, B = bolos, A = absen, T = terlambat; · = jurnal belum diisi, × = tidak terlaksana, – = absensi tidak diisi.</p>
        <template #ttd><TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan_tertulis || 'Direktur', nama: direktur.nama || '', niy: direktur.niy }"
          :kanan="{ jabatan: ttdKanan.jabatan || 'Wali Kelas', nama: ttdKanan.nama || '', niy: ttdKanan.niy }" /></template>
      </DokumenCetak>
    </template>
  </div>
</template>
