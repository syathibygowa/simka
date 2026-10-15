// SIMKA PRO | src/lib/demoPortalWali.js | v1.0 | Fase 9 – Tahap 13.0.0 Fondasi Portal Wali | 15/10/2026
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

export function dataDemo(nis, bagian) {
  const s = semua().find((x) => x.nis === nis)
  if (!s) return { sesi_berakhir: true }
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
    hari_ini: [
      { jenis: 'asrama', kelompok: nama('kamar') || 'Asrama', sesi: 'Asrama pagi', jam: '04.30', kode: 'H' },
      { jenis: 'halaqah', kelompok: nama('halaqah') || 'Halaqah', sesi: 'Halaqah subuh', jam: '05.15', kode: kodeHalaqah },
      ...(nama('kelas') ? [{ jenis: 'kelas', kelompok: nama('kelas'), sesi: 'Absensi kelas', jam: '07.30', kode: 'H' }] : []),
    ],
  }
}
