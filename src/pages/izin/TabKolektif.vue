<!-- SIMKA PRO | src/pages/izin/TabKolektif.vue | v1.1 | 14.22.0: WA ke Kepala Bidang Kesantrian, Direktur, dan Wakil Direktur untuk semua yang berwenang | 25/10/2026 -->
<script setup>
// Izin kolektif: satu pengajuan untuk beberapa santri walau berbeda kelas, kamar, atau jenjang (mis. lomba di luar pondok).
// Mekanisme: diputus satu kali oleh Kepala Bidang Kesantrian (lalu Direktur/Wadir bila melebihi batas hari) untuk semua
// santri; musyrif, wali kelas, dan kepala sekolah santri terkait menerima tembusan; setelah disetujui terbit satu Surat Izin
// Kolektif bernomor dan berkode validasi; Security mencatat keluar/kembali sekaligus. Tombol WA: minta persetujuan ke pemutus
// tingkat yang sedang ditunggu, dan kabar ke orang tua/wali tiap santri.
import { ref, computed, watch, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { PhPaperPlaneTilt, PhCheck, PhX, PhSignOut, PhSignIn, PhProhibit, PhFileText, PhUsersThree, PhMapPin, PhUserCircle, PhInfo, PhCaretDown, PhMagnifyingGlass, PhHourglass, PhCheckCircle } from '@phosphor-icons/vue'
import { useIzin } from '@/stores/izin'
import { useSantri } from '@/stores/santri'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { STATUS_KOLEKTIF, STATUS_IZIN, JENIS_IZIN, rentangIzin, adaSurat, dataMintaKolektif, dataWaliKolektif } from '@/lib/izin'
import { kontakUtama } from '@/lib/santri'
import { formatWaktu } from '@/lib/tanggal'
import { pesanWA } from '@/lib/wa'
import TombolWA from '@/components/TombolWA.vue'
import TombolAksi from '@/components/TombolAksi.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import KartuStatistik from '@/components/KartuStatistik.vue'
import CetakSuratKolektif from './CetakSuratKolektif.vue'
import LembarAjukanKolektif from './LembarAjukanKolektif.vue'

const route = useRoute(); const iz = useIzin(); const san = useSantri(); const sesi = useSesi(); const ui = useUI()
const daftar = ref([]); const memuat = ref(false); const cari = ref(''); const terbuka = ref({}); const kontak = ref([])
async function muat() {
  memuat.value = true
  try {
    daftar.value = await iz.daftarKolektif('semua')
    const fokus = route.query.izin; if (fokus) terbuka.value = { ...terbuka.value, [fokus]: true }
    if (daftar.value.some((k) => ['diajukan', 'disetujui_bidang'].includes(k.status))) kontak.value = await iz.kontakPemutus('KESANTRIAN').catch(() => [])
  } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
onMounted(async () => { await san.muat(); muat() })
watch(() => route.query.izin, muat)

const tampil = computed(() => {
  const q = cari.value.toLowerCase().trim(); const fokus = route.query.izin
  return daftar.value.filter((k) => (!q || `${k.kegiatan} ${k.tempat || ''} ${k.anggota.map((a) => a.nama).join(' ')}`.toLowerCase().includes(q)))
    .sort((a, b) => (b.id === fokus) - (a.id === fokus))
})
const n = (f) => daftar.value.filter(f).length
const statistik = computed(() => [
  { judul: 'Menunggu', nilai: n((k) => ['diajukan', 'disetujui_bidang'].includes(k.status)), ikon: PhHourglass, warna: 'pengajuan', ket: 'Belum diputus' },
  { judul: 'Disetujui', nilai: n((k) => k.status === 'disetujui'), ikon: PhCheckCircle, warna: 'presensi', ket: 'Berlaku' },
  { judul: 'Santri di luar', nilai: daftar.value.reduce((t, k) => t + k.anggota.filter((a) => a.status === 'keluar').length, 0), ikon: PhSignOut, warna: 'shift', ket: 'Sedang kegiatan' },
  { judul: 'Selesai', nilai: n((k) => k.status === 'selesai'), ikon: PhSignIn, warna: 'rekap', ket: '120 hari terakhir' },
])
const aktifAnggota = (k) => k.anggota.filter((a) => !['dibatalkan', 'ditolak'].includes(a.status))
const ringkasSebaran = (k) => { const kel = new Set(aktifAnggota(k).map((a) => a.kelas || '–')); const kmr = new Set(aktifAnggota(k).map((a) => a.kamar || '–')); return `${kel.size} kelas · ${kmr.size} kamar` }

// ---------- WA ----------
const tingkat = (k) => (k.status === 'disetujui_bidang' ? 2 : 1)
const menungguWA = (k) => ['diajukan', 'disetujui_bidang'].includes(k.status)
// 14.22.0: termasuk Direktur/Wakil Direktur bila izin melebihi batas hari; pemutus tidak mengirim ke dirinya sendiri
const pemutusWA = (k) => kontak.value.filter((p) => (p.tingkat === tingkat(k) || (k.perlu_pimpinan && p.tingkat === 2)) && p.employee_id !== sesi.pengguna?.id)
const pesanMinta = (k, p) => pesanWA('izin_kolektif_minta', { ...dataMintaKolektif(k, p), pengirim: sesi.pengguna?.nama_lengkap })
const wali = (a) => { const s = san.cari(a.student_id); return s ? kontakUtama(s) : null }
const pesanWali = (k, a) => pesanWA('izin_kolektif_wali', { ...dataWaliKolektif(k, a, wali(a)), pengirim: sesi.pengguna?.nama_lengkap, jabatan_pengirim: k.pendamping === sesi.pengguna?.nama_lengkap ? 'Pendamping' : '' })

// ---------- Aksi ----------
const lembarAjukan = ref(false); const lembarKonfirmasi = ref(false); const baru = ref(null)
async function selesaiAjukan(id) {
  await muat(); baru.value = daftar.value.find((k) => k.id === id) || null
  if (baru.value) { kontak.value = await iz.kontakPemutus('KESANTRIAN').catch(() => []); terbuka.value = { ...terbuka.value, [id]: true }; lembarKonfirmasi.value = true }
}
const lembarPutus = ref(false); const pilih = ref(null); const keputusan = ref('setuju'); const catatan = ref(''); const proses = ref(false)
function bukaPutus(k, x) { pilih.value = k; keputusan.value = x; catatan.value = ''; lembarPutus.value = true }
async function putus() {
  if (keputusan.value === 'tolak' && catatan.value.trim().length < 5) return ui.toast('Tuliskan alasan penolakan (minimal 5 huruf).', 'galat')
  proses.value = true
  try {
    const h = await iz.putuskanKolektif(pilih.value.id, keputusan.value, catatan.value.trim())
    ui.toast(h === 'disetujui_bidang' ? 'Disetujui. Izin kolektif diteruskan ke Direktur/Wakil Direktur.' : h === 'ditolak' ? 'Izin kolektif ditolak.' : 'Disetujui. Surat izin kolektif terbit dan semua santri berstatus Izin di absensi.')
    lembarPutus.value = false; await muat()
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
const lembarBatal = ref(false); const alasanBatal = ref('')
function batal(k) { pilih.value = k; alasanBatal.value = ''; lembarBatal.value = true }
async function kirimBatal() {
  if (alasanBatal.value.trim().length < 5) return ui.toast('Tuliskan alasan pembatalan (minimal 5 huruf).', 'galat')
  proses.value = true
  try { await iz.batalkanKolektif(pilih.value.id, alasanBatal.value.trim()); lembarBatal.value = false; ui.toast('Izin kolektif dibatalkan; surat dicabut.'); await muat() }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
async function catat(k, aksi) {
  const jml = k.anggota.filter((a) => a.status === (aksi === 'keluar' ? 'disetujui' : 'keluar')).length
  if (!jml) return ui.toast(aksi === 'keluar' ? 'Tidak ada santri yang menunggu dicatat keluar.' : 'Tidak ada santri yang sedang di luar.', 'galat')
  if (!(await ui.konfirmasi({ judul: aksi === 'keluar' ? 'Catat semua keluar' : 'Catat semua kembali', pesan: `${jml} santri ${k.kegiatan} ${aksi === 'keluar' ? 'keluar' : 'kembali ke'} pondok sekarang (${formatWaktu(new Date().toISOString())} WITA)?`, ya: 'Catat' }))) return
  try {
    const h = await iz.catatKolektif(k.id, aksi)
    ui.toast(`${h.tercatat} santri dicatat ${aksi}.${h.gagal?.length ? ` ${h.gagal.length} gagal: ${h.gagal.map((g) => g.nama || g).join(', ')}` : ''}`); await muat()
  } catch (e) { ui.toast(e.message, 'galat') }
}
const cetak = ref(null); const pratinjau = ref(false)
function surat(k) { cetak.value = k; pratinjau.value = true }
</script>
<template>
  <div>
    <div class="kartu w-ekskul flex items-start gap-3 p-4 text-sm">
      <span class="chip-ikon h-10 w-10 shrink-0"><PhInfo :size="22" weight="duotone" /></span>
      <p class="text-teks2"><b class="text-teks">Mekanisme izin kolektif.</b> Santri dari kelas, kamar, atau jenjang berbeda diajukan dalam satu pengajuan dan diputus sekali oleh
        Kepala Bidang Kesantrian (lalu Direktur/Wakil Direktur bila lebih dari {{ iz.pengaturan.batas_hari_bidang }} hari). Musyrif, wali kelas, dan kepala sekolah santri terkait
        menerima tembusan. Setelah disetujui terbit satu Surat Izin Kolektif; Security mencatat keluar/kembali semua santri sekaligus.</p>
    </div>
    <div class="mt-3 flex flex-wrap items-center gap-2">
      <div class="relative min-w-[220px] flex-1"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
        <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari kegiatan atau nama santri" aria-label="Cari izin kolektif" /></div>
      <button v-if="iz.hak.kolektif" class="tombol-utama hidden lg:inline-flex" @click="lembarAjukan = true"><PhPaperPlaneTilt :size="20" weight="duotone" /> Ajukan izin kolektif</button>
    </div>
    <div class="-mx-4 mt-3 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-4 sm:overflow-visible sm:px-0">
      <KartuStatistik v-for="s in statistik" :key="s.judul" class="w-[44%] shrink-0 snap-start sm:w-auto" :judul="s.judul" :nilai="memuat && !daftar.length ? '…' : s.nilai" :ikon="s.ikon" :warna="s.warna" :keterangan="s.ket" />
    </div>

    <ul class="mt-4 space-y-3">
      <li v-for="k in tampil" :key="k.id" class="kartu p-4" :class="['w-' + (STATUS_KOLEKTIF[k.status]?.w || 'hakakses'), $route.query.izin === k.id ? 'kol-fokus' : '']">
        <div class="flex items-start gap-3">
          <span class="chip-ikon h-11 w-11 shrink-0"><PhUsersThree :size="24" weight="duotone" /></span>
          <div class="min-w-0 flex-1">
            <p class="flex flex-wrap items-center gap-1.5"><b>{{ k.kegiatan }}</b><span class="lencana" :class="'w-' + STATUS_KOLEKTIF[k.status]?.w">{{ STATUS_KOLEKTIF[k.status]?.n || k.status }}</span></p>
            <p class="text-xs text-teks3">{{ aktifAnggota(k).length }} santri · {{ ringkasSebaran(k) }} · {{ JENIS_IZIN[k.jenis] }} · {{ k.lama_hari }} hari</p>
            <p class="mt-1.5 text-sm text-teks">{{ k.alasan }}</p>
            <p class="flex items-center gap-1 text-xs text-teks2"><PhMapPin :size="14" /> {{ k.tempat || 'Tempat belum diisi' }} · {{ rentangIzin(k) }} WITA</p>
            <p class="flex items-center gap-1 text-xs text-teks3"><PhUserCircle :size="14" /> Pendamping {{ k.pendamping || '–' }}{{ k.hp_pendamping ? ' (' + k.hp_pendamping + ')' : '' }} · diusulkan {{ k.pengusul || '–' }}</p>
            <p v-if="k.nomor_surat" class="text-xs text-teks3">Surat {{ k.nomor_surat }}</p>
            <ul v-if="k.keputusan?.length" class="mt-1.5 space-y-0.5 rounded-lg bg-permukaan2 px-2.5 py-1.5 text-xs">
              <li v-for="(x, i) in k.keputusan" :key="i"><b :class="x.keputusan === 'tolak' ? 'text-merah' : ''">{{ x.keputusan === 'setuju' ? 'Disetujui' : 'Ditolak' }}</b> {{ x.sebagai }} · {{ x.oleh }} · {{ formatWaktu(x.pada) }}{{ x.catatan ? ' · ' + x.catatan : '' }}</li>
            </ul>
            <div class="mt-3 flex flex-wrap gap-2">
              <template v-if="k.boleh_putus">
                <button class="tombol-utama min-h-[38px] px-3 text-sm" @click="bukaPutus(k, 'setuju')"><PhCheck :size="18" weight="bold" /> Setujui semua</button>
                <button class="tombol-garis min-h-[38px] px-3 text-sm" @click="bukaPutus(k, 'tolak')"><PhX :size="18" /> Tolak</button>
              </template>
              <template v-if="menungguWA(k)">
                <TombolWA v-for="p in pemutusWA(k)" :key="p.employee_id || p.nama" kecil :hp="p.no_hp" :pesan="pesanMinta(k, p)" :label="`${p.tingkat === tingkat(k) ? 'Minta persetujuan' : 'Kabari'} ${p.nama} (${p.tingkat === 2 ? p.jabatan : 'Ka. Bid. Kesantrian'})`" />
                <span v-if="!pemutusWA(k).length" class="self-center text-xs text-teks3">Kontak pemutus belum tercatat.</span>
              </template>
              <button v-if="k.boleh_catat" class="tombol-garis w-shift min-h-[38px] px-3 text-sm" @click="catat(k, 'keluar')"><PhSignOut :size="18" style="color: var(--c)" /> Catat semua keluar</button>
              <button v-if="k.boleh_catat" class="tombol-garis w-rekap min-h-[38px] px-3 text-sm" @click="catat(k, 'kembali')"><PhSignIn :size="18" style="color: var(--c)" /> Catat semua kembali</button>
              <button v-if="adaSurat(k)" class="tombol-garis w-tatausaha min-h-[38px] px-3 text-sm" @click="surat(k)"><PhFileText :size="18" weight="duotone" style="color: var(--c)" /> Surat</button>
              <button v-if="k.boleh_batal" class="tombol-garis min-h-[38px] px-3 text-sm" @click="batal(k)"><PhProhibit :size="18" /> Batalkan</button>
              <button class="tombol-garis min-h-[38px] px-3 text-sm" :aria-expanded="!!terbuka[k.id]" @click="terbuka = { ...terbuka, [k.id]: !terbuka[k.id] }">
                <PhCaretDown :size="18" :class="terbuka[k.id] && 'rotate-180'" /> Santri &amp; WA wali</button>
            </div>
            <ul v-if="terbuka[k.id]" class="mt-3 divide-y divide-garis rounded-xl border border-garis">
              <li v-for="a in k.anggota" :key="a.student_id" class="flex flex-wrap items-center gap-2 px-3 py-2">
                <div class="min-w-0 flex-1"><p class="truncate text-sm font-semibold">{{ a.nama }}</p>
                  <p class="text-xs text-teks3">{{ a.nis }} · {{ a.jenis_kelamin || '–' }} · {{ a.kelas || 'Kelas –' }} · {{ a.kamar || 'Kamar –' }}</p>
                  <p v-if="a.keluar_aktual" class="text-xs text-teks2">Keluar {{ formatWaktu(a.keluar_aktual) }}{{ a.kembali_pada ? ' · kembali ' + formatWaktu(a.kembali_pada) : '' }}</p></div>
                <span class="lencana" :class="'w-' + (a.terlambat ? 'klinik' : STATUS_IZIN[a.status]?.w || 'hakakses')">{{ a.terlambat ? 'Terlambat' : STATUS_IZIN[a.status]?.n || a.status }}</span>
                <TombolWA kecil :hp="wali(a)?.no_hp" :pesan="pesanWali(k, a)" :label="wali(a)?.nama ? `Wali: ${wali(a).nama}` : 'Wali'" />
              </li>
            </ul>
          </div>
        </div>
      </li>
    </ul>
    <p v-if="!tampil.length && !memuat" class="kartu mt-4 p-8 text-center text-sm text-teks3">Belum ada izin kolektif. {{ iz.hak.kolektif ? 'Ketuk "Ajukan izin kolektif" untuk lomba atau kegiatan luar beberapa santri.' : '' }}</p>

    <TombolAksi v-if="iz.hak.kolektif" label="Ajukan izin kolektif" :ikon="PhPaperPlaneTilt" warna="ekskul" @klik="lembarAjukan = true" />
    <LembarAjukanKolektif v-model="lembarAjukan" @selesai="selesaiAjukan" />
    <CetakSuratKolektif v-model:pratinjau="pratinjau" :kolektif="cetak" />

    <LembarBawah v-model="lembarKonfirmasi" judul="Izin kolektif terkirim">
      <div v-if="baru" class="space-y-4 pb-2">
        <p class="flex items-start gap-2 rounded-xl bg-permukaan2 p-3 text-sm"><PhCheckCircle :size="22" weight="duotone" class="shrink-0 text-[#1E7D4F] dark:text-[#5BD69A]" />
          <span>Izin kolektif <b>{{ baru.kegiatan }}</b> ({{ aktifAnggota(baru).length }} santri, {{ ringkasSebaran(baru) }}) menunggu keputusan Kepala Bidang Kesantrian{{ baru.perlu_pimpinan ? ', lalu Direktur/Wakil Direktur' : '' }}.
            Pemutus dan pengasuh santri sudah menerima notifikasi SIMKA.</span></p>
        <div><p class="label-isian">Langkah 1 · minta persetujuan Kepala Bidang Kesantrian</p>
          <div class="flex flex-wrap gap-2"><TombolWA v-for="p in pemutusWA(baru)" :key="p.employee_id || p.nama" :hp="p.no_hp" :pesan="pesanMinta(baru, p)" :label="`${p.nama} (${p.jabatan})`" />
            <p v-if="!pemutusWA(baru).length" class="text-sm text-teks3">Kepala Bidang Kesantrian belum tercatat di Data Pegawai (jabatan struktural).</p></div></div>
        <p v-if="baru.perlu_pimpinan" class="text-sm text-teks2"><b>Langkah 2</b> · setelah disetujui kepala bidang, tombol "Minta persetujuan pimpinan" muncul pada kartu ini.</p>
        <p class="text-sm text-teks2"><b>Langkah {{ baru.perlu_pimpinan ? 3 : 2 }}</b> · kabari orang tua/wali tiap santri lewat tombol WA pada daftar "Santri &amp; WA wali".</p>
        <button class="tombol-garis w-full" @click="lembarKonfirmasi = false">Selesai</button>
      </div>
    </LembarBawah>
    <LembarBawah v-model="lembarPutus" :judul="keputusan === 'setuju' ? 'Setujui izin kolektif' : 'Tolak izin kolektif'">
      <div v-if="pilih" class="space-y-3 pb-2">
        <p class="text-sm"><b>{{ pilih.kegiatan }}</b> · {{ aktifAnggota(pilih).length }} santri · {{ pilih.lama_hari }} hari<br /><span class="text-teks2">{{ pilih.alasan }}</span><br /><span class="text-xs text-teks3">{{ rentangIzin(pilih) }} WITA</span></p>
        <p class="text-xs text-teks2">{{ aktifAnggota(pilih).map((a) => a.nama).join(', ') }}</p>
        <p v-if="keputusan === 'setuju' && pilih.perlu_pimpinan && pilih.status === 'diajukan'" class="rounded-xl bg-permukaan2 p-3 text-xs text-teks2">Lebih dari {{ iz.pengaturan.batas_hari_bidang }} hari: setelah Anda setujui, izin diteruskan ke Direktur/Wakil Direktur.</p>
        <textarea v-model="catatan" rows="2" class="isian" :placeholder="keputusan === 'tolak' ? 'Alasan penolakan (wajib)' : 'Catatan (opsional)'" aria-label="Catatan keputusan" />
        <button class="tombol-utama w-full" :disabled="proses" @click="putus"><component :is="keputusan === 'setuju' ? PhCheck : PhX" :size="20" weight="bold" /> {{ keputusan === 'setuju' ? 'Setujui untuk semua santri' : 'Tolak izin kolektif' }}</button>
      </div>
    </LembarBawah>
    <LembarBawah v-model="lembarBatal" judul="Batalkan izin kolektif">
      <div v-if="pilih" class="space-y-3 pb-2">
        <p class="text-sm"><b>{{ pilih.kegiatan }}</b> · {{ aktifAnggota(pilih).length }} santri</p>
        <textarea v-model="alasanBatal" rows="2" class="isian" placeholder="Alasan pembatalan, contoh: lomba ditunda panitia" aria-label="Alasan pembatalan" />
        <button class="tombol-utama w-full" :disabled="proses" @click="kirimBatal"><PhProhibit :size="20" /> Batalkan izin kolektif</button>
      </div>
    </LembarBawah>
  </div>
</template>
<style scoped>
.kol-fokus { border-color: var(--c); box-shadow: inset 4px 0 0 var(--c); }
</style>
