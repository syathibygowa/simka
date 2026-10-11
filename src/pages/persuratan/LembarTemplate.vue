<!-- SIMKA PRO | src/pages/persuratan/LembarTemplate.vue | v1.0 | Fase 10 – Tahap 2 Template surat dan surat keluar | 11/10/2026 -->
<script setup>
// Sunting/buat template surat: identitas (kode perihal, format nomor, D/K, kop, bentuk kepala, judul), pilihan salam/doa/tembusan,
// naskah dengan isian {kunci} (bantuan sintaks dan tombol sisip isian), daftar isian (jenis, wajib, nilai bawaan), dan
// penanda tangan bawaan (1–2). Pratinjau F4 memakai data contoh (isian kosong ditandai kuning).
import { ref, computed, watch } from 'vue'
import { PhFloppyDisk, PhEye, PhPlus, PhTrash, PhArrowUp, PhQuestion } from '@phosphor-icons/vue'
import { usePersuratan } from '@/stores/persuratan'
import { useLembaga } from '@/stores/lembaga'
import { useUI } from '@/stores/ui'
import { OPSI_SURAT, JENIS_ISIAN, KATEGORI_TEMPLATE, FORMAT_NOMOR, ISIAN_GLOBAL, BAGIAN_PEGAWAI, BAGIAN_SANTRI, nilaiAwal } from '@/lib/suratKeluar'
import { hariIniISO } from '@/lib/tanggal'
import LembarBawah from '@/components/LembarBawah.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import SuratResmi from '@/components/cetak/SuratResmi.vue'

const buka = defineModel({ type: Boolean, default: false })
const props = defineProps({ templat: { type: Object, default: null }, salin: { type: Boolean, default: false } })
const emit = defineEmits(['selesai'])
const ps = usePersuratan(); const lembaga = useLembaga(); const ui = useUI()
const f = ref({}); const proses = ref(false); const pratinjau = ref(false); const bantuan = ref(false); const naskahEl = ref(null)
const KOSONG = { kode: '', nama: '', kategori: 'umum', perihal_kode: 'NZ', format_nomor: 'surat', dk: 'D', kop_kode: 'pondok', bentuk: 'kiri', judul: '', subjudul: '',
  hal_bawaan: '', kepada_bawaan: '', opsi: { salam: true, salam_penutup: true }, isi: '', isian: [], penanda: [{ jabatan: 'Direktur', pengantar: '' }], aktif: true }
watch(buka, async (v) => {
  if (!v) return
  pratinjau.value = false; bantuan.value = false
  lembaga.muat(); ps.muatKonteks().catch(() => {})
  const x = props.templat ? JSON.parse(JSON.stringify(props.templat)) : { ...JSON.parse(JSON.stringify(KOSONG)) }
  if (props.salin) { delete x.id; x.kode = `${x.kode}_salin`.slice(0, 40); x.nama = `${x.nama} (salinan)`; x.bawaan = false }
  x.opsi = x.opsi || {}; x.isian = (x.isian || []).map((i) => ({ gaya: 'angka', wajib: false, bawaan: '', ...i })); x.penanda = x.penanda?.length ? x.penanda : [{ jabatan: 'Direktur' }]
  f.value = x
})
const kodeDariNama = () => { if (!f.value.id && !props.salin && !f.value.kode) f.value.kode = f.value.nama.toLowerCase().normalize('NFKD').replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '').slice(0, 40) }
function tambahIsian() { f.value.isian.push({ kunci: `isian_${f.value.isian.length + 1}`, label: 'Isian baru', jenis: 'teks', wajib: false, bawaan: '', gaya: 'angka' }) }
function naik(i) { if (i > 0) f.value.isian.splice(i - 1, 0, f.value.isian.splice(i, 1)[0]) }
/** Daftar isian yang dapat disisipkan ke naskah. */
const chip = computed(() => [
  ...(f.value.isian || []).flatMap((i) => i.jenis === 'pegawai' ? BAGIAN_PEGAWAI.map((b) => `${i.kunci}.${b}`) : i.jenis === 'santri' ? BAGIAN_SANTRI.map((b) => `${i.kunci}.${b}`) : [i.kunci]),
  ...ISIAN_GLOBAL.map((g) => g.k)])
