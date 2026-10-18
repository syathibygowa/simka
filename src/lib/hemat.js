// SIMKA PRO | src/lib/hemat.js | v1.0 | 14.12.0: penghemat permintaan ke server (peredam pembaruan langsung dan muat berkala saat layar terlihat) | 18/10/2026
// Setiap permintaan ke Supabase tercatat sebagai log (kuota "Logs Ingest"). Dua alat ini mengurangi permintaan berulang:
//   redam(fn, jeda)    — pemicu beruntun (mis. 100 presensi masuk berdekatan) digabung menjadi paling banyak satu muat ulang per `jeda` ms;
//                        saat tab/aplikasi tidak terlihat, muat ulang ditunda sampai layar dibuka kembali.
//   berkala(fn, ms)    — muat ulang berkala hanya saat layar terlihat; saat layar dibuka kembali dan sudah lewat `ms`, langsung dimuat.
const terlihat = () => typeof document === 'undefined' || document.visibilityState !== 'hidden'

export const JEDA_LANGSUNG = 10000   // paling sering satu muat ulang per 10 detik dari pembaruan langsung
const JEDA_MIN = 1500                // tunggu 1,5 detik agar perubahan beruntun tergabung

export function redam(fn, jeda = JEDA_LANGSUNG) {
  let akhir = 0; let tunda = null; let tertunda = false
  const jalan = () => {
    tunda = null
    if (!terlihat()) { tertunda = true; return }
    akhir = Date.now(); fn()
  }
  if (typeof document !== 'undefined') {
    document.addEventListener('visibilitychange', () => { if (tertunda && terlihat()) { tertunda = false; jalan() } })
  }
  return () => {
    if (tunda) return
    tunda = setTimeout(jalan, Math.max(JEDA_MIN, akhir + jeda - Date.now()))
  }
}

/** Mengembalikan fungsi penghenti. */
export function berkala(fn, ms) {
  let akhir = Date.now()
  const jalan = () => { if (!terlihat()) return; akhir = Date.now(); fn() }
  const id = setInterval(jalan, ms)
  const lihat = () => { if (terlihat() && Date.now() - akhir >= ms) jalan() }
  if (typeof document !== 'undefined') document.addEventListener('visibilitychange', lihat)
  return () => { clearInterval(id); if (typeof document !== 'undefined') document.removeEventListener('visibilitychange', lihat) }
}
