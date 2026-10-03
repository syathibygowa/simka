<!-- SIMKA PRO | src/pages/presensi/FormPola.vue | v1.0 | Fase 2 – Tahap 3 Pengaturan presensi | 03/10/2026 -->
<script setup>
// Lembar ubah/tambah pola tugas. Pola pribadi (employee_id terisi) dipakai untuk jadwal khusus satu pegawai.
import { ref, watch } from 'vue'
import { PhFloppyDisk, PhTrash } from '@phosphor-icons/vue'
import { useAturPresensi } from '@/stores/aturPresensi'
import { useLembaga } from '@/stores/lembaga'
import { useUI } from '@/stores/ui'
import { JENIS_POLA, WARNA_POLA } from '@/lib/presensi'
import LembarBawah from '@/components/LembarBawah.vue'

const buka = defineModel({ type: Boolean, default: false })
const props = defineProps({ pola: { type: Object, default: null }, pegawai: { type: Object, default: null } })
const emit = defineEmits(['tersimpan'])
const atur = useAturPresensi(); const lembaga = useLembaga(); const ui = useUI()
const f = ref(null); const proses = ref(false)

watch(buka, (v) => {
  if (!v) return
  if (props.pola?.id) f.value = { ...props.pola }
  else if (props.pegawai) {
    const nama = props.pegawai.nama_lengkap.replace(/^(Ust\.|Ustzh\.)\s*/, '').split(',')[0]
    f.value = { kode: ('KHUSUS_' + (props.pegawai.niy || nama.toUpperCase().replace(/[^A-Z0-9]/g, '')).replace(/[^A-Z0-9]/g, '')).slice(0, 40),
      nama: `Jadwal khusus ${nama}`, jenis: 'khusus', kalender: 'kantor', warna: 'pegawai', aktif: true, urutan: 90, catatan: '', employee_id: props.pegawai.id }
  } else f.value = { kode: '', nama: '', jenis: 'rentang', kalender: 'kantor', warna: 'presensi', aktif: true, urutan: atur.polaUmum.length + 1, catatan: '', employee_id: null }
})
async function simpan() {
  const p = f.value
  if (!p.nama?.trim()) return ui.toast('Nama pola wajib diisi.', 'galat')
  p.kode = String(p.kode || p.nama).toUpperCase().normalize('NFKD').replace(/[^A-Z0-9]+/g, '_').replace(/^_|_$/g, '').slice(0, 40)
  if (p.kode.length < 2) return ui.toast('Kode pola minimal 2 huruf.', 'galat')
  proses.value = true
  try { const d = await atur.simpanPola(p); ui.toast(`Pola ${p.nama} tersimpan.`); buka.value = false; emit('tersimpan', d) }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
async function hapus() {
  const n = atur.pemakaiPola(f.value.id)
  if (!(await ui.konfirmasi({ judul: `Hapus pola ${f.value.nama}?`, pesan: `Semua sesi pola ini ikut terhapus${n ? ` dan ${n} pegawai kehilangan jadwal dari pola ini` : ''}. Pola yang sudah memiliki data presensi tidak dapat dihapus; nonaktifkan saja.`, ya: 'Hapus', bahaya: true }))) return
  try { await atur.hapusPola(f.value.id); ui.toast('Pola dihapus.'); buka.value = false } catch (e) { ui.toast(e.message, 'galat') }
}
</script>
<template>
  <LembarBawah v-model="buka" :judul="f?.id ? `Ubah pola ${f.nama}` : f?.employee_id ? 'Jadwal khusus pegawai' : 'Tambah pola tugas'">
    <div v-if="f" class="space-y-4 pb-2">
      <div><label class="label-isian" for="pl-nama">Nama pola <span class="text-merah">*</span></label>
        <input id="pl-nama" v-model="f.nama" class="isian" placeholder="Contoh: Operator asrama" /></div>
      <div><label class="label-isian" for="pl-kode">Kode</label>
        <input id="pl-kode" v-model="f.kode" class="isian uppercase" placeholder="Dibuat otomatis dari nama" /></div>
      <div>
        <p class="label-isian">Jenis pola</p>
        <div class="grid gap-2 sm:grid-cols-2">
          <label v-for="(info, k) in JENIS_POLA" :key="k" :class="['flex cursor-pointer gap-2.5 rounded-xl border p-3', f.jenis === k ? 'border-[#C7332F] bg-[#C7332F]/5' : 'border-garis']">
            <input v-model="f.jenis" type="radio" :value="k" class="mt-1 h-4 w-4 accent-[#C7332F]" />
            <span><span class="block text-sm font-semibold">{{ info.n }}</span><span class="block text-xs text-teks3">{{ info.ket }}</span></span>
          </label>
        </div>
      </div>
      <div><label class="label-isian" for="pl-kal">Kalender libur</label>
        <select id="pl-kal" v-model="f.kalender" class="isian">
          <option :value="null">Tanpa kalender (hanya libur yang berlaku untuk semua)</option>
          <option v-for="k in lembaga.holiday_calendars" :key="k.jenis_tugas" :value="k.jenis_tugas">{{ k.nama }}</option>
        </select>
        <p class="mt-1 text-xs text-teks3">Libur pekanan dan hari libur diatur di Pengaturan → Tahun ajaran dan kalender. Pola shift mengikuti jadwal shift.</p></div>
      <div>
        <p class="label-isian">Warna</p>
        <div class="flex flex-wrap gap-2">
          <button v-for="w in WARNA_POLA" :key="w" type="button" :class="['h-10 w-10 rounded-full border-4', 'w-' + w, f.warna === w ? 'border-teks' : 'border-transparent']"
            style="background: var(--c)" :aria-label="`Warna ${w}`" :aria-pressed="f.warna === w" @click="f.warna = w" />
        </div>
      </div>
      <div><label class="label-isian" for="pl-cat">Keterangan (tidak wajib)</label><input id="pl-cat" v-model="f.catatan" class="isian" /></div>
      <label class="flex min-h-[44px] items-center gap-3 font-semibold"><input v-model="f.aktif" type="checkbox" class="h-5 w-5 accent-[#C7332F]" /> Pola aktif</label>
      <button class="tombol-utama w-full" :disabled="proses" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses ? 'Menyimpan…' : 'Simpan pola' }}</button>
      <button v-if="f.id && !f.pola_struktural" class="tombol-teks w-full" @click="hapus"><PhTrash :size="20" /> Hapus pola</button>
    </div>
  </LembarBawah>
</template>
