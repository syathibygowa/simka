<!-- SIMKA PRO | src/pages/walikelas/TabDasborKelas.vue | v1.1 | 14.2.0: tombol WhatsApp hijau | 17/10/2026 -->
<script setup>
// Dasbor satu kelas: kartu statistik langsung (hari ini, pekan ini, bulan ini, tidak hadir hari ini), absensi kelas
// hari ini dengan tombol isi, pelajaran hari ini (jurnal mengajar setiap jam: terlaksana/belum diisi), santri yang perlu
// perhatian (Absen atau kehadiran pekan ini di bawah 85%) dengan WA ke orang tua/wali, dan santri yang sedang ditangani Klinik.
import { ref, computed, watch, onMounted, onBeforeUnmount } from 'vue'
import { useRouter } from 'vue-router'
import { PhSun, PhCalendarDots, PhCalendarBlank, PhUserMinus, PhCheckSquareOffset, PhWarningCircle, PhWhatsappLogo, PhFirstAidKit, PhCopy, PhBookOpenText } from '@phosphor-icons/vue'
import { useWaliKelas } from '@/stores/waliKelas'
import { useJadwal } from '@/stores/jadwal'
import { useKlinik } from '@/stores/klinik'
import { useSantri } from '@/stores/santri'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { STATUS_SESI, KODE, jam, teksPersen } from '@/lib/absensi'
import { kontakUtama } from '@/lib/santri'
import { labelKasus } from '@/lib/klinik'
import { hariIniISO, formatPendek, formatHari } from '@/lib/tanggal'
import { pesanWA, tautanWA } from '@/lib/wa'
import { olahRinci, ringkasKamar, awalPekan, awalBulanDari, tambahHari, teksRekapSantri, teksTidakHadir, teksRentang, namaHari, teksKode } from '@/lib/musyrif'
import { STATUS_JP, statusSlot } from '@/lib/guruMapel'
import KartuStatistik from '@/components/KartuStatistik.vue'

const emit = defineEmits(['rekap', 'pelajaran'])
const wk = useWaliKelas(); const jd = useJadwal(); const kl = useKlinik(); const san = useSantri(); const sesi = useSesi(); const ui = useUI(); const router = useRouter()
const hari = hariIniISO(); const awalPk = awalPekan(hari); const awalBl = awalBulanDari(hari)
const d = ref(null); const sesiHari = ref([]); const pelajaran = ref([]); const sakit = ref([]); const memuat = ref(false)

