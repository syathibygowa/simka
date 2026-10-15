<!-- SIMKA PRO | src/pages/jadwal/TabPengaturanJadwal.vue | v1.1 | Perbaikan 13.6.0: sub-tab jenjang, kumpulan jam Sabtu, pembagian jam per hari | 15/10/2026 -->
<script setup>
// Pengaturan akademik per jenjang (sub-tab Wustha (SMP) / SMA): mata pelajaran (umum, kepesantrenan, muatan lokal)
// dan jam pelajaran. Tiga kumpulan jam (reguler, Jumat, Sabtu) dan pembagian hari → kumpulan jam dapat diatur,
// mis. Senin–Kamis jam reguler, Jumat jam Jumat, Sabtu jam Sabtu.
import { ref, computed, onMounted, watch } from 'vue'
import { PhPlus, PhPencilSimple, PhX, PhFloppyDisk, PhCoffee, PhBooks, PhClock, PhCalendarDots, PhSun, PhMosque, PhCalendarBlank } from '@phosphor-icons/vue'
import { useJadwal } from '@/stores/jadwal'
import { useUI } from '@/stores/ui'
import { KELOMPOK_MAPEL, JENJANG_MAPEL, JENIS_JAM, JENJANG_TAB, HARI_SEKOLAH } from '@/lib/jadwal'
import { HARI } from '@/lib/tanggal'
import SubTabJenjang from '@/components/SubTabJenjang.vue'
import LembarBawah from '@/components/LembarBawah.vue'

const jd = useJadwal(); const ui = useUI()
onMounted(() => jd.muat())
const proses = ref(false)

// ---------- Mapel ----------
const lembarMapel = ref(false); const fm = ref(null)
// Mapel jenjang terpilih (termasuk mapel untuk semua jenjang)
const mapelJenjang = computed(() => jd.mapel.filter((m) => m.jenjang === 'semua' || m.jenjang === jenjang.value))
function bukaMapel(m = null) { fm.value = m ? { ...m } : { kode: '', nama: '', jenjang: jenjang.value, kelompok: 'umum', urutan: jd.mapel.length + 1, aktif: true }; lembarMapel.value = true }
async function simpanMapel() {
  if (!/^[A-Za-z0-9_]{1,20}$/.test(fm.value.kode.trim())) return ui.toast('Kode mapel 1–20 huruf/angka tanpa spasi, mis. MTK.', 'galat')
  if (fm.value.nama.trim().length < 3) return ui.toast('Nama mapel wajib diisi.', 'galat')
  proses.value = true
  try { await jd.simpanMapel({ ...fm.value, kode: fm.value.kode.trim().toUpperCase(), nama: fm.value.nama.trim() }); lembarMapel.value = false; ui.toast('Mata pelajaran disimpan.') }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}

// ---------- Jam pelajaran ----------
const jenjang = ref('wustha'); const jenisHari = ref('reguler'); const baris = ref([]); const berubah = ref(false)
const IKON_JAM = { reguler: PhCalendarDots, jumat: PhMosque, sabtu: PhSun }
const WARNA_JAM = { reguler: 'jadwal', jumat: 'presensi', sabtu: 'tahfizh' }
/** Hari yang memakai tiap kumpulan jam (untuk label sub-tab) */
const hariPakai = (jh) => HARI_SEKOLAH.filter((h) => jd.jenisHariUntuk(jenjang.value, h) === jh)
const ringkasHari = (jh) => { const d = hariPakai(jh); return d.length ? d.map((h) => HARI[h].slice(0, 3)).join(', ') : 'belum dipakai' }

