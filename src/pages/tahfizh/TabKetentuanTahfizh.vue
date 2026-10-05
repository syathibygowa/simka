<!-- SIMKA PRO | src/pages/tahfizh/TabKetentuanTahfizh.vue | v1.0 | Fase 5 – Tahap 1 Pengaturan tahfizh dan data hafalan awal | 05/10/2026 -->
<script setup>
// Ketentuan tahfizh per tahun ajaran: umum (KKM, bobot Tajwid/Itqan, batas isian janggal, ambang rekap), target per program
// dan tingkat, rentang predikat, bulan dan pekan efektif, serta penguji. Semua pegawai berhak-lihat dapat membaca;
// hanya pemegang izin atur_tahfizh (atau hak fitur Tahfizh tingkat 3) yang dapat mengubah. Cetak ketentuan F4.
import { ref, computed, onMounted, watch } from 'vue'
import {
  PhGearSix, PhTarget, PhMedal, PhCalendarCheck, PhUserCircleCheck, PhFloppyDisk, PhPlus, PhX, PhArrowCounterClockwise, PhEye, PhLockSimple, PhTrash,
} from '@phosphor-icons/vue'
import { useTahfizh } from '@/stores/tahfizh'
import { useKelompokSantri } from '@/stores/kelompokSantri'
import { usePegawai } from '@/stores/pegawai'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { PROGRAM, JENIS_PENGUJI, HAL_PER_JUZ, formatPosisi, labelBulan, penandaTahfizh } from '@/lib/tahfizh'
import { formatPanjang, hariIniISO } from '@/lib/tanggal'
import { ambilPenandaTangan } from '@/lib/penandatangan'
import LembarBawah from '@/components/LembarBawah.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const tz = useTahfizh(); const kel = useKelompokSantri(); const peg = usePegawai(); const sesi = useSesi(); const ui = useUI()
const boleh = computed(() => tz.hak.atur)
const proses = ref(''); const ta = ref('')
onMounted(async () => {
  await kel.muat(); ta.value = kel.taSekarang?.id || ''
  if (!tz.hakDimuat) await tz.muatHak()
  await muat()
})
async function muat() { try { await tz.muatPengaturan(ta.value) } catch (e) { ui.toast(e.message, 'galat') } salinForm() }
watch(ta, (v, lama) => { if (lama) muat() })
const taObj = computed(() => kel.tahunAjaran.find((t) => t.id === ta.value))
const terkunci = computed(() => !!taObj.value?.terkunci)
const bisaUbah = computed(() => boleh.value && !terkunci.value)

// ---------- Salinan form ----------
const umum = ref({}); const target = ref([]); const predikat = ref([]); const bulan = ref([])
function salinForm() {
  umum.value = { ...(tz.pengaturan || {}) }
  target.value = tz.target.map((x) => ({ ...x })); predikat.value = tz.predikat.map((x) => ({ ...x })); bulan.value = tz.bulan.map((x) => ({ ...x }))
}
const programTarget = ref('reguler')
const barisTarget = computed(() => target.value.filter((t) => t.program === programTarget.value).sort((a, b) => a.tingkat - b.tingkat))
const totalPekan = (smt) => bulan.value.filter((b) => b.semester === smt).reduce((n, b) => n + Number(b.pekan_efektif || 0), 0)

