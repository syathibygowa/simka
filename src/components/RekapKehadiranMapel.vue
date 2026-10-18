<!-- SIMKA PRO | src/components/RekapKehadiranMapel.vue | v1.1 | 14.4.0: awal semester 2 = 1 Januari (sama dengan rapor) | 17/10/2026 -->
<script setup>
// Rekap kehadiran santri per mata pelajaran dari absensi guru mapel di jurnal mengajar.
//   * Pertemuan = tanggal jurnal terlaksana yang absensinya diisi (beberapa JP di hari sama = 1 pertemuan).
//   * Hadir = pertemuan − (Sakit + Izin + Alfa + Bolos); Terlambat tetap hadir. Persen = Hadir ÷ Pertemuan.
//   * Sel/baris di bawah ambang kehadiran santri (Setelan → Ambang kehadiran) berwarna merah; ikut cetak/Excel bila diaktifkan.
// Dipakai di Wali Kelas → Pelajaran (semua mapel kelas) dan Guru Mapel → Rekap (mapel yang diampu).
import { ref, computed, watch, onMounted } from 'vue'
import { PhPrinter, PhFileXls, PhArrowClockwise } from '@phosphor-icons/vue'
import { useJadwal } from '@/stores/jadwal'
import { useLembaga } from '@/stores/lembaga'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { useAmbang, unduhExcelAmbang } from '@/stores/ambang'
import { hariIniISO, formatPanjang, formatPendek } from '@/lib/tanggal'
import { teksPersen } from '@/lib/absensi'
import InputTanggal from './InputTanggal.vue'
import SaringCorong from './SaringCorong.vue'
import DokumenCetak from './cetak/DokumenCetak.vue'
import TandaTangan from './cetak/TandaTangan.vue'

const props = defineProps({
  groupId: { type: String, default: '' },
  assignmentId: { type: String, default: '' },
  ttdKanan: { type: Object, default: () => ({}) },      // { jabatan, nama, niy } — wali kelas atau guru mapel
})
const jd = useJadwal(); const lembaga = useLembaga(); const sesi = useSesi(); const ui = useUI(); const amb = useAmbang()
const hari = hariIniISO()
const ta = computed(() => lembaga.tahunAktif)
const awalSmt = computed(() => {
  if (!ta.value?.mulai) return hari.slice(0, 7) + '-01'
  const m = ta.value.mulai; const s2 = `${Number(m.slice(0, 4)) + 1}-01-01`   // sama dengan rentang rapor: semester 2 mulai 1 Januari
  return hari >= s2 ? s2 : m
})
const PERIODE = computed(() => [
  { k: 'bulan', n: 'Bulan ini', m: hari.slice(0, 7) + '-01', s: hari },
  { k: 'semester', n: 'Semester ini', m: awalSmt.value, s: hari },
  { k: 'atur', n: 'Atur tanggal' },
])
const periode = ref('semester'); const mulai = ref(hari.slice(0, 7) + '-01'); const selesai = ref(hari)
const d = ref(null); const memuat = ref(false); const pratinjau = ref(false)
function terapkanPeriode() { const p = PERIODE.value.find((x) => x.k === periode.value); if (p?.m) { mulai.value = p.m; selesai.value = p.s } }
async function muat() {
  if (!props.groupId && !props.assignmentId) return
  memuat.value = true
  try { d.value = await jd.rekapKehadiranMapel({ group_id: props.groupId || null, assignment_id: props.assignmentId || null, mulai: mulai.value, selesai: selesai.value }) }
  catch (e) { ui.toast(e.message, 'galat'); d.value = null } finally { memuat.value = false }
}
onMounted(async () => { await Promise.all([lembaga.muat(), amb.muat()]); terapkanPeriode(); muat() })
watch(periode, () => { terapkanPeriode(); if (periode.value !== 'atur') muat() })
watch(() => [props.groupId, props.assignmentId], muat)

const mapel = computed(() => (d.value?.mapel || []).filter((m) => m.pertemuan > 0 || (d.value?.mapel || []).length <= 12))
/** Rata-rata santri: total hadir ÷ total pertemuan seluruh mapel (pertemuan sebagai bobot). */
const baris = computed(() => (d.value?.santri || []).map((s) => {
  let p = 0; let h = 0
  for (const m of mapel.value) { const x = s.mapel?.[m.assignment_id]; if (x?.p) { p += x.p; h += x.h } }
  return { ...s, total: { p, h, persen: p ? Math.round((1000 * h) / p) / 10 : null } }
}))
const rataKelas = computed(() => { const x = baris.value.filter((s) => s.total.p); return x.length ? Math.round(10 * x.reduce((a, s) => a + s.total.persen, 0) / x.length) / 10 : null })
const bawahAmbang = computed(() => baris.value.filter((s) => amb.bawah(s.total.persen)).length)
const sel = (s, m) => s.mapel?.[m.assignment_id]
const judulRentang = computed(() => `${formatPanjang(mulai.value)} s.d. ${formatPanjang(selesai.value)}`)
const namaKelas = computed(() => d.value?.kelas?.nama || '')
const satuMapel = computed(() => !!props.assignmentId && mapel.value.length === 1)
const judulCetak = computed(() => (satuMapel.value ? `Rekap Kehadiran Santri Mapel ${mapel.value[0].mapel}` : 'Rekap Kehadiran Santri per Mata Pelajaran'))
const direktur = computed(() => lembaga.signatories.find((x) => x.sumber_jabatan === 'DIREKTUR' || /^direktur/i.test(x.jabatan_tertulis)) || {})

