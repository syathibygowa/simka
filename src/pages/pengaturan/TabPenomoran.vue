<!-- SIMKA PRO | src/pages/pengaturan/TabPenomoran.vue | v1.0 | Fase 1 – Pengaturan | 03/10/2026 -->
<script setup>
import { ref, onMounted } from 'vue'
import { PhFloppyDisk, PhPlus, PhTrash, PhEye } from '@phosphor-icons/vue'
import { useLembaga } from '@/stores/lembaga'
import { useUI } from '@/stores/ui'
import LembarBawah from '@/components/LembarBawah.vue'

const lembaga = useLembaga(); const ui = useUI()
const galat = (e) => ui.toast(e.message, 'galat')
const TOKEN = [
  ['{DK}', 'D (Dakhily, ke dalam) atau K (Khariji, ke luar)'], ['{URUT3}', 'Nomor urut 3 digit: 001'], ['{URUT}', 'Nomor urut tanpa nol: 1'],
  ['{PERIHAL}', 'Kode perihal: QR, AM, DW, …'], ['{UNIT}', 'Kode unit dari kop surat'], ['{BLN_H_ROMAWI}', 'Bulan Hijriah romawi'],
  ['{THN_H}', 'Tahun Hijriah'], ['{BLN_ROMAWI}', 'Bulan Masehi romawi'], ['{BLN}', 'Bulan Masehi 2 digit'], ['{THN}', 'Tahun Masehi'],
]
const RESET = { tahun_hijriah: 'Setiap tahun Hijriah', tahun_masehi: 'Setiap tahun Masehi', bulan_masehi: 'Setiap bulan', tidak: 'Tidak pernah' }

const draf = ref({}); const contoh = ref({})
const opsi = ref({ dk: 'D', perihal: 'NZ', kop: 'pondok' })
onMounted(() => { lembaga.doc_number_formats.forEach((f) => { draf.value[f.kode] = { ...f } }); perbaruiContoh() })
async function perbaruiContoh() {
  for (const f of lembaga.doc_number_formats) {
    try { contoh.value[f.kode] = await lembaga.pratinjauNomor(f.kode, opsi.value) } catch { contoh.value[f.kode] = '' }
  }
}
async function simpanFormat(kode) {
  const d = draf.value[kode]
  if (!d.pola?.includes('{URUT')) return ui.toast('Pola wajib memuat {URUT3} atau {URUT}.', 'galat')
  try {
    await lembaga.simpanBaris('doc_number_formats', { kode, pola: d.pola.trim(), reset: d.reset, aktif: d.aktif }, { pk: 'kode' })
    contoh.value[kode] = await lembaga.pratinjauNomor(kode, opsi.value)
    ui.toast(`Format ${d.nama} disimpan.`)
  } catch (e) { galat(e) }
}

