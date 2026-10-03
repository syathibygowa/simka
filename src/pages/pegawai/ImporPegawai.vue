<!-- SIMKA PRO | src/pages/pegawai/ImporPegawai.vue | v1.0 | Fase 1 – Data pegawai | 03/10/2026 -->
<script setup>
// Impor data pegawai dari Excel: unduh templat → pilih berkas → periksa → impor.
// Judul kolom dari daftar Excel lama pondok juga dikenali (lihat KOLOM_IMPOR.alias).
import { ref, computed, onMounted } from 'vue'
import * as XLSX from 'xlsx'
import { PhDownloadSimple, PhFileXls, PhCheckCircle, PhWarningCircle, PhUploadSimple, PhArrowCounterClockwise } from '@phosphor-icons/vue'
import { usePegawai } from '@/stores/pegawai'
import { useOrganisasi } from '@/stores/organisasi'
import { useUI } from '@/stores/ui'
import { uraiPendek, formatPendek } from '@/lib/tanggal'
import {
  KOLOM_IMPOR, kenaliJudul, normalJK, normalStatus, normalHonorer, normalPendidikan, normalKeluarga, normalLevel, normalKeaktifan, normalHP,
} from '@/lib/kepegawaian'

const peg = usePegawai(); const org = useOrganisasi(); const ui = useUI()
onMounted(() => Promise.all([org.muat(), peg.daftar.length ? null : peg.muat()]))

const namaBerkas = ref(''); const baris = ref([]); const kolomDikenal = ref([]); const kolomAsing = ref([])
const hasil = ref(null); const proses = ref(false)
const siap = computed(() => baris.value.filter((b) => !b.galat.length))
const bermasalah = computed(() => baris.value.filter((b) => b.galat.length))

// ---------- Templat ----------
function unduhTemplat() {
  const wb = XLSX.utils.book_new()
  const contoh = [
    ['Ust. Contoh Satu, Lc.', '2019070101', 'L', 'Gowa', '01/01/1990', '01/07/2019', 'Tetap', '', 'S1-LN', 'Menikah', '081234567890', 'contoh1@gmail.com', 'Bidang Tahfizh', 'Muhaffizh, Wali kelas', '', 'Terampil', 'Aktif'],
    ['Ustzh. Contoh Dua, S.Pd.', '2021071502', 'P', 'Makassar', '15/05/1995', '15/07/2021', 'Honorer', 'Baru', 'S1', 'Belum menikah', '082345678901', '', 'Bidang Kesetaraan Wustha', 'Guru mata pelajaran', '', '', 'Aktif'],
  ]
  const ws = XLSX.utils.aoa_to_sheet([KOLOM_IMPOR.map((c) => c.j + (c.wajib ? ' *' : '')), ...contoh])
  ws['!cols'] = KOLOM_IMPOR.map((c) => ({ wch: Math.max(14, Math.min(40, c.j.length + 2)) }))
  XLSX.utils.book_append_sheet(wb, ws, 'Data pegawai')
  const petunjuk = [
    ['Petunjuk pengisian templat SIMKA PRO (versi 1.0)'], [''],
    ['1. Isi mulai baris ke-2 lembar "Data pegawai". Hapus dua baris contoh sebelum mengimpor.'],
    ['2. Kolom bertanda * wajib diisi. Kolom lain boleh kosong dan dapat dilengkapi kemudian.'],
    ['3. Tanggal ditulis dd/mm/yyyy, contoh 01/07/2019.'],
    ['4. Jabatan fungsional boleh lebih dari satu, pisahkan dengan koma. Medis dan security tidak boleh dirangkap.'],
    ['5. Nama bidang/unit dan jabatan harus sesuai lembar "Referensi".'],
    ['6. Baris dengan NIY yang sudah terdaftar akan MEMPERBARUI data lama; sel kosong tidak menghapus data lama.'],
    ['7. Email dan nomor HP dipakai untuk akun dan pesan WA. NIK, rekening, dan alamat lengkap tidak perlu diisi.'],
  ]
  const wp = XLSX.utils.aoa_to_sheet(petunjuk); wp['!cols'] = [{ wch: 110 }]
  XLSX.utils.book_append_sheet(wb, wp, 'Petunjuk')
  const n = Math.max(org.units.length, org.fungsional.length, org.struktural.length)
  const ref_ = [['Bidang/Unit', 'Jabatan fungsional', 'Jabatan struktural']]
  const u = org.datar.filter((x) => x.aktif), fu = org.fungsional.filter((x) => x.aktif), st = org.struktural.filter((x) => x.aktif)
  for (let i = 0; i < n; i++) ref_.push([u[i]?.nama || '', fu[i]?.nama || '', st[i]?.nama || ''])
  const wr = XLSX.utils.aoa_to_sheet(ref_); wr['!cols'] = [{ wch: 30 }, { wch: 32 }, { wch: 26 }]
  XLSX.utils.book_append_sheet(wb, wr, 'Referensi')
  XLSX.writeFile(wb, 'Templat-Impor-Pegawai-SIMKA-v1.0.xlsx')
}

