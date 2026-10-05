<!-- SIMKA PRO | src/pages/berkas/Berkas.vue | v1.2 | Fase 5 – Perbaikan tampilan tab seragam | 05/10/2026 -->
<script setup>
// Berkas Saya: berkas untuk pegawai dengan kategori yang dapat dibuat sendiri. Berkas tersimpan di Google Drive pondok
// dan dibuka lewat tautan sementara (tidak publik); setiap pembukaan tercatat. Tanpa masa berlaku: berkas tetap ada
// sampai dihapus. Admin ber-izin kelola_berkas dan superadmin: kirim, ubah (ganti berkas, tambah penerima, beri tahu
// ulang), hapus, lihat pembukaan, konfirmasi WA ke penerima, dan kelola kategori.
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { PhFolderOpen, PhPlus, PhMagnifyingGlass, PhDownloadSimple, PhArrowSquareOut, PhUsers, PhTrash, PhPaperclip, PhX, PhTray, PhListChecks, PhPencilSimple, PhWhatsappLogo, PhTag, PhFloppyDisk } from '@phosphor-icons/vue'
import { useBerkasPegawai } from '@/stores/berkasPegawai'
import { usePengumuman } from '@/stores/pengumuman'
import { useUI } from '@/stores/ui'
import { MODE_DEMO } from '@/lib/supabase'
import { ambilBerkasUrl, unggahKeDrive, kompresGambar, namaRapi } from '@/lib/penyimpanan'
import { formatPanjang, formatRelatif, formatWaktu, hariIniISO } from '@/lib/tanggal'
import { pesanWA, halamanAplikasi } from '@/lib/wa'
import LembarBawah from '@/components/LembarBawah.vue'
import BilahTab from '@/components/BilahTab.vue'
import TombolAksi from '@/components/TombolAksi.vue'
import PilihSasaran from '@/components/PilihSasaran.vue'
import IkonDinamis, { IKON_KATEGORI } from '@/components/IkonDinamis.vue'
import DaftarKirimWA from '@/components/DaftarKirimWA.vue'

const props = defineProps({ id: String })
const router = useRouter(); const bp = useBerkasPegawai(); const pg = usePengumuman(); const ui = useUI()
const kelola = computed(() => bp.bolehKelola())
const tab = ref('saya'); const kat = ref(''); const cari = ref('')
const form = ref(null); const berkas = ref(null); const ringkas = ref('Semua pegawai'); const ringkasTambah = ref(''); const simpanan = ref(false)
const pembuka = ref(null); const membuka = ref(false); const formKat = ref(null)
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

// ---------- Kirim / ubah ----------
function bukaForm() { form.value = { judul: '', kategori: bp.kategoriAktif[0]?.kode || 'info', keterangan: '', tautan_luar: '', sasaran: { jenis: 'semua' } }; berkas.value = null }
function ubah(d) { form.value = { id: d.id, judul: d.judul, kategori: d.kategori, keterangan: d.keterangan || '', tautan_luar: d.tautan_luar || '', nama_berkas: d.nama_berkas, tambah: false, sasaran_tambah: { jenis: 'pilihan' }, beri_tahu: false }; berkas.value = null }
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
  if (!berkas.value && !f.nama_berkas && !/^https:\/\//.test(f.tautan_luar.trim())) return ui.toast('Unggah berkas, atau isi tautan yang diawali https://', 'galat')
  if (!f.id && !(await ui.konfirmasi({ judul: 'Kirim berkas?', pesan: `Sasaran: ${ringkas.value}. Setiap penerima mendapat notifikasi; setelah ini Anda dapat mengonfirmasi lewat WA.`, ya: 'Kirim' }))) return
  simpanan.value = true
  try {
    let berkas_id = null
    if (berkas.value && !MODE_DEMO) {
      const blob = berkas.value.type === 'application/pdf' ? berkas.value : await kompresGambar(berkas.value, { maks: 2000, kualitas: 0.8 })
      const t = hariIniISO()
      berkas_id = await unggahKeDrive(blob, { nama: namaRapi(f.kategori.toUpperCase(), f.judul.slice(0, 40), t) + (blob.type === 'application/pdf' ? '.pdf' : '.jpg'),
        kategori: 'berkas_pegawai', folder: `SIMKA PRO/Berkas Pegawai/${t.slice(0, 4)}` })
    }
    const isi = { id: f.id, judul: f.judul, kategori: f.kategori, keterangan: f.keterangan, tautan_luar: f.tautan_luar, berkas_id, beri_tahu: f.beri_tahu,
      nama_berkas: berkas.value?.name || f.nama_berkas, mime: berkas.value?.type, ringkasan: ringkas.value }
    if (f.id && f.tambah) isi.sasaran_tambah = f.sasaran_tambah
    if (!f.id) isi.sasaran = f.sasaran
    const id = await bp.simpan(isi)
    form.value = null
    ui.toast(f.id ? 'Perubahan berkas disimpan.' : 'Berkas terkirim. Lanjutkan konfirmasi lewat WA bila perlu.', 'info')
    const tujuan = id || f.id
    if (tujuan) { await router.replace(`/berkas/${tujuan}`); if (!f.id || f.tambah) lihatPembuka(bp.daftar.find((d) => d.id === tujuan) || { id: tujuan, judul: f.judul, kategori: f.kategori }) }
  } catch (e) { ui.toast(e.message, 'galat') } finally { simpanan.value = false }
}
async function hapus(d) {
  if (!(await ui.konfirmasi({ judul: 'Hapus berkas?', pesan: `"${d.judul}" akan hilang dari semua penerima dan berkasnya dihapus dari Drive.`, ya: 'Hapus', bahaya: true }))) return
  try { await bp.hapus(d.id); router.replace('/berkas'); ui.toast('Berkas dihapus.', 'info') } catch (e) { ui.toast(e.message, 'galat') }
}

