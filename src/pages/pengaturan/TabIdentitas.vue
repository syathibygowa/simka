<!-- SIMKA PRO | src/pages/pengaturan/TabIdentitas.vue | v1.0 | Fase 1 – Pengaturan | 03/10/2026 -->
<script setup>
import { ref } from 'vue'
import { PhFloppyDisk, PhCopySimple } from '@phosphor-icons/vue'
import { useLembaga } from '@/stores/lembaga'
import { useUI } from '@/stores/ui'

const lembaga = useLembaga(); const ui = useUI()
const f = ref({ ...lembaga.identitas })
const proses = ref(false); const menyalin = ref('')

const ISIAN = [
  { k: 'nama_lengkap', l: 'Nama lembaga lengkap', lebar: true },
  { k: 'nama_singkat', l: 'Nama singkat' }, { k: 'tagline', l: 'Tagline' },
  { k: 'npsn', l: 'NPSN', angka: true }, { k: 'nspp', l: 'NSPP', angka: true },
  { k: 'telepon', l: 'Telepon/WA kantor', angka: true }, { k: 'email', l: 'Email lembaga', jenis: 'email' },
  { k: 'kota_surat', l: 'Kota pada tanggal surat', ket: 'Contoh: Gowa → "Gowa, 03 Oktober 2026"' },
  { k: 'alamat', l: 'Alamat lengkap', lebar: true, panjang: true },
]
const LOGO = [
  { k: 'logo_url', l: 'Logo pondok' }, { k: 'logo_kemenag_url', l: 'Logo Kementerian Agama' }, { k: 'ikon_url', l: 'Ikon SIMKA PRO' },
]

async function simpan() {
  if (!f.value.nama_lengkap?.trim()) { ui.toast('Nama lembaga lengkap wajib diisi.', 'galat'); return }
  proses.value = true
  try { await lembaga.simpanPengaturan('identitas', f.value); ui.toast('Identitas lembaga disimpan.') }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
async function salin(k) {
  if (!/^https:\/\//.test(f.value[k] || '')) { ui.toast('Tempel tautan gambar yang diawali https:// terlebih dahulu.', 'galat'); return }
  menyalin.value = k
  try { f.value[k] = await lembaga.salinLogo(f.value[k], k.replace('_url', '')); ui.toast('Logo disalin ke penyimpanan sistem. Tekan Simpan perubahan.') }
  catch (e) { ui.toast(e.message, 'galat') } finally { menyalin.value = '' }
}
</script>
<template>
  <form class="space-y-4" @submit.prevent="simpan">
    <div class="kartu grid gap-4 p-5 sm:grid-cols-2">
      <div v-for="i in ISIAN" :key="i.k" :class="i.lebar && 'sm:col-span-2'">
        <label class="label-isian" :for="'id-' + i.k">{{ i.l }}</label>
        <textarea v-if="i.panjang" :id="'id-' + i.k" v-model="f[i.k]" rows="2" class="isian py-3" />
        <input v-else :id="'id-' + i.k" v-model="f[i.k]" :type="i.jenis || 'text'" :inputmode="i.angka ? 'numeric' : undefined" class="isian" />
        <p v-if="i.ket" class="mt-1 text-xs text-teks3">{{ i.ket }}</p>
      </div>
    </div>

    <div class="kartu p-5">
      <h3 class="judul-bagian">Logo</h3>
      <p class="mb-4 text-sm text-teks3">Logo dari tautan internet sebaiknya disalin ke penyimpanan sistem agar tidak hilang bila tautan asal berubah.</p>
      <div class="space-y-4">
        <div v-for="g in LOGO" :key="g.k" class="flex flex-wrap items-end gap-3">
          <span class="grid h-16 w-16 shrink-0 place-items-center overflow-hidden rounded-xl border border-garis bg-white">
            <img v-if="f[g.k]" :src="f[g.k]" :alt="g.l" class="max-h-14 max-w-14 object-contain" />
          </span>
          <div class="min-w-[220px] flex-1">
            <label class="label-isian" :for="'lg-' + g.k">{{ g.l }}</label>
            <input :id="'lg-' + g.k" v-model="f[g.k]" class="isian" placeholder="https://…" />
          </div>
          <button type="button" class="tombol-garis" :disabled="menyalin === g.k" @click="salin(g.k)">
            <PhCopySimple :size="20" weight="duotone" /> {{ menyalin === g.k ? 'Menyalin…' : 'Salin ke sistem' }}
          </button>
        </div>
      </div>
    </div>

    <div class="flex justify-end">
      <button class="tombol-utama" :disabled="proses"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses ? 'Menyimpan…' : 'Simpan perubahan' }}</button>
    </div>
  </form>
</template>
