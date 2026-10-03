<!-- SIMKA PRO | src/pages/shift/JadwalShift.vue | v1.0 | Fase 2 – Tahap 5 Jadwal shift | 03/10/2026 -->
<script setup>
// Jadwal shift pekanan (medis, security). Admin ber-izin atur_presensi menyusun jadwal
// (manual per sel atau pembuat jadwal bergilir); petugas melihat jadwal dan mengajukan tukar shift.
import { ref, computed, onMounted, watch } from 'vue'
import { PhCaretLeft, PhCaretRight, PhMagicWand, PhFloppyDisk, PhEye, PhWarning, PhArrowsLeftRight, PhCalendarBlank, PhCheck, PhX, PhInfo, PhArrowCounterClockwise } from '@phosphor-icons/vue'
import { useAturPresensi } from '@/stores/aturPresensi'
import { useShift } from '@/stores/shift'
import { usePegawai } from '@/stores/pegawai'
import { useLembaga } from '@/stores/lembaga'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { MODE_DEMO } from '@/lib/supabase'
import { hariIniISO, formatPanjang, formatPendek, formatHari, formatRelatif } from '@/lib/tanggal'
import { seninDari, tanggalPekan, tambahHari, periksaKeterisian, ringkasPegawai, STATUS_TUKAR } from '@/lib/shift'
import { HARI_PENUH, jamTitik, keMenit, durasi } from '@/lib/presensi'
import LembarBawah from '@/components/LembarBawah.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import LembarBergilir from './LembarBergilir.vue'
import LembarTukar from './LembarTukar.vue'

const atur = useAturPresensi(); const shift = useShift(); const peg = usePegawai(); const lembaga = useLembaga(); const sesiPengguna = useSesi(); const ui = useUI()
const siap = ref(false); const galat = ref(''); const memuat = ref(false)
const polaId = ref(''); const senin = ref(seninDari(hariIniISO()))
const data = ref({ pegawai: [], roster: [], tukar: [] }); const draf = ref([]); const berubah = ref(false); const menyimpan = ref(false)
const saya = computed(() => sesiPengguna.pengguna?.id)
const bolehUbah = computed(() => atur.boleh('atur_presensi'))

onMounted(async () => {
  try {
    await Promise.all([lembaga.muat(), sesiPengguna.isAdmin && !peg.daftar.length ? peg.muat() : null])
    await atur.muat()
    polaId.value = polaShift.value[0]?.id || ''
  } catch (e) { galat.value = e.message }
  siap.value = true
})
const polaShift = computed(() => atur.pola.filter((p) => p.jenis === 'shift' && p.aktif
  && (sesiPengguna.isAdmin || atur.jadwal.some((j) => j.pattern_id === p.id && j.employee_id === saya.value && j.aktif))))
const pola = computed(() => atur.cariPola(polaId.value))
const sesi = computed(() => atur.sesiPola(polaId.value).filter((s) => s.aktif))
const hari = computed(() => tanggalPekan(senin.value))
const minggu = computed(() => hari.value[6])

