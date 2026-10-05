<!-- SIMKA PRO | src/pages/tahfizh/ImporHafalan.vue | v1.0 | Fase 5 – Tahap 1 Pengaturan tahfizh dan data hafalan awal | 05/10/2026 -->
<script setup>
// Impor data hafalan awal dari Excel: program, juz resmi (data awal), posisi sabaq/sabqi/manzil, juz sedang dihafal.
// Templat = ekspor data hafalan saat ini (semua santri pada cakupan), sehingga cukup dilengkapi lalu diunggah kembali.
// Hanya baris yang berubah yang dikirim. Juz hasil ujian/sertifikasi tidak dapat dihapus lewat impor.
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import * as XLSX from 'xlsx'
import { PhDownloadSimple, PhFileXls, PhCheckCircle, PhWarningCircle, PhUploadSimple, PhArrowCounterClockwise } from '@phosphor-icons/vue'
import { useTahfizh } from '@/stores/tahfizh'
import { useUI } from '@/stores/ui'
import { PROGRAM, dariHal, keHal, uraiJuz, ringkasJuz, formatPosisi } from '@/lib/tahfizh'
import { formatPendek } from '@/lib/tanggal'

const tz = useTahfizh(); const ui = useUI(); const router = useRouter()
onMounted(async () => {
  await tz.muatHak()
  if (!tz.hak.validasi) { ui.toast('Impor hafalan awal hanya untuk admin ber-izin validasi tahfizh atau pimpinan Bidang Tahfizh.', 'galat'); return router.replace('/tahfizh') }
  await tz.muatSantri()
})

const JUDUL = { nis: ['nis', 'nomor induk'], program: ['program', 'program (reguler/takhassus)'], juz: ['juz resmi', 'juz resmi (mis. 1-5, 30)', 'juz'],
  sabaq_juz: ['sabaq juz'], sabaq_hal: ['sabaq halaman', 'sabaq hal'], sabqi_juz: ['sabqi juz'], sabqi_hal: ['sabqi halaman', 'sabqi hal'],
  manzil_juz: ['manzil juz'], manzil_hal: ['manzil halaman', 'manzil hal'], juz_sedang: ['juz sedang dihafal', 'juz sedang'] }
const kenali = (j) => { const t = String(j ?? '').trim().toLowerCase().replace(/[*:]/g, '').trim(); return t.startsWith('info') ? null : Object.keys(JUDUL).find((k) => JUDUL[k].includes(t)) || null }

const namaBerkas = ref(''); const baris = ref([]); const hasil = ref(null); const proses = ref(false)
const siap = computed(() => baris.value.filter((b) => !b.galat.length && b.ubah))
const bermasalah = computed(() => baris.value.filter((b) => b.galat.length))
const tetap = computed(() => baris.value.filter((b) => !b.galat.length && !b.ubah))

function unduhTemplat() {
  const judul = ['NIS', 'Info: Nama', 'Info: Kelas', 'Info: Halaqah', 'Program (Reguler/Takhassus)', 'Juz resmi (mis. 1-5, 30)', 'Sabaq juz', 'Sabaq halaman',
    'Sabqi juz', 'Sabqi halaman', 'Manzil juz', 'Manzil halaman', 'Juz sedang dihafal']
  const urut = [...tz.santri].sort((a, b) => String(a.halaqah || '~').localeCompare(String(b.halaqah || '~'), 'id') || a.nama.localeCompare(b.nama, 'id'))
  const data = urut.map((s) => [s.nis, s.nama, s.kelas || s.tingkat, s.halaqah || '', PROGRAM[s.program], ringkasJuz(s.juz_resmi).replace(/–/g, '-'),
    dariHal(s.sabaq_hal).juz, dariHal(s.sabaq_hal).hal, dariHal(s.sabqi_hal).juz, dariHal(s.sabqi_hal).hal, dariHal(s.manzil_hal).juz, dariHal(s.manzil_hal).hal, s.juz_sedang || ''])
  const ws = XLSX.utils.aoa_to_sheet([judul, ...data])
  ws['!cols'] = [{ wch: 10 }, { wch: 30 }, { wch: 8 }, { wch: 24 }, { wch: 14 }, { wch: 22 }, ...Array(6).fill({ wch: 10 }), { wch: 12 }]
  for (const r of Object.keys(ws)) if (!r.startsWith('!') && ws[r].t === 's') ws[r].z = '@'
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Hafalan')
  const p = XLSX.utils.aoa_to_sheet([['Petunjuk impor data hafalan awal SIMKA PRO (versi 1.0)'], [''],
    ['1. Lembar "Hafalan" berisi santri pada cakupan Anda beserta data hafalannya saat ini. Lengkapi atau ubah, lalu unggah kembali.'],
    ['2. NIS dipakai untuk mencocokkan santri; jangan diubah. Kolom berawalan "Info:" tidak diimpor.'],
    ['3. Program: Reguler atau Takhassus. Kosong = tidak diubah.'],
    ['4. Juz resmi: nomor juz yang sudah hafal sebelum SIMKA dipakai, dipisah koma; rentang memakai tanda minus (contoh: 1-5, 30). Urutan bebas.'],
    ['   Isian ini MENGGANTI daftar juz data awal santri itu. Juz hasil ujian/sertifikasi tetap tersimpan. Kosong = tidak diubah.'],
    ['5. Posisi ditulis Juz + Halaman (20 halaman = 1 juz; halaman 20 atau lebih otomatis menjadi juz). Sabaq = jumlah hafalan berjalan.'],
    ['   Sabqi dan manzil = posisi muraja\'ah yang sedang diulang. Bila kedua sel (juz dan halaman) kosong, posisi tidak diubah.'],
    ['6. Juz sedang dihafal: satu nomor juz 1–30 (boleh kosong).']])
  p['!cols'] = [{ wch: 130 }]; XLSX.utils.book_append_sheet(wb, p, 'Petunjuk')
  XLSX.writeFile(wb, `Templat-Hafalan-Awal-${formatPendek(new Date()).replace(/\//g, '-')}.xlsx`)
}

