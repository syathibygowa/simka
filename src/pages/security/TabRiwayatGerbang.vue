<!-- SIMKA PRO | src/pages/security/TabRiwayatGerbang.vue | v1.0 | Fase 7 – Tahap 1 Security: gerbang | 06/10/2026 -->
<script setup>
// Riwayat gerbang santri pada rentang tanggal (keluar, kembali, ditolak), saring jenis dan nama,
// unduh Excel, cetak F4 mendatar berkop (Mengetahui Kepala Bidang Kesantrian kiri, pembuat rekap kanan).
import { ref, computed, watch } from 'vue'
import * as XLSX from 'xlsx'
import { PhEye, PhDownloadSimple, PhMagnifyingGlass } from '@phosphor-icons/vue'
import { useSecurity } from '@/stores/security'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { JENIS_LOG, durasi } from '@/lib/security'
import { JENIS_IZIN } from '@/lib/izin'
import { penandaKelompok } from '@/lib/santri'
import { formatWaktu, formatPendek, formatJam, formatPanjang, hariIniISO } from '@/lib/tanggal'
import InputTanggal from '@/components/InputTanggal.vue'
import FotoBerkas from '@/components/FotoBerkas.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const sc = useSecurity(); const sesi = useSesi(); const ui = useUI()
const mulai = ref(hariIniISO().slice(0, 8) + '01'); const selesai = ref(hariIniISO()); const jenis = ref(''); const cari = ref('')
const daftar = ref([]); const memuat = ref(false); const pratinjau = ref(false)
const penanda = ref({ jabatan: 'Kepala Bidang Kesantrian', nama: '', niy: '' })
async function muat() {
  if (!mulai.value || !selesai.value) return
  memuat.value = true
  try { daftar.value = await sc.riwayat(mulai.value, selesai.value, jenis.value) } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
watch([mulai, selesai, jenis], muat, { immediate: true })
watch(pratinjau, async (v) => { if (v) penanda.value = await penandaKelompok({ jenis: 'kamar' }).catch(() => penanda.value) })
const tampil = computed(() => { const q = cari.value.toLowerCase().trim(); return daftar.value.filter((l) => !q || `${l.nama} ${l.nis} ${l.kelas || ''} ${l.kamar || ''}`.toLowerCase().includes(q)) })
const jumlah = (j) => tampil.value.filter((l) => l.jenis === j).length
const periode = computed(() => (mulai.value === selesai.value ? formatPanjang(mulai.value) : `${formatPanjang(mulai.value)} s.d. ${formatPanjang(selesai.value)}`))
const ket = (l) => [l.penjemput ? 'Penjemput ' + l.penjemput : '', l.terlambat_menit ? 'Terlambat ' + durasi(l.terlambat_menit) : '', l.catatan || ''].filter(Boolean).join('; ')

function ekspor() {
  const judul = ['No.', 'Tanggal', 'Jam', 'Kejadian', 'NIS', 'Nama santri', 'L/P', 'Kelas', 'Kamar', 'Jenis izin', 'Alasan izin', 'Batas kembali', 'Penjemput', 'Terlambat (menit)', 'Catatan', 'Petugas']
  const isi = tampil.value.map((l, i) => [i + 1, formatPendek(l.waktu), formatJam(l.waktu), JENIS_LOG[l.jenis].n, l.nis, l.nama, l.jenis_kelamin || '', l.kelas || '', l.kamar || '',
    l.jenis_izin ? JENIS_IZIN[l.jenis_izin] : '', l.alasan_izin || '', l.kembali_batas ? formatWaktu(l.kembali_batas) : '', l.penjemput || '', l.terlambat_menit ?? '', l.catatan || '', l.petugas || ''])
  const ws = XLSX.utils.aoa_to_sheet([[`Riwayat Gerbang Santri ${periode.value}`], [], judul, ...isi])
  ws['!cols'] = [5, 11, 7, 10, 10, 28, 5, 8, 18, 18, 30, 16, 22, 10, 30, 24].map((w) => ({ wch: w }))
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Gerbang'); XLSX.writeFile(wb, `Riwayat-Gerbang-${mulai.value}-${selesai.value}.xlsx`)
}
</script>
<template>
  <div>
    <div class="kartu grid grid-cols-2 gap-3 p-4 sm:grid-cols-[1fr_1fr_1fr_auto]">
      <InputTanggal v-model="mulai" label="Dari" wajib /><InputTanggal v-model="selesai" label="Sampai" wajib />
      <div><label class="label-isian" for="rg-j">Kejadian</label>
        <select id="rg-j" v-model="jenis" class="isian"><option value="">Semua</option><option value="keluar">Keluar</option><option value="kembali">Kembali</option><option value="ditolak">Ditolak</option></select></div>
      <div class="flex items-end gap-2">
        <button class="tombol-garis w-pengajuan min-h-[44px] px-3 text-sm" @click="pratinjau = true"><PhEye :size="18" style="color: var(--c)" /> Cetak</button>
        <button class="tombol-garis w-santri min-h-[44px] px-3 text-sm" @click="ekspor"><PhDownloadSimple :size="18" style="color: var(--c)" /> Excel</button>
      </div>
    </div>
    <div class="mt-3 flex flex-wrap items-center gap-2">
      <div class="relative min-w-[200px] flex-1"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
        <input v-model="cari" type="search" class="isian pl-11" placeholder="Saring nama, NIS, kelas, atau kamar" aria-label="Saring riwayat" /></div>
      <p class="text-sm text-teks2">{{ jumlah('keluar') }} keluar · {{ jumlah('kembali') }} kembali · {{ jumlah('ditolak') }} ditolak</p>
    </div>
    <div class="kartu mt-3 overflow-x-auto">
      <table class="w-full min-w-[760px] text-left text-sm">
        <thead class="border-b border-garis bg-permukaan2 text-teks2"><tr>
          <th class="px-3 py-2.5 font-bold">Waktu</th><th class="px-3 py-2.5 font-bold">Kejadian</th><th class="px-3 py-2.5 font-bold">Santri</th>
          <th class="px-3 py-2.5 font-bold">Keterangan</th><th class="px-3 py-2.5 font-bold">Petugas</th><th class="px-3 py-2.5 font-bold">Foto</th></tr></thead>
        <tbody class="divide-y divide-garis">
          <tr v-for="l in tampil" :key="l.id" :class="'w-' + JENIS_LOG[l.jenis].w">
            <td class="whitespace-nowrap px-3 py-2 tabular-nums">{{ formatWaktu(l.waktu) }}</td>
            <td class="px-3 py-2"><span class="lencana">{{ JENIS_LOG[l.jenis].n }}</span></td>
            <td class="px-3 py-2"><b>{{ l.nama }}</b><br /><span class="text-xs text-teks3">{{ l.nis }} · {{ l.kelas || '–' }} · {{ l.kamar || '–' }}</span></td>
            <td class="px-3 py-2 text-xs">{{ l.alasan_izin ? 'Izin: ' + l.alasan_izin : '' }}<br v-if="l.alasan_izin && ket(l)" />{{ ket(l) }}</td>
            <td class="px-3 py-2 text-xs">{{ l.petugas || '–' }}</td>
            <td class="px-3 py-2"><FotoBerkas v-if="l.foto_id" :id="l.foto_id" alt="Foto gerbang" ukuran="h-12 w-12" /></td>
          </tr>
        </tbody>
      </table>
      <p v-if="!tampil.length && !memuat" class="py-8 text-center text-sm text-teks3">Belum ada catatan gerbang pada rentang ini.</p>
    </div>

    <DokumenCetak kop="pondok" judul="Riwayat Gerbang Santri" :subjudul="'Periode ' + periode" v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap" mendatar>
      <p style="margin: 0 0 6pt">Jumlah: {{ jumlah('keluar') }} keluar, {{ jumlah('kembali') }} kembali, {{ jumlah('ditolak') }} ditolak di gerbang.</p>
      <table class="tabel kecil">
        <thead><tr><th style="width:4%">No.</th><th style="width:11%">Waktu</th><th style="width:7%">Kejadian</th><th style="width:19%">Nama santri</th><th style="width:6%">Kelas</th>
          <th style="width:11%">Kamar</th><th style="width:17%">Alasan izin</th><th>Keterangan</th><th style="width:12%">Petugas</th></tr></thead>
        <tbody>
          <tr v-for="(l, i) in tampil" :key="l.id"><td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ formatWaktu(l.waktu) }}</td><td class="tengah">{{ JENIS_LOG[l.jenis].n }}</td>
            <td>{{ l.nama }}</td><td class="tengah">{{ l.kelas || '–' }}</td><td>{{ l.kamar || '–' }}</td><td>{{ l.alasan_izin || '–' }}</td><td>{{ ket(l) || '–' }}</td><td>{{ l.petugas || '–' }}</td></tr>
          <tr v-if="!tampil.length"><td colspan="9" class="tengah">Tidak ada catatan.</td></tr>
        </tbody>
      </table>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: penanda.jabatan || 'Kepala Bidang Kesantrian', nama: penanda.nama, niy: penanda.niy }"
          :kanan="{ jabatan: 'Pembuat rekap', nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
      </template>
    </DokumenCetak>
  </div>
</template>
