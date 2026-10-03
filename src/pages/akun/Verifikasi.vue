<!-- SIMKA PRO | src/pages/akun/Verifikasi.vue | v1.0 | Fase 1 – Akun dan hak akses | 03/10/2026 -->
<script setup>
// Verifikasi pendaftaran dan pengelolaan akun pegawai (admin dengan izin, superadmin).
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import {
  PhHourglass, PhUsersThree, PhUserMinus, PhMagnifyingGlass, PhCheckCircle, PhXCircle, PhWhatsappLogo, PhKey,
  PhUserPlus, PhShieldCheck, PhProhibit, PhArrowCounterClockwise, PhCopySimple, PhDotsThreeVertical, PhIdentificationCard,
} from '@phosphor-icons/vue'
import { usePegawai } from '@/stores/pegawai'
import { useOrganisasi } from '@/stores/organisasi'
import { useAkun } from '@/stores/akun'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { formatRelatif, formatPanjang } from '@/lib/tanggal'
import { STATUS_AKUN, PENDIDIKAN } from '@/lib/kepegawaian'
import { tautanWA, TEMPLAT_WA } from '@/lib/wa'
import LembarBawah from '@/components/LembarBawah.vue'

const props = defineProps({ tab: { type: String, default: 'menunggu' } })
const router = useRouter()
const peg = usePegawai(); const org = useOrganisasi(); const akun = useAkun(); const sesi = useSesi(); const ui = useUI()
onMounted(() => Promise.all([peg.muat(), org.muat(), akun.muatIzin()]))

const menunggu = computed(() => peg.daftar.filter((p) => p.status_akun === 'menunggu'))
const ditolak = computed(() => peg.daftar.filter((p) => p.status_akun === 'ditolak'))
const cari = ref('')
const semua = computed(() => {
  const q = cari.value.toLowerCase().trim()
  return peg.daftar.filter((p) => ['aktif', 'nonaktif', 'tanpa_akun'].includes(p.status_akun) &&
    (!q || [p.nama_lengkap, p.username, p.email, p.niy].join(' ').toLowerCase().includes(q)))
})
const TAB = computed(() => [
  { k: 'menunggu', n: 'Menunggu verifikasi', ikon: PhHourglass, w: 'verifikasi', j: menunggu.value.length },
  { k: 'akun', n: 'Akun pegawai', ikon: PhUsersThree, w: 'pegawai', j: semua.value.length },
  { k: 'ditolak', n: 'Ditolak', ikon: PhUserMinus, w: 'klinik', j: ditolak.value.length },
])
const aktif = computed(() => TAB.value.find((t) => t.k === props.tab) || TAB.value[0])
const jabatan = (p) => [p.jabatan_struktural, ...(p.jabatan_fungsional || [])].filter(Boolean).join(', ') || '–'

