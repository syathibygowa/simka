<!-- SIMKA PRO | src/pages/tahfizh/TabLaporan.vue | v1.0 | Fase 5 – Tahap 5 Laporan dan grafik tahfizh | 05/10/2026 -->
<script setup>
// Laporan tahfizh: 15 format (Blueprint Bagian 20) dengan periode bulan/semester/tahun, pengelompokan per halaqah, kelas,
// tingkatan, kamar, atau seluruh santri. Pratinjau di layar, ekspor Excel, dan cetak F4 berkop (tiap kelompok satu halaman
// dengan tanda tangan Kepala Bidang Tahfizh dan muhaffizh). Data diolah dari setoran, capaian, absensi halaqah, dan ujian.
import { ref, computed, onMounted, watch } from 'vue'
import * as XLSX from 'xlsx'
import { PhChartPieSlice, PhTable, PhPlay, PhDownloadSimple, PhEye, PhMagnifyingGlass } from '@phosphor-icons/vue'
import { useTahfizh } from '@/stores/tahfizh'
import { useKelompokSantri } from '@/stores/kelompokSantri'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { KATALOG, KELOMPOK, kunciKelompok, susunLaporan } from '@/lib/laporanTahfizh'
import { labelBulan, penandaTahfizh } from '@/lib/tahfizh'
import { hariIniISO, formatPendek } from '@/lib/tanggal'
import GrafikLingkaran from '@/components/grafik/GrafikLingkaran.vue'
import GrafikBatang from '@/components/grafik/GrafikBatang.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const tz = useTahfizh(); const kel = useKelompokSantri(); const sesi = useSesi(); const ui = useUI()
const jenis = ref('bulanan'); const kat = computed(() => KATALOG.find((k) => k.k === jenis.value))
const bulanIni = hariIniISO().slice(0, 8) + '01'
const bulan = ref(bulanIni); const semester = ref(Number(hariIniISO().slice(5, 7)) >= 7 ? 1 : 2)
const kelompok = ref('halaqah'); const nilaiKelompok = ref(''); const rentang = ref({ min: 30, maks: 30 })
const cariSantri = ref(''); const santriPilih = ref(null)
const memuat = ref(false); const lap = ref(null); const dataTerakhir = ref([])
const daftarBulan = computed(() => tz.bulan.filter((b) => b.bulan <= bulanIni).map((b) => b.bulan).reverse())
const bulanSemester = computed(() => tz.bulan.filter((b) => b.semester === semester.value && b.bulan <= bulanIni).map((b) => b.bulan))
const pilihanNilai = computed(() => [...new Set(dataTerakhir.value.map((r) => kunciKelompok(r, kelompok.value)))].sort((a, b) => a.localeCompare(b, 'id', { numeric: true })))
const calonSantri = computed(() => { const q = cariSantri.value.toLowerCase().trim(); return q ? tz.santri.filter((s) => `${s.nama} ${s.nis}`.toLowerCase().includes(q)).slice(0, 8) : [] })
watch(kelompok, () => { nilaiKelompok.value = '' })
watch(jenis, () => { lap.value = null })

onMounted(async () => {
  if (!tz.hakDimuat) await tz.muatHak()
  await kel.muat(); if (!tz.bulan.length || !tz.pengaturan) await tz.muatPengaturan()
  if (!tz.santri.length) await tz.muatSantri()
  try { dataTerakhir.value = await tz.dataLaporan(bulan.value) } catch { dataTerakhir.value = [] }
})

