<!-- SIMKA PRO | src/pages/walikelas/TabRingkasanKelas.vue | v1.1 | Perbaikan 13.6.0: sub-tab bergaris bawah | 15/10/2026 -->
<script setup>
// Dasbor pemantauan seluruh kelas (admin, superadmin, pimpinan): kehadiran kelas, absensi kelas hari ini sudah/belum diisi,
// santri sakit/izin, dan keterlaksanaan pelajaran (jurnal mengajar) per kelas. Saring jenjang; cetak F4 mendatar dan Excel.
// Ketuk kartu kelas untuk membuka dasbor kelas itu.
import { ref, computed, watch, onMounted, onBeforeUnmount } from 'vue'
import * as XLSX from 'xlsx'
import { PhChartLineUp, PhCheckSquareOffset, PhBookOpenText, PhFirstAidKit, PhSignOut, PhArrowRight, PhPrinter, PhFileXls, PhCheckCircle, PhHourglassMedium } from '@phosphor-icons/vue'
import { useWaliKelas } from '@/stores/waliKelas'
import { useLembaga } from '@/stores/lembaga'
import { useSesi } from '@/stores/sesi'
import { teksPersen } from '@/lib/absensi'
import { JENJANG_PENDEK } from '@/lib/santri'
import { awalPekan, awalBulanDari, akhirBulanDari, tambahHari, teksRentang } from '@/lib/musyrif'
import { persenJP, warnaPersen } from '@/lib/guruMapel'
import { hariIniISO } from '@/lib/tanggal'
import KartuStatistik from '@/components/KartuStatistik.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const emit = defineEmits(['buka'])
const wk = useWaliKelas(); const lembaga = useLembaga(); const sesi = useSesi(); const hari = hariIniISO()
const PERIODE = [{ k: 'hari', n: 'Hari ini', m: hari, s: hari }, { k: 'pekan', n: 'Pekan ini', m: awalPekan(hari), s: hari },
  { k: 'bulan', n: 'Bulan ini', m: awalBulanDari(hari), s: hari }, { k: 'lalu', n: 'Bulan lalu', m: awalBulanDari(tambahHari(awalBulanDari(hari), -1)), s: akhirBulanDari(tambahHari(awalBulanDari(hari), -1)) }]
const periode = ref('bulan'); const jenjang = ref(''); const data = ref([]); const memuat = ref(false); const galat = ref(''); const pratinjau = ref(false)
const p = computed(() => PERIODE.find((x) => x.k === periode.value))
async function muat() { memuat.value = true; galat.value = ''; try { data.value = await wk.ringkasan(p.value.m, p.value.s) } catch (e) { galat.value = e.message } finally { memuat.value = false } }
onMounted(() => { muat(); wk.dengarkan(muat); lembaga.muat() })
onBeforeUnmount(() => wk.berhenti())
watch(periode, muat)

const tampil = computed(() => data.value.filter((x) => !jenjang.value || x.jenjang === jenjang.value))
const jumlah = (k) => tampil.value.reduce((a, x) => a + (Number(x[k]) || 0), 0)
const rata = computed(() => { const n = jumlah('anggota'); return n ? Math.round((jumlah('hadir') / n) * 1000) / 10 : null })
const wajibHari = computed(() => tampil.value.filter((x) => x.hari_ini_wajib))
const statistik = computed(() => [
  { judul: 'Absensi kelas hari ini', nilai: `${wajibHari.value.filter((x) => x.hari_ini_terisi).length}/${wajibHari.value.length}`, ikon: PhCheckSquareOffset, warna: 'absensi', ket: wajibHari.value.length ? 'Kelas sudah diabsen wali kelas' : 'Hari ini bukan hari sekolah' },
  { judul: 'Kehadiran santri', nilai: teksPersen(rata.value), ikon: PhChartLineUp, warna: 'walikelas', ket: `${tampil.value.length} kelas · ${jumlah('santri')} santri` },
  { judul: 'Jurnal mengajar hari ini', nilai: `${jumlah('jp_hari_ini_isi')}/${jumlah('jp_hari_ini')}`, ikon: PhBookOpenText, warna: 'gurumapel', ket: 'Jam pelajaran sudah diisi guru' },
  { judul: 'Keterlaksanaan pelajaran', nilai: teksPersen(persenJP(jumlah('jp_terlaksana'), jumlah('jp_terjadwal'))), ikon: PhCheckCircle, warna: 'presensi', ket: `${jumlah('jp_kosong')} JP belum diisi · ${jumlah('jp_tidak')} tidak terlaksana` },
])
const warna = (v) => 'w-' + warnaPersen(v)
const urut = computed(() => [...tampil.value].sort((a, b) => (a.tingkat - b.tingkat) || a.nama.localeCompare(b.nama, 'id', { numeric: true })))
function buka(x) { wk.pilih = x.id; emit('buka') }

