// SIMKA PRO | src/lib/sandi.js | v1.0 | Fase 1 – Akun dan hak akses | 03/10/2026
// Aturan kata sandi sama dengan pemeriksaan di server (Edge Function): minimal 8 karakter, huruf dan angka.
export function periksaSandi(s, ulang) {
  if (!s || s.length < 8) return 'Kata sandi minimal 8 karakter.'
  if (!/[A-Za-z]/.test(s) || !/[0-9]/.test(s)) return 'Kata sandi harus memuat huruf dan angka.'
  if (ulang !== undefined && s !== ulang) return 'Ulangi kata sandi belum sama.'
  return ''
}
/** Kekuatan 0–3 untuk penanda di bawah isian */
export function kekuatanSandi(s = '') {
  let n = 0
  if (s.length >= 8) n++
  if (/[A-Za-z]/.test(s) && /[0-9]/.test(s)) n++
  if (s.length >= 12 && /[^A-Za-z0-9]/.test(s)) n++
  return n
}