async function tampilkan() {
  if (kat.value.periode === 'santri' && !santriPilih.value) return ui.toast('Pilih santri lebih dulu.', 'galat')
  memuat.value = true
  try {
    const ctx = { kelompok: kat.value.tanpaKelompok ? 'seluruh' : kelompok.value, nilaiKelompok: kat.value.tanpaKelompok ? '' : nilaiKelompok.value, bulan: bulan.value,
      pengaturan: tz.pengaturan, rentang: rentang.value }
    if (kat.value.periode === 'bulan') {
      ctx.data = await tz.dataLaporan(bulan.value); dataTerakhir.value = ctx.data
      if (jenis.value === 'ujian') ctx.ujian = (await tz.daftarUjian(null, 'selesai')).filter((u) => String(u.diuji_pada || '').slice(0, 7) === bulan.value.slice(0, 7) || formatPendek(u.diuji_pada).slice(3) === formatPendek(bulan.value).slice(3))
      if (jenis.value === 'halaqah') ctx.kehadiran = await tz.kehadiranHalaqah(bulan.value)
      if (jenis.value === 'kepatuhan') ctx.kepatuhan = await tz.kepatuhanSetoran(bulan.value)
    } else {
      const daftar = kat.value.periode === 'tahun' ? tz.bulan.filter((b) => b.bulan <= bulanIni).map((b) => b.bulan) : bulanSemester.value
      if (!daftar.length) { ui.toast('Belum ada bulan berjalan pada periode ini.', 'galat'); return }
      const isi = await Promise.all(daftar.map((b) => tz.dataLaporan(b)))
      ctx.dataBulan = Object.fromEntries(daftar.map((b, i) => [b, isi[i]])); ctx.data = isi[isi.length - 1]; dataTerakhir.value = ctx.data
      ctx.periodeLabel = kat.value.periode === 'tahun' ? `Tahun Ajaran ${kel.taSekarang?.nama || ''}` : `Semester ${semester.value} (${labelBulan(daftar[0])} – ${labelBulan(daftar[daftar.length - 1])})`
      if (jenis.value === 'individu') {
        ctx.santri = santriPilih.value
        ctx.riwayat = await tz.riwayatSetoran(santriPilih.value.student_id, daftar[0], hariIniISO())
        ctx.ujian = await tz.daftarUjian(null, 'selesai')
      }
    }
    lap.value = susunLaporan(jenis.value, ctx)
    if (!lap.value.bagian.length && !lap.value.grafik) ui.toast('Tidak ada data untuk laporan ini.', 'info')
  } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}

// ---------- Excel ----------
function eksporExcel() {
  const aoa = [[lap.value.judul], [lap.value.subjudul || ''], []]
  if (lap.value.identitas) { lap.value.identitas.forEach(([a, b]) => aoa.push([a, b])); aoa.push([]) }
  for (const b of lap.value.bagian) {
    if (b.judul) aoa.push([b.judul])
    aoa.push(b.kolom.map((k) => k.n)); b.baris.forEach((r) => aoa.push(r.sel))
    b.catatan.forEach((c) => aoa.push([c])); aoa.push([])
  }
  const ws = XLSX.utils.aoa_to_sheet(aoa)
  const lebar = Math.max(...lap.value.bagian.map((b) => b.kolom.length), 2)
  ws['!cols'] = Array.from({ length: lebar }, (_, i) => ({ wch: i === 0 ? 6 : 14 }))
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Laporan')
  XLSX.writeFile(wb, `${lap.value.judul.replace(/\s+/g, '-')}-${formatPendek(new Date()).replace(/\//g, '-')}.xlsx`)
}

