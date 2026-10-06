<!-- SIMKA PRO | src/pages/security/TabKunjungan.vue | v1.0 | Fase 7 – Tahap 2 Titipan, buku tamu, kunjungan | 06/10/2026 -->
<script setup>
// Kunjungan orang tua (Blueprint Bagian 24): santri, pengunjung, hubungan, jumlah orang, jam datang dan pulang, foto opsional.
// Saat dicatat, musyrif santri menerima notifikasi untuk memanggil santri. Bila jadwal kunjungan diaktifkan di Ketentuan,
// kunjungan di luar jadwal hanya ditandai (tidak ditolak). Membawa santri keluar pondok tetap memerlukan izin.
import { ref, computed, watch, onMounted, onBeforeUnmount } from 'vue'
import * as XLSX from 'xlsx'
import { PhUsersThree, PhSignOut, PhCamera, PhMagnifyingGlass, PhEye, PhDownloadSimple, PhWarning, PhInfo } from '@phosphor-icons/vue'
import { useSecurity } from '@/stores/security'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { unggahFotoSecurity } from '@/lib/fotoSecurity'
import { durasi, HARI_PENDEK } from '@/lib/security'
import { penandaKelompok } from '@/lib/santri'
import { formatWaktu, formatJam, formatPanjang, hariIniISO } from '@/lib/tanggal'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import FotoBerkas from '@/components/FotoBerkas.vue'
import TombolAksi from '@/components/TombolAksi.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import PilihSantriGerbang from './PilihSantriGerbang.vue'

