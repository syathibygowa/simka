<!-- SIMKA PRO | src/pages/izin/TabIzin.vue | v1.2 | Fase 8 – Perbaikan: nama menu ringkas | 10/10/2026 -->
<script setup>
// Daftar izin santri. Dipakai di menu Perizinan (cakupan tetap) dan menu Musyrif (disaring per kamar,
// dengan pilihan Menunggu/Aktif/Semua). Aksi sesuai hak dari server: setujui/tolak, ubah, batalkan,
// catat keluar/kembali (hanya petugas Security, Fase 7), WA ke wali.
import { ref, computed, watch, onMounted, onBeforeUnmount } from 'vue'
import {
  PhPaperPlaneTilt, PhCheck, PhX, PhPencilSimple, PhSignOut, PhSignIn, PhWhatsappLogo, PhHourglass, PhWarningCircle, PhCheckCircle, PhUser, PhMagnifyingGlass, PhProhibit,
} from '@phosphor-icons/vue'
import { useIzin } from '@/stores/izin'
import { useSantri } from '@/stores/santri'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { STATUS_IZIN, PERAN_PENGUSUL, JENIS_IZIN, labelIzin, rentangIzin } from '@/lib/izin'
import { kontakUtama, labelRombel } from '@/lib/santri'
import { formatWaktu, hariIniISO } from '@/lib/tanggal'
import { pesanWA, tautanWA } from '@/lib/wa'
import KartuStatistik from '@/components/KartuStatistik.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import TombolAksi from '@/components/TombolAksi.vue'
import LembarAjukanIzin from './LembarAjukanIzin.vue'

