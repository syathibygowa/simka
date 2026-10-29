<!-- SIMKA PRO | src/pages/musyrif/TabSesiKontrol.vue | v1.0 | 14.35.0: sesi asrama (wajib/opsional absen), pengontrolan kamar, laporan instan grup WA | 30/10/2026 -->
<script setup>
// Musyrif → Sesi & kontrol. Seluruh sesi asrama hari itu mengikuti pola presensi musyrif (mis. subuh, pagi, sore, petang, malam):
//   • Sesi "Wajib absen"  : absensi santri wajib diisi (tombol Isi absensi).
//   • Sesi "Absen opsional": musyrif tetap mengontrol; absensi santri boleh diisi. Bila diisi, keadaan santri ikut dilaporkan.
//   • Setiap sesi dicatat pengontrolannya (ceklist butir yang diatur admin, mis. kamar terkunci, listrik dimatikan) + catatan.
//   • Laporan instan ke grup WhatsApp: per sesi atau seluruh sesi hari itu (presensi santri + pengontrolan).
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { PhCaretLeft, PhCaretRight, PhWhatsappLogo, PhListChecks, PhCheckSquare, PhSquare, PhUserCheck, PhShieldCheck, PhUsersThree, PhWarningCircle,
  PhSunHorizon, PhSun, PhCloudSun, PhMoon, PhMoonStars, PhPencilSimple, PhFloppyDisk, PhCheckCircle } from '@phosphor-icons/vue'
import { useMusyrif } from '@/stores/musyrif'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { hariIniISO, formatHari, formatJam } from '@/lib/tanggal'
import { tambahHari } from '@/lib/musyrif'
import { KODE } from '@/lib/absensi'
import { keAbsensi } from '@/lib/urutan'
import { MODE_SESI, KEADAAN, KODE_TIDAK, keadaanSesi, laporanAsramaWA, FORMAT_LAPORAN } from '@/lib/asrama'
import InputTanggal from '@/components/InputTanggal.vue'
import KartuStatistik from '@/components/KartuStatistik.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import LembarLaporanGrup from '@/components/LembarLaporanGrup.vue'

const mu = useMusyrif(); const sesi = useSesi(); const ui = useUI(); const router = useRouter()
const tanggal = ref(hariIniISO()); const d = ref(null); const memuat = ref(false); const kini = ref(new Date())
async function muat() {
  if (!mu.pilih) return
  memuat.value = true
  try { d.value = await mu.kontrolHari(mu.pilih, tanggal.value); kini.value = new Date() } catch (e) { ui.toast(e.message, 'galat'); d.value = null } finally { memuat.value = false }
}
let detak
onMounted(() => { muat(); detak = setInterval(() => { kini.value = new Date() }, 60000) })
onUnmounted(() => clearInterval(detak))
watch(() => [mu.pilih, tanggal.value], muat)
const geser = (n) => { tanggal.value = tambahHari(tanggal.value, n) }

const daftar = computed(() => (d.value?.sesi || []).map((s) => ({ ...s, keadaan: keadaanSesi(s, kini.value) })))
const bolehCatat = computed(() => !!(d.value?.pengasuh_saya || d.value?.boleh_atas_nama))
const ikonSesi = (s) => { const j = Number(s.jam_mulai.slice(0, 2)); return j < 5 ? PhMoonStars : j < 10 ? PhSunHorizon : j < 15 ? PhSun : j < 19 ? PhCloudSun : PhMoon }
const okButir = (k) => (k?.butir || []).filter((b) => b.ok).length

const statistik = computed(() => {
  const s = daftar.value; const wajib = s.filter((x) => x.mode === 'wajib'); const jalan = s.filter((x) => x.keadaan !== 'belum_buka')
  const tidak = new Set(s.flatMap((x) => (x.absensi?.tidak || []).filter((t) => ['I', 'S', 'A', 'B'].includes(t.kode)).map((t) => t.nama)))
  return [
    { judul: 'Sesi asrama', nilai: s.length, ikon: PhListChecks, warna: 'musyrif', keterangan: `${wajib.length} wajib absen · ${s.length - wajib.length} kontrol` },
    { judul: 'Absensi wajib terisi', nilai: `${wajib.filter((x) => x.absensi).length}/${wajib.length}`, ikon: PhUserCheck, warna: 'presensi', keterangan: `${s.filter((x) => x.mode === 'opsional' && x.absensi).length} sesi kontrol ikut diabsen` },
    { judul: 'Pengontrolan tercatat', nilai: `${s.filter((x) => x.kontrol).length}/${jalan.length}`, ikon: PhShieldCheck, warna: 'shift', keterangan: 'Dari sesi yang sudah dibuka' },
    { judul: 'Santri tidak hadir', nilai: tidak.size, ikon: PhWarningCircle, warna: 'klinik', keterangan: 'Izin, sakit, absen, bolos' },
  ]
})

