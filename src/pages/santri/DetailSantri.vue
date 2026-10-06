<!-- SIMKA PRO | src/pages/santri/DetailSantri.vue | v1.5 | Fase 7 – Tahap 5 Penutup fase | 06/10/2026 -->
<script setup>
// Biodata santri: identitas, kontak orang tua/wali (tombol WA), riwayat status dan mutasi;
// ubah status, mutasi keluar beserta surat keterangan pindah; cetak biodata F4. Fase 5: bagian Hafalan. Fase 6: bagian Kesehatan, perizinan, dan laporan.
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  PhPencilSimple, PhTrash, PhEye, PhPrinter, PhClockCounterClockwise, PhArrowsLeftRight, PhSignOut, PhGraduationCap,
  PhCalendarBlank, PhIdentificationCard, PhUsersThree, PhArrowRight, PhFileText, PhToggleLeft, PhChalkboardTeacher, PhBed, PhBookOpenText, PhMedal, PhCheckSquareOffset, PhWarningCircle,
} from '@phosphor-icons/vue'
import { useSantri } from '@/stores/santri'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { JENJANG, STATUS_SANTRI, HUBUNGAN, inisial, kontakUtama, penandaJenjang, JENIS_KELOMPOK, judulKelompok, labelRombel } from '@/lib/santri'
import { formatPanjang, formatPendek, hariIniISO } from '@/lib/tanggal'
import { pesanWA } from '@/lib/wa'
import { useAbsensiSantri } from '@/stores/absensiSantri'
import { KODE, JENIS_ABSENSI, susunRekap, persen, teksPersen } from '@/lib/absensi'
import { alamatLengkap, kurangWajib } from '@/lib/santri'
import { ambilPenandaTangan } from '@/lib/penandatangan'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import TombolWA from '@/components/TombolWA.vue'
import SeksiHafalan from './SeksiHafalan.vue'
import SeksiLayananSantri from './SeksiLayananSantri.vue'
import SeksiSecuritySantri from './SeksiSecuritySantri.vue'

const route = useRoute(); const router = useRouter(); const san = useSantri(); const sesi = useSesi(); const ui = useUI()
const s = computed(() => san.cari(route.params.id))
const riwayat = computed(() => san.riwayat[route.params.id] || { status: [], mutasi: [], kelompok: [] })
// Wali kelas yang sedang berlaku juga boleh memperbarui data santri kelasnya (diperiksa juga di server)
const waliKelas = computed(() => sesi.kelompokSaya.some((k) => k.jenis === 'kelas' && (s.value?.kelompok || []).some((x) => x.id === k.id)))
const bolehUbah = computed(() => sesi.bolehAdmin('kelola_santri') || sesi.tingkat('data_santri') >= 2 || waliKelas.value)
const IKON_KELOMPOK = { kelas: PhChalkboardTeacher, kamar: PhBed, halaqah: PhBookOpenText, ekskul: PhMedal, lainnya: PhUsersThree }
const riwayatKelompokLama = computed(() => (riwayat.value.kelompok || []).filter((r) => r.selesai))
const bolehKelola = computed(() => sesi.bolehAdmin('kelola_santri'))

const pimpinan = ref({ jabatan: '', nama: '', niy: '' }); const direktur = ref({ jabatan: 'Direktur', nama: '', niy: '' })
async function muatPenanda() {
  if (!s.value) return
  pimpinan.value = await penandaJenjang(s.value.jenjang)
  direktur.value = await ambilPenandaTangan('Direktur')
}
// Kehadiran 30 hari terakhir (absensi HISBAT)
const abs = useAbsensiSantri(); const hadir = ref(null); const tidakHadir = ref([])
async function muatKehadiran() {
  const d = new Date(); const akhir = hariIniISO(); d.setDate(d.getDate() - 29)
  const awal = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
  try {
    const [r, x] = await Promise.all([abs.rekap(awal, akhir, { santri: route.params.id }), abs.riwayat(route.params.id, awal, akhir)])
    hadir.value = susunRekap(r)[route.params.id] || null; tidakHadir.value = x
  } catch { hadir.value = null; tidakHadir.value = [] }
}
onMounted(async () => { await san.muat(); san.muatRiwayat(route.params.id); muatPenanda(); muatKehadiran() })
watch(() => route.params.id, (id) => { if (id) { san.muatRiwayat(id); muatPenanda(); muatKehadiran() } })

