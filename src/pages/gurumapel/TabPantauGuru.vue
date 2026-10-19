<!-- SIMKA PRO | src/pages/gurumapel/TabPantauGuru.vue | v1.5 | 14.13.0: saringan corong di HP, tombol Ekspor | 19/10/2026 -->
<script setup>
// Pantauan guru mapel (admin, superadmin, pimpinan sesuai cakupannya):
//   Harian  : tanggal dengan tombol sebelum/sesudah; statistik jam pelajaran (terjadwal, terlaksana, belum diisi, tidak
//             terlaksana) dan daftar per guru beserta status setiap jamnya; WA pengingat bagi yang belum mengisi jurnal.
//   Periode : rekap keterlaksanaan per guru (pekan/bulan/bulan lalu), ketuk guru untuk rincian per kelas-mapel;
//             cetak F4 mendatar dan Excel.
import { ref, computed, watch, onMounted } from 'vue'
import * as XLSX from 'xlsx'
import { PhCaretLeft, PhCaretRight, PhCalendarCheck, PhChartBar, PhChalkboardTeacher, PhCheckCircle, PhHourglassMedium, PhXCircle, PhWhatsappLogo, PhPrinter, PhFileXls, PhMagnifyingGlass } from '@phosphor-icons/vue'
import { useJadwal } from '@/stores/jadwal'
import { useLembaga } from '@/stores/lembaga'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { teksPersen } from '@/lib/absensi'
import { awalPekan, awalBulanDari, akhirBulanDari, tambahHari, teksRentang } from '@/lib/musyrif'
import { STATUS_JP, statusSlot, rekapGuru, rekapPenugasan, persenJP, warnaPersen, pesanPengingatJurnal } from '@/lib/guruMapel'
import { hariIniISO, formatHari } from '@/lib/tanggal'
import { tautanWA } from '@/lib/wa'
import KartuStatistik from '@/components/KartuStatistik.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import SaringCorong from '@/components/SaringCorong.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const jd = useJadwal(); const lembaga = useLembaga(); const sesi = useSesi(); const ui = useUI(); const hari = hariIniISO()
const mode = ref('harian'); const jenjang = ref(''); const cari = ref('')
onMounted(() => { lembaga.muat(); muatH() })

// ---------- Harian ----------
const tgl = ref(hari); const slotH = ref([]); const memuatH = ref(false); const saring = ref('')
async function muatH() { memuatH.value = true; try { slotH.value = await jd.slot(tgl.value, tgl.value) } catch (e) { ui.toast(e.message, 'galat') } finally { memuatH.value = false } }
watch(tgl, muatH)
const cocok = (s) => (!jenjang.value || s.jenjang === jenjang.value)
const hSaring = computed(() => slotH.value.filter(cocok))
const statH = computed(() => {
  const s = hSaring.value; const lewat = s.filter((x) => x.lewat)
  return [
    { judul: 'Guru mengajar', nilai: new Set(s.map((x) => x.employee_id)).size, ikon: PhChalkboardTeacher, warna: 'gurumapel', ket: `${s.length} jam pelajaran terjadwal` },
    { judul: 'Terlaksana', nilai: s.filter((x) => x.status === 'terlaksana').length, ikon: PhCheckCircle, warna: 'presensi', ket: `${teksPersen(persenJP(lewat.filter((x) => x.status === 'terlaksana').length, lewat.length))} dari jam yang sudah lewat` },
    { judul: 'Belum diisi', nilai: lewat.filter((x) => x.status === 'belum').length, ikon: PhHourglassMedium, warna: 'tahfizh', ket: 'Jam sudah lewat, jurnal belum diisi' },
    { judul: 'Tidak terlaksana', nilai: s.filter((x) => x.status === 'tidak_terlaksana').length, ikon: PhXCircle, warna: 'klinik', ket: 'Dengan keterangan dari guru' },
  ]
})
const guruH = computed(() => rekapGuru(hSaring.value)
  .map((g) => ({ ...g, belum: g.slot.filter((x) => x.lewat && x.status === 'belum') }))
  .filter((g) => (!cari.value.trim() || String(g.guru).toLowerCase().includes(cari.value.toLowerCase().trim()))
    && (!saring.value || (saring.value === 'belum' ? g.belum.length : g.slot.some((x) => x.status === saring.value))))
  .sort((a, b) => b.belum.length - a.belum.length || String(a.guru).localeCompare(String(b.guru), 'id')))
