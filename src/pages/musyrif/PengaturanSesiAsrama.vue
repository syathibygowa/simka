<!-- SIMKA PRO | src/pages/musyrif/PengaturanSesiAsrama.vue | v1.0 | 14.35.0: pengaturan peran sesi asrama dan butir pengontrolan kamar | 30/10/2026 -->
<script setup>
// Musyrif → Pengaturan (admin, superadmin, pemegang hak Absensi asrama tingkat atur).
//   1. Peran sesi: setiap sesi pada pola presensi musyrif ditetapkan "Wajib absen" atau "Absen opsional" (sesi kontrol).
//      Jumlah dan jam sesi mengikuti Presensi → Pola dan sesi; bila pola berubah (3, 4, 5 waktu, …) daftar ini ikut berubah.
//   2. Butir pengontrolan: ceklist yang diisi musyrif setiap sesi; dapat berlaku di semua sesi atau sesi tertentu saja.
import { ref, computed, onMounted } from 'vue'
import { PhListChecks, PhShieldCheck, PhPlus, PhTrash, PhArrowUp, PhArrowDown, PhFloppyDisk, PhInfo } from '@phosphor-icons/vue'
import { useMusyrif } from '@/stores/musyrif'
import { useUI } from '@/stores/ui'
import { MODE_SESI } from '@/lib/asrama'

