<!-- SIMKA PRO | src/pages/klinik/LembarRujuk.vue | v1.0 | Fase 6 – Tahap 1 Dasar Klinik | 06/10/2026 -->
<script setup>
// Rujuk santri ke klinik: pilih santri (asuhan sendiri; petugas/pengelola: semua santri di kliniknya) → keluhan singkat →
// periksa hari ini atau besok. Santri yang sudah punya kasus terbuka: rujukan menempel ke kasus itu. Petugas klinik terkait
// menerima notifikasi.
import { ref, watch } from 'vue'
import { PhPaperPlaneTilt, PhMagnifyingGlass, PhSun, PhMoon } from '@phosphor-icons/vue'
import { useKlinik } from '@/stores/klinik'
import { useUI } from '@/stores/ui'
import { KLINIK, STATUS_KASUS, klinikSantri } from '@/lib/klinik'
import { formatWaktu } from '@/lib/tanggal'
import LembarBawah from '@/components/LembarBawah.vue'

const buka = defineModel({ type: Boolean, default: false })
const props = defineProps({ santriAwal: { type: Object, default: null } })
const emit = defineEmits(['selesai'])
const kl = useKlinik(); const ui = useUI()
const cari = ref(''); const calon = ref([]); const santri = ref(null); const keluhan = ref(''); const kapan = ref('hari_ini'); const catatan = ref(''); const proses = ref(false)
let tunda
async function muatCalon() { try { calon.value = await kl.cariSantri(cari.value) } catch (e) { ui.toast(e.message, 'galat') } }
watch(cari, () => { clearTimeout(tunda); tunda = setTimeout(muatCalon, 300) })
watch(buka, (v) => {
  if (!v) return
  santri.value = props.santriAwal; keluhan.value = ''; kapan.value = 'hari_ini'; catatan.value = ''; cari.value = ''
  if (!santri.value) muatCalon()
})
const CONTOH = ['Demam', 'Pusing', 'Batuk pilek', 'Sakit perut', 'Diare', 'Luka', 'Sakit gigi', 'Gatal-gatal']
function tambahContoh(t) { keluhan.value = keluhan.value ? `${keluhan.value}, ${t.toLowerCase()}` : t }

async function kirim() {
  if (keluhan.value.trim().length < 3) return ui.toast('Tuliskan keluhan singkat (minimal 3 huruf).', 'galat')
  proses.value = true
  try {
    const h = await kl.rujuk(santri.value.id, keluhan.value.trim(), kapan.value, catatan.value.trim())
    ui.toast(h.baru ? `Rujukan terkirim ke ${KLINIK[h.klinik]}. Batas periksa ${formatWaktu(h.batas_waktu)}.` : 'Santri sudah tercatat di klinik; rujukan ditambahkan ke kasusnya.')
    buka.value = false; emit('selesai', h)
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <LembarBawah v-model="buka" judul="Rujuk santri ke klinik">
    <div class="space-y-3 pb-2">
      <template v-if="!santri">
        <div class="relative"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
          <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari nama atau NIS santri" aria-label="Cari santri" /></div>
        <ul class="max-h-[50dvh] divide-y divide-garis overflow-y-auto rounded-xl border border-garis">
          <li v-for="s in calon" :key="s.id"><button type="button" class="flex min-h-[52px] w-full items-center gap-3 px-3 text-left text-sm hover:bg-permukaan2" @click="santri = s">
            <span class="min-w-0 flex-1"><b class="block truncate">{{ s.nama }}</b>
              <span class="text-xs text-teks3">{{ s.nis }} · Kelas {{ (s.kelas || '–').replace(/^kelas\s*/i, '') }} · {{ s.kamar || 'Kamar –' }}</span></span>
            <span v-if="s.kasus_terbuka" class="lencana" :class="'w-' + STATUS_KASUS[s.kasus_terbuka].w">{{ STATUS_KASUS[s.kasus_terbuka].p }}</span></button></li>
          <li v-if="!calon.length" class="p-4 text-center text-sm text-teks3">Santri tidak ditemukan atau bukan santri asuhan Anda.</li>
        </ul>
      </template>
      <template v-else>
        <div class="flex items-center gap-2 rounded-xl bg-permukaan2 p-3">
          <span class="min-w-0 flex-1"><b class="block truncate">{{ santri.nama }}</b>
            <span class="text-xs text-teks3">Kelas {{ (santri.kelas || '–').replace(/^kelas\s*/i, '') }} · {{ santri.kamar || 'Kamar –' }} · {{ KLINIK[klinikSantri(santri.jenis_kelamin)] }}</span></span>
          <button v-if="!santriAwal" class="tombol-garis min-h-[36px] px-3 text-xs" @click="santri = null">Ganti</button>
        </div>
        <p v-if="santri.kasus_terbuka" class="rounded-xl bg-permukaan2 p-3 text-xs text-teks2">Santri ini sudah tercatat di klinik ({{ STATUS_KASUS[santri.kasus_terbuka].p.toLowerCase() }}). Rujukan baru ditambahkan ke kasus yang sama.</p>
        <div><label class="label-isian" for="rj-kel">Keluhan singkat <span class="text-merah">*</span></label>
          <textarea id="rj-kel" v-model="keluhan" rows="2" class="isian" placeholder="Contoh: demam sejak semalam, pusing" />
          <div class="mt-2 flex flex-wrap gap-1.5"><button v-for="t in CONTOH" :key="t" type="button" class="tombol-garis min-h-[32px] px-2.5 text-xs" @click="tambahContoh(t)">{{ t }}</button></div></div>
        <div><p class="label-isian">Waktu periksa</p>
          <div class="grid grid-cols-2 gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" aria-label="Waktu periksa">
            <button v-for="o in [{ k: 'hari_ini', n: 'Hari ini', ikon: PhSun }, { k: 'besok', n: 'Besok', ikon: PhMoon }]" :key="o.k" type="button" role="radio" :aria-checked="kapan === o.k"
              :class="['flex min-h-[44px] items-center justify-center gap-2 rounded-xl text-sm font-semibold', kapan === o.k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']" @click="kapan = o.k"><component :is="o.ikon" :size="20" weight="duotone" /> {{ o.n }}</button>
          </div></div>
        <div><label class="label-isian" for="rj-cat">Catatan untuk petugas klinik</label><input id="rj-cat" v-model="catatan" class="isian" placeholder="Opsional, contoh: sudah minum obat penurun panas" /></div>
        <button class="tombol-utama w-full" :disabled="proses" @click="kirim"><PhPaperPlaneTilt :size="20" weight="duotone" /> Kirim rujukan</button>
      </template>
    </div>
  </LembarBawah>
</template>
