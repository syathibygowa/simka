<!-- SIMKA PRO | src/pages/tahfizh/TabKhataman.vue | v1.2 | 14.21.0: hapus usulan khataman yang dibatalkan/ditolak (admin/superadmin) | 24/10/2026 -->
<script setup>
// Khataman Al-Qur'an 30 juz.
//   Muhaffizh: "Usulkan khataman" untuk santri yang sudah khatam 30 juz (usulan tanggal, jam, tempat).
//   Kepala Bidang Tahfizh: setujui (boleh mengubah jadwal/tempat) atau tolak. Setelah disetujui terbit Surat Undangan (ber-QR) dan
//   Sertifikat Penghargaan Khataman (tanda tangan elektronik Direktur dan Kepala Bidang Tahfizh) yang siap diserahkan saat khataman.
//   WhatsApp: pengumuman grup (salin teks), undangan ke orang tua (dikirim muhaffizh), kabar ke muhaffizh.
//   Ubah jadwal (riwayat tersimpan; undangan dan sertifikat ikut diperbarui), tandai terlaksana (tercatat sebagai prestasi santri), batalkan.
//   v1.1: Khataman susulan — pengelola khataman mencatat khataman yang sudah terlaksana sebelum SIMKA dipakai (tanggal lampau):
//         langsung terlaksana, sertifikat bertanggal hari khataman terbit dan menunggu tanda tangan elektronik.
//   v1.2 (14.21.0): admin/superadmin dapat menghapus usulan khataman yang dibatalkan atau ditolak.
import { ref, computed, onMounted, watch } from 'vue'
import { PhCrown, PhPaperPlaneTilt, PhCheckCircle, PhXCircle, PhCalendarBlank, PhClockCounterClockwise, PhPrinter, PhCertificate, PhEnvelopeSimple,
  PhWhatsappLogo, PhUsersThree, PhHourglass, PhMapPin, PhX, PhConfetti, PhCalendarCheck as PhSusulan, PhMagnifyingGlass, PhTrash } from '@phosphor-icons/vue'
import { useTahfizh } from '@/stores/tahfizh'
import { useUI } from '@/stores/ui'
import { useSantri } from '@/stores/santri'
import { STATUS_KHATAMAN, PENGATURAN_KHATAMAN } from '@/lib/dokumenTahfizh'
import { formatHari, formatJam, formatWaktu, formatPendek, hariIniISO } from '@/lib/tanggal'
import { pesanWA, halamanAplikasi } from '@/lib/wa'
import { alamatCek } from '@/lib/dokumen'
import KartuStatistik from '@/components/KartuStatistik.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import LembarLaporanGrup from '@/components/LembarLaporanGrup.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import InputJam from '@/components/InputJam.vue'
import TombolWA from '@/components/TombolWA.vue'
import { useSesi } from '@/stores/sesi'
import PratinjauWA from '@/components/PratinjauWA.vue'
import CetakUndanganKhataman from './CetakUndanganKhataman.vue'
import CetakDokumenTahfizh from './CetakDokumenTahfizh.vue'

