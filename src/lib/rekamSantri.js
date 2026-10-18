// SIMKA PRO | src/lib/rekamSantri.js | v1.0 | 14.9.0: Rekam Kesantrian (muat, temuan otomatis, data demo) | 18/10/2026
// rekam_kesantrian(santri, mulai, selesai) menyatukan data singkat, kelompok, kehadiran HISBAT, hafalan, ujian tahfizh, nilai akhir rapor,
// prestasi, kedisiplinan, security, klinik (ringkas), perizinan dan libur, serta keuangan (bila berhak) satu santri.
// temuan() menyusun catatan ringkas otomatis dari angka tersebut (tanpa skor), seperti Rekam Kepegawaian.
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from '@/stores/lembaga'
import { useSantri } from '@/stores/santri'
import { hariIniISO } from '@/lib/tanggal'
import { formatPosisi } from '@/lib/tahfizh'
import { rupiah } from '@/lib/gaji'

export const JENIS_KELOMPOK_REKAM = { kelas: 'Kelas', kamar: 'Kamar', halaqah: 'Halaqah', ekskul: 'Ekskul', lainnya: 'Kelompok lain' }
export const PENGASUH_KELOMPOK = { kelas: 'Wali kelas', kamar: 'Musyrif', halaqah: 'Muhaffizh', ekskul: 'Pembina', lainnya: 'Pembina' }
export const PROGRAM_REKAM = { kelas: 'Kelas', halaqah: 'Halaqah', asrama: 'Asrama', ekskul: 'Ekskul' }
export const KEPUTUSAN_RAPOR = { naik: 'Naik kelas', tinggal: 'Tinggal kelas', lulus: 'Lulus', tidak_lulus: 'Tidak lulus' }
export const JENIS_UJIAN_TAHFIZH = { kenaikan: 'Kenaikan juz', sertifikasi: 'Sertifikasi' }
export const JENIS_RIWAYAT_SANTRI = { status: 'Status santri', mutasi_masuk: 'Mutasi masuk', mutasi_keluar: 'Mutasi keluar', kenaikan: 'Kenaikan kelas' }
export const AKSI_KENAIKAN = { naik: 'Naik kelas', tinggal: 'Tinggal kelas', lulus: 'Lulus', pindah_jenjang: 'Pindah jenjang' }
export const JENIS_GERBANG = { keluar: 'Keluar', kembali: 'Kembali', ditolak: 'Ditolak keluar' }

export async function muatRekamSantri(id, mulai, selesai) {
  if (MODE_DEMO) return demoRekam(id, mulai, selesai)
  const { data, error } = await supabase.rpc('rekam_kesantrian', { p_santri: id, p_mulai: mulai, p_selesai: selesai })
  if (error) throw new Error(pesanGalat(error))
  return data
}

/** Rekap kehadiran program pokok (kelas, halaqah, asrama) dari r.kehadiran.program. */
export function hadirPokok(r) {
  const p = r?.kehadiran?.program || {}
  const t = ['kelas', 'halaqah', 'asrama'].reduce((a, k) => {
    const x = p[k] || {}
    for (const f of ['sesi', 'hadir', 'izin', 'sakit', 'bolos', 'absen', 'terlambat']) a[f] += Number(x[f] || 0)
    return a
  }, { sesi: 0, hadir: 0, izin: 0, sakit: 0, bolos: 0, absen: 0, terlambat: 0 })
  t.persen = t.sesi ? Math.round((1000 * t.hadir) / t.sesi) / 10 : null
  return t
}
/** Semester rapor terakhir yang punya nilai, beserta rata-rata dan mapel belum tuntas. */
export function nilaiTerakhir(r) {
  const daftar = (r?.nilai || []).filter((s) => (s.mapel || []).some((m) => m.nilai != null))
  const s = daftar[daftar.length - 1]
  if (!s) return null
  const ada = s.mapel.filter((m) => m.nilai != null)
  return { ...s, rata: Math.round((10 * ada.reduce((a, m) => a + Number(m.nilai), 0)) / ada.length) / 10, kurang: ada.filter((m) => m.tuntas === false) }
}
export const rataSemester = (s) => { const a = (s?.mapel || []).filter((m) => m.nilai != null); return a.length ? Math.round((10 * a.reduce((t, m) => t + Number(m.nilai), 0)) / a.length) / 10 : null }

