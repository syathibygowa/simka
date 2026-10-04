<!-- SIMKA PRO | src/pages/jurnal/TabTemplateJurnal.vue | v1.0 | Fase 3 – Tahap 3 Jurnal harian | 04/10/2026 -->
<script setup>
// Template ceklist jurnal (admin ber-izin atur_jurnal dan superadmin): butir per jabatan fungsional, jabatan
// struktural, bidang/unit (berlaku juga untuk unit di bawahnya), atau semua pegawai. Pegawai rangkap jabatan
// otomatis mendapat ceklist gabungan.
import { ref, computed, onMounted } from 'vue'
import { PhPlus, PhPencilSimple, PhTrash, PhArrowUp, PhArrowDown, PhEye, PhEyeSlash, PhFloppyDisk } from '@phosphor-icons/vue'
import { useJurnal } from '@/stores/jurnal'
import { useOrganisasi } from '@/stores/organisasi'
import { useUI } from '@/stores/ui'
import LembarBawah from '@/components/LembarBawah.vue'

const jr = useJurnal(); const org = useOrganisasi(); const ui = useUI()
const grup = ref('semua'); const fb = ref(null)
onMounted(async () => { await org.muat(); try { await jr.muatTemplate() } catch (e) { ui.toast(e.message, 'galat') } })

const kunciButir = (b) => (b.functional_position_id ? 'f:' + b.functional_position_id : b.structural_position_id ? 's:' + b.structural_position_id : b.org_unit_id ? 'u:' + b.org_unit_id : 'semua')
const GRUP = computed(() => [
  { k: 'semua', n: 'Semua pegawai', g: 'Umum' },
  ...org.fungsional.map((f) => ({ k: 'f:' + f.id, n: f.nama, g: 'Jabatan fungsional' })),
  ...org.struktural.map((s) => ({ k: 's:' + s.id, n: s.nama, g: 'Jabatan struktural' })),
  ...org.datar.map((u) => ({ k: 'u:' + u.id, n: '— '.repeat(u.tingkat) + u.nama, g: 'Bidang/unit' })),
])
const jumlah = (k) => jr.butirTemplate.filter((b) => kunciButir(b) === k).length
const butir = computed(() => jr.butirTemplate.filter((b) => kunciButir(b) === grup.value).sort((a, b) => a.urutan - b.urutan))
const namaGrup = computed(() => GRUP.value.find((g) => g.k === grup.value)?.n.replace(/^(— )+/, '') || '')

