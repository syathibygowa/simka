<!-- SIMKA PRO | src/pages/presensi/DataPresensi.vue | v1.0 | Fase 3 – Menu Data Presensi (harian per bidang dan bulanan) | 12/10/2026 -->
<script setup>
// Data Presensi (admin ber-izin verval_presensi dan superadmin), dipisah dari tab Verval Presensi:
//   Harian  : semua pegawai satu bidang (beserta cabangnya) pada satu tanggal, tombol sebelum/sesudah, saring status,
//             ketuk pegawai → rincian sesi: riwayat, ajukan koreksi (admin), ubah langsung/catat manual (superadmin).
//   Bulanan : matriks nama × tanggal satu bulan (tombol bulan sebelum/sesudah); ketuk nama → kalender kehadiran
//             pegawai itu; ketuk sel/tanggal → rincian hari itu untuk diubah.
//   Cetak F4: daftar presensi harian (tegak) dan rekap matriks bulanan (mendatar).
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { PhCalendarCheck, PhCalendarDots, PhCaretLeft, PhCaretRight, PhMagnifyingGlass, PhPrinter, PhInfo, PhArrowClockwise,
  PhClockCounterClockwise, PhPencilSimple, PhPlus, PhUsersThree, PhCheckCircle, PhClock, PhFirstAid, PhXCircle, PhHourglass } from '@phosphor-icons/vue'
import { useVerval } from '@/stores/verval'
import { usePegawai } from '@/stores/pegawai'
import { useOrganisasi } from '@/stores/organisasi'
import { useAturPresensi } from '@/stores/aturPresensi'
import { useLembaga } from '@/stores/lembaga'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { useLaporanKehadiran } from '@/stores/laporanKehadiran'
import { BULAN, HARI, formatHari, formatPendek, formatJam, formatWaktu, hariIniISO } from '@/lib/tanggal'
import { STATUS_PRESENSI, STATUS_PULANG, lencanaSesi } from '@/lib/presensi'
import { STATUS_HADIR, daftarTanggal, tambahHari, persenTeks } from '@/lib/laporanKehadiran'
import BilahTab from '@/components/BilahTab.vue'
import KartuStatistik from '@/components/KartuStatistik.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import LembarKeputusan from '@/pages/verval/LembarKeputusan.vue'

const props = defineProps({ tab: { type: String, default: 'harian' } })
const router = useRouter(); const route = useRoute()
const vv = useVerval(); const peg = usePegawai(); const org = useOrganisasi(); const atur = useAturPresensi(); const lembaga = useLembaga(); const sesi = useSesi(); const ui = useUI()
const TAB = [{ k: 'harian', n: 'Harian', ikon: PhCalendarCheck, w: 'presensi' }, { k: 'bulanan', n: 'Bulanan', ikon: PhCalendarDots, w: 'agenda' }]
const aktif = computed({ get: () => (TAB.some((t) => t.k === props.tab) ? props.tab : 'harian'), set: (k) => router.replace({ path: `/data-presensi/${k}`, query: route.query }) })
const boleh = computed(() => atur.boleh('verval_presensi'))
const siap = ref(false); const galat = ref('')

// ---------- Saringan bersama: bidang + pencarian ----------
const SIMPAN = 'simka.dataPresensi.unit'
const baca = () => { try { return localStorage.getItem(SIMPAN) || '' } catch { return '' } }
const unit = ref(String(route.query.unit || baca())); const cari = ref('')
watch(unit, (v) => { try { localStorage.setItem(SIMPAN, v) } catch { /* abaikan */ } })
const namaUnit = computed(() => (unit.value ? org.cariUnit(unit.value)?.nama || 'Bidang' : 'Seluruh bidang'))
const cocok = (p) => { const q = cari.value.toLowerCase().trim(); return !q || [p.nama, p.niy, p.jabatan].join(' ').toLowerCase().includes(q) }

onMounted(async () => {
  try { await Promise.all([atur.muat(), org.muat(), peg.daftar.length ? null : peg.muat(), lembaga.muat()]) } catch (e) { galat.value = e.message }
  siap.value = true
  if (boleh.value) { aktif.value === 'harian' ? muatH() : muatB() }
  if (route.query.emp && route.query.tanggal) bukaRinci(String(route.query.emp), String(route.query.tanggal))
})

