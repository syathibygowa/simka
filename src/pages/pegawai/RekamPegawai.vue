<!-- SIMKA PRO | src/pages/pegawai/RekamPegawai.vue | v1.0 | 14.8.0: Rekam Kepegawaian individu (tabel, grafik, temuan otomatis, cetak F4, Excel) | 18/10/2026 -->
<script setup>
// Rekam Kepegawaian: laporan menyeluruh satu pegawai pada satu periode, seperti rekam medis.
//   Kepala     : foto, nama, NIY, jabatan struktural/fungsional/Plt, unit, status, masa kerja
//   Ringkasan  : kartu langsung (kehadiran, ketepatan waktu, tanpa keterangan, pengajuan, jurnal harian, mengajar, beban kerja)
//   Temuan     : catatan otomatis (baik, perlu perhatian, informasi) dari angka periode
//   Grafik     : kehadiran per bulan (garis), komposisi status per bulan (tumpuk), jurnal harian dan mengajar per bulan (batang),
//                pola per hari dalam pekan
//   Tabel      : pengajuan, mengajar per kelas-mapel, tugas pengasuhan, absensi santri yang diisi, beban kerja, riwayat, surat teguran
//   Cetak F4   : kop, identitas, temuan, tabel dan grafik; tanda tangan "Mengetahui" pimpinan (kiri) dan pegawai ybs. (kanan). Excel per bagian.
// Hak baca diperiksa server: dirinya, atasan langsung, dan pemegang hak melihat semua pegawai. /profil/rekam = rekam milik sendiri.
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute } from 'vue-router'
import * as XLSX from 'xlsx'
import { PhUserCircle, PhCalendarCheck, PhTimer, PhWarningCircle, PhFileText, PhNotebook, PhChalkboardTeacher, PhClockCountdown, PhPrinter, PhFileXls,
  PhCheckCircle, PhInfo, PhWarning, PhStethoscope, PhWarningOctagon } from '@phosphor-icons/vue'
