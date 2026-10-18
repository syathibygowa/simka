<!-- SIMKA PRO | src/pages/disiplin/LembarPelanggaran.vue | v1.0 | 14.6.0: isian catatan pelanggaran santri (tanpa poin) | 18/10/2026 -->
<script setup>
// Lembar catat/ubah pelanggaran santri. Santri: dikunci (dibuka dari biodata/riwayat) atau dicari (pengasuh melihat santri
// asuhannya tanpa mengetik; Security/Kesantrian mencari semua santri aktif). Tanggal bawaan hari ini, jam mengikuti jam sistem.
// Tingkat (ringan/sedang/berat) mengikuti kategori di ketentuan; kategori "Lainnya" memilih tingkatnya sendiri.
// Bukti foto opsional (antrean unggah → Google Drive). Hak diperiksa server.
import { ref, computed, watch } from 'vue'
import { PhMagnifyingGlass, PhX, PhGavel, PhCamera, PhInfo, PhWarningOctagon } from '@phosphor-icons/vue'
import { useDisiplin } from '@/stores/disiplin'
import { useUI } from '@/stores/ui'
import { TINGKAT_PELANGGARAN, TINGKAT_SP_SANTRI, tingkatKategori, teksTerbuka } from '@/lib/disiplin'
import { hariIniISO } from '@/lib/tanggal'
import { MODE_DEMO } from '@/lib/supabase'
import { unggahKeDrive, kompresGambar, namaRapi } from '@/lib/penyimpanan'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import InputJam from '@/components/InputJam.vue'

const buka = defineModel({ type: Boolean, default: false })
const props = defineProps({ data: { type: Object, default: null }, santri: { type: Object, default: null } })
const emit = defineEmits(['selesai'])
const ds = useDisiplin(); const ui = useUI()
const f = ref({}); const pilihan = ref(null); const cari = ref(''); const hasil = ref([]); const memuatCari = ref(false); const proses = ref(false)
const fotoBaru = ref(null); const pratinjau = ref('')

