<!-- SIMKA PRO | src/pages/pengumuman/TabPengumumanWali.vue | v1.3 | 14.30.0: saringan bawaan Semua | 29/10/2026 -->
<script setup>
// Pengumuman → tab "Untuk wali": pengumuman yang tampil di Portal Wali (dan notifikasi HP wali yang berlangganan).
// Sasaran: semua wali, jenjang, tingkat kelas, kelompok (kelas/kamar/halaqah/ekskul), santri tertentu, dan putra/putri.
// Pengelola melihat berapa wali (per santri) yang sudah membaca, dan dapat mengingatkan lewat WA wali yang belum membaca.
import { computed, onMounted, ref, watch } from 'vue'
import { PhPlus, PhMegaphone, PhPushPin, PhUsers, PhPencilSimple, PhTrash, PhMagnifyingGlass, PhX, PhCheckCircle, PhDeviceMobile, PhUsersFour } from '@phosphor-icons/vue'
import { usePengumumanWali } from '@/stores/pengumumanWali'
import { useUI } from '@/stores/ui'
import { teksPolos } from '@/lib/teksKaya'
import { formatRelatif, formatWaktu, hariIniISO } from '@/lib/tanggal'
import { alamatAplikasi } from '@/lib/wa'
import { HUBUNGAN_WALI } from '@/lib/portalWali'
import LembarBawah from '@/components/LembarBawah.vue'
import IsianTeksKaya from '@/components/IsianTeksKaya.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import TombolAksi from '@/components/TombolAksi.vue'
import TombolWA from '@/components/TombolWA.vue'

const pw = usePengumumanWali(); const ui = useUI()
onMounted(() => pw.muat())
const cari = ref('')
const tampil = computed(() => {
  const q = cari.value.toLowerCase().trim()
  return pw.daftar.filter((p) => !q || [p.judul, p.isi, p.ringkasan_sasaran].join(' ').toLowerCase().includes(q))
})
const persen = (p) => (p.penerima ? Math.round((100 * (p.sudah_dibaca || 0)) / p.penerima) : 0)
const masihBerlaku = (p) => !p.tampil_sampai || p.tampil_sampai >= hariIniISO()

// ---------- Formulir ----------
const form = ref(null); const lembar = ref(false); const menyimpan = ref(false)
const JENJANG = [{ k: 'wustha', n: 'Kesetaraan Wustha' }, { k: 'sma', n: 'SMA' }]
const JENIS_KEL = { kelas: 'Kelas', kamar: 'Kamar', halaqah: 'Halaqah', ekskul: 'Ekskul' }
const santriPilih = ref([]); const cariS = ref(''); const hasilS = ref([])
const hitungan = ref(null)

async function baru() {
  await pw.muatPilihan().catch((e) => ui.toast(e.message, 'galat'))
  form.value = { judul: '', isi: '', penting: false, tampil_sampai: '', tautan: '', nama_tautan: '', sasaran: { jenis: 'semua', jenjang: [], tingkat: [], kelompok: [], santri: [], jk: '' } }
  santriPilih.value = []; lembar.value = true
}
function ubah(p) {
  form.value = { id: p.id, judul: p.judul, isi: p.isi, penting: p.penting, tampil_sampai: p.tampil_sampai || '', tautan: p.tautan || '', nama_tautan: p.nama_tautan || '', sasaran: p.sasaran, terbit: true }
  lembar.value = true
}
const ss = computed(() => form.value?.sasaran)
function alih(arr, v) { const i = arr.indexOf(v); i >= 0 ? arr.splice(i, 1) : arr.push(v) }
const kelompokPer = computed(() => {
  const g = {}; for (const k of pw.pilihan?.kelompok || []) (g[k.jenis] ||= []).push(k)
  return Object.entries(g)
})
// Sasaran lengkap (termasuk santri tertentu) dihitung tanpa mengubah objek yang diawasi (mencegah putaran tanpa akhir)
const sasaranLengkap = computed(() => (form.value ? { ...form.value.sasaran, santri: santriPilih.value.map((s) => s.id) } : null))
let jeda
watch(() => JSON.stringify(sasaranLengkap.value), () => {
  if (!form.value || form.value.terbit) return
  clearTimeout(jeda); jeda = setTimeout(async () => { try { hitungan.value = await pw.hitung(sasaranLengkap.value) } catch { hitungan.value = null } }, 350)
}, { immediate: true })
let jedaCari
watch(cariS, (q) => {
  clearTimeout(jedaCari)
  if (q.trim().length < 2) { hasilS.value = []; return }
  jedaCari = setTimeout(async () => { try { hasilS.value = await pw.cariSantri(q.trim()) } catch { hasilS.value = [] } }, 300)
})
function tambahSantri(s) { if (!santriPilih.value.some((x) => x.id === s.id)) santriPilih.value.push(s); cariS.value = ''; hasilS.value = [] }