// ---------- Harian ----------
const tgl = ref(String(route.query.tanggal || hariIniISO())); const hari = ref(null); const memuatH = ref(false); const saring = ref('semua')
async function muatH() {
  if (!boleh.value || !tgl.value) return
  memuatH.value = true
  try { hari.value = await vv.hariSemua(tgl.value, unit.value || null) } catch (e) { ui.toast(e.message, 'galat') } finally { memuatH.value = false }
}
const geserHari = (n) => { tgl.value = tambahHari(tgl.value, n) }
/** Keadaan pegawai pada hari itu: status terburuk dari sesi tercatat; sesi wajib terlewat tanpa data = tanpa keterangan */
function keadaanHari(p) {
  const wajib = p.sesi.filter((s) => s.status || !s.opsional)
  if (!wajib.length) return 'libur'
  let k = null
  for (const s of wajib) {
    const st = s.status || (s.keadaan === 'terlewat' ? 'tanpa_keterangan' : null)
    if (st && (!k || (STATUS_HADIR[st]?.b ?? 0) > (STATUS_HADIR[k]?.b ?? 0))) k = st
  }
  return k || 'belum'
}
const KELOMPOK = {
  semua: { n: 'Semua' }, hadir: { n: 'Hadir', s: ['hadir', 'dinas_luar'] }, terlambat: { n: 'Terlambat', s: ['terlambat'] },
  izin: { n: 'Izin/sakit/cuti', s: ['izin', 'sakit', 'cuti'] }, tanpa: { n: 'Tanpa keterangan', s: ['tanpa_keterangan'] },
  menunggu: { n: 'Menunggu verval', s: ['menunggu_verval'] }, belum: { n: 'Belum presensi', s: ['belum'] }, libur: { n: 'Tanpa jadwal', s: ['libur'] },
}
const barisH = computed(() => (hari.value?.pegawai || []).map((p) => ({ ...p, k: keadaanHari(p) })))
const hitungH = computed(() => { const h = {}; for (const [k, v] of Object.entries(KELOMPOK)) h[k] = k === 'semua' ? barisH.value.length : barisH.value.filter((p) => v.s.includes(p.k)).length; return h })
const tampilH = computed(() => barisH.value.filter((p) => cocok(p) && (saring.value === 'semua' || KELOMPOK[saring.value].s.includes(p.k))))
const lencanaHari = (k) => (k === 'belum' ? { n: 'Belum presensi', w: 'hakakses' } : k === 'libur' ? { n: 'Tanpa jadwal', w: 'hakakses' } : { n: STATUS_HADIR[k]?.n || k, w: STATUS_HADIR[k]?.w || 'hakakses' })

// ---------- Bulanan ----------
const bulan = ref(String(route.query.bulan || hariIniISO().slice(0, 7))); const rekap = ref(null); const memuatB = ref(false)
const tanggalBulan = computed(() => { const [y, m] = bulan.value.split('-').map(Number); return daftarTanggal(`${bulan.value}-01`, `${bulan.value}-${String(new Date(Date.UTC(y, m, 0)).getUTCDate()).padStart(2, '0')}`) })
const judulBulan = computed(() => { const [y, m] = bulan.value.split('-').map(Number); return `${BULAN[m - 1]} ${y}` })
function geserBulan(n) { const [y, m] = bulan.value.split('-').map(Number); const d = new Date(Date.UTC(y, m - 1 + n, 1)); bulan.value = d.toISOString().slice(0, 7) }
async function muatB() {
  if (!boleh.value) return
  memuatB.value = true
  const t = tanggalBulan.value; const isi = { mulai: t[0], selesai: t[t.length - 1], cakupan: unit.value ? 'bidang' : 'semua', nilai: unit.value || null, rinci: true }
  try {
    if (MODE_DEMO) rekap.value = await useLaporanKehadiran().muat({ ...isi, selesai: isi.selesai < hariIniISO() ? isi.selesai : hariIniISO() })
    else {
      const { data, error } = await supabase.rpc('laporan_kehadiran_pegawai', { p_mulai: isi.mulai, p_selesai: isi.selesai, p_cakupan: isi.cakupan, p_nilai: isi.nilai, p_rinci: true })
      if (error) throw new Error(error.message); rekap.value = data
    }
  } catch (e) { ui.toast(e.message, 'galat') } finally { memuatB.value = false }
}
/** sel[emp][tanggal] = { k: status terburuk, sesi: [...] } */
const sel = computed(() => {
  const m = {}
  for (const r of rekap.value?.rinci || []) {
    const b = ((m[r.employee_id] ||= {})[r.tanggal] ||= { k: null, sesi: [] }); b.sesi.push(r)
    if (STATUS_HADIR[r.status] && (!b.k || STATUS_HADIR[b.k].b < STATUS_HADIR[r.status].b)) b.k = r.status
  }
  return m
})
const tampilB = computed(() => (rekap.value?.pegawai || []).filter(cocok))
const minggu = (t) => new Date(t + 'T00:00:00Z').getUTCDay() === 0
const judulSel = (p, t) => { const c = sel.value[p.employee_id]?.[t]; return `${p.nama} · ${formatHari(t)}` + (c ? ': ' + c.sesi.map((s) => `${s.nama_sesi} ${STATUS_HADIR[s.status]?.n || s.status}`).join('; ') : '') }

// Kalender satu pegawai (dibuka dari nama pada matriks)
const kalender = ref(null)
const selKalender = computed(() => {
  if (!kalender.value) return []
  const t = tanggalBulan.value; const awal = new Date(t[0] + 'T00:00:00Z').getUTCDay()
  return [...Array(awal).fill(null), ...t]
})

function dariKalender(t) { const emp = kalender.value.employee_id; kalender.value = null; bukaRinci(emp, t) }

watch([tgl, unit], () => aktif.value === 'harian' && muatH())
watch([bulan, unit], () => aktif.value === 'bulanan' && muatB())
watch(aktif, (k) => { if (!boleh.value) return; if (k === 'harian' && hari.value?.tanggal !== tgl.value) muatH(); if (k === 'bulanan' && !rekap.value) muatB() })
watch(boleh, (v) => v && siap.value && (aktif.value === 'harian' ? muatH() : muatB()))

