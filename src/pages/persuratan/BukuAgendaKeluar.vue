<!-- SIMKA PRO | src/pages/persuratan/BukuAgendaKeluar.vue | v1.3 | Perbaikan 13.5.0: tab bergaris bawah | 15/10/2026 -->
<script setup>
// Buku agenda surat keluar = inventaris SEMUA surat yang terbit di SIMKA PRO per rentang tanggal surat:
//   Persuratan (surat Tata Usaha, termasuk yang dicabut/direvisi), surat pengajuan pegawai, surat keterangan sakit (Klinik),
//   surat keterangan pindah santri, dan laporan resmi bertanda tangan. Saring per sumber, cari, klik baris untuk membuka
//   surat di tempat asalnya (revisi surat Persuratan dari rinciannya; surat modul lain diperbarui di modulnya).
//   Tabel (kartu di ponsel), Excel, cetak F4 mendatar.
import { ref, computed, watch } from 'vue'
import { useRouter } from 'vue-router'
import * as XLSX from 'xlsx'
import { PhEye, PhDownloadSimple, PhMagnifyingGlass, PhArrowSquareOut, PhEnvelopeSimple, PhFileText, PhFirstAid, PhStudent, PhChartBar } from '@phosphor-icons/vue'
import { usePersuratan } from '@/stores/persuratan'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { STATUS_KELUAR } from '@/lib/suratKeluar'
import { formatPanjang, formatPendek, hariIniISO } from '@/lib/tanggal'
import { ambilPenandaTangan } from '@/lib/penandatangan'
import InputTanggal from '@/components/InputTanggal.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const ps = usePersuratan(); const sesi = useSesi(); const ui = useUI(); const router = useRouter()
const mulai = ref(hariIniISO().slice(0, 8) + '01'); const selesai = ref(hariIniISO()); const baris = ref([]); const memuat = ref(false); const pratinjau = ref(false)
const sumber = ref('semua'); const cari = ref('')
const direktur = ref({ jabatan: 'Direktur', nama: '', niy: '' })
ambilPenandaTangan('Direktur').then((d) => { direktur.value = d }).catch(() => {})
async function muat() {
  memuat.value = true
  try { baris.value = await ps.bukuAgendaKeluar(mulai.value, selesai.value) } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
watch([mulai, selesai], muat, { immediate: true })

const SUMBER = [
  { k: 'tu', n: 'Persuratan', ikon: PhEnvelopeSimple, w: 'tatausaha' },
  { k: 'pengajuan', n: 'Pengajuan pegawai', ikon: PhFileText, w: 'pengajuan' },
  { k: 'klinik', n: 'Klinik', ikon: PhFirstAid, w: 'klinik' },
  { k: 'santri', n: 'Data santri', ikon: PhStudent, w: 'santri' },
  { k: 'laporan', n: 'Dokumen resmi', ikon: PhChartBar, w: 'rekap' },
]
const infoSumber = (k) => SUMBER.find((x) => x.k === k) || SUMBER[0]
const jumlah = computed(() => Object.fromEntries(SUMBER.map((x) => [x.k, baris.value.filter((r) => (r.sumber || 'tu') === x.k).length])))
const tampil = computed(() => {
  const t = cari.value.trim().toLowerCase()
  return baris.value.filter((r) => (sumber.value === 'semua' || (r.sumber || 'tu') === sumber.value)
    && (!t || [r.nomor, r.jenis_nama, r.perihal, r.kepada, r.penanda, r.kode_validasi, r.pemohon].join(' ').toLowerCase().includes(t)))
})
const periode = computed(() => `Tanggal surat ${formatPanjang(mulai.value)} s.d. ${formatPanjang(selesai.value)}`
  + (sumber.value === 'semua' ? '' : ` · Sumber: ${infoSumber(sumber.value).n}`))
const tujuan = (r) => String(r.kepada || '–').split('\n').join(', ')
const ttd = (r) => (r.mode_ttd === 'basah' ? 'Basah' : 'Elektronik')
const statusN = (r) => (STATUS_KELUAR[r.status]?.n || r.status) + (Number(r.revisi_ke) ? ` (revisi ke-${r.revisi_ke})` : '')
function buka(r) { if (r.tautan) router.push(r.tautan); else ui.toast('Surat ini tidak memiliki halaman asal.') }

function ekspor() {
  const kolom = ['Sumber', 'Nomor Surat', 'Tanggal Surat', 'Jenis Surat', 'Perihal', 'Kepada/Subjek', 'Penanda Tangan', 'Tanda Tangan', 'Kode Validasi', 'Penyusun', 'Pemohon', 'Status']
  const isi = tampil.value.map((r) => [r.sumber_nama || 'Persuratan', r.nomor || '', formatPendek(r.tanggal_surat), r.jenis_nama, r.perihal, tujuan(r), r.penanda || '', ttd(r),
    r.kode_validasi || '', r.disusun_oleh || '', r.pemohon || '', statusN(r)])
  const ws = XLSX.utils.aoa_to_sheet([['Buku Agenda Surat Keluar'], [periode.value], [], kolom, ...isi])
  ws['!cols'] = [18, 28, 12, 26, 40, 30, 30, 12, 12, 26, 26, 18].map((w) => ({ wch: w }))
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Surat Keluar'); XLSX.writeFile(wb, `Buku-Agenda-Surat-Keluar-${mulai.value}-${selesai.value}.xlsx`)
}
</script>
<template>
  <div>
    <div class="kartu mb-3 grid grid-cols-2 gap-3 p-4 sm:grid-cols-[1fr_1fr_1.4fr_auto]">
      <InputTanggal v-model="mulai" label="Tanggal surat dari" wajib /><InputTanggal v-model="selesai" label="Sampai" wajib />
      <div class="col-span-2 sm:col-span-1"><label class="label-isian" for="bak-cari">Cari</label>
        <div class="relative"><PhMagnifyingGlass :size="18" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-teks3" />
          <input id="bak-cari" v-model="cari" class="isian pl-10" placeholder="Nomor, perihal, nama, kode" /></div></div>
      <div class="col-span-2 flex items-end gap-2 sm:col-span-1">
        <button class="tombol-garis w-pengajuan min-h-[44px] px-3 text-sm" :disabled="!tampil.length" @click="pratinjau = true"><PhEye :size="18" style="color: var(--c)" /> Cetak</button>
        <button class="tombol-garis w-santri min-h-[44px] px-3 text-sm" :disabled="!tampil.length" @click="ekspor"><PhDownloadSimple :size="18" style="color: var(--c)" /> Excel</button>
      </div>
    </div>

    <div class="bilah-tab kecil mb-3" role="tablist" aria-label="Sumber surat">
      <button type="button" role="tab" :aria-selected="sumber === 'semua'" :class="['tab-garis w-sistem', sumber === 'semua' && 'aktif']" @click="sumber = 'semua'">
        <span>Semua</span> <span class="angka-tab">{{ baris.length }}</span></button>
      <button v-for="x in SUMBER" :key="x.k" type="button" role="tab" :aria-selected="sumber === x.k" :class="['tab-garis', 'w-' + x.w, sumber === x.k && 'aktif']" @click="sumber = x.k">
        <component :is="x.ikon" :size="18" weight="duotone" /><span>{{ x.n }}</span> <span class="angka-tab">{{ jumlah[x.k] }}</span></button>
    </div>

    <!-- Ponsel: kartu -->
    <ul class="space-y-2 sm:hidden">
      <li v-for="(r, i) in tampil" :key="(r.sumber || 'tu') + r.id + i">
        <button type="button" :class="['kartu w-full p-3 text-left', 'w-' + infoSumber(r.sumber).w, r.status !== 'terbit' && 'opacity-70']" @click="buka(r)">
          <span class="flex items-center gap-2 text-xs text-teks3"><component :is="infoSumber(r.sumber).ikon" :size="16" weight="duotone" style="color: var(--c)" />
            {{ r.sumber_nama || 'Persuratan' }} · {{ formatPendek(r.tanggal_surat) }}
            <span class="lencana ml-auto" :class="'w-' + (STATUS_KELUAR[r.status]?.w || 'sistem')">{{ statusN(r) }}</span></span>
          <b class="mt-1 block leading-snug [overflow-wrap:anywhere]">{{ r.perihal }}</b>
          <span class="block text-xs text-teks2">{{ r.jenis_nama }}<template v-if="r.nomor"> · <span class="tabular-nums">{{ r.nomor }}</span></template></span>
          <span class="block text-xs text-teks3">{{ tujuan(r) }}</span>
        </button>
      </li>
    </ul>

    <!-- Desktop: tabel -->
    <div class="kartu hidden overflow-x-auto sm:block">
      <table class="w-full min-w-[900px] text-left text-sm">
        <thead class="border-b border-garis bg-permukaan2 text-teks2"><tr>
          <th class="px-3 py-2.5 font-bold">Sumber</th><th class="px-3 py-2.5 font-bold">Nomor surat</th><th class="px-3 py-2.5 font-bold">Tanggal</th><th class="px-3 py-2.5 font-bold">Jenis dan perihal</th>
          <th class="px-3 py-2.5 font-bold">Kepada/subjek</th><th class="px-3 py-2.5 font-bold">Penanda tangan</th><th class="px-3 py-2.5 font-bold">Status</th><th class="w-10 px-2" /></tr></thead>
        <tbody class="divide-y divide-garis">
          <tr v-for="(r, i) in tampil" :key="(r.sumber || 'tu') + r.id + i" :class="['cursor-pointer hover:bg-permukaan2', r.status !== 'terbit' && 'opacity-70']"
            tabindex="0" @click="buka(r)" @keyup.enter="buka(r)">
            <td class="px-3 py-2" :class="'w-' + infoSumber(r.sumber).w"><span class="flex items-center gap-1.5 whitespace-nowrap">
              <component :is="infoSumber(r.sumber).ikon" :size="18" weight="duotone" style="color: var(--c)" /> {{ r.sumber_nama || 'Persuratan' }}</span></td>
            <td class="px-3 py-2 tabular-nums">{{ r.nomor || '–' }}</td><td class="px-3 py-2 tabular-nums">{{ formatPendek(r.tanggal_surat) }}</td>
            <td class="px-3 py-2">{{ r.perihal }}<span class="block text-xs text-teks3">{{ r.jenis_nama }}</span></td>
            <td class="px-3 py-2">{{ tujuan(r) }}</td>
            <td class="px-3 py-2">{{ r.penanda || '–' }}<span class="block text-xs text-teks3">{{ ttd(r) }}{{ r.kode_validasi ? ' · ' + r.kode_validasi : '' }}</span></td>
            <td class="px-3 py-2"><span class="lencana" :class="'w-' + (STATUS_KELUAR[r.status]?.w || 'sistem')">{{ statusN(r) }}</span></td>
            <td class="px-2 text-teks3"><PhArrowSquareOut :size="18" :aria-label="`Buka ${r.perihal}`" /></td>
          </tr>
        </tbody>
      </table>
    </div>
    <p v-if="!tampil.length" class="kartu py-8 text-center text-sm text-teks3">{{ memuat ? 'Memuat…' : 'Belum ada surat terbit pada rentang dan sumber ini.' }}</p>
    <p class="mt-3 text-xs text-teks3">Surat dari Persuratan direvisi melalui rinciannya (tombol Revisi surat). Surat dari modul lain dibuka dan diperbarui di modul asalnya;
      dokumen penggantinya otomatis tercatat di sini.</p>

    <DokumenCetak kop="pondok" judul="Buku Agenda Surat Keluar" :subjudul="periode" v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap" mendatar>
      <table class="tabel kecil">
        <colgroup><col style="width: 4%" /><col style="width: 10%" /><col style="width: 15%" /><col style="width: 7%" /><col style="width: 22%" /><col style="width: 15%" />
          <col style="width: 14%" /><col style="width: 7%" /><col style="width: 6%" /></colgroup>
        <thead><tr><th>No.</th><th>Sumber</th><th>Nomor Surat</th><th>Tanggal</th><th>Jenis dan Perihal</th><th>Kepada/Subjek</th><th>Penanda Tangan</th><th>Kode Validasi</th><th>Status</th></tr></thead>
        <tbody>
          <tr v-for="(r, i) in tampil" :key="(r.sumber || 'tu') + r.id + i">
            <td class="tengah">{{ i + 1 }}</td><td>{{ r.sumber_nama || 'Persuratan' }}</td><td>{{ r.nomor || '–' }}</td><td class="tengah">{{ formatPendek(r.tanggal_surat) }}</td>
            <td>{{ r.jenis_nama }}: {{ r.perihal }}</td><td>{{ tujuan(r) }}</td><td>{{ r.penanda || '–' }} ({{ ttd(r).toLowerCase() }})</td>
            <td class="tengah">{{ r.kode_validasi || '–' }}</td><td>{{ statusN(r) }}</td>
          </tr>
        </tbody>
      </table>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan, nama: direktur.nama, niy: direktur.niy }"
          :kanan="{ jabatan: 'Petugas Tata Usaha', nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
      </template>
    </DokumenCetak>
  </div>
</template>
