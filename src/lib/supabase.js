// SIMKA PRO | src/lib/supabase.js | v1.1 | Fase 2 – Tahap 4 Halaman presensi | 03/10/2026
// Klien Supabase. Tanpa VITE_SUPABASE_URL aplikasi berjalan dalam MODE DEMO
// (data contoh di memori) agar tampilan dapat dicoba sebelum server siap.
import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL
const anon = import.meta.env.VITE_SUPABASE_ANON_KEY

export const MODE_DEMO = !url || !anon || import.meta.env.MODE === 'demo'
export const supabase = MODE_DEMO
  ? null
  : createClient(url, anon, { auth: { persistSession: true, autoRefreshToken: true, storageKey: 'simka.sesi' } })

/** Memanggil Edge Function dan mengembalikan JSON; galat dari server dilempar sebagai Error berbahasa Indonesia. */
export async function panggilFungsi(nama, isi = {}) {
  const { data: { session } = {} } = await supabase.auth.getSession()
  const r = await fetch(`${url}/functions/v1/${nama}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: anon,
      Authorization: `Bearer ${session?.access_token ?? anon}`,
    },
    body: JSON.stringify(isi),
  })
  let data = {}
  try { data = await r.json() } catch { /* bukan JSON */ }
  if (!r.ok && !data.status) throw new Error(data.galat || 'Server tidak dapat dihubungi. Periksa koneksi lalu coba lagi.')
  return { ok: r.ok, ...data }
}

/**
 * Kirim formulir multipart (berkas + isian) ke Edge Function. Galat dilempar dengan:
 *   e.kode     — kode galat dari server (contoh CEK_KEDALUWARSA)
 *   e.jaringan — true bila sinyal putus/waktu habis (boleh "Coba lagi" dengan permintaan yang sama)
 */
export async function kirimFormulir(nama, formData, batasMs = 45000) {
  const { data: { session } = {} } = await supabase.auth.getSession()
  const henti = new AbortController(); const t = setTimeout(() => henti.abort(), batasMs)
  let r
  try {
    r = await fetch(`${url}/functions/v1/${nama}`, {
      method: 'POST', body: formData, signal: henti.signal,
      headers: { apikey: anon, Authorization: `Bearer ${session?.access_token ?? anon}` },
    })
  } catch {
    const e = new Error('Koneksi terputus atau sinyal lemah. Tekan Coba lagi.'); e.jaringan = true; throw e
  } finally { clearTimeout(t) }
  let data = {}
  try { data = await r.json() } catch { /* bukan JSON */ }
  if (!r.ok) {
    const e = new Error(data.galat || 'Server tidak dapat dihubungi. Tekan Coba lagi.')
    e.kode = data.kode || null; e.jaringan = !data.kode && r.status >= 500
    throw e
  }
  return data
}
