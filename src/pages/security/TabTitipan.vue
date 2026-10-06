<!-- SIMKA PRO | src/pages/security/TabTitipan.vue | v1.0 | Fase 7 – Tahap 2 Titipan, buku tamu, kunjungan | 06/10/2026 -->
<script setup>
// Titipan barang/uang untuk santri (Blueprint Bagian 24). Mencegah paket hilang di pos:
//   Terima : santri penerima, jenis, uraian, pengirim, ekspedisi, FOTO BARANG WAJIB → musyrif dinotifikasi.
//   Serahkan: siapa yang mengambil (santri/musyrif/wali/lainnya) + nama + FOTO PENGAMBIL BERSAMA BARANG WAJIB.
//   Kembalikan ke pengirim (alasan), Batalkan salah catat (pengelola Security).
// Pengasuh melihat titipan santri asuhannya. Riwayat per rentang: Excel dan cetak F4.
import { ref, computed, watch, onMounted, onBeforeUnmount } from 'vue'
import * as XLSX from 'xlsx'
import { PhPackage, PhHandArrowDown, PhArrowUUpLeft, PhProhibit, PhWhatsappLogo, PhCamera, PhMagnifyingGlass, PhEye, PhDownloadSimple, PhClock, PhWarning } from '@phosphor-icons/vue'
import { useSecurity } from '@/stores/security'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { JENIS_TITIPAN, STATUS_TITIPAN, PENGAMBIL, rupiah, durasi } from '@/lib/security'
import { unggahFotoSecurity } from '@/lib/fotoSecurity'
import { penandaKelompok } from '@/lib/santri'
import { pesanWA, tautanWA } from '@/lib/wa'
import { formatWaktu, formatPanjang, hariIniISO } from '@/lib/tanggal'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import FotoBerkas from '@/components/FotoBerkas.vue'
import TombolAksi from '@/components/TombolAksi.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import PilihSantriGerbang from './PilihSantriGerbang.vue'

