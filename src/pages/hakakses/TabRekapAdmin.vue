<!-- SIMKA PRO | src/pages/hakakses/TabRekapAdmin.vue | v1.1 | Perbaikan 13.9.0: izin Kelola pengumuman masuk kelompok administrasi | 16/10/2026 -->
<script setup>
// Rekap akses admin (khusus superadmin): baris = uraian akses, kolom = setiap admin, sel = centang bila admin memiliki akses itu.
// Desktop: matriks lengkap. HP: kartu per admin. Cetak F4 mendatar berkop dengan kolom tanda tangan.
// Akses admin diubah di menu Akun Pegawai → kelola akun → Peran dan izin admin (tombol "Ubah akses").
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { PhUserGear, PhListChecks, PhChartBar, PhShieldWarning, PhCheckCircle, PhMinus, PhPrinter, PhMagnifyingGlass, PhPencilSimple, PhCaretDown } from '@phosphor-icons/vue'
import { useAkun } from '@/stores/akun'
import { usePegawai } from '@/stores/pegawai'
import { useLembaga } from '@/stores/lembaga'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { inisial } from '@/lib/santri'
import KartuStatistik from '@/components/KartuStatistik.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const akun = useAkun(); const peg = usePegawai(); const lembaga = useLembaga(); const sesi = useSesi(); const ui = useUI(); const router = useRouter()
const siap = ref(false)
onMounted(async () => {
  try { await Promise.all([peg.daftar.length ? null : peg.muat(), lembaga.muat()]); await akun.muatIzin() } catch (e) { ui.toast(e.message, 'galat') }
  siap.value = true
})

// Pengelompokan uraian akses agar mudah dibaca
const KELOMPOK = [
  ['Kepegawaian', ['verval_akun', 'kelola_pegawai', 'cetak_kartu', 'kelola_kelompok', 'kelola_berkas', 'atur_beban_kerja']],
  ['Presensi, jadwal, dan jurnal', ['kalender', 'verval_presensi', 'atur_presensi', 'atur_jurnal', 'verval_jurnal', 'atur_jadwal']],
  ['Pengajuan dan administrasi', ['atur_pengajuan', 'lihat_pengajuan', 'kelola_pengumuman', 'kelola_agenda', 'kelola_persuratan', 'kelola_lapor']],
  ['Santri', ['kelola_santri', 'kelompok_santri', 'absensi_atas_nama', 'kelola_izin_santri', 'kelola_libur']],
  ['Tahfizh dan penilaian', ['atur_tahfizh', 'validasi_tahfizh', 'atur_penilaian', 'kelola_nilai']],
  ['Layanan', ['kelola_klinik', 'kelola_security']],
]
const tanpaFase = (t) => (t || '').replace(/\s*\((?:Fase|fase)[^)]*\)/g, '')
const grupAkses = computed(() => {
  const terpakai = new Set(); const hasil = []
  for (const [n, kode] of KELOMPOK) {
    const isi = kode.map((k) => akun.izinTersedia.find((z) => z.kode === k)).filter(Boolean)
    isi.forEach((z) => terpakai.add(z.kode)); if (isi.length) hasil.push({ n, isi })
  }
  const lain = akun.izinTersedia.filter((z) => !terpakai.has(z.kode))
  if (lain.length) hasil.push({ n: 'Lainnya', isi: lain })
  let no = 0
  return hasil.map((g) => ({ ...g, isi: g.isi.map((z) => ({ ...z, nama: tanpaFase(z.nama), no: ++no })) }))
})
const semuaAkses = computed(() => grupAkses.value.flatMap((g) => g.isi))

// Daftar admin (aktif lebih dulu, lalu nama)
const cari = ref('')
const admin = computed(() => peg.daftar.filter((p) => p.peran === 'admin')
  .sort((a, b) => (a.status_akun === 'aktif' ? 0 : 1) - (b.status_akun === 'aktif' ? 0 : 1) || a.nama_lengkap.localeCompare(b.nama_lengkap, 'id')))
