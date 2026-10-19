<!-- SIMKA PRO | src/pages/tahfizh/TabUtas.vue | v1.5 | 14.15.0: penanda tangan dan kop dari Setelan → Penanda tangan | 19/10/2026 -->
<script setup>
// Ujian Tahfizh Akhir Semester (UTAS), di Tahfizh → Ujian → UTAS (SOP UTAS pondok).
//   Panitia (admin/superadmin/pengatur rapor tahfizh): menetapkan penguji per kelas, membagi peserta otomatis (bergilir,
//   penguji dengan peserta paling sedikit lebih dulu), memindahkan peserta antarpenguji, membuka kembali nilai final.
//   Penguji: mengisi juz diujikan (terisi otomatis: N juz resmi terakhir; SMA 5, Wustha 3), Tajwid dan Itqan → nilai akhir,
//   predikat (sebutan Arab/Indonesia sesuai Ketentuan), Tuntas bila ≥ KKM; lalu Kirim (final).
//   Cetak: pembagian penguji dan peserta, daftar hasil UTAS per kelas/halaqah (F4).
// v1.2: nilai final/periode ditutup → penguji mengajukan permintaan ubah nilai (Tajwid/Itqan) kepada panitia; kunci batas pengisian.
// v1.1: pembagian per KELAS atau per HALAQAH (dipilih panitia per semester). Per halaqah: muhaffizh menguji halaqah lain;
//       muhaffizh tidak dapat ditetapkan sebagai penguji halaqahnya sendiri.
import { ref, computed, onMounted, watch } from 'vue'
import {
  PhUsersThree, PhShuffle, PhUserSwitch, PhPaperPlaneTilt, PhFloppyDisk, PhLockSimpleOpen, PhPrinter, PhMagnifyingGlass, PhPlus, PhX, PhCheckCircle,
  PhListChecks, PhHourglass, PhSealCheck, PhInfo, PhPencilSimple, PhTrash, PhPencilLine,
} from '@phosphor-icons/vue'
import { useUtas } from '@/stores/utas'
import { usePegawai } from '@/stores/pegawai'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { predikatDari, sebutanPredikat, JENIS_RAPOR, statusEfektif } from '@/lib/penilaian'
import { useUbahNilai } from '@/stores/ubahNilai'
import { LABEL_SEMESTER } from '@/lib/nilai'
import { ringkasJuz, penandaTahfizh } from '@/lib/tahfizh'
import { JENJANG_PENDEK } from '@/lib/santri'
import { formatPanjang, hariIniISO } from '@/lib/tanggal'
import LembarBawah from '@/components/LembarBawah.vue'
import GridJuz from '@/components/GridJuz.vue'
import KartuStatistik from '@/components/KartuStatistik.vue'
import SaringCorong from '@/components/SaringCorong.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const ut = useUtas(); const peg = usePegawai(); const sesi = useSesi(); const ui = useUI()
const semester = ref(null); const galat = ref(''); const proses = ref('')
async function muat(s) { galat.value = ''; try { await ut.muat(s); semester.value = ut.semester; salin() } catch (e) { galat.value = e.message } }
onMounted(() => muat(ut.semester))
const D = computed(() => ut.data)
const panitia = computed(() => !!D.value?.hak?.panitia)
const ket = computed(() => D.value?.ketentuan || {})
const predikat = computed(() => D.value?.predikat || [])
const sebut = (n) => sebutanPredikat(predikatDari(n, predikat.value), ket.value.bahasa)
const tutup = computed(() => statusEfektif(D.value?.periode) === 'ditutup')
const mode = computed(() => D.value?.mode || 'kelas')
const LBL = computed(() => (mode.value === 'halaqah' ? 'Halaqah' : 'Kelas'))
const namaK = (k) => (mode.value === 'halaqah' ? k.nama : `Kelas ${k.nama}`)
const MODE = [{ k: 'kelas', n: 'Per kelas' }, { k: 'halaqah', n: 'Per halaqah' }]
async function gantiMode(m) {
  if (m === mode.value) return
  if (D.value.peserta.length && !(await ui.konfirmasi({ judul: `Bagi UTAS ${m === 'halaqah' ? 'per halaqah' : 'per kelas'}?`,
    pesan: `Penguji ditetapkan per ${m === 'halaqah' ? 'halaqah' : 'kelas'}. Peserta yang belum dinilai berpindah ke ${m === 'halaqah' ? 'halaqah' : 'kelas'}nya saat Anda menekan Bagi peserta; yang sudah dinilai tetap.`, ya: 'Ganti pembagian' }))) return
  proses.value = 'mode'
  try { await ut.aturMode(m); salin(); ui.toast(`Pembagian UTAS ${LABEL_SEMESTER[semester.value].toLowerCase()} kini ${m === 'halaqah' ? 'per halaqah' : 'per kelas'}.`) } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = '' }
}

