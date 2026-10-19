<!-- SIMKA PRO | src/components/LaporanJurnalMengajar.vue | v1.1 | 14.13.0: tombol disederhanakan (Pratinjau, Ekspor, Impor, Cetak Rekap) | 19/10/2026 -->
<script setup>
// Laporan jurnal mengajar untuk satu cakupan: satu kelas × mapel, satu mapel di semua kelas yang diampu guru,
// semua yang diampu guru, atau semua mapel satu kelas (wali kelas/kurikulum).
// Setiap pertemuan: hari/tanggal, jam (JP), materi pokok – sub-bab, tujuan, kegiatan, metode/strategi, media, alat, sumber
// belajar, kehadiran santri (beserta yang tidak hadir), dan catatan. Cetak F4 mendatar berkop; tanda tangan pimpinan
// (dapat dipilih) di kiri dan guru/wali kelas di kanan. Excel memuat kolom yang sama.
import { ref, computed, watch, onMounted } from 'vue'
import { PhPrinter, PhFileXls, PhArrowClockwise, PhCheckCircle, PhXCircle, PhUsersThree, PhWhatsappLogo } from '@phosphor-icons/vue'
import LembarLaporanGrup from './LembarLaporanGrup.vue'
import { laporanMengajar, laporanMengajarPeriode } from '@/lib/laporanGrup'
import { useJadwal } from '@/stores/jadwal'
import { useLembaga } from '@/stores/lembaga'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { hariIniISO, formatHari, formatPanjang, formatPendek } from '@/lib/tanggal'
import InputTanggal from './InputTanggal.vue'
import SaringCorong from './SaringCorong.vue'
import DokumenCetak from './cetak/DokumenCetak.vue'
import TandaTangan from './cetak/TandaTangan.vue'

const props = defineProps({
  cakupan: { type: Object, required: true },        // { assignment_id | group_id | employee_id, subject_id? }
  judul: { type: String, default: 'Jurnal Mengajar' },
  kanan: { type: String, default: 'guru' },          // 'guru' | 'wali' — penanda tangan kanan
  periodeAwal: { type: String, default: 'bulan' },   // hari | pekan | bulan | semester
})
const jd = useJadwal(); const lembaga = useLembaga(); const sesi = useSesi(); const ui = useUI()
const hari = hariIniISO()
const awalSmt = computed(() => { const ta = lembaga.tahunAktif; if (!ta?.mulai) return hari.slice(0, 7) + '-01'; const jan = `${Number(ta.mulai.slice(0, 4)) + 1}-01-01`; return hari >= jan ? jan : ta.mulai })
const senin = (() => { const t = new Date(hari + 'T12:00:00Z'); t.setUTCDate(t.getUTCDate() - ((t.getUTCDay() + 6) % 7)); return t.toISOString().slice(0, 10) })()
const PERIODE = computed(() => [{ k: 'hari', n: 'Hari ini', m: hari, s: hari }, { k: 'pekan', n: 'Pekan ini', m: senin, s: hari }, { k: 'bulan', n: 'Bulan ini', m: hari.slice(0, 7) + '-01', s: hari }, { k: 'semester', n: 'Semester ini', m: awalSmt.value, s: hari }, { k: 'atur', n: 'Atur tanggal' }])
const periode = ref(['hari', 'pekan', 'bulan', 'semester'].includes(props.periodeAwal) ? props.periodeAwal : 'bulan'); const mulai = ref(hari.slice(0, 7) + '-01'); const selesai = ref(hari)
const d = ref(null); const memuat = ref(false); const pratinjau = ref(false); const lengkap = ref(true)
const kiriId = ref('')
function terapkan() { const p = PERIODE.value.find((x) => x.k === periode.value); if (p?.m) { mulai.value = p.m; selesai.value = p.s } }
async function muat() {
  if (!Object.values(props.cakupan).some(Boolean)) return
  memuat.value = true
  try { d.value = await jd.laporanJurnal({ ...props.cakupan, mulai: mulai.value, selesai: selesai.value }) } catch (e) { ui.toast(e.message, 'galat'); d.value = null } finally { memuat.value = false }
}
onMounted(async () => { await lembaga.muat(); terapkan(); muat() })
watch(periode, () => { terapkan(); if (periode.value !== 'atur') muat() })
watch(() => JSON.stringify(props.cakupan), muat)

