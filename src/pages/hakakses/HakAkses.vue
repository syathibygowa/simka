<!-- SIMKA PRO | src/pages/hakakses/HakAkses.vue | v2.0 | Perbaikan 14.0.0: semua menu dapat diatur, baris Semua pegawai, Bawaan/Tidak ada per jabatan, fitur terkunci | 17/10/2026 -->
<script setup>
// Hak akses fitur (superadmin): Semua pegawai (bawaan) → per jabatan → per bidang → per individu (tertinggi).
// v2.0 (14.0.0): SETIAP menu SIMKA punya baris di sini. Baris "Semua pegawai" di tab Per jabatan memberi hak bawaan
//       setiap pegawai; jabatan dapat mengikuti bawaan atau diberi tingkat sendiri, termasuk "Tidak ada".
//       Fitur terkunci (Beranda, Notifikasi, Profil, Setelan, Hak Akses) ditampilkan beserta alasannya; Gaji, Tunjangan,
//       dan Keuangan diatur per orang di tab Fitur sensitif.
// Tab "Rekap jabatan": ceklist fitur per jabatan/bidang (bisa dicetak). Tab "Rekap admin": matriks izin setiap admin.
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { PhIdentificationBadge, PhTreeStructure, PhUser, PhInfo, PhListChecks, PhLockKey, PhUserGear, PhTable, PhCaretDown, PhUsersThree, PhLock, PhArrowRight } from '@phosphor-icons/vue'
import TabAksesSensitif from './TabAksesSensitif.vue'
import TabRekapAdmin from './TabRekapAdmin.vue'
import TabRekapJabatan from './TabRekapJabatan.vue'
import { useAkses, TINGKAT, SEMUA_ID } from '@/stores/akses'
import { useOrganisasi } from '@/stores/organisasi'
import { usePegawai } from '@/stores/pegawai'
import { useUI } from '@/stores/ui'

const props = defineProps({ tab: { type: String, default: 'jabatan' } })
const router = useRouter()
const akses = useAkses(); const org = useOrganisasi(); const peg = usePegawai(); const ui = useUI()
const siap = ref(false)
onMounted(async () => {
  try { await Promise.all([akses.muat(), org.muat(), peg.daftar.length ? null : peg.muat()]) } catch (e) { ui.toast(e.message, 'galat') }
  siap.value = true
})
const TAB = [
  { k: 'jabatan', n: 'Per jabatan', ikon: PhIdentificationBadge, w: 'presensi', ket: 'Lapis dasar: "Semua pegawai" memberi hak bawaan setiap pegawai; setiap jabatan fungsional dan struktural dapat mengikuti bawaan atau diberi tingkat sendiri, termasuk Tidak ada.' },
  { k: 'bidang', n: 'Per bidang', ikon: PhTreeStructure, w: 'santri', ket: 'Lapis kedua: menambah atau mencabut akses seluruh pegawai di bidang/unit beserta cabangnya.' },
  { k: 'individu', n: 'Per individu', ikon: PhUser, w: 'pengajuan', ket: 'Lapis tertinggi: pengecualian untuk pegawai tertentu. Akses superadmin tidak dapat dicabut.' },
  { k: 'rekap', n: 'Rekap jabatan', ikon: PhTable, w: 'laporan', ket: 'Ceklist fitur yang dapat diakses setiap jabatan dan bidang.' },
  { k: 'admin', n: 'Rekap admin', ikon: PhUserGear, w: 'verifikasi', ket: 'Daftar akses setiap admin dalam satu tabel centang.' },
  { k: 'sensitif', n: 'Fitur sensitif', ikon: PhLockKey, w: 'gaji', ket: 'Gaji, tunjangan, dan keuangan santri: hanya superadmin dan pegawai yang ditunjuk di sini.' },
]
const aktif = computed(() => TAB.find((t) => t.k === props.tab) || TAB[0])

