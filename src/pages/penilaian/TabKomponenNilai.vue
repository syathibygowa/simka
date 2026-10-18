<!-- SIMKA PRO | src/pages/penilaian/TabKomponenNilai.vue | v1.2 | 14.3.0: komponen Kehadiran otomatis | 17/10/2026 -->
<script setup>
// Komponen isian nilai guru mapel per jenis rapor: kategori (Harian, Ulangan, UTS, UAS, …) beserta bobot (jumlah 100% per aspek),
// "berulang" (guru boleh menambah Harian 1, Harian 2, … yang dirata-rata), dan cara menentukan nilai rapor
// (tunggal / akumulasi / rekomendasi). Wustha: aspek keterampilan, bawaan mengikuti nilai pengetahuan.
// v1.2: komponen "Kehadiran" (paling banyak satu per aspek) — nilainya otomatis = persentase kehadiran santri pada mapel itu
//       dari absensi guru mapel di jurnal mengajar selama semester; bobotnya ikut dalam nilai akhir.
import { ref, computed, watch } from 'vue'
import { PhPlus, PhTrash, PhFloppyDisk, PhCalculator, PhInfo, PhArrowUp, PhArrowDown, PhUserCheck } from '@phosphor-icons/vue'
import { usePenilaian } from '@/stores/penilaian'
import { useUI } from '@/stores/ui'
import { JENIS_RAPOR, MODE_NILAI, ASPEK } from '@/lib/penilaian'

const pn = usePenilaian(); const ui = useUI(); const proses = ref('')
const jenis = ref('sma')
const boleh = computed(() => pn.bolehAtur(jenis.value) && !pn.terkunci)
const ket = computed(() => pn.ketentuan[jenis.value] || {})
const daftar = ref([]); const mode = ref('rekomendasi'); const ikut = ref(true)
function salinForm() {
  daftar.value = pn.kategoriJenis(jenis.value).map((c) => ({ ...c, bobot: Number(c.bobot) }))
  mode.value = ket.value.mode_nilai || 'rekomendasi'; ikut.value = ket.value.keterampilan_ikut !== false
}
watch([jenis, () => pn.kategori, () => pn.ketentuan], salinForm, { immediate: true })
const aspekTampil = computed(() => (ket.value.pakai_keterampilan ? ['pengetahuan', 'keterampilan'] : ['pengetahuan']))
const baris = (a) => daftar.value.filter((c) => c.aspek === a)
const jumlah = (a) => baris(a).filter((c) => c.aktif).reduce((n, c) => n + Number(c.bobot || 0), 0)
function tambah(a) { daftar.value.push({ nama: '', aspek: a, bobot: 0, berulang: true, aktif: true, sumber: 'isian' }) }
const adaHadir = (a) => baris(a).some((c) => c.sumber === 'kehadiran')
function tambahHadir(a) { daftar.value.push({ nama: 'Kehadiran', aspek: a, bobot: 10, berulang: false, aktif: true, sumber: 'kehadiran' }) }
function hapus(c) { daftar.value.splice(daftar.value.indexOf(c), 1) }
function geser(c, arah) {
  const b = baris(c.aspek); const i = b.indexOf(c); const j = i + arah; if (j < 0 || j >= b.length) return
  const ia = daftar.value.indexOf(b[i]); const ib = daftar.value.indexOf(b[j]); [daftar.value[ia], daftar.value[ib]] = [daftar.value[ib], daftar.value[ia]]
}

async function simpanKomponen() {
  if (daftar.value.some((c) => !String(c.nama).trim())) return ui.toast('Setiap komponen wajib bernama.', 'galat')
  for (const a of aspekTampil.value) if (baris(a).some((c) => c.aktif) && jumlah(a) !== 100) return ui.toast(`Bobot komponen ${ASPEK[a].toLowerCase()} harus berjumlah 100% (sekarang ${jumlah(a)}%).`, 'galat')
  proses.value = 'komponen'
  try { await pn.simpanKomponen(jenis.value, daftar.value.map((c) => ({ id: c.id, kode: c.kode, nama: String(c.nama).trim(), aspek: c.aspek, bobot: Number(c.bobot), berulang: c.sumber === 'kehadiran' ? false : !!c.berulang, aktif: !!c.aktif, sumber: c.sumber || 'isian' }))); ui.toast('Komponen nilai disimpan.') }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = '' }
}
async function simpanCara() {
  proses.value = 'cara'
  try { await pn.simpanKetentuan(jenis.value, { mode_nilai: mode.value, ...(ket.value.pakai_keterampilan ? { keterampilan_ikut: ikut.value } : {}) }); ui.toast('Cara menentukan nilai disimpan.') }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = '' }
}