const SARING = [{ k: '', n: 'Semua' }, { k: 'belum', n: 'Belum diisi' }, { k: 'tidak_terlaksana', n: 'Tidak terlaksana' }, { k: 'terlaksana', n: 'Terlaksana' }]

// ---------- Periode ----------
const PERIODE = [{ k: 'pekan', n: 'Pekan ini', m: awalPekan(hari), s: hari }, { k: 'bulan', n: 'Bulan ini', m: awalBulanDari(hari), s: hari },
  { k: 'lalu', n: 'Bulan lalu', m: awalBulanDari(tambahHari(awalBulanDari(hari), -1)), s: akhirBulanDari(tambahHari(awalBulanDari(hari), -1)) }]
const periode = ref('bulan'); const slotP = ref([]); const memuatP = ref(false); const rinci = ref(null); const pratinjau = ref(false)
const p = computed(() => PERIODE.find((x) => x.k === periode.value))
async function muatP() { memuatP.value = true; try { slotP.value = await jd.slot(p.value.m, p.value.s) } catch (e) { ui.toast(e.message, 'galat') } finally { memuatP.value = false } }
watch(periode, muatP)
watch(mode, (m) => { if (m === 'periode' && !slotP.value.length) muatP() })
const guruP = computed(() => rekapGuru(slotP.value.filter(cocok)).filter((g) => !cari.value.trim() || String(g.guru).toLowerCase().includes(cari.value.toLowerCase().trim())))
const totP = computed(() => guruP.value.reduce((a, g) => ({ terjadwal: a.terjadwal + g.terjadwal, terlaksana: a.terlaksana + g.terlaksana, tidak: a.tidak + g.tidak, kosong: a.kosong + g.kosong }), { terjadwal: 0, terlaksana: 0, tidak: 0, kosong: 0 }))
const direktur = computed(() => lembaga.signatories.find((s) => s.sumber_jabatan === 'DIREKTUR' || /^direktur/i.test(s.jabatan_tertulis)) || {})
function ekspor() {
  const aoa = [['No.', 'NIY', 'Nama guru', 'Kelas', 'Mata pelajaran', 'JP terjadwal', 'JP terlaksana', 'JP tidak terlaksana', 'JP belum diisi', 'Keterlaksanaan (%)'],
    ...guruP.value.map((g, i) => [i + 1, g.niy || '', g.guru, g.kelas.join(', '), g.mapel.join(', '), g.terjadwal, g.terlaksana, g.tidak, g.kosong, g.persen ?? ''])]
  const ws = XLSX.utils.aoa_to_sheet(aoa); ws['!cols'] = aoa[0].map((j) => ({ wch: ['Nama guru', 'Mata pelajaran'].includes(j) ? 30 : j === 'Kelas' ? 18 : 12 }))
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Keterlaksanaan'); XLSX.writeFile(wb, `Keterlaksanaan-Mengajar-${p.value.m}-${p.value.s}.xlsx`)
}
</script>
<template>
  <div>
    <div class="mb-3 flex flex-wrap items-center gap-2">
      <div class="bilah-tab kecil" role="tablist" aria-label="Tampilan pantauan">
        <button v-for="t in [{ k: 'harian', n: 'Harian', ikon: PhCalendarCheck }, { k: 'periode', n: 'Rekap periode', ikon: PhChartBar }]" :key="t.k" type="button" role="tab" :aria-selected="mode === t.k" @click="mode = t.k"
          :class="['tab-garis', mode === t.k && 'aktif']"><component :is="t.ikon" :size="18" weight="duotone" /><span>{{ t.n }}</span></button>
      </div>
      <SaringCorong class="min-w-[220px] flex-1" :jumlah="jenjang ? 1 : 0" :ringkasan="jenjang === 'wustha' ? 'Wustha' : jenjang === 'sma' ? 'SMA' : ''" judul="Saring pantauan guru">
        <template #cari><div class="relative"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-teks3" />
          <input v-model="cari" type="search" class="isian h-11 pl-10" placeholder="Cari nama guru" aria-label="Cari guru" /></div></template>
        <select v-model="jenjang" class="isian h-11 w-auto py-0 text-sm" aria-label="Saring jenjang"><option value="">Semua jenjang</option><option value="wustha">Wustha</option><option value="sma">SMA</option></select>
      </SaringCorong>
    </div>

    <!-- ===== Harian ===== -->
    <template v-if="mode === 'harian'">
      <div class="mb-3 flex flex-wrap items-end gap-1.5">
        <button class="tombol-garis h-12 w-12 shrink-0 px-0" aria-label="Hari sebelumnya" title="Hari sebelumnya" @click="tgl = tambahHari(tgl, -1)"><PhCaretLeft :size="20" weight="bold" /></button>
        <div class="w-40"><InputTanggal v-model="tgl" label="Tanggal" /></div>
        <button class="tombol-garis h-12 w-12 shrink-0 px-0" aria-label="Hari berikutnya" title="Hari berikutnya" @click="tgl = tambahHari(tgl, 1)"><PhCaretRight :size="20" weight="bold" /></button>
        <button v-if="tgl !== hari" class="tombol-teks h-12 px-2 text-sm" @click="tgl = hari">Hari ini</button>
        <p class="ml-1 self-center text-sm font-bold">{{ formatHari(tgl) }}</p>
      </div>
      <div class="-mx-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-4 sm:overflow-visible sm:px-0">
        <KartuStatistik v-for="k in statH" :key="k.judul" class="w-[44%] shrink-0 snap-start sm:w-auto" :judul="k.judul" :nilai="memuatH && !slotH.length ? '…' : k.nilai" :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket" />
      </div>
      <div class="bilah-tab kecil mt-3" role="tablist" aria-label="Saring status">
        <button v-for="s in SARING" :key="s.k" type="button" role="tab" :aria-selected="saring === s.k" @click="saring = s.k"
          :class="['tab-garis', saring === s.k && 'aktif']">{{ s.n }}</button>
      </div>
      <p v-if="memuatH && !slotH.length" class="kartu mt-3 p-8 text-center text-sm text-teks3">Memuat…</p>
      <p v-else-if="!guruH.length" class="kartu mt-3 p-8 text-center text-sm text-teks3">{{ slotH.length ? 'Tidak ada guru yang cocok.' : 'Tidak ada jam pelajaran terjadwal pada tanggal ini (hari Ahad atau libur sekolah).' }}</p>
      <ul class="mt-3 grid gap-2 xl:grid-cols-2">
        <li v-for="g in guruH" :key="g.employee_id" class="kartu p-3.5">
          <div class="flex items-start gap-2">
            <div class="min-w-0 flex-1"><p class="truncate font-bold">{{ g.guru }}</p><p class="truncate text-xs text-teks3">{{ g.kelas.join(', ') }} · {{ g.mapel.join(', ') }}</p></div>
            <a v-if="g.belum.length && g.no_hp" :href="tautanWA(g.no_hp, pesanPengingatJurnal(g.guru, g.belum))" target="_blank" rel="noopener" class="tombol-wa-garis w-presensi min-h-[38px] shrink-0 px-3 text-sm"><PhWhatsappLogo :size="18" weight="duotone" /> Ingatkan</a>
          </div>
          <div class="mt-2 flex flex-wrap gap-1.5">
            <span v-for="s in g.slot" :key="s.period_id + s.assignment_id" :class="['lencana', 'w-' + STATUS_JP[statusSlot(s)].w]" :title="`${s.mapel} ${s.kelas}: ${STATUS_JP[statusSlot(s)].n}${s.materi ? ' – ' + s.materi : s.keterangan ? ' – ' + s.keterangan : ''}`">
              {{ s.jam_mulai }} {{ s.kelas }} · {{ STATUS_JP[statusSlot(s)].n }}</span>
          </div>
        </li>
      </ul>
    </template>

    <!-- ===== Rekap periode ===== -->
    <template v-else>
      <div class="mb-3 flex flex-wrap items-center gap-2">
        <div class="bilah-tab kecil" role="tablist" aria-label="Periode"><button v-for="x in PERIODE" :key="x.k" :class="['tab-garis', periode === x.k && 'aktif']" type="button" role="tab" :aria-selected="periode === x.k" @click="periode = x.k">{{ x.n }}</button></div>
        <span class="text-xs text-teks3">{{ teksRentang(p.m, p.s) }}</span><span class="flex-1" />
        <button class="tombol-garis min-h-[40px] px-3 text-sm" :disabled="!guruP.length" @click="ekspor"><PhFileXls :size="18" weight="duotone" /> Ekspor</button>
        <button class="tombol-garis min-h-[40px] px-3 text-sm" :disabled="!guruP.length" @click="pratinjau = true"><PhPrinter :size="18" weight="duotone" /> Cetak</button>
      </div>
      <p class="mb-2 text-sm text-teks2">{{ guruP.length }} guru · terlaksana <b>{{ totP.terlaksana }}</b> dari {{ totP.terjadwal }} JP ({{ teksPersen(persenJP(totP.terlaksana, totP.terjadwal)) }}) · belum diisi {{ totP.kosong }} · tidak terlaksana {{ totP.tidak }}</p>
      <p v-if="memuatP && !slotP.length" class="kartu p-8 text-center text-sm text-teks3">Memuat rekap…</p>
      <ul v-else class="grid gap-2 md:grid-cols-2 xl:grid-cols-3">
        <li v-for="g in guruP" :key="g.employee_id">
          <button class="kartu w-full p-3.5 text-left hover:shadow-apung" :class="'w-' + warnaPersen(g.persen)" @click="rinci = g">
            <div class="flex items-start gap-2">
              <div class="min-w-0 flex-1"><p class="truncate font-bold">{{ g.guru }}</p><p class="truncate text-xs text-teks3">{{ g.kelas.join(', ') }} · {{ g.mapel.join(', ') }}</p></div>
              <span class="text-xl font-extrabold tabular-nums" style="color: var(--c)">{{ teksPersen(g.persen) }}</span>
            </div>
            <div class="mt-2 h-2 overflow-hidden rounded-full bg-permukaan2"><div class="h-full rounded-full" :style="{ width: (g.persen ?? 0) + '%', background: 'var(--c)' }" /></div>
            <p class="mt-1.5 text-xs text-teks3">Terlaksana {{ g.terlaksana }}/{{ g.terjadwal }} JP<template v-if="g.tidak"> · tidak {{ g.tidak }}</template><template v-if="g.kosong"> · <b class="text-merah">belum diisi {{ g.kosong }}</b></template></p>
          </button>
        </li>
      </ul>
    </template>

    <LembarBawah :model-value="!!rinci" @update:model-value="(v) => !v && (rinci = null)" :judul="rinci ? rinci.guru : ''">
      <div v-if="rinci" class="space-y-2 pb-2">
        <p class="text-sm text-teks2">{{ teksRentang(p.m, p.s) }} · keterlaksanaan {{ teksPersen(rinci.persen) }}</p>
        <ul class="divide-y divide-garis rounded-xl border border-garis">
          <li v-for="r in rekapPenugasan(rinci.slot)" :key="r.assignment_id" class="flex items-center gap-3 px-3 py-2.5 text-sm">
            <span class="min-w-0 flex-1"><b>{{ r.mapel_nama }}</b> <span class="text-teks3">· kelas {{ r.kelas_nama }}</span>
              <span class="block text-xs text-teks3">Terlaksana {{ r.terlaksana }}/{{ r.terjadwal }} · tidak {{ r.tidak }} · belum diisi {{ r.kosong }}</span></span>
            <span class="lencana" :class="'w-' + warnaPersen(r.persen)">{{ teksPersen(r.persen) }}</span>
          </li>
        </ul>
        <p class="judul-bagian pt-2">Jam yang belum diisi atau tidak terlaksana</p>
        <ul class="max-h-64 space-y-1 overflow-y-auto text-sm">
          <li v-for="s in rinci.slot.filter((x) => x.lewat && x.status !== 'terlaksana')" :key="s.tanggal + s.period_id + s.assignment_id" class="flex flex-wrap gap-x-2">
            <span class="w-40 text-teks3">{{ formatHari(s.tanggal) }}</span><span class="flex-1">{{ s.jam_mulai }} · {{ s.mapel }} {{ s.kelas }}<template v-if="s.keterangan"> – {{ s.keterangan }}</template></span>
            <span class="lencana" :class="'w-' + STATUS_JP[s.status].w">{{ STATUS_JP[s.status].n }}</span></li>
          <li v-if="!rinci.slot.some((x) => x.lewat && x.status !== 'terlaksana')" class="text-teks3">Alhamdulillah, semua jam pelajaran terlaksana dan tercatat.</li>
        </ul>
      </div>
    </LembarBawah>

    <DokumenCetak v-model:pratinjau="pratinjau" mendatar judul="Rekap Keterlaksanaan Mengajar Guru Mapel" :subjudul="`${teksRentang(p.m, p.s)}${jenjang ? ' · ' + (jenjang === 'sma' ? 'SMA' : 'Wustha') : ''}`" :pencetak="sesi.pengguna?.nama_lengkap">
      <table class="tabel kecil">
        <colgroup><col style="width:4%"><col style="width:10%"><col style="width:20%"><col style="width:14%"><col style="width:20%"><col style="width:6%"><col style="width:6%"><col style="width:7%"><col style="width:6%"><col style="width:7%"></colgroup>
        <thead><tr><th>No.</th><th>NIY</th><th>Nama guru</th><th>Kelas</th><th>Mata pelajaran</th><th>JP terjadwal</th><th>Terlaksana</th><th>Tidak terlaksana</th><th>Belum diisi</th><th>Keterlaksanaan</th></tr></thead>
        <tbody>
          <tr v-for="(g, i) in guruP" :key="g.employee_id"><td class="tengah">{{ i + 1 }}</td><td>{{ g.niy || '–' }}</td><td>{{ g.guru }}</td><td>{{ g.kelas.join(', ') }}</td><td>{{ g.mapel.join(', ') }}</td>
            <td class="tengah">{{ g.terjadwal }}</td><td class="tengah">{{ g.terlaksana }}</td><td class="tengah">{{ g.tidak }}</td><td class="tengah">{{ g.kosong }}</td><td class="kanan">{{ teksPersen(g.persen) }}</td></tr>
          <tr><th colspan="5">Jumlah</th><th>{{ totP.terjadwal }}</th><th>{{ totP.terlaksana }}</th><th>{{ totP.tidak }}</th><th>{{ totP.kosong }}</th><th class="kanan">{{ teksPersen(persenJP(totP.terlaksana, totP.terjadwal)) }}</th></tr>
        </tbody>
      </table>
      <p class="mt-2 text-[8pt]">Berdasarkan jurnal mengajar. JP terjadwal = jam pelajaran sesuai jadwal pelajaran pada hari sekolah (di luar libur) yang sudah lewat jamnya.</p>
      <template #ttd><TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan_tertulis || 'Direktur', nama: direktur.nama || '', niy: direktur.niy }" :kanan="{ jabatan: 'Pembuat', nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" /></template>
    </DokumenCetak>
  </div>
</template>
