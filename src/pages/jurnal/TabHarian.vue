<!-- SIMKA PRO | src/pages/jurnal/TabHarian.vue | v1.0 | Fase 3 – Tahap 3 Jurnal harian | 04/10/2026 -->
<script setup>
// Jurnal hari ini (atau kemarin, batas H+1): ceklist dari template jabatan (langsung tercatat) dan
// kegiatan tambahan yang ditulis sendiri (jam, uraian, foto opsional → diverval admin).
import { ref, computed, watch } from 'vue'
import { PhCaretLeft, PhCaretRight, PhCheckSquare, PhSquare, PhChatText, PhPlus, PhPencilSimple, PhTrash, PhLock, PhCamera, PhX, PhInfo, PhCalendarBlank } from '@phosphor-icons/vue'
import { useJurnal } from '@/stores/jurnal'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { MODE_DEMO } from '@/lib/supabase'
import { hariIniISO, formatHari, formatPanjang } from '@/lib/tanggal'
import { unggahKeDrive, kompresGambar, namaRapi } from '@/lib/penyimpanan'
import LembarBawah from '@/components/LembarBawah.vue'
import TombolAksi from '@/components/TombolAksi.vue'
import InputJam from '@/components/InputJam.vue'
import FotoBerkas from '@/components/FotoBerkas.vue'

const props = defineProps({ tanggalAwal: String })
const jr = useJurnal(); const sesi = useSesi(); const ui = useUI()
const tgl = ref(props.tanggalAwal || hariIniISO())
const geser = (n) => { tgl.value = new Date(Date.parse(tgl.value + 'T00:00:00Z') + n * 86400000).toISOString().slice(0, 10) }
watch(tgl, (t) => jr.muatHari(t).catch((e) => ui.toast(e.message, 'galat')), { immediate: true })

const h = computed(() => jr.hari?.tanggal === tgl.value ? jr.hari : null)
const kelompok = computed(() => {
  const g = []
  for (const b of h.value?.butir || []) { if (!g.length || g[g.length - 1].n !== b.kelompok) g.push({ n: b.kelompok, item: [] }); g[g.length - 1].item.push(b) }
  return g
})
const selesai = computed(() => (h.value?.butir || []).filter((b) => b.selesai).length)
const total = computed(() => h.value?.butir.length || 0)

async function balik(b) {
  if (!h.value.terbuka) return ui.toast('Jurnal tanggal ini sudah terkunci (batas pengisian H+1).', 'galat')
  try { await jr.centang(b.item_id, !b.selesai) } catch (e) { ui.toast(e.message, 'galat') }
}
const fc = ref(null)
function bukaCatatan(b) { fc.value = { item_id: b.item_id, uraian: b.uraian, catatan: b.catatan || '' } }
async function simpanCatatan() {
  try { await jr.centang(fc.value.item_id, true, fc.value.catatan.trim() || null); fc.value = null; ui.toast('Catatan disimpan dan butir ditandai selesai.', 'info') } catch (e) { ui.toast(e.message, 'galat') }
}