// Contoh hitung: isian contoh per komponen pengetahuan aktif
const CONTOH = [84, 78, 80, 88, 90, 75]
const contoh = computed(() => {
  const b = baris('pengetahuan').filter((c) => c.aktif)
  const isi = b.map((c, i) => ({ nama: c.nama || '…', nilai: CONTOH[i % CONTOH.length], bobot: Number(c.bobot || 0) }))
  const total = isi.reduce((n, x) => n + x.nilai * x.bobot, 0) / 100
  return { isi, total: Math.round(total * 10 ** (ket.value.desimal || 0)) / 10 ** (ket.value.desimal || 0) }
})
</script>
<template>
  <div class="space-y-4">
    <div class="bilah-tab kecil" role="tablist" aria-label="Jenis rapor">
      <button v-for="j in ['sma', 'wustha']" :key="j" type="button" role="tab" :aria-selected="jenis === j" @click="jenis = j"
        :class="['tab-garis', jenis === j && 'aktif']">{{ JENIS_RAPOR[j].n }}</button>
    </div>

    <section class="kartu w-gurumapel p-4">
      <p class="mb-1 font-bold">Cara menentukan nilai rapor</p>
      <p class="mb-3 text-xs text-teks3">Berlaku untuk semua mapel {{ JENIS_RAPOR[jenis].pendek }}, kecuali mapel yang diberi cara khusus di tab Mapel rapor.</p>
      <div class="grid gap-2 md:grid-cols-3" role="radiogroup" aria-label="Cara menentukan nilai rapor">
        <button v-for="(m, k) in MODE_NILAI" :key="k" type="button" role="radio" :aria-checked="mode === k" :disabled="!boleh" @click="mode = k"
          :class="['rounded-2xl border p-3 text-left disabled:cursor-not-allowed', mode === k ? 'border-[color:var(--c)] bg-permukaan2' : 'border-garis']">
          <span class="flex items-center gap-2 font-semibold"><span :class="['grid h-5 w-5 place-items-center rounded-full border-2', mode === k ? 'border-[color:var(--c)]' : 'border-garis']"><span v-if="mode === k" class="h-2.5 w-2.5 rounded-full" style="background: var(--c)" /></span>{{ m.n }}<span v-if="k === 'rekomendasi'" class="lencana w-presensi">disarankan</span></span>
          <span class="mt-1 block text-xs text-teks2">{{ m.ket }}</span></button>
      </div>
      <label v-if="ket.pakai_keterampilan" class="mt-3 flex min-h-[44px] cursor-pointer items-center gap-2 text-sm">
        <input v-model="ikut" type="checkbox" class="h-5 w-5 accent-[#6B3FA0]" :disabled="!boleh" />
        Nilai keterampilan bawaan <b>sama dengan nilai pengetahuan</b> (guru tetap boleh mengisi terpisah)</label>
      <button v-if="boleh" class="tombol-garis mt-3 w-full sm:w-auto" :disabled="!!proses" @click="simpanCara"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses === 'cara' ? 'Menyimpan…' : 'Simpan cara menentukan nilai' }}</button>
    </section>

    <div class="grid gap-4 xl:grid-cols-[1fr_20rem]">
      <section class="kartu w-rapor space-y-4 p-4">
        <div v-for="a in aspekTampil" :key="a">
          <div class="mb-2 flex flex-wrap items-center gap-2">
            <p class="flex-1 font-bold">Komponen {{ ASPEK[a].toLowerCase() }}</p>
            <span :class="['lencana', jumlah(a) === 100 ? 'w-presensi' : 'w-klinik']">Jumlah bobot {{ jumlah(a) }}%</span>
            <button v-if="boleh" class="tombol-garis min-h-[36px] px-3 text-sm" @click="tambah(a)"><PhPlus :size="16" weight="bold" /> Komponen</button>
            <button v-if="boleh && !adaHadir(a)" class="tombol-garis min-h-[36px] px-3 text-sm" @click="tambahHadir(a)"><PhUserCheck :size="16" weight="duotone" /> Kehadiran</button>
          </div>
          <ul class="space-y-2">
            <li v-for="c in baris(a)" :key="c.id || daftar.indexOf(c)" :class="['grid grid-cols-[1fr_6.5rem_auto] items-center gap-2 rounded-xl border border-garis p-2 sm:grid-cols-[1fr_6.5rem_auto_auto_auto]', !c.aktif && 'opacity-60']">
              <input v-model="c.nama" class="isian min-h-[42px]" placeholder="Nama komponen" :disabled="!boleh" :aria-label="'Nama komponen'" />
              <div class="relative"><input v-model.number="c.bobot" type="number" min="0" max="100" class="isian min-h-[42px] pr-7 text-right tabular-nums" :disabled="!boleh || !c.aktif" :aria-label="`Bobot ${c.nama}`" /><span class="absolute right-2.5 top-1/2 -translate-y-1/2 text-xs text-teks3">%</span></div>
              <div v-if="boleh" class="flex sm:order-last"><button class="tombol-ikon h-9 w-9" :aria-label="`Naikkan ${c.nama}`" @click="geser(c, -1)"><PhArrowUp :size="15" /></button>
                <button class="tombol-ikon h-9 w-9" :aria-label="`Turunkan ${c.nama}`" @click="geser(c, 1)"><PhArrowDown :size="15" /></button>
                <button class="tombol-ikon h-9 w-9" :aria-label="`Hapus ${c.nama}`" @click="hapus(c)"><PhTrash :size="15" /></button></div>
              <span v-if="c.sumber === 'kehadiran'" class="col-span-3 flex min-h-[36px] items-center gap-1.5 text-xs font-semibold text-[#1E7D4F] dark:text-[#5BD69A] sm:col-span-1"><PhUserCheck :size="16" weight="duotone" /> Otomatis dari absensi pelajaran</span>
              <label v-else class="col-span-3 flex min-h-[36px] items-center gap-2 text-xs sm:col-span-1"><input v-model="c.berulang" type="checkbox" class="h-4 w-4 accent-[#1D4ED8]" :disabled="!boleh" /> Boleh beberapa kali</label>
              <label class="col-span-3 flex min-h-[36px] items-center gap-2 text-xs sm:col-span-1"><input v-model="c.aktif" type="checkbox" class="h-4 w-4 accent-[#1D4ED8]" :disabled="!boleh" /> Aktif</label>
            </li>
          </ul>
          <p v-if="a === 'keterampilan' && ikut" class="mt-1 text-xs text-teks3">Selama "sama dengan nilai pengetahuan" dicentang, komponen keterampilan hanya dipakai bila guru memilih mengisi terpisah.</p>
        </div>
        <p class="flex gap-2 text-xs text-teks3"><PhInfo :size="16" class="shrink-0" />
          <span><b>Kehadiran</b>: nilainya otomatis = persentase kehadiran santri pada mapel itu selama semester (hadir ÷ pertemuan; sakit, izin, alfa, bolos mengurangi), dari absensi guru mapel di Jurnal mengajar. Guru tidak perlu mengisinya.
            "Boleh beberapa kali": guru dapat menambah isian sendiri dalam komponen ini (mis. Harian 1, Harian 2, Kuis), lalu dirata-rata sebelum dikalikan bobot. Komponen tanpa centang hanya diisi sekali (mis. UTS, UAS).</span></p>
        <button v-if="boleh" class="tombol-utama w-full" :disabled="!!proses" @click="simpanKomponen"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses === 'komponen' ? 'Menyimpan…' : 'Simpan komponen nilai' }}</button>
      </section>

      <aside class="kartu w-tahfizh h-fit p-4">
        <p class="mb-2 flex items-center gap-2 font-bold"><PhCalculator :size="20" weight="duotone" style="color: var(--c)" /> Contoh perhitungan</p>
        <table class="w-full text-sm"><tbody>
          <tr v-for="x in contoh.isi" :key="x.nama" class="border-b border-garis"><td class="py-1">{{ x.nama }}</td><td class="text-right tabular-nums">{{ x.nilai }}</td><td class="w-14 text-right text-teks3 tabular-nums">× {{ x.bobot }}%</td></tr>
          <tr><td class="pt-2 font-bold">Nilai akhir</td><td colspan="2" class="pt-2 text-right text-lg font-extrabold tabular-nums" style="color: var(--c)">{{ contoh.total }}</td></tr>
        </tbody></table>
        <p class="mt-2 text-xs text-teks3">{{ mode === 'tunggal' ? 'Mode nilai tunggal: angka ini hanya bantuan; guru mengisi nilai rapor sendiri.' : mode === 'akumulasi' ? 'Mode akumulasi: angka ini langsung menjadi nilai rapor.' : 'Mode rekomendasi: angka ini tampil sebagai saran nilai rapor yang dapat dipakai atau diubah guru.' }}
          Dibulatkan {{ ket.desimal ? `${ket.desimal} angka desimal` : 'ke bilangan bulat' }}.</p>
      </aside>
    </div>
  </div>
</template>
