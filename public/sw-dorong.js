// SIMKA PRO | public/sw-dorong.js | v1.2 | Perbaikan: pelindung banjir notifikasi HP | 06/10/2026
// Dimuat oleh service worker PWA (workbox importScripts). Menampilkan notifikasi dorong dari server
// dan membuka halaman terkait saat notifikasi diketuk.
self.addEventListener('push', (event) => {
  let d = {}
  try { d = event.data ? event.data.json() : {} } catch (e) { d = { judul: event.data ? event.data.text() : 'SIMKA PRO' } }
  const judul = d.judul || 'SIMKA PRO'
  // v1.2 – Pelindung banjir: bila HP lama luring lalu menerima banyak notifikasi sekaligus, puluhan notifikasi
  // terpisah dapat membuat antarmuka sistem Android (bilah status, layar kunci) macet. Paling banyak 3 notifikasi
  // tampil terpisah; selebihnya digabung menjadi SATU notifikasi ringkasan yang membuka halaman Notifikasi.
  event.waitUntil((async () => {
    const umum = { icon: 'ikon/ikon-192.png', badge: 'ikon/badge-96.png', lang: 'id' }   // badge: siluet putih transparan
    let ada = []
    try { ada = await self.registration.getNotifications() } catch (e) { ada = [] }
    const terpisah = ada.filter((n) => n.tag !== 'simka-ringkas')
    if (terpisah.length < 3) {
      return self.registration.showNotification(judul, { ...umum, body: d.isi || '', tag: d.id || undefined,
        data: { tautan: d.tautan || '/notifikasi', id: d.id || null } })
    }
    const lama = ada.find((n) => n.tag === 'simka-ringkas')
    const jumlah = terpisah.length + 1 + ((lama && lama.data && lama.data.jumlah) || 0)
    terpisah.forEach((n) => n.close())
    return self.registration.showNotification('SIMKA PRO', { ...umum, tag: 'simka-ringkas', renotify: false, silent: !!lama,
      body: `Ada ${jumlah} notifikasi baru. Terakhir: ${judul}. Ketuk untuk membuka semua notifikasi.`,
      data: { tautan: '/notifikasi', id: null, jumlah } })
  })())
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