async function muat() {
  if (!wk.pilih) return
  memuat.value = true
  try {
    const [r, sh, pl] = await Promise.all([wk.rinci(wk.pilih, awalPk < awalBl ? awalPk : awalBl, hari), wk.sesiHariIni(wk.pilih), jd.slot(hari, hari, wk.pilih).catch(() => [])])
    d.value = r; sesiHari.value = sh; pelajaran.value = pl
    try {
      if (!kl.hakDimuat) await kl.muatHak()
      const ids = new Set(r.santri.map((s) => s.id))
      sakit.value = kl.hak.lihat ? (await kl.daftar('rujukan_saya')).filter((k) => ['menunggu', 'ditangani'].includes(k.status) && ids.has(k.student_id)) : []
    } catch { sakit.value = [] }
  } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
onMounted(async () => { await san.muat(); muat(); wk.dengarkan(muat) })
onBeforeUnmount(() => wk.berhenti())
watch(() => wk.pilih, muat)

const oHari = computed(() => olahRinci(d.value, (s) => s.tanggal === hari))
const oPekan = computed(() => olahRinci(d.value, (s) => s.tanggal >= awalPk))
const oBulan = computed(() => olahRinci(d.value, (s) => s.tanggal >= awalBl))
const rHari = computed(() => ringkasKamar(d.value, oHari.value))
const tidakHari = computed(() => Object.entries(oHari.value.perSantri).flatMap(([id, p]) => p.tidak.filter((x) => ['I', 'S', 'A', 'B'].includes(x.kode)).map((x) => ({ ...x, id }))))
const statistik = computed(() => [
  { judul: 'Kehadiran hari ini', nilai: teksPersen(rHari.value.persen), ikon: PhSun, warna: 'beranda', ket: rHari.value.sesi ? 'Absensi kelas sudah diisi' : 'Absensi kelas belum diisi' },
  { judul: 'Pekan ini', nilai: teksPersen(ringkasKamar(d.value, oPekan.value).persen), ikon: PhCalendarDots, warna: 'agenda', ket: `Sejak ${namaHari(awalPk)} ${formatPendek(awalPk).slice(0, 5)}` },
  { judul: 'Bulan ini', nilai: teksPersen(ringkasKamar(d.value, oBulan.value).persen), ikon: PhCalendarBlank, warna: 'walikelas', ket: `${ringkasKamar(d.value, oBulan.value).penuh} santri hadir penuh` },
  { judul: 'Tidak hadir hari ini', nilai: new Set(tidakHari.value.filter((x) => x.kode !== 'B').map((x) => x.id)).size, ikon: PhUserMinus, warna: 'klinik', ket: 'Izin, sakit, absen' },
])

const perhatian = computed(() => (d.value?.santri || []).map((s) => {
  const p = oPekan.value.perSantri[s.id]; const r = p?.total
  return { s, r, tidak: p?.tidak || [], p: r ? (r.sesi ? Math.round(((r.sesi - r.I - r.S - r.A) / r.sesi) * 1000) / 10 : null) : null }
}).filter((x) => x.r && (x.r.A > 0 || x.r.B > 0 || (x.p != null && x.p < 85))).sort((a, b) => (a.p ?? 100) - (b.p ?? 100)))
function waWali(x) {
  const data = san.cari(x.s.id); const k = data ? kontakUtama(data) : null
  if (!k?.no_hp) return ui.toast('Nomor HP orang tua/wali santri ini belum diisi.', 'galat')
  const pesan = pesanWA('rekap_santri', { nama_wali: k.nama || 'orang tua/wali', nama_santri: x.s.nama, kelas: `kelas ${wk.kelasPilih?.nama || ''}`.trim(), periode: teksRentang(awalPk, hari),
    rekap: `${teksRekapSantri(x.r)}${x.tidak.length ? '\n\n' + teksTidakHadir(x.tidak) : ''}`, pengirim: sesi.pengguna?.nama_lengkap, jabatan_pengirim: `Wali Kelas ${wk.kelasPilih?.nama || ''}`.trim() })
  window.open(tautanWA(k.no_hp, pesan), '_blank', 'noopener')
}

const tidakDiisi = computed(() => olahRinci(d.value, (s) => s.tanggal >= awalBl).tidakDiisi)
const statusSesi = (s) => STATUS_SESI[s.status] || STATUS_SESI.lewat
const isi = (s) => router.push(`/absensi-santri/isi/${wk.pilih}/${s.tanggal}/${s.sesi || s.kode}`)
const asuhanSaya = computed(() => !!wk.kelasPilih?.asuhan_saya)

async function salinHariIni() {
  const nama = (id) => d.value.santri.find((s) => s.id === id)?.nama || '–'
  const baris = tidakHari.value.map((x) => `• ${nama(x.id)}: ${teksKode[x.kode]}${x.ket ? ` (${x.ket})` : ''}`)
  const teks = `Kehadiran kelas ${wk.kelasPilih?.nama}, ${formatHari(hari)}:\n• Kehadiran: ${teksPersen(rHari.value.persen)}\n${baris.length ? 'Tidak hadir:\n' + baris.join('\n') : '• Alhamdulillah, semua santri hadir.'}`
  try { await navigator.clipboard.writeText(teks); ui.toast('Kehadiran hari ini disalin. Tempel di grup WA.') } catch { ui.toast('Tidak dapat menyalin otomatis.', 'galat') }
}
</script>
<template>
  <div class="space-y-4">
    <div class="-mx-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-4 sm:overflow-visible sm:px-0">
      <KartuStatistik v-for="k in statistik" :key="k.judul" class="w-[44%] shrink-0 snap-start sm:w-auto" :judul="k.judul" :nilai="memuat && !d ? '…' : k.nilai" :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket" />
    </div>

    <div class="grid gap-4 lg:grid-cols-2">
      <section class="kartu w-absensi min-w-0 p-4">
        <div class="mb-3 flex items-center gap-2"><PhCheckSquareOffset :size="22" weight="duotone" style="color: var(--c)" /><h2 class="judul-bagian flex-1">Absensi kelas hari ini</h2>
          <button class="tombol-garis min-h-[36px] px-3 text-xs" @click="salinHariIni"><PhCopy :size="16" /> Salin</button></div>
        <ul class="space-y-2">
          <li v-for="s in sesiHari" :key="s.kode" class="flex flex-wrap items-center gap-3 rounded-xl border border-garis p-3" :class="'w-' + statusSesi(s).w">
            <span class="chip-ikon h-10 w-10 shrink-0"><PhSun :size="22" weight="duotone" /></span>
            <span class="min-w-[8rem] flex-1"><b class="block">{{ s.nama }}</b><span class="text-xs text-teks3">{{ jam(s.jam_mulai) }}–{{ jam(s.jam_selesai) }} WITA</span></span>
            <span class="lencana" :class="'w-' + statusSesi(s).w">{{ statusSesi(s).n }}</span>
            <button v-if="s.status !== 'belum_buka'" class="tombol-utama min-h-[38px] px-4 text-sm" @click="isi(s)">{{ s.status === 'terisi' || !asuhanSaya ? 'Lihat' : 'Isi absensi' }}</button>
          </li>
          <li v-if="!sesiHari.length" class="p-3 text-center text-sm text-teks3">Hari ini tidak ada absensi kelas (libur sekolah).</li>
        </ul>
        <div v-if="tidakHari.length" class="mt-3 rounded-xl bg-permukaan2 p-3 text-sm">
          <p class="mb-1 font-semibold">Tidak hadir hari ini</p>
          <p v-for="(x, i) in tidakHari" :key="i" class="flex items-center gap-2 text-xs"><span class="lencana" :class="'w-' + KODE[x.kode].w">{{ teksKode[x.kode] }}</span>
            {{ d.santri.find((s) => s.id === x.id)?.nama }}<template v-if="x.ket"> · {{ x.ket }}</template></p>
        </div>
        <p v-if="tidakDiisi.length" class="mt-3 text-xs font-semibold text-merah">{{ tidakDiisi.length }} hari bulan ini absensi kelas belum/tidak diisi:
          <span class="font-normal text-teks3">{{ tidakDiisi.slice(-6).reverse().map((r) => formatPendek(r.tanggal).slice(0, 5)).join(', ') }}{{ tidakDiisi.length > 6 ? ', …' : '' }}</span></p>
      </section>

      <section class="kartu w-gurumapel min-w-0 p-4">
        <div class="mb-3 flex items-center gap-2"><PhBookOpenText :size="22" weight="duotone" style="color: var(--c)" /><h2 class="judul-bagian flex-1">Pelajaran hari ini</h2>
          <button class="tombol-teks text-sm" @click="emit('pelajaran')">Selengkapnya</button></div>
        <ul class="divide-y divide-garis">
          <li v-for="p in pelajaran" :key="p.period_id + p.assignment_id" class="flex items-center gap-3 py-2 text-sm">
            <span class="w-24 shrink-0 tabular-nums text-teks2">{{ p.jam_mulai }}–{{ p.jam_selesai }}</span>
            <span class="min-w-0 flex-1"><b class="block truncate">{{ p.mapel }}</b><span class="block truncate text-xs text-teks3">{{ p.guru }}<template v-if="p.materi"> · {{ p.materi }}</template></span></span>
            <span class="lencana shrink-0" :class="'w-' + STATUS_JP[statusSlot(p)].w">{{ STATUS_JP[statusSlot(p)].n }}</span>
          </li>
          <li v-if="!pelajaran.length" class="py-4 text-center text-sm text-teks3">Tidak ada jam pelajaran terjadwal hari ini.</li>
        </ul>
      </section>
    </div>

    <div class="grid gap-4 lg:grid-cols-2">
      <section class="kartu w-pengajuan p-4">
        <div class="mb-2 flex items-center gap-2"><PhWarningCircle :size="22" weight="duotone" style="color: var(--c)" /><h2 class="judul-bagian flex-1">Perlu perhatian pekan ini</h2>
          <button class="tombol-teks text-sm" @click="emit('rekap')">Rekap lengkap</button></div>
        <p class="mb-2 text-xs text-teks3">Santri dengan Absen/Bolos atau kehadiran di bawah 85% sejak {{ namaHari(awalPk) }}, {{ formatPendek(awalPk) }}.</p>
        <ul class="divide-y divide-garis">
          <li v-for="x in perhatian" :key="x.s.id" class="flex items-center gap-3 py-2.5 text-sm">
            <span class="min-w-0 flex-1"><b class="block truncate">{{ x.s.nama }}</b><span class="text-xs text-teks3">{{ teksRekapSantri(x.r) }}</span></span>
            <button class="tombol-wa-garis w-presensi min-h-[38px] px-3 text-sm" :aria-label="`WA orang tua/wali ${x.s.nama}`" @click="waWali(x)"><PhWhatsappLogo :size="18" weight="duotone" /> Wali</button>
          </li>
          <li v-if="!perhatian.length" class="py-4 text-center text-sm text-teks3">Alhamdulillah, tidak ada santri yang perlu perhatian khusus pekan ini.</li>
        </ul>
      </section>

      <section class="kartu w-klinik p-4">
        <div class="mb-2 flex items-center gap-2"><PhFirstAidKit :size="22" weight="duotone" style="color: var(--c)" /><h2 class="judul-bagian flex-1">Sakit dan di klinik</h2>
          <router-link to="/klinik/rujukan" class="tombol-teks text-sm">Rujuk santri</router-link></div>
        <ul class="divide-y divide-garis">
          <li v-for="k in sakit" :key="k.id" class="flex items-center gap-3 py-2.5 text-sm">
            <span class="min-w-0 flex-1"><b class="block truncate">{{ k.nama }}</b><span class="text-xs text-teks3">{{ k.keluhan }} · sejak {{ formatPendek(k.dibuka_pada) }}</span></span>
            <span class="lencana" :class="'w-' + labelKasus(k).w">{{ labelKasus(k).n }}</span></li>
          <li v-if="!sakit.length" class="py-4 text-center text-sm text-teks3">Tidak ada santri kelas ini yang sedang ditangani klinik.</li>
        </ul>
      </section>
    </div>
  </div>
</template>