const umur = computed(() => {
  if (!s.value?.tanggal_lahir) return null
  const a = new Date(s.value.tanggal_lahir + 'T00:00:00'), b = new Date()
  return b.getFullYear() - a.getFullYear() - (b < new Date(b.getFullYear(), a.getMonth(), a.getDate()) ? 1 : 0)
})
const ttl = computed(() => [s.value?.tempat_lahir, s.value?.tanggal_lahir && formatPanjang(s.value.tanggal_lahir)].filter(Boolean).join(', ') || '–')
const pesanKe = (k) => pesanWA('wali_santri', { nama_wali: k.nama, nama_santri: s.value.nama_lengkap, nis: s.value.nis, kelas: labelRombel(s.value), hubungan: HUBUNGAN[k.hubungan] })

// ---------- Ubah status ----------
const lembarStatus = ref(false); const st = ref({ status: '', tanggal: hariIniISO(), alasan: '' }); const proses = ref(false)
const PILIHAN_STATUS = computed(() => ['aktif', 'nonaktif', 'lulus', 'berhenti'].filter((k) => k !== s.value?.status))
function bukaStatus() { st.value = { status: PILIHAN_STATUS.value[0], tanggal: hariIniISO(), alasan: '' }; lembarStatus.value = true }
async function simpanStatus() {
  if (st.value.alasan.trim().length < 5) return ui.toast('Alasan perubahan status wajib diisi (minimal 5 huruf).', 'galat')
  proses.value = true
  try { await san.ubahStatus(s.value.id, st.value.status, st.value.tanggal, st.value.alasan.trim()); ui.toast(`Status santri menjadi ${STATUS_SANTRI[st.value.status].n.toLowerCase()}.`); lembarStatus.value = false }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}

