<!-- SIMKA PRO | src/pages/santri/RekamSantri.vue | v1.4 | 14.30.0: label saringan yang sudah jelas disembunyikan (hemat ruang) | 29/10/2026 -->
<script setup>
// Rekam Kesantrian: laporan menyeluruh satu santri pada satu periode, seperti Rekam Kepegawaian.
//   Kepala     : foto, nama, NIS/NISN, JK, jenjang, kelas/kamar/halaqah, status
//   Ringkasan  : kartu langsung (kehadiran, hafalan, juz tuntas, nilai, prestasi, pelanggaran, klinik, izin, tunggakan)
//   Temuan     : catatan otomatis (baik, perlu perhatian, informasi), tanpa skor
//   Grafik     : kehadiran per bulan per program (garis), komposisi kehadiran (lingkaran), hafalan per bulan (batang),
//                nilai akhir semester terakhir (batang, dengan KKM), rata-rata nilai per semester (garis)
//   Tabel      : data singkat, kelompok dan riwayatnya, kehadiran per program + tidak hadir, hafalan dan capaian bulanan, ujian tahfizh dan UTAS,
//                nilai akhir per semester, prestasi, kedisiplinan, security, klinik (ringkas), perizinan dan libur, keuangan, riwayat status
//   Cetak F4   : kop, identitas, temuan, tabel dan grafik; "Mengetahui" Kepala Bidang Kesantrian (kiri) dan wali kelas (kanan). Excel per bagian.
// Hak baca diperiksa server (sama dengan Detail Santri). Kedisiplinan hanya bagi yang berhak; keuangan hanya pemegang akses keuangan.
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import * as XLSX from 'xlsx'
import { PhUserCircle, PhCalendarCheck, PhBookOpenText, PhSealCheck, PhExam, PhMedal, PhGavel, PhFirstAidKit, PhSignOut, PhWallet, PhPrinter, PhFileXls,
  PhCheckCircle, PhInfo, PhWarning, PhArrowLeft, PhCaretLeft, PhCaretRight, PhUsersThree, PhShieldCheck, PhAddressBook, PhClockCounterClockwise, PhFolderUser } from '@phosphor-icons/vue'
import { useSantri } from '@/stores/santri'
import { useSesi } from '@/stores/sesi'
import { useLembaga } from '@/stores/lembaga'
import { useAmbang } from '@/stores/ambang'
import { useUI } from '@/stores/ui'
import { muatRekamSantri, temuanSantri, hadirPokok, nilaiTerakhir, rataSemester, JENIS_KELOMPOK_REKAM, PENGASUH_KELOMPOK, PROGRAM_REKAM, KEPUTUSAN_RAPOR,
  JENIS_UJIAN_TAHFIZH, JENIS_RIWAYAT_SANTRI, AKSI_KENAIKAN, JENIS_GERBANG } from '@/lib/rekamSantri'
