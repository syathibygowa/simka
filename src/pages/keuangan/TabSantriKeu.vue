<!-- SIMKA PRO | src/pages/keuangan/TabSantriKeu.vue | v1.1 | Fase 13 – Pelengkap: saringan kelas/kamar/halaqah | 11/10/2026 -->
<script setup>
// Per santri: tagihan, dibayar, sisa, tunggakan lewat tempo, subsidi, wali (WA). Ketuk santri → rincian (?santri=).
// Pilih beberapa santri → terbitkan surat tagihan sekaligus. Ekspor Excel dan cetak F4.
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import * as XLSX from 'xlsx'
import { PhMagnifyingGlass, PhPaperPlaneTilt, PhFileXls, PhPrinter, PhCheckSquare, PhSquare, PhCaretRight, PhPercent, PhWhatsappLogo } from '@phosphor-icons/vue'
import { useKeuangan } from '@/stores/keuangan'
import { useLembaga } from '@/stores/lembaga'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { formatPendek, hariIniISO, formatPanjang } from '@/lib/tanggal'
import { rupiah, angka, JENJANG, JENJANG_SINGKAT } from '@/lib/keuangan'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import LembarSuratTagihan from './LembarSuratTagihan.vue'

const keu = useKeuangan(); const lembaga = useLembaga(); const sesi = useSesi(); const ui = useUI()
const router = useRouter(); const route = useRoute()
const daftar = ref([]); const memuat = ref(true)
const q = ref(''); const jenjang = ref(''); const grup = ref(''); const kelompok = ref([]); const status = ref(typeof route.query.status === 'string' ? route.query.status : '')
async function muat() { memuat.value = true; try { daftar.value = await keu.santri({ group_id: grup.value }) } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false } }
onMounted(() => { muat(); lembaga.muat(); keu.kelompok().then((k) => { kelompok.value = k }).catch(() => {}) })
watch(grup, muat)
const namaGrup = computed(() => kelompok.value.find((g) => g.id === grup.value)?.nama || '')
const SARING = computed(() => [
  { k: '', n: 'Semua', j: daftar.value.length }, { k: 'tunggak', n: 'Ada sisa', j: daftar.value.filter((x) => x.sisa > 0).length },
  { k: 'lewat', n: 'Lewat jatuh tempo', j: daftar.value.filter((x) => x.lewat > 0).length }, { k: 'lunas', n: 'Lunas', j: daftar.value.filter((x) => x.tagihan > 0 && !x.sisa).length },
])
const tampil = computed(() => { const c = q.value.toLowerCase().trim()
  return daftar.value.filter((x) => (!c || x.nama.toLowerCase().includes(c) || x.nis.startsWith(c)) && (!jenjang.value || x.jenjang === jenjang.value)
    && (status.value === 'tunggak' ? x.sisa > 0 : status.value === 'lewat' ? x.lewat > 0 : status.value === 'lunas' ? x.tagihan > 0 && !x.sisa : true)) })
const jml = (k) => tampil.value.reduce((a, x) => a + Number(x[k] || 0), 0)
const buka = (x) => router.replace({ query: { ...route.query, santri: x.id } })

const pilih = ref(new Set())
const ubahPilih = (x) => { const s = new Set(pilih.value); s.has(x.id) ? s.delete(x.id) : s.add(x.id); pilih.value = s }
const pilihSemua = () => { pilih.value = pilih.value.size ? new Set() : new Set(tampil.value.filter((x) => x.sisa > 0).map((x) => x.id)) }
const surat = ref(null)
const terbitkan = () => { surat.value = daftar.value.filter((x) => pilih.value.has(x.id)) }

