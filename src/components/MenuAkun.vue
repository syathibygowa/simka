<script setup>
// Avatar dan menu akun (desktop): profil, tema, keluar; di mode demo dapat berganti peran.
import { ref, onMounted, onBeforeUnmount } from 'vue'
import { useRouter } from 'vue-router'
import { PhUserCircle, PhSignOut } from '@phosphor-icons/vue'
import { useSesi } from '@/stores/sesi'
import { useNotifikasi } from '@/stores/notifikasi'
import { MODE_DEMO } from '@/lib/supabase'
import PilihTema from './PilihTema.vue'
import AvatarPengguna from './AvatarPengguna.vue'

const sesi = useSesi(); const notif = useNotifikasi(); const router = useRouter()
const buka = ref(false); const akar = ref(null)
const luar = (e) => { if (akar.value && !akar.value.contains(e.target)) buka.value = false }
onMounted(() => document.addEventListener('pointerdown', luar))
onBeforeUnmount(() => document.removeEventListener('pointerdown', luar))
async function keluar() { notif.berhenti(); await sesi.keluar(); router.replace('/masuk') }
function ganti(p) { sesi.masukDemo(p); notif.berhenti(); notif.muat(); buka.value = false; router.push('/') }
const PERAN = { superadmin: 'Superadmin', admin: 'Admin', pegawai: 'Pegawai' }
</script>
<template>
  <div ref="akar" class="relative">
    <button type="button" class="flex items-center gap-2.5 rounded-full py-1 pl-1 pr-3 hover:bg-permukaan2" @click="buka = !buka" :aria-expanded="buka" aria-label="Menu akun">
      <AvatarPengguna :size="38" />
      <span class="hidden text-left xl:block">
        <span class="block max-w-[160px] truncate text-sm font-bold leading-tight">{{ sesi.namaPendek }}</span>
        <span class="block text-xs leading-tight text-teks3">{{ PERAN[sesi.peran] }}</span>
      </span>
    </button>
    <div v-if="buka" class="absolute right-0 top-12 z-40 w-80 rounded-[1.25rem] border border-garis bg-permukaan p-3 shadow-apung">
      <div class="px-2 pb-3">
        <p class="font-bold leading-tight">{{ sesi.pengguna?.nama_lengkap }}</p>
        <p class="text-sm text-teks3">{{ sesi.pengguna?.jabatan }}</p>
      </div>
      <PilihTema />
      <div class="mt-2 border-t border-garis pt-2">
        <router-link to="/profil" class="w-profil flex min-h-[44px] items-center gap-3 rounded-xl px-2 font-semibold hover:bg-permukaan2" @click="buka = false">
          <PhUserCircle :size="22" weight="duotone" style="color: var(--c)" /> Profil saya
        </router-link>
        <template v-if="MODE_DEMO">
          <p class="mt-2 px-2 text-xs font-semibold text-teks3">Mode demo: coba sebagai</p>
          <div class="mt-1 flex gap-1 px-1">
            <button v-for="(n, k) in PERAN" :key="k" :class="['flex-1 rounded-lg py-2 text-xs font-bold', sesi.peran === k ? 'bg-[#C7332F] text-white' : 'bg-permukaan2 text-teks2 hover:text-teks']" @click="ganti(k)">
              {{ n }}
            </button>
          </div>
        </template>
        <button class="w-beranda mt-2 flex min-h-[44px] w-full items-center gap-3 rounded-xl px-2 font-semibold hover:bg-permukaan2" @click="keluar">
          <PhSignOut :size="22" weight="duotone" style="color: var(--c)" /> Keluar
        </button>
      </div>
    </div>
  </div>
</template>