// ---------- Sasaran ----------
const efektif = ref([])   // akses efektif individu (diisi muatEfektif)
const pilihan = ref('')   // 'semua:<id>' | 'fungsional:<id>' | 'struktural:<id>' | 'bidang:<id>' | 'individu:<id>'
const cari = ref('')
watch(() => props.tab, () => { pilihan.value = aktif.value.k === 'jabatan' ? `semua:${SEMUA_ID}` : ''; efektif.value = [] }, { immediate: true })
const daftarSasaran = computed(() => {
  if (aktif.value.k === 'jabatan') return [
    { v: `semua:${SEMUA_ID}`, n: 'Semua pegawai', ket: 'Hak bawaan setiap pegawai', semua: true },
    ...org.fungsional.filter((j) => j.aktif).map((j) => ({ v: `fungsional:${j.id}`, n: j.nama, ket: 'Fungsional' })),
    ...[...org.struktural].filter((j) => j.aktif).sort((a, b) => a.tingkat - b.tingkat).map((j) => ({ v: `struktural:${j.id}`, n: j.nama, ket: 'Struktural' })),
  ]
  if (aktif.value.k === 'bidang') return org.datar.filter((u) => u.aktif).map((u) => ({ v: `bidang:${u.id}`, n: u.nama, ket: u.jenis === 'unit' ? 'Unit' : u.jenis === 'pimpinan' ? 'Seluruh pondok' : 'Bidang', tingkat: u.tingkat }))
  const q = cari.value.toLowerCase()
  return peg.daftar.filter((p) => p.peran !== 'superadmin' && p.status_akun !== 'ditolak' && (!q || p.nama_lengkap.toLowerCase().includes(q)))
    .map((p) => ({ v: `individu:${p.id}`, n: p.nama_lengkap, ket: [p.jabatan_struktural, ...(p.jabatan_fungsional || [])].filter(Boolean).join(', ') || p.nama_unit || '' }))
})
const sasaran = computed(() => { const [s, id] = pilihan.value.split(':'); return id ? { s, id } : null })
const judulSasaran = computed(() => daftarSasaran.value.find((x) => x.v === pilihan.value)?.n || '')
const aturan = computed(() => (sasaran.value ? akses.aturan(sasaran.value.s, sasaran.value.id) : {}))
const jumlah = (v) => { const [s, id] = v.split(':'); return akses.jumlahAturan(s, id) }
const modeSemua = computed(() => sasaran.value?.s === 'semua')
const modeJabatan = computed(() => ['fungsional', 'struktural'].includes(sasaran.value?.s))

// ---------- Nilai kontrol ----------
// Semua pegawai: 0–3. Jabatan: 'ikut' (bawaan) atau 0–3. Bidang/individu: '' (ikuti), 't1'..'t3' (tambah), 'c1'..'c3' (cabut).
const PENGECUALIAN = [
  { v: '', n: 'Ikuti lapis di bawahnya' },
  { v: 't1', n: 'Tambah: lihat' }, { v: 't2', n: 'Tambah: input/ubah' }, { v: 't3', n: 'Tambah: kelola' },
  { v: 'c3', n: 'Batasi: paling tinggi input/ubah' }, { v: 'c2', n: 'Batasi: paling tinggi lihat' }, { v: 'c1', n: 'Cabut seluruh akses' },
]
const nilai = (kode) => {
  const g = aturan.value[kode]
  if (modeSemua.value) return g?.tingkat || 0
  if (modeJabatan.value) return g ? g.tingkat : 'ikut'
  return g ? (g.mode === 'cabut' ? 'c' : 't') + g.tingkat : ''
}
/** Tingkat yang berlaku bagi pemegang jabatan terpilih (aturan sendiri atau bawaan) */
const berlaku = (kode) => { const v = nilai(kode); return v === 'ikut' ? akses.bawaan(kode) : v }
const menyimpan = ref('')
async function ubah(kode, v) {
  const { s, id } = sasaran.value
  menyimpan.value = kode
  try {
    if (s === 'semua') await akses.atur(s, id, kode, Number(v) || null, 'tambah')
    else if (s === 'fungsional' || s === 'struktural') await akses.atur(s, id, kode, v === 'ikut' ? null : Number(v), 'tambah')
    else await akses.atur(s, id, kode, v ? Number(v.slice(1)) : '', v.startsWith('c') ? 'cabut' : 'tambah')
    if (s === 'individu') await muatEfektif()
  } catch (e) { ui.toast(e.message, 'galat') } finally { menyimpan.value = '' }
}

