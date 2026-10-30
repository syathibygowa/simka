// SIMKA PRO | src/lib/supabase.js | v1.4 | 14.36.0: batas waktu 30 detik per permintaan (tidak lagi memproses tanpa akhir saat server ramai) | 30/10/2026
// Klien Supabase. Tanpa VITE_SUPABASE_URL aplikasi berjalan dalam MODE DEMO
// (data contoh di memori) agar tampilan dapat dicoba sebelum server siap.
import { createClient } from '@supabase/supabase-js'
import { redam } from './hemat'
import { pasangHalamanOtomatis } from './halaman'

const url = import.meta.env.VITE_SUPABASE_URL
const anon = import.meta.env.VITE_SUPABASE_ANON_KEY

export const MODE_DEMO = !url || !anon || import.meta.env.MODE === 'demo'

// 14.36.0: setiap permintaan data dibatasi 30 detik. Saat server sibuk (mis. puluhan pegawai masuk bersamaan), halaman tidak lagi
// "memproses terus": permintaan dihentikan, pesan "Server sibuk" tampil, dan pengguna dapat mencoba lagi. Unggahan berkas tidak dibatasi.
export const BATAS_PERMINTAAN_MS = 30000
function fetchBerbatas(input, init = {}) {
  const alamat = typeof input === 'string' ? input : input?.url || ''
  if (init.signal || alamat.includes('/storage/v1/')) return fetch(input, init)
  const henti = new AbortController(); const t = setTimeout(() => henti.abort(), BATAS_PERMINTAAN_MS)
  return fetch(input, { ...init, signal: henti.signal })
    .catch((e) => {
      if (e?.name !== 'AbortError') throw e
      const g = new Error('server belum menjawab dalam 30 detik (sedang ramai atau koneksi lambat). Silakan coba lagi sebentar.'); g.name = 'Server sibuk'; throw g
    })
    .finally(() => clearTimeout(t))
}
export const supabase = MODE_DEMO
  ? null
  : createClient(url, anon, { auth: { persistSession: true, autoRefreshToken: true, storageKey: 'simka.sesi' }, global: { fetch: fetchBerbatas } })

// Pembaruan langsung (postgres_changes) yang hanya memicu "muat ulang" (fungsi tanpa argumen) diredam: perubahan beruntun
// digabung menjadi paling banyak satu muat ulang per 10 detik dan ditunda saat layar tidak terlihat. Penangan yang membaca
// isi perubahan (mis. notifikasi baru) tetap menerima setiap kejadian.
if (supabase) {
  const kanalAsli = supabase.channel.bind(supabase)
  supabase.channel = (...arg) => {
    const ch = kanalAsli(...arg); const onAsli = ch.on.bind(ch)
    ch.on = (jenis, saring, fn) => onAsli(jenis, saring, jenis === 'postgres_changes' && typeof fn === 'function' && fn.length === 0 ? redam(fn) : fn)
    return ch
  }
}

// 14.14.0: jawaban lebih dari 1.000 baris dilanjutkan otomatis per halaman (lihat halaman.js)
if (supabase) pasangHalamanOtomatis(supabase)

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
