<!-- SIMKA PRO | src/components/KehadiranPerPertemuan.vue | v1.0 | 14.34.0: kehadiran santri per pertemuan (P1, P2, …) satu mapel | 30/10/2026 -->
<script setup>
// Kehadiran santri per pertemuan satu mata pelajaran: No · NIS · Nama · P1 · P2 · … · Hadir · Pertemuan · %.
// Pertemuan = tanggal jurnal mengajar terlaksana yang absensinya diisi (beberapa JP di hari yang sama = 1 pertemuan, kode terberat).
// Baris di bawah ambang kehadiran santri berwarna merah. Dipakai di Wali Kelas → Kehadiran kelas dan Guru Mapel → Kehadiran santri.
import { ref, computed, watch, onMounted } from 'vue'
import { PhPrinter, PhFileXls, PhArrowClockwise, PhCalendarCheck, PhPercent, PhWarningCircle, PhUsersThree } from '@phosphor-icons/vue'
import { useJadwal } from '@/stores/jadwal'
import { useLembaga } from '@/stores/lembaga'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { useAmbang, unduhExcelAmbang } from '@/stores/ambang'
import { hariIniISO, formatPanjang, formatPendek } from '@/lib/tanggal'
import { KODE, teksPersen } from '@/lib/absensi'
import InputTanggal from './InputTanggal.vue'
import SaringCorong from './SaringCorong.vue'
import KartuStatistik from './KartuStatistik.vue'
import DokumenCetak from './cetak/DokumenCetak.vue'
import TandaTangan from './cetak/TandaTangan.vue'

const props = defineProps({
  assignmentId: { type: String, required: true },
  ttdKanan: { type: Object, default: () => ({}) },   // { jabatan, nama, niy }
})
const jd = useJadwal(); const lembaga = useLembaga(); const sesi = useSesi(); const ui = useUI(); const amb = useAmbang()
const hari = hariIniISO()
const awalSmt = computed(() => {
  const m = lembaga.tahunAktif?.mulai; if (!m) return hari.slice(0, 7) + '-01'
  const s2 = `${Number(m.slice(0, 4)) + 1}-01-01`
  return hari >= s2 ? s2 : m
})
const PERIODE = computed(() => [
  { k: 'bulan', n: 'Bulan ini', m: hari.slice(0, 7) + '-01', s: hari },
  { k: 'semester', n: 'Semester ini', m: awalSmt.value, s: hari },
  { k: 'atur', n: 'Atur tanggal' },
])
const periode = ref('semester'); const mulai = ref(hari.slice(0, 7) + '-01'); const selesai = ref(hari)
const d = ref(null); const memuat = ref(false); const pratinjau = ref(false)
function terapkan() { const p = PERIODE.value.find((x) => x.k === periode.value); if (p?.m) { mulai.value = p.m; selesai.value = p.s } }
async function muat() {
  if (!props.assignmentId) return
  memuat.value = true
  try { d.value = await jd.kehadiranPertemuanMapel(props.assignmentId, mulai.value, selesai.value) } catch (e) { ui.toast(e.message, 'galat'); d.value = null } finally { memuat.value = false }
}
onMounted(async () => { await Promise.all([lembaga.muat().catch(() => {}), amb.muat().catch(() => {})]); terapkan(); muat() })
watch(periode, () => { terapkan(); if (periode.value !== 'atur') muat() })
watch(() => props.assignmentId, muat)

const pert = computed(() => d.value?.pertemuan || [])
const baris = computed(() => d.value?.santri || [])
const namaKelas = computed(() => d.value?.kelas?.nama || '')
const namaMapel = computed(() => d.value?.mapel?.nama || 'Mapel')
const rata = computed(() => { const x = baris.value.filter((s) => s.total); return x.length ? Math.round(10 * x.reduce((a, s) => a + Number(s.persen || 0), 0) / x.length) / 10 : null })
const bawah = computed(() => baris.value.filter((s) => amb.bawah(s.persen)).length)
const statistik = computed(() => [
  { judul: 'Pertemuan tercatat', nilai: pert.value.length, ikon: PhCalendarCheck, warna: 'jadwal', keterangan: `${formatPendek(mulai.value)} – ${formatPendek(selesai.value)}` },
  { judul: 'Rata-rata kehadiran', nilai: rata.value ?? '–', satuan: rata.value == null ? '' : '%', ikon: PhPercent, warna: 'presensi', keterangan: `${baris.value.length} santri` },
  { judul: 'Di bawah ambang', nilai: bawah.value, ikon: PhWarningCircle, warna: 'klinik', keterangan: `Kurang dari ${amb.batas('santri')}%` },
  { judul: 'Hadir penuh', nilai: baris.value.filter((s) => s.total && s.hadir === s.total).length, ikon: PhUsersThree, warna: 'walikelas', keterangan: 'Seluruh pertemuan' },
])
const judulCetak = computed(() => `Kehadiran Santri per Pertemuan Mapel ${namaMapel.value}`)
const subjudul = computed(() => `Kelas ${namaKelas.value} · ${formatPanjang(mulai.value)} s.d. ${formatPanjang(selesai.value)}`)
const direktur = computed(() => lembaga.signatories.find((x) => x.sumber_jabatan === 'DIREKTUR' || /^direktur/i.test(x.jabatan_tertulis)) || {})
const kelasKode = (k) => (!k ? 'text-teks3' : k === 'H' ? 'text-teks3' : 'chip-ikon w-' + KODE[k].w)
const tglP = (t) => `${t.slice(8, 10)}/${t.slice(5, 7)}`

