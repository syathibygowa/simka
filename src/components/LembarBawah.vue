<script setup>
// Bottom sheet ala Android (mobile); di desktop tampil sebagai dialog di tengah.
import { watch, onBeforeUnmount } from 'vue'
import { PhX } from '@phosphor-icons/vue'
const buka = defineModel({ type: Boolean, default: false })
defineProps({ judul: String })
const tutup = () => (buka.value = false)
const esc = (e) => e.key === 'Escape' && tutup()
watch(buka, (v) => { document.body.style.overflow = v ? 'hidden' : ''; v ? addEventListener('keydown', esc) : removeEventListener('keydown', esc) })
onBeforeUnmount(() => { document.body.style.overflow = ''; removeEventListener('keydown', esc) })
</script>
<template>
  <Teleport to="body">
    <Transition name="lembar">
      <div v-if="buka" class="layar-saja fixed inset-0 z-50 flex items-end justify-center lg:items-center" role="dialog" aria-modal="true" :aria-label="judul">
        <div class="latar-redup absolute inset-0 bg-black/45" @click="tutup" />
        <div class="panel relative max-h-[88dvh] w-full overflow-y-auto rounded-t-[1.75rem] bg-permukaan pb-[max(1.25rem,env(safe-area-inset-bottom))] shadow-apung lg:max-w-lg lg:rounded-[1.5rem]">
          <div class="sticky top-0 z-10 bg-permukaan px-5 pt-2.5 pb-2">
            <div class="mx-auto mb-2 h-1.5 w-10 rounded-full bg-garis lg:hidden" aria-hidden="true" />
            <div class="flex items-center justify-between">
              <h2 class="text-lg font-bold">{{ judul }}</h2>
              <button class="tombol-ikon -mr-2" @click="tutup" aria-label="Tutup"><PhX :size="22" /></button>
            </div>
          </div>
          <div class="px-5"><slot /></div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>
<style scoped>
.lembar-enter-active, .lembar-leave-active { transition: opacity .2s ease; }
.lembar-enter-active .panel, .lembar-leave-active .panel { transition: transform .25s cubic-bezier(.2,.8,.2,1); }
.lembar-enter-from, .lembar-leave-to { opacity: 0; }
.lembar-enter-from .panel, .lembar-leave-to .panel { transform: translateY(40px); }
</style>
