<!-- SIMKA PRO | src/pages/kelompoksantri/LembarKelompok.vue | v1.2 | Perbaikan 13.7.1: pilihan kategori ekskul (Indoor/Outdoor) saat tambah/ubah ekskul | 16/10/2026 -->
<script setup>
// v1.1: putra/putri wajib bila pemisahan putra/putri aktif untuk jenis kelompok ini (pengaturan admin); selain itu boleh campuran.
// v1.2: kelompok berjenis ekskul memiliki pilihan kategori Indoor/Outdoor (dipakai sebagai kelompok dan saringan di menu Ekskul).
// Lembar tambah/ubah kelompok santri: nama, tingkat (kelas), putra/putri, keterangan, tautan grup WA, urutan, aktif.
import { ref, watch, computed } from 'vue'
import { PhFloppyDisk, PhWhatsappLogo } from '@phosphor-icons/vue'
import { useKelompokSantri } from '@/stores/kelompokSantri'
import { useUI } from '@/stores/ui'
import { JENIS_KELOMPOK } from '@/lib/santri'
import { KATEGORI_EKSKUL } from '@/lib/ekskul'
import LembarBawah from '@/components/LembarBawah.vue'

const buka = defineModel({ type: Boolean, default: false })
const props = defineProps({ kelompok: { type: Object, default: null }, jenis: { type: String, default: 'kelas' } })
const emit = defineEmits(['tersimpan'])
const kel = useKelompokSantri(); const ui = useUI()
const f = ref(null); const proses = ref(false)

