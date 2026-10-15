<!-- SIMKA PRO | src/pages/wali/PortalWali.vue | v2.0 | Perbaikan 13.5.0: desain ulang (kepala lebih tinggi, nama lengkap anak, tombol keluar, menu samping desktop) | 15/10/2026 -->
<script setup>
// Kerangka Portal Wali (#/wali/:bagian). Terpisah dari tata letak pegawai.
// HP: bilah aplikasi + navigasi bawah ala Android; desktop: kepala tinggi + menu samping berkelompok (tanpa gulir mendatar).
// Kepala memuat logo pondok, nama lengkap anak (ketuk untuk berpindah/menambah anak), tombol segarkan, dan tombol keluar.
// Bagian yang tersedia mengikuti tahap pengembangan dan butir informasi yang dinyalakan superadmin.
import { computed, onMounted, onBeforeUnmount, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { PhHouseLine, PhUserCircle, PhCaretDown, PhArrowsClockwise, PhPlus, PhLockKey, PhCheckCircle, PhArrowLeft, PhSignOut, PhCalendarCheck, PhDoorOpen, PhHandshake, PhPackage, PhFirstAidKit, PhBookOpenText, PhExam, PhChartBar, PhTrophy, PhWallet, PhMegaphone, PhFileText } from '@phosphor-icons/vue'
import { usePortalWali } from '@/stores/portalWali'
import { useUI } from '@/stores/ui'
import { useLembaga } from '@/stores/lembaga'
import { alamatAset } from '@/lib/penyimpanan'
import logoLokal from '@/assets/logo-pondok.png'
import { MODE_DEMO } from '@/lib/supabase'
import { inisial } from '@/lib/santri'
import PolaKhatam from '@/components/PolaKhatam.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import DaftarToast from '@/components/DaftarToast.vue'
import DialogKonfirmasi from '@/components/DialogKonfirmasi.vue'
import MasukWali from './MasukWali.vue'
import FormMasukWali from './FormMasukWali.vue'
import BerandaWali from './BerandaWali.vue'
import AkunWali from './AkunWali.vue'
import KehadiranWali from './KehadiranWali.vue'
import RiwayatWali from './RiwayatWali.vue'
import HafalanWali from './HafalanWali.vue'
import NilaiWali from './NilaiWali.vue'
import UjianWali from './UjianWali.vue'
import PengumumanWali from './PengumumanWali.vue'
import DokumenWali from './DokumenWali.vue'

const props = defineProps({ bagian: { type: String, default: '' } })
const router = useRouter(); const pw = usePortalWali(); const ui = useUI(); const lembaga = useLembaga()
lembaga.muatIdentitas()

// Bagian portal. butir = butir informasi yang harus aktif (kosong = selalu tampil); bawah = tampil di navigasi bawah HP.
// Bagian lain dibuka dari Menu di Beranda (HP) atau bilah tab (desktop).
const SEMUA = [
  { k: '', n: 'Beranda', ikon: PhHouseLine, w: 'beranda', komp: BerandaWali, bawah: true, grup: 'utama', ket: 'Ringkasan perkembangan ananda' },
  { k: 'kehadiran', n: 'Kehadiran', ikon: PhCalendarCheck, w: 'presensi', komp: KehadiranWali, butir: 'kehadiran', bawah: true, grup: 'utama', ket: 'Kelas, halaqah, asrama, dan ekskul' },
  { k: 'hafalan', n: 'Hafalan', ikon: PhBookOpenText, w: 'tahfizh', komp: HafalanWali, butir: 'hafalan', bawah: true, grup: 'utama', ket: 'Posisi hafalan, capaian, dan setoran' },
  { k: 'pengumuman', n: 'Info', nPanjang: 'Pengumuman', ikon: PhMegaphone, w: 'pengumuman', komp: PengumumanWali, butir: 'pengumuman', bawah: true, grup: 'utama', ket: 'Pengumuman dari pondok' },
  { k: 'ujian', n: 'Ujian tahfizh', ikon: PhExam, w: 'rapor', komp: UjianWali, butir: 'ujian', grup: 'akademik', ket: 'Ujian kenaikan juz dan UTAS' },
  { k: 'nilai', n: 'Nilai rapor', ikon: PhChartBar, w: 'penilaian', komp: NilaiWali, butir: 'nilai', grup: 'akademik', ket: 'Nilai semester yang sudah ditetapkan' },
  { k: 'prestasi', n: 'Prestasi', ikon: PhTrophy, w: 'prestasi', komp: UjianWali, butir: 'prestasi', grup: 'akademik', ket: 'Prestasi dan penghargaan' },
  { k: 'dokumen', n: 'Dokumen', ikon: PhFileText, w: 'laporan', komp: DokumenWali, butir: 'dokumen', grup: 'akademik', ket: 'Surat keterangan dan sertifikat' },
  { k: 'perizinan', n: 'Perizinan', ikon: PhDoorOpen, w: 'pengajuan', komp: RiwayatWali, butir: 'perizinan', grup: 'layanan', ket: 'Izin keluar, pulang, dan libur' },
  { k: 'kunjungan', n: 'Kunjungan', ikon: PhHandshake, w: 'security', komp: RiwayatWali, butir: 'kunjungan', grup: 'layanan', ket: 'Kunjungan orang tua/wali' },
  { k: 'titipan', n: 'Titipan', ikon: PhPackage, w: 'tugas', komp: RiwayatWali, butir: 'titipan', grup: 'layanan', ket: 'Titipan di pos Security' },
  { k: 'sakit', n: 'Riwayat sakit', ikon: PhFirstAidKit, w: 'klinik', komp: RiwayatWali, butir: 'sakit', grup: 'layanan', ket: 'Ringkasan dari Klinik' },
  { k: 'keuangan', n: 'Keuangan', ikon: PhWallet, w: 'keuangan', komp: UjianWali, butir: 'keuangan', grup: 'layanan', ket: 'Ringkasan tagihan dan pembayaran' },
  { k: 'akun', n: 'Akun', ikon: PhUserCircle, w: 'profil', komp: AkunWali, bawah: true, grup: 'akun', ket: 'Anak di perangkat ini, notifikasi, dan tema' },
]
const GRUP = [{ k: 'utama', n: 'Utama' }, { k: 'akademik', n: 'Akademik' }, { k: 'layanan', n: 'Layanan' }, { k: 'akun', n: 'Pengaturan' }]
const NAV = computed(() => SEMUA.filter((t) => !t.butir || pw.butir[t.butir]))
const NAV_BAWAH = computed(() => NAV.value.filter((t) => t.bawah))
/** Menu di Beranda: semua bagian selain Beranda dan Akun. */
const MENU = computed(() => NAV.value.filter((t) => t.k && t.k !== 'akun'))
const segar = ref(0)
const aktifTab = computed(() => NAV.value.find((t) => t.k === props.bagian) || NAV.value[0])
const baru = computed(() => pw.beranda?.pengumuman_baru || 0)
/** Menu samping desktop: dikelompokkan, kelompok tanpa isi disembunyikan. */
const menuSamping = computed(() => GRUP.map((g) => ({ ...g, isi: NAV.value.filter((t) => t.grup === g.k) })).filter((g) => g.isi.length))
const logo = computed(() => alamatAset(lembaga.identitas?.logo_url) || logoLokal)
const namaPondok = computed(() => lembaga.identitas?.nama_lengkap || pw.beranda?.lembaga || "Pondok Pesantren Tahfizhul Qur'an Imam Asy-Syathiby")
const kelasAnak = computed(() => pw.aktif?.kelas || pw.beranda?.santri?.kelas || '')
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
/** Tombol keluar di kepala: keluar dari semua anak di perangkat ini (keluar per anak tersedia di menu Akun). */
async function keluar() {
  const banyak = pw.anak.length > 1
  const ok = await ui.konfirmasi({
    judul: 'Keluar dari Portal Wali',
    pesan: banyak
      ? `Data ${pw.anak.length} anak di perangkat ini akan dikeluarkan. Untuk keluar dari satu anak saja, buka menu Akun.`
      : `Keluar dari data ${pw.aktif.nama} di perangkat ini? Untuk membukanya lagi, masuk kembali dengan NIS/NISN, tanggal lahir, dan 6 digit nomor HP.`,
    ya: 'Keluar', bahaya: true,
  })
  if (!ok) return
  await pw.keluarSemua(); ui.toast('Anda sudah keluar dari Portal Wali.', 'sukses')
}

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
      <PolaKhatam :opasitas="0.12" :ukuran="56" />
      <span class="kilau" aria-hidden="true" />
      <div class="relative mx-auto flex max-w-6xl items-center gap-3 px-4 py-3 sm:px-6 lg:gap-5 lg:py-5">
        <span class="grid h-11 w-11 shrink-0 place-items-center overflow-hidden rounded-full bg-white shadow-md ring-2 ring-white/40 lg:h-14 lg:w-14">
          <img :src="logo" alt="Logo pondok" class="h-[84%] w-[84%] object-contain" @error="(e) => (e.target.src = logoLokal)" /></span>
        <div class="hidden min-w-0 lg:block">
          <p class="text-lg font-extrabold leading-tight tracking-tight">Portal Wali Santri</p>
          <p class="max-w-[30rem] truncate text-sm text-white/85" :title="namaPondok">{{ namaPondok }}<template v-if="MODE_DEMO"> · mode demo</template></p>
        </div>
        <button type="button" class="chip-anak flex min-h-[48px] min-w-0 flex-1 items-center gap-2.5 rounded-2xl py-1.5 pl-1.5 pr-3 text-left lg:ml-auto lg:max-w-md lg:flex-none lg:py-2 lg:pl-2 lg:pr-4"
          :aria-label="'Anak yang dibuka: ' + pw.aktif.nama + '. Ketuk untuk berpindah atau menambah anak.'" @click="lembarAnak = true">
          <span class="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-white text-sm font-extrabold text-[#9A2622] lg:h-11 lg:w-11 lg:text-base">{{ inisial(pw.aktif.nama) }}</span>
          <span class="min-w-0 flex-1">
            <span class="block truncate text-sm font-bold leading-tight lg:text-base">{{ pw.aktif.nama }}</span>
            <span class="block truncate text-xs text-white/85 lg:text-sm">{{ kelasAnak ? 'Kelas ' + kelasAnak + ' · ' : '' }}NIS {{ pw.aktif.nis }}<template v-if="pw.anak.length > 1"> · {{ pw.anak.length }} anak</template></span>
          </span>
          <PhCaretDown :size="16" weight="bold" class="shrink-0" />
        </button>
        <div class="flex shrink-0 items-center gap-1 lg:gap-2">
          <button type="button" class="tombol-kepala" :disabled="pw.memuat" aria-label="Segarkan data" title="Segarkan data" @click="segarkan">
            <PhArrowsClockwise :size="22" :class="pw.memuat && 'animate-spin'" />
          </button>
          <button type="button" class="tombol-kepala" aria-label="Keluar dari Portal Wali" title="Keluar" @click="keluar">
            <PhSignOut :size="22" /><span class="hidden text-sm font-semibold xl:inline">Keluar</span>
          </button>
        </div>
      </div>
    </header>

    <div class="mx-auto max-w-6xl px-4 pb-[calc(100px+env(safe-area-inset-bottom))] pt-4 sm:px-6 lg:grid lg:grid-cols-[256px_minmax(0,1fr)] lg:gap-6 lg:pb-12 lg:pt-6">
      <!-- Menu samping (desktop) -->
      <aside class="layar-saja hidden lg:block">
        <nav class="kartu sticky top-[124px] space-y-4 p-3" aria-label="Menu Portal Wali">
          <div v-for="g in menuSamping" :key="g.k">
            <p class="px-3 pb-1.5 text-[11px] font-bold uppercase tracking-wider text-teks3">{{ g.n }}</p>
            <ul class="space-y-0.5">
              <li v-for="t in g.isi" :key="t.k" :class="'w-' + t.w">
                <button type="button" :class="['menu-samping flex min-h-[44px] w-full items-center gap-3 rounded-xl px-2.5 text-left text-sm', aktifTab.k === t.k ? 'aktif font-bold text-teks' : 'font-semibold text-teks2 hover:bg-permukaan2 hover:text-teks']"
                  :aria-current="aktifTab.k === t.k ? 'page' : undefined" @click="buka(t.k)">
                  <span class="chip-ikon h-8 w-8 rounded-lg"><component :is="t.ikon" :size="19" :weight="aktifTab.k === t.k ? 'fill' : 'duotone'" /></span>
                  <span class="min-w-0 flex-1 truncate">{{ t.nPanjang || t.n }}</span>
                  <span v-if="t.k === 'pengumuman' && baru" class="grid h-5 min-w-[1.25rem] place-items-center rounded-full bg-[#C7332F] px-1.5 text-[11px] font-bold text-white" :aria-label="baru + ' pengumuman baru'">{{ baru }}</span>
                </button>
              </li>
            </ul>
          </div>
        </nav>
      </aside>

      <main class="min-w-0">
        <div v-if="pw.tutup" class="kartu w-pengajuan flex gap-3 p-4" role="status">
          <span class="chip-ikon h-10 w-10"><PhLockKey :size="22" weight="duotone" /></span>
          <p class="text-sm font-semibold">{{ pw.tutup }}</p>
        </div>
        <template v-else>
          <!-- Judul bagian: HP untuk bagian di luar navigasi bawah; desktop untuk semua bagian selain Beranda -->
          <div v-if="aktifTab.k" :class="['mb-4 flex items-center gap-3', aktifTab.bawah && 'hidden lg:flex', 'w-' + aktifTab.w]">
            <button type="button" class="tombol-ikon -ml-2 h-11 w-11 lg:hidden" aria-label="Kembali ke Beranda" @click="buka('')"><PhArrowLeft :size="24" /></button>
            <span class="chip-ikon h-10 w-10 rounded-xl lg:h-12 lg:w-12"><component :is="aktifTab.ikon" :size="24" weight="duotone" /></span>
            <div class="min-w-0"><h1 class="text-lg font-extrabold leading-tight lg:text-xl">{{ aktifTab.nPanjang || aktifTab.n }}</h1>
              <p class="hidden text-sm text-teks3 sm:block">{{ aktifTab.ket }}</p></div>
          </div>
          <component :is="aktifTab.komp" :key="aktifTab.k + pw.aktif.nis + segar" :bagian="aktifTab.k" :menu="MENU"
            @tambah="lembarTambah = true" @pilih="pilih" @buka="buka" />
        </template>
      </main>
    </div>

    <!-- Navigasi bawah (HP) -->
    <nav class="layar-saja fixed inset-x-0 bottom-0 z-30 lg:hidden" style="padding-bottom: env(safe-area-inset-bottom)" aria-label="Menu Portal Wali">
      <div class="absolute inset-0 border-t border-garis bg-permukaan/95 backdrop-blur" aria-hidden="true" />
      <ul class="relative mx-auto grid max-w-xl" :style="{ gridTemplateColumns: `repeat(${NAV_BAWAH.length}, minmax(0, 1fr))` }">
        <li v-for="t in NAV_BAWAH" :key="t.k" :class="'w-' + t.w">
          <button type="button" class="flex h-[68px] w-full flex-col items-center justify-center gap-1" :aria-current="aktifTab.k === t.k ? 'page' : undefined" @click="buka(t.k)">
            <span :class="['pil relative grid h-8 w-14 place-items-center rounded-full transition', aktifTab.k === t.k && 'aktif']">
              <span v-if="t.k === 'pengumuman' && baru" class="absolute -right-0.5 -top-1 grid h-5 min-w-[1.25rem] place-items-center rounded-full bg-[#C7332F] px-1 text-[11px] font-bold text-white" :aria-label="baru + ' pengumuman baru'">{{ baru }}</span>
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
.kepala { background: linear-gradient(120deg, #7E1714 0%, #A9241F 38%, #C7332F 70%, #C2541A 100%); box-shadow: 0 6px 24px rgba(94, 20, 18, .22); }
.kilau { position: absolute; inset: -40% -10% auto auto; width: 420px; height: 420px; border-radius: 50%;
  background: radial-gradient(circle, rgba(255, 196, 120, .30) 0%, transparent 65%); pointer-events: none; }
.chip-anak { background: rgba(255, 255, 255, .14); border: 1px solid rgba(255, 255, 255, .22); }
.chip-anak:hover { background: rgba(255, 255, 255, .22); }
.tombol-kepala { display: inline-flex; align-items: center; justify-content: center; gap: .375rem; min-width: 44px; height: 44px; padding: 0 .625rem;
  border-radius: 9999px; color: #fff; transition: background-color .15s; }
.tombol-kepala:hover { background: rgba(255, 255, 255, .16); }
.tombol-kepala:disabled { opacity: .6; }
.menu-samping { position: relative; }
.menu-samping.aktif { background: color-mix(in srgb, var(--c) 13%, rgb(var(--permukaan))); }
.menu-samping.aktif::before { content: ''; position: absolute; left: -12px; top: 8px; bottom: 8px; width: 4px; border-radius: 0 4px 4px 0; background: var(--tab-aktif); }
.pil.aktif { background: color-mix(in srgb, var(--c) 16%, rgb(var(--permukaan))); }
</style>
