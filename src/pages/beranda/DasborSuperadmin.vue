<!-- SIMKA PRO | src/pages/beranda/DasborSuperadmin.vue | v1.5 | Fase 6 – Tahap 5 Penutup fase klinik dan lapor | 06/10/2026 -->
<script setup>
import { ref, computed } from 'vue'
import {
  PhUsersThree, PhUserCheck, PhHourglass, PhUserCircleDashed, PhKey, PhTreeStructure, PhCloudArrowUp,
  PhPulse, PhGearSix, PhPrinter, PhLightning, PhHeartbeat, PhWarningCircle, PhCheckCircle, PhChartBar, PhMapPinArea,
  PhFileText, PhCalendarCheck, PhFolderOpen, PhSealCheck,
} from '@phosphor-icons/vue'
import { useStatistik } from '@/stores/statistik'
import { formatRelatif, formatWaktu } from '@/lib/tanggal'
import Sapaan from './Sapaan.vue'
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
import TombolAksi from '@/components/TombolAksi.vue'
import LembarBawah from '@/components/LembarBawah.vue'

const stat = useStatistik(); const br = useBeranda()
const d = computed(() => stat.data || {})
const ch = computed(() => stat.berubah)
const lembar = ref(false)

const STATUS = [
  { k: 'tetap', label: 'Tetap', w: 'presensi' }, { k: 'kontrak', label: 'Kontrak', w: 'pegawai' },
  { k: 'honorer', label: 'Honorer', w: 'tahfizh' }, { k: 'belum_diisi', label: 'Belum diisi', w: 'hakakses' },
]
const totalStatus = computed(() => Object.values(d.value.per_status || {}).reduce((a, b) => a + b, 0) || 1)
const jamHeartbeat = computed(() => d.value.heartbeat_terakhir ? (Date.now() - new Date(d.value.heartbeat_terakhir)) / 3600000 : null)
const layananSehat = computed(() => jamHeartbeat.value !== null && jamHeartbeat.value < 30 && !d.value.berkas_gagal)

