// SIMKA PRO | src/lib/dorong.js | v1.0 | Fase 3 – Tahap 1 Pengumuman, audit log, notifikasi HP | 04/10/2026
// Notifikasi dorong (web push): mendaftarkan HP/peramban ini agar notifikasi SIMKA PRO tetap muncul
// walaupun aplikasi tertutup. Kunci publik VAPID diambil dari database (dibuat otomatis oleh Edge Function "dorong").
import { supabase, MODE_DEMO, panggilFungsi } from '@/lib/supabase'

const iOS = () => /iPhone|iPad|iPod/i.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)
const terpasang = () => window.matchMedia?.('(display-mode: standalone)').matches || navigator.standalone === true

/**
 * Keadaan dukungan di perangkat ini:
 *   'demo' | 'tidak_didukung' | 'perlu_dipasang' (iPhone: pasang ke Layar Utama dulu) | 'ditolak' | 'siap'
 */
export function dukungan() {
  if (MODE_DEMO) return 'demo'
  if (iOS() && !terpasang()) return 'perlu_dipasang'
  if (!('serviceWorker' in navigator) || !('PushManager' in window) || !('Notification' in window)) return 'tidak_didukung'
  if (Notification.permission === 'denied') return 'ditolak'
  return 'siap'
}

async function registrasi() {
  const reg = await Promise.race([
    navigator.serviceWorker.ready,
    new Promise((_, gagal) => setTimeout(() => gagal(new Error('Layanan latar aplikasi belum siap. Muat ulang halaman lalu coba lagi.')), 8000)),
  ])
  return reg
}

/** Apakah perangkat ini sudah berlangganan notifikasi dorong. */
export async function aktifDiSini() {
  if (dukungan() !== 'siap') return false
  try { const reg = await registrasi(); return !!(await reg.pushManager.getSubscription()) } catch { return false }
}

function keUint8(b64) {
  const pad = '='.repeat((4 - (b64.length % 4)) % 4)
  const s = atob((b64 + pad).replace(/-/g, '+').replace(/_/g, '/'))
  return Uint8Array.from(s, (c) => c.charCodeAt(0))
}

async function kunciPublik() {
  const { data } = await supabase.rpc('kunci_dorong')
  if (data) return data
  const r = await panggilFungsi('dorong', { aksi: 'kunci' })
  if (!r.publik) throw new Error('Layanan notifikasi HP belum dipasang di server. Hubungi superadmin.')
  return r.publik
}

function namaPerangkat() {
  const ua = navigator.userAgent
  const os = /Android/i.test(ua) ? 'Android' : iOS() ? 'iPhone/iPad' : /Windows/i.test(ua) ? 'Windows' : /Mac/i.test(ua) ? 'Mac' : 'Perangkat lain'
  const br = /Edg\//.test(ua) ? 'Edge' : /SamsungBrowser/.test(ua) ? 'Samsung Internet' : /Chrome\//.test(ua) ? 'Chrome' : /Firefox\//.test(ua) ? 'Firefox' : /Safari\//.test(ua) ? 'Safari' : 'Peramban'
  return `${os} · ${br}`
}

/** Aktifkan notifikasi dorong di perangkat ini (meminta izin notifikasi). */
export async function aktifkan() {
  const d = dukungan()
  if (d === 'perlu_dipasang') throw new Error('Di iPhone, pasang SIMKA PRO ke Layar Utama lebih dulu (Bagikan → Tambahkan ke Layar Utama), lalu buka dari ikon tersebut.')
  if (d === 'tidak_didukung') throw new Error('Peramban ini belum mendukung notifikasi dorong. Gunakan Chrome versi terbaru.')
  if (d === 'ditolak') throw new Error('Izin notifikasi diblokir. Buka pengaturan situs di peramban, izinkan Notifikasi, lalu coba lagi.')
  const izin = await Notification.requestPermission()
  if (izin !== 'granted') throw new Error('Izin notifikasi tidak diberikan.')
  const reg = await registrasi()
  let sub = await reg.pushManager.getSubscription()
  if (!sub) sub = await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: keUint8(await kunciPublik()) })
  const j = sub.toJSON()
  const { error } = await supabase.rpc('daftar_dorong', { p_endpoint: j.endpoint, p_p256dh: j.keys.p256dh, p_auth: j.keys.auth, p_perangkat: namaPerangkat() })
  if (error) throw new Error('Perangkat gagal didaftarkan ke server. Coba lagi.')
  return true
}

/** Matikan notifikasi dorong di perangkat ini. */
export async function matikan() {
  if (dukungan() !== 'siap') return
  const reg = await registrasi()
  const sub = await reg.pushManager.getSubscription()
  if (!sub) return
  await supabase.rpc('hapus_dorong', { p_endpoint: sub.endpoint })
  await sub.unsubscribe()
}

/** Daftar perangkat yang berlangganan untuk akun ini. */
export async function perangkatSaya() {
  if (MODE_DEMO) return []
  const { data } = await supabase.from('push_subscriptions').select('id, perangkat, created_at, terakhir_ok').order('created_at', { ascending: false })
  return data || []
}