function sisip(k) {
  const el = naskahEl.value; const s = `{${k}}`
  if (!el) { f.value.isi += s; return }
  const a = el.selectionStart ?? f.value.isi.length; const b = el.selectionEnd ?? a
  f.value.isi = f.value.isi.slice(0, a) + s + f.value.isi.slice(b)
  requestAnimationFrame(() => { el.focus(); el.selectionStart = el.selectionEnd = a + s.length })
}
const contoh = computed(() => ({ tampilan: { bentuk: f.value.bentuk, judul: f.value.judul, subjudul: f.value.subjudul, isi: f.value.isi, opsi: f.value.opsi, isian: f.value.isian },
  nilai: nilaiAwal(f.value.isian, hariIniISO()), perihal: f.value.hal_bawaan || f.value.nama, kepada: f.value.kepada_bawaan || 'Penerima surat', lampiran: '–',
  tembusan: ['Arsip'], narahubung: 'Nama (nomor HP)', tanggal_surat: hariIniISO(), tanggal_hijriah: ps.konteks?.hijriah_hari_ini || '',
  penanda: f.value.penanda.map((p, i) => ({ ...p, posisi: f.value.penanda.length === 1 ? 'kanan' : i ? 'kanan' : 'kiri', nama: 'Nama Penanda Tangan', niy: '…' })) }))
