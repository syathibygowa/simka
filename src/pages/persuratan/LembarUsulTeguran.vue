<!-- SIMKA PRO | src/pages/persuratan/LembarUsulTeguran.vue | v1.0 | 14.1.0: usul Surat Teguran (pegawai, saran tingkat, pelanggaran, ringkasan kehadiran) | 17/10/2026 -->
<script setup>
// Lembar usul SP oleh Kepala Bidang (atau pemegang fitur Surat teguran):
//   1. pilih pegawai (anggota unit yang dipimpinnya; tingkat Kelola: semua pegawai), tampil SP aktif dan saran tingkat berikutnya
//   2. tingkat SP-1/2/3 (bawaan = saran), pelanggaran (kategori dari ketentuan), uraian wajib
//   3. periode pelanggaran dan ringkasan kehadiran otomatis dari data presensi (opsional), harapan perbaikan
// Usulan langsung menjadi draf surat keluar di Tata Usaha (status Diperiksa TU); penanda tangan mengikuti ketentuan (bawaan Direktur).
import { ref, computed, watch } from 'vue'
import { PhMagnifyingGlass, PhPaperPlaneTilt, PhInfo, PhWarningOctagon, PhChartBar, PhArrowLeft } from '@phosphor-icons/vue'
import { useTeguran } from '@/stores/teguran'
import { usePersuratan } from '@/stores/persuratan'
import { useUI } from '@/stores/ui'
import { TINGKAT_SP, teksPresensi } from '@/lib/teguran'
import { formatPanjang, hariIniISO } from '@/lib/tanggal'
import { tambahHari } from '@/lib/persuratan'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'

const buka = defineModel({ type: Boolean, default: false })
const props = defineProps({ pegawaiAwal: { type: String, default: '' } })
const emit = defineEmits(['tersimpan'])
const tg = useTeguran(); const ps = usePersuratan(); const ui = useUI()

const cari = ref(''); const pegawai = ref(null); const saran = ref(null); const proses = ref(false)
const f = ref({})
function kosongkan() {
  f.value = { tingkat: 1, kategori: [], uraian: '', mulai: tambahHari(hariIniISO(), -30), selesai: hariIniISO(), presensi: false, harapan: tg.set?.harapan || '' }
  pegawai.value = null; saran.value = null; ringkas.value = null; cari.value = ''
}
watch(buka, async (b) => {
  if (!b) return
  kosongkan()
  try {
    await Promise.all([tg.muatPegawai(), tg.set ? null : tg.muatSet(), ps.penandaTangan.length ? null : ps.muatPenandaTangan()])
    f.value.harapan = tg.set?.harapan || ''
    if (props.pegawaiAwal) { const p = tg.pegawai.find((x) => x.id === props.pegawaiAwal); if (p) pilih(p) }
  } catch (e) { ui.toast(e.message, 'galat') }
})
const daftar = computed(() => {
  const q = cari.value.toLowerCase().trim()
  return tg.pegawai.filter((p) => !q || `${p.nama} ${p.niy || ''} ${p.unit || ''}`.toLowerCase().includes(q)).slice(0, q ? 40 : 12)
})
async function pilih(p) {
  if (p.diusulkan) return ui.toast(`${p.nama} masih memiliki usulan surat teguran yang sedang diproses Tata Usaha.`, 'galat')
  pegawai.value = p; saran.value = null
  try { saran.value = await tg.saran(p.id); f.value.tingkat = saran.value.saran } catch (e) { ui.toast(e.message, 'galat') }
}
// Penanda tangan: ketentuan per tingkat, bawaan Direktur
const penanda = computed(() => {
  const id = tg.set?.penanda?.[f.value.tingkat]
  const s = id && ps.penandaTangan.find((x) => x.id === id)
  return s ? `${s.jabatan} (${s.nama})` : 'Direktur'
})
const masa = computed(() => tg.set?.masa_bulan?.[f.value.tingkat] || 6)
function ubahKategori(k) { const i = f.value.kategori.indexOf(k); if (i >= 0) f.value.kategori.splice(i, 1); else f.value.kategori.push(k) }

// Ringkasan kehadiran (pratinjau; server menghitung ulang saat usulan dikirim)
const ringkas = ref(null); const memuatRingkas = ref(false)
watch(() => [f.value.presensi, f.value.mulai, f.value.selesai, pegawai.value?.id], async () => {
  ringkas.value = null
  if (!f.value.presensi || !pegawai.value || !f.value.mulai || !f.value.selesai) return
  memuatRingkas.value = true
  try { ringkas.value = await tg.ringkasanPresensi(pegawai.value.id, f.value.mulai, f.value.selesai) } catch (e) { ui.toast(e.message, 'galat'); f.value.presensi = false } finally { memuatRingkas.value = false }
})

