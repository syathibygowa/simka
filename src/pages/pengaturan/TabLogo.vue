<!-- SIMKA PRO | src/pages/pengaturan/TabLogo.vue | v1.0 | Perbaikan 13.6.0: daftar logo terpusat | 15/10/2026 -->
<script setup>
// Setelan → Logo: pusat semua logo lembaga (pondok, yayasan, Wustha, SMA, Kementerian Agama, Diknas, dan logo tambahan).
// Kop surat, dokumen tahfizh (sertifikat/suket), dan sampul rapor memilih logo dari daftar ini, sehingga cukup
// mengganti gambar di sini. Disimpan di pengaturan identitas (logo_daftar); logo pondok dan Kemenag juga disalin ke
// kolom lama (logo_url, logo_kemenag_url) agar bagian yang belum memakai daftar tetap benar.
import { ref, computed } from 'vue'
import { PhFloppyDisk, PhCopySimple, PhUploadSimple, PhPlus, PhTrash, PhImage, PhStamp } from '@phosphor-icons/vue'
import { useLembaga } from '@/stores/lembaga'
import { useUI } from '@/stores/ui'
import { daftarLogo, LOGO_BAWAAN, rujukan } from '@/lib/logo'
import { alamatAset } from '@/lib/penyimpanan'

const lembaga = useLembaga(); const ui = useUI()
const draf = ref(daftarLogo(lembaga.identitas).map((x) => ({ ...x })))
const proses = ref(false); const sibuk = ref('')
const berubah = ref(false)
const tandai = () => { berubah.value = true }

/** Pemakai logo: kop surat yang merujuk logo ini. */
const dipakai = (k) => lembaga.letterheads.filter((h) => [h.logo_kiri_url, h.logo_kanan_url].includes(rujukan(k))).map((h) => 'Kop ' + h.nama)