// ---------- Akses efektif (individu) ----------
async function muatEfektif() { if (sasaran.value?.s === 'individu') { try { efektif.value = await akses.rincian(sasaran.value.id) } catch (e) { ui.toast(e.message, 'galat') } } }
watch(pilihan, muatEfektif)
const lapis = (n) => (n == null ? '–' : n < 0 ? `cabut ${TINGKAT[-n].toLowerCase()}` : TINGKAT[n])
// Arti tingkat yang sedang berlaku untuk sasaran terpilih
function artiPilihan(f) {
  const v = nilai(f.kode)
  if (modeSemua.value || modeJabatan.value) {
    const t = berlaku(f.kode); if (!t) return v === 0 ? 'Tidak ada akses untuk jabatan ini' : ''
    return `${v === 'ikut' ? 'Bawaan · ' : ''}${TINGKAT[t]}: ${f.arti?.[t] || ''}`
  }
  if (v === '') return ''
  const t = Number(v.slice(1))
  return v.startsWith('t') ? `Tambah ${TINGKAT[t].toLowerCase()}: ${f.arti?.[t] || ''}` : t === 1 ? 'Seluruh akses fitur ini dicabut' : `Dibatasi paling tinggi ${TINGKAT[t - 1].toLowerCase()}`
}
const WARNA_TINGKAT = ['w-hakakses', 'w-pegawai', 'w-presensi', 'w-pengaturan']
const pilihanJabatan = (kode) => [{ v: 'ikut', n: `Bawaan (${TINGKAT[akses.bawaan(kode)]})` }, ...[0, 1, 2, 3].map((t) => ({ v: t, n: TINGKAT[t] }))]
</script>
<template>
  <div>
    <nav class="bilah-tab -mx-4 mb-4 px-4 lg:mx-0 lg:px-0" role="tablist" aria-label="Lapis hak akses">
      <button v-for="t in TAB" :key="t.k" role="tab" :aria-selected="aktif.k === t.k" @click="router.replace(`/hak-akses/${t.k}`)"
        :class="['tab-garis', 'w-' + t.w, aktif.k === t.k && 'aktif']">
        <component :is="t.ikon" :size="20" weight="duotone" /><span>{{ t.n }}</span>
      </button>
    </nav>
    <p class="mb-4 flex gap-2 text-sm text-teks3"><PhInfo :size="18" class="mt-0.5 shrink-0" />{{ aktif.ket }} Semua aturan diperiksa di server, bukan sekadar menyembunyikan menu. Tugas yang ditetapkan (wali kelas, musyrif, muhaffizh, pembina, guru mapel, petugas, pimpinan atas anggota unitnya) tetap berlaku otomatis.</p>

    <TabAksesSensitif v-if="aktif.k === 'sensitif'" />
    <TabRekapAdmin v-else-if="aktif.k === 'admin'" />
    <TabRekapJabatan v-else-if="aktif.k === 'rekap'" />
    <p v-else-if="!siap" class="py-10 text-center text-teks3">Memuat hak akses…</p>
    <div v-else :class="['lg:grid lg:grid-cols-[300px_1fr] lg:gap-5', 'w-' + aktif.w]">
      <!-- Daftar sasaran -->
      <aside class="kartu mb-4 p-3 lg:sticky lg:top-[96px] lg:mb-0 lg:max-h-[calc(100dvh-120px)] lg:overflow-y-auto">
        <input v-if="aktif.k === 'individu'" v-model="cari" type="search" class="isian mb-2" placeholder="Cari nama pegawai" aria-label="Cari pegawai" />
        <select v-model="pilihan" class="isian lg:hidden" :aria-label="'Pilih ' + aktif.n.toLowerCase()">
          <option value="">Pilih {{ aktif.k === 'jabatan' ? 'jabatan' : aktif.k === 'bidang' ? 'bidang/unit' : 'pegawai' }}</option>
          <option v-for="x in daftarSasaran" :key="x.v" :value="x.v">{{ '\u2003'.repeat(x.tingkat || 0) }}{{ x.n }}</option>
        </select>
        <ul class="hidden space-y-0.5 lg:block">
          <li v-for="x in daftarSasaran" :key="x.v">
            <button @click="pilihan = x.v" :class="['flex w-full items-center gap-2 rounded-lg px-2.5 py-2 text-left text-sm', pilihan === x.v ? 'pilih font-bold text-teks' : 'text-teks2 hover:bg-permukaan2']" :style="{ paddingLeft: 10 + (x.tingkat || 0) * 14 + 'px' }">
              <span class="min-w-0 flex-1"><span :class="['block truncate', x.semua && 'font-bold text-teks']">{{ x.n }}</span><span class="block truncate text-xs font-normal text-teks3">{{ x.ket }}</span></span>
              <span v-if="jumlah(x.v)" class="rounded-full bg-permukaan2 px-1.5 text-xs font-bold tabular-nums" :title="`${jumlah(x.v)} aturan`">{{ jumlah(x.v) }}</span>
            </button>
          </li>
        </ul>
      </aside>

      <!-- Aturan fitur -->
      <section>
        <div v-if="!sasaran" class="kartu flex flex-col items-center p-10 text-center"><span class="chip-ikon h-14 w-14 rounded-2xl"><component :is="aktif.ikon" :size="30" weight="duotone" /></span>
          <p class="mt-3 font-semibold">Pilih {{ aktif.k === 'jabatan' ? 'jabatan' : aktif.k === 'bidang' ? 'bidang atau unit' : 'pegawai' }} untuk mengatur aksesnya</p></div>
        <template v-else>
          <h2 class="mb-1 text-lg font-bold">{{ judulSasaran }}</h2>
          <p v-if="modeSemua" class="mb-3 flex gap-2 text-sm text-teks3"><PhUsersThree :size="18" class="mt-0.5 shrink-0" />Hak bawaan untuk setiap pegawai. Jabatan yang tidak diberi tingkat sendiri mengikuti bawaan ini; pilih jabatan di samping untuk memberi tingkat lain, termasuk Tidak ada.</p>
          <p v-else-if="modeJabatan" class="mb-3 text-sm text-teks3">Pilih <b class="font-semibold text-teks2">Bawaan</b> agar mengikuti baris Semua pegawai. Pegawai yang merangkap jabatan mendapat tingkat tertinggi dari jabatan-jabatannya.</p>
          <div v-else class="mb-3" />
          <div class="space-y-4">
            <div v-for="[kel, fitur] in akses.kelompok" :key="kel" class="kartu p-4">
              <h3 class="mb-2 text-sm font-bold text-teks3">{{ kel }}</h3>
              <ul class="divide-y divide-garis">
                <li v-for="f in fitur" :key="f.kode" class="flex flex-wrap items-center gap-2 py-2.5">
                  <div class="min-w-[160px] flex-1"><p class="flex items-center gap-1.5 font-semibold"><PhLock v-if="f.kunci" :size="16" weight="duotone" class="text-teks3" aria-label="Terkunci" />{{ f.nama }}</p>
                    <p v-if="f.menu" class="text-xs text-teks3">Menu: {{ f.menu }}</p>
                    <p v-if="f.kunci" class="mt-0.5 text-xs text-teks2">{{ f.kunci }}</p>
                    <template v-else>
                      <p v-if="artiPilihan(f)" class="mt-0.5 text-xs font-semibold" style="color: var(--c)">{{ artiPilihan(f) }}</p>
                      <p v-if="f.keterangan" class="mt-0.5 text-xs text-teks3">{{ f.keterangan }}</p>
                    </template></div>
                  <button v-if="f.sensitif" class="tombol-garis min-h-[40px] px-3 text-sm" @click="router.replace('/hak-akses/sensitif')">Atur di Fitur sensitif <PhArrowRight :size="16" /></button>
                  <span v-else-if="f.kunci" class="lencana w-hakakses">Khusus {{ ['beranda', 'notifikasi', 'profil'].includes(f.kode) ? 'setiap akun' : 'superadmin' }}</span>
                  <div v-else-if="modeSemua" class="flex flex-wrap rounded-full bg-permukaan2 p-1" role="radiogroup" :aria-label="`Bawaan ${f.nama}`">
                    <button v-for="t in [0, 1, 2, 3]" :key="t" :title="t ? f.arti?.[t] : 'Tanpa akses bawaan'" role="radio" :aria-checked="nilai(f.kode) === t" :disabled="menyimpan === f.kode" @click="ubah(f.kode, t)"
                      :class="['min-h-[36px] rounded-full px-3 text-xs font-semibold', nilai(f.kode) === t ? (t ? 'bg-[#C7332F] text-white' : 'bg-permukaan text-teks shadow-kartu') : 'text-teks2']">{{ TINGKAT[t] }}</button>
                  </div>
                  <div v-else-if="modeJabatan" class="flex flex-wrap rounded-2xl bg-permukaan2 p-1 sm:rounded-full" role="radiogroup" :aria-label="`Tingkat akses ${f.nama}`">
                    <button v-for="o in pilihanJabatan(f.kode)" :key="o.v" :title="o.v === 'ikut' ? 'Mengikuti bawaan Semua pegawai' : o.v ? f.arti?.[o.v] : 'Tidak ada akses (menimpa bawaan)'" role="radio" :aria-checked="nilai(f.kode) === o.v" :disabled="menyimpan === f.kode" @click="ubah(f.kode, o.v)"
                      :class="['min-h-[36px] rounded-full px-3 text-xs font-semibold', nilai(f.kode) === o.v ? (o.v === 'ikut' ? 'bg-permukaan text-teks shadow-kartu ring-1 ring-garis' : o.v ? 'bg-[#C7332F] text-white' : 'bg-[#5B4A4D] text-white') : 'text-teks2']">{{ o.n }}</button>
                  </div>
                  <select v-else class="isian w-full text-sm sm:w-64" :value="nilai(f.kode)" :disabled="menyimpan === f.kode" @change="ubah(f.kode, $event.target.value)" :aria-label="`Pengecualian ${f.nama}`">
                    <option v-for="o in PENGECUALIAN" :key="o.v" :value="o.v">{{ o.n }}</option>
                  </select>
                </li>
              </ul>
            </div>
          </div>

          <!-- Fitur lama yang tidak diatur di sini -->
          <details v-if="akses.fiturLama.length" class="kartu mt-4 p-4">
            <summary class="flex cursor-pointer items-center gap-2 text-sm font-bold text-teks2"><PhCaretDown :size="16" /> {{ akses.fiturLama.length }} fitur lama tidak diatur di sini</summary>
            <ul class="mt-2 divide-y divide-garis text-sm">
              <li v-for="f in akses.fiturLama" :key="f.kode" class="py-2"><b>{{ f.nama }}</b><span class="block text-xs text-teks3">{{ f.keterangan }}</span></li>
            </ul>
          </details>

          <!-- Akses efektif individu -->
          <div v-if="aktif.k === 'individu' && efektif.length" class="kartu w-laporan mt-4 p-4">
            <div class="mb-2 flex items-center gap-2"><span class="chip-ikon h-9 w-9"><PhListChecks :size="20" weight="duotone" /></span><h3 class="judul-bagian">Akses efektif</h3></div>
            <p class="mb-3 text-sm text-teks3">Gabungan semua lapis untuk {{ judulSasaran }}.</p>
            <div class="overflow-x-auto">
              <table class="w-full min-w-[520px] text-left text-sm">
                <thead class="border-b border-garis text-teks3"><tr><th class="py-2 pr-2 font-bold">Fitur</th><th class="px-2 font-bold">Jabatan + bawaan</th><th class="px-2 font-bold">Bidang</th><th class="px-2 font-bold">Individu</th><th class="px-2 font-bold">Efektif</th></tr></thead>
                <tbody class="divide-y divide-garis">
                  <tr v-for="r in efektif.filter((x) => akses.fiturAtur.some((f) => f.kode === x.kode))" :key="r.kode">
                    <td class="py-2 pr-2 font-semibold">{{ r.nama }}</td><td class="px-2 text-teks2">{{ lapis(r.dari_jabatan || null) }}</td>
                    <td class="px-2 text-teks2">{{ lapis(r.dari_bidang) }}</td><td class="px-2 text-teks2">{{ lapis(r.dari_individu) }}</td>
                    <td class="px-2"><span :class="['lencana', WARNA_TINGKAT[r.efektif]]">{{ TINGKAT[r.efektif] }}</span></td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </template>
      </section>
    </div>
  </div>
</template>
<style scoped>
.pilih { background: color-mix(in srgb, var(--c) 13%, rgb(var(--permukaan))); }
</style>
