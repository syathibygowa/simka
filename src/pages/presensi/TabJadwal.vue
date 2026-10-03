<!-- SIMKA PRO | src/pages/presensi/TabJadwal.vue | v1.0 | Fase 2 – Tahap 3 Pengaturan presensi | 03/10/2026 -->
<script setup>
// Jadwal per pegawai: pola dari jabatan (otomatis) dapat disesuaikan per orang —
// memegang sebagian sesi, dinonaktifkan, ditambah pola lain, atau jadwal khusus pribadi.
// Sistem memberi peringatan bila ada sesi yang bertumpuk.
import { ref, computed, watch } from 'vue'
import { PhMagnifyingGlass, PhArrowsClockwise, PhWarning, PhCalendarCheck, PhPlus, PhTrash, PhUserGear, PhCaretRight, PhInfo, PhFloppyDisk } from '@phosphor-icons/vue'
import { useAturPresensi } from '@/stores/aturPresensi'
import { usePegawai } from '@/stores/pegawai'
import { useUI } from '@/stores/ui'
import { useLembaga } from '@/stores/lembaga'
import { MODE_DEMO } from '@/lib/supabase'
import { hariIniISO, formatHari, formatJam } from '@/lib/tanggal'
import { SUMBER_JADWAL, JENIS_POLA, teksHari, jamTitik, keMenit, durasi, sesiPegawai, cariBertumpuk, HARI_PENUH } from '@/lib/presensi'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import FormPola from './FormPola.vue'
import FormSesi from './FormSesi.vue'

const atur = useAturPresensi(); const peg = usePegawai(); const ui = useUI(); const lembaga = useLembaga()
const hariEfektif = (s, polaId) => { const libur = lembaga.holiday_calendars.find((k) => k.jenis_tugas === atur.cariPola(polaId)?.kalender)?.hari_libur || []; return teksHari(s.hari.filter((h) => !libur.includes(h))) }
const bolehUbah = computed(() => atur.boleh('atur_presensi'))
const cari = ref(''); const saring = ref('semua'); const proses = ref(false)

const ringkas = computed(() => peg.daftar.filter((p) => (p.status_keaktifan || 'aktif') === 'aktif' && p.status_akun !== 'ditolak').map((p) => {
  const jadwal = atur.jadwalPegawai(p.id)
  const sesi = sesiPegawai(jadwal, atur.pola, atur.sesi)
  return { p, jadwal, jumlahSesi: sesi.length, tumpuk: cariBertumpuk(sesi) }
}))
const tampil = computed(() => {
  const q = cari.value.toLowerCase().trim()
  return ringkas.value.filter((r) => (saring.value === 'semua' || (saring.value === 'kosong' && !r.jumlahSesi) || (saring.value === 'tumpuk' && r.tumpuk.length))
    && (!q || [r.p.nama_lengkap, r.p.niy, r.p.nama_unit, ...(r.p.jabatan_fungsional || []), r.p.jabatan_struktural].join(' ').toLowerCase().includes(q)))
})
const jumlah = computed(() => ({ kosong: ringkas.value.filter((r) => !r.jumlahSesi).length, tumpuk: ringkas.value.filter((r) => r.tumpuk.length).length }))
const namaPola = (id) => atur.cariPola(id)?.nama || '–'
const rentangJam = (s) => `${jamTitik(keMenit(s.jam_mulai))}–${jamTitik(keMenit(s.jam_mulai) + durasi(s))}`

async function sinkron() {
  if (!(await ui.konfirmasi({ judul: 'Sinkron ulang jadwal dari jabatan?', pesan: 'Pola dari jabatan yang belum ada akan ditambahkan dan pola jabatan yang sudah dilepas akan dihapus. Penyesuaian per orang (sesi yang dipegang, pola tambahan) tetap dipertahankan.', ya: 'Sinkron' }))) return
  proses.value = true
  try { const n = await atur.sinkronSemua(); ui.toast(`Jadwal ${n} pegawai sudah disinkronkan.`) } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}

// ---------- Rincian satu pegawai ----------
const dipilih = ref(null)
const r = computed(() => ringkas.value.find((x) => x.p.id === dipilih.value))
const tambahPolaId = ref('')
const polaTersedia = computed(() => !r.value ? [] : atur.pola.filter((p) => (!p.employee_id || p.employee_id === r.value.p.id) && !r.value.jadwal.some((j) => j.pattern_id === p.id)))
const tglPratinjau = ref(hariIniISO()); const pratinjau = ref(null); const memuatPratinjau = ref(false)
const lembarPola = ref(false); const polaDipilih = ref(null); const lembarSesi = ref(false); const sesiDipilih = ref(null); const polaUntukSesi = ref(null)

