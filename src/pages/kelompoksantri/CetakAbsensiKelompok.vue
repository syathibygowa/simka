<!-- SIMKA PRO | src/pages/kelompoksantri/CetakAbsensiKelompok.vue | v2.0 | Perbaikan: tanggal manual, kolom "Jam Ke", asrama 7 hari, daftar hadir tanda tangan | 14/10/2026 -->
<script setup>
// Cetak lembar absensi manual satu kelompok santri (F4), untuk cadangan saat absensi tidak dapat diisi di aplikasi.
// Hari/tanggal selalu dikosongkan untuk ditulis tangan.
//   Harian  : kelas → "Kehadiran Jam Ke" 1, 2, 3, … sebanyak jam pelajaran (JP) kelas itu;
//             halaqah per waktu halaqah dan kamar per waktu absensi asrama (tanpa jam); ekskul/lainnya satu kolom.
//   Pekanan : kamar/asrama 7 kolom hari (Senin–Ahad); kelompok lain 6 kolom (Senin–Sabtu).
//   Tanda tangan: daftar hadir tunggal (No, NIS/NISN, Nama, L/P, Tanda Tangan bersilang, Ket.) untuk kegiatan apa pun.
// Tanda tangan dokumen: Mengetahui (kepala bidang sesuai jenis kelompok) kiri, pengasuh kelompok kanan.
import { ref, computed } from 'vue'
import { PhPrinter, PhCalendarBlank, PhCalendar, PhSignature } from '@phosphor-icons/vue'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { useKelompokSantri } from '@/stores/kelompokSantri'
import { useSantri } from '@/stores/santri'
import { useJadwal } from '@/stores/jadwal'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { judulKelompok, penandaKelompok, JENIS_KELOMPOK, JENJANG_PENDEK } from '@/lib/santri'
import { HARI, hariIniISO } from '@/lib/tanggal'
import LembarBawah from '@/components/LembarBawah.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const kel = useKelompokSantri(); const san = useSantri(); const jd = useJadwal(); const sesi = useSesi(); const ui = useUI()
const g = ref(null); const lembar = ref(false); const mode = ref('harian'); const proses = ref(false)
const pratinjau = ref(false); const kolom = ref([]); const anggota = ref([]); const penanda = ref({ jabatan: '', nama: '', niy: '' })
const kegiatan = ref('')

function buka(x, m = null) { g.value = x; mode.value = m || 'harian'; lembar.value = true }
defineExpose({ buka })

const MODE = [{ k: 'harian', n: 'Harian', i: PhCalendarBlank }, { k: 'pekanan', n: 'Pekanan', i: PhCalendar }, { k: 'ttd', n: 'Tanda tangan', i: PhSignature }]
const SESI_DEMO = { halaqah: ['Halaqah subuh', 'Halaqah sore', 'Halaqah malam'], asrama: ['Asrama pagi', 'Asrama malam'] }
const tambahHari = (iso, n) => { const d = new Date(`${iso}T12:00:00+08:00`); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10) }
const asrama = computed(() => g.value?.jenis === 'kamar')
const HARI_PEKAN = computed(() => (asrama.value ? [...HARI.slice(1), HARI[0]] : HARI.slice(1)))

/** Nama waktu halaqah/asrama (tanpa jam) dari pola hari kerja terdekat. */
async function waktuPola(jenis) {
  if (MODE_DEMO) return SESI_DEMO[jenis]
  for (let i = 0; i < 7; i++) {
    const { data, error } = await supabase.rpc('sesi_santri_tanggal', { p_jenis: jenis, p_tanggal: tambahHari(hariIniISO(), i) })
    if (error) throw new Error(error.message)
    if (data?.length) return data.sort((a, b) => a.urutan - b.urutan).map((s) => s.nama)
  }
  return []
}
/** Banyak jam pelajaran kelas: terbanyak antara JP hari reguler jenjangnya dan JP terjadwal kelas itu dalam sehari. */
async function banyakJp() {
  await jd.muat()
  const reguler = jd.jam.filter((p) => p.jenjang === g.value.jenjang && p.jenis === 'jp' && (p.jenis_hari || 'reguler') === 'reguler').length
  const tugas = new Set(jd.penugasan.filter((t) => t.group_id === g.value.id).map((t) => t.id))
  const perHari = {}
  for (const j of jd.jadwal) if (j.group_id === g.value.id || tugas.has(j.assignment_id)) perHari[j.hari] = (perHari[j.hari] || 0) + 1
  return Math.max(reguler, ...Object.values(perHari), 0) || 8
}

