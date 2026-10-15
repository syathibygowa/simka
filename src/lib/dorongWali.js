// SIMKA PRO | src/lib/dorongWali.js | v1.0 | Fase 9 – Tahap 13.3.0 Notifikasi HP untuk wali | 15/10/2026
// Notifikasi dorong (web push) Portal Wali: HP wali menerima pemberitahuan saat ada pengumuman untuk anaknya,
// walaupun portal sedang tertutup. Langganan disimpan per sesi wali (per anak), memakai kunci VAPID yang sama
// dengan notifikasi pegawai, dan dikirim oleh Edge Function "dorong" yang sudah ada.
// Mematikan hanya menghapus langganan di server untuk anak itu (langganan peramban tidak dicabut karena
// dapat dipakai bersama akun pegawai atau anak lain di HP yang sama).
import { supabase, MODE_DEMO, panggilFungsi } from '@/lib/supabase'
import { dukungan } from '@/lib/dorong'
import { namaPerangkat } from '@/lib/portalWali'

export { dukungan }

function keUint8(b64) {
  const pad = '='.repeat((4 - (b64.length % 4)) % 4)
  const s = atob((b64 + pad).replace(/-/g, '+').replace(/_/g, '/'))
  return Uint8Array.from(s, (c) => c.charCodeAt(0))
}
async function registrasi() {
  return Promise.race([navigator.serviceWorker.ready,
    new Promise((_, gagal) => setTimeout(() => gagal(new Error('Layanan latar aplikasi belum siap. Muat ulang halaman lalu coba lagi.')), 8000))])
}
async function kunciPublik() {
  const { data } = await supabase.rpc('portal_kunci_dorong')
  if (data) return data
  const r = await panggilFungsi('dorong', { aksi: 'kunci' })
  if (!r.publik) throw new Error('Layanan notifikasi HP belum siap di server pondok.')
  return r.publik
}
async function langgananPeramban(buat = false) {
  const reg = await registrasi()
  let sub = await reg.pushManager.getSubscription()
  if (!sub && buat) sub = await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: keUint8(await kunciPublik()) })
  return sub
}

/** Status notifikasi HP untuk anak (token sesi) di perangkat ini. */
export async function statusWali(token) {
  if (MODE_DEMO || dukungan() !== 'siap' || Notification.permission !== 'granted') return false
  try {
    const sub = await langgananPeramban(false)
    if (!sub) return false
    const { data } = await supabase.rpc('portal_status_dorong', { p_token: token, p_endpoint: sub.endpoint })
    return !!data?.aktif
  } catch { return false }
}

/** Nyalakan notifikasi HP untuk satu atau beberapa anak (daftar token). */
export async function aktifkanWali(tokens) {
  const d = dukungan()
  if (d === 'demo') throw new Error('Mode demo: notifikasi HP tidak tersedia.')
  if (d === 'perlu_dipasang') throw new Error('Di iPhone, pasang portal ke Layar Utama lebih dulu (Bagikan → Tambahkan ke Layar Utama), lalu buka dari ikon tersebut.')
  if (d === 'tidak_didukung') throw new Error('Peramban ini belum mendukung notifikasi HP. Gunakan Chrome versi terbaru.')
  if (d === 'ditolak') throw new Error('Izin notifikasi diblokir. Buka pengaturan situs di peramban, izinkan Notifikasi, lalu coba lagi.')
  if ((await Notification.requestPermission()) !== 'granted') throw new Error('Izin notifikasi tidak diberikan.')
  const j = (await langgananPeramban(true)).toJSON()
  for (const token of tokens) {
    const { data, error } = await supabase.rpc('portal_daftar_dorong', { p_token: token, p_endpoint: j.endpoint, p_p256dh: j.keys.p256dh, p_auth: j.keys.auth, p_perangkat: namaPerangkat() })
    if (error || data?.galat) throw new Error(data?.galat || 'Perangkat gagal didaftarkan. Coba lagi.')
  }
  return true
}

/** Matikan notifikasi HP untuk anak (token sesi) di perangkat ini. */
export async function matikanWali(token) {
  if (MODE_DEMO) return
  let endpoint = null
  try { endpoint = (await langgananPeramban(false))?.endpoint || null } catch { /* tetap hapus semua langganan sesi ini */ }
  await supabase.rpc('portal_hapus_dorong', { p_token: token, p_endpoint: endpoint })
}
