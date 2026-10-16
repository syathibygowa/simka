<!-- SIMKA PRO | src/pages/santri/KelengkapanSantri.vue | v1.1 | Perbaikan 13.9.0: kembali ke posisi semula dan pindah ke santri berikutnya | 16/10/2026 -->
<script setup>
// Kelengkapan data santri di seluruh basis data: identitas, alamat, orang tua/wali, masuk dan sekolah asal, kelompok pondok.
// Kartu statistik langsung, kolom yang paling sering kosong (ketuk untuk menyaring), daftar santri beserta data yang belum diisi,
// v1.1: saat kembali dari formulir, saringan dan posisi gulir dipulihkan serta santri terakhir ditandai; di formulir tersedia
//       tombol Sebelumnya/Berikutnya mengikuti urutan daftar ini (NavKelengkapan).
// tombol Lengkapi (ke formulir santri), ekspor Excel, dan cetak F4 berkop. Kolom yang diperiksa dapat diatur (tersimpan di peramban).
import { ref, computed, onMounted, watch, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import * as XLSX from 'xlsx'
import {
  PhListMagnifyingGlass, PhUsersThree, PhSealCheck, PhWarningCircle, PhGauge, PhMagnifyingGlass, PhPrinter, PhFileXls, PhSlidersHorizontal,
  PhPencilSimple, PhX, PhArrowCounterClockwise,
} from '@phosphor-icons/vue'
import { useSantri } from '@/stores/santri'
import { useSesi } from '@/stores/sesi'
import { useLembaga } from '@/stores/lembaga'
import { TINGKAT, labelRombel, inisial } from '@/lib/santri'
import { KATEGORI_KELENGKAPAN, SEMUA_KOLOM, KOLOM_BAWAAN, periksaSantri } from '@/lib/kelengkapanSantri'
import { formatPendek, hariIniISO } from '@/lib/tanggal'
import KartuStatistik from '@/components/KartuStatistik.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const san = useSantri(); const sesi = useSesi(); const lembaga = useLembaga(); const router = useRouter()
// Keadaan halaman (saringan, posisi gulir, santri terakhir dibuka) disimpan selama sesi peramban
const KUNCI_KEADAAN = 'simka.kelengkapan.keadaan'
const keadaan = (() => { try { return JSON.parse(sessionStorage.getItem(KUNCI_KEADAAN)) || {} } catch { return {} } })()
const terakhir = ref(keadaan.terakhir || '')
onMounted(async () => {
  lembaga.muat(); await san.muat()
  if (keadaan.y != null) {
    await nextTick(); await new Promise((r) => setTimeout(r, 60))
    const el = terakhir.value && [...document.querySelectorAll(`[data-santri="${terakhir.value}"]`)].find((x) => x.offsetParent)
    if (el) el.scrollIntoView({ block: 'center' }); else window.scrollTo(0, keadaan.y)
  }
})
const bolehUbah = computed(() => sesi.bolehAdmin('kelola_santri') || sesi.tingkat('data_santri') >= 2)

// Kolom yang diperiksa (per pengguna, di peramban)
const KUNCI = 'simka.kelengkapan.kolom'
const aktif = ref((() => { try { const v = JSON.parse(localStorage.getItem(KUNCI)); return Array.isArray(v) && v.length ? v : [...KOLOM_BAWAAN] } catch { return [...KOLOM_BAWAAN] } })())
watch(aktif, (v) => { try { localStorage.setItem(KUNCI, JSON.stringify(v)) } catch { /* abaikan */ } }, { deep: true })
const lembarKolom = ref(false)
const togelKolom = (k) => { const i = aktif.value.indexOf(k); if (i >= 0) { if (aktif.value.length > 1) aktif.value.splice(i, 1) } else aktif.value.push(k) }
const kolomAktif = computed(() => SEMUA_KOLOM.filter((c) => aktif.value.includes(c.k)))

// Saringan
const sr = keadaan.saring || {}
const cari = ref(sr.cari || ''); const jenjang = ref(sr.jenjang || 'semua'); const tingkat = ref(sr.tingkat || ''); const jk = ref(sr.jk || ''); const kategori = ref(sr.kategori || 'semua')
const kolom = ref(sr.kolom || ''); const urut = ref(sr.urut || 'kurang')
const hanyaKurang = ref(sr.hanyaKurang ?? true)
const tingkatPilihan = computed(() => (jenjang.value === 'semua' ? [...TINGKAT.wustha, ...TINGKAT.sma] : TINGKAT[jenjang.value]))

// Hasil pemeriksaan santri aktif dalam cakupan pengguna
const hasil = computed(() => san.daftar.filter((s) => s.status === 'aktif').map((s) => ({ s, ...periksaSantri(s, aktif.value) })))
const dalamSaringan = computed(() => hasil.value.filter(({ s }) => (jenjang.value === 'semua' || s.jenjang === jenjang.value)
  && (!tingkat.value || s.tingkat === Number(tingkat.value)) && (!jk.value || s.jenis_kelamin === jk.value)))
const kurangTampil = (h) => h.kurang.filter((c) => (kategori.value === 'semua' || c.kategori === kategori.value) && (!kolom.value || c.k === kolom.value))
const tampil = computed(() => {
  const q = cari.value.toLowerCase().trim()
  const r = dalamSaringan.value.map((h) => ({ ...h, tampilKurang: kurangTampil(h) }))
    .filter((h) => (!hanyaKurang.value || h.tampilKurang.length) && (!q || `${h.s.nama_lengkap} ${h.s.nis} ${h.s.nisn || ''}`.toLowerCase().includes(q)))
  const nama = (a, b) => a.s.nama_lengkap.localeCompare(b.s.nama_lengkap, 'id')
  if (urut.value === 'kurang') r.sort((a, b) => a.persen - b.persen || nama(a, b))
  else if (urut.value === 'kelas') r.sort((a, b) => a.s.tingkat - b.s.tingkat || labelRombel(a.s).localeCompare(labelRombel(b.s), 'id') || nama(a, b))
  else r.sort(nama)
  return r
})

// Statistik dan kolom paling sering kosong
const statistik = computed(() => {
  const d = dalamSaringan.value; const lengkap = d.filter((h) => !h.kurang.length).length
  const rata = d.length ? Math.round(d.reduce((t, h) => t + h.persen, 0) / d.length) : 0
  return [
    { judul: 'Santri aktif diperiksa', nilai: d.length, ikon: PhUsersThree, warna: 'santri', ket: `${kolomAktif.value.length} kolom data diperiksa` },
    { judul: 'Data lengkap', nilai: lengkap, ikon: PhSealCheck, warna: 'presensi', ket: 'Semua kolom terisi' },
    { judul: 'Belum lengkap', nilai: d.length - lengkap, ikon: PhWarningCircle, warna: 'klinik', ket: 'Perlu dilengkapi' },
    { judul: 'Rata-rata kelengkapan', nilai: `${rata}%`, ikon: PhGauge, warna: 'laporan', ket: 'Dari kolom yang diperiksa' },
  ]
})
const rekapKolom = computed(() => kolomAktif.value.map((c) => ({ ...c, kosong: dalamSaringan.value.filter((h) => h.kurang.some((x) => x.k === c.k)).length }))
  .filter((c) => c.kosong && (kategori.value === 'semua' || c.kategori === kategori.value)).sort((a, b) => b.kosong - a.kosong))
const kategoriAktif = computed(() => KATEGORI_KELENGKAPAN.filter((g) => g.kolom.some((c) => aktif.value.includes(c.k))))
const hitungKategori = (k) => dalamSaringan.value.filter((h) => h.kurang.some((c) => k === 'semua' || c.kategori === k)).length
const warnaKategori = (k) => KATEGORI_KELENGKAPAN.find((g) => g.k === k)?.w || 'santri'
const namaKolom = computed(() => SEMUA_KOLOM.find((c) => c.k === kolom.value)?.n || '')
function pilihKolom(k) { kolom.value = kolom.value === k ? '' : k; hanyaKurang.value = true }
function reset() { cari.value = ''; jenjang.value = 'semua'; tingkat.value = ''; jk.value = ''; kategori.value = 'semua'; kolom.value = '' }
function lengkapi(s) {
  terakhir.value = s.id
  try {
    sessionStorage.setItem(KUNCI_KEADAAN, JSON.stringify({ y: window.scrollY, terakhir: s.id,
      saring: { cari: cari.value, jenjang: jenjang.value, tingkat: tingkat.value, jk: jk.value, kategori: kategori.value, kolom: kolom.value, urut: urut.value, hanyaKurang: hanyaKurang.value } }))
    // Urutan santri untuk tombol Sebelumnya/Berikutnya di formulir
    sessionStorage.setItem('simka.kelengkapan.urutan', JSON.stringify({ ids: tampil.value.map((h) => h.s.id), kolom: aktif.value, ubah: bolehUbah.value }))
  } catch { /* abaikan */ }
  router.push({ path: bolehUbah.value ? `/santri/${s.id}/ubah` : `/santri/${s.id}`, query: { dari: 'kelengkapan' } })
}

// Judul saringan untuk dokumen
const judulSaringan = computed(() => [jenjang.value !== 'semua' && (jenjang.value === 'sma' ? 'SMA' : 'Kesetaraan Wustha'), tingkat.value && `Kelas ${tingkat.value}`,
  jk.value && (jk.value === 'L' ? 'Putra' : 'Putri'), kategori.value !== 'semua' && KATEGORI_KELENGKAPAN.find((g) => g.k === kategori.value)?.n, namaKolom.value].filter(Boolean).join(' · '))

// Ekspor Excel: daftar santri + kolom per data (kosong ditandai "Belum")
function eksporExcel() {
  const kol = kolomAktif.value
  const judul = ['No.', 'NIS', 'Nama', 'L/P', 'Kelas', 'Kelengkapan (%)', 'Data belum diisi', ...kol.map((c) => c.n)]
  const data = tampil.value.map((h, i) => [i + 1, h.s.nis, h.s.nama_lengkap, h.s.jenis_kelamin, labelRombel(h.s), h.persen, h.kurang.map((c) => c.n).join(', '),
    ...kol.map((c) => (h.kurang.some((x) => x.k === c.k) ? 'Belum' : 'Ada'))])
  const ws = XLSX.utils.aoa_to_sheet([judul, ...data])
  ws['!cols'] = judul.map((k, i) => ({ wch: i === 6 ? 60 : Math.min(30, Math.max(String(k).length, ...data.map((r) => String(r[i]).length)) + 2) }))
  for (const r of Object.keys(ws)) if (!r.startsWith('!') && ws[r].t === 's') ws[r].z = '@'
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Kelengkapan data')
  XLSX.writeFile(wb, `Kelengkapan-Data-Santri-${formatPendek(hariIniISO()).replace(/\//g, '-')}.xlsx`)
}

// Cetak
const pratinjau = ref(false)
const direktur = computed(() => lembaga.signatories?.find((s) => /^direktur$/i.test(s.jabatan_tertulis)) || lembaga.signatories?.[0] || {})
</script>
<template>
  <div>
    <div class="layar-saja">
      <div class="mb-5 hidden items-center gap-3 lg:flex">
        <span class="w-santri chip-ikon h-12 w-12"><PhListMagnifyingGlass :size="28" weight="duotone" /></span>
        <div class="flex-1"><h2 class="text-lg font-bold">Kelengkapan Data Santri</h2>
          <p class="text-sm text-teks3">Seluruh data santri aktif diperiksa: identitas, alamat, orang tua/wali, data masuk, dan kelompok pondok.</p></div>
      </div>

      <div class="-mx-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-4 sm:overflow-visible sm:px-0">
        <KartuStatistik v-for="k in statistik" :key="k.judul" class="w-[46%] shrink-0 snap-start sm:w-auto" :judul="k.judul" :nilai="san.memuat && !san.daftar.length ? '…' : k.nilai" :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket" />
      </div>

      <!-- Kategori data -->
      <nav class="bilah-tab -mx-4 mt-4 px-4 lg:mx-0 lg:px-0" role="tablist" aria-label="Kategori data">
        <button role="tab" :aria-selected="kategori === 'semua'" :class="['tab-garis w-santri', kategori === 'semua' && 'aktif']" @click="kategori = 'semua'; kolom = ''">Semua data <span class="tabular-nums text-teks3">{{ hitungKategori('semua') }}</span></button>
        <button v-for="g in kategoriAktif" :key="g.k" role="tab" :aria-selected="kategori === g.k" :class="['tab-garis', 'w-' + g.w, kategori === g.k && 'aktif']" @click="kategori = g.k; kolom = ''">
          {{ g.n }} <span class="tabular-nums text-teks3">{{ hitungKategori(g.k) }}</span></button>
      </nav>

      <!-- Data yang paling sering kosong (ketuk untuk menyaring) -->
      <section class="kartu mt-4 p-4">
        <div class="mb-2 flex flex-wrap items-baseline gap-2"><h3 class="judul-bagian">Data yang paling sering kosong</h3>
          <p class="text-xs text-teks3">Ketuk salah satu untuk menampilkan santri yang belum mengisinya.</p>
          <button v-if="kolom || kategori !== 'semua' || jenjang !== 'semua' || tingkat || jk || cari" class="tombol-teks ml-auto h-8 min-h-0 text-xs" @click="reset"><PhArrowCounterClockwise :size="14" /> Atur ulang saringan</button></div>
        <div class="flex flex-wrap gap-1.5">
          <button v-for="c in rekapKolom" :key="c.k" type="button" :aria-pressed="kolom === c.k" :class="['chip-kolom', 'w-' + warnaKategori(c.kategori), kolom === c.k && 'pilih']" @click="pilihKolom(c.k)">
            {{ c.n }} <b class="tabular-nums">{{ c.kosong }}</b></button>
          <p v-if="!rekapKolom.length" class="py-2 text-sm text-teks3">Semua kolom yang diperiksa sudah terisi.</p>
        </div>
      </section>

      <div class="mt-4">
        <div class="min-w-0">
          <!-- Aksi dan saringan -->
          <div class="flex flex-wrap gap-2">
            <div class="relative min-w-[200px] flex-1">
              <PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
              <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari nama, NIS, atau NISN" aria-label="Cari santri" />
            </div>
            <select v-model="jenjang" class="isian w-auto" aria-label="Saring jenjang" @change="tingkat = ''"><option value="semua">Semua jenjang</option><option value="wustha">Kesetaraan Wustha</option><option value="sma">SMA</option></select>
            <select v-model="tingkat" class="isian w-auto" aria-label="Saring kelas"><option value="">Semua kelas</option><option v-for="t in tingkatPilihan" :key="t" :value="t">Kelas {{ t }}</option></select>
            <select v-model="jk" class="isian w-auto" aria-label="Saring jenis kelamin"><option value="">Putra dan putri</option><option value="L">Putra</option><option value="P">Putri</option></select>
            <select v-model="urut" class="isian w-auto" aria-label="Urutkan"><option value="kurang">Paling banyak kurang</option><option value="kelas">Menurut kelas</option><option value="nama">Menurut nama</option></select>
          </div>
          <div class="-mx-4 mt-3 flex gap-2 overflow-x-auto px-4 pb-1 lg:mx-0 lg:px-0">
            <label class="tombol-garis shrink-0 cursor-pointer px-3 text-sm"><input v-model="hanyaKurang" type="checkbox" class="h-4 w-4 accent-[#C7332F]" /> Hanya yang belum lengkap</label>
            <button class="tombol-garis w-pengaturan shrink-0 px-3 text-sm" @click="lembarKolom = true"><PhSlidersHorizontal :size="18" style="color: var(--c)" /> Atur kolom ({{ kolomAktif.length }})</button>
            <button class="tombol-garis w-gaji shrink-0 px-3 text-sm" :disabled="!tampil.length" @click="eksporExcel"><PhFileXls :size="18" weight="duotone" style="color: var(--c)" /> Ekspor Excel</button>
            <button class="tombol-utama shrink-0 px-4 text-sm" :disabled="!tampil.length" @click="pratinjau = true"><PhPrinter :size="18" weight="duotone" /> Cetak</button>
          </div>
          <p v-if="kolom" class="mt-3 flex items-center gap-2 rounded-xl bg-permukaan2 p-2.5 text-sm">Disaring: santri yang <b>{{ namaKolom }}</b> belum diisi
            <button class="tombol-teks ml-auto h-8 min-h-0 text-xs" @click="kolom = ''"><PhX :size="14" /> Hapus saringan</button></p>

          <!-- Desktop: tabel -->
          <div class="kartu mt-3 hidden overflow-x-auto lg:block">
            <table class="w-full text-left text-sm">
              <thead class="border-b border-garis bg-permukaan2 text-teks2"><tr>
                <th class="w-10 px-3 py-3 text-center font-bold">No.</th><th class="px-3 py-3 font-bold">NIS</th><th class="px-3 py-3 font-bold">Nama</th><th class="px-3 py-3 text-center font-bold">L/P</th>
                <th class="px-3 py-3 font-bold">Kelas</th><th class="w-36 px-3 py-3 font-bold">Kelengkapan</th><th class="px-3 py-3 font-bold">Data belum diisi</th><th class="w-24" /></tr></thead>
              <tbody class="divide-y divide-garis">
                <tr v-for="(h, i) in tampil" :key="h.s.id" :data-santri="h.s.id" :class="['align-top hover:bg-permukaan2/50', terakhir === h.s.id && 'terakhir']">
                  <td class="px-3 py-3 text-center tabular-nums text-teks3">{{ i + 1 }}</td>
                  <td class="px-3 py-3 tabular-nums">{{ h.s.nis }}</td>
                  <td class="px-3 py-3 font-semibold"><router-link :to="`/santri/${h.s.id}`" class="hover:underline">{{ h.s.nama_lengkap }}</router-link></td>
                  <td class="px-3 py-3 text-center">{{ h.s.jenis_kelamin }}</td>
                  <td class="px-3 py-3 text-teks2">{{ labelRombel(h.s) }}</td>
                  <td class="px-3 py-3"><div class="flex items-center gap-2"><span class="bar"><span :class="['isi', h.persen === 100 ? 'w-presensi' : h.persen >= 75 ? 'w-agenda' : 'w-klinik']" :style="{ width: h.persen + '%' }" /></span>
                    <b class="w-10 text-right tabular-nums">{{ h.persen }}%</b></div></td>
                  <td class="px-3 py-3"><span v-if="!h.kurang.length" class="lencana w-presensi">Lengkap</span>
                    <span v-else class="flex flex-wrap gap-1"><span v-for="c in h.tampilKurang.length ? h.tampilKurang : h.kurang" :key="c.k" :class="['lencana', 'w-' + warnaKategori(c.kategori)]">{{ c.n }}</span></span></td>
                  <td class="px-3 py-3 text-right"><button v-if="h.kurang.length" class="tombol-garis min-h-[36px] px-3 text-xs" @click="lengkapi(h.s)"><PhPencilSimple :size="16" /> {{ bolehUbah ? 'Lengkapi' : 'Lihat' }}</button></td>
                </tr>
              </tbody>
            </table>
            <p v-if="!tampil.length" class="p-8 text-center text-sm text-teks3">{{ san.memuat ? 'Memuat data santri…' : 'Tidak ada santri sesuai saringan.' }}</p>
          </div>

          <!-- HP: kartu -->
          <ul class="mt-3 space-y-2 lg:hidden">
            <li v-for="h in tampil" :key="h.s.id" :data-santri="h.s.id" :class="terakhir === h.s.id && 'terakhir rounded-[1.25rem]'">
              <button type="button" class="kartu flex w-full items-start gap-3 p-3.5 text-left" @click="lengkapi(h.s)">
                <span :class="['chip-ikon h-11 w-11 shrink-0 text-sm font-extrabold', h.persen === 100 ? 'w-presensi' : h.persen >= 75 ? 'w-agenda' : 'w-klinik']">{{ h.persen }}%</span>
                <span class="min-w-0 flex-1">
                  <b class="block truncate">{{ h.s.nama_lengkap }}</b>
                  <span class="block text-xs text-teks3">{{ h.s.nis }} · {{ h.s.jenis_kelamin }} · {{ labelRombel(h.s) }}</span>
                  <span v-if="h.kurang.length" class="mt-1.5 flex flex-wrap gap-1"><span v-for="c in (h.tampilKurang.length ? h.tampilKurang : h.kurang).slice(0, 8)" :key="c.k" :class="['lencana', 'w-' + warnaKategori(c.kategori)]">{{ c.n }}</span>
                    <span v-if="(h.tampilKurang.length ? h.tampilKurang : h.kurang).length > 8" class="lencana">+{{ (h.tampilKurang.length ? h.tampilKurang : h.kurang).length - 8 }}</span></span>
                  <span v-else class="lencana w-presensi mt-1.5">Lengkap</span>
                </span>
              </button>
            </li>
            <li v-if="!tampil.length" class="kartu p-8 text-center text-sm text-teks3">{{ san.memuat ? 'Memuat data santri…' : 'Tidak ada santri sesuai saringan.' }}</li>
          </ul>
        </div>

      </div>
    </div>

    <!-- Atur kolom -->
    <LembarBawah v-model="lembarKolom" judul="Kolom data yang diperiksa" lebar>
      <div class="space-y-4 pb-2">
        <p class="text-sm text-teks2">Pilih data yang wajib ada untuk setiap santri. Pengaturan ini hanya untuk tampilan Anda di perangkat ini.</p>
        <div v-for="g in KATEGORI_KELENGKAPAN" :key="g.k" :class="'w-' + g.w">
          <p class="mb-1.5 text-sm font-bold" style="color: var(--c)">{{ g.n }}</p>
          <div class="grid gap-1 sm:grid-cols-2">
            <label v-for="c in g.kolom" :key="c.k" class="flex min-h-[40px] items-center gap-2.5 rounded-xl px-2 text-sm hover:bg-permukaan2">
              <input type="checkbox" class="h-5 w-5 shrink-0 accent-[#C7332F]" :checked="aktif.includes(c.k)" @change="togelKolom(c.k)" />
              <span>{{ c.n }}<span v-if="c.bawaan === false" class="text-xs text-teks3"> (opsional)</span></span>
            </label>
          </div>
        </div>
        <div class="flex gap-2"><button class="tombol-garis flex-1" @click="aktif = [...KOLOM_BAWAAN]"><PhArrowCounterClockwise :size="18" /> Kembali ke bawaan</button>
          <button class="tombol-utama flex-1" @click="lembarKolom = false">Selesai</button></div>
      </div>
    </LembarBawah>

    <DokumenCetak v-model:pratinjau="pratinjau" mendatar judul="Daftar Kelengkapan Data Santri" :subjudul="`Santri aktif${judulSaringan ? ' · ' + judulSaringan : ''} · keadaan ${formatPendek(hariIniISO())}`"
      :nama-berkas="`Kelengkapan-Data-Santri-${formatPendek(hariIniISO()).replace(/\//g, '-')}`" :pencetak="sesi.pengguna?.nama_lengkap">
      <table class="tabel">
        <colgroup><col style="width:4%"><col style="width:8%"><col style="width:20%"><col style="width:4%"><col style="width:9%"><col style="width:8%"><col style="width:47%"></colgroup>
        <thead><tr><th>No.</th><th>NIS</th><th>Nama</th><th>L/P</th><th>Kelas</th><th>Kelengkapan</th><th>Data yang Belum Diisi</th></tr></thead>
        <tbody><tr v-for="(h, i) in tampil" :key="h.s.id">
          <td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ h.s.nis }}</td><td>{{ h.s.nama_lengkap }}</td><td class="tengah">{{ h.s.jenis_kelamin }}</td>
          <td>{{ labelRombel(h.s) }}</td><td class="tengah">{{ h.persen }}%</td>
          <td>{{ h.kurang.length ? (h.tampilKurang.length ? h.tampilKurang : h.kurang).map((c) => c.n).join(', ') : 'Lengkap' }}</td>
        </tr></tbody>
      </table>
      <p style="margin-top: 6pt; font-size: 9pt">Kolom yang diperiksa ({{ kolomAktif.length }}): {{ kolomAktif.map((c) => c.n).join(', ') }}.</p>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan_tertulis || 'Direktur', nama: direktur.nama || '', niy: direktur.niy }"
          :kanan="{ jabatan: 'Petugas Data Santri', nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
      </template>
    </DokumenCetak>
  </div>
</template>
<style scoped>
.bar { display: block; height: 6px; flex: 1; overflow: hidden; border-radius: 9999px; background: rgb(var(--permukaan-2)); }
.isi { display: block; height: 100%; border-radius: 9999px; background: var(--c, #C7332F); }
.terakhir { box-shadow: inset 4px 0 0 #C7332F; background: color-mix(in srgb, #C7332F 6%, transparent); }
.chip-kolom { display: inline-flex; min-height: 36px; align-items: center; gap: .4rem; border-radius: 9999px; border: 1px solid color-mix(in srgb, var(--c) 35%, rgb(var(--garis))); padding: 0 .75rem; font-size: .8125rem; color: rgb(var(--teks)); background: color-mix(in srgb, var(--c) 7%, rgb(var(--permukaan))); }
.chip-kolom b { color: var(--c); }
.chip-kolom.pilih { background: var(--c); border-color: transparent; color: #fff; }
.chip-kolom.pilih b { color: #fff; }
:global(.dark) .chip-kolom.pilih, :global(.dark) .chip-kolom.pilih b { color: rgb(var(--latar)); }
</style>
