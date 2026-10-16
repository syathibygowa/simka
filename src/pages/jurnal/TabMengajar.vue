<!-- SIMKA PRO | src/pages/jurnal/TabMengajar.vue | v2.1 | Perbaikan 13.8.0: laporan jurnal mengajar harian ke grup WhatsApp | 16/10/2026 -->
<script setup>
// Jurnal mengajar (sepaket dengan Jurnal Harian).
// v2.1: tombol "Lapor" per hari menyusun laporan jurnal mengajar hari itu (materi, metode, kehadiran santri) untuk grup WA bidang.
// v2.0:
//  * Tanpa memilih tanggal: langsung tampil semua pertemuan sepekan (Senin–Sabtu) sesuai jadwal mengajar; tanggal otomatis.
//    Jam berurutan dengan mapel dan kelas sama digabung menjadi satu pertemuan.
//  * Isian rinci tetapi ringan: Bab/materi pokok, sub-bab/pembahasan, metode, media (pilihan ketuk), catatan opsional.
//    Bab, metode, dan media otomatis terisi dari pertemuan sebelumnya; cukup ganti sub-bab.
//  * Absensi santri per pelajaran (bila diaktifkan): semua dianggap hadir; guru hanya menandai yang tidak hadir.
//    Santri yang sudah tercatat tidak hadir di absensi kelas harian (wali kelas), sakit, atau izin keluar ditandai otomatis.
//  * Batas pengisian mengikuti pengaturan (bawaan H+1); pengaturan dapat diubah superadmin/admin ber-izin Jadwal pelajaran.
import { ref, computed, onMounted } from 'vue'
import {
  PhChalkboardTeacher, PhCheckCircle, PhLightning, PhFloppyDisk, PhListNumbers, PhXCircle, PhClock, PhCaretLeft, PhCaretRight, PhLockSimple,
  PhGear, PhUsersThree, PhCaretDown, PhNotePencil, PhHourglass, PhWhatsappLogo,
} from '@phosphor-icons/vue'
import { useJadwal } from '@/stores/jadwal'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { blokMengajar, jamPendek } from '@/lib/jadwal'
import { hariIniISO, formatHari, formatPendek, HARI } from '@/lib/tanggal'
import LembarBawah from '@/components/LembarBawah.vue'
import LembarLaporanGrup from '@/components/LembarLaporanGrup.vue'
import { laporanMengajar } from '@/lib/laporanGrup'

