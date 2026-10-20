// SIMKA PRO | src/lib/slidePantauan.js | v1.6 | 14.18.0: slide Kinerja Bidang (enam indikator sama untuk setiap bidang) | 21/10/2026
// Penyusun slide Layar Pantauan dari muatan pantauan_langsung(): setiap slide berisi kartu statistik (dengan daftar
// nama untuk detail admin/superadmin) dan grafik (batang/lingkaran). Saringan: jenis kelamin, jenjang, bidang.
// Urutan slide: lihat URUT di akhir susunSlide (Pondok di depan).
// v1.2: Santri + hadir di halaqah; Pegawai + sementara bertugas, cepat pulang, sudah pulang (menggantikan tidak terjadwal);
//       SMP/SMA + jam pelajaran terlaksana; Tahfizh + ujian hari itu; slide Perizinan dan Laporan dan Agenda; hari lalu → teks "hari itu".
// v1.3: setiap slide 10 kartu; data santri/pegawai selalu disertai persentase di keterangan; Santri + asrama pagi;
//       SMP/SMA/Tahfizh/Asrama + jumlah kelas/halaqah/kamar (daftar = rekap: pengasuh, santri L/P, dapat dicetak);
//       Asrama + santri di luar pondok, musyrif hadir pagi dan hadir malam (kehadiran per sesi kerja).
// v1.4: tujuh slide baru @10 kartu — Pondok (ringkasan umum, slide pertama), Wali Kelas, Guru Mapel, Dokumen, Persuratan,
//       Keuangan (hanya pemegang hak lihat keuangan), Administrasi Pegawai. Urutan: Pondok, Santri, Pegawai, SMP, SMA,
//       Wali Kelas, Guru Mapel, Tahfizh, Hafalan, Asrama, Kegiatan Santri, Medis, Security, Ekskul, Perizinan, Laporan
//       dan Agenda, Dokumen, Persuratan, Keuangan, Administrasi Pegawai.
// v1.5: empat slide pindahan dari slider beranda (masing-masing 10 kartu): Presensi Sesi (statistik_presensi), Santri Sesi
//       (statistik_santri + sesi absensi), Ringkasan Tahfizh (ringkasan_tahfizh_beranda), Administrasi (ringkasan_beranda.kelola).
//       Hanya hari berjalan; sumber data dikirim Pantauan.vue lewat parameter x.
// v1.6: slide Kinerja Bidang (x.kinerja = olah(kinerja_bidang()), bulan berjalan s.d. kemarin): kartu skor pondok, skor tiap
//       bidang (daftar = pegawai × enam indikator + catatan), kelompok santri; grafik skor mendatar dan peta warna indikator.
//       Kartu dan baris grafik dapat diketuk untuk rincian siap cetak.
import {
  PhStudent, PhChalkboardTeacher, PhBookOpenText, PhBed, PhFirstAidKit, PhSignOut, PhSiren, PhUserCheck, PhClock, PhAirplaneTilt, PhUserMinus,
  PhHourglass, PhMoon, PhCalendarCheck, PhSignIn, PhProhibit, PhPackage, PhHandArrowDown, PhIdentificationBadge, PhUsersThree, PhGraduationCap,
  PhBooks, PhMedal, PhTrophy, PhTrendUp, PhWarningCircle, PhStethoscope, PhAmbulance, PhHeartbeat, PhShieldCheck, PhPersonSimpleRun, PhUsers, PhHouseLine,
  PhBriefcase, PhHouse, PhTimer, PhEnvelopeSimpleOpen, PhCalendarStar, PhMegaphone, PhExam, PhNotebook,
  PhSun, PhUsersFour, PhCheckCircle, PhXCircle, PhPlayCircle, PhListChecks, PhPercent, PhUserList, PhBookBookmark, PhCalendarX, PhFlag, PhDoorOpen, PhQuestion,
  PhChalkboard, PhPresentationChart, PhNotePencil, PhChartLine, PhFileText, PhSealCheck, PhFiles, PhSignature, PhFolderOpen, PhEnvelopeSimple, PhTray,
  PhTarget, PhArrowsLeftRight, PhPaperPlaneTilt, PhCashRegister, PhCoins, PhReceipt, PhInvoice, PhIdentificationCard, PhClockCounterClockwise, PhUserGear, PhCake,
} from '@phosphor-icons/vue'
import { formatJam, formatWaktu } from './tanggal'
import { JENIS_TITIPAN, PENGAMBIL } from './security'
import { INDIKATOR, persenTeks, skorTeks } from './kinerja'

const W = { hijau: '#1E7D4F', merah: '#C7332F', biru: '#2F5FA8', jingga: '#C26A12', ungu: '#7B3FA0', teal: '#127A7A', abu: '#7A8590', emas: '#A6791A' }
const KODE = { H: 'Hadir', T: 'Terlambat', I: 'Izin', S: 'Sakit', A: 'Absen', B: 'Bolos' }
const hadirKode = (k) => ['H', 'T'].includes(k)
const persen = (a, b) => (b ? Math.round((100 * a) / b) : 0)
const pr = (a, b) => `${persen(a, b)}%`
/** Keterangan jumlah putra/putri beserta persentasenya. */
const ketLP = (x, jk = 'jk') => { const l = x.filter((y) => y[jk] === 'L').length; const p = x.filter((y) => y[jk] === 'P').length; return `${l} putra (${pr(l, x.length)}) · ${p} putri (${pr(p, x.length)})` }
const K_SANTRI = [['nis', 'NIS', 10], ['nama', 'Nama santri', 26], ['kelas', 'Kelas', 8], ['kamar', 'Kamar', 16]]
const K_PEG = [['nama', 'Nama pegawai', 28], ['jabatan', 'Jabatan', 24], ['bidang', 'Bidang', 18], ['ket', 'Keterangan', 22]]
const rapiS = (s, tambah = {}) => ({ ...s, kelas: s.kelas || '–', kamar: s.kamar || '–', halaqah: s.halaqah || '–', ...tambah })
const rapiP = (p, tambah = {}) => ({ ...p, jabatan: p.jabatan || '–', bidang: p.bidang || '–', ket: p.ket || STATUS_PEG[p.status] || '–', ...tambah })
const STATUS_PEG = { hadir: 'Hadir', terlambat: 'Terlambat', dinas_luar: 'Dinas luar', izin: 'Izin', sakit: 'Sakit', cuti: 'Cuti', belum: 'Belum presensi',
  menunggu_verval: 'Menunggu verval', tanpa_keterangan: 'Tanpa keterangan', akan_datang: 'Sesi belum dibuka', libur: 'Tidak terjadwal' }
const STATUS_JP = { terlaksana: 'Terlaksana', tidak_terlaksana: 'Tidak terlaksana', belum_diisi: 'Lewat, jurnal belum diisi', berlangsung: 'Berlangsung', akan_datang: 'Belum dimulai' }
const daftarJp = (judul, x) => ({ judul, kolom: [['jam', 'Jam', 8], ['kelas', 'Kelas', 8], ['jp', 'Jam ke', 10], ['mapel', 'Mapel', 20], ['guru', 'Guru', 24], ['status', 'Status', 18]],
  baris: [...x].sort((a, b) => (a.jam_mulai || '').localeCompare(b.jam_mulai || '') || (a.kelas || '').localeCompare(b.kelas || '', 'id', { numeric: true })).map((p) => ({ ...p, jam: (p.jam_mulai || '').slice(0, 5), status: STATUS_JP[p.status] || p.status })) })
const STATUS_SESI = { terisi: 'Terlaksana', terbuka: 'Berlangsung', belum_buka: 'Belum dimulai', tidak_terisi: 'Lewat, belum diisi', lewat: 'Lewat batas' }
const kartu = (j, v, i, w, ket, daftar) => ({ j, v, i, w, ket, daftar })
const daftarS = (judul, baris, kolomTambah = []) => ({ judul, kolom: [...K_SANTRI, ...kolomTambah], baris })
const daftarP = (judul, baris) => ({ judul, kolom: K_PEG, baris })

/** Kunci sesi halaqah/asrama santri (mis. 'halaqah:subuh') beserta nama dan kehadiran. */
function sesiSantri(santri, awalan) {
  const kunci = [...new Set(santri.flatMap((s) => Object.keys(s.sesi || {}).filter((k) => k.startsWith(awalan))))]
  return kunci.map((k) => { const ada = santri.filter((s) => s.sesi?.[k]); return { k, n: ada[0]?.sesi[k].n || k.split(':')[1], ada, hadir: ada.filter((s) => hadirKode(s.sesi[k].k)) } })
}
const kartuSesiSantri = (h, ikon, w, judulTidak) => kartu(h.n, `${h.hadir.length}/${h.ada.length}`, ikon, w, `${h.ada.length - h.hadir.length} ${judulTidak}`,
  daftarS(`${h.n}: santri tidak hadir`, h.ada.filter((x) => !hadirKode(x.sesi[h.k].k)).map((x) => rapiS(x, { ket: KODE[x.sesi[h.k].k] })), [['ket', 'Status', 10]]))
const kelasSantri = (s) => {
  const kelas = s.filter((x) => x.kelas_sesi > 0); const tidak = kelas.filter((x) => x.kelas_tidak > 0); const penuh = kelas.filter((x) => x.kelas_tidak >= x.kelas_sesi)
  return { kelas, tidak, hadir: kelas.length - penuh.length }
}
const sesiKegiatan = (sesi, jenis) => { const s = sesi.filter((x) => x.jenis === jenis); return { s, ok: s.filter((x) => x.status === 'terisi'), telat: s.filter((x) => x.status === 'tidak_terisi') } }
const daftarSesi = (judul, s) => ({ judul, kolom: [['jam', 'Jam', 7], ['kelompok', 'Kelompok', 16], ['sesi', 'Sesi', 16], ['pengampu', 'Pengampu', 24], ['status', 'Status', 14], ['hadir', 'Hadir', 9]],
  baris: [...s].sort((a, b) => (a.jam_mulai || '').localeCompare(b.jam_mulai || '')).map((x) => ({ ...x, jam: (x.jam_mulai || '').slice(0, 5), pengampu: x.pengampu || '–',
    status: STATUS_SESI[x.status] || x.status, hadir: x.status === 'terisi' ? `${x.hadir ?? 0}/${x.anggota ?? 0}` : '–' })) })
const grafikStatusSesi = (judul, s) => ({ tipe: 'lingkaran', judul, satuan: 'sesi', data: [
  { n: 'Terlaksana', nilai: s.filter((x) => x.status === 'terisi').length, warna: W.hijau }, { n: 'Berlangsung', nilai: s.filter((x) => x.status === 'terbuka').length, warna: W.biru },
  { n: 'Belum dimulai', nilai: s.filter((x) => x.status === 'belum_buka').length, warna: W.abu }, { n: 'Lewat, belum diisi', nilai: s.filter((x) => ['tidak_terisi', 'lewat'].includes(x.status)).length, warna: W.merah }] })
const grafikPerKelompok = (judul, baris, sumbuY = 'Jumlah santri') => ({ tipe: 'batang', judul, sumbuY, label: baris.map((b) => b.n),
  seri: [{ n: 'Hadir', warna: W.hijau, nilai: baris.map((b) => b.h) }, { n: 'Tidak hadir', warna: W.merah, nilai: baris.map((b) => b.t) }] })

/** Santri dengan sesi halaqah hari ini: hadir = hadir minimal satu sesi; tidak = tidak hadir minimal satu sesi. */
function halaqahSantri(santri) {
  const ada = santri.filter((s) => Object.keys(s.sesi || {}).some((k) => k.startsWith('halaqah:')))
  const kode = (s) => Object.entries(s.sesi).filter(([k]) => k.startsWith('halaqah:')).map(([, v]) => v)
  return { ada, hadir: ada.filter((s) => kode(s).some((v) => hadirKode(v.k))), tidak: ada.filter((s) => kode(s).some((v) => !hadirKode(v.k))) }
}
const ketHalaqah = (x) => Object.entries(x.sesi || {}).filter(([k, v]) => k.startsWith('halaqah:') && !hadirKode(v.k)).map(([, v]) => `${v.n}: ${KODE[v.k]}`).join('; ')
const sudahPulang = (p) => p.status === 'libur' || (p.sudah_pulang && !p.bertugas && !['izin', 'sakit', 'cuti', 'dinas_luar'].includes(p.status))
const ringkasSesi = (x) => { const h = {}; x.forEach((p) => { h[p.sesi_kini] = (h[p.sesi_kini] || 0) + 1 }); return Object.entries(h).map(([k, v]) => `${k} ${v}`).join(' · ') }

// ---------- Rekap kelompok, sesi pagi/malam, kehadiran pegawai per sesi ----------
const JK_NAMA = { L: 'Putra', P: 'Putri' }
const JENJANG_NAMA = { wustha: 'SMP', sma: 'SMA' }
/** Daftar rekap kelompok (dapat dicetak): nama, putra/putri atau jenjang, pengasuh, L, P, jumlah, beserta baris jumlah. */
function daftarGrup(judul, grup, namaKolom, pengasuhKolom, kelas = false) {
  const baris = grup.map((g) => ({ nama: g.nama, ket: kelas ? `${JENJANG_NAMA[g.jenjang] || ''}${g.tingkat ? ' · ' + g.tingkat : ''}` : JK_NAMA[g.jk] || 'Campuran',
    pengasuh: g.pengasuh || 'Belum ditetapkan', l: g.l || 0, p: g.p || 0, n: (g.l || 0) + (g.p || 0) }))
  return { judul, kolom: [['nama', namaKolom, 20], ['ket', kelas ? 'Jenjang' : 'Putra/Putri', 11], ['pengasuh', pengasuhKolom, 33], ['l', 'L', 7], ['p', 'P', 7], ['n', 'Jumlah', 9]], baris,
    tegak: true, total: { nama: 'Jumlah', ket: '', pengasuh: '', l: baris.reduce((a, b) => a + b.l, 0), p: baris.reduce((a, b) => a + b.p, 0), n: baris.reduce((a, b) => a + b.n, 0) } }
}
const kartuGrup = (judul, grup, ikon, w, satuan, namaKolom, pengasuhKolom, kelas = false, ttd = null) => {
  const n = grup.reduce((a, g) => a + (g.l || 0) + (g.p || 0), 0); const tanpa = grup.filter((g) => !g.pengasuh).length
  const d = daftarGrup(`Rekap ${judul.replace(/^Jumlah /, '').toLowerCase()}`, grup, namaKolom, pengasuhKolom, kelas); d.ttd = ttd
  return kartu(judul, grup.length, ikon, w, `${n} santri · rata-rata ${grup.length ? Math.round(n / grup.length) : 0}/${satuan}${tanpa ? ` · ${tanpa} tanpa ${pengasuhKolom.toLowerCase()}` : ''}`, d)
}
/** Pilih sesi santri bernama pagi/malam (cadangan: sesi pertama/terakhir). */
const sesiPagi = (daftar) => daftar.find((h) => /pagi|subuh/i.test(h.n)) || (daftar.length > 1 ? daftar[0] : null)
const sesiMalam = (daftar) => daftar.find((h) => /malam/i.test(h.n)) || daftar[daftar.length - 1] || null
/** Pegawai dengan sesi kerja pagi/malam pada hari itu beserta kehadirannya. */
function hadirSesiPeg(d, pegawai, waktu) {
  const cocok = (x) => (waktu === 'pagi' ? /pagi|subuh/i.test(x.n) || (x.mulai || '') < '11:00' : /malam/i.test(x.n) || (x.mulai || '') >= '17:00')
  const ada = []; const hadir = []
  for (const p of pegawai) {
    const s = (d.pegawai_sesi?.[p.id] || []).find(cocok); if (!s) continue
    const st = ['izin', 'sakit', 'cuti', 'dinas_luar'].includes(p.status) ? p.status : s.st
    const x = { ...p, ket: `${s.n} ${s.mulai || ''} · ${STATUS_PEG[st] || 'Belum presensi'}` }; ada.push(x); if (['hadir', 'terlambat'].includes(st)) hadir.push(x)
  }
  return { ada, hadir, adaData: !!d.pegawai_sesi }
}
const saringGrup = (d, jenis, f, jenjang = null) => (d.grup || []).filter((g) => g.jenis === jenis && (!f.jk || !g.jk || g.jk === f.jk) && (!jenjang || g.jenjang === jenjang) && (jenjang || !f.jenjang || jenis !== 'kelas' || g.jenjang === f.jenjang))