// ---------- Rincian satu pegawai satu hari (ubah presensi) ----------
const rinci = ref(null) // { emp, nama, tanggal, sesi, memuat }
async function bukaRinci(emp, tanggal) {
  const p = peg.cari(emp)
  rinci.value = { emp, nama: p?.nama_lengkap || barisH.value.find((x) => x.employee_id === emp)?.nama || '', niy: p?.niy, tanggal, sesi: [], memuat: true }
  await muatRinci()
}
async function muatRinci() {
  const r = rinci.value; if (!r) return
  r.memuat = true
  try { r.sesi = (await vv.harianPegawai(r.emp, r.tanggal)).sesi || [] } catch (e) { ui.toast(e.message, 'galat') } finally { r.memuat = false }
}
const geserRinci = (n) => { rinci.value.tanggal = tambahHari(rinci.value.tanggal, n); muatRinci() }
async function segarkan() { await muatRinci(); if (aktif.value === 'harian') muatH(); else muatB() }

const P = (k) => ({ k, n: STATUS_PRESENSI[k].n, w: STATUS_PRESENSI[k].w })
const PILIH_SEMUA = ['hadir', 'terlambat', 'dinas_luar', 'izin', 'sakit', 'cuti', 'tanpa_keterangan'].map(P)
const PILIH_PULANG = ['tepat', 'cepat', 'tidak_presensi'].map((k) => ({ k, n: STATUS_PULANG[k].n, w: STATUS_PULANG[k].w }))
const lk = ref({ buka: false })
const bukaLembar = (o) => { lk.value = { buka: true, ...o } }
async function kirimKeputusan(isi, res, rej) { try { await lk.value.aksi(isi); ui.toast(lk.value.pesan || 'Tersimpan.'); res(); segarkan() } catch (e) { rej(e) } }
const ringkas = (s, akhir) => `${rinci.value.nama} · ${s.nama_sesi} ${formatPendek(s.tanggal)} · ${akhir}`
function koreksiS(s) {
  bukaLembar({ judul: 'Ajukan koreksi', ringkasan: ringkas(s, 'sekarang ' + lencanaSesi(s).n), pilihan: PILIH_SEMUA, bawaan: s.status, pilihanPulang: s.wajib_pulang ? PILIH_PULANG : null,
    labelTombol: 'Kirim ke superadmin', catatan: 'Koreksi berlaku setelah disetujui superadmin.', pesan: 'Permintaan koreksi terkirim ke superadmin.',
    aksi: ({ status, pulang, alasan }) => vv.ajukanKoreksi(s.attendance_id, status, pulang, alasan) })
}
function ubahS(s) {
  bukaLembar({ judul: 'Ubah langsung (superadmin)', ringkasan: ringkas(s, 'sekarang ' + lencanaSesi(s).n), pilihan: PILIH_SEMUA, bawaan: s.status, pilihanPulang: s.wajib_pulang ? PILIH_PULANG : null,
    labelTombol: 'Simpan perubahan', pesan: 'Presensi diubah dan tercatat di riwayat.', aksi: ({ status, pulang, alasan }) => vv.ubah(s.attendance_id, status, pulang, alasan) })
}
function manualS(s) {
  bukaLembar({ judul: 'Catat manual (superadmin)', ringkasan: ringkas(s, 'belum ada data'), pilihan: PILIH_SEMUA, bawaan: 'hadir', labelTombol: 'Catat presensi', pesan: 'Presensi dicatat manual.',
    aksi: ({ status, alasan }) => vv.catatManual(rinci.value.emp, s.tanggal, s.session_id, status, alasan) })
}
const riwayat = ref(null)
async function lihatRiwayat(s) { try { riwayat.value = { s, isi: await vv.riwayat(s.attendance_id) } } catch (e) { ui.toast(e.message, 'galat') } }
const JENIS_RIWAYAT = { presensi: 'Presensi', penutupan: 'Penutupan otomatis', verval: 'Verval admin', koreksi: 'Koreksi disetujui', superadmin: 'Diubah superadmin', pengajuan: 'Pengajuan pegawai', sistem: 'Sistem' }

