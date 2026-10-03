<!-- SIMKA PRO | src/pages/auth/Daftar.vue | v1.0 | Fase 1 – Akun dan hak akses | 03/10/2026 -->
<script setup>
// Pendaftaran mandiri pegawai. Akun baru menunggu verifikasi admin sebelum dapat dipakai.
import { ref, computed, onMounted } from 'vue'
import { PhUser, PhEnvelopeSimple, PhCheckCircle, PhHourglass } from '@phosphor-icons/vue'
import { useAkun } from '@/stores/akun'
import { useOrganisasi } from '@/stores/organisasi'
import { useUI } from '@/stores/ui'
import { periksaSandi } from '@/lib/sandi'
import { PENDIDIKAN, STATUS_KELUARGA, normalHP } from '@/lib/kepegawaian'
import TataLetakAuth from '@/components/TataLetakAuth.vue'
import InputSandi from '@/components/InputSandi.vue'
import InputTanggal from '@/components/InputTanggal.vue'

const akun = useAkun(); const org = useOrganisasi(); const ui = useUI()
onMounted(() => org.muat())
const f = ref({ nama_lengkap: '', username: '', email: '', sandi: '', ulang: '', niy: '', jenis_kelamin: '', tempat_lahir: '', tanggal_lahir: '',
  no_hp: '', pendidikan_terakhir: '', status_keluarga: '', org_unit_id: '', fungsional_ids: [], struktural_id: '' })
const galat = ref(''); const proses = ref(false); const selesai = ref(false)
const fungsional = computed(() => org.fungsional.filter((j) => j.aktif))
const struktural = computed(() => [...org.struktural].filter((j) => j.aktif).sort((a, b) => a.tingkat - b.tingkat))

function pilih(j) {
  const ids = new Set(f.value.fungsional_ids)
  if (ids.has(j.id)) ids.delete(j.id)
  else {
    const adaTunggal = [...ids].some((id) => org.fungsional.find((x) => x.id === id)?.tanpa_rangkap)
    if ((j.tanpa_rangkap && ids.size) || adaTunggal) return ui.toast('Tugas medis dan security tidak dapat dirangkap dengan tugas lain.', 'galat')
    ids.add(j.id)
  }
  f.value.fungsional_ids = [...ids]
}

