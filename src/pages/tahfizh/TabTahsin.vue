<!-- SIMKA PRO | src/pages/tahfizh/TabTahsin.vue | v1.5 | 14.30.0: saringan bawaan Semua | 29/10/2026 -->
<script setup>
// Tahsin — pembinaan bacaan Al-Qur'an bagi santri yang belum menghafal (umumnya santri baru atau pindahan).
//   Muhaffizh/pengelola: "Tandai santri tahsin" (mulai, asal, tahap awal, pembina).
//   Pembina/muhaffizh: "Catat pertemuan" untuk beberapa santri sekaligus (materi, nilai, naik tahap), lihat riwayat, ajukan lulus.
//   Kepala Bidang Tahfizh/pengelola: luluskan (santri mulai menghafal dan tampil normal di Setoran) atau kembalikan dengan catatan.
// v1.3 (14.21.0): Ujian tahsin — pembina mengajukan ujian; penguji tahsin (bukan pembina/muhaffizh santri) atau Kepala Bidang Tahfizh menilai
//   Makhraj dan Shifat, hasil Lulus/Belum lulus, catatan. Lulus → santri mulai menghafal + Surat Keterangan Hasil Ujian Tahsin (tanda tangan
//   penguji dan Kepala Bidang Tahfizh, diatur di Setelan → Penanda tangan). Bagian "Ujian tahsin" memuat riwayat ujian, cetak suket, dan rekap.
//   WA ke penguji (minta diuji) dan ke penanda tangan suket. Admin/superadmin dapat menghapus data tahsin yang dihentikan.
//   Terpadu: capaian bulanan santri tahsin berstatus "Tahsin"; penanda di Setoran dan Data hafalan; riwayat di Rekam Kesantrian.
import { ref, computed, onMounted, watch } from 'vue'
import { PhUserSound, PhUserPlus, PhNotePencil, PhClockCounterClockwise, PhSealCheck, PhHourglass, PhCalendarBlank, PhTrendUp, PhPrinter, PhWhatsappLogo,
  PhMagnifyingGlass, PhListNumbers, PhPencilSimple, PhPaperPlaneTilt, PhCheckCircle, PhArrowCounterClockwise, PhStop, PhTrash, PhPlus, PhArrowUp, PhArrowDown,
  PhChartBar, PhCaretDown, PhExam, PhFileText, PhCertificate } from '@phosphor-icons/vue'
import { useTahsin } from '@/stores/tahsin'
import { useTahfizh } from '@/stores/tahfizh'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { NILAI_TAHSIN, SUMBER_TAHSIN, STATUS_TAHSIN, HASIL_TAHSIN, KKM_TAHSIN, keadaanTahsin, persenTahsin } from '@/lib/tahsin'
import { penandaTahfizh } from '@/lib/tahfizh'
import { formatPendek, formatPanjang, formatWaktu, hariIniISO } from '@/lib/tanggal'
import { pesanWA, halamanAplikasi } from '@/lib/wa'
import KartuStatistik from '@/components/KartuStatistik.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import TombolWA from '@/components/TombolWA.vue'
import TombolAksi from '@/components/TombolAksi.vue'
import SaringCorong from '@/components/SaringCorong.vue'
import PratinjauWA from '@/components/PratinjauWA.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import CetakDokumenTahfizh from './CetakDokumenTahfizh.vue'