async function kirim() {
  if (!pegawai.value) return ui.toast('Pilih pegawai lebih dulu.', 'galat')
  if (!f.value.kategori.length) return ui.toast('Pilih sedikitnya satu pelanggaran.', 'galat')
  if (f.value.uraian.trim().length < 10) return ui.toast('Uraikan pelanggaran (minimal 10 huruf).', 'galat')
  if (!(await ui.konfirmasi({ judul: `Usulkan ${TINGKAT_SP[f.value.tingkat].singkat}?`,
    pesan: `${TINGKAT_SP[f.value.tingkat].nama} untuk ${pegawai.value.nama} dikirim ke Tata Usaha untuk diperiksa, lalu ditandatangani ${penanda.value}. Pegawai baru menerima surat setelah terbit.`, ya: 'Kirim usulan' }))) return
  proses.value = true
  try {
    const usulPeriode = f.value.presensi || f.value.kategori.some((k) => /hadir|lambat/i.test(k))
    await tg.usul({ employee_id: pegawai.value.id, tingkat: f.value.tingkat, kategori: f.value.kategori, uraian: f.value.uraian.trim(),
      periode_mulai: usulPeriode ? f.value.mulai : null, periode_selesai: usulPeriode ? f.value.selesai : null, sertakan_presensi: f.value.presensi, harapan: f.value.harapan })
    ui.toast('Usulan terkirim ke Tata Usaha. Anda mendapat notifikasi setelah surat terbit.')
    emit('tersimpan'); buka.value = false
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <LembarBawah v-model="buka" judul="Usulkan Surat Teguran" lebar>
    <div class="space-y-5 pb-2">
      <!-- 1. Pegawai -->
      <section v-if="!pegawai">
        <p class="mb-2 text-sm text-teks3">Pilih pegawai yang akan ditegur. {{ tg.pegawai.length ? '' : 'Tidak ada pegawai yang dapat Anda usulkan.' }}</p>
        <div class="relative"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
          <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari nama, NIY, atau unit" aria-label="Cari pegawai" /></div>
        <ul class="mt-2 divide-y divide-garis">
          <li v-for="p in daftar" :key="p.id">
            <button type="button" class="flex w-full items-center gap-3 px-1 py-3 text-left hover:bg-permukaan2 disabled:opacity-60" :disabled="p.diusulkan" @click="pilih(p)">
              <span class="min-w-0 flex-1"><span class="block font-semibold">{{ p.nama }}</span>
                <span class="block truncate text-xs text-teks3">{{ p.niy || 'NIY –' }} · {{ p.unit || '–' }}</span></span>
              <span v-if="p.diusulkan" class="lencana w-shift">Sedang diproses</span>
              <span v-else-if="p.sp_aktif" :class="['lencana', 'w-' + TINGKAT_SP[p.sp_aktif].w]">{{ TINGKAT_SP[p.sp_aktif].singkat }} aktif</span>
            </button>
          </li>
        </ul>
      </section>

      <template v-else>
        <div class="kartu w-pegawai flex items-center gap-3 p-4">
          <div class="min-w-0 flex-1"><p class="font-bold">{{ pegawai.nama }}</p><p class="text-sm text-teks3">{{ pegawai.niy || 'NIY –' }} · {{ pegawai.unit || '–' }}</p></div>
          <button type="button" class="tombol-teks min-h-[40px] px-2 text-sm" @click="pegawai = null; saran = null"><PhArrowLeft :size="16" /> Ganti</button>
        </div>
        <div v-if="saran?.aktif?.length" class="w-klinik rounded-xl border border-garis p-3 text-sm">
          <p class="flex items-center gap-2 font-semibold" style="color: var(--c)"><PhWarningOctagon :size="18" weight="duotone" /> Surat teguran yang masih berlaku</p>
          <ul class="mt-1 space-y-0.5 text-teks2">
            <li v-for="a in saran.aktif" :key="a.id">{{ TINGKAT_SP[a.tingkat].singkat }} {{ a.nomor || '' }} – berlaku sampai {{ formatPanjang(a.berlaku_sampai) }}</li>
          </ul>
          <p v-if="saran.sp3_aktif" class="mt-1 font-semibold text-merah">Pegawai ini masih memiliki SP-3 yang berlaku. Pelanggaran berikutnya diselesaikan pimpinan sesuai ketentuan kepegawaian.</p>
        </div>

        <!-- 2. Tingkat -->
        <div>
          <p class="label-isian">Tingkat surat teguran</p>
          <div class="grid grid-cols-3 gap-2" role="radiogroup" aria-label="Tingkat surat teguran">
            <button v-for="t in [1, 2, 3]" :key="t" type="button" role="radio" :aria-checked="f.tingkat === t" @click="f.tingkat = t"
              :class="['min-h-[56px] rounded-xl border px-2 text-center', 'w-' + TINGKAT_SP[t].w, f.tingkat === t ? 'pilih border-transparent font-bold' : 'border-garis text-teks2']">
              <span class="block text-base font-extrabold" style="color: var(--c)">{{ TINGKAT_SP[t].singkat }}</span>
              <span class="block text-[11px]">{{ saran?.saran === t ? 'Disarankan' : ['Pertama', 'Kedua', 'Ketiga'][t - 1] }}</span>
            </button>
          </div>
          <p class="mt-1 text-xs text-teks3">Berlaku {{ masa }} bulan sejak tanggal surat. Ditandatangani {{ penanda }}.</p>
        </div>

        <!-- 3. Pelanggaran -->
        <div>
          <p class="label-isian">Pelanggaran <span class="text-merah">*</span></p>
          <div class="grid gap-1.5 sm:grid-cols-2">
            <label v-for="k in tg.set?.kategori || []" :key="k" :class="['flex min-h-[44px] cursor-pointer items-center gap-3 rounded-xl border px-3 py-2 text-sm', f.kategori.includes(k) ? 'border-[#C7332F] font-semibold' : 'border-garis']">
              <input type="checkbox" class="h-5 w-5 accent-[#C7332F]" :checked="f.kategori.includes(k)" @change="ubahKategori(k)" /> {{ k }}</label>
          </div>
        </div>
        <div><label class="label-isian" for="sp-uraian">Uraian pelanggaran <span class="text-merah">*</span></label>
          <textarea id="sp-uraian" v-model="f.uraian" rows="3" class="isian" placeholder="Contoh: Tidak hadir mengajar pada jam pertama tanpa pemberitahuan sebanyak empat kali dalam bulan ini." />
          <p class="mt-1 text-xs text-teks3">Ditulis apa adanya di dalam surat. Hindari menyebut hal pribadi yang tidak terkait pelanggaran.</p></div>

        <!-- 4. Periode dan kehadiran -->
        <div class="kartu w-presensi space-y-3 p-4">
          <label class="flex min-h-[44px] cursor-pointer items-center gap-3 font-semibold"><input v-model="f.presensi" type="checkbox" class="h-5 w-5 accent-[#C7332F]" />
            <PhChartBar :size="20" weight="duotone" style="color: var(--c)" /> Sertakan ringkasan kehadiran dari data presensi</label>
          <div class="grid grid-cols-2 gap-3"><InputTanggal v-model="f.mulai" label="Periode dari" /><InputTanggal v-model="f.selesai" label="Sampai" /></div>
          <p v-if="memuatRingkas" class="text-sm text-teks3">Menghitung ringkasan kehadiran…</p>
          <p v-else-if="ringkas" class="rounded-lg bg-permukaan2 p-3 text-sm">{{ teksPresensi(ringkas) }}</p>
        </div>

        <div><label class="label-isian" for="sp-harapan">Harapan perbaikan</label>
          <textarea id="sp-harapan" v-model="f.harapan" rows="2" class="isian" />
          <p class="mt-1 text-xs text-teks3">Disambung dengan kalimat "yang bersangkutan diminta untuk …".</p></div>

        <p class="flex gap-2 rounded-xl bg-permukaan2 p-3 text-sm text-teks2"><PhInfo :size="18" class="mt-0.5 shrink-0" />
          Usulan menjadi draf surat di Tata Usaha. Tata Usaha memeriksa dan mengajukan tanda tangan; nomor surat terbit setelah ditandatangani. Pegawai menerima notifikasi setelah surat terbit.</p>
        <button class="tombol-utama w-full" :disabled="proses" @click="kirim"><PhPaperPlaneTilt :size="20" weight="duotone" /> {{ proses ? 'Mengirim…' : 'Kirim usulan ke Tata Usaha' }}</button>
      </template>
    </div>
  </LembarBawah>
</template>
<style scoped>
.pilih { background: color-mix(in srgb, var(--c) 14%, rgb(var(--permukaan))); box-shadow: inset 0 0 0 2px var(--c); }
</style>
