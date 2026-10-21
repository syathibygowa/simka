<!-- SIMKA PRO | src/pages/pengaturan/TabPenomoran.vue | v1.1 | 14.19.0: posisi nomor per bagian dan atur nomor berikutnya | 21/10/2026 -->
<script setup>
// Pengaturan → Penomoran.
// v1.1: "Posisi nomor per bagian": Yayasan, Pondok, Wustha, dan SMA masing-masing punya urutan sendiri untuk surat biasa
//       (berkelanjutan lintas kode perihal), Surat Keputusan/QR (urutan sendiri), dan agenda surat masuk. Admin dapat
//       mengatur nomor berikutnya (mis. 1231) karena surat sudah terbit sebelum SIMKA dipakai; server menolak nomor yang
//       sudah terpakai. Pola format per bagian wajib memuat {UNIT}.
import { ref, computed, onMounted } from 'vue'
import { PhFloppyDisk, PhPlus, PhTrash, PhEye, PhEnvelopeSimple, PhGavel, PhTray, PhPencilSimple, PhInfo, PhArrowClockwise } from '@phosphor-icons/vue'
import { useLembaga } from '@/stores/lembaga'
import { useUI } from '@/stores/ui'
import LembarBawah from '@/components/LembarBawah.vue'

const lembaga = useLembaga(); const ui = useUI()
const galat = (e) => ui.toast(e.message, 'galat')
const TOKEN = [
  ['{DK}', 'D (Dakhily, ke dalam) atau K (Khariji, ke luar)'], ['{URUT3}', 'Nomor urut minimal 3 digit: 001, 045; ribuan tetap utuh: 1231'], ['{URUT}', 'Nomor urut tanpa nol: 1'],
  ['{PERIHAL}', 'Kode perihal: QR, AM, DW, …'], ['{UNIT}', 'Kode unit dari kop surat (wajib pada format per bagian)'], ['{BLN_H_ROMAWI}', 'Bulan Hijriah romawi'],
  ['{THN_H}', 'Tahun Hijriah'], ['{BLN_ROMAWI}', 'Bulan Masehi romawi'], ['{BLN}', 'Bulan Masehi 2 digit'], ['{THN}', 'Tahun Masehi'],
]
const RESET = { tahun_hijriah: 'Setiap tahun Hijriah', tahun_masehi: 'Setiap tahun Masehi', bulan_masehi: 'Setiap bulan', tidak: 'Tidak pernah (berlanjut terus)' }

// ---------- Posisi nomor per bagian ----------
const KOLOM = [
  { f: 'surat', n: 'Surat biasa', ket: 'Berlanjut untuk semua kode perihal selain QR', ikon: PhEnvelopeSimple, w: 'jadwal' },
  { f: 'sk', n: 'Surat Keputusan (QR)', ket: 'Urutan sendiri, hanya kode perihal QR', ikon: PhGavel, w: 'pengajuan' },
  { f: 'agenda_masuk', n: 'Agenda surat masuk', ket: 'Nomor agenda surat yang diterima', ikon: PhTray, w: 'santri' },
]
const posisi = ref([]); const memuatPosisi = ref(false)
async function muatPosisi() {
  memuatPosisi.value = true
  try { posisi.value = await lembaga.posisiNomor() } catch (e) { galat(e) } finally { memuatPosisi.value = false }
}
const bagian = computed(() => {
  const kops = [...new Map(posisi.value.filter((x) => x.per_kop).map((x) => [x.kop, x.kop_nama])).entries()]
  return kops.map(([kop, nama]) => ({ kop, nama: (nama || kop).replace(/^Kop\s+/i, ''), sel: Object.fromEntries(KOLOM.map((k) => [k.f, posisi.value.find((x) => x.format === k.f && x.kop === kop)])) }))
})
const lembarAtur = ref(false); const fa = ref(null); const prosesAtur = ref(false)
function bukaAtur(x, kolom, namaBagian) {
  fa.value = { x, kolom, namaBagian, nilai: (x.terakhir || 0) + 1 }; lembarAtur.value = true
}
async function simpanAtur() {
  const n = Number(fa.value.nilai)
  if (!Number.isInteger(n) || n < 1) return ui.toast('Isi nomor urut berikutnya dengan angka bulat, mis. 1231.', 'galat')
  if (n <= (fa.value.x.terpakai || 0)) return ui.toast(`Nomor ${n} sudah terpakai di SIMKA. Paling kecil ${fa.value.x.terpakai + 1}.`, 'galat')
  prosesAtur.value = true
  try {
    await lembaga.aturNomorBerikutnya(fa.value.x.format, fa.value.x.kop, n)
    ui.toast(`${fa.value.kolom.n} ${fa.value.namaBagian}: nomor berikutnya ${n}.`); lembarAtur.value = false; await muatPosisi()
  } catch (e) { galat(e) } finally { prosesAtur.value = false }
}

