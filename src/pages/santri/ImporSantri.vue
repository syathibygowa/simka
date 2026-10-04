<!-- SIMKA PRO | src/pages/santri/ImporSantri.vue | v1.1 | Fase 4 – Perbaikan P1 (data santri lengkap) | 04/10/2026 -->
<script setup>
// Impor data santri dari Excel: unduh templat → pilih berkas → periksa → impor.
// Judul kolom ekspor aplikasi SPMB/daftar lama juga dikenali (KOLOM_IMPOR.alias). NIS sama = perbarui.
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import * as XLSX from 'xlsx'
import { PhDownloadSimple, PhFileXls, PhCheckCircle, PhWarningCircle, PhUploadSimple, PhArrowCounterClockwise } from '@phosphor-icons/vue'
import { useSantri } from '@/stores/santri'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { uraiPendek, formatPendek } from '@/lib/tanggal'
import { KOLOM_IMPOR, kenaliJudul, normalJK, normalHP, normalJenjang, normalTingkat, normalJalur, jenjangDariTingkat } from '@/lib/santri'

const san = useSantri(); const sesi = useSesi(); const ui = useUI(); const router = useRouter()
onMounted(() => {
  if (!sesi.bolehAdmin('kelola_santri')) { ui.toast('Impor data santri hanya untuk admin ber-izin kelola santri.', 'galat'); return router.replace('/santri') }
  san.muat()
})

const namaBerkas = ref(''); const baris = ref([]); const kolomDikenal = ref([]); const kolomAsing = ref([])
const hasil = ref(null); const proses = ref(false)
const siap = computed(() => baris.value.filter((b) => !b.galat.length))
const bermasalah = computed(() => baris.value.filter((b) => b.galat.length))

