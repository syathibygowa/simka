<!-- SIMKA PRO | src/pages/klinik/TabKetentuanKlinik.vue | v1.0 | Fase 6 – Tahap 1 Dasar Klinik | 06/10/2026 -->
<script setup>
// Ketentuan klinik: jam layanan, batas waktu pemeriksaan rujukan (dasar tanda merah), jadwal kontrol bawaan,
// dan petugas Klinik Putra/Putri. Diubah oleh superadmin, admin ber-izin kelola_klinik, atau hak fitur Klinik tingkat 3.
// Pengguna lain hanya membaca.
import { ref, computed, onMounted } from 'vue'
import { PhClock, PhPlus, PhTrash, PhFloppyDisk, PhGenderMale, PhGenderFemale, PhUserPlus, PhInfo } from '@phosphor-icons/vue'
import { useKlinik } from '@/stores/klinik'
import { useUI } from '@/stores/ui'
import { KLINIK } from '@/lib/klinik'
import LembarBawah from '@/components/LembarBawah.vue'

const kl = useKlinik(); const ui = useUI()
const isi = ref(null); const proses = ref(false)
const salin = () => { isi.value = JSON.parse(JSON.stringify(kl.pengaturan)) }
onMounted(async () => { try { await kl.muatPengaturan(); salin() } catch (e) { ui.toast(e.message, 'galat') } })
const boleh = computed(() => kl.hak.atur)

