// SIMKA PRO | src/lib/demoPortalWali.js | v1.1 | Fase 9 – Tahap 13.1.0 Kehadiran, perizinan, kunjungan, titipan, sakit | 15/10/2026
// Data contoh Portal Wali untuk MODE DEMO (dibangun dari santri dan kelompok contoh). Semua nama fiktif.
import { SANTRI_DEMO } from './demoSantri'
import { dataKelompokDemo } from './demoKelompok'
import { PENGATURAN_BAWAAN } from './portalWali'
import { hariIniISO } from './tanggal'

let santri = null
const semua = () => (santri ||= SANTRI_DEMO())
const angka = (v) => String(v || '').replace(/\D/g, '')

/** Contoh data masuk untuk ditampilkan di halaman Masuk mode demo. */
export function contohMasukDemo() {
  return semua().filter((s) => s.status === 'aktif' && s.kontak.some((k) => k.no_hp)).slice(0, 3).map((s) => ({
    nis: s.nis, nama: s.nama_lengkap, tanggal_lahir: s.tanggal_lahir, hp6: angka(s.kontak.find((k) => k.no_hp).no_hp).slice(-6),
  }))
}

export function masukDemo(identitas, tanggalLahir, hp) {
  const k = angka(identitas)
  const s = semua().find((x) => x.status === 'aktif' && (x.nis === k || x.nisn === k))
  const kontak = s && s.tanggal_lahir === tanggalLahir ? s.kontak.find((c) => c.no_hp && angka(c.no_hp).slice(-6) === angka(hp)) : null
  if (!kontak) return { ok: false, kode: 'SALAH', galat: 'Data tidak cocok. Periksa kembali NIS/NISN, tanggal lahir, dan 6 digit terakhir nomor HP.' }
  const kelas = dataKelompok(s).find((g) => g.jenis === 'kelas')?.nama || null
  return {
    ok: true, token: `demo-${s.nis}`, hubungan: kontak.hubungan,
    kedaluwarsa: new Date(Date.now() + 30 * 864e5).toISOString(),
    santri: { nis: s.nis, nama: s.nama_lengkap, panggilan: s.nama_panggilan, jk: s.jenis_kelamin, kelas },
  }
}

function dataKelompok(s) {
  const d = dataKelompokDemo(semua())
  return d.anggota.filter((a) => a.student_id === s.id && !a.selesai).map((a) => d.kelompok.find((g) => g.id === a.group_id)).filter(Boolean)
}

// ---------- Kehadiran contoh (deterministik per santri dan tanggal) ----------
const acak = (n) => { const x = Math.sin(n) * 10000; return x - Math.floor(x) }
const isoTgl = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
function sesiDemo(s, mulai, selesai) {
  const kel = dataKelompok(s); const nama = (j) => kel.find((g) => g.jenis === j)?.nama
  const hasil = []; const akhir = new Date(selesai + 'T00:00:00'); const benih = Number(s.nis.slice(-3))
  for (let d = new Date(mulai + 'T00:00:00'); d <= akhir; d.setDate(d.getDate() + 1)) {
    const t = isoTgl(d); const hari = d.getDay(); const n = benih * 97 + d.getDate() + d.getMonth() * 31
    const kode = (i) => { const r = acak(n + i); return r < 0.84 ? 'H' : r < 0.9 ? 'T' : r < 0.94 ? 'I' : r < 0.97 ? 'S' : r < 0.99 ? 'B' : 'A' }
    const daftar = [['asrama', nama('kamar'), 'Asrama pagi', '04.30'], ['asrama', nama('kamar'), 'Asrama malam', '21.00']]
    if (hari !== 0) daftar.push(['halaqah', nama('halaqah'), 'Halaqah subuh', '05.15'], ['halaqah', nama('halaqah'), 'Halaqah ashar', '15.45'], ['halaqah', nama('halaqah'), 'Halaqah maghrib', '18.15'])
    if (hari !== 0 && nama('kelas')) daftar.push(['kelas', nama('kelas'), 'Absensi kelas', '07.30'])
    if ([2, 4].includes(hari) && nama('ekskul')) daftar.push(['ekskul', nama('ekskul'), 'Latihan ekskul', '16.00'])
    daftar.filter((x) => x[1]).forEach((x, i) => {
      const k = kode(i)
      hasil.push({ t, j: x[0], g: x[1], s: x[2], jam: x[3], k, ket: k === 'I' ? 'Acara keluarga' : k === 'T' ? 'Terlambat bangun' : null })
    })
  }
  return hasil.sort((a, b) => (a.t < b.t ? 1 : a.t > b.t ? -1 : a.jam.localeCompare(b.jam)))
}
function rekapDemo(sesi) {
  const kosong = () => ({ sesi: 0, hadir: 0, izin: 0, sakit: 0, bolos: 0, absen: 0, terlambat: 0 })
  const r = { pokok: kosong() }
  for (const x of sesi) {
    const target = [r[x.j] ||= kosong(), ...(x.j !== 'ekskul' ? [r.pokok] : [])]
    for (const o of target) {
      o.sesi++; if (!['I', 'S', 'A'].includes(x.k)) o.hadir++
      if (x.k === 'I') o.izin++; if (x.k === 'S') o.sakit++; if (x.k === 'B') o.bolos++; if (x.k === 'A') o.absen++; if (x.k === 'T') o.terlambat++
    }
  }
  for (const o of Object.values(r)) o.persen = o.sesi ? Math.round((o.hadir * 1000) / o.sesi) / 10 : null
  return r
}
function rentangDemo(p = {}) {
  const hari = hariIniISO(); const selesai = p.selesai && p.selesai < hari ? p.selesai : hari
  return { mulai: p.mulai || `${selesai.slice(0, 8)}01`, selesai }
}
const jamLalu = (hari, jam = 8) => { const d = new Date(); d.setDate(d.getDate() - hari); d.setHours(jam, 15, 0, 0); return d.toISOString() }

