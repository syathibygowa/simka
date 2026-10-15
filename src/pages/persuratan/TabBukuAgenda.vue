<!-- SIMKA PRO | src/pages/persuratan/TabBukuAgenda.vue | v1.2 | Perbaikan 13.5.0: tab bergaris bawah | 15/10/2026 -->
<script setup>
// Buku agenda surat masuk per rentang tanggal terima (paling lama satu tahun): tabel, Excel, cetak F4 mendatar.
// Surat rahasia yang tidak boleh dibaca ditampilkan perihalnya sebagai "(Rahasia)". Pilihan Surat keluar membuka BukuAgendaKeluar.
import { ref, computed, watch } from 'vue'
import * as XLSX from 'xlsx'
import { PhEye, PhDownloadSimple } from '@phosphor-icons/vue'
import { usePersuratan } from '@/stores/persuratan'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { SIFAT_SURAT, STATUS_SURAT } from '@/lib/persuratan'
import { formatPanjang, formatPendek, hariIniISO } from '@/lib/tanggal'
import { ambilPenandaTangan } from '@/lib/penandatangan'
import InputTanggal from '@/components/InputTanggal.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import BukuAgendaKeluar from './BukuAgendaKeluar.vue'
const jenis = ref('masuk')

const ps = usePersuratan(); const sesi = useSesi(); const ui = useUI()
const mulai = ref(hariIniISO().slice(0, 8) + '01'); const selesai = ref(hariIniISO()); const baris = ref([]); const memuat = ref(false); const pratinjau = ref(false)
const direktur = ref({ jabatan: 'Direktur', nama: '', niy: '' })
ambilPenandaTangan('Direktur').then((d) => { direktur.value = d }).catch(() => {})
async function muat() {
  memuat.value = true
  try { baris.value = await ps.bukuAgenda(mulai.value, selesai.value) } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
watch([mulai, selesai], muat, { immediate: true })
const periode = computed(() => `Tanggal terima ${formatPanjang(mulai.value)} s.d. ${formatPanjang(selesai.value)}`)
const ket = (r) => r.disposisi || (r.status === 'diarsipkan' ? 'Diarsipkan' : r.status === 'batal' ? 'Dibatalkan' : '–')
function ekspor() {
  const kolom = ['No. Agenda', 'Tanggal Terima', 'Nomor Surat', 'Tanggal Surat', 'Asal/Pengirim', 'Perihal', 'Sifat', 'Diteruskan Kepada', 'Disposisi Kepada', 'Status']
  const isi = baris.value.map((r) => [r.nomor_agenda, formatPendek(r.tanggal_terima), r.nomor_surat || '', r.tanggal_surat ? formatPendek(r.tanggal_surat) : '', r.pengirim, r.perihal,
    SIFAT_SURAT[r.sifat].n, r.tujuan || '', r.disposisi || '', STATUS_SURAT[r.status].n])
  const ws = XLSX.utils.aoa_to_sheet([['Buku Agenda Surat Masuk'], [periode.value], [], kolom, ...isi])
  ws['!cols'] = [14, 12, 24, 12, 30, 40, 10, 26, 30, 18].map((w) => ({ wch: w }))
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Surat Masuk'); XLSX.writeFile(wb, `Buku-Agenda-Surat-Masuk-${mulai.value}-${selesai.value}.xlsx`)
}
</script>
<template>
  <div>
    <div class="bilah-tab kecil mb-3" role="tablist" aria-label="Jenis buku agenda">
      <button v-for="j in [{ k: 'masuk', n: 'Surat masuk' }, { k: 'keluar', n: 'Surat keluar' }]" :key="j.k" type="button" role="tab" :aria-selected="jenis === j.k"
        :class="['tab-garis', jenis === j.k && 'aktif']" @click="jenis = j.k">{{ j.n }}</button>
    </div>
    <BukuAgendaKeluar v-if="jenis === 'keluar'" />
    <template v-else>
    <div class="kartu mb-4 grid grid-cols-2 gap-3 p-4 sm:grid-cols-[1fr_1fr_auto]">
      <InputTanggal v-model="mulai" label="Diterima dari" wajib /><InputTanggal v-model="selesai" label="Sampai" wajib />
      <div class="col-span-2 flex items-end gap-2 sm:col-span-1">
        <button class="tombol-garis w-pengajuan min-h-[44px] px-3 text-sm" :disabled="!baris.length" @click="pratinjau = true"><PhEye :size="18" style="color: var(--c)" /> Cetak</button>
        <button class="tombol-garis w-santri min-h-[44px] px-3 text-sm" :disabled="!baris.length" @click="ekspor"><PhDownloadSimple :size="18" style="color: var(--c)" /> Excel</button>
      </div>
    </div>
    <div class="kartu overflow-x-auto">
      <table class="w-full min-w-[860px] text-left text-sm">
        <thead class="border-b border-garis bg-permukaan2 text-teks2"><tr>
          <th class="px-3 py-2.5 font-bold">No. agenda</th><th class="px-3 py-2.5 font-bold">Diterima</th><th class="px-3 py-2.5 font-bold">Nomor/tanggal surat</th>
          <th class="px-3 py-2.5 font-bold">Asal/pengirim</th><th class="px-3 py-2.5 font-bold">Perihal</th><th class="px-3 py-2.5 font-bold">Sifat</th>
          <th class="px-3 py-2.5 font-bold">Diteruskan/disposisi</th><th class="px-3 py-2.5 font-bold">Status</th></tr></thead>
        <tbody class="divide-y divide-garis">
          <tr v-for="r in baris" :key="r.nomor_agenda" :class="r.status === 'batal' && 'opacity-60'">
            <td class="px-3 py-2 tabular-nums">{{ r.nomor_agenda }}</td><td class="px-3 py-2 tabular-nums">{{ formatPendek(r.tanggal_terima) }}</td>
            <td class="px-3 py-2">{{ r.nomor_surat || '–' }}<span v-if="r.tanggal_surat" class="block text-xs text-teks3">{{ formatPendek(r.tanggal_surat) }}</span></td>
            <td class="px-3 py-2">{{ r.pengirim }}</td><td class="px-3 py-2">{{ r.perihal }}</td>
            <td class="px-3 py-2"><span class="lencana" :class="'w-' + SIFAT_SURAT[r.sifat].w">{{ SIFAT_SURAT[r.sifat].n }}</span></td>
            <td class="px-3 py-2">{{ r.tujuan || '–' }}<span class="block text-xs text-teks3">{{ ket(r) }}</span></td>
            <td class="px-3 py-2"><span class="lencana" :class="'w-' + STATUS_SURAT[r.status].w">{{ STATUS_SURAT[r.status].n }}</span></td>
          </tr>
        </tbody>
      </table>
      <p v-if="!baris.length" class="py-8 text-center text-sm text-teks3">{{ memuat ? 'Memuat…' : 'Belum ada surat masuk pada rentang ini.' }}</p>
    </div>

    <DokumenCetak kop="pondok" judul="Buku Agenda Surat Masuk" :subjudul="periode" v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap" mendatar>
      <table class="tabel kecil">
        <colgroup><col style="width: 4%" /><col style="width: 10%" /><col style="width: 8%" /><col style="width: 14%" /><col style="width: 15%" /><col style="width: 20%" />
          <col style="width: 6%" /><col style="width: 15%" /><col style="width: 8%" /></colgroup>
        <thead><tr><th>No.</th><th>No. Agenda</th><th>Tgl. Terima</th><th>Nomor dan Tanggal Surat</th><th>Asal/Pengirim</th><th>Perihal</th><th>Sifat</th><th>Diteruskan/Disposisi</th><th>Status</th></tr></thead>
        <tbody>
          <tr v-for="(r, i) in baris" :key="r.nomor_agenda">
            <td class="tengah">{{ i + 1 }}</td><td>{{ r.nomor_agenda }}</td><td class="tengah">{{ formatPendek(r.tanggal_terima) }}</td>
            <td>{{ [r.nomor_surat, r.tanggal_surat && formatPendek(r.tanggal_surat)].filter(Boolean).join(', ') || '–' }}</td><td>{{ r.pengirim }}</td><td>{{ r.perihal }}</td>
            <td>{{ SIFAT_SURAT[r.sifat].n }}</td><td>{{ r.tujuan || '–' }}{{ r.disposisi ? ' → ' + r.disposisi : '' }}</td><td>{{ STATUS_SURAT[r.status].n }}</td>
          </tr>
        </tbody>
      </table>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan, nama: direktur.nama, niy: direktur.niy }"
          :kanan="{ jabatan: 'Petugas Tata Usaha', nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
      </template>
    </DokumenCetak>
    </template>
  </div>
</template>