import { usePegawai } from '@/stores/pegawai'
import { useSesi } from '@/stores/sesi'
import { useLembaga } from '@/stores/lembaga'
import { useAmbang } from '@/stores/ambang'
import { useUI } from '@/stores/ui'
import { muatRekam, temuan, NAMA_HARI_ISO, JENIS_TUGAS, JENIS_ABSEN } from '@/lib/rekamPegawai'
import { STATUS_PEGAWAI, PENDIDIKAN } from '@/lib/kepegawaian'
import { formatPendek, formatPanjang, hariIniISO, BULAN } from '@/lib/tanggal'
import { namaBerkas, periodeRentang } from '@/lib/namaBerkas'
import KartuStatistik from '@/components/KartuStatistik.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import GrafikDeret from '@/components/grafik/GrafikDeret.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const route = useRoute(); const peg = usePegawai(); const sesi = useSesi(); const lembaga = useLembaga(); const ambang = useAmbang(); const ui = useUI()
const id = computed(() => (route.params.id ? String(route.params.id) : sesi.pengguna?.id))
const hari = hariIniISO()
const geser = (iso, bulan) => { const d = new Date(iso + 'T00:00:00Z'); d.setUTCMonth(d.getUTCMonth() + bulan); return d.toISOString().slice(0, 10) }
const thTA = Number(hari.slice(0, 4)) - (Number(hari.slice(5, 7)) < 7 ? 1 : 0)
const PRESET = [
  { k: '3b', n: '3 bulan terakhir', m: geser(hari, -3), s: hari },
  { k: 'sem', n: 'Semester berjalan', m: Number(hari.slice(5, 7)) >= 7 ? `${thTA}-07-01` : `${thTA + 1}-01-01`, s: hari },
  { k: 'ta', n: 'Tahun ajaran', m: `${thTA}-07-01`, s: hari },
  { k: '12b', n: '12 bulan terakhir', m: geser(hari, -12), s: hari },
]
const preset = ref('sem'); const mulai = ref(PRESET[1].m); const selesai = ref(PRESET[1].s)
const pilih = (p) => { preset.value = p.k; mulai.value = p.m; selesai.value = p.s }
const r = ref(null); const memuat = ref(false); const foto = ref('')
async function muat() {
  if (!id.value) return
  if (selesai.value < mulai.value) return ui.toast('Tanggal akhir tidak boleh sebelum tanggal awal.', 'galat')
  memuat.value = true
  try { if (!peg.daftar.length) await peg.muat().catch(() => {}); r.value = await muatRekam(id.value, mulai.value, selesai.value) } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
onMounted(() => { muat(); lembaga.muat().catch(() => {}); ambang.muat().catch(() => {}) })
watch([mulai, selesai, id], muat)
watch(() => r.value?.profil?.id, async (pid) => { if (!pid) return; try { foto.value = (await peg.foto(pid)) || '' } catch { foto.value = '' } })

const P = computed(() => r.value?.profil || {})
const pr = computed(() => r.value?.presensi || {})
const batas = computed(() => ambang.batas('pegawai'))
const fmt = (v, d = '–') => (v == null ? d : String(v).replace('.', ','))
const masa = computed(() => { const b = P.value.masa_kerja_bulan; return b == null ? '–' : `${Math.floor(b / 12)} tahun ${b % 12} bulan` })
const jabatan = computed(() => [...(P.value.struktural || []).map((s) => `${s.jabatan}${s.unit ? ' ' + s.unit.replace(/^Bidang |^Unit /, '') : ''}`), ...(P.value.fungsional || []),
  ...(P.value.plt || []).map((x) => `Plt. ${x.jabatan} (${formatPendek(x.mulai)}–${formatPendek(x.sampai)})`)].join(', ') || '–')
const ajar = computed(() => (r.value?.mengajar || []).reduce((a, m) => ({ y: a.y + m.terlaksana, n: a.n + m.tidak }), { y: 0, n: 0 }))
const hariPengajuan = computed(() => (r.value?.pengajuan || []).filter((x) => x.status === 'disetujui').reduce((a, x) => a + Number(x.hari || 0), 0))
const persenJurnal = computed(() => (pr.value.hari_hadir ? Math.round((100 * (r.value?.jurnal?.hari || 0)) / pr.value.hari_hadir) : null))
const KARTU = computed(() => {
  const x = pr.value; const n = !r.value ? '…' : null
  return [
    { judul: 'Kehadiran', nilai: n ?? (x.persen == null ? '–' : `${fmt(x.persen)}%`), ikon: PhCalendarCheck, warna: x.persen != null && x.persen < batas.value ? 'klinik' : 'presensi', ket: `${x.sesi || 0} sesi wajib · batas ${batas.value}%` },
    { judul: 'Tepat waktu', nilai: n ?? (x.tepat_waktu == null ? '–' : `${fmt(x.tepat_waktu)}%`), ikon: PhTimer, warna: 'shift', ket: `Terlambat ${x.terlambat || 0} kali (${x.menit_terlambat || 0} menit)` },
    { judul: 'Tanpa keterangan', nilai: n ?? (x.tanpa_keterangan || 0), ikon: PhWarningCircle, warna: 'klinik', ket: `Tidak presensi pulang ${x.tidak_presensi_pulang || 0} kali` },
    { judul: 'Izin, sakit, cuti', nilai: n ?? ((x.izin || 0) + (x.sakit || 0) + (x.cuti || 0)), ikon: PhFileText, warna: 'pengajuan', ket: `${hariPengajuan.value} hari pengajuan disetujui` },
    { judul: 'Jurnal harian', nilai: n ?? (persenJurnal.value == null ? '–' : `${persenJurnal.value}%`), ikon: PhNotebook, warna: 'tatausaha', ket: `${r.value?.jurnal?.hari || 0} hari terisi · ${fmt(r.value?.jurnal?.jam, 0)} jam` },
    { judul: 'Mengajar terlaksana', nilai: n ?? (ajar.value.y + ajar.value.n ? `${Math.round((100 * ajar.value.y) / (ajar.value.y + ajar.value.n))}%` : '–'), ikon: PhChalkboardTeacher, warna: 'gurumapel', ket: `${ajar.value.y} pertemuan, ${ajar.value.n} tidak terlaksana` },
    { judul: 'Beban kerja', nilai: n ?? `${fmt(r.value?.beban?.jam, 0)} jam`, ikon: PhClockCountdown, warna: 'gaji', ket: r.value?.beban?.kunci ? `Wajib ${r.value.beban.kunci.jam_wajib} jam/pekan` : 'Per pekan' },
  ]
})
const catatan = computed(() => temuan(r.value, batas.value))
const IKON_TEMUAN = { baik: { ikon: PhCheckCircle, w: 'presensi' }, perhatian: { ikon: PhWarning, w: 'klinik' }, info: { ikon: PhInfo, w: 'shift' } }

// ---------- Grafik ----------
const labelBulan = computed(() => (r.value?.presensi_bulan || []).map((b) => `${BULAN[Number(b.bulan.slice(5)) - 1].slice(0, 3)} ${b.bulan.slice(2, 4)}`))
const gKehadiran = computed(() => [{ n: 'Kehadiran (%)', nilai: (r.value?.presensi_bulan || []).map((b) => b.persen) }, { n: `Batas ${batas.value}%`, nilai: (r.value?.presensi_bulan || []).map(() => batas.value) }])
const gStatus = computed(() => { const b = r.value?.presensi_bulan || []
  return [{ n: 'Hadir tepat waktu', nilai: b.map((x) => x.hadir + x.dinas_luar) }, { n: 'Terlambat', nilai: b.map((x) => x.terlambat) }, { n: 'Izin/sakit/cuti', nilai: b.map((x) => x.izin_sakit_cuti) }, { n: 'Tanpa keterangan', nilai: b.map((x) => x.tanpa_keterangan) }] })
const gKerja = computed(() => [{ n: 'Hari jurnal harian', nilai: (r.value?.jurnal_bulan || []).map((x) => x.hari) }, { n: 'Hari hadir', nilai: (r.value?.jurnal_bulan || []).map((x) => x.hari_hadir) },
  ...(ajar.value.y + ajar.value.n ? [{ n: 'Pertemuan mengajar', nilai: (r.value?.mengajar_bulan || []).map((x) => x.terlaksana) }] : [])])
const pola = computed(() => { const m = Object.fromEntries((r.value?.presensi_hari || []).map((x) => [x.hari, x])); return [1, 2, 3, 4, 5, 6, 7].map((h) => m[h] || { hari: h, sesi: 0, terlambat: 0, tanpa_keterangan: 0 }).filter((x) => x.sesi || x.hari <= 6) })
const maksPola = computed(() => Math.max(1, ...pola.value.map((x) => x.terlambat + x.tanpa_keterangan)))
const STATUS_PENGAJUAN = { menunggu: 'Menunggu', disetujui: 'Disetujui', ditolak: 'Ditolak', dibatalkan: 'Dibatalkan' }
const JENIS_RIWAYAT = { status_kepegawaian: 'Status kepegawaian', unit: 'Unit kerja', jabatan: 'Jabatan', struktural: 'Jabatan struktural', fungsional: 'Jabatan fungsional', keaktifan: 'Keaktifan' }

// ---------- Cetak dan Excel ----------
const pratinjau = ref(false)
const subjudul = computed(() => `${P.value.nama || ''} · periode ${formatPanjang(mulai.value)} s.d. ${formatPanjang(selesai.value)}`)
const pimpinan = computed(() => lembaga.signatories?.find((s) => /^direktur$/i.test(s.jabatan_tertulis)) || {})
function excel() {
  const x = r.value; if (!x) return
  const wb = XLSX.utils.book_new(); const lembar = (n, aoa, w) => { const ws = XLSX.utils.aoa_to_sheet(aoa); ws['!cols'] = w.map((c) => ({ wch: c })); XLSX.utils.book_append_sheet(wb, ws, n) }
  lembar('Identitas', [['Rekam Kepegawaian', subjudul.value], [], ['Nama', P.value.nama], ['NIY', P.value.niy], ['Jabatan', jabatan.value], ['Unit', P.value.unit], ['Status', STATUS_PEGAWAI[P.value.status_kepegawaian] || P.value.status_kepegawaian],
    ['TMT tugas', formatPendek(P.value.tmt_tugas)], ['Masa kerja', masa.value], [], ['Temuan'], ...catatan.value.map((t) => [t.jenis, t.teks])], [22, 80])
  lembar('Kehadiran', [['Bulan', 'Sesi', 'Hadir', 'Terlambat', 'Menit terlambat', 'Dinas luar', 'Izin/sakit/cuti', 'Tanpa keterangan', '% hadir'],
    ...x.presensi_bulan.map((b) => [b.bulan, b.sesi, b.hadir, b.terlambat, b.menit, b.dinas_luar, b.izin_sakit_cuti, b.tanpa_keterangan, b.persen]),
    ['Jumlah', pr.value.sesi, pr.value.hadir, pr.value.terlambat, pr.value.menit_terlambat, pr.value.dinas_luar, (pr.value.izin || 0) + (pr.value.sakit || 0) + (pr.value.cuti || 0), pr.value.tanpa_keterangan, pr.value.persen]], [12, 8, 8, 10, 14, 10, 14, 15, 9])
  lembar('Pengajuan', [['Mulai', 'Selesai', 'Hari', 'Jenis', 'Status', 'Alasan'], ...x.pengajuan.map((p) => [formatPendek(p.mulai), formatPendek(p.selesai), p.hari, p.jenis, STATUS_PENGAJUAN[p.status] || p.status, p.alasan])], [12, 12, 6, 26, 12, 50])
  lembar('Mengajar', [['Kelas', 'Mapel', 'JP/pekan', 'Terlaksana', 'Tidak terlaksana'], ...x.mengajar.map((m) => [m.kelas, m.mapel, m.jp, m.terlaksana, m.tidak])], [12, 28, 10, 12, 16])
  lembar('Jurnal dan tugas', [['Bulan', 'Hari jurnal', 'Hari hadir'], ...x.jurnal_bulan.map((b) => [b.bulan, b.hari, b.hari_hadir]), [], ['Tugas', 'Kelompok', 'Anggota'],
    ...x.tugas.map((t) => [JENIS_TUGAS[t.jenis] || t.jenis, t.kelompok, t.anggota]), [], ['Komponen beban kerja', 'Jam'], ...(x.beban?.rincian || []).map((b) => [b.komponen, b.jam])], [26, 22, 12])
  XLSX.writeFile(wb, `${namaBerkas(P.value.nama, 'Rekam Kepegawaian', periodeRentang(mulai.value, selesai.value))}.xlsx`)
}
</script>
<template>
  <div class="w-pegawai">
    <div class="layar-saja">
      <!-- Kepala -->
      <section class="kartu overflow-hidden">
        <div class="kepala flex flex-wrap items-center gap-4 p-5">
          <img v-if="foto" :src="foto" :alt="'Foto ' + P.nama" class="h-20 w-16 rounded-xl object-cover ring-2 ring-white/60" />
          <span v-else class="grid h-20 w-16 place-items-center rounded-xl bg-white/20"><PhUserCircle :size="40" weight="duotone" /></span>
          <div class="min-w-0 flex-1">
            <p class="flex items-center gap-1.5 text-xs font-semibold uppercase tracking-wider opacity-90"><PhStethoscope :size="16" /> Rekam Kepegawaian</p>
            <h2 class="text-xl font-extrabold leading-tight">{{ P.nama || 'Memuat…' }}</h2>
            <p class="text-sm opacity-90">NIY {{ P.niy || '–' }} · {{ jabatan }}</p>
            <p class="text-sm opacity-90">{{ P.unit || '–' }} · {{ STATUS_PEGAWAI[P.status_kepegawaian] || P.status_kepegawaian || '–' }} · masa kerja {{ masa }}</p>
          </div>
          <div class="flex gap-2">
            <button class="tombol-garis kepala-tombol min-h-[44px] px-3 text-sm" :disabled="!r" @click="excel"><PhFileXls :size="18" weight="duotone" /> Excel</button>
            <button class="tombol-garis kepala-tombol min-h-[44px] px-3 text-sm" :disabled="!r" @click="pratinjau = true"><PhPrinter :size="18" weight="duotone" /> Cetak</button>
          </div>
        </div>
      </section>

      <div class="bilah-tab kecil mt-4" role="tablist" aria-label="Periode rekam">
        <button v-for="p in PRESET" :key="p.k" type="button" role="tab" :aria-selected="preset === p.k" :class="['tab-garis', preset === p.k && 'aktif']" @click="pilih(p)">{{ p.n }}</button>
        <button type="button" role="tab" :aria-selected="preset === 'atur'" :class="['tab-garis', preset === 'atur' && 'aktif']" @click="preset = 'atur'">Atur sendiri</button>
      </div>
      <div v-if="preset === 'atur'" class="kartu mt-3 grid grid-cols-2 gap-3 p-4 sm:max-w-xl"><InputTanggal v-model="mulai" label="Dari tanggal" /><InputTanggal v-model="selesai" label="Sampai tanggal" /></div>

      <p v-if="memuat && !r" class="py-10 text-center text-teks3">Menyusun rekam kepegawaian…</p>
      <template v-else-if="r">
        <div class="-mx-4 mt-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-3 sm:overflow-visible sm:px-0 xl:grid-cols-4">
          <KartuStatistik v-for="k in KARTU" :key="k.judul" class="w-[46%] shrink-0 snap-start sm:w-auto" :judul="k.judul" :nilai="k.nilai" :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket" />
        </div>

        <!-- Temuan -->
        <section class="kartu mt-4 p-5">
          <h3 class="judul-bagian mb-3">Temuan periode ini</h3>
          <ul class="grid gap-2 md:grid-cols-2">
            <li v-for="(t, i) in catatan" :key="i" :class="['flex items-start gap-2 rounded-xl border border-garis p-3 text-sm', 'w-' + IKON_TEMUAN[t.jenis].w]">
              <component :is="IKON_TEMUAN[t.jenis].ikon" :size="20" weight="duotone" class="mt-0.5 shrink-0" style="color: var(--c)" /><span>{{ t.teks }}</span></li>
          </ul>
        </section>

        <!-- Grafik -->
        <div class="mt-4 grid gap-4 xl:grid-cols-2">
          <section class="kartu w-presensi p-4"><h3 class="judul-bagian mb-2">Kehadiran per bulan</h3>
            <GrafikDeret :label="labelBulan" :seri="gKehadiran" jenis="garis" satuan="%" :maks="100" judul="Persentase kehadiran per bulan" /></section>
          <section class="kartu w-shift p-4"><h3 class="judul-bagian mb-2">Komposisi status kehadiran</h3>
            <GrafikDeret :label="labelBulan" :seri="gStatus" jenis="tumpuk" satuan="sesi" judul="Komposisi status kehadiran per bulan" /></section>
          <section class="kartu w-tatausaha p-4"><h3 class="judul-bagian mb-2">Jurnal harian dan mengajar</h3>
            <GrafikDeret :label="labelBulan" :seri="gKerja" jenis="batang" judul="Jurnal harian dan pertemuan mengajar per bulan" /></section>
          <section class="kartu w-klinik p-4"><h3 class="judul-bagian mb-2">Pola per hari</h3>
            <p class="mb-3 text-xs text-teks3">Jumlah terlambat dan tanpa keterangan menurut hari dalam pekan.</p>
            <ul class="space-y-2">
              <li v-for="h in pola" :key="h.hari" class="grid grid-cols-[4.5rem_1fr_4rem] items-center gap-2 text-sm">
                <span class="font-semibold">{{ NAMA_HARI_ISO[h.hari] }}</span>
                <span class="flex h-3 overflow-hidden rounded-full bg-permukaan2"><span class="h-full bg-[#B5501A]" :style="{ width: (h.terlambat / maksPola) * 100 + '%' }" /><span class="h-full bg-[#C7332F]" :style="{ width: (h.tanpa_keterangan / maksPola) * 100 + '%' }" /></span>
                <span class="text-right text-xs tabular-nums text-teks2">{{ h.terlambat }} · {{ h.tanpa_keterangan }}</span></li>
            </ul>
            <p class="mt-2 flex gap-3 text-xs text-teks3"><span class="flex items-center gap-1"><i class="inline-block h-2.5 w-2.5 rounded-full bg-[#B5501A]" />Terlambat</span><span class="flex items-center gap-1"><i class="inline-block h-2.5 w-2.5 rounded-full bg-[#C7332F]" />Tanpa keterangan</span></p>
          </section>
        </div>

        <!-- Tabel -->
        <div class="mt-4 grid gap-4 xl:grid-cols-2">
          <section class="kartu w-pengajuan p-4"><h3 class="judul-bagian mb-2">Pengajuan izin, sakit, cuti, dinas luar</h3>
            <ul class="divide-y divide-garis text-sm"><li v-for="(x, i) in r.pengajuan" :key="i" class="flex items-start justify-between gap-2 py-2">
              <span class="min-w-0"><b>{{ x.jenis }}</b> <span class="text-teks3">· {{ x.hari }} hari</span><span class="block text-xs text-teks3">{{ formatPendek(x.mulai) }}{{ x.selesai !== x.mulai ? ' – ' + formatPendek(x.selesai) : '' }} · {{ x.alasan }}</span></span>
              <span class="lencana shrink-0">{{ STATUS_PENGAJUAN[x.status] || x.status }}</span></li>
              <li v-if="!r.pengajuan.length" class="py-2 text-teks3">Tidak ada pengajuan.</li></ul></section>
          <section class="kartu w-gurumapel p-4"><h3 class="judul-bagian mb-2">Mengajar</h3>
            <table v-if="r.mengajar.length" class="w-full text-sm"><thead class="text-left text-teks3"><tr><th class="py-1.5">Kelas</th><th class="py-1.5">Mapel</th><th class="py-1.5 text-center">JP</th><th class="py-1.5 text-center">Terlaksana</th><th class="py-1.5 text-center">Tidak</th></tr></thead>
              <tbody class="divide-y divide-garis"><tr v-for="(m, i) in r.mengajar" :key="i"><td class="py-1.5">{{ m.kelas }}</td><td class="py-1.5">{{ m.mapel }}</td><td class="py-1.5 text-center">{{ m.jp }}</td>
                <td class="py-1.5 text-center tabular-nums">{{ m.terlaksana }}</td><td :class="['py-1.5 text-center tabular-nums', m.tidak && 'text-merah']">{{ m.tidak }}</td></tr></tbody></table>
            <p v-else class="text-sm text-teks3">Tidak ada penugasan mengajar.</p>
            <p v-if="r.absensi_santri.length" class="mt-3 text-sm text-teks2">Absensi santri diisi: {{ r.absensi_santri.map((a) => `${JENIS_ABSEN[a.jenis] || a.jenis} ${a.sesi} sesi${a.terlambat_isi ? ` (${a.terlambat_isi} terlambat diisi)` : ''}`).join(' · ') }}</p></section>
          <section class="kartu w-walikelas p-4"><h3 class="judul-bagian mb-2">Tugas pengasuhan dan beban kerja</h3>
            <ul class="divide-y divide-garis text-sm"><li v-for="(t, i) in r.tugas" :key="i" class="flex justify-between py-1.5"><span>{{ JENIS_TUGAS[t.jenis] || t.jenis }} <b>{{ t.kelompok }}</b>{{ t.peran !== 'utama' ? ` (${t.peran})` : '' }}</span><span class="text-teks3">{{ t.anggota }} santri</span></li>
              <li v-if="!r.tugas.length" class="py-1.5 text-teks3">Tidak ada tugas pengasuhan.</li></ul>
            <ul class="mt-3 divide-y divide-garis text-sm"><li v-for="(b, i) in r.beban.rincian" :key="i" class="flex justify-between py-1.5"><span>{{ b.komponen }}</span><b class="tabular-nums">{{ fmt(b.jam) }} jam</b></li>
              <li class="flex justify-between py-1.5 font-extrabold"><span>Jumlah beban kerja per pekan</span><span class="tabular-nums">{{ fmt(r.beban.jam, 0) }} jam</span></li></ul></section>
          <section class="kartu w-hakakses p-4"><h3 class="judul-bagian mb-2">Riwayat kepegawaian dan surat teguran</h3>
            <ul class="divide-y divide-garis text-sm"><li v-for="(h, i) in r.riwayat.slice(0, 8)" :key="i" class="py-1.5"><b>{{ JENIS_RIWAYAT[h.jenis] || h.jenis }}</b>: {{ h.lama ? h.lama + ' → ' : '' }}{{ h.baru }}
              <span class="block text-xs text-teks3">{{ h.tanggal ? formatPendek(h.tanggal) : '–' }}{{ h.alasan ? ' · ' + h.alasan : '' }}</span></li>
              <li v-if="!r.riwayat.length" class="py-1.5 text-teks3">Belum ada riwayat perubahan tercatat.</li></ul>
            <ul v-if="r.teguran?.length" class="mt-3 space-y-1.5"><li v-for="(w, i) in r.teguran" :key="i" class="w-klinik flex items-center gap-2 rounded-xl border border-garis p-2 text-sm">
              <PhWarningOctagon :size="18" weight="duotone" style="color: var(--c)" /><span>SP-{{ w.tingkat }} {{ w.nomor || '' }} · {{ formatPendek(w.tanggal) }}{{ w.status === 'dicabut' ? ' · dicabut' : '' }}</span></li></ul></section>
        </div>
      </template>
    </div>

    <!-- Cetak F4 -->
    <DokumenCetak v-if="r" v-model:pratinjau="pratinjau" judul="Rekam Kepegawaian" :subjudul="subjudul" :pencetak="sesi.pengguna?.nama_lengkap"
      :nama-berkas="namaBerkas(P.nama, 'Rekam Kepegawaian', periodeRentang(mulai, selesai))">
      <div class="rekam-cetak">
        <table class="meta-dok"><tbody>
          <tr><td style="width: 20%">Nama</td><td style="width: 32%">: {{ P.nama }}</td><td style="width: 18%">Status</td><td>: {{ STATUS_PEGAWAI[P.status_kepegawaian] || P.status_kepegawaian || '–' }}</td></tr>
          <tr><td>NIY</td><td>: {{ P.niy || '–' }}</td><td>TMT tugas</td><td>: {{ P.tmt_tugas ? formatPendek(P.tmt_tugas) : '–' }} ({{ masa }})</td></tr>
          <tr><td>Jabatan</td><td colspan="3">: {{ jabatan }}</td></tr>
          <tr><td>Unit</td><td>: {{ P.unit || '–' }}</td><td>Pendidikan</td><td>: {{ PENDIDIKAN[P.pendidikan] || P.pendidikan || '–' }}</td></tr>
        </tbody></table>
        <p class="sub">A. Ringkasan dan temuan</p>
        <table class="tabel"><colgroup><col style="width:25%"><col style="width:25%"><col style="width:25%"><col style="width:25%"></colgroup>
          <tbody>
            <tr><td>Kehadiran: <b>{{ fmt(pr.persen) }}%</b> ({{ pr.sesi || 0 }} sesi)</td><td>Tepat waktu: {{ fmt(pr.tepat_waktu) }}%</td><td>Terlambat: {{ pr.terlambat || 0 }} kali ({{ pr.menit_terlambat || 0 }} menit)</td><td>Tanpa keterangan: {{ pr.tanpa_keterangan || 0 }}</td></tr>
            <tr><td>Izin/sakit/cuti: {{ (pr.izin || 0) + (pr.sakit || 0) + (pr.cuti || 0) }} sesi</td><td>Dinas luar: {{ pr.dinas_luar || 0 }} sesi</td><td>Jurnal harian: {{ r.jurnal?.hari || 0 }} hari ({{ persenJurnal ?? '–' }}%)</td><td>Beban kerja: {{ fmt(r.beban?.jam, 0) }} jam/pekan</td></tr>
          </tbody></table>
        <ol class="temuan"><li v-for="(t, i) in catatan" :key="i">{{ t.teks }}</li></ol>
        <p class="sub">B. Kehadiran per bulan</p>
        <table class="tabel"><colgroup><col style="width:16%"><col style="width:10%"><col style="width:10%"><col style="width:12%"><col style="width:12%"><col style="width:14%"><col style="width:14%"><col style="width:12%"></colgroup>
          <thead><tr><th>Bulan</th><th>Sesi</th><th>Hadir</th><th>Terlambat</th><th>Dinas luar</th><th>Izin/sakit/cuti</th><th>Tanpa ket.</th><th>% hadir</th></tr></thead>
          <tbody><tr v-for="(b, i) in r.presensi_bulan" :key="b.bulan" :class="ambang.kelasCetak(b.persen, 'pegawai')"><td>{{ labelBulan[i] }}</td><td class="tengah">{{ b.sesi }}</td><td class="tengah">{{ b.hadir }}</td><td class="tengah">{{ b.terlambat }}</td>
            <td class="tengah">{{ b.dinas_luar }}</td><td class="tengah">{{ b.izin_sakit_cuti }}</td><td class="tengah">{{ b.tanpa_keterangan }}</td><td class="tengah">{{ fmt(b.persen) }}</td></tr></tbody></table>
        <div class="grafik-dua">
          <GrafikDeret :label="labelBulan" :seri="gKehadiran" jenis="garis" satuan="%" :maks="100" judul="Persentase kehadiran per bulan" />
          <GrafikDeret :label="labelBulan" :seri="gStatus" jenis="tumpuk" satuan="sesi" judul="Komposisi status kehadiran per bulan" />
        </div>
        <p class="sub">C. Pengajuan</p>
        <table class="tabel"><colgroup><col style="width:6%"><col style="width:24%"><col style="width:24%"><col style="width:8%"><col style="width:26%"><col style="width:12%"></colgroup>
          <thead><tr><th>No.</th><th>Tanggal</th><th>Jenis</th><th>Hari</th><th>Alasan</th><th>Status</th></tr></thead>
          <tbody><tr v-for="(x, i) in r.pengajuan" :key="i"><td class="tengah">{{ i + 1 }}</td><td>{{ formatPendek(x.mulai) }}{{ x.selesai !== x.mulai ? ' – ' + formatPendek(x.selesai) : '' }}</td><td>{{ x.jenis }}</td><td class="tengah">{{ x.hari }}</td><td>{{ x.alasan }}</td><td>{{ STATUS_PENGAJUAN[x.status] || x.status }}</td></tr>
            <tr v-if="!r.pengajuan.length"><td colspan="6" class="tengah">Tidak ada pengajuan</td></tr></tbody></table>
        <p class="sub">D. Mengajar, tugas, dan beban kerja</p>
        <table class="tabel"><colgroup><col style="width:6%"><col style="width:20%"><col style="width:34%"><col style="width:10%"><col style="width:15%"><col style="width:15%"></colgroup>
          <thead><tr><th>No.</th><th>Kelas</th><th>Mata pelajaran</th><th>JP</th><th>Terlaksana</th><th>Tidak</th></tr></thead>
          <tbody><tr v-for="(m, i) in r.mengajar" :key="i"><td class="tengah">{{ i + 1 }}</td><td>{{ m.kelas }}</td><td>{{ m.mapel }}</td><td class="tengah">{{ m.jp }}</td><td class="tengah">{{ m.terlaksana }}</td><td class="tengah">{{ m.tidak }}</td></tr>
            <tr v-if="!r.mengajar.length"><td colspan="6" class="tengah">Tidak ada penugasan mengajar</td></tr></tbody></table>
        <p class="ket">Tugas pengasuhan: {{ r.tugas.map((t) => `${JENIS_TUGAS[t.jenis] || t.jenis} ${t.kelompok}`).join(', ') || 'tidak ada' }}.
          Beban kerja: {{ r.beban.rincian.map((b) => `${b.komponen} ${fmt(b.jam)} jam`).join(', ') || '–' }} (jumlah {{ fmt(r.beban.jam, 0) }} jam/pekan).
          <template v-if="r.teguran?.length"> Surat teguran: {{ r.teguran.map((w) => `SP-${w.tingkat} ${w.nomor || ''} (${formatPendek(w.tanggal)}${w.status === 'dicabut' ? ', dicabut' : ''})`).join('; ') }}.</template></p>
        <p class="ket">Dokumen ini bersifat terbatas dan disusun otomatis dari data presensi, pengajuan, jurnal, dan penugasan pada SIMKA PRO.</p>
      </div>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: pimpinan.jabatan_tertulis || 'Direktur', nama: pimpinan.nama || '', niy: pimpinan.niy }"
          :kanan="{ jabatan: 'Pegawai yang bersangkutan,', nama: P.nama || '', niy: P.niy }" />
      </template>
    </DokumenCetak>
  </div>
</template>
<style scoped>
.kepala { background: linear-gradient(135deg, #2F5FA8 0%, #3B4CB0 55%, #0B7F81 100%); color: #fff; }
.kepala-tombol { background: rgba(255, 255, 255, 0.14); color: #fff; border-color: rgba(255, 255, 255, 0.45); }
</style>
<style>
.rekam-cetak { font-size: 9.5pt; }
.rekam-cetak .sub { font-weight: 700; margin: 8pt 0 3pt; }
.rekam-cetak table.tabel { font-size: 9pt; }
.rekam-cetak .meta-dok td { padding: 1pt 4pt 1pt 0; vertical-align: top; }
.rekam-cetak .temuan { margin: 4pt 0 0 14pt; padding: 0; list-style: decimal; }
.rekam-cetak .ket { font-size: 9pt; margin-top: 4pt; text-align: justify; }
.rekam-cetak .grafik-dua { display: grid; grid-template-columns: 1fr 1fr; gap: 4mm; margin-top: 6pt; break-inside: avoid; }
</style>
