<!-- SIMKA PRO | src/pages/penilaian/TabPredikatNilai.vue | v1.1 | Perbaikan 13.5.0: tab bergaris bawah | 15/10/2026 -->
<script setup>
// Tabel predikat per kelompok: Mapel SMA, Mapel Wustha (pengetahuan + keterampilan), UTAS tahfizh (sebutan Arab/Indonesia
// dengan tombol pilihan bahasa), Pengembangan diri (nilai huruf + templat deskripsi {kegiatan}), dan Sikap.
// Rentang tidak boleh bertumpuk; celah ditandai. Uji cepat: ketik nilai, lihat predikatnya.
import { ref, computed, watch } from 'vue'
import { PhPlus, PhX, PhFloppyDisk, PhWarningCircle, PhTranslate, PhMagnifyingGlass } from '@phosphor-icons/vue'
import { usePenilaian } from '@/stores/penilaian'
import { useUI } from '@/stores/ui'
import { KELOMPOK_PREDIKAT, predikatDari, sebutanPredikat, celahPredikat } from '@/lib/penilaian'

const pn = usePenilaian(); const ui = useUI(); const proses = ref('')
const kel = ref('sma')
const info = computed(() => KELOMPOK_PREDIKAT[kel.value])
const boleh = computed(() => (info.value.jenis ? pn.bolehAtur(info.value.jenis) : pn.bolehAtur()) && !pn.terkunci)
const daftar = ref([])
function salinForm() { daftar.value = pn.predikatKelompok(kel.value).map((p) => ({ ...p, nilai_min: p.nilai_min == null ? '' : Number(p.nilai_min), nilai_maks: p.nilai_maks == null ? '' : Number(p.nilai_maks) })) }
watch([kel, () => pn.predikat], salinForm, { immediate: true })
const celah = computed(() => (info.value.angka ? celahPredikat(daftar.value) : []))
const bahasa = ref('arab')
watch(() => pn.ketentuan.tahfizh?.bahasa_predikat, (v) => { bahasa.value = v || 'arab' }, { immediate: true })
const uji = ref(''); const hasilUji = computed(() => predikatDari(uji.value, daftar.value))

