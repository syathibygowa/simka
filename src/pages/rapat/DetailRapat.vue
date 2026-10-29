<!-- SIMKA PRO | src/pages/rapat/DetailRapat.vue | v1.2 | 14.30.0: tombol Kembali/Sebelumnya/Berikutnya; status konfirmasi dan kehadiran tidak ganda | 29/10/2026 -->
<script setup>
// Rincian satu rapat (/rapat/:id) — dibuka peserta yang diundang dan admin/superadmin.
//   Peserta  : konfirmasi Hadir/Izin/Sakit/Dinas luar (dengan alasan), tombol "Saya hadir" saat rapat berlangsung, baca notulen.
//   Admin    : ubah rapat, presensi peserta (H/T/I/S/DL/A; isi cepat dari konfirmasi), notulen (pembahasan, keputusan, tindak lanjut),
//              laporan instan ke grup WhatsApp, pengingat pribadi via WhatsApp, cetak Daftar Hadir dan Notulen Rapat (F4, kop, tanda tangan).
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  PhUsersThree, PhClock, PhMapPin, PhLink, PhUser, PhNotePencil, PhPencilSimple, PhWhatsappLogo, PhPrinter, PhTrash, PhCheckCircle, PhHandWaving,
  PhNotebook, PhBellRinging, PhPlus, PhX, PhFloppyDisk, PhCalendarStar, PhWarningCircle, PhPercent, PhHourglassMedium, PhEnvelopeSimple,
} from '@phosphor-icons/vue'
import { useRapat } from '@/stores/rapat'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { JENIS_RAPAT, STATUS_RAPAT, KONFIRMASI, KEHADIRAN, jamRapat, ringkasPeserta, laporanRapatWA, pesanPengingatRapat, HADIR } from '@/lib/rapat'
import { formatHari, formatPanjang, formatWaktu, hariIniISO, sekarang } from '@/lib/tanggal'
import { namaBerkas } from '@/lib/namaBerkas'
import BilahTab from '@/components/BilahTab.vue'
import KartuStatistik from '@/components/KartuStatistik.vue'
import LembarLaporanGrup from '@/components/LembarLaporanGrup.vue'
import DaftarKirimWA from '@/components/DaftarKirimWA.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import IsianTeksKaya from '@/components/IsianTeksKaya.vue'
import { teksKaya } from '@/lib/teksKaya'
import LembarRapat from './LembarRapat.vue'
import NavUrutan from '@/components/NavUrutan.vue'

const route = useRoute(); const router = useRouter(); const rp = useRapat(); const sesi = useSesi(); const ui = useUI()
const D = ref(null); const galat = ref(''); const proses = ref('')
async function muat() {
  galat.value = ''
  try { D.value = await rp.detail(route.params.id); salin() } catch (e) { galat.value = e.message; D.value = null }
}
onMounted(muat)
watch(() => route.params.id, (b, l) => { if (b && b !== l) muat() })
const r = computed(() => D.value?.rapat || {})
const kelola = computed(() => !!D.value?.boleh_kelola)
const S = computed(() => ringkasPeserta(D.value?.peserta || []))
const jenis = computed(() => JENIS_RAPAT[r.value.jenis] || JENIS_RAPAT.lainnya)

// ---------- Tab ----------
const TAB = computed(() => [
  { k: 'peserta', n: 'Peserta dan kehadiran', ikon: PhUsersThree, w: 'rapat', jumlah: S.value.n },
  { k: 'notulen', n: 'Notulen', ikon: PhNotebook, w: 'tatausaha', lencana: r.value.notulen_pada ? null : null },
  ...(kelola.value ? [{ k: 'ingatkan', n: 'Ingatkan via WA', ikon: PhBellRinging, w: 'presensi' }] : []),
])
const tab = ref(route.query.tab === 'notulen' ? 'notulen' : 'peserta')
watch(() => D.value?.rapat?.notulen_pada, (v) => { if (v && !kelola.value && route.query.tab !== 'peserta') tab.value = 'notulen' })

// ---------- Waktu ----------
const mulaiMs = computed(() => (r.value.tanggal ? Date.parse(`${r.value.tanggal}T${String(r.value.jam_mulai || '07:00').slice(0, 5)}:00+08:00`) : 0))
const bukaPresensi = computed(() => { const n = sekarang().getTime(); return r.value.status === 'dijadwalkan' && n >= mulaiMs.value - 30 * 60000 && n <= mulaiMs.value + 5 * 3600000 })
const lewat = computed(() => r.value.tanggal < hariIniISO())

