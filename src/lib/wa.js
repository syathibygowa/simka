// SIMKA PRO | src/lib/wa.js | v1.1 | Fase 1 – Akun dan hak akses | 03/10/2026
// Tautan WhatsApp wa.me dari WA pribadi pegawai (Bagian 25). Templat dapat diatur superadmin pada Fase 3.
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

export const TEMPLAT_WA = {
  aktivasi: (p) => `Assalamu'alaikum warahmatullahi wabarakatuh, ${p.nama}.\n\nAkun SIMKA PRO Anda telah aktif. Silakan masuk di ${alamatAplikasi()} dengan username *${p.username}* dan kata sandi yang Anda buat saat mendaftar.\n\nJazakumullahu khairan.\nAdmin SIMKA PRO Imam Asy-Syathiby`,
  ditolak: (p) => `Assalamu'alaikum warahmatullahi wabarakatuh, ${p.nama}.\n\nPendaftaran akun SIMKA PRO Anda belum dapat disetujui dengan catatan: ${p.catatan}\n\nSilakan hubungi admin pondok untuk keterangan lebih lanjut.\nAdmin SIMKA PRO Imam Asy-Syathiby`,
  sandiSementara: (p) => `Assalamu'alaikum warahmatullahi wabarakatuh, ${p.nama}.\n\nKata sandi sementara akun SIMKA PRO Anda:\nUsername: *${p.username}*\nKata sandi: *${p.sandi}*\n\nSilakan masuk di ${alamatAplikasi()} lalu ganti kata sandi saat diminta. Jangan bagikan pesan ini kepada siapa pun.\nAdmin SIMKA PRO Imam Asy-Syathiby`,
}
