<!-- SIMKA PRO | src/pages/pantauan/Pantauan.vue | v1.0 | Fase 7 – Tahap 4 Pantauan langsung pimpinan | 06/10/2026 -->
<script setup>
// Pantauan Langsung untuk Pimpinan (Blueprint Bagian 28): kondisi santri dan pegawai HARI INI, diperbarui langsung.
//   Santri   : aktif, hadir di kelas, halaqah per sesi, asrama per sesi, sakit (termasuk klinik), di luar pondok, terlambat kembali
//   Pegawai  : hadir, terlambat, dinas luar, izin/sakit/cuti, belum presensi, tidak terjadwal
//   Kegiatan : sesi kelas, halaqah, asrama, ekskul yang sudah/belum terlaksana beserta pengampunya
//   Security : keluar, kembali, ditolak di gerbang, titipan (di pos, diterima, diambil + pengambil), tamu, kunjungan
// Saringan: jenis kelamin, jenjang (santri dan kegiatan), bidang (pegawai). Setiap angka diketuk → daftar nama → cetak F4/Excel.
// Dapat dibuka: semua jabatan struktural (P2), Direktur/Wadir, yayasan, admin, superadmin.
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import * as XLSX from 'xlsx'
import { PhStudent, PhChalkboardTeacher, PhBookOpenText, PhBed, PhFirstAidKit, PhSignOut, PhSiren, PhUserCheck, PhClock, PhAirplaneTilt, PhUserMinus,
  PhHourglass, PhMoon, PhCalendarCheck, PhSignIn, PhProhibit, PhPackage, PhHandArrowDown, PhIdentificationBadge, PhUsersThree, PhBroadcast,
  PhEye, PhDownloadSimple, PhArrowClockwise, PhLock } from '@phosphor-icons/vue'
import { usePantauan } from '@/stores/pantauan'
import { useSesi } from '@/stores/sesi'
import { JENJANG_PENDEK, penandaKelompok } from '@/lib/santri'
import { PENGAMBIL, JENIS_TITIPAN } from '@/lib/security'
import { formatJam, formatWaktu, formatPanjang } from '@/lib/tanggal'
import KartuStatistik from '@/components/KartuStatistik.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const pt = usePantauan(); const sesi = useSesi()
onMounted(() => pt.mulai())
onBeforeUnmount(() => pt.berhenti())
const jk = ref(''); const jenjang = ref(''); const bidang = ref('')
const d = computed(() => pt.data || { santri: [], pegawai: [], sesi: [], security: { gerbang: [], titipan: [], tamu: [], kunjungan: [] }, bidang: [] })
const cocokS = (x) => (!jk.value || x.jk === jk.value) && (!jenjang.value || x.jenjang === jenjang.value)
const santri = computed(() => d.value.santri.filter(cocokS))
const pegawai = computed(() => d.value.pegawai.filter((p) => (!jk.value || p.jk === jk.value) && (!bidang.value || p.bidang_id === bidang.value)))
const kegiatan = computed(() => d.value.sesi.filter((s) => (!jk.value || !s.jk || s.jk === jk.value) && (!jenjang.value || !s.jenjang || s.jenjang === jenjang.value)))
const sec = computed(() => {
  const s = d.value.security; const c = (x) => (!jk.value || !x.jenis_kelamin || x.jenis_kelamin === jk.value)
  return { gerbang: s.gerbang.filter((x) => (!jk.value || x.jk === jk.value) && (!jenjang.value || x.jenjang === jenjang.value)), titipan: s.titipan.filter(c), tamu: s.tamu, kunjungan: s.kunjungan.filter(c) }
})
const hari = computed(() => d.value.tanggal)
const hariIni = (iso) => iso && new Date(new Date(iso).getTime() + 8 * 3600000).toISOString().slice(0, 10) === hari.value

