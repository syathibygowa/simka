<!-- SIMKA PRO | src/pages/absensisantri/TabBerulang.vue | v1.1 | Perbaikan 13.6.0: sub-tab bergaris bawah | 15/10/2026 -->
<script setup>
// Santri dengan ketidakhadiran berulang pada satu periode, untuk tindakan dan penanganan lanjutan:
//   Sakit     = absen kode S (kelas, halaqah, asrama, ekskul, pelajaran) + kasus klinik
//   Izin      = absen kode I + izin keluar/pulang pondok
//   Alfa      = absen kode A (tanpa keterangan)
//   Bolos     = absen kode B
//   Terlambat = absen kode T + terlambat kembali dari izin
// Saringan: kategori, kegiatan, putra/putri, ambang minimal. Ketuk santri → riwayat rinci per tanggal.
// Cetak F4 dan ekspor Excel. Hanya santri yang boleh dilihat pengguna (wali kelas: kelasnya; musyrif: kamarnya; dst.).
import { ref, computed, onMounted, watch } from 'vue'
import * as XLSX from 'xlsx'
import { PhFirstAidKit, PhSignOut, PhQuestion, PhPersonSimpleRun, PhClock, PhPrinter, PhFileXls, PhCaretRight, PhUser, PhInfo } from '@phosphor-icons/vue'
import { useAbsensiSantri } from '@/stores/absensiSantri'
import { useSantri } from '@/stores/santri'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { kelompokDari } from '@/lib/santri'
import { hariIniISO, formatPendek, formatPanjang } from '@/lib/tanggal'
import InputTanggal from '@/components/InputTanggal.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const abs = useAbsensiSantri(); const san = useSantri(); const sesi = useSesi(); const ui = useUI()
const geser = (iso, n) => { const d = new Date(`${iso}T12:00:00+08:00`); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10) }
const selesai = ref(hariIniISO()); const mulai = ref(geser(hariIniISO(), -29)); const data = ref([]); const memuat = ref(false)
const kategori = ref('sakit'); const kegiatan = ref(''); const jk = ref(''); const ambang = ref(3)
async function muat() {
  if (selesai.value < mulai.value) return ui.toast('Tanggal akhir tidak boleh sebelum tanggal mulai.', 'galat')
  memuat.value = true
  try { await san.muat(); data.value = await abs.berulang(mulai.value, selesai.value) } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
onMounted(muat); watch([mulai, selesai], muat)
function periode(n) { selesai.value = hariIniISO(); mulai.value = geser(hariIniISO(), -(n - 1)) }

const KAT = {
  sakit: { n: 'Sering sakit', kode: 'S', ikon: PhFirstAidKit, w: 'klinik', tambah: (r) => r.klinik, label: 'kasus klinik' },
  izin: { n: 'Sering izin', kode: 'I', ikon: PhSignOut, w: 'pengajuan', tambah: (r) => r.izin, label: 'izin keluar/pulang' },
  alfa: { n: 'Sering alfa', kode: 'A', ikon: PhQuestion, w: 'hakakses', tambah: () => 0 },
  bolos: { n: 'Sering bolos', kode: 'B', ikon: PhPersonSimpleRun, w: 'shift', tambah: () => 0 },
  terlambat: { n: 'Sering terlambat', kode: 'T', ikon: PhClock, w: 'agenda', tambah: (r) => r.telat_kembali, label: 'terlambat kembali' },
}
const KEGIATAN = { kelas: 'Kelas', halaqah: 'Halaqah', asrama: 'Asrama', ekskul: 'Ekskul', pelajaran: 'Pelajaran' }
const hitung = (r, kode, keg = kegiatan.value) => Object.entries(r.absen || {}).filter(([j]) => !keg || j === keg).reduce((n, [, v]) => n + (v[kode] || 0), 0)
const total = (r, k) => hitung(r, KAT[k].kode) + (kegiatan.value ? 0 : KAT[k].tambah(r) || 0)
const rinci = (r, k) => [...Object.keys(KEGIATAN).filter((j) => !kegiatan.value || j === kegiatan.value).map((j) => [KEGIATAN[j], r.absen?.[j]?.[KAT[k].kode] || 0]),
  ...(!kegiatan.value && KAT[k].label ? [[KAT[k].label.charAt(0).toUpperCase() + KAT[k].label.slice(1), KAT[k].tambah(r) || 0]] : [])].filter(([, n]) => n > 0).map(([a, n]) => `${a} ${n}`).join(' · ')

const baris = computed(() => data.value.map((r) => { const s = san.cari(r.id); return s ? { ...r, s, kelas: kelompokDari(s, 'kelas')?.nama || '–', kamar: kelompokDari(s, 'kamar')?.nama || '–' } : null })
  .filter((r) => r && (!jk.value || r.s.jenis_kelamin === jk.value)))
const tampil = computed(() => baris.value.map((r) => ({ ...r, n: total(r, kategori.value) })).filter((r) => r.n >= ambang.value).sort((a, b) => b.n - a.n || a.s.nama_lengkap.localeCompare(b.s.nama_lengkap, 'id')))
const jumlahKat = computed(() => Object.fromEntries(Object.keys(KAT).map((k) => [k, baris.value.filter((r) => total(r, k) >= ambang.value).length])))

// Riwayat rinci satu santri
const lembar = ref(false); const pilih = ref(null); const riwayat = ref([]); const memuatR = ref(false)
const KODE_N = { S: 'Sakit', I: 'Izin', A: 'Alfa', B: 'Bolos', T: 'Terlambat' }
async function buka(r) {
  pilih.value = r; lembar.value = true; memuatR.value = true; riwayat.value = []
  try { riwayat.value = await abs.riwayat(r.id, mulai.value, selesai.value) } catch (e) { ui.toast(e.message, 'galat') } finally { memuatR.value = false }
}
const riwayatTampil = computed(() => riwayat.value.filter((x) => (kategori.value === 'sakit' ? x.kode === 'S' : x.kode === KAT[kategori.value].kode) && (!kegiatan.value || x.jenis === kegiatan.value)))

const pratinjau = ref(false)
const judulCetak = computed(() => `Daftar Santri ${KAT[kategori.value].n.replace('Sering', 'Sering')}`)
const subjudul = computed(() => `${formatPanjang(mulai.value)} s.d. ${formatPanjang(selesai.value)} · minimal ${ambang.value} kali${kegiatan.value ? ' · ' + KEGIATAN[kegiatan.value] : ''}${jk.value ? ' · ' + (jk.value === 'L' ? 'Putra' : 'Putri') : ''}`)
function ekspor() {
  const kolom = ['No.', 'NIS', 'Nama', 'L/P', 'Kelas', 'Kamar', 'Sakit', 'Izin', 'Alfa', 'Bolos', 'Terlambat', 'Kasus klinik', 'Izin keluar/pulang', 'Terlambat kembali', 'Keluhan klinik']
  const d = tampil.value.map((r, i) => [i + 1, r.s.nis || '', r.s.nama_lengkap, r.s.jenis_kelamin, r.kelas, r.kamar, hitung(r, 'S'), hitung(r, 'I'), hitung(r, 'A'), hitung(r, 'B'), hitung(r, 'T'), r.klinik || 0, r.izin || 0, r.telat_kembali || 0, r.keluhan || ''])
  const ws = XLSX.utils.aoa_to_sheet([[judulCetak.value], [subjudul.value], [], kolom, ...d]); ws['!cols'] = kolom.map((k) => ({ wch: Math.max(6, k.length + 2) })); ws['!cols'][2] = { wch: 30 }
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Santri berulang'); XLSX.writeFile(wb, `Santri-${kategori.value}-berulang-${mulai.value}_${selesai.value}.xlsx`)
}
</script>
<template>
  <div class="space-y-4">
    <div class="kartu grid gap-3 p-4 sm:grid-cols-2 lg:grid-cols-4">
      <InputTanggal v-model="mulai" label="Dari tanggal" />
      <InputTanggal v-model="selesai" label="Sampai tanggal" />
      <div><label class="label-isian" for="br-keg">Kegiatan</label>
        <select id="br-keg" v-model="kegiatan" class="isian"><option value="">Semua kegiatan</option><option v-for="(n, k) in KEGIATAN" :key="k" :value="k">{{ n }}</option></select></div>
      <div class="grid grid-cols-2 gap-2">
        <div><label class="label-isian" for="br-jk">Santri</label>
          <select id="br-jk" v-model="jk" class="isian"><option value="">Semua</option><option value="L">Putra</option><option value="P">Putri</option></select></div>
        <div><label class="label-isian" for="br-min">Minimal</label>
          <select id="br-min" v-model.number="ambang" class="isian"><option v-for="n in [2, 3, 4, 5, 7, 10]" :key="n" :value="n">{{ n }} kali</option></select></div>
      </div>
      <div class="flex flex-wrap gap-2 sm:col-span-2 lg:col-span-4">
        <button v-for="n in [7, 30, 90]" :key="n" class="tombol-garis min-h-[40px] text-sm" @click="periode(n)">{{ n }} hari terakhir</button>
      </div>
    </div>

    <div class="bilah-tab kecil" role="tablist" aria-label="Kategori">
      <button v-for="(k, kode) in KAT" :key="kode" type="button" role="tab" :aria-selected="kategori === kode" @click="kategori = kode"
        :class="['tab-garis', 'w-' + k.w, kategori === kode && 'aktif']">
        <component :is="k.ikon" :size="18" weight="duotone" /> {{ k.n }} <span class="angka-tab">{{ jumlahKat[kode] }}</span></button>
    </div>

    <div class="flex flex-wrap items-center gap-2">
      <p class="flex min-w-[200px] flex-1 items-start gap-2 text-sm text-teks3"><PhInfo :size="18" class="mt-0.5 shrink-0" />
        {{ tampil.length }} santri {{ KAT[kategori].n.toLowerCase() }} (≥ {{ ambang }} kali){{ KAT[kategori].label && !kegiatan ? `, termasuk ${KAT[kategori].label}` : '' }}.</p>
      <button class="tombol-garis min-h-[40px] text-sm" :disabled="!tampil.length" @click="pratinjau = true"><PhPrinter :size="18" weight="duotone" /> Cetak</button>
      <button class="tombol-garis min-h-[40px] text-sm" :disabled="!tampil.length" @click="ekspor"><PhFileXls :size="18" weight="duotone" /> Excel</button>
    </div>

    <p v-if="memuat" class="kartu py-10 text-center text-sm text-teks3">Menghitung…</p>
    <ul v-else class="grid gap-2 lg:grid-cols-2">
      <li v-for="(r, i) in tampil" :key="r.id">
        <button type="button" :class="['kartu flex w-full items-center gap-3 p-3 text-left hover:shadow-apung', 'w-' + KAT[kategori].w]" @click="buka(r)">
          <span class="chip-ikon h-11 w-11 shrink-0 text-lg font-extrabold tabular-nums">{{ r.n }}</span>
          <span class="min-w-0 flex-1">
            <b class="block truncate">{{ i + 1 }}. {{ r.s.nama_lengkap }}</b>
            <span class="block truncate text-xs text-teks3">{{ r.s.nis }} · {{ r.s.jenis_kelamin }} · Kelas {{ r.kelas }} · {{ r.kamar }}</span>
            <span class="block truncate text-xs text-teks2">{{ rinci(r, kategori) }}</span>
            <span v-if="kategori === 'sakit' && r.keluhan" class="block truncate text-xs text-teks3">Keluhan: {{ r.keluhan }}</span>
          </span>
          <PhCaretRight :size="18" class="shrink-0 text-teks3" />
        </button>
      </li>
      <li v-if="!tampil.length" class="kartu py-10 text-center text-sm text-teks3 lg:col-span-2">Tidak ada santri {{ KAT[kategori].n.toLowerCase() }} minimal {{ ambang }} kali pada periode ini.</li>
    </ul>

    <LembarBawah v-model="lembar" :judul="pilih ? pilih.s.nama_lengkap : ''">
      <div v-if="pilih" class="space-y-3 pb-2">
        <p class="text-sm text-teks2">{{ pilih.s.nis }} · Kelas {{ pilih.kelas }} · {{ pilih.kamar }} · {{ formatPendek(mulai) }}–{{ formatPendek(selesai) }}</p>
        <div class="grid grid-cols-3 gap-2 text-center text-sm sm:grid-cols-6">
          <div v-for="(n, k) in { Sakit: hitung(pilih, 'S', ''), Izin: hitung(pilih, 'I', ''), Alfa: hitung(pilih, 'A', ''), Bolos: hitung(pilih, 'B', ''), Terlambat: hitung(pilih, 'T', ''), Klinik: pilih.klinik || 0 }" :key="k"
            class="rounded-xl bg-permukaan2 p-2"><b class="block text-lg tabular-nums">{{ n }}</b><span class="text-xs text-teks3">{{ k }}</span></div>
        </div>
        <p v-if="pilih.klinik" class="rounded-xl bg-permukaan2 p-3 text-sm">Klinik: {{ pilih.klinik }} kasus{{ pilih.klinik_terakhir ? `, terakhir ${formatPendek(pilih.klinik_terakhir)}` : '' }}{{ pilih.keluhan ? ` · ${pilih.keluhan}` : '' }}</p>
        <h3 class="judul-bagian">Riwayat {{ KAT[kategori].n.replace('Sering ', '').toLowerCase() }}</h3>
        <p v-if="memuatR" class="text-sm text-teks3">Memuat…</p>
        <ul v-else class="divide-y divide-garis rounded-xl border border-garis">
          <li v-for="(x, j) in riwayatTampil" :key="j" class="flex flex-wrap gap-x-2 px-3 py-2 text-sm"><b class="w-24 tabular-nums">{{ formatPendek(x.tanggal) }}</b>
            <span class="flex-1">{{ KEGIATAN[x.jenis] || x.jenis }} · {{ x.kelompok }} · {{ x.nama_sesi }}</span><span class="lencana">{{ KODE_N[x.kode] }}</span>
            <span v-if="x.keterangan" class="w-full text-xs text-teks3">{{ x.keterangan }}</span></li>
          <li v-if="!riwayatTampil.length" class="px-3 py-3 text-sm text-teks3">Tidak ada catatan absensi untuk kategori ini (bisa berasal dari klinik, izin pondok, atau pelajaran).</li>
        </ul>
        <router-link :to="`/santri/${pilih.id}`" class="tombol-garis w-full"><PhUser :size="18" /> Buka profil santri</router-link>
      </div>
    </LembarBawah>

    <DokumenCetak v-model:pratinjau="pratinjau" mendatar kop="pondok" :judul="judulCetak" :subjudul="subjudul" :pencetak="sesi.pengguna?.nama_lengkap">
      <table class="tabel kecil">
        <colgroup><col style="width:3%"><col style="width:7%"><col style="width:17%"><col style="width:3%"><col style="width:6%"><col style="width:10%"><col v-for="n in 6" :key="n" style="width:5%"><col style="width:24%"></colgroup>
        <thead><tr><th>No.</th><th>NIS</th><th>Nama</th><th>L/P</th><th>Kelas</th><th>Kamar</th><th>Sakit</th><th>Izin</th><th>Alfa</th><th>Bolos</th><th>Terlambat</th><th>Klinik</th><th>Rincian</th></tr></thead>
        <tbody><tr v-for="(r, i) in tampil" :key="r.id"><td class="tengah">{{ i + 1 }}</td><td>{{ r.s.nis }}</td><td>{{ r.s.nama_lengkap }}</td><td class="tengah">{{ r.s.jenis_kelamin }}</td>
          <td class="tengah">{{ r.kelas }}</td><td>{{ r.kamar }}</td><td class="tengah">{{ hitung(r, 'S') }}</td><td class="tengah">{{ hitung(r, 'I') }}</td><td class="tengah">{{ hitung(r, 'A') }}</td>
          <td class="tengah">{{ hitung(r, 'B') }}</td><td class="tengah">{{ hitung(r, 'T') }}</td><td class="tengah">{{ r.klinik || 0 }}</td><td>{{ rinci(r, kategori) }}</td></tr></tbody>
      </table>
      <p style="margin-top: 4pt; font-size: 8.5pt">Angka = jumlah sesi tidak hadir menurut kode absensi (kelas, halaqah, asrama, ekskul, pelajaran). Klinik = kasus klinik; rincian menurut kategori {{ KAT[kategori].n.toLowerCase() }}.</p>
      <template #ttd><TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: 'Kepala Bidang Kesantrian', nama: '' }" :kanan="{ jabatan: 'Pembuat laporan', nama: sesi.pengguna?.nama_lengkap || '' }" /></template>
    </DokumenCetak>
  </div>
</template>