// ---------- Kode perihal ----------
const lembar = ref(false); const fp = ref({})
function bukaPerihal() { fp.value = { kode: '', arti: '', keterangan: '', urutan: lembaga.letter_subject_codes.length + 1 }; lembar.value = true }
async function simpanPerihal() {
  const p = fp.value; p.kode = (p.kode || '').trim().toUpperCase()
  if (!/^[A-Z]{2,4}$/.test(p.kode)) return ui.toast('Kode perihal 2–4 huruf kapital, contoh: AM.', 'galat')
  if (!p.arti?.trim()) return ui.toast('Arti kode wajib diisi.', 'galat')
  try { await lembaga.simpanBaris('letter_subject_codes', p, { pk: 'kode', baru: true }); lembar.value = false; ui.toast(`Kode ${p.kode} ditambahkan.`) } catch (e) { galat(e) }
}
async function hapusPerihal(p) {
  if (!(await ui.konfirmasi({ judul: `Hapus kode ${p.kode}?`, pesan: `${p.arti}: ${p.keterangan || ''}`, ya: 'Hapus', bahaya: true }))) return
  try { await lembaga.hapusBaris('letter_subject_codes', p.kode, 'kode'); ui.toast('Kode perihal dihapus.') } catch (e) { galat(e) }
}
</script>
<template>
  <div class="space-y-5">
    <section class="kartu p-5">
      <h3 class="judul-bagian">Format nomor dokumen</h3>
      <p class="mb-3 text-sm text-teks3">Nomor diambil otomatis saat dokumen diterbitkan dan tidak pernah ganda. Contoh di bawah tidak menaikkan nomor urut.</p>
      <div class="mb-4 grid grid-cols-3 gap-2">
        <label class="text-xs font-semibold text-teks3">Jenis surat
          <select v-model="opsi.dk" class="isian mt-1 text-sm font-normal text-teks" @change="perbaruiContoh"><option value="D">D – Dakhily</option><option value="K">K – Khariji</option></select></label>
        <label class="text-xs font-semibold text-teks3">Perihal
          <select v-model="opsi.perihal" class="isian mt-1 text-sm font-normal text-teks" @change="perbaruiContoh"><option v-for="p in lembaga.letter_subject_codes" :key="p.kode" :value="p.kode">{{ p.kode }}</option></select></label>
        <label class="text-xs font-semibold text-teks3">Kop
          <select v-model="opsi.kop" class="isian mt-1 text-sm font-normal text-teks" @change="perbaruiContoh"><option v-for="k in lembaga.letterheads" :key="k.kode" :value="k.kode">{{ k.nama.replace('Kop ', '') }}</option></select></label>
      </div>
      <div class="space-y-3">
        <div v-for="f in lembaga.doc_number_formats" :key="f.kode" class="rounded-xl border border-garis p-3">
          <template v-if="draf[f.kode]">
            <div class="mb-2 flex flex-wrap items-center gap-2">
              <p class="flex-1 font-semibold">{{ f.nama }}</p>
              <label class="flex items-center gap-2 text-sm font-semibold text-teks2"><input v-model="draf[f.kode].aktif" type="checkbox" class="h-4 w-4 accent-[#C7332F]" /> Aktif</label>
            </div>
            <div class="grid gap-2 sm:grid-cols-[1fr_200px_auto]">
              <input v-model="draf[f.kode].pola" class="isian font-mono text-sm" :aria-label="`Pola nomor ${f.nama}`" />
              <select v-model="draf[f.kode].reset" class="isian text-sm" :aria-label="`Nomor urut kembali ke 1 untuk ${f.nama}`"><option v-for="(n, k) in RESET" :key="k" :value="k">Urut ulang: {{ n }}</option></select>
              <button class="tombol-garis px-4" @click="simpanFormat(f.kode)"><PhFloppyDisk :size="18" weight="duotone" /> Simpan</button>
            </div>
            <p class="mt-2 text-sm"><PhEye :size="16" weight="duotone" class="mr-1 inline text-teks3" /><span class="text-teks3">Nomor berikutnya: </span><span class="font-bold tabular-nums">{{ contoh[f.kode] || '–' }}</span></p>
          </template>
        </div>
      </div>
      <details class="mt-4 rounded-xl bg-permukaan2 p-3 text-sm">
        <summary class="cursor-pointer font-semibold">Daftar penanda pola</summary>
        <dl class="mt-2 grid gap-x-4 gap-y-1 sm:grid-cols-[150px_1fr]">
          <template v-for="t in TOKEN" :key="t[0]"><dt class="font-mono font-semibold">{{ t[0] }}</dt><dd class="text-teks2">{{ t[1] }}</dd></template>
        </dl>
      </details>
    </section>

    <section class="kartu p-5">
      <div class="mb-3 flex flex-wrap items-center justify-between gap-2">
        <div><h3 class="judul-bagian">Kode perihal surat</h3><p class="text-sm text-teks3">Pedoman persuratan Wahdah Islamiyah.</p></div>
        <button class="tombol-garis" @click="bukaPerihal"><PhPlus :size="18" weight="bold" /> Tambah kode</button>
      </div>
      <ul class="divide-y divide-garis">
        <li v-for="p in lembaga.letter_subject_codes" :key="p.kode" class="flex items-center gap-3 py-2.5">
          <span class="lencana w-santri w-14 justify-center font-mono">{{ p.kode }}</span>
          <div class="min-w-0 flex-1"><p class="font-semibold">{{ p.arti }}</p><p class="text-sm text-teks3">{{ p.keterangan }}</p></div>
          <button class="tombol-ikon" @click="hapusPerihal(p)" :aria-label="`Hapus kode ${p.kode}`"><PhTrash :size="20" /></button>
        </li>
      </ul>
    </section>

    <LembarBawah v-model="lembar" judul="Tambah kode perihal">
      <div class="space-y-4 pb-2">
        <div><label class="label-isian" for="ph-kode">Kode (2–4 huruf)</label><input id="ph-kode" v-model="fp.kode" class="isian uppercase" maxlength="4" /></div>
        <div><label class="label-isian" for="ph-arti">Arti</label><input id="ph-arti" v-model="fp.arti" class="isian" /></div>
        <div><label class="label-isian" for="ph-ket">Keterangan</label><input id="ph-ket" v-model="fp.keterangan" class="isian" /></div>
        <button class="tombol-utama w-full" @click="simpanPerihal"><PhFloppyDisk :size="20" weight="duotone" /> Simpan</button>
      </div>
    </LembarBawah>
  </div>
</template>
