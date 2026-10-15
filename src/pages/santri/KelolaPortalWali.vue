<!-- SIMKA PRO | src/pages/santri/KelolaPortalWali.vue | v1.0 | Fase 9 – Tahap 13.0.0 Fondasi Portal Wali | 15/10/2026 -->
<script setup>
// Data Santri → Portal Wali (superadmin; admin ber-izin Kelola santri).
// Tab: Ringkasan (kesiapan, tautan portal), Data belum lengkap, Sesi aktif (cabut), Percobaan gagal (buka kunci),
// Pengaturan (buka/tutup portal, cara masuk, batas salah, BUTIR INFORMASI yang dapat dinyalakan/dimatikan; ubah hanya superadmin).
import { computed, onMounted, ref, watch } from 'vue'
import {
  PhGauge, PhUserMinus, PhDeviceMobile, PhLockKey, PhGearSix, PhCheckCircle, PhUsers, PhSignIn, PhWarning, PhStudent, PhLink,
  PhCopy, PhShareNetwork, PhMagnifyingGlass, PhFileXls, PhPencilSimple, PhProhibit, PhLockOpen, PhFloppyDisk, PhLockSimple, PhLockSimpleOpen, PhShieldWarning,
} from '@phosphor-icons/vue'
import { useKelolaPortalWali } from '@/stores/kelolaPortalWali'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { BUTIR_PORTAL, HUBUNGAN_WALI, sudahTersedia } from '@/lib/portalWali'
import { VERSI_APLIKASI } from '@/lib/versi'
import { formatPendek, formatRelatif, formatJam } from '@/lib/tanggal'
import { eksporExcel } from '@/lib/excel'
import { namaBerkas } from '@/lib/namaBerkas'
import BilahTab from '@/components/BilahTab.vue'
import KartuStatistik from '@/components/KartuStatistik.vue'

const kp = useKelolaPortalWali(); const sesi = useSesi(); const ui = useUI()
const boleh = computed(() => sesi.bolehAdmin('kelola_santri'))
const tab = ref('ringkasan')
onMounted(() => { if (boleh.value) kp.muat() })

const TAB = computed(() => [
  { k: 'ringkasan', n: 'Ringkasan', ikon: PhGauge, w: 'beranda' },
  { k: 'kurang', n: 'Data belum lengkap', ikon: PhUserMinus, w: 'klinik', jumlah: kp.kurang.length },
  { k: 'sesi', n: 'Sesi aktif', ikon: PhDeviceMobile, w: 'presensi', jumlah: kp.sesi.length },
  { k: 'gagal', n: 'Percobaan gagal', ikon: PhLockKey, w: 'security', lencana: kp.terkunci.length || null, jumlah: kp.terkunci.length ? null : kp.gagal.length },
  { k: 'pengaturan', n: 'Pengaturan', ikon: PhGearSix, w: 'pengaturan' },
])

// ---------- Ringkasan ----------
const r = computed(() => kp.ringkasan || {})
const kartu = computed(() => [
  { judul: 'Siap masuk portal', nilai: r.value.siap, ikon: PhCheckCircle, warna: 'presensi', ket: `dari ${r.value.santri ?? 0} santri aktif` },
  { judul: 'Data belum lengkap', nilai: kp.kurang.length, ikon: PhUserMinus, warna: 'klinik', ket: 'Tanggal lahir atau nomor HP kosong' },
  { judul: 'Anak dipantau wali', nilai: r.value.santri_bersesi, ikon: PhStudent, warna: 'santri', ket: `${r.value.sesi_aktif ?? 0} perangkat masuk` },
  { judul: 'Dibuka 7 hari terakhir', nilai: r.value.dibuka_7_hari, ikon: PhUsers, warna: 'pengumuman', ket: 'Santri yang portalnya dibuka wali' },
  { judul: 'Masuk 7 hari terakhir', nilai: r.value.masuk_7_hari, ikon: PhSignIn, warna: 'tahfizh', ket: 'Wali yang berhasil masuk' },
  { judul: 'Gagal 24 jam terakhir', nilai: r.value.gagal_24_jam, ikon: PhWarning, warna: 'security', ket: `${kp.terkunci.length} sedang terkunci` },
])
const tautan = computed(() => `${location.origin}${location.pathname}#/wali`)
async function salin() {
  try { await navigator.clipboard.writeText(tautan.value); ui.toast('Tautan Portal Wali disalin.', 'sukses') }
  catch { ui.toast('Tautan tidak dapat disalin otomatis. Salin secara manual.', 'galat') }
}
const bisaBagikan = typeof navigator !== 'undefined' && !!navigator.share
function bagikan() { navigator.share({ title: 'Portal Wali Santri', text: 'Pantau perkembangan ananda di pondok melalui Portal Wali SIMKA PRO:', url: tautan.value }).catch(() => {}) }