async function excel() {
  const XLSX = await import('xlsx')
  const kepala = ['No', 'NIS', 'Nama', ...mapel.value.map((m) => `${m.kode || m.mapel} (%)`), 'Hadir', 'Pertemuan', 'Rata-rata (%)']
  const isi = baris.value.map((s, i) => [i + 1, s.nis, s.nama, ...mapel.value.map((m) => sel(s, m)?.persen ?? ''), s.total.h, s.total.p, s.total.persen ?? ''])
  const ws = XLSX.utils.aoa_to_sheet([[judulCetak.value.toUpperCase()], [`Kelas ${namaKelas.value} · ${judulRentang.value}`], [], kepala, ...isi])
  ws['!cols'] = [{ wch: 5 }, { wch: 12 }, { wch: 30 }, ...mapel.value.map(() => ({ wch: 10 })), { wch: 8 }, { wch: 10 }, { wch: 13 }]
  // Lembar rinci: H/S/I/A/B/T per mapel
  const rinci = [['No', 'NIS', 'Nama', 'Mapel', 'Guru', 'Pertemuan', 'Hadir', 'Terlambat', 'Sakit', 'Izin', 'Alfa', 'Bolos', 'Persen']]
  baris.value.forEach((s, i) => mapel.value.forEach((m) => { const x = sel(s, m); if (x) rinci.push([i + 1, s.nis, s.nama, m.mapel, m.guru || '', x.p, x.h, x.t, x.s, x.i, x.a, x.b, x.persen ?? '']) }))
  const wr = XLSX.utils.aoa_to_sheet(rinci); wr['!cols'] = [5, 12, 28, 24, 24, 10, 7, 9, 7, 7, 7, 7, 8].map((w) => ({ wch: w }))
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Rekap per mapel'); XLSX.utils.book_append_sheet(wb, wr, 'Rinci')
  await unduhExcelAmbang(wb, `Kehadiran-per-mapel-${namaKelas.value.replace(/[^A-Za-z0-9]+/g, '-')}-${mulai.value}-sd-${selesai.value}.xlsx`,
    [...baris.value.map((s, i) => ({ r: 4 + i, persen: s.total.persen, lembar: 'Rekap per mapel' })),
     ...rinci.slice(1).map((r, i) => ({ r: 1 + i, persen: r[12] === '' ? null : r[12], lembar: 'Rinci' }))])
}
</script>
<template>
  <div>
    <SaringCorong class="mb-3" :ringkasan="`${PERIODE.find((x) => x.k === periode)?.n} · ${formatPendek(mulai)} – ${formatPendek(selesai)}`" judul="Periode rekap" :jumlah="0">
      <div class="bilah-tab kecil" role="tablist" aria-label="Periode"><button v-for="x in PERIODE" :key="x.k" type="button" role="tab" :aria-selected="periode === x.k"
        :class="['tab-garis', periode === x.k && 'aktif']" @click="periode = x.k">{{ x.n }}</button></div>
      <div v-if="periode === 'atur'" class="grid w-full grid-cols-2 gap-2 md:w-auto md:min-w-[22rem]"><InputTanggal v-model="mulai" label="Dari" /><InputTanggal v-model="selesai" label="Sampai" /></div>
      <button v-if="periode === 'atur'" class="tombol-utama min-h-[44px] px-4 text-sm" @click="muat"><PhArrowClockwise :size="18" /> Tampilkan</button>
    </SaringCorong>

    <p v-if="memuat && !d" class="kartu p-8 text-center text-sm text-teks3">Menghitung kehadiran per mapel…</p>
    <p v-else-if="!d || !mapel.length" class="kartu p-8 text-center text-sm text-teks3">Belum ada absensi pelajaran pada periode ini. Guru mapel menandai santri yang tidak hadir saat mengisi Jurnal mengajar.</p>
    <template v-else>
      <div class="mb-3 flex flex-wrap items-center gap-2">
        <p class="min-w-[200px] flex-1 text-sm text-teks2">Rata-rata kelas <b>{{ teksPersen(rataKelas) }}</b> · {{ mapel.length }} mapel ·
          <span :class="bawahAmbang ? 'font-bold text-merah' : ''">{{ bawahAmbang }} santri di bawah {{ amb.batas('santri') }}%</span></p>
        <button class="tombol-garis min-h-[40px] px-3 text-sm" @click="excel"><PhFileXls :size="18" weight="duotone" /> Excel</button>
        <button class="tombol-garis min-h-[40px] px-3 text-sm" @click="pratinjau = true"><PhPrinter :size="18" weight="duotone" /> Cetak</button>
      </div>

      <!-- HP: kartu per santri -->
      <ul class="space-y-2 md:hidden">
        <li v-for="s in baris" :key="s.student_id" :class="['kartu p-3', amb.kelas(s.total.persen)]">
          <div class="flex items-center gap-2"><p class="min-w-0 flex-1 truncate font-semibold">{{ s.nama }}</p>
            <span :class="['text-lg font-extrabold tabular-nums', amb.bawah(s.total.persen) && 'persen-ambang']">{{ teksPersen(s.total.persen) }}</span></div>
          <div class="mt-1.5 flex flex-wrap gap-1">
            <span v-for="m in mapel" :key="m.assignment_id" :class="['rounded-md px-1.5 py-0.5 text-[11px] tabular-nums', amb.bawah(sel(s, m)?.persen) ? 'bg-[#C7332F]/15 font-bold text-merah' : 'bg-permukaan2 text-teks2']"
              :title="m.mapel">{{ m.kode || m.mapel.slice(0, 6) }} {{ sel(s, m)?.persen ?? '–' }}</span>
          </div>
        </li>
      </ul>
      <!-- Desktop: matriks -->
      <div class="kartu hidden overflow-auto md:block">
        <table class="w-full text-sm">
          <thead class="sticky top-0 bg-permukaan2 text-xs text-teks2"><tr>
            <th class="sticky left-0 bg-permukaan2 px-2 py-2 text-left">Nama</th>
            <th v-for="m in mapel" :key="m.assignment_id" class="px-1.5 text-center" :title="`${m.mapel} · ${m.guru || ''} · ${m.pertemuan} pertemuan`">{{ m.kode || m.mapel }}<span class="block font-normal text-teks3">{{ m.pertemuan }}×</span></th>
            <th class="px-2 text-center">Rata-rata</th></tr></thead>
          <tbody class="divide-y divide-garis">
            <tr v-for="s in baris" :key="s.student_id" :class="amb.kelas(s.total.persen)">
              <td class="sticky left-0 max-w-[220px] truncate bg-permukaan px-2 py-1.5 font-semibold">{{ s.nama }}</td>
              <td v-for="m in mapel" :key="m.assignment_id" :class="['px-1.5 text-center tabular-nums', amb.bawah(sel(s, m)?.persen) && 'persen-ambang']"
                :title="sel(s, m) ? `Hadir ${sel(s, m).h}/${sel(s, m).p} · S ${sel(s, m).s} · I ${sel(s, m).i} · A ${sel(s, m).a} · B ${sel(s, m).b} · T ${sel(s, m).t}` : ''">{{ sel(s, m)?.persen ?? '–' }}</td>
              <td :class="['px-2 text-center font-bold tabular-nums', amb.bawah(s.total.persen) && 'persen-ambang']">{{ teksPersen(s.total.persen) }}</td>
            </tr>
          </tbody>
        </table>
      </div>
      <p class="mt-2 text-xs text-teks3">Persentase = hadir ÷ pertemuan. Sakit, izin, alfa, dan bolos mengurangi kehadiran; terlambat tetap dihitung hadir. Arahkan kursor/ketuk angka untuk rincian.</p>

      <DokumenCetak v-model:pratinjau="pratinjau" mendatar :judul="judulCetak" :subjudul="`Kelas ${namaKelas} · ${judulRentang}`" :pencetak="sesi.pengguna?.nama_lengkap">
        <table class="tabel kecil">
          <thead><tr><th style="width: 4%">No.</th><th style="width: 9%">NIS</th><th>Nama</th><th v-for="m in mapel" :key="m.assignment_id">{{ m.kode || m.mapel }}</th><th style="width: 7%">Rata-rata</th></tr></thead>
          <tbody>
            <tr v-for="(s, i) in baris" :key="s.student_id" :class="amb.kelasCetak(s.total.persen)">
              <td class="tengah">{{ i + 1 }}</td><td>{{ s.nis }}</td><td>{{ s.nama }}</td>
              <td v-for="m in mapel" :key="m.assignment_id" class="tengah">{{ sel(s, m)?.persen ?? '–' }}</td><td class="tengah">{{ teksPersen(s.total.persen) }}</td>
            </tr>
          </tbody>
        </table>
        <p style="margin-top: 4pt; font-size: 8pt">Keterangan mapel: <template v-for="(m, i) in mapel" :key="m.assignment_id">{{ i ? '; ' : '' }}{{ m.kode || m.mapel }} = {{ m.mapel }} ({{ m.pertemuan }} pertemuan)</template>.
          Persentase = hadir ÷ pertemuan; sakit, izin, alfa, dan bolos mengurangi kehadiran.</p>
        <template #ttd><TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan_tertulis || 'Direktur', nama: direktur.nama || '', niy: direktur.niy }"
          :kanan="{ jabatan: ttdKanan.jabatan || 'Wali Kelas', nama: ttdKanan.nama || '', niy: ttdKanan.niy }" /></template>
      </DokumenCetak>
    </template>
  </div>
</template>
