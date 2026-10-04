<!-- SIMKA PRO | src/pages/kartu/Kartu.vue | v1.0 | Fase 3 – Tahap 4 Berkas Saya dan kartu pegawai | 04/10/2026 -->
<script setup>
// Kartu pegawai. Kartu saya: lihat depan/belakang, ganti pas foto, cetak, dan ganti kode bila kartu hilang.
// Cetak massal (admin ber-izin cetak_kartu): pilih pegawai, cetak 10 kartu per F4 (bolak-balik) atau berdampingan.
// Kartu otomatis tidak berlaku (verifikasi QR) bila pegawai berstatus nonaktif.
import { ref, computed, onMounted, watch } from 'vue'
import { PhIdentificationCard, PhCards, PhCamera, PhPrinter, PhArrowsClockwise, PhMagnifyingGlass, PhCheckSquare, PhSquare, PhInfo, PhQrCode, PhLink } from '@phosphor-icons/vue'
import { useKartu } from '@/stores/kartu'
import { useLembaga } from '@/stores/lembaga'
import { usePegawai } from '@/stores/pegawai'
import { useOrganisasi } from '@/stores/organisasi'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { MODE_DEMO } from '@/lib/supabase'
import { alamatBerkas } from '@/lib/penyimpanan'
import { alamatVerifikasi } from '@/lib/kartu'
import KartuPegawai from '@/components/KartuPegawai.vue'
import LembarKartu from '@/components/cetak/LembarKartu.vue'

const kt = useKartu(); const lembaga = useLembaga(); const peg = usePegawai(); const org = useOrganisasi(); const sesi = useSesi(); const ui = useUI()
const bolehMassal = computed(() => sesi.bolehAdmin('cetak_kartu'))
const tab = ref('saya'); const saya = ref(null); const foto = ref({}); const proses = ref(false); const balik = ref(false)
const pratinjau = ref(false); const cetakData = ref([]); const mode = ref('berdampingan')
const direktur = computed(() => lembaga.signatories.find((s) => s.sumber_jabatan === 'DIREKTUR' || /^direktur/i.test(s.jabatan_tertulis)) || {})