async function excel() {
  const XLSX = await import('xlsx')
  const kepala = ['No', 'NIS', 'Nama', ...pert.value.map((p) => `P${p.ke} (${tglP(p.tanggal)})`), 'Hadir', 'Pertemuan', 'Persen (%)']
  const isi = baris.value.map((s, i) => [i + 1, s.nis, s.nama, ...s.kode.map((k) => k || '–'), s.hadir, s.total, s.persen ?? ''])
  const ws = XLSX.utils.aoa_to_sheet([[judulCetak.value.toUpperCase()], [subjudul.value], [], kepala, ...isi, [],
    ['Pertemuan', 'Tanggal', 'JP', 'Materi'], ...pert.value.map((p) => [`P${p.ke}`, formatPendek(p.tanggal), p.jp, p.materi || ''])])
  ws['!cols'] = [{ wch: 5 }, { wch: 12 }, { wch: 30 }, ...pert.value.map(() => ({ wch: 10 })), { wch: 7 }, { wch: 10 }, { wch: 10 }]
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Per pertemuan')
  await unduhExcelAmbang(wb, `Kehadiran-pertemuan-${namaMapel.value.replace(/[^A-Za-z0-9]+/g, '-')}-${namaKelas.value.replace(/[^A-Za-z0-9]+/g, '-')}.xlsx`,
    baris.value.map((s, i) => ({ r: 4 + i, persen: s.persen, lembar: 'Per pertemuan' })))
}
</script>
<template>
  <div>
    <SaringCorong class="mb-3" :ringkasan="`${PERIODE.find((x) => x.k === periode)?.n} · ${formatPendek(mulai)} – ${formatPendek(selesai)}`" judul="Periode" :jumlah="0">
      <div class="bilah-tab kecil" role="tablist" aria-label="Periode"><button v-for="x in PERIODE" :key="x.k" type="button" role="tab" :aria-selected="periode === x.k"
        :class="['tab-garis', periode === x.k && 'aktif']" @click="periode = x.k">{{ x.n }}</button></div>
      <div v-if="periode === 'atur'" class="grid w-full grid-cols-2 gap-2 md:w-auto md:min-w-[22rem]"><InputTanggal class="tanpa-label" v-model="mulai" label="Dari" /><InputTanggal class="tanpa-label" v-model="selesai" label="Sampai" /></div>
      <button v-if="periode === 'atur'" class="tombol-utama min-h-[44px] px-4 text-sm" @click="muat"><PhArrowClockwise :size="18" /> Tampilkan</button>
    </SaringCorong>

    <div v-if="d" class="mb-3 grid grid-cols-2 gap-3 lg:grid-cols-4"><KartuStatistik v-for="k in statistik" :key="k.judul" v-bind="k" /></div>

    <p v-if="memuat && !d" class="kartu p-8 text-center text-sm text-teks3">Memuat kehadiran per pertemuan…</p>
    <p v-else-if="!d || !pert.length" class="kartu p-8 text-center text-sm text-teks3">Belum ada pertemuan dengan absensi pada periode ini. Guru mapel menandai santri yang tidak hadir saat mengisi Jurnal mengajar.</p>
    <template v-else>
      <div class="mb-2 flex flex-wrap items-center gap-2">
        <p class="min-w-[200px] flex-1 text-sm text-teks2"><b>{{ namaMapel }}</b> · Kelas {{ namaKelas }}<template v-if="d.mapel?.guru"> · {{ d.mapel.guru }}</template></p>
        <button class="tombol-garis min-h-[40px] px-3 text-sm" @click="excel"><PhFileXls :size="18" weight="duotone" /> Ekspor</button>
        <button class="tombol-garis min-h-[40px] px-3 text-sm" @click="pratinjau = true"><PhPrinter :size="18" weight="duotone" /> Cetak</button>
      </div>

      <!-- HP -->
      <ul class="space-y-2 md:hidden">
        <li v-for="(s, i) in baris" :key="s.student_id" :class="['kartu p-3', amb.kelas(s.persen)]">
          <div class="flex items-center gap-2"><span class="w-6 text-xs text-teks3">{{ i + 1 }}</span>
            <p class="min-w-0 flex-1 truncate font-semibold">{{ s.nama }}<span class="ml-1 text-xs font-normal text-teks3">{{ s.nis }}</span></p>
            <span :class="['text-lg font-extrabold tabular-nums', amb.bawah(s.persen) && 'persen-ambang']">{{ teksPersen(s.persen) }}</span></div>
          <p class="text-xs text-teks3">Hadir {{ s.hadir }} dari {{ s.total }} pertemuan</p>
          <div class="mt-2 flex flex-wrap gap-1">
            <span v-for="(k, pi) in s.kode" :key="pi" :title="`P${pert[pi].ke} · ${formatPendek(pert[pi].tanggal)}`"
              :class="['grid h-9 min-w-[2.4rem] place-items-center rounded-lg px-1 text-[11px] leading-tight', k && k !== 'H' ? kelasKode(k) : 'bg-permukaan2 text-teks2']">
              <span class="text-[10px] opacity-80">P{{ pert[pi].ke }}</span><b>{{ k || '–' }}</b></span>
          </div>
        </li>
      </ul>
      <!-- Desktop -->
      <div class="kartu hidden overflow-auto md:block">
        <table class="w-full text-sm">
          <thead class="bg-permukaan2 text-xs text-teks2"><tr>
            <th class="sticky left-0 z-[1] w-10 bg-permukaan2 px-2 py-2 text-center">No</th><th class="px-2 text-left">NIS</th>
            <th class="sticky left-10 z-[1] bg-permukaan2 px-2 text-left">Nama</th>
            <th v-for="p in pert" :key="p.ke" class="px-1 py-1.5 text-center" :title="`${formatPanjang(p.tanggal)} · ${p.jp}${p.materi ? ' · ' + p.materi : ''}`">
              P{{ p.ke }}<span class="block font-normal text-teks3">{{ tglP(p.tanggal) }}</span></th>
            <th class="px-2 text-center">Hadir</th><th class="px-2 text-center">Total</th><th class="px-2 text-center">%</th></tr></thead>
          <tbody class="divide-y divide-garis">
            <tr v-for="(s, i) in baris" :key="s.student_id" :class="amb.kelas(s.persen)">
              <td class="sticky left-0 bg-permukaan px-2 py-1.5 text-center text-teks3">{{ i + 1 }}</td><td class="px-2 tabular-nums">{{ s.nis }}</td>
              <td class="sticky left-10 max-w-[220px] truncate bg-permukaan px-2 font-semibold">{{ s.nama }}</td>
              <td v-for="(k, pi) in s.kode" :key="pi" class="px-1 text-center">
                <span :class="['inline-grid h-7 w-7 place-items-center rounded-md text-xs font-bold', kelasKode(k)]" :title="k ? KODE[k].n : 'Belum menjadi anggota kelas'">{{ k || '–' }}</span></td>
              <td class="px-2 text-center tabular-nums">{{ s.hadir }}</td><td class="px-2 text-center tabular-nums">{{ s.total }}</td>
              <td :class="['px-2 text-center font-bold tabular-nums', amb.bawah(s.persen) && 'persen-ambang']">{{ teksPersen(s.persen) }}</td>
            </tr>
          </tbody>
        </table>
      </div>
      <p class="mt-2 text-xs text-teks3">H = hadir, I = izin, S = sakit, B = bolos, A = absen, T = terlambat (tetap hadir). Persentase = hadir ÷ pertemuan.
        Bila dalam satu hari ada beberapa JP dengan isian berbeda, dipakai keadaan terberat. Arahkan kursor ke P untuk melihat tanggal dan materi.</p>

      <DokumenCetak jenis="gm_kehadiran_pertemuan" :konteks="{ groupIds: [d.kelas?.id].filter(Boolean) }" v-model:pratinjau="pratinjau" :mendatar="pert.length > 12"
        :judul="judulCetak" :subjudul="subjudul" :pencetak="sesi.pengguna?.nama_lengkap">
        <table class="tabel kecil">
          <thead><tr><th style="width: 4%">No.</th><th style="width: 9%">NIS</th><th>Nama</th><th v-for="p in pert" :key="p.ke">P{{ p.ke }}</th>
            <th style="width: 6%">Hadir</th><th style="width: 6%">Total</th><th style="width: 7%">%</th></tr></thead>
          <tbody>
            <tr v-for="(s, i) in baris" :key="s.student_id" :class="amb.kelasCetak(s.persen)">
              <td class="tengah">{{ i + 1 }}</td><td>{{ s.nis }}</td><td>{{ s.nama }}</td>
              <td v-for="(k, pi) in s.kode" :key="pi" class="tengah">{{ k || '–' }}</td>
              <td class="tengah">{{ s.hadir }}</td><td class="tengah">{{ s.total }}</td><td class="tengah">{{ teksPersen(s.persen) }}</td>
            </tr>
          </tbody>
        </table>
        <p style="margin-top: 4pt; font-size: 8pt">Pertemuan: <template v-for="(p, i) in pert" :key="p.ke">{{ i ? '; ' : '' }}P{{ p.ke }} = {{ formatPendek(p.tanggal) }} ({{ p.jp }})</template>.
          Keterangan: H = hadir, I = izin, S = sakit, B = bolos, A = absen, T = terlambat (dihitung hadir).</p>
        <template #ttd><TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan_tertulis || 'Direktur', nama: direktur.nama || '', niy: direktur.niy }"
          :kanan="{ jabatan: ttdKanan.jabatan || 'Guru Mata Pelajaran', nama: ttdKanan.nama || '', niy: ttdKanan.niy }" /></template>
      </DokumenCetak>
    </template>
  </div>
</template>
