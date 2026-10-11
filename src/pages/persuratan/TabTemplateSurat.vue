<!-- SIMKA PRO | src/pages/persuratan/TabTemplateSurat.vue | v1.0 | Fase 10 – Tahap 2 Template surat dan surat keluar | 11/10/2026 -->
<script setup>
// Daftar template surat per kategori (Umum, Kepegawaian, Kesantrian). Tata Usaha dapat mengubah, menyalin, membuat baru,
// menonaktifkan/mengaktifkan, dan menghapus (template yang sudah dipakai atau isi awal hanya dinonaktifkan).
import { ref, computed, onMounted } from 'vue'
import { PhPlus, PhPencilSimple, PhCopy, PhTrash, PhEye, PhEyeSlash, PhMagnifyingGlass } from '@phosphor-icons/vue'
import { usePersuratan } from '@/stores/persuratan'
import { useUI } from '@/stores/ui'
import { KATEGORI_TEMPLATE } from '@/lib/suratKeluar'
import LembarTemplate from './LembarTemplate.vue'

const ps = usePersuratan(); const ui = useUI()
const cari = ref(''); const lembar = ref(false); const pilih = ref(null); const salin = ref(false)
onMounted(() => ps.muatTemplat().catch((e) => ui.toast(e.message, 'galat')))
const grup = computed(() => { const q = cari.value.toLowerCase().trim()
  return Object.entries(KATEGORI_TEMPLATE).map(([k, v]) => ({ k, ...v, isi: ps.templat.filter((x) => x.kategori === k && (!q || `${x.nama} ${x.kode} ${x.perihal_kode}`.toLowerCase().includes(q))) })).filter((g) => g.isi.length) })
function buka(x = null, s = false) { pilih.value = x; salin.value = s; lembar.value = true }
async function alihAktif(x) {
  try { await ps.simpanTemplat({ ...x, aktif: !x.aktif }); ui.toast(x.aktif ? `${x.nama} dinonaktifkan.` : `${x.nama} diaktifkan.`) } catch (e) { ui.toast(e.message, 'galat') }
}
async function hapus(x) {
  if (!(await ui.konfirmasi({ judul: 'Hapus template?', pesan: `${x.nama} akan dihapus. Template isi awal atau yang sudah dipakai hanya dinonaktifkan.`, ya: 'Hapus' }))) return
  try { const h = await ps.hapusTemplat(x.id); ui.toast(h === 'hapus' ? 'Template dihapus.' : 'Template dinonaktifkan karena sudah dipakai atau termasuk isi awal.') } catch (e) { ui.toast(e.message, 'galat') }
}
</script>
<template>
  <div>
    <div class="flex flex-wrap items-center gap-2">
      <div class="relative min-w-[200px] flex-1"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
        <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari template" aria-label="Cari template" /></div>
      <button v-if="ps.hak.kelola" class="tombol-utama" @click="buka()"><PhPlus :size="20" weight="bold" /> Template baru</button>
    </div>
    <section v-for="g in grup" :key="g.k" class="mt-5">
      <h2 class="judul-bagian mb-2">{{ g.n }} <span class="text-sm font-normal text-teks3">({{ g.isi.length }})</span></h2>
      <ul class="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
        <li v-for="x in g.isi" :key="x.id" :class="['kartu p-4', 'w-' + g.w, !x.aktif && 'opacity-60']">
          <div class="flex items-start gap-3">
            <span class="chip-ikon h-11 w-11 text-xs font-extrabold">{{ x.perihal_kode }}</span>
            <div class="min-w-0 flex-1">
              <p class="font-bold leading-snug">{{ x.nama }}</p>
              <p class="text-xs text-teks3"><span class="font-mono">{{ x.kode }}</span> · {{ x.format_nomor === 'sk' ? 'Nomor SK' : x.dk === 'K' ? 'Khariji' : 'Dakhily' }} · {{ (x.isian || []).length }} isian</p>
              <p class="mt-1 flex flex-wrap gap-1"><span v-if="x.bawaan" class="lencana w-hakakses">Isi awal</span><span v-if="!x.aktif" class="lencana w-sistem">Nonaktif</span></p>
            </div>
          </div>
          <div v-if="ps.hak.kelola" class="mt-3 flex flex-wrap gap-1.5">
            <button class="tombol-garis min-h-[36px] px-3 text-sm" @click="buka(x)"><PhPencilSimple :size="16" /> Ubah</button>
            <button class="tombol-garis min-h-[36px] px-3 text-sm" @click="buka(x, true)"><PhCopy :size="16" /> Salin</button>
            <button class="tombol-ikon h-9 w-9" :aria-label="x.aktif ? `Nonaktifkan ${x.nama}` : `Aktifkan ${x.nama}`" @click="alihAktif(x)"><component :is="x.aktif ? PhEyeSlash : PhEye" :size="18" /></button>
            <button class="tombol-ikon h-9 w-9 text-merah" :aria-label="`Hapus ${x.nama}`" @click="hapus(x)"><PhTrash :size="18" /></button>
          </div>
        </li>
      </ul>
    </section>
    <p v-if="!grup.length" class="kartu mt-4 p-8 text-center text-sm text-teks3">Belum ada template.</p>
    <LembarTemplate v-model="lembar" :templat="pilih" :salin="salin" />
  </div>
</template>