function buka(p) { dipilih.value = p.id; tambahPolaId.value = ''; tglPratinjau.value = hariIniISO(); muatPratinjau() }
async function muatPratinjau() {
  if (!dipilih.value) return
  if (MODE_DEMO) {
    const hari = new Date(tglPratinjau.value + 'T12:00:00+08:00').getUTCDay()
    pratinjau.value = sesiPegawai(atur.jadwalPegawai(dipilih.value), atur.pola, atur.sesi)
      .filter((s) => s.pola.jenis !== 'shift' && s.hari.includes(hari)).map((s) => ({ nama_pola: s.pola.nama, nama_sesi: s.nama, jam: rentangJam(s), opsional: s.opsional }))
    return
  }
  memuatPratinjau.value = true
  try {
    const d = await atur.pratinjau(dipilih.value, tglPratinjau.value)
    pratinjau.value = (d || []).map((x) => ({ nama_pola: x.nama_pola, nama_sesi: x.nama_sesi, jam: `${formatJam(x.mulai).replace(':', '.')}–${formatJam(x.selesai).replace(':', '.')}`, opsional: x.opsional }))
  } catch (e) { pratinjau.value = null; ui.toast(e.message, 'galat') } finally { memuatPratinjau.value = false }
}
watch(tglPratinjau, muatPratinjau)

