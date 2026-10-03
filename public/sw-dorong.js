// SIMKA PRO | public/sw-dorong.js | v1.0 | Fase 3 – Tahap 1 Pengumuman, audit log, notifikasi HP | 04/10/2026
// Dimuat oleh service worker PWA (workbox importScripts). Menampilkan notifikasi dorong dari server
// dan membuka halaman terkait saat notifikasi diketuk.
self.addEventListener('push', (event) => {
  let d = {}
  try { d = event.data ? event.data.json() : {} } catch (e) { d = { judul: event.data ? event.data.text() : 'SIMKA PRO' } }
  const judul = d.judul || 'SIMKA PRO'
  event.waitUntil(self.registration.showNotification(judul, {
    body: d.isi || '',
    icon: 'ikon/ikon-192.png',
    badge: 'ikon/ikon-192.png',
    tag: d.id || undefined,
    lang: 'id',
    data: { tautan: d.tautan || '/notifikasi', id: d.id || null },
  }))
})

self.addEventListener('notificationclick', (event) => {
  event.notification.close()
  const tautan = (event.notification.data && event.notification.data.tautan) || '/notifikasi'
  const alamat = new URL(self.registration.scope).href.replace(/#.*$/, '') + '#' + tautan
  event.waitUntil((async () => {
    const jendela = await self.clients.matchAll({ type: 'window', includeUncontrolled: true })
    for (const j of jendela) {
      if (j.url.startsWith(self.registration.scope)) {
        await j.focus()
        try { j.postMessage({ jenis: 'buka-tautan', tautan }) } catch (e) { /* abaikan */ }
        return
      }
    }
    await self.clients.openWindow(alamat)
  })())
})