export function dataDemo(nis, bagian, p = {}) {
  const s = semua().find((x) => x.nis === nis)
  if (!s) return { sesi_berakhir: true }
  const r = rentangDemo(p)
  if (bagian === 'kehadiran') { const sesi = sesiDemo(s, r.mulai, r.selesai); return { ...r, rekap: rekapDemo(sesi), sesi } }
  if (bagian === 'perizinan') return { ...r,
    izin: [{ jenis: 'pulang', alasan: 'Menghadiri pernikahan kakak', penjemput: s.kontak[0].nama, hubungan_penjemput: 'ayah', keluar_pada: jamLalu(9, 13), kembali_batas: jamLalu(7, 17), lama_hari: 2, keluar_aktual: jamLalu(9, 13), kembali_pada: jamLalu(7, 16), status: 'kembali', terlambat: false },
      { jenis: 'keluar', alasan: 'Periksa gigi di puskesmas', penjemput: null, keluar_pada: jamLalu(2, 9), kembali_batas: jamLalu(2, 12), lama_hari: 1, keluar_aktual: jamLalu(2, 9), kembali_pada: jamLalu(2, 13), status: 'kembali', terlambat: true }],
    libur: [{ nama: 'Libur bulanan Oktober', jenis: 'bulanan', pulang_pada: jamLalu(-10, 13), kembali_batas: jamLalu(-12, 17), keputusan: 'boleh' }] }
  if (bagian === 'kunjungan') return { ...r, kunjungan: [{ pengunjung: s.kontak[0].nama, hubungan: s.kontak[0].hubungan, jumlah_orang: 3, datang_pada: jamLalu(4, 10), pulang_pada: jamLalu(4, 12), luar_jadwal: false }] }
  if (bagian === 'titipan') return { ...r, titipan: [
    { jenis: 'makanan', uraian: 'Kue kering dan buah', pengirim: s.kontak[1]?.nama || s.kontak[0].nama, ekspedisi: null, status: 'di_pos', diterima_pada: jamLalu(0, 7) },
    { jenis: 'paket', uraian: 'Kitab dan alat tulis', pengirim: s.kontak[0].nama, ekspedisi: 'JNE', status: 'diambil', diterima_pada: jamLalu(6, 10), diambil_pada: jamLalu(6, 16), pengambil_jenis: 'santri', pengambil_nama: s.nama_lengkap }] }
  if (bagian === 'sakit') return { ...r, kasus: [{ dibuka_pada: jamLalu(3, 7), keluhan: 'Demam dan pusing', status: 'selesai', tindak_lanjut: 'istirahat', kontrol_pada: null, selesai_pada: jamLalu(1, 9), hasil: 'sembuh' }] }
  if (bagian !== 'beranda') return { galat: 'Bagian ini belum tersedia pada mode demo.' }
  const kel = dataKelompok(s)
  const nama = (j) => kel.filter((g) => g.jenis === j).map((g) => g.nama).join(', ') || null
  const TUGAS = { kelas: 'Wali kelas', kamar: 'Musyrif', halaqah: s.jenis_kelamin === 'P' ? 'Muhaffizhah' : 'Muhaffizh', ekskul: 'Pembina ekskul' }
  const URUT = ['kelas', 'halaqah', 'kamar', 'ekskul']
  const pengasuh = kel.filter((g) => g.pengasuh?.length).sort((a, b) => URUT.indexOf(a.jenis) - URUT.indexOf(b.jenis))
    .map((g) => ({ tugas: TUGAS[g.jenis], nama: g.pengasuh[0].nama, kelompok: g.nama }))
  const kodeHalaqah = ['H', 'T', 'H', 'I'][s.nis.charCodeAt(6) % 4]
  return {
    butir: PENGATURAN_BAWAAN.butir,
    lembaga: "Pondok Pesantren Tahfizhul Qur'an Imam Asy-Syathiby Wahdah Islamiyah Gowa",
    tanggal: hariIniISO(),
    wali: { hubungan: s.kontak[0].hubungan, nama: s.kontak[0].nama },
    santri: {
      nis: s.nis, nama: s.nama_lengkap, panggilan: s.nama_panggilan, jk: s.jenis_kelamin, jenjang: s.jenjang, tingkat: s.tingkat,
      kelas: nama('kelas'), kamar: nama('kamar'), halaqah: nama('halaqah'), ekskul: nama('ekskul'),
      program: 'reguler', tempat_lahir: s.tempat_lahir, tanggal_lahir: s.tanggal_lahir, tahun_masuk: s.tahun_masuk,
    },
    pengasuh,
    bulan_ini: rekapDemo(sesiDemo(s, `${hariIniISO().slice(0, 8)}01`, hariIniISO())).pokok,
    hari_ini: [
      { jenis: 'asrama', kelompok: nama('kamar') || 'Asrama', sesi: 'Asrama pagi', jam: '04.30', kode: 'H' },
      { jenis: 'halaqah', kelompok: nama('halaqah') || 'Halaqah', sesi: 'Halaqah subuh', jam: '05.15', kode: kodeHalaqah },
      ...(nama('kelas') ? [{ jenis: 'kelas', kelompok: nama('kelas'), sesi: 'Absensi kelas', jam: '07.30', kode: 'H' }] : []),
    ],
  }
}
