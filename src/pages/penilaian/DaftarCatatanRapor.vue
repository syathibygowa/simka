<!-- SIMKA PRO | src/pages/penilaian/DaftarCatatanRapor.vue | v1.0 | Fase 12 – Tahap 4 Catatan rapor | 13/10/2026 -->
<script setup>
// Daftar isian catatan rapor per santri (dipakai Wali Kelas → Rapor dan Tahfizh → Rapor).
// Catatan disusun otomatis dari bank kalimat dan data santri (fungsi `susun`), bervariasi per santri, dan dapat disunting.
//   Susun yang kosong  : mengisi santri yang belum bercatatan
//   Susun ulang semua  : menyusun ulang seluruh catatan (variasi baru)
//   Susun ulang (santri): variasi baru untuk satu santri
import { ref, computed, watch } from 'vue'
import { PhMagicWand, PhArrowsClockwise, PhFloppyDisk, PhMagnifyingGlass, PhInfo, PhCheckCircle } from '@phosphor-icons/vue'
import { useUI } from '@/stores/ui'

const props = defineProps({
  santri: { type: Array, required: true },   // [{ id, nis, nama, jenis_kelamin, catatan, fakta: [{ n, w? }] }]
  boleh: { type: Boolean, default: false },
  susun: { type: Function, required: true },  // (santri, putaran) => teks
  simpan: { type: Function, required: true }, // async ([{ student_id, teks }])
  label: { type: String, default: 'Catatan' },
  kosongBank: { type: Boolean, default: false },
})
const ui = useUI()
const teks = ref({}); const ubah = ref(new Set()); const putaran = ref({}); const cari = ref(''); const proses = ref(false)
function salin() { teks.value = Object.fromEntries(props.santri.map((s) => [s.id, s.catatan || ''])); ubah.value = new Set() }
watch(() => props.santri, salin, { immediate: true })
const tampil = computed(() => { const q = cari.value.toLowerCase().trim(); return props.santri.filter((s) => !q || `${s.nama} ${s.nis}`.toLowerCase().includes(q)) })
const terisi = computed(() => props.santri.filter((s) => (teks.value[s.id] || '').trim()).length)
function set(s, v) { teks.value[s.id] = v; ubah.value = new Set([...ubah.value, s.id]) }
function susunSatu(s) { const n = (putaran.value[s.id] || 0) + 1; putaran.value[s.id] = n; set(s, props.susun(s, n)) }
function susunKosong() { let n = 0; for (const s of props.santri) if (!(teks.value[s.id] || '').trim()) { set(s, props.susun(s, putaran.value[s.id] || 0)); n++ }
  ui.toast(n ? `${n} catatan disusun. Periksa dan sunting bila perlu, lalu simpan.` : 'Semua santri sudah bercatatan.') }
