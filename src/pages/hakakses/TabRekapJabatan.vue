<!-- SIMKA PRO | src/pages/hakakses/TabRekapJabatan.vue | v1.0 | Perbaikan 13.9.0: ceklist fitur per jabatan fungsional, struktural, dan bidang (cetak F4) | 16/10/2026 -->
<script setup>
// Rekap hak akses fitur dalam satu tabel centang (khusus superadmin):
//   baris = fitur (dengan menu yang dikendalikan), kolom = jabatan fungsional / jabatan struktural / bidang,
//   sel = tingkat akses (Lihat, Input/ubah, Kelola). Untuk bidang: tambahan (+) atau pembatasan (✕).
// Desktop: matriks. HP: kartu per jabatan. Cetak F4 mendatar berkop dengan tanda tangan.
// Akses efektif seseorang = gabungan jabatan → bidang → individu, ditambah hak otomatis karena tugasnya
// (wali kelas, musyrif, muhaffizh, pembina, guru mapel pada kelompok/penugasan masing-masing).
import { ref, computed, onMounted } from 'vue'
import { PhIdentificationBadge, PhCrown, PhTreeStructure, PhMagnifyingGlass, PhPrinter, PhCaretDown, PhCheckCircle, PhMinus, PhProhibit } from '@phosphor-icons/vue'
import { useAkses, TINGKAT } from '@/stores/akses'
import { useOrganisasi } from '@/stores/organisasi'
import { useLembaga } from '@/stores/lembaga'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const akses = useAkses(); const org = useOrganisasi(); const lembaga = useLembaga(); const sesi = useSesi(); const ui = useUI()
const siap = ref(false)
onMounted(async () => {
  try { await Promise.all([akses.dimuat ? null : akses.muat(), org.muat(), lembaga.muat()]) } catch (e) { ui.toast(e.message, 'galat') }
  siap.value = true
})

const MODE = [
  { k: 'fungsional', n: 'Jabatan fungsional', ikon: PhIdentificationBadge, w: 'presensi' },
  { k: 'struktural', n: 'Jabatan struktural', ikon: PhCrown, w: 'agenda' },
  { k: 'bidang', n: 'Bidang/unit', ikon: PhTreeStructure, w: 'santri' },
]
const mode = ref('fungsional'); const cari = ref(''); const ringkas = ref(true)
const SINGKAT = { 1: 'L', 2: 'U', 3: 'K' }

const semuaSasaran = computed(() => {
  if (mode.value === 'fungsional') return org.fungsional.filter((j) => j.aktif).map((j) => ({ id: j.id, n: j.nama }))
  if (mode.value === 'struktural') return [...org.struktural].filter((j) => j.aktif).sort((a, b) => a.tingkat - b.tingkat).map((j) => ({ id: j.id, n: j.nama }))
  return org.datar.filter((u) => u.aktif).map((u) => ({ id: u.id, n: u.nama }))
})
const aturan = (id, kode) => akses.grants[`${mode.value}:${id}:${kode}`] || null
const jumlah = (id) => akses.fitur.filter((f) => { const g = aturan(id, f.kode); return g && g.mode === 'tambah' }).length
const sasaran = computed(() => {
  const q = cari.value.toLowerCase().trim()
  return semuaSasaran.value.filter((x) => (!q || x.n.toLowerCase().includes(q)) && (!ringkas.value || akses.fitur.some((f) => aturan(x.id, f.kode))))
})
const grup = computed(() => { let no = 0; const k = {}; for (const f of akses.fitur) (k[f.kelompok] ||= []).push({ ...f, no: ++no }); return Object.entries(k) })
const pemegang = (kode) => sasaran.value.filter((x) => aturan(x.id, kode)?.mode === 'tambah').length
/** Teks sel: tambah t → "Lihat"/"Input/ubah"/"Kelola"; cabut t → batasan */
const teksSel = (g) => (!g ? '' : g.mode === 'tambah' ? TINGKAT[g.tingkat] : g.tingkat === 1 ? 'Dicabut' : `Maks. ${TINGKAT[g.tingkat - 1].toLowerCase()}`)
const cetakSel = (g) => (!g ? '' : g.mode === 'tambah' ? `✓ ${SINGKAT[g.tingkat]}` : `✕${g.tingkat > 1 ? ' ≤' + SINGKAT[g.tingkat - 1] : ''}`)
const WARNA = { 1: 'w-pegawai', 2: 'w-presensi', 3: 'w-pengaturan' }

