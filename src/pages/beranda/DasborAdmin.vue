<!-- SIMKA PRO | src/pages/beranda/DasborAdmin.vue | v1.11 | Fase 8 – Perbaikan: Untuk Anda tetap di atas, di luar slider | 10/10/2026 -->
<script setup>
import { ref, computed, onMounted } from 'vue'
import {
  PhUsersThree, PhHourglass, PhUserCircleDashed, PhGenderMale, PhGenderFemale, PhPulse,
  PhUserCheck, PhPrinter, PhLightning, PhCaretRight, PhSealCheck, PhChartBar,
  PhFileText, PhCalendarCheck, PhFolderOpen,
} from '@phosphor-icons/vue'
import { useStatistik } from '@/stores/statistik'
import { usePegawai } from '@/stores/pegawai'
import { formatPendek } from '@/lib/tanggal'
import Sapaan from './Sapaan.vue'
import TombolPantauan from '@/components/TombolPantauan.vue'
import { PhSparkle } from '@phosphor-icons/vue'
import SliderStatistik from '@/components/SliderStatistik.vue'
import { panelBeranda } from '@/lib/panelBeranda'
import RingkasanPribadi from './RingkasanPribadi.vue'
import RingkasanPimpinan from './RingkasanPimpinan.vue'
import RingkasanKelola from './RingkasanKelola.vue'
import { useBeranda } from '@/stores/beranda'
import IndikatorLangsung from './IndikatorLangsung.vue'
import StatistikPresensi from './StatistikPresensi.vue'
import SebaranBidang from './SebaranBidang.vue'
import AksiCepat from './AksiCepat.vue'
import KartuStatistik from '@/components/KartuStatistik.vue'
import KartuSantriBeranda from '@/components/KartuSantriBeranda.vue'
import KartuTahfizhBeranda from '@/components/KartuTahfizhBeranda.vue'
import KartuLayananBeranda from '@/components/KartuLayananBeranda.vue'
import KartuSecurityBeranda from '@/components/KartuSecurityBeranda.vue'
import TombolAksi from '@/components/TombolAksi.vue'
import LembarBawah from '@/components/LembarBawah.vue'