// ---------- Slide sekolah (SMP/SMA) ----------
function slideSekolah(k, judul, jenjang, bidangKode, santriAll, pegawaiAll, sesiAll, pelajaranAll, d, f) {
  const jp = pelajaranAll.filter((x) => x.jenjang === jenjang); const jpOk = jp.filter((x) => x.status === 'terlaksana'); const jpLewat = jp.filter((x) => ['belum_diisi', 'tidak_terlaksana'].includes(x.status))
  const s = santriAll.filter((x) => x.jenjang === jenjang); const ks = kelasSantri(s)
  const sesi = sesiAll.filter((x) => x.jenis === 'kelas' && (!x.jenjang || x.jenjang === jenjang)); const ok = sesi.filter((x) => x.status === 'terisi')
  const guru = pegawaiAll.filter((p) => p.bidang_kode === bidangKode && p.status !== 'libur'); const guruHadir = guru.filter((p) => ['hadir', 'terlambat'].includes(p.status))
  const guruTidak = guru.filter((p) => ['izin', 'sakit', 'cuti', 'tanpa_keterangan', 'belum', 'menunggu_verval'].includes(p.status))
  const sakit = s.filter((x) => x.sakit); const luar = s.filter((x) => x.luar)
  const grup = saringGrup(d, 'kelas', f, jenjang)
  const perKelas = {}; for (const x of ks.kelas) { const n = x.kelas || '–'; perKelas[n] = perKelas[n] || { n, h: 0, t: 0 }; x.kelas_tidak >= x.kelas_sesi ? perKelas[n].t++ : perKelas[n].h++ }
  return { k, judul, ikon: PhGraduationCap, w: jenjang === 'sma' ? 'jadwal' : 'santri', sub: `Kelas ${jenjang === 'sma' ? '10–12' : '7–9'} · kehadiran kelas, pelajaran, dan guru hari ini`,
    kartu: [
      kartu('Santri aktif', s.length, PhStudent, 'santri', ketLP(s), daftarS(`Santri ${judul}`, s.map((x) => rapiS(x)))),
      kartuGrup('Jumlah kelas', grup, PhUsersFour, 'laporan', 'kelas', 'Kelas', 'Wali kelas', true, { jenis: 'kelas', jenjang }),
      kartu('Hadir di kelas', `${ks.hadir}/${ks.kelas.length}`, PhChalkboardTeacher, 'presensi', `${pr(ks.hadir, ks.kelas.length)} kehadiran`, daftarS('Santri hadir di kelas', ks.kelas.filter((x) => x.kelas_tidak < x.kelas_sesi).map((x) => rapiS(x)))),
      kartu('Tidak hadir (sebagian/seluruh)', ks.tidak.length, PhUserMinus, 'klinik', `${pr(ks.tidak.length, ks.kelas.length)} · izin, sakit, absen, atau bolos`, daftarS('Santri tidak hadir di kelas', ks.tidak.map((x) => rapiS(x, { ket: `Tidak hadir ${x.kelas_tidak} dari ${x.kelas_sesi} sesi` })), [['ket', 'Keterangan', 20]])),
      kartu('Absensi kelas terisi', `${ok.length}/${sesi.length}`, PhCalendarCheck, 'jadwal', `${pr(ok.length, sesi.length)} · ${sesi.filter((x) => x.status === 'tidak_terisi').length} lewat, belum diisi`, daftarSesi(`Absensi kelas ${judul} hari ini`, sesi)),
      kartu('Jam pelajaran terlaksana', `${jpOk.length}/${jp.length}`, PhNotebook, 'gurumapel', `${pr(jpOk.length, jp.length)} · ${jpLewat.length} tidak terlaksana/jurnal belum diisi`, daftarJp(`Jam pelajaran ${judul} hari ini`, jp)),
      kartu('Guru hadir', `${guruHadir.length}/${guru.length}`, PhUserCheck, 'pegawai', `${pr(guruHadir.length, guru.length)} dari pegawai bidang ${judul} terjadwal`, daftarP(`Guru/pegawai ${judul}`, guru.map((p) => rapiP(p)))),
      kartu('Guru tidak/belum hadir', guruTidak.length, PhUserList, 'pengajuan', `${pr(guruTidak.length, guru.length)} · izin, sakit, cuti, atau belum presensi`, daftarP(`Guru/pegawai ${judul} tidak/belum hadir`, guruTidak.map((p) => rapiP(p, { ket: STATUS_PEG[p.status] })))),
      kartu('Santri sakit', sakit.length, PhFirstAidKit, 'klinik', `${pr(sakit.length, s.length)} dari santri ${judul}`, daftarS(`Santri ${judul} sakit`, sakit.map((x) => rapiS(x, { ket: x.sakit })), [['ket', 'Keterangan', 22]])),
      kartu('Santri di luar pondok', luar.length, PhSignOut, 'security', `${pr(luar.length, s.length)} · izin atau libur`, daftarS(`Santri ${judul} di luar pondok`, luar.map((x) => rapiS(x, { ket: x.luar.alasan, batas: formatWaktu(x.luar.batas) })), [['ket', 'Izin', 20], ['batas', 'Batas kembali', 14]])),
    ],
    grafik: [grafikPerKelompok('Kehadiran per kelas', Object.values(perKelas).sort((a, b) => a.n.localeCompare(b.n, 'id', { numeric: true }))), grafikStatusSesi('Status sesi kelas', sesi)] }
}