function tambahJam() { isi.value.jam_layanan.push({ mulai: '13:00', selesai: '15:00' }) }
async function simpan() {
  for (const j of isi.value.jam_layanan) if (!j.mulai || !j.selesai || j.selesai <= j.mulai) return ui.toast(`Jam layanan ${j.mulai || '?'}–${j.selesai || '?'} tidak sah.`, 'galat')
  proses.value = true
  try {
    await kl.simpanPengaturan({ jam_layanan: isi.value.jam_layanan, batas_hari_ini_menit: Number(isi.value.batas_hari_ini_menit),
      batas_besok_jam: isi.value.batas_besok_jam, kontrol_bawaan_hari: Number(isi.value.kontrol_bawaan_hari) })
    salin(); ui.toast('Ketentuan klinik tersimpan.')
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}

// ---------- Petugas ----------
const petugasDi = (k) => kl.petugas.filter((p) => p.klinik === k)
const lembar = ref(false); const klinikBaru = ref('putra'); const calon = ref([]); const pilih = ref(''); const catatan = ref(''); const cari = ref('')
async function bukaTambah(k) {
  klinikBaru.value = k; pilih.value = ''; catatan.value = ''; cari.value = ''; lembar.value = true
  try { calon.value = await kl.calonPetugas() } catch (e) { ui.toast(e.message, 'galat') }
}
const calonTampil = computed(() => {
  const ada = new Set(petugasDi(klinikBaru.value).map((p) => p.employee_id)); const q = cari.value.toLowerCase().trim()
  return calon.value.filter((c) => !ada.has(c.id) && (!q || c.nama.toLowerCase().includes(q)))
    .sort((a, b) => Number(b.medis) - Number(a.medis) || a.nama.localeCompare(b.nama, 'id'))
})
async function tambah() {
  if (!pilih.value) return ui.toast('Pilih pegawai.', 'galat')
  proses.value = true
  try { await kl.simpanPetugas(pilih.value, klinikBaru.value, true, catatan.value.trim()); lembar.value = false; ui.toast(`Petugas ditambahkan ke ${KLINIK[klinikBaru.value]}.`) }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
async function ubahAktif(p) {
  try { await kl.simpanPetugas(p.employee_id, p.klinik, !p.aktif, p.catatan || ''); ui.toast(p.aktif ? 'Petugas dinonaktifkan.' : 'Petugas diaktifkan.') } catch (e) { ui.toast(e.message, 'galat') }
}
async function hapus(p) {
  if (!(await ui.konfirmasi({ judul: 'Hapus petugas?', pesan: `${p.nama} tidak lagi menerima rujukan ${KLINIK[p.klinik]}. Catatan pemeriksaan lamanya tetap tersimpan.`, ya: 'Hapus' }))) return
  try { await kl.hapusPetugas(p.id); ui.toast('Petugas dihapus.') } catch (e) { ui.toast(e.message, 'galat') }
}
</script>
<template>
  <div v-if="isi" class="space-y-4">
    <p v-if="!boleh" class="kartu flex items-start gap-3 p-4 text-sm text-teks2"><PhInfo :size="22" weight="duotone" class="shrink-0" />
      Ketentuan ini diatur oleh superadmin atau admin ber-izin kelola klinik. Anda dapat membacanya.</p>

    <section class="kartu w-klinik p-4 sm:p-5">
      <h2 class="judul-bagian flex items-center gap-2"><PhClock :size="22" weight="duotone" style="color: var(--c)" /> Jam layanan dan batas waktu</h2>
      <p class="mt-1 text-sm text-teks2">Rujukan "hari ini" wajib diperiksa dalam batas waktu yang dihitung dari jam rujukan (atau dari jam layanan berikutnya bila dirujuk di luar jam layanan). Rujukan yang melewati batas ditandai merah.</p>
      <div class="mt-3 space-y-2">
        <div v-for="(j, i) in isi.jam_layanan" :key="i" class="flex items-end gap-2">
          <div class="flex-1"><label class="label-isian" :for="'jl-m' + i">Layanan {{ i + 1 }} mulai</label><input :id="'jl-m' + i" v-model="j.mulai" type="time" class="isian tabular-nums" :disabled="!boleh" /></div>
          <div class="flex-1"><label class="label-isian" :for="'jl-s' + i">selesai</label><input :id="'jl-s' + i" v-model="j.selesai" type="time" class="isian tabular-nums" :disabled="!boleh" /></div>
          <button v-if="boleh && isi.jam_layanan.length > 1" class="tombol-ikon mb-1" :aria-label="`Hapus jam layanan ${i + 1}`" @click="isi.jam_layanan.splice(i, 1)"><PhTrash :size="20" /></button>
        </div>
        <button v-if="boleh" class="tombol-garis min-h-[38px] px-3 text-sm" @click="tambahJam"><PhPlus :size="18" /> Tambah jam layanan</button>
      </div>
      <div class="mt-4 grid gap-3 sm:grid-cols-3">
        <div><label class="label-isian" for="kl-bh">Batas periksa "hari ini" (menit)</label><input id="kl-bh" v-model="isi.batas_hari_ini_menit" type="number" min="15" max="1440" step="15" class="isian tabular-nums" :disabled="!boleh" /></div>
        <div><label class="label-isian" for="kl-bb">Batas periksa "besok" (jam)</label><input id="kl-bb" v-model="isi.batas_besok_jam" type="time" class="isian tabular-nums" :disabled="!boleh" /></div>
        <div><label class="label-isian" for="kl-kt">Jadwal kontrol bawaan (hari)</label><input id="kl-kt" v-model="isi.kontrol_bawaan_hari" type="number" min="0" max="30" class="isian tabular-nums" :disabled="!boleh" />
          <p class="mt-1 text-xs text-teks3">0 = tidak dijadwalkan otomatis.</p></div>
      </div>
      <button v-if="boleh" class="tombol-utama mt-4" :disabled="proses" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> Simpan ketentuan</button>
    </section>

    <div class="grid gap-4 lg:grid-cols-2">
      <section v-for="k in ['putra', 'putri']" :key="k" class="kartu p-4 sm:p-5" :class="k === 'putra' ? 'w-security' : 'w-klinik'">
        <div class="flex items-center justify-between gap-2">
          <h2 class="judul-bagian flex items-center gap-2"><component :is="k === 'putra' ? PhGenderMale : PhGenderFemale" :size="22" weight="duotone" style="color: var(--c)" /> Petugas {{ KLINIK[k] }}</h2>
          <button v-if="boleh" class="tombol-garis min-h-[38px] px-3 text-sm" @click="bukaTambah(k)"><PhUserPlus :size="18" /> Tambah</button>
        </div>
        <p class="mt-1 text-xs text-teks3">Rujukan santri {{ k }} masuk ke antrean dan notifikasi petugas ini.</p>
        <p v-if="!petugasDi(k).some((p) => p.aktif)" class="mt-3 rounded-xl bg-permukaan2 p-3 text-sm font-semibold text-merah">Belum ada petugas aktif. Rujukan akan diteruskan ke admin pengelola klinik.</p>
        <ul class="mt-3 divide-y divide-garis rounded-xl border border-garis">
          <li v-for="p in petugasDi(k)" :key="p.id" class="flex items-center gap-3 px-3 py-2.5 text-sm" :class="!p.aktif && 'opacity-60'">
            <span class="min-w-0 flex-1"><b class="block truncate">{{ p.nama }}</b>
              <span class="text-xs text-teks3">{{ p.aktif ? 'Aktif' : 'Nonaktif' }}{{ p.punya_akun ? '' : ' · belum punya akun' }}{{ p.catatan ? ' · ' + p.catatan : '' }}</span></span>
            <template v-if="boleh">
              <button class="tombol-garis min-h-[36px] px-3 text-xs" @click="ubahAktif(p)">{{ p.aktif ? 'Nonaktifkan' : 'Aktifkan' }}</button>
              <button class="tombol-ikon" :aria-label="`Hapus ${p.nama}`" @click="hapus(p)"><PhTrash :size="20" /></button>
            </template>
          </li>
          <li v-if="!petugasDi(k).length" class="p-4 text-center text-sm text-teks3">Belum ada petugas.</li>
        </ul>
      </section>
    </div>

    <LembarBawah v-model="lembar" :judul="`Tambah petugas ${KLINIK[klinikBaru]}`">
      <div class="space-y-3 pb-2">
        <input v-model="cari" type="search" class="isian" placeholder="Cari pegawai" aria-label="Cari pegawai" />
        <ul class="max-h-[45dvh] divide-y divide-garis overflow-y-auto rounded-xl border border-garis">
          <li v-for="c in calonTampil" :key="c.id"><label class="flex min-h-[48px] cursor-pointer items-center gap-3 px-3 text-sm hover:bg-permukaan2">
            <input v-model="pilih" type="radio" :value="c.id" class="h-5 w-5 accent-[#C7332F]" />
            <span class="min-w-0 flex-1"><b class="block truncate">{{ c.nama }}</b><span class="text-xs text-teks3">{{ c.jenis_kelamin === 'P' ? 'Perempuan' : 'Laki-laki' }}{{ c.medis ? ' · Petugas kesehatan' : '' }}</span></span></label></li>
        </ul>
        <input v-model="catatan" class="isian" placeholder="Keterangan (opsional), contoh: membantu sementara" aria-label="Keterangan" />
        <button class="tombol-utama w-full" :disabled="proses || !pilih" @click="tambah"><PhUserPlus :size="20" weight="duotone" /> Tambahkan</button>
      </div>
    </LembarBawah>
  </div>
  <p v-else class="kartu p-8 text-center text-sm text-teks3">Memuat ketentuan…</p>
</template>
