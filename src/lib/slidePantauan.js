// SIMKA PRO | src/lib/slidePantauan.js | v1.3 | Perbaikan: 10 kartu per slide, persentase pada keterangan, jumlah kelompok dan rekapnya | 14/10/2026
// Penyusun slide Layar Pantauan dari muatan pantauan_langsung(): setiap slide berisi kartu statistik (dengan daftar
// nama untuk detail admin/superadmin) dan grafik (batang/lingkaran). Saringan: jenis kelamin, jenjang, bidang.
// Urutan: Santri, Pegawai, SMP, SMA, Tahfizh, Hafalan, Asrama, Kegiatan Santri, Medis, Security, Ekskul, Perizinan, Laporan dan Agenda.
// v1.2: Santri + hadir di halaqah; Pegawai + sementara bertugas, cepat pulang, sudah pulang (menggantikan tidak terjadwal);
//       SMP/SMA + jam pelajaran terlaksana; Tahfizh + ujian hari itu; slide Perizinan dan Laporan dan Agenda; hari lalu → teks "hari itu".
// v1.3: setiap slide 10 kartu; data santri/pegawai selalu disertai persentase di keterangan; Santri + asrama pagi;
//       SMP/SMA/Tahfizh/Asrama + jumlah kelas/halaqah/kamar (daftar = rekap: pengasuh, santri L/P, dapat dicetak);
//       Asrama + santri di luar pondok, musyrif hadir pagi dan hadir malam (kehadiran per sesi kerja).
import {
  PhStudent, PhChalkboardTeacher, PhBookOpenText, PhBed, PhFirstAidKit, PhSignOut, PhSiren, PhUserCheck, PhClock, PhAirplaneTilt, PhUserMinus,
  PhHourglass, PhMoon, PhCalendarCheck, PhSignIn, PhProhibit, PhPackage, PhHandArrowDown, PhIdentificationBadge, PhUsersThree, PhGraduationCap,
  PhBooks, PhMedal, PhTrophy, PhTrendUp, PhWarningCircle, PhStethoscope, PhAmbulance, PhHeartbeat, PhShieldCheck, PhPersonSimpleRun, PhUsers, PhHouseLine,
  PhBriefcase, PhHouse, PhTimer, PhEnvelopeSimpleOpen, PhCalendarStar, PhMegaphone, PhExam, PhNotebook,
  PhSun, PhUsersFour, PhCheckCircle, PhXCircle, PhPlayCircle, PhListChecks, PhPercent, PhUserList, PhBookBookmark, PhCalendarX, PhFlag, PhDoorOpen, PhQuestion,
} from '@phosphor-icons/vue'
import { formatJam, formatWaktu } from './tanggal'
import { JENIS_TITIPAN, PENGAMBIL } from './security'

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
export function susunSlide(d, f) {
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