const props = defineProps({
  cakupan: { type: String, default: '' },        // persetujuan | aktif | semua — kosong = pilihan di dalam tab
  group: { type: String, default: '' },          // saring kamar/kelompok
  calon: { type: Array, default: null },         // santri yang dapat diajukan (menu Musyrif: anggota kamar)
  peranUtama: { type: String, default: '' },     // peran pengusul yang didahulukan (menu Musyrif: musyrif)
})
const iz = useIzin(); const san = useSantri(); const sesi = useSesi(); const ui = useUI()
const pilihan = ref('menunggu'); const daftar = ref([]); const memuat = ref(false); const cari = ref('')
const awal = () => { const d = new Date(`${hariIniISO()}T00:00:00`); d.setDate(d.getDate() - 30); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}` }
const mulai = ref(awal()); const selesai = ref(hariIniISO())
const cak = computed(() => props.cakupan || pilihan.value)

async function muat() {
  memuat.value = true
  try {
    if (!iz.hakDimuat) await iz.muatHak()
    daftar.value = await iz.daftar(cak.value, { mulai: cak.value === 'semua' ? mulai.value : null, selesai: cak.value === 'semua' ? selesai.value : null, group: props.group || null })
  } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
onMounted(async () => { await san.muat(); muat(); iz.dengarkan(muat) })
onBeforeUnmount(() => iz.berhenti())
watch(() => [cak.value, props.group, mulai.value, selesai.value], muat)

const tampil = computed(() => { const q = cari.value.toLowerCase().trim(); return daftar.value.filter((x) => !q || `${x.nama} ${x.nis} ${x.alasan} ${x.kamar || ''}`.toLowerCase().includes(q)) })
const n = (f) => daftar.value.filter(f).length
const statistik = computed(() => [
  { judul: 'Menunggu', nilai: n((x) => ['diajukan', 'disetujui_bidang'].includes(x.status)), ikon: PhHourglass, warna: 'pengajuan', ket: 'Belum diputus' },
  { judul: 'Di luar pondok', nilai: n((x) => x.status === 'keluar'), ikon: PhSignOut, warna: 'shift', ket: 'Sedang izin' },
  { judul: 'Terlambat kembali', nilai: n((x) => x.status === 'keluar' && x.terlambat), ikon: PhWarningCircle, warna: 'klinik', ket: 'Lewat batas' },
  { judul: 'Disetujui', nilai: n((x) => x.status === 'disetujui'), ikon: PhCheckCircle, warna: 'presensi', ket: 'Belum keluar' },
])

// ---------- Aksi ----------
const lembarAjukan = ref(false); const izinUbah = ref(null)
function ajukan() { izinUbah.value = null; lembarAjukan.value = true }
function ubah(x) { izinUbah.value = x; lembarAjukan.value = true }
const lembarPutus = ref(false); const pilih = ref(null); const keputusan = ref('setuju'); const catatan = ref(''); const proses = ref(false)
function bukaPutus(x, k) { pilih.value = x; keputusan.value = k; catatan.value = ''; lembarPutus.value = true }
async function putus() {
  if (keputusan.value === 'tolak' && catatan.value.trim().length < 5) return ui.toast('Tuliskan alasan penolakan (minimal 5 huruf).', 'galat')
  proses.value = true
  try {
    const h = await iz.putuskan(pilih.value.id, keputusan.value, catatan.value.trim())
    ui.toast(h === 'disetujui_bidang' ? 'Disetujui. Izin diteruskan ke Direktur/Wakil Direktur.' : h === 'ditolak' ? 'Izin ditolak.' : 'Izin disetujui. Santri otomatis berstatus Izin di absensi.')
    lembarPutus.value = false; await muat()
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
const lembarBatal = ref(false); const alasanBatal = ref('')
function batal(x) { pilih.value = x; alasanBatal.value = ''; lembarBatal.value = true }
async function kirimBatal() {
  if (alasanBatal.value.trim().length < 5) return ui.toast('Tuliskan alasan pembatalan (minimal 5 huruf).', 'galat')
  proses.value = true
  try { await iz.batalkan(pilih.value.id, alasanBatal.value.trim()); lembarBatal.value = false; ui.toast('Izin dibatalkan.'); await muat() }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
async function catat(x, aksi) {
  if (!(await ui.konfirmasi({ judul: aksi === 'keluar' ? 'Catat santri keluar' : 'Catat santri kembali', pesan: `${x.nama} ${aksi === 'keluar' ? 'keluar' : 'kembali ke'} pondok sekarang (${formatWaktu(new Date().toISOString())} WITA)?`, ya: 'Catat' }))) return
  try { await iz.catat(x.id, aksi); ui.toast(aksi === 'keluar' ? 'Keluar dicatat.' : 'Kembali dicatat. Status absensi kembali normal.'); await muat() } catch (e) { ui.toast(e.message, 'galat') }
}
function waWali(x) {
  const s = san.cari(x.student_id); const k = s ? kontakUtama(s) : null
  if (!k?.no_hp) return ui.toast('Nomor HP orang tua/wali santri ini belum diisi.', 'galat')
  const status = { diajukan: 'sedang diajukan', disetujui_bidang: 'sedang diajukan', disetujui: 'telah disetujui', keluar: 'sedang berlangsung', kembali: 'telah selesai', ditolak: 'tidak disetujui', dibatalkan: 'dibatalkan' }[x.status]
  const pesan = pesanWA('izin_santri', { nama_wali: k.nama || 'orang tua/wali', nama_santri: x.nama, kelas: s ? labelRombel(s) : x.kelas || '', jenis_izin: x.jenis === 'keluar' ? 'keluar' : 'pulang',
    status, alasan: x.alasan, waktu_keluar: formatWaktu(x.keluar_pada) + ' WITA', batas_kembali: formatWaktu(x.kembali_batas) + ' WITA',
    penjemput: x.penjemput ? `${x.penjemput}${x.hubungan_penjemput ? ' (' + x.hubungan_penjemput + ')' : ''}` : '–', pengirim: sesi.pengguna?.nama_lengkap, jabatan_pengirim: PERAN_PENGUSUL[x.peran_pengusul] || '' })
  window.open(tautanWA(k.no_hp, pesan), '_blank', 'noopener')
}
const kosong = computed(() => ({ persetujuan: 'Tidak ada izin yang menunggu keputusan Anda.', menunggu: 'Tidak ada izin yang menunggu persetujuan.', aktif: 'Tidak ada santri yang sedang izin.', semua: 'Belum ada izin pada rentang ini.' }[cak.value]))
</script>
<template>
  <div>
    <div class="flex flex-wrap items-center gap-2">
      <div v-if="!cakupan" class="flex gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" aria-label="Saring izin">
        <button v-for="p in [{ k: 'menunggu', n: 'Menunggu' }, { k: 'aktif', n: 'Aktif' }, { k: 'semua', n: 'Semua' }]" :key="p.k" type="button" role="radio" :aria-checked="pilihan === p.k" @click="pilihan = p.k"
          :class="['min-h-[40px] rounded-xl px-4 text-sm font-semibold', pilihan === p.k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">{{ p.n }}</button>
      </div>
      <div class="relative min-w-[180px] flex-1"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
        <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari santri atau alasan" aria-label="Cari izin" /></div>
      <button v-if="iz.hak.ajukan" class="tombol-utama hidden lg:inline-flex" @click="ajukan"><PhPaperPlaneTilt :size="20" weight="duotone" /> Ajukan izin</button>
    </div>
    <div v-if="cak === 'semua'" class="mt-3 grid grid-cols-2 gap-3 sm:max-w-md"><InputTanggal v-model="mulai" label="Keluar dari" /><InputTanggal v-model="selesai" label="Sampai" /></div>

    <div class="-mx-4 mt-3 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-4 sm:overflow-visible sm:px-0">
      <KartuStatistik v-for="k in statistik" :key="k.judul" class="w-[44%] shrink-0 snap-start sm:w-auto" :judul="k.judul" :nilai="memuat && !daftar.length ? '…' : k.nilai" :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket" />
    </div>

    <ul class="mt-4 grid gap-3 md:grid-cols-2">
      <li v-for="x in tampil" :key="x.id" class="kartu p-4" :class="['w-' + labelIzin(x).w, x.terlambat && x.status === 'keluar' ? 'izin-lewat' : '']">
        <div class="flex items-start gap-3">
          <span class="chip-ikon h-11 w-11 shrink-0"><component :is="STATUS_IZIN[x.status]?.ikon || PhUser" :size="24" weight="duotone" /></span>
          <div class="min-w-0 flex-1">
            <p class="flex flex-wrap items-center gap-1.5"><b class="truncate">{{ x.nama }}</b><span class="lencana" :class="'w-' + labelIzin(x).w">{{ labelIzin(x).n }}</span></p>
            <p class="text-xs text-teks3">{{ x.nis }} · {{ x.kamar || 'Kamar –' }} · {{ JENIS_IZIN[x.jenis] }} · {{ x.lama_hari }} hari</p>
            <p class="mt-1.5 text-sm font-semibold text-teks">{{ x.alasan }}</p>
            <p class="text-xs text-teks2">{{ rentangIzin(x) }} WITA</p>
            <p class="text-xs text-teks3">Penjemput: {{ x.penjemput ? `${x.penjemput}${x.hubungan_penjemput ? ' (' + x.hubungan_penjemput + ')' : ''}` : 'belum diisi' }}</p>
            <p class="text-xs text-teks3">{{ x.sumber === 'klinik' ? 'Usulan Klinik' : 'Diusulkan ' + (PERAN_PENGUSUL[x.peran_pengusul] || '').toLowerCase() + ' ' + (x.pengusul || '') }} · diputus {{ x.pemutus }}{{ x.perlu_pimpinan ? ' dan Direktur/Wadir' : '' }}</p>
            <p v-if="x.keluar_aktual || x.kembali_pada" class="text-xs text-teks2">{{ x.keluar_aktual ? 'Keluar ' + formatWaktu(x.keluar_aktual) : '' }}{{ x.kembali_pada ? ' · kembali ' + formatWaktu(x.kembali_pada) : '' }}</p>
            <ul v-if="x.keputusan?.length" class="mt-1.5 space-y-0.5 rounded-lg bg-permukaan2 px-2.5 py-1.5 text-xs">
              <li v-for="(k, i) in x.keputusan" :key="i"><b :class="k.keputusan === 'tolak' ? 'text-merah' : ''">{{ k.keputusan === 'setuju' ? 'Disetujui' : 'Ditolak' }}</b> {{ k.sebagai }} · {{ k.oleh }} · {{ formatWaktu(k.pada) }}{{ k.catatan ? ' · ' + k.catatan : '' }}</li>
            </ul>
            <div class="mt-3 flex flex-wrap gap-2">
              <template v-if="x.boleh_putus">
                <button class="tombol-utama min-h-[38px] px-3 text-sm" @click="bukaPutus(x, 'setuju')"><PhCheck :size="18" weight="bold" /> Setujui</button>
                <button class="tombol-garis min-h-[38px] px-3 text-sm" @click="bukaPutus(x, 'tolak')"><PhX :size="18" /> Tolak</button>
              </template>
              <button v-if="x.boleh_catat && x.status === 'disetujui'" class="tombol-garis w-shift min-h-[38px] px-3 text-sm" @click="catat(x, 'keluar')"><PhSignOut :size="18" style="color: var(--c)" /> Catat keluar</button>
              <button v-if="x.boleh_catat" class="tombol-garis w-rekap min-h-[38px] px-3 text-sm" @click="catat(x, 'kembali')"><PhSignIn :size="18" style="color: var(--c)" /> Catat kembali</button>
              <button v-if="x.boleh_ubah" class="tombol-garis min-h-[38px] px-3 text-sm" @click="ubah(x)"><PhPencilSimple :size="18" /> Ubah</button>
              <button class="tombol-garis w-presensi min-h-[38px] px-3 text-sm" @click="waWali(x)"><PhWhatsappLogo :size="18" weight="duotone" style="color: var(--c)" /> Wali</button>
              <button v-if="x.boleh_batal" class="tombol-garis min-h-[38px] px-3 text-sm" @click="batal(x)"><PhProhibit :size="18" /> Batalkan</button>
            </div>
          </div>
        </div>
      </li>
    </ul>
    <p v-if="!tampil.length && !memuat" class="kartu mt-4 p-8 text-center text-sm text-teks3">{{ kosong }}</p>
    <p class="mt-4 text-xs text-teks3">Pencatatan keluar dan kembali santri dilakukan petugas Security di gerbang (menu Security).</p>

    <TombolAksi v-if="iz.hak.ajukan" label="Ajukan izin" :ikon="PhPaperPlaneTilt" warna="pengajuan" @klik="ajukan" />
    <LembarAjukanIzin v-model="lembarAjukan" :izin="izinUbah" :calon="calon" :peran-utama="peranUtama" @selesai="muat" />
    <LembarBawah v-model="lembarPutus" :judul="keputusan === 'setuju' ? 'Setujui izin' : 'Tolak izin'">
      <div v-if="pilih" class="space-y-3 pb-2">
        <p class="text-sm"><b>{{ pilih.nama }}</b> · {{ JENIS_IZIN[pilih.jenis] }} · {{ pilih.lama_hari }} hari<br /><span class="text-teks2">{{ pilih.alasan }}</span><br /><span class="text-xs text-teks3">{{ rentangIzin(pilih) }} WITA</span></p>
        <p v-if="keputusan === 'setuju' && pilih.perlu_pimpinan && pilih.status === 'diajukan' && !iz.hak.puncak" class="rounded-xl bg-permukaan2 p-3 text-xs text-teks2">Izin lebih dari {{ iz.pengaturan.batas_hari_bidang }} hari: setelah Anda setujui, izin diteruskan ke Direktur/Wakil Direktur.</p>
        <textarea v-model="catatan" rows="2" class="isian" :placeholder="keputusan === 'tolak' ? 'Alasan penolakan (wajib)' : 'Catatan (opsional)'" aria-label="Catatan keputusan" />
        <button class="tombol-utama w-full" :disabled="proses" @click="putus"><component :is="keputusan === 'setuju' ? PhCheck : PhX" :size="20" weight="bold" /> {{ keputusan === 'setuju' ? 'Setujui izin' : 'Tolak izin' }}</button>
      </div>
    </LembarBawah>
    <LembarBawah v-model="lembarBatal" judul="Batalkan izin">
      <div v-if="pilih" class="space-y-3 pb-2">
        <p class="text-sm"><b>{{ pilih.nama }}</b> · {{ pilih.alasan }}</p>
        <textarea v-model="alasanBatal" rows="2" class="isian" placeholder="Alasan pembatalan, contoh: keluarga batal menjemput" aria-label="Alasan pembatalan" />
        <button class="tombol-utama w-full" :disabled="proses" @click="kirimBatal"><PhProhibit :size="20" /> Batalkan izin</button>
      </div>
    </LembarBawah>
  </div>
</template>
<style scoped>
.izin-lewat { border-color: var(--c); box-shadow: inset 4px 0 0 var(--c); }
</style>
