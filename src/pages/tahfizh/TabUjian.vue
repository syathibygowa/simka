<!-- SIMKA PRO | src/pages/tahfizh/TabUjian.vue | v1.5 | 14.9.1: konfirmasi WA ke penguji, antrian penguji, WA jadwal dan hasil ke muhaffizh, keterangan dan catatan perbaikan | 18/10/2026 -->
<script setup>
// Ujian tahfizh: kenaikan juz, sertifikasi berjenjang (5, 10, 15 … juz), dan UTAS (Fase 12, TabUtas.vue).
// Muhaffizh merekomendasikan → penguji aktif menerima notifikasi (dan dapat dikabari WA) → penguji mengambil/menjadwalkan
// atau admin menetapkan penguji → penguji menilai Tajwid & Itqan → Tuntas/Remidi. Kenaikan juz Tuntas otomatis menjadi
// usulan capaian juz di tab Capaian. Muhaffizh tidak menguji santri halaqahnya sendiri. Daftar diperbarui langsung.
// Tahap D: ujian Tuntas → penguji (atau pimpinan tahfizh/Tata Usaha) menerbitkan Suket Ujian Kenaikan Juz / Sertifikat Hafalan bernomor.
// v1.5 (14.9.1): setelah rekomendasi muncul konfirmasi WA per santri ke penguji; penguji punya saringan "Antrian saya"; setelah menjadwalkan
//   muncul WA jadwal ke muhaffizh; setelah menilai muncul WA hasil ke muhaffizh (nama, kelas, halaqah, muhaffizh, nilai, keterangan
//   Lulus/Perbaikan/Tidak lulus, catatan perbaikan). Semua pesan dapat dipratinjau dan dikirim ulang dari kartu ujian.
import { ref, computed, onMounted, onBeforeUnmount, watch } from 'vue'
import {
  PhExam, PhCertificate, PhPaperPlaneTilt, PhHandGrabbing, PhPencilLine, PhX, PhWhatsappLogo, PhUserGear, PhCalendarBlank, PhMagnifyingGlass,
  PhHourglass, PhCheckCircle, PhXCircle, PhUsersThree, PhListChecks,
} from '@phosphor-icons/vue'
import { useTahfizh } from '@/stores/tahfizh'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { STATUS_UJIAN, HASIL_UJIAN, JENIS_PENGUJI, KETERANGAN_UJIAN, ringkasJuz, hitungNilai } from '@/lib/tahfizh'
import { formatWaktu, formatHari, formatJam, hariIniISO } from '@/lib/tanggal'
import { tautanWA, halamanAplikasi, pesanWA } from '@/lib/wa'
import BilahTab from '@/components/BilahTab.vue'
import KartuStatistik from '@/components/KartuStatistik.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import GridJuz from '@/components/GridJuz.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import InputJam from '@/components/InputJam.vue'
import PratinjauWA from '@/components/PratinjauWA.vue'
import TombolWA from '@/components/TombolWA.vue'
import TabUtas from './TabUtas.vue'
import LembarTerbitTahfizh from './LembarTerbitTahfizh.vue'
import CetakDokumenTahfizh from './CetakDokumenTahfizh.vue'