// ---------- Saringan ----------
const lihat = ref('saya'); const kelasPilih = ref(''); const cari = ref('')
watch(D, (d) => { if (d && lihat.value === 'saya' && !d.peserta.some((p) => p.saya)) lihat.value = 'semua' }, { immediate: true })
const peserta = computed(() => { const q = cari.value.toLowerCase().trim()
  return (D.value?.peserta || []).filter((p) => (lihat.value !== 'saya' || p.saya) && (!kelasPilih.value || p.group_id === kelasPilih.value)
    && (!q || `${p.nama} ${p.nis} ${p.kelas || ''} ${p.halaqah || ''} ${p.penguji || ''}`.toLowerCase().includes(q))) })
const perKelas = computed(() => { const g = []; for (const p of peserta.value) { let x = g.find((y) => y.id === p.group_id); if (!x) { x = { id: p.group_id, nama: p.jenis_kelompok === 'halaqah' ? p.kelompok : `Kelas ${p.kelompok || p.kelas || '–'}`, item: [] }; g.push(x) } x.item.push(p) } return g })
const statistik = computed(() => { const d = D.value?.peserta || []; const mine = lihat.value === 'saya' ? d.filter((p) => p.saya) : d
  return [
    { judul: 'Peserta', nilai: mine.length, ikon: PhUsersThree, warna: 'santri', keterangan: lihat.value === 'saya' ? 'Yang Anda uji' : `Semua ${LBL.value.toLowerCase()}` },
    { judul: 'Sudah dinilai', nilai: mine.filter((p) => p.nilai_akhir != null).length, ikon: PhListChecks, warna: 'agenda', keterangan: 'Tajwid dan Itqan terisi' },
    { judul: 'Final', nilai: mine.filter((p) => p.status === 'final').length, ikon: PhSealCheck, warna: 'presensi', keterangan: 'Sudah dikirim penguji' },
    { judul: `Di bawah KKM ${Number(ket.value.kkm || 0)}`, nilai: mine.filter((p) => p.nilai_akhir != null && !p.tuntas).length, ikon: PhHourglass, warna: 'klinik', keterangan: 'Remedial' },
  ] })

// ---------- Isian nilai (salinan lokal) ----------
const isi = ref({}); const ubah = ref(new Set())
function salin() { isi.value = Object.fromEntries((D.value?.peserta || []).map((p) => [p.id, { tajwid: p.tajwid ?? '', itqan: p.itqan ?? '', catatan: p.catatan || '', juz: [...(p.juz || [])] }])); ubah.value = new Set() }
watch(() => ut.data, salin)
const bolehIsi = (p) => !!D.value && (panitia.value || (p.saya && p.status === 'draf' && !tutup.value))
function set(p, f, v) { isi.value[p.id][f] = v; ubah.value = new Set([...ubah.value, p.id]) }
const akhir = (p) => { const x = isi.value[p.id]; if (!x || x.tajwid === '' || x.itqan === '') return null
  return Math.round(((Number(x.tajwid) * Number(ket.value.bobot_tajwid || 50) + Number(x.itqan) * Number(ket.value.bobot_itqan || 50)) / 100) * 100) / 100 }
async function simpan(kirim = false, daftar = null) {
  const target = daftar || [...ubah.value].map((id) => D.value.peserta.find((p) => p.id === id)).filter(Boolean)
  for (const p of target) for (const f of ['tajwid', 'itqan']) { const v = isi.value[p.id][f]; if (v !== '' && !(Number(v) >= 0 && Number(v) <= 100)) return ui.toast(`Nilai ${p.nama} harus 0–100.`, 'galat') }
  if (kirim) {
    const kosong = target.filter((p) => isi.value[p.id].tajwid === '' || isi.value[p.id].itqan === '')
    if (kosong.length) return ui.toast(`${kosong.length} peserta belum lengkap Tajwid/Itqan-nya.`, 'galat')
    if (!(await ui.konfirmasi({ judul: `Kirim ${target.length} nilai UTAS?`, pesan: 'Setelah dikirim (final), nilai hanya dapat diubah melalui panitia UTAS.', ya: 'Kirim nilai' }))) return
  }
  proses.value = kirim ? 'kirim' : 'simpan'
  try {
    await ut.simpanNilai(target.map((p) => ({ id: p.id, juz: isi.value[p.id].juz, tajwid: isi.value[p.id].tajwid === '' ? '' : Number(isi.value[p.id].tajwid),
      itqan: isi.value[p.id].itqan === '' ? '' : Number(isi.value[p.id].itqan), catatan: isi.value[p.id].catatan })), kirim)
    salin(); ui.toast(kirim ? 'Nilai UTAS dikirim.' : 'Nilai UTAS disimpan.')
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = '' }
}
const siapKirim = computed(() => (D.value?.peserta || []).filter((p) => p.saya && p.status === 'draf'))
// Juz diujikan
const lembarJuz = ref(false); const pjuz = ref(null); const juzPilih = ref([])
function bukaJuz(p) { pjuz.value = p; juzPilih.value = [...isi.value[p.id].juz]; lembarJuz.value = true }
function terapJuz() { set(pjuz.value, 'juz', [...juzPilih.value].sort((a, b) => a - b)); lembarJuz.value = false }
function pakaiUsul() { juzPilih.value = [...(pjuz.value.juz_usul || [])] }
// Catatan penguji
const lembarCat = ref(false); const pcat = ref(null); const catTeks = ref('')
function bukaCat(p) { pcat.value = p; catTeks.value = isi.value[p.id].catatan; lembarCat.value = true }
function terapCat() { set(pcat.value, 'catatan', catTeks.value.trim()); lembarCat.value = false }

