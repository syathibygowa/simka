<!-- SIMKA PRO | src/pages/pengaturan/TabKop.vue | v1.0 | Fase 1 – Pengaturan | 03/10/2026 -->
<script setup>
// Empat kop surat: pratinjau langsung saat diketik dan cetak uji F4.
import { ref, nextTick, onMounted, onBeforeUnmount } from 'vue'
import { PhPencilSimple, PhPrinter, PhUploadSimple, PhPlus, PhTrash, PhFloppyDisk, PhArrowLeft, PhCopySimple } from '@phosphor-icons/vue'
import { useLembaga } from '@/stores/lembaga'
import { useUI } from '@/stores/ui'
import { useSesi } from '@/stores/sesi'
import KopSurat from '@/components/cetak/KopSurat.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const lembaga = useLembaga(); const ui = useUI(); const sesi = useSesi()
const draf = ref(null)          // kop yang sedang diubah
const kopUji = ref(null)        // kop untuk cetak uji
const proses = ref(false); const mengunggah = ref('')

// Skala pratinjau agar lebar kertas 175 mm (215 − 2 × 20) muat di layar HP
const wadah = ref(null); const skala = ref(1)
let pengamat
const LEBAR = 661 // 175 mm dalam px (96 dpi)
onMounted(() => { pengamat = new ResizeObserver(() => ukur()); })
onBeforeUnmount(() => pengamat?.disconnect())
function ukur() { if (wadah.value) skala.value = Math.min(1, (wadah.value.clientWidth - 2) / LEBAR) }

async function ubah(k) {
  draf.value = JSON.parse(JSON.stringify({ ...k, baris: k.baris || [] }))
  await nextTick(); if (wadah.value) { pengamat.observe(wadah.value); ukur() }
}
function tutup() { pengamat?.disconnect(); draf.value = null }