/** Catatan otomatis: [{ jenis: 'baik'|'perhatian'|'info', teks }] */
export function temuanSantri(r, batas = 80) {
  if (!r) return []
  const t = []; const h = hadirPokok(r); const prog = r.kehadiran?.program || {}
  if (h.sesi) {
    if (h.persen >= Math.max(batas, 95)) t.push({ jenis: 'baik', teks: `Kehadiran sangat baik (${fmt(h.persen)}% dari ${h.sesi} sesi kelas, halaqah, dan asrama).` })
    else if (h.persen < batas) t.push({ jenis: 'perhatian', teks: `Kehadiran ${fmt(h.persen)}%, di bawah batas ${batas}% yang ditetapkan.` })
    else t.push({ jenis: 'info', teks: `Kehadiran ${fmt(h.persen)}% dari ${h.sesi} sesi kelas, halaqah, dan asrama.` })
    const rendah = ['kelas', 'halaqah', 'asrama'].filter((k) => prog[k]?.sesi && prog[k].persen < batas)
    if (rendah.length && h.persen >= batas) t.push({ jenis: 'perhatian', teks: `Kehadiran ${rendah.map((k) => `${PROGRAM_REKAM[k].toLowerCase()} ${fmt(prog[k].persen)}%`).join(', ')} di bawah batas.` })
    if (h.bolos >= 3) t.push({ jenis: 'perhatian', teks: `Bolos ${h.bolos} kali pada periode ini.` })
    if (h.absen >= 3) t.push({ jenis: 'perhatian', teks: `${h.absen} sesi absen tanpa keterangan.` })
    if (h.terlambat >= 5) t.push({ jenis: 'info', teks: `Terlambat ${h.terlambat} kali.` })
  } else t.push({ jenis: 'info', teks: 'Belum ada sesi absensi pada periode ini.' })
  // Hafalan
  const hf = r.hafalan || {}
  if (hf.setoran?.sesi) t.push({ jenis: 'info', teks: `Setoran ${hf.setoran.sesi} kali; hafalan baru bertambah ${formatPosisi(hf.setoran.tambah_hal) || 0}. Posisi terakhir ${formatPosisi(hf.sabaq_hal) || '0'}.` })
  const bln = (hf.bulanan || []).filter((b) => b.status !== 'tidak_terdata')
  if (bln.length) {
    const ok = bln.filter((b) => ['tercapai', 'khatam'].includes(b.status)).length
    t.push({ jenis: ok === bln.length ? 'baik' : ok < bln.length / 2 ? 'perhatian' : 'info', teks: `Target hafalan bulanan tercapai ${ok} dari ${bln.length} bulan.` })
  }
  if (hf.setoran?.janggal >= 3) t.push({ jenis: 'info', teks: `${hf.setoran.janggal} setoran ditandai janggal oleh sistem; perlu dicek muhaffizh.` })
  const uj = (r.ujian || [])[0]
  if (uj) t.push({ jenis: uj.hasil === 'remidi' ? 'perhatian' : 'baik', teks: `Ujian tahfizh terakhir (${JENIS_UJIAN_TAHFIZH[uj.jenis] || uj.jenis} juz ${(uj.juz || []).join(', ')}): ${uj.hasil === 'remidi' ? 'remidi' : 'tuntas'}${uj.nilai_akhir != null ? `, nilai ${fmt(uj.nilai_akhir)}` : ''}.` })
  // Nilai
  const n = nilaiTerakhir(r)
  if (n) {
    if (n.kurang.length) t.push({ jenis: 'perhatian', teks: `Semester ${n.semester} ${n.ta}: ${n.kurang.length} mapel belum tuntas (${n.kurang.map((m) => m.nama).join(', ')}); rata-rata ${fmt(n.rata)}.` })
    else t.push({ jenis: 'baik', teks: `Semester ${n.semester} ${n.ta}: semua mapel tuntas, rata-rata ${fmt(n.rata)}${n.status === 'dibuka' ? ' (nilai sementara)' : ''}.` })
  }
  const tinggal = (r.nilai || []).find((s) => s.keputusan?.keputusan === 'tinggal' || s.keputusan?.keputusan === 'tidak_lulus')
  if (tinggal) t.push({ jenis: 'perhatian', teks: `Pernah ${KEPUTUSAN_RAPOR[tinggal.keputusan.keputusan].toLowerCase()} pada tahun ajaran ${tinggal.ta}.` })
  // Prestasi
  const pr = (r.prestasi || []).filter((p) => p.dalam_periode)
  if (pr.length) t.push({ jenis: 'baik', teks: `${pr.length} prestasi pada periode ini, terakhir ${pr[0].capaian} ${pr[0].kegiatan}.` })
  // Kedisiplinan
  if (r.pelanggaran) {
    const v = r.pelanggaran.filter((x) => x.dalam_periode)
    if (!v.length) t.push({ jenis: 'baik', teks: 'Tidak ada pelanggaran tercatat pada periode ini.' })
    else { const berat = v.filter((x) => x.tingkat !== 'ringan').length; t.push({ jenis: berat ? 'perhatian' : 'info', teks: `${v.length} pelanggaran pada periode ini${berat ? ` (${berat} sedang/berat)` : ' (semua ringan)'}.` }) }
    const sp = (r.sp || []).filter((w) => w.keadaan === 'aktif')
    if (sp.length) t.push({ jenis: 'perhatian', teks: `Masih memiliki SP-${Math.max(...sp.map((w) => w.tingkat))} yang berlaku sampai ${tgl(sp[0].berlaku_sampai)}.` })
  }
  // Klinik, izin, libur
  const k = r.klinik || {}
  if (k.kasus >= 3) t.push({ jenis: 'perhatian', teks: `Berobat ke klinik ${k.kasus} kali pada periode ini (${k.istirahat || 0} kali istirahat/rawat).` })
  else if (k.kasus) t.push({ jenis: 'info', teks: `Berobat ke klinik ${k.kasus} kali pada periode ini.` })
  const lambat = (r.izin || []).filter((x) => x.terlambat).length + (r.libur || []).filter((x) => x.terlambat).length
  if (lambat) t.push({ jenis: 'perhatian', teks: `Terlambat kembali ke pondok ${lambat} kali setelah izin/libur.` })
  else if ((r.izin || []).length) t.push({ jenis: 'info', teks: `${r.izin.length} izin keluar/pulang; semuanya kembali tepat waktu.` })
  const tdk = (r.libur || []).filter((x) => x.keputusan === 'tidak').length
  if (tdk) t.push({ jenis: 'perhatian', teks: `Tidak memenuhi syarat libur pada ${tdk} periode libur.` })
  // Keuangan
  if (r.keuangan) {
    const u = r.keuangan.ringkas || {}
    if (Number(u.tunggakan) > 0) t.push({ jenis: 'perhatian', teks: `Tunggakan ${rupiah(u.tunggakan)} dari ${u.jumlah_tunggak} tagihan yang sudah jatuh tempo.` })
    else t.push({ jenis: 'baik', teks: 'Tidak ada tunggakan yang sudah jatuh tempo.' })
  }
  return t
}
const fmt = (v) => (v == null ? '–' : String(v).replace('.', ','))
const tgl = (v) => (v ? String(v).slice(0, 10).split('-').reverse().join('/') : '–')