// ---------- Verifikasi ----------
const v = ref(null)        // pegawai yang diperiksa (salinan dengan isian yang dapat dikoreksi)
const hasil = ref(null)    // hasil aksi untuk ditampilkan (sandi sementara, tautan WA)
const proses = ref(false)
function periksa(p) {
  hasil.value = null
  v.value = { ...p, fungsional_ids: [...(p.fungsional_ids || [])], struktural_id: p.structural_position_id || '', org_unit_id: p.org_unit_id || '', keputusan: '', catatan: '' }
}
function pilihFungsional(j) {
  const ids = new Set(v.value.fungsional_ids)
  if (ids.has(j.id)) ids.delete(j.id)
  else {
    if ((j.tanpa_rangkap && ids.size) || [...ids].some((id) => org.fungsional.find((x) => x.id === id)?.tanpa_rangkap)) return ui.toast('Medis dan security tidak dapat dirangkap.', 'galat')
    ids.add(j.id)
  }
  v.value.fungsional_ids = [...ids]
}
async function putuskan(keputusan) {
  const p = v.value
  if (keputusan === 'aktif' && !p.fungsional_ids.length) return ui.toast('Pilih minimal satu jabatan fungsional.', 'galat')
  if (keputusan === 'ditolak' && !p.catatan.trim()) { p.keputusan = 'ditolak'; return ui.toast('Tulis alasan penolakan.', 'galat') }
  proses.value = true
  try {
    const r = await akun.kelola({ aksi: 'verifikasi', employee_id: p.id, keputusan, catatan: p.catatan || null,
      fungsional_ids: p.fungsional_ids, struktural_id: p.struktural_id || null, org_unit_id: p.org_unit_id || null })
    ui.toast(r.pesan)
    hasil.value = { judul: keputusan === 'aktif' ? 'Akun diaktifkan' : 'Pendaftaran ditolak', ok: keputusan === 'aktif', no_hp: p.no_hp,
      wa: keputusan === 'aktif' ? TEMPLAT_WA.aktivasi({ nama: p.nama_lengkap, username: p.username }) : TEMPLAT_WA.ditolak({ nama: p.nama_lengkap, catatan: p.catatan }) }
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}

// ---------- Kelola akun ----------
const k = ref(null); const mode = ref('')  // mode: menu | buat | peran
const fBuat = ref({ username: '', email: '' })
const fPeran = ref({ peran: 'pegawai', izin: [] })
function bukaAkun(p) { k.value = p; mode.value = 'menu'; hasil.value = null }
function mulaiBuat() {
  const saran = (k.value.nama_lengkap || '').replace(/^(Ust\.|Ustzh\.)\s*/i, '').split(',')[0].toLowerCase().replace(/[^a-z0-9]+/g, '').slice(0, 20)
  fBuat.value = { username: saran, email: k.value.email || '' }; mode.value = 'buat'
}
function mulaiPeran() { fPeran.value = { peran: k.value.peran === 'admin' ? 'admin' : 'pegawai', izin: [...(akun.izinAdmin[k.value.id] || [])] }; mode.value = 'peran' }
async function jalankan(isi, pesanWA) {
  proses.value = true
  try {
    const r = await akun.kelola({ employee_id: k.value.id, ...isi })
    ui.toast(r.pesan)
    if (r.sandi_sementara) {
      const username = r.pegawai?.username || isi.username || k.value.username
      hasil.value = { judul: 'Kata sandi sementara', ok: true, sandi: r.sandi_sementara, no_hp: k.value.no_hp,
        wa: TEMPLAT_WA.sandiSementara({ nama: k.value.nama_lengkap, username, sandi: r.sandi_sementara }) }
    } else { k.value = null }
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
async function resetSandi() {
  if (!(await ui.konfirmasi({ judul: 'Buat kata sandi sementara?', pesan: `${k.value.nama_lengkap} wajib mengganti kata sandi saat masuk berikutnya.`, ya: 'Buat sandi sementara' }))) return
  jalankan({ aksi: 'reset_manual' })
}
async function ubahStatus() {
  const aktifkan = k.value.status_akun !== 'aktif'
  if (!(await ui.konfirmasi({ judul: aktifkan ? 'Aktifkan akun kembali?' : 'Nonaktifkan akun?', pesan: aktifkan ? `${k.value.nama_lengkap} dapat masuk kembali.` : `${k.value.nama_lengkap} tidak dapat masuk sampai akunnya diaktifkan kembali. Data tidak dihapus.`, ya: aktifkan ? 'Aktifkan' : 'Nonaktifkan', bahaya: !aktifkan }))) return
  jalankan({ aksi: 'status_akun', aktif: aktifkan })
}
function buatAkun() {
  const b = fBuat.value
  b.username = b.username.trim().toLowerCase()
  if (!/^[a-z0-9._]{4,30}$/.test(b.username)) return ui.toast('Username 4–30 karakter: huruf kecil, angka, titik, atau garis bawah.', 'galat')
  if (!/^\S+@\S+\.\S+$/.test(b.email.trim())) return ui.toast('Alamat email tidak sah.', 'galat')
  jalankan({ aksi: 'buat', username: b.username, email: b.email.trim().toLowerCase() })
}
function simpanPeran() { jalankan({ aksi: 'ubah_peran', peran: fPeran.value.peran, izin: fPeran.value.peran === 'admin' ? fPeran.value.izin : [] }) }
async function salin(t) { try { await navigator.clipboard.writeText(t); ui.toast('Disalin.') } catch { ui.toast('Salin manual: ' + t) } }
const tutupSemua = () => { v.value = null; k.value = null; hasil.value = null }
</script>
<template>
  <div>
    <nav class="-mx-4 mb-4 flex gap-2 overflow-x-auto px-4 pb-1 lg:mx-0 lg:px-0" role="tablist" aria-label="Bagian verifikasi akun">
      <button v-for="t in TAB" :key="t.k" role="tab" :aria-selected="aktif.k === t.k" @click="router.replace(`/verifikasi/${t.k}`)"
        :class="['tab flex min-h-[44px] shrink-0 items-center gap-2.5 rounded-xl border px-3 text-sm font-semibold', 'w-' + t.w, aktif.k === t.k ? 'aktif text-teks' : 'border-garis bg-permukaan text-teks2 hover:text-teks']">
        <span class="chip-ikon h-8 w-8 rounded-lg"><component :is="t.ikon" :size="20" weight="duotone" /></span>
        <span class="whitespace-nowrap">{{ t.n }}</span><span class="rounded-full bg-permukaan2 px-2 text-xs font-bold tabular-nums">{{ t.j }}</span>
      </button>
    </nav>

    <!-- Menunggu -->
    <section v-if="aktif.k === 'menunggu'" class="w-verifikasi">
      <ul v-if="menunggu.length" class="grid gap-3 lg:grid-cols-2">
        <li v-for="p in menunggu" :key="p.id">
          <button class="kartu flex w-full items-center gap-3 p-4 text-left hover:bg-permukaan2" @click="periksa(p)">
            <span class="chip-ikon h-11 w-11"><PhHourglass :size="24" weight="duotone" /></span>
            <span class="min-w-0 flex-1">
              <span class="block truncate font-bold">{{ p.nama_lengkap }}</span>
              <span class="block truncate text-sm text-teks3">{{ p.username }} – {{ p.nama_unit || 'bidang belum dipilih' }}</span>
              <span class="block truncate text-sm text-teks3">{{ jabatan(p) }}</span>
            </span>
            <span class="lencana shrink-0">Periksa</span>
          </button>
        </li>
      </ul>
      <div v-else class="flex flex-col items-center py-16 text-center"><span class="chip-ikon h-16 w-16 rounded-2xl"><PhCheckCircle :size="34" weight="duotone" /></span>
        <p class="mt-3 font-bold">Tidak ada pendaftaran yang menunggu</p><p class="text-sm text-teks3">Pendaftaran baru muncul di sini dan sebagai notifikasi.</p></div>
    </section>

    <!-- Akun pegawai -->
    <section v-else-if="aktif.k === 'akun'" class="w-pegawai">
      <div class="relative mb-3"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
        <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari nama, username, email, atau NIY" aria-label="Cari akun" /></div>
      <ul class="kartu divide-y divide-garis">
        <li v-for="p in semua" :key="p.id" class="flex items-center gap-3 p-3">
          <div class="min-w-0 flex-1">
            <p class="truncate font-semibold">{{ p.nama_lengkap }}</p>
            <p class="truncate text-sm text-teks3">{{ p.username || 'belum ada username' }}{{ p.email ? ' – ' + p.email : '' }}</p>
            <div class="mt-1 flex flex-wrap gap-1">
              <span :class="['lencana', 'w-' + STATUS_AKUN[p.status_akun]?.w]">{{ STATUS_AKUN[p.status_akun]?.n }}</span>
              <span v-if="p.peran === 'admin'" class="lencana w-pengaturan"><PhShieldCheck :size="12" weight="fill" /> Admin</span>
              <span v-if="p.peran === 'superadmin'" class="lencana w-pengaturan">Superadmin</span>
            </div>
          </div>
          <button v-if="p.peran !== 'superadmin'" class="tombol-ikon" @click="bukaAkun(p)" :aria-label="`Kelola akun ${p.nama_lengkap}`"><PhDotsThreeVertical :size="22" weight="bold" /></button>
        </li>
        <li v-if="!semua.length" class="p-8 text-center text-sm text-teks3">Tidak ada akun yang cocok.</li>
      </ul>
    </section>

    <!-- Ditolak -->
    <section v-else class="w-klinik">
      <ul v-if="ditolak.length" class="kartu divide-y divide-garis">
        <li v-for="p in ditolak" :key="p.id" class="flex items-center gap-3 p-3">
          <span class="chip-ikon h-10 w-10"><PhXCircle :size="22" weight="duotone" /></span>
          <div class="min-w-0 flex-1"><p class="font-semibold">{{ p.nama_lengkap }}</p><p class="text-sm text-teks3">Alasan: {{ p.catatan_verifikasi || '–' }}</p></div>
          <router-link :to="`/pegawai/${p.id}`" class="tombol-teks text-sm">Lihat data</router-link>
        </li>
      </ul>
      <p v-else class="py-16 text-center text-teks3">Tidak ada pendaftaran yang ditolak.</p>
    </section>

    <!-- Lembar verifikasi -->
    <LembarBawah :model-value="!!v" @update:model-value="(x) => !x && tutupSemua()" :judul="hasil ? hasil.judul : 'Periksa pendaftaran'">
      <template v-if="v && !hasil">
        <div class="space-y-4 pb-2">
          <div class="rounded-xl bg-permukaan2 p-3 text-sm">
            <p class="text-base font-bold">{{ v.nama_lengkap }}</p>
            <dl class="mt-1 grid grid-cols-[110px_1fr] gap-x-2 gap-y-0.5 text-teks2">
              <dt>Username</dt><dd class="font-semibold text-teks">{{ v.username }}</dd>
              <dt>Email</dt><dd>{{ v.email }}</dd>
              <dt>NIY</dt><dd>{{ v.niy || '–' }}</dd>
              <dt>Jenis kelamin</dt><dd>{{ v.jenis_kelamin === 'P' ? 'Perempuan' : 'Laki-laki' }}</dd>
              <dt>Lahir</dt><dd>{{ [v.tempat_lahir, v.tanggal_lahir && formatPanjang(v.tanggal_lahir)].filter(Boolean).join(', ') || '–' }}</dd>
              <dt>Pendidikan</dt><dd>{{ PENDIDIKAN[v.pendidikan_terakhir] || '–' }}</dd>
              <dt>Nomor HP</dt><dd>{{ v.no_hp || '–' }}</dd>
              <dt>Mendaftar</dt><dd>{{ formatRelatif(v.created_at) || "–" }}</dd>
            </dl>
          </div>
          <p class="text-sm text-teks3">Periksa dan koreksi bila perlu sebelum mengaktifkan.</p>
          <div><label class="label-isian" for="vf-unit">Bidang/unit</label>
            <select id="vf-unit" v-model="v.org_unit_id" class="isian"><option value="">Belum ditentukan</option>
              <option v-for="u in org.datar.filter((x) => x.aktif)" :key="u.id" :value="u.id">{{ '\u2003'.repeat(u.tingkat) }}{{ u.nama }}</option></select></div>
          <div><p class="label-isian">Jabatan fungsional</p>
            <div class="flex flex-wrap gap-1.5">
              <button v-for="j in org.fungsional.filter((x) => x.aktif)" :key="j.id" type="button" @click="pilihFungsional(j)" :aria-pressed="v.fungsional_ids.includes(j.id)"
                :class="['min-h-[38px] rounded-full border px-3 text-sm font-semibold', v.fungsional_ids.includes(j.id) ? 'border-transparent bg-[#1E7D4F] text-white dark:bg-[#5BD69A] dark:text-[#10261B]' : 'border-garis text-teks2']">{{ j.nama }}</button>
            </div></div>
          <div><label class="label-isian" for="vf-str">Jabatan struktural</label>
            <select id="vf-str" v-model="v.struktural_id" class="isian"><option value="">Tidak ada</option>
              <option v-for="j in [...org.struktural].filter((x) => x.aktif).sort((a, b) => a.tingkat - b.tingkat)" :key="j.id" :value="j.id">{{ j.nama }}</option></select></div>
          <div v-if="v.keputusan === 'ditolak'"><label class="label-isian" for="vf-cat">Alasan penolakan (dikirim ke pendaftar)</label>
            <textarea id="vf-cat" v-model="v.catatan" rows="3" class="isian py-3" placeholder="Contoh: Data tidak sesuai daftar pegawai pondok." /></div>
          <div class="grid grid-cols-2 gap-2">
            <button class="tombol-garis" :disabled="proses" @click="v.keputusan === 'ditolak' ? putuskan('ditolak') : (v.keputusan = 'ditolak')"><PhXCircle :size="20" weight="duotone" /> {{ v.keputusan === 'ditolak' ? 'Kirim penolakan' : 'Tolak' }}</button>
            <button class="tombol-utama" :disabled="proses" @click="putuskan('aktif')"><PhCheckCircle :size="20" weight="duotone" /> {{ proses ? 'Memproses…' : 'Aktifkan akun' }}</button>
          </div>
        </div>
      </template>
      <template v-if="hasil && v">
        <div :class="['space-y-4 pb-2', hasil.ok ? 'w-presensi' : 'w-klinik']">
          <p class="text-teks2">{{ hasil.ok ? 'Email aktivasi sudah dikirim otomatis.' : 'Pemberitahuan penolakan sudah dikirim ke email pendaftar.' }} Kabari juga melalui WhatsApp bila perlu.</p>
          <a v-if="hasil.no_hp" :href="tautanWA(hasil.no_hp, hasil.wa)" target="_blank" rel="noopener" class="tombol-utama w-full !bg-[#1E7D4F]"><PhWhatsappLogo :size="22" weight="fill" /> Kirim pesan WA</a>
          <p v-else class="text-sm text-teks3">Nomor HP belum diisi, jadi pesan WA tidak dapat dikirim.</p>
          <button class="tombol-garis w-full" @click="tutupSemua">Selesai</button>
        </div>
      </template>
    </LembarBawah>

    <!-- Lembar kelola akun -->
    <LembarBawah :model-value="!!k" @update:model-value="(x) => !x && tutupSemua()" :judul="hasil ? hasil.judul : k?.nama_lengkap">
      <template v-if="k && hasil">
        <div class="space-y-4 pb-2">
          <div class="rounded-xl bg-permukaan2 p-4 text-center">
            <p class="text-sm text-teks3">Kata sandi sementara</p>
            <p class="mt-1 font-mono text-2xl font-bold tracking-wide">{{ hasil.sandi }}</p>
            <button class="tombol-teks mt-1 text-sm" @click="salin(hasil.sandi)"><PhCopySimple :size="18" /> Salin</button>
          </div>
          <p class="text-sm text-teks2">Sandi ini hanya ditampilkan sekali. Pegawai wajib menggantinya saat masuk.</p>
          <a v-if="hasil.no_hp" :href="tautanWA(hasil.no_hp, hasil.wa)" target="_blank" rel="noopener" class="tombol-utama w-full !bg-[#1E7D4F]"><PhWhatsappLogo :size="22" weight="fill" /> Kirim melalui WA</a>
          <button class="tombol-garis w-full" @click="tutupSemua">Selesai</button>
        </div>
      </template>
      <template v-else-if="k && mode === 'menu'">
        <ul class="space-y-1 pb-2">
          <li v-if="k.status_akun === 'tanpa_akun' && sesi.isSuperadmin"><button class="w-pegawai flex min-h-[52px] w-full items-center gap-3 rounded-xl px-2 font-semibold hover:bg-permukaan2" @click="mulaiBuat">
            <PhUserPlus :size="22" weight="duotone" style="color: var(--c)" /> Buatkan akun</button></li>
          <li v-if="k.status_akun === 'tanpa_akun' && !sesi.isSuperadmin" class="px-2 py-3 text-sm text-teks3">Pegawai ini belum punya akun. Minta pegawai mendaftar sendiri, atau minta superadmin membuatkan akun.</li>
          <template v-if="['aktif', 'nonaktif'].includes(k.status_akun)">
            <li><button class="w-tahfizh flex min-h-[52px] w-full items-center gap-3 rounded-xl px-2 font-semibold hover:bg-permukaan2" @click="resetSandi">
              <PhKey :size="22" weight="duotone" style="color: var(--c)" /> Buat kata sandi sementara</button></li>
            <li v-if="sesi.isSuperadmin && k.status_akun === 'aktif'"><button class="w-pengaturan flex min-h-[52px] w-full items-center gap-3 rounded-xl px-2 font-semibold hover:bg-permukaan2" @click="mulaiPeran">
              <PhShieldCheck :size="22" weight="duotone" style="color: var(--c)" /> Atur peran admin</button></li>
            <li><button :class="['flex min-h-[52px] w-full items-center gap-3 rounded-xl px-2 font-semibold hover:bg-permukaan2', k.status_akun === 'aktif' ? 'w-beranda' : 'w-presensi']" @click="ubahStatus">
              <component :is="k.status_akun === 'aktif' ? PhProhibit : PhArrowCounterClockwise" :size="22" weight="duotone" style="color: var(--c)" />
              {{ k.status_akun === 'aktif' ? 'Nonaktifkan akun' : 'Aktifkan akun kembali' }}</button></li>
          </template>
          <li><router-link :to="`/pegawai/${k.id}`" class="w-profil flex min-h-[52px] items-center gap-3 rounded-xl px-2 font-semibold hover:bg-permukaan2">
            <PhIdentificationCard :size="22" weight="duotone" style="color: var(--c)" /> Lihat biodata</router-link></li>
        </ul>
      </template>
      <template v-else-if="k && mode === 'buat'">
        <div class="space-y-4 pb-2">
          <div><label class="label-isian" for="ba-user">Username</label><input id="ba-user" v-model="fBuat.username" class="isian lowercase" autocapitalize="none" /></div>
          <div><label class="label-isian" for="ba-email">Email</label><input id="ba-email" v-model="fBuat.email" type="email" class="isian" /></div>
          <p class="text-sm text-teks3">Kata sandi sementara dibuat otomatis dan dikirim ke email. Pegawai wajib menggantinya saat masuk pertama.</p>
          <button class="tombol-utama w-full" :disabled="proses" @click="buatAkun"><PhUserPlus :size="20" weight="duotone" /> {{ proses ? 'Membuat…' : 'Buat akun' }}</button>
        </div>
      </template>
      <template v-else-if="k && mode === 'peran'">
        <div class="space-y-4 pb-2">
          <div class="grid grid-cols-2 gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" aria-label="Peran">
            <button v-for="r in [{ k: 'pegawai', n: 'Pegawai' }, { k: 'admin', n: 'Admin' }]" :key="r.k" role="radio" :aria-checked="fPeran.peran === r.k" @click="fPeran.peran = r.k"
              :class="['min-h-[44px] rounded-xl text-sm font-semibold', fPeran.peran === r.k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">{{ r.n }}</button>
          </div>
          <div v-if="fPeran.peran === 'admin'">
            <p class="label-isian">Izin admin</p>
            <label v-for="z in akun.izinTersedia" :key="z.kode" class="flex min-h-[44px] items-center gap-3 rounded-xl px-2 hover:bg-permukaan2">
              <input v-model="fPeran.izin" type="checkbox" :value="z.kode" class="h-5 w-5 accent-[#C7332F]" /><span>{{ z.nama }}</span></label>
          </div>
          <button class="tombol-utama w-full" :disabled="proses" @click="simpanPeran"><PhShieldCheck :size="20" weight="duotone" /> {{ proses ? 'Menyimpan…' : 'Simpan peran' }}</button>
        </div>
      </template>
    </LembarBawah>
  </div>
</template>
<style scoped>
.tab.aktif { border-color: color-mix(in srgb, var(--c) 35%, transparent); background: color-mix(in srgb, var(--c) 12%, rgb(var(--permukaan))); }
</style>
