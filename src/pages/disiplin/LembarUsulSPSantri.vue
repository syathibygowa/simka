<!-- SIMKA PRO | src/pages/disiplin/LembarUsulSPSantri.vue | v1.0 | 14.6.0: usul Surat Peringatan santri (pelanggaran dasar, tingkat, sanksi) | 18/10/2026 -->
<script setup>
// Lembar usul SP santri oleh Bidang Kesantrian:
//   1. pilih santri (atau dikunci dari riwayat), tampil SP aktif, pelanggaran terbuka, dan saran tingkat berikutnya
//   2. centang catatan pelanggaran yang menjadi dasar (bawaan: semua yang belum ditindaklanjuti)
//   3. tingkat SP-1/2/3, sanksi (pilihan dari ketentuan per tingkat + sanksi tambahan), uraian, harapan
// Usulan langsung menjadi draf surat keluar di Tata Usaha (Diperiksa TU); penanda tangan mengikuti ketentuan (bawaan Direktur).
import { ref, computed, watch } from 'vue'
import { PhMagnifyingGlass, PhPaperPlaneTilt, PhInfo, PhWarningOctagon, PhArrowLeft, PhWarning } from '@phosphor-icons/vue'
import { useDisiplin } from '@/stores/disiplin'
import { usePersuratan } from '@/stores/persuratan'
import { useUI } from '@/stores/ui'
import { TINGKAT_SP_SANTRI, TINGKAT_PELANGGARAN, teksTerbuka } from '@/lib/disiplin'
import { formatPanjang, formatPendek } from '@/lib/tanggal'
import LembarBawah from '@/components/LembarBawah.vue'

const buka = defineModel({ type: Boolean, default: false })
const props = defineProps({ santriAwal: { type: Object, default: null } })
const emit = defineEmits(['tersimpan'])
const ds = useDisiplin(); const ps = usePersuratan(); const ui = useUI()
const cari = ref(''); const hasil = ref([]); const santri = ref(null); const saran = ref(null); const proses = ref(false)
const f = ref({ tingkat: 1, pilih: [], sanksi: [], tambahan: '', uraian: '', harapan: '' })

watch(buka, async (b) => {
  if (!b) return
  santri.value = null; saran.value = null; cari.value = ''; hasil.value = []
  try {
    await Promise.all([ds.set ? null : ds.muatSet(), ps.penandaTangan.length ? null : ps.muatPenandaTangan().catch(() => {})])
    if (props.santriAwal) pilih(props.santriAwal)
  } catch (e) { ui.toast(e.message, 'galat') }
})
let tunda
watch(cari, () => { clearTimeout(tunda); tunda = setTimeout(async () => { if (cari.value.trim().length < 2) { hasil.value = []; return } try { hasil.value = await ds.cariSantri(cari.value.trim()) } catch (e) { ui.toast(e.message, 'galat') } }, 300) })
async function pilih(s) {
  santri.value = s; saran.value = null
  try {
    saran.value = await ds.saran(s.id)
    if (saran.value.diusulkan) ui.toast('Santri ini masih memiliki usulan surat peringatan yang sedang diproses Tata Usaha.', 'galat')
    aturTingkat(saran.value.saran)
    f.value.pilih = (saran.value.pelanggaran || []).map((p) => p.id); f.value.uraian = ''
  } catch (e) { ui.toast(e.message, 'galat') }
}
function aturTingkat(t) {
  f.value.tingkat = t
  f.value.sanksi = [...(ds.set?.sanksi?.[t] || [])]
  f.value.harapan = t < 3 ? ds.set?.harapan || '' : ''
}
const sanksiPilihan = computed(() => ds.set?.sanksi?.[f.value.tingkat] || [])
function ubahSanksi(k) { const i = f.value.sanksi.indexOf(k); if (i >= 0) f.value.sanksi.splice(i, 1); else f.value.sanksi.push(k) }
function ubahPilih(id) { const i = f.value.pilih.indexOf(id); if (i >= 0) f.value.pilih.splice(i, 1); else f.value.pilih.push(id) }
const penanda = computed(() => {
  const id = ds.set?.penanda?.[f.value.tingkat]
  const s = id && ps.penandaTangan.find((x) => x.id === id)
  return s ? `${s.jabatan} (${s.nama})` : 'Direktur'
})
const masa = computed(() => ds.set?.masa_bulan?.[f.value.tingkat] || 6)

