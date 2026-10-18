// SIMKA PRO | src/lib/rekamPegawai.js | v1.0 | 14.8.0: pemuat Rekam Kepegawaian individu (server dan mode demo) serta temuan otomatis | 18/10/2026
// rekam_kepegawaian(pegawai, mulai, selesai) menyatukan identitas, jabatan, kehadiran, pengajuan, jurnal, mengajar, tugas, beban kerja,
// dan surat teguran satu pegawai. temuan() menyusun catatan ringkas otomatis (seperti ringkasan rekam medis) dari angka tersebut.
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from '@/stores/lembaga'
import { usePegawai } from '@/stores/pegawai'
import { hariIniISO } from '@/lib/tanggal'

export const NAMA_HARI_ISO = ['', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Ahad']
export const JENIS_TUGAS = { kelas: 'Wali kelas', kamar: 'Musyrif kamar', halaqah: 'Muhaffizh halaqah', ekskul: 'Pembina ekskul', asrama: 'Musyrif asrama' }
export const JENIS_ABSEN = { kelas: 'Absensi kelas', halaqah: 'Absensi halaqah', asrama: 'Absensi asrama', ekskul: 'Pertemuan ekskul' }

export async function muatRekam(id, mulai, selesai) {
  if (MODE_DEMO) return demoRekam(id, mulai, selesai)
  const { data, error } = await supabase.rpc('rekam_kepegawaian', { p_emp: id, p_mulai: mulai, p_selesai: selesai })
  if (error) throw new Error(pesanGalat(error))
  return data
}

/** Catatan otomatis: [{ jenis: 'baik'|'perhatian'|'info', teks }] */
export function temuan(r, batas = 80) {
  if (!r) return []
  const t = []; const p = r.presensi || {}
  if (p.sesi) {
    if (p.persen >= Math.max(batas, 95)) t.push({ jenis: 'baik', teks: `Kehadiran sangat baik (${fmt(p.persen)}% dari ${p.sesi} sesi wajib).` })
    else if (p.persen < batas) t.push({ jenis: 'perhatian', teks: `Kehadiran ${fmt(p.persen)}%, di bawah batas ${batas}% yang ditetapkan.` })
    else t.push({ jenis: 'info', teks: `Kehadiran ${fmt(p.persen)}% dari ${p.sesi} sesi wajib.` })
    if (p.tanpa_keterangan >= 3) t.push({ jenis: 'perhatian', teks: `${p.tanpa_keterangan} sesi tanpa keterangan pada periode ini.` })
    if (p.terlambat >= 5) t.push({ jenis: 'perhatian', teks: `Terlambat ${p.terlambat} kali (jumlah ${p.menit_terlambat} menit); ketepatan waktu ${fmt(p.tepat_waktu)}%.` })
    else if (p.tepat_waktu >= 95) t.push({ jenis: 'baik', teks: `Ketepatan waktu datang ${fmt(p.tepat_waktu)}%.` })
    const rawan = [...(r.presensi_hari || [])].sort((a, b) => b.terlambat + b.tanpa_keterangan - (a.terlambat + a.tanpa_keterangan))[0]
    if (rawan && rawan.terlambat + rawan.tanpa_keterangan >= 3) t.push({ jenis: 'info', teks: `Keterlambatan/ketidakhadiran paling sering pada hari ${NAMA_HARI_ISO[rawan.hari]}.` })
    if (p.tidak_presensi_pulang >= 3) t.push({ jenis: 'perhatian', teks: `${p.tidak_presensi_pulang} kali tidak melakukan presensi pulang.` })
  } else t.push({ jenis: 'info', teks: 'Belum ada sesi presensi wajib pada periode ini.' })
  const j = r.jurnal || {}
  if (p.hari_hadir) {
    const pj = Math.round((100 * (j.hari || 0)) / p.hari_hadir)
    t.push({ jenis: pj >= 90 ? 'baik' : pj < 70 ? 'perhatian' : 'info', teks: `Jurnal harian terisi ${j.hari || 0} dari ${p.hari_hadir} hari hadir (${pj}%).` })
  }
  const ajar = (r.mengajar || []).reduce((a, m) => ({ y: a.y + m.terlaksana, n: a.n + m.tidak }), { y: 0, n: 0 })
  if (ajar.y + ajar.n) t.push({ jenis: ajar.n / (ajar.y + ajar.n) > 0.1 ? 'perhatian' : 'baik', teks: `${ajar.y} pertemuan mengajar terlaksana, ${ajar.n} tidak terlaksana.` })
  const sp = (r.teguran || []).filter((w) => w.status === 'terbit' && w.berlaku_sampai >= hariIniISO())
  if (sp.length) t.push({ jenis: 'perhatian', teks: `Masih memiliki SP-${Math.max(...sp.map((w) => w.tingkat))} yang berlaku.` })
  const peng = (r.pengajuan || []).filter((x) => x.status === 'disetujui')
  if (peng.length) t.push({ jenis: 'info', teks: `${peng.length} pengajuan disetujui (${peng.reduce((a, x) => a + Number(x.hari || 0), 0)} hari).` })
  return t
}
const fmt = (v) => (v == null ? '–' : String(v).replace('.', ','))

// ---------------------------------------------------------------------------------------------- mode demo
function demoRekam(id, mulai, selesai) {
  const p = usePegawai().cari(id) || usePegawai().daftar[0] || {}
  const benih = [...String(id)].reduce((a, c) => a + c.charCodeAt(0), 0)
  const acak = (i, m) => (Math.abs(Math.sin(benih * 13 + i * 7.3)) * 10000) % m
  const bulan = []; const d = new Date(mulai.slice(0, 7) + '-01T00:00:00Z'); const akhir = selesai.slice(0, 7)
  while (d.toISOString().slice(0, 7) <= akhir) { bulan.push(d.toISOString().slice(0, 7)); d.setUTCMonth(d.getUTCMonth() + 1) }
  const pb = bulan.map((b, i) => { const sesi = 22 + Math.round(acak(i, 4)); const tk = Math.round(acak(i + 3, 3)); const isc = Math.round(acak(i + 5, 3)); const lambat = Math.round(acak(i + 9, 6))
    const dl = Math.round(acak(i + 11, 2)); const hadir = sesi - tk - isc - lambat - dl
    return { bulan: b, sesi, hadir, terlambat: lambat, menit: lambat * (5 + Math.round(acak(i, 10))), tanpa_keterangan: tk, izin_sakit_cuti: isc, dinas_luar: dl, persen: Math.round(1000 * (hadir + lambat + dl) / sesi) / 10 } })
  const sum = (k) => pb.reduce((a, x) => a + x[k], 0)
  const sesi = sum('sesi'); const hd = sum('hadir'); const lt = sum('terlambat'); const dl = sum('dinas_luar')
  return {
    mulai, selesai, dibuat: new Date().toISOString(),
    profil: { id: p.id, nama: p.nama_lengkap, niy: p.niy, jenis_kelamin: p.jenis_kelamin, tempat_lahir: p.tempat_lahir, tanggal_lahir: p.tanggal_lahir, tmt_tugas: p.tmt_tugas || '2019-07-15',
      status_kepegawaian: p.status_kepegawaian || 'tetap', pendidikan: p.pendidikan_terakhir || 'S1', no_hp: p.no_hp, foto_id: null, status_keaktifan: 'aktif',
      unit: p.nama_unit || 'Bidang Kesetaraan Wustha', bidang: p.nama_unit || 'Bidang Kesetaraan Wustha', masa_kerja_bulan: 87,
      struktural: [], fungsional: ['Guru mapel', 'Wali kelas'], plt: [] },
    riwayat: [{ tanggal: '2023-07-01', jenis: 'status_kepegawaian', lama: 'kontrak', baru: 'tetap', alasan: 'Pengangkatan pegawai tetap' }, { tanggal: '2019-07-15', jenis: 'unit', lama: null, baru: 'Bidang Kesetaraan Wustha', alasan: 'Penempatan awal' }],
    presensi: { sesi, hadir: hd, terlambat: lt, menit_terlambat: sum('menit'), dinas_luar: dl, izin: Math.ceil(sum('izin_sakit_cuti') / 2), sakit: Math.floor(sum('izin_sakit_cuti') / 2), cuti: 0,
      tanpa_keterangan: sum('tanpa_keterangan'), menunggu: 0, cepat_pulang: 3, menit_cepat: 42, tidak_presensi_pulang: 2, hari_hadir: Math.round((hd + lt + dl) / 1.6),
      persen: Math.round(1000 * (hd + lt + dl) / sesi) / 10, tepat_waktu: Math.round(1000 * hd / (hd + lt)) / 10 },
    presensi_bulan: pb,
    presensi_hari: [1, 2, 3, 4, 5, 6, 7].map((h) => ({ hari: h, sesi: Math.round(sesi / 6), terlambat: Math.round(acak(h, h === 1 ? 6 : 3)), tanpa_keterangan: Math.round(acak(h + 20, 2)) })),
    pengajuan: [{ mulai: bulan[0] + '-14', selesai: bulan[0] + '-15', hari: 2, jenis: 'Sakit', kelompok: 'sakit', status: 'disetujui', alasan: 'Demam', nomor: null },
      { mulai: (bulan[1] || bulan[0]) + '-03', selesai: (bulan[1] || bulan[0]) + '-03', hari: 1, jenis: 'Izin keperluan keluarga', kelompok: 'izin', status: 'disetujui', alasan: 'Menghadiri pernikahan saudara', nomor: 'PGJ.014/PPTQ-IAS/IX/2026' },
      { mulai: (bulan[2] || bulan[0]) + '-20', selesai: (bulan[2] || bulan[0]) + '-21', hari: 2, jenis: 'Dinas luar', kelompok: 'dinas_luar', status: 'disetujui', alasan: 'Pelatihan kurikulum di Makassar', nomor: 'PGJ.021/PPTQ-IAS/X/2026' }],
    jurnal: { entri: Math.round((hd + lt) * 0.9), hari: Math.round((hd + lt + dl) / 1.6 * 0.86), disetujui: Math.round((hd + lt) * 0.8), menunggu: 4, dikembalikan: 2, jam: Math.round((hd + lt) * 2.6) },
    jurnal_bulan: pb.map((x) => ({ bulan: x.bulan, hari: Math.round((x.hadir + x.terlambat) / 1.6 * 0.86), hari_hadir: Math.round((x.hadir + x.terlambat + x.dinas_luar) / 1.6) })),
    mengajar: [{ kelas: '7A', mapel: 'Matematika', jp: 4, tahun: '2026/2027', terlaksana: 4 * bulan.length * 3, tidak: 2 }, { kelas: '8A', mapel: 'Matematika', jp: 4, tahun: '2026/2027', terlaksana: 4 * bulan.length * 3 - 1, tidak: 1 },
      { kelas: '7B', mapel: 'Informatika', jp: 2, tahun: '2026/2027', terlaksana: 2 * bulan.length * 3, tidak: 0 }],
    mengajar_bulan: pb.map((x, i) => ({ bulan: x.bulan, terlaksana: 38 + Math.round(acak(i, 6)), tidak: Math.round(acak(i + 2, 2)) })),
    absensi_santri: [{ jenis: 'kelas', sesi: 18 * bulan.length, terlambat_isi: 2 }],
    tugas: [{ jenis: 'kelas', kelompok: '7A', peran: 'utama', mulai: '2026-07-13', sampai: null, anggota: 24 }, { jenis: 'ekskul', kelompok: 'Robotik', peran: 'pendamping', mulai: '2026-08-01', sampai: null, anggota: 15 }],
    beban: { jam: 34, rincian: [{ komponen: 'Mengajar tatap muka', jam: 24 }, { komponen: 'Wali kelas', jam: 4 }, { komponen: 'Pembina ekskul', jam: 2 }, { komponen: 'Piket', jam: 4 }], kunci: { periode: '2026-09', jam_wajib: 30, total: 34, selisih: 4, status: 'dikunci' } },
    teguran: [],
  }
}