const ts = useTahsin(); const tz = useTahfizh(); const sesi = useSesi(); const ui = useUI()
const semua = ref([]); const calon = ref([]); const memuat = ref(false); const proses = ref(false)
const saring = ref(''); const halaqah = ref(''); const cari = ref('')
async function muat() {
  memuat.value = true
  try {
    if (!ts.pengaturan) await ts.muatPengaturan()
    ;[semua.value, calon.value] = await Promise.all([ts.daftar(null), ts.calon().catch(() => [])])
  } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
onMounted(muat)

const berjalan = computed(() => semua.value.filter((t) => t.status === 'berjalan'))
const daftarHalaqah = computed(() => [...new Set(semua.value.map((t) => t.halaqah || 'Belum masuk halaqah'))].sort((a, b) => a.localeCompare(b, 'id')))
const tampil = computed(() => {
  const q = cari.value.trim().toLowerCase()
  return semua.value.filter((t) => (!saring.value || keadaanTahsin(t) === saring.value || (saring.value === 'berjalan' && t.status === 'berjalan'))
    && (!halaqah.value || (t.halaqah || 'Belum masuk halaqah') === halaqah.value)
    && (!q || t.nama.toLowerCase().includes(q) || String(t.nis).includes(q)))
})
const kelompok = computed(() => {
  const m = new Map(); tampil.value.forEach((t) => { const k = t.halaqah || 'Belum masuk halaqah'; if (!m.has(k)) m.set(k, []); m.get(k).push(t) })
  return [...m.entries()].map(([nama, isi]) => ({ nama, isi }))
})
const tahunIni = (t) => t.selesai && t.selesai.slice(0, 4) === hariIniISO().slice(0, 4)
const statistik = computed(() => {
  const lulus = semua.value.filter((t) => t.status === 'lulus'); const rata = lulus.length ? Math.round(lulus.reduce((n, t) => n + (t.lama_hari || 0), 0) / lulus.length) : null
  return [
    { judul: 'Santri tahsin', nilai: berjalan.value.length, ikon: PhUserSound, warna: 'tahsin', ket: 'Belum menghafal, sedang dibina' },
    { judul: 'Menunggu ujian', nilai: berjalan.value.filter((t) => t.diajukan_lulus_pada).length, ikon: PhHourglass, warna: 'pengajuan', ket: 'Diajukan ujian tahsin' },
    { judul: 'Lulus tahun ini', nilai: lulus.filter(tahunIni).length, ikon: PhSealCheck, warna: 'presensi', ket: 'Sudah mulai menghafal' },
    { judul: 'Rata-rata lama', nilai: rata == null ? '–' : `${rata} hari`, ikon: PhCalendarBlank, warna: 'agenda', ket: 'Dari mulai sampai lulus tahsin' },
  ]
})
// Sebaran santri per tahap (santri berjalan)
const sebaran = computed(() => ts.tahapan.map((t, i) => ({ no: i + 1, nama: t.nama, n: berjalan.value.filter((x) => x.tahap === i + 1).length })))
const maksSebaran = computed(() => Math.max(1, ...sebaran.value.map((s) => s.n)))
const lihatSebaran = ref(true)

// ---------- Tandai santri tahsin ----------
const lembarTandai = ref(false); const pilih = ref([]); const cariCalon = ref(''); const pembina = ref([]); const ft = ref({})
const calonTampil = computed(() => { const q = cariCalon.value.trim().toLowerCase(); return calon.value.filter((s) => !q || s.nama.toLowerCase().includes(q) || String(s.nis).includes(q) || (s.halaqah || '').toLowerCase().includes(q)) })
async function bukaTandai() {
  pilih.value = []; cariCalon.value = ''; ft.value = { mulai: hariIniISO(), sumber: 'santri_baru', tahap: 1, pembina_id: '', catatan: '' }; lembarTandai.value = true
  if (!pembina.value.length) pembina.value = await ts.pembina().catch(() => [])
}
async function simpanTandai() {
  if (!pilih.value.length) return ui.toast('Pilih santri yang masih tahsin.', 'galat')
  proses.value = true
  try { const n = await ts.tandai(pilih.value, { ...ft.value, pembina_id: ft.value.pembina_id || null, catatan: ft.value.catatan.trim() })
    lembarTandai.value = false; ui.toast(`${n} santri ditandai tahsin.`); saring.value = 'berjalan'; await muat() }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}

// ---------- Catat pertemuan (beberapa santri) ----------
const lembarCatat = ref(false); const tglCatat = ref(hariIniISO()); const isian = ref({}); const hqCatat = ref('')
const bolehCatat = computed(() => berjalan.value.filter((t) => t.boleh_bina))
const hqCatatList = computed(() => [...new Set(bolehCatat.value.map((t) => t.halaqah || 'Belum masuk halaqah'))])
const catatTampil = computed(() => bolehCatat.value.filter((t) => !hqCatat.value || (t.halaqah || 'Belum masuk halaqah') === hqCatat.value))
function bukaCatat(t = null) {
  tglCatat.value = hariIniISO(); hqCatat.value = t ? (t.halaqah || 'Belum masuk halaqah') : (halaqah.value || hqCatatList.value[0] || '')
  isian.value = Object.fromEntries(bolehCatat.value.map((x) => [x.id, { nilai: '', materi: '', naik: false, catatan: '' }]))
  lembarCatat.value = true
}
const jumlahIsi = computed(() => Object.values(isian.value).filter((x) => x.nilai).length)
async function simpanCatat() {
  const isi = Object.entries(isian.value).filter(([, x]) => x.nilai).map(([id, x]) => ({ id, nilai: x.nilai, materi: x.materi.trim(), naik: x.naik, catatan: x.catatan.trim() }))
  if (!isi.length) return ui.toast('Pilih nilai bacaan sedikitnya untuk satu santri.', 'galat')
  proses.value = true
  try { const n = await ts.catat(tglCatat.value, isi); lembarCatat.value = false; ui.toast(`Perkembangan tahsin ${n} santri tersimpan.`); await muat() }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}

// ---------- Riwayat ----------
const lembarRiwayat = ref(false); const tr = ref(null); const riwayat = ref([])
async function bukaRiwayat(t) { tr.value = t; riwayat.value = []; lembarRiwayat.value = true; try { riwayat.value = await ts.riwayat(t.id) } catch (e) { ui.toast(e.message, 'galat') } }
async function hapusLog(l) {
  if (!(await ui.konfirmasi({ judul: 'Hapus catatan pertemuan?', pesan: `${formatPanjang(l.tanggal)} · ${l.materi || l.tahap_nama}. Tahap santri dihitung ulang.`, ya: 'Hapus', bahaya: true }))) return
  try { await ts.hapusCatatan(l.id, tr.value.id); riwayat.value = await ts.riwayat(tr.value.id); await muat() } catch (e) { ui.toast(e.message, 'galat') }
}

// ---------- Ubah, ajukan, putuskan, hentikan ----------
const lembarUbah = ref(false); const fu = ref({})
async function bukaUbah(t) { tr.value = t; fu.value = { tahap: t.tahap, pembina_id: t.pembina_id || '', catatan: t.catatan || '' }; lembarUbah.value = true; if (!pembina.value.length) pembina.value = await ts.pembina().catch(() => []) }
async function simpanUbah() {
  proses.value = true
  try { await ts.ubah(tr.value.id, { tahap: Number(fu.value.tahap), pembina_id: fu.value.pembina_id || null, catatan: fu.value.catatan.trim() }); lembarUbah.value = false; ui.toast('Data tahsin diperbarui.'); await muat() }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
const lembarAksi = ref(false); const mode = ref('ajukan'); const catAksi = ref('')
function bukaAksi(t, m) { tr.value = t; mode.value = m; catAksi.value = ''; lembarAksi.value = true }
const JUDUL_AKSI = { ajukan: 'Ajukan ujian tahsin', putus: 'Putuskan lulus tahsin', hentikan: 'Hentikan tahsin' }
async function simpanAksi(lulus = true) {
  proses.value = true
  try {
    if (mode.value === 'ajukan') { await ts.ajukanLulus(tr.value.id, catAksi.value.trim()); ui.toast('Pengajuan ujian tahsin terkirim kepada penguji tahsin dan Kepala Bidang Tahfizh.')
      lembarAksi.value = false; await muat(); const t = semua.value.find((x) => x.id === tr.value.id); if (t) bukaMintaUji(t); return }
    else if (mode.value === 'putus') {
      await ts.putuskan(tr.value.id, lulus, catAksi.value.trim())
      ui.toast(lulus ? `${tr.value.nama} lulus tahsin dan mulai menghafal. Barakallahu fiik.` : 'Pengajuan dikembalikan dengan catatan perbaikan.')
      if (lulus) { lembarAksi.value = false; await muat(); const t = semua.value.find((x) => x.id === tr.value.id); if (t) bukaWA(t, 'lulus'); return }
    } else { await ts.hentikan(tr.value.id, catAksi.value.trim()); ui.toast('Tahsin santri dihentikan.') }
    lembarAksi.value = false; await muat()
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}

// ---------- Tahapan (pengaturan) ----------
const lembarTahap = ref(false); const ftp = ref({ tahapan: [], catatan_lulus: '', kkm_ujian: KKM_TAHSIN })
function bukaTahap() { ftp.value = { tahapan: ts.tahapan.map((t) => ({ nama: t.nama, uraian: t.uraian || '' })), catatan_lulus: ts.pengaturan?.catatan_lulus || '', kkm_ujian: ts.pengaturan?.kkm_ujian ?? KKM_TAHSIN }; lembarTahap.value = true }
function geserTahap(i, d) { const a = ftp.value.tahapan; const j = i + d; if (j < 0 || j >= a.length) return; [a[i], a[j]] = [a[j], a[i]] }
async function simpanTahap() {
  proses.value = true
  try { await ts.simpanPengaturan({ tahapan: ftp.value.tahapan, catatan_lulus: ftp.value.catatan_lulus.trim(), kkm_ujian: Number(ftp.value.kkm_ujian) || KKM_TAHSIN }); lembarTahap.value = false; ui.toast('Tahapan tahsin disimpan.'); await muat() }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}

// ---------- WhatsApp orang tua ----------
const lembarWA = ref(false); const tw = ref(null); const jenisWA = ref('perkembangan')
function bukaWA(t, jenis = null) { tw.value = t; jenisWA.value = jenis || (t.status === 'lulus' ? 'lulus' : 'perkembangan'); lembarWA.value = true }
const teksWA = computed(() => {
  const t = tw.value; if (!t) return ''
  const d = { nama_wali: String(t.wali?.nama || '').replace(/^(bapak|ibu)\s+/i, ''), nama_santri: t.nama, kelas: t.kelas, halaqah: t.halaqah,
    tahap: `${t.tahap}/${t.jumlah_tahap} – ${t.tahap_nama}`, pertemuan: `${t.pertemuan} kali (lancar ${t.lancar} kali)`,
    catatan: t.terakhir ? `${formatPendek(t.terakhir.tanggal)} – ${[t.terakhir.materi, NILAI_TAHSIN[t.terakhir.nilai]?.n, t.terakhir.catatan].filter(Boolean).join(', ')}` : '' }
  return pesanWA(jenisWA.value === 'lulus' ? 'tahsin_lulus_wali' : 'tahsin_perkembangan_wali', d)
})

// ---------- Cetak ----------
const pratinjau = ref(false); const kepala = ref({})
async function cetak() { kepala.value = await penandaTahfizh(); pratinjau.value = true }
const LABEL_SARING = { berjalan: 'Sedang tahsin', menunggu: 'Menunggu ujian', lulus: 'Lulus tahsin', dihentikan: 'Dihentikan' }
const subjudulCetak = computed(() => [LABEL_SARING[saring.value] || 'Semua status', halaqah.value, `keadaan ${formatPanjang(hariIniISO())}`].filter(Boolean).join(' · '))

// ---------- 14.21.0: Ujian tahsin ----------
const bagian = ref('santri')
const kkm = computed(() => Number(ts.pengaturan?.kkm_ujian ?? KKM_TAHSIN))
const lembarUji = ref(false); const fx = ref({}); const hasilDipilih = ref(false)
function bukaUji(t) { tr.value = t; fx.value = { tanggal: hariIniISO(), makhraj: '', shifat: '', hasil: '', catatan: '' }; hasilDipilih.value = false; lembarUji.value = true }
const rataUji = computed(() => { const m = Number(fx.value.makhraj); const sf = Number(fx.value.shifat); return fx.value.makhraj === '' || fx.value.shifat === '' ? null : Math.round(((m + sf) / 2) * 100) / 100 })
watch(rataUji, (r) => { if (!hasilDipilih.value && r != null) fx.value.hasil = r >= kkm.value ? 'lulus' : 'belum_lulus' })
function pilihHasil(h) { fx.value.hasil = h; hasilDipilih.value = true }
async function simpanUji() {
  const f = fx.value
  if (f.makhraj === '' || f.shifat === '') return ui.toast('Isi nilai Makhraj dan Shifat (0–100).', 'galat')
  if (!f.hasil) return ui.toast('Pilih hasil ujian: Lulus atau Belum lulus.', 'galat')
  if (f.hasil === 'belum_lulus' && f.catatan.trim().length < 5) return ui.toast('Tuliskan catatan perbaikan untuk santri yang belum lulus.', 'galat')
  proses.value = true
  try {
    const h = await ts.nilaiUjian(tr.value.id, { tanggal: f.tanggal, makhraj: Number(f.makhraj), shifat: Number(f.shifat), hasil: f.hasil, catatan: f.catatan.trim() })
    lembarUji.value = false
    ui.toast(h.hasil === 'lulus' ? `${tr.value.nama} lulus ujian tahsin (rata-rata ${String(h.nilai).replace('.', ',')}) dan mulai menghafal. Suket hasil ujian terbit.` : `${tr.value.nama} belum lulus; tahsin dilanjutkan dengan catatan perbaikan.`)
    await muat(); if (bagian.value === 'ujian') muatUjian()
    if (h.dokumen?.id) await bukaSuket(h.dokumen.id)
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
// Riwayat ujian (bagian Ujian tahsin)
const awalTA = () => { const h = hariIniISO(); const th = Number(h.slice(0, 4)) - (Number(h.slice(5, 7)) < 7 ? 1 : 0); return `${th}-07-01` }
const ujian = ref([]); const memuatUjian = ref(false); const ujMulai = ref(awalTA()); const ujSelesai = ref(hariIniISO()); const ujHasil = ref('')
async function muatUjian() { memuatUjian.value = true; try { ujian.value = await ts.daftarUjian(ujMulai.value, ujSelesai.value) } catch (e) { ui.toast(e.message, 'galat') } finally { memuatUjian.value = false } }
watch(bagian, (b) => { if (b === 'ujian') muatUjian() })
watch([ujMulai, ujSelesai], () => { if (bagian.value === 'ujian') muatUjian() })
const ujianTampil = computed(() => { const q = cari.value.trim().toLowerCase(); return ujian.value.filter((u) => (!ujHasil.value || u.hasil === ujHasil.value) && (!halaqah.value || (u.halaqah || 'Belum masuk halaqah') === halaqah.value) && (!q || u.nama.toLowerCase().includes(q) || String(u.nis).includes(q))) })
const menungguUji = computed(() => berjalan.value.filter((t) => t.diajukan_lulus_pada))
const angka = (n) => (n == null ? '–' : String(n).replace('.', ','))
// Cetak suket hasil ujian tahsin
const dokSuket = ref(null); const pratinjauSuket = ref(false)
async function bukaSuket(id) {
  if (!id) return ui.toast('Suket belum terbit (hanya untuk hasil Lulus).', 'galat')
  try { const d = (await tz.daftarDokumen({ id }))[0]; if (!d) return ui.toast('Suket tidak ditemukan atau Anda tidak berwenang membukanya.', 'galat'); dokSuket.value = d; pratinjauSuket.value = true } catch (e) { ui.toast(e.message, 'galat') }
}
// WA ke penguji: minta diuji
const lembarMinta = ref(false)
async function bukaMintaUji(t) { tr.value = t; lembarMinta.value = true; if (!tz.penguji.tahsin?.length) await tz.muatPengaturan().catch(() => {}) }
const pengujiTahsin = computed(() => (tz.penguji.tahsin || []).filter((p) => p.aktif && p.nama !== tr.value?.pembina))
const pesanMinta = (p) => pesanWA('tahsin_ujian_minta', { nama: p.nama, nama_santri: tr.value?.nama, kelas: tr.value?.kelas || '–', halaqah: tr.value?.halaqah || '–',
  catatan: tr.value?.catatan_ajuan ? `Catatan pembina: ${tr.value.catatan_ajuan}` : '', tautan: halamanAplikasi('/tahfizh/tahsin'), pengirim: sesi.pengguna?.nama_lengkap })
// Hapus data tahsin yang dihentikan (admin/superadmin)
const dihentikanHapus = computed(() => semua.value.filter((t) => t.boleh_hapus))
async function hapusTahsin(daftar) {
  if (!daftar.length) return
  if (!(await ui.konfirmasi({ judul: daftar.length > 1 ? `Hapus ${daftar.length} data tahsin yang dihentikan?` : 'Hapus data tahsin?', pesan: `${daftar.slice(0, 5).map((t) => t.nama).join(', ')}${daftar.length > 5 ? ', …' : ''}. Riwayat pertemuan dan ujiannya ikut terhapus permanen.`, ya: 'Hapus', bahaya: true }))) return
  try { const n = await tz.hapusUsulan('tahsin', daftar.map((t) => t.id)); ui.toast(`${n} data tahsin dihapus.`); await muat() } catch (e) { ui.toast(e.message, 'galat') }
}
// Cetak rekap ujian tahsin
const pratinjauUjian = ref(false)
async function cetakUjian() { kepala.value = await penandaTahfizh(); pratinjauUjian.value = true }
</script>
<template>
  <div class="w-tahsin">
    <SaringCorong :jumlah="[saring !== 'berjalan', halaqah].filter(Boolean).length" :ringkasan="[LABEL_SARING[saring] || 'Semua', halaqah].filter(Boolean).join(' · ')" judul="Saring santri tahsin">
      <template #cari><div class="relative">
        <PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
        <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari nama atau NIS" aria-label="Cari santri tahsin" />
      </div></template>
      <select v-model="saring" class="isian w-auto" aria-label="Saring status">
        <option value="berjalan">Sedang tahsin</option><option value="menunggu">Menunggu ujian</option><option value="lulus">Lulus tahsin</option><option value="dihentikan">Dihentikan</option><option value="">Semua</option></select>
      <select v-model="halaqah" class="isian w-auto" aria-label="Saring halaqah"><option value="">Semua halaqah</option><option v-for="h in daftarHalaqah" :key="h" :value="h">{{ h }}</option></select>
    </SaringCorong>
    <div class="mt-2 flex flex-wrap items-center gap-2">
      <div class="bilah-tab kecil" role="tablist" aria-label="Bagian tahsin">
        <button v-for="b in [{ k: 'santri', n: 'Santri tahsin', i: PhUserSound, w: 'tahsin' }, { k: 'ujian', n: 'Ujian tahsin', i: PhExam, w: 'agenda' }]" :key="b.k" type="button" role="tab" :aria-selected="bagian === b.k" @click="bagian = b.k"
          :class="['tab-garis', 'w-' + b.w, bagian === b.k && 'aktif']">
          <component :is="b.i" :size="18" weight="duotone" /><span>{{ b.n }}</span><span v-if="b.k === 'ujian' && menungguUji.length" class="lencana-tab">{{ menungguUji.length }}</span></button>
      </div>
      <span class="flex-1" />
      <template v-if="bagian === 'santri'">
        <button v-if="ts.bolehAtur" class="tombol-garis" @click="bukaTahap"><PhListNumbers :size="20" weight="duotone" style="color: var(--c)" /> Tahapan</button>
        <button v-if="saring === 'dihentikan' && dihentikanHapus.length" class="tombol-garis" @click="hapusTahsin(dihentikanHapus)"><PhTrash :size="20" /> Hapus {{ dihentikanHapus.length }} dihentikan</button>
        <button class="tombol-garis w-laporan" :disabled="!tampil.length" @click="cetak"><PhPrinter :size="20" weight="duotone" style="color: var(--c)" /> Cetak</button>
        <button class="tombol-garis" :disabled="!bolehCatat.length" @click="bukaCatat()"><PhNotePencil :size="20" weight="duotone" style="color: var(--c)" /> Catat pertemuan</button>
        <button class="tombol-utama hidden lg:inline-flex" :disabled="!calon.length" @click="bukaTandai"><PhUserPlus :size="20" weight="duotone" /> Tandai santri tahsin</button>
      </template>
      <button v-else class="tombol-garis w-laporan" :disabled="!ujianTampil.length" @click="cetakUjian"><PhPrinter :size="20" weight="duotone" style="color: var(--c)" /> Cetak rekap ujian</button>
    </div>

    <template v-if="bagian === 'santri'">

    <div class="-mx-4 mt-3 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-4 sm:overflow-visible sm:px-0">
      <KartuStatistik v-for="s in statistik" :key="s.judul" class="w-[44%] shrink-0 snap-start sm:w-auto" :judul="s.judul" :nilai="memuat ? '…' : s.nilai" :ikon="s.ikon" :warna="s.warna" :keterangan="s.ket" />
    </div>

    <p class="mt-3 rounded-2xl bg-permukaan2 p-3 text-xs text-teks2">
      Santri tahsin belum menyetor hafalan. Capaian bulanannya berstatus <b>Tahsin</b> (tidak dihitung sebagai target tidak tercapai). Setelah lulus tahsin, santri mulai menghafal dan tampil normal di Setoran.
    </p>

    <!-- Sebaran per tahap -->
    <section v-if="berjalan.length" class="kartu mt-4 p-4">
      <button class="flex w-full items-center gap-2 text-left" :aria-expanded="lihatSebaran" @click="lihatSebaran = !lihatSebaran">
        <PhChartBar :size="20" weight="duotone" style="color: var(--c)" /><h3 class="judul-bagian flex-1">Sebaran santri per tahap</h3><PhCaretDown :size="16" :class="lihatSebaran && 'rotate-180'" /></button>
      <ul v-if="lihatSebaran" class="mt-3 space-y-1.5">
        <li v-for="s in sebaran" :key="s.no" class="grid grid-cols-[1.75rem_minmax(0,1fr)_2rem] items-center gap-2 text-sm sm:grid-cols-[1.75rem_18rem_minmax(0,1fr)_2rem]">
          <span class="chip-ikon h-7 w-7 text-xs font-extrabold">{{ s.no }}</span>
          <span class="truncate text-teks2">{{ s.nama }}</span>
          <span class="hidden h-2.5 overflow-hidden rounded-full bg-garis sm:block"><span class="block h-full rounded-full" :style="`width: ${(s.n / maksSebaran) * 100}%; background: var(--c)`" /></span>
          <b class="text-right tabular-nums">{{ s.n }}</b>
        </li>
      </ul>
    </section>

    <!-- Daftar per halaqah -->
    <section v-for="g in kelompok" :key="g.nama" class="mt-4">
      <h3 class="judul-bagian mb-2 flex items-center gap-2">{{ g.nama }} <span class="lencana w-tahsin">{{ g.isi.length }} santri</span></h3>
      <ul class="grid gap-3 md:grid-cols-2">
        <li v-for="t in g.isi" :key="t.id" :class="['kartu p-4', 'w-' + STATUS_TAHSIN[keadaanTahsin(t)].w]">
          <div class="flex items-start gap-3">
            <span class="chip-ikon h-11 w-11 shrink-0"><PhUserSound :size="24" weight="duotone" /></span>
            <div class="min-w-0 flex-1">
              <p class="flex flex-wrap items-center gap-1.5"><b>{{ t.nama }}</b><span :class="['lencana', 'w-' + STATUS_TAHSIN[keadaanTahsin(t)].w]">{{ STATUS_TAHSIN[keadaanTahsin(t)].n }}</span></p>
              <p class="text-xs text-teks3">{{ t.nis }} · {{ t.jenis_kelamin }} · {{ t.kelas || '–' }} · {{ SUMBER_TAHSIN[t.sumber] }} · mulai {{ formatPendek(t.mulai) }} ({{ t.lama_hari }} hari)</p>
              <!-- Kemajuan tahap -->
              <div class="mt-2">
                <div class="flex items-center justify-between text-xs"><span class="font-semibold">Tahap {{ t.tahap }}/{{ t.jumlah_tahap }} · {{ t.tahap_nama }}</span><span class="tabular-nums text-teks3">{{ persenTahsin(t) }}%</span></div>
                <div class="mt-1 flex gap-0.5" role="img" :aria-label="`Kemajuan tahap ${t.tahap} dari ${t.jumlah_tahap}`">
                  <span v-for="n in t.jumlah_tahap" :key="n" class="h-2 flex-1 rounded-full" :style="n < t.tahap || t.status === 'lulus' ? 'background: var(--c)' : n === t.tahap ? 'background: var(--c); opacity: .4' : ''" :class="n >= t.tahap && t.status !== 'lulus' && n !== t.tahap ? 'bg-garis' : ''" />
                </div>
              </div>
              <p class="mt-2 text-xs text-teks2">Pembina {{ t.pembina || t.muhaffizh || '–' }} · {{ t.pertemuan }} pertemuan<template v-if="t.pertemuan"> · lancar {{ t.lancar }} kali</template></p>
              <p v-if="t.terakhir" class="mt-1 flex flex-wrap items-center gap-1.5 text-xs text-teks2">Terakhir {{ formatPendek(t.terakhir.tanggal) }}: {{ t.terakhir.materi || 'Tahap ' + t.terakhir.tahap }}
                <span :class="['lencana', 'w-' + NILAI_TAHSIN[t.terakhir.nilai].w]">{{ NILAI_TAHSIN[t.terakhir.nilai].n }}</span><span v-if="t.terakhir.catatan" class="text-teks3">· {{ t.terakhir.catatan }}</span></p>
              <p v-if="t.catatan" class="mt-1 text-xs text-teks3">Catatan: {{ t.catatan }}</p>
              <p v-if="t.diajukan_lulus_pada" class="mt-1 text-xs text-teks3">Diajukan lulus {{ formatWaktu(t.diajukan_lulus_pada) }} oleh {{ t.pengaju }}{{ t.catatan_ajuan ? ' · ' + t.catatan_ajuan : '' }}</p>
              <p v-else-if="t.catatan_ajuan" class="mt-1 rounded-xl bg-permukaan2 p-2 text-xs font-semibold">{{ t.catatan_ajuan }}</p>
              <p v-if="t.ujian?.length" class="mt-1 flex flex-wrap items-center gap-1.5 text-xs text-teks2"><PhExam :size="14" /> Ujian {{ formatPendek(t.ujian[0].tanggal) }}: Makhraj {{ angka(t.ujian[0].makhraj) }} · Shifat {{ angka(t.ujian[0].shifat) }}
                <span :class="['lencana', 'w-' + HASIL_TAHSIN[t.ujian[0].hasil].w]">{{ HASIL_TAHSIN[t.ujian[0].hasil].n }}</span><span class="text-teks3">· {{ t.ujian[0].penguji }}</span></p>
              <p v-if="t.status !== 'berjalan'" class="mt-1 text-xs text-teks3">{{ t.status === 'lulus' ? 'Lulus' : 'Dihentikan' }} {{ formatPendek(t.selesai) }}{{ t.pemutus ? ' oleh ' + t.pemutus : '' }}{{ t.catatan_selesai ? ' · ' + t.catatan_selesai : '' }}</p>
              <div class="mt-3 flex flex-wrap gap-2">
                <button v-if="t.boleh_uji && (t.diajukan_lulus_pada || t.boleh_putus)" :class="[t.diajukan_lulus_pada ? 'tombol-utama' : 'tombol-garis', 'min-h-[38px] px-3 text-sm']" @click="bukaUji(t)"><PhExam :size="18" weight="duotone" /> Nilai ujian</button>
                <button v-if="t.diajukan_lulus_pada && t.boleh_bina" class="tombol-wa-garis w-presensi min-h-[38px] px-3 text-sm" @click="bukaMintaUji(t)"><PhWhatsappLogo :size="18" weight="duotone" /> WA penguji</button>
                <button v-if="t.boleh_bina" class="tombol-garis min-h-[38px] px-3 text-sm" @click="bukaCatat(t)"><PhNotePencil :size="18" /> Catat</button>
                <button class="tombol-garis min-h-[38px] px-3 text-sm" @click="bukaRiwayat(t)"><PhClockCounterClockwise :size="18" /> Riwayat</button>
                <button v-if="t.boleh_bina && !t.diajukan_lulus_pada" class="tombol-garis min-h-[38px] px-3 text-sm" @click="bukaAksi(t, 'ajukan')"><PhPaperPlaneTilt :size="18" /> Ajukan ujian</button>
                <button v-if="t.ujian?.[0]?.dokumen_id" class="tombol-garis w-tatausaha min-h-[38px] px-3 text-sm" @click="bukaSuket(t.ujian[0].dokumen_id)"><PhFileText :size="18" weight="duotone" style="color: var(--c)" /> Suket</button>
                <button v-if="t.boleh_hapus" class="tombol-garis min-h-[38px] px-3 text-sm" @click="hapusTahsin([t])"><PhTrash :size="18" /> Hapus</button>
                <button v-if="t.status !== 'dihentikan'" class="tombol-wa-garis w-presensi min-h-[38px] px-3 text-sm" @click="bukaWA(t)"><PhWhatsappLogo :size="18" weight="duotone" /> WA orang tua</button>
                <button v-if="t.boleh_bina" class="tombol-ikon" title="Ubah tahap, pembina, catatan" aria-label="Ubah data tahsin" @click="bukaUbah(t)"><PhPencilSimple :size="20" /></button>
                <button v-if="t.boleh_bina" class="tombol-ikon" title="Hentikan tahsin" aria-label="Hentikan tahsin" @click="bukaAksi(t, 'hentikan')"><PhStop :size="20" /></button>
              </div>
            </div>
          </div>
        </li>
      </ul>
    </section>
    <div v-if="!tampil.length && !memuat" class="kartu mt-4 flex flex-col items-center gap-2 p-8 text-center text-sm text-teks3">
      <PhUserSound :size="40" weight="duotone" style="color: var(--c)" />
      <p>Belum ada santri pada saringan ini.</p>
      <button v-if="calon.length && saring === 'berjalan'" class="tombol-utama" @click="bukaTandai"><PhUserPlus :size="20" weight="duotone" /> Tandai santri tahsin</button>
    </div>

    </template>

    <!-- ===== 14.21.0: Ujian tahsin ===== -->
    <template v-else>
      <section v-if="menungguUji.length" class="kartu mt-4 p-4">
        <h3 class="judul-bagian mb-2 flex items-center gap-2"><PhHourglass :size="20" weight="duotone" style="color: var(--c)" /> Menunggu ujian <span class="lencana w-pengajuan">{{ menungguUji.length }} santri</span></h3>
        <ul class="divide-y divide-garis">
          <li v-for="t in menungguUji" :key="t.id" class="flex flex-wrap items-center gap-2 py-2.5">
            <span class="min-w-0 flex-1"><b class="block truncate text-sm">{{ t.nama }}</b>
              <span class="block text-xs text-teks3">{{ t.kelas || '–' }} · {{ t.halaqah || '–' }} · muhaffizh {{ t.muhaffizh || t.pembina || '–' }} · diajukan {{ formatPendek(t.diajukan_lulus_pada) }} oleh {{ t.pengaju || '–' }}</span></span>
            <button v-if="t.boleh_uji" class="tombol-utama min-h-[38px] px-3 text-sm" @click="bukaUji(t)"><PhExam :size="18" weight="duotone" /> Nilai ujian</button>
            <button v-if="t.boleh_bina" class="tombol-wa-garis w-presensi min-h-[38px] px-3 text-sm" @click="bukaMintaUji(t)"><PhWhatsappLogo :size="18" weight="duotone" /> WA penguji</button>
          </li>
        </ul>
      </section>
      <div class="kartu mt-4 flex flex-wrap items-end gap-3 p-4">
        <div class="sm:w-44"><InputTanggal class="tanpa-label" v-model="ujMulai" label="Ujian dari" /></div>
        <div class="sm:w-44"><InputTanggal class="tanpa-label" v-model="ujSelesai" label="Sampai" /></div>
        <div><label class="label-isian sr-only" for="uj-hasil">Hasil</label>
          <select id="uj-hasil" v-model="ujHasil" class="isian w-auto"><option value="">Semua hasil</option><option value="lulus">Lulus</option><option value="belum_lulus">Belum lulus</option></select></div>
      </div>
      <p v-if="memuatUjian" class="py-8 text-center text-sm text-teks3">Memuat ujian tahsin…</p>
      <ul v-else-if="ujianTampil.length" class="mt-4 grid gap-3 md:grid-cols-2">
        <li v-for="u in ujianTampil" :key="u.id" :class="['kartu p-4', 'w-' + HASIL_TAHSIN[u.hasil].w]">
          <div class="flex items-start gap-3">
            <span class="chip-ikon h-11 w-11 shrink-0"><PhExam :size="24" weight="duotone" /></span>
            <div class="min-w-0 flex-1">
              <p class="flex flex-wrap items-center gap-1.5"><b>{{ u.nama }}</b><span :class="['lencana', 'w-' + HASIL_TAHSIN[u.hasil].w]">{{ HASIL_TAHSIN[u.hasil].n }}</span></p>
              <p class="text-xs text-teks3">{{ u.nis }} · {{ u.kelas || '–' }} · {{ u.halaqah || '–' }} · muhaffizh {{ u.muhaffizh || '–' }}</p>
              <div class="mt-2 grid grid-cols-3 gap-2 text-center">
                <div class="rounded-xl bg-permukaan2 p-2"><p class="text-lg font-extrabold tabular-nums">{{ angka(u.makhraj) }}</p><p class="text-[11px] text-teks3">Makhraj</p></div>
                <div class="rounded-xl bg-permukaan2 p-2"><p class="text-lg font-extrabold tabular-nums">{{ angka(u.shifat) }}</p><p class="text-[11px] text-teks3">Shifat</p></div>
                <div class="rounded-xl bg-permukaan2 p-2"><p class="text-lg font-extrabold tabular-nums">{{ angka(u.nilai) }}</p><p class="text-[11px] text-teks3">Rata-rata</p></div>
              </div>
              <p class="mt-2 text-xs text-teks2">{{ formatPanjang(u.tanggal) }} · penguji {{ u.penguji || '–' }}</p>
              <p v-if="u.catatan" class="text-xs text-teks3">Catatan: {{ u.catatan }}</p>
              <p v-if="u.nomor" class="text-xs text-teks3">Suket {{ u.nomor }}</p>
              <div class="mt-3 flex flex-wrap gap-2">
                <button v-if="u.dokumen_id" class="tombol-garis w-tatausaha min-h-[38px] px-3 text-sm" @click="bukaSuket(u.dokumen_id)"><PhFileText :size="18" weight="duotone" style="color: var(--c)" /> Cetak suket</button>
                <TombolWA v-if="u.wali?.no_hp" kecil :hp="u.wali.no_hp" :pesan="pesanWA(u.hasil === 'lulus' ? 'tahsin_lulus_wali' : 'tahsin_perkembangan_wali', { nama_wali: String(u.wali?.nama || '').replace(/^(bapak|ibu)\s+/i, ''), nama_santri: u.nama, kelas: u.kelas, halaqah: u.halaqah, tahap: 'ujian tahsin', pertemuan: '–', catatan: `Ujian ${formatPendek(u.tanggal)}: Makhraj ${angka(u.makhraj)}, Shifat ${angka(u.shifat)}${u.catatan ? ' – ' + u.catatan : ''}` })" label="WA orang tua" />
              </div>
            </div>
          </div>
        </li>
      </ul>
      <div v-else class="kartu mt-4 flex flex-col items-center gap-2 p-8 text-center text-sm text-teks3">
        <PhExam :size="40" weight="duotone" style="color: var(--c)" />
        <p>Belum ada ujian tahsin pada periode ini. Pembina mengajukan ujian dari kartu santri tahsin (Ajukan ujian).</p>
      </div>
    </template>

    <!-- Tombol aksi mengambang (HP) -->
    <TombolAksi v-if="bagian === 'santri' && calon.length" label="Tandai tahsin" :ikon="PhUserPlus" warna="tahsin" @klik="bukaTandai" />

    <!-- Tandai -->
    <LembarBawah v-model="lembarTandai" judul="Tandai santri tahsin" lebar>
      <div class="space-y-3 pb-2">
        <p class="text-xs text-teks2">Pilih santri yang belum menghafal karena masih memperbaiki bacaan. Santri baru (masuk ≤ 6 bulan) dan hafalan paling sedikit ditampilkan lebih dulu.</p>
        <div class="relative"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
          <input v-model="cariCalon" type="search" class="isian pl-11" placeholder="Cari nama, NIS, atau halaqah" aria-label="Cari calon santri tahsin" /></div>
        <ul class="max-h-64 divide-y divide-garis overflow-y-auto rounded-2xl border border-garis">
          <li v-for="s in calonTampil" :key="s.student_id">
            <label class="flex min-h-[48px] cursor-pointer items-center gap-3 px-3 py-2">
              <input v-model="pilih" type="checkbox" :value="s.student_id" class="h-5 w-5 accent-[var(--c)]" />
              <span class="min-w-0 flex-1"><span class="block truncate text-sm font-semibold">{{ s.nama }}</span>
                <span class="block text-xs text-teks3">{{ s.nis }} · {{ s.kelas || '–' }} · {{ s.halaqah || 'belum masuk halaqah' }} · hafalan {{ s.total_resmi }} juz resmi</span></span>
              <span v-if="s.baru" class="lencana w-santri">Baru</span><span v-if="s.jalur_masuk === 'pindahan'" class="lencana w-jadwal">Pindahan</span><span v-if="s.pernah_tahsin" class="lencana w-hakakses">Pernah tahsin</span>
            </label>
          </li>
          <li v-if="!calonTampil.length" class="p-4 text-center text-sm text-teks3">Tidak ada santri yang cocok.</li>
        </ul>
        <p class="text-xs font-semibold">{{ pilih.length }} santri dipilih</p>
        <div class="grid gap-3 sm:grid-cols-2">
          <InputTanggal v-model="ft.mulai" label="Mulai tahsin" wajib />
          <div><label class="label-isian" for="ts-sumber">Asal santri</label>
            <select id="ts-sumber" v-model="ft.sumber" class="isian"><option v-for="(n, k) in SUMBER_TAHSIN" :key="k" :value="k">{{ n }}</option></select></div>
          <div><label class="label-isian" for="ts-tahap">Tahap awal</label>
            <select id="ts-tahap" v-model.number="ft.tahap" class="isian"><option v-for="(t, i) in ts.tahapan" :key="i" :value="i + 1">{{ i + 1 }}. {{ t.nama }}</option></select></div>
          <div><label class="label-isian" for="ts-pembina">Pembina tahsin</label>
            <select id="ts-pembina" v-model="ft.pembina_id" class="isian"><option value="">Muhaffizh halaqah santri</option><option v-for="p in pembina" :key="p.id" :value="p.id">{{ p.nama }}</option></select></div>
        </div>
        <div><label class="label-isian" for="ts-cat">Catatan awal bacaan</label><input id="ts-cat" v-model="ft.catatan" class="isian" placeholder="Contoh: makhraj huruf halqi belum tepat" /></div>
        <button class="tombol-utama w-full" :disabled="proses || !pilih.length" @click="simpanTandai"><PhUserPlus :size="20" weight="duotone" /> Tandai {{ pilih.length || '' }} santri</button>
      </div>
    </LembarBawah>

    <!-- Catat pertemuan -->
    <LembarBawah v-model="lembarCatat" judul="Catat pertemuan tahsin" lebar>
      <div class="space-y-3 pb-2">
        <div class="grid gap-3 sm:grid-cols-2">
          <InputTanggal v-model="tglCatat" label="Tanggal pertemuan" wajib />
          <div><label class="label-isian" for="tc-hq">Halaqah</label>
            <select id="tc-hq" v-model="hqCatat" class="isian"><option value="">Semua santri binaan</option><option v-for="h in hqCatatList" :key="h" :value="h">{{ h }}</option></select></div>
        </div>
        <p class="text-xs text-teks2">Isi nilai bacaan santri yang hadir; santri tanpa nilai tidak dicatat. Centang <b>Naik tahap</b> bila tahap yang dipelajari sudah tuntas (hanya untuk nilai Lancar).</p>
        <ul class="divide-y divide-garis">
          <li v-for="t in catatTampil" :key="t.id" class="py-3">
            <div class="flex items-center gap-2">
              <span class="min-w-0 flex-1"><b class="block truncate text-sm">{{ t.nama }}</b><span class="block text-xs text-teks3">Tahap {{ t.tahap }}/{{ t.jumlah_tahap }} · {{ t.tahap_nama }}</span></span>
            </div>
            <div class="mt-2 grid grid-cols-3 gap-1 rounded-xl bg-permukaan2 p-1" role="radiogroup" :aria-label="`Nilai bacaan ${t.nama}`">
              <button v-for="(v, k) in NILAI_TAHSIN" :key="k" type="button" role="radio" :aria-checked="isian[t.id].nilai === k" @click="isian[t.id].nilai = isian[t.id].nilai === k ? '' : k"
                :class="['min-h-[38px] rounded-lg px-2 text-xs font-bold', 'w-' + v.w, isian[t.id].nilai === k ? 'text-white shadow-kartu' : 'text-teks3']" :style="isian[t.id].nilai === k ? 'background: var(--c)' : ''">{{ v.n }}</button>
            </div>
            <div v-if="isian[t.id].nilai" class="mt-2 grid gap-2 sm:grid-cols-[1fr_1fr_auto]">
              <input v-model="isian[t.id].materi" class="isian min-h-[40px] text-sm" placeholder="Materi, mis. izhar halqi" :aria-label="`Materi ${t.nama}`" />
              <input v-model="isian[t.id].catatan" class="isian min-h-[40px] text-sm" placeholder="Catatan (opsional)" :aria-label="`Catatan ${t.nama}`" />
              <label :class="['flex min-h-[40px] items-center gap-2 rounded-xl px-3 text-sm font-semibold', isian[t.id].nilai === 'lancar' ? 'bg-permukaan2' : 'opacity-50']">
                <input v-model="isian[t.id].naik" type="checkbox" class="h-5 w-5 accent-[var(--c)]" :disabled="isian[t.id].nilai !== 'lancar' || t.tahap >= t.jumlah_tahap" /> Naik tahap</label>
            </div>
          </li>
          <li v-if="!catatTampil.length" class="py-4 text-center text-sm text-teks3">Tidak ada santri binaan pada halaqah ini.</li>
        </ul>
        <button class="tombol-utama w-full" :disabled="proses || !jumlahIsi" @click="simpanCatat"><PhNotePencil :size="20" weight="duotone" /> Simpan {{ jumlahIsi || '' }} catatan</button>
      </div>
    </LembarBawah>

    <!-- Riwayat -->
    <LembarBawah v-model="lembarRiwayat" :judul="tr ? `Riwayat tahsin · ${tr.nama}` : ''">
      <div v-if="tr" class="space-y-3 pb-2">
        <p class="text-sm text-teks2">Mulai {{ formatPanjang(tr.mulai) }} · {{ SUMBER_TAHSIN[tr.sumber] }} · tahap {{ tr.tahap }}/{{ tr.jumlah_tahap }} ({{ tr.tahap_nama }})</p>
        <ol class="relative space-y-3 border-l-2 border-garis pl-4">
          <li v-for="l in riwayat" :key="l.id" class="relative">
            <span class="absolute -left-[1.42rem] top-1 h-3 w-3 rounded-full" :class="'w-' + NILAI_TAHSIN[l.nilai].w" style="background: var(--c)" />
            <p class="flex flex-wrap items-center gap-1.5 text-sm"><b>{{ formatPanjang(l.tanggal) }}</b><span :class="['lencana', 'w-' + NILAI_TAHSIN[l.nilai].w]">{{ NILAI_TAHSIN[l.nilai].n }}</span>
              <span v-if="l.naik_tahap" class="lencana w-presensi"><PhTrendUp :size="13" weight="bold" /> Naik tahap</span></p>
            <p class="text-xs text-teks2">Tahap {{ l.tahap }} · {{ l.tahap_nama }}{{ l.materi ? ' · ' + l.materi : '' }}</p>
            <p v-if="l.catatan" class="text-xs text-teks3">{{ l.catatan }}</p>
            <p class="flex items-center gap-2 text-xs text-teks3">{{ l.oleh }}
              <button v-if="tr.boleh_bina" class="inline-flex min-h-[32px] items-center gap-1 font-semibold text-[#C7332F] dark:text-[#FF8FB8]" @click="hapusLog(l)"><PhTrash :size="14" /> Hapus</button></p>
          </li>
          <li v-if="!riwayat.length" class="text-sm text-teks3">Belum ada catatan pertemuan.</li>
        </ol>
      </div>
    </LembarBawah>

    <!-- Ubah -->
    <LembarBawah v-model="lembarUbah" :judul="tr ? `Ubah data tahsin · ${tr.nama}` : ''">
      <div v-if="tr" class="space-y-3 pb-2">
        <div><label class="label-isian" for="tu-tahap">Tahap berjalan</label>
          <select id="tu-tahap" v-model.number="fu.tahap" class="isian"><option v-for="(t, i) in ts.tahapan" :key="i" :value="i + 1">{{ i + 1 }}. {{ t.nama }}</option></select></div>
        <div><label class="label-isian" for="tu-pb">Pembina tahsin</label>
          <select id="tu-pb" v-model="fu.pembina_id" class="isian"><option value="">–</option><option v-for="p in pembina" :key="p.id" :value="p.id">{{ p.nama }}</option></select></div>
        <div><label class="label-isian" for="tu-cat">Catatan</label><input id="tu-cat" v-model="fu.catatan" class="isian" /></div>
        <button class="tombol-utama w-full" :disabled="proses" @click="simpanUbah"><PhCheckCircle :size="20" weight="duotone" /> Simpan</button>
      </div>
    </LembarBawah>

    <!-- Ajukan / putuskan / hentikan -->
    <LembarBawah v-model="lembarAksi" :judul="tr ? `${JUDUL_AKSI[mode]} · ${tr.nama}` : ''">
      <div v-if="tr" class="space-y-3 pb-2">
        <p class="text-sm text-teks2">Tahap {{ tr.tahap }}/{{ tr.jumlah_tahap }} ({{ tr.tahap_nama }}) · {{ tr.pertemuan }} pertemuan, lancar {{ tr.lancar }} kali · {{ tr.lama_hari }} hari.</p>
        <p v-if="mode !== 'hentikan'" class="rounded-xl bg-permukaan2 p-3 text-xs text-teks2">{{ ts.pengaturan?.catatan_lulus }}</p>
        <p v-if="mode === 'putus' && tr.catatan_ajuan" class="text-sm">Catatan pengaju: {{ tr.catatan_ajuan }}</p>
        <div><label class="label-isian" for="ta-cat">{{ mode === 'ajukan' ? 'Catatan untuk Kepala Bidang Tahfizh' : mode === 'putus' ? 'Catatan (wajib bila dikembalikan)' : 'Alasan penghentian' }}</label>
          <textarea id="ta-cat" v-model="catAksi" rows="3" class="isian" :placeholder="mode === 'hentikan' ? 'Contoh: salah tanda, santri sudah lancar membaca' : ''" /></div>
        <template v-if="mode === 'putus'">
          <button class="tombol-utama w-full" :disabled="proses" @click="simpanAksi(true)"><PhSealCheck :size="20" weight="duotone" /> Luluskan, mulai menghafal</button>
          <button v-if="tr.diajukan_lulus_pada" class="tombol-garis w-full" :disabled="proses" @click="simpanAksi(false)"><PhArrowCounterClockwise :size="20" /> Kembalikan, lanjutkan tahsin</button>
        </template>
        <button v-else class="tombol-utama w-full" :disabled="proses" @click="simpanAksi()">
          <component :is="mode === 'ajukan' ? PhPaperPlaneTilt : PhStop" :size="20" weight="duotone" /> {{ mode === 'ajukan' ? 'Kirim pengajuan' : 'Hentikan tahsin' }}</button>
      </div>
    </LembarBawah>

    <!-- Tahapan -->
    <LembarBawah v-model="lembarTahap" judul="Tahapan tahsin" lebar>
      <div class="space-y-3 pb-2">
        <p class="text-xs text-teks2">Urutan tahapan dipakai untuk mencatat kemajuan seluruh santri tahsin. Santri yang tahapnya melebihi jumlah tahapan baru disesuaikan otomatis.</p>
        <ol class="space-y-2">
          <li v-for="(t, i) in ftp.tahapan" :key="i" class="rounded-2xl bg-permukaan2 p-2.5">
            <div class="flex items-center gap-2">
              <span class="chip-ikon h-8 w-8 shrink-0 text-xs font-extrabold">{{ i + 1 }}</span>
              <input v-model="t.nama" class="isian min-h-[40px] flex-1 text-sm font-semibold" :aria-label="`Nama tahap ${i + 1}`" />
              <button class="tombol-ikon" :disabled="i === 0" aria-label="Naikkan" @click="geserTahap(i, -1)"><PhArrowUp :size="18" /></button>
              <button class="tombol-ikon" :disabled="i === ftp.tahapan.length - 1" aria-label="Turunkan" @click="geserTahap(i, 1)"><PhArrowDown :size="18" /></button>
              <button class="tombol-ikon" :disabled="ftp.tahapan.length <= 2" aria-label="Hapus tahap" @click="ftp.tahapan.splice(i, 1)"><PhTrash :size="18" /></button>
            </div>
            <input v-model="t.uraian" class="isian mt-2 min-h-[40px] text-sm" placeholder="Uraian singkat (opsional)" :aria-label="`Uraian tahap ${i + 1}`" />
          </li>
        </ol>
        <button class="tombol-garis w-full" :disabled="ftp.tahapan.length >= 20" @click="ftp.tahapan.push({ nama: '', uraian: '' })"><PhPlus :size="20" /> Tambah tahap</button>
        <div><label class="label-isian" for="tp-lulus">Ketentuan lulus tahsin</label><textarea id="tp-lulus" v-model="ftp.catatan_lulus" rows="2" class="isian" /></div>
        <div class="sm:w-56"><label class="label-isian" for="tp-kkm">KKM ujian tahsin (rata-rata Makhraj dan Shifat)</label><input id="tp-kkm" v-model.number="ftp.kkm_ujian" type="number" min="0" max="100" class="isian tabular-nums" /></div>
        <button class="tombol-utama w-full" :disabled="proses" @click="simpanTahap"><PhCheckCircle :size="20" weight="duotone" /> Simpan tahapan</button>
      </div>
    </LembarBawah>

    <!-- WA orang tua -->
    <LembarBawah v-model="lembarWA" :judul="tw ? `WhatsApp orang tua · ${tw.nama}` : ''">
      <div v-if="tw" class="space-y-3 pb-2">
        <div class="grid grid-cols-2 gap-1 rounded-xl bg-permukaan2 p-1" role="radiogroup" aria-label="Jenis pesan">
          <button type="button" role="radio" :aria-checked="jenisWA === 'perkembangan'" :class="['min-h-[38px] rounded-lg text-sm font-bold', jenisWA === 'perkembangan' ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks3']" @click="jenisWA = 'perkembangan'">Perkembangan</button>
          <button type="button" role="radio" :aria-checked="jenisWA === 'lulus'" :disabled="tw.status !== 'lulus'" :class="['min-h-[38px] rounded-lg text-sm font-bold', jenisWA === 'lulus' ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks3']" @click="jenisWA = 'lulus'">Lulus tahsin</button>
        </div>
        <p class="text-sm">{{ tw.wali?.nama || 'Orang tua/wali' }} · {{ tw.wali?.no_hp || 'nomor belum tercatat' }}</p>
        <PratinjauWA :teks="teksWA" />
        <TombolWA :hp="tw.wali?.no_hp" :pesan="teksWA" label="Kirim ke orang tua" />
      </div>
    </LembarBawah>

    <!-- 14.21.0: Nilai ujian tahsin -->
    <LembarBawah v-model="lembarUji" :judul="tr ? `Ujian tahsin · ${tr.nama}` : ''">
      <div v-if="tr" class="space-y-3 pb-2">
        <dl class="grid grid-cols-[7rem_1fr] gap-x-2 gap-y-1 rounded-xl bg-permukaan2 p-3 text-sm">
          <dt class="text-teks3">Nama</dt><dd class="font-semibold">{{ tr.nama }}</dd>
          <dt class="text-teks3">Kelas</dt><dd>{{ tr.kelas || '–' }}</dd>
          <dt class="text-teks3">Muhaffizh</dt><dd>{{ tr.muhaffizh || tr.pembina || '–' }}</dd>
          <dt class="text-teks3">Tahap</dt><dd>{{ tr.tahap }}/{{ tr.jumlah_tahap }} · {{ tr.pertemuan }} pertemuan</dd>
        </dl>
        <InputTanggal v-model="fx.tanggal" label="Tanggal ujian" wajib />
        <div class="grid grid-cols-2 gap-3">
          <div><label class="label-isian" for="ux-m">Makhraj (0–100) <span class="text-merah">*</span></label><input id="ux-m" v-model="fx.makhraj" type="number" min="0" max="100" inputmode="decimal" class="isian tabular-nums" /></div>
          <div><label class="label-isian" for="ux-s">Shifat (0–100) <span class="text-merah">*</span></label><input id="ux-s" v-model="fx.shifat" type="number" min="0" max="100" inputmode="decimal" class="isian tabular-nums" /></div>
        </div>
        <p class="text-sm">Rata-rata: <b class="tabular-nums">{{ rataUji == null ? '–' : angka(rataUji) }}</b> · KKM {{ kkm }}</p>
        <div><p class="label-isian">Hasil <span class="text-merah">*</span></p>
          <div class="grid grid-cols-2 gap-1 rounded-xl bg-permukaan2 p-1" role="radiogroup" aria-label="Hasil ujian tahsin">
            <button v-for="(h, k) in HASIL_TAHSIN" :key="k" type="button" role="radio" :aria-checked="fx.hasil === k" @click="pilihHasil(k)"
              :class="['min-h-[42px] rounded-lg text-sm font-bold', 'w-' + h.w, fx.hasil === k ? 'text-white shadow-kartu' : 'text-teks3']" :style="fx.hasil === k ? 'background: var(--c)' : ''">{{ h.n }}</button>
          </div></div>
        <div><label class="label-isian" for="ux-c">Catatan {{ fx.hasil === 'belum_lulus' ? '(wajib)' : '(opsional)' }}</label>
          <textarea id="ux-c" v-model="fx.catatan" rows="2" class="isian" :placeholder="fx.hasil === 'belum_lulus' ? 'Contoh: huruf ain dan hamzah masih tertukar' : 'Contoh: makhraj dan sifat huruf sudah tepat'" /></div>
        <p class="rounded-xl bg-permukaan2 p-3 text-xs text-teks2">Lulus: santri mulai menghafal dan Surat Keterangan Hasil Ujian Tahsin terbit (ditandatangani penguji dan Kepala Bidang Tahfizh sesuai Setelan). Belum lulus: santri melanjutkan tahsin.</p>
        <button class="tombol-utama w-full" :disabled="proses" @click="simpanUji"><PhCertificate :size="20" weight="duotone" /> Simpan hasil ujian</button>
      </div>
    </LembarBawah>

    <!-- 14.21.0: WA ke penguji tahsin -->
    <LembarBawah v-model="lembarMinta" :judul="tr ? `Minta ujian tahsin · ${tr.nama}` : ''">
      <div v-if="tr" class="space-y-3 pb-2">
        <p class="text-sm text-teks2">Penguji tahsin dan Kepala Bidang Tahfizh sudah menerima notifikasi SIMKA. Kabari juga lewat WhatsApp agar santri segera diuji.</p>
        <div class="flex flex-wrap gap-2">
          <TombolWA v-for="p in pengujiTahsin" :key="p.employee_id" :hp="p.no_hp" :pesan="pesanMinta(p)" :label="p.nama" />
        </div>
        <p v-if="!pengujiTahsin.length" class="text-sm text-teks3">Penguji tahsin belum ditetapkan. Tambahkan di Tahfizh → Ketentuan → Penguji (Ujian tahsin).</p>
        <button class="tombol-garis w-full" @click="lembarMinta = false">Selesai</button>
      </div>
    </LembarBawah>

    <CetakDokumenTahfizh v-if="dokSuket" :key="dokSuket.id" v-model:pratinjau="pratinjauSuket" :dok="dokSuket" />

    <!-- 14.21.0: Cetak rekap ujian tahsin -->
    <DokumenCetak jenis="thz_ujian_tahsin" kop="pondok" judul="Rekap Hasil Ujian Tahsin" :subjudul="`Ujian ${formatPanjang(ujMulai)} s.d. ${formatPanjang(ujSelesai)}${ujHasil ? ' · ' + HASIL_TAHSIN[ujHasil].n : ''}`" v-model:pratinjau="pratinjauUjian" mendatar :pencetak="sesi.pengguna?.nama_lengkap">
      <table class="tabel kecil">
        <colgroup><col style="width:4%"><col style="width:8%"><col style="width:17%"><col style="width:7%"><col style="width:12%"><col style="width:14%"><col style="width:9%"><col style="width:6%"><col style="width:6%"><col style="width:6%"><col style="width:8%"><col style="width:13%"></colgroup>
        <thead><tr><th>No.</th><th>NIS</th><th>Nama</th><th>Kelas</th><th>Halaqah</th><th>Muhaffizh</th><th>Tanggal</th><th>Makhraj</th><th>Shifat</th><th>Rata-rata</th><th>Hasil</th><th>Catatan</th></tr></thead>
        <tbody><tr v-for="(u, i) in ujianTampil" :key="u.id">
          <td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ u.nis }}</td><td>{{ u.nama }}</td><td class="tengah">{{ u.kelas || '–' }}</td><td>{{ u.halaqah || '–' }}</td><td>{{ u.muhaffizh || '–' }}</td>
          <td class="tengah">{{ formatPendek(u.tanggal) }}</td><td class="tengah">{{ angka(u.makhraj) }}</td><td class="tengah">{{ angka(u.shifat) }}</td><td class="tengah">{{ angka(u.nilai) }}</td>
          <td class="tengah">{{ HASIL_TAHSIN[u.hasil].n }}</td><td>{{ u.catatan || '' }}</td></tr></tbody>
      </table>
      <p style="margin-top: 6pt; font-size: 9pt">Jumlah {{ ujianTampil.length }} ujian: lulus {{ ujianTampil.filter((u) => u.hasil === 'lulus').length }}, belum lulus {{ ujianTampil.filter((u) => u.hasil !== 'lulus').length }}. KKM {{ kkm }} (rata-rata Makhraj dan Shifat).</p>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: kepala.jabatan, nama: kepala.nama, niy: kepala.niy }"
          :kanan="{ jabatan: 'Pencetak', nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
      </template>
    </DokumenCetak>

    <!-- Cetak -->
    <DokumenCetak jenis="thz_tahsin" kop="pondok" judul="Daftar Santri Tahsin" :subjudul="subjudulCetak" v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap">
      <table class="tabel kecil">
        <colgroup><col style="width:5%"><col style="width:10%"><col style="width:21%"><col style="width:5%"><col style="width:6%"><col style="width:12%"><col style="width:10%"><col style="width:18%"><col style="width:5%"><col style="width:8%"></colgroup>
        <thead><tr><th>No.</th><th>NIS</th><th>Nama</th><th>JK</th><th>Kelas</th><th>Halaqah</th><th>Mulai</th><th>Tahap</th><th>Temu</th><th>Status</th></tr></thead>
        <tbody><tr v-for="(t, i) in tampil" :key="t.id">
          <td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ t.nis }}</td><td>{{ t.nama }}</td><td class="tengah">{{ t.jenis_kelamin }}</td><td class="tengah">{{ t.kelas || '–' }}</td>
          <td>{{ t.halaqah || '–' }}</td><td class="tengah">{{ formatPendek(t.mulai) }}</td><td>{{ t.tahap }}/{{ t.jumlah_tahap }} {{ t.tahap_nama }}</td><td class="tengah">{{ t.pertemuan }}</td>
          <td class="tengah">{{ STATUS_TAHSIN[keadaanTahsin(t)].n }}</td></tr></tbody>
      </table>
      <p style="margin-top: 6pt; font-size: 9pt">Jumlah {{ tampil.length }} santri. Tahap = tahap berjalan/jumlah tahapan. Temu = jumlah pertemuan tercatat.</p>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: kepala.jabatan, nama: kepala.nama, niy: kepala.niy }"
          :kanan="{ jabatan: 'Pencetak', nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
      </template>
    </DokumenCetak>
  </div>
</template>
