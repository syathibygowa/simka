<!-- SIMKA PRO | src/pages/gaji/PeriodeRinci.vue | v1.7 | 14.13.0: satu tombol Impor (pilih jenis), Templat, Ekspor, Pratinjau | 19/10/2026 -->
<script setup>
// Rincian satu periode gaji: ringkasan, daftar pegawai (skema, penyesuaian, pendapatan, potongan, diterima),
// hitung ulang, impor jumlah diterima dari Excel, ekspor Excel, cetak Daftar Gaji F4 mendatar.
// Mengetuk pegawai membuka rincian komponennya (ubah nominal beralasan, tambah komponen, atur jumlah diterima).
import { ref, computed, onMounted, watch } from 'vue'
import * as XLSX from 'xlsx'
import { PhArrowLeft, PhArrowsClockwise, PhUploadSimple, PhFileXls, PhEye, PhTrash, PhMagnifyingGlass, PhUsersThree, PhCoins, PhScales, PhHandCoins,
  PhWarningCircle, PhDownloadSimple, PhFloppyDisk, PhPaperPlaneTilt, PhSignature, PhSealCheck, PhArrowUUpLeft, PhReceipt, PhXCircle, PhClock } from '@phosphor-icons/vue'
import { useGaji } from '@/stores/gaji'
import { useLembaga } from '@/stores/lembaga'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { useTeguran } from '@/stores/teguran'
import { formatPendek, formatPanjang, formatWaktu } from '@/lib/tanggal'
import { namaPeriode, STATUS_PERIODE, KOLOM_DAFTAR, perKolom, rupiah, angka, bacaRupiah } from '@/lib/gaji'
import KartuStatistik from '@/components/KartuStatistik.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import LembarBarisGaji from './LembarBarisGaji.vue'
import LembarImporKomponen from './LembarImporKomponen.vue'
import CetakSlip from '@/components/cetak/CetakSlip.vue'

const props = defineProps({ id: { type: String, required: true } })
const emit = defineEmits(['tutup'])
const gaji = useGaji(); const lembaga = useLembaga(); const sesi = useSesi(); const ui = useUI()
const r = ref(null); const memuat = ref(true); const proses = ref(false)
async function muat() {
  try { r.value = await gaji.rincianPeriode(props.id); if (!r.value?.periode) throw new Error('Periode gaji tidak ditemukan.') }
  catch (e) { ui.toast(e.message, 'galat'); emit('tutup') } finally { memuat.value = false }
}
onMounted(muat)
// Penanda surat teguran yang masih berlaku (informasi bagi bendahara; tidak memotong gaji secara otomatis)
const spAktif = ref({})
onMounted(async () => { spAktif.value = await useTeguran().spAktif() })
watch(() => props.id, muat)
const pr = computed(() => r.value?.periode || {})
const baris = computed(() => r.value?.baris || [])
const boleh = computed(() => !!gaji.hak.kelola && pr.value.status === 'draf')
const jml = (k) => baris.value.reduce((a, x) => a + Number(x[k] || 0), 0)