const angka = (v) => { const t = String(v ?? '').trim(); return t === '' ? null : /^\d+$/.test(t) ? Number(t) : NaN }
function posisi(o, k, galat) {
  const j = angka(o[k + '_juz']); const h = angka(o[k + '_hal'])
  if (j === null && h === null) return undefined
  if (Number.isNaN(j) || Number.isNaN(h)) { galat.push(`Posisi ${k} harus angka.`); return undefined }
  const total = keHal(j || 0, h || 0)
  if ((j || 0) * 20 + (h || 0) > 600) galat.push(`Posisi ${k} melebihi 30 juz.`)
  return total
}

async function pilihBerkas(e) {
  const berkas = e.target.files?.[0]; e.target.value = ''
  if (!berkas) return
  hasil.value = null
  try {
    const wb = XLSX.read(await berkas.arrayBuffer())
    const aoa = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]], { header: 1, defval: '', raw: false })
    let iJudul = -1; let peta = []
    for (let i = 0; i < Math.min(10, aoa.length); i++) { const p = aoa[i].map(kenali); if (p.includes('nis') && p.filter(Boolean).length >= 2) { iJudul = i; peta = p; break } }
    if (iJudul < 0) return ui.toast('Kolom NIS dan kolom hafalan tidak ditemukan. Pakai templat hafalan awal.', 'galat')
    const data = []
    aoa.slice(iJudul + 1).forEach((r, i) => {
      const o = {}; peta.forEach((k, c) => { if (k && o[k] === undefined) o[k] = String(r[c] ?? '').trim() })
      if (!o.nis) return
      o.nis = o.nis.replace(/\.0$/, '')
      const galat = []; const s = tz.santri.find((x) => x.nis === o.nis)
      if (!/^\d{7}$/.test(o.nis)) galat.push('NIS harus 7 angka.')
      else if (!s) galat.push(`NIS ${o.nis} tidak ada pada cakupan Anda atau belum terdaftar.`)
      const isi = { nis: o.nis }; const ubah = []
      if (o.program) {
        const p = o.program.toLowerCase().startsWith('takh') ? 'takhassus' : o.program.toLowerCase().startsWith('reg') ? 'reguler' : null
        if (!p) galat.push('Program harus Reguler atau Takhassus.'); else { isi.program = p; if (s && s.program !== p) ubah.push(`program ${PROGRAM[p]}`) }
      }
      if (o.juz) {
        const u = uraiJuz(o.juz); galat.push(...u.galat)
        if (!u.galat.length) {
          isi.juz = u.juz
          const kunci = s ? s.juz_resmi.filter((j) => !s.juz_awal.includes(j)) : []
          const awalBaru = u.juz.filter((j) => !kunci.includes(j))
          if (s && ringkasJuz(awalBaru) !== ringkasJuz(s.juz_awal)) ubah.push(`juz ${ringkasJuz(u.juz)}`)
        }
      }
      for (const k of ['sabaq', 'sabqi', 'manzil']) {
        const v = posisi(o, k, galat)
        if (v !== undefined) { isi[k + '_hal'] = v; if (s && s[k + '_hal'] !== v) ubah.push(`${k} ${formatPosisi(v)}`) }
      }
      if (o.juz_sedang !== undefined && o.juz_sedang !== '') {
        const j = angka(o.juz_sedang)
        if (Number.isNaN(j) || j < 1 || j > 30) galat.push('Juz sedang dihafal harus 1–30.'); else { isi.juz_sedang = j; if (s && s.juz_sedang !== j) ubah.push(`sedang juz ${j}`) }
      }
      data.push({ nomorBaris: iJudul + i + 2, isi, galat, ubah: ubah.length > 0, ringkas: ubah.join(', '), nama: s?.nama || '' })
    })
    namaBerkas.value = berkas.name; baris.value = data
    if (!data.length) ui.toast('Berkas tidak berisi baris data.', 'galat')
  } catch { ui.toast('Berkas tidak dapat dibaca. Pastikan berformat .xlsx, .xls, atau .csv.', 'galat') }
}

