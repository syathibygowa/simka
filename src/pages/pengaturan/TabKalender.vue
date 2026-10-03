<!-- SIMKA PRO | src/pages/pengaturan/TabKalender.vue | v1.0 | Fase 1 – Pengaturan | 03/10/2026 -->
<script setup>
import { ref, computed, onMounted } from 'vue'
import { PhPlus, PhCheckCircle, PhPencilSimple, PhTrash, PhCalendarPlus, PhFloppyDisk } from '@phosphor-icons/vue'
import { useLembaga } from '@/stores/lembaga'
import { useUI } from '@/stores/ui'
import { formatPendek, formatPanjang, formatHijriah, hariIniISO, HARI } from '@/lib/tanggal'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'

const lembaga = useLembaga(); const ui = useUI()
const galat = (e) => ui.toast(e.message, 'galat')

// ---------- Tahun ajaran ----------
const lembarTahun = ref(false)
const fTahun = ref({})
function bukaTahun(t = null) {
  const y = new Date().getFullYear()
  fTahun.value = t ? { ...t } : { _baru: true, nama: `${y}/${y + 1}`, mulai: '', selesai: '', semester: 1, aktif: false }
  lembarTahun.value = true
}
async function simpanTahun() {
  const t = fTahun.value
  if (!/^\d{4}\/\d{4}$/.test(t.nama || '')) return ui.toast('Nama tahun ajaran ditulis seperti 2026/2027.', 'galat')
  if (!t.mulai || !t.selesai || t.selesai <= t.mulai) return ui.toast('Tanggal selesai harus setelah tanggal mulai.', 'galat')
  try {
    await lembaga.simpanBaris('academic_years', { id: t.id, nama: t.nama, mulai: t.mulai, selesai: t.selesai, semester: Number(t.semester) }, { baru: !!t._baru })
    lembarTahun.value = false; ui.toast(`Tahun ajaran ${t.nama} disimpan.`)
  } catch (e) { galat(e) }
}
async function aktifkan(t) {
  if (!(await ui.konfirmasi({ judul: `Aktifkan ${t.nama}?`, pesan: 'Tahun ajaran aktif yang lama akan dinonaktifkan. Data tahun lama tetap tersimpan.', ya: 'Aktifkan' }))) return
  try { await lembaga.aktifkanTahun(t.id); ui.toast(`Tahun ajaran ${t.nama} kini aktif.`) } catch (e) { galat(e) }
}
async function gantiSemester(t, s) {
  try { await lembaga.simpanBaris('academic_years', { id: t.id, semester: s }); ui.toast(`Semester ${s === 1 ? 'ganjil' : 'genap'} aktif.`) } catch (e) { galat(e) }
}

// ---------- Libur pekanan per jenis tugas ----------
async function ubahHari(k, hari) {
  const set = new Set(k.hari_libur || [])
  set.has(hari) ? set.delete(hari) : set.add(hari)
  const hari_libur = [...set].sort()
  try { await lembaga.simpanBaris('holiday_calendars', { jenis_tugas: k.jenis_tugas, hari_libur }, { pk: 'jenis_tugas' }); ui.toast(`Libur pekanan ${k.nama} diperbarui.`) }
  catch (e) { galat(e) }
}

// ---------- Hari libur ----------
const JENIS_LIBUR = { libur_bulanan: 'Libur bulanan', libur_pondok: 'Libur pondok', libur_sekolah: 'Libur sekolah', libur_nasional: 'Libur nasional', tanpa_sesi: 'Hari tanpa sesi' }
const lembarLibur = ref(false)
const fLibur = ref({})
const liburUrut = computed(() => [...lembaga.holidays].sort((a, b) => b.tanggal_mulai.localeCompare(a.tanggal_mulai)))
function bukaLibur() {
  fLibur.value = { nama: '', tanggal_mulai: hariIniISO(), tanggal_akhir: hariIniISO(), jenis: 'libur_pondok', berlaku_untuk: ['semua'] }
  lembarLibur.value = true
}
function ubahBerlaku(k) {
  let b = new Set(fLibur.value.berlaku_untuk)
  if (k === 'semua') b = new Set(['semua'])
  else { b.delete('semua'); b.has(k) ? b.delete(k) : b.add(k); if (!b.size) b.add('semua') }
  fLibur.value.berlaku_untuk = [...b]
}
async function simpanLibur() {
  const l = fLibur.value
  if (!l.nama?.trim()) return ui.toast('Nama hari libur wajib diisi.', 'galat')
  if (l.tanggal_akhir < l.tanggal_mulai) return ui.toast('Tanggal akhir tidak boleh sebelum tanggal mulai.', 'galat')
  try { await lembaga.simpanBaris('holidays', l, { baru: true }); lembarLibur.value = false; ui.toast(`${l.nama} ditambahkan.`) } catch (e) { galat(e) }
}
async function hapusLibur(l) {
  if (!(await ui.konfirmasi({ judul: 'Hapus hari libur?', pesan: `${l.nama} (${formatPendek(l.tanggal_mulai)}) akan dihapus.`, ya: 'Hapus', bahaya: true }))) return
  try { await lembaga.hapusBaris('holidays', l.id); ui.toast('Hari libur dihapus.') } catch (e) { galat(e) }
}