const AKSI = [
  { label: 'Verval jurnal', ket: 'Kegiatan jurnal yang ditulis pegawai', ikon: PhSealCheck, warna: 'verval', ke: '/jurnal/verval' },
  { label: 'Semua pengajuan', ket: 'Izin, sakit, cuti, dinas luar', ikon: PhFileText, warna: 'pengajuan', ke: '/pengajuan?tab=semua' },
  { label: 'Agenda dan pengingat', ket: 'Kalender pondok dan undangan', ikon: PhCalendarCheck, warna: 'agenda', ke: '/agenda' },
  { label: 'Kirim berkas pegawai', ket: 'Info, formulir, surat, SK', ikon: PhFolderOpen, warna: 'berkas', ke: '/berkas' },
  { label: 'Rekap presensi', ket: 'Harian dan bulanan, cetak F4 dan Excel', ikon: PhChartBar, warna: 'rekap', ke: '/rekap-presensi' },
  { label: 'Pengaturan presensi', ket: 'Titik GPS, pola sesi, jadwal', ikon: PhMapPinArea, warna: 'aturpresensi', ke: '/atur-presensi' },
  { label: 'Pengaturan lembaga', ket: 'Identitas, kalender, kop, penanda tangan', ikon: PhGearSix, warna: 'pengaturan', ke: '/pengaturan' },
  { label: 'Hak akses fitur', ket: 'Per jabatan, bidang, dan individu', ikon: PhKey, warna: 'hakakses', ke: '/hak-akses' },
  { label: 'Struktur organisasi', ket: 'Bidang, unit, dan jabatan', ikon: PhTreeStructure, warna: 'sistem', ke: '/organisasi' },
  { label: 'Cetak daftar pegawai', ket: 'Dokumen F4 dengan kop pondok', ikon: PhPrinter, warna: 'laporan', ke: '/pegawai' },
]
</script>
<template>
  <div class="space-y-5 lg:space-y-6">
    <Sapaan keterangan="Anda memegang kendali penuh atas data dan pengaturan sistem SIMKA PRO." />

    <StatistikPresensi />

    <template v-if="br.data?.kelola">
      <div class="flex flex-wrap items-center justify-between gap-2"><h2 class="judul-bagian">Administrasi pegawai</h2><IndikatorLangsung :waktu="br.diperbarui" /></div>
      <RingkasanKelola :d="br.data.kelola" />
    </template>
    <template v-if="br.data?.pimpinan">
      <h2 class="judul-bagian">Unit yang Anda pimpin</h2>
      <RingkasanPimpinan :d="br.data.pimpinan" />
    </template>
    <template v-if="br.data?.pribadi">
      <h2 class="judul-bagian">Untuk Anda</h2>
      <RingkasanPribadi :d="br.data.pribadi" />
    </template>

    <KartuSantriBeranda />

    <KartuTahfizhBeranda />
    <KartuLayananBeranda />

    <div class="flex flex-wrap items-center justify-between gap-2">
      <h2 class="judul-bagian">Ringkasan pondok</h2>
      <IndikatorLangsung :waktu="stat.diperbarui" />
    </div>
    <div class="grid grid-cols-2 gap-3 sm:gap-4 xl:grid-cols-4">
      <KartuStatistik judul="Pegawai aktif" :nilai="d.pegawai_aktif" :ikon="PhUsersThree" warna="pegawai" ke="/pegawai"
        :keterangan="`${d.laki_laki ?? 0} laki-laki, ${d.perempuan ?? 0} perempuan`" :perubahan="ch.pegawai_aktif" />
      <KartuStatistik judul="Akun aktif" :nilai="d.akun_aktif" :ikon="PhUserCheck" warna="presensi" keterangan="Sudah dapat masuk aplikasi" :perubahan="ch.akun_aktif" />
      <KartuStatistik judul="Menunggu verifikasi" :nilai="d.menunggu_verifikasi" :ikon="PhHourglass" warna="verifikasi" ke="/verifikasi" keterangan="Pendaftaran mandiri" :perubahan="ch.menunggu_verifikasi" />
      <KartuStatistik judul="Belum punya akun" :nilai="d.tanpa_akun" :ikon="PhUserCircleDashed" warna="tahfizh" ke="/pegawai" keterangan="Data dari impor Excel" :perubahan="ch.tanpa_akun" />
      <KartuStatistik judul="Admin aktif" :nilai="d.admin" :ikon="PhKey" warna="hakakses" ke="/hak-akses" keterangan="Izin diatur superadmin" :perubahan="ch.admin" />
      <KartuStatistik judul="Bidang aktif" :nilai="d.bidang_aktif" :ikon="PhTreeStructure" warna="santri" ke="/organisasi" keterangan="Termasuk unit di bawahnya" :perubahan="ch.bidang_aktif" />
      <KartuStatistik judul="Antrian berkas Drive" :nilai="d.berkas_antri" :ikon="PhCloudArrowUp" warna="laporan" keterangan="Dipindah GAS tiap 5 menit" :perubahan="ch.berkas_antri" />
      <KartuStatistik judul="Aktivitas hari ini" :nilai="d.audit_hari_ini" :ikon="PhPulse" warna="pengajuan" keterangan="Tercatat di audit log" :perubahan="ch.audit_hari_ini" />
    </div>

    <div class="grid gap-4 lg:grid-cols-3 lg:gap-6">
      <section class="kartu p-5 lg:col-span-2">
        <h3 class="judul-bagian">Sebaran pegawai per bidang</h3>
        <p class="mb-4 text-sm text-teks3">Pegawai aktif, termasuk unit di bawah bidang</p>
        <SebaranBidang :data="d.per_bidang" />
      </section>
      <div class="space-y-4 lg:space-y-6">
        <section class="kartu p-5">
          <h3 class="judul-bagian">Status kepegawaian</h3>
          <div class="mt-3 flex h-3 overflow-hidden rounded-full bg-permukaan2" role="img" aria-label="Komposisi status kepegawaian">
            <template v-for="s in STATUS" :key="s.k">
              <div v-if="d.per_status?.[s.k]" :class="'w-' + s.w" :style="{ width: (d.per_status[s.k] / totalStatus) * 100 + '%', background: 'var(--c)' }" />
            </template>
          </div>
          <ul class="mt-3 grid grid-cols-2 gap-2 text-sm">
            <template v-for="s in STATUS" :key="s.k">
              <li v-if="d.per_status?.[s.k]" :class="['flex items-center gap-2', 'w-' + s.w]">
                <span class="h-2.5 w-2.5 rounded-full" style="background: var(--c)" />
                <span class="text-teks2">{{ s.label }}</span><span class="ml-auto font-bold tabular-nums">{{ d.per_status[s.k] }}</span>
              </li>
            </template>
          </ul>
        </section>
        <section :class="['kartu p-5', layananSehat ? 'w-presensi' : 'w-klinik']">
          <div class="flex items-center gap-3">
            <span class="chip-ikon h-11 w-11"><component :is="layananSehat ? PhHeartbeat : PhWarningCircle" :size="24" weight="duotone" /></span>
            <div>
              <h3 class="judul-bagian">Kesehatan layanan</h3>
              <p class="text-sm font-semibold" style="color: var(--c)">{{ layananSehat ? 'Semua layanan aktif' : 'Perlu diperiksa' }}</p>
            </div>
          </div>
          <dl class="mt-3 space-y-1.5 text-sm">
            <div class="flex justify-between gap-2"><dt class="text-teks2">Heartbeat terakhir</dt>
              <dd class="font-semibold" :title="d.heartbeat_terakhir ? formatWaktu(d.heartbeat_terakhir) : ''">{{ d.heartbeat_terakhir ? formatRelatif(d.heartbeat_terakhir) : 'Belum ada' }}</dd></div>
            <div class="flex justify-between gap-2"><dt class="text-teks2">Berkas gagal dipindah</dt><dd class="font-semibold tabular-nums">{{ d.berkas_gagal ?? 0 }}</dd></div>
          </dl>
        </section>
      </div>
    </div>

    <section class="hidden lg:block">
      <h2 class="judul-bagian mb-3">Akses cepat superadmin</h2>
      <AksiCepat :daftar="AKSI" kisi />
    </section>

    <TombolAksi label="Aksi cepat" :ikon="PhLightning" @klik="lembar = true" />
    <LembarBawah v-model="lembar" judul="Aksi cepat"><AksiCepat :daftar="AKSI" @pilih="lembar = false" /></LembarBawah>
  </div>
</template>
