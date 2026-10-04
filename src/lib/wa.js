// SIMKA PRO | src/lib/wa.js | v1.5 | Fase 4 – Tahap 1 Data santri | 04/10/2026
// Tautan WhatsApp wa.me dari WA pribadi pegawai (Bagian 25). Isi pesan diambil dari template WA yang
// dikelola superadmin (Pengaturan → Template WA); bila belum dimuat, dipakai isi bawaan di bawah.
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { useLembaga } from '@/stores/lembaga'
import { useSesi } from '@/stores/sesi'
import { formatHari, formatJam, sekarang } from '@/lib/tanggal'

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
  pengumuman: '{salam}, {nama}.\n\n*{judul}*\n{isi_singkat}\n\nSelengkapnya di SIMKA PRO: {tautan}\n\n{penutup}\n{pengirim}',
  berkas_baru: '{salam}, {nama}.\n\nAda {kategori} untuk Anda di menu Berkas Saya SIMKA PRO:\n*{judul}*\n\nSilakan dibuka di {tautan}\n\n{penutup}\n{pengirim}',
  pengajuan_status: '{salam}, {nama}.\n\nPengajuan {jenis} Anda ({tanggal}, {lama}) saat ini *{status}*.\n{alasan}\n\nRincian dan surat: {tautan}\n\n{penutup}\n{pengirim}',
  pengajuan_pengingat: '{salam}, {nama}.\n\nMohon maaf mengganggu. Ada pengajuan {jenis} dari {pemohon} ({tanggal}, {lama}) yang menunggu persetujuan Anda sebagai {jabatan}.\n\nSilakan diputuskan di SIMKA PRO: {tautan}\n\n{penutup}\n{pengirim}',
  wali_santri: '{salam}, Bapak/Ibu {nama_wali}.\n\nKami dari {nama_singkat} menyampaikan informasi terkait ananda *{nama_santri}* (NIS {nis}, {kelas}).\n\n{pesan}\n\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
  verval_presensi: '{salam}, {nama}.\n\nPresensi Anda pada sesi {sesi}, {tanggal} telah diverval dengan status *{status_presensi}*.\nCatatan: {catatan_verval}\n\n{penutup}\n{pengirim}',
}

let simpanan = {}
/** Muat template WA dari database (dipanggil saat admin/superadmin masuk). */
export async function muatTemplatWA() {
  if (MODE_DEMO) return
  const { data } = await supabase.from('wa_templates').select('kode, isi, aktif')
  simpanan = Object.fromEntries((data || []).filter((t) => t.aktif).map((t) => [t.kode, t.isi]))
}
export const setelTemplatWA = (kode, isi) => { simpanan[kode] = isi }

/**
 * Katalog isian template WA. "umum" terisi otomatis di setiap pesan (lembaga, waktu, pengirim);
 * kelompok lain diisi oleh menu yang mengirim pesan (pengumuman, agenda, pengajuan, berkas, presensi, akun).
 */