async function simpan() {
  const x = f.value
  if (!/^[a-z0-9_]{3,40}$/.test(x.kode)) return ui.toast('Kode template hanya huruf kecil, angka, dan garis bawah (3–40 karakter).', 'galat')
  if (x.nama.trim().length < 3) return ui.toast('Isi nama template.', 'galat')
  if (x.isi.trim().length < 10) return ui.toast('Naskah template masih kosong.', 'galat')
  const kunci = x.isian.map((i) => i.kunci)
  const salah = kunci.find((k) => !/^[a-z][a-z0-9_]{0,30}$/.test(k)); if (salah) return ui.toast(`Kunci isian "${salah}" tidak sah (huruf kecil, angka, garis bawah).`, 'galat')
  if (new Set(kunci).size !== kunci.length) return ui.toast('Ada kunci isian yang dipakai dua kali.', 'galat')
  proses.value = true
  try {
    await ps.simpanTemplat({ ...x, penanda: x.penanda.filter((p) => p.jabatan?.trim()).map((p) => ({ jabatan: p.jabatan.trim(), ...(p.pengantar ? { pengantar: p.pengantar } : {}) })),
      isian: x.isian.map((i) => { const o = { kunci: i.kunci, label: i.label, jenis: i.jenis, wajib: !!i.wajib }; if (i.bawaan) o.bawaan = i.bawaan; if (i.jenis === 'daftar') o.gaya = i.gaya || 'angka'; return o }) })
    ui.toast(`Template ${x.nama} tersimpan.`); buka.value = false; emit('selesai')
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <LembarBawah v-model="buka" :judul="f.id ? `Ubah template: ${f.nama}` : 'Template surat baru'" lebar>
    <div v-if="f.isian" class="space-y-4 pb-2">
      <section class="grid gap-3 sm:grid-cols-3">
        <div class="sm:col-span-2"><label class="label-isian" for="tp-nama">Nama template <span class="text-merah">*</span></label>
          <input id="tp-nama" v-model="f.nama" class="isian" placeholder="Mis. Surat Keterangan Lulus" @blur="kodeDariNama" /></div>
        <div><label class="label-isian" for="tp-kode">Kode <span class="text-merah">*</span></label><input id="tp-kode" v-model="f.kode" class="isian font-mono" placeholder="keterangan_lulus" /></div>
        <div><label class="label-isian" for="tp-kat">Kategori</label>
          <select id="tp-kat" v-model="f.kategori" class="isian"><option v-for="(v, k) in KATEGORI_TEMPLATE" :key="k" :value="k">{{ v.n }}</option></select></div>
        <div><label class="label-isian" for="tp-hal">Kode perihal</label>
          <select id="tp-hal" v-model="f.perihal_kode" class="isian"><option v-for="h in lembaga.letter_subject_codes" :key="h.kode" :value="h.kode">{{ h.kode }} – {{ h.arti }}</option></select></div>
        <div><label class="label-isian" for="tp-fmt">Format nomor</label>
          <select id="tp-fmt" v-model="f.format_nomor" class="isian"><option v-for="x in FORMAT_NOMOR" :key="x.k" :value="x.k">{{ x.n }}</option></select></div>
        <div><label class="label-isian" for="tp-dk">Jenis bawaan</label>
          <select id="tp-dk" v-model="f.dk" class="isian"><option value="D">D – Dakhily (internal)</option><option value="K">K – Khariji (keluar)</option></select></div>
        <div><label class="label-isian" for="tp-kop">Kop bawaan</label>
          <select id="tp-kop" v-model="f.kop_kode" class="isian"><option v-for="k in lembaga.letterheads" :key="k.kode" :value="k.kode">{{ k.nama }}</option></select></div>
        <div><label class="label-isian" for="tp-bentuk">Bentuk kepala surat</label>
          <select id="tp-bentuk" v-model="f.bentuk" class="isian"><option value="kiri">Nomor/Lampiran/Hal di kiri, tanggal di kanan</option><option value="tengah">Judul dan nomor di tengah</option></select></div>
      </section>
      <section v-if="f.bentuk === 'tengah'" class="grid gap-3 sm:grid-cols-2">
        <div><label class="label-isian" for="tp-judul">Judul surat</label><textarea id="tp-judul" v-model="f.judul" rows="2" class="isian py-2.5" placeholder="SURAT KETERANGAN" /></div>
        <div><label class="label-isian" for="tp-sub">Subjudul (di bawah nomor)</label><textarea id="tp-sub" v-model="f.subjudul" rows="2" class="isian py-2.5" placeholder="TENTANG&#10;{tentang}" /></div>
      </section>
      <section class="grid gap-3 sm:grid-cols-2">
        <div><label class="label-isian" for="tp-halb">Perihal bawaan</label><input id="tp-halb" v-model="f.hal_bawaan" class="isian" /></div>
        <div><label class="label-isian" for="tp-kpd">Kepada bawaan</label><input id="tp-kpd" v-model="f.kepada_bawaan" class="isian" /></div>
      </section>
      <section><p class="label-isian">Bagian surat</p>
        <div class="flex flex-wrap gap-x-4 gap-y-2"><label v-for="o in OPSI_SURAT" :key="o.k" class="flex min-h-[36px] items-center gap-2 text-sm">
          <input v-model="f.opsi[o.k]" type="checkbox" class="h-5 w-5" /> {{ o.n }}</label></div></section>

      <section>
        <div class="flex items-center justify-between"><label class="label-isian" for="tp-isi">Naskah surat <span class="text-merah">*</span></label>
          <button type="button" class="tombol-teks px-2 text-sm" @click="bantuan = !bantuan"><PhQuestion :size="16" /> Cara menulis</button></div>
        <div v-if="bantuan" class="mb-2 rounded-xl bg-permukaan2 p-3 text-xs leading-relaxed text-teks2">
          <p><code>{kunci}</code> isian · <code>*tebal*</code> · <code>_miring_</code> · baris kosong = paragraf baru</p>
          <p><code>Hari/tanggal : {hari_tanggal}</code> baris berjajar (beri spasi sebelum titik dua)</p>
          <p><code>1. …</code> <code>a. …</code> <code>- …</code> daftar · <code>== *MEMUTUSKAN*</code> rata tengah</p>
          <p><code>| No. | Uraian | Keterangan |</code> tabel; baris <code>|---|---|---|</code> di bawahnya menjadikan baris pertama kepala tabel</p>
          <p>Isian daftar atau daftar pegawai yang ditulis sendirian pada satu baris tampil sebagai daftar bernomor/tabel.</p>
        </div>
        <textarea id="tp-isi" ref="naskahEl" v-model="f.isi" rows="14" class="isian py-2.5 font-mono text-sm" />
        <p class="mt-1 text-xs text-teks3">Ketuk untuk menyisipkan isian:</p>
        <div class="mt-1 flex max-h-28 flex-wrap gap-1.5 overflow-y-auto">
          <button v-for="c in chip" :key="c" type="button" class="rounded-lg border border-garis px-2 py-1 font-mono text-xs hover:bg-permukaan2" @click="sisip(c)">{{ '{' + c + '}' }}</button>
        </div>
      </section>

      <section class="space-y-2 rounded-2xl border border-garis p-3">
        <div class="flex items-center justify-between"><h3 class="judul-bagian">Isian yang diisi penyusun</h3>
          <button type="button" class="tombol-teks px-2 text-sm" @click="tambahIsian"><PhPlus :size="16" /> Tambah isian</button></div>
        <div v-for="(i, n) in f.isian" :key="n" class="grid gap-2 rounded-xl bg-permukaan2 p-2.5 sm:grid-cols-[1fr_1.4fr_1.2fr_auto]">
          <input v-model="i.kunci" class="isian font-mono text-sm" :aria-label="`Kunci isian ${n + 1}`" placeholder="kunci" />
          <input v-model="i.label" class="isian" :aria-label="`Label isian ${n + 1}`" placeholder="Label" />
          <select v-model="i.jenis" class="isian" :aria-label="`Jenis isian ${n + 1}`"><option v-for="j in JENIS_ISIAN" :key="j.k" :value="j.k">{{ j.n }}</option></select>
          <div class="flex items-center gap-1">
            <button type="button" class="tombol-ikon h-9 w-9" :disabled="n === 0" :aria-label="`Naikkan isian ${n + 1}`" @click="naik(n)"><PhArrowUp :size="16" /></button>
            <button type="button" class="tombol-ikon h-9 w-9 text-merah" :aria-label="`Hapus isian ${n + 1}`" @click="f.isian.splice(n, 1)"><PhTrash :size="16" /></button></div>
          <label class="flex items-center gap-2 text-sm"><input v-model="i.wajib" type="checkbox" class="h-5 w-5" /> Wajib</label>
          <select v-if="i.jenis === 'daftar'" v-model="i.gaya" class="isian" :aria-label="`Gaya daftar ${n + 1}`"><option value="angka">1. 2. 3.</option><option value="huruf">a. b. c.</option><option value="poin">• poin</option></select>
          <input v-if="['teks', 'panjang', 'angka', 'daftar'].includes(i.jenis)" v-model="i.bawaan" class="isian sm:col-span-2" :aria-label="`Nilai bawaan isian ${n + 1}`" placeholder="Nilai bawaan (opsional)" />
        </div>
        <p v-if="!f.isian.length" class="text-sm text-teks3">Belum ada isian. Template tanpa isian tetap dapat dipakai.</p>
      </section>

      <section class="space-y-2 rounded-2xl border border-garis p-3">
        <div class="flex items-center justify-between"><h3 class="judul-bagian">Penanda tangan bawaan</h3>
          <button v-if="f.penanda.length < 2" type="button" class="tombol-teks px-2 text-sm" @click="f.penanda.push({ jabatan: '', pengantar: 'Mengetahui,' })"><PhPlus :size="16" /> Tambah</button></div>
        <div v-for="(p, n) in f.penanda" :key="n" class="grid gap-2 sm:grid-cols-[1fr_1fr_auto]">
          <input v-model="p.jabatan" class="isian" :aria-label="`Jabatan penanda tangan ${n + 1}`" placeholder="Jabatan, mis. Direktur" />
          <input v-model="p.pengantar" class="isian" :aria-label="`Kata pengantar ${n + 1}`" placeholder="Kata pengantar (opsional)" />
          <button v-if="f.penanda.length > 1" type="button" class="tombol-ikon text-merah" :aria-label="`Hapus penanda tangan ${n + 1}`" @click="f.penanda.splice(n, 1)"><PhTrash :size="18" /></button>
        </div>
        <p class="text-xs text-teks3">Dua penanda tangan tampil berdampingan: yang pertama di kiri (pimpinan), yang kedua di kanan.</p>
      </section>

      <div class="flex flex-wrap gap-2">
        <button class="tombol-garis w-rekap" @click="pratinjau = true"><PhEye :size="20" style="color: var(--c)" /> Pratinjau F4</button>
        <button class="tombol-utama flex-1" :disabled="proses" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses ? 'Menyimpan…' : 'Simpan template' }}</button>
      </div>
      <DokumenCetak :kop="f.kop_kode" :judul="`Pratinjau template ${f.nama}`" v-model:pratinjau="pratinjau" sembunyikan-judul tanpa-catatan>
        <SuratResmi :surat="contoh" :lembaga="ps.konteks || {}" />
      </DokumenCetak>
    </div>
  </LembarBawah>
</template>
