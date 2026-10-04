// SIMKA PRO | src/lib/ikonPwa.js | v1.0 | Fase 4 – Perbaikan P3 (ikon PWA dari Pengaturan) | 05/10/2026
// Ikon aplikasi terpasang (PWA Android/desktop), ikon layar utama iOS, dan ikon tab peramban mengikuti
// "Ikon SIMKA PRO" yang diunggah di Pengaturan → Identitas lembaga.
// Caranya: gambar ikon digambar ulang ke kanvas (192, 512, maskable 512, Apple 180) lalu manifest PWA dibuat ulang
// sebagai data URL. Pemasangan baru langsung memakai ikon ini; aplikasi yang sudah terpasang perlu dipasang ulang.
const NAMA = 'SIMKA PRO Imam Asy-Syathiby'

function muatGambar(url) {
  return new Promise((ok, gagal) => {
    const img = new Image(); img.crossOrigin = 'anonymous'
    img.onload = () => ok(img); img.onerror = gagal
    img.src = url + (url.includes('?') ? '&' : '?') + 'pwa=1'
  })
}
/** Gambar ikon persegi; maskable/apple: latar putih dan logo di zona aman. */
function gambar(img, n, { latar = null, isi = 1 } = {}) {
  const c = document.createElement('canvas'); c.width = n; c.height = n
  const g = c.getContext('2d')
  if (latar) { g.fillStyle = latar; g.fillRect(0, 0, n, n) }
  const sisi = n * isi; const skala = Math.min(sisi / img.naturalWidth, sisi / img.naturalHeight)
  const w = img.naturalWidth * skala; const h = img.naturalHeight * skala
  g.imageSmoothingQuality = 'high'
  g.drawImage(img, (n - w) / 2, (n - h) / 2, w, h)
  return c.toDataURL('image/png')
}
function pasangLink(rel, href, sizes) {
  let el = document.querySelector(`link[rel="${rel}"]`)
  if (!el) { el = document.createElement('link'); el.rel = rel; document.head.appendChild(el) }
  el.href = href; if (sizes) el.sizes = sizes; el.type = 'image/png'
}

export async function terapkanIkonPwa(url) {
  if (!url) return false
  try {
    const img = await muatGambar(url)
    const i192 = gambar(img, 192, { isi: 0.92 }); const i512 = gambar(img, 512, { isi: 0.92 })
    const mask = gambar(img, 512, { latar: '#FFFFFF', isi: 0.72 }); const apple = gambar(img, 180, { latar: '#FFFFFF', isi: 0.84 })
    pasangLink('icon', i192, '192x192'); pasangLink('apple-touch-icon', apple, '180x180')
    const dasar = new URL('./', location.href.split('#')[0]).href
    const manifest = {
      name: NAMA, short_name: 'SIMKA PRO', description: 'Sistem Manajemen Kepegawaian Terintegrasi Pondok Pesantren Imam Asy-Syathiby',
      lang: 'id', theme_color: '#C7332F', background_color: '#FAF6F3', display: 'standalone', orientation: 'portrait',
      start_url: dasar, scope: dasar, id: dasar,
      icons: [{ src: i192, sizes: '192x192', type: 'image/png' }, { src: i512, sizes: '512x512', type: 'image/png' },
        { src: mask, sizes: '512x512', type: 'image/png', purpose: 'maskable' }],
    }
    let el = document.querySelector('link[rel="manifest"]')
    if (!el) { el = document.createElement('link'); el.rel = 'manifest'; document.head.appendChild(el) }
    el.href = 'data:application/manifest+json;charset=utf-8,' + encodeURIComponent(JSON.stringify(manifest))
    return true
  } catch {
    // Gambar tidak dapat dibaca (mis. diblokir situs asalnya): ikon tab tetap memakai alamat asli, manifest bawaan dipertahankan
    pasangLink('icon', url); return false
  }
}
