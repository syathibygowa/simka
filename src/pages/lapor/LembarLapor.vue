<!-- SIMKA PRO | src/pages/lapor/LembarLapor.vue | v1.0 | Fase 6 – Tahap 4 Lapor ke bidang dan dasbor ringkasan | 06/10/2026 -->
<script setup>
// Kirim laporan ke bidang terkait: kategori (menentukan penerima; Akademik/Lainnya dipilih pelapor), santri terkait
// (cari semua santri, hanya untuk menandai nama), lokasi, waktu kejadian (bawaan saat ini), uraian, foto, mendesak,
// dan anonim (hanya bila diaktifkan superadmin). Kategori Kesehatan otomatis menjadi rujukan klinik.
import { ref, computed, watch } from 'vue'
import { PhMegaphone, PhMagnifyingGlass, PhX, PhCamera, PhSiren, PhMaskHappy, PhInfo } from '@phosphor-icons/vue'
import { useLapor } from '@/stores/lapor'
import { useUI } from '@/stores/ui'
import { gayaKategori, UNIT_PILIHAN } from '@/lib/lapor'
import { hariIniISO } from '@/lib/tanggal'
import { MODE_DEMO } from '@/lib/supabase'
import { unggahKeDrive, kompresGambar, namaRapi } from '@/lib/penyimpanan'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import InputJam from '@/components/InputJam.vue'