async function simpan() {
  const f = form.value
  if (f.judul.trim().length < 3) return ui.toast('Judul minimal 3 karakter.', 'galat')
  if (f.isi.trim().length < 3) return ui.toast('Isi pengumuman belum diisi.', 'galat')
  if (f.tampil_sampai && f.tampil_sampai < hariIniISO()) return ui.toast('Tanggal "tampil sampai" tidak boleh sebelum hari ini.', 'galat')
  if (f.tautan.trim() && !/^https?:\/\//.test(f.tautan.trim())) return ui.toast('Tautan harus diawali https://', 'galat')
  if (!f.id) {
    if (!hitungan.value?.santri) return ui.toast('Sasaran belum memiliki santri. Ubah pilihan sasaran.', 'galat')
    if (!(await ui.konfirmasi({ judul: 'Terbitkan untuk wali?', ya: 'Terbitkan',
      pesan: `Sasaran: ${hitungan.value.ringkasan} (${hitungan.value.santri} santri). Pengumuman tampil di Portal Wali; ${hitungan.value.bersesi} wali yang sudah masuk portal dapat menerima notifikasi HP bila mereka menyalakannya.` }))) return
  }
  menyimpan.value = true
  try { await pw.simpan({ ...f, sasaran: f.terbit ? f.sasaran : sasaranLengkap.value, ringkasan: hitungan.value?.ringkasan }); lembar.value = false; ui.toast(f.id ? 'Pengumuman wali diperbarui.' : 'Pengumuman untuk wali diterbitkan.', 'sukses') }
  catch (e) { ui.toast(e.message, 'galat') } finally { menyimpan.value = false }
}
async function hapus(p) {
  if (!(await ui.konfirmasi({ judul: 'Hapus pengumuman wali?', pesan: `"${p.judul}" akan hilang dari Portal Wali.`, ya: 'Hapus', bahaya: true }))) return
  try { await pw.hapus(p.id); ui.toast('Pengumuman dihapus.', 'sukses') } catch (e) { ui.toast(e.message, 'galat') }
}

// ---------- Pembaca ----------
const pembaca = ref(null); const saring = ref('semua')
async function lihatPembaca(p) {
  try { pembaca.value = { p, daftar: await pw.pembaca(p.id) }; saring.value = 'belum' } catch (e) { ui.toast(e.message, 'galat') }
}
const daftarPembaca = computed(() => (pembaca.value?.daftar || []).filter((r) => saring.value === 'semua' || (saring.value === 'sudah' ? r.dibaca_pada : !r.dibaca_pada)))
const pesanIngat = (r) => `Assalamu'alaikum warahmatullahi wabarakatuh. Bapak/Ibu ${r.nama_wali || 'wali'} dari ananda ${r.nama}, ada pengumuman pondok di Portal Wali: "${pembaca.value.p.judul}". Silakan buka ${alamatAplikasi()}#/wali (masuk dengan NIS/NISN, tanggal lahir ananda, dan 6 digit terakhir nomor HP). Jazakumullahu khairan.`
</script>

<template>
  <div class="w-portalwali space-y-3">
    <div class="kartu flex flex-wrap items-center gap-3 p-4">
      <span class="chip-ikon h-10 w-10"><PhUsersFour :size="22" weight="duotone" /></span>
      <p class="min-w-0 flex-1 text-sm text-teks2">Pengumuman di tab ini tampil di <b class="text-teks">Portal Wali</b> untuk orang tua/wali santri yang dipilih, bukan untuk pegawai.</p>
      <button class="tombol-utama hidden lg:inline-flex" @click="baru"><PhPlus :size="20" weight="bold" /> Buat untuk wali</button>
    </div>
    <div class="relative"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-teks3" />
      <input v-model="cari" class="isian pl-10" placeholder="Cari judul, isi, atau sasaran" aria-label="Cari pengumuman wali" /></div>
    <p v-if="pw.galat" class="kartu p-4 text-sm font-semibold text-merah">{{ pw.galat }}</p>
    <p v-else-if="pw.memuat && !pw.daftar.length" class="py-10 text-center text-teks3">Memuat pengumuman wali…</p>
    <p v-else-if="!tampil.length" class="kartu p-8 text-center text-teks3">Belum ada pengumuman untuk wali.</p>
    <ul v-else class="space-y-2.5">
      <li v-for="p in tampil" :key="p.id" class="kartu p-4">
        <div class="flex items-start gap-3">
          <span class="chip-ikon h-10 w-10 shrink-0"><component :is="p.penting ? PhPushPin : PhMegaphone" :size="22" weight="duotone" /></span>
          <div class="min-w-0 flex-1">
            <div class="flex flex-wrap gap-1.5">
              <span v-if="p.penting" class="lencana w-beranda">Penting</span>
              <span v-if="!masihBerlaku(p)" class="lencana w-hakakses">Sudah lewat</span>
            </div>
            <h3 class="mt-1 font-bold leading-snug">{{ p.judul }}</h3>
            <p class="mt-0.5 line-clamp-2 text-sm text-teks2">{{ teksPolos(p.isi) }}</p>
            <p class="mt-1.5 text-xs text-teks3">{{ formatRelatif(p.created_at) }} · {{ p.pembuat || 'Pengelola' }} · Sasaran: {{ p.ringkasan_sasaran }}</p>
            <div class="mt-2 flex items-center gap-2">
              <div class="h-1.5 flex-1 overflow-hidden rounded-full bg-permukaan2"><div class="h-full rounded-full bg-[#1E7D4F]" :style="{ width: persen(p) + '%' }" /></div>
              <span class="text-xs tabular-nums text-teks2">{{ p.sudah_dibaca }}/{{ p.penerima }} santri dibaca walinya</span>
            </div>
            <div class="mt-2 flex flex-wrap gap-1.5">
              <button class="tombol-garis min-h-[38px] px-3 text-sm" @click="lihatPembaca(p)"><PhUsers :size="18" /> Pembaca</button>
              <button class="tombol-garis min-h-[38px] px-3 text-sm" @click="ubah(p)"><PhPencilSimple :size="18" /> Ubah</button>
              <button class="tombol-teks min-h-[38px] px-3 text-sm" @click="hapus(p)"><PhTrash :size="18" /> Hapus</button>
            </div>
          </div>
        </div>
      </li>
    </ul>
    <TombolAksi label="Buat untuk wali" :ikon="PhPlus" warna="portalwali" @klik="baru" />

    <!-- Formulir -->
    <LembarBawah v-model="lembar" :judul="form?.id ? 'Ubah pengumuman wali' : 'Pengumuman untuk wali'" lebar>
      <div v-if="form" class="space-y-4 px-5">
        <div><label class="label-isian" for="pw-judul">Judul</label><input id="pw-judul" v-model="form.judul" class="isian" maxlength="150" /></div>
        <IsianTeksKaya v-model="form.isi" id="pw-isi" label="Isi pengumuman" wajib />
        <div class="grid gap-3 sm:grid-cols-2">
          <InputTanggal v-model="form.tampil_sampai" label="Tampil sampai (kosongkan bila tanpa batas)" bawaan-kosong />
          <label class="flex min-h-[44px] items-center gap-2.5 self-end text-sm font-semibold"><input v-model="form.penting" type="checkbox" class="h-5 w-5 accent-[#C7332F]" /> Tandai Penting</label>
        </div>
        <div class="grid gap-3 sm:grid-cols-[2fr_1fr]">
          <div><label class="label-isian" for="pw-tautan">Tautan (opsional)</label><input id="pw-tautan" v-model="form.tautan" class="isian" placeholder="https://…" inputmode="url" /></div>
          <div><label class="label-isian" for="pw-nt">Nama tautan</label><input id="pw-nt" v-model="form.nama_tautan" class="isian" placeholder="mis. Formulir pendaftaran" /></div>
        </div>

        <fieldset v-if="!form.terbit" class="space-y-3 rounded-2xl border border-garis p-4">
          <legend class="px-1 text-sm font-bold">Sasaran wali</legend>
          <div class="flex flex-wrap gap-2">
            <button v-for="j in [{ k: 'semua', n: 'Semua santri aktif' }, { k: 'pilihan', n: 'Pilih sasaran' }]" :key="j.k" type="button" @click="ss.jenis = j.k"
              :class="['min-h-[40px] rounded-xl border px-3.5 text-sm font-semibold', ss.jenis === j.k ? 'border-[#A3305F]/50 bg-[#A3305F]/10 text-teks' : 'border-garis text-teks2']">{{ j.n }}</button>
            <select v-model="ss.jk" class="isian ml-auto w-auto min-w-[9rem]" aria-label="Putra atau putri"><option value="">Putra dan putri</option><option value="L">Putra saja</option><option value="P">Putri saja</option></select>
          </div>
          <template v-if="ss.jenis === 'pilihan'">
            <p class="text-xs text-teks3">Pilihan di bawah digabung: santri yang cocok dengan salah satu pilihan menjadi sasaran.</p>
            <div><p class="label-isian">Jenjang</p><div class="flex flex-wrap gap-2">
              <button v-for="j in JENJANG" :key="j.k" type="button" @click="alih(ss.jenjang, j.k)" :class="['chip-pilih', ss.jenjang.includes(j.k) && 'aktif']">{{ j.n }}</button></div></div>
            <div><p class="label-isian">Tingkat kelas</p><div class="flex flex-wrap gap-2">
              <button v-for="t in [7, 8, 9, 10, 11, 12]" :key="t" type="button" @click="alih(ss.tingkat, String(t))" :class="['chip-pilih tabular-nums', ss.tingkat.includes(String(t)) && 'aktif']">
                Kelas {{ t }} <span class="text-xs text-teks3">({{ pw.pilihan?.tingkat?.[t] || 0 }})</span></button></div></div>
            <div v-for="[jenis, daftar] in kelompokPer" :key="jenis"><p class="label-isian">{{ JENIS_KEL[jenis] }}</p><div class="flex flex-wrap gap-2">
              <button v-for="k in daftar" :key="k.id" type="button" @click="alih(ss.kelompok, k.id)" :class="['chip-pilih', ss.kelompok.includes(k.id) && 'aktif']">
                {{ k.nama }} <span class="text-xs text-teks3">({{ k.jumlah }})</span></button></div></div>
            <div>
              <p class="label-isian">Santri tertentu</p>
              <div class="relative"><PhMagnifyingGlass :size="18" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-teks3" />
                <input v-model="cariS" class="isian pl-10" placeholder="Ketik nama atau NIS (minimal 2 huruf)" aria-label="Cari santri" /></div>
              <ul v-if="hasilS.length" class="mt-1 max-h-48 overflow-y-auto rounded-xl border border-garis">
                <li v-for="s in hasilS" :key="s.id"><button type="button" class="flex w-full items-center gap-2 px-3 py-2 text-left text-sm hover:bg-permukaan2" @click="tambahSantri(s)">
                  <span class="tabular-nums text-teks3">{{ s.nis }}</span> <span class="font-semibold">{{ s.nama }}</span> <span class="text-teks3">{{ s.kelas || '' }}</span></button></li>
              </ul>
              <div v-if="santriPilih.length" class="mt-2 flex flex-wrap gap-1.5">
                <span v-for="s in santriPilih" :key="s.id" class="lencana w-santri gap-1">{{ s.nama }}
                  <button type="button" :aria-label="'Hapus ' + s.nama" @click="santriPilih.splice(santriPilih.indexOf(s), 1)"><PhX :size="12" weight="bold" /></button></span>
              </div>
            </div>
          </template>
          <p class="rounded-xl bg-permukaan2 px-3 py-2 text-sm">
            <b class="tabular-nums">{{ hitungan?.santri ?? '…' }}</b> santri sasaran · <span class="inline-flex items-center gap-1"><PhDeviceMobile :size="16" /> <b class="tabular-nums">{{ hitungan?.bersesi ?? '…' }}</b> sudah ada wali yang masuk portal</span>
          </p>
        </fieldset>
        <p v-else class="text-sm text-teks3">Sasaran tidak dapat diubah setelah terbit. Untuk sasaran lain, buat pengumuman baru.</p>
        <button class="tombol-utama w-full" :disabled="menyimpan" @click="simpan">{{ menyimpan ? 'Menyimpan…' : form.id ? 'Simpan perubahan' : 'Terbitkan untuk wali' }}</button>
      </div>
    </LembarBawah>

    <!-- Pembaca -->
    <LembarBawah :model-value="!!pembaca" :judul="pembaca ? 'Pembaca: ' + pembaca.p.judul : ''" lebar @update:model-value="(v) => !v && (pembaca = null)">
      <div v-if="pembaca" class="px-5">
        <div class="bilah-tab kecil mb-3" role="tablist" aria-label="Saring pembaca">
          <button v-for="s in [{ k: 'belum', n: 'Belum dibaca' }, { k: 'sudah', n: 'Sudah dibaca' }, { k: 'semua', n: 'Semua' }]" :key="s.k" type="button" role="tab" :aria-selected="saring === s.k" @click="saring = s.k"
            :class="['tab-garis', saring === s.k && 'aktif']">
            {{ s.n }} ({{ pembaca.daftar.filter((r) => s.k === 'semua' || (s.k === 'sudah' ? r.dibaca_pada : !r.dibaca_pada)).length }})</button>
        </div>
        <p v-if="!daftarPembaca.length" class="py-6 text-center text-sm text-teks3">Tidak ada data.</p>
        <ul v-else class="divide-y divide-garis/70">
          <li v-for="r in daftarPembaca" :key="r.student_id" class="flex flex-wrap items-center gap-2 py-2.5">
            <div class="min-w-0 flex-1">
              <p class="truncate font-semibold">{{ r.nama }} <span class="font-normal tabular-nums text-teks3">· {{ r.nis }}<template v-if="r.kelas"> · {{ r.kelas }}</template></span></p>
              <p class="text-xs text-teks3">
                <template v-if="r.dibaca_pada"><PhCheckCircle :size="14" weight="fill" class="inline text-[#1E7D4F]" /> Dibaca {{ (HUBUNGAN_WALI[r.dibaca_hubungan] || 'wali').toLowerCase() }} · {{ formatWaktu(r.dibaca_pada) }}</template>
                <template v-else>{{ r.bersesi ? 'Wali sudah masuk portal, belum membaca' : 'Wali belum pernah masuk portal' }}</template></p>
            </div>
            <TombolWA v-if="!r.dibaca_pada" :hp="r.no_hp" :pesan="pesanIngat(r)" label="Ingatkan" kecil />
          </li>
        </ul>
      </div>
    </LembarBawah>
  </div>
</template>
<style scoped>
.chip-pilih { min-height: 38px; border-radius: .75rem; border: 1px solid rgb(var(--garis)); padding: 0 .75rem; font-size: .875rem; font-weight: 600; color: rgb(var(--teks-2)); }
.chip-pilih.aktif { border-color: color-mix(in srgb, var(--c) 50%, transparent); background: color-mix(in srgb, var(--c) 12%, rgb(var(--permukaan))); color: rgb(var(--teks)); }
</style>
