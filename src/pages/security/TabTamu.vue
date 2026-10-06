<!-- SIMKA PRO | src/pages/security/TabTamu.vue | v1.0 | Fase 7 – Tahap 2 Titipan, buku tamu, kunjungan | 06/10/2026 -->
<script setup>
// Buku tamu (Blueprint Bagian 24): nama, instansi, HP, keperluan, orang yang ditemui (pegawai menerima notifikasi),
// jumlah orang, kendaraan, foto opsional, jam masuk dan keluar. Tab "Di dalam" (belum keluar) dan "Riwayat"; Excel dan cetak F4.
import { ref, computed, watch, onMounted, onBeforeUnmount } from 'vue'
import * as XLSX from 'xlsx'
import { PhUsers, PhSignOut, PhCamera, PhMagnifyingGlass, PhEye, PhDownloadSimple, PhX, PhIdentificationBadge } from '@phosphor-icons/vue'
import { useSecurity } from '@/stores/security'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { unggahFotoSecurity } from '@/lib/fotoSecurity'
import { durasi } from '@/lib/security'
import { penandaKelompok } from '@/lib/santri'
import { formatWaktu, formatJam, formatPanjang, hariIniISO } from '@/lib/tanggal'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import FotoBerkas from '@/components/FotoBerkas.vue'
import TombolAksi from '@/components/TombolAksi.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const sc = useSecurity(); const sesi = useSesi(); const ui = useUI()
const cakupan = ref('di_dalam'); const mulai = ref(hariIniISO().slice(0, 8) + '01'); const selesai = ref(hariIniISO()); const cari = ref('')
const daftar = ref([]); const memuat = ref(false)
async function muat() {
  memuat.value = true
  try { daftar.value = await sc.daftarTamu(cakupan.value, mulai.value, selesai.value) } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
watch([cakupan, mulai, selesai], muat)
onMounted(() => { muat(); sc.dengarkan(muat) })
onBeforeUnmount(() => sc.berhenti())
const tampil = computed(() => { const q = cari.value.toLowerCase().trim(); return daftar.value.filter((t) => !q || `${t.nama} ${t.instansi || ''} ${t.keperluan} ${t.ditemui || ''}`.toLowerCase().includes(q)) })
const lamaMenit = (t) => Math.floor(((t.keluar_pada ? new Date(t.keluar_pada) : Date.now()) - new Date(t.masuk_pada)) / 60000)

// ---------- Tamu masuk ----------
const lembar = ref(false); const proses = ref(false); const baru = ref({}); const foto = ref(null); const prat = ref('')
const cariPeg = ref(''); const hasilPeg = ref([]); let tunda
function bukaBaru() { baru.value = { nama: '', instansi: '', hp: '', keperluan: '', ditemui: null, ditemui_teks: '', jumlah_orang: 1, kendaraan: '', catatan: '' }; foto.value = null; prat.value = ''; cariPeg.value = ''; lembar.value = true }
watch(cariPeg, () => { clearTimeout(tunda); tunda = setTimeout(async () => {
  const q = cariPeg.value.trim(); if (q.length < 2) { hasilPeg.value = []; return }
  try { hasilPeg.value = await sc.cariPegawai(q) } catch (e) { ui.toast(e.message, 'galat') }
}, 300) })
function pilihPeg(p) { baru.value.ditemui = p; cariPeg.value = ''; hasilPeg.value = [] }
function bacaFoto(e) { const f = e.target.files?.[0]; e.target.value = ''; if (f && /^image\//.test(f.type)) { foto.value = f; prat.value = URL.createObjectURL(f) } }
async function simpan() {
  const x = baru.value
  if (x.nama.trim().length < 2) return ui.toast('Isi nama tamu.', 'galat')
  if (x.keperluan.trim().length < 3) return ui.toast('Isi keperluan tamu.', 'galat')
  if (!x.ditemui && x.ditemui_teks.trim().length < 2) return ui.toast('Pilih pegawai yang ditemui atau tulis bagian yang dituju.', 'galat')
  proses.value = true
  try {
    const fotoId = await unggahFotoSecurity(foto.value, { nama: x.nama, jenis: 'Tamu' })
    await sc.tamuMasuk({ nama: x.nama.trim(), instansi: x.instansi.trim(), hp: x.hp.trim(), keperluan: x.keperluan.trim(), ditemui_id: x.ditemui?.id || null, ditemui_nama: x.ditemui?.nama,
      ditemui_teks: x.ditemui ? null : x.ditemui_teks.trim(), jumlah_orang: Number(x.jumlah_orang) || 1, kendaraan: x.kendaraan.trim(), catatan: x.catatan.trim(), foto_id: fotoId })
    ui.toast(x.ditemui ? `Tamu tercatat. ${x.ditemui.nama} telah dikabari.` : 'Tamu tercatat.'); lembar.value = false; cakupan.value = 'di_dalam'; await muat()
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
async function keluar(t) {
  if (!(await ui.konfirmasi({ judul: 'Tamu keluar', pesan: `Catat ${t.nama} keluar sekarang?`, ya: 'Catat keluar' }))) return
  try { await sc.tamuKeluar(t.id); ui.toast('Tamu tercatat keluar.'); await muat() } catch (e) { ui.toast(e.message, 'galat') }
}

// ---------- Ekspor dan cetak ----------
const periode = computed(() => (cakupan.value === 'di_dalam' ? 'Tamu di dalam pondok per ' + formatPanjang(hariIniISO()) : mulai.value === selesai.value ? formatPanjang(mulai.value) : `${formatPanjang(mulai.value)} s.d. ${formatPanjang(selesai.value)}`))
function ekspor() {
  const judul = ['No.', 'Masuk', 'Keluar', 'Nama tamu', 'Instansi', 'HP', 'Jumlah orang', 'Kendaraan', 'Keperluan', 'Menemui', 'Petugas', 'Catatan']
  const isi = tampil.value.map((t, i) => [i + 1, formatWaktu(t.masuk_pada), t.keluar_pada ? formatWaktu(t.keluar_pada) : '', t.nama, t.instansi || '', t.hp || '', t.jumlah_orang, t.kendaraan || '', t.keperluan, t.ditemui || '', t.petugas_masuk || '', t.catatan || ''])
  const ws = XLSX.utils.aoa_to_sheet([[`Buku Tamu – ${periode.value}`], [], judul, ...isi])
  ws['!cols'] = [5, 16, 16, 24, 20, 14, 8, 12, 30, 24, 20, 24].map((w) => ({ wch: w }))
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Buku tamu'); XLSX.writeFile(wb, `Buku-Tamu-${cakupan.value === 'di_dalam' ? hariIniISO() : mulai.value + '-' + selesai.value}.xlsx`)
}
const pratinjau = ref(false); const penanda = ref({ jabatan: 'Kepala Bidang Kesantrian', nama: '', niy: '' })
watch(pratinjau, async (v) => { if (v) penanda.value = await penandaKelompok({ jenis: 'kamar' }).catch(() => penanda.value) })
</script>
<template>
  <div>
    <div class="flex flex-wrap items-center gap-2">
      <div class="flex gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" aria-label="Saring tamu">
        <button v-for="p in [{ k: 'di_dalam', n: 'Di dalam' }, { k: 'semua', n: 'Riwayat' }]" :key="p.k" type="button" role="radio" :aria-checked="cakupan === p.k" @click="cakupan = p.k"
          :class="['min-h-[40px] rounded-xl px-4 text-sm font-semibold', cakupan === p.k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">{{ p.n }}</button>
      </div>
      <div class="relative min-w-[180px] flex-1"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
        <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari nama, instansi, keperluan" aria-label="Cari tamu" /></div>
      <button class="tombol-garis w-pengajuan min-h-[44px] px-3 text-sm" @click="pratinjau = true"><PhEye :size="18" style="color: var(--c)" /> Cetak</button>
      <button class="tombol-garis w-santri min-h-[44px] px-3 text-sm" @click="ekspor"><PhDownloadSimple :size="18" style="color: var(--c)" /> Excel</button>
      <button v-if="sc.hak.gerbang" class="tombol-utama hidden lg:inline-flex" @click="bukaBaru"><PhUsers :size="20" weight="duotone" /> Catat tamu</button>
    </div>
    <div v-if="cakupan === 'semua'" class="mt-3 grid grid-cols-2 gap-3 sm:max-w-md"><InputTanggal v-model="mulai" label="Dari" /><InputTanggal v-model="selesai" label="Sampai" /></div>

    <ul class="mt-3 grid gap-3 md:grid-cols-2">
      <li v-for="t in tampil" :key="t.id" class="kartu p-4" :class="t.keluar_pada ? 'w-rekap' : 'w-pegawai'">
        <div class="flex items-start gap-3">
          <span class="chip-ikon h-11 w-11 shrink-0"><PhIdentificationBadge :size="24" weight="duotone" /></span>
          <div class="min-w-0 flex-1">
            <p class="flex flex-wrap items-center gap-1.5"><b class="leading-snug">{{ t.nama }}</b><span class="lencana">{{ t.keluar_pada ? 'Sudah keluar' : 'Di dalam' }}</span></p>
            <p class="text-xs text-teks3">{{ t.instansi || 'Pribadi' }}{{ t.jumlah_orang > 1 ? ' · ' + t.jumlah_orang + ' orang' : '' }}{{ t.kendaraan ? ' · ' + t.kendaraan : '' }}{{ t.hp ? ' · ' + t.hp : '' }}</p>
            <p class="mt-1.5 text-sm font-semibold">{{ t.keperluan }}</p>
            <p class="text-xs text-teks2">Menemui {{ t.ditemui || '–' }}</p>
            <p class="text-xs text-teks2">Masuk {{ formatJam(t.masuk_pada) }}{{ t.keluar_pada ? ' · keluar ' + formatJam(t.keluar_pada) : '' }} · {{ durasi(lamaMenit(t)) }} · {{ formatWaktu(t.masuk_pada).slice(0, 10) }}</p>
            <div class="mt-2 flex items-center gap-2">
              <FotoBerkas v-if="t.foto_id" :id="t.foto_id" alt="Foto tamu" ukuran="h-14 w-14" />
              <button v-if="!t.keluar_pada && sc.hak.gerbang" class="tombol-garis min-h-[38px] px-3 text-sm" @click="keluar(t)"><PhSignOut :size="18" /> Catat keluar</button>
            </div>
          </div>
        </div>
      </li>
    </ul>
    <p v-if="!tampil.length && !memuat" class="kartu mt-3 p-8 text-center text-sm text-teks3">{{ cakupan === 'di_dalam' ? 'Tidak ada tamu di dalam pondok.' : 'Belum ada tamu pada rentang ini.' }}</p>

    <TombolAksi v-if="sc.hak.gerbang" label="Catat tamu" :ikon="PhUsers" warna="pegawai" @klik="bukaBaru" />

    <LembarBawah v-model="lembar" judul="Tamu masuk">
      <div class="space-y-3 pb-2">
        <div class="grid gap-3 sm:grid-cols-2">
          <div><label class="label-isian" for="tm-nm">Nama tamu<span class="text-merah"> *</span></label><input id="tm-nm" v-model="baru.nama" class="isian" /></div>
          <div><label class="label-isian" for="tm-in">Instansi/asal</label><input id="tm-in" v-model="baru.instansi" class="isian" placeholder="Kosongkan bila pribadi" /></div>
        </div>
        <div><label class="label-isian" for="tm-kp">Keperluan<span class="text-merah"> *</span></label><input id="tm-kp" v-model="baru.keperluan" class="isian" placeholder="Contoh: silaturahmi, monitoring, antar barang" /></div>
        <div>
          <p class="label-isian">Menemui<span class="text-merah"> *</span></p>
          <div v-if="baru.ditemui" class="flex items-center gap-2 rounded-xl border border-garis p-2.5">
            <div class="min-w-0 flex-1"><p class="font-semibold">{{ baru.ditemui.nama }}</p><p class="text-xs text-teks3">{{ baru.ditemui.jabatan || 'Pegawai' }} · akan menerima notifikasi</p></div>
            <button type="button" class="tombol-teks min-h-[36px] px-2" aria-label="Ganti" @click="baru.ditemui = null"><PhX :size="18" /></button>
          </div>
          <template v-else>
            <input v-model="cariPeg" type="search" class="isian" placeholder="Ketik nama pegawai yang ditemui" aria-label="Cari pegawai yang ditemui" />
            <ul v-if="hasilPeg.length" class="mt-2 max-h-48 divide-y divide-garis overflow-y-auto rounded-xl border border-garis">
              <li v-for="p in hasilPeg" :key="p.id"><button type="button" class="w-full px-3 py-2 text-left hover:bg-permukaan2" @click="pilihPeg(p)">
                <span class="block font-semibold">{{ p.nama }}</span><span class="block text-xs text-teks3">{{ p.jabatan || 'Pegawai' }}</span></button></li>
            </ul>
            <input v-model="baru.ditemui_teks" class="isian mt-2" placeholder="atau tulis bagian yang dituju, contoh: Tata usaha" aria-label="Bagian yang dituju" />
          </template>
        </div>
        <div class="grid grid-cols-2 gap-3 sm:grid-cols-3">
          <div><label class="label-isian" for="tm-hp">HP</label><input id="tm-hp" v-model="baru.hp" inputmode="tel" class="isian" /></div>
          <div><label class="label-isian" for="tm-jo">Jumlah orang</label><input id="tm-jo" v-model="baru.jumlah_orang" type="number" min="1" class="isian tabular-nums" /></div>
          <div class="col-span-2 sm:col-span-1"><label class="label-isian" for="tm-kd">Kendaraan/plat</label><input id="tm-kd" v-model="baru.kendaraan" class="isian" placeholder="DD 1234 AB" /></div>
        </div>
        <div class="flex flex-wrap items-center gap-3">
          <label class="tombol-garis cursor-pointer"><PhCamera :size="20" weight="duotone" /> {{ prat ? 'Ganti foto' : 'Foto (opsional)' }}
            <input type="file" accept="image/*" capture="environment" class="sr-only" @change="bacaFoto" /></label>
          <img v-if="prat" :src="prat" alt="Pratinjau foto tamu" class="h-16 w-16 rounded-xl object-cover" />
        </div>
        <button class="tombol-utama w-full" :disabled="proses" @click="simpan"><PhUsers :size="20" weight="bold" /> {{ proses ? 'Menyimpan…' : 'Simpan tamu' }}</button>
      </div>
    </LembarBawah>

    <DokumenCetak kop="pondok" judul="Buku Tamu" :subjudul="periode" v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap" mendatar>
      <table class="tabel kecil">
        <thead><tr><th style="width:4%">No.</th><th style="width:11%">Masuk</th><th style="width:7%">Keluar</th><th style="width:15%">Nama tamu</th><th style="width:13%">Instansi</th>
          <th style="width:5%">Orang</th><th>Keperluan</th><th style="width:15%">Menemui</th><th style="width:11%">Petugas</th></tr></thead>
        <tbody>
          <tr v-for="(t, i) in tampil" :key="t.id"><td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ formatWaktu(t.masuk_pada) }}</td><td class="tengah">{{ t.keluar_pada ? formatJam(t.keluar_pada) : '–' }}</td>
            <td>{{ t.nama }}</td><td>{{ t.instansi || 'Pribadi' }}</td><td class="tengah">{{ t.jumlah_orang }}</td><td>{{ t.keperluan }}</td><td>{{ t.ditemui || '–' }}</td><td>{{ t.petugas_masuk || '–' }}</td></tr>
          <tr v-if="!tampil.length"><td colspan="9" class="tengah">Tidak ada tamu.</td></tr>
        </tbody>
      </table>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: penanda.jabatan || 'Kepala Bidang Kesantrian', nama: penanda.nama, niy: penanda.niy }"
          :kanan="{ jabatan: 'Petugas Security', nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
      </template>
    </DokumenCetak>
  </div>
</template>