// ---------- Kolom daftar ----------
const K_SANTRI = [['nama', 'Nama santri', 26], ['nis', 'NIS', 10], ['kelas', 'Kelas', 8], ['kamar', 'Kamar', 16]]
const kelasKamar = (s) => ({ ...s, kelas: s.kelas || '–', kamar: s.kamar || '–' })
const K_PEG = [['nama', 'Nama pegawai', 28], ['jabatan', 'Jabatan', 24], ['bidang', 'Bidang', 18], ['ket', 'Keterangan', 22]]
const pegBaris = (f) => pegawai.value.filter(f).map((p) => ({ ...p, bidang: p.bidang || '–', jabatan: p.jabatan || '–', ket: p.ket || '–' }))
const KODE = { H: 'Hadir', T: 'Terlambat', I: 'Izin', S: 'Sakit', A: 'Absen', B: 'Bolos' }

// ---------- Kartu santri ----------
const sesiSantri = (awalan) => {
  const kunci = [...new Set(santri.value.flatMap((s) => Object.keys(s.sesi || {}).filter((k) => k.startsWith(awalan))))]
  return kunci.map((k) => {
    const ada = santri.value.filter((s) => s.sesi?.[k]); const hadir = ada.filter((s) => ['H', 'T'].includes(s.sesi[k].k))
    return { k, n: ada[0]?.sesi[k].n || k.split(':')[1], ada, hadir }
  })
}
const kartuSantri = computed(() => {
  const s = santri.value; const kelas = s.filter((x) => x.kelas_sesi > 0); const tidakKelas = kelas.filter((x) => x.kelas_tidak > 0)
  const sakit = s.filter((x) => x.sakit); const luar = s.filter((x) => x.luar); const telat = luar.filter((x) => x.luar.terlambat)
  const k = [
    { j: 'Santri aktif', v: s.length, i: PhStudent, w: 'santri', ket: `${s.filter((x) => x.jk === 'L').length} putra · ${s.filter((x) => x.jk === 'P').length} putri`,
      daftar: { judul: 'Santri aktif', kolom: [...K_SANTRI, ['halaqah', 'Halaqah', 18]], baris: s.map((x) => ({ ...kelasKamar(x), halaqah: x.halaqah || '–' })) } },
    { j: 'Hadir di kelas', v: `${kelas.length - kelas.filter((x) => x.kelas_tidak >= x.kelas_sesi).length}/${kelas.length}`, i: PhChalkboardTeacher, w: 'jadwal', ket: `${tidakKelas.length} tidak hadir (sebagian/seluruh)`,
      daftar: { judul: 'Santri tidak hadir di kelas hari ini', kolom: [...K_SANTRI, ['ket', 'Keterangan', 20]], baris: tidakKelas.map((x) => ({ ...kelasKamar(x), ket: `Tidak hadir ${x.kelas_tidak} dari ${x.kelas_sesi} sesi` })) } },
    ...sesiSantri('halaqah:').map((h) => ({ j: h.n, v: `${h.hadir.length}/${h.ada.length}`, i: PhBookOpenText, w: 'tahfizh', ket: `${h.ada.length - h.hadir.length} tidak hadir`,
      daftar: { judul: `${h.n}: santri tidak hadir`, kolom: [...K_SANTRI, ['halaqah', 'Halaqah', 16], ['ket', 'Status', 10]],
        baris: h.ada.filter((x) => !['H', 'T'].includes(x.sesi[h.k].k)).map((x) => ({ ...kelasKamar(x), halaqah: x.halaqah || '–', ket: KODE[x.sesi[h.k].k] })) } })),
    ...sesiSantri('asrama:').map((h) => ({ j: h.n, v: `${h.hadir.length}/${h.ada.length}`, i: PhMoon, w: 'musyrif', ket: `${h.ada.length - h.hadir.length} tidak di asrama`,
      daftar: { judul: `${h.n}: santri tidak hadir`, kolom: [...K_SANTRI, ['ket', 'Status', 10]],
        baris: h.ada.filter((x) => !['H', 'T'].includes(x.sesi[h.k].k)).map((x) => ({ ...kelasKamar(x), ket: KODE[x.sesi[h.k].k] })) } })),
    { j: 'Sakit', v: sakit.length, i: PhFirstAidKit, w: 'klinik', ket: `${sakit.filter((x) => /Dirawat/.test(x.sakit)).length} dirawat di klinik`,
      daftar: { judul: 'Santri sakit hari ini', kolom: [...K_SANTRI, ['ket', 'Keterangan', 20]], baris: sakit.map((x) => ({ ...kelasKamar(x), ket: x.sakit })) } },
    { j: 'Di luar pondok', v: luar.length, i: PhSignOut, w: 'security', ket: 'Izin atau libur, belum kembali',
      daftar: { judul: 'Santri di luar pondok', kolom: [...K_SANTRI, ['ket', 'Izin', 20], ['batas', 'Batas kembali', 14]],
        baris: luar.map((x) => ({ ...kelasKamar(x), ket: x.luar.alasan, batas: formatWaktu(x.luar.batas) })) } },
    { j: 'Terlambat kembali', v: telat.length, i: PhSiren, w: 'klinik', ket: telat.length ? 'Lewat batas kembali' : 'Tidak ada',
      daftar: { judul: 'Santri terlambat kembali', kolom: [...K_SANTRI, ['ket', 'Izin', 20], ['batas', 'Batas kembali', 14]],
        baris: telat.map((x) => ({ ...kelasKamar(x), ket: x.luar.alasan, batas: formatWaktu(x.luar.batas) })) } },
  ]
  return k
})