// ---------- Cetak ----------
const pratinjau = ref(false); const kepala = ref({ jabatan: '', nama: '', niy: '' })
async function cetak() { kepala.value = await penandaTahfizh(); pratinjau.value = true }
const kanan = (b) => (b.muhaffizh ? { jabatan: 'Muhaffizh', nama: b.muhaffizh, niy: '' } : { jabatan: 'Pencetak', nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy || '' })
const lebarKolom = (b) => { const t = b.kolom.reduce((s, k) => s + Number(k.lebar || 10), 0); return b.kolom.map((k) => `${(Number(k.lebar || 10) / t) * 100}%`) }
</script>
<template>
  <div>
    <div class="layar-saja">
      <!-- Pilih laporan -->
      <section class="kartu p-4">
        <div class="grid gap-3 lg:grid-cols-[1fr_auto]">
          <div><label class="label-isian" for="lp-jenis">Laporan</label>
            <select id="lp-jenis" v-model="jenis" class="isian">
              <optgroup label="Laporan tabel"><option v-for="k in KATALOG.filter((x) => !x.grafik)" :key="k.k" :value="k.k">{{ k.n }}</option></optgroup>
              <optgroup label="Grafik"><option v-for="k in KATALOG.filter((x) => x.grafik)" :key="k.k" :value="k.k">{{ k.n }}</option></optgroup>
            </select></div>
          <div class="flex items-end gap-2">
            <button class="tombol-utama" :disabled="memuat" @click="tampilkan"><PhPlay :size="20" weight="duotone" /> {{ memuat ? 'Mengolah…' : 'Tampilkan' }}</button>
          </div>
        </div>
        <div class="mt-3 flex flex-wrap items-end gap-2">
          <div v-if="kat.periode === 'bulan'"><label class="label-isian" for="lp-bulan">Bulan</label>
            <select id="lp-bulan" v-model="bulan" class="isian w-auto"><option v-for="b in daftarBulan" :key="b" :value="b">{{ labelBulan(b) }}</option></select></div>
          <div v-if="kat.periode === 'semester' || kat.periode === 'santri'"><label class="label-isian" for="lp-smt">Semester</label>
            <select id="lp-smt" v-model.number="semester" class="isian w-auto"><option :value="1">Semester 1 (Juli–Desember)</option><option :value="2">Semester 2 (Januari–Juni)</option></select></div>
          <p v-if="kat.periode === 'tahun'" class="pb-3 text-sm text-teks3">Tahun ajaran {{ kel.taSekarang?.nama }} (Juli–Juni, sampai bulan berjalan)</p>
          <template v-if="!kat.tanpaKelompok">
            <div><label class="label-isian" for="lp-kel">Kelompokkan</label>
              <select id="lp-kel" v-model="kelompok" class="isian w-auto"><option v-for="(n, k) in KELOMPOK" :key="k" :value="k">{{ n }}</option></select></div>
            <div v-if="kelompok !== 'seluruh'"><label class="label-isian" for="lp-nilai">Pilih</label>
              <select id="lp-nilai" v-model="nilaiKelompok" class="isian w-auto"><option value="">Semua (satu halaman per kelompok)</option><option v-for="n in pilihanNilai" :key="n" :value="n">{{ n }}</option></select></div>
          </template>
          <template v-if="kat.rentang">
            <div><label class="label-isian" for="lp-min">Total hafalan dari</label><input id="lp-min" v-model.number="rentang.min" type="number" min="0" max="30" class="isian w-24" /></div>
            <div><label class="label-isian" for="lp-maks">s.d. (juz)</label><input id="lp-maks" v-model.number="rentang.maks" type="number" min="0" max="30" class="isian w-24" /></div>
          </template>
          <div v-if="kat.periode === 'santri'" class="relative min-w-[260px] flex-1"><label class="label-isian" for="lp-santri">Santri</label>
            <div class="relative"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
              <input id="lp-santri" v-model="cariSantri" type="search" class="isian pl-11" :placeholder="santriPilih ? santriPilih.nama : 'Ketik nama atau NIS'" /></div>
            <ul v-if="calonSantri.length" class="absolute z-20 mt-1 w-full divide-y divide-garis rounded-xl border border-garis bg-permukaan shadow-apung">
              <li v-for="s in calonSantri" :key="s.student_id"><button type="button" class="w-full px-3 py-2 text-left text-sm hover:bg-permukaan2" @click="santriPilih = s; cariSantri = ''">
                <b>{{ s.nama }}</b> <span class="text-teks3">· {{ s.nis }} · {{ s.halaqah || '–' }}</span></button></li>
            </ul></div>
        </div>
      </section>

      <!-- Hasil -->
      <section v-if="lap" class="kartu mt-4 p-4">
        <div class="mb-3 flex flex-wrap items-center gap-2">
          <div class="min-w-[220px] flex-1"><h2 class="judul-bagian">{{ lap.judul }}</h2><p class="text-sm text-teks3">{{ lap.subjudul }}</p></div>
          <button class="tombol-garis w-santri" @click="eksporExcel"><PhDownloadSimple :size="20" weight="duotone" style="color: var(--c)" /> Excel</button>
          <button class="tombol-garis w-laporan" @click="cetak"><PhEye :size="20" weight="duotone" style="color: var(--c)" /> Pratinjau cetak</button>
        </div>
        <dl v-if="lap.identitas" class="mb-3 grid gap-x-6 gap-y-1 text-sm sm:grid-cols-2"><template v-for="[a, b] in lap.identitas" :key="a"><div class="flex gap-2"><dt class="w-40 text-teks3">{{ a }}</dt><dd class="font-semibold">{{ b }}</dd></div></template></dl>
        <div v-if="lap.grafik" class="mb-4 rounded-2xl bg-permukaan2 p-4">
          <GrafikLingkaran v-if="lap.grafik.jenis === 'lingkaran'" :data="lap.grafik.data" />
          <GrafikBatang v-else :label="lap.grafik.label" :seri="lap.grafik.seri" :sumbu-y="lap.grafik.sumbuY" />
        </div>
        <div v-for="(b, i) in lap.bagian" :key="i" class="mb-5">
          <p v-if="b.judul" class="mb-2 flex items-center gap-2 font-bold"><PhTable :size="18" weight="duotone" class="text-teks3" /> {{ b.judul }}</p>
          <div class="overflow-x-auto rounded-xl border border-garis">
            <table class="w-full text-left text-sm">
              <thead class="bg-permukaan2 text-teks2"><tr><th v-for="k in b.kolom" :key="k.n" :class="['whitespace-nowrap px-2.5 py-2 font-bold', k.tengah && 'text-center']">{{ k.n }}</th></tr></thead>
              <tbody class="divide-y divide-garis">
                <tr v-for="(r, j) in b.baris" :key="j" :class="r.sorot && 'bg-[#C7332F]/10'">
                  <td v-for="(c, x) in r.sel" :key="x" :class="['px-2.5 py-1.5', b.kolom[x]?.tengah && 'text-center tabular-nums']">{{ c }}</td></tr>
                <tr v-if="!b.baris.length"><td :colspan="b.kolom.length" class="px-3 py-6 text-center text-teks3">Tidak ada data.</td></tr>
              </tbody>
            </table>
          </div>
          <p v-for="c in b.catatan" :key="c" class="mt-1 text-xs text-teks3">{{ c }}</p>
        </div>
      </section>
      <div v-else class="kartu mt-4 flex flex-col items-center gap-2 p-10 text-center text-teks3">
        <PhChartPieSlice :size="40" weight="duotone" /><p class="text-sm">Pilih laporan, periode, dan pengelompokan, lalu tekan <b>Tampilkan</b>.</p>
      </div>
    </div>

    <!-- Cetak F4 -->
    <DokumenCetak v-if="lap" kop="pondok" :judul="lap.judul" :subjudul="lap.subjudul" v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap" :mendatar="!!kat.mendatar || !!lap.mendatar">
      <table v-if="lap.identitas" style="width: 100%; margin-bottom: 8pt; font-size: 10.5pt"><tbody><tr v-for="[a, b] in lap.identitas" :key="a"><td style="width: 30%">{{ a }}</td><td>: {{ b }}</td></tr></tbody></table>
      <div v-if="lap.grafik" style="margin: 4pt 0 10pt">
        <GrafikLingkaran v-if="lap.grafik.jenis === 'lingkaran'" :data="lap.grafik.data" />
        <GrafikBatang v-else :label="lap.grafik.label" :seri="lap.grafik.seri" :sumbu-y="lap.grafik.sumbuY" />
      </div>
      <section v-for="(b, i) in lap.bagian" :key="i" :style="i > 0 && lap.bagian.length > 1 && !lap.identitas ? 'page-break-before: always' : ''">
        <p v-if="b.judul" style="margin: 6pt 0 4pt; font-weight: 700">{{ b.judul }}</p>
        <table :class="['tabel', (lap.kecil || b.kolom.length > 10) && 'kecil']">
          <colgroup><col v-for="(w, x) in lebarKolom(b)" :key="x" :style="{ width: w }"></colgroup>
          <thead><tr><th v-for="k in b.kolom" :key="k.n">{{ k.n }}</th></tr></thead>
          <tbody>
            <tr v-for="(r, j) in b.baris" :key="j" :style="r.sorot ? 'background: #FBE3E1' : ''"><td v-for="(c, x) in r.sel" :key="x" :class="b.kolom[x]?.tengah && 'tengah'">{{ c }}</td></tr>
            <tr v-if="!b.baris.length"><td :colspan="b.kolom.length" class="tengah">Tidak ada data.</td></tr>
          </tbody>
        </table>
        <p v-for="c in b.catatan" :key="c" style="margin-top: 3pt; font-size: 9pt">{{ c }}</p>
        <TandaTangan v-if="lap.bagian.length > 1 && !lap.identitas" :kiri="{ pengantar: 'Mengetahui,', jabatan: kepala.jabatan, nama: kepala.nama, niy: kepala.niy }" :kanan="kanan(b)" />
      </section>
      <template v-if="lap.bagian.length <= 1 || lap.identitas" #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: kepala.jabatan, nama: kepala.nama, niy: kepala.niy }" :kanan="lap.bagian[0] ? kanan(lap.bagian[0]) : kanan({})" />
      </template>
    </DokumenCetak>
  </div>
</template>
