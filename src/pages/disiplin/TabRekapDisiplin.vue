<!-- SIMKA PRO | src/pages/disiplin/TabRekapDisiplin.vue | v1.2 | 14.15.0: penanda tangan dan kop dari Setelan → Penanda tangan | 19/10/2026 -->
<script setup>
// Rekap kedisiplinan santri pada rentang tanggal: dikelompokkan per santri, kelas, kamar, atau kategori pelanggaran.
// Kolom ringan/sedang/berat/jumlah (tanpa poin) dan surat peringatan yang terbit pada rentang. Baris santri yang mencapai ambang
// ketentuan (pelanggaran belum ditindaklanjuti SP) ditandai. Cetak F4 berkop (tanda tangan sejajar kiri-kanan) dan Excel.
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { PhPrinter, PhFileXls, PhUsers, PhChalkboard, PhBuildings, PhTag, PhWarning } from '@phosphor-icons/vue'
import { useDisiplin } from '@/stores/disiplin'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { TINGKAT_SP_SANTRI } from '@/lib/disiplin'
import { formatPanjang, formatPendek, hariIniISO } from '@/lib/tanggal'
import { eksporExcel } from '@/lib/excel'
import { namaBerkas, periodeRentang } from '@/lib/namaBerkas'
import { ambilPenandaTangan } from '@/lib/penandatangan'
import InputTanggal from '@/components/InputTanggal.vue'
import SaringCorong from '@/components/SaringCorong.vue'
import BilahTab from '@/components/BilahTab.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const ds = useDisiplin(); const sesi = useSesi(); const ui = useUI(); const router = useRouter()
const hari = hariIniISO(); const th = Number(hari.slice(0, 4)) - (Number(hari.slice(5, 7)) < 7 ? 1 : 0)
const mulai = ref(`${th}-07-01`); const selesai = ref(hari); const jenjang = ref('')
const per = ref('santri')
const mulaiAwal = mulai.value
const jumlahSaring = computed(() => [jenjang.value, mulai.value !== mulaiAwal || selesai.value !== hari].filter(Boolean).length)
const ringkasSaring = computed(() => [`${formatPendek(mulai.value)} – ${formatPendek(selesai.value)}`, jenjang.value === 'wustha' ? 'Wustha' : jenjang.value === 'sma' ? 'SMA' : ''].filter(Boolean).join(' · '))
const PER = [{ k: 'santri', n: 'Per santri', ikon: PhUsers, w: 'santri' }, { k: 'kelas', n: 'Per kelas', ikon: PhChalkboard, w: 'walikelas' },
  { k: 'kamar', n: 'Per kamar', ikon: PhBuildings, w: 'musyrif' }, { k: 'kategori', n: 'Per kategori', ikon: PhTag, w: 'disiplin' }]