// ---------- Pembukaan + WA ----------
async function lihatPembuka(d) { try { pembuka.value = { d, daftar: await bp.pembuka(d.id) } } catch (e) { ui.toast(e.message, 'galat') } }
const penerimaWA = computed(() => (pembuka.value?.daftar || []).map((r) => ({ ...r, keterangan: r.dibuka_pertama ? `dibuka ${formatWaktu(r.dibuka_pertama)}` : 'belum dibuka' })))
const pesanBerkas = (p) => pesanWA('berkas_baru', { nama: p.nama, kategori: bp.kat(pembuka.value.d.kategori).nama, judul: pembuka.value.d.judul, tautan: halamanAplikasi(`/berkas/${pembuka.value.d.id}`), unit: p.unit })

// ---------- Kategori ----------
const WARNA = ['pengumuman', 'shift', 'pegawai', 'beranda', 'tahfizh', 'santri', 'presensi', 'pengajuan', 'klinik', 'berkas', 'laporan', 'hakakses']
function bukaKategori() { formKat.value = { daftar: bp.kategori.map((k) => ({ ...k })), baru: null } }
async function simpanKat(k, baru) {
  if (k.nama.trim().length < 2) return ui.toast('Nama kategori minimal 2 karakter.', 'galat')
  if (baru) k.kode = k.nama.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '').slice(0, 30)
  try { await bp.simpanKategori(k, baru); ui.toast('Kategori disimpan.', 'info'); bukaKategori() } catch (e) { ui.toast(e.message, 'galat') }
}
</script>
<template>
  <div class="w-berkas mx-auto max-w-3xl">
    <div class="mb-3 flex flex-wrap items-center gap-2">
      <BilahTab v-if="kelola" :tepi="false" v-model="tab" label="Tampilan berkas" :tab="[{ k: 'saya', n: 'Berkas saya', ikon: PhTray, w: 'berkas', lencana: baru || null }, { k: 'kelola', n: 'Kelola', ikon: PhListChecks, w: 'hakakses' }]" />
      <button v-if="kelola" class="tombol-garis ml-auto min-h-[40px] text-sm" @click="bukaKategori"><PhTag :size="18" weight="duotone" /> Kategori</button>
      <button v-if="kelola" class="tombol-utama hidden lg:inline-flex" @click="bukaForm"><PhPlus :size="20" weight="bold" /> Kirim berkas</button>
    </div>
    <div class="mb-3 flex gap-1.5 overflow-x-auto pb-1">
      <button @click="kat = ''" :class="['min-h-[40px] shrink-0 rounded-full border px-3.5 text-sm font-semibold', kat === '' ? 'border-transparent bg-[#C7332F] text-white' : 'border-garis bg-permukaan text-teks2']">Semua</button>
      <button v-for="k in bp.kategoriAktif" :key="k.kode" @click="kat = k.kode" :class="['min-h-[40px] shrink-0 rounded-full border px-3.5 text-sm font-semibold', kat === k.kode ? 'border-transparent bg-[#C7332F] text-white' : 'border-garis bg-permukaan text-teks2']">{{ k.nama }}</button>
    </div>
    <div class="relative mb-3"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-teks3" />
      <input v-model="cari" class="isian pl-10" placeholder="Cari judul berkas" aria-label="Cari berkas" /></div>

    <p v-if="bp.memuat && !bp.daftar.length" class="py-8 text-center text-teks3">Memuat berkas…</p>
    <ul v-else class="space-y-2.5">
      <li v-for="d in tampil" :key="d.id">
        <router-link :to="`/berkas/${d.id}`" :class="['kartu flex items-start gap-3 p-4 hover:bg-permukaan2', 'w-' + bp.kat(d.kategori).warna]">
          <span class="chip-ikon h-11 w-11 shrink-0"><IkonDinamis :nama="bp.kat(d.kategori).ikon" :size="24" /></span>
          <span class="min-w-0 flex-1">
            <span class="flex flex-wrap gap-1.5"><span class="lencana">{{ bp.kat(d.kategori).nama }}</span><span v-if="d.saya_penerima && !d.dibuka_pertama" class="lencana w-notifikasi">Baru</span></span>
            <span :class="['mt-1 block leading-snug', d.saya_penerima && !d.dibuka_pertama ? 'font-extrabold' : 'font-bold']">{{ d.judul }}</span>
            <span class="block text-xs text-teks3">{{ formatRelatif(d.created_at) }} · {{ d.nama_berkas || 'Tautan' }}{{ d.ukuran ? ' · ' + ukuran(d.ukuran) : '' }}</span>
            <span v-if="tab === 'kelola'" class="block text-xs font-semibold text-teks2">{{ d.sudah_buka || 0 }}/{{ d.penerima || 0 }} sudah membuka · {{ d.ringkasan_sasaran }}</span>
          </span>
        </router-link>
      </li>
    </ul>
    <div v-if="!bp.memuat && !tampil.length" class="flex flex-col items-center py-12 text-center">
      <span class="chip-ikon h-16 w-16 rounded-2xl"><PhFolderOpen :size="34" weight="duotone" /></span>
      <p class="mt-3 font-bold">Belum ada berkas</p><p class="mt-1 text-sm text-teks3">Berkas yang ditujukan kepada Anda akan muncul di sini.</p>
    </div>
    <TombolAksi v-if="kelola" label="Kirim" :ikon="PhPlus" warna="berkas" @klik="bukaForm" />

    <!-- Rincian -->
    <LembarBawah :model-value="!!terpilih && !form && !pembuka" @update:model-value="(v) => !v && router.replace('/berkas')" judul="Rincian berkas">
      <div v-if="terpilih" :class="['pb-2', 'w-' + bp.kat(terpilih.kategori).warna]">
        <span class="lencana">{{ bp.kat(terpilih.kategori).nama }}</span>
        <h3 class="mt-2 text-xl font-extrabold leading-snug">{{ terpilih.judul }}</h3>
        <p class="mt-1 text-sm text-teks3">Dikirim {{ formatPanjang(terpilih.created_at) }} oleh {{ terpilih.pembuat || 'Pengelola' }}</p>
        <p v-if="terpilih.keterangan" class="mt-3 whitespace-pre-line text-teks">{{ terpilih.keterangan }}</p>
        <p v-if="terpilih.nama_berkas" class="mt-3 flex items-center gap-2 rounded-xl bg-permukaan2 p-3 text-sm"><PhPaperclip :size="18" /> {{ terpilih.nama_berkas }}{{ terpilih.ukuran ? ' · ' + ukuran(terpilih.ukuran) : '' }}</p>
        <p v-if="kelola" class="mt-3 text-sm text-teks2">Sasaran: {{ terpilih.ringkasan_sasaran }}<template v-if="terpilih.penerima != null"> · {{ terpilih.sudah_buka || 0 }} dari {{ terpilih.penerima }} sudah membuka</template></p>
        <div class="mt-4 flex flex-wrap gap-2">
          <button v-if="terpilih.berkas_id" class="tombol-utama" :disabled="membuka" @click="buka(terpilih)"><PhDownloadSimple :size="20" weight="duotone" /> {{ membuka ? 'Mengambil berkas…' : 'Buka berkas' }}</button>
          <a v-if="terpilih.tautan_luar" :href="terpilih.tautan_luar" target="_blank" rel="noopener" :class="terpilih.berkas_id ? 'tombol-garis' : 'tombol-utama'" @click="bp.catatBuka(terpilih.id)"><PhArrowSquareOut :size="20" weight="duotone" /> Buka tautan</a>
          <template v-if="kelola">
            <button class="tombol-garis" @click="lihatPembuka(terpilih)"><PhWhatsappLogo :size="20" weight="duotone" /> Pembukaan dan WA</button>
            <button class="tombol-garis" @click="ubah(terpilih)"><PhPencilSimple :size="20" weight="duotone" /> Ubah</button>
            <button class="tombol-garis w-beranda" style="color: var(--c)" @click="hapus(terpilih)"><PhTrash :size="20" weight="duotone" /> Hapus</button>
          </template>
        </div>
        <p class="mt-3 text-xs text-teks3">Berkas dibuka lewat tautan sementara yang hanya berlaku untuk akun Anda. Berkas tetap tersedia sampai dihapus pengelola.</p>
      </div>
    </LembarBawah>

    <!-- Formulir kirim/ubah -->
    <LembarBawah :model-value="!!form" @update:model-value="(v) => !v && (form = null)" :judul="form?.id ? 'Ubah berkas' : 'Kirim berkas pegawai'">
      <form v-if="form" class="space-y-3 pb-2" @submit.prevent="simpan">
        <div><label class="label-isian" for="bp-judul">Judul</label><input id="bp-judul" v-model="form.judul" class="isian" maxlength="150" placeholder="Contoh: SK Penugasan Musyrif TA 2026/2027" /></div>
        <div><label class="label-isian" for="bp-kat">Kategori</label>
          <select id="bp-kat" v-model="form.kategori" class="isian"><option v-for="k in bp.kategoriAktif" :key="k.kode" :value="k.kode">{{ k.nama }}</option></select></div>
        <div><label class="label-isian" for="bp-ket">Keterangan (opsional)</label><textarea id="bp-ket" v-model="form.keterangan" class="isian min-h-[4.5rem] py-2" /></div>
        <div>
          <p class="label-isian">Berkas (PDF atau foto, maks. 5 MB)</p>
          <div v-if="berkas || form.nama_berkas" class="flex items-center gap-3 rounded-xl border border-garis p-3"><PhPaperclip :size="22" class="text-teks2" />
            <span class="min-w-0 flex-1 truncate text-sm font-semibold">{{ berkas ? `${berkas.name} · ${ukuran(berkas.size)}` : form.nama_berkas }}</span>
            <label class="tombol-teks cursor-pointer text-sm">Ganti<input type="file" accept="application/pdf,image/*" class="sr-only" @change="pilihBerkas" /></label>
            <button v-if="berkas" type="button" class="tombol-ikon" aria-label="Batalkan berkas" @click="berkas = null"><PhX :size="20" /></button></div>
          <label v-else class="tombol-garis w-full cursor-pointer justify-center"><PhPaperclip :size="20" weight="duotone" /> Pilih berkas<input type="file" accept="application/pdf,image/*" class="sr-only" @change="pilihBerkas" /></label>
        </div>
        <div><label class="label-isian" for="bp-tautan">atau tautan (Google Form, Drive, dan sebagainya)</label><input id="bp-tautan" v-model="form.tautan_luar" class="isian" inputmode="url" placeholder="https://" /></div>
        <div v-if="!form.id"><p class="label-isian">Sasaran</p><PilihSasaran v-model="form.sasaran" :hitung="pg.hitungSasaran" @ringkasan="ringkas = $event" /></div>
        <template v-else>
          <label class="flex min-h-[44px] items-center gap-3 font-semibold"><input v-model="form.tambah" type="checkbox" class="h-5 w-5 accent-[#2F5D50]" /> Tambah penerima</label>
          <PilihSasaran v-if="form.tambah" v-model="form.sasaran_tambah" :hitung="pg.hitungSasaran" @ringkasan="ringkasTambah = $event" />
          <label class="flex min-h-[44px] items-center gap-3 font-semibold"><input v-model="form.beri_tahu" type="checkbox" class="h-5 w-5 accent-[#2F5D50]" /> Beri tahu semua penerima bahwa berkas diperbarui</label>
        </template>
        <button class="tombol-utama w-full" :disabled="simpanan">{{ simpanan ? 'Menyimpan…' : form.id ? 'Simpan perubahan' : 'Kirim berkas' }}</button>
      </form>
    </LembarBawah>

    <!-- Pembukaan dan WA -->
    <LembarBawah :model-value="!!pembuka" @update:model-value="(v) => !v && (pembuka = null)" judul="Pembukaan dan konfirmasi WA">
      <div v-if="pembuka" class="pb-2">
        <p class="mb-3 text-sm text-teks2">{{ pembuka.d.judul }}</p>
        <DaftarKirimWA :penerima="penerimaWA" :pesan="pesanBerkas" :kunci="'berkas-' + pembuka.d.id"
          :saringan="[{ k: 'belum', n: 'Belum dibuka', f: (p) => !p.dibuka_pertama }, { k: 'semua', n: 'Semua', f: () => true }, { k: 'sudah', n: 'Sudah dibuka', f: (p) => !!p.dibuka_pertama }]" />
      </div>
    </LembarBawah>

    <!-- Kategori -->
    <LembarBawah :model-value="!!formKat" @update:model-value="(v) => !v && (formKat = null)" judul="Kategori berkas">
      <div v-if="formKat" class="space-y-2 pb-2">
        <div v-for="k in formKat.daftar" :key="k.kode" :class="['rounded-xl border border-garis p-3', 'w-' + k.warna]">
          <div class="flex items-center gap-2">
            <button type="button" class="chip-ikon h-9 w-9 shrink-0" :aria-label="`Ubah ikon dan warna ${k.nama}`" :aria-expanded="!!k._buka" @click="k._buka = !k._buka"><IkonDinamis :nama="k.ikon" :size="20" /></button>
            <input v-model="k.nama" class="isian h-10 min-h-0 flex-1 py-1" :aria-label="`Nama kategori ${k.kode}`" />
            <label class="flex items-center gap-1 text-sm"><input v-model="k.aktif" type="checkbox" class="h-5 w-5" /> Aktif</label>
            <button class="tombol-ikon" :aria-label="`Simpan kategori ${k.nama}`" @click="simpanKat(k, false)"><PhFloppyDisk :size="20" /></button>
          </div>
          <div v-if="k._buka" class="mt-2 flex flex-wrap gap-1">
            <button v-for="i in IKON_KATEGORI" :key="i" type="button" :class="['grid h-8 w-8 place-items-center rounded-lg', k.ikon === i ? 'bg-permukaan2 ring-2 ring-[var(--c)]' : '']" :aria-label="`Ikon ${i}`" @click="k.ikon = i"><IkonDinamis :nama="i" :size="18" /></button>
            <span class="mx-1 w-px bg-garis" />
            <button v-for="w in WARNA" :key="w" type="button" :class="['h-7 w-7 rounded-full', 'w-' + w, k.warna === w && 'ring-2 ring-offset-2 ring-[var(--c)]']" style="background: var(--c)" :aria-label="`Warna ${w}`" @click="k.warna = w" />
          </div>
        </div>
        <div v-if="formKat.baru" class="rounded-xl border-2 border-dashed border-garis p-3">
          <input v-model="formKat.baru.nama" class="isian" placeholder="Nama kategori baru, mis. Sertifikat" aria-label="Nama kategori baru" />
          <button class="tombol-utama mt-2 w-full" @click="simpanKat(formKat.baru, true)"><PhFloppyDisk :size="20" weight="duotone" /> Simpan kategori baru</button>
        </div>
        <button v-else class="tombol-garis w-full" @click="formKat.baru = { nama: '', ikon: 'File', warna: 'hakakses', urutan: formKat.daftar.length + 1, aktif: true }"><PhPlus :size="18" weight="bold" /> Kategori baru</button>
        <p class="text-xs text-teks3">Ketuk ikon kategori untuk mengubah ikon dan warnanya. Kategori nonaktif tidak dapat dipilih untuk berkas baru, tetapi berkas lama tetap tampil.</p>
      </div>
    </LembarBawah>
  </div>
</template>
