// SIMKA PRO | src/main.js | v1.3 | Perbaikan: layar pembuka PWA beranimasi memudar masuk ke aplikasi | 14/10/2026
import { createApp } from 'vue'
import { createPinia } from 'pinia'
import '@fontsource/plus-jakarta-sans/400.css'
import '@fontsource/plus-jakarta-sans/500.css'
import '@fontsource/plus-jakarta-sans/600.css'
import '@fontsource/plus-jakarta-sans/700.css'
import '@fontsource/plus-jakarta-sans/800.css'
import './styles/main.css'
import App from './App.vue'
import router from './router'
import { useTema } from './stores/tema'

const app = createApp(App)
app.use(createPinia())
useTema().pasang()
app.use(router)
app.mount('#app')

// Layar pembuka (index.html): tampil sedikitnya 1,2 detik bila dibuka sebagai aplikasi terpasang (PWA), lalu memudar.
{
  const awal = performance.now(); const pwa = window.matchMedia('(display-mode: standalone)').matches || navigator.standalone
  router.isReady().then(() => {
    const el = document.getElementById('pembuka'); if (!el) return
    setTimeout(() => { el.classList.add('keluar'); setTimeout(() => el.remove(), 600) }, Math.max(0, (pwa ? 1200 : 300) - (performance.now() - awal)))
  })
}

// Pembaruan otomatis: saat versi baru terpasang di GitHub Pages, aplikasi memuat ulang dengan sendirinya
// (dan memeriksa pembaruan setiap 30 menit selama aplikasi terbuka).
if (import.meta.env.MODE !== 'demo') {
  import('virtual:pwa-register').then(({ registerSW }) => {
    registerSW({
      immediate: true,
      onRegisteredSW(_, reg) { if (reg) setInterval(() => reg.update(), 30 * 60 * 1000) },
    })
  })
  // Notifikasi HP diketuk saat aplikasi sudah terbuka: buka halaman terkait
  navigator.serviceWorker?.addEventListener('message', (e) => {
    if (e.data?.jenis === 'buka-tautan' && e.data.tautan) router.push(e.data.tautan)
  })
}