async function simpan(bagian, isi, pesan) {
  proses.value = bagian
  try { await tz.simpanPengaturan(isi); salinForm(); ui.toast(pesan) } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = '' }
}
function simpanUmum() {
  const u = umum.value
  if (!(u.kkm >= 0 && u.kkm <= 100)) return ui.toast('KKM harus 0–100.', 'galat')
  if (Number(u.rekap_memuaskan) > Number(u.rekap_sangat_memuaskan)) return ui.toast('Ambang "Memuaskan" tidak boleh melebihi "Sangat memuaskan".', 'galat')
  simpan('umum', { umum: { kkm: Number(u.kkm), bobot_tajwid: Number(u.bobot_tajwid), bobot_itqan: 100 - Number(u.bobot_tajwid), batas_lonjakan_hal: Number(u.batas_lonjakan_hal),
    rekap_sangat_memuaskan: Number(u.rekap_sangat_memuaskan), rekap_memuaskan: Number(u.rekap_memuaskan), catatan: u.catatan || '' } }, 'Ketentuan umum disimpan.')
}
function simpanTarget() {
  for (const t of target.value) for (const k of ['pekan_hal', 'bulan_hal', 'semester_hal', 'tahun_hal']) if (!(Number(t[k]) >= 0 && Number(t[k]) <= 600)) return ui.toast('Target harus 0–600 halaman.', 'galat')
  simpan('target', { target: target.value.map((t) => ({ program: t.program, tingkat: t.tingkat, pekan_hal: Number(t.pekan_hal), bulan_hal: Number(t.bulan_hal), semester_hal: Number(t.semester_hal), tahun_hal: Number(t.tahun_hal) })) }, 'Target disimpan.')
}
function tambahPredikat() { predikat.value.push({ huruf: '', nilai_min: 0, nilai_maks: 0, deskripsi_rapor: '', deskripsi_sertifikat: '', catatan_akhir: '' }) }
function simpanPredikat() {
  const p = predikat.value
  if (p.length < 2) return ui.toast('Predikat minimal dua rentang.', 'galat')
  if (p.some((x) => !String(x.huruf).trim() || !String(x.deskripsi_rapor).trim())) return ui.toast('Setiap predikat wajib berhuruf dan berdeskripsi rapor.', 'galat')
  if (p.some((x) => Number(x.nilai_min) > Number(x.nilai_maks))) return ui.toast('Batas bawah predikat tidak boleh melebihi batas atasnya.', 'galat')
  simpan('predikat', { predikat: p.map((x) => ({ ...x, nilai_min: Number(x.nilai_min), nilai_maks: Number(x.nilai_maks) })) }, 'Predikat disimpan.')
}
function simpanBulan() { simpan('bulan', { bulan: bulan.value.map((b) => ({ bulan: b.bulan, pekan_efektif: Number(b.pekan_efektif), manual: !!b.manual })) }, 'Pekan efektif disimpan.') }
function otomatis(b) { b.manual = false }

// ---------- Penguji ----------
const lembarPenguji = ref(false); const jenisPenguji = ref('kenaikan'); const cariPeg = ref(''); const catatanPenguji = ref('')
async function bukaPenguji(j) { jenisPenguji.value = j; cariPeg.value = ''; catatanPenguji.value = ''; lembarPenguji.value = true; if (!peg.daftar.length) try { await peg.muat() } catch { /* daftar pegawai tidak tersedia */ } }
const calon = computed(() => {
  const ada = new Set(tz.penguji[jenisPenguji.value].map((p) => p.employee_id)); const q = cariPeg.value.toLowerCase().trim()
  return peg.daftar.filter((p) => p.status_keaktifan === 'aktif' && p.status_akun === 'aktif' && !ada.has(p.id) && (!q || `${p.nama_lengkap} ${p.niy || ''}`.toLowerCase().includes(q))).slice(0, 30)
})
async function tambahPenguji(p) {
  proses.value = 'penguji'
  try { await tz.simpanPenguji(jenisPenguji.value, p.id, true, catatanPenguji.value); lembarPenguji.value = false; ui.toast(`${p.nama_lengkap} ditambahkan sebagai penguji.`) }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = '' }
}
async function hapusPenguji(p) {
  if (!(await ui.konfirmasi({ judul: 'Hapus penguji?', pesan: `${p.nama} tidak lagi menerima daftar tunggu ${JENIS_PENGUJI[jenisPenguji.value].toLowerCase()}.`, ya: 'Hapus', bahaya: true }))) return
  try { await tz.hapusPenguji(p.id); ui.toast('Penguji dihapus.') } catch (e) { ui.toast(e.message, 'galat') }
}
async function aktifkanPenguji(jenis, p) {
  try { await tz.simpanPenguji(jenis, p.employee_id, !p.aktif, p.jabatan === 'Penguji yang ditunjuk' ? '' : p.jabatan); ui.toast(p.aktif ? 'Penguji dinonaktifkan.' : 'Penguji diaktifkan.') } catch (e) { ui.toast(e.message, 'galat') }
}

