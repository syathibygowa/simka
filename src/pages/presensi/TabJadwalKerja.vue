<!-- SIMKA PRO | src/pages/presensi/TabJadwalKerja.vue | v1.1 | 14.13.0: teks keterangan dihapus, saringan corong di HP | 19/10/2026 -->
<script setup>
// Penjadwalan → Jadwal kerja: jam presensi setiap pegawai per hari dalam satu pekan, persis seperti yang dibaca sistem
// (pola dan sesi aktif, sesi yang dipegang, jadwal shift, dan hari libur). Saring putra/putri, bidang/unit, pola, dan nama;
// pilihan menampilkan batas absen (buka · tepat waktu · tutup). Cetak F4 mendatar dengan kop dan tanda tangan.
import { ref, computed, watch, onMounted } from 'vue'
import { PhCaretLeft, PhCaretRight, PhPrinter, PhMagnifyingGlass, PhUsersThree, PhCalendarCheck, PhWarningCircle, PhClockCountdown, PhUserCircle, PhGenderMale, PhGenderFemale, PhFileXls } from '@phosphor-icons/vue'
import * as XLSX from 'xlsx'
import { useAturPresensi } from '@/stores/aturPresensi'
import { useOrganisasi } from '@/stores/organisasi'
import { useLembaga } from '@/stores/lembaga'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { hariIniISO, formatPanjang, formatPendek } from '@/lib/tanggal'
import { seninDari, tambahHari } from '@/lib/shift'
import { HARI_PENUH, HARI_SINGKAT } from '@/lib/presensi'
import KartuStatistik from '@/components/KartuStatistik.vue'
import SaringCorong from '@/components/SaringCorong.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const atur = useAturPresensi(); const org = useOrganisasi(); const lembaga = useLembaga(); const sesi = useSesi(); const ui = useUI()
const senin = ref(seninDari(hariIniISO())); const data = ref(null); const memuat = ref(false); const galat = ref('')
const jk = ref(''); const unit = ref(''); const pola = ref(''); const cari = ref(''); const rinci = ref(false); const pratinjau = ref(false)

async function muat() {
  memuat.value = true; galat.value = ''
  try { data.value = await atur.jadwalKerja(senin.value) } catch (e) { galat.value = e.message } finally { memuat.value = false }
}
onMounted(() => { org.units.length || org.muat(); muat() })
watch(senin, muat)

const tanggal = computed(() => Array.from({ length: 7 }, (_, i) => tambahHari(senin.value, i)))
const hariIni = hariIniISO()
const dow = (t) => new Date(t + 'T00:00:00Z').getUTCDay()
const libur = computed(() => Object.fromEntries((data.value?.libur || []).map((l) => [l.t, l.nama || 'Libur'])))
const daftarPola = computed(() => [...new Set((data.value?.pegawai || []).flatMap((p) => p.pola))].sort())
const unitTerpilih = computed(() => (unit.value ? org.turunan(unit.value) : null))

const tampil = computed(() => {
  const q = cari.value.trim().toLowerCase()
  return (data.value?.pegawai || []).filter((p) => (!jk.value || p.jk === jk.value)
    && (!unitTerpilih.value || unitTerpilih.value.has(p.unit_id))
    && (!pola.value || p.pola.includes(pola.value))
    && (!q || [p.nama, p.niy, p.unit].join(' ').toLowerCase().includes(q)))
})
const jumlahSesi = (p) => p.hari.reduce((t, h) => t + h.sesi.length, 0)
const statistik = computed(() => {
  const n = tampil.value.length; const berjadwal = tampil.value.filter((p) => jumlahSesi(p) > 0).length
  return [
    { k: 'n', judul: 'Pegawai ditampilkan', nilai: n, ikon: PhUsersThree, warna: 'pegawai', ket: jk.value === 'L' ? 'Putra' : jk.value === 'P' ? 'Putri' : 'Putra dan putri' },
    { k: 'b', judul: 'Berjadwal pekan ini', nilai: berjadwal, ikon: PhCalendarCheck, warna: 'presensi', ket: n ? `${Math.round((berjadwal * 100) / n)}% pegawai` : '–' },
    { k: 't', judul: 'Tanpa jadwal', nilai: n - berjadwal, ikon: PhWarningCircle, warna: 'klinik', ket: n - berjadwal ? 'Periksa tab Jadwal pegawai' : 'Semua sudah berjadwal' },
    { k: 's', judul: 'Sesi presensi', nilai: tampil.value.reduce((t, p) => t + jumlahSesi(p), 0), ikon: PhClockCountdown, warna: 'tahfizh', ket: 'Selama 7 hari' },
  ]
})
const teksSesi = (s) => `${s.mulai}${s.pulang ? '–' + s.selesai : ''}`
const teksBatas = (s) => `buka ${s.buka} · tepat ${s.tepat} · tutup ${s.tutup}`
const judulFilter = computed(() => [jk.value === 'L' ? 'Putra' : jk.value === 'P' ? 'Putri' : '', unit.value ? org.cariUnit(unit.value)?.nama : '', pola.value].filter(Boolean).join(' · '))
const direktur = computed(() => lembaga.signatories.find((s) => /^direktur$/i.test(s.jabatan_tertulis)) || lembaga.signatories[0] || {})

