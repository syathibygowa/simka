<!-- SIMKA PRO | src/pages/keuangan/TabTunggakan.vue | v1.3 | 14.2.0: tombol WhatsApp hijau | 17/10/2026 -->
<script setup>
// Posisi tunggakan per tanggal (bawaan hari ini): tagihan yang jatuh tempo paling lambat tanggal itu dan masih bersisa
// pada tanggal itu. Dikelompokkan per santri, kelas, kamar, halaqah, jenis biaya, atau jenjang. Cetak F4 dan Excel.
// Periode jatuh tempo (v1.1): semua, hari ini, pekan ini, bulan ini, bulan lalu, semester ini, atau rentang tanggal.
// Per santri: WA pemberitahuan tunggakan ke wali (satu per satu atau berurutan) dan surat tagihan massal.
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import * as XLSX from 'xlsx'
import { PhFileXls, PhPrinter, PhWhatsappLogo, PhPaperPlaneTilt, PhWarningCircle, PhUsersThree, PhInvoice, PhCaretDown, PhCaretRight } from '@phosphor-icons/vue'
import { useKeuangan } from '@/stores/keuangan'
import { useLembaga } from '@/stores/lembaga'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { formatPendek, formatPanjang, hariIniISO } from '@/lib/tanggal'
import { rupiah, angka, kelompokTunggakan, pesanTunggakan, JENJANG } from '@/lib/keuangan'
import { periodeCepat } from '@/lib/laporanKehadiran'
import { tautanWA } from '@/lib/wa'
import KartuStatistik from '@/components/KartuStatistik.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import DaftarKirimWA from '@/components/DaftarKirimWA.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import LembarSuratTagihan from './LembarSuratTagihan.vue'

const keu = useKeuangan(); const lembaga = useLembaga(); const sesi = useSesi(); const ui = useUI(); const router = useRouter(); const route = useRoute()
const tanggal = ref(hariIniISO()); const dari = ref(''); const periode = ref(''); const cakupan = ref('santri'); const jenjang = ref(''); const baris = ref([]); const memuat = ref(true)
async function muat() { memuat.value = true; try { baris.value = await keu.posisiTunggakan(tanggal.value) } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false } }
onMounted(() => { muat(); lembaga.muat() })
watch(tanggal, muat)
const PERIODE = [{ k: '', n: 'Semua tunggakan' }, { k: 'hari', n: 'Jatuh tempo hari ini' }, { k: 'pekan', n: 'Pekan ini' }, { k: 'bulan', n: 'Bulan ini' },
  { k: 'bulan_lalu', n: 'Bulan lalu' }, { k: 'semester', n: 'Semester ini' }, { k: 'rentang', n: 'Rentang tanggal' }]
watch(periode, (k) => {
  if (!k) { dari.value = ''; tanggal.value = hariIniISO() }
  else if (k !== 'rentang') { const x = periodeCepat(k); dari.value = x.mulai; tanggal.value = x.selesai }
  else if (!dari.value) dari.value = hariIniISO().slice(0, 8) + '01'
})
const CAKUPAN = [{ k: 'santri', n: 'Per santri' }, { k: 'kelas', n: 'Per kelas' }, { k: 'kamar', n: 'Per kamar' }, { k: 'halaqah', n: 'Per halaqah' }, { k: 'jenis', n: 'Per jenis biaya' }, { k: 'jenjang', n: 'Per jenjang' }]
const data = computed(() => baris.value.filter((r) => (!jenjang.value || r.jenjang === jenjang.value) && (!dari.value || r.jatuh_tempo >= dari.value)))
const teksPeriode = computed(() => (dari.value ? `jatuh tempo ${formatPanjang(dari.value)} s.d. ${formatPanjang(tanggal.value)}` : `posisi per ${formatPanjang(tanggal.value)}`))
const kelompok = computed(() => kelompokTunggakan(data.value, cakupan.value))
const total = computed(() => data.value.reduce((a, r) => a + Number(r.sisa), 0))
const santri = computed(() => kelompokTunggakan(data.value, 'santri'))
const buka = ref({})
const bukaSantri = (sid) => router.replace({ query: { ...route.query, santri: sid } })
const judulCakupan = computed(() => CAKUPAN.find((c) => c.k === cakupan.value).n.toLowerCase())

