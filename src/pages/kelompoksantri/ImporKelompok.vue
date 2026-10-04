<!-- SIMKA PRO | src/pages/kelompoksantri/ImporKelompok.vue | v1.0 | Fase 4 – Tahap 2 Kelompok santri | 04/10/2026 -->
<script setup>
// Impor pembagian kelas, kamar, halaqah, dan ekskul dari Excel. Templat berisi semua santri aktif beserta
// pembagian saat ini, sehingga cukup diisi/diubah lalu diunggah kembali. Kelompok yang belum ada dibuat otomatis.
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import * as XLSX from 'xlsx'
import { PhDownloadSimple, PhFileXls, PhCheckCircle, PhWarningCircle, PhUploadSimple, PhArrowCounterClockwise } from '@phosphor-icons/vue'
import { useKelompokSantri } from '@/stores/kelompokSantri'
import { useSantri } from '@/stores/santri'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { namaKelompok, JENJANG_PENDEK } from '@/lib/santri'
import { formatPendek } from '@/lib/tanggal'

const kel = useKelompokSantri(); const san = useSantri(); const sesi = useSesi(); const ui = useUI(); const router = useRouter()
onMounted(async () => {
  if (!(sesi.bolehAdmin('kelompok_santri') || sesi.tingkat('kelompok_santri') >= 2)) { ui.toast('Impor pembagian hanya untuk admin ber-izin kelompok santri.', 'galat'); return router.replace('/kelompok-santri') }
  await Promise.all([kel.muat(), san.muat()])
})
const KOLOM = { nis: ['nis', 'nomor induk', 'no induk'], kelas: ['kelas', 'rombel', 'kelas/rombel'], kamar: ['kamar', 'asrama', 'kamar/asrama'], halaqah: ['halaqah', 'halaqoh', 'halaqah tahfizh'], ekskul: ['ekskul', 'ekstrakurikuler', 'ekskul (pisahkan koma)'] }
const kenali = (j) => { const t = String(j ?? '').trim().toLowerCase().replace(/\s*\(.*\)\s*$/, '').replace(/[*:]/g, '').trim(); return Object.keys(KOLOM).find((k) => KOLOM[k].includes(t)) || null }

const namaBerkas = ref(''); const baris = ref([]); const hasil = ref(null); const proses = ref(false)
const siap = computed(() => baris.value.filter((b) => !b.galat.length && b.ubah))
const bermasalah = computed(() => baris.value.filter((b) => b.galat.length))
const tetap = computed(() => baris.value.filter((b) => !b.galat.length && !b.ubah))

function unduhTemplat() {
  const aktif = san.daftar.filter((s) => s.status === 'aktif').sort((a, b) => a.tingkat - b.tingkat || a.nama_lengkap.localeCompare(b.nama_lengkap, 'id'))
  const isi = [['NIS', 'Nama (tidak diimpor)', 'Kelas santri (tidak diimpor)', 'Kelas', 'Kamar', 'Halaqah', 'Ekskul (pisahkan koma)'],
    ...aktif.map((s) => [s.nis, s.nama_lengkap, `${s.tingkat} ${JENJANG_PENDEK[s.jenjang]} ${s.jenis_kelamin}`, namaKelompok(s, 'kelas'), namaKelompok(s, 'kamar'), namaKelompok(s, 'halaqah'), namaKelompok(s, 'ekskul')])]
  const ws = XLSX.utils.aoa_to_sheet(isi); ws['!cols'] = [{ wch: 10 }, { wch: 30 }, { wch: 18 }, { wch: 10 }, { wch: 22 }, { wch: 26 }, { wch: 30 }]
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Pembagian')
  const petunjuk = [['Petunjuk impor pembagian kelompok SIMKA PRO (versi 1.0)'], [''],
    ['1. Lembar "Pembagian" sudah berisi semua santri aktif beserta kelompoknya saat ini. Isi atau ubah kolom Kelas, Kamar, Halaqah, dan Ekskul.'],
    ['2. Tulis nama kelompok persis sama untuk santri sekelompok (mis. "7A", "Kamar Abu Bakar", "Halaqah Ust. Ahmad"). Nama baru otomatis dibuat sebagai kelompok baru.'],
    ['3. Kelas baru: angka di depan nama menjadi tingkatnya (7A → kelas 7). Santri hanya dapat masuk kelas yang tingkatnya sama dengan kelasnya di Data Santri.'],
    ['4. Kamar dan halaqah baru mengikuti jenis kelamin santri pertama yang dimasukkan; santri berbeda jenis kelamin akan ditolak.'],
    ['5. Satu santri hanya satu kelas, satu kamar, satu halaqah. Bila berbeda dari sebelumnya, santri DIPINDAHKAN dan riwayatnya tersimpan.'],
    ['6. Ekskul boleh lebih dari satu, pisahkan dengan koma. Sel kosong tidak mengeluarkan santri dari kelompoknya.'],
    ['7. Pengasuh (wali kelas, musyrif, muhaffizh, pembina) ditetapkan di aplikasi pada halaman setiap kelompok.']]
  const wp = XLSX.utils.aoa_to_sheet(petunjuk); wp['!cols'] = [{ wch: 130 }]; XLSX.utils.book_append_sheet(wb, wp, 'Petunjuk')
  XLSX.writeFile(wb, `Templat-Pembagian-Kelompok-${formatPendek(new Date()).replace(/\//g, '-')}.xlsx`)
}