// ---------- Isi absensi ----------
const isiAbsensi = (s) => router.push(keAbsensi({ group_id: mu.pilih, tanggal: tanggal.value, sesi: s.kode }))

// ---------- Pengontrolan ----------
const lembarK = ref(false); const sesiK = ref(null); const centang = ref({}); const catatanK = ref(''); const menyimpan = ref(false)
function bukaKontrol(s) {
  sesiK.value = s; catatanK.value = s.kontrol?.catatan || ''
  centang.value = Object.fromEntries(s.butir.map((b) => [b.kode, s.kontrol ? !!s.kontrol.butir.find((x) => x.kode === b.kode)?.ok : false]))
  lembarK.value = true
}
const semuaCentang = computed(() => sesiK.value?.butir.length && sesiK.value.butir.every((b) => centang.value[b.kode]))
const tandaiSemua = () => { const v = !semuaCentang.value; sesiK.value.butir.forEach((b) => { centang.value[b.kode] = v }) }
async function simpanKontrol(lapor = false) {
  menyimpan.value = true
  try {
    await mu.simpanKontrol({ group_id: mu.pilih, tanggal: tanggal.value, sesi: sesiK.value.kode, catatan: catatanK.value,
      butir: sesiK.value.butir.map((b) => ({ kode: b.kode, ok: !!centang.value[b.kode] })) })
    ui.toast(`Pengontrolan ${sesiK.value.nama.toLowerCase()} tersimpan.`); lembarK.value = false
    const kode = sesiK.value.kode; await muat()
    if (lapor) laporkan(daftar.value.filter((x) => x.kode === kode))
  } catch (e) { ui.toast(e.message, 'galat') } finally { menyimpan.value = false }
}

// ---------- Laporan WA ----------
const lembarWA = ref(false); const formatWA = ref('lengkap'); const sesiWA = ref([])
function laporkan(s) { sesiWA.value = s.map((x) => x.kode); lembarWA.value = true }
const laporHari = () => laporkan(daftar.value.filter((x) => x.keadaan !== 'belum_buka'))
const teksWA = computed(() => (d.value ? laporanAsramaWA({ kamar: d.value.kamar.nama, tanggal: tanggal.value, jumlahSantri: d.value.jumlah_santri,
  sesi: daftar.value.filter((x) => sesiWA.value.includes(x.kode)), pengirim: sesi.pengguna?.nama_lengkap, format: formatWA.value }) : ''))