const jd = useJadwal(); const sesi = useSesi(); const ui = useUI()
const hari = hariIniISO()
const geser = (iso, n) => { const d = new Date(`${iso}T12:00:00+08:00`); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10) }
const acuan = ref(hari); const pekan = ref([]); const memuat = ref(false)
const atur = computed(() => jd.aturJurnal || { batas_hari: 1, absen_santri: true, metode: [], media: [] })
async function muat() {
  memuat.value = true
  try { await jd.muatAturJurnal().catch(() => null); pekan.value = await jd.jadwalPekan(acuan.value) } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
onMounted(muat)
function pindahPekan(n) { acuan.value = n === 0 ? hari : geser(acuan.value, n * 7); muat() }
const pekanIni = computed(() => pekan.value.some((h) => h.tanggal === hari))
const labelPekan = computed(() => (pekan.value.length ? `${formatPendek(pekan.value[0].tanggal)} – ${formatPendek(pekan.value[pekan.value.length - 1].tanggal)}` : '…'))

// Pertemuan (blok jam berurutan) per hari
const STATUS = {
  terisi: { n: 'Terisi', w: 'presensi', i: PhCheckCircle }, tidak: { n: 'Tidak terlaksana', w: 'klinik', i: PhXCircle },
  belum: { n: 'Belum diisi', w: 'pengajuan', i: PhNotePencil }, nanti: { n: 'Akan datang', w: 'hakakses', i: PhHourglass },
  kunci: { n: 'Terkunci, belum diisi', w: 'klinik', i: PhLockSimple },
}
const statusBlok = (b, h) => {
  if (b.slot.every((s) => s.jurnal)) return b.jurnal?.status === 'tidak_terlaksana' ? 'tidak' : 'terisi'
  if (h.tanggal > hari) return 'nanti'
  return h.terbuka ? 'belum' : 'kunci'
}
const hariBlok = computed(() => pekan.value.map((h) => ({ ...h, nama: HARI[new Date(`${h.tanggal}T12:00:00+08:00`).getUTCDay()],
  blok: blokMengajar(h.slot || []).map((b) => ({ ...b, tanggal: h.tanggal, st: statusBlok(b, h) })) })))
const semuaBlok = computed(() => hariBlok.value.flatMap((h) => h.blok))
const ringkas = computed(() => { const x = semuaBlok.value.filter((b) => b.tanggal <= hari); return { isi: x.filter((b) => ['terisi', 'tidak'].includes(b.st)).length, n: x.length, belum: x.filter((b) => b.st === 'belum').length } })

// ---------- Lembar isian satu pertemuan ----------
const lembar = ref(false); const b = ref(null); const f = ref(null); const proses = ref(false)
const peserta = ref([]); const absen = ref({}); const bukaAbsen = ref(false); const memuatPeserta = ref(false)
const KODE = [['H', 'Hadir'], ['S', 'Sakit'], ['I', 'Izin'], ['A', 'Alfa'], ['B', 'Bolos'], ['T', 'Terlambat']]
const WARNA_KODE = { H: 'presensi', S: 'klinik', I: 'jadwal', A: 'pengajuan', B: 'klinik', T: 'agenda' }
async function buka(x) {
  b.value = x
  const j = x.jurnal; const t = x.terakhir || {}
  f.value = { status: j?.status || 'terlaksana', bab: j?.bab || (j ? j.materi || '' : t.bab || ''), subbab: j?.subbab || '', metode: [...(j?.metode?.length ? j.metode : t.metode || [])],
    media: [...(j?.media?.length ? j.media : t.media || [])], keterangan: j?.keterangan || '', plan_id: j?.plan_id || null }
  absen.value = { ...(j?.absen || {}) }; peserta.value = []; bukaAbsen.value = false; lembar.value = true
  if (atur.value.absen_santri && x.st !== 'nanti') {
    memuatPeserta.value = true
    try {
      peserta.value = await jd.peserta(x.assignment_id, x.tanggal)
      if (!j) for (const p of peserta.value) { const k = p.kode_kelas || (p.sakit ? 'S' : p.izin ? 'I' : null); if (k) absen.value[p.id] = k }
    } catch (e) { ui.toast(e.message, 'galat') } finally { memuatPeserta.value = false }
  }
}
const bisaIsi = computed(() => b.value && ['belum', 'terisi', 'tidak'].includes(b.value.st) && pekan.value.find((h) => h.tanggal === b.value.tanggal)?.terbuka)
const togel = (arr, v) => { const i = arr.indexOf(v); i >= 0 ? arr.splice(i, 1) : arr.push(v) }
const setKode = (id, k) => { const a = { ...absen.value }; if (k === 'H') delete a[id]; else a[id] = k; absen.value = a }
const tidakHadir = computed(() => peserta.value.filter((p) => absen.value[p.id] && absen.value[p.id] !== 'T'))
const saranBab = computed(() => [...new Set([b.value?.rencana?.topik, b.value?.terakhir?.bab].filter(Boolean))])
function sesuaiRencana() { Object.assign(f.value, { status: 'terlaksana', bab: b.value.rencana.topik, plan_id: b.value.rencana.id }) }
async function simpan() {
  const x = f.value
  if (x.status === 'terlaksana' && `${x.bab} ${x.subbab}`.trim().length < 3) return ui.toast('Isi bab atau materi pokok yang diajarkan.', 'galat')
  if (x.status === 'tidak_terlaksana' && x.keterangan.trim().length < 3) return ui.toast('Isi keterangan mengapa pelajaran tidak terlaksana.', 'galat')
  proses.value = true
  try {
    const pakaiAbsen = x.status === 'terlaksana' && atur.value.absen_santri && peserta.value.length > 0
    await jd.simpanJurnal(b.value.tanggal, b.value.slot.map((s) => ({ assignment_id: s.assignment_id, period_id: s.period_id, status: x.status, bab: x.bab.trim(), subbab: x.subbab.trim(),
      metode: x.metode, media: x.media, plan_id: x.plan_id, keterangan: x.keterangan.trim(), absen: pakaiAbsen ? absen.value : undefined,
      jumlah_anggota: pakaiAbsen ? peserta.value.length : undefined, jumlah_hadir: pakaiAbsen ? peserta.value.length - tidakHadir.value.length : undefined,
      materi: [x.bab.trim(), x.subbab.trim()].filter(Boolean).join(' – ') })))
    ui.toast(`Jurnal ${b.value.mapel} kelas ${b.value.kelas} tersimpan.`); lembar.value = false; await muat()
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}

// ---------- Rencana materi ----------
const lembarR = ref(false); const bR = ref(null); const teksRencana = ref('')
async function bukaRencana(x) {
  bR.value = x; const d = await jd.muatRencana(x.assignment_id)
  teksRencana.value = d.map((r) => r.topik).join('\n'); lembarR.value = true
}
async function simpanRencana() {
  const topik = teksRencana.value.split('\n').map((x) => x.trim()).filter((x) => x.length >= 2)
  try { const n = await jd.simpanRencana(bR.value.assignment_id, topik); ui.toast(`${n} topik rencana materi disimpan.`); lembarR.value = false; await muat() } catch (e) { ui.toast(e.message, 'galat') }
}

// ---------- Pengaturan (superadmin/admin ber-izin Jadwal pelajaran) ----------
const bolehAtur = computed(() => sesi.isSuperadmin || sesi.bolehAdmin('atur_jadwal'))
const lembarA = ref(false); const fa = ref(null)
function bukaAtur() { fa.value = { batas_hari: atur.value.batas_hari ?? 1, absen_santri: atur.value.absen_santri !== false, metode: (atur.value.metode || []).join('\n'), media: (atur.value.media || []).join('\n') }; lembarA.value = true }
async function simpanAtur() {
  const daftar = (t) => [...new Set(t.split('\n').map((x) => x.trim()).filter(Boolean))].slice(0, 20)
  try {
    await jd.simpanAturJurnal({ batas_hari: Number(fa.value.batas_hari), absen_santri: fa.value.absen_santri, metode: daftar(fa.value.metode), media: daftar(fa.value.media) })
    ui.toast('Pengaturan jurnal mengajar disimpan.'); lembarA.value = false; await muat()
  } catch (e) { ui.toast(e.message, 'galat') }
}
// ---------- Laporan harian ke grup WA ----------
const lembarGrup = ref(false); const teksLaporan = ref(''); const menyusun = ref('')
const adaJurnal = (h) => h.blok.some((x) => ['terisi', 'tidak'].includes(x.st))
async function laporHari(h) {
  menyusun.value = h.tanggal
  try {
    const blok = h.blok.filter((x) => ['terisi', 'tidak'].includes(x.st))
    const pertemuan = []
    for (const x of blok) {
      const j = x.jurnal || {}; const kode = Object.entries(j.absen || {}).filter(([, k]) => k && k !== 'H')
      let nama = {}
      if (kode.length) { try { nama = Object.fromEntries((await jd.peserta(x.assignment_id, x.tanggal)).map((p) => [p.id, p.nama])) } catch { /* nama tidak tersedia */ } }
      pertemuan.push({ mapel: x.mapel, kelas: x.kelas, jp: `${jpLabel(x)} (${x.slot.length} JP)`, jam: `${jamPendek(x.jam_mulai)}–${jamPendek(x.jam_selesai)}`,
        status: j.status, materi: j.materi || [j.bab, j.subbab].filter(Boolean).join(' – '), metode: j.metode, media: j.media, keterangan: j.keterangan,
        hadir: j.jumlah_hadir, jumlah: j.jumlah_anggota, tidakHadir: kode.map(([id, k]) => ({ nama: nama[id] || 'Santri', kode: k })) })
    }
    teksLaporan.value = laporanMengajar({ guru: sesi.pengguna?.nama_lengkap, tanggal: h.tanggal, pertemuan })
    lembarGrup.value = true
  } catch (e) { ui.toast(e.message, 'galat') } finally { menyusun.value = '' }
}
const jpLabel = (x) => (x.slot.length > 1 ? `${x.slot[0].jam_ke}–${x.slot[x.slot.length - 1].jam_ke.replace(/^Jam ke-?/, '')}` : x.jam_ke)
</script>
<template>
  <div>
    <!-- Pekan -->
    <div class="mb-4 flex flex-wrap items-center gap-2">
      <div class="flex items-center gap-1 rounded-2xl border border-garis bg-permukaan p-0.5" role="group" aria-label="Pilih pekan">
        <button class="tombol-ikon h-10 w-10" aria-label="Pekan sebelumnya" @click="pindahPekan(-1)"><PhCaretLeft :size="18" weight="bold" /></button>
        <span class="px-2 text-sm font-bold tabular-nums">{{ labelPekan }}</span>
        <button class="tombol-ikon h-10 w-10" aria-label="Pekan berikutnya" @click="pindahPekan(1)"><PhCaretRight :size="18" weight="bold" /></button>
      </div>
      <button v-if="!pekanIni" class="tombol-garis min-h-[40px] px-3 text-sm" @click="pindahPekan(0)">Pekan ini</button>
      <p class="min-w-[180px] flex-1 text-sm text-teks3">{{ ringkas.isi }}/{{ ringkas.n }} pertemuan terisi<template v-if="ringkas.belum"> · <b class="text-merah">{{ ringkas.belum }} belum diisi</b></template> · batas pengisian H+{{ atur.batas_hari }}</p>
      <button v-if="bolehAtur" class="tombol-garis min-h-[40px] px-3 text-sm" @click="bukaAtur"><PhGear :size="18" weight="duotone" /> Pengaturan jurnal</button>
    </div>

    <p v-if="memuat && !pekan.length" class="kartu py-10 text-center text-sm text-teks3">Memuat jadwal mengajar…</p>
    <div v-else class="space-y-4">
      <section v-for="h in hariBlok" :key="h.tanggal" :class="['kartu p-3 sm:p-4', h.tanggal === hari && 'ring-2 ring-[#1E7D4F]/40']">
        <h3 class="mb-2 flex flex-wrap items-center gap-2 px-1 text-sm font-bold">
          {{ h.nama }}, {{ formatPendek(h.tanggal) }}<span v-if="h.tanggal === hari" class="lencana w-presensi">Hari ini</span>
          <span class="ml-auto text-xs font-normal text-teks3">{{ h.libur ? 'Libur sekolah' : h.blok.length ? `${h.blok.length} pertemuan` : 'Tidak ada jadwal' }}</span>
          <button v-if="adaJurnal(h)" class="tombol-garis w-presensi h-9 min-h-0 px-3 text-xs" :disabled="menyusun === h.tanggal" :title="`Laporan jurnal ${h.nama} ke grup WhatsApp`" @click="laporHari(h)">
            <PhWhatsappLogo :size="16" weight="duotone" style="color: var(--c)" /> {{ menyusun === h.tanggal ? 'Menyusun…' : 'Lapor' }}</button>
        </h3>
        <ul v-if="h.blok.length" class="space-y-2">
          <li v-for="x in h.blok" :key="x.kunci">
            <button type="button" :class="['flex w-full items-center gap-3 rounded-xl border border-garis p-3 text-left transition hover:bg-permukaan2', 'w-' + STATUS[x.st].w]" @click="buka(x)">
              <span class="chip-ikon h-10 w-10 shrink-0"><PhChalkboardTeacher :size="22" weight="duotone" /></span>
              <span class="min-w-0 flex-1">
                <b class="block truncate">{{ x.mapel }} · Kelas {{ x.kelas }}</b>
                <span class="flex items-center gap-1 truncate text-xs text-teks3"><PhClock :size="13" class="shrink-0" /> {{ jamPendek(x.jam_mulai) }}–{{ jamPendek(x.jam_selesai) }} · {{ jpLabel(x) }} ({{ x.slot.length }} JP)<template v-if="x.jurnal?.materi"> · {{ x.jurnal.materi }}</template></span>
              </span>
              <span class="lencana shrink-0"><component :is="STATUS[x.st].i" :size="14" weight="fill" /> <span class="hidden sm:inline">{{ STATUS[x.st].n }}</span></span>
            </button>
          </li>
        </ul>
      </section>
      <p v-if="!memuat && !semuaBlok.length" class="kartu py-10 text-center text-sm text-teks3">Tidak ada jadwal mengajar pada pekan ini (libur sekolah atau belum ada jadwal pelajaran).</p>
    </div>

    <!-- Isian satu pertemuan -->
    <LembarBawah v-model="lembar" lebar :judul="b ? `${b.mapel} · Kelas ${b.kelas}` : ''">
      <div v-if="b && f" class="space-y-3 pb-2">
        <p class="flex flex-wrap items-center gap-2 text-sm text-teks2"><PhClock :size="16" /> {{ formatHari(b.tanggal) }} · {{ jpLabel(b) }} · {{ jamPendek(b.jam_mulai) }}–{{ jamPendek(b.jam_selesai) }} ({{ b.slot.length }} JP)
          <button class="tombol-teks ml-auto h-9 min-h-0 text-sm" @click="bukaRencana(b)"><PhListNumbers :size="16" /> Rencana materi</button></p>
        <p v-if="!bisaIsi" class="rounded-xl bg-permukaan2 p-3 text-sm text-teks2"><PhLockSimple :size="16" class="mr-1 inline" />
          {{ b.st === 'nanti' ? 'Pertemuan ini belum berlangsung; jurnal dapat diisi pada harinya.' : `Batas pengisian H+${atur.batas_hari} sudah lewat. Jurnal hanya dapat dilihat.` }}</p>

        <template v-if="bisaIsi">
          <button v-if="b.rencana && !b.jurnal" class="tombol-garis w-full justify-start text-left text-sm" @click="sesuaiRencana">
            <PhLightning :size="18" weight="duotone" class="shrink-0 text-[#B7791F]" /> Sesuai rencana: {{ b.rencana.topik }}</button>
          <div class="grid grid-cols-2 gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" aria-label="Status pertemuan">
            <button v-for="s in [{ k: 'terlaksana', n: 'Terlaksana' }, { k: 'tidak_terlaksana', n: 'Tidak terlaksana' }]" :key="s.k" type="button" role="radio"
              :aria-checked="f.status === s.k" @click="f.status = s.k"
              :class="['min-h-[42px] rounded-xl text-sm font-semibold', f.status === s.k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">{{ s.n }}</button>
          </div>

          <template v-if="f.status === 'terlaksana'">
            <div><label class="label-isian" for="jm-bab">Bab / materi pokok <span class="text-merah">*</span></label>
              <input id="jm-bab" v-model="f.bab" class="isian" list="jm-saran" placeholder="Contoh: Bab 2 Fungsi" @input="f.plan_id = null" />
              <datalist id="jm-saran"><option v-for="s in saranBab" :key="s" :value="s" /></datalist></div>
            <div><label class="label-isian" for="jm-sub">Sub-bab / pembahasan</label>
              <input id="jm-sub" v-model="f.subbab" class="isian" :placeholder="b.terakhir?.subbab ? `Sebelumnya: ${b.terakhir.subbab}` : 'Contoh: Fungsi kuadrat dan grafiknya'" /></div>
            <div>
              <p class="label-isian">Metode pembelajaran</p>
              <div class="flex flex-wrap gap-1.5">
                <button v-for="m in atur.metode" :key="m" type="button" :aria-pressed="f.metode.includes(m)" @click="togel(f.metode, m)"
                  :class="['min-h-[36px] rounded-full border px-3 text-sm', f.metode.includes(m) ? 'border-[#1E7D4F] bg-[#E2F1E8] font-semibold text-[#14583A] dark:bg-[#123524] dark:text-[#8FE0B5]' : 'border-garis text-teks2']">{{ m }}</button>
              </div>
            </div>
            <div>
              <p class="label-isian">Media pembelajaran (bila ada)</p>
              <div class="flex flex-wrap gap-1.5">
                <button v-for="m in atur.media" :key="m" type="button" :aria-pressed="f.media.includes(m)" @click="togel(f.media, m)"
                  :class="['min-h-[36px] rounded-full border px-3 text-sm', f.media.includes(m) ? 'border-[#2F5FA8] bg-[#E3ECF8] font-semibold text-[#1F4580] dark:bg-[#15253D] dark:text-[#A9C6F0]' : 'border-garis text-teks2']">{{ m }}</button>
              </div>
            </div>
            <!-- Kehadiran santri -->
            <div v-if="atur.absen_santri" class="rounded-2xl border border-garis">
              <button type="button" class="flex w-full items-center gap-2 p-3 text-left" :aria-expanded="bukaAbsen" @click="bukaAbsen = !bukaAbsen">
                <PhUsersThree :size="20" weight="duotone" class="shrink-0 text-[#127A7A]" />
                <span class="min-w-0 flex-1 text-sm"><b>Kehadiran santri</b>
                  <span class="block text-xs text-teks3">{{ memuatPeserta ? 'Memuat daftar santri…' : `Hadir ${peserta.length - tidakHadir.length}/${peserta.length}` }}{{ tidakHadir.length ? ' · tidak hadir: ' + tidakHadir.map((p) => p.nama.split(' ')[0] + ' (' + absen[p.id] + ')').join(', ') : ' · semua dianggap hadir' }}</span></span>
                <PhCaretDown :size="18" :class="['shrink-0 transition', bukaAbsen && 'rotate-180']" />
              </button>
              <ul v-if="bukaAbsen" class="max-h-[46vh] divide-y divide-garis overflow-y-auto border-t border-garis">
                <li v-for="(p, i) in peserta" :key="p.id" class="flex flex-wrap items-center gap-2 px-3 py-2">
                  <span class="min-w-0 flex-1 text-sm"><span class="tabular-nums text-teks3">{{ i + 1 }}.</span> {{ p.nama }} <span class="text-xs text-teks3">{{ p.jk }}</span>
                    <span v-if="p.kode_kelas || p.sakit || p.izin" class="block text-xs text-teks3">{{ p.kode_kelas ? 'Tercatat di absensi kelas harian' : p.sakit ? 'Sedang sakit (klinik)' : 'Izin keluar pondok' }}</span></span>
                  <span class="flex gap-0.5" role="radiogroup" :aria-label="`Kehadiran ${p.nama}`">
                    <button v-for="[k, n] in KODE" :key="k" type="button" role="radio" :aria-checked="(absen[p.id] || 'H') === k" :title="n" :aria-label="n" @click="setKode(p.id, k)"
                      :class="['h-8 w-8 rounded-lg text-xs font-bold', (absen[p.id] || 'H') === k ? 'w-' + WARNA_KODE[k] + ' chip-ikon' : 'text-teks3 hover:bg-permukaan2']">{{ k }}</button>
                  </span>
                </li>
                <li v-if="!memuatPeserta && !peserta.length" class="p-3 text-center text-sm text-teks3">Belum ada santri di kelas ini.</li>
              </ul>
            </div>
            <input v-model="f.keterangan" class="isian" placeholder="Catatan (opsional), mis. ulangan harian, tugas rumah" aria-label="Catatan" />
          </template>
          <input v-else v-model="f.keterangan" class="isian" placeholder="Alasan, mis. kegiatan pondok, digantikan, izin" aria-label="Keterangan tidak terlaksana" />
          <button class="tombol-utama w-full" :disabled="proses" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses ? 'Menyimpan…' : b.jurnal ? 'Perbarui jurnal' : 'Simpan jurnal' }}</button>
        </template>

        <dl v-else-if="b.jurnal" class="space-y-1 rounded-xl bg-permukaan2 p-3 text-sm">
          <div><dt class="inline font-semibold">Status: </dt><dd class="inline">{{ b.jurnal.status === 'tidak_terlaksana' ? 'Tidak terlaksana' : 'Terlaksana' }}</dd></div>
          <div v-if="b.jurnal.materi"><dt class="inline font-semibold">Materi: </dt><dd class="inline">{{ b.jurnal.materi }}</dd></div>
          <div v-if="b.jurnal.metode?.length"><dt class="inline font-semibold">Metode: </dt><dd class="inline">{{ b.jurnal.metode.join(', ') }}</dd></div>
          <div v-if="b.jurnal.media?.length"><dt class="inline font-semibold">Media: </dt><dd class="inline">{{ b.jurnal.media.join(', ') }}</dd></div>
          <div v-if="b.jurnal.jumlah_anggota != null"><dt class="inline font-semibold">Kehadiran: </dt><dd class="inline">{{ b.jurnal.jumlah_hadir }}/{{ b.jurnal.jumlah_anggota }} santri</dd></div>
          <div v-if="b.jurnal.keterangan"><dt class="inline font-semibold">Catatan: </dt><dd class="inline">{{ b.jurnal.keterangan }}</dd></div>
        </dl>
      </div>
    </LembarBawah>

    <LembarLaporanGrup v-model="lembarGrup" judul="Laporan jurnal mengajar ke grup WhatsApp" :teks="teksLaporan" />

    <LembarBawah v-model="lembarR" :judul="bR ? `Rencana materi ${bR.mapel} · ${bR.kelas}` : ''">
      <div class="space-y-3 pb-2">
        <p class="text-sm text-teks2">Tulis satu bab/topik per baris sesuai urutan. Saat mengisi jurnal, topik berikutnya muncul sebagai pilihan "Sesuai rencana".</p>
        <textarea v-model="teksRencana" class="isian min-h-[220px]" rows="10" placeholder="Bab 1: …&#10;Bab 2: …" aria-label="Daftar rencana materi" />
        <button class="tombol-utama w-full" @click="simpanRencana">Simpan rencana</button>
      </div>
    </LembarBawah>

    <LembarBawah v-model="lembarA" judul="Pengaturan jurnal mengajar">
      <div v-if="fa" class="space-y-3 pb-2">
        <div><label class="label-isian" for="ja-batas">Batas pengisian (hari setelah mengajar)</label>
          <select id="ja-batas" v-model.number="fa.batas_hari" class="isian"><option v-for="n in [0, 1, 2, 3, 6, 7, 14]" :key="n" :value="n">{{ n === 0 ? 'Hari itu saja' : `H+${n}` }}{{ n === 1 ? ' (bawaan, sama dengan Jurnal Harian)' : n === 6 ? ' (sepekan)' : '' }}</option></select></div>
        <label class="flex items-center gap-3 rounded-xl border border-garis p-3 text-sm"><input v-model="fa.absen_santri" type="checkbox" class="h-5 w-5 shrink-0 accent-[#1E7D4F]" />
          <span><b>Absensi santri oleh guru mapel</b><span class="block text-xs text-teks3">Guru menandai santri yang tidak hadir pada pelajarannya; tersimpan di baris jurnal (tanpa tabel tambahan).</span></span></label>
        <div><label class="label-isian" for="ja-metode">Pilihan metode (satu per baris)</label><textarea id="ja-metode" v-model="fa.metode" class="isian" rows="5" /></div>
        <div><label class="label-isian" for="ja-media">Pilihan media (satu per baris)</label><textarea id="ja-media" v-model="fa.media" class="isian" rows="5" /></div>
        <button class="tombol-utama w-full" @click="simpanAtur"><PhFloppyDisk :size="20" weight="duotone" /> Simpan pengaturan</button>
      </div>
    </LembarBawah>
  </div>
</template>
