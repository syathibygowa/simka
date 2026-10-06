<!-- SIMKA PRO | src/pages/kartu/Kartu.vue | v1.3 | Fase 7 – Perbaikan uji coba: kartu di Profil, cetak massal di Data Pegawai | 06/10/2026 -->
<script setup>
// Kartu pegawai. Kartu saya: lihat depan/belakang, ganti pas foto, cetak, dan ganti kode bila kartu hilang.
// Cetak massal (admin ber-izin cetak_kartu): pilih pegawai, cetak 9 kartu tegak per F4 (bolak-balik) atau berdampingan.
// Kartu otomatis tidak berlaku (verifikasi QR) bila pegawai berstatus nonaktif.
// v1.1: kartu tegak (portrait); foto kartu = foto profil akun (diganti di sini atau di Profil); 9 kartu per F4.
// v1.3: dibuka dari Profil (Kartu saya); Cetak massal pindah ke Data Pegawai → tab Cetak kartu (prop bagian="massal").
import { ref, computed, onMounted, watch, nextTick } from 'vue'
import { PhIdentificationCard, PhCards, PhCamera, PhPrinter, PhArrowsClockwise, PhMagnifyingGlass, PhCheckSquare, PhSquare, PhInfo, PhQrCode, PhLink, PhImage, PhDownloadSimple } from '@phosphor-icons/vue'
import { useKartu } from '@/stores/kartu'
import { useLembaga } from '@/stores/lembaga'
import { usePegawai } from '@/stores/pegawai'
import { useOrganisasi } from '@/stores/organisasi'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { MODE_DEMO } from '@/lib/supabase'
import { alamatBerkas } from '@/lib/penyimpanan'
import { alamatVerifikasi } from '@/lib/kartu'
import { toPng, toJpeg } from 'html-to-image'
import logoLokal from '@/assets/logo-pondok.png'
import { namaRapi } from '@/lib/penyimpanan'
import KartuPegawai from '@/components/KartuPegawai.vue'
import LembarKartu from '@/components/cetak/LembarKartu.vue'

const props = defineProps({ bagian: { type: String, default: 'saya' } })
const kt = useKartu(); const lembaga = useLembaga(); const peg = usePegawai(); const org = useOrganisasi(); const sesi = useSesi(); const ui = useUI()
const tab = ref(props.bagian); const saya = ref(null); const foto = ref({}); const proses = ref(false)
const pratinjau = ref(false); const cetakData = ref([]); const mode = ref('berdampingan')
const direktur = computed(() => lembaga.signatories.find((s) => s.sumber_jabatan === 'DIREKTUR' || /^direktur/i.test(s.jabatan_tertulis)) || {})