onMounted(async () => { await lembaga.muat(); muatSaya() })
async function muatSaya() {
  try { const [d] = await kt.data(); saya.value = d; if (d?.foto_id) foto.value[d.employee_id] = await alamatBerkas(d.foto_id) } catch (e) { ui.toast(e.message, 'galat') }
}
async function gantiFoto(e) {
  const b = e.target.files?.[0]; e.target.value = ''
  if (!b) return
  if (!/^image\//.test(b.type)) return ui.toast('Pilih berkas foto.', 'galat')
  if (MODE_DEMO) { foto.value[saya.value.employee_id] = URL.createObjectURL(b); return ui.toast('Mode demo: foto hanya tampil sementara.', 'info') }
  proses.value = true
  try { await kt.pasangFoto(saya.value.employee_id, b); await muatSaya(); ui.toast('Pas foto diperbarui (dipotong 3:4).', 'info') } catch (er) { ui.toast(er.message, 'galat') } finally { proses.value = false }
}
async function gantiKode() {
  if (!(await ui.konfirmasi({ judul: 'Ganti kode kartu?', pesan: 'Gunakan bila kartu hilang. Kartu lama langsung tidak dapat diverifikasi dan Anda perlu mencetak kartu baru.', ya: 'Ganti kode', bahaya: true }))) return
  try { saya.value.kode = await kt.gantiKode(saya.value.employee_id); ui.toast('Kode kartu diganti. Cetak ulang kartu Anda.', 'info') } catch (e) { ui.toast(e.message, 'galat') }
}
function cetakSaya() { cetakData.value = [saya.value]; mode.value = 'berdampingan'; pratinjau.value = true }
async function salinTautan() { try { await navigator.clipboard.writeText(alamatVerifikasi(saya.value.kode)); ui.toast('Tautan verifikasi disalin.', 'info') } catch { ui.toast(alamatVerifikasi(saya.value.kode), 'info') } }

// ---------- Cetak massal ----------
const pilih = ref(new Set()); const unit = ref(''); const cari = ref('')
watch(tab, async (t) => { if (t === 'massal') { await Promise.all([org.muat(), peg.daftar.length ? null : peg.muat()]) } })
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
  <div class="w-profil mx-auto max-w-4xl">
    <nav v-if="bolehMassal" class="mb-4 flex gap-2" role="tablist" aria-label="Bagian kartu pegawai">
      <button v-for="t in [{ k: 'saya', n: 'Kartu saya', i: PhIdentificationCard }, { k: 'massal', n: 'Cetak massal', i: PhCards }]" :key="t.k" role="tab" :aria-selected="tab === t.k" @click="tab = t.k"
        :class="['tab flex min-h-[44px] items-center gap-2.5 rounded-xl border px-3 text-sm font-semibold', tab === t.k ? 'aktif text-teks' : 'border-garis bg-permukaan text-teks2']">
        <span class="chip-ikon h-8 w-8 rounded-lg"><component :is="t.i" :size="20" weight="duotone" /></span>{{ t.n }}</button>
    </nav>

    <template v-if="tab === 'saya'">
      <p v-if="!saya" class="py-10 text-center text-teks3">Menyiapkan kartu…</p>
      <div v-else class="grid gap-5 lg:grid-cols-[auto_1fr]">
        <div class="flex flex-col items-center gap-3">
          <button type="button" class="balik-kartu" :aria-label="balik ? 'Lihat sisi depan' : 'Lihat sisi belakang'" @click="balik = !balik">
            <KartuPegawai :d="saya" :sisi="balik ? 'belakang' : 'depan'" :foto="foto[saya.employee_id]" :identitas="lembaga.identitas" :direktur="direktur" />
          </button>
          <p class="text-xs text-teks3">Ketuk kartu untuk melihat sisi {{ balik ? 'depan' : 'belakang' }}</p>
        </div>
        <div class="space-y-3">
          <div :class="['kartu p-4', saya.aktif ? 'w-presensi' : 'w-beranda']">
            <p class="flex items-center gap-2 font-bold"><PhQrCode :size="22" weight="duotone" style="color: var(--c)" /> {{ saya.aktif ? 'Kartu berlaku' : 'Kartu tidak berlaku' }}</p>
            <p class="mt-1 text-sm text-teks2">Berlaku selama Anda tercatat sebagai pegawai aktif. Siapa pun dapat memindai kode QR untuk memeriksa keabsahannya.</p>
            <button class="tombol-teks mt-1 text-sm" @click="salinTautan"><PhLink :size="18" /> Salin tautan verifikasi</button>
          </div>
          <label class="tombol-garis w-full cursor-pointer justify-center" :class="proses && 'opacity-60'"><PhCamera :size="20" weight="duotone" /> {{ saya.foto_id ? 'Ganti pas foto' : 'Unggah pas foto' }}
            <input type="file" accept="image/*" class="sr-only" :disabled="proses" @change="gantiFoto" /></label>
          <p class="text-xs text-teks3">Gunakan foto tegak berlatar polos, berpakaian rapi. Foto dipotong otomatis 3:4.</p>
          <button class="tombol-utama w-full" @click="cetakSaya"><PhPrinter :size="20" weight="duotone" /> Cetak kartu (F4)</button>
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
            <label v-for="m in [{ k: 'berdampingan', n: 'Depan–belakang berdampingan (5 pegawai/lembar)' }, { k: 'bolak_balik', n: 'Bolak-balik (10 kartu/lembar, printer dua sisi)' }]" :key="m.k"
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

    <LembarKartu v-model:pratinjau="pratinjau" :kartu="cetakData" :foto="foto" :identitas="lembaga.identitas" :direktur="direktur" :mode="mode" />
  </div>
</template>
<style scoped>
.tab.aktif { border-color: color-mix(in srgb, var(--c) 35%, transparent); background: color-mix(in srgb, var(--c) 12%, rgb(var(--permukaan))); }
.balik-kartu { border-radius: 3.2mm; box-shadow: 0 10px 30px -12px rgba(0,0,0,.45); }
@media (max-width: 380px) { .balik-kartu { zoom: .9; } }
</style>