const tz = useTahfizh(); const ui = useUI(); const sesi = useSesi()
const status = ref('berjalan'); const daftar = ref([]); const memuat = ref(false); const proses = ref(false); const calon = ref([])
async function muat() {
  memuat.value = true
  try { [daftar.value, calon.value] = await Promise.all([tz.daftarKhataman(status.value || null), tz.calonKhataman().catch(() => [])]) }
  catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
const bolehKelola = ref(false)
onMounted(async () => { muat(); bolehKelola.value = await tz.bolehKelolaKhataman() }); watch(status, muat)
const statistik = computed(() => [
  { judul: 'Calon khataman', nilai: calon.value.length, ikon: PhCrown, warna: 'prestasi', ket: 'Sudah khatam 30 juz, belum diusulkan' },
  { judul: 'Menunggu persetujuan', nilai: daftar.value.filter((k) => k.status === 'diusulkan').length, ikon: PhHourglass, warna: 'pengajuan', ket: 'Diputuskan Kepala Bidang Tahfizh' },
  { judul: 'Dijadwalkan', nilai: daftar.value.filter((k) => k.status === 'dijadwalkan').length, ikon: PhCalendarBlank, warna: 'agenda', ket: 'Undangan dan sertifikat siap' },
  { judul: 'Terlaksana', nilai: daftar.value.filter((k) => k.status === 'selesai').length, ikon: PhConfetti, warna: 'presensi', ket: 'Pada saringan ini' },
])
const keISO = (tgl, jam) => (tgl ? new Date(`${tgl}T${(jam || '08:00').slice(0, 5)}:00+08:00`).toISOString() : null)
const dariISO = (iso) => { const d = new Date(new Date(iso).getTime() + 8 * 3600e3).toISOString(); return { tgl: d.slice(0, 10), jam: d.slice(11, 16) } }

// ---------- Usul ----------
const lembarUsul = ref(false); const fu = ref({}); const pilihSantri = ref(null)
function bukaUsul(s = null) { pilihSantri.value = s; fu.value = { tgl: hariIniISO(), jam: '08:00', tempat: PENGATURAN_KHATAMAN.tempat_bawaan, catatan: '' }; lembarUsul.value = true }
async function kirimUsul() {
  if (!pilihSantri.value) return ui.toast('Pilih santri yang diusulkan.', 'galat')
  if (!fu.value.tgl) return ui.toast('Isi tanggal khataman.', 'galat')
  proses.value = true
  try { await tz.usulkanKhataman({ student_id: pilihSantri.value.student_id, jadwal: keISO(fu.value.tgl, fu.value.jam), tempat: fu.value.tempat.trim(), catatan: fu.value.catatan.trim() })
    lembarUsul.value = false; ui.toast('Usulan khataman terkirim kepada Kepala Bidang Tahfizh.'); status.value = 'berjalan'; await muat() }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}

// ---------- Susulan (14.17.0) ----------
const san = useSantri(); const lembarSusulan = ref(false); const fs = ref({}); const cariSusulan = ref('')
async function bukaSusulan() {
  fs.value = { santri: null, tgl: hariIniISO(), jam: '08:00', tempat: PENGATURAN_KHATAMAN.tempat_bawaan, keterangan: '', konfirmasi: false }; cariSusulan.value = ''
  lembarSusulan.value = true; if (!san.daftar.length) san.muat().catch(() => {})
}
const sudahKhataman = computed(() => new Set(daftar.value.filter((k) => ['diusulkan', 'dijadwalkan', 'selesai'].includes(k.status)).map((k) => k.student_id)))
const calonSusulan = computed(() => { const q = cariSusulan.value.toLowerCase().trim(); if (q.length < 2) return []
  return san.daftar.filter((x) => ['aktif', 'lulus'].includes(x.status) && !sudahKhataman.value.has(x.id) && `${x.nama_lengkap} ${x.nis}`.toLowerCase().includes(q)).slice(0, 8) })
const khatamTercatat = computed(() => !!fs.value.santri && calon.value.some((c) => c.student_id === fs.value.santri.id))
async function simpanSusulan() {
  const f = fs.value
  if (!f.santri) return ui.toast('Pilih santri.', 'galat')
  if (!f.tgl || f.tgl > hariIniISO()) return ui.toast('Isi tanggal khataman yang sudah lewat.', 'galat')
  if (f.keterangan.trim().length < 5) return ui.toast('Tuliskan keterangan (minimal 5 huruf).', 'galat')
  if (!khatamTercatat.value && !f.konfirmasi) return ui.toast('Centang konfirmasi bahwa santri sudah khatam 30 juz.', 'galat')
  proses.value = true
  try {
    await tz.catatKhatamanSusulan({ student_id: f.santri.id, tanggal: f.tgl, jam: f.jam, tempat: f.tempat.trim(), keterangan: f.keterangan.trim(), konfirmasi_30: f.konfirmasi })
    lembarSusulan.value = false; ui.toast('Khataman susulan tercatat. Sertifikat terbit dan menunggu tanda tangan elektronik Direktur dan Kepala Bidang Tahfizh.')
    status.value = 'selesai'; await muat()
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}

// ---------- Putuskan ----------
const lembarPutus = ref(false); const kp = ref(null); const fp = ref({})
function bukaPutus(k) { kp.value = k; const j = dariISO(k.jadwal); fp.value = { tgl: j.tgl, jam: j.jam, tempat: k.tempat || '', alasan: '' }; lembarPutus.value = true }
async function putus(setuju) {
  if (!setuju && fp.value.alasan.trim().length < 5) return ui.toast('Tuliskan alasan penolakan (minimal 5 huruf).', 'galat')
  proses.value = true
  try {
    await tz.putuskanKhataman(kp.value.id, setuju, setuju ? { jadwal: keISO(fp.value.tgl, fp.value.jam), tempat: fp.value.tempat.trim() } : { alasan: fp.value.alasan.trim() })
    lembarPutus.value = false; ui.toast(setuju ? 'Khataman disetujui. Undangan dan sertifikat terbit.' : 'Usulan khataman ditolak.'); await muat()
    if (setuju) { const k = daftar.value.find((x) => x.id === kp.value.id); if (k) bukaWA(k) }
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}

// ---------- Ubah jadwal ----------
const lembarUbah = ref(false); const fj = ref({})
function bukaUbah(k) { kp.value = k; const j = dariISO(k.jadwal); fj.value = { tgl: j.tgl, jam: j.jam, tempat: k.tempat || '', alasan: '' }; lembarUbah.value = true }
async function simpanUbah() {
  if (kp.value.status === 'dijadwalkan' && fj.value.alasan.trim().length < 5) return ui.toast('Tuliskan alasan perubahan jadwal (minimal 5 huruf).', 'galat')
  proses.value = true
  try { await tz.ubahJadwalKhataman(kp.value.id, keISO(fj.value.tgl, fj.value.jam), fj.value.tempat.trim(), fj.value.alasan.trim())
    lembarUbah.value = false; ui.toast(kp.value.status === 'dijadwalkan' ? 'Jadwal diubah. Undangan dan sertifikat diperbarui; kabari kembali orang tua.' : 'Usulan jadwal diubah.'); await muat()
    if (kp.value.status === 'dijadwalkan') { const k = daftar.value.find((x) => x.id === kp.value.id); if (k) bukaWA(k) } }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}

// ---------- Selesai dan batal ----------
const lembarAkhir = ref(false); const mode = ref('selesai'); const catAkhir = ref('')
function bukaAkhir(k, m) { kp.value = k; mode.value = m; catAkhir.value = ''; lembarAkhir.value = true }
async function simpanAkhir() {
  proses.value = true
  try {
    if (mode.value === 'selesai') { await tz.selesaikanKhataman(kp.value.id, catAkhir.value.trim()); ui.toast('Khataman tercatat terlaksana dan masuk riwayat prestasi santri. Barakallahu fiik.') }
    else { await tz.batalkanKhataman(kp.value.id, catAkhir.value.trim()); ui.toast('Khataman dibatalkan; undangan dan sertifikat dicabut.') }
    lembarAkhir.value = false; await muat()
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}

// ---------- WhatsApp ----------
const lembarWA = ref(false); const kw = ref(null); const lembarGrup = ref(false); const teksGrup = ref(''); const pratinjauKe = ref(0)
const dataWA = (k, nama) => ({ nama, nama_wali: String(k.wali?.nama || '').replace(/^(bapak|ibu)\s+/i, ''), nama_santri: k.nama, kelas: k.kelas, halaqah: k.halaqah, tanggal: formatHari(k.jadwal), waktu: `${formatJam(k.jadwal)} WITA`,
  tempat: k.tempat, nomor: k.undangan?.nomor, tautan_cek: k.undangan?.kode ? alamatCek(k.undangan.kode) : '', tautan: halamanAplikasi('/tahfizh/khataman') })
const pesanKe = computed(() => {
  const k = kw.value; if (!k) return []
  return [
    { nama: k.wali?.nama || 'Orang tua/wali', hp: k.wali?.no_hp, ket: 'Undangan ke orang tua/wali (dikirim muhaffizh)', pesan: pesanWA('khataman_undangan_wali', dataWA(k, k.wali?.nama)) },
    { nama: k.muhaffizh || k.pengusul || 'Muhaffizh', hp: k.hp_muhaffizh || k.hp_pengusul, ket: 'Kabar persetujuan ke muhaffizh', pesan: pesanWA('khataman_muhaffizh', dataWA(k, k.muhaffizh || k.pengusul)) },
  ]
})
function bukaWA(k) { kw.value = k; pratinjauKe.value = 0; lembarWA.value = true }
function bukaGrup(k) { teksGrup.value = pesanWA('khataman_pengumuman', dataWA(k, '')); lembarGrup.value = true }

// ---------- Cetak ----------
const undangan = ref(null); const pratUndangan = ref(false); const dokSert = ref(null); const pratSert = ref(false)
function cetakUndangan(k) { undangan.value = k; pratUndangan.value = true }
async function cetakSertifikat(k) {
  try { const d = (await tz.daftarDokumen({ id: k.sertifikat.id }))[0]; if (!d) throw new Error('Sertifikat tidak ditemukan.'); dokSert.value = d; pratSert.value = true }
  catch (e) { ui.toast(e.message, 'galat') }
}
// 14.21.0: hapus usulan yang dibatalkan/ditolak (admin/superadmin)
const bolehHapus = (k) => sesi.isAdmin && ['dibatalkan', 'ditolak'].includes(k.status)
const hapusSemua = computed(() => daftar.value.filter(bolehHapus))
async function hapusKhataman(x) {
  if (!x.length) return
  if (!(await ui.konfirmasi({ judul: x.length > 1 ? `Hapus ${x.length} usulan khataman?` : 'Hapus usulan khataman?', pesan: `${x.slice(0, 5).map((k) => k.nama).join(', ')}${x.length > 5 ? ', …' : ''}. Usulan dihapus permanen; undangan dan sertifikat yang pernah terbit tetap tercatat sebagai dicabut.`, ya: 'Hapus', bahaya: true }))) return
  try { const n = await tz.hapusUsulan('khataman', x.map((k) => k.id)); ui.toast(`${n} usulan khataman dihapus.`); await muat() } catch (e) { ui.toast(e.message, 'galat') }
}
const STATUS_TTD = { sah: 'Sah', draf: 'Menunggu tanda tangan', dicabut: 'Dicabut', ditolak: 'Ditolak penanda tangan' }
</script>
<template>
  <div class="w-prestasi">
    <div class="flex flex-wrap items-center gap-2">
      <select v-model="status" class="isian w-auto" aria-label="Saring status">
        <option value="berjalan">Usulan dan terjadwal</option><option value="selesai">Terlaksana</option><option value="ditolak">Ditolak</option><option value="dibatalkan">Dibatalkan</option><option value="">Semua</option></select>
      <span class="flex-1" />
      <button v-if="hapusSemua.length > 1" class="tombol-garis" @click="hapusKhataman(hapusSemua)"><PhTrash :size="20" /> Hapus {{ hapusSemua.length }} usulan batal/ditolak</button>
      <button v-if="bolehKelola" class="tombol-garis" @click="bukaSusulan"><PhSusulan :size="20" weight="duotone" /> Khataman susulan</button>
      <button class="tombol-utama" :disabled="!calon.length" :title="calon.length ? '' : 'Belum ada santri khatam 30 juz di halaqah Anda'" @click="bukaUsul()"><PhPaperPlaneTilt :size="20" weight="duotone" /> Usulkan khataman</button>
    </div>

    <div class="-mx-4 mt-3 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-4 sm:overflow-visible sm:px-0">
      <KartuStatistik v-for="s in statistik" :key="s.judul" class="w-[44%] shrink-0 snap-start sm:w-auto" :judul="s.judul" :nilai="memuat ? '…' : s.nilai" :ikon="s.ikon" :warna="s.warna" :keterangan="s.ket" />
    </div>

    <!-- Calon -->
    <section v-if="calon.length" class="kartu mt-4 p-4">
      <h3 class="judul-bagian mb-2 flex items-center gap-2"><PhCrown :size="20" weight="duotone" style="color: var(--c)" /> Santri khatam 30 juz yang belum diusulkan</h3>
      <ul class="flex flex-wrap gap-2"><li v-for="s in calon" :key="s.student_id">
        <button class="tombol-garis min-h-[40px] px-3 text-sm" @click="bukaUsul(s)"><b>{{ s.nama }}</b> <span class="text-teks3">· {{ s.halaqah || '–' }}</span></button></li></ul>
    </section>

    <ul class="mt-4 grid gap-3 md:grid-cols-2">
      <li v-for="k in daftar" :key="k.id" :class="['kartu p-4', 'w-' + STATUS_KHATAMAN[k.status].w]">
        <div class="flex items-start gap-3">
          <span class="chip-ikon h-11 w-11 shrink-0"><PhCrown :size="24" weight="duotone" /></span>
          <div class="min-w-0 flex-1">
            <p class="flex flex-wrap items-center gap-1.5"><b>{{ k.nama }}</b><span :class="['lencana', 'w-' + STATUS_KHATAMAN[k.status].w]">{{ STATUS_KHATAMAN[k.status].n }}</span><span v-if="k.susulan" class="lencana w-agenda">Susulan</span></p>
            <p class="text-xs text-teks3">{{ k.nis }} · {{ k.kelas || '–' }} · {{ k.halaqah || '–' }} · muhaffizh {{ k.muhaffizh || k.pengusul || '–' }}</p>
            <p class="mt-1.5 flex items-center gap-1.5 text-sm font-semibold"><PhCalendarBlank :size="16" style="color: var(--c)" /> {{ formatHari(k.jadwal) }}, {{ formatJam(k.jadwal) }} WITA</p>
            <p class="flex items-center gap-1.5 text-sm text-teks2"><PhMapPin :size="16" /> {{ k.tempat || '–' }}</p>
            <p class="mt-1 text-xs text-teks3">Diusulkan {{ formatWaktu(k.diusulkan_pada) }} oleh {{ k.pengusul || '–' }}{{ k.catatan_usul ? ' · ' + k.catatan_usul : '' }}</p>
            <p v-if="k.pemutus" class="text-xs text-teks3">{{ k.status === 'ditolak' ? 'Ditolak' : 'Disetujui' }} {{ formatWaktu(k.diputus_pada) }} oleh {{ k.pemutus }}{{ k.alasan_tolak ? ' · ' + k.alasan_tolak : '' }}</p>
            <p v-if="k.alasan_batal" class="text-xs text-teks3">Dibatalkan: {{ k.alasan_batal }}</p>
            <p v-if="k.catatan_selesai" class="text-xs text-teks3">Catatan pelaksanaan: {{ k.catatan_selesai }}</p>
            <details v-if="k.riwayat_jadwal?.length" class="mt-1 text-xs text-teks3"><summary class="cursor-pointer"><PhClockCounterClockwise :size="13" class="inline" /> Riwayat perubahan jadwal ({{ k.riwayat_jadwal.length }})</summary>
              <ul class="mt-1 space-y-0.5"><li v-for="(r, i) in k.riwayat_jadwal" :key="i">{{ formatWaktu(r.jadwal_lama) }} → {{ formatWaktu(r.jadwal_baru) }}{{ r.alasan ? ' · ' + r.alasan : '' }} ({{ r.oleh }})</li></ul></details>
            <div v-if="k.undangan || k.sertifikat" class="mt-2 grid gap-1 rounded-xl bg-permukaan2 p-2 text-xs">
              <p v-if="k.undangan"><PhEnvelopeSimple :size="13" class="inline" /> Undangan {{ k.undangan.nomor }} · <b>{{ STATUS_TTD[k.undangan.status] || k.undangan.status }}</b></p>
              <p v-if="k.sertifikat"><PhCertificate :size="13" class="inline" /> Sertifikat {{ k.sertifikat.nomor }} · <b>{{ k.sertifikat.status === 'dicabut' ? 'Dicabut' : STATUS_TTD[k.sertifikat.status_dokumen] || k.sertifikat.status_dokumen }}</b></p>
            </div>
            <div class="mt-3 flex flex-wrap gap-2">
              <button v-if="k.boleh_putus" class="tombol-utama min-h-[38px] px-3 text-sm" @click="bukaPutus(k)"><PhCheckCircle :size="18" /> Putuskan</button>
              <button v-if="k.boleh_ubah" class="tombol-garis min-h-[38px] px-3 text-sm" @click="bukaUbah(k)"><PhCalendarBlank :size="18" /> Ubah jadwal</button>
              <button v-if="k.undangan" class="tombol-garis min-h-[38px] px-3 text-sm" @click="cetakUndangan(k)"><PhPrinter :size="18" /> Undangan</button>
              <button v-if="k.sertifikat" class="tombol-garis min-h-[38px] px-3 text-sm" @click="cetakSertifikat(k)"><PhCertificate :size="18" /> Sertifikat</button>
              <button v-if="['dijadwalkan', 'selesai'].includes(k.status)" class="tombol-wa-garis w-presensi min-h-[38px] px-3 text-sm" @click="bukaWA(k)"><PhWhatsappLogo :size="18" weight="duotone" /> WA orang tua/muhaffizh</button>
              <button v-if="k.status === 'dijadwalkan'" class="tombol-wa-garis w-presensi min-h-[38px] px-3 text-sm" @click="bukaGrup(k)"><PhUsersThree :size="18" weight="duotone" /> Pengumuman grup</button>
              <button v-if="k.boleh_selesai" class="tombol-garis w-presensi min-h-[38px] px-3 text-sm" @click="bukaAkhir(k, 'selesai')"><PhConfetti :size="18" weight="duotone" style="color: var(--c)" /> Tandai terlaksana</button>
              <button v-if="k.boleh_batal" class="tombol-garis min-h-[38px] px-3 text-sm" @click="bukaAkhir(k, 'batal')"><PhX :size="18" /> Batalkan</button>
              <button v-if="bolehHapus(k)" class="tombol-garis min-h-[38px] px-3 text-sm" @click="hapusKhataman([k])"><PhTrash :size="18" /> Hapus</button>
            </div>
          </div>
        </div>
      </li>
    </ul>
    <p v-if="!daftar.length && !memuat" class="kartu mt-4 p-8 text-center text-sm text-teks3">Belum ada khataman pada saringan ini.</p>

    <!-- Usul -->
    <LembarBawah v-model="lembarUsul" judul="Usulkan khataman Al-Qur'an 30 juz">
      <div class="space-y-3 pb-2">
        <div><label class="label-isian" for="kh-s">Santri</label>
          <select id="kh-s" v-model="pilihSantri" class="isian"><option :value="null" disabled>Pilih santri yang sudah khatam 30 juz</option>
            <option v-for="s in calon" :key="s.student_id" :value="s">{{ s.nama }} · {{ s.halaqah || '–' }} ({{ s.total_resmi >= 30 ? '30 juz resmi' : 'sabaq 30 juz' }})</option></select></div>
        <div class="grid grid-cols-2 gap-3"><InputTanggal v-model="fu.tgl" label="Tanggal khataman" wajib /><InputJam v-model="fu.jam" label="Jam" /></div>
        <div><label class="label-isian" for="kh-t">Tempat</label><input id="kh-t" v-model="fu.tempat" class="isian" /></div>
        <div><label class="label-isian" for="kh-c">Catatan untuk Kepala Bidang Tahfizh</label><input id="kh-c" v-model="fu.catatan" class="isian" placeholder="Contoh: murajaah 30 juz sudah lancar" /></div>
        <button class="tombol-utama w-full" :disabled="proses" @click="kirimUsul"><PhPaperPlaneTilt :size="20" weight="duotone" /> Kirim usulan</button>
      </div>
    </LembarBawah>

    <!-- Susulan -->
    <LembarBawah v-model="lembarSusulan" judul="Catat khataman susulan">
      <div class="space-y-3 pb-2">
        <p class="rounded-xl bg-permukaan2 p-3 text-sm text-teks2">Untuk santri yang sudah khataman sebelum SIMKA dipakai. Khataman langsung tercatat terlaksana pada tanggal tersebut, Sertifikat Penghargaan Khataman terbit bertanggal hari khataman (menunggu tanda tangan elektronik Direktur dan Kepala Bidang Tahfizh), dan tercatat sebagai prestasi santri.</p>
        <div v-if="!fs.santri"><label class="label-isian" for="ks-c">Santri (aktif atau lulus)</label>
          <div class="relative"><PhMagnifyingGlass :size="18" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-teks3" />
            <input id="ks-c" v-model="cariSusulan" class="isian pl-10" placeholder="Ketik nama atau NIS (minimal 2 huruf)" /></div>
          <ul v-if="calonSusulan.length" class="mt-2 divide-y divide-garis rounded-xl border border-garis">
            <li v-for="x in calonSusulan" :key="x.id"><button type="button" class="flex min-h-[44px] w-full items-center gap-2 px-3 text-left text-sm" @click="fs.santri = x">
              <b class="flex-1 truncate">{{ x.nama_lengkap }}</b><span class="text-xs text-teks3">{{ x.nis }}{{ x.status === 'lulus' ? ' · lulus' : '' }}</span></button></li></ul>
          <p v-else-if="cariSusulan.trim().length >= 2" class="mt-2 text-xs text-teks3">Tidak ditemukan, atau khataman santri ini sudah tercatat.</p></div>
        <div v-else class="flex items-center gap-2 rounded-xl border border-garis p-3"><b class="flex-1">{{ fs.santri.nama_lengkap }}</b><span class="text-xs text-teks3">{{ fs.santri.nis }}</span>
          <button type="button" class="tombol-ikon" aria-label="Ganti santri" @click="fs.santri = null"><PhX :size="18" /></button></div>
        <div class="grid grid-cols-2 gap-3"><InputTanggal v-model="fs.tgl" label="Tanggal khataman" wajib /><InputJam v-model="fs.jam" label="Jam" /></div>
        <div><label class="label-isian" for="ks-t">Tempat</label><input id="ks-t" v-model="fs.tempat" class="isian" /></div>
        <div><label class="label-isian" for="ks-k">Keterangan (wajib)</label><input id="ks-k" v-model="fs.keterangan" class="isian" placeholder="Contoh: khataman angkatan 2024, sertifikat belum diterbitkan" /></div>
        <label v-if="fs.santri && !khatamTercatat" class="flex items-start gap-3 rounded-xl border border-garis p-3 text-sm"><input v-model="fs.konfirmasi" type="checkbox" class="mt-0.5 h-5 w-5 shrink-0 accent-[#C7332F]" />
          <span>Hafalan 30 juz santri ini belum tercatat di SIMKA. Saya memastikan santri ini <b>sudah khatam 30 juz</b>.</span></label>
        <button class="tombol-utama w-full" :disabled="proses" @click="simpanSusulan"><PhCertificate :size="20" weight="duotone" /> Catat dan terbitkan sertifikat</button>
      </div>
    </LembarBawah>

    <!-- Putuskan -->
    <LembarBawah v-model="lembarPutus" :judul="kp ? `Putuskan khataman · ${kp.nama}` : ''">
      <div v-if="kp" class="space-y-3 pb-2">
        <p class="text-sm text-teks2">Usulan {{ kp.pengusul }}: {{ formatHari(kp.jadwal) }}, {{ formatJam(kp.jadwal) }} WITA · {{ kp.tempat }}. Jadwal dan tempat boleh disesuaikan sebelum disetujui.</p>
        <div class="grid grid-cols-2 gap-3"><InputTanggal v-model="fp.tgl" label="Tanggal" /><InputJam v-model="fp.jam" label="Jam" /></div>
        <div><label class="label-isian" for="kp-t">Tempat</label><input id="kp-t" v-model="fp.tempat" class="isian" /></div>
        <p class="rounded-xl bg-permukaan2 p-3 text-xs text-teks2">Setelah disetujui: Surat Undangan (tanda tangan elektronik Anda) dan Sertifikat Penghargaan Khataman terbit. Sertifikat menunggu tanda tangan elektronik Direktur di menu Tanda tangan.</p>
        <button class="tombol-utama w-full" :disabled="proses" @click="putus(true)"><PhCheckCircle :size="20" weight="duotone" /> Setujui dan terbitkan</button>
        <div><label class="label-isian" for="kp-a">Alasan bila ditolak</label><input id="kp-a" v-model="fp.alasan" class="isian" /></div>
        <button class="tombol-garis w-full" :disabled="proses" @click="putus(false)"><PhXCircle :size="20" /> Tolak usulan</button>
      </div>
    </LembarBawah>

    <!-- Ubah jadwal -->
    <LembarBawah v-model="lembarUbah" :judul="kp ? `Ubah jadwal khataman · ${kp.nama}` : ''">
      <div v-if="kp" class="space-y-3 pb-2">
        <div class="grid grid-cols-2 gap-3"><InputTanggal v-model="fj.tgl" label="Tanggal baru" wajib /><InputJam v-model="fj.jam" label="Jam" /></div>
        <div><label class="label-isian" for="kj-t">Tempat</label><input id="kj-t" v-model="fj.tempat" class="isian" /></div>
        <div><label class="label-isian" for="kj-a">Alasan perubahan{{ kp.status === 'dijadwalkan' ? ' (wajib)' : '' }}</label><input id="kj-a" v-model="fj.alasan" class="isian" /></div>
        <p v-if="kp.status === 'dijadwalkan'" class="rounded-xl bg-permukaan2 p-3 text-xs text-teks2">Undangan dan sertifikat diperbarui ke tanggal baru; tanda tangan elektronik diminta ulang bila tanggal sertifikat berubah.</p>
        <button class="tombol-utama w-full" :disabled="proses" @click="simpanUbah">Simpan jadwal baru</button>
      </div>
    </LembarBawah>

    <!-- Selesai / batal -->
    <LembarBawah v-model="lembarAkhir" :judul="kp ? (mode === 'selesai' ? `Khataman terlaksana · ${kp.nama}` : `Batalkan khataman · ${kp.nama}`) : ''">
      <div v-if="kp" class="space-y-3 pb-2">
        <p class="text-sm text-teks2">{{ mode === 'selesai' ? 'Tandai bahwa khataman telah dilaksanakan dan sertifikat telah diserahkan. Khataman tercatat di riwayat prestasi santri.' : 'Undangan dan sertifikat yang sudah terbit akan dicabut.' }}</p>
        <textarea v-model="catAkhir" rows="2" class="isian" :placeholder="mode === 'selesai' ? 'Catatan pelaksanaan (opsional)' : 'Alasan pembatalan (wajib)'" :aria-label="mode === 'selesai' ? 'Catatan pelaksanaan' : 'Alasan pembatalan'" />
        <button class="tombol-utama w-full" :disabled="proses" @click="simpanAkhir">{{ mode === 'selesai' ? 'Tandai terlaksana' : 'Batalkan khataman' }}</button>
      </div>
    </LembarBawah>

    <!-- WA -->
    <LembarBawah v-model="lembarWA" :judul="kw ? `Kabari lewat WhatsApp · ${kw.nama}` : ''">
      <div v-if="kw" class="space-y-3 pb-2">
        <ul class="divide-y divide-garis rounded-xl border border-garis">
          <li v-for="(p, i) in pesanKe" :key="i" class="flex items-center gap-3 px-3 py-2.5 text-sm">
            <button type="button" class="min-w-0 flex-1 text-left" @click="pratinjauKe = i"><b class="block truncate">{{ p.nama }}</b><span class="text-xs text-teks3">{{ p.ket }} · {{ p.hp || 'nomor HP belum diisi' }}{{ pratinjauKe === i ? ' · dipratinjau' : '' }}</span></button>
            <TombolWA kecil :hp="p.hp" :pesan="p.pesan" label="Kirim" /></li>
        </ul>
        <PratinjauWA v-if="pesanKe[pratinjauKe]" :teks="pesanKe[pratinjauKe].pesan" />
        <button class="tombol-garis w-full" @click="bukaGrup(kw)"><PhUsersThree :size="20" /> Pengumuman untuk grup WA</button>
        <p class="text-xs text-teks3">Surat undangan dapat dicetak lalu dikirim sebagai PDF; tautan pada pesan membuka halaman Cek Keabsahan undangan.</p>
      </div>
    </LembarBawah>
    <LembarLaporanGrup v-model="lembarGrup" judul="Pengumuman khataman untuk grup WhatsApp" :teks="teksGrup" />

    <CetakUndanganKhataman v-if="undangan" :key="'u' + undangan.id" v-model:pratinjau="pratUndangan" :k="undangan" />
    <CetakDokumenTahfizh v-if="dokSert" :key="'s' + dokSert.id" v-model:pratinjau="pratSert" :dok="dokSert" />
  </div>
</template>
