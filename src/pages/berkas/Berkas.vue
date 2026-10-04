<!-- SIMKA PRO | src/pages/berkas/Berkas.vue | v1.0 | Fase 3 – Tahap 4 Berkas Saya dan kartu pegawai | 04/10/2026 -->
<script setup>
// Berkas Saya: info, formulir, surat, dan SK yang ditujukan kepada pegawai. Berkas tersimpan di Google Drive
// pondok dan dibuka lewat tautan sementara (tidak publik); setiap pembukaan tercatat. Admin ber-izin
// kelola_berkas mengirim berkas dengan sasaran dan melihat siapa yang sudah membuka.
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import * as XLSX from 'xlsx'
import { PhFolderOpen, PhInfo, PhClipboardText, PhEnvelopeSimple, PhStamp, PhFile, PhPlus, PhMagnifyingGlass, PhDownloadSimple, PhArrowSquareOut, PhUsers, PhTrash, PhPaperclip, PhX, PhFileXls, PhTray, PhListChecks } from '@phosphor-icons/vue'
import { useBerkasPegawai } from '@/stores/berkasPegawai'
import { usePengumuman } from '@/stores/pengumuman'
import { useUI } from '@/stores/ui'
import { MODE_DEMO } from '@/lib/supabase'
import { ambilBerkasUrl, unggahKeDrive, kompresGambar, namaRapi } from '@/lib/penyimpanan'
import { formatPanjang, formatPendek, formatRelatif, formatWaktu, hariIniISO } from '@/lib/tanggal'
import LembarBawah from '@/components/LembarBawah.vue'
import TombolAksi from '@/components/TombolAksi.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import PilihSasaran from '@/components/PilihSasaran.vue'

const props = defineProps({ id: String })
const router = useRouter(); const bp = useBerkasPegawai(); const pg = usePengumuman(); const ui = useUI()
const KAT = { info: { n: 'Info', i: PhInfo, w: 'pengumuman' }, formulir: { n: 'Formulir', i: PhClipboardText, w: 'shift' }, surat: { n: 'Surat', i: PhEnvelopeSimple, w: 'pegawai' },
  sk: { n: 'SK', i: PhStamp, w: 'beranda' }, lainnya: { n: 'Lainnya', i: PhFile, w: 'hakakses' } }
const kelola = computed(() => bp.bolehKelola())
const tab = ref('saya'); const kat = ref(''); const cari = ref('')
const form = ref(null); const berkas = ref(null); const ringkas = ref('Semua pegawai'); const simpanan = ref(false)
const pembuka = ref(null); const membuka = ref(false)
onMounted(() => bp.muat().catch((e) => ui.toast(e.message, 'galat')))

const terpilih = computed(() => bp.daftar.find((d) => d.id === props.id) || null)
const tampil = computed(() => {
  const q = cari.value.toLowerCase().trim()
  return bp.daftar.filter((d) => (tab.value === 'kelola' || d.saya_penerima) && (!kat.value || d.kategori === kat.value)
    && (!q || [d.judul, d.keterangan, d.nama_berkas].join(' ').toLowerCase().includes(q)))
})
const baru = computed(() => bp.daftar.filter((d) => d.saya_penerima && !d.dibuka_pertama).length)
const ukuran = (b) => (!b ? '' : b > 1048576 ? (b / 1048576).toFixed(1).replace('.', ',') + ' MB' : Math.round(b / 1024) + ' KB')

async function buka(d) {
  if (d.tautan_luar && !d.berkas_id) { window.open(d.tautan_luar, '_blank', 'noopener'); bp.catatBuka(d.id); return }
  if (MODE_DEMO) { bp.catatBuka(d.id); return ui.toast('Mode demo: berkas contoh tidak tersedia.', 'info') }
  membuka.value = true
  try {
    const url = await ambilBerkasUrl(d.berkas_id)
    const a = document.createElement('a'); a.href = url; a.target = '_blank'; a.rel = 'noopener'
    if (!/pdf|image/.test(d.mime || '')) a.download = d.nama_berkas || 'berkas'
    a.click(); await bp.catatBuka(d.id)
  } catch (e) { ui.toast(e.message, 'galat') } finally { membuka.value = false }
}