// ---------- Templat ----------
function unduhTemplat() {
  const wb = XLSX.utils.book_new()
  const CONTOH = [
    { nis: '2211010', nisn: '0123456789', nama_lengkap: 'Ahmad Fauzan', jenis_kelamin: 'L', jenjang: 'Wustha', tingkat: '8', nama_panggilan: 'Fauzan', tempat_lahir: 'Gowa',
      tanggal_lahir: '04/03/2012', nik: '7306010403120001', no_kk: '7306011203090004', anak_ke: '2', alamat: 'Jl. Poros Malino No. 4', rt: '002', rw: '005',
      kelurahan: 'Bontoramba', kecamatan: 'Somba Opu', kota_kab: 'Kabupaten Gowa', provinsi: 'Sulawesi Selatan', tanggal_masuk: '13/07/2022', jalur_masuk: 'Baru',
      asal_sekolah: 'SD Inpres Bontoramba', hafalan_awal_juz: '1', nama_ayah: 'Fauzi', hp_ayah: '081234567890', pekerjaan_ayah: 'Wiraswasta', nama_ibu: 'Siti Aminah',
      hp_ibu: '081298765432', pekerjaan_ibu: 'Ibu rumah tangga' },
    { nis: '2412005', nisn: '0098765432', nama_lengkap: 'Fatimah Azzahra', jenis_kelamin: 'P', jenjang: 'SMA', tingkat: '11', tempat_lahir: 'Makassar', tanggal_lahir: '15/05/2009',
      anak_ke: '1', alamat: 'Jl. Sultan Alauddin No. 10', rt: '001', rw: '003', kelurahan: 'Gunung Sari', kecamatan: 'Rappocini', kota_kab: 'Kota Makassar', provinsi: 'Sulawesi Selatan',
      tanggal_masuk: '01/08/2026', jalur_masuk: 'Pindahan', asal_sekolah: 'SMA Negeri 1 Gowa', hafalan_awal_juz: '3,5', nama_ayah: 'Rahman', hp_ayah: '085211112222', pekerjaan_ayah: 'PNS',
      nama_ibu: 'Nurhayati', nama_wali: 'Hasan (paman)', hp_wali: '085233334444', pekerjaan_wali: 'Pedagang' },
  ]
  const contoh = CONTOH.map((o) => KOLOM_IMPOR.map((c) => o[c.k] || ''))
  const ws = XLSX.utils.aoa_to_sheet([KOLOM_IMPOR.map((c) => c.j + (c.wajib ? ' *' : '')), ...contoh])
  ws['!cols'] = KOLOM_IMPOR.map((c) => ({ wch: Math.max(12, Math.min(34, c.j.length + 2)) }))
  XLSX.utils.book_append_sheet(wb, ws, 'Data santri')
  const petunjuk = [
    ['Petunjuk pengisian templat data santri SIMKA PRO (versi 1.1)'], [''],
    ['1. Isi mulai baris ke-2 lembar "Data santri". Hapus dua baris contoh sebelum mengimpor.'],
    ['2. Kolom bertanda * wajib untuk santri baru: NIS, NISN, nama, jenis kelamin, kelas, tempat lahir, tanggal lahir. Kolom lain boleh kosong dan dilengkapi kemudian.'],
    ['   Hasil "Ekspor Excel" di Data Santri memakai susunan kolom yang sama: unduh, lengkapi yang kosong, lalu impor kembali.'],
    ['3. NIS 7 angka: 2 digit tahun masuk + 2 digit angkatan + 3 digit nomor santri. Contoh 2211010 = masuk 2022, angkatan 11, nomor 010.'],
    ['4. Kelas ditulis 7–12 (boleh "Kelas 8B", "10 IPA", atau angka Romawi). Jenjang boleh kosong: kelas 7–9 = Wustha, 10–12 = SMA.'],
    ['5. Tanggal ditulis dd/mm/yyyy, contoh 13/07/2022. Hafalan awal dalam juz, boleh desimal (3,5). RT dan RW cukup angka (2 → 002).'],
    ['   NISN, NIK, dan Nomor KK sebaiknya diformat Teks di Excel agar angka 0 di depan dan digit terakhir tidak hilang.'],
    ['6. Baris dengan NIS yang sudah terdaftar akan MEMPERBARUI data lama; sel kosong tidak menghapus data lama.'],
    ['7. Nomor HP orang tua/wali dipakai untuk pesan WA dan kelak login portal wali. Penerima WA utama otomatis: ayah, lalu ibu, lalu wali yang ber-HP (dapat diubah di aplikasi).'],
    ['8. Status santri (nonaktif, mutasi keluar, lulus, berhenti) tidak diimpor; ubah lewat halaman santri agar riwayat dan alasannya tercatat.'],
  ]
  const wp = XLSX.utils.aoa_to_sheet(petunjuk); wp['!cols'] = [{ wch: 120 }]
  XLSX.utils.book_append_sheet(wb, wp, 'Petunjuk')
  XLSX.writeFile(wb, 'Templat-Impor-Santri-SIMKA-v1.1.xlsx')
}

function tanggal(v) {
  if (v === '' || v == null) return ''
  if (v instanceof Date) return `${v.getFullYear()}-${String(v.getMonth() + 1).padStart(2, '0')}-${String(v.getDate()).padStart(2, '0')}`
  if (typeof v === 'number') { const d = XLSX.SSF.parse_date_code(v); return d ? `${d.y}-${String(d.m).padStart(2, '0')}-${String(d.d).padStart(2, '0')}` : null }
  if (/^\d{4}-\d{2}-\d{2}$/.test(String(v).trim())) return String(v).trim()
  return uraiPendek(String(v)) || null
}