const tampilAdmin = computed(() => { const q = cari.value.toLowerCase().trim(); return admin.value.filter((p) => !q || `${p.nama_lengkap} ${p.niy || ''}`.toLowerCase().includes(q)) })
const punya = (p, kode) => (akun.izinAdmin[p.id] || []).includes(kode)
const jumlahAdmin = (kode) => admin.value.filter((p) => punya(p, kode)).length
const jumlahAkses = (p) => semuaAkses.value.filter((z) => punya(p, z.kode)).length
const namaPendek = (n) => n.replace(/,.*$/, '').replace(/^(Ust\.|Ustzh\.|Ustadz|Ustadzah)\s+/i, '')

const statistik = computed(() => {
  const n = admin.value.length; const aktif = admin.value.filter((p) => p.status_akun === 'aktif').length
  const rata = n ? Math.round((admin.value.reduce((t, p) => t + jumlahAkses(p), 0) / n) * 10) / 10 : 0
  const kosong = semuaAkses.value.filter((z) => !jumlahAdmin(z.kode)).length
  return [
    { judul: 'Admin', nilai: n, ikon: PhUserGear, warna: 'verifikasi', ket: `${aktif} akun aktif` },
    { judul: 'Jenis akses admin', nilai: semuaAkses.value.length, ikon: PhListChecks, warna: 'hakakses', ket: 'Dapat dicentang superadmin' },
    { judul: 'Rata-rata akses', nilai: String(rata).replace('.', ','), ikon: PhChartBar, warna: 'laporan', ket: 'Akses per admin' },
    { judul: 'Belum dipegang admin', nilai: kosong, ikon: PhShieldWarning, warna: 'klinik', ket: 'Hanya dijalankan superadmin' },
  ]
})

// HP: kartu per admin dapat dibuka-tutup
const buka = ref({})
const ubahAkses = () => router.push('/verifikasi/akun')