const buka = ref({})
const pratinjau = ref(false)
const direktur = computed(() => lembaga.signatories?.find((s) => /^direktur$/i.test(s.jabatan_tertulis)) || lembaga.signatories?.[0] || {})
const namaMode = computed(() => MODE.find((m) => m.k === mode.value).n)
const lebarKol = computed(() => (sasaran.value.length ? Math.max(3.5, Math.min(10, 66 / sasaran.value.length)) : 10))
</script>
<template>
  <div>
    <p v-if="!siap" class="py-10 text-center text-teks3">Memuat rekap hak akses…</p>
    <template v-else>
      <nav class="bilah-tab kecil mb-3" role="tablist" aria-label="Jenis sasaran">
        <button v-for="m in MODE" :key="m.k" role="tab" :aria-selected="mode === m.k" :class="['tab-garis', 'w-' + m.w, mode === m.k && 'aktif']" @click="mode = m.k; buka = {}">
          <component :is="m.ikon" :size="18" weight="duotone" /><span>{{ m.n }}</span></button>
      </nav>
      <div class="flex flex-wrap items-center gap-2">
        <div class="relative min-w-[220px] flex-1">
          <PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
          <input v-model="cari" type="search" class="isian pl-11" :placeholder="mode === 'bidang' ? 'Cari bidang/unit' : 'Cari jabatan, mis. muhaffizh, musyrif, kepala bidang'" aria-label="Cari" />
        </div>
        <label class="tombol-garis cursor-pointer px-3 text-sm"><input v-model="ringkas" type="checkbox" class="h-4 w-4 accent-[#C7332F]" /> Hanya yang punya aturan</label>
        <button class="tombol-utama min-h-[44px] px-4 text-sm" :disabled="!sasaran.length" @click="pratinjau = true"><PhPrinter :size="18" weight="duotone" /> Cetak ceklist</button>
      </div>
      <p class="mt-2 text-xs text-teks3">L = Lihat · U = Input/ubah · K = Kelola. {{ mode === 'bidang' ? 'Aturan bidang menambah (✓) atau membatasi (✕) akses seluruh pegawai di bidang/unit tersebut beserta cabangnya.' : 'Akses ini dimiliki setiap pegawai yang memegang jabatan tersebut.' }}
        Tugas yang ditetapkan (wali kelas, musyrif, muhaffizh, pembina, guru mapel) otomatis dapat mengisi kelompok/penugasannya sendiri.</p>

      <p v-if="!sasaran.length" class="kartu mt-4 p-8 text-center text-sm text-teks3">{{ ringkas ? 'Belum ada aturan untuk ' + namaMode.toLowerCase() + '. Matikan "Hanya yang punya aturan" untuk melihat semua.' : 'Tidak ada data.' }}</p>
      <template v-else>
        <!-- Desktop -->
        <div class="kartu mt-4 hidden overflow-x-auto lg:block">
          <table class="w-full text-sm">
            <thead><tr class="border-b border-garis bg-permukaan2 text-teks2">
              <th class="sticky left-0 z-10 w-10 bg-permukaan2 px-3 py-3 text-center font-bold">No.</th>
              <th class="sticky left-10 z-10 min-w-[260px] bg-permukaan2 px-3 py-3 text-left font-bold">Fitur dan menu</th>
              <th v-for="x in sasaran" :key="x.id" class="min-w-[92px] px-2 py-3 text-center align-bottom text-xs font-bold text-teks">{{ x.n }}</th>
            </tr></thead>
            <tbody v-for="[kel, daftar] in grup" :key="kel">
              <tr><td :colspan="sasaran.length + 2" class="bg-permukaan2/60 px-3 py-1.5 text-xs font-bold uppercase tracking-wide text-teks3">{{ kel }}</td></tr>
              <tr v-for="f in daftar" :key="f.kode" class="border-t border-garis hover:bg-permukaan2/50">
                <td class="sticky left-0 bg-permukaan px-3 py-2 text-center tabular-nums text-teks3">{{ f.no }}</td>
                <td class="sticky left-10 bg-permukaan px-3 py-2"><b class="block">{{ f.nama }}</b><span class="text-xs text-teks3">{{ f.menu }}</span></td>
                <td v-for="x in sasaran" :key="x.id" class="px-2 py-2 text-center">
                  <template v-if="aturan(x.id, f.kode)">
                    <span v-if="aturan(x.id, f.kode).mode === 'tambah'" :class="['sel', WARNA[aturan(x.id, f.kode).tingkat]]" :title="f.arti?.[aturan(x.id, f.kode).tingkat]">
                      <PhCheckCircle :size="16" weight="fill" /> {{ teksSel(aturan(x.id, f.kode)) }}</span>
                    <span v-else class="sel w-klinik"><PhProhibit :size="16" weight="bold" /> {{ teksSel(aturan(x.id, f.kode)) }}</span>
                  </template>
                  <PhMinus v-else :size="16" class="mx-auto text-teks3/50" />
                </td>
              </tr>
            </tbody>
            <tfoot><tr class="border-t-2 border-garis bg-permukaan2 font-bold">
              <td class="sticky left-0 bg-permukaan2" /><td class="sticky left-10 bg-permukaan2 px-3 py-2.5">Jumlah fitur</td>
              <td v-for="x in sasaran" :key="x.id" class="px-2 py-2.5 text-center tabular-nums">{{ jumlah(x.id) }}</td>
            </tr></tfoot>
          </table>
        </div>

        <!-- HP -->
        <ul class="mt-4 space-y-3 lg:hidden">
          <li v-for="x in sasaran" :key="x.id" :class="['kartu overflow-hidden', 'w-' + MODE.find((m) => m.k === mode).w]">
            <button type="button" class="flex w-full items-center gap-3 p-4 text-left" :aria-expanded="!!buka[x.id]" @click="buka[x.id] = !buka[x.id]">
              <span class="chip-ikon h-11 w-11 shrink-0"><component :is="MODE.find((m) => m.k === mode).ikon" :size="22" weight="duotone" /></span>
              <b class="min-w-0 flex-1">{{ x.n }}</b>
              <span class="shrink-0 text-right"><b class="block text-lg tabular-nums" style="color: var(--c)">{{ jumlah(x.id) }}</b><span class="text-xs text-teks3">fitur</span></span>
              <PhCaretDown :size="18" :class="['shrink-0 text-teks3 transition', buka[x.id] && 'rotate-180']" />
            </button>
            <div v-if="buka[x.id]" class="border-t border-garis px-4 pb-3">
              <template v-for="[kel, daftar] in grup" :key="kel">
                <p class="mt-3 text-xs font-bold uppercase tracking-wide text-teks3">{{ kel }}</p>
                <ul class="mt-1 space-y-1.5">
                  <li v-for="f in daftar" :key="f.kode" class="flex items-start gap-2 text-sm" :class="aturan(x.id, f.kode) ? 'text-teks' : 'text-teks3'">
                    <PhCheckCircle v-if="aturan(x.id, f.kode)?.mode === 'tambah'" :size="20" weight="fill" class="mt-0.5 shrink-0 text-[#1E7D4F] dark:text-[#6FD19A]" />
                    <PhProhibit v-else-if="aturan(x.id, f.kode)" :size="20" class="mt-0.5 shrink-0 text-merah" />
                    <PhMinus v-else :size="20" class="mt-0.5 shrink-0 opacity-50" />
                    <span class="min-w-0 flex-1"><span class="tabular-nums">{{ f.no }}.</span> {{ f.nama }}
                      <span v-if="aturan(x.id, f.kode)" class="block text-xs font-semibold">{{ teksSel(aturan(x.id, f.kode)) }}<template v-if="aturan(x.id, f.kode).mode === 'tambah'">: {{ f.arti?.[aturan(x.id, f.kode).tingkat] }}</template></span></span>
                  </li>
                </ul>
              </template>
            </div>
          </li>
        </ul>
      </template>
    </template>

    <DokumenCetak v-model:pratinjau="pratinjau" mendatar :judul="`Ceklist Hak Akses Fitur per ${namaMode}`" :subjudul="`Keadaan per ${new Date().toLocaleDateString('id-ID', { day: '2-digit', month: 'long', year: 'numeric' })}`"
      :nama-berkas="`Ceklist-Hak-Akses-${namaMode.replace(/[^A-Za-z]+/g, '-')}`" :pencetak="sesi.pengguna?.nama_lengkap">
      <table class="tabel" :style="sasaran.length > 10 ? 'font-size: 8.5pt' : ''">
        <colgroup><col style="width:3.5%"><col :style="`width:${96.5 - lebarKol * sasaran.length}%`"><col v-for="x in sasaran" :key="x.id" :style="`width:${lebarKol}%`"></colgroup>
        <thead><tr><th>No.</th><th>Fitur (Menu)</th><th v-for="x in sasaran" :key="x.id">{{ x.n }}</th></tr></thead>
        <tbody>
          <template v-for="[kel, daftar] in grup" :key="kel">
            <tr><td /><td :colspan="sasaran.length + 1"><i>{{ kel }}</i></td></tr>
            <tr v-for="f in daftar" :key="f.kode">
              <td class="tengah">{{ f.no }}</td><td>{{ f.nama }}<br><span style="font-size: 8pt">{{ f.menu }}</span></td>
              <td v-for="x in sasaran" :key="x.id" class="tengah">{{ cetakSel(aturan(x.id, f.kode)) }}</td>
            </tr>
          </template>
          <tr><td /><td>Jumlah fitur</td><td v-for="x in sasaran" :key="x.id" class="tengah">{{ jumlah(x.id) }}</td></tr>
        </tbody>
      </table>
      <p style="margin-top: 6pt; font-size: 9pt">✓ L = Lihat, ✓ U = Input/ubah, ✓ K = Kelola{{ mode === 'bidang' ? '; ✕ = akses dicabut, ✕ ≤L/≤U = dibatasi paling tinggi lihat/input' : '' }}. Tugas yang ditetapkan (wali kelas, musyrif, muhaffizh, pembina, guru mapel) otomatis mengisi kelompok/penugasannya sendiri.</p>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan_tertulis || 'Direktur', nama: direktur.nama || '', niy: direktur.niy }"
          :kanan="{ jabatan: 'Superadmin SIMKA PRO', nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
      </template>
    </DokumenCetak>
  </div>
</template>
<style scoped>
.sel { display: inline-flex; align-items: center; gap: .25rem; border-radius: 9999px; padding: .15rem .5rem; font-size: .75rem; font-weight: 700; white-space: nowrap;
  color: var(--c); background: color-mix(in srgb, var(--c) 13%, rgb(var(--permukaan))); }
</style>
