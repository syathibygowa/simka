<!-- SIMKA PRO | src/pages/security/Security.vue | v1.2 | Fase 7 – Tahap 3 Libur santri | 06/10/2026 -->
<script setup>
// Menu Security (Blueprint Bagian 24).
//   Gerbang   : cari santri (hijau/merah), siap keluar hari ini, catatan hari ini
//   Di luar   : santri yang sedang izin di luar pondok; terlambat kembali di atas (merah)
//   Titipan   : terima (foto wajib), serahkan (nama + foto pengambil wajib), kembalikan, riwayat
//   Tamu      : buku tamu (orang yang ditemui dinotifikasi)
//   Kunjungan : kunjungan orang tua (musyrif dinotifikasi untuk memanggil santri)
//   Riwayat   : catatan gerbang per rentang tanggal, Excel, cetak F4
//   Ketentuan : toleransi terlambat, keluar lebih awal, pengingat titipan, jadwal kunjungan
// Pencatat: petugas Security. Pimpinan, yayasan, admin, dan superadmin melihat semuanya.
// Pengasuh (musyrif, wali kelas, muhaffizh) hanya melihat Titipan dan Kunjungan santri asuhannya.
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { PhDoorOpen, PhSignOut, PhClockCounterClockwise, PhListChecks, PhFloppyDisk, PhInfo, PhLock, PhPackage, PhIdentificationBadge, PhUsersThree } from '@phosphor-icons/vue'
import { useSecurity } from '@/stores/security'
import { useUI } from '@/stores/ui'
import { HARI_PENDEK } from '@/lib/security'
import BilahTab from '@/components/BilahTab.vue'
import InputJam from '@/components/InputJam.vue'
import TabGerbang from './TabGerbang.vue'
import TabRiwayatGerbang from './TabRiwayatGerbang.vue'
import TabTitipan from './TabTitipan.vue'
import TabTamu from './TabTamu.vue'
import TabKunjungan from './TabKunjungan.vue'