// ---------- Pencocokan unit dan jabatan ----------
const kecil = (s) => String(s ?? '').trim().toLowerCase()
function cari(daftar, teks) {
  const t = kecil(teks); if (!t) return null
  const persis = daftar.find((x) => kecil(x.nama) === t || kecil(x.kode) === t)
  if (persis) return persis
  const mirip = daftar.filter((x) => kecil(x.nama).includes(t) || t.includes(kecil(x.nama).replace(/^(bidang|unit) /, '')))
  return mirip.length === 1 ? mirip[0] : null
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
    // Cari baris judul (baris pertama yang memuat sedikitnya 2 judul dikenal, dalam 10 baris awal)
    let iJudul = -1, peta = []
    for (let i = 0; i < Math.min(10, aoa.length); i++) {
      const p = aoa[i].map((j) => kenaliJudul(j))
      if (p.filter(Boolean).length >= 2 && p.includes('nama_lengkap')) { iJudul = i; peta = p; break }
    }
    if (iJudul < 0) return ui.toast('Kolom "Nama lengkap bergelar" tidak ditemukan. Pakai templat SIMKA PRO atau pastikan baris judul ada di bagian atas.', 'galat')
    kolomDikenal.value = [...new Set(peta.filter(Boolean))]
    kolomAsing.value = aoa[iJudul].filter((j, i) => j !== '' && !peta[i] && !/^no\.?$/i.test(String(j).trim()))
    const data = []
    aoa.slice(iJudul + 1).forEach((r, i) => {
      const o = {}; peta.forEach((k, c) => { if (k && o[k] === undefined) o[k] = r[c] })
      if (!Object.values(o).some((v) => String(v ?? '').trim() !== '')) return
      data.push(periksa(o, iJudul + i + 2))
    })
    namaBerkas.value = berkas.name; baris.value = data
    if (!data.length) ui.toast('Berkas tidak berisi baris data.', 'galat')
  } catch { ui.toast('Berkas tidak dapat dibaca. Pastikan berformat .xlsx, .xls, atau .csv.', 'galat') }
}

function periksa(o, nomorBaris) {
  const galat = [], isi = {}
  const s = (v) => String(v ?? '').trim()
  const set = (k, v, normal, pesan) => {
    if (s(v) === '') return
    const n = normal ? normal(v) : s(v)
    if (n === null) galat.push(pesan); else isi[k] = n
  }
  if (s(o.nama_lengkap).length < 3) galat.push('Nama lengkap kosong atau terlalu pendek.'); else isi.nama_lengkap = s(o.nama_lengkap)
  set('niy', o.niy, (v) => s(v).replace(/\.0$/, ''))
  set('jenis_kelamin', o.jenis_kelamin, normalJK, 'Jenis kelamin harus L atau P.')
  set('tempat_lahir', o.tempat_lahir)
  set('tanggal_lahir', o.tanggal_lahir, tanggal, 'Tanggal lahir tidak sah (tulis dd/mm/yyyy).')
  set('tmt_tugas', o.tmt_tugas, tanggal, 'TMT tugas tidak sah (tulis dd/mm/yyyy).')
  set('status_kepegawaian', o.status_kepegawaian, normalStatus, 'Status kepegawaian harus Tetap, Kontrak, atau Honorer.')
  set('kategori_honorer', o.kategori_honorer, normalHonorer, 'Kategori honorer harus Lama atau Baru.')
  set('pendidikan_terakhir', o.pendidikan_terakhir, normalPendidikan, 'Pendidikan harus SD, SMP, SMA, S1, S1-LN, S2, atau S3.')
  set('status_keluarga', o.status_keluarga, normalKeluarga, 'Status keluarga harus Menikah, Belum menikah, atau Cerai.')
  set('no_hp', o.no_hp, (v) => { const n = normalHP(v); return /^[0-9+]{9,16}$/.test(n) ? n : null }, 'Nomor HP harus 9–16 angka.')
  set('email', o.email, (v) => (/^\S+@\S+\.\S+$/.test(s(v)) ? s(v).toLowerCase() : null), 'Format email tidak sah.')
  set('level_muhaffizh', o.level_muhaffizh, normalLevel, 'Level muhaffizh harus Pemula, Terampil, atau Mahir.')
  set('status_keaktifan', o.status_keaktifan, normalKeaktifan, 'Status keaktifan harus Aktif, Cuti panjang, Nonaktif, atau Keluar.')
  if (s(o.unit)) { const u = cari(org.units, o.unit); if (u) isi.org_unit_id = u.id; else galat.push(`Bidang/unit "${s(o.unit)}" tidak dikenal.`) }
  if (s(o.fungsional)) {
    const ids = []
    for (const t of s(o.fungsional).split(/[,;/]| dan /).map((x) => x.trim()).filter(Boolean)) {
      const j = cari(org.fungsional, t); if (j) ids.push(j.id); else galat.push(`Jabatan fungsional "${t}" tidak dikenal.`)
    }
    const tunggal = ids.filter((id) => org.fungsional.find((x) => x.id === id)?.tanpa_rangkap)
    if (tunggal.length && ids.length > 1) galat.push('Medis atau security tidak boleh dirangkap dengan jabatan lain.')
    isi.fungsional_ids = [...new Set(ids)]
  }
  if (s(o.struktural)) {
    const j = cari(org.struktural, o.struktural)
    if (j) { isi.struktural_id = j.id; if (isi.org_unit_id) isi.unit_struktural_id = isi.org_unit_id } else galat.push(`Jabatan struktural "${s(o.struktural)}" tidak dikenal.`)
  }
  const ada = isi.niy && peg.daftar.find((p) => p.niy === isi.niy)
  return { nomorBaris, isi, galat, aksi: ada ? 'perbarui' : 'tambah', mentah: o }
}