const pertemuan = computed(() => d.value?.pertemuan || [])
const tugas = computed(() => d.value?.penugasan || [])
const kelasSet = computed(() => [...new Set(pertemuan.value.map((x) => x.kelas))])
const mapelSet = computed(() => [...new Set(pertemuan.value.map((x) => x.mapel))])
const guruSet = computed(() => [...new Set(tugas.value.map((x) => x.guru).filter(Boolean))])
const terlaksana = computed(() => pertemuan.value.filter((x) => x.status === 'terlaksana'))
const ringkas = computed(() => ({ n: pertemuan.value.length, ok: terlaksana.value.length, jp: pertemuan.value.reduce((a, x) => a + (x.status === 'terlaksana' ? x.jp : 0), 0),
  hadir: (() => { const x = terlaksana.value.filter((p) => p.jumlah_anggota); const a = x.reduce((n, p) => n + p.jumlah_hadir, 0); const b = x.reduce((n, p) => n + p.jumlah_anggota, 0); return b ? Math.round((1000 * a) / b) / 10 : null })() }))
const materi = (x) => [x.bab, x.subbab].filter(Boolean).join(' – ') || x.materi || ''
const kodeN = { S: 'sakit', I: 'izin', A: 'alfa', B: 'bolos', T: 'terlambat' }
const tidakHadir = (x) => (x.tidak_hadir || []).map((t) => `${t.nama} (${kodeN[t.kode] || t.kode})`).join(', ')
const daftar = (a) => (a || []).join(', ')

// Identitas dokumen
const info = computed(() => ({
  guru: guruSet.value.join(', ') || '–', mapel: mapelSet.value.join(', ') || tugas.value.map((t) => t.mapel).filter((v, i, a) => a.indexOf(v) === i).join(', ') || '–',
  kelas: kelasSet.value.join(', ') || tugas.value.map((t) => t.kelas).filter((v, i, a) => a.indexOf(v) === i).join(', ') || '–',
}))
const satuKelas = computed(() => kelasSet.value.length <= 1); const satuMapel = computed(() => mapelSet.value.length <= 1)
const pilihanKiri = computed(() => lembaga.signatories.filter((s) => s.aktif !== false))
const kiri = computed(() => pilihanKiri.value.find((s) => s.id === kiriId.value) || pilihanKiri.value.find((s) => /kepala sekolah/i.test(s.jabatan_tertulis))
  || pilihanKiri.value.find((s) => s.sumber_jabatan === 'DIREKTUR' || /^direktur/i.test(s.jabatan_tertulis)) || {})
const kananTtd = computed(() => {
  if (props.kanan === 'wali') { const w = tugas.value[0]?.wali || {}; return { jabatan: `Wali Kelas ${info.value.kelas}`, nama: w.nama || '', niy: w.niy } }
  const t = tugas.value[0] || {}; return { jabatan: 'Guru Mata Pelajaran', nama: guruSet.value.length === 1 ? t.guru : '', niy: guruSet.value.length === 1 ? t.niy : '' }
})
const subjudul = computed(() => `${satuKelas.value ? 'Kelas ' + info.value.kelas + ' · ' : ''}${satuMapel.value ? info.value.mapel + ' · ' : ''}${formatPanjang(mulai.value)} s.d. ${formatPanjang(selesai.value)}`)