/** Susun semua slide. d = muatan pantauan_langsung, f = { jk, jenjang, bidang } */
export function susunSlide(d, f, x = {}) {
  const cocokS = (x) => (!f.jk || x.jk === f.jk) && (!f.jenjang || x.jenjang === f.jenjang)
  const santri = d.santri.filter(cocokS); const santriJk = d.santri.filter((x) => !f.jk || x.jk === f.jk)
  const pegawai = d.pegawai.filter((p) => (!f.jk || p.jk === f.jk) && (!f.bidang || p.bidang_id === f.bidang)); const pegawaiJk = d.pegawai.filter((p) => !f.jk || p.jk === f.jk)
  const sesiAll = d.sesi.filter((s) => !f.jk || !s.jk || s.jk === f.jk); const sesi = sesiAll.filter((s) => !f.jenjang || !s.jenjang || s.jenjang === f.jenjang)
  const idSantri = new Set(santri.map((s) => s.id)); const petaSantri = Object.fromEntries(d.santri.map((s) => [s.id, s]))
  const hadirPeg = (p) => ['hadir', 'terlambat'].includes(p.status)
  const hf = (d.hafalan || []).filter((h) => idSantri.has(h.id)).map((h) => ({ ...petaSantri[h.id], ...h }))
  const slide = []

  // 1. Santri
  {
    const ks = kelasSantri(santri); const sakit = santri.filter((x) => x.sakit); const luar = santri.filter((x) => x.luar); const telat = luar.filter((x) => x.luar.terlambat)
    const asrama = sesiSantri(santri, 'asrama:'); const hq = sesiSantri(santri, 'halaqah:'); const pagi = sesiPagi(asrama); const malam = sesiMalam(asrama)
    const hs = halaqahSantri(santri); const ikutEkskul = santri.filter((x) => x.ekskul); const setor = hf.filter((h) => h.setor_hari_ini)
    const kartuAsrama = (h, nama, ikon) => (h ? { ...kartuSesiSantri(h, ikon, 'musyrif', 'tidak di asrama'), j: nama, ket: `${pr(h.hadir.length, h.ada.length)} · ${h.ada.length - h.hadir.length} tidak di asrama` }
      : kartu(nama, '–', ikon, 'musyrif', 'Sesi asrama belum diisi', daftarS(nama, [])))
    slide.push({ k: 'santri', judul: 'Santri', ikon: PhStudent, w: 'santri', sub: 'Kondisi seluruh santri hari ini',
      kartu: [
        kartu('Santri aktif', santri.length, PhStudent, 'santri', ketLP(santri), daftarS('Santri aktif', santri.map((x) => rapiS(x)), [['halaqah', 'Halaqah', 18]])),
        kartu('Hadir di kelas', `${ks.hadir}/${ks.kelas.length}`, PhChalkboardTeacher, 'jadwal', `${pr(ks.hadir, ks.kelas.length)} · ${ks.tidak.length} tidak hadir sebagian/seluruh`, daftarS('Santri tidak hadir di kelas', ks.tidak.map((x) => rapiS(x, { ket: `Tidak hadir ${x.kelas_tidak} dari ${x.kelas_sesi} sesi` })), [['ket', 'Keterangan', 20]])),
        kartu('Hadir di halaqah', `${hs.hadir.length}/${hs.ada.length}`, PhBookOpenText, 'tahfizh', `${pr(hs.hadir.length, hs.ada.length)} · ${hs.tidak.length} tidak hadir sebagian/seluruh`, daftarS('Santri tidak hadir di halaqah', hs.tidak.map((x) => rapiS(x, { ket: ketHalaqah(x) })), [['halaqah', 'Halaqah', 16], ['ket', 'Keterangan', 22]])),
        kartuAsrama(pagi && pagi !== malam ? pagi : null, 'Asrama pagi', PhSun),
        kartuAsrama(malam, 'Asrama malam', PhMoon),
        kartu('Sakit', sakit.length, PhFirstAidKit, 'klinik', `${pr(sakit.length, santri.length)} · ${sakit.filter((x) => /Dirawat/.test(x.sakit)).length} dirawat di klinik`, daftarS('Santri sakit', sakit.map((x) => rapiS(x, { ket: x.sakit })), [['ket', 'Keterangan', 20]])),
        kartu('Di luar pondok', luar.length, PhSignOut, 'security', `${pr(luar.length, santri.length)} · izin atau libur, belum kembali`, daftarS('Santri di luar pondok', luar.map((x) => rapiS(x, { ket: x.luar.alasan, batas: formatWaktu(x.luar.batas) })), [['ket', 'Izin', 20], ['batas', 'Batas kembali', 14]])),
        kartu('Terlambat kembali', telat.length, PhSiren, 'klinik', `${pr(telat.length, luar.length)} dari santri di luar`, daftarS('Santri terlambat kembali', telat.map((x) => rapiS(x, { ket: x.luar.alasan, batas: formatWaktu(x.luar.batas) })), [['ket', 'Izin', 20], ['batas', 'Batas kembali', 14]])),
        kartu('Setor hafalan', `${setor.length}/${hf.length}`, PhBooks, 'gaji', `${pr(setor.length, hf.length)} santri setor hari ini`, daftarS('Santri setor hafalan hari ini', setor.map((x) => rapiS(x, { hari_ini: x.hari_ini ?? 0 })), [['halaqah', 'Halaqah', 16], ['hari_ini', 'Tambah (hal)', 10]])),
        kartu('Ikut ekskul', ikutEkskul.length, PhPersonSimpleRun, 'ekskul', `${pr(ikutEkskul.length, santri.length)} dari santri aktif`, daftarS('Santri peserta ekskul', ikutEkskul.map((x) => rapiS(x, { ekskul: x.ekskul })), [['ekskul', 'Ekskul', 20]])),
      ],
      grafik: [
        { tipe: 'batang', judul: 'Kehadiran per kegiatan hari ini (%)', sumbuY: 'Persen hadir', label: ['Kelas', ...hq.map((h) => h.n), ...asrama.map((h) => h.n)],
          seri: [{ n: 'Hadir (%)', warna: W.hijau, nilai: [persen(ks.hadir, ks.kelas.length), ...hq.map((h) => persen(h.hadir.length, h.ada.length)), ...asrama.map((h) => persen(h.hadir.length, h.ada.length))] }] },
        f.jk ? { tipe: 'lingkaran', judul: 'Santri per jenjang', data: [{ n: 'SMP (Wustha)', nilai: santri.filter((x) => x.jenjang === 'wustha').length, warna: W.biru }, { n: 'SMA', nilai: santri.filter((x) => x.jenjang === 'sma').length, warna: W.teal }] }
          : { tipe: 'lingkaran', judul: 'Santri putra dan putri', data: [{ n: 'Putra', nilai: santri.filter((x) => x.jk === 'L').length, warna: W.biru }, { n: 'Putri', nilai: santri.filter((x) => x.jk === 'P').length, warna: W.ungu }] },
      ] })
  }

  // 2. Pegawai (umum)
  {
    const n = (fn) => pegawai.filter(fn); const terjadwal = n((p) => p.status !== 'libur'); const T = terjadwal.length
    const isc = (p) => ['izin', 'sakit', 'cuti'].includes(p.status); const belum = (p) => ['belum', 'menunggu_verval'].includes(p.status)
    const perBidang = d.bidang.filter((b) => !f.bidang || b.id === f.bidang).map((b) => { const x = pegawai.filter((p) => p.bidang_id === b.id && p.status !== 'libur'); return { n: b.nama.replace(/^Bidang /, ''), h: x.filter(hadirPeg).length, t: x.length - x.filter(hadirPeg).length } }).filter((b) => b.h + b.t > 0)
    const bertugas = n((p) => p.bertugas)
    slide.push({ k: 'pegawai', judul: 'Pegawai', ikon: PhUserCheck, w: 'pegawai', sub: 'Presensi seluruh pegawai hari ini',
      kartu: [
        kartu('Pegawai aktif', pegawai.length, PhUsersFour, 'pegawai', `${T} terjadwal (${pr(T, pegawai.length)}) · ${ketLP(pegawai)}`, daftarP('Pegawai aktif', pegawai.map((p) => rapiP(p)))),
        kartu('Hadir', `${n(hadirPeg).length}/${T}`, PhUserCheck, 'presensi', `${pr(n(hadirPeg).length, T)} dari pegawai terjadwal`, daftarP('Pegawai hadir', n(hadirPeg).map((p) => rapiP(p)))),
        kartu('Sementara bertugas', bertugas.length, PhBriefcase, 'walikelas', d.lalu ? 'Hanya tersedia pada hari berjalan' : `${pr(bertugas.length, T)} · ${ringkasSesi(bertugas) || 'tidak ada sesi berjalan'}`,
          daftarP('Pegawai sementara bertugas di pondok', bertugas.map((p) => rapiP(p, { ket: `Sesi ${p.sesi_kini}` })))),
        kartu('Terlambat', n((p) => p.status === 'terlambat').length, PhClock, 'pengajuan', `${pr(n((p) => p.status === 'terlambat').length, T)} · datang lewat batas`, daftarP('Pegawai terlambat', n((p) => p.status === 'terlambat').map((p) => rapiP(p)))),
        kartu('Cepat pulang', n((p) => p.cepat_menit > 0).length, PhTimer, 'klinik', `${pr(n((p) => p.cepat_menit > 0).length, T)} · absen pulang sebelum waktunya`, daftarP('Pegawai cepat pulang', n((p) => p.cepat_menit > 0).map((p) => rapiP(p, { ket: `Cepat ${p.cepat_menit} menit, pulang ${formatJam(p.pulang_pada)}` })))),
        kartu('Dinas luar', n((p) => p.status === 'dinas_luar').length, PhAirplaneTilt, 'jadwal', `${pr(n((p) => p.status === 'dinas_luar').length, T)} · bertugas di luar pondok`, daftarP('Pegawai dinas luar', n((p) => p.status === 'dinas_luar').map((p) => rapiP(p)))),
        kartu('Izin, sakit, cuti', n(isc).length, PhUserMinus, 'klinik', `${pr(n(isc).length, T)} · ${n((p) => p.status === 'izin').length} izin · ${n((p) => p.status === 'sakit').length} sakit · ${n((p) => p.status === 'cuti').length} cuti`, daftarP('Pegawai izin, sakit, cuti', n(isc).map((p) => rapiP(p)))),
        kartu('Belum presensi', n(belum).length, PhHourglass, 'agenda', `${pr(n(belum).length, T)} · ${n((p) => p.status === 'akan_datang').length} sesinya belum dibuka`, daftarP('Pegawai belum presensi', n((p) => belum(p) || p.status === 'akan_datang').map((p) => rapiP(p, { ket: STATUS_PEG[p.status] })))),
        kartu('Tanpa keterangan', n((p) => p.status === 'tanpa_keterangan').length, PhQuestion, 'shift', `${pr(n((p) => p.status === 'tanpa_keterangan').length, T)} · tidak hadir tanpa keterangan`, daftarP('Pegawai tanpa keterangan', n((p) => p.status === 'tanpa_keterangan').map((p) => rapiP(p)))),
        kartu('Sudah pulang', n(sudahPulang).length, PhHouse, 'hakakses', `${pr(n(sudahPulang).length, pegawai.length)} · ${n((p) => p.status !== 'libur' && sudahPulang(p)).length} absen pulang · ${n((p) => p.status === 'libur').length} tidak terjadwal`,
          daftarP('Pegawai sudah pulang atau tidak terjadwal', n(sudahPulang).map((p) => rapiP(p, { ket: p.status === 'libur' ? 'Tidak terjadwal' : `Sudah pulang${p.pulang_pada ? ' ' + formatJam(p.pulang_pada) : ''}` })))),
      ],
      grafik: [
        { tipe: 'lingkaran', judul: 'Status presensi pegawai', satuan: 'pegawai', data: [
          { n: 'Hadir tepat', nilai: n((p) => p.status === 'hadir').length, warna: W.hijau }, { n: 'Terlambat', nilai: n((p) => p.status === 'terlambat').length, warna: W.jingga },
          { n: 'Dinas luar', nilai: n((p) => p.status === 'dinas_luar').length, warna: W.biru }, { n: 'Izin/sakit/cuti', nilai: n(isc).length, warna: W.ungu },
          { n: 'Belum/tanpa keterangan', nilai: n(belum).length + n((p) => ['akan_datang', 'tanpa_keterangan'].includes(p.status)).length, warna: W.abu }] },
        { tipe: 'batang', judul: 'Kehadiran per bidang', sumbuY: 'Jumlah pegawai', label: perBidang.map((b) => b.n), seri: [{ n: 'Hadir', warna: W.hijau, nilai: perBidang.map((b) => b.h) }, { n: 'Belum/tidak hadir', warna: W.abu, nilai: perBidang.map((b) => b.t) }] },
      ] })
  }

  // 3–4. Sekolah SMP dan SMA (jenjang tetap, saringan jenis kelamin berlaku)
  const pelajaranJk = (d.pelajaran || []).filter((x) => !f.jk || !x.jk || x.jk === f.jk)
  slide.push(slideSekolah('smp', 'SMP', 'wustha', 'WUSTHA', santriJk, pegawaiJk, sesiAll, pelajaranJk, d, f))
  slide.push(slideSekolah('sma', 'SMA', 'sma', 'SMA', santriJk, pegawaiJk, sesiAll, pelajaranJk, d, f))

  // 5. Tahfizh (kehadiran halaqah)
  {
    const hq = sesiSantri(santri, 'halaqah:'); const sk = sesiKegiatan(sesi, 'halaqah'); const hs = halaqahSantri(santri)
    const uj = (d.ujian || []).filter((x) => (!f.jk || x.jk === f.jk) && (!f.jenjang || x.jenjang === f.jenjang))
    const muh = pegawaiJk.filter((p) => (p.muhaffizh || p.bidang_kode === 'TAHFIZH') && p.status !== 'libur'); const muhTidak = muh.filter((p) => !hadirPeg(p) && p.status !== 'akan_datang')
    const berHalaqah = santri.filter((x) => x.halaqah); const tanpa = santri.filter((x) => !x.halaqah)
    const grup = saringGrup(d, 'halaqah', f)
    const ket = (h) => `${pr(h.hadir.length, h.ada.length)} · ${h.ada.length - h.hadir.length} tidak hadir`
    const kartuSesi = hq.map((h) => ({ ...kartuSesiSantri(h, PhBookOpenText, 'tahfizh', 'tidak hadir'), ket: ket(h) }))
    const calon = [
      kartuGrup('Jumlah halaqah', grup, PhUsersFour, 'tahfizh', 'halaqah', 'Halaqah', 'Muhaffizh', false, { jenis: 'halaqah' }),
      kartu('Santri berhalaqah', berHalaqah.length, PhStudent, 'santri', `${pr(berHalaqah.length, santri.length)} dari santri aktif`, daftarS('Santri berhalaqah', berHalaqah.map((x) => rapiS(x)), [['halaqah', 'Halaqah', 18]])),
      kartu('Hadir di halaqah', `${hs.hadir.length}/${hs.ada.length}`, PhCheckCircle, 'presensi', `${pr(hs.hadir.length, hs.ada.length)} hadir minimal satu sesi`, daftarS('Santri hadir di halaqah', hs.hadir.map((x) => rapiS(x)), [['halaqah', 'Halaqah', 18]])),
      ...kartuSesi.slice(0, 3),
      kartu('Sesi halaqah terlaksana', `${sk.ok.length}/${sk.s.length}`, PhCalendarCheck, 'jadwal', `${pr(sk.ok.length, sk.s.length)} · ${sk.telat.length} lewat, belum diisi`, daftarSesi('Sesi halaqah hari ini', sk.s)),
      kartu('Muhaffizh hadir', `${muh.filter(hadirPeg).length}/${muh.length}`, PhUserCheck, 'pegawai', `${pr(muh.filter(hadirPeg).length, muh.length)} dari muhaffizh terjadwal`, daftarP('Muhaffizh hari ini', muh.map((p) => rapiP(p)))),
      kartu('Muhaffizh tidak/belum hadir', muhTidak.length, PhUserList, 'pengajuan', `${pr(muhTidak.length, muh.length)} · izin, sakit, atau belum presensi`, daftarP('Muhaffizh tidak/belum hadir', muhTidak.map((p) => rapiP(p, { ket: STATUS_PEG[p.status] })))),
      kartu('Ujian tahfizh hari ini', uj.length, PhExam, 'agenda', `${uj.filter((x) => x.hasil === 'tuntas').length} tuntas (${pr(uj.filter((x) => x.hasil === 'tuntas').length, uj.length)}) · ${uj.filter((x) => x.status === 'dijadwalkan').length} terjadwal`,
        daftarS('Ujian tahfizh hari ini', uj.map((x) => rapiS(x, { ket: `${x.jenis === 'kenaikan' ? 'Kenaikan juz ' + (x.juz ?? '') : 'Sertifikasi ' + (x.jenjang_sertifikasi ?? '') + ' juz'}`, hasil: x.hasil === 'tuntas' ? `Tuntas (${x.nilai ?? '–'})` : x.hasil === 'remidi' ? `Remidi (${x.nilai ?? '–'})` : 'Terjadwal ' + formatJam(x.jadwal), penguji: x.penguji || '–' })), [['ket', 'Ujian', 18], ['hasil', 'Hasil', 14], ['penguji', 'Penguji', 18]])),
      kartu('Santri tidak hadir halaqah', hs.tidak.length, PhUserMinus, 'klinik', `${pr(hs.tidak.length, hs.ada.length)} · minimal satu sesi hari ini`, daftarS('Santri tidak hadir halaqah', hs.tidak.map((x) => rapiS(x, { ket: ketHalaqah(x) })), [['halaqah', 'Halaqah', 16], ['ket', 'Keterangan', 22]])),
      kartu('Belum berhalaqah', tanpa.length, PhWarningCircle, 'hakakses', `${pr(tanpa.length, santri.length)} dari santri aktif`, daftarS('Santri belum berhalaqah', tanpa.map((x) => rapiS(x)))),
    ]
    slide.push({ k: 'tahfizh', judul: 'Tahfizh', ikon: PhBookOpenText, w: 'tahfizh', sub: 'Halaqah hari ini: kehadiran santri, sesi, dan muhaffizh', kartu: calon.slice(0, 10),
      grafik: [grafikPerKelompok('Kehadiran per sesi halaqah', hq.map((h) => ({ n: h.n, h: h.hadir.length, t: h.ada.length - h.hadir.length }))), grafikStatusSesi('Status sesi halaqah', sk.s)] })
  }

  // 6. Hafalan santri
  {
    const terdata = hf.filter((h) => h.status !== 'tidak_terdata'); const capai = hf.filter((h) => ['tercapai', 'khatam'].includes(h.status)); const tidakCapai = hf.filter((h) => h.status === 'tidak_tercapai')
    const setor = hf.filter((h) => h.setor_hari_ini); const tidakSetor = hf.filter((h) => !h.setor_hari_ini && h.halaqah); const halHari = hf.reduce((a, h) => a + (h.hari_ini || 0), 0); const halBulan = hf.reduce((a, h) => a + Math.max(0, h.tambah || 0), 0)
    const rata = hf.length ? (hf.reduce((a, h) => a + (h.resmi || 0), 0) / hf.length).toFixed(1).replace('.', ',') : '0'
    const khatam = hf.filter((h) => (h.resmi || 0) >= 30); const j10 = hf.filter((h) => (h.resmi || 0) >= 10); const j20 = hf.filter((h) => (h.resmi || 0) >= 20)
    const ember = [['0', 0, 0], ['1–5', 1, 5], ['6–10', 6, 10], ['11–15', 11, 15], ['16–20', 16, 20], ['21–29', 21, 29], ['30', 30, 30]]
    const K_H = [['halaqah', 'Halaqah', 16], ['resmi', 'Juz resmi', 8], ['tambah', 'Tambah bulan ini (hal)', 10], ['target', 'Target (hal)', 8]]
    const bH = (x) => rapiS(x, { resmi: x.resmi ?? 0, tambah: x.tambah ?? 0, target: x.target ?? 0, hari_ini: x.hari_ini ?? 0 })
    const urutResmi = (x) => [...x].sort((a, b) => (b.resmi || 0) - (a.resmi || 0)).map(bH)
    slide.push({ k: 'hafalan', judul: 'Hafalan', ikon: PhBooks, w: 'tahfizh', sub: 'Capaian hafalan bulan berjalan dan setoran hari ini',
      kartu: [
        kartu('Rata-rata hafalan resmi', `${rata} juz`, PhBooks, 'tahfizh', `${hf.length} santri terdata (${pr(hf.length, santri.length)})`, daftarS('Hafalan resmi santri', urutResmi(hf), K_H)),
        kartu('Khatam 30 juz', khatam.length, PhTrophy, 'gaji', `${pr(khatam.length, hf.length)} · juz resmi tervalidasi`, daftarS('Santri khatam 30 juz', khatam.map(bH), K_H)),
        kartu('Hafalan 20 juz ke atas', j20.length, PhBookBookmark, 'ekskul', `${pr(j20.length, hf.length)} dari santri terdata`, daftarS('Santri hafalan 20 juz ke atas', urutResmi(j20), K_H)),
        kartu('Hafalan 10 juz ke atas', j10.length, PhBookBookmark, 'jadwal', `${pr(j10.length, hf.length)} dari santri terdata`, daftarS('Santri hafalan 10 juz ke atas', urutResmi(j10), K_H)),
        kartu('Setor hari ini', `${setor.length}/${hf.length}`, PhCalendarCheck, 'presensi', `${pr(setor.length, hf.length)} · ${halHari} halaman hafalan baru`, daftarS('Santri setor hari ini', setor.map((x) => bH(x)), [['halaqah', 'Halaqah', 16], ['hari_ini', 'Tambah hari ini (hal)', 10]])),
        kartu('Belum setor hari ini', tidakSetor.length, PhCalendarX, 'pengajuan', `${pr(tidakSetor.length, hf.length)} dari santri terdata`, daftarS('Santri belum setor hari ini', tidakSetor.map(bH), K_H)),
        kartu('Tambahan bulan ini', `${halBulan} hal`, PhTrendUp, 'santri', `Rata-rata ${hf.length ? Math.round(halBulan / hf.length) : 0} hal per santri`, daftarS('Tambahan hafalan bulan ini', [...hf].sort((a, b) => (b.tambah || 0) - (a.tambah || 0)).map(bH), K_H)),
        kartu('Mencapai target bulan ini', `${capai.length}/${terdata.length}`, PhMedal, 'presensi', `${pr(capai.length, terdata.length)} dari santri terdata`, daftarS('Santri mencapai target', capai.map(bH), K_H)),
        kartu('Belum mencapai target', tidakCapai.length, PhWarningCircle, 'klinik', `${pr(tidakCapai.length, terdata.length)} · perlu pendampingan muhaffizh`, daftarS('Santri belum mencapai target', tidakCapai.map(bH), K_H)),
        kartu('Capaian belum terdata', hf.length - terdata.length, PhQuestion, 'hakakses', `${pr(hf.length - terdata.length, hf.length)} · target/setoran belum tercatat`, daftarS('Santri capaian belum terdata', hf.filter((h) => h.status === 'tidak_terdata').map(bH), K_H)),
      ],
      grafik: [
        { tipe: 'lingkaran', judul: 'Capaian target bulan ini', data: [{ n: 'Tercapai/khatam', nilai: capai.length, warna: W.hijau }, { n: 'Belum tercapai', nilai: tidakCapai.length, warna: W.merah },
          { n: 'Belum terdata', nilai: hf.length - terdata.length, warna: W.abu }] },
        { tipe: 'batang', judul: 'Sebaran hafalan resmi (juz)', sumbuY: 'Jumlah santri', label: ember.map((e) => e[0] + ' juz'),
          seri: [{ n: 'Santri', warna: W.teal, nilai: ember.map(([, a, b]) => hf.filter((h) => (h.resmi || 0) >= a && (h.resmi || 0) <= b).length) }] },
      ] })
  }

  // 7. Asrama dan musyrif
  {
    const asrama = sesiSantri(santri, 'asrama:'); const sk = sesiKegiatan(sesi, 'asrama'); const pagi = sesiPagi(asrama); const malam = sesiMalam(asrama)
    const mus = pegawaiJk.filter((p) => p.musyrif && p.status !== 'libur'); const sakit = santri.filter((x) => x.sakit && !/Dirujuk/.test(x.sakit))
    const luar = santri.filter((x) => x.luar); const berkamar = santri.filter((x) => x.kamar); const grup = saringGrup(d, 'kamar', f)
    const mPagi = hadirSesiPeg(d, mus, 'pagi'); const mMalam = hadirSesiPeg(d, mus, 'malam')
    const kartuS = (h, nama, ikon) => (h ? { ...kartuSesiSantri(h, ikon, 'musyrif', 'tidak di asrama'), j: nama, ket: `${pr(h.hadir.length, h.ada.length)} · ${h.ada.length - h.hadir.length} tidak di asrama` }
      : kartu(nama, '–', ikon, 'musyrif', 'Sesi asrama belum diisi', daftarS(nama, [])))
    const kartuM = (x, nama, ikon) => kartu(nama, `${x.hadir.length}/${x.ada.length}`, ikon, 'pegawai', x.ada.length ? `${pr(x.hadir.length, x.ada.length)} dari musyrif terjadwal` : 'Tidak ada sesi musyrif',
      daftarP(`${nama} hari ini`, x.ada.map((p) => rapiP(p))))
    const perKamar = {}; if (malam) for (const x of malam.ada) { const n = x.kamar || '–'; perKamar[n] = perKamar[n] || { n, h: 0, t: 0 }; hadirKode(x.sesi[malam.k].k) ? perKamar[n].h++ : perKamar[n].t++ }
    slide.push({ k: 'musyrif', judul: 'Asrama', ikon: PhBed, w: 'musyrif', sub: 'Kehadiran asrama, sesi, dan musyrif hari ini',
      kartu: [
        kartuGrup('Jumlah kamar', grup, PhHouseLine, 'musyrif', 'kamar', 'Kamar', 'Musyrif/musyrifah', false, { jenis: 'kamar' }),
        kartu('Santri berkamar', berkamar.length, PhStudent, 'santri', `${pr(berkamar.length, santri.length)} · ${santri.length - berkamar.length} belum berkamar`, daftarS('Santri per kamar', [...santri].sort((a, b) => (a.kamar || '').localeCompare(b.kamar || '')).map((x) => rapiS(x)))),
        kartuS(pagi && pagi !== malam ? pagi : null, 'Asrama pagi', PhSun),
        kartuS(malam, 'Asrama malam', PhMoon),
        kartu('Santri di luar', luar.length, PhDoorOpen, 'security', `${pr(luar.length, santri.length)} · berada di luar pondok`, daftarS('Santri di luar pondok', luar.map((x) => rapiS(x, { ket: x.luar.alasan, batas: formatWaktu(x.luar.batas) })), [['ket', 'Izin', 20], ['batas', 'Batas kembali', 14]])),
        kartu('Sakit di asrama/klinik', sakit.length, PhFirstAidKit, 'klinik', `${pr(sakit.length, santri.length)} · istirahat atau dirawat`, daftarS('Santri sakit', sakit.map((x) => rapiS(x, { ket: x.sakit })), [['ket', 'Keterangan', 20]])),
        kartu('Sesi asrama terlaksana', `${sk.ok.length}/${sk.s.length}`, PhCalendarCheck, 'jadwal', `${pr(sk.ok.length, sk.s.length)} · ${sk.telat.length} lewat, belum diisi`, daftarSesi('Sesi asrama hari ini', sk.s)),
        kartu('Musyrif terjadwal', mus.length, PhUsersThree, 'walikelas', `${pr(mus.filter(hadirPeg).length, mus.length)} hadir minimal satu sesi`, daftarP('Musyrif terjadwal hari ini', mus.map((p) => rapiP(p)))),
        kartuM(mPagi, 'Musyrif hadir pagi', PhSun),
        kartuM(mMalam, 'Musyrif hadir malam', PhMoon),
      ],
      grafik: [grafikPerKelompok(malam ? `Kehadiran per kamar (${malam.n})` : 'Kehadiran per kamar', Object.values(perKamar).sort((a, b) => a.n.localeCompare(b.n, 'id'))), grafikStatusSesi('Status sesi asrama', sk.s)] })
  }

  // 8. Kegiatan santri dan pengampu
  {
    const J = [['kelas', 'Sesi kelas', PhChalkboardTeacher, 'jadwal'], ['halaqah', 'Sesi halaqah', PhBookOpenText, 'tahfizh'], ['asrama', 'Sesi asrama', PhBed, 'musyrif'], ['ekskul', 'Sesi ekskul', PhUsersThree, 'ekskul']]
    const telat = sesi.filter((x) => x.status === 'tidak_terisi'); const ok = sesi.filter((x) => x.status === 'terisi'); const belumBuka = sesi.filter((x) => x.status === 'belum_buka')
    const pel = pelajaranJk.filter((x) => !f.jenjang || x.jenjang === f.jenjang)
    const pengampuTelat = [...new Set(telat.flatMap((x) => (x.pengampu || '').split(', ').filter(Boolean)))]
    const hadirSesi = ok.reduce((a, x) => a + (x.hadir || 0), 0); const anggotaSesi = ok.reduce((a, x) => a + (x.anggota || 0), 0)
    slide.push({ k: 'kegiatan', judul: 'Kegiatan Santri', ikon: PhCalendarCheck, w: 'jadwal', sub: 'Sesi yang sudah dan belum terlaksana beserta pengampunya',
      kartu: [
        kartu('Seluruh sesi terlaksana', `${ok.length}/${sesi.length}`, PhListChecks, 'presensi', `${pr(ok.length, sesi.length)} dari sesi hari ini`, daftarSesi('Seluruh sesi hari ini', sesi)),
        ...J.map(([k, j, i, w]) => { const s = sesiKegiatan(sesi, k); return kartu(j, `${s.ok.length}/${s.s.length}`, i, w, `${pr(s.ok.length, s.s.length)} · ${s.telat.length ? `${s.telat.length} lewat, belum diisi` : `${s.s.length - s.ok.length} belum terlaksana`}`, daftarSesi(`${j} hari ini`, s.s)) }),
        kartu('Jam pelajaran', `${pel.filter((x) => x.status === 'terlaksana').length}/${pel.length}`, PhNotebook, 'gurumapel', `${pr(pel.filter((x) => x.status === 'terlaksana').length, pel.length)} · ${pel.filter((x) => x.status === 'belum_diisi').length} jurnal belum diisi`, daftarJp('Jam pelajaran hari ini', pel)),
        kartu('Kehadiran santri di sesi', pr(hadirSesi, anggotaSesi), PhPercent, 'santri', `${hadirSesi} dari ${anggotaSesi} santri pada sesi terlaksana`, daftarSesi('Kehadiran pada sesi terlaksana', ok)),
        kartu('Sedang berlangsung', sesi.filter((x) => x.status === 'terbuka').length, PhPlayCircle, 'agenda', `${pr(sesi.filter((x) => x.status === 'terbuka').length, sesi.length)} · sesi terbuka saat ini`, daftarSesi('Sesi sedang berlangsung', sesi.filter((x) => x.status === 'terbuka'))),
        kartu('Lewat waktu, belum diisi', telat.length, PhWarningCircle, 'klinik', `${pr(telat.length, sesi.length)} · ${pengampuTelat.length} pengampu perlu diingatkan`, daftarSesi('Sesi lewat waktu, belum diisi', telat)),
        kartu('Belum dimulai', belumBuka.length, PhHourglass, 'hakakses', `${pr(belumBuka.length, sesi.length)} dari sesi hari ini`, daftarSesi('Sesi belum dimulai', belumBuka)),
      ],
      grafik: [{ tipe: 'batang', judul: 'Status sesi per kegiatan', sumbuY: 'Jumlah sesi', label: J.map((x) => x[1].replace('Sesi ', '')),
        seri: [['terisi', 'Terlaksana', W.hijau], ['terbuka', 'Berlangsung', W.biru], ['belum_buka', 'Belum dimulai', W.abu], ['tidak_terisi', 'Lewat, belum diisi', W.merah]]
          .map(([st, n, warna]) => ({ n, warna, nilai: J.map(([k]) => sesi.filter((x) => x.jenis === k && x.status === st).length) })) }] })
  }

  // 9. Medis / klinik
  {
    const kl = (d.klinik || []).filter((c) => (!f.jk || c.jk === f.jk) && (!f.jenjang || c.jenjang === f.jenjang)); const hari = d.tanggal
    const tgl = (iso) => iso && new Date(new Date(iso).getTime() + 8 * 3600000).toISOString().slice(0, 10)
    const buka = kl.filter((c) => ['menunggu', 'ditangani'].includes(c.status)); const tl = (t) => buka.filter((c) => c.status === 'ditangani' && c.tindak_lanjut === t)
    const sembuh = kl.filter((c) => c.status === 'selesai' && tgl(c.selesai_pada) === hari); const baru = kl.filter((c) => tgl(c.dibuka_pada) === hari)
    const petugas = pegawaiJk.filter((p) => p.unit_kode === 'KLINIK' && p.status !== 'libur'); const N = santri.length
    const K_K = [['nama', 'Nama santri', 24], ['kelas', 'Kelas', 7], ['kamar', 'Kamar', 14], ['keluhan', 'Keluhan', 26], ['ket', 'Keterangan', 16]]
    const TL = { kembali: 'Kembali beraktivitas', istirahat: 'Istirahat di kamar', rawat: 'Dirawat di klinik', rujuk: 'Dirujuk', pulang: 'Dipulangkan' }
    const bK = (c) => ({ ...c, kelas: c.kelas || '–', kamar: c.kamar || '–', ket: c.status === 'menunggu' ? 'Menunggu pemeriksaan' : c.status === 'selesai' ? 'Sembuh/selesai' : TL[c.tindak_lanjut] || 'Ditangani' })
    const dK = (judul, x) => ({ judul, kolom: K_K, baris: x.map(bK) })
    const kS = (judul, x, ikon, w, ket) => kartu(judul, x.length, ikon, w, `${pr(x.length, N)} dari santri · ${ket}`, dK(judul, x))
    slide.push({ k: 'klinik', judul: 'Medis', ikon: PhStethoscope, w: 'klinik', sub: 'Klinik putra dan putri hari ini (tanpa diagnosis)',
      kartu: [
        kS('Kasus terbuka', buka, PhFlag, 'klinik', 'menunggu atau ditangani'),
        kS('Kasus baru hari ini', baru, PhFirstAidKit, 'pengajuan', 'dibuka hari ini'),
        kS('Menunggu pemeriksaan', buka.filter((c) => c.status === 'menunggu'), PhHourglass, 'agenda', 'rujukan belum diperiksa'),
        kS('Dirawat di klinik', tl('rawat'), PhHeartbeat, 'klinik', 'rawat inap klinik'),
        kS('Istirahat di kamar', tl('istirahat'), PhBed, 'musyrif', 'dipantau musyrif'),
        kS('Dirujuk atau dipulangkan', [...tl('rujuk'), ...tl('pulang')], PhAmbulance, 'shift', `${tl('pulang').length} dipulangkan`),
        kS('Kembali beraktivitas', tl('kembali'), PhPersonSimpleRun, 'ekskul', 'tetap dipantau'),
        kS('Diperiksa hari ini', kl.filter((c) => c.periksa_hari_ini > 0), PhStethoscope, 'jadwal', 'pemeriksaan tercatat'),
        kartu('Sembuh hari ini', sembuh.length, PhMedal, 'presensi', `${pr(sembuh.length, sembuh.length + buka.length)} dari kasus hari ini selesai`, dK('Sembuh hari ini', sembuh)),
        kartu('Petugas klinik hadir', `${petugas.filter(hadirPeg).length}/${petugas.length}`, PhUserCheck, 'pegawai', `${pr(petugas.filter(hadirPeg).length, petugas.length)} dari unit Klinik terjadwal`, daftarP('Petugas klinik', petugas.map((p) => rapiP(p)))),
      ],
      grafik: [
        { tipe: 'lingkaran', judul: 'Kasus terbuka menurut tindak lanjut', data: [{ n: 'Menunggu', nilai: buka.filter((c) => c.status === 'menunggu').length, warna: W.jingga },
          { n: 'Dirawat', nilai: tl('rawat').length, warna: W.merah }, { n: 'Istirahat', nilai: tl('istirahat').length, warna: W.ungu }, { n: 'Dirujuk/pulang', nilai: tl('rujuk').length + tl('pulang').length, warna: W.biru },
          { n: 'Lainnya', nilai: tl('kembali').length, warna: W.abu }] },
        { tipe: 'batang', judul: 'Kasus terbuka putra dan putri', sumbuY: 'Jumlah santri', label: ['Putra', 'Putri'],
          seri: [{ n: 'Kasus terbuka', warna: W.merah, nilai: ['putra', 'putri'].map((k) => buka.filter((c) => c.klinik === k).length) }, { n: 'Sembuh hari ini', warna: W.hijau, nilai: ['putra', 'putri'].map((k) => sembuh.filter((c) => c.klinik === k).length) }] },
      ] })
  }

  // 10. Security
  {
    const s = d.security; const g = s.gerbang.filter((x) => (!f.jk || x.jk === f.jk) && (!f.jenjang || x.jenjang === f.jenjang)); const t = s.titipan.filter((x) => !f.jk || !x.jenis_kelamin || x.jenis_kelamin === f.jk)
    const tm = s.tamu; const kj = s.kunjungan.filter((x) => !f.jk || !x.jenis_kelamin || x.jenis_kelamin === f.jk)
    const hari = (iso) => iso && new Date(new Date(iso).getTime() + 8 * 3600000).toISOString().slice(0, 10) === d.tanggal
    const K_G = [['jam', 'Jam', 7], ['nama', 'Nama santri', 24], ['kelas', 'Kelas', 7], ['kamar', 'Kamar', 14], ['ket', 'Keterangan', 26], ['petugas', 'Petugas', 16]]
    const gb = (j, x = g.filter((y) => y.jenis === j), judul = null) => ({ judul: judul || { keluar: 'Santri keluar hari ini', kembali: 'Santri kembali hari ini', ditolak: 'Santri ditolak di gerbang' }[j], kolom: K_G,
      baris: x.map((y) => ({ ...y, jam: formatJam(y.waktu), kelas: y.kelas || '–', kamar: y.kamar || '–', petugas: y.petugas || '–',
        ket: [y.penjemput && 'Penjemput ' + y.penjemput, y.terlambat_menit && 'Terlambat ' + y.terlambat_menit + ' menit', y.catatan].filter(Boolean).join('; ') || '–' })) })
    const K_T = [['nama', 'Santri', 22], ['kelas', 'Kelas', 7], ['barang', 'Barang', 26], ['pengirim', 'Pengirim', 16], ['diterima', 'Diterima', 14], ['ambil', 'Pengambilan', 24]]
    const tB = (fn) => t.filter(fn).map((x) => ({ ...x, kelas: x.kelas || '–', barang: `${JENIS_TITIPAN[x.jenis]?.n}: ${x.uraian}`, diterima: formatWaktu(x.diterima_pada),
      ambil: x.status === 'di_pos' ? 'Masih di pos' : x.status === 'diambil' ? `${x.pengambil_nama} (${PENGAMBIL[x.pengambil_jenis] || ''}) ${formatJam(x.diambil_pada)}` : x.status }))
    const petugas = pegawaiJk.filter((p) => p.unit_kode === 'SECURITY' && p.status !== 'libur')
    const nj = (j) => g.filter((x) => x.jenis === j).length; const N = santri.length
    const luar = santri.filter((x) => x.luar); const kembaliTelat = g.filter((x) => x.jenis === 'kembali' && x.terlambat_menit)
    slide.push({ k: 'security', judul: 'Security', ikon: PhShieldCheck, w: 'security', sub: 'Gerbang, titipan, tamu, dan kunjungan hari ini',
      kartu: [
        kartu('Santri di luar pondok', luar.length, PhDoorOpen, 'security', `${pr(luar.length, N)} dari santri aktif`, daftarS('Santri di luar pondok', luar.map((x) => rapiS(x, { ket: x.luar.alasan, batas: formatWaktu(x.luar.batas) })), [['ket', 'Izin', 20], ['batas', 'Batas kembali', 14]])),
        kartu('Keluar hari ini', nj('keluar'), PhSignOut, 'shift', `${pr(nj('keluar'), N)} dari santri · tercatat di gerbang`, gb('keluar')),
        kartu('Kembali hari ini', nj('kembali'), PhSignIn, 'presensi', `${pr(nj('kembali'), N)} dari santri · tercatat di gerbang`, gb('kembali')),
        kartu('Kembali terlambat', kembaliTelat.length, PhSiren, 'klinik', `${pr(kembaliTelat.length, nj('kembali'))} dari santri yang kembali`, gb('kembali', kembaliTelat, 'Santri kembali terlambat hari ini')),
        kartu('Ditolak di gerbang', nj('ditolak'), PhProhibit, 'klinik', `${pr(nj('ditolak'), nj('keluar') + nj('ditolak'))} dari upaya keluar · tanpa izin berlaku`, gb('ditolak')),
        kartu('Titipan di pos', t.filter((x) => x.status === 'di_pos').length, PhPackage, 'pengajuan', `${t.filter((x) => hari(x.diterima_pada)).length} diterima hari ini`, { judul: 'Titipan di pos dan diterima hari ini', kolom: K_T, baris: tB((x) => x.status === 'di_pos' || hari(x.diterima_pada)) }),
        kartu('Titipan diambil', t.filter((x) => x.status === 'diambil' && hari(x.diambil_pada)).length, PhHandArrowDown, 'gaji', 'Hari ini, tercatat pengambilnya', { judul: 'Titipan diambil hari ini', kolom: K_T, baris: tB((x) => x.status === 'diambil' && hari(x.diambil_pada)) }),
        kartu('Tamu', tm.filter((x) => !x.keluar_pada).length, PhIdentificationBadge, 'pegawai', `di dalam · ${tm.filter((x) => hari(x.masuk_pada)).length} tamu hari ini`,
          { judul: 'Tamu hari ini', kolom: [['jam', 'Masuk', 7], ['nama', 'Nama tamu', 20], ['instansi', 'Instansi', 18], ['keperluan', 'Keperluan', 24], ['ditemui', 'Menemui', 18], ['keluar', 'Keluar', 9]],
            baris: tm.map((x) => ({ ...x, jam: formatJam(x.masuk_pada), instansi: x.instansi || 'Pribadi', ditemui: x.ditemui || '–', keluar: x.keluar_pada ? formatJam(x.keluar_pada) : 'Di dalam' })) }),
        kartu('Kunjungan wali', kj.filter((x) => !x.pulang_pada).length, PhUsers, 'tahfizh', `berlangsung · ${kj.filter((x) => hari(x.datang_pada)).length} hari ini (${pr(kj.filter((x) => hari(x.datang_pada)).length, N)} dari santri)`,
          { judul: 'Kunjungan orang tua hari ini', kolom: [['jam', 'Datang', 7], ['nama', 'Santri', 22], ['kelas', 'Kelas', 7], ['pengunjung', 'Pengunjung', 24], ['pulang', 'Pulang', 10]],
            baris: kj.map((x) => ({ ...x, jam: formatJam(x.datang_pada), kelas: x.kelas || '–', pengunjung: x.pengunjung + (x.hubungan ? ` (${x.hubungan})` : ''), pulang: x.pulang_pada ? formatJam(x.pulang_pada) : 'Berlangsung' })) }),
        kartu('Petugas Security hadir', `${petugas.filter(hadirPeg).length}/${petugas.length}`, PhUserCheck, 'pegawai', `${pr(petugas.filter(hadirPeg).length, petugas.length)} dari unit Security terjadwal`, daftarP('Petugas Security', petugas.map((p) => rapiP(p)))),
      ],
      grafik: [
        { tipe: 'batang', judul: 'Gerbang hari ini', sumbuY: 'Jumlah santri', label: ['Keluar', 'Kembali', 'Ditolak'], seri: [{ n: 'Santri', warna: W.biru, nilai: [nj('keluar'), nj('kembali'), nj('ditolak')] }] },
        { tipe: 'lingkaran', judul: 'Titipan (di pos dan hari ini)', satuan: 'titipan', data: [{ n: 'Di pos', nilai: t.filter((x) => x.status === 'di_pos').length, warna: W.jingga },
          { n: 'Diambil hari ini', nilai: t.filter((x) => x.status === 'diambil' && hari(x.diambil_pada)).length, warna: W.hijau }, { n: 'Dikembalikan', nilai: t.filter((x) => x.status === 'dikembalikan' && hari(x.diambil_pada)).length, warna: W.abu }] },
      ] })
  }

  // 11. Ekskul
  {
    const sk = sesiKegiatan(sesi, 'ekskul'); const hadir = sk.ok.reduce((a, x) => a + (x.hadir || 0), 0); const anggota = sk.ok.reduce((a, x) => a + (x.anggota || 0), 0)
    const ikut = santri.filter((x) => x.ekskul); const tidakIkut = santri.filter((x) => !x.ekskul); const grup = saringGrup(d, 'ekskul', f)
    const berjalan = sk.s.filter((x) => x.status === 'terbuka')
    slide.push({ k: 'ekskul', judul: 'Ekskul', ikon: PhPersonSimpleRun, w: 'ekskul', sub: 'Kegiatan ekstrakurikuler hari ini',
      kartu: [
        d.grup ? kartuGrup('Jumlah ekskul', grup, PhPersonSimpleRun, 'ekskul', 'ekskul', 'Ekskul', 'Pembina', false, { jenis: 'ekskul' })
          : kartu('Jumlah ekskul', d.kelompok?.ekskul ?? 0, PhPersonSimpleRun, 'ekskul', 'Ekskul aktif', null),
        kartu('Santri peserta ekskul', ikut.length, PhStudent, 'santri', `${pr(ikut.length, santri.length)} dari santri aktif`, daftarS('Santri peserta ekskul', ikut.map((x) => rapiS(x, { ekskul: x.ekskul })), [['ekskul', 'Ekskul', 20]])),
        kartu('Belum ikut ekskul', tidakIkut.length, PhWarningCircle, 'hakakses', `${pr(tidakIkut.length, santri.length)} dari santri aktif`, daftarS('Santri belum ikut ekskul', tidakIkut.map((x) => rapiS(x)))),
        kartu('Sesi ekskul hari ini', sk.s.length, PhCalendarStar, 'agenda', `${grup.length ? pr(new Set(sk.s.map((x) => x.group_id)).size, grup.length) : '0%'} ekskul berkegiatan`, daftarSesi('Sesi ekskul hari ini', sk.s)),
        kartu('Sesi ekskul terlaksana', `${sk.ok.length}/${sk.s.length}`, PhCalendarCheck, 'jadwal', `${pr(sk.ok.length, sk.s.length)} · ${sk.telat.length} lewat, belum diisi`, daftarSesi('Sesi ekskul terlaksana', sk.ok)),
        kartu('Sedang berlangsung', berjalan.length, PhPlayCircle, 'presensi', `${pr(berjalan.length, sk.s.length)} dari sesi hari ini`, daftarSesi('Sesi ekskul berlangsung', berjalan)),
        kartu('Lewat, belum diisi', sk.telat.length, PhWarningCircle, 'klinik', `${pr(sk.telat.length, sk.s.length)} · perlu diingatkan ke pembina`, daftarSesi('Sesi ekskul lewat, belum diisi', sk.telat)),
        kartu('Kehadiran ekskul', pr(hadir, anggota), PhPercent, 'presensi', `${hadir} dari ${anggota} peserta pada sesi terlaksana`, daftarSesi('Kehadiran sesi ekskul', sk.ok)),
        kartu('Santri hadir', hadir, PhCheckCircle, 'santri', `${pr(hadir, anggota)} dari peserta sesi terlaksana`, daftarSesi('Kehadiran sesi ekskul', sk.ok)),
        kartu('Santri tidak hadir', Math.max(0, anggota - hadir), PhXCircle, 'klinik', `${pr(Math.max(0, anggota - hadir), anggota)} dari peserta sesi terlaksana`, daftarSesi('Kehadiran sesi ekskul', sk.ok)),
      ],
      grafik: [grafikPerKelompok('Kehadiran per ekskul (sesi terlaksana)', sk.ok.map((x) => ({ n: x.kelompok, h: x.hadir || 0, t: Math.max(0, (x.anggota || 0) - (x.hadir || 0)) }))), grafikStatusSesi('Status sesi ekskul', sk.s)] })
  }
  // 12. Perizinan santri dan pegawai
  {
    const iz = d.izin || { santri: [], pegawai: [] }; const sz = iz.santri.filter((x) => (!f.jk || x.jk === f.jk) && (!f.jenjang || x.jenjang === f.jenjang))
    const pz = iz.pegawai.filter((x) => !f.jk || x.jk === f.jk)
    const K_I = [['jenis', 'Jenis', 10], ['ket', 'Alasan', 22], ['waktu', 'Waktu', 16]]
    const bI = (x, waktu) => rapiS(x, { jenis: x.jenis === 'pulang' ? 'Pulang' : x.jenis === 'keluar' ? 'Keluar' : x.jenis, ket: x.alasan, waktu })
    const K_P = [['nama', 'Nama pegawai', 26], ['jenis', 'Jenis', 16], ['tgl', 'Tanggal', 22], ['ket', 'Alasan', 26]]
    const bP = (x) => ({ ...x, tgl: x.mulai === x.selesai ? x.mulai : `${x.mulai} s.d. ${x.selesai}`, ket: x.alasan || '–' })
    const menunggu = sz.filter((x) => x.menunggu); const keluar = sz.filter((x) => x.keluar_hari_ini); const kembali = sz.filter((x) => x.kembali_hari_ini); const telat = sz.filter((x) => x.terlambat)
    const berlaku = pz.filter((x) => x.berlaku); const tunggu = pz.filter((x) => x.status === 'menunggu'); const N = santri.length; const P = pegawai.filter((p) => p.status !== 'libur').length
    const luar = santri.filter((x) => x.luar); const dinas = pegawai.filter((p) => p.status === 'dinas_luar')
    const K_L = [['ket', 'Izin', 20], ['batas', 'Batas kembali', 14]]; const bL = (x) => rapiS(x, { ket: x.luar.alasan, batas: formatWaktu(x.luar.batas) })
    slide.push({ k: 'perizinan', judul: 'Perizinan', ikon: PhEnvelopeSimpleOpen, w: 'pengajuan', sub: 'Izin santri dan izin/cuti pegawai hari ini',
      kartu: [
        kartu('Santri di luar pondok', luar.length, PhDoorOpen, 'security', `${pr(luar.length, N)} dari santri aktif`, daftarS('Santri di luar pondok', luar.map(bL), K_L)),
        kartu('Izin pulang', luar.filter((x) => x.luar.jenis === 'pulang').length, PhHouse, 'santri', `${pr(luar.filter((x) => x.luar.jenis === 'pulang').length, N)} dari santri · belum kembali`, daftarS('Santri izin pulang', luar.filter((x) => x.luar.jenis === 'pulang').map(bL), K_L)),
        kartu('Izin keluar', luar.filter((x) => x.luar.jenis !== 'pulang').length, PhSignOut, 'shift', `${pr(luar.filter((x) => x.luar.jenis !== 'pulang').length, N)} dari santri · belum kembali`, daftarS('Santri izin keluar', luar.filter((x) => x.luar.jenis !== 'pulang').map(bL), K_L)),
        kartu('Izin santri menunggu', menunggu.length, PhHourglass, 'pengajuan', `${pr(menunggu.length, N)} dari santri · belum diputuskan`, daftarS('Izin santri menunggu keputusan', menunggu.map((x) => bI(x, formatWaktu(x.diajukan))), K_I)),
        kartu('Santri keluar hari ini', keluar.length, PhSignOut, 'jadwal', `${pr(keluar.length, N)} dari santri · tercatat keluar`, daftarS('Santri keluar hari ini', keluar.map((x) => bI(x, formatJam(x.keluar))), K_I)),
        kartu('Santri kembali hari ini', kembali.length, PhSignIn, 'presensi', `${pr(kembali.length, N)} dari santri · tercatat kembali`, daftarS('Santri kembali hari ini', kembali.map((x) => bI(x, formatJam(x.kembali))), K_I)),
        kartu('Terlambat kembali', telat.length, PhSiren, 'klinik', `${pr(telat.length, luar.length + kembali.length)} dari santri izin · lewat batas`, daftarS('Santri terlambat kembali', telat.map((x) => bI(x, 'Batas ' + formatWaktu(x.batas))), K_I)),
        kartu('Pegawai izin/cuti', berlaku.length, PhUserMinus, 'ekskul', `${pr(berlaku.length, P)} dari pegawai terjadwal`, { judul: 'Pegawai izin/cuti hari ini', kolom: K_P, baris: berlaku.map(bP) }),
        kartu('Pegawai dinas luar', dinas.length, PhAirplaneTilt, 'walikelas', `${pr(dinas.length, P)} dari pegawai terjadwal`, daftarP('Pegawai dinas luar', dinas.map((p) => rapiP(p)))),
        kartu('Pengajuan pegawai menunggu', tunggu.length, PhHourglass, 'agenda', 'Izin/cuti belum diputuskan', { judul: 'Pengajuan izin/cuti pegawai menunggu', kolom: K_P, baris: tunggu.map(bP) }),
      ],
      grafik: [{ tipe: 'batang', judul: 'Perizinan santri hari ini', sumbuY: 'Jumlah santri', label: ['Di luar', 'Menunggu', 'Keluar', 'Kembali', 'Terlambat'],
        seri: [{ n: 'Santri', warna: W.jingga, nilai: [luar.length, menunggu.length, keluar.length, kembali.length, telat.length] }] }] })
  }

  // 13. Laporan kejadian dan agenda
  {
    const lp = d.lapor || []; const hariIni = lp.filter((x) => x.hari_ini); const buka = lp.filter((x) => x.status !== 'selesai'); const desak = buka.filter((x) => x.mendesak)
    const st = (s) => lp.filter((x) => x.status === s)
    const ag = d.agenda || []; const ST_L = { terkirim: 'Terkirim', diterima: 'Diterima', ditindaklanjuti: 'Ditindaklanjuti', selesai: 'Selesai' }
    const K_L = [['jam', 'Waktu', 14], ['kategori', 'Kategori', 12], ['lokasi', 'Lokasi', 20], ['uraian', 'Uraian', 34], ['status', 'Status', 14]]
    const bL = (x) => ({ ...x, jam: formatWaktu(x.waktu), lokasi: x.lokasi || '–', status: (ST_L[x.status] || x.status) + (x.mendesak ? ' · mendesak' : '') })
    const dL = (judul, x) => ({ judul, kolom: K_L, baris: x.map(bL) })
    const jamKini = d.lalu ? null : formatJam(d.waktu).replace('.', ':')
    const jamAg = (x) => (x.jam_mulai ? String(x.jam_mulai).slice(0, 5) : null)
    const sehari = ag.filter((x) => !x.jam_mulai); const berjalan = jamKini ? ag.filter((x) => jamAg(x) && jamAg(x) <= jamKini && (!x.jam_selesai || String(x.jam_selesai).slice(0, 5) > jamKini)) : []
    const dA = (judul, x) => ({ judul, kolom: [['jam', 'Jam', 12], ['judul', 'Agenda', 36], ['lokasi', 'Tempat', 20], ['sasaran', 'Peserta', 22]],
      baris: x.map((y) => ({ ...y, jam: y.jam_mulai ? `${String(y.jam_mulai).slice(0, 5)}${y.jam_selesai ? '–' + String(y.jam_selesai).slice(0, 5) : ''}` : 'Sehari', lokasi: y.lokasi || '–', sasaran: y.sasaran || 'Semua' })) })
    slide.push({ k: 'lapor', judul: 'Laporan dan Agenda', ikon: PhMegaphone, w: 'laporan', sub: 'Laporan kejadian (menu Lapor) dan agenda pondok hari ini',
      kartu: [
        kartu('Laporan masuk hari ini', hariIni.length, PhMegaphone, 'laporan', `${pr(hariIni.length, lp.length)} dari laporan yang dipantau`, dL('Laporan masuk hari ini', hariIni)),
        kartu('Laporan belum selesai', buka.length, PhHourglass, 'pengajuan', `${pr(buka.length, lp.length)} · terkirim, diterima, atau ditindaklanjuti`, dL('Laporan belum selesai', buka)),
        kartu('Laporan mendesak', desak.length, PhSiren, 'klinik', `${pr(desak.length, buka.length)} dari laporan belum selesai`, dL('Laporan mendesak belum selesai', desak)),
        kartu('Belum diterima', st('terkirim').length, PhEnvelopeSimpleOpen, 'agenda', `${pr(st('terkirim').length, lp.length)} · menunggu unit penerima`, dL('Laporan belum diterima', st('terkirim'))),
        kartu('Diterima', st('diterima').length, PhCheckCircle, 'jadwal', `${pr(st('diterima').length, lp.length)} · belum ditindaklanjuti`, dL('Laporan diterima', st('diterima'))),
        kartu('Ditindaklanjuti', st('ditindaklanjuti').length, PhListChecks, 'ekskul', `${pr(st('ditindaklanjuti').length, lp.length)} · sedang dikerjakan`, dL('Laporan ditindaklanjuti', st('ditindaklanjuti'))),
        kartu('Selesai', st('selesai').length, PhMedal, 'presensi', `${pr(st('selesai').length, lp.length)} dari laporan yang dipantau`, dL('Laporan selesai', st('selesai'))),
        kartu('Agenda hari ini', ag.length, PhCalendarStar, 'agenda', ag.slice(0, 2).map((x) => x.judul).join(' · ') || 'Tidak ada agenda', dA('Agenda hari ini', ag)),
        kartu('Agenda berlangsung', berjalan.length, PhPlayCircle, 'presensi', d.lalu ? 'Hanya tersedia pada hari berjalan' : berjalan.map((x) => x.judul).join(' · ') || 'Tidak ada saat ini', dA('Agenda sedang berlangsung', berjalan)),
        kartu('Agenda sepanjang hari', sehari.length, PhCalendarCheck, 'jadwal', `${pr(sehari.length, ag.length)} dari agenda hari ini`, dA('Agenda sepanjang hari', sehari)),
      ],
      grafik: [{ tipe: 'lingkaran', judul: 'Status laporan', satuan: 'laporan', data: [{ n: 'Terkirim', nilai: st('terkirim').length, warna: W.jingga },
        { n: 'Diterima', nilai: st('diterima').length, warna: W.biru }, { n: 'Ditindaklanjuti', nilai: st('ditindaklanjuti').length, warna: W.ungu },
        { n: 'Selesai', nilai: st('selesai').length, warna: W.hijau }] }] })
  }

  // ===================== Slide unit kerja (v1.4) =====================
  const rp = (n) => { const x = Number(n) || 0; return x >= 1e9 ? `Rp\u00a0${(x / 1e9).toFixed(1).replace('.', ',')}\u00a0M` : x >= 1e6 ? `Rp\u00a0${(x / 1e6).toFixed(1).replace('.', ',')}\u00a0jt` : `Rp\u00a0${x.toLocaleString('id-ID')}` }
  const rpPenuh = (n) => `Rp ${(Number(n) || 0).toLocaleString('id-ID')}`
  const petaPeg = Object.fromEntries(d.pegawai.map((p) => [p.id, p])); const T = pegawai.filter((p) => p.status !== 'libur').length
  const KODE_ABSEN = { I: 'Izin', S: 'Sakit', A: 'Alfa', B: 'Bolos', T: 'Terlambat' }

  // Pondok secara umum
  {
    const ks = kelasSantri(santri); const luar = santri.filter((x) => x.luar); const sakit = santri.filter((x) => x.sakit); const malam = sesiMalam(sesiSantri(santri, 'asrama:'))
    const hs = halaqahSantri(santri); const hadir = pegawai.filter(hadirPeg); const bertugas = pegawai.filter((p) => p.bertugas)
    const g = (d.grup || []).filter((x) => !f.jk || !x.jk || x.jk === f.jk); const nJ = (j) => g.filter((x) => x.jenis === j).length
    const ag = d.agenda || []; const pg = d.umum?.pengumuman || []; const lpBuka = (d.lapor || []).filter((x) => x.status !== 'selesai')
    slide.push({ k: 'pondok', judul: 'Pondok', ikon: PhHouseLine, w: 'beranda', sub: `Gambaran umum pondok hari ini${d.umum?.libur ? ' · libur sekolah' : ''}`,
      kartu: [
        kartu('Santri aktif', santri.length, PhStudent, 'santri', ketLP(santri), daftarS('Santri aktif', santri.map((x) => rapiS(x)), [['halaqah', 'Halaqah', 18]])),
        kartu('Santri di pondok', santri.length - luar.length, PhHouse, 'presensi', `${pr(santri.length - luar.length, santri.length)} · ${luar.length} di luar pondok`, daftarS('Santri di luar pondok', luar.map((x) => rapiS(x, { ket: x.luar.alasan })), [['ket', 'Izin', 22]])),
        kartu('Kehadiran kelas', pr(ks.hadir, ks.kelas.length), PhChalkboardTeacher, 'jadwal', `${ks.hadir} dari ${ks.kelas.length} santri berkelas`, daftarS('Santri tidak hadir di kelas', ks.tidak.map((x) => rapiS(x, { ket: `Tidak hadir ${x.kelas_tidak} dari ${x.kelas_sesi} sesi` })), [['ket', 'Keterangan', 20]])),
        kartu('Kehadiran halaqah', pr(hs.hadir.length, hs.ada.length), PhBookOpenText, 'tahfizh', `${hs.hadir.length} dari ${hs.ada.length} santri berhalaqah`, daftarS('Santri tidak hadir di halaqah', hs.tidak.map((x) => rapiS(x, { ket: ketHalaqah(x) })), [['ket', 'Keterangan', 22]])),
        kartu('Asrama malam', malam ? pr(malam.hadir.length, malam.ada.length) : '–', PhMoon, 'musyrif', malam ? `${malam.hadir.length} dari ${malam.ada.length} santri di asrama` : 'Sesi asrama belum diisi', malam ? kartuSesiSantri(malam, PhMoon, 'musyrif', '').daftar : null),
        kartu('Santri sakit', sakit.length, PhFirstAidKit, 'klinik', `${pr(sakit.length, santri.length)} dari santri aktif`, daftarS('Santri sakit', sakit.map((x) => rapiS(x, { ket: x.sakit })), [['ket', 'Keterangan', 20]])),
        kartu('Pegawai hadir', `${hadir.length}/${T}`, PhUserCheck, 'pegawai', `${pr(hadir.length, T)} dari pegawai terjadwal`, daftarP('Pegawai hadir', hadir.map((p) => rapiP(p)))),
        kartu('Pegawai sementara bertugas', bertugas.length, PhBriefcase, 'walikelas', d.lalu ? 'Hanya tersedia pada hari berjalan' : `${pr(bertugas.length, T)} · ${ringkasSesi(bertugas) || 'tidak ada sesi berjalan'}`, daftarP('Pegawai sementara bertugas', bertugas.map((p) => rapiP(p, { ket: `Sesi ${p.sesi_kini}` })))),
        kartu('Agenda hari ini', ag.length, PhCalendarStar, 'agenda', ag.slice(0, 2).map((x) => x.judul).join(' · ') || 'Tidak ada agenda',
          { judul: 'Agenda hari ini', kolom: [['jam', 'Jam', 12], ['judul', 'Agenda', 40], ['lokasi', 'Tempat', 22]], baris: ag.map((x) => ({ ...x, jam: x.jam_mulai ? String(x.jam_mulai).slice(0, 5) : 'Sehari', lokasi: x.lokasi || '–' })) }),
        kartu('Pengumuman aktif', pg.length, PhMegaphone, 'laporan', `${pg.filter((x) => x.penting).length} penting · ${lpBuka.length} laporan kejadian belum selesai`,
          { judul: 'Pengumuman aktif', kolom: [['judul', 'Pengumuman', 50], ['sasaran', 'Sasaran', 26], ['sampai', 'Tampil sampai', 14]], baris: pg.map((x) => ({ ...x, judul: x.judul + (x.penting ? ' (penting)' : ''), sasaran: x.sasaran || 'Semua', sampai: x.sampai || '–' })) }),
      ],
      grafik: [
        { tipe: 'batang', judul: 'Kehadiran hari ini (%)', sumbuY: 'Persen', label: ['Santri di kelas', 'Santri di halaqah', 'Santri di asrama', 'Pegawai'],
          seri: [{ n: 'Hadir (%)', warna: W.hijau, nilai: [persen(ks.hadir, ks.kelas.length), persen(hs.hadir.length, hs.ada.length), malam ? persen(malam.hadir.length, malam.ada.length) : 0, persen(hadir.length, T)] }] },
        { tipe: 'lingkaran', judul: `Kelompok santri aktif (${g.length})`, satuan: 'kelompok', data: [{ n: 'Kelas', nilai: nJ('kelas'), warna: W.biru }, { n: 'Kamar', nilai: nJ('kamar'), warna: W.teal },
          { n: 'Halaqah', nilai: nJ('halaqah'), warna: W.emas }, { n: 'Ekskul', nilai: nJ('ekskul'), warna: W.ungu }] },
      ] })
  }

  // Wali kelas
  {
    const grup = saringGrup(d, 'kelas', f); const ber = grup.filter((g) => g.pengasuh); const idWali = [...new Set(grup.flatMap((g) => g.pengasuh_ids || []))]
    const wali = idWali.map((id) => petaPeg[id]).filter((p) => p && p.status !== 'libur'); const waliHadir = wali.filter(hadirPeg)
    const sk = sesiKegiatan(sesi, 'kelas'); const ks = kelasSantri(santri); const kh = d.kelas_harian || {}
    const absen = (kh.absen || []).filter((x) => idSantri.has(x.id)); const byKode = (ks2) => [...new Map(absen.filter((x) => ks2.includes(x.kode)).map((x) => [x.id, x])).values()]
    const izinSakit = byKode(['I', 'S']); const alfa = byKode(['A', 'B']); const alfaBulan = (kh.alfa_bulan || []).filter((x) => idSantri.has(x.id))
    const bS = (x, ket) => rapiS(petaSantri[x.id], { ket })
    const perKelas = {}; for (const x of ks.kelas) { const n = x.kelas || '–'; perKelas[n] = perKelas[n] || { n, h: 0, t: 0 }; x.kelas_tidak >= x.kelas_sesi ? perKelas[n].t++ : perKelas[n].h++ }
    slide.push({ k: 'walikelas', judul: 'Wali Kelas', ikon: PhChalkboard, w: 'walikelas', sub: 'Perwalian kelas: absensi harian, ketidakhadiran, dan catatan wali',
      kartu: [
        kartuGrup('Jumlah kelas', grup, PhUsersFour, 'laporan', 'kelas', 'Kelas', 'Wali kelas', true, { jenis: 'kelas', jenjang: f.jenjang || null }),
        kartu('Wali kelas ditetapkan', `${ber.length}/${grup.length}`, PhChalkboard, 'walikelas', `${pr(ber.length, grup.length)} · ${grup.length - ber.length} kelas belum ada wali`, daftarGrup('Kelas dan wali kelas', grup, 'Kelas', 'Wali kelas', true)),
        kartu('Wali kelas hadir', `${waliHadir.length}/${wali.length}`, PhUserCheck, 'pegawai', `${pr(waliHadir.length, wali.length)} dari wali kelas terjadwal`, daftarP('Wali kelas hari ini', wali.map((p) => rapiP(p)))),
        kartu('Absensi kelas terisi', `${sk.ok.length}/${sk.s.length}`, PhCalendarCheck, 'jadwal', `${pr(sk.ok.length, sk.s.length)} dari sesi kelas hari ini`, daftarSesi('Absensi kelas hari ini', sk.s)),
        kartu('Absensi lewat, belum diisi', sk.telat.length, PhWarningCircle, 'klinik', `${pr(sk.telat.length, sk.s.length)} · perlu diingatkan ke wali kelas`, daftarSesi('Absensi kelas lewat, belum diisi', sk.telat)),
        kartu('Kehadiran santri di kelas', pr(ks.hadir, ks.kelas.length), PhPercent, 'presensi', `${ks.hadir} dari ${ks.kelas.length} santri`, daftarS('Santri tidak hadir di kelas', ks.tidak.map((x) => rapiS(x, { ket: `Tidak hadir ${x.kelas_tidak} dari ${x.kelas_sesi} sesi` })), [['ket', 'Keterangan', 20]])),
        kartu('Izin atau sakit', izinSakit.length, PhFirstAidKit, 'klinik', `${pr(izinSakit.length, ks.kelas.length)} dari santri berkelas`, daftarS('Santri izin/sakit di kelas', izinSakit.map((x) => bS(x, `${KODE_ABSEN[x.kode]}${x.ket ? ': ' + x.ket : ''}`)), [['ket', 'Keterangan', 22]])),
        kartu('Alfa atau bolos', alfa.length, PhUserMinus, 'pengajuan', `${pr(alfa.length, ks.kelas.length)} dari santri berkelas`, daftarS('Santri alfa/bolos di kelas', alfa.map((x) => bS(x, `${KODE_ABSEN[x.kode]} · ${x.sesi}`)), [['ket', 'Keterangan', 22]])),
        kartu('Alfa/bolos ≥3× bulan ini', alfaBulan.length, PhSiren, 'klinik', `${pr(alfaBulan.length, ks.kelas.length)} · perlu pembinaan wali kelas`, daftarS('Santri alfa/bolos 3 kali atau lebih bulan ini', alfaBulan.map((x) => bS(x, `${x.n} kali`)), [['ket', 'Jumlah', 12]])),
        kartu('Catatan wali rapor', `${kh.catatan_wali ?? 0}/${santri.length}`, PhNotebook, 'rapor', `${pr(kh.catatan_wali || 0, santri.length)} santri · semester ${kh.semester || '–'}`, null),
      ],
      grafik: [grafikPerKelompok('Kehadiran santri per kelas', Object.values(perKelas).sort((a, b) => a.n.localeCompare(b.n, 'id', { numeric: true }))),
        { tipe: 'lingkaran', judul: 'Ketidakhadiran di kelas hari ini', data: ['I', 'S', 'A', 'B', 'T'].map((k, i) => ({ n: KODE_ABSEN[k], nilai: absen.filter((x) => x.kode === k).length, warna: [W.biru, W.ungu, W.jingga, W.merah, W.emas][i] })) }] })
  }

  // Guru mapel
  {
    const mp = d.mapel || {}; const pel = pelajaranJk.filter((x) => !f.jenjang || x.jenjang === f.jenjang)
    const guru = (mp.guru || []).map((id) => petaPeg[id]).filter((p) => p && (!f.jk || p.jk === f.jk)); const gH = guru.filter(hadirPeg)
    const ok = pel.filter((x) => x.status === 'terlaksana'); const tidak = pel.filter((x) => x.status === 'tidak_terlaksana'); const belum = pel.filter((x) => x.status === 'belum_diisi')
    const jalan = pel.filter((x) => ['berlangsung', 'akan_datang'].includes(x.status)); const guruBelum = [...new Set(belum.map((x) => x.guru))]
    const ab = (mp.absen || []).filter((x) => idSantri.has(x.id) && x.kode !== 'T'); const abS = [...new Set(ab.map((x) => x.id))]; const bl = mp.bulan || {}
    const perKelas = {}; for (const x of pel) { perKelas[x.kelas] = perKelas[x.kelas] || { n: x.kelas, h: 0, t: 0 }; x.status === 'terlaksana' ? perKelas[x.kelas].h++ : perKelas[x.kelas].t++ }
    slide.push({ k: 'gurumapel', judul: 'Guru Mapel', ikon: PhPresentationChart, w: 'gurumapel', sub: 'Keterlaksanaan pelajaran, jurnal mengajar, dan kehadiran guru hari ini',
      kartu: [
        kartu('Guru mengajar hari ini', guru.length, PhUsersThree, 'gurumapel', `${pr(guru.length, T)} dari pegawai terjadwal`, daftarP('Guru mengajar hari ini', guru.map((p) => rapiP(p)))),
        kartu('Guru hadir', `${gH.length}/${guru.length}`, PhUserCheck, 'pegawai', `${pr(gH.length, guru.length)} dari guru mengajar hari ini`, daftarP('Kehadiran guru mengajar', guru.map((p) => rapiP(p)))),
        kartu('Jam pelajaran hari ini', pel.length, PhClock, 'jadwal', `${new Set(pel.map((x) => x.kelas)).size} kelas · ${new Set(pel.map((x) => x.mapel)).size} mapel`, daftarJp('Jam pelajaran hari ini', pel)),
        kartu('JP terlaksana', `${ok.length}/${pel.length}`, PhCheckCircle, 'presensi', `${pr(ok.length, pel.length)} dari JP hari ini`, daftarJp('JP terlaksana hari ini', ok)),
        kartu('JP tidak terlaksana', tidak.length, PhXCircle, 'klinik', `${pr(tidak.length, pel.length)} dari JP hari ini`, daftarJp('JP tidak terlaksana hari ini', tidak)),
        kartu('Jurnal belum diisi', belum.length, PhNotePencil, 'pengajuan', `${pr(belum.length, pel.length)} · jam sudah lewat`, daftarJp('JP lewat, jurnal belum diisi', belum)),
        kartu('Guru belum isi jurnal', guruBelum.length, PhUserList, 'agenda', `${pr(guruBelum.length, guru.length)} dari guru mengajar hari ini`, { judul: 'Guru belum mengisi jurnal hari ini', kolom: [['guru', 'Guru', 40], ['jp', 'JP belum diisi', 50]], baris: guruBelum.map((g) => ({ guru: g, jp: belum.filter((x) => x.guru === g).map((x) => `${x.mapel} ${x.kelas} (${x.jp})`).join(', ') })) }),
        kartu('Berlangsung atau akan datang', jalan.length, PhPlayCircle, 'hakakses', `${pr(jalan.length, pel.length)} dari JP hari ini`, daftarJp('JP berlangsung atau akan datang', jalan)),
        kartu('Santri tidak hadir di pelajaran', abS.length, PhUserMinus, 'klinik', `${pr(abS.length, santri.length)} dari santri · ${mp.diabsen ?? 0} JP diabsen guru`,
          daftarS('Santri tidak hadir di pelajaran', ab.map((x) => rapiS(petaSantri[x.id], { ket: `${KODE_ABSEN[x.kode]} · ${x.mapel} (${x.jp})`, guru: x.guru })), [['ket', 'Keterangan', 24], ['guru', 'Guru', 18]])),
        kartu('Jurnal bulan ini terlaksana', pr(bl.terlaksana || 0, bl.total || 0), PhChartLine, 'gaji', `${bl.terlaksana || 0} dari ${bl.total || 0} jurnal · ${pr(bl.rinci || 0, bl.total || 0)} rinci (bab)`, null),
      ],
      grafik: [grafikPerKelompok('Keterlaksanaan JP per kelas', Object.values(perKelas).sort((a, b) => String(a.n).localeCompare(String(b.n), 'id', { numeric: true })), 'Jumlah JP'),
        { tipe: 'lingkaran', judul: 'Status jam pelajaran hari ini', satuan: 'JP', data: [{ n: 'Terlaksana', nilai: ok.length, warna: W.hijau }, { n: 'Tidak terlaksana', nilai: tidak.length, warna: W.merah },
          { n: 'Jurnal belum diisi', nilai: belum.length, warna: W.jingga }, { n: 'Berlangsung/akan datang', nilai: jalan.length, warna: W.abu }] }] })
  }

  // Dokumen
  {
    const dk = d.dokumen || {}; const tb = dk.terbit || []; const hariIni = tb.filter((x) => x.hari_ini); const mt = dk.menunggu_ttd || []; const bk = dk.berkas || []
    const target = bk.reduce((a, x) => a + (x.target || 0), 0); const dibuka = bk.reduce((a, x) => a + (x.dibuka || 0), 0)
    const batas30 = new Date(new Date(`${d.tanggal}T12:00:00Z`).getTime() + 30 * 864e5).toISOString().slice(0, 10); const habis = bk.filter((x) => x.berlaku_sampai && x.berlaku_sampai <= batas30)
    const K_D = [['jenis', 'Jenis', 20], ['nomor', 'Nomor', 22], ['perihal', 'Perihal/subjek', 34], ['waktu', 'Terbit', 14]]
    const bD = (x) => ({ ...x, nomor: x.nomor || '–', perihal: [x.perihal, x.subjek].filter(Boolean).join(' · ') || '–', waktu: formatWaktu(x.waktu) })
    const K_B = [['judul', 'Berkas', 34], ['kategori', 'Kategori', 12], ['sasaran', 'Sasaran', 20], ['buka', 'Dibuka', 12], ['sampai', 'Berlaku sampai', 14]]
    const bB = (x) => ({ ...x, sasaran: x.sasaran || 'Semua', buka: `${x.dibuka}/${x.target}`, sampai: x.berlaku_sampai || '–' })
    const perJenis = {}; for (const x of tb) perJenis[x.jenis] = (perJenis[x.jenis] || 0) + 1
    const jenisTop = Object.entries(perJenis).sort((a, b) => b[1] - a[1]).slice(0, 8)
    slide.push({ k: 'dokumen', judul: 'Dokumen', ikon: PhFileText, w: 'berkas', sub: 'Dokumen resmi bernomor (Cek Keabsahan) dan berkas untuk pegawai',
      kartu: [
        kartu('Dokumen sah', dk.sah ?? 0, PhSealCheck, 'presensi', 'Terdaftar dan dapat dicek keasliannya', null),
        kartu('Terbit hari ini', hariIni.length, PhFileText, 'berkas', `${pr(hariIni.length, tb.length)} dari terbitan bulan ini`, { judul: 'Dokumen terbit hari ini', kolom: K_D, baris: hariIni.map(bD) }),
        kartu('Terbit bulan ini', tb.length, PhFiles, 'jadwal', `${Object.keys(perJenis).length} jenis dokumen`, { judul: 'Dokumen terbit bulan ini', kolom: K_D, baris: tb.map(bD) }),
        kartu('Menunggu tanda tangan', mt.length, PhSignature, 'pengajuan', 'Penanda tangan belum menyetujui', { judul: 'Dokumen menunggu tanda tangan', kolom: [['jenis', 'Jenis', 20], ['perihal', 'Perihal', 34], ['penanda', 'Penanda tangan', 24], ['jabatan', 'Jabatan', 20]], baris: mt.map((x) => ({ ...x, perihal: x.perihal || x.nomor || '–', jabatan: x.jabatan || '–' })) }),
        kartu('Draf dokumen', dk.draf ?? 0, PhNotePencil, 'agenda', 'Belum disahkan', null),
        kartu('Dicabut/direvisi bulan ini', dk.dicabut_bulan ?? 0, PhProhibit, 'klinik', 'Tidak berlaku lagi', null),
        kartu('Dicek keabsahan hari ini', dk.dicek_hari ?? 0, PhShieldCheck, 'security', 'Dokumen yang dipindai/diperiksa', null),
        kartu('Berkas pegawai aktif', bk.length, PhFolderOpen, 'berkas', `${bk.filter((x) => x.kategori === 'sk').length} SK · ${bk.filter((x) => x.kategori === 'formulir').length} formulir`, { judul: 'Berkas pegawai aktif', kolom: K_B, baris: bk.map(bB) }),
        kartu('Berkas belum dibuka', target - dibuka, PhEnvelopeSimpleOpen, 'pengajuan', `${pr(target - dibuka, target)} dari ${target} penerima`, { judul: 'Berkas yang belum dibuka semua penerima', kolom: K_B, baris: bk.filter((x) => x.dibuka < x.target).map(bB) }),
        kartu('Berkas berakhir ≤30 hari', habis.length, PhHourglass, 'klinik', `${pr(habis.length, bk.length)} dari berkas aktif`, { judul: 'Berkas berakhir dalam 30 hari', kolom: K_B, baris: habis.map(bB) }),
      ],
      grafik: [{ tipe: 'batang', judul: 'Dokumen terbit bulan ini per jenis', sumbuY: 'Jumlah dokumen', label: jenisTop.map((x) => x[0]), seri: [{ n: 'Dokumen', warna: W.biru, nilai: jenisTop.map((x) => x[1]) }] },
        { tipe: 'lingkaran', judul: 'Berkas pegawai dibuka penerima', satuan: 'penerima', data: [{ n: 'Sudah dibuka', nilai: dibuka, warna: W.hijau }, { n: 'Belum dibuka', nilai: target - dibuka, warna: W.jingga }] }] })
  }

  // Persuratan
  {
    const s = d.surat || {}; const ms = s.masuk || []; const ds = s.disposisi || []; const kl = s.keluar || []
    const buka = ms.filter((x) => ['diteruskan', 'didisposisi'].includes(x.status)); const penting = buka.filter((x) => ['penting', 'segera'].includes(x.sifat))
    const ST_M = { diteruskan: 'Diteruskan', didisposisi: 'Didisposisi', selesai: 'Selesai', diarsipkan: 'Diarsipkan' }
    const ST_K = { draf: 'Draf', diperiksa: 'Diperiksa', menunggu_ttd: 'Menunggu tanda tangan', terbit: 'Terbit', ditolak: 'Ditolak', dibatalkan: 'Dibatalkan', dicabut: 'Dicabut', direvisi: 'Direvisi' }
    const K_M = [['agenda', 'No. agenda', 14], ['tgl', 'Diterima', 11], ['pengirim', 'Pengirim', 22], ['perihal', 'Perihal', 30], ['st', 'Status', 14]]
    const bM = (x) => ({ ...x, tgl: x.tanggal, perihal: x.perihal + (x.sifat !== 'biasa' ? ` (${x.sifat})` : ''), st: ST_M[x.status] || x.status })
    const K_DS = [['perihal', 'Perihal', 30], ['dari', 'Dari', 20], ['kepada', 'Kepada', 20], ['st', 'Status', 12], ['batas', 'Batas', 11]]
    const bDs = (x) => ({ ...x, st: x.status === 'baru' ? 'Belum dibaca' : x.status === 'dibaca' ? 'Dibaca' : 'Selesai', batas: x.batas || '–' })
    const K_K = [['jenis', 'Jenis', 18], ['nomor', 'Nomor', 20], ['perihal', 'Perihal', 30], ['kepada', 'Kepada', 18], ['st', 'Status', 14]]
    const bK = (x) => ({ ...x, nomor: x.nomor || '–', kepada: x.kepada || '–', st: ST_K[x.status] || x.status })
    const proses = kl.filter((x) => ['draf', 'diperiksa', 'menunggu_ttd'].includes(x.status)); const tHari = kl.filter((x) => x.terbit_hari); const tBulan = kl.filter((x) => x.terbit_bulan && x.status === 'terbit')
    slide.push({ k: 'surat', judul: 'Persuratan', ikon: PhEnvelopeSimple, w: 'tatausaha', sub: 'Surat masuk, disposisi, dan surat keluar',
      kartu: [
        kartu('Surat masuk hari ini', ms.filter((x) => x.hari_ini).length, PhTray, 'tatausaha', 'Tercatat di agenda surat masuk', { judul: 'Surat masuk hari ini', kolom: K_M, baris: ms.filter((x) => x.hari_ini).map(bM) }),
        kartu('Surat masuk bulan ini', ms.filter((x) => x.bulan_ini).length, PhEnvelopeSimple, 'jadwal', `${ms.filter((x) => x.bulan_ini && x.status === 'selesai').length} sudah selesai`, { judul: 'Surat masuk bulan ini', kolom: K_M, baris: ms.filter((x) => x.bulan_ini).map(bM) }),
        kartu('Surat masuk belum selesai', buka.length, PhHourglass, 'pengajuan', 'Diteruskan atau didisposisi', { judul: 'Surat masuk belum selesai', kolom: K_M, baris: buka.map(bM) }),
        kartu('Penting/segera belum selesai', penting.length, PhSiren, 'klinik', `${pr(penting.length, buka.length)} dari surat belum selesai`, { judul: 'Surat penting/segera belum selesai', kolom: K_M, baris: penting.map(bM) }),
        kartu('Disposisi berjalan', ds.length, PhArrowsLeftRight, 'agenda', 'Belum dilaporkan selesai', { judul: 'Disposisi berjalan', kolom: K_DS, baris: ds.map(bDs) }),
        kartu('Disposisi belum dibaca', ds.filter((x) => x.status === 'baru').length, PhEnvelopeSimpleOpen, 'pengajuan', `${pr(ds.filter((x) => x.status === 'baru').length, ds.length)} dari disposisi berjalan`, { judul: 'Disposisi belum dibaca', kolom: K_DS, baris: ds.filter((x) => x.status === 'baru').map(bDs) }),
        kartu('Disposisi lewat batas', ds.filter((x) => x.lewat).length, PhWarningCircle, 'klinik', `${pr(ds.filter((x) => x.lewat).length, ds.length)} dari disposisi berjalan`, { judul: 'Disposisi lewat batas waktu', kolom: K_DS, baris: ds.filter((x) => x.lewat).map(bDs) }),
        kartu('Surat keluar terbit hari ini', tHari.length, PhPaperPlaneTilt, 'presensi', 'Bernomor dan sah', { judul: 'Surat keluar terbit hari ini', kolom: K_K, baris: tHari.map(bK) }),
        kartu('Surat keluar bulan ini', tBulan.length, PhFiles, 'santri', 'Terbit bulan ini', { judul: 'Surat keluar terbit bulan ini', kolom: K_K, baris: tBulan.map(bK) }),
        kartu('Surat keluar dalam proses', proses.length, PhSignature, 'walikelas', `${proses.filter((x) => x.status === 'menunggu_ttd').length} menunggu tanda tangan · ${proses.filter((x) => x.status === 'draf').length} draf`, { judul: 'Surat keluar dalam proses', kolom: K_K, baris: proses.map(bK) }),
      ],
      grafik: [{ tipe: 'lingkaran', judul: 'Surat masuk bulan ini menurut status', satuan: 'surat', data: Object.entries(ST_M).map(([k, n], i) => ({ n, nilai: ms.filter((x) => x.bulan_ini && x.status === k).length, warna: [W.jingga, W.ungu, W.hijau, W.abu][i] })) },
        { tipe: 'batang', judul: 'Surat keluar menurut status', sumbuY: 'Jumlah surat', label: ['Draf', 'Diperiksa', 'Menunggu tanda tangan', 'Terbit bulan ini'],
          seri: [{ n: 'Surat', warna: W.biru, nilai: [kl.filter((x) => x.status === 'draf').length, kl.filter((x) => x.status === 'diperiksa').length, kl.filter((x) => x.status === 'menunggu_ttd').length, tBulan.length] }] }] })
  }

  // Keuangan santri (hanya pemegang hak lihat keuangan)
  if (d.keuangan?.boleh) {
    const k = d.keuangan; const sah = (k.bayar || []).filter((x) => x.status === 'sah'); const hariIni = sah.filter((x) => x.tanggal === d.tanggal); const batal = (k.bayar || []).filter((x) => x.status === 'batal')
    const jml = (x) => x.reduce((a, y) => a + Number(y.jumlah || 0), 0); const tg = k.tagih_bulan || {}; const tk = (k.tunggak || []).filter((x) => !f.jk || x.jk === f.jk)
    const sisaTunggak = tk.reduce((a, x) => a + Number(x.sisa || 0), 0)
    const K_P = [['waktu', 'Waktu', 14], ['nomor', 'Nomor', 16], ['nama', 'Santri', 24], ['kelas', 'Kelas', 8], ['cara', 'Cara', 10], ['jml', 'Jumlah', 16]]
    const bP = (x) => ({ ...x, waktu: formatWaktu(x.waktu), nomor: x.nomor || '–', kelas: x.kelas || '–', cara: x.cara === 'transfer' ? 'Transfer' : 'Tunai', jml: rpPenuh(x.jumlah) })
    const K_T = [['nis', 'NIS', 10], ['nama', 'Santri', 26], ['kelas', 'Kelas', 8], ['n', 'Tagihan', 8], ['sisa', 'Sisa tunggakan', 18], ['tertua', 'Jatuh tempo tertua', 16]]
    const hariBulan = [...new Set(sah.map((x) => x.tanggal))].sort()
    slide.push({ k: 'keuangan', judul: 'Keuangan', ikon: PhCashRegister, w: 'keuangan', sub: 'Tagihan dan pembayaran santri',
      kartu: [
        kartu('Penerimaan hari ini', rp(jml(hariIni)), PhCoins, 'keuangan', `${hariIni.length} transaksi · ${rpPenuh(jml(hariIni))}`, { judul: 'Pembayaran hari ini', kolom: K_P, baris: hariIni.map(bP) }),
        kartu('Transaksi hari ini', hariIni.length, PhReceipt, 'presensi', `${hariIni.filter((x) => x.cara === 'tunai').length} tunai · ${hariIni.filter((x) => x.cara === 'transfer').length} transfer`, { judul: 'Pembayaran hari ini', kolom: K_P, baris: hariIni.map(bP) }),
        kartu('Penerimaan bulan ini', rp(jml(sah)), PhChartLine, 'gaji', `${sah.length} transaksi · ${rpPenuh(jml(sah))}`, { judul: 'Pembayaran bulan ini', kolom: K_P, baris: sah.map(bP) }),
        kartu('Tagihan bulan ini', rp(tg.nominal), PhInvoice, 'jadwal', `${tg.n || 0} tagihan · ${rpPenuh(tg.nominal)}`, null),
        kartu('Tertagih bulan ini', pr(Number(tg.dibayar || 0), Number(tg.nominal || 0)), PhPercent, 'presensi', `${rp(tg.dibayar)} dari ${rp(tg.nominal)}`, null),
        kartu('Tagihan lunas bulan ini', `${tg.lunas || 0}/${tg.n || 0}`, PhCheckCircle, 'santri', `${pr(tg.lunas || 0, tg.n || 0)} dari tagihan bulan ini`, null),
        kartu('Tunggakan', rp(sisaTunggak), PhWarningCircle, 'klinik', `Lewat jatuh tempo · ${rpPenuh(sisaTunggak)}`, { judul: 'Santri menunggak', kolom: K_T, baris: tk.map((x) => ({ ...x, kelas: x.kelas || '–', sisa: rpPenuh(x.sisa), tertua: x.tertua })) }),
        kartu('Santri menunggak', tk.length, PhUserMinus, 'pengajuan', `${pr(tk.length, santri.length)} dari santri aktif`, { judul: 'Santri menunggak', kolom: K_T, baris: tk.map((x) => ({ ...x, kelas: x.kelas || '–', sisa: rpPenuh(x.sisa), tertua: x.tertua })) }),
        kartu('Jatuh tempo 7 hari', rp(k.tempo7?.sisa), PhCalendarCheck, 'agenda', `${k.tempo7?.n || 0} tagihan belum lunas`, null),
        kartu('Pembayaran dibatalkan', batal.length, PhProhibit, 'hakakses', `Bulan ini · ${rpPenuh(jml(batal))}`, { judul: 'Pembayaran dibatalkan bulan ini', kolom: K_P, baris: batal.map(bP) }),
      ],
      grafik: [{ tipe: 'batang', judul: 'Penerimaan per hari bulan ini (juta rupiah)', sumbuY: 'Juta rupiah', label: hariBulan.map((t) => t.slice(8, 10)),
          seri: [{ n: 'Penerimaan', warna: W.hijau, nilai: hariBulan.map((t) => Math.round(jml(sah.filter((x) => x.tanggal === t)) / 1e5) / 10) }] },
        { tipe: 'lingkaran', judul: 'Cara pembayaran bulan ini', satuan: 'transaksi', data: [{ n: 'Tunai', nilai: sah.filter((x) => x.cara === 'tunai').length, warna: W.emas }, { n: 'Transfer', nilai: sah.filter((x) => x.cara === 'transfer').length, warna: W.biru }] }] })
  }

  // Administrasi pegawai
  {
    const a = d.adminpeg || {}; const jh = new Set(a.jurnal_hari || []); const terjadwal = pegawai.filter((p) => p.status !== 'libur'); const isi = terjadwal.filter((p) => jh.has(p.id))
    const ultah = a.ultah || []; const ultahHari = ultah.filter((x) => x.hari_ini)
    const K_A = [['nama', 'Pegawai', 28], ['jenis', 'Jenis', 18], ['tgl', 'Tanggal', 22], ['ket', 'Keterangan', 30]]
    const JENIS_C = { koordinat_identik: 'Koordinat identik', akurasi_tidak_wajar: 'Akurasi tidak wajar', perangkat_bersama: 'Perangkat bersama', selfie_identik: 'Swafoto identik' }
    const nAntre = [(a.cuti || []).length, (a.koreksi || []).length, (a.data || []).length, a.jurnal_menunggu || 0, a.slip || 0, (a.curiga || []).length]
    slide.push({ k: 'adminpeg', judul: 'Administrasi Pegawai', ikon: PhIdentificationCard, w: 'pegawai', sub: 'Antrean layanan kepegawaian dan kelengkapan administrasi',
      kartu: [
        kartu('Pegawai aktif', pegawai.length, PhUsersFour, 'pegawai', ketLP(pegawai), daftarP('Pegawai aktif', pegawai.map((p) => rapiP(p)))),
        kartu('Izin/cuti menunggu', (a.cuti || []).length, PhFileText, 'pengajuan', `${pr((a.cuti || []).length, pegawai.length)} dari pegawai · belum diputuskan`, { judul: 'Pengajuan izin/cuti menunggu', kolom: K_A, baris: (a.cuti || []).map((x) => ({ ...x, tgl: x.mulai === x.selesai ? x.mulai : `${x.mulai} s.d. ${x.selesai}`, ket: x.alasan || '–' })) }),
        kartu('Koreksi presensi menunggu', (a.koreksi || []).length, PhClockCounterClockwise, 'agenda', `${pr((a.koreksi || []).length, pegawai.length)} dari pegawai · perbaikan presensi`, { judul: 'Koreksi presensi menunggu', kolom: K_A, baris: (a.koreksi || []).map((x) => ({ ...x, jenis: STATUS_PEG[x.status_baru] || x.status_baru, tgl: formatWaktu(x.waktu), ket: x.alasan })) }),
        kartu('Perubahan data menunggu', (a.data || []).length, PhUserGear, 'jadwal', `${pr((a.data || []).length, pegawai.length)} dari pegawai · perubahan biodata`, { judul: 'Perubahan data pegawai menunggu', kolom: K_A, baris: (a.data || []).map((x) => ({ ...x, jenis: 'Perubahan data', tgl: formatWaktu(x.waktu), ket: x.alasan || '–' })) }),
        kartu('Jurnal harian menunggu verval', a.jurnal_menunggu ?? 0, PhNotebook, 'tatausaha', 'Kegiatan menunggu verifikasi atasan', null),
        kartu('Jurnal harian hari ini', `${isi.length}/${terjadwal.length}`, PhNotePencil, 'presensi', `${pr(isi.length, terjadwal.length)} dari pegawai terjadwal`, daftarP('Pegawai belum mengisi jurnal harian hari ini', terjadwal.filter((p) => !jh.has(p.id)).map((p) => rapiP(p)))),
        kartu('Presensi perlu ditinjau', (a.curiga || []).length, PhSiren, 'klinik', `${pr(new Set((a.curiga || []).map((x) => x.nama)).size, pegawai.length)} dari pegawai · tanda tidak wajar`, { judul: 'Presensi perlu ditinjau', kolom: K_A, baris: (a.curiga || []).map((x) => ({ ...x, jenis: JENIS_C[x.jenis] || x.jenis, tgl: formatWaktu(x.waktu), ket: 'Belum ditinjau' })) }),
        kartu('Permintaan slip gaji', a.slip ?? 0, PhReceipt, 'gaji', `${pr(a.slip || 0, pegawai.length)} dari pegawai · menunggu diproses`, null),
        kartu('Ulang tahun bulan ini', ultah.length, PhCake, 'ekskul', ultahHari.length ? `Hari ini: ${ultahHari.map((x) => x.nama).join(', ')}` : `${pr(ultah.length, pegawai.length)} dari pegawai aktif`,
          { judul: 'Ulang tahun pegawai bulan ini', kolom: [['nama', 'Pegawai', 50], ['tgl', 'Tanggal', 20]], baris: ultah.map((x) => ({ ...x, tgl: String(x.tanggal || '').slice(5).split('-').reverse().join('/') + (x.hari_ini ? ' (hari ini)' : '') })) }),
        kartu('Akun belum diverifikasi', (a.belum_verifikasi || []).length, PhQuestion, 'hakakses', `${pr((a.belum_verifikasi || []).length, pegawai.length)} dari pegawai aktif`, { judul: 'Akun pegawai belum diverifikasi', kolom: [['nama', 'Pegawai', 50], ['niy', 'NIY', 20]], baris: (a.belum_verifikasi || []).map((x) => ({ ...x, niy: x.niy || '–' })) }),
      ],
      grafik: [{ tipe: 'batang', judul: 'Antrean layanan kepegawaian', sumbuY: 'Jumlah', label: ['Izin/cuti', 'Koreksi presensi', 'Perubahan data', 'Jurnal harian', 'Slip gaji', 'Presensi ditinjau'],
          seri: [{ n: 'Menunggu', warna: W.jingga, nilai: nAntre }] },
        { tipe: 'lingkaran', judul: 'Jurnal harian hari ini', satuan: 'pegawai', data: [{ n: 'Sudah mengisi', nilai: isi.length, warna: W.hijau }, { n: 'Belum mengisi', nilai: terjadwal.length - isi.length, warna: W.abu }] }] })
  }

  // Slide pindahan dari beranda (hanya hari berjalan)
  if (!d.lalu) slide.push(...slideBeranda(x, d, f))
  if (!d.lalu && x.kinerja) slide.push(slideKinerja(x.kinerja))

  // Urutan slide: Pondok di depan, unit kerja menyusul sesuai alur
  const URUT = ['pondok', 'santri', 'santrisesi', 'pegawai', 'presensisesi', 'kinerja', 'smp', 'sma', 'walikelas', 'gurumapel', 'tahfizh', 'hafalan', 'tahfizhringkas', 'musyrif', 'kegiatan', 'klinik', 'security', 'ekskul', 'perizinan', 'lapor', 'dokumen', 'surat', 'keuangan', 'adminpeg', 'administrasi']
  slide.sort((a, b) => URUT.indexOf(a.k) - URUT.indexOf(b.k))

  // Hari sebelumnya: ungkapan "hari ini" menjadi "hari itu"
  if (d.lalu) {
    const ganti = (t) => (typeof t === 'string' ? t.replace(/hari ini/g, 'hari itu').replace(/Hari ini/g, 'Hari itu').replace(/saat ini/g, 'saat itu') : t)
    for (const x of slide) {
      x.sub = ganti(x.sub)
      for (const k of x.kartu) { k.j = ganti(k.j); k.ket = ganti(k.ket); if (k.daftar) k.daftar.judul = ganti(k.daftar.judul) }
      for (const g of x.grafik || []) g.judul = ganti(g.judul)
    }
  }
  return slide
}

