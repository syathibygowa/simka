<!-- SIMKA PRO | src/pages/kelompoksantri/CetakAbsensiKelompok.vue | v1.0 | Perbaikan: cetak absensi manual kelompok santri | 13/10/2026 -->
<script setup>
// Cetak lembar absensi manual satu kelompok santri (F4), untuk cadangan saat absensi tidak dapat diisi di aplikasi.
//   Harian : kolom mengikuti kegiatan kelompok pada tanggal itu — kelas per jam pelajaran (JP, beserta mapel terjadwal),
//            halaqah per waktu setoran (pola Muhaffizh, mis. subuh/sore/malam), asrama per waktu absensi (pola Musyrif),
//            ekskul/kelompok lain satu kolom kehadiran.
//   Pekanan: 6 kolom hari (Senin–Sabtu) dengan tanggal dikosongkan untuk ditulis tangan.
// Kolom: No, NIS, Nama, L/P, kehadiran, keterangan. Kode: H hadir, T terlambat, S sakit, I izin, A tanpa keterangan.
// Tanda tangan: Mengetahui (pimpinan bidang) kiri, pengasuh kelompok kanan. Dipakai di daftar dan halaman kelompok.
import { ref, computed } from 'vue'
import { PhPrinter, PhCalendarBlank, PhCalendar } from '@phosphor-icons/vue'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { useKelompokSantri } from '@/stores/kelompokSantri'
import { useSantri } from '@/stores/santri'
import { useJadwal } from '@/stores/jadwal'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { judulKelompok, penandaKelompok, JENIS_KELOMPOK, JENJANG_PENDEK } from '@/lib/santri'
import { HARI, hariIniISO, formatPanjang, formatHari } from '@/lib/tanggal'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const kel = useKelompokSantri(); const san = useSantri(); const jd = useJadwal(); const sesi = useSesi(); const ui = useUI()
const g = ref(null); const lembar = ref(false); const mode = ref('harian'); const tanggal = ref(hariIniISO()); const proses = ref(false)
const pratinjau = ref(false); const kolom = ref([]); const anggota = ref([]); const penanda = ref({ jabatan: '', nama: '', niy: '' }); const tglKolom = ref(null)

function buka(x, m = null) { g.value = x; mode.value = m || 'harian'; tanggal.value = hariIniISO(); lembar.value = true }
defineExpose({ buka })

const SESI_DEMO = { halaqah: [['SUBUH', 'Halaqah subuh', '05:00'], ['SORE', 'Halaqah sore', '15:30'], ['MALAM', 'Halaqah malam', '18:30']], asrama: [['PAGI', 'Asrama pagi', '05:30'], ['MALAM', 'Asrama malam', '21:00']] }
const tambahHari = (iso, n) => { const d = new Date(`${iso}T12:00:00+08:00`); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10) }
const hariKe = (iso) => new Date(`${iso}T12:00:00+08:00`).getUTCDay()

/** Waktu halaqah/asrama untuk tanggal; bila hari libur, ambil pola hari kerja berikutnya (maks. 7 hari). */
async function sesiPola(jenis) {
  if (MODE_DEMO) return { tgl: tanggal.value, daftar: SESI_DEMO[jenis].map(([k, n, j]) => ({ k, n, sub: j })) }
  for (let i = 0; i < 7; i++) {
    const t = tambahHari(tanggal.value, i)
    const { data, error } = await supabase.rpc('sesi_santri_tanggal', { p_jenis: jenis, p_tanggal: t })
    if (error) throw new Error(error.message)
    if (data?.length) return { tgl: t, daftar: data.sort((a, b) => a.urutan - b.urutan).map((s) => ({ k: s.kode, n: s.nama, sub: (s.jam_mulai || '').slice(0, 5) })) }
  }
  return { tgl: tanggal.value, daftar: [] }
}
/** Jam pelajaran kelas pada tanggal (Jumat memakai jam khusus bila ada), beserta mapel terjadwal. */
async function sesiKelas() {
  await jd.muat()
  let t = tanggal.value; let h = hariKe(t); if (h === 0) { t = tambahHari(t, 1); h = 1 }
  const jenisHari = h === 5 && jd.jam.some((p) => p.jenjang === g.value.jenjang && p.jenis_hari === 'jumat') ? 'jumat' : 'reguler'
  const jp = jd.jam.filter((p) => p.jenjang === g.value.jenjang && p.jenis === 'jp' && (p.jenis_hari || 'reguler') === jenisHari).sort((a, b) => a.urutan - b.urutan)
  const mapelDi = (p) => { const j = jd.jadwal.find((x) => x.group_id === g.value.id && Number(x.hari) === h && x.period_id === p.id); const tg = j && jd.penugasan.find((x) => x.id === j.assignment_id)
    const m = tg && jd.mapel.find((x) => x.id === tg.subject_id); return m?.kode || m?.nama || '' }
  return { tgl: t, daftar: jp.map((p, i) => ({ k: p.id, n: `JP ${i + 1}`, sub: `${p.jam_mulai}${mapelDi(p) ? ' · ' + mapelDi(p) : ''}` })) }
}