// ---------- Kartu pegawai ----------
const kartuPegawai = computed(() => {
  const n = (f) => pegawai.value.filter(f).length; const terjadwal = pegawai.value.filter((p) => p.status !== 'libur')
  const isc = (p) => ['izin', 'sakit', 'cuti'].includes(p.status); const belum = (p) => ['belum', 'menunggu_verval', 'tanpa_keterangan'].includes(p.status)
  return [
    { j: 'Hadir', v: `${n((p) => ['hadir', 'terlambat'].includes(p.status))}/${terjadwal.length}`, i: PhUserCheck, w: 'presensi', ket: 'Dari pegawai terjadwal hari ini',
      daftar: { judul: 'Pegawai hadir hari ini', kolom: K_PEG, baris: pegBaris((p) => ['hadir', 'terlambat'].includes(p.status)) } },
    { j: 'Terlambat', v: n((p) => p.status === 'terlambat'), i: PhClock, w: 'pengajuan', ket: 'Datang lewat batas tepat waktu',
      daftar: { judul: 'Pegawai terlambat hari ini', kolom: K_PEG, baris: pegBaris((p) => p.status === 'terlambat') } },
    { j: 'Dinas luar', v: n((p) => p.status === 'dinas_luar'), i: PhAirplaneTilt, w: 'jadwal', ket: 'Bertugas di luar pondok',
      daftar: { judul: 'Pegawai dinas luar', kolom: K_PEG, baris: pegBaris((p) => p.status === 'dinas_luar') } },
    { j: 'Izin, sakit, cuti', v: n(isc), i: PhUserMinus, w: 'klinik', ket: `${n((p) => p.status === 'izin')} izin · ${n((p) => p.status === 'sakit')} sakit · ${n((p) => p.status === 'cuti')} cuti`,
      daftar: { judul: 'Pegawai izin, sakit, atau cuti', kolom: K_PEG, baris: pegBaris(isc).map((p) => ({ ...p, ket: p.ket !== '–' ? p.ket : { izin: 'Izin', sakit: 'Sakit', cuti: 'Cuti' }[p.status] })) } },
    { j: 'Belum presensi', v: n(belum), i: PhHourglass, w: 'agenda', ket: `${n((p) => p.status === 'akan_datang')} sesinya belum dibuka`,
      daftar: { judul: 'Pegawai belum presensi', kolom: K_PEG, baris: pegBaris(belum).map((p) => ({ ...p, ket: { belum: 'Belum presensi', menunggu_verval: 'Menunggu verval', tanpa_keterangan: 'Tanpa keterangan' }[p.status] })) } },
    { j: 'Tidak terjadwal', v: n((p) => p.status === 'libur'), i: PhCalendarCheck, w: 'hakakses', ket: 'Libur/tidak ada sesi hari ini',
      daftar: { judul: 'Pegawai tidak terjadwal hari ini', kolom: K_PEG, baris: pegBaris((p) => p.status === 'libur') } },
  ]
})