const kirim = ref(false); const surat = ref(null)
const penerima = computed(() => santri.value.map((k) => ({ employee_id: k.student_id, nama: `${k.wali?.nama || 'Wali'} – ${k.nama}`, no_hp: k.wali?.no_hp, unit: `${k.kelas || '–'} · ${rupiah(k.sisa)}`, k })))
const pesan = (p) => pesanTunggakan({ nama: p.k.nama, nis: p.k.nis, kelas: p.k.kelas, wali: p.k.wali }, p.k.isi, keu.pengaturan)

function ekspor() {
  const aoa = [['No.', 'NIS', 'Nama', 'JK', 'Kelas', 'Kamar', 'Halaqah', 'Jenjang', 'Jenis biaya', 'Tagihan', 'Jatuh tempo', 'Hari lewat', 'Nominal', 'Dibayar', 'Sisa', 'Wali', 'HP wali'],
    ...data.value.map((r, i) => [i + 1, r.nis, r.nama, r.jk, r.kelas || '', r.kamar || '', r.halaqah || '', JENJANG[r.jenjang], r.jenis, r.tagihan, formatPendek(r.jatuh_tempo), r.hari_lewat, Number(r.nominal), Number(r.dibayar), Number(r.sisa), r.wali?.nama || '', r.wali?.no_hp || ''])]
  const ringkas = [[`Rekap tunggakan ${judulCakupan.value}`, '', '', ''], ['Kelompok', 'Santri', 'Tagihan', 'Sisa'], ...kelompok.value.map((k) => [k.nama, k.jumlahSantri, k.tagihan, k.sisa]), ['Jumlah', santri.value.length, data.value.length, total.value]]
  const wb = XLSX.utils.book_new()
  const w1 = XLSX.utils.aoa_to_sheet([[`Tunggakan santri, ${teksPeriode.value}`], [], ...aoa]); w1['!cols'] = aoa[0].map((j) => ({ wch: ['Nama', 'Tagihan', 'Wali'].includes(j) ? 28 : 12 }))
  XLSX.utils.book_append_sheet(wb, w1, 'Rincian'); XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet(ringkas), 'Rekap')
  XLSX.writeFile(wb, `Tunggakan-Santri-${tanggal.value}.xlsx`)
}
const pratinjau = ref(false)
const direktur = computed(() => lembaga.signatories.find((s) => /^direktur$/i.test(s.jabatan_tertulis)) || {})
</script>
<template>
  <div>
    <div class="mb-3 flex flex-wrap items-end gap-2">
      <div class="w-52"><label class="label-isian" for="tg-per">Periode</label>
        <select id="tg-per" v-model="periode" class="isian"><option v-for="x in PERIODE" :key="x.k" :value="x.k">{{ x.n }}</option></select></div>
      <div v-if="periode === 'rentang'" class="w-44"><InputTanggal v-model="dari" label="Jatuh tempo dari" /></div>
      <div class="w-44"><InputTanggal v-model="tanggal" :label="periode ? 'Sampai tanggal' : 'Posisi per tanggal'" /></div>
      <select v-model="jenjang" class="isian w-48" aria-label="Jenjang"><option value="">Semua jenjang</option><option v-for="(n, k) in JENJANG" :key="k" :value="k">{{ n }}</option></select>
      <div class="flex-1" />
      <button class="tombol-garis" :disabled="!data.length" @click="ekspor"><PhFileXls :size="20" weight="duotone" /> Excel</button>
      <button class="tombol-garis" :disabled="!data.length" @click="pratinjau = true"><PhPrinter :size="20" weight="duotone" /> Cetak</button>
    </div>
    <div class="-mx-4 mb-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-3 sm:overflow-visible sm:px-0">
      <KartuStatistik class="w-[72%] shrink-0 snap-start sm:w-auto" judul="Jumlah tunggakan" :nilai="rupiah(total)" :ikon="PhWarningCircle" warna="klinik" :keterangan="teksPeriode.charAt(0).toUpperCase() + teksPeriode.slice(1)" />
      <KartuStatistik class="w-[44%] shrink-0 snap-start sm:w-auto" judul="Santri menunggak" :nilai="santri.length" :ikon="PhUsersThree" warna="pengajuan" :keterangan="santri.filter((k) => k.wali?.no_hp).length + ' memiliki WA wali'" />
      <KartuStatistik class="w-[44%] shrink-0 snap-start sm:w-auto" judul="Tagihan tertunggak" :nilai="data.length" :ikon="PhInvoice" warna="tahfizh" :keterangan="'Tertua ' + (data.length ? formatPendek(data.map((r) => r.jatuh_tempo).sort()[0]) : '–')" />
    </div>
    <div class="mb-3 flex flex-wrap items-center gap-1.5" role="group" aria-label="Kelompokkan">
      <div class="bilah-tab kecil" role="tablist" aria-label="Kelompokkan">
        <button v-for="c in CAKUPAN" :key="c.k" type="button" @click="(cakupan = c.k), (buka = {})"
        :class="['tab-garis', (cakupan === c.k) && 'aktif']" role="tab" :aria-selected="cakupan === c.k">{{ c.n }}</button>
      </div>
      <div class="flex-1" />
      <button v-if="santri.length" class="tombol-wa-garis min-h-[40px] px-3 text-sm w-presensi" @click="kirim = true"><PhWhatsappLogo :size="18" weight="duotone" /> WA ke semua wali</button>
      <button v-if="santri.length && keu.hak.kelola" class="tombol-utama min-h-[40px] px-3 text-sm" @click="surat = santri.map((k) => ({ id: k.student_id, nama: k.nama }))"><PhPaperPlaneTilt :size="18" weight="duotone" /> Surat tagihan semua</button>
    </div>

    <p v-if="memuat" class="kartu p-8 text-center text-sm text-teks3">Memuat…</p>
    <p v-else-if="!data.length" class="kartu p-8 text-center text-sm text-teks3">Tidak ada tunggakan pada tanggal ini. <i>Alhamdulillah.</i></p>
    <ul v-else class="space-y-2.5">
      <li v-for="k in kelompok" :key="k.kunci" class="kartu p-3.5">
        <div class="flex flex-wrap items-center gap-2">
          <button class="flex min-w-[180px] flex-1 items-start gap-2 text-left" @click="cakupan === 'santri' ? bukaSantri(k.student_id) : (buka[k.kunci] = !buka[k.kunci])">
            <component :is="cakupan === 'santri' ? PhCaretRight : buka[k.kunci] ? PhCaretDown : PhCaretRight" :size="18" class="mt-1 shrink-0 text-teks3" />
            <span><span class="block font-bold">{{ k.nama }}</span>
              <span class="block text-xs text-teks3">{{ cakupan === 'santri' ? `${k.nis} · ${k.kelas || '–'} · ` : `${k.jumlahSantri} santri · ` }}{{ k.tagihan }} tagihan · tertua {{ formatPendek(k.tertua) }} ({{ k.hari }} hari)</span></span>
          </button>
          <p class="text-lg font-extrabold tabular-nums" style="color: var(--c)">{{ rupiah(k.sisa) }}</p>
          <a v-if="cakupan === 'santri' && k.wali?.no_hp" :href="tautanWA(k.wali.no_hp, pesanTunggakan({ nama: k.nama, nis: k.nis, kelas: k.kelas, wali: k.wali }, k.isi, keu.pengaturan))" target="_blank" rel="noopener"
            class="tombol-ikon h-10 w-10 w-presensi" style="color: var(--c)" :aria-label="'WA wali ' + k.nama"><PhWhatsappLogo :size="22" weight="duotone" /></a>
        </div>
        <p v-if="cakupan === 'santri'" class="mt-1 pl-7 text-sm text-teks2">{{ k.isi.map((r) => r.tagihan).join(', ') }}</p>
        <ul v-if="cakupan !== 'santri' && buka[k.kunci]" class="mt-2 divide-y divide-garis border-t border-garis pl-7">
          <li v-for="s in kelompokTunggakan(k.isi, 'santri')" :key="s.kunci"><button class="flex w-full items-center gap-2 py-2 text-left text-sm" @click="bukaSantri(s.student_id)">
            <span class="min-w-0 flex-1"><b>{{ s.nama }}</b> <span class="text-xs text-teks3">{{ s.nis }} · {{ s.kelas || '–' }}</span></span><span class="tabular-nums">{{ rupiah(s.sisa) }}</span></button></li>
        </ul>
      </li>
    </ul>

    <LembarBawah v-model="kirim" judul="WA tunggakan ke wali" lebar>
      <DaftarKirimWA :penerima="penerima" :pesan="pesan" :kunci="'tunggakan-' + tanggal" />
    </LembarBawah>
    <LembarSuratTagihan :santri="surat" @tutup="surat = null" @terbit="muat" />
    <DokumenCetak v-model:pratinjau="pratinjau" mendatar judul="Laporan Tunggakan Keuangan Santri" :subjudul="`${teksPeriode.charAt(0).toUpperCase() + teksPeriode.slice(1)} · ${CAKUPAN.find((c) => c.k === cakupan).n}${jenjang ? ' · ' + JENJANG[jenjang] : ''}`" :pencetak="sesi.pengguna?.nama_lengkap">
      <table v-if="cakupan === 'santri'" class="tabel">
        <colgroup><col style="width:4%"><col style="width:9%"><col style="width:20%"><col style="width:4%"><col style="width:8%"><col style="width:31%"><col style="width:10%"><col style="width:14%"></colgroup>
        <thead><tr><th>No.</th><th>NIS</th><th>Nama</th><th>JK</th><th>Kelas</th><th>Tagihan tertunggak</th><th>Tertua</th><th>Sisa (Rp)</th></tr></thead>
        <tbody><tr v-for="(k, i) in kelompok" :key="k.kunci"><td class="tengah">{{ i + 1 }}</td><td>{{ k.nis }}</td><td>{{ k.nama }}</td><td class="tengah">{{ k.isi[0]?.jk }}</td><td>{{ k.kelas || '' }}</td>
          <td>{{ k.isi.map((r) => r.tagihan).join(', ') }}</td><td class="tengah">{{ formatPendek(k.tertua) }}</td><td class="kanan">{{ angka(k.sisa) }}</td></tr>
          <tr><th colspan="7">Jumlah ({{ kelompok.length }} santri)</th><th class="kanan">{{ angka(total) }}</th></tr></tbody>
      </table>
      <table v-else class="tabel">
        <colgroup><col style="width:6%"><col style="width:46%"><col style="width:14%"><col style="width:14%"><col style="width:20%"></colgroup>
        <thead><tr><th>No.</th><th>{{ { kelas: 'Kelas', kamar: 'Kamar', halaqah: 'Halaqah', jenis: 'Jenis biaya', jenjang: 'Jenjang' }[cakupan] }}</th><th>Santri</th><th>Tagihan</th><th>Sisa (Rp)</th></tr></thead>
        <tbody><tr v-for="(k, i) in kelompok" :key="k.kunci"><td class="tengah">{{ i + 1 }}</td><td>{{ k.nama }}</td><td class="tengah">{{ k.jumlahSantri }}</td><td class="tengah">{{ k.tagihan }}</td><td class="kanan">{{ angka(k.sisa) }}</td></tr>
          <tr><th colspan="2">Jumlah</th><th>{{ santri.length }}</th><th>{{ data.length }}</th><th class="kanan">{{ angka(total) }}</th></tr></tbody>
      </table>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan_tertulis || 'Direktur', nama: direktur.nama || '', niy: direktur.niy }"
          :kanan="{ jabatan: keu.jabatanSaya, nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" :tanggal="tanggal" />
      </template>
    </DokumenCetak>
  </div>
</template>
