<!-- SIMKA PRO | src/pages/keuangan/LembarImporRiwayat.vue | v1.0 | Fase 13 – Impor catatan keuangan tahun-tahun lalu dari Excel | 12/10/2026 -->
<script setup>
// Impor catatan keuangan lama (santri kelas 8/9/11/12 yang sudah membayar sejak kelas 7/10):
//   Satu baris = satu tagihan satu periode: NIS, kode biaya, periode, nominal tagihan (kosong = tarif), dibayar, tanggal bayar, cara, keterangan.
//   Tagihan dibuat bila belum ada; pembayaran dicatat sebagai "catatan pembayaran lama" (tanpa kuitansi bernomor baru).
//   Berkas diperiksa dulu (mode uji, tidak menyimpan); baris galat dilewati saat disimpan.
import { ref, computed } from 'vue'
import * as XLSX from 'xlsx'
import { PhDownloadSimple, PhUploadSimple, PhCheckCircle, PhFloppyDisk } from '@phosphor-icons/vue'
import { useKeuangan } from '@/stores/keuangan'
import { useUI } from '@/stores/ui'
import { hariIniISO } from '@/lib/tanggal'
import { SIKLUS, bacaRupiah } from '@/lib/keuangan'
import LembarBawah from '@/components/LembarBawah.vue'

const buka = defineModel({ type: Boolean, default: false })
const emit = defineEmits(['selesai'])
const keu = useKeuangan(); const ui = useUI()
const baris = ref(null); const hasil = ref(null); const tersimpan = ref(false); const proses = ref(false); const masukan = ref(null); const namaBerkas = ref('')
const KOLOM = ['NIS', 'Nama', 'Kode biaya', 'Periode', 'Nominal tagihan (Rp)', 'Dibayar (Rp)', 'Tanggal bayar', 'Cara bayar', 'Keterangan']
const CONTOH = { bulanan: '2025-07 atau 07/2025', semesteran: '2024/2025-S1 atau 2024/2025-S2', tahunan: '2024/2025', sekali: '(kosong)' }
function tutup() { baris.value = null; hasil.value = null; tersimpan.value = false; namaBerkas.value = '' }

async function templat() {
  let santri = []
  try { santri = (await keu.santri({})).filter((s) => s.status === 'aktif') } catch { /* templat tetap dapat diunduh */ }
  const ws = XLSX.utils.aoa_to_sheet([KOLOM, ...santri.map((s) => [s.nis, s.nama, '', '', '', '', '', '', ''])])
  for (let i = 1; i <= santri.length; i++) { const a = XLSX.utils.encode_cell({ r: i, c: 0 }); if (ws[a]) { ws[a].t = 's'; ws[a].z = '@' } }
  ws['!cols'] = [10, 30, 14, 18, 18, 14, 14, 12, 28].map((wch) => ({ wch }))
  const pt = XLSX.utils.aoa_to_sheet([
    ['Petunjuk impor catatan keuangan lama'], [],
    ['1. Satu baris untuk satu tagihan satu periode. Salin baris santri bila ia punya beberapa periode (mis. SPP Juli–Juni = 12 baris).'],
    ['2. Nominal tagihan kosong = tarif jenis biaya untuk kelas santri pada periode itu (kelas dihitung mundur dari kelas sekarang), dikurangi subsidi.'],
    ['3. Dibayar diisi jumlah yang sudah dibayar (boleh sebagian). Kosong/0 = belum dibayar (menjadi tunggakan).'],
    ['4. Tanggal bayar ditulis dd/mm/yyyy; kosong = tanggal jatuh tempo. Cara bayar: Tunai atau Transfer.'],
    ['5. Pembayaran dicatat sebagai "catatan pembayaran lama" tanpa kuitansi bernomor baru. Tagihan yang sudah ada tidak digandakan.'],
    [], ['Kode biaya', 'Nama', 'Siklus', 'Contoh periode'],
    ...keu.jenis.map((j) => [j.kode, j.nama, SIKLUS[j.siklus]?.n, CONTOH[j.siklus]]),
  ])
  pt['!cols'] = [{ wch: 16 }, { wch: 30 }, { wch: 14 }, { wch: 30 }]
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Catatan'); XLSX.utils.book_append_sheet(wb, pt, 'Petunjuk')
  XLSX.writeFile(wb, `Templat-Catatan-Keuangan-Lama-${hariIniISO()}.xlsx`)
}