// ---------- Konfirmasi saya ----------
const saya = computed(() => D.value?.saya)
const pilihKonf = ref(''); const alasan = ref('')
watch(saya, (s) => { pilihKonf.value = s?.konfirmasi === 'menunggu' ? '' : s?.konfirmasi || ''; alasan.value = s?.alasan || '' }, { immediate: true })
async function konfirmasi(st) {
  if (st !== 'hadir' && alasan.value.trim().length < 3) { pilihKonf.value = st; return ui.toast('Tuliskan alasan singkat, lalu tekan Kirim.', 'info') }
  proses.value = 'konf'
  try { await rp.konfirmasi(r.value.id, st, alasan.value); ui.toast(st === 'hadir' ? 'Terima kasih, Anda tercatat akan hadir.' : 'Konfirmasi tidak hadir terkirim.'); await muat() }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = '' }
}
async function sayaHadir() {
  proses.value = 'hadir'
  try { const st = await rp.hadir(r.value.id); ui.toast(st === 'terlambat' ? 'Kehadiran tercatat (terlambat).' : 'Kehadiran Anda tercatat. Selamat mengikuti rapat.'); await muat() }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = '' }
}

// ---------- Presensi (admin) ----------
const hadir = ref({}); const ubahH = ref(new Set())
function salin() {
  hadir.value = Object.fromEntries((D.value?.peserta || []).map((p) => [p.employee_id, p.kehadiran || '']))
  ubahH.value = new Set()
  const x = D.value?.rapat || {}
  notulen.value = { pembahasan: x.pembahasan || '', keputusan: x.keputusan || '', catatan: x.catatan || '', tindak_lanjut: (x.tindak_lanjut || []).map((t) => ({ ...t })) }
  ubahN.value = false
}
function setH(id, k) { hadir.value[id] = hadir.value[id] === k ? '' : k; ubahH.value = new Set([...ubahH.value, id]) }
function dariKonfirmasi() {
  let n = 0
  for (const p of D.value.peserta) { if (hadir.value[p.employee_id]) continue; const k = p.konfirmasi === 'hadir' ? 'hadir' : ['izin', 'sakit', 'dinas_luar'].includes(p.konfirmasi) ? p.konfirmasi : ''; if (k) { hadir.value[p.employee_id] = k; ubahH.value = new Set([...ubahH.value, p.employee_id]); n++ } }
  ui.toast(n ? `${n} peserta diisi dari konfirmasinya. Periksa lalu Simpan.` : 'Tidak ada yang dapat diisi dari konfirmasi.')
}
async function simpanHadir() {
  proses.value = 'hadir-admin'
  try { await rp.simpanKehadiran(r.value.id, [...ubahH.value].map((id) => ({ employee_id: id, kehadiran: hadir.value[id] || null }))); ui.toast('Presensi rapat disimpan.'); await muat() }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = '' }
}

// ---------- Notulen (admin) ----------
const notulen = ref({ pembahasan: '', keputusan: '', catatan: '', tindak_lanjut: [] }); const ubahN = ref(false); const suntingN = ref(false)
const tambahTL = () => { notulen.value.tindak_lanjut.push({ tugas: '', pj: '', tenggat: '' }); ubahN.value = true }
async function simpanNotulen(selesai) {
  if (selesai && !notulen.value.pembahasan.trim() && !notulen.value.keputusan.trim()) return ui.toast('Isi pokok pembahasan atau keputusan sebelum menandai selesai.', 'galat')
  if (selesai && !(await ui.konfirmasi({ judul: 'Tandai rapat selesai?', pesan: 'Peserta menerima pemberitahuan notulen. Peserta yang belum tercatat hadirnya dicatat izin (sesuai konfirmasi) atau tanpa keterangan.', ya: 'Tandai selesai' }))) return
  proses.value = 'notulen'
  try {
    if (selesai && ubahH.value.size) await rp.simpanKehadiran(r.value.id, [...ubahH.value].map((id) => ({ employee_id: id, kehadiran: hadir.value[id] || null })))
    await rp.simpanNotulen(r.value.id, { ...notulen.value, tindak_lanjut: notulen.value.tindak_lanjut.filter((t) => t.tugas.trim()), selesai })
    ui.toast(selesai ? 'Notulen disimpan dan rapat ditandai selesai. Peserta diberi tahu.' : 'Notulen disimpan.'); suntingN.value = false; await muat()
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = '' }
}