async function siapkan() {
  proses.value = true
  try {
    await san.muat(); await kel.muatAnggota(g.value.id)
    anggota.value = (kel.anggota[g.value.id]?.aktif || []).map((a) => san.cari(a.student_id)).filter(Boolean).sort((a, b) => a.nama_lengkap.localeCompare(b.nama_lengkap, 'id'))
    if (mode.value === 'pekanan') { kolom.value = [1, 2, 3, 4, 5, 6].map((i) => ({ k: i, n: '', sub: '' })); tglKolom.value = null }
    else {
      const j = g.value.jenis
      const r = j === 'kelas' ? await sesiKelas() : j === 'halaqah' ? await sesiPola('halaqah') : j === 'kamar' ? await sesiPola('asrama') : { tgl: tanggal.value, daftar: [{ k: 'H', n: 'Kehadiran', sub: '' }] }
      if (!r.daftar.length) r.daftar = [{ k: 'H', n: 'Kehadiran', sub: '' }]
      kolom.value = r.daftar; tglKolom.value = r.tgl
      if (r.tgl !== tanggal.value) ui.toast(`Tanggal ${formatPanjang(tanggal.value)} libur untuk kegiatan ini; kolom memakai jadwal ${formatHari(r.tgl)}.`)
    }
    penanda.value = await penandaKelompok(g.value).catch(() => penanda.value)
    lembar.value = false; pratinjau.value = true
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}

const pengasuh = computed(() => (g.value?.pengasuh || []).find((p) => p.peran === 'utama' && p.berlaku !== false) || (g.value?.pengasuh || [])[0] || null)
const kop = computed(() => (g.value?.jenis === 'kelas' ? (g.value.jenjang === 'sma' ? 'sma' : 'wustha') : 'pondok'))
const mendatar = computed(() => kolom.value.length > 6)
const lebarKolom = computed(() => { const sisa = (mendatar.value ? 62 : 52) - 0; return `${Math.max(4, sisa / Math.max(1, kolom.value.length))}%` })
const subjudul = computed(() => {
  if (!g.value) return ''
  const dasar = `${JENIS_KELOMPOK[g.value.jenis]?.n || ''}${g.value.jenis === 'kelas' ? ' ' + (JENJANG_PENDEK[g.value.jenjang] || '') : ''} · ${anggota.value.length} santri`
  return mode.value === 'pekanan' ? `${dasar} · Pekan: ........................ s.d. ........................` : `${dasar} · ${formatHari(tglKolom.value || tanggal.value)}`
})
const NAMA_HARI_PEKAN = HARI.slice(1)
</script>
<template>
  <LembarBawah v-model="lembar" :judul="g ? `Cetak absensi · ${judulKelompok(g)}` : ''">
    <div v-if="g" class="space-y-3 pb-2">
      <div class="grid grid-cols-2 gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" aria-label="Jenis lembar absensi">
        <button v-for="m in [{ k: 'harian', n: 'Harian', i: PhCalendarBlank }, { k: 'pekanan', n: 'Pekanan (6 hari)', i: PhCalendar }]" :key="m.k" type="button" role="radio" :aria-checked="mode === m.k" @click="mode = m.k"
          :class="['flex min-h-[44px] items-center justify-center gap-1.5 rounded-xl text-sm font-semibold', mode === m.k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']"><component :is="m.i" :size="18" /> {{ m.n }}</button>
      </div>
      <InputTanggal v-if="mode === 'harian'" v-model="tanggal" label="Tanggal absensi" />
      <p class="text-xs text-teks3">
        <template v-if="mode === 'harian'">Kolom mengikuti kegiatan {{ JENIS_KELOMPOK[g.jenis]?.n.toLowerCase() }}:
          {{ g.jenis === 'kelas' ? 'per jam pelajaran (JP) beserta mapel terjadwal' : g.jenis === 'halaqah' ? 'per waktu halaqah' : g.jenis === 'kamar' ? 'per waktu absensi asrama' : 'satu kolom kehadiran' }}.</template>
        <template v-else>Enam kolom hari (Senin–Sabtu); tanggal ditulis sendiri.</template>
      </p>
      <button class="tombol-utama w-full" :disabled="proses" @click="siapkan"><PhPrinter :size="20" weight="duotone" /> {{ proses ? 'Menyiapkan…' : 'Pratinjau dan cetak' }}</button>
    </div>
  </LembarBawah>

  <DokumenCetak v-if="g" :kop="kop" :judul="`Daftar Hadir ${judulKelompok(g)}`" :subjudul="subjudul" v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap" :mendatar="mendatar">
    <table class="tabel kecil">
      <colgroup><col style="width:4%"><col style="width:9%"><col :style="{ width: mendatar ? '20%' : '27%' }"><col style="width:4%"><col v-for="c in kolom" :key="c.k" :style="{ width: lebarKolom }"><col style="width:9%"></colgroup>
      <thead>
        <tr><th rowspan="2">No.</th><th rowspan="2">NIS</th><th rowspan="2">Nama Santri</th><th rowspan="2">L/P</th>
          <th :colspan="kolom.length">{{ mode === 'pekanan' ? 'Hari / Tanggal' : 'Kehadiran' }}</th><th rowspan="2">Ket.</th></tr>
        <tr><th v-for="(c, i) in kolom" :key="c.k" style="font-weight: 700">
          <template v-if="mode === 'pekanan'">{{ NAMA_HARI_PEKAN[i] }}<br><span style="font-weight: 400">..../..../....</span></template>
          <template v-else>{{ c.n }}<template v-if="c.sub"><br><span style="font-weight: 400">{{ c.sub }}</span></template></template></th></tr>
      </thead>
      <tbody>
        <tr v-for="(s, i) in anggota" :key="s.id" style="height: 7mm"><td class="tengah">{{ i + 1 }}</td><td>{{ s.nis }}</td><td>{{ s.nama_lengkap }}</td><td class="tengah">{{ s.jenis_kelamin }}</td>
          <td v-for="c in kolom" :key="c.k" /><td /></tr>
        <tr v-if="!anggota.length"><td :colspan="kolom.length + 5" class="tengah">Kelompok belum beranggota.</td></tr>
      </tbody>
    </table>
    <p style="margin-top: 4pt; font-size: 8.5pt">Kode: H = hadir, T = terlambat, S = sakit, I = izin, A = tanpa keterangan, B = bolos. Jumlah hadir: ........ · sakit: ........ · izin: ........ · tanpa keterangan: ........</p>
    <template #ttd>
      <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: penanda.jabatan || 'Pimpinan', nama: penanda.nama, niy: penanda.niy }"
        :kanan="{ jabatan: JENIS_KELOMPOK[g.jenis]?.pengasuh || 'Pengasuh', nama: pengasuh?.nama || '', niy: pengasuh?.niy }"
        :tanggal="mode === 'harian' ? tglKolom || tanggal : undefined" />
    </template>
  </DokumenCetak>
</template>