// ---------- Cetak ----------
const pratinjau = ref(false); const kepala = ref({ jabatan: '', nama: '', niy: '' }); const direktur = ref({ jabatan: 'Direktur', nama: '', niy: '' })
async function cetak() { [kepala.value, direktur.value] = await Promise.all([penandaTahfizh(), ambilPenandaTangan('Direktur')]); pratinjau.value = true }
const juzHal = (h) => `${h} hal${h >= HAL_PER_JUZ ? ` (${formatPosisi(h)})` : ''}`
</script>
<template>
  <div>
    <div class="layar-saja space-y-4">
      <div class="kartu flex flex-wrap items-end gap-3 p-4">
        <div class="min-w-[180px] flex-1"><label class="label-isian" for="kt-ta">Tahun ajaran</label>
          <select id="kt-ta" v-model="ta" class="isian"><option v-for="t in kel.tahunAjaran" :key="t.id" :value="t.id">{{ t.nama }}{{ t.aktif ? ' (aktif)' : '' }}{{ t.terkunci ? ' – arsip' : '' }}</option></select></div>
        <button class="tombol-garis" @click="cetak"><PhEye :size="20" weight="duotone" /> Cetak ketentuan</button>
        <p v-if="!boleh" class="flex w-full items-center gap-2 text-sm text-teks3"><PhLockSimple :size="16" /> Baca saja. Ketentuan diubah oleh admin ber-izin "Mengatur tahfizh".</p>
        <p v-else-if="terkunci" class="flex w-full items-center gap-2 text-sm text-teks3"><PhLockSimple :size="16" /> Tahun ajaran ini sudah dikunci sebagai arsip.</p>
      </div>

      <div v-if="tz.pengaturan" class="grid gap-4 xl:grid-cols-2">
        <!-- Umum -->
        <section class="kartu w-tahfizh p-4">
          <p class="mb-3 flex items-center gap-2 font-bold"><PhGearSix :size="20" weight="duotone" style="color: var(--c)" /> Ketentuan umum</p>
          <div class="grid grid-cols-2 gap-3">
            <div><label class="label-isian" for="kt-kkm">KKM</label><input id="kt-kkm" v-model.number="umum.kkm" type="number" min="0" max="100" step="0.5" class="isian tabular-nums" :disabled="!bisaUbah" />
              <p class="mt-1 text-xs text-teks3">Nilai di atas KKM = Tuntas.</p></div>
            <div><label class="label-isian" for="kt-lonjak">Batas penambahan per sesi</label>
              <div class="relative"><input id="kt-lonjak" v-model.number="umum.batas_lonjakan_hal" type="number" min="1" max="200" class="isian pr-12 tabular-nums" :disabled="!bisaUbah" /><span class="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-teks3">hal</span></div>
              <p class="mt-1 text-xs text-teks3">Lebih dari ini ditandai janggal.</p></div>
            <div><label class="label-isian" for="kt-tajwid">Bobot Tajwid (%)</label><input id="kt-tajwid" v-model.number="umum.bobot_tajwid" type="number" min="0" max="100" class="isian tabular-nums" :disabled="!bisaUbah" /></div>
            <div><p class="label-isian">Bobot Itqan (%)</p><p class="isian flex items-center bg-permukaan2 tabular-nums">{{ 100 - (Number(umum.bobot_tajwid) || 0) }}</p></div>
            <div><label class="label-isian" for="kt-sm">"Sangat memuaskan" mulai (%)</label><input id="kt-sm" v-model.number="umum.rekap_sangat_memuaskan" type="number" min="0" max="100" class="isian tabular-nums" :disabled="!bisaUbah" /></div>
            <div><label class="label-isian" for="kt-m">"Memuaskan" mulai (%)</label><input id="kt-m" v-model.number="umum.rekap_memuaskan" type="number" min="0" max="100" class="isian tabular-nums" :disabled="!bisaUbah" /></div>
          </div>
          <p class="mt-2 text-xs text-teks3">Nilai akhir ujian = Tajwid × bobot + Itqan × bobot. Ambang rekap dipakai pada Rekap ketercapaian target semester (di bawah "Memuaskan" = Perlu ditingkatkan).</p>
          <div class="mt-3"><label class="label-isian" for="kt-cat">Catatan</label><textarea id="kt-cat" v-model="umum.catatan" rows="2" class="isian" :disabled="!bisaUbah" placeholder="Opsional, mis. dasar ketentuan" /></div>
          <button v-if="bisaUbah" class="tombol-utama mt-3 w-full" :disabled="!!proses" @click="simpanUmum"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses === 'umum' ? 'Menyimpan…' : 'Simpan ketentuan umum' }}</button>
        </section>

        <!-- Target -->
        <section class="kartu w-presensi p-4">
          <p class="mb-3 flex items-center gap-2 font-bold"><PhTarget :size="20" weight="duotone" style="color: var(--c)" /> Target capaian sabaq</p>
          <div class="mb-3 grid grid-cols-2 gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" aria-label="Program">
            <button v-for="(n, k) in PROGRAM" :key="k" type="button" role="radio" :aria-checked="programTarget === k" @click="programTarget = k"
              :class="['min-h-[40px] rounded-xl text-sm font-semibold', programTarget === k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">{{ n }}</button>
          </div>
          <div class="overflow-x-auto">
            <table class="w-full min-w-[440px] text-sm">
              <thead class="text-xs text-teks2"><tr><th class="py-1 text-left">Kelas</th><th>Pekan (hal)</th><th>Bulan (hal)</th><th>Semester (hal)</th><th>Tahun (hal)</th></tr></thead>
              <tbody>
                <tr v-for="t in barisTarget" :key="t.tingkat">
                  <td class="py-1 pr-2 font-semibold">{{ t.tingkat }}</td>
                  <td v-for="k in ['pekan_hal', 'bulan_hal', 'semester_hal', 'tahun_hal']" :key="k" class="px-1 py-1">
                    <input v-model.number="t[k]" type="number" min="0" max="600" class="isian min-h-[40px] px-2 text-center tabular-nums" :disabled="!bisaUbah" :aria-label="`Kelas ${t.tingkat} ${k.replace('_hal', '')}`" :title="formatPosisi(t[k])" />
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <p class="mt-2 text-xs text-teks3">Satuan halaman (20 halaman = 1 juz; 100 hal = 5 juz, 200 hal = 10 juz). Status bulanan: <b>Tercapai</b> bila penambahan sabaq sebulan ≥ target pekan × pekan efektif bulan itu.</p>
          <button v-if="bisaUbah" class="tombol-utama mt-3 w-full" :disabled="!!proses" @click="simpanTarget"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses === 'target' ? 'Menyimpan…' : 'Simpan target' }}</button>
        </section>

        <!-- Predikat -->
        <section class="kartu w-pengajuan p-4 xl:col-span-2">
          <div class="mb-3 flex items-center gap-2"><p class="flex flex-1 items-center gap-2 font-bold"><PhMedal :size="20" weight="duotone" style="color: var(--c)" /> Rentang nilai dan predikat</p>
            <button v-if="bisaUbah" class="tombol-garis min-h-[36px] px-3 text-sm" @click="tambahPredikat"><PhPlus :size="16" weight="bold" /> Rentang</button></div>
          <ul class="space-y-3">
            <li v-for="(p, i) in predikat" :key="i" class="rounded-xl border border-garis p-3">
              <div class="grid grid-cols-[4rem_1fr_1fr_auto] items-end gap-2">
                <div><label class="label-isian" :for="`pr-h${i}`">Huruf</label><input :id="`pr-h${i}`" v-model="p.huruf" maxlength="3" class="isian text-center font-bold uppercase" :disabled="!bisaUbah" /></div>
                <div><label class="label-isian" :for="`pr-a${i}`">Nilai dari</label><input :id="`pr-a${i}`" v-model.number="p.nilai_min" type="number" min="0" max="100" step="0.01" class="isian tabular-nums" :disabled="!bisaUbah" /></div>
                <div><label class="label-isian" :for="`pr-b${i}`">sampai</label><input :id="`pr-b${i}`" v-model.number="p.nilai_maks" type="number" min="0" max="100" step="0.01" class="isian tabular-nums" :disabled="!bisaUbah" /></div>
                <button v-if="bisaUbah" class="tombol-ikon h-11 w-11" :aria-label="`Hapus predikat ${p.huruf}`" @click="predikat.splice(i, 1)"><PhX :size="18" /></button>
              </div>
              <div class="mt-2 grid gap-2 sm:grid-cols-2">
                <div><label class="label-isian" :for="`pr-r${i}`">Deskripsi rapor</label><input :id="`pr-r${i}`" v-model="p.deskripsi_rapor" class="isian" :disabled="!bisaUbah" /></div>
                <div><label class="label-isian" :for="`pr-s${i}`">Deskripsi sertifikat</label><input :id="`pr-s${i}`" v-model="p.deskripsi_sertifikat" class="isian" :disabled="!bisaUbah" /></div>
              </div>
              <div class="mt-2"><label class="label-isian" :for="`pr-c${i}`">Catatan akhir</label><textarea :id="`pr-c${i}`" v-model="p.catatan_akhir" rows="2" class="isian" :disabled="!bisaUbah" /></div>
            </li>
          </ul>
          <button v-if="bisaUbah" class="tombol-utama mt-3 w-full" :disabled="!!proses" @click="simpanPredikat"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses === 'predikat' ? 'Menyimpan…' : 'Simpan predikat' }}</button>
        </section>

        <!-- Pekan efektif -->
        <section class="kartu w-agenda p-4">
          <p class="mb-1 flex items-center gap-2 font-bold"><PhCalendarCheck :size="20" weight="duotone" style="color: var(--c)" /> Bulan dan pekan efektif</p>
          <p class="mb-3 text-xs text-teks3">Dihitung otomatis dari kalender pondok (Ahad dan hari libur tahfizh): hari halaqah ÷ 6. Ubah bila berbeda; tombol ↺ mengembalikan ke hitungan otomatis.</p>
          <div class="grid gap-2 sm:grid-cols-2">
            <div v-for="smt in [1, 2]" :key="smt">
              <p class="mb-1 text-sm font-bold">Semester {{ smt }} · {{ totalPekan(smt) }} pekan</p>
              <ul class="space-y-1.5">
                <li v-for="b in bulan.filter((x) => x.semester === smt)" :key="b.bulan" class="flex items-center gap-2 rounded-xl bg-permukaan2 px-3 py-1.5 text-sm">
                  <span class="flex-1">{{ labelBulan(b.bulan) }}<span v-if="b.manual" class="lencana w-laporan ml-1">manual</span></span>
                  <input v-model.number="b.pekan_efektif" type="number" min="0" max="5" class="isian min-h-[36px] w-16 px-2 text-center tabular-nums" :disabled="!bisaUbah" :aria-label="`Pekan efektif ${labelBulan(b.bulan)}`" @input="b.manual = true" />
                  <button v-if="bisaUbah && b.manual" class="tombol-ikon h-9 w-9" :aria-label="`Kembalikan ${labelBulan(b.bulan)} ke otomatis`" @click="otomatis(b)"><PhArrowCounterClockwise :size="16" /></button>
                </li>
              </ul>
            </div>
          </div>
          <button v-if="bisaUbah" class="tombol-utama mt-3 w-full" :disabled="!!proses" @click="simpanBulan"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses === 'bulan' ? 'Menyimpan…' : 'Simpan pekan efektif' }}</button>
        </section>

        <!-- Penguji -->
        <section class="kartu w-pegawai p-4">
          <p class="mb-1 flex items-center gap-2 font-bold"><PhUserCircleCheck :size="20" weight="duotone" style="color: var(--c)" /> Penguji</p>
          <p class="mb-3 text-xs text-teks3">Penguji bawaan mengikuti jabatan di Data Pegawai: kenaikan juz = Kepala/Wakil Kepala Bidang Tahfizh; sertifikasi = Direktur dan Wakil Direktur (termasuk Plt). Muhaffizh tidak menguji santri halaqahnya sendiri.</p>
          <div v-for="j in ['kenaikan', 'sertifikasi']" :key="j" class="mb-3">
            <div class="mb-1 flex items-center gap-2"><p class="flex-1 text-sm font-bold">{{ JENIS_PENGUJI[j] }}</p>
              <button v-if="boleh" class="tombol-garis min-h-[34px] px-3 text-xs" @click="bukaPenguji(j)"><PhPlus :size="14" weight="bold" /> Penguji</button></div>
            <ul class="divide-y divide-garis rounded-xl border border-garis">
              <li v-for="p in tz.penguji[j]" :key="p.employee_id" :class="['flex items-center gap-2 px-3 py-2 text-sm', !p.aktif && 'opacity-60']">
                <span class="min-w-0 flex-1"><b class="block truncate">{{ p.nama }}</b><span class="text-xs text-teks3">{{ p.jabatan }}{{ p.bawaan ? ' · bawaan' : '' }}{{ p.aktif ? '' : ' · nonaktif' }}</span></span>
                <template v-if="boleh && !p.bawaan">
                  <button class="tombol-garis min-h-[34px] px-2 text-xs" @click="aktifkanPenguji(j, p)">{{ p.aktif ? 'Nonaktifkan' : 'Aktifkan' }}</button>
                  <button class="tombol-ikon h-9 w-9" :aria-label="`Hapus ${p.nama}`" @click="jenisPenguji = j; hapusPenguji(p)"><PhTrash :size="16" /></button>
                </template>
              </li>
              <li v-if="!tz.penguji[j].length" class="px-3 py-3 text-sm text-teks3">Belum ada. Isi jabatan struktural di Data Pegawai atau tambahkan penguji.</li>
            </ul>
          </div>
        </section>
      </div>
      <p v-else class="kartu p-6 text-center text-sm text-teks3">Memuat ketentuan tahfizh…</p>
    </div>

    <!-- Tambah penguji -->
    <LembarBawah v-model="lembarPenguji" :judul="`Tambah penguji ${JENIS_PENGUJI[jenisPenguji].toLowerCase()}`">
      <div class="space-y-3 pb-2">
        <input v-model="cariPeg" type="search" class="isian" placeholder="Cari nama atau NIY pegawai" aria-label="Cari pegawai" />
        <div><label class="label-isian" for="pg-cat">Keterangan (opsional)</label><input id="pg-cat" v-model="catatanPenguji" class="isian" placeholder="mis. Koordinator halaqah putri" /></div>
        <ul class="max-h-[45dvh] divide-y divide-garis overflow-y-auto rounded-xl border border-garis">
          <li v-for="p in calon" :key="p.id"><button type="button" class="flex min-h-[52px] w-full items-center gap-3 px-3 text-left text-sm hover:bg-permukaan2" :disabled="!!proses" @click="tambahPenguji(p)">
            <span class="min-w-0 flex-1"><b class="block truncate">{{ p.nama_lengkap }}</b><span class="text-xs text-teks3">{{ [p.jabatan_struktural, ...(p.jabatan_fungsional || [])].filter(Boolean).join(', ') || '–' }}</span></span>
            <PhPlus :size="18" class="text-teks3" /></button></li>
          <li v-if="!calon.length" class="px-3 py-4 text-sm text-teks3">Tidak ada pegawai aktif berakun yang cocok.</li>
        </ul>
      </div>
    </LembarBawah>

    <!-- Cetak ketentuan -->
    <DokumenCetak kop="pondok" judul="Ketentuan Penilaian dan Target Tahfizh" :subjudul="`Tahun Ajaran ${taObj?.nama || ''} · keadaan ${formatPanjang(hariIniISO())}`"
      v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap">
      <template v-if="tz.pengaturan">
        <p style="margin: 0 0 4pt; font-weight: 700">A. Ketentuan umum</p>
        <table class="tabel"><colgroup><col style="width:55%"><col style="width:45%"></colgroup>
          <tbody>
            <tr><td>Kriteria Ketuntasan Minimal (KKM)</td><td>{{ tz.pengaturan.kkm }} (di atas KKM dinyatakan Tuntas)</td></tr>
            <tr><td>Bobot nilai ujian</td><td>Tajwid {{ tz.pengaturan.bobot_tajwid }}%, Itqan {{ tz.pengaturan.bobot_itqan }}%</td></tr>
            <tr><td>Konversi</td><td>20 halaman = 1 juz</td></tr>
            <tr><td>Batas penambahan sabaq per sesi (penanda isian janggal)</td><td>{{ tz.pengaturan.batas_lonjakan_hal }} halaman</td></tr>
            <tr><td>Rekap ketercapaian target semester</td><td>Sangat memuaskan ≥ {{ tz.pengaturan.rekap_sangat_memuaskan }}%; Memuaskan ≥ {{ tz.pengaturan.rekap_memuaskan }}%; di bawahnya Perlu ditingkatkan</td></tr>
          </tbody></table>
        <p style="margin: 10pt 0 4pt; font-weight: 700">B. Target capaian sabaq (halaman)</p>
        <table class="tabel"><colgroup><col style="width:16%"><col style="width:12%"><col style="width:18%"><col style="width:18%"><col style="width:18%"><col style="width:18%"></colgroup>
          <thead><tr><th>Program</th><th>Kelas</th><th>Pekan</th><th>Bulan</th><th>Semester</th><th>Tahun</th></tr></thead>
          <tbody><tr v-for="t in tz.target" :key="t.program + t.tingkat"><td>{{ PROGRAM[t.program] }}</td><td class="tengah">{{ t.tingkat }}</td>
            <td class="tengah">{{ juzHal(t.pekan_hal) }}</td><td class="tengah">{{ juzHal(t.bulan_hal) }}</td><td class="tengah">{{ juzHal(t.semester_hal) }}</td><td class="tengah">{{ juzHal(t.tahun_hal) }}</td></tr></tbody></table>
        <p style="margin: 10pt 0 4pt; font-weight: 700">C. Rentang nilai dan predikat</p>
        <table class="tabel"><colgroup><col style="width:13%"><col style="width:7%"><col style="width:20%"><col style="width:17%"><col style="width:43%"></colgroup>
          <thead><tr><th>Rentang nilai</th><th>Huruf</th><th>Deskripsi rapor</th><th>Deskripsi sertifikat</th><th>Catatan akhir</th></tr></thead>
          <tbody><tr v-for="p in tz.predikat" :key="p.huruf"><td class="tengah">{{ p.nilai_min }}–{{ p.nilai_maks }}</td><td class="tengah">{{ p.huruf }}</td><td>{{ p.deskripsi_rapor }}</td><td>{{ p.deskripsi_sertifikat || '–' }}</td><td>{{ p.catatan_akhir || '–' }}</td></tr></tbody></table>
        <p style="margin: 10pt 0 4pt; font-weight: 700">D. Bulan dan pekan efektif</p>
        <table class="tabel"><colgroup><col style="width:25%"><col style="width:25%"><col style="width:25%"><col style="width:25%"></colgroup>
          <thead><tr><th>Bulan (semester 1)</th><th>Pekan efektif</th><th>Bulan (semester 2)</th><th>Pekan efektif</th></tr></thead>
          <tbody><tr v-for="i in 6" :key="i">
            <td>{{ tz.bulan.filter((b) => b.semester === 1)[i - 1] ? labelBulan(tz.bulan.filter((b) => b.semester === 1)[i - 1].bulan) : '' }}</td><td class="tengah">{{ tz.bulan.filter((b) => b.semester === 1)[i - 1]?.pekan_efektif ?? '' }}</td>
            <td>{{ tz.bulan.filter((b) => b.semester === 2)[i - 1] ? labelBulan(tz.bulan.filter((b) => b.semester === 2)[i - 1].bulan) : '' }}</td><td class="tengah">{{ tz.bulan.filter((b) => b.semester === 2)[i - 1]?.pekan_efektif ?? '' }}</td></tr>
            <tr><th>Jumlah</th><th>{{ tz.pekanSemester(1) }}</th><th>Jumlah</th><th>{{ tz.pekanSemester(2) }}</th></tr></tbody></table>
      </template>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan, nama: direktur.nama, niy: direktur.niy }" :kanan="{ jabatan: kepala.jabatan, nama: kepala.nama, niy: kepala.niy }" />
      </template>
    </DokumenCetak>
  </div>
</template>
