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
