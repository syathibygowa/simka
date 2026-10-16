<!-- SIMKA PRO | src/pages/persuratan/LembarCatatSurat.vue | v1.2 | Perbaikan 13.8.0: ringkasan surat masuk dengan gaya teks dan daftar otomatis | 16/10/2026 -->
<script setup>
// Catat (atau ubah) surat masuk oleh Tata Usaha: data surat, sifat, pindaian (foto/PDF, beberapa berkas), dan pimpinan penerima.
// Nomor agenda dibuat otomatis oleh server saat disimpan. Surat dapat langsung diarsipkan tanpa disposisi (mis. brosur).
import { ref, computed, watch } from 'vue'
import { PhFloppyDisk, PhFilePdf, PhImage, PhX, PhPaperclip, PhArchive, PhInfo } from '@phosphor-icons/vue'
import { usePersuratan } from '@/stores/persuratan'
import { useUI } from '@/stores/ui'
import { SIFAT_SURAT, CARA_TERIMA } from '@/lib/persuratan'
import { hariIniISO } from '@/lib/tanggal'
import { MODE_DEMO } from '@/lib/supabase'
import { unggahKeDrive, kompresGambar, namaRapi } from '@/lib/penyimpanan'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import IsianTeksKaya from '@/components/IsianTeksKaya.vue'