/**
 * Slide pindahan dari slider beranda (v1.5), masing-masing 10 kartu.
 * x = { presensi: statistik_presensi(), kelola: ringkasan_beranda().kelola, santri: statistik_santri(), tahfizh: ringkasan_tahfizh_beranda() }
 * Slide dilewati bila datanya tidak tersedia (mis. bukan admin).
 */
export function slideBeranda(x = {}, d = {}, f = {}) {
  const hasil = []; const n = (v) => Number(v) || 0

  // Presensi pegawai per sesi kerja
  const p = x.presensi
  if (p) {
    const tercatat = n(p.sesi_tercatat); const wajib = n(p.sesi_wajib); const tanpa = n(p.terlewat_belum) + n(p.tanpa_keterangan)
    const pola = p.per_pola || []
    hasil.push({ k: 'presensisesi', judul: 'Presensi Sesi', ikon: PhUserCheck, w: 'presensi', sub: 'Presensi pegawai per sesi kerja hari ini (dihitung per sesi, bukan per orang)',
      kartu: [
        kartu('Pegawai hadir', `${n(p.pegawai_hadir)}/${n(p.pegawai_terjadwal)}`, PhUserCheck, 'presensi', `${pr(n(p.pegawai_hadir), n(p.pegawai_terjadwal))} pegawai terjadwal hadir minimal satu sesi`),
        kartu('Tingkat kehadiran', p.persen_kehadiran == null ? '–' : `${String(p.persen_kehadiran).replace('.', ',')}%`, PhPercent, 'gaji', 'Dari sesi yang sudah tercatat atau lewat waktunya'),
        kartu('Sesi tercatat', `${tercatat}/${wajib}`, PhListChecks, 'jadwal', `${pr(tercatat, wajib)} sesi wajib hari ini`),
        kartu('Hadir tepat waktu', n(p.hadir), PhCheckCircle, 'presensi', `${pr(n(p.hadir), tercatat)} dari sesi tercatat`),
        kartu('Terlambat', n(p.terlambat), PhClock, 'pengajuan', `${pr(n(p.terlambat), tercatat)} dari sesi tercatat`),
        kartu('Dinas luar', n(p.dinas_luar), PhAirplaneTilt, 'jadwal', `${pr(n(p.dinas_luar), tercatat)} dari sesi tercatat`),
        kartu('Izin, sakit, cuti', n(p.izin_sakit_cuti), PhUserMinus, 'klinik', `${n(p.izin)} izin · ${n(p.sakit)} sakit · ${n(p.izin_sakit_cuti) - n(p.izin) - n(p.sakit)} cuti`),
        kartu('Sedang terbuka', n(p.terbuka_belum), PhPlayCircle, 'santri', `${n(p.akan_datang)} sesi akan datang`),
        kartu('Terlewat / tanpa keterangan', tanpa, PhXCircle, 'beranda', `${pr(tanpa, wajib)} sesi wajib tanpa presensi`),
        kartu('Perlu verval', n(p.verval_menunggu), PhSealCheck, 'verval', `${n(p.curiga_baru)} penanda kecurigaan perlu ditinjau`),
      ],
      grafik: [
        { tipe: 'lingkaran', judul: 'Status sesi presensi hari ini', satuan: 'sesi', data: [
          { n: 'Hadir tepat', nilai: n(p.hadir), warna: W.hijau }, { n: 'Terlambat', nilai: n(p.terlambat), warna: W.jingga }, { n: 'Dinas luar', nilai: n(p.dinas_luar), warna: W.biru },
          { n: 'Izin/sakit/cuti', nilai: n(p.izin_sakit_cuti), warna: W.ungu }, { n: 'Terlewat/tanpa keterangan', nilai: tanpa, warna: W.merah },
          { n: 'Terbuka/akan datang', nilai: n(p.terbuka_belum) + n(p.akan_datang), warna: W.abu }] },
        { tipe: 'batang', judul: 'Kehadiran per pola tugas', sumbuY: 'Jumlah sesi', label: pola.map((q) => q.pola),
          seri: [{ n: 'Hadir', warna: W.hijau, nilai: pola.map((q) => n(q.hadir)) }, { n: 'Belum/tidak hadir', warna: W.abu, nilai: pola.map((q) => n(q.wajib) - n(q.hadir)) }] },
      ] })
  }

  // Santri per sesi program
  const st = x.santri
  if (st) {
    const h = st.hari_ini || {}; const sesi = (d.sesi || []).filter((s) => !f.jk || !s.jk || s.jk === f.jk)
    const per = (j) => { const s = sesi.filter((y) => y.jenis === j); const ok = s.filter((y) => y.status === 'terisi')
      return { s, ok, h: ok.reduce((a, y) => a + n(y.hadir), 0), ang: ok.reduce((a, y) => a + n(y.anggota), 0) } }
    const kls = per('kelas'); const hq = per('halaqah'); const asr = per('asrama'); const eks = per('ekskul')
    const kartuP = (judul, o, ikon, w) => kartu(judul, `${o.ok.length}/${o.s.length}`, ikon, w, o.ang ? `${pr(o.h, o.ang)} santri hadir · ${o.s.length - o.ok.length} sesi belum terisi` : 'Belum ada sesi terisi', daftarSesi(`Sesi ${judul.toLowerCase()} hari ini`, o.s))
    hasil.push({ k: 'santrisesi', judul: 'Santri Sesi', ikon: PhStudent, w: 'santri', sub: 'Kehadiran santri per sesi program pokok dan ekskul hari ini',
      kartu: [
        kartu('Santri aktif', n(st.aktif), PhStudent, 'santri', `${n(st.putra)} putra · ${n(st.putri)} putri · Wustha ${n(st.wustha)} · SMA ${n(st.sma)}`),
        kartu('Kehadiran hari ini', h.anggota ? `${String(Math.round((n(h.hadir) * 1000) / n(h.anggota)) / 10).replace('.', ',')}%` : '–', PhPercent, 'absensi', `${n(h.sesi)} sesi program pokok terisi`),
        kartuP('Sesi kelas', kls, PhChalkboardTeacher, 'jadwal'),
        kartuP('Sesi halaqah', hq, PhBookOpenText, 'tahfizh'),
        kartuP('Sesi asrama', asr, PhBed, 'musyrif'),
        kartuP('Sesi ekskul', eks, PhPersonSimpleRun, 'ekskul'),
        kartu('Izin', n(h.izin), PhEnvelopeSimpleOpen, 'pengajuan', `${pr(n(h.izin), n(h.anggota))} dari kehadiran tercatat`),
        kartu('Sakit', n(h.sakit), PhFirstAidKit, 'klinik', `${pr(n(h.sakit), n(h.anggota))} dari kehadiran tercatat`),
        kartu('Absen', n(h.absen), PhProhibit, 'beranda', `${pr(n(h.absen), n(h.anggota))} dari kehadiran tercatat`),
        kartu('Data wajib kurang', n(st.data_kurang), PhWarningCircle, 'hakakses', 'NISN, tempat, atau tanggal lahir belum lengkap'),
      ],
      grafik: [
        { tipe: 'batang', judul: 'Kehadiran santri per program (%)', sumbuY: 'Persen hadir', label: ['Kelas', 'Halaqah', 'Asrama', 'Ekskul'],
          seri: [{ n: 'Hadir (%)', warna: W.hijau, nilai: [kls, hq, asr, eks].map((o) => persen(o.h, o.ang)) }] },
        { tipe: 'lingkaran', judul: 'Kehadiran santri hari ini', satuan: 'kehadiran', data: [
          { n: 'Hadir', nilai: n(h.hadir), warna: W.hijau }, { n: 'Izin', nilai: n(h.izin), warna: W.biru }, { n: 'Sakit', nilai: n(h.sakit), warna: W.ungu }, { n: 'Absen', nilai: n(h.absen), warna: W.merah }] },
      ] })
  }

  // Ringkasan tahfizh
  const t = x.tahfizh
  if (t) {
    const terdata = n(t.terdata); const capai = n(t.tercapai); const belum = n(t.tidak_tercapai)
    hasil.push({ k: 'tahfizhringkas', judul: 'Ringkasan Tahfizh', ikon: PhBooks, w: 'tahfizh', sub: 'Setoran, capaian bulan berjalan, ujian, dan usulan juz',
      kartu: [
        kartu('Setoran hari ini', `${n(t.setoran_terisi)}/${n(t.setoran_dibuka)}`, PhNotebook, 'presensi', `Sesi terisi dari yang sudah dibuka · ${n(t.setoran_total)} sesi hari ini`),
        kartu('Sesi setoran hari ini', n(t.setoran_total), PhCalendarCheck, 'jadwal', `${n(t.setoran_total) - n(t.setoran_dibuka)} belum dibuka`),
        kartu('Capaian bulan ini', terdata ? `${pr(capai, terdata)}` : '–', PhTarget, 'tahfizh', `${capai} tercapai dari ${terdata} santri terdata`),
        kartu('Mencapai target', capai, PhMedal, 'presensi', `${pr(capai, terdata)} dari santri terdata`),
        kartu('Belum mencapai target', belum, PhWarningCircle, 'klinik', `${pr(belum, terdata)} · perlu pendampingan`),
        kartu('Ujian menunggu', n(t.ujian_menunggu), PhExam, 'agenda', 'Menunggu penguji atau terjadwal'),
        kartu('Usulan juz', n(t.usulan_menunggu), PhSealCheck, 'pengajuan', 'Menunggu validasi'),
        kartu('Rata-rata hafalan', `${String(t.rata_juz ?? 0).replace('.', ',')} juz`, PhBookOpenText, 'santri', 'Hafalan resmi tervalidasi'),
        kartu('Khatam 30 juz', n(t.khatam), PhTrophy, 'gaji', `${pr(n(t.khatam), n(t.santri))} dari santri tahfizh`),
        kartu('Santri tahfizh', n(t.santri), PhUsersFour, 'santri', `${terdata} capaiannya terdata bulan ini`),
      ],
      grafik: [
        { tipe: 'lingkaran', judul: 'Capaian target bulan ini', data: [{ n: 'Tercapai', nilai: capai, warna: W.hijau }, { n: 'Belum tercapai', nilai: belum, warna: W.merah },
          { n: 'Belum terdata', nilai: Math.max(0, n(t.santri) - terdata), warna: W.abu }] },
        { tipe: 'batang', judul: 'Sesi setoran hari ini', sumbuY: 'Jumlah sesi', label: ['Terisi', 'Dibuka', 'Seluruh sesi'],
          seri: [{ n: 'Sesi', warna: W.teal, nilai: [n(t.setoran_terisi), n(t.setoran_dibuka), n(t.setoran_total)] }] },
      ] })
  }

  // Administrasi pegawai (layanan kepegawaian)
  const k = x.kelola
  if (k) {
    const akun = n(k.akun_aktif); const jurnal = n(k.jurnal_hari_ini)
    hasil.push({ k: 'administrasi', judul: 'Administrasi', ikon: PhFileText, w: 'tatausaha', sub: 'Verval jurnal, pengajuan, agenda, pengumuman, berkas, dan kartu pegawai',
      kartu: [
        kartu('Jurnal menunggu verval', n(k.verval_jurnal), PhSealCheck, 'verval', 'Kegiatan jurnal yang perlu diverval'),
        kartu('Pengajuan dalam proses', n(k.pengajuan_menunggu), PhFileText, 'pengajuan', `${n(k.pengajuan_bulan_ini)} disetujui bulan ini`),
        kartu('Pegawai izin/cuti hari ini', n(k.sedang_izin), PhUserMinus, 'klinik', 'Izin, sakit, cuti, dinas luar'),
        kartu('Mengisi jurnal hari ini', `${jurnal}/${akun}`, PhNotePencil, 'tatausaha', `${pr(jurnal, akun)} dari akun aktif`),
        kartu('Agenda bulan ini', n(k.agenda_bulan_ini), PhCalendarStar, 'agenda', `${n(k.agenda_pekan_ini)} dalam 7 hari ke depan`),
        kartu('Pengumuman aktif', n(k.pengumuman_aktif), PhMegaphone, 'pengumuman', 'Sedang tayang'),
        kartu('Berkas belum dibuka', n(k.berkas_belum_dibuka), PhFolderOpen, 'berkas', 'Berkas yang belum dibuka penerima'),
        kartu('Kartu pegawai terbit', n(k.kartu_terbit), PhIdentificationCard, 'profil', `${n(k.tanpa_foto)} akun belum berpas foto`),
        kartu('Notifikasi HP aktif', n(k.perangkat_push), PhPaperPlaneTilt, 'notifikasi', `${pr(n(k.perangkat_push), akun)} dari akun aktif`),
        kartu('Pegawai tanpa NIY', n(k.tanpa_niy), PhWarningCircle, 'beranda', 'Lengkapi sebelum cetak kartu'),
      ],
      grafik: [
        { tipe: 'batang', judul: 'Antrean administrasi', sumbuY: 'Jumlah', label: ['Verval jurnal', 'Pengajuan', 'Berkas belum dibuka', 'Tanpa NIY', 'Tanpa pas foto'],
          seri: [{ n: 'Menunggu', warna: W.jingga, nilai: [n(k.verval_jurnal), n(k.pengajuan_menunggu), n(k.berkas_belum_dibuka), n(k.tanpa_niy), n(k.tanpa_foto)] }] },
        { tipe: 'lingkaran', judul: 'Jurnal harian hari ini', satuan: 'pegawai', data: [{ n: 'Sudah mengisi', nilai: jurnal, warna: W.hijau }, { n: 'Belum mengisi', nilai: Math.max(0, akun - jurnal), warna: W.abu }] },
      ] })
  }
  return hasil
}