// ---------- Kegiatan tambahan ----------
const fk = ref(null); const foto = ref(null); const simpanan = ref(false)
const STATUS = { menunggu: { n: 'Menunggu verval', w: 'tahfizh' }, disetujui: { n: 'Disetujui', w: 'presensi' }, dikembalikan: { n: 'Dikembalikan', w: 'beranda' } }
const jam = (v) => (v ? String(v).slice(0, 5).replace(':', '.') : '')
const bolehUbah = (k) => k.status !== 'disetujui' && (h.value?.terbuka || k.status === 'dikembalikan')
function tambah() {
  if (!h.value?.terbuka) return ui.toast('Jurnal tanggal ini sudah terkunci (batas pengisian H+1).', 'galat')
  fk.value = { tanggal: tgl.value, jam_mulai: '', jam_selesai: '', uraian: '' }; foto.value = null
}
function ubah(k) { fk.value = { id: k.id, tanggal: tgl.value, jam_mulai: jam(k.jam_mulai).replace('.', ':'), jam_selesai: jam(k.jam_selesai).replace('.', ':'), uraian: k.uraian, foto_id: k.foto_id, catatan_verval: k.catatan_verval }; foto.value = null }
function pilihFoto(e) { const b = e.target.files?.[0]; e.target.value = ''; if (b && /^image\//.test(b.type)) foto.value = b; else if (b) ui.toast('Pilih berkas foto.', 'galat') }
async function simpanKegiatan() {
  const k = fk.value
  if (!k.jam_mulai || !k.jam_selesai || k.jam_selesai <= k.jam_mulai) return ui.toast('Jam selesai harus setelah jam mulai.', 'galat')
  if (k.uraian.trim().length < 5) return ui.toast('Uraian kegiatan minimal 5 karakter.', 'galat')
  simpanan.value = true
  try {
    let foto_id = k.foto_id || null
    if (foto.value && !MODE_DEMO) {
      const blob = await kompresGambar(foto.value, { maks: 1280, kualitas: 0.65 })
      foto_id = await unggahKeDrive(blob, { nama: namaRapi('Jurnal', sesi.pengguna?.niy || sesi.namaPendek, k.tanggal, Date.now()) + '.jpg',
        kategori: 'jurnal', folder: `SIMKA PRO/Jurnal/${k.tanggal.slice(0, 4)}/${k.tanggal.slice(5, 7)}`, retensiHari: 365 })
    }
    await jr.simpanKegiatan({ id: k.id, tanggal: k.tanggal, jam_mulai: k.jam_mulai, jam_selesai: k.jam_selesai, uraian: k.uraian, foto_id })
    fk.value = null; ui.toast(k.id ? 'Kegiatan diperbarui dan diajukan ulang untuk verval.' : 'Kegiatan dicatat dan menunggu verval admin.', 'info')
  } catch (e) { ui.toast(e.message, 'galat') } finally { simpanan.value = false }
}
async function hapus(k) {
  if (!(await ui.konfirmasi({ judul: 'Hapus kegiatan?', pesan: k.uraian, ya: 'Hapus', bahaya: true }))) return
  try { await jr.hapusKegiatan(k.id); ui.toast('Kegiatan dihapus.', 'info') } catch (e) { ui.toast(e.message, 'galat') }
}
</script>
<template>
  <div>
    <div class="kartu mb-3 flex items-center gap-2 p-2">
      <button class="tombol-ikon" aria-label="Hari sebelumnya" @click="geser(-1)"><PhCaretLeft :size="22" weight="bold" /></button>
      <div class="flex-1 text-center"><p class="font-bold">{{ formatHari(tgl) }}</p>
        <p class="text-xs text-teks3">{{ tgl === hariIniISO() ? 'Hari ini' : h?.terbuka ? 'Masih dapat diisi sampai hari ini' : 'Terkunci' }}</p></div>
      <button class="tombol-ikon" aria-label="Hari berikutnya" :disabled="tgl >= hariIniISO()" @click="geser(1)"><PhCaretRight :size="22" weight="bold" /></button>
    </div>

    <p v-if="jr.memuat && !h" class="py-8 text-center text-teks3">Memuat jurnal…</p>
    <template v-else-if="h">
      <p v-if="!h.terbuka" class="mb-3 flex gap-2 rounded-xl bg-permukaan2 p-3 text-sm text-teks2"><PhLock :size="18" class="mt-0.5 shrink-0" />Jurnal tanggal ini terkunci karena melewati batas pengisian H+1. Kegiatan yang dikembalikan admin masih dapat diperbaiki.</p>
      <p v-else-if="!h.wajib" class="mb-3 flex gap-2 rounded-xl bg-permukaan2 p-3 text-sm text-teks2"><PhCalendarBlank :size="18" class="mt-0.5 shrink-0" />Hari ini bukan hari wajib jurnal (libur atau sedang izin/cuti). Anda tetap dapat mengisi bila ada kegiatan.</p>

      <!-- Ceklist -->
      <section class="kartu w-tatausaha mb-4 p-4">
        <div class="mb-2 flex items-center gap-3">
          <span class="chip-ikon h-10 w-10"><PhCheckSquare :size="22" weight="duotone" /></span>
          <div class="flex-1"><h3 class="judul-bagian">Ceklist tugas</h3><p class="text-sm text-teks3">Langsung tercatat tanpa verval</p></div>
          <span class="text-sm font-bold tabular-nums">{{ selesai }}/{{ total }}</span>
        </div>
        <div class="mb-3 h-2 overflow-hidden rounded-full bg-permukaan2" role="progressbar" :aria-valuenow="selesai" aria-valuemin="0" :aria-valuemax="total" aria-label="Kemajuan ceklist">
          <div class="h-full rounded-full transition-all" :style="{ width: (total ? (100 * selesai) / total : 0) + '%', background: 'var(--c)' }" /></div>
        <div v-for="g in kelompok" :key="g.n" class="mb-2">
          <p class="mb-1 px-1 text-xs font-bold uppercase tracking-wide text-teks3">{{ g.n }}</p>
          <ul class="space-y-1">
            <li v-for="b in g.item" :key="b.item_id" :class="['butir flex items-start gap-1 rounded-xl', b.selesai && 'selesai']">
              <button type="button" class="flex min-h-[48px] flex-1 items-start gap-3 rounded-xl p-2 text-left" :disabled="!h.terbuka" :aria-pressed="b.selesai" @click="balik(b)">
                <component :is="b.selesai ? PhCheckSquare : PhSquare" :size="26" :weight="b.selesai ? 'fill' : 'regular'" class="mt-0.5 shrink-0" :style="b.selesai ? 'color: var(--c)' : ''" />
                <span class="min-w-0"><span :class="['block text-sm', b.selesai ? 'font-semibold text-teks' : 'text-teks2']">{{ b.uraian }}</span>
                  <span v-if="b.catatan" class="block text-xs italic text-teks3">“{{ b.catatan }}”</span></span>
              </button>
              <button v-if="h.terbuka" class="tombol-ikon mt-1" :aria-label="`Catatan untuk ${b.uraian}`" @click="bukaCatatan(b)"><PhChatText :size="20" /></button>
            </li>
          </ul>
        </div>
        <p v-if="!total" class="flex gap-2 text-sm text-teks3"><PhInfo :size="18" class="mt-0.5 shrink-0" />Belum ada ceklist untuk jabatan Anda. Hubungi admin, atau catat pekerjaan sebagai kegiatan tambahan.</p>
        <div v-if="h.butir_lama?.length" class="mt-2 text-sm text-teks3">Butir lama yang pernah dicentang: {{ h.butir_lama.map((b) => b.uraian).join('; ') }}</div>
      </section>

      <!-- Kegiatan tambahan -->
      <section class="kartu w-pengajuan p-4">
        <div class="mb-2 flex items-center gap-3">
          <span class="chip-ikon h-10 w-10"><PhPencilSimple :size="22" weight="duotone" /></span>
          <div class="flex-1"><h3 class="judul-bagian">Kegiatan tambahan</h3><p class="text-sm text-teks3">Ditulis sendiri, diverval admin</p></div>
          <button v-if="h.terbuka" class="tombol-garis hidden lg:inline-flex" @click="tambah"><PhPlus :size="18" weight="bold" /> Tambah</button>
        </div>
        <ul class="divide-y divide-garis">
          <li v-for="k in h.kegiatan" :key="k.id" class="flex items-start gap-3 py-3">
            <span class="w-20 shrink-0 text-sm font-bold tabular-nums">{{ jam(k.jam_mulai) }}–{{ jam(k.jam_selesai) }}</span>
            <div class="min-w-0 flex-1">
              <p class="text-sm">{{ k.uraian }}</p>
              <span :class="['lencana mt-1', 'w-' + STATUS[k.status].w]">{{ STATUS[k.status].n }}</span>
              <p v-if="k.catatan_verval" class="mt-1 text-xs italic text-teks2">Catatan admin: “{{ k.catatan_verval }}”</p>
              <div v-if="k.foto_id" class="mt-2"><FotoBerkas :id="k.foto_id" alt="Foto kegiatan" ukuran="h-20 w-28" /></div>
            </div>
            <template v-if="bolehUbah(k)">
              <button class="tombol-ikon" :aria-label="`Ubah kegiatan ${jam(k.jam_mulai)}`" @click="ubah(k)"><PhPencilSimple :size="20" /></button>
              <button class="tombol-ikon" :aria-label="`Hapus kegiatan ${jam(k.jam_mulai)}`" @click="hapus(k)"><PhTrash :size="20" /></button>
            </template>
          </li>
          <li v-if="!h.kegiatan.length" class="py-3 text-sm text-teks3">Belum ada kegiatan tambahan pada tanggal ini.</li>
        </ul>
      </section>
      <TombolAksi v-if="h.terbuka" label="Kegiatan" :ikon="PhPlus" warna="pengajuan" @klik="tambah" />
    </template>

    <LembarBawah :model-value="!!fc" @update:model-value="(v) => !v && (fc = null)" judul="Catatan butir ceklist">
      <form v-if="fc" class="space-y-3 pb-2" @submit.prevent="simpanCatatan">
        <p class="text-sm font-semibold">{{ fc.uraian }}</p>
        <textarea v-model="fc.catatan" class="isian min-h-[5rem] py-2" aria-label="Catatan" placeholder="Contoh: 12 santri setor, 2 santri izin" />
        <button class="tombol-utama w-full">Simpan dan tandai selesai</button>
      </form>
    </LembarBawah>

    <LembarBawah :model-value="!!fk" @update:model-value="(v) => !v && (fk = null)" :judul="fk?.id ? 'Ubah kegiatan' : 'Tambah kegiatan'">
      <form v-if="fk" class="space-y-3 pb-2" @submit.prevent="simpanKegiatan">
        <p class="text-sm text-teks2">{{ formatPanjang(fk.tanggal) }}</p>
        <p v-if="fk.catatan_verval" class="rounded-xl bg-permukaan2 p-3 text-sm">Catatan admin: {{ fk.catatan_verval }}</p>
        <div class="grid gap-3 sm:grid-cols-2"><InputJam v-model="fk.jam_mulai" label="Jam mulai" wajib /><InputJam v-model="fk.jam_selesai" label="Jam selesai" wajib /></div>
        <div><label class="label-isian" for="jr-uraian">Uraian kegiatan</label>
          <textarea id="jr-uraian" v-model="fk.uraian" class="isian min-h-[6rem] py-2" placeholder="Contoh: mendampingi santri lomba tahfizh tingkat kabupaten di Sungguminasa." /></div>
        <div>
          <p class="label-isian">Foto kegiatan (opsional)</p>
          <div v-if="foto" class="flex items-center gap-3 rounded-xl border border-garis p-3"><PhCamera :size="24" weight="duotone" class="text-teks2" />
            <span class="min-w-0 flex-1 truncate text-sm font-semibold">{{ foto.name }}</span>
            <button type="button" class="tombol-ikon" aria-label="Hapus foto" @click="foto = null"><PhX :size="20" /></button></div>
          <label v-else class="tombol-garis w-full cursor-pointer justify-center"><PhCamera :size="20" weight="duotone" /> {{ fk.foto_id ? 'Ganti foto' : 'Pilih atau ambil foto' }}
            <input type="file" accept="image/*" class="sr-only" @change="pilihFoto" /></label>
          <p class="mt-1 text-xs text-teks3">Foto dikompres otomatis dan disimpan di Google Drive pondok.</p>
        </div>
        <button class="tombol-utama w-full" :disabled="simpanan">{{ simpanan ? 'Menyimpan…' : 'Simpan kegiatan' }}</button>
      </form>
    </LembarBawah>
  </div>
</template>
<style scoped>
.butir.selesai { background: color-mix(in srgb, var(--c) 8%, rgb(var(--permukaan))); }
</style>