function bukaForm() { form.value = { judul: '', kategori: 'info', keterangan: '', tautan_luar: '', berlaku_sampai: '', sasaran: { jenis: 'semua' } }; berkas.value = null }
function pilihBerkas(e) {
  const b = e.target.files?.[0]; e.target.value = ''
  if (!b) return
  if (!/^image\/|application\/pdf/.test(b.type)) return ui.toast('Berkas harus PDF atau foto. Untuk dokumen Word/Excel, simpan sebagai PDF terlebih dahulu.', 'galat')
  if (b.type === 'application/pdf' && b.size > 5 * 1024 * 1024) return ui.toast('Ukuran PDF paling besar 5 MB.', 'galat')
  berkas.value = b
}
async function simpan() {
  const f = form.value
  if (f.judul.trim().length < 3) return ui.toast('Judul minimal 3 karakter.', 'galat')
  if (!berkas.value && !/^https:\/\//.test(f.tautan_luar.trim())) return ui.toast('Unggah berkas, atau isi tautan yang diawali https://', 'galat')
  if (!(await ui.konfirmasi({ judul: 'Kirim berkas?', pesan: `Sasaran: ${ringkas.value}. Setiap penerima mendapat notifikasi.`, ya: 'Kirim' }))) return
  simpanan.value = true
  try {
    let berkas_id = null
    if (berkas.value && !MODE_DEMO) {
      const blob = berkas.value.type === 'application/pdf' ? berkas.value : await kompresGambar(berkas.value, { maks: 2000, kualitas: 0.8 })
      const t = hariIniISO()
      berkas_id = await unggahKeDrive(blob, { nama: namaRapi(f.kategori.toUpperCase(), f.judul.slice(0, 40), t) + (blob.type === 'application/pdf' ? '.pdf' : '.jpg'),
        kategori: 'berkas_pegawai', folder: `SIMKA PRO/Berkas Pegawai/${t.slice(0, 4)}` })
    }
    const id = await bp.simpan({ ...f, berkas_id, ringkasan: ringkas.value, nama_berkas: berkas.value?.name, mime: berkas.value?.type })
    form.value = null; ui.toast('Berkas terkirim dan penerima diberi notifikasi.', 'info')
    if (id) router.replace(`/berkas/${id}`)
  } catch (e) { ui.toast(e.message, 'galat') } finally { simpanan.value = false }
}
async function hapus(d) {
  if (!(await ui.konfirmasi({ judul: 'Hapus berkas?', pesan: `"${d.judul}" akan hilang dari semua penerima dan berkasnya dihapus dari Drive.`, ya: 'Hapus', bahaya: true }))) return
  try { await bp.hapus(d.id); router.replace('/berkas'); ui.toast('Berkas dihapus.', 'info') } catch (e) { ui.toast(e.message, 'galat') }
}
async function lihatPembuka(d) { try { pembuka.value = { d, daftar: await bp.pembuka(d.id) } } catch (e) { ui.toast(e.message, 'galat') } }
function eksporPembuka() {
  const p = pembuka.value; const kolom = ['No.', 'Nama', 'Bidang/Unit', 'Status', 'Pertama dibuka', 'Jumlah buka']
  const data = p.daftar.map((r, i) => [i + 1, r.nama, r.unit || '', r.dibuka_pertama ? 'Sudah dibuka' : 'Belum dibuka', r.dibuka_pertama ? formatWaktu(r.dibuka_pertama) : '', r.jumlah_buka])
  const ws = XLSX.utils.aoa_to_sheet([kolom, ...data]); ws['!cols'] = [{ wch: 5 }, { wch: 36 }, { wch: 26 }, { wch: 14 }, { wch: 18 }, { wch: 12 }]
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Pembukaan'); XLSX.writeFile(wb, `Pembukaan-Berkas-${formatPendek(p.d.created_at).replace(/\//g, '-')}.xlsx`)
}
</script>
<template>
  <div class="w-berkas mx-auto max-w-3xl">
    <div class="mb-3 flex flex-wrap items-center gap-2">
      <div v-if="kelola" class="flex rounded-full bg-permukaan2 p-1" role="tablist" aria-label="Tampilan berkas">
        <button v-for="t in [{ k: 'saya', n: 'Berkas saya', i: PhTray }, { k: 'kelola', n: 'Kelola', i: PhListChecks }]" :key="t.k" role="tab" :aria-selected="tab === t.k" @click="tab = t.k"
          :class="['flex min-h-[40px] items-center gap-1.5 rounded-full px-4 text-sm font-semibold', tab === t.k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">
          <component :is="t.i" :size="18" weight="duotone" />{{ t.n }}<span v-if="t.k === 'saya' && baru" class="rounded-full bg-[#C7332F] px-1.5 text-xs text-white">{{ baru }}</span></button>
      </div>
      <button v-if="kelola" class="tombol-utama ml-auto hidden lg:inline-flex" @click="bukaForm"><PhPlus :size="20" weight="bold" /> Kirim berkas</button>
    </div>
    <div class="mb-3 flex gap-1.5 overflow-x-auto pb-1">
      <button v-for="(v, k) in { '': { n: 'Semua' }, ...KAT }" :key="k" @click="kat = k" :class="['min-h-[40px] shrink-0 rounded-full border px-3.5 text-sm font-semibold', kat === k ? 'border-transparent bg-[#C7332F] text-white' : 'border-garis bg-permukaan text-teks2']">{{ v.n }}</button>
    </div>
    <div class="relative mb-3"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-teks3" />
      <input v-model="cari" class="isian pl-10" placeholder="Cari judul berkas" aria-label="Cari berkas" /></div>

    <p v-if="bp.memuat && !bp.daftar.length" class="py-8 text-center text-teks3">Memuat berkas…</p>
    <ul v-else class="space-y-2.5">
      <li v-for="d in tampil" :key="d.id">
        <router-link :to="`/berkas/${d.id}`" :class="['kartu flex items-start gap-3 p-4 hover:bg-permukaan2', 'w-' + KAT[d.kategori].w]">
          <span class="chip-ikon h-11 w-11 shrink-0"><component :is="KAT[d.kategori].i" :size="24" weight="duotone" /></span>
          <span class="min-w-0 flex-1">
            <span class="flex flex-wrap gap-1.5"><span class="lencana">{{ KAT[d.kategori].n }}</span><span v-if="d.saya_penerima && !d.dibuka_pertama" class="lencana w-notifikasi">Baru</span></span>
            <span :class="['mt-1 block leading-snug', d.saya_penerima && !d.dibuka_pertama ? 'font-extrabold' : 'font-bold']">{{ d.judul }}</span>
            <span class="block text-xs text-teks3">{{ formatRelatif(d.created_at) }} · {{ d.nama_berkas || 'Tautan' }}{{ d.ukuran ? ' · ' + ukuran(d.ukuran) : '' }}</span>
            <span v-if="tab === 'kelola'" class="block text-xs font-semibold text-teks2">{{ d.sudah_buka || 0 }}/{{ d.penerima || 0 }} sudah membuka · {{ d.ringkasan_sasaran }}</span>
          </span>
        </router-link>
      </li>
    </ul>
    <div v-if="!bp.memuat && !tampil.length" class="flex flex-col items-center py-12 text-center">
      <span class="chip-ikon h-16 w-16 rounded-2xl"><PhFolderOpen :size="34" weight="duotone" /></span>
      <p class="mt-3 font-bold">Belum ada berkas</p><p class="mt-1 text-sm text-teks3">Info, formulir, surat, dan SK untuk Anda akan muncul di sini.</p>
    </div>
    <TombolAksi v-if="kelola" label="Kirim" :ikon="PhPlus" warna="berkas" @klik="bukaForm" />

    <LembarBawah :model-value="!!terpilih && !form && !pembuka" @update:model-value="(v) => !v && router.replace('/berkas')" judul="Rincian berkas">
      <div v-if="terpilih" :class="['pb-2', 'w-' + KAT[terpilih.kategori].w]">
        <span class="lencana">{{ KAT[terpilih.kategori].n }}</span>
        <h3 class="mt-2 text-xl font-extrabold leading-snug">{{ terpilih.judul }}</h3>
        <p class="mt-1 text-sm text-teks3">Dikirim {{ formatPanjang(terpilih.created_at) }} oleh {{ terpilih.pembuat || 'Pengelola' }}<template v-if="terpilih.berlaku_sampai"> · berlaku sampai {{ formatPanjang(terpilih.berlaku_sampai) }}</template></p>
        <p v-if="terpilih.keterangan" class="mt-3 whitespace-pre-line text-teks">{{ terpilih.keterangan }}</p>
        <p v-if="terpilih.nama_berkas" class="mt-3 flex items-center gap-2 rounded-xl bg-permukaan2 p-3 text-sm"><PhPaperclip :size="18" /> {{ terpilih.nama_berkas }} · {{ ukuran(terpilih.ukuran) }}</p>
        <p v-if="kelola" class="mt-3 text-sm text-teks2">Sasaran: {{ terpilih.ringkasan_sasaran }}<template v-if="terpilih.penerima != null"> · {{ terpilih.sudah_buka || 0 }} dari {{ terpilih.penerima }} sudah membuka</template></p>
        <div class="mt-4 flex flex-wrap gap-2">
          <button v-if="terpilih.berkas_id" class="tombol-utama" :disabled="membuka" @click="buka(terpilih)"><PhDownloadSimple :size="20" weight="duotone" /> {{ membuka ? 'Mengambil berkas…' : 'Buka berkas' }}</button>
          <a v-if="terpilih.tautan_luar" :href="terpilih.tautan_luar" target="_blank" rel="noopener" :class="terpilih.berkas_id ? 'tombol-garis' : 'tombol-utama'" @click="bp.catatBuka(terpilih.id)"><PhArrowSquareOut :size="20" weight="duotone" /> Buka tautan</a>
          <template v-if="kelola">
            <button class="tombol-garis" @click="lihatPembuka(terpilih)"><PhUsers :size="20" weight="duotone" /> Pembukaan</button>
            <button class="tombol-garis w-beranda" style="color: var(--c)" @click="hapus(terpilih)"><PhTrash :size="20" weight="duotone" /> Hapus</button>
          </template>
        </div>
        <p class="mt-3 text-xs text-teks3">Berkas dibuka lewat tautan sementara yang hanya berlaku untuk akun Anda.</p>
      </div>
    </LembarBawah>

    <LembarBawah :model-value="!!form" @update:model-value="(v) => !v && (form = null)" judul="Kirim berkas pegawai">
      <form v-if="form" class="space-y-3 pb-2" @submit.prevent="simpan">
        <div><label class="label-isian" for="bp-judul">Judul</label><input id="bp-judul" v-model="form.judul" class="isian" maxlength="150" placeholder="Contoh: SK Penugasan Musyrif TA 2026/2027" /></div>
        <div class="grid gap-3 sm:grid-cols-2">
          <div><label class="label-isian" for="bp-kat">Kategori</label><select id="bp-kat" v-model="form.kategori" class="isian"><option v-for="(v, k) in KAT" :key="k" :value="k">{{ v.n }}</option></select></div>
          <InputTanggal v-model="form.berlaku_sampai" label="Berlaku sampai (opsional)" />
        </div>
        <div><label class="label-isian" for="bp-ket">Keterangan (opsional)</label><textarea id="bp-ket" v-model="form.keterangan" class="isian min-h-[4.5rem] py-2" /></div>
        <div>
          <p class="label-isian">Berkas (PDF atau foto, maks. 5 MB)</p>
          <div v-if="berkas" class="flex items-center gap-3 rounded-xl border border-garis p-3"><PhPaperclip :size="22" class="text-teks2" />
            <span class="min-w-0 flex-1 truncate text-sm font-semibold">{{ berkas.name }} · {{ ukuran(berkas.size) }}</span>
            <button type="button" class="tombol-ikon" aria-label="Hapus berkas" @click="berkas = null"><PhX :size="20" /></button></div>
          <label v-else class="tombol-garis w-full cursor-pointer justify-center"><PhPaperclip :size="20" weight="duotone" /> Pilih berkas<input type="file" accept="application/pdf,image/*" class="sr-only" @change="pilihBerkas" /></label>
        </div>
        <div><label class="label-isian" for="bp-tautan">atau tautan (Google Form, Drive, dan sebagainya)</label><input id="bp-tautan" v-model="form.tautan_luar" class="isian" inputmode="url" placeholder="https://" /></div>
        <div><p class="label-isian">Sasaran</p><PilihSasaran v-model="form.sasaran" :hitung="pg.hitungSasaran" @ringkasan="ringkas = $event" /></div>
        <button class="tombol-utama w-full" :disabled="simpanan">{{ simpanan ? 'Mengunggah dan mengirim…' : 'Kirim berkas' }}</button>
      </form>
    </LembarBawah>

    <LembarBawah :model-value="!!pembuka" @update:model-value="(v) => !v && (pembuka = null)" judul="Pembukaan berkas">
      <div v-if="pembuka" class="pb-2">
        <div class="mb-2 flex items-center gap-2"><p class="min-w-0 flex-1 truncate text-sm text-teks2">{{ pembuka.d.judul }}</p>
          <button class="tombol-teks text-sm" @click="eksporPembuka"><PhFileXls :size="18" weight="duotone" /> Excel</button></div>
        <ul class="divide-y divide-garis">
          <li v-for="r in pembuka.daftar" :key="r.employee_id" class="flex items-center gap-3 py-2.5">
            <div class="min-w-0 flex-1"><p class="font-semibold">{{ r.nama }}</p><p class="text-xs text-teks3">{{ r.unit || '–' }}</p></div>
            <span :class="['lencana', r.dibuka_pertama ? 'w-presensi' : 'w-hakakses']">{{ r.dibuka_pertama ? `Dibuka ${formatWaktu(r.dibuka_pertama)}` : 'Belum dibuka' }}</span>
          </li>
        </ul>
      </div>
    </LembarBawah>
  </div>
</template>