// ---------- Baca dan periksa berkas ----------
async function pilihBerkas(e) {
  const berkas = e.target.files?.[0]; e.target.value = ''
  if (!berkas) return
  hasil.value = null
  try {
    const wb = XLSX.read(await berkas.arrayBuffer(), { cellDates: true })
    const ws = wb.Sheets[wb.SheetNames[0]]
    const aoa = XLSX.utils.sheet_to_json(ws, { header: 1, defval: '', raw: true })
    let iJudul = -1, peta = []
    for (let i = 0; i < Math.min(10, aoa.length); i++) {
      const p = aoa[i].map((j) => kenaliJudul(j))
      if (p.includes('nis') && p.includes('nama_lengkap')) { iJudul = i; peta = p; break }
    }
    if (iJudul < 0) return ui.toast('Kolom "NIS" dan "Nama lengkap" tidak ditemukan. Pakai templat SIMKA PRO atau pastikan baris judul ada di bagian atas.', 'galat')
    kolomDikenal.value = [...new Set(peta.filter(Boolean))]
    kolomAsing.value = aoa[iJudul].filter((j, i) => j !== '' && !peta[i] && !/^no\.?$/i.test(String(j).trim()))
    const data = []
    const nisBerkas = new Map()
    aoa.slice(iJudul + 1).forEach((r, i) => {
      const o = {}; peta.forEach((k, c) => { if (k && o[k] === undefined) o[k] = r[c] })
      if (!Object.values(o).some((v) => String(v ?? '').trim() !== '')) return
      const b = periksa(o, iJudul + i + 2)
      if (b.isi.nis) { if (nisBerkas.has(b.isi.nis)) b.galat.push(`NIS ${b.isi.nis} ganda di berkas (baris ${nisBerkas.get(b.isi.nis)}).`); else nisBerkas.set(b.isi.nis, b.nomorBaris) }
      data.push(b)
    })
    namaBerkas.value = berkas.name; baris.value = data
    if (!data.length) ui.toast('Berkas tidak berisi baris data.', 'galat')
  } catch { ui.toast('Berkas tidak dapat dibaca. Pastikan berformat .xlsx, .xls, atau .csv.', 'galat') }
}