import { JENJANG, STATUS_SANTRI, HUBUNGAN, namaKelompok, penandaKelompok } from '@/lib/santri'
import { KODE } from '@/lib/absensi'
import { formatPosisi, PROGRAM, SUMBER_JUZ, STATUS_BULANAN } from '@/lib/tahfizh'
import { BIDANG_PRESTASI, TINGKAT_PRESTASI } from '@/lib/prestasi'
import { TINGKAT_PELANGGARAN, KEADAAN_SP_SANTRI } from '@/lib/disiplin'
import { TINDAK_LANJUT, HASIL_KASUS } from '@/lib/klinik'
import { STATUS_IZIN, JENIS_IZIN, HASIL_LIBUR } from '@/lib/izin'
import { rupiah, angka } from '@/lib/gaji'
import { formatPendek, formatPanjang, formatWaktu, hariIniISO, BULAN } from '@/lib/tanggal'
import { namaBerkas, periodeRentang } from '@/lib/namaBerkas'
import KartuStatistik from '@/components/KartuStatistik.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import GrafikDeret from '@/components/grafik/GrafikDeret.vue'
import GrafikLingkaran from '@/components/grafik/GrafikLingkaran.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const route = useRoute(); const router = useRouter(); const san = useSantri(); const sesi = useSesi(); const lembaga = useLembaga(); const ambang = useAmbang(); const ui = useUI()
const id = computed(() => String(route.params.id))
const hari = hariIniISO()
const geser = (iso, bulan) => { const d = new Date(iso + 'T00:00:00Z'); d.setUTCMonth(d.getUTCMonth() + bulan); return d.toISOString().slice(0, 10) }
const thTA = Number(hari.slice(0, 4)) - (Number(hari.slice(5, 7)) < 7 ? 1 : 0)
const PRESET = [
  { k: '3b', n: '3 bulan terakhir', m: geser(hari, -3), s: hari },
  { k: 'sem', n: 'Semester berjalan', m: Number(hari.slice(5, 7)) >= 7 ? `${thTA}-07-01` : `${thTA + 1}-01-01`, s: hari },
  { k: 'ta', n: 'Tahun ajaran', m: `${thTA}-07-01`, s: hari },
  { k: '12b', n: '12 bulan terakhir', m: geser(hari, -12), s: hari },
]
const q = route.query
const preset = ref(typeof q.preset === 'string' ? q.preset : 'sem')
const mulai = ref(typeof q.mulai === 'string' ? q.mulai : PRESET[1].m); const selesai = ref(typeof q.selesai === 'string' ? q.selesai : PRESET[1].s)
const pilih = (p) => { preset.value = p.k; mulai.value = p.m; selesai.value = p.s }
const r = ref(null); const memuat = ref(false); const foto = ref('')
async function muat() {
  if (!id.value) return
  if (selesai.value < mulai.value) return ui.toast('Tanggal akhir tidak boleh sebelum tanggal awal.', 'galat')
  memuat.value = true
  try { r.value = await muatRekamSantri(id.value, mulai.value, selesai.value) } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
const kesantrian = ref({ jabatan: 'Kepala Bidang Kesantrian', nama: '', niy: '' })
onMounted(async () => { if (!san.daftar.length) await san.muat().catch(() => {}); muat(); lembaga.muat().catch(() => {}); ambang.muat().catch(() => {})
  try { kesantrian.value = await penandaKelompok({ jenis: 'kamar' }) } catch { /* cadangan di atas */ } })
watch([mulai, selesai, id], muat)

// ---------- Navigasi: kembali, sebelumnya, berikutnya (urutan kelas lalu nama; periode ikut terbawa) ----------
const urutan = computed(() => [...san.daftar].filter((x) => x.status === 'aktif')
  .sort((a, b) => (namaKelompok(a, 'kelas') || `~${a.tingkat}`).localeCompare(namaKelompok(b, 'kelas') || `~${b.tingkat}`, 'id', { numeric: true }) || String(a.nama_lengkap).localeCompare(String(b.nama_lengkap), 'id')))
const posisi = computed(() => urutan.value.findIndex((x) => x.id === id.value))
const sebelum = computed(() => (posisi.value > 0 ? urutan.value[posisi.value - 1] : null))
const sesudah = computed(() => (posisi.value >= 0 && posisi.value < urutan.value.length - 1 ? urutan.value[posisi.value + 1] : null))
function pindah(x) { if (x) router.replace({ path: `/santri/${x.id}/rekam`, query: { mulai: mulai.value, selesai: selesai.value, preset: preset.value } }) }
function kembali() { if (window.history.state?.back) router.back(); else router.push(`/santri/${id.value}`) }
watch(() => r.value?.profil?.id, async (sid) => { if (!sid) return; const s = san.cari(sid); try { foto.value = (s && (await san.urlFoto(s))) || '' } catch { foto.value = '' } })

// ---------- Ringkasan ----------
const P = computed(() => r.value?.profil || {})
const batas = computed(() => ambang.batas('santri'))
const fmt = (v, d = '–') => (v == null ? d : String(v).replace('.', ','))
const kelompokJenis = (j) => (r.value?.kelompok || []).filter((k) => k.jenis === j)
const kelas = computed(() => kelompokJenis('kelas')[0] || null)
const rombel = computed(() => (kelas.value ? `Kelas ${kelas.value.nama.replace(/^kelas\s*/i, '')}` : P.value.tingkat ? `Kelas ${P.value.tingkat}` : '–'))
const ttl = computed(() => [P.value.tempat_lahir, P.value.tanggal_lahir && formatPanjang(P.value.tanggal_lahir)].filter(Boolean).join(', ') || '–')
const hp = computed(() => hadirPokok(r.value))
const prog = computed(() => r.value?.kehadiran?.program || {})
const hf = computed(() => r.value?.hafalan || {})
const juzTuntas = computed(() => (hf.value.juz || []).length)
const nTerakhir = computed(() => nilaiTerakhir(r.value))
const prestasiPeriode = computed(() => (r.value?.prestasi || []).filter((p) => p.dalam_periode))
const pelPeriode = computed(() => (r.value?.pelanggaran || []).filter((p) => p.dalam_periode))
const spAktif = computed(() => (r.value?.sp || []).filter((w) => w.keadaan === 'aktif'))
const izinLambat = computed(() => (r.value?.izin || []).filter((x) => x.terlambat).length)
const keu = computed(() => r.value?.keuangan || null)
const KARTU = computed(() => {
  const n = !r.value ? '…' : null
  return [
    { judul: 'Kehadiran', nilai: n ?? (hp.value.persen == null ? '–' : `${fmt(hp.value.persen)}%`), ikon: PhCalendarCheck, warna: hp.value.persen != null && hp.value.persen < batas.value ? 'klinik' : 'presensi', ket: `${hp.value.sesi} sesi pokok · batas ${batas.value}%` },
    { judul: 'Hafalan', nilai: n ?? (formatPosisi(hf.value.sabaq_hal) || '0'), ikon: PhBookOpenText, warna: 'tahfizh', ket: `Bertambah ${formatPosisi(hf.value.setoran?.tambah_hal) || '0'} pada periode` },
    { judul: 'Juz tuntas', nilai: n ?? juzTuntas.value, ikon: PhSealCheck, warna: 'libursantri', ket: `${(r.value?.ujian || []).length} ujian tahfizh · ${(r.value?.utas || []).length} UTAS` },
    { judul: 'Rata-rata nilai', nilai: n ?? (nTerakhir.value ? fmt(nTerakhir.value.rata) : '–'), ikon: PhExam, warna: 'rapor', ket: nTerakhir.value ? `Smt ${nTerakhir.value.semester} ${nTerakhir.value.ta} · ${nTerakhir.value.kurang.length} belum tuntas` : 'Belum ada nilai rapor' },
    { judul: 'Prestasi', nilai: n ?? (r.value?.prestasi || []).length, ikon: PhMedal, warna: 'prestasi', ket: `${prestasiPeriode.value.length} pada periode ini` },
    ...(r.value?.pelanggaran ? [{ judul: 'Pelanggaran', nilai: n ?? pelPeriode.value.length, ikon: PhGavel, warna: 'disiplin', ket: spAktif.value.length ? `SP-${Math.max(...spAktif.value.map((w) => w.tingkat))} masih berlaku` : 'Tidak ada SP berlaku' }] : []),
    { judul: 'Klinik', nilai: n ?? (r.value?.klinik?.kasus || 0), ikon: PhFirstAidKit, warna: 'klinik', ket: `${r.value?.klinik?.istirahat || 0} kali istirahat/rawat` },
    { judul: 'Izin keluar/pulang', nilai: n ?? (r.value?.izin || []).length, ikon: PhSignOut, warna: 'security', ket: `Terlambat kembali ${izinLambat.value} kali` },
    ...(keu.value ? [{ judul: 'Tunggakan', nilai: n ?? rupiah(keu.value.ringkas?.tunggakan), ikon: PhWallet, warna: 'keuangan', ket: `Sisa tagihan ${rupiah(keu.value.ringkas?.sisa)}` }] : []),
  ]
})
const catatan = computed(() => temuanSantri(r.value, batas.value))
const IKON_TEMUAN = { baik: { ikon: PhCheckCircle, w: 'presensi' }, perhatian: { ikon: PhWarning, w: 'klinik' }, info: { ikon: PhInfo, w: 'shift' } }

// ---------- Grafik ----------
const labelBulanDari = (b) => `${BULAN[Number(String(b).slice(5, 7)) - 1].slice(0, 3)} ${String(b).slice(2, 4)}`
const kb = computed(() => r.value?.kehadiran?.bulan || [])
const labelBulan = computed(() => kb.value.map((b) => labelBulanDari(b.bulan)))
const gKehadiran = computed(() => [{ n: 'Kelas', nilai: kb.value.map((b) => b.kelas) }, { n: 'Halaqah', nilai: kb.value.map((b) => b.halaqah) },
  { n: 'Asrama', nilai: kb.value.map((b) => b.asrama) }, { n: `Batas ${batas.value}%`, nilai: kb.value.map(() => batas.value) }])
const gKomposisi = computed(() => [
  { n: 'Hadir', nilai: Math.max(0, hp.value.hadir - hp.value.terlambat - hp.value.bolos), warna: '#1E7D4F' }, { n: 'Terlambat', nilai: hp.value.terlambat, warna: '#C98500' },
  { n: 'Izin', nilai: hp.value.izin, warna: '#2A78D6' }, { n: 'Sakit', nilai: hp.value.sakit, warna: '#B42A5E' },
  { n: 'Bolos', nilai: hp.value.bolos, warna: '#EB6834' }, { n: 'Absen', nilai: hp.value.absen, warna: '#46525F' }])
const sb = computed(() => hf.value.setoran_bulan || [])
const gHafalan = computed(() => { const tgt = Object.fromEntries((hf.value.bulanan || []).map((b) => [String(b.bulan).slice(0, 7), b.target_hal]))
  return [{ n: 'Hafalan baru (halaman)', nilai: sb.value.map((b) => b.tambah_hal) }, { n: 'Target bulanan', nilai: sb.value.map((b) => tgt[b.bulan] ?? null) }] })
const gNilai = computed(() => { const s = nTerakhir.value; if (!s) return [] ; const m = s.mapel.filter((x) => x.nilai != null)
  return [{ n: 'Nilai akhir', nilai: m.map((x) => Number(x.nilai)) }, { n: 'KKM', nilai: m.map((x) => Number(x.kkm || 0)) }] })
const labelNilai = computed(() => (nTerakhir.value?.mapel || []).filter((x) => x.nilai != null).map((x) => (x.nama.length > 14 ? x.nama.split(' ').map((w) => w[0]).join('').toUpperCase() : x.nama)))
const semesterNilai = computed(() => (r.value?.nilai || []).filter((s) => rataSemester(s) != null))
const gTrenNilai = computed(() => [{ n: 'Rata-rata nilai', nilai: semesterNilai.value.map((s) => rataSemester(s)) }])
const labelTren = computed(() => semesterNilai.value.map((s) => `${s.ta.slice(2, 4)}/${s.ta.slice(7, 9)} S${s.semester}`))

// ---------- Nilai per semester (sub-tab) ----------
const smtPilih = ref(-1)
watch(() => r.value?.nilai, (n) => { smtPilih.value = (n || []).length - 1 })
const smt = computed(() => (r.value?.nilai || [])[smtPilih.value] || null)
const labelSmt = (s) => `${s.ta} · Smt ${s.semester}`

// ---------- Kelompok binaan per tahun ----------
const kelompokTahun = computed(() => { const m = new Map(); for (const k of r.value?.riwayat_kelompok || []) { if (!m.has(k.tahun)) m.set(k.tahun, []); m.get(k.tahun).push(k) } return [...m.entries()] })
const WARNA_KELOMPOK = { kelas: 'bg-[#3F6212]', kamar: 'bg-[#245E3F]', halaqah: 'bg-[#8C6200]', ekskul: 'bg-[#9D174D]', lainnya: 'bg-[#46525F]' }
const teksRiwayat = (h) => (h.jenis === 'kenaikan' ? `${AKSI_KENAIKAN[h.aksi] || h.aksi}: kelas ${h.lama} → ${h.baru ?? '–'} (${h.tahun})`
  : h.jenis === 'status' ? `${h.lama ? (STATUS_SANTRI[h.lama]?.n || h.lama) + ' → ' : ''}${STATUS_SANTRI[h.baru]?.n || h.baru}` : `${h.baru || '–'}${h.nomor ? ' · ' + h.nomor : ''}`)

// ---------- Cetak dan Excel ----------
const pratinjau = ref(false)
const subjudul = computed(() => `${P.value.nama || ''} · periode ${formatPanjang(mulai.value)} s.d. ${formatPanjang(selesai.value)}`)
const huruf = computed(() => { const daftar = ['identitas', 'kehadiran', 'hafalan', 'nilai', 'prestasi', ...(r.value?.pelanggaran ? ['disiplin'] : []), 'security', 'klinik', 'izin', ...(keu.value ? ['keuangan'] : []), 'riwayat']
  return Object.fromEntries(daftar.map((k, i) => [k, String.fromCharCode(65 + i)])) })
const teksKode = (k) => KODE[k]?.n || k
function excel() {
  const x = r.value; if (!x) return
  const wb = XLSX.utils.book_new(); const lembar = (n, aoa, w) => { const ws = XLSX.utils.aoa_to_sheet(aoa); ws['!cols'] = w.map((c) => ({ wch: c })); XLSX.utils.book_append_sheet(wb, ws, n) }
  lembar('Identitas', [['Rekam Kesantrian', subjudul.value], [], ['NIS', P.value.nis], ['NISN', P.value.nisn || '–'], ['Nama', P.value.nama], ['JK', P.value.jenis_kelamin],
    ['Tempat, tanggal lahir', ttl.value], ['Jenjang', JENJANG[P.value.jenjang] || P.value.jenjang], ['Kelas', rombel.value], ['Status', STATUS_SANTRI[P.value.status]?.n || P.value.status],
    ['Masuk pondok', `${formatPendek(P.value.tanggal_masuk)} (angkatan ${P.value.angkatan ?? '–'})`], ['Orang tua/wali', P.value.kontak ? `${P.value.kontak.nama} (${HUBUNGAN[P.value.kontak.hubungan] || P.value.kontak.hubungan})` : '–'],
    [], ['Kelompok', 'Nama', 'Pengasuh'], ...(x.kelompok || []).map((k) => [JENIS_KELOMPOK_REKAM[k.jenis] || k.jenis, k.nama, k.pengasuh || '–']),
    [], ['Temuan'], ...catatan.value.map((t) => [t.jenis, t.teks])], [22, 40, 34])
  lembar('Kehadiran', [['Program', 'Sesi', 'Hadir', 'Terlambat', 'Izin', 'Sakit', 'Bolos', 'Absen', '% hadir'],
    ...['kelas', 'halaqah', 'asrama', 'ekskul'].filter((k) => prog.value[k]).map((k) => { const p = prog.value[k]; return [PROGRAM_REKAM[k], p.sesi, p.hadir, p.terlambat, p.izin, p.sakit, p.bolos, p.absen, p.persen] }),
    [], ['Bulan', 'Sesi', 'Hadir', 'Izin', 'Sakit', 'Bolos', 'Absen', '% hadir', '% kelas', '% halaqah', '% asrama'],
    ...kb.value.map((b) => [b.bulan, b.sesi, b.hadir, b.izin, b.sakit, b.bolos, b.absen, b.persen, b.kelas, b.halaqah, b.asrama]),
    [], ['Tanggal', 'Program', 'Kelompok', 'Sesi', 'Status', 'Keterangan'], ...(x.kehadiran?.tidak_hadir || []).map((t) => [formatPendek(t.tanggal), PROGRAM_REKAM[t.jenis] || t.jenis, t.kelompok, t.sesi, teksKode(t.kode), t.keterangan || ''])],
    [14, 10, 12, 10, 8, 8, 8, 8, 9, 10, 10])
  lembar('Hafalan', [['Program', PROGRAM[hf.value.program] || hf.value.program], ['Sabaq', formatPosisi(hf.value.sabaq_hal, true)], ['Sabqi', formatPosisi(hf.value.sabqi_hal, true)], ['Manzil', formatPosisi(hf.value.manzil_hal, true)],
    ['Juz tuntas', (hf.value.juz || []).map((j) => j.juz).join(', ')], [], ['Bulan', 'Setoran', 'Hafalan baru (hal)', 'Target (hal)', 'Status capaian'],
    ...sb.value.map((b) => { const c = (hf.value.bulanan || []).find((y) => String(y.bulan).slice(0, 7) === b.bulan); return [b.bulan, b.sesi, b.tambah_hal, c?.target_hal ?? '', c ? STATUS_BULANAN[c.status]?.n || c.status : ''] }),
    [], ['Ujian', 'Juz', 'Tanggal', 'Tajwid', 'Itqan', 'Nilai akhir', 'Predikat', 'Hasil', 'Penguji'],
    ...(x.ujian || []).map((u) => [JENIS_UJIAN_TAHFIZH[u.jenis] || u.jenis, (u.juz || []).join(', '), formatPendek(u.tanggal), u.tajwid, u.itqan, u.nilai_akhir, u.predikat, u.hasil, u.penguji]),
    ...(x.utas || []).map((u) => [`UTAS ${u.ta} smt ${u.semester}`, (u.juz || []).join(', '), formatPendek(u.tanggal), u.tajwid, u.itqan, u.nilai_akhir, u.predikat, u.tuntas ? 'tuntas' : 'belum tuntas', ''])], [26, 14, 18, 12, 16, 12, 14, 12, 24])
  lembar('Nilai', [['Tahun ajaran', 'Semester', 'Kelas', 'Mata pelajaran', 'KKM', 'Nilai akhir', 'Predikat', 'Tuntas'],
    ...(x.nilai || []).flatMap((s) => s.mapel.map((m) => [s.ta, s.semester, s.kelas, m.nama, m.kkm, m.nilai, m.predikat || '', m.tuntas == null ? '' : m.tuntas ? 'Ya' : 'Belum'])),
    [], ['Tahun ajaran', 'Keputusan'], ...(x.nilai || []).filter((s) => s.keputusan).map((s) => [s.ta, KEPUTUSAN_RAPOR[s.keputusan.keputusan] || s.keputusan.keputusan])], [12, 9, 8, 30, 7, 10, 9, 8])
  lembar('Prestasi', [['Tanggal', 'Bidang', 'Tingkat', 'Kegiatan', 'Capaian', 'Penyelenggara'], ...(x.prestasi || []).map((p) => [formatPendek(p.tanggal), BIDANG_PRESTASI[p.bidang]?.n || p.bidang, TINGKAT_PRESTASI[p.tingkat] || p.tingkat, p.kegiatan, p.capaian, p.penyelenggara || ''])], [12, 14, 16, 40, 16, 24])
  if (x.pelanggaran) lembar('Kedisiplinan', [['Tanggal', 'Kategori', 'Tingkat', 'Tempat', 'Uraian', 'Tindakan'], ...x.pelanggaran.map((v) => [formatPendek(v.tanggal), v.kategori, TINGKAT_PELANGGARAN[v.tingkat]?.n || v.tingkat, v.tempat || '', v.uraian, v.tindakan || '']),
    [], ['SP', 'Nomor', 'Tanggal', 'Berlaku sampai', 'Keadaan', 'Pelanggaran'], ...(x.sp || []).map((w) => [`SP-${w.tingkat}`, w.nomor || '', formatPendek(w.tanggal), formatPendek(w.berlaku_sampai), KEADAAN_SP_SANTRI[w.keadaan]?.n || w.keadaan, (w.kategori || []).join('; ')])], [12, 24, 10, 14, 44, 26])
  lembar('Security dan izin', [['Keluar', x.security.keluar], ['Kembali', x.security.kembali], ['Terlambat kembali', x.security.terlambat], ['Ditolak keluar', x.security.ditolak], ['Kunjungan', x.security.kunjungan], ['Titipan', x.security.titipan],
    [], ['Waktu', 'Gerbang', 'Terlambat (menit)', 'Penjemput'], ...(x.security.gerbang || []).map((g) => [formatWaktu(g.waktu), JENIS_GERBANG[g.jenis] || g.jenis, g.terlambat_menit || '', g.penjemput || '']),
    [], ['Izin', 'Alasan', 'Keluar', 'Batas kembali', 'Kembali', 'Status', 'Terlambat'], ...(x.izin || []).map((z) => [JENIS_IZIN[z.jenis] || z.jenis, z.alasan, formatWaktu(z.keluar_pada), formatWaktu(z.kembali_batas), z.kembali_pada ? formatWaktu(z.kembali_pada) : '', STATUS_IZIN[z.status]?.p || z.status, z.terlambat ? 'Ya' : '']),
    [], ['Libur', 'Pulang', 'Keputusan'], ...(x.libur || []).map((l) => [l.periode, formatPendek(l.pulang_pada), HASIL_LIBUR[l.keputusan]?.n || l.keputusan])], [24, 28, 18, 18, 18, 12, 10])
  lembar('Klinik', [['Kasus', x.klinik.kasus], ['Istirahat/rawat', x.klinik.istirahat], ['Dirujuk', x.klinik.rujuk], ['Dipulangkan', x.klinik.pulang], [], ['Tanggal', 'Keluhan', 'Tindak lanjut', 'Hasil'],
    ...(x.klinik.daftar || []).map((c) => [formatPendek(c.tanggal), c.keluhan, TINDAK_LANJUT[c.tindak_lanjut]?.n || c.tindak_lanjut || '', HASIL_KASUS[c.hasil] || c.hasil || ''])], [14, 36, 24, 20])
  if (keu.value) lembar('Keuangan', [['Sisa tagihan', Number(keu.value.ringkas.sisa)], ['Tunggakan jatuh tempo', Number(keu.value.ringkas.tunggakan)], [], ['Tagihan', 'Jatuh tempo', 'Nominal', 'Dibayar', 'Status'],
    ...keu.value.tagihan.map((b) => [b.nama, formatPendek(b.jatuh_tempo), Number(b.nominal), Number(b.dibayar), b.status]), [], ['Tanggal bayar', 'Nomor', 'Jumlah', 'Cara'],
    ...keu.value.pembayaran.map((y) => [formatPendek(y.tanggal), y.nomor || '', Number(y.jumlah), y.cara])], [26, 24, 14, 14, 10])
  XLSX.writeFile(wb, `${namaBerkas(P.value.nama, 'Rekam Kesantrian', periodeRentang(mulai.value, selesai.value))}.xlsx`)
}
</script>
<template>
  <div class="w-santri">
    <div class="layar-saja">
      <!-- Navigasi -->
      <div class="mb-3 flex flex-wrap items-center gap-2">
        <button class="tombol-garis min-h-[44px] px-3 text-sm" @click="kembali"><PhArrowLeft :size="18" weight="bold" /> Kembali</button>
        <template v-if="urutan.length && posisi >= 0">
          <span class="flex-1 text-center text-sm text-teks3">Santri {{ posisi + 1 }}/{{ urutan.length }}</span>
          <button class="tombol-garis min-h-[44px] px-3 text-sm" :disabled="!sebelum" :title="sebelum?.nama_lengkap" @click="pindah(sebelum)"><PhCaretLeft :size="18" weight="bold" /> <span class="hidden sm:inline">Sebelumnya</span></button>
          <button class="tombol-garis min-h-[44px] px-3 text-sm" :disabled="!sesudah" :title="sesudah?.nama_lengkap" @click="pindah(sesudah)"><span class="hidden sm:inline">Berikutnya</span> <PhCaretRight :size="18" weight="bold" /></button>
        </template>
      </div>
      <!-- Kepala -->
      <section class="kartu overflow-hidden">
        <div class="kepala flex flex-wrap items-center gap-4 p-5">
          <img v-if="foto" :src="foto" :alt="'Foto ' + P.nama" class="h-20 w-16 rounded-xl object-cover ring-2 ring-white/60" />
          <span v-else class="grid h-20 w-16 place-items-center rounded-xl bg-white/20"><PhUserCircle :size="40" weight="duotone" /></span>
          <div class="min-w-0 flex-1">
            <p class="flex items-center gap-1.5 text-xs font-semibold uppercase tracking-wider opacity-90"><PhFolderUser :size="16" /> Rekam Kesantrian</p>
            <h2 class="text-xl font-extrabold leading-tight text-white">{{ P.nama || 'Memuat…' }}</h2>
            <p class="text-sm opacity-90">NIS {{ P.nis || '–' }}{{ P.nisn ? ' · NISN ' + P.nisn : '' }} · {{ P.jenis_kelamin === 'P' ? 'Perempuan' : 'Laki-laki' }}</p>
            <p class="text-sm opacity-90">{{ JENJANG[P.jenjang] || '–' }} · {{ rombel }}{{ kelompokJenis('kamar')[0] ? ' · ' + kelompokJenis('kamar')[0].nama : '' }} · {{ STATUS_SANTRI[P.status]?.n || P.status || '–' }}</p>
          </div>
          <div class="flex w-full gap-2 sm:w-auto [&>button]:flex-1 sm:[&>button]:flex-none">
            <button class="tombol-garis kepala-tombol min-h-[44px] px-3 text-sm" :disabled="!r" @click="excel"><PhFileXls :size="18" weight="duotone" /> Ekspor</button>
            <button class="tombol-garis kepala-tombol min-h-[44px] px-3 text-sm" :disabled="!r" @click="pratinjau = true"><PhPrinter :size="18" weight="duotone" /> Cetak</button>
          </div>
        </div>
      </section>

      <div class="bilah-tab kecil mt-4" role="tablist" aria-label="Periode rekam">
        <button v-for="p in PRESET" :key="p.k" type="button" role="tab" :aria-selected="preset === p.k" :class="['tab-garis', preset === p.k && 'aktif']" @click="pilih(p)">{{ p.n }}</button>
        <button type="button" role="tab" :aria-selected="preset === 'atur'" :class="['tab-garis', preset === 'atur' && 'aktif']" @click="preset = 'atur'">Atur sendiri</button>
      </div>
      <div v-if="preset === 'atur'" class="kartu mt-3 grid grid-cols-2 gap-3 p-4 sm:max-w-xl"><InputTanggal class="tanpa-label" v-model="mulai" label="Dari tanggal" /><InputTanggal class="tanpa-label" v-model="selesai" label="Sampai tanggal" /></div>

      <p v-if="memuat && !r" class="py-10 text-center text-teks3">Menyusun rekam kesantrian…</p>
      <template v-else-if="r">
        <div class="-mx-4 mt-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-3 sm:overflow-visible sm:px-0 xl:grid-cols-4">
          <KartuStatistik v-for="k in KARTU" :key="k.judul" class="w-[46%] shrink-0 snap-start sm:w-auto" :judul="k.judul" :nilai="k.nilai" :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket" />
        </div>

        <!-- Temuan -->
        <section class="kartu mt-4 p-5">
          <h3 class="judul-bagian mb-3">Temuan periode ini</h3>
          <ul class="grid gap-2 md:grid-cols-2">
            <li v-for="(t, i) in catatan" :key="i" :class="['flex items-start gap-2 rounded-xl border border-garis p-3 text-sm', 'w-' + IKON_TEMUAN[t.jenis].w]">
              <component :is="IKON_TEMUAN[t.jenis].ikon" :size="20" weight="duotone" class="mt-0.5 shrink-0" style="color: var(--c)" /><span>{{ t.teks }}</span></li>
          </ul>
        </section>

        <!-- Data singkat dan kelompok -->
        <div class="mt-4 grid gap-4 xl:grid-cols-2">
          <section class="kartu w-santri p-4"><h3 class="judul-bagian mb-2 flex items-center gap-2"><PhAddressBook :size="20" weight="duotone" style="color: var(--c)" /> Data singkat</h3>
            <dl class="grid grid-cols-[8.5rem_1fr] gap-x-3 gap-y-1.5 text-sm">
              <dt class="text-teks3">Tempat, tgl lahir</dt><dd>{{ ttl }}</dd>
              <dt class="text-teks3">Masuk pondok</dt><dd>{{ formatPendek(P.tanggal_masuk) }} · angkatan {{ P.angkatan ?? '–' }}{{ P.jalur_masuk === 'pindahan' ? ' (pindahan)' : '' }}</dd>
              <dt class="text-teks3">Asal sekolah</dt><dd>{{ P.asal_sekolah || '–' }}</dd>
              <dt class="text-teks3">Hafalan awal</dt><dd>{{ P.hafalan_awal_juz != null ? fmt(P.hafalan_awal_juz) + ' juz' : '–' }}</dd>
              <dt class="text-teks3">Domisili</dt><dd>{{ [P.kota, P.provinsi].filter(Boolean).join(', ') || '–' }}</dd>
              <dt class="text-teks3">Orang tua/wali</dt><dd>{{ P.kontak ? `${P.kontak.nama} (${HUBUNGAN[P.kontak.hubungan] || P.kontak.hubungan})` : '–' }}<span v-if="P.kontak?.no_hp" class="tabular-nums text-teks3"> · {{ P.kontak.no_hp }}</span></dd>
            </dl></section>
          <section class="kartu w-kelompoksantri p-4"><h3 class="judul-bagian mb-2 flex items-center gap-2"><PhUsersThree :size="20" weight="duotone" style="color: var(--c)" /> Kelompok berjalan</h3>
            <ul class="divide-y divide-garis text-sm"><li v-for="(k, i) in r.kelompok" :key="i" class="flex items-start justify-between gap-2 py-1.5">
              <span><b>{{ JENIS_KELOMPOK_REKAM[k.jenis] || k.jenis }}</b> {{ k.nama }}</span><span class="text-right text-xs text-teks3">{{ PENGASUH_KELOMPOK[k.jenis] }}: {{ k.pengasuh || '–' }}</span></li>
              <li v-if="!r.kelompok.length" class="py-1.5 text-teks3">Belum masuk kelompok pada tahun ajaran berjalan.</li></ul>
            <div v-if="kelompokTahun.length" class="mt-3 grid gap-2 sm:grid-cols-2">
              <div v-for="[th, isi] in kelompokTahun" :key="th" class="rounded-xl border border-garis p-2.5">
                <p class="mb-1 text-xs font-bold">Tahun ajaran {{ th }} <span v-if="isi.some((k) => k.aktif)" class="lencana w-presensi">Berjalan</span></p>
                <ul class="space-y-0.5 text-xs"><li v-for="(k, i) in isi" :key="i" class="flex items-start gap-1.5"><span :class="['mt-1 h-2 w-2 shrink-0 rounded-full', WARNA_KELOMPOK[k.jenis]]" />
                  <span>{{ JENIS_KELOMPOK_REKAM[k.jenis] }} {{ k.nama }}<span v-if="k.alasan" class="text-teks3"> · {{ k.alasan }}</span></span></li></ul>
              </div>
            </div></section>
        </div>

        <!-- Grafik -->
        <div class="mt-4 grid gap-4 xl:grid-cols-2">
          <section class="kartu w-presensi p-4"><h3 class="judul-bagian mb-2">Kehadiran per bulan</h3>
            <GrafikDeret :label="labelBulan" :seri="gKehadiran" jenis="garis" satuan="%" :maks="100" judul="Persentase kehadiran kelas, halaqah, dan asrama per bulan" /></section>
          <section class="kartu w-absensi p-4"><h3 class="judul-bagian mb-2">Komposisi kehadiran</h3>
            <GrafikLingkaran :data="gKomposisi" satuan="sesi" judul="Kelas, halaqah, dan asrama pada periode" /></section>
          <section class="kartu w-tahfizh p-4"><h3 class="judul-bagian mb-2">Hafalan baru per bulan</h3>
            <GrafikDeret :label="sb.map((b) => labelBulanDari(b.bulan))" :seri="gHafalan" jenis="batang" satuan="hal" judul="Hafalan baru dan target bulanan (halaman)" /></section>
          <section class="kartu w-rapor p-4"><h3 class="judul-bagian mb-2">Nilai akhir {{ nTerakhir ? `semester ${nTerakhir.semester} ${nTerakhir.ta}` : '' }}</h3>
            <GrafikDeret v-if="gNilai.length" :label="labelNilai" :seri="gNilai" jenis="batang" :maks="100" judul="Nilai akhir per mata pelajaran dan KKM" />
            <p v-else class="py-6 text-center text-sm text-teks3">Belum ada nilai rapor.</p>
            <template v-if="semesterNilai.length > 1"><p class="mb-1 mt-3 text-xs font-semibold text-teks2">Rata-rata per semester</p>
              <GrafikDeret :label="labelTren" :seri="gTrenNilai" jenis="garis" :maks="100" judul="Rata-rata nilai akhir per semester" /></template></section>
        </div>

        <!-- Tabel -->
        <div class="mt-4 grid gap-4 xl:grid-cols-2">
          <section class="kartu w-absensi p-4"><h3 class="judul-bagian mb-2">Kehadiran per program</h3>
            <div class="overflow-x-auto"><table class="w-full text-sm"><thead class="text-left text-teks3"><tr><th class="py-1.5">Program</th><th class="py-1.5 text-center">Sesi</th><th class="py-1.5 text-center">H</th><th class="py-1.5 text-center">I</th><th class="py-1.5 text-center">S</th><th class="py-1.5 text-center">B</th><th class="py-1.5 text-center">A</th><th class="py-1.5 text-center">T</th><th class="py-1.5 text-right">%</th></tr></thead>
              <tbody class="divide-y divide-garis"><tr v-for="k in ['kelas', 'halaqah', 'asrama', 'ekskul'].filter((x) => prog[x])" :key="k" :class="ambang.kelas(prog[k].persen)">
                <td class="py-1.5 font-semibold">{{ PROGRAM_REKAM[k] }}</td><td class="py-1.5 text-center tabular-nums">{{ prog[k].sesi }}</td><td class="py-1.5 text-center tabular-nums">{{ prog[k].hadir }}</td><td class="py-1.5 text-center tabular-nums">{{ prog[k].izin }}</td>
                <td class="py-1.5 text-center tabular-nums">{{ prog[k].sakit }}</td><td class="py-1.5 text-center tabular-nums">{{ prog[k].bolos }}</td><td class="py-1.5 text-center tabular-nums">{{ prog[k].absen }}</td><td class="py-1.5 text-center tabular-nums">{{ prog[k].terlambat }}</td>
                <td class="py-1.5 text-right font-bold tabular-nums">{{ fmt(prog[k].persen) }}</td></tr>
                <tr v-if="!Object.keys(prog).length"><td colspan="9" class="py-1.5 text-teks3">Belum ada sesi absensi pada periode ini.</td></tr></tbody></table></div>
            <p class="mt-1 text-xs text-teks3">H hadir (termasuk terlambat dan bolos sesuai ketentuan rapor), I izin, S sakit, B bolos, A absen, T terlambat. Ekskul tidak dihitung dalam kehadiran pokok.</p>
            <p v-if="r.kehadiran.tidak_hadir.length" class="mb-1 mt-3 text-xs font-semibold text-teks2">Tidak hadir dan bolos terakhir</p>
            <ul class="divide-y divide-garis text-sm"><li v-for="(t, i) in r.kehadiran.tidak_hadir.slice(0, 8)" :key="i" class="flex items-center justify-between gap-2 py-1.5">
              <span class="min-w-0">{{ formatPendek(t.tanggal) }} · {{ PROGRAM_REKAM[t.jenis] || t.jenis }} <span class="text-teks3">{{ t.sesi }}{{ t.keterangan ? ' · ' + t.keterangan : '' }}</span></span>
              <span :class="['lencana shrink-0', 'w-' + (KODE[t.kode]?.w || 'hakakses')]">{{ teksKode(t.kode) }}</span></li></ul></section>

          <section class="kartu w-tahfizh p-4"><h3 class="judul-bagian mb-2 flex items-center gap-2"><PhBookOpenText :size="20" weight="duotone" style="color: var(--c)" /> Hafalan</h3>
            <div class="grid grid-cols-3 gap-2 text-center text-sm">
              <div class="rounded-xl bg-permukaan2 p-2"><p class="text-xs text-teks3">Sabaq</p><p class="font-bold">{{ formatPosisi(hf.sabaq_hal) || '0' }}</p></div>
              <div class="rounded-xl bg-permukaan2 p-2"><p class="text-xs text-teks3">Sabqi</p><p class="font-bold">{{ formatPosisi(hf.sabqi_hal) || '0' }}</p></div>
              <div class="rounded-xl bg-permukaan2 p-2"><p class="text-xs text-teks3">Manzil</p><p class="font-bold">{{ formatPosisi(hf.manzil_hal) || '0' }}</p></div></div>
            <p class="mt-2 text-sm text-teks2">Program {{ PROGRAM[hf.program] || hf.program }} · {{ hf.halaqah || 'belum masuk halaqah' }} · setoran {{ hf.setoran?.sesi || 0 }} kali pada periode{{ hf.posisi_pada ? ' · posisi per ' + formatPendek(hf.posisi_pada) : '' }}</p>
            <div v-for="(t, i) in hf.tahsin || []" :key="'ts' + i" class="w-tahsin mt-2 rounded-xl bg-permukaan2 p-2.5 text-sm">
              <p class="flex flex-wrap items-center gap-1.5"><b>Tahsin</b><span :class="['lencana', t.status === 'lulus' ? 'w-presensi' : 'w-tahsin']">{{ t.status === 'lulus' ? 'Lulus tahsin' : 'Berjalan' }}</span></p>
              <p class="text-xs text-teks2">{{ formatPendek(t.mulai) }}{{ t.selesai ? ' – ' + formatPendek(t.selesai) : ' – sekarang' }} · tahap {{ t.tahap }}/{{ t.jumlah_tahap }} ({{ t.tahap_nama }}) · {{ t.pertemuan }} pertemuan, lancar {{ t.lancar }} kali · pembina {{ t.pembina || '–' }}</p></div>
            <p class="mb-1 mt-3 text-xs font-semibold text-teks2">Juz tuntas ({{ juzTuntas }})</p>
            <div class="flex flex-wrap gap-1.5"><span v-for="j in hf.juz" :key="j.juz" class="lencana w-libursantri" :title="(SUMBER_JUZ[j.sumber] || j.sumber) + ' · ' + formatPendek(j.tanggal)">Juz {{ j.juz }}</span>
              <span v-if="!juzTuntas" class="text-sm text-teks3">Belum ada juz yang dinyatakan tuntas.</span></div>
            <table v-if="(hf.bulanan || []).length" class="mt-3 w-full text-sm"><thead class="text-left text-teks3"><tr><th class="py-1.5">Bulan</th><th class="py-1.5 text-center">Baru</th><th class="py-1.5 text-center">Target</th><th class="py-1.5">Capaian</th></tr></thead>
              <tbody class="divide-y divide-garis"><tr v-for="(b, i) in hf.bulanan" :key="i"><td class="py-1.5">{{ labelBulanDari(b.bulan) }}</td><td class="py-1.5 text-center tabular-nums">{{ b.tambah_hal }} hal</td><td class="py-1.5 text-center tabular-nums">{{ b.target_hal ?? '–' }} hal</td>
                <td class="py-1.5"><span :class="['lencana', 'w-' + (STATUS_BULANAN[b.status]?.w || 'hakakses')]">{{ STATUS_BULANAN[b.status]?.n || b.status }}</span><span v-if="!b.disahkan" class="ml-1 text-xs text-teks3">belum disahkan</span></td></tr></tbody></table></section>

          <section class="kartu w-libursantri p-4"><h3 class="judul-bagian mb-2 flex items-center gap-2"><PhSealCheck :size="20" weight="duotone" style="color: var(--c)" /> Ujian tahfizh dan UTAS</h3>
            <ul class="divide-y divide-garis text-sm">
              <li v-for="(u, i) in r.ujian" :key="'u' + i" class="flex items-start justify-between gap-2 py-1.5"><span class="min-w-0"><b>{{ JENIS_UJIAN_TAHFIZH[u.jenis] || u.jenis }} juz {{ (u.juz || []).join(', ') }}</b>
                <span class="block text-xs text-teks3">{{ formatPendek(u.tanggal) }} · tajwid {{ fmt(u.tajwid) }}, itqan {{ fmt(u.itqan) }} · {{ u.penguji || '–' }}</span></span>
                <span class="shrink-0 text-right"><b class="tabular-nums">{{ fmt(u.nilai_akhir) }}</b> <span :class="['lencana', u.hasil === 'remidi' ? 'w-klinik' : 'w-presensi']">{{ u.hasil === 'remidi' ? 'Remidi' : 'Tuntas' }}</span></span></li>
              <li v-for="(u, i) in r.utas" :key="'t' + i" class="flex items-start justify-between gap-2 py-1.5"><span class="min-w-0"><b>UTAS {{ u.ta }} semester {{ u.semester }}</b>
                <span class="block text-xs text-teks3">Juz {{ (u.juz || []).join(', ') }} ({{ u.total_juz }} juz) · {{ u.predikat || u.huruf || '–' }}</span></span>
                <span class="shrink-0 text-right"><b class="tabular-nums">{{ fmt(u.nilai_akhir) }}</b> <span :class="['lencana', u.tuntas ? 'w-presensi' : 'w-klinik']">{{ u.tuntas ? 'Tuntas' : 'Belum tuntas' }}</span></span></li>
              <li v-if="!r.ujian.length && !r.utas.length" class="py-1.5 text-teks3">Belum ada ujian tahfizh yang selesai.</li></ul></section>

          <section class="kartu w-rapor p-4"><h3 class="judul-bagian mb-2 flex items-center gap-2"><PhExam :size="20" weight="duotone" style="color: var(--c)" /> Mata pelajaran dan nilai akhir</h3>
            <div v-if="(r.nilai || []).length" class="bilah-tab kecil mb-2" role="tablist" aria-label="Semester">
              <button v-for="(s, i) in r.nilai" :key="i" type="button" role="tab" :aria-selected="smtPilih === i" :class="['tab-garis', smtPilih === i && 'aktif']" @click="smtPilih = i">{{ labelSmt(s) }}</button></div>
            <template v-if="smt">
              <p class="mb-1 text-xs text-teks3">Kelas {{ smt.kelas }} · {{ smt.status === 'dibuka' ? 'periode penilaian masih dibuka (nilai sementara)' : 'rapor sudah ditutup' }}<span v-if="rataSemester(smt) != null"> · rata-rata {{ fmt(rataSemester(smt)) }}</span></p>
              <table class="w-full text-sm"><thead class="text-left text-teks3"><tr><th class="py-1.5">Mata pelajaran</th><th class="py-1.5 text-center">KKM</th><th class="py-1.5 text-center">Nilai</th><th class="py-1.5 text-center">Predikat</th></tr></thead>
                <tbody class="divide-y divide-garis"><tr v-for="(m, i) in smt.mapel" :key="i"><td class="py-1.5">{{ m.nama }}</td><td class="py-1.5 text-center tabular-nums">{{ fmt(m.kkm) }}</td>
                  <td :class="['py-1.5 text-center font-bold tabular-nums', m.tuntas === false && 'text-merah']">{{ fmt(m.nilai) }}</td><td class="py-1.5 text-center">{{ m.predikat || '–' }}</td></tr></tbody></table>
              <p v-if="smt.pd.length" class="mt-2 text-sm text-teks2">Pengembangan diri: {{ smt.pd.map((p) => `${p.kegiatan} (${p.nilai})`).join(', ') }}</p>
              <p v-if="smt.keputusan" class="mt-1 text-sm font-semibold">Keputusan: {{ KEPUTUSAN_RAPOR[smt.keputusan.keputusan] || smt.keputusan.keputusan }}{{ smt.keputusan.ke_tingkat ? ` ke kelas ${smt.keputusan.ke_tingkat}` : '' }}</p></template>
            <p v-else class="text-sm text-teks3">Belum ada periode penilaian yang dibuka untuk santri ini.</p></section>

          <section class="kartu w-prestasi p-4"><h3 class="judul-bagian mb-2 flex items-center gap-2"><PhMedal :size="20" weight="duotone" style="color: var(--c)" /> Riwayat prestasi</h3>
            <ul class="divide-y divide-garis text-sm"><li v-for="(p, i) in r.prestasi" :key="i" :class="['py-1.5', !p.dalam_periode && 'opacity-75']"><b>{{ p.capaian }}</b> {{ p.kegiatan }}
              <span class="block text-xs text-teks3">{{ formatPendek(p.tanggal) }} · {{ BIDANG_PRESTASI[p.bidang]?.n || p.bidang }} · tingkat {{ TINGKAT_PRESTASI[p.tingkat] || p.tingkat }}{{ p.penyelenggara ? ' · ' + p.penyelenggara : '' }}</span></li>
              <li v-if="!r.prestasi.length" class="py-1.5 text-teks3">Belum ada prestasi tercatat.</li></ul></section>

          <section v-if="r.pelanggaran" class="kartu w-disiplin p-4"><h3 class="judul-bagian mb-1 flex items-center gap-2"><PhGavel :size="20" weight="duotone" style="color: var(--c)" /> Riwayat pelanggaran dan SP</h3>
            <p class="mb-2 text-xs text-teks3">Seluruh riwayat; {{ pelPeriode.length }} pelanggaran terjadi pada periode ini.</p>
            <ul class="space-y-2"><li v-for="(w, i) in r.sp" :key="'w' + i" class="rounded-xl border border-garis p-3 text-sm">
              <p class="flex flex-wrap items-center gap-1.5"><b style="color: var(--c)">SP-{{ w.tingkat }}</b><span>{{ w.nomor || '–' }} · {{ formatPendek(w.tanggal) }}</span>
                <span :class="['lencana', 'w-' + (KEADAAN_SP_SANTRI[w.keadaan]?.w || 'hakakses')]">{{ KEADAAN_SP_SANTRI[w.keadaan]?.n || w.keadaan }}</span></p>
              <p class="mt-1 text-teks2">{{ (w.kategori || []).join(', ') }}</p><p v-if="w.berlaku_sampai" class="text-xs text-teks3">Berlaku sampai {{ formatPendek(w.berlaku_sampai) }}</p></li></ul>
            <ul class="mt-2 divide-y divide-garis text-sm"><li v-for="(v, i) in r.pelanggaran" :key="i" :class="['flex items-start justify-between gap-2 py-1.5', !v.dalam_periode && 'opacity-75']">
              <span class="min-w-0"><b>{{ v.kategori }}</b><span class="block text-xs text-teks3">{{ formatPendek(v.tanggal) }}{{ v.tempat ? ' · ' + v.tempat : '' }} · {{ v.uraian }}{{ v.tindakan ? ' · Tindakan: ' + v.tindakan : '' }}</span></span>
              <span :class="['lencana shrink-0', 'w-' + (TINGKAT_PELANGGARAN[v.tingkat]?.w || 'hakakses')]">{{ TINGKAT_PELANGGARAN[v.tingkat]?.n || v.tingkat }}</span></li>
              <li v-if="!r.pelanggaran.length" class="flex items-center gap-2 py-1.5"><PhCheckCircle :size="18" weight="duotone" class="text-[#1E7D4F]" /> Belum pernah tercatat melakukan pelanggaran.</li></ul></section>

          <section class="kartu w-security p-4"><h3 class="judul-bagian mb-2 flex items-center gap-2"><PhShieldCheck :size="20" weight="duotone" style="color: var(--c)" /> Riwayat security</h3>
            <div class="grid grid-cols-3 gap-2 text-center text-sm">
              <div class="rounded-xl bg-permukaan2 p-2"><p class="text-xs text-teks3">Keluar</p><p class="font-bold tabular-nums">{{ r.security.keluar }}</p></div>
              <div class="rounded-xl bg-permukaan2 p-2"><p class="text-xs text-teks3">Terlambat kembali</p><p :class="['font-bold tabular-nums', r.security.terlambat && 'text-merah']">{{ r.security.terlambat }}</p></div>
              <div class="rounded-xl bg-permukaan2 p-2"><p class="text-xs text-teks3">Ditolak keluar</p><p class="font-bold tabular-nums">{{ r.security.ditolak }}</p></div>
              <div class="rounded-xl bg-permukaan2 p-2"><p class="text-xs text-teks3">Kembali</p><p class="font-bold tabular-nums">{{ r.security.kembali }}</p></div>
              <div class="rounded-xl bg-permukaan2 p-2"><p class="text-xs text-teks3">Kunjungan</p><p class="font-bold tabular-nums">{{ r.security.kunjungan }}</p></div>
              <div class="rounded-xl bg-permukaan2 p-2"><p class="text-xs text-teks3">Titipan</p><p class="font-bold tabular-nums">{{ r.security.titipan }}</p></div></div>
            <ul class="mt-2 divide-y divide-garis text-sm"><li v-for="(g, i) in r.security.gerbang.slice(0, 8)" :key="i" class="flex justify-between gap-2 py-1.5">
              <span>{{ formatWaktu(g.waktu) }} · {{ JENIS_GERBANG[g.jenis] || g.jenis }}{{ g.penjemput ? ' · ' + g.penjemput : '' }}</span><span v-if="g.terlambat_menit" class="text-xs font-semibold text-merah">terlambat {{ g.terlambat_menit }} menit</span></li>
              <li v-for="(v, i) in r.security.kunjungan_daftar.slice(0, 4)" :key="'v' + i" class="py-1.5">{{ formatWaktu(v.datang_pada) }} · Kunjungan {{ v.pengunjung }} ({{ HUBUNGAN[v.hubungan] || v.hubungan }})</li></ul></section>

          <section class="kartu w-klinik p-4"><h3 class="judul-bagian mb-1 flex items-center gap-2"><PhFirstAidKit :size="20" weight="duotone" style="color: var(--c)" /> Riwayat klinik (ringkas)</h3>
            <p class="mb-2 text-xs text-teks3">{{ r.klinik.kasus }} kunjungan · {{ r.klinik.istirahat }} istirahat/rawat · {{ r.klinik.rujuk }} dirujuk · {{ r.klinik.pulang }} dipulangkan. Diagnosis dan rincian pemeriksaan tidak ditampilkan.</p>
            <ul class="divide-y divide-garis text-sm"><li v-for="(c, i) in r.klinik.daftar.slice(0, 8)" :key="i" class="flex items-start justify-between gap-2 py-1.5">
              <span class="min-w-0">{{ formatPendek(c.tanggal) }} · {{ c.keluhan }}</span><span class="shrink-0 text-xs text-teks3">{{ TINDAK_LANJUT[c.tindak_lanjut]?.n || (c.status === 'selesai' ? 'Selesai' : 'Ditangani') }}</span></li>
              <li v-if="!r.klinik.daftar.length" class="py-1.5 text-teks3">Tidak ada kunjungan klinik pada periode ini.</li></ul></section>

          <section class="kartu w-libursantri p-4"><h3 class="judul-bagian mb-2 flex items-center gap-2"><PhSignOut :size="20" weight="duotone" style="color: var(--c)" /> Perizinan dan libur</h3>
            <ul class="divide-y divide-garis text-sm"><li v-for="(z, i) in r.izin" :key="i" class="flex items-start justify-between gap-2 py-1.5">
              <span class="min-w-0"><b>{{ JENIS_IZIN[z.jenis] || z.jenis }}</b> · {{ z.alasan }}<span class="block text-xs text-teks3">{{ formatWaktu(z.keluar_pada) }} s.d. {{ formatWaktu(z.kembali_batas) }}{{ z.kembali_pada ? ' · kembali ' + formatWaktu(z.kembali_pada) : '' }}</span></span>
              <span :class="['lencana shrink-0', z.terlambat ? 'w-klinik' : 'w-' + (STATUS_IZIN[z.status]?.w || 'hakakses')]">{{ z.terlambat ? 'Terlambat' : STATUS_IZIN[z.status]?.p || z.status }}</span></li>
              <li v-for="(l, i) in r.libur" :key="'l' + i" class="flex items-start justify-between gap-2 py-1.5"><span class="min-w-0"><b>{{ l.periode }}</b><span class="block text-xs text-teks3">Pulang {{ formatPendek(l.pulang_pada) }}{{ l.alasan_ubah ? ' · ' + l.alasan_ubah : '' }}</span></span>
                <span :class="['lencana shrink-0', 'w-' + (HASIL_LIBUR[l.keputusan]?.w || 'hakakses')]">{{ HASIL_LIBUR[l.keputusan]?.n || l.keputusan }}</span></li>
              <li v-if="!r.izin.length && !r.libur.length" class="py-1.5 text-teks3">Tidak ada izin keluar/pulang atau libur pada periode ini.</li></ul></section>

          <section v-if="keu" class="kartu w-keuangan p-4"><h3 class="judul-bagian mb-1 flex items-center gap-2"><PhWallet :size="20" weight="duotone" style="color: var(--c)" /> Pembayaran</h3>
            <p class="mb-2 text-xs text-teks3">Data bersifat rahasia. Sisa tagihan {{ rupiah(keu.ringkas.sisa) }}, tunggakan jatuh tempo {{ rupiah(keu.ringkas.tunggakan) }}.</p>
            <table class="w-full text-sm"><thead class="text-left text-teks3"><tr><th class="py-1.5">Tagihan</th><th class="py-1.5 text-right">Nominal</th><th class="py-1.5 text-right">Dibayar</th></tr></thead>
              <tbody class="divide-y divide-garis"><tr v-for="(b, i) in keu.tagihan.slice(0, 10)" :key="i" :class="b.lewat && 'text-merah'"><td class="py-1.5">{{ b.nama }}<span class="block text-xs text-teks3">jatuh tempo {{ formatPendek(b.jatuh_tempo) }}</span></td>
                <td class="py-1.5 text-right tabular-nums">{{ angka(b.nominal) }}</td><td class="py-1.5 text-right font-semibold tabular-nums">{{ angka(b.dibayar) }}</td></tr></tbody></table>
            <p class="mt-2 text-sm text-teks2">Pembayaran pada periode: {{ keu.pembayaran.length }} kali, jumlah {{ rupiah(keu.pembayaran.reduce((a, y) => a + Number(y.jumlah), 0)) }}.</p></section>

          <section class="kartu w-hakakses p-4"><h3 class="judul-bagian mb-2 flex items-center gap-2"><PhClockCounterClockwise :size="20" weight="duotone" style="color: var(--c)" /> Riwayat status dan kenaikan</h3>
            <ul class="divide-y divide-garis text-sm"><li v-for="(h, i) in r.riwayat.slice(0, 10)" :key="i" class="py-1.5"><b>{{ JENIS_RIWAYAT_SANTRI[h.jenis] || h.jenis }}</b>: {{ teksRiwayat(h) }}
              <span class="block text-xs text-teks3">{{ h.tanggal ? formatPendek(h.tanggal) : '–' }}{{ h.alasan ? ' · ' + h.alasan : '' }}</span></li>
              <li v-if="!r.riwayat.length" class="py-1.5 text-teks3">Belum ada riwayat tercatat.</li></ul></section>
        </div>
      </template>
    </div>

    <!-- Cetak F4 -->
    <DokumenCetak jenis="rekam_santri" v-if="r" v-model:pratinjau="pratinjau" judul="Rekam Kesantrian" :subjudul="subjudul" :pencetak="sesi.pengguna?.nama_lengkap"
      :nama-berkas="namaBerkas(P.nama, 'Rekam Kesantrian', periodeRentang(mulai, selesai))">
      <div class="rekam-cetak">
        <table class="meta-dok"><tbody>
          <tr><td style="width: 18%">Nama</td><td style="width: 34%">: {{ P.nama }}</td><td style="width: 18%">Jenjang/kelas</td><td>: {{ JENJANG[P.jenjang] || '–' }}, {{ rombel }}</td></tr>
          <tr><td>NIS/NISN</td><td>: {{ P.nis || '–' }} / {{ P.nisn || '–' }}</td><td>Kamar/halaqah</td><td>: {{ kelompokJenis('kamar').map((k) => k.nama).join(', ') || '–' }} / {{ kelompokJenis('halaqah').map((k) => k.nama).join(', ') || '–' }}</td></tr>
          <tr><td>JK</td><td>: {{ P.jenis_kelamin === 'P' ? 'Perempuan' : 'Laki-laki' }}</td><td>Status</td><td>: {{ STATUS_SANTRI[P.status]?.n || P.status }}</td></tr>
          <tr><td>Tempat, tgl lahir</td><td>: {{ ttl }}</td><td>Orang tua/wali</td><td>: {{ P.kontak ? `${P.kontak.nama} (${HUBUNGAN[P.kontak.hubungan] || P.kontak.hubungan})` : '–' }}</td></tr>
        </tbody></table>
        <p class="sub">{{ huruf.identitas }}. Ringkasan dan temuan</p>
        <table class="tabel"><colgroup><col style="width:25%"><col style="width:25%"><col style="width:25%"><col style="width:25%"></colgroup>
          <tbody>
            <tr><td>Kehadiran pokok: <b>{{ fmt(hp.persen) }}%</b> ({{ hp.sesi }} sesi)</td><td>Hafalan: {{ formatPosisi(hf.sabaq_hal, true) || '0' }}</td><td>Juz tuntas: {{ juzTuntas }}</td><td>Rata-rata nilai: {{ nTerakhir ? fmt(nTerakhir.rata) : '–' }}</td></tr>
            <tr><td>Prestasi: {{ r.prestasi.length }} ({{ prestasiPeriode.length }} periode ini)</td><td>{{ r.pelanggaran ? `Pelanggaran periode: ${pelPeriode.length}` : `Izin keluar/pulang: ${r.izin.length}` }}</td><td>Klinik: {{ r.klinik.kasus }} kunjungan</td><td>{{ keu ? `Tunggakan: ${rupiah(keu.ringkas.tunggakan)}` : `Terlambat kembali: ${izinLambat}` }}</td></tr>
          </tbody></table>
        <ol class="temuan"><li v-for="(t, i) in catatan" :key="i">{{ t.teks }}</li></ol>
        <p class="ket">Kelompok berjalan: {{ r.kelompok.map((k) => `${JENIS_KELOMPOK_REKAM[k.jenis]} ${k.nama} (${PENGASUH_KELOMPOK[k.jenis].toLowerCase()} ${k.pengasuh || '–'})`).join('; ') || '–' }}.</p>

        <p class="sub">{{ huruf.kehadiran }}. Kehadiran</p>
        <table class="tabel"><colgroup><col style="width:16%"><col style="width:10%"><col style="width:10%"><col style="width:10%"><col style="width:10%"><col style="width:10%"><col style="width:10%"><col style="width:12%"><col style="width:12%"></colgroup>
          <thead><tr><th>Program/bulan</th><th>Sesi</th><th>Hadir</th><th>Izin</th><th>Sakit</th><th>Bolos</th><th>Absen</th><th>Terlambat</th><th>% hadir</th></tr></thead>
          <tbody><tr v-for="k in ['kelas', 'halaqah', 'asrama', 'ekskul'].filter((x) => prog[x])" :key="k" :class="ambang.kelasCetak(prog[k].persen)"><td>{{ PROGRAM_REKAM[k] }}</td><td class="tengah">{{ prog[k].sesi }}</td><td class="tengah">{{ prog[k].hadir }}</td><td class="tengah">{{ prog[k].izin }}</td>
            <td class="tengah">{{ prog[k].sakit }}</td><td class="tengah">{{ prog[k].bolos }}</td><td class="tengah">{{ prog[k].absen }}</td><td class="tengah">{{ prog[k].terlambat }}</td><td class="tengah">{{ fmt(prog[k].persen) }}</td></tr>
            <tr v-for="(b, i) in kb" :key="b.bulan" :class="ambang.kelasCetak(b.persen)"><td>{{ labelBulan[i] }}</td><td class="tengah">{{ b.sesi }}</td><td class="tengah">{{ b.hadir }}</td><td class="tengah">{{ b.izin }}</td>
              <td class="tengah">{{ b.sakit }}</td><td class="tengah">{{ b.bolos }}</td><td class="tengah">{{ b.absen }}</td><td class="tengah">{{ b.terlambat }}</td><td class="tengah">{{ fmt(b.persen) }}</td></tr></tbody></table>
        <div class="grafik-dua">
          <GrafikDeret :label="labelBulan" :seri="gKehadiran" jenis="garis" satuan="%" :maks="100" judul="Persentase kehadiran per bulan" />
          <GrafikDeret :label="sb.map((b) => labelBulanDari(b.bulan))" :seri="gHafalan" jenis="batang" satuan="hal" judul="Hafalan baru dan target bulanan" />
        </div>

        <p class="sub">{{ huruf.hafalan }}. Hafalan dan ujian tahfizh</p>
        <p class="ket">Program {{ PROGRAM[hf.program] || hf.program }}, {{ hf.halaqah || '–' }}. Posisi sabaq {{ formatPosisi(hf.sabaq_hal, true) || '0' }}, sabqi {{ formatPosisi(hf.sabqi_hal, true) || '0' }}, manzil {{ formatPosisi(hf.manzil_hal, true) || '0' }}.
          Juz tuntas: {{ (hf.juz || []).map((j) => j.juz).join(', ') || 'belum ada' }}. Setoran pada periode {{ hf.setoran?.sesi || 0 }} kali, hafalan baru {{ formatPosisi(hf.setoran?.tambah_hal, true) || '0' }}.
          <template v-for="(t, i) in hf.tahsin || []" :key="'tc' + i"> Tahsin {{ formatPendek(t.mulai) }}{{ t.selesai ? '–' + formatPendek(t.selesai) : '–sekarang' }}: {{ t.status === 'lulus' ? 'lulus' : 'berjalan' }}, tahap {{ t.tahap }}/{{ t.jumlah_tahap }}, {{ t.pertemuan }} pertemuan.</template></p>
        <table class="tabel"><colgroup><col style="width:6%"><col style="width:30%"><col style="width:14%"><col style="width:10%"><col style="width:10%"><col style="width:12%"><col style="width:18%"></colgroup>
          <thead><tr><th>No.</th><th>Ujian</th><th>Tanggal</th><th>Tajwid</th><th>Itqan</th><th>Nilai akhir</th><th>Hasil</th></tr></thead>
          <tbody><tr v-for="(u, i) in r.ujian" :key="'u' + i"><td class="tengah">{{ i + 1 }}</td><td>{{ JENIS_UJIAN_TAHFIZH[u.jenis] || u.jenis }} juz {{ (u.juz || []).join(', ') }}</td><td class="tengah">{{ formatPendek(u.tanggal) }}</td>
            <td class="tengah">{{ fmt(u.tajwid) }}</td><td class="tengah">{{ fmt(u.itqan) }}</td><td class="tengah">{{ fmt(u.nilai_akhir) }}</td><td>{{ u.hasil === 'remidi' ? 'Remidi' : 'Tuntas' }}{{ u.predikat ? ' (' + u.predikat + ')' : '' }}</td></tr>
            <tr v-for="(u, i) in r.utas" :key="'t' + i"><td class="tengah">{{ r.ujian.length + i + 1 }}</td><td>UTAS {{ u.ta }} smt {{ u.semester }}, juz {{ (u.juz || []).join(', ') }}</td><td class="tengah">{{ formatPendek(u.tanggal) }}</td>
              <td class="tengah">{{ fmt(u.tajwid) }}</td><td class="tengah">{{ fmt(u.itqan) }}</td><td class="tengah">{{ fmt(u.nilai_akhir) }}</td><td>{{ u.tuntas ? 'Tuntas' : 'Belum tuntas' }}{{ u.predikat ? ' (' + u.predikat + ')' : '' }}</td></tr>
            <tr v-if="!r.ujian.length && !r.utas.length"><td colspan="7" class="tengah">Belum ada ujian tahfizh yang selesai</td></tr></tbody></table>

        <p class="sub">{{ huruf.nilai }}. Mata pelajaran dan nilai akhir</p>
        <template v-for="(s, j) in r.nilai" :key="j">
          <p class="ket"><b>{{ s.ta }} semester {{ s.semester }}, kelas {{ s.kelas }}</b>{{ s.status === 'dibuka' ? ' (nilai sementara)' : '' }}{{ rataSemester(s) != null ? ` · rata-rata ${fmt(rataSemester(s))}` : '' }}{{ s.keputusan ? ` · ${KEPUTUSAN_RAPOR[s.keputusan.keputusan] || s.keputusan.keputusan}` : '' }}</p>
          <table class="tabel"><colgroup><col style="width:6%"><col style="width:52%"><col style="width:14%"><col style="width:14%"><col style="width:14%"></colgroup>
            <thead><tr><th>No.</th><th>Mata pelajaran</th><th>KKM</th><th>Nilai akhir</th><th>Predikat</th></tr></thead>
            <tbody><tr v-for="(m, i) in s.mapel" :key="i"><td class="tengah">{{ i + 1 }}</td><td>{{ m.nama }}</td><td class="tengah">{{ fmt(m.kkm) }}</td><td class="tengah">{{ fmt(m.nilai) }}</td><td class="tengah">{{ m.predikat || '–' }}</td></tr></tbody></table>
        </template>
        <p v-if="!r.nilai.length" class="ket">Belum ada periode penilaian yang dibuka untuk santri ini.</p>

        <p class="sub">{{ huruf.prestasi }}. Riwayat prestasi</p>
        <table class="tabel"><colgroup><col style="width:6%"><col style="width:14%"><col style="width:40%"><col style="width:16%"><col style="width:24%"></colgroup>
          <thead><tr><th>No.</th><th>Tanggal</th><th>Kegiatan</th><th>Capaian</th><th>Tingkat</th></tr></thead>
          <tbody><tr v-for="(p, i) in r.prestasi" :key="i"><td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ formatPendek(p.tanggal) }}</td><td>{{ p.kegiatan }}</td><td>{{ p.capaian }}</td><td>{{ TINGKAT_PRESTASI[p.tingkat] || p.tingkat }}</td></tr>
            <tr v-if="!r.prestasi.length"><td colspan="5" class="tengah">Belum ada prestasi tercatat</td></tr></tbody></table>

        <template v-if="r.pelanggaran">
          <p class="sub">{{ huruf.disiplin }}. Riwayat pelanggaran dan surat peringatan</p>
          <table class="tabel"><colgroup><col style="width:6%"><col style="width:14%"><col style="width:24%"><col style="width:12%"><col style="width:44%"></colgroup>
            <thead><tr><th>No.</th><th>Tanggal</th><th>Kategori</th><th>Tingkat</th><th>Uraian dan tindakan</th></tr></thead>
            <tbody><tr v-for="(v, i) in r.pelanggaran" :key="i"><td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ formatPendek(v.tanggal) }}</td><td>{{ v.kategori }}</td><td>{{ TINGKAT_PELANGGARAN[v.tingkat]?.n || v.tingkat }}</td><td>{{ v.uraian }}{{ v.tindakan ? '; ' + v.tindakan : '' }}</td></tr>
              <tr v-if="!r.pelanggaran.length"><td colspan="5" class="tengah">Belum pernah tercatat melakukan pelanggaran</td></tr></tbody></table>
          <p v-if="r.sp.length" class="ket">Surat peringatan: {{ r.sp.map((w) => `SP-${w.tingkat} ${w.nomor || ''} (${formatPendek(w.tanggal)}, ${KEADAAN_SP_SANTRI[w.keadaan]?.n || w.keadaan})`).join('; ') }}.</p>
        </template>

        <p class="sub">{{ huruf.security }}. Riwayat security</p>
        <p class="ket">Keluar {{ r.security.keluar }} kali, kembali {{ r.security.kembali }} kali ({{ r.security.terlambat }} terlambat), ditolak keluar {{ r.security.ditolak }} kali, kunjungan orang tua {{ r.security.kunjungan }} kali, titipan {{ r.security.titipan }} kali pada periode ini.</p>

        <p class="sub">{{ huruf.klinik }}. Riwayat klinik (ringkas)</p>
        <p class="ket">{{ r.klinik.kasus }} kunjungan klinik ({{ r.klinik.istirahat }} istirahat/rawat, {{ r.klinik.rujuk }} dirujuk, {{ r.klinik.pulang }} dipulangkan){{ r.klinik.daftar.length ? ': ' + r.klinik.daftar.map((c) => `${formatPendek(c.tanggal)} ${c.keluhan}`).join('; ') : '' }}.</p>

        <p class="sub">{{ huruf.izin }}. Perizinan dan libur</p>
        <table class="tabel"><colgroup><col style="width:6%"><col style="width:22%"><col style="width:30%"><col style="width:26%"><col style="width:16%"></colgroup>
          <thead><tr><th>No.</th><th>Jenis</th><th>Alasan/periode</th><th>Waktu</th><th>Keterangan</th></tr></thead>
          <tbody><tr v-for="(z, i) in r.izin" :key="i"><td class="tengah">{{ i + 1 }}</td><td>{{ JENIS_IZIN[z.jenis] || z.jenis }}</td><td>{{ z.alasan }}</td><td>{{ formatWaktu(z.keluar_pada) }} s.d. {{ formatWaktu(z.kembali_batas) }}</td><td>{{ z.terlambat ? 'Terlambat kembali' : STATUS_IZIN[z.status]?.p || z.status }}</td></tr>
            <tr v-for="(l, i) in r.libur" :key="'l' + i"><td class="tengah">{{ r.izin.length + i + 1 }}</td><td>Libur</td><td>{{ l.periode }}</td><td>{{ formatPendek(l.pulang_pada) }}</td><td>{{ HASIL_LIBUR[l.keputusan]?.n || l.keputusan }}</td></tr>
            <tr v-if="!r.izin.length && !r.libur.length"><td colspan="5" class="tengah">Tidak ada izin atau libur pada periode ini</td></tr></tbody></table>

        <template v-if="keu">
          <p class="sub">{{ huruf.keuangan }}. Pembayaran (rahasia)</p>
          <table class="tabel"><colgroup><col style="width:6%"><col style="width:40%"><col style="width:16%"><col style="width:19%"><col style="width:19%"></colgroup>
            <thead><tr><th>No.</th><th>Tagihan</th><th>Jatuh tempo</th><th>Nominal (Rp)</th><th>Dibayar (Rp)</th></tr></thead>
            <tbody><tr v-for="(b, i) in keu.tagihan" :key="i"><td class="tengah">{{ i + 1 }}</td><td>{{ b.nama }}</td><td class="tengah">{{ formatPendek(b.jatuh_tempo) }}</td><td class="kanan">{{ angka(b.nominal) }}</td><td class="kanan">{{ angka(b.dibayar) }}</td></tr>
              <tr><th colspan="3">Sisa tagihan / tunggakan jatuh tempo</th><th class="kanan">{{ angka(keu.ringkas.sisa) }}</th><th class="kanan">{{ angka(keu.ringkas.tunggakan) }}</th></tr></tbody></table>
        </template>

        <p class="sub">{{ huruf.riwayat }}. Riwayat kelompok dan status</p>
        <p class="ket">{{ kelompokTahun.map(([th, isi]) => `${th}: ${isi.map((k) => `${JENIS_KELOMPOK_REKAM[k.jenis]} ${k.nama}`).join(', ')}`).join('. ') || '–' }}.
          {{ r.riwayat.map((h) => `${formatPendek(h.tanggal)} ${JENIS_RIWAYAT_SANTRI[h.jenis] || h.jenis}: ${teksRiwayat(h)}`).join('; ') }}.</p>
        <p class="ket">Dokumen ini bersifat terbatas dan disusun otomatis dari data absensi, tahfizh, penilaian, kedisiplinan, security, klinik, dan perizinan pada SIMKA PRO.</p>
      </div>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: kesantrian.jabatan || 'Kepala Bidang Kesantrian', nama: kesantrian.nama || '', niy: kesantrian.niy }"
          :kanan="{ jabatan: 'Wali Kelas,', nama: kelas?.utama?.nama || '', niy: kelas?.utama?.niy }" />
      </template>
    </DokumenCetak>
  </div>
</template>
<style scoped>
.kepala { background: linear-gradient(135deg, #0B7F81 0%, #0F6E82 50%, #2F5FA8 100%); color: #fff; }
.kepala-tombol { background: rgba(255, 255, 255, 0.14); color: #fff; border-color: rgba(255, 255, 255, 0.45); }
</style>
<style>
.rekam-cetak { font-size: 9.5pt; }
.rekam-cetak .sub { font-weight: 700; margin: 8pt 0 3pt; }
.rekam-cetak table.tabel { font-size: 9pt; }
.rekam-cetak .meta-dok td { padding: 1pt 4pt 1pt 0; vertical-align: top; }
.rekam-cetak .temuan { margin: 4pt 0 0 14pt; padding: 0; list-style: decimal; }
.rekam-cetak .ket { font-size: 9pt; margin-top: 4pt; text-align: justify; }
.rekam-cetak .grafik-dua { display: grid; grid-template-columns: 1fr 1fr; gap: 4mm; margin-top: 6pt; break-inside: avoid; }
</style>