const mu = useMusyrif(); const ui = useUI()
const d = ref(null); const mode = ref({}); const butir = ref([]); const menyimpan = ref(false); const galat = ref('')
async function muat() {
  galat.value = ''
  try {
    d.value = await mu.pengaturanKontrol()
    mode.value = Object.fromEntries(d.value.sesi.map((s) => [s.kode, s.mode]))
    butir.value = (d.value.butir || []).map((b) => ({ kode: b.kode, teks: b.teks, sesi: [...(b.sesi || [])] }))
  } catch (e) { galat.value = e.message }
}
onMounted(muat)
const boleh = computed(() => !!d.value?.boleh_atur)
const jumlahWajib = computed(() => Object.values(mode.value).filter((m) => m === 'wajib').length)
const tambah = () => butir.value.push({ kode: '', teks: '', sesi: [] })
const hapus = (i) => butir.value.splice(i, 1)
const pindah = (i, n) => { const j = i + n; if (j < 0 || j >= butir.value.length) return; const [x] = butir.value.splice(i, 1); butir.value.splice(j, 0, x) }
const togSesi = (b, k) => { const i = b.sesi.indexOf(k); if (i >= 0) b.sesi.splice(i, 1); else b.sesi.push(k) }
const HARI = ['Ahd', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab']
const teksHari = (h) => (h?.length === 7 ? 'Setiap hari' : (h || []).map((x) => HARI[x]).join(', '))

async function simpan() {
  if (!jumlahWajib.value) return ui.toast('Tetapkan minimal satu sesi yang wajib absensi santri.', 'galat')
  const bersih = butir.value.filter((b) => b.teks.trim().length >= 3)
  if (!bersih.length) return ui.toast('Isi minimal satu butir pengontrolan (minimal 3 huruf).', 'galat')
  menyimpan.value = true
  try { await mu.simpanPengaturanKontrol({ mode: mode.value, butir: bersih }); ui.toast('Pengaturan sesi asrama tersimpan.'); await muat() }
  catch (e) { ui.toast(e.message, 'galat') } finally { menyimpan.value = false }
}
</script>
<template>
  <div class="space-y-4">
    <p v-if="galat" class="kartu w-klinik p-5 text-sm font-semibold" style="color: var(--c)">Pengaturan gagal dimuat: {{ galat }} Pastikan migrasi SQL 14900 sudah dijalankan.</p>
    <p v-else-if="!d" class="kartu p-8 text-center text-sm text-teks3">Memuat pengaturan…</p>
    <template v-else>
      <section class="kartu w-musyrif p-4 sm:p-5">
        <div class="mb-1 flex items-center gap-2"><PhListChecks :size="22" weight="duotone" style="color: var(--c)" /><h2 class="judul-bagian">Peran sesi asrama</h2></div>
        <p class="mb-3 text-sm text-teks2">Sesi mengikuti pola presensi <b>{{ d.pola?.nama || 'Musyrif' }}</b> (Presensi → Pola dan sesi). Tentukan sesi yang <b>wajib</b> absensi santri;
          sesi lainnya menjadi sesi kontrol (absensi santri boleh diisi, tidak wajib). Pengontrolan kamar dicatat pada semua sesi.</p>
        <ul class="divide-y divide-garis">
          <li v-for="s in d.sesi" :key="s.kode" class="flex flex-wrap items-center gap-3 py-3">
            <div class="min-w-[160px] flex-1"><p class="font-semibold">{{ s.nama }}</p>
              <p class="text-xs text-teks3">{{ s.jam_mulai.replace(':', '.') }}–{{ s.jam_selesai.replace(':', '.') }} WITA · {{ teksHari(s.hari) }}{{ s.opsional_pegawai ? ' · presensi pegawai opsional' : '' }}</p></div>
            <div class="grid grid-cols-2 gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" :aria-label="'Peran ' + s.nama">
              <button v-for="(m, k) in MODE_SESI" :key="k" type="button" role="radio" :aria-checked="mode[s.kode] === k" :disabled="!boleh" @click="mode[s.kode] = k"
                :class="['min-h-[40px] rounded-xl px-3 text-sm font-semibold', mode[s.kode] === k ? 'w-' + m.w + ' bg-permukaan shadow-kartu' : 'text-teks2']"
                :style="mode[s.kode] === k ? 'color: var(--c)' : ''">{{ m.n }}</button>
            </div>
          </li>
          <li v-if="!d.sesi.length" class="py-4 text-sm text-teks3">Pola presensi musyrif belum memiliki sesi aktif.</li>
        </ul>
        <p class="mt-2 text-xs text-teks3">{{ jumlahWajib }} sesi wajib absen · {{ d.sesi.length - jumlahWajib }} sesi kontrol.</p>
      </section>

      <section class="kartu w-shift p-4 sm:p-5">
        <div class="mb-1 flex items-center gap-2"><PhShieldCheck :size="22" weight="duotone" style="color: var(--c)" /><h2 class="judul-bagian flex-1">Butir pengontrolan kamar</h2>
          <button v-if="boleh" class="tombol-garis min-h-[40px] px-3 text-sm" @click="tambah"><PhPlus :size="18" /> Butir</button></div>
        <p class="mb-3 text-sm text-teks2">Ceklist yang dicentang musyrif setiap sesi dan ikut dalam laporan WA. Pilih sesi tertentu bila butir hanya berlaku pada sesi itu; tanpa pilihan = semua sesi.</p>
        <ul class="space-y-2">
          <li v-for="(b, i) in butir" :key="i" class="rounded-xl border border-garis p-3">
            <div class="flex items-center gap-2">
              <span class="w-6 text-center text-sm font-bold text-teks3">{{ i + 1 }}</span>
              <label class="sr-only" :for="'bt-' + i">Butir {{ i + 1 }}</label>
              <input :id="'bt-' + i" v-model="b.teks" class="isian flex-1" placeholder="Contoh: Kamar sudah terkunci" :disabled="!boleh" maxlength="120" />
              <template v-if="boleh">
                <button class="tombol-ikon h-9 w-9" :disabled="i === 0" aria-label="Naikkan" @click="pindah(i, -1)"><PhArrowUp :size="16" /></button>
                <button class="tombol-ikon h-9 w-9" :disabled="i === butir.length - 1" aria-label="Turunkan" @click="pindah(i, 1)"><PhArrowDown :size="16" /></button>
                <button class="tombol-ikon h-9 w-9 text-merah" aria-label="Hapus butir" @click="hapus(i)"><PhTrash :size="16" /></button>
              </template>
            </div>
            <div class="mt-2 flex flex-wrap items-center gap-1 pl-8">
              <span class="text-xs text-teks3">Berlaku:</span>
              <span v-if="!b.sesi.length" class="lencana w-presensi">Semua sesi</span>
              <button v-for="s in d.sesi" :key="s.kode" type="button" :disabled="!boleh" @click="togSesi(b, s.kode)"
                :class="['rounded-full border px-2.5 py-1 text-xs font-semibold', b.sesi.includes(s.kode) ? 'w-shift border-[color:var(--c)] text-[color:var(--c)]' : 'border-garis text-teks3']">{{ s.nama }}</button>
            </div>
          </li>
          <li v-if="!butir.length" class="text-sm text-teks3">Belum ada butir. Tekan "Butir" untuk menambah.</li>
        </ul>
      </section>

      <div v-if="boleh" class="flex justify-end"><button class="tombol-utama min-w-[200px]" :disabled="menyimpan" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> Simpan pengaturan</button></div>
      <p v-else class="flex items-center gap-2 text-sm text-teks3"><PhInfo :size="18" /> Pengaturan ini hanya dapat diubah admin atau pemegang hak Absensi asrama tingkat atur.</p>
    </template>
  </div>
</template>
