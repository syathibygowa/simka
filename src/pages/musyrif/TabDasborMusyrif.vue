<!-- SIMKA PRO | src/pages/musyrif/TabDasborMusyrif.vue | v1.0 | Fase 6 – Tahap M1 Menu Musyrif | 06/10/2026 -->
<script setup>
// Dasbor musyrif untuk satu kamar: kartu statistik langsung (hari ini, pekan ini, bulan ini, tidak hadir hari ini),
// sesi asrama hari ini dengan tombol isi absensi, grafik kehadiran 14 hari, santri yang perlu perhatian
// (Absen atau kehadiran pekan ini di bawah 85%) dengan tombol WA ke wali, santri yang sedang ditangani Klinik,
// dan sesi yang belum diisi bulan ini. Diperbarui langsung saat ada absensi baru.
import { ref, computed, watch, onMounted, onBeforeUnmount } from 'vue'
import { useRouter } from 'vue-router'
import {
  PhSun, PhCalendarDots, PhCalendarBlank, PhUserMinus, PhCheckSquareOffset, PhWarningCircle, PhWhatsappLogo, PhFirstAidKit, PhChartBar, PhMoon, PhCopy,
} from '@phosphor-icons/vue'
import { useMusyrif } from '@/stores/musyrif'
import { useKlinik } from '@/stores/klinik'
import { useSantri } from '@/stores/santri'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { STATUS_SESI, KODE, jam, teksPersen } from '@/lib/absensi'
import { kontakUtama } from '@/lib/santri'
import { labelKasus } from '@/lib/klinik'
import { hariIniISO, formatPendek, formatHari } from '@/lib/tanggal'
import { pesanWA, tautanWA } from '@/lib/wa'
import { olahRinci, ringkasKamar, awalPekan, awalBulanDari, tambahHari, daftarTanggal, persenDari, teksRekapSantri, teksTidakHadir, teksRentang, namaHari, teksKode } from '@/lib/musyrif'
import KartuStatistik from '@/components/KartuStatistik.vue'

const emit = defineEmits(['rekap'])
const mu = useMusyrif(); const kl = useKlinik(); const san = useSantri(); const sesi = useSesi(); const ui = useUI(); const router = useRouter()
const hari = hariIniISO(); const awalPk = awalPekan(hari); const awalBl = awalBulanDari(hari); const awal14 = tambahHari(hari, -13)
const d = ref(null); const sesiHari = ref([]); const sakit = ref([]); const memuat = ref(false)