async function pilihBerkas(e) {
  const berkas = e.target.files?.[0]; e.target.value = ''
  if (!berkas) return
  hasil.value = null
  try {
    const wb = XLSX.read(await berkas.arrayBuffer())
    const aoa = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]], { header: 1, defval: '', raw: false })
    let iJudul = -1, peta = []
    for (let i = 0; i < Math.min(10, aoa.length); i++) { const p = aoa[i].map(kenali); if (p.includes('nis') && p.filter(Boolean).length >= 2) { iJudul = i; peta = p; break } }
    if (iJudul < 0) return ui.toast('Kolom NIS dan sedikitnya satu kolom Kelas/Kamar/Halaqah/Ekskul tidak ditemukan. Pakai templat pembagian.', 'galat')
    const data = []
    aoa.slice(iJudul + 1).forEach((r, i) => {
      const o = {}; peta.forEach((k, c) => { if (k && o[k] === undefined) o[k] = String(r[c] ?? '').trim() })
      if (!o.nis) return
      const galat = []; const s = san.daftar.find((x) => x.nis === o.nis.replace(/\.0$/, ''))
      if (!/^\d{7}$/.test(o.nis)) galat.push('NIS harus 7 angka.')
      else if (!s) galat.push(`NIS ${o.nis} belum terdaftar di Data Santri.`)
      const isi = { nis: o.nis }
      let ubah = false
      for (const j of ['kelas', 'kamar', 'halaqah', 'ekskul']) {
        if (!o[j]) continue
        isi[j] = o[j]
        if (!s) continue
        const lama = namaKelompok(s, j).toLowerCase().split(/\s*,\s*/).filter(Boolean)
        const baru = o[j].toLowerCase().split(j === 'ekskul' ? /\s*[,;]\s*/ : /\s*;\s*/).filter(Boolean)
        if (baru.some((n) => !lama.includes(n))) ubah = true
      }
      data.push({ nomorBaris: iJudul + i + 2, isi, galat, ubah, nama: s?.nama_lengkap || '' })
    })
    namaBerkas.value = berkas.name; baris.value = data
    if (!data.length) ui.toast('Berkas tidak berisi baris data.', 'galat')
  } catch { ui.toast('Berkas tidak dapat dibaca. Pastikan berformat .xlsx, .xls, atau .csv.', 'galat') }
}

