<!-- SIMKA PRO | src/pages/penilaian/TabKetentuanNilai.vue | v1.2 | Perbaikan 13.5.0: tab bergaris bawah | 15/10/2026 -->
<script setup>
// Ketentuan per jenis rapor: judul, kop (dari kop surat sistem), label ambang (KKM/KKTP) dan nilai bawaannya, pembulatan,
// bagian rapor (keterampilan, sikap di rapor, kokurikuler, daftar TP, rata-rata, peringkat), fase per kelas (SMA),
// dimensi profil lulusan (kokurikuler), penanda tangan kepala (tengah bawah; orang tua kiri, wali kelas/muhaffizh kanan),
// tempat, jumlah juz UTAS per jenjang dan KKM UTAS (tahfizh).
// v1.1: identitas sekolah per jenis rapor (dicetak pada sampul dan halaman identitas sekolah).
import { ref, computed, watch, onMounted } from 'vue'
import { PhFloppyDisk, PhPlus, PhX, PhSignature, PhInfo } from '@phosphor-icons/vue'
import { usePenilaian } from '@/stores/penilaian'
import { useLembaga } from '@/stores/lembaga'
import { useUI } from '@/stores/ui'
import { JENIS_RAPOR } from '@/lib/penilaian'
import { IDENTITAS_SEKOLAH } from '@/lib/rapor'

const pn = usePenilaian(); const lb = useLembaga(); const ui = useUI(); const proses = ref(false)
onMounted(() => lb.muat().catch(() => {}))
const jenis = ref('sma')
const boleh = computed(() => pn.bolehAtur(jenis.value) && !pn.terkunci)
const f = ref(null); const dimensiBaru = ref('')
function salinForm() { const k = pn.ketentuan[jenis.value]; f.value = k ? { ...k, ambang_bawaan: Number(k.ambang_bawaan), fase: { ...(k.fase || {}) }, dimensi: [...(k.dimensi || [])], identitas: { ...(k.identitas || {}) } } : null }
watch([jenis, () => pn.ketentuan], salinForm, { immediate: true })
const sekolah = computed(() => jenis.value !== 'tahfizh')

const SAKELAR = computed(() => sekolah.value ? [
  { k: 'pakai_keterampilan', n: 'Nilai keterampilan terpisah', ket: 'Kolom Pengetahuan dan Keterampilan (angka, predikat, deskripsi) seperti rapor Wustha.' },
  { k: 'sikap_di_rapor', n: 'Sikap dicetak di rapor', ket: 'Nonaktif: sikap tetap diisi guru di akhir semester dan tampil di leger.' },
  { k: 'pakai_tp', n: 'Deskripsi memuat tujuan pembelajaran', ket: 'Kalimat capaian diikuti daftar TP yang diisi guru (Kurikulum Merdeka).' },
  { k: 'pakai_kokurikuler', n: 'Bagian kokurikuler', ket: 'Nilai dimensi profil lulusan diisi wali kelas; deskripsi tertinggi dan terendah tersusun otomatis.' },
  { k: 'tampil_rata', n: 'Rata-rata nilai dicetak di rapor', ket: 'Baris "Rata-rata nilai" di bawah tabel mapel.' },
  { k: 'tampil_peringkat', n: 'Peringkat dicetak di rapor', ket: 'Nonaktif: peringkat hanya tampil di leger.' },
] : [])