// ---------- Data belum lengkap ----------
const cariK = ref('')
const kurangTampil = computed(() => {
  const q = cariK.value.toLowerCase().trim()
  return kp.kurang.filter((s) => !q || [s.nis, s.nisn, s.nama, s.kelas].join(' ').toLowerCase().includes(q))
})
function eksporKurang() {
  eksporExcel(`${namaBerkas('Santri Belum Siap Portal Wali', formatPendek(new Date()))}.xlsx`, [
    { judul: 'NIS', kunci: 'nis' }, { judul: 'Nama', kunci: 'nama' }, { judul: 'JK', kunci: 'jk' }, { judul: 'NISN', kunci: 'nisn' },
    { judul: 'Kelas', kunci: 'kelas' }, { judul: 'Data yang perlu dilengkapi', kunci: 'kurang' },
  ], kurangTampil.value, 'Belum lengkap')
}

// ---------- Sesi ----------
const cariS = ref('')
const sesiTampil = computed(() => {
  const q = cariS.value.toLowerCase().trim()
  return kp.sesi.filter((s) => !q || [s.nis, s.nama, s.kelas, s.nama_wali, s.perangkat].join(' ').toLowerCase().includes(q))
})
async function cabut(s, semua = false) {
  const pesan = semua ? `Cabut semua sesi Portal Wali untuk ${s.nama}? Semua wali santri ini harus masuk kembali.`
    : `Cabut sesi ${HUBUNGAN_WALI[s.hubungan] || 'wali'} ${s.nama_wali || ''} (${s.perangkat || 'perangkat'}) untuk ${s.nama}?`
  if (!(await ui.konfirmasi({ judul: 'Cabut sesi', pesan, ya: 'Cabut', bahaya: true }))) return
  try { const n = await kp.cabut(semua ? { santri: s.student_id, alasan: 'Dicabut pengelola' } : { sesi: s.id, alasan: 'Dicabut pengelola' }); ui.toast(`${n} sesi dicabut.`, 'sukses') }
  catch (e) { ui.toast(e.message, 'galat') }
}
async function cabutSemua() {
  if (!(await ui.konfirmasi({ judul: 'Cabut semua sesi', pesan: 'Semua wali di semua perangkat harus masuk kembali. Lanjutkan?', ya: 'Cabut semua', bahaya: true }))) return
  try { const n = await kp.cabut({ alasan: 'Semua sesi dicabut superadmin' }); ui.toast(`${n} sesi dicabut.`, 'sukses') }
  catch (e) { ui.toast(e.message, 'galat') }
}

// ---------- Percobaan gagal ----------
const terkunci = (g) => g.terkunci_sampai && new Date(g.terkunci_sampai) > new Date()
async function bukaKunci(g) {
  try { await kp.bukaKunci(g.kunci); ui.toast(`Kunci ${g.nama || g.kunci} dibuka. Wali dapat mencoba masuk lagi.`, 'sukses') }
  catch (e) { ui.toast(e.message, 'galat') }
}