function tambah() { daftar.value.push({ huruf: '', nilai_min: '', nilai_maks: '', sebutan: '', sebutan_arab: '', deskripsi: '', deskripsi_2: '', tuntas: true }) }
async function simpan() {
  const d = daftar.value
  if (d.length < 2) return ui.toast('Predikat minimal dua baris.', 'galat')
  if (d.some((p) => !String(p.huruf).trim() || !String(p.sebutan).trim())) return ui.toast('Setiap predikat wajib berhuruf dan bersebutan.', 'galat')
  if (info.value.angka && d.some((p) => p.nilai_min === '' || p.nilai_maks === '' || Number(p.nilai_min) > Number(p.nilai_maks))) return ui.toast('Isi rentang nilai dengan batas bawah tidak melebihi batas atas.', 'galat')
  proses.value = 'predikat'
  try {
    await pn.simpanPredikat(kel.value, d.map((p, i) => ({ huruf: String(p.huruf).trim(), sebutan: p.sebutan, sebutan_arab: p.sebutan_arab || '', deskripsi: p.deskripsi || '', deskripsi_2: p.deskripsi_2 || '',
      tuntas: !!p.tuntas, urutan: i + 1, ...(info.value.angka ? { nilai_min: Number(p.nilai_min), nilai_maks: Number(p.nilai_maks) } : {}) })))
    ui.toast('Predikat disimpan.')
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = '' }
}
async function simpanBahasa(b) {
  bahasa.value = b; proses.value = 'bahasa'
  try { await pn.simpanKetentuan('tahfizh', { bahasa_predikat: b }); ui.toast(b === 'arab' ? 'Predikat UTAS memakai sebutan Arab (Mumtaz, Jayyid Jiddan, …).' : 'Predikat UTAS memakai sebutan Indonesia (Istimewa, Sangat Baik, …).') }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = '' }
}
</script>
<template>
  <div class="space-y-4">
    <div class="bilah-tab kecil" role="tablist" aria-label="Kelompok predikat">
      <button v-for="(k, kode) in KELOMPOK_PREDIKAT" :key="kode" type="button" role="tab" :aria-selected="kel === kode" @click="kel = kode"
        :class="['tab-garis', kel === kode && 'aktif']">{{ k.n }}</button>
    </div>

    <section v-if="kel === 'utas'" class="kartu w-tahfizh flex flex-wrap items-center gap-3 p-4">
      <span class="chip-ikon h-10 w-10"><PhTranslate :size="22" weight="duotone" /></span>
      <div class="min-w-[200px] flex-1"><p class="font-bold">Bahasa sebutan predikat di rapor</p>
        <p class="text-xs text-teks3">Dipakai di rapor tahfizh dan bagian Pencapaian Program Tahfizh rapor sekolah.</p></div>
      <div class="grid grid-cols-2 gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" aria-label="Bahasa predikat">
        <button v-for="b in [{ k: 'arab', n: 'Arab (Jayyid Jiddan)' }, { k: 'indonesia', n: 'Indonesia (Sangat Baik)' }]" :key="b.k" type="button" role="radio" :aria-checked="bahasa === b.k"
          :disabled="!pn.bolehAtur('tahfizh') || pn.terkunci || !!proses" @click="simpanBahasa(b.k)"
          :class="['min-h-[40px] rounded-xl px-3 text-sm font-semibold', bahasa === b.k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">{{ b.n }}</button>
      </div>
    </section>

    <section class="kartu w-pengajuan p-4">
      <div class="mb-1 flex flex-wrap items-center gap-2"><p class="flex-1 font-bold">Predikat {{ info.n }}</p>
        <button v-if="boleh" class="tombol-garis min-h-[36px] px-3 text-sm" @click="tambah"><PhPlus :size="16" weight="bold" /> Baris</button></div>
      <p class="mb-3 text-xs text-teks3">{{ info.ket }}</p>
      <ul class="space-y-3">
        <li v-for="(p, i) in daftar" :key="i" class="rounded-xl border border-garis p-3">
          <div :class="['grid items-end gap-2', info.angka ? (info.arab ? 'grid-cols-[4rem_1fr_1fr_auto] lg:grid-cols-[4rem_7rem_7rem_1fr_1fr_auto]' : 'grid-cols-[4rem_1fr_1fr_auto] lg:grid-cols-[4rem_7rem_7rem_1fr_auto]') : 'grid-cols-[4rem_1fr_auto]']">
            <div><label class="label-isian" :for="`pd-h${i}`">Huruf</label><input :id="`pd-h${i}`" v-model="p.huruf" maxlength="3" class="isian text-center font-bold uppercase" :disabled="!boleh" /></div>
            <template v-if="info.angka">
              <div><label class="label-isian" :for="`pd-a${i}`">Nilai dari</label><input :id="`pd-a${i}`" v-model.number="p.nilai_min" type="number" min="0" max="100" step="0.01" class="isian tabular-nums" :disabled="!boleh" /></div>
              <div><label class="label-isian" :for="`pd-b${i}`">sampai</label><input :id="`pd-b${i}`" v-model.number="p.nilai_maks" type="number" min="0" max="100" step="0.01" class="isian tabular-nums" :disabled="!boleh" /></div>
            </template>
            <button v-if="boleh" :class="['tombol-ikon h-11 w-11', info.angka ? 'lg:order-last' : 'order-last']" :aria-label="`Hapus predikat ${p.huruf}`" @click="daftar.splice(i, 1)"><PhX :size="18" /></button>
            <div :class="info.angka ? (info.arab ? 'col-span-2 lg:col-span-1' : 'col-span-4 lg:col-span-1') : ''"><label class="label-isian" :for="`pd-s${i}`">Sebutan{{ info.arab ? ' Indonesia' : '' }}</label><input :id="`pd-s${i}`" v-model="p.sebutan" class="isian" :disabled="!boleh" /></div>
            <div v-if="info.arab" class="col-span-2 lg:col-span-1"><label class="label-isian" :for="`pd-ar${i}`">Sebutan Arab (Latin)</label><input :id="`pd-ar${i}`" v-model="p.sebutan_arab" class="isian italic" placeholder="Mumtaz" :disabled="!boleh" /></div>
          </div>
          <div v-if="kel !== 'utas' && kel !== 'sikap'" :class="['mt-2 grid gap-2', info.dua ? 'sm:grid-cols-2' : '']">
            <div><label class="label-isian" :for="`pd-d${i}`">{{ kel === 'pd' ? 'Templat deskripsi' : info.dua ? 'Kalimat capaian pengetahuan' : 'Kalimat capaian' }}</label>
              <textarea :id="`pd-d${i}`" v-model="p.deskripsi" rows="1" class="isian" :disabled="!boleh" /></div>
            <div v-if="info.dua"><label class="label-isian" :for="`pd-d2${i}`">Kalimat capaian keterampilan</label><textarea :id="`pd-d2${i}`" v-model="p.deskripsi_2" rows="1" class="isian" :disabled="!boleh" /></div>
          </div>
          <label class="mt-2 flex min-h-[36px] items-center gap-2 text-sm"><input v-model="p.tuntas" type="checkbox" class="h-5 w-5 accent-[#6D44B8]" :disabled="!boleh" /> Dihitung tuntas/lulus</label>
        </li>
      </ul>
      <p v-for="c in celah" :key="c[0]" class="mt-2 flex items-center gap-1.5 text-sm font-semibold text-merah"><PhWarningCircle :size="16" weight="bold" /> Ada celah: nilai di antara {{ c[0] }} dan {{ c[1] }} tidak masuk predikat mana pun.</p>
      <p v-if="kel === 'sma'" class="mt-2 text-xs text-teks3">Di rapor SMA kalimat capaian diikuti daftar tujuan pembelajaran, mis. "Perlu bimbingan dan pendalaman materi mengenai Demokrasi, Hak Asasi".</p>
      <button v-if="boleh" class="tombol-utama mt-3 w-full" :disabled="!!proses" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses === 'predikat' ? 'Menyimpan…' : 'Simpan predikat' }}</button>
    </section>

    <section v-if="info.angka" class="kartu w-rekap flex flex-wrap items-center gap-3 p-4">
      <span class="chip-ikon h-10 w-10"><PhMagnifyingGlass :size="22" weight="duotone" /></span>
      <div class="w-32"><label class="label-isian" for="pd-uji">Uji nilai</label><input id="pd-uji" v-model="uji" type="number" min="0" max="100" class="isian tabular-nums" placeholder="mis. 77" /></div>
      <p class="min-w-[180px] flex-1 text-sm">
        <template v-if="uji === ''"><span class="text-teks3">Ketik nilai untuk melihat predikatnya.</span></template>
        <template v-else-if="hasilUji"><b class="text-lg">{{ hasilUji.huruf }}</b> · {{ sebutanPredikat(hasilUji, kel === 'utas' ? bahasa : 'indonesia') }}{{ hasilUji.tuntas ? '' : ' (belum tuntas)' }}
          <span v-if="hasilUji.deskripsi" class="block text-xs text-teks3">{{ hasilUji.deskripsi }}</span></template>
        <span v-else class="font-semibold text-merah">Tidak masuk predikat mana pun.</span></p>
    </section>
  </div>
</template>
