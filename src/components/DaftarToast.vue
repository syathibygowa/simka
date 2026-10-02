<script setup>
import { useRouter } from 'vue-router'
import { PhX } from '@phosphor-icons/vue'
import IkonDinamis from './IkonDinamis.vue'
import { useUI } from '@/stores/ui'
import { useNotifikasi } from '@/stores/notifikasi'
const ui = useUI(); const router = useRouter(); const notif = useNotifikasi()
async function aksi(t) {
  ui.tutupToast(t.id)
  if (t.aksi?.notif) { await notif.tandai(t.aksi.notif.id); router.push(t.aksi.notif.tautan) }
}
</script>
<template>
  <div class="layar-saja pointer-events-none fixed inset-x-0 z-[60] flex flex-col items-center gap-2 px-4 posisi" aria-live="polite">
    <TransitionGroup name="toast">
      <div v-for="t in ui.toasts" :key="t.id"
        class="pointer-events-auto flex w-full max-w-md items-center gap-3 rounded-2xl bg-[#2B1F22] px-4 py-3 text-sm text-white shadow-apung dark:bg-[#F8EEEB] dark:text-[#1F1416]">
        <IkonDinamis v-if="t.jenis === 'notifikasi'" nama="Bell" :size="20" />
        <span class="flex-1 font-medium">{{ t.pesan }}</span>
        <button v-if="t.aksi" class="font-bold text-[#FFB59E] dark:text-[#A82824]" @click="aksi(t)">{{ t.aksi.label }}</button>
        <button class="opacity-80 hover:opacity-100" @click="ui.tutupToast(t.id)" aria-label="Tutup pesan"><PhX :size="18" /></button>
      </div>
    </TransitionGroup>
  </div>
</template>
<style scoped>
.posisi { bottom: calc(88px + env(safe-area-inset-bottom)); }
@media (min-width: 1024px) { .posisi { bottom: 24px; } }
.toast-enter-active, .toast-leave-active { transition: all .2s ease; }
.toast-enter-from, .toast-leave-to { opacity: 0; transform: translateY(12px); }
</style>