// ---------- Pembagian jam per hari ----------
const peta = ref({}); const petaBerubah = ref(false)
const muatPeta = () => { peta.value = Object.fromEntries(HARI_SEKOLAH.map((h) => [String(h), jd.jenisHariUntuk(jenjang.value, h)])); petaBerubah.value = false }
watch([jenjang, () => jd.hariJam], muatPeta, { immediate: true, deep: true })
async function simpanPeta() {
  if (!(await ui.konfirmasi({ judul: 'Simpan pembagian jam per hari?', pesan: 'Jadwal pada hari yang berganti kumpulan jam dipindahkan ke jam dengan urutan yang sama; jam yang tidak ada padanannya dikosongkan. Kumpulan jam yang masih kosong disalin dari kumpulan lama.', ya: 'Simpan' }))) return
  proses.value = true
  try {
    const h = await jd.simpanHariJam(jenjang.value, peta.value)
    ui.toast(h?.dikosongkan ? `Pembagian disimpan. ${h.dipindah} jadwal dipindah, ${h.dikosongkan} dikosongkan.` : 'Pembagian jam per hari disimpan.')
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
const muatBaris = () => { baris.value = jd.jamUntuk(jenjang.value, jenisHari.value).map((p) => ({ ...p })); berubah.value = false }
watch([jenjang, jenisHari, () => jd.jam], muatBaris, { immediate: true })
function tambah(jenis) {
  const akhir = baris.value[baris.value.length - 1]; const mulai = akhir?.jam_selesai || '08:00'
  const menit = jenis === 'istirahat' ? 20 : jenjang.value === 'sma' ? 45 : 40
  const [h, m] = mulai.split(':').map(Number); const t = h * 60 + m + menit
  baris.value.push({ jenis, nama: '', jam_mulai: mulai, jam_selesai: `${String(Math.floor(t / 60)).padStart(2, '0')}:${String(t % 60).padStart(2, '0')}` }); berubah.value = true
}
const bernama = computed(() => { let n = 0; return baris.value.map((b) => (b.jenis === 'jp' ? `Jam ke-${++n}` : b.nama || 'Istirahat')) })
async function simpanJam() {
  for (const b of baris.value) if (!b.jam_mulai || !b.jam_selesai || b.jam_selesai <= b.jam_mulai) return ui.toast('Setiap baris: jam selesai harus setelah jam mulai.', 'galat')
  const urut = [...baris.value].sort((a, b) => a.jam_mulai.localeCompare(b.jam_mulai))
  for (let i = 1; i < urut.length; i++) if (urut[i].jam_mulai < urut[i - 1].jam_selesai) return ui.toast('Ada jam yang tumpang tindih.', 'galat')
  if (!(await ui.konfirmasi({ judul: 'Simpan jam pelajaran?', pesan: 'Jam yang dihapus atau diubah menjadi istirahat ikut menghapus jadwal pelajaran pada jam tersebut.', ya: 'Simpan' }))) return
  proses.value = true
  try {
    let n = 0
    await jd.simpanJam(jenjang.value, jenisHari.value, urut.map((b, i) => ({ urutan: i + 1, jenis: b.jenis, nama: b.jenis === 'jp' ? `Jam ke-${++n}` : (b.nama || 'Istirahat'), jam_mulai: b.jam_mulai, jam_selesai: b.jam_selesai })))
    ui.toast('Jam pelajaran disimpan.')
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <div class="space-y-4">
    <SubTabJenjang v-model="jenjang" :semua="false" label="Jenjang pengaturan" />
  <div class="grid gap-4 xl:grid-cols-2">
    <!-- Jam pelajaran -->
    <section class="kartu w-jadwal p-4">
      <p class="mb-3 flex items-center gap-2 font-bold"><PhClock :size="20" weight="duotone" style="color: var(--c)" /> Jam pelajaran {{ JENJANG_TAB[jenjang].n }}</p>

      <!-- Pembagian hari → kumpulan jam -->
      <div class="mb-4 rounded-2xl bg-permukaan2 p-3">
        <p class="mb-2 flex items-center gap-2 text-sm font-bold"><PhCalendarBlank :size="18" weight="duotone" /> Pembagian jam per hari</p>
        <div class="grid grid-cols-2 gap-2 sm:grid-cols-3">
          <label v-for="h in HARI_SEKOLAH" :key="h" class="block"><span class="mb-1 block text-xs font-semibold text-teks2">{{ HARI[h] }}</span>
            <select v-model="peta[String(h)]" class="isian h-10 min-h-0 py-0 text-sm" @change="petaBerubah = true"><option v-for="(n, k) in JENIS_JAM" :key="k" :value="k">{{ n }}</option></select></label>
        </div>
        <button v-if="petaBerubah" class="tombol-utama mt-2 min-h-[40px] w-full text-sm" :disabled="proses" @click="simpanPeta"><PhFloppyDisk :size="18" weight="duotone" /> Simpan pembagian jam per hari</button>
        <p v-else class="mt-2 text-xs text-teks3">Contoh: Senin–Kamis jam reguler, Jumat jam Jumat, Sabtu jam Sabtu. Ubah bila jam suatu hari berbeda.</p>
      </div>

      <!-- Sub-tab kumpulan jam -->
      <nav class="bilah-tab kecil mb-3" role="tablist" aria-label="Kumpulan jam">
        <button v-for="(n, k) in JENIS_JAM" :key="k" type="button" role="tab" :aria-selected="jenisHari === k" :class="['tab-garis', 'w-' + WARNA_JAM[k], jenisHari === k && 'aktif']" @click="jenisHari = k">
          <component :is="IKON_JAM[k]" :size="18" weight="duotone" /><span>{{ n }}</span></button>
      </nav>
      <p class="-mt-1 mb-3 text-xs text-teks3">Dipakai pada: <b class="font-semibold text-teks2">{{ ringkasHari(jenisHari) }}</b></p>
      <p v-if="!baris.length" class="mb-2 rounded-xl bg-permukaan2 p-3 text-sm text-teks2">Kumpulan {{ JENIS_JAM[jenisHari].toLowerCase() }} belum berisi jam. Tambahkan di bawah, atau pilih kumpulan ini di Pembagian jam per hari (jam lama disalin otomatis).</p>
      <ul class="space-y-2">
        <li v-for="(b, i) in baris" :key="i" :class="['flex flex-wrap items-center gap-2 rounded-xl p-2', b.jenis === 'istirahat' ? 'bg-permukaan2' : 'border border-garis']">
          <span class="w-24 text-sm font-semibold">{{ bernama[i] }}</span>
          <input v-if="b.jenis === 'istirahat'" v-model="b.nama" class="isian min-h-[40px] w-40 flex-1 text-sm" placeholder="Istirahat" aria-label="Nama istirahat" @input="berubah = true" />
          <input v-model="b.jam_mulai" type="time" class="isian min-h-[40px] w-28 text-sm tabular-nums" aria-label="Jam mulai" @input="berubah = true" />
          <span class="text-teks3">–</span>
          <input v-model="b.jam_selesai" type="time" class="isian min-h-[40px] w-28 text-sm tabular-nums" aria-label="Jam selesai" @input="berubah = true" />
          <button class="tombol-ikon h-9 w-9" :aria-label="`Hapus ${bernama[i]}`" @click="baris.splice(i, 1); berubah = true"><PhX :size="16" /></button>
        </li>
      </ul>
      <div class="mt-3 grid grid-cols-2 gap-2">
        <button class="tombol-garis" @click="tambah('jp')"><PhPlus :size="18" weight="bold" /> Jam pelajaran</button>
        <button class="tombol-garis" @click="tambah('istirahat')"><PhCoffee :size="18" weight="duotone" /> Istirahat</button>
      </div>
      <button class="tombol-utama mt-2 w-full" :disabled="proses || !berubah" @click="simpanJam"><PhFloppyDisk :size="20" weight="duotone" /> Simpan {{ JENIS_JAM[jenisHari].toLowerCase() }} {{ JENJANG_TAB[jenjang].n }}</button>
      <p class="mt-2 text-xs text-teks3">Isi awal: jam ke-1 pukul 08.00; 1 JP Wustha 40 menit, SMA 45 menit; Jumat lebih singkat. Ubah sesuai ketentuan pondok.</p>
    </section>

    <!-- Mata pelajaran -->
    <section class="kartu w-laporan p-4">
      <div class="mb-3 flex items-center gap-2"><p class="flex flex-1 items-center gap-2 font-bold"><PhBooks :size="20" weight="duotone" style="color: var(--c)" /> Mata pelajaran {{ JENJANG_TAB[jenjang].n }} ({{ mapelJenjang.length }})</p>
        <button class="tombol-garis min-h-[36px] px-3 text-sm" @click="bukaMapel()"><PhPlus :size="16" weight="bold" /> Mapel</button></div>
      <ul class="divide-y divide-garis">
        <li v-for="m in mapelJenjang" :key="m.id" :class="['flex items-center gap-2 py-2 text-sm', !m.aktif && 'opacity-60']">
          <span class="w-16 font-mono text-xs text-teks3">{{ m.kode }}</span>
          <span class="min-w-0 flex-1"><b>{{ m.nama }}</b><span class="block text-xs text-teks3">{{ JENJANG_MAPEL[m.jenjang] }} · {{ KELOMPOK_MAPEL[m.kelompok] }}{{ m.aktif ? '' : ' · nonaktif' }}</span></span>
          <button class="tombol-ikon h-9 w-9" :aria-label="`Ubah ${m.nama}`" @click="bukaMapel(m)"><PhPencilSimple :size="18" /></button>
        </li>
      </ul>
    </section>

    <LembarBawah v-model="lembarMapel" :judul="fm?.id ? 'Ubah mata pelajaran' : 'Tambah mata pelajaran'">
      <div v-if="fm" class="space-y-3 pb-2">
        <div class="grid grid-cols-3 gap-2">
          <div><label class="label-isian" for="mp-k">Kode *</label><input id="mp-k" v-model="fm.kode" class="isian uppercase" maxlength="20" placeholder="MTK" /></div>
          <div class="col-span-2"><label class="label-isian" for="mp-n">Nama *</label><input id="mp-n" v-model="fm.nama" class="isian" placeholder="Matematika" /></div>
        </div>
        <div><label class="label-isian" for="mp-j">Jenjang</label><select id="mp-j" v-model="fm.jenjang" class="isian"><option v-for="(n, k) in JENJANG_MAPEL" :key="k" :value="k">{{ n }}</option></select></div>
        <div><label class="label-isian" for="mp-g">Kelompok</label><select id="mp-g" v-model="fm.kelompok" class="isian"><option v-for="(n, k) in KELOMPOK_MAPEL" :key="k" :value="k">{{ n }}</option></select></div>
        <label v-if="fm.id" class="flex min-h-[44px] items-center gap-2 text-sm font-semibold"><input v-model="fm.aktif" type="checkbox" class="h-5 w-5 accent-[#0B7F81]" /> Mapel aktif</label>
        <button class="tombol-utama w-full" :disabled="proses" @click="simpanMapel">{{ proses ? 'Menyimpan…' : 'Simpan' }}</button>
      </div>
    </LembarBawah>
  </div>
  </div>
</template>