const judulWA = computed(() => (sesiWA.value.length === 1 ? `Laporan ${daftar.value.find((x) => x.kode === sesiWA.value[0])?.nama.toLowerCase() || 'sesi'}` : tanggal.value === hariIniISO() ? 'Laporan sesi asrama hari ini' : 'Laporan sesi asrama'))
</script>
<template>
  <div class="space-y-4">
    <div class="flex flex-wrap items-center gap-2">
      <button class="tombol-ikon h-11 w-11" aria-label="Hari sebelumnya" @click="geser(-1)"><PhCaretLeft :size="20" weight="bold" /></button>
      <div class="w-44"><InputTanggal class="tanpa-label" v-model="tanggal" label="Tanggal" /></div>
      <button class="tombol-ikon h-11 w-11" aria-label="Hari berikutnya" :disabled="tanggal >= hariIniISO()" @click="geser(1)"><PhCaretRight :size="20" weight="bold" /></button>
      <button v-if="tanggal !== hariIniISO()" class="tombol-garis min-h-[44px] px-3 text-sm" @click="tanggal = hariIniISO()">Hari ini</button>
      <span class="flex-1" />
      <button class="tombol-wa-garis w-presensi min-h-[44px] px-4 text-sm" :disabled="!daftar.some((x) => x.keadaan !== 'belum_buka')" @click="laporHari">
        <PhWhatsappLogo :size="20" weight="duotone" /> {{ tanggal === hariIniISO() ? 'Laporan WA hari ini' : 'Laporan WA hari itu' }}</button>
    </div>

    <div class="grid grid-cols-2 gap-3 lg:grid-cols-4"><KartuStatistik v-for="k in statistik" :key="k.judul" v-bind="k" :nilai="memuat && !d ? '…' : k.nilai" /></div>

    <p v-if="memuat && !d" class="kartu p-8 text-center text-sm text-teks3">Memuat sesi asrama…</p>
    <p v-else-if="d && !daftar.length" class="kartu p-8 text-center text-sm text-teks3">Tidak ada sesi asrama pada {{ formatHari(tanggal) }} (hari libur atau pola belum diatur).</p>
    <ul v-else class="grid gap-3 lg:grid-cols-2">
      <li v-for="s in daftar" :key="s.kode" :class="['kartu kartu-sesi p-4', 'w-' + MODE_SESI[s.mode].w, s.keadaan === 'belum_buka' && 'opacity-80']">
        <div class="flex items-start gap-3">
          <span class="chip-ikon h-11 w-11 shrink-0"><component :is="ikonSesi(s)" :size="24" weight="duotone" /></span>
          <div class="min-w-0 flex-1">
            <p class="font-bold">{{ s.nama }}</p>
            <p class="text-xs text-teks3">{{ s.jam_mulai.replace(':', '.') }}–{{ s.jam_selesai.replace(':', '.') }} WITA</p>
            <div class="mt-1 flex flex-wrap gap-1">
              <span :class="['lencana', 'w-' + MODE_SESI[s.mode].w]">{{ MODE_SESI[s.mode].n }}</span>
              <span :class="['lencana', 'w-' + KEADAAN[s.keadaan].w]">{{ KEADAAN[s.keadaan].n }}</span>
            </div>
          </div>
          <button v-if="s.keadaan !== 'belum_buka'" class="tombol-ikon h-10 w-10 shrink-0 text-[#1E7D4F]" :aria-label="'Laporan WA ' + s.nama" title="Laporan WA sesi ini" @click="laporkan([s])">
            <PhWhatsappLogo :size="22" weight="duotone" /></button>
        </div>

        <!-- Absensi santri -->
        <div class="mt-3 rounded-xl bg-permukaan2 p-3">
          <div class="flex flex-wrap items-center gap-2">
            <PhUsersThree :size="18" weight="duotone" class="text-teks2" />
            <p class="min-w-0 flex-1 text-sm font-semibold">
              <template v-if="s.absensi">Hadir {{ s.absensi.hadir }}/{{ s.absensi.jumlah_anggota }} santri</template>
              <template v-else-if="s.mode === 'wajib'"><span :class="s.keadaan !== 'belum_buka' && 'text-merah'">Absensi santri belum diisi</span></template>
              <template v-else><span class="text-teks2">Absensi santri tidak wajib</span></template>
            </p>
            <button v-if="s.keadaan !== 'belum_buka' && bolehCatat" :class="[s.absensi ? 'tombol-garis' : s.mode === 'wajib' ? 'tombol-utama' : 'tombol-garis', 'min-h-[36px] px-3 text-xs']" @click="isiAbsensi(s)">
              {{ s.absensi ? 'Lihat/ubah' : s.mode === 'wajib' ? 'Isi absensi' : 'Absen (opsional)' }}</button>
          </div>
          <div v-if="s.absensi?.tidak?.length" class="mt-2 flex flex-wrap gap-1">
            <span v-for="(t, i) in s.absensi.tidak" :key="i" :class="['lencana', 'w-' + KODE[t.kode].w]">{{ t.nama }} · {{ KODE_TIDAK[t.kode] }}</span>
          </div>
        </div>

        <!-- Pengontrolan -->
        <div class="mt-2 rounded-xl border border-garis p-3">
          <div class="flex flex-wrap items-center gap-2">
            <PhShieldCheck :size="18" weight="duotone" style="color: var(--c)" />
            <p class="min-w-0 flex-1 text-sm font-semibold">
              <template v-if="s.kontrol">Pengontrolan {{ okButir(s.kontrol) }}/{{ s.kontrol.butir.length }} butir</template>
              <template v-else><span :class="s.keadaan === 'lewat' && 'text-merah'">Pengontrolan belum dicatat</span></template>
            </p>
            <button v-if="s.keadaan !== 'belum_buka' && bolehCatat" :class="[s.kontrol ? 'tombol-garis' : 'tombol-utama', 'min-h-[36px] px-3 text-xs']" @click="bukaKontrol(s)">
              <PhPencilSimple v-if="s.kontrol" :size="14" /> {{ s.kontrol ? 'Ubah' : 'Catat kontrol' }}</button>
          </div>
          <ul v-if="s.kontrol" class="mt-2 space-y-0.5 text-xs">
            <li v-for="b in s.kontrol.butir" :key="b.kode" :class="['flex items-center gap-1.5', b.ok ? 'text-teks' : 'text-teks3 line-through']">
              <component :is="b.ok ? PhCheckSquare : PhSquare" :size="16" :weight="b.ok ? 'fill' : 'regular'" :style="b.ok ? 'color: #1E7D4F' : ''" />{{ b.teks }}</li>
            <li v-if="s.kontrol.catatan" class="pt-1 text-teks2">Catatan: {{ s.kontrol.catatan }}</li>
            <li class="pt-1 text-teks3">{{ s.kontrol.oleh }} · pukul {{ formatJam(s.kontrol.waktu) }}</li>
          </ul>
        </div>
      </li>
    </ul>
    <p class="text-xs text-teks3">Sesi dan jamnya mengikuti pola presensi musyrif. "Wajib absen" = absensi santri wajib diisi; "Absen opsional" = sesi kontrol (absensi boleh diisi).
      Peran sesi dan butir pengontrolan diatur admin di tab Pengaturan.</p>

    <!-- Lembar pengontrolan -->
    <LembarBawah v-model="lembarK" :judul="sesiK ? `Pengontrolan ${sesiK.nama.toLowerCase()}` : 'Pengontrolan'">
      <div v-if="sesiK" class="space-y-3 pb-2">
        <p class="text-sm text-teks2">{{ d?.kamar?.nama }} · {{ formatHari(tanggal) }}. Centang yang sudah dipastikan.</p>
        <button type="button" class="tombol-teks h-8 min-h-0 text-sm" @click="tandaiSemua">{{ semuaCentang ? 'Hapus semua centang' : 'Centang semua' }}</button>
        <ul class="space-y-2">
          <li v-for="b in sesiK.butir" :key="b.kode">
            <label :class="['flex min-h-[52px] cursor-pointer items-center gap-3 rounded-xl border px-3 text-sm font-semibold', centang[b.kode] ? 'w-presensi border-[color:var(--c)] bg-[color-mix(in_srgb,var(--c)_10%,transparent)]' : 'border-garis']">
              <input v-model="centang[b.kode]" type="checkbox" class="h-6 w-6 accent-[#1E7D4F]" />{{ b.teks }}</label></li>
          <li v-if="!sesiK.butir.length" class="text-sm text-teks3">Belum ada butir pengontrolan untuk sesi ini. Admin dapat menambahkannya di tab Pengaturan.</li>
        </ul>
        <div><label class="label-isian" for="kt-cat">Catatan (opsional)</label>
          <textarea id="kt-cat" v-model="catatanK" rows="3" class="isian" placeholder="Contoh: dua santri masih murajaah di musala, sudah diarahkan tidur." /></div>
        <div class="grid gap-2 sm:grid-cols-2">
          <button class="tombol-garis" :disabled="menyimpan" @click="simpanKontrol(false)"><PhFloppyDisk :size="20" weight="duotone" /> Simpan</button>
          <button class="tombol-utama" :disabled="menyimpan" @click="simpanKontrol(true)"><PhCheckCircle :size="20" weight="duotone" /> Simpan &amp; laporkan</button>
        </div>
      </div>
    </LembarBawah>

    <LembarLaporanGrup v-model="lembarWA" v-model:format="formatWA" :judul="judulWA" :teks="teksWA" :pilihan-format="FORMAT_LAPORAN"
      :tautan-grup="d?.kamar?.wa_internal || d?.kamar?.wa_wali || ''" :nama-grup="d?.kamar?.wa_internal ? 'grup internal kamar' : 'grup wali kamar'" />
  </div>
</template>
<style scoped>
.kartu-sesi { box-shadow: inset 4px 0 0 var(--c); }
</style>