async function impor() {
  if (!siap.value.length) return
  if (!(await ui.konfirmasi({ judul: `Impor ${siap.value.length} baris?`, pesan: 'Data hafalan awal santri pada baris ini diperbarui dan langsung dianggap resmi. Juz hasil ujian/sertifikasi tidak berubah.', ya: 'Impor sekarang' }))) return
  proses.value = true
  try {
    const kirim = siap.value
    const h = await tz.imporHafalanAwal(kirim.map((b) => b.isi))
    hasil.value = h.map((x, i) => ({ ...x, nomorBaris: kirim[i].nomorBaris, nama: x.nama || kirim[i].nama || kirim[i].isi.nis }))
    const gagal = hasil.value.filter((x) => !x.ok).length
    ui.toast(gagal ? `Impor selesai: ${hasil.value.length - gagal} tersimpan, ${gagal} perlu diperiksa.` : `Impor selesai: ${hasil.value.length} santri.`)
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
function ulangi() { baris.value = []; hasil.value = null; namaBerkas.value = '' }
</script>
<template>
  <div class="mx-auto max-w-5xl space-y-4">
    <section class="kartu w-gaji flex flex-wrap items-center gap-4 p-5">
      <span class="chip-ikon h-12 w-12"><PhFileXls :size="28" weight="duotone" /></span>
      <div class="min-w-[220px] flex-1">
        <h2 class="judul-bagian">1. Unduh templat hafalan awal</h2>
        <p class="text-sm text-teks3">Berisi {{ tz.santri.length }} santri pada cakupan Anda beserta program, juz resmi, dan posisi hafalannya saat ini.</p>
      </div>
      <button class="tombol-garis" :disabled="!tz.santri.length" @click="unduhTemplat"><PhDownloadSimple :size="20" weight="duotone" /> Unduh templat</button>
    </section>
    <section class="kartu w-tahfizh flex flex-wrap items-center gap-4 p-5">
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
      <ul class="mt-3 max-h-[50dvh] divide-y divide-garis overflow-y-auto rounded-xl border border-garis text-sm">
        <li v-for="b in [...bermasalah, ...siap]" :key="b.nomorBaris" class="flex gap-3 px-3 py-2">
          <span class="w-14 shrink-0 tabular-nums text-teks3">Baris {{ b.nomorBaris }}</span>
          <span class="min-w-0 flex-1"><b>{{ b.nama || b.isi.nis }}</b>
            <span v-if="b.galat.length" class="block text-merah">{{ b.galat.join(' ') }}</span>
            <span v-else class="block text-teks2">{{ b.ringkas }}</span></span>
        </li>
      </ul>
      <div class="mt-4 flex flex-wrap gap-2">
        <button class="tombol-utama" :disabled="proses || !siap.length" @click="impor"><PhUploadSimple :size="20" weight="duotone" /> {{ proses ? 'Mengimpor…' : `Impor ${siap.length} baris` }}</button>
        <button class="tombol-garis" @click="ulangi"><PhArrowCounterClockwise :size="20" /> Batal</button>
      </div>
    </section>

    <section v-if="hasil" class="kartu p-5">
      <h2 class="judul-bagian">Hasil impor</h2>
      <ul class="mt-3 max-h-[55dvh] divide-y divide-garis overflow-y-auto rounded-xl border border-garis text-sm">
        <li v-for="h in hasil" :key="h.nomorBaris" class="flex items-start gap-3 px-3 py-2">
          <component :is="h.ok ? PhCheckCircle : PhWarningCircle" :size="20" weight="fill" :class="h.ok ? 'text-[#1E7D4F] dark:text-[#5BD69A]' : 'text-merah'" />
          <span class="min-w-0 flex-1"><b>Baris {{ h.nomorBaris }} · {{ h.nama }}</b><span class="block text-teks2">{{ h.pesan }}</span></span>
        </li>
      </ul>
      <div class="mt-4 flex flex-wrap gap-2">
        <router-link to="/tahfizh/santri" class="tombol-utama">Lihat data hafalan</router-link>
        <button class="tombol-garis" @click="ulangi"><PhArrowCounterClockwise :size="20" /> Impor berkas lain</button>
      </div>
    </section>
  </div>
</template>