const buka = defineModel({ type: Boolean, default: false })
const emit = defineEmits(['selesai'])
const lp = useLapor(); const ui = useUI()
const isi = ref({}); const tgl = ref(''); const jam = ref(''); const cari = ref(''); const hasil = ref([]); const proses = ref(false)
const fotoBaru = ref(null); const pratinjau = ref('')
watch(buka, (v) => { if (!v) return; isi.value = { kategori: '', unit_kode: '', santri: [], lokasi: '', uraian: '', mendesak: false, anonim: false }; tgl.value = hariIniISO(); jam.value = ''; cari.value = ''; hasil.value = []; fotoBaru.value = null; pratinjau.value = '' })
let tunda
watch(cari, () => { clearTimeout(tunda); tunda = setTimeout(async () => { try { hasil.value = await lp.cariSantri(cari.value) } catch (e) { ui.toast(e.message, 'galat') } }, 300) })
const kat = computed(() => lp.kategori.find((k) => k.kode === isi.value.kategori))
const perluUnit = computed(() => kat.value && !kat.value.unit_kode)
function tandai(s) { if (!isi.value.santri.some((x) => x.id === s.id)) isi.value.santri.push(s); cari.value = ''; hasil.value = [] }
function pilihFoto(e) { const f = e.target.files?.[0]; e.target.value = ''; if (!f) return; if (!/^image\//.test(f.type)) return ui.toast('Pilih berkas foto.', 'galat'); fotoBaru.value = f; pratinjau.value = URL.createObjectURL(f) }

async function kirim() {
  const x = isi.value
  if (!x.kategori) return ui.toast('Pilih kategori laporan.', 'galat')
  if (perluUnit.value && !x.unit_kode) return ui.toast('Pilih bidang/unit penerima.', 'galat')
  if (kat.value.ke_klinik && !x.santri.length) return ui.toast('Tandai santri yang sakit.', 'galat')
  if (x.uraian.trim().length < 10) return ui.toast('Tuliskan uraian laporan (minimal 10 huruf).', 'galat')
  proses.value = true
  try {
    let fotoId = null
    if (fotoBaru.value && !MODE_DEMO) {
      const blob = await kompresGambar(fotoBaru.value, { maks: 1280, kualitas: 0.65 }); const t = tgl.value
      fotoId = await unggahKeDrive(blob, { nama: namaRapi('Lapor', x.kategori, t, Date.now()) + '.jpg', kategori: 'lapor_bidang', folder: `SIMKA PRO/Lapor/${t.slice(0, 4)}/${t.slice(5, 7)}`, retensiHari: 365 })
    }
    const waktu = new Date(`${tgl.value}T${(jam.value || new Date().toTimeString().slice(0, 5)).slice(0, 5)}:00+08:00`).toISOString()
    await lp.kirim({ kategori: x.kategori, unit_kode: perluUnit.value ? x.unit_kode : null, santri_ids: x.santri.map((s) => s.id), santri: x.santri, lokasi: x.lokasi.trim(),
      waktu_kejadian: waktu, uraian: x.uraian.trim(), foto_id: fotoId, mendesak: x.mendesak, anonim: x.anonim })
    ui.toast(kat.value.ke_klinik ? 'Laporan terkirim dan santri otomatis dirujuk ke Klinik.' : 'Laporan terkirim ke bidang terkait.')
    buka.value = false; emit('selesai')
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <LembarBawah v-model="buka" judul="Lapor ke bidang terkait">
    <div class="space-y-3 pb-2">
      <div><p class="label-isian">Kategori <span class="text-merah">*</span></p>
        <div class="grid grid-cols-2 gap-2 sm:grid-cols-3" role="radiogroup" aria-label="Kategori laporan">
          <button v-for="k in lp.kategori.filter((x) => x.aktif)" :key="k.kode" type="button" role="radio" :aria-checked="isi.kategori === k.kode" @click="isi.kategori = k.kode"
            :class="['flex min-h-[52px] items-center gap-2 rounded-xl border px-3 text-left text-sm font-semibold', 'w-' + gayaKategori(k.kode).w, isi.kategori === k.kode ? 'kat-pilih' : 'border-garis text-teks2']">
            <component :is="gayaKategori(k.kode).ikon" :size="22" weight="duotone" style="color: var(--c)" class="shrink-0" /><span class="min-w-0 [overflow-wrap:anywhere]">{{ k.nama.replace('/', '/\u200b') }}</span></button>
        </div>
        <p v-if="kat" class="mt-1 text-xs text-teks3">{{ kat.unit_kode ? 'Diteruskan ke ' + (UNIT_PILIHAN.find((u) => u.kode === kat.unit_kode)?.n || kat.unit_kode) : 'Pilih penerima di bawah' }}{{ kat.ke_klinik ? ' dan otomatis menjadi rujukan klinik.' : '.' }} Contoh: {{ kat.contoh }}.</p></div>
      <div v-if="perluUnit"><label class="label-isian" for="lp-unit">Diteruskan ke <span class="text-merah">*</span></label>
        <select id="lp-unit" v-model="isi.unit_kode" class="isian"><option value="">Pilih bidang/unit</option><option v-for="u in UNIT_PILIHAN" :key="u.kode" :value="u.kode">{{ u.n }}</option></select></div>

      <div><p class="label-isian">Santri terkait<span v-if="kat?.ke_klinik" class="text-merah"> *</span><span v-else class="font-normal text-teks3"> (opsional)</span></p>
        <div v-if="isi.santri.length" class="mb-2 flex flex-wrap gap-1.5">
          <span v-for="s in isi.santri" :key="s.id" class="lencana w-santri">{{ s.nama }}<button type="button" class="ml-1" :aria-label="`Hapus ${s.nama}`" @click="isi.santri = isi.santri.filter((x) => x.id !== s.id)"><PhX :size="12" /></button></span>
        </div>
        <div class="relative"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
          <input v-model="cari" type="search" class="isian pl-11" placeholder="Ketik minimal 2 huruf nama atau NIS" aria-label="Cari santri" /></div>
        <ul v-if="hasil.length" class="mt-1 max-h-48 divide-y divide-garis overflow-y-auto rounded-xl border border-garis">
          <li v-for="s in hasil" :key="s.id"><button type="button" class="flex min-h-[44px] w-full items-center px-3 text-left text-sm hover:bg-permukaan2" @click="tandai(s)">
            <b class="flex-1 truncate">{{ s.nama }}</b><span class="text-xs text-teks3">{{ s.nis }}{{ s.kamar ? ' · ' + s.kamar : '' }}</span></button></li>
        </ul></div>

      <div class="grid gap-3 sm:grid-cols-3">
        <div class="sm:col-span-1"><label class="label-isian" for="lp-lok">Lokasi</label><input id="lp-lok" v-model="isi.lokasi" class="isian" placeholder="Contoh: kamar mandi asrama" /></div>
        <InputTanggal v-model="tgl" label="Tanggal kejadian" wajib /><InputJam v-model="jam" label="Jam kejadian" />
      </div>
      <div><label class="label-isian" for="lp-ur">Uraian <span class="text-merah">*</span></label>
        <textarea id="lp-ur" v-model="isi.uraian" rows="3" class="isian" placeholder="Ceritakan apa yang terjadi atau yang perlu ditangani" /></div>
      <div class="flex flex-wrap items-center gap-3">
        <img v-if="pratinjau" :src="pratinjau" alt="Foto laporan" class="h-20 w-28 rounded-xl object-cover" />
        <label class="tombol-garis cursor-pointer"><PhCamera :size="20" weight="duotone" /> {{ pratinjau ? 'Ganti foto' : 'Foto (opsional)' }}<input type="file" accept="image/*" capture="environment" class="sr-only" @change="pilihFoto" /></label>
      </div>
      <label class="flex min-h-[44px] items-center gap-3 rounded-xl bg-permukaan2 px-3 text-sm"><input v-model="isi.mendesak" type="checkbox" class="h-5 w-5 accent-[#C7332F]" />
        <PhSiren :size="20" weight="duotone" class="text-merah" /><span><b>Mendesak</b><span class="block text-xs text-teks3">Seluruh anggota unit penerima mendapat notifikasi merah.</span></span></label>
      <label v-if="lp.hak.anonim_diizinkan" class="flex min-h-[44px] items-center gap-3 rounded-xl bg-permukaan2 px-3 text-sm"><input v-model="isi.anonim" type="checkbox" class="h-5 w-5 accent-[#6D44B8]" />
        <PhMaskHappy :size="20" weight="duotone" /><span><b>Kirim sebagai anonim</b><span class="block text-xs text-teks3">Nama Anda disembunyikan dari penerima (hanya superadmin yang dapat melihat). Anda tetap menerima kabar tindak lanjut.</span></span></label>
      <p class="flex items-start gap-2 text-xs text-teks3"><PhInfo :size="16" class="shrink-0" /> Laporan hanya dapat dibaca Anda, bidang/unit penerima, pimpinan, dan superadmin.</p>
      <button class="tombol-utama w-full" :disabled="proses" @click="kirim"><PhMegaphone :size="20" weight="duotone" /> Kirim laporan</button>
    </div>
  </LembarBawah>
</template>
<style scoped>
.kat-pilih { border-color: var(--c); border-width: 2px; background: color-mix(in srgb, var(--c) 12%, transparent); color: rgb(var(--teks)); }
</style>