// 14.4.0: laporan ke grup WhatsApp internal (satu hari = rinci per pertemuan; lebih dari sehari = rekap per kelas–mapel)
const lembarWA = ref(false); const teksWA = ref('')
function laporWA() {
  const guru = guruSet.value.join(', ')
  if (mulai.value === selesai.value) {
    teksWA.value = laporanMengajar({ guru, tanggal: mulai.value, pertemuan: pertemuan.value.map((x) => ({ mapel: x.mapel, kelas: x.kelas, jp: `${x.jam_ke} (${x.jp} JP)`,
      jam: x.jam_mulai && x.jam_selesai ? `${x.jam_mulai}–${x.jam_selesai}` : '', status: x.status, materi: materi(x), tujuan: x.tujuan, metode: x.metode, media: x.media, alat: x.alat, sumber: x.sumber,
      keterangan: x.keterangan, hadir: x.jumlah_hadir, jumlah: x.jumlah_anggota, tidakHadir: x.tidak_hadir || [] })) })
  } else teksWA.value = laporanMengajarPeriode({ guru, mulai: mulai.value, selesai: selesai.value, pertemuan: pertemuan.value })
  lembarWA.value = true
}
async function excel() {
  const XLSX = await import('xlsx')
  const kepala = ['No', 'Hari, tanggal', 'Jam ke', 'JP', 'Kelas', 'Mapel', 'Guru', 'Status', 'Materi pokok – sub-bab', 'Tujuan', 'Kegiatan', 'Metode/strategi', 'Media', 'Alat', 'Sumber belajar', 'Hadir', 'Jumlah santri', 'Tidak hadir', 'Catatan']
  const isi = pertemuan.value.map((x, i) => [i + 1, formatHari(x.tanggal), x.jam_ke, x.jp, x.kelas, x.mapel, x.guru, x.status === 'terlaksana' ? 'Terlaksana' : 'Tidak terlaksana', materi(x),
    x.tujuan || '', x.kegiatan || '', daftar(x.metode), daftar(x.media), daftar(x.alat), daftar(x.sumber), x.jumlah_hadir ?? '', x.jumlah_anggota ?? '', tidakHadir(x), x.keterangan || ''])
  const ws = XLSX.utils.aoa_to_sheet([[props.judul.toUpperCase()], [`Guru: ${info.value.guru} · Mapel: ${info.value.mapel} · Kelas: ${info.value.kelas}`], [`Periode ${formatPanjang(mulai.value)} s.d. ${formatPanjang(selesai.value)}`], [], kepala, ...isi])
  ws['!cols'] = [5, 24, 14, 5, 10, 22, 24, 14, 36, 30, 30, 24, 20, 20, 24, 7, 9, 30, 24].map((w) => ({ wch: w }))
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Jurnal mengajar')
  XLSX.writeFile(wb, `Jurnal-Mengajar-${(satuMapel.value ? info.value.mapel : 'Mapel').replace(/[^A-Za-z0-9]+/g, '-')}-${(satuKelas.value ? info.value.kelas : 'Kelas').replace(/[^A-Za-z0-9]+/g, '-')}-${mulai.value}-sd-${selesai.value}.xlsx`)
}
</script>
<template>
  <div>
    <SaringCorong class="mb-3" :ringkasan="`${PERIODE.find((x) => x.k === periode)?.n} · ${formatPendek(mulai)} – ${formatPendek(selesai)}`" judul="Periode jurnal" :jumlah="0">
      <div class="bilah-tab kecil" role="tablist" aria-label="Periode"><button v-for="x in PERIODE" :key="x.k" type="button" role="tab" :aria-selected="periode === x.k"
        :class="['tab-garis', periode === x.k && 'aktif']" @click="periode = x.k">{{ x.n }}</button></div>
      <div v-if="periode === 'atur'" class="grid w-full grid-cols-2 gap-2 md:w-auto md:min-w-[22rem]"><InputTanggal v-model="mulai" label="Dari" /><InputTanggal v-model="selesai" label="Sampai" /></div>
      <button v-if="periode === 'atur'" class="tombol-utama min-h-[44px] px-4 text-sm" @click="muat"><PhArrowClockwise :size="18" /> Tampilkan</button>
    </SaringCorong>

    <p v-if="memuat && !d" class="kartu p-8 text-center text-sm text-teks3">Memuat jurnal mengajar…</p>
    <p v-else-if="!pertemuan.length" class="kartu p-8 text-center text-sm text-teks3">Belum ada jurnal mengajar pada periode ini.</p>
    <template v-else>
      <div class="mb-3 flex flex-wrap items-center gap-2">
        <p class="min-w-[220px] flex-1 text-sm text-teks2"><b>{{ ringkas.ok }}</b> dari {{ ringkas.n }} pertemuan terlaksana · {{ ringkas.jp }} JP
          <template v-if="ringkas.hadir != null"> · kehadiran santri rata-rata <b>{{ String(ringkas.hadir).replace('.', ',') }}%</b></template></p>
        <label class="flex items-center gap-2 text-sm"><input v-model="lengkap" type="checkbox" class="h-4 w-4" /> Tampilkan rincian</label>
        <button class="tombol-wa-garis min-h-[40px] px-3 text-sm" @click="laporWA"><PhWhatsappLogo :size="18" weight="duotone" /> Lapor ke grup</button>
        <button class="tombol-garis min-h-[40px] px-3 text-sm" @click="excel"><PhFileXls :size="18" weight="duotone" /> Ekspor</button>
        <button class="tombol-garis min-h-[40px] px-3 text-sm" @click="pratinjau = true"><PhPrinter :size="18" weight="duotone" /> Cetak</button>
      </div>
      <label v-if="pilihanKiri.length > 1" class="mb-3 flex flex-wrap items-center gap-2 text-sm"><span class="shrink-0 text-teks2">Tanda tangan "Mengetahui" pada cetakan:</span>
        <select v-model="kiriId" class="isian min-h-[38px] w-auto py-0 text-sm"><option value="">Otomatis ({{ kiri.jabatan_tertulis || 'Direktur' }})</option>
          <option v-for="s in pilihanKiri" :key="s.id" :value="s.id">{{ s.jabatan_tertulis }} – {{ s.nama }}</option></select></label>
      <ul class="space-y-2">
        <li v-for="(x, i) in pertemuan" :key="x.assignment_id + x.tanggal" class="kartu p-3 text-sm">
          <div class="flex flex-wrap items-start gap-2">
            <component :is="x.status === 'terlaksana' ? PhCheckCircle : PhXCircle" :size="20" weight="fill" :class="['mt-0.5 shrink-0', x.status === 'terlaksana' ? 'text-[#1E7D4F]' : 'text-merah']" />
            <div class="min-w-0 flex-1">
              <p class="font-semibold">{{ i + 1 }}. {{ formatHari(x.tanggal) }} <span class="font-normal text-teks3">· {{ x.jam_ke }} ({{ x.jp }} JP)</span></p>
              <p v-if="!satuKelas || !satuMapel" class="text-xs text-teks3">{{ x.mapel }} · Kelas {{ x.kelas }}<template v-if="guruSet.length > 1"> · {{ x.guru }}</template></p>
              <p v-if="x.status === 'terlaksana'" class="mt-0.5">{{ materi(x) }}</p>
              <p v-else class="mt-0.5 text-merah">Tidak terlaksana{{ x.keterangan ? ': ' + x.keterangan : '' }}</p>
              <dl v-if="lengkap && x.status === 'terlaksana'" class="mt-1 space-y-0.5 text-xs text-teks2">
                <div v-if="x.tujuan"><dt class="inline font-semibold">Tujuan: </dt><dd class="inline">{{ x.tujuan }}</dd></div>
                <div v-if="x.kegiatan"><dt class="inline font-semibold">Kegiatan: </dt><dd class="inline">{{ x.kegiatan }}</dd></div>
                <div v-if="x.metode?.length"><dt class="inline font-semibold">Metode: </dt><dd class="inline">{{ daftar(x.metode) }}</dd></div>
                <div v-if="x.media?.length || x.alat?.length"><dt class="inline font-semibold">Media/alat: </dt><dd class="inline">{{ daftar([...(x.media || []), ...(x.alat || [])]) }}</dd></div>
                <div v-if="x.sumber?.length"><dt class="inline font-semibold">Sumber: </dt><dd class="inline">{{ daftar(x.sumber) }}</dd></div>
                <div v-if="x.keterangan"><dt class="inline font-semibold">Catatan: </dt><dd class="inline">{{ x.keterangan }}</dd></div>
              </dl>
            </div>
            <span v-if="x.jumlah_anggota" class="flex shrink-0 items-center gap-1 text-xs font-semibold tabular-nums"><PhUsersThree :size="16" /> {{ x.jumlah_hadir }}/{{ x.jumlah_anggota }}</span>
          </div>
          <p v-if="lengkap && x.tidak_hadir?.length" class="mt-1 pl-7 text-xs text-merah">Tidak hadir: {{ tidakHadir(x) }}</p>
        </li>
      </ul>

      <LembarLaporanGrup v-model="lembarWA" judul="Laporan jurnal mengajar ke grup WhatsApp" :teks="teksWA" />
      <DokumenCetak v-model:pratinjau="pratinjau" mendatar :judul="judul" :subjudul="subjudul" :pencetak="sesi.pengguna?.nama_lengkap">
        <table class="meta-dok" style="margin-bottom: 6pt">
          <tr><td style="width: 32mm">Guru</td><td style="width: 4mm">:</td><td>{{ info.guru }}</td><td style="width: 32mm">Periode</td><td style="width: 4mm">:</td><td>{{ formatPanjang(mulai) }} s.d. {{ formatPanjang(selesai) }}</td></tr>
          <tr><td>Mata pelajaran</td><td>:</td><td>{{ info.mapel }}</td><td>Pertemuan</td><td>:</td><td>{{ ringkas.ok }} terlaksana dari {{ ringkas.n }} ({{ ringkas.jp }} JP)</td></tr>
          <tr><td>Kelas</td><td>:</td><td>{{ info.kelas }}</td><td>Kehadiran santri</td><td>:</td><td>{{ ringkas.hadir != null ? String(ringkas.hadir).replace('.', ',') + '%' : '–' }}</td></tr>
        </table>
        <table class="tabel kecil">
          <thead><tr><th style="width: 3%">No.</th><th style="width: 10%">Hari, tanggal</th><th style="width: 7%">Jam ke (JP)</th>
            <th v-if="!satuKelas" style="width: 6%">Kelas</th><th v-if="!satuMapel" style="width: 10%">Mapel</th>
            <th>Materi pokok – sub-bab</th><th style="width: 16%">Tujuan dan kegiatan</th><th style="width: 10%">Metode/strategi</th><th style="width: 13%">Media, alat, sumber</th>
            <th style="width: 12%">Kehadiran santri</th><th style="width: 9%">Catatan</th></tr></thead>
          <tbody>
            <tr v-for="(x, i) in pertemuan" :key="x.assignment_id + x.tanggal">
              <td class="tengah">{{ i + 1 }}</td><td>{{ formatHari(x.tanggal) }}</td><td class="tengah">{{ x.jam_ke }} ({{ x.jp }})</td>
              <td v-if="!satuKelas" class="tengah">{{ x.kelas }}</td><td v-if="!satuMapel">{{ x.mapel }}</td>
              <td>{{ x.status === 'terlaksana' ? materi(x) : 'Tidak terlaksana' }}</td>
              <td>{{ [x.tujuan, x.kegiatan].filter(Boolean).join('. ') }}</td>
              <td>{{ daftar(x.metode) }}</td>
              <td>{{ [daftar(x.media), daftar(x.alat), daftar(x.sumber)].filter(Boolean).join('; ') }}</td>
              <td>{{ x.jumlah_anggota ? `${x.jumlah_hadir}/${x.jumlah_anggota}` : '' }}{{ x.tidak_hadir?.length ? '. Tidak hadir: ' + tidakHadir(x) : '' }}</td>
              <td>{{ x.keterangan || '' }}</td>
            </tr>
          </tbody>
        </table>
        <template #ttd><TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: kiri.jabatan_tertulis || 'Direktur', nama: kiri.nama || '', niy: kiri.niy }" :kanan="kananTtd" /></template>
      </DokumenCetak>
    </template>
  </div>
</template>
