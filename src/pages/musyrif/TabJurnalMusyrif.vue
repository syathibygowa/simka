<!-- SIMKA PRO | src/pages/musyrif/TabJurnalMusyrif.vue | v1.0 | Fase 6 – Tahap 3 Jurnal musyrif dan klinik lanjutan | 06/10/2026 -->
<script setup>
// Jurnal musyrif satu kamar: catatan kegiatan kepengasuhan per hari (waktu, kategori, uraian, santri terkait,
// foto opsional ke Drive, tanda "penting" → Kepala Bidang Kesantrian). Pimpinan Kesantrian memberi tanggapan.
// Cetak F4 dan salin ringkasan untuk grup WA internal.
import { ref, computed, watch, onMounted } from 'vue'
import { PhNotePencil, PhPencilSimple, PhTrash, PhStar, PhChatCircleText, PhCamera, PhEye, PhCopy, PhFloppyDisk } from '@phosphor-icons/vue'
import { useMusyrif } from '@/stores/musyrif'
import { useKlinik } from '@/stores/klinik'
import { useSantri } from '@/stores/santri'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { KATEGORI_JURNAL, WAKTU_JURNAL, waktuSekarang, awalPekan, namaHari, teksRentang } from '@/lib/musyrif'
import { penandaKelompok } from '@/lib/santri'
import { hariIniISO, formatPendek, formatWaktu } from '@/lib/tanggal'
import { MODE_DEMO } from '@/lib/supabase'
import { unggahKeDrive, kompresGambar, namaRapi } from '@/lib/penyimpanan'
import InputTanggal from '@/components/InputTanggal.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import TombolAksi from '@/components/TombolAksi.vue'
import FotoBerkas from '@/components/FotoBerkas.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const props = defineProps({ calon: { type: Array, default: () => [] } })
const mu = useMusyrif(); const kl = useKlinik(); const san = useSantri(); const sesi = useSesi(); const ui = useUI()
const hari = hariIniISO()
const mulai = ref(awalPekan(hari)); const selesai = ref(hari); const daftar = ref([]); const memuat = ref(false)
const penanda = ref({ jabatan: '', nama: '', niy: '' })

