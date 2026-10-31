// SIMKA PRO | src/lib/hemat.js | v1.1 | 14.37.0: peredam dapat dibatalkan (pendengar tidak menumpuk, tidak memuat halaman yang sudah ditutup) | 30/10/2026
// Setiap permintaan ke Supabase tercatat sebagai log (kuota "Logs Ingest"). Dua alat ini mengurangi permintaan berulang:
//   redam(fn, jeda)    — pemicu beruntun (mis. 100 presensi masuk berdekatan) digabung menjadi paling banyak satu muat ulang per `jeda` ms;
//                        saat tab/aplikasi tidak terlihat, muat ulang ditunda sampai layar dibuka kembali.
//                        14.37.0: hasilnya punya .batal() (dipanggil otomatis saat kanal Realtime dihentikan, lihat supabase.js).
//                        Sebelumnya setiap pembukaan halaman menambah satu pendengar "layar terlihat" yang tidak pernah dilepas,
//                        sehingga setelah lama dipakai, membuka aplikasi kembali memicu muat ulang data halaman yang sudah ditutup.
//   berkala(fn, ms)    — muat ulang berkala hanya saat layar terlihat; saat layar dibuka kembali dan sudah lewat `ms`, langsung dimuat.
const terlihat = () => typeof document === 'undefined' || document.visibilityState !== 'hidden'

export const JEDA_LANGSUNG = 10000   // paling sering satu muat ulang per 10 detik dari pembaruan langsung
const JEDA_MIN = 1500                // tunggu 1,5 detik agar perubahan beruntun tergabung

export function redam(fn, jeda = JEDA_LANGSUNG) {
  let akhir = 0; let tunda = null; let tertunda = false; let batal = false
  const jalan = () => {
    tunda = null
    if (batal) return
    if (!terlihat()) { tertunda = true; return }
    akhir = Date.now(); fn()
  }
  const lihat = () => { if (tertunda && terlihat()) { tertunda = false; jalan() } }
  if (typeof document !== 'undefined') document.addEventListener('visibilitychange', lihat)
  const picu = () => {
    if (tunda || batal) return
    tunda = setTimeout(jalan, Math.max(JEDA_MIN, akhir + jeda - Date.now()))
  }
  picu.batal = () => {
    batal = true; tertunda = false
    if (tunda) { clearTimeout(tunda); tunda = null }
    if (typeof document !== 'undefined') document.removeEventListener('visibilitychange', lihat)
  }
  return picu
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
