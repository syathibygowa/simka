<!-- SIMKA PRO | src/pages/jurnal/TabRekapJurnal.vue | v1.2 | Laporan tabel ceklist harian (butir template × tanggal, centang bila dikerjakan) | 15/10/2026 -->
<script setup>
// Rekap jurnal per periode: persentase pengisian (hari terisi ÷ hari wajib), butir ceklist, dan kegiatan per status.
// Pegawai melihat dirinya sendiri; pimpinan melihat anggota unitnya; admin ber-izin verval_jurnal melihat semua.
// Laporan individu (per hari) dan rekap kolektif dapat dicetak F4 dan diekspor ke Excel.
import { ref, computed, onMounted, watch } from 'vue'
import * as XLSX from 'xlsx'
import { PhMagnifyingGlass, PhEye, PhFileXls, PhPrinter, PhInfo, PhTable } from '@phosphor-icons/vue'
import { useJurnal } from '@/stores/jurnal'
import { useOrganisasi } from '@/stores/organisasi'
import { useLembaga } from '@/stores/lembaga'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { hariIniISO, formatPanjang, formatPendek, formatHari } from '@/lib/tanggal'
import InputTanggal from '@/components/InputTanggal.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const jr = useJurnal(); const org = useOrganisasi(); const lembaga = useLembaga(); const sesi = useSesi(); const ui = useUI()
const mulai = ref(hariIniISO().slice(0, 8) + '01'); const akhir = ref(hariIniISO())
const data = ref([]); const memuat = ref(false); const unit = ref(''); const cari = ref('')
const pratinjau = ref(false); const individu = ref(null); const pratinjauInd = ref(false)

onMounted(async () => { await Promise.all([org.muat(), lembaga.muat()]); muat() })
watch([mulai, akhir], () => muat())
async function muat() {
  if (akhir.value < mulai.value) return ui.toast('Tanggal akhir tidak boleh sebelum tanggal mulai.', 'galat')
  memuat.value = true
  try { data.value = await jr.rekap(mulai.value, akhir.value) } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
const tampil = computed(() => data.value.filter((r) => (!unit.value || org.turunan(unit.value).has(r.org_unit_id))
  && (!cari.value.trim() || [r.nama, r.niy].join(' ').toLowerCase().includes(cari.value.toLowerCase().trim()))))
const banyak = computed(() => data.value.length > 1)
const warna = (p) => (p == null ? 'hakakses' : p >= 90 ? 'presensi' : p >= 75 ? 'tahfizh' : 'beranda')
const persen = (p) => (p == null ? '–' : String(p).replace('.', ',') + '%')
const total = computed(() => {
  const t = { w: 0, t: 0 }; tampil.value.forEach((r) => { t.w += r.hari_wajib; t.t += r.hari_terisi })
  return t.w ? Math.round((1000 * t.t) / t.w) / 10 : null
})
function bulan(n) {
  const d = new Date(hariIniISO().slice(0, 8) + '01T00:00:00Z'); d.setUTCMonth(d.getUTCMonth() + n)
  mulai.value = d.toISOString().slice(0, 10)
  akhir.value = n === 0 ? hariIniISO() : new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 0)).toISOString().slice(0, 10)
}