function periksa(o, nomorBaris) {
  const galat = [], isi = {}
  const s = (v) => String(v ?? '').trim().replace(/\.0$/, '')
  const set = (k, v, normal, pesan) => {
    if (s(v) === '') return
    const n = normal ? normal(v) : s(v)
    if (n === null) galat.push(pesan); else isi[k] = n
  }
  const nis = s(o.nis).replace(/\s/g, '')
  if (!/^\d{7}$/.test(nis)) galat.push('NIS harus 7 angka.'); else isi.nis = nis
  const ada = isi.nis && san.daftar.find((x) => x.nis === isi.nis)
  set('nama_lengkap', o.nama_lengkap, (v) => (s(v).length >= 3 ? s(v) : null), 'Nama lengkap terlalu pendek.')
  set('jenis_kelamin', o.jenis_kelamin, normalJK, 'Jenis kelamin harus L atau P.')
  set('tingkat', o.tingkat, normalTingkat, 'Kelas harus 7–12.')
  set('jenjang', o.jenjang, normalJenjang, 'Jenjang harus Wustha atau SMA.')
  if (isi.tingkat && !isi.jenjang) isi.jenjang = jenjangDariTingkat(isi.tingkat)
  if (isi.jenjang && !isi.tingkat && ada) isi.tingkat = ada.tingkat
  if (isi.tingkat && isi.jenjang && jenjangDariTingkat(isi.tingkat) !== isi.jenjang) galat.push('Kelas tidak sesuai jenjang (Wustha 7–9, SMA 10–12).')
  set('nisn', o.nisn, (v) => (/^\d{10}$/.test(s(v).replace(/\s/g, '')) ? s(v).replace(/\s/g, '') : null), 'NISN harus 10 angka.')
  set('nik', o.nik, (v) => (/^\d{16}$/.test(s(v).replace(/[\s']/g, '')) ? s(v).replace(/[\s']/g, '') : null), 'NIK harus 16 angka (format sel Excel sebagai Teks).')
  set('nama_panggilan', o.nama_panggilan)
  set('tempat_lahir', o.tempat_lahir)
  set('tanggal_lahir', o.tanggal_lahir, tanggal, 'Tanggal lahir tidak sah (tulis dd/mm/yyyy).')
  set('anak_ke', o.anak_ke, (v) => (/^\d{1,2}$/.test(s(v)) ? Number(s(v)) : null), 'Anak ke- harus angka.')
  set('alamat', o.alamat)
  set('no_kk', o.no_kk, (v) => (/^\d{16}$/.test(s(v).replace(/[\s']/g, '')) ? s(v).replace(/[\s']/g, '') : null), 'Nomor KK harus 16 angka (format sel Excel sebagai Teks).')
  set('rt', o.rt, (v) => (/^\d{1,3}$/.test(s(v)) ? s(v).padStart(3, '0') : null), 'RT harus angka (paling banyak 3 digit).')
  set('rw', o.rw, (v) => (/^\d{1,3}$/.test(s(v)) ? s(v).padStart(3, '0') : null), 'RW harus angka (paling banyak 3 digit).')
  set('kelurahan', o.kelurahan)
  set('kecamatan', o.kecamatan)
  set('kota_kab', o.kota_kab)
  set('provinsi', o.provinsi)
  set('tanggal_masuk', o.tanggal_masuk, tanggal, 'Tanggal masuk tidak sah (tulis dd/mm/yyyy).')
  set('jalur_masuk', o.jalur_masuk, normalJalur, 'Jalur masuk harus Baru atau Pindahan.')
  set('asal_sekolah', o.asal_sekolah)
  set('hafalan_awal_juz', o.hafalan_awal_juz, (v) => { const n = Number(s(v).replace(',', '.').replace(/\s*juz$/i, '')); return n >= 0 && n <= 30 ? n : null }, 'Hafalan awal harus 0–30 juz.')
  set('catatan', o.catatan)
  if (!ada) {
    if (!isi.nisn) galat.push('NISN wajib untuk santri baru.')
    if (!isi.tempat_lahir || !isi.tanggal_lahir) galat.push('Tempat dan tanggal lahir wajib untuk santri baru.')
    if (!isi.nama_lengkap) galat.push('Nama lengkap wajib untuk santri baru.')
    if (!isi.jenis_kelamin) galat.push('Jenis kelamin wajib untuk santri baru.')
    if (!isi.tingkat) galat.push('Kelas wajib untuk santri baru.')
  }
  const kontak = []
  for (const h of ['ayah', 'ibu', 'wali']) {
    const k = { hubungan: h }
    if (s(o['nama_' + h])) k.nama = s(o['nama_' + h])
    if (s(o['hp_' + h])) { const hp = normalHP(o['hp_' + h]); if (/^[0-9+]{9,16}$/.test(hp)) k.no_hp = hp; else galat.push(`HP ${h === 'wali' ? 'wali' : h} harus 9–16 angka.`) }
    if (s(o['pekerjaan_' + h])) k.pekerjaan = s(o['pekerjaan_' + h])
    if (Object.keys(k).length > 1) kontak.push(k)
  }
  if (kontak.length) isi.kontak = kontak
  return { nomorBaris, isi, galat, aksi: ada ? 'perbarui' : 'tambah' }
}

// ---------- Kirim ----------
async function impor() {
  if (!siap.value.length) return
  const ok = await ui.konfirmasi({
    judul: `Impor ${siap.value.length} baris?`,
    pesan: `${siap.value.filter((b) => b.aksi === 'tambah').length} santri baru ditambahkan dan ${siap.value.filter((b) => b.aksi === 'perbarui').length} data lama diperbarui.${bermasalah.value.length ? ` ${bermasalah.value.length} baris bermasalah dilewati.` : ''}`,
    ya: 'Impor sekarang',
  })
  if (!ok) return
  proses.value = true
  try {
    const kirim = siap.value
    const h = await san.impor(kirim.map((b) => b.isi))
    hasil.value = h.map((x, i) => ({ ...x, nomorBaris: kirim[i].nomorBaris, nama: kirim[i].isi.nama_lengkap || kirim[i].isi.nis }))
    const gagal = hasil.value.filter((x) => !x.ok).length
    ui.toast(gagal ? `Impor selesai: ${hasil.value.length - gagal} berhasil, ${gagal} gagal.` : `Impor selesai: ${hasil.value.length} baris berhasil.`)
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
function ulangi() { baris.value = []; hasil.value = null; namaBerkas.value = '' }
function unduhLaporan() {
  const ws = XLSX.utils.aoa_to_sheet([['Baris Excel', 'NIS/Nama', 'Hasil', 'Keterangan'],
    ...hasil.value.map((h) => [h.nomorBaris, h.nama, h.ok ? 'Berhasil' : 'Gagal', h.ok ? (h.aksi === 'ditambah' ? 'Santri baru ditambahkan' : 'Data lama diperbarui') : h.pesan]),
    ...bermasalah.value.map((b) => [b.nomorBaris, b.isi.nama_lengkap || b.isi.nis || '', 'Dilewati', b.galat.join(' ')])])
  ws['!cols'] = [{ wch: 11 }, { wch: 36 }, { wch: 10 }, { wch: 70 }]
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Hasil impor')
  XLSX.writeFile(wb, `Hasil-Impor-Santri-${formatPendek(new Date()).replace(/\//g, '-')}.xlsx`)
}
const JUDUL = Object.fromEntries(KOLOM_IMPOR.map((c) => [c.k, c.j.replace(/\s*\(.*\)$/, '')]))
</script>
<template>
  <div class="mx-auto max-w-5xl space-y-4">
    <section class="kartu w-gaji flex flex-wrap items-center gap-4 p-5">
      <span class="chip-ikon h-12 w-12"><PhFileXls :size="28" weight="duotone" /></span>
      <div class="min-w-[220px] flex-1">
        <h2 class="judul-bagian">1. Unduh templat Excel</h2>
        <p class="text-sm text-teks3">Berisi kolom data santri dan orang tua/wali beserta petunjuk. Ekspor aplikasi SPMB atau daftar lama juga dapat dipakai bila judul kolomnya serupa.</p>
      </div>
      <button class="tombol-garis" @click="unduhTemplat"><PhDownloadSimple :size="20" weight="duotone" /> Unduh templat</button>
    </section>

    <section class="kartu w-santri flex flex-wrap items-center gap-4 p-5">
      <span class="chip-ikon h-12 w-12"><PhUploadSimple :size="28" weight="duotone" /></span>
      <div class="min-w-[220px] flex-1">
        <h2 class="judul-bagian">2. Pilih berkas yang sudah diisi</h2>
        <p class="text-sm text-teks3">{{ namaBerkas ? `Berkas: ${namaBerkas} (${baris.length} baris data)` : 'Format .xlsx, .xls, atau .csv. Data diperiksa dulu sebelum disimpan.' }}</p>
      </div>
      <label class="tombol-utama cursor-pointer"><PhUploadSimple :size="20" weight="duotone" /> {{ namaBerkas ? 'Ganti berkas' : 'Pilih berkas' }}
        <input type="file" accept=".xlsx,.xls,.csv" class="sr-only" @change="pilihBerkas" /></label>
    </section>

    <section v-if="baris.length && !hasil" class="kartu p-5">
      <h2 class="judul-bagian">3. Periksa sebelum mengimpor</h2>
      <div class="mt-3 flex flex-wrap gap-2">
        <span class="lencana w-presensi px-3 py-1 text-sm"><PhCheckCircle :size="16" weight="fill" /> {{ siap.length }} baris siap</span>
        <span v-if="bermasalah.length" class="lencana w-klinik px-3 py-1 text-sm"><PhWarningCircle :size="16" weight="fill" /> {{ bermasalah.length }} baris perlu diperbaiki</span>
        <span class="lencana w-hakakses px-3 py-1 text-sm">{{ siap.filter((b) => b.aksi === 'perbarui').length }} memperbarui data lama (NIS sama)</span>
      </div>
      <p class="mt-2 text-sm text-teks3">Kolom dikenali: {{ kolomDikenal.map((k) => JUDUL[k]).join(', ') }}.</p>
      <p v-if="kolomAsing.length" class="mt-1 text-sm text-teks3">Kolom diabaikan: {{ kolomAsing.join(', ') }}.</p>
      <ul class="mt-4 max-h-[55vh] divide-y divide-garis overflow-y-auto rounded-xl border border-garis">
        <li v-for="b in baris" :key="b.nomorBaris" :class="['flex gap-3 p-3', b.galat.length ? 'w-klinik' : 'w-presensi']">
          <span class="chip-ikon mt-0.5 h-8 w-8 rounded-lg"><component :is="b.galat.length ? PhWarningCircle : PhCheckCircle" :size="18" weight="duotone" /></span>
          <div class="min-w-0 flex-1">
            <p class="font-semibold">{{ b.isi.nama_lengkap || '(nama tidak diubah)' }} <span class="text-xs font-normal text-teks3">– baris {{ b.nomorBaris }}{{ b.isi.nis ? ', NIS ' + b.isi.nis : '' }}{{ b.isi.tingkat ? ', kelas ' + b.isi.tingkat : '' }}{{ b.galat.length ? '' : b.aksi === 'perbarui' ? ', memperbarui data lama' : ', santri baru' }}</span></p>
            <p v-for="g in b.galat" :key="g" class="text-sm font-semibold" style="color: var(--c)">{{ g }}</p>
          </div>
        </li>
      </ul>
      <div class="mt-4 flex flex-wrap justify-end gap-2">
        <button class="tombol-garis" @click="ulangi"><PhArrowCounterClockwise :size="20" /> Batal</button>
        <button class="tombol-utama" :disabled="!siap.length || proses" @click="impor"><PhUploadSimple :size="20" weight="duotone" /> {{ proses ? 'Mengimpor…' : `Impor ${siap.length} baris` }}</button>
      </div>
    </section>

    <section v-if="hasil" class="kartu w-presensi p-5">
      <h2 class="judul-bagian">Hasil impor</h2>
      <div class="mt-3 grid grid-cols-3 gap-2 text-center">
        <div class="rounded-xl bg-permukaan2 p-3"><p class="text-2xl font-extrabold">{{ hasil.filter((h) => h.ok && h.aksi === 'ditambah').length }}</p><p class="text-sm text-teks3">ditambahkan</p></div>
        <div class="rounded-xl bg-permukaan2 p-3"><p class="text-2xl font-extrabold">{{ hasil.filter((h) => h.ok && h.aksi === 'diperbarui').length }}</p><p class="text-sm text-teks3">diperbarui</p></div>
        <div class="rounded-xl bg-permukaan2 p-3"><p class="text-2xl font-extrabold">{{ hasil.filter((h) => !h.ok).length + bermasalah.length }}</p><p class="text-sm text-teks3">gagal/dilewati</p></div>
      </div>
      <ul v-if="hasil.some((h) => !h.ok)" class="mt-3 space-y-1 text-sm">
        <li v-for="h in hasil.filter((x) => !x.ok)" :key="h.nomorBaris" class="w-klinik"><span class="font-semibold">Baris {{ h.nomorBaris }} ({{ h.nama }}):</span> <span style="color: var(--c)">{{ h.pesan }}</span></li>
      </ul>
      <div class="mt-4 flex flex-wrap justify-end gap-2">
        <button class="tombol-garis" @click="unduhLaporan"><PhDownloadSimple :size="20" weight="duotone" /> Unduh laporan hasil</button>
        <button class="tombol-garis" @click="ulangi"><PhArrowCounterClockwise :size="20" /> Impor berkas lain</button>
        <router-link to="/santri" class="tombol-utama">Lihat data santri</router-link>
      </div>
    </section>
  </div>
</template>
