// SIMKA PRO | src/lib/presensi.js | v1.1 | Fase 2 – Tahap 4 Halaman presensi | 03/10/2026
// Bantuan presensi pegawai: label, format jam, jendela sesi, jarak, dan pemeriksaan jadwal bertumpuk.
// Perhitungan resmi (waktu, jarak, status) tetap dilakukan server; fungsi di sini hanya untuk tampilan.

export const JENIS_POLA = {
  rentang: { n: 'Rentang kerja', ket: 'Presensi datang dan pulang (guru, staf, kantor).' },
  sesi: { n: 'Sesi tugas', ket: 'Sekali presensi pada setiap sesi (halaqah, asrama, ekskul).' },
  shift: { n: 'Shift', ket: 'Hanya pada hari yang dijadwalkan di jadwal shift (medis, security).' },
  khusus: { n: 'Jadwal khusus', ket: 'Jadwal yang dibuat khusus, misalnya untuk satu pegawai.' },
}
export const SUMBER_JADWAL = {
  jabatan: { n: 'Dari jabatan', w: 'presensi' },
  struktural: { n: 'Jadwal struktural', w: 'pengaturan' },
  manual: { n: 'Ditambahkan admin', w: 'pegawai' },
}
export const HARI_SINGKAT = ['Ahad', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab']
export const HARI_PENUH = ['Ahad', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu']
export const URUT_HARI = [1, 2, 3, 4, 5, 6, 0] // Senin lebih dulu
export const WARNA_POLA = ['presensi', 'pegawai', 'tahfizh', 'santri', 'laporan', 'klinik', 'security', 'pengajuan', 'gaji', 'sistem', 'pengaturan', 'tatausaha']

/** '07:30:00' → menit sejak 00.00 */
export const keMenit = (t) => { if (!t) return 0; const [h, m] = String(t).split(':').map(Number); return h * 60 + (m || 0) }
/** menit → '07.30' (format jam baku Indonesia); lewat tengah malam ditandai */
export function jamTitik(menit) {
  const hari = Math.floor(menit / 1440)
  const m = ((menit % 1440) + 1440) % 1440
  const t = `${String(Math.floor(m / 60)).padStart(2, '0')}.${String(m % 60).padStart(2, '0')}`
  return hari > 0 ? `${t} (+1 hari)` : hari < 0 ? `${t} (hari sebelumnya)` : t
}
/** '07:30:00' → '07:30' (untuk input type=time) */
export const jamInput = (t) => (t ? String(t).slice(0, 5) : '')
/** Durasi sesi dalam menit; jam selesai ≤ jam mulai berarti lewat tengah malam */
export const durasi = (s) => { const a = keMenit(s.jam_mulai); let b = keMenit(s.jam_selesai); if (b <= a) b += 1440; return b - a }
export const lewatTengahMalam = (s) => keMenit(s.jam_selesai) <= keMenit(s.jam_mulai)

/** Teks hari: "Setiap hari", "Senin–Sabtu", atau daftar */
export function teksHari(hari = []) {
  const h = new Set((hari || []).map(Number))
  if (h.size === 7) return 'Setiap hari'
  if (!h.size) return 'Tidak ada hari'
  const urut = URUT_HARI.filter((x) => h.has(x))
  // rentang beruntun dalam urutan Senin..Ahad
  const idx = urut.map((x) => URUT_HARI.indexOf(x))
  const beruntun = idx.every((v, i) => i === 0 || v === idx[i - 1] + 1)
  if (beruntun && urut.length >= 3) return `${HARI_PENUH[urut[0]]}–${HARI_PENUH[urut[urut.length - 1]]}`
  return urut.map((x) => HARI_PENUH[x]).join(', ')
}

/** Titik-titik penting sebuah sesi dalam menit sejak 00.00 hari sesi */
export function jendela(s) {
  const mulai = keMenit(s.jam_mulai)
  const selesai = mulai + durasi(s)
  const j = {
    buka: mulai - s.buka_menit, mulai, tepat: mulai + s.toleransi_terlambat_menit,
    tutup: mulai + s.tutup_menit, selesai,
  }
  if (s.wajib_pulang) {
    j.pulangBuka = selesai - s.pulang_buka_menit
    j.batasCepat = selesai - (s.opsional ? 0 : s.toleransi_cepat_pulang_menit)
    j.batasPulang = selesai + s.batas_pulang_menit
  }
  return j
}

/** Kalimat ringkas aturan sesi untuk pegawai dan admin */
export function ringkasJendela(s) {
  const j = jendela(s)
  const r = [`${s.label_datang || 'Datang'} ${jamTitik(j.buka)}–${jamTitik(j.tutup)}`, `tepat waktu s.d. ${jamTitik(j.tepat)}`]
  if (s.wajib_pulang) r.push(`${s.label_pulang || 'Pulang'} ${jamTitik(j.pulangBuka)}–${jamTitik(j.batasPulang)}`)
  return r.join(' · ')
}

/** Periksa isian sesi; kembalikan pesan galat pertama atau '' bila sesuai */
export function periksaSesi(s) {
  if (!s.nama?.trim()) return 'Nama sesi wajib diisi.'
  if (!/^[A-Z0-9_]{1,30}$/.test(s.kode || '')) return 'Kode sesi hanya huruf besar, angka, dan garis bawah (contoh SUBUH).'
  if (!s.hari?.length) return 'Pilih minimal satu hari.'
  if (!s.jam_mulai || !s.jam_selesai) return 'Jam mulai dan jam selesai wajib diisi.'
  if (jamInput(s.jam_mulai) === jamInput(s.jam_selesai)) return 'Jam selesai tidak boleh sama dengan jam mulai.'
  const angka = ['buka_menit', 'toleransi_terlambat_menit', 'tutup_menit', 'pulang_buka_menit', 'toleransi_cepat_pulang_menit', 'batas_pulang_menit']
  for (const k of angka) if (!Number.isInteger(Number(s[k])) || Number(s[k]) < 0) return 'Isian menit harus berupa bilangan bulat 0 atau lebih.'
  if (Number(s.tutup_menit) < 1) return 'Batas presensi datang minimal 1 menit setelah jam mulai.'
  if (Number(s.tutup_menit) < Number(s.toleransi_terlambat_menit)) return 'Batas presensi datang tidak boleh lebih awal dari batas toleransi terlambat.'
  if (Number(s.buka_menit) > 240 || Number(s.toleransi_terlambat_menit) > 240 || Number(s.toleransi_cepat_pulang_menit) > 240) return 'Jendela buka dan toleransi paling lama 240 menit.'
  if (Number(s.tutup_menit) > 720 || Number(s.pulang_buka_menit) > 720 || Number(s.batas_pulang_menit) > 720) return 'Batas presensi paling lama 720 menit (12 jam).'
  return ''
}

/** Jarak dua koordinat dalam meter (haversine) — sama dengan fungsi server jarak_meter */
export function jarakMeter(lat1, lng1, lat2, lng2) {
  const r = (x) => (x * Math.PI) / 180
  const a = Math.sin(r(lat2 - lat1) / 2) ** 2 + Math.cos(r(lat1)) * Math.cos(r(lat2)) * Math.sin(r(lng2 - lng1) / 2) ** 2
  return 2 * 6371000 * Math.asin(Math.sqrt(a))
}
/** Titik terdekat: utamakan yang radiusnya memuat posisi */
export function titikTerdekat(titik, lat, lng) {
  const hasil = titik.filter((t) => t.aktif).map((t) => {
    const jarak = Math.round(jarakMeter(lat, lng, t.lat, t.lng))
    return { ...t, jarak, diArea: jarak <= t.radius_m }
  })
  hasil.sort((a, b) => (b.diArea - a.diArea) || a.jarak - b.jarak)
  return hasil[0] || null
}
/** Uraikan "-5.2000, 119.5000" (salinan Google Maps) menjadi { lat, lng } */
export function uraiKoordinat(teks) {
  const m = String(teks || '').replace(/[()]/g, '').match(/(-?\d+(?:[.,]\d+)?)\s*[,; ]\s*(-?\d+(?:[.,]\d+)?)/)
  if (!m) return null
  const lat = Number(m[1].replace(',', '.')); const lng = Number(m[2].replace(',', '.'))
  if (!(lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180)) return null
  return { lat, lng }
}
export const formatKoordinat = (lat, lng) => `${Number(lat).toFixed(6)}, ${Number(lng).toFixed(6)}`
export const formatJarak = (m) => (m >= 1000 ? `${(m / 1000).toFixed(1).replace('.', ',')} km` : `${m} m`)

/**
 * Sesi yang dipegang seorang pegawai (dari jadwal + pola + sesi), untuk pemeriksaan di sisi tampilan.
 * jadwal: baris employee_schedules milik pegawai; pola, sesi: seluruh data.
 */
export function sesiPegawai(jadwalPegawai, pola, sesi) {
  const out = []
  for (const j of jadwalPegawai.filter((x) => x.aktif)) {
    const p = pola.find((x) => x.id === j.pattern_id)
    if (!p || !p.aktif) continue
    for (const s of sesi.filter((x) => x.pattern_id === p.id && x.aktif)) {
      if (j.sesi_dipegang?.length && !j.sesi_dipegang.includes(s.id)) continue
      out.push({ ...s, pola: p })
    }
  }
  return out
}

/**
 * Pasangan sesi wajib yang bertumpuk pada hari yang sama (pola shift dilewati karena bergantung jadwal shift).
 * Mengembalikan [{ a, b, hari: [..] }]
 */
export function cariBertumpuk(daftarSesi) {
  const wajib = daftarSesi.filter((s) => !s.opsional && s.pola.jenis !== 'shift')
  const hasil = []
  for (let i = 0; i < wajib.length; i++) {
    for (let k = i + 1; k < wajib.length; k++) {
      const a = wajib[i]; const b = wajib[k]
      if (a.pattern_id === b.pattern_id && a.kode === b.kode) continue
      const hari = a.hari.filter((h) => b.hari.includes(h))
      if (!hari.length) continue
      const a1 = keMenit(a.jam_mulai); const a2 = a1 + durasi(a)
      const b1 = keMenit(b.jam_mulai); const b2 = b1 + durasi(b)
      if (a1 < b2 && b1 < a2) hasil.push({ a, b, hari })
    }
  }
  return hasil
}

// ---------------- Status presensi (dipakai halaman presensi, beranda, dan rekap) ----------------
export const STATUS_PRESENSI = {
  hadir: { n: 'Hadir', w: 'presensi' }, terlambat: { n: 'Terlambat', w: 'tahfizh' }, dinas_luar: { n: 'Dinas luar', w: 'santri' },
  menunggu_verval: { n: 'Menunggu verval', w: 'pengajuan' }, izin: { n: 'Izin', w: 'pegawai' }, sakit: { n: 'Sakit', w: 'klinik' },
  cuti: { n: 'Cuti', w: 'profil' }, tanpa_keterangan: { n: 'Tanpa keterangan', w: 'beranda' },
}
export const STATUS_PULANG = {
  belum: { n: 'Belum pulang', w: 'hakakses' }, tepat: { n: 'Pulang tepat', w: 'presensi' }, cepat: { n: 'Pulang cepat', w: 'tahfizh' },
  tidak_presensi: { n: 'Tidak presensi pulang', w: 'laporan' }, menunggu_verval: { n: 'Pulang menunggu verval', w: 'pengajuan' },
}
export const KEADAAN_SESI = {
  akan_datang: { n: 'Akan datang', w: 'hakakses' }, terbuka: { n: 'Sedang terbuka', w: 'presensi' },
  menunggu_pulang: { n: 'Berlangsung', w: 'santri' }, selesai: { n: 'Selesai', w: 'presensi' }, terlewat: { n: 'Terlewat', w: 'beranda' },
}
/** Status gabungan satu sesi untuk lencana: status presensi bila ada, selain itu keadaan sesi */
export function lencanaSesi(s) {
  if (s.status) return STATUS_PRESENSI[s.status] || { n: s.status, w: 'hakakses' }
  if (s.opsional && s.keadaan === 'terlewat') return { n: 'Tidak dipakai', w: 'hakakses' }
  return KEADAAN_SESI[s.keadaan] || { n: s.keadaan, w: 'hakakses' }
}
/** Id perangkat acak yang tetap (dipakai deteksi satu perangkat banyak akun) */
export function idPerangkat() {
  try {
    let v = localStorage.getItem('simka.perangkat')
    if (!v) { v = (crypto.randomUUID?.() || Math.random().toString(36).slice(2) + Date.now().toString(36)).replace(/-/g, ''); localStorage.setItem('simka.perangkat', v) }
    return v
  } catch { return null }
}
/** Id permintaan unik untuk satu kali presensi (dipakai ulang saat Coba lagi) */
export const idPermintaan = () => (crypto.randomUUID?.() || `${Date.now()}-${Math.random().toString(36).slice(2)}`).replace(/[^A-Za-z0-9_-]/g, '')