onMounted(async () => { await lembaga.muat(); if (props.bagian === 'massal') await Promise.all([org.muat(), peg.daftar.length ? null : peg.muat()]); else muatSaya() })
async function muatSaya() {
  try { const [d] = await kt.data(); saya.value = d; if (d?.foto_id) foto.value[d.employee_id] = sesi.fotoUrl || await alamatBerkas(d.foto_id); else if (sesi.fotoUrl) foto.value[d.employee_id] = sesi.fotoUrl } catch (e) { ui.toast(e.message, 'galat') }
}
async function gantiFoto(e) {
  const b = e.target.files?.[0]; e.target.value = ''
  if (!b) return
  if (!/^image\//.test(b.type)) return ui.toast('Pilih berkas foto.', 'galat')
  if (MODE_DEMO) { const u = URL.createObjectURL(b); foto.value[saya.value.employee_id] = u; sesi.setelFoto('demo', u); return ui.toast('Mode demo: foto hanya tampil sementara.', 'info') }
  proses.value = true
  try { const id = await kt.pasangFoto(saya.value.employee_id, b); sesi.setelFoto(id, ''); await sesi.muatFoto(); await muatSaya(); ui.toast('Foto profil dan foto kartu diperbarui (dipotong 3:4).', 'info') } catch (er) { ui.toast(er.message, 'galat') } finally { proses.value = false }
}
async function gantiKode() {
  if (!(await ui.konfirmasi({ judul: 'Ganti kode kartu?', pesan: 'Gunakan bila kartu hilang. Kartu lama langsung tidak dapat diverifikasi dan Anda perlu mencetak kartu baru.', ya: 'Ganti kode', bahaya: true }))) return
  try { saya.value.kode = await kt.gantiKode(saya.value.employee_id); ui.toast('Kode kartu diganti. Cetak ulang kartu Anda.', 'info') } catch (e) { ui.toast(e.message, 'galat') }
}
function cetakSaya() { cetakData.value = [saya.value]; mode.value = 'berdampingan'; pratinjau.value = true }
// ---------- Unduh gambar kartu (PNG/JPEG) ----------
// Kartu digambar ulang di luar layar tanpa skala tampilan, lalu diubah menjadi gambar ±600 dpi (cetak 54 × 85,6 mm).
const wadahUnduh = ref(null); const mengunduh = ref(''); const identitasUnduh = ref(null)
// Logo dari situs lain sering menolak dibaca (CORS) sehingga hilang dari gambar: diubah ke data URL, bila gagal pakai logo bawaan aplikasi
async function keDataUrl(url) {
  const r = await fetch(url, { mode: 'cors' }); if (!r.ok) throw new Error('gagal')
  const b = await r.blob(); return await new Promise((ok) => { const f = new FileReader(); f.onload = () => ok(f.result); f.readAsDataURL(b) })
}
const PIKSEL_KOSONG = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='
async function unduhGambar(format) {
  if (!wadahUnduh.value || mengunduh.value) return
  mengunduh.value = format
  try {
    let logo = lembaga.identitas?.logo_url
    try { logo = logo ? await keDataUrl(logo) : logoLokal } catch { logo = logoLokal }
    identitasUnduh.value = { ...lembaga.identitas, logo_url: logo }
    await nextTick(); await document.fonts?.ready
    await Promise.all([...wadahUnduh.value.querySelectorAll('img')].map((img) => (img.complete ? null : new Promise((r) => { img.onload = r; img.onerror = r }))))
    const opsi = { pixelRatio: 6, backgroundColor: format === 'png' ? undefined : '#ffffff', imagePlaceholder: PIKSEL_KOSONG }
    const nama = namaRapi(saya.value.nama) || 'Pegawai'
    for (const sisi of ['depan', 'belakang']) {
      const node = wadahUnduh.value.querySelector(`[data-sisi="${sisi}"] .kartu-p`)
      const url = format === 'png' ? await toPng(node, opsi) : await toJpeg(node, { ...opsi, quality: 0.95 })
      const a = document.createElement('a'); a.href = url; a.download = `Kartu-Pegawai-${nama}-${sisi}.${format === 'png' ? 'png' : 'jpg'}`
      document.body.appendChild(a); a.click(); a.remove()
      await new Promise((r) => setTimeout(r, 400)) // beri jeda agar peramban menerima dua unduhan
    }
    ui.toast(`Kartu (depan dan belakang) diunduh sebagai ${format.toUpperCase()}.`, 'info')
  } catch { ui.toast('Gambar kartu gagal dibuat. Coba lagi atau gunakan Cetak kartu.', 'galat') } finally { mengunduh.value = '' }
}
async function salinTautan() { try { await navigator.clipboard.writeText(alamatVerifikasi(saya.value.kode)); ui.toast('Tautan verifikasi disalin.', 'info') } catch { ui.toast(alamatVerifikasi(saya.value.kode), 'info') } }

// ---------- Cetak massal ----------
const pilih = ref(new Set()); const unit = ref(''); const cari = ref('')
const calon = computed(() => peg.daftar.filter((p) => p.status_keaktifan === 'aktif'
  && (!unit.value || org.turunan(unit.value).has(p.org_unit_id))
  && (!cari.value.trim() || [p.nama_lengkap, p.niy].join(' ').toLowerCase().includes(cari.value.toLowerCase().trim()))))
const semua = computed(() => calon.value.length > 0 && calon.value.every((p) => pilih.value.has(p.id)))
function balikPilih(id) { const s = new Set(pilih.value); s.has(id) ? s.delete(id) : s.add(id); pilih.value = s }
function pilihSemua() { const s = new Set(pilih.value); calon.value.forEach((p) => (semua.value ? s.delete(p.id) : s.add(p.id))); pilih.value = s }
async function siapkanMassal() {
  if (!pilih.value.size) return ui.toast('Pilih minimal satu pegawai.', 'galat')
  proses.value = true
  try {
    const d = await kt.data([...pilih.value])
    const tanpaNiy = d.filter((x) => !x.niy).length
    await Promise.all(d.filter((x) => x.foto_id && !foto.value[x.employee_id]).map(async (x) => { try { foto.value[x.employee_id] = await alamatBerkas(x.foto_id) } catch { /* tanpa foto */ } }))
    cetakData.value = d; pratinjau.value = true
    if (tanpaNiy) ui.toast(`${tanpaNiy} pegawai belum memiliki NIY. Lengkapi di Data Pegawai sebelum mencetak final.`, 'info')
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <div :class="['w-profil', bagian === 'saya' && 'mx-auto max-w-4xl']">
    <template v-if="tab === 'saya'">
      <p v-if="!saya" class="py-10 text-center text-teks3">Menyiapkan kartu…</p>
      <div v-else class="grid gap-5 lg:grid-cols-[auto_1fr]">
        <div class="flex flex-col items-center gap-3">
          <div class="pratinjau-kartu flex gap-3">
            <div class="text-center"><div class="bayang"><KartuPegawai :d="saya" sisi="depan" :foto="foto[saya.employee_id]" :identitas="lembaga.identitas" :direktur="direktur" /></div><p class="mt-1 text-xs text-teks3">Depan</p></div>
            <div class="text-center"><div class="bayang"><KartuPegawai :d="saya" sisi="belakang" :foto="foto[saya.employee_id]" :identitas="lembaga.identitas" :direktur="direktur" /></div><p class="mt-1 text-xs text-teks3">Belakang</p></div>
          </div>
        </div>
        <div class="space-y-3">
          <div :class="['kartu p-4', saya.aktif ? 'w-presensi' : 'w-beranda']">
            <p class="flex items-center gap-2 font-bold"><PhQrCode :size="22" weight="duotone" style="color: var(--c)" /> {{ saya.aktif ? 'Kartu berlaku' : 'Kartu tidak berlaku' }}</p>
            <p class="mt-1 text-sm text-teks2">Berlaku selama Anda tercatat sebagai pegawai aktif. Siapa pun dapat memindai kode QR untuk memeriksa keabsahannya.</p>
            <button class="tombol-teks mt-1 text-sm" @click="salinTautan"><PhLink :size="18" /> Salin tautan verifikasi</button>
          </div>
          <label class="tombol-garis w-full cursor-pointer justify-center" :class="proses && 'opacity-60'"><PhCamera :size="20" weight="duotone" /> {{ saya.foto_id ? 'Ganti foto profil/kartu' : 'Unggah foto profil/kartu' }}
            <input type="file" accept="image/*" class="sr-only" :disabled="proses" @change="gantiFoto" /></label>
          <p class="text-xs text-teks3">Foto kartu sama dengan foto profil akun. Gunakan foto tegak berlatar polos dan berpakaian rapi; foto dipotong otomatis 3:4.</p>
          <button class="tombol-utama w-full" @click="cetakSaya"><PhPrinter :size="20" weight="duotone" /> Cetak kartu (F4)</button>
          <div class="grid grid-cols-2 gap-2">
            <button class="tombol-garis" :disabled="!!mengunduh" @click="unduhGambar('png')"><PhImage :size="20" weight="duotone" /> {{ mengunduh === 'png' ? 'Membuat…' : 'Unduh PNG' }}</button>
            <button class="tombol-garis" :disabled="!!mengunduh" @click="unduhGambar('jpeg')"><PhDownloadSimple :size="20" weight="duotone" /> {{ mengunduh === 'jpeg' ? 'Membuat…' : 'Unduh JPEG' }}</button>
          </div>
          <p class="text-xs text-teks3">Gambar depan dan belakang (±600 dpi) dapat dibagikan atau dicetak di percetakan kartu ukuran 54 × 85,6 mm.</p>
          <button class="tombol-garis w-full" @click="gantiKode"><PhArrowsClockwise :size="20" /> Kartu hilang? Ganti kode</button>
          <p v-if="!saya.niy" class="flex gap-2 rounded-xl bg-permukaan2 p-3 text-sm text-teks2"><PhInfo :size="18" class="mt-0.5 shrink-0" />NIY Anda belum tercatat. Hubungi admin kepegawaian sebelum mencetak kartu.</p>
        </div>
      </div>
    </template>

    <template v-else>
      <div class="kartu mb-3 grid gap-3 p-4 sm:grid-cols-2">
        <div><label class="label-isian" for="km-unit">Bidang/Unit</label>
          <select id="km-unit" v-model="unit" class="isian"><option value="">Semua bidang</option>
            <option v-for="u in org.datar" :key="u.id" :value="u.id">{{ '— '.repeat(u.tingkat) }}{{ u.nama }}</option></select></div>
        <div><label class="label-isian" for="km-cari">Cari pegawai</label>
          <div class="relative"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-teks3" />
            <input id="km-cari" v-model="cari" class="isian pl-10" placeholder="Nama atau NIY" /></div></div>
        <fieldset class="sm:col-span-2"><legend class="label-isian">Tata letak cetak</legend>
          <div class="flex flex-wrap gap-2">
            <label v-for="m in [{ k: 'berdampingan', n: 'Depan–belakang berdampingan (3 pegawai/lembar)' }, { k: 'bolak_balik', n: 'Bolak-balik (9 kartu/lembar, printer dua sisi)' }]" :key="m.k"
              class="flex min-h-[44px] items-center gap-2 rounded-xl border border-garis px-3 text-sm font-semibold"><input v-model="mode" type="radio" :value="m.k" class="h-5 w-5 accent-[#2C6680]" />{{ m.n }}</label>
          </div></fieldset>
      </div>
      <div class="kartu mb-3 flex flex-wrap items-center gap-2 p-2">
        <button class="tombol-teks" @click="pilihSemua"><component :is="semua ? PhCheckSquare : PhSquare" :size="20" /> {{ semua ? 'Batalkan pilihan' : 'Pilih semua yang tampil' }}</button>
        <span class="text-sm text-teks3">{{ pilih.size }} dipilih</span>
        <button class="tombol-utama ml-auto min-h-[40px] px-4 text-sm" :disabled="!pilih.size || proses" @click="siapkanMassal"><PhPrinter :size="18" weight="duotone" /> {{ proses ? 'Menyiapkan…' : 'Pratinjau cetak' }}</button>
      </div>
      <ul class="kartu divide-y divide-garis">
        <li v-for="p in calon" :key="p.id">
          <button type="button" class="flex min-h-[52px] w-full items-center gap-3 px-3 text-left hover:bg-permukaan2" :aria-pressed="pilih.has(p.id)" @click="balikPilih(p.id)">
            <component :is="pilih.has(p.id) ? PhCheckSquare : PhSquare" :size="24" :weight="pilih.has(p.id) ? 'fill' : 'regular'" :style="pilih.has(p.id) ? 'color: var(--c)' : ''" />
            <span class="min-w-0 flex-1"><span class="block font-semibold">{{ p.nama_lengkap }}</span><span class="block text-xs text-teks3">{{ p.niy || 'NIY belum diisi' }} · {{ p.nama_unit || '–' }}</span></span>
          </button>
        </li>
        <li v-if="!calon.length" class="p-4 text-sm text-teks3">Tidak ada pegawai aktif yang sesuai.</li>
      </ul>
    </template>

    <!-- Salinan kartu di luar layar untuk dibuat gambar (tanpa skala tampilan) -->
    <div v-if="saya" ref="wadahUnduh" class="layar-saja" style="position: fixed; left: -10000px; top: 0; pointer-events: none" aria-hidden="true">
      <div data-sisi="depan"><KartuPegawai :d="saya" sisi="depan" :foto="foto[saya.employee_id]" :identitas="identitasUnduh || lembaga.identitas" :direktur="direktur" /></div>
      <div data-sisi="belakang"><KartuPegawai :d="saya" sisi="belakang" :foto="foto[saya.employee_id]" :identitas="identitasUnduh || lembaga.identitas" :direktur="direktur" /></div>
    </div>
    <LembarKartu v-model:pratinjau="pratinjau" :kartu="cetakData" :foto="foto" :identitas="lembaga.identitas" :direktur="direktur" :mode="mode" />
  </div>
</template>
<style scoped>
.tab.aktif { border-color: color-mix(in srgb, var(--c) 35%, transparent); background: color-mix(in srgb, var(--c) 12%, rgb(var(--permukaan))); }
.bayang { border-radius: 3.2mm; box-shadow: 0 12px 30px -12px rgba(0,0,0,.5); }
.pratinjau-kartu { zoom: .82; }
@media (min-width: 400px) { .pratinjau-kartu { zoom: .9; } }
@media (min-width: 1024px) { .pratinjau-kartu { zoom: 1.15; } }
</style>