const pel = ref([]); const sp = ref([]); const memuat = ref(true)
const kesantrian = ref({ jabatan: 'Kepala Bidang Kesantrian', nama: '', niy: '' }); const direktur = ref({ jabatan: 'Direktur', nama: '', niy: '' })
async function muat() {
  if (selesai.value < mulai.value) return ui.toast('Tanggal akhir tidak boleh sebelum tanggal awal.', 'galat')
  memuat.value = true
  try { [pel.value, sp.value] = await Promise.all([ds.daftar({ mulai: mulai.value, selesai: selesai.value }), ds.daftarSP({ mulai: mulai.value, selesai: selesai.value })]) }
  catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
onMounted(() => {
  muat()
  ambilPenandaTangan('%Kesantrian%').then((d) => { if (d?.nama) kesantrian.value = d }).catch(() => {})
  ambilPenandaTangan('Direktur').then((d) => { if (d?.nama) direktur.value = d }).catch(() => {})
})
watch([mulai, selesai], muat)

const pelSaring = computed(() => pel.value.filter((x) => !jenjang.value || x.jenjang === jenjang.value))
const spTerbit = computed(() => sp.value.filter((x) => ['terbit', 'dicabut'].includes(x.status) && (!jenjang.value || x.jenjang === jenjang.value)))
const baris = computed(() => {
  const a = ds.set?.ambang || {}; const peta = new Map()
  const kunci = (x) => (per.value === 'santri' ? x.student_id : per.value === 'kategori' ? x.kategori : x[per.value] || '(tanpa ' + per.value + ')')
  for (const x of pelSaring.value) {
    const k = kunci(x)
    if (!peta.has(k)) peta.set(k, { k, nama: per.value === 'santri' ? x.nama : k, nis: x.nis, kelas: x.kelas, kamar: x.kamar, student_id: x.student_id,
      ringan: 0, sedang: 0, berat: 0, jumlah: 0, terbuka: { ringan: 0, sedang: 0, berat: 0 }, santri: new Set(), sp: [] })
    const b = peta.get(k); b[x.tingkat]++; b.jumlah++; b.santri.add(x.student_id); if (!x.warning_id) b.terbuka[x.tingkat]++
  }
  if (per.value !== 'kategori') for (const w of spTerbit.value) { const b = peta.get(per.value === 'santri' ? w.student_id : w[per.value] || '(tanpa ' + per.value + ')'); if (b) b.sp.push(w.tingkat) }
  return [...peta.values()].map((b) => ({ ...b, jumlahSantri: b.santri.size, spMaks: b.sp.length ? Math.max(...b.sp) : 0,
    ambang: per.value === 'santri' && ['ringan', 'sedang', 'berat'].some((t) => a[t] > 0 && b.terbuka[t] >= a[t]) }))
    .sort((x, y) => y.berat - x.berat || y.jumlah - x.jumlah || String(x.nama).localeCompare(String(y.nama)))
})
const total = computed(() => ({ ringan: baris.value.reduce((s, b) => s + b.ringan, 0), sedang: baris.value.reduce((s, b) => s + b.sedang, 0),
  berat: baris.value.reduce((s, b) => s + b.berat, 0), jumlah: baris.value.reduce((s, b) => s + b.jumlah, 0) }))
const maks = computed(() => Math.max(1, ...baris.value.map((b) => b.jumlah)))
const judulKolom = computed(() => ({ santri: 'Nama santri', kelas: 'Kelas', kamar: 'Kamar', kategori: 'Kategori pelanggaran' }[per.value]))
const subjudul = computed(() => [`Periode ${formatPanjang(mulai.value)} s.d. ${formatPanjang(selesai.value)}`, PER.find((p) => p.k === per.value).n, jenjang.value && (jenjang.value === 'sma' ? 'SMA' : 'Kesetaraan Wustha')].filter(Boolean).join(' · '))
const spTeks = (b) => (b.sp.length ? [...b.sp].sort().map((t) => TINGKAT_SP_SANTRI[t].singkat).join(', ') : '–')

const pratinjau = ref(false)
function excel() {
  if (!baris.value.length) return ui.toast('Tidak ada data untuk diekspor.', 'galat')
  const KOLOM = [
    ...(per.value === 'santri' ? [{ judul: 'NIS', kunci: 'nis' }] : []), { judul: judulKolom.value, kunci: 'nama' },
    ...(per.value === 'santri' ? [{ judul: 'Kelas', kunci: 'kelas' }, { judul: 'Kamar', kunci: 'kamar' }] : [{ judul: 'Jumlah santri', kunci: 'jumlahSantri' }]),
    { judul: 'Ringan', kunci: 'ringan' }, { judul: 'Sedang', kunci: 'sedang' }, { judul: 'Berat', kunci: 'berat' }, { judul: 'Jumlah', kunci: 'jumlah' },
    ...(per.value !== 'kategori' ? [{ judul: 'Surat peringatan', kunci: 'sp', format: (v, b) => spTeks(b) }] : []),
    ...(per.value === 'santri' ? [{ judul: 'Mencapai ambang', kunci: 'ambang', format: (v) => (v ? 'Ya' : '') }] : []),
  ]
  eksporExcel(`${namaBerkas('Rekap Kedisiplinan Santri', PER.find((p) => p.k === per.value).n, periodeRentang(mulai.value, selesai.value))}.xlsx`, KOLOM, baris.value, 'Rekap')
}
</script>
<template>
  <div>
    <div class="layar-saja">
      <BilahTab v-model="per" :tab="PER" kecil label="Kelompokkan rekap" class="mb-3" />
      <SaringCorong :jumlah="jumlahSaring" :ringkasan="ringkasSaring" judul="Saring rekap kedisiplinan">
        <div class="sm:w-44"><InputTanggal v-model="mulai" label="Dari tanggal" /></div>
        <div class="sm:w-44"><InputTanggal v-model="selesai" label="Sampai tanggal" /></div>
        <div><label class="label-isian" for="rd-jenjang">Jenjang</label>
          <select id="rd-jenjang" v-model="jenjang" class="isian w-auto max-w-full"><option value="">Semua jenjang</option><option value="wustha">Kesetaraan Wustha</option><option value="sma">SMA</option></select></div>
      </SaringCorong>
      <div class="mt-3 flex flex-wrap gap-2">
        <button class="tombol-garis min-h-[44px] px-3 text-sm" :disabled="!baris.length" @click="excel"><PhFileXls :size="18" weight="duotone" /> Ekspor</button>
        <button class="tombol-garis min-h-[44px] px-3 text-sm" :disabled="!baris.length" @click="pratinjau = true"><PhPrinter :size="18" weight="duotone" /> Cetak Rekap</button>
      </div>
      <p class="mt-3 text-sm text-teks2">Jumlah {{ total.jumlah }} pelanggaran: <b>{{ total.ringan }}</b> ringan, <b>{{ total.sedang }}</b> sedang, <b class="text-merah">{{ total.berat }}</b> berat ·
        {{ spTerbit.length }} surat peringatan terbit.</p>

      <p v-if="memuat" class="py-10 text-center text-teks3">Memuat rekap…</p>
      <p v-else-if="!baris.length" class="kartu mt-3 p-8 text-center text-sm text-teks3">Tidak ada catatan pelanggaran pada rentang ini.</p>
      <div v-else class="kartu mt-3 overflow-x-auto">
        <table class="tabel-layar w-full min-w-[640px] text-sm">
          <thead><tr class="text-left text-teks3"><th class="p-3">{{ judulKolom }}</th><th v-if="per !== 'santri'" class="p-3 text-center">Santri</th>
            <th class="p-3 text-center">Ringan</th><th class="p-3 text-center">Sedang</th><th class="p-3 text-center">Berat</th><th class="w-[28%] p-3">Jumlah</th><th v-if="per !== 'kategori'" class="p-3">SP</th></tr></thead>
          <tbody class="divide-y divide-garis">
            <tr v-for="b in baris" :key="b.k" :class="b.ambang && 'ambang'">
              <td class="p-3"><button v-if="per === 'santri'" type="button" class="text-left font-semibold hover:underline" @click="router.push({ path: '/disiplin-santri/pelanggaran', query: { santri: b.student_id } })">{{ b.nama }}</button>
                <b v-else>{{ b.nama }}</b>
                <span v-if="per === 'santri'" class="block text-xs text-teks3">{{ b.nis }}{{ b.kelas ? ' · ' + b.kelas : '' }}{{ b.kamar ? ' · ' + b.kamar : '' }}</span>
                <span v-if="b.ambang" class="mt-0.5 flex items-center gap-1 text-xs font-semibold text-merah"><PhWarning :size="13" /> Mencapai ambang</span></td>
              <td v-if="per !== 'santri'" class="p-3 text-center tabular-nums">{{ b.jumlahSantri }}</td>
              <td class="p-3 text-center tabular-nums">{{ b.ringan || '–' }}</td><td class="p-3 text-center tabular-nums">{{ b.sedang || '–' }}</td>
              <td :class="['p-3 text-center tabular-nums', b.berat && 'font-bold text-merah']">{{ b.berat || '–' }}</td>
              <td class="p-3"><div class="flex items-center gap-2"><span class="batang h-2.5 flex-1 overflow-hidden rounded-full bg-permukaan2">
                <span class="block h-full" :style="`width:${(b.jumlah / maks) * 100}%`" /></span><b class="w-6 text-right tabular-nums">{{ b.jumlah }}</b></div></td>
              <td v-if="per !== 'kategori'" class="p-3">{{ spTeks(b) }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <DokumenCetak jenis="disiplin_rekap" judul="Rekap Kedisiplinan Santri" :subjudul="subjudul" v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap"
      :nama-berkas="namaBerkas('Rekap Kedisiplinan Santri', PER.find((p) => p.k === per).n, periodeRentang(mulai, selesai))">
      <table class="tabel">
        <colgroup><col style="width:5%"><col v-if="per === 'santri'" style="width:11%"><col :style="`width:${per === 'santri' ? 30 : 41}%`"><col style="width:12%">
          <col style="width:8%"><col style="width:8%"><col style="width:8%"><col style="width:8%"><col v-if="per !== 'kategori'" style="width:10%"></colgroup>
        <thead><tr><th>No.</th><th v-if="per === 'santri'">NIS</th><th>{{ judulKolom }}</th><th>{{ per === 'santri' ? 'Kelas' : 'Santri' }}</th>
          <th>Ringan</th><th>Sedang</th><th>Berat</th><th>Jumlah</th><th v-if="per !== 'kategori'">SP</th></tr></thead>
        <tbody>
          <tr v-for="(b, i) in baris" :key="b.k" :class="b.ambang && 'cetak-ambang'"><td class="tengah">{{ i + 1 }}</td><td v-if="per === 'santri'" class="tengah">{{ b.nis }}</td><td>{{ b.nama }}</td>
            <td class="tengah">{{ per === 'santri' ? b.kelas || '–' : b.jumlahSantri }}</td><td class="tengah">{{ b.ringan }}</td><td class="tengah">{{ b.sedang }}</td><td class="tengah">{{ b.berat }}</td>
            <td class="tengah">{{ b.jumlah }}</td><td v-if="per !== 'kategori'" class="tengah">{{ spTeks(b) }}</td></tr>
          <tr><th :colspan="per === 'santri' ? 4 : 3">Jumlah</th><th>{{ total.ringan }}</th><th>{{ total.sedang }}</th><th>{{ total.berat }}</th><th>{{ total.jumlah }}</th><th v-if="per !== 'kategori'">{{ spTerbit.length }}</th></tr>
        </tbody>
      </table>
      <p v-if="per === 'santri'" style="margin-top: 6pt; font-size: 9pt">Baris berwarna: santri yang jumlah pelanggarannya (belum ditindaklanjuti surat peringatan) mencapai ambang ketentuan. Dokumen ini bersifat terbatas.</p>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan || 'Direktur', nama: direktur.nama, niy: direktur.niy }"
          :kanan="{ jabatan: kesantrian.jabatan || 'Kepala Bidang Kesantrian', nama: kesantrian.nama, niy: kesantrian.niy }" />
      </template>
    </DokumenCetak>
  </div>
</template>
<style scoped>
.batang > span { background: rgb(var(--merah)); }
tr.ambang > td { background: color-mix(in srgb, rgb(var(--merah)) 9%, transparent); }
</style>