const dua = (n) => String(n).padStart(2, '0')
const isoDari = (d) => { const x = new Date(d.getTime() + 60e3); return `${x.getFullYear()}-${dua(x.getMonth() + 1)}-${dua(x.getDate())}` }
function tanggal(v) {
  if (v instanceof Date) return isoDari(v)
  const t = String(v ?? '').trim(); if (!t) return ''
  const m = t.match(/^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})$/); if (m) return `${m[3]}-${dua(m[2])}-${dua(m[1])}`
  if (/^\d{4}-\d{2}-\d{2}$/.test(t)) return t
  throw new Error(`Tanggal "${t}" tidak dikenali; tulis dd/mm/yyyy.`)
}
const periode = (v) => (v instanceof Date ? isoDari(v).slice(0, 7) : String(v ?? '').trim())
const uang = (v) => (v === '' || v == null ? '' : String(typeof v === 'number' ? Math.round(v) : bacaRupiah(String(v)) ?? ''))

async function bacaBerkas(e) {
  const berkas = e.target.files?.[0]; e.target.value = ''
  if (!berkas) return
  try {
    const wb = XLSX.read(await berkas.arrayBuffer(), { cellDates: true })
    const aoa = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]], { header: 1, raw: true, defval: '' })
    const iJ = aoa.findIndex((x) => x.some((c) => /^nis$/i.test(String(c).trim())))
    if (iJ < 0) throw new Error('Kolom NIS tidak ditemukan. Pakai berkas dari tombol "Unduh templat".')
    const j = aoa[iJ].map((c) => String(c).trim().toLowerCase()); const k = (awal) => j.findIndex((c) => c.startsWith(awal))
    const kk = { nis: j.indexOf('nis'), kode: k('kode'), per: k('periode'), nom: k('nominal'), bayar: k('dibayar'), tgl: k('tanggal'), cara: k('cara'), ket: k('keterangan') }
    const sel = (x, i) => (i >= 0 ? x[i] : '')
    const isi = aoa.slice(iJ + 1).filter((x) => String(sel(x, kk.nis)).trim() && String(sel(x, kk.kode)).trim()).map((x) => ({
      nis: String(sel(x, kk.nis)).trim(), kode: String(sel(x, kk.kode)).trim().toUpperCase(), periode: periode(sel(x, kk.per)),
      nominal: uang(sel(x, kk.nom)), dibayar: uang(sel(x, kk.bayar)), tanggal_bayar: tanggal(sel(x, kk.tgl)), cara: String(sel(x, kk.cara)).trim(), keterangan: String(sel(x, kk.ket)).trim() }))
    if (!isi.length) throw new Error('Tidak ada baris yang terisi kode biaya.')
    if (isi.length > 3000) throw new Error('Paling banyak 3.000 baris sekali impor; bagi menjadi beberapa berkas.')
    baris.value = isi; namaBerkas.value = berkas.name; tersimpan.value = false
    proses.value = true
    hasil.value = await keu.imporRiwayat({ uji: true, baris: isi })
  } catch (err) { ui.toast(err.message, 'galat') } finally { proses.value = false }
}
const hitung = computed(() => { const h = { dibuat: 0, dibayar: 0, ada: 0, galat: 0 }; for (const x of hasil.value || []) h[x.hasil]++; return h })
async function simpan() {
  proses.value = true
  try {
    hasil.value = await keu.imporRiwayat({ baris: baris.value }); tersimpan.value = true
    ui.toast(`${hitung.value.dibuat} tagihan dibuat, ${hitung.value.dibayar + hitung.value.dibuat} baris tersimpan${hitung.value.galat ? `, ${hitung.value.galat} galat dilewati` : ''}.`); emit('selesai')
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
const WARNA = { dibuat: 'w-presensi', dibayar: 'w-santri', ada: 'w-hakakses', galat: 'w-klinik' }
const NAMA = { dibuat: 'Dibuat', dibayar: 'Dibayar', ada: 'Sudah ada', galat: 'Galat' }
</script>
<template>
  <LembarBawah v-model="buka" judul="Impor catatan keuangan lama" lebar @update:model-value="(v) => !v && tutup()">
    <div class="w-keuangan space-y-4 pb-2">
      <p class="text-sm text-teks2">Untuk santri yang sudah membayar sejak tahun-tahun lalu: satu baris untuk satu tagihan per periode (bulan, semester, atau tahun ajaran).
        Tagihan dibuat bila belum ada dan pembayarannya dicatat sebagai <b>catatan pembayaran lama</b> (tanpa kuitansi bernomor baru). Berkas diperiksa dulu sebelum disimpan.</p>
      <div class="flex flex-wrap gap-2">
        <button class="tombol-garis" @click="templat"><PhDownloadSimple :size="20" /> Unduh templat</button>
        <button class="tombol-utama" :disabled="proses" @click="masukan.click()"><PhUploadSimple :size="20" weight="duotone" /> Pilih berkas Excel</button>
        <input ref="masukan" type="file" accept=".xlsx,.xls" class="hidden" @change="bacaBerkas" />
      </div>
      <p v-if="proses && !hasil" class="py-6 text-center text-teks3">Memeriksa berkas…</p>
      <template v-if="hasil">
        <p class="text-sm"><b>{{ namaBerkas }}</b> · {{ hasil.length }} baris {{ tersimpan ? 'diproses' : 'diperiksa (belum disimpan)' }}</p>
        <div class="flex flex-wrap gap-1.5">
          <span v-for="(n, k) in hitung" :key="k" :class="['lencana', WARNA[k]]">{{ NAMA[k] }} {{ n }}</span>
        </div>
        <div class="max-h-80 overflow-auto rounded-xl border border-garis">
          <table class="w-full text-left text-sm">
            <thead class="sticky top-0 bg-permukaan2"><tr><th class="px-2 py-2">Baris</th><th class="px-2 py-2">NIS</th><th class="px-2 py-2">Nama</th><th class="px-2 py-2">Tagihan</th><th class="px-2 py-2">Hasil</th><th class="px-2 py-2">Keterangan</th></tr></thead>
            <tbody class="divide-y divide-garis"><tr v-for="x in hasil" :key="x.baris">
              <td class="px-2 py-1.5 tabular-nums">{{ x.baris }}</td><td class="px-2 py-1.5 tabular-nums">{{ x.nis }}</td><td class="px-2 py-1.5">{{ x.nama || '–' }}</td>
              <td class="px-2 py-1.5">{{ x.tagihan || '–' }}</td><td class="px-2 py-1.5"><span :class="['lencana', WARNA[x.hasil]]">{{ NAMA[x.hasil] }}</span></td>
              <td class="px-2 py-1.5 text-xs text-teks2">{{ x.ket }}</td></tr></tbody>
          </table>
        </div>
        <button v-if="!tersimpan" class="tombol-utama w-full" :disabled="proses || hitung.galat === hasil.length" @click="simpan">
          <PhFloppyDisk :size="20" weight="duotone" /> {{ proses ? 'Menyimpan…' : `Simpan ${hasil.length - hitung.galat} baris${hitung.galat ? ` (${hitung.galat} galat dilewati)` : ''}` }}</button>
        <button v-else class="tombol-garis w-full" @click="buka = false"><PhCheckCircle :size="20" /> Selesai</button>
      </template>
    </div>
  </LembarBawah>
</template>