function tambahDimensi() { const v = dimensiBaru.value.trim(); if (v && !f.value.dimensi.includes(v)) f.value.dimensi.push(v); dimensiBaru.value = '' }
async function simpan() {
  const d = f.value
  if (!String(d.judul || '').trim()) return ui.toast('Judul rapor wajib diisi.', 'galat')
  if (!(d.ambang_bawaan >= 0 && d.ambang_bawaan <= 100)) return ui.toast(`${d.label_ambang} harus 0–100.`, 'galat')
  if (!sekolah.value && !(d.utas_juz_sma >= 1 && d.utas_juz_sma <= 30 && d.utas_juz_wustha >= 1 && d.utas_juz_wustha <= 30)) return ui.toast('Jumlah juz UTAS harus 1–30.', 'galat')
  proses.value = true
  try {
    const isi = { judul: d.judul, kop_kode: d.kop_kode || '', label_ambang: d.label_ambang, ambang_bawaan: Number(d.ambang_bawaan), desimal: Number(d.desimal),
      signatory_id: d.signatory_id || '', jabatan_ttd: d.jabatan_ttd || '', tempat: d.tempat, catatan: d.catatan || '' }
    if (sekolah.value) { for (const s of SAKELAR.value) isi[s.k] = !!d[s.k]; isi.fase = d.fase; isi.dimensi = d.dimensi }
    else Object.assign(isi, { utas_juz_sma: Number(d.utas_juz_sma), utas_juz_wustha: Number(d.utas_juz_wustha) })
    const idn = { ...d.identitas }
    await pn.simpanKetentuan(jenis.value, isi); await pn.simpanIdentitas(jenis.value, idn); ui.toast('Ketentuan rapor disimpan.')
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
const penanda = computed(() => lb.signatories.find((s) => s.id === f.value?.signatory_id) || null)
</script>
<template>
  <div class="space-y-4">
    <div class="bilah-tab kecil" role="tablist" aria-label="Jenis rapor">
      <button v-for="(j, k) in JENIS_RAPOR" :key="k" type="button" role="tab" :aria-selected="jenis === k" @click="jenis = k"
        :class="['tab-garis', jenis === k && 'aktif']">{{ j.n }}</button>
    </div>

    <form v-if="f" class="grid gap-4 xl:grid-cols-2" novalidate @submit.prevent="simpan">
      <section class="kartu w-pengaturan space-y-3 p-4">
        <p class="font-bold">Identitas rapor</p>
        <div><label class="label-isian" for="kt-judul">Judul rapor</label><input id="kt-judul" v-model="f.judul" class="isian" :disabled="!boleh" /></div>
        <div><label class="label-isian" for="kt-kop">Kop</label>
          <select id="kt-kop" v-model="f.kop_kode" class="isian" :disabled="!boleh">
            <option v-if="!sekolah" :value="null">Ikut jenjang santri (Kop SMA / Kop Kesetaraan Wustha)</option>
            <option v-for="k in lb.letterheads.filter((x) => x.aktif !== false)" :key="k.kode" :value="k.kode">{{ k.nama }}</option></select>
          <p class="mt-1 text-xs text-teks3">Memakai kop surat yang diatur di Setelan → Kop surat.</p></div>
        <div class="grid grid-cols-3 gap-3">
          <div><label class="label-isian" for="kt-label">Sebutan</label>
            <select id="kt-label" v-model="f.label_ambang" class="isian" :disabled="!boleh || !sekolah"><option>KKM</option><option>KKTP</option></select></div>
          <div><label class="label-isian" for="kt-ambang">{{ sekolah ? `${f.label_ambang} bawaan` : 'KKM UTAS' }}</label>
            <input id="kt-ambang" v-model.number="f.ambang_bawaan" type="number" min="0" max="100" step="0.5" class="isian tabular-nums" :disabled="!boleh" /></div>
          <div><label class="label-isian" for="kt-des">Pembulatan</label>
            <select id="kt-des" v-model.number="f.desimal" class="isian" :disabled="!boleh"><option :value="0">Bulat</option><option :value="1">1 desimal</option><option :value="2">2 desimal</option></select></div>
        </div>
        <p v-if="sekolah" class="text-xs text-teks3">{{ f.label_ambang }} bawaan dipakai untuk mapel rapor baru; {{ f.label_ambang }} setiap mapel diatur di tab Mapel rapor.</p>
        <p v-else class="text-xs text-teks3">Nilai akhir UTAS = (Tajwid + Itqan) ÷ 2. Nilai di bawah KKM dinyatakan remedial; nilai diisi penguji.</p>
        <div v-if="!sekolah" class="grid grid-cols-2 gap-3">
          <div><label class="label-isian" for="kt-jsma">Juz diuji UTAS · SMA</label><input id="kt-jsma" v-model.number="f.utas_juz_sma" type="number" min="1" max="30" class="isian tabular-nums" :disabled="!boleh" /></div>
          <div><label class="label-isian" for="kt-jw">Juz diuji UTAS · Wustha</label><input id="kt-jw" v-model.number="f.utas_juz_wustha" type="number" min="1" max="30" class="isian tabular-nums" :disabled="!boleh" /></div>
          <p class="col-span-2 text-xs text-teks3">Juz diuji berurutan dari capaian semester; bila kurang, ditambah dari hafalan semester sebelumnya; bila total hafalan kurang, semua hafalan diujikan (SOP UTAS).</p>
        </div>
      </section>

      <section class="kartu w-rapor space-y-3 p-4">
        <p class="flex items-center gap-2 font-bold"><PhSignature :size="20" weight="duotone" style="color: var(--c)" /> Tanda tangan</p>
        <p class="flex gap-2 rounded-xl bg-permukaan2 p-3 text-xs text-teks2"><PhInfo :size="16" class="shrink-0" />
          <span>Susunan semua rapor: <b>orang tua/wali di kiri</b>, <b>{{ sekolah ? 'wali kelas' : 'muhaffizh' }} di kanan</b>, dan <b>{{ f.jabatan_ttd || 'kepala' }} di tengah bawah</b> ("Mengetahui"). Tanda tangan basah.</span></p>
        <div><label class="label-isian" for="kt-ttd">Penanda tangan tengah</label>
          <select id="kt-ttd" v-model="f.signatory_id" class="isian" :disabled="!boleh"><option :value="null">Belum dipilih</option>
            <option v-for="s in lb.signatories.filter((x) => x.aktif)" :key="s.id" :value="s.id">{{ s.jabatan_tertulis }} – {{ s.nama }}</option></select>
          <p class="mt-1 text-xs text-teks3">Daftar penanda tangan diatur di Setelan → Penanda tangan{{ !sekolah ? ' (tambahkan "Kepala Bidang Tahfizh" bila belum ada)' : '' }}.</p></div>
        <div class="grid grid-cols-2 gap-3">
          <div><label class="label-isian" for="kt-jab">Jabatan tertulis di rapor</label><input id="kt-jab" v-model="f.jabatan_ttd" class="isian" placeholder="Kepala Sekolah" :disabled="!boleh" /></div>
          <div><label class="label-isian" for="kt-tempat">Tempat</label><input id="kt-tempat" v-model="f.tempat" class="isian" :disabled="!boleh" /></div>
        </div>
        <div v-if="penanda" class="rounded-xl border border-garis p-3 text-center text-sm">
          <p>Mengetahui,</p><p>{{ f.jabatan_ttd || penanda.jabatan_tertulis }}</p><p class="mt-8 font-bold underline">{{ penanda.nama }}</p><p class="text-xs">{{ penanda.niy ? `NIY. ${penanda.niy}` : '' }}</p></div>
      </section>

      <section v-if="sekolah" class="kartu w-gurumapel p-4 xl:col-span-2">
        <p class="mb-2 font-bold">Bagian rapor</p>
        <ul class="grid gap-2 md:grid-cols-2">
          <li v-for="s in SAKELAR" :key="s.k" class="flex items-start gap-3 rounded-xl border border-garis p-3">
            <div class="min-w-0 flex-1"><p class="text-sm font-semibold">{{ s.n }}</p><p class="text-xs text-teks3">{{ s.ket }}</p></div>
            <button type="button" role="switch" :aria-checked="!!f[s.k]" :aria-label="s.n" :disabled="!boleh" @click="f[s.k] = !f[s.k]"
              :class="['relative h-8 w-14 shrink-0 rounded-full transition disabled:opacity-60', f[s.k] ? 'bg-[#1E7D4F]' : 'bg-garis']">
              <span :class="['absolute top-1 h-6 w-6 rounded-full bg-white shadow transition-all', f[s.k] ? 'left-7' : 'left-1']" /></button>
          </li>
        </ul>
      </section>

      <section v-if="jenis === 'sma'" class="kartu w-agenda p-4">
        <p class="mb-2 font-bold">Fase per kelas</p>
        <div class="grid grid-cols-3 gap-3">
          <div v-for="t in JENIS_RAPOR.sma.tingkat" :key="t"><label class="label-isian" :for="`fs-${t}`">Kelas {{ t }}</label>
            <input :id="`fs-${t}`" v-model="f.fase[t]" maxlength="2" class="isian text-center font-bold uppercase" :disabled="!boleh" /></div>
        </div>
        <p class="mt-1 text-xs text-teks3">Dicetak di kepala rapor (contoh: kelas X fase E, kelas XI–XII fase F).</p>
      </section>

      <section v-if="sekolah && f.pakai_kokurikuler" class="kartu w-walikelas p-4">
        <p class="mb-2 font-bold">Dimensi profil lulusan (kokurikuler)</p>
        <ul class="flex flex-wrap gap-2">
          <li v-for="(d, i) in f.dimensi" :key="d" class="lencana py-1 text-sm">{{ d }}
            <button v-if="boleh" type="button" class="ml-1" :aria-label="`Hapus ${d}`" @click="f.dimensi.splice(i, 1)"><PhX :size="12" weight="bold" /></button></li>
        </ul>
        <div v-if="boleh" class="mt-2 flex gap-2"><input v-model="dimensiBaru" class="isian min-h-[42px]" placeholder="Tambah dimensi" @keydown.enter.prevent="tambahDimensi" />
          <button type="button" class="tombol-garis min-h-[42px] px-3" @click="tambahDimensi"><PhPlus :size="18" weight="bold" /></button></div>
        <p class="mt-1 text-xs text-teks3">Wali kelas mengisi nilai 1–4 per dimensi; tema kokurikuler diisi per semester di tab Periode.</p>
      </section>

      <section class="kartu w-santri p-4 xl:col-span-2">
        <p class="mb-1 font-bold">Identitas sekolah</p>
        <p class="mb-3 text-xs text-teks3">Dicetak pada sampul rapor dan halaman identitas sekolah {{ JENIS_RAPOR[jenis].n }}.</p>
        <div class="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
          <div v-for="x in IDENTITAS_SEKOLAH" :key="x.k" :class="x.lebar ? 'sm:col-span-2' : ''">
            <label class="label-isian" :for="`idn-${x.k}`">{{ x.k === 'nss' && jenis !== 'sma' ? 'NSPP' : x.n }}</label>
            <input :id="`idn-${x.k}`" v-model="f.identitas[x.k]" class="isian" :disabled="!boleh" /></div>
        </div>
      </section>

      <section class="kartu p-4 xl:col-span-2">
        <label class="label-isian" for="kt-cat">Catatan</label><textarea id="kt-cat" v-model="f.catatan" rows="2" class="isian" placeholder="Opsional, mis. dasar ketentuan" :disabled="!boleh" />
        <button v-if="boleh" class="tombol-utama mt-3 w-full" :disabled="proses"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses ? 'Menyimpan…' : `Simpan ketentuan ${JENIS_RAPOR[jenis].n}` }}</button>
      </section>
    </form>
  </div>
</template>