watch(buka, async (v) => {
  if (!v) return
  if (!ds.set) ds.muatSet().catch(() => {})
  const d = props.data
  f.value = d ? { id: d.id, tanggal: d.tanggal, jam: d.jam || '', kategori: d.kategori, tingkat: d.tingkat, tempat: d.tempat || '', uraian: d.uraian, tindakan: d.tindakan || '', saksi: d.saksi || '' }
    : { tanggal: hariIniISO(), jam: '', kategori: '', tingkat: 'ringan', tempat: '', uraian: '', tindakan: '', saksi: '' }
  pilihan.value = props.santri || (d ? { id: d.student_id, nama: d.nama, nis: d.nis, kelas: d.kelas, kamar: d.kamar } : null)
  cari.value = ''; fotoBaru.value = null; pratinjau.value = ''
  if (!pilihan.value) muatCari()
})
let tunda
watch(cari, () => { clearTimeout(tunda); tunda = setTimeout(muatCari, 300) })
async function muatCari() {
  memuatCari.value = true
  try { hasil.value = await ds.cariSantri(cari.value.trim()) } catch (e) { ui.toast(e.message, 'galat') } finally { memuatCari.value = false }
}
const kelompokKategori = computed(() => ['ringan', 'sedang', 'berat'].map((t) => ({ t, daftar: (ds.set?.kategori || []).filter((k) => k.tingkat === t) })).filter((g) => g.daftar.length))
const tingkatOtomatis = computed(() => (f.value.kategori && f.value.kategori !== 'Lainnya' ? tingkatKategori(ds.set, f.value.kategori) : null))
const tingkatAkhir = computed(() => tingkatOtomatis.value || f.value.tingkat || 'ringan')
function pilihFoto(e) { const x = e.target.files?.[0]; e.target.value = ''; if (!x) return; if (!/^image\//.test(x.type)) return ui.toast('Pilih berkas foto.', 'galat'); fotoBaru.value = x; pratinjau.value = URL.createObjectURL(x) }

async function simpan() {
  if (!pilihan.value) return ui.toast('Pilih santri terlebih dahulu.', 'galat')
  if (!f.value.kategori) return ui.toast('Pilih kategori pelanggaran.', 'galat')
  if (f.value.uraian.trim().length < 5) return ui.toast('Uraikan pelanggaran (minimal 5 huruf).', 'galat')
  if (f.value.tanggal > hariIniISO()) return ui.toast('Tanggal pelanggaran belum terjadi.', 'galat')
  proses.value = true
  try {
    const isi = { ...f.value, tingkat: tingkatAkhir.value, student_id: pilihan.value.id }
    if (fotoBaru.value && !MODE_DEMO) {
      const blob = await kompresGambar(fotoBaru.value, { maks: 1280, kualitas: 0.65 }); const t = f.value.tanggal
      isi.bukti_id = await unggahKeDrive(blob, { nama: namaRapi('Pelanggaran', pilihan.value.nis, t, Date.now()) + '.jpg', kategori: 'disiplin_santri',
        folder: `SIMKA PRO/Kedisiplinan Santri/${t.slice(0, 4)}/${t.slice(5, 7)}`, retensiHari: 1095 })
    }
    await ds.simpan(isi)
    ui.toast(f.value.id ? 'Catatan pelanggaran diperbarui.' : 'Pelanggaran dicatat. Pengasuh santri mendapat notifikasi.')
    buka.value = false; emit('selesai')
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <LembarBawah v-model="buka" :judul="f.id ? 'Ubah catatan pelanggaran' : 'Catat pelanggaran santri'">
    <div class="space-y-4 pb-2">
      <div>
        <p class="label-isian">Santri <span class="text-merah">*</span></p>
        <div v-if="pilihan" class="w-disiplin flex items-center gap-3 rounded-2xl border border-garis p-3">
          <span class="chip-ikon h-10 w-10 shrink-0"><PhGavel :size="22" weight="duotone" /></span>
          <span class="min-w-0 flex-1"><b class="block truncate">{{ pilihan.nama }}</b>
            <span class="text-xs text-teks3">NIS {{ pilihan.nis }}{{ pilihan.kelas ? ' · ' + pilihan.kelas : '' }}{{ pilihan.kamar ? ' · ' + pilihan.kamar : '' }}</span></span>
          <button v-if="!santri && !f.id" type="button" class="tombol-ikon" aria-label="Ganti santri" @click="pilihan = null; muatCari()"><PhX :size="20" /></button>
        </div>
        <template v-else>
          <div class="relative"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-teks3" />
            <input v-model="cari" type="search" class="isian pl-10" placeholder="Ketik nama atau NIS santri (min. 2 huruf)" aria-label="Cari santri" /></div>
          <p v-if="!cari && hasil.length" class="mt-1 text-xs text-teks3">Santri asuhan Anda:</p>
          <ul v-if="hasil.length" class="mt-1 max-h-60 divide-y divide-garis overflow-y-auto rounded-2xl border border-garis">
            <li v-for="s in hasil" :key="s.id"><button type="button" class="flex min-h-[48px] w-full items-center gap-2 px-3 text-left hover:bg-permukaan2" @click="pilihan = s">
              <span class="min-w-0 flex-1"><b class="block truncate text-sm">{{ s.nama }}</b><span class="text-xs text-teks3">{{ s.nis }}{{ s.kelas ? ' · ' + s.kelas : '' }}{{ s.kamar ? ' · ' + s.kamar : '' }}</span></span>
              <span v-if="s.sp_aktif" :class="['lencana', 'w-' + TINGKAT_SP_SANTRI[s.sp_aktif].w]">{{ TINGKAT_SP_SANTRI[s.sp_aktif].singkat }}</span>
              <span v-else-if="s.terbuka?.jumlah" class="lencana">{{ s.terbuka.jumlah }} catatan</span></button></li>
          </ul>
          <p v-else-if="memuatCari" class="mt-2 text-sm text-teks3">Mencari…</p>
          <p v-else-if="cari.trim().length >= 2" class="mt-2 text-sm text-teks3">Santri tidak ditemukan atau bukan santri yang dapat Anda catat.</p>
        </template>
        <p v-if="pilihan && !f.id && (pilihan.sp_aktif || pilihan.terbuka?.jumlah)" class="mt-2 flex gap-2 rounded-xl bg-permukaan2 p-3 text-sm text-teks2">
          <PhWarningOctagon :size="18" class="mt-0.5 shrink-0 text-merah" />
          <span>{{ pilihan.sp_aktif ? `Santri ini masih memiliki ${TINGKAT_SP_SANTRI[pilihan.sp_aktif].singkat} yang berlaku. ` : '' }}Pelanggaran yang belum ditindaklanjuti: {{ teksTerbuka(pilihan.terbuka) }}.</span></p>
      </div>
      <div class="grid grid-cols-2 gap-3"><InputTanggal v-model="f.tanggal" label="Tanggal" wajib /><InputJam v-model="f.jam" label="Jam" /></div>
      <div><label class="label-isian" for="pl-kat">Kategori pelanggaran <span class="text-merah">*</span></label>
        <select id="pl-kat" v-model="f.kategori" class="isian">
          <option value="" disabled>Pilih kategori</option>
          <optgroup v-for="g in kelompokKategori" :key="g.t" :label="`Pelanggaran ${TINGKAT_PELANGGARAN[g.t].n.toLowerCase()}`">
            <option v-for="k in g.daftar" :key="k.nama" :value="k.nama">{{ k.nama }}</option>
          </optgroup>
        </select>
        <p v-if="tingkatOtomatis" class="mt-1 flex items-center gap-1.5 text-xs text-teks3">Tingkat: <span :class="['lencana', 'w-' + TINGKAT_PELANGGARAN[tingkatOtomatis].w]">{{ TINGKAT_PELANGGARAN[tingkatOtomatis].n }}</span> (mengikuti ketentuan)</p></div>
      <div v-if="f.kategori === 'Lainnya'"><p class="label-isian">Tingkat pelanggaran</p>
        <div class="grid grid-cols-3 gap-2" role="radiogroup" aria-label="Tingkat pelanggaran">
          <button v-for="(t, k) in TINGKAT_PELANGGARAN" :key="k" type="button" role="radio" :aria-checked="f.tingkat === k" @click="f.tingkat = k"
            :class="['min-h-[44px] rounded-xl border-2 px-2 text-sm font-semibold', 'w-' + t.w, f.tingkat === k ? 'text-teks' : 'border-garis text-teks2']"
            :style="f.tingkat === k ? 'border-color: var(--c); background: color-mix(in srgb, var(--c) 14%, transparent)' : ''">{{ t.n }}</button>
        </div></div>
      <div><label class="label-isian" for="pl-tempat">Tempat</label><input id="pl-tempat" v-model="f.tempat" class="isian" placeholder="Contoh: kamar Umar, gerbang belakang" /></div>
      <div><label class="label-isian" for="pl-uraian">Uraian kejadian <span class="text-merah">*</span></label>
        <textarea id="pl-uraian" v-model="f.uraian" class="isian min-h-[80px]" rows="3" placeholder="Tuliskan apa yang terjadi secara singkat dan objektif." /></div>
      <div><label class="label-isian" for="pl-tindakan">Tindakan/pembinaan langsung</label>
        <textarea id="pl-tindakan" v-model="f.tindakan" class="isian min-h-[60px]" rows="2" placeholder="Contoh: dinasihati, barang disita, membuat surat pernyataan" /></div>
      <div><label class="label-isian" for="pl-saksi">Saksi</label><input id="pl-saksi" v-model="f.saksi" class="isian" placeholder="Opsional" /></div>
      <div v-if="!f.id" class="flex flex-wrap items-center gap-3">
        <img v-if="pratinjau" :src="pratinjau" alt="Bukti pelanggaran" class="h-20 w-28 rounded-xl object-cover" />
        <label class="tombol-garis cursor-pointer"><PhCamera :size="20" weight="duotone" /> {{ pratinjau ? 'Ganti foto' : 'Foto bukti (opsional)' }}<input type="file" accept="image/*" capture="environment" class="sr-only" @change="pilihFoto" /></label>
      </div>
      <p class="flex gap-2 rounded-xl bg-permukaan2 p-3 text-xs text-teks2"><PhInfo :size="16" class="mt-0.5 shrink-0" />
        Catatan bersifat terbatas: dilihat pengasuh santri, Bidang Kesantrian, pimpinan, dan Tata Usaha; tidak tampil di Portal Wali. Pelanggaran berat dan yang mencapai ambang diberitahukan ke Bidang Kesantrian.</p>
      <button class="tombol-utama w-full" :disabled="proses" @click="simpan">{{ proses ? 'Menyimpan…' : f.id ? 'Simpan perubahan' : 'Catat pelanggaran' }}</button>
    </div>
  </LembarBawah>
</template>