// ---------------------------------------------------------------------------------------------- mode demo
function demoRekam(id, mulai, selesai) {
  const s = useSantri().cari(id) || useSantri().daftar[0] || {}
  const benih = [...String(id)].reduce((a, c) => a + c.charCodeAt(0), 0)
  const acak = (i, m) => (Math.abs(Math.sin(benih * 13 + i * 7.3)) * 10000) % m
  const hari = hariIniISO(); const akhir = selesai < hari ? selesai : hari
  const bulan = []; const d = new Date(mulai.slice(0, 7) + '-01T00:00:00Z')
  while (d.toISOString().slice(0, 7) <= selesai.slice(0, 7)) { bulan.push(d.toISOString().slice(0, 7)); d.setUTCMonth(d.getUTCMonth() + 1) }
  const kb = bulan.map((b, i) => { const sesi = b <= akhir.slice(0, 7) ? 66 + Math.round(acak(i, 9)) : 0; const iz = Math.round(acak(i + 1, 3)); const sk = Math.round(acak(i + 2, 4)); const bl = Math.round(acak(i + 3, 2)); const ab = Math.round(acak(i + 4, 2)); const lt = Math.round(acak(i + 5, 4))
    const hd = sesi ? sesi - iz - sk - ab : 0; const ps = (x) => (sesi ? Math.min(100, Math.round(10 * (x + acak(i + 9, 6))) / 10) : null)
    return { bulan: b, sesi, hadir: hd, izin: sesi ? iz : 0, sakit: sesi ? sk : 0, bolos: sesi ? bl : 0, absen: sesi ? ab : 0, terlambat: sesi ? lt : 0, persen: sesi ? Math.round((1000 * hd) / sesi) / 10 : null, kelas: ps(90), halaqah: ps(86), asrama: ps(92) } })
  const jum = (k) => kb.reduce((a, x) => a + x[k], 0)
  const program = Object.fromEntries(['kelas', 'halaqah', 'asrama'].map((k, j) => { const sesi = Math.round(jum('sesi') / 3); const iz = Math.round(jum('izin') / 3); const sk = Math.round(jum('sakit') / 3); const ab = Math.round(jum('absen') / 3) + (j === 1 ? 2 : 0)
    const hd = sesi - iz - sk - ab; return [k, { sesi, hadir: hd, izin: iz, sakit: sk, bolos: Math.round(jum('bolos') / 3), absen: ab, terlambat: Math.round(jum('terlambat') / 3), persen: sesi ? Math.round((1000 * hd) / sesi) / 10 : null }] }))
  program.ekskul = { sesi: 4 * bulan.length, hadir: 4 * bulan.length - 1, izin: 1, sakit: 0, bolos: 0, absen: 0, terlambat: 0, persen: Math.round(1000 * (4 * bulan.length - 1) / (4 * bulan.length)) / 10 }
  const kel = s.kelompok || []
  const namaK = (j, c) => kel.find((k) => k.jenis === j)?.nama || c
  const mapel = s.jenjang === 'sma' ? ['Pendidikan Agama Islam', 'Bahasa Indonesia', 'Matematika', 'Bahasa Inggris', 'Bahasa Arab', 'Fisika', 'Tahfizh']
    : ['Pendidikan Agama Islam', 'Bahasa Indonesia', 'Matematika', 'IPA', 'IPS', 'Bahasa Arab', 'Tahfizh']
  const smt = (ta, semester, kelas, tingkat, geser, status = 'ditutup', keputusan = null) => ({ ta, semester, kelas, jenjang: s.jenjang, tingkat, status,
    mapel: mapel.map((m, i) => { const nilai = Math.round(70 + acak(i + geser, 24)); const kkm = s.jenjang === 'sma' ? 75 : [70, 70, 65, 65, 65, 70, 70][i]
      return { nama: m, kelompok: i < 2 ? 'A' : 'B', urutan: i + 1, kkm, nilai, predikat: nilai >= 90 ? 'A' : nilai >= 80 ? 'B' : nilai >= kkm ? 'C' : 'D', tuntas: nilai >= kkm } }),
    pd: [{ kegiatan: 'Pramuka', nilai: 'B' }], keputusan })
  const tk = Number(s.tingkat) || 8
  const nilai = tk === 7 || tk === 10 ? [smt('2026/2027', 1, namaK('kelas', `${tk}A`), tk, 30, 'dibuka')]
    : [smt('2025/2026', 1, `${tk - 1}A`, tk - 1, 10), smt('2025/2026', 2, `${tk - 1}A`, tk - 1, 20, 'ditutup', { keputusan: 'naik', ke_tingkat: tk }), smt('2026/2027', 1, namaK('kelas', `${tk}A`), tk, 30, 'dibuka')]
  const sabaq = 60 + Math.round(acak(1, 120))
  return {
    mulai, selesai, dibuat: new Date().toISOString(), hak: { disiplin: true, keuangan: true },
    profil: { id: s.id, nama: s.nama_lengkap, panggilan: s.nama_panggilan, nis: s.nis, nisn: s.nisn, jenis_kelamin: s.jenis_kelamin, tempat_lahir: s.tempat_lahir, tanggal_lahir: s.tanggal_lahir,
      jenjang: s.jenjang, tingkat: s.tingkat, status: s.status, status_sejak: s.status_sejak, tahun_masuk: s.tahun_masuk, angkatan: s.angkatan, tanggal_masuk: s.tanggal_masuk, jalur_masuk: s.jalur_masuk,
      asal_sekolah: s.asal_sekolah, hafalan_awal_juz: s.hafalan_awal_juz, foto_id: s.foto_id, kota: s.kota_kab, provinsi: s.provinsi,
      kontak: (s.kontak || []).find((k) => k.utama) || (s.kontak || [])[0] || null },
    kelompok: [
      { jenis: 'kelas', nama: namaK('kelas', `${tk}A`), mulai: '2026-07-13', pengasuh: 'Ust. Ahmad Syahrir, S.Pd.', utama: { nama: 'Ust. Ahmad Syahrir, S.Pd.', niy: '2019070101' } },
      { jenis: 'kamar', nama: namaK('kamar', 'Kamar Umar bin Khattab'), mulai: '2026-07-13', pengasuh: 'Ust. Ridwan Hamid', utama: { nama: 'Ust. Ridwan Hamid', niy: '2020070102' } },
      { jenis: 'halaqah', nama: namaK('halaqah', 'Halaqah Ust. Hasan'), mulai: '2026-07-13', pengasuh: 'Ust. Hasanuddin, S.Q.', utama: { nama: 'Ust. Hasanuddin, S.Q.', niy: '2018070103' } },
      { jenis: 'ekskul', nama: 'Pramuka', mulai: '2026-08-01', pengasuh: 'Ust. Rahmat', utama: { nama: 'Ust. Rahmat', niy: null } }],
    riwayat_kelompok: [
      { tahun: '2026/2027', jenis: 'kelas', nama: namaK('kelas', `${tk}A`), mulai: '2026-07-13', selesai: null, aktif: true },
      { tahun: '2026/2027', jenis: 'kamar', nama: namaK('kamar', 'Kamar Umar bin Khattab'), mulai: '2026-07-13', selesai: null, aktif: true },
      { tahun: '2026/2027', jenis: 'halaqah', nama: namaK('halaqah', 'Halaqah Ust. Hasan'), mulai: '2026-07-13', selesai: null, aktif: true },
      ...(nilai.length > 1 ? [{ tahun: '2025/2026', jenis: 'kelas', nama: `${tk - 1}A`, mulai: '2025-07-14', selesai: '2026-06-30', alasan: 'Naik kelas', aktif: false },
        { tahun: '2025/2026', jenis: 'kamar', nama: 'Kamar Abu Bakar', mulai: '2025-07-14', selesai: '2026-06-30', alasan: 'Pergantian tahun ajaran', aktif: false },
        { tahun: '2025/2026', jenis: 'halaqah', nama: 'Halaqah Ust. Yusuf', mulai: '2025-07-14', selesai: '2026-06-30', alasan: 'Pergantian tahun ajaran', aktif: false }] : [])],
    riwayat: [...(nilai.length > 1 ? [{ tanggal: '2026-06-30', jenis: 'kenaikan', aksi: 'naik', lama: tk - 1, baru: tk, tahun: '2025/2026' }] : []),
      { tanggal: s.tanggal_masuk, jenis: 'status', lama: null, baru: 'aktif', alasan: s.jalur_masuk === 'pindahan' ? `Santri pindahan dari ${s.asal_sekolah}` : 'Santri baru' }],
    kehadiran: { program, bulan: kb,
      tidak_hadir: [{ tanggal: akhir, jenis: 'halaqah', kelompok: namaK('halaqah', 'Halaqah Ust. Hasan'), sesi: 'Halaqah subuh', kode: 'S', keterangan: 'Demam' },
        { tanggal: `${bulan[bulan.length - 1]}-05`, jenis: 'kelas', kelompok: namaK('kelas', `${tk}A`), sesi: 'Kelas', kode: 'I', keterangan: 'Acara keluarga' },
        { tanggal: `${bulan[0]}-20`, jenis: 'asrama', kelompok: namaK('kamar', 'Kamar Umar'), sesi: 'Asrama malam', kode: 'B', keterangan: null }] },
    hafalan: { program: 'reguler', sabaq_hal: sabaq, sabqi_hal: sabaq - 20, manzil_hal: sabaq - 40, juz_sedang: Math.floor(sabaq / 20) + 1, posisi_pada: new Date().toISOString(), halaqah: namaK('halaqah', 'Halaqah Ust. Hasan'),
      juz: [{ juz: 30, sumber: 'awal', tanggal: s.tanggal_masuk }, { juz: 29, sumber: 'awal', tanggal: s.tanggal_masuk }, { juz: 1, sumber: 'ujian', tanggal: '2026-02-10' }, { juz: 2, sumber: 'ujian', tanggal: '2026-08-20' }],
      bulanan: bulan.filter((b) => b < akhir.slice(0, 7)).map((b, i) => { const tam = 6 + Math.round(acak(i + 30, 7)); return { bulan: `${b}-01`, status: tam >= 10 ? 'tercapai' : 'tidak_tercapai', tambah_hal: tam, target_hal: 10, posisi_akhir_hal: sabaq - 10 + i * 3, disahkan: i < 2 } }),
      setoran: { sesi: 18 * bulan.length, tambah_hal: 8 * bulan.length, janggal: 2, hari: 18 * bulan.length },
      setoran_bulan: bulan.map((b, i) => ({ bulan: b, sesi: b <= akhir.slice(0, 7) ? 18 + Math.round(acak(i, 4)) : 0, tambah_hal: b <= akhir.slice(0, 7) ? 6 + Math.round(acak(i + 30, 7)) : 0 })) },
    ujian: [{ jenis: 'kenaikan', juz: [2], ujian_ke: 1, tajwid: 85, itqan: 88, nilai_akhir: 86.5, huruf: 'B', predikat: 'Jayyid Jiddan', hasil: 'tuntas', tanggal: '2026-08-20', penguji: 'Ust. Abdul Hakim, Lc.' },
      { jenis: 'kenaikan', juz: [1], ujian_ke: 2, tajwid: 78, itqan: 80, nilai_akhir: 79, huruf: 'C', predikat: 'Jayyid', hasil: 'tuntas', tanggal: '2026-02-10', penguji: 'Ust. Abdul Hakim, Lc.' }],
    utas: nilai.length > 1 ? [{ ta: '2025/2026', semester: 2, juz: [1, 29, 30], total_juz: 3, tajwid: 80, itqan: 84, nilai_akhir: 82, huruf: 'B', tuntas: true, tanggal: '2026-06-05', predikat: 'Jayyid Jiddan' }] : [],
    nilai,
    prestasi: [{ tanggal: `${bulan[Math.min(1, bulan.length - 1)]}-12`, bidang: 'tahfizh', tingkat: 'kabupaten', kegiatan: 'MTQ Kabupaten Gowa cabang Hifzhil Quran 5 juz', capaian: 'Juara 2', penyelenggara: 'LPTQ Kabupaten Gowa', dalam_periode: true },
      { tanggal: '2026-02-01', bidang: 'akademik', tingkat: 'pondok', kegiatan: 'Lomba Cerdas Cermat Pekan Santri', capaian: 'Juara 1', penyelenggara: 'OSIS', dalam_periode: false }],
    pelanggaran: [{ tanggal: `${bulan[Math.max(0, bulan.length - 2)]}-21`, kategori: 'Membawa HP', tingkat: 'sedang', tempat: 'Asrama', uraian: 'Kedapatan membawa telepon genggam di asrama', tindakan: 'HP disita, nasihat', dalam_periode: true },
      { tanggal: `${bulan[0]}-03`, kategori: 'Terlambat ke masjid', tingkat: 'ringan', tempat: 'Masjid', uraian: 'Terlambat shalat subuh berjamaah', tindakan: 'Nasihat', dalam_periode: true }],
    sp: [{ tingkat: 1, nomor: 'S.001/IZ/KW-IAS/IX/1448', tanggal: `${bulan[Math.max(0, bulan.length - 2)]}-22`, kategori: ['Membawa HP'], sanksi: ['Pembinaan musyrif'], uraian: null, status: 'terbit', berlaku_sampai: '2027-03-21', keadaan: 'aktif' }],
    security: { keluar: 2, kembali: 2, terlambat: 1, ditolak: 0, kunjungan: 2, titipan: 3,
      gerbang: [{ waktu: `${bulan[0]}-07T10:30:00Z`, jenis: 'kembali', terlambat_menit: 90, penjemput: 'Ayah' }, { waktu: `${bulan[0]}-05T00:00:00Z`, jenis: 'keluar', terlambat_menit: null, penjemput: 'Ayah' }],
      kunjungan_daftar: [{ datang_pada: `${bulan[Math.min(1, bulan.length - 1)]}-24T02:00:00Z`, pengunjung: (s.kontak || [])[1]?.nama || 'Ibu', hubungan: 'ibu', luar_jadwal: false }] },
    klinik: { kasus: 2, istirahat: 1, rujuk: 0, pulang: 0, daftar: [{ tanggal: `${bulan[Math.min(1, bulan.length - 1)]}-11`, keluhan: 'Demam dan pusing', tindak_lanjut: 'istirahat', status: 'selesai', hasil: 'sembuh' },
      { tanggal: `${bulan[bulan.length - 1]}-02`, keluhan: 'Sakit perut', tindak_lanjut: 'kembali', status: 'selesai', hasil: 'kembali' }] },
    izin: [{ jenis: 'pulang', alasan: 'Acara keluarga', status: 'kembali', keluar_pada: `${bulan[0]}-05T00:00:00Z`, kembali_batas: `${bulan[0]}-07T09:00:00Z`, kembali_pada: `${bulan[0]}-07T10:30:00Z`, lama_hari: 3, penjemput: 'Ayah', terlambat: true }],
    libur: [{ periode: 'Libur Maulid 1448 H', pulang_pada: `${bulan[Math.min(2, bulan.length - 1)]}-01T02:00:00Z`, kembali_batas: `${bulan[Math.min(2, bulan.length - 1)]}-05T09:00:00Z`, keputusan: 'boleh', tingkat: 'penuh', terlambat: false }],
    keuangan: { ringkas: { sisa: 1200000, tunggakan: 450000, jumlah_tunggak: 1 }, periode: { tagihan: 750000 * bulan.length, dibayar: 750000 * (bulan.length - 1) + 300000, jumlah: bulan.length },
      tagihan: bulan.slice().reverse().map((b, i) => ({ nama: `SPP ${b}`, tanggal_tagih: `${b}-01`, jatuh_tempo: `${b}-10`, nominal: 750000, dibayar: i === 0 ? 0 : i === 1 ? 300000 : 750000, status: i === 0 ? 'belum' : i === 1 ? 'sebagian' : 'lunas', lewat: i === 1 })),
      pembayaran: bulan.slice(1).reverse().map((b, i) => ({ tanggal: `${b}-08`, nomor: `BKM.${String(14 - i).padStart(3, '0')}/KEU/IAS/2026`, jumlah: i === 0 ? 300000 : 750000, cara: i % 2 ? 'tunai' : 'transfer' })),
      bulan: bulan.map((b, i) => ({ bulan: b, dibayar: i === bulan.length - 1 ? 0 : i === bulan.length - 2 ? 300000 : 750000 })) },
  }
}
