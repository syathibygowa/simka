<!-- SIMKA PRO | src/pages/prestasi/LembarPrestasi.vue | v1.0 | Tahap C: isian prestasi santri | 16/10/2026 -->
<script setup>
// Lembar isian prestasi/capaian santri (tambah atau ubah). Santri dapat dikunci (dibuka dari biodata santri) atau dipilih
// dari santri yang terlihat. Tanggal bawaan hari ini. Hak dicek server (pengasuh santri, pimpinan, admin, superadmin).
import { ref, computed, watch } from 'vue'
import { PhMagnifyingGlass, PhX, PhTrophy } from '@phosphor-icons/vue'
import { usePrestasi } from '@/stores/prestasi'
import { useSantri } from '@/stores/santri'
import { useUI } from '@/stores/ui'
import { BIDANG_PRESTASI, TINGKAT_PRESTASI } from '@/lib/prestasi'
import { hariIniISO } from '@/lib/tanggal'
import { labelRombel } from '@/lib/santri'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'

const buka = defineModel({ type: Boolean, default: false })
const props = defineProps({ data: { type: Object, default: null }, santri: { type: Object, default: null } })
const emit = defineEmits(['selesai'])
const pr = usePrestasi(); const san = useSantri(); const ui = useUI()
const f = ref({}); const pilihan = ref(null); const cari = ref(''); const proses = ref(false)

watch(buka, (v) => {
  if (!v) return
  const d = props.data
  f.value = d ? { id: d.id, tanggal: d.tanggal, bidang: d.bidang, tingkat: d.tingkat, nama_kegiatan: d.nama_kegiatan, capaian: d.capaian,
    penyelenggara: d.penyelenggara || '', keterangan: d.keterangan || '', masuk_rapor: d.masuk_rapor !== false }
    : { tanggal: hariIniISO(), bidang: 'tahfizh', tingkat: 'pondok', nama_kegiatan: '', capaian: '', penyelenggara: '', keterangan: '', masuk_rapor: true }
  pilihan.value = props.santri || (d ? { id: d.student_id, nama_lengkap: d.nama, nis: d.nis } : null); cari.value = ''
  if (!props.santri && !d) san.muat()
})
const hasil = computed(() => {
  const q = cari.value.toLowerCase().trim(); if (q.length < 2) return []
  return san.daftar.filter((s) => s.status === 'aktif' && `${s.nama_lengkap} ${s.nis}`.toLowerCase().includes(q)).slice(0, 8)
})
async function simpan() {
  if (!pilihan.value) return ui.toast('Pilih santri terlebih dahulu.', 'galat')
  if (f.value.nama_kegiatan.trim().length < 3) return ui.toast('Isi nama kegiatan/lomba (minimal 3 huruf).', 'galat')
  if (f.value.capaian.trim().length < 2) return ui.toast('Isi capaian, misalnya Juara 1 atau Hafal 5 juz.', 'galat')
  proses.value = true
  try {
    await pr.simpan({ ...f.value, student_id: pilihan.value.id })
    ui.toast(f.value.id ? 'Prestasi diperbarui.' : 'Prestasi dicatat. Pengasuh santri mendapat notifikasi.')
    buka.value = false; emit('selesai')
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <LembarBawah v-model="buka" :judul="f.id ? 'Ubah prestasi santri' : 'Catat prestasi santri'">
    <div class="space-y-4 pb-2">
      <div>
        <p class="label-isian">Santri <span class="text-merah">*</span></p>
        <div v-if="pilihan" class="w-santri flex items-center gap-3 rounded-2xl border border-garis p-3">
          <span class="chip-ikon h-10 w-10 shrink-0"><PhTrophy :size="22" weight="duotone" /></span>
          <span class="min-w-0 flex-1"><b class="block truncate">{{ pilihan.nama_lengkap }}</b><span class="text-xs text-teks3">NIS {{ pilihan.nis }}{{ pilihan.jenjang ? ' · ' + labelRombel(pilihan) : '' }}</span></span>
          <button v-if="!santri && !f.id" type="button" class="tombol-ikon" aria-label="Ganti santri" @click="pilihan = null"><PhX :size="20" /></button>
        </div>
        <template v-else>
          <div class="relative"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-teks3" />
            <input v-model="cari" type="search" class="isian pl-10" placeholder="Ketik nama atau NIS santri (min. 2 huruf)" aria-label="Cari santri" /></div>
          <ul v-if="hasil.length" class="mt-1 divide-y divide-garis rounded-2xl border border-garis">
            <li v-for="s in hasil" :key="s.id"><button type="button" class="flex min-h-[48px] w-full items-center gap-2 px-3 text-left hover:bg-permukaan2" @click="pilihan = s">
              <span class="min-w-0 flex-1"><b class="block truncate text-sm">{{ s.nama_lengkap }}</b><span class="text-xs text-teks3">{{ s.nis }} · {{ labelRombel(s) }}</span></span></button></li>
          </ul>
        </template>
      </div>
      <InputTanggal v-model="f.tanggal" label="Tanggal prestasi" wajib />
      <div><p class="label-isian">Bidang</p>
        <div class="flex flex-wrap gap-1.5">
          <button v-for="(b, k) in BIDANG_PRESTASI" :key="k" type="button" :aria-pressed="f.bidang === k" @click="f.bidang = k"
            :class="['min-h-[40px] rounded-xl border-2 px-3 text-sm font-semibold', 'w-' + b.w, f.bidang === k ? 'text-teks' : 'border-garis text-teks2']"
            :style="f.bidang === k ? 'border-color: var(--c); background: color-mix(in srgb, var(--c) 16%, transparent)' : ''">{{ b.n }}</button>
        </div></div>
      <div class="grid gap-3 sm:grid-cols-2">
        <div><label class="label-isian" for="pr-tingkat">Tingkat</label>
          <select id="pr-tingkat" v-model="f.tingkat" class="isian"><option v-for="(n, k) in TINGKAT_PRESTASI" :key="k" :value="k">{{ n }}</option></select></div>
        <div><label class="label-isian" for="pr-capaian">Capaian <span class="text-merah">*</span></label>
          <input id="pr-capaian" v-model="f.capaian" class="isian" placeholder="Juara 1, Medali emas, Hafal 10 juz" /></div>
      </div>
      <div><label class="label-isian" for="pr-kegiatan">Nama kegiatan/lomba <span class="text-merah">*</span></label>
        <input id="pr-kegiatan" v-model="f.nama_kegiatan" class="isian" placeholder="Contoh: MTQ Cabang Tahfizh 5 Juz" /></div>
      <div><label class="label-isian" for="pr-penyelenggara">Penyelenggara</label>
        <input id="pr-penyelenggara" v-model="f.penyelenggara" class="isian" placeholder="Contoh: LPTQ Kabupaten Gowa" /></div>
      <div><label class="label-isian" for="pr-ket">Keterangan</label>
        <textarea id="pr-ket" v-model="f.keterangan" class="isian min-h-[70px]" rows="2" placeholder="Opsional" /></div>
      <label class="flex min-h-[44px] items-center gap-3 rounded-xl bg-permukaan2 px-3 text-sm font-semibold">
        <input v-model="f.masuk_rapor" type="checkbox" class="h-5 w-5 accent-[#0B6B57]" /> Tampilkan di rapor semester</label>
      <button class="tombol-utama w-full" :disabled="proses" @click="simpan">{{ proses ? 'Menyimpan…' : f.id ? 'Simpan perubahan' : 'Catat prestasi' }}</button>
    </div>
  </LembarBawah>
</template>
