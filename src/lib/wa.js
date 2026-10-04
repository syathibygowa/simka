// SIMKA PRO | src/lib/wa.js | v1.2 | Fase 3 – Tahap 5 Agenda dan template WA | 04/10/2026
// Tautan WhatsApp wa.me dari WA pribadi pegawai (Bagian 25). Isi pesan diambil dari template WA yang
// dikelola superadmin (Pengaturan → Template WA); bila belum dimuat, dipakai isi bawaan di bawah.
import { supabase, MODE_DEMO } from '@/lib/supabase'

export function nomorWA(hp) {
  let n = String(hp || '').replace(/[^0-9]/g, '')
  if (n.startsWith('0')) n = '62' + n.slice(1)
  else if (n.startsWith('8')) n = '62' + n
  return n
}
export function tautanWA(hp, pesan) {
  return `https://wa.me/${nomorWA(hp)}?text=${encodeURIComponent(pesan)}`
}
export const alamatAplikasi = () => location.origin + location.pathname.replace(/index\.html$/, '')

export const BAWAAN_WA = {
  aktivasi: "Assalamu'alaikum warahmatullahi wabarakatuh, {nama}.\n\nAkun SIMKA PRO Anda telah aktif. Silakan masuk di {alamat_aplikasi} dengan username *{username}* dan kata sandi yang Anda buat saat mendaftar.\n\nJazakumullahu khairan.\nAdmin SIMKA PRO Imam Asy-Syathiby",
  ditolak: "Assalamu'alaikum warahmatullahi wabarakatuh, {nama}.\n\nPendaftaran akun SIMKA PRO Anda belum dapat disetujui dengan catatan: {catatan}\n\nSilakan hubungi admin pondok untuk keterangan lebih lanjut.\nAdmin SIMKA PRO Imam Asy-Syathiby",
  sandi_sementara: "Assalamu'alaikum warahmatullahi wabarakatuh, {nama}.\n\nKata sandi sementara akun SIMKA PRO Anda:\nUsername: *{username}*\nKata sandi: *{sandi}*\n\nSilakan masuk di {alamat_aplikasi} lalu ganti kata sandi saat diminta. Jangan bagikan pesan ini kepada siapa pun.\nAdmin SIMKA PRO Imam Asy-Syathiby",
  undangan_agenda: "Assalamu'alaikum warahmatullahi wabarakatuh, {nama}.\n\nMengingatkan agenda *{judul}*\nHari/tanggal: {tanggal}\nWaktu: {waktu}\nTempat: {lokasi}\n\n{keterangan}\n\nJazakumullahu khairan.\n{pengirim}",
  umum: "Assalamu'alaikum warahmatullahi wabarakatuh, {nama}.\n\n{pesan}\n\nJazakumullahu khairan.\n{pengirim}",
}

let simpanan = {}
/** Muat template WA dari database (dipanggil saat admin/superadmin masuk). */
export async function muatTemplatWA() {
  if (MODE_DEMO) return
  const { data } = await supabase.from('wa_templates').select('kode, isi, aktif')
  simpanan = Object.fromEntries((data || []).filter((t) => t.aktif).map((t) => [t.kode, t.isi]))
}
export const setelTemplatWA = (kode, isi) => { simpanan[kode] = isi }

/** Ganti {isian} dengan data; isian kosong diganti "-" dan baris yang hanya berisi isian kosong dibuang. */
export function isiTemplat(isi, data = {}) {
  const d = { alamat_aplikasi: alamatAplikasi(), ...data }
  return String(isi || '')
    .split('\n')
    .filter((baris) => !/^\s*\{(\w+)\}\s*$/.test(baris) || d[baris.trim().slice(1, -1)])
    .join('\n')
    .replace(/\{(\w+)\}/g, (_, k) => (d[k] == null || d[k] === '' ? '-' : String(d[k])))
    .replace(/\n{3,}/g, '\n\n')
}
/** Pesan WA menurut kode template. */
export const pesanWA = (kode, data) => isiTemplat(simpanan[kode] ?? BAWAAN_WA[kode] ?? '{pesan}', data)

// Kompatibel dengan pemanggilan lama (Verifikasi Akun)
export const TEMPLAT_WA = {
  aktivasi: (p) => pesanWA('aktivasi', p),
  ditolak: (p) => pesanWA('ditolak', p),
  sandiSementara: (p) => pesanWA('sandi_sementara', p),
}