async function siapkan() {
  proses.value = true
  try {
    await san.muat(); await kel.muatAnggota(g.value.id)
    anggota.value = (kel.anggota[g.value.id]?.aktif || []).map((a) => san.cari(a.student_id)).filter(Boolean).sort((a, b) => a.nama_lengkap.localeCompare(b.nama_lengkap, 'id'))
    const j = g.value.jenis
    if (mode.value === 'pekanan') kolom.value = HARI_PEKAN.value.map((h) => ({ k: h, n: h }))
    else if (mode.value === 'harian') {
      let daftar = []
      if (j === 'kelas') daftar = Array.from({ length: await banyakJp() }, (_, i) => String(i + 1))
      else if (j === 'halaqah') daftar = await waktuPola('halaqah')
      else if (j === 'kamar') daftar = await waktuPola('asrama')
      kolom.value = (daftar.length ? daftar : ['Kehadiran']).map((n) => ({ k: n, n }))
    } else kolom.value = []
    penanda.value = await penandaKelompok(g.value).catch(() => penanda.value)
    lembar.value = false; pratinjau.value = true
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}

const pengasuh = computed(() => (g.value?.pengasuh || []).find((p) => p.peran === 'utama' && p.berlaku !== false) || (g.value?.pengasuh || [])[0] || null)
const kop = computed(() => (g.value?.jenis === 'kelas' ? (g.value.jenjang === 'sma' ? 'sma' : 'wustha') : 'pondok'))
const mendatar = computed(() => mode.value !== 'ttd' && kolom.value.length > 8)
const lebarKolom = computed(() => `${Math.max(3.5, (mendatar.value ? 62 : 52) / Math.max(1, kolom.value.length))}%`)
const judulKolom = computed(() => (mode.value === 'pekanan' ? 'Hari / Tanggal' : g.value?.jenis === 'kelas' ? 'Kehadiran Jam Ke' : 'Kehadiran'))
const subjudul = computed(() => {
  if (!g.value) return ''
  const dasar = `${JENIS_KELOMPOK[g.value.jenis]?.n || ''}${g.value.jenis === 'kelas' ? ' ' + (JENJANG_PENDEK[g.value.jenjang] || '') : ''} · ${anggota.value.length} santri`
  if (mode.value === 'pekanan') return `${dasar} · Pekan: ........................ s.d. ........................`
  if (mode.value === 'ttd') return `${dasar} · Kegiatan: ${kegiatan.value.trim() || '..................................................'} · Hari/tanggal: ........................................`
  return `${dasar} · Hari/tanggal: ........................................`
})
const judulDok = computed(() => (g.value ? `${mode.value === 'ttd' ? 'Daftar Hadir dan Tanda Tangan' : 'Daftar Hadir'} ${judulKelompok(g.value)}` : ''))
const KET = { harian: (j) => (j === 'kelas' ? 'Kolom "Kehadiran Jam Ke" 1, 2, 3, … sebanyak jam pelajaran kelas ini.' : j === 'halaqah' ? 'Satu kolom untuk setiap waktu halaqah.' : j === 'kamar' ? 'Satu kolom untuk setiap waktu absensi asrama.' : 'Satu kolom kehadiran.'),
  pekanan: (j) => (j === 'kamar' ? 'Tujuh kolom hari (Senin–Ahad).' : 'Enam kolom hari (Senin–Sabtu).'), ttd: () => 'Kolom tanda tangan bersilang (ganjil di kiri, genap di kanan).' }
</script>
<template>
  <LembarBawah v-model="lembar" :judul="g ? `Cetak absensi · ${judulKelompok(g)}` : ''">
    <div v-if="g" class="space-y-3 pb-2">
      <div class="grid grid-cols-3 gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" aria-label="Jenis lembar absensi">
        <button v-for="m in MODE" :key="m.k" type="button" role="radio" :aria-checked="mode === m.k" @click="mode = m.k"
          :class="['flex min-h-[44px] items-center justify-center gap-1.5 rounded-xl px-1 text-sm font-semibold', mode === m.k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']"><component :is="m.i" :size="18" /> {{ m.n }}</button>
      </div>
      <div v-if="mode === 'ttd'"><label class="label-isian" for="abs-keg">Nama kegiatan (boleh dikosongkan)</label>
        <input id="abs-keg" v-model="kegiatan" class="isian" placeholder="Contoh: Pembagian rapor, Ujian tahfizh" /></div>
      <p class="text-sm text-teks2">{{ KET[mode](g.jenis) }} Hari dan tanggal dikosongkan untuk ditulis tangan.</p>
      <button class="tombol-utama w-full" :disabled="proses" @click="siapkan"><PhPrinter :size="20" weight="duotone" /> {{ proses ? 'Menyiapkan…' : 'Pratinjau dan cetak' }}</button>
    </div>
  </LembarBawah>

  <DokumenCetak v-if="g" :kop="kop" :judul="judulDok" :subjudul="subjudul" v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap" :mendatar="mendatar">
    <!-- Daftar hadir tanda tangan (tunggal) -->
    <table v-if="mode === 'ttd'" class="tabel kecil">
      <colgroup><col style="width:5%"><col style="width:21%"><col style="width:30%"><col style="width:5%"><col style="width:28%"><col style="width:11%"></colgroup>
      <thead><tr><th>No.</th><th>NIS/NISN</th><th>Nama Santri</th><th>L/P</th><th>Tanda Tangan</th><th>Ket.</th></tr></thead>
      <tbody>
        <tr v-for="(s, i) in anggota" :key="s.id" style="height: 9mm"><td class="tengah">{{ i + 1 }}</td><td>{{ s.nis || '–' }}<template v-if="s.nisn"> / {{ s.nisn }}</template></td>
          <td>{{ s.nama_lengkap }}</td><td class="tengah">{{ s.jenis_kelamin }}</td>
          <td style="vertical-align: top; text-align: left; font-size: 8pt"><div :style="{ marginLeft: i % 2 ? '50%' : '0' }">{{ i + 1 }}.</div></td><td /></tr>
        <tr v-if="!anggota.length"><td colspan="6" class="tengah">Kelompok belum beranggota.</td></tr>
      </tbody>
    </table>
    <!-- Absensi harian/pekanan -->
    <table v-else class="tabel kecil">
      <colgroup><col style="width:4%"><col style="width:9%"><col :style="{ width: mendatar ? '20%' : '27%' }"><col style="width:4%"><col v-for="c in kolom" :key="c.k" :style="{ width: lebarKolom }"><col style="width:9%"></colgroup>
      <thead>
        <tr><th rowspan="2">No.</th><th rowspan="2">NIS</th><th rowspan="2">Nama Santri</th><th rowspan="2">L/P</th>
          <th :colspan="kolom.length">{{ judulKolom }}</th><th rowspan="2">Ket.</th></tr>
        <tr><th v-for="c in kolom" :key="c.k">{{ c.n }}<template v-if="mode === 'pekanan'"><br><span style="font-weight: 400">..../..../....</span></template></th></tr>
      </thead>
      <tbody>
        <tr v-for="(s, i) in anggota" :key="s.id" style="height: 7mm"><td class="tengah">{{ i + 1 }}</td><td>{{ s.nis }}</td><td>{{ s.nama_lengkap }}</td><td class="tengah">{{ s.jenis_kelamin }}</td>
          <td v-for="c in kolom" :key="c.k" /><td /></tr>
        <tr v-if="!anggota.length"><td :colspan="kolom.length + 5" class="tengah">Kelompok belum beranggota.</td></tr>
      </tbody>
    </table>
    <p v-if="mode !== 'ttd'" style="margin-top: 4pt; font-size: 8.5pt">Kode: H = hadir, T = terlambat, S = sakit, I = izin, A = tanpa keterangan, B = bolos. Jumlah hadir: ........ · sakit: ........ · izin: ........ · tanpa keterangan: ........</p>
    <p v-else style="margin-top: 4pt; font-size: 8.5pt">Jumlah hadir: ........ santri · tidak hadir: ........ santri.</p>
    <template #ttd>
      <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: penanda.jabatan || 'Pimpinan', nama: penanda.nama, niy: penanda.niy }"
        :kanan="{ jabatan: JENIS_KELOMPOK[g.jenis]?.pengasuh || 'Pengasuh', nama: pengasuh?.nama || '', niy: pengasuh?.niy }" tanggal-manual />
    </template>
  </DokumenCetak>
</template>