const sc = useSecurity(); const sesi = useSesi(); const ui = useUI()
const cakupan = ref('di_pos'); const mulai = ref(hariIniISO().slice(0, 8) + '01'); const selesai = ref(hariIniISO()); const cari = ref('')
const daftar = ref([]); const memuat = ref(false)
async function muat() {
  memuat.value = true
  try { daftar.value = await sc.daftarTitipan(cakupan.value, mulai.value, selesai.value) } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
watch([cakupan, mulai, selesai], muat)
onMounted(() => { muat(); sc.dengarkan(muat) })
onBeforeUnmount(() => sc.berhenti())
const tampil = computed(() => { const q = cari.value.toLowerCase().trim(); return daftar.value.filter((t) => !q || `${t.nama} ${t.nis} ${t.kelas || ''} ${t.kamar || ''} ${t.uraian} ${t.pengirim}`.toLowerCase().includes(q)) })
const batasJam = computed(() => Number(sc.pengaturan.pengingat_titipan_hari || 2) * 24)
const lama = (t) => t.status === 'di_pos' && t.lama_jam >= batasJam.value

// ---------- Foto ----------
function bacaFoto(e, simpan) {
  const f = e.target.files?.[0]; e.target.value = ''
  if (!f) return
  if (!/^image\//.test(f.type)) return ui.toast('Pilih berkas foto.', 'galat')
  simpan(f, URL.createObjectURL(f))
}

// ---------- Terima ----------
const lembarTerima = ref(false); const proses = ref(false)
const baru = ref({}); const fotoT = ref(null); const pratT = ref('')
function bukaTerima() { baru.value = { santri: null, jenis: 'paket', uraian: '', nominal: '', pengirim: '', hp_pengirim: '', ekspedisi: '', catatan: '' }; fotoT.value = null; pratT.value = ''; lembarTerima.value = true }
async function simpanTerima() {
  const x = baru.value
  if (!x.santri) return ui.toast('Pilih santri penerima titipan.', 'galat')
  if (x.uraian.trim().length < 3) return ui.toast('Tuliskan uraian barang.', 'galat')
  if (x.pengirim.trim().length < 2) return ui.toast('Isi nama pengirim.', 'galat')
  if (x.jenis === 'uang' && !(Number(x.nominal) > 0)) return ui.toast('Isi nominal uang titipan.', 'galat')
  if (!fotoT.value) return ui.toast('Ambil foto barang saat diterima (wajib).', 'galat')
  proses.value = true
  try {
    const foto = await unggahFotoSecurity(fotoT.value, { nama: x.santri.nama, nis: x.santri.nis, jenis: 'Titipan', folder: 'Titipan' })
    await sc.terimaTitipan({ student_id: x.santri.student_id, jenis: x.jenis, uraian: x.uraian.trim(), nominal: x.jenis === 'uang' ? Number(x.nominal) : null,
      pengirim: x.pengirim.trim(), hp_pengirim: x.hp_pengirim.trim(), ekspedisi: x.ekspedisi.trim(), catatan: x.catatan.trim(), foto_terima_id: foto })
    ui.toast('Titipan tercatat. Musyrif santri telah dikabari.'); lembarTerima.value = false; cakupan.value = 'di_pos'; await muat()
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}

// ---------- Serahkan ----------
const lembarAmbil = ref(false); const pilih = ref(null); const ambil = ref({}); const fotoA = ref(null); const pratA = ref('')
function bukaAmbil(t) { pilih.value = t; ambil.value = { jenis: 'santri', nama: t.nama, catatan: '' }; fotoA.value = null; pratA.value = ''; lembarAmbil.value = true }
watch(() => ambil.value.jenis, (j) => { if (lembarAmbil.value && pilih.value) ambil.value.nama = j === 'santri' ? pilih.value.nama : '' })
async function simpanAmbil() {
  const a = ambil.value
  if (a.nama.trim().length < 2) return ui.toast('Isi nama pengambil.', 'galat')
  if (!fotoA.value) return ui.toast('Ambil foto pengambil bersama barang (wajib).', 'galat')
  proses.value = true
  try {
    const foto = await unggahFotoSecurity(fotoA.value, { nama: pilih.value.nama, nis: pilih.value.nis, jenis: 'Ambil', folder: 'Titipan' })
    await sc.ambilTitipan(pilih.value.id, { pengambil_jenis: a.jenis, pengambil_nama: a.nama.trim(), foto_ambil_id: foto, catatan: a.catatan.trim() })
    ui.toast('Penyerahan titipan tercatat.'); lembarAmbil.value = false; await muat()
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}

// ---------- Kembalikan / batalkan ----------
const lembarTutup = ref(false); const modeTutup = ref('dikembalikan'); const alasan = ref('')
function bukaTutup(t, m) { pilih.value = t; modeTutup.value = m; alasan.value = ''; lembarTutup.value = true }
async function simpanTutup() {
  if (alasan.value.trim().length < 5) return ui.toast('Tuliskan alasan (minimal 5 huruf).', 'galat')
  proses.value = true
  try { await sc.tutupTitipan(pilih.value.id, modeTutup.value, alasan.value.trim()); ui.toast(modeTutup.value === 'batal' ? 'Titipan dibatalkan.' : 'Titipan dicatat dikembalikan ke pengirim.'); lembarTutup.value = false; await muat() }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}

// ---------- WA ke wali ----------
function waWali(t) {
  if (!t.wali?.no_hp) return ui.toast('Nomor HP orang tua/wali santri ini belum diisi.', 'galat')
  const barang = `${JENIS_TITIPAN[t.jenis].n}: ${t.uraian}${t.jenis === 'uang' ? ' (' + rupiah(t.nominal) + ')' : ''}`
  const pesan = pesanWA('titipan_santri', { nama_wali: t.wali.nama || 'orang tua/wali', nama_santri: t.nama, kelas: t.kelas || '', barang, pengirim_titipan: t.pengirim,
    status_titipan: t.status === 'diambil' ? 'telah diserahkan' : 'telah diterima di pos Security pondok', waktu_terima: formatWaktu(t.diterima_pada) + ' WITA',
    pengambilan: t.status === 'diambil' ? `• Diambil: ${t.pengambil_nama} (${PENGAMBIL[t.pengambil_jenis] || ''}), ${formatWaktu(t.diambil_pada)} WITA` : '' })
  window.open(tautanWA(t.wali.no_hp, pesan), '_blank', 'noopener')
}

// ---------- Ekspor dan cetak ----------
const periode = computed(() => (cakupan.value === 'di_pos' ? 'Titipan yang masih di pos per ' + formatPanjang(hariIniISO()) : mulai.value === selesai.value ? formatPanjang(mulai.value) : `${formatPanjang(mulai.value)} s.d. ${formatPanjang(selesai.value)}`))
const pengambilan = (t) => (t.status === 'di_pos' ? '–' : `${t.pengambil_nama || '–'}${t.pengambil_jenis ? ' (' + PENGAMBIL[t.pengambil_jenis] + ')' : ''}, ${formatWaktu(t.diambil_pada)}`)
function ekspor() {
  const judul = ['No.', 'Diterima', 'Nama santri', 'Kelas', 'Kamar', 'Jenis', 'Uraian', 'Nominal', 'Pengirim', 'Ekspedisi', 'Petugas penerima', 'Status', 'Diambil/dikembalikan', 'Petugas penyerah', 'Catatan']
  const isi = tampil.value.map((t, i) => [i + 1, formatWaktu(t.diterima_pada), t.nama, t.kelas || '', t.kamar || '', JENIS_TITIPAN[t.jenis].n, t.uraian, t.nominal || '', t.pengirim, t.ekspedisi || '',
    t.penerima || '', STATUS_TITIPAN[t.status].n, pengambilan(t), t.penyerah || '', t.catatan || ''])
  const ws = XLSX.utils.aoa_to_sheet([[`Titipan Santri – ${periode.value}`], [], judul, ...isi])
  ws['!cols'] = [5, 16, 26, 7, 16, 10, 30, 11, 20, 14, 20, 13, 30, 20, 26].map((w) => ({ wch: w }))
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Titipan'); XLSX.writeFile(wb, `Titipan-Santri-${cakupan.value === 'di_pos' ? hariIniISO() : mulai.value + '-' + selesai.value}.xlsx`)
}
const pratinjau = ref(false); const penanda = ref({ jabatan: 'Kepala Bidang Kesantrian', nama: '', niy: '' })
watch(pratinjau, async (v) => { if (v) penanda.value = await penandaKelompok({ jenis: 'kamar' }).catch(() => penanda.value) })
</script>
<template>
  <div>
    <div class="flex flex-wrap items-center gap-2">
      <div class="flex gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" aria-label="Saring titipan">
        <button v-for="p in [{ k: 'di_pos', n: 'Di pos' }, { k: 'semua', n: 'Riwayat' }]" :key="p.k" type="button" role="radio" :aria-checked="cakupan === p.k" @click="cakupan = p.k"
          :class="['min-h-[40px] rounded-xl px-4 text-sm font-semibold', cakupan === p.k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">{{ p.n }}</button>
      </div>
      <div class="relative min-w-[180px] flex-1"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
        <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari santri, barang, atau pengirim" aria-label="Cari titipan" /></div>
      <button class="tombol-garis w-pengajuan min-h-[44px] px-3 text-sm" @click="pratinjau = true"><PhEye :size="18" style="color: var(--c)" /> Cetak</button>
      <button class="tombol-garis w-santri min-h-[44px] px-3 text-sm" @click="ekspor"><PhDownloadSimple :size="18" style="color: var(--c)" /> Excel</button>
      <button v-if="sc.hak.gerbang" class="tombol-utama hidden lg:inline-flex" @click="bukaTerima"><PhPackage :size="20" weight="duotone" /> Terima titipan</button>
    </div>
    <div v-if="cakupan === 'semua'" class="mt-3 grid grid-cols-2 gap-3 sm:max-w-md"><InputTanggal v-model="mulai" label="Diterima dari" /><InputTanggal v-model="selesai" label="Sampai" /></div>
    <p class="mt-2 text-xs text-teks3">{{ tampil.length }} titipan · titipan di pos lebih dari {{ sc.pengaturan.pengingat_titipan_hari || 2 }} hari ditandai dan diingatkan ke musyrif.</p>

    <ul class="mt-3 grid gap-3 md:grid-cols-2">
      <li v-for="t in tampil" :key="t.id" class="kartu p-4" :class="['w-' + (lama(t) ? 'klinik' : STATUS_TITIPAN[t.status].w), lama(t) && 'lewat']">
        <div class="flex items-start gap-3">
          <span class="chip-ikon h-11 w-11 shrink-0" :class="'w-' + JENIS_TITIPAN[t.jenis].w"><component :is="JENIS_TITIPAN[t.jenis].ikon" :size="24" weight="duotone" /></span>
          <div class="min-w-0 flex-1">
            <p class="flex flex-wrap items-center gap-1.5"><b class="leading-snug">{{ t.nama }}{{ t.kelas ? ' – ' + t.kelas : '' }}</b><span class="lencana">{{ STATUS_TITIPAN[t.status].n }}</span></p>
            <p class="text-xs text-teks3">{{ t.nis }} · {{ t.kamar || 'Kamar –' }}</p>
            <p class="mt-1.5 text-sm font-semibold">{{ JENIS_TITIPAN[t.jenis].n }}: {{ t.uraian }}<span v-if="t.jenis === 'uang'"> · {{ rupiah(t.nominal) }}</span></p>
            <p class="text-xs text-teks2">Dari {{ t.pengirim }}{{ t.hp_pengirim ? ' (' + t.hp_pengirim + ')' : '' }}{{ t.ekspedisi ? ' · ' + t.ekspedisi : '' }}</p>
            <p class="text-xs text-teks2">Diterima {{ formatWaktu(t.diterima_pada) }} oleh {{ t.penerima || '–' }}</p>
            <p v-if="t.status === 'di_pos'" class="flex items-center gap-1 text-xs" :class="lama(t) ? 'font-bold text-merah' : 'text-teks3'">
              <component :is="lama(t) ? PhWarning : PhClock" :size="14" /> Di pos {{ durasi(t.lama_jam * 60) }}</p>
            <p v-else class="text-xs text-teks2">{{ t.status === 'batal' ? 'Dibatalkan' : 'Diserahkan ke ' + pengambilan(t) }}{{ t.penyerah ? ' · petugas ' + t.penyerah : '' }}</p>
            <p v-if="t.catatan" class="text-xs text-teks3">{{ t.catatan }}</p>
            <div class="mt-2 flex gap-2">
              <figure v-if="t.foto_terima_id" class="text-center text-[10px] text-teks3"><FotoBerkas :id="t.foto_terima_id" alt="Foto titipan saat diterima" ukuran="h-16 w-16" /><figcaption>Diterima</figcaption></figure>
              <figure v-if="t.foto_ambil_id" class="text-center text-[10px] text-teks3"><FotoBerkas :id="t.foto_ambil_id" alt="Foto pengambil titipan" ukuran="h-16 w-16" /><figcaption>Diambil</figcaption></figure>
            </div>
            <div class="mt-3 flex flex-wrap gap-2">
              <template v-if="t.status === 'di_pos' && sc.hak.gerbang">
                <button class="tombol-utama min-h-[38px] px-3 text-sm" @click="bukaAmbil(t)"><PhHandArrowDown :size="18" weight="bold" /> Serahkan</button>
                <button class="tombol-garis min-h-[38px] px-3 text-sm" @click="bukaTutup(t, 'dikembalikan')"><PhArrowUUpLeft :size="18" /> Kembalikan</button>
              </template>
              <button v-if="t.status === 'di_pos' && sc.hak.kelola" class="tombol-garis min-h-[38px] px-3 text-sm" @click="bukaTutup(t, 'batal')"><PhProhibit :size="18" /> Batalkan</button>
              <button v-if="t.status !== 'batal'" class="tombol-garis w-presensi min-h-[38px] px-3 text-sm" @click="waWali(t)"><PhWhatsappLogo :size="18" weight="duotone" style="color: var(--c)" /> Wali</button>
            </div>
          </div>
        </div>
      </li>
    </ul>
    <p v-if="!tampil.length && !memuat" class="kartu mt-3 p-8 text-center text-sm text-teks3">{{ cakupan === 'di_pos' ? 'Tidak ada titipan di pos.' : 'Belum ada titipan pada rentang ini.' }}</p>

    <TombolAksi v-if="sc.hak.gerbang" label="Terima titipan" :ikon="PhPackage" warna="security" @klik="bukaTerima" />

    <LembarBawah v-model="lembarTerima" judul="Terima titipan">
      <div class="space-y-3 pb-2">
        <PilihSantriGerbang v-model="baru.santri" label="Santri penerima" />
        <div><p class="label-isian">Jenis</p>
          <div class="flex flex-wrap gap-2" role="radiogroup" aria-label="Jenis titipan">
            <button v-for="(j, k) in JENIS_TITIPAN" :key="k" type="button" role="radio" :aria-checked="baru.jenis === k" @click="baru.jenis = k"
              :class="['flex min-h-[40px] items-center gap-1.5 rounded-xl border px-3 text-sm font-semibold', 'w-' + j.w, baru.jenis === k ? 'pilih-aktif text-teks' : 'border-garis text-teks2']">
              <component :is="j.ikon" :size="18" weight="duotone" style="color: var(--c)" /> {{ j.n }}</button>
          </div></div>
        <div><label class="label-isian" for="tt-ur">Uraian barang<span class="text-merah"> *</span></label><input id="tt-ur" v-model="baru.uraian" class="isian" placeholder="Contoh: kardus sedang, isi makanan dan buku" /></div>
        <div v-if="baru.jenis === 'uang'"><label class="label-isian" for="tt-nm">Nominal (Rp)<span class="text-merah"> *</span></label><input id="tt-nm" v-model="baru.nominal" type="number" min="0" inputmode="numeric" class="isian tabular-nums" /></div>
        <div class="grid gap-3 sm:grid-cols-2">
          <div><label class="label-isian" for="tt-pg">Pengirim<span class="text-merah"> *</span></label><input id="tt-pg" v-model="baru.pengirim" class="isian" placeholder="Nama pengirim" /></div>
          <div><label class="label-isian" for="tt-hp">HP pengirim</label><input id="tt-hp" v-model="baru.hp_pengirim" inputmode="tel" class="isian" placeholder="08…" /></div>
        </div>
        <div><label class="label-isian" for="tt-ek">Ekspedisi/cara datang</label><input id="tt-ek" v-model="baru.ekspedisi" class="isian" placeholder="JNE, J&T, diantar langsung, ojek" /></div>
        <div class="flex flex-wrap items-center gap-3">
          <label class="tombol-garis cursor-pointer"><PhCamera :size="20" weight="duotone" /> {{ pratT ? 'Ganti foto' : 'Foto barang (wajib)' }}
            <input type="file" accept="image/*" capture="environment" class="sr-only" @change="(e) => bacaFoto(e, (f, u) => { fotoT = f; pratT = u })" /></label>
          <img v-if="pratT" :src="pratT" alt="Pratinjau foto titipan" class="h-16 w-16 rounded-xl object-cover" />
        </div>
        <textarea v-model="baru.catatan" rows="2" class="isian" placeholder="Catatan (opsional), contoh: kardus sedikit penyok" aria-label="Catatan titipan" />
        <button class="tombol-utama w-full" :disabled="proses" @click="simpanTerima"><PhPackage :size="20" weight="bold" /> {{ proses ? 'Menyimpan…' : 'Simpan titipan' }}</button>
      </div>
    </LembarBawah>

    <LembarBawah v-model="lembarAmbil" judul="Serahkan titipan">
      <div v-if="pilih" class="space-y-3 pb-2">
        <p class="text-sm"><b>{{ pilih.nama }}{{ pilih.kelas ? ' – ' + pilih.kelas : '' }}</b><br /><span class="text-teks2">{{ JENIS_TITIPAN[pilih.jenis].n }}: {{ pilih.uraian }}</span></p>
        <div><p class="label-isian">Diambil oleh</p>
          <div class="flex flex-wrap gap-2" role="radiogroup" aria-label="Pengambil titipan">
            <button v-for="k in ['santri', 'musyrif', 'wali', 'lainnya']" :key="k" type="button" role="radio" :aria-checked="ambil.jenis === k" @click="ambil.jenis = k"
              :class="['min-h-[40px] rounded-xl border px-3 text-sm font-semibold', 'w-security', ambil.jenis === k ? 'pilih-aktif text-teks' : 'border-garis text-teks2']">{{ PENGAMBIL[k] }}</button>
          </div></div>
        <div><label class="label-isian" for="ta-nm">Nama pengambil<span class="text-merah"> *</span></label><input id="ta-nm" v-model="ambil.nama" class="isian" placeholder="Nama orang yang mengambil" /></div>
        <div class="flex flex-wrap items-center gap-3">
          <label class="tombol-garis cursor-pointer"><PhCamera :size="20" weight="duotone" /> {{ pratA ? 'Ganti foto' : 'Foto pengambil + barang (wajib)' }}
            <input type="file" accept="image/*" capture="environment" class="sr-only" @change="(e) => bacaFoto(e, (f, u) => { fotoA = f; pratA = u })" /></label>
          <img v-if="pratA" :src="pratA" alt="Pratinjau foto pengambil" class="h-16 w-16 rounded-xl object-cover" />
        </div>
        <textarea v-model="ambil.catatan" rows="2" class="isian" placeholder="Catatan (opsional)" aria-label="Catatan penyerahan" />
        <button class="tombol-utama w-full" :disabled="proses" @click="simpanAmbil"><PhHandArrowDown :size="20" weight="bold" /> {{ proses ? 'Menyimpan…' : 'Simpan penyerahan' }}</button>
      </div>
    </LembarBawah>

    <LembarBawah v-model="lembarTutup" :judul="modeTutup === 'batal' ? 'Batalkan titipan' : 'Kembalikan ke pengirim'">
      <div v-if="pilih" class="space-y-3 pb-2">
        <p class="text-sm"><b>{{ pilih.nama }}</b> · {{ pilih.uraian }} · dari {{ pilih.pengirim }}</p>
        <textarea v-model="alasan" rows="2" class="isian" :placeholder="modeTutup === 'batal' ? 'Alasan pembatalan, contoh: salah memilih santri' : 'Alasan, contoh: alamat salah, diambil kembali pengirim'" aria-label="Alasan" />
        <button class="tombol-utama w-full" :disabled="proses" @click="simpanTutup"><component :is="modeTutup === 'batal' ? PhProhibit : PhArrowUUpLeft" :size="20" /> Simpan</button>
      </div>
    </LembarBawah>

    <DokumenCetak kop="pondok" judul="Daftar Titipan Santri" :subjudul="periode" v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap" mendatar>
      <table class="tabel kecil">
        <thead><tr><th style="width:4%">No.</th><th style="width:11%">Diterima</th><th style="width:16%">Nama santri</th><th style="width:5%">Kelas</th><th style="width:10%">Kamar</th>
          <th style="width:17%">Barang</th><th style="width:11%">Pengirim</th><th style="width:8%">Status</th><th>Pengambilan</th><th style="width:10%">Petugas</th></tr></thead>
        <tbody>
          <tr v-for="(t, i) in tampil" :key="t.id"><td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ formatWaktu(t.diterima_pada) }}</td><td>{{ t.nama }}</td><td class="tengah">{{ t.kelas || '–' }}</td>
            <td>{{ t.kamar || '–' }}</td><td>{{ JENIS_TITIPAN[t.jenis].n }}: {{ t.uraian }}{{ t.jenis === 'uang' ? ' (' + rupiah(t.nominal) + ')' : '' }}</td><td>{{ t.pengirim }}</td>
            <td class="tengah">{{ STATUS_TITIPAN[t.status].n }}</td><td>{{ pengambilan(t) }}</td><td>{{ t.penyerah || t.penerima || '–' }}</td></tr>
          <tr v-if="!tampil.length"><td colspan="10" class="tengah">Tidak ada titipan.</td></tr>
        </tbody>
      </table>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: penanda.jabatan || 'Kepala Bidang Kesantrian', nama: penanda.nama, niy: penanda.niy }"
          :kanan="{ jabatan: 'Petugas Security', nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
      </template>
    </DokumenCetak>
  </div>
</template>
<style scoped>
.lewat { border-color: var(--c); box-shadow: inset 4px 0 0 var(--c); }
.pilih-aktif { border-color: var(--c); background: color-mix(in srgb, var(--c) 12%, rgb(var(--permukaan))); }
</style>