function ekspor() {
  const kolom = ['No.', 'NIY', 'Nama', 'Bidang/Unit', 'Hari wajib', 'Hari terisi', 'Tidak diisi (terkunci)', 'Pengisian (%)', 'Butir ceklist', 'Kegiatan disetujui', 'Menunggu verval', 'Dikembalikan']
  const d = tampil.value.map((r, i) => [i + 1, r.niy || '', r.nama, r.unit || '', r.hari_wajib, r.hari_terisi, r.hari_kosong, r.persen ?? '', r.butir, r.kegiatan_disetujui, r.kegiatan_menunggu, r.kegiatan_dikembalikan])
  const ws = XLSX.utils.aoa_to_sheet([kolom, ...d]); ws['!cols'] = kolom.map((k, i) => ({ wch: Math.min(40, Math.max(k.length, ...d.map((r) => String(r[i]).length)) + 2) }))
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Rekap jurnal')
  XLSX.writeFile(wb, `Rekap-Jurnal-${formatPendek(mulai.value).replace(/\//g, '-')}_sd_${formatPendek(akhir.value).replace(/\//g, '-')}.xlsx`)
}
async function laporanIndividu(r) {
  try { individu.value = { r, hari: await jr.individu(r.employee_id, mulai.value, akhir.value) }; pratinjauInd.value = true } catch (e) { ui.toast(e.message, 'galat') }
}
// ---------- Tabel ceklist: No., butir template, tanggal 1–31 (✓ bila dikerjakan), jumlah ----------
const matriks = ref(null); const pratinjauM = ref(false)
async function tabelCeklist(r) {
  const hari = (Date.parse(akhir.value) - Date.parse(mulai.value)) / 864e5 + 1
  if (hari > 31) return ui.toast('Tabel ceklist paling panjang 31 hari. Pilih Bulan ini atau Bulan lalu.', 'galat')
  try {
    const m = await jr.matriks(r.employee_id, mulai.value, akhir.value)
    const cek = new Set((m.cek || []).map((c) => `${c.item_id}|${c.tanggal}`))
    const butir = (m.butir || []).map((b) => ({ ...b, hari: (m.hari || []).map((h) => cek.has(`${b.item_id}|${h.tanggal}`)), n: (m.hari || []).filter((h) => cek.has(`${b.item_id}|${h.tanggal}`)).length }))
    matriks.value = { r, hari: m.hari || [], butir, wajib: (m.hari || []).filter((h) => h.wajib).length }
    pratinjauM.value = true
  } catch (e) { ui.toast(e.message, 'galat') }
}
const lebarTgl = computed(() => (matriks.value ? `${(58 / Math.max(1, matriks.value.hari.length)).toFixed(2)}%` : '2%'))
const jam = (v) => String(v || '').slice(0, 5).replace(':', '.')
const STATUS = { menunggu: 'menunggu verval', disetujui: 'disetujui', dikembalikan: 'dikembalikan' }
const direktur = computed(() => lembaga.signatories.find((s) => s.sumber_jabatan === 'DIREKTUR' || /^direktur/i.test(s.jabatan_tertulis)) || lembaga.signatories[0] || {})
const namaUnit = computed(() => (unit.value ? org.cariUnit(unit.value)?.nama : 'Semua bidang'))
</script>
<template>
  <div class="w-rekap">
    <div class="kartu mb-3 grid gap-3 p-4 sm:grid-cols-2 lg:grid-cols-4">
      <InputTanggal v-model="mulai" label="Dari tanggal" />
      <InputTanggal v-model="akhir" label="Sampai tanggal" />
      <template v-if="banyak">
        <div><label class="label-isian" for="rj-unit">Bidang/Unit</label>
          <select id="rj-unit" v-model="unit" class="isian"><option value="">Semua bidang</option>
            <option v-for="u in org.datar" :key="u.id" :value="u.id">{{ '— '.repeat(u.tingkat) }}{{ u.nama }}</option></select></div>
        <div><label class="label-isian" for="rj-cari">Cari pegawai</label>
          <div class="relative"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-teks3" />
            <input id="rj-cari" v-model="cari" class="isian pl-10" placeholder="Nama atau NIY" /></div></div>
      </template>
      <div class="flex flex-wrap gap-2 sm:col-span-2 lg:col-span-4">
        <button class="tombol-garis min-h-[40px] text-sm" @click="bulan(0)">Bulan ini</button>
        <button class="tombol-garis min-h-[40px] text-sm" @click="bulan(-1)">Bulan lalu</button>
      </div>
    </div>
    <div class="mb-3 flex flex-wrap items-center gap-2">
      <button v-if="banyak" class="tombol-garis" @click="pratinjau = true"><PhEye :size="20" weight="duotone" /> Pratinjau cetak rekap</button>
      <button v-if="banyak" class="tombol-garis" @click="ekspor"><PhFileXls :size="20" weight="duotone" /> Ekspor Excel</button>
      <span v-if="banyak" class="ml-auto text-sm font-semibold text-teks2">Rata-rata pengisian: <span :class="['lencana', 'w-' + warna(total)]">{{ persen(total) }}</span></span>
    </div>
    <p class="mb-3 flex gap-2 text-sm text-teks3"><PhInfo :size="18" class="mt-0.5 shrink-0" />Hari wajib = hari dengan sesi presensi wajib, di luar izin/sakit/cuti yang disetujui. Hari dianggap terisi bila ada butir ceklist atau kegiatan yang tidak dikembalikan.</p>

    <p v-if="memuat" class="py-8 text-center text-teks3">Menghitung rekap…</p>
    <template v-else>
      <div class="kartu hidden overflow-x-auto lg:block">
        <table class="w-full text-sm">
          <thead><tr class="border-b border-garis text-center"><th class="p-3 text-left">Nama</th><th class="p-2">Hari wajib</th><th class="p-2">Terisi</th><th class="p-2">Tidak diisi</th>
            <th class="p-2">Butir</th><th class="p-2">Kegiatan disetujui</th><th class="p-2">Menunggu</th><th class="p-2">Pengisian</th><th class="p-2"></th></tr></thead>
          <tbody>
            <tr v-for="r in tampil" :key="r.employee_id" class="border-b border-garis text-center last:border-0">
              <td class="p-3 text-left"><p class="font-semibold">{{ r.nama }}</p><p class="text-xs text-teks3">{{ r.unit }}</p></td>
              <td class="p-2 tabular-nums">{{ r.hari_wajib }}</td><td class="p-2 tabular-nums">{{ r.hari_terisi }}</td><td class="p-2 tabular-nums">{{ r.hari_kosong }}</td>
              <td class="p-2 tabular-nums">{{ r.butir }}</td><td class="p-2 tabular-nums">{{ r.kegiatan_disetujui }}</td><td class="p-2 tabular-nums">{{ r.kegiatan_menunggu }}</td>
              <td class="p-2"><span :class="['lencana', 'w-' + warna(r.persen)]">{{ persen(r.persen) }}</span></td>
              <td class="p-2"><button class="tombol-teks text-sm" @click="laporanIndividu(r)"><PhPrinter :size="18" weight="duotone" /> Laporan</button>
                <button class="tombol-teks text-sm" @click="tabelCeklist(r)"><PhTable :size="18" weight="duotone" /> Tabel ceklist</button></td>
            </tr>
          </tbody>
        </table>
      </div>
      <ul class="space-y-2 lg:hidden">
        <li v-for="r in tampil" :key="r.employee_id" :class="['kartu p-3.5', 'w-' + warna(r.persen)]">
          <div class="flex items-start gap-2"><p class="min-w-0 flex-1 font-semibold">{{ r.nama }}</p><span class="lencana">{{ persen(r.persen) }}</span></div>
          <p class="text-xs text-teks3">{{ r.unit }}</p>
          <p class="mt-1 text-sm text-teks2">{{ r.hari_terisi }} dari {{ r.hari_wajib }} hari terisi · {{ r.hari_kosong }} tidak diisi · {{ r.kegiatan_disetujui }} kegiatan disetujui</p>
          <div class="mt-2 flex flex-wrap gap-2"><button class="tombol-garis min-h-[40px] text-sm" @click="laporanIndividu(r)"><PhPrinter :size="18" weight="duotone" /> Laporan jurnal</button>
            <button class="tombol-garis min-h-[40px] text-sm" @click="tabelCeklist(r)"><PhTable :size="18" weight="duotone" /> Tabel ceklist</button></div>
        </li>
      </ul>
      <p v-if="!tampil.length" class="py-8 text-center text-teks3">Tidak ada data yang sesuai.</p>
    </template>

    <DokumenCetak v-model:pratinjau="pratinjau" mendatar judul="Rekap Pengisian Jurnal Harian Pegawai" :subjudul="`${formatPanjang(mulai)} s.d. ${formatPanjang(akhir)} · ${namaUnit}`" :pencetak="sesi.pengguna?.nama_lengkap">
      <table class="tabel">
        <colgroup><col style="width:4%"><col style="width:24%"><col style="width:16%"><col v-for="n in 7" :key="n" style="width:8%"></colgroup>
        <thead><tr><th>No.</th><th>Nama</th><th>Bidang/Unit</th><th>Hari wajib</th><th>Hari terisi</th><th>Tidak diisi</th><th>Butir ceklist</th><th>Kegiatan disetujui</th><th>Menunggu verval</th><th>Pengisian (%)</th></tr></thead>
        <tbody><tr v-for="(r, i) in tampil" :key="r.employee_id">
          <td class="tengah">{{ i + 1 }}</td><td>{{ r.nama }}</td><td>{{ r.unit }}</td><td class="tengah">{{ r.hari_wajib }}</td><td class="tengah">{{ r.hari_terisi }}</td>
          <td class="tengah">{{ r.hari_kosong }}</td><td class="tengah">{{ r.butir }}</td><td class="tengah">{{ r.kegiatan_disetujui }}</td><td class="tengah">{{ r.kegiatan_menunggu }}</td><td class="tengah">{{ persen(r.persen) }}</td></tr></tbody>
      </table>
      <p style="margin-top: 6pt">Rata-rata pengisian: {{ persen(total) }}. Pengisian = hari terisi ÷ hari wajib jurnal.</p>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan_tertulis || 'Direktur', nama: direktur.nama || '', niy: direktur.niy }" :kanan="{ jabatan: 'Pembuat Rekap', nama: sesi.pengguna?.nama_lengkap || '' }" />
      </template>
    </DokumenCetak>

    <DokumenCetak v-if="individu" v-model:pratinjau="pratinjauInd" judul="Laporan Jurnal Harian Pegawai" :subjudul="`${formatPanjang(mulai)} s.d. ${formatPanjang(akhir)}`" :pencetak="sesi.pengguna?.nama_lengkap">
      <table class="data" style="margin-bottom: 8pt">
        <tbody>
          <tr><td style="width: 32mm">Nama</td><td style="width: 4mm">:</td><td>{{ individu.r.nama }}</td></tr>
          <tr><td>NIY</td><td>:</td><td>{{ individu.r.niy || '–' }}</td></tr>
          <tr><td>Bidang/Unit</td><td>:</td><td>{{ individu.r.unit || '–' }}</td></tr>
          <tr><td>Pengisian</td><td>:</td><td>{{ individu.r.hari_terisi }} dari {{ individu.r.hari_wajib }} hari wajib ({{ persen(individu.r.persen) }})</td></tr>
        </tbody>
      </table>
      <table class="tabel">
        <colgroup><col style="width:7%"><col style="width:19%"><col style="width:40%"><col style="width:34%"></colgroup>
        <thead><tr><th>No.</th><th>Hari, tanggal</th><th>Ceklist tugas</th><th>Kegiatan tambahan</th></tr></thead>
        <tbody>
          <tr v-for="(d, i) in individu.hari" :key="d.tanggal">
            <td class="tengah">{{ i + 1 }}</td><td>{{ formatHari(d.tanggal) }}</td>
            <td><template v-if="d.butir.length">{{ d.butir.map((b) => b.uraian + (b.catatan ? ` (${b.catatan})` : '')).join('; ') }}</template>
              <template v-else>{{ d.wajib ? (d.terkunci && !d.kegiatan.length ? 'Tidak diisi' : '–') : 'Bukan hari wajib' }}</template></td>
            <td>{{ d.kegiatan.map((k) => `${jam(k.jam_mulai)}–${jam(k.jam_selesai)} ${k.uraian} [${STATUS[k.status]}]`).join('; ') || '–' }}</td>
          </tr>
        </tbody>
      </table>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: 'Atasan Langsung', nama: '.....................................' }" :kanan="{ jabatan: 'Pegawai', nama: individu.r.nama, niy: individu.r.niy }" />
      </template>
    </DokumenCetak>

    <!-- Tabel ceklist bulanan (F4 mendatar) -->
    <DokumenCetak v-if="matriks" v-model:pratinjau="pratinjauM" mendatar judul="Tabel Ceklist Jurnal Harian Pegawai" :subjudul="`${formatPanjang(mulai)} s.d. ${formatPanjang(akhir)}`" :pencetak="sesi.pengguna?.nama_lengkap">
      <table class="data" style="margin-bottom: 6pt">
        <tbody>
          <tr><td style="width: 30mm">Nama</td><td style="width: 4mm">:</td><td>{{ matriks.r.nama }}</td><td style="width: 30mm">Bidang/Unit</td><td style="width: 4mm">:</td><td>{{ matriks.r.unit || '–' }}</td></tr>
          <tr><td>NIY</td><td>:</td><td>{{ matriks.r.niy || '–' }}</td><td>Hari wajib</td><td>:</td><td>{{ matriks.wajib }} hari</td></tr>
        </tbody>
      </table>
      <table class="tabel kecil matriks-cetak">
        <colgroup><col style="width:3%"><col style="width:33%"><col v-for="h in matriks.hari" :key="h.tanggal" :style="{ width: lebarTgl }"><col style="width:6%"></colgroup>
        <thead><tr><th>No.</th><th>Kegiatan/butir ceklist</th><th v-for="h in matriks.hari" :key="h.tanggal" :style="!h.wajib ? 'background:#e6e6e6' : ''">{{ Number(h.tanggal.slice(8)) }}</th><th>Jml.</th></tr></thead>
        <tbody>
          <template v-for="(b, i) in matriks.butir" :key="b.item_id">
            <tr v-if="i === 0 || matriks.butir[i - 1].kelompok !== b.kelompok"><td :colspan="matriks.hari.length + 3" style="font-style: italic">{{ b.kelompok }}</td></tr>
            <tr><td class="tengah">{{ i + 1 }}</td><td>{{ b.uraian }}</td>
              <td v-for="(v, j) in b.hari" :key="j" class="tengah" :style="!matriks.hari[j].wajib ? 'background:#f0f0f0' : ''">{{ v ? '✓' : '' }}</td><td class="tengah">{{ b.n }}</td></tr>
          </template>
          <tr v-if="!matriks.butir.length"><td :colspan="matriks.hari.length + 3" class="tengah">Belum ada butir ceklist template untuk pegawai ini.</td></tr>
        </tbody>
      </table>
      <p style="margin-top: 4pt; font-size: 8.5pt">✓ = butir dikerjakan (dicentang) pada tanggal itu. Kolom berarsir = bukan hari wajib (libur atau izin/sakit/cuti yang disetujui).</p>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: 'Atasan Langsung', nama: '.....................................' }" :kanan="{ jabatan: 'Pegawai', nama: matriks.r.nama, niy: matriks.r.niy }" />
      </template>
    </DokumenCetak>
  </div>
</template>