async function ubahJadwal(j, perubahan) {
  try { await atur.simpanJadwal({ ...j, ...perubahan }); muatPratinjau() } catch (e) { ui.toast(e.message, 'galat') }
}
function pegangSesi(j, sesiId, centang) {
  const semua = atur.sesiPola(j.pattern_id).map((s) => s.id)
  let pegang = new Set(j.sesi_dipegang?.length ? j.sesi_dipegang : semua)
  centang ? pegang.add(sesiId) : pegang.delete(sesiId)
  if (!pegang.size) return ui.toast('Minimal satu sesi dipegang. Nonaktifkan pola bila pegawai tidak memegang sesi apa pun.', 'galat')
  ubahJadwal(j, { sesi_dipegang: pegang.size === semua.length ? null : [...pegang] })
}
async function tambahPola() {
  if (!tambahPolaId.value) return
  try { await atur.simpanJadwal({ employee_id: dipilih.value, pattern_id: tambahPolaId.value, sumber: 'manual', aktif: true }); tambahPolaId.value = ''; ui.toast('Pola ditambahkan ke jadwal pegawai.'); muatPratinjau() }
  catch (e) { ui.toast(e.message, 'galat') }
}
async function hapusJadwal(j) {
  if (!(await ui.konfirmasi({ judul: `Lepas pola ${namaPola(j.pattern_id)}?`, pesan: 'Pegawai tidak lagi wajib presensi pada sesi pola ini.', ya: 'Lepas', bahaya: true }))) return
  try { await atur.hapusJadwal(j.id); ui.toast('Pola dilepas dari jadwal.'); muatPratinjau() } catch (e) { ui.toast(e.message, 'galat') }
}
function jadwalKhusus() { polaDipilih.value = null; lembarPola.value = true }
async function polaKhususTersimpan(p) {
  if (!r.value.jadwal.some((j) => j.pattern_id === p.id)) await atur.simpanJadwal({ employee_id: dipilih.value, pattern_id: p.id, sumber: 'manual', aktif: true })
  sesiDipilih.value = null; polaUntukSesi.value = p.id; lembarSesi.value = true
}
function tambahSesiPribadi(j) { sesiDipilih.value = null; polaUntukSesi.value = j.pattern_id; lembarSesi.value = true }
function ubahSesiPribadi(s) { sesiDipilih.value = s; polaUntukSesi.value = s.pattern_id; lembarSesi.value = true }
const SARING = [{ k: 'semua', n: 'Semua' }, { k: 'kosong', n: 'Belum berjadwal' }, { k: 'tumpuk', n: 'Jadwal bertumpuk' }]
</script>
<template>
  <div class="space-y-4">
    <div class="flex flex-wrap items-center gap-2">
      <div class="relative min-w-[14rem] flex-1">
        <PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-teks3" />
        <input v-model="cari" class="isian pl-10" placeholder="Cari nama, NIY, jabatan, atau bidang" aria-label="Cari pegawai" />
      </div>
      <button v-if="bolehUbah" class="tombol-garis" :disabled="proses" @click="sinkron"><PhArrowsClockwise :size="20" weight="duotone" /> Sinkron dari jabatan</button>
    </div>
    <div class="flex flex-wrap gap-2">
      <button v-for="s in SARING" :key="s.k" @click="saring = s.k"
        :class="['min-h-[40px] rounded-full border px-3.5 text-sm font-semibold', saring === s.k ? 'border-transparent bg-[#C7332F] text-white' : 'border-garis bg-permukaan text-teks2']">
        {{ s.n }}<template v-if="s.k !== 'semua'"> ({{ jumlah[s.k] }})</template></button>
    </div>

    <ul class="grid gap-2 md:grid-cols-2 xl:grid-cols-3">
      <li v-for="x in tampil" :key="x.p.id">
        <button class="kartu flex w-full items-center gap-3 p-3.5 text-left hover:bg-permukaan2" @click="buka(x.p)">
          <span class="chip-ikon h-11 w-11"><PhCalendarCheck :size="24" weight="duotone" /></span>
          <span class="min-w-0 flex-1">
            <span class="block truncate font-semibold">{{ x.p.nama_lengkap }}</span>
            <span class="block truncate text-xs text-teks3">{{ [x.p.jabatan_struktural, ...(x.p.jabatan_fungsional || [])].filter(Boolean).join(', ') || 'Belum ada jabatan' }}</span>
            <span class="mt-1 flex flex-wrap gap-1">
              <span v-for="j in x.jadwal.filter((y) => y.aktif)" :key="j.id" :class="['lencana', 'w-' + (atur.cariPola(j.pattern_id)?.warna || 'presensi')]">{{ namaPola(j.pattern_id) }}</span>
              <span v-if="!x.jumlahSesi" class="lencana w-laporan">Belum berjadwal</span>
              <span v-if="x.tumpuk.length" class="lencana w-klinik"><PhWarning :size="13" weight="bold" /> Bertumpuk</span>
            </span>
          </span>
          <PhCaretRight :size="20" class="text-teks3" />
        </button>
      </li>
    </ul>
    <p v-if="!tampil.length" class="py-8 text-center text-teks3">Tidak ada pegawai yang sesuai.</p>

    <LembarBawah :model-value="!!dipilih" @update:model-value="(v) => !v && (dipilih = null)" :judul="r ? r.p.nama_lengkap : ''">
      <div v-if="r" class="space-y-4 pb-2">
        <p class="text-sm text-teks3">{{ [r.p.jabatan_struktural, ...(r.p.jabatan_fungsional || [])].filter(Boolean).join(', ') || 'Belum ada jabatan' }} · {{ r.p.nama_unit || 'Tanpa bidang' }}</p>

        <div v-if="r.tumpuk.length" class="w-klinik rounded-xl p-3 text-sm" style="background: color-mix(in srgb, var(--c) 12%, transparent)">
          <p class="flex items-center gap-1.5 font-bold" style="color: var(--c)"><PhWarning :size="18" weight="bold" /> Ada sesi yang bertumpuk</p>
          <ul class="mt-1 space-y-0.5 text-teks2">
            <li v-for="(t, i) in r.tumpuk" :key="i">{{ t.a.pola.nama }} – {{ t.a.nama }} ({{ rentangJam(t.a) }}) dengan {{ t.b.pola.nama }} – {{ t.b.nama }} ({{ rentangJam(t.b) }}), hari {{ t.hari.map((h) => HARI_PENUH[h]).join(', ') }}</li>
          </ul>
          <p class="mt-1 text-xs text-teks3">Satu presensi tetap memenuhi semua sesi yang jendelanya terbuka. Bila salah satu sesi sebenarnya tidak dipegang, hapus centangnya di bawah.</p>
        </div>

        <section v-for="j in r.jadwal" :key="j.id" :class="['rounded-2xl border border-garis p-3', 'w-' + (atur.cariPola(j.pattern_id)?.warna || 'presensi'), !j.aktif && 'opacity-70']">
          <div class="flex items-center gap-2">
            <span class="h-3 w-3 shrink-0 rounded-full" style="background: var(--c)" />
            <p class="min-w-0 flex-1 font-bold">{{ namaPola(j.pattern_id) }}
              <span class="ml-1 text-xs font-normal text-teks3">{{ JENIS_POLA[atur.cariPola(j.pattern_id)?.jenis]?.n }}</span></p>
            <span :class="['lencana', 'w-' + SUMBER_JADWAL[j.sumber].w]">{{ SUMBER_JADWAL[j.sumber].n }}</span>
          </div>
          <label class="mt-2 flex min-h-[40px] items-center gap-2.5 text-sm font-semibold">
            <input type="checkbox" class="h-5 w-5 accent-[#C7332F]" :checked="j.aktif" :disabled="!bolehUbah" @change="ubahJadwal(j, { aktif: $event.target.checked })" /> Pola ini berlaku untuk pegawai</label>
          <ul v-if="j.aktif" class="mt-1 space-y-1">
            <li v-for="s in atur.sesiPola(j.pattern_id).filter((x) => x.aktif)" :key="s.id" class="flex items-center gap-2">
              <label class="flex min-h-[40px] flex-1 items-center gap-2.5 text-sm">
                <input type="checkbox" class="h-5 w-5 accent-[#C7332F]" :disabled="!bolehUbah" :checked="!j.sesi_dipegang?.length || j.sesi_dipegang.includes(s.id)" @change="pegangSesi(j, s.id, $event.target.checked)" />
                <span><span class="font-semibold">{{ s.nama }}</span> <span class="tabular-nums text-teks3">{{ rentangJam(s) }}</span>
                  <span class="block text-xs text-teks3">{{ atur.cariPola(j.pattern_id)?.jenis === 'shift' ? 'Sesuai jadwal shift' : hariEfektif(s, j.pattern_id) }}{{ s.opsional ? ' · opsional' : '' }}</span></span>
              </label>
              <button v-if="bolehUbah && atur.cariPola(j.pattern_id)?.employee_id" class="tombol-ikon h-10 w-10" @click="ubahSesiPribadi(s)" :aria-label="`Ubah sesi ${s.nama}`"><PhUserGear :size="18" /></button>
            </li>
            <li v-if="!atur.sesiPola(j.pattern_id).filter((x) => x.aktif).length" class="text-sm text-teks3">Pola ini belum memiliki sesi aktif.</li>
          </ul>
          <div v-if="bolehUbah" class="mt-1 flex flex-wrap gap-1">
            <button v-if="atur.cariPola(j.pattern_id)?.employee_id" class="tombol-teks min-h-[40px] text-sm" @click="tambahSesiPribadi(j)"><PhPlus :size="16" weight="bold" /> Tambah sesi</button>
            <button v-if="j.sumber === 'manual'" class="tombol-teks min-h-[40px] text-sm" @click="hapusJadwal(j)"><PhTrash :size="16" /> Lepas pola</button>
          </div>
        </section>
        <p v-if="!r.jadwal.length" class="flex gap-2 rounded-xl bg-permukaan2 p-3 text-sm text-teks2"><PhInfo :size="18" class="mt-0.5 shrink-0" />
          Pegawai ini belum memiliki jadwal presensi. Tambahkan pola atau buat jadwal khusus.</p>

        <div v-if="bolehUbah" class="space-y-2 rounded-2xl border border-dashed border-garis p-3">
          <label class="label-isian" for="jd-tambah">Tambah pola lain</label>
          <div class="flex gap-2">
            <select id="jd-tambah" v-model="tambahPolaId" class="isian flex-1">
              <option value="">Pilih pola…</option>
              <option v-for="p in polaTersedia" :key="p.id" :value="p.id">{{ p.nama }}{{ p.aktif ? '' : ' (nonaktif)' }}</option>
            </select>
            <button class="tombol-utama px-4" :disabled="!tambahPolaId" @click="tambahPola"><PhPlus :size="20" weight="bold" /></button>
          </div>
          <button class="tombol-garis w-full" @click="jadwalKhusus"><PhUserGear :size="20" weight="duotone" /> Buat jadwal khusus untuk pegawai ini</button>
        </div>

        <div class="rounded-2xl bg-permukaan2 p-3">
          <InputTanggal v-model="tglPratinjau" label="Pratinjau jadwal pada tanggal" />
          <p class="mt-2 text-sm font-bold">{{ formatHari(tglPratinjau) }}</p>
          <p v-if="memuatPratinjau" class="py-2 text-sm text-teks3">Memuat…</p>
          <ul v-else-if="pratinjau?.length" class="mt-1 divide-y divide-garis">
            <li v-for="(x, i) in pratinjau" :key="i" class="flex items-center gap-2 py-1.5 text-sm">
              <span class="w-28 shrink-0 font-semibold tabular-nums">{{ x.jam }}</span>
              <span class="flex-1">{{ x.nama_pola }} – {{ x.nama_sesi }}<span v-if="x.opsional" class="text-teks3"> (opsional)</span></span>
            </li>
          </ul>
          <p v-else class="py-2 text-sm text-teks3">Tidak ada sesi pada tanggal ini (libur atau belum berjadwal).</p>
          <p class="text-xs text-teks3">Pratinjau sudah memperhitungkan libur pekanan, hari libur, dan jadwal shift{{ MODE_DEMO ? ' (mode demo: libur dan shift tidak dihitung)' : '' }}.</p>
        </div>
      </div>
    </LembarBawah>
    <FormPola v-model="lembarPola" :pola="polaDipilih" :pegawai="r?.p" @tersimpan="polaKhususTersimpan" />
    <FormSesi v-model="lembarSesi" :sesi="sesiDipilih" :pola-id="polaUntukSesi" @tersimpan="muatPratinjau" />
  </div>
</template>