async function unggah(e, kolom) {
  const berkas = e.target.files?.[0]; e.target.value = ''
  if (!berkas) return
  mengunggah.value = kolom
  try { draf.value[kolom] = await lembaga.unggahGambar(berkas, `${draf.value.kode}-${kolom.replace('_url', '')}`); ui.toast('Gambar diunggah. Tekan Simpan kop untuk menerapkan.') }
  catch (err) { ui.toast(err.message, 'galat') } finally { mengunggah.value = '' }
}
async function salin(kolom) {
  const u = draf.value[kolom]
  if (!/^https:\/\//.test(u || '')) return ui.toast('Tempel tautan gambar yang diawali https:// terlebih dahulu.', 'galat')
  mengunggah.value = kolom
  try { draf.value[kolom] = await lembaga.salinLogo(u, `${draf.value.kode}-${kolom.replace('_url', '')}`); ui.toast('Logo disalin ke penyimpanan sistem.') }
  catch (err) { ui.toast(err.message, 'galat') } finally { mengunggah.value = '' }
}
const tambahBaris = () => draf.value.baris.push({ teks: '', tebal: false, ukuran: 12 })
const hapusBarisKop = (i) => draf.value.baris.splice(i, 1)

async function simpan() {
  const d = draf.value
  if (!d.nama?.trim() || !d.kode_unit?.trim()) return ui.toast('Nama kop dan kode unit wajib diisi.', 'galat')
  if (d.bentuk === 'gambar' && !d.gambar_url) return ui.toast('Unggah gambar kop atau tempel tautannya.', 'galat')
  proses.value = true
  try {
    await lembaga.simpanBaris('letterheads', {
      id: d.id, nama: d.nama, kode_unit: d.kode_unit.trim().toUpperCase(), bentuk: d.bentuk, gambar_url: d.gambar_url,
      logo_kiri_url: d.logo_kiri_url || null, logo_kanan_url: d.logo_kanan_url || null,
      baris: d.baris.filter((b) => b.teks?.trim()), pita_teks: d.pita_teks || null, pita_warna: d.pita_warna || '#F8E02F',
    })
    ui.toast(`${d.nama} disimpan.`); tutup()
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}

async function cetakUji(k) {
  kopUji.value = k
  await nextTick()
  setTimeout(() => { window.print(); kopUji.value = null }, 400)
}
</script>
<template>
  <div>
    <!-- Daftar kop -->
    <div v-if="!draf" class="grid gap-4 xl:grid-cols-2">
      <article v-for="k in lembaga.letterheads" :key="k.id" class="kartu overflow-hidden">
        <div class="border-b border-garis bg-[#F3EEEB] p-3 dark:bg-[#0F0A0B]">
          <div class="rounded bg-white p-3"><div class="dok"><KopSurat :kop="k" :kode="k.kode" /></div></div>
        </div>
        <div class="flex flex-wrap items-center gap-2 p-4">
          <div class="min-w-0 flex-1">
            <p class="font-bold">{{ k.nama }}</p>
            <p class="text-sm text-teks3">Kode unit {{ k.kode_unit }} – {{ k.bentuk === 'susun' ? 'disusun dari teks dan logo' : 'satu gambar kop utuh' }}</p>
          </div>
          <button class="tombol-garis px-4 text-sm" @click="cetakUji(k)"><PhPrinter :size="18" weight="duotone" /> Cetak uji F4</button>
          <button class="tombol-garis px-4 text-sm" @click="ubah(k)"><PhPencilSimple :size="18" weight="duotone" /> Ubah</button>
        </div>
      </article>
    </div>

    <!-- Penyunting kop -->
    <div v-else class="space-y-4">
      <button class="tombol-teks -ml-3" @click="tutup"><PhArrowLeft :size="18" weight="bold" /> Kembali ke daftar kop</button>
      <div class="kartu p-4 sm:p-5">
        <p class="mb-2 text-sm font-semibold text-teks2">Pratinjau langsung (lebar isi kertas F4)</p>
        <div ref="wadah" class="overflow-hidden rounded-lg border border-garis bg-white p-0">
          <div class="dok p-3" :style="{ width: LEBAR + 'px', zoom: skala }">
            <KopSurat :kop="draf" :kode="draf.kode" />
          </div>
        </div>
      </div>

      <div class="kartu grid gap-4 p-5 sm:grid-cols-2">
        <div><label class="label-isian" for="kp-nama">Nama kop</label><input id="kp-nama" v-model="draf.nama" class="isian" /></div>
        <div><label class="label-isian" for="kp-unit">Kode unit (untuk nomor surat)</label><input id="kp-unit" v-model="draf.kode_unit" class="isian uppercase" /></div>
        <div class="sm:col-span-2">
          <p class="label-isian">Bentuk kop</p>
          <div class="grid grid-cols-2 gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" aria-label="Bentuk kop">
            <button v-for="b in [{ k: 'gambar', n: 'Satu gambar utuh' }, { k: 'susun', n: 'Teks dan logo' }]" :key="b.k" role="radio" :aria-checked="draf.bentuk === b.k" @click="draf.bentuk = b.k"
              :class="['min-h-[44px] rounded-xl text-sm font-semibold', draf.bentuk === b.k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">{{ b.n }}</button>
          </div>
        </div>

        <template v-if="draf.bentuk === 'gambar'">
          <div class="sm:col-span-2">
            <label class="label-isian" for="kp-gbr">Gambar kop</label>
            <div class="flex flex-wrap gap-2">
              <input id="kp-gbr" v-model="draf.gambar_url" class="isian min-w-[220px] flex-1" placeholder="Tautan gambar atau unggah berkas" />
              <label class="tombol-garis cursor-pointer"><PhUploadSimple :size="20" weight="duotone" /> {{ mengunggah === 'gambar_url' ? 'Mengunggah…' : 'Unggah gambar' }}
                <input type="file" accept="image/png,image/jpeg,image/webp" class="sr-only" @change="unggah($event, 'gambar_url')" /></label>
            </div>
            <p class="mt-1 text-xs text-teks3">PNG atau JPG, maksimal 1 MB. Lebar gambar sebaiknya sekitar 2000 piksel agar tajam saat dicetak.</p>
          </div>
        </template>

        <template v-else>
          <div v-for="lg in [{ k: 'logo_kiri_url', n: 'Logo kiri' }, { k: 'logo_kanan_url', n: 'Logo kanan (boleh kosong)' }]" :key="lg.k" class="sm:col-span-2">
            <label class="label-isian" :for="'kp-' + lg.k">{{ lg.n }}</label>
            <div class="flex flex-wrap gap-2">
              <input :id="'kp-' + lg.k" v-model="draf[lg.k]" class="isian min-w-[220px] flex-1" placeholder="https://…" />
              <button type="button" class="tombol-garis" @click="salin(lg.k)"><PhCopySimple :size="20" weight="duotone" /> Salin</button>
              <label class="tombol-garis cursor-pointer"><PhUploadSimple :size="20" weight="duotone" /> Unggah
                <input type="file" accept="image/png,image/jpeg,image/webp,image/svg+xml" class="sr-only" @change="unggah($event, lg.k)" /></label>
            </div>
          </div>
          <div class="sm:col-span-2">
            <p class="label-isian">Baris teks</p>
            <div class="space-y-2">
              <div v-for="(b, i) in draf.baris" :key="i" class="flex flex-wrap items-center gap-2">
                <input v-model="b.teks" class="isian min-w-[200px] flex-1" :aria-label="`Teks baris ${i + 1}`" />
                <label class="flex min-h-[44px] items-center gap-1.5 text-sm font-semibold text-teks2"><input v-model="b.tebal" type="checkbox" class="h-4 w-4 accent-[#C7332F]" /> Tebal</label>
                <select v-model.number="b.ukuran" class="isian w-24" :aria-label="`Ukuran huruf baris ${i + 1}`"><option v-for="u in [8, 9, 10, 11, 12, 13, 14, 15, 16, 18]" :key="u" :value="u">{{ u }} pt</option></select>
                <button type="button" class="tombol-ikon" @click="hapusBarisKop(i)" :aria-label="`Hapus baris ${i + 1}`"><PhTrash :size="20" /></button>
              </div>
            </div>
            <button type="button" class="tombol-teks mt-1 text-sm" @click="tambahBaris"><PhPlus :size="18" weight="bold" /> Tambah baris</button>
          </div>
          <div class="sm:col-span-2 grid gap-3 sm:grid-cols-[1fr_140px]">
            <div><label class="label-isian" for="kp-pita">Pita alamat (kosongkan untuk garis ganda biasa)</label><input id="kp-pita" v-model="draf.pita_teks" class="isian" /></div>
            <div><label class="label-isian" for="kp-warna">Warna pita</label><input id="kp-warna" v-model="draf.pita_warna" type="color" class="isian h-[46px] p-1" /></div>
          </div>
        </template>
      </div>

      <div class="flex flex-wrap justify-end gap-2">
        <button class="tombol-garis" @click="cetakUji(draf)"><PhPrinter :size="20" weight="duotone" /> Cetak uji F4</button>
        <button class="tombol-utama" :disabled="proses" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses ? 'Menyimpan…' : 'Simpan kop' }}</button>
      </div>
    </div>

    <!-- Dokumen cetak uji -->
    <DokumenCetak v-if="kopUji" :kop="kopUji.kode" :kop-data="kopUji" judul="Cetak Uji Kop Surat" :subjudul="kopUji.nama" :pencetak="sesi.pengguna?.nama_lengkap">
      <p>Lembar ini untuk memeriksa kop surat pada kertas F4 (215 × 330 mm) dengan margin 2 cm.</p>
      <table class="tabel" style="margin-top: 8pt">
        <colgroup><col style="width: 8%"><col style="width: 52%"><col style="width: 40%"></colgroup>
        <thead><tr><th>No.</th><th>Pemeriksaan</th><th>Hasil</th></tr></thead>
        <tbody>
          <tr><td class="tengah">1</td><td>Kop tampil utuh dan tidak terpotong</td><td></td></tr>
          <tr><td class="tengah">2</td><td>Logo dan teks terbaca jelas</td><td></td></tr>
          <tr><td class="tengah">3</td><td>Garis tabel tipis ½ pt</td><td></td></tr>
        </tbody>
      </table>
      <template #ttd>
        <TandaTangan :kiri="{ jabatan: 'Direktur', nama: lembaga.signatories[0]?.nama || '', niy: lembaga.signatories[0]?.niy }"
          :kanan="{ jabatan: 'Pemeriksa', nama: sesi.pengguna?.nama_lengkap || '' }" />
      </template>
    </DokumenCetak>
  </div>
</template>