const PANEL = panelBeranda(['presensi', 'kelola', 'pimpinan', 'santri', 'tahfizh', 'layanan', 'security', 'kendali'])
const stat = useStatistik(); const br = useBeranda(); const peg = usePegawai()
const d = computed(() => stat.data || {}); const ch = computed(() => stat.berubah)
const menunggu = computed(() => peg.daftar.filter((p) => p.status_akun === 'menunggu'))
const lembar = ref(false)
onMounted(() => { if (!peg.daftar.length) peg.muat() })
const AKSI = [
  { label: 'Verval jurnal', ket: 'Kegiatan jurnal yang ditulis pegawai', ikon: PhSealCheck, warna: 'verval', ke: '/jurnal/verval' },
  { label: 'Semua pengajuan', ket: 'Izin, sakit, cuti, dinas luar', ikon: PhFileText, warna: 'pengajuan', ke: '/pengajuan?tab=semua' },
  { label: 'Agenda dan pengingat', ket: 'Kalender pondok dan undangan', ikon: PhCalendarCheck, warna: 'agenda', ke: '/agenda' },
  { label: 'Kirim berkas pegawai', ket: 'Info, formulir, surat, SK', ikon: PhFolderOpen, warna: 'berkas', ke: '/berkas' },
  { label: 'Verval presensi', ket: 'Presensi luar area, izin sesi, kecurigaan', ikon: PhSealCheck, warna: 'verval', ke: '/verval-presensi' },
  { label: 'Rekap presensi', ket: 'Harian dan bulanan, cetak F4 dan Excel', ikon: PhChartBar, warna: 'rekap', ke: '/rekap' },
  { label: 'Verifikasi akun', ket: 'Periksa pendaftaran pegawai baru', ikon: PhUserCheck, warna: 'verifikasi', ke: '/verifikasi' },
  { label: 'Data pegawai', ket: 'Lihat, cari, dan cetak data', ikon: PhUsersThree, warna: 'pegawai', ke: '/pegawai' },
  { label: 'Cetak daftar pegawai', ket: 'Dokumen F4 dengan kop pondok', ikon: PhPrinter, warna: 'laporan', ke: '/pegawai' },
]
</script>
<template>
  <div class="space-y-5 lg:space-y-6">
    <Sapaan :keterangan="d.menunggu_verifikasi ? `Ada ${d.menunggu_verifikasi} pendaftaran pegawai yang menunggu verifikasi Anda.` : 'Tidak ada pendaftaran yang menunggu verifikasi.'" />
    <TombolPantauan />

    <!-- Untuk Anda: tetap tersusun di atas (akses cepat), tidak masuk slider -->
    <section v-if="br.data?.pribadi" class="space-y-3" aria-labelledby="judul-untuk-anda">
      <h2 id="judul-untuk-anda" class="judul-bagian flex items-center gap-2 px-1"><PhSparkle :size="20" weight="duotone" class="text-[rgb(var(--merah))]" /> Untuk Anda</h2>
      <RingkasanPribadi :d="br.data.pribadi" />
    </section>

    <SliderStatistik :panel="PANEL" simpan="simka.beranda.admin">
      <template #presensi><StatistikPresensi /></template>
      <template #kelola>
        <template v-if="br.data?.kelola">
          <div class="flex flex-wrap items-center justify-between gap-2"><h2 class="judul-bagian">Administrasi pegawai</h2><IndikatorLangsung :waktu="br.diperbarui" /></div>
          <RingkasanKelola :d="br.data.kelola" />
        </template>
      </template>
      <template #pimpinan>
        <template v-if="br.data?.pimpinan"><h2 class="judul-bagian">Unit yang Anda pimpin</h2><RingkasanPimpinan :d="br.data.pimpinan" /></template>
      </template>
      <template #santri><KartuSantriBeranda /></template>
      <template #tahfizh><KartuTahfizhBeranda /></template>
      <template #layanan><KartuLayananBeranda /></template>
      <template #security><KartuSecurityBeranda /></template>
      <template #kendali>
    <div class="flex flex-wrap items-center justify-between gap-2">
      <h2 class="judul-bagian">Kendali data pegawai</h2>
      <IndikatorLangsung :waktu="stat.diperbarui" />
    </div>
    <div class="grid grid-cols-2 gap-3 sm:gap-4 lg:grid-cols-3">
      <KartuStatistik judul="Menunggu verifikasi" :nilai="d.menunggu_verifikasi" :ikon="PhHourglass" warna="verifikasi" ke="/verifikasi" keterangan="Ketuk untuk memeriksa" :perubahan="ch.menunggu_verifikasi" />
      <KartuStatistik judul="Pegawai aktif" :nilai="d.pegawai_aktif" :ikon="PhUsersThree" warna="pegawai" ke="/pegawai" :keterangan="`${d.akun_aktif ?? 0} sudah memiliki akun`" :perubahan="ch.pegawai_aktif" />
      <KartuStatistik judul="Belum punya akun" :nilai="d.tanpa_akun" :ikon="PhUserCircleDashed" warna="tahfizh" ke="/pegawai" keterangan="Ajak mendaftar mandiri" :perubahan="ch.tanpa_akun" />
      <KartuStatistik judul="Pegawai laki-laki" :nilai="d.laki_laki" :ikon="PhGenderMale" warna="santri" :perubahan="ch.laki_laki" />
      <KartuStatistik judul="Pegawai perempuan" :nilai="d.perempuan" :ikon="PhGenderFemale" warna="klinik" :perubahan="ch.perempuan" />
      <KartuStatistik judul="Aktivitas hari ini" :nilai="d.audit_hari_ini" :ikon="PhPulse" warna="pengajuan" keterangan="Tercatat di audit log" :perubahan="ch.audit_hari_ini" />
    </div>

    <div class="grid gap-4 lg:grid-cols-2 lg:gap-6">
      <section class="kartu w-verifikasi p-5">
        <div class="mb-3 flex items-center justify-between">
          <h3 class="judul-bagian">Antrian verifikasi</h3>
          <router-link to="/verifikasi" class="tombol-teks h-9 min-h-0 text-sm">Lihat semua</router-link>
        </div>
        <ul v-if="menunggu.length" class="divide-y divide-garis">
          <li v-for="p in menunggu" :key="p.id">
            <router-link to="/verifikasi/menunggu" class="flex min-h-[56px] items-center gap-3 py-2">
              <span class="chip-ikon h-10 w-10"><PhHourglass :size="20" weight="duotone" /></span>
              <span class="min-w-0 flex-1">
                <span class="block truncate font-semibold">{{ p.nama_lengkap }}</span>
                <span class="block truncate text-sm text-teks3">{{ p.nama_unit }} – TMT {{ formatPendek(p.tmt_tugas) }}</span>
              </span>
              <PhCaretRight :size="18" class="text-teks3" />
            </router-link>
          </li>
        </ul>
        <p v-else class="py-6 text-center text-sm text-teks3">Semua pendaftaran sudah diperiksa.</p>
      </section>
      <section class="kartu p-5">
        <h3 class="judul-bagian">Sebaran pegawai per bidang</h3>
        <p class="mb-4 text-sm text-teks3">Pegawai aktif, termasuk unit di bawah bidang</p>
        <SebaranBidang :data="d.per_bidang" />
      </section>
    </div>

      </template>
    </SliderStatistik>

    <TombolAksi label="Aksi cepat" :ikon="PhLightning" @klik="lembar = true" />
    <LembarBawah v-model="lembar" judul="Aksi cepat"><AksiCepat :daftar="AKSI" @pilih="lembar = false" /></LembarBawah>
  </div>
</template>
