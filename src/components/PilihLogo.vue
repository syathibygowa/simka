<!-- SIMKA PRO | src/components/PilihLogo.vue | v1.0 | Perbaikan 13.6.0: pemilih logo dari daftar logo terpusat | 15/10/2026 -->
<script setup>
// Pilih satu logo dari Setelan → Logo. Nilai yang disimpan berupa rujukan "logo:<kode>" (ikut berubah bila gambar diganti),
// kosong (tanpa logo / bawaan pemakai), atau tautan gambar lama (tetap ditampilkan agar data lama tidak hilang).
// v-model: string · kosong: teks pilihan kosong (mis. "Tanpa logo" atau "Logo pondok (bawaan)") · label: judul isian.
import { computed } from 'vue'
import { PhProhibit, PhCheckCircle, PhGearSix } from '@phosphor-icons/vue'
import { useLembaga } from '@/stores/lembaga'
import { rujukan, kodeRujukan } from '@/lib/logo'

const nilai = defineModel({ type: String, default: '' })
defineProps({ label: { type: String, default: 'Logo' }, kosong: { type: String, default: 'Tanpa logo' }, ket: { type: String, default: '' } })
const lembaga = useLembaga()
const daftar = computed(() => lembaga.daftarLogo.filter((x) => x.url))
const kode = computed(() => kodeRujukan(nilai.value))
const tautanLama = computed(() => nilai.value && !kode.value)
</script>
<template>
  <fieldset>
    <legend class="label-isian">{{ label }}</legend>
    <div class="grid grid-cols-3 gap-2 sm:grid-cols-4 lg:grid-cols-6" role="radiogroup" :aria-label="label">
      <button type="button" role="radio" :aria-checked="!nilai" :class="['pilih-logo', !nilai && 'aktif']" @click="nilai = ''">
        <span class="gambar"><PhProhibit :size="26" class="text-teks3" /></span><span class="nama">{{ kosong }}</span>
      </button>
      <button v-for="l in daftar" :key="l.k" type="button" role="radio" :aria-checked="kode === l.k" :class="['pilih-logo', kode === l.k && 'aktif']" @click="nilai = rujukan(l.k)">
        <span class="gambar"><img :src="lembaga.urlLogo(rujukan(l.k))" alt="" /></span><span class="nama">{{ l.n }}</span>
        <PhCheckCircle v-if="kode === l.k" :size="20" weight="fill" class="centang" />
      </button>
      <button v-if="tautanLama" type="button" role="radio" aria-checked="true" class="pilih-logo aktif">
        <span class="gambar"><img :src="lembaga.urlLogo(nilai)" alt="Tautan gambar lama" /></span><span class="nama">Tautan lama</span>
        <PhCheckCircle :size="20" weight="fill" class="centang" />
      </button>
    </div>
    <p class="mt-1.5 flex items-center gap-1.5 text-xs text-teks3"><PhGearSix :size="14" /> {{ ket || 'Tambah atau ganti gambar logo di Setelan → Logo; perubahan langsung berlaku di sini.' }}</p>
  </fieldset>
</template>
<style scoped>
.pilih-logo { position: relative; display: flex; flex-direction: column; align-items: center; gap: .375rem; padding: .625rem .5rem; border-radius: .875rem;
  border: 1px solid rgb(var(--garis)); background: rgb(var(--permukaan)); text-align: center; min-height: 44px; }
.pilih-logo:hover { background: rgb(var(--permukaan-2)); }
.pilih-logo.aktif { border-color: var(--tab-aktif); box-shadow: 0 0 0 1.5px var(--tab-aktif); }
.pilih-logo .gambar { display: grid; place-items: center; width: 3.25rem; height: 3.25rem; border-radius: .75rem; background: #fff; overflow: hidden; }
.pilih-logo .gambar img { max-width: 88%; max-height: 88%; object-fit: contain; }
.pilih-logo .nama { font-size: .75rem; font-weight: 600; line-height: 1.2; color: rgb(var(--teks-2)); }
.pilih-logo.aktif .nama { color: rgb(var(--teks)); }
.pilih-logo .centang { position: absolute; top: .25rem; right: .25rem; color: var(--tab-aktif); }
</style>