const sc = useSecurity(); const sesi = useSesi(); const ui = useUI()
const cakupan = ref('berlangsung'); const mulai = ref(hariIniISO().slice(0, 8) + '01'); const selesai = ref(hariIniISO()); const cari = ref('')
const daftar = ref([]); const memuat = ref(false)
async function muat() {
  memuat.value = true
  try { daftar.value = await sc.daftarKunjungan(cakupan.value, mulai.value, selesai.value) } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
watch([cakupan, mulai, selesai], muat)
onMounted(() => { muat(); sc.dengarkan(muat) })
onBeforeUnmount(() => sc.berhenti())
const tampil = computed(() => { const q = cari.value.toLowerCase().trim(); return daftar.value.filter((k) => !q || `${k.nama} ${k.nis} ${k.kelas || ''} ${k.kamar || ''} ${k.pengunjung}`.toLowerCase().includes(q)) })
const lamaMenit = (k) => Math.floor(((k.pulang_pada ? new Date(k.pulang_pada) : Date.now()) - new Date(k.datang_pada)) / 60000)
const jadwal = computed(() => (sc.pengaturan.jadwal_kunjungan_aktif
  ? `Jadwal kunjungan: ${(sc.pengaturan.hari_kunjungan || []).map((h) => HARI_PENDEK[h]).join(', ')}, pukul ${sc.pengaturan.jam_kunjungan_mulai}–${sc.pengaturan.jam_kunjungan_selesai} WITA. Di luar jadwal tetap dicatat dan ditandai.`
  : 'Kunjungan bebas (jadwal kunjungan tidak diaktifkan).'))

const lembar = ref(false); const proses = ref(false); const baru = ref({}); const foto = ref(null); const prat = ref('')
function bukaBaru() { baru.value = { santri: null, pengunjung: '', hubungan: '', hp: '', jumlah_orang: 1, catatan: '' }; foto.value = null; prat.value = ''; lembar.value = true }
function bacaFoto(e) { const f = e.target.files?.[0]; e.target.value = ''; if (f && /^image\//.test(f.type)) { foto.value = f; prat.value = URL.createObjectURL(f) } }
async function simpan() {
  const x = baru.value
  if (!x.santri) return ui.toast('Pilih santri yang dikunjungi.', 'galat')
  if (x.pengunjung.trim().length < 2) return ui.toast('Isi nama pengunjung.', 'galat')
  proses.value = true
  try {
    const fotoId = await unggahFotoSecurity(foto.value, { nama: x.santri.nama, nis: x.santri.nis, jenis: 'Kunjungan' })
    const h = await sc.kunjunganDatang({ student_id: x.santri.student_id, pengunjung: x.pengunjung.trim(), hubungan: x.hubungan.trim(), hp: x.hp.trim(),
      jumlah_orang: Number(x.jumlah_orang) || 1, catatan: x.catatan.trim(), foto_id: fotoId })
    ui.toast(h?.luar_jadwal ? 'Kunjungan tercatat (di luar jadwal). Musyrif telah dikabari.' : 'Kunjungan tercatat. Musyrif telah dikabari untuk memanggil santri.')
    lembar.value = false; cakupan.value = 'berlangsung'; await muat()
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
async function pulang(k) {
  if (!(await ui.konfirmasi({ judul: 'Kunjungan selesai', pesan: `Catat ${k.pengunjung} pulang dari kunjungan ${k.nama}?`, ya: 'Catat pulang' }))) return
  try { await sc.kunjunganPulang(k.id); ui.toast('Kunjungan selesai dicatat.'); await muat() } catch (e) { ui.toast(e.message, 'galat') }
}

const periode = computed(() => (cakupan.value === 'berlangsung' ? 'Kunjungan berlangsung per ' + formatPanjang(hariIniISO()) : mulai.value === selesai.value ? formatPanjang(mulai.value) : `${formatPanjang(mulai.value)} s.d. ${formatPanjang(selesai.value)}`))
function ekspor() {
  const judul = ['No.', 'Datang', 'Pulang', 'Nama santri', 'Kelas', 'Kamar', 'Pengunjung', 'Hubungan', 'HP', 'Jumlah orang', 'Di luar jadwal', 'Petugas', 'Catatan']
  const isi = tampil.value.map((k, i) => [i + 1, formatWaktu(k.datang_pada), k.pulang_pada ? formatWaktu(k.pulang_pada) : '', k.nama, k.kelas || '', k.kamar || '', k.pengunjung, k.hubungan || '', k.hp || '',
    k.jumlah_orang, k.luar_jadwal ? 'Ya' : '', k.petugas_datang || '', k.catatan || ''])
  const ws = XLSX.utils.aoa_to_sheet([[`Kunjungan Orang Tua – ${periode.value}`], [], judul, ...isi])
  ws['!cols'] = [5, 16, 16, 26, 7, 16, 22, 10, 14, 8, 8, 20, 24].map((w) => ({ wch: w }))
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Kunjungan'); XLSX.writeFile(wb, `Kunjungan-${cakupan.value === 'berlangsung' ? hariIniISO() : mulai.value + '-' + selesai.value}.xlsx`)
}
const pratinjau = ref(false); const penanda = ref({ jabatan: 'Kepala Bidang Kesantrian', nama: '', niy: '' })
watch(pratinjau, async (v) => { if (v) penanda.value = await penandaKelompok({ jenis: 'kamar' }).catch(() => penanda.value) })
</script>
<template>
  <div>
    <div class="flex flex-wrap items-center gap-2">
      <div class="flex gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" aria-label="Saring kunjungan">
        <button v-for="p in [{ k: 'berlangsung', n: 'Berlangsung' }, { k: 'semua', n: 'Riwayat' }]" :key="p.k" type="button" role="radio" :aria-checked="cakupan === p.k" @click="cakupan = p.k"
          :class="['min-h-[40px] rounded-xl px-4 text-sm font-semibold', cakupan === p.k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">{{ p.n }}</button>
      </div>
      <div class="relative min-w-[180px] flex-1"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
        <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari santri atau pengunjung" aria-label="Cari kunjungan" /></div>
      <button class="tombol-garis w-pengajuan min-h-[44px] px-3 text-sm" @click="pratinjau = true"><PhEye :size="18" style="color: var(--c)" /> Cetak</button>
      <button class="tombol-garis w-santri min-h-[44px] px-3 text-sm" @click="ekspor"><PhDownloadSimple :size="18" style="color: var(--c)" /> Excel</button>
      <button v-if="sc.hak.gerbang" class="tombol-utama hidden lg:inline-flex" @click="bukaBaru"><PhUsersThree :size="20" weight="duotone" /> Catat kunjungan</button>
    </div>
    <div v-if="cakupan === 'semua'" class="mt-3 grid grid-cols-2 gap-3 sm:max-w-md"><InputTanggal v-model="mulai" label="Dari" /><InputTanggal v-model="selesai" label="Sampai" /></div>
    <p class="mt-2 flex items-start gap-1.5 text-xs text-teks3"><PhInfo :size="14" class="mt-0.5 shrink-0" /> {{ jadwal }} Membawa santri keluar pondok tetap memerlukan izin.</p>

    <ul class="mt-3 grid gap-3 md:grid-cols-2">
      <li v-for="k in tampil" :key="k.id" class="kartu p-4" :class="k.pulang_pada ? 'w-rekap' : 'w-tahfizh'">
        <div class="flex items-start gap-3">
          <span class="chip-ikon h-11 w-11 shrink-0"><PhUsersThree :size="24" weight="duotone" /></span>
          <div class="min-w-0 flex-1">
            <p class="flex flex-wrap items-center gap-1.5"><b class="leading-snug">{{ k.nama }}{{ k.kelas ? ' – ' + k.kelas : '' }}</b>
              <span class="lencana">{{ k.pulang_pada ? 'Selesai' : 'Berlangsung' }}</span>
              <span v-if="k.luar_jadwal" class="inline-flex items-center gap-1 text-xs font-bold text-merah"><PhWarning :size="14" /> Di luar jadwal</span></p>
            <p class="text-xs text-teks3">{{ k.nis }} · {{ k.kamar || 'Kamar –' }}</p>
            <p class="mt-1.5 text-sm font-semibold">{{ k.pengunjung }}{{ k.hubungan ? ' (' + k.hubungan + ')' : '' }}{{ k.jumlah_orang > 1 ? ' · ' + k.jumlah_orang + ' orang' : '' }}</p>
            <p class="text-xs text-teks2">Datang {{ formatJam(k.datang_pada) }}{{ k.pulang_pada ? ' · pulang ' + formatJam(k.pulang_pada) : '' }} · {{ durasi(lamaMenit(k)) }} · {{ formatWaktu(k.datang_pada).slice(0, 10) }}</p>
            <p v-if="k.catatan" class="text-xs text-teks3">{{ k.catatan }}</p>
            <div class="mt-2 flex items-center gap-2">
              <FotoBerkas v-if="k.foto_id" :id="k.foto_id" alt="Foto kunjungan" ukuran="h-14 w-14" />
              <button v-if="!k.pulang_pada && sc.hak.gerbang" class="tombol-garis min-h-[38px] px-3 text-sm" @click="pulang(k)"><PhSignOut :size="18" /> Catat pulang</button>
            </div>
          </div>
        </div>
      </li>
    </ul>
    <p v-if="!tampil.length && !memuat" class="kartu mt-3 p-8 text-center text-sm text-teks3">{{ cakupan === 'berlangsung' ? 'Tidak ada kunjungan yang sedang berlangsung.' : 'Belum ada kunjungan pada rentang ini.' }}</p>

    <TombolAksi v-if="sc.hak.gerbang" label="Catat kunjungan" :ikon="PhUsersThree" warna="tahfizh" @klik="bukaBaru" />

    <LembarBawah v-model="lembar" judul="Kunjungan orang tua">
      <div class="space-y-3 pb-2">
        <PilihSantriGerbang v-model="baru.santri" label="Santri yang dikunjungi" />
        <div class="grid gap-3 sm:grid-cols-2">
          <div><label class="label-isian" for="kj-pg">Nama pengunjung<span class="text-merah"> *</span></label><input id="kj-pg" v-model="baru.pengunjung" class="isian" /></div>
          <div><label class="label-isian" for="kj-hb">Hubungan</label><input id="kj-hb" v-model="baru.hubungan" class="isian" placeholder="Ayah, ibu, paman, kakak" /></div>
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div><label class="label-isian" for="kj-hp">HP</label><input id="kj-hp" v-model="baru.hp" inputmode="tel" class="isian" /></div>
          <div><label class="label-isian" for="kj-jo">Jumlah orang</label><input id="kj-jo" v-model="baru.jumlah_orang" type="number" min="1" class="isian tabular-nums" /></div>
        </div>
        <textarea v-model="baru.catatan" rows="2" class="isian" placeholder="Catatan (opsional), contoh: membawa makanan untuk kamar" aria-label="Catatan kunjungan" />
        <div class="flex flex-wrap items-center gap-3">
          <label class="tombol-garis cursor-pointer"><PhCamera :size="20" weight="duotone" /> {{ prat ? 'Ganti foto' : 'Foto (opsional)' }}
            <input type="file" accept="image/*" capture="environment" class="sr-only" @change="bacaFoto" /></label>
          <img v-if="prat" :src="prat" alt="Pratinjau foto kunjungan" class="h-16 w-16 rounded-xl object-cover" />
        </div>
        <button class="tombol-utama w-full" :disabled="proses" @click="simpan"><PhUsersThree :size="20" weight="bold" /> {{ proses ? 'Menyimpan…' : 'Simpan kunjungan' }}</button>
      </div>
    </LembarBawah>

    <DokumenCetak kop="pondok" judul="Daftar Kunjungan Orang Tua" :subjudul="periode" v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap" mendatar>
      <table class="tabel kecil">
        <thead><tr><th style="width:4%">No.</th><th style="width:11%">Datang</th><th style="width:7%">Pulang</th><th style="width:18%">Nama santri</th><th style="width:6%">Kelas</th>
          <th style="width:11%">Kamar</th><th>Pengunjung</th><th style="width:5%">Orang</th><th style="width:7%">Luar jadwal</th><th style="width:12%">Petugas</th></tr></thead>
        <tbody>
          <tr v-for="(k, i) in tampil" :key="k.id"><td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ formatWaktu(k.datang_pada) }}</td><td class="tengah">{{ k.pulang_pada ? formatJam(k.pulang_pada) : '–' }}</td>
            <td>{{ k.nama }}</td><td class="tengah">{{ k.kelas || '–' }}</td><td>{{ k.kamar || '–' }}</td><td>{{ k.pengunjung }}{{ k.hubungan ? ' (' + k.hubungan + ')' : '' }}</td>
            <td class="tengah">{{ k.jumlah_orang }}</td><td class="tengah">{{ k.luar_jadwal ? 'Ya' : '–' }}</td><td>{{ k.petugas_datang || '–' }}</td></tr>
          <tr v-if="!tampil.length"><td colspan="10" class="tengah">Tidak ada kunjungan.</td></tr>
        </tbody>
      </table>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: penanda.jabatan || 'Kepala Bidang Kesantrian', nama: penanda.nama, niy: penanda.niy }"
          :kanan="{ jabatan: 'Petugas Security', nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
      </template>
    </DokumenCetak>
  </div>
</template>