// ---------- Mutasi keluar ----------
const lembarMutasi = ref(false); const mu = ref({ tanggal: hariIniISO(), tujuan: '', alasan: '' })
function bukaMutasi() { mu.value = { tanggal: hariIniISO(), tujuan: '', alasan: '' }; lembarMutasi.value = true }
async function simpanMutasi() {
  if (mu.value.tujuan.trim().length < 3) return ui.toast('Sekolah/pondok tujuan wajib diisi.', 'galat')
  if (mu.value.alasan.trim().length < 5) return ui.toast('Alasan pindah wajib diisi (minimal 5 huruf).', 'galat')
  const ok = await ui.konfirmasi({ judul: 'Catat mutasi keluar?', pesan: `${s.value.nama_lengkap} akan berstatus mutasi keluar dan nomor surat keterangan pindah diambil dari penomoran surat.`, ya: 'Catat mutasi' })
  if (!ok) return
  proses.value = true
  try {
    const r = await san.mutasiKeluar(s.value.id, mu.value.tanggal, mu.value.tujuan.trim(), mu.value.alasan.trim())
    ui.toast(`Mutasi keluar tercatat. Nomor surat: ${r?.nomor || '–'}`); lembarMutasi.value = false
    mutasiCetak.value = riwayat.value.mutasi.find((m) => m.jenis === 'keluar') || null
    pratinjauPindah.value = !!mutasiCetak.value
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}

// ---------- Cetak ----------
const pratinjauBio = ref(false); const pratinjauPindah = ref(false); const mutasiCetak = ref(null)
const mutasiKeluar = computed(() => riwayat.value.mutasi.find((m) => m.jenis === 'keluar'))
const mutasiMasuk = computed(() => riwayat.value.mutasi.find((m) => m.jenis === 'masuk'))
function bukaSuratPindah(m) { mutasiCetak.value = m; pratinjauPindah.value = true }
const alasanSurat = computed(() => { const a = (mutasiCetak.value?.alasan || '').trim().replace(/\.$/, ''); return a.charAt(0).toLowerCase() + a.slice(1) })
const kopJenjang = computed(() => (s.value?.jenjang === 'sma' ? 'sma' : 'wustha'))
const orangTua = computed(() => (s.value?.kontak || []).filter((k) => k.hubungan !== 'wali').map((k) => k.nama).filter(Boolean).join(' / ') || kontakUtama(s.value)?.nama || '–')
const baris = computed(() => !s.value ? [] : [
  ['Nama lengkap', s.value.nama_lengkap], ['Nama panggilan', s.value.nama_panggilan || '–'], ['NIS', s.value.nis], ['NISN', s.value.nisn || '–'], ['NIK', s.value.nik || '–'], ['Nomor KK', s.value.no_kk || '–'],
  ['Jenis kelamin', s.value.jenis_kelamin === 'P' ? 'Perempuan' : 'Laki-laki'], ['Tempat, tanggal lahir', ttl.value], ['Anak ke-', s.value.anak_ke || '–'],
  ['Alamat', alamatLengkap(s.value) || '–'], ['Jenjang', JENJANG[s.value.jenjang]], ['Kelas', labelRombel(s.value)],
  ['Kamar / halaqah', [(s.value.kelompok || []).find((k) => k.jenis === 'kamar')?.nama, (s.value.kelompok || []).find((k) => k.jenis === 'halaqah')?.nama].filter(Boolean).join(' / ') || '–'],
  ['Tahun masuk / angkatan', `${s.value.tahun_masuk} / angkatan ${s.value.angkatan}`], ['Tanggal masuk', s.value.tanggal_masuk ? formatPanjang(s.value.tanggal_masuk) : '–'],
  ['Jalur masuk', s.value.jalur_masuk === 'pindahan' ? 'Pindahan (mutasi masuk)' : 'Santri baru'], ['Asal sekolah', s.value.asal_sekolah || '–'],
  ['Hafalan awal', s.value.hafalan_awal_juz != null && s.value.hafalan_awal_juz !== '' ? `${String(s.value.hafalan_awal_juz).replace('.', ',')} juz` : '–'],
  ...['ayah', 'ibu', 'wali'].map((h) => { const k = (s.value.kontak || []).find((x) => x.hubungan === h); return [`Nama ${HUBUNGAN[h].toLowerCase()}`, k ? [k.nama, k.no_hp && `HP ${k.no_hp}`, k.pekerjaan].filter(Boolean).join(', ') : '–'] }),
  ['Status', `${STATUS_SANTRI[s.value.status]?.n} sejak ${formatPanjang(s.value.status_sejak)}`],
])

async function hapus() {
  if (!(await ui.konfirmasi({ judul: 'Hapus data santri?', pesan: `${s.value.nama_lengkap} beserta kontak, riwayat status, dan mutasinya akan dihapus permanen. Gunakan hanya untuk data yang salah input; santri yang keluar cukup diubah statusnya.`, ya: 'Hapus permanen', bahaya: true }))) return
  try { await san.hapus(s.value.id); ui.toast('Data santri dihapus.'); router.replace('/santri') } catch (e) { ui.toast(e.message, 'galat') }
}
const WARNA_KONTAK = { ayah: 'pegawai', ibu: 'klinik', wali: 'tahfizh' }
</script>
<template>
  <div v-if="s" class="mx-auto max-w-4xl">
    <div class="layar-saja">
      <section class="kartu w-santri overflow-hidden">
        <div class="kepala h-20 sm:h-24" />
        <div class="-mt-10 flex flex-wrap items-end gap-4 px-5 pb-5">
          <span :class="['grid h-20 w-20 place-items-center rounded-2xl border-4 border-permukaan text-2xl font-extrabold text-white', s.jenis_kelamin === 'P' ? 'bg-[#B42A5E]' : 'bg-[#0B7F81]']">{{ inisial(s.nama_lengkap) }}</span>
          <div class="min-w-0 flex-1 pt-11">
            <h2 class="text-xl font-extrabold leading-tight">{{ s.nama_lengkap }}</h2>
            <p class="text-sm text-teks3 tabular-nums">NIS {{ s.nis }}{{ s.nisn ? ' · NISN ' + s.nisn : '' }}</p>
          </div>
          <span :class="['lencana', 'w-' + STATUS_SANTRI[s.status]?.w]">{{ STATUS_SANTRI[s.status]?.n }}</span>
        </div>
        <div class="grid gap-3 border-t border-garis p-5 sm:grid-cols-2">
          <div class="w-laporan flex items-center gap-3"><span class="chip-ikon h-10 w-10"><PhGraduationCap :size="20" weight="duotone" /></span>
            <div><p class="text-xs text-teks3">Jenjang dan kelas</p><p class="font-semibold">{{ JENJANG[s.jenjang] }} · {{ labelRombel(s) }}</p></div></div>
          <div class="w-tahfizh flex items-center gap-3"><span class="chip-ikon h-10 w-10"><PhCalendarBlank :size="20" weight="duotone" /></span>
            <div><p class="text-xs text-teks3">Masuk pondok</p><p class="font-semibold">{{ s.tahun_masuk }} · angkatan {{ s.angkatan }}{{ s.jalur_masuk === 'pindahan' ? ' (pindahan)' : '' }}</p></div></div>
          <div class="w-pegawai flex items-center gap-3"><span class="chip-ikon h-10 w-10"><PhIdentificationCard :size="20" weight="duotone" /></span>
            <div><p class="text-xs text-teks3">Tempat, tanggal lahir</p><p class="font-semibold">{{ ttl }}{{ umur != null ? ` (${umur} tahun)` : '' }}</p></div></div>
          <div class="w-pengajuan flex items-center gap-3"><span class="chip-ikon h-10 w-10"><PhToggleLeft :size="20" weight="duotone" /></span>
            <div><p class="text-xs text-teks3">Status</p><p class="font-semibold">{{ STATUS_SANTRI[s.status]?.n }} sejak {{ formatPendek(s.status_sejak) }}</p></div></div>
        </div>
      </section>

      <div class="mt-4 flex flex-wrap gap-2">
        <router-link v-if="bolehUbah" :to="`/santri/${s.id}/ubah`" class="tombol-utama"><PhPencilSimple :size="20" weight="duotone" /> Ubah data</router-link>
        <button v-if="bolehKelola" class="tombol-garis w-pengajuan" @click="bukaStatus"><PhArrowsLeftRight :size="20" weight="duotone" style="color: var(--c)" /> Ubah status</button>
        <button v-if="bolehKelola && ['aktif', 'nonaktif'].includes(s.status)" class="tombol-garis w-klinik" @click="bukaMutasi"><PhSignOut :size="20" weight="duotone" style="color: var(--c)" /> Mutasi keluar</button>
        <button class="tombol-garis" @click="pratinjauBio = true"><PhEye :size="20" weight="duotone" /> Pratinjau biodata</button>
        <button v-if="mutasiKeluar" class="tombol-garis w-tatausaha" @click="bukaSuratPindah(mutasiKeluar)"><PhFileText :size="20" weight="duotone" style="color: var(--c)" /> Surat keterangan pindah</button>
        <button v-if="sesi.isSuperadmin" class="tombol-garis" @click="hapus"><PhTrash :size="20" weight="duotone" /> Hapus</button>
      </div>

      <!-- Data wajib belum lengkap -->
      <div v-if="kurangWajib(s).length" class="kartu w-klinik mt-4 flex flex-wrap items-center gap-3 p-4">
        <span class="chip-ikon h-10 w-10"><PhWarningCircle :size="22" weight="duotone" /></span>
        <p class="min-w-[200px] flex-1 text-sm"><b>Data wajib belum lengkap:</b> {{ kurangWajib(s).join(', ') }}. Lengkapi lewat Ubah data atau ekspor–impor Excel.</p>
        <router-link v-if="bolehUbah" :to="`/santri/${s.id}/ubah`" class="tombol-garis min-h-[40px] px-3 text-sm">Lengkapi</router-link>
      </div>

      <!-- Kehadiran 30 hari -->
      <section class="kartu w-absensi mt-4 p-5">
        <div class="mb-3 flex items-center gap-3"><span class="chip-ikon h-10 w-10"><PhCheckSquareOffset :size="22" weight="duotone" /></span>
          <div><h3 class="judul-bagian">Kehadiran 30 hari terakhir</h3><p class="text-sm text-teks3">Absensi HISBAT kelas, halaqah, dan asrama.</p></div></div>
        <div class="grid grid-cols-2 gap-2 sm:grid-cols-4">
          <div v-for="j in ['kelas', 'halaqah', 'asrama', 'pokok']" :key="j" :class="['rounded-2xl border border-garis p-3', 'w-' + (j === 'pokok' ? 'absensi' : JENIS_ABSENSI[j].warna)]">
            <p class="text-xs font-bold uppercase tracking-wide" style="color: var(--c)">{{ j === 'pokok' ? 'Program pokok' : JENIS_ABSENSI[j].n }}</p>
            <p class="mt-1 text-xl font-extrabold tabular-nums">{{ teksPersen(persen(hadir?.[j].hadir, hadir?.[j].sesi)) }}</p>
            <p class="text-xs text-teks3">{{ hadir?.[j].sesi ? `${hadir[j].hadir}/${hadir[j].sesi} sesi` : 'belum ada sesi' }}</p>
          </div>
        </div>
        <ul v-if="tidakHadir.length" class="mt-3 divide-y divide-garis text-sm">
          <li v-for="(x, i) in tidakHadir.slice(0, 8)" :key="i" :class="['flex flex-wrap items-center gap-2 py-2', 'w-' + KODE[x.kode].w]">
            <span class="lencana">{{ KODE[x.kode].n }}</span><span>{{ formatPendek(x.tanggal) }} · {{ x.nama_sesi }} ({{ x.kelompok }})</span>
            <span v-if="x.keterangan" class="text-teks3">· {{ x.keterangan }}</span></li>
        </ul>
        <p v-else-if="hadir" class="mt-3 text-sm text-teks2">Selalu hadir pada sesi yang tercatat.</p>
      </section>

      <!-- Hafalan (Fase 5) -->
      <SeksiHafalan :santri="s" />
      <!-- Kesehatan, perizinan, laporan (Fase 6) -->
      <SeksiLayananSantri :santri="s" />
      <SeksiSecuritySantri :santri="s" />

      <!-- Kelompok tahun ajaran berjalan -->
      <section class="kartu w-kelompoksantri mt-4 p-5">
        <div class="mb-3 flex items-center gap-3"><span class="chip-ikon h-10 w-10"><PhChalkboardTeacher :size="22" weight="duotone" /></span>
          <div><h3 class="judul-bagian">Kelas, kamar, halaqah, dan ekskul</h3><p class="text-sm text-teks3">Tahun ajaran berjalan. Pembagian diatur di menu Kelompok Santri.</p></div></div>
        <ul class="grid gap-2 sm:grid-cols-2 lg:grid-cols-4">
          <li v-for="j in ['kelas', 'kamar', 'halaqah', 'ekskul']" :key="j" :class="['rounded-2xl border border-garis p-3', 'w-' + JENIS_KELOMPOK[j].warna]">
            <p class="flex items-center gap-1.5 text-xs font-bold uppercase tracking-wide" style="color: var(--c)"><component :is="IKON_KELOMPOK[j]" :size="16" weight="duotone" />{{ JENIS_KELOMPOK[j].n }}</p>
            <template v-if="(s.kelompok || []).some((k) => k.jenis === j)">
              <router-link v-for="k in s.kelompok.filter((x) => x.jenis === j)" :key="k.id" :to="`/kelompok-santri/k/${k.id}`" class="mt-1 block font-semibold hover:underline">{{ judulKelompok(k) }}</router-link>
            </template>
            <p v-else class="mt-1 text-sm font-semibold text-teks3">Belum dibagi</p>
          </li>
        </ul>
        <details v-if="riwayatKelompokLama.length" class="mt-3 text-sm">
          <summary class="cursor-pointer font-semibold text-teks2">Riwayat kelompok sebelumnya ({{ riwayatKelompokLama.length }})</summary>
          <ul class="mt-2 space-y-1">
            <li v-for="(r, i) in riwayatKelompokLama" :key="i" class="text-teks2">{{ JENIS_KELOMPOK[r.jenis]?.n }} {{ r.nama }} ({{ r.tahun_ajaran }}): {{ formatPendek(r.mulai) }} – {{ formatPendek(r.selesai) }}{{ r.alasan_keluar ? ' · ' + r.alasan_keluar : '' }}</li>
          </ul>
        </details>
      </section>

      <!-- Kontak orang tua/wali -->
      <section class="kartu w-pegawai mt-4 p-5">
        <div class="mb-3 flex items-center gap-3"><span class="chip-ikon h-10 w-10"><PhUsersThree :size="22" weight="duotone" /></span>
          <div><h3 class="judul-bagian">Orang tua dan wali</h3><p class="text-sm text-teks3">Pesan WA dikirim dari HP Anda; isi pesan dari Template WA.</p></div></div>
        <ul class="grid gap-3 sm:grid-cols-3">
          <li v-for="k in s.kontak" :key="k.hubungan" :class="['rounded-2xl border border-garis p-4', 'w-' + WARNA_KONTAK[k.hubungan]]">
            <p class="text-xs font-bold uppercase tracking-wide" style="color: var(--c)">{{ HUBUNGAN[k.hubungan] }}<span v-if="k.utama" class="lencana ml-1 normal-case">WA utama</span></p>
            <p class="mt-1 font-semibold">{{ k.nama || '–' }}</p>
            <p class="text-sm text-teks2 tabular-nums">{{ k.no_hp || 'HP belum diisi' }}</p>
            <p v-if="k.pekerjaan" class="text-sm text-teks3">{{ k.pekerjaan }}</p>
            <TombolWA class="mt-3" kecil :hp="k.no_hp" :pesan="pesanKe(k)" label="Kirim WA" />
          </li>
          <li v-if="!s.kontak?.length" class="text-sm text-teks3">Belum ada kontak orang tua/wali.</li>
        </ul>
      </section>

      <!-- Riwayat status dan mutasi -->
      <section class="kartu w-pengajuan mt-4 p-5">
        <div class="mb-3 flex items-center gap-3"><span class="chip-ikon h-10 w-10"><PhClockCounterClockwise :size="22" weight="duotone" /></span>
          <div><h3 class="judul-bagian">Riwayat status dan mutasi</h3><p class="text-sm text-teks3">Setiap perubahan tercatat dengan tanggal dan alasan.</p></div></div>
        <ul v-if="riwayat.mutasi.length" class="mb-4 space-y-2">
          <li v-for="m in riwayat.mutasi" :key="m.id" :class="['flex flex-wrap items-center gap-3 rounded-xl bg-permukaan2 p-3', m.jenis === 'keluar' ? 'w-klinik' : 'w-presensi']">
            <span class="lencana">{{ m.jenis === 'keluar' ? 'Mutasi keluar' : 'Mutasi masuk' }}</span>
            <span class="min-w-0 flex-1 text-sm">{{ formatPanjang(m.tanggal) }} · {{ m.jenis === 'keluar' ? 'ke' : 'dari' }} <b>{{ m.sekolah || '–' }}</b>
              <template v-if="m.jenis === 'masuk'"> · ditempatkan di kelas {{ m.tingkat }}{{ m.hafalan_juz != null ? `, hafalan awal ${String(m.hafalan_juz).replace('.', ',')} juz` : '' }}</template>
              <template v-else> · {{ m.alasan }}</template></span>
            <button v-if="m.jenis === 'keluar'" class="tombol-garis min-h-[40px] px-3 text-sm" @click="bukaSuratPindah(m)"><PhPrinter :size="18" weight="duotone" /> Surat</button>
          </li>
        </ul>
        <ol v-if="riwayat.status.length" class="relative ml-2 space-y-3 border-l-2 border-garis pl-5">
          <li v-for="r in riwayat.status" :key="r.id" class="relative">
            <span class="absolute -left-[27px] top-1.5 h-3 w-3 rounded-full" style="background: var(--c)" aria-hidden="true" />
            <p class="flex flex-wrap items-center gap-1.5 text-sm font-semibold">
              <template v-if="r.status_lama">{{ STATUS_SANTRI[r.status_lama]?.n }} <PhArrowRight :size="14" /></template>{{ STATUS_SANTRI[r.status_baru]?.n }}</p>
            <p v-if="r.alasan" class="text-sm text-teks2">{{ r.alasan }}</p>
            <p class="text-xs text-teks3">Berlaku {{ formatPanjang(r.tanggal) }}{{ r.nama_oleh ? ' · dicatat ' + r.nama_oleh : '' }}</p>
          </li>
        </ol>
        <p v-else class="py-3 text-sm text-teks3">Memuat riwayat…</p>
      </section>
    </div>

    <!-- Biodata F4 -->
    <DokumenCetak :kop="kopJenjang" judul="Biodata Santri" v-model:pratinjau="pratinjauBio" :pencetak="sesi.pengguna?.nama_lengkap">
      <table class="tabel">
        <colgroup><col style="width:7%"><col style="width:33%"><col style="width:60%"></colgroup>
        <thead><tr><th>No.</th><th>Data</th><th>Keterangan</th></tr></thead>
        <tbody><tr v-for="(b, i) in baris" :key="b[0]"><td class="tengah">{{ i + 1 }}</td><td>{{ b[0] }}</td><td>{{ b[1] }}</td></tr></tbody>
      </table>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: pimpinan.jabatan, nama: pimpinan.nama, niy: pimpinan.niy }"
          :kanan="{ jabatan: 'Orang tua/wali santri', nama: kontakUtama(s)?.nama || '……………………………' }" />
      </template>
    </DokumenCetak>

    <!-- Surat keterangan pindah F4 -->
    <DokumenCetak v-if="mutasiCetak" :kop="mutasiCetak.kop || kopJenjang" judul="Surat Keterangan Pindah" :nomor="mutasiCetak.nomor_surat"
      v-model:pratinjau="pratinjauPindah" :pencetak="sesi.pengguna?.nama_lengkap">
      <p>Yang bertanda tangan di bawah ini, {{ pimpinan.jabatan || 'Kepala ' + JENJANG[s.jenjang] }} Pondok Pesantren Tahfizhul Qur'an Imam Asy-Syathiby Wahdah Islamiyah Gowa, menerangkan bahwa:</p>
      <table class="data" style="margin: 6pt 0 8pt 12pt">
        <tbody>
          <tr><td style="width: 46mm">Nama</td><td style="width: 4mm">:</td><td>{{ s.nama_lengkap }}</td></tr>
          <tr><td>NIS / NISN</td><td>:</td><td>{{ s.nis }} / {{ s.nisn || '–' }}</td></tr>
          <tr><td>Tempat, tanggal lahir</td><td>:</td><td>{{ ttl }}</td></tr>
          <tr><td>Jenis kelamin</td><td>:</td><td>{{ s.jenis_kelamin === 'P' ? 'Perempuan' : 'Laki-laki' }}</td></tr>
          <tr><td>Jenjang / kelas</td><td>:</td><td>{{ JENJANG[mutasiCetak.jenjang || s.jenjang] }} / Kelas {{ mutasiCetak.tingkat || s.tingkat }}</td></tr>
          <tr><td>Nama orang tua</td><td>:</td><td>{{ orangTua }}</td></tr>
          <tr><td>Alamat</td><td>:</td><td>{{ alamatLengkap(s) || '–' }}</td></tr>
        </tbody>
      </table>
      <p style="text-align: justify">adalah benar santri pada {{ JENJANG[mutasiCetak.jenjang || s.jenjang] }} Pondok Pesantren Tahfizhul Qur'an Imam Asy-Syathiby Wahdah Islamiyah Gowa
        sejak {{ s.tanggal_masuk ? formatPanjang(s.tanggal_masuk) : 'tahun ' + s.tahun_masuk }} dan terhitung mulai tanggal {{ formatPanjang(mutasiCetak.tanggal) }}
        telah pindah ke {{ mutasiCetak.sekolah }} dengan alasan {{ alasanSurat }}.</p>
      <p style="margin-top: 6pt; text-align: justify">Demikian surat keterangan ini dibuat dengan sebenarnya untuk dipergunakan sebagaimana mestinya.</p>
      <template #ttd>
        <TandaTangan :tanggal="mutasiCetak.tanggal" :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan, nama: direktur.nama, niy: direktur.niy }"
          :kanan="{ jabatan: pimpinan.jabatan, nama: pimpinan.nama, niy: pimpinan.niy }" />
      </template>
    </DokumenCetak>

    <!-- Lembar ubah status -->
    <LembarBawah v-model="lembarStatus" judul="Ubah status santri">
      <div class="space-y-4 pb-2">
        <p class="text-sm text-teks2">Status saat ini: <b>{{ STATUS_SANTRI[s.status]?.n }}</b>. Untuk pindah sekolah gunakan <b>Mutasi keluar</b> agar surat keterangan pindah terbit.</p>
        <div><p class="label-isian">Status baru</p>
          <div class="grid grid-cols-2 gap-1.5">
            <button v-for="k in PILIHAN_STATUS" :key="k" type="button" :aria-pressed="st.status === k" @click="st.status = k"
              :class="['min-h-[44px] rounded-xl border-2 px-3 text-sm font-semibold', 'w-' + STATUS_SANTRI[k].w, st.status === k ? 'text-teks' : 'border-garis text-teks2']"
              :style="st.status === k ? 'border-color: var(--c); background: color-mix(in srgb, var(--c) 16%, transparent)' : ''">{{ STATUS_SANTRI[k].n }}</button>
          </div></div>
        <InputTanggal v-model="st.tanggal" label="Berlaku mulai" wajib />
        <div><label class="label-isian" for="st-alasan">Alasan <span class="text-merah">*</span></label>
          <textarea id="st-alasan" v-model="st.alasan" class="isian min-h-[80px]" rows="3" placeholder="Contoh: kembali aktif setelah izin panjang" /></div>
        <button class="tombol-utama w-full" :disabled="proses" @click="simpanStatus">{{ proses ? 'Menyimpan…' : 'Simpan status' }}</button>
      </div>
    </LembarBawah>

    <!-- Lembar mutasi keluar -->
    <LembarBawah v-model="lembarMutasi" judul="Mutasi keluar">
      <div class="space-y-4 pb-2">
        <InputTanggal v-model="mu.tanggal" label="Tanggal pindah" wajib />
        <div><label class="label-isian" for="mu-tujuan">Sekolah/pondok tujuan <span class="text-merah">*</span></label>
          <input id="mu-tujuan" v-model="mu.tujuan" class="isian" placeholder="Nama sekolah/pondok tujuan" /></div>
        <div><label class="label-isian" for="mu-alasan">Alasan pindah <span class="text-merah">*</span></label>
          <textarea id="mu-alasan" v-model="mu.alasan" class="isian min-h-[80px]" rows="3" placeholder="Contoh: mengikuti orang tua pindah tugas" /></div>
        <p class="text-xs text-teks3">Nomor surat diambil dari penomoran surat (Khariji, perihal IL) dengan kop {{ s.jenjang === 'sma' ? 'SMA' : 'Kesetaraan Wustha' }}.</p>
        <button class="tombol-utama w-full" :disabled="proses" @click="simpanMutasi">{{ proses ? 'Menyimpan…' : 'Catat mutasi dan buat surat' }}</button>
      </div>
    </LembarBawah>
  </div>
  <p v-else-if="!san.memuat" class="py-16 text-center text-teks3">Data santri tidak ditemukan atau di luar cakupan Anda.</p>
  <p v-else class="py-16 text-center text-teks3">Memuat data santri…</p>
</template>
<style scoped>
.kepala { background: linear-gradient(135deg, #075F61 0%, #0B7F81 55%, #2F5FA8 100%); }
</style>
