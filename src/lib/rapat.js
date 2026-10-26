// SIMKA PRO | src/lib/rapat.js | v1.1 | 14.29.0: urutan jabatan peserta; notulen berformat di laporan WA | 26/10/2026
import { formatHari, formatPanjang } from './tanggal'
import { halamanAplikasi } from './wa'
import { teksWA } from './teksKaya'

export const JENIS_RAPAT = {
  pimpinan: { n: 'Rapat pimpinan', w: 'pengumuman' },
  bidang: { n: 'Rapat bidang', w: 'walikelas' },
  rutin: { n: 'Rapat rutin', w: 'rapat' },
  koordinasi: { n: 'Rapat koordinasi', w: 'agenda' },
  tim: { n: 'Rapat tim/panitia', w: 'kelompoksantri' },
  lainnya: { n: 'Rapat lainnya', w: 'audit' },
}
export const STATUS_RAPAT = { dijadwalkan: { n: 'Dijadwalkan', w: 'agenda' }, selesai: { n: 'Selesai', w: 'presensi' }, batal: { n: 'Dibatalkan', w: 'klinik' } }
export const KONFIRMASI = {
  menunggu: { n: 'Belum konfirmasi', w: 'audit' }, hadir: { n: 'Akan hadir', w: 'presensi' }, izin: { n: 'Izin', w: 'pengajuan' },
  sakit: { n: 'Sakit', w: 'klinik' }, dinas_luar: { n: 'Dinas luar', w: 'agenda' },
}
export const KEHADIRAN = {
  hadir: { n: 'Hadir', k: 'H', w: 'presensi' }, terlambat: { n: 'Terlambat', k: 'T', w: 'prestasi' }, izin: { n: 'Izin', k: 'I', w: 'pengajuan' },
  sakit: { n: 'Sakit', k: 'S', w: 'klinik' }, dinas_luar: { n: 'Dinas luar', k: 'DL', w: 'agenda' }, alpa: { n: 'Tanpa keterangan', k: 'A', w: 'beranda' },
}
export const HADIR = (k) => k === 'hadir' || k === 'terlambat'
export const jamRapat = (r) => [r.jam_mulai, r.jam_selesai].filter(Boolean).map((j) => String(j).slice(0, 5).replace(':', '.')).join('–')
export const persenHadir = (hadir, total) => (total ? Math.round((hadir / total) * 100) : 0)

/** Ringkasan kehadiran dari daftar peserta (kehadiran tercatat; bila belum, konfirmasi). */
export function ringkasPeserta(peserta = []) {
  const n = peserta.length
  const hadir = peserta.filter((p) => HADIR(p.kehadiran)); const terlambat = peserta.filter((p) => p.kehadiran === 'terlambat')
  const izin = peserta.filter((p) => ['izin', 'sakit', 'dinas_luar'].includes(p.kehadiran))
  const alpa = peserta.filter((p) => p.kehadiran === 'alpa'); const belum = peserta.filter((p) => !p.kehadiran)
  return { n, hadir, terlambat, izin, alpa, belum, persen: persenHadir(hadir.length, n),
    konf: { hadir: peserta.filter((p) => p.konfirmasi === 'hadir').length, izin: peserta.filter((p) => ['izin', 'sakit', 'dinas_luar'].includes(p.konfirmasi)).length,
      menunggu: peserta.filter((p) => p.konfirmasi === 'menunggu').length } }
}
const daftar = (xs, f = (p) => p.nama) => xs.map((p, i) => `${i + 1}. ${f(p)}`).join('\n')