// ---------- Kartu kegiatan ----------
const STATUS_SESI = { terisi: 'Terlaksana', terbuka: 'Sedang berlangsung', belum_buka: 'Belum dimulai', tidak_terisi: 'Tidak terisi', lewat: 'Lewat batas' }
const kartuKegiatan = computed(() => [['kelas', 'Sesi kelas', PhChalkboardTeacher, 'jadwal'], ['halaqah', 'Sesi halaqah', PhBookOpenText, 'tahfizh'], ['asrama', 'Sesi asrama', PhBed, 'musyrif'], ['ekskul', 'Sesi ekskul', PhUsersThree, 'ekskul']]
  .map(([k, j, i, w]) => {
    const s = kegiatan.value.filter((x) => x.jenis === k); const ok = s.filter((x) => x.status === 'terisi'); const telat = s.filter((x) => x.status === 'tidak_terisi')
    return { j, v: `${ok.length}/${s.length}`, i, w, ket: telat.length ? `${telat.length} lewat waktu, belum diisi` : `${s.length - ok.length} belum terlaksana`,
      daftar: { judul: `${j} hari ini`, kolom: [['jam', 'Jam', 7], ['kelompok', 'Kelompok', 16], ['sesi', 'Sesi', 16], ['pengampu', 'Pengampu', 24], ['status', 'Status', 14], ['hadir', 'Hadir', 9]],
        baris: [...s].sort((a, b) => (a.jam_mulai || '').localeCompare(b.jam_mulai || '')).map((x) => ({ ...x, jam: (x.jam_mulai || '').slice(0, 5), pengampu: x.pengampu || '–',
          status: STATUS_SESI[x.status] || x.status, hadir: x.status === 'terisi' ? `${x.hadir ?? 0}/${x.anggota ?? 0}` : '–' })) } }
  }))