// ---------- Penerbitan: ajukan → tanda tangan Bendahara (dan Direktur) → terbit ----------
const ttd = computed(() => r.value?.ttd || [])
const ttdSaya = computed(() => pr.value.status === 'diajukan' && ttd.value.some((t) => t.status === 'menunggu' && t.saya))
const PERAN_TTD = { bendahara: 'Bendahara', direktur: 'Direktur' }
async function ajukan() {
  const kurang = baris.value.filter((b) => b.data.catatan?.length).length
  if (!(await ui.konfirmasi({ judul: `Ajukan penerbitan gaji ${namaPeriode(pr.value)}?`,
    pesan: `${baris.value.length} slip dengan jumlah diterima ${rupiah(jml('diterima'))} diajukan untuk ditandatangani Bendahara${gaji.pengaturan.ttd_direktur ? ' dan Direktur' : ''}.`
      + (kurang ? ` Perhatian: ${kurang} pegawai masih memiliki data kurang.` : '') + ' Setelah terbit, slip terkunci dan hanya dapat diubah lewat revisi.', ya: 'Ajukan' }))) return
  proses.value = true
  try { const h = await gaji.ajukanTerbit(props.id); await muat(); ui.toast(h === 'terbit' ? 'Gaji terbit. Slip terkunci dan bertanda tangan elektronik.' : 'Diajukan. Menunggu tanda tangan.') }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
const fTolak = ref(null)
async function tandatangani(setuju) {
  if (!setuju && (!fTolak.value || fTolak.value.trim().length < 3)) { fTolak.value = fTolak.value ?? ''; return ui.toast('Tulis alasan penolakan.', 'galat') }
  if (setuju && !(await ui.konfirmasi({ judul: 'Tanda tangani daftar gaji?', pesan: `Gaji ${namaPeriode(pr.value)}: ${baris.value.length} pegawai, ${rupiah(jml('diterima'))}. Tanda tangan elektronik Anda tercantum di setiap slip.`, ya: 'Tanda tangani' }))) return
  proses.value = true
  try { const h = await gaji.tandatangani(props.id, setuju, fTolak.value); fTolak.value = null; await muat()
    ui.toast(h === 'terbit' ? 'Ditandatangani. Gaji terbit.' : h === 'ditolak' ? 'Pengajuan dikembalikan ke draf.' : 'Ditandatangani. Menunggu penanda tangan lain.') }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
async function tarik() {
  if (!(await ui.konfirmasi({ judul: 'Tarik pengajuan?', pesan: 'Periode kembali menjadi draf dan tanda tangan yang sudah ada dihapus.', ya: 'Tarik' }))) return
  try { await gaji.tarikPengajuan(props.id); await muat(); ui.toast('Pengajuan ditarik.') } catch (e) { ui.toast(e.message, 'galat') }
}
// Cetak slip (semua yang tampil, atau satu)
const slipCetak = ref([]); const pratinjauSlip = ref(false)
const keSlip = (b) => ({ ...b, periode: pr.value, ttd: ttd.value })
function cetakSlip(daftar) { slipCetak.value = daftar.map(keSlip); pratinjauSlip.value = true }

// ---------- Saringan ----------
const cari = ref(''); const saring = ref('')
const diubah = (b) => b.item.some((i) => i.sumber === 'manual' && i.kategori !== 'penyesuaian') || b.target_diterima != null
const SARING = computed(() => [
  { k: '', n: 'Semua', j: baris.value.length },
  { k: 'sesuai', n: 'Ada penyesuaian', j: baris.value.filter((b) => Number(b.total_penyesuaian)).length },
  { k: 'ubah', n: 'Diubah', j: baris.value.filter(diubah).length },
  { k: 'kurang', n: 'Data kurang', j: baris.value.filter((b) => b.data.catatan?.length).length },
  { k: 'berubah', n: 'Berubah dari bulan lalu', j: baris.value.filter((b) => beda(b)).length },
])
// Selisih jumlah diterima terhadap periode sebelumnya (null bila pegawai tidak ada pada periode sebelumnya)
const beda = (b) => (b.bulan_lalu ? Number(b.diterima) - Number(b.bulan_lalu.diterima) : null)
const teksBeda = (b) => { const v = beda(b); return v == null ? '' : (v > 0 ? '▲ +' : '▼ −') + rupiah(Math.abs(v)) }
const tampil = computed(() => {
  const q = cari.value.toLowerCase().trim()
  return baris.value.filter((b) => (!q || [b.data.nama, b.data.niy, b.data.jabatan_struktural, ...(b.data.jabatan_fungsional || [])].join(' ').toLowerCase().includes(q))
    && (!saring.value || (saring.value === 'sesuai' ? Number(b.total_penyesuaian) : saring.value === 'ubah' ? diubah(b) : saring.value === 'berubah' ? beda(b) : b.data.catatan?.length)))
})
const jabatan = (d) => [d.jabatan_struktural, ...(d.jabatan_fungsional || [])].filter(Boolean).join(', ') || '–'

// ---------- Aksi periode ----------
async function hitungUlang() {
  if (!(await ui.konfirmasi({ judul: 'Hitung ulang periode?', pesan: 'Komponen skema, honor per jam, dan penetapan yayasan dihitung ulang dari data terbaru. Nominal yang sudah Anda ubah dan jumlah diterima yang ditetapkan tetap dipertahankan.', ya: 'Hitung ulang' }))) return
  proses.value = true
  try { await gaji.hitungUlang(props.id); await muat(); ui.toast('Periode gaji dihitung ulang.') } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
async function hapus() {
  if (!(await ui.konfirmasi({ judul: `Hapus periode ${namaPeriode(pr.value)}?`, pesan: 'Semua baris dan perubahan pada periode ini ikut terhapus. Penetapan yayasan, tarif, dan rekening tidak terpengaruh.', ya: 'Hapus periode', bahaya: true }))) return
  try { await gaji.hapusPeriode(props.id); ui.toast('Periode gaji dihapus.'); emit('tutup') } catch (e) { ui.toast(e.message, 'galat') }
}
const fBayar = ref(null)
async function simpanBayar() {
  try { await gaji.ubahPeriode(props.id, { tanggal_bayar: fBayar.value.tanggal_bayar, catatan: fBayar.value.catatan }); fBayar.value = null; await muat(); ui.toast('Periode diperbarui.') }
  catch (e) { ui.toast(e.message, 'galat') }
}

// ---------- Excel ----------
const nmBerkas = (s) => `${s}-${namaPeriode(pr.value).replace(' ', '-')}.xlsx`
function ekspor() {
  const judul = ['No.', 'NIY', 'Nama', 'JK', 'Jabatan', 'Status', ...KOLOM_DAFTAR.map((k) => k[1]), 'Jumlah pendapatan', 'Potongan', 'Jumlah diterima',
    'Menurut skema', 'Cara bayar', 'Bank', 'Nomor rekening', 'Atas nama', 'Keterangan']
  const data = tampil.value.map((b, i) => { const k = perKolom(b.item); const rk = b.data.rekening || {}
    return [i + 1, b.data.niy || '', b.data.nama, b.data.jk || '', jabatan(b.data), b.data.status || '', ...KOLOM_DAFTAR.map(([c]) => k[c] || 0),
      Number(b.total_pendapatan), Number(b.total_potongan), Number(b.diterima), Number(b.total_skema), rk.cara_bayar || '', rk.bank || '', rk.nomor_rekening || '', rk.atas_nama || '',
      [b.alasan_target, ...b.item.filter((x) => x.kategori === 'penyesuaian' && x.alasan).map((x) => x.alasan)].filter(Boolean)[0] || ''] })
  data.push(['', '', 'Jumlah', '', '', '', ...KOLOM_DAFTAR.map(([c]) => tampil.value.reduce((a, b) => a + (perKolom(b.item)[c] || 0), 0)),
    jml('total_pendapatan'), jml('total_potongan'), jml('diterima'), jml('total_skema')])
  const ws = XLSX.utils.aoa_to_sheet([[`Daftar Gaji Pegawai – ${namaPeriode(pr.value)}`], [], judul, ...data])
  ws['!cols'] = judul.map((j, i) => ({ wch: i === 2 ? 32 : i === 4 ? 30 : Math.max(10, Math.min(20, j.length + 2)) }))
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Daftar gaji'); XLSX.writeFile(wb, nmBerkas('Daftar-Gaji'))
}
function templat() {
  const judul = ['NIY', 'Nama', 'Menurut skema', 'Jumlah diterima', 'Keterangan']
  const data = baris.value.map((b) => [b.data.niy || '', b.data.nama, Number(b.total_skema), b.target_diterima != null ? Number(b.target_diterima) : '', b.alasan_target || ''])
  const ws = XLSX.utils.aoa_to_sheet([judul, ...data])
  for (let i = 1; i <= data.length; i++) { const a = XLSX.utils.encode_cell({ r: i, c: 0 }); if (ws[a]) { ws[a].t = 's'; ws[a].z = '@' } }
  ws['!cols'] = [12, 34, 16, 18, 40].map((wch) => ({ wch }))
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Jumlah diterima'); XLSX.writeFile(wb, nmBerkas('Templat-Gaji-Diterima'))
}
const masukan = ref(null); const impor = ref(null); const imporKomponen = ref(false); const pilihImpor = ref(false)
async function bacaBerkas(e) {
  const berkas = e.target.files?.[0]; e.target.value = ''
  if (!berkas) return
  try {
    const wb = XLSX.read(await berkas.arrayBuffer())
    const aoa = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]], { header: 1, raw: false, defval: '' })
    const iJ = aoa.findIndex((x) => x.some((c) => /^niy$/i.test(String(c).trim())))
    if (iJ < 0) throw new Error('Kolom NIY tidak ditemukan. Pakai berkas dari tombol "Templat jumlah diterima".')
    const j = aoa[iJ].map((c) => String(c).trim().toLowerCase())
    const kNiy = j.indexOf('niy'); const kNama = j.findIndex((c) => c.startsWith('nama'))
    const kTerima = j.findIndex((c) => c.includes('diterima') || c === 'gaji' || c.includes('jumlah gaji') || c.includes('total gaji'))
    const kKet = j.findIndex((c) => c.startsWith('keterangan'))
    if (kTerima < 0) throw new Error('Kolom "Jumlah diterima" tidak ditemukan.')
    const isi = aoa.slice(iJ + 1).filter((x) => String(x[kNiy]).trim() && String(x[kTerima]).trim())
      .map((x) => ({ niy: String(x[kNiy]).trim(), nama: kNama >= 0 ? String(x[kNama]).trim() : '', diterima: bacaRupiah(x[kTerima]), keterangan: kKet >= 0 ? String(x[kKet]).trim() : '' }))
    if (!isi.length) throw new Error('Tidak ada baris dengan jumlah diterima terisi.')
    impor.value = { isi, hasil: null, keterangan: 'Data gaji diterima (ketetapan yayasan)' }
  } catch (err) { ui.toast(err.message, 'galat') }
}
async function jalankanImpor() {
  proses.value = true
  try {
    impor.value.hasil = await gaji.imporDiterima(props.id, impor.value.isi.map((x) => ({ ...x, keterangan: x.keterangan || impor.value.keterangan })))
    ui.toast(`${impor.value.hasil.disimpan} pegawai diperbarui.`); await muat()
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
const skemaNiy = (niy) => baris.value.find((b) => b.data.niy === niy)

// ---------- Rincian pegawai & cetak ----------
const pilihId = ref('')
const pilihan = computed(() => baris.value.find((b) => b.id === pilihId.value) || null)
const pratinjau = ref(false)
const direktur = computed(() => lembaga.signatories.find((s) => /^direktur$/i.test(s.jabatan_tertulis)) || {})
const jumlahKolom = computed(() => Object.fromEntries(KOLOM_DAFTAR.map(([c]) => [c, tampil.value.reduce((a, b) => a + (perKolom(b.item)[c] || 0), 0)])))
</script>
<template>
  <div>
    <p v-if="memuat" class="kartu p-8 text-center text-sm text-teks3">Memuat…</p>
    <template v-else-if="r">
      <!-- Kepala -->
      <div class="mb-4 flex flex-wrap items-center gap-3">
        <button class="tombol-ikon shrink-0" @click="emit('tutup')" aria-label="Kembali ke daftar periode"><PhArrowLeft :size="22" /></button>
        <div class="min-w-0 flex-1">
          <h2 class="flex flex-wrap items-center gap-2 text-xl font-extrabold">Gaji {{ namaPeriode(pr) }}
            <span :class="['lencana', 'w-' + STATUS_PERIODE[pr.status].w]">{{ STATUS_PERIODE[pr.status].n }}</span></h2>
          <p class="text-sm text-teks3">Dibayar {{ formatPanjang(pr.tanggal_bayar) }}<template v-if="pr.dihitung_pada"> · dihitung {{ formatWaktu(pr.dihitung_pada) }}</template>
            <button v-if="boleh" class="ml-1 font-semibold text-merah" @click="fBayar = { tanggal_bayar: pr.tanggal_bayar, catatan: pr.catatan || '' }">Ubah</button></p>
          <p v-if="pr.catatan" class="text-sm text-teks2">{{ pr.catatan }}</p>
        </div>
      </div>

      <!-- Penerbitan -->
      <p v-if="pr.status === 'draf' && pr.alasan_tolak" class="w-klinik mb-3 flex gap-2 rounded-xl p-3 text-sm font-semibold" style="color: var(--c); background: color-mix(in srgb, var(--c) 10%, transparent)">
        <PhXCircle :size="18" class="mt-0.5 shrink-0" /> Dikembalikan penanda tangan: {{ pr.alasan_tolak }}</p>
      <section v-if="pr.status !== 'draf' || boleh" :class="['kartu mb-4 p-4', pr.status === 'terbit' ? 'w-presensi' : pr.status === 'diajukan' ? 'w-verifikasi' : 'w-tahfizh']">
        <div class="flex flex-wrap items-center gap-3">
          <span class="chip-ikon h-11 w-11 shrink-0"><component :is="pr.status === 'terbit' ? PhSealCheck : pr.status === 'diajukan' ? PhSignature : PhPaperPlaneTilt" :size="24" weight="duotone" /></span>
          <div class="min-w-[200px] flex-1">
            <p class="font-bold">{{ pr.status === 'terbit' ? 'Slip terbit dan terkunci' : pr.status === 'diajukan' ? 'Menunggu tanda tangan elektronik' : 'Siap diterbitkan?' }}</p>
            <p class="text-sm text-teks3">{{ pr.status === 'terbit' ? `Diterbitkan ${formatWaktu(pr.diterbitkan_pada)}. Perubahan hanya lewat revisi slip per pegawai.`
              : pr.status === 'diajukan' ? `Diajukan ${formatWaktu(pr.diajukan_pada)}.` : `Periksa daftar, lalu ajukan untuk ditandatangani Bendahara${gaji.pengaturan.ttd_direktur ? ' dan Direktur' : ''}.` }}</p>
          </div>
          <button v-if="boleh" class="tombol-utama" :disabled="proses" @click="ajukan"><PhPaperPlaneTilt :size="20" weight="duotone" /> Ajukan terbit</button>
          <button v-if="pr.status === 'terbit' && baris.length" class="tombol-utama" @click="cetakSlip(tampil)"><PhReceipt :size="20" weight="duotone" /> Cetak slip ({{ tampil.length }})</button>
          <button v-if="pr.status === 'diajukan' && gaji.hak.kelola" class="tombol-garis" @click="tarik"><PhArrowUUpLeft :size="20" /> Tarik pengajuan</button>
        </div>
        <ul v-if="ttd.length" class="mt-3 flex flex-wrap gap-2">
          <li v-for="t in ttd" :key="t.peran" :class="['lencana', t.status === 'ditandatangani' ? 'w-presensi' : t.status === 'ditolak' ? 'w-klinik' : 'w-tahfizh']">
            <component :is="t.status === 'ditandatangani' ? PhSealCheck : PhClock" :size="14" />
            {{ PERAN_TTD[t.peran] }}: {{ t.status === 'ditandatangani' ? `${t.nama}, ${formatWaktu(t.waktu)}` : 'menunggu' }}</li>
        </ul>
        <div v-if="ttdSaya" class="mt-3 space-y-2 rounded-xl bg-permukaan2 p-3">
          <p class="text-sm font-semibold">Anda diminta menandatangani daftar gaji ini.</p>
          <input v-if="fTolak !== null" v-model="fTolak" class="isian" placeholder="Alasan penolakan (wajib bila menolak)" aria-label="Alasan penolakan" />
          <div class="flex flex-wrap gap-2">
            <button class="tombol-utama" :disabled="proses" @click="tandatangani(true)"><PhSignature :size="20" weight="duotone" /> Tanda tangani</button>
            <button class="tombol-garis" :disabled="proses" @click="fTolak === null ? (fTolak = '') : tandatangani(false)"><PhXCircle :size="20" /> {{ fTolak === null ? 'Tolak' : 'Kirim penolakan' }}</button>
          </div>
        </div>
      </section>

      <div class="-mx-4 mb-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-4 sm:overflow-visible sm:px-0">
        <KartuStatistik class="w-[44%] shrink-0 snap-start sm:w-auto" judul="Pegawai" :nilai="baris.length" :ikon="PhUsersThree" warna="pegawai" :keterangan="`${SARING[3].j} data kurang`" />
        <KartuStatistik class="w-[72%] shrink-0 snap-start sm:w-auto" judul="Menurut skema" :nilai="rupiah(jml('total_skema'))" :ikon="PhCoins" warna="tahfizh" keterangan="Tarif dan honor per jam" />
        <KartuStatistik class="w-[72%] shrink-0 snap-start sm:w-auto" judul="Penyesuaian" :nilai="rupiah(jml('total_penyesuaian'))" :ikon="PhScales" warna="verifikasi" :keterangan="`${SARING[1].j} pegawai`" />
        <KartuStatistik class="w-[72%] shrink-0 snap-start sm:w-auto" judul="Jumlah diterima" :nilai="rupiah(jml('diterima'))" :ikon="PhHandCoins" warna="presensi" :keterangan="`Potongan ${rupiah(jml('total_potongan'))}`" />
      </div>

      <div class="mb-4 flex flex-wrap items-center gap-2">
        <div class="relative min-w-[200px] flex-1"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
          <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari nama, NIY, atau jabatan" aria-label="Cari pegawai" /></div>
        <button v-if="boleh" class="tombol-garis" :disabled="proses" @click="hitungUlang"><PhArrowsClockwise :size="20" /> Hitung ulang</button>
        <button v-if="boleh" class="tombol-garis" @click="templat"><PhDownloadSimple :size="20" /> Templat</button>
        <button v-if="boleh" class="tombol-garis" @click="pilihImpor = true"><PhUploadSimple :size="20" weight="duotone" /> Impor</button>
        <input ref="masukan" type="file" accept=".xlsx,.xls" class="hidden" @change="bacaBerkas" />
        <button class="tombol-garis" @click="ekspor"><PhFileXls :size="20" weight="duotone" /> Ekspor</button>
        <button class="tombol-garis" @click="pratinjau = true"><PhEye :size="20" weight="duotone" /> Pratinjau</button>
        <button v-if="boleh" class="tombol-garis" @click="hapus"><PhTrash :size="20" /> Hapus</button>
      </div>
      <div class="-mx-4 mb-3 flex gap-1.5 overflow-x-auto px-4 sm:mx-0 sm:px-0" role="group" aria-label="Saring pegawai">
        <div class="bilah-tab kecil" role="tablist" aria-label="Saring pegawai">
          <button v-for="s in SARING" :key="s.k" type="button" @click="saring = s.k"
          :class="['tab-garis', (saring === s.k) && 'aktif']" role="tab" :aria-selected="saring === s.k">
          {{ s.n }} <span class="angka-tab">{{ s.j }}</span></button>
        </div>
      </div>

      <p v-if="!tampil.length" class="kartu p-8 text-center text-sm text-teks3">Tidak ada pegawai yang sesuai.</p>
      <!-- Tabel desktop -->
      <div v-else class="kartu hidden overflow-x-auto lg:block">
        <table class="w-full text-left text-sm">
          <thead class="border-b border-garis bg-permukaan2 text-teks2"><tr>
            <th class="px-3 py-3 font-bold">NIY</th><th class="px-3 py-3 font-bold">Nama dan jabatan</th>
            <th class="px-3 py-3 text-right font-bold">Menurut skema</th><th class="px-3 py-3 text-right font-bold">Penyesuaian</th>
            <th class="px-3 py-3 text-right font-bold">Pendapatan</th><th class="px-3 py-3 text-right font-bold">Potongan</th>
            <th class="px-3 py-3 text-right font-bold">Diterima</th><th class="px-3 py-3 font-bold">Keterangan</th></tr></thead>
          <tbody class="divide-y divide-garis">
            <tr v-for="b in tampil" :key="b.id" class="cursor-pointer align-top hover:bg-permukaan2" @click="pilihId = b.id">
              <td class="px-3 py-2.5 tabular-nums text-teks2">{{ b.data.niy || '–' }}</td>
              <td class="px-3 py-2.5"><p class="font-semibold">{{ b.data.nama }}</p><p class="text-xs text-teks3">{{ jabatan(b.data) }}</p></td>
              <td class="px-3 py-2.5 text-right tabular-nums text-teks2">{{ rupiah(b.total_skema) }}</td>
              <td :class="['px-3 py-2.5 text-right font-semibold tabular-nums', Number(b.total_penyesuaian) < 0 ? 'w-klinik' : 'w-presensi']" :style="Number(b.total_penyesuaian) ? 'color: var(--c)' : ''">
                {{ Number(b.total_penyesuaian) ? (Number(b.total_penyesuaian) > 0 ? '+' : '') + rupiah(b.total_penyesuaian) : '–' }}</td>
              <td class="px-3 py-2.5 text-right tabular-nums">{{ rupiah(b.total_pendapatan) }}</td>
              <td class="px-3 py-2.5 text-right tabular-nums">{{ Number(b.total_potongan) ? rupiah(b.total_potongan) : '–' }}</td>
              <td class="px-3 py-2.5 text-right font-extrabold tabular-nums">{{ rupiah(b.diterima) }}
                <p v-if="beda(b)" :class="['text-xs font-semibold', beda(b) > 0 ? 'w-presensi' : 'w-pengajuan']" style="color: var(--c)" :title="`${b.bulan_lalu.periode}: ${rupiah(b.bulan_lalu.diterima)}`">{{ teksBeda(b) }}</p></td>
              <td class="max-w-[220px] px-3 py-2.5 text-xs">
                <span v-if="b.target_diterima != null" class="lencana w-verifikasi mb-0.5">Ditetapkan</span>
                <span v-else-if="b.item.some((i) => i.sumber === 'penetapan')" class="lencana w-verifikasi mb-0.5">Ketetapan yayasan</span>
                <span v-if="b.item.some((i) => i.sumber === 'manual' && i.kategori !== 'penyesuaian')" class="lencana w-pengajuan mb-0.5">Diubah</span>
                <span v-if="b.dalam_revisi" class="lencana w-klinik mb-0.5">Sedang direvisi</span>
                <span v-else-if="b.revisi_ke" class="lencana w-shift mb-0.5">Revisi ke-{{ b.revisi_ke }}</span>
                <span v-if="b.dibuka_pegawai" class="lencana w-presensi mb-0.5">Dibuka untuk pegawai</span>
                <span v-if="spAktif[b.employee_id]" class="lencana w-klinik mb-0.5" title="Surat teguran masih berlaku">SP-{{ spAktif[b.employee_id] }} aktif</span>
                <p v-if="b.data.catatan?.length" class="w-klinik font-semibold" style="color: var(--c)">{{ b.data.catatan[0] }}<template v-if="b.data.catatan.length > 1"> (+{{ b.data.catatan.length - 1 }})</template></p>
              </td>
            </tr>
          </tbody>
          <tfoot class="border-t-2 border-garis bg-permukaan2 font-bold"><tr>
            <td class="px-3 py-3" colspan="2">Jumlah ({{ tampil.length }} pegawai)</td>
            <td class="px-3 py-3 text-right tabular-nums">{{ rupiah(tampil.reduce((a, b) => a + Number(b.total_skema), 0)) }}</td>
            <td class="px-3 py-3 text-right tabular-nums">{{ rupiah(tampil.reduce((a, b) => a + Number(b.total_penyesuaian), 0)) }}</td>
            <td class="px-3 py-3 text-right tabular-nums">{{ rupiah(tampil.reduce((a, b) => a + Number(b.total_pendapatan), 0)) }}</td>
            <td class="px-3 py-3 text-right tabular-nums">{{ rupiah(tampil.reduce((a, b) => a + Number(b.total_potongan), 0)) }}</td>
            <td class="px-3 py-3 text-right tabular-nums">{{ rupiah(tampil.reduce((a, b) => a + Number(b.diterima), 0)) }}</td><td /></tr></tfoot>
        </table>
      </div>
      <!-- Kartu HP -->
      <ul class="space-y-2.5 lg:hidden">
        <li v-for="b in tampil" :key="b.id">
          <button class="kartu w-full p-4 text-left active:bg-permukaan2" @click="pilihId = b.id">
            <div class="flex items-start gap-2">
              <div class="min-w-0 flex-1"><p class="font-bold">{{ b.data.nama }}</p><p class="truncate text-sm text-teks3">{{ jabatan(b.data) }}</p></div>
              <p class="shrink-0 text-lg font-extrabold tabular-nums">{{ rupiah(b.diterima) }}</p>
            </div>
            <div class="mt-2 flex flex-wrap gap-1">
              <span class="lencana w-tahfizh">Skema {{ rupiah(b.total_skema) }}</span>
              <span v-if="Number(b.total_penyesuaian)" :class="['lencana', Number(b.total_penyesuaian) < 0 ? 'w-klinik' : 'w-presensi']">Penyesuaian {{ Number(b.total_penyesuaian) > 0 ? '+' : '' }}{{ rupiah(b.total_penyesuaian) }}</span>
              <span v-if="b.item.some((i) => i.sumber === 'manual' && i.kategori !== 'penyesuaian')" class="lencana w-pengajuan">Diubah</span>
              <span v-if="b.data.catatan?.length" class="lencana w-klinik"><PhWarningCircle :size="12" /> {{ b.data.catatan.length }} data kurang</span>
              <span v-if="spAktif[b.employee_id]" class="lencana w-klinik">SP-{{ spAktif[b.employee_id] }} aktif</span>
              <span v-if="beda(b)" :class="['lencana', beda(b) > 0 ? 'w-presensi' : 'w-pengajuan']">{{ teksBeda(b) }} dari {{ b.bulan_lalu.periode }}</span>
            </div>
          </button>
        </li>
      </ul>

      <LembarBarisGaji :baris="pilihan" :periode="pr" :boleh="boleh || !!pilihan?.dalam_revisi && !!gaji.hak.kelola" @tutup="pilihId = ''" @berubah="muat"
        @cetak="(b) => cetakSlip([b])" />
      <CetakSlip v-model:pratinjau="pratinjauSlip" :slip="slipCetak" :pengaturan="gaji.pengaturan" :pencetak="sesi.pengguna?.nama_lengkap" />

      <!-- Ubah tanggal bayar -->
      <LembarBawah v-model="pilihImpor" judul="Impor dari Excel">
        <div class="space-y-2 pb-2">
          <button class="tombol-garis w-full justify-start" @click="pilihImpor = false; masukan.click()"><PhUploadSimple :size="20" weight="duotone" /> Jumlah gaji diterima (berkas Templat)</button>
          <button class="tombol-garis w-full justify-start" @click="pilihImpor = false; imporKomponen = true"><PhUploadSimple :size="20" weight="duotone" /> Jam honor, potongan, dan tambahan</button>
        </div>
      </LembarBawah>
      <LembarBawah :model-value="!!fBayar" @update:model-value="(x) => !x && (fBayar = null)" judul="Ubah periode">
        <div v-if="fBayar" class="space-y-4 pb-2">
          <InputTanggal v-model="fBayar.tanggal_bayar" label="Tanggal pembayaran" />
          <div><label class="label-isian" for="pr-cat">Catatan periode (tidak wajib)</label><input id="pr-cat" v-model="fBayar.catatan" class="isian" placeholder="Contoh: gaji dan insentif ujian" /></div>
          <button class="tombol-utama w-full" @click="simpanBayar"><PhFloppyDisk :size="20" weight="duotone" /> Simpan</button>
        </div>
      </LembarBawah>

      <!-- Impor jumlah diterima -->
      <LembarImporKomponen :periode="imporKomponen ? pr : null" :baris="baris" @tutup="imporKomponen = false" @selesai="muat" />
      <LembarBawah :model-value="!!impor" @update:model-value="(x) => !x && (impor = null)" judul="Impor jumlah diterima" lebar>
        <div v-if="impor" class="space-y-4 pb-2">
          <p class="text-sm text-teks2">{{ impor.isi.length }} baris terbaca. Jumlah diterima menjadi nominal slip; selisihnya dengan hasil hitung tampil sebagai
            "{{ gaji.pengaturan.label_penyesuaian }}". Pegawai lain tidak berubah.</p>
          <div><label class="label-isian" for="im-ket">Keterangan bawaan (bila kolom keterangan kosong)</label><input id="im-ket" v-model="impor.keterangan" class="isian" /></div>
          <div class="max-h-[45dvh] overflow-auto rounded-xl border border-garis">
            <table class="w-full text-left text-sm">
              <thead class="sticky top-0 bg-permukaan2"><tr><th class="px-2 py-2">NIY</th><th class="px-2 py-2">Nama</th><th class="px-2 py-2 text-right">Hasil hitung</th>
                <th class="px-2 py-2 text-right">Diterima</th><th class="px-2 py-2 text-right">Selisih</th><th class="px-2 py-2">Hasil</th></tr></thead>
              <tbody class="divide-y divide-garis">
                <tr v-for="(x, i) in impor.isi" :key="i">
                  <td class="px-2 py-1.5 tabular-nums">{{ x.niy }}</td><td class="px-2 py-1.5">{{ skemaNiy(x.niy)?.data.nama || x.nama || '–' }}</td>
                  <td class="px-2 py-1.5 text-right tabular-nums">{{ skemaNiy(x.niy) ? angka(skemaNiy(x.niy).diterima - (skemaNiy(x.niy).total_penyesuaian || 0)) : '–' }}</td>
                  <td class="px-2 py-1.5 text-right font-semibold tabular-nums">{{ x.diterima == null ? 'tidak sah' : angka(x.diterima) }}</td>
                  <td class="px-2 py-1.5 text-right tabular-nums">{{ skemaNiy(x.niy) && x.diterima != null ? angka(x.diterima - (skemaNiy(x.niy).diterima - (skemaNiy(x.niy).total_penyesuaian || 0))) : '–' }}</td>
                  <td class="px-2 py-1.5 text-xs font-semibold">
                    <template v-if="impor.hasil"><span v-if="impor.hasil.gagal.find((g) => g.baris === i + 1)" class="w-klinik" style="color: var(--c)">{{ impor.hasil.gagal.find((g) => g.baris === i + 1).pesan }}</span>
                      <span v-else class="w-presensi" style="color: var(--c)">Tersimpan</span></template>
                    <span v-else class="text-teks3">Belum</span></td>
                </tr>
              </tbody>
            </table>
          </div>
          <button v-if="!impor.hasil" class="tombol-utama w-full" :disabled="proses" @click="jalankanImpor"><PhUploadSimple :size="20" weight="duotone" /> {{ proses ? 'Menyimpan…' : 'Simpan jumlah diterima' }}</button>
          <button v-else class="tombol-garis w-full" @click="impor = null">Selesai</button>
        </div>
      </LembarBawah>

      <!-- Daftar Gaji F4 mendatar -->
      <DokumenCetak v-model:pratinjau="pratinjau" mendatar judul="Daftar Gaji Pegawai"
        :subjudul="`Periode ${namaPeriode(pr)} · dibayar ${formatPendek(pr.tanggal_bayar)}${pr.status === 'draf' ? ' · DRAF' : ''}`" :pencetak="sesi.pengguna?.nama_lengkap">
        <table class="tabel kecil">
          <colgroup><col style="width:3%"><col style="width:7%"><col style="width:15%"><col v-for="k in KOLOM_DAFTAR" :key="k[0]" style="width:6.6%"><col style="width:6%"><col style="width:8%"><col style="width:8.2%"></colgroup>
          <thead><tr><th>No.</th><th>NIY</th><th>Nama</th><th v-for="k in KOLOM_DAFTAR" :key="k[0]">{{ k[1] }}</th><th>Potongan</th><th>Diterima</th><th>Tanda terima</th></tr></thead>
          <tbody>
            <tr v-for="(b, i) in tampil" :key="b.id">
              <td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ b.data.niy || '–' }}</td><td>{{ b.data.nama }}</td>
              <td v-for="k in KOLOM_DAFTAR" :key="k[0]" class="kanan">{{ perKolom(b.item)[k[0]] ? angka(perKolom(b.item)[k[0]]) : '–' }}</td>
              <td class="kanan">{{ Number(b.total_potongan) ? angka(b.total_potongan) : '–' }}</td><td class="kanan">{{ angka(b.diterima) }}</td>
              <td>{{ i + 1 }}.</td>
            </tr>
            <tr><td></td><td></td><td>Jumlah</td><td v-for="k in KOLOM_DAFTAR" :key="k[0]" class="kanan">{{ angka(jumlahKolom[k[0]]) }}</td>
              <td class="kanan">{{ angka(tampil.reduce((a, b) => a + Number(b.total_potongan), 0)) }}</td><td class="kanan">{{ angka(tampil.reduce((a, b) => a + Number(b.diterima), 0)) }}</td><td></td></tr>
          </tbody>
        </table>
        <p class="catatan-cetak">Nominal dalam rupiah. Kolom penyesuaian memuat {{ gaji.pengaturan.label_penyesuaian.toLowerCase() }}.</p>
        <template #ttd>
          <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan_tertulis || 'Direktur', nama: direktur.nama || '', niy: direktur.niy }"
            :kanan="{ jabatan: gaji.jabatanSaya, nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" :tanggal="pr.tanggal_bayar" />
        </template>
      </DokumenCetak>
    </template>
  </div>
</template>