export const ISIAN_WA = [
  { grup: 'Umum (terisi otomatis)', isian: [
    ['salam', "Assalamu'alaikum warahmatullahi wabarakatuh"], ['penutup', 'Jazakumullahu khairan.'],
    ['nama_lembaga', 'Nama lengkap pondok'], ['nama_singkat', 'Nama singkat pondok'], ['alamat_lembaga', 'Alamat pondok'],
    ['telepon_lembaga', 'Telepon pondok'], ['kota', 'Kota surat (Gowa)'], ['hari_ini', 'Hari dan tanggal hari ini'],
    ['jam_sekarang', 'Jam saat ini (WITA)'], ['pengirim', 'Nama pengirim pesan'], ['jabatan_pengirim', 'Jabatan/peran pengirim'],
    ['alamat_aplikasi', 'Alamat SIMKA PRO'],
  ] },
  { grup: 'Penerima (pegawai)', isian: [
    ['nama', 'Nama lengkap penerima'], ['niy', 'NIY penerima'], ['jabatan', 'Jabatan penerima'], ['unit', 'Bidang/unit penerima'], ['username', 'Username akun'],
  ] },
  { grup: 'Akun', isian: [['sandi', 'Kata sandi sementara'], ['catatan', 'Catatan verifikasi/penolakan']] },
  { grup: 'Pengumuman dan berkas', isian: [
    ['judul', 'Judul pengumuman/berkas/agenda'], ['isi_singkat', 'Cuplikan isi pengumuman'], ['kategori', 'Kategori berkas'], ['tautan', 'Tautan terkait (halaman di SIMKA PRO, Zoom, Drive)'],
  ] },
  { grup: 'Agenda', isian: [['tanggal', 'Hari/tanggal agenda'], ['waktu', 'Jam agenda'], ['lokasi', 'Tempat'], ['keterangan', 'Keterangan agenda'], ['pengingat', 'Keterangan pengingat (mis. besok)']] },
  { grup: 'Pengajuan', isian: [['pemohon', 'Nama pemohon'], ['jenis', 'Jenis pengajuan'], ['lama', 'Lama (hari)'], ['nomor', 'Nomor surat'], ['status', 'Status pengajuan'], ['alasan', 'Alasan/catatan']] },
  { grup: 'Presensi', isian: [['sesi', 'Nama sesi presensi'], ['status_presensi', 'Status presensi'], ['catatan_verval', 'Catatan verval admin']] },
  { grup: 'Santri dan wali', isian: [['nama_wali', 'Nama orang tua/wali penerima'], ['hubungan', 'Hubungan (Ayah/Ibu/Wali)'], ['nama_santri', 'Nama santri'], ['nis', 'NIS santri'], ['kelas', 'Kelas santri']] },
  { grup: 'Bebas', isian: [['pesan', 'Isi pesan bebas']] },
]

/** Isian umum yang selalu tersedia. */
export function isianUmum() {
  let l = {}; let p = null
  try { l = useLembaga().identitas || {}; p = useSesi().pengguna } catch { /* di luar aplikasi */ }
  const kini = sekarang()
  return {
    salam: "Assalamu'alaikum warahmatullahi wabarakatuh", penutup: 'Jazakumullahu khairan.',
    nama_lembaga: l.nama_lengkap, nama_singkat: l.nama_singkat, alamat_lembaga: l.alamat, telepon_lembaga: l.telepon, kota: l.kota_surat || 'Gowa',
    hari_ini: formatHari(kini), jam_sekarang: formatJam(kini) + ' WITA',
    pengirim: p?.nama_lengkap, jabatan_pengirim: p?.jabatan_struktural || p?.jabatan_fungsional || (p?.peran === 'superadmin' ? 'Superadmin SIMKA PRO' : p?.peran === 'admin' ? 'Admin SIMKA PRO' : ''),
    alamat_aplikasi: alamatAplikasi(),
  }
}

/** Ganti {isian} dengan data; isian kosong diganti "-" dan baris yang hanya berisi isian kosong dibuang. */
export function isiTemplat(isi, data = {}) {
  const d = { ...isianUmum(), ...Object.fromEntries(Object.entries(data).filter(([, v]) => v != null && v !== '')) }
  return String(isi || '')
    .split('\n')
    .filter((baris) => !/^\s*\{(\w+)\}\s*$/.test(baris) || d[baris.trim().slice(1, -1)])
    .join('\n')
    .replace(/\{(\w+)\}/g, (_, k) => (d[k] == null || d[k] === '' ? '-' : String(d[k])))
    .replace(/\n{3,}/g, '\n\n')
}
/** Tautan halaman SIMKA PRO, mis. halamanAplikasi('/berkas/123'). */
export const halamanAplikasi = (jalur) => `${alamatAplikasi()}#${jalur}`

/** Pesan WA menurut kode template. */
export const pesanWA = (kode, data) => isiTemplat(simpanan[kode] ?? BAWAAN_WA[kode] ?? '{pesan}', data)

// Kompatibel dengan pemanggilan lama (Verifikasi Akun)
export const TEMPLAT_WA = {
  aktivasi: (p) => pesanWA('aktivasi', p),
  ditolak: (p) => pesanWA('ditolak', p),
  sandiSementara: (p) => pesanWA('sandi_sementara', p),
}