function sasaran(k) {
  const [t, id] = k.split(':')
  return { functional_position_id: t === 'f' ? id : null, structural_position_id: t === 's' ? id : null, org_unit_id: t === 'u' ? id : null }
}
function tambah() { fb.value = { ...sasaran(grup.value), uraian: '', urutan: (butir.value.at(-1)?.urutan || 0) + 1, aktif: true } }
async function simpan() {
  if (fb.value.uraian.trim().length < 3) return ui.toast('Uraian butir minimal 3 karakter.', 'galat')
  try { await jr.simpanButir(fb.value); fb.value = null; ui.toast('Butir ceklist disimpan.', 'info') } catch (e) { ui.toast(e.message, 'galat') }
}
async function ubahCepat(b, patch) { try { await jr.simpanButir({ ...b, ...patch }) } catch (e) { ui.toast(e.message, 'galat') } }
async function pindah(i, arah) {
  const a = butir.value[i]; const b = butir.value[i + arah]; if (!b) return
  const ua = a.urutan; const ub = b.urutan === ua ? ua + arah : b.urutan
  await ubahCepat(a, { urutan: ub }); await ubahCepat(b, { urutan: ua })
}
async function hapus(b) {
  if (!(await ui.konfirmasi({ judul: 'Hapus butir ceklist?', pesan: `${b.uraian}. Isian jurnal yang sudah tercatat tetap tersimpan. Bila hanya ingin menyembunyikan, pilih nonaktifkan.`, ya: 'Hapus', bahaya: true }))) return
  try { await jr.hapusButir(b.id); ui.toast('Butir dihapus.', 'info') } catch (e) { ui.toast(e.message, 'galat') }
}
</script>
<template>
  <div class="grid gap-4 lg:grid-cols-[18rem_1fr]">
    <aside class="kartu p-3 lg:max-h-[70vh] lg:overflow-y-auto">
      <label class="label-isian lg:hidden" for="tj-grup">Tampilkan butir untuk</label>
      <select id="tj-grup" v-model="grup" class="isian lg:hidden">
        <optgroup v-for="g in ['Umum', 'Jabatan fungsional', 'Jabatan struktural', 'Bidang/unit']" :key="g" :label="g">
          <option v-for="x in GRUP.filter((y) => y.g === g)" :key="x.k" :value="x.k">{{ x.n }} ({{ jumlah(x.k) }})</option></optgroup>
      </select>
      <div class="hidden lg:block">
        <template v-for="g in ['Umum', 'Jabatan fungsional', 'Jabatan struktural', 'Bidang/unit']" :key="g">
          <p class="mb-1 mt-2 px-2 text-xs font-bold uppercase tracking-wide text-teks3 first:mt-0">{{ g }}</p>
          <button v-for="x in GRUP.filter((y) => y.g === g)" :key="x.k" @click="grup = x.k"
            :class="['flex min-h-[40px] w-full items-center gap-2 rounded-lg px-2 text-left text-sm', grup === x.k ? 'bg-permukaan2 font-bold text-teks' : 'text-teks2 hover:bg-permukaan2']">
            <span class="flex-1 truncate">{{ x.n }}</span><span v-if="jumlah(x.k)" class="text-xs text-teks3">{{ jumlah(x.k) }}</span></button>
        </template>
      </div>
    </aside>

    <section class="kartu w-tatausaha p-4">
      <div class="mb-3 flex flex-wrap items-center gap-2">
        <div class="flex-1"><h3 class="judul-bagian">{{ namaGrup }}</h3><p class="text-sm text-teks3">{{ butir.length }} butir · pegawai rangkap jabatan mendapat ceklist gabungan</p></div>
        <button class="tombol-garis" @click="tambah"><PhPlus :size="18" weight="bold" /> Tambah butir</button>
      </div>
      <ol class="divide-y divide-garis">
        <li v-for="(b, i) in butir" :key="b.id" :class="['flex items-center gap-1 py-2', !b.aktif && 'opacity-55']">
          <span class="w-7 shrink-0 text-center text-sm font-bold text-teks3">{{ i + 1 }}</span>
          <p class="min-w-0 flex-1 text-sm">{{ b.uraian }}<span v-if="!b.aktif" class="ml-1 text-xs text-teks3">(nonaktif)</span></p>
          <button class="tombol-ikon" :aria-label="`Naikkan ${b.uraian}`" :disabled="i === 0" @click="pindah(i, -1)"><PhArrowUp :size="18" /></button>
          <button class="tombol-ikon" :aria-label="`Turunkan ${b.uraian}`" :disabled="i === butir.length - 1" @click="pindah(i, 1)"><PhArrowDown :size="18" /></button>
          <button class="tombol-ikon" :aria-label="b.aktif ? `Nonaktifkan ${b.uraian}` : `Aktifkan ${b.uraian}`" @click="ubahCepat(b, { aktif: !b.aktif })"><component :is="b.aktif ? PhEye : PhEyeSlash" :size="18" /></button>
          <button class="tombol-ikon" :aria-label="`Ubah ${b.uraian}`" @click="fb = { ...b }"><PhPencilSimple :size="18" /></button>
          <button class="tombol-ikon" :aria-label="`Hapus ${b.uraian}`" @click="hapus(b)"><PhTrash :size="18" /></button>
        </li>
        <li v-if="!butir.length" class="py-4 text-sm text-teks3">Belum ada butir. Tekan "Tambah butir" untuk membuat ceklist.</li>
      </ol>
    </section>

    <LembarBawah :model-value="!!fb" @update:model-value="(v) => !v && (fb = null)" :judul="fb?.id ? 'Ubah butir ceklist' : 'Tambah butir ceklist'">
      <form v-if="fb" class="space-y-3 pb-2" @submit.prevent="simpan">
        <p class="text-sm text-teks2">Berlaku untuk: <strong>{{ namaGrup }}</strong></p>
        <div><label class="label-isian" for="tj-uraian">Uraian butir</label>
          <textarea id="tj-uraian" v-model="fb.uraian" class="isian min-h-[4.5rem] py-2" placeholder="Contoh: Membangunkan santri untuk shalat Subuh" /></div>
        <label class="flex min-h-[44px] items-center gap-3 font-semibold"><input v-model="fb.aktif" type="checkbox" class="h-5 w-5 accent-[#7A4E2D]" /> Aktif</label>
        <button class="tombol-utama w-full"><PhFloppyDisk :size="20" weight="duotone" /> Simpan</button>
      </form>
    </LembarBawah>
  </div>
</template>