async function muat() {
  if (!polaId.value) return
  memuat.value = true
  try { data.value = await shift.muat(polaId.value, senin.value, minggu.value); draf.value = data.value.roster.map((r) => ({ ...r })); berubah.value = false }
  catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
let kembalikan = false
watch([polaId, senin], async (baru, lama) => {
  if (kembalikan) { kembalikan = false; return }
  if (berubah.value && lama[0] && !(await ui.konfirmasi({ judul: 'Buang perubahan?', pesan: 'Perubahan jadwal pekan ini belum disimpan.', ya: 'Buang', bahaya: true }))) {
    kembalikan = true; polaId.value = lama[0]; senin.value = lama[1]; return
  }
  muat()
})
function pindahPekan(n) { senin.value = tambahHari(senin.value, n * 7) }

const nama = (id) => data.value.pegawai.find((p) => p.id === id)?.nama || peg.cari(id)?.nama_lengkap || '–'
const pendek = (id) => nama(id).replace(/^(Ust\.|Ustzh\.)\s*/, '').split(',')[0]
const rentangJam = (s) => `${jamTitik(keMenit(s.jam_mulai))}–${jamTitik(keMenit(s.jam_mulai) + durasi(s)).replace(' (+1 hari)', '')}`
const isi = (t, s) => draf.value.filter((r) => r.tanggal === t && r.session_id === s.id)
const cek = computed(() => periksaKeterisian(draf.value, sesi.value, hari.value))
const ringkas = computed(() => ringkasPegawai(draf.value, data.value.pegawai, sesi.value, hari.value))
const hariIni = hariIniISO()

// ---------- Sunting sel (admin) ----------
const sel = ref(null)
function bukaSel(t, s) { if (bolehUbah.value) sel.value = { t, s, pilih: isi(t, s).map((r) => r.employee_id) } }
const terkunci = (empId) => isi(sel.value.t, sel.value.s).find((r) => r.employee_id === empId && (r.ada_presensi || r.sudah_mulai))
function terapkanSel() {
  const { t, s, pilih } = sel.value
  const lama = isi(t, s)
  draf.value = draf.value.filter((r) => !(r.tanggal === t && r.session_id === s.id && !pilih.includes(r.employee_id) && !r.ada_presensi))
  pilih.filter((id) => !lama.some((r) => r.employee_id === id)).forEach((id) => draf.value.push({ employee_id: id, tanggal: t, session_id: s.id, baru: true }))
  berubah.value = true; sel.value = null
}
async function simpan() {
  if (cek.value.kosong.length && !(await ui.konfirmasi({ judul: 'Masih ada shift kosong', pesan: `${cek.value.kosong.length} shift pada pekan ini belum memiliki petugas. Tetap simpan?`, ya: 'Tetap simpan' }))) return
  menyimpan.value = true
  try {
    const r = await shift.simpan(polaId.value, senin.value, minggu.value, draf.value.map((x) => ({ employee_id: x.employee_id, tanggal: x.tanggal, session_id: x.session_id })))
    ui.toast(`Jadwal tersimpan (${r.ditambah} ditambah, ${r.dihapus} dihapus).`); berubah.value = false; await muat()
  } catch (e) { ui.toast(e.message, 'galat') } finally { menyimpan.value = false }
}
function salinPekanLalu() {
  shift.muat(polaId.value, tambahHari(senin.value, -7), tambahHari(senin.value, -1)).then((d) => {
    if (!d.roster.length) return ui.toast('Pekan sebelumnya belum memiliki jadwal.', 'galat')
    const kunci = draf.value.filter((r) => r.ada_presensi || r.sudah_mulai)
    draf.value = [...kunci, ...d.roster.map((r) => ({ employee_id: r.employee_id, tanggal: tambahHari(r.tanggal, 7), session_id: r.session_id, baru: true }))
      .filter((r) => !kunci.some((k) => k.tanggal === r.tanggal && k.session_id === r.session_id && k.employee_id === r.employee_id))]
    berubah.value = true; ui.toast('Jadwal pekan lalu disalin. Periksa lalu tekan Simpan.')
  }).catch((e) => ui.toast(e.message, 'galat'))
}

// ---------- Generator & tukar ----------
const lembarBergilir = ref(false)
async function setelahBergilir(mulai) { berubah.value = false; senin.value = seninDari(mulai); await muat() }
const lembarTukar = ref(false); const rosterTukar = ref(null)
const tukarAktif = (r) => data.value.tukar.some((t) => ['menunggu_rekan', 'menunggu_admin'].includes(t.status) && t.tanggal_pemohon === r.tanggal && t.pemohon_id === r.employee_id)
const bolehTukar = (r) => r.employee_id === saya.value && r.id && !r.sudah_mulai && !r.ada_presensi && !berubah.value && !tukarAktif(r)
function ajukanTukar(r) { rosterTukar.value = r; lembarTukar.value = true }
const tolak = ref(null)
async function aksiTukar(t, jenis, setuju, catatan = null) {
  if (!setuju && jenis === 'putuskan' && catatan === null) { tolak.value = { t, alasan: '' }; return }
  if (catatan !== null && catatan.trim().length < 5) return ui.toast('Alasan penolakan wajib diisi (minimal 5 karakter).', 'galat')
  if (catatan !== null) tolak.value = null
  try {
    if (jenis === 'jawab') await shift.jawab(t.id, setuju, catatan)
    else if (jenis === 'putuskan') await shift.putuskan(t.id, setuju, catatan)
    else await shift.batalkan(t.id)
    ui.toast(jenis === 'batal' ? 'Permintaan dibatalkan.' : setuju ? 'Permintaan disetujui.' : 'Permintaan ditolak.'); await muat()
  } catch (e) { ui.toast(e.message, 'galat') }
}

// ---------- Cetak ----------
const pratinjau = ref(false)
const direktur = computed(() => lembaga.signatories.find((s) => /^direktur$/i.test(s.jabatan_tertulis)) || lembaga.signatories[0] || {})
</script>
<template>
  <div class="w-shift">
    <p v-if="galat" class="rounded-xl bg-[#C7332F]/10 p-3 text-sm font-semibold text-merah">{{ galat }} Pastikan migrasi SQL 1600 sudah dijalankan.</p>
    <p v-else-if="!siap" class="py-10 text-center text-teks3">Memuat jadwal shift…</p>
    <div v-else-if="!polaShift.length" class="mx-auto flex max-w-md flex-col items-center py-12 text-center">
      <span class="chip-ikon h-16 w-16 rounded-3xl"><PhCalendarBlank :size="34" weight="duotone" /></span>
      <p class="mt-3 font-bold">Tidak ada jadwal shift</p>
      <p class="text-sm text-teks3">Jadwal shift berlaku untuk petugas medis dan security, serta pola lain berjenis shift.</p>
    </div>
    <template v-else>
      <div class="layar-saja space-y-3">
        <!-- Pilih pola -->
        <div class="flex flex-wrap gap-2">
          <button v-for="p in polaShift" :key="p.id" @click="polaId = p.id"
            :class="['flex min-h-[44px] items-center gap-2 rounded-xl border px-3.5 text-sm font-semibold', 'w-' + p.warna, polaId === p.id ? 'aktif text-teks' : 'border-garis bg-permukaan text-teks2']">
            <span class="h-2.5 w-2.5 rounded-full" style="background: var(--c)" />{{ p.nama }}</button>
        </div>
        <!-- Navigasi pekan -->
        <div class="kartu flex flex-wrap items-center gap-2 p-2.5">
          <button class="tombol-ikon" @click="pindahPekan(-1)" aria-label="Pekan sebelumnya"><PhCaretLeft :size="22" /></button>
          <div class="min-w-0 flex-1 text-center">
            <p class="font-bold">{{ formatPanjang(senin) }} – {{ formatPanjang(minggu) }}</p>
            <button v-if="senin !== seninDari(hariIni)" class="text-xs font-semibold text-merah" @click="senin = seninDari(hariIni)">Kembali ke pekan ini</button>
            <p v-else class="text-xs text-teks3">Pekan ini</p>
          </div>
          <button class="tombol-ikon" @click="pindahPekan(1)" aria-label="Pekan berikutnya"><PhCaretRight :size="22" /></button>
        </div>
        <!-- Aksi -->
        <div class="flex flex-wrap gap-2">
          <button class="tombol-garis" @click="pratinjau = true"><PhEye :size="20" weight="duotone" /> Pratinjau cetak</button>
          <template v-if="bolehUbah">
            <button class="tombol-garis" @click="lembarBergilir = true"><PhMagicWand :size="20" weight="duotone" /> Jadwal bergilir</button>
            <button class="tombol-garis" @click="salinPekanLalu"><PhArrowCounterClockwise :size="20" weight="duotone" /> Salin pekan lalu</button>
            <button v-if="berubah" class="tombol-garis" @click="muat">Batalkan perubahan</button>
            <button v-if="berubah" class="tombol-utama" :disabled="menyimpan" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> {{ menyimpan ? 'Menyimpan…' : 'Simpan perubahan' }}</button>
          </template>
        </div>
        <p v-if="bolehUbah" class="flex gap-2 text-xs text-teks3"><PhInfo :size="16" class="mt-0.5 shrink-0" /> Ketuk sel untuk memilih petugas. Shift yang sudah dimulai atau berisi presensi tidak dapat dilepas.</p>
        <div v-if="cek.kosong.length" class="w-klinik flex gap-2 rounded-xl p-3 text-sm font-semibold" style="background: color-mix(in srgb, var(--c) 12%, transparent); color: var(--c)">
          <PhWarning :size="20" weight="bold" class="shrink-0" /> {{ cek.kosong.length }} shift pekan ini belum memiliki petugas.</div>
        <p v-if="memuat" class="py-6 text-center text-teks3">Memuat jadwal…</p>

        <!-- Desktop: tabel shift × hari -->
        <div v-if="!memuat" class="kartu hidden overflow-x-auto lg:block">
          <table class="w-full text-sm">
            <thead><tr class="border-b border-garis">
              <th class="w-44 p-3 text-left">Shift</th>
              <th v-for="t in hari" :key="t" :class="['p-3 text-center', t === hariIni && 'bg-[color-mix(in_srgb,var(--c)_10%,transparent)]']">
                {{ HARI_PENUH[new Date(t + 'T00:00:00Z').getUTCDay()] }}<br><span class="font-normal text-teks3">{{ formatPendek(t) }}</span></th>
            </tr></thead>
            <tbody>
              <tr v-for="s in sesi" :key="s.id" class="border-b border-garis last:border-0">
                <td class="p-3"><p class="font-semibold">{{ s.nama }}</p><p class="text-xs text-teks3">{{ rentangJam(s) }}</p></td>
                <td v-for="t in hari" :key="t" :class="['p-1.5 align-top', t === hariIni && 'bg-[color-mix(in_srgb,var(--c)_6%,transparent)]']">
                  <button :class="['flex min-h-[52px] w-full flex-col items-stretch gap-1 rounded-lg p-1.5 text-left', bolehUbah ? 'hover:bg-permukaan2' : 'cursor-default']" @click="bukaSel(t, s)" :aria-label="`${s.nama} ${formatHari(t)}`">
                    <span v-for="r in isi(t, s)" :key="r.employee_id" :class="['rounded-md px-1.5 py-1 text-xs font-semibold', r.employee_id === saya ? 'bg-[#C7332F] text-white' : 'chip-ikon justify-start']">
                      {{ pendek(r.employee_id) }}<span v-if="r.baru" class="font-normal"> (baru)</span></span>
                    <span v-if="!isi(t, s).length" class="text-xs font-semibold text-merah">Kosong</span>
                  </button>
                  <button v-for="r in isi(t, s).filter(bolehTukar)" :key="'t' + r.id" class="mt-0.5 w-full text-xs font-semibold text-merah" @click="ajukanTukar(r)">Tukar</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- HP: kartu per hari -->
        <div v-if="!memuat" class="space-y-2 lg:hidden">
          <section v-for="t in hari" :key="t" :class="['kartu p-3', t === hariIni && 'ring-2 ring-[color:var(--c)]']">
            <p class="mb-1.5 font-bold">{{ formatHari(t) }} <span v-if="t === hariIni" class="lencana ml-1">Hari ini</span></p>
            <ul class="space-y-1.5">
              <li v-for="s in sesi" :key="s.id" class="flex items-center gap-2">
                <button class="flex min-h-[48px] flex-1 items-center gap-2 rounded-xl border border-garis px-3 py-1.5 text-left" @click="bukaSel(t, s)" :disabled="!bolehUbah">
                  <span class="w-24 shrink-0"><span class="block text-sm font-semibold">{{ s.nama }}</span><span class="block text-xs text-teks3">{{ rentangJam(s) }}</span></span>
                  <span class="flex flex-1 flex-wrap gap-1">
                    <span v-for="r in isi(t, s)" :key="r.employee_id" :class="['rounded-md px-2 py-0.5 text-xs font-semibold', r.employee_id === saya ? 'bg-[#C7332F] text-white' : 'chip-ikon']">{{ pendek(r.employee_id) }}</span>
                    <span v-if="!isi(t, s).length" class="text-xs font-semibold text-merah">Kosong</span>
                  </span>
                </button>
                <button v-for="r in isi(t, s).filter(bolehTukar)" :key="'t' + r.id" class="tombol-ikon text-merah" @click="ajukanTukar(r)" aria-label="Ajukan tukar shift"><PhArrowsLeftRight :size="20" weight="bold" /></button>
              </li>
            </ul>
          </section>
        </div>

        <!-- Ringkasan petugas -->
        <section v-if="!memuat && data.pegawai.length" class="kartu p-4">
          <h3 class="judul-bagian mb-2">Ringkasan pekan ini</h3>
          <ul class="divide-y divide-garis text-sm">
            <li v-for="r in ringkas" :key="r.id" class="flex flex-wrap items-center gap-x-3 gap-y-1 py-2">
              <span :class="['min-w-[10rem] flex-1 font-semibold', r.id === saya && 'text-merah']">{{ r.nama }}</span>
              <span v-for="s in sesi" :key="s.id" class="lencana">{{ s.nama }}: {{ r.perSesi[s.id] }}</span>
              <span class="lencana w-tahfizh">Libur {{ r.libur }} hari</span>
            </li>
          </ul>
        </section>

        <!-- Permintaan tukar shift -->
        <section v-if="data.tukar.length" class="kartu p-4">
          <h3 class="judul-bagian mb-2 flex items-center gap-2"><PhArrowsLeftRight :size="20" weight="duotone" /> Permintaan tukar shift</h3>
          <ul class="divide-y divide-garis">
            <li v-for="t in data.tukar" :key="t.id" class="py-2.5 text-sm">
              <div class="flex flex-wrap items-center gap-2">
                <span class="flex-1 font-semibold">{{ t.pemohon }} → {{ t.penerima }}</span>
                <span :class="['lencana', 'w-' + STATUS_TUKAR[t.status].w]">{{ STATUS_TUKAR[t.status].n }}</span>
              </div>
              <p class="text-teks2">{{ t.sesi_pemohon }} {{ formatPendek(t.tanggal_pemohon) }}
                <template v-if="t.tanggal_penerima"> ⇄ {{ t.sesi_penerima }} {{ formatPendek(t.tanggal_penerima) }}</template><template v-else> (digantikan)</template></p>
              <p class="text-xs text-teks3">Alasan: {{ t.alasan }} · {{ formatRelatif(t.created_at) }}<template v-if="t.catatan_admin"> · Admin: {{ t.catatan_admin }}</template></p>
              <div class="mt-1.5 flex flex-wrap gap-2">
                <template v-if="t.status === 'menunggu_rekan' && t.penerima_id === saya">
                  <button class="tombol-utama min-h-[40px] px-4 text-sm" @click="aksiTukar(t, 'jawab', true)"><PhCheck :size="18" weight="bold" /> Setuju</button>
                  <button class="tombol-garis min-h-[40px] px-4 text-sm" @click="aksiTukar(t, 'jawab', false)"><PhX :size="18" /> Tolak</button>
                </template>
                <template v-if="t.status === 'menunggu_admin' && bolehUbah">
                  <button class="tombol-utama min-h-[40px] px-4 text-sm" @click="aksiTukar(t, 'putuskan', true)"><PhCheck :size="18" weight="bold" /> Setujui tukar</button>
                  <button class="tombol-garis min-h-[40px] px-4 text-sm" @click="aksiTukar(t, 'putuskan', false)"><PhX :size="18" /> Tolak</button>
                </template>
                <button v-if="['menunggu_rekan', 'menunggu_admin'].includes(t.status) && t.pemohon_id === saya" class="tombol-teks min-h-[40px] text-sm" @click="aksiTukar(t, 'batal', false)">Batalkan permintaan</button>
              </div>
            </li>
          </ul>
        </section>
      </div>

      <!-- Sunting sel -->
      <LembarBawah :model-value="!!sel" @update:model-value="(v) => !v && (sel = null)" :judul="sel ? `${sel.s.nama} – ${formatHari(sel.t)}` : ''">
        <div v-if="sel" class="space-y-3 pb-2">
          <p class="text-sm text-teks3">Pilih petugas untuk shift {{ rentangJam(sel.s) }}. Biasanya satu petugas per shift.</p>
          <ul class="divide-y divide-garis rounded-xl border border-garis">
            <li v-for="p in data.pegawai" :key="p.id">
              <label class="flex min-h-[48px] items-center gap-3 px-3">
                <input v-model="sel.pilih" type="checkbox" :value="p.id" :disabled="!!terkunci(p.id)" class="h-5 w-5 accent-[#C7332F]" />
                <span class="flex-1 font-semibold">{{ p.nama }}</span>
                <span v-if="terkunci(p.id)" class="text-xs text-teks3">{{ terkunci(p.id).ada_presensi ? 'Sudah presensi' : 'Sudah dimulai' }}</span>
                <span v-else-if="draf.some((r) => r.employee_id === p.id && r.tanggal === sel.t && r.session_id !== sel.s.id)" class="text-xs text-teks3">Ada shift lain hari ini</span>
              </label>
            </li>
          </ul>
          <p v-if="!data.pegawai.length" class="text-sm text-teks3">Belum ada pegawai yang memegang pola ini. Atur di Pengaturan Presensi → Jadwal pegawai.</p>
          <button class="tombol-utama w-full" @click="terapkanSel"><PhCheck :size="20" weight="bold" /> Terapkan</button>
          <p class="text-xs text-teks3">Perubahan baru tersimpan setelah menekan "Simpan perubahan".</p>
        </div>
      </LembarBawah>
      <LembarBawah :model-value="!!tolak" @update:model-value="(v) => !v && (tolak = null)" judul="Tolak tukar shift">
        <div v-if="tolak" class="space-y-3 pb-2">
          <p class="text-sm text-teks2">{{ tolak.t.pemohon }} → {{ tolak.t.penerima }}, {{ tolak.t.sesi_pemohon }} {{ formatPendek(tolak.t.tanggal_pemohon) }}</p>
          <div><label class="label-isian" for="tl-alasan">Alasan penolakan <span class="text-merah">*</span></label>
            <textarea id="tl-alasan" v-model="tolak.alasan" rows="2" class="isian py-2.5" placeholder="Contoh: petugas pengganti belum memenuhi jeda istirahat" /></div>
          <button class="tombol-utama w-full" @click="aksiTukar(tolak.t, 'putuskan', false, tolak.alasan)"><PhX :size="20" weight="bold" /> Tolak permintaan</button>
        </div>
      </LembarBawah>
      <LembarBergilir v-model="lembarBergilir" :pola="pola" :sesi="sesi" :pegawai="data.pegawai" @tersimpan="setelahBergilir" />
      <LembarTukar v-model="lembarTukar" :pola="pola" :roster="rosterTukar" :pegawai="data.pegawai" :sesi="sesi" :saya="saya" @terkirim="muat" />

      <!-- Dokumen cetak -->
      <DokumenCetak v-model:pratinjau="pratinjau" mendatar :judul="`Jadwal Shift ${pola?.nama || ''}`" :subjudul="`${formatPanjang(senin)} s.d. ${formatPanjang(minggu)}`" :pencetak="sesiPengguna.pengguna?.nama_lengkap">
        <table class="tabel">
          <colgroup><col style="width:16%"><col v-for="t in hari" :key="t" style="width:12%"></colgroup>
          <thead><tr><th>Shift</th><th v-for="t in hari" :key="t">{{ HARI_PENUH[new Date(t + 'T00:00:00Z').getUTCDay()] }}<br>{{ formatPendek(t) }}</th></tr></thead>
          <tbody><tr v-for="s in sesi" :key="s.id">
            <td>{{ s.nama }}<br>{{ rentangJam(s) }}</td>
            <td v-for="t in hari" :key="t" class="tengah">{{ isi(t, s).map((r) => pendek(r.employee_id)).join(', ') || '–' }}</td>
          </tr></tbody>
        </table>
        <p style="margin: 10pt 0 4pt">Rekapitulasi petugas</p>
        <table class="tabel">
          <colgroup><col style="width:6%"><col style="width:40%"><col v-for="s in sesi" :key="s.id" :style="`width:${40 / sesi.length}%`"><col style="width:14%"></colgroup>
          <thead><tr><th>No.</th><th>Nama</th><th v-for="s in sesi" :key="s.id">{{ s.nama }}</th><th>Libur (hari)</th></tr></thead>
          <tbody><tr v-for="(r, i) in ringkas" :key="r.id"><td class="tengah">{{ i + 1 }}</td><td>{{ r.nama }}</td><td v-for="s in sesi" :key="s.id" class="tengah">{{ r.perSesi[s.id] }}</td><td class="tengah">{{ r.libur }}</td></tr></tbody>
        </table>
        <template #ttd>
          <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan_tertulis || 'Direktur', nama: direktur.nama || '', niy: direktur.niy }"
            :kanan="{ jabatan: 'Penyusun Jadwal', nama: sesiPengguna.pengguna?.nama_lengkap || '' }" />
        </template>
      </DokumenCetak>
    </template>
    <p v-if="MODE_DEMO && siap" class="layar-saja mt-3 text-xs text-teks3">Mode demo: jadwal contoh disusun otomatis dan tidak disimpan.</p>
  </div>
</template>
<style scoped>
button.aktif { border-color: color-mix(in srgb, var(--c) 35%, transparent); background: color-mix(in srgb, var(--c) 12%, rgb(var(--permukaan))); }
</style>