// ---------- Pengaturan ----------
const f = ref(null)
watch(() => kp.pengaturan, (p) => { if (p) f.value = JSON.parse(JSON.stringify(p)) }, { immediate: true })
const bolehUbah = computed(() => !!kp.pengaturan?.boleh_ubah)
const prosesSimpan = ref(false)
async function simpan() {
  if (f.value.aktif && !kp.pengaturan.aktif && !(await ui.konfirmasi({
    judul: 'Buka Portal Wali', ya: 'Buka portal',
    pesan: `Wali santri dapat masuk dan melihat butir informasi yang dinyalakan. ${kp.kurang.length ? `${kp.kurang.length} santri belum lengkap datanya sehingga walinya belum dapat masuk.` : ''}`,
  }))) return
  prosesSimpan.value = true
  try { await kp.simpan(f.value); ui.toast('Pengaturan Portal Wali disimpan.', 'sukses') }
  catch (e) { ui.toast(e.message, 'galat') }
  finally { prosesSimpan.value = false }
}
const berubah = computed(() => f.value && kp.pengaturan && JSON.stringify({ ...f.value, boleh_ubah: 0 }) !== JSON.stringify({ ...kp.pengaturan, boleh_ubah: 0 }))
</script>

<template>
  <div v-if="!boleh" class="kartu p-6 text-center text-teks2">Halaman ini untuk superadmin dan admin ber-izin Kelola santri.</div>
  <div v-else class="space-y-4">
    <BilahTab v-model="tab" :tab="TAB" label="Bagian Portal Wali" />
    <p v-if="kp.galat" class="kartu p-4 text-sm font-semibold text-merah" role="alert">{{ kp.galat }}</p>
    <p v-if="kp.memuat && !kp.ringkasan" class="py-10 text-center text-teks3">Memuat data Portal Wali…</p>

    <!-- RINGKASAN -->
    <template v-if="tab === 'ringkasan' && kp.ringkasan">
      <div :class="['kartu flex flex-wrap items-center gap-3 p-4', r.aktif ? 'w-presensi' : 'w-pengajuan']">
        <span class="chip-ikon h-11 w-11"><component :is="r.aktif ? PhLockSimpleOpen : PhLockSimple" :size="24" weight="duotone" /></span>
        <div class="min-w-0 flex-1">
          <p class="font-bold">Portal Wali {{ r.aktif ? 'dibuka' : 'ditutup' }}</p>
          <p class="text-sm text-teks2">{{ r.aktif ? 'Wali santri dapat masuk dan melihat butir informasi yang dinyalakan.' : 'Wali santri belum dapat masuk. Lengkapi data santri, lalu buka portal di tab Pengaturan.' }}</p>
        </div>
        <button class="tombol-garis text-sm" @click="tab = 'pengaturan'"><PhGearSix :size="18" weight="duotone" /> Pengaturan</button>
      </div>
      <div class="grid grid-cols-2 gap-3 lg:grid-cols-3">
        <KartuStatistik v-for="k in kartu" :key="k.judul" :judul="k.judul" :nilai="k.nilai" :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket" />
      </div>
      <div class="kartu w-laporan p-4 sm:p-5">
        <div class="flex items-center gap-3">
          <span class="chip-ikon h-10 w-10"><PhLink :size="22" weight="duotone" /></span>
          <div class="min-w-0 flex-1"><h2 class="judul-bagian">Tautan Portal Wali</h2><p class="text-sm text-teks3">Bagikan ke grup WA wali santri. Wali dapat memasang portal di layar utama HP.</p></div>
        </div>
        <p class="mt-3 break-all rounded-xl bg-permukaan2 px-3 py-2.5 font-mono text-sm">{{ tautan }}</p>
        <div class="mt-3 flex flex-wrap gap-2">
          <button class="tombol-garis text-sm" @click="salin"><PhCopy :size="18" weight="duotone" /> Salin tautan</button>
          <button v-if="bisaBagikan" class="tombol-garis text-sm" @click="bagikan"><PhShareNetwork :size="18" weight="duotone" /> Bagikan</button>
        </div>
      </div>
      <div class="kartu w-pengumuman p-4 text-sm text-teks2 sm:p-5">
        <p class="font-bold text-teks">Cara masuk wali</p>
        <p class="mt-1">{{ kp.pengaturan?.identitas === 'nisn' ? 'NISN' : 'NIS atau NISN' }} santri + tanggal lahir santri + 6 digit terakhir nomor HP ayah, ibu, atau wali yang terdaftar di Data Santri.
          Salah {{ kp.pengaturan?.maks_salah }} kali berturut-turut dikunci {{ kp.pengaturan?.kunci_menit }} menit. Masuk berlaku {{ kp.pengaturan?.lama_sesi_hari }} hari di perangkat itu,
          dan otomatis berakhir bila nomor HP, NIS/NISN, tanggal lahir, atau status santri diubah.</p>
      </div>
    </template>

    <!-- DATA BELUM LENGKAP -->
    <template v-if="tab === 'kurang'">
      <div class="flex flex-wrap gap-2">
        <div class="relative min-w-[220px] flex-1">
          <PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
          <input v-model="cariK" class="isian pl-11" placeholder="Cari NIS, nama, atau kelas" aria-label="Cari santri" />
        </div>
        <button class="w-gaji tombol-garis shrink-0 px-4 text-sm" :disabled="!kurangTampil.length" @click="eksporKurang"><PhFileXls :size="20" weight="duotone" style="color: var(--c)" /> Ekspor Excel</button>
      </div>
      <p class="text-sm text-teks3">Wali santri berikut belum dapat masuk portal. Lengkapi lewat tombol Lengkapi, atau impor Excel di Data Santri.</p>
      <div v-if="!kurangTampil.length" class="kartu p-8 text-center text-teks3">Semua santri aktif sudah lengkap datanya untuk Portal Wali.</div>
      <div v-else class="kartu overflow-hidden">
        <table class="hidden w-full text-left text-sm md:table">
          <thead class="bg-permukaan2 text-teks2"><tr><th class="px-4 py-3 font-bold">NIS</th><th class="px-4 py-3 font-bold">Nama</th><th class="px-4 py-3 font-bold">JK</th>
            <th class="px-4 py-3 font-bold">Kelas</th><th class="px-4 py-3 font-bold">Perlu dilengkapi</th><th class="w-28" /></tr></thead>
          <tbody class="divide-y divide-garis/70">
            <tr v-for="s in kurangTampil" :key="s.id">
              <td class="px-4 py-2.5 tabular-nums">{{ s.nis }}</td><td class="px-4 py-2.5 font-semibold">{{ s.nama }}</td><td class="px-4 py-2.5">{{ s.jk }}</td>
              <td class="px-4 py-2.5">{{ s.kelas || '–' }}</td>
              <td class="px-4 py-2.5"><span v-for="k in s.kurang" :key="k" class="lencana w-klinik mr-1">{{ k }}</span></td>
              <td class="px-4 py-2.5 text-right"><router-link :to="`/santri/${s.id}/ubah`" class="tombol-teks min-h-[36px] text-sm"><PhPencilSimple :size="16" /> Lengkapi</router-link></td>
            </tr>
          </tbody>
        </table>
        <ul class="divide-y divide-garis/70 md:hidden">
          <li v-for="s in kurangTampil" :key="s.id" class="flex items-center gap-3 p-3">
            <div class="min-w-0 flex-1"><p class="truncate font-semibold">{{ s.nama }}</p><p class="text-sm tabular-nums text-teks3">NIS {{ s.nis }} · {{ s.kelas || 'tanpa kelas' }}</p>
              <p class="mt-1"><span v-for="k in s.kurang" :key="k" class="lencana w-klinik mr-1">{{ k }}</span></p></div>
            <router-link :to="`/santri/${s.id}/ubah`" class="tombol-ikon h-11 w-11" :aria-label="'Lengkapi data ' + s.nama"><PhPencilSimple :size="22" /></router-link>
          </li>
        </ul>
      </div>
    </template>

    <!-- SESI AKTIF -->
    <template v-if="tab === 'sesi'">
      <div class="flex flex-wrap gap-2">
        <div class="relative min-w-[220px] flex-1">
          <PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
          <input v-model="cariS" class="isian pl-11" placeholder="Cari santri, wali, atau perangkat" aria-label="Cari sesi" />
        </div>
        <button v-if="sesi.isSuperadmin && kp.sesi.length" class="tombol-garis shrink-0 px-4 text-sm text-merah" @click="cabutSemua"><PhShieldWarning :size="20" weight="duotone" /> Cabut semua sesi</button>
      </div>
      <div v-if="!sesiTampil.length" class="kartu p-8 text-center text-teks3">Belum ada wali yang masuk Portal Wali.</div>
      <ul v-else class="space-y-2">
        <li v-for="s in sesiTampil" :key="s.id" class="kartu flex flex-wrap items-center gap-3 p-3 sm:p-4">
          <span class="w-presensi chip-ikon h-10 w-10"><PhDeviceMobile :size="22" weight="duotone" /></span>
          <div class="min-w-0 flex-1">
            <p class="truncate font-semibold">{{ s.nama }} <span class="font-normal tabular-nums text-teks3">· NIS {{ s.nis }}<template v-if="s.kelas"> · {{ s.kelas }}</template></span></p>
            <p class="text-sm text-teks2">{{ HUBUNGAN_WALI[s.hubungan] || 'Wali' }}<template v-if="s.nama_wali"> ({{ s.nama_wali }})</template> · {{ s.perangkat || 'Perangkat tidak dikenal' }}</p>
            <p class="text-xs text-teks3">Terakhir dibuka {{ formatRelatif(s.terakhir) }} · masuk {{ formatPendek(s.dibuat) }} · berlaku sampai {{ formatPendek(s.kedaluwarsa) }}</p>
          </div>
          <div class="flex gap-1">
            <button class="tombol-garis min-h-[40px] px-3 text-sm" @click="cabut(s)"><PhProhibit :size="18" /> Cabut</button>
            <button class="tombol-teks min-h-[40px] px-3 text-sm" @click="cabut(s, true)">Semua sesi santri</button>
          </div>
        </li>
      </ul>
    </template>

    <!-- PERCOBAAN GAGAL -->
    <template v-if="tab === 'gagal'">
      <p class="text-sm text-teks3">Percobaan masuk gagal 7 hari terakhir sejak masuk berhasil terakhir. Bila wali menghubungi pondok karena terkunci, periksa dulu data santri, lalu tekan Buka kunci.</p>
      <div v-if="!kp.gagal.length" class="kartu p-8 text-center text-teks3">Tidak ada percobaan masuk yang gagal.</div>
      <ul v-else class="space-y-2">
        <li v-for="g in kp.gagal" :key="g.kunci" class="kartu flex flex-wrap items-center gap-3 p-3 sm:p-4">
          <span :class="['chip-ikon h-10 w-10', terkunci(g) ? 'w-klinik' : 'w-security']"><component :is="terkunci(g) ? PhLockKey : PhWarning" :size="22" weight="duotone" /></span>
          <div class="min-w-0 flex-1">
            <p class="truncate font-semibold">{{ g.nama || 'NIS/NISN tidak ditemukan' }} <span class="font-normal tabular-nums text-teks3">· {{ g.kunci }}</span></p>
            <p class="text-sm text-teks2">{{ g.gagal }} kali gagal · terakhir {{ formatRelatif(g.terakhir) }} · {{ g.alasan }}</p>
            <p v-if="terkunci(g)" class="text-xs font-semibold text-merah">Terkunci sampai pukul {{ formatJam(g.terkunci_sampai) }} WITA</p>
          </div>
          <button class="tombol-garis min-h-[40px] px-3 text-sm" @click="bukaKunci(g)"><PhLockOpen :size="18" /> Buka kunci</button>
        </li>
      </ul>
    </template>

    <!-- PENGATURAN -->
    <template v-if="tab === 'pengaturan' && f">
      <p v-if="!bolehUbah" class="kartu w-pengajuan p-4 text-sm">Pengaturan hanya dapat diubah superadmin. Anda dapat melihatnya.</p>
      <fieldset :disabled="!bolehUbah" class="space-y-4">
        <div class="kartu w-presensi p-4 sm:p-5">
          <div class="flex items-center gap-3">
            <span class="chip-ikon h-10 w-10"><component :is="f.aktif ? PhLockSimpleOpen : PhLockSimple" :size="22" weight="duotone" /></span>
            <div class="min-w-0 flex-1"><p class="font-bold">Buka Portal Wali</p><p class="text-sm text-teks3">{{ f.aktif ? 'Portal dibuka: wali dapat masuk.' : 'Portal ditutup: wali melihat pesan di bawah.' }}</p></div>
            <button type="button" role="switch" :aria-checked="f.aktif" aria-label="Buka Portal Wali" @click="f.aktif = !f.aktif"
              :class="['relative h-8 w-14 shrink-0 rounded-full transition', f.aktif ? 'bg-[#1E7D4F]' : 'bg-garis']"><span :class="['absolute top-1 h-6 w-6 rounded-full bg-white shadow transition-all', f.aktif ? 'left-7' : 'left-1']" /></button>
          </div>
          <label class="label-isian mt-4" for="pw-tutup">Pesan saat portal ditutup</label>
          <textarea id="pw-tutup" v-model="f.pesan_tutup" class="isian min-h-[72px] py-2.5" maxlength="300" />
        </div>

        <div class="kartu w-hakakses grid gap-4 p-4 sm:grid-cols-2 sm:p-5">
          <div class="sm:col-span-2"><p class="font-bold">Cara masuk dan keamanan</p></div>
          <div>
            <label class="label-isian" for="pw-id">Identitas santri</label>
            <select id="pw-id" v-model="f.identitas" class="isian">
              <option value="nis_nisn">NIS atau NISN (disarankan)</option><option value="nisn">NISN saja</option>
            </select>
          </div>
          <div>
            <label class="label-isian" for="pw-hari">Masuk berlaku (hari)</label>
            <input id="pw-hari" v-model.number="f.lama_sesi_hari" type="number" min="1" max="180" class="isian tabular-nums" />
          </div>
          <div>
            <label class="label-isian" for="pw-salah">Batas salah berturut-turut</label>
            <input id="pw-salah" v-model.number="f.maks_salah" type="number" min="3" max="10" class="isian tabular-nums" />
          </div>
          <div>
            <label class="label-isian" for="pw-menit">Lama terkunci (menit)</label>
            <input id="pw-menit" v-model.number="f.kunci_menit" type="number" min="5" max="120" class="isian tabular-nums" />
          </div>
        </div>

        <div class="kartu w-santri p-4 sm:p-5">
          <p class="font-bold">Butir informasi untuk wali</p>
          <p class="text-sm text-teks3">Nyalakan butir yang boleh dibaca wali. Butir yang dimatikan tidak dikirim server ke portal. Butir bertanda <b>Sensitif</b> bawaannya mati; butir bertanda <b>Menyusul</b> sudah dapat diatur tetapi baru tampil di portal pada pembaruan berikutnya.</p>
          <ul class="mt-3 divide-y divide-garis rounded-xl border border-garis">
            <li v-for="b in BUTIR_PORTAL" :key="b.k" :class="['flex items-center gap-3 px-3 py-3', 'w-' + b.w]">
              <span class="chip-ikon h-9 w-9 rounded-lg"><component :is="b.ikon" :size="20" weight="duotone" /></span>
              <div class="min-w-0 flex-1">
                <p class="text-sm font-semibold">{{ b.n }} <span v-if="b.sensitif" class="lencana w-klinik ml-1">Sensitif</span>
                  <span v-if="!sudahTersedia(b, VERSI_APLIKASI)" class="lencana w-hakakses ml-1">Menyusul</span></p>
                <p class="text-xs text-teks3">{{ b.ket }}</p>
              </div>
              <button type="button" role="switch" :aria-checked="!!f.butir[b.k]" :aria-label="'Tampilkan ' + b.n" @click="f.butir[b.k] = !f.butir[b.k]"
                :class="['relative h-8 w-14 shrink-0 rounded-full transition', f.butir[b.k] ? 'bg-[#1E7D4F]' : 'bg-garis']"><span :class="['absolute top-1 h-6 w-6 rounded-full bg-white shadow transition-all', f.butir[b.k] ? 'left-7' : 'left-1']" /></button>
            </li>
          </ul>
        </div>
        <button v-if="bolehUbah" class="tombol-utama w-full sm:w-auto" :disabled="prosesSimpan || !berubah" @click="simpan">
          <PhFloppyDisk :size="20" weight="duotone" /> {{ prosesSimpan ? 'Menyimpan…' : 'Simpan pengaturan' }}</button>
      </fieldset>
    </template>
  </div>
</template>