// ---------- Cetak ----------
const pratinjau = ref(false)
const direktur = computed(() => lembaga.signatories.find((s) => s.sumber_jabatan === 'DIREKTUR' || /^direktur/i.test(s.jabatan_tertulis)) || {})
const JK = { L: 'L', P: 'P' }
const barisCetakH = computed(() => tampilH.value.flatMap((p) => {
  const ss = p.sesi.filter((s) => s.status || !s.opsional)
  return (ss.length ? ss : [null]).map((s, i) => ({ p, s, awal: i === 0, rentang: Math.max(ss.length, 1) }))
}))
const jamTeks = (v) => (v ? formatJam(v) : '–')
const ringkasB = (p) => ['hadir', 'terlambat', 'dinas_luar', 'izin', 'sakit', 'cuti', 'tanpa_keterangan'].map((k) => p[k] || 0)
</script>
<template>
  <div class="w-datapresensi space-y-4">
    <BilahTab v-model="aktif" :tab="TAB" label="Tampilan data presensi" />

    <p v-if="galat" class="rounded-xl bg-[#C7332F]/10 p-3 text-sm font-semibold text-merah">{{ galat }}</p>
    <div v-else-if="siap && !boleh" class="flex gap-2 rounded-xl bg-permukaan2 p-4 text-sm text-teks2"><PhInfo :size="20" class="shrink-0" />
      Menu ini memerlukan izin "Verval presensi di luar area dan permintaan koreksi" dari superadmin (Verifikasi Akun → peran admin).</div>
    <p v-else-if="!siap" class="py-10 text-center text-teks3">Memuat…</p>

    <template v-else>
      <!-- Bilah saringan -->
      <div class="kartu grid gap-3 p-3 sm:grid-cols-2 lg:grid-cols-[minmax(12rem,16rem)_auto_1fr_auto] lg:items-end">
        <div><label class="label-isian" for="dp-unit">Bidang</label>
          <select id="dp-unit" v-model="unit" class="isian"><option value="">Seluruh bidang</option>
            <option v-for="u in org.datar" :key="u.id" :value="u.id">{{ ' '.repeat(u.tingkat) }}{{ u.nama }}</option></select></div>
        <div v-if="aktif === 'harian'" class="flex items-end gap-1.5">
          <button class="tombol-garis h-12 w-12 shrink-0 px-0" aria-label="Hari sebelumnya" title="Hari sebelumnya" @click="geserHari(-1)"><PhCaretLeft :size="20" weight="bold" /></button>
          <div class="w-40"><InputTanggal v-model="tgl" label="Tanggal" /></div>
          <button class="tombol-garis h-12 w-12 shrink-0 px-0" aria-label="Hari berikutnya" title="Hari berikutnya" @click="geserHari(1)"><PhCaretRight :size="20" weight="bold" /></button>
          <button v-if="tgl !== hariIniISO()" class="tombol-teks h-12 shrink-0 px-2 text-sm" @click="tgl = hariIniISO()">Hari ini</button>
        </div>
        <div v-else class="flex items-end gap-1.5">
          <button class="tombol-garis h-12 w-12 shrink-0 px-0" aria-label="Bulan sebelumnya" title="Bulan sebelumnya" @click="geserBulan(-1)"><PhCaretLeft :size="20" weight="bold" /></button>
          <div><span class="label-isian">Bulan</span><p class="isian flex w-44 items-center justify-center font-bold">{{ judulBulan }}</p></div>
          <button class="tombol-garis h-12 w-12 shrink-0 px-0" aria-label="Bulan berikutnya" title="Bulan berikutnya" @click="geserBulan(1)"><PhCaretRight :size="20" weight="bold" /></button>
          <button v-if="bulan !== hariIniISO().slice(0, 7)" class="tombol-teks h-12 shrink-0 px-2 text-sm" @click="bulan = hariIniISO().slice(0, 7)">Bulan ini</button>
        </div>
        <div class="relative sm:col-span-2 lg:col-span-1"><label class="label-isian" for="dp-cari">Cari pegawai</label>
          <PhMagnifyingGlass :size="20" class="pointer-events-none absolute bottom-3.5 left-3 text-teks3" />
          <input id="dp-cari" v-model="cari" type="search" class="isian pl-10" placeholder="Nama, NIY, atau jabatan" /></div>
        <div class="flex gap-2 sm:col-span-2 lg:col-span-1">
          <button class="tombol-garis h-12 flex-1 lg:flex-none" :disabled="memuatH || memuatB" @click="aktif === 'harian' ? muatH() : muatB()"><PhArrowClockwise :size="18" /> <span class="lg:sr-only">Muat ulang</span></button>
          <button class="tombol-utama h-12 flex-1 lg:flex-none" :disabled="aktif === 'harian' ? !tampilH.length : !tampilB.length" @click="pratinjau = true"><PhPrinter :size="18" weight="duotone" /> Cetak</button>
        </div>
      </div>

      <!-- ===== Harian ===== -->
      <template v-if="aktif === 'harian'">
        <div class="grid grid-cols-2 gap-3 lg:grid-cols-5">
          <KartuStatistik judul="Pegawai" :nilai="hitungH.semua" :ikon="PhUsersThree" warna="pegawai" :keterangan="namaUnit" />
          <KartuStatistik judul="Hadir" :nilai="hitungH.hadir" :ikon="PhCheckCircle" warna="presensi" keterangan="Termasuk dinas luar" />
          <KartuStatistik judul="Terlambat" :nilai="hitungH.terlambat" :ikon="PhClock" warna="tahfizh" />
          <KartuStatistik judul="Izin/sakit/cuti" :nilai="hitungH.izin" :ikon="PhFirstAid" warna="klinik" />
          <KartuStatistik judul="Tanpa keterangan" :nilai="hitungH.tanpa" :ikon="PhXCircle" warna="beranda" :keterangan="hitungH.belum ? `${hitungH.belum} belum presensi` : 'Sesi wajib terlewat'" />
        </div>
        <div class="-mx-4 flex gap-2 overflow-x-auto px-4 pb-1 lg:mx-0 lg:flex-wrap lg:px-0" role="radiogroup" aria-label="Saring menurut keadaan">
          <button v-for="(v, k) in KELOMPOK" :key="k" type="button" role="radio" :aria-checked="saring === k" @click="saring = k"
            :class="['min-h-[40px] shrink-0 rounded-full border px-3 text-sm font-semibold', saring === k ? 'border-transparent bg-[var(--c)] text-white dark:text-[#0B1414]' : 'border-garis bg-permukaan text-teks2']">
            {{ v.n }} <span class="tabular-nums opacity-80">{{ hitungH[k] }}</span></button>
        </div>
        <p class="text-sm font-bold">{{ formatHari(tgl) }} · {{ namaUnit }}</p>
        <p v-if="memuatH && !hari" class="py-10 text-center text-teks3">Memuat data presensi…</p>
        <p v-else-if="!tampilH.length" class="py-10 text-center text-teks3">Tidak ada pegawai yang cocok.</p>
        <ul :class="['grid gap-2 xl:grid-cols-2', memuatH && 'opacity-60']">
          <li v-for="p in tampilH" :key="p.employee_id">
            <button type="button" class="kartu flex w-full items-start gap-3 p-3 text-left hover:shadow-apung" @click="bukaRinci(p.employee_id, tgl)">
              <span :class="['grid h-10 w-10 shrink-0 place-items-center rounded-xl text-sm font-extrabold', 'w-' + lencanaHari(p.k).w]"
                style="background: color-mix(in srgb, var(--c) 14%, transparent); color: var(--c)">{{ STATUS_HADIR[p.k]?.s || (p.k === 'belum' ? '…' : '–') }}</span>
              <span class="min-w-0 flex-1">
                <span class="block font-bold">{{ p.nama }}</span>
                <span class="block truncate text-xs text-teks3">{{ [p.niy, p.unit, p.jabatan].filter(Boolean).join(' · ') }}</span>
                <span class="mt-1.5 flex flex-wrap gap-1">
                  <span v-for="s in p.sesi" :key="s.session_id + s.tanggal" :class="['lencana', 'w-' + lencanaSesi(s).w]">
                    {{ formatJam(s.mulai) }} {{ s.nama_sesi }} · {{ lencanaSesi(s).n }}{{ s.terlambat_menit && s.status === 'terlambat' ? ` ${s.terlambat_menit} mnt` : '' }}</span>
                  <span v-if="!p.sesi.length" class="text-xs text-teks3">Tidak ada sesi pada tanggal ini.</span>
                </span>
              </span>
              <PhPencilSimple :size="18" class="mt-1 shrink-0 text-teks3" aria-hidden="true" />
            </button>
          </li>
        </ul>
      </template>

      <!-- ===== Bulanan ===== -->
      <template v-else>
        <div class="flex flex-wrap gap-1.5 text-xs" aria-label="Keterangan kode">
          <span v-for="(v, k) in STATUS_HADIR" :key="k" :class="['lencana', 'w-' + v.w]"><b>{{ v.s }}</b> {{ v.n }}</span>
        </div>
        <p v-if="memuatB && !rekap" class="py-10 text-center text-teks3">Memuat rekap bulanan…</p>
        <p v-else-if="!tampilB.length" class="py-10 text-center text-teks3">Tidak ada pegawai yang cocok.</p>
        <div v-else :class="['kartu overflow-x-auto', memuatB && 'opacity-60']">
          <table class="matriks text-sm">
            <thead><tr>
              <th class="kiri sticky left-0 z-10 bg-permukaan">Pegawai</th>
              <th v-for="t in tanggalBulan" :key="t" :class="minggu(t) && 'libur'" :title="formatHari(t)">{{ Number(t.slice(8)) }}<span class="block text-[10px] font-normal text-teks3">{{ HARI[new Date(t + 'T00:00:00Z').getUTCDay()].slice(0, 2) }}</span></th>
              <th class="ringkas">Hadir</th><th class="ringkas">%</th>
            </tr></thead>
            <tbody>
              <tr v-for="p in tampilB" :key="p.employee_id">
                <th class="kiri sticky left-0 z-10 bg-permukaan"><button type="button" class="block max-w-[11rem] truncate text-left font-semibold underline-offset-2 hover:underline sm:max-w-[16rem]" @click="kalender = p" :title="`Kalender kehadiran ${p.nama}`">{{ p.nama }}</button>
                  <span class="block text-[11px] font-normal text-teks3">{{ p.niy || '–' }}</span></th>
                <td v-for="t in tanggalBulan" :key="t" :class="minggu(t) && 'libur'">
                  <button v-if="sel[p.employee_id]?.[t]" type="button" :class="['kode', 'w-' + (STATUS_HADIR[sel[p.employee_id][t].k]?.w || 'hakakses')]" :title="judulSel(p, t)" @click="bukaRinci(p.employee_id, t)">
                    {{ STATUS_HADIR[sel[p.employee_id][t].k]?.s || '·' }}</button>
                  <button v-else-if="t <= hariIniISO()" type="button" class="kode kosong" :title="`${p.nama} · ${formatHari(t)}: tidak ada sesi tercatat`" @click="bukaRinci(p.employee_id, t)">·</button>
                </td>
                <td class="ringkas tabular-nums">{{ p.total_hadir }}/{{ p.sesi_wajib }}</td>
                <td class="ringkas font-bold tabular-nums">{{ persenTeks(p.persen) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <p class="text-xs text-teks3">Ketuk nama untuk melihat kalender kehadiran pegawai; ketuk kode tanggal untuk membuka rincian dan mengubah presensi. Sesi hari ini yang belum ditutup belum terhitung.</p>
      </template>
    </template>

    <!-- Kalender satu pegawai -->
    <LembarBawah :model-value="!!kalender" @update:model-value="(v) => !v && (kalender = null)" :judul="kalender ? `${kalender.nama} · ${judulBulan}` : ''">
      <div v-if="kalender" class="space-y-4 pb-2">
        <div class="grid grid-cols-4 gap-2 text-center sm:grid-cols-8">
          <div v-for="(n, i) in ringkasB(kalender)" :key="i" :class="['rounded-xl p-2', 'w-' + Object.values(STATUS_HADIR)[[0, 2, 1, 4, 5, 3, 7][i]].w]" style="background: color-mix(in srgb, var(--c) 12%, transparent)">
            <p class="text-lg font-extrabold tabular-nums" style="color: var(--c)">{{ n }}</p>
            <p class="text-[11px] leading-tight text-teks2">{{ ['Hadir', 'Terlambat', 'Dinas luar', 'Izin', 'Sakit', 'Cuti', 'Tanpa ket.'][i] }}</p></div>
          <div class="rounded-xl bg-permukaan2 p-2"><p class="text-lg font-extrabold tabular-nums">{{ persenTeks(kalender.persen) }}</p><p class="text-[11px] text-teks2">Kehadiran</p></div>
        </div>
        <div class="grid grid-cols-7 gap-1 text-center text-xs">
          <span v-for="h in ['Ahd', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab']" :key="h" class="py-1 font-bold text-teks3">{{ h }}</span>
          <template v-for="(t, i) in selKalender" :key="i">
            <span v-if="!t" />
            <button v-else type="button" :disabled="t > hariIniISO()" @click="dariKalender(t)"
              :class="['hari-kal', sel[kalender?.employee_id]?.[t] ? 'w-' + (STATUS_HADIR[sel[kalender.employee_id][t].k]?.w || 'hakakses') : '', minggu(t) && 'libur', t === hariIniISO() && 'kini']"
              :title="judulSel(kalender, t)">
              <span class="font-bold">{{ Number(t.slice(8)) }}</span>
              <span class="kd">{{ STATUS_HADIR[sel[kalender.employee_id]?.[t]?.k]?.s || '' }}</span>
            </button>
          </template>
        </div>
        <ul class="space-y-1 text-sm">
          <template v-for="t in tanggalBulan" :key="t">
            <li v-for="s in (sel[kalender.employee_id]?.[t]?.sesi || []).filter((x) => x.status !== 'hadir')" :key="t + s.nama_sesi + s.mulai" class="flex gap-2">
              <span class="w-24 shrink-0 tabular-nums text-teks3">{{ formatPendek(t) }}</span>
              <span>{{ s.nama_sesi }}: <b>{{ STATUS_HADIR[s.status]?.n }}</b>{{ (s.terlambat_menit ? ` ${s.terlambat_menit} menit` : '') + (s.keterangan ? ` · ${s.keterangan}` : '') }}</span>
            </li>
          </template>
        </ul>
      </div>
    </LembarBawah>

    <!-- Rincian satu pegawai satu hari -->
    <LembarBawah :model-value="!!rinci" @update:model-value="(v) => !v && (rinci = null)" :judul="rinci ? rinci.nama : ''">
      <div v-if="rinci" class="space-y-3 pb-2">
        <div class="flex items-center gap-2">
          <button class="tombol-garis h-11 w-11 shrink-0 px-0" aria-label="Hari sebelumnya" @click="geserRinci(-1)"><PhCaretLeft :size="20" weight="bold" /></button>
          <p class="flex-1 text-center font-bold">{{ formatHari(rinci.tanggal) }}</p>
          <button class="tombol-garis h-11 w-11 shrink-0 px-0" aria-label="Hari berikutnya" @click="geserRinci(1)"><PhCaretRight :size="20" weight="bold" /></button>
        </div>
        <p v-if="rinci.memuat" class="py-6 text-center text-teks3"><PhHourglass :size="20" class="inline" /> Memuat…</p>
        <p v-else-if="!rinci.sesi.length" class="py-6 text-center text-teks3">Tidak ada sesi pada tanggal ini.</p>
        <ul v-else class="space-y-2">
          <li v-for="s in rinci.sesi" :key="s.session_id + s.tanggal" :class="['rounded-2xl border border-garis p-3', 'w-' + lencanaSesi(s).w]">
            <div class="flex flex-wrap items-center gap-2">
              <span class="w-24 font-bold tabular-nums">{{ formatJam(s.mulai) }}–{{ formatJam(s.selesai) }}</span>
              <span class="flex-1 font-semibold">{{ s.nama_sesi }} <span class="text-xs font-normal text-teks3">· {{ s.nama_pola }}</span></span>
              <span class="lencana">{{ lencanaSesi(s).n }}</span>
              <span v-if="s.status_pulang && s.status_pulang !== 'belum'" :class="['lencana', 'w-' + STATUS_PULANG[s.status_pulang].w]">{{ STATUS_PULANG[s.status_pulang].n }}</span>
            </div>
            <p v-if="s.datang_pada || s.keterangan || s.terlambat_menit" class="mt-1 text-xs text-teks3">
              {{ [s.datang_pada && `Datang ${formatJam(s.datang_pada)}` + (s.terlambat_menit ? ` (terlambat ${s.terlambat_menit} menit)` : ''), s.pulang_pada && `Pulang ${formatJam(s.pulang_pada)}`, s.keterangan].filter(Boolean).join(' · ') }}</p>
            <div class="mt-1.5 flex flex-wrap gap-1">
              <button v-if="s.attendance_id" class="tombol-teks min-h-[40px] px-2 text-sm" @click="lihatRiwayat(s)"><PhClockCounterClockwise :size="16" /> Riwayat</button>
              <button v-if="s.attendance_id && s.status !== 'menunggu_verval' && !sesi.isSuperadmin" class="tombol-teks min-h-[40px] px-2 text-sm" @click="koreksiS(s)"><PhPencilSimple :size="16" /> Ajukan koreksi</button>
              <button v-if="s.attendance_id && sesi.isSuperadmin" class="tombol-teks min-h-[40px] px-2 text-sm" @click="ubahS(s)"><PhPencilSimple :size="16" /> Ubah langsung</button>
              <button v-if="!s.attendance_id && sesi.isSuperadmin && s.keadaan !== 'akan_datang'" class="tombol-teks min-h-[40px] px-2 text-sm" @click="manualS(s)"><PhPlus :size="16" /> Catat manual</button>
            </div>
          </li>
        </ul>
        <p v-if="!sesi.isSuperadmin" class="flex gap-2 text-xs text-teks3"><PhInfo :size="16" class="shrink-0" /> Perubahan oleh admin diajukan sebagai koreksi dan berlaku setelah disetujui superadmin (menu Verval Presensi → Koreksi).</p>
      </div>
    </LembarBawah>

    <LembarKeputusan v-model="lk.buka" :judul="lk.judul" :ringkasan="lk.ringkasan" :pilihan="lk.pilihan || []" :pilihan-pulang="lk.pilihanPulang || null"
      :bawaan="lk.bawaan" :catatan="lk.catatan" :label-tombol="lk.labelTombol" :bahaya="lk.bahaya" :contoh-alasan="lk.contohAlasan" @kirim="kirimKeputusan" />

    <LembarBawah :model-value="!!riwayat" @update:model-value="(v) => !v && (riwayat = null)" :judul="riwayat ? `Riwayat ${riwayat.s.nama_sesi}` : ''">
      <ol v-if="riwayat" class="relative space-y-3 border-l-2 border-garis pb-2 pl-4">
        <li v-for="(h, i) in riwayat.isi" :key="i">
          <p class="text-sm font-bold">{{ JENIS_RIWAYAT[h.jenis] || h.jenis }} · {{ formatWaktu(h.waktu) }}</p>
          <p class="text-sm text-teks2">{{ h.dari ? STATUS_PRESENSI[h.dari]?.n + ' → ' : '' }}{{ STATUS_PRESENSI[h.ke]?.n }}
            <template v-if="h.ke_pulang && h.ke_pulang !== h.dari_pulang"> · {{ STATUS_PULANG[h.ke_pulang]?.n }}</template></p>
          <p v-if="h.alasan" class="text-xs text-teks3">“{{ h.alasan }}”</p>
          <p v-if="h.oleh" class="text-xs text-teks3">Oleh {{ h.oleh }}</p>
        </li>
        <li v-if="!riwayat.isi.length" class="text-sm text-teks3">Belum ada riwayat.</li>
      </ol>
    </LembarBawah>

    <!-- Cetak harian (F4 tegak) -->
    <DokumenCetak v-if="aktif === 'harian'" v-model:pratinjau="pratinjau" judul="Daftar Presensi Harian Pegawai" :subjudul="`${formatHari(tgl)} · ${namaUnit}`" :pencetak="sesi.pengguna?.nama_lengkap">
      <table class="tabel kecil">
        <colgroup><col style="width:4%"><col style="width:12%"><col style="width:23%"><col style="width:4%"><col style="width:16%"><col style="width:8%"><col style="width:8%"><col style="width:12%"><col style="width:13%"></colgroup>
        <thead><tr><th>No.</th><th>NIY</th><th>Nama</th><th>JK</th><th>Sesi</th><th>Datang</th><th>Pulang</th><th>Status</th><th>Keterangan</th></tr></thead>
        <tbody>
          <tr v-for="(b, i) in barisCetakH" :key="i">
            <template v-if="b.awal">
              <td class="tengah" :rowspan="b.rentang">{{ tampilH.indexOf(b.p) + 1 }}</td><td :rowspan="b.rentang">{{ b.p.niy || '–' }}</td>
              <td :rowspan="b.rentang">{{ b.p.nama }}</td><td class="tengah" :rowspan="b.rentang">{{ JK[b.p.jenis_kelamin] || '–' }}</td>
            </template>
            <template v-if="b.s"><td>{{ b.s.nama_sesi }} {{ formatJam(b.s.mulai) }}</td><td class="tengah">{{ jamTeks(b.s.datang_pada) }}</td><td class="tengah">{{ jamTeks(b.s.pulang_pada) }}</td>
              <td>{{ lencanaSesi(b.s).n + (b.s.status === 'terlambat' ? ` ${b.s.terlambat_menit} mnt` : '') }}</td><td>{{ b.s.keterangan || '' }}</td></template>
            <td v-else colspan="5">Tidak ada sesi</td>
          </tr>
        </tbody>
      </table>
      <p class="mt-2 text-[9pt]">Jumlah: {{ hitungH.semua }} pegawai; hadir {{ hitungH.hadir }}, terlambat {{ hitungH.terlambat }}, izin/sakit/cuti {{ hitungH.izin }}, tanpa keterangan {{ hitungH.tanpa }}{{ hitungH.belum ? `, belum presensi ${hitungH.belum}` : '' }}.</p>
      <template #ttd><TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan_tertulis || 'Direktur', nama: direktur.nama || '', niy: direktur.niy }" :kanan="{ jabatan: 'Pembuat', nama: sesi.pengguna?.nama_lengkap || '' }" /></template>
    </DokumenCetak>
    <!-- Cetak bulanan (F4 mendatar) -->
    <DokumenCetak v-else v-model:pratinjau="pratinjau" mendatar judul="Rekap Kehadiran Bulanan Pegawai" :subjudul="`Bulan ${judulBulan} · ${namaUnit}`" :pencetak="sesi.pengguna?.nama_lengkap">
      <table class="tabel kecil">
        <colgroup><col style="width:2.5%"><col style="width:7%"><col style="width:15%"><col v-for="t in tanggalBulan" :key="t" :style="`width:${(64.5 / tanggalBulan.length).toFixed(2)}%`"><col style="width:6%"><col style="width:5%"></colgroup>
        <thead><tr><th>No.</th><th>NIY</th><th>Nama</th><th v-for="t in tanggalBulan" :key="t">{{ Number(t.slice(8)) }}</th><th>Hadir</th><th>%</th></tr></thead>
        <tbody><tr v-for="(p, i) in tampilB" :key="p.employee_id">
          <td class="tengah">{{ i + 1 }}</td><td>{{ p.niy || '–' }}</td><td>{{ p.nama }}</td>
          <td v-for="t in tanggalBulan" :key="t" class="tengah">{{ STATUS_HADIR[sel[p.employee_id]?.[t]?.k]?.s || '' }}</td>
          <td class="tengah">{{ p.total_hadir }}/{{ p.sesi_wajib }}</td><td class="kanan">{{ persenTeks(p.persen) }}</td>
        </tr></tbody>
      </table>
      <p class="mt-2 text-[8pt]">Kode: {{ Object.values(STATUS_HADIR).map((v) => `${v.s} = ${v.n}`).join('; ') }}. Persentase = (hadir + terlambat + dinas luar) ÷ sesi wajib.</p>
      <template #ttd><TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan_tertulis || 'Direktur', nama: direktur.nama || '', niy: direktur.niy }" :kanan="{ jabatan: 'Pembuat', nama: sesi.pengguna?.nama_lengkap || '' }" /></template>
    </DokumenCetak>
  </div>
</template>
<style scoped>
.matriks { border-collapse: separate; border-spacing: 0; min-width: 100%; }
.matriks th, .matriks td { border-bottom: 1px solid rgb(var(--garis)); padding: 2px; text-align: center; white-space: nowrap; min-width: 32px; }
.matriks thead th { font-size: 12px; font-weight: 700; padding: 6px 2px; }
.matriks .kiri { text-align: left; padding: 6px 10px; min-width: 9rem; box-shadow: 1px 0 0 rgb(var(--garis)); }
.matriks .libur { background: color-mix(in srgb, #C7332F 7%, transparent); }
.matriks .ringkas { padding: 6px 8px; font-size: 12px; }
.kode { display: grid; place-items: center; width: 28px; height: 28px; margin: 0 auto; border-radius: 8px; font-size: 11px; font-weight: 800;
  color: var(--c); background: color-mix(in srgb, var(--c) 15%, transparent); }
.kode:hover { outline: 2px solid var(--c); }
.kode.kosong { color: rgb(var(--teks-3)); background: transparent; }
.hari-kal { display: flex; min-height: 3.25rem; flex-direction: column; align-items: center; justify-content: center; gap: 2px; border-radius: 12px;
  border: 1px solid rgb(var(--garis)); background: color-mix(in srgb, var(--c, transparent) 13%, transparent); }
.hari-kal .kd { font-size: 11px; font-weight: 800; color: var(--c); min-height: 1em; }
.hari-kal.libur { border-style: dashed; }
.hari-kal.kini { outline: 2px solid rgb(var(--teks)); }
.hari-kal:disabled { opacity: 0.45; }
</style>
