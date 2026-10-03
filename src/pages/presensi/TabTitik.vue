<!-- SIMKA PRO | src/pages/presensi/TabTitik.vue | v1.0 | Fase 2 – Tahap 3 Pengaturan presensi | 03/10/2026 -->
<script setup>
// Titik GPS pondok (Bagian 9): banyak titik, masing-masing nama, koordinat, dan radius.
// Presensi sah di dalam radius titik mana pun. Hanya superadmin yang dapat mengubah.
import { ref, computed } from 'vue'
import { PhMapPin, PhPlus, PhPencilSimple, PhTrash, PhFloppyDisk, PhNavigationArrow, PhCheckCircle, PhWarningCircle, PhInfo } from '@phosphor-icons/vue'
import { useAturPresensi } from '@/stores/aturPresensi'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { uraiKoordinat, formatKoordinat, formatJarak, titikTerdekat } from '@/lib/presensi'
import PetaTitik from '@/components/PetaTitik.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import TombolAksi from '@/components/TombolAksi.vue'

const atur = useAturPresensi(); const sesi = useSesi(); const ui = useUI()
const bolehUbah = computed(() => sesi.isSuperadmin)
const f = ref(null); const teksKoor = ref(''); const proses = ref(false)
const posisi = ref(null); const mencari = ref(false)
const uji = computed(() => posisi.value ? titikTerdekat(atur.titik, posisi.value.lat, posisi.value.lng) : null)

function baru() {
  const tengah = atur.titik[0] || { lat: -5.2135, lng: 119.4745 }
  f.value = { nama: '', lat: posisi.value?.lat ?? tengah.lat, lng: posisi.value?.lng ?? tengah.lng, radius_m: 100, aktif: true, urutan: atur.titik.length + 1, catatan: '' }
  teksKoor.value = formatKoordinat(f.value.lat, f.value.lng)
}
function ubah(t) { f.value = { ...t }; teksKoor.value = formatKoordinat(t.lat, t.lng) }
function ketukPeta({ lat, lng }) { f.value.lat = lat; f.value.lng = lng; teksKoor.value = formatKoordinat(lat, lng) }
function tulisKoor() { const k = uraiKoordinat(teksKoor.value); if (k) { f.value.lat = k.lat; f.value.lng = k.lng } }

function ambilPosisi(untukForm = false) {
  if (!navigator.geolocation) return ui.toast('Peramban ini tidak mendukung GPS.', 'galat')
  mencari.value = true
  navigator.geolocation.getCurrentPosition((p) => {
    mencari.value = false
    posisi.value = { lat: p.coords.latitude, lng: p.coords.longitude, akurasi: Math.round(p.coords.accuracy) }
    if (untukForm && f.value) ketukPeta({ lat: +p.coords.latitude.toFixed(7), lng: +p.coords.longitude.toFixed(7) })
    if (p.coords.accuracy > 50) ui.toast(`Akurasi GPS ±${Math.round(p.coords.accuracy)} m. Tunggu sebentar di tempat terbuka lalu ulangi agar lebih tepat.`, 'info')
  }, (e) => {
    mencari.value = false
    ui.toast(e.code === 1 ? 'Izin lokasi ditolak. Aktifkan izin lokasi untuk aplikasi ini di pengaturan peramban.' : 'Lokasi tidak terbaca. Aktifkan GPS lalu coba lagi.', 'galat')
  }, { enableHighAccuracy: true, timeout: 20000, maximumAge: 0 })
}