const buka = defineModel({ type: Boolean, default: false })
const props = defineProps({ surat: { type: Object, default: null } })
const emit = defineEmits(['selesai'])
const ps = usePersuratan(); const ui = useUI()
const isi = ref({}); const berkas = ref([]); const proses = ref(false); const langkah = ref('')
const MAKS_BERKAS = 6
watch(buka, async (v) => {
  if (!v) return
  const s = props.surat
  isi.value = s ? { id: s.id, tanggal_terima: s.tanggal_terima, cara: s.cara, nomor_surat: s.nomor_surat || '', tanggal_surat: s.tanggal_surat || hariIniISO(),
    pengirim: s.pengirim, alamat_pengirim: s.alamat_pengirim || '', perihal: s.perihal, ringkasan: s.ringkasan || '', lampiran: s.lampiran || '', sifat: s.sifat,
    tujuan: s.status === 'diarsipkan' ? 'arsip' : s.tujuan_id || '', catatan: s.catatan || '' }
    : { tanggal_terima: hariIniISO(), cara: 'langsung', nomor_surat: '', tanggal_surat: hariIniISO(), pengirim: '', alamat_pengirim: '', perihal: '', ringkasan: '',
        lampiran: '', sifat: 'biasa', tujuan: '', catatan: '' }
  berkas.value = []
  try { await ps.muatPimpinan(); if (!s && !isi.value.tujuan) isi.value.tujuan = ps.pimpinan.find((p) => p.bawaan)?.id || '' } catch (e) { ui.toast(e.message, 'galat') }
})
function pilihBerkas(e) {
  const fs = [...(e.target.files || [])]; e.target.value = ''
  for (const f of fs) {
    if (berkas.value.length >= MAKS_BERKAS) { ui.toast(`Paling banyak ${MAKS_BERKAS} berkas pindaian.`, 'galat'); break }
    if (!/^image\//.test(f.type) && f.type !== 'application/pdf') { ui.toast(`${f.name}: pilih foto atau PDF.`, 'galat'); continue }
    if (f.type === 'application/pdf' && f.size > 5 * 1024 * 1024) { ui.toast(`${f.name}: ukuran PDF paling besar 5 MB.`, 'galat'); continue }
    berkas.value.push({ f, nama: f.name, pdf: f.type === 'application/pdf', url: f.type === 'application/pdf' ? '' : URL.createObjectURL(f) })
  }
}
const tujuanPilih = computed(() => ps.pimpinan.find((p) => p.id === isi.value.tujuan))

async function simpan() {
  const x = isi.value
  if (x.pengirim.trim().length < 3) return ui.toast('Isi asal/pengirim surat.', 'galat')
  if (x.perihal.trim().length < 3) return ui.toast('Isi perihal surat.', 'galat')
  if (!x.tujuan) return ui.toast('Pilih pimpinan penerima, atau "Langsung diarsipkan".', 'galat')
  if (x.tanggal_surat && x.tanggal_surat > x.tanggal_terima) return ui.toast('Tanggal surat tidak boleh sesudah tanggal terima.', 'galat')
  proses.value = true
  try {
    const ids = []
    if (berkas.value.length && !MODE_DEMO) {
      const t = x.tanggal_terima
      for (const [i, b] of berkas.value.entries()) {
        langkah.value = `Mengunggah pindaian ${i + 1} dari ${berkas.value.length}…`
        const blob = b.pdf ? b.f : await kompresGambar(b.f, { maks: 1800, kualitas: 0.72 })
        ids.push(await unggahKeDrive(blob, { nama: namaRapi('SuratMasuk', t, x.pengirim.slice(0, 24), i + 1) + (b.pdf ? '.pdf' : '.jpg'), kategori: 'surat_masuk',
          folder: `SIMKA PRO/Persuratan/Surat Masuk/${t.slice(0, 4)}/${t.slice(5, 7)}` }))
      }
    }
    langkah.value = 'Menyimpan…'
    const muatan = { tanggal_terima: x.tanggal_terima, cara: x.cara, nomor_surat: x.nomor_surat.trim(), tanggal_surat: x.tanggal_surat || null, pengirim: x.pengirim.trim(),
      alamat_pengirim: x.alamat_pengirim.trim(), perihal: x.perihal.trim(), ringkasan: x.ringkasan.trim(), lampiran: x.lampiran.trim(), sifat: x.sifat,
      tujuan_id: x.tujuan === 'arsip' ? null : x.tujuan, arsip: x.tujuan === 'arsip', catatan: x.catatan.trim() }
    if (berkas.value.length) muatan.berkas_ids = ids
    let id = x.id
    if (x.id) { await ps.ubah({ ...muatan, id: x.id }); ui.toast('Perubahan surat tersimpan.') }
    else {
      const r = await ps.catat(muatan); id = r.id
      ui.toast(`Surat tercatat dengan nomor agenda ${r.nomor_agenda}.` + (muatan.arsip ? '' : ` ${tujuanPilih.value?.nama || 'Pimpinan'} mendapat notifikasi.`))
    }
    buka.value = false; emit('selesai', id)
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false; langkah.value = '' }
}
</script>
<template>
  <LembarBawah v-model="buka" :judul="surat ? `Ubah surat ${surat.nomor_agenda}` : 'Catat surat masuk'" lebar>
    <div class="space-y-4 pb-2">
      <p v-if="!surat" class="flex items-start gap-2 rounded-xl bg-permukaan2 px-3 py-2 text-xs text-teks2"><PhInfo :size="16" class="mt-0.5 shrink-0" />
        Nomor agenda dibuat otomatis saat disimpan (format dapat diubah di Setelan → Nomor Surat).</p>
      <div class="grid gap-3 sm:grid-cols-3">
        <InputTanggal v-model="isi.tanggal_terima" label="Tanggal terima" wajib />
        <div><label class="label-isian" for="sm-cara">Cara diterima</label>
          <select id="sm-cara" v-model="isi.cara" class="isian"><option v-for="c in CARA_TERIMA" :key="c.k" :value="c.k">{{ c.n }}</option></select></div>
        <div><label class="label-isian" for="sm-lamp">Lampiran</label><input id="sm-lamp" v-model="isi.lampiran" class="isian" placeholder="Contoh: 1 berkas" /></div>
      </div>
      <div class="grid gap-3 sm:grid-cols-2">
        <div><label class="label-isian" for="sm-no">Nomor surat</label><input id="sm-no" v-model="isi.nomor_surat" class="isian" placeholder="Sesuai yang tertulis di surat" /></div>
        <InputTanggal v-model="isi.tanggal_surat" label="Tanggal surat" />
      </div>
      <div class="grid gap-3 sm:grid-cols-2">
        <div><label class="label-isian" for="sm-dari">Asal/pengirim <span class="text-merah">*</span></label><input id="sm-dari" v-model="isi.pengirim" class="isian" placeholder="Nama instansi atau perorangan" /></div>
        <div><label class="label-isian" for="sm-alamat">Alamat pengirim</label><input id="sm-alamat" v-model="isi.alamat_pengirim" class="isian" /></div>
      </div>
      <div><label class="label-isian" for="sm-hal">Perihal <span class="text-merah">*</span></label><input id="sm-hal" v-model="isi.perihal" class="isian" /></div>
      <IsianTeksKaya id="sm-ring" v-model="isi.ringkasan" label="Ringkasan isi" tinggi="5rem" :petunjuk="false" placeholder="Pokok isi surat, mis. waktu dan tempat kegiatan" />

      <div><p class="label-isian">Sifat surat</p>
        <div class="grid grid-cols-2 gap-2 sm:grid-cols-4" role="radiogroup" aria-label="Sifat surat">
          <button v-for="(v, k) in SIFAT_SURAT" :key="k" type="button" role="radio" :aria-checked="isi.sifat === k" @click="isi.sifat = k"
            :class="['flex min-h-[48px] items-center gap-2 rounded-xl border px-3 text-sm font-semibold', 'w-' + v.w, isi.sifat === k ? 'pilih' : 'border-garis text-teks2']">
            <component :is="v.ikon" :size="20" weight="duotone" style="color: var(--c)" /> {{ v.n }}</button>
        </div>
        <p v-if="isi.sifat === 'rahasia'" class="mt-1 text-xs text-teks3">Surat rahasia hanya dibaca Tata Usaha, pimpinan penerima, dan penerima disposisinya.</p></div>

      <div><p class="label-isian">Pindaian surat <span class="font-normal text-teks3">(foto atau PDF, paling banyak {{ MAKS_BERKAS }} berkas)</span></p>
        <p v-if="surat?.jumlah_berkas && !berkas.length" class="mb-2 text-xs text-teks3"><PhPaperclip :size="13" class="inline" /> {{ surat.jumlah_berkas }} berkas tersimpan. Pilih berkas baru untuk menggantinya.</p>
        <ul v-if="berkas.length" class="mb-2 grid grid-cols-3 gap-2 sm:grid-cols-6">
          <li v-for="(b, i) in berkas" :key="i" class="relative">
            <img v-if="!b.pdf" :src="b.url" :alt="b.nama" class="h-20 w-full rounded-xl object-cover" />
            <span v-else class="grid h-20 place-items-center rounded-xl border border-garis bg-permukaan2 text-xs text-teks2"><PhFilePdf :size="28" weight="duotone" /></span>
            <button type="button" class="absolute -right-1.5 -top-1.5 grid h-7 w-7 place-items-center rounded-full bg-[#C7332F] text-white" :aria-label="`Hapus ${b.nama}`" @click="berkas.splice(i, 1)"><PhX :size="14" weight="bold" /></button>
          </li>
        </ul>
        <div class="flex flex-wrap gap-2">
          <label class="tombol-garis cursor-pointer"><PhImage :size="20" weight="duotone" /> Foto surat<input type="file" accept="image/*" capture="environment" class="sr-only" @change="pilihBerkas" /></label>
          <label class="tombol-garis cursor-pointer"><PhFilePdf :size="20" weight="duotone" /> Berkas foto/PDF<input type="file" accept="image/*,application/pdf" multiple class="sr-only" @change="pilihBerkas" /></label>
        </div></div>

      <div><p class="label-isian">Diteruskan kepada <span class="text-merah">*</span></p>
        <div class="grid gap-2 sm:grid-cols-2" role="radiogroup" aria-label="Pimpinan penerima">
          <button v-for="p in ps.pimpinan" :key="p.id" type="button" role="radio" :aria-checked="isi.tujuan === p.id" @click="isi.tujuan = p.id"
            :class="['flex min-h-[52px] items-center gap-3 rounded-xl border px-3 text-left text-sm w-tatausaha', isi.tujuan === p.id ? 'pilih' : 'border-garis']">
            <span class="min-w-0 flex-1"><b class="block truncate">{{ p.nama }}</b><span class="text-xs text-teks2">{{ p.jabatan }}</span></span></button>
          <button type="button" role="radio" :aria-checked="isi.tujuan === 'arsip'" @click="isi.tujuan = 'arsip'"
            :class="['flex min-h-[52px] items-center gap-3 rounded-xl border px-3 text-left text-sm w-hakakses', isi.tujuan === 'arsip' ? 'pilih' : 'border-garis']">
            <PhArchive :size="22" weight="duotone" style="color: var(--c)" /><span><b class="block">Langsung diarsipkan</b><span class="text-xs text-teks2">Tanpa disposisi (mis. brosur, tembusan)</span></span></button>
        </div>
        <p v-if="!ps.pimpinan.length" class="mt-1 text-xs text-teks3">Belum ada pimpinan aktif. Isi jabatan struktural Direktur/Wadir/Kepala Bidang di Data Pegawai.</p></div>
      <div v-if="isi.tujuan !== 'arsip'"><label class="label-isian" for="sm-cat">Catatan untuk pimpinan</label>
        <input id="sm-cat" v-model="isi.catatan" class="isian" placeholder="Opsional, mis. acara besok pagi" /></div>

      <button class="tombol-utama w-full" :disabled="proses" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses ? langkah || 'Menyimpan…' : surat ? 'Simpan perubahan' : isi.tujuan === 'arsip' ? 'Simpan ke arsip' : 'Simpan dan teruskan' }}</button>
    </div>
  </LembarBawah>
</template>
<style scoped>
.pilih { border-color: var(--c); border-width: 2px; background: color-mix(in srgb, var(--c) 12%, transparent); color: rgb(var(--teks)); }
</style>