function ekspor() {
  const kepala = ['No.', 'NIY', 'Nama', 'L/P', 'Bidang/unit', ...tanggal.value.map((t) => `${HARI_PENUH[dow(t)]} ${formatPendek(t)}`)]
  const baris = tampil.value.map((p, i) => [i + 1, p.niy || '', p.nama, p.jk || '', p.unit || '',
    ...p.hari.map((h) => (h.sesi.length ? h.sesi.map((s) => `${s.sesi} ${teksSesi(s)}${rinci.value ? ` (${teksBatas(s)})` : ''}`).join('; ') : libur.value[h.t] ? 'Libur' : '–'))])
  const ws = XLSX.utils.aoa_to_sheet([kepala, ...baris]); ws['!cols'] = [{ wch: 5 }, { wch: 12 }, { wch: 30 }, { wch: 5 }, { wch: 20 }, ...tanggal.value.map(() => ({ wch: 24 }))]
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Jadwal kerja')
  XLSX.writeFile(wb, `Jadwal-Kerja-Pegawai-${formatPendek(senin.value).replace(/\//g, '-')}.xlsx`)
  ui.toast('Berkas Excel diunduh.')
}
</script>
<template>
  <div class="space-y-4">
    <!-- Navigasi pekan -->
    <div class="kartu flex flex-wrap items-center gap-2 p-2.5">
      <button class="tombol-ikon" aria-label="Pekan sebelumnya" @click="senin = tambahHari(senin, -7)"><PhCaretLeft :size="22" /></button>
      <div class="min-w-0 flex-1 text-center">
        <p class="font-bold">{{ formatPanjang(senin) }} – {{ formatPanjang(tambahHari(senin, 6)) }}</p>
        <button v-if="senin !== seninDari(hariIni)" type="button" class="text-xs font-semibold text-merah" @click="senin = seninDari(hariIni)">Kembali ke pekan ini</button>
        <p v-else class="text-xs text-teks3">Pekan ini</p>
      </div>
      <button class="tombol-ikon" aria-label="Pekan berikutnya" @click="senin = tambahHari(senin, 7)"><PhCaretRight :size="22" /></button>
    </div>

    <!-- Saringan -->
    <div class="kartu space-y-3 p-4">
      <div class="bilah-tab kecil" role="tablist" aria-label="Jenis kelamin">
        <button v-for="x in [{ k: '', n: 'Semua', i: PhUsersThree }, { k: 'L', n: 'Putra', i: PhGenderMale }, { k: 'P', n: 'Putri', i: PhGenderFemale }]" :key="x.k" type="button" role="tab"
          :aria-selected="jk === x.k" :class="['tab-garis', jk === x.k && 'aktif']" @click="jk = x.k"><component :is="x.i" :size="18" weight="duotone" /><span>{{ x.n }}</span></button>
      </div>
      <SaringCorong :jumlah="[unit, pola].filter(Boolean).length" :ringkasan="[org.units.find((u) => u.id === unit)?.nama, pola].filter(Boolean).join(' · ')" judul="Saring jadwal kerja">
        <template #cari><div class="relative"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-teks3" />
            <input id="jk-cari" v-model="cari" type="search" class="isian pl-10" placeholder="Cari nama, NIY, atau bidang" aria-label="Cari pegawai" /></div></template>
        <div><label class="label-isian" for="jk-unit">Bidang/unit</label>
          <select id="jk-unit" v-model="unit" class="isian w-auto max-w-full"><option value="">Semua bidang/unit</option>
            <option v-for="u in org.datar" :key="u.id" :value="u.id">{{ '— '.repeat(u.tingkat) }}{{ u.nama }}</option></select></div>
        <div><label class="label-isian" for="jk-pola">Pola presensi</label>
          <select id="jk-pola" v-model="pola" class="isian w-auto max-w-full"><option value="">Semua pola</option><option v-for="p in daftarPola" :key="p" :value="p">{{ p }}</option></select></div>
      </SaringCorong>
      <div class="flex flex-wrap items-center gap-2">
        <label class="flex min-h-[44px] items-center gap-2 text-sm font-semibold text-teks2"><input v-model="rinci" type="checkbox" class="h-5 w-5 accent-[#C7332F]" /> Tampilkan batas absen (buka · tepat waktu · tutup)</label>
        <span class="flex-1" />
        <button class="tombol-garis min-h-[42px] px-3.5 text-sm" :disabled="!tampil.length" @click="ekspor"><PhFileXls :size="18" weight="duotone" /> Ekspor</button>
        <button class="tombol-utama min-h-[42px] px-4 text-sm" :disabled="!tampil.length" @click="pratinjau = true"><PhPrinter :size="18" weight="duotone" /> Cetak jadwal</button>
      </div>
    </div>

    <p v-if="galat" class="kartu p-4 text-sm font-semibold text-merah" role="alert">{{ galat }} Pastikan migrasi SQL 10500 sudah dijalankan.</p>
    <div v-if="memuat && !data" class="kartu h-40 animate-pulse" aria-busy="true" />

    <template v-if="data">
      <section class="grid grid-cols-2 gap-3 lg:grid-cols-4" aria-label="Ringkasan">
        <KartuStatistik v-for="x in statistik" :key="x.k" :judul="x.judul" :nilai="x.nilai" :ikon="x.ikon" :warna="x.warna" :keterangan="x.ket" />
      </section>

      <!-- Desktop: tabel -->
      <div class="kartu hidden overflow-x-auto lg:block">
        <table class="w-full min-w-[1180px] text-sm">
          <thead><tr class="border-b border-garis text-left">
            <th class="w-[96px] p-3">NIY</th><th class="w-[190px] p-3">Nama</th><th class="w-12 p-3 text-center">L/P</th>
            <th v-for="t in tanggal" :key="t" :class="['p-3 text-center', t === hariIni && 'hari-ini', libur[t] && 'hari-libur']">
              {{ HARI_PENUH[dow(t)] }}<span class="block text-xs font-normal text-teks3">{{ formatPendek(t) }}</span>
              <span v-if="libur[t]" class="block text-[11px] font-semibold text-[#B42A5E] dark:text-[#FF8FB8]" :title="libur[t]">Libur</span></th>
          </tr></thead>
          <tbody>
            <tr v-for="p in tampil" :key="p.id" class="border-b border-garis/70 align-top last:border-0">
              <td class="p-3 tabular-nums text-teks2">{{ p.niy || '–' }}</td>
              <td class="p-3"><span class="font-semibold">{{ p.nama }}</span><span class="block text-xs text-teks3">{{ p.unit || 'Tanpa bidang/unit' }}<template v-if="p.pola.length"> · {{ p.pola.join(', ') }}</template></span></td>
              <td class="p-3 text-center">{{ p.jk || '–' }}</td>
              <td v-for="h in p.hari" :key="h.t" :class="['p-2 text-center', h.t === hariIni && 'hari-ini']">
                <span v-if="!h.sesi.length" class="text-teks3">{{ libur[h.t] ? 'Libur' : '–' }}</span>
                <span v-for="(s, i) in h.sesi" :key="i" :class="['sesi mb-1 block rounded-lg px-1.5 py-1 text-xs', 'w-' + (s.warna || 'presensi'), s.opsional && 'opacity-70']" :title="`${s.pola} · ${s.sesi} · ${teksBatas(s)}`">
                  <b class="block tabular-nums">{{ teksSesi(s) }}</b><span class="block truncate text-teks2">{{ s.sesi }}</span>
                  <span v-if="rinci" class="block text-[10.5px] tabular-nums text-teks3">{{ teksBatas(s) }}</span></span>
              </td>
            </tr>
            <tr v-if="!tampil.length"><td :colspan="10" class="p-8 text-center text-teks3">Tidak ada pegawai sesuai saringan.</td></tr>
          </tbody>
        </table>
      </div>

      <!-- HP: kartu per pegawai -->
      <ul class="space-y-3 lg:hidden">
        <li v-for="p in tampil" :key="p.id" class="kartu p-4">
          <div class="flex items-center gap-3">
            <span class="chip-ikon w-pegawai h-10 w-10"><PhUserCircle :size="22" weight="duotone" /></span>
            <div class="min-w-0"><p class="truncate font-semibold">{{ p.nama }}</p><p class="truncate text-xs text-teks3">{{ p.niy ? 'NIY ' + p.niy + ' · ' : '' }}{{ p.jk || '' }} · {{ p.unit || 'Tanpa bidang/unit' }}</p></div>
          </div>
          <ul class="mt-3 divide-y divide-garis/70">
            <li v-for="h in p.hari" :key="h.t" class="flex items-start gap-3 py-2">
              <span :class="['w-12 shrink-0 text-sm font-semibold', h.t === hariIni && 'text-merah']">{{ HARI_SINGKAT[dow(h.t)] }}</span>
              <span class="flex min-w-0 flex-1 flex-wrap gap-1.5">
                <span v-if="!h.sesi.length" class="text-sm text-teks3">{{ libur[h.t] ? 'Libur – ' + libur[h.t] : 'Tidak ada sesi' }}</span>
                <span v-for="(s, i) in h.sesi" :key="i" :class="['sesi rounded-lg px-2 py-1 text-xs', 'w-' + (s.warna || 'presensi')]">
                  <b class="tabular-nums">{{ teksSesi(s) }}</b> {{ s.sesi }}<span v-if="rinci" class="block text-[11px] tabular-nums text-teks3">{{ teksBatas(s) }}</span></span>
              </span>
            </li>
          </ul>
        </li>
        <li v-if="!tampil.length" class="kartu p-8 text-center text-sm text-teks3">Tidak ada pegawai sesuai saringan.</li>
      </ul>
    </template>

    <DokumenCetak v-model:pratinjau="pratinjau" mendatar judul="Jadwal Kerja Pegawai" :nama-berkas="`Jadwal-Kerja-Pegawai-${formatPendek(senin).replace(/\//g, '-')}`"
      :subjudul="`Pekan ${formatPanjang(senin)} s.d. ${formatPanjang(tambahHari(senin, 6))}${judulFilter ? ' · ' + judulFilter : ''}`" :pencetak="sesi.pengguna?.nama_lengkap">
      <table class="tabel">
        <colgroup><col style="width:3%"><col style="width:9%"><col style="width:17%"><col style="width:3%"><col v-for="t in tanggal" :key="t" style="width:9.71%"></colgroup>
        <thead><tr><th>No.</th><th>NIY</th><th>Nama</th><th>L/P</th>
          <th v-for="t in tanggal" :key="t">{{ HARI_PENUH[dow(t)] }}<br>{{ formatPendek(t) }}<template v-if="libur[t]"><br>(Libur)</template></th></tr></thead>
        <tbody><tr v-for="(p, i) in tampil" :key="p.id">
          <td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ p.niy || '–' }}</td><td>{{ p.nama }}</td><td class="tengah">{{ p.jk || '–' }}</td>
          <td v-for="h in p.hari" :key="h.t" class="tengah">
            <template v-if="h.sesi.length"><div v-for="(s, j) in h.sesi" :key="j">{{ teksSesi(s) }} {{ s.sesi }}<template v-if="rinci"><br><small>{{ teksBatas(s) }}</small></template></div></template>
            <template v-else>{{ libur[h.t] ? 'Libur' : '–' }}</template>
          </td>
        </tr></tbody>
      </table>
      <p style="margin-top: 6pt; font-size: 9pt">Jam = mulai–selesai sesi presensi; "buka" = absen mulai dapat dilakukan, "tepat" = batas tepat waktu, "tutup" = batas akhir absen datang.</p>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan_tertulis || 'Direktur', nama: direktur.nama || '', niy: direktur.niy }"
          :kanan="{ jabatan: 'Penyusun Jadwal', nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
      </template>
    </DokumenCetak>
  </div>
</template>
<style scoped>
.sesi { color: rgb(var(--teks)); background: color-mix(in srgb, var(--c) 14%, rgb(var(--permukaan))); border-left: 3px solid var(--c); text-align: left; }
.hari-ini { background: color-mix(in srgb, #C7332F 6%, transparent); }
th.hari-libur { background: color-mix(in srgb, #B42A5E 8%, transparent); }
</style>