async function impor() {
  if (!siap.value.length) return
  if (!(await ui.konfirmasi({ judul: `Impor ${siap.value.length} baris?`, pesan: `${siap.value.length} santri ditambahkan atau dipindahkan ke kelompok sesuai berkas. Kelompok yang belum ada dibuat otomatis di tahun ajaran aktif.`, ya: 'Impor sekarang' }))) return
  proses.value = true
  try {
    const kirim = siap.value
    const h = await kel.impor(kirim.map((b) => b.isi))
    hasil.value = h.map((x, i) => ({ ...x, nomorBaris: kirim[i].nomorBaris, nama: x.nama || kirim[i].nama || kirim[i].isi.nis }))
    const gagal = hasil.value.filter((x) => !x.ok).length
    ui.toast(gagal ? `Impor selesai: ${hasil.value.length - gagal} lengkap, ${gagal} perlu diperiksa.` : `Impor selesai: ${hasil.value.length} santri.`)
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
function ulangi() { baris.value = []; hasil.value = null; namaBerkas.value = '' }
</script>
<template>
  <div class="mx-auto max-w-5xl space-y-4">
    <section class="kartu w-gaji flex flex-wrap items-center gap-4 p-5">
      <span class="chip-ikon h-12 w-12"><PhFileXls :size="28" weight="duotone" /></span>
      <div class="min-w-[220px] flex-1">
        <h2 class="judul-bagian">1. Unduh templat pembagian</h2>
        <p class="text-sm text-teks3">Berisi {{ san.daftar.filter((s) => s.status === 'aktif').length }} santri aktif beserta kelas, kamar, halaqah, dan ekskulnya saat ini (tahun ajaran {{ kel.taAktif?.nama || '–' }}).</p>
      </div>
      <button class="tombol-garis" @click="unduhTemplat"><PhDownloadSimple :size="20" weight="duotone" /> Unduh templat</button>
    </section>
    <section class="kartu w-kelompoksantri flex flex-wrap items-center gap-4 p-5">
      <span class="chip-ikon h-12 w-12"><PhUploadSimple :size="28" weight="duotone" /></span>
      <div class="min-w-[220px] flex-1">
        <h2 class="judul-bagian">2. Pilih berkas yang sudah diisi</h2>
        <p class="text-sm text-teks3">{{ namaBerkas ? `Berkas: ${namaBerkas} (${baris.length} baris)` : 'Hanya baris yang berubah yang dikirim.' }}</p>
      </div>
      <label class="tombol-utama cursor-pointer"><PhUploadSimple :size="20" weight="duotone" /> {{ namaBerkas ? 'Ganti berkas' : 'Pilih berkas' }}
        <input type="file" accept=".xlsx,.xls,.csv" class="sr-only" @change="pilihBerkas" /></label>
    </section>

    <section v-if="baris.length && !hasil" class="kartu p-5">
      <h2 class="judul-bagian">3. Periksa sebelum mengimpor</h2>
      <div class="mt-3 flex flex-wrap gap-2">
        <span class="lencana w-presensi px-3 py-1 text-sm"><PhCheckCircle :size="16" weight="fill" /> {{ siap.length }} baris berubah</span>
        <span class="lencana w-hakakses px-3 py-1 text-sm">{{ tetap.length }} baris tanpa perubahan (dilewati)</span>
        <span v-if="bermasalah.length" class="lencana w-klinik px-3 py-1 text-sm"><PhWarningCircle :size="16" weight="fill" /> {{ bermasalah.length }} baris bermasalah</span>
      </div>
      <ul class="mt-4 max-h-[55vh] divide-y divide-garis overflow-y-auto rounded-xl border border-garis">
        <li v-for="b in [...bermasalah, ...siap]" :key="b.nomorBaris" :class="['flex gap-3 p-3', b.galat.length ? 'w-klinik' : 'w-presensi']">
          <span class="chip-ikon mt-0.5 h-8 w-8 rounded-lg"><component :is="b.galat.length ? PhWarningCircle : PhCheckCircle" :size="18" weight="duotone" /></span>
          <div class="min-w-0 flex-1">
            <p class="font-semibold">{{ b.nama || b.isi.nis }} <span class="text-xs font-normal text-teks3">– baris {{ b.nomorBaris }}</span></p>
            <p class="text-sm text-teks2">{{ ['kelas', 'kamar', 'halaqah', 'ekskul'].filter((j) => b.isi[j]).map((j) => `${j}: ${b.isi[j]}`).join(' · ') }}</p>
            <p v-for="x in b.galat" :key="x" class="text-sm font-semibold" style="color: var(--c)">{{ x }}</p>
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
      <p class="mt-1 text-sm text-teks2">{{ hasil.filter((h) => h.ok).length }} baris lengkap, {{ hasil.filter((h) => !h.ok).length }} perlu diperiksa.</p>
      <ul class="mt-3 max-h-[50vh] space-y-1 overflow-y-auto text-sm">
        <li v-for="h in hasil.filter((x) => !x.ok || x.pesan)" :key="h.nomorBaris" :class="h.ok ? 'w-presensi' : 'w-klinik'">
          <span class="font-semibold">Baris {{ h.nomorBaris }} ({{ h.nama }}):</span> <span :style="h.ok ? '' : 'color: var(--c)'">{{ h.pesan || 'Berhasil' }}</span></li>
      </ul>
      <div class="mt-4 flex flex-wrap justify-end gap-2">
        <button class="tombol-garis" @click="ulangi"><PhArrowCounterClockwise :size="20" /> Impor berkas lain</button>
        <router-link to="/kelompok-santri" class="tombol-utama">Lihat kelompok</router-link>
      </div>
    </section>
  </div>
</template>