// ---------- Kinerja Bidang (v1.6) ----------
const WARNA_KARTU = ['presensi', 'pegawai', 'santri', 'tahfizh', 'pengajuan', 'klinik', 'security', 'laporan', 'tatausaha', 'gaji', 'agenda', 'musyrif']
const tglPendek = (iso) => (iso ? `${iso.slice(8, 10)}/${iso.slice(5, 7)}/${iso.slice(0, 4)}` : '')
const K_KINERJA = [['niy', 'NIY', 9], ['nama', 'Nama pegawai', 21], ...INDIKATOR.map((x) => [x.k, x.pendek, 8]), ['skor', 'Skor', 7], ['pred', 'Predikat', 11]]
const barisKinerja = (p) => ({ niy: p.niy || '–', nama: p.nama, jabatan: p.jabatan || '–', ...Object.fromEntries(INDIKATOR.map((x) => [x.k, p.ind[x.k].p == null ? '–' : persenTeks(p.ind[x.k].p)])),
  skor: skorTeks(p.skor), pred: p.predikat?.n || '–' })
const ketRumus = () => INDIKATOR.map((x, i) => `${i + 1}) ${x.n} = ${x.rumus}.`)

/** Slide indikator kinerja bidang. k = olah(kinerja_bidang(mulai, selesai)) */
export function slideKinerja(k) {
  const periode = `${tglPendek(k.mulai)} s.d. ${tglPendek(k.selesai)}`
  const bidang = k.bidang.filter((b) => b.skor != null || b.pegawai)
  const urut = [...bidang].sort((a, b) => (b.skor ?? -1) - (a.skor ?? -1))
  const daftarBidang = (b) => ({
    judul: `Kinerja ${b.nama}`, kolom: K_KINERJA, tegak: false,
    catatan: [`Periode ${periode}. Skor ${skorTeks(b.skor)} (${b.predikat?.n || '–'}).${b.kepala ? ' Kepala: ' + b.kepala + '.' : ''}`, ...b.catatan,
      'Persentase per pegawai: absen santri dihitung dari kelompok yang diasuhnya; nilai bidang dihitung dari kelompok milik bidang.'],
    baris: k.pegawai.filter((p) => p.bidang === b.id).sort((x, y) => (x.skor ?? 999) - (y.skor ?? 999)).map(barisKinerja),
    total: { niy: '', nama: 'Nilai bidang', ...Object.fromEntries(INDIKATOR.map((x) => [x.k, b.ind[x.k].p == null ? '–' : persenTeks(b.ind[x.k].p)])), skor: skorTeks(b.skor), pred: b.predikat?.n || '–' },
  })
  const ringkasBaris = urut.map((b) => ({ niy: '', nama: b.nama, ...Object.fromEntries(INDIKATOR.map((x) => [x.k, b.ind[x.k].p == null ? '–' : persenTeks(b.ind[x.k].p)])), skor: skorTeks(b.skor), pred: b.predikat?.n || '–' }))
  const daftarPondok = { judul: 'Indikator Kinerja Bidang', kolom: [['nama', 'Bidang', 24], ...INDIKATOR.map((x) => [x.k, x.pendek, 8.5]), ['skor', 'Skor', 7], ['pred', 'Predikat', 12]], baris: ringkasBaris,
    total: { nama: 'Seluruh pondok', ...Object.fromEntries(INDIKATOR.map((x) => [x.k, k.pondok.ind[x.k].p == null ? '–' : persenTeks(k.pondok.ind[x.k].p)])), skor: skorTeks(k.pondok.skor), pred: k.pondok.predikat?.n || '–' },
    catatan: [`Periode ${periode}. Enam indikator yang sama untuk setiap bidang, bobot sama; skor = rata-rata indikator yang berlaku.`, ...ketRumus(),
      'Predikat: ≥ 90 sangat baik; 80–89 baik; 70–79 cukup; < 70 perlu pembinaan.'] }
  const kurang = k.kelompok.filter((g) => g.ss && g.ss_isi < g.ss).sort((a, b) => (a.p ?? 0) - (b.p ?? 0))
  const namaBidang = Object.fromEntries(k.bidang.map((b) => [b.id, b.nama]))
  const JENIS = { kelas: 'Kelas', halaqah: 'Halaqah', kamar: 'Kamar', ekskul: 'Ekskul' }
  const daftarKelompok = { judul: 'Absensi santri per kelompok yang belum lengkap', kolom: [['kelompok', 'Kelompok', 18], ['jenis', 'Jenis', 9], ['bidang', 'Bidang', 20], ['pengasuh', 'Pengasuh', 25], ['isi', 'Terisi', 9], ['jadwal', 'Terjadwal', 9], ['persen', 'Capaian', 10]],
    baris: kurang.map((g) => ({ kelompok: g.nama, jenis: JENIS[g.jenis] || g.jenis, bidang: namaBidang[g.bidang] || '–', pengasuh: g.pengasuh || '–', isi: g.ss_isi, jadwal: g.ss, persen: persenTeks(g.p) })),
    catatan: [`Periode ${periode}. Sesi absensi yang terjadwal dan sudah lewat tetapi belum diisi.`] }
  const terendah = (b) => { const x = INDIKATOR.filter((i) => b.ind[i.k].p != null).sort((p, q) => b.ind[p.k].p - b.ind[q.k].p)[0]; return x ? `terendah ${x.pendek.toLowerCase()} ${persenTeks(b.ind[x.k].p)}` : 'belum ada data' }
  const kartuBidang = urut.slice(0, 10).map((b, i) => kartu(b.nama.replace(/^Bidang (Kesetaraan )?/, 'Bid. '), skorTeks(b.skor), PhTarget, WARNA_KARTU[(i + 2) % WARNA_KARTU.length],
    `${b.predikat?.n || '–'} · ${b.pegawai} pegawai · ${terendah(b)}`, daftarBidang(b)))
  return {
    k: 'kinerja', judul: 'Kinerja Bidang', ikon: PhChartLine, w: 'rekap',
    sub: `Indikator kinerja bidang ${periode} · enam indikator sama untuk setiap bidang · ketuk untuk rincian`,
    kartu: [
      kartu('Skor seluruh pondok', skorTeks(k.pondok.skor), PhPresentationChart, 'presensi', `${k.pondok.predikat?.n || '–'} · ${k.pondok.pegawai} pegawai · ${bidang.length} bidang`, daftarPondok),
      ...kartuBidang,
      kartu('Kelompok belum lengkap', kurang.length, PhListChecks, 'santri', `dari ${k.kelompok.length} kelompok santri · ada sesi absensi belum terisi`, daftarKelompok),
    ],
    grafik: [
      { tipe: 'skor', judul: 'Skor kinerja per bidang (0–100)', lebar: true, data: urut.filter((b) => b.skor != null).map((b) => ({ id: b.id, n: b.nama, v: b.skor, warna: b.predikat?.warna, ket: b.predikat?.n, daftar: daftarBidang(b) })) },
      { tipe: 'peta', judul: 'Capaian enam indikator per bidang', lebar: true, baris: urut.map((b) => ({ ...b, daftar: daftarBidang(b) })), total: k.pondok },
    ],
  }
}