/** Laporan instan rapat untuk grup WhatsApp. format: lengkap | ringkas */
export function laporanRapatWA(D, format = 'lengkap') {
  const r = D.rapat; const s = ringkasPeserta(D.peserta)
  const baris = [`*LAPORAN ${String(JENIS_RAPAT[r.jenis]?.n || 'Rapat').toUpperCase()}*`, `*${r.judul}*`, '',
    `🗓️ ${formatHari(r.tanggal)}${jamRapat(r) ? ' · ' + jamRapat(r) + ' WITA' : ''}`, r.lokasi ? `📍 ${r.lokasi}` : '', r.pimpinan ? `👤 Pimpinan rapat: ${r.pimpinan}` : '', r.notulis ? `📝 Notulis: ${r.notulis}` : '', '',
    `*Kehadiran: ${s.hadir.length}/${s.n} peserta (${s.persen}%)*`, `✅ Hadir ${s.hadir.length}${s.terlambat.length ? ` (terlambat ${s.terlambat.length})` : ''} · 📨 Izin/sakit/dinas ${s.izin.length} · ❌ Tanpa keterangan ${s.alpa.length}${s.belum.length ? ` · ⏳ Belum dicatat ${s.belum.length}` : ''}`]
  if (format === 'lengkap') {
    if (s.hadir.length) baris.push('', '*Hadir:*', daftar(s.hadir, (p) => p.nama + (p.kehadiran === 'terlambat' ? ' (terlambat)' : '')))
    if (s.izin.length) baris.push('', '*Izin/sakit/dinas luar:*', daftar(s.izin, (p) => `${p.nama} – ${KEHADIRAN[p.kehadiran]?.n}${p.alasan ? ': ' + p.alasan : ''}`))
    if (s.alpa.length) baris.push('', '*Tanpa keterangan:*', daftar(s.alpa))
  }
  if (r.pembahasan) baris.push('', '*Pokok pembahasan:*', teksWA(r.pembahasan))
  if (r.keputusan) baris.push('', '*Keputusan/hasil:*', teksWA(r.keputusan))
  const tl = (r.tindak_lanjut || []).filter((t) => t.tugas)
  if (tl.length) baris.push('', '*Tindak lanjut:*', daftar(tl, (t) => `${t.tugas}${t.pj ? ' — PJ: ' + t.pj : ''}${t.tenggat ? ' (tenggat ' + formatPanjang(t.tenggat) + ')' : ''}`))
  baris.push('', `Notulen lengkap: ${halamanAplikasi('/rapat/' + r.id)}`)
  return baris.filter((x, i, a) => !(x === '' && a[i - 1] === '')).join('\n').replace(/\n{3,}/g, '\n\n').trim()
}

/** Pesan undangan/pengingat pribadi via WhatsApp. */
export function pesanPengingatRapat(r, p) {
  return [`Assalamu'alaikum ${p.nama},`, '', `Mengingatkan undangan *${r.judul}*:`, `🗓️ ${formatHari(r.tanggal)}${jamRapat(r) ? ' · ' + jamRapat(r) + ' WITA' : ''}`,
    r.lokasi ? `📍 ${r.lokasi}` : '', r.tautan ? `🔗 ${r.tautan}` : '', '',
    p.konfirmasi === 'menunggu' ? 'Mohon konfirmasi kehadiran di SIMKA:' : 'Detail rapat di SIMKA:', halamanAplikasi('/rapat/' + r.id), '', 'Jazakumullahu khairan.'].filter((x, i, a) => !(x === '' && a[i - 1] === '')).join('\n')
}

// 14.29.0: urutan jabatan (sama dengan fungsi SQL _urut_jabatan) — Ketua Yayasan, Pengurus Yayasan, Direktur, Wakil Direktur, Kepala Bidang/Sekolah,
// Wakil Kepala, Bendahara, Kepala Unit, Tata Usaha, struktural lain, Operator, lalu jabatan fungsional menurut urutannya.
const URUT_STRUKTURAL = [[/ketua.*yayasan/i, 10], [/yayasan/i, 20], [/wakil direktur/i, 40], [/direktur|mudir/i, 30], [/wakil kepala/i, 60], [/kepala (bidang|sekolah)/i, 50],
  [/bendahara/i, 70], [/kepala unit/i, 80], [/tata usaha/i, 90]]
const URUT_FUNGSIONAL = ['operator', 'guru', 'wali kelas', 'muhaffizh', 'musyrif', 'pembina ekskul', 'staf bidang', 'staf pembantu', 'kesehatan', 'medis', 'keamanan', 'security', 'kebersihan', 'logistik', 'media', 'sarana', 'pelatih']
/** Urutan dari nama jabatan (mode demo; data asli memakai nilai 'urut' dari server). */
export function urutJabatan(struktural, fungsional = []) {
  if (struktural) { const x = URUT_STRUKTURAL.find(([re]) => re.test(struktural)); return x ? x[1] : 100 }
  const f = (fungsional || []).map((n) => URUT_FUNGSIONAL.findIndex((k) => String(n).toLowerCase().includes(k))).filter((i) => i >= 0)
  return f.length ? (Math.min(...f) === 0 ? 200 : 300 + Math.min(...f)) : 900
}
export const urutkanPeserta = (xs) => [...xs].sort((a, b) => (a.urut ?? 900) - (b.urut ?? 900) || String(a.nama).localeCompare(String(b.nama), 'id'))
