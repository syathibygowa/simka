<!-- SIMKA PRO | src/pages/wali/PortalWali.vue | v1.1 | Fase 9 – Tahap 13.1.0 Kehadiran, perizinan, kunjungan, titipan, riwayat sakit | 15/10/2026 -->
<script setup>
// Kerangka Portal Wali (#/wali/:bagian). Terpisah dari tata letak pegawai.
// HP: bilah aplikasi + navigasi bawah ala Android; desktop: kepala + bilah tab. Anak dapat lebih dari satu (pindah lewat chip anak).
// Bagian yang tersedia mengikuti tahap pengembangan dan butir informasi yang dinyalakan superadmin.
import { computed, onMounted, onBeforeUnmount, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { PhHouseLine, PhUserCircle, PhCaretDown, PhArrowsClockwise, PhPlus, PhLockKey, PhCheckCircle, PhArrowLeft, PhCalendarCheck, PhDoorOpen, PhHandshake, PhPackage, PhFirstAidKit } from '@phosphor-icons/vue'
import { usePortalWali } from '@/stores/portalWali'
import { useUI } from '@/stores/ui'
import { MODE_DEMO } from '@/lib/supabase'
import { inisial } from '@/lib/santri'
import LogoSimka from '@/components/LogoSimka.vue'
import PolaKhatam from '@/components/PolaKhatam.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import BilahTab from '@/components/BilahTab.vue'
import DaftarToast from '@/components/DaftarToast.vue'
import DialogKonfirmasi from '@/components/DialogKonfirmasi.vue'
import MasukWali from './MasukWali.vue'
import FormMasukWali from './FormMasukWali.vue'
import BerandaWali from './BerandaWali.vue'
import AkunWali from './AkunWali.vue'
import KehadiranWali from './KehadiranWali.vue'
import RiwayatWali from './RiwayatWali.vue'

const props = defineProps({ bagian: { type: String, default: '' } })
const router = useRouter(); const pw = usePortalWali(); const ui = useUI()

// Bagian portal. butir = butir informasi yang harus aktif (kosong = selalu tampil); bawah = tampil di navigasi bawah HP.
// Bagian lain dibuka dari Menu di Beranda (HP) atau bilah tab (desktop).
const SEMUA = [
  { k: '', n: 'Beranda', ikon: PhHouseLine, w: 'beranda', komp: BerandaWali, bawah: true },
  { k: 'kehadiran', n: 'Kehadiran', ikon: PhCalendarCheck, w: 'presensi', komp: KehadiranWali, butir: 'kehadiran', bawah: true },
  { k: 'perizinan', n: 'Perizinan', ikon: PhDoorOpen, w: 'pengajuan', komp: RiwayatWali, butir: 'perizinan', ket: 'Izin keluar, pulang, dan libur' },
  { k: 'kunjungan', n: 'Kunjungan', ikon: PhHandshake, w: 'security', komp: RiwayatWali, butir: 'kunjungan', ket: 'Kunjungan orang tua/wali' },
  { k: 'titipan', n: 'Titipan', ikon: PhPackage, w: 'tugas', komp: RiwayatWali, butir: 'titipan', ket: 'Titipan di pos Security' },
  { k: 'sakit', n: 'Riwayat sakit', ikon: PhFirstAidKit, w: 'klinik', komp: RiwayatWali, butir: 'sakit', ket: 'Ringkasan dari Klinik' },
  { k: 'akun', n: 'Akun', ikon: PhUserCircle, w: 'profil', komp: AkunWali, bawah: true },
]
const NAV = computed(() => SEMUA.filter((t) => !t.butir || pw.butir[t.butir]))
const NAV_BAWAH = computed(() => NAV.value.filter((t) => t.bawah))
/** Menu di Beranda: semua bagian selain Beranda dan Akun. */
const MENU = computed(() => NAV.value.filter((t) => t.k && t.k !== 'akun'))
const segar = ref(0)
const aktifTab = computed(() => NAV.value.find((t) => t.k === props.bagian) || NAV.value[0])
const tabModel = computed({ get: () => aktifTab.value.k || 'beranda', set: (k) => buka(k === 'beranda' ? '' : k) })
const tabDesktop = computed(() => NAV.value.map((t) => ({ ...t, k: t.k || 'beranda', ket: undefined })))
const buka = (k) => { router.replace(k ? `/wali/${k}` : '/wali'); window.scrollTo({ top: 0 }) }

const lembarAnak = ref(false); const lembarTambah = ref(false)
let terakhirMuat = 0
async function muat() { terakhirMuat = Date.now(); await pw.muatBeranda() }
/** Tombol segarkan: beranda dimuat ulang dan bagian yang sedang dibuka dipasang ulang (memuat datanya lagi). */
async function segarkan() { segar.value++; await muat() }
function pilih(nis) { pw.pilih(nis); lembarAnak.value = false; buka('') }
function tambahSelesai(a) {
  lembarTambah.value = false; lembarAnak.value = false
  ui.toast(`${a.nama} ditambahkan. Ketuk nama anak di atas untuk berpindah.`, 'sukses'); buka('')
}
function masukSelesai() { buka('') }

// Anak berganti (masuk, tambah, pindah): gulir ke atas lalu muat datanya
watch(() => pw.aktif?.nis, (n) => { window.scrollTo({ top: 0 }); if (n) muat() })
// Saat aplikasi dibuka kembali (pindah dari aplikasi lain), segarkan bila data sudah lebih dari 2 menit.
const segarkanBilaLama = () => { if (document.visibilityState === 'visible' && pw.aktif && Date.now() - terakhirMuat > 120000) muat() }
onMounted(() => { if (pw.aktif) muat(); document.addEventListener('visibilitychange', segarkanBilaLama) })
onBeforeUnmount(() => document.removeEventListener('visibilitychange', segarkanBilaLama))
</script>

<template>
  <MasukWali v-if="!pw.aktif" @selesai="masukSelesai" />

  <div v-else class="min-h-dvh bg-latar">
    <!-- Kepala -->
    <header class="kepala layar-saja sticky top-0 z-20 overflow-hidden text-white" style="padding-top: env(safe-area-inset-top)">
      <PolaKhatam :opasitas="0.12" :ukuran="52" />
      <div class="relative mx-auto flex max-w-5xl items-center gap-3 px-4 py-3 sm:px-6">
        <span class="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-white"><LogoSimka :size="28" /></span>
        <div class="hidden min-w-0 sm:block">
          <p class="font-extrabold leading-tight">Portal Wali Santri</p>
          <p class="text-xs text-white/85">Imam Asy-Syathiby Gowa<template v-if="MODE_DEMO"> · mode demo</template></p>
        </div>
        <button type="button" class="chip-anak ml-auto flex min-h-[44px] min-w-0 items-center gap-2 rounded-full py-1 pl-1 pr-3 sm:ml-6"
          :aria-label="'Anak yang dibuka: ' + pw.aktif.nama + '. Ketuk untuk berpindah atau menambah anak.'" @click="lembarAnak = true">
          <span class="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-white text-sm font-extrabold text-[#9A2622]">{{ inisial(pw.aktif.nama) }}</span>
          <span class="min-w-0 text-left"><span class="block max-w-[11rem] truncate text-sm font-bold leading-tight sm:max-w-[16rem]">{{ pw.aktif.panggilan || pw.aktif.nama }}</span>
            <span class="block text-xs text-white/85">{{ pw.aktif.kelas ? 'Kelas ' + pw.aktif.kelas : 'NIS ' + pw.aktif.nis }}</span></span>
          <PhCaretDown :size="16" weight="bold" class="shrink-0" />
        </button>
        <button type="button" class="tombol-ikon h-11 w-11 shrink-0 text-white hover:bg-white/15 sm:ml-auto" :disabled="pw.memuat" aria-label="Segarkan data" @click="segarkan">
          <PhArrowsClockwise :size="22" :class="pw.memuat && 'animate-spin'" />
        </button>
      </div>
    </header>

    <main class="mx-auto max-w-5xl px-4 pb-[calc(100px+env(safe-area-inset-bottom))] pt-4 sm:px-6 lg:pb-12">
      <div class="mb-4 hidden lg:block"><BilahTab v-model="tabModel" :tab="tabDesktop" label="Menu Portal Wali" :tepi="false" /></div>
      <div v-if="pw.tutup" class="kartu w-pengajuan flex gap-3 p-4" role="status">
        <span class="chip-ikon h-10 w-10"><PhLockKey :size="22" weight="duotone" /></span>
        <p class="text-sm font-semibold">{{ pw.tutup }}</p>
      </div>
      <template v-else>
        <!-- Judul bagian (HP) untuk bagian yang tidak ada di navigasi bawah -->
        <div v-if="!aktifTab.bawah" :class="['mb-3 flex items-center gap-2 lg:hidden', 'w-' + aktifTab.w]">
          <button type="button" class="tombol-ikon h-11 w-11 -ml-2" aria-label="Kembali ke Beranda" @click="buka('')"><PhArrowLeft :size="24" /></button>
          <span class="chip-ikon h-9 w-9 rounded-lg"><component :is="aktifTab.ikon" :size="20" weight="duotone" /></span>
          <h1 class="text-lg font-bold">{{ aktifTab.n }}</h1>
        </div>
        <component :is="aktifTab.komp" :key="aktifTab.k + pw.aktif.nis + segar" :bagian="aktifTab.k" :menu="MENU"
          @tambah="lembarTambah = true" @pilih="pilih" @buka="buka" />
      </template>
    </main>

    <!-- Navigasi bawah (HP) -->
    <nav class="layar-saja fixed inset-x-0 bottom-0 z-30 lg:hidden" style="padding-bottom: env(safe-area-inset-bottom)" aria-label="Menu Portal Wali">
      <div class="absolute inset-0 border-t border-garis bg-permukaan/95 backdrop-blur" aria-hidden="true" />
      <ul class="relative mx-auto grid max-w-xl" :style="{ gridTemplateColumns: `repeat(${NAV_BAWAH.length}, minmax(0, 1fr))` }">
        <li v-for="t in NAV_BAWAH" :key="t.k" :class="'w-' + t.w">
          <button type="button" class="flex h-[68px] w-full flex-col items-center justify-center gap-1" :aria-current="aktifTab.k === t.k ? 'page' : undefined" @click="buka(t.k)">
            <span :class="['pil grid h-8 w-14 place-items-center rounded-full transition', aktifTab.k === t.k && 'aktif']">
              <component :is="t.ikon" :size="24" :weight="aktifTab.k === t.k ? 'fill' : 'duotone'" :style="{ color: aktifTab.k === t.k ? 'var(--c)' : undefined }" :class="aktifTab.k !== t.k && 'text-teks2'" />
            </span>
            <span :class="['text-[11px] leading-none', aktifTab.k === t.k ? 'font-bold text-teks' : 'font-medium text-teks2']">{{ t.n }}</span>
          </button>
        </li>
      </ul>
    </nav>

    <!-- Pilih anak -->
    <LembarBawah v-model="lembarAnak" judul="Pilih anak">
      <ul class="space-y-2 px-5">
        <li v-for="a in pw.anak" :key="a.nis">
          <button type="button" :class="['flex min-h-[56px] w-full items-center gap-3 rounded-xl border border-garis p-2.5 text-left', a.nis === pw.aktif.nis ? 'bg-permukaan2' : 'hover:bg-permukaan2']" @click="pilih(a.nis)">
            <span class="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-[#C7332F] text-sm font-bold text-white">{{ inisial(a.nama) }}</span>
            <span class="min-w-0 flex-1"><span class="block truncate font-semibold">{{ a.nama }}</span>
              <span class="block text-sm text-teks3">NIS {{ a.nis }}<template v-if="a.kelas"> · Kelas {{ a.kelas }}</template></span></span>
            <PhCheckCircle v-if="a.nis === pw.aktif.nis" :size="22" weight="fill" class="shrink-0 text-[#15803D]" aria-label="Sedang dibuka" />
          </button>
        </li>
      </ul>
      <div class="px-5 pt-3"><button type="button" class="tombol-garis w-full" @click="lembarTambah = true"><PhPlus :size="20" weight="bold" /> Tambah anak</button></div>
    </LembarBawah>

    <!-- Tambah anak -->
    <LembarBawah v-model="lembarTambah" judul="Tambah anak">
      <div class="px-5">
        <p class="mb-4 text-sm text-teks2">Masukkan data anak lainnya. Nomor HP boleh nomor ayah, ibu, atau wali yang terdaftar untuk anak tersebut.</p>
        <FormMasukWali tombol="Tambahkan anak" @selesai="tambahSelesai" />
      </div>
    </LembarBawah>
  </div>
  <DaftarToast />
  <DialogKonfirmasi />
</template>
<style scoped>
.kepala { background: var(--gradasi-utama); }
.chip-anak { background: rgba(255, 255, 255, .16); }
.chip-anak:hover { background: rgba(255, 255, 255, .24); }
.pil.aktif { background: color-mix(in srgb, var(--c) 16%, rgb(var(--permukaan))); }
</style>