// ---------- Lain-lain ----------
const lembarUbah = ref(false); const lembarWA = ref(false); const formatWA = ref('lengkap')
const teksLaporan = computed(() => (D.value ? laporanRapatWA(D.value, formatWA.value) : ''))
const FORMAT_WA = [{ k: 'lengkap', n: 'Lengkap', ket: 'Daftar nama hadir, izin, dan tanpa keterangan' }, { k: 'ringkas', n: 'Ringkas', ket: 'Jumlah dan persentase saja' }]
const penerimaWA = computed(() => (D.value?.peserta || []).map((p) => ({ ...p })))
const saringWA = [{ k: 'menunggu', n: 'Belum konfirmasi', f: (p) => p.konfirmasi === 'menunggu' }, { k: 'hadir', n: 'Akan hadir', f: (p) => p.konfirmasi === 'hadir' }, { k: 'semua', n: 'Semua peserta', f: () => true }]
async function hapus() {
  if (!(await ui.konfirmasi({ judul: 'Hapus rapat?', pesan: 'Rapat, daftar peserta, presensi, dan notulennya terhapus permanen.', ya: 'Hapus', bahaya: true }))) return
  try { await rp.hapus(r.value.id); ui.toast('Rapat dihapus.'); router.replace('/rapat') } catch (e) { ui.toast(e.message, 'galat') }
}
const cetak = ref(''); const pratinjau = computed({ get: () => !!cetak.value, set: (v) => { if (!v) cetak.value = '' } })
const ttdKiri = computed(() => ({ jabatan: 'Pimpinan Rapat,', nama: r.value.pimpinan || '', niy: r.value.pimpinan_niy }))
const ttdKanan = computed(() => ({ jabatan: 'Notulis,', nama: r.value.notulis || '', niy: r.value.notulis_niy }))
const subjudul = computed(() => `${r.value.judul} · ${formatHari(r.value.tanggal)}`)
const statistik = computed(() => {
  const s = S.value; const selesai = r.value.status === 'selesai' || s.n - s.belum.length > 0
  return selesai ? [
    { judul: 'Peserta', nilai: s.n, ikon: PhUsersThree, warna: 'rapat', ket: r.value.ringkasan_sasaran || 'Diundang' },
    { judul: 'Hadir', nilai: s.hadir.length, ikon: PhCheckCircle, warna: 'presensi', ket: s.terlambat.length ? `${s.terlambat.length} terlambat` : 'Tepat waktu' },
    { judul: 'Izin/sakit/dinas', nilai: s.izin.length, ikon: PhEnvelopeSimple, warna: 'pengajuan', ket: `Tanpa keterangan ${s.alpa.length}` },
    { judul: 'Kehadiran', nilai: s.persen, satuan: '%', ikon: PhPercent, warna: 'agenda', ket: s.belum.length ? `${s.belum.length} belum dicatat` : 'Lengkap' },
  ] : [
    { judul: 'Peserta', nilai: s.n, ikon: PhUsersThree, warna: 'rapat', ket: r.value.ringkasan_sasaran || 'Diundang' },
    { judul: 'Akan hadir', nilai: s.konf.hadir, ikon: PhCheckCircle, warna: 'presensi', ket: 'Sudah konfirmasi' },
    { judul: 'Izin/sakit/dinas', nilai: s.konf.izin, ikon: PhEnvelopeSimple, warna: 'pengajuan', ket: 'Berhalangan' },
    { judul: 'Belum konfirmasi', nilai: s.konf.menunggu, ikon: PhHourglassMedium, warna: 'klinik', ket: 'Ingatkan via WA' },
  ]
})
</script>
<template>
  <div :class="['pb-24', 'w-' + jenis.w]">
    <NavUrutan class="mb-3" jenis="rapat" kembali="/rapat" label-kembali="Kembali ke Rapat" />
    <div v-if="galat" class="kartu w-klinik flex flex-wrap items-center gap-3 p-5">
      <PhWarningCircle :size="24" class="shrink-0" style="color: var(--c)" /><p class="min-w-[200px] flex-1 text-sm font-semibold" style="color: var(--c)">{{ galat }}</p>
      <button class="tombol-garis" @click="router.push('/rapat')">Kembali ke Rapat</button>
    </div>
    <template v-else-if="D">
      <!-- Kepala -->
      <section class="kartu kepala overflow-hidden p-5">
        <div class="flex flex-wrap items-start gap-3">
          <span class="chip-ikon h-12 w-12 shrink-0"><PhUsersThree :size="28" weight="duotone" /></span>
          <div class="min-w-0 flex-1">
            <p class="flex flex-wrap gap-1.5 text-xs"><span class="lencana">{{ jenis.n }}</span><span v-if="r.unit" class="lencana w-walikelas">{{ r.unit }}</span>
              <span :class="['lencana', 'w-' + STATUS_RAPAT[r.status].w]">{{ STATUS_RAPAT[r.status].n }}</span>
              <span v-if="r.agenda_id" class="lencana w-agenda"><PhCalendarStar :size="12" weight="fill" /> dari Agenda</span></p>
            <h2 class="mt-1 text-xl font-bold leading-tight">{{ r.judul }}</h2>
            <p class="mt-1 flex flex-wrap gap-x-4 gap-y-1 text-sm text-teks2">
              <span>{{ formatHari(r.tanggal) }}</span><span v-if="jamRapat(r)" class="flex items-center gap-1"><PhClock :size="16" />{{ jamRapat(r) }} WITA</span>
              <span v-if="r.lokasi" class="flex items-center gap-1"><PhMapPin :size="16" />{{ r.lokasi }}</span>
              <a v-if="r.tautan" :href="r.tautan" target="_blank" rel="noopener" class="flex items-center gap-1 font-semibold underline" style="color: var(--c)"><PhLink :size="16" />Tautan daring</a></p>
            <p class="mt-1 flex flex-wrap gap-x-4 text-sm text-teks2"><span class="flex items-center gap-1"><PhUser :size="16" />Pimpinan: <b>{{ r.pimpinan || '–' }}</b></span>
              <span class="flex items-center gap-1"><PhNotePencil :size="16" />Notulis: <b>{{ r.notulis || '–' }}</b></span></p>
          </div>
        </div>
        <div v-if="kelola" class="mt-4 flex flex-wrap gap-2">
          <button class="tombol-garis min-h-[40px] px-3 text-sm" @click="lembarUbah = true"><PhPencilSimple :size="18" /> Ubah</button>
          <button class="tombol-wa-garis min-h-[40px] px-3 text-sm" @click="lembarWA = true"><PhWhatsappLogo :size="18" weight="duotone" /> Laporan ke grup WA</button>
          <button class="tombol-garis min-h-[40px] px-3 text-sm" @click="cetak = 'hadir'"><PhPrinter :size="18" weight="duotone" /> Daftar hadir</button>
          <button class="tombol-garis min-h-[40px] px-3 text-sm" @click="cetak = 'notulen'"><PhPrinter :size="18" weight="duotone" /> Notulen</button>
          <button v-if="!r.agenda_id || lewat" class="tombol-garis min-h-[40px] px-3 text-sm text-merah" @click="hapus"><PhTrash :size="18" /> Hapus</button>
        </div>
        <div v-else-if="r.notulen_pada" class="mt-4 flex flex-wrap gap-2">
          <button class="tombol-garis min-h-[40px] px-3 text-sm" @click="cetak = 'notulen'"><PhPrinter :size="18" weight="duotone" /> Cetak notulen</button>
        </div>
      </section>

      <!-- Konfirmasi dan hadir saya -->
      <section v-if="saya && r.status !== 'batal'" class="kartu mt-3 p-4">
        <div class="flex flex-wrap items-center gap-2">
          <p class="flex-1 font-bold">Kehadiran saya</p>
          <span v-if="!saya.kehadiran" :class="['lencana', 'w-' + KONFIRMASI[saya.konfirmasi].w]">{{ KONFIRMASI[saya.konfirmasi].n }}</span>
          <span v-if="saya.kehadiran" :class="['lencana', 'w-' + KEHADIRAN[saya.kehadiran].w]">{{ KEHADIRAN[saya.kehadiran].n }}{{ saya.hadir_pada ? ' · ' + formatWaktu(saya.hadir_pada) : '' }}</span>
        </div>
        <button v-if="bukaPresensi && !HADIR(saya.kehadiran)" class="tombol-utama mt-3 w-full" :disabled="!!proses" @click="sayaHadir"><PhHandWaving :size="22" weight="duotone" /> {{ proses === 'hadir' ? 'Mencatat…' : 'Saya hadir di rapat ini' }}</button>
        <template v-if="r.status === 'dijadwalkan' && !saya.kehadiran">
          <p class="mt-3 text-sm text-teks2">Konfirmasi kehadiran Anda:</p>
          <div class="mt-2 grid grid-cols-2 gap-2 sm:grid-cols-4">
            <button v-for="k in ['hadir', 'izin', 'sakit', 'dinas_luar']" :key="k" type="button" :disabled="!!proses" @click="k === 'hadir' ? konfirmasi('hadir') : (pilihKonf = k)"
              :class="['min-h-[44px] rounded-xl border-2 px-3 text-sm font-bold', 'w-' + KONFIRMASI[k].w, (pilihKonf || saya.konfirmasi) === k ? 'text-teks' : 'border-garis text-teks2']"
              :style="(pilihKonf || saya.konfirmasi) === k ? 'border-color: var(--c); background: color-mix(in srgb, var(--c) 16%, transparent)' : ''">{{ k === 'hadir' ? 'Insya Allah hadir' : KONFIRMASI[k].n }}</button>
          </div>
          <div v-if="pilihKonf && pilihKonf !== 'hadir'" class="mt-3 flex flex-wrap gap-2">
            <input v-model="alasan" class="isian min-w-[220px] flex-1" placeholder="Alasan singkat, mis. mengantar santri ke rumah sakit" aria-label="Alasan tidak hadir" />
            <button class="tombol-utama px-5" :disabled="!!proses" @click="konfirmasi(pilihKonf)">{{ proses === 'konf' ? 'Mengirim…' : 'Kirim' }}</button>
          </div>
          <p v-if="saya.alasan" class="mt-2 text-xs text-teks3">Alasan tercatat: {{ saya.alasan }}</p>
        </template>
      </section>
      <p v-if="r.status === 'batal'" class="kartu w-klinik mt-3 p-4 text-sm font-semibold" style="color: var(--c)">Rapat ini dibatalkan.</p>

      <div class="-mx-4 my-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-2 sm:overflow-visible sm:px-0 xl:grid-cols-4">
        <KartuStatistik v-for="k in statistik" :key="k.judul" class="w-[46%] shrink-0 snap-start sm:w-auto" :judul="k.judul" :nilai="k.nilai" :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket" :satuan="k.satuan" />
      </div>

      <BilahTab v-model="tab" class="mb-4" :tab="TAB" label="Bagian rapat" />

      <!-- Peserta -->
      <template v-if="tab === 'peserta'">
        <section v-if="kelola" class="kartu mb-3 flex flex-wrap items-center gap-2 p-3 text-sm">
          <p class="min-w-[220px] flex-1 text-teks2">Catat kehadiran: H hadir, T terlambat, I izin, S sakit, DL dinas luar, A tanpa keterangan. Peserta juga dapat menekan "Saya hadir" saat rapat berlangsung.</p>
          <button class="tombol-garis min-h-[38px] px-3 text-sm" @click="dariKonfirmasi">Isi dari konfirmasi</button>
        </section>
        <ul class="kartu divide-y divide-garis">
          <li v-for="(p, i) in D.peserta" :key="p.employee_id" class="flex flex-wrap items-center gap-x-3 gap-y-2 px-4 py-3">
            <span class="w-6 text-right text-xs tabular-nums text-teks3">{{ i + 1 }}</span>
            <div class="min-w-[180px] flex-1">
              <p class="font-semibold">{{ p.nama }}<span v-if="p.employee_id === r.pimpinan_id" class="lencana ml-1.5 text-[11px]">Pimpinan</span><span v-if="p.employee_id === r.notulis_id" class="lencana ml-1.5 text-[11px]">Notulis</span></p>
              <p class="text-xs text-teks3">{{ [p.jabatan, p.unit].filter(Boolean).join(' · ') || '–' }}</p>
              <p class="mt-0.5 flex flex-wrap gap-1.5 text-xs">
                <span v-if="kelola || !p.kehadiran" :class="['lencana', 'w-' + KONFIRMASI[p.konfirmasi].w]">{{ kelola && p.kehadiran ? 'Konfirmasi: ' : '' }}{{ KONFIRMASI[p.konfirmasi].n }}</span>
                <span v-if="p.alasan" class="text-teks2">{{ p.alasan }}</span>
                <span v-if="!kelola && p.kehadiran" :class="['lencana', 'w-' + KEHADIRAN[p.kehadiran].w]">{{ KEHADIRAN[p.kehadiran].n }}</span></p>
            </div>
            <div v-if="kelola" class="flex flex-wrap gap-1" role="radiogroup" :aria-label="`Kehadiran ${p.nama}`">
              <button v-for="(v, k) in KEHADIRAN" :key="k" type="button" role="radio" :aria-checked="hadir[p.employee_id] === k" :title="v.n" @click="setH(p.employee_id, k)"
                :class="['h-10 min-w-[40px] rounded-xl border-2 px-1.5 text-xs font-extrabold', 'w-' + v.w, hadir[p.employee_id] === k ? '' : 'border-garis text-teks3']"
                :style="hadir[p.employee_id] === k ? 'border-color: var(--c); background: color-mix(in srgb, var(--c) 18%, transparent); color: var(--c)' : ''">{{ v.k }}</button>
            </div>
          </li>
          <li v-if="!D.peserta.length" class="p-6 text-center text-sm text-teks3">Belum ada peserta.</li>
        </ul>
      </template>

      <!-- Notulen -->
      <template v-else-if="tab === 'notulen'">
        <section v-if="!suntingN" class="kartu space-y-4 p-5">
          <div v-if="!r.pembahasan && !r.keputusan && !(r.tindak_lanjut || []).length" class="py-4 text-center text-sm text-teks3">
            <PhNotebook :size="36" weight="duotone" class="mx-auto" /><p class="mt-2">Notulen belum diisi.</p></div>
          <!-- eslint-disable vue/no-v-html -- teksKaya() meng-escape isi lebih dahulu -->
          <div v-if="r.pembahasan"><h3 class="mb-1 font-bold">Pokok pembahasan</h3><p class="teks-kaya whitespace-pre-line text-sm text-teks2" v-html="teksKaya(r.pembahasan)" /></div>
          <div v-if="r.keputusan"><h3 class="mb-1 font-bold">Keputusan/hasil rapat</h3><p class="teks-kaya whitespace-pre-line text-sm text-teks2" v-html="teksKaya(r.keputusan)" /></div>
          <div v-if="(r.tindak_lanjut || []).length"><h3 class="mb-1 font-bold">Tindak lanjut</h3>
            <ul class="divide-y divide-garis rounded-xl border border-garis text-sm"><li v-for="(t, i) in r.tindak_lanjut" :key="i" class="flex flex-wrap gap-x-3 px-3 py-2"><b class="flex-1">{{ i + 1 }}. {{ t.tugas }}</b>
              <span v-if="t.pj" class="text-teks2">PJ: {{ t.pj }}</span><span v-if="t.tenggat" class="text-teks3">tenggat {{ formatPanjang(t.tenggat) }}</span></li></ul></div>
          <div v-if="r.catatan"><h3 class="mb-1 font-bold">Catatan</h3><p class="teks-kaya whitespace-pre-line text-sm text-teks2" v-html="teksKaya(r.catatan)" /></div>
          <!-- eslint-enable vue/no-v-html -->
          <p v-if="r.notulen_pada" class="text-xs text-teks3">Notulen ditetapkan {{ formatWaktu(r.notulen_pada) }}.</p>
          <button v-if="kelola" class="tombol-utama w-full sm:w-auto" @click="suntingN = true"><PhPencilSimple :size="18" /> {{ r.pembahasan || r.keputusan ? 'Ubah notulen' : 'Tulis notulen' }}</button>
        </section>
        <section v-else class="kartu space-y-4 p-5">
          <IsianTeksKaya id="nt-bahas" v-model="notulen.pembahasan" label="Pokok pembahasan" tinggi="10rem" placeholder="Hal-hal yang dibahas dalam rapat" @update:model-value="ubahN = true" />
          <IsianTeksKaya id="nt-putus" v-model="notulen.keputusan" label="Keputusan/hasil rapat" tinggi="10rem" placeholder="1. …" :petunjuk="false" @update:model-value="ubahN = true" />
          <div>
            <p class="label-isian">Tindak lanjut</p>
            <div v-for="(t, i) in notulen.tindak_lanjut" :key="i" class="mb-2 grid gap-2 rounded-xl border border-garis p-2 sm:grid-cols-[1fr_200px_170px_44px]">
              <input v-model="t.tugas" class="isian" placeholder="Tugas" :aria-label="`Tugas ${i + 1}`" @input="ubahN = true" />
              <input v-model="t.pj" class="isian" placeholder="Penanggung jawab" :aria-label="`Penanggung jawab ${i + 1}`" @input="ubahN = true" />
              <InputTanggal v-model="t.tenggat" bawaan-kosong />
              <button type="button" class="tombol-ikon self-center" aria-label="Hapus tindak lanjut" @click="notulen.tindak_lanjut.splice(i, 1); ubahN = true"><PhX :size="18" /></button>
            </div>
            <button type="button" class="tombol-garis min-h-[38px] px-3 text-sm" @click="tambahTL"><PhPlus :size="16" weight="bold" /> Tambah tindak lanjut</button>
          </div>
          <IsianTeksKaya id="nt-cat" v-model="notulen.catatan" label="Catatan lain" tinggi="5rem" :petunjuk="false" @update:model-value="ubahN = true" />
          <div class="flex flex-wrap gap-2">
            <button class="tombol-garis" @click="salin(); suntingN = false">Batal</button>
            <button class="tombol-garis" :disabled="!!proses" @click="simpanNotulen(false)"><PhFloppyDisk :size="18" /> Simpan draf</button>
            <button v-if="r.status !== 'selesai'" class="tombol-utama" :disabled="!!proses" @click="simpanNotulen(true)"><PhCheckCircle :size="18" weight="duotone" /> {{ proses === 'notulen' ? 'Menyimpan…' : 'Simpan dan tandai selesai' }}</button>
            <button v-else class="tombol-utama" :disabled="!!proses" @click="simpanNotulen(false)"><PhFloppyDisk :size="18" /> Simpan perubahan</button>
          </div>
          <p class="text-xs text-teks3">Saat ditandai selesai, peserta menerima pemberitahuan notulen; peserta yang belum dicatat hadirnya dicatat izin (sesuai konfirmasi) atau tanpa keterangan.</p>
        </section>
      </template>

      <!-- Ingatkan via WA -->
      <template v-else-if="tab === 'ingatkan'">
        <section class="kartu p-4">
          <p class="mb-3 text-sm text-teks2">Peserta juga menerima pengingat otomatis di akunnya (H-1 bila belum konfirmasi dan 1 jam sebelum rapat). Ketuk nama untuk mengirim pengingat pribadi via WhatsApp.</p>
          <DaftarKirimWA :penerima="penerimaWA" :pesan="(p) => pesanPengingatRapat(r, p)" :kunci="'rapat-' + r.id" :saringan="saringWA" />
        </section>
      </template>

      <!-- Bilah simpan presensi -->
      <div v-if="kelola && ubahH.size && tab === 'peserta'" class="fixed inset-x-0 bottom-[76px] z-30 flex justify-center px-4 lg:bottom-6 lg:pl-[280px]">
        <div class="kartu flex w-full max-w-xl items-center gap-3 p-3 shadow-xl">
          <PhWarningCircle :size="20" class="shrink-0" style="color: var(--c)" /><p class="flex-1 text-sm font-semibold">{{ ubahH.size }} perubahan presensi</p>
          <button class="tombol-garis min-h-[40px] px-3 text-sm" @click="salin">Batal</button>
          <button class="tombol-utama min-h-[40px] px-4 text-sm" :disabled="!!proses" @click="simpanHadir"><PhFloppyDisk :size="18" weight="duotone" /> {{ proses ? 'Menyimpan…' : 'Simpan' }}</button>
        </div>
      </div>

      <LembarLaporanGrup v-model="lembarWA" v-model:format="formatWA" judul="Laporan rapat ke grup WhatsApp" :teks="teksLaporan" :pilihan-format="FORMAT_WA" />
      <LembarRapat v-model="lembarUbah" :data="r" @selesai="muat" />

      <!-- Cetak: daftar hadir / notulen -->
      <DokumenCetak :judul="cetak === 'notulen' ? 'Notulen Rapat' : 'Daftar Hadir Rapat'" :subjudul="subjudul" v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap"
        :nama-berkas="namaBerkas(r.judul, cetak === 'notulen' ? 'Notulen Rapat' : 'Daftar Hadir Rapat', formatPanjang(r.tanggal))">
        <table class="identitas-rapat">
          <colgroup><col style="width:24%"><col style="width:3%"><col></colgroup>
          <tbody>
            <tr><td>Nama rapat</td><td>:</td><td>{{ r.judul }}</td></tr>
            <tr><td>Jenis rapat</td><td>:</td><td>{{ jenis.n }}{{ r.unit ? ' · ' + r.unit : '' }}</td></tr>
            <tr><td>Hari/tanggal</td><td>:</td><td>{{ formatHari(r.tanggal) }}</td></tr>
            <tr><td>Waktu</td><td>:</td><td>{{ jamRapat(r) ? jamRapat(r) + ' WITA' : '–' }}</td></tr>
            <tr><td>Tempat</td><td>:</td><td>{{ r.lokasi || '–' }}</td></tr>
            <tr><td>Pimpinan rapat</td><td>:</td><td>{{ r.pimpinan || '–' }}</td></tr>
            <tr><td>Notulis</td><td>:</td><td>{{ r.notulis || '–' }}</td></tr>
            <tr><td>Kehadiran</td><td>:</td><td>{{ S.hadir.length }} dari {{ S.n }} peserta ({{ S.persen }}%); izin/sakit/dinas luar {{ S.izin.length }}; tanpa keterangan {{ S.alpa.length }}</td></tr>
          </tbody>
        </table>
        <template v-if="cetak === 'hadir'">
          <table class="tabel" style="margin-top: 8pt">
            <colgroup><col style="width:6%"><col style="width:32%"><col style="width:30%"><col style="width:12%"><col style="width:20%"></colgroup>
            <thead><tr><th>No.</th><th>Nama</th><th>Jabatan/bidang</th><th>Kehadiran</th><th>Tanda tangan</th></tr></thead>
            <tbody><tr v-for="(p, i) in D.peserta" :key="p.employee_id" style="height: 9mm"><td class="tengah">{{ i + 1 }}</td><td>{{ p.nama }}</td><td>{{ [p.jabatan, p.unit].filter(Boolean).join(', ') || '–' }}</td>
              <td class="tengah">{{ p.kehadiran ? KEHADIRAN[p.kehadiran].n : '' }}</td><td :style="{ textAlign: i % 2 ? 'right' : 'left', verticalAlign: 'top', fontSize: '8pt' }">{{ i + 1 }}.</td></tr></tbody>
          </table>
        </template>
        <template v-else>
          <!-- eslint-disable vue/no-v-html -- teksKaya() meng-escape isi lebih dahulu -->
          <p class="sub-cetak">A. Pokok Pembahasan</p><p class="isi-cetak teks-kaya" v-html="r.pembahasan ? teksKaya(r.pembahasan) : '–'" />
          <p class="sub-cetak">B. Keputusan/Hasil Rapat</p><p class="isi-cetak teks-kaya" v-html="r.keputusan ? teksKaya(r.keputusan) : '–'" />
          <template v-if="(r.tindak_lanjut || []).length">
            <p class="sub-cetak">C. Tindak Lanjut</p>
            <table class="tabel"><colgroup><col style="width:6%"><col style="width:50%"><col style="width:26%"><col style="width:18%"></colgroup>
              <thead><tr><th>No.</th><th>Tugas</th><th>Penanggung jawab</th><th>Tenggat</th></tr></thead>
              <tbody><tr v-for="(t, i) in r.tindak_lanjut" :key="i"><td class="tengah">{{ i + 1 }}</td><td>{{ t.tugas }}</td><td>{{ t.pj || '–' }}</td><td class="tengah">{{ t.tenggat ? formatPanjang(t.tenggat) : '–' }}</td></tr></tbody></table>
          </template>
          <template v-if="r.catatan"><p class="sub-cetak">{{ (r.tindak_lanjut || []).length ? 'D' : 'C' }}. Catatan</p><p class="isi-cetak teks-kaya" v-html="teksKaya(r.catatan)" /></template>
          <!-- eslint-enable vue/no-v-html -->
        </template>
        <template #ttd><TandaTangan :kiri="ttdKiri" :kanan="ttdKanan" /></template>
      </DokumenCetak>
    </template>
    <p v-else class="kartu p-8 text-center text-sm text-teks3">Memuat rapat…</p>
    <NavUrutan v-if="D" class="mt-6" jenis="rapat" kembali="/rapat" label-kembali="Kembali ke Rapat" />
  </div>
</template>
<style scoped>
.kepala { background: linear-gradient(135deg, color-mix(in srgb, var(--c) 14%, rgb(var(--permukaan))), rgb(var(--permukaan)) 70%); }
</style>
<style>
.dok table.identitas-rapat { width: 100%; border-collapse: collapse; font-size: 10.5pt; margin-bottom: 4pt; }
.dok table.identitas-rapat td { padding: 1pt 2pt; vertical-align: top; border: 0; }
.dok .sub-cetak { margin: 8pt 0 3pt; font-weight: 700; font-size: 10.5pt; }
.dok .isi-cetak { white-space: pre-line; text-align: justify; font-size: 10.5pt; }
</style>