// ---------- Kartu Security ----------
const K_GERBANG = [['jam', 'Jam', 7], ['nama', 'Nama santri', 24], ['kelas', 'Kelas', 7], ['kamar', 'Kamar', 14], ['ket', 'Keterangan', 26], ['petugas', 'Petugas', 16]]
const kartuSecurity = computed(() => {
  const g = sec.value.gerbang; const t = sec.value.titipan; const tm = sec.value.tamu; const kj = sec.value.kunjungan
  const gb = (j) => g.filter((x) => x.jenis === j).map((x) => ({ ...x, jam: formatJam(x.waktu), kelas: x.kelas || '–', kamar: x.kamar || '–', petugas: x.petugas || '–',
    ket: [x.penjemput && 'Penjemput ' + x.penjemput, x.terlambat_menit && 'Terlambat ' + x.terlambat_menit + ' menit', x.catatan].filter(Boolean).join('; ') || '–' }))
  const tBaris = (f) => t.filter(f).map((x) => ({ ...x, kelas: x.kelas || '–', barang: `${JENIS_TITIPAN[x.jenis]?.n}: ${x.uraian}`, diterima: formatWaktu(x.diterima_pada),
    ambil: x.status === 'di_pos' ? 'Masih di pos' : x.status === 'diambil' ? `${x.pengambil_nama} (${PENGAMBIL[x.pengambil_jenis] || ''}) ${formatJam(x.diambil_pada)}` : x.status }))
  const K_T = [['nama', 'Santri', 22], ['kelas', 'Kelas', 7], ['barang', 'Barang', 26], ['pengirim', 'Pengirim', 16], ['diterima', 'Diterima', 14], ['ambil', 'Pengambilan', 24]]
  return [
    { j: 'Keluar hari ini', v: g.filter((x) => x.jenis === 'keluar').length, i: PhSignOut, w: 'shift', ket: 'Tercatat di gerbang', daftar: { judul: 'Santri keluar hari ini', kolom: K_GERBANG, baris: gb('keluar') } },
    { j: 'Kembali hari ini', v: g.filter((x) => x.jenis === 'kembali').length, i: PhSignIn, w: 'presensi', ket: `${g.filter((x) => x.jenis === 'kembali' && x.terlambat_menit).length} terlambat`, daftar: { judul: 'Santri kembali hari ini', kolom: K_GERBANG, baris: gb('kembali') } },
    { j: 'Ditolak di gerbang', v: g.filter((x) => x.jenis === 'ditolak').length, i: PhProhibit, w: 'klinik', ket: 'Tanpa izin berlaku', daftar: { judul: 'Santri ditolak di gerbang', kolom: K_GERBANG, baris: gb('ditolak') } },
    { j: 'Titipan di pos', v: t.filter((x) => x.status === 'di_pos').length, i: PhPackage, w: 'pengajuan', ket: `${t.filter((x) => hariIni(x.diterima_pada)).length} diterima hari ini`,
      daftar: { judul: 'Titipan di pos dan diterima hari ini', kolom: K_T, baris: tBaris((x) => x.status === 'di_pos' || hariIni(x.diterima_pada)) } },
    { j: 'Titipan diambil', v: t.filter((x) => x.status === 'diambil' && hariIni(x.diambil_pada)).length, i: PhHandArrowDown, w: 'gaji', ket: 'Hari ini, tercatat pengambilnya',
      daftar: { judul: 'Titipan diambil hari ini', kolom: K_T, baris: tBaris((x) => x.status === 'diambil' && hariIni(x.diambil_pada)) } },
    { j: 'Tamu', v: tm.filter((x) => !x.keluar_pada).length, i: PhIdentificationBadge, w: 'pegawai', ket: `di dalam · ${tm.filter((x) => hariIni(x.masuk_pada)).length} tamu hari ini`,
      daftar: { judul: 'Tamu hari ini', kolom: [['jam', 'Masuk', 7], ['nama', 'Nama tamu', 20], ['instansi', 'Instansi', 18], ['keperluan', 'Keperluan', 24], ['ditemui', 'Menemui', 18], ['keluar', 'Keluar', 9]],
        baris: tm.map((x) => ({ ...x, jam: formatJam(x.masuk_pada), instansi: x.instansi || 'Pribadi', ditemui: x.ditemui || '–', keluar: x.keluar_pada ? formatJam(x.keluar_pada) : 'Di dalam' })) } },
    { j: 'Kunjungan wali', v: kj.filter((x) => !x.pulang_pada).length, i: PhUsersThree, w: 'tahfizh', ket: `berlangsung · ${kj.filter((x) => hariIni(x.datang_pada)).length} hari ini`,
      daftar: { judul: 'Kunjungan orang tua hari ini', kolom: [['jam', 'Datang', 7], ['nama', 'Santri', 22], ['kelas', 'Kelas', 7], ['pengunjung', 'Pengunjung', 24], ['pulang', 'Pulang', 10]],
        baris: kj.map((x) => ({ ...x, jam: formatJam(x.datang_pada), kelas: x.kelas || '–', pengunjung: x.pengunjung + (x.hubungan ? ` (${x.hubungan})` : ''), pulang: x.pulang_pada ? formatJam(x.pulang_pada) : 'Berlangsung' })) } },
  ]
})