watch(buka, (v) => {
  if (!v) return
  kel.muatPengaturan().catch(() => {})
  const g = props.kelompok
  f.value = g ? { id: g.id, jenis: g.jenis, nama: g.nama, tingkat: g.tingkat || '', jenis_kelamin: g.jenis_kelamin || '', keterangan: g.keterangan || '',
    wa_wali: g.wa_wali || '', wa_internal: g.wa_internal || '', urutan: g.urutan || 0, aktif: g.aktif, naqib_id: g.naqib_id || '', kategori_ekskul: g.kategori_ekskul || '' }
    : { jenis: props.jenis, nama: '', tingkat: props.jenis === 'kelas' ? 7 : '', jenis_kelamin: '', keterangan: '', wa_wali: '', wa_internal: '', urutan: 0, aktif: true, kategori_ekskul: '' }
})
const wajibJK = computed(() => !!f.value && kel.pisahJk(f.value.jenis))
async function simpan() {
  const d = f.value
  if (!d.nama.trim()) return ui.toast('Nama kelompok wajib diisi.', 'galat')
  if (wajibJK.value && !d.jenis_kelamin) return ui.toast(`${JENIS_KELOMPOK[d.jenis].n} wajib ditentukan putra atau putri (pemisahan putra/putri aktif).`, 'galat')
  for (const t of [d.wa_wali, d.wa_internal]) if (t && !/^https?:\/\//i.test(t.trim())) return ui.toast('Tautan grup WA harus diawali https:// (salin dari "Undang via tautan" di WhatsApp).', 'galat')
  proses.value = true
  try {
    const { kategori_ekskul, ...isi } = d
    const id = await kel.simpan({ ...isi, tingkat: d.jenis === 'kelas' ? Number(d.tingkat) : null, ...(d.jenis === 'ekskul' ? { kategori_ekskul: kategori_ekskul || null } : {}) })
    ui.toast(d.id ? 'Perubahan kelompok disimpan.' : `${JENIS_KELOMPOK[d.jenis].n} ${d.nama.trim()} ditambahkan.`)
    buka.value = false; emit('tersimpan', id)
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <LembarBawah v-model="buka" :judul="f?.id ? `Ubah ${JENIS_KELOMPOK[f.jenis].n.toLowerCase()}` : `Tambah ${JENIS_KELOMPOK[f?.jenis || jenis].n.toLowerCase()}`">
    <form v-if="f" class="space-y-4 pb-2" novalidate @submit.prevent="simpan">
      <div><label class="label-isian" for="kl-nama">Nama {{ JENIS_KELOMPOK[f.jenis].n.toLowerCase() }} <span class="text-merah">*</span></label>
        <input id="kl-nama" v-model="f.nama" class="isian" :placeholder="JENIS_KELOMPOK[f.jenis].contoh" /></div>
      <div v-if="f.jenis === 'kelas'"><p class="label-isian">Tingkat <span class="text-merah">*</span></p>
        <div class="grid grid-cols-6 gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" aria-label="Tingkat kelas">
          <button v-for="t in [7, 8, 9, 10, 11, 12]" :key="t" type="button" role="radio" :aria-checked="Number(f.tingkat) === t" @click="f.tingkat = t"
            :class="['min-h-[44px] rounded-xl text-sm font-semibold tabular-nums', Number(f.tingkat) === t ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">{{ t }}</button>
        </div>
        <p class="mt-1 text-xs text-teks3">7–9 Kesetaraan Wustha, 10–12 SMA. Hanya santri dengan kelas yang sama yang dapat dimasukkan.</p></div>
      <div v-if="f.jenis === 'ekskul'"><p class="label-isian">Kategori ekskul</p>
        <div class="grid grid-cols-3 gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" aria-label="Kategori ekskul">
          <button v-for="k in [...Object.entries(KATEGORI_EKSKUL).map(([k, v]) => ({ k, ...v })), { k: '', n: 'Belum diatur' }]" :key="k.k" type="button" role="radio"
            :aria-checked="f.kategori_ekskul === k.k" @click="f.kategori_ekskul = k.k"
            :class="['flex min-h-[44px] items-center justify-center gap-1.5 rounded-xl text-sm font-semibold', k.w && 'w-' + k.w, f.kategori_ekskul === k.k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">
            <component :is="k.ikon" v-if="k.ikon" :size="18" weight="duotone" style="color: var(--c)" />{{ k.n }}</button>
        </div>
        <p class="mt-1 text-xs text-teks3">{{ f.kategori_ekskul ? KATEGORI_EKSKUL[f.kategori_ekskul].ket : 'Ekskul tanpa kategori tampil di kelompok "Belum diatur" pada menu Ekskul.' }}</p></div>
      <div><p class="label-isian">Santri <span v-if="wajibJK" class="text-merah">*</span></p>
        <div class="grid grid-cols-3 gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" aria-label="Jenis kelamin anggota">
          <button v-for="j in [{ k: 'L', n: 'Putra' }, { k: 'P', n: 'Putri' }, ...(wajibJK ? [] : [{ k: '', n: 'Campuran' }])]" :key="j.k" type="button" role="radio"
            :aria-checked="f.jenis_kelamin === j.k" @click="f.jenis_kelamin = j.k"
            :class="['min-h-[44px] rounded-xl text-sm font-semibold', f.jenis_kelamin === j.k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">{{ j.n }}</button>
        </div></div>
      <div><label class="label-isian" for="kl-ket">Keterangan</label>
        <input id="kl-ket" v-model="f.keterangan" class="isian" :placeholder="f.jenis === 'ekskul' ? 'Contoh: Selasa dan Kamis sore, lapangan' : 'Contoh: Asrama Putra 1, lantai 2'" /></div>
      <div class="w-presensi rounded-2xl border border-garis p-3">
        <p class="mb-2 flex items-center gap-1.5 text-sm font-bold" style="color: var(--c)"><PhWhatsappLogo :size="18" weight="duotone" /> Grup WhatsApp</p>
        <div class="space-y-3">
          <div><label class="label-isian" for="kl-waw">Tautan grup wali santri</label><input id="kl-waw" v-model="f.wa_wali" class="isian" inputmode="url" placeholder="https://chat.whatsapp.com/…" /></div>
          <div><label class="label-isian" for="kl-wai">Tautan grup internal pengasuh</label><input id="kl-wai" v-model="f.wa_internal" class="isian" inputmode="url" placeholder="https://chat.whatsapp.com/…" /></div>
        </div>
      </div>
      <div class="grid grid-cols-2 gap-3">
        <div><label class="label-isian" for="kl-urut">Urutan tampil</label><input id="kl-urut" v-model.number="f.urutan" type="number" class="isian" /></div>
        <label v-if="f.id" class="flex min-h-[44px] items-end gap-2 pb-2 text-sm font-semibold"><input v-model="f.aktif" type="checkbox" class="h-5 w-5 accent-[#0B7F81]" /> Kelompok aktif</label>
      </div>
      <button class="tombol-utama w-full" :disabled="proses"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses ? 'Menyimpan…' : 'Simpan' }}</button>
    </form>
  </LembarBawah>
</template>
