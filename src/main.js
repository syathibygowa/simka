// SIMKA PRO | src/main.js | v1.2 | Fase 3 – Tahap 1 Pengumuman, audit log, notifikasi HP | 04/10/2026
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
