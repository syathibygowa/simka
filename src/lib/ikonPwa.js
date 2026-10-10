// SIMKA PRO | src/lib/ikonPwa.js | v1.2 | Fase 8 – Perbaikan: nama menu ringkas | 10/10/2026
// Ikon TAB peramban dan ikon layar utama iOS mengikuti "Ikon SIMKA PRO" dari Setelan → Identitas lembaga.
// PERUBAHAN v1.1: manifest PWA TIDAK LAGI dibuat ulang di peramban. Manifest buatan (data URL dengan ikon berubah-ubah)
// membuat Chrome menganggap aplikasi terpasang (WebAPK) terus berubah sehingga memicu pemasangan/pembaruan berulang,
// yang pada peluncur Xiaomi/Redmi (MIUI/HyperOS) dapat membuat layar utama tertutup-terbuka terus.
// Manifest kini selalu berkas tetap hasil build (public/ikon/*), dengan id tetap.
function muatGambar(url) {
  return new Promise((ok, gagal) => {
    const img = new Image(); img.crossOrigin = 'anonymous'
    img.onload = () => ok(img); img.onerror = gagal
    img.src = url + (url.includes('?') ? '&' : '?') + 'pwa=1'
  })
}
function pasangLink(rel, href, sizes) {
  let el = document.querySelector(`link[rel="${rel}"]`)
  if (!el) { el = document.createElement('link'); el.rel = rel; document.head.appendChild(el) }
  el.href = href; if (sizes) el.sizes = sizes
}
/** Hanya ikon tab peramban dan ikon iOS; manifest tidak disentuh. */
export async function terapkanIkonPwa(url) {
  if (!url) return false
  pasangLink('icon', url)
  if (!/iPad|iPhone|iPod/.test(navigator.userAgent)) return true
  try {
    const img = await muatGambar(url)
    const c = document.createElement('canvas'); c.width = 180; c.height = 180
    const g = c.getContext('2d'); g.fillStyle = '#FFFFFF'; g.fillRect(0, 0, 180, 180)
    const s = Math.min(151 / img.naturalWidth, 151 / img.naturalHeight); const w = img.naturalWidth * s; const h = img.naturalHeight * s
    g.drawImage(img, (180 - w) / 2, (180 - h) / 2, w, h)
    pasangLink('apple-touch-icon', c.toDataURL('image/png'), '180x180')
  } catch { /* ikon iOS bawaan tetap dipakai */ }
  return true
}