async function susunSemua() {
  if (terisi.value && !(await ui.konfirmasi({ judul: 'Susun ulang semua catatan?', pesan: `${terisi.value} catatan yang sudah ada akan diganti susunan baru (belum tersimpan sampai Anda menekan Simpan).`, ya: 'Susun ulang' }))) return
  for (const s of props.santri) susunSatu(s)
}
async function simpanSemua() {
  const isi = [...ubah.value].map((id) => ({ student_id: id, teks: (teks.value[id] || '').trim() }))
  const pendek = isi.find((x) => x.teks && x.teks.length < 3); if (pendek) return ui.toast('Catatan minimal 3 huruf.', 'galat')
  const panjang = isi.find((x) => x.teks.length > 1000); if (panjang) return ui.toast('Catatan maksimal 1.000 huruf.', 'galat')
  proses.value = true
  try { await props.simpan(isi); ubah.value = new Set(); ui.toast(`${isi.length} catatan disimpan.`) } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
const jk = (s) => (s.jenis_kelamin === 'P' ? 'P' : 'L')
defineExpose({ adaUbah: () => ubah.value.size > 0 })
</script>
<template>
  <div class="space-y-3">
    <div class="kartu flex flex-wrap items-center gap-2 p-3">
      <p class="min-w-[150px] flex-1 text-sm"><b class="tabular-nums">{{ terisi }}/{{ santri.length }}</b> <span class="text-teks3">santri bercatatan</span></p>
      <div class="relative w-full sm:w-56"><PhMagnifyingGlass :size="18" class="absolute left-3 top-1/2 -translate-y-1/2 text-teks3" />
        <input v-model="cari" type="search" class="isian pl-10" placeholder="Cari santri" aria-label="Cari santri" /></div>
      <template v-if="boleh">
        <button class="tombol-utama min-h-[40px] px-3 text-sm" :disabled="kosongBank" @click="susunKosong"><PhMagicWand :size="18" weight="duotone" /> Susun yang kosong</button>
        <button class="tombol-garis min-h-[40px] px-3 text-sm" :disabled="kosongBank" @click="susunSemua"><PhArrowsClockwise :size="18" /> Susun ulang semua</button>
      </template>
    </div>
    <p v-if="kosongBank" class="flex gap-2 rounded-xl bg-permukaan2 p-3 text-sm text-teks2"><PhInfo :size="18" class="mt-0.5 shrink-0" /><span>Bank kalimat {{ label.toLowerCase() }} masih kosong. Isi di Penilaian → Kalimat rapor.</span></p>

    <ul class="space-y-3">
      <li v-for="s in tampil" :key="s.id" class="kartu p-4">
        <div class="flex flex-wrap items-start gap-2">
          <div class="min-w-0 flex-1">
            <p class="font-semibold"><span class="text-teks3 tabular-nums">{{ santri.indexOf(s) + 1 }}.</span> {{ s.nama }}
              <PhCheckCircle v-if="s.catatan && !ubah.has(s.id)" :size="14" weight="fill" class="inline" style="color: var(--c)" aria-label="tersimpan" /></p>
            <p class="text-xs text-teks3">{{ s.nis }} · {{ jk(s) }}</p>
          </div>
          <button v-if="boleh && !kosongBank" class="tombol-garis min-h-[36px] px-3 text-xs" :aria-label="`Susun ulang catatan ${s.nama}`" @click="susunSatu(s)"><PhArrowsClockwise :size="16" /> Susun ulang</button>
        </div>
        <ul v-if="s.fakta?.length" class="mt-2 flex flex-wrap gap-1.5">
          <li v-for="f in s.fakta" :key="f.n" :class="['lencana', f.w ? 'w-' + f.w : '']">{{ f.n }}</li>
        </ul>
        <textarea :value="teks[s.id]" rows="3" :disabled="!boleh" :aria-label="`${label} ${s.nama}`" maxlength="1000"
          :class="['isian mt-2 text-sm leading-relaxed', ubah.has(s.id) ? 'border-[color:var(--c)]' : '']" :placeholder="boleh ? 'Tekan Susun ulang atau tulis sendiri' : 'Belum ada catatan'"
          @input="set(s, $event.target.value)" />
        <p class="mt-1 text-right text-[11px] tabular-nums text-teks3">{{ (teks[s.id] || '').length }}/1000</p>
      </li>
    </ul>
    <p v-if="!tampil.length" class="kartu p-6 text-center text-sm text-teks3">Tidak ada santri.</p>
    <p class="text-xs text-teks3">Tulis _miring_ untuk istilah Arab (contoh: _barakallahu fiik_); tercetak miring di rapor.</p>

    <div v-if="ubah.size" class="sticky bottom-[84px] z-20 lg:bottom-4">
      <div class="kartu mx-auto flex max-w-2xl flex-wrap items-center gap-2 p-3 shadow-xl">
        <p class="flex-1 text-sm font-semibold">{{ ubah.size }} catatan belum disimpan</p>
        <button class="tombol-garis min-h-[40px] px-3 text-sm" :disabled="proses" @click="salin">Batal</button>
        <button class="tombol-utama min-h-[40px] px-3 text-sm" :disabled="proses" @click="simpanSemua"><PhFloppyDisk :size="18" weight="duotone" /> {{ proses ? 'Menyimpan…' : 'Simpan catatan' }}</button>
      </div>
    </div>
  </div>
</template>