async function kirim() {
  if (!santri.value) return ui.toast('Pilih santri lebih dulu.', 'galat')
  if (saran.value?.diusulkan) return ui.toast('Santri ini masih memiliki usulan surat peringatan yang sedang diproses Tata Usaha.', 'galat')
  if (!f.value.pilih.length) return ui.toast('Pilih sedikitnya satu catatan pelanggaran sebagai dasar.', 'galat')
  const sanksi = [...f.value.sanksi, ...f.value.tambahan.split('\n').map((x) => x.trim()).filter(Boolean)]
  if (!sanksi.length) return ui.toast('Pilih atau tuliskan sedikitnya satu sanksi.', 'galat')
  const sp = TINGKAT_SP_SANTRI[f.value.tingkat]
  const akibat = f.value.tingkat === 3 && ds.set?.sp3_keluar ? ' Setelah terbit, status santri otomatis menjadi Berhenti (dikembalikan kepada orang tua).' : ''
  if (!(await ui.konfirmasi({ judul: `Usulkan ${sp.singkat}?`, pesan: `${sp.nama} untuk ${santri.value.nama} dikirim ke Tata Usaha untuk diperiksa, lalu ditandatangani ${penanda.value}.${akibat}`, ya: 'Kirim usulan', bahaya: f.value.tingkat === 3 }))) return
  proses.value = true
  try {
    await ds.usul({ student_id: santri.value.id, tingkat: f.value.tingkat, pelanggaran_ids: f.value.pilih, sanksi, uraian: f.value.uraian.trim(), harapan: f.value.harapan.trim() })
    ui.toast('Usulan terkirim ke Tata Usaha. Anda mendapat notifikasi setelah surat terbit.')
    emit('tersimpan'); buka.value = false
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <LembarBawah v-model="buka" judul="Usulkan Surat Peringatan Santri" lebar>
    <div class="space-y-5 pb-2">
      <section v-if="!santri">
        <p class="mb-2 text-sm text-teks3">Pilih santri yang akan diberi surat peringatan.</p>
        <div class="relative"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
          <input v-model="cari" type="search" class="isian pl-11" placeholder="Ketik nama atau NIS (min. 2 huruf)" aria-label="Cari santri" /></div>
        <ul class="mt-2 divide-y divide-garis">
          <li v-for="s in hasil" :key="s.id">
            <button type="button" class="flex w-full items-center gap-3 px-1 py-3 text-left hover:bg-permukaan2" @click="pilih(s)">
              <span class="min-w-0 flex-1"><span class="block font-semibold">{{ s.nama }}</span>
                <span class="block truncate text-xs text-teks3">{{ s.nis }}{{ s.kelas ? ' · ' + s.kelas : '' }} · terbuka: {{ teksTerbuka(s.terbuka) }}</span></span>
              <span v-if="s.sp_aktif" :class="['lencana', 'w-' + TINGKAT_SP_SANTRI[s.sp_aktif].w]">{{ TINGKAT_SP_SANTRI[s.sp_aktif].singkat }} aktif</span>
            </button>
          </li>
        </ul>
      </section>

      <template v-else>
        <div class="kartu w-santri flex items-center gap-3 p-4">
          <div class="min-w-0 flex-1"><p class="font-bold">{{ santri.nama }}</p><p class="text-sm text-teks3">NIS {{ santri.nis }}{{ santri.kelas ? ' · ' + santri.kelas : '' }}{{ santri.kamar ? ' · ' + santri.kamar : '' }}</p></div>
          <button v-if="!santriAwal" type="button" class="tombol-teks min-h-[40px] px-2 text-sm" @click="santri = null; saran = null"><PhArrowLeft :size="16" /> Ganti</button>
        </div>
        <p v-if="!saran" class="text-sm text-teks3">Memuat riwayat kedisiplinan…</p>
        <template v-else>
          <div v-if="saran.aktif.length" class="w-disiplin rounded-xl border border-garis p-3 text-sm">
            <p class="flex items-center gap-2 font-semibold" style="color: var(--c)"><PhWarningOctagon :size="18" weight="duotone" /> Surat peringatan yang masih berlaku</p>
            <ul class="mt-1 space-y-0.5 text-teks2"><li v-for="a in saran.aktif" :key="a.id">{{ TINGKAT_SP_SANTRI[a.tingkat].singkat }} {{ a.nomor || '' }} – berlaku sampai {{ formatPanjang(a.berlaku_sampai) }}</li></ul>
          </div>
          <p v-if="saran.ambang" class="flex gap-2 rounded-xl bg-permukaan2 p-3 text-sm"><PhWarning :size="18" class="mt-0.5 shrink-0 text-merah" />
            Jumlah pelanggaran {{ saran.ambang }} yang belum ditindaklanjuti telah mencapai ambang ketentuan ({{ teksTerbuka(saran.terbuka) }}).</p>

          <div>
            <p class="label-isian">Pelanggaran yang menjadi dasar <span class="text-merah">*</span></p>
            <p v-if="!saran.pelanggaran.length" class="rounded-xl bg-permukaan2 p-3 text-sm text-teks3">Tidak ada catatan pelanggaran yang belum ditindaklanjuti dalam satu tahun terakhir. Catat pelanggarannya terlebih dahulu.</p>
            <div v-else class="space-y-1.5">
              <label v-for="p in saran.pelanggaran" :key="p.id" :class="['flex cursor-pointer items-start gap-3 rounded-xl border px-3 py-2 text-sm', f.pilih.includes(p.id) ? 'border-[#A3261C]' : 'border-garis']">
                <input type="checkbox" class="mt-0.5 h-5 w-5 shrink-0 accent-[#A3261C]" :checked="f.pilih.includes(p.id)" @change="ubahPilih(p.id)" />
                <span class="min-w-0 flex-1"><span class="font-semibold">{{ p.kategori }}</span>
                  <span :class="['lencana ml-1', 'w-' + TINGKAT_PELANGGARAN[p.tingkat].w]">{{ TINGKAT_PELANGGARAN[p.tingkat].n }}</span>
                  <span class="block text-xs text-teks3">{{ formatPendek(p.tanggal) }} · {{ p.uraian }}</span></span>
              </label>
            </div>
          </div>

          <div>
            <p class="label-isian">Tingkat surat peringatan</p>
            <div class="grid grid-cols-3 gap-2" role="radiogroup" aria-label="Tingkat surat peringatan">
              <button v-for="t in [1, 2, 3]" :key="t" type="button" role="radio" :aria-checked="f.tingkat === t" @click="aturTingkat(t)"
                :class="['min-h-[56px] rounded-xl border px-2 text-center', 'w-' + TINGKAT_SP_SANTRI[t].w, f.tingkat === t ? 'pilih border-transparent font-bold' : 'border-garis text-teks2']">
                <span class="block text-base font-extrabold" style="color: var(--c)">{{ TINGKAT_SP_SANTRI[t].singkat }}</span>
                <span class="block text-[11px]">{{ saran.saran === t ? 'Disarankan' : ['Pertama', 'Kedua', 'Ketiga'][t - 1] }}</span>
              </button>
            </div>
            <p class="mt-1 text-xs text-teks3">{{ f.tingkat === 3 ? 'SP-3: santri dikembalikan kepada orang tua/wali.' : `Berlaku ${masa} bulan sejak tanggal surat.` }} Ditandatangani {{ penanda }}.</p>
            <p v-if="f.tingkat === 3 && ds.set?.sp3_keluar" class="mt-2 flex gap-2 rounded-xl border border-[#A3261C] p-3 text-sm text-merah"><PhWarning :size="18" class="mt-0.5 shrink-0" />
              Setelah SP-3 terbit, status santri otomatis menjadi Berhenti dan pengelola Keuangan diberi tahu untuk memeriksa tunggakan.</p>
          </div>

          <div>
            <p class="label-isian">Sanksi <span class="text-merah">*</span></p>
            <div class="space-y-1.5">
              <label v-for="k in sanksiPilihan" :key="k" :class="['flex min-h-[44px] cursor-pointer items-center gap-3 rounded-xl border px-3 py-2 text-sm', f.sanksi.includes(k) ? 'border-[#A3261C] font-semibold' : 'border-garis']">
                <input type="checkbox" class="h-5 w-5 accent-[#A3261C]" :checked="f.sanksi.includes(k)" @change="ubahSanksi(k)" /> {{ k }}</label>
            </div>
            <textarea v-model="f.tambahan" rows="2" class="isian mt-2" aria-label="Sanksi tambahan" placeholder="Sanksi tambahan (satu per baris, opsional)" />
          </div>
          <div><label class="label-isian" for="sps-uraian">Uraian tambahan</label>
            <textarea id="sps-uraian" v-model="f.uraian" rows="2" class="isian" placeholder="Opsional. Contoh: pelanggaran terjadi berulang setelah pembinaan wali kelas." />
            <p class="mt-1 text-xs text-teks3">Daftar pelanggaran (tanggal, kategori, uraian) ditulis otomatis di dalam surat.</p></div>
          <div><label class="label-isian" for="sps-harapan">{{ f.tingkat < 3 ? 'Harapan perbaikan' : 'Kalimat tambahan (opsional)' }}</label>
            <textarea id="sps-harapan" v-model="f.harapan" rows="2" class="isian" />
            <p v-if="f.tingkat < 3" class="mt-1 text-xs text-teks3">Disambung dengan kalimat "Kami mengharapkan santri yang bersangkutan …".</p></div>

          <p class="flex gap-2 rounded-xl bg-permukaan2 p-3 text-sm text-teks2"><PhInfo :size="18" class="mt-0.5 shrink-0" />
            Usulan menjadi draf surat di Tata Usaha. Tata Usaha memeriksa dan mengajukan tanda tangan; nomor surat terbit setelah ditandatangani Direktur. Pengasuh santri diberi tahu setelah surat terbit.</p>
          <button class="tombol-utama w-full" :disabled="proses || !saran.pelanggaran.length || saran.diusulkan" @click="kirim"><PhPaperPlaneTilt :size="20" weight="duotone" /> {{ proses ? 'Mengirim…' : 'Kirim usulan ke Tata Usaha' }}</button>
        </template>
      </template>
    </div>
  </LembarBawah>
</template>
<style scoped>
.pilih { background: color-mix(in srgb, var(--c) 14%, rgb(var(--permukaan))); box-shadow: inset 0 0 0 2px var(--c); }
</style>