// ---------- Permintaan ubah nilai (penguji, nilai final atau periode ditutup) ----------
const un = useUbahNilai(); const lembarUbah = ref(false); const pUbah = ref(null); const fUbah = ref({ tajwid: '', itqan: '', alasan: '' })
const bolehAjukan = (p) => p.saya && !panitia.value && (p.status === 'final' || tutup.value) && p.nilai_akhir != null
function bukaUbah(p) { pUbah.value = p; fUbah.value = { tajwid: p.tajwid ?? '', itqan: p.itqan ?? '', alasan: '' }; lembarUbah.value = true }
async function kirimUbah() {
  const p = pUbah.value; const f = fUbah.value
  if (f.alasan.trim().length < 5) return ui.toast('Alasan perubahan wajib diisi (minimal 5 huruf).', 'galat')
  const isi = { jenis: 'utas', utas_result_id: p.id, alasan: f.alasan.trim() }
  for (const k of ['tajwid', 'itqan']) { if (!(Number(f[k]) >= 0 && Number(f[k]) <= 100) || f[k] === '') return ui.toast('Nilai harus 0–100.', 'galat'); if (Number(f[k]) !== Number(p[k])) isi[k] = Number(f[k]) }
  if (!('tajwid' in isi) && !('itqan' in isi)) return ui.toast('Tidak ada nilai yang berubah.', 'galat')
  proses.value = 'ubah'
  try { await un.ajukan(isi, { lama: { tajwid: p.tajwid, itqan: p.itqan }, nis: p.nis, nama: p.nama, jenis_kelamin: p.jenis_kelamin, kelas: p.kelas }); lembarUbah.value = false; ui.toast('Permintaan ubah nilai dikirim ke panitia UTAS.') }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = '' }
}

// ---------- Panitia ----------
const lembarPenguji = ref(false); const kelasAtur = ref(null); const pengujiPilih = ref([]); const cariPeg = ref('')
async function bukaPenguji(k) { kelasAtur.value = k; pengujiPilih.value = k.penguji.map((x) => ({ id: x.employee_id, nama: x.nama })); cariPeg.value = ''; lembarPenguji.value = true
  if (!peg.daftar.length) try { await peg.muat() } catch { /* daftar pegawai tidak tersedia */ } }
const calon = computed(() => { const q = cariPeg.value.toLowerCase().trim(); const ada = new Set(pengujiPilih.value.map((x) => x.id))
  return peg.daftar.filter((p) => p.status_keaktifan === 'aktif' && !ada.has(p.id) && (!q || `${p.nama_lengkap} ${p.niy || ''}`.toLowerCase().includes(q))).slice(0, 25) })
async function simpanPenguji() {
  proses.value = 'penguji'
  try { await ut.simpanPenguji(kelasAtur.value.group_id, pengujiPilih.value.map((x) => x.id)); lembarPenguji.value = false; salin(); ui.toast(`Penguji ${namaK(kelasAtur.value)} disimpan.`) }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = '' }
}
async function bagi(k, ulang = false) {
  if (!k.penguji.length) return ui.toast(`Tetapkan penguji ${namaK(k)} lebih dulu.`, 'galat')
  if (ulang && !(await ui.konfirmasi({ judul: `Bagi ulang ${namaK(k)}?`, pesan: `Peserta yang belum dinilai dibagi ulang di antara penguji ${LBL.value.toLowerCase()} ini.`, ya: 'Bagi ulang' }))) return
  proses.value = 'bagi'
  try { const n = await ut.bagi(k.group_id, ulang); salin(); ui.toast(`${n} peserta ${namaK(k)} dibagikan ke penguji.`) } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = '' }
}
const pilih = ref(new Set())
const togglePilih = (id) => { const s = new Set(pilih.value); s.has(id) ? s.delete(id) : s.add(id); pilih.value = s }
const lembarPindah = ref(false); const pindahKe = ref('')
const pengujiKelas = computed(() => { const g = new Set(peserta.value.filter((p) => pilih.value.has(p.id)).map((p) => p.group_id))
  const m = new Map(); for (const k of D.value?.kelas || []) if (g.has(k.group_id)) for (const x of k.penguji) m.set(x.employee_id, x.nama); return [...m].map(([id, nama]) => ({ id, nama })) })
