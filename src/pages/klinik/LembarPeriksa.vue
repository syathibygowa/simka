<!-- SIMKA PRO | src/pages/klinik/LembarPeriksa.vue | v1.0 | Fase 6 – Tahap 1 Dasar Klinik | 06/10/2026 -->
<script setup>
// Catat pemeriksaan/kontrol oleh petugas klinik. Tanpa :kasus = pasien datang sendiri (pilih santri dulu).
// Isian: keluhan, pemeriksaan (tanda vital), diagnosis, tindakan, obat/terapi (catatan bebas, tanpa daftar obat),
// tindak lanjut (5 pilihan), tujuan rujukan, jadwal kontrol, catatan. "Kembali beraktivitas" menutup kasus.
import { ref, computed, watch } from 'vue'
import { PhStethoscope, PhMagnifyingGlass, PhCalendarCheck } from '@phosphor-icons/vue'
import { useKlinik } from '@/stores/klinik'
import { useUI } from '@/stores/ui'
import { KLINIK, TINDAK_LANJUT, STATUS_KASUS, klinikSantri } from '@/lib/klinik'
import { hariIniISO } from '@/lib/tanggal'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import InputJam from '@/components/InputJam.vue'

const buka = defineModel({ type: Boolean, default: false })
const props = defineProps({ kasus: { type: Object, default: null } })
const emit = defineEmits(['selesai'])
const kl = useKlinik(); const ui = useUI()
const kosong = () => ({ keluhan: '', pemeriksaan: '', diagnosis: '', tindakan: '', obat: '', tindak_lanjut: '', rujuk_ke: '', catatan: '' })
const isi = ref(kosong()); const santri = ref(null); const cari = ref(''); const calon = ref([]); const proses = ref(false)
const kontrol = ref(false); const tglKontrol = ref(''); const jamKontrol = ref('')
let tunda
async function muatCalon() {
  try { calon.value = (await kl.cariSantri(cari.value)).filter((s) => kl.bolehPeriksa(klinikSantri(s.jenis_kelamin))) } catch (e) { ui.toast(e.message, 'galat') }
}
watch(cari, () => { clearTimeout(tunda); tunda = setTimeout(muatCalon, 300) })
const tambahHari = (n) => { const d = new Date(hariIniISO() + 'T00:00:00'); d.setDate(d.getDate() + n); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}` }
watch(buka, async (v) => {
  if (!v) return
  isi.value = kosong(); santri.value = null; cari.value = ''; kontrol.value = false
  if (!kl.pengaturan) await kl.muatPengaturan().catch(() => {})
  if (props.kasus) { isi.value.keluhan = props.kasus.keluhan || '' } else muatCalon()
  tglKontrol.value = tambahHari(Number(kl.pengaturan?.kontrol_bawaan_hari ?? 1)); jamKontrol.value = ''
})
watch(() => isi.value.tindak_lanjut, (tl) => { kontrol.value = ['istirahat', 'rawat'].includes(tl) && Number(kl.pengaturan?.kontrol_bawaan_hari ?? 1) > 0 })
const judul = computed(() => (props.kasus ? `${props.kasus.status === 'ditangani' ? 'Kontrol' : 'Pemeriksaan'} · ${props.kasus.nama}` : 'Pasien datang sendiri'))
const siapIsi = computed(() => props.kasus || santri.value)

async function simpan() {
  const tl = isi.value.tindak_lanjut
  if (!tl) return ui.toast('Pilih tindak lanjut.', 'galat')
  if (!props.kasus && isi.value.keluhan.trim().length < 3) return ui.toast('Tuliskan keluhan pasien.', 'galat')
  if (tl === 'rujuk' && isi.value.rujuk_ke.trim().length < 3) return ui.toast('Tuliskan tujuan rujukan (rumah sakit/puskesmas).', 'galat')
  const kontrolPada = kontrol.value && tl !== 'kembali' && tglKontrol.value ? new Date(`${tglKontrol.value}T${(jamKontrol.value || '08:00').slice(0, 5)}:00+08:00`).toISOString() : null
  if (kontrolPada && new Date(kontrolPada) < new Date(Date.now() - 3600000)) return ui.toast('Jadwal kontrol tidak boleh di masa lalu.', 'galat')
  proses.value = true
  try {
    const h = await kl.periksa({ ...isi.value, case_id: props.kasus?.id || null, student_id: props.kasus ? null : santri.value.id, kontrol_pada: kontrolPada })
    ui.toast(h.status === 'selesai' ? 'Pemeriksaan tersimpan. Santri kembali beraktivitas; kasus ditutup.' : `Pemeriksaan tersimpan: ${TINDAK_LANJUT[tl].n.toLowerCase()}.`)
    buka.value = false; emit('selesai', h)
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <LembarBawah v-model="buka" :judul="judul">
    <div class="space-y-3 pb-2">
      <template v-if="!siapIsi">
        <div class="relative"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
          <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari nama atau NIS santri" aria-label="Cari santri" /></div>
        <ul class="max-h-[50dvh] divide-y divide-garis overflow-y-auto rounded-xl border border-garis">
          <li v-for="s in calon" :key="s.id"><button type="button" class="flex min-h-[52px] w-full items-center gap-3 px-3 text-left text-sm hover:bg-permukaan2" @click="santri = s">
            <span class="min-w-0 flex-1"><b class="block truncate">{{ s.nama }}</b><span class="text-xs text-teks3">{{ s.nis }} · Kelas {{ (s.kelas || '–').replace(/^kelas\s*/i, '') }} · {{ s.kamar || 'Kamar –' }}</span></span>
            <span v-if="s.kasus_terbuka" class="lencana" :class="'w-' + STATUS_KASUS[s.kasus_terbuka].w">{{ STATUS_KASUS[s.kasus_terbuka].p }}</span></button></li>
          <li v-if="!calon.length" class="p-4 text-center text-sm text-teks3">Santri tidak ditemukan di klinik yang Anda layani.</li>
        </ul>
      </template>
      <template v-else>
        <div class="rounded-xl bg-permukaan2 p-3 text-sm">
          <b class="block">{{ kasus?.nama || santri.nama }}</b>
          <span class="text-xs text-teks3">Kelas {{ ((kasus || santri).kelas || '–').replace(/^kelas\s*/i, '') }} · {{ (kasus || santri).kamar || 'Kamar –' }} · {{ KLINIK[kasus?.klinik || klinikSantri(santri.jenis_kelamin)] }}</span>
          <span v-if="kasus" class="mt-1 block text-xs text-teks2">Keluhan rujukan: {{ kasus.keluhan }}</span>
          <button v-if="!kasus" class="tombol-garis mt-2 min-h-[32px] px-3 text-xs" @click="santri = null">Ganti santri</button>
        </div>
        <div><label class="label-isian" for="pr-kel">Keluhan<span v-if="!kasus" class="text-merah"> *</span></label><textarea id="pr-kel" v-model="isi.keluhan" rows="2" class="isian" placeholder="Keluhan yang disampaikan santri" /></div>
        <div><label class="label-isian" for="pr-pem">Pemeriksaan</label><textarea id="pr-pem" v-model="isi.pemeriksaan" rows="2" class="isian" placeholder="Contoh: suhu 38,5 °C; tensi 110/70; nadi 90×/menit" /></div>
        <div class="grid gap-3 sm:grid-cols-2">
          <div><label class="label-isian" for="pr-dx">Diagnosis</label><input id="pr-dx" v-model="isi.diagnosis" class="isian" placeholder="Contoh: febris, ISPA" /></div>
          <div><label class="label-isian" for="pr-tx">Tindakan</label><input id="pr-tx" v-model="isi.tindakan" class="isian" placeholder="Contoh: kompres, perawatan luka" /></div>
        </div>
        <div><label class="label-isian" for="pr-obat">Obat/terapi (catatan)</label><textarea id="pr-obat" v-model="isi.obat" rows="2" class="isian" placeholder="Contoh: parasetamol 500 mg 3×1 sesudah makan, 3 hari" /></div>

        <div><p class="label-isian">Tindak lanjut <span class="text-merah">*</span></p>
          <div class="grid grid-cols-2 gap-2 sm:grid-cols-3" role="radiogroup" aria-label="Tindak lanjut">
            <button v-for="(t, k) in TINDAK_LANJUT" :key="k" type="button" role="radio" :aria-checked="isi.tindak_lanjut === k"
              :class="['flex min-h-[52px] items-center gap-2 rounded-xl border px-3 text-left text-sm font-semibold', 'w-' + t.w, isi.tindak_lanjut === k ? 'tl-pilih' : 'border-garis text-teks2']"
              @click="isi.tindak_lanjut = k"><component :is="t.ikon" :size="22" weight="duotone" style="color: var(--c)" class="shrink-0" />{{ t.n }}</button>
          </div>
          <p v-if="isi.tindak_lanjut" class="mt-1 text-xs text-teks3">{{ TINDAK_LANJUT[isi.tindak_lanjut].ket }}</p></div>
        <div v-if="isi.tindak_lanjut === 'rujuk'"><label class="label-isian" for="pr-rj">Dirujuk ke <span class="text-merah">*</span></label><input id="pr-rj" v-model="isi.rujuk_ke" class="isian" placeholder="Contoh: RSUD Syekh Yusuf Gowa" /></div>

        <template v-if="isi.tindak_lanjut && isi.tindak_lanjut !== 'kembali'">
          <label class="flex min-h-[44px] items-center gap-3 text-sm font-semibold"><input v-model="kontrol" type="checkbox" class="h-5 w-5 accent-[#C7332F]" />
            <PhCalendarCheck :size="20" weight="duotone" /> Jadwalkan kontrol</label>
          <div v-if="kontrol" class="grid gap-3 sm:grid-cols-2"><InputTanggal v-model="tglKontrol" label="Tanggal kontrol" /><InputJam v-model="jamKontrol" label="Jam" /></div>
        </template>
        <div><label class="label-isian" for="pr-cat">Catatan</label><input id="pr-cat" v-model="isi.catatan" class="isian" placeholder="Opsional, contoh: pantau suhu tiap 4 jam" /></div>
        <p class="rounded-xl bg-permukaan2 p-3 text-xs text-teks2">Catatan pemeriksaan bersifat rahasia: hanya petugas klinik, pengelola klinik, pimpinan Kesantrian, dan superadmin yang dapat membacanya. Pengasuh dan wali hanya melihat keluhan umum dan statusnya.</p>
        <button class="tombol-utama w-full" :disabled="proses" @click="simpan"><PhStethoscope :size="20" weight="duotone" /> Simpan pemeriksaan</button>
      </template>
    </div>
  </LembarBawah>
</template>
<style scoped>
.tl-pilih { border-color: var(--c); border-width: 2px; background: color-mix(in srgb, var(--c) 12%, transparent); color: rgb(var(--teks)); }
</style>