const direktur = computed(() => lembaga.signatories.find((s) => s.sumber_jabatan === 'DIREKTUR' || /^direktur/i.test(s.jabatan_tertulis)) || {})
const judulCetak = computed(() => `${teksRentang(p.value.m, p.value.s)}${jenjang.value ? ' · ' + JENJANG_PENDEK[jenjang.value] : ''}`)
function ekspor() {
  const aoa = [['No.', 'Kelas', 'Jenjang', 'Wali kelas', 'Santri', 'Sesi terisi', 'Sesi seharusnya', 'Kehadiran (%)', 'Izin', 'Sakit', 'Absen', 'Bolos', 'Terlambat',
    'JP terjadwal', 'JP terlaksana', 'JP tidak terlaksana', 'JP belum diisi', 'Keterlaksanaan (%)'],
  ...urut.value.map((x, i) => [i + 1, x.nama, JENJANG_PENDEK[x.jenjang] || '', x.wali || '', x.santri, x.sesi_terisi, x.sesi_rencana, x.persen ?? '', x.izin, x.sakit, x.absen, x.bolos ?? 0, x.terlambat,
    x.jp_terjadwal, x.jp_terlaksana, x.jp_tidak, x.jp_kosong, persenJP(x.jp_terlaksana, x.jp_terjadwal) ?? ''])]
  const ws = XLSX.utils.aoa_to_sheet(aoa); ws['!cols'] = aoa[0].map((j) => ({ wch: j === 'Wali kelas' ? 28 : 12 }))
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Pemantauan kelas'); XLSX.writeFile(wb, `Pemantauan-Kelas-${p.value.m}-${p.value.s}.xlsx`)
}
</script>
<template>
  <div>
    <div class="mb-3 flex flex-wrap items-center gap-2">
      <div class="bilah-tab kecil" role="tablist" aria-label="Periode"><button v-for="x in PERIODE" :key="x.k" :class="['tab-garis', periode === x.k && 'aktif']" type="button" role="tab" :aria-selected="periode === x.k" @click="periode = x.k">{{ x.n }}</button></div>
      <select v-model="jenjang" class="isian h-9 w-auto py-0 text-sm" aria-label="Saring jenjang"><option value="">Semua jenjang</option><option value="wustha">Wustha</option><option value="sma">SMA</option></select>
      <span class="text-xs text-teks3">{{ teksRentang(p.m, p.s) }}</span>
      <span class="flex-1" />
      <button class="tombol-garis min-h-[40px] px-3 text-sm" :disabled="!tampil.length" @click="ekspor"><PhFileXls :size="18" weight="duotone" /> Excel</button>
      <button class="tombol-garis min-h-[40px] px-3 text-sm" :disabled="!tampil.length" @click="pratinjau = true"><PhPrinter :size="18" weight="duotone" /> Cetak</button>
    </div>
    <div class="-mx-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-2 sm:overflow-visible sm:px-0 xl:grid-cols-4">
      <KartuStatistik v-for="k in statistik" :key="k.judul" class="w-[44%] shrink-0 snap-start sm:w-auto" :judul="k.judul" :nilai="memuat && !data.length ? '…' : k.nilai" :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket" />
    </div>
    <ul class="mt-4 grid gap-3 md:grid-cols-2 xl:grid-cols-3">
      <li v-for="x in urut" :key="x.id">
        <button class="kartu w-full p-4 text-left transition hover:-translate-y-0.5" :class="warna(x.persen)" @click="buka(x)">
          <div class="flex items-start gap-3">
            <div class="min-w-0 flex-1"><b class="block truncate">Kelas {{ x.nama }} <span class="text-xs font-normal text-teks3">· {{ JENJANG_PENDEK[x.jenjang] }}</span></b>
              <span class="block truncate text-xs text-teks3">{{ x.santri }} santri · {{ x.wali || 'belum ada wali kelas' }}</span></div>
            <span class="text-right"><span class="block text-2xl font-extrabold tabular-nums" style="color: var(--c)">{{ teksPersen(x.persen) }}</span><span class="text-[11px] text-teks3">kehadiran</span></span>
          </div>
          <div class="mt-3 flex flex-wrap gap-1.5 text-xs">
            <span v-if="!x.hari_ini_wajib" class="lencana w-hakakses">Hari ini libur</span>
            <span v-else-if="x.hari_ini_terisi" class="lencana w-presensi"><PhCheckCircle :size="12" /> Absensi hari ini terisi</span>
            <span v-else class="lencana w-tahfizh"><PhHourglassMedium :size="12" /> Absensi hari ini belum diisi</span>
            <span v-if="x.jp_hari_ini" :class="['lencana', x.jp_hari_ini_isi < x.jp_hari_ini ? 'w-laporan' : 'w-gurumapel']">Jurnal hari ini {{ x.jp_hari_ini_isi }}/{{ x.jp_hari_ini }} JP</span>
          </div>
          <div class="mt-2 flex items-center gap-2 text-xs text-teks3">
            <span class="w-20 shrink-0">Pelajaran</span>
            <div class="h-2 flex-1 overflow-hidden rounded-full bg-permukaan2" role="img" :aria-label="`Keterlaksanaan ${teksPersen(persenJP(x.jp_terlaksana, x.jp_terjadwal))}`">
              <div class="h-full rounded-full" :class="'w-' + warnaPersen(persenJP(x.jp_terlaksana, x.jp_terjadwal))" :style="{ width: (persenJP(x.jp_terlaksana, x.jp_terjadwal) ?? 0) + '%', background: 'var(--c)' }" /></div>
            <span class="w-24 shrink-0 text-right tabular-nums">{{ x.jp_terlaksana }}/{{ x.jp_terjadwal }} JP</span>
          </div>
          <div class="mt-2 flex flex-wrap gap-1.5 text-xs">
            <span class="lencana w-pengajuan">I {{ x.izin }}</span><span class="lencana w-klinik">S {{ x.sakit }}</span><span class="lencana w-beranda">A {{ x.absen }}</span>
            <span v-if="x.sakit_aktif" class="lencana w-klinik"><PhFirstAidKit :size="12" /> {{ x.sakit_aktif }} di klinik</span>
            <span v-if="x.izin_aktif" class="lencana w-pengajuan"><PhSignOut :size="12" /> {{ x.izin_aktif }} izin</span>
            <span v-if="x.jp_kosong" class="lencana w-tahfizh">{{ x.jp_kosong }} JP belum diisi</span>
          </div>
          <p class="mt-2 flex items-center justify-end gap-1.5 text-xs font-semibold text-teks2">Buka dasbor kelas <PhArrowRight :size="14" /></p>
        </button>
      </li>
    </ul>
    <p v-if="galat" class="kartu w-klinik mt-4 p-5 text-sm font-semibold" style="color: var(--c)">Ringkasan gagal dimuat: {{ galat }}</p>
    <div v-else-if="!data.length && !memuat" class="kartu mt-4 p-6 text-center text-sm text-teks2">
      <p class="font-semibold">Belum ada kelas aktif pada tahun ajaran aktif.</p>
      <p class="mt-1 text-teks3">Dasbor terisi setelah kelas dibuat dan diisi santri serta wali kelasnya di Kelompok Santri → Kelas.</p>
      <router-link to="/kelompok-santri" class="tombol-utama mt-3 inline-flex">Buka Kelompok Santri</router-link>
    </div>
    <p class="mt-3 text-xs text-teks3">Kehadiran = (hadir + terlambat + bolos) ÷ seluruh kehadiran tercatat. Keterlaksanaan = JP terlaksana ÷ JP terjadwal yang sudah lewat jamnya.</p>

    <DokumenCetak v-model:pratinjau="pratinjau" mendatar judul="Rekap Pemantauan Kelas" :subjudul="judulCetak" :pencetak="sesi.pengguna?.nama_lengkap">
      <table class="tabel kecil">
        <colgroup><col style="width:3%"><col style="width:6%"><col style="width:17%"><col style="width:5%"><col style="width:7%"><col style="width:7%"><col style="width:5%"><col style="width:5%"><col style="width:5%"><col style="width:5%"><col style="width:7%"><col style="width:7%"><col style="width:7%"><col style="width:7%"><col style="width:7%"></colgroup>
        <thead><tr><th>No.</th><th>Kelas</th><th>Wali kelas</th><th>Santri</th><th>Sesi terisi</th><th>Kehadiran</th><th>Izin</th><th>Sakit</th><th>Absen</th><th>Bolos</th>
          <th>JP terjadwal</th><th>JP terlaksana</th><th>JP tidak terlaksana</th><th>JP belum diisi</th><th>Keterlaksanaan</th></tr></thead>
        <tbody>
          <tr v-for="(x, i) in urut" :key="x.id"><td class="tengah">{{ i + 1 }}</td><td>{{ x.nama }}</td><td>{{ x.wali || '–' }}</td><td class="tengah">{{ x.santri }}</td>
            <td class="tengah">{{ x.sesi_terisi }}/{{ x.sesi_rencana }}</td><td class="kanan">{{ teksPersen(x.persen) }}</td><td class="tengah">{{ x.izin }}</td><td class="tengah">{{ x.sakit }}</td>
            <td class="tengah">{{ x.absen }}</td><td class="tengah">{{ x.bolos ?? 0 }}</td><td class="tengah">{{ x.jp_terjadwal }}</td><td class="tengah">{{ x.jp_terlaksana }}</td>
            <td class="tengah">{{ x.jp_tidak }}</td><td class="tengah">{{ x.jp_kosong }}</td><td class="kanan">{{ teksPersen(persenJP(x.jp_terlaksana, x.jp_terjadwal)) }}</td></tr>
          <tr><th colspan="3">Jumlah/rata-rata</th><th>{{ jumlah('santri') }}</th><th>{{ jumlah('sesi_terisi') }}</th><th class="kanan">{{ teksPersen(rata) }}</th><th>{{ jumlah('izin') }}</th><th>{{ jumlah('sakit') }}</th>
            <th>{{ jumlah('absen') }}</th><th>{{ jumlah('bolos') }}</th><th>{{ jumlah('jp_terjadwal') }}</th><th>{{ jumlah('jp_terlaksana') }}</th><th>{{ jumlah('jp_tidak') }}</th><th>{{ jumlah('jp_kosong') }}</th>
            <th class="kanan">{{ teksPersen(persenJP(jumlah('jp_terlaksana'), jumlah('jp_terjadwal'))) }}</th></tr>
        </tbody>
      </table>
      <p class="mt-2 text-[8pt]">Kehadiran = (hadir + terlambat + bolos) ÷ seluruh kehadiran tercatat pada absensi kelas. Keterlaksanaan = JP terlaksana ÷ JP terjadwal (berdasarkan jurnal mengajar guru).</p>
      <template #ttd><TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan_tertulis || 'Direktur', nama: direktur.nama || '', niy: direktur.niy }" :kanan="{ jabatan: 'Pembuat', nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" /></template>
    </DokumenCetak>
  </div>
</template>