// ---------- Koreksi Hijriah ----------
const koreksi = ref(Number(lembaga.hijriah?.koreksi_hari || 0))
const hijriahServer = ref('')
onMounted(async () => { hijriahServer.value = await lembaga.hijriahServer(hariIniISO()) })
async function simpanKoreksi() {
  try {
    await lembaga.simpanPengaturan('hijriah', { ...lembaga.hijriah, koreksi_hari: Number(koreksi.value) })
    hijriahServer.value = await lembaga.hijriahServer(hariIniISO())
    ui.toast('Koreksi tanggal Hijriah disimpan.')
  } catch (e) { galat(e) }
}
</script>
<template>
  <div class="space-y-5">
    <!-- Tahun ajaran -->
    <section class="kartu p-5">
      <div class="mb-3 flex flex-wrap items-center justify-between gap-2">
        <div><h3 class="judul-bagian">Tahun ajaran</h3><p class="text-sm text-teks3">Hanya satu tahun ajaran yang aktif.</p></div>
        <button class="tombol-garis" @click="bukaTahun()"><PhPlus :size="18" weight="bold" /> Tambah tahun ajaran</button>
      </div>
      <ul class="space-y-2">
        <li v-for="t in lembaga.academic_years" :key="t.id" :class="['flex flex-wrap items-center gap-3 rounded-xl border p-3', t.aktif ? 'border-transparent bg-permukaan2' : 'border-garis']">
          <div class="min-w-[180px] flex-1">
            <p class="font-bold">{{ t.nama }} <span v-if="t.aktif" class="lencana w-presensi ml-1"><PhCheckCircle :size="12" weight="fill" /> Aktif</span></p>
            <p class="text-sm text-teks3">{{ formatPendek(t.mulai) }} sampai {{ formatPendek(t.selesai) }}</p>
          </div>
          <div v-if="t.aktif" class="flex rounded-full bg-permukaan p-1" role="radiogroup" aria-label="Semester aktif">
            <button v-for="s in [1, 2]" :key="s" role="radio" :aria-checked="t.semester === s" @click="gantiSemester(t, s)"
              :class="['min-h-[36px] rounded-full px-3 text-sm font-semibold', t.semester === s ? 'bg-[#C7332F] text-white' : 'text-teks2']">{{ s === 1 ? 'Ganjil' : 'Genap' }}</button>
          </div>
          <button v-else class="tombol-teks text-sm" @click="aktifkan(t)">Jadikan aktif</button>
          <button class="tombol-ikon" @click="bukaTahun(t)" :aria-label="`Ubah ${t.nama}`"><PhPencilSimple :size="20" /></button>
        </li>
      </ul>
    </section>

    <!-- Libur pekanan -->
    <section class="kartu p-5">
      <h3 class="judul-bagian">Libur pekanan per jenis tugas</h3>
      <p class="mb-3 text-sm text-teks3">Ketuk nama hari untuk menandai hari libur. Dipakai saat menghitung sesi presensi wajib.</p>
      <div class="space-y-3">
        <div v-for="k in lembaga.holiday_calendars" :key="k.jenis_tugas" class="flex flex-wrap items-center gap-x-4 gap-y-2">
          <div class="w-full sm:w-56"><p class="font-semibold">{{ k.nama }}</p><p class="text-xs text-teks3">{{ k.catatan }}</p></div>
          <div class="flex flex-wrap gap-1.5">
            <button v-for="(h, i) in HARI" :key="h" @click="ubahHari(k, i)" :aria-pressed="(k.hari_libur || []).includes(i)"
              :class="['min-h-[36px] rounded-full border px-3 text-xs font-semibold', (k.hari_libur || []).includes(i) ? 'border-transparent bg-[#B42A5E] text-white' : 'border-garis text-teks2 hover:text-teks']">{{ h }}</button>
          </div>
        </div>
      </div>
    </section>

    <!-- Hari libur -->
    <section class="kartu p-5">
      <div class="mb-3 flex flex-wrap items-center justify-between gap-2">
        <div><h3 class="judul-bagian">Hari libur dan hari tanpa sesi</h3><p class="text-sm text-teks3">Libur bulanan, libur pondok, libur sekolah, dan libur nasional.</p></div>
        <button class="tombol-garis" @click="bukaLibur"><PhCalendarPlus :size="18" weight="duotone" /> Tambah hari libur</button>
      </div>
      <ul v-if="liburUrut.length" class="divide-y divide-garis">
        <li v-for="l in liburUrut" :key="l.id" class="flex items-center gap-3 py-2.5">
          <div class="flex-1">
            <p class="font-semibold">{{ l.nama }}</p>
            <p class="text-sm text-teks3">{{ formatPanjang(l.tanggal_mulai) }}<template v-if="l.tanggal_akhir !== l.tanggal_mulai"> sampai {{ formatPanjang(l.tanggal_akhir) }}</template>
              – {{ JENIS_LIBUR[l.jenis] }}, berlaku untuk {{ (l.berlaku_untuk || []).includes('semua') ? 'semua' : l.berlaku_untuk.join(', ') }}</p>
          </div>
          <button class="tombol-ikon" @click="hapusLibur(l)" :aria-label="`Hapus ${l.nama}`"><PhTrash :size="20" /></button>
        </li>
      </ul>
      <p v-else class="py-4 text-center text-sm text-teks3">Belum ada hari libur yang dicatat.</p>
    </section>

    <!-- Koreksi Hijriah -->
    <section class="kartu p-5">
      <h3 class="judul-bagian">Tanggal Hijriah pada surat</h3>
      <p class="mb-3 text-sm text-teks3">Bila tanggal Hijriah berbeda dengan penetapan, geser beberapa hari di sini.</p>
      <div class="flex flex-wrap items-end gap-3">
        <div>
          <label class="label-isian" for="koreksi">Koreksi hari</label>
          <select id="koreksi" v-model.number="koreksi" class="isian w-40">
            <option v-for="n in [-2, -1, 0, 1, 2]" :key="n" :value="n">{{ n > 0 ? '+' + n : n }} hari</option>
          </select>
        </div>
        <div class="flex-1 text-sm">
          <p class="text-teks3">Hari ini ({{ formatPanjang(hariIniISO()) }})</p>
          <p class="font-bold">{{ hijriahServer || formatHijriah(new Date(), koreksi) }}</p>
        </div>
        <button class="tombol-utama" @click="simpanKoreksi"><PhFloppyDisk :size="20" weight="duotone" /> Simpan</button>
      </div>
    </section>

    <LembarBawah v-model="lembarTahun" :judul="fTahun._baru ? 'Tambah tahun ajaran' : 'Ubah tahun ajaran'">
      <div class="space-y-4 pb-2">
        <div><label class="label-isian" for="th-nama">Nama tahun ajaran</label><input id="th-nama" v-model="fTahun.nama" class="isian" placeholder="2026/2027" /></div>
        <InputTanggal v-model="fTahun.mulai" label="Tanggal mulai" wajib />
        <InputTanggal v-model="fTahun.selesai" label="Tanggal selesai" wajib />
        <div><label class="label-isian" for="th-sem">Semester</label>
          <select id="th-sem" v-model.number="fTahun.semester" class="isian"><option :value="1">Ganjil</option><option :value="2">Genap</option></select></div>
        <button class="tombol-utama w-full" @click="simpanTahun"><PhFloppyDisk :size="20" weight="duotone" /> Simpan</button>
      </div>
    </LembarBawah>

    <LembarBawah v-model="lembarLibur" judul="Tambah hari libur">
      <div class="space-y-4 pb-2">
        <div><label class="label-isian" for="lb-nama">Nama</label><input id="lb-nama" v-model="fLibur.nama" class="isian" placeholder="Contoh: Libur akhir semester" /></div>
        <div class="grid gap-4 sm:grid-cols-2">
          <InputTanggal v-model="fLibur.tanggal_mulai" label="Tanggal mulai" wajib />
          <InputTanggal v-model="fLibur.tanggal_akhir" label="Tanggal akhir" wajib />
        </div>
        <div><label class="label-isian" for="lb-jenis">Jenis</label>
          <select id="lb-jenis" v-model="fLibur.jenis" class="isian"><option v-for="(n, k) in JENIS_LIBUR" :key="k" :value="k">{{ n }}</option></select></div>
        <div>
          <p class="label-isian">Berlaku untuk</p>
          <div class="flex flex-wrap gap-1.5">
            <button v-for="k in ['semua', ...lembaga.holiday_calendars.map((x) => x.jenis_tugas)]" :key="k" type="button" @click="ubahBerlaku(k)"
              :class="['min-h-[36px] rounded-full border px-3 text-sm font-semibold', fLibur.berlaku_untuk?.includes(k) ? 'border-transparent bg-[#C7332F] text-white' : 'border-garis text-teks2']">
              {{ k === 'semua' ? 'Semua' : lembaga.holiday_calendars.find((x) => x.jenis_tugas === k)?.nama }}</button>
          </div>
        </div>
        <button class="tombol-utama w-full" @click="simpanLibur"><PhFloppyDisk :size="20" weight="duotone" /> Simpan</button>
      </div>
    </LembarBawah>
  </div>
</template>