async function simpan() {
  const t = f.value
  tulisKoor()
  if (!t.nama?.trim() || t.nama.trim().length < 2) return ui.toast('Nama titik wajib diisi, misalnya Masjid atau Gedung SMA.', 'galat')
  if (!uraiKoordinat(teksKoor.value)) return ui.toast('Koordinat tidak sah. Contoh penulisan: -5.208143, 119.494981', 'galat')
  const r = Number(t.radius_m)
  if (!Number.isInteger(r) || r < 10 || r > 2000) return ui.toast('Radius harus 10 sampai 2.000 meter.', 'galat')
  proses.value = true
  try { await atur.simpanTitik(t); ui.toast(`Titik ${t.nama} tersimpan.`); f.value = null } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
async function hapus(t) {
  if (!(await ui.konfirmasi({ judul: `Hapus titik ${t.nama}?`, pesan: 'Presensi di area titik ini tidak lagi dianggap di dalam pondok. Bila hanya ingin menghentikan sementara, nonaktifkan saja titiknya.', ya: 'Hapus', bahaya: true }))) return
  try { await atur.hapusTitik(t.id); ui.toast('Titik dihapus.'); f.value = null } catch (e) { ui.toast(e.message, 'galat') }
}
</script>
<template>
  <div class="grid gap-4 lg:grid-cols-[1.35fr_1fr]">
    <section class="space-y-3">
      <PetaTitik :titik="atur.titik" :posisi-saya="posisi" tinggi="clamp(260px, 48vh, 460px)" />
      <div class="kartu p-4">
        <div class="flex flex-wrap items-center gap-2">
          <h3 class="judul-bagian flex-1">Uji posisi saya</h3>
          <button class="tombol-garis" :disabled="mencari" @click="ambilPosisi(false)"><PhNavigationArrow :size="20" weight="duotone" /> {{ mencari ? 'Membaca GPS…' : 'Baca lokasi HP ini' }}</button>
        </div>
        <p v-if="!posisi" class="mt-1 text-sm text-teks3">Berdiri di lokasi, lalu tekan tombol di atas untuk memastikan radius titik sudah tepat.</p>
        <div v-else-if="!uji" class="mt-2 flex gap-2 rounded-xl bg-permukaan2 p-3 text-sm"><PhInfo :size="20" class="shrink-0" /> Belum ada titik GPS aktif.</div>
        <div v-else :class="['mt-2 flex gap-2 rounded-xl p-3 text-sm font-semibold', uji.diArea ? 'w-presensi' : 'w-laporan']" style="background: color-mix(in srgb, var(--c) 12%, transparent); color: var(--c)">
          <component :is="uji.diArea ? PhCheckCircle : PhWarningCircle" :size="22" weight="duotone" class="shrink-0" />
          <span>{{ uji.diArea ? `Di dalam area: ${uji.nama}, ${formatJarak(uji.jarak)}` : `Di luar area. Titik terdekat ${uji.nama}, ${formatJarak(uji.jarak)} (radius ${uji.radius_m} m)` }}
            <span class="block text-xs font-normal text-teks3">Akurasi GPS ±{{ posisi.akurasi }} m · {{ formatKoordinat(posisi.lat, posisi.lng) }}</span></span>
        </div>
      </div>
    </section>

    <section class="kartu p-4 sm:p-5">
      <div class="mb-2 flex items-center gap-2">
        <h3 class="judul-bagian flex-1">Titik GPS ({{ atur.titik.length }})</h3>
        <button v-if="bolehUbah" class="tombol-utama hidden lg:inline-flex" @click="baru"><PhPlus :size="20" weight="bold" /> Tambah titik</button>
      </div>
      <p v-if="!bolehUbah" class="mb-2 flex gap-2 text-sm text-teks3"><PhInfo :size="18" class="mt-0.5 shrink-0" /> Titik GPS hanya dapat diubah superadmin.</p>
      <div v-if="!atur.titik.length" class="flex flex-col items-center py-8 text-center">
        <span class="chip-ikon h-14 w-14 rounded-2xl"><PhMapPin :size="30" weight="duotone" /></span>
        <p class="mt-3 font-semibold">Belum ada titik GPS</p>
        <p class="max-w-xs text-sm text-teks3">Selama belum ada titik, semua presensi dianggap di luar area dan masuk antrian verval.</p>
      </div>
      <ul class="divide-y divide-garis">
        <li v-for="t in atur.titik" :key="t.id" class="flex items-center gap-3 py-2.5">
          <span class="chip-ikon h-10 w-10"><PhMapPin :size="22" weight="duotone" /></span>
          <div class="min-w-0 flex-1">
            <p class="font-semibold">{{ t.nama }} <span v-if="!t.aktif" class="lencana w-hakakses ml-1">Nonaktif</span></p>
            <p class="text-xs text-teks3">Radius {{ t.radius_m }} m · {{ formatKoordinat(t.lat, t.lng) }}<span v-if="t.catatan"> · {{ t.catatan }}</span></p>
          </div>
          <button v-if="bolehUbah" class="tombol-ikon" @click="ubah(t)" :aria-label="`Ubah titik ${t.nama}`"><PhPencilSimple :size="20" /></button>
        </li>
      </ul>
    </section>

    <TombolAksi v-if="bolehUbah" label="Tambah titik" :ikon="PhPlus" warna="santri" @klik="baru" />

    <LembarBawah :model-value="!!f" @update:model-value="(x) => !x && (f = null)" :judul="f?.id ? `Ubah titik ${f.nama}` : 'Tambah titik GPS'">
      <div v-if="f" class="space-y-4 pb-2">
        <PetaTitik :titik="atur.titik" :pilihan="f" :posisi-saya="posisi" tinggi="240px" @ketuk="ketukPeta" />
        <div><label class="label-isian" for="tk-nama">Nama titik <span class="text-merah">*</span></label>
          <input id="tk-nama" v-model="f.nama" class="isian" maxlength="60" placeholder="Contoh: Masjid, Gedung SMA, Asrama Putri" /></div>
        <div>
          <label class="label-isian" for="tk-koor">Koordinat (lintang, bujur) <span class="text-merah">*</span></label>
          <input id="tk-koor" v-model="teksKoor" class="isian tabular-nums" inputmode="decimal" placeholder="-5.208143, 119.494981" @change="tulisKoor" @blur="tulisKoor" />
          <p class="mt-1 text-xs text-teks3">Ketuk peta, tempel salinan koordinat dari Google Maps (tekan lama pada lokasi lalu salin angkanya), atau baca lokasi HP saat berdiri di tempat.</p>
          <button type="button" class="tombol-garis mt-2 w-full" :disabled="mencari" @click="ambilPosisi(true)"><PhNavigationArrow :size="20" weight="duotone" /> {{ mencari ? 'Membaca GPS…' : 'Pakai lokasi HP ini' }}</button>
        </div>
        <div>
          <label class="label-isian" for="tk-rad">Radius: {{ f.radius_m }} meter</label>
          <div class="flex items-center gap-3">
            <input id="tk-rad" v-model.number="f.radius_m" type="range" min="10" max="500" step="5" class="flex-1 accent-[#C7332F]" />
            <input v-model.number="f.radius_m" type="number" min="10" max="2000" class="isian w-24 tabular-nums" aria-label="Radius dalam meter" />
          </div>
          <p class="mt-1 text-xs text-teks3">Saran 50–150 m. Radius terlalu besar memudahkan presensi dari luar pondok.</p>
        </div>
        <div><label class="label-isian" for="tk-cat">Keterangan (tidak wajib)</label><input id="tk-cat" v-model="f.catatan" class="isian" placeholder="Contoh: mencakup asrama putra" /></div>
        <label class="flex min-h-[44px] items-center gap-3 font-semibold"><input v-model="f.aktif" type="checkbox" class="h-5 w-5 accent-[#C7332F]" /> Titik aktif</label>
        <button class="tombol-utama w-full" :disabled="proses" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses ? 'Menyimpan…' : 'Simpan titik' }}</button>
        <button v-if="f.id" class="tombol-teks w-full" @click="hapus(f)"><PhTrash :size="20" /> Hapus titik</button>
      </div>
    </LembarBawah>
  </div>
</template>