// ---------- Kirim ----------
async function impor() {
  if (!siap.value.length) return
  const ok = await ui.konfirmasi({
    judul: `Impor ${siap.value.length} baris?`,
    pesan: `${siap.value.filter((b) => b.aksi === 'tambah').length} pegawai baru ditambahkan dan ${siap.value.filter((b) => b.aksi === 'perbarui').length} data lama diperbarui.${bermasalah.value.length ? ` ${bermasalah.value.length} baris bermasalah dilewati.` : ''}`,
    ya: 'Impor sekarang',
  })
  if (!ok) return
  proses.value = true
  try {
    const kirim = siap.value
    const h = await peg.impor(kirim.map((b) => b.isi))
    hasil.value = h.map((x, i) => ({ ...x, nomorBaris: kirim[i].nomorBaris, nama: kirim[i].isi.nama_lengkap }))
    const gagal = hasil.value.filter((x) => !x.ok).length
    ui.toast(gagal ? `Impor selesai: ${hasil.value.length - gagal} berhasil, ${gagal} gagal.` : `Impor selesai: ${hasil.value.length} baris berhasil.`)
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
function ulangi() { baris.value = []; hasil.value = null; namaBerkas.value = '' }
function unduhLaporan() {
  const ws = XLSX.utils.aoa_to_sheet([['Baris Excel', 'Nama', 'Hasil', 'Keterangan'],
    ...hasil.value.map((h) => [h.nomorBaris, h.nama, h.ok ? 'Berhasil' : 'Gagal', h.ok ? (h.aksi === 'ditambah' ? 'Pegawai baru ditambahkan' : 'Data lama diperbarui') : h.pesan]),
    ...bermasalah.value.map((b) => [b.nomorBaris, b.isi.nama_lengkap || '', 'Dilewati', b.galat.join(' ')])])
  ws['!cols'] = [{ wch: 11 }, { wch: 36 }, { wch: 10 }, { wch: 70 }]
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Hasil impor')
  XLSX.writeFile(wb, `Hasil-Impor-Pegawai-${formatPendek(new Date()).replace(/\//g, '-')}.xlsx`)
}
const JUDUL = Object.fromEntries(KOLOM_IMPOR.map((c) => [c.k, c.j.replace(/\s*\(.*\)$/, '')]))
</script>
<template>
  <div class="mx-auto max-w-5xl space-y-4">
    <!-- Langkah 1 -->
    <section class="kartu w-gaji flex flex-wrap items-center gap-4 p-5">
      <span class="chip-ikon h-12 w-12"><PhFileXls :size="28" weight="duotone" /></span>
      <div class="min-w-[220px] flex-1">
        <h2 class="judul-bagian">1. Unduh templat Excel</h2>
        <p class="text-sm text-teks3">Berisi kolom data pegawai, petunjuk, dan daftar nama bidang serta jabatan yang sah. Daftar Excel lama pondok juga dapat dipakai bila judul kolomnya serupa.</p>
      </div>
      <button class="tombol-garis" @click="unduhTemplat"><PhDownloadSimple :size="20" weight="duotone" /> Unduh templat</button>
    </section>

    <!-- Langkah 2 -->
    <section class="kartu w-pegawai flex flex-wrap items-center gap-4 p-5">
      <span class="chip-ikon h-12 w-12"><PhUploadSimple :size="28" weight="duotone" /></span>
      <div class="min-w-[220px] flex-1">
        <h2 class="judul-bagian">2. Pilih berkas yang sudah diisi</h2>
        <p class="text-sm text-teks3">{{ namaBerkas ? `Berkas: ${namaBerkas} (${baris.length} baris data)` : 'Format .xlsx, .xls, atau .csv. Data diperiksa dulu sebelum disimpan.' }}</p>
      </div>
      <label class="tombol-utama cursor-pointer"><PhUploadSimple :size="20" weight="duotone" /> {{ namaBerkas ? 'Ganti berkas' : 'Pilih berkas' }}
        <input type="file" accept=".xlsx,.xls,.csv" class="sr-only" @change="pilihBerkas" /></label>
    </section>

    <!-- Langkah 3: hasil pemeriksaan -->
    <section v-if="baris.length && !hasil" class="kartu p-5">
      <h2 class="judul-bagian">3. Periksa sebelum mengimpor</h2>
      <div class="mt-3 flex flex-wrap gap-2">
        <span class="lencana w-presensi px-3 py-1 text-sm"><PhCheckCircle :size="16" weight="fill" /> {{ siap.length }} baris siap</span>
        <span v-if="bermasalah.length" class="lencana w-klinik px-3 py-1 text-sm"><PhWarningCircle :size="16" weight="fill" /> {{ bermasalah.length }} baris perlu diperbaiki</span>
        <span class="lencana w-hakakses px-3 py-1 text-sm">{{ siap.filter((b) => b.aksi === 'perbarui').length }} memperbarui data lama (NIY sama)</span>
      </div>
      <p class="mt-2 text-sm text-teks3">Kolom dikenali: {{ kolomDikenal.map((k) => JUDUL[k]).join(', ') }}.</p>
      <p v-if="kolomAsing.length" class="mt-1 text-sm text-teks3">Kolom diabaikan: {{ kolomAsing.join(', ') }}.</p>

      <ul class="mt-4 max-h-[55vh] divide-y divide-garis overflow-y-auto rounded-xl border border-garis">
        <li v-for="b in baris" :key="b.nomorBaris" :class="['flex gap-3 p-3', b.galat.length ? 'w-klinik' : 'w-presensi']">
          <span class="chip-ikon mt-0.5 h-8 w-8 rounded-lg"><component :is="b.galat.length ? PhWarningCircle : PhCheckCircle" :size="18" weight="duotone" /></span>
          <div class="min-w-0 flex-1">
            <p class="font-semibold">{{ b.isi.nama_lengkap || '(tanpa nama)' }} <span class="text-xs font-normal text-teks3">– baris {{ b.nomorBaris }}{{ b.isi.niy ? ', NIY ' + b.isi.niy : '' }}{{ b.galat.length ? '' : b.aksi === 'perbarui' ? ', memperbarui data lama' : ', pegawai baru' }}</span></p>
            <p v-for="g in b.galat" :key="g" class="text-sm font-semibold" style="color: var(--c)">{{ g }}</p>
          </div>
        </li>
      </ul>
      <p v-if="bermasalah.length" class="mt-3 text-sm text-teks2">Perbaiki baris bermasalah di Excel lalu pilih ulang berkasnya, atau lanjutkan impor tanpa baris tersebut.</p>
      <div class="mt-4 flex flex-wrap justify-end gap-2">
        <button class="tombol-garis" @click="ulangi"><PhArrowCounterClockwise :size="20" /> Batal</button>
        <button class="tombol-utama" :disabled="!siap.length || proses" @click="impor"><PhUploadSimple :size="20" weight="duotone" /> {{ proses ? 'Mengimpor…' : `Impor ${siap.length} baris` }}</button>
      </div>
    </section>

    <!-- Langkah 4: hasil impor -->
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
        <router-link to="/pegawai" class="tombol-utama">Lihat data pegawai</router-link>
      </div>
    </section>
  </div>
</template>