async function pindah() {
  proses.value = 'pindah'
  try { await ut.pindah([...pilih.value], pindahKe.value || null); pilih.value = new Set(); lembarPindah.value = false; salin(); ui.toast('Penguji peserta dipindahkan.') }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = '' }
}
async function bukaFinal() {
  const ids = peserta.value.filter((p) => pilih.value.has(p.id) && p.status === 'final').map((p) => p.id)
  if (!ids.length) return ui.toast('Pilih peserta berstatus final.', 'galat')
  try { await ut.buka(ids); pilih.value = new Set(); salin(); ui.toast(`${ids.length} nilai dibuka kembali untuk penguji.`) } catch (e) { ui.toast(e.message, 'galat') }
}
async function hapusPeserta() {
  const ids = [...pilih.value]
  if (!(await ui.konfirmasi({ judul: `Keluarkan ${ids.length} peserta?`, pesan: 'Hanya peserta yang belum bernilai yang dikeluarkan dari UTAS semester ini.', ya: 'Keluarkan', bahaya: true }))) return
  try { await ut.hapus(ids); pilih.value = new Set(); salin(); ui.toast('Peserta dikeluarkan.') } catch (e) { ui.toast(e.message, 'galat') }
}

// ---------- Cetak ----------
const cetakJenis = ref(''); const pratinjau = ref(false); const kepala = ref({ jabatan: 'Kepala Bidang Tahfizh', nama: '', niy: '' })
async function cetak(j) { cetakJenis.value = j; try { kepala.value = await penandaTahfizh() } catch { /* penanda tangan bawaan */ } pratinjau.value = true }
// Peserta yang sudah dinilai sebelum pembagian diganti tetap pada kelompok lamanya: ikut dicetak sebagai kelompok tersendiri
const kelasCetak = computed(() => {
  const ps = D.value?.peserta || []; const ada = new Set((D.value?.kelas || []).map((k) => k.group_id)); const lain = new Map()
  for (const p of ps) if (!ada.has(p.group_id) && !lain.has(p.group_id)) {
    const pj = [...new Map(ps.filter((x) => x.group_id === p.group_id && x.penguji_id).map((x) => [x.penguji_id, { employee_id: x.penguji_id, nama: x.penguji }])).values()]
    lain.set(p.group_id, { group_id: p.group_id, nama: p.kelompok || p.kelas || '–', jenis: p.jenis_kelompok, penguji: pj })
  }
  return [...(D.value?.kelas || []), ...lain.values()].filter((k) => !kelasPilih.value || k.group_id === kelasPilih.value)
    .map((k) => ({ ...k, peserta: ps.filter((p) => p.group_id === k.group_id) })).filter((k) => k.peserta.length || k.penguji.length)
})
const namaCetak = (k) => (k.jenis === 'halaqah' ? k.nama : `Kelas ${k.nama}`)
</script>
<template>
  <div class="space-y-4">
    <div class="kartu flex flex-wrap items-end gap-3 p-4">
      <div class="bilah-tab kecil" role="tablist" aria-label="Semester">
        <button v-for="s in [1, 2]" :key="s" type="button" role="tab" :aria-selected="semester === s" @click="muat(s)"
          :class="['tab-garis', semester === s && 'aktif']">{{ LABEL_SEMESTER[s] }}</button>
      </div>
      <p class="min-w-[220px] flex-1 text-xs text-teks3">Juz diujikan otomatis: SMA {{ ket.juz_sma || 5 }} juz, Wustha {{ ket.juz_wustha || 3 }} juz (hafalan resmi terakhir; bila kurang, semua hafalan). Nilai akhir = (Tajwid + Itqan) ÷ 2 · KKM {{ Number(ket.kkm || 80) }}.</p>
      <div class="flex gap-2"><button class="tombol-garis min-h-[40px] px-3 text-sm" :disabled="!D" @click="cetak('pembagian')"><PhPrinter :size="18" weight="duotone" /> Pembagian</button>
        <button class="tombol-garis min-h-[40px] px-3 text-sm" :disabled="!D" @click="cetak('hasil')"><PhPrinter :size="18" weight="duotone" /> Hasil</button></div>
    </div>
    <div v-if="galat" class="kartu w-klinik p-5 text-sm font-semibold" style="color: var(--c)">Data UTAS gagal dimuat: {{ galat }} Pastikan migrasi SQL 8400 sudah dijalankan.</div>
    <template v-else-if="D">
      <p v-if="tutup" class="flex items-center gap-2 rounded-2xl bg-permukaan2 p-3 text-sm text-teks2"><PhInfo :size="18" /> Periode penilaian tahfizh semester ini sudah ditutup; nilai hanya dapat diubah panitia.</p>
      <div class="grid grid-cols-2 gap-3 lg:grid-cols-4"><KartuStatistik v-for="s in statistik" :key="s.judul" v-bind="s" /></div>

      <!-- Panitia: kelas dan penguji -->
      <section v-if="panitia" class="kartu w-tahfizh p-4">
        <div class="mb-2 flex flex-wrap items-center gap-2">
          <p class="flex-1 font-bold">{{ LBL }} dan penguji</p>
          <div class="grid grid-cols-2 gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" aria-label="Pembagian penguji">
            <button v-for="m in MODE" :key="m.k" type="button" role="radio" :aria-checked="mode === m.k" :disabled="!!proses" @click="gantiMode(m.k)"
              :class="['min-h-[36px] rounded-xl px-3 text-xs font-semibold', mode === m.k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">{{ m.n }}</button>
          </div>
        </div>
        <p class="mb-3 text-xs text-teks3">Tetapkan penguji tiap {{ LBL.toLowerCase() }} (boleh lebih dari satu), lalu tekan Bagi peserta. Peserta dibagi bergilir; penguji dapat dipindah per santri.<template v-if="mode === 'halaqah'"> Muhaffizh menguji halaqah lain, tidak menguji halaqahnya sendiri.</template></p>
        <ul class="grid gap-2 md:grid-cols-2 xl:grid-cols-3">
          <li v-for="k in D.kelas" :key="k.group_id" class="rounded-xl border border-garis p-3">
            <div class="flex items-center gap-2"><p class="flex-1 font-bold">{{ namaK(k) }} <span class="text-xs font-normal text-teks3">{{ k.jenjang ? JENJANG_PENDEK[k.jenjang] + ' · ' : '' }}{{ k.santri }} santri</span></p>
              <button class="tombol-ikon h-9 w-9" :aria-label="`Atur penguji ${namaK(k)}`" @click="bukaPenguji(k)"><PhPencilSimple :size="16" /></button></div>
            <p v-if="k.muhaffizh" class="text-xs text-teks3">Muhaffizh: {{ k.muhaffizh }}</p>
            <p class="mt-1 text-sm text-teks2">{{ k.penguji.length ? k.penguji.map((x) => x.nama).join(', ') : 'Belum ada penguji' }}</p>
            <div class="mt-2 flex flex-wrap gap-2">
              <button v-if="D.belum_dibagi[k.group_id]" class="tombol-utama min-h-[36px] px-3 text-xs" :disabled="!!proses" @click="bagi(k)"><PhShuffle :size="16" weight="bold" /> Bagi {{ D.belum_dibagi[k.group_id] }} peserta</button>
              <button v-else-if="k.penguji.length" class="tombol-garis min-h-[36px] px-3 text-xs" :disabled="!!proses" @click="bagi(k, true)"><PhShuffle :size="16" /> Bagi ulang</button>
            </div>
          </li>
        </ul>
      </section>

      <!-- Saringan -->
      <div class="flex flex-wrap items-center gap-2">
        <div v-if="D.peserta.some((p) => p.saya) && D.peserta.some((p) => !p.saya)" class="bilah-tab kecil" role="tablist" aria-label="Tampilan">
          <button v-for="t in [{ k: 'saya', n: 'Peserta saya' }, { k: 'semua', n: 'Semua' }]" :key="t.k" type="button" role="tab" :aria-selected="lihat === t.k" @click="lihat = t.k"
            :class="['tab-garis', lihat === t.k && 'aktif']">{{ t.n }}</button>
        </div>
        <SaringCorong class="min-w-[220px] flex-1" :jumlah="kelasPilih ? 1 : 0" :ringkasan="kelasPilih ? namaK(D.kelas.find((k) => k.group_id === kelasPilih) || {}) : ''" judul="Saring peserta UTAS">
          <template #cari><div class="relative"><PhMagnifyingGlass :size="18" class="absolute left-3 top-1/2 -translate-y-1/2 text-teks3" />
            <input v-model="cari" type="search" class="isian pl-10" placeholder="Cari santri, kelas, halaqah, penguji" aria-label="Cari" /></div></template>
          <select v-model="kelasPilih" class="isian w-auto" aria-label="Saring kelompok"><option value="">Semua {{ LBL.toLowerCase() }}</option><option v-for="k in D.kelas" :key="k.group_id" :value="k.group_id">{{ namaK(k) }}</option></select>
        </SaringCorong>
      </div>
      <div v-if="panitia && pilih.size" class="kartu flex flex-wrap items-center gap-2 p-3 text-sm">
        <b class="flex-1">{{ pilih.size }} dipilih</b>
        <button class="tombol-garis min-h-[36px] px-3 text-xs" @click="pindahKe = ''; lembarPindah = true"><PhUserSwitch :size="16" /> Pindah penguji</button>
        <button class="tombol-garis min-h-[36px] px-3 text-xs" @click="bukaFinal"><PhLockSimpleOpen :size="16" /> Buka nilai final</button>
        <button class="tombol-garis min-h-[36px] px-3 text-xs" @click="hapusPeserta"><PhTrash :size="16" /> Keluarkan</button>
        <button class="tombol-ikon h-9 w-9" aria-label="Batalkan pilihan" @click="pilih = new Set()"><PhX :size="16" /></button>
      </div>

      <!-- Peserta per kelas/halaqah -->
      <section v-for="g in perKelas" :key="g.id" class="kartu overflow-hidden">
        <p class="border-b border-garis bg-permukaan2 px-4 py-2 text-sm font-bold">{{ g.nama }} <span class="font-normal text-teks3">· {{ g.item.length }} peserta</span></p>
        <ul class="divide-y divide-garis">
          <li v-for="p in g.item.filter((x) => isi[x.id])" :key="p.id" class="flex flex-wrap items-center gap-x-3 gap-y-2 px-4 py-3">
            <input v-if="panitia" type="checkbox" class="h-5 w-5 accent-[#8C6200]" :checked="pilih.has(p.id)" :aria-label="`Pilih ${p.nama}`" @change="togglePilih(p.id)" />
            <div class="min-w-0 flex-1 basis-[45%]">
              <p class="truncate font-semibold">{{ p.nama }} <span v-if="p.status === 'final'" class="lencana w-presensi"><PhCheckCircle :size="12" weight="bold" /> final</span></p>
              <p class="text-xs text-teks3">{{ p.nis }} · {{ mode === 'halaqah' ? (p.kelas ? 'Kelas ' + p.kelas : 'tanpa kelas') : (p.halaqah || 'tanpa halaqah') }} · hafalan {{ p.total_juz }} juz · penguji: {{ p.penguji || 'belum ada' }}</p>
              <button type="button" class="mt-1 flex items-center gap-1 text-xs font-semibold" :class="bolehIsi(p) ? '' : 'pointer-events-none'" style="color: var(--c)" @click="bukaJuz(p)">
                Juz diujikan: {{ isi[p.id].juz.length ? ringkasJuz(isi[p.id].juz) : 'belum ada' }} ({{ isi[p.id].juz.length }} juz)<PhPencilSimple v-if="bolehIsi(p)" :size="12" /></button>
            </div>
            <div class="flex items-end gap-2">
              <label class="text-center text-[11px] text-teks3">Tajwid<input :value="isi[p.id].tajwid" type="number" min="0" max="100" :disabled="!bolehIsi(p)" :aria-label="`Tajwid ${p.nama}`"
                :class="['mt-0.5 block h-10 w-16 rounded-lg border bg-permukaan text-center text-sm tabular-nums text-teks', ubah.has(p.id) ? 'border-[color:var(--c)]' : 'border-garis']" @change="set(p, 'tajwid', $event.target.value)" /></label>
              <label class="text-center text-[11px] text-teks3">Itqan<input :value="isi[p.id].itqan" type="number" min="0" max="100" :disabled="!bolehIsi(p)" :aria-label="`Itqan ${p.nama}`"
                :class="['mt-0.5 block h-10 w-16 rounded-lg border bg-permukaan text-center text-sm tabular-nums text-teks', ubah.has(p.id) ? 'border-[color:var(--c)]' : 'border-garis']" @change="set(p, 'itqan', $event.target.value)" /></label>
              <div class="w-24 text-center"><p class="text-lg font-extrabold tabular-nums" style="color: var(--c)">{{ akhir(p) ?? '–' }}</p>
                <p v-if="akhir(p) != null" :class="['text-[11px] font-semibold', akhir(p) >= Number(ket.kkm) ? 'text-teks2' : 'text-merah']"><i v-if="ket.bahasa === 'arab'">{{ sebut(akhir(p)) }}</i><template v-else>{{ sebut(akhir(p)) }}</template>{{ akhir(p) >= Number(ket.kkm) ? '' : ' · remedial' }}</p></div>
              <button v-if="bolehAjukan(p)" class="tombol-ikon h-10 w-10" :aria-label="`Ajukan perubahan nilai ${p.nama}`" title="Ajukan perubahan nilai" @click="bukaUbah(p)"><PhPencilLine :size="16" /></button>
              <button v-if="bolehIsi(p)" class="tombol-ikon h-10 w-10" :aria-label="`Catatan ${p.nama}`" :title="isi[p.id].catatan || 'Catatan penguji'" @click="bukaCat(p)"><PhPencilSimple :size="16" :weight="isi[p.id].catatan ? 'fill' : 'regular'" /></button>
            </div>
          </li>
        </ul>
      </section>
      <p v-if="!peserta.length" class="kartu p-6 text-center text-sm text-teks3">{{ panitia ? `Belum ada peserta. Tetapkan penguji lalu tekan Bagi peserta pada setiap ${LBL.toLowerCase()}.` : 'Belum ada peserta UTAS untuk Anda pada semester ini.' }}</p>

      <!-- Bilah simpan/kirim -->
      <div v-if="ubah.size || siapKirim.length" class="sticky bottom-[84px] z-20 lg:bottom-4">
        <div class="kartu mx-auto flex max-w-2xl flex-wrap items-center gap-2 p-3 shadow-xl">
          <p class="flex-1 text-sm font-semibold">{{ ubah.size ? `${ubah.size} perubahan belum disimpan` : `${siapKirim.length} nilai Anda belum dikirim` }}</p>
          <button v-if="ubah.size" class="tombol-garis min-h-[40px] px-3 text-sm" :disabled="!!proses" @click="simpan(false)"><PhFloppyDisk :size="18" weight="duotone" /> {{ proses === 'simpan' ? 'Menyimpan…' : 'Simpan' }}</button>
          <button v-if="siapKirim.length && !tutup" class="tombol-utama min-h-[40px] px-3 text-sm" :disabled="!!proses" @click="simpan(true, siapKirim)"><PhPaperPlaneTilt :size="18" weight="duotone" /> Kirim nilai saya (final)</button>
        </div>
      </div>
    </template>
    <p v-else class="kartu p-6 text-center text-sm text-teks3">Memuat UTAS…</p>

    <!-- Juz diujikan -->
    <LembarBawah v-model="lembarJuz" :judul="pjuz ? `Juz diujikan · ${pjuz.nama}` : ''" lebar>
      <div v-if="pjuz" class="space-y-3 pb-2">
        <p class="text-sm text-teks2">Usulan otomatis: <b>{{ pjuz.juz_usul?.length ? ringkasJuz(pjuz.juz_usul) : 'belum ada hafalan resmi' }}</b> ({{ pjuz.jenjang === 'sma' ? ket.juz_sma : ket.juz_wustha }} juz terakhir untuk {{ JENIS_RAPOR[pjuz.jenjang]?.pendek }}).</p>
        <GridJuz v-model="juzPilih" label="Juz diujikan" label-pilih="Diujikan" />
        <div class="flex gap-2"><button class="tombol-garis" type="button" @click="pakaiUsul">Pakai usulan</button><button class="tombol-utama flex-1" type="button" @click="terapJuz">Terapkan ({{ juzPilih.length }} juz)</button></div>
      </div>
    </LembarBawah>

    <!-- Permintaan ubah nilai -->
    <LembarBawah v-model="lembarUbah" :judul="pUbah ? `Ajukan perubahan nilai · ${pUbah.nama}` : ''">
      <div class="space-y-3 pb-2">
        <p class="text-xs text-teks3">Nilai sudah final{{ tutup ? ' / periode ditutup' : '' }}. Perubahan diajukan kepada panitia UTAS dan berlaku setelah disetujui.</p>
        <div class="grid grid-cols-2 gap-3">
          <div><label class="label-isian" for="uu-t">Tajwid (kini {{ pUbah?.tajwid ?? '–' }})</label><input id="uu-t" v-model="fUbah.tajwid" type="number" min="0" max="100" class="isian tabular-nums" /></div>
          <div><label class="label-isian" for="uu-i">Itqan (kini {{ pUbah?.itqan ?? '–' }})</label><input id="uu-i" v-model="fUbah.itqan" type="number" min="0" max="100" class="isian tabular-nums" /></div>
        </div>
        <div><label class="label-isian" for="uu-a">Alasan perubahan</label><textarea id="uu-a" v-model="fUbah.alasan" rows="2" class="isian" placeholder="Contoh: salah input nilai tajwid" /></div>
        <button class="tombol-utama w-full" :disabled="!!proses" @click="kirimUbah"><PhPaperPlaneTilt :size="20" weight="duotone" /> {{ proses === 'ubah' ? 'Mengirim…' : 'Kirim permintaan' }}</button>
      </div>
    </LembarBawah>

    <!-- Catatan -->
    <LembarBawah v-model="lembarCat" :judul="pcat ? `Catatan penguji · ${pcat.nama}` : ''">
      <div class="space-y-3 pb-2"><textarea v-model="catTeks" rows="3" class="isian" placeholder="Contoh: juz 7 paling tidak lancar" aria-label="Catatan penguji" />
        <button class="tombol-utama w-full" @click="terapCat">Terapkan</button></div>
    </LembarBawah>

    <!-- Penguji kelas/halaqah -->
    <LembarBawah v-model="lembarPenguji" :judul="kelasAtur ? `Penguji UTAS · ${namaK(kelasAtur)}` : ''">
      <div class="space-y-3 pb-2">
        <p v-if="kelasAtur?.muhaffizh" class="text-xs text-teks3">Muhaffizh halaqah ini ({{ kelasAtur.muhaffizh }}) tidak dapat menjadi pengujinya.</p>
        <ul class="flex flex-wrap gap-2"><li v-for="(x, i) in pengujiPilih" :key="x.id" class="lencana py-1 text-sm">{{ x.nama }}<button type="button" class="ml-1" :aria-label="`Lepas ${x.nama}`" @click="pengujiPilih.splice(i, 1)"><PhX :size="12" weight="bold" /></button></li>
          <li v-if="!pengujiPilih.length" class="text-sm text-teks3">Belum ada penguji dipilih.</li></ul>
        <input v-model="cariPeg" type="search" class="isian" placeholder="Cari nama atau NIY pegawai" aria-label="Cari pegawai" />
        <ul class="max-h-[40dvh] divide-y divide-garis overflow-y-auto rounded-xl border border-garis">
          <li v-for="p in calon" :key="p.id"><button type="button" class="flex min-h-[48px] w-full items-center gap-3 px-3 text-left text-sm hover:bg-permukaan2" @click="pengujiPilih.push({ id: p.id, nama: p.nama_lengkap })">
            <span class="min-w-0 flex-1"><b class="block truncate">{{ p.nama_lengkap }}</b><span class="text-xs text-teks3">{{ [p.jabatan_struktural, ...(p.jabatan_fungsional || [])].filter(Boolean).join(', ') || '–' }}</span></span><PhPlus :size="18" class="text-teks3" /></button></li>
        </ul>
        <button class="tombol-utama w-full" :disabled="!!proses" @click="simpanPenguji"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses === 'penguji' ? 'Menyimpan…' : 'Simpan penguji' }}</button>
      </div>
    </LembarBawah>

    <!-- Pindah penguji -->
    <LembarBawah v-model="lembarPindah" :judul="`Pindah penguji · ${pilih.size} peserta`">
      <div class="space-y-3 pb-2">
        <select v-model="pindahKe" class="isian" aria-label="Penguji tujuan"><option value="">Tanpa penguji</option><option v-for="x in pengujiKelas" :key="x.id" :value="x.id">{{ x.nama }}</option></select>
        <p class="text-xs text-teks3">Pilihan berisi penguji {{ LBL.toLowerCase() }} peserta yang dipilih. Tambah penguji {{ LBL.toLowerCase() }} lebih dulu bila perlu.</p>
        <button class="tombol-utama w-full" :disabled="!!proses" @click="pindah"><PhUserSwitch :size="20" weight="duotone" /> Pindahkan</button>
      </div>
    </LembarBawah>

    <!-- Cetak -->
    <DokumenCetak jenis="thz_utas" kop="pondok" :judul="cetakJenis === 'hasil' ? 'Hasil Ujian Tahfizh Akhir Semester (UTAS)' : 'Pembagian Penguji Ujian Tahfizh Akhir Semester (UTAS)'"
      :subjudul="`${LABEL_SEMESTER[semester] || ''} · keadaan ${formatPanjang(hariIniISO())}`" v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap" :mendatar="cetakJenis === 'hasil'">
      <template v-if="cetakJenis === 'pembagian'">
        <table class="tabel"><colgroup><col style="width:7%"><col style="width:17%"><col style="width:25%"><col style="width:51%"></colgroup>
          <thead><tr><th>No.</th><th>{{ LBL }}</th><th>Penguji</th><th>Peserta ujian (juz diujikan)</th></tr></thead>
          <tbody><template v-for="k in kelasCetak" :key="k.group_id">
            <tr v-for="(x, i) in (k.penguji.length ? k.penguji : [{ employee_id: '-', nama: '–' }])" :key="k.group_id + x.employee_id">
              <td class="tengah">{{ kelasCetak.indexOf(k) + 1 }}.{{ i + 1 }}</td><td>{{ namaCetak(k) }}</td><td>{{ x.nama }}</td>
              <td>{{ k.peserta.filter((p) => p.penguji_id === x.employee_id).map((p) => `${p.nama} (${ringkasJuz(p.juz) || '–'})`).join('; ') || '–' }}</td></tr>
          </template></tbody></table>
      </template>
      <template v-else>
        <template v-for="k in kelasCetak" :key="k.group_id">
          <p style="margin: 8pt 0 3pt; font-weight: 700">{{ namaCetak(k) }}</p>
          <table class="tabel"><colgroup><col style="width:4%"><col style="width:8%"><col style="width:21%"><col style="width:7%"><col style="width:13%"><col style="width:16%"><col style="width:6%"><col style="width:6%"><col style="width:6%"><col style="width:13%"></colgroup>
            <thead><tr><th>No.</th><th>NIS</th><th>Nama</th><th>Total hafalan</th><th>Juz diujikan</th><th>Penguji</th><th>Tajwid</th><th>Itqan</th><th>Nilai</th><th>Predikat</th></tr></thead>
            <tbody><tr v-for="(p, i) in k.peserta" :key="p.id"><td class="tengah">{{ i + 1 }}</td><td>{{ p.nis }}</td><td>{{ p.nama }}</td><td class="tengah">{{ p.total_juz }} juz</td>
              <td class="tengah">{{ ringkasJuz(p.juz) || '–' }}</td><td>{{ p.penguji || '–' }}</td><td class="tengah">{{ p.tajwid ?? '' }}</td><td class="tengah">{{ p.itqan ?? '' }}</td>
              <td class="tengah">{{ p.nilai_akhir ?? '' }}</td><td class="tengah"><template v-if="p.nilai_akhir != null"><i v-if="ket.bahasa === 'arab'">{{ sebut(p.nilai_akhir) }}</i><template v-else>{{ sebut(p.nilai_akhir) }}</template>{{ p.tuntas ? '' : ' (Remedial)' }}</template></td></tr></tbody></table>
        </template>
        <p style="margin-top: 4pt; font-size: 9pt">KKM {{ Number(ket.kkm) }}; nilai akhir = (Tajwid + Itqan) ÷ 2. {{ predikat.map((x) => `${x.huruf} ${x.nilai_min}–${x.nilai_maks} ${ket.bahasa === 'arab' && x.sebutan_arab ? x.sebutan_arab : x.sebutan}`).join(' · ') }}</p>
      </template>
      <template #ttd><TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: kepala.jabatan, nama: kepala.nama, niy: kepala.niy }" :kanan="{ jabatan: 'Panitia UTAS', nama: sesi.pengguna?.nama_lengkap || '' }" /></template>
    </DokumenCetak>
  </div>
</template>