const props = defineProps({ tab: { type: String, default: '' } })
const router = useRouter(); const sc = useSecurity(); const ui = useUI()
onMounted(async () => { if (!sc.hakDimuat) await sc.muatHak().catch((e) => ui.toast(e.message, 'galat')); salin(); sc.muatBeranda() })
const b = computed(() => sc.beranda || {})
const TAB = computed(() => (sc.hak.lihat ? [
  { k: 'gerbang', n: 'Gerbang', ikon: PhDoorOpen, w: 'security' },
  { k: 'diluar', n: 'Di luar', ikon: PhSignOut, w: 'shift', jumlah: b.value.di_luar ?? null, lencana: b.value.terlambat || null },
  { k: 'titipan', n: 'Titipan', ikon: PhPackage, w: 'pengajuan', jumlah: b.value.titipan_di_pos ?? null, lencana: b.value.titipan_lama || null },
  { k: 'tamu', n: 'Tamu', ikon: PhIdentificationBadge, w: 'pegawai', jumlah: b.value.tamu_di_dalam ?? null },
  { k: 'kunjungan', n: 'Kunjungan', ikon: PhUsersThree, w: 'tahfizh', jumlah: b.value.kunjungan_berlangsung ?? null },
  { k: 'riwayat', n: 'Riwayat gerbang', ikon: PhClockCounterClockwise, w: 'rekap' },
  { k: 'ketentuan', n: 'Ketentuan', ikon: PhListChecks, w: 'pengaturan' },
] : [
  { k: 'titipan', n: 'Titipan santri', ikon: PhPackage, w: 'pengajuan' },
  { k: 'kunjungan', n: 'Kunjungan', ikon: PhUsersThree, w: 'tahfizh' },
]))
const boleh = computed(() => sc.hak.lihat || sc.hak.pengasuh)
const aktif = computed(() => (TAB.value.some((t) => t.k === props.tab) ? props.tab : TAB.value[0].k))
const atur = ref({}); const proses = ref(false)
function salin() { atur.value = { ...sc.pengaturan, hari_kunjungan: [...(sc.pengaturan.hari_kunjungan || [])] } }
function alihHari(h) { const a = atur.value.hari_kunjungan; atur.value.hari_kunjungan = a.includes(h) ? a.filter((x) => x !== h) : [...a, h].sort() }
async function simpan() {
  proses.value = true
  try {
    const a = atur.value
    await sc.simpanPengaturan({ toleransi_terlambat_menit: Number(a.toleransi_terlambat_menit), keluar_lebih_awal_menit: Number(a.keluar_lebih_awal_menit),
      pengingat_titipan_hari: Number(a.pengingat_titipan_hari), jadwal_kunjungan_aktif: !!a.jadwal_kunjungan_aktif, hari_kunjungan: a.hari_kunjungan,
      jam_kunjungan_mulai: (a.jam_kunjungan_mulai || '').slice(0, 5), jam_kunjungan_selesai: (a.jam_kunjungan_selesai || '').slice(0, 5) })
    salin(); ui.toast('Ketentuan Security tersimpan.')
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <div v-if="sc.hakDimuat && boleh">
    <BilahTab class="mb-4" :tab="TAB" :model-value="aktif" label="Bagian Security" @update:model-value="(k) => router.replace(`/security/${k}`)" />
    <TabRiwayatGerbang v-if="aktif === 'riwayat'" />
    <TabTitipan v-else-if="aktif === 'titipan'" />
    <TabTamu v-else-if="aktif === 'tamu'" />
    <TabKunjungan v-else-if="aktif === 'kunjungan'" />
    <section v-else-if="aktif === 'ketentuan'" class="kartu w-security p-4 sm:p-5">
      <h2 class="judul-bagian">Ketentuan Security</h2>
      <ul class="mt-2 list-disc space-y-1 pl-5 text-sm text-teks2">
        <li>Pencatat gerbang, titipan, tamu, dan kunjungan adalah petugas Security (jabatan Petugas keamanan). Superadmin dan admin ber-izin kelola Security menjadi cadangan.</li>
        <li>Hijau: izin disetujui dan berlaku. Merah: tidak ada izin, belum disetujui, belum waktunya, atau kedaluwarsa. Santri tanpa izin dicatat "ditolak di gerbang".</li>
        <li>Terlambat kembali: Kepala Bidang Kesantrian, pengusul, musyrif, wali kelas, dan muhaffizh menerima notifikasi sekali.</li>
        <li>Titipan wajib difoto saat diterima, dan pengambilnya wajib dicatat beserta foto. Musyrif dikabari saat titipan datang, diambil, dan bila belum diambil.</li>
        <li>Foto Security disimpan 6 bulan di Google Drive pondok.</li>
      </ul>
      <fieldset :disabled="!sc.hak.kelola" class="mt-4 space-y-4">
        <div class="grid gap-3 sm:grid-cols-3">
          <div><label class="label-isian" for="sc-tol">Toleransi terlambat kembali (menit)</label><input id="sc-tol" v-model="atur.toleransi_terlambat_menit" type="number" min="0" max="720" class="isian tabular-nums" /></div>
          <div><label class="label-isian" for="sc-awal">Boleh keluar lebih awal dari jadwal izin (menit)</label><input id="sc-awal" v-model="atur.keluar_lebih_awal_menit" type="number" min="0" max="1440" class="isian tabular-nums" /></div>
          <div><label class="label-isian" for="sc-tp">Ingatkan titipan belum diambil setelah (hari)</label><input id="sc-tp" v-model="atur.pengingat_titipan_hari" type="number" min="1" max="30" class="isian tabular-nums" /></div>
        </div>
        <div class="rounded-2xl border border-garis p-3">
          <label class="flex items-center gap-2 text-sm font-semibold"><input v-model="atur.jadwal_kunjungan_aktif" type="checkbox" class="h-5 w-5 accent-[#C7332F]" /> Aktifkan jadwal kunjungan orang tua</label>
          <p class="mt-1 text-xs text-teks3">Bila tidak diaktifkan, kunjungan bebas. Bila diaktifkan, kunjungan di luar jadwal tetap dicatat dan ditandai.</p>
          <div v-if="atur.jadwal_kunjungan_aktif" class="mt-3 space-y-3">
            <div class="flex flex-wrap gap-2" role="group" aria-label="Hari kunjungan">
              <button v-for="(h, i) in HARI_PENDEK" :key="h" type="button" :aria-pressed="atur.hari_kunjungan.includes(i)" @click="alihHari(i)"
                :class="['min-h-[40px] rounded-xl border px-3 text-sm font-semibold', atur.hari_kunjungan.includes(i) ? 'border-[#3B4CB0] bg-[#3B4CB0]/10 text-teks' : 'border-garis text-teks2']">{{ h }}</button>
            </div>
            <div class="grid max-w-xl gap-3 sm:grid-cols-2"><InputJam v-model="atur.jam_kunjungan_mulai" label="Mulai" /><InputJam v-model="atur.jam_kunjungan_selesai" label="Selesai" /></div>
          </div>
        </div>
      </fieldset>
      <button v-if="sc.hak.kelola" class="tombol-utama mt-4" :disabled="proses" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> Simpan ketentuan</button>
      <p v-else class="mt-3 flex items-center gap-2 text-xs text-teks3"><PhInfo :size="16" /> Diatur oleh superadmin atau admin ber-izin kelola Security.</p>
    </section>
    <TabGerbang v-else :key="aktif" :mode="aktif === 'diluar' ? 'diluar' : 'gerbang'" />
  </div>
  <div v-else-if="sc.hakDimuat" class="kartu flex flex-col items-center gap-2 p-8 text-center text-sm text-teks2">
    <PhLock :size="36" weight="duotone" class="text-teks3" />
    Menu Security hanya untuk petugas Security, pengasuh santri, pimpinan, admin, dan superadmin.
  </div>
  <p v-else class="kartu p-8 text-center text-sm text-teks3">Memuat…</p>
</template>