function ekspor() {
  const aoa = [['No.', 'NIS', 'Nama', 'JK', 'Kelas', 'Jenjang', 'Tagihan', 'Dibayar', 'Sisa', 'Lewat jatuh tempo', 'Jatuh tempo tertua', 'Wali', 'HP wali'],
    ...tampil.value.map((x, i) => [i + 1, x.nis, x.nama, x.jk, x.kelas || '', JENJANG_SINGKAT[x.jenjang], Number(x.tagihan), Number(x.dibayar), Number(x.sisa), Number(x.lewat),
      x.tempo_tertua ? formatPendek(x.tempo_tertua) : '', x.wali?.nama || '', x.wali?.no_hp || '']),
    ['', '', 'Jumlah', '', '', '', jml('tagihan'), jml('dibayar'), jml('sisa'), jml('lewat')]]
  const ws = XLSX.utils.aoa_to_sheet([[`Keuangan Santri per ${formatPanjang(hariIniISO())}`], [], ...aoa])
  ws['!cols'] = aoa[0].map((j) => ({ wch: j === 'Nama' || j === 'Wali' ? 30 : 14 }))
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Keuangan santri'); XLSX.writeFile(wb, `Keuangan-Santri-${hariIniISO()}.xlsx`)
}
const pratinjau = ref(false)
const direktur = computed(() => lembaga.signatories.find((s) => /^direktur$/i.test(s.jabatan_tertulis)) || {})
</script>
<template>
  <div>
    <div class="mb-3 flex flex-wrap items-end gap-2">
      <div class="relative min-w-[200px] flex-1"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-teks3" />
        <input v-model="q" type="search" class="isian pl-10" placeholder="Cari nama atau NIS" aria-label="Cari santri" /></div>
      <select v-model="grup" class="isian w-48" aria-label="Kelompok"><option value="">Semua kelompok</option>
        <optgroup v-for="(n, jn) in { kelas: 'Kelas', kamar: 'Kamar', halaqah: 'Halaqah' }" :key="jn" :label="n"><option v-for="g in kelompok.filter((x) => x.jenis === jn)" :key="g.id" :value="g.id">{{ g.nama }}</option></optgroup></select>
      <select v-model="jenjang" class="isian w-48" aria-label="Jenjang"><option value="">Semua jenjang</option><option v-for="(n, k) in JENJANG" :key="k" :value="k">{{ n }}</option></select>
      <button class="tombol-garis" :disabled="!tampil.length" @click="ekspor"><PhFileXls :size="20" weight="duotone" /> Excel</button>
      <button class="tombol-garis" :disabled="!tampil.length" @click="pratinjau = true"><PhPrinter :size="20" weight="duotone" /> Cetak</button>
    </div>
    <div class="-mx-4 mb-3 flex gap-1.5 overflow-x-auto px-4 sm:mx-0 sm:px-0" role="group" aria-label="Saring santri">
      <button v-for="s in SARING" :key="s.k" type="button" @click="status = s.k" :aria-pressed="status === s.k"
        :class="['min-h-[40px] shrink-0 rounded-xl border px-3 text-sm font-semibold', status === s.k ? 'border-transparent bg-[#C7332F] text-white' : 'border-garis text-teks2']">{{ s.n }} <span class="tabular-nums opacity-80">{{ s.j }}</span></button>
    </div>
    <div v-if="keu.hak.kelola" class="mb-3 flex flex-wrap items-center gap-2">
      <button class="tombol-garis min-h-[40px] px-3 text-sm" @click="pilihSemua"><component :is="pilih.size ? PhCheckSquare : PhSquare" :size="18" /> {{ pilih.size ? 'Kosongkan pilihan' : 'Pilih semua yang bersisa' }}</button>
      <button v-if="pilih.size" class="tombol-utama min-h-[40px] px-3 text-sm" @click="terbitkan"><PhPaperPlaneTilt :size="18" weight="duotone" /> Surat tagihan untuk {{ pilih.size }} santri</button>
    </div>

    <p v-if="memuat" class="kartu p-8 text-center text-sm text-teks3">Memuat…</p>
    <p v-else-if="!tampil.length" class="kartu p-8 text-center text-sm text-teks3">Tidak ada santri yang sesuai.</p>
    <template v-else>
      <div class="kartu hidden overflow-x-auto lg:block">
        <table class="w-full text-left text-sm">
          <thead class="border-b border-garis bg-permukaan2 text-teks2"><tr>
            <th v-if="keu.hak.kelola" class="w-10 px-3 py-3"><span class="sr-only">Pilih</span></th>
            <th class="px-3 py-3 font-bold">NIS</th><th class="px-3 py-3 font-bold">Nama</th><th class="px-3 py-3 font-bold">JK</th><th class="px-3 py-3 font-bold">Kelas</th>
            <th class="px-3 py-3 text-right font-bold">Tagihan</th><th class="px-3 py-3 text-right font-bold">Dibayar</th><th class="px-3 py-3 text-right font-bold">Sisa</th>
            <th class="px-3 py-3 text-right font-bold">Lewat tempo</th><th class="px-3 py-3 font-bold">Wali</th><th class="w-8" /></tr></thead>
          <tbody class="divide-y divide-garis">
            <tr v-for="x in tampil" :key="x.id" class="cursor-pointer hover:bg-permukaan2" @click="buka(x)">
              <td v-if="keu.hak.kelola" class="px-3 py-2.5" @click.stop="ubahPilih(x)"><component :is="pilih.has(x.id) ? PhCheckSquare : PhSquare" :size="22" :weight="pilih.has(x.id) ? 'fill' : 'regular'" style="color: var(--c)" :aria-label="'Pilih ' + x.nama" /></td>
              <td class="px-3 py-2.5 tabular-nums text-teks2">{{ x.nis }}</td>
              <td class="px-3 py-2.5 font-semibold">{{ x.nama }} <PhPercent v-if="x.subsidi" :size="14" class="inline" style="color: var(--c)" aria-label="Mendapat subsidi" /></td>
              <td class="px-3 py-2.5">{{ x.jk }}</td><td class="px-3 py-2.5">{{ x.kelas || JENJANG_SINGKAT[x.jenjang] + ' ' + x.tingkat }}</td>
              <td class="px-3 py-2.5 text-right tabular-nums">{{ angka(x.tagihan) }}</td><td class="px-3 py-2.5 text-right tabular-nums">{{ angka(x.dibayar) }}</td>
              <td class="px-3 py-2.5 text-right font-bold tabular-nums">{{ x.sisa ? angka(x.sisa) : '–' }}</td>
              <td :class="['px-3 py-2.5 text-right tabular-nums', x.lewat && 'font-bold text-merah']">{{ x.lewat ? angka(x.lewat) : '–' }}</td>
              <td class="px-3 py-2.5 text-xs">{{ x.wali?.nama || '–' }}<PhWhatsappLogo v-if="x.wali?.no_hp" :size="14" class="ml-1 inline text-[#1E7D4F]" aria-label="Ada nomor WA" /></td>
              <td class="pr-3"><PhCaretRight :size="16" class="text-teks3" /></td>
            </tr>
          </tbody>
          <tfoot class="border-t-2 border-garis bg-permukaan2 font-bold"><tr><td v-if="keu.hak.kelola" /><td class="px-3 py-3" colspan="4">Jumlah ({{ tampil.length }} santri)</td>
            <td class="px-3 py-3 text-right tabular-nums">{{ angka(jml('tagihan')) }}</td><td class="px-3 py-3 text-right tabular-nums">{{ angka(jml('dibayar')) }}</td>
            <td class="px-3 py-3 text-right tabular-nums">{{ angka(jml('sisa')) }}</td><td class="px-3 py-3 text-right tabular-nums">{{ angka(jml('lewat')) }}</td><td colspan="2" /></tr></tfoot>
        </table>
      </div>
      <ul class="space-y-2.5 lg:hidden">
        <li v-for="x in tampil" :key="x.id" class="kartu flex items-stretch overflow-hidden">
          <button v-if="keu.hak.kelola" class="grid w-12 shrink-0 place-items-center border-r border-garis" :aria-label="'Pilih ' + x.nama" @click="ubahPilih(x)">
            <component :is="pilih.has(x.id) ? PhCheckSquare : PhSquare" :size="24" :weight="pilih.has(x.id) ? 'fill' : 'regular'" style="color: var(--c)" /></button>
          <button class="min-w-0 flex-1 p-3.5 text-left active:bg-permukaan2" @click="buka(x)">
            <div class="flex items-start gap-2"><div class="min-w-0 flex-1"><p class="truncate font-bold">{{ x.nama }}</p><p class="text-xs text-teks3">{{ x.nis }} · {{ x.jk }} · {{ x.kelas || '–' }}</p></div>
              <p class="shrink-0 text-right"><span class="block text-lg font-extrabold tabular-nums" :style="x.sisa ? 'color: var(--c)' : ''">{{ x.sisa ? rupiah(x.sisa) : 'Lunas' }}</span>
                <span v-if="x.lewat" class="block text-xs font-semibold text-merah">lewat tempo {{ rupiah(x.lewat) }}</span></p></div>
          </button>
        </li>
      </ul>
    </template>

    <LembarSuratTagihan :santri="surat" @tutup="surat = null" @terbit="(pilih = new Set()), muat()" />
    <DokumenCetak v-model:pratinjau="pratinjau" mendatar judul="Daftar Tagihan Santri" :subjudul="`Posisi per ${formatPanjang(hariIniISO())}${namaGrup ? ' · ' + namaGrup : ''}${jenjang ? ' · ' + JENJANG[jenjang] : ''}`" :pencetak="sesi.pengguna?.nama_lengkap">
      <table class="tabel">
        <colgroup><col style="width:4%"><col style="width:9%"><col style="width:22%"><col style="width:4%"><col style="width:8%"><col v-for="n in 4" :key="n" style="width:10%"><col style="width:13%"></colgroup>
        <thead><tr><th>No.</th><th>NIS</th><th>Nama</th><th>JK</th><th>Kelas</th><th>Tagihan (Rp)</th><th>Dibayar (Rp)</th><th>Sisa (Rp)</th><th>Lewat tempo (Rp)</th><th>Wali</th></tr></thead>
        <tbody><tr v-for="(x, i) in tampil" :key="x.id"><td class="tengah">{{ i + 1 }}</td><td>{{ x.nis }}</td><td>{{ x.nama }}</td><td class="tengah">{{ x.jk }}</td><td>{{ x.kelas || '' }}</td>
          <td class="kanan">{{ angka(x.tagihan) }}</td><td class="kanan">{{ angka(x.dibayar) }}</td><td class="kanan">{{ angka(x.sisa) }}</td><td class="kanan">{{ angka(x.lewat) }}</td><td>{{ x.wali?.nama || '' }}</td></tr>
          <tr><th colspan="5">Jumlah</th><th class="kanan">{{ angka(jml('tagihan')) }}</th><th class="kanan">{{ angka(jml('dibayar')) }}</th><th class="kanan">{{ angka(jml('sisa')) }}</th><th class="kanan">{{ angka(jml('lewat')) }}</th><th /></tr></tbody>
      </table>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan_tertulis || 'Direktur', nama: direktur.nama || '', niy: direktur.niy }"
          :kanan="{ jabatan: keu.jabatanSaya, nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
      </template>
    </DokumenCetak>
  </div>
</template>