const draf = ref({}); const contoh = ref({})
const opsi = ref({ dk: 'D', perihal: 'NZ', kop: 'pondok' })
onMounted(() => { lembaga.doc_number_formats.forEach((f) => { draf.value[f.kode] = { ...f } }); perbaruiContoh(); muatPosisi() })
async function perbaruiContoh() {
  for (const f of lembaga.doc_number_formats) {
    try { contoh.value[f.kode] = await lembaga.pratinjauNomor(f.kode, opsi.value) } catch { contoh.value[f.kode] = '' }
  }
}
async function simpanFormat(kode) {
  const d = draf.value[kode]
  if (!d.pola?.includes('{URUT')) return ui.toast('Pola wajib memuat {URUT3} atau {URUT}.', 'galat')
  if (d.per_kop && !d.pola.includes('{UNIT}')) return ui.toast('Pola ini dihitung per bagian, jadi wajib memuat {UNIT} agar nomor antarbagian tidak sama.', 'galat')
  try {
    await lembaga.simpanBaris('doc_number_formats', { kode, pola: d.pola.trim(), reset: d.reset, aktif: d.aktif }, { pk: 'kode' })
    contoh.value[kode] = await lembaga.pratinjauNomor(kode, opsi.value)
    ui.toast(`Format ${d.nama} disimpan.`); muatPosisi()
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
      <div class="mb-1 flex flex-wrap items-center gap-2">
        <h3 class="judul-bagian flex-1">Posisi nomor per bagian</h3>
        <button class="tombol-ikon" aria-label="Muat ulang posisi nomor" :disabled="memuatPosisi" @click="muatPosisi"><PhArrowClockwise :size="20" :class="memuatPosisi && 'animate-spin'" /></button>
      </div>
      <p class="mb-3 flex items-start gap-1.5 text-sm text-teks2"><PhInfo :size="16" class="mt-0.5 shrink-0" />
        <span>Setiap bagian penerbit surat punya urutan sendiri. Surat biasa berlanjut walau kode perihalnya berganti (D.301/FW lalu K.302/AM);
          Surat Keputusan (QR) punya urutan sendiri. Bila surat sudah terbit sebelum SIMKA dipakai, tekan <b>Atur</b> lalu isi nomor urut berikutnya.</span></p>
      <p v-if="memuatPosisi && !posisi.length" class="py-6 text-center text-sm text-teks3">Memuat posisi nomor…</p>
      <div v-else class="grid gap-3 md:grid-cols-2">
        <div v-for="b in bagian" :key="b.kop" class="rounded-2xl border border-garis p-3">
          <p class="mb-2 font-bold">{{ b.nama }}</p>
          <ul class="space-y-2">
            <li v-for="k in KOLOM" :key="k.f" :class="['w-' + k.w, 'flex items-center gap-3 rounded-xl p-2.5']" style="background: color-mix(in srgb, var(--c) 9%, transparent)">
              <span class="grid h-10 w-10 shrink-0 place-items-center rounded-xl text-white" style="background: var(--c)"><component :is="k.ikon" :size="20" weight="duotone" /></span>
              <span class="min-w-0 flex-1">
                <span class="block text-sm font-semibold">{{ k.n }}</span>
                <template v-if="b.sel[k.f]">
                  <span class="block text-xs text-teks2">Terakhir <b class="tabular-nums">{{ b.sel[k.f].terakhir }}</b> · berikutnya</span>
                  <span class="block truncate font-mono text-sm font-bold tabular-nums" :title="b.sel[k.f].berikutnya">{{ b.sel[k.f].berikutnya }}</span>
                </template>
                <span v-else class="block text-xs text-teks3">Format tidak aktif</span>
              </span>
              <button v-if="b.sel[k.f]" type="button" class="tombol-garis min-h-[40px] shrink-0 px-3 text-sm" :aria-label="`Atur nomor ${k.n} ${b.nama}`" @click="bukaAtur(b.sel[k.f], k, b.nama)"><PhPencilSimple :size="16" /> Atur</button>
            </li>
          </ul>
        </div>
      </div>
      <p class="mt-3 text-xs text-teks3">Urutan kembali ke 1 mengikuti pilihan "Urut ulang" pada format nomor di bawah. Bila nomor surat di pondok tidak pernah diulang dari 1, pilih "Tidak pernah (berlanjut terus)".</p>
    </section>

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
              <p class="flex-1 font-semibold">{{ f.nama }}<span v-if="f.per_kop" class="lencana w-jadwal ml-2 align-middle text-xs">per bagian</span></p>
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

    <LembarBawah v-model="lembarAtur" :judul="fa ? `Atur nomor: ${fa.kolom.n} — ${fa.namaBagian}` : 'Atur nomor'">
      <div v-if="fa" class="space-y-4 pb-2">
        <div class="rounded-xl bg-permukaan2 p-3 text-sm">
          <p>Terakhir terbit di SIMKA pada periode ini: <b class="tabular-nums">{{ fa.x.terpakai || 'belum ada' }}</b></p>
          <p>Penghitung saat ini: <b class="tabular-nums">{{ fa.x.terakhir }}</b> · contoh berikutnya <span class="font-mono font-bold">{{ fa.x.berikutnya }}</span></p>
          <p class="text-teks3">Urut ulang: {{ RESET[fa.x.reset] || fa.x.reset }}{{ fa.x.periode && fa.x.periode !== '-' ? ` (periode ${fa.x.periode})` : '' }}</p>
        </div>
        <div><label class="label-isian" for="na-nilai">Nomor urut berikutnya</label>
          <input id="na-nilai" v-model.number="fa.nilai" type="number" inputmode="numeric" :min="(fa.x.terpakai || 0) + 1" class="isian tabular-nums" />
          <p class="mt-1 text-xs text-teks3">Isi nomor surat terakhir yang sudah terbit (di luar SIMKA) ditambah 1. Contoh: surat terakhir bernomor 1230 → isi 1231. Paling kecil {{ (fa.x.terpakai || 0) + 1 }}.</p></div>
        <button class="tombol-utama w-full" :disabled="prosesAtur" @click="simpanAtur"><PhFloppyDisk :size="20" weight="duotone" /> Simpan nomor berikutnya</button>
      </div>
    </LembarBawah>

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