async function muat() {
  if (!mu.pilih) return
  memuat.value = true
  try { daftar.value = await mu.jurnal(mu.pilih, mulai.value, selesai.value) } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
onMounted(async () => {
  await san.muat(); muat()
  if (!kl.hakDimuat) kl.muatHak().catch(() => {})
  penanda.value = await penandaKelompok({ jenis: 'kamar' }).catch(() => penanda.value)
})
watch(() => [mu.pilih, mulai.value, selesai.value], muat)

const bolehTulis = computed(() => mu.kamarPilih?.asuhan_saya || sesi.peran === 'superadmin')
const bolehTanggapi = computed(() => kl.hak.pimpinan || sesi.peran === 'superadmin')
const perTanggal = computed(() => {
  const g = {}; for (const j of daftar.value) (g[j.tanggal] ||= []).push(j)
  return Object.entries(g).sort((a, b) => b[0].localeCompare(a[0]))
})

// ---------- Tulis/ubah ----------
const lembar = ref(false); const isi = ref({}); const proses = ref(false); const fotoBaru = ref(null); const pratinjauFoto = ref('')
function tulis(j = null) {
  isi.value = j ? { id: j.id, tanggal: j.tanggal, waktu: j.waktu, kategori: j.kategori, uraian: j.uraian, santri_ids: j.santri.map((s) => s.id), penting: j.penting, foto_id: j.foto_id }
    : { tanggal: hari, waktu: waktuSekarang(), kategori: '', uraian: '', santri_ids: [], penting: false, foto_id: null }
  fotoBaru.value = null; pratinjauFoto.value = ''; lembar.value = true
}
function pilihFoto(e) { const f = e.target.files?.[0]; e.target.value = ''; if (!f) return; if (!/^image\//.test(f.type)) return ui.toast('Pilih berkas foto.', 'galat'); fotoBaru.value = f; pratinjauFoto.value = URL.createObjectURL(f) }
function alihSantri(id) { const s = new Set(isi.value.santri_ids); s.has(id) ? s.delete(id) : s.add(id); isi.value.santri_ids = [...s] }
async function simpan() {
  if (!isi.value.kategori) return ui.toast('Pilih kategori jurnal.', 'galat')
  if (isi.value.uraian.trim().length < 5) return ui.toast('Tuliskan uraian kegiatan (minimal 5 huruf).', 'galat')
  proses.value = true
  try {
    let fotoId = isi.value.foto_id
    if (fotoBaru.value && !MODE_DEMO) {
      const blob = await kompresGambar(fotoBaru.value, { maks: 1280, kualitas: 0.65 }); const t = isi.value.tanggal
      fotoId = await unggahKeDrive(blob, { nama: namaRapi('Jurnal', mu.kamarPilih?.nama, t, Date.now()) + '.jpg', kategori: 'jurnal_musyrif', folder: `SIMKA PRO/Jurnal Musyrif/${t.slice(0, 4)}/${t.slice(5, 7)}`, retensiHari: 365 })
    }
    await mu.simpanJurnal({ ...isi.value, uraian: isi.value.uraian.trim(), group_id: mu.pilih, foto_id: fotoId || null })
    ui.toast(isi.value.penting ? 'Jurnal tersimpan dan diteruskan ke Kepala Bidang Kesantrian.' : 'Jurnal tersimpan.')
    lembar.value = false; await muat()
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
async function hapus(j) {
  if (!(await ui.konfirmasi({ judul: 'Hapus jurnal?', pesan: j.uraian.slice(0, 120), ya: 'Hapus', bahaya: true }))) return
  try { await mu.hapusJurnal(j.id, mu.pilih); ui.toast('Jurnal dihapus.'); await muat() } catch (e) { ui.toast(e.message, 'galat') }
}

// ---------- Tanggapan pimpinan ----------
const lembarTanggap = ref(false); const pilih = ref(null); const tanggapan = ref('')
function tanggapi(j) { pilih.value = j; tanggapan.value = j.tanggapan || ''; lembarTanggap.value = true }
async function kirimTanggapan() {
  proses.value = true
  try { await mu.tanggapiJurnal(pilih.value.id, tanggapan.value.trim(), mu.pilih); lembarTanggap.value = false; ui.toast('Tanggapan tersimpan; musyrif mendapat notifikasi.'); await muat() }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}

// ---------- Salin dan cetak ----------
async function salin() {
  const baris = [...daftar.value].reverse().map((j) => `• ${namaHari(j.tanggal)} ${formatPendek(j.tanggal).slice(0, 5)} ${WAKTU_JURNAL[j.waktu].toLowerCase()} [${KATEGORI_JURNAL[j.kategori].n}]: ${j.uraian}`)
  const teks = `Jurnal musyrif ${mu.kamarPilih?.nama}, ${teksRentang(mulai.value, selesai.value)}:\n${baris.join('\n') || '• Belum ada catatan.'}\n\n${sesi.pengguna?.nama_lengkap || ''}`
  try { await navigator.clipboard.writeText(teks); ui.toast('Jurnal disalin. Tempel di grup WA internal.') } catch { ui.toast('Tidak dapat menyalin otomatis.', 'galat') }
}
const pratinjau = ref(false)
const musyrifSaya = computed(() => mu.kamarPilih?.musyrif.find((m) => m.employee_id === sesi.pengguna?.id) || mu.kamarPilih?.musyrif[0] || null)
</script>
<template>
  <div>
    <div class="kartu mb-4 grid grid-cols-2 gap-3 p-4 sm:grid-cols-[1fr_1fr_auto]">
      <InputTanggal v-model="mulai" label="Dari" wajib /><InputTanggal v-model="selesai" label="Sampai" wajib />
      <div class="col-span-2 flex items-end gap-2 sm:col-span-1">
        <button class="tombol-garis w-agenda min-h-[44px] px-3 text-sm" @click="salin"><PhCopy :size="18" style="color: var(--c)" /> Salin</button>
        <button class="tombol-garis w-pengajuan min-h-[44px] px-3 text-sm" @click="pratinjau = true"><PhEye :size="18" style="color: var(--c)" /> Cetak</button>
        <button v-if="bolehTulis" class="tombol-utama hidden min-h-[44px] lg:inline-flex" @click="tulis()"><PhNotePencil :size="20" weight="duotone" /> Tulis jurnal</button>
      </div>
    </div>

    <p v-if="memuat && !daftar.length" class="kartu p-8 text-center text-sm text-teks3">Memuat jurnal…</p>
    <p v-else-if="!daftar.length" class="kartu p-8 text-center text-sm text-teks3">Belum ada jurnal pada rentang ini.{{ bolehTulis ? ' Ketuk "Tulis jurnal" untuk mencatat kegiatan kamar.' : '' }}</p>
    <section v-for="[tgl, isiTgl] in perTanggal" :key="tgl" class="mb-4">
      <h3 class="mb-2 text-sm font-bold text-teks2">{{ namaHari(tgl) }}, {{ formatPendek(tgl) }} · {{ isiTgl.length }} catatan</h3>
      <ul class="grid gap-3 md:grid-cols-2">
        <li v-for="j in isiTgl" :key="j.id" class="kartu p-4" :class="'w-' + KATEGORI_JURNAL[j.kategori].w">
          <div class="flex items-start gap-3">
            <span class="chip-ikon h-10 w-10 shrink-0"><component :is="KATEGORI_JURNAL[j.kategori].ikon" :size="22" weight="duotone" /></span>
            <div class="min-w-0 flex-1">
              <p class="flex flex-wrap items-center gap-1.5"><span class="lencana" :class="'w-' + KATEGORI_JURNAL[j.kategori].w">{{ KATEGORI_JURNAL[j.kategori].n }}</span>
                <span class="text-xs text-teks3">{{ WAKTU_JURNAL[j.waktu] }}</span>
                <span v-if="j.penting" class="lencana w-pengajuan"><PhStar :size="12" weight="fill" /> Penting</span></p>
              <p class="mt-1.5 whitespace-pre-line text-sm text-teks">{{ j.uraian }}</p>
              <p v-if="j.santri.length" class="mt-1 text-xs text-teks2">Santri: {{ j.santri.map((s) => s.nama).join(', ') }}</p>
              <FotoBerkas v-if="j.foto_id" :id="j.foto_id" alt="Foto jurnal" ukuran="mt-2 h-24 w-32" />
              <p class="mt-1 text-xs text-teks3">{{ j.penulis }}</p>
              <p v-if="j.tanggapan" class="mt-2 rounded-lg bg-permukaan2 px-2.5 py-1.5 text-xs"><b>Tanggapan {{ j.ditanggapi_oleh }}:</b> {{ j.tanggapan }}
                <span class="text-teks3"> · {{ formatWaktu(j.ditanggapi_pada) }}</span></p>
              <div class="mt-2 flex flex-wrap gap-2">
                <button v-if="j.boleh_ubah" class="tombol-garis min-h-[36px] px-3 text-xs" @click="tulis(j)"><PhPencilSimple :size="16" /> Ubah</button>
                <button v-if="j.boleh_ubah" class="tombol-garis min-h-[36px] px-3 text-xs" @click="hapus(j)"><PhTrash :size="16" /> Hapus</button>
                <button v-if="bolehTanggapi" class="tombol-garis w-agenda min-h-[36px] px-3 text-xs" @click="tanggapi(j)"><PhChatCircleText :size="16" style="color: var(--c)" /> {{ j.tanggapan ? 'Ubah tanggapan' : 'Tanggapi' }}</button>
              </div>
            </div>
          </div>
        </li>
      </ul>
    </section>

    <TombolAksi v-if="bolehTulis" label="Tulis jurnal" :ikon="PhNotePencil" warna="musyrif" @klik="tulis()" />

    <LembarBawah v-model="lembar" :judul="isi.id ? 'Ubah jurnal' : 'Tulis jurnal musyrif'">
      <div class="space-y-3 pb-2">
        <div class="grid gap-3 sm:grid-cols-2">
          <InputTanggal v-model="isi.tanggal" label="Tanggal" wajib />
          <div><label class="label-isian" for="jm-waktu">Waktu</label>
            <select id="jm-waktu" v-model="isi.waktu" class="isian"><option v-for="(n, k) in WAKTU_JURNAL" :key="k" :value="k">{{ n }}</option></select></div>
        </div>
        <div><p class="label-isian">Kategori <span class="text-merah">*</span></p>
          <div class="grid grid-cols-2 gap-2 sm:grid-cols-4" role="radiogroup" aria-label="Kategori jurnal">
            <button v-for="(k, kode) in KATEGORI_JURNAL" :key="kode" type="button" role="radio" :aria-checked="isi.kategori === kode" @click="isi.kategori = kode"
              :class="['flex min-h-[46px] items-center gap-2 rounded-xl border px-3 text-left text-sm font-semibold', 'w-' + k.w, isi.kategori === kode ? 'kat-pilih' : 'border-garis text-teks2']">
              <component :is="k.ikon" :size="20" weight="duotone" style="color: var(--c)" />{{ k.n }}</button>
          </div></div>
        <div><label class="label-isian" for="jm-uraian">Uraian kegiatan <span class="text-merah">*</span></label>
          <textarea id="jm-uraian" v-model="isi.uraian" rows="4" class="isian" placeholder="Contoh: apel malam, pemeriksaan kebersihan kamar, kejadian dan tindak lanjutnya" /></div>
        <div v-if="calon.length"><p class="label-isian">Santri terkait (opsional)</p>
          <div class="flex max-h-40 flex-wrap gap-1.5 overflow-y-auto">
            <button v-for="s in calon" :key="s.id" type="button" :aria-pressed="isi.santri_ids.includes(s.id)" @click="alihSantri(s.id)"
              :class="['min-h-[34px] rounded-full border px-3 text-xs font-semibold', isi.santri_ids.includes(s.id) ? 'border-transparent bg-[#245E3F] text-white' : 'border-garis text-teks2']">{{ s.nama }}</button>
          </div></div>
        <div class="flex flex-wrap items-center gap-3">
          <img v-if="pratinjauFoto" :src="pratinjauFoto" alt="Foto baru" class="h-20 w-28 rounded-xl object-cover" />
          <FotoBerkas v-else-if="isi.foto_id" :id="isi.foto_id" alt="Foto jurnal" ukuran="h-20 w-28" />
          <label class="tombol-garis cursor-pointer"><PhCamera :size="20" weight="duotone" /> {{ isi.foto_id || pratinjauFoto ? 'Ganti foto' : 'Foto (opsional)' }}
            <input type="file" accept="image/*" capture="environment" class="sr-only" @change="pilihFoto" /></label>
        </div>
        <label class="flex min-h-[44px] items-center gap-3 rounded-xl bg-permukaan2 px-3 text-sm"><input v-model="isi.penting" type="checkbox" class="h-5 w-5 accent-[#B5501A]" />
          <span><b>Tandai penting</b><span class="block text-xs text-teks3">Kepala Bidang Kesantrian mendapat notifikasi.</span></span></label>
        <button class="tombol-utama w-full" :disabled="proses" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> Simpan jurnal</button>
      </div>
    </LembarBawah>

    <LembarBawah v-model="lembarTanggap" judul="Tanggapan pimpinan">
      <div v-if="pilih" class="space-y-3 pb-2">
        <p class="text-sm text-teks2">{{ pilih.uraian }}</p>
        <textarea v-model="tanggapan" rows="3" class="isian" placeholder="Arahan atau tanggapan untuk musyrif" aria-label="Tanggapan" />
        <button class="tombol-utama w-full" :disabled="proses" @click="kirimTanggapan"><PhChatCircleText :size="20" weight="duotone" /> Simpan tanggapan</button>
      </div>
    </LembarBawah>

    <DokumenCetak kop="pondok" judul="Jurnal Musyrif" :subjudul="`${mu.kamarPilih?.nama || ''} · ${teksRentang(mulai, selesai)}`" v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap">
      <table class="tabel">
        <thead><tr><th style="width:5%">No.</th><th style="width:17%">Hari, tanggal</th><th style="width:9%">Waktu</th><th style="width:12%">Kategori</th><th>Uraian kegiatan</th><th style="width:18%">Santri terkait</th></tr></thead>
        <tbody>
          <tr v-for="(j, i) in [...daftar].reverse()" :key="j.id"><td class="tengah">{{ i + 1 }}</td><td>{{ namaHari(j.tanggal) }}, {{ formatPendek(j.tanggal) }}</td>
            <td class="tengah">{{ WAKTU_JURNAL[j.waktu] }}</td><td>{{ KATEGORI_JURNAL[j.kategori].n }}{{ j.penting ? ' (penting)' : '' }}</td>
            <td>{{ j.uraian }}<template v-if="j.tanggapan"><br />Tanggapan: {{ j.tanggapan }}</template></td><td>{{ j.santri.map((s) => s.nama).join(', ') || '–' }}</td></tr>
          <tr v-if="!daftar.length"><td colspan="6" class="tengah">Belum ada jurnal pada rentang ini.</td></tr>
        </tbody>
      </table>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: penanda.jabatan, nama: penanda.nama, niy: penanda.niy }"
          :kanan="{ jabatan: 'Musyrif ' + (mu.kamarPilih?.nama || ''), nama: musyrifSaya?.nama || '', niy: musyrifSaya?.niy }" />
      </template>
    </DokumenCetak>
  </div>
</template>
<style scoped>
.kat-pilih { border-color: var(--c); border-width: 2px; background: color-mix(in srgb, var(--c) 12%, transparent); color: rgb(var(--teks)); }
</style>