// ---------- Daftar, cetak, Excel ----------
const lembar = ref(false); const daftar = ref(null); const pratinjau = ref(false); const penanda = ref({ jabatan: 'Direktur', nama: '', niy: '' })
function buka(k) { daftar.value = k.daftar; lembar.value = true }
const saringanTeks = computed(() => [jk.value === 'L' ? 'putra' : jk.value === 'P' ? 'putri' : '', jenjang.value ? JENJANG_PENDEK[jenjang.value] : '',
  bidang.value ? d.value.bidang.find((b) => b.id === bidang.value)?.nama : ''].filter(Boolean).join(', '))
async function cetak() { penanda.value = await penandaKelompok({ jenis: 'umum' }).catch(() => penanda.value); pratinjau.value = true }
function ekspor() {
  const x = daftar.value
  const ws = XLSX.utils.aoa_to_sheet([[x.judul], [`${formatPanjang(hari.value)}, pukul ${formatJam(d.value.waktu)} WITA${saringanTeks.value ? ' · ' + saringanTeks.value : ''}`], [],
    ['No.', ...x.kolom.map((c) => c[1])], ...x.baris.map((b, i) => [i + 1, ...x.kolom.map((c) => b[c[0]] ?? '')])])
  ws['!cols'] = [{ wch: 5 }, ...x.kolom.map((c) => ({ wch: c[2] + 6 }))]
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Pantauan'); XLSX.writeFile(wb, `Pantauan-${x.judul.replace(/[^\w]+/g, '-')}-${hari.value}.xlsx`)
}
const bagian = computed(() => [
  { judul: 'Santri', ikon: PhStudent, kartu: kartuSantri.value },
  { judul: 'Pegawai', ikon: PhUserCheck, kartu: kartuPegawai.value },
  { judul: 'Kegiatan santri dan pengampu', ikon: PhChalkboardTeacher, kartu: kartuKegiatan.value },
  { judul: 'Security', ikon: PhSignOut, kartu: kartuSecurity.value },
])
</script>
<template>
  <div v-if="pt.galat && !pt.data" class="kartu flex flex-col items-center gap-2 p-8 text-center text-sm text-teks2">
    <PhLock :size="36" weight="duotone" class="text-teks3" /> {{ pt.galat }}
  </div>
  <div v-else>
    <div class="kartu w-shift flex flex-wrap items-center gap-2 p-3">
      <span class="flex items-center gap-2 text-sm font-semibold"><span class="relative flex h-2.5 w-2.5"><span class="absolute inline-flex h-full w-full animate-ping rounded-full bg-[#1E7D4F] opacity-60" /><span class="relative inline-flex h-2.5 w-2.5 rounded-full bg-[#1E7D4F]" /></span>
        Langsung · {{ pt.data ? formatJam(pt.data.waktu) + ' WITA' : 'memuat…' }}</span>
      <button class="tombol-teks min-h-[36px] px-2" :disabled="pt.memuat" aria-label="Muat ulang" @click="pt.muat()"><PhArrowClockwise :size="18" :class="pt.memuat && 'animate-spin'" /></button>
      <div class="ml-auto flex flex-wrap gap-2">
        <select v-model="jk" class="isian min-h-[40px] w-auto py-1.5 text-sm" aria-label="Saring jenis kelamin"><option value="">Putra dan putri</option><option value="L">Putra</option><option value="P">Putri</option></select>
        <select v-model="jenjang" class="isian min-h-[40px] w-auto py-1.5 text-sm" aria-label="Saring jenjang"><option value="">Semua jenjang</option><option v-for="(n, k) in JENJANG_PENDEK" :key="k" :value="k">{{ n }}</option></select>
        <select v-model="bidang" class="isian min-h-[40px] w-auto py-1.5 text-sm" aria-label="Saring bidang pegawai"><option value="">Semua bidang</option><option v-for="b in d.bidang" :key="b.id" :value="b.id">{{ b.nama }}</option></select>
      </div>
    </div>
    <p class="mt-2 text-xs text-teks3">Ketuk setiap angka untuk melihat daftar nama, lalu cetak atau unduh Excel. Saringan bidang berlaku untuk pegawai; jenjang untuk santri dan kegiatan.</p>

    <section v-for="b in bagian" :key="b.judul" class="mt-5">
      <h2 class="judul-bagian mb-3 flex items-center gap-2"><component :is="b.ikon" :size="22" weight="duotone" /> {{ b.judul }}</h2>
      <div class="grid grid-cols-2 gap-3 sm:gap-4 lg:grid-cols-4">
        <button v-for="k in b.kartu" :key="k.j" type="button" class="text-left" :aria-label="`${k.j}: ${k.v}. Lihat daftar`" @click="buka(k)">
          <KartuStatistik :judul="k.j" :nilai="pt.data ? k.v : '…'" :ikon="k.i" :warna="k.w" :keterangan="k.ket" />
        </button>
      </div>
    </section>

    <LembarBawah v-model="lembar" lebar :judul="daftar?.judul || 'Daftar'">
      <div v-if="daftar" class="pb-2">
        <div class="mb-3 flex flex-wrap items-center gap-2">
          <p class="flex-1 text-sm text-teks2">{{ daftar.baris.length }} data · {{ formatPanjang(hari) }}{{ saringanTeks ? ' · ' + saringanTeks : '' }}</p>
          <button class="tombol-garis w-pengajuan min-h-[40px] px-3 text-sm" @click="cetak"><PhEye :size="18" style="color: var(--c)" /> Cetak</button>
          <button class="tombol-garis w-santri min-h-[40px] px-3 text-sm" @click="ekspor"><PhDownloadSimple :size="18" style="color: var(--c)" /> Excel</button>
        </div>
        <div class="max-h-[60vh] overflow-auto rounded-xl border border-garis">
          <table class="w-full min-w-[560px] text-left text-sm">
            <thead class="sticky top-0 bg-permukaan2 text-teks2"><tr><th class="px-3 py-2 font-bold">No.</th><th v-for="c in daftar.kolom" :key="c[0]" class="px-3 py-2 font-bold">{{ c[1] }}</th></tr></thead>
            <tbody class="divide-y divide-garis">
              <tr v-for="(r, i) in daftar.baris" :key="i"><td class="px-3 py-2 tabular-nums text-teks3">{{ i + 1 }}</td><td v-for="c in daftar.kolom" :key="c[0]" class="px-3 py-2">{{ r[c[0]] ?? '–' }}</td></tr>
            </tbody>
          </table>
          <p v-if="!daftar.baris.length" class="py-6 text-center text-sm text-teks3">Tidak ada data.</p>
        </div>
      </div>
    </LembarBawah>

    <DokumenCetak v-if="daftar" kop="pondok" :judul="daftar.judul" :subjudul="`${formatPanjang(hari)}, pukul ${formatJam(d.waktu)} WITA${saringanTeks ? ' · ' + saringanTeks : ''}`"
      v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap" :mendatar="daftar.kolom.length > 5">
      <p style="margin: 0 0 6pt">Jumlah: {{ daftar.baris.length }}</p>
      <table class="tabel kecil">
        <thead><tr><th style="width:5%">No.</th><th v-for="c in daftar.kolom" :key="c[0]" :style="{ width: c[2] + '%' }">{{ c[1] }}</th></tr></thead>
        <tbody>
          <tr v-for="(r, i) in daftar.baris" :key="i"><td class="tengah">{{ i + 1 }}</td><td v-for="c in daftar.kolom" :key="c[0]">{{ r[c[0]] ?? '–' }}</td></tr>
          <tr v-if="!daftar.baris.length"><td :colspan="daftar.kolom.length + 1" class="tengah">Tidak ada data.</td></tr>
        </tbody>
      </table>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: penanda.jabatan || 'Direktur', nama: penanda.nama, niy: penanda.niy }"
          :kanan="{ jabatan: sesi.pengguna?.jabatan || 'Pencetak', nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
      </template>
    </DokumenCetak>
  </div>
</template>