async function kirim() {
  const d = f.value; galat.value = ''
  d.username = d.username.trim().toLowerCase()
  if (d.nama_lengkap.trim().length < 3) galat.value = 'Nama lengkap bergelar wajib diisi.'
  else if (!/^[a-z0-9._]{4,30}$/.test(d.username)) galat.value = 'Username 4–30 karakter: huruf kecil, angka, titik, atau garis bawah (tanpa spasi).'
  else if (!/^\S+@\S+\.\S+$/.test(d.email.trim())) galat.value = 'Alamat email tidak sah.'
  else if (!d.jenis_kelamin) galat.value = 'Pilih jenis kelamin.'
  else if (!d.fungsional_ids.length) galat.value = 'Pilih minimal satu jabatan fungsional (tugas Anda di pondok).'
  else galat.value = periksaSandi(d.sandi, d.ulang)
  if (d.no_hp && !galat.value) { d.no_hp = normalHP(d.no_hp); if (!/^[0-9+]{9,16}$/.test(d.no_hp)) galat.value = 'Nomor HP harus 9–16 angka.' }
  if (galat.value) { window.scrollTo({ top: 0, behavior: 'smooth' }); return }
  proses.value = true
  try {
    const { ulang, ...isi } = d
    await akun.daftar({ ...isi, email: d.email.trim().toLowerCase(), struktural_id: d.struktural_id || null, org_unit_id: d.org_unit_id || null })
    selesai.value = true; window.scrollTo({ top: 0 })
  } catch (e) { galat.value = e.message; window.scrollTo({ top: 0, behavior: 'smooth' }) } finally { proses.value = false }
}
</script>
<template>
  <TataLetakAuth :judul="selesai ? 'Pendaftaran terkirim' : 'Daftar akun pegawai'" :keterangan="selesai ? '' : 'Isi data diri Anda. Akun dapat dipakai setelah diverifikasi admin pondok.'" lebar="max-w-2xl">
    <div v-if="selesai" class="w-verifikasi flex flex-col items-center py-4 text-center">
      <span class="chip-ikon h-16 w-16 rounded-2xl"><PhHourglass :size="34" weight="duotone" /></span>
      <p class="mt-3 text-lg font-bold">Menunggu verifikasi admin</p>
      <p class="mt-1 max-w-md text-teks2">Admin akan memeriksa data Anda. Pemberitahuan aktivasi dikirim ke <b class="font-semibold">{{ f.email }}</b> dan dapat juga melalui WhatsApp.</p>
      <router-link to="/masuk" class="tombol-utama mt-5">Kembali ke halaman masuk</router-link>
    </div>

    <form v-else class="space-y-6" @submit.prevent="kirim" novalidate>
      <p v-if="galat" class="rounded-xl bg-[#C7332F]/10 px-3.5 py-2.5 text-sm font-semibold text-merah" role="alert">{{ galat }}</p>

      <fieldset class="space-y-4">
        <legend class="judul-bagian mb-2">Akun</legend>
        <div class="grid gap-4 sm:grid-cols-2">
          <div><label for="d-user" class="label-isian">Username</label>
            <div class="relative"><PhUser :size="20" weight="duotone" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
              <input id="d-user" v-model="f.username" class="isian pl-11 lowercase" autocomplete="username" autocapitalize="none" placeholder="contoh: hasanbasri" /></div></div>
          <div><label for="d-email" class="label-isian">Email aktif</label>
            <div class="relative"><PhEnvelopeSimple :size="20" weight="duotone" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
              <input id="d-email" v-model="f.email" type="email" class="isian pl-11" autocomplete="email" /></div></div>
          <InputSandi id="d-s1" v-model="f.sandi" label="Kata sandi" kekuatan />
          <InputSandi id="d-s2" v-model="f.ulang" label="Ulangi kata sandi" />
        </div>
      </fieldset>

      <fieldset class="space-y-4">
        <legend class="judul-bagian mb-2">Data diri</legend>
        <div><label for="d-nama" class="label-isian">Nama lengkap bergelar</label><input id="d-nama" v-model="f.nama_lengkap" class="isian" placeholder="Seperti tertulis di dokumen resmi" /></div>
        <div class="grid gap-4 sm:grid-cols-2">
          <div><p class="label-isian">Jenis kelamin</p>
            <div class="grid grid-cols-2 gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" aria-label="Jenis kelamin">
              <button v-for="j in [{ k: 'L', n: 'Laki-laki' }, { k: 'P', n: 'Perempuan' }]" :key="j.k" type="button" role="radio" :aria-checked="f.jenis_kelamin === j.k" @click="f.jenis_kelamin = j.k"
                :class="['min-h-[44px] rounded-xl text-sm font-semibold', f.jenis_kelamin === j.k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">{{ j.n }}</button></div></div>
          <div><label for="d-niy" class="label-isian">NIY (bila sudah ada)</label><input id="d-niy" v-model="f.niy" class="isian" inputmode="numeric" /></div>
          <div><label for="d-tmp" class="label-isian">Tempat lahir</label><input id="d-tmp" v-model="f.tempat_lahir" class="isian" /></div>
          <InputTanggal v-model="f.tanggal_lahir" label="Tanggal lahir" bawaan-kosong />
          <div><label for="d-hp" class="label-isian">Nomor HP/WA</label><input id="d-hp" v-model="f.no_hp" class="isian" inputmode="tel" placeholder="08xxxxxxxxxx" /></div>
          <div><label for="d-pend" class="label-isian">Pendidikan terakhir</label>
            <select id="d-pend" v-model="f.pendidikan_terakhir" class="isian"><option value="">Pilih</option><option v-for="(n, k) in PENDIDIKAN" :key="k" :value="k">{{ n }}</option></select></div>
          <div><label for="d-kel" class="label-isian">Status keluarga</label>
            <select id="d-kel" v-model="f.status_keluarga" class="isian"><option value="">Pilih</option><option v-for="(n, k) in STATUS_KELUARGA" :key="k" :value="k">{{ n }}</option></select></div>
        </div>
      </fieldset>

      <fieldset class="space-y-4">
        <legend class="judul-bagian mb-2">Tugas di pondok</legend>
        <div><label for="d-unit" class="label-isian">Bidang/unit</label>
          <select id="d-unit" v-model="f.org_unit_id" class="isian"><option value="">Pilih</option>
            <option v-for="u in org.datar.filter((x) => x.aktif)" :key="u.id" :value="u.id">{{ '\u2003'.repeat(u.tingkat) }}{{ u.nama }}</option></select></div>
        <div><p class="label-isian">Jabatan fungsional (centang semua tugas Anda)</p>
          <div class="flex flex-wrap gap-1.5">
            <button v-for="j in fungsional" :key="j.id" type="button" :aria-pressed="f.fungsional_ids.includes(j.id)" @click="pilih(j)"
              :class="['min-h-[40px] rounded-full border px-3.5 text-sm font-semibold', f.fungsional_ids.includes(j.id) ? 'border-transparent bg-[#1E7D4F] text-white dark:bg-[#5BD69A] dark:text-[#10261B]' : 'border-garis text-teks2']">
              <PhCheckCircle v-if="f.fungsional_ids.includes(j.id)" :size="16" weight="fill" class="-ml-1 mr-1 inline" />{{ j.nama }}</button>
          </div></div>
        <div><label for="d-str" class="label-isian">Jabatan struktural (bila ada)</label>
          <select id="d-str" v-model="f.struktural_id" class="isian"><option value="">Tidak ada</option><option v-for="j in struktural" :key="j.id" :value="j.id">{{ j.nama }}</option></select></div>
      </fieldset>

      <button class="tombol-utama w-full" :disabled="proses">{{ proses ? 'Mengirim…' : 'Kirim pendaftaran' }}</button>
    </form>
    <template #bawah><span class="text-teks2">Sudah punya akun? </span><router-link to="/masuk" class="font-semibold text-merah">Masuk</router-link></template>
  </TataLetakAuth>
</template>