function tambah() {
  draf.value.push({ k: 'lain-' + Date.now().toString(36), n: '', url: '', bawaan: false }); tandai()
}
async function hapus(i) {
  const x = draf.value[i]
  if (!(await ui.konfirmasi({ judul: 'Hapus logo', pesan: `Hapus ${x.n || 'logo ini'} dari daftar? Kop atau dokumen yang memakainya akan tampil tanpa logo ini.`, ya: 'Hapus', bahaya: true }))) return
  draf.value.splice(i, 1); tandai()
}
async function unggah(e, x) {
  const berkas = e.target.files?.[0]; e.target.value = ''
  if (!berkas) return
  sibuk.value = x.k
  try { x.url = await lembaga.unggahGambar(berkas, 'logo-' + x.k); tandai(); ui.toast('Gambar diunggah. Tekan Simpan daftar logo untuk menerapkan.') }
  catch (err) { ui.toast(err.message, 'galat') } finally { sibuk.value = '' }
}
async function salin(x) {
  if (!/^https:\/\//.test(x.url || '')) return ui.toast('Tempel tautan gambar yang diawali https:// terlebih dahulu.', 'galat')
  sibuk.value = x.k
  try { x.url = await lembaga.salinLogo(x.url, 'logo-' + x.k); tandai(); ui.toast('Logo disalin ke penyimpanan sistem. Tekan Simpan daftar logo.') }
  catch (err) { ui.toast(err.message, 'galat') } finally { sibuk.value = '' }
}
const jumlahTerisi = computed(() => draf.value.filter((x) => x.url).length)

async function simpan() {
  if (draf.value.some((x) => !x.bawaan && !x.n.trim())) return ui.toast('Isi nama setiap logo tambahan.', 'galat')
  proses.value = true
  try {
    const logo_daftar = draf.value.map((x) => ({ k: x.k, n: x.n.trim(), url: (x.url || '').trim() }))
    const ambil = (k) => logo_daftar.find((x) => x.k === k)?.url || ''
    const isi = { ...lembaga.identitas, logo_daftar }
    for (const b of LOGO_BAWAAN.filter((b) => b.sumber)) isi[b.sumber] = ambil(b.k)
    await lembaga.simpanPengaturan('identitas', isi)
    berubah.value = false; ui.toast('Daftar logo disimpan dan langsung berlaku di kop surat, dokumen, dan rapor.')
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <div class="space-y-4">
    <p class="text-sm text-teks2">Semua logo lembaga dikelola di sini. Kop surat, sertifikat dan surat keterangan tahfizh, serta sampul rapor tinggal memilih logo dari daftar ini.
      {{ jumlahTerisi }} dari {{ draf.length }} logo sudah bergambar.</p>
    <ul class="grid gap-3 md:grid-cols-2">
      <li v-for="(x, i) in draf" :key="x.k" class="kartu flex gap-4 p-4">
        <span class="grid h-20 w-20 shrink-0 place-items-center overflow-hidden rounded-2xl border border-garis bg-white">
          <img v-if="x.url" :src="alamatAset(x.url)" alt="" :title="x.n" class="max-h-[72px] max-w-[72px] object-contain" />
          <PhImage v-else :size="30" class="text-[#9C8E8B]" />
        </span>
        <div class="min-w-0 flex-1 space-y-2">
          <div class="flex items-center gap-2">
            <input v-if="!x.bawaan" v-model="x.n" class="isian h-10 min-h-0 flex-1 py-0 text-sm font-semibold" placeholder="Nama logo, mis. Logo OSIS" :aria-label="'Nama logo ' + (i + 1)" @input="tandai" />
            <p v-else class="flex-1 font-bold">{{ x.n }}</p>
            <button v-if="!x.bawaan" type="button" class="tombol-ikon h-10 w-10 shrink-0" :aria-label="'Hapus ' + (x.n || 'logo')" @click="hapus(i)"><PhTrash :size="20" /></button>
          </div>
          <input v-model="x.url" class="isian h-10 min-h-0 py-0 text-sm" placeholder="Tautan gambar https://… atau unggah" :aria-label="'Tautan gambar ' + (x.n || 'logo')" @input="tandai" />
          <div class="flex flex-wrap gap-2">
            <label class="tombol-garis min-h-[38px] cursor-pointer px-3 text-sm"><PhUploadSimple :size="18" weight="duotone" /> {{ sibuk === x.k ? 'Memproses…' : 'Unggah' }}
              <input type="file" accept="image/png,image/jpeg,image/webp,image/svg+xml" class="sr-only" @change="unggah($event, x)" /></label>
            <button type="button" class="tombol-garis min-h-[38px] px-3 text-sm" :disabled="sibuk === x.k" @click="salin(x)"><PhCopySimple :size="18" weight="duotone" /> Salin ke sistem</button>
            <button v-if="x.url" type="button" class="tombol-teks min-h-[38px] px-2 text-sm" @click="(x.url = ''), tandai()">Kosongkan</button>
          </div>
          <p v-if="dipakai(x.k).length" class="flex flex-wrap items-center gap-1 text-xs text-teks3"><PhStamp :size="14" /> Dipakai: {{ dipakai(x.k).join(', ') }}</p>
        </div>
      </li>
    </ul>
    <div class="flex flex-wrap items-center justify-between gap-2">
      <button type="button" class="tombol-garis" @click="tambah"><PhPlus :size="20" weight="bold" /> Tambah logo</button>
      <button type="button" class="tombol-utama" :disabled="proses" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses ? 'Menyimpan…' : 'Simpan daftar logo' }}<span v-if="berubah && !proses" class="ml-1 h-2 w-2 rounded-full bg-white" aria-label="ada perubahan" /></button>
    </div>
    <p class="text-xs text-teks3">PNG/JPG/WEBP/SVG maksimal 1 MB, sebaiknya berlatar transparan. Logo dari tautan internet sebaiknya disalin ke penyimpanan sistem agar tidak hilang bila tautan asal berubah.</p>
  </div>
</template>