// Cetak
const pratinjau = ref(false)
const direktur = computed(() => lembaga.signatories?.find((s) => /^direktur$/i.test(s.jabatan_tertulis)) || lembaga.signatories?.[0] || {})
const lebarAdmin = computed(() => (admin.value.length ? Math.max(5, Math.min(12, 62 / admin.value.length)) : 10))
</script>
<template>
  <div>
    <p v-if="!siap" class="py-10 text-center text-teks3">Memuat rekap akses admin…</p>
    <template v-else>
      <div class="-mx-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-4 sm:overflow-visible sm:px-0">
        <KartuStatistik v-for="k in statistik" :key="k.judul" class="w-[46%] shrink-0 snap-start sm:w-auto" :judul="k.judul" :nilai="k.nilai" :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket" />
      </div>

      <div class="mt-4 flex flex-wrap items-center gap-2">
        <div class="relative min-w-[220px] flex-1">
          <PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
          <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari nama atau NIY admin" aria-label="Cari admin" />
        </div>
        <button class="tombol-garis w-verifikasi min-h-[44px] px-4 text-sm" @click="ubahAkses"><PhPencilSimple :size="18" style="color: var(--c)" /> Ubah akses admin</button>
        <button class="tombol-utama min-h-[44px] px-4 text-sm" :disabled="!admin.length" @click="pratinjau = true"><PhPrinter :size="18" weight="duotone" /> Cetak rekap</button>
      </div>

      <p v-if="!admin.length" class="kartu mt-4 p-8 text-center text-sm text-teks3">Belum ada akun berperan admin. Peran admin diberikan di menu Akun Pegawai.</p>
      <template v-else>
        <!-- Desktop: matriks -->
        <div class="kartu mt-4 hidden overflow-x-auto lg:block">
          <table class="matriks w-full text-sm">
            <thead>
              <tr class="border-b border-garis bg-permukaan2 text-teks2">
                <th class="sticky left-0 z-10 w-10 bg-permukaan2 px-3 py-3 text-center font-bold">No.</th>
                <th class="sticky left-10 z-10 min-w-[280px] bg-permukaan2 px-3 py-3 text-left font-bold">Uraian akses admin</th>
                <th v-for="p in tampilAdmin" :key="p.id" class="min-w-[92px] px-2 py-3 text-center align-bottom font-bold" :title="p.nama_lengkap">
                  <span class="chip-ikon mx-auto mb-1 h-8 w-8 text-[11px] font-extrabold" :class="p.status_akun === 'aktif' ? 'w-verifikasi' : 'w-hakakses'">{{ inisial(p.nama_lengkap) }}</span>
                  <span class="block max-w-[110px] truncate text-xs text-teks">{{ namaPendek(p.nama_lengkap) }}</span>
                  <span class="block text-[11px] font-normal tabular-nums text-teks3">{{ p.niy || 'tanpa NIY' }}</span>
                  <span v-if="p.status_akun !== 'aktif'" class="lencana w-klinik mt-1">Nonaktif</span>
                </th>
                <th class="px-3 py-3 text-center font-bold">Jumlah admin</th>
              </tr>
            </thead>
            <tbody v-for="g in grupAkses" :key="g.n">
              <tr><td :colspan="tampilAdmin.length + 3" class="bg-permukaan2/60 px-3 py-1.5 text-xs font-bold uppercase tracking-wide text-teks3">{{ g.n }}</td></tr>
              <tr v-for="z in g.isi" :key="z.kode" class="border-t border-garis hover:bg-permukaan2/50">
                <td class="sticky left-0 bg-permukaan px-3 py-2 text-center tabular-nums text-teks3">{{ z.no }}</td>
                <td class="sticky left-10 bg-permukaan px-3 py-2 text-teks">{{ z.nama }}</td>
                <td v-for="p in tampilAdmin" :key="p.id" class="px-2 py-2 text-center">
                  <PhCheckCircle v-if="punya(p, z.kode)" :size="22" weight="fill" class="centang mx-auto" :aria-label="`${p.nama_lengkap}: ya`" />
                  <PhMinus v-else :size="16" class="mx-auto text-teks3/50" :aria-label="`${p.nama_lengkap}: tidak`" />
                </td>
                <td class="px-3 py-2 text-center tabular-nums" :class="jumlahAdmin(z.kode) ? 'font-semibold' : 'text-merah'">{{ jumlahAdmin(z.kode) || 'Belum ada' }}</td>
              </tr>
            </tbody>
            <tfoot>
              <tr class="border-t-2 border-garis bg-permukaan2 font-bold">
                <td class="sticky left-0 bg-permukaan2" /><td class="sticky left-10 bg-permukaan2 px-3 py-2.5">Jumlah akses</td>
                <td v-for="p in tampilAdmin" :key="p.id" class="px-2 py-2.5 text-center tabular-nums">{{ jumlahAkses(p) }}/{{ semuaAkses.length }}</td><td />
              </tr>
            </tfoot>
          </table>
        </div>

        <!-- HP: kartu per admin -->
        <ul class="mt-4 space-y-3 lg:hidden">
          <li v-for="p in tampilAdmin" :key="p.id" class="kartu w-verifikasi overflow-hidden">
            <button type="button" class="flex w-full items-center gap-3 p-4 text-left" :aria-expanded="!!buka[p.id]" @click="buka[p.id] = !buka[p.id]">
              <span class="chip-ikon h-11 w-11 shrink-0 text-sm font-extrabold">{{ inisial(p.nama_lengkap) }}</span>
              <span class="min-w-0 flex-1"><b class="block truncate">{{ p.nama_lengkap }}</b>
                <span class="block text-xs text-teks3">{{ p.niy || 'tanpa NIY' }}<template v-if="p.status_akun !== 'aktif'"> · nonaktif</template></span>
                <span class="mt-1.5 block h-1.5 overflow-hidden rounded-full bg-permukaan2"><span class="block h-full rounded-full" style="background: var(--c)" :style="{ width: (jumlahAkses(p) / Math.max(1, semuaAkses.length)) * 100 + '%' }" /></span></span>
              <span class="shrink-0 text-right"><b class="block text-lg tabular-nums" style="color: var(--c)">{{ jumlahAkses(p) }}</b><span class="text-xs text-teks3">dari {{ semuaAkses.length }}</span></span>
              <PhCaretDown :size="18" :class="['shrink-0 text-teks3 transition', buka[p.id] && 'rotate-180']" />
            </button>
            <div v-if="buka[p.id]" class="border-t border-garis px-4 pb-3">
              <template v-for="g in grupAkses" :key="g.n">
                <p class="mt-3 text-xs font-bold uppercase tracking-wide text-teks3">{{ g.n }}</p>
                <ul class="mt-1 space-y-1">
                  <li v-for="z in g.isi" :key="z.kode" class="flex items-start gap-2 text-sm" :class="punya(p, z.kode) ? 'text-teks' : 'text-teks3'">
                    <PhCheckCircle v-if="punya(p, z.kode)" :size="20" weight="fill" class="centang mt-0.5 shrink-0" /><PhMinus v-else :size="20" class="mt-0.5 shrink-0 opacity-50" />
                    <span><span class="tabular-nums">{{ z.no }}.</span> {{ z.nama }}</span>
                  </li>
                </ul>
              </template>
            </div>
          </li>
        </ul>
        <p class="mt-3 text-xs text-teks3">Centang hijau = admin memiliki akses tersebut. Superadmin selalu memiliki seluruh akses dan tidak dicantumkan. Akses diubah melalui Akun Pegawai → kelola akun → Peran dan izin admin.</p>
      </template>
    </template>

    <DokumenCetak v-model:pratinjau="pratinjau" mendatar judul="Rekap Akses Admin SIMKA PRO" :subjudul="`Keadaan per ${new Date().toLocaleDateString('id-ID', { day: '2-digit', month: 'long', year: 'numeric' })}`"
      nama-berkas="Rekap-Akses-Admin-SIMKA-PRO" :pencetak="sesi.pengguna?.nama_lengkap">
      <table class="tabel">
        <colgroup><col style="width:4%"><col :style="`width:${96 - lebarAdmin * admin.length - 7}%`"><col v-for="p in admin" :key="p.id" :style="`width:${lebarAdmin}%`"><col style="width:7%"></colgroup>
        <thead><tr><th>No.</th><th>Uraian Akses Admin</th><th v-for="p in admin" :key="p.id">{{ p.nama_lengkap }}<br>NIY {{ p.niy || '–' }}</th><th>Jumlah Admin</th></tr></thead>
        <tbody>
          <template v-for="g in grupAkses" :key="g.n">
            <tr><td class="tengah" /><td :colspan="admin.length + 2"><i>{{ g.n }}</i></td></tr>
            <tr v-for="z in g.isi" :key="z.kode">
              <td class="tengah">{{ z.no }}</td><td>{{ z.nama }}</td>
              <td v-for="p in admin" :key="p.id" class="tengah">{{ punya(p, z.kode) ? '✓' : '' }}</td>
              <td class="tengah">{{ jumlahAdmin(z.kode) }}</td>
            </tr>
          </template>
          <tr><td /><td>Jumlah akses</td><td v-for="p in admin" :key="p.id" class="tengah">{{ jumlahAkses(p) }}</td><td /></tr>
        </tbody>
      </table>
      <p style="margin-top: 6pt; font-size: 9pt">Tanda ✓ = admin memiliki akses tersebut. Superadmin memiliki seluruh akses dan tidak dicantumkan.</p>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan_tertulis || 'Direktur', nama: direktur.nama || '', niy: direktur.niy }"
          :kanan="{ jabatan: 'Superadmin SIMKA PRO', nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
      </template>
    </DokumenCetak>
  </div>
</template>
<style scoped>
.centang { color: #1E7D4F; }
:global(.dark) .centang { color: #6FD19A; }
</style>