const props = defineProps({ hanyaUtas: Boolean })
const tz = useTahfizh(); const sesi = useSesi(); const ui = useUI()
const jenis = ref(props.hanyaUtas ? 'utas' : 'kenaikan'); const status = ref('aktif'); const daftar = ref([]); const memuat = ref(false); const proses = ref(false); const cari = ref('')
const pengelola = computed(() => tz.hak.atur || tz.hak.validasi)
async function muat() {
  memuat.value = true
  try { daftar.value = await tz.daftarUjian(jenis.value, status.value || null); muatDokumen() } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
// ---------- Dokumen ujian (Tahap D) ----------
const dokUjian = ref({}); const lembarTerbit = ref(false); const ujianTerbit = ref(null); const dokCetak = ref(null); const pratinjauDok = ref(false)
async function muatDokumen() {
  if (!daftar.value.some((u) => u.hasil === 'tuntas')) return
  try { const d = await tz.daftarDokumen({}); dokUjian.value = Object.fromEntries(d.filter((x) => x.exam_id && x.status === 'terbit').map((x) => [x.exam_id, x])) } catch { dokUjian.value = {} }
}
const bolehTerbit = (u) => u.hasil === 'tuntas' && (u.penguji_saya || tz.hak.dokumen)
function bukaTerbit(u) { ujianTerbit.value = u; lembarTerbit.value = true }
async function sesudahTerbit(h) { await muatDokumen(); const d = Object.values(dokUjian.value).find((x) => x.id === h.id) || (await tz.daftarDokumen({ id: h.id }))[0]; if (d) { dokCetak.value = d; pratinjauDok.value = true } }
function cetakDok(d) { dokCetak.value = d; pratinjauDok.value = true }
watch([jenis, status], () => { if (jenis.value !== 'utas') muat() })
onMounted(async () => {
  if (props.hanyaUtas) return
  if (!tz.hakDimuat) await tz.muatHak()
  if (!tz.pengaturan) await tz.muatPengaturan()
  if (!tz.santri.length) await tz.muatSantri()
  await muat(); tz.dengarkanUjian(muat)
})
onBeforeUnmount(() => tz.berhentiUjian())

// Antrian penguji: ujian yang dapat diambil/dinilai penguji ini, atau sudah dipegangnya
const sayaPenguji = computed(() => !!(tz.hak[`penguji_${jenis.value}`]))
const antrianSaya = ref(false)
const jumlahAntrian = computed(() => daftar.value.filter((u) => ['menunggu', 'dijadwalkan'].includes(u.status) && (u.boleh_nilai || u.penguji_saya)).length)
watch(sayaPenguji, (v) => { if (v && !pengelola.value) antrianSaya.value = true }, { immediate: true })
const tampil = computed(() => { const q = cari.value.toLowerCase().trim(); return daftar.value.filter((u) => (!q || `${u.nama} ${u.nis} ${u.halaqah || ''}`.toLowerCase().includes(q)) && (!antrianSaya.value || u.boleh_nilai || u.penguji_saya)) })
const statistik = computed(() => {
  const d = daftar.value
  return [
    { judul: 'Menunggu penguji', nilai: d.filter((u) => u.status === 'menunggu').length, ikon: PhHourglass, warna: 'pengajuan', ket: 'Belum diambil penguji' },
    { judul: 'Dijadwalkan', nilai: d.filter((u) => u.status === 'dijadwalkan').length, ikon: PhCalendarBlank, warna: 'agenda', ket: 'Siap dinilai' },
    { judul: 'Tuntas', nilai: d.filter((u) => u.hasil === 'tuntas').length, ikon: PhCheckCircle, warna: 'presensi', ket: 'Pada daftar yang tampil' },
    { judul: 'Remidi', nilai: d.filter((u) => u.hasil === 'remidi').length, ikon: PhXCircle, warna: 'klinik', ket: 'Perlu diulang' },
  ]
})
const ketUjian = (u) => (u.jenis === 'kenaikan' ? `Juz ${ringkasJuz(u.juz)}` : `Sertifikasi ${u.jenjang} juz${u.juz?.length ? ' · juz ' + ringkasJuz(u.juz) : ''}`)

// ---------- Rekomendasi ----------
const lembarRek = ref(false); const santriRek = ref(null); const juzRek = ref([]); const catRek = ref(''); const cariSantri = ref('')
const calon = computed(() => { const q = cariSantri.value.toLowerCase().trim(); return tz.santri.filter((s) => s.status === 'aktif' && (!q || `${s.nama} ${s.nis} ${s.halaqah || ''}`.toLowerCase().includes(q))).slice(0, 40) })
const jenjangBerikut = computed(() => {
  if (!santriRek.value) return 5
  const tuntas = daftar.value.filter((u) => u.student_id === santriRek.value.student_id && u.jenis === 'sertifikasi' && u.hasil === 'tuntas').map((u) => u.jenjang)
  return Math.max(0, ...tuntas) + 5
})
function bukaRek() { santriRek.value = null; juzRek.value = []; catRek.value = ''; cariSantri.value = ''; lembarRek.value = true }
async function rekomendasikan() {
  const s = santriRek.value
  if (jenis.value === 'kenaikan' && !juzRek.value.length) return ui.toast('Pilih juz yang akan diujikan.', 'galat')
  if (jenis.value === 'sertifikasi' && s.total_resmi < jenjangBerikut.value) return ui.toast(`Hafalan resmi ${s.total_resmi} juz; jenjang ${jenjangBerikut.value} juz belum dapat diujikan.`, 'galat')
  proses.value = true
  try {
    await tz.rekomendasikanUjian(s.student_id, jenis.value, juzRek.value, jenis.value === 'sertifikasi' ? jenjangBerikut.value : null, catRek.value.trim())
    lembarRek.value = false; ui.toast('Rekomendasi terkirim. Penguji aktif menerima notifikasi.'); status.value = 'aktif'; await muat()
    const baru = daftar.value.find((u) => u.student_id === s.student_id && u.status === 'menunggu' && u.jenis === jenis.value)
    if (baru) bukaKirim('rekomendasi', baru)
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}

// ---------- WA ke penguji ----------
const lembarWA = ref(false)
const pengujiAktif = computed(() => tz.penguji[jenis.value].filter((p) => p.aktif))
function bukaWA() { lembarWA.value = true }
const pesanPenguji = (p) => {
  const tunggu = daftar.value.filter((u) => u.status === 'menunggu')
  return pesanWA('penguji_ujian', { nama: p.nama, jenis_ujian: JENIS_PENGUJI[jenis.value].toLowerCase(), jumlah: tunggu.length,
    daftar: tunggu.map((u, i) => `${i + 1}. ${u.nama} (${u.halaqah || '-'}) · ${ketUjian(u)}`).join('\n'), tautan: halamanAplikasi('/tahfizh/ujian') })
}

// ---------- Ambil / tetapkan penguji ----------
const lembarAmbil = ref(false); const ujianPilih = ref(null); const tglJadwal = ref(hariIniISO()); const jamJadwal = ref(''); const pengujiPilih = ref('')
function bukaAmbil(u) { ujianPilih.value = u; tglJadwal.value = hariIniISO(); jamJadwal.value = ''; pengujiPilih.value = ''; lembarAmbil.value = true }
const jadwalISO = () => (tglJadwal.value ? new Date(`${tglJadwal.value}T${(jamJadwal.value || '08:00').slice(0, 5)}:00+08:00`).toISOString() : null)
async function ambil() {
  proses.value = true
  try {
    if (pengujiPilih.value) await tz.tetapkanPenguji(ujianPilih.value.id, pengujiPilih.value, jadwalISO())
    else await tz.ambilUjian(ujianPilih.value.id, jadwalISO())
    const idUjian = ujianPilih.value.id
    lembarAmbil.value = false; ui.toast('Ujian dijadwalkan.'); await muat()
    const u = daftar.value.find((x) => x.id === idUjian); if (u) bukaKirim('jadwal', u)
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}

// ---------- Penilaian ----------
const lembarNilai = ref(false); const tajwid = ref(''); const itqan = ref(''); const catNilai = ref(''); const ketNilai = ref('perbaikan'); const perbaikan = ref('')
const pratinjau = computed(() => hitungNilai(tajwid.value, itqan.value, tz.pengaturan, tz.predikat))
function bukaNilai(u) { ujianPilih.value = u; tajwid.value = ''; itqan.value = ''; catNilai.value = ''; ketNilai.value = 'perbaikan'; perbaikan.value = ''; lembarNilai.value = true }
const ketPratinjau = computed(() => (!pratinjau.value ? null : pratinjau.value.hasil === 'tuntas' ? 'lulus' : ketNilai.value))
async function simpanNilai() {
  const a = Number(tajwid.value); const b = Number(itqan.value)
  if (tajwid.value === '' || itqan.value === '' || !(a >= 0 && a <= 100) || !(b >= 0 && b <= 100)) return ui.toast('Nilai Tajwid dan Itqan harus 0–100.', 'galat')
  if (pratinjau.value.hasil === 'remidi' && !perbaikan.value.trim()) return ui.toast('Tuliskan catatan perbaikan untuk santri yang belum lulus.', 'galat')
  if (!(await ui.konfirmasi({ judul: 'Simpan nilai ujian?', pesan: `${ujianPilih.value.nama}: nilai akhir ${pratinjau.value.akhir} (${pratinjau.value.huruf}) → ${KETERANGAN_UJIAN[ketPratinjau.value].n}. Nilai tidak dapat diubah setelah disimpan.`, ya: 'Simpan nilai' }))) return
  proses.value = true
  try {
    const idUjian = ujianPilih.value.id
    const h = await tz.nilaiUjian(idUjian, a, b, catNilai.value.trim(), ketNilai.value, perbaikan.value)
    lembarNilai.value = false
    ui.toast(`${ujianPilih.value.nama}: ${KETERANGAN_UJIAN[h.keterangan || (h.hasil === 'tuntas' ? 'lulus' : 'perbaikan')].n} (${h.nilai_akhir}, ${h.huruf}).${h.hasil === 'tuntas' && ujianPilih.value.jenis === 'kenaikan' ? ' Juz diusulkan untuk divalidasi.' : ''}`)
    if (status.value === 'aktif') status.value = 'selesai'
    await muat()
    const u = daftar.value.find((x) => x.id === idUjian); if (u) bukaKirim('hasil', u)
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}

// ---------- Batal ----------
const lembarBatal = ref(false); const alasanBatal = ref('')
function bukaBatal(u) { ujianPilih.value = u; alasanBatal.value = ''; lembarBatal.value = true }
async function batal() {
  if (alasanBatal.value.trim().length < 5) return ui.toast('Tuliskan alasan pembatalan (minimal 5 huruf).', 'galat')
  proses.value = true
  try { await tz.batalkanUjian(ujianPilih.value.id, alasanBatal.value.trim()); lembarBatal.value = false; ui.toast('Ujian dibatalkan.'); await muat() }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
const bolehBatal = (u) => ['menunggu', 'dijadwalkan'].includes(u.status) && (u.muhaffizh_saya || pengelola.value)

// ---------- Pesan WhatsApp per ujian: rekomendasi → penguji, jadwal → muhaffizh, hasil → muhaffizh ----------
const lembarKirim = ref(false); const kirim = ref({ mode: '', ujian: null })
const JUDUL_KIRIM = { rekomendasi: 'Konfirmasi rekomendasi ke penguji', jadwal: 'Kabari muhaffizh: jadwal ujian', hasil: 'Teruskan hasil ujian ke muhaffizh' }
const teksJadwal = (u) => (u.jadwal ? `${formatHari(u.jadwal)} pukul ${formatJam(u.jadwal)} WITA` : 'menyusul')
const dataPesan = (u, nama) => ({ nama, jenis_ujian: JENIS_PENGUJI[u.jenis].toLowerCase(), nama_santri: u.nama, kelas: u.kelas, halaqah: u.halaqah, muhaffizh: u.muhaffizh,
  materi: ketUjian(u), catatan: u.catatan_rekomendasi, jadwal: teksJadwal(u), penguji: u.penguji, tautan: halamanAplikasi('/tahfizh/ujian'),
  nilai_tajwid: u.nilai_tajwid, nilai_itqan: u.nilai_itqan, nilai_akhir: u.nilai_akhir, predikat: [u.huruf, u.predikat].filter(Boolean).join(', '),
  keterangan_ujian: KETERANGAN_UJIAN[u.keterangan]?.n || (u.hasil ? HASIL_UJIAN[u.hasil].n : ''), catatan_perbaikan: u.catatan_perbaikan || (u.keterangan === 'lulus' ? 'tidak ada' : '') })
/** Penerima: rekomendasi → penguji aktif (penguji terpilih bila sudah ada); jadwal/hasil → muhaffizh halaqah, ditambah perekomendasi bila orangnya berbeda. */
const penerimaKirim = computed(() => {
  const u = kirim.value.ujian; if (!u) return []
  const kode = { rekomendasi: 'ujian_rekomendasi', jadwal: 'ujian_jadwal', hasil: 'ujian_hasil' }[kirim.value.mode]
  let daftarP = []
  if (kirim.value.mode === 'rekomendasi') {
    daftarP = u.penguji ? [{ nama: u.penguji, hp: u.hp_penguji, ket: 'Penguji' }]
      : tz.penguji[u.jenis].filter((p) => p.aktif && p.employee_id !== sesi.pengguna?.id).map((p) => ({ nama: p.nama, hp: p.no_hp, ket: p.jabatan || 'Penguji aktif' }))
  } else {
    daftarP = [{ nama: u.muhaffizh || 'Muhaffizh', hp: u.hp_muhaffizh, ket: `Muhaffizh ${u.halaqah || ''}`.trim() }]
    if (u.direkomendasikan_oleh && u.direkomendasikan_oleh !== u.muhaffizh) daftarP.push({ nama: u.direkomendasikan_oleh, hp: u.hp_perekomendasi, ket: 'Yang merekomendasikan' })
  }
  return daftarP.map((p) => ({ ...p, pesan: pesanWA(kode, dataPesan(u, p.nama)) }))
})
const pratinjauKe = ref(0)
function bukaKirim(mode, u) { kirim.value = { mode, ujian: u }; pratinjauKe.value = 0; lembarKirim.value = true }
const bolehKirim = (u) => ({
  rekomendasi: u.status === 'menunggu' && (u.muhaffizh_saya || pengelola.value),
  jadwal: u.status === 'dijadwalkan' && (u.penguji_saya || pengelola.value),
  hasil: u.status === 'selesai' && (u.penguji_saya || pengelola.value),
})
</script>
<template>
  <div>
    <BilahTab v-if="!hanyaUtas" v-model="jenis" class="mb-3" label="Jenis ujian"
      :tab="[{ k: 'kenaikan', n: 'Kenaikan juz', ikon: PhExam, w: 'tahfizh' }, { k: 'sertifikasi', n: 'Sertifikasi', ikon: PhCertificate, w: 'pengajuan' }, { k: 'utas', n: 'UTAS', ikon: PhUsersThree, w: 'penilaian' }]" />
    <TabUtas v-if="jenis === 'utas'" />
    <template v-else>

    <div class="flex flex-wrap items-center gap-2">
      <select v-model="status" class="isian w-auto" aria-label="Saring status"><option value="aktif">Daftar tunggu dan terjadwal</option><option value="selesai">Selesai (1 tahun)</option><option value="dibatalkan">Dibatalkan</option><option value="">Semua</option></select>
      <div class="relative min-w-[200px] flex-1"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
        <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari santri atau halaqah" aria-label="Cari santri" /></div>
      <button v-if="tz.hak.muhaffizh || pengelola" class="tombol-utama" @click="bukaRek"><PhPaperPlaneTilt :size="20" weight="duotone" /> Rekomendasikan</button>
      <button v-if="pengujiAktif.length" class="tombol-wa-garis w-presensi" @click="bukaWA"><PhWhatsappLogo :size="20" weight="duotone" /> Kabari penguji</button>
      <button v-if="sayaPenguji" :class="['tombol-garis w-agenda', antrianSaya && 'font-bold ring-2 ring-[var(--c)]']" :aria-pressed="antrianSaya" @click="antrianSaya = !antrianSaya">
        <PhListChecks :size="20" weight="duotone" style="color: var(--c)" /> Antrian saya <span class="lencana w-agenda">{{ jumlahAntrian }}</span></button>
    </div>

    <div class="-mx-4 mt-3 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-4 sm:overflow-visible sm:px-0">
      <KartuStatistik v-for="k in statistik" :key="k.judul" class="w-[44%] shrink-0 snap-start sm:w-auto" :judul="k.judul" :nilai="memuat ? '…' : k.nilai" :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket" />
    </div>

    <ul class="mt-4 grid gap-3 md:grid-cols-2">
      <li v-for="u in tampil" :key="u.id" class="kartu p-4" :class="'w-' + (u.hasil ? HASIL_UJIAN[u.hasil].w : STATUS_UJIAN[u.status].w)">
        <div class="flex items-start gap-3">
          <span class="chip-ikon h-11 w-11 shrink-0"><component :is="u.jenis === 'kenaikan' ? PhExam : PhCertificate" :size="24" weight="duotone" /></span>
          <div class="min-w-0 flex-1">
            <p class="flex flex-wrap items-center gap-1.5"><b>{{ u.nama }}</b>
              <span class="lencana" :class="'w-' + (u.hasil ? HASIL_UJIAN[u.hasil].w : STATUS_UJIAN[u.status].w)">{{ u.hasil ? HASIL_UJIAN[u.hasil].n : STATUS_UJIAN[u.status].n }}</span>
              <span v-if="u.ujian_ke > 1" class="lencana w-hakakses">Ujian ke-{{ u.ujian_ke }}</span></p>
            <p class="text-sm font-semibold text-teks2">{{ ketUjian(u) }}</p>
            <p class="text-xs text-teks3">{{ u.nis }} · {{ u.kelas || '–' }} · {{ u.halaqah || '–' }} · resmi {{ u.total_resmi }} juz</p>
            <p class="text-xs text-teks3">Direkomendasikan {{ formatWaktu(u.direkomendasikan_pada) }} oleh {{ u.direkomendasikan_oleh || '–' }}{{ u.catatan_rekomendasi ? ' · ' + u.catatan_rekomendasi : '' }}</p>
            <p v-if="u.penguji" class="text-xs text-teks3">Penguji: <b class="text-teks2">{{ u.penguji }}</b><template v-if="u.jadwal"> · {{ formatWaktu(u.jadwal) }} WITA</template></p>
            <div v-if="u.status === 'selesai'" class="mt-2 grid grid-cols-4 gap-1.5 text-center text-xs">
              <div class="rounded-lg bg-permukaan2 p-1.5"><b class="block text-base tabular-nums">{{ u.nilai_tajwid }}</b>Tajwid</div>
              <div class="rounded-lg bg-permukaan2 p-1.5"><b class="block text-base tabular-nums">{{ u.nilai_itqan }}</b>Itqan</div>
              <div class="rounded-lg bg-permukaan2 p-1.5"><b class="block text-base tabular-nums" style="color: var(--c)">{{ u.nilai_akhir }}</b>Akhir</div>
              <div class="rounded-lg bg-permukaan2 p-1.5"><b class="block text-base">{{ u.huruf || '–' }}</b>{{ u.predikat || '' }}</div>
            </div>
            <p v-if="u.keterangan" class="mt-2 flex flex-wrap items-center gap-1.5 text-sm">Keterangan: <span :class="['lencana', 'w-' + KETERANGAN_UJIAN[u.keterangan].w]">{{ KETERANGAN_UJIAN[u.keterangan].n }}</span></p>
            <p v-if="u.catatan_perbaikan" class="mt-1 text-sm"><b>Catatan perbaikan:</b> {{ u.catatan_perbaikan }}</p>
            <p v-if="u.catatan_penguji" class="mt-1 text-xs text-teks3">Catatan penguji: {{ u.catatan_penguji }}</p>
            <p v-if="u.alasan_batal" class="mt-1 text-xs text-teks3">Dibatalkan: {{ u.alasan_batal }}</p>
            <div v-if="u.hasil === 'tuntas' && (dokUjian[u.id] || bolehTerbit(u))" class="mt-3 flex flex-wrap items-center gap-2">
              <template v-if="dokUjian[u.id]">
                <button class="tombol-garis w-prestasi min-h-[38px] px-3 text-sm" @click="cetakDok(dokUjian[u.id])"><PhCertificate :size="18" weight="duotone" style="color: var(--c)" /> Cetak {{ u.jenis === 'kenaikan' ? 'suket' : 'sertifikat' }}</button>
                <span class="text-xs text-teks3 tabular-nums">{{ dokUjian[u.id].nomor }}{{ dokUjian[u.id].status_dokumen === 'draf' ? ' · menunggu tanda tangan' : '' }}</span>
              </template>
              <button v-else class="tombol-utama min-h-[38px] px-3 text-sm" @click="bukaTerbit(u)"><PhCertificate :size="18" weight="duotone" /> {{ u.jenis === 'kenaikan' ? 'Terbitkan suket kenaikan juz' : 'Terbitkan sertifikat hafalan' }}</button>
            </div>
            <div v-if="u.status === 'menunggu' || u.status === 'dijadwalkan'" class="mt-3 flex flex-wrap gap-2">
              <button v-if="u.boleh_nilai && u.status === 'menunggu'" class="tombol-garis min-h-[38px] px-3 text-sm" @click="bukaAmbil(u)"><PhHandGrabbing :size="18" /> Ambil & jadwalkan</button>
              <button v-else-if="pengelola && u.status === 'menunggu'" class="tombol-garis min-h-[38px] px-3 text-sm" @click="bukaAmbil(u)"><PhUserGear :size="18" /> Tetapkan penguji</button>
              <button v-if="u.boleh_nilai" class="tombol-utama min-h-[38px] px-3 text-sm" @click="bukaNilai(u)"><PhPencilLine :size="18" /> Nilai</button>
              <button v-if="bolehBatal(u)" class="tombol-garis min-h-[38px] px-3 text-sm" @click="bukaBatal(u)"><PhX :size="18" /> Batalkan</button>
            </div>
            <div v-if="bolehKirim(u).rekomendasi || bolehKirim(u).jadwal || bolehKirim(u).hasil" class="mt-2 flex flex-wrap gap-2">
              <button v-if="bolehKirim(u).rekomendasi" class="tombol-wa-garis w-presensi min-h-[38px] px-3 text-sm" @click="bukaKirim('rekomendasi', u)"><PhWhatsappLogo :size="18" weight="duotone" /> Konfirmasi ke penguji</button>
              <button v-if="bolehKirim(u).jadwal" class="tombol-wa-garis w-presensi min-h-[38px] px-3 text-sm" @click="bukaKirim('jadwal', u)"><PhWhatsappLogo :size="18" weight="duotone" /> WA jadwal ke muhaffizh</button>
              <button v-if="bolehKirim(u).hasil" class="tombol-wa-garis w-presensi min-h-[38px] px-3 text-sm" @click="bukaKirim('hasil', u)"><PhWhatsappLogo :size="18" weight="duotone" /> WA hasil ke muhaffizh</button>
            </div>
          </div>
        </div>
      </li>
    </ul>
    <p v-if="!tampil.length && !memuat" class="kartu mt-4 p-8 text-center text-sm text-teks3">Tidak ada ujian pada saringan ini.</p>

    <!-- Rekomendasi -->
    <LembarBawah v-model="lembarRek" :judul="`Rekomendasi ${JENIS_PENGUJI[jenis].toLowerCase()}`">
      <div class="space-y-3 pb-2">
        <template v-if="!santriRek">
          <input v-model="cariSantri" type="search" class="isian" placeholder="Cari santri" aria-label="Cari santri" />
          <ul class="max-h-[50dvh] divide-y divide-garis overflow-y-auto rounded-xl border border-garis">
            <li v-for="s in calon" :key="s.student_id"><button type="button" class="flex min-h-[52px] w-full items-center gap-3 px-3 text-left text-sm hover:bg-permukaan2" @click="santriRek = s">
              <span class="min-w-0 flex-1"><b class="block truncate">{{ s.nama }}</b><span class="text-xs text-teks3">{{ s.halaqah || '–' }} · resmi {{ s.total_resmi }} juz{{ s.juz_sedang ? ` · sedang juz ${s.juz_sedang}` : '' }}</span></span>
              <PhUsersThree :size="18" class="text-teks3" /></button></li>
          </ul>
        </template>
        <template v-else>
          <div class="flex items-center gap-2 rounded-xl bg-permukaan2 p-3"><span class="min-w-0 flex-1"><b class="block truncate">{{ santriRek.nama }}</b><span class="text-xs text-teks3">Resmi {{ santriRek.total_resmi }} juz: {{ ringkasJuz(santriRek.juz_resmi) || '–' }}</span></span>
            <button class="tombol-garis min-h-[36px] px-3 text-xs" @click="santriRek = null; juzRek = []">Ganti</button></div>
          <template v-if="jenis === 'kenaikan'">
            <p class="label-isian">Juz yang diujikan</p>
            <GridJuz v-model="juzRek" :terkunci="santriRek.juz_resmi" :sedang="santriRek.juz_sedang" label="Juz yang diujikan" label-pilih="Diujikan" label-kunci="Sudah resmi (terkunci)" />
          </template>
          <template v-else>
            <p class="rounded-xl bg-permukaan2 p-3 text-sm">Jenjang berikutnya: <b>{{ jenjangBerikut }} juz</b> sekali duduk.
              <span v-if="santriRek.total_resmi < jenjangBerikut" class="block font-semibold text-merah">Hafalan resmi baru {{ santriRek.total_resmi }} juz; belum mencukupi.</span></p>
            <p class="label-isian">Juz yang diujikan (opsional, dari juz resmi)</p>
            <GridJuz v-model="juzRek" :terkunci="Array.from({ length: 30 }, (_, i) => i + 1).filter((j) => !santriRek.juz_resmi.includes(j))" label="Juz sertifikasi" label-pilih="Diujikan" label-kunci="Belum resmi (tidak dapat dipilih)" />
          </template>
          <div><label class="label-isian" for="rk-cat">Catatan untuk penguji</label><input id="rk-cat" v-model="catRek" class="isian" placeholder="Contoh: sudah lancar, siap diuji pekan ini" /></div>
          <button class="tombol-utama w-full" :disabled="proses" @click="rekomendasikan"><PhPaperPlaneTilt :size="20" weight="duotone" /> Kirim rekomendasi</button>
        </template>
      </div>
    </LembarBawah>

    <!-- Ambil / tetapkan -->
    <LembarBawah v-model="lembarAmbil" :judul="ujianPilih ? `Jadwalkan ujian · ${ujianPilih.nama}` : ''">
      <div v-if="ujianPilih" class="space-y-3 pb-2">
        <p class="text-sm text-teks2">{{ ketUjian(ujianPilih) }} · {{ ujianPilih.halaqah || '–' }}</p>
        <div v-if="pengelola && !ujianPilih.boleh_nilai"><label class="label-isian" for="aj-pg">Penguji</label>
          <select id="aj-pg" v-model="pengujiPilih" class="isian"><option value="" disabled>Pilih penguji aktif</option>
            <option v-for="p in tz.penguji[ujianPilih.jenis].filter((x) => x.aktif)" :key="p.employee_id" :value="p.employee_id">{{ p.nama }} · {{ p.jabatan }}</option></select></div>
        <div class="grid grid-cols-2 gap-3"><InputTanggal v-model="tglJadwal" label="Tanggal ujian" /><InputJam v-model="jamJadwal" label="Jam" /></div>
        <button class="tombol-utama w-full" :disabled="proses || (pengelola && !ujianPilih.boleh_nilai && !pengujiPilih)" @click="ambil">{{ ujianPilih.boleh_nilai ? 'Ambil dan jadwalkan' : 'Tetapkan penguji' }}</button>
      </div>
    </LembarBawah>

    <!-- Penilaian -->
    <LembarBawah v-model="lembarNilai" :judul="ujianPilih ? `Nilai ujian · ${ujianPilih.nama}` : ''">
      <div v-if="ujianPilih" class="space-y-3 pb-2">
        <p class="text-sm text-teks2">{{ ketUjian(ujianPilih) }} · bobot Tajwid {{ tz.pengaturan?.bobot_tajwid }}%, Itqan {{ tz.pengaturan?.bobot_itqan }}% · KKM {{ tz.pengaturan?.kkm }}</p>
        <div class="grid grid-cols-2 gap-3">
          <div><label class="label-isian" for="nl-tj">Nilai Tajwid</label><input id="nl-tj" v-model="tajwid" type="number" min="0" max="100" step="0.5" inputmode="decimal" class="isian text-center text-lg font-bold tabular-nums" /></div>
          <div><label class="label-isian" for="nl-iq">Nilai Itqan</label><input id="nl-iq" v-model="itqan" type="number" min="0" max="100" step="0.5" inputmode="decimal" class="isian text-center text-lg font-bold tabular-nums" /></div>
        </div>
        <div v-if="pratinjau" class="rounded-xl p-3 text-center" :class="'w-' + HASIL_UJIAN[pratinjau.hasil].w" style="background: color-mix(in srgb, var(--c) 12%, transparent)">
          <p class="text-3xl font-extrabold tabular-nums" style="color: var(--c)">{{ pratinjau.akhir }}</p>
          <p class="text-sm font-semibold">{{ pratinjau.huruf }} · {{ pratinjau.predikat }} · <b>{{ HASIL_UJIAN[pratinjau.hasil].n }} ({{ KETERANGAN_UJIAN[ketPratinjau].n }})</b></p>
        </div>
        <fieldset v-if="pratinjau?.hasil === 'remidi'"><legend class="label-isian">Keterangan</legend>
          <div class="grid grid-cols-2 gap-2">
            <label v-for="k in ['perbaikan', 'tidak_lulus']" :key="k" :class="['flex min-h-[48px] cursor-pointer items-center gap-2 rounded-xl border p-3 text-sm', ketNilai === k ? 'border-[var(--c)] font-bold' : 'border-garis', 'w-' + KETERANGAN_UJIAN[k].w]">
              <input v-model="ketNilai" type="radio" :value="k" class="h-5 w-5" style="accent-color: var(--c)" />{{ KETERANGAN_UJIAN[k].n }}</label></div>
          <p class="mt-1 text-xs text-teks3">Perbaikan: diuji ulang setelah bagian yang dicatat diperbaiki. Tidak lulus: perlu mengulang persiapan dari awal.</p></fieldset>
        <div><label class="label-isian" for="nl-pb">Catatan perbaikan{{ pratinjau?.hasil === 'remidi' ? ' (wajib)' : ' (bila ada)' }}</label>
          <textarea id="nl-pb" v-model="perbaikan" rows="2" class="isian" placeholder="Contoh: juz 3 halaman 5–7 belum lancar; mad wajib muttashil" /></div>
        <div><label class="label-isian" for="nl-cat">Catatan penguji (umum)</label><textarea id="nl-cat" v-model="catNilai" rows="2" class="isian" placeholder="Contoh: makhraj huruf ص perlu diperbaiki" /></div>
        <button class="tombol-utama w-full" :disabled="proses || !pratinjau" @click="simpanNilai"><PhPencilLine :size="20" weight="duotone" /> Simpan nilai</button>
      </div>
    </LembarBawah>

    <!-- Batal -->
    <LembarBawah v-model="lembarBatal" judul="Batalkan ujian">
      <div class="space-y-3 pb-2">
        <textarea v-model="alasanBatal" rows="2" class="isian" placeholder="Alasan pembatalan" aria-label="Alasan pembatalan" />
        <button class="tombol-utama w-full" :disabled="proses" @click="batal">Batalkan ujian</button>
      </div>
    </LembarBawah>

    <!-- WA penguji -->
    <LembarBawah v-model="lembarWA" judul="Kabari penguji lewat WhatsApp">
      <div class="space-y-2 pb-2">
        <p class="text-sm text-teks2">Kirim daftar tunggu {{ JENIS_PENGUJI[jenis].toLowerCase() }} ({{ daftar.filter((u) => u.status === 'menunggu').length }} santri) ke penguji aktif.</p>
        <ul class="divide-y divide-garis rounded-xl border border-garis">
          <li v-for="p in pengujiAktif" :key="p.employee_id" class="flex items-center gap-3 px-3 py-2.5 text-sm">
            <span class="min-w-0 flex-1"><b class="block truncate">{{ p.nama }}</b><span class="text-xs text-teks3">{{ p.no_hp || 'Nomor HP belum diisi' }}</span></span>
            <a v-if="p.no_hp" :href="tautanWA(p.no_hp, pesanPenguji(p))" target="_blank" rel="noopener" class="tombol-wa-garis w-presensi min-h-[38px] px-3 text-sm"><PhWhatsappLogo :size="18" weight="duotone" /> Kirim</a>
          </li>
        </ul>
      </div>
    </LembarBawah>
    <!-- WA per ujian -->
    <LembarBawah v-model="lembarKirim" :judul="JUDUL_KIRIM[kirim.mode] || ''">
      <div v-if="kirim.ujian" class="space-y-3 pb-2">
        <p class="text-sm text-teks2"><b>{{ kirim.ujian.nama }}</b> · {{ ketUjian(kirim.ujian) }} · {{ kirim.ujian.halaqah || '–' }}</p>
        <ul class="divide-y divide-garis rounded-xl border border-garis">
          <li v-for="(p, i) in penerimaKirim" :key="i" class="flex items-center gap-3 px-3 py-2.5 text-sm">
            <button type="button" class="min-w-0 flex-1 text-left" @click="pratinjauKe = i"><b class="block truncate">{{ p.nama }}</b><span class="text-xs text-teks3">{{ p.ket }} · {{ p.hp || 'nomor HP belum diisi' }}{{ pratinjauKe === i ? ' · dipratinjau' : '' }}</span></button>
            <TombolWA kecil :hp="p.hp" :pesan="p.pesan" label="Kirim" /></li>
          <li v-if="!penerimaKirim.length" class="px-3 py-2.5 text-sm text-teks3">Belum ada penerima. Pastikan penguji aktif atau muhaffizh halaqah sudah diatur.</li>
        </ul>
        <PratinjauWA v-if="penerimaKirim[pratinjauKe]" :teks="penerimaKirim[pratinjauKe].pesan" />
        <p class="text-xs text-teks3">Pesan dapat diubah di WhatsApp sebelum dikirim. Template diatur di Setelan → Template WA.</p>
      </div>
    </LembarBawah>
  </template>
    <LembarTerbitTahfizh v-model="lembarTerbit" :ujian="ujianTerbit" @terbit="sesudahTerbit" />
    <CetakDokumenTahfizh v-if="dokCetak" :key="dokCetak.id" v-model:pratinjau="pratinjauDok" :dok="dokCetak" />
  </div>
</template>