async function muat() {
  if (!mu.pilih) return
  memuat.value = true
  try {
    const [r, sh] = await Promise.all([mu.rinci(mu.pilih, awal14 < awalBl ? awal14 : awalBl, hari), mu.sesiHariIni(mu.pilih)])
    d.value = r; sesiHari.value = sh
    try {
      if (!kl.hakDimuat) await kl.muatHak()
      const nama = mu.kamarPilih?.nama; const ids = new Set(r.santri.map((s) => s.id))
      sakit.value = kl.hak.lihat ? (await kl.daftar('rujukan_saya')).filter((k) => ['menunggu', 'ditangani'].includes(k.status) && (ids.has(k.student_id) || k.kamar === nama)) : []
    } catch { sakit.value = [] }
  } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
onMounted(async () => { await san.muat(); muat(); mu.dengarkan(muat) })
onBeforeUnmount(() => mu.berhenti())
watch(() => mu.pilih, muat)

const oHari = computed(() => olahRinci(d.value, (s) => s.tanggal === hari))
const oPekan = computed(() => olahRinci(d.value, (s) => s.tanggal >= awalPk))
const oBulan = computed(() => olahRinci(d.value, (s) => s.tanggal >= awalBl))
const rHari = computed(() => ringkasKamar(d.value, oHari.value))
const tidakHari = computed(() => Object.entries(oHari.value.perSantri).flatMap(([id, p]) => p.tidak.filter((x) => ['I', 'S', 'A'].includes(x.kode)).map((x) => ({ ...x, id }))))
const statistik = computed(() => [
  { judul: 'Kehadiran hari ini', nilai: teksPersen(rHari.value.persen), ikon: PhSun, warna: 'beranda', ket: `${rHari.value.sesi} sesi terisi` },
  { judul: 'Pekan ini', nilai: teksPersen(ringkasKamar(d.value, oPekan.value).persen), ikon: PhCalendarDots, warna: 'agenda', ket: `Sejak ${namaHari(awalPk)} ${formatPendek(awalPk).slice(0, 5)}` },
  { judul: 'Bulan ini', nilai: teksPersen(ringkasKamar(d.value, oBulan.value).persen), ikon: PhCalendarBlank, warna: 'laporan', ket: `${ringkasKamar(d.value, oBulan.value).penuh} santri hadir penuh` },
  { judul: 'Tidak hadir hari ini', nilai: new Set(tidakHari.value.map((x) => x.id)).size, ikon: PhUserMinus, warna: 'klinik', ket: 'Izin, sakit, absen' },
])

// Grafik 14 hari
const grafik = computed(() => {
  const o = olahRinci(d.value)
  return daftarTanggal(awal14, hari).map((t) => { const r = o.perTanggal[t]; return { t, p: r ? persenDari(r) : null, n: r?.sesi || 0 } })
})

// Perlu perhatian: ada Absen pekan ini, atau kehadiran pekan ini < 85%
const perhatian = computed(() => (d.value?.santri || []).map((s) => {
  const p = oPekan.value.perSantri[s.id]; const r = p?.total
  return { s, r, tidak: p?.tidak || [], p: r ? persenDari(r) : null }
}).filter((x) => x.r && (x.r.A > 0 || (x.p != null && x.p < 85))).sort((a, b) => (a.p ?? 100) - (b.p ?? 100)))
function waWali(x) {
  const data = san.cari(x.s.id); const k = data ? kontakUtama(data) : null
  if (!k?.no_hp) return ui.toast('Nomor HP orang tua/wali santri ini belum diisi.', 'galat')
  const pesan = pesanWA('rekap_asrama', { nama_wali: k.nama || 'orang tua/wali', nama_santri: x.s.nama, kamar: mu.kamarPilih?.nama, periode: teksRentang(awalPk, hari),
    rekap: teksRekapSantri(x.r), ketidakhadiran: teksTidakHadir(x.tidak), pengirim: sesi.pengguna?.nama_lengkap, jabatan_pengirim: `Musyrif ${mu.kamarPilih?.nama || ''}`.trim() })
  window.open(tautanWA(k.no_hp, pesan), '_blank', 'noopener')
}

const tidakDiisi = computed(() => olahRinci(d.value, (s) => s.tanggal >= awalBl).tidakDiisi)
const statusSesi = (s) => STATUS_SESI[s.status] || STATUS_SESI.lewat
const isi = (s) => router.push(`/absensi-santri/isi/${mu.pilih}/${s.tanggal}/${s.sesi || s.kode}`)

// Salin kehadiran hari ini (cepat untuk grup)
async function salinHariIni() {
  const nama = (id) => d.value.santri.find((s) => s.id === id)?.nama || '–'
  const baris = tidakHari.value.map((x) => `• ${nama(x.id)} — ${x.nama_sesi.toLowerCase()}: ${teksKode[x.kode]}`)
  const teks = `Kehadiran asrama ${mu.kamarPilih?.nama}, ${formatHari(hari)}:\n• Kehadiran: ${teksPersen(rHari.value.persen)} (${rHari.value.sesi} sesi)\n${baris.length ? 'Tidak hadir:\n' + baris.join('\n') : '• Alhamdulillah, semua santri hadir.'}`
  try { await navigator.clipboard.writeText(teks); ui.toast('Kehadiran hari ini disalin. Tempel di grup WA.') } catch { ui.toast('Tidak dapat menyalin otomatis.', 'galat') }
}
</script>
<template>
  <div class="space-y-4">
    <div class="-mx-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-4 sm:overflow-visible sm:px-0">
      <KartuStatistik v-for="k in statistik" :key="k.judul" class="w-[44%] shrink-0 snap-start sm:w-auto" :judul="k.judul" :nilai="memuat && !d ? '…' : k.nilai" :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket" />
    </div>

    <div class="grid gap-4 lg:grid-cols-2">
      <!-- Sesi hari ini -->
      <section class="kartu w-absensi p-4">
        <div class="mb-3 flex items-center gap-2"><PhCheckSquareOffset :size="22" weight="duotone" style="color: var(--c)" /><h2 class="judul-bagian flex-1">Absensi asrama hari ini</h2>
          <button class="tombol-garis min-h-[36px] px-3 text-xs" @click="salinHariIni"><PhCopy :size="16" /> Salin</button></div>
        <ul class="space-y-2">
          <li v-for="s in sesiHari" :key="s.kode" class="flex items-center gap-3 rounded-xl border border-garis p-3" :class="'w-' + statusSesi(s).w">
            <span class="chip-ikon h-10 w-10 shrink-0"><component :is="s.kode === 'PAGI' ? PhSun : PhMoon" :size="22" weight="duotone" /></span>
            <span class="min-w-0 flex-1"><b class="block">{{ s.nama }}</b><span class="text-xs text-teks3">{{ jam(s.jam_mulai) }}–{{ jam(s.jam_selesai) }} WITA</span></span>
            <span class="lencana" :class="'w-' + statusSesi(s).w">{{ statusSesi(s).n }}</span>
            <button v-if="s.status !== 'belum_buka'" class="tombol-garis min-h-[38px] px-3 text-sm" @click="isi(s)">{{ s.status === 'terisi' ? 'Lihat' : 'Isi' }}</button>
          </li>
          <li v-if="!sesiHari.length" class="p-3 text-center text-sm text-teks3">Tidak ada sesi asrama hari ini.</li>
        </ul>
        <div v-if="tidakHari.length" class="mt-3 rounded-xl bg-permukaan2 p-3 text-sm">
          <p class="mb-1 font-semibold">Tidak hadir hari ini</p>
          <p v-for="(x, i) in tidakHari" :key="i" class="flex items-center gap-2 text-xs"><span class="lencana" :class="'w-' + KODE[x.kode].w">{{ teksKode[x.kode] }}</span>
            {{ d.santri.find((s) => s.id === x.id)?.nama }} · {{ x.nama_sesi.toLowerCase() }}</p>
        </div>
      </section>

      <!-- Grafik 14 hari -->
      <section class="kartu w-rekap p-4">
        <div class="mb-3 flex items-center gap-2"><PhChartBar :size="22" weight="duotone" style="color: var(--c)" /><h2 class="judul-bagian flex-1">Kehadiran 14 hari terakhir</h2>
          <button class="tombol-teks text-sm" @click="emit('rekap')">Rekap lengkap</button></div>
        <div class="flex h-40 items-end gap-1" role="img" :aria-label="'Grafik kehadiran asrama 14 hari: ' + grafik.map((g) => `${formatPendek(g.t)} ${teksPersen(g.p)}`).join(', ')">
          <div v-for="g in grafik" :key="g.t" class="flex h-full flex-1 flex-col items-center justify-end gap-1">
            <span class="text-[10px] font-semibold tabular-nums text-teks2">{{ g.p == null ? '' : Math.round(g.p) }}</span>
            <span class="w-full rounded-t-md" :style="{ height: (g.p == null ? 4 : Math.max(6, g.p)) + '%', background: g.p == null ? 'rgb(var(--garis))' : g.p >= 95 ? '#1E7D4F' : g.p >= 85 ? '#1572B6' : g.p >= 75 ? '#B5501A' : '#C7332F' }" />
            <span class="text-[10px] tabular-nums text-teks3">{{ g.t.slice(8) }}</span>
          </div>
        </div>
        <p class="mt-2 text-xs text-teks3">Persentase kehadiran seluruh sesi asrama per tanggal. Hijau ≥ 95%, biru 85–94%, jingga 75–84%, merah di bawah 75%; abu-abu = belum ada sesi terisi.</p>
      </section>
    </div>

    <div class="grid gap-4 lg:grid-cols-2">
      <!-- Perlu perhatian -->
      <section class="kartu w-pengajuan p-4">
        <div class="mb-2 flex items-center gap-2"><PhWarningCircle :size="22" weight="duotone" style="color: var(--c)" /><h2 class="judul-bagian">Perlu perhatian pekan ini</h2></div>
        <p class="mb-2 text-xs text-teks3">Santri dengan Absen atau kehadiran di bawah 85% sejak {{ namaHari(awalPk) }}, {{ formatPendek(awalPk) }}.</p>
        <ul class="divide-y divide-garis">
          <li v-for="x in perhatian" :key="x.s.id" class="flex items-center gap-3 py-2.5 text-sm">
            <span class="min-w-0 flex-1"><b class="block truncate">{{ x.s.nama }}</b><span class="text-xs text-teks3">{{ teksRekapSantri(x.r) }}</span></span>
            <button class="tombol-garis w-presensi min-h-[38px] px-3 text-sm" @click="waWali(x)" :aria-label="`WA wali ${x.s.nama}`"><PhWhatsappLogo :size="18" weight="duotone" style="color: var(--c)" /> Wali</button>
          </li>
          <li v-if="!perhatian.length" class="py-4 text-center text-sm text-teks3">Alhamdulillah, tidak ada santri yang perlu perhatian khusus pekan ini.</li>
        </ul>
      </section>

      <!-- Klinik dan sesi belum diisi -->
      <section class="kartu w-klinik p-4">
        <div class="mb-2 flex items-center gap-2"><PhFirstAidKit :size="22" weight="duotone" style="color: var(--c)" /><h2 class="judul-bagian flex-1">Sakit dan di klinik</h2>
          <router-link to="/klinik/rujukan" class="tombol-teks text-sm">Rujuk santri</router-link></div>
        <ul class="divide-y divide-garis">
          <li v-for="k in sakit" :key="k.id" class="flex items-center gap-3 py-2.5 text-sm">
            <span class="min-w-0 flex-1"><b class="block truncate">{{ k.nama }}</b><span class="text-xs text-teks3">{{ k.keluhan }} · sejak {{ formatPendek(k.dibuka_pada) }}</span></span>
            <span class="lencana" :class="'w-' + labelKasus(k).w">{{ labelKasus(k).n }}</span></li>
          <li v-if="!sakit.length" class="py-4 text-center text-sm text-teks3">Tidak ada santri kamar ini yang sedang ditangani klinik.</li>
        </ul>
        <div v-if="tidakDiisi.length" class="mt-3 rounded-xl bg-permukaan2 p-3 text-sm">
          <p class="font-semibold text-merah">{{ tidakDiisi.length }} sesi asrama bulan ini belum/tidak diisi</p>
          <p class="text-xs text-teks3">{{ tidakDiisi.slice(-6).reverse().map((r) => `${formatPendek(r.tanggal).slice(0, 5)} ${r.nama_sesi.toLowerCase()}`).join(' · ') }}{{ tidakDiisi.length > 6 ? ' · …' : '' }}</p>
        </div>
      </section>
    </div>
  </div>
</template>
